import SwiftUI

// MARK: - Bildirimler / Son Hareketler (Ekran 07)
// Koyu başlık: "Hareketler", kapsam satırı, filtre çipleri (Tümü/Malzeme/Satış).
// Akış BUGÜN / DÜN / BU HAFTA gruplarında; satırlar 28px glif rozetli.

struct ActivityFeedView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var filter: ProjectViewModel.ActivityFilter = .tumu

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ActivityItem.Section.allCases, id: \.self) { section in
                        let items = viewModel.activities(filter: filter).filter { $0.section == section }
                        if !items.isEmpty {
                            Text(section.rawValue)
                                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                                .padding(.top, 20)
                                .padding(.bottom, 10)

                            VStack(spacing: 10) {
                                ForEach(items) { item in
                                    ActivityRow(item: item)
                                }
                            }
                        }
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.markActivityRead() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                DarkHeaderButton(systemName: "chevron.left") { dismiss() }
                Spacer()
            }
            .padding(.top, 6)

            Text("Hareketler")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                .padding(.top, 14)

            Text("Tüm projeler · son 7 gün")
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 5)

            // Filtre çipleri
            HStack(spacing: 8) {
                ForEach(ProjectViewModel.ActivityFilter.allCases, id: \.self) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.rawValue)
                            .font(.manrope(12.5, .bold))
                            .foregroundColor(filter == option ? Palette.ink : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(filter == option ? Color.white : Color.white.opacity(0.08))
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
}

// MARK: - Hareket satırı

struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            badge

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                Text(item.meta)
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.timeText)
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Palette.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border, lineWidth: 1))
    }

    /// 28px tür rozeti: ↓ giriş (yeşil) · ↑ çıkış (nötr) · ₺ satış · ＋ katılım (bakır).
    private var badge: some View {
        let (symbol, bg, fg): (String, Color, Color) = {
            switch item.kind {
            case .materialIn:    return ("arrow.down", Palette.successTint, Palette.success)
            case .materialOut:   return ("arrow.up", Palette.pendingTint, Palette.textFaded)
            case .sale:          return ("turkishlirasign", Palette.accentTint, Palette.accent)
            case .partnerJoined: return ("plus", Palette.accentTint, Palette.accent)
            }
        }()
        return Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(fg)
            .frame(width: 28, height: 28)
            .background(bg)
            .cornerRadius(9)
    }
}
