import SwiftUI
import PhotosUI

// MARK: - Şantiye Fotoğrafları (Ekran 09)
// Haftalık ilerleme kaydı: "Bu hafta" canlı yuvalar (galeriden ekleme),
// "Geçen hafta" arşiv kutuları (kamera glifi + tarih). Admin FAB: ＋ Fotoğraf Ekle.

struct SitePhotosView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: String

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

                    weekHeader("Bu hafta", count: max(currentWeek.count, 9))
                        .padding(.top, 18)

                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(currentWeek) { photo in
                            currentWeekTile(photo)
                        }
                    }
                    .padding(.top, 10)

                    weekHeader("Geçen hafta", count: max(archive.count, 14))
                        .padding(.top, 24)

                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(archive) { photo in
                            archiveTile(photo)
                        }
                    }
                    .padding(.top, 10)

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
                    Text("\(project?.title ?? "") · \(project?.photoCount ?? 0) fotoğraf")
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
        if let data = photo.imageData, let image = UIImage(data: data) {
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

    /// Galeriden seçilen görselleri bu haftanın kaydına ekler.
    private func importPickedPhotos() {
        guard !pickedItems.isEmpty else { return }
        let items = pickedItems
        pickedItems = []
        Task {
            var images: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    images.append(data)
                }
            }
            await MainActor.run {
                viewModel.addSitePhotos(role: appState.currentUser?.role ?? .partner,
                                        projectId: projectId, images: images)
            }
        }
    }
}
