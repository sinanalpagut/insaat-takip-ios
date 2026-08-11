import SwiftUI
import UIKit

// MARK: - Kamera Köprüsü
// SwiftUI'de yerleşik kamera görünümü yok; fiş/irsaliye fotoğraflamak için
// UIImagePickerController sarmalanır. Çekilen kare, saklanmadan önce
// SitePhoto.thumbnailSide boyutuna indirgenir (bellek koruması).

struct CameraPicker: UIViewControllerRepresentable {
    /// Çekim tamamlanınca küçültülmüş görseli verir.
    var onCapture: (UIImage) -> Void

    /// Cihazda kamera var mı? (Simülatörde yok — çağıran taraf galeriye düşer.)
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = CameraPicker.isAvailable ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (UIImage) -> Void
        @Environment(\.dismiss) private var dismiss

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            defer { picker.dismiss(animated: true) }
            guard let original = info[.originalImage] as? UIImage else { return }
            onCapture(CameraPicker.downsampled(original))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    /// Tam çözünürlüklü kareyi ekran için yeterli boyuta indirger.
    static func downsampled(_ image: UIImage) -> UIImage {
        let side = SitePhoto.thumbnailSide
        let longest = max(image.size.width, image.size.height)
        guard longest > side else { return image }

        let scale = side / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
