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
    
    private let appState: AppState
    let dataManager: ChartDataManager
    private let api: MockAPIService
    
    weak var markerManager: MarkerManager?
    
    // MARK: - Published State
    
    @Published var currentSymbol: TradingSymbolDTO?
    @Published var currentTimeframe: ChartTimeframe = .m5
    @Published var availableSymbols: [TradingSymbolDTO] = []
    @Published var isLoadingData: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Watchlists
    
    @Published var personalWatchlist: [TradingSymbolDTO] = []
    @Published var guildWatchlist: [TradingSymbolDTO] = []
    
    
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
    
    var combinedWatchlist: [TradingSymbolDTO] {
        let combined = personalWatchlist + guildWatchlist
        var seen = Set<UUID>()
        return combined.filter { symbol in
            guard !seen.contains(symbol.id) else { return false }
            seen.insert(symbol.id)
            return true
        }
    }
    
    // MARK: - Initialization
    
    init(appState: AppState, dataManager: ChartDataManager, api: MockAPIService) {
        self.appState = appState
        self.dataManager = dataManager
        self.api = api
    }
    
    // MARK: - Public Methods
    
    /// Initialize the view model with data
    func initialize() async {
        isLoadingData = true
        
        do {
            // Load watchlists
            if let userId = appState.currentUser?.id {
                personalWatchlist = try await api.fetchPersonalWatchlist(userId: userId)
            }
            
            if let guildId = appState.currentGuild?.id {
                guildWatchlist = try await api.fetchChartGuildWatchlist(guildId: guildId)
            }
            
            // Set initial symbol from combined watchlist
            if currentSymbol == nil {
                currentSymbol = combinedWatchlist.first
            }
            
            // CRITICAL: Regenerate chart data with the actual symbol and timeframe
            // This fixes the "100.00 price on launch" issue
            if let symbol = currentSymbol {
                dataManager.regenerateMockData(symbol: symbol, timeframe: currentTimeframe)
            } else {
                // Fallback if no symbols available
                dataManager.regenerateMockData(timeframe: currentTimeframe)
            }
            
        } catch {
            errorMessage = "Failed to load watchlists: \(error.localizedDescription)"
            // Still start with default data even if watchlist fails
            dataManager.regenerateMockData(timeframe: currentTimeframe)
        }
        
        isLoadingData = false
        // ADD: After data is loaded, calculate indicators
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
    }
    
    /// Set the current symbol and regenerate chart data
    func setSymbol(_ symbol: TradingSymbolDTO) {
        guard currentSymbol?.id != symbol.id else { return }
        
        currentSymbol = symbol
        handleSymbolChange()
    }
    
    /// Set the current timeframe and regenerate chart data
    func setTimeframe(_ timeframe: ChartTimeframe) {
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
        guard let symbol = currentSymbol else { return }
        
        // Use the symbol-aware regeneration method
        dataManager.regenerateMockData(symbol: symbol, timeframe: currentTimeframe)
        
        // ADD: Recalculate indicators
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
        
        // TODO: When backend is ready, replace with:
        // Task {
        //     let candles = try await api.fetchHistoricalCandles(
        //         symbol: symbol.symbol,
        //         timeframe: currentTimeframe,
        //         limit: currentTimeframe.initialCandlesCount
        //     )
        //     dataManager.updateWithMarketData(candles)
        // }
    }
    
    /// Handle timeframe change - regenerate chart data with new timeframe
    private func handleTimeframeChange() {
        if let symbol = currentSymbol {
            // Use symbol-aware regeneration
            dataManager.regenerateMockData(symbol: symbol, timeframe: currentTimeframe)
        } else {
            // Fallback without symbol
            dataManager.regenerateMockData(timeframe: currentTimeframe)
        }
        
        // ADD: Recalculate indicators
        indicatorManager.recalculateIndicators(candles: dataManager.candles)
        
        // TODO: When backend is ready, replace with:
        // Task {
        //     guard let symbol = currentSymbol else { return }
        //     let candles = try await api.fetchHistoricalCandles(
        //         symbol: symbol.symbol,
        //         timeframe: currentTimeframe,
        //         limit: currentTimeframe.initialCandlesCount
        //     )
        //     dataManager.updateWithMarketData(candles)
        // }
    }
    
    /// Load user's personal watchlist
    private func loadPersonalWatchlist() async throws {
        guard let userId = appState.currentUser?.id else { return }
        personalWatchlist = try await api.fetchPersonalWatchlist(userId: userId)
    }
    
    /// Load guild's watchlist
    private func loadGuildWatchlist() async throws {
        guard let guildId = appState.currentGuild?.id else { return }
        guildWatchlist = try await api.fetchChartGuildWatchlist(guildId: guildId)
    }
    
    
    func loadMarkers() async {
        guard let symbol = currentSymbol,
              let guildId = appState.currentGuild?.id,
              let markerManager = markerManager else {
            return
        }
        
        await markerManager.loadMarkersFromAPI(
            api: api,
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
}



