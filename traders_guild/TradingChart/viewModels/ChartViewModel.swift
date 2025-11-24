//
//  ChartViewModel.swift
//  traders_guild
//
//  FIXED VERSION - Uses chartGuildWatchlist instead of guildWatchlist
//

import SwiftUI
import Combine

@MainActor
class ChartViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    /// Reference to app state for user/guild info
    private let appState: AppState
    
    /// Chart data manager handles candle generation
    let dataManager: ChartDataManager
    
    /// API service for fetching watchlists
    private let api: MockAPIService
    
    // MARK: - Published State
    
    /// Currently selected trading symbol
    @Published var currentSymbol: TradingSymbol?
    
    /// Currently selected timeframe
    @Published var currentTimeframe: ChartTimeframe = .h1
    
    /// Available symbols for quick selection
    @Published var availableSymbols: [TradingSymbol] = []
    
    /// Loading state
    @Published var isLoadingData: Bool = false
    
    /// Error message if something goes wrong
    @Published var errorMessage: String?
    
    // MARK: - Watchlists
    
    /// User's personal watchlist
    @Published var personalWatchlist: [TradingSymbol] = []
    
    /// Guild's shared watchlist (UPDATED NAME)
    @Published var guildWatchlist: [TradingSymbol] = []
    
    /// Combined watchlist (personal + guild, duplicates removed)
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
                // UPDATED: Using the renamed method
                guildWatchlist = try await api.fetchChartGuildWatchlist(guildId: guildId)
            }
            
            // Set initial symbol from combined watchlist
            if currentSymbol == nil {
                currentSymbol = combinedWatchlist.first
            }
            
            // Start data generation
            dataManager.startDataGeneration()
            
        } catch {
            errorMessage = "Failed to load watchlists: \(error.localizedDescription)"
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
    
    /// Handle symbol change - regenerate chart data
    private func handleSymbolChange() {
        // TODO: When backend is ready, replace this with real API call
        // Example:
        // let candles = try await api.fetchHistoricalCandles(
        //     symbol: currentSymbol.symbol,
        //     timeframe: currentTimeframe,
        //     limit: currentTimeframe.initialCandlesCount
        // )
        // dataManager.updateWithMarketData(candles)
        
        // For now, regenerate mock data
        dataManager.regenerateMockData()
    }
    
    /// Handle timeframe change - regenerate chart data
    private func handleTimeframeChange() {
        // TODO: When backend is ready, replace this with real API call
        // Example:
        // let candles = try await api.fetchHistoricalCandles(
        //     symbol: currentSymbol.symbol,
        //     timeframe: currentTimeframe,
        //     limit: currentTimeframe.initialCandlesCount
        // )
        // dataManager.updateWithMarketData(candles)
        
        // For now, regenerate mock data with timeframe-specific candle count
        dataManager.regenerateMockData(candleCount: currentTimeframe.initialCandlesCount)
    }
    
    /// Load user's personal watchlist
    private func loadPersonalWatchlist() async throws {
        guard let userId = appState.currentUser?.id else { return }
        personalWatchlist = try await api.fetchPersonalWatchlist(userId: userId)
    }
    
    /// Load guild's watchlist
    private func loadGuildWatchlist() async throws {
        guard let guildId = appState.currentGuild?.id else { return }
        // UPDATED: Using the renamed method
        guildWatchlist = try await api.fetchChartGuildWatchlist(guildId: guildId)
    }
}
