import SwiftUI

// MARK: - Renk Paleti
// Tasarım dosyasındaki (design handoff) token tablosunun birebir Swift karşılığı.
// Antrasit (ink) + Bakır (copper) paleti.

extension Color {
    /// "#RRGGBB" hex değerinden Color üretir.
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Palette {
    // Zemin ve yüzeyler
    static let ink          = Color(hex: 0x22262E) // koyu app bar, birincil metin
    static let page         = Color(hex: 0xF6F4F2) // ekran arka planı
    static let surface      = Color.white          // kartlar, sheet'ler
    static let border       = Color(hex: 0xE7E2DC) // kart kenarlıkları
    static let divider      = Color(hex: 0xF2EEE9) // kart içi ayırıcılar
    static let track        = Color(hex: 0xEFEBE6) // progress bar rayı
    static let fillSubtle   = Color(hex: 0xFAF8F6) // iç paneller, dropzone zemini
    static let fillMuted    = Color(hex: 0xF2EFEB) // ikon çipleri, kapat butonları

    // Vurgu (bakır)
    static let accent        = Color(hex: 0xA9633C) // birincil aksiyonlar, FAB, aktif sekme
    static let accentPressed = Color(hex: 0x8A4E2E)
    static let accentTint    = Color(hex: 0xF5E6DC) // ikon kareleri, seçili çipler
    static let accentLight   = Color(hex: 0xE8A87C) // koyu bar üzerindeki "Net" rakamı

    // Metin
    static let textSecondary = Color(hex: 0x8C877F)
    static let textTertiary  = Color(hex: 0xB0A99F)
    static let textMuted     = Color(hex: 0x6E6860)
    static let textControl   = Color(hex: 0x7C766D)
    static let textFaded     = Color(hex: 0x857F76) // pasif segment / boş daire rozeti
    static let tabInactive   = Color(hex: 0xA8A199)

    // Başarı (satış) tonları
    static let success       = Color(hex: 0x3F7A54)
    static let successTint   = Color(hex: 0xE7F0E9)
    static let successBorder = Color(hex: 0xC9DDCE)
    static let successInk    = Color(hex: 0x23543A)
    static let successChip   = Color(hex: 0xCFE3D4)

    // Beklemede (kapora / taksitli) — bilinçli olarak nötr
    static let pendingTint   = Color(hex: 0xEFEAE3)
    static let pendingInk    = Color(hex: 0x6E6860)

    // Uyarı (kritik stok, PDF rozeti)
    static let alertTint     = Color(hex: 0xF6E3DE)
    static let alertInk      = Color(hex: 0x9C4A38)
    static let alertBar      = Color(hex: 0xB85A42)

    // Marka
    static let whatsapp      = Color(hex: 0x1FA855)

    // Kesikli kenarlıklar
    static let dashed        = Color(hex: 0xD3CABF)
    static let dashedSoft    = Color(hex: 0xDCD5CC)

    // Bildirim zili noktası
    static let amberDot      = Color(hex: 0xE0A21C)

    // İçerik üzeri scrim
    static let scrim         = Color(hex: 0x1C1A18, alpha: 0.48)

    // Grafik: zayıf ay çubuğu
    static let barSoft       = Color(hex: 0xD9B79C)
}
