import XCTest
@testable import InsaatTakip

/// Daire listesi — ekleme ve silme (madde 61).
@MainActor
final class ApartmentRosterTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Project) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return (vm, vm.projects.first!)
    }

    /// `totalApartments` LİSTEYLE SENKRON kalmalı.
    ///
    /// O alan saklanan bir sayı ve gerçek listeden ayrışabilir. "5 Kat / 20
    /// Daire" yazan bir projede 21 daire olması, projenin kendi "türetilen
    /// rakam saklanmaz" ilkesinin ihlali olurdu — ve rakam iki ekranda
    /// (`Project.meta` ve dashboard alt başlığı) görünüyor.
    func testAddKeepsStoredCountInSync() {
        let (vm, proje) = kur()
        let once = vm.apartments(for: proje.id).count

        XCTAssertTrue(vm.addApartment(role: .admin, projectId: proje.id))
        let sonra = vm.apartments(for: proje.id)
        XCTAssertEqual(sonra.count, once + 1)
        XCTAssertEqual(vm.projects.first { $0.id == proje.id }?.totalApartments, sonra.count,
                       "saklanan sayı listeden ayrıştı")
    }

    /// Yeni daire, mevcut EN BÜYÜK numaranın bir fazlasını alır.
    func testAddUsesNextFreeNumber() {
        let (vm, proje) = kur()
        let enBuyuk = vm.apartments(for: proje.id).map(\.apartmentNumber).max() ?? 0
        _ = vm.addApartment(role: .admin, projectId: proje.id)
        XCTAssertEqual(vm.apartments(for: proje.id).map(\.apartmentNumber).max(), enBuyuk + 1)
    }

    /// TAAHHÜTLÜ daire silinemez.
    ///
    /// Satılmış/rezerve dairenin tahsilatı, taksit planı ve alıcı kaydı var;
    /// burada sessizce silmek parayı toplamlardan düşürürdü. Kullanıcı önce
    /// satışı iptal eder — `cancelSale` hepsini temizliyor.
    func testCommittedApartmentCannotBeDeleted() {
        let (vm, proje) = kur()
        let satilan = vm.apartments(for: proje.id).first { $0.isCommitted }!
        let once = vm.apartments(for: proje.id).count

        XCTAssertFalse(vm.deleteApartment(role: .admin, apartmentId: satilan.id))
        XCTAssertEqual(vm.apartments(for: proje.id).count, once)
    }

    /// Taahhütsüz daire silinir ve saklanan sayı da düşer.
    func testDeletingFreeApartmentSyncsCount() {
        let (vm, proje) = kur()
        let bos = vm.apartments(for: proje.id).first { !$0.isCommitted }!
        let once = vm.apartments(for: proje.id).count

        XCTAssertTrue(vm.deleteApartment(role: .admin, apartmentId: bos.id))
        let sonra = vm.apartments(for: proje.id)
        XCTAssertEqual(sonra.count, once - 1)
        XCTAssertNil(sonra.first { $0.id == bos.id })
        XCTAssertEqual(vm.projects.first { $0.id == proje.id }?.totalApartments, sonra.count)
    }

    /// Silinen dairenin GÖRSELLERİ de listeden düşer.
    ///
    /// Yetim kalan bir nesne, projenin HER üyesinin okuyabildiği bir dosya
    /// olarak Storage'da kalırdı.
    func testDeletingApartmentDropsItsPhotos() {
        let (vm, proje) = kur()
        let hedef = vm.apartments(for: proje.id).first {
            !$0.isCommitted && !vm.photos(forApartment: $0.id).isEmpty
        } ?? vm.apartments(for: proje.id).first { !$0.isCommitted }!

        _ = vm.deleteApartment(role: .admin, apartmentId: hedef.id)
        XCTAssertTrue(vm.photos(forApartment: hedef.id).isEmpty)
    }

    // MARK: Toplu düzenleme

    /// Kat kapsamı: yalnızca AYNI kattaki daireler değişir.
    func testApplyToFloorOnlyTouchesThatFloor() {
        let (vm, proje) = kur()
        let kaynak = vm.apartments(for: proje.id).first!
        let baskaKat = vm.apartments(for: proje.id).first { $0.floor != kaynak.floor }

        _ = vm.updateApartment(role: .admin, apartmentId: kaynak.id, type: "3+1",
                               areaM2: 118, floor: kaynak.floor, status: kaynak.status,
                               listPriceText: "0", deliveryNote: kaynak.deliveryNote)
        _ = vm.applyTypeAndArea(role: .admin, from: kaynak.id, wholeProject: false)

        for a in vm.apartments(for: proje.id) where a.floor == kaynak.floor {
            XCTAssertEqual(a.type, "3+1")
            XCTAssertEqual(a.areaM2, 118)
        }
        if let baskaKat, let sonra = vm.apartments.first(where: { $0.id == baskaKat.id }) {
            XCTAssertNotEqual(sonra.areaM2, 118, "başka kat da değişti")
        }
    }

    /// BEDEL, DURUM ve TESLİM NOTU KOPYALANMAZ.
    ///
    /// Bunlar daireye özgü; toplu yazılsaydı satılmış bir dairenin bedeli
    /// sessizce değişir ve ciro bozulurdu. Yalnızca TİP ve ALAN fiziksel
    /// özellik ve satış durumundan bağımsız.
    func testApplyDoesNotCopyPriceOrStatus() {
        let (vm, proje) = kur()
        let kaynak = vm.apartments(for: proje.id).first { !$0.isCommitted }!
        let satilan = vm.apartments(for: proje.id).first { $0.status == .sold }!
        let bedelOnce = satilan.price
        let durumOnce = satilan.status
        let notOnce = satilan.deliveryNote

        _ = vm.updateApartment(role: .admin, apartmentId: kaynak.id, type: "1+1",
                               areaM2: 55, floor: kaynak.floor, status: kaynak.status,
                               listPriceText: "9.999.999", deliveryNote: "TEST NOTU")
        _ = vm.applyTypeAndArea(role: .admin, from: kaynak.id, wholeProject: true)

        let sonra = vm.apartments.first { $0.id == satilan.id }!
        XCTAssertEqual(sonra.type, "1+1", "tip uygulanmadı")
        XCTAssertEqual(sonra.areaM2, 55, "alan uygulanmadı")
        XCTAssertEqual(sonra.price, bedelOnce, "BEDEL kopyalandı")
        XCTAssertEqual(sonra.status, durumOnce, "DURUM kopyalandı")
        XCTAssertEqual(sonra.deliveryNote, notOnce, "TESLİM NOTU kopyalandı")
    }

    /// Zaten aynıysa yazma üretilmez — gereksiz kayıt denetim izini şişirir
    /// ve çevrimdışı kuyruğa yük bindirir.
    func testApplyIsIdempotent() {
        let (vm, proje) = kur()
        let kaynak = vm.apartments(for: proje.id).first!
        _ = vm.updateApartment(role: .admin, apartmentId: kaynak.id, type: "2+1",
                               areaM2: 95, floor: kaynak.floor, status: kaynak.status,
                               listPriceText: "0", deliveryNote: kaynak.deliveryNote)
        let ilk = vm.applyTypeAndArea(role: .admin, from: kaynak.id, wholeProject: true)
        XCTAssertGreaterThan(ilk, 0)
        XCTAssertEqual(vm.applyTypeAndArea(role: .admin, from: kaynak.id, wholeProject: true), 0,
                       "ikinci uygulama gereksiz yazma üretti")
    }

    func testPartnerCannotApply() {
        let (vm, proje) = kur()
        let kaynak = vm.apartments(for: proje.id).first!
        XCTAssertEqual(vm.applyTypeAndArea(role: .partner, from: kaynak.id, wholeProject: true), 0)
    }

    func testPartnerCannotAddOrDelete() {
        let (vm, proje) = kur()
        let once = vm.apartments(for: proje.id).count
        let bos = vm.apartments(for: proje.id).first { !$0.isCommitted }!

        XCTAssertFalse(vm.addApartment(role: .partner, projectId: proje.id))
        XCTAssertFalse(vm.deleteApartment(role: .partner, apartmentId: bos.id))
        XCTAssertEqual(vm.apartments(for: proje.id).count, once)
    }
}
