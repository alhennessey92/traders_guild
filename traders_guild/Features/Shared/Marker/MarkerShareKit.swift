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
        "X, Discord, Reddit, Telegram, Copy link and More make this marker card, your profile handle and guild name public outside Traders Guild. Other services may retain or reshare it."

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

    /// Currencies, metals and energy are searched as a whole pair on X
    /// ($EURUSD, $XAUUSD); crypto is searched by the coin ($BTC, not $BTCUSD).
    private static let pairBases: Set<String> = [
        "USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF", "CNH", "SEK", "NOK", "MXN",
        "XAU", "XAG", "XPT", "XPD", "BCO", "WTI", "NATGAS", "COPPER",
    ]

    /// The `$TAG` for an instrument, or nil when it wouldn't be a useful one.
    ///
    /// A cashtag is a real searchable entity on X, so a shared marker carrying
    /// one reaches people following the instrument rather than only the author's
    /// followers. Mirrors `shared/services/cashtags.py` in the backend and
    /// `Cashtags.kt` on Android — change one, change all three.
    static func cashtag(_ symbolTicker: String?) -> String? {
        let raw = (symbolTicker ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "$", with: "")
        guard !raw.isEmpty else { return nil }

        let parts = raw.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let base = String(parts.first ?? "")
        let quote = parts.count > 1 ? String(parts[1]) : ""

        let tag: String
        if quote.isEmpty {
            tag = base
        } else if pairBases.contains(base) {
            tag = base + quote
        } else {
            tag = base
        }

        guard !tag.isEmpty, tag.count <= 12,
              tag.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return "$" + tag
    }

    /// How a resolved setup is named in post copy — "hit target", "stopped out".
    ///
    /// Mirrors the backend's `_outcome_phrase`, which writes the same words onto
    /// the card and the landing page. Change one, change both.
    static func outcomePhrase(_ outcome: SetupOutcome?) -> String? {
        guard let outcome, outcome.isWin || outcome.isLoss else { return nil }
        var phrase = outcome.isWin ? "hit target" : "stopped out"
        if let pnl = outcome.pnl {
            phrase += String(format: " %@%.2f%%", pnl >= 0 ? "+" : "", pnl)
        }
        return phrase
    }

    /// The headline a marker leads with — "BTCUSD setup at 67,250.12".
    /// Falls back gracefully as each piece of context goes missing.
    static func shareHeadline(
        symbolTicker: String?,
        intent: String?,
        price: Double?,
        outcome: SetupOutcome? = nil
    ) -> String {
        // The cashtag is what makes the post findable; fall back to the plain
        // ticker when the instrument doesn't yield a usable one.
        let ticker = cashtag(symbolTicker)
            ?? (symbolTicker?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
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

    /// The post text, without the link.
    ///
    /// Split out from `xComposeText` because not every destination wants the URL
    /// inline. Telegram's composer takes the body and the link as *separate*
    /// parameters and renders both, so a URL in here would appear twice. X and
    /// the native share sheet append it; Telegram passes it alongside.
    static func shareBody(
        symbolTicker: String?,
        caption: String?,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> String {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCaption.isEmpty {
            // The author's own words lead; the cashtag rides along so the post
            // is still findable, unless they already used it themselves.
            var lead = trimmedCaption
            if let tag = cashtag(symbolTicker),
               !trimmedCaption.uppercased().contains(tag.uppercased()) {
                lead += " \(tag)"
            }
            return lead
        }
        // A resolved setup is the one post worth writing differently: it has a
        // result, so it reads as a call that landed rather than an idea posted.
        if let verdict = outcomePhrase(outcome) {
            let tag = cashtag(symbolTicker)
                ?? (symbolTicker?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            let called = tag.isEmpty ? "Called this level" : "Called \(tag) off this level"
            return "\(called) — \(verdict). Traders Guild 📈"
        }
        let headline = shareHeadline(symbolTicker: symbolTicker, intent: intent, price: price)
        // The unfurled card already brands and explains the product, so the
        // post spends its characters on the trade, not on a tagline.
        return "Just marked \(headline) on Traders Guild 📈"
    }

    private static func xComposeText(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> String {
        let body = shareBody(
            symbolTicker: symbolTicker,
            caption: caption,
            intent: intent,
            price: price,
            outcome: outcome
        )
        return "\(body) \(url.absoluteString)"
    }

    /// Native X app composer scheme; falls back to `xComposeURL` (web).
    /// `caption` is the optional user-written message (further editable in X).
    static func xAppURL(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> URL? {
        let text = xComposeText(
            symbolTicker: symbolTicker,
            caption: caption,
            url: url,
            intent: intent,
            price: price,
            outcome: outcome
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
        price: Double? = nil,
        outcome: SetupOutcome? = nil
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
                    price: price,
                    outcome: outcome
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
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> String {
        var headline = shareHeadline(symbolTicker: symbolTicker, intent: intent, price: price)
        // The attached card shows the result too, but the bolded line is what
        // people read in the channel list, so it carries it as well.
        if let verdict = outcomePhrase(outcome) {
            headline += " — \(verdict)"
        }
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lead = trimmedCaption.isEmpty
            ? "Shared from my chart on Traders Guild."
            : trimmedCaption
        return """
        **\(headline.prefix(1).uppercased() + headline.dropFirst()) on Traders Guild** 📈
        \(lead)
        \(url.absoluteString)
        """
    }

    // MARK: Telegram

    /// Native Telegram composer; falls back to `telegramWebURL`.
    ///
    /// `text` and `url` are deliberately separate: Telegram renders the text and
    /// then unfurls the link, so `shareBody` carries no URL of its own.
    static func telegramAppURL(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "tg"
        components.host = "msg_url"
        components.queryItems = telegramQueryItems(
            symbolTicker: symbolTicker,
            caption: caption,
            url: url,
            intent: intent,
            price: price,
            outcome: outcome
        )
        return components.url
    }

    /// Web composer fallback; `t.me` is a universal link Telegram claims, so an
    /// installed app still catches it.
    static func telegramWebURL(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> URL? {
        var components = URLComponents(string: "https://t.me/share/url")
        components?.queryItems = telegramQueryItems(
            symbolTicker: symbolTicker,
            caption: caption,
            url: url,
            intent: intent,
            price: price,
            outcome: outcome
        )
        return components?.url
    }

    private static func telegramQueryItems(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String?,
        price: Double?,
        outcome: SetupOutcome?
    ) -> [URLQueryItem] {
        [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(
                name: "text",
                value: shareBody(
                    symbolTicker: symbolTicker,
                    caption: caption,
                    intent: intent,
                    price: price,
                    outcome: outcome
                )
            ),
        ]
    }

    // MARK: Reddit

    /// Reddit's own ceiling for a post title.
    static let redditTitleLimit = 300

    /// A Reddit link post carries a title and a URL — there is no body — so the
    /// title is the whole message. `shareBody` already reads as one and already
    /// names the product, so it is reused rather than given its own copy to
    /// drift from.
    static func redditTitle(
        symbolTicker: String?,
        caption: String?,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> String {
        let body = shareBody(
            symbolTicker: symbolTicker,
            caption: caption,
            intent: intent,
            price: price,
            outcome: outcome
        )
        return String(body.prefix(redditTitleLimit))
    }

    /// Reddit's submit page. No app scheme: Reddit claims this as a universal
    /// link, so an installed app catches it and a browser handles it otherwise.
    static func redditSubmitURL(
        symbolTicker: String?,
        caption: String?,
        url: URL,
        intent: String? = nil,
        price: Double? = nil,
        outcome: SetupOutcome? = nil
    ) -> URL? {
        var components = URLComponents(string: "https://www.reddit.com/submit")
        components?.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(
                name: "title",
                value: redditTitle(
                    symbolTicker: symbolTicker,
                    caption: caption,
                    intent: intent,
                    price: price,
                    outcome: outcome
                )
            ),
        ]
        return components?.url
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
