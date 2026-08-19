import CoreGraphics
import Foundation

/// The main chart's visible time window, as the timeframe panels need it for their window overlay.
///
/// Pure maths, deliberately outside any view. It used to live as private computed properties on
/// `MainView`, which forced the app's root view to observe `ChartGestureState` and so to re-evaluate
/// on every frame of a chart pan. Extracting it makes the calculation testable on its own and lets
/// the only consumer — `TimeframePanelContainer` — own the subscription.
enum MainChartViewport {

    /// Fractional index of the leftmost visible candle (e.g. 5.3 = 30% into candle 5).
    ///
    /// Fractional rather than rounded so the overlay tracks a pan continuously instead of snapping
    /// a whole candle at a time.
    static func fractionalStartIndex(
        panOffsetX: CGFloat,
        candleWidthScale: CGFloat,
        baseCandleWidth: CGFloat,
        candleSpacing: CGFloat,
        historicalRenderIndexOffset: Int
    ) -> CGFloat {
        let totalCandleWidth = baseCandleWidth * candleWidthScale + candleSpacing
        guard totalCandleWidth > 0 else { return 0 }
        return max(0, CGFloat(historicalRenderIndexOffset) - panOffsetX / totalCandleWidth)
    }

    /// Timestamp at a fractional candle index, interpolating between candles and extrapolating at
    /// `timeframeSeconds` per candle beyond either end.
    static func interpolatedTimestamp(
        at fractionalIndex: CGFloat,
        candleTimestamps: [Date],
        timeframeSeconds: TimeInterval
    ) -> Date? {
        guard let first = candleTimestamps.first, let last = candleTimestamps.last else { return nil }

        let idx = Int(fractionalIndex)
        let frac = fractionalIndex - CGFloat(idx)

        if idx < 0 {
            return first.addingTimeInterval(-Double(-fractionalIndex) * timeframeSeconds)
        }
        if idx >= candleTimestamps.count - 1 {
            let overshoot = fractionalIndex - CGFloat(candleTimestamps.count - 1)
            return last.addingTimeInterval(Double(overshoot) * timeframeSeconds)
        }

        let t0 = candleTimestamps[idx].timeIntervalSince1970
        let t1 = candleTimestamps[idx + 1].timeIntervalSince1970
        return Date(timeIntervalSince1970: t0 + Double(frac) * (t1 - t0))
    }

    /// Start and end timestamps of the window currently on screen.
    ///
    /// Returns the single available timestamp for both bounds when there are fewer than two
    /// candles — there is no window to speak of, and the overlay draws nothing useful either way.
    static func visibleWindow(
        panOffsetX: CGFloat,
        candleWidthScale: CGFloat,
        baseCandleWidth: CGFloat,
        candleSpacing: CGFloat,
        historicalRenderIndexOffset: Int,
        viewportWidth: CGFloat,
        candleTimestamps: [Date],
        timeframeSeconds: TimeInterval
    ) -> (start: Date?, end: Date?) {
        guard candleTimestamps.count >= 2 else {
            return (candleTimestamps.first, candleTimestamps.last)
        }

        let totalCandleWidth = baseCandleWidth * candleWidthScale + candleSpacing
        guard totalCandleWidth > 0 else {
            return (candleTimestamps.first, candleTimestamps.last)
        }

        let start = fractionalStartIndex(
            panOffsetX: panOffsetX,
            candleWidthScale: candleWidthScale,
            baseCandleWidth: baseCandleWidth,
            candleSpacing: candleSpacing,
            historicalRenderIndexOffset: historicalRenderIndexOffset
        )
        let end = start + viewportWidth / totalCandleWidth

        return (
            interpolatedTimestamp(at: start, candleTimestamps: candleTimestamps, timeframeSeconds: timeframeSeconds),
            interpolatedTimestamp(at: end, candleTimestamps: candleTimestamps, timeframeSeconds: timeframeSeconds)
        )
    }
}
