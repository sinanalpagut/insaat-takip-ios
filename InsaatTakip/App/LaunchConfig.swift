import Foundation

// MARK: - Launch Argümanları (yalnızca DEBUG)
// Simülatörde belirli bir ekranı doğrudan açmak için kullanılır; ekran görüntüsü
// karşılaştırmaları ve ileride snapshot testleri için:
//   xcrun simctl launch <udid> com.sinanalpagut.insaattakip \
//       -role admin -screen project -tab apt -sheet invite

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
