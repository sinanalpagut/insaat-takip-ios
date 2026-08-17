import SwiftUI

// MARK: - Kod ile Katıl (Ekran 08)
// Tam ekran ink zemin. 6 haneli kod kutuları, bakır CTA, "veya" ayracı,
// davet bağlantısı yapıştırma ve 48 saat / tek kullanım dipnotu.

struct JoinWithCodeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    /// Girilen ham kod (en çok 6 karakter, harf/rakam).
    @State private var code = ""
    @FocusState private var fieldFocused: Bool
    @State private var showInvalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Kapat butonu (tam ekran sunumda geri dönüş)
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(11)
                }
            }
            .padding(.top, 8)

            AppMark()
                .padding(.top, 26)

            Text("Projeye katıl")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 26)

            Text("Yöneticiden aldığın 6 haneli kodu gir. Katıldığında verileri yalnızca görüntüleyebilirsin.")
                .font(.manrope(14.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(4)
                .padding(.top, 12)

            // 6 haneli kod kutuları — gizli TextField üzerine çizilir.
            codeBoxes
                .padding(.top, 30)

            // CTA
            Button {
                submit()
            } label: {
                Text("Projeye Katıl")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(code.count == 6 ? Palette.accent : Palette.accent.opacity(0.5))
                    .cornerRadius(14)
            }
            .padding(.top, 24)

            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                Text("veya")
                    .font(.manrope(11.5, .semiBold))
                    .foregroundColor(.white.opacity(0.4))
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            }
            .padding(.vertical, 18)

            // Panodaki davet bağlantısından kodu çeker.
            Button {
                pasteLink()
            } label: {
                Text("Davet bağlantısını yapıştır")
                    .font(.manrope(14.5, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.22), lineWidth: 1))
            }

            Spacer()

            Text("Kodlar 48 saat geçerlidir ve tek kişilik kullanım içindir.")
                .font(.manrope(11, .medium))
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 26)
        .background(Palette.ink.ignoresSafeArea())
        .toastOverlay(viewModel.toast)
        .onAppear { fieldFocused = true }
    }

    // MARK: Kod kutuları

    private var codeBoxes: some View {
        ZStack {
            // Görünmez giriş alanı: klavye ve otomatik büyük harf yönetimi.
            TextField("", text: Binding(
                get: { code },
                set: { code = InviteCode.sanitize($0) }
            ))
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .focused($fieldFocused)
            .foregroundColor(.clear)
            .tint(.clear)
            .frame(height: 58)

            HStack(spacing: 9) {
                ForEach(0..<6, id: \.self) { index in
                    let char = character(at: index)
                    Text(char.map(String.init) ?? "")
                        .font(.sora(24, .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(index == code.count && fieldFocused
                                        ? Palette.accent
                                        : Color.white.opacity(showInvalid ? 0.5 : 0.18),
                                        lineWidth: 1.5)
                        )
                        .cornerRadius(13)
                }
            }
            .allowsHitTesting(false)   // Dokunuşlar alttaki TextField'a gitsin
        }
        .onTapGesture { fieldFocused = true }
    }

    private func character(at index: Int) -> Character? {
        guard index < code.count else { return nil }
        return Array(code)[index]
    }

    // MARK: Aksiyonlar

    private func submit() {
        guard InviteCode.sanitize(code).count == 6 else {
            showInvalid = true
            viewModel.flash("Kod 6 haneli olmalı")
            return
        }

        // Kod artık gerçek bir projeyle eşleşiyor; süresi ve tek kullanım kuralı denetleniyor.
        // Kullanıcı ARTIK oturum açmış olmak zorunda: davet, kimliği bilinen bir
        // kişiyi projeye ekliyor. Giriş öncesi katılma yolu kaldırıldı çünkü
        // `memberUids`'e yazılacak bir uid olmadan üyelik kurulamaz.
        guard let user = appState.currentUser else {
            viewModel.flash("Önce telefonla giriş yap")
            return
        }
        switch viewModel.redeemInvite(code: code, user: user) {
        case .success(let projectTitle):
            dismiss()
            viewModel.flash("\(projectTitle) · salt okunur erişim")
        case .notFound:
            showInvalid = true
            viewModel.flash("Böyle bir davet kodu yok")
        case .expired:
            showInvalid = true
            viewModel.flash("Kodun süresi dolmuş · yöneticiden yeni kod iste")
        case .alreadyUsed:
            showInvalid = true
            viewModel.flash("Bu kod daha önce kullanılmış")
        case .alreadyMember:
            dismiss()
            viewModel.flash("Bu projenin zaten ortağısın")
        }
    }

    /// Panodaki "insaattakip.app/katil/X7B-9Q2" benzeri bağlantıdan kodu ayıklar.
    private func pasteLink() {
        guard let text = UIPasteboard.general.string else {
            viewModel.flash("Panoda bağlantı yok")
            return
        }
        let tail = text.split(separator: "/").last.map(String.init) ?? text
        let sanitized = InviteCode.sanitize(tail)
        if sanitized.count == 6 {
            code = sanitized
            submit()
        } else {
            viewModel.flash("Bağlantı çözümlenemedi")
        }
    }
}
