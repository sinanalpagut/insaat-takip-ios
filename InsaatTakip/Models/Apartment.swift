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
    var area: String            // "95 m²"
    var status: Status
    var buyerName: String?      // Satıldıysa alıcı
    var price: Kurus            // Satış bedeli (satıldıysa)
    var paidAmount: Kurus       // Tahsil edilen tutar
    var paymentStatus: PaymentStatus?
    var saleDate: Date?         // Sözleşme / satış tarihi
    var deliveryNote: String    // "Anahtar teslim bekliyor" vb.

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
