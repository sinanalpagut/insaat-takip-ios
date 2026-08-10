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

    let projectId: String

    enum Tab: String, CaseIterable {
        case malzemeler = "Malzemeler"
        case daireler = "Daireler"
        case ortaklar = "Ortaklar"
        case belgeler = "Belgeler"
    }

    /// Alt sayfalar — tek bir sheet(item:) ile yönetilir.
    enum ActiveSheet: Identifiable {
        case materialLog(materialId: String)
        case receipt
        case invite
        case apartmentDetail(apartmentId: String)
        case saleForm(apartmentId: String?)
        case upload

        var id: String {
            switch self {
            case .materialLog(let id):     return "log-\(id)"
            case .receipt:                 return "receipt"
            case .invite:                  return "invite"
            case .apartmentDetail(let id): return "apt-\(id)"
            case .saleForm(let id):        return "sale-\(id ?? "yeni")"
            case .upload:                  return "upload"
            }
        }
    }

    @State private var tab: Tab = .malzemeler
    @State private var activeSheet: ActiveSheet?
    @State private var documentFilter: DocumentsTabView.Filter = .tumu
    @State private var didApplyLaunchConfig = false
    @State private var showPhotos = false
    @State private var showReport = false

    private var isAdmin: Bool { appState.isAdmin }

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
                            // Ortak salt okunur: yalnızca satılmış daire detayına bakabilir.
                            if apartment.isSold { activeSheet = .apartmentDetail(apartmentId: apartment.id) }
                            return
                        }
                        activeSheet = apartment.isSold
                            ? .apartmentDetail(apartmentId: apartment.id)
                            : .saleForm(apartmentId: apartment.id)
                    }
                case .ortaklar:
                    PartnersTabView(projectId: projectId)
                case .belgeler:
                    DocumentsTabView(projectId: projectId, filter: documentFilter)
                }
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .floatingActionButton(fabTitle ?? "", visible: isAdmin && fabTitle != nil) {
            switch tab {
            case .malzemeler: activeSheet = .receipt
            case .daireler:   activeSheet = .saleForm(apartmentId: nil)
            case .ortaklar:   activeSheet = .invite
            case .belgeler:   activeSheet = .upload
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
        }
        .navigationDestination(isPresented: $showPhotos) {
            SitePhotosView(projectId: projectId)
        }
        .navigationDestination(isPresented: $showReport) {
            ReportView(projectId: projectId)
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
            case "log":     activeSheet = .materialLog(materialId: "p1-Ø12")
            case "receipt": activeSheet = .receipt
            case "invite":  activeSheet = .invite
            case "apt":     activeSheet = .apartmentDetail(apartmentId: "p1-7")
            case "sale":    activeSheet = .saleForm(apartmentId: nil)
            case "upload":  activeSheet = .upload
            default: break
            }
        }
    }

    /// Sekme başına FAB başlığı (yalnızca yönetici).
    private var fabTitle: String? {
        switch tab {
        case .malzemeler: return "Fiş Ekle"
        case .daireler:   return "Satış Ekle"
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
                activeSheet = .saleForm(apartmentId: id)
            }
        case .saleForm(let apartmentId):
            SaleFormSheet(projectId: projectId, apartmentId: apartmentId)
        case .upload:
            UploadSheet(projectId: projectId)
        }
    }

    // MARK: Koyu başlık

    private func header(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                DarkHeaderButton(systemName: "chevron.left") { dismiss() }

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

                // Şantiye fotoğrafları ve dönem raporu kısayolları
                Menu {
                    Button {
                        showPhotos = true
                    } label: {
                        Label("Şantiye Fotoğrafları", systemImage: "camera")
                    }
                    Button {
                        showReport = true
                    } label: {
                        Label("Dönem Raporu", systemImage: "chart.bar")
                    }
                } label: {
                    darkHeaderIcon("ellipsis")
                }

                if tab == .malzemeler {
                    Text(appState.currentUser?.role.chipText ?? "")
                        .font(.manrope(9.5, .extraBold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(7)
                }
            }
            .padding(.top, 6)

            // Malzemeler sekmesi: SATIŞ / MALZEME / NET finans şeridi
            if tab == .malzemeler {
                HStack(spacing: 9) {
                    financeTile("Satış", Fmt.compactMoney(viewModel.totalSales(for: projectId)),
                                background: Color.white.opacity(0.07), valueColor: .white)
                    financeTile("Malzeme", Fmt.compactMoney(viewModel.totalMaterialCost(for: projectId)),
                                background: Color.white.opacity(0.07), valueColor: .white)
                    financeTile("Net", Fmt.compactMoney(viewModel.netAmount(for: projectId)),
                                background: Palette.accent.opacity(0.22), valueColor: Palette.accentLight)
                }
                .padding(.top, 16)
            }

            // Belgeler sekmesi: Tümü / Mimari / Statik / Ruhsat filtre çipleri
            if tab == .belgeler {
                HStack(spacing: 8) {
                    ForEach(DocumentsTabView.Filter.allCases, id: \.self) { option in
                        Button {
                            documentFilter = option
                        } label: {
                            Text(option.rawValue)
                                .font(.manrope(12.5, .bold))
                                .foregroundColor(documentFilter == option ? Palette.ink : .white.opacity(0.7))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(documentFilter == option ? Color.white : Color.white.opacity(0.08))
                                .cornerRadius(11)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, tab == .malzemeler || tab == .belgeler ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink.ignoresSafeArea(edges: .top))
    }

    /// Sekmeye göre değişen alt başlık.
    private func headerSubtitle(_ project: Project) -> String {
        switch tab {
        case .malzemeler:
            return project.meta
        case .daireler:
            let collected = Fmt.compactMoney(viewModel.collectedAmount(for: projectId))
            let outstanding = Fmt.compactMoney(viewModel.outstandingAmount(for: projectId))
            return "Tahsilat \(collected) · Kalan alacak \(outstanding)"
        case .ortaklar:
            return "\(viewModel.partners(for: projectId).count) ortak · hisse dağılımı tanımlı"
        case .belgeler:
            let role = appState.currentUser?.role ?? .partner
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
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.08))
            .cornerRadius(11)
    }

    private func financeTile(_ label: String, _ value: String, background: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .smallCapsLabel(size: 9.5, color: .white.opacity(0.45), tracking: 1.1)
            Text(value)
                .font(.sora(15, .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .cornerRadius(13)
    }

    // MARK: Sekme çubuğu

    private var tabBar: some View {
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
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}
