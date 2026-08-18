import Foundation

// MARK: - Gider (malzeme dışı maliyet kalemleri)
// İnşaat maliyeti yalnızca malzemeden ibaret değildir. İşçilik, taşeron
// hakedişi, arsa/kat karşılığı, ruhsat-harç-SGK, makine kirası ve yakıt
// buraya kaydedilir; olmadığında ortağa gösterilen "net" gerçeğin çok üzerinde
// kalıyordu ve müteahhit paralel bir Excel tutmak zorundaydı.

struct Expense: Codable, Identifiable, Equatable {

    /// Gider türü. Sahadaki konuşma diline yakın tutuldu.
    enum Category: String, Codable, CaseIterable, Identifiable {
        case iscilik = "İşçilik"
        case taseron = "Taşeron"
        case arsa = "Arsa / Kat karşılığı"
        case ruhsatHarc = "Ruhsat & Harç"
        case makine = "Makine / Ekipman"
        case yakit = "Yakıt / Ulaşım"
        case diger = "Diğer"

        var id: String { rawValue }

        /// Listede ve formda kullanılan kısa ad (çip metni).
        var shortName: String {
            switch self {
            case .arsa:       return "Arsa"
            case .ruhsatHarc: return "Ruhsat"
            case .makine:     return "Makine"
            case .yakit:      return "Yakıt"
            default:          return rawValue
            }
        }

        /// Satır başındaki simge.
        var icon: String {
            switch self {
            case .iscilik:    return "hammer.fill"
            case .taseron:    return "person.2.fill"
            case .arsa:       return "map.fill"
            case .ruhsatHarc: return "doc.badge.gearshape.fill"
            case .makine:     return "gearshape.2.fill"
            case .yakit:      return "fuelpump.fill"
            case .diger:      return "square.grid.2x2.fill"
            }
        }
    }

    let id: UUID
    let projectId: UUID
    var category: Category
    var amount: Kurus           // Ödenen tutar
    var date: Date              // Ödeme / hakediş tarihi — geçmiş tarih girilebilir
    var payee: String           // Kime ödendi: "Kalıpçı Ekibi", "Yılmaz Nakliyat"
    var note: String            // "3. hakediş", "Şubat SGK"
    var user: String            // Kaydı giren

    /// Fiş görselinin Storage yolu. DOLU olması, görselin buluta yazıldığının
    /// tek kanıtı — "yükleniyor" cihaza özgü bir durum ve belgeye YAZILMAZ
    /// (iki cihaz birbirinin durumunu ezerdi). Görselin kendisi burada değil:
    /// `projects/{projectId}/{kova}/{id}.jpg` yolunda duruyor.
    var receiptPath: String? = nil

    var dateText: String { Fmt.shortDate(date) }

    /// Satır alt metni: "Kalıpçı Ekibi · 3. hakediş" (boş olanlar atlanır)
    var detailText: String {
        [payee, note].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
