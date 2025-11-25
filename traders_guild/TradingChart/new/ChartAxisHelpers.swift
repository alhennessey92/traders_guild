//
//  ChartAxisHelpers.swift
//  traders_guild
//
//  Created by Al Hennessey on 25/11/2025.
//

//
//  ChartAxisHelpers.swift
//  traders_guild
//
//  Comprehensive axis helper utilities for professional chart rendering
//  Handles "nice" time intervals, symbol-aware price formatting, and adaptive labeling
//

import SwiftUI

// MARK: - Time Axis Helper

/// Helper struct for calculating "nice" time intervals and formatting time labels
/// Ensures labels show clean times like 13:15, 13:30 instead of 13:17, 13:22
struct TimeAxisHelper {
    
    /// The current chart timeframe
    let timeframe: ChartTimeframe
    
    /// Initialize with the active timeframe
    init(timeframe: ChartTimeframe) {
        self.timeframe = timeframe
    }
    
    // MARK: - Nice Time Interval Calculation
    
    /// Returns the "nice" interval in seconds for displaying time labels
    /// This determines which timestamps should get labels (e.g., every 15 min, every hour)
    var niceLabelInterval: TimeInterval {
        switch timeframe {
        case .m1:
            // 1-minute chart: show labels every 5 minutes
            return 5 * 60  // 300 seconds
        case .m5:
            // 5-minute chart: show labels every 15 or 30 minutes
            return 15 * 60  // 900 seconds
        case .m15:
            // 15-minute chart: show labels every 1 hour
            return 60 * 60  // 3600 seconds
        case .m30:
            // 30-minute chart: show labels every 2 hours
            return 2 * 60 * 60  // 7200 seconds
        case .h1:
            // 1-hour chart: show labels every 4 hours
            return 4 * 60 * 60  // 14400 seconds
        case .h4:
            // 4-hour chart: show labels every 12 hours (or day boundary)
            return 12 * 60 * 60  // 43200 seconds
        case .d1:
            // Daily chart: show labels every week (Monday)
            return 7 * 24 * 60 * 60  // 604800 seconds
        case .w1:
            // Weekly chart: show labels every month
            return 30 * 24 * 60 * 60  // ~30 days
        case .mn:
            // Monthly chart: show labels every quarter
            return 90 * 24 * 60 * 60  // ~90 days
        }
    }
    
    /// Returns the minimum nice label interval based on horizontal zoom
    /// When zoomed in, we can show more frequent labels
    func adaptiveLabelInterval(zoomScale: CGFloat) -> TimeInterval {
        let baseInterval = niceLabelInterval
        
        // When zoomed in (scale > 1.5), show more labels
        if zoomScale > 2.0 {
            return baseInterval / 2
        } else if zoomScale > 1.5 {
            return baseInterval / 1.5
        } else if zoomScale < 0.6 {
            // When zoomed out, show fewer labels
            return baseInterval * 2
        } else if zoomScale < 0.4 {
            return baseInterval * 3
        }
        
        return baseInterval
    }
    
    // MARK: - Timestamp Boundary Checking
    
    /// Check if a timestamp falls on a "nice" boundary for the current timeframe
    /// - Parameters:
    ///   - timestamp: The date to check
    ///   - interval: The interval to check against (use `niceLabelInterval` or `adaptiveLabelInterval`)
    /// - Returns: True if this timestamp should have a label
    func isNiceBoundary(_ timestamp: Date, interval: TimeInterval) -> Bool {
        let calendar = Calendar.current
        
        switch timeframe {
        case .m1, .m5:
            // For minute charts, check if minutes are divisible by interval
            let minutes = calendar.component(.minute, from: timestamp)
            let intervalMinutes = Int(interval / 60)
            return minutes % intervalMinutes == 0
            
        case .m15, .m30:
            // For 15/30 minute charts, check hour boundaries
            let minutes = calendar.component(.minute, from: timestamp)
            let intervalMinutes = Int(interval / 60)
            if intervalMinutes >= 60 {
                // Check for whole hours
                return minutes == 0
            }
            return minutes % intervalMinutes == 0
            
        case .h1, .h4:
            // For hourly charts, check hour boundaries
            let hour = calendar.component(.hour, from: timestamp)
            let intervalHours = Int(interval / 3600)
            let minutes = calendar.component(.minute, from: timestamp)
            return hour % intervalHours == 0 && minutes == 0
            
        case .d1:
            // For daily charts, check for specific weekdays (e.g., Monday)
            let weekday = calendar.component(.weekday, from: timestamp)
            // Sunday = 1, Monday = 2 in Calendar
            return weekday == 2  // Monday
            
        case .w1:
            // For weekly charts, check for month start
            let day = calendar.component(.day, from: timestamp)
            return day <= 7  // First week of month
            
        case .mn:
            // For monthly charts, check for quarter start
            let month = calendar.component(.month, from: timestamp)
            return month % 3 == 1  // Jan, Apr, Jul, Oct
        }
    }
    
    /// Find the nearest "nice" time boundary for a given timestamp
    /// Useful for aligning mock data to clean intervals
    func nearestNiceBoundary(_ timestamp: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp)
        
        switch timeframe {
        case .m1:
            // Round to nearest minute
            components.second = 0
            
        case .m5:
            // Round to nearest 5 minutes
            if let minute = components.minute {
                components.minute = (minute / 5) * 5
            }
            components.second = 0
            
        case .m15:
            // Round to nearest 15 minutes
            if let minute = components.minute {
                components.minute = (minute / 15) * 15
            }
            components.second = 0
            
        case .m30:
            // Round to nearest 30 minutes
            if let minute = components.minute {
                components.minute = (minute / 30) * 30
            }
            components.second = 0
            
        case .h1:
            // Round to nearest hour
            components.minute = 0
            components.second = 0
            
        case .h4:
            // Round to nearest 4 hours
            if let hour = components.hour {
                components.hour = (hour / 4) * 4
            }
            components.minute = 0
            components.second = 0
            
        case .d1:
            // Round to start of day
            components.hour = 0
            components.minute = 0
            components.second = 0
            
        case .w1:
            // Round to start of week (Monday)
            components.hour = 0
            components.minute = 0
            components.second = 0
            // Find previous Monday
            if let date = calendar.date(from: components) {
                let weekday = calendar.component(.weekday, from: date)
                let daysToSubtract = (weekday + 5) % 7  // Days since Monday
                return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? timestamp
            }
            
        case .mn:
            // Round to start of month
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        
        return calendar.date(from: components) ?? timestamp
    }
    
    // MARK: - Time Label Formatting
    
    /// Format a timestamp appropriately for the current timeframe
    /// - Parameter timestamp: The date to format
    /// - Returns: Formatted string suitable for axis label
    func formatLabel(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .m1, .m5, .m15, .m30:
            // Short timeframes: show time only
            formatter.dateFormat = "HH:mm"
            
        case .h1:
            // Hourly: show time, include date on day boundaries
            let hour = Calendar.current.component(.hour, from: timestamp)
            if hour == 0 {
                formatter.dateFormat = "dd MMM"
            } else {
                formatter.dateFormat = "HH:mm"
            }
            
        case .h4:
            // 4-hour: show time, include date on day boundaries
            let hour = Calendar.current.component(.hour, from: timestamp)
            if hour == 0 {
                formatter.dateFormat = "dd MMM"
            } else {
                formatter.dateFormat = "HH:mm"
            }
            
        case .d1:
            // Daily: show date
            formatter.dateFormat = "dd MMM"
            
        case .w1:
            // Weekly: show date with month
            formatter.dateFormat = "dd MMM"
            
        case .mn:
            // Monthly: show month and year
            formatter.dateFormat = "MMM yy"
        }
        
        return formatter.string(from: timestamp)
    }
    
    /// Get a compact format for tight spaces
    func formatLabelCompact(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .m1, .m5, .m15, .m30, .h1, .h4:
            formatter.dateFormat = "HH:mm"
        case .d1, .w1:
            formatter.dateFormat = "dd/MM"
        case .mn:
            formatter.dateFormat = "MMM"
        }
        
        return formatter.string(from: timestamp)
    }
}

// MARK: - Price Axis Helper

/// Helper struct for calculating "nice" price intervals and symbol-aware formatting
struct PriceAxisHelper {
    
    /// The trading symbol for context-aware formatting
    let symbol: TradingSymbol?
    
    /// The visible price range
    let priceRange: (min: Double, max: Double)
    
    /// Current vertical zoom scale
    let priceScale: CGFloat
    
    init(symbol: TradingSymbol?, priceRange: (min: Double, max: Double), priceScale: CGFloat) {
        self.symbol = symbol
        self.priceRange = priceRange
        self.priceScale = priceScale
    }
    
    // MARK: - Nice Price Step Calculation
    
    /// Calculate a "nice" price step for grid lines
    /// Returns values like 0.0001, 0.0005, 0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10, 50, 100
    var nicePriceStep: Double {
        let range = priceRange.max - priceRange.min
        guard range > 0 else { return 1.0 }
        
        // Adjust target grid lines based on zoom
        let baseTargetLines: Double = 8.0
        let targetLines: Double
        
        if priceScale > 2.0 {
            targetLines = baseTargetLines * 1.5  // More lines when zoomed in
        } else if priceScale > 1.5 {
            targetLines = baseTargetLines * 1.25
        } else if priceScale < 0.7 {
            targetLines = baseTargetLines * 0.7  // Fewer lines when zoomed out
        } else {
            targetLines = baseTargetLines
        }
        
        let roughStep = range / targetLines
        
        // Find magnitude (power of 10)
        let magnitude = pow(10.0, floor(log10(roughStep)))
        
        // Normalize to 1-10 range
        let normalized = roughStep / magnitude
        
        // Pick nice number: 1, 2, 2.5, 5, or 10
        let niceNormalized: Double
        if normalized <= 1.0 {
            niceNormalized = 1.0
        } else if normalized <= 2.0 {
            niceNormalized = 2.0
        } else if normalized <= 2.5 {
            niceNormalized = 2.5
        } else if normalized <= 5.0 {
            niceNormalized = 5.0
        } else {
            niceNormalized = 10.0
        }
        
        return niceNormalized * magnitude
    }
    
    /// Get the starting price for grid lines (rounded down to nice boundary)
    var gridStartPrice: Double {
        let step = nicePriceStep
        return floor(priceRange.min / step) * step
    }
    
    /// Get the ending price for grid lines (rounded up to nice boundary)
    var gridEndPrice: Double {
        let step = nicePriceStep
        return ceil(priceRange.max / step) * step
    }
    
    /// Generate all the "nice" price levels for grid lines
    var gridPriceLevels: [Double] {
        let step = nicePriceStep
        var levels: [Double] = []
        var currentPrice = gridStartPrice
        
        while currentPrice <= gridEndPrice {
            levels.append(currentPrice)
            currentPrice += step
        }
        
        return levels
    }
    
    // MARK: - Symbol-Aware Formatting
    
    /// Determine the appropriate number of decimal places for the current symbol
    var decimalPlaces: Int {
        guard let symbol = symbol else {
            // Default: determine from price magnitude
            return decimalPlacesFromMagnitude()
        }
        
        switch symbol.assetClass {
        case .forex:
            // Forex pairs have specific conventions
            if symbol.symbol.contains("JPY") {
                return 3  // JPY pairs: 150.123
            } else {
                return 5  // Major pairs: 1.08543
            }
            
        case .crypto:
            // Crypto depends on price magnitude
            let avgPrice = (priceRange.min + priceRange.max) / 2
            if avgPrice > 1000 {
                return 2  // BTC: 45000.00
            } else if avgPrice > 1 {
                return 4  // ETH: 2500.0000
            } else {
                return 6  // Small coins: 0.001234
            }
            
        case .stocks:
            return 2  // Stocks: 155.25
            
        case .commodities:
            return 2  // Gold: 2000.50
            
        case .indices:
            let avgPrice = (priceRange.min + priceRange.max) / 2
            if avgPrice > 10000 {
                return 0  // Dow: 35000
            } else {
                return 2  // S&P: 4500.00
            }
            
        case .futures:
            return 2  // Default for futures
        }
    }
    
    /// Fallback decimal places based on price magnitude when no symbol is set
    private func decimalPlacesFromMagnitude() -> Int {
        let step = nicePriceStep
        
        if step >= 100 {
            return 0
        } else if step >= 10 {
            return 0
        } else if step >= 1 {
            return 0
        } else if step >= 0.1 {
            return 1
        } else if step >= 0.01 {
            return 2
        } else if step >= 0.001 {
            return 3
        } else if step >= 0.0001 {
            return 4
        } else {
            return 5
        }
    }
    
    /// Format a price value for display on the Y-axis
    func formatPrice(_ price: Double) -> String {
        if let symbol = symbol {
            return symbol.formatPrice(price)
        } else {
            return String(format: "%.\(decimalPlaces)f", price)
        }
    }
    
    /// Format price for a grid label (may be more compact)
    func formatGridLabel(_ price: Double) -> String {
        let places = decimalPlaces
        
        // For very large numbers, use K/M suffixes
        if price >= 1_000_000 {
            return String(format: "%.1fM", price / 1_000_000)
        } else if price >= 10_000 && places == 0 {
            return String(format: "%.1fK", price / 1_000)
        }
        
        return String(format: "%.\(places)f", price)
    }
}

// MARK: - Extended TradingSymbol Formatting

extension TradingSymbol {
    
    /// Get the recommended decimal places for this symbol
    var recommendedDecimalPlaces: Int {
        switch assetClass {
        case .forex:
            return symbol.contains("JPY") ? 3 : 5
        case .crypto:
            // Will need to be determined dynamically based on price
            return 2
        case .stocks, .commodities, .futures:
            return 2
        case .indices:
            return 2
        }
    }
    
    /// Format a price difference (for change displays)
    func formatPriceChange(_ change: Double) -> String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(formatPrice(change))"
    }
}

// MARK: - Axis Configuration

/// Configuration struct for axis rendering
struct AxisConfiguration {
    /// X-axis settings
    struct TimeAxis {
        var showLabels: Bool = true
        var labelHeight: CGFloat = 20
        var labelFont: Font = .system(size: 10)
        var labelColor: Color = .gray
        var gridColor: Color = .gray.opacity(0.2)
        var gridLineWidth: CGFloat = 0.5
    }
    
    /// Y-axis settings
    struct PriceAxis {
        var showLabels: Bool = true
        var labelWidth: CGFloat = 60
        var labelFont: Font = .system(size: 10)
        var labelColor: Color = .gray
        var gridColor: Color = .gray.opacity(0.2)
        var gridLineWidth: CGFloat = 0.5
    }
    
    var timeAxis = TimeAxis()
    var priceAxis = PriceAxis()
}
