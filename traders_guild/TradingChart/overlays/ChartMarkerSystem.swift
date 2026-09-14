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
    /// Carries the created/updated server marker when available (nil for the
    /// offline / optimistic-only path), so callers can offer post-placement sharing.
    case success(RLChartMarkerDTO?)
    case failure(MarkerPlacementFailure)

    /// Case check that ignores the associated marker (handy for assertions/call
    /// sites that only care that placement succeeded).
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
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
    /// One marker by id, with the viewer's own permission flags. Used when a
    /// marker is known to exist but the window fetch did not contain it.
    func getMarker(markerId: UUID) async throws -> RLChartMarkerDTO
    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO
    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO
    /// Returns the richer 1.3.0 acknowledgement, which still carries `detail`
    /// and adds the parent reconciliation metadata. Older servers omit the new
    /// fields and decode to nil.
    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLMarkerDeleteResponseDTO
    /// One bounded window onto a thesis. `cursor` continues either ancestry or a
    /// branch, depending on which cursor it came from.
    func getMarkerThread(markerId: UUID, cursor: String?) async throws -> RLMarkerThreadResponseDTO
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
    private struct LayoutContext: Equatable {
        let guildId: UUID
        let symbolId: UUID
        let timeframe: RLChartTimeframe
    }

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
    @Published var selectedMarker: ChartMarkerUI? {
        didSet {
            // Focus is a pure function of the selection and what is loaded, so
            // it is recomputed here rather than at every call site that can
            // change the selection.
            guard oldValue?.id != selectedMarker?.id else { return }
            // Painted members describe the *previous* thesis until the next
            // frame reports. Carrying them into a new selection would derive
            // focus from the wrong set — and the fade latch would then hold
            // that wrong answer for the life of the selection.
            renderedMarkerIds = nil
            refreshLinkFocus()
        }
    }
    // Changing a filter is a deliberate act, not a race, so the fade latch is
    // dropped and the ">= 2 visible members" rule re-applies. Progressive page
    // arrivals deliberately do *not* do this — that is what the latch prevents.
    @Published var visibleIntents: Set<RLMarkerIntent> = Set(RLMarkerIntent.allCases) {
        didSet {
            clearFadeLatch()
            refreshLinkFocus()
        }
    }
    @Published var visibilityMode: MarkerVisibilityMode = .all {
        didSet {
            clearFadeLatch()
            refreshLinkFocus()
        }
    }
    
    /// Tracks if we should show a "like existing marker" prompt
    @Published var duplicateMarkerToLike: ChartMarkerUI?
    @Published var showDuplicateAlert: Bool = false

    // MARK: - Linked markers

    /// The synchronously-derived focus decision for the current selection.
    /// `nil` whenever nothing is selected or the selection is standalone.
    ///
    /// Derived state: assign it only from `refreshLinkFocus()`, which lives in
    /// `MarkerManager+Links.swift` and therefore needs an internal setter.
    @Published var linkFocus: MarkerFocusState?

    /// Server capability. While false the chart behaves exactly as 1.2.1 did:
    /// existing links still decode and render as ordinary markers, but no
    /// rings, connectors, badges or respond affordances appear.
    @Published var linkedMarkersEnabled: Bool = false {
        didSet {
            guard oldValue != linkedMarkersEnabled else { return }
            refreshLinkFocus()
        }
    }

    /// Whether the authenticated viewer can moderate in the current guild.
    ///
    /// Held here so a realtime payload's permission flags — which describe the
    /// member who acted, not the member reading — can be replaced with locally
    /// derived ones. Defaults to false: a wrong `true` offers a delete that the
    /// server refuses, a wrong `false` only hides an affordance a refresh
    /// restores.
    @Published var viewerCanModerate: Bool = false

    /// Newest absolute response counts, applied monotonically and *before* any
    /// symbol/timeframe filtering.
    var responseCounts = MarkerResponseCountReconciler()

    /// Latched for the life of one selection so the chart cannot flicker
    /// between dimmed and undimmed as progressive pages arrive.
    private var latchedFadeDecision: (selectionId: UUID, shouldFade: Bool)?

    var fadeLatch: (selectionId: UUID, shouldFade: Bool)? { latchedFadeDecision }

    func setFadeLatch(selectionId: UUID, shouldFade: Bool) {
        latchedFadeDecision = (selectionId, shouldFade)
    }

    func clearFadeLatch() {
        latchedFadeDecision = nil
    }

    /// Internal accessor so the linked-marker extension, which lives in its own
    /// file, can reach the client without widening `api` itself.
    var markerAPI: (any MarkerAPIClient)? { api }

    /// Thesis cache, owned by app state so it outlives this manager's layout
    /// teardown. Weak: the store belongs to the session, not to the chart.
    weak var threadStore: MarkerThreadStore?

    /// The first `.connected` is the initial connection, not a reconnect, and
    /// must not throw away a cache that was just populated.
    private var hasConnectedRealTimeOnce = false

    /// Thesis members the renderer actually painted, reported after viewport
    /// culling.
    ///
    /// Deliberately members only, not every painted marker: the fade rule asks
    /// how many *related* glyphs are visible, so anything else would be
    /// collected and compared for nothing on the pan path. Nil before the first
    /// focused frame, when `filteredMarkers` is the best available answer.
    private(set) var renderedMarkerIds: Set<UUID>?

    /// Called by the chart when the painted member set changes.
    ///
    /// The renderer only calls this on an actual change, and this guards again:
    /// re-deriving focus rebuilds the whole link topology, which must never sit
    /// on the pan path.
    ///
    /// - Parameter selectionId: the selection the report describes. The call is
    ///   deferred to the main actor from inside a draw pass, so the selection
    ///   can have moved on before it lands; a report about the previous thesis
    ///   would otherwise install that thesis's painted set as the new one's.
    func reportRenderedMarkers(_ ids: Set<UUID>, forSelection selectionId: UUID) {
        guard selectedMarker?.id == selectionId else { return }
        guard renderedMarkerIds != ids else { return }
        renderedMarkerIds = ids
        // The latch protects the fade decision from topology churn *between*
        // paints — progressive pages, realtime arrivals. It must not outlive a
        // change in what is actually painted, which is the very input the
        // "fewer than two visible members" rule is about.
        clearFadeLatch()
        refreshLinkFocus()
    }


    private var currentUserId: UUID
    private var currentGuildId: UUID
    private var currentUserMember: RLGuildMemberDTO
    
    /// API service for backend persistence
    private weak var api: (any MarkerAPIClient)?

    /// Current symbol ID for API calls
    private var currentSymbolId: UUID?

    /// Current timeframe for API calls
    private var currentTimeframe: RLChartTimeframe?

    /// The chart context that owns the current marker layout assignments.
    ///
    /// A refresh inside one context carries slots forward by marker ID and
    /// anchor timestamp. Moving to another guild, symbol or timeframe starts a
    /// clean allocation so layout state can never leak between charts.
    private var layoutContext: LayoutContext?

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
        // Discard loads whose candle array belongs to a different timeframe than the one being
        // loaded — a stale race during a rapid timeframe/symbol switch. Positioning against a
        // mismatched array assigns wrong candle indices (see candleArrayMatchesTimeframe).
        guard candleArrayMatchesTimeframe(candles, timeframe) else {
            print("⏭️ [Markers] Skipping load — candle array does not match timeframe \(timeframe.rawValue)")
            return
        }

        let requestedContext = LayoutContext(
            guildId: guildId,
            symbolId: symbolId,
            timeframe: timeframe
        )
        let shouldPreserveAssignments = activateLayoutContext(requestedContext)

        // Configure MarkerManager with API for persistence
        configure(api: api, symbolId: symbolId, timeframe: timeframe)

        // Update guild context so marker create/delete/like use the correct guild
        self.currentGuildId = guildId
        
        do {
            let fetchedMarkers = try await fetchMarkerDTOs(
                api: api,
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframe,
                startTime: candles.first?.timestamp,
                endTime: candles.last?.timestamp
            )
            let convertedMarkers = positionedMarkers(from: fetchedMarkers, candles: candles)

            // Another symbol/timeframe may have won the race while the request
            // was in flight. Never publish markers (or their slots) into it.
            guard layoutContext == requestedContext else { return }

            await MainActor.run {
                let markersWithPreservedAssignments = shouldPreserveAssignments
                    ? MarkerPositionCalculator.retainingStableAssignments(
                        in: convertedMarkers,
                        from: self.markers
                    )
                    : convertedMarkers
                self.markers = MarkerPositionCalculator.assignStablePositions(
                    markers: markersWithPreservedAssignments,
                    candles: candles
                )
            }

            // Subscribe to real-time marker events for this guild
            subscribeToMarkerChannel(guildId: guildId)
        } catch {
            print("Failed to load markers: \(error)")
        }
    }

    /// Fetch one marker by id and place it on `candles`.
    ///
    /// The window fetch that fills `markers` is bounded by the candles the
    /// chart was given at load time, so a marker on a candle that arrived
    /// afterwards — the live candle, or one the persisted series had not
    /// reached yet — is not in it and never will be until the next reload.
    /// Navigation knows the id it is travelling to, so it can ask for that
    /// marker directly instead of failing because the window happened not to
    /// contain it.
    ///
    /// Returns the loaded copy if the marker is already here. Returns nil when
    /// the marker cannot be shown on this chart: another symbol, timeframe or
    /// guild; a private marker that is not ours; the context changed while the
    /// request was in flight; or no loaded candle within tolerance of its
    /// timestamp — a candle the backend never persisted is not conjured.
    @discardableResult
    func loadMarker(id: UUID, candles: [RLCandleDTO]) async -> ChartMarkerUI? {
        if let existing = markers.first(where: { $0.id == id }) {
            return existing
        }
        guard let api,
              let currentSymbolId,
              let currentTf = currentTimeframe,
              candleArrayMatchesTimeframe(candles, currentTf) else { return nil }
        let requestedContext = layoutContext

        let dto: RLChartMarkerDTO
        do {
            dto = try await api.getMarker(markerId: id)
        } catch {
            print("Failed to load marker \(id): \(error)")
            return nil
        }

        guard layoutContext == requestedContext,
              dto.symbolId == currentSymbolId,
              dto.guildId == currentGuildId,
              dto.timeframe == currentTf.toBackendString(),
              canRenderMarker(dto) else { return nil }

        return await MainActor.run { () -> ChartMarkerUI? in
            // The window fetch or a realtime create may have landed it meanwhile.
            if let existing = markers.first(where: { $0.id == id }) {
                return existing
            }
            guard let candleIndex = findCandleIndex(timestamp: dto.candleTimestamp, in: candles) else {
                return nil
            }
            // A by-id read carries the viewer's own flags, unlike the create
            // broadcast, so nothing needs re-deriving here.
            var marker = ChartMarkerUI(marker: dto, candleIndex: candleIndex)
            let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
                marker: marker,
                existingMarkers: markers,
                candles: candles
            )
            marker.positionedBelow = positioning.isBelow
            marker.proximityTier = positioning.tier
            marker.stackIndex = positioning.stackIndex
            marker.hasStableLayout = true
            markers.append(marker)
            return marker
        }
    }

    func mergeMarkersFromAPI(
        api: any MarkerAPIClient,
        symbolId: UUID,
        symbol: String,
        guildId: UUID,
        timeframe: RLChartTimeframe,
        candles: [RLCandleDTO],
        startTime: Date?,
        endTime: Date?
    ) async {
        // Discard merges whose candle array belongs to a different timeframe than the one being
        // loaded — a stale race during a rapid timeframe/symbol switch (see candleArrayMatchesTimeframe).
        guard candleArrayMatchesTimeframe(candles, timeframe) else {
            print("⏭️ [Markers] Skipping merge — candle array does not match timeframe \(timeframe.rawValue)")
            return
        }

        let requestedContext = LayoutContext(
            guildId: guildId,
            symbolId: symbolId,
            timeframe: timeframe
        )
        _ = activateLayoutContext(requestedContext)
        configure(api: api, symbolId: symbolId, timeframe: timeframe)
        self.currentGuildId = guildId

        do {
            let fetchedMarkers = try await fetchMarkerDTOs(
                api: api,
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframe,
                startTime: startTime,
                endTime: endTime
            )
            let newMarkers = positionedMarkers(from: fetchedMarkers, candles: candles)

            guard layoutContext == requestedContext else { return }

            await MainActor.run {
                var mergedById: [UUID: ChartMarkerUI] = [:]
                for marker in self.markers {
                    mergedById[marker.id] = marker
                }
                for marker in newMarkers {
                    var refreshed = marker
                    if let existing = mergedById[marker.id],
                       existing.candleTimestamp == marker.candleTimestamp {
                        refreshed.positionedBelow = existing.positionedBelow
                        refreshed.proximityTier = existing.proximityTier
                        refreshed.stackIndex = existing.stackIndex
                        refreshed.hasStableLayout = existing.hasStableLayout
                    }
                    mergedById[marker.id] = refreshed
                }

                var mergedMarkers = Array(mergedById.values)
                let indexByTimestamp = self.candleIndexMap(for: candles)
                for i in 0..<mergedMarkers.count {
                    if let newIndex = self.findCandleIndex(
                        timestamp: mergedMarkers[i].candleTimestamp,
                        in: candles,
                        indexByTimestamp: indexByTimestamp
                    ) {
                        mergedMarkers[i].candleIndex = newIndex
                    }
                }
                mergedMarkers.sort { $0.createdAt < $1.createdAt }
                mergedMarkers = MarkerPositionCalculator.assignStablePositions(
                    markers: mergedMarkers,
                    candles: candles
                )
                self.markers = mergedMarkers
                if let selected = self.selectedMarker,
                   let refreshed = mergedMarkers.first(where: { $0.id == selected.id }) {
                    self.selectedMarker = refreshed
                }
            }

            subscribeToMarkerChannel(guildId: guildId)
        } catch {
            print("Failed to merge markers: \(error)")
        }
    }

    private func fetchMarkerDTOs(
        api: any MarkerAPIClient,
        guildId: UUID,
        symbolId: UUID,
        timeframe: RLChartTimeframe,
        startTime: Date?,
        endTime: Date?
    ) async throws -> [RLChartMarkerDTO] {
        let timeframeString = timeframe.toBackendString()
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

        return fetchedMarkers
    }

    private func positionedMarkers(
        from fetchedMarkers: [RLChartMarkerDTO],
        candles: [RLCandleDTO]
    ) -> [ChartMarkerUI] {
        var convertedMarkers: [ChartMarkerUI] = []
        let indexByTimestamp = candleIndexMap(for: candles)
        for rlMarker in fetchedMarkers {
            guard canRenderMarker(rlMarker) else { continue }
            if let candleIndex = findCandleIndex(
                timestamp: rlMarker.candleTimestamp,
                in: candles,
                indexByTimestamp: indexByTimestamp
            ) {
                convertedMarkers.append(ChartMarkerUI(marker: rlMarker, candleIndex: candleIndex))
            }
        }

        for i in 0..<convertedMarkers.count {
            convertedMarkers[i].positionedBelow = false
            convertedMarkers[i].proximityTier = 0
            convertedMarkers[i].stackIndex = 0
            convertedMarkers[i].isVisible = true
        }

        convertedMarkers.sort { $0.createdAt < $1.createdAt }
        return convertedMarkers
    }

    /// Select the owner of all in-memory marker slots.
    ///
    /// The return value tells a full API refresh whether the existing wrappers
    /// belong to the same chart and may safely donate their assignments.
    @discardableResult
    private func activateLayoutContext(_ context: LayoutContext) -> Bool {
        let shouldPreserveAssignments = layoutContext == context
        guard !shouldPreserveAssignments else { return true }

        let guildChanged = layoutContext?.guildId != context.guildId
        layoutContext = context
        markers.removeAll()
        selectedMarker = nil
        linkFocus = nil
        clearFadeLatch()
        // Counts survive a symbol or timeframe move — they are absolute and
        // keyed by marker id, so returning to a chart must not roll a badge
        // back to whatever a cached list payload happens to say. A guild change
        // is a different scope entirely and clears them.
        if guildChanged {
            responseCounts.removeAll()
            unsubscribeFromMarkerChannel()
        }
        return false
    }

    private func candleIndexMap(for candles: [RLCandleDTO]) -> [Date: Int] {
        var indexByTimestamp: [Date: Int] = [:]
        indexByTimestamp.reserveCapacity(candles.count)
        for (index, candle) in candles.enumerated() {
            indexByTimestamp[candle.timestamp] = index
        }
        return indexByTimestamp
    }

    private func findCandleIndex(
        timestamp: Date,
        in candles: [RLCandleDTO],
        indexByTimestamp: [Date: Int]? = nil
    ) -> Int? {
        guard !candles.isEmpty else { return nil }
        if let exactIndex = indexByTimestamp?[timestamp] {
            return exactIndex
        }

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

    /// Guard against positioning markers onto a candle array from a *different* timeframe.
    ///
    /// During a rapid symbol/timeframe switch (e.g. navigating to a 4h marker, then switching
    /// to 5m before the 5m candles arrive), an in-flight marker load can run with the new
    /// timeframe but the previous timeframe's candle array still in place. Because candle-index
    /// matching uses a spacing-relative tolerance, markers then snap onto the wrong (sparser)
    /// candles and keep those stale indices when the correct candles load — surfacing as a mass
    /// of mis-placed markers that navigate to arbitrary positions. Adjacent timeframes differ by
    /// ≥2x in spacing, so comparing the array's median spacing to the expected timeframe spacing
    /// reliably detects the mismatch.
    private func candleArrayMatchesTimeframe(_ candles: [RLCandleDTO], _ timeframe: RLChartTimeframe) -> Bool {
        guard candles.count > 1 else { return true } // not enough data to judge — allow

        var diffs: [TimeInterval] = []
        diffs.reserveCapacity(candles.count - 1)
        for idx in 1..<candles.count {
            let diff = candles[idx].timestamp.timeIntervalSince(candles[idx - 1].timestamp)
            if diff > 0 { diffs.append(diff) }
        }
        guard !diffs.isEmpty else { return true }

        let sorted = diffs.sorted()
        let median = sorted[sorted.count / 2]
        let expected = timeframe.seconds
        guard expected > 0 else { return true }

        // Same-timeframe arrays land at ratio ≈ 1.0 (crypto is exact; weekend/DST/month-length
        // irregularity on higher timeframes stays well within this band because the median is
        // dominated by regular steps). Any other timeframe sits ≥2x away.
        let ratio = median / expected
        return ratio >= 0.6 && ratio <= 1.7
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

        // Events missed while the socket was down may have changed, deleted or
        // hidden nodes in a cached thesis, so every window is dropped on
        // reconnect rather than trusted.
        RealTimeService.shared.$connectionStatus
            .removeDuplicates()
            .sink { [weak self] status in
                guard status == .connected else { return }
                Task { @MainActor [weak self] in
                    self?.handleRealTimeReconnected()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func handleRealTimeReconnected() {
        guard hasConnectedRealTimeOnce else {
            hasConnectedRealTimeOnce = true
            return
        }
        threadStore?.invalidateAll(reason: .reconnect)
        // Counts observed before the socket dropped may have moved while it was
        // down, and nothing will re-announce them. The loaded chart is
        // refreshed from the server rather than trusted.
        responseCounts.removeAll()
        Task { @MainActor [weak self] in
            await self?.refreshMarkersAfterReconnect()
        }
    }

    /// Re-read the current chart's markers so counts reflect what was missed.
    @MainActor
    private func refreshMarkersAfterReconnect() async {
        guard let api,
              let symbolId = currentSymbolId,
              let timeframe = currentTimeframe,
              let candles = dataManager?.candles,
              !candles.isEmpty else { return }
        await loadMarkersFromAPI(
            api: api,
            symbolId: symbolId,
            symbol: "",
            guildId: currentGuildId,
            timeframe: timeframe,
            candles: candles
        )
    }

    private func subscribeToMarkerChannel(guildId: UUID) {
        let channel = "guild:\(guildId.uuidString.lowercased()):markers"
        guard currentMarkerChannel != channel else { return }

        unsubscribeFromMarkerChannel()
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

        // Absolute counts are reconciled BEFORE any symbol/timeframe filtering.
        // A response placed on another timeframe still changes the badge on a
        // parent the viewer is looking at here, and every guard below would
        // otherwise discard that correction.
        applyLinkCounts(from: markerDTO)
        // A new response changes how the server would render its thesis —
        // including branches not yet loaded — so the cached window is dropped.
        invalidateThreadsTouched(by: markerDTO)

        guard canRenderMarker(markerDTO) else { return }

        // Filter to current symbol and timeframe
        guard markerDTO.symbolId == currentSymbolId,
              let currentTf = currentTimeframe,
              markerDTO.timeframe == currentTf.toBackendString() else { return }

        // Dedup — ignore if already present
        guard !markers.contains(where: { $0.id == markerDTO.id }) else { return }

        // Don't position against a candle array from a different timeframe — during a
        // timeframe switch the marker's timeframe can already match `currentTf` while the
        // previous timeframe's candles are still in place (see candleArrayMatchesTimeframe).
        guard let candles = dataManager?.candles,
              candleArrayMatchesTimeframe(candles, currentTf),
              let candleIndex = findCandleIndex(timestamp: markerDTO.candleTimestamp, in: candles) else { return }

        // A created marker has no loaded copy to merge against, but its
        // permission flags are just as much the creator's — this is the payload
        // that hands every recipient an Edit affordance on someone else's
        // marker. Derived rather than merged, since there is nothing to preserve.
        var marker = ChartMarkerUI(
            marker: locallyPermissioned(markerDTO),
            candleIndex: candleIndex
        )

        let positioning = MarkerPositionCalculator.calculatePositionForNewMarker(
            marker: marker,
            existingMarkers: markers,
            candles: candles
        )
        marker.positionedBelow = positioning.isBelow
        marker.proximityTier = positioning.tier
        marker.stackIndex = positioning.stackIndex
        marker.hasStableLayout = true

        markers.append(marker)
    }

    private func handleMarkerUpdated(_ message: WSIncomingMessage) {
        guard let markerDTO = message.payload(as: RLChartMarkerDTO.self) else { return }

        // Counts ride on updates too, not only creations, and are absolute — so
        // they are applied before any render guard can discard the payload.
        applyLinkCounts(from: markerDTO)
        invalidateThreadsTouched(by: markerDTO)

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

        // Preserve positioning while the anchor is unchanged. An anchor edit is
        // a new ID+timestamp layout identity and takes the next free slot at its
        // new candle instead of carrying a stale assignment across the chart.
        //
        // Two corrections before the payload replaces what is loaded. The count
        // comes from the reconciler, because an update whose revision was just
        // rejected as older must not write its stale count back over the newer
        // one. And engagement and permissions go through `neutralMerge`, which
        // keeps this viewer's like and votes and re-derives their own
        // permissions rather than adopting whatever the payload happens to
        // carry.
        var updated = markers[index].withMarker(
            neutralMerge(withReconciledCount(markerDTO), into: markers[index].marker)
        )
        if !updated.hasStableLayout {
            guard let candles = dataManager?.candles,
                  let currentTf = currentTimeframe,
                  candleArrayMatchesTimeframe(candles, currentTf),
                  let newCandleIndex = findCandleIndex(
                    timestamp: markerDTO.candleTimestamp,
                    in: candles
                  ) else {
                markers.remove(at: index)
                if selectedMarker?.id == markerDTO.id {
                    selectedMarker = nil
                }
                return
            }
            updated.candleIndex = newCandleIndex
            let assignment = MarkerPositionCalculator.calculatePositionForNewMarker(
                marker: updated,
                existingMarkers: markers.enumerated().compactMap { offset, marker in
                    offset == index ? nil : marker
                },
                candles: candles
            )
            updated.positionedBelow = assignment.isBelow
            updated.proximityTier = assignment.tier
            updated.stackIndex = assignment.stackIndex
            updated.hasStableLayout = true
        }
        markers[index] = updated
        syncSelectedMarker(updated)
    }

    private func handleMarkerDeleted(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: MarkerDeletedPayload.self),
              let markerId = UUID(uuidString: payload.markerId) else { return }

        // As with creation, the parent's post-delete count is absolute and is
        // applied regardless of which chart the deleted marker belonged to.
        applyLinkCounts(fromDeletion: payload)

        // The thesis this marker belonged to now has a hole in it; the server
        // renders that as a tombstone, so the cached window is stale. Routed
        // through the same escalating path as creation: a deletion on a branch
        // nobody has paged into is invisible to an id lookup.
        invalidateThreadsTouched(byDeletionOf: payload)

        markers.removeAll { $0.id == markerId }
        responseCounts.forget(markerId)
        if selectedMarker?.id == markerId {
            selectedMarker = nil
        }

        recalculateAllPositions()
        refreshLinkFocus()
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

        // Counts and thesis invalidation happen before the loaded-marker guard,
        // for the same reason they do on create and update: a tracking snapshot
        // for a marker on another timeframe — or one not loaded here at all —
        // still carries an absolute count for its parent and still changes how
        // the server would render its thesis. Doing this inside the guard meant
        // both corrections were dropped exactly when the viewer could not see
        // the marker for themselves.
        if let markerDTO = payload.marker {
            applyLinkCounts(from: markerDTO)
            invalidateThreadsTouched(by: markerDTO)
        }

        if let index = markers.firstIndex(where: { $0.id == markerId }) {
            let updated: ChartMarkerUI
            if let markerDTO = payload.marker {
                updated = markers[index].withMarker(
                    neutralMerge(withReconciledCount(markerDTO), into: markers[index].marker)
                )
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
        let indexByTimestamp = candleIndexMap(for: candles)
        // Remove markers whose candles no longer exist in the visible window
        markers.removeAll { marker in
            findCandleIndex(
                timestamp: marker.candleTimestamp,
                in: candles,
                indexByTimestamp: indexByTimestamp
            ) == nil
        }
        // Update indices for remaining markers
        for i in 0..<markers.count {
            if let newIndex = findCandleIndex(
                timestamp: markers[i].candleTimestamp,
                in: candles,
                indexByTimestamp: indexByTimestamp
            ) {
                markers[i].candleIndex = newIndex
            }
        }
        markers = MarkerPositionCalculator.assignStablePositions(markers: markers, candles: candles)
        // A list payload can be older than a count we already reconciled, so
        // known-newer values are written back before focus is derived.
        reconcileLoadedCounts()
        // A cross-timeframe jump lands here: the marker it travelled to has
        // just become available, so the staged selection can be honoured.
        restorePendingLinkSelection()
        refreshLinkFocus()
    }

    func clearMarkers() {
        markers.removeAll()
        linkFocus = nil
        clearFadeLatch()
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
        marker.hasStableLayout = true
        markers.append(marker)

        guard let api else {
            return .success(nil)
        }

        do {
            let created = try await api.createMarkerV2(guildId: currentGuildId, request: request)
            // HTTP create is authoritative for the creator: the realtime echo
            // of their own marker is suppressed server-side, so this is the
            // only place the author learns their parent's new count — and the
            // only place their own cached thesis can be invalidated. Everyone
            // else gets both from `marker_created`; the author gets neither.
            applyLinkCounts(from: created)
            invalidateThreadsTouched(by: created)
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
                updated.hasStableLayout = true
                markers[idx] = updated
            }
            NotificationCenter.default.post(name: .markerCreatedSuccessfully, object: nil)
            return .success(created)
        } catch {
            markers.removeAll { $0.id == tempId }
            print("Failed to create marker v2: \(error)")
            return .failure(MarkerPlacementFailure.from(error: error, fallback: .genericCreateFailure))
        }
    }

    /// Delete a marker, server first.
    ///
    /// Deliberately **not** optimistic. This used to remove the marker and
    /// clear the selection before asking the server, then push the row back on
    /// failure — and with no `api` configured it removed the marker and
    /// returned, so a marker that was never deleted looked deleted until the
    /// next fetch. That is tolerable for a debug affordance and not for an
    /// action a member can reach: the one thing a destructive control must
    /// never do is report success it did not get.
    ///
    /// Permission is checked against the loaded marker's own `canDelete`, which
    /// `neutralMerge` derives locally rather than adopting from a broadcast, so
    /// a payload serialized for its author cannot talk this client into
    /// offering a delete the server will refuse.
    @discardableResult
    func deleteMarker(id: UUID) async -> MarkerDeleteOutcome {
        guard let target = markers.first(where: { $0.id == id }) else {
            return .notFound
        }
        guard target.canDelete else { return .notPermitted }
        guard let api else { return .failed }

        let acknowledgement: RLMarkerDeleteResponseDTO
        do {
            acknowledgement = try await api.deleteMarker(guildId: currentGuildId, markerId: id)
        } catch {
            // Nothing was removed, so there is nothing to put back. The caller
            // surfaces this; the marker is still on the chart and still
            // selected, which is the truth.
            return .failed
        }

        markers.removeAll { $0.id == id }
        // Only clear a selection that is still the marker we deleted: the user
        // may have tapped another marker while the request was in flight, and
        // dropping that selection would be a second surprise.
        if selectedMarker?.id == id {
            selectedMarker = nil
        }
        // Same reasoning as create: the author never receives their own
        // delete event, so the parent's corrected count — and the
        // invalidation of the thesis they just put a hole in — arrive here.
        applyLinkCounts(fromDeletion: acknowledgement)
        invalidateThreadsTouched(byDeletionOf: acknowledgement)
        responseCounts.forget(id)
        recalculateAllPositions()
        refreshLinkFocus()
        return .deleted
    }

    private struct MarkerLayoutSnapshot {
        let candleIndex: Int
        let positionedBelow: Bool
        let proximityTier: Int
        let stackIndex: Int
        let hasStableLayout: Bool
    }

    private func markerIndex(for id: UUID) -> Int? {
        markers.firstIndex(where: { $0.id == id })
    }

    private func snapshotLayout(for marker: ChartMarkerUI) -> MarkerLayoutSnapshot {
        MarkerLayoutSnapshot(
            candleIndex: marker.candleIndex,
            positionedBelow: marker.positionedBelow,
            proximityTier: marker.proximityTier,
            stackIndex: marker.stackIndex,
            hasStableLayout: marker.hasStableLayout
        )
    }

    private func applyingLayout(_ snapshot: MarkerLayoutSnapshot, to marker: ChartMarkerUI) -> ChartMarkerUI {
        var updated = marker
        updated.candleIndex = snapshot.candleIndex
        updated.positionedBelow = snapshot.positionedBelow
        updated.proximityTier = snapshot.proximityTier
        updated.stackIndex = snapshot.stackIndex
        updated.hasStableLayout = snapshot.hasStableLayout
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
                        anchorPrice: existingEmojiPayload?.anchorPrice,
                        scale: existingEmojiPayload?.scale
                    )
                )
            )
        }

        if didMutateComponents,
           originalDTO.intentEnum == .setup,
           originalDTO.trackingEnabled,
           let trackingState = originalDTO.trackingStateEnum,
           trackingState != .draft {
            updatedComponents = originalDTO.components
            didMutateComponents = false
        }

        guard note != nil || didMutateComponents else { return }

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
            return .success(reconciled)
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
        priceScale: CGFloat = 1.0,
        viewportHeight: CGFloat = 0
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
        
        // A deleted marker leaves a deliberate hole: survivors keep their
        // stack indices, and the next marker claims the first free one. The
        // preview must use the same allocator as commit or it can overlap a
        // survivor before jumping somewhere else when placed.
        let usedStackIndices = Set(
            markersAtCandle
                .filter { $0.positionedBelow == shouldBeBelow }
                .map(\.stackIndex)
        )
        var stackIndex = 0
        while usedStackIndices.contains(stackIndex) {
            stackIndex += 1
        }
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
        var markerY = baseY + stackOffsetValue
        if viewportHeight > 0 {
            let markerRadius = MarkerVisualSpec.baseCanvasDiameter / 2
            markerY = Swift.max(markerRadius, Swift.min(markerY, viewportHeight - markerRadius))
        }
        
        return (CGPoint(x: centerX, y: markerY), shouldBeBelow)
    }
    
    // MARK: - Stable Position Assignment
    
    private static let closeProximityRange = 2

    /// Copy layout only when both halves of a marker's layout identity match.
    ///
    /// API refreshes rebuild every `ChartMarkerUI`, so wrapper-local state is
    /// otherwise lost even though the user is still looking at the same chart.
    /// Matching the anchor timestamp as well as the marker ID ensures an edited
    /// anchor is allocated afresh.
    static func retainingStableAssignments(
        in refreshedMarkers: [ChartMarkerUI],
        from existingMarkers: [ChartMarkerUI]
    ) -> [ChartMarkerUI] {
        let existingByID = Dictionary(
            existingMarkers.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        return refreshedMarkers.map { refreshed in
            guard let existing = existingByID[refreshed.id],
                  existing.candleTimestamp == refreshed.candleTimestamp,
                  existing.hasStableLayout else {
                return refreshed
            }

            var retained = refreshed
            retained.positionedBelow = existing.positionedBelow
            retained.proximityTier = existing.proximityTier
            retained.stackIndex = existing.stackIndex
            retained.hasStableLayout = true
            return retained
        }
    }
    
    static func assignStablePositions(
        markers: [ChartMarkerUI],
        candles: [RLCandleDTO]
    ) -> [ChartMarkerUI] {
        var result = markers

        // Existing markers own their slot for the lifetime of this chart
        // context. Re-running the old global allocator after an add, delete or
        // history prepend could flip every nearby marker to the other side.
        var positioned = result.filter(\.hasStableLayout)
        let unassignedIndices = result.indices
            .filter { !result[$0].hasStableLayout }
            .sorted {
                if result[$0].createdAt == result[$1].createdAt {
                    return result[$0].id.uuidString < result[$1].id.uuidString
                }
                return result[$0].createdAt < result[$1].createdAt
            }

        for index in unassignedIndices {
            let assignment = calculatePositionForNewMarker(
                marker: result[index],
                existingMarkers: positioned,
                candles: candles
            )
            result[index].positionedBelow = assignment.isBelow
            result[index].proximityTier = assignment.tier
            result[index].stackIndex = assignment.stackIndex
            result[index].hasStableLayout = true
            positioned.append(result[index])
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
        
        let usedStackIndices = Set(
            markersAtCandle
                .filter { $0.positionedBelow == shouldBeBelow }
                .map(\.stackIndex)
        )
        var stackIndex = 0
        while usedStackIndices.contains(stackIndex) {
            stackIndex += 1
        }
        
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
        editingEmojiOverride: (markerId: UUID, emoji: String)? = nil,
        linkRender: MarkerLinkRenderContext? = nil,
        linkedMarkersEnabled: Bool = false
    ) {
        guard priceRange.max > priceRange.min,
              chartSize.width > 0,
              chartSize.height > 0,
              priceScale > 0,
              totalCandleWidth > 0,
              actualCandleWidth > 0 else { return }

        var markerContext = context
        let isDimmed = dimmed
        if dimmed {
            markerContext.opacity = 0.25
        }

        let scaledHeight = chartSize.height * priceScale
        let allVisibleMarkers = markers.filter { $0.isVisible }
        let groupedMarkers = Dictionary(grouping: allVisibleMarkers) { $0.candleIndex }
        let sortedCandleIndices = groupedMarkers.keys.sorted()
        let markerCullMargin = Swift.max(
            totalCandleWidth * 6,
            MarkerVisualSpec.baseCanvasDiameter * Swift.max(selectedMarkerScale, 1.0) + MarkerPositionCalculator.hitRadius
        )

        var renderQueue: [RenderedMarker] = []
        // Final rendered bounds, accumulated across candles so connectors can be
        // routed once the whole frame's positions — including the selected
        // marker's neighbour nudge — are known.
        var linkGlyphBounds: [UUID: MarkerGlyphBounds] = [:]
        renderQueue.reserveCapacity(allVisibleMarkers.count)

        for candleIndex in sortedCandleIndices {
            guard let markersAtCandle = groupedMarkers[candleIndex] else { continue }
            guard candleIndex >= 0 && candleIndex < candles.count else { continue }
            
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            
            if x < -markerCullMargin || x > chartSize.width + markerCullMargin {
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

            // Nudge non-selected markers away when one is selected (todo 38 —
            // stack safety). Shared with hit testing so a tap resolves against
            // the positions actually painted.
            MarkerStackLayout.applySelectionNudge(
                to: &markerPositions,
                selectedMarkerId: selectedMarkerId,
                selectedMarkerScale: selectedMarkerScale
            )

            // Captured after the nudge above, so connectors attach where the
            // glyphs actually land rather than where they would have.
            if linkRender != nil {
                for entry in markerPositions {
                    let isSelected = selectedMarkerId == entry.marker.id
                    let radius = (MarkerVisualSpec.baseCanvasDiameter / 2)
                        * (isSelected ? selectedMarkerScale : 1.0)
                    linkGlyphBounds[entry.marker.id] = MarkerGlyphBounds(
                        id: entry.marker.id,
                        center: entry.position,
                        radius: radius,
                        badgeRects: MarkerLinkRenderer.badgeRects(
                            center: entry.position,
                            isBelow: entry.marker.positionedBelow,
                            likeCount: entry.marker.likeCount,
                            badge: MarkerLinkRenderer.badgeKind(
                                linkedMarkersEnabled: linkedMarkersEnabled,
                                responseCount: entry.marker.responseCount,
                                relationship: entry.marker.linkRelationship
                            )
                        )
                    )
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

        // Connectors are routed and drawn here — after every position is final,
        // and before any glyph — so they pass behind the glass rather than over
        // it, and so they attach to post-nudge centres.
        if let linkRender {
            let plan = MarkerLinkGeometry.plan(
                edges: linkRender.focus.candidateEdges,
                glyphs: linkGlyphBounds,
                plotRect: linkRender.plotRect,
                selectedId: linkRender.focus.selectedId,
                curvature: linkRender.curvature
            )
            MarkerLinkRenderer.drawConnectors(
                context: context,
                plan: plan,
                revealProgress: linkRender.revealProgress,
                lineWidth: linkRender.lineWidth
            )
        }

        // What was actually painted this frame, after viewport culling. The
        // fade rule needs this rather than the loaded set: a member scrolled a
        // thousand candles away is not a visible companion.
        //
        // Cost is kept off the pan path deliberately. Nothing happens unless a
        // thesis is focused; only *members* are collected, which is a handful
        // rather than every marker on screen; and the result is compared against
        // what the manager already derived, so the steady state — panning with a
        // stable set of members visible — allocates no Task at all.
        if let linkRender, let markerManager {
            var paintedMembers: Set<UUID> = []
            for rendered in renderQueue where linkRender.focus.memberIds.contains(rendered.marker.id) {
                // Queue membership is not visibility. The queue is culled
                // horizontally by candle index and a margin, so a member can be
                // in it while sitting off the top or bottom of the price range,
                // behind the y-axis, or inside the margin — never painted, yet
                // previously counted as a visible companion, which kept the fade
                // on with a single glyph actually on screen.
                let radius = (MarkerVisualSpec.baseCanvasDiameter / 2) * rendered.scale
                guard MarkerLinkRenderer.isGlyphVisible(
                    center: rendered.position,
                    scaledRadius: radius,
                    in: linkRender.plotRect
                ) else { continue }
                paintedMembers.insert(rendered.marker.id)
            }
            if paintedMembers != linkRender.focus.visibleMemberIds {
                let reportedSelection = linkRender.focus.selectedId
                Task { @MainActor in
                    markerManager.reportRenderedMarkers(
                        paintedMembers,
                        forSelection: reportedSelection
                    )
                }
            }
        }

        let glyphQueue = renderQueue.sorted {
            let lhsPriority = MarkerStackLayout.paintPriority(
                markerId: $0.marker.id, isSelected: $0.isSelected,
                focusMemberIds: linkRender?.focus.memberIds ?? []
            )
            let rhsPriority = MarkerStackLayout.paintPriority(
                markerId: $1.marker.id, isSelected: $1.isSelected,
                focusMemberIds: linkRender?.focus.memberIds ?? []
            )
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if $0.sortKey != $1.sortKey {
                return $0.sortKey < $1.sortKey
            }
            return $0.marker.id.uuidString < $1.marker.id.uuidString
        }

        // A second, shallower dim used only for thesis focus. The placement dim
        // above is a whole-layer effect; this one is per marker.
        var focusDimmedContext = context
        focusDimmedContext.opacity = MarkerLinkGraph.unrelatedOpacity

        // Theme colours read once, symbols resolved once — per pass, not per
        // marker per frame. See `MarkerDrawPass`.
        var pass = MarkerDrawPass()

        for rendered in glyphQueue {
            // Use original undimmed context for selected markers so they stay at full opacity
            var drawContext = (isDimmed && rendered.isSelected) ? context : markerContext
            if !isDimmed, linkRender?.isDimmed(rendered.marker.id) == true {
                drawContext = focusDimmedContext
            }
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
                emojiOverride: emojiOverride,
                linkRing: linkRender?.ringStyles[rendered.marker.id],
                linkRingProgress: linkRender?.revealProgress ?? 0,
                linkedMarkersEnabled: linkedMarkersEnabled,
                pass: &pass
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
        emojiOverride: String? = nil,
        linkRing: MarkerLinkRingStyle? = nil,
        linkRingProgress: CGFloat = 0,
        linkedMarkersEnabled: Bool = false,
        pass: inout MarkerDrawPass
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
        drawContext.fill(Path(ellipseIn: shadowRect), with: .color(pass.markerShadow))

        // 2. Opaque dark base (canvas can't use .ultraThinMaterial — must block chart content)
        drawContext.fill(circlePath, with: .color(pass.markerFill))

        // 3. Tint overlay — subtle for standard, stronger for alerts
        if isAlert, let severity = markerSeverity {
            drawContext.fill(circlePath, with: .color(severity.color.opacity(0.30)))
        } else {
            drawContext.fill(circlePath, with: .color(pass.markerNeutralTint))
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
                with: .color(pass.glassStroke),
                style: StrokeStyle(lineWidth: MarkerVisualSpec.glassStrokeWidth)
            )
        }

        // 5. Icon — palette rendering via pre-resolved SwiftUI symbols
        let iconSize = MarkerVisualSpec.iconSize(for: diameter, intent: marker.intent)
        let reactionEmoji = MarkerEmojiNormalization.normalized(emojiOverride) ?? marker.selectedEmoji
        if marker.intent == .reaction, let iconChar = reactionEmoji {
            let iconColor = MarkerVisualSpec.iconPrimaryColor(for: marker.intent, severity: markerSeverity)
            drawContext.draw(
                Text(iconChar)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(iconColor),
                at: position
            )
        } else if marker.intent == .personal,
                  let avatar = drawContext.resolveSymbol(
                      id: MarkerVisualSpec.avatarSymbolTag(
                          authorId: marker.author.userId.uuidString,
                          isSelected: isSelected
                      )
                  ) {
            // A personal marker is the one that is about a person, so it wears their face —
            // its author's, which is not always the viewer's now that one can be shared
            // with the guild.
            let size = avatar.size
            drawContext.draw(
                avatar,
                in: CGRect(
                    x: position.x - size.width / 2,
                    y: position.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
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
                    yOffset: 0,
                    pass: &pass
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
            drawContext.fill(Path(roundedRect: badgeRect, cornerRadius: 7), with: .color(pass.heartBadge))
            // `verbatim:` for the same reason as the response badge: a like
            // count is a number, and the localised-key path resolved arguments
            // and walked an attributed string for it on every marker, every
            // frame. Pre-existing, but it is the same defect in the same loop.
            drawContext.draw(
                Text(verbatim: "\(marker.likeCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(pass.onAccent),
                at: CGPoint(x: position.x + 15, y: position.y + badgeOffset + 7)
            )
        }

        // 7. The single left-hand badge — mirror of the like badge, so the two
        // can never collide. Drawn in every state, not only in focus: this is
        // the affordance that says a thesis exists before you tap. Gated on the
        // capability inside `badgeKind`, because linked DTOs outlive the flag
        // and a disabled capability must leave them undecorated.
        MarkerLinkRenderer.drawResponseBadge(
            context: drawContext,
            center: position,
            isBelow: isBelow,
            badge: MarkerLinkRenderer.badgeKind(
                linkedMarkersEnabled: linkedMarkersEnabled,
                responseCount: marker.responseCount,
                relationship: marker.linkRelationship
            ),
            pass: &pass
        )

        // 8. Thesis ring. Colour lives here and nowhere else in the resting
        // chart, so deselecting restores the 1.2.1 appearance exactly.
        if let linkRing {
            MarkerLinkRenderer.drawRing(
                context: drawContext,
                center: position,
                radius: scaledRadius,
                style: linkRing,
                progress: linkRingProgress
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
        yOffset: CGFloat,
        pass: inout MarkerDrawPass
    ) {
        var resolvedIcon = pass.symbol(named: symbolName, in: context)
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

    /// What a chart tap means once the marker layer has had its say.
    ///
    /// One rule, in one place, because the tap handler has now got it wrong
    /// twice. The order matters: ask the hit test *first*, decide afterwards.
    /// Clipping a focus tap to the visible plot is the hit test's job — it
    /// already refuses a point outside `plotRect` and rejects a disc that was
    /// never painted — so a second guard in front of the hit test buys nothing
    /// and costs the empty-tap exit, which is the whole way out of focus mode
    /// for someone whose thumb lands on the price axis.
    enum MarkerTapOutcome: Equatable {
        case select(UUID)
        /// A miss, while a thesis is focused. Exits focus — wherever the miss
        /// was, including the axis gutters the marker layer does not paint.
        case exitFocus
        /// A miss outside focus, which does nothing, exactly as in 1.2.1.
        case ignore
    }

    static func tapOutcome(hitMarkerId: UUID?, isFocused: Bool) -> MarkerTapOutcome {
        if let hitMarkerId { return .select(hitMarkerId) }
        return isFocused ? .exitFocus : .ignore
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
    
    /// Focus-mode hit testing, against the geometry that was painted.
    ///
    /// Builds the same per-candle layout the renderer does — same positions,
    /// same shared nudge — then orders every candidate by paint priority and
    /// takes the topmost under the point. Glyph discs only: badges and
    /// connectors are decoration, and treating them as targets would widen
    /// glyphs asymmetrically.
    private static func focusedMarkerAtLocation(
        _ location: CGPoint,
        markers: [ChartMarkerUI],
        candles: [RLCandleDTO],
        chartSize: CGSize,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat,
        selectedMarkerId: UUID?,
        selectedMarkerScale: CGFloat,
        focusMemberIds: Set<UUID>,
        plotRect: CGRect
    ) -> ChartMarkerUI? {
        guard plotRect.contains(location) else { return nil }
        let scaledHeight = chartSize.height * priceScale
        let grouped = Dictionary(grouping: markers.filter(\.isVisible)) { $0.candleIndex }
        let baseRadius = MarkerVisualSpec.baseCanvasDiameter / 2
        // The same horizontal cull the renderer applies, so hit testing
        // considers exactly the candles that were drawn.
        let cullMargin = Swift.max(
            totalCandleWidth * 6,
            MarkerVisualSpec.baseCanvasDiameter * Swift.max(selectedMarkerScale, 1.0)
                + MarkerPositionCalculator.hitRadius
        )

        var candidates: [(marker: ChartMarkerUI, bounds: MarkerGlyphBounds, priority: Int, order: Int)] = []

        for candleIndex in grouped.keys.sorted() {
            guard let atCandle = grouped[candleIndex],
                  candleIndex >= 0, candleIndex < candles.count else { continue }

            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset
            guard x >= -cullMargin, x <= chartSize.width + cullMargin else { continue }

            let candle = candles[candleIndex]
            let range = CGFloat(priceRange.max - priceRange.min)
            let candleHighY = chartSize.height - (CGFloat(candle.high - priceRange.min) / range) * scaledHeight - verticalOffset
            let candleLowY = chartSize.height - (CGFloat(candle.low - priceRange.min) / range) * scaledHeight - verticalOffset
            let centerX = x + actualCandleWidth / 2

            var positions: [(marker: ChartMarkerUI, position: CGPoint)] = atCandle
                .sorted { $0.createdAt < $1.createdAt }
                .map { marker in
                    (marker, MarkerPositionCalculator.computeMarkerScreenPosition(
                        marker: marker,
                        candleHighY: candleHighY,
                        candleLowY: candleLowY,
                        centerX: centerX,
                        priceScale: priceScale,
                        viewportHeight: chartSize.height
                    ))
                }

            MarkerStackLayout.applySelectionNudge(
                to: &positions,
                selectedMarkerId: selectedMarkerId,
                selectedMarkerScale: selectedMarkerScale
            )

            for (order, entry) in positions.enumerated() {
                let isSelected = entry.marker.id == selectedMarkerId
                let radius = baseRadius * (isSelected ? selectedMarkerScale : 1.0)
                guard MarkerLinkRenderer.isGlyphVisible(
                    center: entry.position, scaledRadius: radius, in: plotRect
                ) else { continue }
                candidates.append((
                    marker: entry.marker,
                    bounds: MarkerGlyphBounds(
                        id: entry.marker.id,
                        center: entry.position,
                        radius: radius
                    ),
                    priority: MarkerStackLayout.paintPriority(
                        markerId: entry.marker.id,
                        isSelected: isSelected,
                        focusMemberIds: focusMemberIds
                    ),
                    order: candleIndex * 10_000 + order
                ))
            }
        }

        // Topmost first: highest paint priority, then latest painted within it.
        let topmostFirst = candidates.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.order != $1.order { return $0.order > $1.order }
            return $0.marker.id.uuidString > $1.marker.id.uuidString
        }
        let touchRadius = MarkerPositionCalculator.hitRadius
        return topmostFirst.first {
            $0.bounds.isHit(by: location, touchRadius: touchRadius)
        }?.marker
    }

    /// Which marker a tap selects.
    ///
    /// Two behaviours, deliberately separate.
    ///
    /// **In focus mode** the tap resolves against the geometry the viewer is
    /// looking at: post-nudge centres, the selected glyph's scaled radius, and
    /// paint priority — unrelated, then thesis members, then the selected glyph
    /// — walked topmost-first. Without that, a tap in a dense stack could select
    /// the neighbour *behind* the glyph under the finger, because the legacy
    /// path recomputes unnudged centres and walks creation order, neither of
    /// which is what was drawn. Walking a thesis by tapping is the feature, so
    /// this has to agree with the picture.
    ///
    /// **Otherwise** the 1.2.1 behaviour, verbatim: recomputed centres,
    /// creation order reversed, fixed radius. A standalone marker outside any
    /// thesis behaves exactly as it always has.
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
        totalOffset: CGFloat,
        selectedMarkerId: UUID? = nil,
        selectedMarkerScale: CGFloat = 1.0,
        focusMemberIds: Set<UUID> = [],
        plotRect: CGRect? = nil
    ) -> ChartMarkerUI? {
        guard priceRange.max > priceRange.min,
              chartSize.width > 0,
              chartSize.height > 0,
              priceScale > 0,
              totalCandleWidth > 0,
              actualCandleWidth > 0 else { return nil }

        if !focusMemberIds.isEmpty {
            return focusedMarkerAtLocation(
                location,
                markers: markers,
                candles: candles,
                chartSize: chartSize,
                priceRange: priceRange,
                priceScale: priceScale,
                verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                totalOffset: totalOffset,
                selectedMarkerId: selectedMarkerId,
                selectedMarkerScale: selectedMarkerScale,
                focusMemberIds: focusMemberIds,
                plotRect: plotRect ?? CGRect(origin: .zero, size: chartSize)
            )
        }

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
