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
            // `createdAt` SUNUCU DAMGASI, cihaz saati DEĞİL. Kural artık
            // `createdAt == request.time` istiyor ve `expiresAt`i sunucu
            // saatinden 49 saatle sınırlıyor: daha önce kodun ömrünü cihaz
            // saati belirliyordu ve saati ileri alınmış bir cihaz 48 saatlik
            // kodu yıllarca geçerli yapabilirdi (`redeemInvite` süreyi
            // belgedeki `expiresAt`e bakarak ölçüyor).
            batch.setData([
                "projectId": pid,
                "createdAt": FieldValue.serverTimestamp(),
                "expiresAt": Timestamp(date: expiresAt),
                "usedAt": NSNull(),
            ], forDocument: db.collection("invites").document(code))

            // Yöneticinin ekranda göreceği ayna. Otorite `invites/{KOD}`;
            // buradaki kopya yalnızca gösterim, çünkü kod okuma kapalı.
            // AYNADA CİHAZ SAATİ KALIYOR ve bu bilinçli: bu kopya yalnızca
            // yöneticinin ekranında "kod ne zaman üretildi" yazmak için var,
            // otorite `invites/{KOD}`. Buraya da sunucu damgası konsaydı,
            // damganın iç içe bir map alanında (`invite.createdAt`) yaşaması
            // gerekirdi ve proje belgesinin kuralı damgayı denetlemiyor —
            // yani kanıt değeri olmayan bir yerde kanıt görüntüsü olurdu.
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

    private static func mapped(_ error: Error) -> InviteError {
        InviteError.from(error)
    }
}

extension InviteError {
    /// Callable hatasını uygulamanın Türkçe hatasına çevirir.
    ///
    /// İşlev, `HttpsError`in mesaj alanında sabit bir anahtar döndürüyor
    /// (`code-used`, `code-expired`…). Firebase bunu `NSLocalizedDescription`
    /// olarak taşıyor.
    ///
    /// SINIFIN DIŞINDA olmasının sebebi test: `FirebaseInviteService`
    /// `@MainActor` ve bu dönüşüm onun içinde `private` kaldıkça birim
    /// testten çağrılamıyordu. `AccountDeletionError.from(_:)` ile aynı yer,
    /// aynı sebep.
    static func from(_ error: Error) -> InviteError {
        let ns = error as NSError
        #if DEBUG
        print("[invite] \(ns.domain) code=\(ns.code) · \(ns.localizedDescription)")
        #endif

        if ns.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: ns.code) {
            // Mesajdaki anahtar birincil kaynak; kod ikincil yedek.
            let mappedByMessage = InviteError.fromFunctionCode(ns.localizedDescription)
            if mappedByMessage != .unknown { return mappedByMessage }

            // YEDEK DAL KOD HAKKINDA HÜKÜM VERMEZ.
            //
            // Buraya yalnızca anahtar taşımayan hatalar düşüyor ve anahtarı
            // üreten tek yer işlev GÖVDESİ. Çerçeve oturum ve App Check
            // kapılarını gövdeden ÖNCE denetliyor; SDK zaman aşımını ve 404'ü
            // kendi metniyle üretiyor. Yani bu dala gelen her çağrıda sunucu
            // kodu OKUMADI. Eskiden üç dal okumuş gibi cevap veriyordu:
            // `.unauthenticated → .notSignedIn` (ekranda "kod yok"),
            // `.deadlineExceeded → .expired` ("süresi doldu"), ve `.notFound`
            // — ki 404 burada "işlev yok / bölge yanlış" demek, bu dosyanın
            // başındaki yorum tam bu tuzağı yazıyor.
            //
            // `.resourceExhausted` BURADA YOK ve bilerek: sunucunun gerçek
            // oran sınırı HER ZAMAN `too-many-attempts` anahtarıyla geliyor ve
            // yukarıda yakalanıyor. Anahtarsız 429 ise Cloud Run'ın örnek
            // sınırından (`maxInstances`) geliyor; onu "çok fazla deneme"
            // saymak hiç denemeyen kişiyi suçlamak olurdu.
            switch code {
            case .unauthenticated:  return .requestRejected
            case .deadlineExceeded: return .timedOut
            case .unavailable:      return .network
            default:                return .unknown
            }
        }
        if ns.domain == NSURLErrorDomain { return .network }
        // SDK çağrıdan ÖNCE Auth ID jetonunu tazeliyor; önbellekteki jeton
        // eskimişken ağ yoksa hata Auth alanından geliyor (17020 =
        // `networkError`). Bağlantı sorunu, "katılınamadı" değil.
        if ns.domain == "FIRAuthErrorDomain", ns.code == 17020 { return .network }
        return .unknown
    }
}
