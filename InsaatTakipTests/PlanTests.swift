import XCTest
@testable import InsaatTakip

/// Abonelik paketleri — madde 87.
///
/// NEDEN BU TESTLER VAR: fiyat etiketi, kullanıcının parasını verdiği sözdür.
/// Yanlış bir rakam ekranda "kampanya" gibi görünmez, SÖZÜN İHLALİ olur — ve
/// bu kod tabanının bütün para politikası (bkz. `Kurus`) tam da rakamın
/// sessizce kaymasını engellemek üzerine kurulu.
///
/// Katalogdaki rakamlar ELLE yazılı (çarpma operatörü bilerek yok). Kuralı
/// koruyan şey o yüzden burası: "yıllık = on ay" kararı, katalogdaki iki
/// sayının ilişkisi olarak değil, bu testin iddiası olarak yaşıyor.
final class PlanTests: XCTestCase {

    /// YILLIK = ON AYIN FİYATI. "İki ay bedava" sözü buradan geliyor.
    func testYearlyIsTenMonths() {
        for plan in Plan.purchasable {
            guard let aylik = plan.monthlyPrice, let yillik = plan.yearlyPrice else {
                return XCTFail("\(plan.rawValue): satın alınabilir pakette fiyat yok")
            }
            XCTAssertEqual(yillik.raw, aylik.raw * 10,
                           "\(plan.rawValue) yıllığı on ayı tutmuyor — "
                           + "aylık \(Fmt.money(aylik)), yıllık \(Fmt.money(yillik))")
        }
    }

    /// Onaylanan fiyatlar (15 Eki 2026). Rakamlar testte YAZILI: katalogdaki
    /// bir değişiklik buraya da dokunmayı gerektirsin, sessizce geçmesin.
    func testApprovedPrices() {
        XCTAssertNil(Plan.ucretsiz.monthlyPrice)
        XCTAssertEqual(Plan.santiye.monthlyPrice, Kurus.lira(749))
        XCTAssertEqual(Plan.muteahhit.monthlyPrice, Kurus.lira(1_499))
        XCTAssertEqual(Plan.kurumsal.monthlyPrice, Kurus.lira(4_999))
        XCTAssertEqual(Plan.kurumsal.yearlyPrice, Kurus.lira(49_990))
    }

    /// PAKET BÜYÜDÜKÇE SINIR DA BÜYÜMELİ.
    ///
    /// Daha pahalı bir pakette daha az proje olması, satın alan kişiyi
    /// cezalandırmak olurdu. Elle yazılmış bir katalogda bu, tek bir yanlış
    /// rakamla olur.
    func testLimitsGrowWithPrice() {
        let sirali: [Plan] = [.ucretsiz, .santiye, .muteahhit, .kurumsal]
        var oncekiSinir = 0
        for plan in sirali {
            guard let sinir = plan.activeProjectLimit else {
                XCTAssertEqual(plan, .kurumsal, "sınırsız olan yalnızca en üst paket olmalı")
                continue
            }
            XCTAssertGreaterThan(sinir, oncekiSinir,
                                 "\(plan.rawValue) kendinden ucuz pakete göre daha dar")
            oncekiSinir = sinir
        }
    }

    /// ORTAK SINIRI YALNIZCA ÜCRETSİZ KATMANDA.
    ///
    /// Ücretli pakette ortak başına ücret ALINMIYOR; sınır koymak kişi başına
    /// ücretin kılık değiştirmiş hâli olurdu.
    func testOnlyFreeTierLimitsPartners() {
        XCTAssertEqual(Plan.ucretsiz.invitedPartnerLimit, 2)
        for plan in Plan.purchasable {
            XCTAssertNil(plan.invitedPartnerLimit,
                         "\(plan.rawValue) ortak sınırı koyuyor — kişi başına ücret yok")
        }
    }

    /// ÜRÜN KİMLİKLERİ BENZERSİZ VE PAKET ADINI TAŞIYOR.
    ///
    /// Kimlikler App Store Connect'e ELLE giriliyor; tek harf farkı satın
    /// almanın sessizce çalışmaması demek. Çakışma ise iki paketin aynı ürüne
    /// bağlanması — kullanıcı ödediğinden başkasını alır.
    func testProductIdsAreUniqueAndNamed() {
        var gorulen = Set<String>()
        for plan in Plan.purchasable {
            for id in [plan.monthlyProductId, plan.yearlyProductId].compactMap({ $0 }) {
                XCTAssertTrue(id.contains(plan.rawValue), "\(id) paket adını taşımıyor")
                XCTAssertTrue(gorulen.insert(id).inserted, "ürün kimliği çakıştı: \(id)")
            }
        }
        XCTAssertNil(Plan.ucretsiz.monthlyProductId, "ücretsiz katmanın ürünü olmamalı")
        XCTAssertEqual(gorulen.count, 6, "üç pakette aylık+yıllık altı ürün bekleniyor")
    }

    /// Ücretsiz katman `Entitlement.free` ile aynı şey.
    func testFreeEntitlementMapsToFreePlan() {
        XCTAssertEqual(Entitlement.free, .plan(.ucretsiz))
        XCTAssertEqual(Entitlement.free.activeProjectLimit, 1)
        XCTAssertEqual(Entitlement.free.invitedPartnerLimit, 2)
    }

    /// EN ÜST PAKET SINIRSIZ: kurumsalda proje sayısı sayılmıyor.
    func testKurumsalHasNoProjectLimit() {
        XCTAssertNil(Entitlement.plan(.kurumsal).activeProjectLimit)
        XCTAssertEqual(Quota.canCreateProject(QuotaSnapshot(activeProjects: 250),
                                              entitlement: .plan(.kurumsal)), .allowed)
    }
}
