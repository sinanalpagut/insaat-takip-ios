import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firestore kalıcılığı
//
// `ProjectRepository`nin gerçek uygulaması. ViewModel bu sınıfı TANIMAZ: dikiş
// Faz 1/15'te açılmıştı, bu yüzden 22 view dosyası ve ViewModel'in genel
// arayüzü değişmiyor.
//
// ─── Koleksiyon adları firestore.rules ile BİREBİR aynı olmak zorunda ───
// Buradaki bir yazım hatası kuralların varsayılan RED satırına düşer ve yazma
// "permission denied" ile geri gelir. Adlar tek bir enum'da toplandı ki 12 ayrı
// yerde tekrarlanmasın; kural tarafında da her biri ayrı testle denetleniyor.

enum RepositoryError: LocalizedError, Equatable {
    case notSignedIn
    /// Alt koleksiyon belgesi proje kimliği taşımıyor — geçerli bir yol kurulamaz.
    case missingProjectId(record: String)
    case decodeFailed(collection: String, documentId: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Oturum açık değil"
        case .missingProjectId(let record):
            return "Kayıt bir projeye bağlı değil: \(record)"
        case .decodeFailed(let collection, let documentId, let reason):
            return "Kayıt okunamadı (\(collection)/\(documentId)): \(reason)"
        }
    }
}

@MainActor
final class FirestoreProjectRepository: ProjectRepository {

    /// Koleksiyon adları. `firestore.rules` içindeki `match` bloklarıyla aynı.
    private enum Coll: String {
        case materials
        case materialLogs
        case apartments
        case partners
        case documents
        case activities
        case sitePhotos
        case expenses
        case payments
        case apartmentPhotos
        case auditEntries
        case buyers
    }

    private let db: Firestore

    /// `cachedSnapshot()`in döndürdüğü kopya. Firestore'un disk önbelleği yalnızca
    /// ASENKRON okunabiliyor (`getDocuments(source: .cache)`), protokol ise
    /// senkron bir anlık görüntü istiyor — ekranın bir kare bile boş kalmaması
    /// için. Bu yüzden son yükleme burada tutuluyor: ilk açılışta boş, `load()`
    /// tamamlanınca dolu.
    private var latest = DataSnapshot()

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    // MARK: - Protokol

    func cachedSnapshot() -> DataSnapshot { latest }

    func load() async throws -> DataSnapshot {
        guard let uid = Auth.auth().currentUser?.uid else { throw RepositoryError.notSignedIn }

        var result = DataSnapshot()

        // Üyeliğe göre sorgu ZORUNLU: güvenlik kuralı bir belgeyi doğrulayabilir
        // ama sorguya kapsam veremez. Süzgeçsiz sorgu tek tek projeleri gizlemez,
        // sorgunun TAMAMINI reddeder. (firestore.indexes.json'daki bileşik indeks
        // tam olarak bu sorgu için.)
        let projectDocs = try await db.collection("projects")
            .whereField("memberUids", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        result.projects = try projectDocs.documents.map {
            try decode(Project.self, from: $0, in: "projects")
        }
        #if DEBUG
        // Sorgu HATA VERMEDEN boş dönebiliyor (ör. önbellekten yanıtlanırsa).
        // Sessiz boşluğu ayırt etmek için uid, sonuç sayısı ve verinin
        // önbellekten mi geldiği yazdırılıyor.
        print("[load] uid=\(uid) proje=\(result.projects.count) önbellekten=\(projectDocs.metadata.isFromCache)")
        #endif

        for project in result.projects {
            let pid = project.id
            // Belgeler ROLE GÖRE farklı sorgulanıyor. Ortak için süzgeç şart:
            // `partnerVisible == false` kayıtları kural reddediyor ve süzgeç
            // olmadan sorgunun tamamı düşer. Sahip kısıtsız sorgular.
            let isOwner = project.ownerUid == uid

            // Tek projenin 11 koleksiyonu paralel; projeler arası sıralı.
            async let materials = fetch(Material.self, .materials, pid)
            async let materialLogs = fetch(MaterialLog.self, .materialLogs, pid)
            async let apartments = fetch(Apartment.self, .apartments, pid)
            async let partners = fetch(Partner.self, .partners, pid)
            async let documents = fetchDocuments(pid, ownerView: isOwner)
            async let activities = fetch(ActivityItem.self, .activities, pid)
            async let expenses = fetch(Expense.self, .expenses, pid)
            async let payments = fetch(Payment.self, .payments, pid)
            async let audits = fetch(AuditEntry.self, .auditEntries, pid)
            async let sitePhotos = fetchSitePhotos(pid)
            async let apartmentPhotos = fetchApartmentPhotos(pid)

            result.materials += try await materials
            result.materialLogs += try await materialLogs
            result.apartments += try await apartments
            result.partners += try await partners
            result.documents += try await documents
            result.activities += try await activities
            result.expenses += try await expenses
            result.payments += try await payments
            result.auditEntries += try await audits
            result.sitePhotos += try await sitePhotos
            result.apartmentPhotos += try await apartmentPhotos

            // Alıcı kimlikleri YALNIZCA sahibin projesinde çekilir. Ortak için
            // sorguyu ATMAMAK şart: kural okumayı reddeder, `getDocuments`
            // fırlatır ve TÜM yükleme düşerdi — belgelerdeki role göre sorgu
            // dersinin aynısı. Ortakta `buyerName` nil kalır; arayüz zaten nil
            // adla başa çıkıyor.
            if isOwner {
                let buyers = try await fetch(ApartmentBuyer.self, .buyers, pid)
                let names = Dictionary(uniqueKeysWithValues: buyers.map { ($0.apartmentId, $0.name) })
                for index in result.apartments.indices
                where result.apartments[index].projectId == pid {
                    result.apartments[index].buyerName = names[result.apartments[index].id]
                }
            }
        }

        // Malzeme toplamları KAYITLI DEĞİL (madde 19): `Material.CodingKeys`
        // türetilen alanları dışarıda bırakıyor, çünkü kalıcı olsalardı her fiş
        // işlemi tam dokümanı yazar ve iki cihaz eşzamanlı giriş yaptığında
        // "son yazan kazanır" sapması Malzeme ve Net rakamlarına giderdi.
        // Diskten gelen malzemede toplamlar sıfır; burada yeniden türetiliyor.
        for index in result.materials.indices {
            result.materials[index].recalculate(from: result.materialLogs)
        }

        latest = result
        return result
    }

    /// TEK kullanıcı eyleminin tüm yazmaları.
    ///
    /// İKİ AŞAMA — güvenlik kuralının dayattığı kısıt: alt koleksiyon yazmaları
    /// üst proje belgesini `get()` ile doğruluyor ve kural değerlendirmesi AYNI
    /// partideki henüz işlenmemiş yazmaları GÖRMEZ. `addProject` proje + ~20
    /// daire + 9 malzemeyi tek çağrıda veriyor; hepsi tek partiye konsa alt
    /// belgeler reddedilirdi. Bu yüzden proje belgeleri önce ve ayrı işlenir.
    /// (Kısıt `tests/rules.test.mjs` içinde bir testle sabitlendi.)
    ///
    /// Atomiklik sözü BOZULMUYOR: proje belgesi içermeyen eylemlerin (fiş, satış
    /// iptali, düzenleme, silme) tamamı tek partide kalıyor — yani "yarısı
    /// yazılmış iptal" durumu hâlâ imkânsız. Proje belgesi içeren tek çok-yazmalı
    /// eylem proje KURULUMU; orada yarı başarı "proje kuruldu, daireler gelmedi"
    /// demek: görünür ve yeniden denenebilir.
    func apply(_ changes: [DocumentChange]) async throws {
        guard !changes.isEmpty else { return }

        // 1. aşama — proje belgeleri.
        for change in changes {
            guard case .project(let project) = change else { continue }
            try await db.collection("projects").document(project.id.uuidString)
                .setData(try encode(project))
        }

        // 2. aşama — geri kalan her şey tek parti.
        let rest = changes.filter { if case .project = $0 { return false } else { return true } }
        if !rest.isEmpty {
            let batch = db.batch()
            for change in rest { try stage(change, in: batch) }
            try await batch.commit()
        }

        // Yazma başarılı: iç kopya da güncellenir.
        mirror(changes)
    }

    /// Yazma başarılı olduktan sonra iç kopyayı da günceller.
    ///
    /// Bu olmadan `cachedSnapshot()` son `load()` anında donup kalıyor ve
    /// DEBUG'daki `verifySeam` her yazmadan sonra "dikiş kopuk" diye yanlış
    /// alarm veriyor — ekranda 1 proje, kaynakta 0. Gerçek bir kopukluğu
    /// yakalaması gereken denetim, güvenilmez hale gelirdi.
    private func mirror(_ changes: [DocumentChange]) {
        for change in changes {
            switch change {
            case .project(let p):        upsert(p, into: &latest.projects)
            case .material(let m):       upsert(m, into: &latest.materials)
            case .materialLog(let l):    upsert(l, into: &latest.materialLogs)
            case .apartment(let a):      upsert(a, into: &latest.apartments)
            case .partner(let p):        upsert(p, into: &latest.partners)
            case .document(let d):       upsert(d, into: &latest.documents)
            case .activity(let a):       upsert(a, into: &latest.activities)
            case .sitePhoto(let p):      upsert(p, into: &latest.sitePhotos)
            case .expense(let e):        upsert(e, into: &latest.expenses)
            case .payment(let p):        upsert(p, into: &latest.payments)
            case .apartmentPhoto(let p): upsert(p, into: &latest.apartmentPhotos)
            case .audit(let a):          upsert(a, into: &latest.auditEntries)

            case .buyer(let b):
                if let i = latest.apartments.firstIndex(where: { $0.id == b.apartmentId }) {
                    latest.apartments[i].buyerName = b.name
                }
            case .deleteBuyer(let apartmentId, _):
                if let i = latest.apartments.firstIndex(where: { $0.id == apartmentId }) {
                    latest.apartments[i].buyerName = nil
                }
            case .deleteMaterialLog(let id, _):
                latest.materialLogs.removeAll { $0.id == id }
            case .deleteExpense(let id, _):
                latest.expenses.removeAll { $0.id == id }
            case .deletePayment(let id, _):
                latest.payments.removeAll { $0.id == id }
            case .deleteApartmentPhoto(let id, _):
                latest.apartmentPhotos.removeAll { $0.id == id }
            case .deletePayments(let ids, _):
                latest.payments.removeAll { ids.contains($0.id) }
            }
        }
        // Türetilen alanlar kaydedilmediği için burada da yeniden hesaplanır.
        for index in latest.materials.indices {
            latest.materials[index].recalculate(from: latest.materialLogs)
        }
    }

    /// Kimliğe göre ekle-veya-değiştir (`DocumentChange` model taşıyan
    /// case'lerin tamamı UPSERT).
    private func upsert<T: Identifiable>(_ value: T, into array: inout [T]) where T.ID: Equatable {
        if let index = array.firstIndex(where: { $0.id == value.id }) {
            array[index] = value
        } else {
            array.append(value)
        }
    }

    // MARK: - Yazma eşlemesi

    private func stage(_ change: DocumentChange, in batch: WriteBatch) throws {
        switch change {
        case .project:
            // 1. aşamada işlendi; buraya düşmemesi gerekiyor.
            return

        case .material(let m):
            batch.setData(try encode(m), forDocument: ref(.materials, m.projectId, m.id))
        case .materialLog(let l):
            batch.setData(try encode(l), forDocument: ref(.materialLogs, l.projectId, l.id))
        case .apartment(let a):
            batch.setData(try encode(a), forDocument: ref(.apartments, a.projectId, a.id))
        case .partner(let p):
            batch.setData(try encode(p), forDocument: ref(.partners, p.projectId, p.id))
        case .document(let d):
            batch.setData(try encode(d), forDocument: ref(.documents, d.projectId, d.id))
        case .expense(let e):
            batch.setData(try encode(e), forDocument: ref(.expenses, e.projectId, e.id))
        case .payment(let p):
            batch.setData(try encode(p), forDocument: ref(.payments, p.projectId, p.id))
        case .audit(let a):
            batch.setData(try encode(a), forDocument: ref(.auditEntries, a.projectId, a.id))

        case .activity(let a):
            // `ActivityItem.projectId` tip olarak optional (gizlilik düzeltmesinde
            // öyle eklendi) ama nil ise geçerli bir yol YOK. Sessizce atmak yerine
            // açık hata: hareket akışı şeffaflık iddiasının dayanağı, kaybolmamalı.
            guard let pid = a.projectId else {
                throw RepositoryError.missingProjectId(record: "ActivityItem \(a.id) · \(a.title)")
            }
            batch.setData(try encode(a), forDocument: ref(.activities, pid, a.id))

        // Görselli iki model `Codable` DEĞİL (`UIImage` taşıyorlar). Belge olarak
        // yalnızca üst veri yazılıyor; görselin kendisi Storage'a gidecek
        // (`storagePath` / `uploadState` — madde 17). Bugün diskten dönen
        // fotoğrafın `image`i nil olur ve ekranda tasarımdaki yer tutucu görünür.
        case .sitePhoto(let p):
            batch.setData(fields(of: p), forDocument: ref(.sitePhotos, p.projectId, p.id))
        case .apartmentPhoto(let p):
            batch.setData(fields(of: p), forDocument: ref(.apartmentPhotos, p.projectId, p.id))

        case .buyer(let b):
            batch.setData(try encode(b), forDocument: ref(.buyers, b.projectId, b.apartmentId))
        case .deleteBuyer(let apartmentId, let pid):
            batch.deleteDocument(ref(.buyers, pid, apartmentId))

        case .deleteMaterialLog(let id, let pid):
            batch.deleteDocument(ref(.materialLogs, pid, id))
        case .deleteExpense(let id, let pid):
            batch.deleteDocument(ref(.expenses, pid, id))
        case .deletePayment(let id, let pid):
            batch.deleteDocument(ref(.payments, pid, id))
        case .deleteApartmentPhoto(let id, let pid):
            batch.deleteDocument(ref(.apartmentPhotos, pid, id))
        case .deletePayments(let ids, let pid):
            for id in ids { batch.deleteDocument(ref(.payments, pid, id)) }
        }
    }

    // MARK: - Yollar

    private func ref(_ coll: Coll, _ pid: UUID, _ id: UUID) -> DocumentReference {
        db.collection("projects").document(pid.uuidString)
            .collection(coll.rawValue).document(id.uuidString)
    }

    private func collection(_ coll: Coll, _ pid: UUID) -> CollectionReference {
        db.collection("projects").document(pid.uuidString).collection(coll.rawValue)
    }

    // MARK: - Kodlama / kod çözme

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        try Firestore.Encoder().encode(value)
    }

    /// Kod çözme hatası SESSİZCE GEÇİLMEZ. Bozuk bir `materialLog`u atlamak,
    /// toplamları sessizce yanlış göstermek demek olurdu — uygulamanın tüm
    /// rakam politikası (bkz. `Kurus`, `verifySeam`) bunun tersini söylüyor.
    /// Şema uyuşmazlığı bir hatadır; yanlış rakam göstermek yerine yüklemeyi
    /// düşürüp kullanıcıya hata göstermek doğrusu.
    private func decode<T: Decodable>(_ type: T.Type,
                                     from doc: QueryDocumentSnapshot,
                                     in collection: String) throws -> T {
        do {
            return try doc.data(as: type)
        } catch {
            throw RepositoryError.decodeFailed(collection: collection,
                                               documentId: doc.documentID,
                                               reason: String(describing: error))
        }
    }

    private func fetch<T: Decodable>(_ type: T.Type, _ coll: Coll, _ pid: UUID) async throws -> [T] {
        let snap = try await collection(coll, pid).getDocuments()
        return try snap.documents.map { try decode(type, from: $0, in: coll.rawValue) }
    }

    /// Belgeler role göre farklı sorgulanır (bkz. `load()`).
    private func fetchDocuments(_ pid: UUID, ownerView: Bool) async throws -> [ProjectDocument] {
        let base = collection(.documents, pid)
        let query: Query = ownerView ? base : base.whereField("partnerVisible", isEqualTo: true)
        let snap = try await query.getDocuments()
        return try snap.documents.map { try decode(ProjectDocument.self, from: $0, in: "documents") }
    }

    // MARK: - Görselli modeller (elle)

    private func fields(of photo: SitePhoto) -> [String: Any] {
        var fields: [String: Any] = ["id": photo.id.uuidString,
                                     "projectId": photo.projectId.uuidString,
                                     "date": Timestamp(date: photo.date)]
        // Yol ancak yükleme bitince yazılır; nil iken alan hiç konmaz ki
        // "yol var ama boş" gibi üçüncü bir durum doğmasın.
        if let path = photo.storagePath { fields["storagePath"] = path }
        return fields
    }

    private func fields(of photo: ApartmentPhoto) -> [String: Any] {
        var fields: [String: Any] = ["id": photo.id.uuidString,
                                     "projectId": photo.projectId.uuidString,
                                     "apartmentId": photo.apartmentId.uuidString,
                                     "label": photo.label]
        if let path = photo.storagePath { fields["storagePath"] = path }
        return fields
    }

    private func fetchSitePhotos(_ pid: UUID) async throws -> [SitePhoto] {
        let snap = try await collection(.sitePhotos, pid).getDocuments()
        return try snap.documents.map { doc in
            guard let id = UUID(uuidString: doc.documentID),
                  let projectId = (doc.data()["projectId"] as? String).flatMap(UUID.init),
                  let date = (doc.data()["date"] as? Timestamp)?.dateValue()
            else {
                throw RepositoryError.decodeFailed(collection: "sitePhotos",
                                                   documentId: doc.documentID,
                                                   reason: "id / projectId / date eksik")
            }
            return SitePhoto(id: id, projectId: projectId, date: date, image: nil,
                             storagePath: doc.data()["storagePath"] as? String)
        }
    }

    private func fetchApartmentPhotos(_ pid: UUID) async throws -> [ApartmentPhoto] {
        let snap = try await collection(.apartmentPhotos, pid).getDocuments()
        return try snap.documents.map { doc in
            guard let id = UUID(uuidString: doc.documentID),
                  let projectId = (doc.data()["projectId"] as? String).flatMap(UUID.init),
                  let apartmentId = (doc.data()["apartmentId"] as? String).flatMap(UUID.init)
            else {
                throw RepositoryError.decodeFailed(collection: "apartmentPhotos",
                                                   documentId: doc.documentID,
                                                   reason: "id / projectId / apartmentId eksik")
            }
            let label = doc.data()["label"] as? String ?? ""
            return ApartmentPhoto(id: id, projectId: projectId, apartmentId: apartmentId,
                                  label: label, image: nil,
                                  storagePath: doc.data()["storagePath"] as? String)
        }
    }
}
