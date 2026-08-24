import Foundation

// MARK: - Proje (Ada / Parsel)

/// İnşaatın yapım aşaması — dashboard kartındaki durum çipi.
enum ProjectPhase: String, Codable, CaseIterable {
    case temel = "Temel"
    case kabaInsaat = "Kaba inşaat"
    case inceIsler = "İnce işler"
    case teslim = "Teslim"
}

struct Project: Codable, Identifiable, Equatable {
    /// Kimlik iş verisinden TÜRETİLMEZ. Önceden "p1" / "kars309" gibi elle
    /// verilen dizelerdi; ada/parsel değişince kimlik de değişir, üstelik
    /// veritabanında doküman yolu olarak güvenli değildi.
    let id: UUID
    var blockNumber: String        // Ada
    var parcelNumber: String       // Parsel
    var district: String           // İlçe
    var city: String               // İl
    var floors: Int                // Kat sayısı
    var totalApartments: Int       // Toplam daire
    var phase: ProjectPhase        // Yapım aşaması
    var progress: Int              // İnşaat ilerlemesi (%)
    /// Projeyi kuran yöneticinin Firebase `uid`'i. Kimin hangi projeyi göreceği
    /// buradan belirlenir; güvenlik kuralının dayandığı alan da budur
    /// (`request.auth.uid == resource.data.ownerUid`).
    var ownerUid: String
    /// Projeyi görebilen TÜM kullanıcılar (sahip dahil).
    ///
    /// Ortağın "üyesi olduğum projeler" listesi ancak
    /// `whereField("memberUids", arrayContains: uid)` ile sorgulanabilir:
    /// güvenlik kuralı bir belgeyi doğrulayabilir ama sorguya KAPSAM VEREMEZ.
    /// Bu yüzden üyelik hem burada (yetki izdüşümü) hem `Partner` kaydında
    /// (hisse, ad, katılım tarihi — iş verisi) duruyor; ikisi farklı sorulara
    /// cevap veriyor ve tek senkron noktası davet akışıdır.
    var memberUids: [String]
    /// Dashboard sıralaması ve zorunlu bileşik indeks için.
    var createdAt: Date
    var invite: Invite?            // Üretilmiş aktif davet (kod + geçerlilik)
    var photoCount: Int            // Şantiye fotoğraf sayısı (arşiv dahil)

    /// Arşivlenme anı — `nil` ise proje aktif (madde 60).
    ///
    /// AYRI ALAN, `phase` DEĞİL: `phase` inşaatın aşaması (temel → teslim),
    /// arşiv ise projenin yaşam döngüsü durumu. Teslim edilmiş bir proje hâlâ
    /// takip ediliyor olabilir; arşivlenmiş bir proje ise artık takip
    /// edilmiyor. İkisini tek alana sıkıştırmak "teslim = arşiv" varsayımını
    /// koda gömerdi.
    ///
    /// SİLME DEĞİL ARŞİV: bitmiş bir projeyi silmek mali kayıt kaybı demek —
    /// müteahhidin geçmiş projelerinin rakamları vergi ve muhasebe için
    /// duruyor olmalı. Arşiv geri alınabilir; silme ayrı bir iş.
    var archivedAt: Date? = nil

    var isArchived: Bool { archivedAt != nil }

    /// Kart başlığı: "145 Ada / 2 Parsel"
    var title: String { "\(blockNumber) Ada / \(parcelNumber) Parsel" }

    /// Meta satırı: "Çayırova, Kocaeli · 5 Kat / 20 Daire"
    var meta: String { "\(district), \(city) · \(floors) Kat / \(totalApartments) Daire" }

    /// BU PROJEDEKİ rol. Global roldan farklı olabilir ve doğrusu budur:
    /// kişi kendi projesinde yönetici, davet edildiği projede ortaktır.
    ///
    /// Sunucu zaten böyle çalışıyor — güvenlik kuralı yazmayı `ownerUid`e,
    /// okumayı `memberUids`e bağlıyor. İstemcinin global rol kullanması iki
    /// modelin ayrışması demekti: davet edilen ortak `.admin` açıldığı için
    /// ekranda yönetici düğmelerini görüyor, basıyor ve yazma SUNUCUDA
    /// reddediliyordu — güvenlik açığı değil ama yalan bir arayüz.
    func role(for user: User?) -> UserRole {
        guard let user else { return .partner }
        // İNDİRME HER ZAMAN GEÇERLİ, YÜKSELTME ASLA.
        //
        // Proje rolü sahiplikten türetiliyor ve bu doğru: yetkinin kaynağı
        // `ownerUid`, kullanıcının kendi hakkında söylediği şey değil. Ama tek
        // yönlü bir istisna güvenli: kullanıcı kendini ORTAĞA indirdiyse
        // sahiplik onu yönetici yapmaz.
        //
        // Bu istisna olmadan geliştirmedeki "Ortak görünümü" önizlemesi
        // çalışamıyordu; kimliği değiştirerek çalıştırma denemesi ise ekranı
        // boşaltıp yanlış sonuca götürüyordu (bkz. `AppState.switchRole`).
        //
        // Ters yön KAPALI kalıyor ve kapalı kalmalı: `user.role == .admin`
        // olması tek başına yönetici yapmıyor, sahiplik yine de aranıyor.
        // Yani bu dal yalnızca yetkiyi AZALTABİLİR.
        guard user.role == .admin else { return .partner }
        return ownerUid == user.id ? .admin : .partner
    }

    /// %90 ve üzeri ilerleme yeşil (success) paletine geçer.
    var isNearComplete: Bool { progress >= 90 }
}
