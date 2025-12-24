//
//  WatchlistView.swift
//  traders_guild
//
//  Guild & Personal Watchlist View for Left Drawer
//  UPDATED: Uses UnifiedComponents for consistent styling
//  UPDATED: 3 tabs (Personal/Guild/Search) matching ChartSheetSymbolView style
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
    
    // Confirmation dialog
    @State private var symbolToRemove: TradingSymbolDTO? = nil
    @State private var showRemoveConfirmation: Bool = false
    @State private var removeFromPersonal: Bool = true
    
    // Selection feedback
    @State private var justSelectedSymbolId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector using UnifiedTabBar with compact style
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
            
            // Content based on selected tab
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
            Text("This will remove \(symbol.ticker) from your \(removeFromPersonal ? "personal" : "guild") watchlist.")
        }
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
                watchlistSymbolsList(
                    symbols: leftDrawerViewModel.personalTradingWatchlist,
                    isPersonal: true
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
                    subtitle: "Use the Search tab to add symbols"
                )
                .padding(.top, 40)
            } else {
                watchlistSymbolsList(
                    symbols: leftDrawerViewModel.guildTradingWatchlist,
                    isPersonal: false
                )
            }
        }
    }
    
    // MARK: - Watchlist Symbols List (grouped by asset class)
    
    private func watchlistSymbolsList(symbols: [TradingSymbolDTO], isPersonal: Bool) -> some View {
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
                                WatchlistSymbolRow(
                                    symbol: symbol,
                                    isCurrentSymbol: symbol.id == currentSymbolId,
                                    isJustSelected: symbol.id == justSelectedSymbolId,
                                    isRemoving: symbol.id == isRemovingSymbol,
                                    onTap: { selectSymbol(symbol) },
                                    onRemove: { requestRemoveSymbol(symbol, fromPersonal: isPersonal) }
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
                    Text("Find symbols to add to your watchlist")
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
                                    inGuild: isInGuildWatchlist(symbol),
                                    onTap: { selectSymbol(symbol) },
                                    onAddToPersonal: { addToPersonalWatchlist(symbol) },
                                    onAddToGuild: { addToGuildWatchlist(symbol) }
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
    
    private func isInGuildWatchlist(_ symbol: TradingSymbolDTO) -> Bool {
        leftDrawerViewModel.guildTradingWatchlist.contains(where: { $0.id == symbol.id })
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
    
    private func requestRemoveSymbol(_ symbol: TradingSymbolDTO, fromPersonal: Bool) {
        symbolToRemove = symbol
        removeFromPersonal = fromPersonal
        showRemoveConfirmation = true
    }
    
    private func confirmRemoveSymbol(_ symbol: TradingSymbolDTO, fromPersonal: Bool) {
        isRemovingSymbol = symbol.id
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                if fromPersonal {
                    guard let userId = appState.currentUser?.id else { return }
                    try await appState.removeFromPersonalWatchlist(userId: userId, symbolId: symbol.id)
                    await MainActor.run {
                        leftDrawerViewModel.personalTradingWatchlist.removeAll { $0.id == symbol.id }
                    }
                } else {
                    guard let guildId = appState.currentGuild?.id else { return }
                    try await appState.removeFromGuildWatchlist(guildId: guildId, symbolId: symbol.id)
                    await MainActor.run {
                        leftDrawerViewModel.guildTradingWatchlist.removeAll { $0.id == symbol.id }
                    }
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
    
    private func addToGuildWatchlist(_ symbol: TradingSymbolDTO) {
        guard let guildId = appState.currentGuild?.id else { return }
        
        isAddingSymbol = symbol.id
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                try await appState.addToGuildWatchlist(guildId: guildId, symbolId: symbol.id)
                await MainActor.run {
                    if !leftDrawerViewModel.guildTradingWatchlist.contains(where: { $0.id == symbol.id }) {
                        leftDrawerViewModel.guildTradingWatchlist.append(symbol)
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

// MARK: - Watchlist Symbol Row (for Personal/Guild tabs)

struct WatchlistSymbolRow: View {
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

// MARK: - Search Result Symbol Row

struct SearchResultSymbolRow: View {
    let symbol: TradingSymbolDTO
    let isAddingSymbol: Bool
    let inPersonal: Bool
    let inGuild: Bool
    let onTap: () -> Void
    let onAddToPersonal: () -> Void
    let onAddToGuild: () -> Void
    
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
                
                // Add buttons
                HStack(spacing: 6) {
                    // Personal button
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
                    
                    // Guild button
                    Button(action: onAddToGuild) {
                        Image(systemName: inGuild ? "person.3.fill" : "person.3")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(inGuild ? .blue : .gray)
                            .frame(width: 32, height: 32)
                            .background(inGuild ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(inGuild || isAddingSymbol)
                }
                
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



////
////  WatchlistView.swift
////  traders_guild
////
////  Guild & Personal Watchlist View for Left Drawer
////  Features: Personal/Guild tabs, symbol icons, market status, search,
////            long-press to remove, chart linking, visual selection feedback
////
//
//import SwiftUI
//import UIKit
//
//// MARK: - Watchlist View
//
//struct WatchlistView: View {
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    @EnvironmentObject var appState: AppState
//    
//    // Current symbol on chart (passed from parent or nil)
//    var currentSymbolId: UUID? = nil
//    
//    // Tab state
//    @State private var selectedTab: WatchlistTab = .guild
//    
//    // Search state
//    @State private var searchText: String = ""
//    @State private var searchResults: [TradingSymbolDTO] = []
//    @State private var isSearchFocused: Bool = false
//    
//    // Loading states
//    @State private var isAddingSymbol: UUID? = nil
//    @State private var isRemovingSymbol: UUID? = nil
//    
//    // Confirmation dialog
//    @State private var symbolToRemove: TradingSymbolDTO? = nil
//    @State private var showRemoveConfirmation: Bool = false
//    
//    // Selection feedback
//    @State private var justSelectedSymbolId: UUID? = nil
//    
//    enum WatchlistTab: String, CaseIterable {
//        case personal = "Personal"
//        case guild = "Guild"
//        
//        var icon: String {
//            switch self {
//            case .personal: return "star.fill"
//            case .guild: return "person.3.fill"
//            }
//        }
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Tab selector
//            tabSelector
//                .padding(.horizontal, 12)
//                .padding(.top, 8)
//                .padding(.bottom, 8)
//            
//            // Search bar
//            searchBar
//                .padding(.horizontal, 12)
//                .padding(.bottom, 12)
//            
//            // Content (no ScrollView - parent SectionDrawerView provides it)
//            VStack(spacing: 12) {
//                if !searchText.isEmpty {
//                    // Search results
//                    searchResultsSection
//                } else {
//                    // Watchlist content based on selected tab
//                    watchlistSection
//                }
//            }
//            .padding(.horizontal, 12)
//            .padding(.bottom, 20)
//        }
//        .confirmationDialog(
//            "Remove from \(selectedTab.rawValue) Watchlist?",
//            isPresented: $showRemoveConfirmation,
//            titleVisibility: .visible,
//            presenting: symbolToRemove
//        ) { symbol in
//            Button("Remove \(symbol.ticker)", role: .destructive) {
//                confirmRemoveSymbol(symbol)
//            }
//            Button("Cancel", role: .cancel) {
//                symbolToRemove = nil
//            }
//        } message: { symbol in
//            Text("This will remove \(symbol.displayName) from your \(selectedTab.rawValue.lowercased()) watchlist.")
//        }
//        .onDisappear {
//            // Ensure keyboard is dismissed when view disappears
//            dismissKeyboard()
//        }
//        .onChange(of: selectedTab) { oldValue, newValue in
//            // Dismiss keyboard when changing tabs
//            dismissKeyboard()
//        }
//    }
//    
//    // MARK: - Tab Selector
//    
//    private var tabSelector: some View {
//        HStack(spacing: 8) {
//            ForEach(WatchlistTab.allCases, id: \.self) { tab in
//                Button(action: {
//                    withAnimation(.easeInOut(duration: 0.2)) {
//                        selectedTab = tab
//                        searchText = ""
//                        searchResults = []
//                    }
//                    dismissKeyboard()
//                }) {
//                    HStack(spacing: 6) {
//                        Image(systemName: tab.icon)
//                            .font(.system(size: 12, weight: .semibold))
//                        
//                        Text(tab.rawValue)
//                            .font(.system(size: 13, weight: .medium))
//                        
//                        // Count badge
//                        Text("(\(countForTab(tab)))")
//                            .font(.system(size: 11))
//                            .foregroundColor(selectedTab == tab ? .white.opacity(0.7) : .gray)
//                    }
//                    .foregroundColor(selectedTab == tab ? .white : .gray)
//                    .padding(.horizontal, 14)
//                    .padding(.vertical, 10)
//                    .background(
//                        selectedTab == tab ?
//                        LinearGradient(
//                            colors: tab == .personal ? [.yellow.opacity(0.4), .orange.opacity(0.3)] : [.blue.opacity(0.4), .purple.opacity(0.3)],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        ) :
//                        LinearGradient(
//                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
//                    .cornerRadius(10)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 10)
//                            .stroke(selectedTab == tab ? (tab == .personal ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.3)) : Color.clear, lineWidth: 1)
//                    )
//                }
//                .buttonStyle(.plain)
//            }
//            
//            Spacer()
//        }
//    }
//    
//    private func countForTab(_ tab: WatchlistTab) -> Int {
//        switch tab {
//        case .personal:
//            return leftDrawerViewModel.personalTradingWatchlist.count
//        case .guild:
//            return leftDrawerViewModel.guildTradingWatchlist.count
//        }
//    }
//    
//    // MARK: - Search Bar
//    
//    private var searchBar: some View {
//        HStack(spacing: 10) {
//            Image(systemName: "magnifyingglass")
//                .foregroundColor(.gray)
//                .font(.system(size: 15))
//            
//            TextField("Search symbols to add...", text: $searchText)
//                .foregroundColor(.white)
//                .font(.system(size: 15))
//                .autocapitalization(.allCharacters)
//                .disableAutocorrection(true)
//                .onChange(of: searchText) { newValue in
//                    performSearch(query: newValue)
//                }
//            
//            if !searchText.isEmpty {
//                Button(action: {
//                    searchText = ""
//                    searchResults = []
//                    dismissKeyboard()
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .foregroundColor(.gray)
//                        .font(.system(size: 16))
//                }
//            }
//        }
//        .padding(.horizontal, 14)
//        .padding(.vertical, 12)
//        .background(Color.white.opacity(0.08))
//        .clipShape(Capsule())
//    }
//    
//    // MARK: - Search Results Section
//    
//    private var searchResultsSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text("Search Results")
//                    .font(.subheadline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.white)
//                
//                Spacer()
//                
//                if !searchResults.isEmpty {
//                    Text("\(searchResults.count) found")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                }
//            }
//            
//            if searchResults.isEmpty && !searchText.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: "magnifyingglass")
//                        .font(.largeTitle)
//                        .foregroundColor(.gray.opacity(0.4))
//                    Text("No symbols found for '\(searchText)'")
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 40)
//            } else {
//                // Group search results by asset class too
//                let grouped = Dictionary(grouping: searchResults) { $0.assetClass }
//                let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
//                
//                VStack(spacing: 10) {
//                    ForEach(orderedClasses, id: \.self) { assetClass in
//                        if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
//                            SearchResultAssetGroup(
//                                assetClass: assetClass,
//                                symbols: classSymbols,
//                                currentSymbolId: currentSymbolId,
//                                isAddingSymbol: isAddingSymbol,
//                                isSymbolInWatchlist: { isSymbolInCurrentWatchlist($0) },
//                                onToggleWatchlist: { toggleWatchlist($0) },
//                                onSelectSymbol: { selectSymbolForChart($0) }
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Watchlist Section
//    
//    private var watchlistSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            // Get symbols based on selected tab
//            let symbols = selectedTab == .personal ?
//                leftDrawerViewModel.personalTradingWatchlist :
//                leftDrawerViewModel.guildTradingWatchlist
//            
//            // Loading state
//            if leftDrawerViewModel.isLoading && symbols.isEmpty {
//                VStack(spacing: 16) {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                        .tint(.white)
//                    Text("Loading \(selectedTab.rawValue) Watchlist...")
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.top, 40)
//            }
//            // Empty state
//            else if symbols.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: selectedTab == .personal ? "star" : "person.3")
//                        .font(.system(size: 40))
//                        .foregroundColor(.gray.opacity(0.4))
//                    Text("No Symbols in \(selectedTab.rawValue) Watchlist")
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//                        .foregroundColor(.white.opacity(0.7))
//                    Text("Search above to add symbols")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 40)
//            }
//            // Watchlist content
//            else {
//                // Group by asset class
//                let grouped = Dictionary(grouping: symbols) { $0.assetClass }
//                let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
//                
//                ForEach(orderedClasses, id: \.self) { assetClass in
//                    if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
//                        WatchlistAssetGroup(
//                            assetClass: assetClass,
//                            symbols: classSymbols,
//                            currentSymbolId: currentSymbolId,
//                            justSelectedSymbolId: justSelectedSymbolId,
//                            isRemovingSymbol: isRemovingSymbol,
//                            onRemoveSymbol: { symbol in
//                                requestRemoveSymbol(symbol)
//                            },
//                            onSelectSymbol: { symbol in
//                                selectSymbolForChart(symbol)
//                            }
//                        )
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func dismissKeyboard() {
//        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//    }
//    
//    private func performSearch(query: String) {
//        let trimmed = query.trimmingCharacters(in: .whitespaces).uppercased()
//        guard !trimmed.isEmpty else {
//            searchResults = []
//            return
//        }
//        
//        searchResults = SampleData.allTradingSymbolDTOs.filter { symbol in
//            symbol.ticker.uppercased().contains(trimmed) ||
//            symbol.displayName.uppercased().contains(trimmed)
//        }
//    }
//    
//    private func isSymbolInCurrentWatchlist(_ symbol: TradingSymbolDTO) -> Bool {
//        switch selectedTab {
//        case .personal:
//            return leftDrawerViewModel.personalTradingWatchlist.contains { $0.id == symbol.id }
//        case .guild:
//            return leftDrawerViewModel.guildTradingWatchlist.contains { $0.id == symbol.id }
//        }
//    }
//    
//    private func toggleWatchlist(_ symbol: TradingSymbolDTO) {
//        let impact = UIImpactFeedbackGenerator(style: .light)
//        impact.impactOccurred()
//        
//        if isSymbolInCurrentWatchlist(symbol) {
//            requestRemoveSymbol(symbol)
//        } else {
//            addToWatchlist(symbol)
//        }
//    }
//    
//    private func requestRemoveSymbol(_ symbol: TradingSymbolDTO) {
//        symbolToRemove = symbol
//        showRemoveConfirmation = true
//    }
//    
//    private func confirmRemoveSymbol(_ symbol: TradingSymbolDTO) {
//        removeFromWatchlist(symbol)
//        symbolToRemove = nil
//    }
//    
//    private func addToWatchlist(_ symbol: TradingSymbolDTO) {
//        isAddingSymbol = symbol.id
//        
//        Task {
//            do {
//                switch selectedTab {
//                case .personal:
//                    guard let userId = appState.currentUser?.id else { return }
//                    try await appState.addToPersonalWatchlist(userId: userId, symbolId: symbol.id)
//                    await MainActor.run {
//                        // Update single source of truth
//                        if !leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id }) {
//                            leftDrawerViewModel.personalTradingWatchlist.append(symbol)
//                        }
//                    }
//                    
//                case .guild:
//                    guard let guildId = appState.currentGuild?.id else { return }
//                    try await appState.addToGuildWatchlist(guildId: guildId, symbolId: symbol.id)
//                    await MainActor.run {
//                        // Update single source of truth
//                        if !leftDrawerViewModel.guildTradingWatchlist.contains(where: { $0.id == symbol.id }) {
//                            leftDrawerViewModel.guildTradingWatchlist.append(symbol)
//                        }
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    appState.showError(error, title: "Failed to add symbol")
//                }
//            }
//            
//            await MainActor.run {
//                isAddingSymbol = nil
//            }
//        }
//    }
//    
//    private func removeFromWatchlist(_ symbol: TradingSymbolDTO) {
//        isRemovingSymbol = symbol.id
//        
//        Task {
//            do {
//                switch selectedTab {
//                case .personal:
//                    guard let userId = appState.currentUser?.id else { return }
//                    try await appState.removeFromPersonalWatchlist(userId: userId, symbolId: symbol.id)
//                    await MainActor.run {
//                        // Update single source of truth
//                        leftDrawerViewModel.personalTradingWatchlist.removeAll { $0.id == symbol.id }
//                    }
//                    
//                case .guild:
//                    guard let guildId = appState.currentGuild?.id else { return }
//                    try await appState.removeFromGuildWatchlist(guildId: guildId, symbolId: symbol.id)
//                    await MainActor.run {
//                        // Update single source of truth
//                        leftDrawerViewModel.guildTradingWatchlist.removeAll { $0.id == symbol.id }
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    appState.showError(error, title: "Failed to remove symbol")
//                }
//            }
//            
//            await MainActor.run {
//                isRemovingSymbol = nil
//            }
//        }
//    }
//    
//    private func selectSymbolForChart(_ symbol: TradingSymbolDTO) {
//        dismissKeyboard()
//        
//        let impact = UIImpactFeedbackGenerator(style: .medium)
//        impact.impactOccurred()
//        
//        // Visual feedback - flash the selected row
//        justSelectedSymbolId = symbol.id
//        
//        // Clear the flash after a short delay
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            justSelectedSymbolId = nil
//        }
//        
//        // Post notification to update chart and close drawer
//        NotificationCenter.default.post(
//            name: .selectChartSymbol,
//            object: nil,
//            userInfo: ["symbol": symbol]
//        )
//    }
//}
//
//// MARK: - Notification Name Extension
//
//extension Notification.Name {
//    static let selectChartSymbol = Notification.Name("selectChartSymbol")
//}
//
//// MARK: - Asset Group View
//
//struct WatchlistAssetGroup: View {
//    let assetClass: AssetClass
//    let symbols: [TradingSymbolDTO]
//    let currentSymbolId: UUID?
//    let justSelectedSymbolId: UUID?
//    let isRemovingSymbol: UUID?
//    let onRemoveSymbol: (TradingSymbolDTO) -> Void
//    let onSelectSymbol: (TradingSymbolDTO) -> Void
//    
//    @State private var isExpanded: Bool = true
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            // Header
//            Button(action: {
//                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                    isExpanded.toggle()
//                }
//            }) {
//                HStack(spacing: 10) {
//                    Image(systemName: assetClass.icon)
//                        .font(.system(size: 14))
//                        .foregroundColor(assetClassColor)
//                        .frame(width: 20)
//                    
//                    Text(assetClass.rawValue)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                    
//                    Text("(\(symbols.count))")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                    
//                    Spacer()
//                    
//                    Image(systemName: "chevron.right")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.gray)
//                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 10)
//                .background(Color.white.opacity(0.06))
//                .clipShape(Capsule())
//            }
//            .buttonStyle(.plain)
//            
//            // Symbols
//            if isExpanded {
//                VStack(spacing: 6) {
//                    ForEach(symbols) { symbol in
//                        WatchlistSymbolRow(
//                            symbol: symbol,
//                            isSelected: currentSymbolId == symbol.id,
//                            isJustSelected: justSelectedSymbolId == symbol.id,
//                            isLoading: isRemovingSymbol == symbol.id,
//                            onSelectSymbol: {
//                                onSelectSymbol(symbol)
//                            },
//                            onRemoveSymbol: {
//                                onRemoveSymbol(symbol)
//                            }
//                        )
//                    }
//                }
//            }
//        }
//    }
//    
//    private var assetClassColor: Color {
//        switch assetClass {
//        case .forex: return .blue
//        case .crypto: return .orange
//        case .stocks: return .green
//        case .commodities: return .yellow
//        case .indices: return .purple
//        case .futures: return .cyan
//        }
//    }
//}
//
//// MARK: - Symbol Row View
//
//struct WatchlistSymbolRow: View {
//    let symbol: TradingSymbolDTO
//    let isSelected: Bool
//    var isJustSelected: Bool = false
//    var isLoading: Bool = false
//    let onSelectSymbol: () -> Void
//    let onRemoveSymbol: () -> Void
//    
//    @State private var showFlash = false
//    
//    var body: some View {
//        Button(action: {
//            let impact = UIImpactFeedbackGenerator(style: .medium)
//            impact.impactOccurred()
//            onSelectSymbol()
//        }) {
//            HStack(spacing: 12) {
//                // Symbol Icon
//                WatchlistSymbolIcon(symbol: symbol, size: 42)
//                
//                // Symbol Info
//                VStack(alignment: .leading, spacing: 3) {
//                    HStack(spacing: 6) {
//                        Text(symbol.ticker)
//                            .font(.system(size: 14, weight: .semibold))
//                            .foregroundColor(.white)
//                        
//                        // Market status indicator
//                        MarketStatusIndicator(isActive: symbol.isActive)
//                    }
//                    
//                    Text(symbol.displayName)
//                        .font(.system(size: 11))
//                        .foregroundColor(.gray)
//                        .lineLimit(1)
//                }
//                
//                Spacer()
//                
//                // Price Info
//                VStack(alignment: .trailing, spacing: 3) {
//                    Text(symbol.priceFormatted)
//                        .font(.system(size: 13, weight: .medium, design: .monospaced))
//                        .foregroundColor(.white)
//                    
//                    HStack(spacing: 2) {
//                        Image(systemName: symbol.isUp ? "arrow.up" : "arrow.down")
//                            .font(.system(size: 8, weight: .bold))
//                        Text(symbol.changeFormatted)
//                            .font(.system(size: 11, weight: .medium))
//                    }
//                    .foregroundColor(symbol.changeColor)
//                }
//                
//                // Selection indicator or loading
//                if isLoading {
//                    ProgressView()
//                        .scaleEffect(0.7)
//                        .tint(.white)
//                        .frame(width: 24, height: 24)
//                } else if isSelected {
//                    Image(systemName: "checkmark.circle.fill")
//                        .foregroundColor(.blue)
//                        .font(.system(size: 20))
//                }
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 10)
//            .background(
//                Group {
//                    if isSelected {
//                        LinearGradient(
//                            colors: [
//                                symbol.primaryColorValue.opacity(0.3),
//                                symbol.secondaryColorValue.opacity(0.15)
//                            ],
//                            startPoint: .leading,
//                            endPoint: .trailing
//                        )
//                    } else if showFlash {
//                        Color.white.opacity(0.15)
//                    } else {
//                        Color.white.opacity(0.04)
//                    }
//                }
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: 12)
//                    .stroke(isSelected ? symbol.primaryColorValue.opacity(0.4) : Color.clear, lineWidth: 1)
//            )
//            .cornerRadius(12)
//        }
//        .buttonStyle(PressableButtonStyle())
//        .contextMenu {
//            Button(role: .destructive, action: onRemoveSymbol) {
//                Label("Remove from Watchlist", systemImage: "minus.circle")
//            }
//        }
//        .onChange(of: isJustSelected) { oldValue, newValue in
//            if newValue {
//                // Flash effect when selected
//                withAnimation(.easeIn(duration: 0.1)) {
//                    showFlash = true
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                    withAnimation(.easeOut(duration: 0.3)) {
//                        showFlash = false
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Pressable Button Style
//
//struct PressableButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .opacity(configuration.isPressed ? 0.7 : 1.0)
//            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
//            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
//    }
//}
//
//// MARK: - Symbol Icon for Watchlist
//
//struct WatchlistSymbolIcon: View {
//    let symbol: TradingSymbolDTO
//    var size: CGFloat = 42
//    
//    var body: some View {
//        Group {
//            if let iconName = symbol.iconName {
//                // Has custom icon
//                Image(iconName)
//                    .renderingMode(.original)
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: size, height: size)
//                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
//            } else {
//                // Gradient with letter
//                ZStack {
//                    LinearGradient(
//                        colors: [
//                            symbol.primaryColorValue,
//                            symbol.secondaryColorValue.opacity(0.8)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                    
//                    Text(symbol.fallbackInitial)
//                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
//                        .foregroundColor(.white)
//                }
//                .frame(width: size, height: size)
//                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
//            }
//        }
//        .overlay(
//            RoundedRectangle(cornerRadius: size * 0.22)
//                .stroke(Color.white.opacity(0.15), lineWidth: 1)
//        )
//    }
//}
//
//// MARK: - Market Status Indicator
//
//struct MarketStatusIndicator: View {
//    let isActive: Bool
//    
//    var body: some View {
//        if isActive {
//            Circle()
//                .fill(Color.green)
//                .frame(width: 6, height: 6)
//                .shadow(color: .green.opacity(0.5), radius: 2)
//        } else {
//            Image(systemName: "moon.fill")
//                .font(.system(size: 8))
//                .foregroundColor(.gray.opacity(0.7))
//        }
//    }
//}
//
//// MARK: - Search Result Asset Group
//
//struct SearchResultAssetGroup: View {
//    let assetClass: AssetClass
//    let symbols: [TradingSymbolDTO]
//    let currentSymbolId: UUID?
//    let isAddingSymbol: UUID?
//    let isSymbolInWatchlist: (TradingSymbolDTO) -> Bool
//    let onToggleWatchlist: (TradingSymbolDTO) -> Void
//    let onSelectSymbol: (TradingSymbolDTO) -> Void
//    
//    @State private var isExpanded: Bool = true
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            // Header
//            Button(action: {
//                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                    isExpanded.toggle()
//                }
//            }) {
//                HStack(spacing: 10) {
//                    Image(systemName: assetClass.icon)
//                        .font(.system(size: 14))
//                        .foregroundColor(assetClassColor)
//                        .frame(width: 20)
//                    
//                    Text(assetClass.rawValue)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                    
//                    Text("(\(symbols.count))")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                    
//                    Spacer()
//                    
//                    Image(systemName: "chevron.right")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.gray)
//                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 10)
//                .background(Color.white.opacity(0.06))
//                .cornerRadius(10)
//            }
//            .buttonStyle(.plain)
//            
//            // Symbols
//            if isExpanded {
//                VStack(spacing: 6) {
//                    ForEach(symbols) { symbol in
//                        SearchResultRow(
//                            symbol: symbol,
//                            isSelected: currentSymbolId == symbol.id,
//                            isInWatchlist: isSymbolInWatchlist(symbol),
//                            isLoading: isAddingSymbol == symbol.id,
//                            onSelectSymbol: { onSelectSymbol(symbol) },
//                            onToggleWatchlist: { onToggleWatchlist(symbol) }
//                        )
//                    }
//                }
//            }
//        }
//    }
//    
//    private var assetClassColor: Color {
//        switch assetClass {
//        case .forex: return .blue
//        case .crypto: return .orange
//        case .stocks: return .green
//        case .commodities: return .yellow
//        case .indices: return .purple
//        case .futures: return .cyan
//        }
//    }
//}
//
//// MARK: - Search Result Row
//
//struct SearchResultRow: View {
//    let symbol: TradingSymbolDTO
//    let isSelected: Bool
//    let isInWatchlist: Bool
//    var isLoading: Bool = false
//    let onSelectSymbol: () -> Void
//    let onToggleWatchlist: () -> Void
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            // Tap area for chart selection
//            Button(action: {
//                let impact = UIImpactFeedbackGenerator(style: .medium)
//                impact.impactOccurred()
//                onSelectSymbol()
//            }) {
//                HStack(spacing: 12) {
//                    // Symbol Icon
//                    WatchlistSymbolIcon(symbol: symbol, size: 42)
//                    
//                    // Symbol Info
//                    VStack(alignment: .leading, spacing: 3) {
//                        HStack(spacing: 6) {
//                            Text(symbol.ticker)
//                                .font(.system(size: 14, weight: .semibold))
//                                .foregroundColor(.white)
//                            
//                            MarketStatusIndicator(isActive: symbol.isActive)
//                        }
//                        
//                        Text(symbol.displayName)
//                            .font(.system(size: 11))
//                            .foregroundColor(.gray)
//                            .lineLimit(1)
//                    }
//                    
//                    Spacer()
//                    
//                    // Price Info
//                    VStack(alignment: .trailing, spacing: 3) {
//                        Text(symbol.priceFormatted)
//                            .font(.system(size: 13, weight: .medium, design: .monospaced))
//                            .foregroundColor(.white)
//                        
//                        HStack(spacing: 2) {
//                            Image(systemName: symbol.isUp ? "arrow.up" : "arrow.down")
//                                .font(.system(size: 8, weight: .bold))
//                            Text(symbol.changeFormatted)
//                                .font(.system(size: 11, weight: .medium))
//                        }
//                        .foregroundColor(symbol.changeColor)
//                    }
//                }
//            }
//            .buttonStyle(PressableButtonStyle())
//            
//            // Add/Check button
//            Button(action: {
//                let impact = UIImpactFeedbackGenerator(style: .light)
//                impact.impactOccurred()
//                onToggleWatchlist()
//            }) {
//                Group {
//                    if isLoading {
//                        ProgressView()
//                            .scaleEffect(0.7)
//                            .tint(.white)
//                    } else {
//                        Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
//                            .foregroundColor(isInWatchlist ? .green : .blue)
//                    }
//                }
//                .font(.system(size: 22))
//                .frame(width: 32, height: 32)
//            }
//            .buttonStyle(.plain)
//            .disabled(isLoading)
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 10)
//        .background(
//            Group {
//                if isSelected {
//                    LinearGradient(
//                        colors: [
//                            symbol.primaryColorValue.opacity(0.3),
//                            symbol.secondaryColorValue.opacity(0.15)
//                        ],
//                        startPoint: .leading,
//                        endPoint: .trailing
//                    )
//                } else {
//                    Color.white.opacity(0.04)
//                }
//            }
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(isSelected ? symbol.primaryColorValue.opacity(0.4) : Color.clear, lineWidth: 1)
//        )
//        .cornerRadius(12)
//    }
//}
//
//// MARK: - Preview
//
//#Preview {
//    ZStack {
//        Color.black.ignoresSafeArea()
//        WatchlistView()
//    }
//}
