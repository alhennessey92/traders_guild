//
//  ChartModels.swift
//  traders_guild
//
//  UPDATED VERSION - Comprehensive marker types with custom functionality
//  Each marker type has specific icon, color, and behavior
//
//  FIX: Renamed AlertSeverity to MarkerAlertSeverity to avoid conflict with DTOs.swift
//  FIX: Added stopLoss and takeProfit cases to MarkerType for SampleData compatibility
//

import Foundation
import SwiftUI

// MARK: - Trading Symbol DTO

/// Trading symbol model for chart data
struct TradingSymbol: Identifiable, Codable, Hashable {
    let id: UUID
    let symbol: String
    let displayName: String
    let assetClass: AssetClass
    let exchange: String?
    let tickSize: Double
    let lotSize: Double
    let isActive: Bool
    
    enum AssetClass: String, Codable, CaseIterable {
        case forex
        case crypto
        case stocks
        case commodities
        case indices
        case futures
        
        var icon: String {
            switch self {
            case .forex: return "chart.bar.fill"
            case .crypto: return "bitcoinsign.circle.fill"
            case .stocks: return "chart.line.uptrend.xyaxis"
            case .commodities: return "cube.fill"
            case .indices: return "chart.bar.doc.horizontal.fill"
            case .futures: return "calendar.circle.fill"
            }
        }
    }
    
    func formatPrice(_ price: Double) -> String {
        switch assetClass {
        case .forex:
            return String(format: "%.5f", price)
        case .crypto:
            return String(format: "$%.2f", price)
        case .stocks:
            return String(format: "$%.2f", price)
        case .commodities:
            return String(format: "$%.2f", price)
        case .indices:
            return String(format: "%.2f", price)
        case .futures:
            return String(format: "%.2f", price)
        }
    }
}

// MARK: - Chart Timeframe

enum ChartTimeframe: String, Codable, CaseIterable {
    case m1 = "1m"
    case m5 = "5m"
    case m15 = "15m"
    case m30 = "30m"
    case h1 = "1h"
    case h4 = "4h"
    case d1 = "1d"
    case w1 = "1w"
    case mn = "1M"
    
    var displayName: String {
        switch self {
        case .m1: return "1 Minute"
        case .m5: return "5 Minutes"
        case .m15: return "15 Minutes"
        case .m30: return "30 Minutes"
        case .h1: return "1 Hour"
        case .h4: return "4 Hours"
        case .d1: return "1 Day"
        case .w1: return "1 Week"
        case .mn: return "1 Month"
        }
    }
    
    var shortName: String {
        switch self {
        case .m1: return "1m"
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .h1: return "1H"
        case .h4: return "4H"
        case .d1: return "1D"
        case .w1: return "1W"
        case .mn: return "1M"
        }
    }
    
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
    
    var initialCandlesCount: Int {
        switch self {
        case .m1: return 500
        case .m5: return 400
        case .m15: return 300
        case .m30: return 250
        case .h1: return 200
        case .h4: return 150
        case .d1: return 100
        case .w1: return 52
        case .mn: return 24
        }
    }
    
    var gridLineCount: Int {
        switch self {
        case .m1, .m5: return 6
        case .m15, .m30: return 5
        case .h1, .h4: return 4
        case .d1, .w1, .mn: return 3
        }
    }
    
    var group: TimeframeGroup {
        switch self {
        case .m1, .m5, .m15, .m30: return .minutes
        case .h1, .h4: return .hours
        case .d1, .w1, .mn: return .daily
        }
    }
    
    
    /// MARK - AL
    var xAxisFormat: String {
        switch self {
        case .m1, .m5, .m15, .m30, .h1:
            return "HH:mm"
        case .h4:
            return "MMM d HH:mm"
        case .d1, .w1:
            return "MMM d"
        case .mn:
            return "MMM yyyy"
        }
    }
}

enum TimeframeGroup: String, CaseIterable {
    case minutes = "Minutes"
    case hours = "Hours"
    case daily = "Daily & Weekly"
}

extension ChartTimeframe {
    static var groupedTimeframes: [TimeframeGroup: [ChartTimeframe]] {
        [
            .minutes: [.m1, .m5, .m15, .m30],
            .hours: [.h1, .h4],
            .daily: [.d1, .w1, .mn]
        ]
    }
}

// MARK: - Marker Types

/// All available marker types matching the MainView buttons
/// Each type has a specific icon, color, and optional custom behavior
enum MarkerType: String, Codable, CaseIterable {
    // Core Markers
    case note = "Note"
    case question = "Question"
    case alert = "Alert"
    case entry = "Entry"
    case exit = "Exit"
    
    // Trading Markers (added for SampleData compatibility)
    case stopLoss = "Stop Loss"
    case takeProfit = "Take Profit"
    
    // Analysis Markers
    case support = "Support"
    case resistance = "Resistance"
    case indicator = "Indicator"
    case trendline = "Trendline"
    case pattern = "Pattern"
    case volumeSpike = "Volume Spike"
    
    // Prediction Markers
    case predictionTarget = "Prediction"
    
    // Social Markers
    case emoji = "Emoji"
    case poll = "Poll"
    case personal = "Personal"
    
    /// The SF Symbol icon for this marker type
    var icon: String {
        switch self {
        case .note: return "pencil.circle"
        case .question: return "questionmark.circle"
        case .alert: return "bell.circle"
        case .entry: return "arrow.up.circle"
        case .exit: return "arrow.down.circle"
        case .stopLoss: return "xmark.shield"
        case .takeProfit: return "checkmark.shield"
        case .support: return "s.circle"
        case .resistance: return "r.circle"
        case .indicator: return "star.circle"
        case .trendline: return "chart.line.uptrend.xyaxis.circle"
        case .pattern: return "circle.hexagongrid.circle"
        case .volumeSpike: return "chart.line.downtrend.xyaxis.circle"
        case .predictionTarget: return "staroflife.circle"
        case .emoji: return "face.smiling.inverse"
        case .poll: return "newspaper.circle"
        case .personal: return "person.circle"
        }
    }
    
    /// The color associated with this marker type
    var color: Color {
        switch self {
        case .note: return .gray
        case .question: return .blue
        case .alert: return .yellow
        case .entry: return .green
        case .exit: return .orange
        case .stopLoss: return .red
        case .takeProfit: return .blue
        case .support: return .purple
        case .resistance: return .pink
        case .indicator: return .teal
        case .trendline: return .indigo
        case .pattern: return .cyan
        case .volumeSpike: return .mint
        case .predictionTarget: return .orange  // Changed from Color("tgAccentDark") - more visible
        case .emoji: return .white
        case .poll: return .blue
        case .personal: return .cyan  // Changed from Color("tgMidGrey") - more visible
        }
    }
    
    /// Whether this marker type displays a horizontal line on the chart
    var hasHorizontalLine: Bool {
        switch self {
        case .entry, .exit, .stopLoss, .takeProfit, .support, .resistance, .predictionTarget:
            return true
        default:
            return false
        }
    }
    
    /// The price source for the horizontal line (if applicable)
    var lineSource: LinePriceSource {
        switch self {
        case .entry: return .candleOpen
        case .exit: return .candleClose
        case .stopLoss: return .candleOpen
        case .takeProfit: return .candleClose
        case .support: return .candleLow
        case .resistance: return .candleHigh
        case .predictionTarget: return .custom
        default: return .none
        }
    }
    
    /// The marker category for grouping in UI
    var category: MarkerCategory {
        switch self {
        case .note, .question, .alert, .entry, .exit:
            return .core
        case .stopLoss, .takeProfit:
            return .core
        case .support, .resistance, .indicator, .trendline, .pattern, .volumeSpike:
            return .analysis
        case .predictionTarget:
            return .prediction
        case .emoji, .poll, .personal:
            return .social
        }
    }
}

/// Source for horizontal line price
enum LinePriceSource: String, Codable {
    case none
    case candleOpen
    case candleClose
    case candleHigh
    case candleLow
    case custom
}

/// Category for grouping marker types
enum MarkerCategory: String, CaseIterable {
    case core = "Core Markers"
    case analysis = "Analysis Markers"
    case prediction = "Prediction Markers"
    case social = "Social Markers"
}

// MARK: - Marker Alert Severity (for Alert markers)
// RENAMED from AlertSeverity to avoid conflict with DTOs.swift AlertSeverity

enum MarkerAlertSeverity: String, Codable, CaseIterable {
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .mild: return .green
        case .moderate: return .yellow
        case .severe: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Trendline Direction (for Trendline markers)

enum TrendlineDirection: String, Codable, CaseIterable {
    case up = "Uptrend"
    case down = "Downtrend"
    case sideways = "Sideways"
}

// MARK: - Chart Pattern (for Pattern markers)

enum ChartPattern: String, Codable, CaseIterable {
    case headAndShoulders = "Head & Shoulders"
    case inverseHeadAndShoulders = "Inverse H&S"
    case doubleTop = "Double Top"
    case doubleBottom = "Double Bottom"
    case tripleTop = "Triple Top"
    case tripleBottom = "Triple Bottom"
    case ascendingTriangle = "Ascending Triangle"
    case descendingTriangle = "Descending Triangle"
    case symmetricalTriangle = "Symmetrical Triangle"
    case wedge = "Wedge"
    case flag = "Flag"
    case pennant = "Pennant"
    case cup = "Cup & Handle"
    case rectangle = "Rectangle"
    case other = "Other"
}

// MARK: - Poll Option (for Poll markers)

struct PollOption: Codable, Hashable, Identifiable {
    let id: UUID
    let text: String
    var voteCount: Int
    
    init(id: UUID = UUID(), text: String, voteCount: Int = 0) {
        self.id = id
        self.text = text
        self.voteCount = voteCount
    }
}

// MARK: - Marker Comment

struct MarkerComment: Codable, Hashable, Identifiable {
    let id: UUID
    let userId: String
    let username: String
    let text: String
    let createdAt: Date
    
    init(id: UUID = UUID(), userId: String, username: String, text: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.username = username
        self.text = text
        self.createdAt = createdAt
    }
}

// MARK: - Chart Marker Model

/// Chart marker with stable positioning and custom functionality per type
struct ChartMarker: Identifiable, Codable, Hashable {
    let id: UUID
    var candleIndex: Int
    let timestamp: Date
    var price: Double
    let type: MarkerType
    let userId: String
    let username: String
    var note: String?
    let createdAt: Date
    let guildId: String
    var isVisible: Bool
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    
    // MARK: - Stable Positioning Properties
    
    /// Whether this marker is positioned below the candle (true) or above (false)
    var positionedBelow: Bool
    
    /// The proximity tier for this marker (0 = closest to candle)
    var proximityTier: Int
    
    /// Stack index within markers on the same candle
    var stackIndex: Int
    
    // MARK: - Type-Specific Properties
    
    /// Horizontal line price for Entry/Exit/Support/Resistance markers
    var horizontalLinePrice: Double?
    
    /// Target price for Prediction markers (stop loss/take profit line)
    var targetPrice: Double?
    
    /// Alert severity for Alert markers (using renamed type)
    var alertSeverity: MarkerAlertSeverity?
    
    /// Trendline direction for Trendline markers
    var trendlineDirection: TrendlineDirection?
    
    /// Selected indicator name for Indicator markers
    var selectedIndicator: String?
    
    /// Chart pattern for Pattern markers
    var chartPattern: ChartPattern?
    
    /// Selected emoji for Emoji markers
    var selectedEmoji: String?
    
    /// Poll question for Poll markers
    var pollQuestion: String?
    
    /// Poll options for Poll markers
    var pollOptions: [PollOption]?
    
    /// User's poll vote (option ID)
    var userPollVote: UUID?
    
    /// Comments on this marker
    var comments: [MarkerComment]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        userId: String,
        username: String,
        note: String? = nil,
        guildId: String,
        createdAt: Date = Date(),
        isVisible: Bool = true,
        likeCount: Int = 0,
        isLikedByCurrentUser: Bool = false,
        positionedBelow: Bool = false,
        proximityTier: Int = 0,
        stackIndex: Int = 0,
        horizontalLinePrice: Double? = nil,
        targetPrice: Double? = nil,
        alertSeverity: MarkerAlertSeverity? = nil,
        trendlineDirection: TrendlineDirection? = nil,
        selectedIndicator: String? = nil,
        chartPattern: ChartPattern? = nil,
        selectedEmoji: String? = nil,
        pollQuestion: String? = nil,
        pollOptions: [PollOption]? = nil,
        userPollVote: UUID? = nil,
        comments: [MarkerComment] = []
    ) {
        self.id = id
        self.candleIndex = candleIndex
        self.timestamp = timestamp
        self.price = price
        self.type = type
        self.userId = userId
        self.username = username
        self.note = note
        self.guildId = guildId
        self.createdAt = createdAt
        self.isVisible = isVisible
        self.likeCount = likeCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.positionedBelow = positionedBelow
        self.proximityTier = proximityTier
        self.stackIndex = stackIndex
        self.horizontalLinePrice = horizontalLinePrice
        self.targetPrice = targetPrice
        self.alertSeverity = alertSeverity
        self.trendlineDirection = trendlineDirection
        self.selectedIndicator = selectedIndicator
        self.chartPattern = chartPattern
        self.selectedEmoji = selectedEmoji
        self.pollQuestion = pollQuestion
        self.pollOptions = pollOptions
        self.userPollVote = userPollVote
        self.comments = comments
    }
    
    // MARK: - Computed Properties
    
    /// Get the price for the horizontal line based on marker type
    func getLinePrice(candle: Candle?) -> Double? {
        guard type.hasHorizontalLine else { return nil }
        
        switch type.lineSource {
        case .candleOpen:
            return candle?.open ?? horizontalLinePrice
        case .candleClose:
            return candle?.close ?? horizontalLinePrice
        case .candleHigh:
            return candle?.high ?? horizontalLinePrice
        case .candleLow:
            return candle?.low ?? horizontalLinePrice
        case .custom:
            return targetPrice ?? horizontalLinePrice
        case .none:
            return nil
        }
    }
    
    // MARK: - Hashable & Equatable
    
    static func == (lhs: ChartMarker, rhs: ChartMarker) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

