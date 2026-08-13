import Foundation

// MARK: - Kullanıcı ve Rol

/// Uygulamadaki iki rol: veri giren tek Yönetici ve salt-okunur Ortak.
enum UserRole: String, Codable {
    case admin
    case partner

    /// Proje detay başlığındaki rol çipi metni.
    var chipText: String {
        switch self {
        case .admin:   return "Yönetici"
        case .partner: return "İzleyici"
        }
    }
}

struct User: Codable, Identifiable, Equatable {
    /// Firebase Auth `uid`'i — 28 karakterlik opak bir metin, UUID'ye
    /// ayrıştırılamaz. Kimlik `UUID` kalsaydı güvenlik kuralındaki
    /// `request.auth.uid == ownerUid` karşılaştırması hiçbir zaman doğru olmaz
    /// ve tüm yetki modeli sessizce çökerdi.
    ///
    /// DİKKAT: Yalnızca KULLANICI kimliği metne döndü. Doküman kimlikleri
    /// (Project.id, Material.id, Apartment.id…) `UUID` kalıyor — onlar Firestore
    /// doküman adı, kullanıcı kimliği değil.
    let id: String
    var name: String
    var role: UserRole
    /// E.164 biçiminde telefon (+905551112233). Telefon+SMS auth seçildiği için
    /// kimliğin kullanıcıya görünen karşılığı bu.
    var phone: String = ""

    /// Avatar için baş harfler ("Mehmet Kılıç" → "MK").
    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased(with: Fmt.locale)
    }

    /// Demo kimlikleri SABİT: önceden `UUID()` ile her açılışta yeniden
    /// üretiliyordu, yani "kurduğum proje" bağı uygulama kapanınca kopuyordu.
    static let admin = User(id: "demo-admin", name: "Mehmet Kılıç", role: .admin)
    static let partner = User(id: "demo-partner", name: "Serkan Aydın", role: .partner)
}
