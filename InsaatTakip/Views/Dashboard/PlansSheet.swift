import SwiftUI

// MARK: - Paketler (madde 87)
//
// NEDEN BU EKRAN VAR: paket kataloğu koda yazıldı ama kullanıcının onu
// görebileceği TEK AN, bir sınıra çarpıp şerit mesajı okuduğu andı. Yani
// fiyatı ancak REDDEDİLEREK öğreniyordu — satın alma kararını bir hata
// mesajının üstüne kurmak, ürünü hem ucuz hem düşmanca gösterir.
//
// NEDEN ARA ARA ÇIKAN BİR HATIRLATMA DEĞİL: kendi ürününü araya girerek
// tanıtmak reklamın ta kendisi ve `Plan.swift` reklamı üç gerekçeyle
// reddediyor — üçü de burada aynen geçerli. Bunun yerine giriş noktaları
// SABİT ve SESSİZ: panoda duran bir satır, hesap kartında bir satır. İkisi
// de kullanıcıyı kesmiyor, ikisi de her an orada.
//
// FİYAT MAĞAZADAN (25 Eki 2026). 1.0 (169), fiyat gösterip satın alma ürünü
// sunmadığı için 2.1(b) ile reddedildi. Artık ekrandaki her fiyat Apple'ın
// `displayPrice`ı: tahsil edilen tutarla harfi harfine aynı ve kişinin mağaza
// bölgesinin parasıyla. Mağaza cevap vermezse fiyat YAZILMIYOR — katalogdaki
// hedef rakamı göstermek, Apple'ın tahsil etmeyeceği bir tutarı söz vermek
// olurdu. Sınırlar ve paket farkları hâlâ `Plan` kataloğundan.
//
// APPLE 3.1.2'NİN İSTEDİKLERİ BU EKRANDA: paketin adı, süresi, tahsil edilen
// tutar (en belirgin fiyat öğesi), otomatik yenileme ve iptal cümlesi,
// kullanım koşulları ve gizlilik bağlantıları, "Satın alımları geri yükle".

struct PlansSheet: View {
    /// Ekran bir SINIRA ÇARPILARAK açıldıysa dolu gelir.
    ///
    /// NEDEN PARAMETRE: aynı ekran iki ayrı sebeple açılıyor — kullanıcı
    /// merak edip baktığında ve duvara çarptığında. İkisinde aynı cümleyi
    /// göstermek, duvara çarpanı "sen zaten bakıyordun" yerine koymak olurdu.
    var sinirdaki: Bool = false

    @EnvironmentObject private var viewModel: ProjectViewModel
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var donem: BillingPeriod = .monthly
    /// Sonuç uyarısı. TOAST DEĞİL: toast panonun üstünde çiziliyor ve bu
    /// sheet açıkken görünmüyor — "abonelik bulunamadı" sessizce kaybolurdu.
    private struct Uyari: Equatable { let baslik: String; let mesaj: String }
    @State private var uyari: Uyari?

    private var current: Entitlement { subscriptions.entitlement }

    /// Uçuşta bir işlem varken bütün düğmeler kilitli: iki satın alma
    /// penceresi üst üste açılamaz, geri yükleme satın almayla yarışamaz.
    private var mesgul: Bool { subscriptions.purchasingId != nil || subscriptions.restoring }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Paketler",
                        subtitle: "Proje sayına göre seç, istediğin an değiştir") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    durumKarti
                    donemSecici

                    if subscriptions.offersState == .failed {
                        fiyatYuklenemedi
                    }

                    ForEach(Plan.allCases) { plan in
                        planKarti(plan)
                    }

                    ortakOzellikler
                    hukukiBolum

                    Spacer().frame(height: 16)
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.page)
        .sheetHeight(0.92)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        // MESAJ BU EKRANIN ÜSTÜNDE. Kökteki toast bu sheet'in ve onu açan
        // Hesap sheet'inin ARKASINDA çiziliyor; 25 Eki'de TestFlight'ta
        // görüldü: geri yükleme başarılıydı, ekran kapandı, "Paketin geri
        // yüklendi" mesajı Hesap ekranının arkasında kaldı ve kişi hiçbir
        // şey olmadığını sandı. Diğer sheet'ler aynı sebeple kendi
        // katmanlarını taşıyor.
        .toastOverlay(viewModel.toast)
        .task {
            if let durum = subscriptions.status { donem = durum.period }
            if subscriptions.offersState != .loaded { await subscriptions.loadOffers() }
            if let durum = subscriptions.status { donem = durum.period }
        }
        .alert(uyari?.baslik ?? "",
               isPresented: Binding(get: { uyari != nil }, set: { if !$0 { uyari = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(uyari?.mesaj ?? "")
        }
    }

    // MARK: Şu an neredesin

    /// Kartların ÜSTÜNDE duruyor, çünkü "hangisini alayım" sorusunun cevabı
    /// "şu an neyin var" ile başlıyor.
    private var durumKarti: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(durumBasligi)
                .font(.sora(16, .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(durumAciklamasi)
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if case .plan(let plan) = current, plan != .ucretsiz {
                Button {
                    Task { await subscriptions.showManageSubscriptions() }
                } label: {
                    Text("Aboneliği yönet")
                        .font(.manrope(12.5, .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(Color.white.opacity(0.14))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .cornerRadius(16)
    }

    private var durumBasligi: String {
        if sinirdaki { return "Aktif proje sınırındasın" }
        switch current {
        case .resolving:          return "Paketin kontrol ediliyor"
        case .plan(.ucretsiz):    return "Ücretsiz katmandasın"
        case .plan(let plan):
            if let durum = subscriptions.status, durum.plan == plan {
                return "Paketin: \(plan.displayName) · \(durum.period.label)"
            }
            return "Paketin: \(plan.displayName)"
        }
    }

    /// DURUM CÜMLESİ APPLE'IN SÖYLEDİĞİNİ TEKRARLIYOR, TAHMİN ETMİYOR.
    /// Yenilenme tarihi, iptal ve ödeme sorunu `ActiveSubscription`tan; bilgi
    /// gelmediyse cümle tarih uydurmuyor.
    private var durumAciklamasi: String {
        // SINIRDAYKEN ÜCRETSİZ ÇIKIŞ ÖNCE SÖYLENİYOR: arşiv kayıtları silmiyor,
        // yalnızca kontenjanı boşaltıyor — gerçekten bedava bir çıkış.
        if sinirdaki {
            return "Biten projeyi arşivlemek ücretsiz: kayıtları durur ve okunabilir kalır, "
                 + "kontenjanın boşalır. Aynı anda daha fazla proje tutmak için paket seçebilirsin."
        }
        switch current {
        case .resolving:
            return "App Store'daki aboneliğin okunuyor."
        case .plan(.ucretsiz):
            return Plan.ucretsiz.highlights.joined(separator: " · ")
                 + ". Arşivlenen projeler sayılmıyor ve her zaman okunabilir."
        case .plan:
            guard let durum = subscriptions.status else {
                return "Aboneliğini Ayarlar → Apple Kimliği → Abonelikler'den yönetebilirsin."
            }
            var cumle: String
            switch durum.state {
            case .renewing:
                cumle = durum.expiresAt.map { "\(Fmt.shortDate($0)) tarihinde yenilenir." }
                    ?? "Dönem sonunda yenilenir."
            case .cancelled:
                cumle = durum.expiresAt.map { "Yenilenmeyecek; \(Fmt.shortDate($0)) tarihinde sona erer." }
                    ?? "Yenilenmeyecek; dönem sonunda sona erer."
            case .billingIssue:
                cumle = "Ödeme alınamadı. Apple'daki ödeme bilgini güncelle; güncellenmezse paket "
                      + "sona erer ve sınırın üstündeki projeler salt okunur olur."
            }
            if let sonraki = durum.nextPlan {
                cumle += " Dönem sonunda \(sonraki.displayName) paketine geçilecek."
            }
            return cumle
        }
    }

    // MARK: Dönem seçici

    private var donemSecici: some View {
        HStack(spacing: 4) {
            ForEach(BillingPeriod.allCases) { d in
                Button {
                    donem = d
                } label: {
                    Text(d.label)
                        .font(.manrope(13, .bold))
                        .foregroundColor(donem == d ? .white : Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(donem == d ? Palette.ink : Color.clear)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(donem == d ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.surface)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
    }

    // MARK: Mağaza cevap vermedi

    /// FİYATSIZ KART DÜĞMESİZ. Ürünler gelmezse (bağlantı yok, App Store
    /// Connect'te ürün onaylanmamış) satın alma düğmesi gösterilmiyor; neden
    /// gösterilmediği burada söyleniyor ve tekrar denenebiliyor.
    private var fiyatYuklenemedi: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "wifi.exclamationmark")
                .iconFont(14, weight: .semibold)
                .foregroundColor(Palette.alertInk)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text("Fiyatlar App Store'dan yüklenemedi. Bağlantını kontrol edip tekrar dene.")
                    .font(.manrope(12.5, .medium))
                    .foregroundColor(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Tekrar dene") {
                    Task { await subscriptions.loadOffers() }
                }
                .font(.manrope(12.5, .bold))
                .foregroundColor(Palette.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.alertTint.opacity(0.6))
        .cornerRadius(14)
    }

    // MARK: Paket kartı

    private func planKarti(_ plan: Plan) -> some View {
        let secili = current == .plan(plan)
        let teklif = subscriptions.offer(plan, donem)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(plan.displayName)
                    .font(.sora(16, .bold))
                    .foregroundColor(Palette.ink)
                if secili {
                    Text("Paketin")
                        .smallCapsLabel(size: 9.5, color: Palette.accent, tracking: 1)
                }
                Spacer(minLength: 4)
                if let teklif { fiyatEtiketi(teklif) }
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(plan.highlights, id: \.self) { satir in
                    ozellikSatiri(satir, renk: Palette.ink)
                }
            }

            if let not = tasarrufNotu(plan) {
                Text(not)
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let tanitim = teklif?.introOffer {
                Text(tanitim)
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(Palette.success)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let teklif, let baslik = dugmeBasligi(plan, teklif) {
                satinAlDugmesi(baslik, teklif)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(secili ? Palette.accent : Palette.border,
                        lineWidth: secili ? 1.5 : 1)
        )
    }

    /// TAHSİL EDİLEN TUTAR EN BELİRGİN ÖĞE (3.1.2). Yıllıkta "aylık karşılığı"
    /// yazılmıyor: büyük puntoyla aylık rakam gösterip yıllık tahsil etmek,
    /// Apple'ın tam olarak yasakladığı şey.
    private func fiyatEtiketi(_ teklif: StoreOffer) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(teklif.displayPrice)
                .font(.sora(15, .bold))
                .foregroundColor(Palette.ink)
            Text("/\(teklif.period.unit)")
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textSecondary)
        }
    }

    /// YILLIK TASARRUF MAĞAZA FİYATLARINDAN HESAPLANIYOR. Eskiden katalogdan
    /// "iki ay bedava" yazıyordu; Apple'ın fiyat basamakları katalogdaki
    /// rakamı birebir tutmayabilir ve o zaman cümle yanlış olurdu. Oran aşağı
    /// yuvarlanıyor: abartılmış bir indirim, söz verilenden az vermek demek.
    private func tasarrufNotu(_ plan: Plan) -> String? {
        guard let aylik = subscriptions.offer(plan, .monthly),
              let yillik = subscriptions.offer(plan, .yearly),
              aylik.price > 0 else { return nil }
        let oran = (1 - yillik.price / (aylik.price * 12)) * 100
        var yuvarlak = Decimal()
        var kaynak = oran
        NSDecimalRound(&yuvarlak, &kaynak, 0, .down)
        let yuzde = NSDecimalNumber(decimal: yuvarlak).intValue
        guard yuzde >= 1 else { return nil }
        return donem == .yearly
            ? "Aylık ödemeye göre yılda %\(yuzde) daha az"
            : "Yıllık ödemede %\(yuzde) tasarruf"
    }

    /// Düğme metni DURUMA göre. `nil` = düğme yok (zaten bu paket ve dönem).
    private func dugmeBasligi(_ plan: Plan, _ teklif: StoreOffer) -> String? {
        guard plan != .ucretsiz else { return nil }
        if current == .plan(plan) {
            guard let durum = subscriptions.status, durum.plan == plan else { return nil }
            return durum.period == teklif.period ? nil : "\(teklif.period.label) ödemeye geç"
        }
        if case .plan(let mevcut) = current, mevcut != .ucretsiz {
            return "\(plan.displayName) paketine geç"
        }
        return "\(plan.displayName) · \(teklif.displayPrice)/\(teklif.period.unit)"
    }

    private func satinAlDugmesi(_ baslik: String, _ teklif: StoreOffer) -> some View {
        let bu = subscriptions.purchasingId == teklif.id
        return Button {
            Task { await satinAl(teklif) }
        } label: {
            HStack(spacing: 9) {
                if bu { ProgressView().tint(.white) }
                Text(baslik).font(.manrope(14.5, .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(Palette.accent.opacity(mesgul && !bu ? 0.45 : 1))
            .cornerRadius(13)
        }
        .buttonStyle(.plain)
        .disabled(mesgul || !subscriptions.canMakePayments)
    }

    private func satinAl(_ teklif: StoreOffer) async {
        switch await subscriptions.purchase(teklif, uid: appState.currentUser?.id) {
        case .purchased(let plan):
            // EKRAN AÇIK KALIYOR: üstteki durum kartı yeni paketi ve
            // yenilenme tarihini hemen gösteriyor — sonucun kendisi bu.
            // Kapatmak, kişiyi sonucu göremediği bir ekrana bırakıyordu.
            viewModel.flash("Paketin: \(plan.displayName)")
        case .pending:
            uyari = Uyari(baslik: "Onay bekleniyor",
                          mesaj: "Satın alma onay bekliyor (ör. Aile Paylaşımı'nda \"Satın Almak İçin Sor\"). "
                               + "Onaylanınca paketin kendiliğinden açılır.")
        case .failed(let neden):
            uyari = Uyari(baslik: neden.title, mesaj: neden.message)
        case .cancelled, .busy:
            break
        }
    }

    private func ozellikSatiri(_ metin: String, renk: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark")
                .iconFont(11, weight: .bold)
                .foregroundColor(Palette.accent)
                .padding(.top, 2)
            Text(metin)
                .font(.manrope(12.5, .medium))
                .foregroundColor(renk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: Her pakette olanlar

    /// AYRI KARTTA DURUYOR, paket kartlarının içinde değil: bunlar ücretsiz
    /// katmanda da var ve kartlara kopyalansaydı ücretsiz kullanıcı, zaten
    /// sahip olduğu şeyler için para ödemesi gerektiğini sanırdı.
    private var ortakOzellikler: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Her pakette")
                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
            ForEach(Plan.commonFeatures, id: \.self) { satir in
                ozellikSatiri(satir, renk: Palette.textSecondary)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .cornerRadius(15)
    }

    // MARK: Hukuki bölüm (3.1.2)

    private var hukukiBolum: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !subscriptions.canMakePayments {
                Text("Bu cihazda uygulama içi satın alma kapalı (Ekran Süresi sınırlaması).")
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(Palette.alertInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Ödeme, satın almayı onayladığında Apple Kimliğinden alınır. Abonelik, dönem "
                 + "bitiminden en az 24 saat önce iptal edilmedikçe aynı süre ve ücretle otomatik "
                 + "yenilenir; yenileme ücreti dönem bitiminden önceki 24 saat içinde alınır. "
                 + "Aboneliğini Ayarlar → Apple Kimliği → Abonelikler'den yönetebilir ya da iptal "
                 + "edebilirsin. Abonelik bitince verilerin silinmez; sınırın üstündeki projeler "
                 + "salt okunur olur.")
                .font(.manrope(11, .medium))
                .foregroundColor(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await geriYukle() }
            } label: {
                HStack(spacing: 7) {
                    if subscriptions.restoring { ProgressView() }
                    Text("Satın alımları geri yükle")
                        .font(.manrope(12.5, .bold))
                }
                .foregroundColor(Palette.ink)
            }
            .buttonStyle(.plain)
            .disabled(mesgul)

            HStack(spacing: 16) {
                if let kosullar = AppInfo.termsURL {
                    Link("Kullanım koşulları", destination: kosullar)
                        .font(.manrope(11.5, .semiBold))
                }
                if let gizlilik = AppInfo.privacyPolicyURL {
                    Link("Gizlilik politikası", destination: gizlilik)
                        .font(.manrope(11.5, .semiBold))
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(Palette.textSecondary)
        }
    }

    private func geriYukle() async {
        switch await subscriptions.restore() {
        case .restored(let plan):
            viewModel.flash("Paketin geri yüklendi: \(plan.displayName)")
        case .nothingFound:
            uyari = Uyari(baslik: "Abonelik bulunamadı",
                          mesaj: "Bu Apple Kimliğinde etkin bir İnşaat Takip aboneliği yok. Aboneliği "
                               + "başka bir Apple Kimliğiyle aldıysan o kimlikle App Store'a giriş yapıp tekrar dene.")
        case .failed(let neden):
            uyari = Uyari(baslik: neden.title, mesaj: neden.message)
        case .cancelled, .busy:
            break
        }
    }
}
