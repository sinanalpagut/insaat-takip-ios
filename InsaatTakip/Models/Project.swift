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
    let id: String
    var blockNumber: String        // Ada
    var parcelNumber: String       // Parsel
    var district: String           // İlçe
    var city: String               // İl
    var floors: Int                // Kat sayısı
    var totalApartments: Int       // Toplam daire
    var phase: ProjectPhase        // Yapım aşaması
    var progress: Int              // İnşaat ilerlemesi (%)
    var inviteCode: String?        // Üretilmiş aktif davet kodu
    var photoCount: Int            // Şantiye fotoğraf sayısı (arşiv dahil)

    /// Kart başlığı: "145 Ada / 2 Parsel"
    var title: String { "\(blockNumber) Ada / \(parcelNumber) Parsel" }

    /// Meta satırı: "Çayırova, Kocaeli · 5 Kat / 20 Daire"
    var meta: String { "\(district), \(city) · \(floors) Kat / \(totalApartments) Daire" }

    /// %90 ve üzeri ilerleme yeşil (success) paletine geçer.
    var isNearComplete: Bool { progress >= 90 }
}
