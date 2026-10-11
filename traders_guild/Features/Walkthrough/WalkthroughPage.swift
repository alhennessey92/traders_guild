//
//  WalkthroughPage.swift
//  traders_guild
//
//  The five pages of the first-run walkthrough, in order.
//

import Foundation
import CoreGraphics

/// One page of the walkthrough shown once after account creation (and on demand
/// from Settings). Copy lives here; media is looked up by `slot`, so replacing a
/// clip is a file swap — see `launch_assets/walkthrough/README.md`.
enum WalkthroughPage: Int, CaseIterable, Identifiable {
    case hero
    case placeMarker
    case trackedSetup
    case respondChat
    case guild

    var id: Int { rawValue }

    /// Asset slot: `walkthrough_<slot>.mp4` and `walkthrough_<slot>_poster.jpg`.
    var slot: String {
        switch self {
        case .hero: return "hero"
        case .placeMarker: return "place_marker"
        case .trackedSetup: return "tracked_setup"
        case .respondChat: return "respond_chat"
        case .guild: return "guild"
        }
    }

    var title: String {
        switch self {
        case .hero: return "One chart. Your whole guild."
        case .placeMarker: return "Mark your call."
        case .trackedSetup: return "Let the chart keep score."
        case .respondChat: return "Respond, discuss, decide."
        case .guild: return "Build a guild. Build a reputation."
        }
    }

    var body: String {
        switch self {
        case .hero:
            return "Traders Guild is a live chart your guild shares. What anyone marks, everyone sees — in real time."
        case .placeMarker:
            return "Tap the marker button, then Post to the chart or Setup. Your face is pinned to the exact candle — add indicators, drawings or levels when you want the guild to see your working."
        case .trackedSetup:
            return "Setup markers carry entry, stop-loss and take-profit. The app watches price and records the result — that's your accuracy record and your place on the leaderboard."
        case .respondChat:
            return "Reply to any marker with your own — support it, challenge it or build on it — and talk it through in chat that lives on the chart."
        case .guild:
            return "You're starting in a System Guild. Join a real guild with an invite or handle, or create your own with a crest and bring your people."
        }
    }

    /// Small print under the last page's buttons. Carried over from the retired
    /// beta welcome sheet so the acknowledgement is still shown once.
    var footnote: String? {
        switch self {
        case .guild: return "Crypto market data powered by Binance. Not financial advice."
        default: return nil
        }
    }

    var isLast: Bool { self == WalkthroughPage.allCases.last }

    var next: WalkthroughPage? { WalkthroughPage(rawValue: rawValue + 1) }

    var primaryButtonTitle: String { isLast ? "Place your first marker" : "Continue" }

    /// Only the last page offers a way to finish without placing a marker.
    var secondaryButtonTitle: String? { isLast ? "Explore first" : nil }

    /// The editor pans the full recording inside a 720×1000 frame before encoding. Fit that
    /// complete frame: cropping it again would hide the controls the camera moved to reveal.
    static let sourceAspectRatio: CGFloat = 720.0 / 1000.0

    func clipPlacement(in window: CGSize) -> (size: CGSize, offsetY: CGFloat) {
        let width = min(window.width, window.height * Self.sourceAspectRatio)
        return (CGSize(width: width, height: width / Self.sourceAspectRatio), 0)
    }

    /// The bundled clip, or nil when a slot has no footage yet — the page then
    /// shows its poster only.
    func clipURL(in bundle: Bundle = .main) -> URL? {
        Self.resource("walkthrough_\(slot)", ext: "mp4", in: bundle)
    }

    func posterURL(in bundle: Bundle = .main) -> URL? {
        Self.resource("walkthrough_\(slot)_poster", ext: "jpg", in: bundle)
    }

    /// The synchronized `Resources/Walkthrough` folder copies flat into the bundle
    /// root, but look in the subdirectory first in case that ever changes.
    private static func resource(_ name: String, ext: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: "Walkthrough")
            ?? bundle.url(forResource: name, withExtension: ext)
    }
}

/// How the walkthrough ended. Every outcome marks it complete for the account;
/// only `.placeFirstMarker` has a follow-up action.
enum WalkthroughOutcome: Equatable {
    /// Skip, swipe-down or any other early dismissal.
    case skipped
    /// Reached the last page and chose "Explore first".
    case completed
    /// Reached the last page and chose "Place your first marker".
    case placeFirstMarker
}
