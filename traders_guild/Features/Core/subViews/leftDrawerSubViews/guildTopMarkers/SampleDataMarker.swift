//
//  SampleData+TopMarkers.swift
//  traders_guild
//
//  Sample data extension for Top Markers feature
//  Add this to your existing SampleData.swift or keep as separate file
//

import Foundation

// MARK: - ================================================================================================
// MARK: - SAMPLE DATA EXTENSION - TOP MARKERS
// MARK: - ================================================================================================

extension SampleData {
    
    // MARK: - Top Marker Authors
    
    /// Sample authors for top markers
    static let topMarkerAuthors: [(id: UUID, username: String, initials: String, isOnline: Bool, reputation: Int, role: MemberRole)] = [
        (UUID(), "TraderMike", "TM", true, 1850, .moderator),
        (UUID(), "CryptoQueen", "CQ", true, 2100, .admin),
        (UUID(), "ForexMaster", "FM", false, 1650, .moderator),
        (UUID(), "ChartWizard", "CW", true, 1420, .member),
        (UUID(), "TrendHunter", "TH", false, 980, .member),
        (UUID(), "PriceAction", "PA", true, 1320, .moderator),
        (UUID(), "SignalPro", "SP", false, 1150, .member),
        (UUID(), "MarketSage", "MS", true, 2450, .admin)
    ]
    
    // MARK: - Trending Markers
    
    /// Today's trending markers (sorted by engagement)
    static var trendingTopMarkers: [TopMarkerDTO] {
        let guildId = sampleGuild.id
        
        return [
            // #1 - Hot EUR/USD entry
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "EURUSD" }?.id ?? UUID(),
                symbolTicker: "EURUSD",
                symbolBrandColor: "#3366FF",
                symbolAssetClass: .forex,
                guildId: guildId,
                authorId: topMarkerAuthors[0].id,
                authorUsername: topMarkerAuthors[0].username,
                authorInitials: topMarkerAuthors[0].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[0].isOnline,
                authorReputation: topMarkerAuthors[0].reputation,
                authorRole: topMarkerAuthors[0].role,
                type: .entry,
                notePreview: "Perfect entry at the 61.8% fib retracement. Stop below the swing low, targeting 1.0950. Risk/reward is excellent here.",
                createdAt: Date().addingTimeInterval(-3600 * 1.5),
                createdAtFormatted: "1h ago",
                candleIndex: 48,
                timestamp: Date().addingTimeInterval(-3600 * 1.5),
                price: 1.0865,
                timeframe: .h1,
                likeCount: 67,
                isLikedByCurrentUser: true,
                commentCount: 23,
                trendingScore: 245.0,
                isCurrentUserMarker: false
            ),
            
            // #2 - BTC prediction
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "BTCUSD" }?.id ?? UUID(),
                symbolTicker: "BTCUSD",
                symbolBrandColor: "#F7931A",
                symbolAssetClass: .crypto,
                guildId: guildId,
                authorId: topMarkerAuthors[1].id,
                authorUsername: topMarkerAuthors[1].username,
                authorInitials: topMarkerAuthors[1].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[1].isOnline,
                authorReputation: topMarkerAuthors[1].reputation,
                authorRole: topMarkerAuthors[1].role,
                type: .predictionTarget,
                notePreview: "Breakout imminent! Cup and handle pattern completing. Target: $48,500 within 48 hours.",
                createdAt: Date().addingTimeInterval(-3600 * 3),
                createdAtFormatted: "3h ago",
                candleIndex: 42,
                timestamp: Date().addingTimeInterval(-3600 * 3),
                price: 44850.0,
                timeframe: .h4,
                likeCount: 52,
                isLikedByCurrentUser: false,
                commentCount: 18,
                trendingScore: 198.0,
                isCurrentUserMarker: false
            ),
            
            // #3 - Gold alert
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "XAUUSD" }?.id ?? UUID(),
                symbolTicker: "XAUUSD",
                symbolBrandColor: "#FFD700",
                symbolAssetClass: .commodities,
                guildId: guildId,
                authorId: topMarkerAuthors[2].id,
                authorUsername: topMarkerAuthors[2].username,
                authorInitials: topMarkerAuthors[2].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[2].isOnline,
                authorReputation: topMarkerAuthors[2].reputation,
                authorRole: topMarkerAuthors[2].role,
                type: .alert,
                notePreview: "⚠️ Critical resistance at 2050. Watching for rejection or breakout. Fed speech tomorrow could be catalyst.",
                createdAt: Date().addingTimeInterval(-3600 * 4),
                createdAtFormatted: "4h ago",
                candleIndex: 38,
                timestamp: Date().addingTimeInterval(-3600 * 4),
                price: 2048.50,
                timeframe: .h1,
                likeCount: 45,
                isLikedByCurrentUser: true,
                commentCount: 14,
                trendingScore: 173.0,
                isCurrentUserMarker: false
            ),
            
            // #4 - GBP/USD pattern
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "GBPUSD" }?.id ?? UUID(),
                symbolTicker: "GBPUSD",
                symbolBrandColor: "#FF3366",
                symbolAssetClass: .forex,
                guildId: guildId,
                authorId: topMarkerAuthors[3].id,
                authorUsername: topMarkerAuthors[3].username,
                authorInitials: topMarkerAuthors[3].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[3].isOnline,
                authorReputation: topMarkerAuthors[3].reputation,
                authorRole: topMarkerAuthors[3].role,
                type: .pattern,
                notePreview: "Head and shoulders pattern on the 4H. Neckline at 1.2650. Measured move targets 1.2450.",
                createdAt: Date().addingTimeInterval(-3600 * 5),
                createdAtFormatted: "5h ago",
                candleIndex: 35,
                timestamp: Date().addingTimeInterval(-3600 * 5),
                price: 1.2720,
                timeframe: .h4,
                likeCount: 38,
                isLikedByCurrentUser: false,
                commentCount: 11,
                trendingScore: 149.0,
                isCurrentUserMarker: false
            ),
            
            // #5 - ETH support
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "ETHUSD" }?.id ?? UUID(),
                symbolTicker: "ETHUSD",
                symbolBrandColor: "#627EEA",
                symbolAssetClass: .crypto,
                guildId: guildId,
                authorId: topMarkerAuthors[4].id,
                authorUsername: topMarkerAuthors[4].username,
                authorInitials: topMarkerAuthors[4].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[4].isOnline,
                authorReputation: topMarkerAuthors[4].reputation,
                authorRole: topMarkerAuthors[4].role,
                type: .support,
                notePreview: "Strong support zone 2250-2280. Multiple touches, volume profile shows high activity.",
                createdAt: Date().addingTimeInterval(-3600 * 6),
                createdAtFormatted: "6h ago",
                candleIndex: 32,
                timestamp: Date().addingTimeInterval(-3600 * 6),
                price: 2265.0,
                timeframe: .h1,
                likeCount: 31,
                isLikedByCurrentUser: false,
                commentCount: 8,
                trendingScore: 123.0,
                isCurrentUserMarker: false
            ),
            
            // #6 - AAPL exit
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "AAPL" }?.id ?? UUID(),
                symbolTicker: "AAPL",
                symbolBrandColor: "#A2AAAD",
                symbolAssetClass: .stocks,
                guildId: guildId,
                authorId: topMarkerAuthors[5].id,
                authorUsername: topMarkerAuthors[5].username,
                authorInitials: topMarkerAuthors[5].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[5].isOnline,
                authorReputation: topMarkerAuthors[5].reputation,
                authorRole: topMarkerAuthors[5].role,
                type: .exit,
                notePreview: "Taking profits here at resistance. Up 3.2% on this trade. Will re-enter on pullback.",
                createdAt: Date().addingTimeInterval(-3600 * 7),
                createdAtFormatted: "7h ago",
                candleIndex: 28,
                timestamp: Date().addingTimeInterval(-3600 * 7),
                price: 188.45,
                timeframe: .d1,
                likeCount: 28,
                isLikedByCurrentUser: true,
                commentCount: 6,
                trendingScore: 110.0,
                isCurrentUserMarker: false
            ),
            
            // #7 - USD/JPY trendline
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "USDJPY" }?.id ?? UUID(),
                symbolTicker: "USDJPY",
                symbolBrandColor: "#BC002D",
                symbolAssetClass: .forex,
                guildId: guildId,
                authorId: topMarkerAuthors[6].id,
                authorUsername: topMarkerAuthors[6].username,
                authorInitials: topMarkerAuthors[6].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[6].isOnline,
                authorReputation: topMarkerAuthors[6].reputation,
                authorRole: topMarkerAuthors[6].role,
                type: .trendline,
                notePreview: "Rising trendline from October low. Third touch incoming - high probability bounce zone.",
                createdAt: Date().addingTimeInterval(-3600 * 8),
                createdAtFormatted: "8h ago",
                candleIndex: 25,
                timestamp: Date().addingTimeInterval(-3600 * 8),
                price: 148.75,
                timeframe: .h4,
                likeCount: 22,
                isLikedByCurrentUser: false,
                commentCount: 5,
                trendingScore: 89.0,
                isCurrentUserMarker: false
            ),
            
            // #8 - SPX resistance
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "SPX500" }?.id ?? UUID(),
                symbolTicker: "SPX500",
                symbolBrandColor: "#00B140",
                symbolAssetClass: .indices,
                guildId: guildId,
                authorId: topMarkerAuthors[7].id,
                authorUsername: topMarkerAuthors[7].username,
                authorInitials: topMarkerAuthors[7].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[7].isOnline,
                authorReputation: topMarkerAuthors[7].reputation,
                authorRole: topMarkerAuthors[7].role,
                type: .resistance,
                notePreview: "Major resistance at all-time highs. Expecting consolidation before breakout attempt.",
                createdAt: Date().addingTimeInterval(-3600 * 10),
                createdAtFormatted: "10h ago",
                candleIndex: 22,
                timestamp: Date().addingTimeInterval(-3600 * 10),
                price: 4785.0,
                timeframe: .d1,
                likeCount: 19,
                isLikedByCurrentUser: false,
                commentCount: 4,
                trendingScore: 76.0,
                isCurrentUserMarker: false
            )
        ]
    }
    
    // MARK: - Symbol Grouped Markers
    
    /// Markers grouped by symbol ticker (top 3 per symbol)
    static var symbolGroupedTopMarkers: [String: [TopMarkerDTO]] {
        var grouped: [String: [TopMarkerDTO]] = [:]
        
        // Add all trending markers grouped by symbol
        for marker in trendingTopMarkers {
            if grouped[marker.symbolTicker] == nil {
                grouped[marker.symbolTicker] = []
            }
            grouped[marker.symbolTicker]?.append(marker)
        }
        
        // Add some additional markers for variety
        let additionalMarkers = generateAdditionalSymbolMarkers()
        for marker in additionalMarkers {
            if grouped[marker.symbolTicker] == nil {
                grouped[marker.symbolTicker] = []
            }
            grouped[marker.symbolTicker]?.append(marker)
        }
        
        // Sort each group by like count and keep only top 3
        for (ticker, markers) in grouped {
            let sorted = markers.sorted { $0.likeCount > $1.likeCount }
            grouped[ticker] = Array(sorted.prefix(3))
        }
        
        return grouped
    }
    
    /// Generate additional markers for symbol grouping
    private static func generateAdditionalSymbolMarkers() -> [TopMarkerDTO] {
        let guildId = sampleGuild.id
        
        return [
            // Extra EUR/USD marker
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "EURUSD" }?.id ?? UUID(),
                symbolTicker: "EURUSD",
                symbolBrandColor: "#3366FF",
                symbolAssetClass: .forex,
                guildId: guildId,
                authorId: topMarkerAuthors[4].id,
                authorUsername: topMarkerAuthors[4].username,
                authorInitials: topMarkerAuthors[4].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[4].isOnline,
                authorReputation: topMarkerAuthors[4].reputation,
                authorRole: topMarkerAuthors[4].role,
                type: .indicator,
                notePreview: "Confluence zone - 200 EMA meets horizontal support. High probability reaction area.",
                createdAt: Date().addingTimeInterval(-3600 * 12),
                createdAtFormatted: "12h ago",
                candleIndex: 18,
                timestamp: Date().addingTimeInterval(-3600 * 12),
                price: 1.0845,
                timeframe: .h1,
                likeCount: 15,
                isLikedByCurrentUser: false,
                commentCount: 3,
                trendingScore: 54.0,
                
                isCurrentUserMarker: false
            ),
            
            // Extra BTC marker
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "BTCUSD" }?.id ?? UUID(),
                symbolTicker: "BTCUSD",
                symbolBrandColor: "#F7931A",
                symbolAssetClass: .crypto,
                guildId: guildId,
                authorId: topMarkerAuthors[3].id,
                authorUsername: topMarkerAuthors[3].username,
                authorInitials: topMarkerAuthors[3].initials,
                authorAvatarURL: nil,
                authorIsOnline: topMarkerAuthors[3].isOnline,
                authorReputation: topMarkerAuthors[3].reputation,
                authorRole: topMarkerAuthors[3].role,
                type: .entry,
                notePreview: "Adding to my long position here. Scaling in on the pullback to support.",
                createdAt: Date().addingTimeInterval(-3600 * 14),
                createdAtFormatted: "14h ago",
                candleIndex: 15,
                timestamp: Date().addingTimeInterval(-3600 * 14),
                price: 44200.0,
                timeframe: .h4,
                likeCount: 12,
                isLikedByCurrentUser: true,
                commentCount: 2,
                trendingScore: 42.0,
                
                isCurrentUserMarker: false
            )
        ]
    }
    
    // MARK: - Following Markers
    
    /// Markers from users the current user follows
    static var followingTopMarkers: [TopMarkerDTO] {
        // Return subset of trending markers (simulating followed users)
        return Array(trendingTopMarkers.prefix(4))
    }
    
    // MARK: - My Markers
    
    /// Current user's own markers
    static var myTopMarkers: [TopMarkerDTO] {
        let guildId = sampleGuild.id
        let userId = currentUser.id
        
        return [
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "EURUSD" }?.id ?? UUID(),
                symbolTicker: "EURUSD",
                symbolBrandColor: "#3366FF",
                symbolAssetClass: .forex,
                guildId: guildId,
                authorId: userId,
                authorUsername: currentUser.username,
                authorInitials: String(currentUser.username.prefix(2)).uppercased(),
                authorAvatarURL: currentUser.avatarURL,
                authorIsOnline: true,
                authorReputation: currentUser.guildMembership.reputation,
                authorRole: currentUser.guildMembership.roleInGuild,
                type: .entry,
                notePreview: "My entry on the London open. Following the momentum from Asian session.",
                createdAt: Date().addingTimeInterval(-3600 * 2),
                createdAtFormatted: "2h ago",
                candleIndex: 45,
                timestamp: Date().addingTimeInterval(-3600 * 2),
                price: 1.0872,
                timeframe: .m15,
                likeCount: 8,
                isLikedByCurrentUser: false, // Can't like your own
                commentCount: 3,
                trendingScore: 30.0,
                
                isCurrentUserMarker: true
            ),
            
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "GBPUSD" }?.id ?? UUID(),
                symbolTicker: "GBPUSD",
                symbolBrandColor: "#FF3366",
                symbolAssetClass: .forex,
                guildId: guildId,
                authorId: userId,
                authorUsername: currentUser.username,
                authorInitials: String(currentUser.username.prefix(2)).uppercased(),
                authorAvatarURL: currentUser.avatarURL,
                authorIsOnline: true,
                authorReputation: currentUser.guildMembership.reputation,
                authorRole: currentUser.guildMembership.roleInGuild,
                type: .note,
                notePreview: "Watching this descending channel. Breakout could signal trend reversal.",
                createdAt: Date().addingTimeInterval(-3600 * 8),
                createdAtFormatted: "8h ago",
                candleIndex: 28,
                timestamp: Date().addingTimeInterval(-3600 * 8),
                price: 1.2695,
                timeframe: .h1,
                likeCount: 5,
                isLikedByCurrentUser: false,
                commentCount: 1,
                trendingScore: 17.0,
                
                isCurrentUserMarker: true
            ),
            
            TopMarkerDTO(
                id: UUID(),
                symbolId: allTradingSymbolDTOs.first { $0.ticker == "XAUUSD" }?.id ?? UUID(),
                symbolTicker: "XAUUSD",
                symbolBrandColor: "#FFD700",
                symbolAssetClass: .commodities,
                guildId: guildId,
                authorId: userId,
                authorUsername: currentUser.username,
                authorInitials: String(currentUser.username.prefix(2)).uppercased(),
                authorAvatarURL: currentUser.avatarURL,
                authorIsOnline: true,
                authorReputation: currentUser.guildMembership.reputation,
                authorRole: currentUser.guildMembership.roleInGuild,
                type: .predictionTarget,
                notePreview: "Gold looking bullish. Expecting move to 2060 by end of week.",
                createdAt: Date().addingTimeInterval(-3600 * 16),
                createdAtFormatted: "16h ago",
                candleIndex: 20,
                timestamp: Date().addingTimeInterval(-3600 * 16),
                price: 2042.0,
                timeframe: .h4,
                likeCount: 12,
                isLikedByCurrentUser: false,
                commentCount: 4,
                trendingScore: 44.0,
                
                isCurrentUserMarker: true
            )
        ]
    }
    
    // MARK: - Full Response
    
    /// Complete top markers response for API simulation
    static var topMarkersResponse: TopMarkersResponseDTO {
        TopMarkersResponseDTO(
            trending: trendingTopMarkers,
            bySymbol: symbolGroupedTopMarkers,
            following: followingTopMarkers,
            mine: myTopMarkers,
            lastUpdated: Date()
        )
    }
}
