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

    /// Shown before an author chooses an external destination. Keep this copy
    /// explicit: the durable link and preview leave the guild boundary and can
    /// be retained by the receiving service or its users.
    static let externalSharingDisclosure =
        "X, Discord, Copy link and More make this marker card, your profile handle and guild name public outside Traders Guild. Other services may retain or reshare it."

    /// Guild-visible markers can be forwarded to another member inside the app.
    /// Private markers remain visible only to their author and must not expose a
    /// share surface.
    static func canShareWithinGuild(visibility: String) -> Bool {
        visibility.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("guild") == .orderedSame
    }

    /// Public/external channels publish a durable marker link, so they require
    /// both guild visibility and the marker author's consent.
    static func canShareExternally(isCurrentUserMarker: Bool, visibility: String) -> Bool {
        isCurrentUserMarker && canShareWithinGuild(visibility: visibility)
    }

    /// Accept only the capability URL issued by chart-service for this marker.
    /// Constructing a URL from the UUID would bypass the author's server-side
    /// consent boundary, so all external destinations go through this guard.
    static func validatedServerShareURL(_ rawValue: String, markerId: UUID) -> URL? {
        var allowedHosts: Set<String> = ["tradersguild.co"]
        #if DEBUG
        // Staging issues capabilities for its own public origin. Never admit an
        // arbitrary API response host, even in a debug build.
        allowedHosts.insert("api-dev.tradersguild.co")
        #endif

        guard let components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              allowedHosts.contains(host),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              components.path.lowercased() == "/marker/\(markerId.uuidString.lowercased())",
              let items = components.queryItems,
              items.count == 1,
              items[0].name == "share_token",
              let token = items[0].value,
              token.count == 43,
              token.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
              }) else {
            return nil
        }
        return components.url
    }

    static func markerCustomSchemeURL(markerId: UUID) -> URL? {
        URL(string: "tradersguild://marker/\(markerId.uuidString.lowercased())")
    }

    /// Human-readable price, matching how the marker reads on the chart.
    static func formattedPrice(_ price: Double?) -> String? {
        guard let price, price.isFinite else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        // Match the chart's precision bands so FX doesn't round to nothing.
        formatter.maximumFractionDigits = abs(price) >= 1000 ? 2 : (abs(price) >= 1 ? 4 : 8)
        return formatter.string(from: NSNumber(value: price))
    }

    /// The headline a marker leads with — "BTCUSD setup at 67,250.12".
    /// Falls back gracefully as each piece of context goes missing.
    static func shareHeadline(symbolTicker: String?, intent: String?, price: Double?) -> String {
        let ticker = symbolTicker?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let intentWord = intent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let priceText = formattedPrice(price)

        var headline = ticker.isEmpty ? "my latest marker" : ticker
        if !ticker.isEmpty, !intentWord.isEmpty, intentWord != "personal" {
            headline += " \(intentWord)"
        }
        if !ticker.isEmpty, let priceText {
            headline += " at \(priceText)"
        }
        return headline
    }

    private static func xComposeText(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil
    ) -> String {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCaption.isEmpty {
            return "\(trimmedCaption) \(url.absoluteString)"
        }
        let headline = shareHeadline(symbolTicker: symbolTicker, intent: intent, price: price)
        return "Just dropped \(headline) on Traders Guild — the social trading platform where guilds call the markets together. 📈 \(url.absoluteString)"
    }

    /// Native X app composer scheme; falls back to `xComposeURL` (web).
    /// `caption` is the optional user-written message (further editable in X).
    static func xAppURL(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil
    ) -> URL? {
        let text = xComposeText(
            symbolTicker: symbolTicker,
            caption: caption,
            url: url,
            intent: intent,
            price: price
        )
        var components = URLComponents()
        components.scheme = "twitter"
        components.host = "post"
        components.queryItems = [URLQueryItem(name: "message", value: text)]
        return components.url
    }

    /// Web composer fallback for X when the app isn't installed.
    static func xComposeURL(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil
    ) -> URL? {
        var components = URLComponents(string: "https://x.com/intent/post")
        components?.queryItems = [
            URLQueryItem(
                name: "text",
                value: xComposeText(
                    symbolTicker: symbolTicker,
                    caption: caption,
                    url: url,
                    intent: intent,
                    price: price
                )
            ),
        ]
        return components?.url
    }

    /// A Discord-ready, formatted message to paste into a channel.
    ///
    /// Used when the guild hasn't connected a webhook — with one connected the
    /// marker is posted directly instead (see `shareMarkerToDiscord`).
    static func discordMessage(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil
    ) -> String {
        let headline = shareHeadline(symbolTicker: symbolTicker, intent: intent, price: price)
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lead = trimmedCaption.isEmpty
            ? "Called it on Traders Guild — the social trading platform where guilds call the markets together."
            : trimmedCaption
        return """
        **\(headline.prefix(1).uppercased() + headline.dropFirst()) on Traders Guild** 📈
        \(lead)
        \(url.absoluteString)
        """
    }

    /// Native Discord app scheme, then the web fallback.
    static var discordAppURL: URL? { GuildInviteShare.discordAppURL }
    static var discordWebURL: URL? { GuildInviteShare.discordWebURL }

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

// MARK: - Deep-link failure copy

struct MarkerDeepLinkFailureCopy: Equatable {
    let title: String
    let message: String

    static func terminalFailure(forHTTPStatus statusCode: Int) -> Self? {
        switch statusCode {
        case 403:
            return Self(
                title: "Marker Access Required",
                message: "Join the marker’s guild to view it."
            )
        case 404:
            return Self(
                title: "Marker Unavailable",
                message: "That marker is no longer available."
            )
        default:
            return nil
        }
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
