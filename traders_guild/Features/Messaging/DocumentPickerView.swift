import SwiftUI
import UniformTypeIdentifiers

// MARK: - ================================================================================================
// MARK: - DOCUMENT PICKER VIEW
// MARK: - ================================================================================================

/// SwiftUI wrapper around UIDocumentPickerViewController for selecting files.
/// Returns selected file data, filename, and MIME type to the caller.
struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentSelected: (Data, String, String) -> Void  // (fileData, filename, mimeType)
    let onCancel: () -> Void

    /// Supported document types
    private let supportedTypes: [UTType] = [
        .pdf,
        .plainText,
        .png,
        .jpeg,
        .webP,
        .gif,
        .zip,
    ]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentSelected: onDocumentSelected, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentSelected: (Data, String, String) -> Void
        let onCancel: () -> Void

        init(onDocumentSelected: @escaping (Data, String, String) -> Void, onCancel: @escaping () -> Void) {
            self.onDocumentSelected = onDocumentSelected
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }

            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                onCancel()
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let mimeType = mimeTypeForExtension(url.pathExtension)
                DispatchQueue.main.async {
                    self.onDocumentSelected(data, filename, mimeType)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onCancel()
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        private func mimeTypeForExtension(_ ext: String) -> String {
            switch ext.lowercased() {
            case "pdf": return "application/pdf"
            case "txt": return "text/plain"
            case "png": return "image/png"
            case "jpg", "jpeg": return "image/jpeg"
            case "webp": return "image/webp"
            case "gif": return "image/gif"
            case "zip": return "application/zip"
            default: return "application/octet-stream"
            }
        }
    }
}
