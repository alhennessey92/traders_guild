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
    
    @Published var candles: [CandleDTO] = []
    @Published var currentPrice: Double = 0
    @Published var priceRange: (min: Double, max: Double) = (0, 0)
    
    // MARK: - Symbol & Timeframe Context
    
    /// Current trading symbol - needed for proper price generation and formatting
    var currentSymbol: TradingSymbolDTO?
    
    /// Current timeframe - needed for proper timestamp alignment
    var currentTimeframe: ChartTimeframe = .h1
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var basePrice: Double = 100.0
    private let maxCandles = 500
    
    // MARK: - Initialization
    
    init() {
        // Generate default data immediately so chart isn't empty on launch
        // This will be replaced when symbol loads
        loadDefaultData()
    }
    
    deinit {
        stopDataGeneration()
    }
    
    // MARK: - Immediate Default Data (prevents empty chart on launch)
    
    /// Load default data immediately - prevents blank chart on app launch
    private func loadDefaultData() {
        // Generate quick default data at a typical forex price
        candles = CandleDTO.generateAlignedSampleData(
            count: 100,  // Fewer candles for faster initial load
            timeframe: .h1,
            endDate: Date(),
            basePrice: 1.08  // Typical EUR/USD price
        )
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }
    
    // MARK: - Primary Data Generation Methods
    
    /// Regenerate mock data for a specific symbol and timeframe
    func regenerateMockData(symbol: TradingSymbolDTO, timeframe: ChartTimeframe) {
        stopDataGeneration()
        
        self.currentSymbol = symbol
        self.currentTimeframe = timeframe
        
        candles = CandleDTO.generateSampleData(
            count: timeframe.initialCandlesCount,
            timeframe: timeframe,
            symbol: symbol
        )
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
        
        startDataGeneration()
    }
    
    /// Regenerate for current symbol with new timeframe
    func regenerateMockData(timeframe: ChartTimeframe) {
        self.currentTimeframe = timeframe
        
        if let symbol = currentSymbol {
            regenerateMockData(symbol: symbol, timeframe: timeframe)
        } else {
            regenerateMockDataDefault(timeframe: timeframe)
        }
    }
    
    /// Regenerate for current timeframe with new symbol
    func regenerateMockData(symbol: TradingSymbolDTO) {
        regenerateMockData(symbol: symbol, timeframe: currentTimeframe)
    }
    
    /// Fallback when no symbol is set
    private func regenerateMockDataDefault(timeframe: ChartTimeframe) {
        stopDataGeneration()
        
        self.currentTimeframe = timeframe
        
        candles = CandleDTO.generateAlignedSampleData(
            count: timeframe.initialCandlesCount,
            timeframe: timeframe,
            endDate: Date(),
            basePrice: basePrice > 0 ? basePrice : 100.0
        )
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
        
        startDataGeneration()
    }
    
    // MARK: - Legacy Methods
    
    func regenerateMockData() {
        if let symbol = currentSymbol {
            regenerateMockData(symbol: symbol, timeframe: currentTimeframe)
        } else {
            regenerateMockDataDefault(timeframe: currentTimeframe)
        }
    }
    
    func regenerateMockData(candleCount: Int) {
        stopDataGeneration()
        
        if let symbol = currentSymbol {
            candles = CandleDTO.generateSampleData(
                count: candleCount,
                timeframe: currentTimeframe,
                symbol: symbol
            )
        } else {
            candles = CandleDTO.generateAlignedSampleData(
                count: candleCount,
                timeframe: currentTimeframe,
                endDate: Date(),
                basePrice: basePrice > 0 ? basePrice : 100.0
            )
        }
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
        
        startDataGeneration()
    }
    
    func regenerateMockData(basePrice: Double) {
        stopDataGeneration()
        
        self.basePrice = basePrice
        
        if let symbol = currentSymbol {
            var tempCandles: [CandleDTO] = []
            var currentPriceVal = basePrice
            let volatility = defaultVolatility(for: symbol)
            
            let alignedEndDate = alignToTimeframe(date: Date(), timeframe: currentTimeframe)
            var currentDate = alignedEndDate
            
            for _ in 0..<currentTimeframe.initialCandlesCount {
                let candle = CandleDTO.randomWithVolatility(
                    basePrice: currentPriceVal,
                    timestamp: currentDate,
                    volatility: volatility
                )
                tempCandles.append(candle)
                currentPriceVal = candle.close
                currentDate = currentDate.addingTimeInterval(-currentTimeframe.seconds)
            }
            
            candles = tempCandles.reversed()
        } else {
            candles = CandleDTO.generateAlignedSampleData(
                count: currentTimeframe.initialCandlesCount,
                timeframe: currentTimeframe,
                endDate: Date(),
                basePrice: basePrice
            )
        }
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
        }
        
        startDataGeneration()
    }
    
    // MARK: - Timer Management
    
    /// Timer for new candle generation (based on timeframe)
    private var candleTimer: Timer?
    
    /// Timer for tick updates (fast price changes within current candle)
    private var tickTimer: Timer?
    
    /// The timestamp when the current candle started
    private var currentCandleStartTime: Date?
    
    func startDataGeneration() {
        stopDataGeneration()
        
        // Start tick timer for live price updates (every 0.8 seconds)
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.generateTickUpdate()
        }
        
        // Start candle timer based on timeframe
        let candleInterval: TimeInterval
        switch currentTimeframe {
        case .m1:
            candleInterval = 60.0   // New candle every minute
        case .m5:
            candleInterval = 300.0  // Every 5 minutes
        case .m15:
            candleInterval = 900.0  // Every 15 minutes
        case .m30:
            candleInterval = 1800.0 // Every 30 minutes
        case .h1:
            candleInterval = 3600.0 // Every hour
        case .h4:
            candleInterval = 14400.0 // Every 4 hours
        default:
            candleInterval = 60.0   // Fallback to 1 minute for demo
        }
        
        // For demo purposes, use accelerated time (1 candle per X seconds)
        let demoInterval: TimeInterval
        switch currentTimeframe {
        case .m1:
            demoInterval = 10.0   // New M1 candle every 10 seconds
        case .m5:
            demoInterval = 15.0   // New M5 candle every 15 seconds
        case .m15, .m30:
            demoInterval = 20.0
        default:
            demoInterval = 25.0
        }
        
        candleTimer = Timer.scheduledTimer(withTimeInterval: demoInterval, repeats: true) { [weak self] _ in
            self?.closeCurrentCandleAndStartNew()
        }
        
        // Initialize current candle start time
        currentCandleStartTime = Date()
    }
    
    func stopDataGeneration() {
        timer?.invalidate()
        timer = nil
        candleTimer?.invalidate()
        candleTimer = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }
    
    // MARK: - Tick Data Updates
    
    /// Generate a tick update - modifies the current (last) candle
    /// This simulates real-time price movement within a candle
    private func generateTickUpdate() {
        guard !candles.isEmpty else { return }
        
        let volatility = currentSymbol.map { defaultVolatility(for: $0) } ?? 0.02
        
        // Smaller tick movements (fraction of candle volatility)
        let tickVolatility = volatility * 0.3
        
        // Generate new tick price
        let priceChange = basePrice * Double.random(in: -tickVolatility...tickVolatility)
        let newPrice = basePrice + priceChange
        
        // Update the last candle with new tick
        updateCurrentCandle(withTick: newPrice)
        
        // Update current price display
        currentPrice = newPrice
        basePrice = newPrice
    }
    
    /// Update the current (last) candle with a new tick price
    /// - Parameters:
    ///   - tickPrice: The new tick price
    ///   - tickVolume: Optional volume for this tick (uses random if nil - for mock data)
    private func updateCurrentCandle(withTick tickPrice: Double, tickVolume: Double? = nil) {
        guard !candles.isEmpty else { return }
        
        let lastCandle = candles[candles.count - 1]
        
        // Calculate new volume (use provided tick volume or generate random for mock)
        let volumeIncrement = tickVolume ?? Double.random(in: 100...1000)
        let newVolume = (lastCandle.volume ?? 0) + volumeIncrement
        
        // Update candle with new tick data
        let updatedCandle = CandleDTO(
            id: lastCandle.id,  // Keep same ID when updating
            timestamp: lastCandle.timestamp,
            timestampFormatted: lastCandle.timestampFormatted,  // Keep same formatted timestamp
            open: lastCandle.open,
            high: max(lastCandle.high, tickPrice),
            low: min(lastCandle.low, tickPrice),
            close: tickPrice,
            volume: newVolume,
            volumeFormatted: formatVolume(newVolume)
        )
        
        candles[candles.count - 1] = updatedCandle
        
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
    ///   - volume: Optional tick volume
    ///   - timestamp: Optional tick timestamp (uses current time if nil)
    func processRealTick(price: Double, volume: Double? = nil, timestamp: Date? = nil) {
        // Update current price display immediately
        currentPrice = price
        basePrice = price
        
        // Update the current candle
        updateCurrentCandle(withTick: price, tickVolume: volume)
    }
    
    /// Process a complete candle from a data feed
    /// Use this when receiving historical or completed candles
    /// - Parameter candle: The complete candle data
    func processRealCandle(_ candle: CandleDTO) {
        // Check if this candle should update the last one or be appended
        if let lastCandle = candles.last {
            if candle.timestamp == lastCandle.timestamp {
                // Same timestamp - update existing candle
                candles[candles.count - 1] = candle
            } else if candle.timestamp > lastCandle.timestamp {
                // New candle - append
                candles.append(candle)
                
                if candles.count > maxCandles {
                    candles.removeFirst(candles.count - maxCandles)
                }
            }
            // Older candles are ignored (historical data should use updateWithMarketData)
        } else {
            candles.append(candle)
        }
        
        currentPrice = candle.close
        basePrice = candle.close
        updatePriceRange()
    }
    
    /// Switch between mock and real data modes
    /// - Parameter useMockData: If true, generates mock tick data. If false, stops mock generation.
    func setDataMode(useMockData: Bool) {
        if useMockData {
            startDataGeneration()
        } else {
            // Stop mock data generation - real data will come via processRealTick/processRealCandle
            stopDataGeneration()
        }
    }
    
    /// Close the current candle and start a new one
    private func closeCurrentCandleAndStartNew() {
        guard !candles.isEmpty else { return }
        
        let lastTimestamp = candles.last?.timestamp ?? Date()
        let newTimestamp = lastTimestamp.addingTimeInterval(currentTimeframe.seconds)
        let alignedTimestamp = alignToTimeframe(date: newTimestamp, timeframe: currentTimeframe)
        
        // Create new candle starting at current price
        let newVolume = Double.random(in: 10000...50000)
        let newCandle = CandleDTO(
            id: UUID(),
            timestamp: alignedTimestamp,
            timestampFormatted: formatTimestamp(alignedTimestamp),
            open: currentPrice,
            high: currentPrice,
            low: currentPrice,
            close: currentPrice,
            volume: newVolume,
            volumeFormatted: formatVolume(newVolume)
        )
        
        candles.append(newCandle)
        currentCandleStartTime = Date()
        
        if candles.count > maxCandles {
            candles.removeFirst(candles.count - maxCandles)
        }
        
        updatePriceRange()
    }
    
    // MARK: - Legacy Candle Generation (kept for compatibility)
    
    private func generateNewCandle() {
        guard !candles.isEmpty else { return }
        
        let lastTimestamp = candles.last?.timestamp ?? Date()
        let newTimestamp = lastTimestamp.addingTimeInterval(currentTimeframe.seconds)
        let alignedTimestamp = alignToTimeframe(date: newTimestamp, timeframe: currentTimeframe)
        
        let volatility = currentSymbol.map { defaultVolatility(for: $0) } ?? 0.02
        
        let newCandle = CandleDTO.randomWithVolatility(
            basePrice: basePrice,
            timestamp: alignedTimestamp,
            volatility: volatility
        )
        
        candles.append(newCandle)
        currentPrice = newCandle.close
        basePrice = newCandle.close
        
        if candles.count > maxCandles {
            candles.removeFirst(candles.count - maxCandles)
        }
        
        updatePriceRange()
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
            return symbol.formatPrice(price)
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
        
        switch symbol.assetClass {
        case .forex:
            return symbol.ticker.contains("JPY") ? 3 : 5
        case .crypto:
            if currentPrice > 1000 { return 2 }
            else if currentPrice > 1 { return 4 }
            else { return 6 }
        case .stocks, .commodities, .futures:
            return 2
        case .indices:
            return currentPrice > 10000 ? 0 : 2
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
    
    func candles(from startDate: Date, to endDate: Date) -> [CandleDTO] {
        return candles.filter { candle in
            candle.timestamp >= startDate && candle.timestamp <= endDate
        }
    }
    
    func recentCandles(count: Int) -> [CandleDTO] {
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
    
    func updateWithMarketData(_ data: [CandleDTO]) {
        candles = data
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }
    
    func addRealtimeCandle(_ candle: CandleDTO) {
        candles.append(candle)
        currentPrice = candle.close
        basePrice = candle.close
        
        if candles.count > maxCandles {
            candles.removeFirst()
        }
        
        updatePriceRange()
    }
    
    // MARK: - Helper Methods
    
    private func defaultVolatility(for symbol: TradingSymbolDTO) -> Double {
        switch symbol.assetClass {
        case .forex: return 0.003
        case .crypto: return 0.03
        case .stocks: return 0.015
        case .commodities: return 0.02
        case .indices: return 0.01
        case .futures: return 0.02
        }
    }
    
    private func alignToTimeframe(date: Date, timeframe: ChartTimeframe) -> Date {
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
    
    // MARK: - CandleDTO Formatting Helpers
    
    /// Format timestamp for CandleDTO
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format volume for CandleDTO
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
