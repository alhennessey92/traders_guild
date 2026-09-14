import Foundation

/// Resolve a draft's time against the new interval rather than retaining an
/// index from the previous candle array. A 06:41 response belongs to the 04:00
/// four-hour candle, not whichever candle happens to have the old array index.
enum MarkerResponseAnchorResolver {
    static func index(for time: Date, candles: [RLCandleDTO], timeframe: RLChartTimeframe) -> Int? {
        guard let first = candles.first, time >= first.timestamp else { return nil }
        var lower = 0
        var upper = candles.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if candles[middle].timestamp <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        let index = lower - 1
        guard index >= 0 else { return nil }
        let start = candles[index].timestamp
        let end: Date
        if timeframe == .mn {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            end = nextMonth
        } else {
            end = start.addingTimeInterval(timeframe.seconds)
        }
        // Return nil for unloaded history so the caller loads a window; never
        // silently move an older response onto an unrelated visible candle.
        return time < end ? index : nil
    }
}
