//
//  Candle+TimeframeGeneration.swift
//  traders_guild
//
//  Extension for generating timeframe-aligned sample data
//  Ensures timestamps fall on "nice" boundaries for realistic chart display
//

import Foundation

extension CandleDTO {
    
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
        timeframe: ChartTimeframe,
        endDate: Date = Date(),
        basePrice: Double = 100.0
    ) -> [CandleDTO] {
        var candles: [CandleDTO] = []
        var currentPrice = basePrice
        
        // Round the end date to the nearest timeframe boundary
        let alignedEndDate = alignToTimeframe(date: endDate, timeframe: timeframe)
        var currentDate = alignedEndDate
        
        for _ in 0..<count {
            // Generate candle with the aligned timestamp
            let candle = CandleDTO.random(basePrice: currentPrice, timestamp: currentDate)
            candles.append(candle)
            
            // Move to next candle's price (for realistic trends)
            currentPrice = candle.close
            
            // Move backwards in time by one timeframe interval
            currentDate = currentDate.addingTimeInterval(-timeframe.seconds)
        }
        
        // Reverse so oldest candles are first, newest at end
        return candles.reversed()
    }
    
    /// Generate sample data for a specific trading symbol
    /// Uses appropriate base price and volatility for the asset class
    /// - Parameters:
    ///   - count: Number of candles to generate
    ///   - timeframe: The chart timeframe
    ///   - symbol: The trading symbol (determines base price and characteristics)
    /// - Returns: Array of candles appropriate for the symbol
    static func generateSampleData(
        count: Int = 200,
        timeframe: ChartTimeframe,
        symbol: TradingSymbolDTO
    ) -> [CandleDTO] {
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
        timeframe: ChartTimeframe,
        endDate: Date = Date(),
        basePrice: Double = 100.0,
        volatility: Double = 0.02
    ) -> [CandleDTO] {
        var candles: [CandleDTO] = []
        var currentPrice = basePrice
        
        let alignedEndDate = alignToTimeframe(date: endDate, timeframe: timeframe)
        var currentDate = alignedEndDate
        
        for _ in 0..<count {
            let candle = CandleDTO.randomWithVolatility(
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
    
    /// Align a date to the nearest timeframe boundary
    /// - Parameters:
    ///   - date: The date to align
    ///   - timeframe: The timeframe to align to
    /// - Returns: Date rounded down to the nearest timeframe boundary
    private static func alignToTimeframe(date: Date, timeframe: ChartTimeframe) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        
        // Always zero out seconds
        components.second = 0
        
        switch timeframe {
        case .m1:
            // Already aligned to minute
            break
            
        case .m5:
            // Round down to nearest 5 minutes
            if let minute = components.minute {
                components.minute = (minute / 5) * 5
            }
            
        case .m15:
            // Round down to nearest 15 minutes
            if let minute = components.minute {
                components.minute = (minute / 15) * 15
            }
            
        case .m30:
            // Round down to nearest 30 minutes
            if let minute = components.minute {
                components.minute = (minute / 30) * 30
            }
            
        case .h1:
            // Round down to nearest hour
            components.minute = 0
            
        case .h4:
            // Round down to nearest 4 hours
            components.minute = 0
            if let hour = components.hour {
                components.hour = (hour / 4) * 4
            }
            
        case .d1:
            // Round down to start of day (market open would be different per exchange)
            components.hour = 0
            components.minute = 0
            
        case .w1:
            // Round down to start of week (Monday)
            components.hour = 0
            components.minute = 0
            // Find the Monday of this week
            if let date = calendar.date(from: components) {
                let weekday = calendar.component(.weekday, from: date)
                // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
                let daysFromMonday = (weekday + 5) % 7  // Days since last Monday
                if let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) {
                    return monday
                }
            }
            
        case .mn:
            // Round down to start of month
            components.day = 1
            components.hour = 0
            components.minute = 0
        }
        
        return calendar.date(from: components) ?? date
    }
    
    // MARK: - Symbol-Specific Configuration
    
    /// Get default base price for a trading symbol
    private static func defaultBasePrice(for symbol: TradingSymbolDTO) -> Double {
        switch symbol.assetClass {
        case .forex:
            if symbol.ticker.contains("JPY") {
                return 150.0  // USDJPY, EURJPY, etc.
            } else {
                return 1.08   // EURUSD, GBPUSD, etc.
            }
            
        case .crypto:
            if symbol.ticker.contains("BTC") {
                return 45000.0
            } else if symbol.ticker.contains("ETH") {
                return 2500.0
            } else {
                return 1.0  // Altcoins
            }
            
        case .stocks:
            return 150.0  // Typical stock price
            
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
        }
    }
    
    /// Get default volatility for a trading symbol
    private static func defaultVolatility(for symbol: TradingSymbolDTO) -> Double {
        switch symbol.assetClass {
        case .forex:
            return 0.003  // Forex is relatively stable (0.3% moves typical)
            
        case .crypto:
            return 0.03   // Crypto is volatile (3% moves common)
            
        case .stocks:
            return 0.015  // Stocks moderate volatility
            
        case .commodities:
            return 0.02   // Commodities moderate
            
        case .indices:
            return 0.01   // Indices less volatile
            
        case .futures:
            return 0.02
        }
    }
    
    // MARK: - Enhanced Random Generation
    
    /// Generate a random candle with custom volatility
    /// FIXED: Now uses proper CandleDTO initializer with all required fields
    static func randomWithVolatility(
        basePrice: Double,
        timestamp: Date,
        volatility: Double
    ) -> CandleDTO {
        // Generate open price with some variance from base
        let open = basePrice * (1.0 + Double.random(in: -volatility...volatility))
        
        // Generate close price with variance from open
        let close = open * (1.0 + Double.random(in: -volatility...volatility))
        
        // Ensure high is actually the highest value
        let bodyHigh = max(open, close)
        let bodyLow = min(open, close)
        
        // Add wicks that extend beyond the body
        let high = bodyHigh * (1.0 + Double.random(in: 0...(volatility * 0.5)))
        let low = bodyLow * (1.0 - Double.random(in: 0...(volatility * 0.5)))
        
        let volume = Double.random(in: 100_000...1_000_000)
        
        // FIXED: Use proper CandleDTO initializer
        return CandleDTO(
            id: UUID(),
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
    
    // MARK: - Formatting Helpers
    
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

// NOTE: ChartDataManager methods are now in ChartDataManager.swift
// The regenerateMockData(symbol:timeframe:) method is built into ChartDataManager directly





