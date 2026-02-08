//
//  ChartMarkerUI.swift
//  traders_guild
//
//  UI wrapper for RLChartMarkerDTO with chart-specific layout state.
//

import Foundation

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
    var type: RLMarkerType { marker.markerTypeEnum }
    var note: String? { marker.note }
    var createdAt: Date { marker.createdAt }
    var createdAtFormatted: String { marker.createdAtFormatted }
    var likeCount: Int { marker.likeCount }
    var isLikedByCurrentUser: Bool { marker.isLikedByCurrentUser }
    var commentCount: Int { marker.commentCount }
    var comments: [RLMarkerCommentDTO] { marker.comments }
    var isCurrentUserMarker: Bool { marker.isCurrentUserMarker }
    var canEdit: Bool { marker.canEdit }
    var canDelete: Bool { marker.canDelete }
    var horizontalLinePrice: Double? { marker.horizontalLinePrice }
    var targetPrice: Double? { marker.targetPrice }
    var alertSeverity: MarkerAlertSeverity? {
        marker.alertSeverity.flatMap { MarkerAlertSeverity.fromBackendString($0) }
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
        switch type.lineSource {
        case .candleOpen:
            return candle.open
        case .candleClose:
            return candle.close
        case .candleHigh:
            return candle.high
        case .candleLow:
            return candle.low
        case .custom:
            return horizontalLinePrice
        case .none:
            return nil
        }
    }
}

extension RLChartMarkerDTO {
    var markerTypeEnum: RLMarkerType {
        RLMarkerType.fromBackendString(markerType) ?? .note
    }
    
    func updating(
        note: String? = nil,
        isVisible: Bool? = nil,
        likeCount: Int? = nil,
        isLikedByCurrentUser: Bool? = nil,
        comments: [RLMarkerCommentDTO]? = nil,
        commentCount: Int? = nil
    ) -> RLChartMarkerDTO {
        guard var dict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any] else {
            return self
        }
        if let note = note { dict["note"] = note }
        if let isVisible = isVisible { dict["isVisible"] = isVisible }
        if let likeCount = likeCount { dict["likeCount"] = likeCount }
        if let isLikedByCurrentUser = isLikedByCurrentUser { dict["isLikedByCurrentUser"] = isLikedByCurrentUser }
        if let comments = comments,
           let commentsData = try? JSONEncoder().encode(comments),
           let commentsArray = try? JSONSerialization.jsonObject(with: commentsData) {
            dict["comments"] = commentsArray
        }
        if let commentCount = commentCount { dict["commentCount"] = commentCount }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLChartMarkerDTO.self, from: data) else {
            return self
        }
        return updated
    }
}
