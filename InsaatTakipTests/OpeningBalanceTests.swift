import XCTest
@testable import InsaatTakip

/// Açılış devri — madde 59.
@MainActor
final class OpeningBalanceTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Material) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return (vm, vm.materials.first!)
    }

    /// Devir EKLEME DEĞİL DEĞİŞTİRMEDİR.
    ///
    /// Yanlış giren kullanıcı düzeltmek için ikinci kez yazdığında miktar iki
    /// katına çıkmamalı. Bu, "devri fiş olarak yaz" çözümünün en büyük
    /// sakıncasıydı: fiş eklenir, devir ise değiştirilir.
    func testOpeningBalanceReplacesInsteadOfAccumulating() {
        let (vm, malzeme) = kur()
        let fisGiren = malzeme.totalIn - malzeme.openingIn

        XCTAssertTrue(vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                           inText: "1000", outText: "0", costText: "50.000"))
        let ilk = vm.materials.first { $0.id == malzeme.id }!
        XCTAssertEqual(ilk.openingIn, 1000, accuracy: 0.001)

        // AYNI değerlerle ikinci kez — hiçbir şey değişmemeli.
        _ = vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                 inText: "1000", outText: "0", costText: "50.000")
        XCTAssertEqual(vm.materials.first { $0.id == malzeme.id }!.openingIn, 1000, accuracy: 0.001)

        // FARKLI değerle — üstüne yazılmalı, toplanmamalı.
        _ = vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                 inText: "400", outText: "0", costText: "20.000")
        let son = vm.materials.first { $0.id == malzeme.id }!
        XCTAssertEqual(son.openingIn, 400, accuracy: 0.001)
        XCTAssertEqual(son.totalIn, 400 + fisGiren, accuracy: 0.001,
                       "toplam giren = devir + fişler olmalı")
    }

    /// Maliyet fişlerin ÜSTÜNE ekleniyor, yerine geçmiyor.
    func testOpeningCostAddsToReceiptTotal() {
        let (vm, malzeme) = kur()
        let fisTutari = malzeme.accruedCost - malzeme.openingCost

        _ = vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                 inText: Fmt.qtyText(malzeme.openingIn),
                                 outText: Fmt.qtyText(malzeme.openingOut),
                                 costText: "123.456")
        let son = vm.materials.first { $0.id == malzeme.id }!
        XCTAssertEqual(son.accruedCost.raw, Kurus.lira(123_456).raw + fisTutari.raw)
    }

    /// Devri düşürmek stoğu EKSİYE düşüremez.
    ///
    /// Kayıtlı çıkış fişleri devirden besleniyor olabilir; devri sıfırlamak
    /// "eksi stok" üretirdi ve `Material.currentStock` hiçbir yerde bunu
    /// yakalamıyor — ekranda eksi bir kalan görünürdü.
    func testCannotPushStockNegative() {
        let (vm, malzeme) = kur()
        // Önce devri büyütüp çıkışın devirden karşılandığı bir durum kur.
        _ = vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                 inText: "100000", outText: "0", costText: "0")
        let cikan = vm.materials.first { $0.id == malzeme.id }!.totalOut

        // Şimdi devri, kayıtlı çıkışı karşılayamayacak kadar küçült.
        let sonuc = vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                         inText: "0", outText: "\(Int(cikan) + 1000)", costText: "0")
        XCTAssertFalse(sonuc, "stoğu eksiye düşüren devir kabul edildi")
        XCTAssertGreaterThanOrEqual(vm.materials.first { $0.id == malzeme.id }!.currentStock, 0)
    }

    func testPartnerCannotSetOpeningBalance() {
        let (vm, malzeme) = kur()
        let once = vm.materials.first { $0.id == malzeme.id }!.openingIn
        XCTAssertFalse(vm.setOpeningBalance(role: .partner, materialId: malzeme.id,
                                            inText: "9999", outText: "0", costText: "0"))
        XCTAssertEqual(vm.materials.first { $0.id == malzeme.id }!.openingIn, once, accuracy: 0.001)
    }
}
