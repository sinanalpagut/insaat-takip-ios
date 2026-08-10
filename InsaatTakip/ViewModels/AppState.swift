import SwiftUI

// MARK: - Global Uygulama Durumu
// Oturum ve rol yönetimi. EnvironmentObject olarak tüm görünümlere dağıtılır.
// Yetki kuralı: veri giren tek kişi Yönetici'dir; Ortak yalnızca görüntüler.

final class AppState: ObservableObject {
    /// Aktif kullanıcı; nil ise karşılama (onboarding) ekranı gösterilir.
    @Published var currentUser: User?

    init() {
        // DEBUG: launch argümanıyla rol atlaması (ekran görüntüsü akışları için).
        if let role = LaunchConfig.role {
            currentUser = role == .admin ? .admin : .partner
        }
    }

    var isAdmin: Bool { currentUser?.role == .admin }
    var isPartner: Bool { currentUser?.role == .partner }

    /// "Yönetici Olarak Giriş Yap" akışı.
    func signInAsAdmin() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = .admin
        }
    }

    /// Davet kodu doğrulandıktan sonra ortak oturumu açar.
    func joinAsPartner() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = .partner
        }
    }

    /// Rol değiştirme (avatar menüsü) — canlı demoda iki görünümü kıyaslamak için.
    func switchRole(to role: UserRole) {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = role == .admin ? .admin : .partner
        }
    }

    /// Oturumu kapatıp karşılama ekranına döner.
    func signOut() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = nil
        }
    }
}
