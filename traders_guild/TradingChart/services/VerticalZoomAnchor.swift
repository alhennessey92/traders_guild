import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Where vertical (price-axis) zoom pivots, and what that does to the pan offset.
///
/// Pure maths, deliberately outside any view — the same reasoning as
/// [MainChartViewport]. It previously sat inline in two gesture closures on
/// `TradingChartView`.
///
/// **On the anchor, and why iOS keeps a screen-derived one.** `verticalPanOffset`
/// is consumed in chart-local space (`ChartCoordinateSystem.yPosition` measures
/// against `chartSize.height`), so on paper the pivot "should" be the chart's own
/// centre. Changing it to that was tried and rejected on device: pivoting on the
/// chart rect makes the zoom pull away from the candles, where the old pivot —
/// low in the chart's coordinate space, because the display is taller than the
/// chart — kept the price action anchored. The shipped iOS feel wins over the
/// tidier derivation, so iOS keeps exactly the constant it has always used.
///
/// macOS gets the chart-local pivot instead, because there is no meaningful
/// "screen centre" for a pane in a 2x2 grid — and its gestures are being designed
/// from scratch for mouse and trackpad regardless.
enum VerticalZoomAnchor {

    /// The pivot, in chart-local coordinates.
    ///
    /// Deliberately platform-split. Do not "unify" these — the iOS branch is the
    /// shipped gesture feel and reproducing it is the whole point.
    static func anchorY(chartHeight: CGFloat) -> CGFloat {
        #if os(macOS)
        return chartHeight > 0 ? chartHeight / 2 : 0
        #else
        return UIScreen.main.bounds.height / 2
        #endif
    }

    /// Pan offset that holds `anchorY` visually fixed while the price scale goes
    /// from `initialScale` to `newScale`.
    ///
    /// Takes the anchor rather than deriving it, so the maths stays pure and
    /// testable independently of which platform policy supplied it.
    static func adjustedVerticalOffset(
        initialOffset: CGFloat,
        initialScale: CGFloat,
        newScale: CGFloat,
        anchorY: CGFloat
    ) -> CGFloat {
        // The shipped gesture had no such guard; priceScale is clamped to a
        // positive minimum so this cannot fire in practice. It exists only to
        // keep a degenerate scale from producing NaN.
        guard initialScale > 0 else { return initialOffset }
        let scaleRatio = newScale / initialScale
        return initialOffset * scaleRatio + anchorY * (1.0 - scaleRatio)
    }
}
