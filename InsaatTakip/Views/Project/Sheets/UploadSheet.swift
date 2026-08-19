import SwiftUI
import UniformTypeIdentifiers

// MARK: - Dosya / Görsel Yükleme (Ekran 12, yalnızca yönetici)
// Tek akış: plan dosyası da şantiye görseli de aynı panelden.
// Kesikli dropzone → dosya seçimi, ilerleyen yükleme satırı, kategori çipleri,
// sürüm notu ve "Ortaklar görebilsin" anahtarı. Kapalıysa dosya yalnız yönetitiye görünür.

struct UploadSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    @State private var category: ProjectDocument.Group = .mimari
    @State private var versionNote = ""
    @State private var partnerVisible = true
    @State private var showImporter = false
    @State private var pickedURL: URL?

    // Seçilen dosya ve sahte yükleme ilerlemesi
    @State private var fileName: String?
    @State private var fileSizeMB: Double = 0

    /// Seçilen dosyanın URL'İ. Önceden yalnızca ad ve boyut taşınıyordu ve
    /// baytlara bir daha erişilemiyordu — "yükleme" tamamen sahteydi.
    /// URL güvenlik kapsamlı olabildiği için baytı ViewModel kopyalıyor
    /// (`DocumentStore.copyIn`, kapsamı kendi açıp kapatıyor).

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Dosya / Görsel Ekle",
                        subtitle: "PDF, DWG, JPG · en fazla 50 MB") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    dropzone
                        .padding(.top, 16)

                    if let fileName {
                        uploadRow(fileName)
                            .padding(.top, 10)
                    }

                    Text("Kategori")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 18)

                    FlowLayout(spacing: 9) {
                        ForEach(ProjectDocument.Group.allCases, id: \.self) { group in
                            categoryChip(group)
                        }
                    }
                    .padding(.top, 10)

                    Text("Sürüm Notu")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    TextField("Örn. Rev-6 · balkon revizyonu", text: $versionNote)
                        .font(.manrope(13.5, .semiBold))
                        .foregroundColor(Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                        .padding(.top, 8)

                    // Ortak görünürlüğü — belge bazlı yetki
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ortaklar görebilsin")
                                .font(.manrope(13.5, .bold))
                                .foregroundColor(Palette.ink)
                            Text("Kapalıysa yalnızca yönetici erişir")
                                .font(.manrope(11.5, .medium))
                                .foregroundColor(Palette.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $partnerVisible)
                            .labelsHidden()
                            .tint(Palette.accent)
                    }
                    .padding(14)
                    .background(Palette.fillSubtle)
                    .cornerRadius(13)
                    .padding(.top, 14)

                    PrimaryButton(title: "Yükle") { upload() }
                        .padding(.top, 18)

                    Spacer().frame(height: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .sheetHeight(0.85)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.pdf, .image, UTType(filenameExtension: "dwg") ?? .data],
                      allowsMultipleSelection: false) { result in
            handlePickedFile(result)
        }
    }

    // MARK: Parçalar

    /// Kesikli dosya bırakma alanı.
    private var dropzone: some View {
        Button {
            showImporter = true
        } label: {
            VStack(spacing: 10) {
                Text("+")
                    .font(.manrope(21, .semiBold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 44, height: 44)
                    .background(Palette.accentTint)
                    .cornerRadius(13)
                Text("Dosya seç veya sürükle")
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(Palette.ink)
                Text("Galeriden görsel · Dosyalar'dan plan")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 150)
            .background(Palette.fillSubtle)
            .cornerRadius(16)
            .dashedBorder(Palette.dashed, radius: 16)
        }
        .buttonStyle(.plain)
    }

    /// Seçilen dosyanın ilerleme satırı: rozet, ad, 4px bar + yüzde.
    private func uploadRow(_ name: String) -> some View {
        HStack(spacing: 12) {
            Text((name as NSString).pathExtension.uppercased().prefix(3))
                .font(.sora(10, .bold))
                .foregroundColor(Palette.alertInk)
                .frame(width: 38, height: 38)
                .background(Palette.alertTint)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 7) {
                Text(name)
                    .font(.manrope(13, .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Fmt.megabytes(fileSizeMB))
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Image(systemName: "checkmark.circle.fill")
                .iconFont(16, weight: .semibold)
                .foregroundColor(Palette.success)
        }
        .padding(12)
        .background(Palette.fillSubtle)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
    }

    private func categoryChip(_ group: ProjectDocument.Group) -> some View {
        Button {
            category = group
        } label: {
            Text(group.rawValue)
                .font(.manrope(12.5, .bold))
                .foregroundColor(category == group ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(category == group ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(category == group ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
        }
    }

    // MARK: Aksiyonlar

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        // iCloud Drive / başka uygulamalardan gelen URL'ler güvenlik kapsamlıdır;
        // erişim açılmazsa boyut okuması sessizce 0 döner ve her dosya "0,1 MB" görünürdü.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let megabytes = Double(bytes) / 1_048_576

        guard bytes > 0 else {
            viewModel.flash("Dosya okunamadı")
            return
        }
        guard megabytes <= Self.maxUploadMB else {
            viewModel.flash("Dosya \(Int(Self.maxUploadMB)) MB sınırını aşıyor")
            return
        }

        fileName = url.lastPathComponent
        fileSizeMB = megabytes
        pickedURL = url

        // SAHTE İLERLEME ÇUBUĞU KALDIRILDI. Dosya seçilir seçilmez 0,9 saniyede
        // %100'e giden bir animasyondu ve ağdaki hiçbir şeye bağlı değildi:
        // yükleme başlamadan "tamamlandı" gösteriyordu. Gerçek yükleme artık
        // "Kaydet"e basılınca başlıyor ve ilerlemesi ekranın altındaki
        // bekleyen-yazma şeridinden okunuyor — tüm yazmalarla aynı yerden,
        // ikinci bir ilerleme dili icat etmeden.
    }

    /// Sheet başlığında duyurulan sınır.
    static let maxUploadMB: Double = 50

    private func upload() {
        guard let pickedURL else {
            viewModel.flash("Önce dosya seç")
            return
        }
        let saved = viewModel.addDocument(
            role: viewModel.role(inProject: projectId, for: appState.currentUser),
            projectId: projectId,
            group: category,
            sourceURL: pickedURL,
            versionNote: versionNote,
            partnerVisible: partnerVisible)
        // Kopyalama başarısızsa sheet AÇIK kalıyor: kullanıcı hatayı görüp
        // başka dosya seçebilsin. Kapansaydı "eklendi" sanırdı.
        if saved { dismiss() }
    }
}
