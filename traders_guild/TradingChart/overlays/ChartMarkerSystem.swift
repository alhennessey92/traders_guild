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

extension RLMarkerType {
    /// Per-type dark gradient: red for stop loss, blue for take profit, etc.
    /// Same darkness level for all — uses displayColor scaled down
    func markerBackgroundGradient(displayColor: Color) -> (start: Color, end: Color) {
        (displayColor.markerGradientStart(), displayColor.markerGradientEnd())
    }
    /// Border gradient: reverse direction from fill, brighter colors for contrast.
    /// brightness/opacity params enable future glow and pulse effects.
    func markerBorderGradient(
        displayColor: Color,
        brightness: CGFloat = 1.0,
        opacity: CGFloat = 1.0
    ) -> (start: Color, end: Color) {
        var start = displayColor.markerBorderGradientStart()
        var end = displayColor.markerBorderGradientEnd()
        if brightness != 1.0 {
            start = start.blendedForGlow(brightness: brightness)
            end = end.blendedForGlow(brightness: brightness)
        }
        if opacity != 1.0 {
            start = start.opacity(Double(opacity))
            end = end.opacity(Double(opacity))
        }
        return (start, end)
    }
}

// MARK: - Marker Manager

@MainActor
class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarkerUI] = []
    @Published var selectedMarker: ChartMarkerUI?
    @Published var visibleTypes: Set<RLMarkerType> = Set(RLMarkerType.allCases)
    @Published var visibilityMode: MarkerVisibilityMode = .all
    
    /// Tracks if we should show a "like existing marker" prompt
    @Published var duplicateMarkerToLike: ChartMarkerUI?
    @Published var showDuplicateAlert: Bool = false
    
    private var currentUserId: UUID
    private var currentGuildId: UUID
    private var currentUserMember: RLGuildMemberDTO
    
    /// API service for backend persistence
    private weak var api: RealAPIService?

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
    func configure(api: RealAPIService, symbolId: UUID, timeframe: RLChartTimeframe) {
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
    
    // MARK: - API Loading
    
    func loadMarkersFromAPI(
        api: RealAPIService,
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleRealTimeMessage(message)
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
        default:
            break
        }
    }

    private func handleMarkerCreated(_ message: WSIncomingMessage) {
        guard let markerDTO = message.payload(as: RLChartMarkerDTO.self) else { return }

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
        guard let index = markers.firstIndex(where: { $0.id == markerDTO.id }) else { return }

        // Preserve positioning — only update the DTO
        markers[index] = markers[index].withMarker(markerDTO)
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
    
    func existingMarkerOfType(_ type: RLMarkerType, atCandleIndex candleIndex: Int) -> ChartMarkerUI? {
        return markers.first { marker in
            marker.candleIndex == candleIndex && marker.type == type
        }
    }
    
    /// Find marker by backend marker type string (for RLChartMarkerUI compatibility)
    func existingMarkerOfBackendType(_ backendType: String, atCandleIndex candleIndex: Int) -> ChartMarkerUI? {
        guard let markerType = RLMarkerType.fromBackendString(backendType) else { return nil }
        return existingMarkerOfType(markerType, atCandleIndex: candleIndex)
    }
    
    func canAddMarker(type: RLMarkerType, atCandleIndex candleIndex: Int) -> Bool {
        return existingMarkerOfType(type, atCandleIndex: candleIndex) == nil
    }
    
    // MARK: - Marker CRUD
    
    @discardableResult
    func addMarker(
        symbolId: UUID,
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: RLMarkerType,
        note: String? = nil,
        candles: [RLCandleDTO],
        horizontalLinePrice: Double? = nil,
        targetPrice: Double? = nil,
        stopLossPrice: Double? = nil,
        alertSeverity: MarkerAlertSeverity? = nil,
        trendlineDirection: TrendlineDirection? = nil,
        selectedIndicator: String? = nil,
        chartPattern: ChartPattern? = nil,
        selectedEmoji: String? = nil,
        pollQuestion: String? = nil,
        pollOptions: [String]? = nil
    ) async -> Bool {
        // Validate candle index
        guard candleIndex >= 0 && candleIndex < candles.count else {
            return false
        }
        
        // Check for duplicate type on same candle
        if let existingMarker = existingMarkerOfType(type, atCandleIndex: candleIndex) {
            duplicateMarkerToLike = existingMarker
            showDuplicateAlert = true
            return false
        }
        
        // Calculate line price based on marker type
        var linePrice = horizontalLinePrice
        if type.hasHorizontalLine && linePrice == nil {
            guard candleIndex >= 0 && candleIndex < candles.count else {
                return false
            }
            let candle = candles[candleIndex]
            
            if type == .predictionTarget {
                linePrice = targetPrice ?? candle.close
            } else {
                switch type {
                case .entry, .stopLoss:
                    linePrice = candle.open
                case .exit, .takeProfit:
                    linePrice = candle.close
                case .support:
                    linePrice = candle.low
                case .resistance:
                    linePrice = candle.high
                default:
                    break
                }
            }
        }
        
        let now = Date()
        let tempId = UUID()
        
        let pollOptionsDTO = pollOptions?.map {
            RLPollOptionDTO(id: UUID(), text: $0, voteCount: 0, hasVoted: false)
        }
        
        let timeframeString = currentTimeframe?.toBackendString() ?? RLChartTimeframe.h1.toBackendString()
        let tempMarkerDTO = RLChartMarkerDTO(
            id: tempId,
            symbolId: symbolId,
            guildId: currentGuildId,
            author: currentUserMember,
            candleTimestamp: timestamp,
            timeframe: timeframeString,
            price: price,
            markerType: type.toBackendString(),
            note: note,
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
            horizontalLinePrice: linePrice,
            targetPrice: targetPrice,
            stopLossPrice: stopLossPrice,
            alertSeverity: alertSeverity?.toBackendString(),
            trendlineDirection: trendlineDirection?.rawValue,
            selectedIndicator: selectedIndicator,
            chartPattern: chartPattern?.rawValue,
            selectedEmoji: selectedEmoji,
            pollQuestion: pollQuestion,
            pollOptions: pollOptionsDTO,
            userPollVote: nil
        )
        
        var marker = ChartMarkerUI(marker: tempMarkerDTO, candleIndex: candleIndex)
        
        // Calculate position
        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex
        
        // Optimistic update - add marker immediately
        markers.append(marker)
        
        // Persist to backend
        guard let api = api,
              let timeframe = currentTimeframe else {
            // If no API configured, marker is already added optimistically
            return true
        }
        
        do {
            // Create marker via API
            let createdMarker = try await api.createMarker(
                guildId: currentGuildId,
                symbolId: symbolId,
                candleTimestamp: timestamp,
                timeframe: timeframe.toBackendString(),
                price: price,
                markerType: type.toBackendString(),
                note: note,
                horizontalLinePrice: linePrice,
                targetPrice: targetPrice,
                stopLossPrice: stopLossPrice,
                alertSeverity: alertSeverity?.toBackendString(),
                trendlineDirection: trendlineDirection?.rawValue,
                selectedIndicator: selectedIndicator,
                chartPattern: chartPattern?.rawValue,
                selectedEmoji: selectedEmoji,
                pollQuestion: pollQuestion,
                pollOptions: pollOptions
            )
            
            // Replace optimistic marker with real one from backend
            if let index = markers.firstIndex(where: { $0.id == tempId }) {
                if let candleIndex = findCandleIndex(timestamp: createdMarker.candleTimestamp, in: candles) {
                    var updatedMarker = ChartMarkerUI(marker: createdMarker, candleIndex: candleIndex)
                    updatedMarker.positionedBelow = marker.positionedBelow
                    updatedMarker.proximityTier = marker.proximityTier
                    updatedMarker.stackIndex = marker.stackIndex
                    markers[index] = updatedMarker
                }
            }
            
            return true
        } catch {
            // Revert optimistic update on error
            markers.removeAll { $0.id == tempId }
            print("Failed to create marker: \(error)")
            return false
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
    
    /// Update a marker with any combination of fields (all optional). Only provided fields are sent to the backend.
    func updateMarker(
        id: UUID,
        note: String? = nil,
        price: Double? = nil,
        isVisible: Bool? = nil,
        horizontalLinePrice: Double? = nil,
        targetPrice: Double? = nil,
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
        if let note = note {
            markers[index] = originalMarker.withMarker(originalMarker.marker.updating(note: note))
            syncSelectedMarker(markers[index])
        }

        do {
            let updatedMarker = try await api.updateMarker(
                guildId: currentGuildId,
                markerId: id,
                note: note,
                price: price,
                isVisible: isVisible,
                horizontalLinePrice: horizontalLinePrice,
                targetPrice: targetPrice,
                alertSeverity: alertSeverity,
                trendlineDirection: trendlineDirection,
                selectedIndicator: selectedIndicator,
                chartPattern: chartPattern,
                selectedEmoji: selectedEmoji
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

            if note != nil {
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
    
    func addComment(
        markerId: UUID,
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil
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
                attachmentName: attachmentName
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

        return markers.filter { marker in
            guard marker.isVisible else { return false }
            guard visibleTypes.contains(marker.type) else { return false }
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
    
    @Published var baseOffset: CGFloat {
        didSet { UserDefaults.standard.set(baseOffset, forKey: "markerBaseOffset") }
    }
    
    @Published var stackOffset: CGFloat {
        didSet { UserDefaults.standard.set(stackOffset, forKey: "markerStackOffset") }
    }
    
    @Published var minStackSpacing: CGFloat {
        didSet { UserDefaults.standard.set(minStackSpacing, forKey: "markerMinStackSpacing") }
    }
    
    @Published var proximityTierOffset: CGFloat {
        didSet { UserDefaults.standard.set(proximityTierOffset, forKey: "markerProximityTierOffset") }
    }
    
    @Published var placementExtraOffset: CGFloat {
        didSet { UserDefaults.standard.set(placementExtraOffset, forKey: "markerPlacementExtraOffset") }
    }
    
    private init() {
        self.baseOffset = UserDefaults.standard.object(forKey: "markerBaseOffset") as? CGFloat ?? 70
        self.stackOffset = UserDefaults.standard.object(forKey: "markerStackOffset") as? CGFloat ?? 36
        self.minStackSpacing = UserDefaults.standard.object(forKey: "markerMinStackSpacing") as? CGFloat ?? 34
        self.proximityTierOffset = UserDefaults.standard.object(forKey: "markerProximityTierOffset") as? CGFloat ?? 25
        self.placementExtraOffset = UserDefaults.standard.object(forKey: "markerPlacementExtraOffset") as? CGFloat ?? 40
    }
    
    func resetToDefaults() {
        baseOffset = 70
        stackOffset = 36
        minStackSpacing = 34
        proximityTierOffset = 25
        placementExtraOffset = 40
    }
}

// MARK: - Marker Position Calculator

struct MarkerPositionCalculator {
    
    static var settings: MarkerDisplaySettings { MarkerDisplaySettings.shared }
    static var baseOffset: CGFloat { settings.baseOffset }
    static var stackOffset: CGFloat { settings.stackOffset }
    static var minStackSpacing: CGFloat { settings.minStackSpacing }
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
        priceScale: CGFloat = 1.0
    ) -> CGPoint {
        let baseY: CGFloat
        let stackDirection: CGFloat
        
        let dampenedBaseScale = dampenPriceScale(priceScale, dampening: 0.75)
        let scaledStackOffsetRaw = stackOffset * dampenPriceScale(priceScale, dampening: 0.5)
        let scaledStackOffset = Swift.max(minStackSpacing, scaledStackOffsetRaw)
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
        let markerY = baseY + stackOffsetValue + tierOffset
        
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
        let scaledStackOffset = Swift.max(minStackSpacing, scaledStackOffsetRaw)
        
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
            return aboveCount > belowCount
        }
        
        guard candleIndex >= 0 && candleIndex < candles.count else {
            return false
        }
        
        let candle = candles[candleIndex]
        return candle.isBullish
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
        
        guard candleIndex >= 0 && candleIndex < candles.count else {
            return false
        }
        
        let candle = candles[candleIndex]
        return candle.isBullish
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
        dimmed: Bool = false
    ) {
        var markerContext = context
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
                    priceScale: priceScale
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
            drawSingleMarker(
                context: markerContext,
                marker: rendered.marker,
                position: rendered.position,
                isBelow: rendered.marker.positionedBelow,
                scale: rendered.scale,
                isSelected: rendered.isSelected,
                rotation: rendered.rotation
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
        
        let baseRadius: CGFloat = 14
        var previousY = anchorY
        
        for (marker, position) in markers {
            let markerEdgeY: CGFloat = isBelow ? position.y - baseRadius : position.y + baseRadius
            
            let linePath = Path { path in
                path.move(to: CGPoint(x: centerX, y: previousY))
                path.addLine(to: CGPoint(x: centerX, y: markerEdgeY))
            }
            
            context.stroke(
                linePath,
                with: .color(Color.gray.opacity(0.4)),
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
        rotation: CGFloat = 0
    ) {
        // Apply rotation around marker center for wiggle effect
        var drawContext = context
        if rotation != 0 {
            let radians = rotation * .pi / 180
            drawContext.translateBy(x: position.x, y: position.y)
            drawContext.rotate(by: Angle(radians: Double(radians)))
            drawContext.translateBy(x: -position.x, y: -position.y)
        }

        let baseRadius: CGFloat = 16
        let scaledRadius = baseRadius * scale

        let circleRect = CGRect(
            x: position.x - scaledRadius,
            y: position.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        let circlePath = Path(ellipseIn: circleRect)

        // 1. Shadow
        let shadowRect = CGRect(
            x: position.x - scaledRadius + 1.2,
            y: position.y - scaledRadius + 1.2,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        drawContext.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.28)))

        // 2. Midnight blue gradient background (top → bottom)
        let gradient = marker.type.markerBackgroundGradient(displayColor: marker.displayColor)
        let grad = Gradient(colors: [gradient.start, gradient.end])
        let startPt = CGPoint(x: position.x, y: position.y - scaledRadius)
        let endPt = CGPoint(x: position.x, y: position.y + scaledRadius)
        drawContext.fill(circlePath, with: .linearGradient(grad, startPoint: startPt, endPoint: endPt))

        // 3. Border — gradient (bottom bright → top dim, opposite of fill)
        let borderWidth = isSelected ? AppColors.markerSelectedBorderWidth : AppColors.markerUnselectedBorderWidth
        let borderStart = marker.displayColor.markerBorderGradientStart()
        let borderEnd = marker.displayColor.markerBorderGradientEnd()
        let borderGrad = Gradient(colors: [borderStart, borderEnd])
        let borderStartPt = CGPoint(x: position.x, y: position.y + scaledRadius)  // bottom (bright)
        let borderEndPt = CGPoint(x: position.x, y: position.y - scaledRadius)    // top (dim)
        drawContext.stroke(circlePath, with: .linearGradient(borderGrad, startPoint: borderStartPt, endPoint: borderEndPt), lineWidth: borderWidth)

        // 4. Icon — light grey, bolder sizing (50% of badge diameter)
        let iconColor = AppColors.markerIconLight
        let fontSize: CGFloat = scaledRadius * 1.0
        if marker.type == .emoji {
            let iconChar = marker.selectedEmoji ?? "🎯"
            drawContext.draw(
                Text(iconChar)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(iconColor),
                at: position
            )
        } else if let label = marker.type.shortLabel {
            drawContext.draw(
                Text(label)
                    .font(.system(size: fontSize * 0.9, weight: .bold))
                    .foregroundColor(iconColor),
                at: position
            )
        } else {
            let maxIconSize = scaledRadius * 1.0
            let iconImage = Image(systemName: marker.type.icon)
            var resolvedIcon = drawContext.resolve(iconImage)
            resolvedIcon.shading = GraphicsContext.Shading.color(iconColor)
            let imgSize = resolvedIcon.size
            guard imgSize.width > 0, imgSize.height > 0 else {
                let fallbackRect = CGRect(x: position.x - maxIconSize / 2, y: position.y - maxIconSize / 2, width: maxIconSize, height: maxIconSize)
                drawContext.draw(resolvedIcon, in: fallbackRect)
                return
            }
            // Aspect-fit: preserve icon proportions (avoids vertical squash from draw-in-rect)
            let iconScale = min(maxIconSize / imgSize.width, maxIconSize / imgSize.height)
            let drawW = imgSize.width * iconScale
            let drawH = imgSize.height * iconScale
            let iconRect = CGRect(
                x: position.x - drawW / 2,
                y: position.y - drawH / 2,
                width: drawW,
                height: drawH
            )
            drawContext.draw(resolvedIcon, in: iconRect)
        }

        // 5. Like count badge
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
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 15, y: position.y + badgeOffset + 7)
            )
        }
    }

    private static func usernameLabelCandidate(
        for marker: ChartMarkerUI,
        position: CGPoint,
        scale: CGFloat,
        sortKey: Int
    ) -> UsernameLabelCandidate? {
        let username = marker.author.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return nil }

        let scaledRadius = 16 * scale
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
    
    private static func getIconCharacter(for type: RLMarkerType) -> String {
        switch type {
        case .note: return "✎"
        case .question: return "?"
        case .alert: return "!"
        case .entry: return "↑"
        case .exit: return "↓"
        case .stopLoss: return "✕"
        case .takeProfit: return "✓"
        case .support: return "S"
        case .resistance: return "R"
        case .indicator: return "★"
        case .trendline: return "⤴"
        case .pattern: return "◇"
        case .volumeSpike: return "⚡"
        case .predictionTarget: return "⊛"
        case .emoji: return "☺"
        case .poll: return "☰"
        case .personal: return "●"
        }
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
                    priceScale: priceScale
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
    private static let chartBackground = UIColor(red: 25.0 / 255.0, green: 25.0 / 255.0, blue: 33.0 / 255.0, alpha: 1.0)
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
