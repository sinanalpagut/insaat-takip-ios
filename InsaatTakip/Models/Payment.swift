import Foundation

// MARK: - Tahsilat (daire ödemesi)
// Malzeme tarafında her hareket fişiyle kayıtlıyken paranın geldiği tarafta
// tek bir toplam vardı: `paidAmount` üzerine yazılıyordu. Yönetici yeni ödemeyi
// eski toplama akıldan ekliyor, ödemenin tarihi/yöntemi/dekontu hiçbir yerde
// durmuyordu. Artık her tahsilat ayrı bir kayıt; toplam bunlardan TÜRETİLİR.

struct Payment: Codable, Identifiable, Equatable {

    /// Ödeme yöntemi — sahada sorulan ilk soru.
    enum Method: String, Codable, CaseIterable, Identifiable {
        case pesinat = "Peşinat"
        case taksit = "Taksit"
        case havale = "Havale / EFT"
        case nakit = "Nakit"
        case cek = "Çek"
        case kredi = "Banka kredisi"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .pesinat: return "flag.fill"
            case .taksit:  return "calendar"
            case .havale:  return "arrow.left.arrow.right"
            case .nakit:   return "banknote.fill"
            case .cek:     return "doc.text.fill"
            case .kredi:   return "building.columns.fill"
            }
        }
    }

    let id: UUID
    /// Firestore yolu için — bkz. MaterialLog.projectId.
    let projectId: UUID
    let apartmentId: UUID
    var amount: Kurus
    var date: Date
    var method: Method
    var note: String        // "3. taksit", "Konut kredisi kullanımı"
    var user: String

    var dateText: String { Fmt.shortDate(date) }

    /// Satır alt metni: "Taksit · 3. taksit · 12 Mar 2026"
    var detailText: String {
        [method.rawValue, note].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
