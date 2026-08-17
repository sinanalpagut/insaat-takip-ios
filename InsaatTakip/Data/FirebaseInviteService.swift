import Foundation
import FirebaseFirestore
import FirebaseFunctions

// MARK: - Davet akışının gerçek uygulaması
//
// Üretme Firestore'a doğrudan yazma, kullanma Cloud Function çağrısı.
// Gerekçe `InviteService` protokolünde.

@MainActor
final class FirebaseInviteService: InviteService {

    private let db: Firestore
    private let functions: Functions

    /// Bölge, `functions/src/index.ts`'teki `setGlobalOptions` ile AYNI olmak
    /// ZORUNDA. Farklı olsa çağrı 404 döner ve hata "işlev yok" gibi görünür —
    /// oysa işlev vardır, yalnızca başka bölgededir.
    ///
    /// `nonisolated`: sınıf `@MainActor` olduğu için statik üyeleri de aktöre
    /// bağlı sayılıyor, ama bu sabit varsayılan argümanda ve `AppDelegate`in
    /// emülatör kurulumunda izole olmayan bağlamdan okunuyor. Swift 6'da bu
    /// uyarı hataya dönüşüyor.
    nonisolated static let region = "europe-west1"

    init(db: Firestore = Firestore.firestore(),
         functions: Functions = Functions.functions(region: FirebaseInviteService.region)) {
        self.db = db
        self.functions = functions
    }

    // MARK: Üretme

    func createInvite(projectId: UUID, ownerUid: String) async throws -> String {
        let pid = projectId.uuidString
        let createdAt = Date()
        let expiresAt = createdAt.addingTimeInterval(TimeInterval(Invite.validHours * 3600))

        // Kod çakışması: kural `create`'i yalnızca belge YOKKEN kabul ediyor,
        // yani var olan bir kodun üzerine yazmak reddedilir. 31 karakterlik
        // alfabede 6 hane ~887 milyon olasılık; çakışma pratikte görülmez ama
        // görüldüğünde sessizce başkasının davetini çalmak yerine yeni kod
        // denenir. Üç deneme fazlasıyla yeterli.
        var lastError: Error?
        for _ in 0..<3 {
            let code = InviteCode.generate()
            let batch = db.batch()
            batch.setData([
                "projectId": pid,
                "createdAt": Timestamp(date: createdAt),
                "expiresAt": Timestamp(date: expiresAt),
                "usedAt": NSNull(),
            ], forDocument: db.collection("invites").document(code))

            // Yöneticinin ekranda göreceği ayna. Otorite `invites/{KOD}`;
            // buradaki kopya yalnızca gösterim, çünkü kod okuma kapalı.
            batch.updateData([
                "invite": [
                    "code": code,
                    "createdAt": Timestamp(date: createdAt),
                ],
            ], forDocument: db.collection("projects").document(pid))

            do {
                try await batch.commit()
                return code
            } catch {
                lastError = error
            }
        }
        throw lastError ?? InviteError.unknown
    }

    // MARK: Kullanma

    func redeem(code: String) async throws -> InviteRedemption {
        do {
            let response = try await functions.httpsCallable("redeemInvite")
                .call(["code": code])
            guard let data = response.data as? [String: Any],
                  let projectIdString = data["projectId"] as? String,
                  let projectId = UUID(uuidString: projectIdString),
                  let title = data["projectTitle"] as? String
            else {
                throw InviteError.unknown
            }
            return InviteRedemption(projectId: projectId,
                                    projectTitle: title,
                                    alreadyMember: data["alreadyMember"] as? Bool ?? false)
        } catch let error as InviteError {
            throw error
        } catch {
            throw Self.mapped(error)
        }
    }

    /// Callable hatasını uygulamanın Türkçe hatasına çevirir.
    ///
    /// İşlev, `HttpsError`in mesaj alanında sabit bir anahtar döndürüyor
    /// (`code-used`, `code-expired`…). Firebase bunu `NSLocalizedDescription`
    /// olarak taşıyor.
    private static func mapped(_ error: Error) -> InviteError {
        let ns = error as NSError
        #if DEBUG
        print("[invite] \(ns.domain) code=\(ns.code) · \(ns.localizedDescription)")
        #endif

        if ns.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: ns.code) {
            // Mesajdaki anahtar birincil kaynak; kod ikincil yedek.
            let mappedByMessage = InviteError.fromFunctionCode(ns.localizedDescription)
            if mappedByMessage != .unknown { return mappedByMessage }

            switch code {
            case .unauthenticated:    return .notSignedIn
            case .invalidArgument:    return .badFormat
            case .notFound:           return .notFound
            case .deadlineExceeded:   return .expired
            case .alreadyExists:      return .alreadyUsed
            case .failedPrecondition: return .inviteBroken
            case .unavailable:        return .network
            default:                  return .unknown
            }
        }
        if ns.domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}
