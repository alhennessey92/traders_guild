//
//  ShareLinkIcon.swift
//  traders_guild
//
//  The app icon as a guaranteed bitmap, for share-sheet link previews.
//

#if canImport(UIKit)
import UIKit

/// The icon `LPLinkMetadata` shows next to a shared link, always backed by a real `CGImage`.
///
/// **Never ask UIKit for the app icon by name here.** The app icon is an Icon Composer
/// asset (`Resources/AppIcon.icon`), and `UIImage(named: "AppIcon")` against one raises
/// `NSInternalInconsistencyException` — "Need an imageRef" — from inside the lookup itself.
/// That is an ObjC assertion, not a nil return, so no Swift `if let` can guard it: the app
/// terminates. It fired while the share sheet built its preview, which is why tapping
/// "More" on a marker (or a guild invite) crashed rather than failing quietly.
///
/// So the icon is loaded from the bundle's own PNG files instead, and every path ends in a
/// drawn tile rather than nothing — a share sheet without an icon is fine, a crash is not.
///
/// This lives in one place because the marker and invite share kits each had their own copy
/// of the unsafe lookup, and the crash therefore existed twice.
enum ShareLinkIcon {
    private static let renderSize = CGSize(width: 96, height: 96)

    /// Always returns a bitmap-backed image.
    static func bitmap() -> UIImage {
        if let candidate = primaryIconFile() ?? composedBundledIcon() {
            let rendered = UIGraphicsImageRenderer(size: renderSize).image { _ in
                candidate.draw(in: CGRect(origin: .zero, size: renderSize))
            }
            if rendered.cgImage != nil { return rendered }
        }
        return fallbackTile()
    }

    // MARK: - Sources

    /// The icon PNG the build writes to the bundle root (`AppIcon60x60@2x.png`), found via
    /// Info.plist rather than the asset catalog.
    private static func primaryIconFile() -> UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String] else {
            return nil
        }
        // Largest last in CFBundleIconFiles, so walk it backwards.
        for name in files.reversed() {
            if let image = bundledPNG(name) { return image }
        }
        return nil
    }

    /// The Icon Composer layers, composited by hand — the fallback when the build has not
    /// emitted a flattened icon PNG.
    private static func composedBundledIcon() -> UIImage? {
        let logo = bundledPNG("TG 6", subdirectory: "AppIcon.icon/Assets")
            ?? bundledPNG("TG 3", subdirectory: "AppIconPreview/Assets")
        let background = bundledPNG("appiconbg 2", subdirectory: "AppIcon.icon/Assets")
            ?? bundledPNG("appiconbg 2", subdirectory: "AppIconPreview/Assets")
        guard logo != nil || background != nil else { return nil }

        return UIGraphicsImageRenderer(size: renderSize).image { _ in
            let rect = CGRect(origin: .zero, size: renderSize)
            background?.draw(in: rect)
            if let logo {
                let inset = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
                logo.draw(in: inset)
            }
        }
    }

    /// Loads a PNG from the bundle by path. `Bundle.url(forResource:)` does not resolve the
    /// `@2x` / `@3x` suffixes that `UIImage(named:)` would, so they are tried explicitly.
    private static func bundledPNG(_ name: String, subdirectory: String? = nil) -> UIImage? {
        for candidate in ["\(name)@3x", "\(name)@2x", name] {
            let url: URL?
            if let subdirectory {
                url = Bundle.main.url(forResource: candidate, withExtension: "png", subdirectory: subdirectory)
                    ?? Bundle.main.url(forResource: candidate, withExtension: "png")
            } else {
                url = Bundle.main.url(forResource: candidate, withExtension: "png")
            }
            if let url,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }

    /// The brand tile, drawn rather than loaded, so this can never fail.
    private static func fallbackTile() -> UIImage {
        UIGraphicsImageRenderer(size: renderSize).image { context in
            let rect = CGRect(origin: .zero, size: renderSize)
            UIBezierPath(roundedRect: rect, cornerRadius: 22).addClip()
            let colors = [
                UIColor(red: 0.08, green: 0.15, blue: 0.30, alpha: 1).cgColor,
                UIColor(red: 0.00, green: 0.72, blue: 0.86, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: renderSize.width, y: renderSize.height),
                    options: []
                )
            }
            let text = "TG" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white,
            ]
            let textSize = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(
                    x: (renderSize.width - textSize.width) / 2,
                    y: (renderSize.height - textSize.height) / 2
                ),
                withAttributes: attrs
            )
        }
    }
}
#endif
