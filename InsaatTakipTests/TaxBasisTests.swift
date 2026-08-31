import XCTest
@testable import InsaatTakip

/// KDV tabanı beyanı — madde 80.
///
/// NEDEN BU TESTLER VAR: bu madde bir DEFTER değil, bir KAYIT SÖZLEŞMESİ.
/// Dolayısıyla iki şey kanıtlanmalı: (1) beyan hiçbir rakamı değiştirmiyor —
/// değiştirseydi uygulama sessizce vergi hesaplamış olurdu; (2) alanın
/// eklenmesi mevcut proje belgelerini açılamaz hâle getirmiyor. İkincisi
/// teorik bir kaygı değil: Swift'in türetilmiş çözümleyicisi eksik anahtarda
/// varsayılan değeri KULLANMIYOR, `keyNotFound` atıyor.
@MainActor
final class TaxBasisTests: XCTestCase {

    private func kur() -> (ProjectViewModel, Project) {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return (vm, vm.projects[0])
    }

    /// Yeni projede beyan YOK — ve bu bir iddia değil, iddianın yokluğu.
    func testDefaultsToUndeclared() {
        let (_, proje) = kur()
        XCTAssertNil(proje.expenseTaxBasis)
        XCTAssertNil(proje.salesTaxBasis)
        XCTAssertEqual(proje.expenseTaxBasis.label, "Belirtilmedi")
        XCTAssertEqual(proje.expenseTaxBasis.fieldSuffix, "",
                       "beyan yokken alan etiketine ek yazılmamalı")
    }

    /// BEYAN HİÇBİR TUTARI DEĞİŞTİRMİYOR.
    ///
    /// Maddenin tek işi kayıt: "KDV dahil" demek, girilmiş 100.000 ₺'yi
    /// 83.333 ₺ yapmaz. Yapsaydı uygulama vergi hesaplamış olurdu ve o
    /// hesabın oranı, dönemi ve düzeltmesi hiçbir yerde tutulmuyor.
    func testDeclarationChangesNoAmount() {
        let (vm, proje) = kur()
        let ciroOnce = vm.totalSales(for: proje.id)
        let giderOnce = vm.totalCost(for: proje.id)
        let netOnce = vm.netAmount(for: proje.id)

        vm.setTaxBasis(role: .admin, projectId: proje.id, expense: .dahil, sales: .haric)

        XCTAssertEqual(vm.totalSales(for: proje.id), ciroOnce)
        XCTAssertEqual(vm.totalCost(for: proje.id), giderOnce)
        XCTAssertEqual(vm.netAmount(for: proje.id), netOnce)
    }

    /// Beyan kaydediliyor ve DENETİM İZİNE yazılıyor.
    ///
    /// Beyan bir gün değiştiğinde, o günden öncesi ve sonrası aynı defterde
    /// farklı anlam taşıyan rakamlar hâline gelir; hangi fişin hangi beyan
    /// altında girildiği ancak izde kalır.
    func testDeclarationIsAudited() {
        let (vm, proje) = kur()
        vm.setTaxBasis(role: .admin, projectId: proje.id, expense: .dahil, sales: .haric)

        let guncel = vm.projects.first { $0.id == proje.id }
        XCTAssertEqual(guncel?.expenseTaxBasis, .dahil)
        XCTAssertEqual(guncel?.salesTaxBasis, .haric)

        let degisiklikler = vm.audit(forProject: proje.id).flatMap(\.changes)
        XCTAssertEqual(degisiklikler.first { $0.field == "Gider KDV tabanı" }?.newValue, "KDV dahil")
        XCTAssertEqual(degisiklikler.first { $0.field == "Satış KDV tabanı" }?.newValue, "KDV hariç")
    }

    /// Beyan GERİ ALINABİLİR: yanlış işaretleyen kullanıcı "belirtilmedi"ye
    /// dönebilmeli. Uydurma bir beyan, beyansızlıktan kötüdür — çünkü
    /// sonrasında kimse sorgulamaz.
    func testDeclarationCanBeCleared() {
        let (vm, proje) = kur()
        vm.setTaxBasis(role: .admin, projectId: proje.id, expense: .dahil, sales: .dahil)
        vm.setTaxBasis(role: .admin, projectId: proje.id, expense: nil, sales: nil)
        XCTAssertNil(vm.projects.first { $0.id == proje.id }?.expenseTaxBasis)
    }

    /// ORTAK BEYAN EDEMEZ: bu rakamların ne olduğunu bilen kişi yönetici.
    func testPartnerCannotDeclare() {
        let (vm, proje) = kur()
        vm.setTaxBasis(role: .partner, projectId: proje.id, expense: .dahil, sales: .haric)
        XCTAssertNil(vm.projects.first { $0.id == proje.id }?.expenseTaxBasis)
    }

    /// DEĞİŞİKLİK YOKSA KAYIT DA YOK: aynı beyanı ikinci kez kaydetmek
    /// denetim izine boş bir satır eklemez.
    func testNoOpDeclarationWritesNothing() {
        let (vm, proje) = kur()
        vm.setTaxBasis(role: .admin, projectId: proje.id, expense: .dahil, sales: .haric)
        let once = vm.audit(forProject: proje.id).count
        vm.setTaxBasis(role: .admin, projectId: proje.id, expense: .dahil, sales: .haric)
        XCTAssertEqual(vm.audit(forProject: proje.id).count, once)
    }

    /// ESKİ PROJE BELGESİ HÂLÂ AÇILIYOR — göç yok.
    ///
    /// Alan opsiyonel olmasaydı (varsayılan değerli ama opsiyonel olmayan),
    /// bu belge `keyNotFound` ile patlar ve üretimdeki HER proje okunamaz
    /// hâle gelirdi. Ölçülmüş davranış: türetilmiş çözümleyici varsayılanı
    /// kullanmıyor.
    func testDecodingProjectWithoutTaxFields() throws {
        let json = """
        {"id":"\(UUID().uuidString)","blockNumber":"145","parcelNumber":"2",
         "district":"Çayırova","city":"Kocaeli","floors":5,"totalApartments":20,
         "phase":"Kaba inşaat","progress":68,"ownerUid":"u1","memberUids":["u1"],
         "createdAt":0,"photoCount":0}
        """
        let proje = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertNil(proje.expenseTaxBasis)
        XCTAssertNil(proje.salesTaxBasis)
        XCTAssertEqual(proje.progress, 68)
    }

    /// CSV SÜTUN BAŞLIĞI BEYANI TAŞIYOR.
    ///
    /// Dosyayı açan mali müşavir projenin beyanını göremez, yalnızca
    /// sayıları görür; "Tutar" başlığı tek başına o rakamın ne olduğunu
    /// söylemiyordu.
    func testCSVHeaderCarriesDeclaration() {
        let (vm, proje) = kur()
        let giderler = vm.expenses.filter { $0.projectId == proje.id }
        let baslik = ProjectExporter.expensesCSV(giderler, taxBasis: .dahil)
            .components(separatedBy: "\n")[0]
        XCTAssertTrue(baslik.contains("KDV dahil"), "başlıkta beyan yok: \(baslik)")

        // Beyan yoksa ek de yok: "(belirtilmedi)" olmayan bir bilgiyi varmış
        // gibi gösterirdi.
        let beyansiz = ProjectExporter.expensesCSV(giderler, taxBasis: nil)
            .components(separatedBy: "\n")[0]
        XCTAssertFalse(beyansiz.contains("KDV"))
        XCTAssertFalse(beyansiz.contains("Belirtilmedi"))
    }

}
