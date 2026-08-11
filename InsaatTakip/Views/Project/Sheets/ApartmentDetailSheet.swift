import SwiftUI
import PhotosUI

// MARK: - Daire Detayı & Görselleri (Ekran 13)
// Satılmış daire kartına dokununca açılır: satış bedeli bloğu (yeşil),
// GÖRSELLER şeridi (dolu yuvalar + admin için "Görsel Ekle"),
// Ödeme / Teslim durumu satırları ve yöneticiye "Satış Kaydını Düzenle" CTA'sı.

struct ApartmentDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let apartmentId: String
    /// "Satış Kaydını Düzenle" — üst görünüm satış formunu açar.
    var onEdit: (String) -> Void

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    private var apartment: Apartment? {
        viewModel.apartments.first { $0.id == apartmentId }
    }

    private var isAdmin: Bool { appState.isAdmin }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let apartment {
                SheetHeader(title: "Daire No \(apartment.apartmentNumber)",
                            subtitle: subtitle(apartment)) { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        priceBlock(apartment)
                            .padding(.top, 16)

                        // Görseller şeridi — sayaç gerçek görsel adedini gösterir
                        HStack {
                            Text("Görseller")
                                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                            Spacer()
                            let photos = viewModel.photos(forApartment: apartment.id)
                            if !photos.isEmpty {
                                Text("Tümü (\(photos.count))")
                                    .font(.manrope(12, .bold))
                                    .foregroundColor(Palette.accent)
                            }
                        }
                        .padding(.top, 20)

                        imageStrip(apartment)
                            .padding(.top, 10)

                        // Detay satırları
                        detailRow("Ödeme durumu", apartment.paymentStatus?.rawValue ?? "—")
                            .padding(.top, 14)
                        Divider().overlay(Palette.divider)
                        detailRow("Teslim durumu", apartment.deliveryNote)

                        if isAdmin {
                            PrimaryButton(title: "Satış Kaydını Düzenle") {
                                // Üst görünüm sheet kapanınca satış formunu açar;
                                // sabit gecikmeye dayanan zincirleme kaldırıldı.
                                onEdit(apartment.id)
                                dismiss()
                            }
                            .padding(.top, 16)
                        }

                        Spacer().frame(height: 24)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .onChange(of: pickedItems) { _ in
            if let apartment { importPickedPhotos(for: apartment.id) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let apartment {
                    viewModel.addApartmentPhotos(role: appState.currentUser?.role ?? .partner,
                                                 apartmentId: apartment.id, images: [image])
                }
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func subtitle(_ apartment: Apartment) -> String {
        var parts = [apartment.floorLabel]
        if let buyer = apartment.buyerName { parts.append(buyer) }
        if let date = apartment.saleDateText { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    /// Yeşil satış bedeli bloğu + ödeme çipi.
    private func priceBlock(_ apartment: Apartment) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Satış Bedeli")
                    .smallCapsLabel(size: 10, color: Palette.successInk.opacity(0.6), tracking: 1.1)
                Text(Fmt.compactMoney(apartment.price))
                    .font(.sora(26, .bold))
                    .foregroundColor(Palette.success)
            }
            Spacer()
            StatusChip(text: apartment.paymentStatus == .tamamlandi ? "Tahsil Edildi" : (apartment.paymentStatus?.rawValue ?? ""),
                       background: apartment.paymentStatus == .tamamlandi ? Palette.successChip : Palette.pendingTint,
                       foreground: apartment.paymentStatus == .tamamlandi ? Palette.successInk : Palette.pendingInk)
        }
        .padding(16)
        .background(Palette.successTint)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.successBorder, lineWidth: 1))
    }

    /// 3 kolonlu görsel şeridi: dolu kareler (yatay kaydırmalı) + yöneticiye ekleme yuvası.
    private func imageStrip(_ apartment: Apartment) -> some View {
        let photos = viewModel.photos(forApartment: apartment.id)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(photos) { photo in
                    photoTile(photo)
                }

                if isAdmin {
                    // Galeriden seç
                    PhotosPicker(selection: $pickedItems, maxSelectionCount: 6, matching: .images) {
                        addTile(icon: "photo.on.rectangle", title: "Galeriden")
                    }
                    // Kameradan çek
                    Button {
                        showCamera = true
                    } label: {
                        addTile(icon: "camera.fill", title: "Fotoğraf Çek")
                    }
                }
            }
        }
        .frame(height: 112)
    }

    /// Dolu görsel karesi; yöneticide uzun basınca silme seçeneği çıkar.
    private func photoTile(_ photo: ApartmentPhoto) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 108)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            } else {
                // Tasarımdaki yer tutucu kare (henüz fotoğraf yüklenmemiş yuva)
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(Palette.textTertiary)
                    Text(photo.label)
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.textMuted)
                }
                .frame(width: 104, height: 108)
                .background(Palette.fillSubtle)
                .cornerRadius(13)
                .dashedBorder(Palette.dashed, radius: 13, lineWidth: 1.2)
            }
        }
        .contextMenu {
            if isAdmin {
                Button(role: .destructive) {
                    viewModel.removeApartmentPhoto(role: appState.currentUser?.role ?? .partner,
                                                   photoId: photo.id)
                } label: {
                    Label("Görseli sil", systemImage: "trash")
                }
            }
        }
    }

    /// Kesikli "ekle" yuvası (galeri / kamera).
    private func addTile(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Palette.accent)
                .frame(width: 34, height: 34)
                .background(Palette.accentTint)
                .cornerRadius(10)
            Text(title)
                .font(.manrope(11.5, .bold))
                .foregroundColor(Palette.accent)
        }
        .frame(width: 104, height: 108)
        .background(Palette.surface)
        .cornerRadius(13)
        .dashedBorder(Palette.dashed, radius: 13, lineWidth: 1.2)
    }

    /// Galeriden seçilenleri küçültüp daireye ekler.
    private func importPickedPhotos(for apartmentId: String) {
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
                viewModel.addApartmentPhotos(role: role, apartmentId: apartmentId, images: ready)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.manrope(13, .medium))
                .foregroundColor(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.manrope(13, .bold))
                .foregroundColor(Palette.ink)
        }
        .padding(.vertical, 13)
    }
}
