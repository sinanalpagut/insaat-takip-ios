import SwiftUI

// MARK: - Yeni Malzeme Tanımla (yalnızca yönetici)
// Fiş ekleme sayfasındaki "＋ Yeni Malzeme" çipinden açılır.
// Varsayılan katalogda olmayan kalemleri (seramik, boya, izolasyon…) projeye ekler.

struct NewMaterialSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID
    /// Kalem oluşturulunca üst forma bildirilir (hemen seçili gelsin diye).
    var onCreate: (Material) -> Void

    @State private var name = ""
    @State private var subtitle = ""
    @State private var unit = ""
    @State private var unitPriceText = ""

    /// Sahada en sık kullanılan birimler — yazmadan seçilebilsin.
    private let commonUnits = ["kg", "ton", "adet", "m²", "m³", "torba", "paket", "metre"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Yeni Malzeme",
                        subtitle: "Bu projeye özel kalem tanımla") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    field("MALZEME ADI", text: $name, placeholder: "Örn. Seramik")
                        .padding(.top, 18)

                    field("AÇIKLAMA (İSTEĞE BAĞLI)", text: $subtitle,
                          placeholder: "Örn. 60x60 mat sırlı")
                        .padding(.top, 14)

                    Text("Birim")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    FlowLayout(spacing: 9) {
                        ForEach(commonUnits, id: \.self) { option in
                            unitChip(option)
                        }
                    }
                    .padding(.top, 10)

                    TextField("veya kendin yaz — örn. rulo", text: $unit)
                        .font(.manrope(13.5, .semiBold))
                        .foregroundColor(Palette.ink)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                        .padding(.top, 10)

                    field("BİRİM FİYAT (₺)", text: $unitPriceText,
                          placeholder: "Örn. 420", keyboard: .decimalPad)
                        .padding(.top, 14)

                    PrimaryButton(title: "Malzemeyi Ekle") { create() }
                        .padding(.top, 22)

                    Text("Eklenen kalem sıfır stokla açılır; miktarı fiş ile girersin.")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    Spacer().frame(height: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .keyboardDoneToolbar()
        .sheetHeight(0.75)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
    }

    // MARK: Parçalar

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.manrope(14, .bold))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }

    private func unitChip(_ option: String) -> some View {
        let selected = unit == option
        return Button {
            unit = option
        } label: {
            Text(option)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
        }
    }

    private func create() {
        guard let material = viewModel.addMaterial(role: appState.currentUser?.role ?? .partner,
                                                   projectId: projectId,
                                                   name: name, subtitle: subtitle,
                                                   unit: unit, unitPriceText: unitPriceText)
        else { return }
        onCreate(material)
        dismiss()
    }
}
