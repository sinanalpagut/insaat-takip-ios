import Foundation

// MARK: - Ortak (Partner)

struct Partner: Codable, Identifiable, Equatable {
    let id: UUID
    let projectId: String
    var name: String
    var isFounder: Bool         // Proje kurucusu (yönetici) mi?
    var joinedAt: Date          // Katılım / kuruluş tarihi
    var sharePercent: Int       // Hisse yüzdesi

    /// "Katıldı · 12 Mar 2026" / "Proje kurucusu · 04 Oca 2026"
    var joinedText: String {
        "\(isFounder ? "Proje kurucusu" : "Katıldı") · \(Fmt.shortDate(joinedAt))"
    }
    /// Uygulamaya giren hesap. nil = hisse tanımlı ama kişi henüz katılmamış.
    /// Ortağın hangi projeleri görebileceği bu bağdan çözülür.
    var userId: UUID?

    var initials: String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first }).uppercased(with: Fmt.locale)
    }
}

// MARK: - Davet

/// Projeye özel davet. Tasarımda "48 saat geçerli · tek ortak için" yazıyordu
/// ama kod bunu uygulamıyordu; artık geçerlilik ve tek kullanım burada tutulur.
struct Invite: Codable, Equatable {
    var code: String            // ham 6 hane (tiresiz)
    var createdAt: Date
    var usedAt: Date?           // dolu ise kod harcanmış
    var usedByName: String?     // kodu kullanan ortağın adı

    static let validHours = 48

    var expiresAt: Date {
        createdAt.addingTimeInterval(TimeInterval(Invite.validHours * 3600))
    }

    var isExpired: Bool { Date() >= expiresAt }
    var isUsed: Bool { usedAt != nil }
    var isUsable: Bool { !isUsed && !isExpired }

    /// "48 saat geçerli · tek ortak için" / "Kullanıldı · Ayşe Tuna" / "Süresi doldu"
    var statusText: String {
        if let usedByName { return "Kullanıldı · \(usedByName)" }
        if isUsed { return "Kullanıldı" }
        if isExpired { return "Süresi doldu · yeni kod üret" }

        let remaining = Int(expiresAt.timeIntervalSinceNow / 3600)
        if remaining >= 1 { return "\(remaining) saat geçerli · tek ortak için" }
        let minutes = max(1, Int(expiresAt.timeIntervalSinceNow / 60))
        return "\(minutes) dakika geçerli · tek ortak için"
    }
}

// MARK: - Davet Kodu üretimi

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
