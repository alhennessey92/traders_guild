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
    /// True once this marker has been assigned a slot in the current chart
    /// session. Re-layout preserves that slot until its anchor timestamp changes.
    var hasStableLayout: Bool = false
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
    var predictionResult: RLPredictionResultDTO? { marker.predictionResult }
    var createdAt: Date { marker.createdAt }
    var createdAtFormatted: String { marker.createdAtFormatted }
    var likeCount: Int { marker.likeCount }
    var isLikedByCurrentUser: Bool { marker.isLikedByCurrentUser }
    var commentCount: Int { marker.commentCount }
    var comments: [RLMarkerCommentDTO] { marker.comments }
    var isCurrentUserMarker: Bool { marker.isCurrentUserMarker }
    var canEdit: Bool { marker.canEdit }
    var canDelete: Bool { marker.canDelete }
    var isEditableByCurrentUser: Bool { isCurrentUserMarker && canEdit }
    var canOpenEditFlow: Bool { canEdit || isCurrentUserMarker }
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
        if let lineComponent = components.first(where: { $0.componentType == RLComponentType.drawingHorizontalLine.rawValue }),
           case let .drawingHorizontalLine(payload) = lineComponent.payload {
            let trimmed = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "Line" : trimmed
        }
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
    var resolvedPollQuestion: String? {
        func normalized(_ value: String?) -> String? {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }

        func extractFromUnknownPayload(_ payload: [String: AnyCodable]) -> String? {
            let keys = ["poll_question", "question", "prompt", "text", "title"]
            for key in keys {
                if let value = payload[key]?.value as? String,
                   let normalized = normalized(value) {
                    return normalized
                }
            }
            return nil
        }

        let componentPollText: String? = marker.components.first { $0.componentTypeEnum == .textNote }
            .flatMap { component in
                guard case let .note(payload) = component.payload else { return nil }
                return payload.text
            }
        let unknownComponentPollText: String? = marker.components.compactMap { component in
            guard case let .unknown(_, rawPayload) = component.payload else { return nil }
            return extractFromUnknownPayload(rawPayload)
        }.first
        let candidates: [String?] = [
            marker.pollQuestion,
            componentPollText,
            unknownComponentPollText,
            marker.note,
            marker.title,
        ]
        for candidate in candidates {
            if let normalized = normalized(candidate) {
                return normalized
            }
        }
        return nil
    }
    var pollOptions: [RLPollOptionDTO]? { marker.pollOptions }
    var userPollVote: UUID? { marker.userPollVote }

    // MARK: - Linked markers

    var parentMarkerId: UUID? { marker.parentMarkerId }
    var linkRelationship: MarkerLinkRelationshipValue? { marker.linkRelationshipValue }
    var parentPreview: RLMarkerLinkPreviewDTO? { marker.parentPreview }
    var responseCount: Int { marker.responseCount }
    var responsesRevision: String? { marker.responsesRevision }
    var responsesRevisionValue: MarkerRevision? { marker.responsesRevisionValue }
    var isLinkedResponse: Bool { marker.isLinkedResponse }
    var isDetachedResponse: Bool { marker.isDetachedResponse }
    var hasAnyResponses: Bool { marker.hasAnyResponses }
    var participatesInThesis: Bool { marker.participatesInThesis }
    var hasUnavailableParent: Bool { marker.hasUnavailableParent }

    /// Topology projection used by `MarkerLinkGraph`. Keeping the conversion
    /// here means the graph never needs to know about chart wrappers.
    var linkNode: MarkerLinkNode {
        MarkerLinkNode(
            id: id,
            parentId: marker.parentMarkerId,
            relationship: marker.linkRelationshipValue,
            directResponseCount: marker.responseCount
        )
    }
    var totalPollVotes: Int {
        pollOptions?.reduce(0) { $0 + $1.voteCount } ?? 0
    }

    /// Effective color for rendering: intent-first, alert severity override if present.
    var displayColor: Color {
        if intent == .alert, let severity = alertSeverity { return severity.color }
        return intent.color
    }

    var displayIcon: String {
        intent.markerSymbol(for: alertSeverity)
    }
    
    init(marker: RLChartMarkerDTO, candleIndex: Int) {
        self.marker = marker.normalizedAnnotationAnchors()
        self.candleIndex = candleIndex
        self.isVisible = marker.isVisible
    }

    func withMarker(_ newMarker: RLChartMarkerDTO) -> ChartMarkerUI {
        var updated = self
        let anchorChanged = updated.candleTimestamp != newMarker.candleTimestamp
        updated.marker = newMarker.normalizedAnnotationAnchors()
        if anchorChanged {
            updated.hasStableLayout = false
        }
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
    func normalizedAnnotationAnchors() -> RLChartMarkerDTO {
        let fallbackAnchorTime = anchorComponent?.payload.anchorTime ?? candleTimestamp
        let fallbackAnchorPrice = anchorComponent?.payload.levelPrice ?? price

        let normalizedComponents = components.map { component in
            switch component.payload {
            case let .note(payload):
                guard payload.anchorTime == nil || payload.anchorPrice == nil else { return component }
                return RLMarkerComponentDTO(
                    id: component.id,
                    componentType: component.componentType,
                    payload: .note(
                        NotePayload(
                            text: payload.text,
                            offsetX: payload.offsetX,
                            offsetY: payload.offsetY,
                            anchorTime: payload.anchorTime ?? fallbackAnchorTime,
                            anchorPrice: payload.anchorPrice ?? fallbackAnchorPrice,
                            fontSize: payload.fontSize,
                            colorHex: payload.colorHex
                        )
                    ),
                    ordering: component.ordering
                )

            case let .reactionEmoji(payload):
                guard payload.anchorTime == nil || payload.anchorPrice == nil else { return component }
                return RLMarkerComponentDTO(
                    id: component.id,
                    componentType: component.componentType,
                    payload: .reactionEmoji(
                        EmojiPayload(
                            emoji: payload.emoji,
                            offsetX: payload.offsetX,
                            offsetY: payload.offsetY,
                            anchorTime: payload.anchorTime ?? fallbackAnchorTime,
                            anchorPrice: payload.anchorPrice ?? fallbackAnchorPrice,
                            scale: payload.scale
                        )
                    ),
                    ordering: component.ordering
                )

            default:
                return component
            }
        }

        guard normalizedComponents != components else { return self }
        return updating(components: normalizedComponents)
    }

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
        pollQuestion: String? = nil,
        pollOptions: [RLPollOptionDTO]? = nil,
        userPollVote: UUID? = nil,
        directResponseCount: Int? = nil,
        responsesRevision: String? = nil,
        hasResponses: Bool? = nil,
        isCurrentUserMarker: Bool? = nil,
        canEdit: Bool? = nil,
        canDelete: Bool? = nil,
        parentPreview: RLMarkerLinkPreviewDTO? = nil
    ) -> RLChartMarkerDTO {
        guard var dict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any] else {
            return self
        }
        if let parentPreview,
           let encoded = try? JSONEncoder().encode(parentPreview),
           let previewDict = try? JSONSerialization.jsonObject(with: encoded) {
            dict["parentPreview"] = previewDict
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
        if let pollQuestion = pollQuestion { dict["pollQuestion"] = pollQuestion }
        if let pollOptions = pollOptions,
           let pollOptionsData = try? JSONEncoder().encode(pollOptions),
           let pollOptionsArray = try? JSONSerialization.jsonObject(with: pollOptionsData) {
            dict["pollOptions"] = pollOptionsArray
        }
        if let userPollVote = userPollVote { dict["userPollVote"] = userPollVote.uuidString }
        if let directResponseCount = directResponseCount {
            dict["directResponseCount"] = directResponseCount
        }
        // Stored verbatim as the wire string. Encoding it as a date here would
        // reintroduce exactly the millisecond rounding MarkerRevision exists to
        // avoid, silently collapsing microsecond-separated revisions.
        if let responsesRevision = responsesRevision {
            dict["responsesRevision"] = responsesRevision
        }
        // Structural, and deliberately writable independently of the count: a
        // soft delete drops the count to zero and leaves this true.
        if let hasResponses = hasResponses {
            dict["hasResponses"] = hasResponses
        }
        // Viewer-relative permissions. A broadcast payload carries whoever
        // created it, so these are re-derived locally rather than adopted.
        if let isCurrentUserMarker = isCurrentUserMarker {
            dict["isCurrentUserMarker"] = isCurrentUserMarker
        }
        if let canEdit = canEdit { dict["canEdit"] = canEdit }
        if let canDelete = canDelete { dict["canDelete"] = canDelete }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLChartMarkerDTO.self, from: data) else {
            return self
        }
        return updated
    }

    /// This marker's parent is gone: the same DTO with its parent preview
    /// turned into a tombstone.
    ///
    /// A deletion event only names the deleted marker; a loaded child would
    /// otherwise keep the navigable preview it was hydrated with, and its
    /// "Open parent" row would still try — and reach a 404. The tombstone
    /// keeps the link relationship and the parent id (a soft delete leaves the
    /// row), drops every navigation field, and marks itself unavailable, which
    /// is exactly the shape the server sends for a parent it will not show.
    func withUnavailableParent() -> RLChartMarkerDTO {
        guard parentMarkerId != nil || linkRelationship != nil else { return self }
        let existing = parentPreview
        let tombstone = RLMarkerLinkPreviewDTO(
            nodeKey: existing?.nodeKey ?? "tombstone:\(parentMarkerId?.uuidString ?? id.uuidString)",
            parentKey: existing?.parentKey,
            parentMarkerId: existing?.parentMarkerId,
            linkRelationship: existing?.linkRelationship,
            isUnavailable: true,
            directResponseCount: existing?.directResponseCount ?? 0,
            depth: existing?.depth ?? 0
        )
        return updating(parentPreview: tombstone)
    }
}
