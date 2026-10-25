import SwiftUI
import UniformTypeIdentifiers

// MARK: - Projeler / Dashboard (Ekran 01)
// Koyu app bar (alt köşeleri 22px yuvarlak): wordmark, bildirim zili, avatar,
// "Projelerim" başlığı. Gövde: AKTİF PROJELER etiketi + proje kartları.
// Yönetici: sağ altta "＋ Yeni Proje" FAB. Ortak: FAB yok; listeye kesikli
// "Kod ile projeye katıl" kartı eklenir ve app bar'da salt okunur rozeti görünür.

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40
    @State private var showArchived = false
    @EnvironmentObject private var viewModel: ProjectViewModel

    @State private var showNewProject = false
    @State private var showRoleMenu = false
    @State private var showJoinSheet = false
    @State private var showRestorePicker = false
    /// Paketler ekranının sunum taşıyıcısı.
    ///
    /// `.sheet(isPresented:)` DEĞİL `.sheet(item:)` ve sebebi ölçülerek
    /// bulundu: iki `@State`i aynı blokta değiştirince (önce bağlam, sonra
    /// bayrak) sheet içeriği bağlamın ESKİ değerini yakalıyordu — ekran
    /// açılıyor ama sınır metni yerine genel metin çıkıyordu. Taşıyıcı
    /// değerle birlikte sunulduğu için böyle bir yarış kalmıyor.
    private struct PaketSunumu: Identifiable {
        let id = UUID()
        let sinirdaki: Bool
    }
    @State private var paketSunumu: PaketSunumu?
    @State private var restoreSummary: ProjectViewModel.RestoreSummary?
    @State private var restoreError: String?
    /// Geri yükleme YAPILMADI — neden ve ne yapılacağı.
    @State private var restoreRefusal: ProjectViewModel.RestoreRefusal?
    /// Onay birkaç saniyeyi geçti mi — geçtiyse bağlantı açıklaması.
    @State private var slowRestore = false

    private var isAdmin: Bool { appState.isAdmin }

    /// Yalnızca kullanıcının erişebildiği projeler (yönetici: kurduğu,
    /// ortak: davetle katıldığı). Filtre ViewModel'de.
    /// AKTİF projeler — arşivlenenler ayrı bölümde (madde 60).
    private var visibleProjects: [Project] {
        viewModel.activeProjects(for: appState.currentUser)
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

                    // Yüklenemeyen projeler ŞERİDİ — listeden sessizce
                    // eksilmesinler ve toplamlara dahil olmadıkları YAZILI olsun.
                    failedProjectsStrip

                    // HATA İLE BOŞLUK AYRI ŞEYLER (madde 57). Aynı ekranı
                    // göstermek, veri gelmediğinde kullanıcıya "verin yok"
                    // demek oluyordu — kural reddi, eksik indeks ya da ağ
                    // hatasında üründeki en korkutucu cümle.
                    if let hata = viewModel.loadError, visibleProjects.isEmpty {
                        loadErrorState(hata)
                    } else if visibleProjects.isEmpty {
                        emptyState
                    }

                    ForEach(visibleProjects) { project in
                        NavigationLink(value: Route.project(project.id)) {
                            ProjectCardView(project: project)
                        }
                        .buttonStyle(.plain)
                    }

                    archivedSection

                    // PAKET SATIRI — madde 87. Yalnızca yöneticide: paket,
                    // projeyi KURAN kişinin ödeme ilişkisi. Ortağın salt
                    // okunur ekranında fiyat göstermek, ödemeyeceği bir şeyi
                    // satmaya çalışmak olurdu.
                    if isAdmin { planRow }

                    // Davet kartı ROLDEN BAĞIMSIZ. Eskiden `!isAdmin` koşuluyla
                    // gösteriliyordu; kimlik doğrulaması geldikten sonra her yeni
                    // hesap `.admin` açıldığı için davet edilen ortak elindeki
                    // kodu girecek hiçbir yer bulamıyordu — özellik ölü doğmuştu.
                    // Ayrıca kendi projesinin yöneticisi olan biri, başkasının
                    // projesine ortak olarak davet edilebilir; bu kartı role
                    // bağlamak o durumu da imkânsız kılıyordu.
                    joinCard

                    if isAdmin { restoreCard }

                    Spacer().frame(height: 90)
                }
                .padding(.horizontal, 16)
            }
        }
        // "-sheet plans" → paket ekranı doğrudan açılır.
        //
        // `LaunchConfig.sheet` bugüne kadar YALNIZCA proje ekranında
        // okunuyordu; pano üstünde açılabilen bir sheet yoktu. Paket ekranı
        // ilk örnek ve dört ayrı duruma göre farklı görünüyor (yayın öncesi,
        // ücretsiz, sınırda, ücretli) — her birini elle dolaşarak açmak,
        // görsel karşılaştırmayı pratikte yapılmaz kılardı.
        .onAppear {
            if LaunchConfig.sheet == "plans" { paketSunumu = PaketSunumu(sinirdaki: false) }
            // "-sheet partner" → ortak karşılaması. Onsuz bu ekran yalnızca
            // GERÇEK bir davet kodu kullanılarak görülebilirdi: kod üretmek,
            // ikinci bir hesapla girmek ve kodu harcamak gerekirdi. Görsel
            // doğrulama pratikte yapılamaz olurdu.
            if LaunchConfig.sheet == "partner" {
                viewModel.joinedAsPartner = "1224 Ada / 1 Parsel"
            }
        }
        // Çekerek yenileme — gerekçe ProjectDetailView'da.
        .refreshable { await viewModel.refresh() }
        .fileImporter(isPresented: $showRestorePicker,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false,
                      onCompletion: loadBackup)
        // SONUÇ ŞERİTLE DEĞİL UYARIYLA. Geri yükleme birkaç rakam ve iki
        // uyarı taşıyor (belgeler gelmedi, ortaklar yeniden davet edilmeli);
        // kaybolan bir şerit bunları taşıyamaz ve kullanıcı neyin eksik
        // kaldığını hiç öğrenemez.
        .alert("Geri yüklendi",
               isPresented: Binding(get: { restoreSummary != nil },
                                    set: { if !$0 { restoreSummary = nil } })) {
            Button("Tamam", role: .cancel) { restoreSummary = nil }
        } message: {
            Text(restoreSummary?.message ?? "")
        }
        .alert("Geri yüklenemedi",
               isPresented: Binding(get: { restoreError != nil },
                                    set: { if !$0 { restoreError = nil } })) {
            Button("Tamam", role: .cancel) { restoreError = nil }
        } message: {
            Text(restoreError ?? "")
        }
        .alert(restoreRefusal?.title ?? "",
               isPresented: Binding(get: { restoreRefusal != nil },
                                    set: { if !$0 { restoreRefusal = nil } })) {
            Button("Tamam", role: .cancel) { restoreRefusal = nil }
        } message: {
            Text(restoreRefusal?.message ?? "")
        }
        .task(id: viewModel.restorePending) {
            slowRestore = false
            guard viewModel.restorePending else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { slowRestore = true }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        // KOTA DENETİMİ FORMDAN ÖNCE (16 Eki 2026).
        //
        // Önceden form sonuna kadar açılıyordu: kullanıcı ada, parsel, ilçe,
        // il, kat ve daire sayısını giriyor, "Projeyi Oluştur"a basıyor ve
        // ANCAK O ZAMAN reddediliyordu — üstelik 2,6 saniyede sönen bir
        // şeritle. Emek boşa gidiyor, mesaj kayboluyor ve satın almaya en
        // yakın anda ürün susuyordu.
        //
        // `addProject` içindeki boğaz KALDIRILMADI: orası son savunma ve
        // proje açmanın başka bir yolu eklenirse onu da yakalar. Buradaki
        // denetim kullanıcıyı korumak için, kuralı uygulamak için değil.
        .floatingActionButton("Yeni Proje", visible: isAdmin) {
            if planAtLimit {
                paketSunumu = PaketSunumu(sinirdaki: true)
            } else {
                showNewProject = true
            }
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
        .sheet(item: $paketSunumu) { sunum in
            PlansSheet(sinirdaki: sunum.sinirdaki)
        }
        // ORTAK KARŞILAMASI — katılma ekranı kapandıktan SONRA panoda açılıyor.
        // Katılma ekranının içinde gösterilemezdi: o ekran kendini kapatıyor.
        .sheet(isPresented: Binding(get: { viewModel.joinedAsPartner != nil },
                                    set: { if !$0 { viewModel.joinedAsPartner = nil } })) {
            PartnerWelcomeSheet(projectTitle: viewModel.joinedAsPartner ?? "") {
                viewModel.joinedAsPartner = nil
            }
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
    /// Arşivlenmiş projeler — GİZLENMİYOR, katlanıyor.
    ///
    /// Listeden büsbütün çıkarmak, kullanıcının "hepsi bu" sanacağı bir yalan
    /// olurdu (aynı ders `prefix(4)` ve yüklenemeyen projelerde iki kez
    /// öğrenildi). Kapsam da yazılı: bu projeler yukarıdaki portföy
    /// toplamlarına ve m² karşılaştırmasına GİRMİYOR.
    @ViewBuilder
    private var archivedSection: some View {
        let arsiv = viewModel.archivedProjects(for: appState.currentUser)
        if !arsiv.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showArchived.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showArchived ? "chevron.down" : "chevron.right")
                            .iconFont(11, weight: .bold)
                        Text("Arşiv · \(arsiv.count) proje")
                            .font(.manrope(12.5, .bold))
                        Spacer()
                    }
                    .foregroundColor(Palette.textSecondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }

                if showArchived {
                    Text("Bu projeler portföy toplamlarına ve m² karşılaştırmasına dahil değil.")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .padding(.bottom, 8)

                    ForEach(arsiv) { project in
                        NavigationLink(value: Route.project(project.id)) {
                            ProjectCardView(project: project)
                                .opacity(0.65)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 10)
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    /// Yükleme hatası — boş durumdan AYRI ve geri dönüşü var.
    private func loadErrorState(_ mesaj: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "exclamationmark.triangle.fill")
                .iconFont(22, weight: .semibold)
                .foregroundColor(Palette.alertInk)
                .frame(width: 54, height: 54)
                .background(Palette.alertTint)
                .cornerRadius(17)

            Text("Veriler yüklenemedi")
                .font(.sora(17, .bold))
                .foregroundColor(Palette.ink)
                .padding(.top, 4)

            // SEBEBİ YAZILI: "bir hata oluştu" kullanıcıya hiçbir şey
            // söylemiyor ve destek kanalı da olmadığı için (madde 72) sorunun
            // izi tamamen kayboluyordu.
            Text(mesaj)
                .font(.manrope(12.5, .medium))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 6)
                .padding(.horizontal, 8)

            Text("Verilerin duruyor — bu bir bağlantı ya da izin sorunu.")
                .font(.manrope(11.5, .medium))
                .foregroundColor(Palette.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text(viewModel.isRefreshing ? "Deneniyor…" : "Tekrar dene")
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background(Palette.accent)
                    .cornerRadius(13)
            }
            .disabled(viewModel.isRefreshing)
            .padding(.top, 16)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
        .cornerRadius(18)
        .padding(.top, 18)
    }

    /// İçeriği okunamayan projeler — listeden SESSİZCE eksilmesinler (madde 56).
    @ViewBuilder
    private var failedProjectsStrip: some View {
        if !viewModel.failedProjects.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.failedProjects.count) proje yüklenemedi")
                    .font(.manrope(12.5, .bold))
                    .foregroundColor(Palette.alertInk)
                Text(viewModel.failedProjects.map(\.title).joined(separator: ", "))
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(2)
                Text("Bu projelerin rakamları aşağıdaki toplamlara DAHİL DEĞİL.")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.alertTint)
            .cornerRadius(14)
            .padding(.top, 14)
        }
    }

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

    // MARK: Paket satırı (madde 87)

    /// Panoda SABİT duran sessiz giriş.
    ///
    /// NEDEN PANODA: paketlerin tek görünürlük yolu hesap kartı olsaydı,
    /// kullanıcı avatara dokunmayı akıl etmedikçe ürünün bir sınırı olduğunu
    /// HİÇ öğrenemezdi — ve bunu ilk kez, ikinci projesini açamadığı an
    /// öğrenirdi. Fiyatı reddedilerek öğrenmek, satın alma kararının
    /// verilebileceği en kötü an.
    ///
    /// NEDEN ARA ARA ÇIKAN BİR PENCERE DEĞİL: araya giren tanıtım, reklamın
    /// ta kendisi. Reklamın neden reddedildiği `Plan.swift`te yazılı ve üç
    /// gerekçesi de kendi ürününü tanıtan pencere için aynen geçerli. Bu
    /// satır kullanıcıyı hiç kesmiyor ama her an orada.
    ///
    /// SINIRA ÇARPINCA SATIR DEĞİŞMİYOR, TONU DEĞİŞİYOR. Aynı yerde duruyor;
    /// yalnızca rengi ve cümlesi durumu söylüyor. Sınıra çarpınca YENİ bir
    /// kartın belirmesi, kullanıcının ekranda yerini kaybetmesine yol açardı.
    private var planRow: some View {
        Button {
            paketSunumu = PaketSunumu(sinirdaki: planAtLimit)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: planAtLimit ? "exclamationmark.circle" : "square.stack.3d.up")
                    .iconFont(14, weight: .semibold)
                    .foregroundColor(planAtLimit ? Palette.accent : Palette.textMuted)
                    .frame(width: 38, height: 38)
                    .background(planAtLimit ? Palette.accentTint : Palette.fillMuted)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(planRowTitle)
                        .font(.manrope(13, .bold))
                        .foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(planRowDetail)
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .iconFont(11, weight: .bold)
                    .foregroundColor(Palette.textFaded)
            }
            .padding(13)
            .background(Palette.surface)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(planAtLimit ? Palette.accent : Palette.border,
                            lineWidth: planAtLimit ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Kullanıcı ŞU AN sınırda mı — kararı `Quota` veriyor, bu ekran değil.
    ///
    /// Sayıyı burada yeniden hesaplamak ("projects.count >= 1" gibi) iki
    /// ayrı doğruluk kaynağı yaratırdı: arşivlenmiş projenin sayılmaması
    /// kuralı `Quota`da yaşıyor ve burada kopyalansaydı sessizce ayrışırdı.
    private var planAtLimit: Bool {
        guard let user = appState.currentUser else { return false }
        if case .wouldExceedProjects = Quota.canCreateProject(viewModel.quotaSnapshot(for: user),
                                                              entitlement: viewModel.entitlement) {
            return true
        }
        return false
    }

    private var planRowTitle: String {
        switch viewModel.entitlement {
        case .resolving: return "Paketler"
        case .plan(.ucretsiz):    return planAtLimit ? "Aktif proje sınırındasın" : "Ücretsiz katman"
        case .plan(let plan):     return "\(plan.displayName) paketi"
        }
    }

    /// Paket sınırının dışında kalıp salt okunur olan proje sayısı.
    private var kilitliProjeSayisi: Int {
        viewModel.activeProjects(for: appState.currentUser).filter {
            if case .overLimit = viewModel.writeBlock(for: $0.id) { return true }
            return false
        }.count
    }

    /// SINIRDAYKEN İKİ ÇIKIŞ DA YAZILI: arşivlemek ücretsiz, paket ücretli.
    /// Yalnızca paketi göstermek, kullanıcının zaten hakkı olan ücretsiz
    /// çözümü saklamak olurdu.
    ///
    /// SALT OKUNUR PROJE VARSA ÖNCE O SÖYLENİYOR (25 Eki 2026): satır sınır
    /// rengindeyken "paketini gör" demek, kişiye neden uyarıldığını
    /// söylememek olurdu.
    private var planRowDetail: String {
        let kilitli = kilitliProjeSayisi
        if kilitli > 0 {
            return "\(kilitli) proje salt okunur · biten projeyi arşivle ya da paketini yükselt"
        }
        switch viewModel.entitlement {
        case .resolving:
            return "Paketin kontrol ediliyor"
        case .plan(.ucretsiz):
            return planAtLimit
                ? "Biten projeyi arşivle ya da paketlere bak"
                : Plan.ucretsiz.highlights.joined(separator: " · ")
        case .plan:
            return "Paketini gör ya da değiştir"
        }
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
                // AX'te satır DİKEY: üç sütun (ad · yüzde · ₺/m²) yan yana
                // sığmıyor ve üçü birden kırpılıyordu.
                AdaptiveTileRow(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        // AX BOYUTUNDA KESİLMİYOR (2 Eyl 2026 · cihaz turu).
                        // Gerçek telefonda en büyük metinde satır "9999 Ada /
                        // …", "100 A…", "140 A…" oluyordu: karşılaştırma
                        // tablosunun SATIR BAŞLIĞI, yani hangi projeden
                        // bahsedildiği okunamıyordu. Aynı ders proje
                        // başlığında ve `financeTile`da yazılı.
                        Text(row.title)
                            .font(.manrope(12, .semiBold))
                            .foregroundColor(Palette.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                        // KAPSAM SATIRI. m² maliyetinin paydasına yalnızca
                        // alanı GİRİLMİŞ daireler giriyor, oysa pay projenin
                        // tamamının gideri — kapsam eksikse rakam
                        // (toplam/girili) oranı kadar ŞİŞİYOR (20 dairenin
                        // 4'ü girili ise 5 KAT). Rapor ekranı bunu zaten
                        // yazıyordu, bu tablo yazmıyordu; aynı rakamın bir
                        // ekranda dürüst diğerinde yanıltıcı olması madde 1'in
                        // dersinin ihlaliydi. Rakamı "düzeltmek" seçenek
                        // değil: girilmemiş dairenin alanı BİLİNMİYOR ve
                        // madde 14'te uydurma varsayılanlar kaldırıldı.
                        if row.missingCount > 0 && row.perM2 != nil {
                            Text("\(row.measuredCount)/\(row.measuredCount + row.missingCount) dairenin alanı girili")
                                .font(.manrope(10, .medium))
                                .foregroundColor(Palette.alertInk)
                                .lineLimit(1)
                        }
                    }
                    // Dikey düzende `Spacer()` satırı uçtan uca açardı.
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    if let margin = row.margin {
                        Text(Fmt.signedPercent(margin))
                            .font(.manrope(11, .bold))
                            .foregroundColor(margin >= 0 ? Palette.success : Palette.alertInk)
                    }
                    // Alan girilmemiş projede "—": sıfır yazmak "bedava inşa
                    // edildi" demek olurdu.
                    // SABİT 96 pt YALNIZCA NORMAL BOYUTTA: AX'te rakam o
                    // genişliğe sığmayıp sarılıyor ve satır bozuluyordu.
                    Text(row.perM2.map(Fmt.costPerArea) ?? "—")
                        .font(.sora(12, .bold))
                        .foregroundColor(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 96,
                               alignment: .trailing)
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

            // Eksik kapsam SIRALAMAYI da bozuyor: şişmiş rakam projeyi
            // listenin pahalı ucuna oturtuyor. Kırpmayı yazdığımız gibi
            // (yukarıdaki "+n proje daha") bunu da yazıyoruz.
            let eksikKapsam = rows.contains { $0.missingCount > 0 && $0.perM2 != nil }
            Text("Sıralama m² maliyetine göre. Yüzde, satışa oranla satış−gider farkı; kalan inşaat maliyeti düşülmemiştir."
                 + (eksikKapsam ? " Alanı eksik girilmiş projede m² maliyeti olduğundan yüksek çıkar ve sıralamayı yukarı taşır." : ""))
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

    // MARK: Yedekten geri yükleme (madde 75)

    /// KARTIN YERİ BİLİNÇLİ: `joinCard` ile yan yana, listenin en altında ve
    /// projesi olmayan kullanıcıda ekranın ortasında.
    ///
    /// Bu düğmeyi arayacak kişi telefonunu yeni kaybetmiş, yeni telefonuna
    /// girmiş ve ekranında hiç proje yok. Ayarların içine gömülseydi tam da
    /// ihtiyaç duyulduğu anda bulunamazdı.
    private var restoreCard: some View {
        Button {
            showRestorePicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .iconFont(15, weight: .semibold)
                    .foregroundColor(Palette.accent)
                    .frame(width: 38, height: 38)
                    .background(Palette.accentTint)
                    .cornerRadius(12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yedekten geri yükle")
                        .font(.manrope(13.5, .bold))
                        .foregroundColor(Palette.ink)
                    // SUNUCU ONAYI BEKLENİYOR: proje panoda ANCAK iki aşama da
                    // onaylanınca görünüyor. Ağ arada koparsa yazma kuyrukta
                    // bekliyor; bunu söylemek, kişinin tekrar tekrar dosya
                    // seçmesini önlüyor.
                    Text(viewModel.restorePending
                         ? (slowRestore ? "Bağlantı bekleniyor · sunucu onaylamadan tamamlanmış sayılmaz"
                                        : "Sunucuya yazılıyor…")
                         : "Dışa aktardığın Yedek.json dosyasını seç")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if viewModel.restorePending { ProgressView().tint(Palette.textTertiary) }
            }
            .padding(14)
            .background(Palette.surface)
            .cornerRadius(16)
            .dashedBorder(Palette.dashed, radius: 16)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.restorePending)
        .padding(.top, 10)
    }

    private func loadBackup(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            restoreError = "Dosya seçilemedi"
        case .success(let urls):
            guard let url = urls.first else { return }
            // İçe aktarılan dosya UYGULAMANIN KUMU DIŞINDA; erişim açıkça
            // istenmeli ve kapatılmalı, yoksa okuma sessizce boş döner.
            let erisim = url.startAccessingSecurityScopedResource()
            defer { if erisim { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let backup = try ProjectExporter.decodeBackup(data)
                // "Geri yüklendi" ANCAK sunucu onayından sonra. Eskiden geri
                // yükleme eşzamanlıydı ve uyarı sunucuya tek bayt gitmeden
                // açılıyordu; ret gelirse 2,6 saniyelik "kaydedilemedi"
                // şeridi o uyarının ARKASINDA kalıyordu.
                let kullanici = appState.currentUser
                Task {
                    switch await viewModel.restore(from: backup, user: kullanici) {
                    case .restored(let ozet): restoreSummary = ozet
                    case .refused(.busy):     break
                    case .refused(let red):   restoreRefusal = red
                    }
                }
            } catch let error as ProjectExporter.BackupError {
                restoreError = error.errorDescription
            } catch {
                restoreError = "Dosya okunamadı"
            }
        }
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
                    // PAKET SINIRININ DIŞINDA KALAN PROJE KARTTA DA SÖYLENİYOR:
                    // kişi hangi projede kayıt girebileceğini proje proje açıp
                    // denemeden görmeli. Arşivdekiler ayrı bölümde durduğu için
                    // orada ayrıca işaret gerekmiyor.
                    if case .overLimit = viewModel.writeBlock(for: project.id) {
                        Label("Salt okunur · paket sınırı", systemImage: "lock")
                            .font(.manrope(11, .semiBold))
                            .foregroundColor(Palette.accent)
                            .padding(.top, 3)
                    }
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
