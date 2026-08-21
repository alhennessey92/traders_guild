import CoreGraphics
import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import traders_guild

/// Pins the vertical-zoom pivot.
///
/// History worth keeping: the pivot is derived from the *display* height on iOS,
/// even though `verticalPanOffset` is consumed in chart-local space. That looks
/// like a coordinate-space bug on paper, and it was "fixed" to pivot on the chart
/// rect — which tested worse on device, because pivoting on the chart pulls the
/// zoom away from the candles while the taller screen-derived pivot keeps the
/// price action anchored. The shipped feel won.
///
/// So the point of these tests is the opposite of the usual one: they exist to
/// stop anyone (including a future me, reasoning from first principles again)
/// quietly making the iOS pivot chart-relative.
struct VerticalZoomAnchorTests {

    // MARK: - The iOS pivot must not become chart-relative

    #if os(iOS)
    @Test
    func iOSPivotsOnTheDisplayNotTheChartRect() {
        let expected = UIScreen.main.bounds.height / 2
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 600) == expected)
    }

    /// The load-bearing property: the iOS anchor does **not** vary with the chart
    /// rect. If this ever starts failing, the shipped gesture feel has changed.
    @Test
    func theIOSPivotIsIndependentOfChartHeight() {
        let small = VerticalZoomAnchor.anchorY(chartHeight: 320)
        let large = VerticalZoomAnchor.anchorY(chartHeight: 1600)
        #expect(small == large)
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 0) == small,
                "even a not-yet-laid-out chart uses the display pivot on iOS")
    }
    #endif

    #if os(macOS)
    /// A pane in a 2x2 grid has no meaningful "screen centre", so macOS pivots on
    /// the pane. Its gestures are being designed separately for mouse/trackpad.
    @Test
    func macOSPivotsOnThePane() {
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 600) == 300)
        #expect(VerticalZoomAnchor.anchorY(chartHeight: 400) == 200)
    }
    #endif

    // MARK: - The offset maths, independent of which pivot supplied it

    @Test
    func anUnscaledZoomLeavesTheOffsetAlone() {
        let offset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: 42, initialScale: 1, newScale: 1, anchorY: 300
        )
        #expect(offset == 42)
    }

    /// The formula only holds a point fixed when the anchor **is** the chart's
    /// centre. That is worth stating plainly, because it means iOS deliberately
    /// does not hold anything fixed: its anchor comes from the display, which is
    /// taller than the chart, so a zoom drifts. Tested on device, that drift is
    /// what makes the gesture feel like it zooms from the candles — it is the
    /// shipped behaviour and it is preferred.
    @Test
    func aPointIsHeldFixedOnlyWhenTheAnchorIsTheChartsCentre() {
        let chartHeight: CGFloat = 600
        let initialOffset: CGFloat = 80
        let initialScale: CGFloat = 1.0
        let newScale: CGFloat = 2.5

        func anchorDriftAfterZoom(anchor: CGFloat) -> CGFloat {
            let newOffset = VerticalZoomAnchor.adjustedVerticalOffset(
                initialOffset: initialOffset,
                initialScale: initialScale,
                newScale: newScale,
                anchorY: anchor
            )
            // ChartCoordinateSystem.yPosition, reduced to the terms that vary:
            //   y = H - normalized * H * scale - offset
            let normalizedAtAnchor =
                (chartHeight - anchor - initialOffset) / (chartHeight * initialScale)
            let after = chartHeight - normalizedAtAnchor * chartHeight * newScale - newOffset
            return after - anchor
        }

        // Centred anchor: nothing moves.
        #expect(abs(anchorDriftAfterZoom(anchor: chartHeight / 2)) < 0.0001)

        // A display-derived anchor sits below the chart's centre and does drift.
        // This is not a defect — it is the iOS gesture.
        #expect(abs(anchorDriftAfterZoom(anchor: 437)) > 1,
                "iOS's display-derived anchor is expected to drift; if this stops being true the shipped gesture feel has changed")
    }

    /// Reproduces the shipped inline formula verbatim and checks the extracted
    /// version agrees, so the refactor is provably behaviour-preserving.
    @Test
    func theExtractedMathsMatchesTheShippedInlineFormula() {
        let anchor: CGFloat = 437
        for initialScale in [0.5, 1.0, 2.0, 3.5] as [CGFloat] {
            for newScale in [0.4, 1.0, 1.9, 4.0] as [CGFloat] {
                for initialOffset in [-120, -1, 0, 55, 300] as [CGFloat] {
                    // Verbatim from the pre-refactor gesture closures.
                    let scaleRatio = newScale / initialScale
                    let shipped = initialOffset * scaleRatio + anchor * (1.0 - scaleRatio)

                    let extracted = VerticalZoomAnchor.adjustedVerticalOffset(
                        initialOffset: initialOffset,
                        initialScale: initialScale,
                        newScale: newScale,
                        anchorY: anchor
                    )
                    #expect(extracted == shipped)
                }
            }
        }
    }

    @Test
    func aDegenerateScaleIsLeftUntouchedRatherThanDividedBy() {
        let offset = VerticalZoomAnchor.adjustedVerticalOffset(
            initialOffset: 12, initialScale: 0, newScale: 2, anchorY: 300
        )
        #expect(offset == 12)
    }
}
