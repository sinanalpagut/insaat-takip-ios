import SwiftUI

// MARK: - Tahsilat Ekle (yalnızca yönetici)
// Daire detayındaki "Ödeme Ekle" ile açılır. Her tahsilat ayrı bir kayıt;
// toplam bu kayıtlardan hesaplandığı için yönetici eski toplamı akıldan
// toplamak zorunda kalmaz.

struct PaymentSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let apartmentId: UUID

    @State private var amountText = ""
    @State private var method: Payment.Method = .taksit
    @State private var note = ""
    @State private var date = Date()
    @State private var receiptImage: UIImage?
    @State private var showCamera = false

    private var apartment: Apartment? {
        viewModel.apartments.first { $0.id == apartmentId }
    }

    /// Kalan alacak — formda hem bilgi hem hızlı doldurma için.
    private var remaining: Kurus {
        guard let apartment else { return .zero }
        return max(.zero, apartment.price - apartment.paidAmount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Tahsilat Ekle",
                        subtitle: apartment.map { "Daire No \($0.apartmentNumber) · \($0.buyerName ?? "")" }) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Kalan alacak kartı — tek dokunuşla tutara yazılabilir
                    if remaining > .zero {
                        Button {
                            amountText = Fmt.moneyText(remaining)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Kalan alacak")
                                        .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.0)
                                    Text(Fmt.money(remaining))
                                        .font(.sora(18, .bold))
                                        .foregroundColor(Palette.ink)
                                }
                                Spacer()
                                Text("Tümünü yaz")
                                    .font(.manrope(12, .bold))
                                    .foregroundColor(Palette.accent)
                            }
                            .padding(14)
                            .background(Palette.fillSubtle)
                            .cornerRadius(14)
                        }
                        .padding(.top, 18)
                    }

                    field("TUTAR (₺)", text: $amountText,
                          placeholder: "Örn. 25.000", keyboard: .decimalPad)
                        .padding(.top, 14)

                    Text("Ödeme Yöntemi")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    FlowLayout(spacing: 9) {
                        ForEach(Payment.Method.allCases) { option in
                            methodChip(option)
                        }
                    }
                    .padding(.top, 10)

                    field("AÇIKLAMA (İSTEĞE BAĞLI)", text: $note, placeholder: "Örn. 4. taksit")
                        .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tarih")
                            .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        HStack {
                            Text("Tahsilat tarihi")
                                .font(.manrope(13.5, .medium))
                                .foregroundColor(Palette.textMuted)
                            Spacer()
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .tint(Palette.accent)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(.top, 14)

                    // Dekont fotoğrafı
                    HStack(spacing: 10) {
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: receiptImage == nil ? "camera.fill" : "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(receiptImage == nil ? "Dekont Fotoğrafı Ekle" : "Dekont eklendi")
                                    .font(.manrope(13.5, .bold))
                            }
                            .foregroundColor(receiptImage == nil ? Palette.accent : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(receiptImage == nil ? Palette.accentTint : Palette.success)
                            .cornerRadius(13)
                        }
                        if receiptImage != nil {
                            Button { receiptImage = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Palette.textMuted)
                                    .frame(width: 52, height: 52)
                                    .background(Palette.fillMuted)
                                    .cornerRadius(13)
                            }
                        }
                    }
                    .padding(.top, 14)

                    PrimaryButton(title: "Tahsilatı Kaydet") { save() }
                        .padding(.top, 22)

                    Text("Bedelin tamamı tahsil edilince ödeme durumu otomatik \"Tamamlandı\" olur.")
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
        .sheetHeight(0.85)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { image in
                    receiptImage = image
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Parçalar

    private func methodChip(_ option: Payment.Method) -> some View {
        let selected = method == option
        return Button {
            method = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(option.rawValue)
                    .font(.manrope(12.5, .bold))
            }
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

    private func save() {
        let saved = viewModel.addPayment(role: appState.currentUser?.role ?? .partner,
                                         apartmentId: apartmentId,
                                         amountText: amountText,
                                         method: method, note: note,
                                         date: date, receiptImage: receiptImage)
        if saved { dismiss() }
    }
}
