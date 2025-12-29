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
// MARK: - TOP MARKERS TAB DEFINITION
// MARK: - ================================================================================================

/// Tab enum conforming to UnifiedTabItem for use with UnifiedTabBar
enum TopMarkersTab: String, CaseIterable, UnifiedTabItem {
    case trending = "Trending"
    case symbol = "Symbol"
    case following = "Following"
    case mine = "Mine"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .trending: return "flame.fill"
        case .symbol: return "chart.line.uptrend.xyaxis"
        case .following: return "person.2.fill"
        case .mine: return "person.fill"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - TOP MARKERS VIEW
// MARK: - ================================================================================================

struct TopMarkersView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var appState: AppState
    
    // Tab state
    @State private var selectedTab: TopMarkersTab = .trending
    
    // Loading state
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false
    
    // Selection feedback
    @State private var likedMarkerId: UUID? = nil
    
    /// Callback when user wants to navigate to a marker on the chart
    var onNavigateToMarker: ((TopMarkerDTO) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector - OUTSIDE ScrollView (truly fixed)
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in getCountForTab(tab) },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 12)
            
            // Scrollable content with pull to refresh
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case .trending:
                        trendingMarkersContent
                    case .symbol:
                        assetClassMarkersContent
                    case .following:
                        followingMarkersContent
                    case .mine:
                        myMarkersContent
                    }
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
    }
    
    // MARK: - Refresh
    
    private func refreshMarkers() async {
        guard let guild = appState.currentGuild else { return }
        await leftDrawerViewModel.refresh(for: guild.id, appState: appState)
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: TopMarkersTab) -> Int {
        switch tab {
        case .trending: return leftDrawerViewModel.trendingMarkers.count
        case .symbol: return leftDrawerViewModel.symbolGroupedMarkers.reduce(0) { $0 + $1.value.count }
        case .following: return leftDrawerViewModel.followingMarkers.count
        case .mine: return leftDrawerViewModel.myMarkers.count
        }
    }
    
    // MARK: - Load Data
    
    private func loadMarkersIfNeeded() async {
        guard !hasLoaded else { return }
        guard let guildId = appState.currentGuild?.id else { return }
        
        isLoading = true
        await leftDrawerViewModel.loadTopMarkers(for: guildId, appState: appState)
        isLoading = false
        hasLoaded = true
    }
    
    // MARK: - Trending Markers Content
    
    private var trendingMarkersContent: some View {
        Group {
            if isLoading {
                UnifiedLoadingState(message: "Loading top markers...")
            } else if leftDrawerViewModel.trendingMarkers.isEmpty {
                UnifiedEmptyState(
                    icon: "flame",
                    title: "No Trending Markers",
                    subtitle: "Be the first to place a marker today!"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(leftDrawerViewModel.trendingMarkers) { marker in
                        TopMarkerCard(
                            marker: marker,
                            showMyBadge: marker.isCurrentUserMarker,
                            likedMarkerId: $likedMarkerId,
                            onLike: { handleLike(marker: marker) },
                            onTap: { handleMarkerTap(marker: marker) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Asset Class Markers Content (grouped by Forex, Crypto, etc.)
    
    /// Pre-computed grouping to avoid recomputation on every render
    private var markersGroupedByAssetClass: [(assetClass: AssetClass, markers: [TopMarkerDTO])] {
        let allMarkers = leftDrawerViewModel.symbolGroupedMarkers.values.flatMap { $0 }
        let grouped = Dictionary(grouping: allMarkers, by: { $0.symbolAssetClass })
        let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
        
        return orderedClasses.compactMap { assetClass in
            guard let markers = grouped[assetClass], !markers.isEmpty else { return nil }
            let topMarkers = Array(markers.sorted { $0.likeCount > $1.likeCount }.prefix(5))
            return (assetClass: assetClass, markers: topMarkers)
        }
    }
    
    private var assetClassMarkersContent: some View {
        Group {
            if isLoading {
                UnifiedLoadingState(message: "Loading markers...")
            } else if leftDrawerViewModel.symbolGroupedMarkers.isEmpty {
                UnifiedEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Markers by Symbol",
                    subtitle: "Markers will be grouped by asset class"
                )
                .padding(.top, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(markersGroupedByAssetClass, id: \.assetClass) { group in
                        AssetClassMarkerGroup(
                            assetClass: group.assetClass,
                            markers: group.markers,
                            likedMarkerId: $likedMarkerId,
                            onLike: { marker in handleLike(marker: marker) },
                            onTap: { marker in handleMarkerTap(marker: marker) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Following Markers Content
    
    private var followingMarkersContent: some View {
        Group {
            if isLoading {
                UnifiedLoadingState(message: "Loading markers...")
            } else if leftDrawerViewModel.followingMarkers.isEmpty {
                UnifiedEmptyState(
                    icon: "person.2",
                    title: "No Markers from Following",
                    subtitle: "Follow traders to see their markers here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(leftDrawerViewModel.followingMarkers) { marker in
                        TopMarkerCard(
                            marker: marker,
                            showMyBadge: marker.isCurrentUserMarker,
                            likedMarkerId: $likedMarkerId,
                            onLike: { handleLike(marker: marker) },
                            onTap: { handleMarkerTap(marker: marker) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - My Markers Content
    
    private var myMarkersContent: some View {
        Group {
            if isLoading {
                UnifiedLoadingState(message: "Loading markers...")
            } else if leftDrawerViewModel.myMarkers.isEmpty {
                UnifiedEmptyState(
                    icon: "mappin.and.ellipse",
                    title: "No Markers Yet",
                    subtitle: "Place markers on charts to see them here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(leftDrawerViewModel.myMarkers) { marker in
                        TopMarkerCard(
                            marker: marker,
                            showMyBadge: true,
                            likedMarkerId: $likedMarkerId,
                            onLike: { handleLike(marker: marker) },
                            onTap: { handleMarkerTap(marker: marker) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleLike(marker: TopMarkerDTO) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            likedMarkerId = marker.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            likedMarkerId = nil
        }
        
        Task {
            await leftDrawerViewModel.toggleMarkerLike(markerId: marker.id, appState: appState)
        }
    }
    
    private func handleMarkerTap(marker: TopMarkerDTO) {
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
    let marker: TopMarkerDTO
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
        switch marker.type {
        case .resistance: return "Resist"
        case .predictionTarget: return "Predict"
        default: return marker.type.rawValue
        }
    }
    
    var body: some View {
        UnifiedContentCard(onTap: onTap) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 8) {
                    // Icon with type label underneath - pushed down with top padding
                    VStack(spacing: 1) {
                        UnifiedIconBadge(
                            icon: marker.type.icon,
                            color: marker.type.color,
                            size: 26,
                            iconSize: 11
                        )
                        Text(shortTypeName)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(marker.type.color.opacity(0.9))
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
                                    .background(Capsule().fill(Color.blue.opacity(0.6)))
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
                                .foregroundColor(marker.isLikedByCurrentUser ? .red : AppColors.whiteText.opacity(0.5))
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
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 14)
                
                // MARK: - Author Footer Bar
                UnifiedAuthorFooter(
                    username: marker.authorUsername,
                    isOnline: marker.authorIsOnline,
                    role: marker.authorRole,
                    reputation: marker.authorReputation,
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
    let type: MarkerType
    
    var body: some View {
        UnifiedIconBadge(
            icon: type.icon,
            color: type.color
        )
    }
}

// MARK: - Asset Class Marker Group

struct AssetClassMarkerGroup: View {
    let assetClass: AssetClass
    let markers: [TopMarkerDTO]
    @Binding var likedMarkerId: UUID?
    let onLike: (TopMarkerDTO) -> Void
    let onTap: (TopMarkerDTO) -> Void
    
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
    let markers: [TopMarkerDTO]
    @Binding var likedMarkerId: UUID?
    let onLike: (TopMarkerDTO) -> Void
    let onTap: (TopMarkerDTO) -> Void
    
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
