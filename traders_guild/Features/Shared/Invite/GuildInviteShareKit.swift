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

    private static func xComposeText(guildName: String, url: URL) -> String {
        "Join my guild \(guildName) on Traders Guild — the social trading platform where communities call the markets together. 📈 \(url.absoluteString)"
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

        // Only attach the preview image if it is bitmap-backed; otherwise
        // LinkPresentation crashes serialising it ("Need an imageRef").
        if let icon = Self.appIconImage(), icon.cgImage != nil {
            let provider = NSItemProvider(object: icon)
            metadata.iconProvider = provider
            metadata.imageProvider = provider
        }

        return metadata
    }

    /// Always returns a freshly-rendered bitmap (guaranteed `cgImage`).
    /// Asset-catalog "AppIcon" / named icons frequently lack a CGImage, which
    /// crashes `LPLinkMetadata`/`NSItemProvider` when the share sheet renders
    /// its preview — so any candidate is re-drawn into a renderer bitmap.
    private static func appIconImage() -> UIImage? {
        guard let candidate = UIImage(named: "AppIcon")
                ?? infoPlistAppIcon()
                ?? composedBundledAppIcon() else {
            return renderedFallbackIcon()
        }

        let size = CGSize(width: 96, height: 96)
        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            candidate.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage != nil ? rendered : renderedFallbackIcon()
    }

    private static func infoPlistAppIcon() -> UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] else {
            return nil
        }
        for name in iconFiles.reversed() {
            if let icon = UIImage(named: name) { return icon }
        }
        return nil
    }

    private static func bundledImage(named name: String, subdirectory: String) -> UIImage? {
        let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: subdirectory
        ) ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url else { return nil }

        return UIImage(contentsOfFile: url.path)
    }

    private static func composedBundledAppIcon() -> UIImage? {
        let logo = bundledImage(named: "TG 6", subdirectory: "AppIcon.icon/Assets")
            ?? bundledImage(named: "TG 3", subdirectory: "AppIconPreview/Assets")
        let background = bundledImage(named: "appiconbg 2", subdirectory: "AppIcon.icon/Assets")
            ?? bundledImage(named: "appiconbg 2", subdirectory: "AppIconPreview/Assets")

        guard logo != nil || background != nil else { return nil }

        let size = CGSize(width: 96, height: 96)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            if let background {
                background.draw(in: rect)
            } else {
                UIColor(red: 0.06, green: 0.11, blue: 0.22, alpha: 1).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 22).fill()
            }

            if let logo {
                let logoWidth = size.width * 0.72
                let logoHeight = logoWidth * (logo.size.height / max(logo.size.width, 1))
                let logoRect = CGRect(
                    x: (size.width - logoWidth) / 2,
                    y: (size.height - logoHeight) / 2 + 7,
                    width: logoWidth,
                    height: logoHeight
                )
                logo.draw(in: logoRect)
            }
        }
    }

    private static func renderedFallbackIcon() -> UIImage {
        let size = CGSize(width: 96, height: 96)
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 22)
            path.addClip()

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
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            let text = "TG" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor.white,
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2
                ),
                withAttributes: attributes
            )
        }
    }
}
