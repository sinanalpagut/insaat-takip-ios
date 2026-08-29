import XCTest
@testable import InsaatTakip

/// Liste araması ve dönem süzgeci — madde 79.
///
/// NEDEN BU TESTLER VAR: arama sessizce YANLIŞ ÇALIŞAN bir şey. "Sonuç yok"
/// ekranı hem "böyle bir kayıt yok" hem "arama bozuk" durumunda aynı görünür;
/// kullanıcı ikisini ayırt edemez ve kaydın silindiğini sanabilir.
final class ListSearchTests: XCTestCase {

    // MARK: Arama

    /// TÜRKÇE KÜÇÜLTME TUZAĞI.
    ///
    /// `"İRSALİYE".lowercased()` varsayılan yerel ayarda birleşik noktalı bir
    /// "i̇" üretiyor ve kullanıcının yazdığı "irsaliye" ile eşleşmiyor.
    func testTurkishCaseFolding() {
        XCTAssertTrue(ListSearch.matches("irsaliye", in: ["İRSALİYE #4471"]))
        XCTAssertTrue(ListSearch.matches("İRSALİYE", in: ["irsaliye #4471"]))
        XCTAssertTrue(ListSearch.matches("YILMAZ", in: ["Yılmaz Yapı"]))
    }

    /// NOKTALI/NOKTASIZ i AYRIMI ARAMADA KALKIYOR.
    ///
    /// Türkçede nokta harfi değiştiriyor ama kullanıcı arama kutusunda hangi
    /// i'yi yazdığını hatırlamak zorunda değil. Dördü de ("i", "ı", "İ", "I")
    /// aynı harfe iniyor.
    func testDottedAndDotlessIAreInterchangeable() {
        XCTAssertTrue(ListSearch.matches("yil", in: ["yıl sonu"]))
        XCTAssertTrue(ListSearch.matches("yıl", in: ["YIL SONU"]))
        XCTAssertTrue(ListSearch.matches("ISKONTO", in: ["İskonto"]))
        XCTAssertTrue(ListSearch.matches("ıskonto", in: ["iskonto"]))
    }

    /// AKSAN KATLAMA — Türkçe karakter yazmayı şart koşmak, aramanın işini
    /// kullanıcıya devretmek olurdu.
    func testDiacriticFolding() {
        XCTAssertTrue(ListSearch.matches("cimento", in: ["Çimento"]))
        XCTAssertTrue(ListSearch.matches("sirket", in: ["Şirket Ödemesi"]))
        XCTAssertTrue(ListSearch.matches("Çimento", in: ["cimento"]))
        XCTAssertTrue(ListSearch.matches("ogutucu", in: ["Öğütücü"]))
    }

    /// BOŞ SORGU HER ŞEYİ EŞLEŞTİRİR — süzgeç yokken liste kırpılmamalı.
    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(ListSearch.matches("", in: ["herhangi"]))
        XCTAssertTrue(ListSearch.matches("   ", in: ["herhangi"]))
    }

    /// Alanlardan HERHANGİ BİRİ yeterli; hiçbiri tutmazsa eşleşme yok.
    func testAnyFieldMatches() {
        let alanlar = ["Taşeron", "Demir A.Ş.", "3. kat kalıp"]
        XCTAssertTrue(ListSearch.matches("demir", in: alanlar))
        XCTAssertTrue(ListSearch.matches("kalıp", in: alanlar))
        XCTAssertFalse(ListSearch.matches("beton", in: alanlar))
    }

    // MARK: Dönem

    private func gun(_ y: Int, _ a: Int, _ g: Int) -> Date {
        Fmt.calendar.date(from: DateComponents(year: y, month: a, day: g))!
    }

    func testPeriodAllAlwaysMatches() {
        XCTAssertTrue(ListPeriod.tumu.contains(gun(2020, 1, 1), now: gun(2026, 8, 25)))
    }

    func testThisMonth() {
        let now = gun(2026, 8, 25)
        XCTAssertTrue(ListPeriod.buAy.contains(gun(2026, 8, 1), now: now))
        XCTAssertTrue(ListPeriod.buAy.contains(gun(2026, 8, 31), now: now))
        XCTAssertFalse(ListPeriod.buAy.contains(gun(2026, 7, 31), now: now))
    }

    /// "SON 3 AY" TAKVİM AYIDIR, 90 GÜN DEĞİL.
    ///
    /// Gün sayısıyla hesaplamak ayın 31'inde farklı, 1'inde farklı bir
    /// pencere verirdi; müteahhit "son 3 ay" derken takvim aylarını
    /// kastediyor.
    func testLastThreeMonthsIsCalendarBased() {
        let now = gun(2026, 8, 25)
        XCTAssertTrue(ListPeriod.sonUcAy.contains(gun(2026, 6, 1), now: now),
                      "haziran başı kapsamda olmalı")
        XCTAssertTrue(ListPeriod.sonUcAy.contains(gun(2026, 8, 25), now: now))
        XCTAssertFalse(ListPeriod.sonUcAy.contains(gun(2026, 5, 31), now: now),
                       "mayıs sonu kapsam dışı")
    }

    /// GELECEK TARİH KAPSAM DIŞI — vadesi gelmemiş bir kayıt "son 3 ayda
    /// harcadıklarım" listesinde görünmemeli.
    func testFutureDateIsOutsideRecentWindow() {
        let now = gun(2026, 8, 25)
        XCTAssertFalse(ListPeriod.sonUcAy.contains(gun(2026, 9, 10), now: now))
    }

    func testThisYear() {
        let now = gun(2026, 8, 25)
        XCTAssertTrue(ListPeriod.buYil.contains(gun(2026, 1, 1), now: now))
        XCTAssertFalse(ListPeriod.buYil.contains(gun(2025, 12, 31), now: now))
    }
}
