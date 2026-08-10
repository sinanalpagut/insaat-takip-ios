import SwiftUI

// MARK: - Satış Ekle / Düzenle (yalnızca yönetici)
// Ekran 04'teki "＋ Satış Ekle" FAB'ı ve boş daire kartından açılır;
// ekran 13'teki "Satış Kaydını Düzenle" mevcut kaydı doldurarak açar.
// Fiş formundaki dil: çipler, küçük büyük-harf etiketler, bakır CTA.

struct SaleFormSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: String
    /// FAB'dan gelindiyse nil — form içinden boş daire seçilir.
    let apartmentId: String?

    @State private var selectedApartmentId: String?
    @State private var buyerName = ""
    @State private var priceText = ""
    @State private var paidText = ""
    @State private var payment: PaymentStatus = .tamamlandi
    @State private var didPrefill = false

    /// Formda seçilebilecek daireler: boş olanlar + düzenlenen daire.
    private var selectableApartments: [Apartment] {
        viewModel.apartments(for: projectId).filter { !$0.isSold || $0.id == apartmentId }
    }

    private var selectedApartment: Apartment? {
        viewModel.apartments.first { $0.id == (selectedApartmentId ?? apartmentId) }
    }

    private var isEditing: Bool {
        selectedApartment?.isSold == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: isEditing ? "Satış Kaydını Düzenle" : "Satış Ekle",
                        subtitle: viewModel.projects.first { $0.id == projectId }?.title) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Daire")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    // Daire seçim çipleri (düzenlemede kilitli tek çip)
                    FlowLayout(spacing: 9) {
                        ForEach(selectableApartments) { apartment in
                            apartmentChip(apartment)
                        }
                    }
                    .padding(.top, 10)

                    Text("Alıcı Adı")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    TextField("Örn. Berk Koç", text: $buyerName)
                        .font(.manrope(14, .bold))
                        .foregroundColor(Palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                        .padding(.top, 8)

                    HStack(alignment: .top, spacing: 10) {
                        moneyField("SATIŞ BEDELİ (₺)", text: $priceText, placeholder: "3.850.000")
                        if payment != .tamamlandi {
                            moneyField("TAHSİL EDİLEN (₺)", text: $paidText, placeholder: "500.000")
                        }
                    }
                    .padding(.top, 16)

                    Text("Ödeme Durumu")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    HStack(spacing: 9) {
                        ForEach(PaymentStatus.allCases, id: \.self) { option in
                            paymentChip(option)
                        }
                    }
                    .padding(.top, 10)

                    PrimaryButton(title: isEditing ? "Kaydı Güncelle" : "Satışı Kaydet") { save() }
                        .padding(.top, 22)

                    Text("Satış, ortakların akışına ve dönem raporuna anında yansır.")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

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
        .onAppear { prefill() }
    }

    // MARK: Parçalar

    private func apartmentChip(_ apartment: Apartment) -> some View {
        let selected = apartment.id == (selectedApartmentId ?? apartmentId)
        return Button {
            selectedApartmentId = apartment.id
        } label: {
            Text("No \(apartment.apartmentNumber)")
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
        .disabled(isEditing && apartment.id != apartmentId)
    }

    private func paymentChip(_ option: PaymentStatus) -> some View {
        Button {
            payment = option
        } label: {
            Text(option.rawValue)
                .font(.manrope(12, .bold))
                .foregroundColor(payment == option ? Palette.accent : Palette.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(payment == option ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(payment == option ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(10)
        }
    }

    private func moneyField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.sora(15, .bold))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }

    // MARK: Aksiyonlar

    /// Düzenleme modunda mevcut satış bilgilerini forma taşır.
    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        selectedApartmentId = apartmentId ?? selectableApartments.first?.id
        guard let apartment = selectedApartment, apartment.isSold else { return }
        buyerName = apartment.buyerName ?? ""
        priceText = Fmt.qty(apartment.price)
        paidText = Fmt.qty(apartment.paidAmount)
        payment = apartment.paymentStatus ?? .tamamlandi
    }

    private func save() {
        guard let apartment = selectedApartment else {
            viewModel.flash("Daire seçilmedi")
            return
        }
        let saved = viewModel.saveSale(role: appState.currentUser?.role ?? .partner,
                                       apartmentId: apartment.id,
                                       buyerName: buyerName,
                                       priceText: priceText,
                                       paidText: paidText,
                                       payment: payment)
        if saved { dismiss() }
    }
}
