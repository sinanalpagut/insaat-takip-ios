import XCTest
@testable import InsaatTakip

/// Davet bağlantısı — madde 29.
///
/// NEDEN BU TESTLER VAR: bağlantı ÜÇ AYRI YERDE yaşıyor ve ikisi başka bir
/// depoda (benav.com.tr):
///   1. `InviteCode.link` adresi üretiyor,
///   2. `vercel.json` → `/katil/:kod` isteği `katil.html`e yazıyor,
///   3. `katil.html` yoldan kodu ayıklıyor.
/// Üçü birbirinden habersiz değişebilir ve ayrıştıkları an bağlantı 404
/// verir — tam da bu maddenin kapattığı kusur. Bu testler Swift tarafını
/// kilitliyor: buradaki biçim değişirse test kırmızıya döner ve diğer iki
/// yeri güncellemeyi hatırlatır.
final class InviteCodeLinkTests: XCTestCase {

    /// ADRES TAM OLARAK YAZILI.
    ///
    /// "https ile başlıyor mu" gibi gevşek bir denetim, alan adı yanlışlıkla
    /// değiştiğinde de geçerdi — oysa yakalanması gereken hata tam olarak o.
    /// Buradaki yol (`/katil/`) sitedeki yazma kuralıyla birebir aynı olmalı.
    func testLinkShape() {
        XCTAssertEqual(InviteCode.link("X7B9Q2"), "benav.com.tr/katil/X7B-9Q2")
    }

    /// BAĞLANTI, KENDİ ÜRETTİĞİ KODA GERİ ÇÖZÜLEBİLMELİ.
    ///
    /// `JoinWithCodeView.pasteLink` bağlantının son bölümünü alıp
    /// `sanitize`dan geçiriyor; `katil.html` de aynısını yapıyor. Üretim ile
    /// ayrıştırma ayrı yerlerde yazıldığı için aralarındaki sözleşme ancak
    /// gidiş-dönüş denenerek kanıtlanır. Tireli gösterim bu yüzden tehlikeli:
    /// `sanitize` tireyi atmasaydı hiçbir davet çalışmazdı.
    func testLinkRoundTripsBackToTheCode() {
        for _ in 0..<200 {
            let uretilen = InviteCode.generate()
            let baglanti = InviteCode.link(uretilen)
            let sonBolum = baglanti.split(separator: "/").last.map(String.init) ?? ""
            XCTAssertEqual(InviteCode.sanitize(sonBolum), uretilen,
                           "bağlantı koda geri çözülmedi: \(baglanti)")
        }
    }

    /// WHATSAPP'TAN KOPYALANAN METİN GENELDE YALNIZ BAĞLANTI DEĞİL.
    ///
    /// Mesaj "…davet kodun: X7B-9Q2\nhttps://benav.com.tr/katil/X7B-9Q2"
    /// biçiminde gidiyor ve kullanıcı çoğu zaman fazlasını kopyalıyor.
    /// Ayrıştırma son bölümü aldığı için bu çalışmalı — çalışmazsa kusur
    /// kullanıcıya "Bağlantı çözümlenemedi" diye görünür ve davet ölür.
    func testTrailingTextStillYieldsTheCode() {
        let yapistirilan = "1224 Ada projesini takip etmen için davet kodun: X7B-9Q2\n"
                         + "https://" + InviteCode.link("X7B9Q2")
        let sonBolum = yapistirilan.split(separator: "/").last.map(String.init) ?? ""
        XCTAssertEqual(InviteCode.sanitize(sonBolum), "X7B9Q2")
    }

    /// ALFABEDE KARIŞABİLEN HARFLER YOK — bağlantı elle de yazılıyor.
    ///
    /// Sayfa kodu büyük puntoyla gösteriyor ve kullanıcıların bir kısmı
    /// kopyalamak yerine telefondan okuyup uygulamaya yazıyor. I/1, O/0 ve
    /// S/5 karışması o yolda sessiz bir başarısızlık olurdu.
    func testAlphabetAvoidsConfusableCharacters() {
        for karakter in "IOS01" {
            XCTAssertFalse(InviteCode.alphabet.contains(karakter),
                           "\(karakter) alfabede — elle yazımda karışır")
        }
    }
}
