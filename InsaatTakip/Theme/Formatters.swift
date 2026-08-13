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

    // MARK: - Para (kuruş)
    // Ekranda kuruş GÖSTERİLMEZ: uygulamanın hiçbir yerinde kuruşlu rakam yoktu,
    // göç bunu değiştirmiyor. Kuruş yalnızca hesabın içinde yaşar, gösterimde
    // tam liraya yuvarlanır.

    /// 356250000 kuruş → "3.562.500 ₺"
    static func money(_ value: Kurus) -> String {
        "\(qty((Double(value.raw) / 100).rounded())) ₺"
    }

    /// 4265000000 kuruş → "42,65 M ₺" · 20460000 → "205 B ₺" · 0 → "0 ₺"
    /// Eşikler KURUŞ cinsinden yazılır; lira eşiği bırakılsaydı sessizce 100 kat
    /// sapardı ve her rakam "M ₺" ölçeğine kayardı.
    static func compactMoney(_ value: Kurus) -> String {
        let v = abs(value.raw)
        let sign = value.raw < 0 ? "−" : ""
        if v >= 100_000_000 {          // 1.000.000 ₺
            return sign + (decimal2.string(from: NSNumber(value: Double(v) / 100_000_000)) ?? "") + " M ₺"
        }
        if v >= 100_000 {              // 1.000 ₺
            return sign + "\(Int((Double(v) / 100_000).rounded())) B ₺"
        }
        return sign + money(Kurus.kurus(v))
    }

    /// Milyon cinsinden tek ondalık: 315000000 kuruş → "3,1" (rapor grafiği).
    static func millionsShort(_ value: Kurus) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: Double(value.raw) / 100_000_000)) ?? ""
    }

    /// Birim fiyat, listede tam sayıya yuvarlanır: 2850 kuruş → "29 ₺/kg".
    static func unitPriceRounded(_ price: Kurus, unit: String) -> String {
        "\(qty((Double(price.raw) / 100).rounded())) ₺/\(unit)"
    }

    /// Birim fiyat, detayda hassas: 2850 kuruş → "28,50 ₺/kg" · 245000 → "2.450 ₺/m³".
    static func unitPriceExact(_ price: Kurus, unit: String) -> String {
        if price.raw % 100 == 0 {
            return "\(qty(Double(price.raw) / 100)) ₺/\(unit)"
        }
        return "\(decimal2.string(from: NSNumber(value: Double(price.raw) / 100)) ?? "") ₺/\(unit)"
    }

    /// Para değerini FORMA geri yazmak için: "3.850.000" · "28,50".
    /// `qty` kullanılamaz — o `rounded()` uygulayıp ondalığı atıyor, yani
    /// 28,50 ₺'lik bir birim fiyat forma "29" olarak dolar ve kaydedilince
    /// gerçekten 29 ₺ olurdu.
    static func moneyText(_ value: Kurus) -> String {
        if value.raw % 100 == 0 {
            return qty(Double(value.raw) / 100)
        }
        return decimal2.string(from: NSNumber(value: Double(value.raw) / 100)) ?? ""
    }

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

    /// Uygulamanın her yerinde kullanılan takvim (tr-TR, pazartesi haftanın ilk günü).
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.firstWeekday = 2   // Pazartesi
        return c
    }()

    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.dateFormat = pattern
        return f
    }

    /// "10 Ağu 2026" biçiminde Türkçe kısa tarih.
    static func shortDate(_ date: Date = Date()) -> String {
        formatter("d MMM yyyy").string(from: date)
    }

    /// "10 Ağu" — yıl olmadan (şantiye fotoğrafı, aynı yıl içindeki belgeler).
    static func dayMonth(_ date: Date) -> String {
        formatter("d MMM").string(from: date)
    }

    /// "09:24" biçiminde saat.
    static func clock(_ date: Date = Date()) -> String {
        formatter("HH:mm").string(from: date)
    }

    /// Hareket akışındaki zaman etiketi: bugün "09:24", dün "Dün",
    /// bu hafta "Sal", daha eski "12 Mar".
    static func relativeTime(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return clock(date) }
        if calendar.isDateInYesterday(date) { return "Dün" }
        if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            return formatter("EEE").string(from: date)   // "Sal"
        }
        return dayMonth(date)
    }

    /// Belirli bir günü Date olarak üretir (mock veri ve testler için).
    static func makeDate(_ day: Int, _ month: Int, _ year: Int,
                         hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    /// Bugünden geriye/ileriye gün kaydırır (mock verideki "bugün", "dün" kayıtları).
    static func daysAgo(_ days: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let base = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
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
