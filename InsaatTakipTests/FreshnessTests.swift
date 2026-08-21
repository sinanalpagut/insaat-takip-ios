import XCTest
@testable import InsaatTakip

/// Verinin tazeliği — madde 54.
@MainActor
final class FreshnessTests: XCTestCase {

    private func an(_ y: Int, _ a: Int, _ g: Int, _ s: Int, _ d: Int) -> Date {
        Fmt.calendar.date(from: DateComponents(year: y, month: a, day: g, hour: s, minute: d))!
    }

    /// Hiç yüklenmemişse bunu SÖYLEMELİ.
    ///
    /// KUSUR: alt başlık `Fmt.clock()`u varsayılanıyla çağırıyordu (`Date()`),
    /// yani her çizimde O ANKİ SAATİ yazıyordu. Uygulama veriyi yalnızca soğuk
    /// açılışta çektiği için satır, en çok yanıltıcı olabileceği anda
    /// yanıltıyordu: ortak yöneticinin az önce girdiği satışı göremezken ekran
    /// ona verinin taze olduğunu söylüyordu.
    func testNeverLoadedIsStated() {
        XCTAssertEqual(ProjectViewModel.freshnessText(nil), "sunucudan henüz yüklenmedi")
    }

    func testJustNow() {
        let simdi = an(2026, 8, 21, 14, 30)
        XCTAssertEqual(ProjectViewModel.freshnessText(simdi.addingTimeInterval(-5), now: simdi),
                       "az önce güncellendi")
        XCTAssertEqual(ProjectViewModel.freshnessText(simdi.addingTimeInterval(-89), now: simdi),
                       "az önce güncellendi")
    }

    /// 90 saniyeyi geçince SAAT yazılmalı — "az önce" demeye devam etmek,
    /// düzeltilen kusurun daha yumuşak hali olurdu.
    func testSameDayShowsClock() {
        let simdi = an(2026, 8, 21, 14, 30)
        let metin = ProjectViewModel.freshnessText(an(2026, 8, 21, 9, 15), now: simdi)
        XCTAssertTrue(metin.contains("09:15"), metin)
        XCTAssertTrue(metin.hasSuffix("güncellendi"), metin)
        XCTAssertFalse(metin.contains("az önce"), metin)
    }

    func testYesterday() {
        let simdi = an(2026, 8, 21, 14, 30)
        let metin = ProjectViewModel.freshnessText(an(2026, 8, 20, 9, 15), now: simdi)
        XCTAssertTrue(metin.hasPrefix("dün"), metin)
        XCTAssertTrue(metin.contains("09:15"), metin)
    }

    /// GÜN SINIRI SAATE DEĞİL TAKVİME BAKMALI: gece 00:10'da açılan uygulamada
    /// 23:50'de yüklenen veri "az önce" değil DÜN'dür. Saat farkına bakan bir
    /// eşik (20 dakika) burada yanlış cevap verirdi.
    func testDayBoundaryUsesCalendarNotElapsedTime() {
        let simdi = an(2026, 8, 21, 0, 10)
        let metin = ProjectViewModel.freshnessText(an(2026, 8, 20, 23, 50), now: simdi)
        XCTAssertTrue(metin.hasPrefix("dün"), metin)
    }

    func testOlderShowsDate() {
        let simdi = an(2026, 8, 21, 14, 30)
        let metin = ProjectViewModel.freshnessText(an(2026, 8, 12, 9, 15), now: simdi)
        XCTAssertTrue(metin.contains("tarihinde güncellendi"), metin)
        XCTAssertFalse(metin.contains("dün"), metin)
    }
}
