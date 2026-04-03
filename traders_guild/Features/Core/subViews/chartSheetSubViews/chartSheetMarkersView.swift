//
//  chartSheetMarkersView.swift
//  traders_guild
//
//  Chart bottom-sheet marker management:
//  Add | Markers | Analysis
//  Markers -> Live Feed | Setups | By Timeframe | All
//  Scope via inline pill toggle (Everyone / Friends)
//

import SwiftUI

enum MarkerSheetPrimaryTab: String, CaseIterable, UnifiedTabItem {
    case add = "Add"
    case markers = "Markers"
    case analysis = "Analysis"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .add: return "plus.circle.fill"
        case .markers: return "target"
        case .analysis: return "chart.bar.xaxis"
        }
    }
}

private struct ChartMarkerSetupCacheEntry {
    let live: [RLMarkerActivityItemDTO]
    let resolved: [RLMarkerActivityItemDTO]
}

struct chartSheetMarkersView: View {
    @EnvironmentObject private var rlAppState: RLAppState

    @ObservedObject var chartViewModel: ChartViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel

    var onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil
    var onMarkerSelection: (() -> Void)? = nil

    @State private var selectedPrimaryTab: MarkerSheetPrimaryTab = .add
    @State private var selectedSubTab: MarkerSheetSubTab = .liveFeed
    @State private var selectedScopeToggle: MarkerScopeToggle = .everyone

    @State private var recentMarkers: [RLMarkerActivityItemDTO] = []
    @State private var archiveMarkers: [RLMarkerActivityItemDTO] = []
    @State private var setupsLiveMarkers: [RLMarkerActivityItemDTO] = []
    @State private var setupsResolvedMarkers: [RLMarkerActivityItemDTO] = []

    @State private var recentCache: [String: [RLMarkerActivityItemDTO]] = [:]
    @State private var archiveCache: [String: [RLMarkerActivityItemDTO]] = [:]
    @State private var setupsCache: [String: ChartMarkerSetupCacheEntry] = [:]

    @State private var analysisSnapshot: MarkerActivityFeedSnapshot?

    @State private var cacheNamespace = ""
    @State private var liveSymbol: RLTradingSymbolDTO?

    @State private var isLoadingActivity = false
    @State private var isRefreshingActivity = false
    @State private var activityLoadError: String?
    @State private var showMarkerSettingsSheet = false
    @State private var likedMarkerId: UUID?

    private var reloadKey: String {
        let symbol = chartViewModel.currentSymbol?.id.uuidString ?? "none"
        let guild = rlAppState.currentGuild?.id.uuidString ?? "none"
        let user = rlAppState.currentUser?.id.uuidString ?? "none"
        return "\(symbol)|\(guild)|\(user)"
    }

    private var visibleLoadKey: String {
        "\(reloadKey)|\(selectedPrimaryTab.rawValue)|\(selectedSubTab.rawValue)|\(selectedScopeToggle.rawValue)"
    }

    private var currentSymbolLabel: String {
        chartViewModel.currentSymbol?.ticker ?? "Symbol"
    }

    private var activeSymbolPrice: Double? {
        liveSymbol?.currentPrice ?? chartViewModel.currentSymbol?.currentPrice
    }

    private var selectedFlatMarkers: [RLMarkerActivityItemDTO] {
        switch selectedSubTab {
        case .liveFeed:
            return recentMarkers
        case .all:
            return archiveMarkers
        case .setups, .byTimeframe:
            return []
        }
    }

    private var timeframeGroups: [MarkerTimeframeGroup] {
        MarkerActivityNavigation.timeframeGroups(
            from: archiveMarkers,
            currentTimeframe: chartViewModel.currentTimeframe
        )
    }

    private var analysisMarkers: [RLMarkerActivityItemDTO] {
        analysisSnapshot?.markersByScope[.guild] ?? []
    }

    private var addMarkerIntents: [RLMarkerIntent] {
        let allIntents = RLMarkerIntent.allCases
        guard let setupIndex = allIntents.firstIndex(of: .setup) else {
            return allIntents
        }

        var orderedIntents = allIntents
        let setupIntent = orderedIntents.remove(at: setupIndex)
        orderedIntents.insert(setupIntent, at: 0)
        return orderedIntents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            UnifiedTabBar(
                selectedTab: $selectedPrimaryTab,
                size: .compact,
                theme: .markerPrimary,
                spacing: 6
            )

            switch selectedPrimaryTab {
            case .add:
                EmptyView()
            case .markers:
                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .compact,
                    theme: .markerNavigation,
                    spacing: 6
                )

                markersSummaryBadge
            case .analysis:
                analysisSummaryBadge
            }

            content

            if let activityLoadError,
               !activityLoadError.isEmpty,
               selectedPrimaryTab != .add,
               selectedPrimaryTab == .analysis ? analysisMarkers.isEmpty : visibleMarkersAreEmpty {
                errorBanner(activityLoadError)
            }
        }
        .padding(.top, 15)
        .task(id: visibleLoadKey) {
            await loadMarkerActivity(forceRefresh: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .markerCreatedSuccessfully)) { _ in
            Task { await loadMarkerActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .markerActivityDidChange)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadMarkerActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reputationDidUpdate)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadMarkerActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .accuracyDidUpdate)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadMarkerActivity(forceRefresh: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard shouldRefresh(for: notification) else { return }
            Task { await loadMarkerActivity(forceRefresh: true) }
        }
        .sheet(isPresented: $showMarkerSettingsSheet) {
            if let markerManager = chartViewModel.markerManager {
                MarkerFilterSettingsSheet(
                    markerManager: markerManager,
                    isPresented: $showMarkerSettingsSheet
                )
            } else {
                NavigationStack {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.statusWarning90)

                        Text("Marker settings are unavailable right now.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)

                        Text("Try again after the chart marker manager is ready.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(AppColors.systemBlack.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            SheetCloseButton(action: {
                                showMarkerSettingsSheet = false
                            })
                        }
                    }
                }
                .presentationDetents([.fraction(0.35)])
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.statusInfo22.opacity(0.9))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "target")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.statusInfo95)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Markers")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                Text(subtitleForCurrentTab)
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if selectedPrimaryTab != .add {
                    Button {
                        Task { await loadMarkerActivity(forceRefresh: true) }
                    } label: {
                        if isRefreshingActivity {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.surfaceWhite85)
                                .frame(width: 34, height: 34)
                                .background(AppColors.surfaceWhite08)
                                .clipShape(Circle())
                        }
                    }
                    .disabled(isRefreshingActivity || isLoadingActivity)
                }

                MarkerSettingsButton {
                    showMarkerSettingsSheet = true
                }
                .disabled(chartViewModel.markerManager == nil)
                .opacity(chartViewModel.markerManager == nil ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.statusInfo95.opacity(0.22),
                            AppColors.statusInfo95.opacity(0.12),
                            AppColors.whiteText.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.statusInfo95.opacity(0.34), lineWidth: 1)
                )
        )
    }

    private var subtitleForCurrentTab: String {
        switch selectedPrimaryTab {
        case .add:
            return "Select a marker type to begin placement on the chart."
        case .markers:
            return "Browse recent, grouped, and archived marker activity for \(currentSymbolLabel)."
        case .analysis:
            return "See one universal analysis view for all marker activity on \(currentSymbolLabel)."
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        switch selectedPrimaryTab {
        case .add:
            addContent
        case .markers:
            markersContent
        case .analysis:
            analysisContent
        }
    }

    // MARK: - Add Tab (flat list of all intents)

    private var addContent: some View {
        VStack(spacing: 8) {
            ForEach(addMarkerIntents, id: \.self) { intent in
                if intent == .setup {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(AppColors.statusWarning90)
                            .font(.caption)
                        Text("Prediction markers affect your accuracy, and TP results also affect reputation. Set entry, SL, and TP when prompted.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                }

                MarkerPlacementOptionRow(
                    intent: intent,
                    isActive: isMarkerPlacementActive(for: intent),
                    onToggle: { togglePlacement(for: intent) }
                )
            }
        }
    }

    // MARK: - Markers Tab

    @ViewBuilder
    private var markersContent: some View {
        if selectedSubTab == .setups {
            setupsContent
        } else if selectedSubTab == .byTimeframe {
            timeframeContent
        } else if isLoadingActivity && selectedFlatMarkers.isEmpty {
            UnifiedLoadingState(message: "Loading marker activity...")
                .padding(.top, 24)
        } else if selectedFlatMarkers.isEmpty {
            UnifiedEmptyState(
                icon: emptyStateIcon,
                title: emptyStateTitle,
                subtitle: emptyStateSubtitle
            )
            .padding(.top, 20)
        } else {
            markerList(selectedFlatMarkers)
        }
    }

    @ViewBuilder
    private var setupsContent: some View {
        if isLoadingActivity && setupsLiveMarkers.isEmpty && setupsResolvedMarkers.isEmpty {
            UnifiedLoadingState(message: "Loading setups...")
                .padding(.top, 24)
        } else if setupsLiveMarkers.isEmpty && setupsResolvedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "target",
                title: "No Setups",
                subtitle: "No tracked setup markers for \(currentSymbolLabel) yet."
            )
            .padding(.top, 20)
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
    private var timeframeContent: some View {
        if isLoadingActivity && archiveMarkers.isEmpty {
            UnifiedLoadingState(message: "Loading marker timeframes...")
                .padding(.top, 24)
        } else if timeframeGroups.isEmpty {
            UnifiedEmptyState(
                icon: "clock",
                title: "No Markers by Timeframe",
                subtitle: "Grouped marker activity for \(currentSymbolLabel) will appear here."
            )
            .padding(.top, 20)
        } else {
            VStack(spacing: 8) {
                ForEach(timeframeGroups) { group in
                    UnifiedDisclosureGroup(
                        title: group.title,
                        count: group.count,
                        icon: "clock",
                        iconColor: group.rawTimeframe == chartViewModel.currentTimeframe.toBackendString()
                            ? AppColors.statusPositive70
                            : AppColors.statusInfo80,
                        isExpandedByDefault: group.isExpandedByDefault
                    ) {
                        markerList(group.markers)
                    }
                }
            }
        }
    }

    // MARK: - Analysis Tab

    @ViewBuilder
    private var analysisContent: some View {
        if isLoadingActivity && analysisMarkers.isEmpty {
            UnifiedLoadingState(message: "Preparing marker analysis...")
                .padding(.top, 24)
        } else if analysisMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "chart.bar.xaxis",
                title: "No marker analysis yet",
                subtitle: "Place markers on \(currentSymbolLabel) to generate symbol activity."
            )
            .padding(.top, 20)
        } else {
            VStack(spacing: 10) {
                metricGrid

                analysisSectionCard(title: "Marker Type Breakdown", icon: "square.grid.2x2.fill") {
                    VStack(spacing: 8) {
                        ForEach(markerTypeBreakdown, id: \.key) { row in
                            BreakdownRow(
                                title: row.key,
                                count: row.value,
                                total: analysisMarkers.count
                            )
                        }
                    }
                }

                analysisSectionCard(title: "Timeframe Breakdown", icon: "clock") {
                    VStack(spacing: 8) {
                        ForEach(timeframeBreakdown, id: \.key) { row in
                            BreakdownRow(
                                title: row.key,
                                count: row.value,
                                total: analysisMarkers.count
                            )
                        }
                    }
                }

                analysisSectionCard(title: "Quick Links", icon: "link") {
                    VStack(spacing: 8) {
                        ForEach(Array(analysisMarkers.prefix(8))) { marker in
                            QuickLinkRow(
                                marker: marker,
                                onOpen: { openMarker(marker) }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Summary Badges

    private var markersSummaryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(currentSymbolLabel) \u{2022} \(selectedSubTab.title) \u{2022} \(summaryMarkerCount) markers")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()

            scopePillToggle
        }
        .padding(.horizontal, 2)
    }

    private var scopePillToggle: some View {
        HStack(spacing: 0) {
            ForEach(MarkerScopeToggle.allCases, id: \.self) { toggle in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedScopeToggle = toggle
                    }
                } label: {
                    Text(toggle.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(selectedScopeToggle == toggle ? .white : AppColors.surfaceWhite60)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedScopeToggle == toggle
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

    private var analysisSummaryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(currentSymbolLabel) \u{2022} Guild \u{2022} \(analysisMarkers.count) markers \u{2022} \(Set(analysisMarkers.map { timeframeLabel($0.timeframe) }).count) timeframes")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Empty States

    private var emptyStateIcon: String {
        switch selectedSubTab {
        case .liveFeed: return "bolt.horizontal"
        case .setups: return "target"
        case .byTimeframe: return "clock"
        case .all: return "square.grid.2x2"
        }
    }

    private var emptyStateTitle: String {
        switch selectedSubTab {
        case .liveFeed: return "No Recent Activity"
        case .setups: return "No Setups"
        case .byTimeframe: return "No Markers by Timeframe"
        case .all: return "No Markers"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedSubTab {
        case .liveFeed:
            return "Recent marker activity for \(currentSymbolLabel) will appear here."
        case .setups:
            return "No tracked setup markers for \(currentSymbolLabel) yet."
        case .byTimeframe:
            return "Grouped timeframe activity for \(currentSymbolLabel) will appear here."
        case .all:
            return "No archived marker activity for \(currentSymbolLabel) yet."
        }
    }

    // MARK: - Analysis Helpers

    private var markerTypeBreakdown: [(key: String, value: Int)] {
        let counts = Dictionary(grouping: analysisMarkers) { $0.intentEnum.displayName }
            .mapValues(\.count)
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
    }

    private var timeframeBreakdown: [(key: String, value: Int)] {
        let counts = Dictionary(grouping: analysisMarkers) { marker in
            timeframeLabel(marker.timeframe)
        }
        .mapValues(\.count)

        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
    }

    private var metricGrid: some View {
        let total = analysisMarkers.count
        let uniqueTimeframes = Set(analysisMarkers.map { timeframeLabel($0.timeframe) }).count
        let candleGroups = Dictionary(grouping: analysisMarkers) { $0.candleTimestamp.timeIntervalSince1970 }
        let stackedCandles = candleGroups.values.filter { $0.count > 1 }.count
        let predictionCount = analysisMarkers.filter { $0.intentEnum == .setup }.count

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            AnalysisMetricCard(title: "Total", value: "\(total)", subtitle: "markers")
            AnalysisMetricCard(title: "Timeframes", value: "\(uniqueTimeframes)", subtitle: "covered")
            AnalysisMetricCard(title: "Stacks", value: "\(stackedCandles)", subtitle: "shared candles")
            AnalysisMetricCard(title: "Predictions", value: "\(predictionCount)", subtitle: "setups")
        }
    }

    // MARK: - Count Helpers

    private var summaryMarkerCount: Int {
        switch selectedSubTab {
        case .liveFeed:
            return recentMarkers.count
        case .setups:
            return setupsLiveMarkers.count + setupsResolvedMarkers.count
        case .byTimeframe, .all:
            return archiveMarkers.count
        }
    }

    private var visibleMarkersAreEmpty: Bool {
        switch selectedSubTab {
        case .liveFeed:
            return recentMarkers.isEmpty
        case .setups:
            return setupsLiveMarkers.isEmpty && setupsResolvedMarkers.isEmpty
        case .byTimeframe, .all:
            return archiveMarkers.isEmpty
        }
    }

    // MARK: - UI Helpers

    private func markerList(_ markers: [RLMarkerActivityItemDTO]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(markers) { marker in
                MarkerListItem(
                    marker: marker,
                    style: .capsule,
                    showMyBadge: marker.isCurrentUserMarker,
                    currentPrice: activeSymbolPrice,
                    likeAnimationMarkerId: likedMarkerId,
                    onLike: { handleLike(marker: marker) },
                    onTap: { openMarker(marker) }
                )
            }
        }
    }

    private func analysisSectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppColors.statusInfo85)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }

            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.surfaceWhite08)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.statusWarning95)
            Spacer()
        }
        .padding(10)
        .background(AppColors.statusWarning14)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Actions

    private func isMarkerPlacementActive(for intent: RLMarkerIntent) -> Bool {
        controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerIntent == intent
    }

    private func togglePlacement(for intent: RLMarkerIntent) {
        if isMarkerPlacementActive(for: intent) {
            controlViewModel.cancelMarkerPlacement()
            return
        }

        if let failure = placementPreflightFailure(for: intent) {
            rlAppState.showError(
                title: failure.toastTitle,
                message: failure.userMessage,
                severity: failure.toastSeverity,
                style: .toast
            )
            return
        }

        controlViewModel.startMarkerPlacement(intent: intent)
        onMarkerSelection?()
    }

    private func placementPreflightFailure(for intent: RLMarkerIntent) -> MarkerPlacementFailure? {
        guard intent == .setup,
              let markerManager = chartViewModel.markerManager,
              let symbolId = chartViewModel.currentSymbol?.id else {
            return nil
        }

        return markerManager.preflightPlacementFailure(
            for: intent,
            symbolId: symbolId,
            timeframe: chartViewModel.currentTimeframe.toBackendString(),
            trackingEnabled: true
        )
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

    private func openMarker(_ marker: RLMarkerActivityItemDTO) {
        onNavigateToMarker?(marker.asTopMarkerDTO())
        onMarkerSelection?()
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
            entry = ChartMarkerSetupCacheEntry(live: live, resolved: resolved)
            setupsCache[key] = entry
        }

        if let snapshot = analysisSnapshot {
            var markersByScope = snapshot.markersByScope
            for scope in markersByScope.keys {
                guard var markers = markersByScope[scope],
                      let index = markers.firstIndex(where: { $0.id == markerId }) else { continue }

                markers[index].isLikedByCurrentUser = isLiked
                markers[index].likeCount = likeCount
                markersByScope[scope] = markers
            }

            analysisSnapshot = MarkerActivityFeedSnapshot(
                markersByScope: markersByScope,
                totalCountByScope: snapshot.totalCountByScope,
                lastUpdated: snapshot.lastUpdated
            )
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

    private func timeframeLabel(_ backendTimeframe: String) -> String {
        MarkerActivityNavigation.timeframeTitle(for: backendTimeframe)
    }

    // MARK: - Data Loading

    private func loadMarkerActivity(forceRefresh: Bool) async {
        guard let guildId = rlAppState.currentGuild?.id,
              rlAppState.currentUser?.id != nil,
              let currentSymbol = chartViewModel.currentSymbol else {
            await MainActor.run {
                resetMarkerActivityState()
                setupsLiveMarkers = []
                setupsResolvedMarkers = []
                analysisSnapshot = nil
                liveSymbol = chartViewModel.currentSymbol
                activityLoadError = "Select a guild, user, and symbol to load marker activity."
                isLoadingActivity = false
                isRefreshingActivity = false
            }
            return
        }

        let requestPrimaryTab = selectedPrimaryTab
        let requestSubTab = selectedSubTab
        let requestScope = selectedScopeToggle
        let requestSymbol = currentSymbol
        let loadKey = requestScope.rawValue

        if cacheNamespace != reloadKey {
            await MainActor.run {
                cacheNamespace = reloadKey
                resetMarkerActivityState()
                analysisSnapshot = nil
            }
        }

        if selectedPrimaryTab == .add {
            await MainActor.run {
                liveSymbol = currentSymbol
                isLoadingActivity = false
                isRefreshingActivity = false
            }
            return
        }

        if requestPrimaryTab == .analysis,
           !forceRefresh,
           analysisSnapshot != nil,
           liveSymbol != nil {
            return
        }

        if forceRefresh {
            await MainActor.run {
                isRefreshingActivity = true
                activityLoadError = nil
            }
        } else {
            await MainActor.run {
                isLoadingActivity = true
                activityLoadError = nil
            }
        }

        do {
            let api = rlAppState.realApi
            let refreshedSymbol = try? await api.getSymbol(symbolId: requestSymbol.id)

            switch requestPrimaryTab {
            case .markers:
                let scope = requestScope.apiScope

                switch requestSubTab {
                case .liveFeed:
                    if !forceRefresh, let cachedMarkers = recentCache[loadKey] {
                        await MainActor.run {
                            recentMarkers = cachedMarkers
                            liveSymbol = refreshedSymbol ?? requestSymbol
                            activityLoadError = nil
                            isLoadingActivity = false
                            isRefreshingActivity = false
                        }
                        break
                    }

                    let markers = try await loadMarkers(
                        api: api,
                        guildId: guildId,
                        symbolId: requestSymbol.id,
                        scope: scope,
                        loadMode: .recentFeed
                    )
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        recentCache[loadKey] = markers
                        recentMarkers = markers
                        liveSymbol = refreshedSymbol ?? requestSymbol
                        activityLoadError = nil
                        isLoadingActivity = false
                        isRefreshingActivity = false
                    }

                case .setups:
                    if !forceRefresh, let cachedEntry = setupsCache[loadKey] {
                        await MainActor.run {
                            setupsLiveMarkers = cachedEntry.live
                            setupsResolvedMarkers = cachedEntry.resolved
                            liveSymbol = refreshedSymbol ?? requestSymbol
                            activityLoadError = nil
                            isLoadingActivity = false
                            isRefreshingActivity = false
                        }
                        break
                    }

                    async let liveMarkers = loadMarkers(
                        api: api,
                        guildId: guildId,
                        symbolId: requestSymbol.id,
                        scope: scope,
                        loadMode: .setupsLive
                    )
                    async let resolvedMarkers = loadMarkers(
                        api: api,
                        guildId: guildId,
                        symbolId: requestSymbol.id,
                        scope: scope,
                        loadMode: .setupsResolved
                    )

                    let (live, resolved) = try await (liveMarkers, resolvedMarkers)
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        setupsCache[loadKey] = ChartMarkerSetupCacheEntry(live: live, resolved: resolved)
                        setupsLiveMarkers = live
                        setupsResolvedMarkers = resolved
                        liveSymbol = refreshedSymbol ?? requestSymbol
                        activityLoadError = nil
                        isLoadingActivity = false
                        isRefreshingActivity = false
                    }

                case .byTimeframe, .all:
                    if !forceRefresh, let cachedMarkers = archiveCache[loadKey] {
                        await MainActor.run {
                            archiveMarkers = cachedMarkers
                            liveSymbol = refreshedSymbol ?? requestSymbol
                            activityLoadError = nil
                            isLoadingActivity = false
                            isRefreshingActivity = false
                        }
                        break
                    }

                    let markers = try await loadMarkers(
                        api: api,
                        guildId: guildId,
                        symbolId: requestSymbol.id,
                        scope: scope,
                        loadMode: .archive
                    )
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        archiveCache[loadKey] = markers
                        archiveMarkers = markers
                        liveSymbol = refreshedSymbol ?? requestSymbol
                        activityLoadError = nil
                        isLoadingActivity = false
                        isRefreshingActivity = false
                    }
                }

            case .analysis:
                let snapshot = try await MarkerActivityFeedLoader.loadScopes(
                    api: api,
                    guildId: guildId,
                    symbolId: requestSymbol.id,
                    state: .all,
                    window: nil,
                    scopes: [.guild],
                    limit: 200,
                    fetchAllPages: true
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    analysisSnapshot = snapshot
                    liveSymbol = refreshedSymbol ?? requestSymbol
                    activityLoadError = nil
                    isLoadingActivity = false
                    isRefreshingActivity = false
                }

            case .add:
                break
            }
        } catch {
            guard !isCancellationError(error) else { return }
            await MainActor.run {
                activityLoadError = error.localizedDescription
                isLoadingActivity = false
                isRefreshingActivity = false
            }
        }
    }

    private func loadMarkers(
        api: RealAPIService,
        guildId: UUID,
        symbolId: UUID,
        scope: RLMarkerActivityScope,
        loadMode: MarkerActivityListLoadMode
    ) async throws -> [RLMarkerActivityItemDTO] {
        let snapshot = try await MarkerActivityFeedLoader.loadForScope(
            api: api,
            guildId: guildId,
            symbolId: symbolId,
            scope: scope,
            state: loadMode.state,
            limit: loadMode.limit,
            fetchAllPages: loadMode.fetchAllPages
        )

        guard !Task.isCancelled else { return [] }
        return MarkerActivityNavigation.sortedByActivity(snapshot.markersByScope[scope] ?? [])
    }

    private func resetMarkerActivityState() {
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
}

// MARK: - Private Helper Views

private struct MarkerPlacementOptionRow: View {
    let intent: RLMarkerIntent
    let isActive: Bool
    let onToggle: () -> Void

    private var rowAccentColor: Color {
        isActive ? AppColors.statusNegative95 : intent.color
    }

    private var rowBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.surfaceWhite08, AppColors.surfaceWhite04],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowBorderColor: Color {
        AppColors.surfaceWhite10
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(rowAccentColor)
                    .frame(width: 3, height: 32)
                    .padding(.leading, 6)

                HStack(spacing: 12) {
                    if isActive {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                    } else {
                        UnifiedMarkerBadge(intent: intent, sizeToken: .large)
                            .frame(width: 46, height: 46)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isActive ? "Cancel Placement" : intent.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if !isActive {
                            Text(intent.subtitle)
                                .font(.caption2)
                                .foregroundColor(AppColors.surfaceWhite74)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isActive ? "xmark" : "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.surfaceWhite84)
                        .frame(width: 28, height: 28)
                        .background(AppColors.surfaceWhite08)
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
                .padding(.trailing, 14)
            }
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(rowBackgroundGradient)
                    PatternOverlay(patternType: .honeycomb, hexSize: 16)
                        .opacity(0.02)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(rowBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MarkerSettingsButton: View {
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.surfaceWhite85)
                .frame(width: 34, height: 34)
                .background(AppColors.surfaceWhite08)
                .clipShape(Circle())
        }
        .accessibilityLabel("Marker settings")
    }
}

private struct MarkerFilterSettingsSheet: View {
    @ObservedObject var markerManager: MarkerManager
    @Binding var isPresented: Bool

    private var selectedIntentCount: Int {
        markerManager.visibleIntents.count
    }

    private var totalIntentCount: Int {
        RLMarkerIntent.allCases.count
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "slider.horizontal.3",
                    iconColor: AppColors.accentColor,
                    title: "Marker Settings",
                    subtitle: "Visibility and intent filters"
                )
                .padding(.horizontal, 16)
                .padding(.top, 30)

                Divider()
                    .background(AppColors.surfaceWhite15)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 12) {
                        AdminSectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Visibility Mode")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.greyText)

                                Picker("Visibility", selection: $markerManager.visibilityMode) {
                                    ForEach(MarkerVisibilityMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .colorScheme(.dark)
                            }
                        }

                        AdminSectionCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Intent Filters")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.greyText)

                                    Spacer()

                                    Text("\(selectedIntentCount)/\(totalIntentCount)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(AppColors.surfaceWhite70)

                                    Button {
                                        markerManager.visibleIntents = Set(RLMarkerIntent.allCases)
                                    } label: {
                                        Text("All")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(AppColors.accentColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule().fill(AppColors.accentColor.opacity(0.15))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }

                                ForEach(RLMarkerIntent.allCases, id: \.self) { intent in
                                    HStack(spacing: 10) {
                                        UnifiedMarkerBadge(intent: intent, sizeToken: .tiny)

                                        Text(intent.displayName)
                                            .font(.subheadline)
                                            .foregroundColor(.white)

                                        Spacer()

                                        Toggle("", isOn: binding(for: intent))
                                            .labelsHidden()
                                            .tint(AppColors.accentColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Button {
                    isPresented = false
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.greyText)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AdminSheetBackground())
        .presentationDetents([.fraction(0.55), .large])
    }

    private func binding(for intent: RLMarkerIntent) -> Binding<Bool> {
        Binding(
            get: { markerManager.visibleIntents.contains(intent) },
            set: { isOn in
                if isOn {
                    markerManager.visibleIntents.insert(intent)
                } else {
                    markerManager.visibleIntents.remove(intent)
                }
            }
        )
    }
}

private struct AnalysisMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(AppColors.surfaceGray90)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.surfaceWhite08)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                )
        )
    }
}

private struct BreakdownRow: View {
    let title: String
    let count: Int
    let total: Int

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppColors.surfaceWhite90)
                Spacer()
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.surfaceWhite12)
                    Capsule()
                        .fill(AppColors.statusInfo60)
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct QuickLinkRow: View {
    let marker: RLMarkerActivityItemDTO
    let onOpen: () -> Void

    private var timeframeText: String {
        RLChartTimeframe.fromBackendString(marker.timeframe)?.shortName ?? marker.timeframe.uppercased()
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                UnifiedMarkerBadge(intent: marker.intentEnum, sizeToken: .tiny)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(marker.intentEnum.displayName) \u{2022} \(marker.symbolTicker)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("\(timeframeText) \u{2022} \(marker.activityTimestampFormatted)")
                        .font(.caption2)
                        .foregroundColor(AppColors.surfaceWhite70)
                }

                Spacer()

                Image(systemName: "arrow.up.forward")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.statusInfo80)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.surfaceWhite08)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
