import XCTest
@testable import InsaatTakip

/// Sürüm ve destek bilgisi — madde 72.
///
/// NEDEN BU TESTLER VAR: Crashlytics bilinçli olarak ertelendi, yani sahadaki
/// bir hatanın görünebildiği TEK kanal destek e-postası. O e-posta tanı
/// bilgisi taşımazsa kanal da yok sayılır — "uygulama açılmıyor" diye gelen
/// bir mesajla çalışılamaz.
final class AppInfoTests: XCTestCase {

    /// SÜRÜM VE BUILD BİRLİKTE. Yalnızca "1.0" yazmak destek için işe yaramaz:
    /// aynı sürüm numarasıyla onlarca build gönderiliyor ve hatanın hangisinde
    /// olduğu ancak build numarasıyla ayrılıyor.
    func testVersionTextCarriesBothNumbers() {
        let metin = AppInfo.versionText
        XCTAssertTrue(metin.contains("("), "build numarası eksik: \(metin)")
        XCTAssertTrue(metin.hasSuffix(")"))
        XCTAssertFalse(metin.contains("—"), "sürüm okunamadı: \(metin)")
    }

    /// Destek bağlantısı KURULABİLİYOR ve doğru adrese gidiyor.
    func testSupportMailIsAddressed() throws {
        let url = try XCTUnwrap(AppInfo.supportMailURL)
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertTrue(url.absoluteString.contains(AppInfo.supportAddress))
    }

    /// E-POSTA GÖVDESİ TANI BİLGİSİ TAŞIMALI.
    ///
    /// Sürüm, iOS sürümü ve cihaz modeli olmadan hatanın hangi derlemede
    /// olduğu bilinemez; kullanıcıdan bunları sormak cevabı günlerce
    /// geciktirir.
    func testSupportMailCarriesDiagnostics() throws {
        let url = try XCTUnwrap(AppInfo.supportMailURL)
        let govde = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "body" }?.value)

        XCTAssertTrue(govde.contains(AppInfo.versionText), "sürüm yok")
        XCTAssertTrue(govde.contains("iOS:"), "iOS sürümü yok")
        XCTAssertTrue(govde.contains(AppInfo.deviceIdentifier), "cihaz modeli yok")
        XCTAssertTrue(govde.contains("silmeyin"),
                      "kullanıcıya satırları silmemesi söylenmemiş")
    }

    /// CİHAZ KİMLİĞİ MODELİ SÖYLEMELİ.
    ///
    /// `UIDevice.current.model` yalnızca "iPhone" diyor ve bir hata raporunda
    /// işe yaramıyor; donanım kimliği ("iPhone14,2") gerekiyor.
    func testDeviceIdentifierIsSpecific() {
        let kimlik = AppInfo.deviceIdentifier
        XCTAssertFalse(kimlik.isEmpty)
        XCTAssertNotEqual(kimlik, "iPhone", "model ayrımı yok")
        XCTAssertNotEqual(kimlik, "bilinmiyor")
    }

    /// GİZLİLİK POLİTİKASI ADRESİ HENÜZ YOK (madde 27) ve bu BİLİNÇLİ.
    ///
    /// Bu test, adres eklendiği gün DÜŞECEK ve o an satırın gerçekten
    /// gösterildiğini doğrulamayı hatırlatacak. Çalışmayan bir bağlantı, hiç
    /// bağlantı olmamasından kötü.
    func testPrivacyPolicyIsStillPending() {
        XCTAssertNil(AppInfo.privacyPolicyURL,
                     "madde 27 kapandıysa AccountSheet'teki satırı da doğrula")
    }
}
