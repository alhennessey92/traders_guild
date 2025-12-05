//
//  IndicatorModels.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/12/2025.
//

//
//  IndicatorModels.swift
//  traders_guild
//
//  Professional indicator system models
//  Defines indicator types, configurations, and computed data structures
//

import SwiftUI

// MARK: - Indicator Type

/// All available indicator types
enum IndicatorType: String, Codable, CaseIterable, Identifiable {
    case ema = "EMA"
    case sma = "SMA"
    case rsi = "RSI"
    case macd = "MACD"
    case bollingerBands = "Bollinger"
    case volume = "Volume"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ema: return "Exponential Moving Average"
        case .sma: return "Simple Moving Average"
        case .rsi: return "Relative Strength Index"
        case .macd: return "MACD"
        case .bollingerBands: return "Bollinger Bands"
        case .volume: return "Volume"
        }
    }
    
    var shortName: String { rawValue }
    
    var icon: String {
        switch self {
        case .ema, .sma: return "chart.line.uptrend.xyaxis"
        case .rsi: return "waveform.path.ecg"
        case .macd: return "chart.bar.xaxis"
        case .bollingerBands: return "arrow.up.and.down"
        case .volume: return "chart.bar"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .ema: return .cyan
        case .sma: return .orange
        case .rsi: return .purple
        case .macd: return .green
        case .bollingerBands: return .pink
        case .volume: return .blue
        }
    }
    
    /// Whether this indicator is drawn directly on the price chart
    var isOverlay: Bool {
        switch self {
        case .ema, .sma, .bollingerBands:
            return true
        case .rsi, .macd, .volume:
            return false
        }
    }
    
    /// Category for grouping in UI
    var category: IndicatorCategory {
        switch self {
        case .ema, .sma:
            return .movingAverages
        case .rsi, .macd:
            return .momentum
        case .bollingerBands:
            return .volatility
        case .volume:
            return .volume
        }
    }
    
    /// Description for help text
    var description: String {
        switch self {
        case .ema:
            return "Exponential Moving Average gives more weight to recent prices, reacting faster to price changes."
        case .sma:
            return "Simple Moving Average calculates the arithmetic mean of prices over a specified period."
        case .rsi:
            return "Relative Strength Index measures the speed and magnitude of recent price changes to evaluate overbought or oversold conditions."
        case .macd:
            return "Moving Average Convergence Divergence shows the relationship between two moving averages."
        case .bollingerBands:
            return "Bollinger Bands measure volatility using standard deviations around a moving average."
        case .volume:
            return "Volume shows the number of shares or contracts traded."
        }
    }
}

// MARK: - Indicator Category

enum IndicatorCategory: String, CaseIterable {
    case movingAverages = "Moving Averages"
    case momentum = "Momentum"
    case volatility = "Volatility"
    case volume = "Volume"
    
    var icon: String {
        switch self {
        case .movingAverages: return "chart.line.uptrend.xyaxis"
        case .momentum: return "waveform.path.ecg"
        case .volatility: return "arrow.up.and.down"
        case .volume: return "chart.bar"
        }
    }
    
    var indicators: [IndicatorType] {
        IndicatorType.allCases.filter { $0.category == self }
    }
}

// MARK: - Indicator Configuration

/// Base configuration for all indicators
protocol IndicatorConfiguration: Identifiable, Codable, Hashable {
    var id: UUID { get }
    var type: IndicatorType { get }
    var isEnabled: Bool { get set }
    var color: CodableColor { get set }
    var lineWidth: CGFloat { get set }
}

/// EMA/SMA Configuration
struct MovingAverageConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType
    var isEnabled: Bool
    var color: CodableColor
    var lineWidth: CGFloat
    var period: Int
    var priceSource: PriceSource
    
    init(
        id: UUID = UUID(),
        type: IndicatorType = .ema,
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.cyan),
        lineWidth: CGFloat = 1.5,
        period: Int = 20,
        priceSource: PriceSource = .close
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.period = period
        self.priceSource = priceSource
    }
    
    /// Label for display (e.g., "EMA 20")
    var label: String {
        "\(type.shortName) \(period)"
    }
}

/// RSI Configuration
struct RSIConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .rsi
    var isEnabled: Bool
    var color: CodableColor
    var lineWidth: CGFloat
    var period: Int
    var overboughtLevel: Double
    var oversoldLevel: Double
    var showLevels: Bool
    var overboughtColor: CodableColor
    var oversoldColor: CodableColor
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.purple),
        lineWidth: CGFloat = 1.5,
        period: Int = 14,
        overboughtLevel: Double = 70,
        oversoldLevel: Double = 30,
        showLevels: Bool = true,
        overboughtColor: CodableColor = CodableColor(.red.opacity(0.5)),
        oversoldColor: CodableColor = CodableColor(.green.opacity(0.5))
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.period = period
        self.overboughtLevel = overboughtLevel
        self.oversoldLevel = oversoldLevel
        self.showLevels = showLevels
        self.overboughtColor = overboughtColor
        self.oversoldColor = oversoldColor
    }
    
    var label: String {
        "RSI \(period)"
    }
}

// MARK: - Price Source

enum PriceSource: String, Codable, CaseIterable {
    case open = "Open"
    case high = "High"
    case low = "Low"
    case close = "Close"
    case hl2 = "HL/2"      // (High + Low) / 2
    case hlc3 = "HLC/3"    // (High + Low + Close) / 3
    case ohlc4 = "OHLC/4"  // (Open + High + Low + Close) / 4
    
    func price(from candle: Candle) -> Double {
        switch self {
        case .open: return candle.open
        case .high: return candle.high
        case .low: return candle.low
        case .close: return candle.close
        case .hl2: return (candle.high + candle.low) / 2
        case .hlc3: return (candle.high + candle.low + candle.close) / 3
        case .ohlc4: return (candle.open + candle.high + candle.low + candle.close) / 4
        }
    }
}

// MARK: - Computed Indicator Data

/// Computed EMA/SMA data point
struct MovingAverageDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let value: Double
    let timestamp: Date
}

/// Computed RSI data point
struct RSIDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let value: Double
    let timestamp: Date
    
    var isOverbought: Bool { value >= 70 }
    var isOversold: Bool { value <= 30 }
    var condition: RSICondition {
        if value >= 70 { return .overbought }
        if value <= 30 { return .oversold }
        return .neutral
    }
}

enum RSICondition {
    case overbought
    case oversold
    case neutral
    
    var color: Color {
        switch self {
        case .overbought: return .red
        case .oversold: return .green
        case .neutral: return .gray
        }
    }
}

// MARK: - Codable Color Wrapper

/// Wrapper to make Color codable
struct CodableColor: Codable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    init(_ color: Color) {
        // Extract RGB from color
        // Note: This is a simplified implementation
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
}

// MARK: - Preset Configurations

extension MovingAverageConfig {
    /// Common EMA presets
    static let ema9 = MovingAverageConfig(type: .ema, color: CodableColor(.cyan), period: 9)
    static let ema20 = MovingAverageConfig(type: .ema, color: CodableColor(.yellow), period: 20)
    static let ema50 = MovingAverageConfig(type: .ema, color: CodableColor(.orange), period: 50)
    static let ema100 = MovingAverageConfig(type: .ema, color: CodableColor(.red), period: 100)
    static let ema200 = MovingAverageConfig(type: .ema, color: CodableColor(.purple), period: 200)
    
    /// Common SMA presets
    static let sma20 = MovingAverageConfig(type: .sma, color: CodableColor(.blue), period: 20)
    static let sma50 = MovingAverageConfig(type: .sma, color: CodableColor(.green), period: 50)
    static let sma200 = MovingAverageConfig(type: .sma, color: CodableColor(.red), period: 200)
    
    static var defaultEMAPresets: [MovingAverageConfig] {
        [.ema9, .ema20, .ema50, .ema100, .ema200]
    }
    
    static var defaultSMAPresets: [MovingAverageConfig] {
        [.sma20, .sma50, .sma200]
    }
}

extension RSIConfig {
    static let standard = RSIConfig()
    static let fast = RSIConfig(period: 7)
    static let slow = RSIConfig(period: 21)
}

// MARK: - Active Indicators State

/// Tracks all currently active indicators
struct ActiveIndicators: Codable {
    var movingAverages: [MovingAverageConfig] = []
    var rsi: RSIConfig?
    
    /// Check if any indicators are active
    var hasActiveIndicators: Bool {
        !movingAverages.filter(\.isEnabled).isEmpty || (rsi?.isEnabled ?? false)
    }
    
    /// Check if any panel indicators are active (non-overlay)
    var hasPanelIndicators: Bool {
        rsi?.isEnabled ?? false
    }
    
    /// Check if any overlay indicators are active
    var hasOverlayIndicators: Bool {
        !movingAverages.filter(\.isEnabled).isEmpty
    }
    
    /// Get enabled moving averages
    var enabledMovingAverages: [MovingAverageConfig] {
        movingAverages.filter(\.isEnabled)
    }
}
