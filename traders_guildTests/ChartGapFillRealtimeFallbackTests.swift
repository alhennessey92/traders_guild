import Foundation
import Testing
@testable import traders_guild

@MainActor
struct ChartGapFillRealtimeFallbackTests {
    @Test
    func realtimeFallbackInsertsMissingBucketsForTickPath() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T10:00:00Z", close: 100)])

        manager.processRealTick(
            price: 101,
            volume: 3,
            timestamp: try date("2026-01-01T10:03:00Z")
        )

        #expect(manager.candles.count == 4)
        #expect(manager.candles[1].isGapFill)
        #expect(manager.candles[2].isGapFill)
        #expect(!manager.candles[3].isGapFill)
    }

    @Test
    func realtimeFallbackInsertsMissingBucketsForCandlePath() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T10:00:00Z", close: 100)])

        let _ = manager.processRealCandle(
            makeCandle("2026-01-01T10:03:00Z", close: 103, isGapFill: false)
        )

        #expect(manager.candles.count == 4)
        #expect(manager.candles[1].isGapFill)
        #expect(manager.candles[2].isGapFill)
        #expect(!manager.candles[3].isGapFill)
    }

    @Test
    func realtimeFallbackCapIsRespected() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T00:00:00Z", close: 100)])

        manager.processRealTick(
            price: 101,
            volume: 1,
            timestamp: try date("2026-01-01T03:30:00Z")
        )

        let gapCount = manager.candles.filter(\.isGapFill).count
        #expect(gapCount == 120)
        #expect(manager.candles.count == 122)
    }

    @Test
    func realCandleReplacesExistingPlaceholder() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T10:00:00Z", close: 100)])

        manager.processRealTick(
            price: 101,
            volume: 1,
            timestamp: try date("2026-01-01T10:03:00Z")
        )

        let replacement = makeCandle("2026-01-01T10:02:00Z", close: 150, isGapFill: false)
        let _ = manager.processRealCandle(replacement)

        let idx = try #require(manager.candles.firstIndex(where: { $0.timestamp == replacement.timestamp }))
        #expect(!manager.candles[idx].isGapFill)
        #expect(manager.candles[idx].close == 150)
    }

    @Test
    func decodeWithoutGapFlagDefaultsToFalse() throws {
        let json = """
        {
          "timestamp": "2026-01-01T00:00:00Z",
          "timestamp_formatted": "2026-01-01 00:00",
          "open": 100.0,
          "high": 101.0,
          "low": 99.0,
          "close": 100.5,
          "volume": 10.0
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let candle = try decoder.decode(RLCandleDTO.self, from: Data(json.utf8))
        #expect(candle.isGapFill == false)
    }

    @Test
    func markerSnapTieBreakPrefersPreviousThenNext() throws {
        let candles = [
            makeCandle("2026-01-01T10:00:00Z", close: 100, isGapFill: false),
            makeCandle("2026-01-01T10:01:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:02:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:03:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:04:00Z", close: 100, isGapFill: false),
        ]

        let snapped = TradingChartView.nearestNonGapCandleIndex(for: 2, candles: candles)
        #expect(snapped == 0)

        let onlyGaps = [
            makeCandle("2026-01-01T10:00:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:01:00Z", close: 100, isGapFill: true),
        ]
        #expect(TradingChartView.nearestNonGapCandleIndex(for: 1, candles: onlyGaps) == nil)
    }

    private func makeCandle(_ iso: String, close: Double, isGapFill: Bool = false) -> RLCandleDTO {
        let ts = (try? date(iso)) ?? Date(timeIntervalSince1970: 0)
        return RLCandleDTO(
            timestamp: ts,
            timestampFormatted: nil,
            open: close,
            high: close,
            low: close,
            close: close,
            volume: 1,
            volumeFormatted: "1",
            isGapFill: isGapFill
        )
    }

    private func date(_ iso8601: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso8601) else {
            throw DateParseError.invalid(iso8601)
        }
        return date
    }
}

private enum DateParseError: Error {
    case invalid(String)
}
