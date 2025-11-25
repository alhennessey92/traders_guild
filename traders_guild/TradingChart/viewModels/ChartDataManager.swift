

//
//  ChartDataManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/11/2025.
//

import SwiftUI
import Combine
import Foundation

/// Manages chart data and provides real-time updates
/// This is the data source for the trading chart, handling both historical and live data
class ChartDataManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Array of candles to display on the chart
    /// Published so the view updates when new candles are added
    @Published var candles: [Candle] = []
    
    /// Current/latest price for the price indicator
    /// This is typically the close price of the most recent candle
    @Published var currentPrice: Double = 0
    
    /// The price range for scaling the chart
    /// Calculated from all visible candles plus padding
    @Published var priceRange: (min: Double, max: Double) = (0, 0)
    
    // MARK: - Private Properties
    
    /// Timer for generating new candles in real-time
    private var timer: Timer?
    
    /// Current base price for generating new sample data
    /// This creates continuous price movement from the last candle
    private var basePrice: Double = 100.0
    
    /// Maximum number of candles to keep in memory
    /// Prevents memory issues with long-running charts
    private let maxCandles = 500
    
    // MARK: - Initialization
    
    init() {
        loadInitialData()
    }
    
    deinit {
        // Clean up timer when manager is deallocated
        stopDataGeneration()
    }
    
    // MARK: - Data Management
    
    /// Load initial sample data for the chart
    /// In production, this would load historical data from an API
    private func loadInitialData() {
        // Generate 100 candles of historical data
        candles = Candle.generateSampleData(count: 200)
        
        // Update the price range based on loaded data
        updatePriceRange()
        
        // Set current price from the latest candle
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }
    
    /// Start generating real-time data updates
    /// Simulates live market data feed
    func startDataGeneration() {
        // Stop any existing timer to prevent duplicates
        stopDataGeneration()
        
        // Create timer for real-time updates (every 5 seconds for demo)
        // In production, this would be replaced with WebSocket or API polling
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.generateNewCandle()
        }
    }
    
    /// Stop generating real-time data
    func stopDataGeneration() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Generate a new candle and add it to the chart
    /// Simulates receiving new market data
    private func generateNewCandle() {
        // Create new candle based on current price
        let newCandle = Candle.random(
            basePrice: basePrice,
            timestamp: Date()
        )
        
        // Add new candle to the array
        candles.append(newCandle)
        
        // Update current price indicator
        currentPrice = newCandle.close
        
        // Update base price for next candle generation
        basePrice = newCandle.close
        
        // Remove old candles if we exceed the memory limit
        if candles.count > maxCandles {
            candles.removeFirst(candles.count - maxCandles)
        }
        
        // Recalculate price range with new data
        updatePriceRange()
    }
    
    /// Update the price range based on all candles
    /// This determines the Y-axis scale for the chart
    func updatePriceRange() {
        guard !candles.isEmpty else {
            // Default range if no data
            priceRange = (0, 100)
            return
        }
        
        // Find the absolute minimum and maximum prices
        let allLows = candles.map { $0.low }
        let allHighs = candles.map { $0.high }
        
        guard let minPrice = allLows.min(),
              let maxPrice = allHighs.max() else {
            priceRange = (0, 100)
            return
        }
        
        // Add 10% padding to the range for better visualization
        // This prevents candles from touching the top/bottom of the chart
        let padding = (maxPrice - minPrice) * 0.6 // TODO: make this universal to adjust the padding in settings
        priceRange = (minPrice - padding, maxPrice + padding)
    }
    
    // MARK: - Data Access Methods
    
    /// Get candles within a specific time range
    /// Useful for filtering data by date
    func candles(from startDate: Date, to endDate: Date) -> [Candle] {
        return candles.filter { candle in
            candle.timestamp >= startDate && candle.timestamp <= endDate
        }
    }
    
    /// Get the most recent candles
    /// Useful for calculating recent indicators
    func recentCandles(count: Int) -> [Candle] {
        guard count > 0 else { return [] }
        let startIndex = max(0, candles.count - count)
        return Array(candles.suffix(from: startIndex))
    }
    
    /// Calculate simple moving average for a given period
    /// This is a common technical indicator
    func movingAverage(period: Int) -> [Double] {
        guard period > 0 && candles.count >= period else { return [] }
        
        var movingAverages: [Double] = []
        
        // Calculate MA for each possible position
        for i in (period-1)..<candles.count {
            let relevantCandles = candles[(i-period+1)...i]
            let sum = relevantCandles.reduce(0) { $0 + $1.close }
            movingAverages.append(sum / Double(period))
        }
        
        return movingAverages
    }
    
    // MARK: - Price Calculations
    
    /// Convert a Y coordinate to a price value
    /// Used for displaying price at cursor position
    func price(at yPosition: CGFloat, in height: CGFloat, scale: CGFloat, offset: CGFloat) -> Double {
        let normalizedY = (height - yPosition - offset) / (height * scale)
        return priceRange.min + (normalizedY * (priceRange.max - priceRange.min))
    }
    
    /// Convert a price to a Y coordinate
    /// Used for positioning price indicators and levels
    func yPosition(for price: Double, in height: CGFloat, scale: CGFloat, offset: CGFloat) -> CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return height - (CGFloat(normalizedPrice) * height * scale) - offset
    }
    
    /// Simulate receiving real-time market data
    /// In production, this would connect to a real data feed
    func simulateMarketData() {
        startDataGeneration()
    }
    
    /// Update chart with real market data
    /// This would be called when receiving data from an API or WebSocket
    func updateWithMarketData(_ data: [Candle]) {
        candles = data
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
    }
    
    /// Add a single new candle from real-time feed
    /// Used when receiving tick-by-tick updates
    func addRealtimeCandle(_ candle: Candle) {
        candles.append(candle)
        currentPrice = candle.close
        
        // Maintain memory limit
        if candles.count > maxCandles {
            candles.removeFirst()
        }
        
        updatePriceRange()
    }
    
    /// Regenerate mock data when symbol or timeframe changes
    /// This stops the current generation, creates fresh data, and restarts the timer
    func regenerateMockData() {
        // Stop current data generation
        stopDataGeneration()
        
        // Generate fresh candle data
        candles = Candle.generateSampleData(count: 200)
        
        // Update price range with new data
        updatePriceRange()
        
        // Set current price from the latest candle
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
        
        // Restart data generation for real-time updates
        startDataGeneration()
    }
    
    /// Regenerate mock data with a specific number of candles
    /// Useful for different timeframes that may need more or less historical data
    func regenerateMockData(candleCount: Int) {
        stopDataGeneration()
        
        // Generate specified number of candles
        candles = Candle.generateSampleData(count: candleCount)
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            currentPrice = lastCandle.close
            basePrice = lastCandle.close
        }
        
        startDataGeneration()
    }
    
    /// Regenerate mock data with a specific base price
    /// Useful for different symbols with different price ranges
    func regenerateMockData(basePrice: Double) {
        stopDataGeneration()
        
        // Set the base price for this symbol
        self.basePrice = basePrice
        
        // Generate data starting from this price
        var tempCandles: [Candle] = []
        var currentPrice = basePrice
        var currentDate = Date()
        
        for _ in 0..<200 {
            let candle = Candle.random(basePrice: currentPrice, timestamp: currentDate)
            tempCandles.append(candle)
            currentPrice = candle.close
            currentDate = currentDate.addingTimeInterval(-300) // 5 minutes earlier
        }
        
        candles = tempCandles.reversed()
        
        updatePriceRange()
        
        if let lastCandle = candles.last {
            self.currentPrice = lastCandle.close
        }
        
        startDataGeneration()
    }
}



