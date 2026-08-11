import Foundation

// MARK: - tr-TR Sayı / Para Formatlayıcıları
// Binlik ayracı ".", ondalık ","; para birimi ₺ sonda.
// Kompakt gösterim tasarımdaki gibi: 42.650.000 → "42,65 M ₺", 204.600 → "205 B ₺".

enum Fmt {
    static let locale = Locale(identifier: "tr_TR")

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static let decimal2: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// 48000 → "48.000". Sonlu olmayan değerler ekrana "NaN"/"∞" olarak
    /// sızmasın diye tire ile gösterilir (Int(nan) dönüşümü de çökertirdi).
    static func qty(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return grouped.string(from: NSNumber(value: value.rounded())) ?? "—"
    }

    /// 48000 kg → "48.000 kg"
    static func qty(_ value: Double, unit: String) -> String {
        "\(qty(value)) \(unit)"
    }

    /// 356250 → "356.250 ₺"
    static func money(_ value: Double) -> String {
        "\(qty(value)) ₺"
    }

    /// 42650000 → "42,65 M ₺" · 204600 → "205 B ₺" · 950 → "950 ₺"
    static func compactMoney(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        let v = abs(value)
        let sign = value < 0 ? "−" : ""
        if v >= 1_000_000 {
            return sign + (decimal2.string(from: NSNumber(value: v / 1_000_000)) ?? "") + " M ₺"
        }
        if v >= 1_000 {
            return sign + "\(Int((v / 1_000).rounded())) B ₺"
        }
        return sign + money(v)
    }

    /// Milyon cinsinden tek ondalık: 3150000 → "3,1" (rapor grafiği).
    static func millionsShort(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: value / 1_000_000)) ?? ""
    }

    /// Birim fiyat, listede tam sayıya yuvarlanır: 28,5 → "29 ₺/kg".
    static func unitPriceRounded(_ price: Double, unit: String) -> String {
        "\(qty(price.rounded())) ₺/\(unit)"
    }

    /// Birim fiyat, detayda hassas: 28,5 → "28,50 ₺/kg" · 2450 → "2.450 ₺/m³".
    static func unitPriceExact(_ price: Double, unit: String) -> String {
        if price == price.rounded() {
            return "\(qty(price)) ₺/\(unit)"
        }
        return "\(decimal2.string(from: NSNumber(value: price)) ?? "") ₺/\(unit)"
    }

    /// "10 Ağu 2026" biçiminde Türkçe kısa tarih.
    static func shortDate(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    /// "09:24" biçiminde saat.
    static func clock(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// MB gösterimi: 4.2 → "4,2 MB" · 0.8 → "0,8 MB"
    static func megabytes(_ mb: Double) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = mb == mb.rounded() ? 0 : 1
        f.maximumFractionDigits = 1
        return (f.string(from: NSNumber(value: mb)) ?? "") + " MB"
    }
}
