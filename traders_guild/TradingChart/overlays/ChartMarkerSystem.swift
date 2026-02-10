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

// MARK: - Marker Manager

@MainActor
class MarkerManager: ObservableObject {
    @Published var markers: [ChartMarkerUI] = []
    @Published var selectedMarker: ChartMarkerUI?
    @Published var visibleTypes: Set<RLMarkerType> = Set(RLMarkerType.allCases)
    @Published var showOnlyMyMarkers: Bool = false
    @Published var markersHidden: Bool = false
    
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
            // Fetch markers from RealAPIService
            let timeframeString = timeframe.toBackendString()
            let markersListDTO = try await api.getMarkers(
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframeString,
                limit: 100
            )
            
            // Convert RLChartMarkerUI to ChartMarkerUI (UI model)
            var convertedMarkers: [ChartMarkerUI] = []
            for rlMarker in markersListDTO.markers {
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
        
        for (index, candle) in candles.enumerated() {
            let diff = abs(candle.timestamp.timeIntervalSince(timestamp))
            if diff < smallestDiff {
                smallestDiff = diff
                closestIndex = index
            }
        }
        return closestIndex
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
    
    func updateMarker(id: UUID, note: String) async {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        
        // Optimistic update
        let originalMarker = markers[index]
        let oldNote = originalMarker.note
        let optimisticMarker = originalMarker.withMarker(originalMarker.marker.updating(note: note))
        markers[index] = optimisticMarker
        
        // Persist to backend
        guard let api = api else { return }
        
        do {
            let updatedMarker = try await api.updateMarker(
                guildId: currentGuildId,
                markerId: id,
                note: note,
                price: nil,
                isVisible: nil,
                horizontalLinePrice: nil,
                targetPrice: nil,
                alertSeverity: nil,
                trendlineDirection: nil,
                selectedIndicator: nil,
                chartPattern: nil,
                selectedEmoji: nil
            )
            
            // Update with real marker from backend (preserve positioning)
            var updated = ChartMarkerUI(marker: updatedMarker, candleIndex: markers[index].candleIndex)
            updated.positionedBelow = markers[index].positionedBelow
            updated.proximityTier = markers[index].proximityTier
            updated.stackIndex = markers[index].stackIndex
            markers[index] = updated
        } catch {
            // Revert optimistic update on error
            markers[index] = originalMarker.withMarker(originalMarker.marker.updating(note: oldNote))
            print("Failed to update marker: \(error)")
        }
    }
    
    func toggleLike(markerId: UUID) async {
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
        
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
        
        // Persist to backend
        guard let api = api else { return }
        
        do {
            let response = try await api.toggleMarkerLike(guildId: currentGuildId, markerId: markerId)
            // Update with real like count from backend
            let updated = markers[index].withMarker(
                markers[index].marker.updating(
                    likeCount: response.likeCount,
                    isLikedByCurrentUser: response.isLiked
                )
            )
            markers[index] = updated
        } catch {
            // Revert optimistic update on error
            markers[index] = currentMarker.withMarker(
                currentMarker.marker.updating(
                    likeCount: oldLikeCount,
                    isLikedByCurrentUser: wasLiked
                )
            )
            print("Failed to toggle like: \(error)")
        }
    }
    
    func addComment(markerId: UUID, content: String) async {
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
        
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
            canDelete: true
        )
        
        let optimisticComments = markers[index].comments + [comment]
        markers[index] = markers[index].withMarker(
            markers[index].marker.updating(
                comments: optimisticComments,
                commentCount: optimisticComments.count
            )
        )
        
        // Persist to backend
        guard let api = api else { return }
        
        do {
            let createdComment = try await api.addMarkerComment(
                guildId: currentGuildId,
                markerId: markerId,
                content: content
            )
            
            // Replace optimistic comment with real one from backend
            var updatedComments = markers[index].comments
            if let commentIndex = updatedComments.firstIndex(where: { $0.id == tempCommentId }) {
                updatedComments[commentIndex] = createdComment
            }
            markers[index] = markers[index].withMarker(
                markers[index].marker.updating(
                    comments: updatedComments,
                    commentCount: updatedComments.count
                )
            )
        } catch {
            // Revert optimistic update on error
            let rolledBackComments = markers[index].comments.filter { $0.id != tempCommentId }
            markers[index] = markers[index].withMarker(
                markers[index].marker.updating(
                    comments: rolledBackComments,
                    commentCount: rolledBackComments.count
                )
            )
            print("Failed to add comment: \(error)")
        }
    }
    
    func deleteComment(markerId: UUID, commentId: UUID) {
        guard let markerIndex = markers.firstIndex(where: { $0.id == markerId }) else { return }
        let updatedComments = markers[markerIndex].comments.filter { $0.id != commentId }
        markers[markerIndex] = markers[markerIndex].withMarker(
            markers[markerIndex].marker.updating(
                comments: updatedComments,
                commentCount: updatedComments.count
            )
        )
    }
    
    var filteredMarkers: [ChartMarkerUI] {
        if markersHidden { return [] }
        
        return markers.filter { marker in
            guard marker.isVisible else { return false }
            guard visibleTypes.contains(marker.type) else { return false }
            if showOnlyMyMarkers && !marker.isCurrentUserMarker {
                return false
            }
            return true
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
        chartData: ChartDataManager? = nil
    ) {
        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        
        for (candleIndex, markersAtCandle) in groupedMarkers {
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
            let hideUsernames = markersAtCandle.count > 1
            
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
            
            let aboveMarkers = markerPositions.filter { !$0.marker.positionedBelow }.sorted { $0.position.y > $1.position.y }
            let belowMarkers = markerPositions.filter { $0.marker.positionedBelow }.sorted { $0.position.y < $1.position.y }
            
            drawStackedConnectionLines(context: context, markers: aboveMarkers, anchorY: candleHighY, centerX: centerX, isBelow: false)
            drawStackedConnectionLines(context: context, markers: belowMarkers, anchorY: candleLowY, centerX: centerX, isBelow: true)
            
            for (marker, position) in markerPositions {
                let isSelected = selectedMarkerId == marker.id
                let scale: CGFloat = isSelected ? 1.3 : 1.0
                
                drawSingleMarker(
                    context: context,
                    marker: marker,
                    position: position,
                    isBelow: marker.positionedBelow,
                    scale: scale,
                    hideUsername: hideUsernames,
                    isSelected: isSelected
                )
            }
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
                with: .color(Color.gray.opacity(0.6)),
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
        hideUsername: Bool = false,
        isSelected: Bool = false
    ) {
        let baseRadius: CGFloat = 16
        let scaledRadius = baseRadius * scale
        
        // Selection glow effect
        if isSelected {
            let glowRect = CGRect(
                x: position.x - scaledRadius - 4,
                y: position.y - scaledRadius - 4,
                width: (scaledRadius + 4) * 2,
                height: (scaledRadius + 4) * 2
            )
            context.fill(Path(ellipseIn: glowRect), with: .color(marker.type.color.opacity(0.3)))
        }
        
        // Shadow
        let shadowRect = CGRect(
            x: position.x - scaledRadius + 1.5,
            y: position.y - scaledRadius + 1.5,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.35)))
        
        // Main circle
        let circleRect = CGRect(
            x: position.x - scaledRadius,
            y: position.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        )
        
        // Fill
        context.fill(Path(ellipseIn: circleRect), with: .color(marker.type.color.opacity(0.3)))
        
        // Border
        let strokeWidth: CGFloat = isSelected ? 3 : 2
        context.stroke(Path(ellipseIn: circleRect), with: .color(marker.type.color), lineWidth: strokeWidth)
        
        // Icon character
        let iconChar = getIconCharacter(for: marker.type)
        let fontSize: CGFloat = 14 * scale
        context.draw(
            Text(iconChar)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(marker.type.color),
            at: position
        )
        
        // Like count badge
        if marker.likeCount > 0 {
            let badgeOffset: CGFloat = isBelow ? -17 : 5
            let badgeRect = CGRect(
                x: position.x + 8,
                y: position.y + badgeOffset,
                width: 14,
                height: 14
            )
            context.fill(Path(roundedRect: badgeRect, cornerRadius: 7), with: .color(.red))
            context.draw(
                Text("\(marker.likeCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white),
                at: CGPoint(x: position.x + 15, y: position.y + badgeOffset + 7)
            )
        }
        
        // Username label
        if !hideUsername {
            let labelY = isBelow ? position.y + scaledRadius + 10 : position.y - scaledRadius - 10
            context.draw(
                Text(marker.author.displayName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.85)),
                at: CGPoint(x: position.x, y: labelY)
            )
        }
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
        case .poll: return "✓"
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

