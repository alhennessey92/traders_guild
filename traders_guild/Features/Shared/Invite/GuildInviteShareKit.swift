//
//  GuildInviteShareKit.swift
//  traders_guild
//
//  Shared invite/referral sharing infrastructure used by GuildInviteHubView and
//  every invite surface (post-create, drawer promo, signup step, user list).
//  Extracted from UserListView so there is a single rich-share implementation.
//

import SwiftUI
import UIKit
import LinkPresentation
import UniformTypeIdentifiers
import CoreImage

// MARK: - Share Item

/// The payload shared via the native share sheet and rich-link metadata.
struct GuildInviteShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let guildName: String

    var previewTitle: String { "Join \(guildName)" }

    var previewSubtitle: String {
        "Refer friends to Traders Guild and earn reputation when they join."
    }

    var message: String {
        "Join \(guildName) on Traders Guild. Use my referral link to join the guild and build reputation together: \(url.absoluteString)"
    }
}

// MARK: - Channel intent helpers

enum GuildInviteShare {

    /// The invite text, without the link.
    ///
    /// Telegram's composer takes the body and the link as separate parameters
    /// and renders both, so a URL in here would appear twice; Reddit's title
    /// takes no URL at all. X and the native sheet append it themselves.
    static func inviteBody(guildName: String) -> String {
        "Join my guild \(guildName) on Traders Guild — the social trading platform where communities call the markets together. 📈"
    }

    private static func xComposeText(guildName: String, url: URL) -> String {
        "\(inviteBody(guildName: guildName)) \(url.absoluteString)"
    }

    /// Native X (Twitter) app composer scheme — opens the X app's tweet
    /// composer pre-filled. Used first; falls back to `xComposeURL` (web).
    static func xAppURL(guildName: String, url: URL) -> URL? {
        let text = xComposeText(guildName: guildName, url: url)
        var components = URLComponents()
        components.scheme = "twitter"
        components.host = "post"
        components.queryItems = [URLQueryItem(name: "message", value: text)]
        return components.url
    }

    /// Web composer fallback for X when the app isn't installed.
    static func xComposeURL(guildName: String, url: URL) -> URL? {
        var components = URLComponents(string: "https://x.com/intent/post")
        components?.queryItems = [
            URLQueryItem(name: "text", value: xComposeText(guildName: guildName, url: url)),
        ]
        return components?.url
    }

    /// A Discord-ready, nicely formatted message to paste into a server/channel.
    static func discordMessage(guildName: String, url: URL) -> String {
        """
        **Join \(guildName) on Traders Guild** 📈
        We're calling the markets together on Traders Guild — the social trading platform. Tap to join the guild and build reputation with us:
        \(url.absoluteString)
        """
    }

    /// Native Telegram composer; falls back to `telegramWebURL`.
    ///
    /// `text` and `url` stay separate — Telegram renders the text and then
    /// unfurls the link, so `inviteBody` carries no URL of its own.
    static func telegramAppURL(guildName: String, url: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "tg"
        components.host = "msg_url"
        components.queryItems = telegramQueryItems(guildName: guildName, url: url)
        return components.url
    }

    /// Web fallback; `t.me` is a universal link Telegram claims, so an installed
    /// app still catches it.
    static func telegramWebURL(guildName: String, url: URL) -> URL? {
        var components = URLComponents(string: "https://t.me/share/url")
        components?.queryItems = telegramQueryItems(guildName: guildName, url: url)
        return components?.url
    }

    private static func telegramQueryItems(guildName: String, url: URL) -> [URLQueryItem] {
        [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "text", value: inviteBody(guildName: guildName)),
        ]
    }

    /// Reddit's submit page. A link post is a title plus a URL, no body, so the
    /// invite body doubles as the title (capped at Reddit's 300 characters).
    /// No app scheme: Reddit claims this as a universal link.
    static func redditSubmitURL(guildName: String, url: URL) -> URL? {
        var components = URLComponents(string: "https://www.reddit.com/submit")
        components?.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(
                name: "title",
                value: String(inviteBody(guildName: guildName).prefix(MarkerShare.redditTitleLimit))
            ),
        ]
        return components?.url
    }

    /// Native Discord app scheme (opens the app); used first.
    static var discordAppURL: URL? { URL(string: "discord://") }
    /// Web fallback that opens Discord (app via universal link, else browser).
    static var discordWebURL: URL? { URL(string: "https://discord.com/channels/@me") }

    /// Presents `UIActivityViewController` directly via UIKit.
    ///
    /// Wrapping it in a SwiftUI `.sheet(item:)` wedges the modal layer because
    /// `UIActivityViewController` runs its own presentation lifecycle that races
    /// SwiftUI's — leaving the chart frozen until the app is relaunched.
    /// `onPresented` fires once the sheet is on screen (or immediately if it
    /// can't be presented), so callers can clear any loading indicator.
    @MainActor
    static func presentNativeShareSheet(for item: GuildInviteShareItem, onPresented: (() -> Void)? = nil) {
        let source = GuildInviteActivityItemSource(item: item)
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

    /// Open a URL if the system can handle it (e.g. sms: composer).
    @MainActor
    static func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Try to open a native app via its scheme; if it isn't installed (open
    /// reports failure), fall back to the web URL. `open(_:options:completionHandler:)`
    /// does not require the scheme in LSApplicationQueriesSchemes.
    @MainActor
    static func openAppOrWeb(_ appURL: URL?, fallback webURL: URL?) {
        guard let appURL else { open(webURL); return }
        UIApplication.shared.open(appURL, options: [:]) { success in
            if !success, let webURL {
                UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
            }
        }
    }

    /// Render a QR code image for a URL string (CoreImage `CIQRCodeGenerator`).
    static func qrCode(for string: String, size: CGFloat = 240) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Rich-link Activity Item Source

final class GuildInviteActivityItemSource: NSObject, UIActivityItemSource {
    private let item: GuildInviteShareItem

    init(item: GuildInviteShareItem) {
        self.item = item
        super.init()
    }

    /// A String, not a URL.
    ///
    /// Returning a URL makes UIKit build a rich link preview, which fetches and
    /// renders the remote OG card itself — and that render is what crashed with
    /// "Need an imageRef". The shared payload below still contains the link, so
    /// Discord and X unfurl it exactly as before; only the in-sheet preview
    /// changes, and it is cosmetic.
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        item.message
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
        // No `url`/`originalURL`. Either one hands LinkPresentation the remote
        // page to fetch and render a preview from, which is the crash path —
        // the OG card itself is a valid 1200x630 PNG, so the failure is inside
        // that render, not in what we serve.

        // Register PNG *data*, not a UIImage. The previous guard checked
        // `cgImage != nil` but still handed UIImage to NSItemProvider, which
        // re-serialises it on the share sheet's own terms — and still crashed
        // with "Need an imageRef". Data has no backing-image to lose.
        if let png = ShareLinkIcon.bitmap().pngData() {
            metadata.iconProvider = NSItemProvider(
                item: png as NSData,
                typeIdentifier: UTType.png.identifier,
            )
            // Deliberately no imageProvider: the large preview adds nothing for
            // an invite link and doubles the surface that can fail to render.
        }

        return metadata
    }

}
