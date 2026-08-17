import SwiftUI

// MARK: - Telefon ile Giriş
// Karşılama ekranından açılır. İki aşama tek ekranda: numara → SMS kodu.
// Ayrı ekran yerine tek ekran, çünkü kullanıcı numarasını yanlış yazdığında
// geri gidip düzeltmesi tek dokunuş olmalı (SMS beklerken en sık yapılan şey).

struct PhoneSignInView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Stage: Equatable {
        case phone
        case code(VerificationRequest)
    }

    @State private var stage: Stage = .phone
    @State private var phoneText = ""
    @State private var codeText = ""
    @State private var isBusy = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                DarkHeaderButton(systemName: "xmark") { dismiss() }
            }
            .padding(.top, 6)

            AppMark()
                .padding(.top, 24)

            Text(stage == .phone ? "Telefonla giriş" : "Kodu gir")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                .padding(.top, 22)

            Text(subtitle)
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            switch stage {
            case .phone: phoneField
            case .code:  codeField
            }

            if let errorText {
                Text(errorText)
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.alertTint)
                    .padding(.top, 12)
            }

            primaryButton
                .padding(.top, 20)

            if case .code(let request) = stage {
                Button {
                    // Numarayı düzeltmek için geri: en sık ihtiyaç duyulan yol.
                    stage = .phone
                    codeText = ""
                    errorText = nil
                    phoneText = PhoneFormat.pretty(request.phone)
                } label: {
                    Text("Numarayı değiştir")
                        .font(.manrope(13.5, .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }

            Spacer()

            Text("Girişte SMS ile tek kullanımlık kod gönderilir. Numaran yalnızca kimlik doğrulama ve ortak davetleri için kullanılır.")
                .font(.manrope(11.5, .medium))
                .foregroundColor(.white.opacity(0.35))
                .lineSpacing(3)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ink.ignoresSafeArea())
        .toastOverlay(viewModel.toast)
        .onAppear { focused = true }
    }

    private var subtitle: String {
        switch stage {
        case .phone:
            return "Numaranı gir, sana tek kullanımlık bir kod göndereceğiz."
        case .code(let request):
            return "\(PhoneFormat.pretty(request.phone)) numarasına gönderilen 6 haneli kodu gir."
        }
    }

    // MARK: Alanlar

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TELEFON")
                .smallCapsLabel(size: 10, color: .white.opacity(0.45), tracking: 1.0)
            TextField("", text: $phoneText, prompt: Text("0555 123 45 67")
                .foregroundColor(.white.opacity(0.3)))
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
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
        .padding(.top, 26)
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DOĞRULAMA KODU")
                .smallCapsLabel(size: 10, color: .white.opacity(0.45), tracking: 1.0)
            TextField("", text: $codeText, prompt: Text("123456")
                .foregroundColor(.white.opacity(0.3)))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)   // iOS klavyeden kodu önerir
                .focused($focused)
                .font(.sora(22, .bold))
                .tracking(6)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1))
                .cornerRadius(14)
                .onChange(of: codeText) { value in
                    // 6 hane girilince kendiliğinden doğrula — kullanıcı ayrıca
                    // butona basmasın; SMS otomatik doldurulduğunda da çalışır.
                    if value.filter(\.isNumber).count == 6 { submit() }
                }
        }
        .padding(.top, 26)
    }

    private var primaryButton: some View {
        Button(action: submit) {
            HStack(spacing: 9) {
                if isBusy { ProgressView().tint(.white) }
                Text(isBusy ? "Gönderiliyor…" : (stage == .phone ? "Kod Gönder" : "Giriş Yap"))
                    .font(.manrope(15, .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Palette.accent.opacity(isBusy ? 0.6 : 1))
            .cornerRadius(14)
        }
        .disabled(isBusy)
    }

    // MARK: Aksiyon

    private func submit() {
        guard !isBusy else { return }
        errorText = nil
        isBusy = true

        Task {
            defer { isBusy = false }
            do {
                switch stage {
                case .phone:
                    let request = try await appState.auth.sendCode(to: phoneText)
                    stage = .code(request)
                    codeText = ""
                    focused = true

                case .code(let request):
                    let session = try await appState.auth.verify(code: codeText, for: request)
                    // İsmin nerede saklandığını bu ekran bilmez: `AppState`
                    // profili çözer, bulamazsa isim ekranını açar.
                    await appState.completeSignIn(session)
                    dismiss()
                }
            } catch let error as AuthError {
                errorText = error.errorDescription
                if case .invalidCode = error { codeText = "" }
            } catch {
                errorText = AuthError.unknown("").errorDescription
            }
        }
    }
}
