import XCTest
@testable import InsaatTakip

/// Kota ve hak — madde 87.
///
/// NEDEN BU TESTLER VAR: sınır `Entitlement` üzerinden enjekte ediliyor;
/// gerçek hak `SubscriptionManager`dan geliyor. Testler sınırı doğrudan
/// kurarak kotanın kendi kararını denetliyor. Eski giriş cümlesi: sınır o
/// gün AÇIK DEĞİLDİ (`resolving`) ve
/// açık olmayan bir mekanizmanın çalıştığı iddia edilemez. Testler sınırı
/// enjekte ederek yayın gününü BUGÜN provası yapıyor: kapatılan tek şey bir
/// sabit olduğunda, kapatınca ne olacağı önceden biliniyor.
@MainActor
final class QuotaTests: XCTestCase {

    private func kur() -> ProjectViewModel {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return vm
    }

    /// HAK BİLİNMİYORKEN SINIR YOK — açılışın ilk anı (gerekçe
    /// `Entitlement.resolving`ta).
    func testResolvingIsUnlimited() {
        XCTAssertNil(Entitlement.resolving.activeProjectLimit)
        let snapshot = QuotaSnapshot(activeProjects: 99)
        XCTAssertEqual(Quota.canCreateProject(snapshot, entitlement: .resolving), .allowed)
    }

    /// Ücretsiz katman: 1 aktif proje.
    func testFreeTierAllowsOneActiveProject() {
        XCTAssertEqual(Entitlement.free.activeProjectLimit, 1)
        XCTAssertEqual(Quota.canCreateProject(QuotaSnapshot(activeProjects: 0), entitlement: .free),
                       .allowed)
        XCTAssertEqual(Quota.canCreateProject(QuotaSnapshot(activeProjects: 1), entitlement: .free),
                       .wouldExceedProjects(limit: 1))
    }

    /// ARŞİVLENMİŞ PROJE SAYILMIYOR.
    ///
    /// İnşaat yıllarca sürüyor ve biten projenin kayıtları vergi/muhasebe
    /// için duruyor (madde 60). Arşivi saymak, kullanıcıyı yeni proje
    /// açabilmek için kendi geçmişini silmeye iterdi.
    func testArchivedProjectsDoNotCountAgainstLimit() {
        let snapshot = QuotaSnapshot(activeProjects: 1, archivedProjects: 12)
        XCTAssertEqual(Quota.canCreateProject(snapshot, entitlement: .plan(.santiye)),
                       .allowed)
    }

    /// SINIR GERÇEKTEN UYGULANIYOR — `addProject` boğazından geçiyor.
    func testAddProjectRespectsLimit() {
        let vm = kur()
        vm.entitlement = .free
        // Tohum veride zaten aktif proje var; ücretsiz katmanda yeni proje
        // açılamamalı.
        let once = vm.projects.count
        let sonuc = vm.addProject(user: .admin, block: "999", parcel: "1",
                                  district: "—", city: "—", floors: 1, apartmentCount: 1)
        XCTAssertNil(sonuc)
        XCTAssertEqual(vm.projects.count, once)
    }

    /// ARŞİVLEYİNCE YENİ PROJE AÇILABİLİYOR — kullanıcıya söylenen cümlenin
    /// gerçekten işe yaradığı kanıtlanmalı, yoksa cümle çıkışsız bir öneri.
    func testArchivingFreesTheSlot() {
        let vm = kur()
        for proje in vm.projects {
            vm.setArchived(true, role: .admin, projectId: proje.id)
        }
        vm.entitlement = .free
        let yeni = vm.addProject(user: .admin, block: "999", parcel: "1",
                                 district: "—", city: "—", floors: 1, apartmentCount: 1)
        XCTAssertNotNil(yeni)
    }

    /// ORTAK OLARAK KATILDIĞI PROJELER SAYILMIYOR.
    ///
    /// Ortak başına ücret alınmayacağı kararının kod karşılığı: ortağın
    /// gördüğü projelerin maliyeti davet eden müteahhidin hanesinde.
    func testProjectsWhereUserIsOnlyMemberDoNotCount() {
        let vm = kur()
        let baskasi = "baska-uid"
        for i in vm.projects.indices {
            vm.projects[i].ownerUid = baskasi
            if !vm.projects[i].memberUids.contains(User.admin.id) {
                vm.projects[i].memberUids.append(User.admin.id)
            }
        }
        XCTAssertEqual(vm.quotaSnapshot(for: .admin).activeProjects, 0)
        vm.entitlement = .free
        XCTAssertNotNil(vm.addProject(user: .admin, block: "999", parcel: "1",
                                      district: "—", city: "—", floors: 1, apartmentCount: 1))
    }

    /// Sınır cümlesi NE YAPACAĞINI söylüyor.
    func testLimitMessageOffersAWayOut() {
        XCTAssertTrue(Quota.limitMessage(limit: 1).contains("arşivlersen"))
        XCTAssertTrue(Quota.limitMessage(limit: 3).contains("3 aktif proje"))
    }

    /// SINIR CÜMLESİ İKİ ÇIKIŞI DA SÖYLÜYOR — ve BEDAVA OLAN ÖNCE.
    ///
    /// Yalnızca paketi söylemek, kullanıcının zaten hakkı olan ücretsiz
    /// çözümü (arşivlemek) saklamak olurdu. Yalnızca arşivi söylemek ise
    /// satın almaya en yakın anda ürünü susturuyordu — 16 Eki 2026'ya kadarki
    /// hâli buydu.
    ///
    /// SIRA DA TESTTE: arşiv cümlesi pakete göre ÖNCE geçmeli. Ücretsiz
    /// çıkışı ikinci plana atmak, dürüstlüğü biçimsel olarak korurken fiilen
    /// kaybetmek olur.
    func testLimitMessageNamesBothExitsFreeFirst() {
        for sinir in [1, 3, 10] {
            let mesaj = Quota.limitMessage(limit: sinir)
            guard let arsivYeri = mesaj.range(of: "arşivlersen"),
                  let paketYeri = mesaj.range(of: "paket") else {
                return XCTFail("sınır \(sinir): iki çıkıştan biri cümlede yok — \(mesaj)")
            }
            XCTAssertTrue(arsivYeri.lowerBound < paketYeri.lowerBound,
                          "sınır \(sinir): ücretsiz çıkış paketten SONRA geçiyor")
        }
    }

    // MARK: - Ortak kotası (15 Eki 2026 kararı)

    /// ÜCRETSİZ KATMAN DAR BAŞLIYOR: 2 davetli ortak.
    ///
    /// Gerekçe asimetri: sınırı gevşetmek bedava, sıkmak imkânsız. Bugün 2
    /// verip sonra "sınırsız" demek hediye; tersi, zaten davet etmiş
    /// kullanıcıdan geri almak.
    func testFreeTierAllowsTwoInvitedPartners() {
        XCTAssertEqual(Entitlement.free.invitedPartnerLimit, 2)
        XCTAssertEqual(Quota.canInvitePartner(invitedCount: 1, entitlement: .free), .allowed)
        XCTAssertEqual(Quota.canInvitePartner(invitedCount: 2, entitlement: .free),
                       .wouldExceedPartners(limit: 2))
    }

    /// ÜCRETLİ KATMANDA ORTAK SINIRSIZ — kişi başına ücret ALINMIYOR.
    ///
    /// Ortak salt okur ve parayı ödeyen müteahhit; kişi başına ücret, ürünü
    /// ayıran tek şeyi (ortakla şeffaflık) vergilendirmek olurdu.
    func testPaidTiersHaveNoPartnerLimit() {
        XCTAssertNil(Entitlement.plan(.santiye).invitedPartnerLimit)
        XCTAssertEqual(Quota.canInvitePartner(invitedCount: 99,
                                              entitlement: .plan(.santiye)),
                       .allowed)
    }

    /// KURUCU SAYILMIYOR: kendi `Partner` kaydı sınırı yemez.
    func testFounderDoesNotCountAgainstPartnerLimit() {
        let vm = kur()
        vm.entitlement = .free
        let proje = vm.projects[0]
        // Tohum veride kurucu + davetliler var; davetliler sıfırlanınca
        // kurucuya rağmen davet mümkün olmalı.
        vm.partners.removeAll { $0.projectId == proje.id && !$0.isFounder }
        let davetli = vm.partners(for: proje.id).filter { !$0.isFounder }.count
        XCTAssertEqual(davetli, 0)
        XCTAssertEqual(Quota.canInvitePartner(invitedCount: davetli, entitlement: .free), .allowed)
    }

    // MARK: - Sınır ile ödeme yolu birbirine bağlı

    /// SINIRA ÇARPAN KİŞİNİN ÖDEYEREK ÇIKABİLECEĞİ BİR ÜRÜN OLMALI.
    ///
    /// Eskiden `Plan.purchasesAvailable` bayrağını denetliyordu: kota açılıp
    /// satın alma kapalı kalırsa kullanıcı çıkışı olmayan bir duvara çarpardı.
    /// Bayrak StoreKit gelince (25 Eki 2026) kalktı; aynı söz artık şöyle
    /// tutuluyor: sınırı olan her katmanın ÜSTÜNDE, mağazada satılan ve o
    /// sınırı genişleten bir paket var.
    func testEveryLimitHasAPaidWayOut() {
        for plan in Plan.allCases {
            guard let sinir = plan.activeProjectLimit else { continue }
            let cikis = Plan.purchasable.first { ust in
                ust.rank > plan.rank && (ust.activeProjectLimit ?? .max) > sinir
                    && ust.monthlyProductId != nil && ust.yearlyProductId != nil
            }
            XCTAssertNotNil(cikis, "\(plan.rawValue) sınırının üstünde satın alınabilir paket yok")
        }
    }

    /// Sınır cümlesi NE YAPACAĞINI söylüyor — burada çıkış arşivlemek değil.
    func testPartnerLimitMessagePointsToUpgrade() {
        let mesaj = Quota.partnerLimitMessage(limit: 2)
        XCTAssertTrue(mesaj.contains("2 ortak"))
        XCTAssertTrue(mesaj.contains("yükselt"))
    }

}
