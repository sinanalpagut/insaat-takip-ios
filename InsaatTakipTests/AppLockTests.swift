import XCTest
import LocalAuthentication
@testable import InsaatTakip

/// Uygulama kilidi ve gizlilik örtüsü — madde 78.
///
/// NEDEN BU TESTLER VAR: kilit bir DURUM MAKİNESİ ve sessizce yanlış
/// davranabilir. "Kilitli görünüyor ama değil" ya da "kapalı ayara rağmen
/// kilitli kaldı" hatalarının ikisi de ekranda fark edilmez — biri korumayı
/// yok eder, öteki kullanıcıyı kendi verisinden dışarıda bırakır.
@MainActor
final class AppLockTests: XCTestCase {

    /// Cihaz doğrulamasını taklit eder.
    private final class FakeContext: LAContext {
        var yapabilir: Bool
        var sonuc: Bool
        init(yapabilir: Bool = true, sonuc: Bool = true) {
            self.yapabilir = yapabilir
            self.sonuc = sonuc
            super.init()
        }
        override func canEvaluatePolicy(_ policy: LAPolicy,
                                        error: NSErrorPointer) -> Bool { yapabilir }
        override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String,
                                     reply: @escaping (Bool, Error?) -> Void) {
            reply(sonuc, sonuc ? nil : NSError(domain: LAErrorDomain,
                                               code: LAError.userCancel.rawValue))
        }
    }

    private func kur(enabled: Bool = false,
                     yapabilir: Bool = true, sonuc: Bool = true) -> AppLock {
        let d = UserDefaults(suiteName: "applock-test-\(UUID().uuidString)")!
        let lock = AppLock(defaults: d, context: {
            FakeContext(yapabilir: yapabilir, sonuc: sonuc)
        })
        lock.isEnabled = enabled
        return lock
    }

    /// AYAR KAPALIYKEN HİÇBİR ŞEY OLMAZ.
    ///
    /// Varsayılan kapalı: her açılışta yüz taraması istemek şantiyede
    /// eldivenle çalışan kullanıcı için ürünü kullanılmaz yapardı.
    func testDisabledNeverLocks() {
        let lock = kur(enabled: false)
        lock.applicationWillResignActive()
        lock.applicationDidEnterBackground()
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isCovered)
    }

    /// ARKA PLANA GEÇİŞ KİLİTLER.
    func testBackgroundLocksWhenEnabled() {
        let lock = kur(enabled: true)
        lock.applicationDidEnterBackground()
        XCTAssertTrue(lock.isLocked)
    }

    /// `.inactive` ÖRTER AMA KİLİTLEMEZ — maddenin en ince kararı.
    ///
    /// Fiş fotoğrafı çekmek ve galeriden seçmek sahneyi `.inactive` yapıyor
    /// ama `.background` yapmıyor. Kilit `.inactive`e bağlansaydı uygulamanın
    /// EN ÇOK kullanılan eyleminde her seferinde yüz taraması istenirdi.
    func testResignActiveCoversButDoesNotLock() {
        let lock = kur(enabled: true)
        lock.applicationWillResignActive()
        XCTAssertTrue(lock.isCovered, "uygulama değiştirici görüntüsü örtülmeli")
        XCTAssertFalse(lock.isLocked, "fiş çekmek kilit istememelİ")
    }

    /// Etkinleşince örtü kalkar; kilit varsa DURUR.
    func testBecomingActiveLiftsCoverButKeepsLock() {
        let lock = kur(enabled: true)
        lock.applicationDidEnterBackground()
        lock.applicationWillResignActive()
        lock.applicationDidBecomeActive()
        XCTAssertFalse(lock.isCovered)
        XCTAssertTrue(lock.isLocked, "kilit yalnızca doğrulamayla açılmalı")
    }

    /// DOĞRULAMA BAŞARILI → kilit açılır.
    func testSuccessfulAuthenticationUnlocks() async {
        let lock = kur(enabled: true, sonuc: true)
        lock.applicationDidEnterBackground()
        let ok = await lock.unlock()
        XCTAssertTrue(ok)
        XCTAssertFalse(lock.isLocked)
    }

    /// DOĞRULAMA REDDEDİLDİ → kilit KAPALI kalır.
    ///
    /// Vazgeçen kullanıcı içeri girmemeli; ekranda "Tekrar dene" duruyor.
    func testFailedAuthenticationKeepsLock() async {
        let lock = kur(enabled: true, sonuc: false)
        lock.applicationDidEnterBackground()
        let ok = await lock.unlock()
        XCTAssertFalse(ok)
        XCTAssertTrue(lock.isLocked)
    }

    /// CİHAZDA EKRAN KİLİDİ YOKSA KİLİT AÇILIR (fail-open).
    ///
    /// Görünüşte yanlış, tersi daha kötü: parolasız cihazda kilidi zorlamak
    /// uygulamayı KALICI olarak erişilemez yapardı — üstelik hiçbir şey
    /// kazandırmadan, çünkü telefonu eline alan zaten içeride.
    func testFailsOpenWhenDeviceCannotAuthenticate() async {
        let lock = kur(enabled: true, yapabilir: false)
        lock.applicationDidEnterBackground()
        XCTAssertTrue(lock.isLocked)
        let ok = await lock.unlock()
        XCTAssertTrue(ok, "kullanıcı kendi verisinden dışarıda kalmamalı")
        XCTAssertFalse(lock.isLocked)
    }

    /// Doğrulama yapılamayan cihazda AYAR AÇILAMAZ.
    func testSettingIsUnavailableWithoutDeviceAuth() {
        XCTAssertFalse(kur(yapabilir: false).canAuthenticate)
        XCTAssertTrue(kur(yapabilir: true).canAuthenticate)
    }

    /// AYARI KAPATMAK KİLİDİ DE DÜŞÜRÜR.
    ///
    /// Düşürmeseydi kullanıcı, kapattığı bir kilidin arkasında kalırdı.
    func testDisablingReleasesAnExistingLock() {
        let lock = kur(enabled: true)
        lock.applicationDidEnterBackground()
        lock.applicationWillResignActive()
        XCTAssertTrue(lock.isLocked)

        lock.isEnabled = false
        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isCovered)
    }

    /// Ayar cihazda KALICI — uygulama kapanınca kilit kaybolmamalı.
    func testSettingPersists() {
        let ad = "applock-persist-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: ad)!
        let ilk = AppLock(defaults: d, context: { FakeContext() })
        ilk.isEnabled = true

        let ikinci = AppLock(defaults: d, context: { FakeContext() })
        XCTAssertTrue(ikinci.isEnabled, "ayar açılışlar arasında korunmalı")
    }
}
