import SwiftUI

// MARK: - Daireler & Satış Durumu (Ekran 04)
// Üstte özet kart (TOPLAM DAİRE / SATILAN / KALAN + satış oranı barı),
// altında 2 kolonlu ızgara: satılan = yeşil kart, boş = kesikli kenarlık.

struct ApartmentsTabView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: UUID
    /// Daireye dokununca: satıldıysa detay, boşsa satış formu (yalnızca yönetici).
    var onSelect: (Apartment) -> Void

    private var apartments: [Apartment] {
        viewModel.apartments(for: projectId)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                summaryCard
                    .padding(.top, 16)

                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(apartments) { apartment in
                        Button {
                            onSelect(apartment)
                        } label: {
                            ApartmentCellView(apartment: apartment)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Özet kart

    private var summaryCard: some View {
        let total = apartments.count
        let sold = viewModel.soldCount(for: projectId)
        let rate = total > 0 ? Int((Double(sold) / Double(total) * 100).rounded()) : 0

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Toplam Daire")
                        .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
                    Text("\(total)")
                        .font(.sora(26, .bold))
                        .foregroundColor(Palette.ink)
                }
                Spacer()
                HStack(spacing: 22) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Satılan")
                            .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
                        Text("\(sold)")
                            .font(.sora(18, .bold))
                            .foregroundColor(Palette.success)
                    }
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Kalan")
                            .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
                        Text("\(total - sold)")
                            .font(.sora(18, .bold))
                            .foregroundColor(Palette.textMuted)
                    }
                }
            }

            ProgressBarView(fraction: total > 0 ? Double(sold) / Double(total) : 0,
                            fill: Palette.success)
                .padding(.top, 14)

            HStack {
                Text("Satış oranı %\(rate)")
                Spacer()
                Text("Ciro \(Fmt.compactMoney(viewModel.totalSales(for: projectId)))")
            }
            .font(.manrope(12, .medium))
            .foregroundColor(Palette.textMuted)
            .padding(.top, 10)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Daire hücresi

struct ApartmentCellView: View {
    let apartment: Apartment

    var body: some View {
        Group {
            if apartment.isSold {
                soldCell
            } else {
                emptyCell
            }
        }
        .frame(minHeight: 142)
    }

    /// Satılan daire: yeşil zemin, alıcı + bedel + tahsilat barı + ödeme çipi.
    private var soldCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("No \(apartment.apartmentNumber)")
                    .font(.sora(15, .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text(apartment.floorLabel)
                    .font(.manrope(10.5, .semiBold))
                    .foregroundColor(Palette.textSecondary)
            }

            Text(apartment.buyerName ?? "")
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textMuted)
                .lineLimit(1)
                .padding(.top, 7)

            Text(Fmt.compactMoney(apartment.price))
                .font(.sora(15, .bold))
                .foregroundColor(Palette.success)
                .padding(.top, 3)

            Text(apartment.saleDateText ?? "")
                .font(.manrope(10, .medium))
                .foregroundColor(Palette.textTertiary)
                .padding(.top, 3)

            Spacer(minLength: 8)

            // Tahsilat oranı (ödenen ÷ bedel)
            ProgressBarView(fraction: apartment.collectionFraction,
                            fill: Palette.success,
                            track: Palette.successBorder.opacity(0.55),
                            height: 4)

            HStack {
                StatusChip(text: apartment.paymentStatus?.rawValue ?? "",
                           background: apartment.paymentStatus == .tamamlandi ? Palette.successChip : Palette.pendingTint,
                           foreground: apartment.paymentStatus == .tamamlandi ? Palette.successInk : Palette.pendingInk,
                           fontSize: 9)
                Spacer()
                Text(apartment.collectionText)
                    .font(.manrope(10, .semiBold))
                    .foregroundColor(apartment.paymentStatus == .tamamlandi ? Palette.successInk : Palette.textMuted)
            }
            .padding(.top, 8)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.successTint)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.successBorder, lineWidth: 1))
    }

    /// Boş daire: beyaz zemin, 1.5px kesikli kenarlık, sol altta "BOŞ" çipi.
    private var emptyCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("No \(apartment.apartmentNumber)")
                    .font(.sora(15, .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text(apartment.floorLabel)
                    .font(.manrope(10.5, .semiBold))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer(minLength: 8)

            StatusChip(text: "Boş",
                       background: Palette.fillMuted,
                       foreground: Palette.textFaded,
                       fontSize: 9)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .cornerRadius(14)
        .dashedBorder(Palette.dashedSoft, radius: 14)
    }
}
