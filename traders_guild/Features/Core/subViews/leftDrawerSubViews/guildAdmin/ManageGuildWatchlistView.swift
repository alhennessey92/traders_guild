//
//  ManageGuildWatchlistView.swift
//  traders_guild
//

import SwiftUI

private enum GuildWatchlistAdminTab: String, CaseIterable, UnifiedTabItem {
    case requests = "Requests"
    case current = "Current"
    case search = "Search"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .requests:
            return "tray.and.arrow.down.fill"
        case .current:
            return "list.bullet"
        case .search:
            return "magnifyingglass"
        }
    }
}

struct ManageGuildWatchlistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    @State private var selectedTab: GuildWatchlistAdminTab = .requests
    @State private var pendingRequests: [RLGuildWatchlistRequestResponseDTO] = []
    @State private var guildSymbols: [RLTradingSymbolDTO] = []
    @State private var globalSymbols: [RLTradingSymbolDTO] = []

    @State private var isLoading: Bool = true
    @State private var isSearching: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [RLTradingSymbolDTO] = []

    @State private var processingRequestIds: Set<UUID> = []
    @State private var processingSymbolIds: Set<UUID> = []

    private var canManage: Bool {
        rlAppState.canAdmin || rlAppState.isGuildOwner
    }

    private var pendingSymbolIds: Set<UUID> {
        Set(pendingRequests.map { $0.symbolId })
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 30)
                    .padding(.bottom, 12)
                    .adminSheetChrome(edge: .top)

                tabBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(AppColors.sheetBackground.opacity(0.98))

                content
                    .padding(.horizontal, 16)
            }

            SheetCloseButton(action: { dismiss() })
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdminSheetBackground())
        .onAppear {
            Task {
                await loadAll()
            }
        }
    }

    private var header: some View {
        AdminSheetHeader(
            icon: "list.bullet.rectangle",
            iconColor: .blue,
            title: "Guild Watchlist",
            subtitle: "Review symbol requests and manage guild symbols"
        )
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .subTab,
                countForTab: { badgeCount(for: $0) },
                spacing: 6
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
            Button("Refresh") {
                Task { await loadAll() }
            }
            .font(.caption)
            .disabled(isLoading)
        }
    }

    private func badgeCount(for tab: GuildWatchlistAdminTab) -> Int {
        switch tab {
        case .requests:
            return pendingRequests.count
        case .current:
            return 0
        case .search:
            return 0
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading watchlist...")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch selectedTab {
            case .requests:
                requestsContent
            case .current:
                currentWatchlistContent
            case .search:
                searchContent
            }
        }
    }

    private var requestsContent: some View {
        Group {
            if pendingRequests.isEmpty {
                VStack {
                    Spacer()
                    UnifiedEmptyState(
                        icon: "checkmark.seal",
                        title: "No Pending Requests",
                        subtitle: "All watchlist requests are up to date"
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(pendingRequests) { request in
                            requestCard(request)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func requestCard(_ request: RLGuildWatchlistRequestResponseDTO) -> some View {
        let busy = processingRequestIds.contains(request.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                TickerSymbolIconView(
                    ticker: request.symbolTicker,
                    size: 28,
                    cornerRadiusRatio: 0.22,
                    strokeOpacity: 0.14
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.symbolTicker)
                        .font(.headline)
                        .foregroundColor(AppColors.whiteText)
                    Text(request.symbolDisplayName)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                Spacer()
                Text(request.createdAtFormatted)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Text("Requested by @\(request.requester.username)")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            if let reason = request.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.symbolSheetGroupedPanelFill))
            }

            if canManage {
                HStack(spacing: 8) {
                    Button {
                        Task { await reviewRequest(request, action: "approved") }
                    } label: {
                        HStack(spacing: 6) {
                            if busy { ProgressView().scaleEffect(0.7).tint(AppColors.onAccentForeground) }
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.onAccentForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.statusPositive60))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)

                    Button {
                        Task { await reviewRequest(request, action: "rejected") }
                    } label: {
                        HStack(spacing: 6) {
                            if busy { ProgressView().scaleEffect(0.7) }
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.surfaceWhite06))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 0.8)
                )
        )
    }

    private var currentWatchlistContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Guild Watchlist")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)

                if guildSymbols.isEmpty {
                    UnifiedEmptyState(
                        icon: "list.bullet",
                        title: "No Guild Symbols",
                        subtitle: "Use search to add symbols to this watchlist"
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(guildSymbols) { symbol in
                            guildSymbolRow(symbol)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var searchContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                addSymbolSection
            }
            .padding(.vertical, 8)
        }
    }

    private var addSymbolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Symbols")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.greyText)

            UnifiedSearchBar(
                text: $searchText,
                placeholder: "Search symbols...",
                onTextChange: { query in
                    performSearch(query: query)
                }
            )

            if isSearching {
                ProgressView("Searching...")
                    .font(.caption)
            } else {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Browse global symbols")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                VStack(spacing: 6) {
                    ForEach(displayedSearchResults.prefix(20)) { symbol in
                        searchRow(symbol)
                    }
                }
            }
        }
    }

    private var displayedSearchResults: [RLTradingSymbolDTO] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? globalSymbols : searchResults
    }

    private func searchRow(_ symbol: RLTradingSymbolDTO) -> some View {
        let inGuild = guildSymbols.contains(where: { $0.id == symbol.id })
        let isPending = pendingSymbolIds.contains(symbol.id)
        let busy = processingSymbolIds.contains(symbol.id)

        return HStack(spacing: 10) {
            TradingSymbolIconView(
                symbol: symbol,
                size: 30,
                cornerRadiusRatio: 0.22,
                strokeOpacity: 0.16
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.ticker)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Text(symbol.displayName)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)

                FlowLayout(spacing: 6) {
                    Image(systemName: symbol.effectiveIsMarketOpen ? "circle.fill" : "moon.fill")
                        .font(.system(size: symbol.effectiveIsMarketOpen ? 6 : 8, weight: .semibold))
                        .foregroundColor(symbol.effectiveIsMarketOpen ? .green : AppColors.surfaceGray80)

                    Text(symbol.providerDisplayLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.greyText)

                    ForEach(symbol.activityBadgeValues, id: \.self) { badge in
                        watchlistActivityBadge(label: badge)
                    }
                }
            }
            Spacer()

            if inGuild {
                statusPill("In Guild", color: .blue)
            } else if isPending {
                statusPill("Requested", color: .orange)
            } else {
                Button {
                    Task { await addSymbolToGuild(symbol) }
                } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().scaleEffect(0.65).tint(AppColors.onAccentForeground) }
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.onAccentForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 0.5)
                )
        )
    }

    private func guildSymbolRow(_ symbol: RLTradingSymbolDTO) -> some View {
        let busy = processingSymbolIds.contains(symbol.id)
        return HStack(spacing: 10) {
            TradingSymbolIconView(
                symbol: symbol,
                size: 30,
                cornerRadiusRatio: 0.22,
                strokeOpacity: 0.16
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.ticker)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                Text(symbol.displayName)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)

                FlowLayout(spacing: 6) {
                    Image(systemName: symbol.effectiveIsMarketOpen ? "circle.fill" : "moon.fill")
                        .font(.system(size: symbol.effectiveIsMarketOpen ? 6 : 8, weight: .semibold))
                        .foregroundColor(symbol.effectiveIsMarketOpen ? .green : AppColors.surfaceGray80)

                    Text(symbol.providerDisplayLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.greyText)

                    ForEach(symbol.activityBadgeValues, id: \.self) { badge in
                        watchlistActivityBadge(label: badge)
                    }
                }
            }
            Spacer()
            if canManage {
                Button {
                    Task { await removeSymbolFromGuild(symbol) }
                } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().scaleEffect(0.65).tint(AppColors.onAccentForeground) }
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.statusNegative85)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.statusNegative15))
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 0.5)
                )
        )
    }

    private func statusPill(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.18)))
    }

    private func watchlistActivityBadge(label: String) -> some View {
        let color: Color
        let icon: String
        switch label.lowercased() {
        case "trending":
            color = .orange
            icon = "chart.line.uptrend.xyaxis"
        case "hot":
            color = .red
            icon = "flame.fill"
        case "new markers":
            color = .green
            icon = "sparkles"
        default:
            color = .gray
            icon = "circle.fill"
        }
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
        }
            .foregroundColor(AppColors.surfaceWhite95)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.45)))
    }

    @MainActor
    private func loadAll() async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let requestsTask = rlAppState.fetchGuildWatchlistRequests(status: "pending")
            async let watchlistTask = rlAppState.fetchGuildWatchlist(guildId: guildId)
            async let globalSymbolsTask = rlAppState.realApi.getGlobalSymbols(guildId: guildId, limit: 100)
            let (requestsResponse, watchlistResponse, globalSymbolsResponse) = try await (requestsTask, watchlistTask, globalSymbolsTask)
            pendingRequests = requestsResponse.requests
            guildSymbols = watchlistResponse.symbols.map { $0.symbol }
            globalSymbols = globalSymbolsResponse.symbols
            leftDrawerViewModel.guildTradingWatchlist = guildSymbols
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchResults = globalSymbols
            }
        } catch {
            // Errors are surfaced via RLAppState toasts.
        }
    }

    private func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = globalSymbols
            return
        }
        Task {
            isSearching = true
            defer { isSearching = false }
            do {
                let response = try await rlAppState.realApi.searchSymbols(query: trimmedQuery, limit: 30)
                await MainActor.run {
                    searchResults = response.results
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                }
            }
        }
    }

    private func reviewRequest(_ request: RLGuildWatchlistRequestResponseDTO, action: String) async {
        processingRequestIds.insert(request.id)
        defer { processingRequestIds.remove(request.id) }
        do {
            _ = try await rlAppState.reviewGuildWatchlistRequest(requestId: request.id, action: action)
            await loadAll()
            NotificationCenter.default.post(name: .guildWatchlistUpdated, object: nil)
        } catch {
            // Errors are surfaced via RLAppState toasts.
        }
    }

    private func addSymbolToGuild(_ symbol: RLTradingSymbolDTO) async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        processingSymbolIds.insert(symbol.id)
        defer { processingSymbolIds.remove(symbol.id) }
        do {
            _ = try await rlAppState.addToGuildWatchlist(guildId: guildId, symbolId: symbol.id)
            await loadAll()
            NotificationCenter.default.post(name: .guildWatchlistUpdated, object: nil)
        } catch {
            // Errors are surfaced via RLAppState toasts.
        }
    }

    private func removeSymbolFromGuild(_ symbol: RLTradingSymbolDTO) async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        processingSymbolIds.insert(symbol.id)
        defer { processingSymbolIds.remove(symbol.id) }
        do {
            try await rlAppState.removeFromGuildWatchlist(guildId: guildId, symbolId: symbol.id)
            await loadAll()
            NotificationCenter.default.post(name: .guildWatchlistUpdated, object: nil)
        } catch {
            // Errors are surfaced via RLAppState toasts.
        }
    }
}
