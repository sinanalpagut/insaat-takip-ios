import SwiftUI
import FirebaseCore

// MARK: - Uygulama Girişi

@main
struct InsaatTakipApp: App {
    /// Global oturum / rol durumu.
    @StateObject private var appState = AppState()
    /// Tüm proje verisi ve iş mantığı.
    @StateObject private var viewModel = ProjectViewModel()

    init() {
        // GoogleService-Info.plist'i okuyup Firebase'i başlatır. Kalıcılık ve
        // Auth henüz bağlı değil (bkz. ANALIZ.md Faz 2) — bu satır yalnızca
        // SDK'nın uygulamaya doğru bağlandığını doğrulamak için var; sonraki
        // adımlarda repository ve kimlik doğrulama buna dayanacak.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(viewModel)
                .preferredColorScheme(.light)   // Tasarım açık tema üzerine kurulu
                .tint(Palette.accent)
                // Arayüz tamamen Türkçe. Yerel ayar sabitlenmezse SwiftUI'nin
                // .textCase(.uppercase) dönüşümü cihazın diline uyar ve İngilizce
                // telefonda "YÖNETİCİ" → "YÖNETICI", "AKTİF" → "AKTIF" olur (i ≠ İ).
                .environment(\.locale, Fmt.locale)
        }
    }
}
