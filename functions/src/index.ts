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

      // ÜYELİK DENETİMİ `usedAt` KAPISINDAN ÖNCE — sıra kritik.
      //
      // Zaten üye (ya da projenin sahibi) olan kişi için yapacak bir şey yok:
      // başarıyı tekrar döndürmek doğru cevap. Bu dal ÖNCEDEN `usedAt`
      // kapısının ARKASINDAYDI ve dolayısıyla kendi gerekçesinin tarif ettiği
      // duruma hiç ulaşamıyordu: kullanıcı kodu kullanıp üye olduğu anda kod
      // harcanmış oluyor, ikinci dokunuşunda "bu kod kullanılmış" hatası
      // alıyordu — oysa az önce kendisi katılmıştı.
      //
      // Aynı şey ağ yeniden denemesinde de oluyordu: çağrı sunucuda başarılı
      // olup yanıt kaybolursa, yeniden deneme hata döndürüyor ve kullanıcıya
      // katılamadığı söyleniyordu. Bu dal işlevin İDEMPOTANS çıkışı; kapının
      // arkasında durduğu sürece işe yaramıyordu.
      //
      // Güvenlik zayıflamıyor: üye OLMAYAN biri harcanmış kodu hâlâ
      // kullanamıyor, aşağıdaki kapı yerinde duruyor.
      if (members.includes(uid) || project.get("ownerUid") === uid) {
        return { projectId, projectTitle: title, alreadyMember: true };
      }

      if (invite.get("usedAt") != null) {
        throw new HttpsError("already-exists", "code-used");
      }

      const expiresAt = invite.get("expiresAt") as Timestamp | undefined;
      if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
        throw new HttpsError("deadline-exceeded", "code-expired");
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
        // `actorUid` EKRANA ÇIKMIYOR; hesap silinince bu satırı bulabilmek
        // için var. `title` kişinin GERÇEK ADINI taşıyor ve uid olmadan o adı
        // arayarak silmek gerekirdi — ada göre arama hem kırılgan hem de
        // adaşları birbirine karıştırır.
        actorUid: uid,
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

// ═══════════════════════════════════════════════════════════════════════════
// VARSAYILAN KOVAYA GÜVENİLMİYOR — kanıtlanmış bir tuzak.
//
// `getStorage().bucket()` argümansız çağrıldığında adı `FIREBASE_CONFIG`
// ortam değişkenindeki `storageBucket` alanından alıyor ve o alan tarihsel
// olarak `<proje>.appspot.com` kalıbıyla üretiliyor. Bu projenin kovası ise
// `<proje>.firebasestorage.app` — 2024 sonrası açılan projelerin yeni adı.
// Doğrudan sınandı: `.appspot.com` HTTP 404 (kova YOK),
// `.firebasestorage.app` HTTP 403 (kova VAR).
//
// Yanlış kova `deleteFiles` çağrısında istisna fırlatır ve o istisna hesap
// silme döngüsünün ORTASINDA patlar; sonucu "projesi silinmiş ama hesabı
// duran kullanıcı" olur.
//
// "ÖNCE VAR MI DİYE SOR" YOLU DENENDİ VE TERK EDİLDİ. `bucket.exists()` ile
// aday yoklamak makul görünüyordu; emülatör bunun neden kırılgan olduğunu
// gösterdi: Storage emülatörü, İÇİNDE NESNE OLAN kova için bile `exists()`
// çağrısına false diyor. Yoklamaya güvenen sürüm bu yüzden hiçbir dosyayı
// silmeden "silindi" dedi ve testte yakalandı. Silmeyi, silmenin kendisinden
// başka bir çağrının cevabına bağlamak fazladan bir yalan söyleme yolu açıyor.
//
// BUGÜNKÜ YOL: adayları sırayla DENE, cevabı İŞİN KENDİSİNDEN al.
//   · 404 (kova yok) → sıradaki aday. Yapısal hata kodu; metin eşleştirmesi yok.
//   · Başka hata (izin, ağ) → FIRLAT. Yutulsaydı dosyalar kalırken kullanıcıya
//     "silindi" denirdi.
//   · Bütün adaylar 404 → gerçekten böyle bir kova yok, dolayısıyla o kovada
//     dosya da yok. Silinecek bir şey olmadığı için devam edilir; bu sessiz
//     bir atlama değil, çıkarımı kesin bir sonuç.
// İlk başarılı ad saklanıyor: sonraki projeler doğrudan oradan siliyor.
// ═══════════════════════════════════════════════════════════════════════════

function bucketAdaylari(): string[] {
  const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "";
  return [
    process.env.STORAGE_BUCKET,
    projectId ? `${projectId}.firebasestorage.app` : undefined,
    projectId ? `${projectId}.appspot.com` : undefined,
  ].filter((v): v is string => typeof v === "string" && v.length > 0);
}

let cachedBucketName: string | null = null;

/// Bir projenin bütün Storage nesnelerini siler.
///
/// ÖNEK silmesi, belgeye bakan bir silmenin kaçıracağı nesneleri de yakalıyor:
/// yüklemesi yarım kalmış ve yolu hiçbir belgeye yazılmamış dosyalar.
async function deleteProjectFiles(projectId: string): Promise<void> {
  const prefix = `projects/${projectId}/`;

  if (cachedBucketName) {
    await getStorage().bucket(cachedBucketName).deleteFiles({ prefix });
    return;
  }

  for (const ad of bucketAdaylari()) {
    try {
      await getStorage().bucket(ad).deleteFiles({ prefix });
      cachedBucketName = ad;
      return;
    } catch (error) {
      const kod = (error as { code?: number }).code;
      if (kod === 404) continue;   // böyle bir kova yok → sıradaki aday
      throw error;                  // izin/ağ → sahibine söyle
    }
  }
  // Hiçbir aday yok: silinecek nesne de yok.
}

interface DeleteResult {
  deletedProjects: number;
  leftProjects: number;
}

// SÜRE VE BELLEK AÇIKÇA YAZILI — varsayılan 60 saniye bu iş için YETMEZ ve
// yetmediğinde sonucu "yarım silinmiş hesap" olur. Silme, proje sayısıyla
// doğrusal büyüyen bir dizi: her proje için Storage önek silmesi (nesne
// başına bir istek) + `recursiveDelete` (belge başına bir yazma). Beş projesi
// ve birkaç yüz fotoğrafı olan bir müteahhitte 60 saniye gerçekçi bir tavan
// değil. 540 saniye, işlevin ORTASINDA kesilme ihtimalini pratikte sıfırlıyor;
// istemci tarafındaki bekleme süresi de buna göre ayarlandı
// (`AccountDeletionService`).
export const deleteAccount = onCall<unknown, Promise<DeleteResult>>(
  { timeoutSeconds: 540, memory: "512MiB" },
  async (request): Promise<DeleteResult> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "signed-in-required");
    }

    // ---- 0) YAKIN ZAMANLI DOĞRULAMA — SUNUCUDA ---------------------------
    //
    // İstemci silmeden önce bir SMS turu döndürüyor ve kullanıcıya "Güvenlik
    // için numarana bir kod göndereceğiz" diyor. O tur BİR GÜVENLİK KAPISI
    // DEĞİLDİ: callable uçları sıradan HTTPS uçları ve bu işlev yalnızca
    // "oturum var mı" diye soruyordu. Testlerin kendisi bunun kanıtı —
    // tests/functions.test.mjs uygulamayı hiç açmadan, düz bir POST ve Bearer
    // jetonuyla silme çağırıyor.
    //
    // Yani kaçırılmış bir ID jetonu (bir saat geçerli) tek çağrıyla bütün
    // projeleri, alıcı kayıtlarını ve dekontları geri dönüşsüz siliyordu ve
    // kullanıcı hiçbir SMS görmüyordu. Ekranda yazan güvenlik gerekçesini
    // uygulayan kimse yoktu.
    //
    // `auth_time` jetonun İÇİNDE ve kullanıcının en son NE ZAMAN kimlik
    // doğruladığını söylüyor; yeniden doğrulama onu tazeliyor. Pencere 15
    // dakika: kullanıcının okuyup düşünmesine, hatta sunucu hatasından sonra
    // tekrar denemesine yetecek kadar geniş, çalınmış bir jetonun sessizce
    // kullanılmasına yetmeyecek kadar dar.
    const authTime = Number(request.auth?.token?.auth_time ?? 0);
    if (!authTime || Date.now() / 1000 - authTime > 15 * 60) {
      throw new HttpsError("failed-precondition", "reauth-required");
    }

    // ---- 1) SAHİBİ OLDUĞU PROJELER: tamamen sil --------------------------
    const owned = await db.collection("projects").where("ownerUid", "==", uid).get();

    // Storage'a DÖNGÜNÜN İÇİNDE dokunuluyor. Kova, döngünün dışında bir kez
    // çözülseydi HİÇ PROJESİ OLMAYAN bir kullanıcı — uygulamayı açıp vazgeçen
    // kişi — hiç ihtiyacı olmayan bir kova çağrısına takılır ve o çağrı hata
    // verirse hesabını hiç silemezdi.
    for (const project of owned.docs) {
      // SIRA: ÖNCE STORAGE, SONRA FIRESTORE. Tersi denenmişti ve
      // KURTARILAMAZ: `recursiveDelete` çalışıp ardından Storage silmesi hata
      // verirse proje belgesi gitmiş olur, dolayısıyla yeniden çağrıldığında
      // `owned` sorgusu o projeyi ARTIK BULAMAZ ve dosyalara giden tek yol
      // kapanır — nesneler kovada sonsuza dek öksüz kalır ve kimse listeleyemez.
      //
      // Bu sırayla iki dalın ikisi de toparlanabilir:
      //   · Storage düşerse Firestore'a hiç dokunulmamıştır; kullanıcı hâlâ
      //     her şeyine sahip ve tekrar deneyebilir.
      //   · Firestore düşerse Storage önekinde silinecek bir şey kalmamıştır;
      //     tekrar çağrı boş bir silme + eksik kalan belgeleri tamamlar.
      // Yani işlev, hangi adımda kesilirse kesilsin, TEKRAR ÇAĞRILDIĞINDA
      // ilerliyor. Yarım kalmanın kalıcı hâle geldiği tek düzen eski düzendi.
      //
      // Storage ÖNEK silmesi: belgeye bakan bir silme, yüklemesi yarım kalmış
      // ve yolu belgeye hiç yazılmamış nesneleri kaçırırdı.
      await deleteProjectFiles(project.id);

      // ALT KOLEKSİYONLAR ÖNCE, ÜST BELGE EN SON — ve bu iki adım ayrı.
      //
      // `db.recursiveDelete(project.ref)` tek çağrıda her şeyi siliyor ama
      // silme sırasını GARANTİ ETMİYOR: proje belgesi alt belgelerden önce
      // gidebilir. Gider ve ardından bir alt silme hata verirse, proje belgesi
      // yok olduğu için `owned` sorgusu bir daha o projeyi BULAMAZ; kalan alt
      // belgeler (alıcı adları dahil) erişilemez öksüz kalır. Storage'daki
      // tuzağın aynısı, bir katman içeride.
      //
      // `listCollections()` alt koleksiyon adlarını ÇALIŞMA ANINDA okuyor —
      // yani 13 koleksiyonu elle saymanın sakıncası (yeni koleksiyon eklenince
      // sessizce eksik kalması) burada da yok. Üst belge en sonda ve tek
      // başına siliniyor: ona sıra geldiğinde altında silinecek bir şey
      // kalmamıştır, kesinti olursa da proje hâlâ bulunabilir durumdadır.
      for (const alt of await project.ref.listCollections()) {
        await db.recursiveDelete(alt);
      }
      await project.ref.delete();

      // DAVET BELGELERİ ÜST DÜZEYDE ve proje ağacının DIŞINDA duruyor
      // (`invites/{KOD}`), yani `recursiveDelete` onlara hiç uğramıyor.
      // Kural `allow update, delete: if false` diyor — yani bu belgeleri
      // İSTEMCİ HİÇBİR ZAMAN silemez, sahibi bile. Buradan silinmezlerse
      // sonsuza dek kalırlar ve içlerinde `usedByName` alanı, yani daveti
      // kullanan kişinin GERÇEK ADI vardır (KVKK).
      const invites = await db.collection("invites")
        .where("projectId", "==", project.id).get();
      await Promise.all(invites.docs.map((doc) => doc.ref.delete()));
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

      // "X projeye katıldı" HAREKETİ de düşüyor: başlığı kişinin gerçek adı ve
      // ortak kaydını adı yüzünden silerken aynı adı akışta bırakmak kararın
      // kendisini boşa çıkarırdı.
      //
      // Bunu yapabilmemizin sebebi `activities`in ne olduğu: repository'de
      // yazılı olduğu gibi bu koleksiyon HİÇBİR PARA TOPLAMINI beslemiyor ve
      // JSON yedeğine girmiyor — salt bir akış ekranı. Satırı düşürmek hiçbir
      // rakamı ve hiçbir kaydı değiştirmiyor.
      //
      // `auditEntries` İÇİN AYNI ŞEY YAPILMIYOR ve yapılmamalı: denetim izi
      // yedeğe giriyor, kaydın kendisi o. Ortak zaten SALT OKUR — hiçbir
      // denetim kaydının yazarı olamaz — dolayısıyla ayrılan ortağın adı orada
      // yazar olarak zaten görünmüyor.
      const joins = await project.ref.collection("activities")
        .where("actorUid", "==", uid).get();
      joins.docs.forEach((doc) => batch.delete(doc.ref));

      await batch.commit();
      left += 1;
    }

    // ---- 2b) BAŞKASININ projesindeki davet izleri: AD silinir --------------
    // Bu kişi bir daveti kullandıysa, o `invites/{KOD}` belgesinde adı ve
    // uid'i yazılı kaldı. Belge BAŞKASININ projesine ait, o yüzden silinmiyor —
    // kodun harcandığı bilgisi (`usedAt`) o projenin sahibinin verisi ve
    // durmalı. Silinen yalnızca KİMLİK: ad ve uid.
    //
    // Bu, hemen yukarıdaki ortak kaydı silme kararının aynısı: orada da
    // "adı taşıyor (KVKK)" gerekçesiyle kayıt düşürülüyor. Aynı gerekçe burada
    // uygulanmasaydı, kural bir yerde geçerli bir yerde geçersiz olurdu.
    const redeemed = await db.collection("invites")
      .where("usedByUid", "==", uid).get();
    await Promise.all(redeemed.docs.map((doc) => doc.ref.update({
      usedByName: FieldValue.delete(),
      usedByUid: FieldValue.delete(),
    })));

    // ---- 3) Profil belgesi ------------------------------------------------
    await db.collection("users").doc(uid).delete();

    // ---- 4) Auth kaydı — EN SON ------------------------------------------
    // Buraya kadar her şey silindi; bundan sonra uid'in bir daha üretilme
    // ihtimali yok ve olması da gerekmiyor.
    await getAuth().deleteUser(uid);

    return { deletedProjects: owned.size, leftProjects: left };
  },
);
