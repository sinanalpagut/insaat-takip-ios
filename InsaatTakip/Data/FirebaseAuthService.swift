import Foundation
import FirebaseAuth

// MARK: - Firebase telefon doğrulama
//
// Bu sınıf, `AuthService` protokolünün gerçek uygulaması. Ekranlar protokole
// baktığı için sahte servisle bunun arasında geçiş yapmak tek satır
// (bkz. AppState.makeAuthService).
//
// GEREKSİNİM — gerçek cihazda: APNs anahtarı Firebase konsoluna yüklenmiş
// olmalı. Yüklü değilse Firebase sessiz doğrulamayı yapamaz ve reCAPTCHA web
// akışına düşer; o ekranın metni Google'ın kontrolünde ve Türkçe değil.
// Simülatörde push hiç çalışmadığı için orada sahte servis kullanılıyor.

@MainActor
final class FirebaseAuthService: AuthService {

    func restoredSession() -> AuthSession? {
        guard let user = Auth.auth().currentUser else { return nil }
        // `isNewAccount` burada bilinemez: oturum diskten geri geldiyse hesap
        // zaten var. İsim `users/{uid}` dokümanından okunacak, yoksa isim
        // ekranı açılır — yani bu bayrağın false olması bir varsayım değil,
        // "yeni kayıt akışına gerek yok" demek.
        return AuthSession(uid: user.uid, phone: user.phoneNumber ?? "", isNewAccount: false)
    }

    func sendCode(to phone: String) async throws -> VerificationRequest {
        guard let e164 = PhoneFormat.e164(phone) else { throw AuthError.invalidPhone }
        // Info.plist'te geri çağrı URL şeması YOKSA `verifyPhoneNumber` çöker —
        // hata döndürmez, `fatalError`a bile varamadan `mainBundleUrlTypes` nil
        // olduğu için "unexpectedly found nil" ile düşer. Yani yanlış
        // yapılandırılmış bir derlemede kullanıcı "Kod Gönder"e bastığı anda
        // uygulama kapanıyordu. Önce denetleyip Türkçe hata döndürüyoruz:
        // çökme, hiçbir gerekçeyle kabul edilebilir bir davranış değil.
        guard Self.hasCallbackURLScheme else { throw AuthError.notConfigured }
        do {
            let id = try await PhoneAuthProvider.provider()
                .verifyPhoneNumber(e164, uiDelegate: nil)
            return VerificationRequest(id: id, phone: e164)
        } catch {
            throw Self.mapped(error)
        }
    }

    func verify(code: String, for request: VerificationRequest) async throws -> AuthSession {
        let credential = PhoneAuthProvider.provider()
            .credential(withVerificationID: request.id, verificationCode: code)
        do {
            let result = try await Auth.auth().signIn(with: credential)
            return AuthSession(uid: result.user.uid,
                               phone: result.user.phoneNumber ?? request.phone,
                               isNewAccount: result.additionalUserInfo?.isNewUser ?? false)
        } catch {
            throw Self.mapped(error)
        }
    }

    func signOut() throws {
        do { try Auth.auth().signOut() } catch { throw Self.mapped(error) }
    }

    /// Info.plist'te Firebase'in beklediği geri çağrı şeması tanımlı mı?
    ///
    /// Firebase şemayı `CLIENT_ID`den (ters çevrilmiş) ya da o yoksa
    /// `GOOGLE_APP_ID`den (`app-1-…-ios-…`) türetiyor. Burada türetmeyi
    /// TEKRARLAMIYORUZ — SDK'nın iç kuralı sürüm sürüm değişebilir; yalnızca
    /// böyle görünen bir şemanın kayıtlı olup olmadığına bakıyoruz. Bu, gerçek
    /// çökme nedenini (hiç URL tipi olmaması) kesin olarak yakalıyor.
    private static var hasCallbackURLScheme: Bool {
        guard let types = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]]
        else { return false }
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return schemes.contains {
            $0.hasPrefix("app-1-") || $0.hasPrefix("com.googleusercontent.apps")
        }
    }

    /// Firebase hata kodlarını uygulamanın Türkçe hatalarına çevirir.
    /// Ham `NSError.localizedDescription` arayüze sızarsa kullanıcı İngilizce
    /// bir mesaj görür — uygulamanın tamamı Türkçe olduğu için kabul edilemez.
    private static func mapped(_ error: Error) -> AuthError {
        #if DEBUG
        // Kullanıcıya Türkçe kısa mesaj gidiyor; geliştirici ham hatayı görmeden
        // yanlış eşlemeyi farkedemez. Yalnızca DEBUG.
        let ns = error as NSError
        print("[auth] \(ns.domain) code=\(ns.code) · \(ns.localizedDescription) · \(ns.userInfo)")
        #endif
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidPhoneNumber, .missingPhoneNumber:
            return .invalidPhone
        case .invalidVerificationCode, .missingVerificationCode:
            return .invalidCode
        case .sessionExpired, .invalidVerificationID:
            return .codeExpired
        case .tooManyRequests, .quotaExceeded:
            return .tooManyRequests
        case .networkError:
            return .network
        default:
            return .unknown((error as NSError).domain)
        }
    }
}
