//
//  Candle.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/11/2025.
//

import Foundation

/// Represents a single candlestick in the trading chart
/// Contains OHLC (Open, High, Low, Close) data plus timestamp and optional volume
struct Candle: Identifiable, Equatable {
    let id = UUID()
    
    /// The opening price at the start of this time period
    let open: Double
    
    /// The highest price reached during this time period
    let high: Double
    
    /// The lowest price reached during this time period
    let low: Double
    
    /// The closing price at the end of this time period
    let close: Double
    
    /// The timestamp for when this candle period started
    let timestamp: Date
    
    /// Optional: Volume traded during this period (for future volume indicators)
    let volume: Double?
    
    // MARK: - Computed Properties
    
    /// Whether this is a bullish (green) or bearish (red) candle
    /// Bullish means close >= open (price went up or stayed same)
    var isBullish: Bool {
        close >= open
    }
    
    /// The body height of the candle (difference between open and close)
    /// This determines how tall the colored rectangle will be
    var bodyHeight: Double {
        abs(close - open)
    }
    
    /// The total range of the candle from highest to lowest point
    var range: Double {
        high - low
    }
    
    /// The upper wick size (from body top to high)
    var upperWick: Double {
        high - max(open, close)
    }
    
    /// The lower wick size (from body bottom to low)
    var lowerWick: Double {
        min(open, close) - low
    }
    
    // MARK: - Initializer
    
    init(open: Double, high: Double, low: Double, close: Double, timestamp: Date, volume: Double? = nil) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.timestamp = timestamp
        self.volume = volume
    }
}

// MARK: - Sample Data Generation

extension Candle {
    /// Generate a random candle for testing purposes
    /// Uses realistic price movements based on volatility
    static func random(basePrice: Double, timestamp: Date) -> Candle {
        // 2% volatility for realistic price movements
        let volatility = 0.02
        
        // Generate open price with some variance from base
        let open = basePrice + (Double.random(in: -volatility...volatility) * basePrice)
        
        // Generate close price with variance from open
        let close = open + (Double.random(in: -volatility...volatility) * basePrice)
        
        // Ensure high is actually the highest value
        let bodyHigh = max(open, close)
        let bodyLow = min(open, close)
        
        // Add wicks that extend beyond the body
        // Upper wick can be up to half the volatility above body
        let high = bodyHigh + (Double.random(in: 0...(volatility/2)) * basePrice)
        
        // Lower wick can be up to half the volatility below body
        let low = bodyLow - (Double.random(in: 0...(volatility/2)) * basePrice)
        
        return Candle(
            open: open,
            high: high,
            low: low,
            close: close,
            timestamp: timestamp,
            volume: Double.random(in: 100000...1000000) // Random volume for testing
        )
    }
    
    /// Generate an array of sample candles for initial chart display
    static func generateSampleData(count: Int = 200, startDate: Date = Date()) -> [Candle] {
        var candles: [Candle] = []
        var currentPrice = 100.0 // Starting price at $100
        var currentDate = startDate
        
        for _ in 0..<count {
            // Generate candle based on current price
            let candle = Candle.random(basePrice: currentPrice, timestamp: currentDate)
            candles.append(candle)
            
            // Update price for next candle to create trending behavior
            // This creates more realistic connected price movement
            currentPrice = candle.close
            
            // Move to previous time period (5 minutes ago)
            currentDate = currentDate.addingTimeInterval(-300)
        }
        
        // Reverse so newest candles are at the end
        return candles.reversed()
    }
}
