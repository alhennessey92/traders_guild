//
//  chartSheetMarkersView.swift
//  traders_guild
//
//  Chart bottom-sheet marker management:
//  Add | Markers | Analysis
//  Markers -> Active | Today | This Week | This Month | Resolved
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

enum MarkerAddCategoryTab: String, CaseIterable, UnifiedTabItem {
    case prediction = "Prediction"
    case trade = "Trade"
    case analysis = "Analysis"
    case signals = "Signals"
    case social = "Social"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .prediction: return "target"
        case .trade: return "arrow.left.and.right.circle.fill"
        case .analysis: return "waveform.path.ecg"
        case .signals: return "bell.badge.fill"
        case .social: return "person.2.fill"
        }
    }
}

struct chartSheetMarkersView: View {
    @EnvironmentObject private var rlAppState: RLAppState

    @ObservedObject var chartViewModel: ChartViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel

    var onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil
    var onMarkerSelection: (() -> Void)? = nil

    @State private var selectedPrimaryTab: MarkerSheetPrimaryTab = .add
    @State private var selectedAddCategory: MarkerAddCategoryTab = .prediction
    @State private var selectedMarkerTopTab: RLMarkerActivityTopTab = .active
    @State private var selectedScope: RLMarkerActivityScope = .guild

    @State private var markerActivityCache: [RLMarkerActivityTopTab: MarkerActivityFeedSnapshot] = [:]
    @State private var analysisSnapshot: MarkerActivityFeedSnapshot?
    @State private var cacheNamespace = ""
    @State private var liveSymbol: RLTradingSymbolDTO?

    @State private var isLoadingActivity = false
    @State private var isRefreshingActivity = false
    @State private var activityLoadError: String?
    @State private var showMarkerSettingsSheet = false

    private var reloadKey: String {
        let symbol = chartViewModel.currentSymbol?.id.uuidString ?? "none"
        let guild = rlAppState.currentGuild?.id.uuidString ?? "none"
        let user = rlAppState.currentUser?.id.uuidString ?? "none"
        return "\(symbol)|\(guild)|\(user)"
    }

    private var visibleLoadKey: String {
        "\(reloadKey)|\(selectedPrimaryTab.rawValue)|\(selectedMarkerTopTab.rawValue)"
    }

    private var currentSymbolLabel: String {
        chartViewModel.currentSymbol?.ticker ?? "Symbol"
    }

    private var markerCategoryMap: [MarkerAddCategoryTab: [RLMarkerIntent]] {
        [
            .prediction: [.setup],
            .trade: [.setup, .alert],
            .analysis: [.analysis, .news],
            .signals: [.alert, .question],
            .social: [.poll, .reaction, .personal]
        ]
    }

    private var activeSymbolPrice: Double? {
        liveSymbol?.currentPrice ?? chartViewModel.currentSymbol?.currentPrice
    }

    private var selectedMarkers: [RLMarkerActivityItemDTO] {
        markerActivityCache[selectedMarkerTopTab]?.markersByScope[selectedScope] ?? []
    }

    private var analysisMarkers: [RLMarkerActivityItemDTO] {
        analysisSnapshot?.markersByScope[.guild] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            UnifiedTabBar(
                selectedTab: $selectedPrimaryTab,
                size: .compact,
                theme: .markerPrimary,
                countForTab: { count(for: $0) },
                spacing: 6
            )

            switch selectedPrimaryTab {
            case .add:
                UnifiedTabBar(
                    selectedTab: $selectedAddCategory,
                    size: .compact,
                    theme: .subTab,
                    countForTab: { markerIntents(for: $0).count },
                    spacing: 6
                )
            case .markers:
                UnifiedTabBar(
                    selectedTab: $selectedMarkerTopTab,
                    size: .compact,
                    theme: .componentsTabs,
                    countForTab: { countForTopTab($0) },
                    spacing: 6
                )

                UnifiedTabBar(
                    selectedTab: $selectedScope,
                    size: .compact,
                    theme: .subTab,
                    countForTab: { countForScope($0, topTab: selectedMarkerTopTab) },
                    spacing: 6
                )

                activitySummaryBadge(
                    descriptor: selectedMarkerTopTab.title
                )
            case .analysis:
                analysisSummaryBadge
            }

            content

            if let activityLoadError,
               !activityLoadError.isEmpty,
               selectedPrimaryTab != .add,
               selectedPrimaryTab == .analysis ? analysisMarkers.isEmpty : selectedMarkers.isEmpty {
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
                            Button("Done") {
                                showMarkerSettingsSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.fraction(0.35)])
            }
        }
    }

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
            return "Add markers quickly from grouped categories. Selecting one closes the sheet and starts placement."
        case .markers:
            return "Track live setups plus recent and resolved marker activity for \(currentSymbolLabel)."
        case .analysis:
            return "See one universal analysis view for all marker activity on \(currentSymbolLabel)."
        }
    }

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

    private var addContent: some View {
        VStack(spacing: 8) {
            if selectedAddCategory == .prediction {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(AppColors.statusWarning90)
                        .font(.caption)
                    Text("Prediction markers affect your accuracy and reputation. Set entry, SL, and TP when prompted.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }

            ForEach(markerIntents(for: selectedAddCategory), id: \.self) { intent in
                MarkerPlacementOptionRow(
                    intent: intent,
                    isActive: isMarkerPlacementActive(for: intent),
                    onToggle: { togglePlacement(for: intent) }
                )
            }
        }
    }

    @ViewBuilder
    private var markersContent: some View {
        if isLoadingActivity && selectedMarkers.isEmpty {
            UnifiedLoadingState(message: "Loading marker activity...")
                .padding(.top, 24)
        } else if selectedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: emptyStateIcon,
                title: emptyStateTitle,
                subtitle: emptyStateSubtitle
            )
            .padding(.top, 20)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(selectedMarkers) { marker in
                    MarkerActivityCard(
                        marker: marker,
                        showMyBadge: marker.isCurrentUserMarker,
                        currentPrice: activeSymbolPrice,
                        onTap: { openMarker(marker) }
                    )
                }
            }
        }
    }

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

    private var emptyStateIcon: String {
        switch selectedMarkerTopTab {
        case .active: return "bolt"
        case .today: return "sun.max"
        case .thisWeek: return "calendar"
        case .thisMonth: return "calendar.badge.clock"
        case .resolved: return "checkmark.circle"
        }
    }

    private var emptyStateTitle: String {
        switch selectedMarkerTopTab {
        case .active: return "No Active Markers"
        case .today: return "No Markers Today"
        case .thisWeek: return "No Markers This Week"
        case .thisMonth: return "No Markers This Month"
        case .resolved: return "No Resolved Markers"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedMarkerTopTab {
        case .active:
            return "Tracked setup markers for \(currentSymbolLabel) will appear here while they are being watched."
        case .resolved:
            return "Setups for \(currentSymbolLabel) move here when they hit TP, SL, or expire."
        case .today, .thisWeek, .thisMonth:
            return "All marker activity for \(currentSymbolLabel) in the selected time window will appear here."
        }
    }

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

    private func activitySummaryBadge(descriptor: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(currentSymbolLabel) • \(descriptor) • \(selectedScope.title) • \(summaryMarkerCount) markers")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var analysisSummaryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(currentSymbolLabel) • Guild • \(analysisMarkers.count) markers • \(Set(analysisMarkers.map { timeframeLabel($0.timeframe) }).count) timeframes")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var summaryMarkerCount: Int {
        switch selectedPrimaryTab {
        case .add:
            return 0
        case .markers:
            return countForScope(selectedScope, topTab: selectedMarkerTopTab)
        case .analysis:
            return analysisMarkers.count
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
                .fill(AppColors.surfaceWhite04)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.surfaceWhite08, lineWidth: 1)
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

    private func markerIntents(for category: MarkerAddCategoryTab) -> [RLMarkerIntent] {
        markerCategoryMap[category] ?? []
    }

    private func count(for tab: MarkerSheetPrimaryTab) -> Int {
        switch tab {
        case .add:
            return Set(markerCategoryMap.values.flatMap { $0 }).count
        case .markers:
            return summaryMarkerCount
        case .analysis:
            return analysisMarkers.count
        }
    }

    private func countForTopTab(_ topTab: RLMarkerActivityTopTab) -> Int {
        countForScope(selectedScope, topTab: topTab)
    }

    private func countForScope(_ scope: RLMarkerActivityScope, topTab: RLMarkerActivityTopTab) -> Int {
        let snapshot = markerActivityCache[topTab]
        return snapshot?.totalCountByScope[scope] ?? snapshot?.markersByScope[scope]?.count ?? 0
    }

    private func isMarkerPlacementActive(for intent: RLMarkerIntent) -> Bool {
        controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerIntent == intent
    }

    private func togglePlacement(for intent: RLMarkerIntent) {
        if isMarkerPlacementActive(for: intent) {
            controlViewModel.cancelMarkerPlacement()
            return
        }

        controlViewModel.startMarkerPlacement(intent: intent)
        onMarkerSelection?()
    }

    private func openMarker(_ marker: RLMarkerActivityItemDTO) {
        onNavigateToMarker?(marker.asTopMarkerDTO())
        onMarkerSelection?()
    }

    private func timeframeLabel(_ backendTimeframe: String) -> String {
        RLChartTimeframe.fromBackendString(backendTimeframe)?.shortName ?? backendTimeframe.uppercased()
    }

    private func loadMarkerActivity(forceRefresh: Bool) async {
        guard let guildId = rlAppState.currentGuild?.id,
              rlAppState.currentUser?.id != nil,
              let currentSymbol = chartViewModel.currentSymbol else {
            await MainActor.run {
                markerActivityCache = [:]
                analysisSnapshot = nil
                liveSymbol = chartViewModel.currentSymbol
                activityLoadError = "Select a guild, user, and symbol to load marker activity."
                isLoadingActivity = false
                isRefreshingActivity = false
            }
            return
        }

        let requestPrimaryTab = selectedPrimaryTab
        let requestTopTab = selectedMarkerTopTab
        let requestSymbol = currentSymbol

        if cacheNamespace != reloadKey {
            await MainActor.run {
                cacheNamespace = reloadKey
                markerActivityCache = [:]
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

        if requestPrimaryTab == .markers,
           !forceRefresh,
           markerActivityCache[requestTopTab] != nil,
           liveSymbol != nil {
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
                let snapshot = try await MarkerActivityFeedLoader.loadTopTab(
                    api: api,
                    guildId: guildId,
                    symbolId: requestSymbol.id,
                    topTab: requestTopTab,
                    scopes: Array(RLMarkerActivityScope.allCases),
                    limit: 60
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    markerActivityCache[requestTopTab] = snapshot
                    liveSymbol = refreshedSymbol ?? requestSymbol
                    activityLoadError = nil
                    isLoadingActivity = false
                    isRefreshingActivity = false
                }

                Task {
                    await prefetchRemainingTopTabs(
                        excluding: requestTopTab,
                        guildId: guildId,
                        symbolId: requestSymbol.id
                    )
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

    private func prefetchRemainingTopTabs(
        excluding activeTab: RLMarkerActivityTopTab,
        guildId: UUID,
        symbolId: UUID
    ) async {
        await withTaskGroup(of: (RLMarkerActivityTopTab, MarkerActivityFeedSnapshot?).self) { group in
            for tab in RLMarkerActivityTopTab.allCases where tab != activeTab && markerActivityCache[tab] == nil {
                group.addTask {
                    do {
                        let snapshot = try await MarkerActivityFeedLoader.loadTopTab(
                            api: rlAppState.realApi,
                            guildId: guildId,
                            symbolId: symbolId,
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
                    markerActivityCache[tab] = snapshot
                }
            }
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

private struct MarkerPlacementOptionRow: View {
    let intent: RLMarkerIntent
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                if isActive {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                } else {
                    UnifiedMarkerBadge(intent: intent, sizeToken: .medium)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isActive ? "Cancel Placement" : intent.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !isActive {
                        Text(intent.subtitle)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isActive ? "xmark" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isActive ? AppColors.surfaceWhite80 : AppColors.surfaceGray90)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? AppColors.statusNegative35 : intent.color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.surfaceWhite08, lineWidth: 1)
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
                .fill(AppColors.surfaceWhite04)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.surfaceWhite08, lineWidth: 1)
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
                        .fill(AppColors.surfaceWhite08)
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
                    Text("\(marker.intentEnum.displayName) • \(marker.symbolTicker)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("\(timeframeText) • \(marker.activityTimestampFormatted)")
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
                    .fill(AppColors.surfaceWhite04)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.surfaceWhite08, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
