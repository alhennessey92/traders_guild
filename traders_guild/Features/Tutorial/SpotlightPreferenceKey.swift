import SwiftUI

// MARK: - Spotlight Frame Key

/// Collects named CGRect frames (in global coordinate space) from views
/// tagged with `.spotlightTarget(_:)`. Resolved frames are stored in
/// `TutorialManager.spotlightFrames` via `.onPreferenceChange`.
struct SpotlightFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - View Extension

extension View {
    /// Registers this view as a spotlight target for the tutorial system.
    /// Uses a background `GeometryReader` to resolve the view's frame in the
    /// global coordinate space, then writes it to `SpotlightFrameKey`.
    func spotlightTarget(_ key: String) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: SpotlightFrameKey.self,
                        value: [key: geometry.frame(in: .global)]
                    )
            }
        )
    }
}

// MARK: - Reverse Mask Extension

extension View {
    /// Applies an inverted mask — the masked region becomes transparent while
    /// the surrounding area remains opaque. Used to punch a spotlight hole
    /// through the dimming overlay.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .center) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
