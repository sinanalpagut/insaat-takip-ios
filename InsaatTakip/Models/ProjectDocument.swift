import Foundation

// MARK: - Plan & Proje Dosyaları (Belgeler sekmesi)

struct ProjectDocument: Codable, Identifiable, Equatable {
    /// Belge grubu — hem liste bölümleri hem yükleme kategorileri.
    enum Group: String, Codable, CaseIterable {
        case mimari = "Mimari"
        case statik = "Statik"
        case ruhsat = "Ruhsat"
        case gorsel = "Görsel"
        case sozlesme = "Sözleşme"

        /// Liste bölüm başlığı.
        var sectionTitle: String {
            switch self {
            case .mimari:   return "Mimari Proje"
            case .statik:   return "Statik Proje"
            case .ruhsat:   return "Ruhsat & Resmî Evrak"
            case .gorsel:   return "Görseller"
            case .sozlesme: return "Sözleşmeler"
            }
        }
    }

    /// Dosya türü — 38px rozetin rengini belirler.
    enum FileType: String, Codable {
        case pdf = "PDF"
        case dwg = "DWG"
        case jpg = "JPG"
    }

    let id: UUID
    let projectId: String
    var group: Group
    var fileType: FileType
    var name: String            // "Vaziyet Planı"
    var versionText: String     // "v3" / "taslak"
    var sizeMB: Double          // 4.2
    var dateText: String        // "12 Oca 2026"
    var partnerVisible: Bool    // "Ortaklar görebilsin" anahtarı

    /// Satır alt metni: "v3 · 4,2 MB · 12 Oca 2026"
    var metaText: String {
        "\(versionText) · \(Fmt.megabytes(sizeMB)) · \(dateText)"
    }
}
