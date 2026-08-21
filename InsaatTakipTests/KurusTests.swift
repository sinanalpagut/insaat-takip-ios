import XCTest
@testable import InsaatTakip

/// `Kurus` — para aritmetiğinin değişmezleri.
///
/// Buradaki her test GERÇEKTEN YAŞANMIŞ bir kusuru bekliyor. Faz 5'te bulunan
/// hataların ortak özelliği şuydu: hepsi TOPLAM denetimlerinden geçiyordu,
/// bozdukları şey detaydı. O yüzden testler yalnızca "toplam tutuyor mu" diye
/// sormuyor; eşitlik, işaret ve TUZAK ATMAMA da ayrı ayrı sınanıyor.
final class KurusTests: XCTestCase {

    // MARK: split(_:into:) — madde 32

    /// Eşit bölmede paylar toplamı tutara BİREBİR eşit ve aralarındaki fark
    /// en fazla 1 kuruş olmalı.
    ///
    /// KUSUR: `Installment.plan` eşit taksitleri yüzde üzerinden üretiyordu
    /// (`100 / count` TAM SAYI bölmesi). 12 taksitte yüzdeler toplamı 96
    /// çıkıyor, eksik kalan %4 son taksite biniyordu — 12 ayda %50, 36 ayda
    /// 15 KAT şişkin son taksit. Toplam her zaman doğru olduğu için hiçbir
    /// toplam denetimi yakalayamıyordu.
    func testSplitIntoEqualParts() {
        let tutarlar: [Int64] = [75_000_000, 120_000_037, 183_749_999, 1, 0, 99, -120_000_037]
        for raw in tutarlar {
            for count in 1...240 {
                let paylar = Kurus.split(.kurus(raw), into: count)
                XCTAssertEqual(paylar.count, count)
                XCTAssertEqual(paylar.reduce(Kurus.zero, +).raw, raw,
                               "toplam sapması: tutar=\(raw) count=\(count)")
                let ham = paylar.map(\.raw)
                XCTAssertLessThanOrEqual((ham.max() ?? 0) - (ham.min() ?? 0), 1,
                                         "paylar eşit değil: tutar=\(raw) count=\(count)")
            }
        }
    }

    func testSplitIntoRejectsNonPositiveCount() {
        XCTAssertTrue(Kurus.split(.lira(1_000), into: 0).isEmpty)
        XCTAssertTrue(Kurus.split(.lira(1_000), into: -3).isEmpty)
    }

    // MARK: split(_:byPercents:) — regresyon: taşmada SIGTRAP

    /// Büyük tutarlar TUZAK ATMAMALI.
    ///
    /// KUSUR: `magnitude * Int64(yüzde)` düz çarpımla yapılıyordu ve
    /// `magnitude` 9,2e16 kuruşu geçtiğinde taşıp SIGTRAP atıyordu. Madde 37
    /// düzeltilirken `Kurus.cost` `Int64.max`a doyurmaya başlayınca bu değer
    /// buraya doğrudan akar oldu: çökme ortadan kalkmadı, YER DEĞİŞTİRDİ.
    func testSplitByPercentsDoesNotTrapOnHugeAmounts() {
        for raw in [Int64.max, -Int64.max, 9_223_372_036_854_775_000] {
            for yuzdeler in [[50, 50], [33, 33, 34], [40, 25, 20, 15], [100]] {
                let paylar = Kurus.split(.kurus(raw), byPercents: yuzdeler)
                XCTAssertEqual(paylar.reduce(Kurus.zero, +).raw, raw,
                               "toplam sapması: tutar=\(raw) yüzdeler=\(yuzdeler)")
            }
        }
    }

    /// Yüzdeler toplamı 100 DEĞİLSE yalnızca o kadarı dağıtılır — kalanı
    /// çağıranın sorunu (ekranda "%40 tanımsız" diye görünüyor).
    func testSplitByPercentsPartialCoverage() {
        XCTAssertEqual(Kurus.split(.lira(10_000), byPercents: [60]).map(\.raw), [600_000])
        XCTAssertEqual(Kurus.split(.lira(10_000), byPercents: [30, 30]).map(\.raw),
                       [300_000, 300_000])
    }

    /// Kalan dağıtımı BELİRLENİMCİ: aynı girdi her çağrıda aynı çıktıyı verir.
    func testSplitByPercentsIsDeterministic() {
        let ilk = Kurus.split(.kurus(4_123_754_937), byPercents: [33, 33, 34]).map(\.raw)
        for _ in 0..<50 {
            XCTAssertEqual(Kurus.split(.kurus(4_123_754_937), byPercents: [33, 33, 34]).map(\.raw),
                           ilk)
        }
    }

    // MARK: cost — madde 37

    /// Taşma ÇÖKME değil DOYURMA üretmeli.
    ///
    /// KUSUR: `Int64((quantity * Double(unitPrice.raw)).rounded())` aralık
    /// denetlemiyordu. Swift'te aralık dışı `Int64(Double)` sarmalanmaz, TUZAK
    /// ATAR. Çağrı yolu Kaydet düğmesi değildi: `ReceiptSheet.totalAmount` bir
    /// computed property ve `body` içinde okunuyor, yani kullanıcı daha
    /// kaydetmeden ALANA YAZARKEN uygulama kapanıyordu.
    func testCostSaturatesInsteadOfTrapping() {
        let tavanMiktar = 1e12
        let tavanTutar = Kurus.kurus(100_000_000_000_000)
        XCTAssertEqual(Kurus.cost(quantity: tavanMiktar, unitPrice: tavanTutar).raw, Int64.max)
        XCTAssertEqual(Kurus.cost(quantity: 100_000, unitPrice: tavanTutar).raw, Int64.max)
    }

    /// Negatif uçta `Int64.min` ÜRETİLMEMELİ.
    ///
    /// KUSUR: doyurma eklenirken negatif uç `Int64.min` dönüyordu.
    /// `abs(Int64.min)` Swift'te TUZAK ATAR ve `ProjectExporter.money`,
    /// `Fmt.compactMoney`, `Fmt.exactMoney` üçü de `abs` çağırıyor — yani
    /// çökme ortadan kalkmamış, ikinci kez yer değiştirmişti.
    func testCostNeverProducesInt64Min() {
        for q in [-1e12, -100_000.0, -1.0] {
            let sonuc = Kurus.cost(quantity: q, unitPrice: .kurus(100_000_000_000_000))
            XCTAssertNotEqual(sonuc.raw, Int64.min)
            // Biçimlendiriciler tuzak atmadan çalışabilmeli:
            XCTAssertFalse(ProjectExporter.money(sonuc).isEmpty)
            XCTAssertFalse(Fmt.exactMoney(sonuc).isEmpty)
        }
    }

    func testCostRoundsHalfUpPerReceipt() {
        // 12,345 m³ × 2.450,00 ₺ = 30.245,25 ₺
        XCTAssertEqual(Kurus.cost(quantity: 12.345, unitPrice: .kurus(245_000)).raw, 3_024_525)
        XCTAssertEqual(Kurus.cost(quantity: .nan, unitPrice: .lira(100)).raw, 0)
        XCTAssertEqual(Kurus.cost(quantity: .infinity, unitPrice: .lira(100)).raw, 0)
    }
}
