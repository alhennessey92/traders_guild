//
//  WatchlistView.swift
//  traders_guild
//
//  Guild & Personal Watchlist View for Left Drawer
//  UPDATED: Uses UnifiedComponents for consistent styling
//  UPDATED: 3 tabs (Personal/Guild/Search) matching ChartSheetSymbolView style
//  UPDATED: Guild watchlist is now read-only (managed by admins)
//

import SwiftUI
import UIKit

// MARK: - Watchlist Tab Definition

/// Tab enum conforming to UnifiedTabItem for use with UnifiedTabBar
enum WatchlistTab: String, CaseIterable, UnifiedTabItem {
    case personal = "Personal"
    case guild = "Guild"
    case search = "Search"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .personal: return "star.fill"
        case .guild: return "person.3.fill"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - Watchlist View

struct WatchlistView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var appState: AppState
    
    // Current symbol on chart (passed from parent or nil)
    var currentSymbolId: UUID? = nil
    
    // Tab state
    @State private var selectedTab: WatchlistTab = .guild
    
    // Search state (only used in search tab)
    @State private var searchText: String = ""
    @State private var searchResults: [TradingSymbolDTO] = []
    
    // Loading states
    @State private var isAddingSymbol: UUID? = nil
    @State private var isRemovingSymbol: UUID? = nil
    
    // Confirmation dialog (only for personal watchlist now)
    @State private var symbolToRemove: TradingSymbolDTO? = nil
    @State private var showRemoveConfirmation: Bool = false
    
    // Selection feedback
    @State private var justSelectedSymbolId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector using UnifiedTabBar with compact style - OUTSIDE ScrollView
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in
                    return getCountForTab(tab)
                },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .onChange(of: selectedTab) { oldValue, newValue in
                // Clear search when switching away from search tab
                if oldValue == .search {
                    searchText = ""
                    searchResults = []
                }
                dismissKeyboard()
            }
            
            // Scrollable content with pull to refresh
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .personal:
                        personalWatchlistContent
                    case .guild:
                        guildWatchlistContent
                    case .search:
                        searchContent
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshWatchlist()
            }
        }
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
            Text("This will remove \(symbol.ticker) from your personal watchlist.")
        }
    }
    
    // MARK: - Refresh
    
    private func refreshWatchlist() async {
        guard let guild = appState.currentGuild else { return }
        await leftDrawerViewModel.refresh(for: guild.id, appState: appState)
    }
    
    // MARK: - Tab Counts
    
    /// Returns count for tab - UnifiedTabBar expects Int
    private func getCountForTab(_ tab: WatchlistTab) -> Int {
        switch tab {
        case .personal:
            return leftDrawerViewModel.personalTradingWatchlist.count
        case .guild:
            return leftDrawerViewModel.guildTradingWatchlist.count
        case .search:
            return searchResults.count
        }
    }
    
    // MARK: - Personal Watchlist Content
    
    private var personalWatchlistContent: some View {
        Group {
            if leftDrawerViewModel.personalTradingWatchlist.isEmpty {
                UnifiedEmptyState(
                    icon: "star",
                    title: "No Personal Symbols",
                    subtitle: "Use the Search tab to add symbols"
                )
                .padding(.top, 40)
            } else {
                personalWatchlistSymbolsList(
                    symbols: leftDrawerViewModel.personalTradingWatchlist
                )
            }
        }
    }
    
    // MARK: - Guild Watchlist Content
    
    private var guildWatchlistContent: some View {
        Group {
            if leftDrawerViewModel.guildTradingWatchlist.isEmpty {
                UnifiedEmptyState(
                    icon: "person.3",
                    title: "No Guild Symbols",
                    subtitle: "Guild watchlist is managed by admins"
                )
                .padding(.top, 40)
            } else {
                VStack(spacing: 10) {
                    // Admin notice
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Managed by guild admins")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    
                    guildWatchlistSymbolsList(
                        symbols: leftDrawerViewModel.guildTradingWatchlist
                    )
                }
            }
        }
    }
    
    // MARK: - Personal Watchlist Symbols List (grouped by asset class)
    
    private func personalWatchlistSymbolsList(symbols: [TradingSymbolDTO]) -> some View {
        let grouped = Dictionary(grouping: symbols, by: { $0.assetClass })
        let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
        
        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    UnifiedDisclosureGroup(
                        title: assetClass.rawValue,
                        count: classSymbols.count,
                        icon: assetClass.icon,
                        iconColor: colorForAssetClass(assetClass),
                        isExpandedByDefault: true
                    ) {
                        VStack(spacing: 6) {
                            ForEach(classSymbols) { symbol in
                                PersonalWatchlistRow(
                                    symbol: symbol,
                                    isCurrentSymbol: symbol.id == currentSymbolId,
                                    isJustSelected: symbol.id == justSelectedSymbolId,
                                    isRemoving: symbol.id == isRemovingSymbol,
                                    onTap: { selectSymbol(symbol) },
                                    onRemove: { requestRemoveSymbol(symbol) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Guild Watchlist Symbols List (read-only, no remove option)
    
    private func guildWatchlistSymbolsList(symbols: [TradingSymbolDTO]) -> some View {
        let grouped = Dictionary(grouping: symbols, by: { $0.assetClass })
        let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
        
        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    UnifiedDisclosureGroup(
                        title: assetClass.rawValue,
                        count: classSymbols.count,
                        icon: assetClass.icon,
                        iconColor: colorForAssetClass(assetClass),
                        isExpandedByDefault: true
                    ) {
                        VStack(spacing: 6) {
                            ForEach(classSymbols) { symbol in
                                GuildWatchlistRow(
                                    symbol: symbol,
                                    isCurrentSymbol: symbol.id == currentSymbolId,
                                    isJustSelected: symbol.id == justSelectedSymbolId,
                                    onTap: { selectSymbol(symbol) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Search Content
    
    private var searchContent: some View {
        VStack(spacing: 12) {
            // Search bar only in search tab
            UnifiedSymbolSearchBar(
                text: $searchText,
                placeholder: "Search symbols...",
                onTextChange: { query in
                    performSearch(query: query)
                },
                onClear: {
                    searchResults = []
                    dismissKeyboard()
                }
            )
            
            if searchText.isEmpty {
                // Show hint when not searching
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Search for symbols")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Find symbols to add to your personal watchlist")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)
            } else if searchResults.isEmpty {
                UnifiedNoResultsState(searchText: searchText)
                    .padding(.top, 40)
            } else {
                searchResultsList
            }
        }
    }
    
    // MARK: - Search Results List
    
    private var searchResultsList: some View {
        let grouped = Dictionary(grouping: searchResults, by: { $0.assetClass })
        let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
        
        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    UnifiedDisclosureGroup(
                        title: assetClass.rawValue,
                        count: classSymbols.count,
                        icon: assetClass.icon,
                        iconColor: colorForAssetClass(assetClass),
                        isExpandedByDefault: true
                    ) {
                        VStack(spacing: 6) {
                            ForEach(classSymbols) { symbol in
                                SearchResultSymbolRow(
                                    symbol: symbol,
                                    isAddingSymbol: isAddingSymbol == symbol.id,
                                    inPersonal: isInPersonalWatchlist(symbol),
                                    onTap: { selectSymbol(symbol) },
                                    onAddToPersonal: { addToPersonalWatchlist(symbol) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper: Asset Class Color
    
    private func colorForAssetClass(_ assetClass: AssetClass) -> Color {
        switch assetClass {
        case .forex: return .blue
        case .crypto: return .orange
        case .stocks: return .green
        case .commodities: return .yellow
        case .indices: return .purple
        case .futures: return .cyan
        }
    }
    
    // MARK: - Watchlist Checks
    
    private func isInPersonalWatchlist(_ symbol: TradingSymbolDTO) -> Bool {
        leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id })
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let lowercasedQuery = query.lowercased()
        searchResults = SampleData.allTradingSymbolDTOs.filter { symbol in
            symbol.ticker.lowercased().contains(lowercasedQuery) ||
            symbol.displayName.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Actions
    
    private func selectSymbol(_ symbol: TradingSymbolDTO) {
        dismissKeyboard()
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Visual feedback
        justSelectedSymbolId = symbol.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            justSelectedSymbolId = nil
        }
        
        // Post notification to update chart and close drawer
        NotificationCenter.default.post(
            name: .selectChartSymbol,
            object: nil,
            userInfo: ["symbol": symbol]
        )
    }
    
    private func requestRemoveSymbol(_ symbol: TradingSymbolDTO) {
        symbolToRemove = symbol
        showRemoveConfirmation = true
    }
    
    private func confirmRemoveSymbol(_ symbol: TradingSymbolDTO) {
        isRemovingSymbol = symbol.id
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                guard let userId = appState.currentUser?.id else { return }
                try await appState.removeFromPersonalWatchlist(userId: userId, symbolId: symbol.id)
                await MainActor.run {
                    leftDrawerViewModel.personalTradingWatchlist.removeAll { $0.id == symbol.id }
                }
            } catch {
                await MainActor.run {
                    appState.showError(error, title: "Failed to remove symbol")
                }
            }
            
            await MainActor.run {
                isRemovingSymbol = nil
                symbolToRemove = nil
            }
        }
    }
    
    private func addToPersonalWatchlist(_ symbol: TradingSymbolDTO) {
        guard let userId = appState.currentUser?.id else { return }
        
        isAddingSymbol = symbol.id
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                try await appState.addToPersonalWatchlist(userId: userId, symbolId: symbol.id)
                await MainActor.run {
                    if !leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id }) {
                        leftDrawerViewModel.personalTradingWatchlist.append(symbol)
                    }
                }
            } catch {
                await MainActor.run {
                    appState.showError(error, title: "Failed to add to watchlist")
                }
            }
            
            await MainActor.run {
                isAddingSymbol = nil
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let selectChartSymbol = Notification.Name("selectChartSymbol")
}

// MARK: - Personal Watchlist Row (with context menu for remove)

struct PersonalWatchlistRow: View {
    let symbol: TradingSymbolDTO
    let isCurrentSymbol: Bool
    let isJustSelected: Bool
    let isRemoving: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Symbol icon with SVG support
                WatchlistSymbolIcon(symbol: symbol, size: 44)
                
                // Symbol info
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.ticker)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(symbol.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Price info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(symbol.priceFormatted)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 2) {
                        Image(systemName: symbol.isUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(symbol.changeFormatted)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(symbol.changeColor)
                }
                
                // Remove indicator when removing
                if isRemoving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.red)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentSymbol ? Color.blue.opacity(0.2) :
                          isJustSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrentSymbol ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove from Watchlist", systemImage: "trash")
            }
        }
    }
}

// MARK: - Guild Watchlist Row (read-only, no context menu)

struct GuildWatchlistRow: View {
    let symbol: TradingSymbolDTO
    let isCurrentSymbol: Bool
    let isJustSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Symbol icon with SVG support
                WatchlistSymbolIcon(symbol: symbol, size: 44)
                
                // Symbol info
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.ticker)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(symbol.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Price info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(symbol.priceFormatted)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 2) {
                        Image(systemName: symbol.isUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(symbol.changeFormatted)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(symbol.changeColor)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentSymbol ? Color.blue.opacity(0.2) :
                          isJustSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrentSymbol ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        // No context menu - guild watchlist is read-only
    }
}

// MARK: - Search Result Symbol Row (personal watchlist only)

struct SearchResultSymbolRow: View {
    let symbol: TradingSymbolDTO
    let isAddingSymbol: Bool
    let inPersonal: Bool
    let onTap: () -> Void
    let onAddToPersonal: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Symbol icon
                WatchlistSymbolIcon(symbol: symbol, size: 40)
                
                // Symbol info
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.ticker)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(symbol.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Personal watchlist button only
                Button(action: onAddToPersonal) {
                    Image(systemName: inPersonal ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(inPersonal ? .yellow : .gray)
                        .frame(width: 32, height: 32)
                        .background(inPersonal ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(inPersonal || isAddingSymbol)
                
                if isAddingSymbol {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Symbol Icon View (with SVG support)

struct WatchlistSymbolIcon: View {
    let symbol: TradingSymbolDTO
    var size: CGFloat = 44
    
    var body: some View {
        Group {
            if let iconName = symbol.iconName {
                // Has SVG icon - render it to fill the entire icon area
                Image(iconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                // No icon - show gradient background with abbreviation text
                ZStack {
                    LinearGradient(
                        colors: [
                            symbol.primaryColorValue,
                            symbol.secondaryColorValue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Text(symbol.fallbackInitial)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}



