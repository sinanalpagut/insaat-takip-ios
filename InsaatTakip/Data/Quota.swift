import Foundation

// MARK: - Kota ve hak (madde 87)
//
// BU DOSYA ÖDEME ALMIYOR. StoreKit yok ve bilerek yok (madde 87 · parça c).
// Burada olan şey daha küçük ve daha aceleci: SINIRIN DURACAĞI YERİ açmak.
//
// Gerekçe geri dönülemezlikte: StoreKit'i sonra yazabilirsin, ilk yayının
// SINIRSIZLIĞINI geri alamazsın. 12 proje açmış bir kullanıcıyı sonradan
// 3 proje sınırına sokmak ya sonsuza kadar muafiyet ya da güven kaybı demek.
// Bu yüzden sayaçlar, sınır sabitleri ve TEK boğaz noktası bugün var; açılıp
// kapanan tek şey `Entitlement`.

/// Kullanıcının hakkı — bugün tek bir yerden geliyor, yarın StoreKit'ten.
/// Kullanıcının hakkı — bugün tek bir yerden geliyor, yarın StoreKit'ten.
enum Entitlement: Equatable {
    /// Satın alınmış (ya da ücretsiz) paket. Sınırlar `Plan`dan okunuyor:
    /// fiyat ve sınır ayrı dursaydı birini değiştirip diğerini unutmak
    /// serbest olurdu.
    case plan(Plan)

    /// Yayın öncesi: sınır YOK.
    ///
    /// Bugün herkes bu haktadır çünkü ödeme alacak bir yol yok ve olmayan bir
    /// aboneliğin yokluğunu cezalandırmak, kullanıcıyı ürünü hiç
    /// kullanamayacağı bir kapıya çarptırmak olurdu. YAYINDAN ÖNCE bu değer
    /// `.free`e çevrilecek; değişecek tek satır `ProjectViewModel.entitlement`.
    case preLaunchUnlimited

    /// Kalıcı ücretsiz katman: 1 AKTİF proje, 2 davetli ortak.
    ///
    /// Deneme süresi DEĞİL, kalıcı. Bu uygulama veri girildikten SONRA değer
    /// üretiyor; 14 günlük deneme dolduğunda kullanıcı henüz güveni kurmamış
    /// oluyor ve elindeki tek şey yarım girilmiş bir şantiye kaydı.
    static let free = Entitlement.plan(.ucretsiz)

    /// Davet edilebilecek ortak sayısı. `nil` = sınırsız.
    var invitedPartnerLimit: Int? {
        switch self {
        case .plan(let plan):     return plan.invitedPartnerLimit
        case .preLaunchUnlimited: return nil
        }
    }

    /// Aynı anda kaç AKTİF proje tutulabilir. `nil` = sınırsız.
    ///
    /// ARŞİVLENMİŞ PROJE SAYILMIYOR ve bu, eksenin kendisi kadar önemli:
    /// inşaat yıllarca sürüyor, biten proje kayıtlarıyla birlikte duruyor
    /// (madde 60). Biten projeyi saymak, kullanıcıyı kendi geçmişini
    /// silmeye iterdi — uygulamanın var olma sebebinin tersi.
    var activeProjectLimit: Int? {
        switch self {
        case .plan(let plan):     return plan.activeProjectLimit
        case .preLaunchUnlimited: return nil
        }
    }
}

/// Kotanın kararı.
enum QuotaDecision: Equatable {
    case allowed
    /// Sınır dolu — kaç projeye izin verildiği yazılı, çünkü kullanıcıya
    /// söylenecek cümle bu sayıyı içeriyor.
    case wouldExceedProjects(limit: Int)
    /// Ücretsiz katmanın ortak sınırı dolu.
    case wouldExceedPartners(limit: Int)
}

/// Kotanın ölçtüğü sayılar.
///
/// BELGE VE FOTOĞRAF SAYAÇLARI BUGÜN SINIR UYGULAMIYOR ama ölçülüyor:
/// `storage.rules` dosya BAŞINA 4 MB / 50 MB sınırı koyuyor, SAYI sınırı
/// koymuyor — yani tek proje sınırsız belge ve fotoğraf tutabilir ve
/// maliyet oradan açık uçlu sızıyor. Sınırın nereye konacağı ancak gerçek
/// kullanım görüldükten sonra bilinir; ölçmeden konan bir sayı, kullanıcıyı
/// hiçbir maliyet gerekçesi olmadan durdururdu.
struct QuotaSnapshot: Equatable {
    var activeProjects: Int = 0
    var archivedProjects: Int = 0
    var documents: Int = 0
    var photos: Int = 0
}

enum Quota {

    /// Yeni proje açılabilir mi?
    ///
    /// TEK BOĞAZ NOKTASI. Sınır bir gün gerçekten açıldığında değişecek yer
    /// burası olsun diye `addProject` bunu çağırıyor; her çağrı yerine ayrı
    /// koşul yazılsaydı, sınırın uygulanmadığı bir yol kalması an meselesiydi
    /// (bu kod tabanı aynı dersi `ownerWrite` ile bir kez öğrendi).
    static func canCreateProject(_ snapshot: QuotaSnapshot,
                                 entitlement: Entitlement) -> QuotaDecision {
        guard let limit = entitlement.activeProjectLimit else { return .allowed }
        return snapshot.activeProjects < limit ? .allowed : .wouldExceedProjects(limit: limit)
    }

    /// Yeni ortak davet edilebilir mi?
    ///
    /// SAYILAN ŞEY DAVET EDİLEN ORTAKLAR, kurucu DEĞİL: proje kurucusunun
    /// kendi `Partner` kaydı da listede duruyor ve onu saymak, ücretsiz
    /// katmanda ilan edilen "2 ortak"ı sessizce 1'e indirirdi.
    static func canInvitePartner(invitedCount: Int,
                                 entitlement: Entitlement) -> QuotaDecision {
        guard let limit = entitlement.invitedPartnerLimit else { return .allowed }
        return invitedCount < limit ? .allowed : .wouldExceedPartners(limit: limit)
    }

    /// Ortak sınırı dolduğunda söylenen cümle. Kullanıcıya NE YAPACAĞINI
    /// söylüyor: burada çıkış yolu arşivlemek değil, paketi yükseltmek.
    static func partnerLimitMessage(limit: Int) -> String {
        "Ücretsiz katmanda \(limit) ortak davet edilebilir. Daha fazlası için paketi yükselt."
    }

    /// Sınır dolduğunda kullanıcıya söylenen cümle.
    ///
    /// NE YAPACAĞINI SÖYLÜYOR: "sınıra ulaştın" tek başına kişiyi çıkışsız
    /// bırakır. Arşivleme zaten var ve biten projeyi arşivlemek doğru
    /// davranış; cümle onu gösteriyor.
    static func limitMessage(limit: Int) -> String {
        limit == 1
            ? "Ücretsiz katmanda aynı anda 1 aktif proje tutulabilir. Biten projeyi arşivlersen yenisini açabilirsin."
            : "Paketinde aynı anda \(limit) aktif proje var. Biten projeyi arşivlersen yenisini açabilirsin."
    }
}

// MARK: - Yayın öncesi karar notları
//
// ABONELİK YAZMAYI KİLİTLER, OKUMAYI ASLA. Aboneliği biten müteahhidi kendi
// mali kaydından dışarıda bırakmak kabul edilemez: veri onun, uygulama
// yalnızca tutuyor. Aynı ölçüt uygulama kilidinde de kullanıldı
// (`AppLock.unlock` biyometri değerlendirilemiyorsa AÇILIYOR) — kullanıcıyı
// kendi verisinden ayıran bir hata, koruduğu şeyden daha pahalı.
//
// SINIR KURALDA UYGULANMIYOR, İSTEMCİDE. Firestore kuralında proje sayısı
// denetlemek her yazmada bir `get()` demek: yazma başına ek okuma, ek ücret
// ve YENİ BİR KIRILMA YOLU — hak belgesi okunamadığı an TÜM yazmalar
// reddedilirdi. Kuralın işi yetki (kim yazabilir), kotanın işi ticaret;
// ikisini aynı yere koymak, ticari bir hatanın veri kaybı gibi görünmesine
// yol açar.
//
// DOĞRULANACAK TEK DIŞ BİLİNMEYEN (bundan önce StoreKit'e tek satır kod
// yazılmamalı): Apple'ın uygulama içi satın alma zorunluluğu ve dış ödeme
// bağlantısı kuralı bölgeye göre değişiyor ve son yıllarda değişti.
