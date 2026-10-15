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

    /// HUKUKİ ADRESLER YERİNDE — madde 27 kapandı (15 Eki 2026).
    ///
    /// Bu testin yerini aldığı `testPrivacyPolicyIsStillPending`, adresin BOŞ
    /// kalmasını kilitliyordu ve tam da görevini yaparak adresler eklendiği
    /// gün düştü: "satırın gerçekten gösterildiğini doğrula" diye uyardı,
    /// doğrulandı (AccountSheet'te gizlilik + KVKK + koşullar satırları,
    /// PlansSheet'te koşullar + gizlilik bağlantısı).
    ///
    /// ŞİMDİ KİLİTLENEN ŞEY ADRESİN ŞEKLİ:
    ///   · https — App Store gizlilik adresinde http kabul etmiyor;
    ///   · üçü BİRBİRİNDEN FARKLI — kopyala-yapıştır ile aynı sayfaya bakan
    ///     üç satır, kullanıcının aradığı metni hiç bulamaması demek ve bu
    ///     hata ekranda normal görünür, yalnızca dokununca anlaşılır.
    ///
    /// ADRESLERİN CANLI OLDUĞUNU BU TEST DOĞRULAYAMAZ: sayfalar başka bir
    /// depoda (`scripts/hukuki-sayfalar.py` üretiyor) ve testin ağa çıkması
    /// onu kırılgan yapardı. Yayın öncesi elle açılıp görülmeleri şart.
    func testLegalURLsAreConfigured() throws {
        let adresler: [(String, URL)] = [
            ("gizlilik", try XCTUnwrap(AppInfo.privacyPolicyURL)),
            ("kvkk", try XCTUnwrap(AppInfo.kvkkNoticeURL)),
            ("koşullar", try XCTUnwrap(AppInfo.termsURL)),
        ]
        for (ad, url) in adresler {
            XCTAssertEqual(url.scheme, "https", "\(ad) adresi https değil")
            XCTAssertFalse(url.host?.isEmpty ?? true, "\(ad) adresinde alan adı yok")
        }
        XCTAssertEqual(Set(adresler.map { $0.1.absoluteString }).count, 3,
                       "üç hukuki satırdan en az ikisi aynı sayfaya gidiyor")
    }
}
