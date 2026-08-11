import Foundation

// MARK: - Malzeme ve Stok Hareketi

struct Material: Codable, Identifiable, Equatable {
    let id: String
    let projectId: String
    var code: String          // Rozet kodu: "Ø12", "C30", "ÇMT"…
    var name: String          // "Demir", "Hazır Beton"…
    var subtitle: String      // "Nervürlü inşaat demiri"
    var unit: String          // "kg", "m³", "torba", "adet", "m²", "ton"
    var unitPrice: Double     // Güncel/son alış birim fiyatı (₺) — yalnızca gösterim ve ön dolum
    var totalIn: Double       // Toplam giren
    var totalOut: Double      // Toplam kullanılan
    var step: Double          // Fiş formunda hızlı artış adımı

    /// Fiilen ödenen toplam tutar; her giriş kendi tarihindeki fiyatıyla eklenir.
    /// Hesaplanan (totalIn × güncel fiyat) yerine biriktirilen bir değerdir:
    /// aksi halde yeni bir fiyat girmek geçmişteki tüm stoğu yeniden fiyatlandırırdı.
    var accruedCost: Double

    /// Kalan stok.
    var currentStock: Double { totalIn - totalOut }

    /// Kalan / giren oranı (progress bar).
    var remainingFraction: Double { totalIn > 0 ? currentStock / totalIn : 0 }

    /// Toplam malzeme tutarı.
    var totalCost: Double { accruedCost }

    /// Kritik stok: kalan oranı eşiğin altına düşünce uyarı paletine geçer.
    static let criticalThreshold = 0.10
    var isCritical: Bool { remainingFraction < Material.criticalThreshold }
}

/// Malzeme giriş / çıkış kaydı.
struct MaterialLog: Codable, Identifiable, Equatable {
    enum LogType: String, Codable {
        case entry   // Giriş · Şantiyeye
        case exit    // Çıkış · Kullanım
    }

    let id: UUID
    let materialId: String
    var type: LogType
    var amount: Double
    /// Kayıt anındaki birim fiyat — dondurulur; sonraki fiyat değişiklikleri
    /// geçmiş dönem raporlarını değiştirmesin diye.
    var unitPrice: Double
    var dateText: String      // "28 Tem 2026"
    var note: String          // "İrsaliye #4471 · Yılmaz Yapı" / "5. kat perde donatısı"
    var user: String          // Kaydı giren kişi

    /// "+12.500 kg" / "−6.800 kg"
    func signedAmount(unit: String) -> String {
        (type == .entry ? "+" : "−") + Fmt.qty(amount, unit: unit)
    }
}
