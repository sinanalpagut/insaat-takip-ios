import Foundation

// MARK: - Hareket / Bildirim Akışı (Ekran 07)

struct ActivityItem: Codable, Identifiable, Equatable {
    /// Satır başındaki 28px rozetin türü.
    enum Kind: String, Codable {
        case materialIn     // ↓ giriş (yeşil)
        case materialOut    // ↑ çıkış (nötr)
        case sale           // ₺ satış (bakır)
        case partnerJoined  // ＋ ortak katıldı (bakır)
    }

    /// Akıştaki zaman grubu — saklanmaz, timestamp'ten hesaplanır.
    enum Section: String, Codable, CaseIterable {
        case bugun = "Bugün"
        case dun = "Dün"
        case buHafta = "Bu Hafta"
        case dahaEski = "Daha Eski"
    }

    let id: UUID
    var kind: Kind
    var title: String       // "Demir · 12.500 kg giriş"
    var meta: String        // "145 Ada / 2 Parsel · İrsaliye #4471"
    /// Olayın gerçekleştiği an. Bölüm ve zaman etiketi bundan TÜRETİLİR —
    /// önceden "Bugün" metin olarak saklanıyordu ve yarın da "Bugün" diyordu.
    var timestamp: Date

    var timeText: String { Fmt.relativeTime(timestamp) }

    /// Akıştaki grup, her görüntülemede yeniden hesaplanır.
    var section: Section {
        if Fmt.calendar.isDateInToday(timestamp) { return .bugun }
        if Fmt.calendar.isDateInYesterday(timestamp) { return .dun }
        let days = Fmt.calendar.dateComponents([.day], from: timestamp, to: Date()).day ?? 99
        return days < 7 ? .buHafta : .dahaEski
    }

    /// Filtre çipleri: Tümü / Malzeme / Satış.
    var isMaterial: Bool { kind == .materialIn || kind == .materialOut }
    var isSale: Bool { kind == .sale }
}

// MARK: - Şantiye Fotoğrafı (Ekran 09)

import UIKit

struct SitePhoto: Identifiable, Equatable {
    let id: UUID
    let projectId: UUID
    var date: Date              // Çekim tarihi

    var dateText: String { Fmt.dayMonth(date) }

    /// "Bu hafta" grubu tarihten hesaplanır — sabit bayrak yarın yanlış olurdu.
    var isCurrentWeek: Bool {
        Fmt.calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Küçültülmüş görsel. Galeriden gelen ham veri ASLA saklanmaz:
    /// 12 MP bir fotoğrafın çözülmüş hali ~48 MB'tır; birkaç kare bile
    /// uygulamanın bellekten sonlandırılmasına yeter. İçe aktarımda
    /// `SitePhoto.thumbnailSide` boyutuna indirgenir ve tek sefer üretilir.
    var image: UIImage?

    static let thumbnailSide: CGFloat = 1200

    /// Diff maliyeti: görselin baytlarını karşılaştırmak yerine kimlik + tarih.
    static func == (lhs: SitePhoto, rhs: SitePhoto) -> Bool {
        lhs.id == rhs.id
            && lhs.date == rhs.date
            && (lhs.image === rhs.image)
    }

    /// Ham galeri verisini ekran için yeterli boyuta indirger.
    static func downsample(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailSide,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Daire Görseli (Ekran 13)

/// Daireye bağlı etiketli görsel. `Apartment` Codable kaldığı için
/// görseller ayrı koleksiyonda tutulur (UIImage kodlanamaz).
struct ApartmentPhoto: Identifiable, Equatable {
    let id: UUID
    let apartmentId: UUID
    var label: String        // "Salon", "Mutfak", "Görsel 3"…
    var image: UIImage?      // nil = tasarımdaki yer tutucu kare

    static func == (lhs: ApartmentPhoto, rhs: ApartmentPhoto) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && (lhs.image === rhs.image)
    }
}
