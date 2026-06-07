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

struct HistoricalMergeResult: Equatable {
    let prependedCount: Int
    let insertedCount: Int
    let duplicateCount: Int
    let deferredPriceRangeUpdate: Bool

    var didMutate: Bool { prependedCount > 0 || insertedCount > 0 }
}

class ChartDataManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var candles: [RLCandleDTO] = []
    @Published var currentPrice: Double = 0
    @Published var priceRange: (min: Double, max: Double) = (0, 0)
    @Published private(set) var lastPrependedCandleCount: Int = 0
    @Published private(set) var hasDeferredHistoricalPriceRangeUpdate = false

    /// Number of historical candles inserted before the original visual index origin.
    ///
    /// This is intentionally not `@Published`: it is updated immediately before `candles` is
    /// published so a single view invalidation sees both the new array and the corrected visual
    /// index origin. That keeps prepends from moving the visible chart during a pan.
    private(set) var historicalRenderIndexOffset: Int = 0

    private var focusedHistoricalPriceRangeWindow: Range<Int>?
    
    // MARK: - Symbol & Timeframe Context
    
    /// Current trading symbol - needed for proper price generation and formatting
    var currentSymbol: RLTradingSymbolDTO?
    
    /// Current timeframe - needed for proper timestamp alignment
    var currentTimeframe: RLChartTimeframe = .h1
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var basePrice: Double = 100.0
    private let maxCandles = Int.max
    private let maxRealtimeFallbackInsert = 120

    /// Coalesces tick-driven `@Published` updates so SwiftUI is invalidated at most ~20Hz
    /// instead of at the raw WebSocket tick rate (which can hit 50–100Hz). Without this
    /// the entire view tree observing `chartViewModel`/`chartDataManager` is rebuilt on
    /// every tick, even when the chart isn't on screen.
    private var pendingTickCandles: [RLCandleDTO]?
    private var pendingTickPrice: Double?
    private var pendingTickFlushScheduled = false
    private let tickPublishCoalesceWindow: TimeInterval = 0.05
    
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
        let result = RealtimeCandleStreamReducer.processTick(
            candles: pendingTickCandles ?? candles,
            timeframe: currentTimeframe,
            price: price,
            volume: volume,
            timestamp: timestamp,
            maxCandles: maxCandles,
            maxRealtimeFallbackInsert: maxRealtimeFallbackInsert
        )
        pendingTickCandles = result.candles
        pendingTickPrice = result.currentPrice
        basePrice = result.currentPrice

        guard !pendingTickFlushScheduled else { return }
        pendingTickFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + tickPublishCoalesceWindow) { [weak self] in
            self?.flushPendingTick()
        }
    }

    private func flushPendingTick() {
        pendingTickFlushScheduled = false
        if let pendingCandles = pendingTickCandles {
            candles = pendingCandles
            pendingTickCandles = nil
        }
        if let pendingPrice = pendingTickPrice {
            currentPrice = pendingPrice
            pendingTickPrice = nil
        }
        updatePriceRange()
    }
    
    /// Process a complete candle from a data feed
    /// Use this when receiving historical or completed candles
    /// - Parameter candle: The complete candle data
    @discardableResult
    func processRealCandle(_ candle: RLCandleDTO) -> Int {
        flushPendingTick()
        let result = RealtimeCandleStreamReducer.processCompletedCandle(
            candles: candles,
            timeframe: currentTimeframe,
            candle: candle,
            maxCandles: maxCandles,
            maxRealtimeFallbackInsert: maxRealtimeFallbackInsert
        )
        candles = result.candles
        currentPrice = result.currentPrice
        basePrice = result.currentPrice
        updatePriceRange()
        return result.trimmedCount
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
    
    func updatePriceRange(includeDeferredHistorical: Bool = false) {
        if includeDeferredHistorical {
            hasDeferredHistoricalPriceRangeUpdate = false
            focusedHistoricalPriceRangeWindow = nil
        }

        guard !candles.isEmpty else {
            priceRange = (0, 100)
            return
        }

        guard let calculatedRange = Self.calculatedPriceRange(
            from: eligibleCandlesForPriceRange(includeDeferredHistorical: includeDeferredHistorical),
            currentPrice: currentPrice
        ) else {
            priceRange = (0, 100)
            return
        }

        priceRange = calculatedRange
    }
    
    // MARK: - Price Formatting (Symbol-Aware)
    
    /// Format a price using the current symbol's conventions
    func formatPrice(_ price: Double) -> String {
        if currentSymbol != nil {
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
        pendingTickCandles = nil
        pendingTickPrice = nil
        lastPrependedCandleCount = 0
        hasDeferredHistoricalPriceRangeUpdate = false
        historicalRenderIndexOffset = 0
        focusedHistoricalPriceRangeWindow = nil
        candles = Self.sortedUniqueCandles(data)
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }

    @discardableResult
    func mergeHistoricalMarketData(_ data: [RLCandleDTO]) -> Int {
        mergeHistoricalMarketData(data, preservePriceRangeForPurePrepend: false).prependedCount
    }

    @discardableResult
    func mergeHistoricalMarketData(
        _ data: [RLCandleDTO],
        preservePriceRangeForPurePrepend: Bool,
        beforePublishingPrepend: ((Int) -> Void)? = nil
    ) -> HistoricalMergeResult {
        guard !data.isEmpty else {
            lastPrependedCandleCount = 0
            return HistoricalMergeResult(
                prependedCount: 0,
                insertedCount: 0,
                duplicateCount: 0,
                deferredPriceRangeUpdate: false
            )
        }

        flushPendingTick()
        guard let oldFirstTimestamp = candles.first?.timestamp else {
            historicalRenderIndexOffset = 0
            candles = Self.sortedUniqueCandles(data)
            lastPrependedCandleCount = 0
            updatePriceRange()

            if let lastCandle = candles.last {
                currentPrice = lastCandle.close
                basePrice = lastCandle.close
            }

            return HistoricalMergeResult(
                prependedCount: 0,
                insertedCount: candles.count,
                duplicateCount: max(0, data.count - candles.count),
                deferredPriceRangeUpdate: false
            )
        }

        let existingTimestamps = Set(candles.map(\.timestamp))
        var uniqueIncoming: [RLCandleDTO] = []
        uniqueIncoming.reserveCapacity(data.count)
        var seenIncoming = Set<Date>()
        var duplicateCount = 0

        for candle in data {
            if existingTimestamps.contains(candle.timestamp) || seenIncoming.contains(candle.timestamp) {
                duplicateCount += 1
                continue
            }
            seenIncoming.insert(candle.timestamp)
            uniqueIncoming.append(candle)
        }

        guard !uniqueIncoming.isEmpty else {
            lastPrependedCandleCount = 0
            return HistoricalMergeResult(
                prependedCount: 0,
                insertedCount: 0,
                duplicateCount: duplicateCount,
                deferredPriceRangeUpdate: false
            )
        }

        let isPurePrepend = uniqueIncoming.allSatisfy { $0.timestamp < oldFirstTimestamp }
        let prependedCount = uniqueIncoming.filter { $0.timestamp < oldFirstTimestamp }.count

        if isPurePrepend {
            let oldPriceRange = priceRange
            if prependedCount > 0 {
                historicalRenderIndexOffset += prependedCount
                shiftFocusedHistoricalPriceRangeWindow(by: prependedCount)
                beforePublishingPrepend?(prependedCount)
            }
            candles = uniqueIncoming.sorted { $0.timestamp < $1.timestamp } + candles
            lastPrependedCandleCount = prependedCount

            if preservePriceRangeForPurePrepend {
                priceRange = oldPriceRange
                hasDeferredHistoricalPriceRangeUpdate = true
            } else {
                updatePriceRange()
            }
        } else {
            lastPrependedCandleCount = prependedCount
            if prependedCount > 0 {
                historicalRenderIndexOffset += prependedCount
                shiftFocusedHistoricalPriceRangeWindow(by: prependedCount)
                beforePublishingPrepend?(prependedCount)
            }
            candles = Self.sortedUniqueCandles(data + candles)
            updatePriceRange()
        }

        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }

        return HistoricalMergeResult(
            prependedCount: prependedCount,
            insertedCount: uniqueIncoming.count,
            duplicateCount: duplicateCount,
            deferredPriceRangeUpdate: isPurePrepend && preservePriceRangeForPurePrepend
        )
    }

    func consumeLastPrependedCandleCount() -> Int {
        let count = lastPrependedCandleCount
        lastPrependedCandleCount = 0
        return count
    }

    func refreshDeferredHistoricalPriceRangeIfNeeded(forCandleIndex candleIndex: Int? = nil) {
        guard hasDeferredHistoricalPriceRangeUpdate else { return }
        if let candleIndex,
           candleIndex >= historicalRenderIndexOffset {
            return
        }
        updatePriceRange(includeDeferredHistorical: true)
    }

    @discardableResult
    func focusDeferredHistoricalPriceRangeIfNeeded(forCandleIndex candleIndex: Int, visibleCandleCount: Int) -> Bool {
        guard hasDeferredHistoricalPriceRangeUpdate,
              candleIndex >= 0,
              candleIndex < historicalRenderIndexOffset,
              candleIndex < candles.count else {
            return false
        }

        if let focusedHistoricalPriceRangeWindow,
           focusedHistoricalPriceRangeWindow.contains(candleIndex) {
            return false
        }

        let radius = max(visibleCandleCount * 4, 48)
        let lowerBound = max(0, candleIndex - radius)
        let upperBound = min(candles.count, candleIndex + radius + 1)
        guard lowerBound < upperBound else { return false }

        return setFocusedHistoricalPriceRangeWindow(lowerBound..<upperBound)
    }

    @discardableResult
    func focusVisibleHistoricalPriceRangeIfNeeded(visibleStartIndex: Int, visibleCandleCount: Int) -> Bool {
        guard hasDeferredHistoricalPriceRangeUpdate,
              historicalRenderIndexOffset > 0,
              !candles.isEmpty else {
            return false
        }

        let visibleCount = max(1, visibleCandleCount)
        let boundedStart = max(0, min(candles.count - 1, visibleStartIndex))
        guard boundedStart < historicalRenderIndexOffset else {
            return clearFocusedHistoricalPriceRangeIfNeeded()
        }

        let visibleEnd = min(candles.count, boundedStart + visibleCount)
        let centerIndex = max(0, min(historicalRenderIndexOffset - 1, boundedStart + visibleCount / 2))
        let radius = max(visibleCount * 4, 48)
        let lowerBound = max(0, min(boundedStart, centerIndex - radius))
        let upperBound = min(candles.count, max(visibleEnd, centerIndex + radius + 1))
        guard lowerBound < upperBound else { return false }

        return setFocusedHistoricalPriceRangeWindow(lowerBound..<upperBound)
    }

    @discardableResult
    func clearFocusedHistoricalPriceRangeIfNeeded() -> Bool {
        guard focusedHistoricalPriceRangeWindow != nil else { return false }
        focusedHistoricalPriceRangeWindow = nil
        let oldRange = priceRange
        updatePriceRange()
        return oldRange.min != priceRange.min || oldRange.max != priceRange.max
    }
    
    func addRealtimeCandle(_ candle: RLCandleDTO) {
        lastPrependedCandleCount = 0
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

    private static func sortedUniqueCandles(_ candles: [RLCandleDTO]) -> [RLCandleDTO] {
        var byTimestamp: [Date: RLCandleDTO] = [:]
        for candle in candles {
            byTimestamp[candle.timestamp] = candle
        }
        return byTimestamp.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func eligibleCandlesForPriceRange(includeDeferredHistorical: Bool) -> [RLCandleDTO] {
        if !includeDeferredHistorical,
           hasDeferredHistoricalPriceRangeUpdate {
            if let focusedHistoricalPriceRangeWindow {
                let lowerBound = max(0, min(candles.count, focusedHistoricalPriceRangeWindow.lowerBound))
                let upperBound = max(lowerBound, min(candles.count, focusedHistoricalPriceRangeWindow.upperBound))
                if lowerBound < upperBound {
                    return Array(candles[lowerBound..<upperBound])
                }
            }

            if historicalRenderIndexOffset > 0,
               historicalRenderIndexOffset < candles.count {
                return Array(candles[historicalRenderIndexOffset...])
            }
        }

        return candles
    }

    private func shiftFocusedHistoricalPriceRangeWindow(by count: Int) {
        guard count > 0,
              let window = focusedHistoricalPriceRangeWindow else {
            return
        }

        focusedHistoricalPriceRangeWindow = (window.lowerBound + count)..<(window.upperBound + count)
    }

    private func setFocusedHistoricalPriceRangeWindow(_ window: Range<Int>) -> Bool {
        focusedHistoricalPriceRangeWindow = window
        let oldRange = priceRange
        updatePriceRange()
        return oldRange.min != priceRange.min || oldRange.max != priceRange.max
    }

    private static func calculatedPriceRange(
        from candles: [RLCandleDTO],
        currentPrice: Double
    ) -> (min: Double, max: Double)? {
        guard !candles.isEmpty else { return nil }

        let rangeSource = candles.contains(where: { !$0.isGapFill })
            ? candles.filter { !$0.isGapFill }
            : candles
        let allLows = rangeSource.map { $0.low }
        let allHighs = rangeSource.map { $0.high }

        guard let minPrice = allLows.min(),
              let maxPrice = allHighs.max() else {
            return nil
        }

        let span = maxPrice - minPrice
        guard span > 0 else {
            let center = maxPrice > 0 ? maxPrice : max(currentPrice, 1)
            let padding = max(abs(center) * 0.001, 0.0001)
            return (center - padding, center + padding)
        }

        let padding = span * 0.1
        return (minPrice - padding, maxPrice + padding)
    }
}
