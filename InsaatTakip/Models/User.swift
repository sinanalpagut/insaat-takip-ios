import Foundation

// MARK: - Kullanıcı ve Rol

/// Uygulamadaki iki rol: veri giren tek Yönetici ve salt-okunur Ortak.
enum UserRole: String, Codable {
    case admin
    case partner

    /// Proje detay başlığındaki rol çipi metni.
    var chipText: String {
        switch self {
        case .admin:   return "Yönetici"
        case .partner: return "İzleyici"
        }
    }
}

struct User: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var role: UserRole

    /// Avatar için baş harfler ("Mehmet Kılıç" → "MK").
    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased(with: Fmt.locale)
    }

    static let admin = User(id: UUID(), name: "Mehmet Kılıç", role: .admin)
    static let partner = User(id: UUID(), name: "Serkan Aydın", role: .partner)
}
