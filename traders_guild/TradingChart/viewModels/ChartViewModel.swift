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
    
    /// Current WebSocket channel subscriptions for real-time market data
    private var currentTickChannel: String?
    private var currentCandleChannel: String?
    
    /// Configure with proper app state and API service
    /// Called from MainView.onAppear when EnvironmentObjects are available
    func configure(appState: RLAppState, api: RealAPIService) {
        self.appState = appState
        self.api = api
        setupRealTimeSubscriptions()
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
    @Published var errorMessage: String?
    
    // MARK: - Watchlists
    
    @Published var personalWatchlist: [RLTradingSymbolDTO] = []
    @Published var guildWatchlist: [RLTradingSymbolDTO] = []
    @Published var globalSymbols: [RLTradingSymbolDTO] = []
    
    
    // MARK: Indicator manager
    
    // IMPORTANT: Expose gestureState for RSI panel synchronization
    let gestureState = ChartGestureState()
    
    @Published var indicatorManager = IndicatorManager()
    
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
    }
    
    // MARK: - Public Methods
    
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
            errorMessage = "Failed to load watchlists: \(error.localizedDescription)"
            appState.showError(error, title: "Failed to Load Chart Data", style: .toast)
        }
        
        isLoadingData = false
        // ADD: After data is loaded, calculate indicators
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
    }
    
    /// Load chart data (symbol + candles + markers) from backend
    private func loadChartData(symbolId: UUID, guildId: UUID, timeframe: RLChartTimeframe, skipSubscribe: Bool = false) async {
        do {
            let timeframeString = timeframe.toBackendString()
            let chartData = try await api.getChartData(
                guildId: guildId,
                symbolId: symbolId,
                timeframe: timeframeString,
                candleLimit: timeframe.initialCandlesCount
            )

            // Update current symbol if it changed
            if currentSymbol?.id != chartData.symbol.id {
                currentSymbol = chartData.symbol
            }
            activeMarketProvider = chartData.symbol.activeMarketProvider ?? activeMarketProvider

            // Sync symbol to dataManager so MarkerCreationSheet can access it
            dataManager.currentSymbol = chartData.symbol
            dataManager.currentTimeframe = timeframe

            // Update candles
            dataManager.updateWithMarketData(chartData.candles)

            // Subscribe to real-time price ticks for this symbol/timeframe
            // (skipped when caller already subscribed to avoid double-subscribe)
            if !skipSubscribe {
                subscribeToRealTimeTicks(guildId: guildId, symbolId: symbolId, timeframe: timeframe)
            }

            // Update markers (if markerManager is set)
            if let markerManager = markerManager {
                await markerManager.loadMarkersFromAPI(
                    api: api,
                    symbolId: chartData.symbol.id,
                    symbol: chartData.symbol.ticker,
                    guildId: guildId,
                    timeframe: timeframe,
                    candles: dataManager.candles
                )
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
            errorMessage = "Failed to load chart data: \(error.localizedDescription)"
            appState.showError(error, title: "Failed to Load Chart", style: .toast)
            // Clear candles on error - don't show stale or mock data
            dataManager.updateWithMarketData([])
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
            appState.showError(title: "No Guild", message: "Please select a guild to view charts", style: .toast)
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
            appState.showError(title: "No Chart Data", message: "Please select a symbol and guild", style: .toast)
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
