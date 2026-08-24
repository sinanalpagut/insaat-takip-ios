import SwiftUI

// MARK: - Açılış devri (madde 59)
//
// Yarısı bitmiş şantiyede uygulamaya geçen müteahhidin eldeki stoğu.
// Önceden `openingIn/openingOut/openingCost` yalnızca demo tohumunda
// atanıyordu; `addProject` her kalemi sıfırla açıyor. Eldeki 20 ton demiri
// girmenin tek yolu SAHTE geçmiş tarihli bir fiş yazmaktı — olmayan bir
// irsaliye, olmayan bir tedarikçi ve fiyat geçmişini (madde 25) bozan bir
// kayıt.
//
// DEVİR BİR HAREKET DEĞİL, AÇILIŞ BAKİYESİDİR. O yüzden fiş ekranından değil
// buradan giriliyor ve hareket listesinde görünmüyor; `Material.recalculate`
// zaten `openingCost + fişler` diye topluyor, dosyaya da kendi "Devir"
// satırıyla giriyor (madde 40).

struct OpeningBalanceSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let materialId: UUID

    @State private var inText = ""
    @State private var outText = ""
    @State private var costText = ""
    @State private var didPrefill = false

    private var material: Material? {
        viewModel.materials.first { $0.id == materialId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let material {
                SheetHeader(title: "Açılış Devri", subtitle: material.name) { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Uygulamayı kullanmaya başlamadan ÖNCE şantiyede olan miktar. "
                             + "Fiş olarak yazılmaz: bir hareket değil, açılış bakiyesidir.")
                            .font(.manrope(12, .medium))
                            .foregroundColor(Palette.textMuted)
                            .lineSpacing(3)
                            .padding(.top, 14)

                        field("DEVİR GİREN (\(material.unit.uppercased()))", text: $inText,
                              placeholder: "Örn. 20.000", keyboard: .decimalPad)
                            .padding(.top, 16)

                        field("DEVİR KULLANILAN (\(material.unit.uppercased()))", text: $outText,
                              placeholder: "Örn. 14.000", keyboard: .decimalPad)
                            .padding(.top, 14)
                        Text("Devirden bugüne kadar harcanan kısım. Bilinmiyorsa boş bırak.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .padding(.top, 6)

                        field("DEVİR TUTARI (₺)", text: $costText,
                              placeholder: "Örn. 570.000", keyboard: .decimalPad)
                            .padding(.top, 14)
                        // Kapsam yazılı: bu rakam malzeme giderine EKLENİYOR,
                        // fiş toplamının yerine geçmiyor.
                        Text("Devir stoğunun maliyeti. Malzeme giderine fişlerin ÜSTÜNE eklenir.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .padding(.top, 6)

                        // ÜSTÜNE YAZILIR, EKLENMEZ: kullanıcı düzeltmek için
                        // ikinci kez girdiğinde miktar iki katına çıkmasın.
                        if material.openingIn != 0 || material.openingCost != .zero {
                            Text("Kayıtlı devir var; girilen değerler ÜSTÜNE YAZILIR.")
                                .font(.manrope(11.5, .semiBold))
                                .foregroundColor(Palette.alertInk)
                                .padding(.top, 14)
                        }

                        PrimaryButton(title: "Devri Kaydet") { save() }
                            .padding(.top, 22)

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
        .background(Palette.surface)
        .presentationCornerRadius24()
        .presentationDragIndicator(.visible)
        .toastOverlay(viewModel.toast)
        .onAppear { prefill() }
    }

    /// Mevcut devir forma yüklenir — düzeltme yolu bu.
    ///
    /// Miktarlar `Fmt.qtyText` ile yazılıyor, `Fmt.qty` ile DEĞİL: ikincisi
    /// yuvarlıyor ve 12,5 m³'lük bir devir forma "13" olarak dolup kaydedilince
    /// gerçekten 13 olurdu (madde 52'de yaşanan tuzak).
    private func prefill() {
        guard !didPrefill, let material else { return }
        didPrefill = true
        if material.openingIn != 0 { inText = Fmt.qtyText(material.openingIn) }
        if material.openingOut != 0 { outText = Fmt.qtyText(material.openingOut) }
        if material.openingCost != .zero { costText = Fmt.moneyText(material.openingCost) }
    }

    private func save() {
        guard let material else { return }
        let saved = viewModel.setOpeningBalance(
            role: viewModel.role(inProject: material.projectId, for: appState.currentUser),
            materialId: materialId,
            inText: inText, outText: outText, costText: costText)
        if saved { dismiss() }
    }

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
                .frame(minHeight: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }
}
