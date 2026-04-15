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
    private var lastRealtimeMarketEventAt: Date = .distantPast
    
    /// Current WebSocket channel subscriptions for real-time market data
    private var currentTickChannel: String?
    private var currentCandleChannel: String?
    
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
    @Published var availableSymbols: [RLTradingSymbolDTO] = []
    @Published var activeMarketProvider: String?
    @Published var activeMarketProviderUpdatedAt: Date?
    @Published var isLoadingData: Bool = false
    @Published private(set) var isLoadingOlderCandles: Bool = false
    @Published private(set) var hasMoreHistoricalCandles: Bool = false
    @Published var errorMessage: String?
    private var earliestHistoricalCandleTimestamp: Date?
    private let historicalCandlePageSize = 1000
    
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
    
    init(appState: RLAppState, dataManager: ChartDataManager, api: RealAPIService) {
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
                activeMarketProvider = providerStatus.activeProvider
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
            if let providerFromSymbols = available.first(where: { $0.activeMarketProvider != nil })?.activeMarketProvider {
                activeMarketProvider = providerFromSymbols
            }

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
            errorMessage = RLUserFacingErrorMapper.message(from: error)
            appState.showError(error, title: "Failed to Load Chart Data", style: .toast)
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
                let prependedCount = dataManager.mergeHistoricalMarketData(chartData.candles)
                if prependedCount > 0 {
                    gestureState.panOffset.width -= CGFloat(prependedCount) * totalCandleWidth
                }
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
            errorMessage = RLUserFacingErrorMapper.message(from: error)
            appState.showError(error, title: "Failed to Load Chart", style: .toast)
            // Clear candles on error - don't show stale or mock data
            dataManager.updateWithMarketData([])
            earliestHistoricalCandleTimestamp = nil
            hasMoreHistoricalCandles = false
        }
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
                message: "Provider changed. Switched to \(fallback.ticker).",
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

        errorMessage = "No symbols supported by active provider"
        dataManager.updateWithMarketData([])
        earliestHistoricalCandleTimestamp = nil
        hasMoreHistoricalCandles = false
        appState.showError(
            title: "No Supported Symbols",
            message: detail.isEmpty
                ? "No symbols are supported by the active market provider."
                : detail,
            style: .toast
        )
    }
    
    /// Set the current symbol and regenerate chart data
    func setSymbol(_ symbol: RLTradingSymbolDTO) {
        guard symbol.isSelectableForActiveProvider else {
            let providerText = symbol.activeProviderDisplayName ?? "active provider"
            appState.showError(
                title: "Symbol Unavailable",
                message: "\(symbol.ticker) is not supported by \(providerText).",
                style: .toast
            )
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
            let prependedCount = dataManager.mergeHistoricalMarketData(candlesResponse.candles)
            if prependedCount > 0 {
                gestureState.panOffset.width -= CGFloat(prependedCount) * totalCandleWidth
            }
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
            }

            indicatorManager.recalculateIndicators(candles: dataManager.candles)
        } catch {
            print("Failed to load navigation window: \(error)")
        }
    }

    @discardableResult
    func loadOlderCandlesIfNeeded(
        visibleStartIndex: Int,
        preloadThreshold: Int
    ) async -> Int {
        guard visibleStartIndex <= preloadThreshold else { return 0 }
        return await loadOlderCandles()
    }

    @discardableResult
    func loadOlderCandles() async -> Int {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id,
              hasMoreHistoricalCandles,
              !isLoadingOlderCandles,
              !isLoadingData else {
            return 0
        }

        let endTime = earliestHistoricalCandleTimestamp ?? dataManager.candles.first?.timestamp
        guard let endTime else { return 0 }

        isLoadingOlderCandles = true
        defer { isLoadingOlderCandles = false }

        do {
            let previousFirstTimestamp = dataManager.candles.first?.timestamp
            let candlesResponse = try await api.getCandles(
                symbolId: symbol.id,
                timeframe: currentTimeframe.toBackendString(),
                limit: historicalCandlePageSize,
                endTime: endTime,
                continuousTime: true
            )

            let prependedCount = dataManager.mergeHistoricalMarketData(candlesResponse.candles)
            if prependedCount > 0 {
                gestureState.panOffset.width -= CGFloat(prependedCount) * totalCandleWidth
            }

            earliestHistoricalCandleTimestamp = dataManager.candles.first?.timestamp ?? candlesResponse.earliestTimestamp
            hasMoreHistoricalCandles = candlesResponse.hasMore && prependedCount > 0

            if prependedCount > 0, let markerManager {
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

            if prependedCount > 0 {
                indicatorManager.recalculateIndicators(candles: dataManager.candles)
            }
            return prependedCount
        } catch {
            print("Failed to load older candles: \(error)")
            return 0
        }
    }
    
    /// Reload all data (watchlists and chart)
    func reloadData() async {
        await initialize()
    }
    
    // MARK: - Private Methods
    
    /// Handle symbol change - regenerate chart data with new symbol
    private func handleSymbolChange() {
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
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
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
            indicatorManager.recalculateIndicators(candles: dataManager.candles)

            // Unsubscribe from OLD channels after data is loaded
            var oldChannels: [String] = []
            if let ch = oldTickChannel, ch != currentTickChannel { oldChannels.append(ch) }
            if let ch = oldCandleChannel, ch != currentCandleChannel { oldChannels.append(ch) }
            if !oldChannels.isEmpty {
                RealTimeService.shared.unsubscribe(from: oldChannels, owner: "chart")
            }
        }
    }
    
    /// Handle timeframe change - regenerate chart data with new timeframe
    private func handleTimeframeChange() {
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
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
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
            indicatorManager.recalculateIndicators(candles: dataManager.candles)

            // Unsubscribe from OLD channels after data is loaded
            var oldChannels: [String] = []
            if let ch = oldTickChannel, ch != currentTickChannel { oldChannels.append(ch) }
            if let ch = oldCandleChannel, ch != currentCandleChannel { oldChannels.append(ch) }
            if !oldChannels.isEmpty {
                RealTimeService.shared.unsubscribe(from: oldChannels, owner: "chart")
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
        case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .levelSupport, .levelResistance, .textNote, .reactionEmoji:
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
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
        }
        // Handle completed candle messages (type: "candle_complete")
        else if message.type == "candle_complete" {
            guard let candlePayload = message.payload(as: MarketCandlePayload.self) else { return }

            // Reject candles from wrong timeframe (can happen during switchover overlap)
            guard candlePayload.timeframe == currentTimeframe.toBackendString() else { return }
            let candle = RLCandleDTO(
                timestamp: candlePayload.candle.timestamp,
                timestampFormatted: nil,
                open: candlePayload.candle.open,
                high: candlePayload.candle.high,
                low: candlePayload.candle.low,
                close: candlePayload.candle.close,
                volume: candlePayload.candle.volume,
                volumeFormatted: nil
            )
            let firstTimestampBefore = dataManager.candles.first?.timestamp
            let trimmedCount = dataManager.processRealCandle(candle)
            let firstTimestampAfter = dataManager.candles.first?.timestamp

            if trimmedCount > 0 {
                // Preserve viewport continuity when front candles are dropped.
                gestureState.panOffset.width += CGFloat(trimmedCount) * totalCandleWidth
            }

            // If front candles were trimmed, recalculate marker indices from timestamps
            if let before = firstTimestampBefore, let after = firstTimestampAfter, before != after {
                markerManager?.recalculateCandleIndices(candles: dataManager.candles)
            }

            noteRealtimeMarketEvent()
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
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
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
        }
    }
    
    /// Subscribe to real-time market data for a symbol/timeframe
    private func subscribeToRealTimeTicks(guildId: UUID, symbolId: UUID, timeframe: RLChartTimeframe) {
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

        RealTimeService.shared.subscribe(to: [tickChannel, candleChannel], owner: "chart")
        print("📡 [Chart] Subscribed to market data: \(tickChannel), \(candleChannel)")
    }

    /// Unsubscribe from real-time market data (called when chart is closed or symbol changes)
    private func unsubscribeFromRealTimeTicks() {
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
            RealTimeService.shared.unsubscribe(from: channels, owner: "chart")
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
