import Foundation

struct RealtimeCandleReductionResult {
    let candles: [RLCandleDTO]
    let currentPrice: Double
    let trimmedCount: Int
}

enum RealtimeCandleStreamReducer {
    static func processTick(
        candles: [RLCandleDTO],
        timeframe: RLChartTimeframe,
        price: Double,
        volume: Double,
        timestamp: Date? = nil,
        maxCandles: Int = 500,
        maxRealtimeFallbackInsert: Int = 120
    ) -> RealtimeCandleReductionResult {
        var nextCandles = candles
        var trimmedCount = 0

        guard !nextCandles.isEmpty else {
            return RealtimeCandleReductionResult(
                candles: nextCandles,
                currentPrice: price,
                trimmedCount: 0
            )
        }

        let tickTime = timestamp ?? Date()
        let bucketTimestamp = alignedCandleTimestamp(for: tickTime, timeframe: timeframe)

        if let lastCandle = nextCandles.last {
            if bucketTimestamp > lastCandle.timestamp {
                let fallbackCandles = fillRealtimeGap(
                    from: lastCandle,
                    to: bucketTimestamp,
                    timeframe: timeframe,
                    maxRealtimeFallbackInsert: maxRealtimeFallbackInsert
                )
                if !fallbackCandles.isEmpty {
                    nextCandles.append(contentsOf: fallbackCandles)
                }

                let newCandle = RLCandleDTO(
                    timestamp: bucketTimestamp,
                    open: price,
                    high: price,
                    low: price,
                    close: price,
                    volume: volume,
                    isGapFill: false
                )
                nextCandles.append(newCandle)

                if nextCandles.count > maxCandles {
                    trimmedCount = nextCandles.count - maxCandles
                    nextCandles.removeFirst(trimmedCount)
                }
            } else if bucketTimestamp == lastCandle.timestamp {
                nextCandles[nextCandles.count - 1] = updatedCandle(
                    lastCandle,
                    tickPrice: price,
                    tickVolume: volume
                )
            } else if let existingIndex = indexOfCandle(with: bucketTimestamp, in: nextCandles),
                      nextCandles[existingIndex].isGapFill {
                nextCandles[existingIndex] = RLCandleDTO(
                    timestamp: bucketTimestamp,
                    open: price,
                    high: price,
                    low: price,
                    close: price,
                    volume: volume,
                    isGapFill: false
                )
            }
        }

        return RealtimeCandleReductionResult(
            candles: nextCandles,
            currentPrice: price,
            trimmedCount: trimmedCount
        )
    }

    static func processCompletedCandle(
        candles: [RLCandleDTO],
        timeframe: RLChartTimeframe,
        candle: RLCandleDTO,
        maxCandles: Int = 500,
        maxRealtimeFallbackInsert: Int = 120
    ) -> RealtimeCandleReductionResult {
        var nextCandles = candles
        var trimmedCount = 0

        if let existingIndex = indexOfCandle(with: candle.timestamp, in: nextCandles) {
            nextCandles[existingIndex] = candle
        } else if let lastCandle = nextCandles.last {
            if candle.timestamp > lastCandle.timestamp {
                let fallbackCandles = fillRealtimeGap(
                    from: lastCandle,
                    to: candle.timestamp,
                    timeframe: timeframe,
                    maxRealtimeFallbackInsert: maxRealtimeFallbackInsert
                )
                if !fallbackCandles.isEmpty {
                    nextCandles.append(contentsOf: fallbackCandles)
                }
                nextCandles.append(candle)

                if nextCandles.count > maxCandles {
                    trimmedCount = nextCandles.count - maxCandles
                    nextCandles.removeFirst(trimmedCount)
                }
            }
        } else {
            nextCandles.append(candle)
        }

        return RealtimeCandleReductionResult(
            candles: nextCandles,
            currentPrice: candle.close,
            trimmedCount: trimmedCount
        )
    }

    static func alignedCandleTimestamp(for timestamp: Date, timeframe: RLChartTimeframe) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp)
        components.second = 0

        switch timeframe {
        case .m1:
            break
        case .m5:
            if let minute = components.minute { components.minute = (minute / 5) * 5 }
        case .m15:
            if let minute = components.minute { components.minute = (minute / 15) * 15 }
        case .m30:
            if let minute = components.minute { components.minute = (minute / 30) * 30 }
        case .h1:
            components.minute = 0
        case .h4:
            if let hour = components.hour { components.hour = (hour / 4) * 4 }
            components.minute = 0
        case .d1:
            components.hour = 0
            components.minute = 0
        case .w1:
            components.hour = 0
            components.minute = 0
            if let dayStart = calendar.date(from: components) {
                let weekday = calendar.component(.weekday, from: dayStart)
                let daysFromMonday = (weekday + 5) % 7
                return calendar.date(byAdding: .day, value: -daysFromMonday, to: dayStart) ?? dayStart
            }
        case .mn:
            components.day = 1
            components.hour = 0
            components.minute = 0
        }

        return calendar.date(from: components) ?? timestamp
    }

    static func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        }
        if volume >= 1_000 {
            return String(format: "%.1fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }

    private static func updatedCandle(
        _ candle: RLCandleDTO,
        tickPrice: Double,
        tickVolume: Double
    ) -> RLCandleDTO {
        let newVolume = (candle.volume ?? 0) + tickVolume
        return RLCandleDTO(
            timestamp: candle.timestamp,
            open: candle.open,
            high: max(candle.high, tickPrice),
            low: min(candle.low, tickPrice),
            close: tickPrice,
            volume: newVolume,
            isGapFill: false
        )
    }

    private static func fillRealtimeGap(
        from lastCandle: RLCandleDTO,
        to newTimestamp: Date,
        timeframe: RLChartTimeframe,
        maxRealtimeFallbackInsert: Int
    ) -> [RLCandleDTO] {
        let step = max(1, timeframe.seconds)
        var nextTimestamp = lastCandle.timestamp.addingTimeInterval(step)
        var generated: [RLCandleDTO] = []

        while nextTimestamp < newTimestamp && generated.count < maxRealtimeFallbackInsert {
            let close = generated.last?.close ?? lastCandle.close
            generated.append(
                RLCandleDTO(
                    timestamp: nextTimestamp,
                    open: close,
                    high: close,
                    low: close,
                    close: close,
                    volume: 0,
                    isGapFill: true
                )
            )
            nextTimestamp = nextTimestamp.addingTimeInterval(step)
        }

        return generated
    }

    private static func indexOfCandle(with timestamp: Date, in candles: [RLCandleDTO]) -> Int? {
        var left = 0
        var right = candles.count - 1

        while left <= right {
            let middle = (left + right) / 2
            let currentTimestamp = candles[middle].timestamp

            if currentTimestamp == timestamp {
                return middle
            }

            if currentTimestamp < timestamp {
                left = middle + 1
            } else {
                right = middle - 1
            }
        }

        return nil
    }
}
