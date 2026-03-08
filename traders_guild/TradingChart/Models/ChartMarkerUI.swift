//
//  ChartMarkerUI.swift
//  traders_guild
//
//  UI wrapper for RLChartMarkerDTO (v2 intent/components) with chart-specific layout state.
//

import Foundation
import SwiftUI

struct ChartMarkerUI: Identifiable, Hashable {
    var marker: RLChartMarkerDTO
    
    // Layout state (computed per chart view)
    var candleIndex: Int
    var positionedBelow: Bool = false
    var proximityTier: Int = 0
    var stackIndex: Int = 0
    var isVisible: Bool = true
    
    var id: UUID { marker.id }
    
    // MARK: - Convenience Accessors
    var symbolId: UUID { marker.symbolId }
    var guildId: UUID { marker.guildId }
    var author: RLGuildMemberDTO { marker.author }
    var candleTimestamp: Date { marker.candleTimestamp }
    var timeframe: String { marker.timeframe }
    var price: Double { marker.price }
    var intent: RLMarkerIntent { marker.intentEnum }
    var title: String? { marker.title }
    var note: String? { marker.note }
    var visibility: String { marker.visibility }
    var confidence: Int? { marker.confidence }
    var trackingEnabled: Bool { marker.trackingEnabled }
    var trackingState: RLTrackingState? { marker.trackingStateEnum }
    var createdAt: Date { marker.createdAt }
    var createdAtFormatted: String { marker.createdAtFormatted }
    var likeCount: Int { marker.likeCount }
    var isLikedByCurrentUser: Bool { marker.isLikedByCurrentUser }
    var commentCount: Int { marker.commentCount }
    var comments: [RLMarkerCommentDTO] { marker.comments }
    var isCurrentUserMarker: Bool { marker.isCurrentUserMarker }
    var canEdit: Bool { marker.canEdit }
    var canDelete: Bool { marker.canDelete }
    var components: [RLMarkerComponentDTO] { marker.components }
    var anchorComponent: RLMarkerComponentDTO? { marker.anchorComponent }
    var levelComponents: [RLMarkerComponentDTO] { marker.levelComponents }
    var drawingComponents: [RLMarkerComponentDTO] {
        marker.components.filter { $0.componentTypeEnum?.isDrawing == true }
    }
    var indicatorComponents: [RLMarkerComponentDTO] {
        marker.components.filter { $0.componentTypeEnum == .indicator }
    }
    var linkComponents: [RLMarkerComponentDTO] {
        marker.components.filter { $0.componentTypeEnum == .linkURL || $0.componentTypeEnum == .timeframeLink }
    }
    var entryLevel: RLMarkerComponentDTO? {
        marker.components.first { $0.componentTypeEnum == .levelEntry }
    }
    var slLevel: RLMarkerComponentDTO? {
        marker.components.first { $0.componentTypeEnum == .levelSl }
    }
    var tpLevel: RLMarkerComponentDTO? {
        marker.components.first { $0.componentTypeEnum == .levelTp }
    }
    var hasHorizontalLine: Bool { marker.hasHorizontalLine }
    var entryPrice: Double? { marker.entryPrice }
    var targetPrice: Double? { marker.targetPrice }
    var stopLossPrice: Double? { marker.stopLossPrice }
    var horizontalLinePrice: Double? { marker.horizontalLinePrice }
    var horizontalLineLabel: String {
        if components.contains(where: { $0.componentType == RLComponentType.levelEntry.rawValue }) {
            return "Entry"
        }
        if components.contains(where: { $0.componentType == RLComponentType.levelTp.rawValue }) {
            return "TP"
        }
        if components.contains(where: { $0.componentType == RLComponentType.levelSl.rawValue }) {
            return "SL"
        }
        if components.contains(where: { $0.componentType == RLComponentType.levelSupport.rawValue }) {
            return "Support"
        }
        if components.contains(where: { $0.componentType == RLComponentType.levelResistance.rawValue }) {
            return "Resist"
        }
        return ""
    }
    var alertSeverity: MarkerAlertSeverity? {
        if let backendSeverity = marker.alertSeverity,
           let resolved = MarkerAlertSeverity.fromBackendString(backendSeverity) {
            return resolved
        }

        let trimmedNote = marker.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedNote.hasPrefix("[Critical] ") { return .critical }
        if trimmedNote.hasPrefix("[Severe] ") { return .severe }
        if trimmedNote.hasPrefix("[Warning] ") { return .moderate }
        if trimmedNote.hasPrefix("[Informational] ") { return .mild }
        return nil
    }
    var trendlineDirection: TrendlineDirection? {
        marker.trendlineDirection.flatMap { TrendlineDirection.fromBackendString($0) }
    }
    var selectedIndicator: String? { marker.selectedIndicator }
    var chartPattern: ChartPattern? {
        marker.chartPattern.flatMap { ChartPattern.fromBackendString($0) }
    }
    var selectedEmoji: String? { marker.selectedEmoji }
    var pollQuestion: String? { marker.pollQuestion }
    var pollOptions: [RLPollOptionDTO]? { marker.pollOptions }
    var userPollVote: UUID? { marker.userPollVote }
    var totalPollVotes: Int {
        pollOptions?.reduce(0) { $0 + $1.voteCount } ?? 0
    }

    /// Effective color for rendering: intent-first, alert severity override if present.
    var displayColor: Color {
        if intent == .alert, let severity = alertSeverity { return severity.color }
        return intent.color
    }

    var displayIcon: String {
        intent.icon
    }
    
    init(marker: RLChartMarkerDTO, candleIndex: Int) {
        self.marker = marker
        self.candleIndex = candleIndex
        self.isVisible = marker.isVisible
    }
    
    func withMarker(_ newMarker: RLChartMarkerDTO) -> ChartMarkerUI {
        var updated = self
        updated.marker = newMarker
        return updated
    }
    
    /// Calculate the horizontal line price for a marker based on its line source.
    /// Returns nil when the marker type does not use a horizontal line.
    func linePrice(for candle: RLCandleDTO) -> Double? {
        if let linePrice = horizontalLinePrice {
            return linePrice
        }

        if let entryPrice {
            return entryPrice
        }
        if let targetPrice {
            return targetPrice
        }
        if let stopLossPrice {
            return stopLossPrice
        }

        return anchorComponent?.payload.levelPrice ?? marker.price
    }
}

extension RLChartMarkerDTO {
    func updating(
        intent: String? = nil,
        title: String? = nil,
        note: String? = nil,
        visibility: String? = nil,
        confidence: Int? = nil,
        trackingEnabled: Bool? = nil,
        trackingState: String? = nil,
        components: [RLMarkerComponentDTO]? = nil,
        isVisible: Bool? = nil,
        likeCount: Int? = nil,
        isLikedByCurrentUser: Bool? = nil,
        comments: [RLMarkerCommentDTO]? = nil,
        commentCount: Int? = nil,
        pollOptions: [RLPollOptionDTO]? = nil,
        userPollVote: UUID? = nil
    ) -> RLChartMarkerDTO {
        guard var dict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any] else {
            return self
        }
        if let intent = intent { dict["intent"] = intent }
        if let title = title { dict["title"] = title }
        if let note = note { dict["note"] = note }
        if let visibility = visibility { dict["visibility"] = visibility }
        if let confidence = confidence { dict["confidence"] = confidence }
        if let trackingEnabled = trackingEnabled { dict["trackingEnabled"] = trackingEnabled }
        if let trackingState = trackingState { dict["trackingState"] = trackingState }
        if let components = components,
           let componentsData = try? JSONEncoder().encode(components),
           let componentsArray = try? JSONSerialization.jsonObject(with: componentsData) {
            dict["components"] = componentsArray
        }
        if let isVisible = isVisible { dict["isVisible"] = isVisible }
        if let likeCount = likeCount { dict["likeCount"] = likeCount }
        if let isLikedByCurrentUser = isLikedByCurrentUser { dict["isLikedByCurrentUser"] = isLikedByCurrentUser }
        if let comments = comments,
           let commentsData = try? JSONEncoder().encode(comments),
           let commentsArray = try? JSONSerialization.jsonObject(with: commentsData) {
            dict["comments"] = commentsArray
        }
        if let commentCount = commentCount { dict["commentCount"] = commentCount }
        if let pollOptions = pollOptions,
           let pollOptionsData = try? JSONEncoder().encode(pollOptions),
           let pollOptionsArray = try? JSONSerialization.jsonObject(with: pollOptionsData) {
            dict["pollOptions"] = pollOptionsArray
        }
        if let userPollVote = userPollVote { dict["userPollVote"] = userPollVote.uuidString }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLChartMarkerDTO.self, from: data) else {
            return self
        }
        return updated
    }
}
