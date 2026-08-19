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

    func deleteServerData() async throws -> AccountDeletionSummary {
        let response = try await functions.httpsCallable("deleteAccount").call([:])
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
