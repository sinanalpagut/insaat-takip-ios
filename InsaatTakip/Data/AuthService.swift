import Foundation

// MARK: - Kimlik doğrulama sözleşmesi
//
// Telefon + SMS kodu (ANALIZ.md Faz 2 madde 16 kararı). Şantiyedeki ortak
// e-posta hatırlamak zorunda kalmasın diye seçildi; davet akışıyla da doğal
// eşleşiyor — davet edilen kişi zaten telefon numarasıyla biliniyor.
//
// Repository'deki aynı desen: protokol + sahte uygulama + gerçek uygulama.
// Sahte uygulama olmadan giriş ekranı geliştirilemez, çünkü her denemede
// gerçek SMS beklemek (ve kota harcamak) gerekirdi.

/// Doğrulama isteği başlatıldığında dönen tanıtıcı. Kodu doğrularken geri verilir.
struct VerificationRequest: Equatable {
    let id: String
    /// Kullanıcıya "+90 555 000 0001 numarasına kod gönderildi" demek için.
    let phone: String
}

/// Oturum açan kimlik. `name` AYRI tutuluyor: telefon doğrulaması isim
/// vermez, yalnızca numarayı kanıtlar. İsim ilk girişte sorulup
/// `users/{uid}` dokümanında saklanır.
struct AuthSession: Equatable {
    let uid: String
    let phone: String
    /// `users/{uid}` dokümanı yoksa true — isim sorma ekranı bununla açılır.
    let isNewAccount: Bool
}

enum AuthError: LocalizedError, Equatable {
    case invalidPhone
    case invalidCode
    case codeExpired
    case tooManyRequests
    case network
    /// Uygulama telefon doğrulaması için yapılandırılmamış (Info.plist'te geri
    /// çağrı URL şeması yok). Bu bir KULLANICI hatası değil, derleme hatası;
    /// yine de çökmek yerine söylenmesi gerekiyor — bkz. FirebaseAuthService.
    case notConfigured
    /// Telefonla giriş Firebase projesinde KAPALI (kod 17006).
    ///
    /// Emülatör bu ayarı sormuyor; sağlayıcının açık olması yalnızca GERÇEK
    /// projede gerekiyor. Bu yüzden tüm geliştirme emülatörle yapıldığında
    /// hata ilk kez gerçek cihazda görülüyor. Kullanıcı hatası değil, kurulum
    /// eksiği — o yüzden ayrı bir durum.
    case providerDisabled
    /// Firebase silme/hassas işlem için yakın oturum istiyor (17014).
    /// Kullanıcı GİRİŞ yapmıyor, hesabını siliyor — "Giriş yapılamadı" demek
    /// yaptığı işle alakasız ve yanıltıcı olurdu.
    case requiresRecentLogin
    /// Yeniden doğrulamada girilen numara oturumdakinden FARKLI.
    case phoneMismatch
    /// APNs/uygulama doğrulaması başarısız (17054, 17093, 17095…).
    ///
    /// Firebase telefon doğrulamasında uygulamanın gerçekliğini sessiz bir push
    /// ile kanıtlıyor. Anahtar, arka plan kipi ya da bildirim iletimi eksikse
    /// buraya düşüyor. Ayrı tutulmasının sebebi: "Giriş yapılamadı" bu durumda
    /// hem kullanıcıyı hem geliştiriciyi yanlış yere bakmaya itiyordu.
    case appVerificationFailed
    case unknown(String)

    /// Kullanıcıya gösterilen metin. Firebase'in İngilizce hata dizeleri
    /// arayüze SIZMAMALI — uygulamanın tamamı Türkçe.
    var errorDescription: String? {
        switch self {
        case .invalidPhone:     return "Telefon numarası geçersiz"
        case .invalidCode:      return "Kod hatalı"
        case .codeExpired:      return "Kodun süresi doldu · yeniden gönder"
        case .tooManyRequests:  return "Çok fazla deneme · bir süre sonra tekrar dene"
        case .network:          return "Bağlantı yok"
        case .notConfigured:    return "Telefon girişi bu derlemede yapılandırılmadı"
        case .providerDisabled: return "Telefonla giriş bu projede açık değil · Firebase konsolunda etkinleştirilmeli"
        case .requiresRecentLogin:
            return "Güvenlik için numaranı yeniden doğrulaman gerekiyor"
        case .phoneMismatch:
            return "Bu numara hesabına ait değil"
        case .appVerificationFailed:
            return "Uygulama doğrulaması yapılamadı · bildirim ayarları eksik"
        case .unknown:          return "Giriş yapılamadı"
        }
    }
}

@MainActor
protocol AuthService {

    /// Uygulama açılışında elde hazır olan oturum (varsa). Firebase bunu disk'te
    /// tutuyor; kullanıcı her açılışta yeniden SMS beklemesin diye senkron okunur.
    func restoredSession() -> AuthSession?

    /// Numaraya SMS kodu gönderir.
    /// - Parameter phone: E.164 biçiminde (+905551112233).
    func sendCode(to phone: String) async throws -> VerificationRequest

    /// Kodu doğrular ve oturumu açar.
    func verify(code: String, for request: VerificationRequest) async throws -> AuthSession

    func signOut() throws

    /// Silme öncesi kimliği YENİDEN doğrular (madde 28).
    ///
    /// `verify(code:for:)` KULLANILAMAZ ve bu ayrım güvenlik açısından kritik:
    /// o metot `signIn(with:)` çağırıyor, yani kullanıcı BAŞKA bir numara
    /// girerse oturum sessizce o hesaba geçer ve ardından gelen "hesabımı sil"
    /// düğmesi YANLIŞ HESABI siler. Yeniden doğrulama `reauthenticate(with:)`
    /// kullanmak ve numaranın oturumdakiyle aynı olduğunu denetlemek zorunda.
    func reauthenticate(code: String, for request: VerificationRequest) async throws

    /// Firebase Auth kaydını siler. Sunucu tarafı veri silme AYRI: bu çağrıdan
    /// ÖNCE `deleteAccount` işlevi koşmalı, çünkü Auth kaydı gidince uid bir
    /// daha üretilemez ve veri erişilemez öksüz kalır.
    func deleteAccount() async throws
}

// MARK: - Telefon numarası normalleştirme

enum PhoneFormat {

    /// Kullanıcının yazdığını E.164'e çevirir: "0555 123 45 67" → "+905551234567".
    ///
    /// Firebase yalnızca E.164 kabul ediyor. Türkiye'de numaralar alışkanlıkla
    /// baştaki 0 ile yazılır; bu dönüşüm olmadan neredeyse her giriş denemesi
    /// "geçersiz numara" ile döner.
    static func e164(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        switch digits.count {
        case 10 where digits.first == "5":                    // 5551234567
            return "+90" + digits
        case 11 where digits.hasPrefix("0"):                  // 05551234567
            return "+90" + digits.dropFirst()
        case 12 where digits.hasPrefix("90"):                 // 905551234567
            return "+" + digits
        default:
            return nil
        }
    }

    /// Ekranda gösterim: "+905551234567" → "+90 555 123 45 67".
    static func pretty(_ e164: String) -> String {
        let digits = e164.filter(\.isNumber)
        guard digits.count == 12, digits.hasPrefix("90") else { return e164 }
        let n = Array(digits.dropFirst(2))
        return "+90 \(String(n[0...2])) \(String(n[3...5])) \(String(n[6...7])) \(String(n[8...9]))"
    }
}
