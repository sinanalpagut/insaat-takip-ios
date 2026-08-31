import XCTest
@testable import InsaatTakip

/// Blok / etap etiketi — madde 83.
///
/// NEDEN BU TESTLER VAR: bu madde listedeki tek FAİZİYLE BÜYÜYEN işti —
/// kullanıcı üç bloğu üç ayrı proje olarak kurduktan sonra birleştirmek her
/// daire, fiş, gider ve denetim izi belgesini taşımak demek. Dar dilim bugün
/// girdiğine göre, dilimin kendi sınırları da kilitlenmeli: etiket ciroyu
/// bloğa kırıyor ama GİDERİ kırmıyor, kopyalama etiketi taşımıyor ve eski
/// belgeler etiketsiz okunabiliyor.
@MainActor
final class BlockLabelTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Project) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return (vm, vm.projects[0])
    }

    /// Tek etiket varsa kırılım YOK.
    ///
    /// Tek bloklu her projeye "A Blok · 20 daire" diye bir kart koymak,
    /// hiçbir şey söylemeyen bir kart olurdu; ekran da bu boş diziye bakıyor.
    func testSingleLabelProducesNoBreakdown() {
        let (vm, proje) = kur()
        for i in vm.apartments.indices where vm.apartments[i].projectId == proje.id {
            vm.apartments[i].blockLabel = "A Blok"
        }
        XCTAssertTrue(vm.blockBreakdown(for: proje.id).isEmpty)

        // Etiketsiz proje de aynı: "belirtilmedi" tek başına bir kırılım değil.
        for i in vm.apartments.indices where vm.apartments[i].projectId == proje.id {
            vm.apartments[i].blockLabel = ""
        }
        XCTAssertTrue(vm.blockBreakdown(for: proje.id).isEmpty)
    }

    /// İki blok: ciro doğru bloğa yazılıyor.
    func testSalesLandInTheirOwnBlock() {
        let (vm, proje) = kur()
        let ids = vm.apartments(for: proje.id).map(\.id)
        for (n, id) in ids.enumerated() {
            guard let i = vm.apartments.firstIndex(where: { $0.id == id }) else { continue }
            vm.apartments[i].blockLabel = n < 2 ? "A Blok" : "B Blok"
            vm.apartments[i].status = n == 0 ? .sold : .available
            vm.apartments[i].price = Kurus.kurus(100_00)
        }

        let dilimler = vm.blockBreakdown(for: proje.id)
        XCTAssertEqual(dilimler.count, 2)
        let a = dilimler.first { $0.label == "A Blok" }
        let b = dilimler.first { $0.label == "B Blok" }
        XCTAssertEqual(a?.salesTotal, Kurus.kurus(100_00))
        XCTAssertEqual(a?.soldCount, 1)
        XCTAssertEqual(b?.salesTotal, .zero, "B bloğun cirosu A'dan sızmamalı")
        XCTAssertEqual(b?.soldCount, 0)
    }

    /// ETİKETSİZ DAİRELER EN SONDA.
    ///
    /// "Belirtilmedi" bir blok ADI değil, eksik veri. Listenin başında
    /// dursaydı bir bloğun adıymış gibi okunurdu.
    func testUnlabeledSliceSortsLast() {
        let (vm, proje) = kur()
        let ids = vm.apartments(for: proje.id).map(\.id)
        for (n, id) in ids.enumerated() {
            guard let i = vm.apartments.firstIndex(where: { $0.id == id }) else { continue }
            vm.apartments[i].blockLabel = n < 2 ? "" : (n < 4 ? "B Blok" : "A Blok")
        }
        let etiketler = vm.blockBreakdown(for: proje.id).map(\.label)
        XCTAssertEqual(etiketler, ["A Blok", "B Blok", ""])
    }

    /// Kat karşılığı daire sayılıyor ama ciroya girmiyor;
    /// fiyatsız boş daire stok toplamını sessizce şişirmiyor.
    func testLandOwnerAndPricelessAreCountedNotSummed() {
        let (vm, proje) = kur()
        let ids = vm.apartments(for: proje.id).map(\.id)
        for (n, id) in ids.enumerated() {
            guard let i = vm.apartments.firstIndex(where: { $0.id == id }) else { continue }
            vm.apartments[i].blockLabel = n == 0 ? "A Blok" : "B Blok"
            vm.apartments[i].status = n == 0 ? .landOwner : .available
            vm.apartments[i].price = n == 0 ? Kurus.kurus(999_999_00) : .zero
        }
        let dilimler = vm.blockBreakdown(for: proje.id)
        let a = dilimler.first { $0.label == "A Blok" }
        let b = dilimler.first { $0.label == "B Blok" }
        XCTAssertEqual(a?.landOwnerCount, 1)
        XCTAssertEqual(a?.salesTotal, .zero, "kat karşılığı daire ciroya giremez")
        XCTAssertEqual(a?.stockTotal, .zero, "kat karşılığı daire stok değeri de değil")
        XCTAssertEqual(b?.stockTotal, .zero)
        XCTAssertEqual(b?.pricelessCount, b?.total, "fiyatsız daireler sayılmalı")
    }

    /// Etiket kaydediliyor ve DENETİM İZİNE yazılıyor.
    ///
    /// Bir daireyi başka bloğa taşımak raporda iki bloğun rakamını birden
    /// değiştiriyor; izsiz bırakılsaydı "neden değişti" sorusunun cevabı
    /// hiçbir yerde olmazdı.
    func testLabelIsSavedAndAudited() {
        let (vm, proje) = kur()
        let daire = vm.apartments(for: proje.id)[0]
        XCTAssertTrue(vm.updateApartment(role: .admin, apartmentId: daire.id,
                                         type: daire.type, areaM2: daire.areaM2,
                                         floor: daire.floor, status: daire.status,
                                         listPriceText: "", deliveryNote: daire.deliveryNote,
                                         blockLabel: "  C Blok  "))
        XCTAssertEqual(vm.apartments.first { $0.id == daire.id }?.blockLabel, "C Blok",
                       "baştaki/sondaki boşluk temizlenmeli")

        let iz = vm.audit(forProject: proje.id)
            .flatMap(\.changes)
            .first { $0.field == "Blok / Etap" }
        XCTAssertNotNil(iz, "blok değişikliği denetim izine yazılmadı")
        XCTAssertEqual(iz?.newValue, "C Blok")
    }

    /// TOPLU UYGULAMA ETİKETİ TAŞIMIYOR.
    ///
    /// "Tip ve alanı bütün projeye uygula" tek dokunuşla bütün daireleri aynı
    /// bloğa taşısaydı, blok kırılımı sessizce tek bloğa iner ve kullanıcı
    /// bunu ancak raporda fark ederdi.
    func testBulkApplyDoesNotCopyBlockLabel() {
        let (vm, proje) = kur()
        let daireler = vm.apartments(for: proje.id)
        for (n, d) in daireler.enumerated() {
            guard let i = vm.apartments.firstIndex(where: { $0.id == d.id }) else { continue }
            vm.apartments[i].blockLabel = n == 0 ? "A Blok" : "B Blok"
        }
        _ = vm.updateApartment(role: .admin, apartmentId: daireler[0].id,
                               type: "9+1", areaM2: 200,
                               floor: daireler[0].floor, status: daireler[0].status,
                               listPriceText: "", deliveryNote: daireler[0].deliveryNote,
                               blockLabel: "A Blok")
        _ = vm.applyTypeAndArea(role: .admin, from: daireler[0].id, wholeProject: true)

        let sonra = vm.apartments(for: proje.id)
        XCTAssertTrue(sonra.allSatisfy { $0.type == "9+1" }, "tip kopyalanmalıydı")
        XCTAssertEqual(sonra.filter { $0.blockLabel == "B Blok" }.count, daireler.count - 1,
                       "blok etiketi kopyalanmamalı")
    }

    /// ESKİ BELGE ETİKETSİZ OKUNUR — göç yok.
    ///
    /// Madde 83'ten önce yazılmış her daire belgesinde `blockLabel` alanı hiç
    /// yok. Çözümleme patlasaydı, uygulama var olan verisini açamaz hâle
    /// gelirdi; boş etiket zaten geçerli durum ("belirtilmedi").
    func testDecodingDocumentWithoutBlockLabel() throws {
        let json = """
        {"id":"\(UUID().uuidString)","projectId":"\(UUID().uuidString)",
         "apartmentNumber":7,"floor":2,"type":"3+1","areaM2":103.8,
         "status":"available","price":0,"paidAmount":0,
         "deliveryNote":""}
        """
        let daire = try JSONDecoder().decode(Apartment.self, from: Data(json.utf8))
        XCTAssertEqual(daire.blockLabel, "")
        XCTAssertEqual(daire.apartmentNumber, 7)
    }

    /// CSV'de blok sütunu HER ZAMAN var.
    ///
    /// Ekranda kırılım yalnızca birden çok etiket varsa görünüyor; dosyada
    /// sütunun bazen olup bazen olmaması, mali müşavirin şablonunu her
    /// seferinde bozardı.
    func testCSVAlwaysCarriesBlockColumn() {
        let (vm, proje) = kur()
        var daireler = vm.apartments(for: proje.id)
        daireler[0].blockLabel = "A Blok"
        let csv = ProjectExporter.apartmentsCSV(daireler, includeBuyer: false)
        let satirlar = csv.components(separatedBy: "\n")
        XCTAssertTrue(satirlar[0].contains("Blok / Etap"), "başlıkta blok sütunu yok")
        XCTAssertTrue(satirlar[1].contains("A Blok"), "ilk satırda etiket yok")
    }
}
