import SwiftUI
import PhotosUI

// MARK: - Şantiye Fotoğrafları (Ekran 09)
// Haftalık ilerleme kaydı: "Bu hafta" canlı yuvalar (galeriden ekleme),
// "Geçen hafta" arşiv kutuları (kamera glifi + tarih). Admin FAB: ＋ Fotoğraf Ekle.

struct SitePhotosView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showPicker = false

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    private var isAdmin: Bool { appState.isAdmin }

    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    let photos = viewModel.photos(for: projectId)
                    let currentWeek = photos.filter(\.isCurrentWeek)
                    let archive = photos.filter { !$0.isCurrentWeek }

                    if photos.isEmpty {
                        emptyState
                            .padding(.top, 18)
                    } else {
                        weekHeader("Bu hafta", count: currentWeek.count)
                            .padding(.top, 18)

                        LazyVGrid(columns: columns, spacing: 7) {
                            ForEach(currentWeek) { photo in
                                currentWeekTile(photo)
                            }
                        }
                        .padding(.top, 10)

                        if !archive.isEmpty {
                            weekHeader("Geçen hafta", count: archive.count)
                                .padding(.top, 24)

                            LazyVGrid(columns: columns, spacing: 7) {
                                ForEach(archive) { photo in
                                    archiveTile(photo)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }

                    Spacer().frame(height: 90)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .floatingActionButton("Fotoğraf Ekle", visible: isAdmin) {
            showPicker = true
        }
        .photosPicker(isPresented: $showPicker, selection: $pickedItems,
                      maxSelectionCount: 6, matching: .images)
        .onChange(of: pickedItems) { _ in
            importPickedPhotos()
        }
        .toastOverlay(viewModel.toast)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                DarkHeaderButton(systemName: "chevron.left") { dismiss() }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Şantiye Kaydı")
                        .font(.sora(17, .bold))
                        .foregroundColor(.white)
                    Text("\(project?.title ?? "") · \(viewModel.photos(for: projectId).count) fotoğraf")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink.ignoresSafeArea(edges: .top))
    }

    /// Hiç fotoğraf yokken gösterilen kesikli davet kartı.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Palette.textTertiary)
            Text("Henüz şantiye fotoğrafı yok")
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.ink)
            Text(isAdmin ? "Haftalık ilerlemeyi \"＋ Fotoğraf Ekle\" ile kaydetmeye başla"
                         : "Yönetici fotoğraf ekledikçe burada görünecek")
                .font(.manrope(11.5, .medium))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .background(Palette.fillSubtle)
        .cornerRadius(16)
        .dashedBorder(Palette.dashed, radius: 16)
    }

    private func weekHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.manrope(15, .bold))
                .foregroundColor(Palette.ink)
            Spacer()
            Text("\(count) fotoğraf")
                .font(.manrope(12, .semiBold))
                .foregroundColor(Palette.textSecondary)
        }
    }

    /// Bu haftanın yuvası: fotoğraf seçildiyse görsel, değilse kesikli dropzone.
    /// Color.clear + aspectRatio: hücre, ızgara sütununu kare olarak doldurur.
    @ViewBuilder
    private func currentWeekTile(_ photo: SitePhoto) -> some View {
        // Görsel içe aktarımda bir kez küçültülüp saklanır; burada yalnızca çizilir.
        if let image = photo.image {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack(spacing: 7) {
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(Palette.textTertiary)
                        Text(photo.dateText)
                            .font(.manrope(11.5, .semiBold))
                            .foregroundColor(Palette.textMuted)
                    }
                )
                .background(Palette.fillMuted.opacity(0.6))
                .cornerRadius(12)
                .dashedBorder(Palette.dashed, radius: 12, lineWidth: 1.2)
        }
    }

    /// Arşiv kutusu: bej zemin, kamera glifi + tarih.
    private func archiveTile(_ photo: SitePhoto) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                VStack(spacing: 7) {
                    Image(systemName: "camera")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(Palette.textTertiary)
                    Text(photo.dateText)
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                }
            )
            .background(Color(hex: 0xE8E1D8).opacity(0.55))
            .cornerRadius(12)
    }

    /// Galeriden seçilen görselleri küçültüp bu haftanın kaydına ekler.
    /// Küçültme arka planda yapılır; ham galeri verisi hiçbir zaman saklanmaz.
    private func importPickedPhotos() {
        guard !pickedItems.isEmpty else { return }
        let items = pickedItems
        pickedItems = []
        let role = appState.currentUser?.role ?? .partner

        Task.detached(priority: .userInitiated) {
            var images: [UIImage] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let thumbnail = SitePhoto.downsample(data) else { continue }
                images.append(thumbnail)
            }
            let ready = images
            await MainActor.run {
                viewModel.addSitePhotos(role: role, projectId: projectId, images: ready)
            }
        }
    }
}
