import SwiftUI

// MARK: - Ortak Davet Modalı (Ekran 05, yalnızca yönetici)
// Kod üretilmeden: kesikli yer tutucu + "Proje Davet Kodu Üret".
// Üretildikten sonra: koyu kod bloğu (X7B-9Q2), kopyalanabilir bağlantı satırı,
// WhatsApp ile Paylaş ve "Kodu Kopyala" / "Yeni Kod" ikilisi.

struct InviteSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: String

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Ortak Davet Et",
                        subtitle: "Davet edilen kişi \(project?.title ?? "") projesini yalnızca görüntüleyebilir.",
                        subtitleAccent: project?.title) { dismiss() }

            if let code = project?.inviteCode {
                codeBlock(code)
                linkRow(code)
                whatsappButton(code)

                HStack(spacing: 10) {
                    OutlineButton(title: "Kodu Kopyala") {
                        viewModel.copyInviteCode(code)
                    }
                    OutlineButton(title: "Yeni Kod") {
                        viewModel.generateInviteCode(role: appState.currentUser?.role ?? .partner,
                                                    projectId: projectId)
                    }
                }
                .padding(.top, 10)
            } else {
                emptyState
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.68)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
    }

    // MARK: Durumlar

    /// Henüz kod üretilmemiş hali.
    private var emptyState: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "qrcode")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(Palette.textTertiary)
                Text("Henüz kod üretilmedi")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .background(Palette.fillSubtle)
            .cornerRadius(16)
            .dashedBorder(Palette.dashed, radius: 16)
            .padding(.top, 18)

            PrimaryButton(title: "Proje Davet Kodu Üret") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    viewModel.generateInviteCode(role: appState.currentUser?.role ?? .partner,
                                                projectId: projectId)
                }
            }
            .padding(.top, 14)
        }
    }

    /// Koyu kod bloğu: DAVET KODU etiketi, Sora 34 kod, geçerlilik notu.
    private func codeBlock(_ code: String) -> some View {
        VStack(spacing: 8) {
            Text("Davet Kodu")
                .smallCapsLabel(size: 9.5, color: .white.opacity(0.45), tracking: 1.4)
            Text(InviteCode.formatted(code))
                .font(.sora(34, .bold))
                .tracking(4)
                .foregroundColor(.white)
            Text("48 saat geçerli · tek ortak için")
                .font(.manrope(11, .medium))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Palette.ink)
        .cornerRadius(16)
        .padding(.top, 18)
    }

    /// Kopyalanabilir davet bağlantısı satırı.
    private func linkRow(_ code: String) -> some View {
        Button {
            viewModel.copyInviteLink(code)
        } label: {
            HStack {
                Text(InviteCode.link(code))
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("Kopyala")
                    .font(.manrope(12.5, .bold))
                    .foregroundColor(Palette.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Palette.fillSubtle)
            .cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
        .padding(.top, 12)
    }

    /// WhatsApp marka rengiyle paylaşım butonu (tasarım gereği yeniden boyanmaz).
    private func whatsappButton(_ code: String) -> some View {
        Button {
            if let project {
                viewModel.shareInviteViaWhatsApp(project: project, raw: code)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "message.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("WhatsApp ile Paylaş")
                    .font(.manrope(15, .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.whatsapp)
            .cornerRadius(14)
            .shadow(color: Palette.whatsapp.opacity(0.3), radius: 9, x: 0, y: 7)
        }
        .padding(.top, 12)
    }
}
