import XCTest
@testable import traders_guild

/// Pins the main chart's visible-window maths.
///
/// This calculation used to sit as private computed properties on `MainView`, which meant the app's
/// root view had to observe `ChartGestureState` — and so re-evaluated the entire shell on every
/// frame of a chart pan (measured: ~37 MainView body passes/sec while panning, against 0.13 ms of
/// actual candle drawing per frame). Moving it down to `TimeframePanelContainer`, its only consumer,
/// removed that. These tests exist so the move is verified rather than assumed: the expected values
/// below are derived from the original MainView formulas, not from the new implementation.
final class MainChartViewportTests: XCTestCase {

    private let base: CGFloat = 12
    private let spacing: CGFloat = 4
    private let hourly: TimeInterval = 3600

    /// 12 * 1.0 + 4 = 16pt per candle, matching the constants MainView passed literally.
    private func timestamps(count: Int, start: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> [Date] {
        (0..<count).map { start.addingTimeInterval(Double($0) * hourly) }
    }

    // MARK: - fractionalStartIndex

    func testFractionalStartIndexIsZeroWhenUnpannedWithNoHistory() {
        let index = MainChartViewport.fractionalStartIndex(
            panOffsetX: 0,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0
        )
        XCTAssertEqual(index, 0)
    }

    /// Panning right (positive offset) moves the window *back* through history.
    func testPanningRightNeverGoesBelowZeroWithoutHistory() {
        let index = MainChartViewport.fractionalStartIndex(
            panOffsetX: 160,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0
        )
        XCTAssertEqual(index, 0, "clamped at zero — there is nothing older to show")
    }

    func testHistoricalOffsetShiftsTheWindowForward() {
        // renderOffset 100, panned left by 160pt = 10 candles → 100 - (-160/16) → 110.
        let index = MainChartViewport.fractionalStartIndex(
            panOffsetX: -160,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 100
        )
        XCTAssertEqual(index, 110, accuracy: 0.0001)
    }

    /// Zooming out narrows each candle, so the same pan spans more of them.
    func testCandleWidthScaleChangesHowFarAPanReaches() {
        // 12 * 0.5 + 4 = 10pt per candle → 100pt of pan is 10 candles, not 6.25.
        let index = MainChartViewport.fractionalStartIndex(
            panOffsetX: -100,
            candleWidthScale: 0.5,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0
        )
        XCTAssertEqual(index, 10, accuracy: 0.0001)
    }

    func testDegenerateCandleWidthDoesNotDivideByZero() {
        let index = MainChartViewport.fractionalStartIndex(
            panOffsetX: -100,
            candleWidthScale: 0,
            baseCandleWidth: 0,
            candleSpacing: 0,
            historicalRenderIndexOffset: 5
        )
        XCTAssertEqual(index, 0)
    }

    // MARK: - interpolatedTimestamp

    func testInterpolatesBetweenTwoCandles() throws {
        let stamps = timestamps(count: 5)
        let result = try XCTUnwrap(MainChartViewport.interpolatedTimestamp(
            at: 2.25, candleTimestamps: stamps, timeframeSeconds: hourly
        ))
        XCTAssertEqual(
            result.timeIntervalSince1970,
            stamps[2].timeIntervalSince1970 + 900,   // a quarter of an hour past candle 2
            accuracy: 0.001
        )
    }

    func testExtrapolatesBeforeTheFirstCandle() throws {
        let stamps = timestamps(count: 5)
        let result = try XCTUnwrap(MainChartViewport.interpolatedTimestamp(
            at: -2, candleTimestamps: stamps, timeframeSeconds: hourly
        ))
        XCTAssertEqual(
            result.timeIntervalSince1970,
            stamps[0].timeIntervalSince1970 - 2 * hourly,
            accuracy: 0.001
        )
    }

    /// The right edge routinely sits past the newest candle — the chart keeps empty space there.
    func testExtrapolatesPastTheLastCandle() throws {
        let stamps = timestamps(count: 5)
        let result = try XCTUnwrap(MainChartViewport.interpolatedTimestamp(
            at: 6.5, candleTimestamps: stamps, timeframeSeconds: hourly
        ))
        XCTAssertEqual(
            result.timeIntervalSince1970,
            stamps[4].timeIntervalSince1970 + 2.5 * hourly,
            accuracy: 0.001
        )
    }

    func testEmptyCandlesYieldNoTimestamp() {
        XCTAssertNil(MainChartViewport.interpolatedTimestamp(
            at: 3, candleTimestamps: [], timeframeSeconds: hourly
        ))
    }

    // MARK: - visibleWindow

    func testVisibleWindowSpansTheViewportWidth() throws {
        let stamps = timestamps(count: 200)
        // 16pt per candle, 640pt viewport → exactly 40 candles on screen.
        let window = MainChartViewport.visibleWindow(
            panOffsetX: 0,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0,
            viewportWidth: 640,
            candleTimestamps: stamps,
            timeframeSeconds: hourly
        )

        XCTAssertEqual(try XCTUnwrap(window.start).timeIntervalSince1970, stamps[0].timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(window.end).timeIntervalSince1970, stamps[40].timeIntervalSince1970, accuracy: 0.001)
    }

    func testVisibleWindowFollowsAPan() throws {
        let stamps = timestamps(count: 200)
        // Panned left by 10 candles (160pt) → window is candles 10…50.
        let window = MainChartViewport.visibleWindow(
            panOffsetX: -160,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0,
            viewportWidth: 640,
            candleTimestamps: stamps,
            timeframeSeconds: hourly
        )

        XCTAssertEqual(try XCTUnwrap(window.start).timeIntervalSince1970, stamps[10].timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(window.end).timeIntervalSince1970, stamps[50].timeIntervalSince1970, accuracy: 0.001)
    }

    func testSingleCandleCollapsesTheWindowRatherThanCrashing() {
        let only = timestamps(count: 1)
        let window = MainChartViewport.visibleWindow(
            panOffsetX: -160,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0,
            viewportWidth: 640,
            candleTimestamps: only,
            timeframeSeconds: hourly
        )

        XCTAssertEqual(window.start, only[0])
        XCTAssertEqual(window.end, only[0])
    }

    func testNoCandlesYieldsNoWindow() {
        let window = MainChartViewport.visibleWindow(
            panOffsetX: 0,
            candleWidthScale: 1,
            baseCandleWidth: base,
            candleSpacing: spacing,
            historicalRenderIndexOffset: 0,
            viewportWidth: 640,
            candleTimestamps: [],
            timeframeSeconds: hourly
        )

        XCTAssertNil(window.start)
        XCTAssertNil(window.end)
    }
}
