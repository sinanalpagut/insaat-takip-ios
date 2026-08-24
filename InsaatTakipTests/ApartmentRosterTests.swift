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

    func testPartnerCannotAddOrDelete() {
        let (vm, proje) = kur()
        let once = vm.apartments(for: proje.id).count
        let bos = vm.apartments(for: proje.id).first { !$0.isCommitted }!

        XCTAssertFalse(vm.addApartment(role: .partner, projectId: proje.id))
        XCTAssertFalse(vm.deleteApartment(role: .partner, apartmentId: bos.id))
        XCTAssertEqual(vm.apartments(for: proje.id).count, once)
    }
}
