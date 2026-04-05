//
//  ChartMarkerSystem.swift
//  traders_guild
//
//  CONVERTED: Now uses ChartMarkerUI instead of ChartMarker
//  All marker operations use the DTO pattern with embedded author info
//
//  INCLUDES:
//  - MarkerManager (with backwards-compatible String init for TradingChartView)
//  - MarkerDisplaySettings
//  - MarkerPositionCalculator
//  - ChartMarkerSystem (static drawing and hit detection)
//  - MarkerView
//  - MarkerCreationSheet
//  - MarkerSettingsView

import SwiftUI
import Combine
import UIKit

enum MarkerVisibilityMode: String, CaseIterable, Identifiable {
    case off
    case all
    case mine
    case friends

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .all: return "All"
        case .mine: return "Mine"
        case .friends: return "Friends"
        }
    }
}

enum MarkerPlacementFailure: Equatable {
    case trackedSetupConflictSymbolTimeframe
    case trackedSetupLimitReached
    case genericCreateFailure
    case genericUpdateFailure

    var toastTitle: String {
        switch self {
        case .trackedSetupConflictSymbolTimeframe, .trackedSetupLimitReached:
            return "Setup Not Allowed"
        case .genericCreateFailure:
            return "Placement Failed"
        case .genericUpdateFailure:
            return "Save Failed"
        }
    }

    var toastSeverity: RLAlertSeverity {
        switch self {
        case .trackedSetupConflictSymbolTimeframe, .trackedSetupLimitReached:
            return .warning
        case .genericCreateFailure, .genericUpdateFailure:
            return .error
        }
    }

    var userMessage: String {
        switch self {
        case .trackedSetupConflictSymbolTimeframe:
            return "You already have an open tracked setup on this symbol and timeframe."
        case .trackedSetupLimitReached:
            return "You already have 10 open tracked setups in this guild."
        case .genericCreateFailure:
            return "Could not place marker. Try again."
        case .genericUpdateFailure:
            return "Could not save changes. Try again."
        }
    }

    static func from(error: Error, fallback: MarkerPlacementFailure) -> MarkerPlacementFailure {
        switch error {
        case APIError.badRequest(let detail), APIError.serverError(_, let detail):
            switch detail {
            case "tracked_setup_conflict_symbol_timeframe":
                return .trackedSetupConflictSymbolTimeframe
            case "tracked_setup_limit_reached":
                return .trackedSetupLimitReached
            default:
                return fallback
            }
        default:
            return fallback
        }
    }
}

enum MarkerPlacementSubmissionResult: Equatable {
    case success
    case failure(MarkerPlacementFailure)
}

protocol MarkerAPIClient: AnyObject {
    func getMarkers(
        guildId: UUID,
        symbolId: UUID,
        timeframe: String,
        limit: Int,
        cursor: String?,
        startTime: Date?,
        endTime: Date?
    ) async throws -> RLMarkersListDTO
    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO
    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO
    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLDetailResponseDTO
    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO
    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO
    func addMarkerComment(
        guildId: UUID,
        markerId: UUID,
        content: String,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO
    func toggleMarkerCommentReaction(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMarkerCommentDTO
    func getMarkerCommentReactionReactors(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO
    func deleteMarkerComment(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID
    ) async throws -> RLDetailResponseDTO
}

extension RealAPIService: MarkerAPIClient {}

private extension ChartMarkerUI {
    var isOpenTrackedSetup: Bool {
        intent == .setup && trackingEnabled && (trackingState == .armed || trackingState == .active)
    }
}

// MARK: - Marker Appearance Model

extension Color {
    /// Darker variant for borders (reduce luminance)
    func markerBorderVariant() -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let factor: CGFloat = 0.28
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
    /// Slightly lighter variant for icons (boost toward white, but darker than before)
    func markerIconVariant() -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let blend: CGFloat = 0.35
        return Color(red: r * (1 - blend) + blend, green: g * (1 - blend) + blend, blue: b * (1 - blend) + blend)
    }
    /// Dark gradient start for marker background
    func markerGradientStart() -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let factor: CGFloat = 0.1
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
    /// Dark gradient end for marker background
    func markerGradientEnd() -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let factor: CGFloat = 0.18
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
    /// Border gradient bright end (sits at bottom, opposite to fill) — type color at ~55%
    func markerBorderGradientStart() -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let factor: CGFloat = 0.55
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
    /// Border gradient dim end (sits at top, opposite to fill) — type color at ~25%
    func markerBorderGradientEnd() -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let factor: CGFloat = 0.25
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
    /// Blend toward white for glow/activity effects
    func blendedForGlow(brightness: CGFloat) -> Color {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard u.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let blend = min(max((brightness - 1.0) * 0.5, 0), 1.0)
        return Color(
            red: r + (1.0 - r) * blend,
            green: g + (1.0 - g) * blend,
            blue: b + (1.0 - b) * blend
        )
    }
}

// MARK: - Marker Manager

@MainActor
class MarkerManager: ObservableObject {
    enum PollVoteError: LocalizedError {
        case markerNotFound
        case invalidPoll
        case optionNotFound
        case apiUnavailable

        var errorDescription: String? {
            switch self {
            case .markerNotFound:
                return "Marker not found."
            case .invalidPoll:
                return "This marker is not a poll."
            case .optionNotFound:
                return "Selected poll option no longer exists."
            case .apiUnavailable:
                return "Poll voting is unavailable right now."
            }
        }
    }

    @Published var markers: [ChartMarkerUI] = []
    @Published var selectedMarker: ChartMarkerUI?
    @Published var visibleIntents: Set<RLMarkerIntent> = Set(RLMarkerIntent.allCases)
    @Published var visibilityMode: MarkerVisibilityMode = .all
    
    /// Tracks if we should show a "like existing marker" prompt
    @Published var duplicateMarkerToLike: ChartMarkerUI?
    @Published var showDuplicateAlert: Bool = false
    
    private var currentUserId: UUID
    private var currentGuildId: UUID
    private var currentUserMember: RLGuildMemberDTO
    
    /// API service for backend persistence
    private weak var api: (any MarkerAPIClient)?

    /// Current symbol ID for API calls
    private var currentSymbolId: UUID?

    /// Current timeframe for API calls
    private var currentTimeframe: RLChartTimeframe?

    /// Real-time marker channel subscription
    private var currentMarkerChannel: String?
    private var cancellables = Set<AnyCancellable>()
    private weak var dataManager: ChartDataManager?
    
    var guildId: UUID { currentGuildId }
    var userId: UUID { currentUserId }
    
    /// Configure MarkerManager with API service
    func configure(api: any MarkerAPIClient, symbolId: UUID, timeframe: RLChartTimeframe) {
        self.api = api
        self.currentSymbolId = symbolId
        self.currentTimeframe = timeframe
    }
    
    // MARK: - Initialization
    
    /// Initialize MarkerManager with required user and guild information
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - guildId: Current guild's ID
    ///   - userMembership: Current user's guild membership
    init(
        userId: UUID,
        guildId: UUID,
        currentUserMember: RLGuildMemberDTO
    ) {
        self.currentUserId = userId
        self.currentGuildId = guildId
        self.currentUserMember = currentUserMember
    }

    func updateContext(userId: UUID, guildId: UUID, currentUserMember: RLGuildMemberDTO) {
        self.currentUserId = userId
        self.currentGuildId = guildId
        self.currentUserMember = currentUserMember
    }

    private func canRenderMarker(_ marker: RLChartMarkerDTO) -> Bool {
        let visibility = marker.visibility.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return visibility != "private"
            || marker.author.userId == currentUserId
            || marker.isCurrentUserMarker
    }
    
    // MARK: - API Loading
    
    func loadMarkersFromAPI(
        api: any MarkerAPIClient,
        symbolId: UUID,
        symbol: String,
        guildId: UUID,
        timeframe: RLChartTimeframe,
        candles: [RLCandleDTO]
    ) async {
        // Configure MarkerManager with API for persistence
        configure(api: api, symbolId: symbolId, timeframe: timeframe)

        // Update guild context so marker create/delete/like use the correct guild
        self.currentGuildId = guildId
        
        do {
            // Fetch markers from RealAPIService (paged)
            let timeframeString = timeframe.toBackendString()
            let startTime = candles.first?.timestamp
            let endTime = candles.last?.timestamp
            var cursor: String?
            var pageCount = 0
            let maxPages = 10
            var fetchedMarkers: [RLChartMarkerDTO] = []

            repeat {
                let markersListDTO = try await api.getMarkers(
                    guildId: guildId,
                    symbolId: symbolId,
                    timeframe: timeframeString,
                    limit: 100,
                    cursor: cursor,
                    startTime: startTime,
                    endTime: endTime
                )
                fetchedMarkers.append(contentsOf: markersListDTO.markers)
                cursor = markersListDTO.nextCursor
                pageCount += 1

                if !markersListDTO.hasMore || cursor == nil {
                    break
                }
            } while pageCount < maxPages
            
            // Convert RLChartMarkerUI to ChartMarkerUI (UI model)
            var convertedMarkers: [ChartMarkerUI] = []
            for rlMarker in fetchedMarkers {
                guard canRenderMarker(rlMarker) else { continue }
                if let candleIndex = findCandleIndex(timestamp: rlMarker.candleTimestamp, in: candles) {
                    convertedMarkers.append(ChartMarkerUI(marker: rlMarker, candleIndex: candleIndex))
                }
            }
            
            // Update prices based on candle data (if needed)
            // Note: Prices should already be correct from backend, but verify alignment
            var positionedMarkers = convertedMarkers
            
            // Reset positioning fields for proper recalculation
            for i in 0..<positionedMarkers.count {
                positionedMarkers[i].positionedBelow = false
                positionedMarkers[i].proximityTier = 0
                positionedMarkers[i].stackIndex = 0
                positionedMarkers[i].isVisible = true
            }
            
            // Sort by creation date before recalculating positions
            positionedMarkers.sort { $0.createdAt < $1.createdAt }
            
            // Calculate proper positions
            positionedMarkers = MarkerPositionCalculator.assignStablePositions(
                markers: positionedMarkers,
                candles: candles
            )
            
            await MainActor.run {
                self.markers = positionedMarkers
            }

            // Subscribe to real-time marker events for this guild
            subscribeToMarkerChannel(guildId: guildId)
        } catch {
            print("Failed to load markers: \(error)")
        }
    }

    private func findCandleIndex(timestamp: Date, in candles: [RLCandleDTO]) -> Int? {
        guard !candles.isEmpty else { return nil }
        var closestIndex: Int?
        var smallestDiff: TimeInterval = .greatestFiniteMagnitude
        let tolerance = candleMatchTolerance(in: candles)
        
        for (index, candle) in candles.enumerated() {
            let diff = abs(candle.timestamp.timeIntervalSince(timestamp))
            if diff < smallestDiff {
                smallestDiff = diff
                closestIndex = index
            }
        }

        guard smallestDiff <= tolerance else {
            return nil
        }
        return closestIndex
    }

    private func candleMatchTolerance(in candles: [RLCandleDTO]) -> TimeInterval {
        guard candles.count > 1 else {
            let timeframeSeconds = currentTimeframe?.seconds ?? 60
            return max(30, timeframeSeconds * 0.6)
        }

        var diffs: [TimeInterval] = []
        diffs.reserveCapacity(candles.count - 1)
        for idx in 1..<candles.count {
            let diff = abs(candles[idx].timestamp.timeIntervalSince(candles[idx - 1].timestamp))
            if diff > 0 {
                diffs.append(diff)
            }
        }

        guard !diffs.isEmpty else {
            let timeframeSeconds = currentTimeframe?.seconds ?? 60
            return max(30, timeframeSeconds * 0.6)
        }

        let sorted = diffs.sorted()
        let median = sorted[sorted.count / 2]
        return max(30, median * 0.6)
    }
    
    
    // MARK: - Real-Time Subscriptions

    func configureRealTime(dataManager: ChartDataManager) {
        self.dataManager = dataManager
        cancellables.removeAll()
        RealTimeService.shared.messageSubject
            .sink { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.handleRealTimeMessage(message)
                }
            }
            .store(in: &cancellables)
    }

    private func subscribeToMarkerChannel(guildId: UUID) {
        unsubscribeFromMarkerChannel()
        let channel = "guild:\(guildId.uuidString.lowercased()):markers"
        currentMarkerChannel = channel
        RealTimeService.shared.subscribe(to: [channel], owner: "markers")
    }

    private func unsubscribeFromMarkerChannel() {
        if let channel = currentMarkerChannel {
            RealTimeService.shared.unsubscribe(from: [channel], owner: "markers")
            currentMarkerChannel = nil
        }
    }

    @MainActor
    private func handleRealTimeMessage(_ message: WSIncomingMessage) {
        guard let channel = message.channel, channel == currentMarkerChannel else { return }

        switch message.type {
        case "marker_created":
            handleMarkerCreated(message)
        case "marker_updated":
            handleMarkerUpdated(message)
        case "marker_deleted":
            handleMarkerDeleted(message)
        case "marker_liked":
            handleMarkerLiked(message)
        case "marker_commented":
            handleMarkerCommented(message)
        case "message_reaction_updated":
            handleCommentReactionUpdated(message)
        case "tracking_state_changed":
            handleTrackingStateChanged(message)
        default:
            break
        }
    }

    private func handleMarkerCreated(_ message: WSIncomingMessage) {
        guard let markerDTO = message.payload(as: RLChartMarkerDTO.self) else { return }
        guard canRenderMarker(markerDTO) else { return }

        // Filter to current symbol and timeframe
        guard markerDTO.symbolId == currentSymbolId,
              let currentTf = currentTimeframe,
              markerDTO.timeframe == currentTf.toBackendString() else { return }

        // Dedup — ignore if already present
        guard !markers.contains(where: { $0.id == markerDTO.id }) else { return }

        guard let candles = dataManager?.candles,
              let candleIndex = findCandleIndex(timestamp: markerDTO.candleTimestamp, in: candles) else { return }

        var marker = ChartMarkerUI(marker: markerDTO, candleIndex: candleIndex)

        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex

        markers.append(marker)
    }

    private func handleMarkerUpdated(_ message: WSIncomingMessage) {
        guard let markerDTO = message.payload(as: RLChartMarkerDTO.self) else { return }
        guard canRenderMarker(markerDTO) else {
            let markerId = markerDTO.id
            markers.removeAll { $0.id == markerId }
            if selectedMarker?.id == markerId {
                selectedMarker = nil
            }
            recalculateAllPositions()
            return
        }
        guard let index = markers.firstIndex(where: { $0.id == markerDTO.id }) else { return }

        // Preserve positioning — only update the DTO
        let updated = markers[index].withMarker(markerDTO)
        markers[index] = updated
        syncSelectedMarker(updated)
    }

    private func handleMarkerDeleted(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: MarkerDeletedPayload.self),
              let markerId = UUID(uuidString: payload.markerId) else { return }

        markers.removeAll { $0.id == markerId }
        if selectedMarker?.id == markerId {
            selectedMarker = nil
        }

        recalculateAllPositions()
    }

    private func handleMarkerLiked(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: MarkerLikedPayload.self),
              let markerId = UUID(uuidString: payload.markerId) else { return }
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }

        // Only update like count — isLiked is relative to the sender, not us
        markers[index] = markers[index].withMarker(
            markers[index].marker.updating(likeCount: payload.likeCount)
        )
    }

    private func handleMarkerCommented(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: MarkerCommentedPayload.self),
              let markerId = UUID(uuidString: payload.markerId) else { return }
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }

        // Don't add duplicate comments
        let existingCommentIds = Set(markers[index].comments.map { $0.id })
        guard !existingCommentIds.contains(payload.comment.id) else { return }

        // Recompute isCurrentUserMessage for the receiving user
        var comment = payload.comment
        let isMine = comment.author.userId == currentUserId
        comment = comment.withCurrentUser(isMine)

        let updatedComments = markers[index].comments + [comment]
        markers[index] = markers[index].withMarker(
            markers[index].marker.updating(
                comments: updatedComments,
                commentCount: payload.commentCount
            )
        )
    }

    private func handleCommentReactionUpdated(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: WSMessageReactionUpdatedPayload.self),
              let markerId = UUID(uuidString: payload.markerId ?? ""),
              let commentId = UUID(uuidString: payload.messageId),
              let markerIndex = markers.firstIndex(where: { $0.id == markerId }),
              let commentIndex = markers[markerIndex].comments.firstIndex(where: { $0.id == commentId }) else { return }

        let existingByEmoji = Dictionary(
            uniqueKeysWithValues: markers[markerIndex].comments[commentIndex].reactions.map { ($0.emoji, $0) }
        )
        let updatedComment = {
            var comment = markers[markerIndex].comments[commentIndex]
            comment.reactions = payload.reactions.map { reaction in
                RLMessageReactionDTO(
                    emoji: reaction.emoji,
                    count: reaction.count,
                    reactedByCurrentUser: existingByEmoji[reaction.emoji]?.reactedByCurrentUser ?? false
                )
            }
            return comment
        }()

        var updatedComments = markers[markerIndex].comments
        updatedComments[commentIndex] = updatedComment
        let updatedMarker = markers[markerIndex].withMarker(
            markers[markerIndex].marker.updating(comments: updatedComments)
        )
        markers[markerIndex] = updatedMarker
        syncSelectedMarker(updatedMarker)
    }

    private func handleTrackingStateChanged(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: MarkerTrackingStateChangedPayload.self),
              let markerId = UUID(uuidString: payload.markerId) else { return }

        if let index = markers.firstIndex(where: { $0.id == markerId }) {
            let updated: ChartMarkerUI
            if let markerDTO = payload.marker {
                updated = markers[index].withMarker(markerDTO)
            } else {
                updated = markers[index].withMarker(
                    markers[index].marker.updating(trackingState: payload.newState)
                )
            }
            markers[index] = updated
            syncSelectedMarker(updated)
            return
        }

        // Marker may not be loaded in current window; refresh when possible.
        if let api, let symbolId = currentSymbolId, let timeframe = currentTimeframe, let candles = dataManager?.candles {
            Task { [weak self] in
                guard let self else { return }
                await self.loadMarkersFromAPI(
                    api: api,
                    symbolId: symbolId,
                    symbol: "",
                    guildId: self.currentGuildId,
                    timeframe: timeframe,
                    candles: candles
                )
            }
        }
    }

    // MARK: - Position Recalculation

    private func recalculateAllPositions() {
        guard let candles = dataManager?.candles else { return }
        markers = MarkerPositionCalculator.assignStablePositions(
            markers: markers,
            candles: candles
        )
    }

    func recalculateCandleIndices(candles: [RLCandleDTO]) {
        // Remove markers whose candles no longer exist in the visible window
        markers.removeAll { marker in
            findCandleIndex(timestamp: marker.candleTimestamp, in: candles) == nil
        }
        // Update indices for remaining markers
        for i in 0..<markers.count {
            if let newIndex = findCandleIndex(timestamp: markers[i].candleTimestamp, in: candles) {
                markers[i].candleIndex = newIndex
            }
        }
        markers = MarkerPositionCalculator.assignStablePositions(markers: markers, candles: candles)
    }

    func clearMarkers() {
        markers.removeAll()
        selectedMarker = nil
        unsubscribeFromMarkerChannel()
    }
    
    // MARK: - Duplicate Type Check
    
    func existingMarkerOfIntent(_ intent: RLMarkerIntent, atCandleIndex candleIndex: Int) -> ChartMarkerUI? {
        return markers.first { marker in
            marker.candleIndex == candleIndex && marker.intent == intent
        }
    }
    
    func canAddMarker(intent: RLMarkerIntent, atCandleIndex candleIndex: Int) -> Bool {
        return existingMarkerOfIntent(intent, atCandleIndex: candleIndex) == nil
    }
    
    // MARK: - Marker CRUD
    
    func preflightPlacementFailure(
        for intent: RLMarkerIntent,
        symbolId: UUID,
        timeframe: String,
        trackingEnabled: Bool,
        excludingMarkerId: UUID? = nil
    ) -> MarkerPlacementFailure? {
        guard intent == .setup, trackingEnabled else {
            return nil
        }

        let conflictingMarker = markers.first { marker in
            guard marker.id != excludingMarkerId else { return false }
            return marker.author.userId == currentUserId
                && marker.symbolId == symbolId
                && marker.timeframe == timeframe
                && marker.isOpenTrackedSetup
        }

        if conflictingMarker != nil {
            return .trackedSetupConflictSymbolTimeframe
        }

        return nil
    }

    private func preflightPlacementFailure(
        for request: RLCreateMarkerRequest,
        excludingMarkerId: UUID? = nil
    ) -> MarkerPlacementFailure? {
        preflightPlacementFailure(
            for: RLMarkerIntent(rawValue: request.intent) ?? .analysis,
            symbolId: request.symbolId,
            timeframe: request.timeframe,
            trackingEnabled: request.trackingEnabled,
            excludingMarkerId: excludingMarkerId
        )
    }

    @discardableResult
    func addMarkerV2(
        request: RLCreateMarkerRequest,
        candleIndex: Int,
        candles: [RLCandleDTO]
    ) async -> MarkerPlacementSubmissionResult {
        if let preflightFailure = preflightPlacementFailure(for: request) {
            return .failure(preflightFailure)
        }

        let tempId = UUID()
        let now = Date()

        guard let anchorRequest = request.components.first(where: { $0.componentType == RLComponentType.anchor.rawValue }) else {
            return .failure(.genericCreateFailure)
        }
        let anchorPayload = MarkerComponentPayload.decode(componentType: RLComponentType.anchor.rawValue, rawPayload: anchorRequest.payload)
        let anchorPrice = anchorPayload.levelPrice ?? 0
        let anchorTime = anchorPayload.anchorTime ?? now

        let tempComponents = request.components.enumerated().map { idx, component in
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: component.componentType,
                payload: MarkerComponentPayload.decode(componentType: component.componentType, rawPayload: component.payload),
                ordering: idx
            )
        }

        let tempMarkerDTO = RLChartMarkerDTO(
            id: tempId,
            symbolId: request.symbolId,
            guildId: currentGuildId,
            author: currentUserMember,
            candleTimestamp: anchorTime,
            timeframe: request.timeframe,
            price: anchorPrice,
            intent: request.intent,
            title: request.title,
            note: request.note,
            visibility: request.visibility,
            confidence: request.confidence,
            trackingEnabled: request.trackingEnabled,
            trackingState: request.intent == RLMarkerIntent.setup.rawValue
                ? (request.trackingEnabled ? RLTrackingState.armed.rawValue : RLTrackingState.draft.rawValue)
                : nil,
            alertSeverity: nil,
            createdAt: now,
            createdAtFormatted: "Just now",
            isVisible: true,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: true,
            canEdit: true,
            canDelete: true,
            components: tempComponents,
            primaryComponentId: tempComponents.first(where: { $0.componentType == RLComponentType.anchor.rawValue })?.id,
            pollQuestion: request.pollQuestion,
            pollOptions: request.pollOptions?.map { RLPollOptionDTO(id: UUID(), text: $0, voteCount: 0, hasVoted: false) },
            userPollVote: nil,
            predictionResult: nil
        )

        var marker = ChartMarkerUI(marker: tempMarkerDTO, candleIndex: candleIndex)
        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex
        markers.append(marker)

        guard let api else {
            return .success
        }

        do {
            let created = try await api.createMarkerV2(guildId: currentGuildId, request: request)
            if let idx = markers.firstIndex(where: { $0.id == tempId }),
               let newCandleIndex = findCandleIndex(timestamp: created.candleTimestamp, in: candles) {
                let resolvedCreated = patchPollFields(
                    in: created,
                    fallbackQuestion: normalizedPollQuestion(request.pollQuestion) ?? markers[idx].pollQuestion,
                    fallbackOptions: fallbackPollOptions(
                        from: request.pollOptions,
                        preservingIDsFrom: markers[idx].pollOptions
                    ) ?? markers[idx].pollOptions
                )
                var updated = ChartMarkerUI(marker: resolvedCreated, candleIndex: newCandleIndex)
                updated.positionedBelow = marker.positionedBelow
                updated.proximityTier = marker.proximityTier
                updated.stackIndex = marker.stackIndex
                markers[idx] = updated
            }
            NotificationCenter.default.post(name: .markerCreatedSuccessfully, object: nil)
            return .success
        } catch {
            markers.removeAll { $0.id == tempId }
            print("Failed to create marker v2: \(error)")
            return .failure(MarkerPlacementFailure.from(error: error, fallback: .genericCreateFailure))
        }
    }

    func deleteMarker(id: UUID) async {
        // Optimistic update - remove immediately
        let markerToDelete = markers.first { $0.id == id }
        markers.removeAll { $0.id == id }
        if selectedMarker?.id == id {
            selectedMarker = nil
        }
        
        // Persist to backend
        guard let api = api else { return }
        
        do {
            _ = try await api.deleteMarker(guildId: currentGuildId, markerId: id)
        } catch {
            // Revert optimistic update on error
            if let marker = markerToDelete {
                markers.append(marker)
            }
            print("Failed to delete marker: \(error)")
        }
    }

    private struct MarkerLayoutSnapshot {
        let candleIndex: Int
        let positionedBelow: Bool
        let proximityTier: Int
        let stackIndex: Int
    }

    private func markerIndex(for id: UUID) -> Int? {
        markers.firstIndex(where: { $0.id == id })
    }

    private func snapshotLayout(for marker: ChartMarkerUI) -> MarkerLayoutSnapshot {
        MarkerLayoutSnapshot(
            candleIndex: marker.candleIndex,
            positionedBelow: marker.positionedBelow,
            proximityTier: marker.proximityTier,
            stackIndex: marker.stackIndex
        )
    }

    private func applyingLayout(_ snapshot: MarkerLayoutSnapshot, to marker: ChartMarkerUI) -> ChartMarkerUI {
        var updated = marker
        updated.candleIndex = snapshot.candleIndex
        updated.positionedBelow = snapshot.positionedBelow
        updated.proximityTier = snapshot.proximityTier
        updated.stackIndex = snapshot.stackIndex
        return updated
    }

    private func syncSelectedMarker(_ marker: ChartMarkerUI) {
        guard selectedMarker?.id == marker.id else { return }
        selectedMarker = marker
    }

    private func normalizedPollQuestion(_ question: String?) -> String? {
        let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fallbackPollOptions(
        from options: [String]?,
        preservingIDsFrom existing: [RLPollOptionDTO]?
    ) -> [RLPollOptionDTO]? {
        guard let options else { return nil }
        let normalized = options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return nil }

        return normalized.enumerated().map { index, text in
            let existingID = existing?.indices.contains(index) == true ? existing?[index].id : nil
            return RLPollOptionDTO(
                id: existingID ?? UUID(),
                text: text,
                voteCount: 0,
                hasVoted: false
            )
        }
    }

    private func patchPollFields(
        in marker: RLChartMarkerDTO,
        fallbackQuestion: String?,
        fallbackOptions: [RLPollOptionDTO]?
    ) -> RLChartMarkerDTO {
        let serverQuestion = marker.pollQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let shouldPatchQuestion = serverQuestion.isEmpty && fallbackQuestion != nil
        let shouldPatchOptions = (marker.pollOptions?.isEmpty ?? true) && !(fallbackOptions?.isEmpty ?? true)

        guard shouldPatchQuestion || shouldPatchOptions else { return marker }
        return marker.updating(
            pollQuestion: shouldPatchQuestion ? fallbackQuestion : nil,
            pollOptions: shouldPatchOptions ? fallbackOptions : nil
        )
    }
    
    /// Update a marker with any combination of fields (all optional). Only provided fields are sent to the backend.
    func updateMarker(
        id: UUID,
        note: String? = nil,
        price: Double? = nil,
        isVisible: Bool? = nil,
        horizontalLinePrice: Double? = nil,
        horizontalLineType: RLComponentType? = nil,
        targetPrice: Double? = nil,
        stopLossPrice: Double? = nil,
        alertSeverity: String? = nil,
        trendlineDirection: String? = nil,
        selectedIndicator: String? = nil,
        chartPattern: String? = nil,
        selectedEmoji: String? = nil
    ) async {
        guard let index = markerIndex(for: id) else { return }
        guard let api = api else { return }

        let originalMarker = markers[index]
        let originalSnapshot = snapshotLayout(for: originalMarker)
        let originalDTO = originalMarker.marker

        var updatedComponents = originalDTO.components
        var didMutateComponents = false

        func upsertComponent(_ componentType: String, payload: MarkerComponentPayload) {
            if let idx = updatedComponents.firstIndex(where: { $0.componentType == componentType }) {
                let existing = updatedComponents[idx]
                updatedComponents[idx] = RLMarkerComponentDTO(
                    id: existing.id,
                    componentType: existing.componentType,
                    payload: payload,
                    ordering: existing.ordering
                )
            } else {
                updatedComponents.append(
                    RLMarkerComponentDTO(
                        id: UUID(),
                        componentType: componentType,
                        payload: payload,
                        ordering: updatedComponents.count
                    )
                )
            }
            didMutateComponents = true
        }

        if let price {
            if let anchorIndex = updatedComponents.firstIndex(where: { $0.componentType == RLComponentType.anchor.rawValue }),
               case let .anchor(anchorPayload) = updatedComponents[anchorIndex].payload {
                let updatedAnchor = AnchorPayload(time: anchorPayload.time, price: price)
                let current = updatedComponents[anchorIndex]
                updatedComponents[anchorIndex] = RLMarkerComponentDTO(
                    id: current.id,
                    componentType: current.componentType,
                    payload: .anchor(updatedAnchor),
                    ordering: current.ordering
                )
                didMutateComponents = true
            }
        }

        if let horizontalLinePrice {
            let candidateOrder: [RLComponentType] = [
                .levelEntry, .levelSl, .levelTp, .levelSupport, .levelResistance,
            ]
            let resolvedType = horizontalLineType ?? (
                candidateOrder.first { candidate in
                    updatedComponents.contains(where: { $0.componentType == candidate.rawValue })
                } ?? (originalDTO.intentEnum == .setup ? .levelEntry : nil)
            )
            // Ignore generic horizontal-line updates for non-setup markers that
            // do not already have an explicit level component.
            if let componentType = resolvedType {
                let existingLabel: String? = {
                    guard let existing = updatedComponents.first(where: { $0.componentType == componentType.rawValue }) else {
                        return nil
                    }
                    switch existing.payload {
                    case .levelEntry(let payload),
                         .levelSl(let payload),
                         .levelTp(let payload),
                         .levelSupport(let payload),
                         .levelResistance(let payload):
                        return payload.label
                    default:
                        return nil
                    }
                }()
                let fallbackLabel: String = {
                    switch componentType {
                    case .levelEntry: return "Entry"
                    case .levelSl: return "SL"
                    case .levelTp: return "TP"
                    case .levelSupport: return "Support"
                    case .levelResistance: return "Resistance"
                    default: return "Level"
                    }
                }()
                let payload: MarkerComponentPayload = {
                    switch componentType {
                    case .levelEntry:
                        return .levelEntry(LevelPayload(price: horizontalLinePrice, label: existingLabel ?? fallbackLabel))
                    case .levelSl:
                        return .levelSl(LevelPayload(price: horizontalLinePrice, label: existingLabel ?? fallbackLabel))
                    case .levelTp:
                        return .levelTp(LevelPayload(price: horizontalLinePrice, label: existingLabel ?? fallbackLabel))
                    case .levelSupport:
                        return .levelSupport(LevelPayload(price: horizontalLinePrice, label: existingLabel ?? fallbackLabel))
                    case .levelResistance:
                        return .levelResistance(LevelPayload(price: horizontalLinePrice, label: existingLabel ?? fallbackLabel))
                    default:
                        return .levelEntry(LevelPayload(price: horizontalLinePrice, label: existingLabel ?? fallbackLabel))
                    }
                }()
                upsertComponent(componentType.rawValue, payload: payload)
            }
        }

        if let targetPrice {
            upsertComponent(
                RLComponentType.levelTp.rawValue,
                payload: .levelTp(LevelPayload(price: targetPrice, label: nil))
            )
        }

        if let stopLossPrice {
            upsertComponent(
                RLComponentType.levelSl.rawValue,
                payload: .levelSl(LevelPayload(price: stopLossPrice, label: nil))
            )
        }

        if let selectedIndicator {
            upsertComponent(
                RLComponentType.indicator.rawValue,
                payload: .indicator(IndicatorPayload(name: selectedIndicator, settings: nil, isPrimary: nil))
            )
        }

        if let selectedEmoji {
            let existingEmojiPayload: EmojiPayload? = {
                guard let existing = updatedComponents.first(where: {
                    $0.componentType == RLComponentType.reactionEmoji.rawValue
                }) else {
                    return nil
                }
                guard case let .reactionEmoji(payload) = existing.payload else {
                    return nil
                }
                return payload
            }()
            upsertComponent(
                RLComponentType.reactionEmoji.rawValue,
                payload: .reactionEmoji(
                    EmojiPayload(
                        emoji: selectedEmoji,
                        offsetX: existingEmojiPayload?.offsetX,
                        offsetY: existingEmojiPayload?.offsetY,
                        anchorTime: existingEmojiPayload?.anchorTime,
                        anchorPrice: existingEmojiPayload?.anchorPrice
                    )
                )
            )
        }

        if let note = note {
            markers[index] = originalMarker.withMarker(originalDTO.updating(note: note))
            syncSelectedMarker(markers[index])
        }
        if didMutateComponents {
            let optimistic = markers[index].withMarker(
                markers[index].marker.updating(
                    trackingState: markers[index].marker.trackingState,
                    components: updatedComponents
                )
            )
            markers[index] = optimistic
            syncSelectedMarker(optimistic)
        }

        do {
            let updateRequest = RLUpdateMarkerRequest(
                intent: nil,
                title: nil,
                note: note,
                visibility: nil,
                confidence: nil,
                trackingEnabled: nil,
                components: didMutateComponents
                    ? updatedComponents.map { RLMarkerComponentRequest(componentType: $0.componentType, payload: $0.payload.rawPayload) }
                    : nil
            )
            let updatedMarker = try await api.updateMarkerV2(
                guildId: currentGuildId,
                markerId: id,
                request: updateRequest
            )
            guard let latestIndex = markerIndex(for: id) else { return }

            let latestSnapshot = snapshotLayout(for: markers[latestIndex])
            let updated = applyingLayout(
                latestSnapshot,
                to: ChartMarkerUI(marker: updatedMarker, candleIndex: latestSnapshot.candleIndex)
            )
            markers[latestIndex] = updated
            syncSelectedMarker(updated)
        } catch {
            guard let latestIndex = markerIndex(for: id) else { return }

            if note != nil || didMutateComponents {
                let rolledBack = applyingLayout(
                    originalSnapshot,
                    to: ChartMarkerUI(marker: originalMarker.marker, candleIndex: originalSnapshot.candleIndex)
                )
                markers[latestIndex] = rolledBack
                syncSelectedMarker(rolledBack)
            }
            print("Failed to update marker: \(error)")
        }
    }

    @discardableResult
    func updateMarkerFromPlacement(
        id: UUID,
        request: RLUpdateMarkerRequest
    ) async -> MarkerPlacementSubmissionResult {
        guard let index = markerIndex(for: id) else {
            return .failure(.genericUpdateFailure)
        }
        guard let api = api else {
            return .failure(.genericUpdateFailure)
        }

        let originalMarker = markers[index]
        let effectiveCreateRequest = RLCreateMarkerRequest(
            symbolId: originalMarker.symbolId,
            timeframe: originalMarker.timeframe,
            intent: request.intent ?? originalMarker.intent.rawValue,
            title: request.title,
            note: request.note,
            visibility: request.visibility ?? originalMarker.visibility,
            confidence: request.confidence,
            trackingEnabled: request.trackingEnabled ?? originalMarker.trackingEnabled,
            components: request.components ?? [],
            pollQuestion: request.pollQuestion,
            pollOptions: request.pollOptions
        )
        if let preflightFailure = preflightPlacementFailure(for: effectiveCreateRequest, excludingMarkerId: id) {
            return .failure(preflightFailure)
        }

        let originalSnapshot = snapshotLayout(for: originalMarker)
        let originalDTO = originalMarker.marker

        let optimisticComponents: [RLMarkerComponentDTO]? = request.components.map { requests in
            buildComponentDTOs(
                from: requests,
                preservingFrom: originalDTO.components
            )
        }
        let optimisticPollQuestion = normalizedPollQuestion(request.pollQuestion)
        let optimisticPollOptions = fallbackPollOptions(
            from: request.pollOptions,
            preservingIDsFrom: originalDTO.pollOptions
        )

        let optimistic = originalMarker.withMarker(
            originalDTO.updating(
                title: request.title,
                note: request.note,
                visibility: request.visibility,
                trackingEnabled: request.trackingEnabled,
                components: optimisticComponents,
                pollQuestion: optimisticPollQuestion,
                pollOptions: optimisticPollOptions
            )
        )
        markers[index] = optimistic
        syncSelectedMarker(optimistic)

        do {
            let updatedMarker = try await api.updateMarkerV2(
                guildId: currentGuildId,
                markerId: id,
                request: request
            )
            guard let latestIndex = markerIndex(for: id) else {
                return .failure(.genericUpdateFailure)
            }

            let latestSnapshot = snapshotLayout(for: markers[latestIndex])
            let reconciled = patchPollFields(
                in: updatedMarker,
                fallbackQuestion: optimistic.pollQuestion,
                fallbackOptions: optimistic.pollOptions
            )
            let updated = applyingLayout(
                latestSnapshot,
                to: ChartMarkerUI(marker: reconciled, candleIndex: latestSnapshot.candleIndex)
            )
            markers[latestIndex] = updated
            syncSelectedMarker(updated)
            return .success
        } catch {
            guard let latestIndex = markerIndex(for: id) else {
                return .failure(.genericUpdateFailure)
            }
            let rolledBack = applyingLayout(
                originalSnapshot,
                to: ChartMarkerUI(marker: originalMarker.marker, candleIndex: originalSnapshot.candleIndex)
            )
            markers[latestIndex] = rolledBack
            syncSelectedMarker(rolledBack)
            print("Failed to update marker from placement: \(error)")
            return .failure(MarkerPlacementFailure.from(error: error, fallback: .genericUpdateFailure))
        }
    }

    private func buildComponentDTOs(
        from requests: [RLMarkerComponentRequest],
        preservingFrom existing: [RLMarkerComponentDTO]
    ) -> [RLMarkerComponentDTO] {
        var reusableIDs: [String: [UUID]] = [:]
        for component in existing.sorted(by: { $0.ordering < $1.ordering }) {
            reusableIDs[component.componentType, default: []].append(component.id)
        }

        return requests.enumerated().map { ordering, component in
            let id: UUID = {
                var pool = reusableIDs[component.componentType] ?? []
                if !pool.isEmpty {
                    let preserved = pool.removeFirst()
                    reusableIDs[component.componentType] = pool
                    return preserved
                }
                return UUID()
            }()

            return RLMarkerComponentDTO(
                id: id,
                componentType: component.componentType,
                payload: MarkerComponentPayload.decode(
                    componentType: component.componentType,
                    rawPayload: component.payload
                ),
                ordering: ordering
            )
        }
    }
    
    func toggleLike(markerId: UUID) async {
        guard let index = markerIndex(for: markerId) else { return }
        
        // Optimistic update
        let currentMarker = markers[index]
        let wasLiked = currentMarker.isLikedByCurrentUser
        let oldLikeCount = currentMarker.likeCount
        let optimisticLikeCount = wasLiked ? max(0, oldLikeCount - 1) : oldLikeCount + 1
        markers[index] = currentMarker.withMarker(
            currentMarker.marker.updating(
                likeCount: optimisticLikeCount,
                isLikedByCurrentUser: !wasLiked
            )
        )
        syncSelectedMarker(markers[index])
        
        // Persist to backend
        guard let api = api else { return }
        
        do {
            let response = try await api.toggleMarkerLike(guildId: currentGuildId, markerId: markerId)
            guard let latestIndex = markerIndex(for: markerId) else { return }

            // Update with real like count from backend
            let updated = markers[latestIndex].withMarker(
                markers[latestIndex].marker.updating(
                    likeCount: response.likeCount,
                    isLikedByCurrentUser: response.isLiked
                )
            )
            markers[latestIndex] = updated
            syncSelectedMarker(updated)
        } catch {
            guard let latestIndex = markerIndex(for: markerId) else { return }

            // Revert optimistic update on error
            let rolledBack = currentMarker.withMarker(
                currentMarker.marker.updating(
                    likeCount: oldLikeCount,
                    isLikedByCurrentUser: wasLiked
                )
            )
            markers[latestIndex] = rolledBack
            syncSelectedMarker(rolledBack)
            print("Failed to toggle like: \(error)")
        }
    }

    func voteOnPoll(markerId: UUID, optionId: UUID) async throws {
        guard let index = markerIndex(for: markerId) else {
            throw PollVoteError.markerNotFound
        }

        let originalMarker = markers[index]
        guard let originalOptions = originalMarker.pollOptions, !originalOptions.isEmpty else {
            throw PollVoteError.invalidPoll
        }
        guard originalOptions.contains(where: { $0.id == optionId }) else {
            throw PollVoteError.optionNotFound
        }

        let previousVoteId = originalMarker.userPollVote
        let optimisticOptions = originalOptions.map { option in
            let wasSelectedBefore = previousVoteId == option.id
            let isSelectedNow = option.id == optionId

            var adjustedVoteCount = option.voteCount
            if wasSelectedBefore && !isSelectedNow {
                adjustedVoteCount = max(0, adjustedVoteCount - 1)
            } else if !wasSelectedBefore && isSelectedNow {
                adjustedVoteCount += 1
            }

            return RLPollOptionDTO(
                id: option.id,
                text: option.text,
                voteCount: adjustedVoteCount,
                hasVoted: isSelectedNow
            )
        }

        let optimistic = originalMarker.withMarker(
            originalMarker.marker.updating(
                pollOptions: optimisticOptions,
                userPollVote: optionId
            )
        )
        markers[index] = optimistic
        syncSelectedMarker(optimistic)

        guard let api else {
            throw PollVoteError.apiUnavailable
        }

        do {
            let response = try await api.voteOnPoll(
                guildId: currentGuildId,
                markerId: markerId,
                optionId: optionId
            )

            guard let latestIndex = markerIndex(for: markerId) else {
                throw PollVoteError.markerNotFound
            }

            let reconciled = markers[latestIndex].withMarker(
                markers[latestIndex].marker.updating(
                    pollOptions: response.updatedOptions,
                    userPollVote: response.optionId
                )
            )
            markers[latestIndex] = reconciled
            syncSelectedMarker(reconciled)
        } catch {
            if let latestIndex = markerIndex(for: markerId) {
                let rolledBack = markers[latestIndex].withMarker(originalMarker.marker)
                markers[latestIndex] = rolledBack
                syncSelectedMarker(rolledBack)
            }
            throw error
        }
    }
    
    func addComment(
        markerId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        replyToMessageId: UUID? = nil
    ) async {
        guard let index = markerIndex(for: markerId) else { return }
        
        let tempCommentId = UUID()
        
        // Optimistic update
        let comment = RLMarkerCommentDTO(
            id: tempCommentId,
            markerId: markerId,
            author: currentUserMember,
            content: content,
            timestamp: Date(),
            timestampFormatted: "Just now",
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName
        )
        
        let optimisticComments = markers[index].comments + [comment]
        markers[index] = markers[index].withMarker(
            markers[index].marker.updating(
                comments: optimisticComments,
                commentCount: optimisticComments.count
            )
        )
        syncSelectedMarker(markers[index])
        
        // Persist to backend
        guard let api = api else { return }
        
        do {
            let createdComment = try await api.addMarkerComment(
                guildId: currentGuildId,
                markerId: markerId,
                content: content,
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName,
                replyToMessageId: replyToMessageId
            )
            
            guard let latestIndex = markerIndex(for: markerId) else { return }

            // Replace optimistic comment with real one from backend
            var updatedComments = markers[latestIndex].comments
            if let commentIndex = updatedComments.firstIndex(where: { $0.id == tempCommentId }) {
                updatedComments[commentIndex] = createdComment
            } else {
                updatedComments.append(createdComment)
            }
            let updated = markers[latestIndex].withMarker(
                markers[latestIndex].marker.updating(
                    comments: updatedComments,
                    commentCount: updatedComments.count
                )
            )
            markers[latestIndex] = updated
            syncSelectedMarker(updated)
        } catch {
            guard let latestIndex = markerIndex(for: markerId) else { return }

            // Revert optimistic update on error
            let rolledBackComments = markers[latestIndex].comments.filter { $0.id != tempCommentId }
            let updated = markers[latestIndex].withMarker(
                markers[latestIndex].marker.updating(
                    comments: rolledBackComments,
                    commentCount: rolledBackComments.count
                )
            )
            markers[latestIndex] = updated
            syncSelectedMarker(updated)
            print("Failed to add comment: \(error)")
        }
    }

    func toggleCommentReaction(markerId: UUID, commentId: UUID, emoji: String) async throws {
        guard let markerIndex = markerIndex(for: markerId),
              let commentIndex = markers[markerIndex].comments.firstIndex(where: { $0.id == commentId }),
              let api else { return }

        let updatedComment = try await api.toggleMarkerCommentReaction(
            guildId: currentGuildId,
            markerId: markerId,
            commentId: commentId,
            emoji: emoji
        )

        var updatedComments = markers[markerIndex].comments
        updatedComments[commentIndex] = updatedComment
        let updatedMarker = markers[markerIndex].withMarker(
            markers[markerIndex].marker.updating(comments: updatedComments)
        )
        markers[markerIndex] = updatedMarker
        syncSelectedMarker(updatedMarker)
    }

    func fetchCommentReactionReactors(
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        guard let api else {
            throw APIError.badRequest("Marker API is not configured")
        }
        return try await api.getMarkerCommentReactionReactors(
            guildId: currentGuildId,
            markerId: markerId,
            commentId: commentId,
            emoji: emoji
        )
    }
    
    @discardableResult
    func deleteComment(markerId: UUID, commentId: UUID) async -> Bool {
        guard let initialIndex = markerIndex(for: markerId) else { return false }

        let originalComments = markers[initialIndex].comments
        guard originalComments.contains(where: { $0.id == commentId }) else { return true }

        let updatedComments = originalComments.filter { $0.id != commentId }
        let optimisticallyUpdated = markers[initialIndex].withMarker(
            markers[initialIndex].marker.updating(
                comments: updatedComments,
                commentCount: updatedComments.count
            )
        )
        markers[initialIndex] = optimisticallyUpdated
        syncSelectedMarker(optimisticallyUpdated)

        guard let api = api else { return true }

        do {
            _ = try await api.deleteMarkerComment(
                guildId: currentGuildId,
                markerId: markerId,
                commentId: commentId
            )
            return true
        } catch {
            guard let latestIndex = markerIndex(for: markerId) else { return false }
            let rolledBack = markers[latestIndex].withMarker(
                markers[latestIndex].marker.updating(
                    comments: originalComments,
                    commentCount: originalComments.count
                )
            )
            markers[latestIndex] = rolledBack
            syncSelectedMarker(rolledBack)
            print("Failed to delete comment: \(error)")
            return false
        }
    }
    
    var filteredMarkers: [ChartMarkerUI] {
        if visibilityMode == .off { return [] }
        let effectiveIntents = visibleIntents

        return markers.filter { marker in
            guard marker.isVisible else { return false }
            guard canRenderMarker(marker.marker) else { return false }
            guard effectiveIntents.contains(marker.intent) else { return false }
            switch visibilityMode {
            case .off:
                return false
            case .all:
                return true
            case .mine:
                return marker.isCurrentUserMarker || marker.author.userId == currentUserId
            case .friends:
                return marker.author.isFriend
            }
        }
    }
    
    func markersGroupedByCandle() -> [Int: [ChartMarkerUI]] {
        Dictionary(grouping: filteredMarkers) { $0.candleIndex }
    }
    
    func markerCount(atCandleIndex candleIndex: Int) -> Int {
        markersGroupedByCandle()[candleIndex]?.count ?? 0
    }
    
    func shouldHideUsername(forCandleIndex candleIndex: Int) -> Bool {
        markerCount(atCandleIndex: candleIndex) > 1
    }
}

// MARK: - Marker Display Settings

class MarkerDisplaySettings: ObservableObject {
    static let shared = MarkerDisplaySettings()
    static let baseOffsetDefault: CGFloat = 70
    static let stackOffsetDefault: CGFloat = 36
    static let minStackSpacingDefault: CGFloat = 34
    static let proximityTierOffsetDefault: CGFloat = 25
    static let placementExtraOffsetLegacyDefault: CGFloat = 40
    static let placementExtraOffsetDefault: CGFloat = 24

    static let keyBaseOffset = "markerBaseOffset"
    static let keyStackOffset = "markerStackOffset"
    static let keyMinStackSpacing = "markerMinStackSpacing"
    static let keyProximityTierOffset = "markerProximityTierOffset"
    static let keyPlacementExtraOffset = "markerPlacementExtraOffset"
    static let keyPlacementOffsetMigrated = "markerPlacementExtraOffsetMigrated_v2"

    private let userDefaults: UserDefaults

    @Published var baseOffset: CGFloat {
        didSet { userDefaults.set(baseOffset, forKey: Self.keyBaseOffset) }
    }

    @Published var stackOffset: CGFloat {
        didSet { userDefaults.set(stackOffset, forKey: Self.keyStackOffset) }
    }

    @Published var minStackSpacing: CGFloat {
        didSet {
            let clamped = Swift.max(MarkerPositionCalculator.hardMinimumStackSpacing, minStackSpacing)
            if clamped != minStackSpacing {
                minStackSpacing = clamped
                return
            }
            userDefaults.set(minStackSpacing, forKey: Self.keyMinStackSpacing)
        }
    }

    @Published var proximityTierOffset: CGFloat {
        didSet { userDefaults.set(proximityTierOffset, forKey: Self.keyProximityTierOffset) }
    }

    @Published var placementExtraOffset: CGFloat {
        didSet { userDefaults.set(placementExtraOffset, forKey: Self.keyPlacementExtraOffset) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.baseOffset = userDefaults.object(forKey: Self.keyBaseOffset) as? CGFloat ?? Self.baseOffsetDefault
        self.stackOffset = userDefaults.object(forKey: Self.keyStackOffset) as? CGFloat ?? Self.stackOffsetDefault
        let persistedMinSpacing = userDefaults.object(forKey: Self.keyMinStackSpacing) as? CGFloat ?? Self.minStackSpacingDefault
        self.minStackSpacing = Swift.max(MarkerPositionCalculator.hardMinimumStackSpacing, persistedMinSpacing)
        self.proximityTierOffset = userDefaults.object(forKey: Self.keyProximityTierOffset) as? CGFloat ?? Self.proximityTierOffsetDefault

        let persistedPlacementOffset = userDefaults.object(forKey: Self.keyPlacementExtraOffset) as? CGFloat
        let hasMigratedPlacementOffset = userDefaults.bool(forKey: Self.keyPlacementOffsetMigrated)
        if let persistedPlacementOffset {
            let shouldMigrateLegacyDefault =
                !hasMigratedPlacementOffset &&
                abs(persistedPlacementOffset - Self.placementExtraOffsetLegacyDefault) < 0.0001

            self.placementExtraOffset = shouldMigrateLegacyDefault
                ? Self.placementExtraOffsetDefault
                : persistedPlacementOffset
        } else {
            self.placementExtraOffset = Self.placementExtraOffsetDefault
        }

        userDefaults.set(self.placementExtraOffset, forKey: Self.keyPlacementExtraOffset)

        if !hasMigratedPlacementOffset {
            userDefaults.set(true, forKey: Self.keyPlacementOffsetMigrated)
        }
    }

    func resetToDefaults() {
        baseOffset = Self.baseOffsetDefault
        stackOffset = Self.stackOffsetDefault
        minStackSpacing = Swift.max(MarkerPositionCalculator.hardMinimumStackSpacing, Self.minStackSpacingDefault)
        proximityTierOffset = Self.proximityTierOffsetDefault
        placementExtraOffset = Self.placementExtraOffsetDefault
    }
}

// MARK: - Marker Position Calculator

struct MarkerPositionCalculator {
    
    static var settings: MarkerDisplaySettings { MarkerDisplaySettings.shared }
    static var baseOffset: CGFloat { settings.baseOffset }
    static var stackOffset: CGFloat { settings.stackOffset }
    static var minStackSpacing: CGFloat { settings.minStackSpacing }
    static let hardMinimumStackSpacing: CGFloat = MarkerVisualSpec.baseCanvasDiameter + 4
    static let proximityRange = 3
    static let hitRadius: CGFloat = 28
    
    static var placementOffset: CGFloat {
        settings.baseOffset + settings.placementExtraOffset
    }
    
    // MARK: - Shared Position Calculation
    
    static func computeMarkerScreenPosition(
        marker: ChartMarkerUI,
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat,
        priceScale: CGFloat = 1.0,
        viewportHeight: CGFloat = 0
    ) -> CGPoint {
        let baseY: CGFloat
        let stackDirection: CGFloat

        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
        let scaledStackOffset = Swift.max(hardMinimumStackSpacing, Swift.max(minStackSpacing, scaledStackOffsetRaw))
        let scaledBaseOffset = baseOffset * dampenedBaseScale
        let scaledTierOffset = offsetForTier(marker.proximityTier) * dampenedBaseScale

        if marker.positionedBelow {
            baseY = candleLowY + scaledBaseOffset
            stackDirection = 1.0
        } else {
            baseY = candleHighY - scaledBaseOffset
            stackDirection = -1.0
        }

        let stackOffsetValue = CGFloat(marker.stackIndex) * scaledStackOffset * stackDirection
        let tierOffset = scaledTierOffset * stackDirection
        var markerY = baseY + stackOffsetValue + tierOffset

        // Clamp within viewport bounds if available, keeping markers visible
        if viewportHeight > 0 {
            let markerRadius = MarkerVisualSpec.baseCanvasDiameter / 2
            markerY = Swift.max(markerRadius, Swift.min(markerY, viewportHeight - markerRadius))
        }

        return CGPoint(x: centerX, y: markerY)
    }
    
    private static func dampenPriceScale(_ priceScale: CGFloat, dampening: CGFloat) -> CGFloat {
        return 1.0 + (priceScale - 1.0) * dampening
    }
    
    static func calculatePreviewPosition(
        candleIndex: Int,
        existingMarkers: [ChartMarkerUI],
        candles: [RLCandleDTO],
        candleHighY: CGFloat,
        candleLowY: CGFloat,
        centerX: CGFloat,
        priceScale: CGFloat = 1.0
    ) -> (position: CGPoint, isBelow: Bool) {
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledPlacementOffset = placementOffset * dampenedBaseScale
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
        let scaledStackOffset = Swift.max(hardMinimumStackSpacing, Swift.max(minStackSpacing, scaledStackOffsetRaw))
        
        let shouldBeBelow: Bool
        
        if !markersAtCandle.isEmpty {
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        } else {
            shouldBeBelow = determineSideForNewMarker(
                candleIndex: candleIndex,
                existingMarkers: existingMarkers,
                candles: candles
            )
        }
        
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        if shouldBeBelow {
            baseY = candleLowY + scaledPlacementOffset
            stackDirection = 1.0
        } else {
            baseY = candleHighY - scaledPlacementOffset
            stackDirection = -1.0
        }
        
        let stackOffsetValue = CGFloat(stackIndex) * scaledStackOffset * stackDirection
        let markerY = baseY + stackOffsetValue
        
        return (CGPoint(x: centerX, y: markerY), shouldBeBelow)
    }
    
    // MARK: - Stable Position Assignment
    
    private static let closeProximityRange = 2
    
    static func assignStablePositions(
        markers: [ChartMarkerUI],
        candles: [RLCandleDTO]
    ) -> [ChartMarkerUI] {
        var result = markers
        
        let grouped = Dictionary(grouping: result) { $0.candleIndex }
        let sortedIndices = grouped.keys.sorted()
        
        var usedAboveTiers: [Int: Set<Int>] = [:]
        var usedBelowTiers: [Int: Set<Int>] = [:]
        var candleSideDecisions: [Int: Bool] = [:]
        
        for candleIndex in sortedIndices {
            guard let markersAtCandle = grouped[candleIndex] else { continue }
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            let shouldBeBelow = determineSideForCandle(
                candleIndex: candleIndex,
                candles: candles,
                existingDecisions: candleSideDecisions
            )
            
            candleSideDecisions[candleIndex] = shouldBeBelow
            
            let tier: Int
            if shouldBeBelow {
                tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedBelowTiers)
            } else {
                tier = calculateProximityTierInternal(candleIndex: candleIndex, usedTiers: &usedAboveTiers)
            }
            
            for (stackIndex, markerInGroup) in sorted.enumerated() {
                guard let globalIndex = result.firstIndex(where: { $0.id == markerInGroup.id }) else { continue }
                
                result[globalIndex].positionedBelow = shouldBeBelow
                result[globalIndex].proximityTier = tier
                result[globalIndex].stackIndex = stackIndex
            }
        }
        
        return result
    }
    
    static func calculatePositionForNewMarker(
        marker: ChartMarkerUI,
        existingMarkers: [ChartMarkerUI],
        candles: [RLCandleDTO]
    ) -> (isBelow: Bool, tier: Int, stackIndex: Int) {
        let candleIndex = marker.candleIndex
        let markersAtCandle = existingMarkers.filter { $0.candleIndex == candleIndex }
        
        let shouldBeBelow: Bool
        
        if !markersAtCandle.isEmpty {
            if let firstMarker = markersAtCandle.first {
                shouldBeBelow = firstMarker.positionedBelow
            } else {
                shouldBeBelow = false
            }
        } else {
            shouldBeBelow = determineSideForNewMarker(
                candleIndex: candleIndex,
                existingMarkers: existingMarkers,
                candles: candles
            )
        }
        
        let tier: Int
        if !markersAtCandle.isEmpty {
            tier = markersAtCandle.first?.proximityTier ?? 0
        } else {
            tier = calculateProximityTier(
                candleIndex: candleIndex,
                isBelow: shouldBeBelow,
                existingMarkers: existingMarkers
            )
        }
        
        let stackIndex = markersAtCandle.filter { $0.positionedBelow == shouldBeBelow }.count
        
        return (shouldBeBelow, tier, stackIndex)
    }
    
    private static func determineSideForNewMarker(
        candleIndex: Int,
        existingMarkers: [ChartMarkerUI],
        candles: [RLCandleDTO]
    ) -> Bool {
        var aboveCount = 0
        var belowCount = 0

        for offset in -closeProximityRange...closeProximityRange {
            if offset == 0 { continue }
            let neighborIndex = candleIndex + offset
            let nearbyMarkers = existingMarkers.filter { $0.candleIndex == neighborIndex }

            for marker in nearbyMarkers {
                if marker.positionedBelow {
                    belowCount += 1
                } else {
                    aboveCount += 1
                }
            }
        }

        if aboveCount != belowCount {
            // Place on the less crowded side to reduce obscuring
            return aboveCount > belowCount
        }

        // Default: prefer above (false) to avoid obscuring candle bodies
        return false
    }

    private static func determineSideForCandle(
        candleIndex: Int,
        candles: [RLCandleDTO],
        existingDecisions: [Int: Bool]
    ) -> Bool {
        var aboveCount = 0
        var belowCount = 0

        for offset in -closeProximityRange...closeProximityRange {
            if offset == 0 { continue }
            let neighborIndex = candleIndex + offset

            if let decision = existingDecisions[neighborIndex] {
                if decision {
                    belowCount += 1
                } else {
                    aboveCount += 1
                }
            }
        }

        if aboveCount != belowCount {
            return aboveCount > belowCount
        }

        // Default: prefer above (false) to avoid obscuring candle bodies
        return false
    }
    
    private static func calculateProximityTier(
        candleIndex: Int,
        isBelow: Bool,
        existingMarkers: [ChartMarkerUI]
    ) -> Int {
        var usedTiers = Set<Int>()
        
        for offset in -proximityRange...proximityRange {
            let neighborIndex = candleIndex + offset
            let nearbyMarkers = existingMarkers.filter {
                $0.candleIndex == neighborIndex && $0.positionedBelow == isBelow
            }
            
            for marker in nearbyMarkers {
                usedTiers.insert(marker.proximityTier)
            }
        }
        
        var tier = 0
        while usedTiers.contains(tier) {
            tier += 1
        }
        
        return tier
    }
    
    private static func calculateProximityTierInternal(
        candleIndex: Int,
        usedTiers: inout [Int: Set<Int>]
    ) -> Int {
        var conflictingTiers = Set<Int>()
        
        for offset in -proximityRange...proximityRange {
            let neighborIndex = candleIndex + offset
            if let tiers = usedTiers[neighborIndex] {
                conflictingTiers.formUnion(tiers)
            }
        }
        
        var tier = 0
        while conflictingTiers.contains(tier) {
            tier += 1
        }
        
        if usedTiers[candleIndex] == nil {
            usedTiers[candleIndex] = Set<Int>()
        }
        usedTiers[candleIndex]?.insert(tier)
        
        return tier
    }
    
    static func offsetForTier(_ tier: Int) -> CGFloat {
        return CGFloat(tier) * settings.proximityTierOffset
    }
    
    static func findMarkerAtPoint(
        point: CGPoint,
        markers: [ChartMarkerUI],
        markerPositions: [UUID: CGPoint]
    ) -> ChartMarkerUI? {
        for marker in markers.reversed() {
            if let position = markerPositions[marker.id] {
                let distance = hypot(point.x - position.x, point.y - position.y)
                if distance <= hitRadius {
                    return marker
                }
            }
        }
        return nil
    }
}

// MARK: - Chart Marker System (Canvas Drawing)

struct ChartMarkerSystem {
    struct UsernameLabelCandidate {
        let markerId: UUID
        let rect: CGRect
        let sortKey: Int

        init(markerId: UUID, rect: CGRect, sortKey: Int = 0) {
            self.markerId = markerId
            self.rect = rect
            self.sortKey = sortKey
        }
    }

    private struct RenderedMarker {
        let marker: ChartMarkerUI
        let position: CGPoint
        let isSelected: Bool
        let scale: CGFloat
        let sortKey: Int
        let rotation: CGFloat
    }

    static func visibleUsernameMarkerIDs(from candidates: [UsernameLabelCandidate]) -> Set<UUID> {
        var visible = Set<UUID>()
        var occupiedRects: [CGRect] = []

        let sortedCandidates = candidates.sorted {
            if $0.sortKey != $1.sortKey {
                return $0.sortKey < $1.sortKey
            }
            return $0.markerId.uuidString < $1.markerId.uuidString
        }

        for candidate in sortedCandidates {
            let paddedRect = candidate.rect.insetBy(dx: -4, dy: -2)
            let hasCollision = occupiedRects.contains(where: { $0.intersects(paddedRect) })
            if hasCollision {
                continue
            }

            visible.insert(candidate.markerId)
            occupiedRects.append(candidate.rect)
        }

        return visible
    }
    
    static func drawMarkers(
        context: GraphicsContext,
        markers: [ChartMarkerUI],
        candles: [RLCandleDTO],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat,
        markerManager: MarkerManager? = nil,
        selectedMarkerId: UUID? = nil,
        selectedMarkerScale: CGFloat = 1.5,
        selectedMarkerRotation: CGFloat = 0,
        chartData: ChartDataManager? = nil,
        dimmed: Bool = false,
        editingEmojiOverride: (markerId: UUID, emoji: String)? = nil
    ) {
        var markerContext = context
        let isDimmed = dimmed
        if dimmed {
            markerContext.opacity = 0.25
        }

        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        let sortedCandleIndices = groupedMarkers.keys.sorted()

        var renderQueue: [RenderedMarker] = []
        renderQueue.reserveCapacity(allVisibleMarkers.count)

        for candleIndex in sortedCandleIndices {
            guard let markersAtCandle = groupedMarkers[candleIndex] else { continue }
            guard candleIndex >= 0 && candleIndex < candles.count else { continue }
            
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            
            if x < -totalCandleWidth * 2 || x > chartSize.width + totalCandleWidth * 2 {
                continue
            }
            
            let candle = candles[candleIndex]
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let centerX = x + actualCandleWidth / 2
            
            let sortedMarkers = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            var markerPositions: [(marker: ChartMarkerUI, position: CGPoint)] = []
            for marker in sortedMarkers {
                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                    marker: marker,
                    candleHighY: candleHighY,
                    candleLowY: candleLowY,
                    centerX: centerX,
                    priceScale: priceScale,
                    viewportHeight: chartSize.height
                )
                markerPositions.append((marker, position))
            }

            // Nudge non-selected markers away when one is selected (todo 38 — stack safety)
            if let selId = selectedMarkerId,
               let selIdx = markerPositions.firstIndex(where: { $0.marker.id == selId }),
               selectedMarkerScale > 1.0 {
                let sel = markerPositions[selIdx]
                let nudgeAmount: CGFloat = 10
                let stackDir: CGFloat = sel.marker.positionedBelow ? 1.0 : -1.0
                for i in markerPositions.indices where i != selIdx {
                    let other = markerPositions[i]
                    guard other.marker.positionedBelow == sel.marker.positionedBelow else { continue }
                    let otherStack = other.marker.stackIndex
                    let selStack = sel.marker.stackIndex
                    if otherStack == selStack - 1 {
                        markerPositions[i].position.y -= stackDir * nudgeAmount
                    } else if otherStack == selStack + 1 {
                        markerPositions[i].position.y += stackDir * nudgeAmount
                    }
                }
            }
            
            let aboveMarkers = markerPositions.filter { !$0.marker.positionedBelow }.sorted { $0.position.y > $1.position.y }
            let belowMarkers = markerPositions.filter { $0.marker.positionedBelow }.sorted { $0.position.y < $1.position.y }
            
            drawStackedConnectionLines(context: markerContext, markers: aboveMarkers, anchorY: candleHighY, centerX: centerX, isBelow: false)
            drawStackedConnectionLines(context: markerContext, markers: belowMarkers, anchorY: candleLowY, centerX: centerX, isBelow: true)
            for (markerOrder, markerAndPosition) in markerPositions.enumerated() {
                let marker = markerAndPosition.marker
                let position = markerAndPosition.position
                let isSelected = selectedMarkerId == marker.id
                let scale: CGFloat = isSelected ? selectedMarkerScale : 1.0

                renderQueue.append(
                    RenderedMarker(
                        marker: marker,
                        position: position,
                        isSelected: isSelected,
                        scale: scale,
                        sortKey: candleIndex * 10_000 + markerOrder,
                        rotation: isSelected ? selectedMarkerRotation : 0
                    )
                )
            }
        }

        // Username labels removed per todo 38 — author visible in marker detail view

        let glyphQueue = renderQueue.sorted {
            if $0.isSelected != $1.isSelected {
                return !$0.isSelected
            }
            if $0.sortKey != $1.sortKey {
                return $0.sortKey < $1.sortKey
            }
            return $0.marker.id.uuidString < $1.marker.id.uuidString
        }

        for rendered in glyphQueue {
            // Use original undimmed context for selected markers so they stay at full opacity
            let drawContext = (isDimmed && rendered.isSelected) ? context : markerContext
            let emojiOverride: String? = (editingEmojiOverride != nil && rendered.marker.id == editingEmojiOverride?.markerId)
                ? editingEmojiOverride?.emoji : nil
            drawSingleMarker(
                context: drawContext,
                marker: rendered.marker,
                position: rendered.position,
                isBelow: rendered.marker.positionedBelow,
                scale: rendered.scale,
                isSelected: rendered.isSelected,
                rotation: rendered.rotation,
                emojiOverride: emojiOverride
            )
        }
    }
    
    private static func drawStackedConnectionLines(
        context: GraphicsContext,
        markers: [(marker: ChartMarkerUI, position: CGPoint)],
        anchorY: CGFloat,
        centerX: CGFloat,
        isBelow: Bool
    ) {
        guard !markers.isEmpty else { return }

        let baseRadius: CGFloat = MarkerVisualSpec.baseCanvasDiameter / 2
        var previousY = anchorY

        for (_, position) in markers {
            let nearEdge = isBelow ? position.y - baseRadius : position.y + baseRadius

            let linePath = Path { path in
                path.move(to: CGPoint(x: centerX, y: previousY))
                path.addLine(to: CGPoint(x: centerX, y: nearEdge))
            }

            context.stroke(
                linePath,
                with: .color(AppColors.surfaceGray40),
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
            )

            previousY = isBelow ? position.y + baseRadius : position.y - baseRadius
        }
    }
    
    private static func drawSingleMarker(
        context: GraphicsContext,
        marker: ChartMarkerUI,
        position: CGPoint,
        isBelow: Bool,
        scale: CGFloat = 1.0,
        isSelected: Bool = false,
        rotation: CGFloat = 0,
        emojiOverride: String? = nil
    ) {
        var drawContext = context
        if rotation != 0 {
            let radians = rotation * .pi / 180
            drawContext.translateBy(x: position.x, y: position.y)
            drawContext.rotate(by: Angle(radians: Double(radians)))
            drawContext.translateBy(x: -position.x, y: -position.y)
        }

        let baseRadius: CGFloat = MarkerVisualSpec.baseCanvasDiameter / 2
        let scaledRadius = baseRadius * scale
        let diameter = scaledRadius * 2

        let circleRect = CGRect(
            x: position.x - scaledRadius,
            y: position.y - scaledRadius,
            width: diameter,
            height: diameter
        )
        let circlePath = Path(ellipseIn: circleRect)

        let markerSeverity = marker.intent == .alert ? marker.alertSeverity : nil
        let isAlert = marker.intent == .alert && markerSeverity != nil

        // 1. Shadow
        let shadowRect = circleRect.offsetBy(dx: 1, dy: 1)
        drawContext.fill(Path(ellipseIn: shadowRect), with: .color(AppColors.canvasMarkerShadow))

        // 2. Opaque dark base (canvas can't use .ultraThinMaterial — must block chart content)
        drawContext.fill(circlePath, with: .color(AppColors.canvasMarkerFill))

        // 3. Tint overlay — subtle for standard, stronger for alerts
        if isAlert, let severity = markerSeverity {
            drawContext.fill(circlePath, with: .color(severity.color.opacity(0.30)))
        } else {
            drawContext.fill(circlePath, with: .color(Color.white.opacity(0.06)))
        }

        // 4. Stroke — thin white for standard, colored + thicker for alerts
        if isAlert, let severity = markerSeverity {
            drawContext.stroke(
                circlePath,
                with: .color(severity.color.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        } else {
            drawContext.stroke(
                circlePath,
                with: .color(MarkerVisualSpec.glassStrokeColor),
                style: StrokeStyle(lineWidth: MarkerVisualSpec.glassStrokeWidth)
            )
        }

        // 5. Icon — palette rendering via pre-resolved SwiftUI symbols
        let iconSize = MarkerVisualSpec.iconSize(for: diameter, intent: marker.intent)
        if marker.intent == .reaction, let iconChar = emojiOverride ?? marker.selectedEmoji {
            let iconColor = MarkerVisualSpec.iconPrimaryColor(for: marker.intent, severity: markerSeverity)
            drawContext.draw(
                Text(iconChar)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(iconColor),
                at: position
            )
        } else {
            let symbolId = MarkerSymbolID(intent: marker.intent, alertSeverity: markerSeverity, isSelected: isSelected)
            if let resolved = drawContext.resolveSymbol(id: symbolId.tag) {
                let symSize = resolved.size
                let drawRect = CGRect(
                    x: position.x - symSize.width / 2,
                    y: position.y - symSize.height / 2,
                    width: symSize.width,
                    height: symSize.height
                )
                drawContext.draw(resolved, in: drawRect)
            } else {
                // Fallback monochrome if symbol not resolved
                let iconColor = MarkerVisualSpec.iconPrimaryColor(for: marker.intent, severity: markerSeverity)
                drawMonochromeSymbol(
                    context: &drawContext,
                    symbolName: MarkerVisualSpec.symbol(for: marker.intent, severity: markerSeverity),
                    color: iconColor,
                    at: position,
                    maxIconSize: iconSize,
                    yOffset: 0
                )
            }
        }

        // 6. Like count badge
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = isBelow ? -17 : 5
            let badgeRect = CGRect(
                x: position.x + 8,
                y: position.y + badgeOffset,
                width: 14,
                height: 14
            )
            drawContext.fill(Path(roundedRect: badgeRect, cornerRadius: 7), with: .color(AppColors.markerHeartBadge))
            drawContext.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.onAccentForeground),
                at: CGPoint(x: position.x + 15, y: position.y + badgeOffset + 7)
            )
        }
    }

    // drawPaletteSymbol removed — canvas now uses single monochrome icons (Point 93 fix).

    private static func drawMonochromeSymbol(
        context: inout GraphicsContext,
        symbolName: String,
        color: Color,
        at position: CGPoint,
        maxIconSize: CGFloat,
        yOffset: CGFloat
    ) {
        let iconImage = Image(systemName: symbolName)
        var resolvedIcon = context.resolve(iconImage)
        resolvedIcon.shading = .color(color)
        let imageSize = resolvedIcon.size

        guard imageSize.width > 0, imageSize.height > 0 else {
            let fallbackRect = CGRect(
                x: position.x - maxIconSize / 2,
                y: position.y - maxIconSize / 2 + yOffset,
                width: maxIconSize,
                height: maxIconSize
            )
            context.draw(resolvedIcon, in: fallbackRect)
            return
        }

        let scale = min(maxIconSize / imageSize.width, maxIconSize / imageSize.height)
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let iconRect = CGRect(
            x: position.x - drawWidth / 2,
            y: position.y - drawHeight / 2 + yOffset,
            width: drawWidth,
            height: drawHeight
        )
        context.draw(resolvedIcon, in: iconRect)
    }

    // markerPinPath removed — all markers are now glass circles (Point 92).

    private static func usernameLabelCandidate(
        for marker: ChartMarkerUI,
        position: CGPoint,
        scale: CGFloat,
        sortKey: Int
    ) -> UsernameLabelCandidate? {
        let username = marker.author.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return nil }

        let scaledRadius = 15 * scale
        let labelY = marker.positionedBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
        let estimatedWidth = min(140, max(24, CGFloat(username.count) * 5.2 + 10))
        let rect = CGRect(
            x: position.x - estimatedWidth / 2,
            y: labelY - 6,
            width: estimatedWidth,
            height: 12
        )
        return UsernameLabelCandidate(markerId: marker.id, rect: rect, sortKey: sortKey)
    }

    private static func drawUsernameLabel(
        context: GraphicsContext,
        marker: ChartMarkerUI,
        position: CGPoint,
        isBelow: Bool,
        scale: CGFloat
    ) {
        let scaledRadius = 16 * scale
        let labelY = isBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
        let usernameColor = MarkerLabelStyling.usernameColor(for: marker)
        context.draw(
            Text(marker.author.username)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(usernameColor.opacity(0.95)),
            at: CGPoint(x: position.x, y: labelY)
        )
    }
    
    // MARK: - Hit Detection
    
    static func findMarkerAtLocation(
        _ location: CGPoint,
        markers: [ChartMarkerUI],
        candles: [RLCandleDTO],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) -> ChartMarkerUI? {
        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        let hitRadius = MarkerPositionCalculator.hitRadius
        
        let sortedCandleIndices = groupedMarkers.keys.sorted().reversed()
        
        for candleIndex in sortedCandleIndices {
            guard let markersAtCandle = groupedMarkers[candleIndex],
                  candleIndex >= 0 && candleIndex < candles.count else { continue }
            
            let candle = candles[candleIndex]
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            let centerX = x + actualCandleWidth / 2
            
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) * scaledHeight - verticalOffset
            
            let sorted = markersAtCandle.sorted { $0.createdAt < $1.createdAt }
            
            for marker in sorted.reversed() {
                let position = MarkerPositionCalculator.computeMarkerScreenPosition(
                    marker: marker,
                    candleHighY: candleHighY,
                    candleLowY: candleLowY,
                    centerX: centerX,
                    priceScale: priceScale,
                    viewportHeight: chartSize.height
                )

                let distance = hypot(location.x - position.x, location.y - position.y)
                if distance <= hitRadius {
                    return marker
                }
            }
        }
        
        return nil
    }
}

enum MarkerLabelStyling {
    private static let chartBackground = UIColor(AppColors.chartPanelBackgroundAlt)
    private static let minimumContrast: CGFloat = 2.8

    static func usernameColor(for marker: ChartMarkerUI) -> Color {
        let baseColor = UIColor(marker.displayColor)
        let contrast = baseColor.contrastRatio(against: chartBackground)
        if contrast >= minimumContrast {
            return Color(baseColor)
        }

        let deficit = minimumContrast - contrast
        let blendAmount = min(0.6, max(0.2, deficit / minimumContrast))
        return Color(baseColor.blended(with: .white, amount: blendAmount))
    }
}

private extension UIColor {
    var relativeLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        let r = channel(red)
        let g = channel(green)
        let b = channel(blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    func contrastRatio(against color: UIColor) -> CGFloat {
        let a = relativeLuminance
        let b = color.relativeLuminance
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func blended(with color: UIColor, amount: CGFloat) -> UIColor {
        let clampedAmount = min(1.0, max(0.0, amount))
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * clampedAmount,
            green: g1 + (g2 - g1) * clampedAmount,
            blue: b1 + (b2 - b1) * clampedAmount,
            alpha: a1 + (a2 - a1) * clampedAmount
        )
    }
}
