import SwiftUI

// MARK: - Malzemeler Sekmesi (Ekran 02)
// "STOK DURUMU" etiketi + kalem sayısı / toplam tutar; her malzeme bir kart.
// Kart: kod rozeti, ad + "açıklama · birim fiyat", sağda kalan miktar (Sora),
// altında kalan/giren oranı barı ve "Giren … / Tutar …" satırı.
// Kritik stokta (kalan oranı eşiğin altında) rozet ve bar uyarı paletine döner.

struct MaterialsTabView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: String
    /// Karta dokununca hareket detayı sayfasını açar.
    var onSelect: (String) -> Void

    private var materials: [Material] {
        viewModel.materials(for: projectId)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 11) {
                HStack {
                    Text("Stok Durumu")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    Text("\(materials.count) kalem · \(Fmt.compactMoney(viewModel.totalMaterialCost(for: projectId)))")
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.textSecondary)
                }
                .padding(.top, 16)

                ForEach(materials) { material in
                    Button {
                        onSelect(material.id)
                    } label: {
                        MaterialCardView(material: material)
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Malzeme kartı

struct MaterialCardView: View {
    let material: Material

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                CodeBadge(code: material.code, critical: material.isCritical)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(material.name)
                            .font(.manrope(15, .bold))
                            .foregroundColor(Palette.ink)
                        // Uyarı paleti (#F6E3DE) normal tintten (#F5E6DC) sadece
                        // 1-2 RGB farklı; tek başına renkle uyarmak görünmüyordu.
                        if material.isCritical {
                            StatusChip(text: "Kritik",
                                       background: Palette.alertInk,
                                       foreground: .white,
                                       fontSize: 9)
                        }
                    }
                    Text("\(material.subtitle) · \(Fmt.unitPriceRounded(material.unitPrice, unit: material.unit))")
                        .font(.manrope(12.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.qty(material.currentStock, unit: material.unit))
                        .font(.sora(15, .bold))
                        .foregroundColor(material.isCritical ? Palette.alertInk : Palette.ink)
                    Text("kalan")
                        .font(.manrope(10.5, .medium))
                        .foregroundColor(Palette.textTertiary)
                }
            }

            ProgressBarView(fraction: material.remainingFraction,
                            fill: material.isCritical ? Palette.alertBar : Palette.accent,
                            height: 5)
                .padding(.top, 12)

            HStack {
                Text("Giren \(Fmt.qty(material.totalIn, unit: material.unit))")
                Spacer()
                Text("Tutar \(Fmt.compactMoney(material.totalCost))")
            }
            .font(.manrope(11.5, .medium))
            .foregroundColor(Palette.textMuted)
            .padding(.top, 9)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Palette.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }
}
