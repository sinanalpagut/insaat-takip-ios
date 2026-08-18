import SwiftUI
import UIKit

// MARK: - Ortak Bileşenler
// Tasarımda tekrar eden yapı taşları: köşe şekli, progress bar, çipler,
// FAB, sheet iskeleti, toast, koyu header butonu.

/// Yalnızca seçilen köşeleri yuvarlatan shape (iOS 16'da UnevenRoundedRectangle yok).
struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// 4–6px yüksekliğinde, tam yuvarlak progress bar (ray + dolgu).
struct ProgressBarView: View {
    var fraction: Double            // 0...1
    var fill: Color = Palette.accent
    var track: Color = Palette.track
    var height: CGFloat = 6
    var minFraction: Double = 0.03  // tasarımda min %3 dolgu görünür

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * max(minFraction, min(1, fraction)))
            }
        }
        .frame(height: height)
    }
}

/// Küçük büyük-harf durum çipi (proje durumu, ödeme durumu vb.).
struct StatusChip: View {
    var text: String
    var background: Color
    var foreground: Color
    var fontSize: CGFloat = 10
    var tracking: CGFloat = 0.4
    var uppercased: Bool = true   // Proje durumu çipi tasarımda normal harfle yazılır

    var body: some View {
        Text(text)
            .font(.manrope(fontSize, .extraBold))
            .tracking(tracking)
            .textCase(uppercased ? .uppercase : nil)
            .foregroundColor(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background)
            .cornerRadius(7)
    }
}

/// Malzeme kodu rozeti — 40px yuvarlatılmış kare (Ø12, ÇMT, EPS…).
struct CodeBadge: View {
    var code: String
    var critical: Bool = false
    var size: CGFloat = 40

    var body: some View {
        Text(code)
            .font(.sora(11, .bold))
            .foregroundColor(critical ? Palette.alertInk : Palette.accent)
            .frame(width: size, height: size)
            .background(critical ? Palette.alertTint : Palette.accentTint)
            .cornerRadius(12)
    }
}

/// Sağ altta konumlanan bakır extended FAB ("＋ Yeni Proje" gibi).
struct FloatingActionButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("+").font(.manrope(17, .bold))
                Text(title).font(.manrope(14.5, .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Palette.accent)
            .cornerRadius(16)
            .shadow(color: Palette.accent.opacity(0.38), radius: 13, x: 0, y: 12)
        }
    }
}

/// FAB'ı sağ alta yerleştiren overlay yardımcısı.
extension View {
    func floatingActionButton(_ title: String, visible: Bool = true, action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            if visible {
                FloatingActionButton(title: title, action: action)
                    .padding(.trailing, 18)
                    .padding(.bottom, 12)
            }
        }
    }
}

/// Sheet başlığı: sürükleme çubuğu, başlık + alt başlık, kapat (✕) butonu.
struct SheetHeader: View {
    var title: String
    var subtitle: String? = nil
    var subtitleAccent: String? = nil   // alt başlıkta vurgulanan bölüm (proje adı gibi)
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tutamaç sistemin `.presentationDragIndicator(.visible)` göstergesinden
            // gelir. Buraya bir kapsül daha çizilince üst üste iki tutamaç oluyordu.

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.sora(24, .bold))
                        .foregroundColor(Palette.ink)
                    if let subtitle {
                        subtitleText(subtitle)
                            .font(.manrope(12.5, .medium))
                            .foregroundColor(Palette.textSecondary)
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.textMuted)
                        .frame(width: 40, height: 40)
                        .background(Palette.fillMuted)
                        .cornerRadius(13)
                }
            }
            .padding(.top, 14)
        }
    }

    @ViewBuilder
    private func subtitleText(_ text: String) -> some View {
        if let accent = subtitleAccent, let range = text.range(of: accent) {
            let before = String(text[text.startIndex..<range.lowerBound])
            let after = String(text[range.upperBound...])
            (Text(before)
             + Text(accent).font(.manrope(12.5, .bold)).foregroundColor(Palette.ink)
             + Text(after))
        } else {
            Text(text)
        }
    }
}

/// 52px yüksekliğinde birincil bakır buton.
struct PrimaryButton: View {
    var title: String
    var icon: String? = nil
    var background: Color = Palette.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(.manrope(15, .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .cornerRadius(14)
            .shadow(color: background.opacity(0.28), radius: 10, x: 0, y: 8)
        }
    }
}

/// Kenarlıklı ikincil (outline) buton.
struct OutlineButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                .cornerRadius(13)
        }
    }
}

/// Koyu header üzerindeki 34px yuvarlatılmış kare buton (geri oku vb.).
struct DarkHeaderButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08))
                .cornerRadius(11)
        }
    }
}

// MARK: - Toast

/// Alt kenardan 52px yukarıda beliren onay bildirimi.
/// Bekleyen yazma şeridi. Kehribar ton: hata DEĞİL — veri kaybolmadı, yalnızca
/// henüz gönderilmedi. Kırmızı kullanmak "bir şey bozuldu" derdi ve yanlış olurdu.
struct PendingWritesBar: View {
    var message: String

    var body: some View {
        HStack(spacing: 9) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(Palette.ink)
            Text(message)
                .font(.manrope(12, .semiBold))
                .foregroundColor(Palette.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Palette.amberDot.opacity(0.92))
        .cornerRadius(11)
        .shadow(color: Color(hex: 0x1C1A18, alpha: 0.18), radius: 10, x: 0, y: 5)
        // Toast'ın üstünde kalacak kadar: toast 52pt dipten başlıyor ve
        // ~44pt yüksekliğinde.
        .padding(.bottom, 104)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ToastView: View {
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.whatsapp).frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(message)
                .font(.manrope(12.5, .semiBold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .cornerRadius(14)
        .shadow(color: Color(hex: 0x1C1A18, alpha: 0.34), radius: 17, x: 0, y: 14)
        .padding(.horizontal, 20)
        .padding(.bottom, 52)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension View {
    /// ViewModel'deki toast mesajını ekrana bağlar.
    /// Sunucu onayı bekleyen yazmaların şeridi.
    ///
    /// Toast DEĞİL, bilerek: toast bir OLAY bildirir ve söner; bekleyen yazma
    /// bir DURUM ve kuyruk boşalana kadar ekranda kalmalı. Sönen bir uyarı,
    /// tam da fark edilmesi gereken durumda (kullanıcı ekrana bakmıyorken
    /// bağlantı gitti) işe yaramazdı.
    func pendingWritesOverlay(_ visible: Bool, message: String) -> some View {
        // ALTTA, üstte değil. Üstte denendi ve koyu başlığın üstüne binip
        // bildirim zilini kapattı. Alt kenar zaten uygulamanın bildirim dili
        // (toast orada) ve şerit toast'ın üstünde durup ikisi birlikte
        // okunabiliyor.
        overlay(alignment: .bottom) {
            if visible {
                PendingWritesBar(message: message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: visible)
    }

    func toastOverlay(_ message: String?) -> some View {
        overlay(alignment: .bottom) {
            if let message {
                ToastView(message: message)
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: message)
    }
}

// MARK: - Klavye kapatma

extension View {
    /// Sayısal klavyelerde (decimalPad / numberPad) "return" tuşu yoktur;
    /// kullanıcı klavyeyi kapatamayıp formun altını göremiyordu. Üstüne
    /// "Bitti" çubuğu ekler.
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Bitti") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
                .font(.manrope(15, .bold))
                .foregroundColor(Palette.accent)
            }
        }
    }

    /// Sheet'ler tek sabit yükseklikteydi; küçük ekranda (iPhone SE) alt kısımdaki
    /// butonlar erişilemez kalıyordu. Tasarımdaki yüksekliği korur, tam ekrana
    /// çekilebilmesini de sağlar.
    func sheetHeight(_ fraction: CGFloat) -> some View {
        presentationDetents([.fraction(fraction), .large])
    }
}

// MARK: - Akış yerleşimi (çip grupları için satır kaydırmalı dizilim)

/// Çipleri satıra sığmayınca alta kaydıran basit flow layout (iOS 16 Layout API).
struct FlowLayout: Layout {
    var spacing: CGFloat = 9

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Belirsiz öneride .infinity dönmek yerleşimi bozar; sistem varsayılanına düş.
        let width = proposal.width ?? proposal.replacingUnspecifiedDimensions().width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Kesikli kenarlık

extension View {
    func dashedBorder(_ color: Color = Palette.dashed, radius: CGFloat = 14, lineWidth: CGFloat = 1.5, dash: CGFloat = 5) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: [dash, 4]))
        )
    }
}
