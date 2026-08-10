import SwiftUI

// MARK: - Tipografi
// Display / rakamlar: Sora (600, 700) — başlıklar, para, miktar, davet kodu, daire no.
// UI / gövde: Manrope (400–800) — etiketler, gövde metni, meta.

extension Font {
    /// Sora — başlık ve rakam fontu.
    static func sora(_ size: CGFloat, _ weight: SoraWeight = .semiBold) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    /// Manrope — arayüz / gövde fontu.
    static func manrope(_ size: CGFloat, _ weight: ManropeWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }
}

enum SoraWeight {
    case regular, semiBold, bold

    var postScriptName: String {
        switch self {
        case .regular:  return "Sora-Regular"
        case .semiBold: return "Sora-SemiBold"
        case .bold:     return "Sora-Bold"
        }
    }
}

enum ManropeWeight {
    case regular, medium, semiBold, bold, extraBold

    var postScriptName: String {
        switch self {
        case .regular:   return "Manrope-Regular"
        case .medium:    return "Manrope-Medium"
        case .semiBold:  return "Manrope-SemiBold"
        case .bold:      return "Manrope-Bold"
        case .extraBold: return "Manrope-ExtraBold"
        }
    }
}

// MARK: - Hazır metin stilleri

extension View {
    /// Küçük büyük-harf etiket stili (9.5–10.5px, 800, geniş harf aralığı).
    func smallCapsLabel(size: CGFloat = 10.5, color: Color = Palette.textTertiary, tracking: CGFloat = 1.0) -> some View {
        self.font(.manrope(size, .extraBold))
            .tracking(tracking)
            .foregroundColor(color)
            .textCase(.uppercase)
    }
}
