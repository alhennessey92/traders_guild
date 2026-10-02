import Testing
import UIKit
@testable import traders_guild

/// The intent badge's glyph is drawn as a template image (not text) for pan
/// performance; it must exist for every badge symbol, at the badge's size, and
/// be built once.
struct MarkerBadgeGlyphImagesTests {

    private static let statuses: [MarkerIntentBadge.SetupStatus] = [
        .unknown, .untracked, .armed, .active, .takeProfit, .stopLoss, .expired,
    ]

    private var badgeSymbols: [String] {
        var names: Set<String> = []
        for intent in [RLMarkerIntent.analysis, .question] {
            if let style = MarkerIntentBadge.style(intent: intent) { names.insert(style.symbol) }
        }
        for status in Self.statuses {
            if let style = MarkerIntentBadge.style(intent: .setup, setupStatus: status) { names.insert(style.symbol) }
        }
        return names.sorted()
    }

    @Test
    func everyBadgeSymbolHasATemplateGlyphAtBadgeSize() {
        #expect(!badgeSymbols.isEmpty)
        for name in badgeSymbols {
            let image = MarkerBadgeGlyphImages.image(named: name)
            #expect(image.size.width > 0 && image.size.height > 0, "\(name) resolved to an empty image")
            #expect(image.renderingMode == .alwaysTemplate, "\(name) must be tinted by the draw pass")
            #expect(image.size.width <= 14 && image.size.height <= 14, "\(name) is larger than the 8 pt badge glyph: \(image.size)")
        }
    }

    @Test
    func glyphsAreBuiltOnce() {
        let name = badgeSymbols.first ?? "questionmark"
        #expect(MarkerBadgeGlyphImages.image(named: name) === MarkerBadgeGlyphImages.image(named: name))
    }
}
