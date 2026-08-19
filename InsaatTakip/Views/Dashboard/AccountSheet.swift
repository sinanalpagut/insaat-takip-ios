import SwiftUI

// MARK: - Hesap & Görünüm Kartı
// Dashboard'daki avatara dokununca açılır. Sistemin gri liste görünümü yerine
// uygulamanın kendi dilinde: koyu profil başlığı, seçili hâli işaretli rol
// kartları ve altta ayrık "Oturumu kapat".

struct AccountSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteFlow = false

    private var user: User? { appState.currentUser }

    @State private var isEditingName = false
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Hesap",
                        subtitle: "Görünümü değiştir veya oturumu kapat") { dismiss() }

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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .fullScreenCover(isPresented: $showDeleteFlow) {
            DeleteAccountView()
        }
        .sheetHeight(0.62)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
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
