import SwiftUI

// MARK: - Hesap & Görünüm Kartı
// Dashboard'daki avatara dokununca açılır. Sistemin gri liste görünümü yerine
// uygulamanın kendi dilinde: koyu profil başlığı, seçili hâli işaretli rol
// kartları ve altta ayrık "Oturumu kapat".

struct AccountSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    private var user: User? { appState.currentUser }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Hesap",
                        subtitle: "Görünümü değiştir veya oturumu kapat") { dismiss() }

            // Profil kartı — koyu zemin, avatar + ad + aktif rol
            HStack(spacing: 13) {
                Text(user?.initials ?? "")
                    .font(.manrope(16, .extraBold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Palette.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(user?.name ?? "")
                        .font(.sora(17, .bold))
                        .foregroundColor(.white)
                    Text(appState.isAdmin
                         ? "Yönetici · tüm verileri düzenleyebilir"
                         : "İzleyici · salt okunur erişim")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.ink)
            .cornerRadius(16)
            .padding(.top, 18)

            Text("Görünüm")
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

            Button {
                dismiss()
                appState.signOut()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
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
                    .font(.system(size: 15, weight: .medium))
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
                        .font(.system(size: 13, weight: .bold))
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
