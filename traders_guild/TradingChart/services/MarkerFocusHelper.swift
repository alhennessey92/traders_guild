import CoreGraphics

struct MarkerFocusHelper {
    static func renderedGlyphFocusPrice(
        marker: ChartMarkerUI,
        candles: [RLCandleDTO],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) -> Double? {
        guard marker.candleIndex >= 0, marker.candleIndex < candles.count else {
            return nil
        }

        let range = priceRange.max - priceRange.min
        guard range > 0, chartSize.height > 0, priceScale > 0 else {
            return nil
        }

        let candle = candles[marker.candleIndex]
        let scaledHeight = chartSize.height * priceScale
        let centerX = CGFloat(marker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2

        let candleHighY = chartSize.height
            - (CGFloat(candle.high - priceRange.min) / CGFloat(range)) * scaledHeight
            - verticalOffset
        let candleLowY = chartSize.height
            - (CGFloat(candle.low - priceRange.min) / CGFloat(range)) * scaledHeight
            - verticalOffset

        let markerPosition = MarkerPositionCalculator.computeMarkerScreenPosition(
            marker: marker,
            candleHighY: candleHighY,
            candleLowY: candleLowY,
            centerX: centerX,
            priceScale: priceScale
        )

        guard markerPosition.y.isFinite else {
            return nil
        }

        let normalizedY = (chartSize.height - (markerPosition.y + verticalOffset)) / scaledHeight
        let unclamped = priceRange.min + Double(normalizedY) * range
        let resolved = min(priceRange.max, max(priceRange.min, unclamped))

        guard resolved.isFinite else {
            return nil
        }

        return resolved
    }
}
