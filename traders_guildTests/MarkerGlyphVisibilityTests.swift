import CoreGraphics
import Foundation
import Testing
@testable import traders_guild

/// Whether a focused thesis member was actually painted.
///
/// The render queue is culled horizontally — by candle index and a margin — and
/// never against the plot rect, so queue membership was being read as
/// visibility. A companion off the top of the price range, behind the y-axis,
/// or sitting in the margin counted as visible and held the fade on with a
/// single glyph really on screen.
struct MarkerGlyphVisibilityTests {

    /// A realistic plot: the marker layer is clipped to the chart minus the
    /// y-axis on the right and the x-axis label strip along the bottom.
    private let plot = CGRect(x: 0, y: 0, width: 340, height: 700)
    private var radius: CGFloat { MarkerVisualSpec.baseCanvasDiameter / 2 }
    private var selectedRadius: CGFloat { radius * 1.5 }

    @Test
    func aGlyphInsideThePlotIsVisible() {
        #expect(MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: 170, y: 350), scaledRadius: radius, in: plot
        ))
    }

    /// Off the top or bottom of the price range. This is the common one: a
    /// thesis spans prices, and zooming in pushes members out vertically while
    /// leaving them in the queue.
    @Test
    func aGlyphOffTheTopOrBottomIsNotVisible() {
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: 170, y: -60), scaledRadius: radius, in: plot
        ))
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: 170, y: 780), scaledRadius: radius, in: plot
        ))
    }

    /// Behind the y-axis. The plot stops before the axis, so a glyph drawn there
    /// is clipped away even though its x is within the canvas.
    @Test
    func aGlyphBehindTheRightAxisIsNotVisible() {
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: 400, y: 350), scaledRadius: radius, in: plot
        ))
    }

    /// Far outside on the horizontal margin the queue tolerates.
    @Test
    func aGlyphFarOutsideTheMarginIsNotVisible() {
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: -220, y: 350), scaledRadius: radius, in: plot
        ))
    }

    /// Half a glyph at the edge is still a glyph the viewer can see and compare
    /// against, so it counts. The boundary is the disc, not the centre.
    @Test
    func aPartlyVisibleDiscCounts() {
        // Centre just outside the left edge, disc still overlapping.
        #expect(MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: -radius + 2, y: 350), scaledRadius: radius, in: plot
        ))
        // One point further out than the radius and it is genuinely gone.
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: CGPoint(x: -radius - 2, y: 350), scaledRadius: radius, in: plot
        ))
    }

    /// The selected marker is drawn at 1.5×, so its disc reaches further. A
    /// centre that would be invisible at rest can be visible when selected —
    /// which is why the check uses the final scaled radius rather than the base.
    @Test
    func theScaledSelectedDiscReachesFurtherThanTheRestingOne() {
        let center = CGPoint(x: 340 + radius + 4, y: 350)
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: center, scaledRadius: radius, in: plot
        ))
        #expect(MarkerLinkRenderer.isGlyphVisible(
            center: center, scaledRadius: selectedRadius, in: plot
        ))
    }

    /// Corners are a real case — a glyph beyond both edges is outside even
    /// though each axis alone looks close enough. Circle-against-rect, not two
    /// independent range checks.
    @Test
    func aDiagonalCornerMissIsNotVisible() {
        let justOutsideOnBothAxes = CGPoint(x: 340 + radius * 0.8, y: 700 + radius * 0.8)
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: justOutsideOnBothAxes, scaledRadius: radius, in: plot
        ))
    }

    /// An empty plot paints nothing, so nothing is visible — guarding the first
    /// frame before layout has a size.
    @Test
    func anEmptyPlotShowsNothing() {
        #expect(!MarkerLinkRenderer.isGlyphVisible(
            center: .zero, scaledRadius: radius, in: .zero
        ))
    }
}
