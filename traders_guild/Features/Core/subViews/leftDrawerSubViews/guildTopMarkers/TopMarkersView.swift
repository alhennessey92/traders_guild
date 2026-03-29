//
//  TopMarkersView.swift
//  traders_guild
//
//  Left drawer marker activity feed.
//  Live Feed | Setups | By Symbol | All
//  Scope via inline pill toggle (Everyone / Friends / Mine)
//

import SwiftUI

private struct TopMarkerSetupCacheEntry {
    let live: [RLMarkerActivityItemDTO]
    let resolved: [RLMarkerActivityItemDTO]
}

struct TopMarkersView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rlAppState: RLAppState

    @State private var selectedTab: DrawerMarkerTab = .liveFeed
    @State private var selectedScope: DrawerScopeToggle = .everyone

    @State private var recentMarkers: [RLMarkerActivityItemDTO] = []
    @State private var archiveMarkers: [RLMarkerActivityItemDTO] = []
    @State private var setupsLiveMarkers: [RLMarkerActivityItemDTO] = []
    @State private var setupsResolvedMarkers: [RLMarkerActivityItemDTO] = []

    @State private var recentCache: [String: [RLMarkerActivityItemDTO]] = [:]
    @State private var archiveCache: [String: [RLMarkerActivityItemDTO]] = [:]
    @State private var setupsCache: [String: TopMarkerSetupCacheEntry] = [:]

    @State private var symbolCache: [UUID: RLTradingSymbolDTO] = [:]
    @State private var cacheNamespace = ""
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var likedMarkerId: UUID?
    @State private var activeLoadRequestId = 0

    var onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil

    private var reloadKey: String {
        let guild = rlAppState.currentGuild?.id.uuidString ?? "none"
        let user = rlAppState.currentUser?.id.uuidString ?? "none"
        return "\(guild)|\(user)"
    }

    private var visibleLoadKey: String {
        "\(reloadKey)|\(selectedTab.rawValue)|\(selectedScope.rawValue)"
    }

    private var currentTotalCount: Int {
        switch selectedTab {
        case .liveFeed:
            return recentMarkers.count
        case .setups:
            return setupsLiveMarkers.count + setupsResolvedMarkers.count
        case .bySymbol, .all:
            return archiveMarkers.count
        }
    }

    private var symbolGroups: [MarkerSymbolGroup] {
        MarkerActivityNavigation.symbolGroups(from: archiveMarkers)
    }

    var body: some View {
        VStack(spacing: 0) {
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .markerNavigation,
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            summaryBadge
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    content
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .refreshable {
                await loadActivity(forceRefresh: true)
            }
        }
        .task(id: visibleLoadKey) {
            await loadActivity(forceRefresh: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .markerCreatedSuccessfully)) { _ in
            Task { await loadActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .markerActivityDidChange)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reputationDidUpdate)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accuracyDidUpdate)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadActivity(forceRefresh: true) }
        }
    }

    private var summaryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(selectedTab.title) \u{2022} \(selectedScope.rawValue) \u{2022} \(currentTotalCount) markers")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()

            drawerScopePill
        }
    }

    private var drawerScopePill: some View {
        HStack(spacing: 0) {
            ForEach(DrawerScopeToggle.allCases, id: \.self) { toggle in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedScope = toggle
                    }
                } label: {
                    Text(toggle.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(selectedScope == toggle ? .white : AppColors.surfaceWhite60)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            selectedScope == toggle
                                ? Capsule().fill(AppColors.statusInfo60)
                                : Capsule().fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Capsule().fill(AppColors.surfaceWhite08)
        )
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && recentMarkers.isEmpty && archiveMarkers.isEmpty && setupsLiveMarkers.isEmpty && setupsResolvedMarkers.isEmpty {
            UnifiedLoadingState(message: "Loading marker activity...")
                .padding(.top, 40)
        } else if let loadError, recentMarkers.isEmpty && archiveMarkers.isEmpty && setupsLiveMarkers.isEmpty && setupsResolvedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "exclamationmark.triangle",
                title: "Unable to load marker activity",
                subtitle: loadError
            )
            .padding(.top, 36)
        } else {
            switch selectedTab {
            case .liveFeed:
                liveFeedContent
            case .setups:
                setupsContent
            case .bySymbol:
                bySymbolContent
            case .all:
                allMarkersContent
            }
        }
    }

    @ViewBuilder
    private var liveFeedContent: some View {
        if recentMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "bolt.horizontal",
                title: "No Recent Activity",
                subtitle: "Recent \(selectedScope.rawValue.lowercased()) marker activity will appear here."
            )
            .padding(.top, 36)
        } else {
            markerList(recentMarkers)
        }
    }

    @ViewBuilder
    private var setupsContent: some View {
        if setupsLiveMarkers.isEmpty && setupsResolvedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "target",
                title: "No Setups",
                subtitle: "\(selectedScope.rawValue) tracked setup markers will appear here."
            )
            .padding(.top, 36)
        } else {
            VStack(spacing: 12) {
                if !setupsLiveMarkers.isEmpty {
                    UnifiedDisclosureGroup(
                        title: "Live",
                        count: setupsLiveMarkers.count,
                        icon: "bolt.fill",
                        iconColor: AppColors.statusPositive70,
                        isExpandedByDefault: true
                    ) {
                        markerList(setupsLiveMarkers)
                    }
                }

                if !setupsResolvedMarkers.isEmpty {
                    UnifiedDisclosureGroup(
                        title: "Resolved",
                        count: setupsResolvedMarkers.count,
                        icon: "checkmark.circle.fill",
                        iconColor: AppColors.surfaceWhite60,
                        isExpandedByDefault: false
                    ) {
                        markerList(setupsResolvedMarkers)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bySymbolContent: some View {
        if symbolGroups.isEmpty {
            UnifiedEmptyState(
                icon: "list.bullet.rectangle",
                title: "No Markers by Symbol",
                subtitle: "\(selectedScope.rawValue) marker activity grouped by symbol will appear here."
            )
            .padding(.top, 36)
        } else {
            VStack(spacing: 8) {
                ForEach(symbolGroups) { symbolGroup in
                    UnifiedDisclosureGroup(
                        title: symbolGroup.ticker,
                        count: symbolGroup.count,
                        icon: "chart.xyaxis.line",
                        iconColor: colorForSymbolGroup(symbolGroup),
                        isExpandedByDefault: false
                    ) {
                        markerList(symbolGroup.markers)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var allMarkersContent: some View {
        if archiveMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "square.grid.2x2",
                title: "No Markers",
                subtitle: "\(selectedScope.rawValue) marker archive will appear here."
            )
            .padding(.top, 36)
        } else {
            markerList(archiveMarkers)
        }
    }

    private func markerList(_ markers: [RLMarkerActivityItemDTO]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(markers) { marker in
                MarkerListItem(
                    marker: marker,
                    style: .capsule,
                    showMyBadge: marker.isCurrentUserMarker,
                    currentPrice: symbolCache[marker.symbolId]?.currentPrice,
                    likeAnimationMarkerId: likedMarkerId,
                    onLike: { handleLike(marker: marker) },
                    onTap: { handleMarkerTap(marker: marker) }
                )
            }
        }
    }

    private func loadActivity(forceRefresh: Bool) async {
        let requestId = await MainActor.run {
            activeLoadRequestId += 1
            return activeLoadRequestId
        }

        guard let guildId = rlAppState.currentGuild?.id else {
            applyIfCurrentRequest(requestId) {
                resetAllState()
                cacheNamespace = reloadKey
                loadError = "Select a guild to load marker activity."
                isLoading = false
            }
            return
        }

        if cacheNamespace != reloadKey {
            applyIfCurrentRequest(requestId) {
                cacheNamespace = reloadKey
                resetAllState()
                symbolCache = [:]
                loadError = nil
            }
        }

        let requestTab = selectedTab
        let scope = selectedScope.apiScope
        let loadKey = selectedScope.rawValue

        if !forceRefresh {
            switch requestTab {
            case .liveFeed:
                if let cachedMarkers = recentCache[loadKey] {
                    applyIfCurrentRequest(requestId) {
                        recentMarkers = cachedMarkers
                        loadError = nil
                        isLoading = false
                    }
                    await loadLiveSymbols(for: cachedMarkers)
                    return
                }
            case .setups:
                if let cachedEntry = setupsCache[loadKey] {
                    applyIfCurrentRequest(requestId) {
                        setupsLiveMarkers = cachedEntry.live
                        setupsResolvedMarkers = cachedEntry.resolved
                        loadError = nil
                        isLoading = false
                    }
                    await loadLiveSymbols(for: cachedEntry.live + cachedEntry.resolved)
                    return
                }
            case .bySymbol, .all:
                if let cachedMarkers = archiveCache[loadKey] {
                    applyIfCurrentRequest(requestId) {
                        archiveMarkers = cachedMarkers
                        loadError = nil
                        isLoading = false
                    }
                    await loadLiveSymbols(for: cachedMarkers)
                    return
                }
            }
        }

        applyIfCurrentRequest(requestId) {
            isLoading = true
            loadError = nil
        }

        do {
            switch requestTab {
            case .liveFeed:
                let markers = try await loadMarkers(
                    guildId: guildId,
                    scope: scope,
                    loadMode: .recentFeed
                )

                guard isCurrentRequest(requestId) else { return }

                applyIfCurrentRequest(requestId) {
                    recentCache[loadKey] = markers
                    recentMarkers = markers
                    loadError = nil
                    isLoading = false
                }

                await loadLiveSymbols(for: markers)

            case .setups:
                async let liveMarkers = loadMarkers(
                    guildId: guildId,
                    scope: scope,
                    loadMode: .setupsLive
                )
                async let resolvedMarkers = loadMarkers(
                    guildId: guildId,
                    scope: scope,
                    loadMode: .setupsResolved
                )

                let (live, resolved) = try await (liveMarkers, resolvedMarkers)
                guard !Task.isCancelled else { return }

                guard isCurrentRequest(requestId) else { return }

                applyIfCurrentRequest(requestId) {
                    setupsCache[loadKey] = TopMarkerSetupCacheEntry(live: live, resolved: resolved)
                    setupsLiveMarkers = live
                    setupsResolvedMarkers = resolved
                    loadError = nil
                    isLoading = false
                }

                await loadLiveSymbols(for: live + resolved)

            case .bySymbol, .all:
                let markers = try await loadMarkers(
                    guildId: guildId,
                    scope: scope,
                    loadMode: .archive
                )

                guard isCurrentRequest(requestId) else { return }

                applyIfCurrentRequest(requestId) {
                    archiveCache[loadKey] = markers
                    archiveMarkers = markers
                    loadError = nil
                    isLoading = false
                }

                await loadLiveSymbols(for: markers)
            }
        } catch {
            guard !isCancellationError(error) else { return }
            applyIfCurrentRequest(requestId) {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadMarkers(
        guildId: UUID,
        scope: RLMarkerActivityScope,
        loadMode: MarkerActivityListLoadMode
    ) async throws -> [RLMarkerActivityItemDTO] {
        let snapshot = try await MarkerActivityFeedLoader.loadForScope(
            api: rlAppState.realApi,
            guildId: guildId,
            scope: scope,
            state: loadMode.state,
            limit: loadMode.limit,
            fetchAllPages: loadMode.fetchAllPages
        )

        guard !Task.isCancelled else { return [] }
        return MarkerActivityNavigation.sortedByActivity(snapshot.markersByScope[scope] ?? [])
    }

    private func loadLiveSymbols(for markers: [RLMarkerActivityItemDTO], forceReload: Bool = false) async {
        let uniqueSymbolIds = Set(markers.map(\.symbolId))
        let symbolIdsToFetch = uniqueSymbolIds.filter { forceReload || symbolCache[$0] == nil }
        guard !symbolIdsToFetch.isEmpty else { return }

        var updates: [UUID: RLTradingSymbolDTO] = [:]
        await withTaskGroup(of: (UUID, RLTradingSymbolDTO?).self) { group in
            for symbolId in symbolIdsToFetch {
                group.addTask {
                    let symbol = try? await rlAppState.realApi.getSymbol(symbolId: symbolId)
                    return (symbolId, symbol)
                }
            }

            for await (symbolId, symbol) in group {
                if let symbol {
                    updates[symbolId] = symbol
                }
            }
        }

        guard !updates.isEmpty else { return }
        await MainActor.run {
            symbolCache.merge(updates) { _, newValue in newValue }
        }
    }

    private func handleLike(marker: RLMarkerActivityItemDTO) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            likedMarkerId = marker.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            likedMarkerId = nil
        }

        Task {
            guard let guildId = rlAppState.currentGuild?.id else { return }
            do {
                let result = try await rlAppState.realApi.toggleMarkerLike(guildId: guildId, markerId: marker.id)
                await MainActor.run {
                    updateMarkerLike(markerId: marker.id, isLiked: result.isLiked, likeCount: result.likeCount)
                }
            } catch {
                print("Failed to toggle marker like: \(error)")
            }
        }
    }

    private func handleMarkerTap(marker: RLMarkerActivityItemDTO) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let topMarker = marker.asTopMarkerDTO()
        if let onNavigateToMarker {
            onNavigateToMarker(topMarker)
        } else {
            leftDrawerViewModel.requestNavigationToMarker(topMarker)
        }
    }

    private func updateMarkerLike(markerId: UUID, isLiked: Bool, likeCount: Int) {
        updateLike(in: &recentMarkers, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
        updateLike(in: &archiveMarkers, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
        updateLike(in: &setupsLiveMarkers, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
        updateLike(in: &setupsResolvedMarkers, markerId: markerId, isLiked: isLiked, likeCount: likeCount)

        for key in recentCache.keys {
            guard var markers = recentCache[key] else { continue }
            updateLike(in: &markers, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
            recentCache[key] = markers
        }

        for key in archiveCache.keys {
            guard var markers = archiveCache[key] else { continue }
            updateLike(in: &markers, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
            archiveCache[key] = markers
        }

        for key in setupsCache.keys {
            guard var entry = setupsCache[key] else { continue }
            var live = entry.live
            var resolved = entry.resolved
            updateLike(in: &live, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
            updateLike(in: &resolved, markerId: markerId, isLiked: isLiked, likeCount: likeCount)
            entry = TopMarkerSetupCacheEntry(live: live, resolved: resolved)
            setupsCache[key] = entry
        }
    }

    private func updateLike(
        in markers: inout [RLMarkerActivityItemDTO],
        markerId: UUID,
        isLiked: Bool,
        likeCount: Int
    ) {
        guard let index = markers.firstIndex(where: { $0.id == markerId }) else { return }
        markers[index].isLikedByCurrentUser = isLiked
        markers[index].likeCount = likeCount
    }

    private func colorForSymbolGroup(_ group: MarkerSymbolGroup) -> Color {
        if let brandColor = group.brandColor,
           let color = Color(hex: brandColor) {
            return color
        }
        return AppColors.statusInfo80
    }

    private func resetAllState() {
        recentMarkers = []
        archiveMarkers = []
        setupsLiveMarkers = []
        setupsResolvedMarkers = []
        recentCache = [:]
        archiveCache = [:]
        setupsCache = [:]
    }

    private func shouldRefresh(for notification: Notification) -> Bool {
        guard let currentGuildId = rlAppState.currentGuild?.id else { return true }
        guard let rawGuildId = notification.userInfo?["guildId"] else { return true }

        if let guildId = rawGuildId as? UUID {
            return guildId == currentGuildId
        }

        if let guildIdString = rawGuildId as? String,
           let guildId = UUID(uuidString: guildIdString) {
            return guildId == currentGuildId
        }

        return true
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    @MainActor
    private func applyIfCurrentRequest(_ requestId: Int, updates: () -> Void) {
        guard requestId == activeLoadRequestId else { return }
        updates()
    }

    @MainActor
    private func isCurrentRequest(_ requestId: Int) -> Bool {
        requestId == activeLoadRequestId
    }
}
