import Foundation
import Testing
import UIKit
@testable import traders_guild

/// Regression cover for the share-sheet crash: tapping "More" on a marker (or a guild invite)
/// terminated the app with `NSInternalInconsistencyException` — "Need an imageRef" — because the
/// link-preview icon was fetched with `UIImage(named: "AppIcon")`, and the app icon is an Icon
/// Composer asset. The assertion is raised inside the lookup, so the old `if let` guard never ran.
///
/// These tests call the real path against the real app bundle (the test target is app-hosted).
/// Against the previous implementation the first one does not fail — it crashes the test run.
struct ShareLinkIconTests {
    @MainActor
    @Test
    func bitmapResolvesWithoutTrippingTheIconAssetAssertion() {
        let icon = ShareLinkIcon.bitmap()
        #expect(icon.cgImage != nil, "LinkPresentation needs a real bitmap behind the icon")
        #expect(icon.size.width > 0 && icon.size.height > 0)
    }

    /// The share kits hand `NSItemProvider` PNG data rather than a `UIImage`, so the bitmap has
    /// to survive that encoding.
    @MainActor
    @Test
    func bitmapEncodesToPNGForTheItemProvider() {
        let png = ShareLinkIcon.bitmap().pngData()
        #expect(png != nil)
        #expect((png?.count ?? 0) > 0)
    }

    /// The delegate method the share sheet actually calls — frame 15 of the crash, which then
    /// called into the icon lookup. Building it here exercises the whole preview path against
    /// the real bundle, short of presenting UIKit's sheet.
    @MainActor
    @Test
    func markerLinkMetadataBuildsWithAnIconProvider() {
        let item = MarkerShareItem(
            url: URL(string: "https://tradersguild.co/marker/5b2abf91-6ce8-4e5d-a2cc-5c25c4b7594a")!,
            symbolTicker: "BTC/USD"
        )
        let source = MarkerShareActivityItemSource(item: item)
        let metadata = source.activityViewControllerLinkMetadata(UIActivityViewController(
            activityItems: [item.url],
            applicationActivities: nil
        ))

        #expect(metadata != nil)
        #expect(metadata?.title == "BTC/USD marker on Traders Guild")
        #expect(metadata?.iconProvider != nil, "the preview icon is the path that used to crash")
    }

    /// The whole path the crash took: build the item source, hand it to a real
    /// `UIActivityViewController` and present it over the running app. Against the old
    /// implementation this crashes the test run inside `_createMainPresenterIfNeeded`, which is
    /// exactly what tapping "More" did.
    ///
    /// The local dev backend hands out an ngrok share URL that `validatedServerShareURL`
    /// refuses, so the share sheet cannot be reached by tapping through a local build — this
    /// covers it without a backend.
    @MainActor
    @Test
    func theNativeShareSheetPresentsWithoutCrashing() async throws {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        guard let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first,
              let rootVC = window.rootViewController else {
            // No UI host (headless run) — the other tests still cover the metadata itself.
            return
        }

        let item = MarkerShareItem(
            url: URL(string: "https://tradersguild.co/marker/5b2abf91-6ce8-4e5d-a2cc-5c25c4b7594a?share_token=PnCZ8qTCAPlL-0yzwPpkv9Z3bFlizM9aRsSsWEOhII8")!,
            symbolTicker: "BTC/USD"
        )

        await withCheckedContinuation { continuation in
            MarkerShare.presentNativeShareSheet(for: item) {
                continuation.resume()
            }
        }

        var presenter = rootVC
        while let presented = presenter.presentedViewController, !(presented is UIActivityViewController) {
            presenter = presented
        }
        #expect(presenter.presentedViewController is UIActivityViewController)

        await withCheckedContinuation { continuation in
            presenter.dismiss(animated: false) { continuation.resume() }
        }
    }

    /// Repeated presentations must not depend on any cached lookup succeeding the first time.
    @MainActor
    @Test
    func bitmapIsStableAcrossCalls() {
        let first = ShareLinkIcon.bitmap()
        let second = ShareLinkIcon.bitmap()
        #expect(first.size == second.size)
        #expect(second.cgImage != nil)
    }
}
