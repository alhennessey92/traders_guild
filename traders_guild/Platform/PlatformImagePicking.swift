//
//  PlatformImagePicking.swift
//  traders_guild
//
//  macOS image selection.
//
//  iOS keeps UIImagePickerController and PHPickerViewController exactly as they
//  are — that is the shipped behaviour, including `allowsEditing` and the camera
//  path. None of it exists on macOS, where the native equivalent of "choose a
//  picture" is an open panel.
//
//  The views below present that panel and report back through the same callbacks
//  the UIKit wrappers use, so the call sites are identical on both platforms.
//

import SwiftUI
import UniformTypeIdentifiers

/// Where an image is being chosen from. Replaces
/// `UIImagePickerController.SourceType` at call sites so they compile on both
/// platforms; on iOS it maps straight back to the UIKit value.
enum ImagePickerSource {
    case photoLibrary
    case camera
}

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

enum PlatformFilePanel {

    /// Runs a modal open panel restricted to images.
    ///
    /// Modal rather than a sheet because these are presented from SwiftUI
    /// `.sheet` bodies that have no NSWindow to attach to at that point.
    @MainActor
    static func chooseImages(allowsMultipleSelection: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose"
        panel.message = "Choose an image"
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func mimeType(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}

/// Presents the open panel as soon as it appears, then dismisses itself — so a
/// `.sheet { … }` containing it behaves like the iOS picker sheet.
struct MacImageChooser: View {

    let allowsMultipleSelection: Bool
    let onChosen: ([URL]) -> Void
    let onCancel: () -> Void

    @State private var hasRun = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                // .onAppear can fire more than once for the same presentation.
                guard !hasRun else { return }
                hasRun = true
                let urls = PlatformFilePanel.chooseImages(
                    allowsMultipleSelection: allowsMultipleSelection
                )
                if urls.isEmpty { onCancel() } else { onChosen(urls) }
            }
    }
}
#endif
