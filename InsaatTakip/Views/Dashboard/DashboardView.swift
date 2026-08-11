import SwiftUI

// MARK: - Projeler / Dashboard (Ekran 01)
// Koyu app bar (alt köşeleri 22px yuvarlak): wordmark, bildirim zili, avatar,
// "Projelerim" başlığı. Gövde: AKTİF PROJELER etiketi + proje kartları.
// Yönetici: sağ altta "＋ Yeni Proje" FAB. Ortak: FAB yok; listeye kesikli
// "Kod ile projeye katıl" kartı eklenir ve app bar'da salt okunur rozeti görünür.

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    @State private var showNewProject = false
    @State private var showRoleMenu = false
    @State private var showJoinSheet = false

    private var isAdmin: Bool { appState.isAdmin }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Text("Aktif Projeler")
                            .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        Spacer()
                        Text("\(viewModel.projects.count) proje")
                            .font(.manrope(12, .semiBold))
                            .foregroundColor(Palette.textSecondary)
                    }
                    .padding(.top, 18)

                    ForEach(viewModel.projects) { project in
                        NavigationLink(value: Route.project(project.id)) {
                            ProjectCardView(project: project)
                        }
                        .buttonStyle(.plain)
                    }

                    // Ortak: yeni projeye yalnızca davet koduyla katılabilir.
                    if !isAdmin {
                        joinCard
                    }

                    Spacer().frame(height: 90)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .floatingActionButton("Yeni Proje", visible: isAdmin) {
            showNewProject = true
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet()
        }
        .fullScreenCover(isPresented: $showJoinSheet) {
            JoinWithCodeView()
        }
        .sheet(isPresented: $showRoleMenu) {
            AccountSheet()
        }
    }

    // MARK: Koyu app bar

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("İNŞAAT TAKİP")
                    .font(.manrope(10.5, .extraBold))
                    .tracking(2.2)
                    .foregroundColor(.white.opacity(0.45))
                Spacer()

                // Bildirim zili — okunmamış hareket varsa kehribar nokta.
                NavigationLink(value: Route.activity) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(13)
                        if viewModel.hasUnreadActivity {
                            Circle()
                                .fill(Palette.amberDot)
                                .frame(width: 7, height: 7)
                                .offset(x: -11, y: 11)
                        }
                    }
                }

                // Avatar — rol değiştirme / çıkış menüsü.
                Button {
                    showRoleMenu = true
                } label: {
                    Text(appState.currentUser?.initials ?? "")
                        .font(.manrope(13, .extraBold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Palette.accent)
                        .clipShape(Circle())
                }
                .padding(.leading, 10)
            }
            .padding(.top, 6)

            Text("Projelerim")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text(viewModel.dashboardSubtitle)
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 5)

            // Ortak için salt okunur bilgilendirme rozeti.
            if !isAdmin {
                HStack(spacing: 7) {
                    Image(systemName: "eye")
                        .font(.system(size: 10, weight: .semibold))
                    Text("İzleyici · salt okunur erişim")
                        .font(.manrope(10.5, .extraBold))
                        .tracking(0.5)
                }
                .foregroundColor(.white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Palette.ink
                .clipShape(RoundedCorners(radius: 22, corners: [.bottomLeft, .bottomRight]))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Ortak katılım kartı

    private var joinCard: some View {
        Button {
            showJoinSheet = true
        } label: {
            HStack(spacing: 12) {
                Text("+")
                    .font(.manrope(19, .semiBold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 38, height: 38)
                    .background(Palette.accentTint)
                    .cornerRadius(12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kod ile projeye katıl")
                        .font(.manrope(13.5, .bold))
                        .foregroundColor(Palette.ink)
                    Text("Yöneticiden aldığın 6 haneli kodu gir")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Palette.surface)
            .cornerRadius(16)
            .dashedBorder(Palette.dashed, radius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Proje Kartı

struct ProjectCardView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Başlık + durum çipi
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.title)
                        .font(.sora(17, .bold))
                        .foregroundColor(Palette.ink)
                    Text(project.meta)
                        .font(.manrope(12.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                }
                Spacer()
                StatusChip(text: project.phase.rawValue,
                           background: project.isNearComplete ? Palette.successTint : Palette.accentTint,
                           foreground: project.isNearComplete ? Palette.success : Palette.accent,
                           uppercased: false)
            }

            // İlerleme
            HStack {
                Text("İnşaat ilerlemesi")
                    .font(.manrope(12, .medium))
                    .foregroundColor(Palette.textMuted)
                Spacer()
                Text("%\(project.progress)")
                    .font(.sora(13, .bold))
                    .foregroundColor(project.isNearComplete ? Palette.success : Palette.accent)
            }
            .padding(.top, 14)

            ProgressBarView(fraction: Double(project.progress) / 100,
                            fill: project.isNearComplete ? Palette.success : Palette.accent)
                .padding(.top, 7)

            Divider()
                .overlay(Palette.divider)
                .padding(.top, 13)

            // 3 kolonlu özet: SATILAN · MALZEME · CİRO
            HStack(spacing: 0) {
                statColumn("Satılan",
                           "\(viewModel.soldCount(for: project.id))/\(project.totalApartments)",
                           Palette.ink)
                statColumn("Malzeme",
                           "\(viewModel.materials(for: project.id).count) kalem",
                           Palette.ink)
                statColumn("Ciro",
                           Fmt.compactMoney(viewModel.totalSales(for: project.id)),
                           Palette.success)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    private func statColumn(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .smallCapsLabel(size: 9.5, color: Palette.textTertiary, tracking: 0.9)
            Text(value)
                .font(.sora(15, .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
