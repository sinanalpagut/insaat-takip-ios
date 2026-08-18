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

    /// Bir tutarı yüzde paylara böler. **Payların toplamı tutarın kendisine
    /// EŞİTTİR** — bir kuruş bile kaybolmaz ya da türemez.
    ///
    /// Neden ayrı bir işlem: her payı tek tek `tutar × yüzde / 100` diye
    /// yuvarlamak toplamı bozar. %33 / %33 / %34'lük bir dağılımda üç pay
    /// ayrı ayrı yuvarlandığında toplamları tutardan 1-2 kuruş sapar ve
    /// yönetici ekranda "toplamı tutmayan üç rakam" görür. Bu uygulamada
    /// rakamın dürüstlüğü bir üslup tercihi değil ("Net" etiketi tam da bu
    /// yüzden düzeltilmişti), o yüzden dağıtım EN BÜYÜK KALAN yöntemiyle
    /// yapılıyor: önce taban paylar verilir, artan kuruşlar kesirli kısmı en
    /// büyük olan paydan başlayarak birer birer dağıtılır.
    ///
    /// `cost(quantity:unitPrice:)`'tan sonraki İKİNCİ yuvarlama noktası —
    /// üçüncüsü olmamalı.
    ///
    /// Yüzdeler toplamı 100 olmak zorunda DEĞİL: %60 tanımlıysa tutarın
    /// yalnızca %60'ı dağıtılır, kalanı çağıranın sorunudur (ekranda
    /// "%40 tanımsız" diye görünür).
    static func split(_ total: Kurus, byPercents percents: [Int]) -> [Kurus] {
        guard !percents.isEmpty else { return [] }
        // Negatif tutar (zarardaki proje) da bölünebilmeli. İşareti ayırıp
        // büyüklük üzerinden dağıtıyoruz: aksi halde tam sayı bölmesinin
        // sıfıra doğru kırpması zararı ortaklar arasında asimetrik dağıtırdı.
        let sign: Int64 = total.raw < 0 ? -1 : 1
        let magnitude = abs(total.raw)

        // Taban pay ve kalan: her ikisi de tam sayı, kayan nokta yok.
        var shares = percents.map { Kurus(raw: sign * (magnitude * Int64($0) / 100)) }
        let remainders = percents.map { (magnitude * Int64($0)) % 100 }

        let distributed = shares.reduce(Int64(0)) { $0 + abs($1.raw) }
        var leftover = (magnitude * Int64(percents.reduce(0, +)) / 100) - distributed

        // Kalanı büyükten küçüğe dağıt; eşitlikte sıradaki ilk pay kazanır ki
        // sonuç ÇAĞRIDAN ÇAĞRIYA AYNI olsun (rastgelelik yok).
        let order = remainders.enumerated()
            .sorted { $0.element == $1.element ? $0.offset < $1.offset : $0.element > $1.element }
            .map(\.offset)
        var i = 0
        while leftover > 0, i < order.count {
            shares[order[i]] = Kurus(raw: shares[order[i]].raw + sign)
            leftover -= 1
            i += 1
        }
        return shares
    }

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
