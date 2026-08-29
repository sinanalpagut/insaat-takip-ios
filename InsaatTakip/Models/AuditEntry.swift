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
        /// Kayıt OLUŞTURMA (madde 61 · daire ekleme). Yeni bir ham değer;
        /// eski belgelerde hiç geçmediği için geriye dönük uyumlu.
        case create = "eklendi"

        var icon: String {
            switch self {
            case .update: return "pencil"
            case .delete: return "trash"
            case .create: return "plus"
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
    /// İSTEMCİNİN yazdığı an — cihaz saatinden geliyor.
    ///
    /// Gösterimde ve sıralamada doğrudan KULLANILMIYOR; `trueDate` üzerinden
    /// geçiliyor. Gerekçesi orada.
    let date: Date

    /// SUNUCUNUN yazdığı an (madde 77).
    ///
    /// `FirestoreProjectRepository.stamped()` her yazmaya
    /// `FieldValue.serverTimestamp()` koyuyor ve güvenlik kuralı
    /// `updatedAt == request.time` diye ŞART KOŞUYOR — yani bu alan varsa
    /// doğrudur ve değiştirilemez. Yeni yazılan her kayıtta dolu; uygulama
    /// içi (bellek) kayıtlarda ve kural gelmeden önce yazılmış eski
    /// belgelerde nil.
    var updatedAt: Date? = nil

    /// GÖSTERİMDE VE SIRALAMADA KULLANILAN an.
    ///
    /// Sunucu damgası varsa o, yoksa istemcinin yazdığı. Denetim izinin tüm
    /// değeri tarihlerinde: cihaz saati yanlışsa ya da kasten geri alınmışsa
    /// `date` yalan söyler ve iz bir kanıt değil bir İDDİA olur. Madde 76 ile
    /// bu tarihler artık ORTAĞIN gördüğü bir ekranda.
    ///
    /// Yedek olarak `date`in kalması bilinçli: sunucu damgası gelmeden önce
    /// (yazma kuyruktayken) ekranın tarihsiz satır göstermesi, doğru olmayan
    /// bir tarihten daha kötü bir deneyim olurdu.
    var trueDate: Date { updatedAt ?? date }

    var dateText: String { Fmt.shortDate(trueDate) }

    /// "Miktar: 12.500 kg → 1.250 kg · Birim fiyat: 28,50 ₺ → 31,00 ₺"
    var summary: String {
        changes.map(\.text).joined(separator: " · ")
    }
}
