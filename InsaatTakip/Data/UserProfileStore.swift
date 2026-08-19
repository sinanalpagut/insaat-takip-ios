import Foundation
import FirebaseFirestore

// MARK: - Kullanıcı profili (users/{uid})
//
// Telefon doğrulaması numarayı kanıtlar ama İSİM VERMEZ. İsim ilk girişte
// soruluyor; bir yere yazılmazsa kullanıcı uygulamayı her açtığında "Adın ne?"
// ekranıyla karşılaşır. Bu yüzden profil, oturumdan AYRI bir kayıt.
//
// Neden ayrı bir protokol (ProjectRepository'ye eklemek yerine): profil
// `projects/{pid}` ağacının DIŞINDA, `users/{uid}` yolunda yaşıyor — farklı
// güvenlik kuralı, farklı ömür. Ortağın adı ise `Partner.name` ile projeye
// yazılı; yani bu kayıt "ben kimim" sorusunun karşılığı, ortak listesinin değil.

struct UserProfile: Codable, Equatable {
    let uid: String
    var name: String
    /// E.164 (+905551112233). Kimliğin kullanıcıya görünen karşılığı.
    var phone: String
    var createdAt: Date
}

@MainActor
protocol UserProfileStore {

    /// Açılışta SENKRON okunan yerel kopya.
    ///
    /// Neden senkron: `AppState.init` senkron çalışıyor ve isim orada gerekiyor.
    /// Ağ turu beklenirse uygulama ya boş bir ekranla açılır ya da bir an için
    /// isim yerine telefon numarası gösterir. Aynı desen `ProjectRepository`de
    /// de var (`cachedSnapshot`).
    func cachedProfile(uid: String) -> UserProfile?

    /// Uzak kopyayı okur. Yeni cihaza/kuruluma girişte yerel önbellek boştur;
    /// isim ancak buradan gelir.
    func fetch(uid: String) async throws -> UserProfile?

    /// Kaydeder. ÖNCE yerel önbelleğe yazar, SONRA uzak kopyayı dener — uzak
    /// yazma hata verse bile kullanıcıya isim bir daha sorulmaz.
    func save(_ profile: UserProfile) async throws

    /// Yerel kopyayı siler (madde 28).
    ///
    /// Önbellek normalde BİLEREK tutuluyor — aynı kişi tekrar girdiğinde isim
    /// yeniden sorulmasın diye. Ama hesap SİLİNİRSE gereklilik bitiyor ve
    /// kayıt E.164 telefon numarası taşıyor: KVKK kapsamında kişisel veri.
    /// "Hesabımı sildim" diyen kullanıcının verisi cihazda kalmamalı.
    func remove(uid: String)
}

// MARK: - Yerel uygulama

/// Yalnızca cihazda tutan uygulama. Simülatörde ve Firestore bağlanana kadar
/// (ANALIZ.md Faz 2 madde 18/19) tek kaynak bu.
///
/// BİLİNEN SINIR: uygulama silinip yeniden kurulursa isim sorulur. Veri kaybı
/// değil, tek seferlik bir soru — uzak kopya bağlandığında kapanacak.
@MainActor
final class LocalUserProfileStore: UserProfileStore {

    private let defaults: UserDefaults
    private static let prefix = "userProfile."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func cachedProfile(uid: String) -> UserProfile? {
        guard let data = defaults.data(forKey: Self.prefix + uid) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    /// Yerel uygulamada uzak kopya yok; önbellek zaten tek kaynak.
    func fetch(uid: String) async throws -> UserProfile? { cachedProfile(uid: uid) }

    func remove(uid: String) {
        defaults.removeObject(forKey: Self.prefix + uid)
    }

    func save(_ profile: UserProfile) async throws {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.prefix + profile.uid)
        // UserDefaults diske yazmayı geciktiriyor. Normalde bu görünmez ama bu
        // kayıt girişin HEMEN ardından yazılıyor: uygulama o aralıkta ölürse
        // (çökme, hata ayıklayıcıdan durdurma) isim kaybolur ve kullanıcı bir
        // daha "Adın ne?" ekranıyla karşılaşır. Tek seferlik, küçük ve kimliğe
        // ait bir yazım olduğu için burada beklemek doğru.
        defaults.synchronize()
    }
}

// MARK: - Firestore uygulaması

/// `users/{uid}` belgesini Firestore'da tutar, yerel önbelleği de günceller.
///
/// İSİM ARTIK SUNUCUDA OLMAK ZORUNDA: `redeemInvite` Cloud Function'ı katılan
/// kişinin adını buradan okuyor. Yalnızca yerelde kalsaydı işlev adı bulamaz ve
/// yöneticinin ortak listesinde telefon numarası ya da "Ortak" görünürdü.
/// İstemciden ad göndermek de çözüm değil: kişi ortak tablosunda istediği adla
/// görünürdü ve liste doğrulanmamış veri taşırdı.
///
/// Güvenlik kuralı bu yolu zaten koruyor ve test edildi: `users/{uid}` yalnızca
/// kişinin KENDİSİNE açık, uid bilen biri başkasının telefonuna ulaşamıyor.
@MainActor
final class FirestoreUserProfileStore: UserProfileStore {

    private let db: Firestore
    /// Senkron `cachedProfile` ve uzak yazma başarısız olsa bile isim sorulmasın
    /// diye yerel kopya korunuyor. Firestore'un disk önbelleği yalnızca asenkron
    /// okunabildiği için protokolün senkron sözü ancak böyle tutulabiliyor.
    private let local: LocalUserProfileStore

    /// `local` varsayılanı gövdede kuruluyor: `LocalUserProfileStore` ana
    /// aktörde olduğu için varsayılan argüman ifadesi olarak yazılamıyor
    /// (çağrı yerinde, izole olmayan bağlamda değerlendirilirdi). Aynı kalıp
    /// `ProjectViewModel.init`'te de var.
    init(db: Firestore = Firestore.firestore(), local: LocalUserProfileStore? = nil) {
        self.db = db
        self.local = local ?? LocalUserProfileStore()
    }

    func cachedProfile(uid: String) -> UserProfile? { local.cachedProfile(uid: uid) }

    func fetch(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard snapshot.exists else { return nil }
        let profile = try snapshot.data(as: UserProfile.self)
        // Uzaktan gelen kayıt önbelleğe de yazılır: yeni cihazda ikinci açılışta
        // ağ beklemeden isim hazır olsun.
        try? await local.save(profile)
        return profile
    }

    /// Yalnızca YEREL kopyayı siler. `users/{uid}` belgesini `deleteAccount`
    /// Cloud Function'ı siliyor — kural istemciye izin vermiyor
    /// (`allow delete: if false`) ve vermemesi doğru.
    func remove(uid: String) { local.remove(uid: uid) }

    func save(_ profile: UserProfile) async throws {
        // ÖNCE yerel: uzak yazma başarısız olsa bile kullanıcıya isim bir daha
        // sorulmaz. Sıra bilinçli — tersi olsa ağ hatası ismi kaybettirirdi.
        try await local.save(profile)
        try await db.collection("users").document(profile.uid)
            .setData(try Firestore.Encoder().encode(profile))
    }
}
