import SwiftUI

// MARK: - Uygulama Girişi

@main
struct InsaatTakipApp: App {
    /// Global oturum / rol durumu.
    @StateObject private var appState = AppState()
    /// Tüm proje verisi ve iş mantığı.
    @StateObject private var viewModel = ProjectViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(viewModel)
                .preferredColorScheme(.light)   // Tasarım açık tema üzerine kurulu
                .tint(Palette.accent)
        }
    }
}
