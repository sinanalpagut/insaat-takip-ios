import SwiftUI

// MARK: - Proje Detay (Ekran 02 / 04 / 05 / 11 kabuk görünümü)
// Koyu başlık sekmeye göre içerik değiştirir:
//   Malzemeler → meta satırı + finans şeridi + rol çipi
//   Daireler   → tahsilat / kalan alacak satırı
//   Ortaklar   → ortak sayısı satırı
//   Belgeler   → dosya sayısı + filtre çipleri
// Altında beyaz sekme çubuğu (aktif: ink metin + 2.5px bakır alt çizgi).

struct ProjectDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    enum Tab: String, CaseIterable {
        case malzemeler = "Malzemeler"
        case giderler = "Giderler"
        case daireler = "Daireler"
        case ortaklar = "Ortaklar"
        case belgeler = "Belgeler"
    }

    /// Alt sayfalar — tek bir sheet(item:) ile yönetilir.
    enum ActiveSheet: Identifiable {
        case materialLog(materialId: UUID)
        case receipt
        case invite
        case apartmentDetail(apartmentId: UUID)
        case apartmentEdit(apartmentId: UUID)
        case saleForm(apartmentId: UUID?)
        case upload
        case progress
        case expense

        var id: String {
            switch self {
            case .materialLog(let id):     return "log-\(id)"
            case .receipt:                 return "receipt"
            case .invite:                  return "invite"
            case .apartmentDetail(let id): return "apt-\(id)"
            case .apartmentEdit(let id):   return "aptedit-\(id)"
            case .saleForm(let id):        return "sale-\(id?.uuidString ?? "yeni")"
            case .upload:                  return "upload"
            case .progress:                return "progress"
            case .expense:                 return "expense"
            }
        }
    }

    @State private var tab: Tab = .malzemeler
    @State private var activeSheet: ActiveSheet?
    @State private var documentFilter: DocumentsTabView.Filter = .tumu
    @State private var didApplyLaunchConfig = false
    /// Daire detayı kapandıktan sonra açılacak satış düzenleme sheet'i.
    @State private var pendingSaleEdit: UUID?
    /// Daire detayından "Daire Bilgisini Düzenle" seçilince kapanışta açılacak kayıt.
    @State private var pendingApartmentEdit: UUID?

    /// BU PROJEDEKİ rol — global rol değil. Davet edilen ortak `.admin`
    /// açıldığı için global rol kullanılsa ortağa yönetici düğmeleri görünür,
    /// bastığında yazma sunucuda reddedilirdi.
    private var isAdmin: Bool {
        viewModel.projects.first { $0.id == projectId }?
            .role(for: appState.currentUser) == .admin
    }

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let project {
                header(project)
                tabBar

                // Sekme içerikleri — mantık ViewModel'de, görünümler "dumb".
                switch tab {
                case .malzemeler:
                    MaterialsTabView(projectId: projectId) { materialId in
                        activeSheet = .materialLog(materialId: materialId)
                    }
                case .daireler:
                    ApartmentsTabView(projectId: projectId) { apartment in
                        guard isAdmin else {
                            // Ortak salt okunur ama artık HER dairenin detayını
                            // görebilir: arsa sahibinin dairesini gizlemek
                            // şeffaflık iddiasıyla çelişirdi.
                            activeSheet = .apartmentDetail(apartmentId: apartment.id)
                            return
                        }
                        // Boş daireye dokunmak doğrudan satış formunu açar (hızlı yol);
                        // taahhütlü ve kat karşılığı daireler detayına gider.
                        // Boş dairenin bilgi düzenleme ekranına basılı tutarak ulaşılır.
                        activeSheet = apartment.isSellable
                            ? .saleForm(apartmentId: apartment.id)
                            : .apartmentDetail(apartmentId: apartment.id)
                    } onEditInfo: { apartment in
                        activeSheet = .apartmentEdit(apartmentId: apartment.id)
                    }
                case .giderler:
                    ExpensesTabView(projectId: projectId)
                case .ortaklar:
                    PartnersTabView(projectId: projectId)
                case .belgeler:
                    DocumentsTabView(projectId: projectId, filter: $documentFilter)
                }
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .floatingActionButton(fabTitle ?? "", visible: isAdmin && fabTitle != nil) {
            switch tab {
            case .malzemeler: activeSheet = .receipt
            case .giderler:   activeSheet = .expense
            case .daireler:   activeSheet = .saleForm(apartmentId: nil)
            case .ortaklar:   activeSheet = .invite
            case .belgeler:   activeSheet = .upload
            }
        }
        // Sheet zincirlemesi: daire detayından "Satış Kaydını Düzenle" seçilince
        // yeni sheet, sabit bir gecikmeyle değil, kapanış olayında açılır.
        .sheet(item: $activeSheet, onDismiss: {
            if let id = pendingSaleEdit {
                pendingSaleEdit = nil
                activeSheet = .saleForm(apartmentId: id)
            } else if let id = pendingApartmentEdit {
                pendingApartmentEdit = nil
                activeSheet = .apartmentEdit(apartmentId: id)
            }
        }) { sheet in
            sheetContent(sheet)
        }
        .onAppear { applyLaunchConfig() }
    }

    /// DEBUG launch argümanlarından sekme / sheet kurulumu (ekran görüntüsü akışı).
    private func applyLaunchConfig() {
        guard !didApplyLaunchConfig else { return }
        didApplyLaunchConfig = true

        switch LaunchConfig.tab {
        case "mat": tab = .malzemeler
        case "apt": tab = .daireler
        case "ptn": tab = .ortaklar
        case "doc": tab = .belgeler
        default: break
        }

        guard let sheet = LaunchConfig.sheet else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            switch sheet {
            case "log":
                if let id = viewModel.materials(for: projectId).first?.id {
                    activeSheet = .materialLog(materialId: id)
                }
            case "receipt": activeSheet = .receipt
            case "invite":  activeSheet = .invite
            case "apt":
                if let id = viewModel.apartments(for: projectId).first(where: \.countsAsRevenue)?.id {
                    activeSheet = .apartmentDetail(apartmentId: id)
                }
            case "sale":    activeSheet = .saleForm(apartmentId: nil)
            case "upload":  activeSheet = .upload
            default: break
            }
        }
    }

    /// Sekme başına FAB başlığı (yalnızca yönetici).
    /// Tamamı satılmış projede "Satış Ekle" boş bir form açacağı için gizlenir.
    private var fabTitle: String? {
        switch tab {
        case .malzemeler: return "Fiş Ekle"
        case .giderler:   return "Gider Ekle"
        case .daireler:
            // Kat karşılığı ve rezerve daireler satış formunda seçilemez;
            // `!isSold` denseydi tamamı elden çıkmış projede bile FAB görünürdü.
            let hasAvailable = viewModel.apartments(for: projectId).contains(where: \.isSellable)
            return hasAvailable ? "Satış Ekle" : nil
        case .ortaklar:   return "Ortak Davet Et"
        case .belgeler:   return "Dosya Ekle"
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .materialLog(let materialId):
            MaterialLogSheet(materialId: materialId)
        case .receipt:
            ReceiptSheet(projectId: projectId)
        case .invite:
            InviteSheet(projectId: projectId)
        case .apartmentDetail(let apartmentId):
            ApartmentDetailSheet(apartmentId: apartmentId) { id in
                pendingSaleEdit = id   // kapanışta açılır (onDismiss)
            } onEditInfo: { id in
                pendingApartmentEdit = id
            }
        case .apartmentEdit(let apartmentId):
            ApartmentEditSheet(apartmentId: apartmentId)
        case .saleForm(let apartmentId):
            SaleFormSheet(projectId: projectId, apartmentId: apartmentId)
        case .upload:
            UploadSheet(projectId: projectId)
        case .progress:
            ProgressSheet(projectId: projectId)
        case .expense:
            ExpenseSheet(projectId: projectId)
        }
    }

    // MARK: Koyu başlık

    private func header(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                DarkHeaderButton(systemName: "chevron.left", label: "Geri") { dismiss() }

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.title)
                        .font(.sora(17, .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(headerSubtitle(project))
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                // Şantiye fotoğrafları ve dönem raporu kısayolları.
                // NavigationLink(value:) ile kök rota tablosunu kullanır —
                // iOS 16'da iki ayrı isPresented hedefi üst üste kırılgandı.
                Menu {
                    NavigationLink(value: Route.photos(projectId)) {
                        Label("Şantiye Fotoğrafları", systemImage: "camera")
                    }
                    NavigationLink(value: Route.report(projectId)) {
                        Label("Dönem Raporu", systemImage: "chart.bar")
                    }
                    if isAdmin {
                        Button {
                            activeSheet = .progress
                        } label: {
                            Label("İnşaat İlerlemesi", systemImage: "slider.horizontal.3")
                        }
                    }
                } label: {
                    darkHeaderIcon("ellipsis")
                }

                // Rozet BU PROJEDEKİ rolü söylüyor. Global rol yazılsaydı davetle
                // katılan ortak da başlıkta "YÖNETİCİ" görürdü.
                Text((isAdmin ? UserRole.admin : UserRole.partner).chipText)
                    .font(.manrope(9.5, .extraBold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(7)
            }
            .padding(.top, 6)

            // SATIŞ / MALZEME / NET finans şeridi — dört sekmede de görünür.
            // Sabit başlık yüksekliği, sekme çubuğunun yerinden oynamasını önler
            // (sekme değiştirirken ikinci dokunuş kaymasın diye).
            // AX boyutunda üç karo alt alta — bkz. DashboardView portföy şeridi.
            // Sabit başlık yüksekliği gerekçesi (sekme çubuğu oynamasın)
            // korunuyor: üçü de aynı anda büyüdüğü için hizalama bozulmuyor.
            AdaptiveTileRow(spacing: 9) {
                financeTile("Satış", Fmt.compactMoney(viewModel.totalSales(for: projectId)),
                            background: Color.white.opacity(0.07), valueColor: .white)
                financeTile("Gider", Fmt.compactMoney(viewModel.totalCost(for: projectId)),
                            background: Color.white.opacity(0.07), valueColor: .white)
                // Gider defteri geldiği için "Net" artık dürüst: satış − (malzeme +
                // işçilik, taşeron, arsa, harç…). Yalnızca GİRİLEN giderleri
                // kapsadığı raporda ayrıca belirtilir.
                financeTile("Net", Fmt.compactMoney(viewModel.netAmount(for: projectId)),
                            background: Palette.accent.opacity(0.22), valueColor: Palette.accentLight)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink.ignoresSafeArea(edges: .top))
    }

    /// Sekmeye göre değişen alt başlık.
    private func headerSubtitle(_ project: Project) -> String {
        switch tab {
        case .malzemeler:
            return project.meta
        case .giderler:
            let other = viewModel.totalOtherExpenses(for: projectId)
            let material = viewModel.totalMaterialCost(for: projectId)
            return "Malzeme \(Fmt.compactMoney(material)) · Diğer \(Fmt.compactMoney(other))"
        case .daireler:
            let collected = Fmt.compactMoney(viewModel.collectedAmount(for: projectId))
            let outstanding = Fmt.compactMoney(viewModel.outstandingAmount(for: projectId))
            return "Tahsilat \(collected) · Kalan alacak \(outstanding)"
        case .ortaklar:
            let partners = viewModel.partners(for: projectId)
            let shareTotal = partners.reduce(0) { $0 + $1.sharePercent }
            return "\(partners.count) ortak · hisse %\(shareTotal) tanımlı"
        case .belgeler:
            let role: UserRole = isAdmin ? .admin : .partner
            let docs = viewModel.documents(for: projectId, role: role)
            let totalMB = docs.reduce(0) { $0 + $1.sizeMB }
            var text = "\(docs.count) dosya · \(Fmt.megabytes(totalMB))"
            if let lastUpload = viewModel.lastUploadText(for: projectId, role: role) {
                text += " · son yükleme \(lastUpload)"
            }
            return text
        }
    }

    /// Koyu başlıktaki 34px ikon butonu görünümü (NavigationLink etiketi).
    private func darkHeaderIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .iconFont(13, weight: .semibold)
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                        .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.08))
            .cornerRadius(11)
    }

    private func financeTile(_ label: String, _ value: String, background: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .smallCapsLabel(size: 9.5, color: .white.opacity(0.62), tracking: 1.1)
            // KIRPMA KALDIRILDI. `lineLimit(1)` + `minimumScaleFactor(0.8)`
            // yalnızca %20 pay veriyordu, oysa AX5'te yazı %172 büyüyor:
            // "42,65 M ₺" ekrana "42,..." olarak düşüyordu ve KESİLEN PARÇA
            // TAM OLARAK BÜYÜKLÜK EKİ — yani 42 bin ile 42 milyon ayırt
            // edilemiyordu. Bu, uygulamanın baştan beri reddettiği "yanıltıcı
            // rakam" sınıfı; kırpmak yerine karo dikey büyüyor.
            //
            // Üç karo da aynı anda büyüdüğü için hizalama bozulmuyor.
            Text(value)
                .font(.sora(15, .bold))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .cornerRadius(13)
    }

    // MARK: Sekme çubuğu

    private var tabBar: some View {
        // 5 sekme sabit genişliğe sığmıyor; yatay kaydırma eklendi.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { option in
                    Button {
                        tab = option   // Tasarım gereği geçiş anlık, cross-fade yok
                    } label: {
                        VStack(spacing: 0) {
                            Text(option.rawValue)
                                .font(.manrope(13.5, .bold))
                                .foregroundColor(tab == option ? Palette.ink : Palette.tabInactive)
                                .padding(.top, 14)
                                .padding(.bottom, 12)
                                .padding(.horizontal, 13)
                            Rectangle()
                                .fill(tab == option ? Palette.accent : Color.clear)
                                .frame(height: 2.5)
                        }
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}
