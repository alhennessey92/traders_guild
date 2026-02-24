//
//  Candle+TimeframeGeneration.swift
//  traders_guild
//
//  Extension for generating timeframe-aligned sample data
//  Ensures timestamps fall on "nice" boundaries for realistic chart display
//

import Foundation

extension RLCandleDTO {
    
    // MARK: - Timeframe-Aware Sample Data Generation
    
    /// Generate sample candles aligned to a specific timeframe
    /// Timestamps will fall on natural boundaries (e.g., :00, :05, :15 for minute charts)
    /// - Parameters:
    ///   - count: Number of candles to generate
    ///   - timeframe: The chart timeframe to align timestamps to
    ///   - endDate: The ending date (most recent candle), defaults to now rounded to timeframe
    ///   - basePrice: Starting price for the simulation
    /// - Returns: Array of candles with aligned timestamps, oldest first
    static func generateAlignedSampleData(
        count: Int = 200,
        timeframe: RLChartTimeframe,
        endDate: Date = Date(),
        basePrice: Double = 100.0
    ) -> [RLCandleDTO] {
        var candles: [RLCandleDTO] = []
        var currentPrice = basePrice
        
        let alignedEndDate = alignToTimeframe(date: endDate, timeframe: timeframe)
        var currentDate = alignedEndDate
        
        for _ in 0..<count {
            let candle = RLCandleDTO.random(basePrice: currentPrice, timestamp: currentDate)
            candles.append(candle)
            currentPrice = candle.close
            currentDate = currentDate.addingTimeInterval(-timeframe.seconds)
        }
        
        return candles.reversed()
    }
    
    /// Generate sample data for a specific trading symbol
    /// Uses appropriate base price and volatility for the asset class
    static func generateSampleData(
        count: Int = 200,
        timeframe: RLChartTimeframe,
        symbol: RLTradingSymbolDTO
    ) -> [RLCandleDTO] {
        let basePrice = defaultBasePrice(for: symbol)
        let volatility = defaultVolatility(for: symbol)
        
        return generateAlignedSampleData(
            count: count,
            timeframe: timeframe,
            endDate: Date(),
            basePrice: basePrice,
            volatility: volatility
        )
    }
    
    /// Generate aligned sample data with custom volatility
    static func generateAlignedSampleData(
        count: Int = 200,
        timeframe: RLChartTimeframe,
        endDate: Date = Date(),
        basePrice: Double = 100.0,
        volatility: Double = 0.02
    ) -> [RLCandleDTO] {
        var candles: [RLCandleDTO] = []
        var currentPrice = basePrice
        
        let alignedEndDate = alignToTimeframe(date: endDate, timeframe: timeframe)
        var currentDate = alignedEndDate
        
        for _ in 0..<count {
            let candle = RLCandleDTO.randomWithVolatility(
                basePrice: currentPrice,
                timestamp: currentDate,
                volatility: volatility
            )
            candles.append(candle)
            currentPrice = candle.close
            currentDate = currentDate.addingTimeInterval(-timeframe.seconds)
        }
        
        return candles.reversed()
    }
    
    // MARK: - Time Alignment Helpers
    
    private static func alignToTimeframe(date: Date, timeframe: RLChartTimeframe) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        
        components.second = 0
        
        switch timeframe {
        case .m1:
            break
        case .m5:
            if let minute = components.minute {
                components.minute = (minute / 5) * 5
            }
        case .m15:
            if let minute = components.minute {
                components.minute = (minute / 15) * 15
            }
        case .m30:
            if let minute = components.minute {
                components.minute = (minute / 30) * 30
            }
        case .h1:
            components.minute = 0
        case .h4:
            components.minute = 0
            if let hour = components.hour {
                components.hour = (hour / 4) * 4
            }
        case .d1:
            components.hour = 0
            components.minute = 0
        case .w1:
            components.hour = 0
            components.minute = 0
            if let date = calendar.date(from: components) {
                let weekday = calendar.component(.weekday, from: date)
                let daysFromMonday = (weekday + 5) % 7
                if let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) {
                    return monday
                }
            }
        case .mn:
            components.day = 1
            components.hour = 0
            components.minute = 0
        }
        
        return calendar.date(from: components) ?? date
    }
    
    // MARK: - Symbol-Specific Configuration
    
    private static func defaultBasePrice(for symbol: RLTradingSymbolDTO) -> Double {
        switch symbol.assetClassEnum {
        case .forex:
            if symbol.ticker.contains("JPY") {
                return 150.0
            } else {
                return 1.08
            }
        case .crypto:
            if symbol.ticker.contains("BTC") {
                return 45000.0
            } else if symbol.ticker.contains("ETH") {
                return 2500.0
            } else {
                return 1.0
            }
        case .stocks:
            return 150.0
        case .commodities:
            if symbol.ticker.contains("GOLD") || symbol.ticker.contains("XAU") {
                return 2000.0
            } else if symbol.ticker.contains("OIL") || symbol.ticker.contains("CL") {
                return 75.0
            } else {
                return 100.0
            }
        case .indices:
            if symbol.ticker.contains("SPX") || symbol.ticker.contains("SP500") {
                return 4500.0
            } else if symbol.ticker.contains("NDX") || symbol.ticker.contains("NASDAQ") {
                return 15000.0
            } else if symbol.ticker.contains("DJI") || symbol.ticker.contains("DOW") {
                return 35000.0
            } else {
                return 1000.0
            }
        case .futures:
            return 100.0
        case .none:
            return symbol.currentPrice ?? 100.0
        }
    }
    
    private static func defaultVolatility(for symbol: RLTradingSymbolDTO) -> Double {
        switch symbol.assetClassEnum {
        case .forex:
            return 0.003
        case .crypto:
            return 0.03
        case .stocks:
            return 0.015
        case .commodities:
            return 0.02
        case .indices:
            return 0.01
        case .futures:
            return 0.02
        case .none:
            return 0.01
        }
    }
    
    // MARK: - Enhanced Random Generation
    
    static func randomWithVolatility(
        basePrice: Double,
        timestamp: Date,
        volatility: Double
    ) -> RLCandleDTO {
        random(basePrice: basePrice, timestamp: timestamp, volatility: volatility)
    }
    
    static func random(
        basePrice: Double,
        timestamp: Date,
        volatility: Double = 0.02
    ) -> RLCandleDTO {
        let open = basePrice + (Double.random(in: -volatility...volatility) * basePrice)
        let close = open + (Double.random(in: -volatility...volatility) * basePrice)
        let bodyHigh = max(open, close)
        let bodyLow = min(open, close)
        let high = bodyHigh + (Double.random(in: 0...(volatility / 2)) * basePrice)
        let low = bodyLow - (Double.random(in: 0...(volatility / 2)) * basePrice)
        let volume = Double.random(in: 100_000...1_000_000)
        
        return RLCandleDTO(
            timestamp: timestamp,
            timestampFormatted: formatTimestamp(timestamp),
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            volumeFormatted: formatVolume(volume)
        )
    }
    
    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private static func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.2fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.2fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.2fK", volume / 1_000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}
