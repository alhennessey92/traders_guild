//
//  MarkerShareKit.swift
//  traders_guild
//
//  Marker-sharing analogue of GuildInviteShareKit: builds the shareable marker
//  deep link, X (Twitter) composer URLs, and the native share sheet for a placed
//  marker. Reuses GuildInviteShare for the generic open/openAppOrWeb helpers.
//

import SwiftUI
import UIKit
import LinkPresentation

// MARK: - Share Item

/// Payload shared via the native share sheet / rich-link metadata for a marker.
struct MarkerShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let symbolTicker: String?
    /// Optional user-written caption; when present it leads the shared text.
    var caption: String? = nil

    var previewTitle: String {
        if let symbolTicker, !symbolTicker.isEmpty {
            return "\(symbolTicker) marker on Traders Guild"
        }
        return "Marker on Traders Guild"
    }

    var message: String {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCaption.isEmpty {
            return "\(trimmedCaption) \(url.absoluteString)"
        }
        let subject = (symbolTicker.map { "my \($0) marker" }) ?? "my marker"
        return "Check out \(subject) on Traders Guild — the social trading platform where guilds call the markets together. 📈 \(url.absoluteString)"
    }
}

// MARK: - Channel intent helpers

enum MarkerShare {

    /// Universal/deep link that opens the specific marker in-app. The `https`
    /// form opens the app via `applinks` (once the entitlement + AASA are live)
    /// and is safe to paste anywhere; the `tradersguild://marker/<id>` custom
    /// scheme opens it in all builds.
    static func markerShareURL(markerId: UUID) -> URL {
        URL(string: "https://tradersguild.co/marker/\(markerId.uuidString.lowercased())")!
    }

    static func markerCustomSchemeURL(markerId: UUID) -> URL? {
        URL(string: "tradersguild://marker/\(markerId.uuidString.lowercased())")
    }

    private static func xComposeText(symbolTicker: String?, caption: String?, url: URL) -> String {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCaption.isEmpty {
            return "\(trimmedCaption) \(url.absoluteString)"
        }
        let subject = (symbolTicker.map { "my \($0) marker" }) ?? "my latest marker"
        return "Just dropped \(subject) on Traders Guild — the social trading platform where guilds call the markets together. 📈 \(url.absoluteString)"
    }

    /// Native X app composer scheme; falls back to `xComposeURL` (web).
    /// `caption` is the optional user-written message (further editable in X).
    static func xAppURL(symbolTicker: String?, caption: String?, url: URL) -> URL? {
        let text = xComposeText(symbolTicker: symbolTicker, caption: caption, url: url)
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        return URL(string: "twitter://post?message=\(encoded)")
    }

    /// Web composer fallback for X when the app isn't installed.
    static func xComposeURL(symbolTicker: String?, caption: String?, url: URL) -> URL? {
        var components = URLComponents(string: "https://x.com/intent/post")
        components?.queryItems = [
            URLQueryItem(name: "text", value: xComposeText(symbolTicker: symbolTicker, caption: caption, url: url)),
        ]
        return components?.url
    }

    /// Presents `UIActivityViewController` for a marker. Mirrors
    /// `GuildInviteShare.presentNativeShareSheet` — UIKit presentation avoids the
    /// SwiftUI `.sheet(item:)` modal-layer wedge documented there.
    @MainActor
    static func presentNativeShareSheet(for item: MarkerShareItem, onPresented: (() -> Void)? = nil) {
        let source = MarkerShareActivityItemSource(item: item)
        let activityVC = UIActivityViewController(activityItems: [source], applicationActivities: nil)

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
              let rootVC = window.rootViewController else {
            onPresented?()
            return
        }

        var presenter = rootVC
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true) { onPresented?() }
    }
}

// MARK: - Rich-link Activity Item Source

final class MarkerShareActivityItemSource: NSObject, UIActivityItemSource {
    private let item: MarkerShareItem

    init(item: MarkerShareItem) {
        self.item = item
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        item.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        item.message
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        item.previewTitle
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = item.previewTitle
        metadata.originalURL = item.url
        metadata.url = item.url

        // Only attach a bitmap-backed icon; a non-bitmap image crashes
        // LinkPresentation ("Need an imageRef") — same guard as the invite kit.
        if let icon = Self.appIconBitmap(), icon.cgImage != nil {
            let provider = NSItemProvider(object: icon)
            metadata.iconProvider = provider
            metadata.imageProvider = provider
        }
        return metadata
    }

    /// Re-draws the app icon into a guaranteed-bitmap image (asset-catalog icons
    /// frequently lack a CGImage). Falls back to a rendered "TG" tile.
    private static func appIconBitmap() -> UIImage? {
        let size = CGSize(width: 96, height: 96)
        if let candidate = UIImage(named: "AppIcon") {
            let rendered = UIGraphicsImageRenderer(size: size).image { _ in
                candidate.draw(in: CGRect(origin: .zero, size: size))
            }
            if rendered.cgImage != nil { return rendered }
        }
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
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
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            let text = "TG" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white,
            ]
            let ts = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2),
                withAttributes: attrs
            )
        }
    }
}
