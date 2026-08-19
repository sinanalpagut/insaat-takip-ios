import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

// ═══════════════════════════════════════════════════════════════════════════
// İnşaat Takip — Cloud Functions
//
// İKİ İŞLEV VAR ve ikisi de ZORUNLU — istemciden güvenli yapılamayacak iki iş.
//
// 1) redeemInvite — sistemdeki tek "kullanıcı kendi yetkisini yükseltiyor"
//    işlemi: davet edilen kişi kendini bir projenin üyesi yapıyor.
// 2) deleteAccount — App Store 5.1.1(v) zorunluluğu; gerekçesi kendi
//    bloğunda yazılı.
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

// ═══════════════════════════════════════════════════════════════════════════
// HESAP SİLME (madde 28) — App Store Guideline 5.1.1(v)
//
// Hesap oluşturmaya izin veren uygulama, hesabın uygulama İÇİNDEN silinmesine
// de izin vermek ZORUNDA. Bu olmadan gönderim doğrudan reddediliyor.
//
// NEDEN İSTEMCİDEN YAPILAMAZ — beş bağımsız sebep:
//
//  1. `projects/{pid}` ve `users/{uid}` için kural `allow delete: if false`.
//     (Kuralın kendi yorumu zaten bu işlevi işaret ediyordu.)
//  2. ORTAK kendi uid'ini `memberUids`'ten ÇIKARAMAZ: projeye yazma yalnızca
//     sahibe açık. Yani hesabını silen ortak için istemci çözümü matematiksel
//     olarak imkânsız — `redeemInvite`'ı zorunlu kılan gerekçenin aynası.
//  3. Firestore alt koleksiyonları üst belge silinince OTOMATİK SİLİNMİYOR.
//     13 alt koleksiyon var; "proje belgesini sil" deyip geçmek, kullanıcıya
//     "silindi" derken alıcı adlarını ve tahsilatları veritabanında bırakmak
//     olurdu.
//  4. Storage nesneleri istemciden LİSTELENEMİYOR (kurallar yalnızca tam
//     dosya yollarını eşliyor, önek listelemeye izin yok). Admin SDK'nın önek
//     silmesi ayrıca YETİM nesneleri de yakalıyor — yüklemesi yarım kalmış,
//     belgede yolu yazılmamış dosyalar.
//  5. Auth kaydı EN SON silinmeli. Önce silinseydi aynı uid bir daha
//     üretilemeyeceği için `isOwner`/`isMember` sonsuza dek false döner ve veri
//     erişilemez öksüz kalırdı. Sıra bir tercih değil, tek yönlü kapı.
//
// SAHİPLİK KARARI: sahibin projeleri ve tüm verisi SİLİNİR. Devir (ownerUid
// değişimi) kural düzeyinde yasak, devir akışı yok ve devralanın rızası
// gerekir; o ayrı bir madde. İstemci onay ekranında ne kaybedileceğini
// rakamla söylüyor (kaç proje, kaç ortak erişimini kaybedecek).
//
// YENİDEN KİMLİK DOĞRULAMA İSTEMCİDE: `user.reauthenticate(with:)` ile SMS
// turu orada dönüyor. Bu işlev yalnızca doğrulanmış çağrıya güveniyor —
// `request.auth` olmadan hiçbir şey yapmıyor.
// ═══════════════════════════════════════════════════════════════════════════

interface DeleteResult {
  deletedProjects: number;
  leftProjects: number;
}

export const deleteAccount = onCall<unknown, Promise<DeleteResult>>(
  async (request): Promise<DeleteResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "signed-in-required");
    }

    // ---- 1) SAHİBİ OLDUĞU PROJELER: tamamen sil --------------------------
    const owned = await db.collection("projects").where("ownerUid", "==", uid).get();
    const bucket = getStorage().bucket();

    for (const project of owned.docs) {
      // `recursiveDelete` alt koleksiyonların TAMAMINI geziyor; tek tek
      // koleksiyon adı yazmak yeni bir koleksiyon eklendiğinde sessizce
      // eksik kalırdı (13 tane var ve madde 21'de bir tane daha eklendi).
      await db.recursiveDelete(project.ref);

      // Storage ÖNEK silmesi: belgeye bakan bir silme, yüklemesi yarım kalmış
      // ve yolu belgeye hiç yazılmamış nesneleri kaçırırdı.
      await bucket.deleteFiles({ prefix: `projects/${project.id}/` });
    }

    // ---- 2) ORTAK OLDUĞU PROJELER: yalnızca kendini çıkar ----------------
    // Başkasının verisi silinmiyor; kullanıcı listeden düşüyor.
    const member = await db.collection("projects")
      .where("memberUids", "array-contains", uid).get();

    let left = 0;
    for (const project of member.docs) {
      if (project.get("ownerUid") === uid) continue;   // 1. adımda silindi
      const batch = db.batch();
      batch.update(project.ref, { memberUids: FieldValue.arrayRemove(uid) });

      // Ortak kaydı da düşüyor: adı taşıyor (KVKK) ve kişi artık projede
      // değil. Hisse yüzdesi kayboluyor — yöneticinin yeniden tanımlaması
      // gerekiyor, ama kimliği tutmaktan iyi.
      const partners = await project.ref.collection("partners")
        .where("userUid", "==", uid).get();
      partners.docs.forEach((doc) => batch.delete(doc.ref));

      await batch.commit();
      left += 1;
    }

    // ---- 3) Profil belgesi ------------------------------------------------
    await db.collection("users").doc(uid).delete();

    // ---- 4) Auth kaydı — EN SON ------------------------------------------
    // Buraya kadar her şey silindi; bundan sonra uid'in bir daha üretilme
    // ihtimali yok ve olması da gerekmiyor.
    await getAuth().deleteUser(uid);

    return { deletedProjects: owned.size, leftProjects: left };
  },
);
