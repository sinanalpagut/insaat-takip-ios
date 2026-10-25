import SwiftUI

// MARK: - Hesap & Görünüm Kartı
// Dashboard'daki avatara dokununca açılır. Sistemin gri liste görünümü yerine
// uygulamanın kendi dilinde: koyu profil başlığı, seçili hâli işaretli rol
// kartları ve altta ayrık "Oturumu kapat".

struct AccountSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @EnvironmentObject private var appLock: AppLock
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteFlow = false
    @State private var showPlans = false

    private var user: User? { appState.currentUser }

    @State private var isEditingName = false
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Hesap",
                        subtitle: "Görünümü değiştir veya oturumu kapat") { dismiss() }

            // GÖVDE KAYDIRILABİLİR (15 Eki 2026).
            //
            // Paket bölümü ve iki hukuki satır eklenince içerik küçük
            // ekranlarda sabit yüksekliği aşıyordu: SwiftUI taşan kısmı
            // sessizce KIRPAR — yani "Hesabı Sil" düğmesi, App Store'un
            // 5.1.1(v) ile zorunlu kıldığı tek giriş, hiç görünmeden
            // kaybolurdu. Kırpılma hata vermediği için de ancak sahada
            // fark edilirdi.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    profileCard
                        .padding(.top, 18)

                    // Rol değiştirme yalnızca GELİŞTİRME derlemesinde. Yayın sürümünde açık
                    // kalsaydı, salt okunur olması gereken ortak kendini iki dokunuşta
                    // yönetici yapabilir; ViewModel'deki tüm yetki kontrolleri anlamsızlaşırdı.
                    // Gerçek rol, oturum açan hesaptan gelecek (Faz 2 — kimlik doğrulama).
                    #if DEBUG
                    Text("Görünüm · geliştirme")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                    roleRow(role: .admin,
                            icon: "square.and.pencil",
                            title: "Yönetici görünümü",
                            detail: "Malzeme, satış ve belge girişi yapabilirsin")

                    roleRow(role: .partner,
                            icon: "eye",
                            title: "Ortak görünümü",
                            detail: "Salt okunur — ortakların gördüğü ekran")
                        .padding(.top, 9)
                    #endif

                    // ─── Paket (madde 87) ───
                    //
                    // NEDEN HESAP KARTINDA: ödeme ilişkisi hesabın bir özelliği,
                    // projenin değil. Kullanıcı "ne ödüyorum" sorusunu sorduğunda
                    // baktığı yer burası — oturum ve hesap silmenin durduğu yer.
                    //
                    // PANODAKİ SATIRLA ÇİFT GİRİŞ BİLİNÇLİ: panodaki satır kullanıcı
                    // aramadan görünür, buradaki ise arayınca bulunur. Biri diğerinin
                    // yedeği değil; ikisi iki farklı soruyu karşılıyor.
                    Text("Paket")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                    Button {
                        showPlans = true
                    } label: {
                        infoRow(icon: "square.stack.3d.up",
                                title: paketBasligi,
                                detail: "Paketleri ve sınırları gör",
                                trailing: nil)
                    }
                    .buttonStyle(.plain)
                    .background(Palette.surface)
                    .cornerRadius(15)

                    // ─── Güvenlik: uygulama kilidi (madde 78) ───
                    //
                    // ROLDEN BAĞIMSIZ: ortağın gördüğü ekranlar da ciro, tahsilat ve
                    // taksit planı taşıyor. Kilidi yalnızca yöneticiye vermek,
                    // korumayı verinin yarısında bırakmak olurdu.
                    Text("Güvenlik")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                    lockRow

                    // ─── Destek ve sürüm (madde 72) ───
                    //
                    // Crashlytics bilinçli olarak ertelendi; o yüzden bu satırlar
                    // sahadaki bir hatanın görünebildiği TEK kanal. İkisi de yokken
                    // kullanıcı bildiremiyor, geliştirici ölçemiyordu.
                    Text("Destek")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                    supportRows

                    Button {
                        dismiss()
                        appState.signOut()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .iconFont(14, weight: .semibold)
                            Text("Oturumu Kapat")
                                .font(.manrope(14, .bold))
                        }
                        .foregroundColor(Palette.alertInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Palette.alertTint.opacity(0.6))
                        .cornerRadius(14)
                    }
                    .padding(.top, 20)

                    // HESAP SİLME — App Store 5.1.1(v) zorunluluğu.
                    //
                    // Apple silme girişinin uygulama İÇİNDE ve bulunabilir olmasını
                    // istiyor; web sayfasına yönlendirme reddediliyor. Hakem hesap
                    // ekranına bakacak, bu yüzden burada.
                    //
                    // Görsel olarak "Oturumu Kapat"tan AYRI ve daha sessiz: ikisi
                    // eşit ağırlıkta dursaydı yanlışlıkla silme riski artardı.
                    Button {
                        showDeleteFlow = true
                    } label: {
                        Text("Hesabı Sil")
                            .font(.manrope(13, .semiBold))
                            .foregroundColor(Palette.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .padding(.top, 4)

                    Spacer().frame(height: 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .fullScreenCover(isPresented: $showDeleteFlow) {
            DeleteAccountView()
        }
        .sheet(isPresented: $showPlans) {
            PlansSheet()
        }
        .sheetHeight(0.86)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
    }

    /// Satırın başlığı DURUMU söylüyor, sabit bir etiket değil.
    ///
    /// "Yükselt" yazıp geçmek, yayın öncesi dönemde zaten her şeye sahip olan
    /// kullanıcıya yalan söylemek olurdu; ücretli pakette ise satın almış
    /// kişiye tekrar satmaya çalışmak olurdu.
    private var paketBasligi: String {
        switch viewModel.entitlement {
        case .resolving: return "Paketler"
        case .plan(.ucretsiz):    return "Ücretsiz katman · yükselt"
        case .plan(let plan):     return "\(plan.displayName) paketi"
        }
    }

    // MARK: Profil kartı

    /// Koyu zemin, avatar + ad + telefon + aktif rol. Ad yerinde düzenlenir:
    /// isim ekranı "sonradan değiştirebilirsin" diyor, karşılığı burası.
    /// Telefon de burada gösteriliyor — kimliğin kendisi o numara, kullanıcının
    /// hangi numarayla girdiğini görebileceği başka bir yer yok.
    private var profileCard: some View {
        HStack(spacing: 13) {
            Text(user?.initials ?? "")
                .font(.manrope(16, .extraBold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Palette.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                if isEditingName {
                    TextField("", text: $draftName,
                              prompt: Text("Ad Soyad").foregroundColor(.white.opacity(0.3)))
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .font(.sora(17, .bold))
                        .foregroundColor(.white)
                        .onSubmit { commitName() }
                } else {
                    Text(user?.name ?? "")
                        .font(.sora(17, .bold))
                        .foregroundColor(.white)
                }

                if let phone = user?.phone, !phone.isEmpty {
                    Text(PhoneFormat.pretty(phone))
                        .font(.manrope(11.5, .semiBold))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(appState.isAdmin
                     ? "Yönetici · tüm verileri düzenleyebilir"
                     : "İzleyici · salt okunur erişim")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 4)

            Button {
                if isEditingName {
                    commitName()
                } else {
                    draftName = user?.name ?? ""
                    isEditingName = true
                    nameFocused = true
                }
            } label: {
                Image(systemName: isEditingName ? "checkmark" : "pencil")
                    .iconFont(14, weight: .semibold)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(12)
            }
            .disabled(isEditingName && draftName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .cornerRadius(16)
    }

    /// Boş ad kaydedilmez: alan boş bırakılıp onaylanırsa eski ad korunur ve
    /// düzenleme kapanır — aksi halde avatar baş harfleri boşalırdı.
    private func commitName() {
        appState.updateName(draftName)
        isEditingName = false
        nameFocused = false
    }

    private var supportRows: some View {
        VStack(spacing: 0) {
            // GERİ BİLDİRİM — tanı bilgisi e-postaya ÖNCEDEN yazılı
            // (gerekçesi `AppInfo.supportMailURL` içinde).
            if let mail = AppInfo.supportMailURL {
                Link(destination: mail) {
                    infoRow(icon: "envelope",
                            title: "Geri bildirim gönder",
                            detail: "Hata bildir ya da öneride bulun",
                            trailing: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.divider).padding(.leading, 68)
            }

            // GİZLİLİK POLİTİKASI — adres yokken satır HİÇ çizilmiyor
            // (madde 27). Çalışmayan bir bağlantı, hiç bağlantı olmamasından
            // kötü.
            if let policy = AppInfo.privacyPolicyURL {
                Link(destination: policy) {
                    infoRow(icon: "hand.raised",
                            title: "Gizlilik politikası",
                            detail: "Verilerin nasıl saklandığı",
                            trailing: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.divider).padding(.leading, 68)
            }

            // KVKK AYDINLATMA METNİ AYRI SATIR.
            //
            // Gizlilik politikasının içine gömülseydi, KVKK'nın istediği
            // başlıklar (veri sorumlusu, hukuki sebep, m.11 hakları) genel
            // metnin içinde kaybolurdu. Türkiye'deki kullanıcı "KVKK" diye
            // arıyor; aradığı kelimeyi ekranda bulmalı.
            if let kvkk = AppInfo.kvkkNoticeURL {
                Link(destination: kvkk) {
                    infoRow(icon: "doc.text",
                            title: "KVKK aydınlatma metni",
                            detail: "Hangi veri, hangi hukuki sebeple",
                            trailing: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.divider).padding(.leading, 68)
            }

            if let kosullar = AppInfo.termsURL {
                Link(destination: kosullar) {
                    infoRow(icon: "checkmark.seal",
                            title: "Kullanım koşulları",
                            detail: "Hizmetin sınırları ve abonelik",
                            trailing: nil)
                }
                .buttonStyle(.plain)
                Divider().overlay(Palette.divider).padding(.leading, 68)
            }

            // SÜRÜM — dokununca panoya kopyalanıyor. Destek e-postasına elle
            // yazdırmak, yanlış yazılmasına ve yanlış derlemede hata
            // aranmasına yol açardı.
            Button {
                UIPasteboard.general.string = AppInfo.versionText
                viewModel.flash("Sürüm kopyalandı · \(AppInfo.versionText)")
            } label: {
                infoRow(icon: "info.circle",
                        title: "Sürüm",
                        detail: "Dokun ve kopyala",
                        trailing: AppInfo.versionText)
            }
            .buttonStyle(.plain)
        }
        .background(Palette.surface)
        .cornerRadius(15)
    }

    private func infoRow(icon: String, title: String,
                         detail: String, trailing: String?) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .iconFont(15, weight: .medium)
                .foregroundColor(Palette.textMuted)
                .frame(width: 42, height: 42)
                .background(Palette.fillMuted)
                .cornerRadius(13)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(Palette.ink)
                Text(detail)
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.textSecondary)
            }
        }
        .padding(13)
        .contentShape(Rectangle())
    }

    /// Uygulama kilidi anahtarı.
    ///
    /// CİHAZDA EKRAN KİLİDİ YOKSA ANAHTAR KAPALI ve sebebi YAZILI. Açılabilir
    /// bırakılsaydı kullanıcı, açamayacağı bir kilidin arkasında kalırdı —
    /// üstelik bunu ancak uygulamayı bir kez arka plana attıktan sonra
    /// öğrenirdi.
    private var lockRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { appLock.isEnabled },
                                 set: { appLock.isEnabled = $0 })) {
                HStack(spacing: 13) {
                    Image(systemName: "faceid")
                        .iconFont(15, weight: .medium)
                        .foregroundColor(appLock.isEnabled ? Palette.accent : Palette.textMuted)
                        .frame(width: 42, height: 42)
                        .background(appLock.isEnabled ? Palette.accentTint : Palette.fillMuted)
                        .cornerRadius(13)

                    VStack(alignment: .leading, spacing: 3) {
                        // BAŞLIK KESİLMİYOR (2 Eyl 2026 · cihaz turu): en
                        // büyük metinde "Uygulam…" oluyordu — ayarın ADI
                        // okunamıyordu, oysa altındaki açıklama sarılıyordu.
                        Text("Uygulama kilidi")
                            .font(.manrope(13.5, .bold))
                            .foregroundColor(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Uygulamaya dönüşte kimlik doğrulanır · değiştiricide içerik gizlenir")
                            .font(.manrope(11.5, .medium))
                            .foregroundColor(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .disabled(!appLock.canAuthenticate)

            if !appLock.canAuthenticate {
                Text(appLock.unavailableReason)
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(Palette.alertInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .background(Palette.surface)
        .cornerRadius(15)
    }

    /// Seçilebilir rol satırı; aktif olan bakır tik ile işaretlenir.
    private func roleRow(role: UserRole, icon: String, title: String, detail: String) -> some View {
        let isActive = appState.currentUser?.role == role
        return Button {
            guard !isActive else { return }
            appState.switchRole(to: role)
            dismiss()
            viewModel.flash(role == .admin ? "Yönetici görünümü" : "Ortak görünümü · salt okunur")
        } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .iconFont(15, weight: .medium)
                    .foregroundColor(isActive ? Palette.accent : Palette.textMuted)
                    .frame(width: 42, height: 42)
                    .background(isActive ? Palette.accentTint : Palette.fillMuted)
                    .cornerRadius(13)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.manrope(13.5, .bold))
                        .foregroundColor(Palette.ink)
                    Text(detail)
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Spacer(minLength: 4)

                if isActive {
                    Image(systemName: "checkmark")
                        .iconFont(13, weight: .bold)
                        .foregroundColor(Palette.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Palette.surface)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isActive ? Palette.accent : Palette.border, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
