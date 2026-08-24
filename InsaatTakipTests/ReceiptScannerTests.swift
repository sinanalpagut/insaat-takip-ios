import XCTest
@testable import InsaatTakip

/// Fiş okuyucunun toplam bulma kuralı.
///
/// NEDEN BU TESTLER VAR: okuyucu iki gerçek fişte de YANLIŞ toplam üretti ve
/// yanlış değeri ekranda "FİŞTEN OKUNDU · Toplam 1 ₺" diye KESİN bir cümleyle
/// gösterdi. Kullanıcı "Uygula"ya bastığında o değer doğrudan birim fiyata
/// dönüşüyor — yani okuma hatası sessizce paraya dönüşüyor.
///
/// Kök neden fişin içeriği değil, DÜZENİ: fiş iki sütunlu (solda etiket, sağda
/// tutar) ve Vision bunu satır satır okumuyor; önce sol sütunun tamamını,
/// sonra sağ sütunun tamamını veriyor. "Bir sonraki satıra bak" kuralı bu
/// yüzden bir sonraki ETİKETİ okuyordu.
///
/// Aşağıdaki diziler o düzeni birebir taklit ediyor ama içerik uydurma:
/// gerçek fişler kişisel veri ve bu depo herkese açık.
final class ReceiptScannerTests: XCTestCase {

    private func total(_ lines: [String]) -> Kurus? {
        ReceiptScanner.parse(lines: lines).total
    }

    /// İKİ SÜTUN — etiketler önce, tutarlar sonra.
    ///
    /// Ölçülen hata: "TOPLAM"ın hemen altındaki satır KDV tutarıydı, toplam
    /// değil. 340,00 yerine 30,91 okunuyordu.
    func testTwoColumnLayoutPicksTotalNotVat() {
        let lines = ["TOPKDV", "TOPLAM", "*30,91", "*340,00"]
        XCTAssertEqual(total(lines), Kurus.kurus(34_000))
    }

    /// ETİKET SATIRINDAKİ RAKAM TUTAR DEĞİLDİR.
    ///
    /// Ölçülen hata: "Ödenecek KDV Dahil Tutar"ın altındaki satır
    /// "Banka Kredi Kartı (1)" idi; parantezdeki 1, toplam sanıldı ve ekranda
    /// "Toplam 1 ₺" yazdı. Gerçek toplam 399,00'du.
    func testLabelLineDigitsAreNotAmounts() {
        let lines = [
            "TOPLAM KDV",
            "Odenecek KDV Dahil Tutar",
            "Banka Kredi Karti (1)",
            "*398,00", "*1,00", "*66,50", "*399,00",
        ]
        XCTAssertEqual(total(lines), Kurus.kurus(39_900))
    }

    /// Tutar etiketle AYNI satırdaysa eski yol bozulmamalı.
    func testSameLineAmountStillWins() {
        XCTAssertEqual(total(["GENEL TOPLAM: 1.250,00"]), Kurus.kurus(125_000))
    }

    /// KDV satırı toplam sanılmamalı — var olan kuralın koruması.
    func testVatLineIsSkipped() {
        let lines = ["TOPLAM KDV *66,50", "TOPLAM", "*399,00"]
        XCTAssertEqual(total(lines), Kurus.kurus(39_900))
    }

    /// UZAKTAKİ BÜYÜK TUTAR KAPSAMA GİRMEMELİ.
    ///
    /// Fişin altında kart bakiyesi gibi toplamdan BÜYÜK sayılar bulunuyor.
    /// Pencere dar olmasaydı "en büyüğü al" kuralı bakiyeyi toplam sanardı.
    func testFarAwayLargerAmountIsIgnored() {
        var lines = ["TOPLAM", "*340,00"]
        lines += Array(repeating: "MUSTERI NUSHASI", count: 8)
        lines += ["BAKIYE:", "3.935,51 TL"]
        XCTAssertEqual(total(lines), Kurus.kurus(34_000))
    }

    /// Yalnızca-tutar ayrımı: harf içeren satır etikettir.
    func testAmountOnlyRecognition() {
        XCTAssertTrue(ReceiptScanner.isAmountOnly("*340,00"))
        XCTAssertTrue(ReceiptScanner.isAmountOnly("399,00 TL"))
        XCTAssertFalse(ReceiptScanner.isAmountOnly("Banka Kredi Karti (1)"))
        XCTAssertFalse(ReceiptScanner.isAmountOnly("TOPLAM"))
    }

    /// Hiçbir anahtar kelime yoksa: kuruşlu en büyük sayı.
    func testFallbackToLargestDecimal() {
        XCTAssertEqual(total(["Kalem A *12,00", "Kalem B *8,50"]), Kurus.kurus(1_200))
    }
}
