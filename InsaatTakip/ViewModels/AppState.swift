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
    private let deletion: AccountDeletionService

    /// Silme bitince karşılama ekranında gösterilecek özet.
    ///
    /// Neden burada: `deleteAccount` `currentUser`ı nil'liyor ve `RootView` o
    /// anda TÜM ağacı değiştiriyor — silme ekranının kendi "bitti" adımı
    /// yok olup gidiyordu. Kullanıcı düğmeye basıp kendini aniden giriş
    /// ekranında buluyordu ve ne silindiğini hiç göremiyordu.
    @Published var lastDeletionSummary: AccountDeletionSummary?

    init(auth: AuthService? = nil, profiles: UserProfileStore? = nil,
         deletion: AccountDeletionService? = nil) {
        // DİKKAT: aşağıda `service`/`store` yerel değişkenleri kullanılıyor.
        // Parametre adı `auth`, `self.auth`'u gölgeliyor; doğrudan `auth`
        // yazılırsa varsayılan çağrıda (auth: nil) oturum HİÇ geri yüklenmez.
        let service = auth ?? Self.makeAuthService()
        // Firestore devredeyse profil SUNUCUDA olmak zorunda: `redeemInvite`
        // Cloud Function'ı katılan kişinin adını `users/{uid}`'den okuyor.
        // Yalnızca yerelde kalsa yöneticinin ortak listesinde "Ortak" görünürdü.
        let store = profiles ?? (LaunchConfig.usesFirestore
                                 ? FirestoreUserProfileStore()
                                 : LocalUserProfileStore())
        self.auth = service
        self.profiles = store
        self.deletion = deletion ?? Self.makeDeletionService()

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
                // Önbellek boş — ama SUNUCU ismi biliyor olabilir. Uygulama
                // silinip yeniden kurulduğunda anahtar zinciri oturumu koruyor,
                // yerel önbellek ise sıfırlanıyor: yalnızca önbelleğe bakılırsa
                // isim yeniden soruluyor ve verilen cevap `users/{uid}` belgesini
                // YENİ `createdAt` ile eziyor. Farklı yazılırsa ortakların
                // gördüğü ad da sessizce değişirdi.
                pendingNameSession = session
                Task { await adoptRemoteName(for: session) }
            }
        }
    }

    /// Sunucudaki profili okur; isim varsa isim ekranını hiç göstermeden içeri
    /// alır. Ekran bir an görünüp kapanabilir — bu, yanlış ismi kalıcılaştırmaya
    /// yeğdir. Hata durumunda sessizce isim ekranında kalınır.
    private func adoptRemoteName(for session: AuthSession) async {
        guard let name = try? await profiles.fetch(uid: session.uid)?.name,
              !name.isEmpty,
              pendingNameSession?.uid == session.uid else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = Self.user(from: session, name: name)
            pendingNameSession = nil
        }
    }

    /// Simülatörde SAHTE servis kullanılır: gerçek telefon doğrulaması APNs
    /// istiyor, push simülatörde hiç çalışmıyor ve Firebase reCAPTCHA web
    /// akışına düşüyor — o ekranın metni Google'ın kontrolünde ve Türkçe değil.
    /// Gerçek cihazda ve yayında Firebase uygulaması devreye girer.
    ///
    /// İSTİSNA — emülatör modu: Auth emülatörü APNs de reCAPTCHA da istemiyor,
    /// yani simülatörde GERÇEK telefon akışı çalışıyor. Bu şart, çünkü Firestore
    /// kuralları `request.auth.uid` istiyor; sahte servis Firebase'e hiç
    /// dokunmadığı için kalıcılık emülatörde sahte kimlikle denenemez.
    private static func makeAuthService() -> AuthService {
        #if DEBUG
        if LaunchConfig.emulatorHost != nil { return FirebaseAuthService() }
        // "-auth firebase": test telefon numarasıyla gerçek yol, simülatörde de.
        if LaunchConfig.usesFirebaseAuth { return FirebaseAuthService() }
        #endif
        // `DEBUG` ŞARTI ZORUNLU. Yalnızca `targetEnvironment(simulator)`
        // yazılsaydı, RELEASE yapılandırması simülatörde koşturulduğunda sahte
        // kimlik devreye girerdi — yani "yayın derlemesini bir kez çalıştırıp
        // görelim" denemesi (madde 70) gerçek yolu değil, taklidi sınardı ve
        // geçtiğini sanırdık. Mağazaya giden ikili cihazda çalıştığı için
        // etkilenmiyor; tehlike, sınamanın kendisinin yalan söylemesi.
        #if DEBUG && targetEnvironment(simulator)
        // Rol kısayolu kullanılıyorsa sahte oturum O KULLANICIYLA kuruluyor —
        // gerekçesi FakeAuthService.init'te.
        let shortcut: User? = LaunchConfig.role.map { $0 == .admin ? .admin : .partner }
        return FakeAuthService(signedInAs: shortcut)
        #else
        return FirebaseAuthService()
        #endif
    }

    /// Silme servisi, kimlik servisiyle AYNI ölçüte göre seçiliyor: sahte
    /// kimlikle çalışan bir oturumun gerçek sunucu silmesi çağırması anlamsız
    /// olurdu (uid sunucuda yok).
    private static func makeDeletionService() -> AccountDeletionService {
        #if DEBUG
        if LaunchConfig.emulatorHost != nil { return FirebaseAccountDeletionService() }
        if LaunchConfig.usesFirebaseAuth { return FirebaseAccountDeletionService() }
        #endif
        #if DEBUG && targetEnvironment(simulator)
        return FakeAccountDeletionService()
        #else
        return FirebaseAccountDeletionService()
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
    /// Geliştirme önizlemesi: rolü değiştirir, KİMLİĞİ DEĞİŞTİRMEZ.
    ///
    /// Önceden `currentUser`ı örnek kullanıcılarla (`.admin` / `.partner`)
    /// değiştiriyordu. Sonucu gerçek veriyle test ederken ortaya çıktı:
    /// "Ortak görünümü"ne basınca oturum bambaşka bir kimliğe geçiyor, o kimlik
    /// hiçbir projenin üyesi olmadığı için ekran "0 proje · Henüz projen yok"
    /// diyordu. "Yönetici görünümü"ne dönmek de gerçek kullanıcıyı geri
    /// getirmiyordu — üçüncü bir örnek kullanıcı geliyordu. Gerçek oturum
    /// yalnızca uygulama yeniden açılınca dönüyordu.
    ///
    /// ASIL TEHLİKE VERİ KAYBI DEĞİL, YANLIŞ SONUÇTU: bu araçla "ortak ne
    /// görüyor" sorusunu sınamaya kalkan biri boş bir ekran görüp "ortak
    /// projeyi göremiyor" diye YANLIŞ bir gizlilik sonucuna varabilirdi.
    /// Kimliği değiştiren bir önizleme, önizlediğini iddia ettiği şeyi
    /// göstermiyor.
    ///
    /// SINIR — bu önizleme EKRANI gösterir, VERİYİ DEĞİL. Yönetici oturumu
    /// `buyers` belgelerini zaten indirmiş durumda, dolayısıyla önizlemede
    /// daire kartında ALICI ADI görünebilir. Gerçek ortakta görünmez: kural
    /// `buyers`ı ortağa kapatıyor, yani o veri istemciye hiç ulaşmıyor
    /// (`tests/rules.test.mjs` bunu kanıtlıyor). Buradaki görüntüye bakıp
    /// "ortak alıcı adını görüyor" sonucunu çıkarmak YANLIŞ olur; veri
    /// katmanının kanıtı kural testleridir, bu araç değil.
    func switchRole(to role: UserRole) {
        withAnimation(.easeInOut(duration: 0.25)) {
            guard let user = currentUser else {
                currentUser = role == .admin ? .admin : .partner
                return
            }
            currentUser = User(id: user.id, name: user.name,
                               role: role, phone: user.phone)
        }
    }

    /// Oturumu kapatıp karşılama ekranına döner.
    ///
    /// Profil önbelleği SİLİNMEZ: aynı kişi tekrar girdiğinde isim yeniden
    /// sorulmasın. Kayıt uid'e bağlı olduğu için başka bir hesapla girildiğinde
    /// o hesabın adı okunur, bu ad sızmaz.
    /// Hesabı ve tüm verisini siler (madde 28 · App Store 5.1.1(v)).
    ///
    /// SIRA TEK YÖNLÜ KAPI ve değiştirilemez:
    ///   1. SUNUCU VERİSİ — Cloud Function. Auth kaydı hâlâ duruyor, yani
    ///      işlevin `request.auth.uid`'i var ve kurallar çözülebiliyor.
    ///   2. AUTH KAYDI — işlev zaten Admin SDK ile sildi; istemcideki
    ///      `deleteAccount()` yalnızca yerel oturumu geçersiz kılıyor ve
    ///      başarısız olması akışı durdurmuyor.
    ///   3. YEREL TEMİZLİK — en son. Önce yapılsaydı ve sunucu adımı
    ///      başarısız olsaydı, kullanıcı verisini kaybetmiş ama hesabı duran
    ///      bir hâlde kalırdı.
    ///
    /// Yeniden kimlik doğrulama BU METODUN DIŞINDA, çağıran ekranda yapılıyor
    /// (SMS turu) — `AuthService.reauthenticate` ile, `verify` ile DEĞİL.
    func deleteAccount() async throws -> AccountDeletionSummary {
        let summary = try await deletion.deleteServerData()

        // Auth kaydını işlev sildi; bu çağrı yerel oturumu düşürüyor. Hata
        // yutuluyor çünkü sunucu tarafı zaten bitti ve kullanıcıyı "silindi mi
        // silinmedi mi" belirsizliğinde bırakmak daha kötü.
        try? await auth.deleteAccount()

        if let uid = currentUser?.id { profiles.remove(uid: uid) }
        try? auth.signOut()
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = nil
            pendingNameSession = nil
            lastDeletionSummary = summary
        }

        // CİHAZDAKİ DOSYALAR — en sonda ve oturum düştükten SONRA.
        //
        // Onay ekranı "fotoğraf ve belgeler kalıcı olarak silinecek" diyor;
        // bu satır olmadan o cümle yalnızca sunucu için doğruydu. Fotoğraflar,
        // belgeler ve Firestore'un kalıcı önbelleği (alıcı adları dahil)
        // telefonda kalıyordu.
        //
        // Firestore önbelleği BURADA temizlenmiyor; bayrağı bırakılıp sonraki
        // açılışa devrediliyor. Gerekçesi `LocalDataPurge` içinde yazılı ve
        // gerçek cihazda çökmeyle öğrenildi.
        LocalDataPurge.afterAccountDeletion()

        return summary
    }

    func signOut() {
        try? auth.signOut()
        withAnimation(.easeInOut(duration: 0.25)) {
            currentUser = nil
            pendingNameSession = nil
            // Silme özeti BURADA da temizleniyor. Temizlenmeseydi karşılama
            // ekranındaki "Hesabın silindi · 2 proje silindi" afişi, sonraki
            // sıradan bir ÇIKIŞTA yeniden belirirdi: kullanıcı çıkış yapar,
            // ekranda hesabının silindiğini okur.
            lastDeletionSummary = nil
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
