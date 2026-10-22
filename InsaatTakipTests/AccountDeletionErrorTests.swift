import XCTest
import FirebaseFunctions
@testable import InsaatTakip

/// Hesap silme hatalarının çevirisi — madde 68.
///
/// NEDEN BU TESTLER VAR: silme ekranı hatayı `(error as? AuthError)` ile
/// çözmeye çalışıyordu ve Cloud Functions hiçbir zaman `AuthError`
/// fırlatmıyor. Dönüşüm her seferinde başarısız oluyordu, yani kullanıcı
/// sebep ne olursa olsun tek bir cümle görüyordu: "Hesap silinemedi".
///
/// Bu, kodda tek satırla görülmeyen bir kusur: `??` operatörünün sağ tarafı
/// makul bir yedek gibi duruyor, oysa TEK çalışan dal oydu. Aşağıdaki testler
/// artık her sınıfın ayrı bir cümleye çevrildiğini sabitliyor.
final class AccountDeletionErrorTests: XCTestCase {

    private func functionsError(_ code: FunctionsErrorCode,
                                message: String = "") -> NSError {
        NSError(domain: FunctionsErrorDomain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Şantiyede kapsama yok: kullanıcının bilmesi gereken şey bu, "silinemedi"
    /// değil. Yanlış mesaj kullanıcıyı akışı baştan başlatmaya itiyor, her
    /// deneme yeni bir SMS yakıyor ve sonunda kotaya çarpıyordu.
    func testUnreachableIsNamed() {
        XCTAssertEqual(AccountDeletionError.from(functionsError(.unavailable)), .unreachable)
        XCTAssertEqual(AccountDeletionError.from(functionsError(.deadlineExceeded)), .unreachable)
    }

    /// Sunucunun yakın doğrulama istediği durum, sıradan bir sunucu hatasından
    /// AYRI: kullanıcının yapması gereken şey farklı (baştan başlamak).
    func testReauthRequiredIsDistinct() {
        let error = functionsError(.failedPrecondition, message: "reauth-required")
        XCTAssertEqual(AccountDeletionError.from(error), .reauthRequired)
    }

    /// `failed-precondition` her zaman yakın doğrulama demek DEĞİL. Mesaja
    /// bakmadan eşleseydi, ilgisiz bir sunucu hatası kullanıcıyı SMS turuna
    /// geri yollardı.
    func testOtherPreconditionIsServerFailure() {
        XCTAssertEqual(AccountDeletionError.from(functionsError(.failedPrecondition)),
                       .serverFailed)
    }

    /// İşlev dağıtılmamışsa bu bir KURULUM hatası; "tekrar dene" demek
    /// kullanıcıyı sonsuza dek denemeye iter.
    func testNotDeployedIsNamed() {
        XCTAssertEqual(AccountDeletionError.from(functionsError(.notFound)), .notDeployed)
    }

    /// Oturum düştü hükmü işlevin KENDİ anahtarıyla veriliyor.
    ///
    /// Bu test eskiden ANAHTARSIZ `.unauthenticated`ı `.signedOut` sayıyordu —
    /// yani düzeltilen varsayımı sabitliyordu. Anahtarsız 401 çerçevenin
    /// reddi; gövde hiç çalışmadı ve oturum hakkında bir şey söylemiyor.
    /// O durum `testCerceveReddiOturumDusmusSayilmiyor` altında.
    func testSignedOutIsNamed() {
        XCTAssertEqual(AccountDeletionError.from(functionsError(.unauthenticated,
                                                                message: "signed-in-required")),
                       .signedOut)
    }

    /// Anahtarsız 403 de oturum hakkında hüküm değil: işlev gövdesi 403
    /// fırlatmıyor, yalnızca altyapı (çağırma izni) fırlatıyor. Eskiden bu
    /// test 403'ü `.signedOut`a sabitliyordu — 401 için kapatılan SMS
    /// döngüsünü 403 üzerinden açık tutan varsayım.
    func testAltyapi403OturumDusmusSayilmiyor() {
        let hata = AccountDeletionError.from(functionsError(.permissionDenied,
                                                            message: "PERMISSION DENIED"))
        XCTAssertNotEqual(hata, .signedOut)
        XCTAssertTrue(hata.retryable, "403 kişiyi SMS turuna yolluyor")
    }

    /// Functions dışından gelen bir hata (ağ katmanı) da anlamlı bir sınıfa
    /// düşmeli; `serverFailed` demek "sunucu cevap verdi" ima ederdi.
    func testNonFunctionsErrorIsUnreachable() {
        let urlError = NSError(domain: NSURLErrorDomain, code: -1009)
        XCTAssertEqual(AccountDeletionError.from(urlError), .unreachable)
    }

    /// EKRANIN DAVRANIŞINI belirleyen ayrım: hangi hatadan sonra aynı ekranda
    /// tekrar denemenin anlamı var? Yeniden doğrulama gerekiyorsa YOK — aynı
    /// düğmeye basmak aynı hatayı üretir ve kullanıcı kilitlenir.
    func testRetryabilityDrivesTheScreen() {
        XCTAssertTrue(AccountDeletionError.unreachable.retryable)
        XCTAssertTrue(AccountDeletionError.serverFailed.retryable)
        XCTAssertFalse(AccountDeletionError.reauthRequired.retryable)
        XCTAssertFalse(AccountDeletionError.signedOut.retryable)
        XCTAssertFalse(AccountDeletionError.notDeployed.retryable)
    }

    /// Her sınıfın kullanıcıya söyleyecek AYRI bir cümlesi olmalı; ikisi aynı
    /// olsaydı ayırmanın bir faydası kalmazdı.
    func testEveryCaseHasItsOwnSentence() {
        // `allCases`, elle liste DEĞİL: elle tutulan liste `.requestRejected`
        // eklendiğinde güncellenmemişti ve yeni cümle hiç denetlenmiyordu.
        let hepsi = AccountDeletionError.allCases
        let cumleler = hepsi.compactMap(\.errorDescription)
        XCTAssertEqual(cumleler.count, hepsi.count)
        XCTAssertEqual(Set(cumleler).count, hepsi.count)
    }

    // MARK: - Aynı 401, iki ekran

    /// Çerçevenin App Check / jeton reddi "oturumun düşmüş" DEĞİL.
    ///
    /// `deleteAccount` da `enforceAppCheck: true`. Bu yanıt eskiden
    /// `.signedOut`a gidiyordu ve silme ekranı kişiyi baştan SMS turuna
    /// yolluyordu: doğrulama BAŞARILI oluyor (Auth'un App Check ile ilgisi
    /// yok), silme yine reddediliyor, ekran yine başa atıyor — her tur bir
    /// SMS. Davet ekranı aynı yanıta artık başka bir teşhis koyduğu için
    /// ikisinin ayrışması da yanlış olurdu.
    func testCerceveReddiOturumDusmusSayilmiyor() {
        let hata = AccountDeletionError.from(functionsError(.unauthenticated,
                                                            message: "Unauthenticated"))
        XCTAssertNotEqual(hata, .signedOut,
                          "çerçeve reddi kullanıcıyı SMS turuna yolluyor")
        XCTAssertEqual(hata, .requestRejected)
        XCTAssertTrue(hata.retryable, "yeniden deneme yerine SMS turuna yollanıyor")
    }

    func testGercekOturumYokAnahtariKorunuyor() {
        XCTAssertEqual(AccountDeletionError.from(functionsError(.unauthenticated,
                                                                message: "signed-in-required")),
                       .signedOut)
    }
}
