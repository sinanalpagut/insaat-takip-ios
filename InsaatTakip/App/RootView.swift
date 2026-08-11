import SwiftUI

// MARK: - Kök Görünüm ve Rota Tanımı
// Oturum yoksa karşılama; varsa NavigationStack içinde Dashboard.
// Push edilen ekranlar Route enum'u üzerinden yönetilir.

/// Uygulama içi push rotaları.
enum Route: Hashable {
    case project(String)     // Proje detay (projectId)
    case activity            // Hareketler / bildirimler
    case photos(String)      // Şantiye fotoğrafları
    case report(String)      // Dönem raporu
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if appState.currentUser == nil {
                WelcomeView()
                    .toastOverlay(viewModel.toast)
                    // Oturum kapanınca gezinme yığını sıfırlanır; yeniden girişte
                    // kullanıcı eski ekranın üstünde açılmaz.
                    .onAppear { path = NavigationPath() }
            } else {
                NavigationStack(path: $path) {
                    DashboardView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .project(let id):  ProjectDetailView(projectId: id)
                            case .activity:         ActivityFeedView()
                            case .photos(let id):   SitePhotosView(projectId: id)
                            case .report(let id):   ReportView(projectId: id)
                            }
                        }
                }
                .toastOverlay(viewModel.toast)
                .onAppear { seedFromLaunchConfig() }
            }
        }
    }

    /// DEBUG launch argümanlarına göre ilk rotayı kurar (ekran görüntüsü akışı).
    private func seedFromLaunchConfig() {
        guard path.isEmpty else { return }
        switch LaunchConfig.screen {
        case "project":  path.append(Route.project("p1"))
        case "activity": path.append(Route.activity)
        case "photos":   path.append(Route.photos("p1"))
        case "report":   path.append(Route.report("p1"))
        default:         break
        }
    }
}
