//
//  PlatformImage.swift
//  traders_guild
//
//  One image type for both platforms. `UIImage` on iOS, `NSImage` on macOS,
//  with the handful of constructors and encoders the app actually uses bridged
//  so call sites read the same on either side.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

// MARK: - Constructors

extension PlatformImage {

    /// `PlatformImage(assetNamed:)` rather than `init(named:)` — the two
    /// platforms disagree on the argument type (`String` vs `NSImage.Name`)
    /// and on optionality, so a distinct label keeps call sites unambiguous.
    static func asset(named name: String) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(named: name)
        #else
        return NSImage(named: name)
        #endif
    }

    /// SF Symbol lookup. Used as an availability probe as well as for rendering.
    static func symbol(named name: String) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(systemName: name)
        #else
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        #endif
    }

    static func decoded(from data: Data) -> PlatformImage? {
        PlatformImage(data: data)
    }

    static func loaded(contentsOfFile path: String) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(contentsOfFile: path)
        #else
        return NSImage(contentsOfFile: path)
        #endif
    }
}

// MARK: - Encoding

extension PlatformImage {

    /// JPEG bytes at the given quality (0...1), or nil if the image has no
    /// rasterisable representation.
    func jpegBytes(compressionQuality quality: CGFloat) -> Data? {
        #if canImport(UIKit)
        return jpegData(compressionQuality: quality)
        #else
        guard let rep = bitmapRepresentation else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }

    func pngBytes() -> Data? {
        #if canImport(UIKit)
        return pngData()
        #else
        return bitmapRepresentation?.representation(using: .png, properties: [:])
        #endif
    }

    #if canImport(AppKit) && !canImport(UIKit)
    /// `NSImage` is a container of representations rather than a bitmap, so it
    /// has to be flattened before it can be encoded.
    private var bitmapRepresentation: NSBitmapImageRep? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = size
        return rep
    }
    #endif
}

// MARK: - SwiftUI

extension Image {
    /// Cross-platform replacement for `Image(uiImage:)`.
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
