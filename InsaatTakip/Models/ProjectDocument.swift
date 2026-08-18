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
    let projectId: UUID
    var group: Group
    var fileType: FileType
    var name: String            // "Vaziyet Planı"
    var versionText: String     // "v3" / "taslak"
    var sizeMB: Double          // 4.2
    var date: Date              // Yükleme / evrak tarihi
    var partnerVisible: Bool    // "Ortaklar görebilsin" anahtarı

    /// Dosya uzantısı ("pdf", "dwg", "xlsx"…). Nokta YOK, küçük harf.
    ///
    /// Önce atılıyordu: `addDocument` adı `deletingPathExtension` ile kesiyor
    /// ve geriye yalnızca üç kutulu `fileType` rozeti kalıyordu. Rozet gerçek
    /// türü taşımıyor — bilinmeyen her uzantı `.pdf` sayılıyor, yani bir
    /// `.xlsx` PDF olarak etiketleniyordu. Uzantı ÖNİZLEME için şart:
    /// QuickLook dosyayı adından tanıyor, indirilen bayt geçici dosyaya bu
    /// uzantıyla yazılmadan açılamıyor.
    var fileExtension: String = ""

    /// MIME türü — Storage'a metadata olarak gidiyor ve kural bunu görüyor.
    /// Bilinmiyorsa `application/octet-stream`.
    var contentType: String = "application/octet-stream"

    /// Belgenin Storage yolu. DOLU olması, baytın buluta yazıldığının tek
    /// kanıtı — görsellerdeki `storagePath` ile aynı sözleşme: "yükleniyor"
    /// cihaza özgü bir durum ve belgeye YAZILMAZ, yoksa iki cihaz birbirinin
    /// durumunu ezer.
    ///
    /// Nesne adı belgenin KİMLİĞİ, uzantı içermiyor: `storage.rules` kardeş
    /// Firestore belgesini ancak kimliği yoldan çözebilirse okuyabiliyor
    /// (`partnerVisible` kontrolü buna dayanıyor).
    var storagePath: String? = nil

    /// Ekranda ve paylaşımda görünecek tam dosya adı: "Vaziyet Planı.pdf".
    var fullFileName: String {
        fileExtension.isEmpty ? name : "\(name).\(fileExtension)"
    }

    var dateText: String { Fmt.shortDate(date) }

    /// Satır alt metni: "v3 · 4,2 MB · 12 Oca 2026"
    var metaText: String {
        "\(versionText) · \(Fmt.megabytes(sizeMB)) · \(dateText)"
    }
}
