//
//  ChartSheetSymbolView.swift
//  traders_guild
//
//  Symbol and timeframe selector for chart bottom sheet
//  Features: Symbol icons with gradient backgrounds, watchlist tabs, search
//
//  NOTE: RootBottomBarSymbolButton and RootBottomBarIconButton are in separate files
//

import SwiftUI
import UIKit

// MARK: - Main Symbol Sheet View

struct ChartSheetSymbolView: View {
    @ObservedObject var chartViewModel: ChartViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    // Watchlist tab state
    @State private var selectedWatchlistTab: WatchlistTab = .personal
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [TradingSymbolDTO] = []
    
    // Watchlist button loading states
    @State private var isAddingToPersonal: Bool = false
    @State private var isAddingToGuild: Bool = false
    
    // Confirmation dialog state
    @State private var symbolToRemove: TradingSymbolDTO? = nil
    @State private var removeFromPersonal: Bool = true
    @State private var showRemoveConfirmation: Bool = false
    
    enum WatchlistTab: String, CaseIterable {
        case personal = "Personal"
        case guild = "Guild"
        case search = "Search"
        
        var icon: String {
            switch self {
            case .personal: return "person.fill"
            case .guild: return "person.3.fill"
            case .search: return "magnifyingglass"
            }
        }
    }
    
    // Helper to get current symbol as DTO
    // Since currentSymbol is already TradingSymbolDTO, just return it directly
    private var currentSymbolDTO: TradingSymbolDTO? {
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
        .confirmationDialog(
            "Remove from \(removeFromPersonal ? "Personal" : "Guild") Watchlist?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible,
            presenting: symbolToRemove
        ) { symbol in
            Button("Remove \(symbol.ticker)", role: .destructive) {
                confirmRemoveSymbol(symbol, fromPersonal: removeFromPersonal)
            }
            Button("Cancel", role: .cancel) {
                symbolToRemove = nil
            }
        } message: { symbol in
            Text("This will remove \(symbol.displayName) from your \(removeFromPersonal ? "personal" : "guild") watchlist.")
        }
        .onDisappear {
            dismissKeyboard()
        }
    }
    
    private func requestRemoveSymbol(_ symbol: TradingSymbolDTO, fromPersonal: Bool) {
        symbolToRemove = symbol
        removeFromPersonal = fromPersonal
        showRemoveConfirmation = true
    }
    
    private func confirmRemoveSymbol(_ symbol: TradingSymbolDTO, fromPersonal: Bool) {
        if fromPersonal {
            togglePersonalWatchlist(symbol: symbol, isCurrentlyIn: true)
        } else {
            toggleGuildWatchlist(symbol: symbol, isCurrentlyIn: true)
        }
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
                                .font(.system(size: 15, weight: .semibold))
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
                                
                                Text(symbol.assetClass.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        
                        // Price section - fixed width to prevent squishing
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(symbol.formatPrice(chartViewModel.dataManager.currentPrice))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 2) {
                                Image(systemName: symbol.isUp ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(symbol.changeFormatted)
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
    
    private func watchlistButtons(for symbol: TradingSymbolDTO) -> some View {
        // Use leftDrawerViewModel as single source of truth
        let inPersonal = leftDrawerViewModel.personalTradingWatchlist.contains { $0.id == symbol.id }
        let inGuild = leftDrawerViewModel.guildTradingWatchlist.contains { $0.id == symbol.id }
        
        return HStack(spacing: 10) {
            // Personal watchlist button
            Button(action: {
                if inPersonal {
                    requestRemoveSymbol(symbol, fromPersonal: true)
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
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(inPersonal ? Color.yellow.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isAddingToPersonal)
            
            // Guild watchlist button
            Button(action: {
                if inGuild {
                    requestRemoveSymbol(symbol, fromPersonal: false)
                } else {
                    toggleGuildWatchlist(symbol: symbol, isCurrentlyIn: false)
                }
            }) {
                HStack(spacing: 6) {
                    if isAddingToGuild {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(inGuild ? .blue : .white.opacity(0.7))
                    } else {
                        Image(systemName: inGuild ? "person.3.fill" : "person.3")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text("Guild")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(inGuild ? .blue : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    inGuild ?
                    Color.blue.opacity(0.2) :
                    Color.white.opacity(0.1)
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(inGuild ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isAddingToGuild)
            
            Spacer()
        }
    }
    
    // MARK: - Watchlist Toggle Actions
    
    private func togglePersonalWatchlist(symbol: TradingSymbolDTO, isCurrentlyIn: Bool) {
        guard let userId = appState.currentUser?.id else { return }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        isAddingToPersonal = true
        
        Task {
            do {
                if isCurrentlyIn {
                    try await appState.removeFromPersonalWatchlist(userId: userId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
                        leftDrawerViewModel.personalTradingWatchlist.removeAll { $0.id == symbol.id }
                    }
                } else {
                    try await appState.addToPersonalWatchlist(userId: userId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
                        if !leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id }) {
                            leftDrawerViewModel.personalTradingWatchlist.append(symbol)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    appState.showError(error, title: "Failed to update watchlist")
                }
            }
            
            await MainActor.run {
                isAddingToPersonal = false
            }
        }
    }
    
    private func toggleGuildWatchlist(symbol: TradingSymbolDTO, isCurrentlyIn: Bool) {
        guard let guildId = appState.currentGuild?.id else { return }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        isAddingToGuild = true
        
        Task {
            do {
                if isCurrentlyIn {
                    try await appState.removeFromGuildWatchlist(guildId: guildId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
                        leftDrawerViewModel.guildTradingWatchlist.removeAll { $0.id == symbol.id }
                    }
                } else {
                    try await appState.addToGuildWatchlist(guildId: guildId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
                        if !leftDrawerViewModel.guildTradingWatchlist.contains(where: { $0.id == symbol.id }) {
                            leftDrawerViewModel.guildTradingWatchlist.append(symbol)
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    appState.showError(error, title: "Failed to update watchlist")
                }
            }
            
            await MainActor.run {
                isAddingToGuild = false
            }
        }
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
            Text("Timeframe")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
    
    private func timeframeRow(title: String, timeframes: [ChartTimeframe]) -> some View {
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
                Text("Symbols")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Tab Pills
                HStack(spacing: 4) {
                    ForEach(WatchlistTab.allCases, id: \.self) { tab in
                        WatchlistTabButton(
                            tab: tab,
                            isSelected: selectedWatchlistTab == tab
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedWatchlistTab = tab
                                if tab != .search {
                                    searchText = ""
                                    isSearching = false
                                }
                            }
                        }
                    }
                }
            }
            
            // Search bar (shown when search tab is active)
            if selectedWatchlistTab == .search {
                searchBar
            }
            
            // Content based on selected tab
            watchlistContent
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search all symbols...", text: $searchText)
                .foregroundColor(.white)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .onChange(of: searchText) { newValue in
                    performSearch(query: newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var watchlistContent: some View {
        // Use leftDrawerViewModel as single source of truth
        let symbols: [TradingSymbolDTO] = {
            switch selectedWatchlistTab {
            case .personal:
                return leftDrawerViewModel.personalTradingWatchlist
            case .guild:
                return leftDrawerViewModel.guildTradingWatchlist
            case .search:
                return searchText.isEmpty ? SampleData.allTradingSymbolDTOs : searchResults
            }
        }()
        
        if symbols.isEmpty {
            emptyWatchlistView
        } else {
            // Group by asset class
            let grouped = Dictionary(grouping: symbols) { $0.assetClass }
            let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
            
            VStack(spacing: 10) {
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
    }
    
    // Helper to select symbol (bridges DTO to TradingSymbol)
    private func selectSymbol(_ dto: TradingSymbolDTO) {
        // Dismiss keyboard first
        dismissKeyboard()
        
        // Since ChartViewModel.currentSymbol is TradingSymbolDTO, set it directly
        chartViewModel.setSymbol(dto)
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var emptyWatchlistView: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedWatchlistTab == .search ? "magnifyingglass" : "star")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.5))
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    private var emptyMessage: String {
        switch selectedWatchlistTab {
        case .personal:
            return "No symbols in your personal watchlist.\nSearch to add symbols."
        case .guild:
            return "No symbols in the guild watchlist."
        case .search:
            return searchText.isEmpty ? "Search for symbols to add" : "No symbols found for '\(searchText)'"
        }
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).uppercased()
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        
        searchResults = SampleData.allTradingSymbolDTOs.filter { symbol in
            symbol.ticker.uppercased().contains(trimmed) ||
            symbol.displayName.uppercased().contains(trimmed)
        }
    }
}

// MARK: - Symbol Icon View

struct SymbolIconView: View {
    let symbol: TradingSymbolDTO
    var size: CGFloat = 44
    
    var body: some View {
        Group {
            if let iconName = symbol.iconName {
                // Has custom icon - fill entire container
                Image(iconName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
            } else {
                // No icon - show gradient with letter
                ZStack {
                    LinearGradient(
                        colors: [
                            symbol.primaryColorValue,
                            symbol.secondaryColorValue.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Text(symbol.fallbackInitial)
                        .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.25)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: symbol.primaryColorValue.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Asset Class Badge

struct AssetClassBadge: View {
    let assetClass: AssetClass
    
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
        .cornerRadius(6)
    }
}

// MARK: - Timeframe Chip

struct TimeframeChip: View {
    let timeframe: ChartTimeframe
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
                        colors: [Color.blue, Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Watchlist Tab Button

struct WatchlistTabButton: View {
    let tab: ChartSheetSymbolView.WatchlistTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10))
                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                Color.blue.opacity(0.8) :
                Color.white.opacity(0.1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Symbol Asset Group (Collapsible)

struct SymbolAssetGroup: View {
    let assetClass: AssetClass
    let symbols: [TradingSymbolDTO]
    let currentSymbolId: UUID?
    let onSelectSymbol: (TradingSymbolDTO) -> Void
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 6) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: assetClass.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(assetClassColor)
                        .frame(width: 18)
                    
                    Text(assetClass.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("(\(symbols.count))")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Symbols
            if isExpanded {
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
    
    private var assetClassColor: Color {
        switch assetClass {
        case .forex: return .blue
        case .crypto: return .orange
        case .stocks: return .green
        case .commodities: return .yellow
        case .indices: return .purple
        case .futures: return .cyan
        }
    }
}

// MARK: - Symbol List Row

struct SymbolListRow: View {
    let symbol: TradingSymbolDTO
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                    Text(symbol.priceFormatted)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 2) {
                        Image(systemName: symbol.isUp ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(symbol.changeFormatted)
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
