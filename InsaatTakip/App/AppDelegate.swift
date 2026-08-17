import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import UIKit

// MARK: - App delegate (yalnızca Firebase telefon doğrulaması için)
//
// SwiftUI uygulamasında app delegate'e gerek yok — BİR İSTİSNA dışında:
// Firebase telefon doğrulaması uygulamanın gerçekliğini sessiz bir push
// bildirimiyle kanıtlıyor ve o bildirimin FirebaseAuth'a İLETİLMESİ gerekiyor.
//
// Bu dosya olmadan `PhoneAuthProvider.verifyPhoneNumber` daha en başta düşüyor:
//
//   guard await manager.checkNotificationForwarding() else {
//     throw AuthErrorUtils.notificationNotForwardedError()   // kod 17054
//   }
//
// Bu denetim, "test için uygulama doğrulamasını kapat" bayrağından ÖNCE
// çalışıyor; yani emülatörde bile atlanamıyor. Sonuç olarak delegate yoksa
// telefonla giriş NE gerçek cihazda NE emülatörde çalışır — kullanıcı "Kod
// Gönder"e bastığında hata alır.
//
// Bu kusur uzun süre görünmedi çünkü simülatörde sahte kimlik servisi
// kullanılıyordu ve bu kod yoluna hiç girilmiyordu.

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Firebase kurulumu BURADA, `App.init()`te DEĞİL.
    ///
    /// `App.init()` SwiftUI app delegate'i kurmadan önce çalışıyor; Firebase'in
    /// swizzler'ı o anda geçici bir nesne görüp "App Delegate does not conform
    /// to UIApplicationDelegate protocol" diyerek bağlanamıyor. Bağlanamayınca
    /// doğrulama bildirimi FirebaseAuth'a iletilmiyor ve telefonla giriş
    /// `ERROR_NOTIFICATION_NOT_FORWARDED` ile düşüyor. Yani bu satırın YERİ
    /// bir üslup tercihi değil, çalışma koşulu.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                        [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Self.connectEmulatorIfRequested()
        return true
    }

    /// "-emulator 127.0.0.1:8080" verilmişse Firestore ve Auth emülatöre bağlanır.
    ///
    /// Neden: `firestore.rules` JavaScript testleriyle kanıtlandı, ama o testler
    /// kuralları doğruluyor — REPOSITORY'nin ürettiği gerçek yazmaları değil.
    /// Uygulamayı aynı emülatöre bağlamak, kalıcılığı gerçek veritabanına
    /// dokunmadan ve gerçek kurallar altında denemenin tek yolu.
    ///
    /// Ayarlar İLK Firestore kullanımından önce yapılmak zorunda; sonrasında
    /// değiştirilirse SDK çöküyor.
    private static func connectEmulatorIfRequested() {
        #if DEBUG
        guard let host = LaunchConfig.emulatorHost else { return }
        let parts = host.split(separator: ":")
        let name = String(parts.first ?? "127.0.0.1")
        let port = parts.count > 1 ? Int(parts[1]) ?? 8080 : 8080

        let settings = Firestore.firestore().settings
        settings.host = "\(name):\(port)"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        // Auth emülatörü 9099'da. Firestore kuralları `request.auth.uid` istiyor;
        // gerçek Auth'a bağlı kalınırsa emülatördeki Firestore o jetonu
        // doğrulayamaz.
        Auth.auth().useEmulator(withHost: name, port: 9099)

        // Uygulama doğrulamasını kapat. YAYINA ASLA ÇIKMAZ: `#if DEBUG` ve
        // yalnızca `-emulator` verilmişken. `useEmulator` aynı satırı kendisi de
        // çalıştırıyor; açıkça yazılı olması bayrağın hangi ortamda açık
        // olduğunun tek bakışta okunması için.
        Auth.auth().settings?.appVerificationDisabledForTesting = true

        print("[emulator] Firestore \(name):\(port) · Auth \(name):9099")
        #endif
    }

    /// APNs jetonunu FirebaseAuth'a verir. Gerçek cihazda sessiz doğrulama
    /// bunun üzerinden yürüyor; simülatörde kayıt hiç başarılı olmuyor ve bu
    /// çağrılmıyor — orada emülatör + test bayrağı yolu kullanılıyor.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // `.unknown`: sandbox/production ayrımını SDK kendi çözer. Elle
        // seçilseydi TestFlight derlemelerinde yanlış ortam seçilebilirdi.
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    /// Gelen sessiz bildirimi FirebaseAuth'a iletir.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler:
                        @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(notification) {
            // Doğrulama bildirimi: uygulamanın işi yok, FirebaseAuth aldı.
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }

    /// reCAPTCHA geri dönüşü. APNs ile sessiz doğrulama yapılamadığında Firebase
    /// web akışına düşüyor ve sonucu `app-1-…-ios-…` şemasıyla uygulamaya geri
    /// veriyor (şema Config/Info.plist'te kayıtlı).
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Auth.auth().canHandle(url)
    }
}
