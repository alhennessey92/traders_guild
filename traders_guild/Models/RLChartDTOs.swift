//
//  ChartDTOs.swift
//  TradersGuild
//
//  Chart & Market Data DTOs - Maps to backend shared/schemas/chart_schema.py
//
//  NOTE: Uses existing RLGuildMemberDTO from CoreDTOs.swift as embedded author type.
//  All response DTOs use .convertFromSnakeCase decoder strategy.
//
//  Backend Field           → Swift Property (via .convertFromSnakeCase)
//  ---------------         ----------------
//  symbol_id              → symbolId
//  candle_timestamp       → candleTimestamp
//  is_liked_by_current_user → isLikedByCurrentUser
//  timestamp_formatted    → timestampFormatted
//

import Foundation
import SwiftUI

// =============================================================================
// MARK: - Asset Class (UI Helper)
// =============================================================================

enum RLAssetClass: String, Codable, CaseIterable {
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
    
    static func fromBackendString(_ string: String) -> RLAssetClass? {
        switch string.lowercased() {
        case "forex": return .forex
        case "crypto", "cryptocurrency": return .crypto
        case "stocks", "stock": return .stocks
        case "commodities", "commodity": return .commodities
        case "indices", "index": return .indices
        case "futures", "future": return .futures
        default: return nil
        }
    }
}

// =============================================================================
// MARK: - Marker Type (UI Helper)
// =============================================================================

enum RLMarkerType: String, Codable, CaseIterable {
    case note = "Note"
    case question = "Question"
    case alert = "Alert"
    case entry = "Entry"
    case exit = "Exit"
    case stopLoss = "Stop Loss"
    case takeProfit = "Take Profit"
    case support = "Support"
    case resistance = "Resistance"
    case indicator = "Indicator"
    case trendline = "Trendline"
    case pattern = "Pattern"
    case volumeSpike = "Volume Spike"
    case predictionTarget = "Prediction"
    case emoji = "Emoji"
    case poll = "Poll"
    case personal = "Personal"
    
    /// SF Symbol name only (no .circle) — chart draws its own circle; add custom symbols here for new marker types
    var icon: String {
        switch self {   
        case .note: return "pencil"
        case .question: return "questionmark"
        case .alert: return "exclamationmark.triangle"
        case .entry: return "arrow.right.circle.dotted"
        case .exit: return "arrow.left.circle.dotted"
        case .stopLoss: return "xmark"
        case .takeProfit: return "checkmark"
        case .support: return "arrow.down.to.line"
        case .resistance: return "arrow.up.to.line"
        case .indicator: return "star"
        case .trendline: return "chart.line.uptrend.xyaxis"
        case .pattern: return "circle.hexagongrid.fill"
        case .volumeSpike: return "chart.line.downtrend.xyaxis"
        case .predictionTarget: return "target"
        case .emoji: return "face.smiling.inverse"
        case .poll: return "newspaper.fill"
        case .personal: return "person.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .note: return .gray
        case .question: return .blue
        case .alert: return .yellow
        case .entry: return .green
        case .exit: return AppColors.bearCandleRed
        case .stopLoss: return .red
        case .takeProfit: return .blue
        case .support: return .purple
        case .resistance: return .pink
        case .indicator: return .teal
        case .trendline: return .indigo
        case .pattern: return .cyan
        case .volumeSpike: return .mint
        case .predictionTarget: return .white
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
    
    /// Short label for display on chart lines
    var lineLabel: String {
        switch self {
        case .entry: return "Entry"
        case .exit: return "Exit"
        case .stopLoss: return "SL"
        case .takeProfit: return "TP"
        case .support: return "Support"
        case .resistance: return "Resist"
        case .predictionTarget: return "Entry"
        default: return ""
        }
    }

    /// Price source for horizontal line (UI)
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
    
    static func fromBackendString(_ string: String) -> RLMarkerType? {
        switch string.lowercased() {
        case "entry": return .entry
        case "exit": return .exit
        case "stop_loss": return .stopLoss
        case "take_profit": return .takeProfit
        case "prediction": return .predictionTarget
        case "analysis": return .note
        case "alert": return .alert
        case "support": return .support
        case "resistance": return .resistance
        case "trendline": return .trendline
        case "pattern": return .pattern
        case "indicator": return .indicator
        case "emoji": return .emoji
        case "poll": return .poll
        case "note": return .note
        case "question": return .question
        case "volume_spike": return .volumeSpike
        case "personal": return .personal
        default: return nil
        }
    }
}

// =============================================================================
// MARK: - Chart Timeframe (UI Helper)
// =============================================================================

enum RLChartTimeframe: String, Codable, CaseIterable {
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

// =============================================================================
// MARK: - Trading Symbol
// =============================================================================

/// Full trading symbol with live price snapshot
/// Backend: TradingSymbolResponse
struct RLTradingSymbolDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let ticker: String
    let displayName: String
    let assetClass: String                      // forex, crypto, stocks
    let exchange: String?
    let tickSize: Double
    let lotSize: Double
    let decimalPlaces: Int
    let isActive: Bool
    
    // Visual identity
    let iconName: String?
    let iconUrl: String?
    let primaryColor: String
    let secondaryColor: String
    
    // Live price data (from SymbolSnapshot)
    let currentPrice: Double?
    let priceFormatted: String?
    let change24h: Double?
    let changePercent24h: Double?
    let changeFormatted: String?
    let isUp: Bool?
    
    let high24h: Double?
    let low24h: Double?
    let volume24h: Double?
    let volumeFormatted: String?

    // Optional membership flags (present on /chart/symbols/global responses)
    let inPersonalWatchlist: Bool?
    let inGuildWatchlist: Bool?
    let isRequestedForGuild: Bool?
    let activeMarketProvider: String?
    let isSupportedByActiveProvider: Bool?
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLTradingSymbolDTO, rhs: RLTradingSymbolDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.currentPrice == rhs.currentPrice
    }
    
    // MARK: - Convenience
    
    /// Display string for price change (e.g. "+1.25 (+0.45%)")
    var changeDisplay: String {
        changeFormatted ?? "--"
    }
    
    /// Short ticker for compact display
    var shortTicker: String {
        ticker.replacingOccurrences(of: "/", with: "")
    }

    var isSelectableForActiveProvider: Bool {
        isSupportedByActiveProvider ?? true
    }

    var activeProviderDisplayName: String? {
        activeMarketProvider?
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }
}

/// Active market provider status.
/// Backend: MarketDataProviderStatusResponse
struct RLMarketDataProviderStatusDTO: Codable {
    let activeProvider: String
    let updatedAt: Date?
}


// =============================================================================
// MARK: - Candles
// =============================================================================

/// Single OHLCV candle
/// Backend: CandleResponse
struct RLCandleDTO: Codable, Equatable {
    let timestamp: Date
    let timestampFormatted: String?
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    let volumeFormatted: String?
    
    // MARK: - Convenience
    
    var isBullish: Bool { close >= open }
    var bodyHeight: Double { abs(close - open) }
    var wickHigh: Double { high }
    var wickLow: Double { low }
}

/// Paginated candle list response
/// Backend: CandleListResponse
struct RLCandleListDTO: Codable {
    let candles: [RLCandleDTO]
    let symbolId: UUID
    let timeframe: String
    let hasMore: Bool
    let earliestTimestamp: Date?
}


// =============================================================================
// MARK: - Poll Option
// =============================================================================

/// Poll option within a poll-type marker
/// Backend: PollOptionResponse
struct RLPollOptionDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let voteCount: Int
    let hasVoted: Bool
}


// =============================================================================
// MARK: - Marker Comment
// =============================================================================

/// Individual comment on a chart marker
/// Backend: MarkerCommentResponse
struct RLMarkerCommentDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let markerId: UUID
    let author: RLGuildMemberDTO
    let content: String
    let timestamp: Date
    let timestampFormatted: String
    let isEdited: Bool
    var isCurrentUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?

    /// Returns a copy with isCurrentUserMessage recomputed for the local user
    func withCurrentUser(_ isCurrent: Bool) -> RLMarkerCommentDTO {
        var copy = self
        copy.isCurrentUserMessage = isCurrent
        return copy
    }
    
    init(
        id: UUID,
        markerId: UUID,
        author: RLGuildMemberDTO,
        content: String,
        timestamp: Date,
        timestampFormatted: String,
        isEdited: Bool,
        isCurrentUserMessage: Bool,
        canEdit: Bool,
        canDelete: Bool,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil
    ) {
        self.id = id
        self.markerId = markerId
        self.author = author
        self.content = content
        self.timestamp = timestamp
        self.timestampFormatted = timestampFormatted
        self.isEdited = isEdited
        self.isCurrentUserMessage = isCurrentUserMessage
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RLMarkerCommentDTO, rhs: RLMarkerCommentDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited
    }

    // MARK: - CodingKeys
    // Backend sends "created_at" aliased to "timestamp" via validation_alias
    // With .convertFromSnakeCase, "created_at" becomes "createdAt"
    // We need to handle both cases
    enum CodingKeys: String, CodingKey {
        case id, markerId, author, content
        case timestamp
        case createdAt
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
        case attachmentUrl, attachmentType, attachmentName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        markerId = try container.decode(UUID.self, forKey: .markerId)
        author = try container.decode(RLGuildMemberDTO.self, forKey: .author)
        content = try container.decode(String.self, forKey: .content)
        timestampFormatted = try container.decode(String.self, forKey: .timestampFormatted)
        isEdited = try container.decode(Bool.self, forKey: .isEdited)
        isCurrentUserMessage = try container.decode(Bool.self, forKey: .isCurrentUserMessage)
        canEdit = try container.decode(Bool.self, forKey: .canEdit)
        canDelete = try container.decode(Bool.self, forKey: .canDelete)
        attachmentUrl = try container.decodeIfPresent(String.self, forKey: .attachmentUrl)
        attachmentType = try container.decodeIfPresent(String.self, forKey: .attachmentType)
        attachmentName = try container.decodeIfPresent(String.self, forKey: .attachmentName)

        if let timestampValue = try container.decodeIfPresent(Date.self, forKey: .timestamp) {
            timestamp = timestampValue
        } else {
            timestamp = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(markerId, forKey: .markerId)
        try container.encode(author, forKey: .author)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(timestampFormatted, forKey: .timestampFormatted)
        try container.encode(isEdited, forKey: .isEdited)
        try container.encode(isCurrentUserMessage, forKey: .isCurrentUserMessage)
        try container.encode(canEdit, forKey: .canEdit)
        try container.encode(canDelete, forKey: .canDelete)
        try container.encodeIfPresent(attachmentUrl, forKey: .attachmentUrl)
        try container.encodeIfPresent(attachmentType, forKey: .attachmentType)
        try container.encodeIfPresent(attachmentName, forKey: .attachmentName)
    }
}


// =============================================================================
// MARK: - Chart Marker
// =============================================================================

/// Full chart marker with engagement data and permissions
/// Backend: ChartMarkerResponse
struct RLChartMarkerDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let symbolId: UUID
    let guildId: UUID
    let author: RLGuildMemberDTO
    
    // Position
    let candleTimestamp: Date
    let timeframe: String
    let price: Double
    
    // Marker data
    let markerType: String                      // analysis, alert, emoji, poll, etc.
    let note: String?
    let createdAt: Date
    let createdAtFormatted: String
    let isVisible: Bool
    
    // Engagement
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    let commentCount: Int
    let comments: [RLMarkerCommentDTO]
    
    // Permissions
    let isCurrentUserMarker: Bool
    let canEdit: Bool
    let canDelete: Bool
    
    // Type-specific (exploded from JSONB metadata)
    let horizontalLinePrice: Double?
    let targetPrice: Double?
    let stopLossPrice: Double?
    let alertSeverity: String?                  // low, medium, high, critical
    let trendlineDirection: String?             // up, down, sideways
    let selectedIndicator: String?
    let chartPattern: String?
    let selectedEmoji: String?
    let pollQuestion: String?
    let pollOptions: [RLPollOptionDTO]?
    let userPollVote: UUID?
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLChartMarkerDTO, rhs: RLChartMarkerDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.likeCount == rhs.likeCount &&
        lhs.commentCount == rhs.commentCount &&
        lhs.isVisible == rhs.isVisible
    }
    
    // MARK: - Convenience
    
    /// Whether this marker has a horizontal price line
    var hasHorizontalLine: Bool {
        horizontalLinePrice != nil
    }
    
    /// Whether this is a poll marker
    var isPoll: Bool {
        markerType == "poll"
    }
}


// =============================================================================
// MARK: - Top Marker (Trending/Discovery)
// =============================================================================

/// Flattened marker for trending/discovery views
/// Backend: TopMarkerResponse
struct RLTopMarkerDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let symbolId: UUID
    let symbolTicker: String
    let symbolBrandColor: String?
    let symbolAssetClass: String
    let guildId: UUID
    
    // Author (flattened)
    let authorId: UUID
    let authorUsername: String
    let authorInitials: String
    let authorAvatarUrl: String?
    let authorIsOnline: Bool
    let authorReputation: Int
    let authorAccuracyRate: Double?
    let authorRole: String
    
    // Marker
    let markerType: String
    let notePreview: String?
    let createdAt: Date
    let createdAtFormatted: String
    
    // Chart position
    let candleTimestamp: Date
    let timeframe: String
    let price: Double
    let targetPrice: Double?
    let stopLossPrice: Double?
    
    // Engagement
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    let commentCount: Int
    
    // Ranking
    let trendingScore: Double
    
    // Permissions
    let isCurrentUserMarker: Bool
    
    // MARK: - Computed Properties
    
    var authorAccuracyFormatted: String? {
        guard let rate = authorAccuracyRate else { return nil }
        return "\(Int(rate * 100))%"
    }

    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLTopMarkerDTO, rhs: RLTopMarkerDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.likeCount == rhs.likeCount
    }
}

/// Categorized top markers list
/// Backend: TopMarkersListResponse
struct RLTopMarkersListDTO: Codable {
    let trending: [RLTopMarkerDTO]
    let bySymbol: [String: [RLTopMarkerDTO]]
    let following: [RLTopMarkerDTO]
    let mine: [RLTopMarkerDTO]
    let lastUpdated: Date
}


// =============================================================================
// MARK: - Marker Lists & Operations
// =============================================================================

/// Paginated markers list
/// Backend: MarkersListResponse
struct RLMarkersListDTO: Codable {
    let markers: [RLChartMarkerDTO]
    let totalCount: Int
    let hasMore: Bool
    let nextCursor: String?
}

/// Paginated marker comments list
/// Backend: MarkerCommentsListResponse
struct RLMarkerCommentsListDTO: Codable {
    let comments: [RLMarkerCommentDTO]
    let hasMore: Bool
    let nextCursor: String?
}

/// Like toggle response
/// Backend: LikeMarkerResponse
struct RLLikeMarkerDTO: Codable {
    let markerId: UUID
    let likeCount: Int
    let isLiked: Bool
}

/// Poll vote response
/// Backend: VotePollResponse
struct RLVotePollDTO: Codable {
    let markerId: UUID
    let optionId: UUID
    let updatedOptions: [RLPollOptionDTO]
}

/// Navigation info for jumping to a marker on the chart
/// Backend: MarkerNavigationResponse
struct RLMarkerNavigationDTO: Codable {
    let markerId: UUID
    let symbolId: UUID
    let symbolTicker: String
    let timeframe: String
    let candleTimestamp: Date
    let price: Double
}


// =============================================================================
// MARK: - Marker Real-Time Event Payloads
// =============================================================================

/// Payload for marker_deleted WebSocket event
struct MarkerDeletedPayload: Codable {
    let markerId: String
    let guildId: String
}

/// Payload for marker_liked WebSocket event
struct MarkerLikedPayload: Codable {
    let markerId: String
    let likeCount: Int
    let isLiked: Bool
}

/// Payload for marker_commented WebSocket event
struct MarkerCommentedPayload: Codable {
    let markerId: String
    let comment: RLMarkerCommentDTO
    let commentCount: Int
}


// =============================================================================
// MARK: - Watchlist
// =============================================================================

/// Single watchlist item with symbol data
/// Backend: WatchlistSymbolResponse
struct RLWatchlistSymbolDTO: Codable, Identifiable, Equatable {
    let watchlistItemId: UUID
    let symbol: RLTradingSymbolDTO
    let sortOrder: Int
    let addedAt: Date
    let addedAtFormatted: String
    
    var id: UUID { watchlistItemId }
    
    static func == (lhs: RLWatchlistSymbolDTO, rhs: RLWatchlistSymbolDTO) -> Bool {
        lhs.watchlistItemId == rhs.watchlistItemId
    }
}

/// Personal watchlist response
/// Backend: PersonalWatchlistResponse
struct RLPersonalWatchlistDTO: Codable {
    let symbols: [RLWatchlistSymbolDTO]
}

/// Guild watchlist response
/// Backend: GuildWatchlistResponse
struct RLGuildWatchlistDTO: Codable {
    let guildId: UUID
    let symbols: [RLWatchlistSymbolDTO]
}


// =============================================================================
// MARK: - Chart Chat
// =============================================================================

/// Individual chart chat message
/// Backend: ChartChatMessageResponse
struct RLChartChatMessageDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let chatId: UUID
    let author: RLGuildMemberDTO
    let content: String
    let timestamp: Date
    let timestampFormatted: String
    let isEdited: Bool
    var isCurrentUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?

    /// Returns a copy with isCurrentUserMessage recomputed for the local user
    func withCurrentUser(_ isCurrent: Bool) -> RLChartChatMessageDTO {
        var copy = self
        copy.isCurrentUserMessage = isCurrent
        return copy
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLChartChatMessageDTO, rhs: RLChartChatMessageDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited
    }
    
    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, chatId, author, content
        case timestamp
        case createdAt
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
        case attachmentUrl, attachmentType, attachmentName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        chatId = try container.decode(UUID.self, forKey: .chatId)
        author = try container.decode(RLGuildMemberDTO.self, forKey: .author)
        content = try container.decode(String.self, forKey: .content)
        timestampFormatted = try container.decode(String.self, forKey: .timestampFormatted)
        isEdited = try container.decode(Bool.self, forKey: .isEdited)
        isCurrentUserMessage = try container.decode(Bool.self, forKey: .isCurrentUserMessage)
        canEdit = try container.decode(Bool.self, forKey: .canEdit)
        canDelete = try container.decode(Bool.self, forKey: .canDelete)
        attachmentUrl = try container.decodeIfPresent(String.self, forKey: .attachmentUrl)
        attachmentType = try container.decodeIfPresent(String.self, forKey: .attachmentType)
        attachmentName = try container.decodeIfPresent(String.self, forKey: .attachmentName)

        if let timestampValue = try container.decodeIfPresent(Date.self, forKey: .timestamp) {
            timestamp = timestampValue
        } else {
            timestamp = try container.decode(Date.self, forKey: .createdAt)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(chatId, forKey: .chatId)
        try container.encode(author, forKey: .author)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(timestampFormatted, forKey: .timestampFormatted)
        try container.encode(isEdited, forKey: .isEdited)
        try container.encode(isCurrentUserMessage, forKey: .isCurrentUserMessage)
        try container.encode(canEdit, forKey: .canEdit)
        try container.encode(canDelete, forKey: .canDelete)
        try container.encodeIfPresent(attachmentUrl, forKey: .attachmentUrl)
        try container.encodeIfPresent(attachmentType, forKey: .attachmentType)
        try container.encodeIfPresent(attachmentName, forKey: .attachmentName)
    }
    
    // MARK: - Convenience
    
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 60
    }
}

/// Chart chat (per symbol + guild)
/// Backend: ChartChatResponse
struct RLChartChatDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let guildId: UUID
    let symbolId: UUID
    let symbolTicker: String
    let guildName: String
    let lastMessage: RLChartChatMessageDTO?
    let lastActivity: Date
    let lastActivityFormatted: String
    let unreadCount: Int
    let activeUserCount: Int
    let isMuted: Bool
    let isPinned: Bool
    let canSendMessages: Bool
    
    static func == (lhs: RLChartChatDTO, rhs: RLChartChatDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.unreadCount == rhs.unreadCount
    }
    
    var hasUnread: Bool {
        unreadCount > 0
    }
}

/// Paginated chart chat messages list
/// Backend: ChartChatMessagesListResponse
struct RLChartChatMessagesListDTO: Codable {
    let messages: [RLChartChatMessageDTO]
    let hasMore: Bool
    let nextCursor: String?
}


// =============================================================================
// MARK: - Symbol Search
// =============================================================================

/// Symbol search results
/// Backend: SymbolSearchResponse
struct RLSymbolSearchDTO: Codable {
    let results: [RLTradingSymbolDTO]
    let totalCount: Int
    let query: String
}

/// Global symbols listing with watchlist membership flags
/// Backend: GlobalSymbolsListResponse
struct RLGlobalSymbolsListDTO: Codable {
    let symbols: [RLTradingSymbolDTO]
    let totalCount: Int
    let nextCursor: String?
}


// =============================================================================
// MARK: - Combined Chart Data (Initial Load)
// =============================================================================

/// Combined chart data response (symbol + candles + markers)
/// Backend: ChartDataResponse
struct RLChartDataDTO: Codable {
    let symbol: RLTradingSymbolDTO
    let timeframe: String
    let candles: [RLCandleDTO]
    let markers: [RLChartMarkerDTO]
    let hasMoreCandles: Bool
    let lastUpdated: Date
    let lastUpdatedFormatted: String
}


// =============================================================================
// MARK: - Request DTOs
// =============================================================================

/// Add symbol to watchlist
/// Backend: WatchlistAddRequest
struct RLWatchlistAddRequest: Codable {
    let symbolId: UUID
    
    enum CodingKeys: String, CodingKey {
        case symbolId = "symbol_id"
    }
}

/// Request to add a symbol to guild watchlist (member request)
/// Backend: GuildWatchlistAddRequestRequest
struct RLGuildWatchlistAddRequestDTO: Codable {
    let symbolId: UUID
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case symbolId = "symbol_id"
        case reason
    }
}

/// Guild watchlist addition request response
/// Backend: GuildWatchlistRequestResponse
struct RLGuildWatchlistRequestResponseDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID
    let symbolId: UUID
    let symbolTicker: String
    let symbolDisplayName: String
    let requester: RLGuildMemberDTO
    let reason: String?
    let status: String
    let createdAt: Date
    let createdAtFormatted: String
    let reviewedById: UUID?
    let reviewedByUsername: String?
    let reviewedAt: Date?
    let reviewNote: String?
}

/// List of guild watchlist requests
/// Backend: GuildWatchlistRequestsListResponse
struct RLGuildWatchlistRequestsListResponseDTO: Codable {
    let requests: [RLGuildWatchlistRequestResponseDTO]
    let totalCount: Int
}

/// Request body for reviewing a guild watchlist request
/// Backend: GuildWatchlistReviewRequest
struct RLGuildWatchlistReviewRequestDTO: Codable {
    let action: String  // approved | rejected
    let reviewNote: String?

    enum CodingKeys: String, CodingKey {
        case action
        case reviewNote = "review_note"
    }
}

/// Reorder watchlist
/// Backend: WatchlistReorderRequest
struct RLWatchlistReorderRequest: Codable {
    let symbolIds: [UUID]
    
    enum CodingKeys: String, CodingKey {
        case symbolIds = "symbol_ids"
    }
}

/// Create a chart marker
/// Backend: CreateMarkerRequest
struct RLCreateMarkerRequest: Codable {
    let symbolId: UUID
    let guildId: UUID
    let candleTimestamp: Date
    let timeframe: String
    let price: Double
    let markerType: String
    let note: String?
    
    // Type-specific
    let horizontalLinePrice: Double?
    let targetPrice: Double?
    let stopLossPrice: Double?
    let alertSeverity: String?
    let trendlineDirection: String?
    let selectedIndicator: String?
    let chartPattern: String?
    let selectedEmoji: String?
    let pollQuestion: String?
    let pollOptions: [String]?

    enum CodingKeys: String, CodingKey {
        case symbolId = "symbol_id"
        case guildId = "guild_id"
        case candleTimestamp = "candle_timestamp"
        case timeframe, price
        case markerType = "marker_type"
        case note
        case horizontalLinePrice = "horizontal_line_price"
        case targetPrice = "target_price"
        case stopLossPrice = "stop_loss_price"
        case alertSeverity = "alert_severity"
        case trendlineDirection = "trendline_direction"
        case selectedIndicator = "selected_indicator"
        case chartPattern = "chart_pattern"
        case selectedEmoji = "selected_emoji"
        case pollQuestion = "poll_question"
        case pollOptions = "poll_options"
    }
}

/// Update a chart marker
/// Backend: UpdateMarkerRequest
struct RLUpdateMarkerRequest: Codable {
    let note: String?
    let price: Double?
    let isVisible: Bool?
    let horizontalLinePrice: Double?
    let targetPrice: Double?
    let alertSeverity: String?
    let trendlineDirection: String?
    let selectedIndicator: String?
    let chartPattern: String?
    let selectedEmoji: String?
    
    enum CodingKeys: String, CodingKey {
        case note, price
        case isVisible = "is_visible"
        case horizontalLinePrice = "horizontal_line_price"
        case targetPrice = "target_price"
        case alertSeverity = "alert_severity"
        case trendlineDirection = "trendline_direction"
        case selectedIndicator = "selected_indicator"
        case chartPattern = "chart_pattern"
        case selectedEmoji = "selected_emoji"
    }
}

/// Create marker comment
/// Backend: CreateMarkerCommentRequest
struct RLCreateMarkerCommentRequest: Codable {
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?

    init(content: String, attachmentUrl: String? = nil, attachmentType: String? = nil, attachmentName: String? = nil) {
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
    }
}

/// Edit marker comment
/// Backend: EditMarkerCommentRequest
struct RLEditMarkerCommentRequest: Codable {
    let content: String
}

/// Vote on poll
/// Backend: VotePollRequest
struct RLVotePollRequest: Codable {
    let optionId: UUID
    
    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
    }
}

/// Send chart chat message
/// Backend: SendChartChatMessageRequest
struct RLSendChartChatMessageRequest: Codable {
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?

    init(content: String, attachmentUrl: String? = nil, attachmentType: String? = nil, attachmentName: String? = nil) {
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
    }
}

/// Edit chart chat message
/// Backend: EditChartChatMessageRequest
struct RLEditChartChatMessageRequest: Codable {
    let content: String
}

/// Report content (generic across all content types)
/// Backend: ReportContentRequest
struct RLReportContentRequest: Codable {
    let contentType: String   // chatroom_message | dm_message | chart_chat_message | marker_comment | chart_marker
    let contentId: UUID
    let guildId: UUID?
    let reason: String        // spam | harassment | hate_speech | inappropriate | misinformation | other
    let details: String?
    
    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentId = "content_id"
        case guildId = "guild_id"
        case reason, details
    }
}

/// Update chart chat settings (mute/pin)
/// Backend: UpdateChartChatSettingsRequest
struct RLUpdateChartChatSettingsRequest: Codable {
    let isMuted: Bool?
    let isPinned: Bool?
    
    enum CodingKeys: String, CodingKey {
        case isMuted = "is_muted"
        case isPinned = "is_pinned"
    }
}


// ── Settings & Report Responses ──

/// Chart chat per-user settings response
/// Backend: ChartChatUserSettingsResponse
struct RLChartChatUserSettingsDTO: Codable {
    let chatId: UUID
    let userId: UUID
    let isMuted: Bool
    let isPinned: Bool
}

/// Content report response — see RLCoreDTOs.swift for full RLContentReportDTO
/// (Moved to RLCoreDTOs.swift with additional fields for reports dashboard)


// =============================================================================
// MARK: - WebSocket / Real-time Payloads
// =============================================================================

/// Market tick update (from tick_ingestor via WebSocket)
/// Backend: MarketTickPayload
struct RLMarketTickDTO: Codable {
    let symbolId: UUID
    let ticker: String
    let price: Double
    let bid: Double?
    let ask: Double?
    let volume: Double?
    let timestamp: Date
}

/// Candle update (from ingestor via WebSocket)
/// Backend: CandleUpdatePayload
struct RLCandleUpdateDTO: Codable {
    let symbolId: UUID
    let timeframe: String
    let candle: RLCandleDTO
    let isNewCandle: Bool
}

/// Marker event (real-time marker activity)
/// Backend: MarkerEventPayload
struct RLMarkerEventDTO: Codable {
    let eventType: String                       // created, updated, deleted, liked, commented
    let guildId: UUID
    let symbolId: UUID
    let marker: RLChartMarkerDTO?
    let markerId: UUID?
    let likeCount: Int?
    let commentCount: Int?
    let actorId: UUID
}


// =============================================================================
// MARK: - Chart Chat Channel Helpers
// =============================================================================

extension MessagingChannel {
    /// Chart chat channel for real-time messages
    static func chartChatChannel(_ chatId: UUID) -> MessagingChannel {
        return .chartChat(chatId)
    }
}


// =============================================================================
// MARK: - Sample Data (DEBUG only)
// =============================================================================

#if DEBUG
extension RLTradingSymbolDTO {
    static let sampleBTC = RLTradingSymbolDTO(
        id: UUID(),
        ticker: "BTC/USD",
        displayName: "Bitcoin / US Dollar",
        assetClass: "crypto",
        exchange: "Binance",
        tickSize: 0.01,
        lotSize: 0.001,
        decimalPlaces: 2,
        isActive: true,
        iconName: "bitcoinsign.circle.fill",
        iconUrl: nil,
        primaryColor: "#F7931A",
        secondaryColor: "#4A4A4A",
        currentPrice: 97500.50,
        priceFormatted: "97,500.50",
        change24h: 1250.00,
        changePercent24h: 1.30,
        changeFormatted: "+1,250.00 (+1.30%)",
        isUp: true,
        high24h: 98200.00,
        low24h: 95800.00,
        volume24h: 28500000000,
        volumeFormatted: "28.5B",
        inPersonalWatchlist: nil,
        inGuildWatchlist: nil,
        isRequestedForGuild: nil,
        activeMarketProvider: "twelve_data",
        isSupportedByActiveProvider: true
    )
    
    static let sampleEURUSD = RLTradingSymbolDTO(
        id: UUID(),
        ticker: "EUR/USD",
        displayName: "Euro / US Dollar",
        assetClass: "forex",
        exchange: nil,
        tickSize: 0.0001,
        lotSize: 1.0,
        decimalPlaces: 5,
        isActive: true,
        iconName: "eurosign.circle.fill",
        iconUrl: nil,
        primaryColor: "#003399",
        secondaryColor: "#FFD700",
        currentPrice: 1.08520,
        priceFormatted: "1.08520",
        change24h: 0.00120,
        changePercent24h: 0.11,
        changeFormatted: "+0.00120 (+0.11%)",
        isUp: true,
        high24h: 1.08650,
        low24h: 1.08200,
        volume24h: nil,
        volumeFormatted: nil,
        inPersonalWatchlist: nil,
        inGuildWatchlist: nil,
        isRequestedForGuild: nil,
        activeMarketProvider: "twelve_data",
        isSupportedByActiveProvider: true
    )
}
#endif
