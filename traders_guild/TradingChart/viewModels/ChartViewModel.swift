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
    
    // MARK: - Published State
    
    @Published var currentSymbol: TradingSymbol?
    @Published var currentTimeframe: ChartTimeframe = .h1
    @Published var availableSymbols: [TradingSymbol] = []
    @Published var isLoadingData: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Watchlists
    
    @Published var personalWatchlist: [TradingSymbol] = []
    @Published var guildWatchlist: [TradingSymbol] = []
    
    var combinedWatchlist: [TradingSymbol] {
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
    }
    
    /// Set the current symbol and regenerate chart data
    func setSymbol(_ symbol: TradingSymbol) {
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
}
