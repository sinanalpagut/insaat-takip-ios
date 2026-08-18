import Foundation

// MARK: - Daire ve Satış

/// Ödeme durumu — satılan daire kartındaki çip.
enum PaymentStatus: String, Codable, CaseIterable {
    case tamamlandi = "Tamamlandı"
    case kapora = "Kapora"
    case taksitli = "Taksitli"
}

struct Apartment: Codable, Identifiable, Equatable {

    /// Dairenin ticari durumu.
    /// Türkiye'de projelerin çoğu KAT KARŞILIĞI yapılıyor: dairelerin bir kısmı
    /// arsa sahibinin, bir kısmı müteahhidin. Yalnızca .sold/.available olduğu
    /// sürece arsa sahibinin daireleri "Boş" görünüyor, satış oranı ve ciro
    /// sistematik olarak yanlış çıkıyordu.
    ///
    /// İptal edilen satış ayrı bir durum DEĞİL: daire gerçekten yeniden
    /// satılabilir hale geldiği için .available'a döner, iptalin izi denetim
    /// defterinde alıcı/bedel/tahsilat anlık görüntüsüyle kalır (bkz. cancelSale).
    enum Status: String, Codable, CaseIterable, Identifiable {
        case sold        // Satıldı — ciroya girer
        case reserved    // Rezerve / opsiyonlu — kapora aşaması, ciroya HENÜZ girmez
        case landOwner   // Kat karşılığı payı — arsa sahibine gider, bedelsiz
        case available   // Boş — satışa hazır

        var id: String { rawValue }

        /// Kart rozeti. ELLE büyük harfli: Türkçe'de "İptal".uppercased()
        /// varsayılan locale'de "IPTAL" üretir, o yüzden çipe uppercased: false verilir.
        var badge: String {
            switch self {
            case .sold:      return "SATILDI"
            case .reserved:  return "REZERVE"
            case .landOwner: return "KAT KARŞILIĞI"
            case .available: return "BOŞ"
            }
        }

        /// Detay satırındaki cümle içi metin.
        var label: String {
            switch self {
            case .sold:      return "Satıldı"
            case .reserved:  return "Rezerve — kapora aşamasında"
            case .landOwner: return "Kat karşılığı payı (arsa sahibi)"
            case .available: return "Boş — satışa hazır"
            }
        }
    }

    let id: UUID
    let projectId: UUID
    var apartmentNumber: Int
    var floor: Int
    var type: String            // "2+1" / "3+1"

    /// BRÜT alan, m² — SAYI, metin değil.
    ///
    /// Önce `area: String` idi ("95 m²", "111,55 m²", "103,8 m²") ve hiçbir
    /// yerde sayıya çevrilmiyordu. m² maliyeti (madde 25) bu alanı bölen olarak
    /// istiyor ve metin üzerinden hesap iki yoldan da yanlış çıkıyordu:
    /// `parseNumber("111,55 m²")` SESSİZCE 0 döndürüyor (birim eki yüzünden
    /// `Double(...)` nil, guard 0'a düşüyor) ve giriş kutusu doğrulamasız
    /// serbest metin olduğu için "118", "118m2", "yaklaşık 120" hepsi kabul
    /// ediliyordu. Bir dairenin alanı okunamadığında toplam sessizce küçülür ve
    /// m² maliyeti olduğundan yüksek çıkar — projenin yasakladığı hata sınıfı.
    ///
    /// `nil` = HENÜZ GİRİLMEDİ. Yeni kurulan projede tüm daireler böyle açılıyor
    /// (madde 14: uydurma "2+1 / 95 m²" varsayılanları kaldırılmıştı). Bu yüzden
    /// optional: 0 m² ile "bilmiyorum" aynı şey değil, sıfır kabul edilirse
    /// bölme patlar ya da rakam uydurulur.
    ///
    /// NET alan tutulmuyor. Gerçek TOKİ verisinde biliniyor (111,55 brüt /
    /// 88,5 net) ama modellenmedi; müteahhit m² maliyetini brüt üzerinden
    /// konuşuyor ve ikinci bir alan ikinci bir doğruluk kaynağı olurdu.
    var areaM2: Double?

    /// Ekranda görünen alan metni. Tek kaynak `areaM2`.
    var areaText: String { Fmt.area(areaM2) }
    var status: Status
    /// Satıldıysa alıcı. KODLANMAZ (CodingKeys dışı): kural alan gizleyemediği
    /// için ad daire belgesinde durdukça ortağın cihazına inerdi. Kimlik
    /// `buyers/{apartmentId}` belgesinde yaşar (yalnızca yönetici okur);
    /// yüklemede yalnızca sahibin projelerinde geri birleştirilir, ortakta nil
    /// kalır. Malzemenin türetilen toplamlarıyla aynı desen: bellekte bütün,
    /// kodlama sınırında ayrık.
    var buyerName: String? = nil
    var price: Kurus            // Satış bedeli (satıldıysa)
    var paidAmount: Kurus       // Tahsil edilen tutar
    var paymentStatus: PaymentStatus?
    var saleDate: Date?         // Sözleşme / satış tarihi
    var deliveryNote: String    // "Anahtar teslim bekliyor" vb.

    enum CodingKeys: String, CodingKey {
        case id, projectId, apartmentNumber, floor, type, areaM2, status
        /// ESKİ metin alanı — yalnızca GÖÇ için okunuyor, hiç yazılmıyor.
        case area
        case price, paidAmount, paymentStatus, saleDate, deliveryNote
        // buyerName BİLİNÇLİ olarak yok — gerekçesi alanın üzerinde.
    }

    // MARK: Durumdan türeyen kovalar
    // Tek bir `isSold` yerine dört ayrı soru: her hesap hangi daireleri
    // saydığını açıkça söylesin. Önceden ciro, satış oranı, "kalan stok" ve
    // tahsilat aynı bayrağa bakıyordu; kat karşılığı daire eklenince dördü
    // birden yanlış olurdu.

    /// Ciroya sayılır mı? Yalnızca satılan. Rezerve sözleşmesi kesinleşmedi,
    /// kat karşılığı bedelsiz.
    var countsAsRevenue: Bool { status == .sold }

    /// Satış formunda seçilebilir mi? Kat karşılığı daire asla satılamaz;
    /// rezerve daire kendi kartındaki "Satışa Çevir" ile forma girer.
    var isSellable: Bool { status == .available }

    /// Tahsilat kabul eder mi? Rezerve dairenin kaporası da gerçek nakittir.
    var isCommitted: Bool { status == .sold || status == .reserved }

    /// Satış oranının paydasına girer mi? Kat karşılığı hariç her şey —
    /// paydada kalsaydı tamamı elden çıkmış blok bile hiçbir zaman %100 olmazdı.
    var isInSalesScope: Bool { status != .landOwner }

    var saleDateText: String? { saleDate.map(Fmt.shortDate) }

    /// Kat etiketi: negatif = bodrum, 0 = "Zemin", pozitif = "N. Kat" (TOKİ kat düzeni).
    var floorLabel: String { Apartment.floorLabel(for: floor) }

    /// Düzenleme formundaki kat seçicisi henüz kaydedilmemiş bir değeri
    /// gösterdiği için etiket üretimi statik olarak da erişilebilir.
    /// Üye üye başlatıcı — ELLE yazılı.
    ///
    /// Özel `init(from decoder:)` eklenince Swift üretilen başlatıcıyı artık
    /// sağlamıyor. Alan sırası ve varsayılanlar kaydın okunuşunu belirlediği
    /// için burada duruyor.
    init(id: UUID, projectId: UUID, apartmentNumber: Int, floor: Int,
         type: String, areaM2: Double?, status: Status,
         buyerName: String? = nil, price: Kurus, paidAmount: Kurus,
         paymentStatus: PaymentStatus? = nil, saleDate: Date? = nil,
         deliveryNote: String) {
        self.id = id
        self.projectId = projectId
        self.apartmentNumber = apartmentNumber
        self.floor = floor
        self.type = type
        self.areaM2 = areaM2
        self.status = status
        self.buyerName = buyerName
        self.price = price
        self.paidAmount = paidAmount
        self.paymentStatus = paymentStatus
        self.saleDate = saleDate
        self.deliveryNote = deliveryNote
    }

    // MARK: Göç — eski metin alanı

    /// `areaM2` yokken yazılmış belgeleri okur.
    ///
    /// Alan metinden sayıya taşındı; yayında zaten `area: "111,55 m²"` biçiminde
    /// yazılmış belgeler var. Bunlar okunurken bir kez ayrıştırılıyor ve sonraki
    /// yazmada sayı olarak geri gidiyor. Ayrıştırma BAŞARISIZ olursa alan `nil`
    /// kalıyor — sessizce 0 yazmak, "girilmedi" ile "sıfır" ayrımını yok eder ve
    /// m² maliyetini yanlış hesaplardı.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        projectId = try c.decode(UUID.self, forKey: .projectId)
        apartmentNumber = try c.decode(Int.self, forKey: .apartmentNumber)
        floor = try c.decode(Int.self, forKey: .floor)
        type = try c.decode(String.self, forKey: .type)
        status = try c.decode(Status.self, forKey: .status)
        price = try c.decode(Kurus.self, forKey: .price)
        paidAmount = try c.decode(Kurus.self, forKey: .paidAmount)
        paymentStatus = try c.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus)
        saleDate = try c.decodeIfPresent(Date.self, forKey: .saleDate)
        deliveryNote = try c.decode(String.self, forKey: .deliveryNote)

        if let numeric = try c.decodeIfPresent(Double.self, forKey: .areaM2) {
            areaM2 = numeric
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .area) {
            areaM2 = Apartment.parseLegacyArea(legacy)
        } else {
            areaM2 = nil
        }
    }

    /// Yazma. Eski `area` metin anahtarı ASLA yazılmıyor — göç tek yönlü,
    /// yoksa iki alan yan yana yaşar ve hangisinin doğru olduğu belirsizleşir.
    ///
    /// `areaM2` nil ise anahtar HİÇ KONULMUYOR (`encodeIfPresent`): fotoğrafın
    /// `storagePath`ıyla aynı karar — "alan var ama boş" gibi üçüncü bir durum
    /// doğmasın.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(projectId, forKey: .projectId)
        try c.encode(apartmentNumber, forKey: .apartmentNumber)
        try c.encode(floor, forKey: .floor)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(areaM2, forKey: .areaM2)
        try c.encode(status, forKey: .status)
        try c.encode(price, forKey: .price)
        try c.encode(paidAmount, forKey: .paidAmount)
        try c.encodeIfPresent(paymentStatus, forKey: .paymentStatus)
        try c.encodeIfPresent(saleDate, forKey: .saleDate)
        try c.encode(deliveryNote, forKey: .deliveryNote)
    }

    /// "111,55 m²" · "103,8 m²" · "95" → sayı. "—" ve çöp girdide nil.
    ///
    /// Türk virgülü ZORUNLU olarak destekleniyor (demo verisinde üç ayrı
    /// hassasiyet var) ve nokta da: cihaz dili İngilizce olan kullanıcı
    /// "111.55" yazar. Binlik ayracı yok — daire alanı dört haneye çıkmaz.
    static func parseLegacyArea(_ text: String) -> Double? {
        let digits = text.filter { $0.isNumber || $0 == "," || $0 == "." }
            .replacingOccurrences(of: ",", with: ".")
        guard !digits.isEmpty, let value = Double(digits),
              value.isFinite, value > 0 else { return nil }
        return value
    }

    static func floorLabel(for floor: Int) -> String {
        if floor < 0 { return "\(-floor). Bodrum" }
        return floor == 0 ? "Zemin" : "\(floor). Kat"
    }

    /// Kalan alacak.
    var remainingAmount: Kurus { max(.zero, price - paidAmount) }

    /// Tahsilat oranı (kart içindeki 4px bar).
    /// Para/para bölmesi ORAN üretir; Kurus'ta `/` bilerek tanımlı değil, bu
    /// yüzden dönüşüm açıkça yazılır — tam sayı bölmesiyle 0/1'e yuvarlanıp
    /// çubuğun hep boş ya da hep dolu görünmesi riski böyle kapanıyor.
    var collectionFraction: Double {
        price > .zero ? Double(paidAmount.raw) / Double(price.raw) : 0
    }

    /// Kart sağ altındaki metin. Duruma göre değişir: kat karşılığı dairenin
    /// bedeli yok, rezervenin ise henüz "kalan alacağı" yok — yalnızca kaporası var.
    var collectionText: String {
        switch status {
        case .landOwner:
            return "Bedelsiz devir"
        case .reserved:
            return paidAmount > .zero ? "Kapora \(Fmt.compactMoney(paidAmount))" : "Kapora bekleniyor"
        case .available:
            return ""
        case .sold:
            return paymentStatus == .tamamlandi
                ? "Tahsil edildi"
                : "Kalan \(Fmt.compactMoney(remainingAmount))"
        }
    }
}

// MARK: - Alıcı kimliği (yalnızca yönetici)

/// `projects/{pid}/buyers/{apartmentId}` belgesi. Daireden AYRI, çünkü güvenlik
/// kuralı alan gizleyemez — belgeye izin verir ya da vermez. Ortak daireyi
/// (durum, bedel, tahsilat) okur; bu belgeyi YALNIZCA sahip okur.
/// Belge kimliği = daire kimliği: sahip tek sorguyla tüm alıcıları çekip
/// dairelerle eşleştirir.
struct ApartmentBuyer: Codable, Identifiable, Equatable {
    let apartmentId: UUID
    let projectId: UUID
    var name: String

    var id: UUID { apartmentId }
}
