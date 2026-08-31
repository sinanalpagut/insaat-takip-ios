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
    /// Doluysa DÜZENLEME kipi (madde 64). Gider düzeltmenin yolu hiç yoktu:
    /// yanlış tutar "sil-yeniden gir" demekti ve silme belge fotoğrafını da
    /// kalıcı olarak götürüyordu.
    var editingExpenseId: UUID? = nil

    @State private var didPrefill = false

    @State private var category: Expense.Category = .iscilik
    @State private var amountText = ""
    @State private var payee = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var receiptImage: UIImage?
    /// Kaynak seçimi (kamera / galeri) — madde 63.
    @State private var showSource = false

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: editingExpenseId == nil ? "Gider Ekle" : "Gideri Düzenle",
                        subtitle: project?.title) { dismiss() }

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

                    // ETİKET BEYANI TAŞIYOR (madde 80): beyan bir kez
                    // menüde yapılıyor ama rakamın girildiği an burası. Ek
                    // yalnızca beyan varsa görünüyor; "· BELİRTİLMEDİ" her
                    // forma gürültü katardı ve yapacak bir şey söylemezdi.
                    field("TUTAR (₺)\(project?.expenseTaxBasis.fieldSuffix ?? "")",
                          text: $amountText,
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
                            showSource = true
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: receiptImage == nil ? "camera.fill" : "checkmark")
                                    .iconFont(14, weight: .semibold)
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
                                    .iconFont(13, weight: .semibold)
                                    .foregroundColor(Palette.textMuted)
                                    .frame(width: 52, height: 52)
                                    .background(Palette.fillMuted)
                                    .cornerRadius(13)
                            }
                        }
                    }
                    .padding(.top, 14)

                    PrimaryButton(title: editingExpenseId == nil
                                  ? "Gideri Kaydet" : "Değişikliği Kaydet") { save() }
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
        .onAppear { prefill() }
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .receiptSource(isPresented: $showSource, image: $receiptImage)
    }

    // MARK: Parçalar

    private func categoryChip(_ option: Expense.Category) -> some View {
        let selected = category == option
        return Button {
            category = option
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .iconFont(10, weight: .semibold)
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

    /// Tutar `Fmt.moneyText` ile yazılıyor, `Fmt.money` ile DEĞİL: ikincisi tam
    /// liraya yuvarlar ve 28,50 ₺'lik bir gider forma "29" olarak dolup
    /// kaydedilince gerçekten 29 ₺ olurdu (madde 52'nin miktar tarafındaki
    /// aynı tuzağı).
    private func prefill() {
        guard !didPrefill, let id = editingExpenseId,
              let expense = viewModel.expenses.first(where: { $0.id == id }) else { return }
        didPrefill = true
        category = expense.category
        amountText = Fmt.moneyText(expense.amount)
        payee = expense.payee
        note = expense.note
        date = expense.date
        receiptImage = viewModel.receiptImages[expense.id]
    }

    private func save() {
        let role = viewModel.role(inProject: projectId, for: appState.currentUser)
        let saved: Bool
        if let id = editingExpenseId {
            // Belge fotoğrafı düzenlemede DEĞİŞMİYOR: tutarı düzeltmek için
            // fişi yeniden çekmeye zorlamak, düzeltmenin önündeki asıl engeldi.
            saved = viewModel.updateExpense(role: role, expenseId: id, category: category,
                                            amountText: amountText, payee: payee,
                                            note: note, date: date)
        } else {
            saved = viewModel.addExpense(role: role, projectId: projectId,
                                         category: category, amountText: amountText,
                                         payee: payee, note: note,
                                         date: date, receiptImage: receiptImage)
        }
        if saved { dismiss() }
    }
}
