import SwiftUI

// MARK: - Hesap Silme (madde 28) — App Store 5.1.1(v)
//
// İKİ AŞAMALI ve ikinci aşama zorunlu: Firebase hassas işlemler için yakın
// oturum istiyor (`requiresRecentLogin`, 17014), yani silmeden önce yeni bir
// SMS turu dönmek zorunda.
//
// GÜVENLİK — bu ekran `AuthService.verify` KULLANMAZ. `verify` içeride
// `signIn(with:)` çağırıyor; kullanıcı başka bir numara girerse oturum
// sessizce o hesaba geçer ve ardından gelen silme YANLIŞ HESABI silerdi.
// Burada `reauthenticate` kullanılıyor ve numaranın oturumdakiyle aynı olduğu
// ayrıca denetleniyor.
//
// ONAY EKRANI NE KAYBEDİLECEĞİNİ RAKAMLA SÖYLÜYOR. "Bu işlem geri alınamaz"
// tek başına bilgi taşımıyor; müteahhidin kaç projesi, kaç dairesi ve kaç
// ortağının erişimi gittiğini görmesi gerekiyor.

struct DeleteAccountView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    // `done` adımı YOKTU ve olamazdı: `deleteAccount` `currentUser`ı nil'liyor,
    // `RootView` tüm ağacı değiştiriyor ve bu ekran o anda yok oluyor. Ekranın
    // kendi "bitti" adımı hiç çizilmiyordu — özet karşılama ekranında
    // gösteriliyor (`AppState.lastDeletionSummary`). Çizilmeyen bir adımı
    // taşımak, sonraki okuyucuya var olmayan bir yol gösteriyordu.
    private enum Step { case confirm, code }

    @State private var step: Step = .confirm
    @State private var request: VerificationRequest?
    @State private var code = ""
    @State private var busy = false
    @State private var errorText: String?

    /// SMS turu GEÇİLDİ mi?
    ///
    /// Yeniden doğrulama kimlik bilgisi TEK KULLANIMLIK. Sunucu adımı ağ
    /// yüzünden düştüğünde kullanıcı "sil" düğmesine tekrar bastığında eski
    /// kod yeniden gönderiliyordu; Firebase onu tükenmiş sayıp "Kodun süresi
    /// doldu" diyordu ve ekranda kodu yeniden gönderecek bir düğme yoktu. Yani
    /// ilk sunucu hatasından sonra akış BİR DAHA TAMAMLANAMIYORDU ve mesaj
    /// kullanıcıdan ekranda bulunmayan bir şeyi yapmasını istiyordu.
    ///
    /// Bu bayrak açıkken tekrar denemede SMS turu ATLANIYOR: doğrulama zaten
    /// başarılı oldu, oturum Firebase açısından hâlâ "yakın zamanlı". Eksik
    /// kalan yalnızca sunucu çağrısı, tekrarlanması gereken de o.
    @State private var reauthDone = false

    /// Kod adımına gelindiğinde klavye kendiliğinden açılsın.
    ///
    /// Burada tek bir alan var, o yüzden `Bool` yeterli — kardeş ekranda
    /// (PhoneSignInView) İKİ alan aynı `Bool`a bağlıydı ve odak hiçbirine
    /// gitmiyordu; oradaki bağ artık alanı ayırt ediyor.
    @FocusState private var codeFocused: Bool

    /// Silmeden önce indirilen dosyalar — paylaşım sayfasına gidiyor.
    @State private var exportPayload: ExportPayload?

    /// Silinecek olanın büyüklüğü — kullanıcının kendi verisi üzerinden.
    private var owned: [Project] {
        guard let user = appState.currentUser else { return [] }
        return viewModel.projects.filter { $0.role(for: user) == .admin }
    }

    private var partnerCount: Int {
        owned.reduce(0) { total, project in
            // Sahibin kendisi de bir Partner kaydı; erişimini kaybedecek olan
            // DİĞERLERİ sayılıyor.
            total + viewModel.partners(for: project.id).filter { $0.userUid != appState.currentUser?.id }.count
        }
    }

    private var apartmentCount: Int {
        owned.reduce(0) { $0 + viewModel.apartments(for: $1.id).count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            switch step {
            case .confirm: confirmStep
            case .code:    codeStep
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ink.ignoresSafeArea())
        .sheet(item: $exportPayload) { payload in
            ShareSheet(items: payload.urls)
        }
        // Abonelik durumu bu ekranda TAZELENİYOR: silme uyarısı yenileme
        // durumuna bakıyor ve paket ekranı oturumda hiç açılmamış olabilir.
        .task { await subscriptions.refresh() }
    }

    private var header: some View {
        HStack {
            Spacer()
            // İŞ SÜRERKEN KAPATILAMAZ. Açık bırakıldığında kullanıcı, uzun
            // süren silmeyi takılmış sanıp kapatıyordu; çağrı arka planda
            // sürüyor ve sonucu — hata olsa bile — yok edilmiş bir görünümün
            // `@State`ine yazılıp hiçbir yerde görünmüyordu. Kullanıcı hesabının
            // silindiğini sanarak devam ediyor, oysa duruyor ya da yarım
            // silinmiş olabiliyordu.
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .iconFont(14, weight: .semibold)
                    .foregroundColor(.white.opacity(busy ? 0.25 : 0.7))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .disabled(busy)
        }
        .padding(.top, 16)
    }

    // MARK: 1 — Onay

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hesabını sil")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text(impactText)
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text("Bu işlem geri alınamaz.")
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.accentLight)
                .padding(.top, 14)

            aboneligiUyar

            if let errorText {
                Text(errorText)
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.accentLight)
                    .padding(.top, 12)
            }

            // VERİYİ İNDİRME ADIMI SİLMEDEN ÖNCE VE BURADA.
            //
            // Madde 75'in ikinci cümlesi: "Hesap silmede de 'önce verini dışa
            // aktar' adımı sunulmuyor." Sunulmadığı için kullanıcı, geri dönüşü
            // olmayan işlemi verisini alma imkânı olduğunu bilmeden yapıyordu.
            //
            // Bağlantı vermek yerine DÜĞME: "her projenin Dönem Raporu
            // ekranına tek tek git" demek, silmenin hemen öncesinde en kötü
            // yönlendirme olurdu — kişi zaten vazgeçmeye değil bitirmeye
            // gelmiş, araya konan her adım atlanır.
            //
            // Yalnızca SAHİBİ OLUNAN projeler indiriliyor; ortak olunan
            // projeler zaten silinmiyor ve başkasının verisi bu akışın işi
            // değil (gerekçe `exportOwnedFiles` içinde).
            if !owned.isEmpty {
                Button {
                    exportData()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "square.and.arrow.down")
                            .iconFont(14, weight: .semibold)
                        Text("Önce verilerini indir")
                            .font(.manrope(14, .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(14)
                }
                .padding(.top, 22)

                Text("\(owned.count) projenin Excel (CSV) dosyaları ve JSON yedeği. Yedek dosyası daha sonra geri yüklenebilir.")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            }

            Button {
                Task { await sendCode() }
            } label: {
                Text(busy ? "Kod gönderiliyor…" : "Devam et")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.alertInk.opacity(busy ? 0.5 : 1))
                    .cornerRadius(14)
            }
            .disabled(busy)
            .padding(.top, 26)

            Text("Güvenlik için numarana bir kod göndereceğiz.")
                .font(.manrope(11.5, .medium))
                .foregroundColor(.white.opacity(0.62))
                .padding(.top, 12)
        }
    }

    /// ABONELİK HESAP SİLMEYLE BİTMİYOR — ödeme Apple'da.
    ///
    /// Apple'ın hesap silme rehberi: aboneliği olan kişiye faturalamanın Apple
    /// üzerinden süreceği söylenmeli ve devam etmeden önce iptal etmesi
    /// istenmeli. Söylenmeseydi kişi hesabını silip ödemeye devam ederdi —
    /// üstelik silinmiş bir hesap için.
    ///
    /// İPTAL EDİLMİŞSE BAŞKA CÜMLE: yenilenmeyecek bir aboneliği "iptal et"
    /// demek, kişiyi zaten yaptığı şeyi aramaya gönderirdi.
    ///
    /// KARAR `billingNotice`TA: hak açık olmasa da (ödeme yeniden deneniyor)
    /// yenileme sürüyorsa uyarı çıkıyor. Durum bu ekran açılınca tazeleniyor
    /// (`.task` aşağıda) — paket ekranı hiç açılmamış olabilir.
    @ViewBuilder
    private var aboneligiUyar: some View {
        switch subscriptions.billingNotice {
        case .none:
            EmptyView()
        case .continues(let plan):
            abonelikKutusu(plan, iptalEdilmis: false)
        case .cancelled(let plan):
            abonelikKutusu(plan, iptalEdilmis: true)
        }
    }

    private func abonelikKutusu(_ plan: Plan, iptalEdilmis: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(iptalEdilmis
                 ? "\(plan.displayName) aboneliğin iptal edilmiş; dönem sonunda biter ve yeniden ücret alınmaz."
                 : "\(plan.displayName) aboneliğin hesabı silince iptal olmaz: ödeme Apple üzerinden sürer. "
                   + "Devam etmeden önce aboneliğini iptal et.")
                .font(.manrope(13, .semiBold))
                .foregroundColor(.white)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if !iptalEdilmis {
                Button {
                    Task { await subscriptions.showManageSubscriptions() }
                } label: {
                    Text("Aboneliği yönet")
                        .font(.manrope(13, .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 38)
                        .background(Color.white.opacity(0.16))
                        .cornerRadius(11)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
        .padding(.top, 18)
    }

    /// Ne kaybedileceği — sayılarla. Ortağı olmayan tek projeli bir kullanıcı
    /// için de doğru okunacak biçimde kuruluyor.
    private var impactText: String {
        var parts: [String] = []
        if owned.isEmpty {
            parts.append("Hesabın ve profil bilgilerin kalıcı olarak silinecek.")
        } else {
            parts.append("Sahibi olduğun \(owned.count) proje ve içindeki \(apartmentCount) dairenin tüm kayıtları — malzeme, gider, tahsilat, fotoğraf ve belgeler — kalıcı olarak silinecek.")
            if partnerCount > 0 {
                parts.append("\(partnerCount) ortak bu projelere erişimini kaybedecek.")
            }
        }
        let memberOnly = viewModel.projects.count - owned.count
        if memberOnly > 0 {
            parts.append("Ortak olduğun \(memberOnly) projeden çıkarılacaksın; o projelerin verisi silinmez.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: 2 — Kod

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kodu gir")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text("\(PhoneFormat.pretty(request?.phone ?? "")) numarasına gönderilen 6 haneli kodu gir.")
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(4)
                .padding(.top, 12)

            TextField("", text: $code, prompt: Text("123456")
                .foregroundColor(.white.opacity(0.3)))
                .keyboardType(.numberPad)
                // SMS'ten gelen kodu klavye üstünde önerir. Kardeş giriş
                // ekranında vardı, burada yoktu — aynı işi yapan iki ekrandan
                // biri kullanıcıyı kodu elle yazmaya zorluyordu.
                .textContentType(.oneTimeCode)
                .focused($codeFocused)
                .font(.sora(20, .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1))
                .cornerRadius(14)
                .padding(.top, 22)

            if let errorText {
                Text(errorText)
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.accentLight)
                    .padding(.top, 12)
            }

            Button {
                Task { await confirmDelete() }
            } label: {
                HStack(spacing: 10) {
                    // DÖNEN GÖSTERGE. Yalnızca metin ve %50 opaklık vardı;
                    // gerçek silme saniyeler sürüyor ve duran bir ekran
                    // "takıldı" gibi okunuyordu. Kardeş ekran PhoneSignInView
                    // bunu zaten gösteriyordu.
                    if busy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(busyText)
                        .font(.manrope(15, .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Palette.alertInk.opacity(canSubmit ? 1 : 0.5))
                .cornerRadius(14)
            }
            .disabled(!canSubmit)
            .padding(.top, 22)
        }
    }

    /// Düğme metni. Doğrulama geçildikten sonra tekrar denemede "Hesabı kalıcı
    /// olarak sil" yazmak, kullanıcıya SMS turunu yeniden geçeceğini
    /// düşündürüyordu; oysa eksik kalan yalnızca sunucu adımı.
    private var busyText: String {
        if busy { return "Siliniyor…" }
        return reauthDone ? "Tekrar dene" : "Hesabı kalıcı olarak sil"
    }

    /// Doğrulama geçildiyse kod alanı artık gerekli değil — tekrar denemede
    /// altı hane şartı koşulsaydı, kodu temizlenmiş bir ekranda düğme sonsuza
    /// dek kapalı kalırdı.
    private var canSubmit: Bool {
        !busy && (reauthDone || code.count == 6)
    }

    // MARK: Aksiyonlar

    private func exportData() {
        let urls = viewModel.exportOwnedFiles(user: appState.currentUser)
        guard !urls.isEmpty else {
            errorText = "Dışa aktarılacak kayıt yok"
            return
        }
        exportPayload = ExportPayload(urls: urls)
    }

    private func sendCode() async {
        // Numara yoksa kullanıcıyı SUÇLAMA. `sendCode("")` "Telefon numarası
        // geçersiz" veriyor ve kullanıcı hiçbir şey yazmadığı için bu mesaj
        // ona yanlış bir şey yaptığını söylüyor — oysa sorun oturumda.
        guard let phone = appState.currentUser?.phone, !phone.isEmpty else {
            errorText = "Oturumunda kayıtlı numara yok · çıkış yapıp tekrar gir"
            return
        }
        busy = true
        errorText = nil
        do {
            request = try await appState.auth.sendCode(to: phone)
            step = .code
            codeFocused = true
        } catch {
            errorText = (error as? AuthError)?.errorDescription ?? "Kod gönderilemedi"
        }
        busy = false
    }

    private func confirmDelete() async {
        guard let request else { return }
        busy = true
        errorText = nil

        // ADIM 1 — SMS turu. Yalnızca bir kez; kimlik bilgisi tek kullanımlık.
        if !reauthDone {
            do {
                // `verify` DEĞİL `reauthenticate` — gerekçesi dosya başında.
                try await appState.auth.reauthenticate(code: code, for: request)
                reauthDone = true
            } catch {
                let authError = error as? AuthError
                errorText = authError?.errorDescription ?? "İşlem tamamlanamadı"
                // Yanlış kod ekranda KALMIYOR: kullanıcı altı hanenin hangisini
                // yanlış yazdığını görmüyor, tek yapabileceği baştan yazmak.
                // Kardeş ekran (PhoneSignInView) da böyle davranıyor.
                if authError == .invalidCode { code = "" }
                busy = false
                return
            }
        }

        // ADIM 2 — sunucu. Bitti adımı BURADA gösterilmiyor: `deleteAccount`
        // oturumu düşürüyor ve `RootView` tüm ağacı değiştiriyor, yani bu ekran
        // yok oluyor. Özet karşılama ekranında gösteriliyor
        // (`AppState.lastDeletionSummary`).
        do {
            _ = try await appState.deleteAccount()
        } catch {
            let hata = error as? AccountDeletionError ?? .serverFailed
            errorText = hata.errorDescription
            // Doğrulama eskimişse ya da oturum düştüyse aynı ekranda tekrar
            // denemek aynı hatayı üretir; kullanıcı BAŞA dönmeli. Bunu ona
            // söylemek yetmez, ekranı da oraya götürmek gerekiyor.
            if !hata.retryable {
                reauthDone = false
                code = ""
                step = .confirm
            }
        }
        busy = false
    }
}
