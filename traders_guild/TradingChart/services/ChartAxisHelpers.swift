//
//  ChartAxisHelpers.swift
//  traders_guild
//
//  UPDATED VERSION with:
//  1. Zoom-aware price step calculation (more grid lines when zoomed in)
//  2. Date label support for X-axis at day boundaries
//

import SwiftUI

// MARK: - Time Axis Helper

/// Helper struct for calculating "nice" time intervals and formatting time labels
/// Ensures labels show clean times like 13:15, 13:30 instead of 13:17, 13:22
struct TimeAxisHelper {
    
    /// The current chart timeframe
    let timeframe: RLChartTimeframe
    
    /// Initialize with the active timeframe
    init(timeframe: RLChartTimeframe) {
        self.timeframe = timeframe
    }
    
    // MARK: - Nice Time Interval Calculation
    
    /// Returns the "nice" interval in seconds for displaying time labels
    /// This determines which timestamps should get labels (e.g., every 15 min, every hour)
    var niceLabelInterval: TimeInterval {
        switch timeframe {
        case .m1:
            return 5 * 60  // 5 minutes
        case .m5:
            return 15 * 60  // 15 minutes
        case .m15:
            return 60 * 60  // 1 hour
        case .m30:
            return 2 * 60 * 60  // 2 hours
        case .h1:
            return 4 * 60 * 60  // 4 hours
        case .h4:
            return 12 * 60 * 60  // 12 hours
        case .d1:
            return 7 * 24 * 60 * 60  // 1 week
        case .w1:
            return 30 * 24 * 60 * 60  // ~30 days
        case .mn:
            return 90 * 24 * 60 * 60  // ~90 days
        }
    }
    
    /// Returns the minimum nice label interval based on horizontal zoom
    func adaptiveLabelInterval(zoomScale: CGFloat) -> TimeInterval {
        let baseInterval = niceLabelInterval
        
        if zoomScale > 2.0 {
            return baseInterval / 2
        } else if zoomScale > 1.5 {
            return baseInterval / 1.5
        } else if zoomScale < 0.6 {
            return baseInterval * 2
        } else if zoomScale < 0.4 {
            return baseInterval * 3
        }
        
        return baseInterval
    }
    
    // MARK: - Timestamp Boundary Checking
    
    /// Check if a timestamp falls on a "nice" boundary for the current timeframe
    func isNiceBoundary(_ timestamp: Date, interval: TimeInterval) -> Bool {
        let calendar = Calendar.current
        
        switch timeframe {
        case .m1, .m5:
            let minutes = calendar.component(.minute, from: timestamp)
            let intervalMinutes = Int(interval / 60)
            return minutes % intervalMinutes == 0
            
        case .m15, .m30:
            let minutes = calendar.component(.minute, from: timestamp)
            let intervalMinutes = Int(interval / 60)
            if intervalMinutes >= 60 {
                return minutes == 0
            }
            return minutes % intervalMinutes == 0
            
        case .h1, .h4:
            let hour = calendar.component(.hour, from: timestamp)
            let intervalHours = Int(interval / 3600)
            let minutes = calendar.component(.minute, from: timestamp)
            return hour % intervalHours == 0 && minutes == 0
            
        case .d1:
            let weekday = calendar.component(.weekday, from: timestamp)
            return weekday == 2  // Monday
            
        case .w1:
            let day = calendar.component(.day, from: timestamp)
            return day <= 7
            
        case .mn:
            let month = calendar.component(.month, from: timestamp)
            return month % 3 == 1
        }
    }
    
    /// Find the nearest "nice" time boundary for a given timestamp
    func nearestNiceBoundary(_ timestamp: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp)
        
        switch timeframe {
        case .m1:
            components.second = 0
            
        case .m5:
            if let minute = components.minute {
                components.minute = (minute / 5) * 5
            }
            components.second = 0
            
        case .m15:
            if let minute = components.minute {
                components.minute = (minute / 15) * 15
            }
            components.second = 0
            
        case .m30:
            if let minute = components.minute {
                components.minute = (minute / 30) * 30
            }
            components.second = 0
            
        case .h1:
            components.minute = 0
            components.second = 0
            
        case .h4:
            if let hour = components.hour {
                components.hour = (hour / 4) * 4
            }
            components.minute = 0
            components.second = 0
            
        case .d1:
            components.hour = 0
            components.minute = 0
            components.second = 0
            
        case .w1:
            components.hour = 0
            components.minute = 0
            components.second = 0
            if let date = calendar.date(from: components) {
                let weekday = calendar.component(.weekday, from: date)
                let daysToSubtract = (weekday + 5) % 7
                return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? timestamp
            }
            
        case .mn:
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        
        return calendar.date(from: components) ?? timestamp
    }
    
    // MARK: - Time Label Formatting
    
    /// Format a timestamp appropriately for the current timeframe
    func formatLabel(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .m1, .m5, .m15, .m30:
            formatter.dateFormat = "HH:mm"
            
        case .h1:
            let hour = Calendar.current.component(.hour, from: timestamp)
            if hour == 0 {
                formatter.dateFormat = "dd MMM"
            } else {
                formatter.dateFormat = "HH:mm"
            }
            
        case .h4:
            let hour = Calendar.current.component(.hour, from: timestamp)
            if hour == 0 {
                formatter.dateFormat = "dd MMM"
            } else {
                formatter.dateFormat = "HH:mm"
            }
            
        case .d1:
            formatter.dateFormat = "dd MMM"
            
        case .w1:
            formatter.dateFormat = "dd MMM"
            
        case .mn:
            formatter.dateFormat = "MMM yy"
        }
        
        return formatter.string(from: timestamp)
    }
    
    // MARK: - NEW: Check if timestamp is at midnight (day boundary)
    
    /// Check if timestamp is at midnight (00:00)
    /// Used to show date labels on intraday charts
    static func isMidnight(_ timestamp: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        let minute = calendar.component(.minute, from: timestamp)
        return hour == 0 && minute == 0
    }
    
    /// Check if timestamp is near midnight (within tolerance for the timeframe)
    /// For H1: exact midnight. For M15/M30: within 30 min. For M1/M5: within 5 min
    func isNearMidnight(_ timestamp: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        let minute = calendar.component(.minute, from: timestamp)
        
        switch timeframe {
        case .m1, .m5:
            return hour == 0 && minute <= 5
        case .m15, .m30:
            return hour == 0 && minute <= 30
        case .h1, .h4:
            return hour == 0
        default:
            return false
        }
    }
    
    /// Check if this is a month boundary (1st of month)
    static func isFirstOfMonth(_ timestamp: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: timestamp)
        return day == 1
    }
}


// MARK: - Price Axis Helper

/// Helper struct for calculating "nice" price intervals and symbol-aware formatting
/// UPDATED: Now properly accounts for zoom level to show more grid lines when zoomed in
struct PriceAxisHelper {
    
    /// The trading symbol for context-aware formatting
    let symbol: RLTradingSymbolDTO?
    
    /// The visible price range (from chart data)
    let priceRange: (min: Double, max: Double)
    
    /// Current vertical zoom scale
    let priceScale: CGFloat
    
    /// Optional: actual chart height for more precise calculations
    let chartHeight: CGFloat?
    
    init(symbol: RLTradingSymbolDTO?, priceRange: (min: Double, max: Double), priceScale: CGFloat, chartHeight: CGFloat? = nil) {
        self.symbol = symbol
        self.priceRange = priceRange
        self.priceScale = priceScale
        self.chartHeight = chartHeight
    }
    
    // MARK: - Nice Price Step Calculation
    
    /// Calculate a "nice" price step for grid lines
    /// FIXED: Now properly scales with zoom level
    /// When zoomed in 2x, you see half the price range, so you need twice as many lines
    var nicePriceStep: Double {
        let dataRange = priceRange.max - priceRange.min
        guard dataRange > 0 else { return 1.0 }
        
        // CRITICAL FIX: Calculate the VISIBLE range, not the data range
        // When priceScale = 2, you're viewing half the data range on screen
        // So the effective range for grid calculation should be smaller
        let visibleRange = dataRange / Double(priceScale)
        
        // UPDATED: Target 14 lines instead of 10 for denser Y-axis grid
        let targetLinesOnScreen: Double = 14.0
        
        // Calculate rough step based on VISIBLE range
        let roughStep = visibleRange / targetLinesOnScreen
        
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
            return decimalPlacesFromMagnitude()
        }
        
        let assetClass = symbol.assetClassEnum ?? .forex
        switch assetClass {
        case .forex:
            return symbol.ticker.contains("JPY") ? 3 : 5
        case .crypto:
            let avgPrice = (priceRange.min + priceRange.max) / 2
            if avgPrice > 1000 {
                return 2
            } else if avgPrice > 1 {
                return 4
            } else {
                return 6
            }
        case .stocks, .commodities, .futures:
            return 2
        case .indices:
            let avgPrice = (priceRange.min + priceRange.max) / 2
            return avgPrice > 10000 ? 0 : 2
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
        
        if price >= 1_000_000 {
            return String(format: "%.1fM", price / 1_000_000)
        } else if price >= 10_000 && places == 0 {
            return String(format: "%.1fK", price / 1_000)
        }
        
        return String(format: "%.\(places)f", price)
    }
}


// MARK: - Extended RLTradingSymbolDTO Formatting

extension RLTradingSymbolDTO {
    
    /// Get the recommended decimal places for this symbol
    var recommendedDecimalPlaces: Int {
        switch assetClassEnum ?? .forex {
        case .forex:
            return ticker.contains("JPY") ? 3 : 5
        case .crypto, .stocks, .commodities, .futures, .indices:
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
        var labelHeight: CGFloat = 30
        var labelFont: Font = .system(size: 10)
        var labelColor: Color = .gray
        var gridColor: Color = AppColors.surfaceGray20
        var gridLineWidth: CGFloat = 0.5
    }
    
    /// Y-axis settings
    struct PriceAxis {
        var showLabels: Bool = true
        var labelWidth: CGFloat = 60
        var labelFont: Font = .system(size: 10)
        var labelColor: Color = .gray
        var gridColor: Color = AppColors.surfaceGray20
        var gridLineWidth: CGFloat = 0.5
    }
    
    var timeAxis = TimeAxis()
    var priceAxis = PriceAxis()
}


