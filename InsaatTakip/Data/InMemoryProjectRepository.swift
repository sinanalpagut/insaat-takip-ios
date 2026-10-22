import Foundation

// MARK: - Bellek içi ProjectRepository (Faz 1)
//
// Kalıcılık yok: uygulama kapanınca veri gider. Bu, App Store için yeterli
// değil (bkz. ANALIZ.md Faz 2) ama dikişin bugün doğru yerde olmasını sağlar.
// Firestore geldiğinde YALNIZCA bu sınıfın yerine yenisi yazılacak; ViewModel
// ve 22 view dosyası olduğu gibi kalacak.

@MainActor
final class InMemoryProjectRepository: ProjectRepository {

    // Demo verisi bu alanlara yazılır (bkz. InMemoryProjectRepository+Seed.swift).
    var projects: [Project] = []
    var materials: [Material] = []
    var materialLogs: [MaterialLog] = []
    var apartments: [Apartment] = []
    var partners: [Partner] = []
    var documents: [ProjectDocument] = []
    var activities: [ActivityItem] = []
    var sitePhotos: [SitePhoto] = []
    var expenses: [Expense] = []
    var payments: [Payment] = []
    var partnerLedger: [PartnerLedgerEntry] = []
    var installments: [Installment] = []
    var apartmentPhotos: [ApartmentPhoto] = []
    var auditEntries: [AuditEntry] = []

    init() {
        loadMockData()
    }

    // MARK: Okuma

    func cachedSnapshot() -> DataSnapshot {
        DataSnapshot(projects: projects, materials: materials, materialLogs: materialLogs,
                     apartments: apartments, partners: partners, documents: documents,
                     activities: activities, sitePhotos: sitePhotos, expenses: expenses,
                     payments: payments, installments: installments,
                     partnerLedger: partnerLedger,
                     apartmentPhotos: apartmentPhotos,
                     auditEntries: auditEntries)
    }

    /// Bellek içi kaynakta ağ yok; önbellekle aynı veriyi döndürür.
    func load() async throws -> DataSnapshot { cachedSnapshot() }

    // MARK: Yazma

    /// Sıra korunur. Bellek içinde "atomiklik" kendiliğinden sağlanır (tek aktör,
    /// tek geçiş); Firestore uygulamasında burası bir WriteBatch olacak.
    /// Kurulum işaretleri — kuralın `establishToken` denetiminin taklidi.
    private var establishTokens: [UUID: String] = [:]

    /// Var olup bu kullanıcının OKUYAMADIĞI projeler (başkasının). Test kancası:
    /// kural ikisini ayırt ettirmediği için ön okuma bunlara "okunamıyor" der,
    /// kurulum yazması ise reddedilir.
    var foreignProjectIds: Set<UUID> = []

    func apply(_ changes: [DocumentChange]) async throws {
        // KURALIN TAKLİDİ, yazmadan ÖNCE: kurulum yalnızca belge yoksa ya da
        // AYNI işaretle yeniden gönderiliyorsa geçer. Eskiden burada düz
        // `upsert` vardı ve birim testleri "sunucuda var, yerelde yok"
        // durumunu hiç üretemiyordu — ezme hatası bu yüzden görünmüyordu.
        for change in changes {
            guard case .createProject(let p, let token) = change else { continue }
            if foreignProjectIds.contains(p.id) { throw RepositoryError.accessDenied }
            if projects.contains(where: { $0.id == p.id }), establishTokens[p.id] != token {
                throw RepositoryError.accessDenied
            }
        }
        for change in changes { apply(change) }
    }

    func probeProject(_ id: UUID) async throws -> ProjectProbe {
        guard projects.contains(where: { $0.id == id }), !foreignProjectIds.contains(id) else {
            return .notReadable
        }
        let kayitVar = auditEntries.contains { $0.projectId == id }
                    || apartments.contains { $0.projectId == id }
        return .readable(establishToken: establishTokens[id], hasRecords: kayitVar)
    }

    private func apply(_ change: DocumentChange) {
        switch change {
        // ÜRETİM DEPOSUYLA AYNI DARALTMA. Buraya uygulanmazsa demo ile üretim
        // sessizce ayrışır ve bunu hiçbir şey haber vermez: birim testlerin
        // tamamı bu depo üzerinde koşuyor, DEBUG'daki `verifySeam` ise yalnızca
        // kayıt SAYISI karşılaştırıyor — eksik ya da ezilmiş bir ALAN sayıyı
        // değiştirmediği için görünmez. O hâlde testler düzeltmeyi değil,
        // hangi depoya bakıldığını ölçerdi.
        case .project(let value):
            if let i = projects.firstIndex(where: { $0.id == value.id }) {
                var birlesik = value
                birlesik.memberUids = projects[i].memberUids
                birlesik.invite = projects[i].invite
                projects[i] = birlesik
            } else {
                upsert(value, into: &projects)
            }
        case .createProject(let value, let token):
            establishTokens[value.id] = token
            upsert(value, into: &projects)
        case .projectMembership(let pid, let uid, let op):
            if let i = projects.firstIndex(where: { $0.id == pid }) {
                switch op {
                case .add:
                    if !projects[i].memberUids.contains(uid) { projects[i].memberUids.append(uid) }
                case .remove:
                    projects[i].memberUids.removeAll { $0 == uid }
                }
            }
        case .projectInvite(let pid, let invite):
            if let i = projects.firstIndex(where: { $0.id == pid }) { projects[i].invite = invite }
        case .material(let value):       upsert(value, into: &materials)
        case .apartment(let value):      upsert(value, into: &apartments)
        case .partner(let value):        upsert(value, into: &partners)

        // Aşağıdaki üç koleksiyon ekranda YENİDEN ESKİYE listeleniyor; yeni kayıt
        // başa eklenir ki `load()` ekranın gördüğü sırayı birebir döndürsün.
        case .materialLog(let value):    upsert(value, into: &materialLogs, newestFirst: true)
        case .expense(let value):        upsert(value, into: &expenses, newestFirst: true)
        case .audit(let value):          upsert(value, into: &auditEntries, newestFirst: true)
        case .activity(let value):       upsert(value, into: &activities, newestFirst: true)

        case .payment(let value):        upsert(value, into: &payments)
        case .partnerLedger(let value):  upsert(value, into: &partnerLedger)
        case .installment(let value):    upsert(value, into: &installments)
        case .document(let value):       upsert(value, into: &documents, newestFirst: true)
        case .sitePhoto(let value):      upsert(value, into: &sitePhotos, newestFirst: true)
        case .apartmentPhoto(let value): upsert(value, into: &apartmentPhotos)

        // Bellekte ayrı alıcı dizisi YOK: kimlik doğrudan dairenin alanına
        // işlenir. Ayrım yalnızca kodlama/yol sınırında (Firestore) gerekli.
        case .buyer(let value):
            if let index = apartments.firstIndex(where: { $0.id == value.apartmentId }) {
                apartments[index].buyerName = value.name
            }
        case .deleteBuyer(let apartmentId, _):
            if let index = apartments.firstIndex(where: { $0.id == apartmentId }) {
                apartments[index].buyerName = nil
            }

        // Bellek içinde proje kimliğine gerek yok (kimlik tek başına benzersiz);
        // Firestore uygulamasında doküman YOLUNU kurmak için kullanılacak.
        case .deleteMaterialLog(let id, _):     materialLogs.removeAll { $0.id == id }
        case .deleteExpense(let id, _):         expenses.removeAll { $0.id == id }
        case .deletePayment(let id, _):         payments.removeAll { $0.id == id }
        case .deletePartnerLedger(let id, _):   partnerLedger.removeAll { $0.id == id }
        case .deleteApartmentPhoto(let id, _):  apartmentPhotos.removeAll { $0.id == id }
        case .deletePartner(let id, _):         partners.removeAll { $0.id == id }
        case .deleteApartment(let id, _):       apartments.removeAll { $0.id == id }
        case .deletePayments(let ids, _):
            let dropped = Set(ids)
            payments.removeAll { dropped.contains($0.id) }
        case .deleteInstallments(let ids, _):
            let dropped = Set(ids)
            installments.removeAll { dropped.contains($0.id) }
        }
    }

    /// Kimliği varsa günceller, yoksa ekler — Firestore'un `setData` davranışı.
    private func upsert<T: Identifiable>(_ value: T, into list: inout [T],
                                         newestFirst: Bool = false) {
        if let index = list.firstIndex(where: { $0.id == value.id }) {
            list[index] = value
        } else if newestFirst {
            list.insert(value, at: 0)
        } else {
            list.append(value)
        }
    }

    // MARK: Demo verisi kurulurken kullanılan yardımcılar

    func material(in projectId: UUID, code: String) -> Material? {
        materials.first { $0.projectId == projectId && $0.code == code }
    }

    func apartment(in projectId: UUID, number: Int) -> Apartment? {
        apartments.first { $0.projectId == projectId && $0.apartmentNumber == number }
    }

    /// Demo verisinde elle yazılan `paidAmount`, üretilen ödeme kayıtlarından
    /// yeniden türetilir; böylece kaynak veri kendi içinde tutarlı çıkar.
    /// (Çalışma zamanındaki karşılığı ProjectViewModel.recalculateCollected.)
    func recalculateCollected(for apartmentId: UUID) {
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }) else { return }
        apartments[index].paidAmount = payments
            .filter { $0.apartmentId == apartmentId }
            .reduce(Kurus.zero) { $0 + $1.amount }
    }
}
