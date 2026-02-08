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
    
    // MARK: - Published State
    
    @Published var currentSymbol: RLTradingSymbolDTO?
    @Published var currentTimeframe: RLChartTimeframe = .m5
    @Published var availableSymbols: [RLTradingSymbolDTO] = []
    @Published var isLoadingData: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Watchlists
    
    @Published var personalWatchlist: [RLTradingSymbolDTO] = []
    @Published var guildWatchlist: [RLTradingSymbolDTO] = []
    
    
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
            // Load watchlists using new API
            let personalWatchlistDTO = try await api.getPersonalWatchlist()
            personalWatchlist = personalWatchlistDTO.symbols.map { $0.symbol }
            
            if let guildId = appState.currentGuild?.id {
                let guildWatchlistDTO = try await api.getGuildWatchlist(guildId: guildId)
                guildWatchlist = guildWatchlistDTO.symbols.map { $0.symbol }
            }
            
            // Set initial symbol from combined watchlist
            if currentSymbol == nil {
                currentSymbol = combinedWatchlist.first
            }
            
            // Load chart data for the selected symbol
            if let symbol = currentSymbol, let guildId = appState.currentGuild?.id {
                await loadChartData(symbolId: symbol.id, guildId: guildId, timeframe: currentTimeframe)
            } else {
                // No symbols available - show error
                errorMessage = "No symbols available in watchlist"
                appState.showError(title: "No Chart Data", message: "Please add symbols to your watchlist", style: .toast)
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
    private func loadChartData(symbolId: UUID, guildId: UUID, timeframe: RLChartTimeframe) async {
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
            
            // Update candles
            dataManager.updateWithMarketData(chartData.candles)
            
            // Subscribe to real-time price ticks for this symbol/timeframe
            subscribeToRealTimeTicks(guildId: guildId, symbolId: symbolId, timeframe: timeframe)
            
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
            errorMessage = "Failed to load chart data: \(error.localizedDescription)"
            appState.showError(error, title: "Failed to Load Chart", style: .toast)
            // Clear candles on error - don't show stale or mock data
            dataManager.updateWithMarketData([])
        }
    }
    
    /// Set the current symbol and regenerate chart data
    func setSymbol(_ symbol: RLTradingSymbolDTO) {
        guard currentSymbol?.id != symbol.id else { return }
        
        currentSymbol = symbol
        handleSymbolChange()
    }
    
    /// Set the current timeframe and regenerate chart data
    func setTimeframe(_ timeframe: RLChartTimeframe) {
        guard currentTimeframe != timeframe else { return }
        
        currentTimeframe = timeframe
        handleTimeframeChange()
    }
    
    /// Reload all data (watchlists and chart)
    func reloadData() async {
        await initialize()
    }
    
    // MARK: - Private Methods
    
    /// Handle symbol change - regenerate chart data with new symbol
    private func handleSymbolChange() {
        // Unsubscribe from old symbol's ticks
        unsubscribeFromRealTimeTicks()
        
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id else {
            // No guild selected - show error
            errorMessage = "No guild selected"
            appState.showError(title: "No Guild", message: "Please select a guild to view charts", style: .toast)
            dataManager.updateWithMarketData([])
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
            return
        }
        
        // Load real chart data from backend
        Task {
            await loadChartData(symbolId: symbol.id, guildId: guildId, timeframe: currentTimeframe)
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
        }
    }
    
    /// Handle timeframe change - regenerate chart data with new timeframe
    private func handleTimeframeChange() {
        // Unsubscribe from old timeframe's ticks
        unsubscribeFromRealTimeTicks()
        
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id else {
            // No symbol/guild - show error
            errorMessage = "No symbol or guild selected"
            appState.showError(title: "No Chart Data", message: "Please select a symbol and guild", style: .toast)
            dataManager.updateWithMarketData([])
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
            return
        }
        
        // Load real chart data with new timeframe
        Task {
            await loadChartData(symbolId: symbol.id, guildId: guildId, timeframe: currentTimeframe)
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
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
                timestamp: nil
            )
            indicatorManager.recalculateIndicators(candles: dataManager.candles)
        }
        // Handle completed candle messages (type: "candle_complete")
        else if message.type == "candle_complete" {
            guard let candlePayload = message.payload(as: MarketCandlePayload.self) else { return }
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
            dataManager.processRealCandle(candle)
            let firstTimestampAfter = dataManager.candles.first?.timestamp

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
    let timestamp: String?
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



