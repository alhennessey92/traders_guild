//
//  TopMarkersView.swift
//  traders_guild
//
//  Top Markers View for Left Drawer
//  Displays trending, symbol-based, following, and personal markers
//  Uses UnifiedComponents for consistent styling
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - TAB DEFINITIONS
// MARK: - ================================================================================================

/// Primary section tabs
enum MarkerSectionTab: String, CaseIterable, UnifiedTabItem {
    case active = "Active"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .active: return "bolt.fill"
        case .today: return "flame.fill"
        case .thisWeek: return "calendar"
        case .thisMonth: return "calendar.badge.clock"
        }
    }

    /// Time window in hours for data fetch
    var timeWindowHours: Int {
        switch self {
        case .active: return 168
        case .today: return 24
        case .thisWeek: return 168
        case .thisMonth: return 720
        }
    }
}

/// Sub-tab for filtering within each section
enum MarkerSubTab: String, CaseIterable, UnifiedTabItem {
    case all = "All"
    case bySymbol = "Symbol"
    case friends = "Friends"
    case mine = "Mine"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .bySymbol: return "chart.line.uptrend.xyaxis"
        case .friends: return "person.2.fill"
        case .mine: return "person.fill"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - TOP MARKERS VIEW
// MARK: - ================================================================================================

struct TopMarkersView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rlAppState: RLAppState

    // Tab state
    @State private var selectedSection: MarkerSectionTab = .today
    @State private var selectedSubTab: MarkerSubTab = .all

    // Loading state
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false

    // Selection feedback
    @State private var likedMarkerId: UUID? = nil

    /// Callback when user wants to navigate to a marker on the chart
    var onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil

    // MARK: - Computed Data

    private var followingAuthorIds: Set<UUID> {
        Set(leftDrawerViewModel.followingMarkers.map(\.authorId))
    }

    /// Markers for the currently selected primary section
    private var markersForSection: [RLTopMarkerDTO] {
        switch selectedSection {
        case .active:
            return leftDrawerViewModel.trendingMarkers.filter { $0.setupSummary?.trackingState == "active" }
        case .today:
            return leftDrawerViewModel.trendingMarkers
        case .thisWeek:
            // symbolGroupedMarkers covers the weekly window
            return leftDrawerViewModel.symbolGroupedMarkers.values.flatMap { $0 }
        case .thisMonth:
            return leftDrawerViewModel.myMarkers + leftDrawerViewModel.followingMarkers
        }
    }

    private var showGreenBorder: Bool {
        selectedSection == .active
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Primary tabs — fixed at top
            UnifiedTabBar(
                selectedTab: $selectedSection,
                size: .compact,
                theme: .blue,
                countForTab: { tab in countForSection(tab) },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            // Sub-tabs — fixed below primary
            UnifiedTabBar(
                selectedTab: $selectedSubTab,
                size: .compact,
                theme: .subTab,
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    filteredMarkerList(
                        markers: markersForSection,
                        subTab: selectedSubTab
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshMarkers()
            }
        }
        .task {
            await loadMarkersIfNeeded()
        }
        .onChange(of: selectedSection) { _, newSection in
            Task {
                guard let guildId = rlAppState.currentGuild?.id else { return }
                isLoading = true
                await leftDrawerViewModel.loadTopMarkers(
                    for: guildId,
                    rlAppState: rlAppState,
                    timeWindowHours: newSection.timeWindowHours
                )
                isLoading = false
            }
        }
    }

    // MARK: - Section Counts

    private func countForSection(_ tab: MarkerSectionTab) -> Int {
        switch tab {
        case .active:
            return leftDrawerViewModel.trendingMarkers.filter { $0.setupSummary?.trackingState == "active" }.count
        case .today:
            return leftDrawerViewModel.trendingMarkers.count
        case .thisWeek:
            return leftDrawerViewModel.symbolGroupedMarkers.values.reduce(0) { $0 + $1.count }
        case .thisMonth:
            return (leftDrawerViewModel.myMarkers + leftDrawerViewModel.followingMarkers).count
        }
    }

    // MARK: - Filtered Marker List

    @ViewBuilder
    private func filteredMarkerList(
        markers: [RLTopMarkerDTO],
        subTab: MarkerSubTab
    ) -> some View {
        if isLoading {
            UnifiedLoadingState(message: "Loading markers...")
                .padding(.top, 40)
        } else {
            let filtered = filterMarkers(markers, by: subTab)
            if subTab == .bySymbol {
                // Grouped by symbol view
                let grouped = Dictionary(grouping: filtered) { $0.symbolTicker }
                if grouped.isEmpty {
                    emptyStateForSection
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(grouped.keys.sorted()), id: \.self) { symbolTicker in
                            if let symbolMarkers = grouped[symbolTicker] {
                                SymbolMarkerGroup(
                                    symbolTicker: symbolTicker,
                                    markers: symbolMarkers,
                                    likedMarkerId: $likedMarkerId,
                                    onLike: { marker in handleLike(marker: marker) },
                                    onTap: { marker in handleMarkerTap(marker: marker) }
                                )
                            }
                        }
                    }
                }
            } else if filtered.isEmpty {
                emptyStateForSection
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { marker in
                        TopMarkerCard(
                            marker: marker,
                            showMyBadge: marker.isCurrentUserMarker,
                            likedMarkerId: $likedMarkerId,
                            onLike: { handleLike(marker: marker) },
                            onTap: { handleMarkerTap(marker: marker) }
                        )
                        .overlay(
                            showGreenBorder
                                ? RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.statusPositive70.opacity(0.3), lineWidth: 1)
                                : nil
                        )
                    }
                }
            }
        }
    }

    private var emptyStateForSection: some View {
        let (icon, title, subtitle): (String, String, String) = {
            switch selectedSection {
            case .active:
                return ("bolt", "No Active Markers", "Markers with active tracking will appear here")
            case .today:
                return ("flame", "No Markers Today", "Be the first to place a marker today!")
            case .thisWeek:
                return ("calendar", "No Markers This Week", "Place markers on charts to see them here")
            case .thisMonth:
                return ("calendar.badge.clock", "No Markers This Month", "Place markers on charts to see them here")
            }
        }()

        return UnifiedEmptyState(icon: icon, title: title, subtitle: subtitle)
            .padding(.top, 40)
    }

    // MARK: - Filter Logic

    private func filterMarkers(_ markers: [RLTopMarkerDTO], by subTab: MarkerSubTab) -> [RLTopMarkerDTO] {
        switch subTab {
        case .all:
            return markers
        case .bySymbol:
            return markers // grouping handled in the view
        case .friends:
            return markers.filter { followingAuthorIds.contains($0.authorId) }
        case .mine:
            return markers.filter { $0.isCurrentUserMarker }
        }
    }

    // MARK: - Refresh

    private func refreshMarkers() async {
        guard let guild = rlAppState.currentGuild else { return }
        await leftDrawerViewModel.refreshTopMarkers(
            for: guild.id,
            rlAppState: rlAppState,
            timeWindowHours: selectedSection.timeWindowHours
        )
    }

    // MARK: - Load Data

    private func loadMarkersIfNeeded() async {
        guard !hasLoaded else { return }
        guard let guildId = rlAppState.currentGuild?.id else { return }

        isLoading = true
        await leftDrawerViewModel.loadTopMarkers(
            for: guildId,
            rlAppState: rlAppState,
            timeWindowHours: selectedSection.timeWindowHours
        )
        isLoading = false
        hasLoaded = true
    }

    // MARK: - Actions

    private func handleLike(marker: RLTopMarkerDTO) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            likedMarkerId = marker.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            likedMarkerId = nil
        }

        Task {
            await leftDrawerViewModel.toggleMarkerLike(markerId: marker.id, rlAppState: rlAppState)
        }
    }

    private func handleMarkerTap(marker: RLTopMarkerDTO) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if let onNavigate = onNavigateToMarker {
            onNavigate(marker)
            return
        }

        leftDrawerViewModel.requestNavigationToMarker(marker)
    }
}

// MARK: - ================================================================================================
// MARK: - TOP MARKER CARD
// MARK: - ================================================================================================

struct TopMarkerCard: View {
    let marker: RLTopMarkerDTO
    var showMyBadge: Bool = false
    @Binding var likedMarkerId: UUID?
    let onLike: () -> Void
    let onTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    private var isLikeAnimating: Bool {
        likedMarkerId == marker.id
    }
    
    /// Shortened marker type name for display
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
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 8) {
                    // Icon with type label underneath - pushed down with top padding
                    VStack(spacing: 1) {
                        UnifiedMarkerBadge(intent: marker.intentEnum, sizeToken: .small)
                        Text(shortTypeName)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(marker.intentEnum.color.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(width: 34)
                    .padding(.top, 4) // Push icon down
                    
                    // Right side content
                    VStack(alignment: .leading, spacing: 2) {
                        // Symbol row - at top
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
                            
                            // Likes
                            Button(action: onLike) {
                                HStack(spacing: 2) {
                                    Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
                                        .font(.system(size: 10))
                                        .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
                                    Text("\(marker.likeCount)")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(marker.isLikedByCurrentUser ? AppColors.markerHeartTint : AppColors.markerHeartMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Note preview
                        if let note = marker.notePreview, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.whiteText.opacity(0.75))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 4)
                        }

                        if let setup = marker.setupSummary, marker.intentEnum == .setup {
                            HStack(spacing: 6) {
                                if let entry = setup.entryPrice {
                                    Text("E \(String(format: "%.2f", entry))")
                                }
                                if let sl = setup.slPrice {
                                    Text("SL \(String(format: "%.2f", sl))")
                                }
                                if let tp = setup.tpPrice {
                                    Text("TP \(String(format: "%.2f", tp))")
                                }
                                if let state = setup.trackingState,
                                   let tracking = RLTrackingState(rawValue: state) {
                                    Text(tracking.displayName.uppercased())
                                        .foregroundColor(tracking.color)
                                }
                            }
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(AppColors.greyText)
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 14)
                
                // MARK: - Author Footer Bar
                UnifiedAuthorFooter(
                    username: marker.authorUsername,
                    isOnline: marker.authorIsOnline,
                    role: RLMemberRole(from: marker.authorRole),
                    reputation: marker.authorReputation,
                    accuracy: marker.authorAccuracyFormatted,
                    timeText: marker.createdAtFormatted,
                    showOnlineStatus: false
                )
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - SUPPORTING VIEWS
// MARK: - ================================================================================================

// MARK: - Marker Type Icon (kept for backwards compatibility)

struct MarkerTypeIcon: View {
    let intent: RLMarkerIntent
    
    var body: some View {
        UnifiedMarkerBadge(
            intent: intent,
            sizeToken: .medium
        )
    }
}

// MARK: - Asset Class Marker Group

struct AssetClassMarkerGroup: View {
    let assetClass: RLAssetClass
    let markers: [RLTopMarkerDTO]
    @Binding var likedMarkerId: UUID?
    let onLike: (RLTopMarkerDTO) -> Void
    let onTap: (RLTopMarkerDTO) -> Void
    
    /// Color for asset class (matches WatchlistView)
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
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: assetClass.rawValue,
            count: markers.count,
            icon: assetClass.icon,
            iconColor: assetClassColor,
            isExpandedByDefault: true
        ) {
            VStack(spacing: 8) {
                ForEach(markers) { marker in
                    TopMarkerCard(
                        marker: marker,
                        showMyBadge: marker.isCurrentUserMarker,
                        likedMarkerId: $likedMarkerId,
                        onLike: { onLike(marker) },
                        onTap: { onTap(marker) }
                    )
                }
            }
        }
    }
}

// MARK: - Symbol Marker Group (kept for backwards compatibility if needed)

struct SymbolMarkerGroup: View {
    let symbolTicker: String
    let markers: [RLTopMarkerDTO]
    @Binding var likedMarkerId: UUID?
    let onLike: (RLTopMarkerDTO) -> Void
    let onTap: (RLTopMarkerDTO) -> Void
    
    private var brandColor: Color {
        if let colorHex = markers.first?.symbolBrandColor {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }
    
    var body: some View {
        UnifiedDisclosureGroup(
            title: symbolTicker,
            count: markers.count,
            icon: "chart.line.uptrend.xyaxis",
            iconColor: brandColor,
            isExpandedByDefault: true
        ) {
            VStack(spacing: 8) {
                ForEach(markers) { marker in
                    TopMarkerCard(
                        marker: marker,
                        showMyBadge: marker.isCurrentUserMarker,
                        likedMarkerId: $likedMarkerId,
                        onLike: { onLike(marker) },
                        onTap: { onTap(marker) }
                    )
                }
            }
        }
    }
}
