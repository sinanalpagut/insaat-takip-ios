import Foundation

// MARK: - Ortak (Partner)

struct Partner: Codable, Identifiable, Equatable {
    let id: UUID
    let projectId: String
    var name: String
    var isFounder: Bool         // Proje kurucusu (yönetici) mi?
    var joinedText: String      // "Katıldı · 12 Mar 2026" / "Proje kurucusu · 04 Oca 2026"
    var sharePercent: Int       // Hisse yüzdesi

    var initials: String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first }).uppercased(with: Fmt.locale)
    }
}

// MARK: - Davet Kodu

enum InviteCode {
    /// Görsel olarak karışabilen karakterler (I, O, S, 0, 1) alfabeden çıkarılmıştır.
    static let alphabet = Array("ABCDEFGHJKLMNPQRTUVWXYZ23456789")

    /// 6 haneli yeni kod üretir (ham, tiresiz): "X7B9Q2"
    static func generate() -> String {
        String((0..<6).map { _ in alphabet.randomElement()! })
    }

    /// "X7B9Q2" → "X7B-9Q2" görünümü.
    static func formatted(_ raw: String) -> String {
        guard raw.count == 6 else { return raw }
        let mid = raw.index(raw.startIndex, offsetBy: 3)
        return "\(raw[raw.startIndex..<mid])-\(raw[mid...])"
    }

    /// Davet bağlantısı.
    static func link(_ raw: String) -> String {
        "insaattakip.app/katil/\(formatted(raw))"
    }

    /// Kullanıcı girdisini normalize eder: büyük harf, yalnız harf/rakam, en çok 6 karakter.
    static func sanitize(_ input: String) -> String {
        let filtered = input.uppercased().filter { $0.isLetter || $0.isNumber }
        return String(filtered.prefix(6))
    }
}
