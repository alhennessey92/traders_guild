import CoreGraphics
import Foundation
import Testing
@testable import traders_guild

/// Pins the vertical-zoom pivot.
///
/// Both Y-axis gestures used to derive the pivot from `UIScreen.main.bounds.height`,
/// while `verticalPanOffset` is consumed in chart-local space. The expected values
/// below are derived from the invariant the formula is supposed to satisfy — the
/// anchor stays visually fixed across a scale change — not from the implementation.
struct VerticalZoomAnchorTests {

    private let chartHeight: CGFloat = 600

    @Test
    func theAnchorIsTheChartsOwnCentre() {
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 600) == 300)
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 320) == 160)
    }

    /// A pane is not the display. The same chart height must give the same pivot
    /// regardless of how big the screen behind it is — which is exactly what the
    /// old `UIScreen`-derived version got wrong.
    @Test
    func theAnchorIgnoresEverythingExceptTheChartRect() {
        // A 2x2 grid pane on a large display is ~a quarter of it; the pivot must
        // follow the pane.
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 400) == 200)
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 400)
                != VerticalZoomAnchor.anchorY(chartHeight: 1600))
    }

    @Test
    func anUnscaledZoomLeavesTheOffsetAlone() {
        let offset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: 42, initialScale: 1, newScale: 1, chartHeight: chartHeight
        )
        #expect(offset == 42)
    }

    /// The defining property: the price sitting at the anchor before the zoom is
    /// still at the anchor after it.
    @Test
    func thePointUnderTheAnchorDoesNotMove() {
        let initialOffset: CGFloat = 80
        let initialScale: CGFloat = 1.0
        let newScale: CGFloat = 2.5
        let anchor = VerticalZoomAnchor.anchorY(chartHeight: chartHeight)

        let newOffset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: initialOffset,
            initialScale: initialScale,
            newScale: newScale,
            chartHeight: chartHeight
        )

        // ChartCoordinateSystem.yPosition, reduced to the parts that vary here:
        //   y = H - normalized * H * scale - offset
        // Solve for the normalized price rendered at the anchor before the zoom,
        // then check it still lands on the anchor afterwards.
        func y(normalized: CGFloat, scale: CGFloat, offset: CGFloat) -> CGFloat {
            chartHeight - normalized * chartHeight * scale - offset
        }
        let normalizedAtAnchor =
            (chartHeight - anchor - initialOffset) / (chartHeight * initialScale)

        let after = y(normalized: normalizedAtAnchor, scale: newScale, offset: newOffset)
        #expect(abs(after - anchor) < 0.0001,
                "the price under the anchor drifted by \(after - anchor)pt")
    }

    @Test
    func zoomingOutHoldsTheAnchorToo() {
        let anchor = VerticalZoomAnchor.anchorY(chartHeight: chartHeight)
        let initialOffset: CGFloat = -30
        let newOffset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: initialOffset, initialScale: 3.0, newScale: 0.8, chartHeight: chartHeight
        )
        let normalizedAtAnchor = (chartHeight - anchor - initialOffset) / (chartHeight * 3.0)
        let after = chartHeight - normalizedAtAnchor * chartHeight * 0.8 - newOffset
        #expect(abs(after - anchor) < 0.0001)
    }

    @Test
    func aDegenerateScaleIsLeftUntouchedRatherThanDividedBy() {
        let offset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: 12, initialScale: 0, newScale: 2, chartHeight: chartHeight
        )
        #expect(offset == 12)
    }

    @Test
    func aChartWithNoHeightYetDoesNotProduceNaN() {
        let offset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: 10, initialScale: 1, newScale: 2, chartHeight: 0
        )
        #expect(offset.isFinite)
    }
}
