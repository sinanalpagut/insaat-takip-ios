import SwiftUI

// MARK: - Daire Bilgisi Düzenleme (yalnızca yönetici)
// Daire kartından (kat karşılığı / boş / rezerve) veya daire detayından açılır.
// Bu ekran olmadan yeni projede üretilen daireler hiçbir yerden düzeltilemiyordu:
// müteahhit kendi projesini kurduğu ilk dakikada yanlış tip/m²/kat görüyor ve
// düzeltemiyordu. Satış BURADAN yapılmaz — .sold'a yalnızca satış formu geçirir.

struct ApartmentEditSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let apartmentId: UUID

    @State private var type = ""
    @State private var area = ""
    @State private var floor = 0
    @State private var status: Apartment.Status = .available
    @State private var listPriceText = ""
    @State private var deliveryNote = ""
    @State private var didLoad = false

    private var apartment: Apartment? {
        viewModel.apartments.first { $0.id == apartmentId }
    }

    /// Satılmış daire bu formdan durum değiştiremez; satış kaydı satış formunun işi.
    private var isSoldRecord: Bool { apartment?.status == .sold }

    /// Kat karşılığı daire bedelsizdir — liste fiyatı alanı anlamsız olur.
    private var showsPrice: Bool { status != .landOwner && status != .sold }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Daire Bilgisi",
                        subtitle: apartment.map { "Daire No \($0.apartmentNumber)" }) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Daire Durumu")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 18)

                    FlowLayout(spacing: 9) {
                        ForEach(Apartment.Status.allCases) { option in
                            statusChip(option)
                        }
                    }
                    .padding(.top, 10)

                    Text(status.label)
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .padding(.top, 8)

                    if isSoldRecord {
                        Text("Satılmış dairenin durumu buradan değiştirilemez; satışı iptal etmek için daire detayını kullan.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        field("TİP", text: $type, placeholder: "Örn. 3+1")
                        field("ALAN", text: $area, placeholder: "Örn. 118 m²")
                    }
                    .padding(.top, 16)

                    // Kat — bodrum (negatif) ve zemin (0) ifade edilebilsin:
                    // yeni proje kurulumu katları 1'den başlatıyordu, oysa gerçek
                    // TOKİ bloklarında bodrum ve zemin kat var.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KAT")
                            .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        HStack {
                            Text(Apartment.floorLabel(for: floor))
                                .font(.manrope(14, .bold))
                                .foregroundColor(Palette.ink)
                            Spacer()
                            Stepper("", value: $floor, in: -3...40)
                                .labelsHidden()
                                .tint(Palette.accent)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(.top, 14)

                    if showsPrice {
                        field("LİSTE FİYATI (₺)", text: $listPriceText,
                              placeholder: "Örn. 3.400.000", keyboard: .decimalPad)
                            .padding(.top, 14)
                        Text("Satış formunda hazır gelir; ciroya ancak satış kaydedilince girer.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .padding(.top, 6)
                    }

                    field("TESLİM NOTU", text: $deliveryNote, placeholder: "Örn. Anahtar teslim bekliyor")
                        .padding(.top, 14)

                    PrimaryButton(title: "Kaydet") { save() }
                        .padding(.top, 22)

                    // Bu daire daha önce düzeltildiyse geçmişi burada durur.
                    let history = viewModel.audit(for: apartmentId)
                    if !history.isEmpty {
                        auditSection(history)
                            .padding(.top, 22)
                    }

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
        .onAppear(perform: load)
    }

    // MARK: Parçalar

    private func statusChip(_ option: Apartment.Status) -> some View {
        let selected = status == option
        // Satılmış daire yalnızca kendi durumunu gösterir; diğer çipler kilitli.
        let locked = isSoldRecord ? option != .sold : option == .sold
        return Button {
            status = option
        } label: {
            Text(option.badge)
                .font(.manrope(12, .bold))
                .foregroundColor(selected ? Palette.accent : (locked ? Palette.textFaded : Palette.textMuted))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
                .opacity(locked ? 0.45 : 1)
        }
        .disabled(locked)
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

    private func auditSection(_ history: [AuditEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Değişiklik Geçmişi")
                .smallCapsLabel(size: 10, color: Palette.textFaded, tracking: 1.1)
            ForEach(history) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(entry.dateText) · \(entry.user)")
                        .font(.manrope(11, .bold))
                        .foregroundColor(Palette.textMuted)
                    Text(entry.summary)
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Palette.fillSubtle)
                .cornerRadius(11)
            }
        }
    }

    // MARK: Aksiyonlar

    private func load() {
        guard !didLoad, let apartment else { return }
        didLoad = true
        // Yeni projede tip/alan "—" gelir; forma boş taşınsın ki kullanıcı
        // tire silmek zorunda kalmasın.
        type = apartment.type == "—" ? "" : apartment.type
        area = apartment.area == "—" ? "" : apartment.area
        floor = apartment.floor
        status = apartment.status
        listPriceText = apartment.price > .zero ? Fmt.moneyText(apartment.price) : ""
        deliveryNote = apartment.deliveryNote
    }

    private func save() {
        let saved = viewModel.updateApartment(role: appState.currentUser?.role ?? .partner,
                                              apartmentId: apartmentId,
                                              type: type.isEmpty ? "—" : type,
                                              area: area.isEmpty ? "—" : area,
                                              floor: floor,
                                              status: status,
                                              listPriceText: listPriceText,
                                              deliveryNote: deliveryNote)
        if saved { dismiss() }
    }
}
