import Foundation
import LocalAuthentication

// MARK: - Uygulama Kilidi ve Gizlilik Örtüsü (madde 78)
//
// Uygulama alıcı kimliğini, IBAN taşıyan dekontları ve projenin tüm
// finansallarını taşıyor. Telefonunu masaya bırakan müteahhit için bunların
// tamamı bir dokunuş uzaktaydı: `LAContext` kod tabanında hiç geçmiyordu ve
// uygulama değiştiricide örtü yoktu — arka plandaki uygulamanın anlık
// görüntüsü ciroyu ve alıcı adlarını olduğu gibi gösteriyordu.
//
// ═══ KARARLAR ═══
//
// OPSİYONEL, VARSAYILAN KAPALI. Her açılışta yüz taraması istemek şantiyede
// eldivenle çalışan bir kullanıcı için ürünü kullanılmaz yapardı. Koruma
// isteyen açar.
//
// `deviceOwnerAuthentication` — `...WithBiometrics` DEĞİL. Fark kritik:
// biyometri-yalnız politika, yüzü okunmayan (maske, ıslak el, kardeş
// benzerliği) kullanıcıya HİÇBİR giriş yolu bırakmaz. Veri onun verisi;
// kişiyi kendi kaydından dışarıda bırakan bir kilit, koruma değil arıza.
// Bu politika parola yedeğini de kapsıyor.
//
// CİHAZDA PAROLA YOKSA KİLİT AÇILMIYOR VE AÇIK KALIYOR (fail-open).
// Görünüşte yanlış ama tersi daha kötü: parolasız bir cihazda kilidi
// zorlamak, uygulamayı kalıcı olarak erişilemez yapardı — üstelik hiçbir şey
// kazandırmadan, çünkü telefonu eline alan zaten içeride. Ayar da böyle bir
// cihazda AÇILAMIYOR; kullanıcıya sebebi söyleniyor.
//
// KİLİT `.background`TA, ÖRTÜ `.inactive`TE. İkisi bilerek farklı:
//   · Fiş fotoğrafı çekmek ve galeriden seçmek sahneyi `.inactive` yapıyor
//     ama `.background` yapmıyor. Kilidi `.inactive`e bağlamak, uygulamanın
//     EN ÇOK kullanılan eyleminde her seferinde yüz taraması istemek olurdu.
//   · Uygulama değiştirici anlık görüntüsü tam olarak `.inactive` anında
//     alınıyor; örtünün orada olması şart.
// Aynı yaşam döngüsünün iki farklı eşiği, iki farklı sebeple.

@MainActor
final class AppLock: ObservableObject {

    /// Kilit şu an kapalı mı? `true` iken içerik hiç çizilmiyor.
    @Published private(set) var isLocked = false

    /// Uygulama değiştirici örtüsü görünsün mü?
    @Published private(set) var isCovered = false

    /// Kullanıcı kilidi açtı mı? (cihazda saklanıyor)
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.key)
            // Ayar kapatılınca kilit de düşmeli; aksi halde kullanıcı
            // kapattığı bir kilidin arkasında kalırdı.
            if !isEnabled { isLocked = false; isCovered = false }
        }
    }

    private static let key = "appLockEnabled"
    private let defaults: UserDefaults
    private let context: () -> LAContext

    init(defaults: UserDefaults = .standard,
         context: @escaping () -> LAContext = { LAContext() }) {
        self.defaults = defaults
        self.context = context
        self.isEnabled = defaults.bool(forKey: Self.key)
    }

    /// Cihaz kimlik doğrulaması yapabiliyor mu? (biyometri VEYA parola)
    ///
    /// Ayar bu `false` iken açılamıyor: açılabilseydi kullanıcı, açamayacağı
    /// bir kilidin arkasında kalırdı.
    var canAuthenticate: Bool {
        var error: NSError?
        return context().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Cihazda parola/biyometri yoksa kullanıcıya SEBEBİ söylenecek metin.
    var unavailableReason: String {
        "Bu cihazda ekran kilidi tanımlı değil · önce Ayarlar'dan parola kur"
    }

    // MARK: Yaşam döngüsü

    /// Sahne arka plana geçti — kilitle.
    func applicationDidEnterBackground() {
        guard isEnabled else { return }
        isLocked = true
    }

    /// Sahne bir an için etkisizleşti — uygulama değiştirici görüntüsü tam
    /// burada alınıyor, örtü hemen inmeli.
    func applicationWillResignActive() {
        guard isEnabled else { return }
        isCovered = true
    }

    /// Sahne tekrar etkin — örtü kalkar, kilit varsa doğrulama istenir.
    func applicationDidBecomeActive() {
        isCovered = false
    }

    // MARK: Doğrulama

    /// Kilidi açmayı dener.
    ///
    /// Cihaz doğrulama yapamıyorsa kilit AÇILIYOR (fail-open) — gerekçesi
    /// dosya başında.
    @discardableResult
    func unlock() async -> Bool {
        guard isLocked else { return true }
        let ctx = context()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return true
        }
        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Proje kayıtlarını görmek için kimliğini doğrula")
            if ok { isLocked = false }
            return ok
        } catch {
            // Kullanıcı vazgeçti ya da doğrulama düştü: kilit KAPALI kalıyor.
            return false
        }
    }
}
