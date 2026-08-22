import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

// MARK: - ================================================================================================
// MARK: - DOCUMENT PICKER VIEW
// MARK: - ================================================================================================

/// SwiftUI wrapper around UIDocumentPickerViewController for selecting files.
/// Returns selected file data, filename, and MIME type to the caller.
#if canImport(UIKit)
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
#else
/// macOS counterpart to UIDocumentPickerViewController. The panel is launched
/// from a one-point SwiftUI view so existing sheet call sites stay unchanged.
struct DocumentPickerView: View {
    let onDocumentsSelected: ([(Data, String, String)]) -> Void
    let onCancel: () -> Void
    var selectionLimit: Int = 10

    @State private var hasRun = false

    private let supportedTypes: [UTType] = [
        .pdf,
        .plainText,
        .png,
        .jpeg,
        .webP,
        .gif,
        .zip,
    ]

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                guard !hasRun else { return }
                hasRun = true

                let panel = NSOpenPanel()
                panel.allowedContentTypes = supportedTypes
                panel.allowsMultipleSelection = true
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.prompt = "Choose"
                panel.message = "Choose files"

                guard panel.runModal() == .OK else {
                    onCancel()
                    return
                }

                let payloads = panel.urls.prefix(selectionLimit).compactMap {
                    url -> (Data, String, String)? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return (data, url.lastPathComponent, mimeTypeForExtension(url.pathExtension))
                }

                if payloads.isEmpty {
                    onCancel()
                } else {
                    onDocumentsSelected(payloads)
                }
            }
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
#endif
