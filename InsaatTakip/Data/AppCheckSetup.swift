import Foundation
import FirebaseAppCheck
import FirebaseCore

// MARK: - App Check (madde 71)
//
// App Check, Firebase'e gelen isteğin GERÇEKTEN bu uygulamadan geldiğini
// kanıtlıyor. Onsuz proje kimliği ve API anahtarı — ki ikisi de uygulamanın
// içinde, yani sökülebilir — herkese açık birer uç demek:
//   · Telefon girişi herkese açık ve HER SMS ÜCRETLİ,
//   · `redeemInvite` ve `deleteAccount` düz HTTPS uçları (madde 68'de
//     testlerin kendisi bunu kanıtladı: uygulama hiç açılmadan curl ile
//     çağrılabiliyor),
//   · Firestore ve Storage kuralları YETKİYİ denetliyor, ÇAĞIRANI değil.
// Bütçe uyarısı da harcamayı KESMİYOR, yalnızca haber veriyor.
//
// ═══ SIRA ═══
// Sağlayıcı fabrikası `FirebaseApp.configure()`dan ÖNCE kurulmak zorunda.
// Sonra kurulursa Firebase ilk jetonu varsayılan sağlayıcıyla almaya çalışır
// ve sessizce başarısız olur — sorun ancak zorlama açıldığında, yani
// üretimde, görünür.
//
// ═══ SAĞLAYICI SEÇİMİ ═══
// GERÇEK CİHAZ: App Attest. Uygulama hedefi iOS 16 olduğu için her cihazda
// var; DeviceCheck'e düşmeye gerek yok.
// SİMÜLATÖR/DEBUG: Debug sağlayıcı. App Attest simülatörde çalışmıyor;
// debug sağlayıcı konsola bir jeton basıyor ve o jeton Firebase konsoluna
// elle eklendiğinde simülatör de doğrulanmış sayılıyor.
//
// ═══ ZORLAMA AÇILMADI ve bu BİLİNÇLİ ═══
// İstemci jetonu GÖNDERİYOR, sunucu henüz İSTEMİYOR. Firebase konsolunda
// zorlama açılmadan önce "doğrulanmış / doğrulanmamış" ölçümlerine bakmak
// gerekiyor: gerçek trafiğin doğrulandığı görülmeden zorlama açmak,
// uygulamayı kendi kullanıcılarına kapatmak olur. Aynı ders madde 77'de
// yaşandı — kural sıkılaştırması önce koşturularak doğrulandı.
// Callable'lardaki `enforceAppCheck` de aynı sebeple AÇILMADI.

enum AppCheckSetup {

    /// `FirebaseApp.configure()`dan ÖNCE çağrılmalı.
    static func install() {
        #if DEBUG
        // Debug jetonu konsola basılıyor:
        //   "Firebase App Check Debug Token: XXXXXXXX-..."
        // O değer Firebase konsolunda App Check → uygulama → Manage debug
        // tokens altına eklenmeli. Eklenmezse simülatör doğrulanmamış sayılır
        // — zorlama kapalıyken zararsız, açıldığında simülatör dışarıda kalır.
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif
    }

    /// Jetonun GERÇEKTEN alınabildiğini sınar ve SONUCU günlüğe yazar.
    ///
    /// NEDEN ÜRETİMDE DE ÇALIŞIYOR (`#if DEBUG` YOK): App Check sessizce
    /// başarısız olan bir mekanizma. Jeton alınamazsa uygulama hiçbir şey
    /// söylemez — yalnızca her istek reddedilir ve kullanıcı "veriler
    /// gelmiyor" der. Crashlytics bilerek ertelendiği için (madde 30) sahada
    /// bunu görmenin BAŞKA YOLU YOK. Teşhisi yalnızca DEBUG'a koymak, tam da
    /// ölçülemeyen yeri ölçüsüz bırakmak olurdu: App Attest zaten SADECE
    /// Release'de çalışıyor.
    ///
    /// JETONUN KENDİSİ ASLA YAZILMIYOR — o bir kimlik bilgisi ve günlükler
    /// cihazdan dışarı çıkabiliyor. Yalnızca alınıp alınamadığı ve hata metni.
    ///
    /// `forcingRefresh: false` BİLİNÇLİ: önbellekte jeton varsa ağa çıkmıyor,
    /// yani her açılışta bedel yok. Taze kurulumda önbellek boş olduğu için
    /// gerçek bir doğrulama turu koşuyor — yani kanıt istediğimiz an olan
    /// "ilk Release kurulumu"nda tam olarak istediğimiz şeyi ölçüyor.
    static func probe() {
        AppCheck.appCheck().token(forcingRefresh: false) { _, hata in
            // `Diag` üzerinden: tek yazma yolu olsun. `print` kullanıldığında
            // satır tamponda kalıp hiç görünmeyebiliyor (gerekçe `Diag.yaz`).
            if let hata {
                Diag.log("appcheck", "JETON ALINAMADI — \(hata.localizedDescription)")
            } else {
                Diag.log("appcheck", "jeton alındı")
            }
        }
    }
}

/// App Attest sağlayıcı fabrikası.
///
/// Ayrı tip olmasının sebebi: Firebase hazır bir `AppAttestProviderFactory`
/// sunmuyor, fabrika protokolünü uygulamak gerekiyor.
final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
