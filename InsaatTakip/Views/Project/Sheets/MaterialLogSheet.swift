import SwiftUI

// MARK: - Malzeme Hareket Detayı (Ekran 03)
// Karta dokununca açılan alt sayfa: rozet + ad + hassas birim fiyat,
// GİREN / KULLANILAN / KALAN kutuları ve SON HAREKETLER listesi.

struct MaterialLogSheet: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let materialId: String

    private var material: Material? {
        viewModel.materials.first { $0.id == materialId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let material {
                // Başlık: rozet + ad + birim fiyat + kapat
                HStack(spacing: 12) {
                    CodeBadge(code: material.code, critical: material.isCritical)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(material.name)
                            .font(.sora(22, .bold))
                            .foregroundColor(Palette.ink)
                        Text("\(material.subtitle) · \(Fmt.unitPriceExact(material.unitPrice, unit: material.unit))")
                            .font(.manrope(12.5, .medium))
                            .foregroundColor(Palette.textSecondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.textMuted)
                            .frame(width: 40, height: 40)
                            .background(Palette.fillMuted)
                            .cornerRadius(13)
                    }
                }
                .padding(.top, 24)

                // GİREN / KULLANILAN / KALAN kutuları
                HStack(spacing: 9) {
                    statTile("Giren", Fmt.qty(material.totalIn),
                             background: Palette.fillSubtle,
                             labelColor: Palette.textTertiary, valueColor: Palette.ink)
                    statTile("Kullanılan", Fmt.qty(material.totalOut),
                             background: Palette.fillSubtle,
                             labelColor: Palette.textTertiary, valueColor: Palette.ink)
                    statTile("Kalan", Fmt.qty(material.currentStock),
                             background: material.isCritical ? Palette.alertTint : Palette.accentTint,
                             labelColor: material.isCritical ? Palette.alertInk : Palette.accent,
                             valueColor: material.isCritical ? Palette.alertInk : Palette.accent)
                }
                .padding(.top, 18)

                Text("Son Hareketler")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    .padding(.top, 22)
                    .padding(.bottom, 4)

                // Giriş / çıkış kayıtları
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        let entries = viewModel.logs(for: materialId)
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, log in
                            logRow(log, unit: material.unit)
                            if index < entries.count - 1 {
                                Divider().overlay(Palette.divider)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
    }

    private func statTile(_ label: String, _ value: String,
                          background: Color, labelColor: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .smallCapsLabel(size: 9.5, color: labelColor, tracking: 1.0)
            Text(value)
                .font(.sora(16, .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .cornerRadius(12)
    }

    /// Hareket satırı: 26px yön rozeti, not, "tarih · kullanıcı", işaretli miktar.
    private func logRow(_ log: MaterialLog, unit: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: log.type == .entry ? "arrow.down" : "arrow.up")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(log.type == .entry ? Palette.success : Palette.textFaded)
                .frame(width: 26, height: 26)
                .background(log.type == .entry ? Palette.successTint : Palette.fillMuted)
                .cornerRadius(9)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.note)
                    .font(.manrope(13, .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                Text("\(log.dateText) · \(log.user)")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Text(log.signedAmount(unit: unit))
                .font(.sora(13, .bold))
                .foregroundColor(log.type == .entry ? Palette.success : Palette.textMuted)
        }
        .padding(.vertical, 12)
    }
}
