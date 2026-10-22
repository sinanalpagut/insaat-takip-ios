import FirebaseFunctions
import Foundation

// MARK: - Hesap silme (madde 28) — App Store 5.1.1(v)
//
// Sunucu tarafını `deleteAccount` Cloud Function'ı yapıyor; gerekçesi
// functions/src/index.ts içinde yazılı (beş bağımsız sebep: kural istemciye
// proje/profil silmeyi kapatıyor, ortak kendi üyeliğini çıkaramıyor, alt
// koleksiyonlar otomatik silinmiyor, Storage istemciden listelenemiyor ve Auth
// kaydı en son silinmeli).
//
// Bu tip yalnızca çağrıyı ve hatayı taşıyor — `FirebaseInviteService` ile aynı
// desen.

struct AccountDeletionSummary {
    /// Silinen (sahibi olunan) proje sayısı.
    let deletedProjects: Int
    /// Ortak olarak ayrılınan proje sayısı — verisi DURUYOR.
    let leftProjects: Int
}

// MARK: - Silme hatası
//
// Neden ayrı bir tip: silme ekranı hatayı `(error as? AuthError)` ile
// çözmeye çalışıyordu ve Cloud Functions HİÇBİR ZAMAN `AuthError`
// fırlatmıyor — `FunctionsErrorDomain` NSError fırlatıyor. Dönüşüm hep
// başarısız olduğu için kullanıcı, sebep ne olursa olsun tek bir cümle
// görüyordu: "Hesap silinemedi".
//
// Fark kullanıcı için gerçek: şantiyede kapsama yokken "Bağlantı yok" demek
// ile "Hesap silinemedi" demek farklı davranışlara yol açıyor. İkincisini
// okuyan kişi akışı baştan başlatıyor, her denemede yeni bir SMS yakıyor ve
// sonunda Firebase kotasına çarpıyor — yani mesajın belirsizliği kullanıcıyı
// çalışmayan bir döngüye sokuyor.
enum AccountDeletionError: LocalizedError, Equatable, CaseIterable {
    /// Ağ yok ya da sunucuya ulaşılamadı — VERİ HENÜZ SİLİNMEMİŞ olabilir.
    case unreachable
    /// Oturum düşmüş — işlevin KENDİ `signed-in-required` anahtarı.
    case signedOut
    /// İstek, işlev gövdesine girmeden reddedildi (çerçevenin App Check /
    /// jeton kapısı). Davet ekranındaki `InviteError.requestRejected` ile
    /// AYNI sunucu yanıtı.
    ///
    /// Eskiden `.signedOut`a gidiyordu ve bu bir SMS döngüsüydü: ekran kişiyi
    /// baştan telefon doğrulamasına yolluyor, doğrulama BAŞARILI oluyor
    /// (Auth'un App Check ile ilgisi yok), silme yine reddediliyor, ekran yine
    /// başa atıyor. Her tur bir SMS — bu dosyanın başındaki yorumun "kotaya
    /// çarpar" dediği döngünün ta kendisi.
    case requestRejected
    /// Sunucu yakın zamanlı doğrulama istiyor (`reauth-required`).
    case reauthRequired
    /// İşlev dağıtılmamış ya da bölge yanlış — kurulum hatası.
    case notDeployed
    /// Sunucu işi tamamlayamadı.
    case serverFailed

    var errorDescription: String? {
        switch self {
        case .unreachable:    return "Bağlantı yok · silme tamamlanmadı"
        case .signedOut:      return "Oturumun düşmüş · çıkıp tekrar gir"
        // Bu metin SMS kodu alanının hemen altında görünüyor; "doğrulanamadı"
        // kelimesi "SMS kodun doğrulanamadı" diye okunuyordu.
        case .requestRejected: return "Sunucu isteği reddetti · SMS kodun geçerli, bağlantını kontrol edip tekrar dene"
        case .reauthRequired: return "Doğrulamanın süresi doldu · baştan başla"
        case .notDeployed:    return "Silme servisi bu projede kurulu değil"
        case .serverFailed:   return "Sunucu silmeyi tamamlayamadı · tekrar dene"
        }
    }

    /// Aynı oturumla yeniden denemenin anlamı var mı?
    ///
    /// `reauthRequired` ve `signedOut` için YOK: ekranın kod adımına dönüp
    /// tekrar "sil" demek aynı hatayı üretir. Diğerleri geçici.
    var retryable: Bool {
        // `requestRejected` YENİDEN DENENEBİLİR: sebep çoğunlukla jetonun
        // alınamadığı kötü bağlantı ve aynı oturumla düzelebiliyor. Kişiyi
        // SMS turuna geri yollamak düzeltmiyor, yalnızca SMS yakıyor.
        self == .unreachable || self == .serverFailed || self == .requestRejected
    }

    /// `FunctionsErrorDomain` NSError'ından çeviri.
    static func from(_ error: Error) -> AccountDeletionError {
        #if DEBUG
        // Ham hata DEBUG'da basılıyor: kullanıcıya Türkçe ve kısa bir cümle
        // gösteriliyor, ama geliştiricinin sebebi okuyabilmesi gerekiyor.
        print("deleteAccount hatası: \(error)")
        #endif
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: ns.code) else {
            return .unreachable
        }
        switch code {
        case .unavailable, .deadlineExceeded, .aborted, .cancelled:
            return .unreachable
        case .unauthenticated:
            // Anahtar yalnızca işlev GÖVDESİNDEN gelir. Anahtarsız 401 =
            // çerçeve reddetti, gövde hiç çalışmadı.
            return ns.localizedDescription == "signed-in-required" ? .signedOut : .requestRejected
        case .permissionDenied:
            // 403'ü işlev gövdesi HİÇ fırlatmıyor ve projede `authPolicy`
            // yok; yani yalnızca altyapıdan geliyor (Cloud Run çağırma izni,
            // kuruluş politikası). Oturumla ilgisi yok — `.signedOut` kişiyi
            // SMS turuna yollar ve 401 için kapatılan döngü burada açık kalırdı.
            return .requestRejected
        case .failedPrecondition:
            // Sunucu `reauth-required` diyorsa doğrulama eskimiş demektir.
            return ns.localizedDescription.contains("reauth") ? .reauthRequired : .serverFailed
        case .notFound:
            return .notDeployed
        default:
            return .serverFailed
        }
    }
}

@MainActor
protocol AccountDeletionService {
    func deleteServerData() async throws -> AccountDeletionSummary
}

@MainActor
final class FirebaseAccountDeletionService: AccountDeletionService {

    private let functions: Functions

    init(functions: Functions = Functions.functions(region: FirebaseInviteService.region)) {
        self.functions = functions
    }

    /// İstemci beklemesi SUNUCUDAN UZUN olmak zorunda.
    ///
    /// Callable'ın istemci tarafındaki varsayılan sınırı 70 saniye, sunucu
    /// tarafındaki sınır ise 540 saniyeye çıkarıldı. Varsayılan bırakılsaydı
    /// uzun bir silmede istemci 70. saniyede pes eder, kullanıcıya "Hesap
    /// silinemedi" derdi — oysa sunucu silmeye DEVAM ediyor ve birkaç saniye
    /// sonra bitiriyor. Kullanıcıya söylenen şeyin tersi oluyor: hesabı
    /// silindiği hâlde silinmedi sanıyor, tekrar girmeyi deniyor ve giremiyor.
    ///
    /// Bekleme süresi sunucununkinden UZUN: kimin pes edeceğine sunucu karar
    /// versin ki istemci gerçek sonucu görebilsin.
    func deleteServerData() async throws -> AccountDeletionSummary {
        let callable = functions.httpsCallable("deleteAccount")
        callable.timeoutInterval = 600
        let response: HTTPSCallableResult
        do { response = try await callable.call([:]) }
        catch { throw AccountDeletionError.from(error) }
        let data = response.data as? [String: Any] ?? [:]
        return AccountDeletionSummary(
            deletedProjects: data["deletedProjects"] as? Int ?? 0,
            leftProjects: data["leftProjects"] as? Int ?? 0)
    }
}

/// Simülatör/demo yolu. Sunucu yok; akış ekranda denenebilsin diye başarıyı
/// taklit ediyor.
///
/// Sahte servis olmasaydı silme akışı YALNIZCA gerçek cihazda denenebilirdi ve
/// ekran doğrulaması her seferinde telefon gerektirirdi.
@MainActor
final class FakeAccountDeletionService: AccountDeletionService {
    func deleteServerData() async throws -> AccountDeletionSummary {
        AccountDeletionSummary(deletedProjects: 0, leftProjects: 0)
    }
}
