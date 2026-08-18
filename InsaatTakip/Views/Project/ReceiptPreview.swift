import SwiftUI

// MARK: - Fiş / dekont tam ekran önizlemesi (madde 17)
//
// Üç ekran aynı şeyi istiyor: malzeme fişi (MaterialLogSheet), gider fişi
// (ExpensesTabView) ve tahsilat dekontu (ApartmentDetailSheet). Tek yerde
// durması bir üslup tercihi değil: dekont ekranı sonradan eklenirken siyah
// zemin/kapat düğmesi yeniden yazılsaydı, gizlilik kapısının da yeniden
// yazılması gerekirdi ve unutulan bir kapı sızıntı demek.

/// Tam ekranda gösterilecek görsel.
struct SharePayloadImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ReceiptPreviewModifier: ViewModifier {
    @Binding var payload: SharePayloadImage?

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $payload) { item in
            // ZStack hizası tüm çocuklara uygulandığı için görsel üste
            // yapışıyordu; görsel ortalanır, kapat butonu ayrı bir overlay.
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    payload = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(20)
            }
        }
    }
}

extension View {
    /// Fiş/dekont görselini tam ekranda açar.
    func receiptPreview(_ payload: Binding<SharePayloadImage?>) -> some View {
        modifier(ReceiptPreviewModifier(payload: payload))
    }
}
