//
//  ChartDTOs.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/12/2025.
//
//  Chart-related DTOs following the same patterns as MessagingDTOs and GeneralDTOs.
//  All DTOs contain embedded data - no lookups required!
//

import Foundation
import SwiftUI


// ================================================================================================
// MARK: - TRADING SYMBOL DTOs
// ================================================================================================


// MARK: - Asset Class
/// Type of financial instrument
enum AssetClass: String, Codable, CaseIterable {
    case forex = "Forex"
    case crypto = "Crypto"
    case stocks = "Stocks"
    case commodities = "Commodities"
    case indices = "Indices"
    case futures = "Futures"
    
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
    
    var displayName: String { rawValue }
}


// MARK: - Trading Symbol DTO
/// Complete trading symbol information for chart display
/// Pre-formatted by backend with current prices and metadata
/// Used in: chart views, watchlists, symbol search
struct TradingSymbolDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Symbol unique ID
    let ticker: String                  // Trading symbol (e.g., "EURUSD", "BTC/USD")
    let displayName: String             // Full display name (e.g., "Euro / US Dollar")
    let assetClass: AssetClass          // Type of instrument
    let exchange: String?               // Exchange name if applicable
    let tickSize: Double                // Minimum price movement
    let lotSize: Double                 // Standard lot size
    let isActive: Bool                  // Is market currently open
    
    // Price info (pre-formatted by backend)
    let currentPrice: Double            // Latest price
    let priceFormatted: String          // Pre-formatted price (e.g., "1.0842")
    let change24h: Double               // 24h change amount
    let changePercent24h: Double        // 24h change percentage
    let changeFormatted: String         // Pre-formatted change (e.g., "+0.45%")
    let isUp: Bool                      // True if price increased
    
    // Market info
    let high24h: Double?                // 24h high
    let low24h: Double?                 // 24h low
    let volume24h: Double?              // 24h volume
    let volumeFormatted: String?        // Pre-formatted volume (e.g., "1.2B")
    
    /// Color for price change indicator
    var changeColor: Color {
        isUp ? .green : .red
    }
    
    /// Arrow indicator for change direction
    var changeArrow: String {
        isUp ? "↑" : "↓"
    }
    
    /// Format a price according to this symbol's specifications
    func formatPrice(_ price: Double) -> String {
        switch assetClass {
        case .forex:
            return String(format: "%.5f", price)
        case .crypto:
            return price >= 1 ? String(format: "$%.2f", price) : String(format: "$%.6f", price)
        case .stocks, .commodities:
            return String(format: "$%.2f", price)
        case .indices, .futures:
            return String(format: "%.2f", price)
        }
    }
    
    /// Decimal places for this symbol type
    var decimalPlaces: Int {
        switch assetClass {
        case .forex: return 5
        case .crypto: return currentPrice >= 1 ? 2 : 6
        case .stocks, .commodities: return 2
        case .indices, .futures: return 2
        }
    }
}


// ================================================================================================
// MARK: - CHART TIMEFRAME
// ================================================================================================

// MARK: - Chart Timeframe
/// Available chart timeframes
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
    
    static var groupedTimeframes: [TimeframeGroup: [ChartTimeframe]] {
        [
            .minutes: [.m1, .m5, .m15, .m30],
            .hours: [.h1, .h4],
            .daily: [.d1, .w1, .mn]
        ]
    }
}

enum TimeframeGroup: String, CaseIterable {
    case minutes = "Minutes"
    case hours = "Hours"
    case daily = "Daily & Weekly"
}


// ================================================================================================
// MARK: - MARKER TYPE ENUMS
// ================================================================================================

// MARK: - Marker Type
/// All available marker types with icons, colors, and behavior
enum MarkerType: String, Codable, CaseIterable {
    // Core Markers
    case note = "Note"
    case question = "Question"
    case alert = "Alert"
    case entry = "Entry"
    case exit = "Exit"
    
    // Trading Markers
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
    
    /// SF Symbol icon for this marker
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
    
    /// Color associated with this marker
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
        case .predictionTarget: return .orange
        case .emoji: return .white
        case .poll: return .blue
        case .personal: return .cyan
        }
    }
    
    /// Whether this marker displays a horizontal line
    var hasHorizontalLine: Bool {
        switch self {
        case .entry, .exit, .stopLoss, .takeProfit, .support, .resistance, .predictionTarget:
            return true
        default:
            return false
        }
    }
    
    /// Price source for horizontal line
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
    
    /// Category for UI grouping
    var category: MarkerCategory {
        switch self {
        case .note, .question, .alert, .entry, .exit, .stopLoss, .takeProfit:
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


// MARK: - Marker Alert Severity
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

// MARK: - Trendline Direction
enum TrendlineDirection: String, Codable, CaseIterable {
    case up = "Uptrend"
    case down = "Downtrend"
    case sideways = "Sideways"
}

// MARK: - Chart Pattern
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


// ================================================================================================
// MARK: - POLL OPTION DTO
// ================================================================================================

// MARK: - Poll Option DTO
/// Individual option in a marker poll
struct PollOptionDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Option unique ID
    let text: String                    // Option text
    var voteCount: Int                  // Total votes for this option
    let hasVoted: Bool                  // Has current user voted for this? (personalized)
    
    /// Vote percentage (requires total votes from parent)
    func votePercentage(totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return Double(voteCount) / Double(totalVotes) * 100
    }
}


// ================================================================================================
// MARK: - CHART MARKER DTO
// ================================================================================================

// MARK: - Chart Marker DTO
/// Complete chart marker information following DTO pattern
/// Contains EMBEDDED author info - no lookups required!
/// Used in: chart overlay, marker detail view, marker lists
struct ChartMarkerDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Marker unique ID
    let symbolId: UUID                  // Symbol this marker is on
    let guildId: UUID                   // Guild context
    let author: GuildMembershipDTO      // EMBEDDED author info (no lookup!)
    
    // Position data
    var candleIndex: Int                // Index in candle array
    var timestamp: Date                 // Candle timestamp for stable positioning
    var price: Double                   // Price level on chart
    
    // Marker properties
    let type: MarkerType                // Type of marker
    var note: String?                   // User's note/comment
    let createdAt: Date                 // When marker was created
    let createdAtFormatted: String      // Pre-formatted time (e.g., "2 hours ago")
    var isVisible: Bool                 // Is marker currently visible
    
    // Engagement data
    var likeCount: Int                  // Number of likes
    var isLikedByCurrentUser: Bool      // Has current user liked? (personalized)
    var commentCount: Int               // Number of comments
    var comments: [MarkerCommentDTO]    // EMBEDDED comments (may be paginated)
    
    // Permissions (personalized)
    let isCurrentUserMarker: Bool       // Did current user create this?
    let canEdit: Bool                   // Can current user edit?
    let canDelete: Bool                 // Can current user delete?
    
    // Stable positioning properties
    var positionedBelow: Bool           // Position below candle (true) or above (false)
    var proximityTier: Int              // Tier for stacking (0 = closest)
    var stackIndex: Int                 // Index within same-candle markers
    
    // Type-specific properties
    var horizontalLinePrice: Double?    // Line price for Entry/Exit/Support/Resistance
    var targetPrice: Double?            // Target for Prediction markers
    var alertSeverity: MarkerAlertSeverity?  // For Alert markers
    var trendlineDirection: TrendlineDirection?  // For Trendline markers
    var selectedIndicator: String?      // For Indicator markers
    var chartPattern: ChartPattern?     // For Pattern markers
    var selectedEmoji: String?          // For Emoji markers
    var pollQuestion: String?           // For Poll markers
    var pollOptions: [PollOptionDTO]?   // For Poll markers
    var userPollVote: UUID?             // Current user's vote (personalized)
    
    // MARK: - Computed Properties
    
    /// Author's display name
    var authorDisplayName: String {
        author.globalMember.username
    }
    
    /// Author's initials for avatar
    var authorInitials: String {
        String(author.globalMember.username.prefix(2)).uppercased()
    }
    
    /// Total votes in poll
    var totalPollVotes: Int {
        pollOptions?.reduce(0) { $0 + $1.voteCount } ?? 0
    }
    
    /// Has user voted in poll
    var hasVotedInPoll: Bool {
        userPollVote != nil
    }
    
    /// Get line price based on marker type and candle
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
    
    // MARK: - Equatable (by ID only for performance)
    
    static func == (lhs: ChartMarkerDTO, rhs: ChartMarkerDTO) -> Bool {
        lhs.id == rhs.id
    }
}


// ================================================================================================
// MARK: - MARKER SUMMARY DTO
// ================================================================================================

// MARK: - Marker Summary DTO
/// Lightweight marker representation for lists and previews
/// Use when you don't need full marker details
struct MarkerSummaryDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Marker unique ID
    let type: MarkerType                // Marker type
    let authorUsername: String          // Author's username
    let authorAvatarURL: String?        // Author's avatar
    let notePreview: String?            // First ~50 chars of note
    let createdAtFormatted: String      // Pre-formatted time
    let likeCount: Int                  // Like count
    let commentCount: Int               // Comment count
    let isCurrentUserMarker: Bool       // Is current user's marker
    
    /// Truncated note for preview
    var displayNote: String {
        guard let note = notePreview else { return type.rawValue }
        return note.count > 50 ? String(note.prefix(47)) + "..." : note
    }
}


// ================================================================================================
// MARK: - CANDLE DTO
// ================================================================================================

// MARK: - Candle DTO
/// Single candlestick data for chart display
/// Contains OHLC data plus optional volume
struct CandleDTO: Identifiable, Codable, Equatable {
    let id: UUID                        // Unique ID for SwiftUI
    let timestamp: Date                 // Candle period start time
    let timestampFormatted: String      // Pre-formatted for display
    let open: Double                    // Opening price
    let high: Double                    // Highest price
    let low: Double                     // Lowest price
    let close: Double                   // Closing price
    let volume: Double?                 // Trading volume (optional)
    let volumeFormatted: String?        // Pre-formatted volume
    
    /// Is this a bullish (green) candle
    var isBullish: Bool {
        close >= open
    }
    
    /// Body height (difference between open and close)
    var bodyHeight: Double {
        abs(close - open)
    }
    
    /// Total range from high to low
    var range: Double {
        high - low
    }
    
    /// Upper wick size
    var upperWick: Double {
        high - max(open, close)
    }
    
    /// Lower wick size
    var lowerWick: Double {
        min(open, close) - low
    }
}


// ================================================================================================
// MARK: - CHART DATA RESPONSE DTOs
// ================================================================================================

// MARK: - Chart Data Response
/// Response containing candles and markers for a symbol
/// Used when loading chart data from API
struct ChartDataResponseDTO: Codable {
    let symbol: TradingSymbolDTO        // Symbol info
    let timeframe: ChartTimeframe       // Requested timeframe
    let candles: [CandleDTO]            // Candle data
    let markers: [ChartMarkerDTO]       // Markers on this chart
    let hasMoreCandles: Bool            // Can load more historical data
    let lastUpdated: Date               // When data was last updated
    let lastUpdatedFormatted: String    // Pre-formatted update time
}

// MARK: - Markers List Response
/// Paginated response for marker lists
struct MarkersListResponseDTO: Codable {
    let markers: [ChartMarkerDTO]       // Marker data
    let totalCount: Int                 // Total markers available
    let page: Int                       // Current page
    let pageSize: Int                   // Items per page
    let hasMore: Bool                   // More pages available
    
    var nextPage: Int? {
        hasMore ? page + 1 : nil
    }
}


// ================================================================================================
// MARK: - MARKER OPERATION RESPONSES
// ================================================================================================

// MARK: - Create Marker Response
struct CreateMarkerResponseDTO: Codable {
    let marker: ChartMarkerDTO          // Created marker with full data
    let success: Bool
    let error: String?
}

// MARK: - Update Marker Response
struct UpdateMarkerResponseDTO: Codable {
    let marker: ChartMarkerDTO          // Updated marker
    let success: Bool
    let error: String?
}

// MARK: - Like Marker Response
struct LikeMarkerResponseDTO: Codable {
    let markerId: UUID
    let likeCount: Int                  // New like count
    let isLiked: Bool                   // New like status
    let success: Bool
}

// MARK: - Vote Poll Response
struct VotePollResponseDTO: Codable {
    let markerId: UUID
    let optionId: UUID                  // Voted option
    let updatedOptions: [PollOptionDTO] // Updated vote counts
    let success: Bool
}










extension TradingSymbolDTO {
    /// Create from legacy TradingSymbol (for migration)
    static func fromLegacy(_ symbol: TradingSymbol, currentPrice: Double = 0) -> TradingSymbolDTO {
        TradingSymbolDTO(
            id: symbol.id,
            ticker: symbol.symbol,
            displayName: symbol.displayName,
            assetClass: AssetClass(rawValue: symbol.assetClass.rawValue) ?? .forex,
            exchange: symbol.exchange,
            tickSize: symbol.tickSize,
            lotSize: symbol.lotSize,
            isActive: symbol.isActive,
            currentPrice: currentPrice,
            priceFormatted: symbol.formatPrice(currentPrice),
            change24h: 0,
            changePercent24h: 0,
            changeFormatted: "0.00%",
            isUp: true,
            high24h: nil,
            low24h: nil,
            volume24h: nil,
            volumeFormatted: nil
        )
    }
}
