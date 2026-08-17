import SwiftUI

// MARK: - Karşılama / Giriş (Onboarding)
// Ekran 08 ile aynı koyu (ink) dil: bakır uygulama işareti, Sora başlık.
// İki yol: "Yönetici Olarak Giriş Yap" veya "Davet Kodu ile Projeye Katıl".

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showJoin = false
    @State private var showPhoneSignIn = false

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

            // Telefon + SMS girişi. "Yönetici olarak gir" düğmesi kaldırıldı:
            // rol artık seçilmiyor, kimlik doğrulanıyor. Kendi projesini kuran
            // kişi zaten o projenin yöneticisi (Project.ownerUid).
            Button {
                showPhoneSignIn = true
            } label: {
                Text("Telefonla Giriş Yap")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.accent)
                    .cornerRadius(14)
            }

            // Davet girişi buradan KALDIRILDI: projeye katılmak için önce
            // kimlik gerekiyor (memberUids'e yazılacak bir uid olmalı). Ortak da
            // aynı telefon girişinden geçiyor, koda dashboard'dan ulaşıyor.
            Text("Ortak olarak davet edildiysen de telefonunla giriş yap; davet kodunu girişten sonra kullanacaksın.")
                .font(.manrope(11, .medium))
                .foregroundColor(.white.opacity(0.35))
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink.ignoresSafeArea())
        .fullScreenCover(isPresented: $showJoin) {
            JoinWithCodeView()
        }
        .fullScreenCover(isPresented: $showPhoneSignIn) {
            PhoneSignInView()
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
