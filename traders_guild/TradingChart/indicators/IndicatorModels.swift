//
//  IndicatorModels.swift
//  traders_guild
//
//  EXPANDED VERSION - Adds MACD, Stochastic configs with 2-panel limit enforcement
//

import SwiftUI

// MARK: - Indicator Type

enum IndicatorType: String, Codable, CaseIterable, Identifiable {
    case ema = "EMA"
    case sma = "SMA"
    case rsi = "RSI"
    case macd = "MACD"
    case stochastic = "Stochastic"
    case bollingerBands = "Bollinger"
    case vwap = "VWAP"
    case volume = "Volume"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ema: return "Exponential Moving Average"
        case .sma: return "Simple Moving Average"
        case .rsi: return "Relative Strength Index"
        case .macd: return "MACD"
        case .stochastic: return "Stochastic Oscillator"
        case .bollingerBands: return "Bollinger Bands"
        case .vwap: return "Volume Weighted Average Price"
        case .volume: return "Volume"
        }
    }
    
    var shortName: String { rawValue }
    
    var icon: String {
        switch self {
        case .ema, .sma: return "chart.line.uptrend.xyaxis"
        case .rsi: return "waveform.path.ecg"
        case .macd: return "chart.bar.xaxis"
        case .stochastic: return "waveform.path.ecg.rectangle"
        case .bollingerBands: return "arrow.up.and.down"
        case .vwap: return "chart.line.flattrend.xyaxis"
        case .volume: return "chart.bar"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .ema: return .cyan
        case .sma: return .orange
        case .rsi: return .purple
        case .macd: return .cyan
        case .stochastic: return .yellow
        case .bollingerBands: return .pink
        case .vwap: return .orange
        case .volume: return .blue
        }
    }
    
    var isOverlay: Bool {
        switch self {
        case .ema, .sma, .bollingerBands, .vwap:
            return true
        case .rsi, .macd, .stochastic, .volume:
            return false
        }
    }
    
    var category: IndicatorCategory {
        switch self {
        case .ema, .sma:
            return .movingAverages
        case .rsi, .macd, .stochastic:
            return .momentum
        case .bollingerBands:
            return .volatility
        case .vwap, .volume:
            return .volume
        }
    }
    
    var description: String {
        switch self {
        case .ema:
            return "Exponential Moving Average gives more weight to recent prices."
        case .sma:
            return "Simple Moving Average calculates the arithmetic mean of prices."
        case .rsi:
            return "RSI measures overbought or oversold conditions (0-100 scale)."
        case .macd:
            return "MACD shows relationship between two moving averages with histogram."
        case .stochastic:
            return "Stochastic compares closing price to price range over a period."
        case .bollingerBands:
            return "Bollinger Bands measure volatility using standard deviations."
        case .vwap:
            return "VWAP shows average price weighted by volume, used as trading benchmark."
        case .volume:
            return "Volume shows trading activity."
        }
    }
}

// MARK: - Panel Indicator Type

/// Types of indicators that appear in separate panels (not overlays)
enum PanelIndicatorType: String, Codable, CaseIterable, Identifiable, Hashable {
    case rsi = "RSI"
    case macd = "MACD"
    case stochastic = "Stochastic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rsi: return "Relative Strength Index"
        case .macd: return "Moving Average Convergence Divergence"
        case .stochastic: return "Stochastic Oscillator"
        }
    }
    
    var icon: String {
        switch self {
        case .rsi: return "waveform.path.ecg"
        case .macd: return "chart.bar.xaxis"
        case .stochastic: return "waveform.path.ecg.rectangle"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .rsi: return .purple
        case .macd: return .cyan
        case .stochastic: return .yellow
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

// MARK: - Indicator Configuration Protocol

protocol IndicatorConfiguration: Identifiable, Codable, Hashable {
    var id: UUID { get }
    var type: IndicatorType { get }
    var isEnabled: Bool { get set }
    var color: CodableColor { get set }
    var lineWidth: CGFloat { get set }
}

// MARK: - Moving Average Configuration

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
    
    var label: String {
        "\(type.shortName) \(period)"
    }
}

// MARK: - RSI Configuration

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
        overboughtColor: CodableColor = CodableColor(.red.opacity(0.15)),
        oversoldColor: CodableColor = CodableColor(.green.opacity(0.15))
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
    
    var label: String { "RSI \(period)" }
}

// MARK: - MACD Configuration

struct MACDConfig: IndicatorConfiguration, Identifiable {
    let id: UUID
    let type: IndicatorType = .macd
    var isEnabled: Bool
    var color: CodableColor  // MACD line color
    var lineWidth: CGFloat
    
    var fastPeriod: Int
    var slowPeriod: Int
    var signalPeriod: Int
    
    var signalColor: CodableColor
    var histogramPositiveColor: CodableColor
    var histogramNegativeColor: CodableColor
    
    var showHistogram: Bool
    var showSignalLine: Bool
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.cyan),
        lineWidth: CGFloat = 1.5,
        fastPeriod: Int = 12,
        slowPeriod: Int = 26,
        signalPeriod: Int = 9,
        signalColor: CodableColor = CodableColor(.orange),
        histogramPositiveColor: CodableColor = CodableColor(.green.opacity(0.7)),
        histogramNegativeColor: CodableColor = CodableColor(.red.opacity(0.7)),
        showHistogram: Bool = true,
        showSignalLine: Bool = true
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.fastPeriod = fastPeriod
        self.slowPeriod = slowPeriod
        self.signalPeriod = signalPeriod
        self.signalColor = signalColor
        self.histogramPositiveColor = histogramPositiveColor
        self.histogramNegativeColor = histogramNegativeColor
        self.showHistogram = showHistogram
        self.showSignalLine = showSignalLine
    }
    
    var label: String { "MACD(\(fastPeriod),\(slowPeriod),\(signalPeriod))" }
    var shortLabel: String { "MACD" }
    
    // Presets
    static let standard = MACDConfig()
    static let fast = MACDConfig(fastPeriod: 8, slowPeriod: 17, signalPeriod: 9)
    static let slow = MACDConfig(fastPeriod: 19, slowPeriod: 39, signalPeriod: 9)
}

// MARK: - Stochastic Configuration

struct StochasticConfig: IndicatorConfiguration, Identifiable {
    let id: UUID
    let type: IndicatorType = .stochastic
    var isEnabled: Bool
    var color: CodableColor  // %K line color
    var lineWidth: CGFloat
    
    var kPeriod: Int      // %K period (lookback)
    var dPeriod: Int      // %D period (signal smoothing)
    var smoothK: Int      // %K smoothing
    
    var dColor: CodableColor  // %D line color
    
    var overboughtLevel: Double
    var oversoldLevel: Double
    var showLevels: Bool
    var overboughtColor: CodableColor
    var oversoldColor: CodableColor
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.yellow),
        lineWidth: CGFloat = 1.5,
        kPeriod: Int = 14,
        dPeriod: Int = 3,
        smoothK: Int = 3,
        dColor: CodableColor = CodableColor(.red),
        overboughtLevel: Double = 80,
        oversoldLevel: Double = 20,
        showLevels: Bool = true,
        overboughtColor: CodableColor = CodableColor(.red.opacity(0.15)),
        oversoldColor: CodableColor = CodableColor(.green.opacity(0.15))
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.kPeriod = kPeriod
        self.dPeriod = dPeriod
        self.smoothK = smoothK
        self.dColor = dColor
        self.overboughtLevel = overboughtLevel
        self.oversoldLevel = oversoldLevel
        self.showLevels = showLevels
        self.overboughtColor = overboughtColor
        self.oversoldColor = oversoldColor
    }
    
    var label: String { "Stoch(\(kPeriod),\(dPeriod),\(smoothK))" }
    var shortLabel: String { "Stochastic" }
    
    // Presets
    static let standard = StochasticConfig()
    static let fast = StochasticConfig(kPeriod: 5, dPeriod: 3, smoothK: 1)
    static let slow = StochasticConfig(kPeriod: 21, dPeriod: 7, smoothK: 7)
}

// MARK: - Price Source

enum PriceSource: String, Codable, CaseIterable {
    case open = "Open"
    case high = "High"
    case low = "Low"
    case close = "Close"
    case hl2 = "HL/2"
    case hlc3 = "HLC/3"
    case ohlc4 = "OHLC/4"
    
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

// MARK: - Computed Data Points

struct MovingAverageDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let value: Double
    let timestamp: Date
}

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
    case overbought, oversold, neutral
    
    var color: Color {
        switch self {
        case .overbought: return .red
        case .oversold: return .green
        case .neutral: return .gray
        }
    }
}

// MARK: - MACD Data Point

struct MACDDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let timestamp: Date
    let macdLine: Double      // MACD line (fast EMA - slow EMA)
    let signalLine: Double    // Signal line (EMA of MACD)
    let histogram: Double     // MACD - Signal
    
    var isHistogramPositive: Bool { histogram >= 0 }
    
    var crossoverType: MACDCrossover {
        if macdLine > signalLine && histogram > 0 {
            return .bullish
        } else if macdLine < signalLine && histogram < 0 {
            return .bearish
        }
        return .neutral
    }
}

enum MACDCrossover {
    case bullish, bearish, neutral
    
    var color: Color {
        switch self {
        case .bullish: return .green
        case .bearish: return .red
        case .neutral: return .gray
        }
    }
    
    var label: String {
        switch self {
        case .bullish: return "BULLISH"
        case .bearish: return "BEARISH"
        case .neutral: return ""
        }
    }
}

// MARK: - Stochastic Data Point

struct StochasticDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let timestamp: Date
    let kValue: Double   // %K (fast line)
    let dValue: Double   // %D (slow/signal line)
    
    var condition: StochasticCondition {
        if kValue >= 80 { return .overbought }
        if kValue <= 20 { return .oversold }
        return .neutral
    }
}

enum StochasticCondition {
    case overbought, oversold, neutral
    
    var color: Color {
        switch self {
        case .overbought: return .red
        case .oversold: return .green
        case .neutral: return .gray
        }
    }
}

// MARK: - Codable Color Wrapper

struct CodableColor: Codable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    init(_ color: Color) {
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

// MARK: - Bollinger Bands Configuration

struct BollingerBandsConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .bollingerBands
    var isEnabled: Bool
    var color: CodableColor  // Middle band color
    var lineWidth: CGFloat
    var period: Int
    var standardDeviations: Double
    var upperBandColor: CodableColor
    var lowerBandColor: CodableColor
    var fillColor: CodableColor
    var showFill: Bool
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.gray),
        lineWidth: CGFloat = 1.0,
        period: Int = 20,
        standardDeviations: Double = 2.0,
        upperBandColor: CodableColor = CodableColor(.red.opacity(0.7)),
        lowerBandColor: CodableColor = CodableColor(.green.opacity(0.7)),
        fillColor: CodableColor = CodableColor(.blue.opacity(0.1)),
        showFill: Bool = true
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.period = period
        self.standardDeviations = standardDeviations
        self.upperBandColor = upperBandColor
        self.lowerBandColor = lowerBandColor
        self.fillColor = fillColor
        self.showFill = showFill
    }
    
    var label: String {
        "BB(\(period),\(String(format: "%.1f", standardDeviations)))"
    }
}

/// Bollinger Bands computed data point
struct BollingerBandsDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let middleBand: Double  // SMA
    let upperBand: Double   // SMA + (stdDev * multiplier)
    let lowerBand: Double   // SMA - (stdDev * multiplier)
    let bandwidth: Double   // (upper - lower) / middle * 100
    let timestamp: Date
}

// MARK: - VWAP Configuration

struct VWAPConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .vwap
    var isEnabled: Bool
    var color: CodableColor
    var lineWidth: CGFloat
    var showStandardDeviationBands: Bool
    var upperBandColor: CodableColor
    var lowerBandColor: CodableColor
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.orange),
        lineWidth: CGFloat = 1.5,
        showStandardDeviationBands: Bool = false,
        upperBandColor: CodableColor = CodableColor(.orange.opacity(0.5)),
        lowerBandColor: CodableColor = CodableColor(.orange.opacity(0.5))
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.showStandardDeviationBands = showStandardDeviationBands
        self.upperBandColor = upperBandColor
        self.lowerBandColor = lowerBandColor
    }
    
    var label: String { "VWAP" }
}

/// VWAP computed data point
struct VWAPDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let vwap: Double
    let upperBand: Double?  // VWAP + 1 stdDev
    let lowerBand: Double?  // VWAP - 1 stdDev
    let timestamp: Date
}

// MARK: - Preset Configurations

extension MovingAverageConfig {
    static let ema9 = MovingAverageConfig(type: .ema, color: CodableColor(.cyan), period: 9)
    static let ema20 = MovingAverageConfig(type: .ema, color: CodableColor(.yellow), period: 20)
    static let ema50 = MovingAverageConfig(type: .ema, color: CodableColor(.orange), period: 50)
    static let ema100 = MovingAverageConfig(type: .ema, color: CodableColor(.red), period: 100)
    static let ema200 = MovingAverageConfig(type: .ema, color: CodableColor(.purple), period: 200)
    
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

struct ActiveIndicators: Codable {
    var movingAverages: [MovingAverageConfig] = []
    var bollingerBands: BollingerBandsConfig?
    var vwap: VWAPConfig?
    var rsi: RSIConfig?
    var macd: MACDConfig?
    var stochastic: StochasticConfig?
    
    // MARK: - Panel Limit Constants
    
    /// Maximum number of panel indicators allowed at once
    static let maxPanelIndicators: Int = 2
    
    // MARK: - Panel Count
    
    /// Current count of enabled panel indicators
    var enabledPanelCount: Int {
        var count = 0
        if rsi?.isEnabled == true { count += 1 }
        if macd?.isEnabled == true { count += 1 }
        if stochastic?.isEnabled == true { count += 1 }
        return count
    }
    
    /// Check if another panel indicator can be added
    var canAddPanelIndicator: Bool {
        enabledPanelCount < Self.maxPanelIndicators
    }
    
    /// Get ordered list of active panel types for rendering
    var activePanelTypes: [PanelIndicatorType] {
        var types: [PanelIndicatorType] = []
        if rsi?.isEnabled == true { types.append(.rsi) }
        if macd?.isEnabled == true { types.append(.macd) }
        if stochastic?.isEnabled == true { types.append(.stochastic) }
        return types
    }
    
    // MARK: - Existing Computed Properties
    
    var hasActiveIndicators: Bool {
        !movingAverages.filter(\.isEnabled).isEmpty ||
        (bollingerBands?.isEnabled ?? false) ||
        (vwap?.isEnabled ?? false) ||
        (rsi?.isEnabled ?? false) ||
        (macd?.isEnabled ?? false) ||
        (stochastic?.isEnabled ?? false)
    }
    
    var hasPanelIndicators: Bool {
        enabledPanelCount > 0
    }
    
    var hasOverlayIndicators: Bool {
        !movingAverages.filter(\.isEnabled).isEmpty ||
        (bollingerBands?.isEnabled ?? false) ||
        (vwap?.isEnabled ?? false)
    }
    
    var enabledMovingAverages: [MovingAverageConfig] {
        movingAverages.filter(\.isEnabled)
    }
}

// MARK: - Identifiable Extensions

extension MovingAverageConfig: Identifiable {}
extension RSIConfig: Identifiable {}
extension BollingerBandsConfig: Identifiable {}
extension VWAPConfig: Identifiable {}














////
////  IndicatorModels.swift
////  traders_guild
////
////  Created by Al Hennessey on 05/12/2025.
////
//
////
////  IndicatorModels.swift
////  traders_guild
////
////  Professional indicator system models
////  Defines indicator types, configurations, and computed data structures
////
//
//import SwiftUI
//
//// MARK: - Indicator Type
//
///// All available indicator types
//enum IndicatorType: String, Codable, CaseIterable, Identifiable {
//    case ema = "EMA"
//    case sma = "SMA"
//    case rsi = "RSI"
//    case macd = "MACD"
//    case bollingerBands = "Bollinger"
//    case volume = "Volume"
//    
//    var id: String { rawValue }
//    
//    var displayName: String {
//        switch self {
//        case .ema: return "Exponential Moving Average"
//        case .sma: return "Simple Moving Average"
//        case .rsi: return "Relative Strength Index"
//        case .macd: return "MACD"
//        case .bollingerBands: return "Bollinger Bands"
//        case .volume: return "Volume"
//        }
//    }
//    
//    var shortName: String { rawValue }
//    
//    var icon: String {
//        switch self {
//        case .ema, .sma: return "chart.line.uptrend.xyaxis"
//        case .rsi: return "waveform.path.ecg"
//        case .macd: return "chart.bar.xaxis"
//        case .bollingerBands: return "arrow.up.and.down"
//        case .volume: return "chart.bar"
//        }
//    }
//    
//    var defaultColor: Color {
//        switch self {
//        case .ema: return .cyan
//        case .sma: return .orange
//        case .rsi: return .purple
//        case .macd: return .green
//        case .bollingerBands: return .pink
//        case .volume: return .blue
//        }
//    }
//    
//    /// Whether this indicator is drawn directly on the price chart
//    var isOverlay: Bool {
//        switch self {
//        case .ema, .sma, .bollingerBands:
//            return true
//        case .rsi, .macd, .volume:
//            return false
//        }
//    }
//    
//    /// Category for grouping in UI
//    var category: IndicatorCategory {
//        switch self {
//        case .ema, .sma:
//            return .movingAverages
//        case .rsi, .macd:
//            return .momentum
//        case .bollingerBands:
//            return .volatility
//        case .volume:
//            return .volume
//        }
//    }
//    
//    /// Description for help text
//    var description: String {
//        switch self {
//        case .ema:
//            return "Exponential Moving Average gives more weight to recent prices, reacting faster to price changes."
//        case .sma:
//            return "Simple Moving Average calculates the arithmetic mean of prices over a specified period."
//        case .rsi:
//            return "Relative Strength Index measures the speed and magnitude of recent price changes to evaluate overbought or oversold conditions."
//        case .macd:
//            return "Moving Average Convergence Divergence shows the relationship between two moving averages."
//        case .bollingerBands:
//            return "Bollinger Bands measure volatility using standard deviations around a moving average."
//        case .volume:
//            return "Volume shows the number of shares or contracts traded."
//        }
//    }
//}
//
//// MARK: - Indicator Category
//
//enum IndicatorCategory: String, CaseIterable {
//    case movingAverages = "Moving Averages"
//    case momentum = "Momentum"
//    case volatility = "Volatility"
//    case volume = "Volume"
//    
//    var icon: String {
//        switch self {
//        case .movingAverages: return "chart.line.uptrend.xyaxis"
//        case .momentum: return "waveform.path.ecg"
//        case .volatility: return "arrow.up.and.down"
//        case .volume: return "chart.bar"
//        }
//    }
//    
//    var indicators: [IndicatorType] {
//        IndicatorType.allCases.filter { $0.category == self }
//    }
//}
//
//// MARK: - Indicator Configuration
//
///// Base configuration for all indicators
//protocol IndicatorConfiguration: Identifiable, Codable, Hashable {
//    var id: UUID { get }
//    var type: IndicatorType { get }
//    var isEnabled: Bool { get set }
//    var color: CodableColor { get set }
//    var lineWidth: CGFloat { get set }
//}
//
///// EMA/SMA Configuration
//struct MovingAverageConfig: IndicatorConfiguration {
//    let id: UUID
//    let type: IndicatorType
//    var isEnabled: Bool
//    var color: CodableColor
//    var lineWidth: CGFloat
//    var period: Int
//    var priceSource: PriceSource
//    
//    init(
//        id: UUID = UUID(),
//        type: IndicatorType = .ema,
//        isEnabled: Bool = true,
//        color: CodableColor = CodableColor(.cyan),
//        lineWidth: CGFloat = 1.5,
//        period: Int = 20,
//        priceSource: PriceSource = .close
//    ) {
//        self.id = id
//        self.type = type
//        self.isEnabled = isEnabled
//        self.color = color
//        self.lineWidth = lineWidth
//        self.period = period
//        self.priceSource = priceSource
//    }
//    
//    /// Label for display (e.g., "EMA 20")
//    var label: String {
//        "\(type.shortName) \(period)"
//    }
//}
//
///// RSI Configuration
//struct RSIConfig: IndicatorConfiguration {
//    let id: UUID
//    let type: IndicatorType = .rsi
//    var isEnabled: Bool
//    var color: CodableColor
//    var lineWidth: CGFloat
//    var period: Int
//    var overboughtLevel: Double
//    var oversoldLevel: Double
//    var showLevels: Bool
//    var overboughtColor: CodableColor
//    var oversoldColor: CodableColor
//    
//    init(
//        id: UUID = UUID(),
//        isEnabled: Bool = true,
//        color: CodableColor = CodableColor(.purple),
//        lineWidth: CGFloat = 1.5,
//        period: Int = 14,
//        overboughtLevel: Double = 70,
//        oversoldLevel: Double = 30,
//        showLevels: Bool = true,
//        overboughtColor: CodableColor = CodableColor(.red.opacity(0.5)),
//        oversoldColor: CodableColor = CodableColor(.green.opacity(0.5))
//    ) {
//        self.id = id
//        self.isEnabled = isEnabled
//        self.color = color
//        self.lineWidth = lineWidth
//        self.period = period
//        self.overboughtLevel = overboughtLevel
//        self.oversoldLevel = oversoldLevel
//        self.showLevels = showLevels
//        self.overboughtColor = overboughtColor
//        self.oversoldColor = oversoldColor
//    }
//    
//    var label: String {
//        "RSI \(period)"
//    }
//}
//
//// MARK: - Price Source
//
//enum PriceSource: String, Codable, CaseIterable {
//    case open = "Open"
//    case high = "High"
//    case low = "Low"
//    case close = "Close"
//    case hl2 = "HL/2"      // (High + Low) / 2
//    case hlc3 = "HLC/3"    // (High + Low + Close) / 3
//    case ohlc4 = "OHLC/4"  // (Open + High + Low + Close) / 4
//    
//    func price(from candle: Candle) -> Double {
//        switch self {
//        case .open: return candle.open
//        case .high: return candle.high
//        case .low: return candle.low
//        case .close: return candle.close
//        case .hl2: return (candle.high + candle.low) / 2
//        case .hlc3: return (candle.high + candle.low + candle.close) / 3
//        case .ohlc4: return (candle.open + candle.high + candle.low + candle.close) / 4
//        }
//    }
//}
//
//// MARK: - Computed Indicator Data
//
///// Computed EMA/SMA data point
//struct MovingAverageDataPoint: Identifiable {
//    let id = UUID()
//    let candleIndex: Int
//    let value: Double
//    let timestamp: Date
//}
//
///// Computed RSI data point
//struct RSIDataPoint: Identifiable {
//    let id = UUID()
//    let candleIndex: Int
//    let value: Double
//    let timestamp: Date
//    
//    var isOverbought: Bool { value >= 70 }
//    var isOversold: Bool { value <= 30 }
//    var condition: RSICondition {
//        if value >= 70 { return .overbought }
//        if value <= 30 { return .oversold }
//        return .neutral
//    }
//}
//
//enum RSICondition {
//    case overbought
//    case oversold
//    case neutral
//    
//    var color: Color {
//        switch self {
//        case .overbought: return .red
//        case .oversold: return .green
//        case .neutral: return .gray
//        }
//    }
//}
//
//// MARK: - Codable Color Wrapper
//
///// Wrapper to make Color codable
//struct CodableColor: Codable, Hashable {
//    let red: Double
//    let green: Double
//    let blue: Double
//    let opacity: Double
//    
//    var color: Color {
//        Color(red: red, green: green, blue: blue, opacity: opacity)
//    }
//    
//    init(_ color: Color) {
//        // Extract RGB from color
//        // Note: This is a simplified implementation
//        let uiColor = UIColor(color)
//        var r: CGFloat = 0
//        var g: CGFloat = 0
//        var b: CGFloat = 0
//        var a: CGFloat = 0
//        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
//        
//        self.red = Double(r)
//        self.green = Double(g)
//        self.blue = Double(b)
//        self.opacity = Double(a)
//    }
//    
//    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
//        self.red = red
//        self.green = green
//        self.blue = blue
//        self.opacity = opacity
//    }
//}
//
//// MARK: - Preset Configurations
//
//extension MovingAverageConfig {
//    /// Common EMA presets
//    static let ema9 = MovingAverageConfig(type: .ema, color: CodableColor(.cyan), period: 9)
//    static let ema20 = MovingAverageConfig(type: .ema, color: CodableColor(.yellow), period: 20)
//    static let ema50 = MovingAverageConfig(type: .ema, color: CodableColor(.orange), period: 50)
//    static let ema100 = MovingAverageConfig(type: .ema, color: CodableColor(.red), period: 100)
//    static let ema200 = MovingAverageConfig(type: .ema, color: CodableColor(.purple), period: 200)
//    
//    /// Common SMA presets
//    static let sma20 = MovingAverageConfig(type: .sma, color: CodableColor(.blue), period: 20)
//    static let sma50 = MovingAverageConfig(type: .sma, color: CodableColor(.green), period: 50)
//    static let sma200 = MovingAverageConfig(type: .sma, color: CodableColor(.red), period: 200)
//    
//    static var defaultEMAPresets: [MovingAverageConfig] {
//        [.ema9, .ema20, .ema50, .ema100, .ema200]
//    }
//    
//    static var defaultSMAPresets: [MovingAverageConfig] {
//        [.sma20, .sma50, .sma200]
//    }
//}
//
//extension RSIConfig {
//    static let standard = RSIConfig()
//    static let fast = RSIConfig(period: 7)
//    static let slow = RSIConfig(period: 21)
//}
//
//// MARK: - Active Indicators State
//
///// Tracks all currently active indicators
//struct ActiveIndicators: Codable {
//    var movingAverages: [MovingAverageConfig] = []
//    var rsi: RSIConfig?
//    
//    /// Check if any indicators are active
//    var hasActiveIndicators: Bool {
//        !movingAverages.filter(\.isEnabled).isEmpty || (rsi?.isEnabled ?? false)
//    }
//    
//    /// Check if any panel indicators are active (non-overlay)
//    var hasPanelIndicators: Bool {
//        rsi?.isEnabled ?? false
//    }
//    
//    /// Check if any overlay indicators are active
//    var hasOverlayIndicators: Bool {
//        !movingAverages.filter(\.isEnabled).isEmpty
//    }
//    
//    /// Get enabled moving averages
//    var enabledMovingAverages: [MovingAverageConfig] {
//        movingAverages.filter(\.isEnabled)
//    }
//}
