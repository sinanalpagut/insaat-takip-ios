import XCTest
@testable import InsaatTakip

/// Ortak cari hesabı — madde 82.
///
/// NEDEN BU TESTLER VAR: bu defterin var olma sebebi, bir dağıtımı kaydetmenin
/// TEK yolunun `.diger` kategorisinde bir gider olmasıydı — ve
/// `netAmount = satış − (malzeme + diğer gider)` olduğu için ortağa para
/// ödemek, dağıtımın dayandığı rakamı BÜTÜN ortaklar için birden
/// düşürüyordu. Yani bu maddenin ilk korkuluğu "cari hareket hiçbir gider
/// toplamına girmez" ve bir gün biri bu iki dünyayı birleştirmeye kalkarsa
/// testin patlaması gerekiyor.
@MainActor
final class PartnerLedgerTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Project, [Partner]) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        let proje = vm.projects[0]
        return (vm, proje, vm.partners(for: proje.id))
    }

    /// CARİ HAREKET GİDER DEĞİL — maddenin tek en önemli korkuluğu.
    func testLedgerNeverTouchesCostOrNet() {
        let (vm, proje, ortaklar) = kur()
        let giderOnce = vm.totalCost(for: proje.id)
        let netOnce = vm.netAmount(for: proje.id)
        let malzemeOnce = vm.totalMaterialCost(for: proje.id)
        let digerOnce = vm.totalOtherExpenses(for: proje.id)

        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortaklar[0].id,
                          kind: .dagitim, amountText: "2.000.000", date: Date(), note: "Kâr payı")
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortaklar[0].id,
                          kind: .sermaye, amountText: "1.000.000", date: Date(), note: "Sermaye")

        XCTAssertEqual(vm.totalCost(for: proje.id), giderOnce, "cari hareket gidere girdi")
        XCTAssertEqual(vm.netAmount(for: proje.id), netOnce, "cari hareket dönem netini bozdu")
        XCTAssertEqual(vm.totalMaterialCost(for: proje.id), malzemeOnce)
        XCTAssertEqual(vm.totalOtherExpenses(for: proje.id), digerOnce)
    }

    /// Bakiye = sermaye − (çekilen + dağıtım).
    func testBalanceArithmetic() {
        let (vm, proje, ortaklar) = kur()
        let ortak = ortaklar[0]
        // Tohum verideki hareketleri temizle: test kendi başlangıcını kurar.
        vm.partnerLedger.removeAll { $0.projectId == proje.id }

        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortak.id,
                          kind: .sermaye, amountText: "1.000", date: Date(), note: "")
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortak.id,
                          kind: .cekilen, amountText: "300", date: Date(), note: "")
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortak.id,
                          kind: .dagitim, amountText: "200", date: Date(), note: "")

        let bakiye = vm.balance(forPartner: ortak.id)
        XCTAssertEqual(bakiye.capital, Kurus.lira(1_000))
        XCTAssertEqual(bakiye.withdrawn, Kurus.lira(300))
        XCTAssertEqual(bakiye.distributed, Kurus.lira(200))
        XCTAssertEqual(bakiye.net, Kurus.lira(500))
    }

    /// EKSİ BAKİYE GİZLENMİYOR.
    ///
    /// Koyduğundan fazlasını çekmiş ortak ortaklığa borçludur; rakamı sıfırda
    /// kırpmak, borcu uygulamanın içinde görünmez yapardı.
    func testBalanceCanGoNegative() {
        let (vm, proje, ortaklar) = kur()
        vm.partnerLedger.removeAll { $0.projectId == proje.id }
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortaklar[0].id,
                          kind: .cekilen, amountText: "500", date: Date(), note: "")
        XCTAssertTrue(vm.balance(forPartner: ortaklar[0].id).net < .zero)
    }

    /// TUTAR HER ZAMAN POZİTİF, YÖN TÜRDEN GELİYOR.
    ///
    /// Tek bir işaretli para alanı olsaydı, formda "−" yazmayı unutan
    /// kullanıcı sessizce ters yönde bir kayıt üretirdi.
    func testAmountStaysPositiveAndDirectionComesFromKind() {
        let (vm, proje, ortaklar) = kur()
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortaklar[0].id,
                          kind: .cekilen, amountText: "750", date: Date(), note: "")
        let kayit = vm.ledger(forPartner: ortaklar[0].id).first { $0.amount == Kurus.lira(750) }
        XCTAssertNotNil(kayit)
        XCTAssertTrue(kayit!.amount > .zero, "tutar pozitif tutulmalı")
        XCTAssertEqual(kayit?.signedAmount, Kurus.zero - Kurus.lira(750))
    }

    /// BAŞKA PROJENİN ORTAĞINA HAREKET YAZILAMAZ.
    ///
    /// Yazılabilseydi iki projenin cari hesabı sessizce birbirine karışırdı.
    func testRejectsPartnerFromAnotherProject() {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        let ilk = vm.projects[0]
        guard let yabanci = vm.partners.first(where: { $0.projectId != ilk.id }) else {
            return XCTFail("ikinci projede ortak yok")
        }
        let once = vm.ledger(for: ilk.id).count
        let sonuc = vm.addLedgerEntry(role: .admin, projectId: ilk.id, partnerId: yabanci.id,
                                      kind: .sermaye, amountText: "100", date: Date(), note: "")
        XCTAssertFalse(sonuc)
        XCTAssertEqual(vm.ledger(for: ilk.id).count, once)
    }

    /// ORTAK YAZAMAZ — kural da reddediyor (firestore.rules · ownerWrite).
    func testPartnerCannotWrite() {
        let (vm, proje, ortaklar) = kur()
        let once = vm.ledger(for: proje.id).count
        XCTAssertFalse(vm.addLedgerEntry(role: .partner, projectId: proje.id,
                                         partnerId: ortaklar[0].id, kind: .sermaye,
                                         amountText: "100", date: Date(), note: ""))
        XCTAssertEqual(vm.ledger(for: proje.id).count, once)
    }

    /// Sıfır ya da boş tutar reddediliyor.
    func testRejectsZeroAmount() {
        let (vm, proje, ortaklar) = kur()
        XCTAssertFalse(vm.addLedgerEntry(role: .admin, projectId: proje.id,
                                         partnerId: ortaklar[0].id, kind: .sermaye,
                                         amountText: "", date: Date(), note: ""))
    }

    /// EKLEME VE SİLME DENETİM İZİNDE.
    ///
    /// Bu kayıtlar ortaklar arasındaki hesabın dayanağı; sessizce kaybolan bir
    /// sermaye kaydı tam olarak uygulamanın önlemek için var olduğu
    /// tartışmayı üretir.
    func testAddAndDeleteAreAudited() {
        let (vm, proje, ortaklar) = kur()
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortaklar[0].id,
                          kind: .sermaye, amountText: "1.500", date: Date(), note: "")
        guard let kayit = vm.ledger(forPartner: ortaklar[0].id).first(where: { $0.amount == Kurus.lira(1_500) }) else {
            return XCTFail("kayıt eklenmedi")
        }
        XCTAssertTrue(vm.audit(forProject: proje.id).contains { $0.recordId == kayit.id })

        XCTAssertTrue(vm.deleteLedgerEntry(role: .admin, entryId: kayit.id))
        XCTAssertNil(vm.partnerLedger.first { $0.id == kayit.id })
        let silmeIzi = vm.audit(forProject: proje.id)
            .filter { $0.recordId == kayit.id }
            .flatMap(\.changes)
            .first { $0.newValue == "silindi" }
        XCTAssertNotNil(silmeIzi, "silme ize yazılmadı")
    }

    /// ORTAK SİLEMEZ.
    func testPartnerCannotDelete() {
        let (vm, proje, _) = kur()
        guard let kayit = vm.ledger(for: proje.id).first else { return XCTFail("tohum hareketi yok") }
        XCTAssertFalse(vm.deleteLedgerEntry(role: .partner, entryId: kayit.id))
        XCTAssertNotNil(vm.partnerLedger.first { $0.id == kayit.id })
    }

    /// PAY HESABI CARİDEN ETKİLENMİYOR.
    ///
    /// `share(of:)` proje toplamlarını yüzdeyle dilimliyor; cari hesap ise
    /// ortağın kasayla arasındaki ayrı bir hesap. İkisini birbirine
    /// karıştırmak "payına düşen" ile "sana kalan" arasındaki farkı silerdi.
    func testShareIsUnaffectedByLedger() throws {
        let (vm, proje, ortaklar) = kur()
        guard let once = vm.share(of: ortaklar[0]) else { return XCTFail("hisse tanımsız") }
        vm.addLedgerEntry(role: .admin, projectId: proje.id, partnerId: ortaklar[0].id,
                          kind: .sermaye, amountText: "9.000.000", date: Date(), note: "")
        let sonra = try? XCTUnwrap(vm.share(of: ortaklar[0]))
        XCTAssertEqual(sonra?.sales, once.sales)
        XCTAssertEqual(sonra?.collected, once.collected)
        XCTAssertEqual(sonra?.outstanding, once.outstanding)
    }

    /// CSV AYRI DOSYA ve yön sütunu taşıyor.
    func testCSVCarriesDirection() {
        let (vm, proje, ortaklar) = kur()
        let csv = ProjectExporter.partnerLedgerCSV(vm.ledger(for: proje.id),
                                                   partners: ortaklar)
        let satirlar = csv.components(separatedBy: "\n")
        XCTAssertTrue(satirlar[0].contains("Yön"))
        XCTAssertTrue(satirlar[0].contains("İşaretli Tutar"))
        XCTAssertTrue(satirlar.dropFirst().contains { $0.contains("Giren") || $0.contains("Çıkan") })
    }
}
