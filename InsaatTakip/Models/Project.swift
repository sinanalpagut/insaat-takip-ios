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

    /// Kart başlığı: "145 Ada / 2 Parsel"
    var title: String { "\(blockNumber) Ada / \(parcelNumber) Parsel" }

    /// Meta satırı: "Çayırova, Kocaeli · 5 Kat / 20 Daire"
    var meta: String { "\(district), \(city) · \(floors) Kat / \(totalApartments) Daire" }

    /// %90 ve üzeri ilerleme yeşil (success) paletine geçer.
    var isNearComplete: Bool { progress >= 90 }
}
