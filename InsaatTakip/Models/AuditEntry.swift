import Foundation

// MARK: - Denetim İzi (değişiklik kaydı)
// Uygulamanın tek iddiası şeffaflık; ama kayıt düzenlenebilir olduğu anda
// "yönetici rakamı sonradan değiştirdi mi?" sorusunun cevabı yoksa iddia
// doğrulanabilir olmaktan çıkar. Bu yüzden düzenleme ve silme yeteneği
// değişiklik kaydıyla BİRLİKTE geliyor: her düzeltme eski → yeni değeriyle,
// kimin ne zaman yaptığıyla defterde kalır ve ortağa da görünür.

struct AuditEntry: Codable, Identifiable, Equatable {

    enum Action: String, Codable {
        case update = "düzenlendi"
        case delete = "silindi"

        var icon: String {
            switch self {
            case .update: return "pencil"
            case .delete: return "trash"
            }
        }
    }

    /// Tek bir alanın eski → yeni değeri. Sayı/tarih değil metin tutulur:
    /// kullanıcıya ne gösterildiyse denetimde de o görünsün.
    struct Change: Codable, Equatable, Identifiable {
        let field: String       // "Miktar", "Birim fiyat", "Tarih"…
        let oldValue: String
        let newValue: String

        var id: String { field }
        var text: String { "\(field): \(oldValue) → \(newValue)" }
    }

    let id: UUID
    /// Değişen kaydın kimliği (fiş, gider, tahsilat, satış…) — geçmişi
    /// kaydın kendi ekranında göstermek için.
    let recordId: UUID
    let projectId: UUID
    let subject: String         // "Demir · İrsaliye #4471"
    let action: Action
    let changes: [Change]       // silmede tek satır: kaydın özeti
    let user: String
    let date: Date

    var dateText: String { Fmt.shortDate(date) }

    /// "Miktar: 12.500 kg → 1.250 kg · Birim fiyat: 28,50 ₺ → 31,00 ₺"
    var summary: String {
        changes.map(\.text).joined(separator: " · ")
    }
}
