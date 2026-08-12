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

    let id: UUID
    let projectId: UUID
    var apartmentNumber: Int
    var floor: Int
    var type: String            // "2+1" / "3+1"
    var area: String            // "95 m²"
    var status: Status
    var buyerName: String?      // Satıldıysa alıcı
    var price: Double           // Satış bedeli (satıldıysa)
    var paidAmount: Double      // Tahsil edilen tutar
    var paymentStatus: PaymentStatus?
    var saleDate: Date?         // Sözleşme / satış tarihi
    var deliveryNote: String    // "Anahtar teslim bekliyor" vb.

    var isSold: Bool { status == .sold }

    var saleDateText: String? { saleDate.map(Fmt.shortDate) }

    /// Kat etiketi: negatif = bodrum, 0 = "Zemin", pozitif = "N. Kat" (TOKİ kat düzeni).
    var floorLabel: String {
        if floor < 0 { return "\(-floor). Bodrum" }
        return floor == 0 ? "Zemin" : "\(floor). Kat"
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
