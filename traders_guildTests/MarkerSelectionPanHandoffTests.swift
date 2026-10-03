import XCTest
@testable import traders_guild

/// The owner's "select another marker, then pan before its wiggle finishes".
///
/// Selecting a marker starts a 0.9 s centre-on-marker animation that writes
/// the chart's pan offset outright on every display frame. A drag that begins
/// inside it applies its movement, and the next frame overwrites it. These
/// reproduce that on the real `ChartGestureState` and its real display link,
/// then check the prototype's hand-off: under the experiment the finger stops
/// the animation, and the legacy chart is unchanged.
@MainActor
final class MarkerSelectionPanHandoffTests: XCTestCase {

    private let chartWidth: CGFloat = 400
    private let chartHeight: CGFloat = 600
    private let candleWidth: CGFloat = 10
    private let candleCount = 300
    /// Where centring on candle 150 lands: half the chart, less the candle's x
    /// and half a candle.
    private var centredOffset: CGFloat { chartWidth / 2 - 150 * candleWidth - candleWidth / 2 }

    /// What a tap on a marker at candle 150 starts.
    private func selectingAMarker() -> ChartGestureState {
        let state = ChartGestureState()
        state.animateCenterOnMarker(
            at: 150,
            chartWidth: chartWidth,
            candleWidth: candleWidth,
            price: 100,
            chartHeight: chartHeight,
            priceRange: (min: 50, max: 150)
        )
        return state
    }

    private func letFramesRun(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func drag(_ state: ChartGestureState, by dx: CGFloat) {
        state.applyPan(
            translation: CGSize(width: dx, height: 0),
            chartWidth: chartWidth,
            candleCount: candleCount,
            candleWidth: candleWidth,
            chartHeight: chartHeight,
            priceScale: 1,
            trackVelocity: false
        )
    }

    /// The reproduction: a drag started 0.25 s into the centring moves the
    /// chart, and the animation then puts it back exactly where it was going.
    /// The finger's movement is lost.
    func testOnTheLegacyChartTheCentringOverwritesADragStartedInsideIt() {
        let state = selectingAMarker()
        letFramesRun(for: 0.25)
        XCTAssertTrue(state.isCenteringAnimationActive, "the centring is still running when the pan starts")

        state.beginDrag()
        let beforeDrag = state.panOffset.width
        drag(state, by: -150)
        XCTAssertEqual(state.panOffset.width, beforeDrag - 150, accuracy: 0.001, "the drag moved the chart")

        letFramesRun(for: 1.0)
        XCTAssertFalse(state.isCenteringAnimationActive)
        XCTAssertEqual(state.panOffset.width, centredOffset, accuracy: 0.5,
                       "the chart ends on the marker as if the 150 pt drag never happened")
    }

    /// The prototype: the finger takes over. The chart stays where the drag
    /// put it and nothing moves it afterwards.
    func testUnderThePrototypeTheFingerTakesOverFromTheCentring() {
        let state = selectingAMarker()
        letFramesRun(for: 0.25)
        XCTAssertTrue(state.isCenteringAnimationActive)

        state.beginDrag(interruptsCentering: true)
        XCTAssertFalse(state.isCenteringAnimationActive, "the drag stops the centring")
        drag(state, by: -150)
        let dragged = state.panOffset.width

        letFramesRun(for: 1.0)
        XCTAssertEqual(state.panOffset.width, dragged, "nothing moved the chart after the finger")
        XCTAssertGreaterThan(abs(dragged - centredOffset), 1, "the chart did not snap to the marker")
    }

    /// With no centring under way, a drag is the same either way.
    func testWithoutACentringADragIsUnchanged() {
        for interrupts in [false, true] {
            let state = ChartGestureState()
            state.beginDrag(interruptsCentering: interrupts)
            drag(state, by: -150)
            XCTAssertEqual(state.panOffset.width, -150, accuracy: 0.001)
            XCTAssertFalse(state.isCenteringAnimationActive)
        }
    }
}
