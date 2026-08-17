import SwiftUI

// MARK: - Global Uygulama Durumu
// Oturum ve rol yönetimi. EnvironmentObject olarak tüm görünümlere dağıtılır.
// Yetki kuralı: veri giren tek kişi Yönetici'dir; Ortak yalnızca görüntüler.

@MainActor
final class AppState: ObservableObject {

    /// Aktif kullanıcı; nil ise karşılama (onboarding) ekranı gösterilir.
    @Published var currentUser: User?

    /// Telefon doğrulaması geçildi ama isim henüz alınmadı. İsim ekranı bununla
    /// açılır: telefon auth yalnızca numarayı kanıtlar, isim vermez — ortak
    /// listesinde ve hareket akışında görünecek adı kullanıcıdan almak şart.
    @Published var pendingNameSession: AuthSession?

    let auth: AuthService
    private let profiles: UserProfileStore

    init(auth: AuthService? = nil, profiles: UserProfileStore? = nil) {
        // DİKKAT: aşağıda `service`/`store` yerel değişkenleri kullanılıyor.
        // Parametre adı `auth`, `self.auth`'u gölgeliyor; doğrudan `auth`
        // yazılırsa varsayılan çağrıda (auth: nil) oturum HİÇ geri yüklenmez.
        let service = auth ?? Self.makeAuthService()
        let store = profiles ?? LocalUserProfileStore()
        self.auth = service
        self.profiles = store

        // DEBUG: launch argümanıyla rol atlaması (ekran görüntüsü akışları için).
        if let role = LaunchConfig.role {
            currentUser = role == .admin ? .admin : .partner
            return
        }
        // Diskte oturum varsa doğrudan içeri: kullanıcı her açılışta SMS beklemez.
        // İsim yerel önbellekten gelir; yoksa isim ekranı açılır — telefon
        // numarasını isim yerine göstermek yerine bir kez sormak doğrusu.
        if let session = service.restoredSession() {
            if let name = store.cachedProfile(uid: session.uid)?.name, !name.isEmpty {
                currentUser = Self.user(from: session, name: name)
            } else {
                pendingNameSession = session
            }
        }
    }

    /// Simülatörde SAHTE servis kullanılır: gerçek telefon doğrulaması APNs
    /// istiyor, push simülatörde hiç çalışmıyor ve Firebase reCAPTCHA web
    /// akışına düşüyor — o ekranın metni Google'ın kontrolünde ve Türkçe değil.
    /// Gerçek cihazda ve yayında Firebase uygulaması devreye girer.
    private static func makeAuthService() -> AuthService {
        #if targetEnvironment(simulator)
        return FakeAuthService()
        #else
        return FirebaseAuthService()
        #endif
    }

    var isAdmin: Bool { currentUser?.role == .admin }
    var isPartner: Bool { currentUser?.role == .partner }

    // MARK: Oturum akışı

    /// Kod doğrulandı. İsim biliniyorsa doğrudan içeri, bilinmiyorsa isim sorulur.
    /// İsmin nerede saklandığını ekranın bilmesine gerek yok; çözüm burada.
    func completeSignIn(_ session: AuthSession) async {
        if let name = await resolvedName(for: session), !name.isEmpty {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentUser = Self.user(from: session, name: name)
                pendingNameSession = nil
            }
        } else {
            pendingNameSession = session
        }
    }

    /// Önce yerel önbellek (anında), sonra uzak kopya. Yeni hesapta uzak kopya
    /// yok — bayrağa güvenip gereksiz ağ turunu atlıyoruz.
    private func resolvedName(for session: AuthSession) async -> String? {
        if let cached = profiles.cachedProfile(uid: session.uid) { return cached.name }
        guard !session.isNewAccount else { return nil }
        do { return try await profiles.fetch(uid: session.uid)?.name } catch { return nil }
    }

    /// İsim ekranından gelen ad ile oturumu tamamlar ve profili kaydeder.
    func finishNameStep(name: String) {
        guard let session = pendingNameSession else { return }
        let profile = UserProfile(uid: session.uid,
                                  name: name,
                                  phone: session.phone,
                                  createdAt: Date())
        // Yazma arka planda: ekran beklemez. Uzak yazma başarısız olsa bile
        // `save` yerel önbelleği güncellediği için isim bir daha sorulmaz.
        Task { try? await profiles.save(profile) }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = Self.user(from: session, name: name)
            pendingNameSession = nil
        }
    }

    /// Hesap kartından isim değiştirme. İsim ekranı "sonradan değiştirebilirsin"
    /// diyor; bu, o sözün karşılığı.
    func updateName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard var user = currentUser, !trimmed.isEmpty, trimmed != user.name else { return }
        user.name = trimmed
        let profile = UserProfile(uid: user.id,
                                  name: trimmed,
                                  phone: user.phone,
                                  createdAt: profiles.cachedProfile(uid: user.id)?.createdAt ?? Date())
        Task { try? await profiles.save(profile) }
        withAnimation(.easeInOut(duration: 0.2)) { currentUser = user }
    }

    /// Rol değiştirme (avatar menüsü) — canlı demoda iki görünümü kıyaslamak için.
    func switchRole(to role: UserRole) {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = role == .admin ? .admin : .partner
        }
    }

    /// Oturumu kapatıp karşılama ekranına döner.
    ///
    /// Profil önbelleği SİLİNMEZ: aynı kişi tekrar girdiğinde isim yeniden
    /// sorulmasın. Kayıt uid'e bağlı olduğu için başka bir hesapla girildiğinde
    /// o hesabın adı okunur, bu ad sızmaz.
    func signOut() {
        try? auth.signOut()
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = nil
            pendingNameSession = nil
        }
    }

    /// Oturumdan `User` üretir.
    ///
    /// ROL — bilinen sınır: rol bugün kullanıcı başına GLOBAL. Doğru model
    /// proje başınadır (kendi projesinde yönetici, davet edildiği projede
    /// ortak) ve `Project.ownerUid` bunu zaten ifade edebiliyor. Global rol
    /// kaldığı sürece "kendi projesi olan bir kişi, davet edildiği projede de
    /// yönetici görünür" durumu mümkün. Yeni hesap `.admin` açılıyor çünkü
    /// aksi halde ilk kullanıcı proje kuramaz ve uygulama ilk açılışta ölü kalır.
    /// Proje bazlı role geçiş ayrı bir madde olarak ele alınacak.
    private static func user(from session: AuthSession, name: String) -> User {
        User(id: session.uid, name: name, role: .admin, phone: session.phone)
    }
}
