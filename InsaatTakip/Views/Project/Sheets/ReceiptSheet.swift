import SwiftUI

// MARK: - Fiş / Malzeme Ekleme (Ekran 06, yalnızca yönetici)
// Segment: "Giriş · Şantiyeye" / "Çıkış · Kullanım". Malzeme çipleri,
// miktar + birim fiyat alanları, canlı "Toplam tutar" satırı, fiş no ve Kaydet.

struct ReceiptSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: String

    @State private var direction: MaterialLog.LogType = .entry
    @State private var selectedMaterialId: String?
    @State private var quantityText = ""
    @State private var unitPriceText = ""
    @State private var referenceText = ""

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    private var materials: [Material] {
        viewModel.materials(for: projectId)
    }

    private var selectedMaterial: Material? {
        materials.first { $0.id == selectedMaterialId } ?? materials.first
    }

    /// Canlı toplam: miktar × birim fiyat.
    private var totalAmount: Double {
        ProjectViewModel.parseNumber(quantityText) * ProjectViewModel.parseNumber(unitPriceText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Malzeme / Fiş Ekle",
                        subtitle: project?.title) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    segmentControl
                        .padding(.top, 16)

                    Text("Malzeme")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 18)

                    // Malzeme seçim çipleri (seçili: bakır kenarlık + tint)
                    FlowLayout(spacing: 9) {
                        ForEach(materials) { material in
                            materialChip(material)
                        }
                    }
                    .padding(.top, 10)

                    // Miktar + birim fiyat
                    HStack(alignment: .top, spacing: 10) {
                        inputField("MİKTAR (\(selectedMaterial?.unit ?? ""))",
                                   text: $quantityText, placeholder: "12.500")
                        inputField("BİRİM FİYAT (₺)",
                                   text: $unitPriceText, placeholder: "28,50")
                    }
                    .padding(.top, 16)

                    // Canlı toplam tutar
                    HStack {
                        Text("Toplam tutar")
                            .font(.manrope(13, .semiBold))
                            .foregroundColor(Palette.textMuted)
                        Spacer()
                        Text(Fmt.money(totalAmount))
                            .font(.sora(16, .bold))
                            .foregroundColor(Palette.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Palette.accentTint)
                    .cornerRadius(12)
                    .padding(.top, 12)

                    Text("Fiş / İrsaliye")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    TextField("Örn. İrsaliye #4482 · Yılmaz Yapı", text: $referenceText)
                        .font(.manrope(13.5, .semiBold))
                        .foregroundColor(Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                        .padding(.top, 8)

                    PrimaryButton(title: "Kaydet") { save() }
                        .padding(.top, 20)

                    Spacer().frame(height: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .onAppear {
            // Tasarımdaki gibi: seçili malzemenin güncel birim fiyatı hazır gelir.
            if selectedMaterialId == nil { selectedMaterialId = materials.first?.id }
            syncUnitPrice()
        }
    }

    // MARK: Parçalar

    /// "Giriş · Şantiyeye" / "Çıkış · Kullanım" segmenti.
    private var segmentControl: some View {
        HStack(spacing: 4) {
            segmentButton("Giriş · Şantiyeye", .entry)
            segmentButton("Çıkış · Kullanım", .exit)
        }
        .padding(4)
        .background(Palette.fillMuted)
        .cornerRadius(13)
    }

    private func segmentButton(_ title: String, _ value: MaterialLog.LogType) -> some View {
        Button {
            direction = value
        } label: {
            Text(title)
                .font(.manrope(12.5, .bold))
                .foregroundColor(direction == value ? Palette.ink : Palette.textFaded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(direction == value ? Palette.surface : Color.clear)
                .cornerRadius(9)
                .shadow(color: direction == value ? Color(hex: 0x22262E, alpha: 0.12) : .clear,
                        radius: 3, x: 0, y: 1)
        }
    }

    private func materialChip(_ material: Material) -> some View {
        let selected = material.id == selectedMaterial?.id
        return Button {
            selectedMaterialId = material.id
            syncUnitPrice()
        } label: {
            Text(material.name)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
        }
    }

    private func inputField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.sora(16, .bold))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }

    // MARK: Aksiyonlar

    /// Seçilen malzemenin kayıtlı birim fiyatını alana yazar.
    private func syncUnitPrice() {
        guard let material = selectedMaterial else { return }
        let price = material.unitPrice
        unitPriceText = price == price.rounded()
            ? Fmt.qty(price)
            : Fmt.qty(price).replacingOccurrences(of: " ", with: "")
        if price != price.rounded() {
            // Ondalıklı fiyatlar "28,50" biçiminde gösterilir.
            unitPriceText = String(format: "%.2f", price).replacingOccurrences(of: ".", with: ",")
        }
    }

    private func save() {
        let saved = viewModel.addReceipt(role: appState.currentUser?.role ?? .partner,
                                         materialId: selectedMaterial?.id ?? "",
                                         type: direction,
                                         amountText: quantityText,
                                         unitPriceText: unitPriceText,
                                         reference: referenceText)
        if saved { dismiss() }
    }
}
