import Foundation

// MARK: - Daire ve Satış

/// Ödeme durumu — satılan daire kartındaki çip.
enum PaymentStatus: String, Codable, CaseIterable {
    case tamamlandi = "Tamamlandı"
    case kapora = "Kapora"
    case taksitli = "Taksitli"
}

struct Apartment: Codable, Identifiable, Equatable {
    enum Status: String, Codable {
        case sold        // Satıldı (yeşil kart)
        case available   // Boş (kesikli kenarlıklı kart)
    }

    let id: String
    let projectId: String
    var apartmentNumber: Int
    var floor: Int
    var type: String            // "2+1" / "3+1"
    var area: String            // "95 m²"
    var status: Status
    var buyerName: String?      // Satıldıysa alıcı
    var price: Double           // Satış bedeli (satıldıysa)
    var paidAmount: Double      // Tahsil edilen tutar
    var paymentStatus: PaymentStatus?
    var saleDateText: String?   // "18 Şub 2026"
    var deliveryNote: String    // "Anahtar teslim bekliyor" vb.
    var imageLabels: [String]   // Daire görsel yuvaları ("Salon", "Mutfak")

    var isSold: Bool { status == .sold }

    /// Kat etiketi: 0 = "Zemin" (TOKİ projelerindeki zemin katlar), diğerleri "N. Kat".
    var floorLabel: String {
        floor == 0 ? "Zemin" : "\(floor). Kat"
    }

    /// Kalan alacak.
    var remainingAmount: Double { max(0, price - paidAmount) }

    /// Tahsilat oranı (kart içindeki 4px bar).
    var collectionFraction: Double { price > 0 ? paidAmount / price : 0 }

    /// Kart sağ altındaki metin: "Tahsil edildi" / "Kalan 3,20 M ₺"
    var collectionText: String {
        paymentStatus == .tamamlandi ? "Tahsil edildi" : "Kalan \(Fmt.compactMoney(remainingAmount))"
    }
}
