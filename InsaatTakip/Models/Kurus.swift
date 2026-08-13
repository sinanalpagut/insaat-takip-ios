import Foundation

// MARK: - Para (kuruş)
//
// Para `Double` ile tutulmaz: ikilik kayan nokta 0,1'i tam temsil edemez ve
// hata toplamlarda birikir. Uygulamanın merkezî rakamı olan "Net" onlarca
// kalemin toplamı-farkı olduğu için bu birikme doğrudan ortağa gösterilen
// tabloya yansır. Ayrıca `>=` ve `!=` karşılaştırmaları kesinleşmediği için
// "bedelin tamamı tahsil edildi mi" kapısı ve denetim izi diff'i güvenilmez.
//
// Ham `Int64` yerine ince bir sarmalayıcı olmasının sebebi, derleyiciyi işe
// koşmak:
//
//  1. `ExpressibleByIntegerLiteral` KASTEN yok. Demo verisindeki tuple'lar tip
//     anotasyonlu (`[(Int, String, Double, …)]`); ham Int64'e geçilseydi
//     `3_150_000` literali olduğu gibi derlenir ve sessizce 31.500 ₺ olurdu.
//     173 para sabitinin tamamı 100 kat sapabilir, üstelik sapan değer hâlâ
//     "makul bir daire fiyatı" göründüğü için gözle de yakalanmazdı. Bu tip
//     her sabiti `.lira(…)` yazmaya zorlar; iş listesini derleyici çıkarır.
//
//  2. Bölme operatörü YOK. Para/para bölmesi oran üretir (tahsilat yüzdesi,
//     gider dağılımı, grafik çubuğu). Ham Int64'te bunlar derlenmeye devam
//     eder ama tam sayı bölmesi 0 ya da 1 döndürür — ilerleme çubukları hep
//     boş ya da hep dolu görünür, tek bir uyarı çıkmaz. Burada derleme hatası
//     verir ve `Double(a.raw) / Double(b.raw)` yazmaya zorlar.
//
//  3. Ham Int64'te `price` ile `apartmentNumber`, `floor`, `daysAgo` aynı tip
//     olurdu; bugün Double/Int ayrımının sağladığı kaza koruması kaybolurdu.

struct Kurus: Codable, Equatable, Hashable, Comparable, AdditiveArithmetic {

    /// Tam sayı kuruş. 1 ₺ = 100.
    private(set) var raw: Int64

    private init(raw: Int64) { self.raw = raw }

    static let zero = Kurus(raw: 0)

    /// Lira (ve isteğe bağlı kuruş) cinsinden: `.lira(3_150_000)` · `.lira(28, 50)` → 28,50 ₺
    static func lira(_ lira: Int, _ kurus: Int = 0) -> Kurus {
        Kurus(raw: Int64(lira) * 100 + Int64(kurus))
    }

    /// Doğrudan kuruş cinsinden — ayrıştırma ve hesap sonuçları için.
    static func kurus(_ value: Int64) -> Kurus { Kurus(raw: value) }

    /// Miktar × birim fiyat. Uygulamadaki TEK yuvarlama noktası.
    ///
    /// Miktarlar (kg, m³, torba) `Double` kalıyor, fiyat kuruş; çarpım kaçınılmaz
    /// olarak kesirli çıkıyor. Yuvarlama yarım-yukarı: hem Türk ticari teamülü
    /// hem de demo verisinin bugün kullandığı `.rounded()` varsayılanı — banker
    /// yuvarlamasına geçmek ekrandaki mevcut rakamları kaydırırdı.
    ///
    /// Kural fiş BAŞINA uygulanır, toplamda değil. Böylece bir fiş silindiğinde
    /// etkisi tam olarak geri alınabiliyor ve alt küme toplamları (ay, çeyrek)
    /// üst küme toplamının parçası olarak kalıyor.
    static func cost(quantity: Double, unitPrice: Kurus) -> Kurus {
        guard quantity.isFinite else { return .zero }
        return Kurus(raw: Int64((quantity * Double(unitPrice.raw)).rounded()))
    }

    /// Oran hesapları için — bölme bilinçli olarak burada değil, çağıran yerde
    /// `Double(a.raw) / Double(b.raw)` diye AÇIKÇA yazılır ki para/para bölmesinin
    /// oran ürettiği gözden kaçmasın.
    var liraValue: Double { Double(raw) / 100 }

    // MARK: Aritmetik

    static func + (lhs: Kurus, rhs: Kurus) -> Kurus { Kurus(raw: lhs.raw + rhs.raw) }
    static func - (lhs: Kurus, rhs: Kurus) -> Kurus { Kurus(raw: lhs.raw - rhs.raw) }
    static prefix func - (value: Kurus) -> Kurus { Kurus(raw: -value.raw) }
    static func < (lhs: Kurus, rhs: Kurus) -> Bool { lhs.raw < rhs.raw }

    // MARK: Codable
    // Düz `Int64` olarak kodlanır — Firestore şeması tam sayı görsün, sarmalayıcı
    // JSON'a bir nesne olarak sızmasın.

    init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode(Int64.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}
