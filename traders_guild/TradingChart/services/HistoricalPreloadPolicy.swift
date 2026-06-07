//
//  HistoricalPreloadPolicy.swift
//  traders_guild
//
//  Shared thresholds for keeping historical candles ahead of the viewport.
//

import Foundation

enum HistoricalPreloadReason: String {
    case warmup
    case viewport
}

struct HistoricalPreloadPolicy {
    static let pageSize = 1000

    static func warmupTarget(for timeframe: RLChartTimeframe) -> Int {
        switch timeframe {
        case .m1, .m5, .m15, .m30:
            return 3500
        case .h1, .h4:
            return 2500
        case .d1, .w1, .mn:
            return 1200
        }
    }

    static func triggerThreshold(visibleCandleCount: Int) -> Int {
        max(visibleCandleCount * 8, 900)
    }

    static func targetBuffer(visibleCandleCount: Int) -> Int {
        max(visibleCandleCount * 12, 1500)
    }

    static func shouldWarmup(
        candleCount: Int,
        timeframe: RLChartTimeframe,
        hasMoreHistoricalCandles: Bool
    ) -> Bool {
        hasMoreHistoricalCandles && candleCount < warmupTarget(for: timeframe)
    }

    static func shouldPreload(
        visibleStartIndex: Int,
        visibleCandleCount: Int,
        hasMoreHistoricalCandles: Bool
    ) -> Bool {
        hasMoreHistoricalCandles &&
            visibleStartIndex <= triggerThreshold(visibleCandleCount: visibleCandleCount)
    }

    static func edgeGuardCandleCount(
        visibleCandleCount: Int,
        candleCount: Int,
        hasMoreHistoricalCandles: Bool
    ) -> Int {
        guard hasMoreHistoricalCandles, visibleCandleCount > 0, candleCount > visibleCandleCount else {
            return 0
        }

        let desiredGuard = max(visibleCandleCount * 2, 120)
        let maximumGuard = max(0, candleCount - (visibleCandleCount * 2))
        return min(desiredGuard, maximumGuard)
    }
}
