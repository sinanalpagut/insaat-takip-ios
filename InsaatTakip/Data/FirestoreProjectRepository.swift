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
    /// Sunucu isteği REDDETTİ — kural ya da App Check. Ağ sorunu DEĞİL.
    case accessDenied
    /// Sunucuya ULAŞILAMADI — ağ sorunu.
    case offline

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Oturum açık değil"
        case .missingProjectId(let record):
            return "Kayıt bir projeye bağlı değil: \(record)"
        case .decodeFailed(let collection, let documentId, let reason):
            return "Kayıt okunamadı (\(collection)/\(documentId)): \(reason)"
        case .accessDenied:
            // "BAĞLANTIYI DENETLE" DEMİYOR ve sebebi önemli: bu hata ağla
            // ilgili DEĞİL, sunucu isteği reddetti. Kullanıcıyı modeme
            // yöneltmek, çözümü olmayan bir yerde dakikalarca oyalar.
            // App Check zorlaması açıldığı için (madde 71) gerçek hayattaki
            // en olası sebep ESKİ DERLEME; Firebase'in kendi zorlama uyarısı
            // da aynı şeyi söylüyor ("ensure users have an updated version").
            return "Erişim reddedildi · uygulamanın güncel sürümünü kullandığından emin ol"
        case .offline:
            return "Veriler yüklenemedi · bağlantıyı denetle"
        }
    }

    /// Firestore hatasını SINIFLANDIRIR; tanımadığı hatada `nil` döner.
    ///
    /// NEDEN BURADA: `ProjectViewModel` yalnızca SwiftUI import ediyor ve
    /// Firestore'u hiç tanımıyor — depo soyutlamasının tuttuğu yer tam da
    /// burası. Sınıflandırmayı ViewModel'e taşımak, soyutlamayı delmek
    /// olurdu.
    ///
    /// AYRIM "REDDEDİLDİ" İLE "ULAŞILAMADI" ARASINDA. Bugüne kadar İKİSİ DE
    /// "bağlantıyı denetle" diyordu; yani kural reddi de, App Check reddi de
    /// kullanıcıyı modeme yönlendiriyordu. App Check zorlaması açıldıktan
    /// sonra bu, sahada en olası yanlış yönlendirme hâline geldi.
    ///
    /// App Check reddi ile kural reddi BURADA AYRILMIYOR, çünkü ayrılamıyor:
    /// Firestore ikisine de `permissionDenied` döndürüyor ve açıklama metni
    /// aynı (REST üzerinden ölçüldü, 16 Eki 2026). Ortak cümle o yüzden her
    /// iki sebebi de kapsayacak şekilde yazıldı.
    static func classify(_ error: Error) -> RepositoryError? {
        let ns = error as NSError
        guard ns.domain == FirestoreErrorDomain else { return nil }
        switch ns.code {
        case FirestoreErrorCode.permissionDenied.rawValue: return .accessDenied
        case FirestoreErrorCode.unavailable.rawValue:      return .offline
        default:                                           return nil
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
        case installments
        case partnerLedger
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

    /// Yükleme — hataları SINIFLANDIRARAK fırlatır.
    ///
    /// Sarmalayıcı ayrı duruyor ki `fetchAll` içindeki proje düzeyinde
    /// yalıtım (madde 56) olduğu gibi kalsın: oradaki `catch`ler tek bir
    /// projeyi kurtarmak için, buradaki ise TÜM yüklemeyi düşüren hatayı
    /// kullanıcıya doğru cümleyle anlatmak için.
    func load() async throws -> DataSnapshot {
        do {
            return try await fetchAll()
        } catch {
            throw RepositoryError.classify(error) ?? error
        }
    }

    private func fetchAll() async throws -> DataSnapshot {
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

        // PROJE BAŞINA YALITIM (madde 56). Önceden tek bir çözülemeyen belge
        // `load()`u fırlatıyordu: `apply` hiç çalışmıyor, ekranda HİÇBİR proje
        // kalmıyordu. Bir projedeki bozuk kayıt yüzünden diğer dört projeyi
        // kaybetmek orantısız.
        //
        // BOZUK BELGEYİ ATLAMAK ise hâlâ YAPILMIYOR; gerekçesi `decode`in
        // başında yazılı: bir `materialLog`u atlamak toplamları SESSİZCE yanlış
        // gösterir. Yalıtım o yüzden belge düzeyinde değil PROJE düzeyinde —
        // etkilenen proje bütünüyle dışarıda kalıyor (rakamı yarım
        // gösterilmiyor) ve `failedProjects`e yazılıyor ki ekranda söylensin.
        let found = result.projects
        result.projects = []
        for project in found {
            do {
                result.merge(try await loadProject(project, uid: uid))
            } catch {
                result.failedProjects.append(
                    ProjectLoadFailure(id: project.id, title: project.title,
                                       reason: String(describing: error)))
                #if DEBUG
                print("[load] proje yüklenemedi \(project.title): \(error)")
                #endif
            }
        }

        #if DEBUG
        // ALT KOLEKSİYONLAR BİRLEŞTİKTEN SONRA. İlk satır yalnızca proje
        // belgelerini sayıyor; alt koleksiyonlar bu döngüde geliyor. Sayaç
        // yukarıda kalsaydı her zaman sıfır basar ve "veri gelmiyor" gibi
        // okunurdu — bir teşhis turu tam olarak bu yüzden yanlış yola saptı.
        print("[load] alt: daire=\(result.apartments.count) cari=\(result.partnerLedger.count) "
              + "gider=\(result.expenses.count) tahsilat=\(result.payments.count) "
              + "ortak=\(result.partners.count) düşen proje=\(result.failedProjects.count)")
        #endif

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

    /// TEK projenin verisi. Hata fırlatırsa YALNIZCA o proje düşer.
    private func loadProject(_ project: Project, uid: String) async throws -> DataSnapshot {
        var result = DataSnapshot()
        result.projects = [project]
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
        async let installments = fetch(Installment.self, .installments, pid)
        async let ledger = fetch(PartnerLedgerEntry.self, .partnerLedger, pid)
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
        result.installments += try await installments
        result.partnerLedger += try await ledger
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
    /// 1. AŞAMADA ARTIK YALNIZCA `.createProject` VAR (19 Eki düzeltmesi).
    /// İki aşamanın gerekçesi — alt koleksiyon kuralının parti içindeki proje
    /// OLUŞTURMASINI görmemesi — yalnızca kurulumda geçerli. Var olan bir
    /// projeye yazan `.project`, `.projectMembership` ve `.projectInvite`
    /// artık partiye giriyor; bu, `removePartner`ın kendi yorumunun istediği
    /// "üyelik kapısı + ortak kaydı TEK partide" sözünü ilk kez gerçekten
    /// tutuyor ve `addApartment`ın daire sayacı ↔ daire ayrışmasını kapatıyor.
    func apply(_ changes: [DocumentChange]) async throws {
        guard !changes.isEmpty else { return }

        // 1. aşama — proje KURULUMU.
        for change in changes {
            guard case .createProject(let project, let token) = change else { continue }
            var fields = try encode(project)
            fields["establishToken"] = token
            try await db.collection("projects").document(project.id.uuidString)
                .setData(fields)
        }

        // 2. aşama — geri kalan her şey tek parti.
        let rest = changes.filter { if case .createProject = $0 { return false } else { return true } }
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
            // AYNA DA YAZMA YOLUNU TAKLİT ETMEK ZORUNDA: `.project` sunucuda
            // üyeliğe ve davete dokunmadığı için iç kopyada da dokunmamalı.
            // Tam nesneyi basmak, sunucuda korunan ortağı yerel kopyadan
            // düşürür ve `verifySeam` bunu GÖREMEZ (yalnızca kayıt SAYISI
            // karşılaştırıyor, alan değil).
            case .project(let p):
                if let i = latest.projects.firstIndex(where: { $0.id == p.id }) {
                    var birlesik = p
                    birlesik.memberUids = latest.projects[i].memberUids
                    birlesik.invite = latest.projects[i].invite
                    latest.projects[i] = birlesik
                } else {
                    upsert(p, into: &latest.projects)
                }
            case .createProject(let p, _): upsert(p, into: &latest.projects)
            case .projectMembership(let pid, let uid, let op):
                if let i = latest.projects.firstIndex(where: { $0.id == pid }) {
                    switch op {
                    case .add:
                        if !latest.projects[i].memberUids.contains(uid) {
                            latest.projects[i].memberUids.append(uid)
                        }
                    case .remove:
                        latest.projects[i].memberUids.removeAll { $0 == uid }
                    }
                }
            case .projectInvite(let pid, let invite):
                if let i = latest.projects.firstIndex(where: { $0.id == pid }) {
                    latest.projects[i].invite = invite
                }
            case .material(let m):       upsert(m, into: &latest.materials)
            case .materialLog(let l):    upsert(l, into: &latest.materialLogs)
            case .apartment(let a):      upsert(a, into: &latest.apartments)
            case .partner(let p):        upsert(p, into: &latest.partners)
            case .document(let d):       upsert(d, into: &latest.documents)
            case .activity(let a):       upsert(a, into: &latest.activities)
            case .sitePhoto(let p):      upsert(p, into: &latest.sitePhotos)
            case .expense(let e):        upsert(e, into: &latest.expenses)
            case .payment(let p):        upsert(p, into: &latest.payments)
            case .partnerLedger(let l):  upsert(l, into: &latest.partnerLedger)
            case .installment(let i):    upsert(i, into: &latest.installments)
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
            case .deletePartnerLedger(let id, _):
                latest.partnerLedger.removeAll { $0.id == id }
            case .deleteApartmentPhoto(let id, _):
                latest.apartmentPhotos.removeAll { $0.id == id }
            case .deletePartner(let id, _):
                latest.partners.removeAll { $0.id == id }
            case .deleteApartment(let id, _):
                latest.apartments.removeAll { $0.id == id }
            case .deletePayments(let ids, _):
                latest.payments.removeAll { ids.contains($0.id) }
            case .deleteInstallments(let ids, _):
                latest.installments.removeAll { ids.contains($0.id) }
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
        case .createProject:
            // 1. aşamada işlendi; buraya düşmemesi gerekiyor.
            return

        case .project(let p):
            // merge: true ZORUNLU — `projectFields` içinde `FieldValue.delete()`
            // sentinel'leri var ve onlar merge OLMAYAN bir `setData` içinde
            // ObjC istisnası atıyor. Swift'te `try`/`catch` ile YAKALANMAZ:
            // uygulama çöker. Bu yükü başka bir yazmaya taşıma.
            batch.setData(stamped(try Self.projectFields(p, writerUid: writerUid)),
                          forDocument: projectRef(p.id), merge: true)

        case .projectMembership(let pid, let uid, let op):
            let islem = op == .add ? FieldValue.arrayUnion([uid])
                                   : FieldValue.arrayRemove([uid])
            batch.updateData(stamped(["memberUids": islem]), forDocument: projectRef(pid))

        case .projectInvite(let pid, let invite):
            let deger: Any = try invite.map { try Firestore.Encoder().encode($0) as Any }
                             ?? FieldValue.delete()
            batch.updateData(stamped(["invite": deger]), forDocument: projectRef(pid))

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
        case .installment(let i):
            batch.setData(try encode(i), forDocument: ref(.installments, i.projectId, i.id))
        case .partnerLedger(let l):
            batch.setData(try encode(l), forDocument: ref(.partnerLedger, l.projectId, l.id))
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
        // yalnızca üst veri yazılıyor; görselin kendisi Storage'da ve belgede
        // `storagePath` ile işaretli (madde 17). "Yükleniyor" diye bir ALAN YOK:
        // o durum cihaza özgü ve diskte dosya var + belgede yol yok ile ifade
        // ediliyor; belgeye yazılsaydı iki cihaz birbirinin durumunu ezerdi.
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
        case .deletePartnerLedger(let id, let pid):
            batch.deleteDocument(ref(.partnerLedger, pid, id))
        case .deleteInstallments(let ids, let pid):
            for id in ids { batch.deleteDocument(ref(.installments, pid, id)) }
        case .deleteApartmentPhoto(let id, let pid):
            batch.deleteDocument(ref(.apartmentPhotos, pid, id))
        case .deletePartner(let id, let pid):
            batch.deleteDocument(ref(.partners, pid, id))
        case .deleteApartment(let id, let pid):
            batch.deleteDocument(ref(.apartments, pid, id))
        case .deletePayments(let ids, let pid):
            for id in ids { batch.deleteDocument(ref(.payments, pid, id)) }
        }
    }

    // MARK: - Yollar

    private func projectRef(_ pid: UUID) -> DocumentReference {
        db.collection("projects").document(pid.uuidString)
    }

    private var writerUid: String { Auth.auth().currentUser?.uid ?? "" }

    func probeProject(_ id: UUID) async throws -> ProjectProbe {
        do {
            let snap = try await db.collection("projects").document(id.uuidString)
                .getDocument(source: .server)
            guard snap.exists else { return .notReadable }
            // Kayıt var mı — iki ucuz sorgu. Geri yüklemenin kayıt partisi HER
            // ZAMAN kendi denetim kaydını taşıyor, yani parti işlendiyse
            // `auditEntries` boş olamaz; kabuğu elle kullanan biri de çoğunlukla
            // daire ekliyor. Parti atomik: biri varsa hepsi var.
            var kayitVar = false
            for coll in [Coll.auditEntries, Coll.apartments] where !kayitVar {
                let q = try await collection(coll, id).limit(to: 1).getDocuments(source: .server)
                kayitVar = !q.isEmpty
            }
            return .readable(establishToken: snap.get("establishToken") as? String,
                             hasRecords: kayitVar)
        } catch {
            switch RepositoryError.classify(error) {
            case .accessDenied?: return .notReadable
            case .offline?:      throw RepositoryError.offline
            default:             throw error
            }
        }
    }

    // MARK: - Proje belgesinin yazma yükü

    /// Sunucunun sahibi olduğu, istemcinin kendi kopyasından YAZMAYACAĞI alanlar.
    static let serverOwnedProjectFields = ["memberUids", "invite"]

    /// Sıradan düzenlemede kullanıcının TEMİZLEYEBİLDİĞİ opsiyonel alanlar.
    ///
    /// `merge: true` yalnızca YÜKTE OLAN alanları yazıyor; yükte olmayan alan
    /// sunucuda ESKİ DEĞERİYLE KALIYOR. Yani "kullanıcı kalan maliyet
    /// tahminini sildi" niyeti, alanı yükten çıkarmakla anlatılamaz — açık
    /// `FieldValue.delete()` gerekiyor. Yoksa silinen değer bir sonraki
    /// `refresh()`te geri gelir ve bu ekranda anında görünmez.
    ///
    /// ⚠️ BU LİSTEYE `memberUids` YA DA `invite` EKLENMEMELİ. O iki alan
    /// yükten zaten çıkarıldığı için `fields[key] == nil` koşulu ikisi için
    /// DAİMA doğru olur ve her düzenleme üyeliği SİLER — bugünkü sessiz
    /// düşmeden kat kat beter, çünkü sahip de kendi projesini okuyamaz hâle
    /// gelir (kural `uid() in request.resource.data.memberUids` istiyor).
    /// `ProjectMembershipWriteTests` listeyi pinliyor.
    static let erasableProjectFields = ["archivedAt", "remainingCostEstimate",
                                        "expenseTaxBasis", "salesTaxBasis"]

    /// Sıradan proje düzenlemesinin yükü.
    ///
    /// STATİK ve SAF olmasının sebebi test: depo ÖRNEĞİ kurmak Firestore
    /// istemcisini ayağa kaldırmak demek, birim testi üretim veritabanına
    /// bağlamak istemiyoruz. Sözlük buradan doğrudan ölçülebiliyor.
    ///
    /// `writerUid` boş değilse yüke `memberUids: arrayUnion([writerUid])`
    /// ekleniyor — KENDİNİ ONARMA. `memberUids` yükten çıkınca kuralın
    /// `uid() in request.resource.data.memberUids` şartı SUNUCUDAKİ listeye
    /// bakmaya başlıyor; o liste bir sebeple sahibin uid'ini kaybederse
    /// (hatalı bir işlev yazması, elle konsol düzenlemesi) sahibin HER
    /// yazması kalıcı `permission-denied` olurdu. `arrayUnion` yalnızca
    /// EKLİYOR, hiçbir koşulda kimseyi düşürmüyor, ve idempotent.
    static func projectFields(_ project: Project, writerUid: String) throws -> [String: Any] {
        var fields = try Firestore.Encoder().encode(project)
        for key in serverOwnedProjectFields { fields.removeValue(forKey: key) }
        for key in erasableProjectFields where fields[key] == nil {
            fields[key] = FieldValue.delete()
        }
        if !writerUid.isEmpty {
            fields["memberUids"] = FieldValue.arrayUnion([writerUid])
        }
        return fields
    }

    private func ref(_ coll: Coll, _ pid: UUID, _ id: UUID) -> DocumentReference {
        db.collection("projects").document(pid.uuidString)
            .collection(coll.rawValue).document(id.uuidString)
    }

    private func collection(_ coll: Coll, _ pid: UUID) -> CollectionReference {
        db.collection("projects").document(pid.uuidString).collection(coll.rawValue)
    }

    // MARK: - Kodlama / kod çözme

    /// Her yazılan belgeye SUNUCU zaman damgası ve yazan kişi/oturum eklenir.
    ///
    /// NEDEN (madde 55): yazma yolu tam belge `setData` — son yazan kazanır,
    /// merge yok, önkoşul yok. Aynı kişinin iki cihazı aynı kaydı düzenlerse
    /// biri diğerini SESSİZCE eziyor. En gerçekçi hali kuyruk: şantiyede
    /// çevrimdışı kalan telefon saatlerce yazma biriktiriyor, bağlanınca
    /// iPad'de yapılmış daha yeni değişikliğin üstüne yazıyor.
    ///
    /// BU ALANLAR KAYBI ÖNLEMİYOR, GÖRÜNÜR KILIYOR. Önleme (transaction +
    /// sürüm önkoşulu) toplu yazmanın atomikliğini bozar ve tek maddeden büyük
    /// bir iştir — satış + taksitler + denetim kaydı bugün TEK partide gidiyor
    /// ve bu güvence korunmalı. Bugün eksik olan şey teşhis: bir belgeye en son
    /// NE ZAMAN ve HANGİ OTURUMDAN yazıldığı hiçbir yerde yazılı değil,
    /// dolayısıyla "değişikliğim nereye gitti" sorusu cevaplanamıyor.
    ///
    /// `serverTimestamp` bilinçli: cihaz saatine güvenilmiyor (bkz. madde 77 —
    /// denetim izinin zaman damgası da bugün istemciden geliyor).
    /// `writerSession` uygulama açılışına özgü: aynı uid iki cihazda da aynı
    /// olduğu için tek başına uid, "hangi cihaz" sorusunu ayırt etmiyor.
    private static let writerSession = UUID().uuidString

    private func stamped(_ fields: [String: Any]) -> [String: Any] {
        var out = fields
        out["updatedAt"] = FieldValue.serverTimestamp()
        out["updatedBy"] = Auth.auth().currentUser?.uid ?? ""
        out["updatedFrom"] = Self.writerSession
        return out
    }

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        stamped(try Firestore.Encoder().encode(value))
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

    /// Hareket akışının sunucu tarafı sınırı.
    ///
    /// NEDEN YALNIZCA `activities`: bu koleksiyon hiçbir PARA TOPLAMINI
    /// beslemiyor ve JSON yedeğine de girmiyor — salt bir akış ekranı. Diğer
    /// koleksiyonlar (malzemeHareketleri, giderler, tahsilatlar, taksitler,
    /// daireler) toplamların HAM KAYNAĞI: projenin "türetilen rakam saklanmaz,
    /// ham kayıtlardan hesaplanır" ilkesi gereği hepsi okunuyor. Onlara limit
    /// koymak rakamları SESSİZCE yanlış yapardı — bu uygulamanın reddettiği
    /// hatanın en ağır biçimi. `auditEntries` de sınırlanamaz: yedeğe
    /// `denetimIzi` olarak giriyor ve eksik bir yedek, kullanıcının veri
    /// kaybını fark etmeyeceği bir yalan olur.
    ///
    /// Toplamları besleyen koleksiyonların sınırlanabilmesi için ya sunucu
    /// tarafı toplama (Firestore aggregation) ya da saklanan toplam gerekiyor;
    /// ikincisi ilkeye aykırı, ilki ayrı bir iş (bkz. ANALIZ madde 58 notu).
    private static let activityLimit = 200

    private func fetch<T: Decodable>(_ type: T.Type, _ coll: Coll, _ pid: UUID) async throws -> [T] {
        var query: Query = collection(coll, pid)
        if coll == .activities {
            query = query.order(by: "timestamp", descending: true)
                         .limit(to: Self.activityLimit)
        }
        let snap = try await query.getDocuments()
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
        return stamped(fields)
    }

    private func fields(of photo: ApartmentPhoto) -> [String: Any] {
        var fields: [String: Any] = ["id": photo.id.uuidString,
                                     "projectId": photo.projectId.uuidString,
                                     "apartmentId": photo.apartmentId.uuidString,
                                     "label": photo.label]
        if let path = photo.storagePath { fields["storagePath"] = path }
        return stamped(fields)
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
