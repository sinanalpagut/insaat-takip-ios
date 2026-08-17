import Foundation

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
