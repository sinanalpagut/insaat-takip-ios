import FirebaseFunctions

// MARK: - Hesap silme (madde 28) — App Store 5.1.1(v)
//
// Sunucu tarafını `deleteAccount` Cloud Function'ı yapıyor; gerekçesi
// functions/src/index.ts içinde yazılı (beş bağımsız sebep: kural istemciye
// proje/profil silmeyi kapatıyor, ortak kendi üyeliğini çıkaramıyor, alt
// koleksiyonlar otomatik silinmiyor, Storage istemciden listelenemiyor ve Auth
// kaydı en son silinmeli).
//
// Bu tip yalnızca çağrıyı ve hatayı taşıyor — `FirebaseInviteService` ile aynı
// desen.

struct AccountDeletionSummary {
    /// Silinen (sahibi olunan) proje sayısı.
    let deletedProjects: Int
    /// Ortak olarak ayrılınan proje sayısı — verisi DURUYOR.
    let leftProjects: Int
}

@MainActor
protocol AccountDeletionService {
    func deleteServerData() async throws -> AccountDeletionSummary
}

@MainActor
final class FirebaseAccountDeletionService: AccountDeletionService {

    private let functions: Functions

    init(functions: Functions = Functions.functions(region: FirebaseInviteService.region)) {
        self.functions = functions
    }

    /// İstemci beklemesi SUNUCUDAN UZUN olmak zorunda.
    ///
    /// Callable'ın istemci tarafındaki varsayılan sınırı 70 saniye, sunucu
    /// tarafındaki sınır ise 540 saniyeye çıkarıldı. Varsayılan bırakılsaydı
    /// uzun bir silmede istemci 70. saniyede pes eder, kullanıcıya "Hesap
    /// silinemedi" derdi — oysa sunucu silmeye DEVAM ediyor ve birkaç saniye
    /// sonra bitiriyor. Kullanıcıya söylenen şeyin tersi oluyor: hesabı
    /// silindiği hâlde silinmedi sanıyor, tekrar girmeyi deniyor ve giremiyor.
    ///
    /// Bekleme süresi sunucununkinden UZUN: kimin pes edeceğine sunucu karar
    /// versin ki istemci gerçek sonucu görebilsin.
    func deleteServerData() async throws -> AccountDeletionSummary {
        let callable = functions.httpsCallable("deleteAccount")
        callable.timeoutInterval = 600
        let response = try await callable.call([:])
        let data = response.data as? [String: Any] ?? [:]
        return AccountDeletionSummary(
            deletedProjects: data["deletedProjects"] as? Int ?? 0,
            leftProjects: data["leftProjects"] as? Int ?? 0)
    }
}

/// Simülatör/demo yolu. Sunucu yok; akış ekranda denenebilsin diye başarıyı
/// taklit ediyor.
///
/// Sahte servis olmasaydı silme akışı YALNIZCA gerçek cihazda denenebilirdi ve
/// ekran doğrulaması her seferinde telefon gerektirirdi.
@MainActor
final class FakeAccountDeletionService: AccountDeletionService {
    func deleteServerData() async throws -> AccountDeletionSummary {
        AccountDeletionSummary(deletedProjects: 0, leftProjects: 0)
    }
}
