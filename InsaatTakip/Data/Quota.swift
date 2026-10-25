import Foundation

// MARK: - Kota ve hak (madde 87)
//
// ÖDEME BURADA DEĞİL: satın alma `Subscriptions.swift` + `SubscriptionManager`
// (StoreKit 2, 25 Eki 2026). Bu dosya yalnızca SINIRIN kararını veriyor:
// sayaçlar, sınır sabitleri ve TEK boğaz noktası. Açılıp kapanan tek şey
// `Entitlement`.
//
// Tarihçe: sayaçlar ve boğaz StoreKit'ten ÖNCE kuruldu, çünkü ilk yayının
// sınırsızlığı geri alınamazdı — 12 proje açmış bir kullanıcıyı sonradan
// 3 proje sınırına sokmak ya sonsuza kadar muafiyet ya da güven kaybı demek.

/// Kullanıcının hakkı — kaynağı StoreKit (`EntitlementResolver`).
enum Entitlement: Equatable {
    /// Satın alınmış (ya da ücretsiz) paket. Sınırlar `Plan`dan okunuyor:
    /// fiyat ve sınır ayrı dursaydı birini değiştirip diğerini unutmak
    /// serbest olurdu.
    case plan(Plan)

    /// Hak HENÜZ BİLİNMİYOR: StoreKit açılışta cevap vermedi. Sınır YOK.
    ///
    /// NEDEN SINIRSIZ, NEDEN ÜCRETSİZ DEĞİL: `Transaction.currentEntitlements`
    /// cihazdaki imzalı kayıtları okuyor ve ağ istemiyor, yani bu durum
    /// açılışın ilk anından ibaret. O anı `.free` saymak, ücretli kullanıcının
    /// projelerini bir an "salt okunur" gösterir ve tam o an dokunduğu yazmayı
    /// reddederdi — ödeyen kişiyi cezalandıran bir yarış. Bu anda yapılabilecek
    /// en kötü şey, birkaç yüz milisaniyelik sınırsızlıktan daha pahalı.
    case resolving

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
        case .resolving: return nil
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
        case .resolving: return nil
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

    /// Arşivden çıkarma sınıra çarptığında söylenen cümle.
    ///
    /// Arşivden çıkarmak da bir projeyi aktif yapıyor; kotaya bakmasaydı
    /// "arşivle → yenisini aç → eskisini geri çıkar" döngüsü ücretsiz
    /// katmanda sınırsız aktif proje demekti.
    static func unarchiveLimitMessage(limit: Int) -> String {
        (limit == 1
            ? "Ücretsiz katmanda aynı anda 1 aktif proje tutulabilir."
            : "Paketinde aynı anda \(limit) aktif proje var.")
            + " Arşivden çıkarmak için önce başka bir projeyi arşivle; daha fazlası için paketlere bakabilirsin."
    }

    /// Sınır dolduğunda kullanıcıya söylenen cümle.
    ///
    /// NE YAPACAĞINI SÖYLÜYOR: "sınıra ulaştın" tek başına kişiyi çıkışsız
    /// bırakır. Arşivleme zaten var ve biten projeyi arşivlemek doğru
    /// davranış; cümle onu gösteriyor.
    static func limitMessage(limit: Int) -> String {
        // İKİ ÇIKIŞ DA YAZILI: arşivlemek bedava, paket ücretli. Yalnızca
        // paketi söylemek, kullanıcının zaten hakkı olan ücretsiz çözümü
        // saklamak olurdu; yalnızca arşivi söylemek ise satın almaya en
        // yakın anda ürünü susturuyordu. Sıra önemli — bedava olan önce.
        limit == 1
            ? "Ücretsiz katmanda aynı anda 1 aktif proje tutulabilir. Biten projeyi arşivlersen yenisini açabilirsin; daha fazlası için paketlere bakabilirsin."
            : "Paketinde aynı anda \(limit) aktif proje var. Biten projeyi arşivlersen yenisini açabilirsin; daha fazlası için paketlere bakabilirsin."
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
// YAZMA KİLİDİ (25 Eki 2026, kullanıcı kararı): arşivdeki proje salt okunur;
// sınırın üstünde kalan aktif projelerin en eskileri yazılabilir, fazlası salt
// okunur. Kapı `ProjectViewModel.writeBlock(for:)`. Okuma ve dışa aktarma
// hiçbir durumda kapanmıyor — yukarıdaki ilkenin uygulaması.
//
// DIŞ BİLİNMEYEN KAPANDI: dijital abonelik Türkiye mağazasında uygulama içi
// satın alma (IAP) ile satılıyor; dış ödeme bağlantısı kullanılmıyor, yani
// bölgeye göre değişen bağlantı kuralları bu ürüne uygulanmıyor.
