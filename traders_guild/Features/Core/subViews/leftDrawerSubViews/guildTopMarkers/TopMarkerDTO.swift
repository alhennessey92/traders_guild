//
//  TopMarkerDTOs.swift
//  traders_guild
//
//  Data Transfer Objects for Top Markers feature
//  Lightweight marker representation optimized for list display
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - TOP MARKER DTO
// MARK: - ================================================================================================

/// Lightweight marker DTO optimized for the Top Markers list display
/// Contains essential display info without full marker detail overhead
struct TopMarkerDTO: Identifiable, Equatable {
    let id: UUID                        // Marker unique ID
    let symbolId: UUID                  // Symbol this marker is on
    let symbolTicker: String            // Symbol ticker (e.g., "EURUSD")
    let symbolBrandColor: String?       // Brand color hex for symbol
    let symbolAssetClass: AssetClass    // Asset class for grouping
    let guildId: UUID                   // Guild context
    
    // Author info (embedded for no lookup)
    let authorId: UUID                  // Author's user ID
    let authorUsername: String          // Author's username
    let authorInitials: String          // Author's initials for avatar
    let authorAvatarURL: String?        // Author's avatar URL
    let authorIsOnline: Bool            // Is author currently online
    let authorReputation: Int           // Author's reputation score
    let authorRole: MemberRole          // Author's role in guild
    
    // Marker properties
    let type: MarkerType                // Type of marker
    let notePreview: String?            // First ~100 chars of note
    let createdAt: Date                 // When marker was created
    let createdAtFormatted: String      // Pre-formatted time (e.g., "2h ago")
    
    // Chart position info (for navigation)
    let candleIndex: Int                // Index in candle array
    let timestamp: Date                 // Candle timestamp
    let price: Double                   // Price level
    let timeframe: ChartTimeframe       // Timeframe of the chart
    
    // Engagement data
    var likeCount: Int                  // Number of likes
    var isLikedByCurrentUser: Bool      // Has current user liked?
    var commentCount: Int               // Number of comments
    
    // Ranking data (internal use for sorting)
    var trendingScore: Double           // Score for trending algorithm
    
    // Permissions
    let isCurrentUserMarker: Bool       // Did current user create this?
    
    // MARK: - Equatable (by ID only for performance)
    
    static func == (lhs: TopMarkerDTO, rhs: TopMarkerDTO) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ================================================================================================
// MARK: - TOP MARKERS RESPONSE DTO
// MARK: - ================================================================================================

/// Response from top markers API endpoint
struct TopMarkersResponseDTO {
    let trending: [TopMarkerDTO]            // Today's trending markers
    let bySymbol: [String: [TopMarkerDTO]]  // Grouped by symbol ticker
    let following: [TopMarkerDTO]           // From users you follow
    let mine: [TopMarkerDTO]                // Your own markers
    let lastUpdated: Date                   // When this data was fetched
}

// MARK: - ================================================================================================
// MARK: - MARKER NAVIGATION INFO
// MARK: - ================================================================================================

/// Information needed to navigate to a marker on the chart
struct MarkerNavigationInfo: Identifiable {
    let id: UUID                        // For Identifiable
    let markerId: UUID                  // The marker to navigate to
    let symbolId: UUID                  // Symbol to load
    let symbolTicker: String            // Symbol ticker
    let timeframe: ChartTimeframe       // Timeframe to use
    let candleIndex: Int                // Index to scroll to
    let timestamp: Date                 // Timestamp for positioning
    let price: Double                   // Price level
    
    init(from marker: TopMarkerDTO) {
        self.id = UUID()
        self.markerId = marker.id
        self.symbolId = marker.symbolId
        self.symbolTicker = marker.symbolTicker
        self.timeframe = marker.timeframe
        self.candleIndex = marker.candleIndex
        self.timestamp = marker.timestamp
        self.price = marker.price
    }
}

// MARK: - ================================================================================================
// MARK: - CONVERSION HELPERS
// MARK: - ================================================================================================

extension TopMarkerDTO {
    /// Create TopMarkerDTO from full ChartMarkerDTO
    /// Used when converting detailed markers to lightweight list items
    static func fromChartMarker(
        _ marker: ChartMarkerDTO,
        symbol: TradingSymbolDTO,
        currentUserId: UUID
    ) -> TopMarkerDTO {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        return TopMarkerDTO(
            id: marker.id,
            symbolId: symbol.id,
            symbolTicker: symbol.ticker,
            symbolBrandColor: symbol.primaryColor,
            symbolAssetClass: symbol.assetClass,
            guildId: marker.guildId,
            authorId: marker.author.globalMember.id,
            authorUsername: marker.author.globalMember.username,
            authorInitials: String(marker.author.globalMember.username.prefix(2)).uppercased(),
            authorAvatarURL: marker.author.globalMember.avatarURL,
            authorIsOnline: marker.author.isOnline,
            authorReputation: marker.author.reputation,
            authorRole: marker.author.roleInGuild,
            type: marker.type,
            notePreview: marker.note?.prefix(100).description,
            createdAt: marker.createdAt,
            createdAtFormatted: formatter.localizedString(for: marker.createdAt, relativeTo: Date()),
            candleIndex: marker.candleIndex,
            timestamp: marker.timestamp,
            price: marker.price,
            timeframe: .h1, // Would come from chart context in real impl
            likeCount: marker.likeCount,
            isLikedByCurrentUser: marker.isLikedByCurrentUser,
            commentCount: marker.commentCount,
            trendingScore: Double(marker.likeCount * 3 + marker.commentCount * 2),
            isCurrentUserMarker: marker.isCurrentUserMarker
        )
    }
}

// MARK: - ================================================================================================
// MARK: - DEBUG PREVIEW SAMPLES
// MARK: - ================================================================================================

#if DEBUG
extension TopMarkerDTO {
    /// Sample marker for previews only
    static var sample: TopMarkerDTO {
        TopMarkerDTO(
            id: UUID(),
            symbolId: UUID(),
            symbolTicker: "EURUSD",
            symbolBrandColor: "#3366FF",
            symbolAssetClass: .forex,
            guildId: UUID(),
            authorId: UUID(),
            authorUsername: "TraderMike",
            authorInitials: "TM",
            authorAvatarURL: nil,
            authorIsOnline: true,
            authorReputation: 1250,
            authorRole: .moderator,
            type: .entry,
            notePreview: "Strong support level here, watching for a bounce. RSI showing oversold conditions.",
            createdAt: Date().addingTimeInterval(-3600 * 2),
            createdAtFormatted: "2h ago",
            candleIndex: 45,
            timestamp: Date().addingTimeInterval(-3600 * 2),
            price: 1.0865,
            timeframe: .h1,
            likeCount: 47,
            isLikedByCurrentUser: true,
            commentCount: 12,
            trendingScore: 156.5,
            
            isCurrentUserMarker: false
        )
    }
    
    static var sample2: TopMarkerDTO {
        TopMarkerDTO(
            id: UUID(),
            symbolId: UUID(),
            symbolTicker: "BTCUSD",
            symbolBrandColor: "#F7931A",
            symbolAssetClass: .crypto,
            guildId: UUID(),
            authorId: UUID(),
            authorUsername: "CryptoKing",
            authorInitials: "CK",
            authorAvatarURL: nil,
            authorIsOnline: false,
            authorReputation: 2100,
            authorRole: .admin,
            type: .predictionTarget,
            notePreview: "Expecting a breakout above 45k. Volume picking up significantly.",
            createdAt: Date().addingTimeInterval(-3600 * 4),
            createdAtFormatted: "4h ago",
            candleIndex: 32,
            timestamp: Date().addingTimeInterval(-3600 * 4),
            price: 44250.0,
            timeframe: .h4,
            likeCount: 38,
            isLikedByCurrentUser: false,
            commentCount: 8,
            trendingScore: 142.3,
            
            isCurrentUserMarker: false
        )
    }
    
    static var sample3: TopMarkerDTO {
        TopMarkerDTO(
            id: UUID(),
            symbolId: UUID(),
            symbolTicker: "AAPL",
            symbolBrandColor: "#A2AAAD",
            symbolAssetClass: .stocks,
            guildId: UUID(),
            authorId: UUID(),
            authorUsername: "StockPro",
            authorInitials: "SP",
            authorAvatarURL: nil,
            authorIsOnline: true,
            authorReputation: 890,
            authorRole: .member,
            type: .pattern,
            notePreview: "Earnings report coming up. Historical pattern suggests volatility.",
            createdAt: Date().addingTimeInterval(-3600 * 6),
            createdAtFormatted: "6h ago",
            candleIndex: 28,
            timestamp: Date().addingTimeInterval(-3600 * 6),
            price: 185.50,
            timeframe: .d1,
            likeCount: 25,
            isLikedByCurrentUser: false,
            commentCount: 5,
            trendingScore: 98.7,
            
            isCurrentUserMarker: true
        )
    }
}
#endif
