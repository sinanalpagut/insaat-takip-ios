import SwiftUI

// MARK: - Dönem Raporu / PDF (Ekran 10)
// Dönem çipleri (Bu ay / Çeyrek / Tümü), özet kart (son satır "Dönem net" yeşil),
// AYLIK SATIŞ çubuk grafiği (≥7 M ₺ koyu bakır, altı açık) ve PDF paylaşımı.

struct ReportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    @State private var period: ProjectViewModel.ReportPeriod = .ceyrek
    @State private var sharePayload: SharePayload?
    /// CSV/JSON dışa aktarma — birden çok dosya birlikte paylaşılıyor.
    @State private var exportPayload: ExportPayload?

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    private var summary: ProjectViewModel.ReportSummary {
        viewModel.reportSummary(for: projectId, period: period)
    }

    private var bars: [ProjectViewModel.MonthBar] {
        viewModel.monthlySales(for: projectId)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    summaryCard
                        .padding(.top, 16)
                    outlookCard
                    blockCard
                    chartCard

                    PrimaryButton(title: "PDF Olarak İndir", icon: "doc.text") {
                        exportPDF()
                    }
                    .padding(.top, 6)

                    // CSV/JSON — madde 26. PDF tek sayfalık özet; mali müşavir
                    // SATIR SATIR veri istiyor ve müteahhit bu yüzden paralel
                    // Excel tutuyordu.
                    Button {
                        exportData()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "tablecells")
                                .iconFont(14, weight: .semibold)
                            Text("Excel (CSV) ve Yedek")
                                .font(.manrope(14, .bold))
                        }
                        .foregroundColor(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.surface)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(.top, 8)

                    Text(isAdmin
                         ? "CSV dosyaları Excel'de doğrudan açılır. Yedek dosyası alıcı bilgisini de içerir."
                         : "CSV dosyaları Excel'de doğrudan açılır. Alıcı bilgisi yalnızca yöneticide görünür.")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        // sheet(item:) kullanılır: isPresented + "if let" kalıbında sheet içeriği
        // sunum anında henüz güncellenmemiş değeri yakalayıp boş (beyaz) açılıyordu.
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
        }
        .sheet(item: $exportPayload) { payload in
            ShareSheet(items: payload.urls)
        }
    }

    /// BU PROJEDEKİ rol — dışa aktarılan dosyanın İÇERİĞİNİ belirliyor.
    private var isAdmin: Bool {
        viewModel.role(inProject: projectId, for: appState.currentUser) == .admin
    }

    /// CSV dosyalarını ve JSON yedeğini üretip paylaşım sayfasını açar.
    private func exportData() {
        let urls = viewModel.exportFiles(for: projectId,
                                         role: isAdmin ? .admin : .partner)
        guard !urls.isEmpty else {
            viewModel.flash("Dışa aktarılacak kayıt yok")
            return
        }
        exportPayload = ExportPayload(urls: urls)
    }

    // MARK: Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                DarkHeaderButton(systemName: "chevron.left", label: "Geri") { dismiss() }
                Spacer()
            }
            .padding(.top, 6)

            Text("Dönem Raporu")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                .padding(.top, 14)

            Text(project?.title ?? "")
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 5)

            HStack(spacing: 8) {
                ForEach(ProjectViewModel.ReportPeriod.allCases, id: \.self) { option in
                    Button {
                        period = option
                    } label: {
                        Text(option.rawValue)
                            .font(.manrope(12.5, .bold))
                            .foregroundColor(period == option ? Palette.ink : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(period == option ? Color.white : Color.white.opacity(0.08))
                            .cornerRadius(11)
                    }
                }
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Palette.ink
                .clipShape(RoundedCorners(radius: 22, corners: [.bottomLeft, .bottomRight]))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Özet kart

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(summary.title)
                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                .padding(.bottom, 6)

            summaryRow("Satılan daire", "\(summary.soldCount) adet")
            Divider().overlay(Palette.divider)
            // Ciroya girmeyen ama ortağın bilmesi gereken kalemler. Kırılım
            // olmadan "Satılan daire N adet" ya kat karşılığını içerip yanlış
            // olur ya da bekleyen kaporayı tamamen gizler.
            if summary.reservedCount > 0 {
                summaryRow("Rezerve",
                           "\(summary.reservedCount) adet · kapora \(Fmt.compactMoney(summary.depositTotal))")
                Divider().overlay(Palette.divider)
            }
            if summary.landOwnerCount > 0 {
                summaryRow("Kat karşılığı (bedelsiz)", "\(summary.landOwnerCount) adet")
                Divider().overlay(Palette.divider)
            }
            // TAM HASSASİYET, kısaltma DEĞİL. Bu dört rakam birbirinden
            // çıkarılıyor (`net = satış − (malzeme + diğer)`) ve `compactMoney`
            // her satırı ayrı ayrı milyona yuvarladığı için ortağın kâğıt
            // üstünde yaptığı çıkarma karttaki "Dönem net" ile tutmuyordu.
            // Model tarafında hesap zaten tam Kuruş aritmetiği — bozulan
            // gösterimdi. Kart ortaklara PDF olarak dağıtılıyor.
            summaryRow("Satış geliri", Fmt.exactMoney(summary.salesTotal))
            Divider().overlay(Palette.divider)
            summaryRow("Tahsil edilen", Fmt.exactMoney(summary.collectedTotal))
            Divider().overlay(Palette.divider)
            summaryRow("Malzeme gideri", Fmt.exactMoney(summary.materialCost))
            Divider().overlay(Palette.divider)
            summaryRow("Diğer giderler", Fmt.exactMoney(summary.otherExpenses))
            Divider().overlay(Palette.divider)
            // Gider defteri geldiği için "Dönem net" artık dürüst bir rakam.
            summaryRow("Dönem net", Fmt.exactMoney(summary.net),
                       valueColor: summary.net >= .zero ? Palette.success : Palette.alertInk)

            // m² MALİYETİ — madde 25.
            //
            // Dönem çipinden BAĞIMSIZ: payda projenin tüm dairelerinin brüt
            // alanı, pay ise projenin TOPLAM maliyeti. Dönemsel maliyeti
            // dönemsel olmayan bir alana bölmek anlamsız bir rakam üretirdi.
            // Bu yüzden etiket "proje geneli" diyor.
            if let area = viewModel.areaCost(for: projectId) {
                Divider().overlay(Palette.divider)
                summaryRow("m² maliyeti (proje geneli)", Fmt.costPerArea(area.perM2))
            }

            // Bu kart ortaklara PDF olarak dağıtılıyor; kapsamı yazılı olmalı.
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle")
                    .iconFont(11, weight: .medium)
                    .padding(.top, 1)
                Text(scopeNote)
                    .font(.manrope(11, .medium))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(Palette.textTertiary)
            .padding(.top, 12)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    /// Raporun kapsam cümlesi. m² maliyeti eklendiğinde tek bir cümle
    /// yetmiyor: o rakamın paydası ORTAK ALAN İÇERMİYOR ve bu onu yukarı
    /// çekiyor — merdiven, hol, şaft ve sığınak da inşa edildi ama daire alanı
    /// toplamına girmiyor. Gerçek inşaat alanı yaklaşık %15 daha büyük,
    /// dolayısıyla gerçek m² maliyeti gösterilen rakamın ALTINDA. Model ortak
    /// alan katsayısı tutmadığı için uydurulmuyor, söyleniyor.
    private var scopeNote: String {
        var parts = ["Yalnızca uygulamaya girilen gider kayıtlarını kapsar; finansman gideri dahil değildir."]
        parts.append(taxNote)
        if let area = viewModel.areaCost(for: projectId) {
            parts.append("m² maliyetinin paydası dairelerin brüt alan toplamı (\(Fmt.qty(area.totalAreaM2)) m², \(area.measuredCount) daire); merdiven ve hol gibi ortak alanlar dahil değil, bu yüzden gerçek m² maliyeti bir miktar daha düşüktür.")
            if area.missingCount > 0 {
                parts.append("\(area.missingCount) dairenin alanı henüz girilmedi.")
            }
        }
        return parts.joined(separator: " ")
    }

    /// KDV cümlesi — madde 80.
    ///
    /// ESKİ CÜMLE ("vergi ve finansman giderleri dahil değildir") beyan
    /// varken YANLIŞ YÖNDE okunuyordu: fişler KDV DAHİL giriliyorsa vergi
    /// zaten maliyetin içinde ve cümle tersini söylüyordu.
    ///
    /// Asıl söylenmesi gereken şey daha ağır: iki taban FARKLI beyan
    /// edildiyse "Dönem net" KDV hariç bir gelirden KDV dahil bir maliyeti
    /// çıkarıyor demektir. Konutta oran %1-10, malzemede %20 — yani sapma
    /// tek yönlü bile değil: maliyet şişik, ciro düşük. Bu kart ortağa PDF
    /// olarak dağıtıldığı için sapmanın VARLIĞI yazılmak zorunda; uygulama
    /// düzeltmeye kalkışmıyor, çünkü düzeltmek oran defteri tutmak olurdu.
    private var taxNote: String {
        guard let project = viewModel.projects.first(where: { $0.id == projectId }) else {
            return "Uygulama vergi hesaplamaz."
        }
        let gider = project.expenseTaxBasis
        let satis = project.salesTaxBasis

        if gider == nil, satis == nil {
            return "Tutarların KDV tabanı belirtilmedi (proje menüsü → KDV Beyanı); "
                 + "uygulama vergi hesaplamaz."
        }
        // KISALTMA KÜÇÜLTÜLMÜYOR: `lowercased` "KDV"yi "kdv" yapıyordu.
        var cumle = "Beyan: gider tarafı \(gider.label), satış tarafı \(satis.label). "
                  + "Uygulama vergi hesaplamaz."
        // İKİ TABAN FARKLIYSA NET RAKAM KARIŞIM: söylenmezse ortak onu saf
        // bir kâr sanır.
        if gider == .dahil, satis == .haric {
            cumle += " Net rakam KDV hariç bir gelirden KDV dahil bir maliyeti "
                   + "çıkarıyor; bu fark düzeltilmiş DEĞİLDİR."
        } else if gider == .haric, satis == .dahil {
            cumle += " Net rakam KDV dahil bir gelirden KDV hariç bir maliyeti "
                   + "çıkarıyor; bu fark düzeltilmiş DEĞİLDİR."
        }
        return cumle
    }

    private func summaryRow(_ label: String, _ value: String, valueColor: Color = Palette.ink) -> some View {
        HStack {
            Text(label)
                .font(.manrope(13.5, .medium))
                .foregroundColor(Palette.textMuted)
            Spacer()
            Text(value)
                .font(.sora(15, .bold))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 13)
    }

    // MARK: Grafik kartı

    // MARK: İleriye bakan kart (madde 86)

    /// "Elimde ne kaldı, ne eder" — müteahhidin uygulamayı açma sebebi.
    ///
    /// Rapor bugüne kadar YALNIZCA GERİYE bakıyordu: ciro, tahsilat, gider.
    /// Oysa cevabın verisi zaten diskte — boş dairenin `price` alanında liste
    /// fiyatı duruyor.
    ///
    /// DÖNEM ÇİPİNDEN BAĞIMSIZ ve etiket bunu söylüyor: "şu an elimde ne var"
    /// sorusunun cevabı geçmiş bir çeyreğe göre süzülemez. Aynı gerekçe
    /// `summary.reservedCount` ve m² maliyetinde de yazılı.
    private var outlookCard: some View {
        let o = viewModel.stockOutlook(for: projectId)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Beklenen Hasılat")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                Spacer()
                Text("proje geneli")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
            }
            .padding(.bottom, 12)

            Text(Fmt.exactMoney(o.expected))
                .font(.sora(24, .bold))
                .foregroundColor(Palette.ink)

            Text("Satılan + rezerve + boş dairelerin liste fiyatı")
                .font(.manrope(11.5, .medium))
                .foregroundColor(Palette.textSecondary)
                .padding(.top, 3)
                .padding(.bottom, 12)

            // ÜÇ KOVA AYRI GÖSTERİLİYOR. Güven düzeyleri farklı: satılan
            // gerçekleşti, rezerve sözleşmesi kesinleşmedi, boş dairenin
            // liste fiyatı bir HEDEF. Tek rakama katlamak, uygulamanın
            // `countsAsRevenue`/`isSellable` ayrımıyla çözdüğü hatayı bir üst
            // katta tekrarlamak olurdu.
            Divider().overlay(Palette.divider)
            summaryRow("Satılan (gerçekleşen)", Fmt.exactMoney(o.soldTotal))
            if o.reservedCount > 0 {
                Divider().overlay(Palette.divider)
                summaryRow("Rezerve · \(o.reservedCount) daire",
                           Fmt.exactMoney(o.reservedTotal))
            }
            Divider().overlay(Palette.divider)
            summaryRow("Boş stok · \(o.availableCount) daire",
                       Fmt.exactMoney(o.availableTotal))

            // EKSİK RAKAM SÖYLENİYOR. Fiyatı girilmemiş daire toplamı sessizce
            // küçültür ve hiçbir şey bunu söylemezse kullanıcı eksik bir
            // rakama güvenir — bu uygulamanın tekrar tekrar düzelttiği hata.
            if !o.isComplete {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle")
                        .iconFont(11, weight: .semibold)
                        .padding(.top, 1)
                    Text("\(o.pricelessCount) boş dairenin liste fiyatı girilmemiş; bu tutar o daireleri İÇERMİYOR.")
                        .font(.manrope(11, .semiBold))
                        .lineSpacing(2)
                        // PDF'TE KESİLİYORDU. `ImageRenderer` yüksekliği
                        // önermediği için bu cümle tek satıra sığdırılıp
                        // "…" ile kırpılıyordu: ortağa giden belgede tam da
                        // KAPSAMI anlatan cümle yarım kalıyordu. Ekranda
                        // görünmüyordu çünkü ScrollView yüksekliği serbest
                        // bırakıyor.
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Palette.alertInk)
                .padding(.top, 12)
            }

            // SONUÇ SATIRI YALNIZCA KALAN MALİYET GİRİLDİYSE.
            //
            // Uygulama kalan maliyeti BİLMİYOR ve "harcanan ÷ %ilerleme" ile
            // türetmek, bu kod tabanının `areaCost`ta nil döndürerek reddettiği
            // tahmini yapmak olurdu: yüzde elle sürülüyor ve maliyet doğrusal
            // ilerlemiyor. Rakamı yalnızca kullanıcı verebilir; vermediyse kart
            // eskisi gibi "bu hasılattır, kâr değildir" demeye devam ediyor.
            if let kalan = o.remainingCost, let sonuc = o.projectedResult {
                Divider().overlay(Palette.divider)
                summaryRow("Bugüne kadar harcanan", "− " + Fmt.exactMoney(o.spentToDate))
                Divider().overlay(Palette.divider)
                summaryRow("Bitirmek için kalan (senin tahminin)",
                           "− " + Fmt.exactMoney(kalan))
                Divider().overlay(Palette.divider)
                summaryRow("Beklenen sonuç", Fmt.exactMoney(sonuc),
                           valueColor: sonuc >= .zero ? Palette.success : Palette.alertInk)

                // Kapsam yazılı: bu kart ortaklara PDF olarak dağıtılıyor ve
                // "beklenen sonuç" satırı bir kâr taahhüdü gibi okunabilir.
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle")
                        .iconFont(11, weight: .medium)
                        .padding(.top, 1)
                    Text("Kalan maliyet senin girdiğin tahmindir. Harcanan yalnızca "
                         + "uygulamaya girilen giderleri kapsar; vergi ve finansman dahil değildir.")
                        .font(.manrope(11, .medium))
                        .lineSpacing(2)
                        // PDF'TE KESİLİYORDU. `ImageRenderer` yüksekliği
                        // önermediği için bu cümle tek satıra sığdırılıp
                        // "…" ile kırpılıyordu: ortağa giden belgede tam da
                        // KAPSAMI anlatan cümle yarım kalıyordu. Ekranda
                        // görünmüyordu çünkü ScrollView yüksekliği serbest
                        // bırakıyor.
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Palette.textTertiary)
                .padding(.top, 12)
            } else {
                // Kalan maliyet GİRİLMEDİ. Sıfır sayıp sonucu yine de
                // göstermek, temeli yeni atılmış projede kocaman bir kâr
                // uydurmak olurdu.
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle")
                        .iconFont(11, weight: .medium)
                        .padding(.top, 1)
                    Text("Bu bir HASILAT tahminidir, kâr değildir: kalan inşaat maliyeti "
                         + "düşülmemiştir. İlerleme ekranından girersen sonuç burada görünür.")
                        .font(.manrope(11, .medium))
                        .lineSpacing(2)
                        // PDF'TE KESİLİYORDU. `ImageRenderer` yüksekliği
                        // önermediği için bu cümle tek satıra sığdırılıp
                        // "…" ile kırpılıyordu: ortağa giden belgede tam da
                        // KAPSAMI anlatan cümle yarım kalıyordu. Ekranda
                        // görünmüyordu çünkü ScrollView yüksekliği serbest
                        // bırakıyor.
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Palette.textTertiary)
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
    }

    // MARK: Blok / etap kırılımı (madde 83)

    /// Aynı parselde birden çok blok varsa: hangi blok satıldı, hangisinde
    /// stok kaldı.
    ///
    /// GİDER SATIRI YOK ve bu kartın en önemli kararı bu. Beton bütün
    /// şantiyeye dökülüyor, vinç iki bloğu birden kaldırıyor, ruhsat harcı
    /// parsele ödeniyor — blok başına maliyet dağıtmak, hiç toplanmamış bir
    /// veriden blok kârı üretmek olurdu. Kart bu yüzden yalnızca daireye
    /// KESİN olarak ait rakamları taşıyor ve eksiği kendi altında yazıyor.
    @ViewBuilder
    private var blockCard: some View {
        let slices = viewModel.blockBreakdown(for: projectId)
        if !slices.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Blok / Etap")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    Text("proje geneli")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                }
                .padding(.bottom, 4)

                ForEach(slices) { slice in
                    Divider().overlay(Palette.divider)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(slice.label.isEmpty ? "Blok belirtilmemiş" : slice.label)
                                .font(.manrope(13.5, .semiBold))
                                .foregroundColor(Palette.ink)
                            Spacer()
                            Text(Fmt.exactMoney(slice.salesTotal))
                                .font(.sora(15, .bold))
                                .foregroundColor(Palette.ink)
                        }
                        // Sayılar tek satırda: "12/16 satıldı · 3 boş · 1 kat karşılığı".
                        Text(blockDetail(slice))
                            .font(.manrope(11.5, .medium))
                            .foregroundColor(Palette.textMuted)
                    }
                    .padding(.vertical, 11)
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "info.circle")
                        .iconFont(11, weight: .medium)
                        .padding(.top, 1)
                    Text("Tutarlar SATILAN dairelerin bedelidir. Gider blok bazında "
                         + "ayrılmıyor: beton, vinç ve harç bütün parsele ait.")
                        .font(.manrope(11, .medium))
                        .lineSpacing(2)
                        // PDF'TE KESİLİYORDU. `ImageRenderer` yüksekliği
                        // önermediği için bu cümle tek satıra sığdırılıp
                        // "…" ile kırpılıyordu: ortağa giden belgede tam da
                        // KAPSAMI anlatan cümle yarım kalıyordu. Ekranda
                        // görünmüyordu çünkü ScrollView yüksekliği serbest
                        // bırakıyor.
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(Palette.textTertiary)
                .padding(.top, 12)
            }
            .padding(16)
            .background(Palette.surface)
            .cornerRadius(18)
        }
    }

    private func blockDetail(_ slice: ProjectViewModel.BlockSlice) -> String {
        var parts = ["\(slice.soldCount)/\(slice.total) satıldı"]
        if slice.stockTotal > .zero {
            // Rezerve SAYISI yazılıyor: tutarın içinde sözleşmesi
            // kesinleşmemiş daire varsa okuyucu bunu bilmeli.
            parts.append(slice.reservedCount > 0
                         ? "stok \(Fmt.compactMoney(slice.stockTotal)) · \(slice.reservedCount) rezerve dahil"
                         : "stok \(Fmt.compactMoney(slice.stockTotal))")
        }
        if slice.pricelessCount > 0 {
            // Eksik rakam SÖYLENİYOR — outlookCard'daki desenin aynısı.
            parts.append("\(slice.pricelessCount) dairenin fiyatı girilmedi")
        }
        if slice.landOwnerCount > 0 {
            parts.append("\(slice.landOwnerCount) kat karşılığı")
        }
        return parts.joined(separator: " · ")
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Aylık Satış (M ₺)")
                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)

            HStack(alignment: .bottom, spacing: 14) {
                // Sıfıra bölmeyi engelleyen taban: 1 kuruş.
                let maxValue = max(bars.map(\.value).max() ?? .zero, Kurus.kurus(1))
                ForEach(bars) { bar in
                    VStack(spacing: 7) {
                        Text(Fmt.millionsShort(bar.value))
                            .font(.sora(11, .bold))
                            .foregroundColor(Palette.textMuted)
                        // ≥7 M ₺ aylar koyu bakır, diğerleri açık ton
                        RoundedCorners(radius: 5, corners: [.topLeft, .topRight])
                            // Eşik LİRA cinsinden yazılır; kuruş sabiti bırakılsaydı
                            // 70.000 ₺ anlamına gelir ve neredeyse her ay koyu görünürdü.
                            .fill(bar.value >= Kurus.lira(7_000_000) ? Palette.accent : Palette.barSoft)
                            .frame(height: max(10, Double(bar.value.raw) / Double(maxValue.raw) * 62))
                        Text(bar.label)
                            .font(.manrope(11, .semiBold))
                            .foregroundColor(Palette.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 16)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: PDF üretimi

    /// Özet ve grafiği tek sayfalık PDF'e çevirip paylaşım sayfası açar.
    private func exportPDF() {
        let content = VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("İNŞAAT TAKİP — DÖNEM RAPORU")
                    .font(.manrope(11, .extraBold))
                    .tracking(1.4)
                    .foregroundColor(Palette.accent)
                Text(project?.title ?? "")
                    .font(.sora(24, .bold))
                    .foregroundColor(Palette.ink)
                Text("\(project?.meta ?? "") · \(Fmt.shortDate())")
                    .font(.manrope(12, .medium))
                    .foregroundColor(Palette.textSecondary)
            }
            summaryCard
            // EKRANDA NE VARSA BELGEDE DE VAR (31 Ağu 2026). PDF ortağa
            // gönderilen ASIL belge; ekranda beklenen hasılat ve blok
            // kırılımı dururken belgede durmaması, aynı projeye dair iki
            // farklı hikâye demekti — üstelik eksik olan taraf, ortağın
            // gerçekten merak ettiği ileriye bakan rakamdı.
            //
            // İkisi de DÖNEM ÇİPİNDEN BAĞIMSIZ ve etiketleri bunu söylüyor
            // ("proje geneli"): rapor bir döneme ait, bu iki kart projenin
            // bugünkü hâline.
            outlookCard
            blockCard
            chartCard
            Text("Bu rapor İnşaat Takip uygulamasından oluşturulmuştur. Ortaklar salt okunur erişime sahiptir.")
                .font(.manrope(10.5, .medium))
                .foregroundColor(Palette.textTertiary)
        }
        .padding(28)
        .frame(width: 560)
        .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 560, height: nil)

        // Ada/parsel kullanıcı girdisidir; "/" gibi karakterler var olmayan bir
        // alt dizin yolu üretip PDF'in sessizce yazılamamasına yol açardı.
        let safe: (String?) -> String = { raw in
            (raw ?? "").components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }.joined(separator: "-")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Donem-Raporu-\(safe(project?.blockNumber))-\(safe(project?.parcelNumber)).pdf")

        var didWrite = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard size.width > 0, size.height > 0,
                  let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            didWrite = true
        }

        // Yazma başarısızsa boş bir paylaşım sayfası açmak yerine kullanıcıyı bilgilendir.
        guard didWrite, FileManager.default.fileExists(atPath: url.path) else {
            viewModel.flash("PDF oluşturulamadı")
            return
        }

        sharePayload = SharePayload(url: url)
    }
}

/// Paylaşılacak dosya — sheet(item:) için kimlikli sarmalayıcı.
struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

/// Birden çok dosyayı tek paylaşımda taşır (CSV'ler + JSON yedeği).
struct ExportPayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// UIKit paylaşım sayfası köprüsü (PDF çıktısı için).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
