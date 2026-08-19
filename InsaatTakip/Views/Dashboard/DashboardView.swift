import SwiftUI

// MARK: - Projeler / Dashboard (Ekran 01)
// Koyu app bar (alt köşeleri 22px yuvarlak): wordmark, bildirim zili, avatar,
// "Projelerim" başlığı. Gövde: AKTİF PROJELER etiketi + proje kartları.
// Yönetici: sağ altta "＋ Yeni Proje" FAB. Ortak: FAB yok; listeye kesikli
// "Kod ile projeye katıl" kartı eklenir ve app bar'da salt okunur rozeti görünür.

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40
    @EnvironmentObject private var viewModel: ProjectViewModel

    @State private var showNewProject = false
    @State private var showRoleMenu = false
    @State private var showJoinSheet = false

    private var isAdmin: Bool { appState.isAdmin }

    /// Yalnızca kullanıcının erişebildiği projeler (yönetici: kurduğu,
    /// ortak: davetle katıldığı). Filtre ViewModel'de.
    private var visibleProjects: [Project] {
        viewModel.visibleProjects(for: appState.currentUser)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // PORTFÖY ŞERİDİ — madde 26. Tek projesi olan için gürültü,
                    // o yüzden İKİ ve üzeri projede görünüyor.
                    if visibleProjects.count > 1,
                       let portfolio = viewModel.portfolio(for: appState.currentUser) {
                        portfolioCard(portfolio)
                            .padding(.top, 18)
                    }

                    HStack {
                        Text("Aktif Projeler")
                            .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        Spacer()
                        Text("\(visibleProjects.count) proje")
                            .font(.manrope(12, .semiBold))
                            .foregroundColor(Palette.textSecondary)
                    }
                    .padding(.top, 18)

                    if visibleProjects.isEmpty {
                        emptyState
                    }

                    ForEach(visibleProjects) { project in
                        NavigationLink(value: Route.project(project.id)) {
                            ProjectCardView(project: project)
                        }
                        .buttonStyle(.plain)
                    }

                    // Davet kartı ROLDEN BAĞIMSIZ. Eskiden `!isAdmin` koşuluyla
                    // gösteriliyordu; kimlik doğrulaması geldikten sonra her yeni
                    // hesap `.admin` açıldığı için davet edilen ortak elindeki
                    // kodu girecek hiçbir yer bulamıyordu — özellik ölü doğmuştu.
                    // Ayrıca kendi projesinin yöneticisi olan biri, başkasının
                    // projesine ortak olarak davet edilebilir; bu kartı role
                    // bağlamak o durumu da imkânsız kılıyordu.
                    joinCard

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
                    .foregroundColor(.white.opacity(0.62))
                Spacer()

                // Bildirim zili — okunmamış hareket varsa kehribar nokta.
                NavigationLink(value: Route.activity) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .iconFont(15, weight: .medium)
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                // Nokta bilgi taşıyor ama SADECE renkle: VoiceOver kullanıcısı
                // okunmamış hareket olduğunu hiç öğrenemiyordu.
                .accessibilityLabel(viewModel.hasUnreadActivity
                                    ? "Hareket akışı · okunmamış var"
                                    : "Hareket akışı")

                // Avatar — rol değiştirme / çıkış menüsü.
                Button {
                    showRoleMenu = true
                } label: {
                    Text(appState.currentUser?.initials ?? "")
                        .font(.manrope(13, .extraBold))
                        .foregroundColor(.white)
                        // Daire YAZIYLA BİRLİKTE büyüyor: sabit 40pt'de baş
                        // harfler AX5'te sığmıyor ve avatar "..." gösteriyordu
                        // — hesap sayfasının (rol, çıkış, HESAP SİLME) tek
                        // girişi tanımsız bir noktaya dönüyordu. Tasarımdaki
                        // 40 sayısı varsayılan boyutta aynen korunuyor.
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        // ÖLÇEKLENİYOR AMA SINIRLI. Serbest bırakıldığında
                        // AX5'te 109pt'ye çıkıp başlığı taşırıyor ve zilin
                        // üstüne biniyordu. Başlık çubuğu gibi krom öğeler
                        // sınırsız büyüyemez; 52pt tavan hem baş harfleri
                        // okunur kılıyor hem düzeni koruyor. Tasarımdaki 40
                        // sayısı varsayılan boyutta aynen geçerli.
                        .frame(width: min(avatarSize, 52), height: min(avatarSize, 52))
                        .background(Palette.accent)
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                // Hesap sayfasının (rol, oturum kapatma, HESAP SİLME) TEK
                // girişi. Etiketsizken VoiceOver'da yalnızca baş harfler
                // okunuyordu — nereye götürdüğü belirsizdi.
                .accessibilityLabel("Hesap menüsü")
                .padding(.leading, 10)
            }
            .padding(.top, 6)

            Text("Projelerim")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                // Büyük yazıda "Projeler..." diye kesiliyordu; sarılmasına
                // izin veriliyor.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Text(viewModel.dashboardSubtitle(for: appState.currentUser))
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 5)

            // Ortak için salt okunur bilgilendirme rozeti.
            if !isAdmin {
                HStack(spacing: 7) {
                    Image(systemName: "eye")
                        .iconFont(10, weight: .semibold)
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

    // MARK: Boş durum

    /// Hiç proje yokken görünen karşılama. Kimlik doğrulaması gelene kadar bu
    /// hâle ulaşılamıyordu (her kullanıcı demo verisiyle açılıyordu); artık her
    /// YENİ HESABIN gördüğü ilk ekran bu. Boş bırakılırsa kullanıcı, davet
    /// koduyla mı katılacağını yoksa proje mi kuracağını anlamadan bomboş bir
    /// sayfayla karşılaşıyordu.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.2")
                .iconFont(22, weight: .regular)
                .foregroundColor(Palette.accent)
                .frame(width: 54, height: 54)
                .background(Palette.accentTint)
                .cornerRadius(17)

            Text("Henüz projen yok")
                .font(.sora(17, .bold))
                .foregroundColor(Palette.ink)
                .padding(.top, 4)

            Text(isAdmin
                 ? "Kendi projeni kurmak için “Yeni Proje”ye dokun. Ortak olarak davet edildiysen aşağıdaki koddan katıl."
                 : "Yöneticiden aldığın 6 haneli davet kodunu aşağıdan girerek projeye katıl.")
                .font(.manrope(12.5, .medium))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Palette.surface)
        .cornerRadius(18)
        .padding(.top, 4)
    }

    // MARK: Davet kodu kartı

    // MARK: Portföy şeridi (madde 26)

    /// Tüm projelerin toplamı + m² maliyetine göre karşılaştırma.
    ///
    /// Dashboard bugüne kadar kartları alt alta diziyor ama HİÇBİR toplam
    /// vermiyordu: beş projesi olan müteahhit toplam ciroyu, tahsilatı ve
    /// kalan alacağı hiçbir yerde göremiyordu — uygulamayı açma sebebi olan
    /// soru cevapsızdı.
    private func portfolioCard(_ portfolio: ProjectViewModel.Portfolio) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Portföy")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                Spacer()
                Text("\(portfolio.projectCount) proje")
                    .font(.manrope(12, .semiBold))
                    .foregroundColor(Palette.textSecondary)
            }

            // ERİŞİLEBİLİRLİK BOYUTLARINDA DİKEY. Üç karo yan yana AX5'te
            // sığmıyor: etiketler bölünüyor ("TAHSİLA / T"), rakamlar
            // sarılıyor ve kart okunmaz hâle geliyor. Yatay düzen tasarımın
            // parçası ama sığmadığı yerde bilgi taşımıyor.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        portfolioTile("CİRO", portfolio.sales, Palette.ink)
                        portfolioTile("TAHSİLAT", portfolio.collected, Palette.success)
                        portfolioTile("KALAN ALACAK", portfolio.outstanding, Palette.accent)
                    }
                } else {
                    HStack(spacing: 0) {
                        portfolioTile("CİRO", portfolio.sales, Palette.ink)
                        portfolioTile("TAHSİLAT", portfolio.collected, Palette.success)
                        portfolioTile("KALAN ALACAK", portfolio.outstanding, Palette.accent)
                    }
                }
            }
            .padding(.top, 14)

            Divider().overlay(Palette.divider).padding(.vertical, 12)

            // Projeler m² maliyetine göre sıralı — madde 25 gelmeden bu
            // karşılaştırma yapılamıyordu.
            // KIRPMA SESSİZ OLAMAZ. Önce `prefix(4)` vardı ve beş projeli
            // portföyde biri listeden sessizce düşüyordu — kullanıcı "hepsi bu"
            // sanıyordu. Kart uzamasın diye sınır duruyor ama kaç projenin
            // dışarıda kaldığı YAZILI.
            let rows = viewModel.comparisons(for: appState.currentUser)
            let shown = 5
            ForEach(rows.prefix(shown)) { row in
                HStack(spacing: 8) {
                    Text(row.title)
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                    Spacer()
                    if let margin = row.margin {
                        Text(Fmt.signedPercent(margin))
                            .font(.manrope(11, .bold))
                            .foregroundColor(margin >= 0 ? Palette.success : Palette.alertInk)
                    }
                    // Alan girilmemiş projede "—": sıfır yazmak "bedava inşa
                    // edildi" demek olurdu.
                    Text(row.perM2.map(Fmt.costPerArea) ?? "—")
                        .font(.sora(12, .bold))
                        .foregroundColor(Palette.textMuted)
                        .frame(width: 96, alignment: .trailing)
                }
                .padding(.top, 8)
            }

            if rows.count > shown {
                Text("+\(rows.count - shown) proje daha")
                    .font(.manrope(11, .semiBold))
                    .foregroundColor(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }

            Text("Sıralama m² maliyetine göre. Yüzde, satışa oranla satış−gider farkı; kalan inşaat maliyeti düşülmemiştir.")
                .font(.manrope(10.5, .medium))
                .foregroundColor(Palette.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
    }

    private func portfolioTile(_ label: String, _ value: Kurus,
                               _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .smallCapsLabel(size: 9, color: Palette.textFaded, tracking: 0.8)
            // Bkz. ProjectDetailView.financeTile: kırpma büyüklük ekini
            // yiyordu. Bu kart madde 26'nın tek varlık sebebi ("beş projesi
            // olan müteahhit toplam ciroyu hiçbir yerde göremiyordu") ve
            // büyük yazıda tam o soruyu cevapsız bırakıyordu.
            Text(Fmt.compactMoney(value))
                .font(.sora(15, .bold))
                .foregroundColor(color)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
                // Payda `sellableCount`: kat karşılığı daireler satılamaz.
                // Önceden burada saklı `project.totalApartments`, Daireler
                // sekmesinde ise `apartments.count` vardı — aynı proje iki
                // ekranda iki farklı oran gösteriyordu.
                statColumn("Satılan",
                           "\(viewModel.soldCount(for: project.id))/\(viewModel.sellableCount(for: project.id))",
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
