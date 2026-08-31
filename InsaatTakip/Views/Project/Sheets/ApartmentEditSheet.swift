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
    @State private var showApplyScope = false
    @State private var status: Apartment.Status = .available
    /// Rezerve dairede alıcı adayının adı (madde 67).
    @State private var buyerName = ""
    @State private var listPriceText = ""
    @State private var deliveryNote = ""
    @State private var blockLabel = ""
    @State private var didLoad = false

    private var apartment: Apartment? {
        viewModel.apartments.first { $0.id == apartmentId }
    }

    /// Satış tarafının KDV beyanı — alan etiketine yazılıyor (madde 80).
    private var salesBasisSuffix: String {
        guard let projectId = apartment?.projectId,
              let project = viewModel.projects.first(where: { $0.id == projectId })
        else { return "" }
        return project.salesTaxBasis.fieldSuffix
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
                        // Sayısal klavye ve birimsiz yer tutucu: alan artık
                        // sayı (Apartment.areaM2). Önce serbest metindi ve
                        // "118", "118m2", "yaklaşık 120" hepsi kabul ediliyordu;
                        // m² maliyeti o veriden hesaplanamıyordu.
                        field("ALAN (m²)", text: $area, placeholder: "Örn. 118",
                              keyboard: .decimalPad)
                    }
                    .padding(.top, 16)

                    // BLOK / ETAP — madde 83. Serbest metin: TOKİ "SF-1 Blok
                    // 1", müteahhit "A Blok", belediye "2. Etap" diyor; sabit
                    // liste sahadaki adı uygulamanınkine çevirmeyi kullanıcıya
                    // yıkardı. Tek bloklu projede boş kalır ve hiçbir ekran
                    // blok kırılımı göstermez.
                    field("BLOK / ETAP", text: $blockLabel,
                          placeholder: "Örn. A Blok · boş bırakılabilir")
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
                        field("LİSTE FİYATI (₺)\(salesBasisSuffix)", text: $listPriceText,
                              placeholder: "Örn. 3.400.000", keyboard: .decimalPad)
                            .padding(.top, 14)
                        Text("Satış formunda hazır gelir; ciroya ancak satış kaydedilince girer.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .padding(.top, 6)
                    }

                    // ALICI ADAYI — yalnızca REZERVE dairede (madde 67).
                    //
                    // Kapora yatıran kişinin adı hiçbir yere yazılamıyordu:
                    // `buyerName`i yalnızca satış formu yazıyor ve o daireyi
                    // koşulsuz satıldıya çeviriyor. Müteahhit kimden kapora
                    // aldığını uygulamada tutamıyordu.
                    //
                    // SATILAN dairede burada GÖSTERİLMİYOR: orada kimlik satış
                    // formunun işi ve iki ayrı yazma yolu olması, hangisinin
                    // kazandığı belirsiz bir durum yaratırdı.
                    if status == .reserved {
                        field("ALICI ADAYI", text: $buyerName, placeholder: "Örn. Ahmet Yılmaz")
                            .padding(.top, 14)
                        Text("Yalnızca yöneticiye görünür; ortak bu adı göremez.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .padding(.top, 6)
                    }

                    // TOPLU UYGULAMA (madde 61). 20 daireli blokta dairelerin
                    // çoğu aynı tip ve m²; her birini tek tek açıp aynı iki
                    // alanı yazmak ilk haftanın en can sıkıcı işiydi — üstelik
                    // bu ekrana yalnızca karta BASILI TUTARAK ulaşılıyor.
                    //
                    // ÖNCE KAYDET, SONRA UYGULA: düğme kaynak daireyi de
                    // yazıyor, yoksa "tümüne uygula"dan sonra kaynağın kendisi
                    // eski değerde kalırdı.
                    if !isSoldRecord {
                        Button {
                            showApplyScope = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.on.square")
                                    .iconFont(12, weight: .semibold)
                                Text("Tip ve alanı diğer dairelere uygula")
                                    .font(.manrope(12.5, .bold))
                                Spacer()
                            }
                            .foregroundColor(Palette.accent)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .background(Palette.accentTint)
                            .cornerRadius(13)
                        }
                        .padding(.top, 14)
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
        .confirmationDialog("Tip ve alan nereye uygulansın?", isPresented: $showApplyScope,
                            titleVisibility: .visible) {
            Button("Bu kattaki dairelere") { applyTo(wholeProject: false) }
            Button("Projedeki tüm dairelere") { applyTo(wholeProject: true) }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Yalnızca TİP ve ALAN kopyalanır. Bedel, durum ve teslim notu "
                 + "her dairede kendi değerinde kalır.")
        }
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
        area = apartment.areaM2.map { Fmt.qtyText($0) } ?? ""   // qty DEĞİL: 111,55 m² → 112 oluyordu
        floor = apartment.floor
        status = apartment.status
        buyerName = apartment.buyerName ?? ""
        listPriceText = apartment.price > .zero ? Fmt.moneyText(apartment.price) : ""
        deliveryNote = apartment.deliveryNote
        blockLabel = apartment.blockLabel
    }

    /// Önce kaynağı kaydeder, sonra kopyalar. Sıra önemli: kaydetmeden
    /// uygulasaydık kaynağın kendisi eski değerde kalırdı.
    private func applyTo(wholeProject: Bool) {
        let role = viewModel.role(forApartment: apartmentId, user: appState.currentUser)
        guard viewModel.updateApartment(role: role, apartmentId: apartmentId,
                                        type: type.isEmpty ? "—" : type,
                                        areaM2: Apartment.parseLegacyArea(area),
                                        floor: floor, status: status,
                                        listPriceText: listPriceText,
                                        deliveryNote: deliveryNote,
                                        buyerName: buyerName,
                                        blockLabel: blockLabel) else { return }
        let n = viewModel.applyTypeAndArea(role: role, from: apartmentId,
                                           wholeProject: wholeProject)
        if n == 0 { viewModel.flash("Diğer daireler zaten aynı") }
        dismiss()
    }

    private func save() {
        let saved = viewModel.updateApartment(role: viewModel.role(forApartment: apartmentId, user: appState.currentUser),
                                              apartmentId: apartmentId,
                                              type: type.isEmpty ? "—" : type,
                                              areaM2: Apartment.parseLegacyArea(area),
                                              floor: floor,
                                              status: status,
                                              listPriceText: listPriceText,
                                              deliveryNote: deliveryNote,
                                              buyerName: buyerName,
                                              blockLabel: blockLabel)
        if saved { dismiss() }
    }
}
