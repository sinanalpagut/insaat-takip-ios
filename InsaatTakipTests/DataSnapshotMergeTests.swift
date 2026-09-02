import XCTest
@testable import InsaatTakip

/// `DataSnapshot.merge` — proje başına okunan verinin birleştirilmesi.
///
/// NEDEN BU TEST VAR: 2 Eyl 2026 cihaz turunda ortak cari hesabı gerçek
/// veritabanına yazıldı, `fetch` onu SUNUCUDAN okudu (sonda "belge=1" dedi) ve
/// `merge` ELLE SAYDIĞI on üç koleksiyonun arasında `partnerLedger`
/// olmadığı için sessizce çöpe attı. Ekranda kayıt vardı, yeniden başlatınca
/// yoktu; hata yoktu, uyarı yoktu.
///
/// Bu, aynı gün bulunan `Apartment.encode(to:)` kusuruyla AYNI SINIF: elle
/// yazılmış bir liste, yeni bir alan/koleksiyon eklendiğinde sessizce eksik
/// kalıyor ve hiçbir şey bunu söylemiyor. Bu yüzden test tek tek koleksiyon
/// adı saymıyor — `Mirror` ile HER dizi özelliğini geziyor. Yarın yeni bir
/// koleksiyon eklendiğinde bu test KIRMIZIYA DÖNER: ya `merge` unutulmuştur ya
/// da aşağıdaki `doluAnlikGoruntu` — ikisi de düzeltilmesi gereken şey.
final class DataSnapshotMergeTests: XCTestCase {

    /// Her koleksiyonda BİR kayıt taşıyan anlık görüntü.
    private func doluAnlikGoruntu() -> DataSnapshot {
        let pid = UUID()
        let aid = UUID()
        var s = DataSnapshot()

        s.projects = [Project(id: pid, blockNumber: "145", parcelNumber: "2",
                              district: "—", city: "—", floors: 1, totalApartments: 1,
                              phase: .temel, progress: 0, ownerUid: "u1",
                              memberUids: ["u1"], createdAt: Date(),
                              invite: nil, photoCount: 0)]
        s.materials = [Material(id: UUID(), projectId: pid, code: "Ø12", name: "Demir",
                                subtitle: "—", unit: "kg", unitPrice: Kurus.lira(29), step: 500)]
        s.materialLogs = [MaterialLog(id: UUID(), projectId: pid, materialId: UUID(),
                                      type: .entry, amount: 100, unitPrice: Kurus.lira(29),
                                      date: Date(), note: "", user: "u")]
        s.apartments = [Apartment(id: aid, projectId: pid, apartmentNumber: 1, floor: 1,
                                  type: "3+1", areaM2: nil, status: .available,
                                  buyerName: nil, price: .zero, paidAmount: .zero,
                                  paymentStatus: nil, saleDate: nil, deliveryNote: "")]
        s.partners = [Partner(id: UUID(), projectId: pid, name: "Ortak",
                              isFounder: true, joinedAt: Date(), sharePercent: 100)]
        s.documents = [ProjectDocument(id: UUID(), projectId: pid, group: .mimari,
                                       fileType: .pdf, name: "Plan", versionText: "v1",
                                       sizeMB: 1, date: Date(), partnerVisible: true)]
        s.activities = [ActivityItem(id: UUID(), projectId: pid, kind: .edit,
                                     title: "t", meta: "m", timestamp: Date())]
        s.sitePhotos = [SitePhoto(id: UUID(), projectId: pid, date: Date(), image: nil)]
        s.expenses = [Expense(id: UUID(), projectId: pid, category: .diger,
                              amount: Kurus.lira(1), date: Date(), payee: "", note: "", user: "u")]
        s.payments = [Payment(id: UUID(), projectId: pid, apartmentId: aid,
                              amount: Kurus.lira(1), date: Date(), method: .nakit,
                              note: "", user: "u")]
        s.installments = [Installment(id: UUID(), projectId: pid, apartmentId: aid,
                                      sequence: 1, dueDate: Date(), amount: Kurus.lira(1))]
        s.partnerLedger = [PartnerLedgerEntry(id: UUID(), projectId: pid, partnerId: UUID(),
                                              kind: .sermaye, amount: Kurus.lira(1),
                                              date: Date(), note: "", user: "u")]
        s.apartmentPhotos = [ApartmentPhoto(id: UUID(), projectId: pid, apartmentId: aid,
                                            label: "Görsel 1", image: nil)]
        s.auditEntries = [AuditEntry(id: UUID(), recordId: aid, projectId: pid,
                                     subject: "s", action: .update, changes: [],
                                     user: "u", date: Date())]
        s.failedProjects = [ProjectLoadFailure(id: pid, title: "t", reason: "r")]
        return s
    }

    /// HİÇBİR KOLEKSİYON BİRLEŞTİRMEDE DÜŞMEMELİ.
    ///
    /// `Mirror` kullanılıyor çünkü asıl kusur "listeye eklemeyi unutmak"tı;
    /// testin kendisi de elle sayılan bir liste olsaydı aynı şekilde eksik
    /// kalırdı.
    func testMergeCarriesEveryCollection() {
        let dolu = doluAnlikGoruntu()
        var hedef = DataSnapshot()
        hedef.merge(dolu)

        var bakilan = 0
        for cocuk in Mirror(reflecting: hedef).children {
            guard let ad = cocuk.label else { continue }
            // Dizi olmayan bir özellik eklenirse (ör. bir bayrak) atlanıyor;
            // birleştirme sorusu yalnızca koleksiyonlar için anlamlı.
            guard let dizi = cocuk.value as? any Collection else { continue }
            bakilan += 1
            XCTAssertFalse(dizi.isEmpty,
                           "\(ad) BİRLEŞTİRMEDE DÜŞÜYOR — ya DataSnapshot.merge'de "
                           + "eksik ya da testteki doluAnlikGoruntu'da doldurulmamış")
        }
        // Testin kendisi boşa dönmesin: hiç özellik gezilmediyse Mirror kırılmış
        // demektir ve yeşil bir test hiçbir şey kanıtlamıyor olurdu.
        XCTAssertGreaterThanOrEqual(bakilan, 14, "Mirror koleksiyonları göremedi")
    }

    /// Birleştirme EKLER, üzerine yazmaz: iki projeden gelen kayıtlar toplanır.
    func testMergeAppendsInsteadOfReplacing() {
        var hedef = doluAnlikGoruntu()
        hedef.merge(doluAnlikGoruntu())
        XCTAssertEqual(hedef.projects.count, 2)
        XCTAssertEqual(hedef.partnerLedger.count, 2)
        XCTAssertEqual(hedef.apartments.count, 2)
    }
}
