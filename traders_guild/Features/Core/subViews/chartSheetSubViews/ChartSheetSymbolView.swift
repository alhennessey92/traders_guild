//
//  ChartSheetSymbolView.swift
//  traders_guild
//
//  Symbol and timeframe selector for chart bottom sheet
//  UPDATED: Now uses UnifiedComponents for consistent styling
//  UPDATED: Guild watchlist is now request-based (sends request to admin)
//
//  Features: Symbol icons with gradient backgrounds, watchlist tabs, search
//
//  NOTE: RootBottomBarSymbolButton and RootBottomBarIconButton are in separate files
//

import SwiftUI
import UIKit

// MARK: - Symbol Sheet Tab Definition

/// Tab enum conforming to UnifiedTabItem for use with UnifiedTabBar
enum SymbolSheetTab: String, CaseIterable, UnifiedTabItem {
    case personal = "Personal"
    case guild = "Guild"
    case global = "Global"
    case search = "Search"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .personal: return "star.fill"
        case .guild: return "person.3.fill"
        case .global: return "globe"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - Main Symbol Sheet View

struct ChartSheetSymbolView: View {
    @ObservedObject var chartViewModel: ChartViewModel
    @EnvironmentObject var rlAppState: RLAppState
    
    // Watchlist tab state
    @State private var selectedWatchlistTab: SymbolSheetTab = .personal
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [RLTradingSymbolDTO] = []
    
    // Watchlist button loading states
    @State private var isAddingToPersonal: Bool = false
    @State private var isRequestingGuild: Bool = false
    @State private var pendingGuildRequests: [RLGuildWatchlistRequestResponseDTO] = []
    
    // Confirmation dialog state (personal only now)
    @State private var symbolToRemove: RLTradingSymbolDTO? = nil
    @State private var showRemoveConfirmation: Bool = false
    
    // Guild request alert state
    @State private var showGuildRequestAlert: Bool = false
    @State private var symbolToRequest: RLTradingSymbolDTO? = nil
    
    // Helper to get current symbol as DTO
    private var currentSymbolDTO: RLTradingSymbolDTO? {
        return chartViewModel.currentSymbol
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Current Symbol Header
            currentSymbolHeader
            
            // Loading indicator
            if chartViewModel.isLoadingData {
                loadingIndicator
            }
            
            // Timeframe Selector
            timeframeSection
            
            // Watchlist Section with Tabs
            watchlistSection
        }
        //.background(UnifiedStaticBackground())
        .confirmationDialog(
            "Remove from Personal Watchlist?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible,
            presenting: symbolToRemove
        ) { symbol in
            Button("Remove \(symbol.ticker)", role: .destructive) {
                confirmRemoveSymbol(symbol)
            }
            Button("Cancel", role: .cancel) {
                symbolToRemove = nil
            }
        } message: { symbol in
            Text("This will remove \(symbol.displayName) from your personal watchlist.")
        }
        .alert("Request Guild Watchlist Addition", isPresented: $showGuildRequestAlert, presenting: symbolToRequest) { symbol in
            Button("Send Request") {
                sendGuildWatchlistRequest(symbol: symbol)
            }
            Button("Cancel", role: .cancel) {
                symbolToRequest = nil
            }
        } message: { symbol in
            Text("Request to add \(symbol.ticker) to the guild watchlist? A guild admin will review your request.")
        }
        .onDisappear {
            dismissKeyboard()
        }
        .onAppear {
            Task {
                await reloadGuildRequestState()
            }
        }
        .onChange(of: rlAppState.currentGuild?.id) { _ in
            Task {
                await reloadGuildRequestState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildWatchlistUpdated)) { _ in
            Task {
                await chartViewModel.reloadData()
                await reloadGuildRequestState()
            }
        }
    }
    
    private func requestRemoveSymbol(_ symbol: RLTradingSymbolDTO) {
        symbolToRemove = symbol
        showRemoveConfirmation = true
    }
    
    private func confirmRemoveSymbol(_ symbol: RLTradingSymbolDTO) {
        togglePersonalWatchlist(symbol: symbol, isCurrentlyIn: true)
        symbolToRemove = nil
    }
    
    // MARK: - Current Symbol Header
    
    private var currentSymbolHeader: some View {
        Group {
            if let symbol = currentSymbolDTO {
                VStack(spacing: 12) {
                    // Main header row - icon top-aligned with content
                    HStack(alignment: .top, spacing: 12) {
                        // Symbol Icon - top aligned
                        SymbolIconView(symbol: symbol, size: 48)
                        
                        // Middle section: name, ticker, asset class
                        VStack(alignment: .leading, spacing: 3) {
                            Text(symbol.displayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            HStack(spacing: 5) {
                                Text(symbol.ticker)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                // Market status
                                SymbolMarketStatus(isActive: symbol.isActive)
                                
                                Text("•")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                                
                                Text(symbol.assetClass.capitalized)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        
                        // Price section - fixed width to prevent squishing
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(symbol.formatPrice(chartViewModel.dataManager.currentPrice))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 2) {
                                Image(systemName: (symbol.isUp ?? true) ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(symbol.changeFormatted ?? "--")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(symbol.changeColor)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    // Watchlist buttons row
                    watchlistButtons(for: symbol)
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            symbol.primaryColorValue.opacity(0.35),
                            symbol.secondaryColorValue.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(symbol.primaryColorValue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(14)
            }
        }
    }
    
    // MARK: - Watchlist Buttons
    
    private func watchlistButtons(for symbol: RLTradingSymbolDTO) -> some View {
        // Use chartViewModel watchlists as single source of truth
        let inPersonal = chartViewModel.personalWatchlist.contains { $0.id == symbol.id }
        let inGuild = chartViewModel.guildWatchlist.contains { $0.id == symbol.id }
        let isRequested = pendingGuildRequests.contains { $0.symbolId == symbol.id && $0.status.lowercased() == "pending" }
        let canDirectlyManageGuildWatchlist = rlAppState.canAdmin
        
        return HStack(spacing: 10) {
            // Personal watchlist button - unchanged behavior
            Button(action: {
                if inPersonal {
                    requestRemoveSymbol(symbol)
                } else {
                    togglePersonalWatchlist(symbol: symbol, isCurrentlyIn: false)
                }
            }) {
                HStack(spacing: 6) {
                    if isAddingToPersonal {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(inPersonal ? .yellow : .white.opacity(0.7))
                    } else {
                        Image(systemName: inPersonal ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text("Personal")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(inPersonal ? .yellow : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    inPersonal ?
                    Color.yellow.opacity(0.2) :
                    Color.white.opacity(0.1)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(inPersonal ? Color.yellow.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isAddingToPersonal)
            
            // Guild watchlist button with role-aware states
            Button(action: {
                if inGuild || isRequested {
                    return
                }
                if canDirectlyManageGuildWatchlist {
                    addToGuildWatchlistWithPreflight(symbol: symbol)
                } else {
                    symbolToRequest = symbol
                    showGuildRequestAlert = true
                }
            }) {
                HStack(spacing: 6) {
                    if isRequestingGuild {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint((inGuild || isRequested) ? .blue : .white.opacity(0.7))
                    } else {
                        Image(systemName: guildButtonIcon(inGuild: inGuild, isRequested: isRequested, canManage: canDirectlyManageGuildWatchlist))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(guildButtonTitle(inGuild: inGuild, isRequested: isRequested, canManage: canDirectlyManageGuildWatchlist))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(guildButtonForegroundColor(inGuild: inGuild, isRequested: isRequested))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    guildButtonBackgroundColor(inGuild: inGuild, isRequested: isRequested)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(guildButtonStrokeColor(inGuild: inGuild, isRequested: isRequested), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(inGuild || isRequested || isRequestingGuild)
            
            Spacer()
        }
    }
    
    // MARK: - Watchlist Toggle Actions
    
    private func togglePersonalWatchlist(symbol: RLTradingSymbolDTO, isCurrentlyIn: Bool) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        isAddingToPersonal = true
        
        Task {
            do {
                if isCurrentlyIn {
                    try await rlAppState.removeFromPersonalWatchlist(symbolId: symbol.id)
                    // Refresh watchlist from chartViewModel
                    await chartViewModel.reloadData()
                } else {
                    _ = try await rlAppState.addToPersonalWatchlist(symbolId: symbol.id)
                    // Refresh watchlist from chartViewModel
                    await chartViewModel.reloadData()
                }
            } catch {
                await MainActor.run {
                    rlAppState.showError(error, title: "Failed to update watchlist", style: .toast)
                }
            }
            
            await MainActor.run {
                isAddingToPersonal = false
            }
        }
    }
    
    private func sendGuildWatchlistRequest(symbol: RLTradingSymbolDTO) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        guard symbol.isActive else {
            rlAppState.showError(
                title: "Symbol Inactive",
                message: "This symbol is inactive and cannot be added to the guild watchlist.",
                style: .toast
            )
            return
        }
        
        isRequestingGuild = true
        
        Task {
            do {
                guard let guildId = rlAppState.currentGuild?.id else {
                    throw RLAppError.noGuildSelected
                }
                try await rlAppState.requestGuildWatchlistAddition(
                    guildId: guildId,
                    symbolId: symbol.id
                )
                await reloadGuildRequestState()
            } catch {
                // RLAppState already surfaces request errors.
            }
            
            await MainActor.run {
                isRequestingGuild = false
                symbolToRequest = nil
            }
        }
    }

    private func addToGuildWatchlistWithPreflight(symbol: RLTradingSymbolDTO) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        guard symbol.isActive else {
            rlAppState.showError(
                title: "Symbol Inactive",
                message: "This symbol is inactive and cannot be added to the guild watchlist.",
                style: .toast
            )
            return
        }

        isRequestingGuild = true
        Task {
            do {
                guard let guildId = rlAppState.currentGuild?.id else {
                    throw RLAppError.noGuildSelected
                }

                // Preflight refresh protects against stale local state after admin reviews.
                await chartViewModel.reloadData()
                let alreadyInGuild = chartViewModel.guildWatchlist.contains { $0.id == symbol.id }
                if alreadyInGuild {
                    await reloadGuildRequestState()
                    await MainActor.run {
                        isRequestingGuild = false
                    }
                    return
                }

                _ = try await rlAppState.addToGuildWatchlist(guildId: guildId, symbolId: symbol.id)
                await chartViewModel.reloadData()
                await reloadGuildRequestState()
                NotificationCenter.default.post(name: .guildWatchlistUpdated, object: nil)
            } catch {
                // RLAppState already surfaces add/remove errors.
            }

            await MainActor.run {
                isRequestingGuild = false
            }
        }
    }

    @MainActor
    private func reloadGuildRequestState() async {
        do {
            let response = try await rlAppState.fetchGuildWatchlistRequests(status: "pending")
            pendingGuildRequests = response.requests
        } catch {
            pendingGuildRequests = []
        }
    }

    private func guildButtonTitle(inGuild: Bool, isRequested: Bool, canManage: Bool) -> String {
        if inGuild { return "In Guild" }
        if isRequested { return "Requested" }
        return canManage ? "Add Guild" : "Request"
    }

    private func guildButtonIcon(inGuild: Bool, isRequested: Bool, canManage: Bool) -> String {
        if inGuild { return "person.3.fill" }
        if isRequested { return "clock.fill" }
        return canManage ? "plus.circle.fill" : "person.3.sequence"
    }

    private func guildButtonForegroundColor(inGuild: Bool, isRequested: Bool) -> Color {
        if inGuild { return .blue }
        if isRequested { return .orange }
        return .white.opacity(0.7)
    }

    private func guildButtonBackgroundColor(inGuild: Bool, isRequested: Bool) -> Color {
        if inGuild { return Color.blue.opacity(0.2) }
        if isRequested { return Color.orange.opacity(0.2) }
        return Color.white.opacity(0.1)
    }

    private func guildButtonStrokeColor(inGuild: Bool, isRequested: Bool) -> Color {
        if inGuild { return Color.blue.opacity(0.4) }
        if isRequested { return Color.orange.opacity(0.4) }
        return Color.clear
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text("Loading chart data...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Timeframe Section
    
    private var timeframeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            UnifiedSectionHeader(title: "Timeframe")
            
            VStack(alignment: .leading, spacing: 12) {
                // Minutes Row
                timeframeRow(
                    title: "Minutes",
                    timeframes: [.m1, .m5, .m15, .m30]
                )
                
                // Hours Row
                timeframeRow(
                    title: "Hours",
                    timeframes: [.h1, .h4]
                )
                
                // Daily+ Row
                timeframeRow(
                    title: "Daily & Higher",
                    timeframes: [.d1, .w1, .mn]
                )
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func timeframeRow(title: String, timeframes: [RLChartTimeframe]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .center, spacing: 8) {
                ForEach(timeframes, id: \.self) { timeframe in
                    TimeframeChip(
                        timeframe: timeframe,
                        isSelected: chartViewModel.currentTimeframe == timeframe
                    ) {
                        chartViewModel.setTimeframe(timeframe)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Watchlist Section
    
    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with tabs
            HStack {
                Text("Watchlists")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Tab Pills using UnifiedTabBar (compact style)
                UnifiedTabBar(
                    selectedTab: $selectedWatchlistTab,
                    size: .compact,
                    theme: .blue,
                    countForTab: { tab in
                        switch tab {
                        case .personal: return chartViewModel.personalWatchlist.count
                        case .guild: return chartViewModel.guildWatchlist.count
                        case .global: return chartViewModel.globalSymbols.count
                        case .search: return searchResults.count
                        }
                    },
                    spacing: 6
                )
                .onChange(of: selectedWatchlistTab) { oldValue, newValue in
                    if newValue != .search {
                        searchText = ""
                        isSearching = false
                    }
                }
            }
            
            // Search bar (shown when search tab is active) - with smooth animation
            if selectedWatchlistTab == .search {
                UnifiedSymbolSearchBar(
                    text: $searchText,
                    placeholder: "Search all symbols...",
                    onTextChange: { query in
                        performSearch(query: query)
                    },
                    onClear: {
                        searchResults = []
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Content based on selected tab
            watchlistContent
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedWatchlistTab)
    }
    
    @ViewBuilder
    private var watchlistContent: some View {
        switch selectedWatchlistTab {
        case .personal:
            if chartViewModel.personalWatchlist.isEmpty {
                UnifiedEmptyState(
                    icon: "star",
                    title: "No Personal Symbols",
                    subtitle: "Add symbols from the Search tab"
                )
            } else {
                symbolListView(symbols: chartViewModel.personalWatchlist)
            }
            
        case .guild:
            if chartViewModel.guildWatchlist.isEmpty {
                UnifiedEmptyState(
                    icon: "person.3",
                    title: "No Guild Symbols",
                    subtitle: "Managed by guild admins"
                )
            } else {
                VStack(spacing: 8) {
                    // Admin notice
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Managed by guild admins")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    symbolListView(symbols: chartViewModel.guildWatchlist)
                }
            }

        case .global:
            if chartViewModel.globalSymbols.isEmpty {
                UnifiedEmptyState(
                    icon: "globe",
                    title: "No Global Symbols",
                    subtitle: "No active symbols are available right now"
                )
            } else {
                globalSymbolListView(symbols: chartViewModel.globalSymbols)
            }
            
        case .search:
            if searchText.isEmpty {
                // Show search hint when not searching
                searchHintView
            } else if isSearching {
                UnifiedLoadingState(message: "Searching symbols...")
            } else if searchResults.isEmpty {
                UnifiedNoResultsState(searchText: searchText)
            } else {
                symbolListView(symbols: searchResults)
            }
        }
    }
    
    /// Search hint view - shown when search tab is active but no query entered
    private var searchHintView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("Search for Symbols")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Find symbols to view on chart or add to your personal watchlist")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    /// Grouped symbol list view
    private func symbolListView(symbols: [RLTradingSymbolDTO]) -> some View {
        // Group by asset class (convert string to enum for grouping)
        let grouped = Dictionary(grouping: symbols) { symbol -> RLAssetClass in
            RLAssetClass.fromBackendString(symbol.assetClass) ?? .forex
        }
        let orderedClasses: [RLAssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
        
        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    SymbolAssetGroup(
                        assetClass: assetClass,
                        symbols: classSymbols,
                        currentSymbolId: currentSymbolDTO?.id,
                        onSelectSymbol: { symbol in
                            selectSymbol(symbol)
                        }
                    )
                }
            }
        }
    }

    private func globalSymbolListView(symbols: [RLTradingSymbolDTO]) -> some View {
        let grouped = Dictionary(grouping: symbols) { symbol -> RLAssetClass in
            RLAssetClass.fromBackendString(symbol.assetClass) ?? .forex
        }
        let orderedClasses: [RLAssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]

        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    UnifiedDisclosureGroup(
                        title: assetClass.rawValue,
                        count: classSymbols.count,
                        icon: assetClass.icon,
                        iconColor: assetClassColor(assetClass),
                        isExpandedByDefault: true
                    ) {
                        VStack(spacing: 6) {
                            ForEach(classSymbols) { symbol in
                                GlobalSymbolListRow(
                                    symbol: symbol,
                                    isSelected: currentSymbolDTO?.id == symbol.id
                                ) {
                                    selectSymbol(symbol)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let searchResult = try await rlAppState.realApi.searchSymbols(
                    query: trimmed,
                    limit: 50
                )
                await MainActor.run {
                    searchResults = searchResult.results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    rlAppState.showError(error, title: "Search Failed", style: .toast)
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    private func selectSymbol(_ symbol: RLTradingSymbolDTO) {
        dismissKeyboard()
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        chartViewModel.setSymbol(symbol)
    }
}

// MARK: - Symbol Icon View

struct SymbolIconView: View {
    let symbol: RLTradingSymbolDTO
    var size: CGFloat = 48
    
    var body: some View {
        TradingSymbolIconView(
            symbol: symbol,
            size: size,
            cornerRadiusRatio: 0.25,
            strokeOpacity: 0.2,
            showShadow: true
        )
    }
}

// MARK: - Asset Class Badge

struct AssetClassBadge: View {
    let assetClass: RLAssetClass
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: assetClass.icon)
                .font(.system(size: 9))
            Text(assetClass.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Timeframe Chip

struct TimeframeChip: View {
    let timeframe: RLChartTimeframe
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.shortName)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(minWidth: 44)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue.opacity(0.9) : Color.clear, lineWidth: 1)
                )
            
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Symbol Asset Group (Using UnifiedDisclosureGroup)

struct SymbolAssetGroup: View {
    let assetClass: RLAssetClass
    let symbols: [RLTradingSymbolDTO]
    let currentSymbolId: UUID?
    let onSelectSymbol: (RLTradingSymbolDTO) -> Void
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: assetClass.rawValue,
            count: symbols.count,
            icon: assetClass.icon,
            iconColor: assetClassColor(assetClass),
            isExpandedByDefault: true
        ) {
            VStack(spacing: 6) {
                ForEach(symbols) { symbol in
                    SymbolListRow(
                        symbol: symbol,
                        isSelected: currentSymbolId == symbol.id
                    ) {
                        onSelectSymbol(symbol)
                    }
                }
            }
        }
    }
}

// MARK: - Symbol List Row

struct SymbolListRow: View {
    let symbol: RLTradingSymbolDTO
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                // Symbol Icon
                SymbolIconView(symbol: symbol, size: 44)
                
                // Symbol Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(symbol.ticker)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Market status indicator
                        SymbolMarketStatus(isActive: symbol.isActive)
                    }
                    
                    Text(symbol.displayName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Price and Change
                VStack(alignment: .trailing, spacing: 3) {
                    Text(symbol.priceFormatted ?? "--")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 2) {
                        Image(systemName: (symbol.isUp ?? true) ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(symbol.changeFormatted ?? "--")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(symbol.changeColor)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(12)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [
                        symbol.primaryColorValue.opacity(0.25),
                        symbol.secondaryColorValue.opacity(0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.03)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? symbol.primaryColorValue.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct GlobalSymbolListRow: View {
    let symbol: RLTradingSymbolDTO
    let isSelected: Bool
    let action: () -> Void

    private var statusBadges: [String] {
        var badges: [String] = []
        if symbol.inPersonalWatchlist == true {
            badges.append("Personal")
        }
        if symbol.inGuildWatchlist == true {
            badges.append("Guild")
        }
        if symbol.isRequestedForGuild == true {
            badges.append("Requested")
        }
        return badges
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    SymbolIconView(symbol: symbol, size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(symbol.ticker)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)

                            SymbolMarketStatus(isActive: symbol.isActive)
                        }

                        Text(symbol.displayName)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(symbol.priceFormatted ?? "--")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        HStack(spacing: 2) {
                            Image(systemName: (symbol.isUp ?? true) ? "arrow.up" : "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                            Text(symbol.changeFormatted ?? "--")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(symbol.changeColor)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
                .padding(12)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [
                            symbol.primaryColorValue.opacity(0.25),
                            symbol.secondaryColorValue.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.white.opacity(0.03)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? symbol.primaryColorValue.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        )
                )
                .cornerRadius(12)

                if !statusBadges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(statusBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Market Status Indicator (for Symbol List)

struct SymbolMarketStatus: View {
    let isActive: Bool
    
    var body: some View {
        if isActive {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: .green.opacity(0.5), radius: 2)
        } else {
            Image(systemName: "moon.fill")
                .font(.system(size: 8))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let guildWatchlistUpdated = Notification.Name("guildWatchlistUpdated")
    static let personalWatchlistUpdated = Notification.Name("personalWatchlistUpdated")
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            Text("Symbol Sheet Preview")
                .foregroundColor(.white)
        }
        .padding()
    }
}
