import Foundation

// MARK: - Sahte kimlik doğrulama (geliştirme ve simülatör)
//
// Gerçek SMS beklemeden giriş akışını geliştirmek/denemek için. Firebase
// konsolunda tanımlı test numarasıyla AYNI değerleri kullanır, böylece sahte
// ile gerçek arasında geçiş yaparken ekranda hiçbir şey değişmez.
//
// Simülatörde gerçek telefon doğrulaması APNs istiyor ve onun yerine
// reCAPTCHA web akışına düşüyor; o ekranın metnini biz kontrol edemiyoruz.
// Bu yüzden simülatörde varsayılan olarak sahte servis kullanılıyor.

@MainActor
final class FakeAuthService: AuthService {

    /// Firebase konsolundaki test numarasıyla aynı.
    static let testPhone = "+905550000001"
    static let testCode = "123456"

    private let defaults: UserDefaults
    private static let sessionKey = "fakeAuth.session"
    private static let knownPhonesKey = "fakeAuth.knownPhones"

    private var session: AuthSession?
    /// Bu numarayla daha önce girildi mi — `isNewAccount` bayrağını üretmek için.
    private var knownPhones: Set<String>

    /// `signedInAs` — DEBUG rol kısayolu (`-role admin`) kimlik servisini
    /// tamamen atlayıp `currentUser`ı doğrudan kuruyor. O yolda oturum
    /// seedlenmezse sahte servis oturumsuz kalıyor ve kimlik gerektiren her
    /// akış (ör. hesap silme) simülatörde `notConfigured` ile duruyordu —
    /// yani ekran doğrulaması yalnızca gerçek cihazda mümkün oluyordu.
    ///
    /// Oturum KULLANICIYLA tutarlı kuruluyor (uid + telefon): sabit bir test
    /// numarası kullanılsaydı, silme akışındaki "numara oturumdakiyle aynı mı"
    /// denetimi rol kısayolunda hep düşerdi ve gerçek bir kusur sanılırdı.
    init(startSignedIn: Bool = false, signedInAs user: User? = nil,
         defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.knownPhonesKey) ?? []
        self.knownPhones = Set(stored).union([Self.testPhone])

        if let user, !user.phone.isEmpty {
            session = AuthSession(uid: user.id, phone: user.phone, isNewAccount: false)
            knownPhones.insert(user.phone)
        } else if startSignedIn {
            session = AuthSession(uid: User.admin.id, phone: Self.testPhone, isNewAccount: false)
        } else if let data = defaults.data(forKey: Self.sessionKey) {
            session = try? JSONDecoder().decode(StoredSession.self, from: data).asSession
        }
    }

    func restoredSession() -> AuthSession? { session }

    func sendCode(to phone: String) async throws -> VerificationRequest {
        // E.164'e ÇEVİRİP döndürmek şart, yalnızca doğrulamak yetmez: gerçek
        // servis normalleştirilmiş numarayı döndürüyor ve uid o numaradan
        // türüyor. Ham metinle dönülürse "0555…" ile "+90555…" iki ayrı hesap
        // olur ve ekranda numara biçimsiz görünür — yani sahte servis gerçeğin
        // yapmadığı bir davranışı taklit etmiş olur.
        guard let e164 = PhoneFormat.e164(phone) else { throw AuthError.invalidPhone }
        // Ağ gecikmesini taklit et: "Kod gönderiliyor…" durumu gerçek akışta
        // görünüyor, sahte serviste anında dönerse o durumu hiç test edemeyiz.
        try? await Task.sleep(nanoseconds: 600_000_000)
        return VerificationRequest(id: "fake-\(e164)", phone: e164)
    }

    func verify(code: String, for request: VerificationRequest) async throws -> AuthSession {
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard code == Self.testCode else { throw AuthError.invalidCode }

        let isNew = !knownPhones.contains(request.phone)
        knownPhones.insert(request.phone)
        defaults.set(Array(knownPhones), forKey: Self.knownPhonesKey)
        // Sahte uid numaradan türetilir; aynı numarayla tekrar girince aynı
        // hesaba düşülür (gerçek Firebase davranışı).
        let uid = request.phone == Self.testPhone ? User.admin.id : "fake-\(request.phone.filter(\.isNumber))"
        let session = AuthSession(uid: uid, phone: request.phone, isNewAccount: isNew)
        store(session)
        return session
    }

    func signOut() throws {
        session = nil
        defaults.removeObject(forKey: Self.sessionKey)
    }

    /// Sahte yeniden doğrulama (madde 28).
    ///
    /// Gerçek servisteki güvenlik kapısının AYNISI burada da var: numara
    /// oturumdakiyle eşleşmiyorsa reddediliyor. Sahte servis gevşek
    /// bırakılsaydı silme akışı simülatörde "çalışıyor" görünür, gerçek
    /// cihazda ise `phoneMismatch` ile durur ve fark ancak sahada anlaşılırdı.
    func reauthenticate(code: String, for request: VerificationRequest) async throws {
        guard let session else { throw AuthError.notConfigured }
        guard session.phone == request.phone else { throw AuthError.phoneMismatch }
        guard code == Self.testCode else { throw AuthError.invalidCode }
    }

    /// Sahte silme: oturumu ve bu cihazda tanınan numarayı kaldırır.
    ///
    /// `knownPhones` de temizleniyor — yoksa simülatörde "silme sonrası temiz
    /// cihaz" senaryosu doğru denenemezdi: aynı numarayla girişte kullanıcı
    /// yeni değil "tanınan" sayılırdı.
    func deleteAccount() async throws {
        guard let session else { throw AuthError.notConfigured }
        var known = Set(defaults.stringArray(forKey: Self.knownPhonesKey) ?? [])
        known.remove(session.phone)
        defaults.set(Array(known), forKey: Self.knownPhonesKey)
        try signOut()
    }

    /// Oturumu DİSKE yazar. Firebase oturumu kendi başına kalıcı tutuyor;
    /// sahte servis yalnızca bellekte tutsaydı uygulama her açılışta karşılama
    /// ekranına düşer ve `restoredSession()` yolu simülatörde hiç denenemezdi.
    private func store(_ session: AuthSession) {
        self.session = session
        if let data = try? JSONEncoder().encode(StoredSession(session)) {
            defaults.set(data, forKey: Self.sessionKey)
            // Aynı gerekçe `LocalUserProfileStore.save`'da: girişin hemen
            // ardından öldürülen uygulamada gecikmeli yazım kaybolur ve
            // geliştirme sırasında her seferinde baştan giriş gerekir.
            defaults.synchronize()
        }
    }

    /// `AuthSession` arayüz sözleşmesi; diske yazım biçimi ondan ayrı tutuluyor
    /// ki sözleşmeye `Codable` eklemek zorunda kalmayalım.
    private struct StoredSession: Codable {
        let uid: String
        let phone: String

        init(_ session: AuthSession) {
            uid = session.uid
            phone = session.phone
        }
        /// Diskten dönen oturumda hesap yeni olamaz — kayıt varsa girilmiş demek.
        var asSession: AuthSession {
            AuthSession(uid: uid, phone: phone, isNewAccount: false)
        }
    }
}
