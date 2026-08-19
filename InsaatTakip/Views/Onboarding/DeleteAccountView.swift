import SwiftUI

// MARK: - Hesap Silme (madde 28) — App Store 5.1.1(v)
//
// İKİ AŞAMALI ve ikinci aşama zorunlu: Firebase hassas işlemler için yakın
// oturum istiyor (`requiresRecentLogin`, 17014), yani silmeden önce yeni bir
// SMS turu dönmek zorunda.
//
// GÜVENLİK — bu ekran `AuthService.verify` KULLANMAZ. `verify` içeride
// `signIn(with:)` çağırıyor; kullanıcı başka bir numara girerse oturum
// sessizce o hesaba geçer ve ardından gelen silme YANLIŞ HESABI silerdi.
// Burada `reauthenticate` kullanılıyor ve numaranın oturumdakiyle aynı olduğu
// ayrıca denetleniyor.
//
// ONAY EKRANI NE KAYBEDİLECEĞİNİ RAKAMLA SÖYLÜYOR. "Bu işlem geri alınamaz"
// tek başına bilgi taşımıyor; müteahhidin kaç projesi, kaç dairesi ve kaç
// ortağının erişimi gittiğini görmesi gerekiyor.

struct DeleteAccountView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Step { case confirm, code, done }

    @State private var step: Step = .confirm
    @State private var request: VerificationRequest?
    @State private var code = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var summary: AccountDeletionSummary?

    /// Silinecek olanın büyüklüğü — kullanıcının kendi verisi üzerinden.
    private var owned: [Project] {
        guard let user = appState.currentUser else { return [] }
        return viewModel.projects.filter { $0.role(for: user) == .admin }
    }

    private var partnerCount: Int {
        owned.reduce(0) { total, project in
            // Sahibin kendisi de bir Partner kaydı; erişimini kaybedecek olan
            // DİĞERLERİ sayılıyor.
            total + viewModel.partners(for: project.id).filter { $0.userUid != appState.currentUser?.id }.count
        }
    }

    private var apartmentCount: Int {
        owned.reduce(0) { $0 + viewModel.apartments(for: $1.id).count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            switch step {
            case .confirm: confirmStep
            case .code:    codeStep
            case .done:    doneStep
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ink.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Spacer()
            if step != .done {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .iconFont(14, weight: .semibold)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: 1 — Onay

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hesabını sil")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text(impactText)
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text("Bu işlem geri alınamaz.")
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.accentLight)
                .padding(.top, 14)

            if let errorText {
                Text(errorText)
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.accentLight)
                    .padding(.top, 12)
            }

            Button {
                Task { await sendCode() }
            } label: {
                Text(busy ? "Kod gönderiliyor…" : "Devam et")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.alertInk.opacity(busy ? 0.5 : 1))
                    .cornerRadius(14)
            }
            .disabled(busy)
            .padding(.top, 26)

            Text("Güvenlik için numarana bir kod göndereceğiz.")
                .font(.manrope(11.5, .medium))
                .foregroundColor(.white.opacity(0.62))
                .padding(.top, 12)
        }
    }

    /// Ne kaybedileceği — sayılarla. Ortağı olmayan tek projeli bir kullanıcı
    /// için de doğru okunacak biçimde kuruluyor.
    private var impactText: String {
        var parts: [String] = []
        if owned.isEmpty {
            parts.append("Hesabın ve profil bilgilerin kalıcı olarak silinecek.")
        } else {
            parts.append("Sahibi olduğun \(owned.count) proje ve içindeki \(apartmentCount) dairenin tüm kayıtları — malzeme, gider, tahsilat, fotoğraf ve belgeler — kalıcı olarak silinecek.")
            if partnerCount > 0 {
                parts.append("\(partnerCount) ortak bu projelere erişimini kaybedecek.")
            }
        }
        let memberOnly = viewModel.projects.count - owned.count
        if memberOnly > 0 {
            parts.append("Ortak olduğun \(memberOnly) projeden çıkarılacaksın; o projelerin verisi silinmez.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: 2 — Kod

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Kodu gir")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text("\(PhoneFormat.pretty(request?.phone ?? "")) numarasına gönderilen 6 haneli kodu gir.")
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(4)
                .padding(.top, 12)

            TextField("", text: $code, prompt: Text("123456")
                .foregroundColor(.white.opacity(0.3)))
                .keyboardType(.numberPad)
                .font(.sora(20, .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1))
                .cornerRadius(14)
                .padding(.top, 22)

            if let errorText {
                Text(errorText)
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.accentLight)
                    .padding(.top, 12)
            }

            Button {
                Task { await confirmDelete() }
            } label: {
                Text(busy ? "Siliniyor…" : "Hesabı kalıcı olarak sil")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.alertInk.opacity(code.count < 6 || busy ? 0.5 : 1))
                    .cornerRadius(14)
            }
            .disabled(code.count < 6 || busy)
            .padding(.top, 22)
        }
    }

    // MARK: 3 — Bitti

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hesabın silindi")
                .font(.sora(27, .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            // Ne yapıldığını SAYIYLA söylüyor: "silindi" demek tek başına
            // doğrulanabilir bir bilgi taşımıyor.
            Text(doneText)
                .font(.manrope(14, .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Button { dismiss() } label: {
                Text("Kapat")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Palette.accent)
                    .cornerRadius(14)
            }
            .padding(.top, 26)
        }
    }

    private var doneText: String {
        guard let summary else { return "Hesabın ve verilerin kalıcı olarak silindi." }
        var parts = ["Hesabın ve profil bilgilerin kalıcı olarak silindi."]
        if summary.deletedProjects > 0 {
            parts.append("\(summary.deletedProjects) proje ve tüm kayıtları silindi.")
        }
        if summary.leftProjects > 0 {
            parts.append("\(summary.leftProjects) projeden çıkarıldın.")
        }
        return parts.joined(separator: " ")
    }

    // MARK: Aksiyonlar

    private func sendCode() async {
        // Numara yoksa kullanıcıyı SUÇLAMA. `sendCode("")` "Telefon numarası
        // geçersiz" veriyor ve kullanıcı hiçbir şey yazmadığı için bu mesaj
        // ona yanlış bir şey yaptığını söylüyor — oysa sorun oturumda.
        guard let phone = appState.currentUser?.phone, !phone.isEmpty else {
            errorText = "Oturumunda kayıtlı numara yok · çıkış yapıp tekrar gir"
            return
        }
        busy = true
        errorText = nil
        do {
            request = try await appState.auth.sendCode(to: phone)
            step = .code
        } catch {
            errorText = (error as? AuthError)?.errorDescription ?? "Kod gönderilemedi"
        }
        busy = false
    }

    private func confirmDelete() async {
        guard let request else { return }
        busy = true
        errorText = nil
        do {
            // `verify` DEĞİL `reauthenticate` — gerekçesi dosya başında.
            try await appState.auth.reauthenticate(code: code, for: request)
            // Bitti adımı BURADA gösterilmiyor: `deleteAccount` oturumu
            // düşürüyor ve `RootView` tüm ağacı değiştiriyor, yani bu ekran
            // yok oluyor. Özet karşılama ekranında gösteriliyor
            // (`AppState.lastDeletionSummary`).
            _ = try await appState.deleteAccount()
        } catch {
            errorText = (error as? AuthError)?.errorDescription ?? "Hesap silinemedi"
        }
        busy = false
    }
}
