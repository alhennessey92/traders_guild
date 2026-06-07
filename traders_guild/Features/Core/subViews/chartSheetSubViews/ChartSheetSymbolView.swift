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
    @State private var isSymbolDetailsExpanded: Bool = false
    @State private var keyboardInset: CGFloat = 0
    
    // Helper to get current symbol as DTO
    private var currentSymbolDTO: RLTradingSymbolDTO? {
        return chartViewModel.currentSymbol
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Current Symbol Header
                currentSymbolHeader

                // Symbol Details
                currentSymbolDetailsSection
                
                // Loading indicator
                if chartViewModel.isLoadingData {
                    loadingIndicator
                }
                
                // Timeframe Selector
                timeframeSection
                
                // Watchlist Section with Tabs
                watchlistSection
            }
            .padding(.bottom, selectedWatchlistTab == .search ? max(keyboardInset + 32, 32) : 32)
        }
        .contentShape(Rectangle())
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTapAndDragBackground()
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            },
            including: .subviews
        )
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
            keyboardInset = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardInset(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardInset = 0
            }
        }
        .onAppear {
            Task {
                await reloadGuildRequestState()
            }
        }
        .task(id: currentSymbolDTO?.id) {
            if let id = currentSymbolDTO?.id {
                await chartViewModel.loadSymbolPreview(for: id)
            }
        }
        .onChange(of: rlAppState.currentGuild?.id) {
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
                        
                        // Middle section: name, ticker + status, pills
                        VStack(alignment: .leading, spacing: 4) {
                            Text(symbol.displayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppColors.onSymbolBlueBackground)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(alignment: .center, spacing: 6) {
                                Text(symbol.ticker)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.onSymbolBlueBackgroundMuted)

                                SymbolMarketStatus(isMarketOpen: symbol.effectiveIsMarketOpen)

                                SymbolWatchlistIndicators(
                                    inPersonal: symbol.inPersonalWatchlist == true,
                                    inGuild: symbol.inGuildWatchlist == true
                                )
                            }

                            FlowLayout(spacing: 5) {
                                SymbolProviderBadge(provider: symbol.providerDisplayLabel)

                                ForEach(symbol.activityBadgeValues, id: \.self) { badge in
                                    SymbolActivityBadge(label: badge)
                                }

                                SymbolAssetClassBadge(assetClass: symbol.assetClass)

                                if !symbol.isSelectableForActiveProvider {
                                    UnsupportedSymbolBadge()
                                }
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        // Price section - fixed width to prevent squishing
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(symbol.formatPrice(chartViewModel.dataManager.currentPrice))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(AppColors.onSymbolBlueBackground)
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
                            AppColors.symbolSheetHeroBlueGradientLeading,
                            AppColors.symbolSheetHeroBlueGradientTrailing
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.symbolSheetHeroBlueStroke, lineWidth: 1)
                )
                .cornerRadius(14)
            }
        }
    }

    private var currentSymbolDetailsSection: some View {
        Group {
            if let symbol = currentSymbolDTO {
                VStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSymbolDetailsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.adaptiveAccessoryForeground)

                            Text("Symbol Details")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.primaryForeground)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.adaptiveAccessoryForeground)
                                .rotationEffect(.degrees(isSymbolDetailsExpanded ? 90 : 0))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppColors.symbolDetailsHeaderGradientLeading,
                                    AppColors.symbolDetailsHeaderGradientTrailing,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if isSymbolDetailsExpanded {
                        VStack(alignment: .leading, spacing: 10) {
                            symbolPriceLineBlock(for: symbol)

                            if let description = symbol.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !description.isEmpty {
                                SymbolInfoBlock(
                                    title: "About",
                                    value: description,
                                    urlString: symbol.infoUrl
                                )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                MarketSessionTimeline(symbol: symbol)
                                Text(runningHoursText(for: symbol))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppColors.secondaryForeground)
                            }

                            SymbolDetailRow(
                                title: "Day High / Low",
                                value: dayHighLowText(for: symbol)
                            )
                            SymbolDetailRow(
                                title: "Week High / Low",
                                value: weekHighLowText(for: symbol)
                            )
                            SymbolDetailRow(
                                title: "Global Sentiment",
                                value: bullishBearishSummary(for: symbol)
                            )
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.symbolDetailCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.symbolDetailCardStroke, lineWidth: 1)
                                )
                        )
                        .transition(.opacity)
                    } else {
                        symbolDetailsCompactSummary(for: symbol)
                            .transition(.opacity)
                    }
                }
                .clipped()
            }
        }
    }

    /// Collapsed summary: a short "sample window" into the full details — two
    /// prominent, tappable tiles for the data Provider (brand-coloured) and 24h
    /// Sentiment. Kept to roughly half the detailed height; tapping expands
    /// everything (including the 24h price line).
    private func symbolDetailsCompactSummary(for symbol: RLTradingSymbolDTO) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSymbolDetailsExpanded = true
            }
            HapticFeedback.light.trigger()
        } label: {
            HStack(spacing: 10) {
                providerTile(for: symbol)
                sentimentTile(for: symbol)
            }
        }
        .buttonStyle(.plain)
    }

    private func providerTile(for symbol: RLTradingSymbolDTO) -> some View {
        let brand = ProviderBrand.resolve(symbol.providerDisplayLabel)
        return compactTile(title: "Provider", accent: brand.color) {
            HStack(spacing: 9) {
                brandLogo(brand, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(symbol.providerDisplayLabel)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(AppColors.primaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Market data")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.secondaryForeground)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func sentimentTile(for symbol: RLTradingSymbolDTO) -> some View {
        let descriptor = sentimentDescriptor(for: symbol)
        return compactTile(title: "Sentiment", accent: descriptor.color) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(descriptor.color.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: descriptor.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(descriptor.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(descriptor.label)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(descriptor.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(symbol.changeFormatted ?? "--") · 24h")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.secondaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Shared chrome for the two collapsed tiles: a labelled, accent-tinted card.
    private func compactTile<Content: View>(
        title: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(AppColors.secondaryForeground)
                .tracking(0.4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accent.opacity(0.30), lineWidth: 1)
                )
        )
    }

    /// Brand "logo" tile — a brand-coloured rounded square with the provider's
    /// monogram (falls back to a coloured dot for unknown providers).
    private func brandLogo(_ brand: ProviderBrand, size: CGFloat) -> some View {
        Group {
            if brand.monogram.isEmpty {
                Circle()
                    .fill(brand.color)
                    .frame(width: size * 0.5, height: size * 0.5)
                    .frame(width: size, height: size)
            } else {
                Text(brand.monogram)
                    .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                    .foregroundColor(brand.onColor)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .fill(brand.color)
                    )
            }
        }
    }

    /// 24h price line for the expanded detail view. Uses MiniLineChart, which
    /// scales to the series' own min/max so real peaks and troughs are visible.
    @ViewBuilder
    private func symbolPriceLineBlock(for symbol: RLTradingSymbolDTO) -> some View {
        let preview = chartViewModel.currentSymbolPreview
        let closes = (preview?.symbolId == symbol.id) ? (preview?.closes ?? []) : []
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Last 24h")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.secondaryForeground)
                Spacer(minLength: 0)
                Text(symbol.changeFormatted ?? "--")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(symbol.changeColor)
            }
            if closes.count >= 2 {
                MiniLineChart(values: closes, tint: symbol.changeColor, height: 92)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.surfaceWhite10)
                    .frame(height: 92)
                    .overlay(
                        Text("Loading 24h…")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.secondaryForeground)
                    )
            }
        }
    }

    private func sentimentDescriptor(
        for symbol: RLTradingSymbolDTO
    ) -> (label: String, icon: String, color: Color) {
        let change = symbol.changePercent24h ?? 0
        if change > 0.15 {
            return ("Bullish", "chart.line.uptrend.xyaxis", AppColors.priceChangePositive)
        }
        if change < -0.15 {
            return ("Bearish", "chart.line.downtrend.xyaxis", AppColors.priceChangeNegative)
        }
        return ("Neutral", "arrow.left.and.right", AppColors.secondaryForeground)
    }
    
    // MARK: - Watchlist Buttons
    
    private func watchlistButtons(for symbol: RLTradingSymbolDTO) -> some View {
        // Use chartViewModel watchlists as single source of truth
        let inPersonal = chartViewModel.personalWatchlist.contains { $0.id == symbol.id }
        let inGuild = chartViewModel.guildWatchlist.contains { $0.id == symbol.id }
        let isRequested = pendingGuildRequests.contains { $0.symbolId == symbol.id && $0.status.lowercased() == "pending" }
        let canDirectlyManageGuildWatchlist = rlAppState.canAdmin
        let isUnsupported = !symbol.isSelectableForActiveProvider
        
        return HStack(spacing: 10) {
            // Personal watchlist button - unchanged behavior
            Button(action: {
                if isUnsupported {
                    showUnsupportedSymbolToast(symbol)
                    return
                }
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
                            .tint(inPersonal ? AppColors.symbolDetailPersonalStarActive : AppColors.surfaceDetailSecondaryForeground)
                    } else {
                        Image(systemName: inPersonal ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text("Personal")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(inPersonal ? AppColors.symbolDetailPersonalStarActive : AppColors.surfaceDetailSecondaryForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    inPersonal ?
                    AppColors.statusHighlight40 :
                    AppColors.surfaceWhite10
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(inPersonal ? AppColors.statusHighlight68 : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isAddingToPersonal || isUnsupported)
            
            // Guild watchlist button with role-aware states
            Button(action: {
                if isUnsupported {
                    showUnsupportedSymbolToast(symbol)
                    return
                }
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
                            .tint((inGuild || isRequested) ? AppColors.statusInfo : AppColors.surfaceDetailSecondaryForeground)
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
            .disabled(inGuild || isRequested || isRequestingGuild || isUnsupported)
            
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
        if inGuild { return AppColors.statusInfo }
        if isRequested { return AppColors.moderationOrange }
        return AppColors.surfaceDetailSecondaryForeground
    }

    private func guildButtonBackgroundColor(inGuild: Bool, isRequested: Bool) -> Color {
        if inGuild { return AppColors.statusInfo40 }
        if isRequested { return AppColors.statusWarning40 }
        return AppColors.surfaceWhite10
    }

    private func guildButtonStrokeColor(inGuild: Bool, isRequested: Bool) -> Color {
        if inGuild { return AppColors.statusInfo65 }
        if isRequested { return AppColors.statusWarning62 }
        return Color.clear
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(AppColors.primaryForeground)
            Text("Loading chart data...")
                .font(.caption)
                .foregroundColor(AppColors.secondaryForeground)
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
            .background(AppColors.symbolSheetGroupedPanelFill)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func timeframeRow(title: String, timeframes: [RLChartTimeframe]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.secondaryForeground)
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
                    .foregroundColor(AppColors.primaryForeground)
                
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
                    dismissKeyboard()
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
                    .foregroundColor(AppColors.secondaryForeground)
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
                .foregroundColor(AppColors.surfaceGray40)
            
            Text("Search for Symbols")
                .font(.headline)
                .foregroundColor(AppColors.secondaryForeground)
            
            Text("Find symbols to view on chart or add to your personal watchlist")
                .font(.caption)
                .foregroundColor(AppColors.surfaceGray70)
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
        let orderedClasses: [RLAssetClass] = [.crypto, .forex, .stocks, .commodities, .indices, .futures]
        
        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    SymbolAssetGroup(
                        assetClass: assetClass,
                        symbols: classSymbols,
                        currentSymbolId: currentSymbolDTO?.id,
                        isExpandedByDefault: assetClass == .crypto,
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
        let orderedClasses: [RLAssetClass] = [.crypto, .forex, .stocks, .commodities, .indices, .futures]

        return VStack(spacing: 10) {
            ForEach(orderedClasses, id: \.self) { assetClass in
                if let classSymbols = grouped[assetClass], !classSymbols.isEmpty {
                    UnifiedDisclosureGroup(
                        title: assetClass.rawValue,
                        count: classSymbols.count,
                        icon: assetClass.icon,
                        iconColor: assetClassColor(assetClass),
                        isExpandedByDefault: assetClass == .crypto
                    ) {
                        LazyVStack(spacing: 6) {
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

    private func updateKeyboardInset(from notification: Notification) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow),
              let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let convertedEndFrame = window.convert(endFrame, from: nil)
        let overlap = max(0, window.bounds.maxY - convertedEndFrame.minY - window.safeAreaInsets.bottom)

        withAnimation(.easeOut(duration: 0.2)) {
            keyboardInset = overlap
        }
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
        guard symbol.isSelectableForActiveProvider else {
            showUnsupportedSymbolToast(symbol)
            return
        }
        dismissKeyboard()
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        chartViewModel.setSymbol(symbol)
    }

    private func showUnsupportedSymbolToast(_ symbol: RLTradingSymbolDTO) {
        if APIEnvironment.current == .production {
            rlAppState.showError(
                title: "Available in Production",
                message: "\(symbol.ticker) is listed in public beta, but live data is currently limited to Binance crypto markets. Broader markets unlock in production.",
                style: .toast
            )
            return
        }

        let providerText = symbol.providerDisplayLabel
        rlAppState.showError(
            title: "Symbol Unavailable",
            message: "\(symbol.ticker) is not supported by \(providerText).",
            style: .toast
        )
    }

    private func runningHoursText(for symbol: RLTradingSymbolDTO) -> String {
        switch symbol.assetClass.lowercased() {
        case "crypto":
            return "24/7 continuous trading"
        case "forex":
            return "Sun 22:00 to Fri 22:00 UTC"
        case "stocks":
            return "Exchange session hours"
        case "commodities", "futures":
            return "Exchange-dependent sessions"
        default:
            return "Market schedule varies"
        }
    }

    private func dayHighLowText(for symbol: RLTradingSymbolDTO) -> String {
        if let high = symbol.high24h, let low = symbol.low24h {
            return "\(symbol.formatPrice(low)) – \(symbol.formatPrice(high))"
        }
        // Crypto / providers without a 24h snapshot: derive the range from candles.
        if let range = recentRange(hours: 24) {
            return "\(symbol.formatPrice(range.low)) – \(symbol.formatPrice(range.high))"
        }
        return "Unavailable"
    }

    private func weekHighLowText(for symbol: RLTradingSymbolDTO) -> String {
        guard let range = recentRange(hours: 24 * 7) else { return "Unavailable" }
        return "\(symbol.formatPrice(range.low)) – \(symbol.formatPrice(range.high))"
    }

    /// High/low derived from candles within the last `hours`, falling back to the
    /// most recent loaded candles when that window has too few points.
    private func recentRange(hours: Int) -> (low: Double, high: Double)? {
        let candles = chartViewModel.dataManager.candles
        guard !candles.isEmpty else { return nil }
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let windowed = candles.filter { $0.timestamp >= cutoff }
        let pool = windowed.count >= 2 ? windowed : Array(candles.suffix(48))
        guard let low = pool.map(\.low).min(), let high = pool.map(\.high).max() else { return nil }
        return (low, high)
    }

    private func bullishBearishSummary(for symbol: RLTradingSymbolDTO) -> String {
        let dayChange = symbol.changePercent24h ?? 0
        if dayChange > 0.15 {
            return "Bullish bias (+\(String(format: "%.2f", dayChange))%)"
        }
        if dayChange < -0.15 {
            return "Bearish bias (\(String(format: "%.2f", dayChange))%)"
        }
        return "Neutral / range-bound"
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
        .foregroundColor(AppColors.surfaceDetailSecondaryForeground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.surfaceWhite10)
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
                .foregroundColor(isSelected ? AppColors.onAccentForeground : AppColors.secondaryForeground)
                .frame(minWidth: 44)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [AppColors.statusInfo70, AppColors.statusInfo90],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            AppColors.timeframeChipUnselectedLeading,
                            AppColors.timeframeChipUnselectedTrailing,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? AppColors.statusInfo90 : Color.clear, lineWidth: 1)
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
    let isExpandedByDefault: Bool
    let onSelectSymbol: (RLTradingSymbolDTO) -> Void
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: assetClass.rawValue,
            count: symbols.count,
            icon: assetClass.icon,
            iconColor: assetClassColor(assetClass),
            isExpandedByDefault: isExpandedByDefault
        ) {
            LazyVStack(spacing: 6) {
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

    private var pillCount: Int {
        var n = 1
        n += symbol.activityBadgeValues.count
        if !symbol.isSelectableForActiveProvider { n += 1 }
        return n
    }

    var body: some View {
        let isCompactPills = pillCount >= 3
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
                            .foregroundColor(isSelected ? AppColors.onSymbolBlueBackground : AppColors.primaryForeground)

                        // Market status indicator
                        SymbolMarketStatus(isMarketOpen: symbol.effectiveIsMarketOpen)

                        SymbolWatchlistIndicators(
                            inPersonal: symbol.inPersonalWatchlist == true,
                            inGuild: symbol.inGuildWatchlist == true
                        )
                    }

                    Text(symbol.displayName)
                        .font(.caption)
                        .foregroundColor(isSelected ? AppColors.onSymbolBlueBackgroundMuted : AppColors.secondaryForeground)
                        .lineLimit(1)

                    FlowLayout(spacing: 6) {
                        SymbolProviderBadge(provider: symbol.providerDisplayLabel, isCompact: isCompactPills)
                        ForEach(symbol.activityBadgeValues, id: \.self) { badge in
                            SymbolActivityBadge(label: badge, isCompact: isCompactPills)
                        }
                        if !symbol.isSelectableForActiveProvider {
                            UnsupportedSymbolBadge(isCompact: isCompactPills)
                        }
                    }
                }
                .frame(maxHeight: 64)
                .layoutPriority(1)
                
                Spacer()
                
                // Price and Change
                VStack(alignment: .trailing, spacing: 3) {
                    Text(symbol.priceFormatted ?? "--")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? AppColors.onSymbolBlueBackground : AppColors.primaryForeground)
                    
                    HStack(spacing: 2) {
                        Image(systemName: (symbol.isUp ?? true) ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(symbol.changeFormatted ?? "--")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(symbol.changeColor)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.statusInfo90)
                        .font(.title3)
                }
            }
            .padding(12)
            .background(
                isSelected ?
                LinearGradient(
                    colors: [
                        AppColors.symbolListRowSelectedBlueGradientLeading,
                        AppColors.symbolListRowSelectedBlueGradientTrailing
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    colors: [
                        AppColors.symbolListRowUnselectedLeading,
                        AppColors.symbolListRowUnselectedTrailing,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppColors.symbolListRowSelectedBlueStroke : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
        }
        .opacity(symbol.isSelectableForActiveProvider ? 1.0 : 0.65)
        .buttonStyle(.plain)
    }
}

struct GlobalSymbolListRow: View {
    let symbol: RLTradingSymbolDTO
    let isSelected: Bool
    let action: () -> Void

    private var statusBadges: [String] {
        var badges: [String] = []
        if symbol.isRequestedForGuild == true {
            badges.append("Requested")
        }
        if symbol.isSupportedByActiveProvider == false {
            badges.append(UnsupportedSymbolBadge.labelText)
        }
        return badges
    }

    private var pillCount: Int {
        var n = 1
        n += symbol.activityBadgeValues.count
        if !symbol.isSelectableForActiveProvider { n += 1 }
        n += statusBadges.count
        return n
    }

    var body: some View {
        let isCompactPills = pillCount >= 3
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    SymbolIconView(symbol: symbol, size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(symbol.ticker)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.primaryForeground)

                            SymbolMarketStatus(isMarketOpen: symbol.effectiveIsMarketOpen)

                            SymbolWatchlistIndicators(
                                inPersonal: symbol.inPersonalWatchlist == true,
                                inGuild: symbol.inGuildWatchlist == true
                            )
                        }

                        Text(symbol.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryForeground)
                            .lineLimit(1)

                        FlowLayout(spacing: 6) {
                            SymbolProviderBadge(provider: symbol.providerDisplayLabel, isCompact: isCompactPills)
                            ForEach(symbol.activityBadgeValues, id: \.self) { badge in
                                SymbolActivityBadge(label: badge, isCompact: isCompactPills)
                            }
                            if !symbol.isSelectableForActiveProvider {
                                UnsupportedSymbolBadge(isCompact: isCompactPills)
                            }
                        }
                    }
                    .frame(maxHeight: 64)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(symbol.priceFormatted ?? "--")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryForeground)

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
                            .foregroundColor(AppColors.statusInfo90)
                            .font(.title3)
                    }
                }
                .padding(12)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [
                            AppColors.symbolListRowSelectedBlueGradientLeading,
                            AppColors.symbolListRowSelectedBlueGradientTrailing
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [
                            AppColors.symbolListRowUnselectedLeading,
                            AppColors.symbolListRowUnselectedTrailing,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? AppColors.symbolListRowSelectedBlueStroke : Color.clear,
                            lineWidth: 1
                        )
                )
                .cornerRadius(12)

                if !statusBadges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(statusBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.symbolRowBadgeForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.symbolRowBadgeBackground)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .opacity(symbol.isSelectableForActiveProvider ? 1.0 : 0.65)
        .buttonStyle(.plain)
    }
}

// MARK: - Market Status Indicator (for Symbol List)

struct SymbolMarketStatus: View {
    let isMarketOpen: Bool

    var body: some View {
        Group {
            if isMarketOpen {
                Circle()
                    .fill(AppColors.statusPositive)
                    .frame(width: 6, height: 6)
                    .shadow(color: AppColors.statusPositive50, radius: 2)
            } else {
                Image(systemName: "moon.fill")
                    .font(.system(size: 8))
                    .foregroundColor(AppColors.surfaceGray70)
            }
        }
        // Match cap height of adjacent ticker text so the indicator visually
        // centers on the ticker's x-height rather than its baseline.
        .frame(height: 12)
    }
}

struct SymbolAssetClassBadge: View {
    let assetClass: String

    private var displayLabel: String {
        switch assetClass.lowercased() {
        case "crypto", "cryptocurrency": return "Crypto"
        case "stock", "stocks", "equity": return "Stock"
        case "forex", "fx": return "Forex"
        case "commodity", "commodities": return "Commodity"
        case "index", "indices": return "Index"
        default: return assetClass.capitalized
        }
    }

    private var iconName: String {
        switch assetClass.lowercased() {
        case "crypto", "cryptocurrency": return "bitcoinsign.circle.fill"
        case "stock", "stocks", "equity": return "building.columns.fill"
        case "forex", "fx": return "dollarsign.arrow.circlepath"
        case "commodity", "commodities": return "leaf.fill"
        case "index", "indices": return "chart.bar.fill"
        default: return "tag.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 8, weight: .bold))
            Text(displayLabel)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundColor(AppColors.surfaceDetailPrimaryForeground)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AppColors.surfaceWhite20)
        .clipShape(Capsule())
        .accessibilityLabel(displayLabel)
    }
}

struct SymbolProviderBadge: View {
    let provider: String
    var isCompact: Bool = false

    private var brand: ProviderBrand { ProviderBrand.resolve(provider) }

    var body: some View {
        HStack(spacing: 4) {
            brandMark
            if !isCompact {
                Text(provider)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(AppColors.surfaceDetailPrimaryForeground)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(brand.color.opacity(0.16))
                .overlay(
                    Capsule()
                        .stroke(brand.color.opacity(0.34), lineWidth: 1)
                )
        )
        .accessibilityLabel(provider)
    }

    /// Mini brand "logo": a brand-colored monogram tile, or a colored dot for
    /// providers we don't have a monogram for.
    @ViewBuilder
    private var brandMark: some View {
        if brand.monogram.isEmpty {
            Circle()
                .fill(brand.color)
                .frame(width: 6, height: 6)
        } else {
            Text(brand.monogram)
                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                .foregroundColor(brand.onColor)
                .frame(width: 12, height: 12)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(brand.color)
                )
        }
    }
}

struct UnsupportedSymbolBadge: View {
    var isCompact: Bool = false

    static var labelText: String {
        APIEnvironment.current == .production ? "Prod Only" : "Unsupported"
    }

    var body: some View {
        Group {
            if isCompact {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
            } else {
                Text(Self.labelText)
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundColor(AppColors.surfaceDetailPrimaryForeground)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AppColors.statusNegative35)
        .clipShape(Capsule())
        .accessibilityLabel(Self.labelText)
    }
}

/// Small inline indicators that show whether a symbol is in the user's
/// personal watchlist (star) and/or the current guild's watchlist (group).
/// Renders next to the ticker / market-status indicator.
struct SymbolWatchlistIndicators: View {
    let inPersonal: Bool
    let inGuild: Bool

    var body: some View {
        HStack(spacing: 4) {
            if inPersonal {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.statusWarning95)
                    .accessibilityLabel("In your personal watchlist")
            }
            if inGuild {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.statusInfo90)
                    .accessibilityLabel("In guild watchlist")
            }
        }
    }
}

struct SymbolActivityBadge: View {
    let label: String
    var isCompact: Bool = false

    private var iconName: String {
        switch label.lowercased() {
        case "trending":
            return "chart.line.uptrend.xyaxis"
        case "hot":
            return "flame.fill"
        case "new markers":
            return "sparkles"
        default:
            return "circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch label.lowercased() {
        case "trending":
            return AppColors.statusWarning80
        case "hot":
            return AppColors.statusNegative.opacity(0.28)
        case "new markers":
            return AppColors.statusPositive25
        default:
            return AppColors.surfaceWhite20
        }
    }

    var body: some View {
        Group {
            if isCompact {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .bold))
            } else {
                HStack(spacing: 3) {
                    Image(systemName: iconName)
                        .font(.system(size: 8, weight: .bold))
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .foregroundColor(AppColors.surfaceDetailPrimaryForeground)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel(label)
    }
}

private struct SymbolDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.surfaceDetailTertiaryForeground)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.surfaceDetailPrimaryForeground)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SymbolInfoBlock: View {
    let title: String
    let value: String
    let urlString: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.surfaceDetailPrimaryForeground)

                if let url = infoURL {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.adaptiveAccessoryForeground)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(value)
                .font(.caption)
                .foregroundColor(AppColors.surfaceDetailSecondaryForeground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    private var infoURL: URL? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return url
    }
}

// MARK: - Market Session Timeline

struct MarketSessionTimeline: View {
    let symbol: RLTradingSymbolDTO

    @State private var now = Date()
    @State private var cachedOandaSessionState: (isOpen: Bool, nextTransition: Date)?
    @State private var cachedCountdownText: String = ""
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var session: RLTradingSymbolDTO.MarketSession { symbol.marketSession }
    private var tz: TimeZone { symbol.exchangeTimeZone }
    private var usesOandaForexSessionBoundaries: Bool { symbol.usesOandaForexSessionBoundaries }

    private var exchangeTimeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: now)
        let abbrev = tz.abbreviation(for: now) ?? tz.identifier
        return "\(abbrev) \(timeStr)"
    }

    private var currentFraction: Double {
        var calendar = Calendar.current
        calendar.timeZone = tz
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        return (Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0) / 24.0
    }

    private var isWeekend: Bool {
        var calendar = Calendar.current
        calendar.timeZone = tz
        return calendar.isDateInWeekend(now)
    }

    private var isInSession: Bool {
        if let oandaState = cachedOandaSessionState {
            return oandaState.isOpen
        }
        if session.isContinuous {
            return !(session.closedWeekend && isWeekend)
        }
        if session.closedWeekend && isWeekend { return false }

        if session.openHour <= session.closeHour {
            return currentFraction >= session.openFraction && currentFraction < session.closeFraction
        } else {
            return currentFraction >= session.openFraction || currentFraction < session.closeFraction
        }
    }

    private func computeCountdownText() -> String {
        var calendar = Calendar.current
        calendar.timeZone = tz

        if let oandaState = cachedOandaSessionState {
            return "\(oandaState.isOpen ? "Closes" : "Opens") \(relativeCountdown(to: oandaState.nextTransition))"
        }

        if session.isContinuous && !session.closedWeekend {
            return "Always Open"
        }

        if session.isContinuous && session.closedWeekend {
            if isWeekend {
                if let nextMonday = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, weekday: 2), matchingPolicy: .nextTime) {
                    return "Opens \(relativeCountdown(to: nextMonday))"
                }
                return "Closed (Weekend)"
            }
            let weekday = calendar.component(.weekday, from: now)
            if weekday == 6 {
                if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
                    return "Closes \(relativeCountdown(to: midnight))"
                }
            }
            return "Open"
        }

        if isInSession {
            var closeComps = DateComponents()
            closeComps.hour = session.closeHour >= 24 ? 0 : session.closeHour
            closeComps.minute = session.closeMinute
            if let closeTime = calendar.nextDate(after: now, matching: closeComps, matchingPolicy: .nextTime) {
                return "Closes \(relativeCountdown(to: closeTime))"
            }
            return "Open"
        } else {
            if isWeekend {
                if let nextMonday = calendar.nextDate(after: now, matching: DateComponents(hour: session.openHour, minute: session.openMinute, weekday: 2), matchingPolicy: .nextTime) {
                    return "Opens \(relativeCountdown(to: nextMonday))"
                }
                return "Closed (Weekend)"
            }
            var openComps = DateComponents()
            openComps.hour = session.openHour
            openComps.minute = session.openMinute
            if let openTime = calendar.nextDate(after: now, matching: openComps, matchingPolicy: .nextTime) {
                return "Opens \(relativeCountdown(to: openTime))"
            }
            return "Closed"
        }
    }

    private func relativeCountdown(to target: Date) -> String {
        let interval = target.timeIntervalSince(now)
        guard interval > 0 else { return "soon" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        }
        return "in \(minutes)m"
    }

    private func timeLabel(_ hour: Int, _ minute: Int) -> String {
        String(format: "%02d:%02d", hour >= 24 ? 0 : hour, minute)
    }

    private func computeOandaSessionState() -> (isOpen: Bool, nextTransition: Date)? {
        guard usesOandaForexSessionBoundaries else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = tz

        let sundayOpen = DateComponents(hour: 22, minute: 0, weekday: 1)
        let fridayClose = DateComponents(hour: 22, minute: 0, weekday: 6)

        guard
            let lastSundayOpen = calendar.nextDate(
                after: now,
                matching: sundayOpen,
                matchingPolicy: .nextTime,
                direction: .backward
            ),
            let lastFridayClose = calendar.nextDate(
                after: now,
                matching: fridayClose,
                matchingPolicy: .nextTime,
                direction: .backward
            ),
            let nextSundayOpen = calendar.nextDate(
                after: now,
                matching: sundayOpen,
                matchingPolicy: .nextTime
            ),
            let nextFridayClose = calendar.nextDate(
                after: now,
                matching: fridayClose,
                matchingPolicy: .nextTime
            )
        else {
            return nil
        }

        let isOpen = lastSundayOpen > lastFridayClose
        return isOpen ? (true, nextFridayClose) : (false, nextSundayOpen)
    }

    private func refreshDerivedState() {
        cachedOandaSessionState = computeOandaSessionState()
        cachedCountdownText = computeCountdownText()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.surfaceDetailSecondaryForeground)
                Text(exchangeTimeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.surfaceDetailPrimaryForeground)
                Spacer()
                Text(cachedCountdownText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isInSession ? AppColors.statusPositive90 : AppColors.statusWarning90)
            }

            if !session.isContinuous {
                sessionBar
            } else if session.closedWeekend {
                weekBar
            } else {
                continuousBar
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.symbolDetailCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.symbolDetailCardStroke, lineWidth: 1)
                )
        )
        .onAppear { refreshDerivedState() }
        .onChange(of: now) { _, _ in refreshDerivedState() }
        .onChange(of: symbol.id) { _, _ in refreshDerivedState() }
        .onReceive(timer) { _ in now = Date() }
    }

    private var sessionBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let openX = session.openFraction * w
            let closeX = session.closeFraction * w
            let nowX = currentFraction * w

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.surfaceWhite12)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.statusPositive50, AppColors.statusPositive30],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: closeX - openX, height: 6)
                    .offset(x: openX)

                Circle()
                    .fill(AppColors.systemWhite)
                    .frame(width: 8, height: 8)
                    .shadow(color: AppColors.surfaceWhite40, radius: 3)
                    .offset(x: nowX - 4)

                Text(timeLabel(session.openHour, session.openMinute))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceDetailQuaternaryForeground)
                    .offset(x: max(0, openX - 10), y: 12)

                Text(timeLabel(session.closeHour, session.closeMinute))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceDetailQuaternaryForeground)
                    .offset(x: min(w - 28, closeX - 10), y: 12)
            }
        }
        .frame(height: 24)
    }

    private var weekBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let dayWidth = w / 7.0
            var calendar = Calendar.current
            let _ = calendar.timeZone = tz
            let currentWeekday = calendar.component(.weekday, from: now)
            let nowX = currentFraction * w

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.surfaceWhite12)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.statusPositive50, AppColors.statusPositive30],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: dayWidth * 5, height: 6)
                    .offset(x: dayWidth)

                if !isWeekend || (usesOandaForexSessionBoundaries && isInSession) {
                    Circle()
                        .fill(AppColors.systemWhite)
                        .frame(width: 8, height: 8)
                        .shadow(color: AppColors.surfaceWhite40, radius: 3)
                        .offset(x: (CGFloat(currentWeekday - 1) * dayWidth + nowX / 7.0) - 4)
                }

                HStack(spacing: 0) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.surfaceDetailQuaternaryForeground)
                            .frame(width: dayWidth)
                    }
                }
                .offset(y: 12)
            }
        }
        .frame(height: 24)
    }

    private var continuousBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let nowX = currentFraction * w

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.statusPositive40, AppColors.statusPositive25],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 6)

                Circle()
                    .fill(AppColors.systemWhite)
                    .frame(width: 8, height: 8)
                    .shadow(color: AppColors.surfaceWhite40, radius: 3)
                    .offset(x: nowX - 4)

                Text("24/7")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AppColors.surfaceDetailQuaternaryForeground)
                    .offset(x: w / 2 - 10, y: 12)
            }
        }
        .frame(height: 24)
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
        AppColors.systemBlack.ignoresSafeArea()
        
        ScrollView {
            Text("Symbol Sheet Preview")
                .foregroundColor(AppColors.primaryForeground)
        }
        .padding()
    }
}
