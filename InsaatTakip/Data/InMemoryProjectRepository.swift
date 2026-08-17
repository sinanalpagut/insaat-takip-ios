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
                     payments: payments, apartmentPhotos: apartmentPhotos,
                     auditEntries: auditEntries)
    }

    /// Bellek içi kaynakta ağ yok; önbellekle aynı veriyi döndürür.
    func load() async throws -> DataSnapshot { cachedSnapshot() }

    // MARK: Yazma

    /// Sıra korunur. Bellek içinde "atomiklik" kendiliğinden sağlanır (tek aktör,
    /// tek geçiş); Firestore uygulamasında burası bir WriteBatch olacak.
    func apply(_ changes: [DocumentChange]) async throws {
        for change in changes { apply(change) }
    }

    private func apply(_ change: DocumentChange) {
        switch change {
        case .project(let value):        upsert(value, into: &projects)
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
        case .document(let value):       upsert(value, into: &documents, newestFirst: true)
        case .sitePhoto(let value):      upsert(value, into: &sitePhotos, newestFirst: true)
        case .apartmentPhoto(let value): upsert(value, into: &apartmentPhotos)

        // Bellek içinde proje kimliğine gerek yok (kimlik tek başına benzersiz);
        // Firestore uygulamasında doküman YOLUNU kurmak için kullanılacak.
        case .deleteMaterialLog(let id, _):     materialLogs.removeAll { $0.id == id }
        case .deleteExpense(let id, _):         expenses.removeAll { $0.id == id }
        case .deletePayment(let id, _):         payments.removeAll { $0.id == id }
        case .deleteApartmentPhoto(let id, _):  apartmentPhotos.removeAll { $0.id == id }
        case .deletePayments(let ids, _):
            let dropped = Set(ids)
            payments.removeAll { dropped.contains($0.id) }
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
