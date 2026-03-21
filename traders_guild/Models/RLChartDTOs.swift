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
// MARK: - Marker Intent (V2)
// =============================================================================

enum RLMarkerIntent: String, Codable, CaseIterable {
    case analysis
    case setup
    case alert
    case question
    case poll
    case news
    case reaction
    case personal

    var displayName: String {
        switch self {
        case .analysis: return "Analysis"
        case .setup: return "Setup"
        case .alert: return "Alert"
        case .question: return "Question"
        case .poll: return "Poll"
        case .news: return "News"
        case .reaction: return "Reaction"
        case .personal: return "Personal"
        }
    }

    var subtitle: String {
        switch self {
        case .analysis: return "Share chart analysis"
        case .setup: return "Entry, SL, and TP setup"
        case .alert: return "Flag urgent context"
        case .question: return "Ask your guild"
        case .poll: return "Collect quick votes"
        case .news: return "Share market headlines"
        case .reaction: return "React with emoji"
        case .personal: return "Private marker for you"
        }
    }

    var icon: String {
        switch self {
        case .analysis: return "waveform.path.ecg.magnifyingglass"
        case .setup: return "gearshape.arrow.trianglehead.2.clockwise.rotate.90"
        case .alert: return "exclamationmark.shield.fill"
        case .question: return "questionmark.circle.dashed"
        case .poll: return "list.bullet.clipboard"
        case .news: return "newspaper.fill"
        case .reaction: return "face.smiling"
        case .personal: return "person.badge.shield.checkmark.fill"
        }
    }

    var color: Color {
        switch self {
        case .analysis: return Color(hex: "#0F9EB4") ?? .teal
        case .setup: return Color(hex: "#0E854D") ?? .green
        case .alert: return Color(hex: "#8E959D") ?? .gray
        case .question: return Color(hex: "#5B7FFF") ?? .blue
        case .poll: return Color(hex: "#8B5CF6") ?? .purple
        case .news: return Color(hex: "#EC4899") ?? .pink
        case .reaction: return Color(hex: "#F59E0B") ?? .orange
        case .personal: return Color(hex: "#6B7280") ?? .gray
        }
    }

    func markerSymbol(for severity: MarkerAlertSeverity? = nil) -> String {
        if self == .alert, let severity {
            return severity.markerIcon
        }
        return icon
    }

    func markerPalette(for severity: MarkerAlertSeverity? = nil) -> [Color] {
        if self == .alert, let severity {
            return severity.markerPalette
        }

        let base = MarkerVisualSpec.iconBaseColor

        switch self {
        case .setup:
            return [
                base,
                (Color(hex: "#0E854D") ?? .green).opacity(0.88),
                (Color(hex: "#4ADE80") ?? .mint).opacity(0.66),
            ]
        case .analysis:
            return [
                base,
                (Color(hex: "#0F9EB4") ?? .teal).opacity(0.88),
                (Color(hex: "#22D3EE") ?? .cyan).opacity(0.66),
            ]
        case .alert:
            return [
                base,
                (Color(hex: "#9CA3AF") ?? .gray).opacity(0.9),
                (Color(hex: "#D1D5DB") ?? .gray).opacity(0.66),
            ]
        case .question:
            return [
                base,
                (Color(hex: "#5B7FFF") ?? .blue).opacity(0.9),
                (Color(hex: "#93C5FD") ?? .cyan).opacity(0.68),
            ]
        case .poll:
            return [
                base,
                (Color(hex: "#8B5CF6") ?? .purple).opacity(0.88),
                (Color(hex: "#C4B5FD") ?? .indigo).opacity(0.66),
            ]
        case .news:
            return [
                base,
                (Color(hex: "#EC4899") ?? .pink).opacity(0.88),
                (Color(hex: "#F9A8D4") ?? .pink).opacity(0.66),
            ]
        case .reaction:
            return [
                base,
                (Color(hex: "#F59E0B") ?? .orange).opacity(0.9),
                (Color(hex: "#FCD34D") ?? .yellow).opacity(0.7),
            ]
        case .personal:
            return [
                base,
                (Color(hex: "#6B7280") ?? .gray).opacity(0.9),
                (Color(hex: "#9CA3AF") ?? .gray).opacity(0.7),
            ]
        }
    }
}

enum RLTrackingState: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case armed = "ARMED"
    case active = "ACTIVE"
    case tpHit = "TP_HIT"
    case slHit = "SL_HIT"
    case expired = "EXPIRED"

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .armed: return "Armed"
        case .active: return "Active"
        case .tpHit: return "TP Hit"
        case .slHit: return "SL Hit"
        case .expired: return "Expired"
        }
    }

    var color: Color {
        switch self {
        case .draft: return .gray
        case .armed: return Color(hex: "#0F9EB4") ?? .teal
        case .active: return .green
        case .tpHit: return .green
        case .slHit: return .red
        case .expired: return .gray
        }
    }

    var icon: String {
        switch self {
        case .draft: return "square.and.pencil"
        case .armed: return "dot.radiowaves.left.and.right"
        case .active: return "bolt.fill"
        case .tpHit: return "checkmark.circle.fill"
        case .slHit: return "xmark.circle.fill"
        case .expired: return "clock.badge.xmark.fill"
        }
    }

    var isLive: Bool {
        self == .armed || self == .active
    }

    var isResolved: Bool {
        self == .tpHit || self == .slHit || self == .expired
    }

    var timelinePosition: Int {
        switch self {
        case .draft: return 0
        case .armed: return 1
        case .active: return 2
        case .tpHit, .slHit, .expired: return 3
        }
    }
}

enum RLComponentType: String, Codable, CaseIterable {
    case anchor = "anchor"
    case levelEntry = "level.entry"
    case levelSl = "level.sl"
    case levelTp = "level.tp"
    case levelSupport = "level.support"
    case levelResistance = "level.resistance"
    case drawingTrendline = "drawing.trendline"
    case drawingHorizontalLine = "drawing.horizontal_line"
    case drawingZone = "drawing.zone"
    case indicator = "indicator"
    case linkURL = "link.url"
    case textNote = "text.note"
    case reactionEmoji = "reaction.emoji"
    case timeframeLink = "timeframe_link"

    var displayName: String {
        switch self {
        case .anchor: return "Anchor"
        case .levelEntry: return "Entry"
        case .levelSl: return "Stop Loss"
        case .levelTp: return "Take Profit"
        case .levelSupport: return "Support"
        case .levelResistance: return "Resistance"
        case .drawingTrendline: return "Trendline"
        case .drawingHorizontalLine: return "Horizontal Line"
        case .drawingZone: return "Zone"
        case .indicator: return "Indicator"
        case .linkURL: return "Link"
        case .textNote: return "Note"
        case .reactionEmoji: return "Emoji"
        case .timeframeLink: return "Timeframe"
        }
    }

    /// Short label for on-chart ghost preview price tags (2-4 chars).
    var shortLabel: String {
        switch self {
        case .anchor: return "⚓"
        case .levelEntry: return "ENT"
        case .levelSl: return "SL"
        case .levelTp: return "TP"
        case .levelSupport: return "SUP"
        case .levelResistance: return "RES"
        case .drawingTrendline: return "TL"
        case .drawingHorizontalLine: return "HL"
        case .drawingZone: return "ZN"
        case .indicator: return "IND"
        case .linkURL: return "URL"
        case .textNote: return "TXT"
        case .reactionEmoji: return "EMJ"
        case .timeframeLink: return "TF"
        }
    }

    var icon: String {
        switch self {
        case .anchor: return "scope"
        case .levelEntry, .levelSl, .levelTp, .levelSupport, .levelResistance:
            return "line.3.horizontal"
        case .drawingHorizontalLine:
            return "line.3.horizontal"
        case .drawingTrendline, .drawingZone:
            return "pencil.and.ruler"
        case .indicator:
            return "waveform.path.ecg"
        case .linkURL:
            return "link"
        case .textNote:
            return "text.bubble"
        case .reactionEmoji:
            return "face.smiling"
        case .timeframeLink:
            return "clock"
        }
    }

    var color: Color {
        switch self {
        case .anchor: return Color(hex: "#5B7FFF") ?? .blue
        case .levelEntry: return Color(hex: "#0E854D") ?? .green
        case .levelSl: return Color(hex: "#DC2626") ?? .red
        case .levelTp: return Color(hex: "#0EA5E9") ?? .cyan
        case .levelSupport: return Color(hex: "#7C3AED") ?? .purple
        case .levelResistance: return Color(hex: "#DC2626") ?? .red
        case .drawingTrendline: return Color(hex: "#14B8A6") ?? .teal
        case .drawingHorizontalLine: return Color(hex: "#9CA3AF") ?? .gray
        case .drawingZone: return Color(hex: "#22C55E") ?? .green
        case .indicator: return Color(hex: "#F59E0B") ?? .orange
        case .linkURL: return Color(hex: "#EC4899") ?? .pink
        case .textNote: return Color(hex: "#6B7280") ?? .gray
        case .reactionEmoji: return Color(hex: "#F59E0B") ?? .orange
        case .timeframeLink: return Color(hex: "#38BDF8") ?? .cyan
        }
    }

    var isLevel: Bool { rawValue.hasPrefix("level.") }
    var isDrawing: Bool { rawValue.hasPrefix("drawing.") }
}

struct AnchorPayload: Codable {
    let time: Date
    let price: Double
}

struct LevelPayload: Codable {
    let price: Double
    let label: String?
    let colorHex: String?
    let lineStyle: MarkerDrawingLineStyle?
    let lineWidth: Double?

    init(
        price: Double,
        label: String? = nil,
        colorHex: String? = nil,
        lineStyle: MarkerDrawingLineStyle? = nil,
        lineWidth: Double? = nil
    ) {
        self.price = price
        self.label = label
        self.colorHex = colorHex
        self.lineStyle = lineStyle
        self.lineWidth = lineWidth
    }
}

struct TrendlinePayload: Codable {
    let startTime: Date
    let startPrice: Double
    let endTime: Date
    let endPrice: Double
    let colorHex: String?
    let lineStyle: MarkerDrawingLineStyle?
    let lineWidth: Double?

    init(
        startTime: Date,
        startPrice: Double,
        endTime: Date,
        endPrice: Double,
        colorHex: String? = nil,
        lineStyle: MarkerDrawingLineStyle? = nil,
        lineWidth: Double? = nil
    ) {
        self.startTime = startTime
        self.startPrice = startPrice
        self.endTime = endTime
        self.endPrice = endPrice
        self.colorHex = colorHex
        self.lineStyle = lineStyle
        self.lineWidth = lineWidth
    }
}

struct HorizontalLinePayload: Codable {
    let price: Double
    let label: String?
    let colorHex: String?
    let lineStyle: MarkerDrawingLineStyle?
    let lineWidth: Double?

    init(
        price: Double,
        label: String? = nil,
        colorHex: String? = nil,
        lineStyle: MarkerDrawingLineStyle? = nil,
        lineWidth: Double? = nil
    ) {
        self.price = price
        self.label = label
        self.colorHex = colorHex
        self.lineStyle = lineStyle
        self.lineWidth = lineWidth
    }
}

struct ZonePayload: Codable {
    let topPrice: Double
    let bottomPrice: Double
    let startTime: Date?
    let endTime: Date?
    let colorHex: String?
    let lineStyle: MarkerDrawingLineStyle?
    let lineWidth: Double?

    init(
        topPrice: Double,
        bottomPrice: Double,
        startTime: Date?,
        endTime: Date?,
        colorHex: String? = nil,
        lineStyle: MarkerDrawingLineStyle? = nil,
        lineWidth: Double? = nil
    ) {
        self.topPrice = topPrice
        self.bottomPrice = bottomPrice
        self.startTime = startTime
        self.endTime = endTime
        self.colorHex = colorHex
        self.lineStyle = lineStyle
        self.lineWidth = lineWidth
    }
}

struct IndicatorPayload: Codable {
    let name: String
    let settings: [String: AnyCodable]?
    let isPrimary: Bool?
}

struct NotePayload: Codable {
    let text: String
    let offsetX: Double?
    let offsetY: Double?

    init(text: String, offsetX: Double? = nil, offsetY: Double? = nil) {
        self.text = text
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

struct LinkPayload: Codable {
    let url: String
    let title: String?
    let previewImage: String?
}

struct EmojiPayload: Codable {
    let emoji: String
    let offsetX: Double?
    let offsetY: Double?

    init(emoji: String, offsetX: Double? = nil, offsetY: Double? = nil) {
        self.emoji = emoji
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

struct TimeframeLinkPayload: Codable {
    let timeframe: String
    let note: String?
}

enum MarkerComponentPayload: Codable {
    case anchor(AnchorPayload)
    case levelEntry(LevelPayload)
    case levelSl(LevelPayload)
    case levelTp(LevelPayload)
    case levelSupport(LevelPayload)
    case levelResistance(LevelPayload)
    case drawingTrendline(TrendlinePayload)
    case drawingHorizontalLine(HorizontalLinePayload)
    case drawingZone(ZonePayload)
    case indicator(IndicatorPayload)
    case note(NotePayload)
    case link(LinkPayload)
    case reactionEmoji(EmojiPayload)
    case timeframeLink(TimeframeLinkPayload)
    case unknown(type: String, rawPayload: [String: AnyCodable])

    static func decode(componentType: String, rawPayload: [String: AnyCodable]) -> MarkerComponentPayload {
        func decodePayload<T: Decodable>(_ type: T.Type) -> T? {
            guard let data = try? JSONEncoder().encode(rawPayload) else { return nil }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date string: \(dateString)"
                )
            }
            return try? decoder.decode(type, from: data)
        }

        switch componentType {
        case RLComponentType.anchor.rawValue:
            if let payload = decodePayload(AnchorPayload.self) { return .anchor(payload) }
        case RLComponentType.levelEntry.rawValue:
            if let payload = decodePayload(LevelPayload.self) { return .levelEntry(payload) }
        case RLComponentType.levelSl.rawValue:
            if let payload = decodePayload(LevelPayload.self) { return .levelSl(payload) }
        case RLComponentType.levelTp.rawValue:
            if let payload = decodePayload(LevelPayload.self) { return .levelTp(payload) }
        case RLComponentType.levelSupport.rawValue:
            if let payload = decodePayload(LevelPayload.self) { return .levelSupport(payload) }
        case RLComponentType.levelResistance.rawValue:
            if let payload = decodePayload(LevelPayload.self) { return .levelResistance(payload) }
        case RLComponentType.drawingTrendline.rawValue:
            if let payload = decodePayload(TrendlinePayload.self) { return .drawingTrendline(payload) }
        case RLComponentType.drawingHorizontalLine.rawValue:
            if let payload = decodePayload(HorizontalLinePayload.self) { return .drawingHorizontalLine(payload) }
        case RLComponentType.drawingZone.rawValue:
            if let payload = decodePayload(ZonePayload.self) { return .drawingZone(payload) }
        case RLComponentType.indicator.rawValue:
            if let payload = decodePayload(IndicatorPayload.self) { return .indicator(payload) }
        case RLComponentType.textNote.rawValue:
            if let payload = decodePayload(NotePayload.self) { return .note(payload) }
        case RLComponentType.linkURL.rawValue:
            if let payload = decodePayload(LinkPayload.self) { return .link(payload) }
        case RLComponentType.reactionEmoji.rawValue:
            if let payload = decodePayload(EmojiPayload.self) { return .reactionEmoji(payload) }
        case RLComponentType.timeframeLink.rawValue:
            if let payload = decodePayload(TimeframeLinkPayload.self) { return .timeframeLink(payload) }
        default:
            break
        }

        return .unknown(type: componentType, rawPayload: rawPayload)
    }

    var rawPayload: [String: AnyCodable] {
        func encodePayload<T: Encodable>(_ value: T) -> [String: AnyCodable] {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            encoder.dateEncodingStrategy = .iso8601
            guard
                let data = try? encoder.encode(value),
                let encoded = try? JSONDecoder().decode([String: AnyCodable].self, from: data)
            else {
                return [:]
            }
            return encoded
        }

        switch self {
        case .anchor(let payload): return encodePayload(payload)
        case .levelEntry(let payload): return encodePayload(payload)
        case .levelSl(let payload): return encodePayload(payload)
        case .levelTp(let payload): return encodePayload(payload)
        case .levelSupport(let payload): return encodePayload(payload)
        case .levelResistance(let payload): return encodePayload(payload)
        case .drawingTrendline(let payload): return encodePayload(payload)
        case .drawingHorizontalLine(let payload): return encodePayload(payload)
        case .drawingZone(let payload): return encodePayload(payload)
        case .indicator(let payload): return encodePayload(payload)
        case .note(let payload): return encodePayload(payload)
        case .link(let payload): return encodePayload(payload)
        case .reactionEmoji(let payload): return encodePayload(payload)
        case .timeframeLink(let payload): return encodePayload(payload)
        case .unknown(_, let rawPayload): return rawPayload
        }
    }
}

extension MarkerComponentPayload {
    var levelPrice: Double? {
        switch self {
        case .levelEntry(let payload): return payload.price
        case .levelSl(let payload): return payload.price
        case .levelTp(let payload): return payload.price
        case .levelSupport(let payload): return payload.price
        case .levelResistance(let payload): return payload.price
        case .drawingHorizontalLine(let payload): return payload.price
        case .anchor(let payload): return payload.price
        default: return nil
        }
    }

    var anchorTime: Date? {
        if case let .anchor(payload) = self {
            return payload.time
        }
        return nil
    }

    var indicatorName: String? {
        if case let .indicator(payload) = self {
            return payload.name
        }
        return nil
    }

    var emojiValue: String? {
        if case let .reactionEmoji(payload) = self {
            return payload.emoji
        }
        return nil
    }

    var drawingColorHex: String? {
        switch self {
        case .levelEntry(let payload),
             .levelSl(let payload),
             .levelTp(let payload),
             .levelSupport(let payload),
             .levelResistance(let payload):
            return payload.colorHex
        case .drawingTrendline(let payload):
            return payload.colorHex
        case .drawingHorizontalLine(let payload):
            return payload.colorHex
        case .drawingZone(let payload):
            return payload.colorHex
        default:
            return nil
        }
    }

    var drawingLineStyle: MarkerDrawingLineStyle? {
        switch self {
        case .levelEntry(let payload),
             .levelSl(let payload),
             .levelTp(let payload),
             .levelSupport(let payload),
             .levelResistance(let payload):
            return payload.lineStyle
        case .drawingTrendline(let payload):
            return payload.lineStyle
        case .drawingHorizontalLine(let payload):
            return payload.lineStyle
        case .drawingZone(let payload):
            return payload.lineStyle
        default:
            return nil
        }
    }

    var drawingLineWidth: Double? {
        switch self {
        case .levelEntry(let payload),
             .levelSl(let payload),
             .levelTp(let payload),
             .levelSupport(let payload),
             .levelResistance(let payload):
            return payload.lineWidth
        case .drawingTrendline(let payload):
            return payload.lineWidth
        case .drawingHorizontalLine(let payload):
            return payload.lineWidth
        case .drawingZone(let payload):
            return payload.lineWidth
        default:
            return nil
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
    let isMarketOpen: Bool?
    let marketStatusUpdatedAt: Date?
    let activityBadges: [String]?
    
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

    var providerDisplayLabel: String {
        (activeProviderDisplayName ?? exchange ?? "MARKET").uppercased()
    }

    var effectiveIsMarketOpen: Bool {
        isMarketOpen ?? false
    }

    var activityBadgeValues: [String] {
        activityBadges ?? []
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
    var isGapFill: Bool = false

    enum CodingKeys: String, CodingKey {
        case timestamp
        case timestampFormatted
        case open
        case high
        case low
        case close
        case volume
        case volumeFormatted
        case isGapFill
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        timestampFormatted = try container.decodeIfPresent(String.self, forKey: .timestampFormatted)
        open = try container.decode(Double.self, forKey: .open)
        high = try container.decode(Double.self, forKey: .high)
        low = try container.decode(Double.self, forKey: .low)
        close = try container.decode(Double.self, forKey: .close)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)
        volumeFormatted = try container.decodeIfPresent(String.self, forKey: .volumeFormatted)
        isGapFill = try container.decodeIfPresent(Bool.self, forKey: .isGapFill) ?? false
    }

    init(
        timestamp: Date,
        timestampFormatted: String?,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double?,
        volumeFormatted: String?,
        isGapFill: Bool = false
    ) {
        self.timestamp = timestamp
        self.timestampFormatted = timestampFormatted
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.volumeFormatted = volumeFormatted
        self.isGapFill = isGapFill
    }
    
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
    let replyPreview: RLMessageReplyPreviewDTO?
    var reactions: [RLMessageReactionDTO]

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
        attachmentName: String? = nil,
        replyPreview: RLMessageReplyPreviewDTO? = nil,
        reactions: [RLMessageReactionDTO] = []
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
        self.replyPreview = replyPreview
        self.reactions = reactions
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RLMarkerCommentDTO, rhs: RLMarkerCommentDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited &&
        lhs.replyPreview == rhs.replyPreview &&
        lhs.reactions == rhs.reactions
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
        case replyPreview, reactions
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
        replyPreview = try container.decodeIfPresent(RLMessageReplyPreviewDTO.self, forKey: .replyPreview)
        reactions = try container.decodeIfPresent([RLMessageReactionDTO].self, forKey: .reactions) ?? []

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
        try container.encodeIfPresent(replyPreview, forKey: .replyPreview)
        try container.encode(reactions, forKey: .reactions)
    }
}


// =============================================================================
// MARK: - Chart Marker
// =============================================================================

/// Full chart marker with engagement data and permissions
/// Backend: ChartMarkerResponse
// MARK: - Prediction Result

struct RLPredictionResultDTO: Codable, Equatable {
    let resultType: String       // "take_profit" or "stop_loss"
    let triggerPrice: Double
    let triggeredAt: Date
    let triggeredAtFormatted: String
    let pnl: Double?

    var isWin: Bool { resultType == "take_profit" }
    var displayLabel: String { isWin ? "TP Hit" : "SL Hit" }
}

// MARK: - Chart Marker

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
    let intent: String
    let title: String?
    let note: String?
    let visibility: String
    let confidence: Int?
    let trackingEnabled: Bool
    let trackingState: String?
    let alertSeverity: String?
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
    
    // Components
    let components: [RLMarkerComponentDTO]
    let primaryComponentId: UUID?

    // Poll
    let pollQuestion: String?
    let pollOptions: [RLPollOptionDTO]?
    let userPollVote: UUID?

    // Prediction outcome (tracked setups only)
    let predictionResult: RLPredictionResultDTO?

    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLChartMarkerDTO, rhs: RLChartMarkerDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.likeCount == rhs.likeCount &&
        lhs.commentCount == rhs.commentCount &&
        lhs.isVisible == rhs.isVisible &&
        lhs.trackingState == rhs.trackingState &&
        lhs.predictionResult == rhs.predictionResult
    }
    
    // MARK: - Convenience
    
    /// Whether this marker has a horizontal price line
    var hasHorizontalLine: Bool {
        !levelComponents.isEmpty
    }
    
    /// Whether this is a poll marker
    var isPoll: Bool {
        intent == RLMarkerIntent.poll.rawValue
    }

    var intentEnum: RLMarkerIntent {
        RLMarkerIntent(rawValue: intent) ?? .analysis
    }

    var trackingStateEnum: RLTrackingState? {
        trackingState.flatMap { RLTrackingState(rawValue: $0) }
    }

    var levelComponents: [RLMarkerComponentDTO] {
        components.filter { $0.componentTypeEnum?.isLevel == true }
    }

    var anchorComponent: RLMarkerComponentDTO? {
        components.first { $0.componentType == RLComponentType.anchor.rawValue }
    }

    var horizontalLinePrice: Double? {
        levelComponents.first?.payload.levelPrice
    }

    var entryPrice: Double? {
        components.first { $0.componentType == RLComponentType.levelEntry.rawValue }?.payload.levelPrice
    }

    var stopLossPrice: Double? {
        components.first { $0.componentType == RLComponentType.levelSl.rawValue }?.payload.levelPrice
    }

    var targetPrice: Double? {
        components.first { $0.componentType == RLComponentType.levelTp.rawValue }?.payload.levelPrice
    }

    var selectedEmoji: String? {
        components.first { $0.componentType == RLComponentType.reactionEmoji.rawValue }?.payload.emojiValue
    }

    var selectedIndicator: String? {
        components.first { $0.componentType == RLComponentType.indicator.rawValue }?.payload.indicatorName
    }
    var trendlineDirection: String? { nil }
    var chartPattern: String? { nil }
}

struct RLMarkerComponentDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let componentType: String
    let payload: MarkerComponentPayload
    let ordering: Int

    var componentTypeEnum: RLComponentType? {
        RLComponentType(rawValue: componentType)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case componentType
        case payload
        case ordering
    }

    init(id: UUID, componentType: String, payload: MarkerComponentPayload, ordering: Int) {
        self.id = id
        self.componentType = componentType
        self.payload = payload
        self.ordering = ordering
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        componentType = try container.decode(String.self, forKey: .componentType)
        ordering = try container.decode(Int.self, forKey: .ordering)
        let rawPayload = try container.decode([String: AnyCodable].self, forKey: .payload)
        payload = MarkerComponentPayload.decode(componentType: componentType, rawPayload: rawPayload)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(componentType, forKey: .componentType)
        try container.encode(ordering, forKey: .ordering)
        try container.encode(payload.rawPayload, forKey: .payload)
    }

    static func == (lhs: RLMarkerComponentDTO, rhs: RLMarkerComponentDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.componentType == rhs.componentType &&
        lhs.ordering == rhs.ordering &&
        payloadFingerprint(lhs.payload) == payloadFingerprint(rhs.payload)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(componentType)
        hasher.combine(ordering)
        hasher.combine(Self.payloadFingerprint(payload))
    }

    private static func payloadFingerprint(_ payload: MarkerComponentPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard
            let data = try? encoder.encode(payload.rawPayload),
            let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return value
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
    let intent: String
    let title: String?
    let notePreview: String?
    let createdAt: Date
    let createdAtFormatted: String
    
    // Chart position
    let candleTimestamp: Date
    let timeframe: String
    let price: Double
    let setupSummary: RLSetupSummaryDTO?
    
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

    var intentEnum: RLMarkerIntent { RLMarkerIntent(rawValue: intent) ?? .analysis }
}

struct RLSetupSummaryDTO: Codable, Hashable {
    let entryPrice: Double?
    let slPrice: Double?
    let tpPrice: Double?
    let trackingState: String?
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
    let replyPreview: RLMessageReplyPreviewDTO?
    var reactions: [RLMessageReactionDTO]

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
        lhs.isEdited == rhs.isEdited &&
        lhs.replyPreview == rhs.replyPreview &&
        lhs.reactions == rhs.reactions
    }
    
    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, chatId, author, content
        case timestamp
        case createdAt
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
        case attachmentUrl, attachmentType, attachmentName
        case replyPreview, reactions
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
        replyPreview = try container.decodeIfPresent(RLMessageReplyPreviewDTO.self, forKey: .replyPreview)
        reactions = try container.decodeIfPresent([RLMessageReactionDTO].self, forKey: .reactions) ?? []

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
        try container.encodeIfPresent(replyPreview, forKey: .replyPreview)
        try container.encode(reactions, forKey: .reactions)
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
    let timeframe: String
    let intent: String
    let title: String?
    let note: String?
    let visibility: String
    let confidence: Int?
    let trackingEnabled: Bool
    let components: [RLMarkerComponentRequest]
    let pollQuestion: String?
    let pollOptions: [String]?

    enum CodingKeys: String, CodingKey {
        case symbolId = "symbol_id"
        case timeframe
        case intent
        case title
        case note
        case visibility
        case confidence
        case trackingEnabled = "tracking_enabled"
        case components
        case pollQuestion = "poll_question"
        case pollOptions = "poll_options"
    }
}

/// Update a chart marker
/// Backend: UpdateMarkerRequest
struct RLUpdateMarkerRequest: Codable {
    let intent: String?
    let title: String?
    let note: String?
    let visibility: String?
    let confidence: Int?
    let trackingEnabled: Bool?
    let components: [RLMarkerComponentRequest]?
    // Local-only fields for optimistic reconciliation when server payload omits poll values.
    let pollQuestion: String?
    let pollOptions: [String]?

    init(
        intent: String? = nil,
        title: String? = nil,
        note: String? = nil,
        visibility: String? = nil,
        confidence: Int? = nil,
        trackingEnabled: Bool? = nil,
        components: [RLMarkerComponentRequest]? = nil,
        pollQuestion: String? = nil,
        pollOptions: [String]? = nil
    ) {
        self.intent = intent
        self.title = title
        self.note = note
        self.visibility = visibility
        self.confidence = confidence
        self.trackingEnabled = trackingEnabled
        self.components = components
        self.pollQuestion = pollQuestion
        self.pollOptions = pollOptions
    }
    
    enum CodingKeys: String, CodingKey {
        case intent
        case title
        case note
        case visibility
        case confidence
        case trackingEnabled = "tracking_enabled"
        case components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = try container.decodeIfPresent(String.self, forKey: .intent)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        confidence = try container.decodeIfPresent(Int.self, forKey: .confidence)
        trackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .trackingEnabled)
        components = try container.decodeIfPresent([RLMarkerComponentRequest].self, forKey: .components)
        pollQuestion = nil
        pollOptions = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(trackingEnabled, forKey: .trackingEnabled)
        try container.encodeIfPresent(components, forKey: .components)
    }
}

struct RLMarkerComponentRequest: Codable {
    let componentType: String
    let payload: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case componentType = "component_type"
        case payload
    }
}

/// Create marker comment
/// Backend: CreateMarkerCommentRequest
struct RLCreateMarkerCommentRequest: Codable {
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    let replyToMessageId: UUID?

    init(
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        replyToMessageId: UUID? = nil
    ) {
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.replyToMessageId = replyToMessageId
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
    let replyToMessageId: UUID?

    init(
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        replyToMessageId: UUID? = nil
    ) {
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.replyToMessageId = replyToMessageId
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
    let eventType: String
    let guildId: UUID
    let symbolId: UUID
    let marker: RLChartMarkerDTO?
    let markerId: UUID?
    let likeCount: Int?
    let commentCount: Int?
    let actorId: UUID?
    let oldTrackingState: String?
    let newTrackingState: String?
}

struct MarkerTrackingStateChangedPayload: Codable {
    let markerId: String
    let oldState: String?
    let newState: String?
    let guildId: String
    let symbolId: String
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
        isSupportedByActiveProvider: true,
        isMarketOpen: true,
        marketStatusUpdatedAt: Date(),
        activityBadges: ["Trending", "Hot"]
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
        isSupportedByActiveProvider: true,
        isMarketOpen: false,
        marketStatusUpdatedAt: Date(),
        activityBadges: ["New Markers"]
    )
}
#endif
