import CoreGraphics
import Foundation

/// Where vertical (price-axis) zoom pivots, and what it does to the pan offset.
///
/// Pure maths, deliberately outside any view — the same reasoning as
/// [MainChartViewport]. It previously sat inline in two gesture closures on
/// `TradingChartView`, both of which derived the pivot from `UIScreen.main`.
///
/// That was a coordinate-space mismatch, not merely an approximation:
/// `verticalPanOffset` is consumed in chart-local space
/// (`ChartCoordinateSystem.yPosition` measures against `chartSize.height`), while
/// the pivot was measured against the physical display. Since the chart never
/// fills the screen, the pivot sat below the chart's visual centre and the price
/// axis crept during a zoom. With several panes on screen the pivot could land
/// outside the pane being zoomed altogether.
enum VerticalZoomAnchor {

    /// The pivot: the vertical centre of the chart's own rect.
    ///
    /// Zero before the first layout pass, which degenerates to scaling about the
    /// origin. Unreachable in practice — the chart cannot be pinched before it
    /// has been laid out.
    static func anchorY(chartHeight: CGFloat) -> CGFloat {
        chartHeight > 0 ? chartHeight / 2 : 0
    }

    /// Pan offset that holds `anchorY` visually fixed while the price scale goes
    /// from `initialScale` to `newScale`.
    static func adjustedVerticalOffset(
        initialOffset: CGFloat,
        initialScale: CGFloat,
        newScale: CGFloat,
        chartHeight: CGFloat
    ) -> CGFloat {
        guard initialScale > 0 else { return initialOffset }
        let scaleRatio = newScale / initialScale
        let anchor = anchorY(chartHeight: chartHeight)
        return initialOffset * scaleRatio + anchor * (1.0 - scaleRatio)
    }
}
