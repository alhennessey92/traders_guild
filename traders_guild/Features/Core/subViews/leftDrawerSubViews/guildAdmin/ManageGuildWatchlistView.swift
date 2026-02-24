//
//  ManageGuildWatchlistView.swift
//  traders_guild
//

import SwiftUI

private enum GuildWatchlistAdminTab: String, CaseIterable {
    case requests = "Requests"
    case current = "Current"
}

struct ManageGuildWatchlistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    @State private var selectedTab: GuildWatchlistAdminTab = .requests
    @State private var pendingRequests: [RLGuildWatchlistRequestResponseDTO] = []
    @State private var guildSymbols: [RLTradingSymbolDTO] = []

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
            VStack(alignment: .leading, spacing: 12) {
                header
                tabBar
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 30)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .onAppear {
            Task {
                await loadAll()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            UnifiedIconBadge(
                icon: "list.bullet.rectangle",
                color: .blue,
                size: 44,
                iconSize: 20,
                backgroundOpacity: 0.2
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Guild Watchlist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Review symbol requests and manage guild symbols")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(GuildWatchlistAdminTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                        if tab == .requests && !pendingRequests.isEmpty {
                            Text("\(pendingRequests.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.orange))
                        }
                    }
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(selectedTab == tab ? Color.accentColor : AppColors.whiteText.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
            Button("Refresh") {
                Task { await loadAll() }
            }
            .font(.caption)
            .disabled(isLoading)
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
            .frame(maxWidth: .infinity)
        } else {
            switch selectedTab {
            case .requests:
                requestsContent
            case .current:
                currentWatchlistContent
            }
        }
    }

    private var requestsContent: some View {
        Group {
            if pendingRequests.isEmpty {
                UnifiedEmptyState(
                    icon: "checkmark.seal",
                    title: "No Pending Requests",
                    subtitle: "All watchlist requests are up to date"
                )
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.symbolTicker)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(request.symbolDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(request.createdAtFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text("Requested by @\(request.requester.username)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let reason = request.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.whiteText.opacity(0.05)))
            }

            if canManage {
                HStack(spacing: 8) {
                    Button {
                        Task { await reviewRequest(request, action: "approved") }
                    } label: {
                        HStack(spacing: 6) {
                            if busy { ProgressView().scaleEffect(0.7).tint(.white) }
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
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
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .controlSize(.small)
                    .disabled(busy)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.whiteText.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var currentWatchlistContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if canManage {
                    addSymbolSection
                }

                Text("Current Guild Watchlist")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

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

    private var addSymbolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Symbol")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TextField("Search symbols...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { query in
                    performSearch(query: query)
                }

            if isSearching {
                ProgressView("Searching...")
                    .font(.caption)
            } else if !searchText.isEmpty {
                VStack(spacing: 6) {
                    ForEach(searchResults.prefix(10)) { symbol in
                        searchRow(symbol)
                    }
                }
            }
        }
    }

    private func searchRow(_ symbol: RLTradingSymbolDTO) -> some View {
        let inGuild = guildSymbols.contains(where: { $0.id == symbol.id })
        let isPending = pendingSymbolIds.contains(symbol.id)
        let busy = processingSymbolIds.contains(symbol.id)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.ticker)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(symbol.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                        if busy { ProgressView().scaleEffect(0.65).tint(.white) }
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(busy)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.whiteText.opacity(0.05)))
    }

    private func guildSymbolRow(_ symbol: RLTradingSymbolDTO) -> some View {
        let busy = processingSymbolIds.contains(symbol.id)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol.ticker)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(symbol.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if canManage {
                Button {
                    Task { await removeSymbolFromGuild(symbol) }
                } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().scaleEffect(0.65).tint(.white) }
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(busy)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.whiteText.opacity(0.05)))
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

    @MainActor
    private func loadAll() async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let requestsTask = rlAppState.fetchGuildWatchlistRequests(status: "pending")
            async let watchlistTask = rlAppState.fetchGuildWatchlist(guildId: guildId)
            let (requestsResponse, watchlistResponse) = try await (requestsTask, watchlistTask)
            pendingRequests = requestsResponse.requests
            guildSymbols = watchlistResponse.symbols.map { $0.symbol }
            leftDrawerViewModel.guildTradingWatchlist = guildSymbols
        } catch {
            // Errors are surfaced via RLAppState toasts.
        }
    }

    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        Task {
            isSearching = true
            defer { isSearching = false }
            do {
                let response = try await rlAppState.realApi.searchSymbols(query: query, limit: 30)
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
