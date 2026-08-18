import SwiftUI

// MARK: - İsim Adımı (yalnızca ilk girişte)
// Telefon doğrulaması numarayı kanıtlar ama isim VERMEZ. Bu ad ortak
// listesinde, hareket akışında ("X projeye katıldı") ve denetim defterinde
// görünüyor — numarayla bırakılsaydı ortak tablosu telefon numaralarından
// oluşurdu ve şeffaflık iddiası okunamaz hale gelirdi.

struct NameStepView: View {
    @EnvironmentObject private var appState: AppState

    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 72)

            AppMark()

            Text("Adın ne?")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 24)

            Text("Ortakların seni bu adla görecek. Sonradan değiştirebilirsin.")
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(4)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text("AD SOYAD")
                    .smallCapsLabel(size: 10, color: .white.opacity(0.45), tracking: 1.0)
                TextField("", text: $name, prompt: Text("Örn. Mehmet Kılıç")
                    .foregroundColor(.white.opacity(0.3)))
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .font(.sora(18, .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .cornerRadius(14)
            }
            .padding(.top, 28)

            Button {
                appState.finishNameStep(name: trimmed)
            } label: {
                Text("Devam")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.accent.opacity(trimmed.isEmpty ? 0.4 : 1))
                    .cornerRadius(14)
            }
            .disabled(trimmed.isEmpty)
            .padding(.top, 22)

            // ÇIKIŞ YOLU. Bu ekranda daha önce ne geri ne çıkış vardı ve buraya
            // düşen kullanıcı KİLİTLİ kalıyordu: telefon doğrulaması bitmiş
            // (yani oturum açık) ama profil yok, dolayısıyla uygulama her
            // açılışta buraya dönüyor. Yanlış numarayla giren biri geri
            // dönemiyordu.
            //
            // Uygulamayı silmek de kurtarmıyor — Firebase oturumu KEYCHAIN'de
            // duruyor ve keychain uygulama silinince temizlenmiyor. Gerçek
            // cihazda birebir bu yaşandı: uygulama kaldırılıp yeniden kuruldu,
            // eski oturum geri geldi ve ekran yine burası oldu.
            Button {
                appState.signOut()
            } label: {
                Text("Farklı numarayla giriş yap")
                    .font(.manrope(13.5, .semiBold))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ink.ignoresSafeArea())
        .onAppear { focused = true }
    }
}
