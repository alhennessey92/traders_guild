//
//  Extensions.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/11/2025.
//


import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Standard colors for trading charts
    /// Consistent color scheme across the app
    struct Trading {
        static let bullish = Color.green
        static let bearish = Color.red
        static let bullishLight = Color.green.opacity(0.3)
        static let bearishLight = Color.red.opacity(0.3)
        static let grid = Color.gray.opacity(0.1)
        static let gridMajor = Color.gray.opacity(0.2)
        static let text = Color.gray
        static let priceIndicator = Color.yellow
        static let background = Color.black
        static let volumeUp = Color.green.opacity(0.5)
        static let volumeDown = Color.red.opacity(0.5)
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format price for display with 2 decimal places
    var formattedPrice: String {
        String(format: "%.2f", self)
    }
    
    /// Format price with custom decimal places
    func formattedPrice(decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
    
    /// Format large numbers with K/M/B suffixes
    /// Useful for volume display
    var formattedVolume: String {
        let num = abs(self)
        let sign = (self < 0) ? "-" : ""
        
        switch num {
        case 1_000_000_000...:
            let formatted = num / 1_000_000_000
            return "\(sign)\(formatted.formattedWith(1))B"
        case 1_000_000...:
            let formatted = num / 1_000_000
            return "\(sign)\(formatted.formattedWith(1))M"
        case 1_000...:
            let formatted = num / 1_000
            return "\(sign)\(formatted.formattedWith(1))K"
        default:
            return "\(sign)\(self.formattedWith(0))"
        }
    }
    
    /// Format with specified decimal places
    func formattedWith(_ decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }
    
    /// Clamp value between min and max
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    
    /// Calculate percentage change
    func percentageChange(from original: Double) -> Double {
        guard original != 0 else { return 0 }
        return ((self - original) / original) * 100
    }
}

// MARK: - CGFloat Extensions

extension CGFloat {
    /// Clamp value between min and max
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    
    /// Linear interpolation between two values
    func lerp(to target: CGFloat, by amount: CGFloat) -> CGFloat {
        self + (target - self) * amount
    }
    
    /// Smooth step interpolation for smoother animations
    func smoothStep(to target: CGFloat, by amount: CGFloat) -> CGFloat {
        let t = amount.clamped(to: 0...1)
        let smoothT = t * t * (3 - 2 * t)
        return lerp(to: target, by: smoothT)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format for chart time labels
    /// Adapts format based on time difference from now
    var chartTimeLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        // Choose format based on time distance
        if calendar.isDate(self, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEE HH:mm"
        } else if calendar.isDate(self, equalTo: now, toGranularity: .month) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: self)
    }
    
    /// Short format for compact display
    var shortTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    /// Format for different timeframes
    func label(for timeframe: Timeframe) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .m1, .m5, .m15, .m30:
            formatter.dateFormat = "HH:mm"
        case .h1, .h4:
            formatter.dateFormat = "dd MMM HH:mm"
        case .d1:
            formatter.dateFormat = "dd MMM"
        case .w1:
            formatter.dateFormat = "dd MMM yyyy"
        case .mn:
            formatter.dateFormat = "MMM yyyy"
        }
        
        return formatter.string(from: self)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Measure view size and report it
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
                    .onPreferenceChange(SizePreferenceKey.self, perform: action)
            }
        )
    }
    
    /// Add a border only when condition is true
    func conditionalBorder(_ condition: Bool, color: Color = .red, width: CGFloat = 1) -> some View {
        self.if(condition) { view in
            view.border(color, width: width)
        }
    }
}

// MARK: - Preference Keys

/// Preference key for measuring view sizes
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Array Extensions

extension Array where Element == Candle {
    /// Calculate the price range for the array of candles
    var priceRange: (min: Double, max: Double) {
        guard !isEmpty else { return (0, 100) }
        
        let lows = map { $0.low }
        let highs = map { $0.high }
        
        let minPrice = lows.min() ?? 0
        let maxPrice = highs.max() ?? 100
        
        // Add 10% padding for better visualization
        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding, maxPrice + padding)
    }
    
    /// Get visible candles for a given index range
    func visibleCandles(in range: Range<Int>) -> ArraySlice<Candle> {
        let safeRange = Swift.max(0, range.lowerBound)..<Swift.min(count, range.upperBound)
        return self[safeRange]
    }
    
    /// Calculate simple moving average
    func sma(period: Int) -> [Double] {
        guard count >= period else { return [] }
        
        var result: [Double] = []
        for i in (period - 1)..<count {
            let slice = self[(i - period + 1)...i]
            let sum = slice.reduce(0) { $0 + $1.close }
            result.append(sum / Double(period))
        }
        return result
    }
    
    /// Calculate exponential moving average
    func ema(period: Int) -> [Double] {
        guard count >= period else { return [] }
        
        var result: [Double] = []
        let multiplier = 2.0 / Double(period + 1)
        
        // Start with SMA for first value
        let firstSMA = self[0..<period].reduce(0) { $0 + $1.close } / Double(period)
        result.append(firstSMA)
        
        // Calculate EMA for remaining values
        for i in period..<count {
            let ema = (self[i].close - result.last!) * multiplier + result.last!
            result.append(ema)
        }
        
        return result
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// Standard animation for chart transitions
    static var chartAnimation: Animation {
        .interactiveSpring(response: 0.3, dampingFraction: 0.7)
    }
    
    /// Quick animation for immediate feedback
    static var quickChartAnimation: Animation {
        .easeInOut(duration: 0.2)
    }
    
    /// Smooth animation for price updates
    static var priceUpdateAnimation: Animation {
        .easeInOut(duration: 0.5)
    }
}

// MARK: - Constants

/// Centralized constants for the trading chart
enum ChartConstants {
    static let defaultCandleWidth: CGFloat = 12
    static let defaultCandleSpacing: CGFloat = 4
    static let edgePadding: CGFloat = 100
    static let gridLines = 10
    static let minZoomScale: CGFloat = 0.3
    static let maxZoomScale: CGFloat = 3.0
    static let updateInterval: TimeInterval = 5.0
    static let yAxisWidth: CGFloat = 60
    static let xAxisHeight: CGFloat = 20
}

// MARK: - Timeframe Enum

/// Available timeframes for the trading chart
enum Timeframe: String, CaseIterable {
    case m1 = "1m"
    case m5 = "5m"
    case m15 = "15m"
    case m30 = "30m"
    case h1 = "1H"
    case h4 = "4H"
    case d1 = "1D"
    case w1 = "1W"
    case mn = "1M"
    
    /// Duration in seconds for each timeframe
    var seconds: TimeInterval {
        switch self {
        case .m1: return 60
        case .m5: return 300
        case .m15: return 900
        case .m30: return 1800
        case .h1: return 3600
        case .h4: return 14400
        case .d1: return 86400
        case .w1: return 604800
        case .mn: return 2592000
        }
    }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .m1: return "1 Minute"
        case .m5: return "5 Minutes"
        case .m15: return "15 Minutes"
        case .m30: return "30 Minutes"
        case .h1: return "1 Hour"
        case .h4: return "4 Hours"
        case .d1: return "Daily"
        case .w1: return "Weekly"
        case .mn: return "Monthly"
        }
    }
}
