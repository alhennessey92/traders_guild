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

// MARK: - Watchlist View

struct WatchlistView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rlAppState: RLAppState
    
    // Current symbol on chart (passed from parent or nil)
    var currentSymbolId: UUID? = nil
    
    // Tab state
    @State private var selectedTab: WatchlistTab = .guild
    
    // Search state (only used in search tab)
    @State private var searchText: String = ""
    @State private var searchResults: [RLTradingSymbolDTO] = []
    @State private var isSearching: Bool = false
    
    // Loading states
    @State private var isAddingSymbol: UUID? = nil
    @State private var isRemovingSymbol: UUID? = nil
    
    // Confirmation dialog (only for personal watchlist now)
    @State private var symbolToRemove: RLTradingSymbolDTO? = nil
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
                    case .global:
                        globalWatchlistContent
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
        .onReceive(NotificationCenter.default.publisher(for: .guildWatchlistUpdated)) { _ in
            Task {
                await refreshWatchlist()
            }
        }
        .task {
            // Load global symbols on first appearance if not already loaded
            if leftDrawerViewModel.globalTradingSymbols.isEmpty,
               let guildId = rlAppState.currentGuild?.id {
                do {
                    let globalResponse = try await rlAppState.realApi.getGlobalSymbols(guildId: guildId, limit: 100)
                    leftDrawerViewModel.globalTradingSymbols = globalResponse.symbols
                } catch {
                    // Errors are surfaced through RLAppState toasts.
                }
            }
        }
    }
    
    // MARK: - Refresh
    
    private func refreshWatchlist() async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        do {
            async let guildTask = rlAppState.fetchGuildWatchlist(guildId: guildId)
            async let personalTask = rlAppState.fetchPersonalWatchlist()
            async let globalTask = rlAppState.realApi.getGlobalSymbols(guildId: guildId, limit: 100)
            let (guildResponse, personalResponse, globalResponse) = try await (guildTask, personalTask, globalTask)
            await MainActor.run {
                leftDrawerViewModel.guildTradingWatchlist = guildResponse.symbols.map { $0.symbol }
                leftDrawerViewModel.personalTradingWatchlist = personalResponse.symbols.map { $0.symbol }
                leftDrawerViewModel.globalTradingSymbols = globalResponse.symbols
            }
        } catch {
            // Errors are surfaced through RLAppState toasts.
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
        case .global:
            return leftDrawerViewModel.globalTradingSymbols.count
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

    // MARK: - Global Watchlist Content

    private var globalWatchlistContent: some View {
        Group {
            if leftDrawerViewModel.globalTradingSymbols.isEmpty {
                UnifiedEmptyState(
                    icon: "globe",
                    title: "No Global Symbols",
                    subtitle: "No active symbols are available right now"
                )
                .padding(.top, 40)
            } else {
                globalSymbolsList(
                    symbols: leftDrawerViewModel.globalTradingSymbols
                )
            }
        }
    }

    // MARK: - Global Symbols List (grouped by asset class)

    private func globalSymbolsList(symbols: [RLTradingSymbolDTO]) -> some View {
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


    // MARK: - Personal Watchlist Symbols List (grouped by asset class)
    
    private func personalWatchlistSymbolsList(symbols: [RLTradingSymbolDTO]) -> some View {
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
    
    private func guildWatchlistSymbolsList(symbols: [RLTradingSymbolDTO]) -> some View {
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
                        .foregroundColor(AppColors.surfaceGray50)
                    Text("Search for symbols")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Find symbols to add to your personal watchlist")
                        .font(.caption)
                        .foregroundColor(AppColors.surfaceGray70)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)
            } else if isSearching {
                UnifiedLoadingState(message: "Searching symbols...")
                    .padding(.top, 40)
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
        let grouped = Dictionary(grouping: searchResults) { symbol -> RLAssetClass in
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
    
    private func colorForAssetClass(_ assetClass: RLAssetClass) -> Color {
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
    
    private func isInPersonalWatchlist(_ symbol: RLTradingSymbolDTO) -> Bool {
        leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id })
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Debounce search to avoid too many API calls
        Task {
            isSearching = true
            do {
                // Use RealAPIService to search symbols
                let results = try await rlAppState.realApi.searchSymbols(query: query, limit: 50)
                await MainActor.run {
                    searchResults = results.results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                    print("Failed to search symbols: \(error)")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectSymbol(_ symbol: RLTradingSymbolDTO) {
        guard symbol.isSelectableForActiveProvider else {
            showUnsupportedSymbolToast(symbol)
            return
        }
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

    private func showUnsupportedSymbolToast(_ symbol: RLTradingSymbolDTO) {
        let providerText = symbol.activeProviderDisplayName ?? "active provider"
        rlAppState.showError(
            title: "Symbol Unavailable",
            message: "\(symbol.ticker) is not supported by \(providerText).",
            style: .toast
        )
    }
    
    private func requestRemoveSymbol(_ symbol: RLTradingSymbolDTO) {
        symbolToRemove = symbol
        showRemoveConfirmation = true
    }
    
    private func confirmRemoveSymbol(_ symbol: RLTradingSymbolDTO) {
        isRemovingSymbol = symbol.id
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                try await rlAppState.removeFromPersonalWatchlist(symbolId: symbol.id)
                await MainActor.run {
                    leftDrawerViewModel.personalTradingWatchlist.removeAll { $0.id == symbol.id }
                }
            } catch {
                await MainActor.run {
                    rlAppState.showError(error, title: "Failed to remove symbol", style: .toast)
                }
            }
            
            await MainActor.run {
                isRemovingSymbol = nil
                symbolToRemove = nil
            }
        }
    }
    
    private func addToPersonalWatchlist(_ symbol: RLTradingSymbolDTO) {
        guard symbol.isSelectableForActiveProvider else {
            showUnsupportedSymbolToast(symbol)
            return
        }
        isAddingSymbol = symbol.id
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                try await rlAppState.addToPersonalWatchlist(symbolId: symbol.id)
                await MainActor.run {
                    if !leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id }) {
                        leftDrawerViewModel.personalTradingWatchlist.append(symbol)
                    }
                }
            } catch {
                await MainActor.run {
                    rlAppState.showError(error, title: "Failed to add to watchlist", style: .toast)
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
    let symbol: RLTradingSymbolDTO
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

                    FlowLayout(spacing: 6) {
                        if let provider = symbol.activeProviderDisplayName {
                            SymbolProviderBadge(provider: provider)
                        }
                        if !symbol.isSelectableForActiveProvider {
                            UnsupportedSymbolBadge()
                        }
                    }
                }

                Spacer()

                // Price info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(symbol.priceFormatted ?? "--")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    HStack(spacing: 2) {
                        Image(systemName: (symbol.isUp ?? false) ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(symbol.changeFormatted ?? "--")
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
                    .fill(isCurrentSymbol ? AppColors.statusInfo20 :
                          isJustSelected ? AppColors.statusPositive20 : AppColors.surfaceWhite05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrentSymbol ? AppColors.statusInfo40 : Color.clear, lineWidth: 1)
            )
        }
        .opacity(symbol.isSelectableForActiveProvider ? 1.0 : 0.65)
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
    let symbol: RLTradingSymbolDTO
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

                    FlowLayout(spacing: 6) {
                        if let provider = symbol.activeProviderDisplayName {
                            SymbolProviderBadge(provider: provider)
                        }
                        if !symbol.isSelectableForActiveProvider {
                            UnsupportedSymbolBadge()
                        }
                    }
                }

                Spacer()

                // Price info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(symbol.priceFormatted ?? "--")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    HStack(spacing: 2) {
                        Image(systemName: (symbol.isUp ?? false) ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(symbol.changeFormatted ?? "--")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(symbol.changeColor)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentSymbol ? AppColors.statusInfo20 :
                          isJustSelected ? AppColors.statusPositive20 : AppColors.surfaceWhite05)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isCurrentSymbol ? AppColors.statusInfo40 : Color.clear, lineWidth: 1)
            )
        }
        .opacity(symbol.isSelectableForActiveProvider ? 1.0 : 0.65)
        .buttonStyle(.plain)
        // No context menu - guild watchlist is read-only
    }
}

// MARK: - Search Result Symbol Row (personal watchlist only)

struct SearchResultSymbolRow: View {
    let symbol: RLTradingSymbolDTO
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

                    FlowLayout(spacing: 6) {
                        if let provider = symbol.activeProviderDisplayName {
                            SymbolProviderBadge(provider: provider)
                        }
                        if !symbol.isSelectableForActiveProvider {
                            UnsupportedSymbolBadge()
                        }
                    }
                }

                Spacer()
                
                // Personal watchlist button only
                Button(action: onAddToPersonal) {
                    Image(systemName: inPersonal ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(
                            !symbol.isSelectableForActiveProvider
                                ? AppColors.statusNegative80
                                : (inPersonal ? .yellow : .gray)
                        )
                        .frame(width: 32, height: 32)
                        .background(inPersonal ? AppColors.statusHighlight20 : AppColors.surfaceWhite10)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(inPersonal || isAddingSymbol || !symbol.isSelectableForActiveProvider)
                
                if isAddingSymbol {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.surfaceWhite05)
            )
        }
        .opacity(symbol.isSelectableForActiveProvider ? 1.0 : 0.65)
        .buttonStyle(.plain)
    }
}

// MARK: - Symbol Icon View (with SVG support)

struct WatchlistSymbolIcon: View {
    let symbol: RLTradingSymbolDTO
    var size: CGFloat = 44
    
    var body: some View {
        TradingSymbolIconView(
            symbol: symbol,
            size: size,
            cornerRadiusRatio: 0.22,
            strokeOpacity: 0.15,
            showShadow: false
        )
    }
}
