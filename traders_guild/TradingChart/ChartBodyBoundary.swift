import SwiftUI

/// Defers construction of a chart subtree until SwiftUI evaluates its body.
///
/// A helper returning `some View` still embeds its full value in the caller's
/// result-builder tuple. In unoptimized device builds, the chart's large tuples
/// and modifier chains exhausted the main-thread stack during initial layout.
/// Store the builder rather than its result so each subtree is constructed in
/// a separate body evaluation, without erasing its type or changing its state.
struct ChartBodyBoundary<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View { content() }
}
