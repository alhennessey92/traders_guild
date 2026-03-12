//
//  chartSheetMarkersView.swift
//  traders_guild
//
//  Refactored marker sheet:
//  - Mirrors indicator sheet structure and styling
//  - Provides Add / Active / Analysis tabs
//  - Active and Analysis are symbol-scoped and timeframe-aware
//

import SwiftUI

enum MarkerSheetPrimaryTab: String, CaseIterable, UnifiedTabItem {
    case add = "Add"
    case active = "Active"
    case analysis = "Analysis"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .add: return "plus.circle.fill"
        case .active: return "clock.arrow.circlepath"
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

enum MarkerActivityScopeTab: String, CaseIterable, UnifiedTabItem {
    case personal = "Personal"
    case friends = "Friends"
    case guild = "Guild"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .friends: return "person.2.fill"
        case .guild: return "person.3.fill"
        }
    }
}

private struct MarkerTimelineGroup: Identifiable {
    let id: String
    let candleTimestamp: Date
    let markers: [RLTopMarkerDTO]
}

/// Marker content view for ChartBottomSheet
struct chartSheetMarkersView: View {
    @EnvironmentObject private var rlAppState: RLAppState

    @ObservedObject var chartViewModel: ChartViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel

    /// Navigate to selected marker on chart
    var onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil

    /// Called when marker selection should collapse to compact detent
    var onMarkerSelection: (() -> Void)? = nil

    @State private var selectedPrimaryTab: MarkerSheetPrimaryTab = .add
    @State private var selectedAddCategory: MarkerAddCategoryTab = .prediction
    @State private var selectedActivityScope: MarkerActivityScopeTab = .personal

    @State private var markerCacheByScope: [MarkerActivityScopeTab: [RLTopMarkerDTO]] = [:]
    @State private var liveSymbol: RLTradingSymbolDTO?

    @State private var isLoadingActive = false
    @State private var isRefreshingActive = false
    @State private var activeLoadError: String?
    @State private var showMarkerSettingsSheet = false

    private var reloadKey: String {
        let symbol = chartViewModel.currentSymbol?.id.uuidString ?? "none"
        let guild = rlAppState.currentGuild?.id.uuidString ?? "none"
        let user = rlAppState.currentUser?.id.uuidString ?? "none"
        return "\(symbol)|\(guild)|\(user)"
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

    private var scopedMarkers: [RLTopMarkerDTO] {
        markers(for: selectedActivityScope)
    }

    private var scopedTimelineGroups: [MarkerTimelineGroup] {
        let grouped = Dictionary(grouping: scopedMarkers) { marker in
            marker.candleTimestamp.timeIntervalSince1970
        }

        return grouped
            .map { timestamp, markers in
                MarkerTimelineGroup(
                    id: "\(timestamp)",
                    candleTimestamp: Date(timeIntervalSince1970: timestamp),
                    markers: markers.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.candleTimestamp > $1.candleTimestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            UnifiedTabBar(
                selectedTab: $selectedPrimaryTab,
                size: .compact,
                theme: .blue,
                countForTab: { count(for: $0) },
                spacing: 6
            )

            if selectedPrimaryTab == .add {
                UnifiedTabBar(
                    selectedTab: $selectedAddCategory,
                    size: .compact,
                    theme: .subTab,
                    countForTab: { markerIntents(for: $0).count },
                    spacing: 6
                )
            } else {
                UnifiedTabBar(
                    selectedTab: $selectedActivityScope,
                    size: .compact,
                    theme: .subTab,
                    countForTab: { markers(for: $0).count },
                    spacing: 6
                )

                activitySummaryBadge
            }

            content

            if let activeLoadError,
               !activeLoadError.isEmpty,
               selectedPrimaryTab != .add,
               scopedMarkers.isEmpty {
                errorBanner(activeLoadError)
            }
        }
        .padding(.top, 15)
        .task(id: reloadKey) {
            await loadActiveMarkers(forceRefresh: false)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Markers")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 10) {
                    if selectedPrimaryTab != .add {
                        Button {
                            Task {
                                await loadActiveMarkers(forceRefresh: true)
                            }
                        } label: {
                            if isRefreshingActive {
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
                        .disabled(isRefreshingActive || isLoadingActive)
                    }

                    MarkerSettingsButton {
                        showMarkerSettingsSheet = true
                    }
                    .disabled(chartViewModel.markerManager == nil)
                    .opacity(chartViewModel.markerManager == nil ? 0.45 : 1)
                }
            }
            .padding(.bottom, 6)

            Text(subtitleForCurrentTab)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private var subtitleForCurrentTab: String {
        switch selectedPrimaryTab {
        case .add:
            return "Add markers quickly from grouped categories. Selecting one closes the sheet and starts placement."
        case .active:
            return "Activity timeline for \(currentSymbolLabel), including markers from all available timeframes."
        case .analysis:
            return "Breakdown of active marker flow, timeframe coverage, and quick links for \(currentSymbolLabel)."
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedPrimaryTab {
        case .add:
            addContent
        case .active:
            activeTimelineContent
        case .analysis:
            analysisContent
        }
    }

    // MARK: - Add Tab

    private var addContent: some View {
        VStack(spacing: 8) {
            if selectedAddCategory == .prediction {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(AppColors.statusWarning90)
                        .font(.caption)
                    Text("Prediction markers affect your reputation. Set entry, SL, and TP when prompted.")
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
                    onToggle: {
                        togglePlacement(for: intent)
                    }
                )
            }
        }
    }

    // MARK: - Active Tab

    @ViewBuilder
    private var activeTimelineContent: some View {
        if isLoadingActive && scopedMarkers.isEmpty {
            UnifiedLoadingState(message: "Loading active markers...")
                .padding(.top, 24)
        } else if scopedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "mappin.and.ellipse",
                title: "No active markers",
                subtitle: "Markers for \(currentSymbolLabel) will appear here as they are placed."
            )
            .padding(.top, 20)
        } else {
            VStack(spacing: 10) {
                ForEach(Array(scopedTimelineGroups.enumerated()), id: \.element.id) { index, group in
                    MarkerTimelineGroupCard(
                        group: group,
                        isLast: index == scopedTimelineGroups.count - 1,
                        symbolPrice: activeSymbolPrice,
                        onOpen: { marker in
                            openMarker(marker)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Analysis Tab

    @ViewBuilder
    private var analysisContent: some View {
        if isLoadingActive && scopedMarkers.isEmpty {
            UnifiedLoadingState(message: "Preparing marker analysis...")
                .padding(.top, 24)
        } else if scopedMarkers.isEmpty {
            UnifiedEmptyState(
                icon: "chart.bar.xaxis",
                title: "No marker analysis yet",
                subtitle: "Place markers on \(currentSymbolLabel) to generate timeline analytics."
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
                                total: scopedMarkers.count
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
                                total: scopedMarkers.count
                            )
                        }
                    }
                }

                analysisSectionCard(title: "Quick Links", icon: "link") {
                    VStack(spacing: 8) {
                        ForEach(Array(scopedMarkers.prefix(8))) { marker in
                            QuickLinkRow(
                                marker: marker,
                                onOpen: {
                                    openMarker(marker)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Analysis Computed

    private var markerTypeBreakdown: [(key: String, value: Int)] {
        let counts = Dictionary(grouping: scopedMarkers) { $0.intentEnum.displayName }
            .mapValues(\.count)
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
    }

    private var timeframeBreakdown: [(key: String, value: Int)] {
        let counts = Dictionary(grouping: scopedMarkers) { marker in
            timeframeLabel(marker.timeframe)
        }
        .mapValues(\.count)

        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
    }

    private var metricGrid: some View {
        let total = scopedMarkers.count
        let uniqueTimeframes = Set(scopedMarkers.map { timeframeLabel($0.timeframe) }).count
        let stackedCandles = scopedTimelineGroups.filter { $0.markers.count > 1 }.count
        let predictionCount = scopedMarkers.filter { $0.intentEnum == .setup }.count

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            AnalysisMetricCard(title: "Total", value: "\(total)", subtitle: "markers")
            AnalysisMetricCard(title: "Timeframes", value: "\(uniqueTimeframes)", subtitle: "covered")
            AnalysisMetricCard(title: "Stacks", value: "\(stackedCandles)", subtitle: "shared candles")
            AnalysisMetricCard(title: "Predictions", value: "\(predictionCount)", subtitle: "active")
        }
    }

    // MARK: - Shared UI

    private var activitySummaryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption)
                .foregroundColor(AppColors.statusInfo80)

            Text("\(currentSymbolLabel) • \(scopedMarkers.count) markers • \(Set(scopedMarkers.map { timeframeLabel($0.timeframe) }).count) timeframes")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 2)
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

    // MARK: - Actions

    private func markerIntents(for category: MarkerAddCategoryTab) -> [RLMarkerIntent] {
        markerCategoryMap[category] ?? []
    }

    private func count(for tab: MarkerSheetPrimaryTab) -> Int {
        switch tab {
        case .add:
            return Set(markerCategoryMap.values.flatMap { $0 }).count
        case .active, .analysis:
            return scopedMarkers.count
        }
    }

    private func markers(for scope: MarkerActivityScopeTab) -> [RLTopMarkerDTO] {
        markerCacheByScope[scope] ?? []
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

    private func openMarker(_ marker: RLTopMarkerDTO) {
        onNavigateToMarker?(marker)
        onMarkerSelection?()
    }

    private func timeframeLabel(_ backendTimeframe: String) -> String {
        RLChartTimeframe.fromBackendString(backendTimeframe)?.shortName ?? backendTimeframe.uppercased()
    }

    private func dedupeMarkers(_ markers: [RLTopMarkerDTO]) -> [RLTopMarkerDTO] {
        var map: [UUID: RLTopMarkerDTO] = [:]
        for marker in markers {
            if let existing = map[marker.id] {
                map[marker.id] = existing.createdAt >= marker.createdAt ? existing : marker
            } else {
                map[marker.id] = marker
            }
        }
        return Array(map.values)
    }

    private func loadActiveMarkers(forceRefresh: Bool) async {
        guard let guildId = rlAppState.currentGuild?.id,
              let userId = rlAppState.currentUser?.id,
              let currentSymbol = chartViewModel.currentSymbol else {
            await MainActor.run {
                markerCacheByScope = [:]
                liveSymbol = chartViewModel.currentSymbol
                activeLoadError = "Select a guild, user, and symbol to load marker activity."
                isLoadingActive = false
                isRefreshingActive = false
            }
            return
        }

        if forceRefresh {
            await MainActor.run {
                isRefreshingActive = true
                activeLoadError = nil
            }
        } else {
            await MainActor.run {
                isLoadingActive = true
                activeLoadError = nil
            }
        }

        do {
            async let userMarkersTask = rlAppState.realApi.getUserMarkers(guildId: guildId, userId: userId)
            async let topMarkersTask = rlAppState.realApi.getTopMarkers(guildId: guildId, timeWindowHours: 336)

            let userMarkersResponse = try await userMarkersTask
            let topMarkersResponse = try await topMarkersTask
            let freshSymbol = try? await rlAppState.realApi.getSymbol(symbolId: currentSymbol.id)

            let mine = userMarkersResponse.mine.filter { $0.symbolId == currentSymbol.id }
            let friends = topMarkersResponse.following.filter { $0.symbolId == currentSymbol.id }

            let bySymbolMatches = topMarkersResponse.bySymbol.values
                .flatMap { $0 }
                .filter { $0.symbolId == currentSymbol.id }

            let trendingMatches = topMarkersResponse.trending.filter { $0.symbolId == currentSymbol.id }

            let guild = dedupeMarkers(bySymbolMatches + trendingMatches + friends + mine)

            await MainActor.run {
                markerCacheByScope[.personal] = dedupeMarkers(mine).sorted { $0.createdAt > $1.createdAt }
                markerCacheByScope[.friends] = dedupeMarkers(friends).sorted { $0.createdAt > $1.createdAt }
                markerCacheByScope[.guild] = guild.sorted { $0.createdAt > $1.createdAt }
                liveSymbol = freshSymbol ?? currentSymbol
                activeLoadError = nil
            }
        } catch {
            await MainActor.run {
                activeLoadError = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoadingActive = false
            isRefreshingActive = false
        }
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
                    UnifiedMarkerBadge(
                        intent: intent,
                        sizeToken: .medium
                    )
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
        NavigationStack {
            List {
                Section("Visibility") {
                    Picker("Visibility", selection: $markerManager.visibilityMode) {
                        ForEach(MarkerVisibilityMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Intent Filters (\(selectedIntentCount)/\(totalIntentCount))") {
                    ForEach(RLMarkerIntent.allCases, id: \.self) { intent in
                        Toggle(isOn: binding(for: intent)) {
                            HStack(spacing: 10) {
                                UnifiedMarkerBadge(
                                    intent: intent,
                                    sizeToken: .tiny
                                )

                                Text(intent.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(AppColors.accentColor)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.systemBlack)
            .navigationTitle("Marker Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("All") {
                        markerManager.visibleIntents = Set(RLMarkerIntent.allCases)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
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

private struct MarkerTimelineGroupCard: View {
    let group: MarkerTimelineGroup
    let isLast: Bool
    let symbolPrice: Double?
    let onOpen: (RLTopMarkerDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(AppColors.statusInfo85)

                Text(group.candleTimestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)

                if group.markers.count > 1 {
                    Text("\(group.markers.count) stacked")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.statusWarning90)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppColors.statusWarning18)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(group.markers) { marker in
                    ActiveMarkerRow(
                        marker: marker,
                        symbolPrice: symbolPrice,
                        onOpen: {
                            onOpen(marker)
                        }
                    )
                }
            }

            if !isLast {
                Divider()
                    .background(AppColors.surfaceWhite08)
            }
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
}

private struct ActiveMarkerRow: View {
    let marker: RLTopMarkerDTO
    let symbolPrice: Double?
    let onOpen: () -> Void

    private var status: MarkerPredictionProgressStatus? {
        guard marker.intentEnum == .setup else { return nil }
        return MarkerPredictionProgress.status(
            entryPrice: marker.setupSummary?.entryPrice ?? marker.price,
            currentPrice: symbolPrice,
            targetPrice: marker.setupSummary?.tpPrice,
            stopLossPrice: marker.setupSummary?.slPrice
        )
    }

    private var timeframeText: String {
        RLChartTimeframe.fromBackendString(marker.timeframe)?.shortName ?? marker.timeframe.uppercased()
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 10) {
                UnifiedMarkerBadge(intent: marker.intentEnum, sizeToken: .small)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(marker.intentEnum.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)

                        Text(timeframeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(marker.intentEnum.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(marker.intentEnum.color.opacity(0.2))
                            .clipShape(Capsule())

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(AppColors.surfaceGray90)
                    }

                    HStack(spacing: 6) {
                        if let symbolColor = marker.symbolBrandColor {
                            Circle()
                                .fill(Color(hex: symbolColor) ?? .blue)
                                .frame(width: 6, height: 6)
                        }
                        Text(marker.symbolTicker)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText)

                        if !marker.isCurrentUserMarker {
                            Text("@\(marker.authorUsername)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Text(marker.createdAtFormatted)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    if let status {
                        MarkerStatusChip(status: status)
                    }

                    if let note = marker.notePreview, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 10) {
                        Label("\(marker.likeCount)", systemImage: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .font(.caption2)
                            .foregroundColor(marker.isLikedByCurrentUser ? AppColors.markerHeartTint : .gray)

                        Label("\(marker.commentCount)", systemImage: "bubble.left")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.surfaceWhite03)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MarkerStatusChip: View {
    let status: MarkerPredictionProgressStatus

    private var chipColor: Color {
        switch status {
        case .inProgress:
            return .blue
        case .approachingTP:
            return .green
        case .approachingSL:
            return .orange
        case .liveUnavailable:
            return .gray
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundColor(chipColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(chipColor.opacity(0.2))
            .clipShape(Capsule())
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
    let marker: RLTopMarkerDTO
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
                    Text("\(timeframeText) • \(marker.createdAtFormatted)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(AppColors.surfaceGray90)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.surfaceWhite03)
            )
        }
        .buttonStyle(.plain)
    }
}
