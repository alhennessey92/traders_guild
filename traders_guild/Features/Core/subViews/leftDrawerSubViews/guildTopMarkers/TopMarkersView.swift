//
//  TopMarkersView.swift
//  traders_guild
//
//  Left drawer marker activity feed.
//  Active | Today | This Week | This Month | Resolved
//  Guild | Friends | Personal
//

import SwiftUI

struct TopMarkersView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rlAppState: RLAppState

    @State private var selectedTopTab: RLMarkerActivityTopTab = .active
    @State private var selectedScope: RLMarkerActivityScope = .guild

    @State private var activitySnapshots: [RLMarkerActivityTopTab: MarkerActivityFeedSnapshot] = [:]
    @State private var symbolCache: [UUID: RLTradingSymbolDTO] = [:]
    @State private var cacheNamespace = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var loadError: String?
    @State private var likedMarkerId: UUID?

    var onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil

    private var reloadKey: String {
        let guild = rlAppState.currentGuild?.id.uuidString ?? "none"
        let user = rlAppState.currentUser?.id.uuidString ?? "none"
        return "\(guild)|\(user)"
    }

    private var visibleLoadKey: String {
        "\(reloadKey)|\(selectedTopTab.rawValue)"
    }

    private var selectedMarkers: [RLMarkerActivityItemDTO] {
        activitySnapshots[selectedTopTab]?.markersByScope[selectedScope] ?? []
    }

    private var currentTotalCount: Int {
        activitySnapshots[selectedTopTab]?.totalCountByScope[selectedScope] ?? selectedMarkers.count
    }

    var body: some View {
        VStack(spacing: 0) {
            UnifiedTabBar(
                selectedTab: $selectedTopTab,
                size: .compact,
                theme: .componentsTabs,
                countForTab: { tab in
                    activitySnapshots[tab]?.totalCountByScope[selectedScope] ?? 0
                },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            UnifiedTabBar(
                selectedTab: $selectedScope,
                size: .compact,
                theme: .subTab,
                countForTab: { scope in
                    activitySnapshots[selectedTopTab]?.totalCountByScope[scope] ?? 0
                },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

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

    @ViewBuilder
    private var content: some View {
        if isLoading && !hasLoaded {
            UnifiedLoadingState(message: "Loading marker activity...")
                .padding(.top, 40)
        } else if let loadError, selectedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "exclamationmark.triangle",
                title: "Unable to load marker activity",
                subtitle: loadError
            )
            .padding(.top, 36)
        } else if selectedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: emptyStateIcon,
                title: emptyStateTitle,
                subtitle: emptyStateSubtitle
            )
            .padding(.top, 36)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(selectedMarkers) { marker in
                    MarkerActivityCard(
                        marker: marker,
                        showMyBadge: marker.isCurrentUserMarker,
                        currentPrice: symbolCache[marker.symbolId]?.currentPrice,
                        likeAnimationMarkerId: likedMarkerId,
                        onLike: { handleLike(marker: marker) },
                        onTap: { handleMarkerTap(marker: marker) }
                    )
                }
            }
        }
    }

    private var summaryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(selectedTopTab.title) • \(selectedScope.title) • \(currentTotalCount) markers")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()
        }
    }

    private var emptyStateIcon: String {
        switch selectedTopTab {
        case .active: return "bolt"
        case .today: return "sun.max"
        case .thisWeek: return "calendar"
        case .thisMonth: return "calendar.badge.clock"
        case .resolved: return "checkmark.circle"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTopTab {
        case .active: return "No Active Setups"
        case .today: return "No Markers Today"
        case .thisWeek: return "No Markers This Week"
        case .thisMonth: return "No Markers This Month"
        case .resolved: return "No Resolved Setups"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedTopTab {
        case .active:
            return "\(selectedScope.title) tracked setup markers will appear here while they are being watched."
        case .resolved:
            return "\(selectedScope.title) setups that hit TP, SL, or expired will appear here."
        case .today, .thisWeek, .thisMonth:
            return "\(selectedScope.title) marker activity in this time window will appear here."
        }
    }

    private func loadActivity(forceRefresh: Bool) async {
        guard let guildId = rlAppState.currentGuild?.id else {
            await MainActor.run {
                activitySnapshots = [:]
                cacheNamespace = reloadKey
                hasLoaded = true
                loadError = "Select a guild to load marker activity."
                isLoading = false
            }
            return
        }

        if cacheNamespace != reloadKey {
            await MainActor.run {
                cacheNamespace = reloadKey
                activitySnapshots = [:]
                symbolCache = [:]
                hasLoaded = false
                loadError = nil
            }
        }

        let requestTab = selectedTopTab

        if !forceRefresh, activitySnapshots[requestTab] != nil, hasLoaded {
            return
        }

        await MainActor.run {
            isLoading = true
            if forceRefresh {
                loadError = nil
            }
        }

        do {
            let snapshot = try await MarkerActivityFeedLoader.loadTopTab(
                api: rlAppState.realApi,
                guildId: guildId,
                topTab: requestTab,
                scopes: Array(RLMarkerActivityScope.allCases),
                limit: 60
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                activitySnapshots[requestTab] = snapshot
                hasLoaded = true
                loadError = nil
                isLoading = false
            }

            await loadLiveSymbols(for: Array(snapshot.markersByScope.values.joined()))

            Task {
                await prefetchRemainingTabs(excluding: requestTab, guildId: guildId)
            }
        } catch {
            guard !isCancellationError(error) else { return }
            await MainActor.run {
                hasLoaded = true
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func prefetchRemainingTabs(
        excluding activeTab: RLMarkerActivityTopTab,
        guildId: UUID
    ) async {
        await withTaskGroup(of: (RLMarkerActivityTopTab, MarkerActivityFeedSnapshot?).self) { group in
            for tab in RLMarkerActivityTopTab.allCases where tab != activeTab && activitySnapshots[tab] == nil {
                group.addTask {
                    do {
                        let snapshot = try await MarkerActivityFeedLoader.loadTopTab(
                            api: rlAppState.realApi,
                            guildId: guildId,
                            topTab: tab,
                            scopes: Array(RLMarkerActivityScope.allCases),
                            limit: 60
                        )
                        return (tab, snapshot)
                    } catch {
                        return (tab, nil)
                    }
                }
            }

            for await (tab, snapshot) in group {
                guard let snapshot else { continue }
                await MainActor.run {
                    activitySnapshots[tab] = snapshot
                }
                await loadLiveSymbols(for: Array(snapshot.markersByScope.values.joined()))
            }
        }
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
                print("⚠️ Failed to toggle marker like: \(error)")
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
        for key in activitySnapshots.keys {
            guard let snapshot = activitySnapshots[key] else { continue }

            var markersByScope = snapshot.markersByScope
            for scope in markersByScope.keys {
                guard var markers = markersByScope[scope] else { continue }
                if let index = markers.firstIndex(where: { $0.id == markerId }) {
                    markers[index].isLikedByCurrentUser = isLiked
                    markers[index].likeCount = likeCount
                    markersByScope[scope] = markers
                }
            }

            activitySnapshots[key] = MarkerActivityFeedSnapshot(
                markersByScope: markersByScope,
                totalCountByScope: snapshot.totalCountByScope,
                lastUpdated: Date()
            )
        }
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
}

struct MarkerActivityCard: View {
    let marker: RLMarkerActivityItemDTO
    var showMyBadge: Bool = false
    var currentPrice: Double? = nil
    var likeAnimationMarkerId: UUID? = nil
    var onLike: (() -> Void)? = nil
    let onTap: () -> Void

    private var isLikeAnimating: Bool {
        likeAnimationMarkerId == marker.id
    }

    private var trackingState: RLTrackingState? {
        marker.trackingStateEnum
    }

    private var approachingStatus: MarkerPredictionProgressStatus? {
        guard marker.intentEnum == .setup,
              let setupSummary = marker.setupSummary,
              let trackingState,
              trackingState.isLive else { return nil }

        let status = MarkerPredictionProgress.status(
            entryPrice: setupSummary.entryPrice ?? marker.price,
            currentPrice: currentPrice,
            targetPrice: setupSummary.tpPrice,
            stopLossPrice: setupSummary.slPrice
        )
        return (status == .approachingTP || status == .approachingSL) ? status : nil
    }

    private var liveSetupMetrics: LiveSetupMetrics? {
        guard marker.intentEnum == .setup,
              let setupSummary = marker.setupSummary,
              let trackingState,
              trackingState.isLive,
              let stopLossPrice = setupSummary.slPrice,
              let targetPrice = setupSummary.tpPrice,
              let currentPrice else { return nil }

        let entryPrice = setupSummary.entryPrice ?? marker.price
        return LiveSetupMetrics.compute(
            entryPrice: entryPrice,
            stopLossPrice: stopLossPrice,
            targetPrice: targetPrice,
            currentPrice: currentPrice
        )
    }

    private var outcome: SetupOutcome? {
        guard marker.intentEnum == .setup,
              let trackingState,
              trackingState.isResolved else { return nil }

        return SetupOutcome(
            state: trackingState,
            resultType: marker.predictionResult?.resultType,
            triggerPrice: marker.predictionResult?.triggerPrice,
            triggeredAtFormatted: marker.predictionResult?.triggeredAtFormatted,
            pnl: marker.predictionResult?.pnl,
            isTracked: true,
            guildRepDelta: marker.predictionResult?.guildRepDelta,
            globalRepDelta: marker.predictionResult?.globalRepDelta
        )
    }

    private var shortTypeName: String {
        switch marker.intentEnum {
        case .analysis: return "Analysis"
        case .setup: return "Setup"
        case .alert: return "Alert"
        case .question: return "Question"
        case .poll: return "Poll"
        case .news: return "News"
        case .reaction: return "React"
        case .personal: return "Private"
        }
    }

    var body: some View {
        UnifiedContentCard(onTap: onTap) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 1) {
                        UnifiedMarkerBadge(intent: marker.intentEnum, sizeToken: .small)
                        Text(shortTypeName)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(marker.intentEnum.color.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(width: 34)
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if let brandColor = marker.symbolBrandColor {
                                Circle()
                                    .fill(Color(hex: brandColor) ?? .blue)
                                    .frame(width: 6, height: 6)
                            }
                            Text(marker.symbolTicker)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.whiteText)

                            if showMyBadge {
                                Text("YOU")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AppColors.statusInfo60))
                            }

                            Spacer()

                            if let onLike {
                                Button(action: onLike) {
                                    HStack(spacing: 2) {
                                        Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                                            .font(.system(size: 10))
                                            .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
                                        Text("\(marker.likeCount)")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(
                                        marker.isLikedByCurrentUser
                                            ? AppColors.markerHeartTint
                                            : AppColors.markerHeartMuted
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 2) {
                                    Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                                        .font(.system(size: 10))
                                    Text("\(marker.likeCount)")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(
                                    marker.isLikedByCurrentUser
                                        ? AppColors.markerHeartTint
                                        : AppColors.markerHeartMuted
                                )
                            }
                        }

                        if let note = marker.notePreview, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.whiteText.opacity(0.75))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 4)
                        }

                        HStack(spacing: 6) {
                            MarkerActivityMetaChip(
                                icon: "clock",
                                text: marker.timeframe.uppercased(),
                                tint: AppColors.whiteText.opacity(0.85),
                                background: AppColors.whiteText.opacity(0.10)
                            )

                            if let trackingState {
                                TrackingStatePill(state: trackingState, size: .compact)
                            }

                            if let approachingStatus {
                                ApproachingLevelChip(status: approachingStatus)
                            }

                            Spacer()
                        }
                        .padding(.top, 2)

                        if let outcome {
                            HStack(spacing: 6) {
                                if let pnl = outcome.pnl {
                                    MarkerActivityMetaChip(
                                        icon: outcome.isWin ? "arrow.up.right" : "arrow.down.right",
                                        text: formatPnL(pnl),
                                        tint: outcomeTint(outcome),
                                        background: outcomeTint(outcome).opacity(0.15)
                                    )
                                } else if outcome.isExpired {
                                    MarkerActivityMetaChip(
                                        icon: "clock.badge.xmark",
                                        text: "No score impact",
                                        tint: AppColors.surfaceGray90,
                                        background: AppColors.surfaceWhite08
                                    )
                                }
                            }
                            .padding(.top, 2)
                        } else if let liveSetupMetrics {
                            VStack(alignment: .leading, spacing: 8) {
                                MarkerActivityMetaChip(
                                    icon: liveSetupMetrics.isMovingTowardTarget ? "waveform.path.ecg" : "arrow.down.right",
                                    text: "Live \(formatPnL(liveSetupMetrics.currentPnL))",
                                    tint: liveSetupMetrics.isMovingTowardTarget
                                        ? AppColors.statusInfo85
                                        : AppColors.statusNegative70,
                                    background: liveSetupMetrics.isMovingTowardTarget
                                        ? AppColors.statusInfo15
                                        : AppColors.statusNegative15
                                )

                                LiveSetupProgressStrip(
                                    metrics: liveSetupMetrics,
                                    formatPrice: formatPrice(_:)
                                )
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 14)

                UnifiedAuthorFooter(
                    username: marker.authorUsername,
                    isOnline: marker.authorIsOnline,
                    role: RLMemberRole(from: marker.authorRole),
                    reputation: marker.authorReputation,
                    timeText: marker.activityTimestampFormatted,
                    showOnlineStatus: false
                )
            }
        }
    }

    private func outcomeTint(_ outcome: SetupOutcome) -> Color {
        if outcome.isWin { return AppColors.statusPositive70 }
        if outcome.isLoss { return AppColors.statusNegative70 }
        return AppColors.surfaceGray90
    }

    private func formatPnL(_ pnl: Double) -> String {
        String(format: "%@%.2f%%", pnl >= 0 ? "+" : "", pnl)
    }

    private func formatPrice(_ price: Double) -> String {
        let absolute = abs(price)
        if absolute >= 1000 {
            return String(format: "%.2f", price)
        }
        if absolute >= 1 {
            return String(format: "%.4f", price)
        }
        return String(format: "%.6f", price)
    }
}

// LiveSetupMetrics is defined in MarkerPredictionProgress.swift

private struct LiveSetupProgressStrip: View {
    let metrics: LiveSetupMetrics
    let formatPrice: (Double) -> String

    private var targetTint: Color { AppColors.statusInfo85 }
    private var stopTint: Color { AppColors.statusNegative70 }
    private var swingTint: Color { metrics.isMovingTowardTarget ? targetTint : stopTint }

    private var entryPosition: CGFloat {
        CGFloat(min(max(metrics.entryPosition, 0), 1))
    }

    private var currentPosition: CGFloat {
        CGFloat(min(max(metrics.currentPosition, 0), 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let safeWidth = max(width, 1)
                let entryX = safeWidth * entryPosition
                let currentX = safeWidth * currentPosition
                let swingStart = min(entryX, currentX)
                let swingWidth = max(abs(currentX - entryX), 2)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.surfaceWhite08)

                    HStack(spacing: 0) {
                        if metrics.isLong {
                            Rectangle()
                                .fill(stopTint.opacity(0.35))
                                .frame(width: entryX)
                            Rectangle()
                                .fill(targetTint.opacity(0.35))
                        } else {
                            Rectangle()
                                .fill(targetTint.opacity(0.35))
                                .frame(width: entryX)
                            Rectangle()
                                .fill(stopTint.opacity(0.35))
                        }
                    }
                    .clipShape(Capsule())

                    Capsule()
                        .fill(swingTint)
                        .frame(width: swingWidth)
                        .offset(x: swingStart)

                    Capsule()
                        .fill(AppColors.surfaceWhite85.opacity(0.65))
                        .frame(width: 2)
                        .offset(x: max(min(entryX - 1, safeWidth - 2), 0))

                    Circle()
                        .fill(swingTint)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(AppColors.systemBlack.opacity(0.55), lineWidth: 2)
                        )
                        .offset(x: max(min(currentX - 5, safeWidth - 10), 0), y: -1)
                }
            }
            .frame(height: 8)

            HStack {
                Text("SL \(formatPrice(metrics.stopLossPrice))")
                    .foregroundColor(stopTint)

                Spacer()

                Text("ENTRY \(formatPrice(metrics.entryPrice))")
                    .foregroundColor(AppColors.surfaceWhite70)

                Spacer()

                Text("TP \(formatPrice(metrics.targetPrice))")
                    .foregroundColor(targetTint)
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
        }
    }
}

struct MarkerActivityMetaChip: View {
    let icon: String
    let text: String
    let tint: Color
    let background: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(background)
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
