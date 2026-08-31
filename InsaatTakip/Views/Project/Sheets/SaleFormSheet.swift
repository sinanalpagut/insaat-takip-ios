import SwiftUI

// MARK: - Satış Ekle / Düzenle (yalnızca yönetici)
// Ekran 04'teki "＋ Satış Ekle" FAB'ı ve boş daire kartından açılır;
// ekran 13'teki "Satış Kaydını Düzenle" mevcut kaydı doldurarak açar.
// Fiş formundaki dil: çipler, küçük büyük-harf etiketler, bakır CTA.

struct SaleFormSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID
    /// FAB'dan gelindiyse nil — form içinden boş daire seçilir.
    let apartmentId: UUID?

    /// Satış tarafının KDV beyanı — alan etiketine yazılıyor (madde 80).
    private var salesBasisSuffix: String {
        viewModel.projects.first { $0.id == projectId }?.salesTaxBasis.fieldSuffix ?? ""
    }

    @State private var selectedApartmentId: UUID?
    @State private var buyerName = ""
    @State private var priceText = ""
    @State private var paidText = ""
    @State private var payment: PaymentStatus = .tamamlandi
    /// Sözleşme tarihi; düzenlemede kayıtlı tarihle açılır.
    @State private var saleDate = Date()

    /// Taksit planı (madde 21). Yalnızca "Taksitli" seçiliyken sorulur.
    @State private var installmentCount = 12
    @State private var firstDueDate = Date()
    @State private var didPrefill = false

    /// Formda seçilebilecek daireler: gerçekten boş olanlar + düzenlenen daire.
    /// `!isSold` denseydi kat karşılığı daire de listelenir ve yönetici arsa
    /// sahibinin dairesini yanlışlıkla satabilirdi.
    private var selectableApartments: [Apartment] {
        viewModel.apartments(for: projectId).filter { $0.isSellable || $0.id == apartmentId }
    }

    private var selectedApartment: Apartment? {
        viewModel.apartments.first { $0.id == (selectedApartmentId ?? apartmentId) }
    }

    /// Rezerve daire de "düzenleme" sayılır: kaporası ve alıcı adayı forma taşınır,
    /// başlık "Satışa Çevir" olur.
    private var isEditing: Bool {
        selectedApartment?.isCommitted == true
    }

    private var isConverting: Bool {
        selectedApartment?.status == .reserved
    }

    /// Tahsilat alanı yalnızca ilk kayıtta anlamlı: sonrasında ödeme defteri yönetir.
    private var showsPaidField: Bool {
        payment != .tamamlandi && (!isEditing || isConverting)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: isConverting ? "Satışa Çevir"
                                : (isEditing ? "Satış Kaydını Düzenle" : "Satış Ekle"),
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
                        moneyField("SATIŞ BEDELİ (₺)\(salesBasisSuffix)",
                                   text: $priceText, placeholder: "3.850.000")
                        // Tahsilat alanı YALNIZCA ilk kayıtta (yeni satış veya
                        // rezerveden çevirme) görünür. Kayıtlı bir satışta tahsilat
                        // tek kaynaktan — ödeme kayıtlarından — türetiliyor; burada
                        // ikinci bir yazma yolu bırakıldığında girilen tutar sessizce
                        // çöpe gidiyordu (kaydedildi der, hiçbir yere yazmazdı).
                        if showsPaidField {
                            moneyField("TAHSİL EDİLEN (₺)", text: $paidText, placeholder: "500.000")
                        }
                    }
                    .padding(.top, 16)

                    if isEditing, !isConverting {
                        Text("Tahsilat, daire detayındaki \"Ödeme Ekle\" ile işlenir — her ödemenin tarihi ve dekontu ayrı kayıtta durur.")
                            .font(.manrope(11, .medium))
                            .foregroundColor(Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }

                    Text("Ödeme Durumu")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    HStack(spacing: 9) {
                        ForEach(PaymentStatus.allCases, id: \.self) { option in
                            paymentChip(option)
                        }
                    }
                    .padding(.top, 10)

                    // Sözleşme tarihi — satış her zaman "bugün"e yazılıyordu,
                    // geçmişe dönük satış aylık ciro grafiğinde yanlış aya düşerdi.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tarih")
                            .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        HStack {
                            Text("Sözleşme tarihi")
                                .font(.manrope(13.5, .medium))
                                .foregroundColor(Palette.textMuted)
                            Spacer()
                            DatePicker("", selection: $saleDate, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .tint(Palette.accent)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(.top, 16)

                    // TAKSİT PLANI — yalnızca "Taksitli" seçiliyken.
                    //
                    // Bugüne kadar "Taksitli" bir ETİKETTİ: arkasında taksit
                    // sayısı, tutarı ya da vadesi yoktu, dolayısıyla "gecikmiş
                    // tahsilat" sorusu cevaplanamıyordu.
                    if payment == .taksitli {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TAKSİT PLANI")
                                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)

                            HStack {
                                Text("Taksit sayısı")
                                    .font(.manrope(13.5, .medium))
                                    .foregroundColor(Palette.textMuted)
                                Spacer()
                                Text("\(installmentCount)")
                                    .font(.sora(15, .bold))
                                    .foregroundColor(Palette.ink)
                                Stepper("", value: $installmentCount, in: 1...240)
                                    .labelsHidden()
                                    .tint(Palette.accent)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(Palette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))

                            HStack {
                                Text("İlk vade")
                                    .font(.manrope(13.5, .medium))
                                    .foregroundColor(Palette.textMuted)
                                Spacer()
                                // Sözleşme tarihi geçmişe açık ama vade
                                // GELECEĞE bakar; alt sınır yok, üst sınır da.
                                DatePicker("", selection: $firstDueDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Palette.accent)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(Palette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))

                            Text(planSummary)
                                .font(.manrope(11.5, .medium))
                                .foregroundColor(Palette.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 16)
                    }

                    PrimaryButton(title: isConverting ? "Satışa Çevir"
                                     : (isEditing ? "Kaydı Güncelle" : "Satışı Kaydet")) { save() }
                        .padding(.top, 22)

                    Text(isEditing
                         ? "Değişiklikler kayda geçer ve ortakların akışında görünür."
                         : "Satış, ortakların akışına ve dönem raporuna anında yansır.")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    // Bu satış daha önce düzeltildiyse geçmişi burada durur.
                    if let apartmentId = selectedApartmentId {
                        let history = viewModel.audit(for: apartmentId)
                        if !history.isEmpty {
                            auditSection(history)
                                .padding(.top, 20)
                        }
                    }

                    Spacer().frame(height: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .keyboardDoneToolbar()
        .sheetHeight(0.82)
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
            prefillListPrice(apartment)
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
        guard let apartment = selectedApartment else { return }
        guard apartment.isCommitted else {
            prefillListPrice(apartment)
            return
        }
        buyerName = apartment.buyerName ?? ""
        priceText = Fmt.moneyText(apartment.price)
        paidText = Fmt.moneyText(apartment.paidAmount)
        payment = apartment.paymentStatus ?? .tamamlandi
        saleDate = apartment.saleDate ?? Date()

        // KAYITLI PLAN FORMA YÜKLENİYOR. Önceden yüklenmiyordu ve
        // `installmentCount` 12, `firstDueDate` bugün varsayılanlarında
        // kalıyordu; `save()` bu varsayılanları kaydediyor, `saveSale` de eski
        // planı silip yerine onlarla yenisini kuruyordu. Yani alıcı adındaki
        // bir yazım hatasını düzeltmek 36 aylık planı 12 aylığa çeviriyor, tüm
        // vadeleri bugüne kaydırıyor ve GECİKMİŞ TAHSİLATI sıfırlıyordu.
        // Plan toplamı bedele eşit kaldığı için hiçbir toplam denetimi bunu
        // yakalamıyordu.
        let plan = viewModel.installmentPlan(for: apartment.id)
        let taksitler = plan.filter { $0.sequence > 0 }
        if !taksitler.isEmpty {
            installmentCount = taksitler.count
            // Planın İLK satırı (peşinat varsa o, yoksa 1. taksit) —
            // `Installment.plan`in `firstDueDate` sözleşmesiyle birebir aynı.
            firstDueDate = plan.first?.dueDate ?? firstDueDate
        }
    }

    /// Boş dairede tanımlı liste fiyatı varsa (TOKİ gerçek verisi) forma hazır getirir.
    /// Fiyatı olmayan daireye geçildiğinde alan MUTLAKA temizlenir: önceden erken
    /// dönülüyordu ve önceki dairenin bedeli alanda kalıyordu — yönetici çipten
    /// başka daire seçip kaydettiğinde hiç yazmadığı bir bedelle satış işleniyor,
    /// ciro o tutar kadar şişiyordu.
    private func prefillListPrice(_ apartment: Apartment) {
        guard !apartment.isCommitted else { return }
        priceText = apartment.price > .zero ? Fmt.moneyText(apartment.price) : ""
    }

    /// Kaydetmeden ÖNCE planın ne üreteceğini söyler.
    ///
    /// Rakamı kullanıcı kaydettikten sonra keşfetmemeli: 3.850.000 ₺'lik bir
    /// daireyi 12 taksite bölerken aylık tutarın ne olacağı kararı etkiliyor.
    /// Planın peşinatı — KAYDEDİLENLE AYNI KAYNAK.
    ///
    /// `saveSale` düzenleme modunda peşinatı eski planın `sequence 0` satırından
    /// alıyor (madde 35), çünkü form alanı "TAHSİL EDİLEN" diye etiketli ve o
    /// tutar ödemeler biriktikçe büyüyor. Önizleme `paidText`ten okumaya devam
    /// edince ekranla kayıt zorunlu olarak ayrıştı: 600.000 ₺ peşinatlı 36
    /// taksitlik bir planda 14 taksit ödendikten sonra ekran "aylık 50.926 ₺"
    /// diyor, veritabanına 83.333 ₺ giriyordu — kullanıcı gördüğü rakama
    /// güvenerek kaydediyor. Bu, madde 33'ün kapattığı kusurun (önizlemenin
    /// planı ayrı hesaplaması) 35 düzeltilirken geri açılmış hali.
    private var effectiveDownPayment: Kurus {
        if let apartment = selectedApartment {
            let plan = viewModel.installmentPlan(for: apartment.id)
            if plan.contains(where: { $0.sequence > 0 }) {
                return plan.first(where: { $0.sequence == 0 })?.amount ?? .zero
            }
        }
        return ProjectViewModel.parseMoney(paidText)
    }

    private var planSummary: String {
        let price = ProjectViewModel.parseMoney(priceText)
        let down = effectiveDownPayment
        guard price > down, installmentCount > 0 else {
            return "Bedel ve peşinat girilince aylık tutar burada görünür."
        }
        let rest = price - down
        // Önizleme, planı KURAN işlemin kendisinden okunuyor — ayrıca
        // hesaplanmıyor. Önceden burada `rest.raw / Int64(installmentCount)`
        // vardı: `Kurus.split`ten bağımsız ÜÇÜNCÜ bir yuvarlama noktası ve
        // ekranla veritabanının sessizce ayrışabildiği bir yer. Nitekim
        // ayrışmıştı: plan üretimi son taksiti şişirirken bu satır doğru eşit
        // tutarı gösteriyordu, farkı da "yaklaşık" kelimesi örtüyordu.
        let shares = Kurus.split(rest, into: installmentCount)
        let monthly = shares.first ?? .zero
        let downText = down > .zero ? "\(Fmt.money(down)) peşinat + " : ""
        // Paylar arasında en fazla 1 kuruş fark olabilir; "yaklaşık" bunu
        // karşılıyor ve artık gerçekten yalnızca bunu karşılıyor.
        return "\(downText)\(installmentCount) ay × yaklaşık \(Fmt.money(monthly)). İlk vade \(Fmt.shortDate(firstDueDate))."
    }

    private func save() {
        guard let apartment = selectedApartment else {
            viewModel.flash("Daire seçilmedi")
            return
        }
        let saved = viewModel.saveSale(role: viewModel.role(inProject: projectId, for: appState.currentUser),
                                       apartmentId: apartment.id,
                                       buyerName: buyerName,
                                       priceText: priceText,
                                       paidText: paidText,
                                       payment: payment,
                                       saleDate: saleDate,
                                       installmentCount: payment == .taksitli ? installmentCount : 0,
                                       firstDueDate: payment == .taksitli ? firstDueDate : nil)
        if saved { dismiss() }
    }

    /// Bu satışın değişiklik geçmişi — kim, ne zaman, neyi neye çevirmiş.
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
}
