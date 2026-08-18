import QuickLook
import SwiftUI

// MARK: - Belge önizleme (madde 23)
//
// Projedeki İLK önizleme yüzeyi. Bugüne dek "İndir" düğmesi yalnızca
// `flash("… indiriliyor")` diyordu — hiçbir şey inmiyor, hiçbir şey açılmıyordu.
//
// QuickLook seçildi çünkü PDF, DWG, resim, Office dosyaları ve daha fazlasını
// tek yüzeyle açıyor ve paylaşma/yazdırma düğmelerini kendisi getiriyor;
// alternatifi her tür için ayrı görüntüleyici yazmaktı.
//
// DOSYA ADI ÖNEMLİ: QuickLook türü UZANTIDAN çözüyor. Depodaki kopya `.bin`
// soneki taşıdığı için `DocumentStore.previewURL` dosyayı gerçek adıyla geçici
// dizine kopyalıyor; uzantısız verilse "bilinmeyen belge" olarak açılırdı.

struct DocumentPreview: UIViewControllerRepresentable {

    let url: URL
    var onDismiss: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url, onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        context.coordinator.url = url
        (controller.viewControllers.first as? QLPreviewController)?.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var url: URL
        let onDismiss: () -> Void

        init(url: URL, onDismiss: @escaping () -> Void) {
            self.url = url
            self.onDismiss = onDismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            onDismiss()
        }
    }
}
