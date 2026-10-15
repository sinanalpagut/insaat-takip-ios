import Foundation

// MARK: - Launch Argümanları (yalnızca DEBUG)
// Simülatörde belirli bir ekranı doğrudan açmak için kullanılır; ekran görüntüsü
// karşılaştırmaları ve ileride snapshot testleri için:
//   xcrun simctl launch <udid> com.sinanalpagut.insaattakip \
//       -role admin -screen project -tab apt -sheet invite
//
// Paket ekranı için:
//   xcrun simctl launch <udid> com.sinanalpagut.insaattakip \
//       -role admin -screen dashboard -plan free -sheet plans

enum LaunchConfig {
    private static func value(for key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// "-role admin|partner" → otomatik oturum.
    static var role: UserRole? {
        #if DEBUG
        switch value(for: "role") {
        case "admin":   return .admin
        case "partner": return .partner
        default:        return nil
        }
        #else
        return nil
        #endif
    }

    /// "-screen dashboard|project|activity|photos|report"
    static var screen: String? {
        #if DEBUG
        return value(for: "screen")
        #else
        return nil
        #endif
    }

    /// "-tab mat|apt|ptn|doc"
    static var tab: String? {
        #if DEBUG
        return value(for: "tab")
        #else
        return nil
        #endif
    }

    /// "-sheet log|receipt|invite|apt|sale|upload"
    static var sheet: String? {
        #if DEBUG
        return value(for: "sheet")
        #else
        return nil
        #endif
    }

    /// "-plan free|santiye|muteahhit|kurumsal" → hak enjeksiyonu (madde 87).
    ///
    /// NEDEN GEREKLİ: paket satırı ve paket ekranı DÖRT duruma göre farklı
    /// görünüyor — yayın öncesi, ücretsiz, ücretsiz+sınırda, ücretli. Yayın
    /// öncesi varsayılan `preLaunchUnlimited` olduğu için diğer üçü elle HİÇ
    /// açılamıyordu: ekranın çoğu durumu, kod yazıldıktan sonra bile
    /// görülmeden kalıyordu. Sınır ENJEKTE EDİLEREK test edilir ilkesinin
    /// (QuotaTests) ekran tarafındaki karşılığı.
    ///
    /// YALNIZCA DEBUG: yayın sürümünde açık kalsaydı kullanıcı kendine
    /// kurumsal paket verebilirdi.
    static var entitlement: Entitlement? {
        #if DEBUG
        switch value(for: "plan") {
        case "free":      return .plan(.ucretsiz)
        case "santiye":   return .plan(.santiye)
        case "muteahhit": return .plan(.muteahhit)
        case "kurumsal":  return .plan(.kurumsal)
        default:          return nil
        }
        #else
        return nil
        #endif
    }

    /// "-backend firestore" → bellek içi demo verisi yerine gerçek Firestore.
    ///
    /// Varsayılan hâlâ demo verisi: 5 projelik senaryo ekran karşılaştırmaları ve
    /// tasarım sadakati denetimleri için gerekli, ayrıca kalıcılık henüz her
    /// akışta doğrulanmadı. Anahtar açıkça çevrilmeden gerçek veritabanına
    /// geçilmiyor — yanlışlıkla boş bir uygulamayla karşılaşmamak için.
    static var usesFirestore: Bool {
        #if DEBUG
        return value(for: "backend") == "firestore"
        #else
        return true
        #endif
    }

    /// "-auth firebase" → simülatörde de GERÇEK Firebase kimliği (madde 68/69).
    ///
    /// Simülatörde sahte kimlik kullanılmasının TEK gerekçesi vardı: telefon
    /// doğrulaması APNs sessiz bildirimi istiyor ve simülatörde push hiç
    /// çalışmıyor. Firebase'in TEST TELEFON NUMARASI o gerekçeyi ortadan
    /// kaldırıyor — beyaz listedeki numara için ne SMS ne APNs ne de reCAPTCHA
    /// devreye giriyor, dolayısıyla gerçek `PhoneAuthProvider` yolu simülatörde
    /// de birebir çalışıyor.
    ///
    /// Bu anahtar olmadan hesap silmenin GERÇEK yolu yalnızca fiziksel cihazda
    /// denenebiliyordu ve madde 68'in tespiti tam olarak buydu: "simülatör
    /// sahte servisi kullanıyor, gerçek reauthenticate + gerçek silme
    /// denenmedi". Denenemeyen şey doğrulanamıyor.
    ///
    /// `-backend firestore` ile birlikte kullanılmak üzere: gerçek Firestore'a
    /// SAHTE kimlikle bağlanmanın anlamı yok, çünkü kurallar `request.auth.uid`
    /// istiyor ve her yazma reddedilirdi.
    static var usesFirebaseAuth: Bool {
        #if DEBUG
        return value(for: "auth") == "firebase"
        #else
        return true
        #endif
    }

    /// "-firedebug" → Firestore SDK günlüğü AÇIK.
    ///
    /// AD ÇAKIŞMASI: bayrak önce "-firelog"du ve `devicectl` onu kendi
    /// `-l <path>` seçeneği sanıp başlatmayı reddetti (kısa seçenekler
    /// harf harf ayrıştırılıyor). Cihaza argüman geçirirken `l`, `t`, `j`
    /// gibi değer isteyen kısa seçenek harflerinden kaçınmak gerekiyor.
    ///
    /// TEŞHİS ARACI, kalıcı davranış değil. Kayıtlı ders: "Firebase'de bir şey
    /// SESSİZCE çalışmıyorsa önce SDK günlüğünü aç" — yazma reddedildiğinde
    /// uygulama hiçbir şey basmıyor, SDK basıyor.
    static var firestoreLogging: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-firedebug")
        #else
        return false
        #endif
    }

    /// "-emulator 127.0.0.1:8080" → Firestore ve Auth emülatörüne bağlan.
    ///
    /// Kural testleri (tests/rules.test.mjs) kuralları JavaScript tarafından
    /// kanıtlıyor; bu anahtar UYGULAMANIN KENDİSİNİ aynı emülatöre bağlıyor,
    /// böylece repository'nin ürettiği gerçek yazmalar da aynı kurallardan
    /// geçiyor. Gerçek veritabanına dokunmadan uçtan uca doğrulama yolu bu.
    static var emulatorHost: String? {
        #if DEBUG
        return value(for: "emulator")
        #else
        return nil
        #endif
    }
}
