import SwiftUI
import UniformTypeIdentifiers

// MARK: - ================================================================================================
// MARK: - DOCUMENT PICKER VIEW
// MARK: - ================================================================================================

/// SwiftUI wrapper around UIDocumentPickerViewController for selecting files.
/// Returns selected file data, filename, and MIME type to the caller.
struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentsSelected: ([(Data, String, String)]) -> Void  // [(fileData, filename, mimeType)]
    let onCancel: () -> Void
    var selectionLimit: Int = 10

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
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDocumentsSelected: onDocumentsSelected,
            onCancel: onCancel,
            selectionLimit: selectionLimit
        )
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentsSelected: ([(Data, String, String)]) -> Void
        let onCancel: () -> Void
        let selectionLimit: Int

        init(
            onDocumentsSelected: @escaping ([(Data, String, String)]) -> Void,
            onCancel: @escaping () -> Void,
            selectionLimit: Int
        ) {
            self.onDocumentsSelected = onDocumentsSelected
            self.onCancel = onCancel
            self.selectionLimit = selectionLimit
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let selectedURLs = Array(urls.prefix(selectionLimit))
            guard !selectedURLs.isEmpty else {
                onCancel()
                return
            }

            var payloads: [(Data, String, String)] = []
            for url in selectedURLs {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: url)
                    payloads.append((data, url.lastPathComponent, mimeTypeForExtension(url.pathExtension)))
                } catch {
                    continue
                }
            }

            DispatchQueue.main.async {
                if payloads.isEmpty {
                    self.onCancel()
                } else {
                    self.onDocumentsSelected(payloads)
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
