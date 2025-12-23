//
//  WatchlistView.swift
//  traders_guild
//
//  Guild & Personal Watchlist View for Left Drawer
//  Features: Personal/Guild tabs, symbol icons, market status, search,
//            add/remove with confirmation, chart linking, keyboard dismiss
//

import SwiftUI
import UIKit

// MARK: - Watchlist View

struct WatchlistView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var appState: AppState
    
    // Tab state
    @State private var selectedTab: WatchlistTab = .guild
    
    // Search state
    @State private var searchText: String = ""
    @State private var searchResults: [TradingSymbolDTO] = []
    @State private var isSearchFocused: Bool = false
    
    // Loading states
    @State private var isAddingSymbol: UUID? = nil
    @State private var isRemovingSymbol: UUID? = nil
    
    // Confirmation dialog
    @State private var symbolToRemove: TradingSymbolDTO? = nil
    @State private var showRemoveConfirmation: Bool = false
    
    enum WatchlistTab: String, CaseIterable {
        case personal = "Personal"
        case guild = "Guild"
        
        var icon: String {
            switch self {
            case .personal: return "star.fill"
            case .guild: return "person.3.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            tabSelector
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            // Search bar
            searchBar
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            
            // Content
            ScrollView {
                VStack(spacing: 12) {
                    if !searchText.isEmpty {
                        // Search results
                        searchResultsSection
                    } else {
                        // Watchlist content based on selected tab
                        watchlistSection
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .confirmationDialog(
            "Remove from \(selectedTab.rawValue) Watchlist?",
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
            Text("This will remove \(symbol.displayName) from your \(selectedTab.rawValue.lowercased()) watchlist.")
        }
        .onDisappear {
            // Ensure keyboard is dismissed when view disappears
            dismissKeyboard()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Dismiss keyboard when changing tabs
            dismissKeyboard()
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(WatchlistTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        searchText = ""
                        searchResults = []
                    }
                    dismissKeyboard()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                        
                        // Count badge
                        Text("(\(countForTab(tab)))")
                            .font(.system(size: 11))
                            .foregroundColor(selectedTab == tab ? .white.opacity(0.7) : .gray)
                    }
                    .foregroundColor(selectedTab == tab ? .white : .gray)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ?
                        LinearGradient(
                            colors: tab == .personal ? [.yellow.opacity(0.4), .orange.opacity(0.3)] : [.blue.opacity(0.4), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedTab == tab ? (tab == .personal ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.3)) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    private func countForTab(_ tab: WatchlistTab) -> Int {
        switch tab {
        case .personal:
            return leftDrawerViewModel.personalTradingWatchlist.count
        case .guild:
            return leftDrawerViewModel.guildTradingWatchlist.count
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 15))
            
            TextField("Search symbols to add...", text: $searchText)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .onChange(of: searchText) { newValue in
                    performSearch(query: newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                    dismissKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Search Results")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !searchResults.isEmpty {
                    Text("\(searchResults.count) found")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No symbols found for '\(searchText)'")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(searchResults) { symbol in
                        WatchlistSymbolRow(
                            symbol: symbol,
                            isInWatchlist: isSymbolInCurrentWatchlist(symbol),
                            isLoading: isAddingSymbol == symbol.id,
                            showRemoveButton: false,
                            onToggleWatchlist: {
                                toggleWatchlist(symbol)
                            },
                            onSelectSymbol: {
                                selectSymbolForChart(symbol)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Watchlist Section
    
    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Get symbols based on selected tab
            let symbols = selectedTab == .personal ?
                leftDrawerViewModel.personalTradingWatchlist :
                leftDrawerViewModel.guildTradingWatchlist
            
            // Loading state
            if leftDrawerViewModel.isLoading && symbols.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                    Text("Loading \(selectedTab.rawValue) Watchlist...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            // Empty state
            else if symbols.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: selectedTab == .personal ? "star" : "person.3")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No Symbols in \(selectedTab.rawValue) Watchlist")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Search above to add symbols")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
            // Watchlist content
            else {
                // Group by asset class
                let grouped = Dictionary(grouping: symbols) { $0.assetClass }
                let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
                
                ForEach(orderedClasses, id: \.self) { assetClass in
                    if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                        WatchlistAssetGroup(
                            assetClass: assetClass,
                            symbols: classSymbols,
                            isRemovingSymbol: isRemovingSymbol,
                            onRemoveSymbol: { symbol in
                                requestRemoveSymbol(symbol)
                            },
                            onSelectSymbol: { symbol in
                                selectSymbolForChart(symbol)
                            }
                        )
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
    
    private func isSymbolInCurrentWatchlist(_ symbol: TradingSymbolDTO) -> Bool {
        switch selectedTab {
        case .personal:
            return leftDrawerViewModel.personalTradingWatchlist.contains { $0.id == symbol.id }
        case .guild:
            return leftDrawerViewModel.guildTradingWatchlist.contains { $0.id == symbol.id }
        }
    }
    
    private func toggleWatchlist(_ symbol: TradingSymbolDTO) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        if isSymbolInCurrentWatchlist(symbol) {
            requestRemoveSymbol(symbol)
        } else {
            addToWatchlist(symbol)
        }
    }
    
    private func requestRemoveSymbol(_ symbol: TradingSymbolDTO) {
        symbolToRemove = symbol
        showRemoveConfirmation = true
    }
    
    private func confirmRemoveSymbol(_ symbol: TradingSymbolDTO) {
        removeFromWatchlist(symbol)
        symbolToRemove = nil
    }
    
    private func addToWatchlist(_ symbol: TradingSymbolDTO) {
        isAddingSymbol = symbol.id
        
        Task {
            do {
                switch selectedTab {
                case .personal:
                    guard let userId = appState.currentUser?.id else { return }
                    try await appState.addToPersonalWatchlist(userId: userId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
                        if !leftDrawerViewModel.personalTradingWatchlist.contains(where: { $0.id == symbol.id }) {
                            leftDrawerViewModel.personalTradingWatchlist.append(symbol)
                        }
                    }
                    
                case .guild:
                    guard let guildId = appState.currentGuild?.id else { return }
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
                    appState.showError(error, title: "Failed to add symbol")
                }
            }
            
            await MainActor.run {
                isAddingSymbol = nil
            }
        }
    }
    
    private func removeFromWatchlist(_ symbol: TradingSymbolDTO) {
        isRemovingSymbol = symbol.id
        
        Task {
            do {
                switch selectedTab {
                case .personal:
                    guard let userId = appState.currentUser?.id else { return }
                    try await appState.removeFromPersonalWatchlist(userId: userId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
                        leftDrawerViewModel.personalTradingWatchlist.removeAll { $0.id == symbol.id }
                    }
                    
                case .guild:
                    guard let guildId = appState.currentGuild?.id else { return }
                    try await appState.removeFromGuildWatchlist(guildId: guildId, symbolId: symbol.id)
                    await MainActor.run {
                        // Update single source of truth
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
            }
        }
    }
    
    private func selectSymbolForChart(_ symbol: TradingSymbolDTO) {
        dismissKeyboard()
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Post notification to update chart and close drawer
        NotificationCenter.default.post(
            name: .selectChartSymbol,
            object: nil,
            userInfo: ["symbol": symbol]
        )
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let selectChartSymbol = Notification.Name("selectChartSymbol")
}

// MARK: - Asset Group View

struct WatchlistAssetGroup: View {
    let assetClass: AssetClass
    let symbols: [TradingSymbolDTO]
    let isRemovingSymbol: UUID?
    let onRemoveSymbol: (TradingSymbolDTO) -> Void
    let onSelectSymbol: (TradingSymbolDTO) -> Void
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: assetClass.icon)
                        .font(.system(size: 14))
                        .foregroundColor(assetClassColor)
                        .frame(width: 20)
                    
                    Text(assetClass.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("(\(symbols.count))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
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
                        WatchlistSymbolRow(
                            symbol: symbol,
                            isInWatchlist: true,
                            isLoading: isRemovingSymbol == symbol.id,
                            showRemoveButton: true,
                            onToggleWatchlist: {
                                onRemoveSymbol(symbol)
                            },
                            onSelectSymbol: {
                                onSelectSymbol(symbol)
                            }
                        )
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

// MARK: - Symbol Row View

struct WatchlistSymbolRow: View {
    let symbol: TradingSymbolDTO
    let isInWatchlist: Bool
    var isLoading: Bool = false
    var showRemoveButton: Bool = false
    let onToggleWatchlist: () -> Void
    let onSelectSymbol: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Tap area for chart selection
            Button(action: onSelectSymbol) {
                HStack(spacing: 12) {
                    // Symbol Icon
                    WatchlistSymbolIcon(symbol: symbol, size: 42)
                    
                    // Symbol Info
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(symbol.ticker)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Market status indicator
                            MarketStatusIndicator(isActive: symbol.isActive)
                        }
                        
                        Text(symbol.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Price Info
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(symbol.priceFormatted)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 2) {
                            Image(systemName: symbol.isUp ? "arrow.up" : "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                            Text(symbol.changeFormatted)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(symbol.changeColor)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Add/Remove button
            Button(action: onToggleWatchlist) {
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else if showRemoveButton {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red.opacity(0.8))
                    } else {
                        Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(isInWatchlist ? .green : .blue)
                    }
                }
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isPressed ? 0.08 : 0.04))
        )
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Symbol Icon for Watchlist

struct WatchlistSymbolIcon: View {
    let symbol: TradingSymbolDTO
    var size: CGFloat = 42
    
    var body: some View {
        Group {
            if let iconName = symbol.iconName {
                // Has custom icon
                Image(iconName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                // Gradient with letter
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

// MARK: - Market Status Indicator

struct MarketStatusIndicator: View {
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WatchlistView()
    }
}

////
////  WatchlistView.swift
////  traders_guild
////
////  Created by Al Hennessey on 10/10/2025.
////
//
//import SwiftUI
//
//// MARK: - Watchlist View
//struct WatchlistView: View {
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 10) {
//                // ✅ Loading state
//                if leftDrawerViewModel.isLoading && leftDrawerViewModel.watchlist == nil {
//                    VStack(spacing: 16) {
//                        ProgressView()
//                            .scaleEffect(1.2)
//                        Text("Loading Guild Watchlist...")
//                            .font(.subheadline)
//                            .foregroundColor(AppColors.whiteText.opacity(0.5))
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.top, 40)
//                }
//                else if leftDrawerViewModel.watchlist?.symbols.isEmpty ?? true {
//                    VStack(spacing: 12) {
//                        Image(systemName: "chart.line.uptrend.xyaxis")
//                            .font(.largeTitle)
//                            .foregroundColor(AppColors.whiteText.opacity(0.3))
//                        Text("No Symbols in Guild Watchlist")
//                            .font(.subheadline)
//                            .foregroundColor(AppColors.whiteText.opacity(0.5))
//                        Text("Check back later for guild updates")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText.opacity(0.4))
//                            .multilineTextAlignment(.center)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.top, 40)
//                } else {
//                    // ✅ Group symbols by type
//                    if let symbols = leftDrawerViewModel.watchlist?.symbols {
//                        WatchlistGroupedView(symbols: symbols) { symbol in
//                            // TODO: Navigate to chart view with symbol
//                            print("Navigate to chart for \(symbol.ticker)")
//                        }
//                    }
//                }
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 8)
//        }
//    }
//}
//
//// MARK: - Grouped Watchlist View
//struct WatchlistGroupedView: View {
//    let symbols: [SymbolDTO]
//    let onSymbolTap: (SymbolDTO) -> Void
//    
//    // Group symbols by type
//    private var groupedSymbols: [SymbolDTOType: [SymbolDTO]] {
//        Dictionary(grouping: symbols, by: { $0.symbolType })
//    }
//    
//    // Ordered types for consistent display
//    private let orderedTypes: [SymbolDTOType] = [.stocks, .cryptocurrency, .forex, .commodities]
//    
//    var body: some View {
//        VStack(spacing: 12) {
//            ForEach(orderedTypes, id: \.self) { symbolType in
//                WatchlistDisclosureGroup(
//                    symbolType: symbolType,
//                    symbols: groupedSymbols[symbolType] ?? [],
//                    onSymbolTap: onSymbolTap
//                )
//            }
//        }
//    }
//}
//
//// MARK: - Disclosure Group for Symbol Type
//struct WatchlistDisclosureGroup: View {
//    let symbolType: SymbolDTOType
//    let symbols: [SymbolDTO]
//    let onSymbolTap: (SymbolDTO) -> Void
//    
//    @State private var isExpanded: Bool = true
//    
//    private var symbolTypeIcon: String {
//        switch symbolType {
//        case .stocks:
//            return "chart.bar.fill"
//        case .cryptocurrency:
//            return "bitcoinsign.circle.fill"
//        case .forex:
//            return "dollarsign.circle.fill"
//        case .commodities:
//            return "cube.fill"
//        }
//    }
//    
//    private var symbolTypeColor: Color {
//        switch symbolType {
//        case .stocks:
//            return AppColors.accentColor
//        case .cryptocurrency:
//            return .orange
//        case .forex:
//            return AppColors.bullCandleGreen
//        case .commodities:
//            return .yellow
//        }
//    }
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            // Header
//            Button(action: {
//                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                    isExpanded.toggle()
//                }
//            }) {
//                HStack(spacing: 12) {
//                    // Icon
//                    Image(systemName: symbolTypeIcon)
//                        .font(.caption)
//                        .foregroundColor(symbolTypeColor)
//                        .frame(width: 16)
//                    
//                    // Type name
//                    Text(symbolType.rawValue)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.whiteText)
//                    
//                    // Count
//                    Text("(\(symbols.count))")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                    
//                    Spacer()
//                    
//                    // Chevron
//                    Image(systemName: "chevron.right")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 10)
//                .background(Color.white.opacity(0.06))
//                .cornerRadius(20)
//            }
//            .buttonStyle(PlainButtonStyle())
//            
//            // Symbols list
//            if isExpanded {
//                if symbols.isEmpty {
//                    // Empty state
//                    VStack(spacing: 8) {
//                        Image(systemName: "tray")
//                            .font(.title2)
//                            .foregroundColor(AppColors.whiteText.opacity(0.3))
//                        Text("No \(symbolType.rawValue.lowercased()) in watchlist")
//                            .font(.caption)
//                            .foregroundColor(AppColors.whiteText.opacity(0.5))
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 24)
//                } else {
//                    VStack(spacing: 6) {
//                        ForEach(symbols) { symbol in
//                            WatchlistRowView(
//                                symbol: symbol,
//                                onTap: {
//                                    onSymbolTap(symbol)
//                                    HapticFeedback.light.trigger()
//                                }
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Watchlist Row View
//struct WatchlistRowView: View {
//    let symbol: SymbolDTO
//    let onTap: () -> Void
//
//    
//    @State private var isPressed = false
//    
//    // Computed properties to simplify the complex expressions
//    private var isMarketOpen: Bool {
//        symbol.symbolStatus == .open
//    }
//    
//    private var statusIcon: String {
//        isMarketOpen ? "circle.circle.fill" : "moon.fill"
//    }
//    
//    private var statusColor: Color {
//        isMarketOpen ? AppColors.bullCandleGreen : AppColors.accentDarkColor
//    }
//    
//    
//    private var statusView: some View {
//        Group {
//            if isMarketOpen {
//                Image(systemName: statusIcon)
//                    .foregroundColor(statusColor)
//            } else {
//                Image(systemName: statusIcon)
//                    .symbolRenderingMode(.palette)
//                    .foregroundStyle(statusColor, .white)
//            }
//        }
//        .font(.caption2)
//        .fontWeight(.regular)
//    }
//    
//    private var isDirectionPositive: Bool{
//        symbol.isUp == true
//    }
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 12) {
//                VStack(spacing: 4) {
//                    Text(String(symbol.ticker.prefix(2)))
//                        .font(.caption2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
//                    
//                }
//                .frame(width: 40, height: 40)
//                .background(Color.white.opacity(0.1))
//                .cornerRadius(8)
//
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Text(symbol.ticker)
//                            .font(.subheadline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        statusView
//                    }
//                    
//                    Text(symbol.name)
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.6))
//                }
//
//                Spacer()
//
//                VStack(alignment: .trailing, spacing: 4) {
//                    Text(symbol.price.formatted())
//                        .font(.callout)
//                        .fontWeight(.medium)
//                        .foregroundColor(AppColors.whiteText.opacity(0.9))
//                    Text("\(symbol.change.formatted())  \(symbol.changeFormatted)")
//                        .font(.footnote)
//                        .fontWeight(.regular)
//                        .foregroundColor(isDirectionPositive ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
//                }
//                .padding(.leading, 4)
//            }
//            .padding(.trailing, 16)
//            .padding(.leading, 8)
//            .padding(.vertical, 8)
//            .frame(minHeight: 56, alignment: .center)
//            .background(
//                RoundedRectangle(cornerRadius: 14)
//                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.03))
////                    .overlay(
////                        RoundedRectangle(cornerRadius: 14)
////                            .strokeBorder(AppColors.accentColor.opacity(0.3), lineWidth: 1)
////                    )
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = pressing
//            }
//        }, perform: {})
//    }
//}
