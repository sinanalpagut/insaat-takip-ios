import XCTest
@testable import InsaatTakip

/// Kalan stok ve beklenen hasılat — madde 86.
///
/// NEDEN BU TESTLER VAR: bu rakam ürünün ileriye bakan TEK rakamı ve sessizce
/// eksik çıkması çok kolay. Liste fiyatı girilmemiş bir daire, toplamı hiçbir
/// uyarı vermeden küçültür; kat karşılığı daire ise sayılırsa müteahhide ait
/// olmayan bir değeri onun hasılatı gibi gösterir. İkisi de ekranda doğru
/// görünür.
@MainActor
final class StockOutlookTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Project) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return (vm, vm.projects.first!)
    }

    /// Yardımcı: projedeki daireleri istenen duruma ve bedele getirir.
    private func kurgula(_ vm: ProjectViewModel, _ proje: Project,
                         _ plan: [(Apartment.Status, Int64)]) {
        var kalan = plan
        for i in vm.apartments.indices where vm.apartments[i].projectId == proje.id {
            if kalan.isEmpty {
                vm.apartments[i].status = .landOwner
                vm.apartments[i].price = Kurus.kurus(999_999_00)
                continue
            }
            let (durum, bedel) = kalan.removeFirst()
            vm.apartments[i].status = durum
            vm.apartments[i].price = Kurus.kurus(bedel)
        }
    }

    /// ÜÇ KOVA AYRI: satılan gerçekleşti, rezerve kesinleşmedi, boş bir HEDEF.
    func testThreeBucketsStaySeparate() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.sold, 100_00), (.sold, 200_00),
                            (.reserved, 50_00),
                            (.available, 30_00), (.available, 40_00)])

        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.soldTotal, Kurus.kurus(300_00))
        XCTAssertEqual(o.reservedTotal, Kurus.kurus(50_00))
        XCTAssertEqual(o.availableTotal, Kurus.kurus(70_00))
        XCTAssertEqual(o.reservedCount, 1)
        XCTAssertEqual(o.availableCount, 2)
        XCTAssertEqual(o.expected, Kurus.kurus(420_00))
    }

    /// KAT KARŞILIĞI DAİRE HİÇBİR KOVAYA GİRMEZ.
    ///
    /// Arsa sahibinin ve bedelsiz; beklenen hasılata katmak, müteahhide ait
    /// olmayan bir değeri onun geliri gibi göstermek olurdu. Kurgu, kalan tüm
    /// daireleri 999.999 ₺'lik kat karşılığı yapıyor — sızarsa toplam patlar.
    func testLandOwnerNeverCounts() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.sold, 100_00)])

        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.expected, Kurus.kurus(100_00),
                       "kat karşılığı daire beklenen hasılata sızdı")
        XCTAssertEqual(o.availableCount, 0)
    }

    /// FİYATI GİRİLMEMİŞ DAİRE SAYILIYOR VE TOPLAMA GİRMİYOR.
    ///
    /// Rakamın eksik olduğunu söylemek, eksik rakamı doğru göstermekten daha
    /// önemli: 10 boş dairenin 7'sine fiyat girilmemişse toplam sessizce
    /// küçülür ve hiçbir şey bunu söylemez.
    func testApartmentsWithoutListPriceAreCountedNotSummed() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.available, 40_00), (.available, 0), (.available, 0)])

        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.availableCount, 3, "fiyatsız daire de stoktur")
        XCTAssertEqual(o.pricelessCount, 2)
        XCTAssertEqual(o.availableTotal, Kurus.kurus(40_00))
        XCTAssertFalse(o.isComplete, "eksik rakam TAM sayılmamalı")
    }

    /// Hepsinin fiyatı varsa rakam TAM.
    func testCompleteWhenEveryUnitIsPriced() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.available, 10_00), (.available, 20_00)])
        XCTAssertTrue(vm.stockOutlook(for: proje.id).isComplete)
    }

    /// Boş projede rakam SIFIR, çökme yok.
    func testEmptyProjectIsZero() {
        let (vm, proje) = kur()
        for i in vm.apartments.indices where vm.apartments[i].projectId == proje.id {
            vm.apartments[i].status = .landOwner
        }
        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.expected, .zero)
        XCTAssertTrue(o.isComplete, "hiç boş daire yoksa eksik de yok")
    }

    /// Beklenen hasılat, ciro rakamıyla TUTARLI olmalı.
    ///
    /// `totalSales` de yalnızca satılanı sayıyor; ikisi ayrışırsa aynı ekranda
    /// iki farklı "ciro" görünürdü.
    func testSoldTotalMatchesExistingRevenueFigure() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.sold, 150_00), (.sold, 250_00), (.available, 90_00)])
        XCTAssertEqual(vm.stockOutlook(for: proje.id).soldTotal,
                       vm.totalSales(for: proje.id))
    }
}
