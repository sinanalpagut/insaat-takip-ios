import Foundation

// MARK: - Davet akışı sözleşmesi
//
// Repository ve AuthService'teki aynı dikiş: protokol + sahte + gerçek.
//
// NEDEN AYRI BİR SERVİS: davet, sistemdeki tek "kullanıcı kendi yetkisini
// yükseltiyor" işlemi. Güvenlik kuralları bunu bilerek reddediyor —
// `memberUids`'e yazma yalnızca sahibe açık, ve davet edilen kişi henüz üyesi
// olmadığı projeyi okuyamadığı için kodu istemcide doğrulaması da imkânsız.
// Dolayısıyla KULLANMA bir Cloud Function çağrısı; ÜRETME ise yöneticinin kendi
// projesine yazması, onu kural çözüyor.
//
// Bu asimetri kasıtlı ve iki uç ayrı yollardan gidiyor: `createInvite` doğrudan
// Firestore'a yazar, `redeemInvite` callable'a gider.

/// Davet kullanmanın sonucu.
struct InviteRedemption: Equatable {
    let projectId: UUID
    let projectTitle: String
    /// Kişi zaten üyeydi — HATA DEĞİL. Aynı bağlantıya iki kez dokunmak bir
    /// arıza değil; kullanıcıya "zaten ortağısın" denir ve proje açılır.
    let alreadyMember: Bool
}

enum InviteError: LocalizedError, Equatable {
    case notSignedIn
    case badFormat
    case notFound
    case expired
    case alreadyUsed
    /// Davet ortada kalmış (projesi silinmiş) ya da bozuk. Kullanıcının hatası değil.
    case inviteBroken
    case network
    case unknown

    /// Kullanıcıya gösterilen metin. Cloud Function'ın döndürdüğü kodlar
    /// makine okunur (`code-used`, `code-expired`…); Türkçeye çeviri BURADA
    /// yapılıyor ki sunucu mesajları arayüze sızmasın.
    var errorDescription: String? {
        switch self {
        case .notSignedIn:  return "Önce telefonla giriş yap"
        case .badFormat:    return "Kod 6 haneli olmalı"
        case .notFound:     return "Böyle bir davet kodu yok"
        case .expired:      return "Kodun süresi doldu · yöneticiden yeni kod iste"
        case .alreadyUsed:  return "Bu kod daha önce kullanılmış"
        case .inviteBroken: return "Davet geçersiz · yöneticiye bildir"
        case .network:      return "Bağlantı yok"
        case .unknown:      return "Projeye katılınamadı"
        }
    }

    /// Cloud Function'ın `message` alanındaki sabit anahtarı hataya çevirir.
    /// İşlev bilerek makine okunur anahtar döndürüyor: metin döndürseydi
    /// sunucudaki bir metin değişikliği arayüzü sessizce bozardı.
    static func fromFunctionCode(_ code: String) -> InviteError {
        switch code {
        case "signed-in-required": return .notSignedIn
        case "code-format":        return .badFormat
        case "code-not-found":     return .notFound
        case "code-expired":       return .expired
        case "code-used":          return .alreadyUsed
        case "invite-broken", "project-missing": return .inviteBroken
        default:                   return .unknown
        }
    }
}

@MainActor
protocol InviteService {

    /// Yönetici projeye davet kodu üretir.
    ///
    /// İki belge, tek parti: `invites/{KOD}` (işlevin tek `get` ile bulacağı
    /// otorite kayıt) + `projects/{pid}.invite` (yöneticinin ekranda göreceği
    /// ayna). Ayna bilinçli bir çoğaltma: kod okuma HERKESE kapalı olduğu için
    /// sahip bile `invites/{KOD}`'u okuyamaz.
    ///
    /// - Returns: üretilen ham kod (tiresiz, 6 karakter).
    func createInvite(projectId: UUID, ownerUid: String) async throws -> String

    /// Davet kodunu kullanır. Cloud Function çağrısı.
    func redeem(code: String) async throws -> InviteRedemption
}
