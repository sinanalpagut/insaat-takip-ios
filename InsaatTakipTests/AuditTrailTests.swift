import XCTest
@testable import InsaatTakip

/// Kayıt İzi ekranının veri kaynağı ve gruplaması — madde 76.
///
/// NEDEN BU TESTLER VAR: `audit(forProject:)` yazılmıştı ama View katmanında
/// ÇAĞIRAN YOKTU — yani hiç koşmamış bir yoldu. Ekran onun üstüne kuruldu;
/// koşmamış kodun kusurları koşana kadar görünmüyor (bu projede defalarca
/// yaşandı), o yüzden önce burada koşuyor.
@MainActor
final class AuditTrailTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Project) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return (vm, vm.projects.first!)
    }

    /// Düzeltme projenin izine düşmeli ve ESKİ DEĞERİ taşımalı.
    ///
    /// Ekranın var olma sebebi bu: ortak bugüne kadar rakamın SONUCUNU
    /// görüyordu, DEĞİŞTİRİLDİĞİNİ göremiyordu. Eski değer taşınmazsa ekran
    /// yalnızca "bir şey düzeltildi" der ve hiçbir şeyi denetlenebilir yapmaz.
    func testEditLandsInProjectTrailWithOldValue() throws {
        let (vm, proje) = kur()
        let daire = try XCTUnwrap(vm.apartments(for: proje.id).first { !$0.isCommitted })
        let onceki = vm.audit(forProject: proje.id).count

        XCTAssertTrue(vm.updateApartment(role: .admin, apartmentId: daire.id,
                                         type: "4+1", areaM2: 140, floor: daire.floor,
                                         status: daire.status,
                                         listPriceText: "2.500.000", deliveryNote: "",
                                         buyerName: ""))

        let iz = vm.audit(forProject: proje.id)
        XCTAssertEqual(iz.count, onceki + 1)
        let kayit = try XCTUnwrap(iz.first)
        XCTAssertTrue(kayit.subject.contains("Daire No \(daire.apartmentNumber)"))
        XCTAssertFalse(kayit.changes.isEmpty, "değişiklik listesi boş — eski değer taşınmıyor")
        XCTAssertTrue(kayit.summary.contains("→"), "eski → yeni biçimi kayıp")
    }

    /// İZ YENİDEN ESKİYE sıralı olmalı — ekran onu böyle çiziyor ve gün
    /// gruplaması sıralı akışa güveniyor.
    func testTrailIsNewestFirst() throws {
        let (vm, proje) = kur()
        let daireler = vm.apartments(for: proje.id).filter { !$0.isCommitted }
        try XCTSkipUnless(daireler.count >= 2, "zemin: iki boş daire gerekiyor")

        for (i, daire) in daireler.prefix(2).enumerated() {
            _ = vm.updateApartment(role: .admin, apartmentId: daire.id,
                                   type: "\(i + 2)+1", areaM2: 100 + Double(i),
                                   floor: daire.floor, status: daire.status,
                                   listPriceText: "1.000.000", deliveryNote: "",
                                   buyerName: "")
        }

        let tarihler = vm.audit(forProject: proje.id).map(\.date)
        XCTAssertEqual(tarihler, tarihler.sorted(by: >), "iz yeniden eskiye sıralı değil")
    }

    /// PROJE YALITIMI: ekran tek projenin izini gösteriyor.
    ///
    /// Süzgeç kaçsaydı ortak, ÜYESİ OLMADIĞI projenin düzeltmelerini görürdü —
    /// dashboard'da özenle kurulan sınırın aynısı buradan delinirdi.
    func testTrailIsScopedToOneProject() throws {
        let (vm, proje) = kur()
        let digerleri = vm.projects.filter { $0.id != proje.id }
        try XCTSkipUnless(!digerleri.isEmpty, "zemin: ikinci proje gerekiyor")

        let daire = try XCTUnwrap(vm.apartments(for: proje.id).first { !$0.isCommitted })
        _ = vm.updateApartment(role: .admin, apartmentId: daire.id, type: "1+1",
                               areaM2: 60, floor: daire.floor, status: daire.status,
                               listPriceText: "900.000", deliveryNote: "", buyerName: "")

        for kayit in vm.audit(forProject: proje.id) {
            XCTAssertEqual(kayit.projectId, proje.id)
        }
        for baska in digerleri {
            XCTAssertFalse(vm.audit(forProject: baska.id).contains { $0.projectId == proje.id })
        }
    }

    /// GÜN BAŞLIKLARI. Denetim izinde asıl soru "ne zaman değişti" ve bir
    /// müteahhit için o soru takvim gününde cevaplanıyor, saat başında değil.
    func testDayHeadings() {
        let bugun = Date()
        let dun = Fmt.calendar.date(byAdding: .day, value: -1, to: bugun)!
        let eski = Fmt.calendar.date(byAdding: .day, value: -40, to: bugun)!

        XCTAssertEqual(AuditTrailView.gunBasligi(bugun), "Bugün")
        XCTAssertEqual(AuditTrailView.gunBasligi(dun), "Dün")
        XCTAssertEqual(AuditTrailView.gunBasligi(eski), Fmt.shortDate(eski))
        XCTAssertNotEqual(AuditTrailView.gunBasligi(eski), "Bugün")
    }
}
