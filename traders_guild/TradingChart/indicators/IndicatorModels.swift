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
    case wma = "WMA"
    case hma = "HMA"
    case vwap = "VWAP"
    case bollingerBands = "Bollinger"
    case donchianChannels = "Donchian"
    case keltnerChannels = "Keltner"
    case parabolicSAR = "SAR"
    case rsi = "RSI"
    case macd = "MACD"
    case stochastic = "Stochastic"
    case cci = "CCI"
    case williamsR = "Williams %R"
    case atr = "ATR"
    case volume = "Volume"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ema: return "Exponential Moving Average"
        case .sma: return "Simple Moving Average"
        case .wma: return "Weighted Moving Average"
        case .hma: return "Hull Moving Average"
        case .vwap: return "Volume Weighted Average Price"
        case .bollingerBands: return "Bollinger Bands"
        case .donchianChannels: return "Donchian Channels"
        case .keltnerChannels: return "Keltner Channels"
        case .parabolicSAR: return "Parabolic SAR"
        case .rsi: return "Relative Strength Index"
        case .macd: return "MACD"
        case .stochastic: return "Stochastic Oscillator"
        case .cci: return "Commodity Channel Index"
        case .williamsR: return "Williams %R"
        case .atr: return "Average True Range"
        case .volume: return "Volume"
        }
    }
    
    var shortName: String { rawValue }
    
    var icon: String {
        switch self {
        case .ema, .sma, .wma, .hma: return "chart.line.uptrend.xyaxis"
        case .vwap: return "chart.line.flattrend.xyaxis"
        case .bollingerBands, .donchianChannels, .keltnerChannels: return "arrow.up.and.down"
        case .parabolicSAR: return "circle.dotted"
        case .rsi: return "waveform.path.ecg"
        case .macd: return "chart.bar.xaxis"
        case .stochastic, .williamsR: return "waveform.path.ecg.rectangle"
        case .cci: return "arrow.up.arrow.down.circle"
        case .atr: return "ruler"
        case .volume: return "chart.bar"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .ema: return .cyan
        case .sma: return .orange
        case .wma: return .yellow
        case .hma: return .mint
        case .vwap: return .orange
        case .bollingerBands: return .pink
        case .donchianChannels: return .blue
        case .keltnerChannels: return .purple
        case .parabolicSAR: return .yellow
        case .rsi: return .purple
        case .macd: return .cyan
        case .stochastic: return .yellow
        case .cci: return .orange
        case .williamsR: return .pink
        case .atr: return .red
        case .volume: return .blue
        }
    }
    
    var isOverlay: Bool {
        switch self {
        case .ema, .sma, .wma, .hma, .vwap, .bollingerBands, .donchianChannels, .keltnerChannels, .parabolicSAR:
            return true
        case .rsi, .macd, .stochastic, .cci, .williamsR, .atr, .volume:
            return false
        }
    }
    
    var category: IndicatorCategory {
        switch self {
        case .ema, .sma, .wma, .hma, .vwap, .parabolicSAR:
            return .trend
        case .bollingerBands, .donchianChannels, .keltnerChannels, .atr:
            return .volatility
        case .rsi, .macd, .stochastic, .cci, .williamsR:
            return .momentum
        case .volume:
            return .volume
        }
    }
    
    var description: String {
        switch self {
        case .ema:
            return "Exponential Moving Average gives more weight to recent prices."
        case .sma:
            return "Simple Moving Average calculates the arithmetic mean of prices."
        case .wma:
            return "Weighted Moving Average assigns linearly increasing weights to recent prices."
        case .hma:
            return "Hull Moving Average reduces lag while maintaining smoothness."
        case .vwap:
            return "VWAP shows average price weighted by volume, used as trading benchmark."
        case .bollingerBands:
            return "Bollinger Bands measure volatility using standard deviations."
        case .donchianChannels:
            return "Donchian Channels show highest high and lowest low over a period."
        case .keltnerChannels:
            return "Keltner Channels use ATR-based bands around an EMA."
        case .parabolicSAR:
            return "Parabolic SAR identifies potential reversals with trailing dots."
        case .rsi:
            return "RSI measures overbought or oversold conditions (0-100 scale)."
        case .macd:
            return "MACD shows relationship between two moving averages with histogram."
        case .stochastic:
            return "Stochastic compares closing price to price range over a period."
        case .cci:
            return "CCI measures price deviation from its statistical mean."
        case .williamsR:
            return "Williams %R shows overbought/oversold levels (0 to -100)."
        case .atr:
            return "ATR measures market volatility using true range."
        case .volume:
            return "Volume shows trading activity for each period."
        }
    }
}

// MARK: - Panel Indicator Type

/// Types of indicators that appear in separate panels (not overlays)
enum PanelIndicatorType: String, Codable, CaseIterable, Identifiable, Hashable {
    case rsi = "RSI"
    case macd = "MACD"
    case stochastic = "Stochastic"
    case cci = "CCI"
    case williamsR = "Williams %R"
    case atr = "ATR"
    case volume = "Volume"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rsi: return "Relative Strength Index"
        case .macd: return "Moving Average Convergence Divergence"
        case .stochastic: return "Stochastic Oscillator"
        case .cci: return "Commodity Channel Index"
        case .williamsR: return "Williams %R"
        case .atr: return "Average True Range"
        case .volume: return "Volume"
        }
    }
    
    var icon: String {
        switch self {
        case .rsi: return "waveform.path.ecg"
        case .macd: return "chart.bar.xaxis"
        case .stochastic: return "waveform.path.ecg.rectangle"
        case .cci: return "arrow.up.arrow.down.circle"
        case .williamsR: return "waveform.path.ecg.rectangle"
        case .atr: return "ruler"
        case .volume: return "chart.bar"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .rsi: return .purple
        case .macd: return .cyan
        case .stochastic: return .yellow
        case .cci: return .orange
        case .williamsR: return .pink
        case .atr: return .red
        case .volume: return .blue
        }
    }
    
    var category: IndicatorCategory {
        switch self {
        case .rsi, .macd, .stochastic, .cci, .williamsR:
            return .momentum
        case .atr:
            return .volatility
        case .volume:
            return .volume
        }
    }
}

// MARK: - Indicator Category

enum IndicatorCategory: String, CaseIterable {
    case trend = "Trend"
    case volatility = "Volatility"
    case momentum = "Momentum"
    case volume = "Volume"
    
    var icon: String {
        switch self {
        case .trend: return "chart.line.uptrend.xyaxis"
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
    
    func price(from candle: RLCandleDTO) -> Double {
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

    var label: String {
        switch self {
        case .overbought: return "OVERBOUGHT"
        case .oversold: return "OVERSOLD"
        case .neutral: return ""
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

// MARK: - Donchian Channels Configuration

struct DonchianChannelsConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .donchianChannels
    var isEnabled: Bool
    var color: CodableColor  // Middle line color
    var lineWidth: CGFloat
    var period: Int
    var upperBandColor: CodableColor
    var lowerBandColor: CodableColor
    var fillColor: CodableColor
    var showFill: Bool
    var showMiddleLine: Bool
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.gray),
        lineWidth: CGFloat = 1.0,
        period: Int = 20,
        upperBandColor: CodableColor = CodableColor(.blue.opacity(0.8)),
        lowerBandColor: CodableColor = CodableColor(.blue.opacity(0.8)),
        fillColor: CodableColor = CodableColor(.blue.opacity(0.1)),
        showFill: Bool = true,
        showMiddleLine: Bool = true
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.period = period
        self.upperBandColor = upperBandColor
        self.lowerBandColor = lowerBandColor
        self.fillColor = fillColor
        self.showFill = showFill
        self.showMiddleLine = showMiddleLine
    }
    
    var label: String { "DC(\(period))" }
}

struct DonchianChannelsDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let upperBand: Double   // Highest high
    let lowerBand: Double   // Lowest low
    let middleLine: Double  // (Upper + Lower) / 2
    let timestamp: Date
}

// MARK: - Keltner Channels Configuration

struct KeltnerChannelsConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .keltnerChannels
    var isEnabled: Bool
    var color: CodableColor  // EMA color
    var lineWidth: CGFloat
    var emaPeriod: Int
    var atrPeriod: Int
    var atrMultiplier: Double
    var upperBandColor: CodableColor
    var lowerBandColor: CodableColor
    var fillColor: CodableColor
    var showFill: Bool
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.purple),
        lineWidth: CGFloat = 1.0,
        emaPeriod: Int = 20,
        atrPeriod: Int = 10,
        atrMultiplier: Double = 2.0,
        upperBandColor: CodableColor = CodableColor(.purple.opacity(0.7)),
        lowerBandColor: CodableColor = CodableColor(.purple.opacity(0.7)),
        fillColor: CodableColor = CodableColor(.purple.opacity(0.1)),
        showFill: Bool = true
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.emaPeriod = emaPeriod
        self.atrPeriod = atrPeriod
        self.atrMultiplier = atrMultiplier
        self.upperBandColor = upperBandColor
        self.lowerBandColor = lowerBandColor
        self.fillColor = fillColor
        self.showFill = showFill
    }
    
    var label: String { "KC(\(emaPeriod),\(atrPeriod))" }
}

struct KeltnerChannelsDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let ema: Double
    let upperBand: Double
    let lowerBand: Double
    let timestamp: Date
}

// MARK: - Parabolic SAR Configuration

struct ParabolicSARConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .parabolicSAR
    var isEnabled: Bool
    var color: CodableColor
    var lineWidth: CGFloat
    var accelerationStart: Double
    var accelerationIncrement: Double
    var accelerationMax: Double
    var bullishColor: CodableColor
    var bearishColor: CodableColor
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.yellow),
        lineWidth: CGFloat = 1.5,
        accelerationStart: Double = 0.02,
        accelerationIncrement: Double = 0.02,
        accelerationMax: Double = 0.2,
        bullishColor: CodableColor = CodableColor(.green),
        bearishColor: CodableColor = CodableColor(.red)
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.accelerationStart = accelerationStart
        self.accelerationIncrement = accelerationIncrement
        self.accelerationMax = accelerationMax
        self.bullishColor = bullishColor
        self.bearishColor = bearishColor
    }
    
    var label: String { "SAR" }
}

struct ParabolicSARDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let sar: Double
    let isUptrend: Bool
    let timestamp: Date
}

// MARK: - CCI Configuration

struct CCIConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .cci
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
        color: CodableColor = CodableColor(.orange),
        lineWidth: CGFloat = 1.5,
        period: Int = 20,
        overboughtLevel: Double = 100,
        oversoldLevel: Double = -100,
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
    
    var label: String { "CCI(\(period))" }
}

struct CCIDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let value: Double
    let timestamp: Date
    
    var condition: CCICondition {
        if value >= 100 { return .overbought }
        if value <= -100 { return .oversold }
        return .neutral
    }
}

enum CCICondition {
    case overbought, oversold, neutral
    
    var color: Color {
        switch self {
        case .overbought: return .red
        case .oversold: return .green
        case .neutral: return .gray
        }
    }

    var label: String {
        switch self {
        case .overbought: return "OVERBOUGHT"
        case .oversold: return "OVERSOLD"
        case .neutral: return ""
        }
    }
}

// MARK: - Williams %R Configuration

struct WilliamsRConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .williamsR
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
        color: CodableColor = CodableColor(.pink),
        lineWidth: CGFloat = 1.5,
        period: Int = 14,
        overboughtLevel: Double = -20,
        oversoldLevel: Double = -80,
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
    
    var label: String { "%R(\(period))" }
}

struct WilliamsRDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let value: Double  // 0 to -100
    let timestamp: Date
    
    var condition: WilliamsRCondition {
        if value >= -20 { return .overbought }
        if value <= -80 { return .oversold }
        return .neutral
    }
}

enum WilliamsRCondition {
    case overbought, oversold, neutral
    
    var color: Color {
        switch self {
        case .overbought: return .red
        case .oversold: return .green
        case .neutral: return .gray
        }
    }
}

// MARK: - ATR Configuration

struct ATRConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .atr
    var isEnabled: Bool
    var color: CodableColor
    var lineWidth: CGFloat
    var period: Int
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.red),
        lineWidth: CGFloat = 1.5,
        period: Int = 14
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.period = period
    }
    
    var label: String { "ATR(\(period))" }
}

struct ATRDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let value: Double
    let timestamp: Date
}

// MARK: - Volume Configuration

struct VolumeConfig: IndicatorConfiguration {
    let id: UUID
    let type: IndicatorType = .volume
    var isEnabled: Bool
    var color: CodableColor
    var lineWidth: CGFloat
    var bullishColor: CodableColor
    var bearishColor: CodableColor
    var showMA: Bool
    var maPeriod: Int
    var maColor: CodableColor
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        color: CodableColor = CodableColor(.blue),
        lineWidth: CGFloat = 1.0,
        bullishColor: CodableColor = CodableColor(.green.opacity(0.7)),
        bearishColor: CodableColor = CodableColor(.red.opacity(0.7)),
        showMA: Bool = false,
        maPeriod: Int = 20,
        maColor: CodableColor = CodableColor(.yellow)
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.color = color
        self.lineWidth = lineWidth
        self.bullishColor = bullishColor
        self.bearishColor = bearishColor
        self.showMA = showMA
        self.maPeriod = maPeriod
        self.maColor = maColor
    }
    
    var label: String { "Volume" }
}

struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let volume: Double
    let isBullish: Bool
    let ma: Double?  // Moving average of volume
    let timestamp: Date

    var condition: VolumeCondition {
        isBullish ? .bullish : .bearish
    }
}

enum VolumeCondition {
    case bullish
    case bearish

    var label: String {
        switch self {
        case .bullish: return "BULLISH"
        case .bearish: return "BEARISH"
        }
    }
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
    // Trend overlays
    var movingAverages: [MovingAverageConfig] = []  // EMA, SMA, WMA, HMA
    var vwap: VWAPConfig?
    var parabolicSAR: ParabolicSARConfig?
    
    // Volatility overlays
    var bollingerBands: BollingerBandsConfig?
    var donchianChannels: DonchianChannelsConfig?
    var keltnerChannels: KeltnerChannelsConfig?
    
    // Momentum panels
    var rsi: RSIConfig?
    var macd: MACDConfig?
    var stochastic: StochasticConfig?
    var cci: CCIConfig?
    var williamsR: WilliamsRConfig?
    
    // Volatility panels
    var atr: ATRConfig?
    
    // Volume panels
    var volume: VolumeConfig?
    
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
        if cci?.isEnabled == true { count += 1 }
        if williamsR?.isEnabled == true { count += 1 }
        if atr?.isEnabled == true { count += 1 }
        if volume?.isEnabled == true { count += 1 }
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
        if cci?.isEnabled == true { types.append(.cci) }
        if williamsR?.isEnabled == true { types.append(.williamsR) }
        if atr?.isEnabled == true { types.append(.atr) }
        if volume?.isEnabled == true { types.append(.volume) }
        return types
    }
    
    // MARK: - Existing Computed Properties
    
    var hasActiveIndicators: Bool {
        !movingAverages.filter(\.isEnabled).isEmpty ||
        (vwap?.isEnabled ?? false) ||
        (parabolicSAR?.isEnabled ?? false) ||
        (bollingerBands?.isEnabled ?? false) ||
        (donchianChannels?.isEnabled ?? false) ||
        (keltnerChannels?.isEnabled ?? false) ||
        (rsi?.isEnabled ?? false) ||
        (macd?.isEnabled ?? false) ||
        (stochastic?.isEnabled ?? false) ||
        (cci?.isEnabled ?? false) ||
        (williamsR?.isEnabled ?? false) ||
        (atr?.isEnabled ?? false) ||
        (volume?.isEnabled ?? false)
    }
    
    var hasPanelIndicators: Bool {
        enabledPanelCount > 0
    }
    
    var hasOverlayIndicators: Bool {
        !movingAverages.filter(\.isEnabled).isEmpty ||
        (vwap?.isEnabled ?? false) ||
        (parabolicSAR?.isEnabled ?? false) ||
        (bollingerBands?.isEnabled ?? false) ||
        (donchianChannels?.isEnabled ?? false) ||
        (keltnerChannels?.isEnabled ?? false)
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
extension DonchianChannelsConfig: Identifiable {}
extension KeltnerChannelsConfig: Identifiable {}
extension ParabolicSARConfig: Identifiable {}
extension CCIConfig: Identifiable {}
extension WilliamsRConfig: Identifiable {}
extension ATRConfig: Identifiable {}
extension VolumeConfig: Identifiable {}
