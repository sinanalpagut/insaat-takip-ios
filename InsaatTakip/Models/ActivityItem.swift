import Foundation

// MARK: - Hareket / Bildirim Akışı (Ekran 07)

struct ActivityItem: Codable, Identifiable, Equatable {
    /// Satır başındaki 28px rozetin türü.
    enum Kind: String, Codable {
        case materialIn     // ↓ giriş (yeşil)
        case materialOut    // ↑ çıkış (nötr)
        case sale           // ₺ satış (bakır)
        case partnerJoined  // ＋ ortak katıldı (bakır)
    }

    /// Akıştaki zaman grubu.
    enum Section: String, Codable, CaseIterable {
        case bugun = "Bugün"
        case dun = "Dün"
        case buHafta = "Bu Hafta"
    }

    let id: UUID
    var kind: Kind
    var title: String       // "Demir · 12.500 kg giriş"
    var meta: String        // "145 Ada / 2 Parsel · İrsaliye #4471"
    var timeText: String    // "09:24" / "Sal"
    var section: Section

    /// Filtre çipleri: Tümü / Malzeme / Satış.
    var isMaterial: Bool { kind == .materialIn || kind == .materialOut }
    var isSale: Bool { kind == .sale }
}

// MARK: - Şantiye Fotoğrafı (Ekran 09)

struct SitePhoto: Identifiable, Equatable {
    let id: UUID
    let projectId: String
    var dateText: String        // "05 Ağu"
    var isCurrentWeek: Bool     // Bu hafta: canlı yuva · Arşiv: dolu kutu
    var imageData: Data?        // Admin galeriden seçince dolar
}
