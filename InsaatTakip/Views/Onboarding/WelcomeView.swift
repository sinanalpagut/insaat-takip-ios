import SwiftUI

// MARK: - Karşılama / Giriş (Onboarding)
// Ekran 08 ile aynı koyu (ink) dil: bakır uygulama işareti, Sora başlık.
// İki yol: "Yönetici Olarak Giriş Yap" veya "Davet Kodu ile Projeye Katıl".

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showJoin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 84)

            AppMark()

            Text("İnşaat Takip")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 26)

            Text("Ada / parsel bazlı malzeme ve satış takibi. Sahadaki her hareket, ortaklarla şeffaf biçimde paylaşılır.")
                .font(.manrope(14.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(4)
                .padding(.top, 12)

            Spacer()

            // Yönetici girişi — veri girme yetkisi olan tek rol.
            Button {
                appState.signInAsAdmin()
            } label: {
                Text("Yönetici Olarak Giriş Yap")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.accent)
                    .cornerRadius(14)
            }

            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                Text("veya")
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(.white.opacity(0.4))
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            }
            .padding(.vertical, 18)

            // Ortak katılımı — salt okunur erişim.
            Button {
                showJoin = true
            } label: {
                Text("Davet Kodu ile Projeye Katıl")
                    .font(.manrope(14.5, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.22), lineWidth: 1))
            }

            Text("Ortaklar verileri yalnızca görüntüleyebilir.")
                .font(.manrope(11, .medium))
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink.ignoresSafeArea())
        .fullScreenCover(isPresented: $showJoin) {
            JoinWithCodeView()
        }
        .onAppear {
            // DEBUG: "-screen join" ile kod ekranını doğrudan aç
            if LaunchConfig.screen == "join" { showJoin = true }
        }
    }
}

/// 52px bakır uygulama işareti — beyaz "kart" glifi.
struct AppMark: View {
    var size: CGFloat = 52

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.31)
            .fill(Palette.accent)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5)
                    .stroke(Color.white, lineWidth: 2.5)
                    .frame(width: size * 0.44, height: size * 0.36)
                    .overlay(
                        Rectangle()
                            .fill(Color.white)
                            .frame(height: 2.5)
                            .offset(y: -size * 0.055)
                    )
            )
    }
}
