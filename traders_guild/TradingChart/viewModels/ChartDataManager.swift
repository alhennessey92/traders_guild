//
//  ChartDataManager.swift
//  traders_guild
//
//  UPDATED VERSION v3 - Live tick data + Real data integration ready
//
//  ============================================================================
//  REAL DATA INTEGRATION GUIDE
//  ============================================================================
//
//  When ready to switch from mock data to real data (MetaTrader, broker API, etc.):
//
//  1. INITIAL LOAD (Historical Data):
//     - Fetch historical candles from your data source
//     - Call: dataManager.updateWithMarketData(candles)
//
//  2. REAL-TIME TICKS (WebSocket/Streaming):
//     - When you receive a price tick, call:
//       dataManager.processRealTick(price: 1.0850, volume: 100, timestamp: Date())
//     - This updates the current candle in real-time
//
//  3. COMPLETED CANDLES (New candle notifications):
//     - When a new candle completes, call:
//       dataManager.processRealCandle(candle)
//
//  4. SWITCHING MODES:
//     - To stop mock data: dataManager.setDataMode(useMockData: false)
//     - To resume mock data: dataManager.setDataMode(useMockData: true)
//
//  5. SYMBOL/TIMEFRAME CHANGES:
//     - When user changes symbol/timeframe:
//       a. Stop current data: dataManager.stopDataGeneration()
//       b. Fetch new historical data
//       c. Call: dataManager.updateWithMarketData(newCandles)
//       d. Resume real-time feed for new symbol
//
//  ============================================================================

import SwiftUI
import Combine
import Foundation

class ChartDataManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var candles: [RLCandleDTO] = []
    @Published var currentPrice: Double = 0
    @Published var priceRange: (min: Double, max: Double) = (0, 0)
    
    // MARK: - Symbol & Timeframe Context
    
    /// Current trading symbol - needed for proper price generation and formatting
    var currentSymbol: RLTradingSymbolDTO?
    
    /// Current timeframe - needed for proper timestamp alignment
    var currentTimeframe: RLChartTimeframe = .h1
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var basePrice: Double = 100.0
    private let maxCandles = 500
    private let maxRealtimeFallbackInsert = 120
    
    // MARK: - Initialization
    
    init() {
        // Chart will be empty until real data is loaded from backend
        // This prevents showing mock data
    }
    
    deinit {
        stopDataGeneration()
    }
    
    /// Update the current (last) candle with a new tick price
    /// - Parameters:
    ///   - tickPrice: The new tick price
    ///   - tickVolume: Volume for this tick (required for real data)
    private func updateCurrentCandle(at index: Int, withTick tickPrice: Double, tickVolume: Double) {
        guard index >= 0 && index < candles.count else { return }

        let lastCandle = candles[index]
        
        // Calculate new volume (use provided tick volume)
        let newVolume = (lastCandle.volume ?? 0) + tickVolume
        
        // Update candle with new tick data
        let updatedCandle = RLCandleDTO(
            timestamp: lastCandle.timestamp,
            timestampFormatted: lastCandle.timestampFormatted,  // Keep same formatted timestamp
            open: lastCandle.open,
            high: max(lastCandle.high, tickPrice),
            low: min(lastCandle.low, tickPrice),
            close: tickPrice,
            volume: newVolume,
            volumeFormatted: formatVolume(newVolume),
            isGapFill: false
        )
        
        candles[index] = updatedCandle
        
        // Update price range if needed
        if tickPrice > priceRange.max || tickPrice < priceRange.min {
            updatePriceRange()
        }
    }
    
    // MARK: - Real Data Integration Points
    
    /// Process a real tick from a data feed (WebSocket, API, etc.)
    /// Call this method when you receive real-time price updates
    /// - Parameters:
    ///   - price: The tick price
    ///   - volume: Tick volume (required)
    ///   - timestamp: Optional tick timestamp (uses current time if nil)
    func processRealTick(price: Double, volume: Double, timestamp: Date? = nil) {
        // Update current price display immediately
        currentPrice = price
        basePrice = price

        guard !candles.isEmpty else { return }

        let tickTime = timestamp ?? Date()
        let bucketTimestamp = alignedCandleTimestamp(for: tickTime)

        if let lastCandle = candles.last {
            if bucketTimestamp > lastCandle.timestamp {
                let fallbackCandles = fillRealtimeGap(from: lastCandle, to: bucketTimestamp)
                if !fallbackCandles.isEmpty {
                    candles.append(contentsOf: fallbackCandles)
                }

                // Start a new in-progress candle bucket.
                let newCandle = RLCandleDTO(
                    timestamp: bucketTimestamp,
                    timestampFormatted: nil,
                    open: price,
                    high: price,
                    low: price,
                    close: price,
                    volume: volume,
                    volumeFormatted: formatVolume(volume),
                    isGapFill: false
                )
                candles.append(newCandle)
                if candles.count > maxCandles {
                    candles.removeFirst(candles.count - maxCandles)
                }
                updatePriceRange()
            } else if bucketTimestamp == lastCandle.timestamp {
                updateCurrentCandle(at: candles.count - 1, withTick: price, tickVolume: volume)
            } else {
                if let existingIndex = indexOfCandle(with: bucketTimestamp),
                   candles[existingIndex].isGapFill {
                    candles[existingIndex] = RLCandleDTO(
                        timestamp: bucketTimestamp,
                        timestampFormatted: candles[existingIndex].timestampFormatted,
                        open: price,
                        high: price,
                        low: price,
                        close: price,
                        volume: volume,
                        volumeFormatted: formatVolume(volume),
                        isGapFill: false
                    )
                    updatePriceRange()
                    return
                }
                // Ignore stale tick for an older bucket unless replacing a placeholder.
                return
            }
        }
    }

    private func fillRealtimeGap(from lastCandle: RLCandleDTO, to newTimestamp: Date) -> [RLCandleDTO] {
        let step = max(1, currentTimeframe.seconds)
        var nextTimestamp = lastCandle.timestamp.addingTimeInterval(step)
        var generated: [RLCandleDTO] = []

        while nextTimestamp < newTimestamp && generated.count < maxRealtimeFallbackInsert {
            let close = generated.last?.close ?? lastCandle.close
            generated.append(
                RLCandleDTO(
                    timestamp: nextTimestamp,
                    timestampFormatted: nil,
                    open: close,
                    high: close,
                    low: close,
                    close: close,
                    volume: 0,
                    volumeFormatted: formatVolume(0),
                    isGapFill: true
                )
            )
            nextTimestamp = nextTimestamp.addingTimeInterval(step)
        }

        return generated
    }

    private func indexOfCandle(with timestamp: Date) -> Int? {
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

    /// Align tick timestamps to the current timeframe bucket boundary.
    private func alignedCandleTimestamp(for timestamp: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp)
        components.second = 0

        switch currentTimeframe {
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
    
    /// Process a complete candle from a data feed
    /// Use this when receiving historical or completed candles
    /// - Parameter candle: The complete candle data
    @discardableResult
    func processRealCandle(_ candle: RLCandleDTO) -> Int {
        var trimmedCount = 0
        if let existingIndex = indexOfCandle(with: candle.timestamp) {
            candles[existingIndex] = candle
        } else if let lastCandle = candles.last {
            if candle.timestamp > lastCandle.timestamp {
                let fallbackCandles = fillRealtimeGap(from: lastCandle, to: candle.timestamp)
                if !fallbackCandles.isEmpty {
                    candles.append(contentsOf: fallbackCandles)
                }
                candles.append(candle)

                if candles.count > maxCandles {
                    trimmedCount = candles.count - maxCandles
                    candles.removeFirst(trimmedCount)
                }
            }
            // Older candles are ignored unless they match an existing placeholder timestamp.
        } else {
            candles.append(candle)
        }
        
        currentPrice = candle.close
        basePrice = candle.close
        updatePriceRange()
        return trimmedCount
    }
    
    // MARK: - Timer Management (for cleanup only - no mock data generation)
    
    /// Timer for new candle generation (based on timeframe)
    private var candleTimer: Timer?
    
    /// Timer for tick updates (fast price changes within current candle)
    private var tickTimer: Timer?
    
    func stopDataGeneration() {
        candleTimer?.invalidate()
        candleTimer = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }
    
    // MARK: - Price Range
    
    func updatePriceRange() {
        guard !candles.isEmpty else {
            priceRange = (0, 100)
            return
        }
        
        let allLows = candles.map { $0.low }
        let allHighs = candles.map { $0.high }
        
        guard let minPrice = allLows.min(),
              let maxPrice = allHighs.max() else {
            priceRange = (0, 100)
            return
        }
        
        let padding = (maxPrice - minPrice) * 0.1
        priceRange = (minPrice - padding, maxPrice + padding)
    }
    
    // MARK: - Price Formatting (Symbol-Aware)
    
    /// Format a price using the current symbol's conventions
    func formatPrice(_ price: Double) -> String {
        if let symbol = currentSymbol {
            // RLTradingSymbolDTO doesn't have formatPrice method, use decimal places
            let decimals = priceDecimalPlaces
            return String(format: "%.\(decimals)f", price)
        } else {
            // Fallback based on price magnitude
            return formatPriceByMagnitude(price)
        }
    }
    
    /// Get the number of decimal places for current symbol
    var priceDecimalPlaces: Int {
        guard let symbol = currentSymbol else {
            return decimalPlacesForMagnitude(currentPrice)
        }
        
        // Use decimalPlaces from RLTradingSymbolDTO if available, otherwise infer
        if symbol.decimalPlaces > 0 {
            return symbol.decimalPlaces
        }
        
        // Fallback based on asset class
        switch symbol.assetClass.lowercased() {
        case "forex":
            return symbol.ticker.contains("JPY") ? 3 : 5
        case "crypto":
            if currentPrice > 1000 { return 2 }
            else if currentPrice > 1 { return 4 }
            else { return 6 }
        case "stocks", "commodities", "futures":
            return 2
        case "indices":
            return currentPrice > 10000 ? 0 : 2
        default:
            return 2
        }
    }
    
    /// Fallback formatting based on price magnitude
    private func formatPriceByMagnitude(_ price: Double) -> String {
        let decimals = decimalPlacesForMagnitude(price)
        return String(format: "%.\(decimals)f", price)
    }
    
    private func decimalPlacesForMagnitude(_ price: Double) -> Int {
        let absPrice = abs(price)
        if absPrice >= 1000 { return 2 }
        else if absPrice >= 100 { return 2 }
        else if absPrice >= 10 { return 3 }
        else if absPrice >= 1 { return 4 }
        else { return 5 }
    }
    
    // MARK: - Data Access Methods
    
    func candles(from startDate: Date, to endDate: Date) -> [RLCandleDTO] {
        return candles.filter { candle in
            candle.timestamp >= startDate && candle.timestamp <= endDate
        }
    }
    
    func recentCandles(count: Int) -> [RLCandleDTO] {
        guard count > 0 else { return [] }
        let startIndex = max(0, candles.count - count)
        return Array(candles.suffix(from: startIndex))
    }
    
    func movingAverage(period: Int) -> [Double] {
        guard period > 0 && candles.count >= period else { return [] }
        
        var movingAverages: [Double] = []
        
        for i in (period-1)..<candles.count {
            let relevantCandles = candles[(i-period+1)...i]
            let sum = relevantCandles.reduce(0) { $0 + $1.close }
            movingAverages.append(sum / Double(period))
        }
        
        return movingAverages
    }
    
    // MARK: - Price Calculations
    
    func price(at yPosition: CGFloat, in height: CGFloat, scale: CGFloat, offset: CGFloat) -> Double {
        let normalizedY = (height - yPosition - offset) / (height * scale)
        return priceRange.min + (normalizedY * (priceRange.max - priceRange.min))
    }
    
    func yPosition(for price: Double, in height: CGFloat, scale: CGFloat, offset: CGFloat) -> CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return height - (CGFloat(normalizedPrice) * height * scale) - offset
    }
    
    // MARK: - External Data Methods
    
    func updateWithMarketData(_ data: [RLCandleDTO]) {
        candles = data
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }
    
    func addRealtimeCandle(_ candle: RLCandleDTO) {
        candles.append(candle)
        currentPrice = candle.close
        basePrice = candle.close
        
        if candles.count > maxCandles {
            candles.removeFirst()
        }
        
        updatePriceRange()
    }
    
    // MARK: - Helper Methods
    
    private func alignToTimeframe(date: Date, timeframe: RLChartTimeframe) -> Date {
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
        case .mn:
            components.day = 1
            components.hour = 0
            components.minute = 0
        }
        
        return calendar.date(from: components) ?? date
    }
    
    // MARK: - RLCandleDTO Formatting Helpers
    
    /// Format timestamp for RLCandleDTO
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format volume for RLCandleDTO
    private func formatVolume(_ volume: Double?) -> String? {
        guard let volume = volume else { return nil }
        
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
