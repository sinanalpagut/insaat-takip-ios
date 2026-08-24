import XCTest
@testable import InsaatTakip

/// Alıcı kimliğinin ortaktan gizliliği — madde 18 ve 67.
///
/// Rezerve daireye alıcı adayının adı yazılabiliyor (madde 67). Bu testlerin
/// işi, o yolun madde 18'in kapattığı sızıntıyı ARKA KAPIDAN geri açmadığını
/// kanıtlamak: `auditEntries` kuralı ORTAĞA OKUMA veriyor
/// (`allow read: if isMember`), dolayısıyla adın denetim izine yazılması
/// gizliliği doğrudan bozardı.
@MainActor
final class BuyerPrivacyTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Apartment) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        // Demo veride rezerveye çevrilebilecek boş bir daire bul.
        let bos = vm.apartments.first { $0.status == .available }!
        return (vm, bos)
    }

    /// Ad denetim izine YAZILMAMALI — yalnızca "kayıtlı / kaldırıldı".
    func testBuyerNameNeverEntersAuditTrail() {
        let (vm, daire) = kur()
        let ad = "Zeynep Karaca"

        _ = vm.updateApartment(role: .admin, apartmentId: daire.id, type: daire.type,
                               areaM2: daire.areaM2, floor: daire.floor, status: .reserved,
                               listPriceText: "1.000.000", deliveryNote: "",
                               buyerName: ad)

        let iz = vm.audit(for: daire.id)
        XCTAssertFalse(iz.isEmpty, "denetim kaydı hiç yazılmadı")
        for kayit in iz {
            for degisiklik in kayit.changes {
                XCTAssertFalse(degisiklik.oldValue.contains(ad), "ad eski değerde sızdı")
                XCTAssertFalse(degisiklik.newValue.contains(ad), "ad yeni değerde sızdı")
                XCTAssertFalse(degisiklik.field.contains(ad), "ad alan adında sızdı")
            }
            XCTAssertFalse(kayit.subject.contains(ad), "ad konu başlığında sızdı")
        }
        // Kaydın kendisi daireye yazılmış olmalı.
        XCTAssertEqual(vm.apartments.first { $0.id == daire.id }?.buyerName, ad)
    }

    /// Rezerve daire bu formdan BAŞKA duruma çevrilemez.
    ///
    /// İlk yazışta `updateApartment`a "rezerveden çıkarsa adı temizle" diye bir
    /// dal koymuştum; test onun ULAŞILAMAZ olduğunu gösterdi. Fonksiyonun
    /// başındaki `isCommitted` koruması bu geçişi zaten reddediyor ve temizlik
    /// `cancelSale`de yapılıyor. Bu test o korumanın yerinde kalmasını sağlıyor.
    func testReservedCannotBeChangedFromInfoForm() {
        let (vm, daire) = kur()
        _ = vm.updateApartment(role: .admin, apartmentId: daire.id, type: daire.type,
                               areaM2: daire.areaM2, floor: daire.floor, status: .reserved,
                               listPriceText: "1.000.000", deliveryNote: "",
                               buyerName: "Zeynep Karaca")

        let sonuc = vm.updateApartment(role: .admin, apartmentId: daire.id, type: daire.type,
                                       areaM2: daire.areaM2, floor: daire.floor,
                                       status: .available, listPriceText: "1.000.000",
                                       deliveryNote: "", buyerName: "")
        XCTAssertFalse(sonuc, "rezerve daire bilgi formundan boşa çevrilebildi")
        XCTAssertEqual(vm.apartments.first { $0.id == daire.id }?.status, .reserved)
    }

    /// İPTAL YOLU kimliği bırakır — veri minimizasyonu.
    func testCancellingReservationClearsBuyer() {
        let (vm, daire) = kur()
        _ = vm.updateApartment(role: .admin, apartmentId: daire.id, type: daire.type,
                               areaM2: daire.areaM2, floor: daire.floor, status: .reserved,
                               listPriceText: "1.000.000", deliveryNote: "",
                               buyerName: "Zeynep Karaca")
        XCTAssertNotNil(vm.apartments.first { $0.id == daire.id }?.buyerName)

        XCTAssertTrue(vm.cancelSale(role: .admin, apartmentId: daire.id))
        XCTAssertNil(vm.apartments.first { $0.id == daire.id }?.buyerName,
                     "iptal sonrası alıcı adayı kaldı")
        XCTAssertEqual(vm.apartments.first { $0.id == daire.id }?.status, .available)
    }

    /// ORTAK bu yolu kullanamaz.
    func testPartnerCannotWriteBuyerName() {
        let (vm, daire) = kur()
        let sonuc = vm.updateApartment(role: .partner, apartmentId: daire.id, type: daire.type,
                                       areaM2: daire.areaM2, floor: daire.floor, status: .reserved,
                                       listPriceText: "1.000.000", deliveryNote: "",
                                       buyerName: "Zeynep Karaca")
        XCTAssertFalse(sonuc)
        XCTAssertNil(vm.apartments.first { $0.id == daire.id }?.buyerName)
    }
}
