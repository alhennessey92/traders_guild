import SwiftUI
import PhotosUI

// MARK: - ================================================================================================
// MARK: - PHOTO PICKER VIEW
// MARK: - ================================================================================================

/// SwiftUI wrapper around PHPickerViewController for selecting photos from the library.
/// Returns selected image data and filename to the caller via onImageSelected callback.
struct PhotoPickerView: UIViewControllerRepresentable {
    let onImageSelected: (Data, String, String) -> Void  // (imageData, filename, mimeType)
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (Data, String, String) -> Void
        let onCancel: () -> Void

        init(onImageSelected: @escaping (Data, String, String) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8) else {
                    DispatchQueue.main.async { self?.onCancel() }
                    return
                }

                let filename = provider.suggestedName ?? "photo_\(UUID().uuidString.prefix(8))"
                DispatchQueue.main.async {
                    self?.onImageSelected(data, "\(filename).jpg", "image/jpeg")
                }
            }
        }
    }
}
