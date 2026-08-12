import SwiftUI

// MARK: - Gider Ekle (yalnızca yönetici)
// Malzeme dışı maliyet kalemi kaydeder. Fiş ekleme sayfasıyla aynı form dili;
// ek olarak TARİH seçici var — akşam toplu giriş yapan müteahhit geçmiş güne
// yazabilsin diye (fiş girişi hep "bugün"e yazıyordu).

struct ExpenseSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    @State private var category: Expense.Category = .iscilik
    @State private var amountText = ""
    @State private var payee = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var receiptImage: UIImage?
    @State private var showCamera = false

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Gider Ekle", subtitle: project?.title) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gider Türü")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 18)

                    FlowLayout(spacing: 9) {
                        ForEach(Expense.Category.allCases) { option in
                            categoryChip(option)
                        }
                    }
                    .padding(.top, 10)

                    field("TUTAR (₺)", text: $amountText,
                          placeholder: "Örn. 85.000", keyboard: .decimalPad)
                        .padding(.top, 16)

                    field("KİME ÖDENDİ", text: $payee, placeholder: "Örn. Kalıpçı Ekibi")
                        .padding(.top, 14)

                    field("AÇIKLAMA (İSTEĞE BAĞLI)", text: $note, placeholder: "Örn. 3. hakediş")
                        .padding(.top, 14)

                    // Tarih — geçmişe kayıt girilebilsin
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tarih")
                            .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        HStack {
                            // Tarihi seçicinin kendi çipi gösteriyor; solda ne olduğu yazar.
                            Text("Ödeme tarihi")
                                .font(.manrope(13.5, .medium))
                                .foregroundColor(Palette.textMuted)
                            Spacer()
                            DatePicker("", selection: $date,
                                       in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .tint(Palette.accent)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(.top, 14)

                    // Belge fotoğrafı (hakediş, makbuz)
                    HStack(spacing: 10) {
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: receiptImage == nil ? "camera.fill" : "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(receiptImage == nil ? "Belge Fotoğrafı Ekle" : "Belge eklendi")
                                    .font(.manrope(13.5, .bold))
                            }
                            .foregroundColor(receiptImage == nil ? Palette.accent : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(receiptImage == nil ? Palette.accentTint : Palette.success)
                            .cornerRadius(13)
                        }
                        if receiptImage != nil {
                            Button {
                                receiptImage = nil
                            } label: {
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

                    PrimaryButton(title: "Gideri Kaydet") { save() }
                        .padding(.top, 22)

                    Text("Girilen giderler \"Net\" rakamına ve dönem raporuna dahil edilir.")
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

    private func categoryChip(_ option: Expense.Category) -> some View {
        let selected = category == option
        return Button {
            category = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(option.shortName)
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
        let saved = viewModel.addExpense(role: appState.currentUser?.role ?? .partner,
                                         projectId: projectId,
                                         category: category,
                                         amountText: amountText,
                                         payee: payee, note: note,
                                         date: date, receiptImage: receiptImage)
        if saved { dismiss() }
    }
}
