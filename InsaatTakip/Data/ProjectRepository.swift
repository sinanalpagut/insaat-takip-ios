import Foundation

// MARK: - Veri katmanı sözleşmesi
//
// Bugün tek bir kaynak var (bellek içi demo verisi), ama Faz 2'de Firestore
// gelecek ve o gün TÜM yazma işlemleri ağ üzerinden, `async throws` olarak
// yapılacak. Bu protokol o değişimi ProjectViewModel'in İÇİNDE tutmak için var:
// view'lar ViewModel'i senkron çağırmaya devam eder, ViewModel de kalıcılığı
// buraya devreder. Aksi halde Faz 2'de 22 view dosyası birden değişecekti.
//
// Burada İŞ KURALI YOKTUR. Yetki kapısı (role == .admin), stok kontrolü,
// türetilen alan hesapları, denetim izi ve kullanıcı mesajları ViewModel'de
// kalır; repository yalnızca "şu kayıtları yaz" der.

/// Uygulamanın kalıcı verisinin tek seferlik tam kopyası.
/// `receiptImages` BİLİNÇLİ olarak yok: `[UUID: UIImage]` bir dosya deposu işidir,
/// doküman değil — Faz 2'de Storage'a ayrı bir yoldan gidecek.
struct DataSnapshot {
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
}

/// Tek bir kayıt yazması. Firestore'daki bir doküman işlemine birebir karşılık gelir.
///
/// Model taşıyan case'ler UPSERT'tir: kimlik modelin `id`'sidir, bu yüzden "ekle"
/// ile "güncelle" ayrı case olmak zorunda değil — Firestore'da da değil.
enum DocumentChange {
    case project(Project)
    case material(Material)
    case materialLog(MaterialLog)
    case apartment(Apartment)
    case partner(Partner)
    case document(ProjectDocument)
    case activity(ActivityItem)
    case sitePhoto(SitePhoto)
    case expense(Expense)
    case payment(Payment)
    case apartmentPhoto(ApartmentPhoto)
    case audit(AuditEntry)

    case deleteMaterialLog(id: UUID)
    case deleteExpense(id: UUID)
    case deletePayment(id: UUID)
    case deleteApartmentPhoto(id: UUID)

    /// Satış iptalinde o dairenin TÜM tahsilatları birlikte düşer. Kaç kayıt
    /// olduğu çağrı anında bilinmediği için tek tek kimlik yerine kuralı taşıyoruz;
    /// Firestore'da bu bir sorgu + toplu silme olacak.
    case deletePayments(apartmentId: UUID)
}

/// @MainActor bilinçli: `SitePhoto` ve `ApartmentPhoto` birer `UIImage` taşıdığı
/// için `Sendable` değiller. Protokolü ana aktörde tutmak, iOS 16 hedefinde
/// eşzamanlılık uyarılarına boğulmadan doğru sınırı çizmemizi sağlıyor. Faz 2'de
/// ağ işi Firestore uygulamasının İÇİNDEKİ bir actor'e iner; dışa bakan yüz
/// ana aktörde kalır, yani bu satır değişmez.
@MainActor
protocol ProjectRepository {

    /// Ağ gerektirmeyen anlık kopya; ViewModel'in init'inde çağrılır.
    /// Ekranın bir kare bile boş görünmemesini garanti eder — "kullanıcı hiçbir
    /// fark görmemeli" kuralının teknik dayanağı budur. Faz 2'de Firestore'un
    /// disk önbelleğini döndürecek (ilk açılışta boş) ve `load()` tamamlayacak.
    func cachedSnapshot() -> DataSnapshot

    /// Yetkili kaynaktan tam yükleme. Faz 1'de çağrılmıyor: bellek içi kaynakta
    /// `cachedSnapshot()` zaten güncel veriyi veriyor ve ekranı gereksiz yere
    /// yeniden kurmanın bir faydası yok. İmzanın bugünden doğru olması, Faz 2'de
    /// RootView'a eklenecek tek bir `.task` dışında hiçbir şeyin değişmemesi için.
    func load() async throws -> DataSnapshot

    /// TEK kullanıcı eyleminin ürettiği yazmaların tamamı; sıra korunur ve dizi
    /// TEK ATOMİK BİRİM sayılır (Firestore'da `WriteBatch`).
    /// Bu yüzden ViewModel bir eylemin bütün yazmalarını tek çağrıda verir:
    /// örneğin satış iptali daireyi, silinen tahsilatları, denetim kaydını ve
    /// hareket akışı satırını birlikte gönderir. Yarısı yazılıp yarısı yazılmayan
    /// bir iptal, ortağa tutarsız bir tablo gösterirdi.
    func apply(_ changes: [DocumentChange]) async throws
}
