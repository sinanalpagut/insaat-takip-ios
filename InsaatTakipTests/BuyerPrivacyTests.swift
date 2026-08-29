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

    /// ORTAĞIN OKUYABİLDİĞİ HER DEFTERİ tarar: denetim izi VE hareket akışı.
    ///
    /// İkisi birlikte taranmak zorunda çünkü `recordAudit` TEK çağrıda İKİ
    /// kayıt yazıyor: `AuditEntry` ve onun özetini `meta` alanında taşıyan bir
    /// `ActivityItem`. Yalnızca denetim izine bakan bir test, aynı metnin
    /// ortağa açık ikinci deftere girmediğini kanıtlamıyordu.
    private func adSizdiMi(_ vm: ProjectViewModel, _ ad: String) -> String? {
        for kayit in vm.auditEntries {
            if kayit.subject.contains(ad) { return "denetim izi · konu: \(kayit.subject)" }
            for d in kayit.changes {
                if d.field.contains(ad) { return "denetim izi · alan: \(d.field)" }
                if d.oldValue.contains(ad) { return "denetim izi · eski değer: \(d.oldValue)" }
                if d.newValue.contains(ad) { return "denetim izi · yeni değer: \(d.newValue)" }
            }
        }
        for hareket in vm.activities {
            if hareket.title.contains(ad) { return "hareket akışı · başlık: \(hareket.title)" }
            if hareket.meta.contains(ad) { return "hareket akışı · meta: \(hareket.meta)" }
        }
        return nil
    }

    /// REZERVE YOLU — ad yalnızca "kayıtlı / kaldırıldı" olarak geçmeli.
    func testBuyerNameNeverEntersAuditTrail() {
        let (vm, daire) = kur()
        let ad = "Zeynep Karaca"

        _ = vm.updateApartment(role: .admin, apartmentId: daire.id, type: daire.type,
                               areaM2: daire.areaM2, floor: daire.floor, status: .reserved,
                               listPriceText: "1.000.000", deliveryNote: "",
                               buyerName: ad)

        XCTAssertFalse(vm.audit(for: daire.id).isEmpty, "denetim kaydı hiç yazılmadı")
        XCTAssertNil(adSizdiMi(vm, ad))
        XCTAssertEqual(vm.apartments.first { $0.id == daire.id }?.buyerName, ad)
    }

    /// SATIŞ YOLU — adın gerçekten girildiği form.
    ///
    /// Önceki hâlde bu yol HİÇ SINANMIYORDU: test yalnızca `updateApartment`
    /// çağırıyordu, oysa alıcı adını asıl toplayan ekran satış formu.
    /// `saveSale` içindeki denetim dalı ayrıca "yeni satış değilse" kapısının
    /// arkasında, yani rezerve→satış ve satış düzeltme yolları da kapsam
    /// dışıydı. Kayıt İzi ekranı (madde 76) güvenliğini bu teste dayandırıyor;
    /// tek fonksiyon tarayan bir test o yükü taşıyamazdı.
    func testBuyerNameNeverLeaksThroughSale() {
        let (vm, daire) = kur()
        let ad = "Zeynep Karaca"

        XCTAssertTrue(vm.saveSale(role: .admin, apartmentId: daire.id, buyerName: ad,
                                  priceText: "1.000.000", paidText: "250.000",
                                  payment: .taksitli, saleDate: Date(),
                                  installmentCount: 6, firstDueDate: Date()))
        XCTAssertNil(adSizdiMi(vm, ad))

        // SATIŞ DÜZELTMESİ de sınanıyor: ikinci kayıt "yeni satış değil"
        // dalından geçiyor ve denetim kaydını orası yazıyor.
        XCTAssertTrue(vm.saveSale(role: .admin, apartmentId: daire.id, buyerName: ad,
                                  priceText: "1.200.000", paidText: "250.000",
                                  payment: .taksitli, saleDate: Date(),
                                  installmentCount: 6, firstDueDate: Date()))
        XCTAssertNil(adSizdiMi(vm, ad))
    }

    /// SATIŞ İPTALİ — alıcı kaydı silinirken de ad geçmemeli.
    func testBuyerNameNeverLeaksThroughCancellation() {
        let (vm, daire) = kur()
        let ad = "Zeynep Karaca"

        XCTAssertTrue(vm.saveSale(role: .admin, apartmentId: daire.id, buyerName: ad,
                                  priceText: "1.000.000", paidText: "250.000",
                                  payment: .taksitli, saleDate: Date(),
                                  installmentCount: 6, firstDueDate: Date()))
        XCTAssertTrue(vm.cancelSale(role: .admin, apartmentId: daire.id))

        XCTAssertNil(adSizdiMi(vm, ad))
        XCTAssertNil(vm.apartments.first { $0.id == daire.id }?.buyerName,
                     "iptalde alıcı kaydı da düşmeli")
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
