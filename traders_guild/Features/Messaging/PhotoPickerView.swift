import SwiftUI
import PhotosUI

// MARK: - ================================================================================================
// MARK: - PHOTO PICKER VIEW
// MARK: - ================================================================================================

/// SwiftUI wrapper around PHPickerViewController for selecting photos from the library.
/// Returns selected image data and filename to the caller via onImagesSelected callback.
#if canImport(UIKit)

struct PhotoPickerView: UIViewControllerRepresentable {
    let onImagesSelected: ([(Data, String, String)]) -> Void  // [(imageData, filename, mimeType)]
    let onCancel: () -> Void
    var selectionLimit: Int = 10

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImagesSelected: onImagesSelected,
            onCancel: onCancel,
            selectionLimit: selectionLimit
        )
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagesSelected: ([(Data, String, String)]) -> Void
        let onCancel: () -> Void
        let selectionLimit: Int

        init(
            onImagesSelected: @escaping ([(Data, String, String)]) -> Void,
            onCancel: @escaping () -> Void,
            selectionLimit: Int
        ) {
            self.onImagesSelected = onImagesSelected
            self.onCancel = onCancel
            self.selectionLimit = selectionLimit
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Do NOT call picker.dismiss() here — SwiftUI manages dismissal
            // via the fullScreenCover binding. Calling dismiss on the UIKit
            // controller conflicts with SwiftUI and can cascade-dismiss the
            // parent sheet.
            let selectedResults = Array(results.prefix(selectionLimit))
            guard !selectedResults.isEmpty else {
                onCancel()
                return
            }

            let lock = NSLock()
            let group = DispatchGroup()
            var payloads: [(Data, String, String)] = []

            for result in selectedResults {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage,
                          let data = image.jpegBytes(compressionQuality: 0.85) else {
                        return
                    }
                    let baseName = provider.suggestedName ?? "photo_\(UUID().uuidString.prefix(8))"
                    lock.lock()
                    payloads.append((data, "\(baseName).jpg", "image/jpeg"))
                    lock.unlock()
                }
            }

            group.notify(queue: .main) { [weak self] in
                guard let self else { return }
                if payloads.isEmpty {
                    self.onCancel()
                } else {
                    self.onImagesSelected(payloads)
                }
            }
        }
    }
}

#else

/// macOS counterpart to the PHPicker sheet. Reads the chosen files straight off
/// disk and reports the same (data, filename, mimeType) tuples the iOS coordinator
/// produces, so `appendAttachments` is unchanged.
struct PhotoPickerView: View {

    let onImagesSelected: ([(Data, String, String)]) -> Void
    let onCancel: () -> Void
    var selectionLimit: Int = 10

    var body: some View {
        MacImageChooser(
            allowsMultipleSelection: selectionLimit != 1,
            onChosen: { urls in
                let picked = urls.prefix(selectionLimit).compactMap { url -> (Data, String, String)? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return (data, url.lastPathComponent, PlatformFilePanel.mimeType(for: url))
                }
                if picked.isEmpty { onCancel() } else { onImagesSelected(picked) }
            },
            onCancel: onCancel
        )
    }
}

#endif
