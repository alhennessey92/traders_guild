//
//  ChartViewModel.swift
//  traders_guild
//
//  UPDATED VERSION - Properly initializes chart data with symbol and timeframe
//  Fixes: initial load showing wrong price, data not regenerating on symbol change
//

import SwiftUI
import Combine

@MainActor
class ChartViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private var appState: RLAppState
    let dataManager: ChartDataManager
    private var api: RealAPIService
    private var cancellables = Set<AnyCancellable>()
    private var hasConfiguredRealtimeObservers = false
    private var needsRealtimeResync = false
    private var isPerformingRealtimeResync = false
    private var lastRealtimeResyncAt: Date = .distantPast
    private var stalenessWatchdogTask: Task<Void, Never>?
    private var historicalPreloadTask: Task<Void, Never>?
    private var markerNavigationTimeoutTask: Task<Void, Never>?
    private var lastRealtimeMarketEventAt: Date = .distantPast

    /// Drives automatic recovery from the empty / "Market Data Unavailable" state
    /// (a failed initial candle load). Kept separate from the staleness watchdog
    /// and reconnect resync, which only run once candles already exist.
    private var chartRetryTask: Task<Void, Never>?
    private var isPerformingChartRetry = false
    
    /// Current WebSocket channel subscriptions for real-time market data
    private var currentTickChannel: String?
    private var currentCandleChannel: String?

    /// Coalesces back-to-back tick-driven indicator recalcs into a throttled cadence.
    /// WebSocket ticks can arrive at 20–100Hz; recalculating all indicators across the
    /// full candle history on every tick burns a CPU core and starves the UI.
    private var pendingIndicatorRecalc = false
    private let indicatorRecalcCoalesceWindow: TimeInterval = 0.08
    
    /// Configure with proper app state and API service
    /// Called from MainView.onAppear when EnvironmentObjects are available
    func configure(appState: RLAppState, api: RealAPIService) {
        self.appState = appState
        self.api = api
        guard !hasConfiguredRealtimeObservers else { return }
        hasConfiguredRealtimeObservers = true
        setupRealTimeSubscriptions()
        setupRealTimeConnectionObserver()
        startStalenessWatchdog()
    }
    
    weak var markerManager: MarkerManager?

    // MARK: - Marker Detail Bridge

    /// Mirrors markerManager.selectedMarker so ChartBottomSheet can react to marker selection
    @Published var selectedMarkerForSheet: ChartMarkerUI?
    private var markerSelectionCancellable: AnyCancellable?

    /// Call after markerManager is assigned to bridge selectedMarker into @Published for bottom sheet reactivity
    func observeMarkerSelection() {
        markerSelectionCancellable = markerManager?.$selectedMarker
            .receive(on: RunLoop.main)
            .sink { [weak self] marker in
                self?.selectedMarkerForSheet = marker
            }
    }

    // MARK: - Published State
    
    @Published var currentSymbol: RLTradingSymbolDTO?
    @Published var currentTimeframe: RLChartTimeframe = .m5
    /// 24h price series powering the collapsed symbol panel's mini line chart.
    @Published var currentSymbolPreview: SymbolPreview?
    @Published var availableSymbols: [RLTradingSymbolDTO] = []
    @Published var activeMarketProvider: String?
    @Published var activeMarketProviderUpdatedAt: Date?
    @Published var isLoadingData: Bool = false
    @Published private(set) var isLoadingOlderCandles: Bool = false
    @Published private(set) var hasMoreHistoricalCandles: Bool = false
    @Published var errorMessage: String?

    /// True while the chart is auto-recovering from an empty/failed candle load
    /// (either mid-attempt or waiting between backoff attempts). Drives the
    /// "Reconnecting…" state in the no-data overlay.
    @Published private(set) var isRetryingChartLoad: Bool = false
    /// Current auto-retry attempt number (0 when not auto-recovering).
    @Published private(set) var chartRetryAttempt: Int = 0

    /// True while a marker-panel navigation is in flight (timeframe/symbol/scroll change driven by
    /// MarkerNavigationHelper). While set, TradingChartView suppresses competing pan-offset resets
    /// so the navigation can land on the marker without being snapped back to the latest candles.
    @Published var isNavigatingToMarker: Bool = false
    @Published private(set) var markerNavigationSession: MarkerNavigationSession?

    private var earliestHistoricalCandleTimestamp: Date?
    private let historicalCandlePageSize = HistoricalPreloadPolicy.pageSize
    
    // MARK: - Watchlists
    
    @Published var personalWatchlist: [RLTradingSymbolDTO] = []
    @Published var guildWatchlist: [RLTradingSymbolDTO] = []
    @Published var globalSymbols: [RLTradingSymbolDTO] = []
    
    
    // MARK: Indicator manager
    
    // IMPORTANT: Expose gestureState for RSI panel synchronization
    let gestureState = ChartGestureState()
    
    @Published var indicatorManager = IndicatorManager()
    @Published var chartDrawingManager = ChartDrawingManager()
    @Published var chartTimeframeLinkManager = ChartTimeframeLinkManager()
    let chartComponentsPlacementState = MarkerPlacementState()

    private var isSyncingChartDrawingPlacementFromManager = false
    private var isApplyingChartDrawingPlacementToManager = false
    private var syncChartDrawingPlacementFromManagerScheduled = false
    private var applyChartDrawingPlacementToManagerScheduled = false
    
    // In ChartViewModel.swift, add:
    var totalCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
    }

    var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }

    private let baseCandleWidth: CGFloat = 12
    private let candleSpacing: CGFloat = 4
    
    var combinedWatchlist: [RLTradingSymbolDTO] {
        let combined = personalWatchlist + guildWatchlist
        var seen = Set<UUID>()
        return combined.filter { symbol in
            guard !seen.contains(symbol.id) else { return false }
            seen.insert(symbol.id)
            return true
        }
    }

    var allAvailableSymbols: [RLTradingSymbolDTO] {
        let combined = combinedWatchlist + globalSymbols
        var seen = Set<UUID>()
        return combined.filter { symbol in
            guard !seen.contains(symbol.id) else { return false }
            seen.insert(symbol.id)
            return true
        }
    }
    
    // MARK: - Initialization
    
    /// Identifies this chart to `RealTimeService`'s channel reference counting.
    ///
    /// Every chart used to subscribe as the literal owner `"chart"`, so the owner
    /// set never held more than one entry no matter how many charts existed. With
    /// several charts on screen the first one to change symbol emptied that set and
    /// the shared socket unsubscribed the channel out from under all the others.
    /// A per-instance token makes the reference count real. Mirrors the pattern
    /// already used by `TimeframePanelManager`.
    let ownerToken: String

    /// Identity of the chart pane this view model drives. One pane on iOS; up to
    /// four on macOS. Also addresses pane-directed notifications — see
    /// [ChartPaneAddressing].
    let paneID: UUID

    init(
        appState: RLAppState,
        dataManager: ChartDataManager,
        api: RealAPIService,
        paneID: UUID = UUID(),
        ownerToken: String? = nil
    ) {
        self.paneID = paneID
        self.ownerToken = ownerToken ?? "chart_\(paneID.uuidString.lowercased())"
        self.appState = appState
        self.dataManager = dataManager
        self.api = api
        chartDrawingManager.load()
        chartTimeframeLinkManager.load()
        chartComponentsPlacementState.intent = .analysis
        setupChartDrawingPlacementSync()
        syncChartDrawingPlacementFromManager()
    }

    deinit {
        stalenessWatchdogTask?.cancel()
        historicalPreloadTask?.cancel()
        markerNavigationTimeoutTask?.cancel()
    }
    
    // MARK: - Public Methods

    func showPlacementFailure(_ failure: MarkerPlacementFailure) {
        appState.showError(
            title: failure.toastTitle,
            message: failure.userMessage,
            severity: failure.toastSeverity,
            style: .toast
        )
    }
    
    /// Initialize the view model with data
    func initialize() async {
        isLoadingData = true
        errorMessage = nil
        
        do {
            do {
                let providerStatus = try await api.getMarketDataProviderStatus()
                activeMarketProviderUpdatedAt = providerStatus.updatedAt
            } catch {
                // Non-fatal: symbol payloads also carry active provider metadata.
            }

            // Load watchlists using new API
            let personalWatchlistDTO = try await api.getPersonalWatchlist()
            personalWatchlist = personalWatchlistDTO.symbols.map { $0.symbol }
            
            if let guildId = appState.currentGuild?.id {
                let guildWatchlistDTO = try await api.getGuildWatchlist(guildId: guildId)
                guildWatchlist = guildWatchlistDTO.symbols.map { $0.symbol }
                let globalSymbolsDTO = try await api.getGlobalSymbols(guildId: guildId, limit: 100)
                globalSymbols = globalSymbolsDTO.symbols
            } else {
                globalSymbols = []
            }

            // Set initial symbol from watchlists, then global fallback.
            let available = allAvailableSymbols
            if let current = currentSymbol,
               let refreshedCurrent = available.first(where: { $0.id == current.id }),
               !refreshedCurrent.isSelectableForActiveProvider {
                currentSymbol = nil
            } else if let current = currentSymbol,
                      !available.contains(where: { $0.id == current.id }) {
                currentSymbol = nil
            }
            if currentSymbol == nil {
                currentSymbol = firstSupportedSymbol(in: combinedWatchlist)
                    ?? firstSupportedSymbol(in: globalSymbols)
                    ?? combinedWatchlist.first
                    ?? globalSymbols.first
            }
            activeMarketProvider = currentSymbol?.activeMarketProvider
            syncChartDrawingStorageContext()
            availableSymbols = available
            
            // Load chart data for the selected symbol
            if let symbol = currentSymbol, let guildId = appState.currentGuild?.id {
                await loadChartData(symbolId: symbol.id, guildId: guildId, timeframe: currentTimeframe)
            } else {
                // No symbols available - show error
                errorMessage = "No symbols available in watchlist"
                appState.showError(
                    title: "No Chart Data",
                    message: "No active symbols are available for this guild yet.",
                    style: .toast
                )
            }
            
        } catch {
            errorMessage = RLUserFacingErrorMapper.message(from: error, context: .chart)
            appState.showError(error, title: "Failed to Load Chart Data", style: .toast, context: .chart)
        }
        
        isLoadingData = false
        // ADD: After data is loaded, calculate indicators
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
    }
    
    /// Load chart data (symbol + candles + markers) from backend
    private func loadChartData(
        symbolId: UUID,
        guildId: UUID,
        timeframe: RLChartTimeframe,
        skipSubscribe: Bool = false,
        mergeWithExisting: Bool = false
    ) async {
        if !mergeWithExisting {
            cancelHistoricalPreload()
        }

        do {
            let timeframeString = timeframe.toBackendString()
            let chartData = try await api.getChartData(
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframeString,
                candleLimit: timeframe.initialCandlesCount,
                continuousTime: true
            )

            // Update current symbol if it changed
            if currentSymbol?.id != chartData.symbol.id {
                currentSymbol = chartData.symbol
            }
            syncChartDrawingStorageContext()
            activeMarketProvider = chartData.symbol.activeMarketProvider ?? activeMarketProvider

            // Sync symbol to dataManager so MarkerCreationSheet can access it
            dataManager.currentSymbol = chartData.symbol
            dataManager.currentTimeframe = timeframe

            if mergeWithExisting, !dataManager.candles.isEmpty {
                let mergeResult = dataManager.mergeHistoricalMarketData(
                    chartData.candles,
                    preservePriceRangeForPurePrepend: false,
                    beforePublishingPrepend: { [weak self] prependedCount in
                        guard let self, !self.isNavigatingToMarker else { return }
                        self.gestureState.applyHistoricalPrepend(
                            count: prependedCount,
                            totalCandleWidth: self.totalCandleWidth
                        )
                    }
                )
                hasMoreHistoricalCandles = hasMoreHistoricalCandles || chartData.hasMoreCandles
            } else {
                dataManager.updateWithMarketData(chartData.candles)
                hasMoreHistoricalCandles = chartData.hasMoreCandles
            }
            earliestHistoricalCandleTimestamp = dataManager.candles.first?.timestamp
            reconcileCurrentCandleWithSymbolSnapshot(chartData.symbol)
            noteRealtimeMarketEvent()

            // Subscribe to real-time price ticks for this symbol/timeframe
            // (skipped when caller already subscribed to avoid double-subscribe)
            if !skipSubscribe {
                subscribeToRealTimeTicks(guildId: guildId, symbolId: symbolId, timeframe: timeframe)
            }

            // Update markers (if markerManager is set)
            if let markerManager = markerManager {
                if mergeWithExisting {
                    await markerManager.mergeMarkersFromAPI(
                        api: api,
                        symbolId: chartData.symbol.id,
                        symbol: chartData.symbol.ticker,
                        guildId: guildId,
                        timeframe: timeframe,
                        candles: dataManager.candles,
                        startTime: chartData.candles.first?.timestamp,
                        endTime: chartData.candles.last?.timestamp
                    )
                } else {
                    await markerManager.loadMarkersFromAPI(
                        api: api,
                        symbolId: chartData.symbol.id,
                        symbol: chartData.symbol.ticker,
                        guildId: guildId,
                        timeframe: timeframe,
                        candles: dataManager.candles
                    )
                }
                markerManager.recalculateCandleIndices(candles: dataManager.candles)
            }

        } catch {
            if case let APIError.serverError(statusCode, detail) = error, statusCode == 409 {
                await handleUnsupportedSymbolFallback(
                    previousSymbolId: symbolId,
                    guildId: guildId,
                    timeframe: timeframe,
                    detail: detail,
                    skipSubscribe: skipSubscribe
                )
                return
            }
            errorMessage = RLUserFacingErrorMapper.message(from: error, context: .chart)
            appState.showError(error, title: "Failed to Load Chart", style: .toast, context: .chart)
            // Clear candles on error - don't show stale or mock data
            dataManager.updateWithMarketData([])
            earliestHistoricalCandleTimestamp = nil
            hasMoreHistoricalCandles = false
            cancelHistoricalPreload()
        }

        // Start/stop empty-state auto-recovery based on whether this load left
        // us with candles. No-ops for the merge/resync paths (candles present).
        updateChartRetryLoop()
    }

    private func handleUnsupportedSymbolFallback(
        previousSymbolId: UUID,
        guildId: UUID,
        timeframe: RLChartTimeframe,
        detail: String,
        skipSubscribe: Bool
    ) async {
        let fallback = allAvailableSymbols.first {
            $0.id != previousSymbolId && $0.isSelectableForActiveProvider
        }
        if let fallback {
            currentSymbol = fallback
            syncChartDrawingStorageContext()
            activeMarketProvider = fallback.activeMarketProvider ?? activeMarketProvider
            appState.showError(
                title: "Symbol Unavailable",
                message: "\(detailMessage(forUnsupportedSymbolDetail: detail)) Switched to \(fallback.ticker).",
                style: .toast
            )
            await loadChartData(
                symbolId: fallback.id,
                guildId: guildId,
                timeframe: timeframe,
                skipSubscribe: skipSubscribe
            )
            return
        }

        errorMessage = "No symbols supported by their default data providers"
        dataManager.updateWithMarketData([])
        earliestHistoricalCandleTimestamp = nil
        hasMoreHistoricalCandles = false
        cancelHistoricalPreload()
        appState.showError(
            title: "No Supported Symbols",
            message: detail.isEmpty
                ? "No symbols are supported by their default market data providers."
                : detail,
            style: .toast
        )
    }
    
    /// Set the current symbol and regenerate chart data
    func setSymbol(_ symbol: RLTradingSymbolDTO) {
        guard symbol.isSelectableForActiveProvider else {
            if APIEnvironment.current == .production {
                appState.showError(
                    title: "Available in Production",
                    message: "\(symbol.ticker) is listed in public beta, but live data is currently limited to Binance crypto markets. Broader markets unlock in production.",
                    style: .toast
                )
            } else {
                let providerText = symbol.activeProviderDisplayName ?? "active provider"
                appState.showError(
                    title: "Symbol Unavailable",
                    message: "\(symbol.ticker) is not supported by \(providerText).",
                    style: .toast
                )
            }
            return
        }
        guard currentSymbol?.id != symbol.id else { return }
        
        currentSymbol = symbol
        syncChartDrawingStorageContext()
        if let provider = symbol.activeMarketProvider {
            activeMarketProvider = provider
        }
        handleSymbolChange()
    }
    
    /// Set the current timeframe and regenerate chart data
    func setTimeframe(_ timeframe: RLChartTimeframe) {
        guard currentTimeframe != timeframe else { return }
        
        currentTimeframe = timeframe
        dataManager.currentTimeframe = timeframe
        handleTimeframeChange()
    }

    @discardableResult
    func beginMarkerNavigation(_ target: MarkerNavigationTarget) -> UUID {
        markerNavigationTimeoutTask?.cancel()
        let session = MarkerNavigationSession(target: target)
        markerNavigationSession = session
        isNavigatingToMarker = true
        markerNavigationTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                return
            }
            self?.expireMarkerNavigationIfActive(sessionId: session.id)
        }
        return session.id
    }

    func updateMarkerNavigationPhase(sessionId: UUID, phase: MarkerNavigationPhase) {
        guard var session = markerNavigationSession, session.id == sessionId else { return }
        session.phase = phase
        markerNavigationSession = session
    }

    func isMarkerNavigationSessionActive(_ sessionId: UUID) -> Bool {
        markerNavigationSession?.id == sessionId && isNavigatingToMarker
    }

    func finishMarkerNavigation(sessionId: UUID, phase: MarkerNavigationPhase) {
        guard var session = markerNavigationSession, session.id == sessionId else { return }
        markerNavigationTimeoutTask?.cancel()
        markerNavigationTimeoutTask = nil
        session.phase = phase
        markerNavigationSession = session
        isNavigatingToMarker = false

        let clearDelay: TimeInterval
        switch phase {
        case .failed:
            clearDelay = 2.2
        default:
            clearDelay = 0.35
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + clearDelay) { [weak self] in
            guard self?.markerNavigationSession?.id == sessionId else { return }
            self?.markerNavigationSession = nil
        }
    }

    /// Fail-safe for a suspended request or lifecycle race. The session-id guard ensures
    /// an old watchdog can never terminate a newer marker navigation.
    func expireMarkerNavigationIfActive(sessionId: UUID) {
        guard isMarkerNavigationSessionActive(sessionId) else { return }
        finishMarkerNavigation(
            sessionId: sessionId,
            phase: .failed("Marker loading timed out")
        )
    }

    /// Change symbol and timeframe as a single marker-navigation operation. This avoids the
    /// duplicate chart-data fetches caused by calling setSymbol and setTimeframe back-to-back.
    @discardableResult
    func prepareForMarkerNavigation(
        _ target: MarkerNavigationTarget,
        symbol: RLTradingSymbolDTO,
        timeframe: RLChartTimeframe
    ) async -> Bool {
        _ = target
        guard symbol.isSelectableForActiveProvider else {
            appState.showError(
                title: "Symbol Unavailable",
                message: "\(symbol.ticker) is not supported by the active market data provider.",
                style: .toast
            )
            return false
        }
        guard let guildId = appState.currentGuild?.id else {
            errorMessage = "No guild selected"
            return false
        }

        let needsReload = currentSymbol?.id != symbol.id
            || currentTimeframe != timeframe
            || dataManager.candles.isEmpty
            || dataManager.currentTimeframe != timeframe

        currentSymbol = symbol
        currentTimeframe = timeframe
        dataManager.currentSymbol = symbol
        dataManager.currentTimeframe = timeframe
        syncChartDrawingStorageContext()
        activeMarketProvider = symbol.activeMarketProvider ?? activeMarketProvider

        if needsReload {
            markerManager?.clearMarkers()
            subscribeToRealTimeTicks(guildId: guildId, symbolId: symbol.id, timeframe: timeframe)
            await loadChartData(
                symbolId: symbol.id,
                guildId: guildId,
                timeframe: timeframe,
                skipSubscribe: true
            )
            scheduleIndicatorRecalc()
        } else {
            markerManager?.recalculateCandleIndices(candles: dataManager.candles)
        }
        return true
    }

    private func detailMessage(forUnsupportedSymbolDetail detail: String) -> String {
        if APIEnvironment.current == .production {
            return "Public beta currently supports live Binance crypto markets only. Broader markets unlock in production."
        }

        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "Selected symbol is unavailable from its default market data provider."
    }

    /// Load a candle/marker window centered around a specific timestamp.
    /// Used for marker navigation when the target lies outside the currently loaded chart slice.
    func loadNavigationWindow(around timestamp: Date, timeframe: RLChartTimeframe? = nil) async {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id else {
            return
        }

        let targetTimeframe = timeframe ?? currentTimeframe
        let candleLimit = targetTimeframe.initialCandlesCount
        let halfWindowCandles = max(1, candleLimit / 2)
        let endTime = timestamp.addingTimeInterval(targetTimeframe.seconds * Double(halfWindowCandles))

        do {
            let previousFirstTimestamp = dataManager.candles.first?.timestamp
            let candlesResponse = try await api.getCandles(
                symbolId: symbol.id,
                timeframe: targetTimeframe.toBackendString(),
                limit: candleLimit,
                endTime: endTime,
                continuousTime: true
            )

            dataManager.currentSymbol = symbol
            dataManager.currentTimeframe = targetTimeframe
            let mergeResult = dataManager.mergeHistoricalMarketData(
                candlesResponse.candles,
                preservePriceRangeForPurePrepend: false,
                beforePublishingPrepend: { [weak self] prependedCount in
                    guard let self, !self.isNavigatingToMarker else { return }
                    self.gestureState.applyHistoricalPrepend(
                        count: prependedCount,
                        totalCandleWidth: self.totalCandleWidth
                    )
                }
            )
            earliestHistoricalCandleTimestamp = dataManager.candles.first?.timestamp
            hasMoreHistoricalCandles = candlesResponse.hasMore
            reconcileCurrentCandleWithSymbolSnapshot(symbol)
            noteRealtimeMarketEvent()

            if let markerManager {
                await markerManager.mergeMarkersFromAPI(
                    api: api,
                    symbolId: symbol.id,
                    symbol: symbol.ticker,
                    guildId: guildId,
                    timeframe: targetTimeframe,
                    candles: dataManager.candles,
                    startTime: candlesResponse.candles.first?.timestamp,
                    endTime: previousFirstTimestamp ?? candlesResponse.candles.last?.timestamp
                )
                markerManager.recalculateCandleIndices(candles: dataManager.candles)
            }

            scheduleIndicatorRecalc()
        } catch {
            print("Failed to load navigation window: \(error)")
        }
    }

    // MARK: - Symbol Preview (compact symbol panel)

    /// Compact 24h price series (closes) for the collapsed symbol panel's line.
    struct SymbolPreview: Equatable {
        let symbolId: UUID
        let closes: [Double]
    }

    /// Fetch a lightweight 24h price series (fixed 15m resolution → 96 points) so
    /// the mini line traces accurate "last 24 hours" price flow regardless of the
    /// chart's current timeframe. Cached per symbol; failures keep any previous
    /// preview in place.
    func loadSymbolPreview(for symbolId: UUID) async {
        if currentSymbolPreview?.symbolId == symbolId { return }
        do {
            let response = try await api.getCandles(
                symbolId: symbolId,
                timeframe: RLChartTimeframe.m15.toBackendString(),
                limit: 96
            )
            guard response.candles.count >= 2 else {
                if currentSymbolPreview?.symbolId != symbolId {
                    currentSymbolPreview = nil
                }
                return
            }
            currentSymbolPreview = SymbolPreview(
                symbolId: symbolId,
                closes: response.candles.map(\.close)
            )
        } catch {
            // Leave any previous preview in place; the panel falls back gracefully.
        }
    }

    @discardableResult
    func loadOlderCandlesIfNeeded(
        visibleStartIndex: Int,
        visibleCandleCount: Int,
        reason: HistoricalPreloadReason = .viewport
    ) async -> Int {
        guard HistoricalPreloadPolicy.shouldPreload(
            visibleStartIndex: visibleStartIndex,
            visibleCandleCount: visibleCandleCount,
            hasMoreHistoricalCandles: hasMoreHistoricalCandles
        ) else {
            return 0
        }

        let outcome = await loadOlderCandlePage(
            preservePriceRangeForPurePrepend: true,
            hydrateMarkersImmediately: false
        )
        let prependedCount = outcome.mergeResult.prependedCount

        if prependedCount > 0 {
            scheduleIndicatorRecalc()
            scheduleHistoricalMarkerHydration(
                startTime: outcome.startTime,
                endTime: outcome.endTime,
                reason: reason
            )
        }

        return prependedCount
    }

    @discardableResult
    func loadOlderCandles() async -> Int {
        let outcome = await loadOlderCandlePage(
            preservePriceRangeForPurePrepend: false,
            hydrateMarkersImmediately: true
        )
        return outcome.mergeResult.prependedCount
    }

    private func loadOlderCandlePage(
        preservePriceRangeForPurePrepend: Bool,
        hydrateMarkersImmediately: Bool
    ) async -> (
        mergeResult: HistoricalMergeResult,
        startTime: Date?,
        endTime: Date?
    ) {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id,
              hasMoreHistoricalCandles,
              !isLoadingOlderCandles,
              !dataManager.candles.isEmpty else {
            return (
                HistoricalMergeResult(
                    prependedCount: 0,
                    insertedCount: 0,
                    duplicateCount: 0,
                    deferredPriceRangeUpdate: false
                ),
                nil,
                nil
            )
        }

        let endTime = earliestHistoricalCandleTimestamp ?? dataManager.candles.first?.timestamp
        guard let endTime else {
            return (
                HistoricalMergeResult(
                    prependedCount: 0,
                    insertedCount: 0,
                    duplicateCount: 0,
                    deferredPriceRangeUpdate: false
                ),
                nil,
                nil
            )
        }

        isLoadingOlderCandles = true
        defer { isLoadingOlderCandles = false }

        do {
            let previousFirstTimestamp = dataManager.candles.first?.timestamp
            #if DEBUG
            // A history page is the one piece of work that lands mid-gesture and is big enough to
            // drop frames: a ~200 KB fetch, then a prepend + republish of the whole candle array on
            // the main actor. If panning stutters periodically, check whether the hitches line up
            // with these lines — `merge` is the part that blocks the UI; `fetch` does not.
            let fetchStartedAt = CFAbsoluteTimeGetCurrent()
            #endif
            let candlesResponse = try await api.getCandles(
                symbolId: symbol.id,
                timeframe: currentTimeframe.toBackendString(),
                limit: historicalCandlePageSize,
                endTime: endTime,
                continuousTime: true
            )
            #if DEBUG
            let mergeStartedAt = CFAbsoluteTimeGetCurrent()
            #endif

            let mergeResult = dataManager.mergeHistoricalMarketData(
                candlesResponse.candles,
                preservePriceRangeForPurePrepend: preservePriceRangeForPurePrepend,
                beforePublishingPrepend: { [weak self] prependedCount in
                    guard let self, !self.isNavigatingToMarker else { return }
                    self.gestureState.applyHistoricalPrepend(
                        count: prependedCount,
                        totalCandleWidth: self.totalCandleWidth
                    )
                }
            )

            #if DEBUG
            let now = CFAbsoluteTimeGetCurrent()
            print(String(
                format: "📄 [Chart] history page: +%d candles (total %d) fetch=%.0fms merge=%.1fms",
                mergeResult.prependedCount,
                dataManager.candles.count,
                (mergeStartedAt - fetchStartedAt) * 1000,
                (now - mergeStartedAt) * 1000
            ))
            #endif

            earliestHistoricalCandleTimestamp = dataManager.candles.first?.timestamp ?? candlesResponse.earliestTimestamp
            hasMoreHistoricalCandles = candlesResponse.hasMore && mergeResult.prependedCount > 0

            if hydrateMarkersImmediately, mergeResult.prependedCount > 0, let markerManager {
                await markerManager.mergeMarkersFromAPI(
                    api: api,
                    symbolId: symbol.id,
                    symbol: symbol.ticker,
                    guildId: guildId,
                    timeframe: currentTimeframe,
                    candles: dataManager.candles,
                    startTime: dataManager.candles.first?.timestamp,
                    endTime: previousFirstTimestamp ?? candlesResponse.candles.last?.timestamp
                )
                markerManager.recalculateCandleIndices(candles: dataManager.candles)
            }

            if hydrateMarkersImmediately, mergeResult.prependedCount > 0 {
                scheduleIndicatorRecalc()
            }

            return (
                mergeResult,
                dataManager.candles.first?.timestamp,
                previousFirstTimestamp ?? candlesResponse.candles.last?.timestamp
            )
        } catch {
            print("Failed to load older candles: \(error)")
            return (
                HistoricalMergeResult(
                    prependedCount: 0,
                    insertedCount: 0,
                    duplicateCount: 0,
                    deferredPriceRangeUpdate: false
                ),
                nil,
                nil
            )
        }
    }

    private func scheduleHistoricalWarmupIfNeeded() {
        cancelHistoricalPreload()
        guard let symbolId = currentSymbol?.id,
              let guildId = appState.currentGuild?.id,
              HistoricalPreloadPolicy.shouldWarmup(
                candleCount: dataManager.candles.count,
                timeframe: currentTimeframe,
                hasMoreHistoricalCandles: hasMoreHistoricalCandles
              ) else {
            return
        }

        let timeframe = currentTimeframe
        historicalPreloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            await self?.runHistoricalWarmup(
                symbolId: symbolId,
                guildId: guildId,
                timeframe: timeframe
            )
        }
    }

    private func cancelHistoricalPreload() {
        historicalPreloadTask?.cancel()
        historicalPreloadTask = nil
    }

    private func runHistoricalWarmup(
        symbolId: UUID,
        guildId: UUID,
        timeframe: RLChartTimeframe
    ) async {
        var totalPrepended = 0
        var aggregateStartTime: Date?
        var aggregateEndTime: Date?

        while !Task.isCancelled,
              isHistoricalPreloadContextCurrent(symbolId: symbolId, guildId: guildId, timeframe: timeframe),
              HistoricalPreloadPolicy.shouldWarmup(
                candleCount: dataManager.candles.count,
                timeframe: timeframe,
                hasMoreHistoricalCandles: hasMoreHistoricalCandles
              ) {
            let outcome = await loadOlderCandlePage(
                preservePriceRangeForPurePrepend: true,
                hydrateMarkersImmediately: false
            )
            let prependedCount = outcome.mergeResult.prependedCount
            guard prependedCount > 0 else { break }

            totalPrepended += prependedCount
            aggregateStartTime = outcome.startTime ?? aggregateStartTime
            aggregateEndTime = aggregateEndTime ?? outcome.endTime
        }

        if totalPrepended > 0,
           isHistoricalPreloadContextCurrent(symbolId: symbolId, guildId: guildId, timeframe: timeframe) {
            scheduleIndicatorRecalc()
            scheduleHistoricalMarkerHydration(
                startTime: aggregateStartTime,
                endTime: aggregateEndTime,
                reason: .warmup
            )
        }

        if historicalPreloadTask?.isCancelled == false {
            historicalPreloadTask = nil
        }
    }

    private func isHistoricalPreloadContextCurrent(
        symbolId: UUID,
        guildId: UUID,
        timeframe: RLChartTimeframe
    ) -> Bool {
        currentSymbol?.id == symbolId &&
            appState.currentGuild?.id == guildId &&
            currentTimeframe == timeframe
    }

    private func scheduleHistoricalMarkerHydration(
        startTime: Date?,
        endTime: Date?,
        reason: HistoricalPreloadReason
    ) {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id,
              let startTime,
              let endTime,
              startTime < endTime else {
            return
        }

        let timeframe = currentTimeframe
        Task { @MainActor [weak self] in
            guard let self,
                  self.isHistoricalPreloadContextCurrent(
                    symbolId: symbol.id,
                    guildId: guildId,
                    timeframe: timeframe
                  ),
                  let markerManager = self.markerManager else {
                return
            }

            await markerManager.mergeMarkersFromAPI(
                api: self.api,
                symbolId: symbol.id,
                symbol: symbol.ticker,
                guildId: guildId,
                timeframe: timeframe,
                candles: self.dataManager.candles,
                startTime: startTime,
                endTime: endTime
            )
            markerManager.recalculateCandleIndices(candles: self.dataManager.candles)
            print("📈 [Chart] Hydrated historical markers after \(reason.rawValue) preload")
        }
    }
    
    /// Reload all data (watchlists and chart)
    func reloadData() async {
        await initialize()
    }
    
    // MARK: - Private Methods
    
    /// Handle symbol change - regenerate chart data with new symbol
    private func handleSymbolChange() {
        // A deliberate symbol switch supersedes any in-flight auto-recovery;
        // the load below restarts the loop if it ends up empty.
        cancelChartRetryLoop()
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id else {
            // No guild selected - show error
            unsubscribeFromRealTimeTicks()
            errorMessage = "No guild selected"
            appState.showError(
                title: RLUserFacingCopy.text(.errorNoGuildSelected),
                message: RLUserFacingCopy.text(.errorSelectGuildFirst),
                style: .toast
            )
            dataManager.updateWithMarketData([])
            cancelHistoricalPreload()
            scheduleIndicatorRecalc()
            return
        }

        // Capture old channels before subscribing to new ones
        let oldTickChannel = currentTickChannel
        let oldCandleChannel = currentCandleChannel

        // Subscribe to NEW channels FIRST to avoid missing messages during load
        subscribeToRealTimeTicks(guildId: guildId, symbolId: symbol.id, timeframe: currentTimeframe)

        // Load real chart data from backend
        Task {
            await loadChartData(symbolId: symbol.id, guildId: guildId, timeframe: currentTimeframe, skipSubscribe: true)
            scheduleIndicatorRecalc()

            // Unsubscribe from OLD channels after data is loaded
            var oldChannels: [String] = []
            if let ch = oldTickChannel, ch != currentTickChannel { oldChannels.append(ch) }
            if let ch = oldCandleChannel, ch != currentCandleChannel { oldChannels.append(ch) }
            if !oldChannels.isEmpty {
                RealTimeService.shared.unsubscribe(from: oldChannels, owner: ownerToken)
            }
        }
    }
    
    /// Handle timeframe change - regenerate chart data with new timeframe
    private func handleTimeframeChange() {
        // A deliberate timeframe switch supersedes any in-flight auto-recovery.
        cancelChartRetryLoop()
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id else {
            // No symbol/guild - show error
            unsubscribeFromRealTimeTicks()
            errorMessage = "No symbol or guild selected"
            appState.showError(
                title: "No Chart Data",
                message: RLUserFacingCopy.text(.errorNoChartDataSelection),
                style: .toast
            )
            dataManager.updateWithMarketData([])
            cancelHistoricalPreload()
            scheduleIndicatorRecalc()
            return
        }

        // Capture old channels before subscribing to new ones
        let oldTickChannel = currentTickChannel
        let oldCandleChannel = currentCandleChannel

        // Subscribe to NEW channels FIRST to avoid missing messages during load
        subscribeToRealTimeTicks(guildId: guildId, symbolId: symbol.id, timeframe: currentTimeframe)

        Task {
            // Load data (skip subscribe since we already did it above)
            await loadChartData(symbolId: symbol.id, guildId: guildId, timeframe: currentTimeframe, skipSubscribe: true)
            scheduleIndicatorRecalc()

            // Unsubscribe from OLD channels after data is loaded
            var oldChannels: [String] = []
            if let ch = oldTickChannel, ch != currentTickChannel { oldChannels.append(ch) }
            if let ch = oldCandleChannel, ch != currentCandleChannel { oldChannels.append(ch) }
            if !oldChannels.isEmpty {
                RealTimeService.shared.unsubscribe(from: oldChannels, owner: ownerToken)
            }
        }
    }

    private func firstSupportedSymbol(in symbols: [RLTradingSymbolDTO]) -> RLTradingSymbolDTO? {
        symbols.first(where: { $0.isSelectableForActiveProvider })
    }

    private func syncChartDrawingStorageContext() {
        let storageNamespace = appState.currentUser?.id.uuidString.lowercased()
        chartDrawingManager.storageNamespace = storageNamespace
        chartTimeframeLinkManager.storageNamespace = storageNamespace
        chartDrawingManager.symbolId = currentSymbol?.id
        chartTimeframeLinkManager.symbolId = currentSymbol?.id
        scheduleSyncChartDrawingPlacementFromManager()
    }

    func updateChartDrawingPlacementAnchor(time: Date?, price: Double?) {
        let resolvedTime = time ?? dataManager.candles.last?.timestamp ?? Date()
        let resolvedPrice = price ?? dataManager.candles.last?.close ?? 0
        chartComponentsPlacementState.upsertComponent(
            .anchor,
            payload: .anchor(
                AnchorPayload(
                    time: resolvedTime,
                    price: resolvedPrice
                )
            )
        )
    }

    private func setupChartDrawingPlacementSync() {
        chartDrawingManager.$drawings
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleSyncChartDrawingPlacementFromManager()
            }
            .store(in: &cancellables)

        chartComponentsPlacementState.$components
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleApplyChartDrawingPlacementToManager()
            }
            .store(in: &cancellables)
    }
    
    private func scheduleSyncChartDrawingPlacementFromManager() {
        guard !syncChartDrawingPlacementFromManagerScheduled else { return }
        syncChartDrawingPlacementFromManagerScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncChartDrawingPlacementFromManagerScheduled = false
            self.syncChartDrawingPlacementFromManager()
        }
    }
    
    private func scheduleApplyChartDrawingPlacementToManager() {
        guard !applyChartDrawingPlacementToManagerScheduled else { return }
        applyChartDrawingPlacementToManagerScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyChartDrawingPlacementToManagerScheduled = false
            self.applyChartDrawingPlacementToManager()
        }
    }

    private func syncChartDrawingPlacementFromManager() {
        guard !isApplyingChartDrawingPlacementToManager, !isSyncingChartDrawingPlacementFromManager else { return }
        isSyncingChartDrawingPlacementFromManager = true
        defer { isSyncingChartDrawingPlacementFromManager = false }

        let activeEditingDraftId = chartComponentsPlacementState.editingDrawingId
        let anchorTime = dataManager.candles.last?.timestamp ?? Date()
        let anchorPrice = dataManager.candles.last?.close ?? 0
        let normalizedDrawings = chartDrawingManager.drawings.map {
            ChartDrawingBridge.normalizedAnnotationDrawing(
                from: $0,
                fallbackAnchorTime: anchorTime,
                fallbackAnchorPrice: anchorPrice
            )
        }

        if normalizedDrawings != chartDrawingManager.drawings {
            chartDrawingManager.setDrawings(normalizedDrawings)
        }

        let preservedNonDrawingComponents = chartComponentsPlacementState.components.filter {
            $0.componentType != .anchor && !isChartDrawingPlacementComponent($0.componentType)
        }

        var nextComponents: [MarkerComponentDraft] = [
            MarkerComponentDraft(
                id: chartComponentsPlacementState.anchorDraft?.id ?? UUID(),
                componentType: .anchor,
                payload: .anchor(
                    AnchorPayload(
                        time: anchorTime,
                        price: anchorPrice
                    )
                )
            )
        ]
        nextComponents.append(contentsOf: preservedNonDrawingComponents)
        nextComponents.append(contentsOf: normalizedDrawings.map {
            ChartDrawingBridge.markerDraft(from: $0, anchorTime: anchorTime, anchorPrice: anchorPrice)
        })
        chartComponentsPlacementState.components = nextComponents

        // Seed emoji scale overrides from persisted drawings
        for drawing in normalizedDrawings where drawing.type == .emoji {
            if let scale = drawing.scale {
                chartComponentsPlacementState.emojiScaleOverrides[drawing.id] = CGFloat(scale)
            }
        }
        if let activeEditingDraftId,
           !nextComponents.contains(where: { $0.id == activeEditingDraftId }) {
            chartComponentsPlacementState.commitDrawingAndExit()
        }
    }

    private func applyChartDrawingPlacementToManager() {
        guard !isSyncingChartDrawingPlacementFromManager else { return }
        isApplyingChartDrawingPlacementToManager = true
        defer { isApplyingChartDrawingPlacementToManager = false }
        let anchorTime = dataManager.candles.last?.timestamp ?? Date()
        let anchorPrice = dataManager.candles.last?.close ?? 0
        let nextDrawings = chartComponentsPlacementState.components.compactMap { draft -> ChartDrawing? in
            guard var drawing = ChartDrawingBridge.chartDrawing(from: draft, anchorTime: anchorTime, anchorPrice: anchorPrice) else { return nil }
            if drawing.type == .emoji {
                let scale = chartComponentsPlacementState.emojiScale(for: draft.id)
                if scale != 1.0 {
                    drawing.scale = Double(scale)
                }
            }
            return drawing
        }
        guard nextDrawings != chartDrawingManager.drawings else { return }
        chartDrawingManager.setDrawings(nextDrawings)
    }

    private func isChartDrawingPlacementComponent(_ componentType: RLComponentType) -> Bool {
        switch componentType {
        case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .levelSupport, .levelResistance, .textNote, .reactionEmoji:
            return true
        default:
            return false
        }
    }

    /// Load user's personal watchlist
    private func loadPersonalWatchlist() async throws {
        let watchlistDTO = try await api.getPersonalWatchlist()
        personalWatchlist = watchlistDTO.symbols.map { $0.symbol }
    }
    
    /// Load guild's watchlist
    private func loadGuildWatchlist() async throws {
        guard let guildId = appState.currentGuild?.id else { return }
        let watchlistDTO = try await api.getGuildWatchlist(guildId: guildId)
        guildWatchlist = watchlistDTO.symbols.map { $0.symbol }
    }
    
    
    func loadMarkers() async {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id,
              let markerManager = markerManager else {
            return
        }
        
        await markerManager.loadMarkersFromAPI(
            api: api,
            symbolId: symbol.id,
            symbol: symbol.ticker,
            guildId: guildId,
            timeframe: currentTimeframe,
            candles: dataManager.candles
        )
    }
    
    // Add recalculation trigger method
    func recalculateIndicators() {
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
    }
    
    // MARK: - Real-time Price Updates
    
    /// Set up WebSocket message subscriptions for chart ticks
    private func setupRealTimeSubscriptions() {
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleRealTimeMessage(message)
            }
            .store(in: &cancellables)
    }

    private func setupRealTimeConnectionObserver() {
        RealTimeService.shared.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleRealTimeConnectionStatus(status)
            }
            .store(in: &cancellables)
    }

    private func handleRealTimeConnectionStatus(_ status: RealTimeConnectionStatus) {
        switch status {
        case .connected:
            // Recover the empty / "data unavailable" state too — the resync below
            // only handles charts that already have candles.
            if currentSymbol != nil, dataManager.candles.isEmpty {
                Task { [weak self] in
                    await self?.retryChartDataLoad(reason: "websocket_reconnected_empty")
                }
            }
            guard needsRealtimeResync else { return }
            Task { [weak self] in
                await self?.resyncActiveChart(reason: "websocket_reconnected")
            }
        case .disconnected, .error:
            if currentSymbol != nil, !dataManager.candles.isEmpty {
                needsRealtimeResync = true
            }
        case .connecting:
            break
        }
    }

    func handleAppDidBecomeActive() async {
        if currentSymbol != nil, dataManager.candles.isEmpty {
            await retryChartDataLoad(reason: "app_became_active_empty")
        }
        needsRealtimeResync = true
        await resyncActiveChart(reason: "app_became_active")
    }

    private func startStalenessWatchdog() {
        guard stalenessWatchdogTask == nil else { return }

        stalenessWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self else { return }
                await self.handleRealtimeStalenessWatchdog()
            }
        }
    }

    private func handleRealtimeStalenessWatchdog() async {
        guard let symbol = currentSymbol,
              symbol.isMarketOpen ?? true,
              appState.currentGuild?.id != nil,
              !dataManager.candles.isEmpty,
              !isLoadingData else {
            return
        }

        let now = Date()
        let inactivityThreshold: TimeInterval = currentTimeframe == .m1 ? 20 : 30
        let hasGoneQuiet = now.timeIntervalSince(lastRealtimeMarketEventAt) >= inactivityThreshold
        let currentBucketAge = now.timeIntervalSince(dataManager.candles.last?.timestamp ?? .distantPast)
        let hasMissedABucketBoundary = currentBucketAge >= currentTimeframe.seconds + 5

        guard hasGoneQuiet || hasMissedABucketBoundary else { return }
        await resyncActiveChart(reason: hasMissedABucketBoundary ? "bucket_boundary_watchdog" : "market_stale_watchdog")
    }

    private func resyncActiveChart(reason: String) async {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id else {
            needsRealtimeResync = false
            return
        }

        let now = Date()
        guard !isPerformingRealtimeResync else { return }
        guard now.timeIntervalSince(lastRealtimeResyncAt) >= 2 else {
            needsRealtimeResync = false
            return
        }

        isPerformingRealtimeResync = true
        defer {
            isPerformingRealtimeResync = false
            lastRealtimeResyncAt = Date()
        }

        print("🔄 [Chart] Resyncing active chart (\(reason))")
        subscribeToRealTimeTicks(guildId: guildId, symbolId: symbol.id, timeframe: currentTimeframe)
            await loadChartData(
                symbolId: symbol.id,
                guildId: guildId,
                timeframe: currentTimeframe,
                skipSubscribe: true,
                mergeWithExisting: true
            )
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
        needsRealtimeResync = false
    }

    // MARK: - Empty-state Auto-recovery
    //
    // The staleness watchdog and reconnect resync above only run once candles
    // exist. A *failed initial load* leaves the chart empty behind the
    // "Market Data Unavailable" overlay with no way back. These methods recover
    // that: a public retry (manual button / reconnect / foreground / network
    // restore) plus a self-cancelling exponential-backoff loop.

    /// Re-attempt the initial candle load for the current symbol/timeframe.
    /// Safe to call from the retry button, the backoff loop, websocket reconnect,
    /// app-foreground and network-restore — concurrent calls are coalesced.
    func retryChartDataLoad(reason: String) async {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id,
              !isLoadingData,
              !isPerformingChartRetry else { return }

        isPerformingChartRetry = true
        defer { isPerformingChartRetry = false }

        isRetryingChartLoad = true
        errorMessage = nil
        print("🔄 [Chart] Retrying chart data load (\(reason))")
        subscribeToRealTimeTicks(guildId: guildId, symbolId: symbol.id, timeframe: currentTimeframe)
        await loadChartData(
            symbolId: symbol.id,
            guildId: guildId,
            timeframe: currentTimeframe,
            skipSubscribe: true
        )
        scheduleIndicatorRecalc()
        // loadChartData → updateChartRetryLoop() reconciles isRetryingChartLoad
        // (cancels on recovery, (re)starts the loop if still empty).
    }

    /// Called at the end of every load: starts the backoff loop when we are
    /// stuck with a symbol but no candles, otherwise tears it down.
    private func updateChartRetryLoop() {
        if currentSymbol != nil, dataManager.candles.isEmpty {
            startChartRetryLoopIfNeeded()
        } else {
            cancelChartRetryLoop()
        }
    }

    private func startChartRetryLoopIfNeeded() {
        guard chartRetryTask == nil,
              currentSymbol != nil,
              dataManager.candles.isEmpty else { return }

        isRetryingChartLoad = true
        chartRetryTask = Task { [weak self] in
            guard let self else { return }
            var attempt = 0
            while !Task.isCancelled {
                guard self.currentSymbol != nil, self.dataManager.candles.isEmpty else { break }

                attempt += 1
                self.chartRetryAttempt = attempt
                // Exponential backoff capped at 30s: 2, 4, 8, 16, 30, 30…
                let delaySeconds = min(30.0, pow(2.0, Double(attempt)))
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                if Task.isCancelled { break }

                await self.retryChartDataLoad(reason: "auto_retry_\(attempt)")
                if !self.dataManager.candles.isEmpty { break }
            }
            self.chartRetryTask = nil
            self.isRetryingChartLoad = false
            self.chartRetryAttempt = 0
        }
    }

    private func cancelChartRetryLoop() {
        chartRetryTask?.cancel()
        chartRetryTask = nil
        isRetryingChartLoad = false
        chartRetryAttempt = 0
    }

    private func reconcileCurrentCandleWithSymbolSnapshot(_ symbol: RLTradingSymbolDTO) {
        guard let snapshotPrice = symbol.currentPrice else { return }
        guard let snapshotTimestamp = symbol.marketStatusUpdatedAt else {
            dataManager.currentPrice = snapshotPrice
            return
        }

        if let lastCandleTimestamp = dataManager.candles.last?.timestamp,
           snapshotTimestamp < lastCandleTimestamp {
            return
        }

        dataManager.processRealTick(
            price: snapshotPrice,
            volume: 0,
            timestamp: snapshotTimestamp
        )
        noteRealtimeMarketEvent()
    }

    private func noteRealtimeMarketEvent() {
        lastRealtimeMarketEventAt = Date()
    }
    
    private func scheduleIndicatorRecalc() {
        guard !pendingIndicatorRecalc else { return }
        pendingIndicatorRecalc = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.indicatorRecalcCoalesceWindow ?? 0.08) * 1_000_000_000))
            guard let self else { return }
            self.pendingIndicatorRecalc = false
            self.indicatorManager.recalculateIndicators(candles: self.dataManager.candles)
        }
    }

    /// Handle incoming WebSocket messages for chart data
    private func handleRealTimeMessage(_ message: WSIncomingMessage) {
        // Only handle messages on our subscribed market channels
        guard let channel = message.channel,
              channel == currentTickChannel || channel == currentCandleChannel else {
            return
        }

        // Handle tick messages (type: "tick")
        if message.type == "tick" {
            guard let tickData = message.payload(as: MarketTickPayload.self) else { return }
            dataManager.processRealTick(
                price: tickData.price,
                volume: tickData.volume ?? 0,
                timestamp: tickData.timestamp
            )
            noteRealtimeMarketEvent()
            scheduleIndicatorRecalc()
        }
        // Handle completed candle messages (type: "candle_complete")
        else if message.type == "candle_complete" {
            guard let candlePayload = message.payload(as: MarketCandlePayload.self) else { return }

            // Reject candles from wrong timeframe (can happen during switchover overlap)
            guard candlePayload.timeframe == currentTimeframe.toBackendString() else { return }
            let candle = RLCandleDTO(
                timestamp: candlePayload.candle.timestamp,
                open: candlePayload.candle.open,
                high: candlePayload.candle.high,
                low: candlePayload.candle.low,
                close: candlePayload.candle.close,
                volume: candlePayload.candle.volume
            )
            let firstTimestampBefore = dataManager.candles.first?.timestamp
            let trimmedCount = dataManager.processRealCandle(candle)
            let firstTimestampAfter = dataManager.candles.first?.timestamp

            if trimmedCount > 0 && !isNavigatingToMarker {
                // Preserve viewport continuity when front candles are dropped.
                gestureState.panOffset.width += CGFloat(trimmedCount) * totalCandleWidth
            }

            // If front candles were trimmed, recalculate marker indices from timestamps
            if let before = firstTimestampBefore, let after = firstTimestampAfter, before != after {
                markerManager?.recalculateCandleIndices(candles: dataManager.candles)
            }

            noteRealtimeMarketEvent()
            scheduleIndicatorRecalc()
        }
        else if message.type == "candle_update" {
            guard let candlePayload = message.payload(as: MarketCandlePayload.self) else { return }
            guard candlePayload.timeframe == currentTimeframe.toBackendString() else { return }

            dataManager.processRealTick(
                price: candlePayload.candle.close,
                volume: candlePayload.candle.volume,
                timestamp: candlePayload.candle.timestamp
            )
            noteRealtimeMarketEvent()
            scheduleIndicatorRecalc()
        }
    }
    
    /// Subscribe to real-time market data for a symbol/timeframe
    // Internal rather than private so tests can pin the multi-pane invariant:
    // these must register under `ownerToken`, never a shared literal.
    func subscribeToRealTimeTicks(guildId: UUID, symbolId: UUID, timeframe: RLChartTimeframe) {
        // Unsubscribe from previous channels
        unsubscribeFromRealTimeTicks()

        let symbolIdStr = symbolId.uuidString.lowercased()
        let timeframeString = timeframe.toBackendString()

        // Subscribe to tick channel: market:ticks:{symbol_id}
        let tickChannel = "market:ticks:\(symbolIdStr)"
        currentTickChannel = tickChannel

        // Subscribe to candle channel: market:candles:{symbol_id}:{timeframe}
        let candleChannel = "market:candles:\(symbolIdStr):\(timeframeString)"
        currentCandleChannel = candleChannel

        RealTimeService.shared.subscribe(to: [tickChannel, candleChannel], owner: ownerToken)
        print("📡 [Chart] Subscribed to market data: \(tickChannel), \(candleChannel)")
    }

    /// Unsubscribe from real-time market data (called when chart is closed or symbol changes)
    func unsubscribeFromRealTimeTicks() {
        var channels: [String] = []
        if let channel = currentTickChannel {
            channels.append(channel)
            currentTickChannel = nil
        }
        if let channel = currentCandleChannel {
            channels.append(channel)
            currentCandleChannel = nil
        }
        if !channels.isEmpty {
            RealTimeService.shared.unsubscribe(from: channels, owner: ownerToken)
            print("📡 [Chart] Unsubscribed from market data")
        }
    }
}

// MARK: - Market Data Payloads

/// Payload for real-time tick messages from market-ingestion-service
/// Backend publishes: {symbol_id, ticker, price, bid, ask, volume, timestamp}
struct MarketTickPayload: Codable {
    let symbolId: String
    let ticker: String
    let price: Double
    let bid: Double?
    let ask: Double?
    let volume: Double?
    let timestamp: Date?
}

/// Payload for completed candle messages from market-ingestion-service
/// Backend publishes: {symbol_id, ticker, timeframe, candle: {timestamp, open, high, low, close, volume}}
struct MarketCandlePayload: Codable {
    let symbolId: String
    let ticker: String
    let timeframe: String
    let candle: MarketCandleData
}

/// Individual candle data within MarketCandlePayload
struct MarketCandleData: Codable {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}
