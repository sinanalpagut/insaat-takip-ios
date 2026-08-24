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
    /// Doluysa DÜZENLEME kipi (madde 64). Önceden düzenleme yolu hiç yoktu:
    /// yanlış girilen bir tutarı düzeltmenin tek yolu silip yeniden girmekti ve
    /// silme, bankadan alınmış dekontu da Storage'dan kalıcı olarak düşürüyordu.
    var editingPaymentId: UUID? = nil

    @State private var didPrefill = false

    @State private var amountText = ""
    @State private var method: Payment.Method = .taksit
    @State private var note = ""
    @State private var date = Date()
    @State private var receiptImage: UIImage?
    /// Kaynak seçimi (kamera / galeri) — madde 63.
    @State private var showSource = false

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
            SheetHeader(title: editingPaymentId == nil ? "Tahsilat Ekle" : "Tahsilatı Düzenle",
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
                            showSource = true
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: receiptImage == nil ? "camera.fill" : "checkmark")
                                    .iconFont(14, weight: .semibold)
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
                                    .iconFont(13, weight: .semibold)
                                    .foregroundColor(Palette.textMuted)
                                    .frame(width: 52, height: 52)
                                    .background(Palette.fillMuted)
                                    .cornerRadius(13)
                            }
                        }
                    }
                    .padding(.top, 14)

                    PrimaryButton(title: editingPaymentId == nil
                                  ? "Tahsilatı Kaydet" : "Değişikliği Kaydet") { save() }
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
        .onAppear { prefill() }
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .receiptSource(isPresented: $showSource, image: $receiptImage)
    }

    // MARK: Parçalar

    private func methodChip(_ option: Payment.Method) -> some View {
        let selected = method == option
        return Button {
            method = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .iconFont(10, weight: .semibold)
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

    /// Düzenleme kipinde formu kayıtlı değerlerle açar.
    ///
    /// Tutar `Fmt.moneyText` ile yazılıyor, `Fmt.money` ile DEĞİL: ikincisi tam
    /// liraya yuvarlıyor ve 28,50 ₺'lik bir tahsilat forma "29" olarak dolup
    /// kaydedilince gerçekten 29 ₺ olurdu (aynı tuzak miktar tarafında madde
    /// 52'de yaşandı).
    private func prefill() {
        guard !didPrefill, let id = editingPaymentId,
              let payment = viewModel.payments.first(where: { $0.id == id }) else { return }
        didPrefill = true
        amountText = Fmt.moneyText(payment.amount)
        method = payment.method
        note = payment.note
        date = payment.date
        receiptImage = viewModel.receiptImages[payment.id]
    }

    private func save() {
        let role = viewModel.role(forApartment: apartmentId, user: appState.currentUser)
        let saved: Bool
        if let id = editingPaymentId {
            // DEKONT DÜZENLEMEDE DEĞİŞMİYOR: görsel yolu ayrı bir akış
            // (yükleme/silme) ve tutarı düzeltmek için dekontu yeniden
            // çekmeye zorlamak, düzeltmenin önündeki asıl engeldi.
            saved = viewModel.updatePayment(role: role, paymentId: id,
                                            amountText: amountText, method: method,
                                            note: note, date: date)
        } else {
            saved = viewModel.addPayment(role: role, apartmentId: apartmentId,
                                         amountText: amountText,
                                         method: method, note: note,
                                         date: date, receiptImage: receiptImage)
        }
        if saved { dismiss() }
    }
}
