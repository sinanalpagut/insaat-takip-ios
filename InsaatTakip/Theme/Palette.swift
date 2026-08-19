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
    //
    // ═══ KONTRAST (madde 31) ═══
    // Tasarımdan gelen gri tonlar WCAG AA'nın normal metin eşiğinin (4,5:1)
    // ALTINDAYDI ve en kötüsü en çok kullanılanıydı: textTertiary beyaz
    // üzerinde 2,33:1, textSecondary 3,57:1, tabInactive 2,55:1.
    //
    // İşin can sıkıcı tarafı NEREDE kullanıldıklarıydı: kapsam notları.
    // "m² maliyetinin paydası dairelerin brüt alan toplamı", "kalan inşaat
    // maliyeti düşülmemiştir", "ortakların koyduğu sermaye henüz tutulmuyor" —
    // yani rakamları DÜRÜST kılan metinler, uygulamanın en okunmaz metinleriydi.
    // Şantiyede güneş altında pratikte görünmüyorlardı.
    //
    // Tonlar surface / page / fillSubtle / fillMuted zeminlerinde 4,5:1'i
    // geçecek şekilde koyulaştırıldı. Hiyerarşi KAYBOLMADI: aralarındaki
    // parlaklık farkı korundu ve zaten ağırlık (Regular / SemiBold / ExtraBold)
    // ile boyut farkı da taşıyor.
    static let textSecondary = Color(hex: 0x5F5B55) // 6,74:1 (beyaz)
    static let textTertiary  = Color(hex: 0x726C62) // 5,20:1
    static let textMuted     = Color(hex: 0x6E6860) // 5,51:1 — zaten geçiyordu
    static let textControl   = Color(hex: 0x67625A) // form etiketleri
    static let textFaded     = Color(hex: 0x6C675F) // 5,61:1
    static let tabInactive   = Color(hex: 0x74706A) // 4,92:1 — birincil navigasyon

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
