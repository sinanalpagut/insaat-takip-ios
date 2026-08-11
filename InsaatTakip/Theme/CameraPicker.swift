import SwiftUI
import UIKit

// MARK: - Kamera Köprüsü
// SwiftUI'de yerleşik kamera görünümü yok; fiş/irsaliye ve daire görsellerini
// çekmek için UIImagePickerController sarmalanır. Çekilen kare, saklanmadan
// önce SitePhoto.thumbnailSide boyutuna indirgenir (bellek koruması).
//
// ÖNEMLİ: Sunumu yalnızca SwiftUI yönetir. Burada picker.dismiss() ÇAĞRILMAZ —
// üst görünüm zaten fullScreenCover'ı kapatıyor; ikisi birlikte çalışınca
// kapatma zinciri yukarı taşıyor ve fişi giren sayfa da kapanıyordu.

struct CameraPicker: UIViewControllerRepresentable {
    /// Çekim tamamlanınca küçültülmüş görseli verir. Üst görünüm sunumu kapatır.
    var onCapture: (UIImage) -> Void
    /// Kullanıcı vazgeçtiğinde çağrılır; üst görünüm sunumu kapatır.
    var onCancel: () -> Void

    /// Cihazda gerçek kamera var mı?
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        #if targetEnvironment(simulator)
        // Simülatörün kamerası yalnızca önizleme stub'ı — deklanşör kare üretmiyor.
        // Akışın test edilebilmesi için galeriye düşülür.
        picker.sourceType = .photoLibrary
        #else
        picker.sourceType = CameraPicker.isAvailable ? .camera : .photoLibrary
        #endif
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // .editedImage yalnızca allowsEditing açıkken gelir; ikisi de yoksa iptal say.
            guard let original = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) else {
                onCancel()
                return
            }
            onCapture(CameraPicker.downsampled(original))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }

    /// Tam çözünürlüklü kareyi ekran için yeterli boyuta indirger.
    static func downsampled(_ image: UIImage) -> UIImage {
        let side = SitePhoto.thumbnailSide
        let longest = max(image.size.width, image.size.height)
        guard longest > side, longest > 0 else { return image }

        let scale = side / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
