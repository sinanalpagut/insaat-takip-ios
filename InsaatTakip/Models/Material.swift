import Foundation

// MARK: - Malzeme ve Stok Hareketi

struct Material: Codable, Identifiable, Equatable {
    /// Önceden "p1-Ø12" gibi projeye ve rozet koduna bağlıydı: kod değişince
    /// kimlik kırılıyordu ve ASCII olmayan karakter içeriyordu.
    let id: UUID
    let projectId: UUID
    var code: String          // Rozet kodu: "Ø12", "C30", "ÇMT"…
    var name: String          // "Demir", "Hazır Beton"…
    var subtitle: String      // "Nervürlü inşaat demiri"
    var unit: String          // "kg", "m³", "torba", "adet", "m²", "ton"
    var unitPrice: Kurus      // Güncel/son alış birim fiyatı — yalnızca gösterim ve ön dolum

    // MARK: Türetilen toplamlar
    // Aşağıdaki üç alan ViewModel dışında ASLA yazılmaz; tek yazma noktası
    // recalculateMaterial'dır. Önceden `accruedCost += ...` ile birikiyordu
    // ve bunu geri alan hiçbir kod yolu yoktu: yanlış girilen bir fiş
    // maliyette kalıcı olarak duruyordu.
    var totalIn: Double       // Toplam giren = devir + giriş fişleri
    var totalOut: Double      // Toplam kullanılan = devir + çıkış fişleri
    var step: Double          // Fiş formunda hızlı artış adımı
    /// Fiilen ödenen toplam tutar; her giriş kendi tarihindeki fiyatıyla sayılır.
    /// Hesaplanan (totalIn × güncel fiyat) yerine hareket bazlı bir toplamdır:
    /// aksi halde yeni bir fiyat girmek geçmişteki tüm stoğu yeniden fiyatlandırırdı.
    var accruedCost: Kurus

    // MARK: Devir (açılış) bakiyesi
    // Bir proje uygulamaya girdiğinde şantiyede zaten malzeme vardır ve o
    // günün öncesine ait fiş yoktur. Toplamlar hareketlerden türetildiği için
    // kayıtlı hareketlerle açıklanamayan kısım burada durur; devir olmasaydı
    // bir fiş silindiğinde hiç fişi olmayan stok da sıfıra düşerdi.
    var openingIn: Double = 0
    var openingOut: Double = 0
    var openingCost: Kurus = .zero

    /// Kalan stok.
    var currentStock: Double { totalIn - totalOut }

    /// Kalan / giren oranı (progress bar).
    var remainingFraction: Double { totalIn > 0 ? currentStock / totalIn : 0 }

    /// Toplam malzeme tutarı.
    var totalCost: Kurus { accruedCost }

    /// Kritik stok: kalan oranı eşiğin altına düşünce uyarı paletine geçer.
    ///
    /// `totalIn > 0` koşulu şart: hiç alım yapılmamış kalem "kritik stok" değil,
    /// yalnızca "henüz alınmadı"dır. Bu koşul olmadan yeni kurulan projede
    /// dokuz kalemin dokuzu da kırmızı "KRİTİK" rozetiyle açılıyordu ve rozet
    /// anlamını yitiriyordu — gerçekten kritik olan bir kalem o gürültünün
    /// içinde fark edilmezdi.
    static let criticalThreshold = 0.10
    var isCritical: Bool {
        totalIn > 0 && remainingFraction < Material.criticalThreshold
    }

    /// Toplamları devir + hareketlerden yeniden türetir.
    /// Formül burada durur çünkü iki ayrı çağıranı var: çalışma zamanında
    /// ProjectViewModel (fiş eklenince/silinince), veri kaynağı kurulurken de
    /// repository. İki yerde ayrı yazılsaydı biri değişip diğeri kalırdı.
    mutating func recalculate(from logs: [MaterialLog]) {
        let mine = logs.filter { $0.materialId == id }
        let entries = mine.filter { $0.type == .entry }
        totalIn = openingIn + entries.reduce(0) { $0 + $1.amount }
        totalOut = openingOut + mine.filter { $0.type == .exit }.reduce(0) { $0 + $1.amount }
        // Yuvarlama fiş BAŞINA yapılır (Kurus.cost), toplamda değil: böylece bir
        // fiş silindiğinde etkisi tam olarak geri alınıyor ve ay/çeyrek toplamları
        // proje toplamının parçası olarak kalıyor.
        accruedCost = openingCost + entries.reduce(Kurus.zero) {
            $0 + Kurus.cost(quantity: $1.amount, unitPrice: $1.unitPrice)
        }
    }
}

/// Malzeme giriş / çıkış kaydı.
struct MaterialLog: Codable, Identifiable, Equatable {
    enum LogType: String, Codable {
        case entry   // Giriş · Şantiyeye
        case exit    // Çıkış · Kullanım
    }

    let id: UUID
    let materialId: UUID
    var type: LogType
    var amount: Double
    /// Kayıt anındaki birim fiyat — dondurulur; sonraki fiyat değişiklikleri
    /// geçmiş dönem raporlarını değiştirmesin diye.
    var unitPrice: Kurus
    /// Hareketin gerçekleştiği an. Metin yerine Date: sıralama, dönem filtresi
    /// ve geçmiş tarihli kayıt ancak böyle mümkün.
    var date: Date
    var note: String          // "İrsaliye #4471 · Yılmaz Yapı" / "5. kat perde donatısı"
    var user: String          // Kaydı giren kişi

    var dateText: String { Fmt.shortDate(date) }

    /// "+12.500 kg" / "−6.800 kg"
    func signedAmount(unit: String) -> String {
        (type == .entry ? "+" : "−") + Fmt.qty(amount, unit: unit)
    }
}
