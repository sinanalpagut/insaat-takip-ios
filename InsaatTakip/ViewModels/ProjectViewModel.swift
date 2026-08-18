import SwiftUI

// MARK: - ProjectViewModel
// Uygulamanın tüm iş mantığı ve verisi burada toplanır (MVVM).
// Henüz bir veritabanı bağlı değil; tasarım dosyasındaki senaryoyu birebir
// yansıtan gerçekçi mock verilerle çalışır:
//   · 145 Ada / 2 Parsel (Çayırova) — 20 daire, 12 satış, 9 kalem malzeme
//   · 1287 Ada / 14 Parsel (Nilüfer) — temel aşamasında
//   · 908 Ada / 7 Parsel (Kepez) — teslim aşamasında, tamamı satılmış
// View'lar "dumb" kalır; filtreleme, toplama ve yetki kuralları buradadır.

// Tüm durum güncellemeleri ana aktörde yapılır; @Published alanların arka
// plandan yazılması (SwiftUI'da kararsız davranış) derleyici tarafından engellenir.
@MainActor
final class ProjectViewModel: ObservableObject {

    // MARK: Yayınlanan durum

    @Published var projects: [Project] = []
    @Published var materials: [Material] = []          // Tüm projelerin malzemeleri
    @Published var materialLogs: [MaterialLog] = []    // Giriş / çıkış kayıtları
    @Published var apartments: [Apartment] = []        // Tüm projelerin daireleri
    @Published var partners: [Partner] = []            // Ortaklar (hisse dağılımı)
    @Published var documents: [ProjectDocument] = []   // Plan & proje dosyaları
    @Published var activities: [ActivityItem] = []     // Hareket / bildirim akışı
    @Published var sitePhotos: [SitePhoto] = []        // Şantiye fotoğraf yuvaları
    @Published var expenses: [Expense] = []            // Malzeme dışı giderler
    @Published var payments: [Payment] = []            // Daire tahsilatları
    @Published var apartmentPhotos: [ApartmentPhoto] = []   // Daire görselleri
    /// Düzenleme ve silmelerin değişiklik kaydı (eski → yeni, kim, ne zaman).
    @Published var auditEntries: [AuditEntry] = []
    /// Fiş fotoğrafları — hareket kimliğine göre (kamerayla çekilen irsaliye).
    @Published var receiptImages: [UUID: UIImage] = [:]

    /// Ekran altında beliren onay bildirimi.
    @Published var toast: String?

    /// Bildirim zilindeki okunmamış işareti.
    @Published var hasUnreadActivity = true

    private var toastTask: Task<Void, Never>?

    /// Kalıcılık sınırı. Bugün bellek içi, Faz 2'de Firestore.
    /// Değişimin bu sınırın gerisinde kalması, o gün 22 view dosyasına
    /// dokunmak zorunda kalmamamızın tek sebebi.
    private let repository: ProjectRepository

    /// Varsayılan `nil`: `InMemoryProjectRepository()` ana aktörde olduğu için
    /// varsayılan argüman ifadesi olarak yazılamıyor (çağrı yerinde, izole
    /// olmayan bağlamda değerlendirilirdi). Gövdede kurmak aynı sonucu verir.
    /// Davet akışı. `nil` = demo verisi (yerel mantık yeterli, sunucu yok).
    /// Firestore devredeyse dolu: davet kullanma bir Cloud Function çağrısı.
    private let invites: InviteService?

    /// Görsel deposu (disk + Storage). `nil` = demo: görseller RAM'de yaşar,
    /// mevcut davranış aynen korunur. Firestore devredeyken pikseller diske
    /// ANINDA, buluta arkadan gider (madde 17).
    private let images: ImageStore?

    /// Uçuştaki bulut aktarımları (yükleme + indirme). Bellek içi ve SÜRECE
    /// ÖZGÜ: uçuştaki bir aktarım süreçten uzun yaşayamaz, yani uygulama
    /// ölünce bu küme de ölmeli ve `hydrateImages` yeniden denemeli. Kalıcı
    /// bir defter tutulsaydı defterle gerçek arasındaki ayrışma yeni bir hata
    /// sınıfı olurdu.
    private var transfersInFlight: Set<String> = []

    /// İşlemi YAPAN kişi — kayıtlardaki "kim" alanı buradan gelir.
    ///
    /// Önceden her kayda sabit `User.admin.name` yazılıyordu, yani gerçek bir
    /// projede fişi kim girerse girsin denetim izinde hep aynı demo adı
    /// görünüyordu. Uygulamanın şeffaflık iddiası "kim, ne zaman" cevabına
    /// dayanıyor; o cevap yanlışsa iz bir kanıt değil süstür.
    ///
    /// `RootView` oturum değiştikçe burayı günceller.
    var actingUser: User?

    /// Kayıtlara yazılacak ad. Sahte veri/demo yolunda oturum yoksa eski
    /// davranış korunur.
    private var actorName: String { actingUser?.name ?? User.admin.name }

    init(repository: ProjectRepository? = nil, invites: InviteService? = nil,
         images: ImageStore? = nil) {
        let source = repository ?? Self.makeRepository()
        self.repository = source
        self.invites = invites ?? (LaunchConfig.usesFirestore ? FirebaseInviteService() : nil)
        self.images = images ?? (LaunchConfig.usesFirestore ? ImageStore() : nil)
        // Açılışta BEKLEME YOK: önbellek senkron okunur. `load()` async olsaydı
        // ekran bir kare boş görünür, yani kullanıcı bir fark görürdü.
        apply(source.cachedSnapshot())
    }

    /// Kalıcılık kaynağını seçer. Varsayılan hâlâ demo verisi; gerçek Firestore
    /// `-backend firestore` ile açılıyor (bkz. LaunchConfig). Yayın derlemesinde
    /// koşul yok, Firestore devrede.
    private static func makeRepository() -> ProjectRepository {
        LaunchConfig.usesFirestore ? FirestoreProjectRepository() : InMemoryProjectRepository()
    }

    /// Yetkili kaynaktan tam yükleme. `RootView` bunu bir `.task` içinde çağırır.
    ///
    /// Bellek içi kaynakta bu bir no-op sayılır (önbellek zaten güncel veriyi
    /// veriyor); Firestore'da ilk açılışta önbellek BOŞ olduğu için ekranı asıl
    /// dolduran çağrı budur. Hata sessiz geçilmez: kullanıcı boş bir dashboard'a
    /// bakıp verisini kaybettiğini sanmasın.
    func refresh() async {
        do {
            apply(try await repository.load())
        } catch {
            #if DEBUG
            // Ham hata görünmezse "yüklenemedi" mesajının NEDENİ hiçbir yerde
            // okunamaz. Kural reddi mi, indeks mi, ağ mı — ayırt etmek şart.
            print("[refresh] yükleme başarısız: \(error)")
            #endif
            flash(Self.loadFailureMessage(for: error))
        }
    }

    private static func loadFailureMessage(for error: Error) -> String {
        if let repositoryError = error as? RepositoryError {
            return repositoryError.errorDescription ?? "Veriler yüklenemedi"
        }
        // Firestore'un İngilizce hata dizeleri arayüze SIZMAMALI.
        return "Veriler yüklenemedi · bağlantıyı denetle"
    }

    // MARK: - Kalıcılık köprüsü

    /// Kaynaktan gelen görüntüyü ekrana bağlar ve türetilen alanları yeniden hesaplar.
    /// Türetme burada yapılır ki kaynağın (mock, Firestore, ileride bir yedek dosya)
    /// tutarlı veri gönderdiğine güvenmek zorunda kalmayalım.
    private func apply(_ snapshot: DataSnapshot) {
        projects = snapshot.projects
        materials = snapshot.materials
        materialLogs = snapshot.materialLogs
        apartments = snapshot.apartments
        partners = snapshot.partners
        documents = snapshot.documents
        activities = snapshot.activities
        sitePhotos = snapshot.sitePhotos
        expenses = snapshot.expenses
        payments = snapshot.payments
        apartmentPhotos = snapshot.apartmentPhotos
        auditEntries = snapshot.auditEntries

        for index in materials.indices {
            materials[index].recalculate(from: materialLogs)
        }
        for apartment in apartments where apartment.isCommitted {
            recalculateCollected(for: apartment.id)
        }

        // Diskteki/buluttaki görselleri modele geri bağla. `load()` yalnızca
        // üst veri döndürür (görsel baytları Firestore'da değil); bu çağrı
        // olmasa oturum ortasındaki bir `refresh()` kullanıcının az önce
        // eklediği fotoğrafları bile yer tutucuya çevirirdi.
        hydrateImages()
    }

    // MARK: - Görsel canlandırma ve yükleme (madde 17)

    /// İki adım: (1) DİSKTE olan anında bağlanır, (2) diskte olup bulutta
    /// olmayan yeniden yüklenir — yarım kalmış yüklemelerin telafisi budur.
    ///
    /// BULUTTAN İNDİRME BURADA YOK, bilinçli: `sitePhotos`/`apartmentPhotos`
    /// TÜM projelerin görsellerini taşıyor ve `apply()` her açılışta çalışıyor.
    /// İndirme buraya konulduğunda, 300 fotoğraflı bir projeye katılan ortak
    /// daha Dashboard'da dururken 300 eşzamanlı indirme başlıyordu: ~120 MB
    /// hücresel trafik, 300 Storage okuması ve kuralın çapraz-servis
    /// `firestore.get()`i yüzünden 300 EK Firestore okuması — kullanıcı fotoğraf
    /// ekranını hiç açmasa bile. Piksel artık ekranda GÖRÜNEN hücre için
    /// isteniyor: `imageNeeded(...)`.
    private func hydrateImages() {
        guard let images else { return }

        for index in sitePhotos.indices where sitePhotos[index].image == nil {
            let photo = sitePhotos[index]
            if let cached = images.cached(bucket: .sitePhotos,
                                          projectId: photo.projectId, id: photo.id) {
                sitePhotos[index].image = cached
            }
        }
        for index in apartmentPhotos.indices where apartmentPhotos[index].image == nil {
            let photo = apartmentPhotos[index]
            if let cached = images.cached(bucket: .apartmentPhotos,
                                          projectId: photo.projectId, id: photo.id) {
                apartmentPhotos[index].image = cached
            }
        }

        // (2) Yarım kalmış yüklemeler: belge var, yol yok, piksel elde var.
        for photo in sitePhotos where photo.storagePath == nil && photo.image != nil {
            uploadImage(bucket: .sitePhotos, projectId: photo.projectId, id: photo.id)
        }
        for photo in apartmentPhotos where photo.storagePath == nil && photo.image != nil {
            uploadImage(bucket: .apartmentPhotos, projectId: photo.projectId, id: photo.id)
        }

        hydrateReceipts(images)
    }

    /// Fişlerin yarım kalmış yüklemeleri.
    ///
    /// Ölçüt fotoğraflardan FARKLI olmak zorunda: fiş pikseli `receiptImages`
    /// sözlüğünde yaşıyor ve o sözlük yeniden açılışta BOŞ, yani "elde görsel
    /// var" hiçbir zaman doğru olmaz. Ölçüt "diskte dosya var + belgede yol
    /// yok". Dizin taraması pikselleri okumadan yalnızca dosya adlarına bakıyor;
    /// `upload` da zaten diskten okuduğu için görseli belleğe almaya gerek yok.
    private func hydrateReceipts(_ images: ImageStore) {
        var pendingShared = Set(materialLogs.filter { $0.receiptPath == nil }.map(\.id))
        pendingShared.formUnion(expenses.filter { $0.receiptPath == nil }.map(\.id))
        for entry in images.localEntries(bucket: .receipts)
        where pendingShared.contains(entry.id) {
            uploadImage(bucket: .receipts, projectId: entry.projectId, id: entry.id)
        }

        let pendingPayments = Set(payments.filter { $0.receiptPath == nil }.map(\.id))
        for entry in images.localEntries(bucket: .paymentReceipts)
        where pendingPayments.contains(entry.id) {
            uploadImage(bucket: .paymentReceipts, projectId: entry.projectId, id: entry.id)
        }
    }

    /// Ekranda çizilen bir fotoğraf hücresi pikselini burada ister. Diskte
    /// varsa `hydrateImages` zaten bağlamıştır; yoksa ve belgede yol varsa
    /// buluttan indirilir. Görünmeyen fotoğraf indirilmez — fatura da trafik
    /// de kullanıcının gerçekten baktığı kadardır.
    func imageNeeded(bucket: ImageBucket, photoId: UUID) {
        switch bucket {
        case .sitePhotos:
            guard let photo = sitePhotos.first(where: { $0.id == photoId }),
                  photo.image == nil, let path = photo.storagePath else { return }
            downloadImage(bucket: .sitePhotos, projectId: photo.projectId,
                          id: photo.id, path: path)
        case .apartmentPhotos:
            guard let photo = apartmentPhotos.first(where: { $0.id == photoId }),
                  photo.image == nil, let path = photo.storagePath else { return }
            downloadImage(bucket: .apartmentPhotos, projectId: photo.projectId,
                          id: photo.id, path: path)
        case .receipts, .paymentReceipts:
            guard let target = receiptTarget(bucket: bucket, id: photoId),
                  receiptImages[photoId] == nil else { return }
            // Önce disk: aynı cihazda çekilen fiş zaten burada, ağa çıkmaya gerek yok.
            if let cached = images?.cached(bucket: bucket, projectId: target.projectId,
                                           id: photoId) {
                receiptImages[photoId] = cached
                return
            }
            guard let path = target.path else { return }
            downloadImage(bucket: bucket, projectId: target.projectId, id: photoId, path: path)
        }
    }

    // MARK: Fiş görselleri (madde 17'nin 3. parçası)

    /// Düzenlemede fiş görseline ne yapılacağı.
    ///
    /// `UIImage?` YETMİYOR: nil hem "kullanıcı dokunmadı" hem "kullanıcı
    /// kaldırdı" demek olurdu ve kod ikincisini birincisi sanıyordu — formdaki
    /// X düğmesine basılıp kaydedilen fiş sessizce geri geliyordu. Buluta
    /// taşındıktan sonra aynı kusur, kullanıcının sildiği görselin hem Storage'da
    /// hem `receiptPath` alanında yaşamaya devam etmesi demekti.
    enum ReceiptEdit {
        case unchanged
        case replaced(UIImage)
        case cleared

        var isCleared: Bool { if case .cleared = self { return true } else { return false } }
    }

    /// Bir fiş kimliğinin hangi kovaya, hangi projeye ve hangi yola ait olduğunu
    /// çözer. TEK YERDE: yanlış kova seçmek yetki sızıntısı demek — tahsilat
    /// dekontu `paymentReceipts`te yalnızca yöneticiye açık, malzeme/gider fişi
    /// `receipts`te ortağa da açık. Bu çözüm her çağrı yerinde tekrar yazılsaydı
    /// biri unutulduğunda dekont ortağın okuyabildiği kovaya düşerdi.
    ///
    /// `.receipts` İKİ koleksiyona birden hizmet ediyor (malzeme fişi + gider
    /// fişi); ikisi de aynı kovada çünkü ortak ikisini de görebilmeli.
    private func receiptTarget(bucket: ImageBucket,
                               id: UUID) -> (projectId: UUID, path: String?)? {
        switch bucket {
        case .paymentReceipts:
            guard let p = payments.first(where: { $0.id == id }) else { return nil }
            return (p.projectId, p.receiptPath)
        case .receipts:
            if let l = materialLogs.first(where: { $0.id == id }) {
                return (l.projectId, l.receiptPath)
            }
            if let e = expenses.first(where: { $0.id == id }) {
                return (e.projectId, e.receiptPath)
            }
            return nil
        case .sitePhotos, .apartmentPhotos:
            return nil
        }
    }

    /// Fiş görselini diske yazar ve yüklemeyi başlatır. Üç ekleme yolunun
    /// (malzeme fişi, tahsilat dekontu, gider fişi) ortak sonu.
    private func storeReceipt(_ image: UIImage, bucket: ImageBucket,
                              projectId: UUID, id: UUID) {
        receiptImages[id] = image
        images?.cache(image, bucket: bucket, projectId: projectId, id: id)
        uploadImage(bucket: bucket, projectId: projectId, id: id)
    }

    /// Fiş görselini diskten, buluttan ve bellekten siler.
    ///
    /// KOŞULSUZ: "elde görsel var mı" diye BAKILMAZ. `receiptImages` yeniden
    /// açılışta boş olduğu için koşullansaydı, uygulamayı kapatıp açtıktan
    /// sonraki her silme nesneyi bulutta bırakırdı. `ImageStore.delete` yolu
    /// belirlenimci hesapladığı için yol belgede yazılı olmasa da çalışır.
    private func discardReceipt(bucket: ImageBucket, projectId: UUID,
                                id: UUID, path: String?) {
        receiptImages[id] = nil
        Task { [images] in
            await images?.delete(bucket: bucket, projectId: projectId,
                                 id: id, storagePath: path)
        }
    }

    /// Storage'dan indirip modele bağlar. Kayıp ağda sessiz kalır: görsel yer
    /// tutucuda kalır ve bir sonraki `refresh()` yeniden dener — üst veri
    /// (tarih/etiket) zaten ekranda, kaybolan yalnızca piksel.
    private func downloadImage(bucket: ImageBucket, projectId: UUID, id: UUID, path: String) {
        guard let images else { return }
        // Aynı nesne zaten iniyorsa ikinci kez İSTEME. Liste yeniden çizildikçe
        // `imageNeeded` her hücre için tekrar çağrılıyor; bu kayıt olmasa aynı
        // JPEG kaydırma başına birkaç kez inerdi.
        let key = transferKey(bucket, projectId, id)
        guard transfersInFlight.insert(key).inserted else { return }
        Task { [weak self] in
            guard let self else { return }
            defer { self.transfersInFlight.remove(key) }
            guard let image = try? await images.download(path: path, bucket: bucket,
                                                         projectId: projectId, id: id)
            else { return }
            switch bucket {
            case .sitePhotos:
                if let i = self.sitePhotos.firstIndex(where: { $0.id == id }) {
                    self.sitePhotos[i].image = image
                }
            case .apartmentPhotos:
                if let i = self.apartmentPhotos.firstIndex(where: { $0.id == id }) {
                    self.apartmentPhotos[i].image = image
                }
            case .receipts, .paymentReceipts:
                self.receiptImages[id] = image
            }
        }
    }

    /// Diskteki görseli Storage'a yükler; başarıda belgeye `storagePath` yazar.
    /// `pendingWrites` sayacına BAĞLI: yükleme de bir "gönderilecek kayıt" —
    /// sayaca girmese, şeridin kapattığı sessiz kayıp sınıfı Storage'da
    /// yeniden doğardı.
    private func uploadImage(bucket: ImageBucket, projectId: UUID, id: UUID) {
        guard let images else { return }
        // Aynı görsel zaten gidiyorsa ikinci kez GÖNDERME. `hydrateImages`
        // yolu henüz yazılmamış her fotoğrafı aday sayıyor; araya giren bir
        // `refresh()` (örneğin davet kodu kabulü) uçuştaki yüklemeleri baştan
        // başlatıyordu: aynı baytlar iki kez, bekleyen-yazma şeridi de gerçeğin
        // iki katı. Kayıt SÜRECE ÖZGÜ — uygulama ölünce uçuştaki yükleme de
        // ölür ve bir sonraki açılış yeniden denemeli.
        let key = transferKey(bucket, projectId, id)
        guard transfersInFlight.insert(key).inserted else { return }
        beginPendingWrite()
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.transfersInFlight.remove(key)
                self.endPendingWrite()
            }
            do {
                // Diskte dosya yoksa (depolama dolu) bellekteki kare yedek
                // olarak gider — yoksa piksel hiçbir yere ulaşmadan kaybolurdu.
                let path = try await images.upload(bucket: bucket, projectId: projectId,
                                                   id: id, fallback: self.pixels(bucket, id))
                switch bucket {
                case .sitePhotos:
                    if let i = self.sitePhotos.firstIndex(where: { $0.id == id }) {
                        self.sitePhotos[i].storagePath = path
                        self.persist([.sitePhoto(self.sitePhotos[i])], failureNote: "Fotoğraf yolu")
                    } else {
                        await self.discardOrphan(bucket, projectId, id, path)
                    }
                case .apartmentPhotos:
                    if let i = self.apartmentPhotos.firstIndex(where: { $0.id == id }) {
                        self.apartmentPhotos[i].storagePath = path
                        self.persist([.apartmentPhoto(self.apartmentPhotos[i])], failureNote: "Görsel yolu")
                    } else {
                        await self.discardOrphan(bucket, projectId, id, path)
                    }
                case .receipts:
                    if let i = self.materialLogs.firstIndex(where: { $0.id == id }) {
                        self.materialLogs[i].receiptPath = path
                        self.persist([.materialLog(self.materialLogs[i])], failureNote: "Fiş yolu")
                    } else if let i = self.expenses.firstIndex(where: { $0.id == id }) {
                        self.expenses[i].receiptPath = path
                        self.persist([.expense(self.expenses[i])], failureNote: "Fiş yolu")
                    } else {
                        // İKİ diziye de bakmak ŞART: `.receipts` hem malzeme
                        // fişine hem gider fişine hizmet ediyor. Biri unutulsa,
                        // silinen kaydın nesnesi projenin HER üyesinin
                        // okuyabildiği bir yetim olarak kalırdı.
                        await self.discardOrphan(bucket, projectId, id, path)
                    }
                case .paymentReceipts:
                    if let i = self.payments.firstIndex(where: { $0.id == id }) {
                        self.payments[i].receiptPath = path
                        self.persist([.payment(self.payments[i])], failureNote: "Dekont yolu")
                    } else {
                        await self.discardOrphan(bucket, projectId, id, path)
                    }
                }
            } catch {
                #if DEBUG
                print("[image] yükleme başarısız \(bucket.rawValue)/\(id): \(error)")
                #endif
                // Yeniden deneme yalnızca piksel elde kaldıysa mümkün: diskte
                // dosya ya da bellekte kare. İkisi de yoksa söz verilemez.
                if self.pixels(bucket, id) != nil {
                    self.flash("Görsel gönderilemedi · sonra yeniden denenecek")
                } else {
                    self.flash("Görsel gönderilemedi · yeniden ekleyin")
                }
            }
        }
    }

    /// Modeldeki piksel — disk yazılamadığında yüklemeye yedek, hata mesajını
    /// dürüst kurmak için de ölçüt.
    private func pixels(_ bucket: ImageBucket, _ id: UUID) -> UIImage? {
        switch bucket {
        case .sitePhotos:      return sitePhotos.first { $0.id == id }?.image
        case .apartmentPhotos: return apartmentPhotos.first { $0.id == id }?.image
        case .receipts, .paymentReceipts: return receiptImages[id]
        }
    }

    /// Yükleme uçuştayken kayıt silinmiş: az önce yazılan nesneyi geri al.
    /// Yoksa hiçbir kodun bir daha silmeyeceği, projenin HER üyesinin
    /// okuyabildiği bir yetim nesne bulutta kalırdı — üstelik kullanıcıya
    /// "silindi" denmişken.
    private func discardOrphan(_ bucket: ImageBucket, _ projectId: UUID,
                               _ id: UUID, _ path: String) async {
        await images?.delete(bucket: bucket, projectId: projectId, id: id, storagePath: path)
    }

    /// Uçuştaki aktarımların anahtarı — ImageStore'un disk dosya adıyla aynı
    /// şema, yeni bir kimlik düzeni doğmasın diye.
    private func transferKey(_ bucket: ImageBucket, _ projectId: UUID, _ id: UUID) -> String {
        "\(bucket.rawValue)_\(projectId.uuidString)_\(id.uuidString)"
    }

    // MARK: Bekleyen yazma görünürlüğü

    /// Sunucu onayı bekleyen yazma sayısı.
    ///
    /// NEDEN GEREKLİ: Firestore çevrimdışıyken yazmayı KUYRUĞA alıyor ve
    /// `commit()` yalnızca sunucu onayı gelince dönüyor. Yani `persist`in
    /// `catch` bloğu çalışmıyor, kullanıcı "kaydedildi" görüyor ve veri
    /// sunucuda olmuyor. Şantiyede internetin gidip geldiği bir uygulamada bu
    /// sessiz veri kaybı demek — uygulamanın tüm rakam politikasının (bkz.
    /// `Kurus`, `verifySeam`) tersi.
    ///
    /// Yazma İPTAL EDİLMİYOR: kuyruk bir kusur değil, Firestore'un çevrimdışı
    /// özelliği; bağlantı gelince kayıt düşüyor. Yapılması gereken onu
    /// GÖRÜNÜR kılmak.
    @Published private(set) var pendingWrites = 0

    /// Bekleme kullanıcıya gösterilecek kadar uzadı mı.
    ///
    /// Her kayıtta uyarı çıkarmıyoruz: normal bir yazma milisaniyeler sürüyor
    /// ve o durumda çıkan bir şerit, gerçekten takıldığında fark edilmeyecek
    /// bir gürültüye dönüşürdü.
    @Published private(set) var showsPendingWrites = false

    private var pendingBannerTask: Task<Void, Never>?
    /// Bu süreden uzun süren yazma "takıldı" sayılır.
    private static let pendingBannerDelay: UInt64 = 2_000_000_000

    private func beginPendingWrite() {
        pendingWrites += 1
        guard pendingBannerTask == nil else { return }
        pendingBannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.pendingBannerDelay)
            guard let self, !Task.isCancelled, self.pendingWrites > 0 else { return }
            withAnimation(.easeInOut(duration: 0.2)) { self.showsPendingWrites = true }
        }
    }

    private func endPendingWrite() {
        pendingWrites = max(0, pendingWrites - 1)
        guard pendingWrites == 0 else { return }
        pendingBannerTask?.cancel()
        pendingBannerTask = nil
        withAnimation(.easeInOut(duration: 0.2)) { showsPendingWrites = false }
    }

    /// Bekleyen yazma şeridinin metni.
    var pendingWritesMessage: String {
        "Bağlantı bekleniyor · \(pendingWrites) kayıt gönderilecek"
    }

    /// Bir kullanıcı eyleminin ürettiği yazmaları kaynağa iletir.
    ///
    /// Yerel durum ZATEN güncellendi (iyimser güncelleme) — Firestore'un kendi
    /// davranışı da budur: yazma önce yerel önbelleğe uygulanır, arayüz anında
    /// tepki verir, sunucu senkronu arkada yürür. Bu sayede ViewModel'in genel
    /// arayüzü senkron kalabiliyor ve view'lar `async` bilmek zorunda değil.
    /// Hata olursa kullanıcıya mevcut toast mekanizmasıyla söylenir.
    private func persist(_ changes: [DocumentChange], failureNote: String) {
        guard !changes.isEmpty else { return }
        // Sayaç Task'TEN ÖNCE artıyor: Task'in içinde artsaydı, yazma
        // başladıktan sonraki ilk karede sayı hâlâ sıfır görünürdü.
        beginPendingWrite()
        Task { [weak self] in
            guard let self else { return }
            defer { self.endPendingWrite() }
            do {
                try await self.repository.apply(changes)
                #if DEBUG
                self.verifySeam(after: failureNote)
                #endif
            } catch {
                #if DEBUG
                // Kullanıcıya kısa Türkçe mesaj gidiyor; ham hata görünmezse
                // "kaydedilemedi" toast'ının NEDENİ hiçbir yerde okunamaz —
                // oysa bu, yorumun "en sinsi hata sınıfı" dediği şeyin tam
                // kendisi. Yalnızca DEBUG.
                print("[persist] \(failureNote) başarısız: \(error)")
                #endif
                self.flash("\(failureNote) kaydedilemedi")
            }
        }
    }

    #if DEBUG
    /// Dikişin gerçekten çalıştığını denetler: yazmadan sonra kaynağın kopyası
    /// ekranın gördüğüyle aynı sayıda kayıt taşımalı.
    ///
    /// Bu kontrol olmasa, bir mutasyonda `persist` çağırmayı unutmak HİÇBİR
    /// belirti vermezdi — ekran doğru görünür, veri sessizce kaybolurdu. Faz 2'de
    /// bunun karşılığı "kullanıcı kaydetti sanıyor, sunucuya hiç gitmedi" olurdu,
    /// yani en sinsi hata sınıfı. Burada geliştirme sırasında patlar.
    private func verifySeam(after note: String) {
        let mirror = repository.cachedSnapshot()
        let pairs: [(String, Int, Int)] = [
            ("proje", projects.count, mirror.projects.count),
            ("malzeme", materials.count, mirror.materials.count),
            ("fiş", materialLogs.count, mirror.materialLogs.count),
            ("daire", apartments.count, mirror.apartments.count),
            ("ortak", partners.count, mirror.partners.count),
            ("belge", documents.count, mirror.documents.count),
            ("hareket", activities.count, mirror.activities.count),
            ("şantiye fotoğrafı", sitePhotos.count, mirror.sitePhotos.count),
            ("gider", expenses.count, mirror.expenses.count),
            ("tahsilat", payments.count, mirror.payments.count),
            ("daire görseli", apartmentPhotos.count, mirror.apartmentPhotos.count),
            ("denetim kaydı", auditEntries.count, mirror.auditEntries.count),
        ]
        for (name, local, stored) in pairs where local != stored {
            assertionFailure("Dikiş kopuk · \(note): \(name) ekranda \(local), kaynakta \(stored)")
        }
    }
    #endif

    // MARK: - Üyelik (kim hangi projeyi görür)

    /// Kullanıcının erişebildiği projeler.
    /// · Yönetici → kurduğu projeler (ownerId)
    /// · Ortak    → yalnızca davetle katıldığı projeler (Partner.userId)
    /// Önceden dashboard TÜM projeleri listeliyordu; bir projeye davet edilen
    /// ortak, diğer projelerin alıcı adlarını ve cirosunu da görüyordu.
    /// Kullanıcının BU PROJEDEKİ rolü. Global rol değil (bkz. Project.role(for:)).
    ///
    /// View'lar yetki sorusunu buradan soruyor; `appState.currentUser?.role`
    /// geçmek davet edilen ortağa yönetici arayüzü göstermek demekti.
    /// Proje bulunamazsa en kısıtlı rol: bilinmeyen bir projede yazma yetkisi
    /// varsaymak, yanlış tarafta hata yapmak olurdu.
    func role(inProject projectId: UUID, for user: User?) -> UserRole {
        projects.first { $0.id == projectId }?.role(for: user) ?? .partner
    }

    /// Daire üzerinden aynı soru (sheet'lerin bir kısmı projeyi değil daireyi taşıyor).
    func role(forApartment apartmentId: UUID, user: User?) -> UserRole {
        guard let projectId = apartments.first(where: { $0.id == apartmentId })?.projectId
        else { return .partner }
        return role(inProject: projectId, for: user)
    }

    func visibleProjects(for user: User?) -> [Project] {
        guard let user else { return [] }
        // Üyelik `memberUids` üzerinden okunur; Partner kaydı üzerinden DEĞİL.
        // Firestore'da "üyesi olduğum projeler" ancak bu diziyle sorgulanabiliyor
        // (`whereField("memberUids", arrayContains: uid)`), o yüzden yerel filtre
        // de aynı alana bakmalı — iki kaynak ayrışırsa buluta geçişte ekran
        // sessizce farklı bir liste gösterirdi.
        // ROLDEN BAĞIMSIZ. Hangi projeleri GÖRDÜĞÜNÜ üyelik belirler; rol ne
        // YAPABİLDİĞİNİ belirler. Önceden yönetici dalı `ownerUid == user.id`
        // süzüyordu ve bu, davet akışını sessizce kırıyordu: her yeni hesap
        // `.admin` açıldığı için davet edilen ortak sunucuda üye oluyor ama
        // dashboard'da hiçbir proje göremiyordu — katılma başarılı, sonuç boş
        // ekran.
        //
        // Sunucu zaten bu modeli uyguluyor: Firestore sorgusu
        // `whereField("memberUids", arrayContains: uid)` ve güvenlik kuralı
        // okumayı üyeliğe bağlıyor. İstemcinin farklı bir ölçüt kullanması iki
        // kaynağın ayrışması demekti.
        //
        // Sahip her zaman `memberUids` içinde: kural hem oluşturmada hem
        // güncellemede `uid() in memberUids` şartını koşuyor, yani kendi
        // projesini listeden düşürmek mümkün değil.
        return projects.filter { $0.memberUids.contains(user.id) }
    }

    /// Kullanıcı bu projeyi görebiliyor mu? (Derin bağlantı / eski rota koruması)
    func canAccess(projectId: UUID, user: User?) -> Bool {
        visibleProjects(for: user).contains { $0.id == projectId }
    }

    // MARK: - Proje bazlı erişim (filtreleme ViewModel'de, View'da değil)

    func materials(for projectId: UUID) -> [Material] {
        materials.filter { $0.projectId == projectId }
    }

    /// Bir malzemenin hareketleri — YENİDEN ESKİYE sıralı.
    ///
    /// Sıralama BURADA olmak zorundaydı: önceden yalnızca süzülüyordu ve sıra
    /// diziye nasıl girdiğine kalıyordu. İki kaynak iki farklı sıra veriyor —
    /// `addReceipt` başa ekliyor (yani geçmiş tarihli bir fiş en üste düşüyor),
    /// Firestore'un `getDocuments()` çağrısı ise `order(by:)` olmadığı için
    /// doküman kimliği (UUID) sırasında, yani RASTGELE döndürüyor. Sonuç:
    /// "Son Hareketler" listesi simülatörde doğru, gerçek cihazda karışık
    /// görünüyordu — en sinsi hata tipi, çünkü ekran çalışıyor gibi duruyor.
    ///
    /// Eşit tarihlerde kimliğe göre kırılıyor ki sonuç çağrıdan çağrıya AYNI
    /// olsun; aynı gün iki fiş girmek mümkün ve tarih alanı gün hassasiyetinde
    /// gösteriliyor.
    func logs(for materialId: UUID) -> [MaterialLog] {
        materialLogs
            .filter { $0.materialId == materialId }
            .sorted {
                $0.date == $1.date
                    ? $0.id.uuidString > $1.id.uuidString
                    : $0.date > $1.date
            }
    }

    // MARK: - Malzeme fiyat geçmişi (madde 25)

    /// Tek bir alım gözlemi.
    struct PriceObservation: Identifiable {
        let id: UUID
        let date: Date
        let unitPrice: Kurus
        let amount: Double
        /// Bir önceki gözleme göre oran değişimi (0,12 = %12 zam). İlk gözlemde nil.
        let changeRatio: Double?
    }

    /// Bir malzemenin alım fiyatı geçmişi — ESKİDEN YENİYE.
    ///
    /// YALNIZCA GİRİŞ FİŞLERİ. Çıkış fişleri de `unitPrice` taşıyor ama o bir
    /// alış fiyatı DEĞİL: `addReceipt` çıkışta o anki güncel fiyatı kaydın
    /// içine kopyalıyor. Seriye girseler aynı fiyatın tekrarları olarak çizgiyi
    /// yapay biçimde düzleştirirlerdi — bağımsız bir gözlem değiller.
    /// `Material.recalculate` da maliyete yalnızca girişleri katıyor; aynı
    /// süzgeç.
    ///
    /// DEVİR (`openingCost`) BU SERİDE YOK ve olamaz: tarihi yok, fiş dökümü
    /// yok. Demo veride maliyetin çoğu oradadır. Bu yüzden ekranda kapsam
    /// yazılı: seri "proje boyunca fiyat" değil, "kayıtlı giriş fişlerindeki
    /// fiyat".
    func priceHistory(for materialId: UUID) -> [PriceObservation] {
        let entries = materialLogs
            .filter { $0.materialId == materialId && $0.type == .entry }
            .sorted {
                $0.date == $1.date
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.date < $1.date
            }

        return entries.enumerated().map { index, log in
            var ratio: Double?
            if index > 0 {
                let previous = entries[index - 1].unitPrice
                // Para/para bölmesi AÇIKÇA raw üzerinden: Kurus'ta bölme
                // operatörü yok ve oran üretmek yeni bir yuvarlama noktası
                // olmasın diye burada Double'a çıkılıyor (bkz. Kurus.swift).
                if previous.raw != 0 {
                    ratio = Double(log.unitPrice.raw - previous.raw) / Double(previous.raw)
                }
            }
            return PriceObservation(id: log.id, date: log.date,
                                    unitPrice: log.unitPrice,
                                    amount: log.amount, changeRatio: ratio)
        }
    }

    /// İlk gözlemden son gözleme oran değişimi. Tek gözlem varsa nil.
    func priceChangeRatio(for materialId: UUID) -> Double? {
        let history = priceHistory(for: materialId)
        guard let first = history.first, let last = history.last,
              first.id != last.id, first.unitPrice.raw != 0 else { return nil }
        return Double(last.unitPrice.raw - first.unitPrice.raw) / Double(first.unitPrice.raw)
    }

    func apartments(for projectId: UUID) -> [Apartment] {
        apartments
            .filter { $0.projectId == projectId }
            .sorted { $0.apartmentNumber < $1.apartmentNumber }
    }

    func partners(for projectId: UUID) -> [Partner] {
        partners.filter { $0.projectId == projectId }
    }

    /// Belgeler — ortak yalnızca "Ortaklar görebilsin" açık olanları görür.
    func documents(for projectId: UUID, role: UserRole) -> [ProjectDocument] {
        documents.filter { $0.projectId == projectId && (role == .admin || $0.partnerVisible) }
    }

    /// Belge tarihlerinden (Fmt.makeDate(12, 1, 2026)) en yenisini bulur; başlıktaki "son yükleme" için.
    /// İçinde bulunulan yıla aitse yıl gösterilmez ("14 Tem"), değilse tam tarih döner.
    func lastUploadText(for projectId: UUID, role: UserRole) -> String? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let parsed: [(Int, Int, Int, String)] = documents(for: projectId, role: role).compactMap { doc in
            let parts = doc.dateText.split(separator: " ")
            guard parts.count >= 2,
                  let day = Int(parts[0]),
                  let monthIndex = Self.monthNames.firstIndex(of: String(parts[1])) else { return nil }
            let year = parts.count > 2 ? (Int(parts[2]) ?? currentYear) : currentYear
            return (year, monthIndex + 1, day, doc.dateText)
        }
        guard let newest = parsed.max(by: { ($0.0, $0.1, $0.2) < ($1.0, $1.1, $1.2) }) else { return nil }
        if newest.0 == currentYear {
            return "\(newest.2) \(Self.monthNames[newest.1 - 1])"
        }
        return newest.3
    }

    func photos(for projectId: UUID) -> [SitePhoto] {
        sitePhotos.filter { $0.projectId == projectId }
    }

    /// Bir dairenin görselleri (yer tutucular dahil).
    func photos(forApartment apartmentId: UUID) -> [ApartmentPhoto] {
        apartmentPhotos.filter { $0.apartmentId == apartmentId }
    }

    /// Kimlikler artık UUID olduğu için mock veri ve testler kalemi
    /// insan tarafından okunabilir koddan/numaradan bulur.
    func material(in projectId: UUID, code: String) -> Material? {
        materials.first { $0.projectId == projectId && $0.code == code }
    }

    func apartment(in projectId: UUID, number: Int) -> Apartment? {
        apartments.first { $0.projectId == projectId && $0.apartmentNumber == number }
    }

    // MARK: - Özet rakamlar

    /// Toplam satış cirosu (yalnızca satılan dairelerin bedelleri).
    /// Not: Boş daireler liste fiyatı taşıyabilir (TOKİ gerçek verisi) — ciroya girmez.
    /// Rezerve daire de girmez: sözleşme henüz kesinleşmedi. Kat karşılığı zaten bedelsiz.
    func totalSales(for projectId: UUID) -> Kurus {
        apartments(for: projectId).filter(\.countsAsRevenue).reduce(Kurus.zero) { $0 + $1.price }
    }

    /// Toplam malzeme gideri (giren × birim fiyat).
    func totalMaterialCost(for projectId: UUID) -> Kurus {
        materials(for: projectId).reduce(Kurus.zero) { $0 + $1.totalCost }
    }

    /// Projenin malzeme dışı giderleri (işçilik, taşeron, arsa, harç…).
    func expenses(for projectId: UUID) -> [Expense] {
        expenses.filter { $0.projectId == projectId }.sorted { $0.date > $1.date }
    }

    func totalOtherExpenses(for projectId: UUID) -> Kurus {
        expenses.filter { $0.projectId == projectId }.reduce(Kurus.zero) { $0 + $1.amount }
    }

    /// Kategori bazlı kırılım (büyükten küçüğe) — Giderler sekmesindeki özet.
    func expenseBreakdown(for projectId: UUID) -> [(category: Expense.Category, total: Kurus)] {
        Dictionary(grouping: expenses.filter { $0.projectId == projectId }, by: \.category)
            .map { (category: $0.key, total: $0.value.reduce(Kurus.zero) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    /// Projenin TOPLAM gideri: malzeme + diğer kalemler.
    func totalCost(for projectId: UUID) -> Kurus {
        totalMaterialCost(for: projectId) + totalOtherExpenses(for: projectId)
    }

    /// Net = satış − (malzeme + diğer giderler).
    /// Gider defteri geldiği için artık "net" demek dürüst; yalnızca uygulamaya
    /// GİRİLEN giderleri kapsadığı ekranlarda ayrıca belirtilir.
    func netAmount(for projectId: UUID) -> Kurus {
        totalSales(for: projectId) - totalCost(for: projectId)
    }

    func soldCount(for projectId: UUID) -> Int {
        apartments(for: projectId).filter(\.countsAsRevenue).count
    }

    /// Rezerve (kapora aşamasındaki) daire sayısı.
    func reservedCount(for projectId: UUID) -> Int {
        apartments(for: projectId).filter { $0.status == .reserved }.count
    }

    /// Arsa sahibine giden kat karşılığı daire sayısı.
    func landOwnerCount(for projectId: UUID) -> Int {
        apartments(for: projectId).filter { $0.status == .landOwner }.count
    }

    /// Gerçekten satışa hazır, boş daire sayısı ("Kalan" karosu).
    /// Önceden "toplam − satılan" deniyordu; bu, kat karşılığı ve rezerve
    /// daireleri satılabilir stok gibi gösteriyordu — maddenin asıl semptomu.
    func availableCount(for projectId: UUID) -> Int {
        apartments(for: projectId).filter(\.isSellable).count
    }

    /// Satış oranının PAYDASI: kat karşılığı hariç toplam daire.
    /// Kat karşılığı paydada kalsaydı, müteahhidin payının tamamı satılsa bile
    /// oran hiçbir zaman %100 olmazdı.
    func sellableCount(for projectId: UUID) -> Int {
        apartments(for: projectId).filter(\.isInSalesScope).count
    }

    /// Satış oranı (0…1). Tek payda: hem dashboard hem Daireler sekmesi bunu kullanır —
    /// önceden biri `apartments.count`, diğeri `project.totalApartments` kullanıyordu.
    func salesRate(for projectId: UUID) -> Double {
        let sellable = sellableCount(for: projectId)
        return sellable > 0 ? Double(soldCount(for: projectId)) / Double(sellable) : 0
    }

    /// Tahsil edilen toplam — yalnızca SATILAN dairelerden.
    /// Payı (totalSales) ve çıkanı aynı daire kümesinden almak zorunlu: aksi
    /// halde ilk rezerve kaporası girdiğinde "kalan alacak" sessizce düşer,
    /// az satışlı projede eksiye iner.
    func collectedAmount(for projectId: UUID) -> Kurus {
        apartments(for: projectId).filter(\.countsAsRevenue).reduce(Kurus.zero) { $0 + $1.paidAmount }
    }

    /// Rezerve dairelerde bekleyen kapora havuzu. Gerçek nakit olduğu için
    /// görünmeli, ama ciroya ve satış tahsilatına karışmamalı.
    func depositAmount(for projectId: UUID) -> Kurus {
        apartments(for: projectId).filter { $0.status == .reserved }.reduce(Kurus.zero) { $0 + $1.paidAmount }
    }

    /// Kalan alacak toplamı. Daire başına `remainingAmount` max(0,…) ile kırpıldığı
    /// için proje toplamı da kırpılmalı: aksi halde tek bir dairedeki fazla tahsilat
    /// ortağa "Kalan alacak −3,40 M ₺" olarak gösterilirdi.
    func outstandingAmount(for projectId: UUID) -> Kurus {
        max(.zero, totalSales(for: projectId) - collectedAmount(for: projectId))
    }

    /// Dashboard alt başlığı — yalnızca kullanıcının eriştiği projeleri sayar.
    func dashboardSubtitle(for user: User?) -> String {
        let visible = visibleProjects(for: user)
        let apartmentTotal = visible.reduce(0) { $0 + $1.totalApartments }
        return "\(visible.count) proje · \(apartmentTotal) daire · Bugün \(Fmt.clock()) güncellendi"
    }

    // MARK: - Yönetici işlemleri (yetki kontrolü çağıran ekranda + burada)

    /// Fiş / malzeme hareketi kaydeder. Boş miktar tasarım gereği "Miktar girilmedi" uyarısı verir.
    /// - Returns: Kayıt başarılıysa true.
    @discardableResult
    func addReceipt(role: UserRole, materialId: UUID, type: MaterialLog.LogType,
                    amountText: String, unitPriceText: String, reference: String,
                    date: Date = Date(), receiptImage: UIImage? = nil) -> Bool {
        guard role == .admin else { return false }   // Ortak veri giremez
        guard let index = materials.firstIndex(where: { $0.id == materialId }) else {
            flash("Malzeme seçilmedi")
            return false
        }

        let amount = Self.parseQuantity(amountText)
        guard amount > 0 else {
            flash("Miktar girilmedi")
            return false
        }

        let material = materials[index]
        // Kayda geçen miktar, stoğa uygulanan miktarla daima aynıdır:
        // çıkışta stok yetmiyorsa sessizce kırpmak yerine işlemi reddederiz.
        let effectivePrice: Kurus

        if type == .entry {
            let newPrice = Self.parseMoney(unitPriceText)
            // Fiyat yalnızca bu girişe uygulanır; geçmiş stok yeniden fiyatlanmaz.
            effectivePrice = newPrice > .zero ? newPrice : material.unitPrice
            // Atama YOK: fiş eklendikten sonra `refreshCurrentPrice` en yeni
            // giriş fişinden türetiyor. Burada doğrudan yazılsaydı geçmiş
            // tarihli bir fiş "güncel fiyat"ı geriye çekerdi.
        } else {
            guard material.currentStock >= amount else {
                flash("Stok yetersiz · kalan \(Fmt.qty(material.currentStock, unit: material.unit))")
                return false
            }
            effectivePrice = material.unitPrice
        }

        let note = reference.isEmpty
            ? (type == .entry ? "İrsaliye kaydı" : "Saha kullanımı")
            : reference
        let log = MaterialLog(id: UUID(), projectId: material.projectId,
                              materialId: materialId, type: type,
                              amount: amount, unitPrice: effectivePrice,
                              date: date,
                              note: note, user: actorName)
        materialLogs.insert(log, at: 0)
        // Kamerayla çekilen fiş görseli: diske ANINDA, buluta arkadan.
        // Önceden yalnızca sözlüğe konuyordu — "Fiş kaydedildi" deniyor ama
        // piksel uygulama kapanınca uçuyordu.
        if let receiptImage {
            storeReceipt(receiptImage, bucket: .receipts,
                         projectId: material.projectId, id: log.id)
        }
        // Stok ve maliyet toplamları hareketlerden yeniden türetilir.
        var changes: [DocumentChange] = [.materialLog(log)]
        if let updated = recalculateMaterial(materialId) { changes.append(.material(updated)) }

        // Hareket akışına düşür.
        let verb = type == .entry ? "giriş" : "çıkış"
        let project = projects.first { $0.id == material.projectId }
        changes.append(pushActivity(
            ActivityItem(id: UUID(), projectId: material.projectId,
                         kind: type == .entry ? .materialIn : .materialOut,
                         title: "\(material.name) · \(Fmt.qty(amount, unit: material.unit)) \(verb)",
                         meta: "\(project?.title ?? "") · \(note)",
                         timestamp: Date())))
        persist(changes, failureNote: "Fiş")
        flash("Fiş kaydedildi")
        return true
    }

    /// Kayıtlı bir fişi düzeltir. Yanlış girilen 125.000 kg demirin tek çaresi
    /// telafi çıkışı girmekti; o da maliyeti azaltmıyordu. Değişiklik denetim
    /// izine yazılır — ortak da neyin ne zaman düzeltildiğini görebilsin.
    @discardableResult
    func updateReceipt(role: UserRole, logId: UUID, type: MaterialLog.LogType,
                       amountText: String, unitPriceText: String, reference: String,
                       date: Date, receipt: ReceiptEdit = .unchanged) -> Bool {
        guard role == .admin else { return false }
        guard let logIndex = materialLogs.firstIndex(where: { $0.id == logId }),
              let material = materials.first(where: { $0.id == materialLogs[logIndex].materialId })
        else { return false }

        let amount = Self.parseQuantity(amountText)
        guard amount > 0 else {
            flash("Miktar girilmedi")
            return false
        }

        let old = materialLogs[logIndex]
        let newPrice = Self.parseMoney(unitPriceText)
        var updated = old
        updated.type = type
        updated.amount = amount
        updated.unitPrice = newPrice > .zero ? newPrice : old.unitPrice
        updated.date = date
        updated.note = reference.isEmpty ? old.note : reference

        // Önce uygula, sonra sonucu denetle: düzeltme stoğu eksiye düşürüyorsa
        // (ör. çoktan harcanmış bir girişi küçültmek) işlem geri alınır.
        materialLogs[logIndex] = updated
        recalculateMaterial(material.id)
        if let check = materials.first(where: { $0.id == material.id }), check.currentStock < 0 {
            materialLogs[logIndex] = old
            recalculateMaterial(material.id)
            flash("Bu düzeltme stoğu eksiye düşürür")
            return false
        }
        // Fiş görseli: üç durum ayrı ayrı işleniyor (bkz. ReceiptEdit).
        var receiptChanged = false
        switch receipt {
        case .unchanged:
            break
        case .replaced(let image):
            // Yol belirlenimci olduğu için yeni görsel eskisinin ÜZERİNE yazar;
            // yetim doğmaz. Yol zaten yazılıysa yeniden yazılması da zararsız.
            storeReceipt(image, bucket: .receipts,
                         projectId: materialLogs[logIndex].projectId, id: logId)
            receiptChanged = true
        case .cleared:
            discardReceipt(bucket: .receipts, projectId: materialLogs[logIndex].projectId,
                           id: logId, path: materialLogs[logIndex].receiptPath)
            materialLogs[logIndex].receiptPath = nil
            receiptChanged = true
        }

        // Neyin değiştiğini alan alan yaz.
        var changes: [AuditEntry.Change] = []
        if old.type != updated.type {
            changes.append(.init(field: "Tür",
                                 oldValue: old.type == .entry ? "Giriş" : "Çıkış",
                                 newValue: updated.type == .entry ? "Giriş" : "Çıkış"))
        }
        if old.amount != updated.amount {
            changes.append(.init(field: "Miktar",
                                 oldValue: Fmt.qty(old.amount, unit: material.unit),
                                 newValue: Fmt.qty(updated.amount, unit: material.unit)))
        }
        if old.unitPrice != updated.unitPrice {
            changes.append(.init(field: "Birim fiyat",
                                 oldValue: Fmt.unitPriceExact(old.unitPrice, unit: material.unit),
                                 newValue: Fmt.unitPriceExact(updated.unitPrice, unit: material.unit)))
        }
        if old.date != updated.date {
            changes.append(.init(field: "Tarih", oldValue: old.dateText, newValue: updated.dateText))
        }
        if old.note != updated.note {
            changes.append(.init(field: "Açıklama", oldValue: old.note, newValue: updated.note))
        }
        if receiptChanged {
            changes.append(.init(field: "Fiş fotoğrafı",
                                 oldValue: old.receiptPath == nil ? "yok" : "vardı",
                                 newValue: receipt.isCleared ? "kaldırıldı" : "değiştirildi"))
        }
        guard !changes.isEmpty else {
            flash("Değişiklik yok")
            return true
        }
        // Görsel kaldırıldıysa `receiptPath` yukarıda nil'lendi; yazılacak kayıt
        // diziden TAZE alınmalı, yoksa yol belgede yaşamaya devam ederdi.
        var writes: [DocumentChange] = [.materialLog(materialLogs[logIndex])]
        if let refreshed = materials.first(where: { $0.id == material.id }) {
            writes.append(.material(refreshed))
        }
        writes += recordAudit(recordId: logId, projectId: material.projectId,
                              subject: "\(material.name) fişi", action: .update, changes: changes)
        persist(writes, failureNote: "Fiş düzeltmesi")
        flash("Fiş güncellendi")
        return true
    }

    /// Fişi siler; stok ve maliyet hareketlerden yeniden türetilir.
    @discardableResult
    func deleteReceipt(role: UserRole, logId: UUID) -> Bool {
        guard role == .admin else { return false }
        guard let logIndex = materialLogs.firstIndex(where: { $0.id == logId }),
              let material = materials.first(where: { $0.id == materialLogs[logIndex].materialId })
        else { return false }

        let removed = materialLogs.remove(at: logIndex)
        recalculateMaterial(material.id)
        // Silinen giriş zaten harcanmışsa stok eksiye düşer — kayıt geri konur.
        if let check = materials.first(where: { $0.id == material.id }), check.currentStock < 0 {
            materialLogs.insert(removed, at: logIndex)
            recalculateMaterial(material.id)
            flash("Bu fiş silinirse stok eksiye düşer")
            return false
        }
        // Silme, YUKARIDAKİ geri alma dalından SONRA: reddedilen bir silme
        // hâlâ yaşayan bir fişin bulut nesnesini yok etmemeli.
        discardReceipt(bucket: .receipts, projectId: material.projectId,
                       id: logId, path: removed.receiptPath)

        var writes: [DocumentChange] = [.deleteMaterialLog(id: logId, projectId: material.projectId)]
        if let refreshed = materials.first(where: { $0.id == material.id }) {
            writes.append(.material(refreshed))
        }
        writes += recordAudit(recordId: logId, projectId: material.projectId,
                              subject: "\(material.name) fişi", action: .delete,
                              changes: [.init(field: removed.type == .entry ? "Giriş" : "Çıkış",
                                              oldValue: Fmt.qty(removed.amount, unit: material.unit),
                                              newValue: "silindi")])
        persist(writes, failureNote: "Fiş silme")
        flash("Fiş silindi")
        return true
    }

    // MARK: Denetim izi

    /// Bir kaydın değişiklik geçmişi (yeniden eskiye).
    func audit(for recordId: UUID) -> [AuditEntry] {
        auditEntries.filter { $0.recordId == recordId }.sorted { $0.date > $1.date }
    }

    /// Bir projenin tüm değişiklik kayıtları — ortak da görebilir.
    func audit(forProject projectId: UUID) -> [AuditEntry] {
        auditEntries.filter { $0.projectId == projectId }.sorted { $0.date > $1.date }
    }

    /// Değişikliği deftere yazar ve hareket akışına düşürür.
    /// Akışa da düşmesi bilinçli: düzeltme yalnızca yöneticinin gördüğü bir
    /// yerde kalırsa "şeffaf" iddiası ortak açısından doğrulanabilir olmaz.
    /// - Returns: Kalıcılığa gönderilecek kayıtlar. Çağıran bunları kendi
    ///   listesine ekler ki bir eylemin tüm yazmaları TEK parti olarak gitsin.
    private func recordAudit(recordId: UUID, projectId: UUID, subject: String,
                             action: AuditEntry.Action,
                             changes: [AuditEntry.Change]) -> [DocumentChange] {
        let entry = AuditEntry(id: UUID(), recordId: recordId, projectId: projectId,
                               subject: subject, action: action, changes: changes,
                               user: actorName, date: Date())
        auditEntries.insert(entry, at: 0)

        let projectTitle = projects.first { $0.id == projectId }?.title ?? ""
        let activity = ActivityItem(id: UUID(), projectId: projectId, kind: .edit,
                                    title: "\(subject) \(action.rawValue)",
                                    meta: [projectTitle, entry.summary]
                                         .filter { !$0.isEmpty }.joined(separator: " · "),
                                    timestamp: entry.date)
        activities.insert(activity, at: 0)
        hasUnreadActivity = true
        return [.audit(entry), .activity(activity)]
    }

    /// Hareket akışına satır ekler; kalıcılık kaydını da döndürür.
    private func pushActivity(_ item: ActivityItem) -> DocumentChange {
        activities.insert(item, at: 0)
        hasUnreadActivity = true
        return .activity(item)
    }

    /// Malzeme toplamları TEK yerden türetilir: devir + kayıtlı hareketler.
    /// Silme ve düzenleme ancak böyle geri alınabilir oluyor.
    /// - Returns: Güncellenen malzeme (kalıcılığa yazılmak üzere).
    @discardableResult
    private func recalculateMaterial(_ materialId: UUID) -> Material? {
        guard let index = materials.firstIndex(where: { $0.id == materialId }) else { return nil }
        materials[index].recalculate(from: materialLogs)

        // "Güncel fiyat" da hareketlerden TÜRETİLİYOR — en yeni giriş fişinden.
        //
        // Önceden `addReceipt` bu alana doğrudan yazıyordu ve iki kusuru vardı:
        // (1) karar ekleme anına bakıyordu, fişin TARİHİNE değil — bugün geçen
        // ayın 24,80'lik fişini girmek "güncel fiyat"ı 28,50'den geriye
        // çekiyordu; (2) fiş düzeltilince ya da silinince geri alınmıyordu —
        // fiyatı yanlışlıkla 2.850 girip sonra düzelten yönetici kartta hâlâ
        // 2.850 ₺/kg görüyordu. Yani türetilebilir bir değerin saklanmış hâliydi
        // ve projenin "türetilen rakam saklanmaz" ilkesini ihlal ediyordu.
        //
        // Burada olması üç yolu birden kapatıyor: ekleme, düzeltme, silme —
        // hepsi bu fonksiyondan geçiyor.
        //
        // Hiç giriş fişi yoksa alan OLDUĞU GİBİ kalıyor: yalnızca devirle açılmış
        // bir kalemin fiyatı elle girilmiştir, türetilecek kaynak yoktur.
        let newest = materialLogs
            .filter { $0.materialId == materialId && $0.type == .entry }
            .max { lhs, rhs in
                lhs.date == rhs.date
                    ? lhs.id.uuidString < rhs.id.uuidString
                    : lhs.date < rhs.date
            }
        if let newest, newest.unitPrice > .zero {
            materials[index].unitPrice = newest.unitPrice
        }
        return materials[index]
    }

    /// Projenin inşaat ilerlemesini ve yapım aşamasını günceller.
    /// Bu iki alan dashboard kartının en büyük görsel öğesi; düzenlenemediği için
    /// kullanıcının açtığı her proje sonsuza dek "%0 · Temel" görünüyordu.
    func updateProgress(role: UserRole, projectId: UUID, progress: Int, phase: ProjectPhase) {
        guard role == .admin,
              let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].progress = min(100, max(0, progress))
        projects[index].phase = phase
        persist([.project(projects[index])], failureNote: "İlerleme")
        flash("İlerleme güncellendi")
    }

    /// Satışı iptal eder; daire tekrar boşa döner.
    /// Yanlış daireye satış işlemek tek dokunuşla mümkün olduğu için geri dönüş şart.
    /// Liste fiyatı (TOKİ gerçek verisi) korunur — satış formunda yeniden önerilir.
    @discardableResult
    func cancelSale(role: UserRole, apartmentId: UUID) -> Bool {
        guard role == .admin else { return false }
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }),
              apartments[index].isCommitted else { return false }

        var apartment = apartments[index]
        let hadBuyer = apartment.buyerName != nil
        let price = apartment.price
        let collected = apartment.paidAmount
        let wasReserved = apartment.status == .reserved

        apartment.status = .available
        apartment.buyerName = nil
        apartment.paidAmount = .zero
        apartment.paymentStatus = nil
        apartment.saleDate = nil
        apartments[index] = apartment

        // Satış iptal edilince o daireye ait tahsilat kayıtları da düşer.
        let removed = payments.filter { $0.apartmentId == apartmentId }
        // N adet dekont: belgeler silindikten sonra bu kimlikler hiçbir yerden
        // geri gelmez — nesneleri şimdi silinmezse bulutta sonsuza dek kalır ve
        // her biri alıcının adını taşır.
        for payment in removed {
            discardReceipt(bucket: .paymentReceipts, projectId: payment.projectId,
                           id: payment.id, path: payment.receiptPath)
        }
        payments.removeAll { $0.apartmentId == apartmentId }

        // İptal, silinen tahsilatın ANLIK GÖRÜNTÜSÜYLE deftere yazılır.
        // Daire .available'a döndüğü ve ödeme kayıtları silindiği için, bu kayıt
        // olmadan gerçekten tahsil edilmiş paranın izi hiçbir yerde kalmazdı;
        // ortağa dağıtılan geçmiş rapordaki ciro farkı da açıklanamazdı.
        var changes: [AuditEntry.Change] = [
            .init(field: "Durum",
                  oldValue: wasReserved ? "Rezerve" : "Satıldı",
                  newValue: "Boş"),
            // Ad bilerek YOK — defter ortağa açık (bkz. saveSale'deki not).
            .init(field: "Alıcı kaydı", oldValue: hadBuyer ? "kayıtlı" : "—", newValue: "kaldırıldı"),
            .init(field: "Bedel", oldValue: Fmt.money(price), newValue: "—"),
        ]
        if collected > .zero {
            changes.append(.init(field: "Silinen tahsilat",
                                 oldValue: "\(removed.count) kayıt · \(Fmt.money(collected))",
                                 newValue: "—"))
        }
        var writes: [DocumentChange] = [.apartment(apartment),
                                        // Kimlik, gereklilik bitince silinir
                                        // (veri minimizasyonu).
                                        .deleteBuyer(apartmentId: apartmentId,
                                                     projectId: apartment.projectId),
                                        .deletePayments(ids: removed.map(\.id),
                                                        projectId: apartment.projectId)]
        writes += recordAudit(recordId: apartmentId, projectId: apartment.projectId,
                              subject: "Daire No \(apartment.apartmentNumber) satışı",
                              action: .delete, changes: changes)

        // İptal de bir harekettir; ortakların akışında görünmeli (şeffaflık).
        let projectTitle = projects.first { $0.id == apartment.projectId }?.title ?? ""
        writes.append(pushActivity(
            ActivityItem(id: UUID(), projectId: apartment.projectId, kind: .sale,
                         title: "Daire No \(apartment.apartmentNumber) \(wasReserved ? "rezervi kaldırıldı" : "satışı iptal edildi")",
                         meta: "\(projectTitle) · \(Fmt.compactMoney(price))",
                         timestamp: Date())))
        persist(writes, failureNote: "Satış iptali")
        flash(wasReserved ? "Rezerv kaldırıldı" : "Satış iptal edildi")
        return true
    }

    /// Daire bilgisini günceller: tip, alan, kat, durum, liste fiyatı, teslim notu.
    /// Bu form olmadan yeni projede uydurulan "2+1 / 95 m²" hiçbir yerden
    /// düzeltilemiyordu — raporun "1. gün bırakma anı" dediği yer burasıydı.
    /// Satış bu fonksiyondan YAPILAMAZ; .sold'a yalnızca saveSale geçirir.
    @discardableResult
    func updateApartment(role: UserRole, apartmentId: UUID, type: String, area: String,
                         floor: Int, status: Apartment.Status,
                         listPriceText: String, deliveryNote: String) -> Bool {
        guard role == .admin else { return false }
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }) else { return false }

        let before = apartments[index]
        // Satış kaydı olan daire bu formdan boşaltılamaz: tahsilatı hiçbir
        // kovaya girmeyen bir daire, parayı toplamlardan sessizce düşürürdü.
        if before.isCommitted, status != before.status, status != .sold {
            flash("Önce satışı iptal et")
            return false
        }
        guard status != .sold || before.status == .sold else {
            flash("Satış, satış formundan kaydedilir")
            return false
        }

        var apartment = before
        apartment.type = type.trimmingCharacters(in: .whitespaces)
        apartment.area = area.trimmingCharacters(in: .whitespaces)
        apartment.floor = floor
        apartment.deliveryNote = deliveryNote.trimmingCharacters(in: .whitespaces)
        apartment.status = status

        if status == .landOwner {
            // Kat karşılığı daire bedelsizdir: arsa bedeli gider defterinde
            // ".arsa" kategorisinde duruyor. Daireye ayrıca bedel yazılırsa
            // aynı ekonomik olay iki kez maliyete girer.
            apartment.price = .zero
            apartment.buyerName = nil
            apartment.paymentStatus = nil
        } else if status != .sold {
            // Boş/rezerve dairede girilen rakam LİSTE fiyatıdır — satış formunda önerilir.
            apartment.price = Self.parseMoney(listPriceText)
        }
        apartments[index] = apartment

        var changes: [AuditEntry.Change] = []
        if before.status != apartment.status {
            changes.append(.init(field: "Durum", oldValue: before.status.label, newValue: apartment.status.label))
        }
        if before.type != apartment.type {
            changes.append(.init(field: "Tip", oldValue: before.type, newValue: apartment.type))
        }
        if before.area != apartment.area {
            changes.append(.init(field: "Alan", oldValue: before.area, newValue: apartment.area))
        }
        if before.floor != apartment.floor {
            changes.append(.init(field: "Kat", oldValue: before.floorLabel, newValue: apartment.floorLabel))
        }
        if before.price != apartment.price {
            changes.append(.init(field: "Liste fiyatı",
                                 oldValue: Fmt.money(before.price), newValue: Fmt.money(apartment.price)))
        }
        if before.deliveryNote != apartment.deliveryNote {
            changes.append(.init(field: "Teslim notu",
                                 oldValue: before.deliveryNote, newValue: apartment.deliveryNote))
        }
        guard !changes.isEmpty else {
            flash("Değişiklik yok")
            return true
        }
        var writes: [DocumentChange] = [.apartment(apartment)]
        if before.buyerName != nil, apartment.buyerName == nil {
            // Kat karşılığına çevrilen dairenin alıcı belgesi yetim kalmasın.
            writes.append(.deleteBuyer(apartmentId: apartmentId,
                                       projectId: apartment.projectId))
        }
        writes += recordAudit(recordId: apartmentId, projectId: apartment.projectId,
                              subject: "Daire No \(apartment.apartmentNumber)",
                              action: .update, changes: changes)
        persist(writes, failureNote: "Daire bilgisi")
        flash("Daire bilgisi güncellendi")
        return true
    }

    // MARK: Tahsilat

    /// Bir dairenin ödeme geçmişi (yeniden eskiye).
    func payments(forApartment apartmentId: UUID) -> [Payment] {
        payments.filter { $0.apartmentId == apartmentId }.sorted { $0.date > $1.date }
    }

    /// Daireye tahsilat işler. Toplam `paidAmount` bu kayıtlardan yeniden
    /// hesaplandığı için yönetici eski toplamı akıldan toplamak zorunda kalmaz.
    @discardableResult
    func addPayment(role: UserRole, apartmentId: UUID, amountText: String,
                    method: Payment.Method, note: String, date: Date,
                    receiptImage: UIImage? = nil) -> Bool {
        guard role == .admin else { return false }
        guard let apartment = apartments.first(where: { $0.id == apartmentId }) else { return false }

        let amount = Self.parseMoney(amountText)
        guard amount > .zero else {
            flash("Tutar girilmedi")
            return false
        }
        // Kalan alacaktan fazla tahsilat reddedilir. Kabul edilse daire kartı
        // "Tahsil edildi" demeye devam ediyor (remainingAmount kırpılıyor), fazlalık
        // hiçbir yerde görünmüyor, ama proje "kalan alacağı" eksiye düşüyordu —
        // aynı havalenin iki kez girilmesi bunun en yaygın yolu.
        let remaining = max(.zero, apartment.price - apartment.paidAmount)
        if apartment.price > .zero, amount > remaining {
            flash(remaining > .zero
                  ? "Kalan alacak \(Fmt.money(remaining)) — fazlası girilemez"
                  : "Bedelin tamamı tahsil edilmiş")
            return false
        }

        let payment = Payment(id: UUID(), projectId: apartment.projectId,
                              apartmentId: apartmentId, amount: amount,
                              date: date, method: method,
                              note: note.trimmingCharacters(in: .whitespaces),
                              user: actorName)
        payments.append(payment)
        // Dekont AYRI kovada: üstünde gönderenin adı yazıyor, yani madde
        // 18'de ortaktan ayrılan alıcı kimliği. `receipts` kovasında dursaydı
        // Firestore'da kapatılan sızıntı Storage'dan geri açılırdı.
        if let receiptImage {
            storeReceipt(receiptImage, bucket: .paymentReceipts,
                         projectId: payment.projectId, id: payment.id)
        }
        var writes: [DocumentChange] = [.payment(payment)]
        if let updated = recalculateCollected(for: apartmentId) { writes.append(.apartment(updated)) }

        let projectTitle = projects.first { $0.id == apartment.projectId }?.title ?? ""
        writes.append(pushActivity(
            ActivityItem(id: UUID(), projectId: apartment.projectId, kind: .sale,
                         title: "Daire No \(apartment.apartmentNumber) tahsilat — \(Fmt.compactMoney(amount))",
                         meta: "\(projectTitle) · \(payment.detailText)",
                         timestamp: Date())))
        persist(writes, failureNote: "Tahsilat")
        flash("Tahsilat kaydedildi")
        return true
    }

    /// Yanlış girilen tahsilatı siler; toplam yeniden hesaplanır.
    func deletePayment(role: UserRole, id: UUID) {
        guard role == .admin,
              let payment = payments.first(where: { $0.id == id }),
              let apartment = apartments.first(where: { $0.id == payment.apartmentId }) else { return }
        payments.removeAll { $0.id == id }
        discardReceipt(bucket: .paymentReceipts, projectId: payment.projectId,
                       id: id, path: payment.receiptPath)
        var writes: [DocumentChange] = [.deletePayment(id: id, projectId: apartment.projectId)]
        if let updated = recalculateCollected(for: payment.apartmentId) { writes.append(.apartment(updated)) }
        writes += recordAudit(recordId: id, projectId: apartment.projectId,
                              subject: "Daire No \(apartment.apartmentNumber) tahsilatı", action: .delete,
                              changes: [.init(field: payment.detailText,
                                              oldValue: Fmt.money(payment.amount), newValue: "silindi")])
        persist(writes, failureNote: "Tahsilat silme")
        flash("Tahsilat silindi")
    }

    /// `paidAmount` ve ödeme durumu TEK yerden, ödeme kayıtlarından türetilir.
    /// - Returns: Güncellenen daire (kalıcılığa yazılmak üzere).
    @discardableResult
    private func recalculateCollected(for apartmentId: UUID) -> Apartment? {
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }) else { return nil }
        let total = payments.filter { $0.apartmentId == apartmentId }.reduce(Kurus.zero) { $0 + $1.amount }
        apartments[index].paidAmount = total

        // Bedelin tamamı tahsil edildiyse durum otomatik "Tamamlandı"ya geçer.
        // Kapı `isCommitted`: rezerve daireye kapora işlenince de ödeme durumu
        // oluşsun (isSold olsaydı çip boş kalırdı). Kat karşılığında price 0
        // olduğu için blok zaten hiç çalışmaz — doğru davranış.
        if apartments[index].isCommitted, apartments[index].price > .zero {
            if total >= apartments[index].price {
                apartments[index].paymentStatus = .tamamlandi
            } else if apartments[index].paymentStatus == .tamamlandi {
                // Ödeme silinip toplam düşerse durum geri alınır.
                apartments[index].paymentStatus = .taksitli
            }
        }
        return apartments[index]
    }

    /// Malzeme dışı gider kaydeder (işçilik, taşeron, arsa, harç…).
    /// Tarih serbesttir: akşam toplu giriş yapan müteahhit geçmiş güne yazabilir.
    @discardableResult
    func addExpense(role: UserRole, projectId: UUID, category: Expense.Category,
                    amountText: String, payee: String, note: String,
                    date: Date, receiptImage: UIImage? = nil) -> Bool {
        guard role == .admin else { return false }

        let amount = Self.parseMoney(amountText)
        guard amount > .zero else {
            flash("Tutar girilmedi")
            return false
        }

        let expense = Expense(id: UUID(), projectId: projectId, category: category,
                              amount: amount, date: date,
                              payee: payee.trimmingCharacters(in: .whitespaces),
                              note: note.trimmingCharacters(in: .whitespaces),
                              user: actorName)
        expenses.insert(expense, at: 0)
        if let receiptImage {
            storeReceipt(receiptImage, bucket: .receipts,
                         projectId: expense.projectId, id: expense.id)
        }

        let projectTitle = projects.first { $0.id == projectId }?.title ?? ""
        let activity = pushActivity(
            ActivityItem(id: UUID(), projectId: projectId, kind: .expense,
                         title: "\(category.rawValue) · \(Fmt.compactMoney(amount))",
                         meta: [projectTitle, expense.detailText]
                              .filter { !$0.isEmpty }.joined(separator: " · "),
                         timestamp: Date()))
        persist([.expense(expense), activity], failureNote: "Gider")
        flash("Gider kaydedildi")
        return true
    }

    /// Yanlış girilen gideri siler (yalnızca yönetici).
    func deleteExpense(role: UserRole, id: UUID) {
        guard role == .admin, let expense = expenses.first(where: { $0.id == id }) else { return }
        expenses.removeAll { $0.id == id }
        discardReceipt(bucket: .receipts, projectId: expense.projectId,
                       id: id, path: expense.receiptPath)
        var writes: [DocumentChange] = [.deleteExpense(id: id, projectId: expense.projectId)]
        writes += recordAudit(recordId: id, projectId: expense.projectId,
                              subject: expense.category.rawValue, action: .delete,
                              changes: [.init(field: expense.detailText.isEmpty ? "Tutar" : expense.detailText,
                                              oldValue: Fmt.money(expense.amount), newValue: "silindi")])
        persist(writes, failureNote: "Gider silme")
        flash("Gider silindi")
    }

    /// Projeye yeni malzeme kalemi tanımlar (varsayılan katalog dışındakiler için).
    /// Rozet kodu verilmezse addan türetilir: "Seramik" → "SER".
    @discardableResult
    func addMaterial(role: UserRole, projectId: UUID, name: String, subtitle: String,
                     unit: String, unitPriceText: String) -> Material? {
        guard role == .admin else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            flash("Malzeme adı girilmedi")
            return nil
        }
        guard !trimmedUnit.isEmpty else {
            flash("Birim girilmedi")
            return nil
        }

        let code = Self.badgeCode(from: trimmedName)
        // Aynı projede aynı kod varsa sonuna sayı eklenir (kimlikler çakışmasın).
        let existingCodes = Set(materials(for: projectId).map(\.code))
        var uniqueCode = code
        var suffix = 2
        while existingCodes.contains(uniqueCode) {
            uniqueCode = "\(code)\(suffix)"
            suffix += 1
        }

        let material = Material(id: UUID(), projectId: projectId,
                                code: uniqueCode, name: trimmedName,
                                subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                                unit: trimmedUnit,
                                unitPrice: Self.parseMoney(unitPriceText), step: 10)
        materials.append(material)
        persist([.material(material)], failureNote: "Malzeme")
        flash("\(trimmedName) eklendi")
        return material
    }

    /// "Nervürlü Demir" → "NER" · "Q" → "Q" (en fazla 3 harf, Türkçe büyük harf).
    static func badgeCode(from name: String) -> String {
        let letters = name.uppercased(with: Fmt.locale).filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(3))
    }

    /// Daire satışı ekler veya mevcut satış kaydını günceller.
    @discardableResult
    func saveSale(role: UserRole, apartmentId: UUID, buyerName: String,
                  priceText: String, paidText: String, payment: PaymentStatus, saleDate: Date? = nil) -> Bool {
        guard role == .admin else { return false }
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }) else { return false }

        // Kat karşılığı daire arsa sahibinindir; satış formunda seçilebilir
        // olmaması yetmez, model düzeyinde de reddedilmeli.
        guard apartments[index].status != .landOwner else {
            flash("Kat karşılığı daire satılamaz")
            return false
        }

        let price = Self.parseMoney(priceText)
        let trimmedBuyer = buyerName.trimmingCharacters(in: .whitespaces)
        guard price > .zero, !trimmedBuyer.isEmpty else {
            flash(price <= .zero ? "Satış bedeli girilmedi" : "Alıcı adı girilmedi")
            return false
        }

        var apartment = apartments[index]
        let before = apartment
        // "Yeni satış" = daha önce hiçbir taahhüt yok. Rezerve daire satışa
        // çevrilirken kapora ZATEN Payment olarak kayıtlı; burada isSold'a
        // bakılsaydı ikinci bir peşinat kaydı açılır ve tahsilat çift sayılırdı.
        let isNewSale = !apartment.isCommitted
        // Bedel, tahsil edilmiş tutarın altına indirilemez: aksi halde daire
        // bedelinden fazla tahsilat taşır, `remainingAmount` max(0,…) ile
        // kırpıldığı için kartta görünmez, ama proje "kalan alacağı" eksiye düşer.
        if !isNewSale, price < before.paidAmount {
            flash("Bedel tahsil edilenin (\(Fmt.money(before.paidAmount))) altına inemez")
            return false
        }

        apartment.status = .sold
        apartment.buyerName = trimmedBuyer
        apartment.price = price
        apartment.paymentStatus = payment
        apartment.saleDate = saleDate ?? apartment.saleDate ?? Date()
        apartments[index] = apartment
        var writes: [DocumentChange] = [
            // Kimlik daire belgesine DEĞİL, yalnızca yöneticinin okuyabildiği
            // buyers/{apartmentId} belgesine yazılır (madde 18). Dairedeki
            // buyerName alanı CodingKeys dışı — Firestore'a hiç çıkmıyor.
            .buyer(ApartmentBuyer(apartmentId: apartmentId,
                                  projectId: apartment.projectId,
                                  name: trimmedBuyer)),
        ]

        // İlk tahsilat da bir kayıt olarak defterde durur; `paidAmount` artık
        // doğrudan yazılmıyor, ödeme kayıtlarından hesaplanıyor.
        let target = payment == .tamamlandi ? price : min(price, Self.parseMoney(paidText))
        if isNewSale {
            if target > .zero {
                let initial = Payment(id: UUID(), projectId: apartment.projectId,
                                      apartmentId: apartmentId,
                                      amount: target,
                                      date: apartment.saleDate ?? Date(),
                                      method: payment == .tamamlandi ? .havale : .pesinat,
                                      note: payment == .tamamlandi ? "Satış bedeli" : "Sözleşme peşinatı",
                                      user: actorName)
                payments.append(initial)
                writes.append(.payment(initial))
            }
        } else if before.status == .reserved {
            // Rezerve satışa çevriliyor: kapora zaten kayıtlı, yalnızca FARK
            // kadar yeni kayıt açılır — yoksa aynı para iki kez sayılırdı.
            let delta = target - before.paidAmount
            if delta > .zero {
                let balance = Payment(id: UUID(), projectId: apartment.projectId,
                                      apartmentId: apartmentId,
                                      amount: delta,
                                      date: apartment.saleDate ?? Date(),
                                      method: payment == .tamamlandi ? .havale : .pesinat,
                                      note: "Sözleşme bakiyesi (kapora sonrası)",
                                      user: actorName)
                payments.append(balance)
                writes.append(.payment(balance))
            }
        }
        if let updated = recalculateCollected(for: apartmentId) { writes.append(.apartment(updated)) }

        // Denetim kaydı, recalculateCollected'DAN SONRA ve gerçekten yazılan
        // son durumla karşılaştırılarak yazılır. Önceden önce yazılıyordu:
        // kullanıcı "Tamamlandı" seçtiğinde recalculateCollected bunu (tahsilat
        // yetmediği için) geri alıyor, ama defter "Taksitli → Tamamlandı" diye
        // hiç gerçekleşmemiş bir değişikliği kalıcı olarak kaydediyordu.
        let after = apartments[index]
        if !isNewSale {
            var changes: [AuditEntry.Change] = []
            if before.status != after.status {
                changes.append(.init(field: "Durum",
                                     oldValue: before.status.label,
                                     newValue: after.status.label))
            }
            if before.buyerName != after.buyerName {
                // Denetim defteri ORTAĞA AÇIK; ad buraya yazılırsa gizlilik
                // sınırı (buyers yalnızca yönetici) defterden delinir. Defter
                // DEĞİŞİMİ söyler, kimliği söylemez — kimlik buyers belgesinde.
                changes.append(.init(field: "Alıcı kaydı",
                                     oldValue: before.buyerName == nil ? "—" : "kayıtlı",
                                     newValue: "güncellendi"))
            }
            if before.price != after.price {
                changes.append(.init(field: "Satış bedeli",
                                     oldValue: Fmt.money(before.price),
                                     newValue: Fmt.money(after.price)))
            }
            if before.paymentStatus != after.paymentStatus {
                changes.append(.init(field: "Ödeme durumu",
                                     oldValue: before.paymentStatus?.rawValue ?? "—",
                                     newValue: after.paymentStatus?.rawValue ?? "—"))
            }
            if before.paidAmount != after.paidAmount {
                changes.append(.init(field: "Tahsil edilen",
                                     oldValue: Fmt.money(before.paidAmount),
                                     newValue: Fmt.money(after.paidAmount)))
            }
            if before.saleDate != after.saleDate {
                changes.append(.init(field: "Satış tarihi",
                                     oldValue: before.saleDate.map(Fmt.shortDate) ?? "—",
                                     newValue: after.saleDate.map(Fmt.shortDate) ?? "—"))
            }
            if !changes.isEmpty {
                writes += recordAudit(recordId: apartmentId, projectId: apartment.projectId,
                                      subject: "Daire No \(apartment.apartmentNumber) satışı",
                                      action: .update, changes: changes)
            }
        }

        // Satış akışa `kind: .sale` olarak düşer. Koşul isNewSale DEĞİL "bu
        // işlemle .sold oldu mu": rezerveden çevrilen satış isNewSale=false
        // olduğu için akışa hiç düşmüyordu — ciro artıyor ama ortak "Satış"
        // filtresinde karşılığını bulamıyordu.
        if before.status != .sold {
            let projectTitle = projects.first { $0.id == apartment.projectId }?.title ?? ""
            let payNote: String
            switch after.paymentStatus ?? payment {
            case .tamamlandi: payNote = "Tahsil edildi"
            case .kapora:     payNote = "Kapora alındı"
            case .taksitli:   payNote = "Taksit planı başladı"
            }
            let prefix = before.status == .reserved ? "rezervden satışa çevrildi" : "satıldı"
            writes.append(pushActivity(
                ActivityItem(id: UUID(), projectId: apartment.projectId, kind: .sale,
                             title: "Daire No \(apartment.apartmentNumber) \(prefix) — \(Fmt.compactMoney(price))",
                             // Alıcı adı bilerek YOK: hareket akışı ortağa
                             // açık ve ciro bilgisi ad olmadan da tam.
                             meta: "\(projectTitle) · \(payNote)",
                             timestamp: Date())))
        }
        persist(writes, failureNote: "Satış")

        // Seçilen ödeme durumu tahsilata uymadığı için geri alındıysa sessiz kalmayalım.
        if after.paymentStatus != payment {
            flash("Tahsilat yetmediği için ödeme durumu \"\(after.paymentStatus?.rawValue ?? "—")\" kaldı")
        } else {
            flash(before.status == .sold ? "Satış kaydı güncellendi" : "Satış kaydedildi")
        }
        return true
    }

    /// Yeni proje (ada/parsel) oluşturur; daireleri boş olarak açar.
    @discardableResult
    /// Yeni proje kurar.
    ///
    /// `user` ZORUNLU: sahiplik ve ilk üyelik onun `uid`'inden geliyor. Önceden
    /// yalnızca `role` alıyordu ve sahiplik `User.admin.id`'ye SABİTLENMİŞTİ —
    /// kimlik doğrulaması gelmeden önce zararsızdı, sonrasında iki şeyi birden
    /// kırıyordu: proje kuran kişinin kendi listesinde görünmüyordu
    /// (`memberUids` onun uid'ini içermiyor) ve güvenlik kuralı yazmayı
    /// reddediyordu (`ownerUid != request.auth.uid`). Yani gerçek kimlikle
    /// hiç kimse proje kuramıyordu.
    func addProject(user: User?, block: String, parcel: String, district: String,
                    city: String, floors: Int, apartmentCount: Int) -> Project? {
        guard let user, user.role == .admin else { return nil }
        let trimmedBlock = block.trimmingCharacters(in: .whitespaces)
        let trimmedParcel = parcel.trimmingCharacters(in: .whitespaces)
        guard !trimmedBlock.isEmpty, !trimmedParcel.isEmpty else {
            flash("Ada ve parsel girilmedi")
            return nil
        }

        let project = Project(id: UUID(),
                              blockNumber: trimmedBlock, parcelNumber: trimmedParcel,
                              district: district.isEmpty ? "—" : district,
                              city: city.isEmpty ? "—" : city,
                              floors: max(1, floors), totalApartments: max(1, apartmentCount),
                              phase: .temel, progress: 0,
                              ownerUid: user.id,
                              memberUids: [user.id],
                              createdAt: Date(),
                              invite: nil, photoCount: 0)
        projects.append(project)
        var writes: [DocumentChange] = [.project(project)]

        // Daireler boş (satılmamış) olarak oluşturulur; kat = 4 daire varsayımıyla.
        // Tip ve alan UYDURULMAZ: önceden sabit bir listeden ("2+1 / 95 m²")
        // dolduruluyordu ve hiçbir ekrandan düzeltilemiyordu — müteahhit kendi
        // projesini kurduğu ilk dakikada 20 yanlış daire görüyordu. Artık boş
        // gelir ve daire kartından tek tek düzenlenir.
        let perFloor = max(1, Int((Double(project.totalApartments) / Double(project.floors)).rounded(.up)))
        for n in 1...project.totalApartments {
            let apartment = Apartment(id: UUID(), projectId: project.id,
                                      apartmentNumber: n, floor: (n - 1) / perFloor + 1,
                                      type: "—", area: "—", status: .available,
                                      buyerName: nil, price: .zero, paidAmount: .zero,
                                      paymentStatus: nil, saleDate: nil,
                                      deliveryNote: "Yapım sürüyor")
            apartments.append(apartment)
            writes.append(.apartment(apartment))
        }

        // Standart malzeme kataloğu sıfır stokla açılır — aksi halde "Fiş Ekle"
        // formunda seçilecek malzeme olmaz ve kaydetme sessizce başarısız olurdu.
        for item in Self.materialCatalog {
            let material = Material(id: UUID(), projectId: project.id,
                                    code: item.code, name: item.name, subtitle: item.subtitle,
                                    unit: item.unit, unitPrice: item.price, step: item.step)
            materials.append(material)
            writes.append(.material(material))
        }

        // Projeyi kuran yönetici, hisse dağılımının tamamıyla ilk ortak olur.
        let founder = Partner(id: UUID(), projectId: project.id, name: user.name,
                              isFounder: true,
                              joinedAt: Date(),
                              sharePercent: 100, userUid: user.id)
        partners.append(founder)
        writes.append(.partner(founder))

        persist(writes, failureNote: "Proje")
        flash("Proje oluşturuldu")
        return project
    }

    // MARK: - Ortak hissesi (madde 20)

    /// Bir ortağın projedeki payı — dört rakam, hiçbiri saklanmaz.
    ///
    /// NEDEN TEK BİR "PAYIN ŞU KADAR" RAKAMI YOK:
    /// `netAmount` geliri TAHAKKUK esasıyla alıyor (satılan dairenin TAM bedeli,
    /// tahsil edilmemiş olsa da) ama gideri BUGÜNE KADAR girilmiş kayıtlardan
    /// topluyor. Maketten satışta para önce girer, inşaat maliyeti sonra çıkar;
    /// yarısı bitmiş bir projede tek satırlık "payın 7,2 M ₺" ortağa kasada
    /// olmayan ve bir kısmı daha harcanacak olan parayı "hakkın" diye söyler.
    /// Bu, madde 1'de "Net" etiketiyle kapatılan hatanın kişiselleşmiş hâli
    /// olurdu — orada rakam projeye aitti, burada doğrudan kişinin cebine.
    ///
    /// Onun yerine projenin ZATEN gösterdiği dört rakamın paya bölünmüş hâli
    /// yan yana duruyor; hangisinin kasada olduğu ekranda ayrı yazılı.
    struct PartnerShare {
        let percent: Int
        /// Satılan dairelerin bedelinden pay (tahakkuk).
        let sales: Kurus
        /// Girilen malzeme + diğer giderlerden pay.
        let cost: Kurus
        /// İkisinin farkı. "Kâr" DEĞİL: kalan inşaat maliyeti düşülmedi.
        let difference: Kurus
        /// Kasaya GİRMİŞ paradan pay.
        let collected: Kurus
        /// Henüz tahsil edilmemiş alacaktan pay.
        let outstanding: Kurus
    }

    /// Ortağın payı. Paylar TÜM ortaklar üzerinden birlikte bölünür ki
    /// toplamları proje rakamına birebir eşit kalsın (bkz. `Kurus.split`).
    /// Hisse tanımlı değilse (yeni katılan ortak %0 ile geliyor) `nil` döner —
    /// sıfırlarla dolu bir kart, tanımsız hisseyi "payın yok" diye gösterirdi.
    func share(of partner: Partner) -> PartnerShare? {
        guard partner.sharePercent > 0 else { return nil }
        let roster = partners(for: partner.projectId)
        guard let index = roster.firstIndex(where: { $0.id == partner.id }) else { return nil }
        let percents = roster.map(\.sharePercent)
        let pid = partner.projectId

        func slice(_ total: Kurus) -> Kurus { Kurus.split(total, byPercents: percents)[index] }

        return PartnerShare(percent: partner.sharePercent,
                            sales: slice(totalSales(for: pid)),
                            cost: slice(totalCost(for: pid)),
                            difference: slice(netAmount(for: pid)),
                            collected: slice(collectedAmount(for: pid)),
                            outstanding: slice(outstandingAmount(for: pid)))
    }

    /// Oturumu açan kişinin BU PROJEDEKİ ortak kaydı. Bağ `userUid` üzerinden:
    /// yönetici hisseyi tanımlamış ama kişi henüz katılmamış olabilir, o yüzden
    /// `Partner` kaydı üyelikten ayrı yaşıyor.
    func partnerRecord(in projectId: UUID, for user: User?) -> Partner? {
        guard let uid = user?.id else { return nil }
        return partners(for: projectId).first { $0.userUid == uid }
    }


    /// Bir ortağın hisse yüzdesini değiştirir (yalnızca yönetici).
    ///
    /// Bu yol AÇILANA KADAR `sharePercent` ölü veriydi: kurucuya sabit %100,
    /// davetle katılana %0 yazılıyordu ve değiştirecek ne ekran ne fonksiyon
    /// vardı. Yani gerçek bir projede davet edilen her ortak, düzeltemeyeceği
    /// bir "%0" görüyordu — pay hesabı yazılsaydı da herkesin payı 0 ₺ çıkardı.
    ///
    /// TOPLAM %100'Ü AŞAMAZ. Aşan bir dağılım, ortağa gerçekte var olmayan bir
    /// pay vaat etmek olurdu; bu uygulamada rakamın dürüstlüğü kapıda durur,
    /// ekranda uyarı olarak değil.
    ///
    /// Değişiklik denetim izine yazılır: ortağın payı, ortağın haberi olmadan
    /// sessizce küçültülebilecek bir şey değil.
    @discardableResult
    func updatePartnerShare(role: UserRole, partnerId: UUID, percent: Int) -> Bool {
        guard role == .admin else { return false }
        guard let index = partners.firstIndex(where: { $0.id == partnerId }) else { return false }
        let partner = partners[index]
        let clamped = max(0, min(100, percent))
        guard clamped != partner.sharePercent else { return true }

        let othersTotal = partners
            .filter { $0.projectId == partner.projectId && $0.id != partnerId }
            .reduce(0) { $0 + $1.sharePercent }
        guard othersTotal + clamped <= 100 else {
            flash("Toplam hisse %100'ü aşamaz · kalan %\(100 - othersTotal)")
            return false
        }

        partners[index].sharePercent = clamped
        var writes: [DocumentChange] = [.partner(partners[index])]
        writes += recordAudit(recordId: partnerId, projectId: partner.projectId,
                              subject: "\(partner.name) hissesi", action: .update,
                              changes: [.init(field: "Hisse",
                                              oldValue: "%\(partner.sharePercent)",
                                              newValue: "%\(clamped)")])
        persist(writes, failureNote: "Hisse")
        flash("Hisse güncellendi")
        return true
    }

    /// Bu projede henüz dağıtılmamış hisse yüzdesi.
    func unassignedSharePercent(for projectId: UUID) -> Int {
        100 - partners(for: projectId).reduce(0) { $0 + $1.sharePercent }
    }

    /// Yeni projelerde açılan standart malzeme kalemleri (mock verideki katalogla aynı).
    static let materialCatalog: [(code: String, name: String, subtitle: String, unit: String, price: Kurus, step: Double)] = [
        ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", .lira(28, 50), 500),
        ("C30", "Hazır Beton", "C30/37 pompalı", "m³", .lira(2_450), 50),
        ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", .lira(165), 50),
        ("TĞL", "Tuğla", "19luk yatay delikli", "adet", .lira(22), 1_000),
        ("EPS", "Strafor", "5 cm cephe levhası", "m²", .lira(96), 100),
        ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", .lira(6_800), 10),
        ("KUM", "Kum", "Yıkanmış dere kumu", "ton", .lira(950), 20),
        ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", .lira(42), 25),
        ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", .lira(210), 25),
    ]

    // MARK: Davet kodu

    /// Projeye 48 saat geçerli, tek kullanımlık davet kodu üretir.
    /// Aynı kod başka bir projede kullanımdaysa yeniden üretilir.
    func generateInviteCode(role: UserRole, projectId: UUID) {
        guard role == .admin,
              let index = projects.firstIndex(where: { $0.id == projectId }) else { return }

        var code = InviteCode.generate()
        let activeCodes = Set(projects.compactMap { $0.invite?.isUsable == true ? $0.invite?.code : nil })
        var attempts = 0
        while activeCodes.contains(code), attempts < 20 {
            code = InviteCode.generate()
            attempts += 1
        }
        projects[index].invite = Invite(code: code, createdAt: Date())

        guard let invites else {
            // Demo verisi: kod yalnızca projenin içinde yaşar.
            persist([.project(projects[index])], failureNote: "Davet kodu")
            return
        }

        // Firestore: `invites/{KOD}` otorite kaydı ile proje aynası TEK PARTİDE
        // yazılır. `persist` KULLANILMIYOR çünkü `invites` koleksiyonu
        // `DocumentChange`'in bilmediği bir yol — repository yalnızca proje
        // ağacını tanıyor ve davet o ağacın dışında (bilerek: kod okuma herkese
        // kapalı olmalı, proje belgesinin içinde olsa üyeler de görürdü).
        let projectId = projects[index].id
        let ownerUid = projects[index].ownerUid
        Task { [weak self] in
            guard let self else { return }
            do {
                // Sunucunun ürettiği kod kazanır: çakışma olursa servis yeniden
                // dener ve elimizdeki yerel kod geçersiz kalırdı.
                let serverCode = try await invites.createInvite(projectId: projectId,
                                                               ownerUid: ownerUid)
                if let i = self.projects.firstIndex(where: { $0.id == projectId }) {
                    self.projects[i].invite = Invite(code: serverCode, createdAt: Date())
                }
            } catch {
                #if DEBUG
                print("[invite] üretilemedi: \(error)")
                #endif
                // Yerel kodu geri al: ekranda kullanılamayacak bir kod
                // göstermek, kod göstermemekten kötü.
                if let i = self.projects.firstIndex(where: { $0.id == projectId }) {
                    self.projects[i].invite = nil
                }
                self.flash("Davet kodu üretilemedi")
            }
        }
    }

    /// Davet kodunu kullanır: kodu GERÇEK bir projeyle eşler, süresini ve tek
    /// kullanım kuralını denetler, kullanıcıyı o projenin ortağı yapar.
    /// Önceden 6 haneli her kod kabul ediliyor ve kod hiçbir projeye bağlanmıyordu.
    enum JoinResult: Equatable {
        case success(projectTitle: String)
        case notFound        // böyle bir davet yok
        case expired         // 48 saat dolmuş
        case alreadyUsed     // kod harcanmış
        case alreadyMember   // kullanıcı zaten bu projenin ortağı
    }

    /// Davet kodunu kullanır — hangi yoldan gideceğine BURADA karar verilir.
    ///
    /// Firestore devredeyse Cloud Function çağrılır: davet edilen kişi üyesi
    /// olmadığı projeyi okuyamadığı için kodu istemcide doğrulamak imkânsız ve
    /// `memberUids`'e yazma kurala göre yalnızca sahibe açık. Demo verisinde ise
    /// yerel mantık çalışır (aşağıdaki `redeemInvite`).
    ///
    /// Bu ayrımın ViewModel'de olması bilinçli: `JoinWithCodeView` hangi arka
    /// ucun devrede olduğunu bilmemeli, tek bir çağrı görmeli.
    func joinProject(code rawCode: String, user: User) async -> JoinResult {
        guard let invites else { return redeemInvite(code: rawCode, user: user) }

        do {
            let redemption = try await invites.redeem(code: InviteCode.sanitize(rawCode))
            // Sunucu üyeliği yazdı; ekranın onu görmesi için yeniden yükleme
            // şart — yeni proje yerel kopyada henüz yok.
            await refresh()
            return redemption.alreadyMember
                ? .alreadyMember
                : .success(projectTitle: redemption.projectTitle)
        } catch let error as InviteError {
            switch error {
            case .notFound, .badFormat, .notSignedIn: return .notFound
            case .expired:                            return .expired
            case .alreadyUsed:                        return .alreadyUsed
            case .inviteBroken, .network, .unknown:
                // Ayrı bir JoinResult durumu YOK; kullanıcıya gerçek nedeni
                // toast ile söylüyoruz, aksi halde "böyle bir kod yok" diyerek
                // yanlış yönlendirmiş olurduk.
                flash(error.errorDescription ?? "Projeye katılınamadı")
                return .notFound
            }
        } catch {
            flash("Projeye katılınamadı")
            return .notFound
        }
    }

    func redeemInvite(code rawCode: String, user: User) -> JoinResult {
        let code = InviteCode.sanitize(rawCode)
        guard let index = projects.firstIndex(where: { $0.invite?.code == code }) else {
            return .notFound
        }
        guard let invite = projects[index].invite else { return .notFound }
        if invite.isUsed { return .alreadyUsed }
        if invite.isExpired { return .expired }

        let project = projects[index]
        if project.memberUids.contains(user.id) {
            return .alreadyMember
        }

        // Kod harcanır — tek kullanımlık.
        projects[index].invite?.usedAt = Date()
        projects[index].invite?.usedByName = user.name
        // Üyelik izdüşümü — Partner kaydıyla BİRLİKTE yazılır. Firestore'da bu
        // ikisi tek transaction olacak: yarısı yazılan bir katılım, ya görünmeyen
        // bir ortak ya da hisse kaydı olmayan bir üye bırakırdı.
        projects[index].memberUids.append(user.id)

        // Hisse yüzdesi yönetici tarafından sonradan tanımlanır (Faz 3: ortak cari hesabı).
        let partner = Partner(id: UUID(), projectId: project.id, name: user.name,
                              isFounder: false,
                              joinedAt: Date(),
                              sharePercent: 0,
                              userUid: user.id)
        partners.append(partner)

        let activity = pushActivity(
            ActivityItem(id: UUID(), projectId: project.id, kind: .partnerJoined,
                         title: "\(user.name) projeye katıldı",
                         meta: "\(project.title) · davet kodu ile · salt okunur",
                         timestamp: Date()))
        persist([.project(projects[index]), .partner(partner), activity],
                failureNote: "Projeye katılma")
        return .success(projectTitle: project.title)
    }

    func copyInviteCode(_ raw: String) {
        UIPasteboard.general.string = InviteCode.formatted(raw)
        flash("Davet kodu kopyalandı")
    }

    func copyInviteLink(_ raw: String) {
        UIPasteboard.general.string = "https://" + InviteCode.link(raw)
        flash("Bağlantı kopyalandı")
    }

    /// WhatsApp ile davet paylaşımı; uygulama yoksa kullanıcı bilgilendirilir.
    func shareInviteViaWhatsApp(project: Project, raw: String) {
        let message = "\(project.title) projesini takip etmen için davet kodun: \(InviteCode.formatted(raw))\nhttps://\(InviteCode.link(raw))"
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "whatsapp://send?text=\(encoded)"),
              UIApplication.shared.canOpenURL(url) else {
            flash("WhatsApp bulunamadı")
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: Belge ve fotoğraf

    /// Yükleme sayfasından yeni belge ekler.
    func addDocument(role: UserRole, projectId: UUID, group: ProjectDocument.Group,
                     fileName: String, sizeMB: Double, versionNote: String, partnerVisible: Bool) {
        guard role == .admin else { return }
        let ext = (fileName as NSString).pathExtension.lowercased()
        let type: ProjectDocument.FileType = ext == "dwg" ? .dwg : (["jpg", "jpeg", "png", "heic"].contains(ext) ? .jpg : .pdf)
        let baseName = (fileName as NSString).deletingPathExtension
        let doc = ProjectDocument(id: UUID(), projectId: projectId, group: group,
                                  fileType: type,
                                  name: baseName.isEmpty ? fileName : baseName,
                                  versionText: versionNote.isEmpty ? "v1" : versionNote,
                                  sizeMB: max(0.1, sizeMB),
                                  date: Date(),
                                  partnerVisible: partnerVisible)
        documents.insert(doc, at: 0)
        persist([.document(doc)], failureNote: "Dosya")
        flash("Dosya yüklendi")
    }

    /// Daireye (küçültülmüş) görsel ekler — galeriden veya kameradan.
    func addApartmentPhotos(role: UserRole, apartmentId: UUID, images: [UIImage]) {
        guard role == .admin, !images.isEmpty else { return }
        guard let apartment = apartments.first(where: { $0.id == apartmentId }) else { return }
        let existing = photos(forApartment: apartmentId).count
        var writes: [DocumentChange] = []
        for (offset, image) in images.enumerated() {
            let photo = ApartmentPhoto(id: UUID(), projectId: apartment.projectId,
                                       apartmentId: apartmentId,
                                       label: "Görsel \(existing + offset + 1)",
                                       image: image)
            apartmentPhotos.append(photo)
            writes.append(.apartmentPhoto(photo))
            self.images?.cache(image, bucket: .apartmentPhotos,
                               projectId: apartment.projectId, id: photo.id)
            uploadImage(bucket: .apartmentPhotos, projectId: apartment.projectId, id: photo.id)
        }
        persist(writes, failureNote: "Görsel")
        flash(images.count == 1 ? "Görsel eklendi" : "\(images.count) görsel eklendi")
    }

    /// Daire görselini siler (yalnızca yönetici).
    func removeApartmentPhoto(role: UserRole, photoId: UUID) {
        guard role == .admin,
              let photo = apartmentPhotos.first(where: { $0.id == photoId }) else { return }
        apartmentPhotos.removeAll { $0.id == photoId }
        persist([.deleteApartmentPhoto(id: photoId, projectId: photo.projectId)],
                failureNote: "Görsel silme")
        // Bulut/disk temizliği en iyi çaba: belge silindi, kalan nesne yetim
        // olur — sızıntı değil, temizlik borcu. Bu yüzden persist'i beklemiyor.
        Task { [images] in
            await images?.delete(bucket: .apartmentPhotos, projectId: photo.projectId,
                                 id: photoId, storagePath: photo.storagePath)
        }
        flash("Görsel silindi")
    }

    /// Galeriden seçilen (küçültülmüş) şantiye fotoğraflarını bu haftaya ekler.
    /// Küçültme çağıran tarafta, arka planda yapılır — burada yalnızca hazır görseller beklenir.
    func addSitePhotos(role: UserRole, projectId: UUID, images: [UIImage]) {
        guard role == .admin, !images.isEmpty else { return }
        var writes: [DocumentChange] = []
        for image in images {
            let photo = SitePhoto(id: UUID(), projectId: projectId, date: Date(), image: image)
            sitePhotos.insert(photo, at: 0)
            writes.append(.sitePhoto(photo))
            // Önce DİSK (uygulama ölse de piksel durur), sonra bulut.
            self.images?.cache(image, bucket: .sitePhotos, projectId: projectId, id: photo.id)
            uploadImage(bucket: .sitePhotos, projectId: projectId, id: photo.id)
        }
        persist(writes, failureNote: "Fotoğraf")
        flash(images.count == 1 ? "Fotoğraf eklendi" : "\(images.count) fotoğraf eklendi")
    }

    // MARK: - Rapor (Ekran 10)

    enum ReportPeriod: String, CaseIterable {
        case buAy = "Bu ay"
        case ceyrek = "Çeyrek"
        case tumu = "Tümü"
    }

    struct ReportSummary {
        var title: String            // "3. ÇEYREK ÖZETİ"
        var soldCount: Int
        var salesTotal: Kurus
        var collectedTotal: Kurus
        var materialCost: Kurus
        var otherExpenses: Kurus
        /// Ciroya girmeyen ama raporda görünmesi gereken kalemler.
        /// Dönemden bağımsızdır: "şu an kaç daire rezerve / kat karşılığı" sorusunun
        /// cevabı geçmiş bir aya göre süzülemez.
        var reservedCount: Int = 0
        var depositTotal: Kurus = .zero  // Rezerve dairelerde bekleyen kapora
        var landOwnerCount: Int = 0
        var totalCost: Kurus { materialCost + otherExpenses }
        var net: Kurus { salesTotal - totalCost }
    }

    struct MonthBar: Identifiable {
        let id = UUID()
        var label: String            // "Şub"
        var value: Kurus             // Ay toplam satış
    }

    static let monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    /// Seçilen dönemin tarih aralığı. Metin ayrıştırma yerine takvim kullanılır;
    /// yıl sınırı, artık yıl ve ay uzunlukları Foundation'a bırakılır.
    private func dateRange(for period: ReportPeriod) -> (range: DateInterval?, title: String) {
        let calendar = Fmt.calendar
        let now = Date()

        switch period {
        case .buAy:
            let interval = calendar.dateInterval(of: .month, for: now)
            let name = Self.monthNames[calendar.component(.month, from: now) - 1]
            return (interval, name.uppercased(with: Fmt.locale) + " AYI ÖZETİ")

        case .ceyrek:
            let interval = calendar.dateInterval(of: .quarter, for: now)
            let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
            return (interval, "\(quarter). ÇEYREK ÖZETİ")

        case .tumu:
            return (nil, "PROJE GENELİ ÖZET")   // nil = tarih filtresi yok
        }
    }

    /// Seçilen dönemin özet tablosu.
    func reportSummary(for projectId: UUID, period: ReportPeriod) -> ReportSummary {
        let (range, title) = dateRange(for: period)

        let sold = apartments(for: projectId).filter { apartment in
            guard apartment.countsAsRevenue, let saleDate = apartment.saleDate else { return false }
            guard let range else { return true }   // "Tümü"
            return range.contains(saleDate)
        }
        let sales = sold.reduce(Kurus.zero) { $0 + $1.price }
        let projectApartments = apartments(for: projectId)

        // Dönem tahsilatı ÖDEME TARİHLERİNDEN gelir. Önceden dönemde satış tarihi
        // olan dairelerin ömür boyu `paidAmount` toplamıydı: aynı kartta malzeme
        // ve diğer giderler gerçekten o döneme aitken tahsilat başka bir pencereden
        // geliyordu. Bir çeyrekte imzalanan sözleşmenin sonraki çeyreklerde ödenen
        // taksitleri imza çeyreğine yazılıyor, o çeyrekte kasaya giren para ise
        // hiç görünmüyordu. Bu kart ortaklara PDF olarak dağıtılıyor.
        let revenueApartmentIds = Set(projectApartments.filter(\.countsAsRevenue).map(\.id))
        let collected: Kurus
        if let range {
            collected = payments
                .filter { revenueApartmentIds.contains($0.apartmentId) && range.contains($0.date) }
                .reduce(Kurus.zero) { $0 + $1.amount }
        } else {
            collected = projectApartments.filter(\.countsAsRevenue).reduce(Kurus.zero) { $0 + $1.paidAmount }
        }

        // Rezerve ve kat karşılığı daireler ciroya girmez ama raporda GÖRÜNMELİ:
        // aksi halde ortağa giden PDF'te "Satılan daire N adet" ya kat karşılığını
        // içerip yanlış olur ya da bekleyen kaporayı tamamen gizler.
        let reserved = projectApartments.filter { $0.status == .reserved }
        let landOwner = projectApartments.filter { $0.status == .landOwner }.count

        // Malzeme gideri:
        //  · "Tümü" → projenin birikmiş toplam maliyeti (kayıt öncesi alımlar dahil)
        //  · ay/çeyrek → yalnızca o dönemde KAYITLI giriş fişleri, her biri
        //    kendi tarihindeki dondurulmuş fiyatıyla (sonraki zamlar geçmişi değiştirmez)
        let cost: Kurus
        let materialIds = Set(materials(for: projectId).map(\.id))
        if let range {
            cost = materialLogs.reduce(Kurus.zero) { sum, log in
                guard log.type == .entry, materialIds.contains(log.materialId),
                      range.contains(log.date) else { return sum }
                return sum + Kurus.cost(quantity: log.amount, unitPrice: log.unitPrice)
            }
        } else {
            cost = totalMaterialCost(for: projectId)
        }

        // Malzeme dışı giderler de aynı dönem penceresine göre süzülür.
        let projectExpenses = expenses.filter { $0.projectId == projectId }
        let otherCost = projectExpenses.reduce(Kurus.zero) { sum, expense in
            guard let range else { return sum + expense.amount }
            return range.contains(expense.date) ? sum + expense.amount : sum
        }

        return ReportSummary(title: title, soldCount: sold.count,
                             salesTotal: sales, collectedTotal: collected,
                             materialCost: cost, otherExpenses: otherCost,
                             reservedCount: reserved.count,
                             depositTotal: reserved.reduce(Kurus.zero) { $0 + $1.paidAmount },
                             landOwnerCount: landOwner)
    }

    /// Son 6 tamamlanmış ayın satış çubukları — yıl sınırını takvim aşar.
    /// (Ocak'ta önceki yılın Tem–Ara'sını gösterir; grafik hiçbir ayda boş kalmaz.)
    func monthlySales(for projectId: UUID) -> [MonthBar] {
        let calendar = Fmt.calendar
        let sold = apartments(for: projectId).filter(\.countsAsRevenue)

        return (1...6).compactMap { offset in
            // 6 ay geriden bir önceki aya kadar
            guard let monthStart = calendar.date(byAdding: .month, value: offset - 7, to: Date()),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { return nil }

            let total = sold.reduce(Kurus.zero) { sum, apartment in
                guard let saleDate = apartment.saleDate, interval.contains(saleDate) else { return sum }
                return sum + apartment.price
            }
            let label = Self.monthNames[calendar.component(.month, from: monthStart) - 1]
            return MonthBar(label: label, value: total)
        }
    }

    // MARK: - Hareket akışı filtresi (Ekran 07)

    enum ActivityFilter: String, CaseIterable {
        case tumu = "Tümü"
        case malzeme = "Malzeme"
        case satis = "Satış"
        case gider = "Gider"
    }

    /// Hareket akışı — ÖNCE üyelik, sonra tür süzgeci.
    /// Üyelik burada uygulanmazsa dashboard'daki gizlilik sınırı bildirim
    /// zilinden delinir: ortak, görmediği projelerin alıcı adını ve tutarını
    /// bu ekranda okuyabilir.
    func activities(filter: ActivityFilter, for user: User?) -> [ActivityItem] {
        let allowed = Set(visibleProjects(for: user).map(\.id))
        // projectId'si olmayan (proje bağımsız) kayıt bugün yok; olursa gizlenir.
        let mine = activities.filter { $0.projectId.map(allowed.contains) ?? false }
        switch filter {
        case .tumu:    return mine
        case .malzeme: return mine.filter(\.isMaterial)
        case .satis:   return mine.filter(\.isSale)
        case .gider:   return mine.filter { $0.kind == .expense }
        }
    }

    func markActivityRead() {
        hasUnreadActivity = false
    }

    // MARK: - Toast

    /// 2,6 saniye görünen onay bildirimi.
    /// Kapatma işi doğrudan ana aktörde çalışır; @Published güncellemesi
    /// hiçbir zaman arka plandan yapılmaz (Swift 6 uyumlu).
    func flash(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }

    /// "12.500" / "28,50" gibi tr-TR girdilerini sayıya çevirir.
    /// Çok uzun rakam dizileri Double'da `inf`e taşar ve modele NaN sokar
    /// ("Ciro +∞ ₺", "Kalan NaN"); bu yüzden sonuç sonlu bir aralığa sıkıştırılır.
    static func parseNumber(_ text: String) -> Double {
        let normalized = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return 0 }
        return min(value, maxAmount)
    }

    /// Miktar girdisi (kg, m³, torba…). Para İÇİN KULLANILMAZ — bkz. parseMoney.
    static func parseQuantity(_ text: String) -> Double { parseNumber(text) }

    /// Para girdisini KURUŞA çevirir. Double'a hiç uğramaz: "8,17" gibi bir tutar
    /// `Int64(Double * 100)` yolundan 816 kuruş çıkardı (0,0817'nin ikilik
    /// gösterimi 8,17'nin biraz altında), string üzerinden 817 çıkar.
    ///
    /// Son ayraçtan sonra 1-2 hane varsa o ondalıktır; aksi halde tüm ayraçlar
    /// binlik kabul edilir. Bu, bugünkü davranışın düzeltilmiş hali: mevcut
    /// `parseNumber` TÜM noktaları koşulsuz siliyor, dolayısıyla cihaz dili
    /// İngilizce olan kullanıcının ondalık tuşundan gelen "28.50" bugün
    /// 2.850 ₺ olarak kaydediliyor — sessiz 100 kat hata.
    static func parseMoney(_ text: String) -> Kurus {
        let cleaned = text.filter { $0.isNumber || $0 == "," || $0 == "." }
        guard !cleaned.isEmpty else { return .zero }

        var whole = cleaned
        var fraction = ""
        if let lastSeparator = cleaned.lastIndex(where: { $0 == "," || $0 == "." }) {
            let tail = String(cleaned[cleaned.index(after: lastSeparator)...])
            // Ayraçtan sonra 1-2 rakam varsa ondalık, 3 ise binlik ("1.500").
            if tail.count <= 2, !tail.isEmpty, tail.allSatisfy(\.isNumber) {
                whole = String(cleaned[cleaned.startIndex..<lastSeparator])
                fraction = tail
            }
        }
        let digits = whole.filter(\.isNumber)
        guard let liraPart = Int64(digits.isEmpty ? "0" : digits) else { return .zero }

        // "5" → 50 kuruş, "05" → 5 kuruş.
        let kurusPart = Int64(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let total = liraPart.multipliedReportingOverflow(by: 100)
        guard !total.overflow else { return Kurus.kurus(maxKurus) }
        return Kurus.kurus(min(total.partialValue + kurusPart, maxKurus))
    }

    /// Tek bir miktarın kabul edilen üst sınırı (1 trilyon).
    static let maxAmount: Double = 1e12

    /// Tek bir tutarın üst sınırı: 1 trilyon ₺ = 1e14 kuruş (Int64.max ≈ 9,2e18).
    static let maxKurus: Int64 = 100_000_000_000_000
}
