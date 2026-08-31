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
        // BAŞLANGIÇ DURUMUNU TEST KURAR: demo veride ilk projenin kalan maliyet
        // tahmini DOLU geliyor (kartın dolu hâli demo'da da görülsün diye).
        // Testin "girilmemiş" varsayımını tohum verisine bırakmak, tohum
        // değiştiği an testi sessizce anlamsızlaştırırdı.
        vm.projects[0].remainingCostEstimate = nil
        return (vm, vm.projects[0])
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

    // MARK: - Bitirmenin maliyeti (madde 86, ikinci yarı)

    /// KALAN MALİYET GİRİLMEMİŞSE SONUÇ YOK.
    ///
    /// En kolay hata bu olurdu: nil'i sıfır sayıp "hasılat − harcanan"
    /// rakamını sonuç diye göstermek. Temeli yeni atılmış bir projede o rakam
    /// kocaman bir kâr gibi görünür ve ortağa PDF olarak gider.
    func testProjectedResultIsNilWhenEstimateMissing() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.sold, 1_000_00), (.available, 500_00)])
        let o = vm.stockOutlook(for: proje.id)
        XCTAssertNil(o.remainingCost)
        XCTAssertNil(o.projectedResult, "Girilmemiş tahmin sıfır sayılmamalı")
        XCTAssertEqual(o.expected, Kurus.kurus(1_500_00))
    }

    /// Sonuç = beklenen hasılat − harcanan − kalan tahmini.
    func testProjectedResultSubtractsSpentAndRemaining() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.sold, 1_000_00), (.available, 500_00)])
        vm.expenses.removeAll { $0.projectId == proje.id }
        vm.materials.removeAll { $0.projectId == proje.id }
        _ = vm.addExpense(role: .admin, projectId: proje.id, category: .diger,
                          amountText: "300", payee: "Beton", note: "",
                          date: Date())
        vm.updateProgress(role: .admin, projectId: proje.id, progress: 40,
                          phase: .kabaInsaat, remainingCostText: "700")

        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.spentToDate, Kurus.kurus(300_00))
        XCTAssertEqual(o.remainingCost, Kurus.kurus(700_00))
        // 1500 − 300 − 700 = 500
        XCTAssertEqual(o.projectedResult, Kurus.kurus(500_00))
    }

    /// SONUÇ EKSİYE DÜŞEBİLİR ve düşmeli: zarara giden projeyi rakam söylemeli.
    func testProjectedResultCanBeNegative() {
        let (vm, proje) = kur()
        kurgula(vm, proje, [(.sold, 100_00)])
        vm.expenses.removeAll { $0.projectId == proje.id }
        vm.materials.removeAll { $0.projectId == proje.id }
        vm.updateProgress(role: .admin, projectId: proje.id, progress: 10,
                          phase: .temel, remainingCostText: "5.000")
        let o = vm.stockOutlook(for: proje.id)
        XCTAssertNotNil(o.projectedResult)
        XCTAssertTrue(o.projectedResult! < .zero, "Zarar gizlenmemeli")
    }

    /// BOŞ METİN "0" DEĞİL, "SİL" DEMEK.
    ///
    /// `parseMoney("")` sıfır döndürüyor; alanı boşaltan kullanıcı sıfır
    /// maliyet iddia etmiş olsaydı ekranda hemen bir "beklenen sonuç" belirir
    /// ve o sonuç kalan tüm inşaatı bedava sayardı.
    func testEmptyTextClearsEstimateInsteadOfZeroing() {
        let (vm, proje) = kur()
        vm.updateProgress(role: .admin, projectId: proje.id, progress: 50,
                          phase: .kabaInsaat, remainingCostText: "1.200")
        XCTAssertEqual(vm.projects.first { $0.id == proje.id }?.remainingCostEstimate,
                       Kurus.kurus(1_200_00))

        vm.updateProgress(role: .admin, projectId: proje.id, progress: 60,
                          phase: .kabaInsaat, remainingCostText: "   ")
        XCTAssertNil(vm.projects.first { $0.id == proje.id }?.remainingCostEstimate)
        XCTAssertNil(vm.stockOutlook(for: proje.id).projectedResult)
    }

    /// SIFIR GİRİLEBİLİR ve nil'den AYRI durur: "bitti, masraf kalmadı".
    func testExplicitZeroIsKeptAndDiffersFromNil() {
        let (vm, proje) = kur()
        vm.updateProgress(role: .admin, projectId: proje.id, progress: 100,
                          phase: .teslim, remainingCostText: "0")
        XCTAssertEqual(vm.projects.first { $0.id == proje.id }?.remainingCostEstimate, .zero)
        XCTAssertNotNil(vm.stockOutlook(for: proje.id).projectedResult,
                        "Açıkça sıfır girildiyse sonuç gösterilebilir")
    }

    /// PARAMETRE GEÇİLMEZSE TAHMİN KORUNUR.
    ///
    /// `updateProgress` başka yerlerden de çağrılıyor; kalan maliyeti taşımayan
    /// bir çağrı, kullanıcının girdiği tahmini sessizce silmemeli.
    func testOmittingParameterKeepsExistingEstimate() {
        let (vm, proje) = kur()
        vm.updateProgress(role: .admin, projectId: proje.id, progress: 50,
                          phase: .kabaInsaat, remainingCostText: "900")
        vm.updateProgress(role: .admin, projectId: proje.id, progress: 70,
                          phase: .inceIsler)
        XCTAssertEqual(vm.projects.first { $0.id == proje.id }?.remainingCostEstimate,
                       Kurus.kurus(900_00))
    }

    /// ORTAK YAZAMAZ: tahmin yöneticinin rakamı.
    func testPartnerCannotSetEstimate() {
        let (vm, proje) = kur()
        vm.updateProgress(role: .partner, projectId: proje.id, progress: 90,
                          phase: .teslim, remainingCostText: "1.000")
        XCTAssertNil(vm.projects.first { $0.id == proje.id }?.remainingCostEstimate)
    }


    /// SIFIR İLE BİLİNMEYEN AYRI.
    ///
    /// Yeni kurulan projede hiç satış yok ve hiçbir daireye liste fiyatı
    /// girilmemiş: toplam matematiksel olarak sıfır ama anlamı "bu projeden
    /// para beklenmiyor" değil, "henüz bilinmiyor". Ekran o durumda rakam
    /// yerine "—" gösteriyor.
    func testAllPricelessMeansUnknownNotZero() {
        let (vm, proje) = kur()
        for i in vm.apartments.indices where vm.apartments[i].projectId == proje.id {
            vm.apartments[i].status = .available
            vm.apartments[i].price = .zero
        }
        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.expected, .zero)
        XCTAssertTrue(o.isUnknown, "fiyatsız yeni proje 'sıfır hasılat' demek değil")
    }

    /// GERÇEKTEN SIFIR OLAN DURUM bilinmeyen SAYILMIYOR: bütün daireler kat
    /// karşılığıysa müteahhide gerçekten hasılat kalmıyor ve bu bir bilgi.
    func testAllLandOwnerIsZeroNotUnknown() {
        let (vm, proje) = kur()
        for i in vm.apartments.indices where vm.apartments[i].projectId == proje.id {
            vm.apartments[i].status = .landOwner
            vm.apartments[i].price = .zero
        }
        let o = vm.stockOutlook(for: proje.id)
        XCTAssertEqual(o.expected, .zero)
        XCTAssertFalse(o.isUnknown, "kat karşılığı daireler bilinmeyen değil, bedelsiz")
    }

}
