import SwiftUI

// MARK: - Uygulama Girişi
//
// Firebase kurulumu BURADA DEĞİL, `AppDelegate.didFinishLaunching` içinde.
// Gerekçe: `FirebaseApp.configure()` `App.init()`te çağrıldığında SwiftUI henüz
// app delegate'i kurmamış oluyor ve Firebase'in swizzler'ı geçici bir nesne
// görüp bağlanamıyor — günlükte
//   [AppDelegateSwizzler][I-SWZ001014] App Delegate does not conform to
//   UIApplicationDelegate protocol.
// Sonucu telefon doğrulamasında görünüyordu: doğrulama bildirimi
// FirebaseAuth'a iletilemediği için giriş `ERROR_NOTIFICATION_NOT_FORWARDED`
// (17054) ile düşüyordu.

@main
struct InsaatTakipApp: App {
    /// Firebase telefon doğrulaması app delegate ZORUNLU kılıyor: doğrulama
    /// bildiriminin FirebaseAuth'a iletilmesi gerekiyor (bkz. AppDelegate).
    /// Bu satır olmadan telefonla giriş hiçbir ortamda çalışmıyor.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Global oturum / rol durumu.
    @StateObject private var appState = AppState()
    /// Tüm proje verisi ve iş mantığı.
    @StateObject private var viewModel = ProjectViewModel()
    /// Uygulama kilidi ve gizlilik örtüsü (madde 78).
    @StateObject private var appLock = AppLock()
    /// Abonelik ve hak (madde 87/c). Hak buradan `viewModel.entitlement`e
    /// akıyor; kota ve yazma kilidi onu okuyor.
    @StateObject private var subscriptions = SubscriptionManager(store: Self.makeStore(),
                                                                 override: LaunchConfig.entitlement)

    private static func makeStore() -> SubscriptionStore {
        #if DEBUG
        if LaunchConfig.usesDemoStore { return DemoSubscriptionStore() }
        #endif
        return AppStoreSubscriptionStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(viewModel)
                .environmentObject(appLock)
                .environmentObject(subscriptions)
                // İşlem dinleyicisi AÇILIŞTA: uygulama kapalıyken tamamlanan
                // yenileme ve onaylar ancak dinleyen varsa teslim ediliyor.
                .task { subscriptions.start() }
                .onReceive(subscriptions.$entitlement) { viewModel.entitlement = $0 }
                .preferredColorScheme(.light)   // Tasarım açık tema üzerine kurulu
                .tint(Palette.accent)
                // Arayüz tamamen Türkçe. Yerel ayar sabitlenmezse SwiftUI'nin
                // .textCase(.uppercase) dönüşümü cihazın diline uyar ve İngilizce
                // telefonda "YÖNETİCİ" → "YÖNETICI", "AKTİF" → "AKTIF" olur (i ≠ İ).
                .environment(\.locale, Fmt.locale)
        }
    }
}
