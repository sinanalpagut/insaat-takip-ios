import XCTest
import UIKit
@testable import InsaatTakip

/// Salt okunur projeler — abonelik kararı (25 Eki 2026).
///
/// KOTA YÜRÜRLÜĞE GİRDİĞİ AN ÜÇ YOL AKTİF PROJE SINIRINI SÜSE ÇEVİRİYORDU:
///   1. Arşivdeki projeye kayıt girilebiliyordu. Kişi her şeyi arşivde tutup
///      orada çalışırsa "aktif" sayısı hiçbir şeyi sınırlamıyordu.
///   2. Arşivden çıkarma kotaya bakmıyordu: arşivle → yenisini aç → eskisini
///      geri çıkar döngüsüyle ücretsiz katmanda sınırsız aktif proje.
///   3. Abonelik bitince yalnızca YENİ proje duruyordu: bir ay paket alıp on
///      proje açan kişi, iptalden sonra on projede çalışmaya devam ediyordu.
///
/// KARARLAR (kullanıcı, 25 Eki): arşiv salt okunur; sınırın üstündeki aktif
/// projelerin EN ESKİLERİ yazılabilir kalır, fazlası salt okunur. Kişi
/// hangisinde çalışacağını diğerlerini arşivleyerek seçer.
///
/// OKUMA HİÇBİR ZAMAN KAPANMIYOR: veri müteahhidin, uygulama yalnızca
/// tutuyor (`Quota.swift` karar notu). Dışa aktarma da okuma sayılıyor.
@MainActor
final class ProjectWriteLockTests: XCTestCase {

    /// Görünüm modelinin yazılabilir bütün durumu. Kilitli projeye yapılan
    /// çağrı bunun HİÇBİR parçasını değiştirmemeli: yerelde değişip sunucuya
    /// gitmeyen kayıt ekranda yalan söyler, sunucuya giden ise kilidi deler.
    private struct Durum: Equatable {
        var projects: [Project]
        var materials: [Material]
        var materialLogs: [MaterialLog]
        var apartments: [Apartment]
        var partners: [Partner]
        var documents: [ProjectDocument]
        var sitePhotos: [SitePhoto]
        var expenses: [Expense]
        var payments: [Payment]
        var partnerLedger: [PartnerLedgerEntry]
        var apartmentPhotos: [ApartmentPhoto]

        @MainActor init(_ vm: ProjectViewModel) {
            projects = vm.projects; materials = vm.materials
            materialLogs = vm.materialLogs; apartments = vm.apartments
            partners = vm.partners; documents = vm.documents
            sitePhotos = vm.sitePhotos; expenses = vm.expenses
            payments = vm.payments; partnerLedger = vm.partnerLedger
            apartmentPhotos = vm.apartmentPhotos
        }
    }

    private func kur() -> ProjectViewModel {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return vm
    }

    private func index(_ vm: ProjectViewModel, _ id: UUID) -> Int {
        vm.projects.firstIndex { $0.id == id }!
    }

    /// Proje sırasını AÇIKÇA kurar: tohum verideki beş proje aynı günü
    /// taşıyor ve "en eski" kararı tarihe bağlı.
    private func sirala(_ vm: ProjectViewModel, _ ids: [UUID]) {
        let taban = Date(timeIntervalSince1970: 1_700_000_000)
        for (n, id) in ids.enumerated() {
            vm.projects[index(vm, id)].createdAt = taban.addingTimeInterval(Double(n) * 86_400)
        }
    }

    private let sira = [DemoID.cayirova, DemoID.nilufer, DemoID.kepez,
                        DemoID.kars309, DemoID.kars327]

    /// Kilitli projeye dokunan BÜTÜN yazma yolları.
    ///
    /// Liste elle tutuluyor; yeni bir yazma fonksiyonu eklenirse BURAYA da
    /// eklenmeli. Her çağrı geçerli argümanlarla yapılıyor ve toast'un kilit
    /// cümlesi olduğu ayrıca doğrulanıyor — çağrının argüman hatasından
    /// reddedilip testi yanlış yeşile boyaması böyle engelleniyor.
    private func yazmaYollari(_ vm: ProjectViewModel, _ pid: UUID) throws -> [(String, () -> Void)] {
        let malzeme = try XCTUnwrap(vm.materials.first { $0.projectId == pid })
        let hareket = try XCTUnwrap(vm.materialLogs.first { $0.projectId == pid })
        let satilmis = try XCTUnwrap(vm.apartments.first { $0.projectId == pid && $0.isCommitted })
        let bos = try XCTUnwrap(vm.apartments.first { $0.projectId == pid && $0.status == .available })
        let tahsilat = try XCTUnwrap(vm.payments.first { $0.projectId == pid })
        let gider = try XCTUnwrap(vm.expenses.first { $0.projectId == pid })
        let ortak = try XCTUnwrap(vm.partners.first { $0.projectId == pid && !$0.isFounder })
        let proje = vm.projects[index(vm, pid)]
        let digerTaban: TaxBasis = proje.expenseTaxBasis == .dahil ? .haric : .dahil

        let dosya = FileManager.default.temporaryDirectory
            .appendingPathComponent("kilit-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: dosya)
        let gorsel = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }

        var yollar: [(String, () -> Void)] = [
            ("setTaxBasis", { vm.setTaxBasis(role: .admin, projectId: pid, expense: digerTaban, sales: proje.salesTaxBasis) }),
            ("addReceipt", { _ = vm.addReceipt(role: .admin, materialId: malzeme.id, type: .entry,
                                               amountText: "3", unitPriceText: "100", reference: "R1") }),
            ("updateReceipt", { _ = vm.updateReceipt(role: .admin, logId: hareket.id, type: hareket.type,
                                                     amountText: "1", unitPriceText: "100",
                                                     reference: "R2", date: Date()) }),
            ("deleteReceipt", { _ = vm.deleteReceipt(role: .admin, logId: hareket.id) }),
            ("updateProgress", { vm.updateProgress(role: .admin, projectId: pid,
                                                   progress: (proje.progress + 7) % 100, phase: proje.phase) }),
            ("cancelSale", { _ = vm.cancelSale(role: .admin, apartmentId: satilmis.id) }),
            ("updateApartment", { _ = vm.updateApartment(role: .admin, apartmentId: bos.id, type: "4+1",
                                                         areaM2: 140, floor: bos.floor, status: .available,
                                                         listPriceText: "", deliveryNote: "") }),
            ("addPayment", { _ = vm.addPayment(role: .admin, apartmentId: satilmis.id, amountText: "1000",
                                               method: .havale, note: "", date: Date()) }),
            ("updatePayment", { _ = vm.updatePayment(role: .admin, paymentId: tahsilat.id, amountText: "1234",
                                                     method: tahsilat.method, note: "", date: tahsilat.date) }),
            ("deletePayment", { vm.deletePayment(role: .admin, id: tahsilat.id) }),
            ("applyTypeAndArea", { _ = vm.applyTypeAndArea(role: .admin, from: bos.id, wholeProject: true) }),
            ("addApartment", { _ = vm.addApartment(role: .admin, projectId: pid) }),
            ("deleteApartment", { _ = vm.deleteApartment(role: .admin, apartmentId: bos.id) }),
            ("setOpeningBalance", { _ = vm.setOpeningBalance(role: .admin, materialId: malzeme.id,
                                                             inText: "5", outText: "0", costText: "500") }),
            ("addExpense", { _ = vm.addExpense(role: .admin, projectId: pid, category: .iscilik,
                                               amountText: "1000", payee: "Usta", note: "", date: Date()) }),
            ("updateExpense", { _ = vm.updateExpense(role: .admin, expenseId: gider.id, category: gider.category,
                                                     amountText: "1500", payee: "Usta", note: "", date: gider.date) }),
            ("deleteExpense", { vm.deleteExpense(role: .admin, id: gider.id) }),
            ("addMaterial", { _ = vm.addMaterial(role: .admin, projectId: pid, name: "Kireç", subtitle: "",
                                                 unit: "torba", unitPriceText: "90") }),
            ("saveSale", { _ = vm.saveSale(role: .admin, apartmentId: bos.id, buyerName: "Deneme Alıcı",
                                           priceText: "1000000", paidText: "0", payment: .kapora) }),
            ("addLedgerEntry", { _ = vm.addLedgerEntry(role: .admin, projectId: pid, partnerId: ortak.id,
                                                       kind: .sermaye, amountText: "1000",
                                                       date: Date(), note: "") }),
            ("updatePartnerShare", { _ = vm.updatePartnerShare(role: .admin, partnerId: ortak.id,
                                                               percent: max(0, ortak.sharePercent - 1)) }),
            ("generateInviteCode", { vm.generateInviteCode(role: .admin, projectId: pid) }),
            ("addDocument", { _ = vm.addDocument(role: .admin, projectId: pid, group: .ruhsat,
                                                 sourceURL: dosya, versionNote: "v1",
                                                 partnerVisible: true) }),
            ("addApartmentPhotos", { vm.addApartmentPhotos(role: .admin, apartmentId: bos.id, images: [gorsel]) }),
            ("addSitePhotos", { vm.addSitePhotos(role: .admin, projectId: pid, images: [gorsel]) }),
        ]
        if let kayit = vm.partnerLedger.first(where: { $0.projectId == pid }) {
            yollar.append(("deleteLedgerEntry", { _ = vm.deleteLedgerEntry(role: .admin, entryId: kayit.id) }))
        }
        if let foto = vm.apartmentPhotos.first(where: { $0.projectId == pid }) {
            yollar.append(("removeApartmentPhoto", { vm.removeApartmentPhoto(role: .admin, photoId: foto.id) }))
        }
        return yollar
    }

    /// Her yazma yolunu kilitli projeye karşı çalıştırır.
    private func hicbiriYazmamali(_ vm: ProjectViewModel, _ pid: UUID,
                                  beklenen: ProjectViewModel.WriteBlock,
                                  file: StaticString = #filePath, line: UInt = #line) throws {
        for (ad, cagri) in try yazmaYollari(vm, pid) {
            let once = Durum(vm)
            vm.toast = nil
            cagri()
            XCTAssertEqual(Durum(vm), once, "\(ad): kilitli projede durum değişti", file: file, line: line)
            XCTAssertEqual(vm.pendingWrites, 0, "\(ad): kilitli projeye yazma gönderildi", file: file, line: line)
            XCTAssertEqual(vm.toast, beklenen.message,
                           "\(ad): kilit sebebi söylenmedi (başka bir sebeple mi reddedildi?)",
                           file: file, line: line)
        }
    }

    // MARK: - Arşiv salt okunur

    func testArsivdekiProjeyeHicbirYoldanYazilmiyor() throws {
        let vm = kur()
        vm.projects[index(vm, DemoID.cayirova)].archivedAt = Date()
        XCTAssertEqual(vm.writeBlock(for: DemoID.cayirova), .archived)
        try hicbiriYazmamali(vm, DemoID.cayirova, beklenen: .archived)
    }

    /// Arşiv KOTADAN BAĞIMSIZ salt okunur: en üst pakette de.
    func testArsivEnUstPakettedeSaltOkunur() {
        let vm = kur()
        vm.entitlement = .plan(.kurumsal)
        vm.projects[index(vm, DemoID.kepez)].archivedAt = Date()
        XCTAssertEqual(vm.writeBlock(for: DemoID.kepez), .archived)
    }

    /// OKUMA AÇIK: arşivdeki projenin dosyaları dışa aktarılabiliyor.
    func testArsivdekiProjeDisaAktarilabiliyor() {
        let vm = kur()
        vm.projects[index(vm, DemoID.cayirova)].archivedAt = Date()
        XCTAssertFalse(vm.exportFiles(for: DemoID.cayirova, role: .admin).isEmpty,
                       "arşiv dışa aktarmayı kapattı — okuma hiçbir zaman kapanmamalı")
    }

    // MARK: - Arşivden çıkarma kotaya tabi

    func testSinirdaykenArsivdenCikarilamiyor() {
        let vm = kur()
        vm.entitlement = .free
        // Bir aktif proje kalsın, diğerleri arşivde.
        for id in sira.dropFirst() { vm.projects[index(vm, id)].archivedAt = Date() }

        vm.setArchived(false, role: .admin, projectId: DemoID.nilufer)

        XCTAssertNotNil(vm.projects[index(vm, DemoID.nilufer)].archivedAt,
                        "ücretsiz katmanda ikinci aktif proje arşivden çıkarıldı")
        XCTAssertEqual(vm.pendingWrites, 0)
        XCTAssertEqual(vm.toast, Quota.unarchiveLimitMessage(limit: 1))
    }

    /// Kontenjan boşken çıkarma ÇALIŞMALI — cümlenin önerdiği çıkış gerçek.
    func testKontenjanBoskenArsivdenCikariliyor() {
        let vm = kur()
        vm.entitlement = .free
        for id in sira { vm.projects[index(vm, id)].archivedAt = Date() }

        vm.setArchived(false, role: .admin, projectId: DemoID.nilufer)

        XCTAssertNil(vm.projects[index(vm, DemoID.nilufer)].archivedAt)
    }

    /// Arşivlemek HER ZAMAN serbest — kilitli projede de. Çıkış yolunu
    /// kilitlemek kişiyi tamamen hapsederdi.
    func testKilitliProjeArsivlenebiliyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        XCTAssertEqual(vm.writeBlock(for: DemoID.kepez), .overLimit(limit: 1))

        vm.setArchived(true, role: .admin, projectId: DemoID.kepez)

        XCTAssertNotNil(vm.projects[index(vm, DemoID.kepez)].archivedAt)
    }

    // MARK: - Sınırın üstü: en eskiler yazılabilir

    func testSinirinUstundeEnEskilerYazilabilir() throws {
        let vm = kur()
        vm.entitlement = .plan(.santiye)   // 3 aktif proje
        sirala(vm, sira)

        XCTAssertNil(vm.writeBlock(for: DemoID.cayirova))
        XCTAssertNil(vm.writeBlock(for: DemoID.nilufer))
        XCTAssertNil(vm.writeBlock(for: DemoID.kepez))
        XCTAssertEqual(vm.writeBlock(for: DemoID.kars309), .overLimit(limit: 3))
        XCTAssertEqual(vm.writeBlock(for: DemoID.kars327), .overLimit(limit: 3))
    }

    /// Bütün kayıt türleri yalnızca Çayırova'da var; o yüzden EN YENİ o
    /// yapılıyor ve sınırın dışında kalıyor.
    func testSinirDisindakiProjeyeHicbirYoldanYazilmiyor() throws {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, [DemoID.nilufer, DemoID.kepez, DemoID.kars309, DemoID.kars327, DemoID.cayirova])
        XCTAssertEqual(vm.writeBlock(for: DemoID.cayirova), .overLimit(limit: 1))
        try hicbiriYazmamali(vm, DemoID.cayirova, beklenen: .overLimit(limit: 1))
    }

    /// Sınır içindeki proje GERÇEKTEN yazılabilir — kilit fazlasını kesiyor,
    /// hepsini değil.
    func testSinirIcindekiProjeyeYazilabiliyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        XCTAssertTrue(vm.addExpense(role: .admin, projectId: DemoID.cayirova, category: .iscilik,
                                    amountText: "1000", payee: "Usta", note: "", date: Date()))
    }

    /// SEÇİM ARŞİVLEYEREK: en eskiyi arşivleyen kişi sıradakinde çalışır.
    func testArsivlemekSiradakiProjeyiAciyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        XCTAssertEqual(vm.writeBlock(for: DemoID.nilufer), .overLimit(limit: 1))

        vm.setArchived(true, role: .admin, projectId: DemoID.cayirova)

        XCTAssertNil(vm.writeBlock(for: DemoID.nilufer))
    }

    /// Paketi yükseltmek kilidi kaldırır.
    func testYukseltmeKilidiKaldiriyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        XCTAssertEqual(vm.writeBlock(for: DemoID.kars327), .overLimit(limit: 1))
        vm.entitlement = .plan(.kurumsal)
        XCTAssertNil(vm.writeBlock(for: DemoID.kars327))
    }

    /// Hak henüz bilinmiyorken (StoreKit cevap vermeden) kilit YOK: ücretli
    /// kullanıcının projesi açılışın ilk anında salt okunur görünmemeli.
    func testHakBilinmiyorkenSinirKilidiYok() {
        let vm = kur()
        vm.entitlement = .resolving
        sirala(vm, sira)
        for id in sira { XCTAssertNil(vm.writeBlock(for: id)) }
    }

    /// Başkasının projesi bu kişinin paketine göre KİLİTLENMEZ. Ortak zaten
    /// yazamıyor; ama ekranda "paketin yetmiyor" demek yanlış kişiyi suçlar.
    func testBaskasininProjesiBuPaketeGoreKilitlenmiyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        for i in vm.projects.indices { vm.projects[i].ownerUid = "baska-sahip" }
        for id in sira { XCTAssertNil(vm.writeBlock(for: id)) }
    }

    // MARK: - Yetki işlemleri kilitlenmiyor

    /// Ortağı çıkarmak bir ERİŞİM işlemi: kilitli projede de açık kalmalı.
    /// Ayrılan ortağın erişimini kesememek, kilidin koruduğu şeyden pahalı.
    func testKilitliProjedeOrtakCikarilabiliyor() throws {
        let vm = kur()
        vm.projects[index(vm, DemoID.cayirova)].archivedAt = Date()
        let ortak = try XCTUnwrap(vm.partners.first { $0.projectId == DemoID.cayirova && !$0.isFounder })
        XCTAssertTrue(vm.removePartner(role: .admin, partnerId: ortak.id))
    }

    // MARK: - Geri yükleme kotaya tabi

    func testSinirdaykenGeriYuklemeReddediliyor() async {
        let vm = kur()
        vm.entitlement = .free
        let tarih = Date(timeIntervalSince1970: 1_750_000_000)
        let proje = Project(id: UUID(), blockNumber: "77", parcelNumber: "1",
                            district: "Gebze", city: "Kocaeli", floors: 2, totalApartments: 4,
                            phase: .temel, progress: 0, ownerUid: "eski", memberUids: ["eski"],
                            createdAt: tarih, invite: nil, photoCount: 0)
        let yedek = ProjectExporter.Backup(
            surum: ProjectExporter.backupVersion, olusturma: tarih, aliciDahil: false,
            proje: proje, malzemeler: [], malzemeHareketleri: [], giderler: [], daireler: [],
            tahsilatlar: [], taksitler: [], ortaklar: [], ortakCari: nil, belgeler: [],
            alicilar: [], denetimIzi: [])

        let sonuc = await vm.restore(from: yedek, user: .admin)

        XCTAssertEqual(sonuc, .refused(.overQuota(limit: 1)))
        XCTAssertFalse(vm.projects.contains { $0.id == proje.id })
    }

    // MARK: - Bağımsız inceleme bulguları (25 Eki)

    /// HAK DEĞİŞİNCE EKRANLAR HABERDAR OLMALI. `entitlement` yayımlanmıyordu:
    /// "Satın Almak İçin Sor" onayı, iade ya da başka cihazdan yükseltme
    /// `Transaction.updates` ile geliyor ve başka hiçbir şey ekranı
    /// tazelemiyorsa kilit şeridi ve gizli düğmeler eski hakta kalıyordu.
    func testHakDegisinceGorunumModeliYayimliyor() {
        let vm = kur()
        var sayac = 0
        let abone = vm.objectWillChange.sink { sayac += 1 }
        vm.entitlement = .plan(.kurumsal)
        XCTAssertGreaterThan(sayac, 0, "hak değişti ama görünümler haber almadı")
        abone.cancel()
    }

    /// ERİŞİMİ OLMAYAN ORTAK KAYDI DAVET SINIRINI YEMEZ. Geri yükleme ortak
    /// kayıtlarını `userUid`siz getiriyor ve özet "yeniden davet etmen
    /// gerekiyor" diyor; eskiden bu kayıtlar sayıldığı için ücretsiz katmanda
    /// yeniden davet edilemiyordu.
    func testErisimiOlmayanOrtakKaydiDavetSiniriniYemiyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        for i in vm.partners.indices where vm.partners[i].projectId == DemoID.cayirova && !vm.partners[i].isFounder {
            vm.partners[i].userUid = nil
        }
        XCTAssertGreaterThanOrEqual(vm.partners(for: DemoID.cayirova).filter { !$0.isFounder }.count, 2,
                                    "tohum veride en az iki ortak bekleniyordu")

        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)

        XCTAssertNotEqual(vm.toast, Quota.partnerLimitMessage(limit: 2))
        XCTAssertNotNil(vm.projects[index(vm, DemoID.cayirova)].invite, "davet kodu üretilmedi")
    }

    /// Ters yön: erişimi OLAN iki ortak sınırı doldurur.
    func testErisimiOlanIkiOrtakSiniriDolduruyor() {
        let vm = kur()
        vm.entitlement = .free
        sirala(vm, sira)
        var n = 0
        for i in vm.partners.indices where vm.partners[i].projectId == DemoID.cayirova && !vm.partners[i].isFounder {
            vm.partners[i].userUid = "uid-\(n)"; n += 1
        }
        XCTAssertGreaterThanOrEqual(n, 2)

        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)

        XCTAssertEqual(vm.toast, Quota.partnerLimitMessage(limit: 2))
    }
}
