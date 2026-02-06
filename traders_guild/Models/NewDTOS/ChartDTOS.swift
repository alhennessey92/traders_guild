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
}


// =============================================================================
// MARK: - Candles
// =============================================================================

/// Single OHLCV candle
/// Backend: CandleResponse
struct RLCandleDTO: Codable, Equatable {
    let timestamp: Date
    let timestampFormatted: String
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
    let isCurrentUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    
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
        case timestamp = "createdAt"        // validation_alias maps created_at → timestamp
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
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
    let likeCount: Int
    let isLikedByCurrentUser: Bool
    let commentCount: Int
    let comments: [RLMarkerCommentDTO]
    
    // Permissions
    let isCurrentUserMarker: Bool
    let canEdit: Bool
    let canDelete: Bool
    
    // Type-specific (exploded from JSONB metadata)
    let horizontalLinePrice: Double?
    let targetPrice: Double?
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
    
    // Engagement
    let likeCount: Int
    let isLikedByCurrentUser: Bool
    let commentCount: Int
    
    // Ranking
    let trendingScore: Double
    
    // Permissions
    let isCurrentUserMarker: Bool
    
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
    let isCurrentUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    
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
        case timestamp = "createdAt"
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
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

/// Content report response
/// Backend: ContentReportResponse
struct RLContentReportDTO: Codable, Identifiable {
    let id: UUID
    let contentType: String
    let contentId: UUID
    let reason: String
    let status: String
    let createdAt: Date
}


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
        volumeFormatted: "28.5B"
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
        volumeFormatted: nil
    )
}
#endif
