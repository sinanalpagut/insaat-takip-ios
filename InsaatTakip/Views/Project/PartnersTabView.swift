import SwiftUI

// MARK: - Ortaklar Sekmesi (Ekran 05)
// Ortak satırları: 40px baş harf avatarı (yönetici = ink, ortak = bakır tint),
// ad + rol, katılım tarihi, sağda bakır hisse yüzdesi.
// Ortak rolündeyken salt-okunur açıklaması gösterilir; davet FAB'ı yalnızca yöneticide.

struct PartnersTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                HStack {
                    Text("Hisse Dağılımı")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    Text("%100 tanımlı")
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.textSecondary)
                }
                .padding(.top, 16)

                ForEach(viewModel.partners(for: projectId)) { partner in
                    PartnerRowView(partner: partner)
                }

                // Ortak görünümü: davet yetkisinin kimde olduğunu açıklayan not.
                if appState.isPartner {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Palette.accent)
                            .padding(.top, 1)
                        Text("Bu projeyi salt okunur takip ediyorsun. Yeni ortak daveti yalnızca yönetici tarafından yapılabilir.")
                            .font(.manrope(12, .medium))
                            .foregroundColor(Palette.textMuted)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.accentTint.opacity(0.55))
                    .cornerRadius(14)
                    .padding(.top, 6)
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Ortak satırı

struct PartnerRowView: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 12) {
            Text(partner.initials)
                .font(.manrope(13, .extraBold))
                .foregroundColor(partner.isFounder ? .white : Palette.accent)
                .frame(width: 40, height: 40)
                .background(partner.isFounder ? Palette.ink : Palette.accentTint)
                .cornerRadius(13)

            VStack(alignment: .leading, spacing: 3) {
                Text(partner.name)
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(Palette.ink)
                Text(partner.joinedText)
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Text("%\(partner.sharePercent)")
                .font(.sora(15, .bold))
                .foregroundColor(Palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Palette.surface)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.border, lineWidth: 1))
    }
}
