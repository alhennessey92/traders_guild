//
//  ChartDataManager.swift
//  traders_guild
//
//  UPDATED VERSION v2 - Faster initial load + symbol-aware formatting
//

import SwiftUI
import Combine
import Foundation

class ChartDataManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var candles: [Candle] = []
    @Published var currentPrice: Double = 0
    @Published var priceRange: (min: Double, max: Double) = (0, 0)
    
    // MARK: - Symbol & Timeframe Context
    
    /// Current trading symbol - needed for proper price generation and formatting
    var currentSymbol: TradingSymbol?
    
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
        candles = Candle.generateAlignedSampleData(
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
    func regenerateMockData(symbol: TradingSymbol, timeframe: ChartTimeframe) {
        stopDataGeneration()
        
        self.currentSymbol = symbol
        self.currentTimeframe = timeframe
        
        candles = Candle.generateSampleData(
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
    func regenerateMockData(symbol: TradingSymbol) {
        regenerateMockData(symbol: symbol, timeframe: currentTimeframe)
    }
    
    /// Fallback when no symbol is set
    private func regenerateMockDataDefault(timeframe: ChartTimeframe) {
        stopDataGeneration()
        
        self.currentTimeframe = timeframe
        
        candles = Candle.generateAlignedSampleData(
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
            candles = Candle.generateSampleData(
                count: candleCount,
                timeframe: currentTimeframe,
                symbol: symbol
            )
        } else {
            candles = Candle.generateAlignedSampleData(
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
            var tempCandles: [Candle] = []
            var currentPriceVal = basePrice
            let volatility = defaultVolatility(for: symbol)
            
            let alignedEndDate = alignToTimeframe(date: Date(), timeframe: currentTimeframe)
            var currentDate = alignedEndDate
            
            for _ in 0..<currentTimeframe.initialCandlesCount {
                let candle = Candle.randomWithVolatility(
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
            candles = Candle.generateAlignedSampleData(
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
    
    func startDataGeneration() {
        stopDataGeneration()
        
        let interval: TimeInterval
        switch currentTimeframe {
        case .m1:
            interval = 5.0
        case .m5:
            interval = 8.0
        case .m15, .m30:
            interval = 10.0
        default:
            interval = 15.0
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.generateNewCandle()
        }
    }
    
    func stopDataGeneration() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Live Candle Generation
    
    private func generateNewCandle() {
        guard !candles.isEmpty else { return }
        
        let lastTimestamp = candles.last?.timestamp ?? Date()
        let newTimestamp = lastTimestamp.addingTimeInterval(currentTimeframe.seconds)
        let alignedTimestamp = alignToTimeframe(date: newTimestamp, timeframe: currentTimeframe)
        
        let volatility = currentSymbol.map { defaultVolatility(for: $0) } ?? 0.02
        
        let newCandle = Candle.randomWithVolatility(
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
            return symbol.symbol.contains("JPY") ? 3 : 5
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
    
    func candles(from startDate: Date, to endDate: Date) -> [Candle] {
        return candles.filter { candle in
            candle.timestamp >= startDate && candle.timestamp <= endDate
        }
    }
    
    func recentCandles(count: Int) -> [Candle] {
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
    
    func updateWithMarketData(_ data: [Candle]) {
        candles = data
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }
    
    func addRealtimeCandle(_ candle: Candle) {
        candles.append(candle)
        currentPrice = candle.close
        basePrice = candle.close
        
        if candles.count > maxCandles {
            candles.removeFirst()
        }
        
        updatePriceRange()
    }
    
    // MARK: - Helper Methods
    
    private func defaultVolatility(for symbol: TradingSymbol) -> Double {
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
}

//
//
////
////  ChartDataManager.swift
////  traders_guild
////
////  Created by Al Hennessey on 14/11/2025.
////
//
//import SwiftUI
//import Combine
//import Foundation
//
///// Manages chart data and provides real-time updates
///// This is the data source for the trading chart, handling both historical and live data
//class ChartDataManager: ObservableObject {
//    // MARK: - Published Properties
//    
//    /// Array of candles to display on the chart
//    /// Published so the view updates when new candles are added
//    @Published var candles: [Candle] = []
//    
//    /// Current/latest price for the price indicator
//    /// This is typically the close price of the most recent candle
//    @Published var currentPrice: Double = 0
//    
//    /// The price range for scaling the chart
//    /// Calculated from all visible candles plus padding
//    @Published var priceRange: (min: Double, max: Double) = (0, 0)
//    
//    // MARK: - Private Properties
//    
//    /// Timer for generating new candles in real-time
//    private var timer: Timer?
//    
//    /// Current base price for generating new sample data
//    /// This creates continuous price movement from the last candle
//    var basePrice: Double = 100.0
//    
//    /// Maximum number of candles to keep in memory
//    /// Prevents memory issues with long-running charts
//    private let maxCandles = 500
//    
//    // MARK: - Initialization
//    
//    init() {
//        loadInitialData()
//    }
//    
//    deinit {
//        // Clean up timer when manager is deallocated
//        stopDataGeneration()
//    }
//    
//    // MARK: - Data Management
//    
//    /// Load initial sample data for the chart
//    /// In production, this would load historical data from an API
//    private func loadInitialData() {
//        // Generate 100 candles of historical data
//        candles = Candle.generateSampleData(count: 200)
//        
//        // Update the price range based on loaded data
//        updatePriceRange()
//        
//        // Set current price from the latest candle
//        if let lastCandle = candles.last {
//            currentPrice = lastCandle.close
//            basePrice = lastCandle.close
//        }
//    }
//    
//    /// Start generating real-time data updates
//    /// Simulates live market data feed
//    func startDataGeneration() {
//        // Stop any existing timer to prevent duplicates
//        stopDataGeneration()
//        
//        // Create timer for real-time updates (every 5 seconds for demo)
//        // In production, this would be replaced with WebSocket or API polling
//        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
//            self?.generateNewCandle()
//        }
//    }
//    
//    /// Stop generating real-time data
//    func stopDataGeneration() {
//        timer?.invalidate()
//        timer = nil
//    }
//    
//    /// Generate a new candle and add it to the chart
//    /// Simulates receiving new market data
//    private func generateNewCandle() {
//        // Create new candle based on current price
//        let newCandle = Candle.random(
//            basePrice: basePrice,
//            timestamp: Date()
//        )
//        
//        // Add new candle to the array
//        candles.append(newCandle)
//        
//        // Update current price indicator
//        currentPrice = newCandle.close
//        
//        // Update base price for next candle generation
//        basePrice = newCandle.close
//        
//        // Remove old candles if we exceed the memory limit
//        if candles.count > maxCandles {
//            candles.removeFirst(candles.count - maxCandles)
//        }
//        
//        // Recalculate price range with new data
//        updatePriceRange()
//    }
//    
//    /// Update the price range based on all candles
//    /// This determines the Y-axis scale for the chart
//    func updatePriceRange() {
//        guard !candles.isEmpty else {
//            // Default range if no data
//            priceRange = (0, 100)
//            return
//        }
//        
//        // Find the absolute minimum and maximum prices
//        let allLows = candles.map { $0.low }
//        let allHighs = candles.map { $0.high }
//        
//        guard let minPrice = allLows.min(),
//              let maxPrice = allHighs.max() else {
//            priceRange = (0, 100)
//            return
//        }
//        
//        // Add 10% padding to the range for better visualization
//        // This prevents candles from touching the top/bottom of the chart
//        let padding = (maxPrice - minPrice) * 0.6 // TODO: make this universal to adjust the padding in settings
//        priceRange = (minPrice - padding, maxPrice + padding)
//    }
//    
//    // MARK: - Data Access Methods
//    
//    /// Get candles within a specific time range
//    /// Useful for filtering data by date
//    func candles(from startDate: Date, to endDate: Date) -> [Candle] {
//        return candles.filter { candle in
//            candle.timestamp >= startDate && candle.timestamp <= endDate
//        }
//    }
//    
//    /// Get the most recent candles
//    /// Useful for calculating recent indicators
//    func recentCandles(count: Int) -> [Candle] {
//        guard count > 0 else { return [] }
//        let startIndex = max(0, candles.count - count)
//        return Array(candles.suffix(from: startIndex))
//    }
//    
//    /// Calculate simple moving average for a given period
//    /// This is a common technical indicator
//    func movingAverage(period: Int) -> [Double] {
//        guard period > 0 && candles.count >= period else { return [] }
//        
//        var movingAverages: [Double] = []
//        
//        // Calculate MA for each possible position
//        for i in (period-1)..<candles.count {
//            let relevantCandles = candles[(i-period+1)...i]
//            let sum = relevantCandles.reduce(0) { $0 + $1.close }
//            movingAverages.append(sum / Double(period))
//        }
//        
//        return movingAverages
//    }
//    
//    // MARK: - Price Calculations
//    
//    /// Convert a Y coordinate to a price value
//    /// Used for displaying price at cursor position
//    func price(at yPosition: CGFloat, in height: CGFloat, scale: CGFloat, offset: CGFloat) -> Double {
//        let normalizedY = (height - yPosition - offset) / (height * scale)
//        return priceRange.min + (normalizedY * (priceRange.max - priceRange.min))
//    }
//    
//    /// Convert a price to a Y coordinate
//    /// Used for positioning price indicators and levels
//    func yPosition(for price: Double, in height: CGFloat, scale: CGFloat, offset: CGFloat) -> CGFloat {
//        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
//        return height - (CGFloat(normalizedPrice) * height * scale) - offset
//    }
//    
//    /// Simulate receiving real-time market data
//    /// In production, this would connect to a real data feed
//    func simulateMarketData() {
//        startDataGeneration()
//    }
//    
//    /// Update chart with real market data
//    /// This would be called when receiving data from an API or WebSocket
//    func updateWithMarketData(_ data: [Candle]) {
//        candles = data
//        updatePriceRange()
//        
//        if let lastCandle = candles.last {
//            currentPrice = lastCandle.close
//            basePrice = lastCandle.close
//        }
//    }
//    
//    /// Add a single new candle from real-time feed
//    /// Used when receiving tick-by-tick updates
//    func addRealtimeCandle(_ candle: Candle) {
//        candles.append(candle)
//        currentPrice = candle.close
//        
//        // Maintain memory limit
//        if candles.count > maxCandles {
//            candles.removeFirst()
//        }
//        
//        updatePriceRange()
//    }
//    
//    /// Regenerate mock data when symbol or timeframe changes
//    /// This stops the current generation, creates fresh data, and restarts the timer
//    func regenerateMockData() {
//        // Stop current data generation
//        stopDataGeneration()
//        
//        // Generate fresh candle data
//        candles = Candle.generateSampleData(count: 200)
//        
//        // Update price range with new data
//        updatePriceRange()
//        
//        // Set current price from the latest candle
//        if let lastCandle = candles.last {
//            currentPrice = lastCandle.close
//            basePrice = lastCandle.close
//        }
//        
//        // Restart data generation for real-time updates
//        startDataGeneration()
//    }
//    
//    /// Regenerate mock data with a specific number of candles
//    /// Useful for different timeframes that may need more or less historical data
//    func regenerateMockData(candleCount: Int) {
//        stopDataGeneration()
//        
//        // Generate specified number of candles
//        candles = Candle.generateSampleData(count: candleCount)
//        
//        updatePriceRange()
//        
//        if let lastCandle = candles.last {
//            currentPrice = lastCandle.close
//            basePrice = lastCandle.close
//        }
//        
//        startDataGeneration()
//    }
//    
//    /// Regenerate mock data with a specific base price
//    /// Useful for different symbols with different price ranges
//    func regenerateMockData(basePrice: Double) {
//        stopDataGeneration()
//        
//        // Set the base price for this symbol
//        self.basePrice = basePrice
//        
//        // Generate data starting from this price
//        var tempCandles: [Candle] = []
//        var currentPrice = basePrice
//        var currentDate = Date()
//        
//        for _ in 0..<200 {
//            let candle = Candle.random(basePrice: currentPrice, timestamp: currentDate)
//            tempCandles.append(candle)
//            currentPrice = candle.close
//            currentDate = currentDate.addingTimeInterval(-300) // 5 minutes earlier
//        }
//        
//        candles = tempCandles.reversed()
//        
//        updatePriceRange()
//        
//        if let lastCandle = candles.last {
//            self.currentPrice = lastCandle.close
//        }
//        
//        startDataGeneration()
//    }
//}
//
//
//
