import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)

struct SharedImagePicker: UIViewControllerRepresentable {
    let sourceType: ImagePickerSource
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        let requested: UIImagePickerController.SourceType = (sourceType == .camera) ? .camera : .photoLibrary
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(requested) ? requested : .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: SharedImagePicker

        init(_ parent: SharedImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImagePicked(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImagePicked(originalImage)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#else

/// macOS has no UIImagePickerController. `.camera` has no equivalent either —
/// Continuity Camera is a text-field affordance, not a picker — so both sources
/// resolve to choosing a file.
struct SharedImagePicker: View {

    let sourceType: ImagePickerSource
    let onImagePicked: (PlatformImage) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MacImageChooser(
            allowsMultipleSelection: false,
            onChosen: { urls in
                if let url = urls.first,
                   let image = PlatformImage(contentsOf: url) {
                    onImagePicked(image)
                }
                dismiss()
            },
            onCancel: { dismiss() }
        )
    }
}

#endif
