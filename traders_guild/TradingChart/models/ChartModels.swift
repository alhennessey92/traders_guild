//
//  ChartModels.swift
//  traders_guild
//
//  Chart-specific models (excluding Candle which is in Candle.swift)
//  Following the DTO pattern
//

import Foundation
import SwiftUI

// MARK: - Trading Symbol DTO

/// Trading symbol model for chart data
/// Follows the same DTO pattern as your other models
struct TradingSymbol: Identifiable, Codable, Hashable {
    let id: UUID
    let symbol: String              // e.g., "EURUSD", "BTCUSD"
    let displayName: String         // e.g., "Euro / US Dollar"
    let assetClass: AssetClass
    let exchange: String?           // e.g., "Forex", "NASDAQ", "Binance"
    let tickSize: Double            // Minimum price movement
    let lotSize: Double             // Minimum quantity
    let isActive: Bool
    
    /// Asset class categorization
    enum AssetClass: String, Codable, CaseIterable {
        case forex
        case crypto
        case stocks
        case commodities
        case indices
        case futures
        
        /// Icon for each asset class
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
    
    /// Format price according to asset class conventions
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

/// Timeframe for chart data
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
    
    /// Display name for UI
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
    
    /// Short name for compact UI (buttons)
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
    
    /// Duration in seconds
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
    
    /// How many candles to initially load
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
    
    /// How many grid lines to show
    var gridLineCount: Int {
        switch self {
        case .m1, .m5: return 6
        case .m15, .m30: return 5
        case .h1, .h4: return 4
        case .d1, .w1, .mn: return 3
        }
    }
    
    /// Timeframe category for grouping in UI
    var group: TimeframeGroup {
        switch self {
        case .m1, .m5, .m15, .m30: return .minutes
        case .h1, .h4: return .hours
        case .d1, .w1, .mn: return .daily
        }
    }
}

/// Timeframe grouping for UI organization
enum TimeframeGroup: String, CaseIterable {
    case minutes = "Minutes"
    case hours = "Hours"
    case daily = "Daily & Weekly"
}

/// Grouped timeframes for UI display
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

enum MarkerType: String, Codable, CaseIterable {
    case entry = "Entry"
    case exit = "Exit"
    case stopLoss = "Stop Loss"
    case takeProfit = "Take Profit"
    case support = "Support"
    case resistance = "Resistance"
    case alert = "Alert"
    case pattern = "Pattern"
    case note = "Note"
    
    var color: Color {
        switch self {
        case .entry: return .green
        case .exit: return .orange
        case .stopLoss: return .red
        case .takeProfit: return .blue
        case .support: return .purple
        case .resistance: return .pink
        case .alert: return .yellow
        case .pattern: return .cyan
        case .note: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .entry: return "arrow.up.circle.fill"
        case .exit: return "arrow.down.circle.fill"
        case .stopLoss: return "xmark.shield.fill"
        case .takeProfit: return "checkmark.shield.fill"
        case .support: return "arrow.up"
        case .resistance: return "arrow.down"
        case .alert: return "bell.fill"
        case .pattern: return "sparkles"
        case .note: return "note.text"
        }
    }
}

// MARK: - Chart Marker Model

struct ChartMarker: Identifiable, Codable {
    let id: UUID
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let type: MarkerType
    let userId: String
    let username: String
    var note: String?
    let createdAt: Date
    let guildId: String
    var isVisible: Bool
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    
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
        createdAt: Date = Date()
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
        self.isVisible = true
        self.likeCount = 0
        self.isLikedByCurrentUser = false
    }
}
