import XCTest
@testable import InsaatTakip

/// Dışa aktarma — madde 26, 40, 41, 44, 45, 48.
///
/// Bu dosyadaki kusurların ortak özelliği: dosya KENDİ İÇİNDE tutarlı
/// görünüyordu, ama ekranla aynı adı taşıyan rakamlar farklı şeyleri sayıyordu.
final class ExporterTests: XCTestCase {

    // MARK: money — madde 48

    /// Negatif tutarlarda eksi işareti KAYBOLMAMALI.
    ///
    /// KUSUR: `lira = raw / 100` tam sayı bölmesi sıfıra doğru kırptığı için
    /// −1..−99 kuruş aralığında lira kısmı 0 oluyor, `abs` da kuruşu pozitife
    /// çeviriyordu: `-50` → `"0,50"`. Bir zarar rakamı dosyada kâra dönüşüyordu.
    func testMoneyKeepsNegativeSign() {
        XCTAssertEqual(ProjectExporter.money(.kurus(-1)), "-0,01")
        XCTAssertEqual(ProjectExporter.money(.kurus(-50)), "-0,50")
        XCTAssertEqual(ProjectExporter.money(.kurus(-99)), "-0,99")
        XCTAssertEqual(ProjectExporter.money(.kurus(-100)), "-1,00")
        XCTAssertEqual(ProjectExporter.money(.kurus(-12345)), "-123,45")
        XCTAssertEqual(ProjectExporter.money(.kurus(50)), "0,50")
        XCTAssertEqual(ProjectExporter.money(.zero), "0,00")
    }

    // MARK: field — madde 44

    /// CRLF içeren alan TIRNAKLANMALI.
    ///
    /// KUSUR: Swift'te `"\r\n"` TEK grapheme kümesi, dolayısıyla
    /// `text.contains("\n")` CRLF içeren metinde **false** dönüyor. Excel'den
    /// kopyalanmış iki satırlık bir açıklama (Excel CRLF kullanır)
    /// tırnaklanmadan yazılıyordu: satır ikiye bölünüyor ve o noktadan sonraki
    /// BÜTÜN sütunlar kayıyordu.
    func testFieldQuotesAllLineBreakForms() {
        let crlf = "İrsaliye #4471\r\nYılmaz Yapı"
        XCTAssertFalse(crlf.contains("\n"), "Swift davranışı değişmiş — testin öncülü geçersiz")
        XCTAssertTrue(ProjectExporter.field(crlf).hasPrefix("\""), "CRLF tırnaklanmadı")

        XCTAssertTrue(ProjectExporter.field("a\nb").hasPrefix("\""))
        XCTAssertTrue(ProjectExporter.field("a\rb").hasPrefix("\""))
        XCTAssertTrue(ProjectExporter.field("a;b").hasPrefix("\""))
        XCTAssertTrue(ProjectExporter.field("a\"b").hasPrefix("\""))
        XCTAssertEqual(ProjectExporter.field("düz metin"), "düz metin")
        // İçerideki tırnak ikilenir.
        XCTAssertEqual(ProjectExporter.field("a\"b"), "\"a\"\"b\"")
    }

    // MARK: quantity — madde 45

    /// Miktar TAM yazılmalı, 2 ondalığa kırpılmamalı.
    ///
    /// KUSUR: "Tutar" sütunu `Kurus.cost` ile TAM miktardan hesaplanıyor ama
    /// "Miktar" 2 ondalığa kırpılıyordu; Excel'de `=Miktar*BirimFiyat` satırdaki
    /// Tutar'ı vermiyordu. Dışa aktarma bir VERİ dosyası — gösterim kısaltması
    /// ekranın işi, dosyanın değil.
    func testQuantityIsExactSoRowsSelfVerify() {
        XCTAssertEqual(ProjectExporter.quantity(12.345), "12,345")
        XCTAssertEqual(ProjectExporter.quantity(48_000), "48000")
        XCTAssertEqual(ProjectExporter.quantity(0.125), "0,125")
        XCTAssertEqual(ProjectExporter.quantity(.nan), "")

        // Satır kendi içinde tutuyor mu: Miktar × Birim Fiyat = Tutar
        let miktar = 12.345
        let birimFiyat = Kurus.kurus(245_000)
        let tutar = Kurus.cost(quantity: miktar, unitPrice: birimFiyat)
        let yazilanMiktar = Double(ProjectExporter.quantity(miktar)
            .replacingOccurrences(of: ",", with: "."))!
        XCTAssertEqual(Kurus.cost(quantity: yazilanMiktar, unitPrice: birimFiyat).raw, tutar.raw,
                       "dosyadaki miktar, tutarı geri üretmiyor")
    }

    // MARK: Fmt.exactMoney — madde 43

    /// Rapor kartının satırları birbirinden ÇIKARILIYOR; gösterim yuvarlaması
    /// aritmetiği bozmamalı.
    ///
    /// KUSUR: her satır ayrı ayrı `compactMoney`den geçiyordu (milyonda iki
    /// ondalık = satır başına 5.000 ₺'ye kadar sapma). 200.000 rastgele dönem
    /// özetinde ortağın kâğıt üstündeki çıkarması %33 oranında kartla
    /// tutmuyordu. Kart ortaklara PDF olarak dağıtılıyor.
    func testExactMoneyPreservesArithmetic() {
        let satis = Kurus.kurus(5_301_595_691)
        let malzeme = Kurus.kurus(601_071_364)
        let diger = Kurus.kurus(1_285_310_972)
        let net = satis - (malzeme + diger)

        // Gösterilen değerler ham değerlerden geri okunabilmeli.
        func geriOku(_ s: String) -> Int64 {
            let temiz = s.replacingOccurrences(of: " ₺", with: "")
                .replacingOccurrences(of: "−", with: "-")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Int64((Double(temiz)! * 100).rounded())
        }
        XCTAssertEqual(geriOku(Fmt.exactMoney(satis)), satis.raw)
        XCTAssertEqual(geriOku(Fmt.exactMoney(malzeme)), malzeme.raw)
        XCTAssertEqual(geriOku(Fmt.exactMoney(diger)), diger.raw)
        XCTAssertEqual(geriOku(Fmt.exactMoney(satis)) - geriOku(Fmt.exactMoney(malzeme))
                       - geriOku(Fmt.exactMoney(diger)), net.raw,
                       "ekrandaki rakamlarla yapılan çıkarma net'i vermiyor")
        XCTAssertTrue(Fmt.exactMoney(.kurus(-50)).hasPrefix("−"))
    }

    /// GİDER SÜTUNU KİŞİ ADINI "ÖDENEN" DİYE SUNMAMALI.
    ///
    /// Sütunda `payee` var ("Şantiye ekibi") ve hemen "Tutar"ın yanında
    /// duruyor; başlık "Ödenen" olduğunda dosyayı açan mali müşavir ikisini
    /// "ödenen tutar" diye okuyabiliyordu. Üstelik model ödemeyi zaten
    /// garanti etmiyor (madde 81): kayıt tahakkuk esaslı.
    func testExpenseCSVNamesThePayeeColumnHonestly() {
        let gider = Expense(id: UUID(), projectId: UUID(), category: .iscilik,
                            amount: Kurus.lira(1_240_000), date: Date(),
                            payee: "Şantiye ekibi", note: "Ağustos puantajı",
                            user: "Mehmet Kılıç")
        let baslik = ProjectExporter.expensesCSV([gider]).components(separatedBy: "\r\n")[0]
        XCTAssertTrue(baslik.contains("Kime Ödendi"), "başlık: \(baslik)")
        XCTAssertFalse(baslik.contains(";Ödenen;"), "kişi sütunu 'Ödenen' diye adlandırılmamalı")
    }

}
