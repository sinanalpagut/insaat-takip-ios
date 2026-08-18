import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

// ═══════════════════════════════════════════════════════════════════════════
// İnşaat Takip — Cloud Functions
//
// TEK İŞLEV VAR ve olması ZORUNLU. Sistemdeki tek "kullanıcı kendi yetkisini
// yükseltiyor" işlemi bu: davet edilen kişi kendini bir projenin üyesi yapıyor.
//
// Güvenlik kuralları bunu yapamaz ve yapmaması doğru:
//   · Davet edilen kişi henüz ÜYE OLMADIĞI projeyi okuyamaz (kural öyle), o
//     yüzden kodu istemcide doğrulaması imkânsız.
//   · `memberUids`'e yazma yalnızca sahibe açık. Açık olsaydı herkes kendini
//     herhangi bir projeye ekleyebilirdi.
//   · Kodun geçerliliği + tek kullanımı + dört belgenin atomik yazımı istemciden
//     güvenli kurulamaz.
// (Bu kısıt `tests/rules.test.mjs` içinde testle sabit: "YABANCI kendini üye
// listesine EKLEYEMEZ".)
//
// DAVET ÜRETME BURADA DEĞİL: yönetici kendi projesine yazıyor, onu güvenlik
// kuralı çözüyor (`invites/{KOD}` create + `projects/{pid}.invite` aynası).
// İşlev çağrısı gereksiz maliyet ve gecikme olurdu.
// ═══════════════════════════════════════════════════════════════════════════

initializeApp();
const db = getFirestore();

// BÖLGE — europe-west1. Firestore `eur3` çoklu bölgesi europe-west1 ve
// europe-west4'ten oluşuyor; işlev bunlardan birinde olmalı ki her davet
// kıtalar arası tur atmasın. (Frankfurt/europe-west3 eur3'ün İÇİNDE DEĞİL —
// yakın görünmesi yanıltıcı.)
//
// maxInstances — bilinçli düşük. Davet kullanma insan hızında bir işlem;
// yüzlerce eşzamanlı örneğe ihtiyacı yok ve sınır, hatalı bir döngünün
// faturayı şişirmesine karşı üst bir tavan.
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

/// Kullanıcı girdisini normalize eder — istemcideki `InviteCode.sanitize` ile
/// AYNI kurallar. Kullanıcı tireyle ("X7B-9Q2") ya da küçük harfle yazabilir.
function sanitizeCode(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 6);
}

/// Katılan kişinin ortak listesinde görünecek adı.
///
/// Kaynak SUNUCU: `users/{uid}` profili. İstemciden ad ALINMIYOR — alınsaydı
/// kişi ortak tablosunda istediği adla görünürdü ve yöneticinin gördüğü liste
/// doğrulanmamış veri olurdu.
///
/// TELEFON NUMARASI YEDEK DEĞİL. Önce numaraya düşülüyordu; `partners/{id}`
/// belgesi ise projenin TÜM üyelerine açık (`allow read: if isMember(pid)`),
/// yani profilini doldurmadan katılan kişinin telefonu diğer ortakların
/// cihazına iniyordu. Numara KVKK kapsamında kişisel veri ve kişi onu
/// ortaklara göstermeye rıza vermedi; kimlik doğrulaması için verdi.
/// Adı olmayan kişi "Yeni ortak" görünür, katıldıktan sonra kendi adını
/// girdiğinde düzelir.
async function displayName(uid: string, _phone: string | undefined): Promise<string> {
  const profile = await db.collection("users").doc(uid).get();
  const name = profile.get("name");
  if (typeof name === "string" && name.trim().length > 0) return name.trim();
  return "Yeni ortak";
}

interface RedeemResult {
  projectId: string;
  projectTitle: string;
  /// Kişi zaten üyeyse true — HATA DEĞİL. İstemci "zaten ortağısın" der ve
  /// projeyi açar. Aynı bağlantıya iki kez dokunmak bir arıza değil.
  alreadyMember: boolean;
}

export const redeemInvite = onCall<{ code?: string }, Promise<RedeemResult>>(
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "signed-in-required");
    }

    const code = sanitizeCode(request.data?.code);
    if (code.length !== 6) {
      throw new HttpsError("invalid-argument", "code-format");
    }

    const phone = request.auth?.token?.phone_number as string | undefined;
    const name = await displayName(uid, phone);

    const inviteRef = db.collection("invites").doc(code);

    return db.runTransaction(async (tx) => {
      const invite = await tx.get(inviteRef);
      if (!invite.exists) {
        throw new HttpsError("not-found", "code-not-found");
      }
      if (invite.get("usedAt") != null) {
        throw new HttpsError("already-exists", "code-used");
      }

      const expiresAt = invite.get("expiresAt") as Timestamp | undefined;
      if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
        throw new HttpsError("deadline-exceeded", "code-expired");
      }

      const projectId = invite.get("projectId");
      if (typeof projectId !== "string" || projectId.length === 0) {
        throw new HttpsError("failed-precondition", "invite-broken");
      }

      const projectRef = db.collection("projects").doc(projectId);
      const project = await tx.get(projectRef);
      if (!project.exists) {
        // Proje silinmiş ama davet ortada kalmış. Kodu harcamıyoruz; sorun
        // kullanıcıda değil, veride.
        throw new HttpsError("failed-precondition", "project-missing");
      }

      const title = `${project.get("blockNumber")} Ada / ${project.get("parcelNumber")} Parsel`;
      const members: string[] = project.get("memberUids") ?? [];

      // Zaten üye (ya da projenin sahibi) — kod HARCANMAZ. Harcansaydı,
      // yanlışlıkla iki kez dokunan kişi kodu yakar ve yönetici yeni kod
      // üretmek zorunda kalırdı.
      if (members.includes(uid) || project.get("ownerUid") === uid) {
        return { projectId, projectTitle: title, alreadyMember: true };
      }

      // Dört yazma, TEK transaction: üyelik + ortak kaydı + hareket + kodun
      // harcanması. Yarısı yazılırsa "üye oldu ama ortak listesinde yok" ya da
      // "kod harcandı ama üyelik yok" gibi bir durum kalırdı.
      tx.update(projectRef, { memberUids: FieldValue.arrayUnion(uid) });

      const partnerId = crypto.randomUUID().toUpperCase();
      tx.set(projectRef.collection("partners").doc(partnerId), {
        id: partnerId,
        projectId,
        name,
        isFounder: false,
        joinedAt: FieldValue.serverTimestamp(),
        sharePercent: 0, // Hisseyi yönetici tanımlar; işlev pay dağıtmaz.
        userUid: uid,
      });

      const activityId = crypto.randomUUID().toUpperCase();
      tx.set(projectRef.collection("activities").doc(activityId), {
        id: activityId,
        projectId,
        kind: "partnerJoined",
        title: `${name} projeye katıldı`,
        meta: title,
        timestamp: FieldValue.serverTimestamp(),
      });

      tx.update(inviteRef, {
        usedAt: FieldValue.serverTimestamp(),
        usedByUid: uid,
        usedByName: name,
      });

      return { projectId, projectTitle: title, alreadyMember: false };
    });
  }
);
