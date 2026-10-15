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
// EKRANDA TEK BİR RAKAM ELLE YAZILI DEĞİL. Hepsi `Plan` kataloğundan
// okunuyor: fiyat etiketi iki ayrı yerde dursaydı biri değişip diğeri
// kalırdı ve kullanıcı, ekranda okuduğu sayıyı vermeyen bir pakete para
// ödemiş olurdu.

struct PlansSheet: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    private var current: Entitlement { viewModel.entitlement }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Paketler",
                        subtitle: "Proje sayına göre seç, istediğin an değiştir") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    durumKarti

                    ForEach(Plan.allCases) { plan in
                        planKarti(plan)
                    }

                    ortakOzellikler
                    hukukiSatir

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
    }

    // MARK: Şu an neredesin

    /// Kartların ÜSTÜNDE duruyor, çünkü "hangisini alayım" sorusunun cevabı
    /// "şu an neyin var" ile başlıyor. Bu satır olmadan dört kart, hiçbiri
    /// işaretli olmayan bir fiyat listesi olurdu.
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .cornerRadius(16)
    }

    private var durumBasligi: String {
        switch current {
        case .preLaunchUnlimited: return "Yayın öncesi · tüm özellikler açık"
        case .plan(let plan):     return "Paketin: \(plan.displayName)"
        }
    }

    /// YAYIN ÖNCESİ DÖNEM AÇIKÇA SÖYLENİYOR.
    ///
    /// "Sınırsız" yazıp sebebini yazmamak, yarın sınır yürürlüğe girdiğinde
    /// kullanıcıya verilen sözün geri alındığını düşündürürdü. Bugünden "bu
    /// dönem böyle" demek, beklentiyi en başta doğru kuruyor.
    private var durumAciklamasi: String {
        switch current {
        case .preLaunchUnlimited:
            return "Bu dönemde ücret alınmıyor ve hiçbir sınır uygulanmıyor. "
                 + "Aşağıdaki paketler uygulama yayına çıktığında geçerli olacak."
        case .plan(.ucretsiz):
            return "Ücretsiz katmandasın: "
                 + Plan.ucretsiz.highlights.joined(separator: " · ")
                 + ". Arşivlenen projeler sayılmıyor."
        case .plan:
            return "Aboneliğini Ayarlar → Apple Kimliği → Abonelikler bölümünden "
                 + "yönetebilir ya da iptal edebilirsin."
        }
    }

    // MARK: Paket kartı

    private func planKarti(_ plan: Plan) -> some View {
        let secili = current == .plan(plan)
        return VStack(alignment: .leading, spacing: 11) {
            // BAŞLIK VE FİYAT AYNI SATIRDA, taban çizgisinde hizalı: kullanıcı
            // kartları fiyat sütununa göre tarıyor.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(plan.displayName)
                    .font(.sora(16, .bold))
                    .foregroundColor(Palette.ink)
                if secili {
                    Text("Paketin")
                        .smallCapsLabel(size: 9.5, color: Palette.accent, tracking: 1)
                }
                Spacer(minLength: 4)
                fiyatEtiketi(plan)
            }

            // AYIRT EDİCİ SATIRLAR KATALOGDAN. Ekranda elle yazılsaydı, bir
            // sınırı değiştirip buradaki vaadi güncellemeyi unutmak serbest
            // olurdu.
            VStack(alignment: .leading, spacing: 7) {
                ForEach(plan.highlights, id: \.self) { satir in
                    ozellikSatiri(satir, renk: Palette.ink)
                }
            }

            if let yillik = plan.yearlyPrice {
                // "İKİ AY BEDAVA" RAKAMLA BİRLİKTE: indirim iddiası, yanında
                // tutarı olmadan doğrulanamaz. Oranı `PlanTests` kilitliyor —
                // metin ile katalog ayrı yönlere gidemiyor.
                Text("Yıllık \(Fmt.money(yillik)) · iki ay bedava")
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // SATIN ALMA DÜĞMESİ BAYRAĞA BAĞLI (`Plan.purchasesAvailable`).
            // StoreKit bağlanana kadar GÖRÜNMÜYOR: çalışmayan bir düğme,
            // bastıran kullanıcıya uygulamanın bakımsız olduğunu söyler;
            // hiç olmaması ise yalnızca "henüz satışta değil" der.
            if Plan.purchasesAvailable, plan.monthlyPrice != nil, !secili {
                PrimaryButton(title: "\(plan.displayName) paketine geç") {
                    // Madde 87/c ile burası `PurchaseService.purchase(plan)`
                    // olacak; bayrak o işle birlikte açılacak.
                    viewModel.flash("Satın alma yakında açılacak")
                }
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

    @ViewBuilder
    private func fiyatEtiketi(_ plan: Plan) -> some View {
        if let aylik = plan.monthlyPrice {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Fmt.money(aylik))
                    .font(.sora(15, .bold))
                    .foregroundColor(Palette.ink)
                Text("/ay")
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(Palette.textSecondary)
            }
        }
        // ÜCRETSİZ KATMANDA FİYAT ETİKETİ HİÇ ÇİZİLMİYOR.
        //
        // Cihazda görüldü (15 Eki 2026): kartta solda "Ücretsiz", sağda yine
        // "Ücretsiz" yazıyordu. Aynı kelimeyi iki kez okumak, kullanıcıyı
        // ikisinin farklı şeyler söylediğini sanıp aramaya iter. Paketin ADI
        // zaten fiyatı söylüyor.
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

    /// AYRI KARTTA DURUYOR, paket kartlarının içinde değil.
    ///
    /// Bunlar ücretsiz katmanda da var. Paket kartlarına kopyalansaydı
    /// ücretsiz kullanıcı, zaten sahip olduğu şeyler için para ödemesi
    /// gerektiğini sanırdı — oysa ürünü satan şey tam da bunların herkeste
    /// olması.
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

    // MARK: Hukuki satır

    /// KOŞULLAR VE GİZLİLİK BAĞLANTISI PAKET EKRANINDA ZORUNLU.
    ///
    /// Apple'ın abonelik kuralı satın alma ekranında bu iki adresin ve
    /// otomatik yenileme cümlesinin bulunmasını istiyor. Satın alma bugün
    /// kapalı olsa da bağlantılar şimdiden burada: açılınca eklenmesi
    /// gereken, yani unutulabilecek bir şey kalmasın.
    private var hukukiSatir: some View {
        VStack(alignment: .leading, spacing: 8) {
            if Plan.purchasesAvailable {
                Text("Abonelikler dönem sonunda otomatik yenilenir. İptal etmezsen ücret "
                     + "yeniden alınır; iptali Ayarlar → Apple Kimliği → Abonelikler'den yapabilirsin.")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
}
