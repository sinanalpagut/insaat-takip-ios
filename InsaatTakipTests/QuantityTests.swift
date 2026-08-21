import XCTest
@testable import InsaatTakip

/// Miktar girdisi ve forma geri yazımı.
///
/// İkisi de PARA tarafında çözülmüş, miktar tarafında atlanmış kusurlardı —
/// üstelik `ReceiptSheet`in düzenleme formunda yan yana duruyorlardı: birim
/// fiyat doğru formatlayıcıyla, miktar yuvarlayanla dolduruluyordu.
@MainActor
final class QuantityTests: XCTestCase {

    // MARK: parseQuantity — ondalık yutulması

    /// Ondalık ayraç KORUNMALI.
    ///
    /// KUSUR: `parseQuantity` doğrudan `parseNumber`a bağlıydı ve o TÜM
    /// noktaları koşulsuz siliyor. Cihaz dili Türkçe değilse ondalık tuşundan
    /// gelen "12.5" 125 oluyordu — sessiz 10 kat hata. `parseMoney` bu kusur
    /// için düzeltilmiş, miktar tarafı kapatılmamıştı.
    func testParseQuantityKeepsDecimals() {
        XCTAssertEqual(ProjectViewModel.parseQuantity("12,5"), 12.5, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("12.5"), 12.5, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("12,345"), 12.345, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("0,125"), 0.125, accuracy: 1e-9)
    }

    /// Binlik ayraç binlik kalmalı — ondalık sanılmamalı.
    func testParseQuantityKeepsThousands() {
        XCTAssertEqual(ProjectViewModel.parseQuantity("12.500"), 12_500, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("1.234.567"), 1_234_567, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("48.000"), 48_000, accuracy: 1e-9)
    }

    /// İki ayraç birden varsa SONUNCUSU ondalıktır.
    func testParseQuantityMixedSeparators() {
        XCTAssertEqual(ProjectViewModel.parseQuantity("1.234,5"), 1234.5, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("1,234.5"), 1234.5, accuracy: 1e-9)
    }

    /// Üst simge rakam sayıya KARIŞMAMALI.
    ///
    /// Swift'te `Character("²").isNumber` TRUE döndürüyor; alan m² yazımına
    /// açık olduğu için süzgeç ASCII'ye bağlandı. (Aynı tuzak daire alanı
    /// göçünde bir kez veriyi sessizce bozmuştu.)
    func testParseQuantityIgnoresSuperscriptDigits() {
        XCTAssertTrue(Character("²").isNumber, "Swift davranışı değişmiş — testin öncülü geçersiz")
        XCTAssertEqual(ProjectViewModel.parseQuantity("12²"), 12, accuracy: 1e-9)
        XCTAssertEqual(ProjectViewModel.parseQuantity("95 m²"), 95, accuracy: 1e-9)
    }

    func testParseQuantityDegenerate() {
        XCTAssertEqual(ProjectViewModel.parseQuantity(""), 0)
        XCTAssertEqual(ProjectViewModel.parseQuantity("abc"), 0)
        XCTAssertEqual(ProjectViewModel.parseQuantity(","), 0)
        XCTAssertEqual(ProjectViewModel.parseQuantity("-5"), 5, accuracy: 1e-9)  // işaret süzülüyor
    }

    // MARK: qtyText — forma geri yazım

    /// Forma yazılan metin, GERİ OKUNDUĞUNDA aynı değeri vermeli.
    ///
    /// KUSUR: form `Fmt.qty` ile dolduruluyordu ve o `rounded()` uyguluyor.
    /// 12,5 m³'lük fiş açılınca kutuda "13" beliriyor, kaydedince gerçekten
    /// 13 m³ oluyordu. Denetim izi de aynı yuvarlanmış metni kullandığı için
    /// satır "13 m³ → 13 m³" görünüyor, kaybın izi bile kalmıyordu.
    /// Aynısı daire alanında da vardı: 111,55 m² → 112.
    func testQtyTextRoundTripsThroughTheForm() {
        for deger in [12.5, 111.55, 0.125, 48_000, 12.345, 1234.5] {
            let formaYazilan = Fmt.qtyText(deger)
            let geriOkunan = ProjectViewModel.parseQuantity(formaYazilan)
            XCTAssertEqual(geriOkunan, deger, accuracy: 1e-9,
                           "\(deger) → \"\(formaYazilan)\" → \(geriOkunan)")
        }
    }

    /// `qty` GÖSTERİM için yuvarlamaya devam ediyor — bu bilinçli, listede
    /// "3.224 kg" yazmak doğru. Ayrım korunmalı ki biri diğerinin yerine
    /// kullanılmasın.
    func testQtyStillRoundsForDisplay() {
        XCTAssertEqual(Fmt.qty(12.5), "13")
        XCTAssertEqual(Fmt.qtyText(12.5), "12,5")
    }
}
