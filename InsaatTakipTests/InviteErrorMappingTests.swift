import XCTest
import FirebaseFunctions
@testable import InsaatTakip

/// Davet hatalarının sunucudan ekrana çevirisi.
///
/// KÖK İLKE: `InviteError.from(_:)` iki katmanlı. Önce işlevin mesajındaki
/// makine okunur anahtara bakıyor (`code-expired`, `code-used`…); anahtar
/// yoksa koda düşüyor. Anahtar YALNIZCA işlev gövdesi çalıştığında üretiliyor
/// — çerçeve (`firebase-functions` `wrapOnCallHandler`) oturum ve App Check
/// kapılarını gövdeden ÖNCE kontrol ediyor ve reddettiğinde kendi metnini
/// ("Unauthenticated") yazıyor. Yani yedek koda düşen her hata, tanımı gereği
/// "sunucu kodu OKUMADI" demek. O dal kod hakkında hüküm veremez.
///
/// Eskiden veriyordu: `.unauthenticated → .notSignedIn` (sonra sessizce
/// "Böyle bir davet kodu yok") ve `.deadlineExceeded → .expired` ("Kodun
/// süresi doldu · yöneticiden yeni kod iste"). Birincisi App Check arızasında
/// GEÇERLİ HER KODU "yok" gösteriyordu; ikincisi yavaş ağda geçerli kodu
/// "süresi doldu" gösterip yöneticiye gereksiz yere yeni kod ürettiriyordu.
final class InviteErrorMappingTests: XCTestCase {

    private func callable(_ code: FunctionsErrorCode, _ message: String) -> NSError {
        NSError(domain: FunctionsErrorDomain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    // MARK: - Madde 2 — çerçeve reddi kod hakkında hüküm değil

    /// App Check jetonu alınamadığında SDK isteği başlıksız gönderiyor ve
    /// çerçeve `unauthenticated` / "Unauthenticated" ile reddediyor. Kod hiç
    /// okunmadı.
    func testCerceveReddiOturumYokSayilmiyor() {
        let hata = InviteError.from(callable(.unauthenticated, "Unauthenticated"))
        XCTAssertNotEqual(hata, .notSignedIn,
                          "çerçeve reddi 'oturum yok'a çevrildi — sonra 'kod yok' oluyordu")
        XCTAssertNotEqual(hata, .notFound)
    }

    /// İşlevin KENDİ oturum anahtarı ayrı ve doğru eşlenmeye devam etmeli.
    func testGercekOturumYokAnahtariKorunuyor() {
        XCTAssertEqual(InviteError.from(callable(.unauthenticated, "signed-in-required")),
                       .notSignedIn)
    }

    // MARK: - Madde 3 — zaman aşımı süre dolumu değil

    /// SDK istemci zaman aşımını (70 sn) ve sunucu 504'ünü `.deadlineExceeded`
    /// + "DEADLINE EXCEEDED" olarak veriyor.
    func testZamanAsimiSureDolumuSayilmiyor() {
        XCTAssertNotEqual(InviteError.from(callable(.deadlineExceeded, "DEADLINE EXCEEDED")),
                          .expired,
                          "zaman aşımı 'kodun süresi doldu' gösteriliyor")
    }

    /// Gerçek süre dolumu işlevden HER ZAMAN anahtarla geliyor.
    func testGercekSureDolumuKorunuyor() {
        XCTAssertEqual(InviteError.from(callable(.deadlineExceeded, "code-expired")), .expired)
        XCTAssertEqual(InviteError.from(callable(.failedPrecondition, "code-expired")), .expired)
    }

    // MARK: - Aynı ilkenin diğer yedek dalları

    /// 404 = işlev yok / bölge yanlış / ad değişmiş. `FirebaseInviteService`in
    /// kendi yorumu bu tuzağı yazıyor; eşleme tersini yapıp "kod yok" diyordu.
    func testDagitimHatasiKodYokSayilmiyor() {
        XCTAssertNotEqual(InviteError.from(callable(.notFound, "NOT FOUND")), .notFound)
    }

    /// Çerçevenin "Bad Request"i gövdeye girmemiş bir çağrı; biçimi denetleyen
    /// gövdenin `code-format` anahtarı.
    func testCerceveBadRequestBicimHatasiSayilmiyor() {
        XCTAssertNotEqual(InviteError.from(callable(.invalidArgument, "Bad Request")), .badFormat)
        XCTAssertEqual(InviteError.from(callable(.invalidArgument, "code-format")), .badFormat)
    }

    /// Oran sınırı adlandırılmalı: "Projeye katılınamadı" gören kişi beklemesi
    /// gerektiğini öğrenemiyor ve denemeye devam ediyordu.
    func testOranSiniriAdlandiriliyor() {
        XCTAssertNotEqual(InviteError.from(callable(.resourceExhausted, "too-many-attempts")),
                          .unknown)
    }

    /// Gövdenin kod hakkındaki hükümleri değişmemeli.
    func testKodHukumleriKorunuyor() {
        XCTAssertEqual(InviteError.from(callable(.notFound, "code-not-found")), .notFound)
        XCTAssertEqual(InviteError.from(callable(.failedPrecondition, "code-used")), .alreadyUsed)
        XCTAssertEqual(InviteError.from(callable(.failedPrecondition, "invite-broken")), .inviteBroken)
        XCTAssertEqual(InviteError.from(NSError(domain: NSURLErrorDomain,
                                                code: NSURLErrorNotConnectedToInternet)),
                       .network)
    }

    // MARK: - Yeni durumların kendisi

    func testYeniDurumlarDogruYereGidiyor() {
        XCTAssertEqual(InviteError.from(callable(.unauthenticated, "Unauthenticated")), .requestRejected)
        XCTAssertEqual(InviteError.from(callable(.deadlineExceeded, "DEADLINE EXCEEDED")), .timedOut)
        XCTAssertEqual(InviteError.from(callable(.resourceExhausted, "too-many-attempts")), .tooManyAttempts)
        XCTAssertEqual(InviteError.from(callable(.notFound, "NOT FOUND")), .unknown)
    }

    /// İki durum aynı cümleyi taşırsa kişi ikisini aynı arıza sanır.
    /// `AuthError`'ın "Uygulama doğrulaması yapılamadı · bildirim ayarları
    /// eksik" cümlesiyle de çakışmamalı — benzerini burada gören kişi
    /// bildirim ayarlarını kurcalamaya giderdi.
    func testHerDurumunKendiCumlesiVar() {
        let metinler = InviteError.allCases.compactMap(\.errorDescription)
        XCTAssertEqual(metinler.count, InviteError.allCases.count, "metinsiz durum var")
        XCTAssertEqual(Set(metinler).count, metinler.count, "iki durum aynı cümleyi taşıyor")
        let girisMetni = AuthError.appVerificationFailed.errorDescription ?? ""
        for m in metinler {
            XCTAssertFalse(m.localizedCaseInsensitiveContains("uygulama doğrula"),
                           "'\(m)' giriş ekranının '\(girisMetni)' cümlesine benziyor")
        }
    }

    /// Kutuları yalnızca kodun kendisi hakkındaki hükümler kızartır; kod
    /// okunmadıysa açıklama olmadan bırakılmaz.
    func testKodHatasiOlmayanlarinAciklamasiVar() {
        for hata in InviteError.allCases where !hata.isCodeFault {
            XCTAssertNotNil(hata.recoverySuggestion, "\(hata) kalıcı uyarıda boş kalır")
        }
        XCTAssertEqual(Set(InviteError.allCases.filter(\.isCodeFault)),
                       [.badFormat, .notFound, .expired, .alreadyUsed])
    }

    /// "Güncelle" talimatı yok: ilk kullanıcılar için güncellenecek sürüm
    /// olmayabilir ve boşa çıkan adım metnin tamamına güveni bitirir.
    func testGuncelleTalimatiYok() {
        for hata in InviteError.allCases {
            let metin = (hata.recoverySuggestion ?? "") + (hata.errorDescription ?? "")
            XCTAssertFalse(metin.localizedCaseInsensitiveContains("App Store"), "\(hata)")
            XCTAssertFalse(metin.localizedCaseInsensitiveContains("güncelle"), "\(hata)")
        }
    }

    // MARK: - Ekrana kadar

    /// Davet servisi yerine geçen sahte: her çağrıda verilen hatayı fırlatır.
    @MainActor
    private final class FirlatanDavet: InviteService {
        let hata: Error
        init(_ hata: Error) { self.hata = hata }
        func createInvite(projectId: UUID, ownerUid: String) async throws -> String { "" }
        func redeem(code: String) async throws -> InviteRedemption { throw hata }
    }

    /// Asıl belirti: App Check arızasında geçerli kod "yok" gösteriliyordu.
    @MainActor
    func testCerceveReddiEkrandaKodYokOlmuyor() async {
        let hata = InviteError.from(callable(.unauthenticated, "Unauthenticated"))
        let vm = ProjectViewModel(repository: InMemoryProjectRepository(),
                                  invites: FirlatanDavet(hata))
        let sonuc = await vm.joinProject(code: "ABC234",
                                         user: User(id: "uid-ortak", name: "Ortak", role: .partner, phone: "+905550000003"))
        XCTAssertNotEqual(sonuc, .notFound, "geçerli kod 'Böyle bir davet kodu yok' gösterildi")
        XCTAssertNotEqual(sonuc, .expired)
        XCTAssertEqual(sonuc, .failed(.requestRejected))
    }

    @MainActor
    func testZamanAsimiEkrandaSureDoldiOlmuyor() async {
        let hata = InviteError.from(callable(.deadlineExceeded, "DEADLINE EXCEEDED"))
        let vm = ProjectViewModel(repository: InMemoryProjectRepository(),
                                  invites: FirlatanDavet(hata))
        let sonuc = await vm.joinProject(code: "ABC234",
                                         user: User(id: "uid-ortak", name: "Ortak", role: .partner, phone: "+905550000003"))
        XCTAssertNotEqual(sonuc, .expired, "yavaş ağ 'kodun süresi doldu' gösterildi")
        XCTAssertNotEqual(sonuc, .notFound)
        XCTAssertEqual(sonuc, .failed(.timedOut))
    }
}
