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

    @State private var pickedItem: PhotosPickerItem?

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

                        // Görseller şeridi
                        HStack {
                            Text("Görseller")
                                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                            Spacer()
                            Text("Tümü (\(max(apartment.imageLabels.count, 6)))")
                                .font(.manrope(12, .bold))
                                .foregroundColor(Palette.accent)
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
                                dismiss()
                                // Sheet kapanışıyla çakışmaması için kısa gecikme
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                    onEdit(apartment.id)
                                }
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
    }

    private func subtitle(_ apartment: Apartment) -> String {
        var parts = ["\(apartment.floor). Kat"]
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

    /// 3 kolonlu görsel şeridi: dolu yuvalar + yöneticiye "Görsel Ekle".
    private func imageStrip(_ apartment: Apartment) -> some View {
        HStack(spacing: 9) {
            ForEach(apartment.imageLabels.prefix(2), id: \.self) { label in
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(Palette.textTertiary)
                    Text(label)
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.textMuted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 108)
                .background(Palette.fillSubtle)
                .cornerRadius(13)
                .dashedBorder(Palette.dashed, radius: 13, lineWidth: 1.2)
            }

            if isAdmin {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    VStack(spacing: 8) {
                        Text("+")
                            .font(.manrope(17, .semiBold))
                            .foregroundColor(Palette.accent)
                            .frame(width: 34, height: 34)
                            .background(Palette.accentTint)
                            .cornerRadius(10)
                        Text("Görsel Ekle")
                            .font(.manrope(11.5, .bold))
                            .foregroundColor(Palette.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 108)
                    .background(Palette.surface)
                    .cornerRadius(13)
                    .dashedBorder(Palette.dashed, radius: 13, lineWidth: 1.2)
                }
                .onChange(of: pickedItem) { _ in
                    if pickedItem != nil {
                        viewModel.flash("Görsel eklendi")
                        pickedItem = nil
                    }
                }
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
