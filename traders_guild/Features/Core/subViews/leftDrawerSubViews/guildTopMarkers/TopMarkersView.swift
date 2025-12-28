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
            // Tab selector
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
            
            // Content based on selected tab
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
        .task {
            await loadMarkersIfNeeded()
        }
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
                ScrollView(.vertical, showsIndicators: false) {
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
                ScrollView(.vertical, showsIndicators: false) {
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
                ScrollView(.vertical, showsIndicators: false) {
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
                ScrollView(.vertical, showsIndicators: false) {
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
    
    var body: some View {
        UnifiedContentCard(onTap: onTap) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                VStack(alignment: .leading, spacing: 3) {
                    // Top row: Icon + Symbol + Type + Stats
                    HStack(spacing: 8) {
                        // Marker type icon
                        UnifiedIconBadge(
                            icon: marker.type.icon,
                            color: marker.type.color,
                            size: 28,
                            iconSize: 12
                        )
                        
                        // Symbol with brand color
                        HStack(spacing: 4) {
                            if let brandColor = marker.symbolBrandColor {
                                Circle()
                                    .fill(Color(hex: brandColor) ?? .blue)
                                    .frame(width: 6, height: 6)
                            }
                            Text(marker.symbolTicker)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.whiteText)
                        }
                        
                        // Marker type label
                        Text(marker.type.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(marker.type.color.opacity(0.9))
                        
                        if showMyBadge {
                            Text("YOU")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.6)))
                        }
                        
                        Spacer()
                        
                        // Stats (top right)
                        UnifiedStatsRow(
                            commentCount: marker.commentCount,
                            likeCount: marker.likeCount,
                            isLiked: marker.isLikedByCurrentUser,
                            isLikeAnimating: isLikeAnimating,
                            onLike: onLike
                        )
                    }
                    
                    // Note preview
                    if let note = marker.notePreview, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.whiteText.opacity(0.75))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 36) // Align with content after icon (28 + 8 spacing)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                // MARK: - Author Footer Bar
                UnifiedAuthorFooter(
                    username: marker.authorUsername,
                    isOnline: marker.authorIsOnline,
                    role: marker.authorRole,
                    reputation: marker.authorReputation,
                    timeText: marker.createdAtFormatted
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

// MARK: - ================================================================================================
// MARK: - PREVIEW
// MARK: - ================================================================================================

#if DEBUG
#Preview("Top Markers View") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 16) {
                TopMarkerCard(
                    marker: TopMarkerDTO.sample,
                    showMyBadge: false,
                    likedMarkerId: .constant(nil),
                    onLike: {},
                    onTap: {}
                )
                
                TopMarkerCard(
                    marker: TopMarkerDTO.sample2,
                    showMyBadge: false,
                    likedMarkerId: .constant(nil),
                    onLike: {},
                    onTap: {}
                )
                
                TopMarkerCard(
                    marker: TopMarkerDTO.sample3,
                    showMyBadge: true,
                    likedMarkerId: .constant(nil),
                    onLike: {},
                    onTap: {}
                )
            }
            .padding()
        }
    }
}
#endif

////
////  TopMarkersView.swift
////  traders_guild
////
////  Top Markers View for Left Drawer
////  Displays trending, symbol-based, following, and personal markers
////  Uses UnifiedComponents for consistent styling
////
//
//import SwiftUI
//
//// MARK: - ================================================================================================
//// MARK: - TOP MARKERS TAB DEFINITION
//// MARK: - ================================================================================================
//
///// Tab enum conforming to UnifiedTabItem for use with UnifiedTabBar
//enum TopMarkersTab: String, CaseIterable, UnifiedTabItem {
//    case trending = "Trending"
//    case symbol = "Symbol"
//    case following = "Following"
//    case mine = "Mine"
//    
//    var title: String { rawValue }
//    
//    var icon: String {
//        switch self {
//        case .trending: return "flame.fill"
//        case .symbol: return "chart.line.uptrend.xyaxis"
//        case .following: return "person.2.fill"
//        case .mine: return "person.fill"
//        }
//    }
//}
//
//// MARK: - ================================================================================================
//// MARK: - TOP MARKERS VIEW
//// MARK: - ================================================================================================
//
//struct TopMarkersView: View {
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    @EnvironmentObject var appState: AppState
//    
//    // Tab state
//    @State private var selectedTab: TopMarkersTab = .trending
//    
//    // Loading state
//    @State private var isLoading: Bool = false
//    @State private var hasLoaded: Bool = false
//    
//    // Selection feedback
//    @State private var likedMarkerId: UUID? = nil
//    
//    /// Callback when user wants to navigate to a marker on the chart
//    var onNavigateToMarker: ((TopMarkerDTO) -> Void)? = nil
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Tab selector
//            UnifiedTabBar(
//                selectedTab: $selectedTab,
//                size: .compact,
//                theme: .blue,
//                countForTab: { tab in getCountForTab(tab) },
//                spacing: 6
//            )
//            .padding(.horizontal, 12)
//            .padding(.top, 4)
//            .padding(.bottom, 12)
//            
//            // Content based on selected tab
//            VStack(spacing: 12) {
//                switch selectedTab {
//                case .trending:
//                    trendingMarkersContent
//                case .symbol:
//                    assetClassMarkersContent
//                case .following:
//                    followingMarkersContent
//                case .mine:
//                    myMarkersContent
//                }
//            }
//            .padding(.horizontal, 12)
//            .padding(.bottom, 20)
//        }
//        .task {
//            await loadMarkersIfNeeded()
//        }
//    }
//    
//    // MARK: - Tab Counts
//    
//    private func getCountForTab(_ tab: TopMarkersTab) -> Int {
//        switch tab {
//        case .trending: return leftDrawerViewModel.trendingMarkers.count
//        case .symbol: return leftDrawerViewModel.symbolGroupedMarkers.reduce(0) { $0 + $1.value.count }
//        case .following: return leftDrawerViewModel.followingMarkers.count
//        case .mine: return leftDrawerViewModel.myMarkers.count
//        }
//    }
//    
//    // MARK: - Load Data
//    
//    private func loadMarkersIfNeeded() async {
//        guard !hasLoaded else { return }
//        guard let guildId = appState.currentGuild?.id else { return }
//        
//        isLoading = true
//        await leftDrawerViewModel.loadTopMarkers(for: guildId, appState: appState)
//        isLoading = false
//        hasLoaded = true
//    }
//    
//    // MARK: - Trending Markers Content
//    
//    private var trendingMarkersContent: some View {
//        Group {
//            if isLoading {
//                UnifiedLoadingState(message: "Loading top markers...")
//            } else if leftDrawerViewModel.trendingMarkers.isEmpty {
//                UnifiedEmptyState(
//                    icon: "flame",
//                    title: "No Trending Markers",
//                    subtitle: "Be the first to place a marker today!"
//                )
//                .padding(.top, 40)
//            } else {
//                ScrollView(.vertical, showsIndicators: false) {
//                    LazyVStack(spacing: 10) {
//                        ForEach(leftDrawerViewModel.trendingMarkers) { marker in
//                            TopMarkerCard(
//                                marker: marker,
//                                showMyBadge: marker.isCurrentUserMarker,
//                                likedMarkerId: $likedMarkerId,
//                                onLike: { handleLike(marker: marker) },
//                                onTap: { handleMarkerTap(marker: marker) }
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Asset Class Markers Content (grouped by Forex, Crypto, etc.)
//    
//    /// Pre-computed grouping to avoid recomputation on every render
//    private var markersGroupedByAssetClass: [(assetClass: AssetClass, markers: [TopMarkerDTO])] {
//        let allMarkers = leftDrawerViewModel.symbolGroupedMarkers.values.flatMap { $0 }
//        let grouped = Dictionary(grouping: allMarkers, by: { $0.symbolAssetClass })
//        let orderedClasses: [AssetClass] = [.forex, .crypto, .stocks, .commodities, .indices, .futures]
//        
//        return orderedClasses.compactMap { assetClass in
//            guard let markers = grouped[assetClass], !markers.isEmpty else { return nil }
//            let topMarkers = Array(markers.sorted { $0.likeCount > $1.likeCount }.prefix(5))
//            return (assetClass: assetClass, markers: topMarkers)
//        }
//    }
//    
//    private var assetClassMarkersContent: some View {
//        Group {
//            if isLoading {
//                UnifiedLoadingState(message: "Loading markers...")
//            } else if leftDrawerViewModel.symbolGroupedMarkers.isEmpty {
//                UnifiedEmptyState(
//                    icon: "chart.line.uptrend.xyaxis",
//                    title: "No Markers by Symbol",
//                    subtitle: "Markers will be grouped by asset class"
//                )
//                .padding(.top, 40)
//            } else {
//                ScrollView(.vertical, showsIndicators: false) {
//                    VStack(spacing: 10) {
//                        ForEach(markersGroupedByAssetClass, id: \.assetClass) { group in
//                            AssetClassMarkerGroup(
//                                assetClass: group.assetClass,
//                                markers: group.markers,
//                                likedMarkerId: $likedMarkerId,
//                                onLike: { marker in handleLike(marker: marker) },
//                                onTap: { marker in handleMarkerTap(marker: marker) }
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Following Markers Content
//    
//    private var followingMarkersContent: some View {
//        Group {
//            if isLoading {
//                UnifiedLoadingState(message: "Loading markers...")
//            } else if leftDrawerViewModel.followingMarkers.isEmpty {
//                UnifiedEmptyState(
//                    icon: "person.2",
//                    title: "No Markers from Following",
//                    subtitle: "Follow traders to see their markers here"
//                )
//                .padding(.top, 40)
//            } else {
//                ScrollView(.vertical, showsIndicators: false) {
//                    LazyVStack(spacing: 10) {
//                        ForEach(leftDrawerViewModel.followingMarkers) { marker in
//                            TopMarkerCard(
//                                marker: marker,
//                                showMyBadge: marker.isCurrentUserMarker,
//                                likedMarkerId: $likedMarkerId,
//                                onLike: { handleLike(marker: marker) },
//                                onTap: { handleMarkerTap(marker: marker) }
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - My Markers Content
//    
//    private var myMarkersContent: some View {
//        Group {
//            if isLoading {
//                UnifiedLoadingState(message: "Loading markers...")
//            } else if leftDrawerViewModel.myMarkers.isEmpty {
//                UnifiedEmptyState(
//                    icon: "mappin.and.ellipse",
//                    title: "No Markers Yet",
//                    subtitle: "Place markers on charts to see them here"
//                )
//                .padding(.top, 40)
//            } else {
//                ScrollView(.vertical, showsIndicators: false) {
//                    LazyVStack(spacing: 10) {
//                        ForEach(leftDrawerViewModel.myMarkers) { marker in
//                            TopMarkerCard(
//                                marker: marker,
//                                showMyBadge: true,
//                                likedMarkerId: $likedMarkerId,
//                                onLike: { handleLike(marker: marker) },
//                                onTap: { handleMarkerTap(marker: marker) }
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Actions
//    
//    private func handleLike(marker: TopMarkerDTO) {
//        let generator = UIImpactFeedbackGenerator(style: .light)
//        generator.impactOccurred()
//        
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//            likedMarkerId = marker.id
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            likedMarkerId = nil
//        }
//        
//        Task {
//            await leftDrawerViewModel.toggleMarkerLike(markerId: marker.id, appState: appState)
//        }
//    }
//    
//    private func handleMarkerTap(marker: TopMarkerDTO) {
//        let generator = UIImpactFeedbackGenerator(style: .medium)
//        generator.impactOccurred()
//        
//        if let onNavigate = onNavigateToMarker {
//            onNavigate(marker)
//            return
//        }
//        
//        leftDrawerViewModel.requestNavigationToMarker(marker)
//    }
//}
//
//// MARK: - ================================================================================================
//// MARK: - TOP MARKER CARD
//// MARK: - ================================================================================================
//
//struct TopMarkerCard: View {
//    let marker: TopMarkerDTO
//    var showMyBadge: Bool = false
//    @Binding var likedMarkerId: UUID?
//    let onLike: () -> Void
//    let onTap: () -> Void
//    
//    @State private var isPressed: Bool = false
//    
//    private var isLikeAnimating: Bool {
//        likedMarkerId == marker.id
//    }
//    
//    var body: some View {
//        Button(action: onTap) {
//            VStack(spacing: 0) {
//                // MARK: - Main Content Area
//                VStack(alignment: .leading, spacing: 5) {
//                    // Top row: Icon + Symbol + Type + Stats
//                    HStack(spacing: 8) {
//                        // Marker type icon
//                        MarkerTypeIcon(type: marker.type)
//                        
//                        // Symbol with brand color
//                        HStack(spacing: 4) {
//                            if let brandColor = marker.symbolBrandColor {
//                                Circle()
//                                    .fill(Color(hex: brandColor) ?? .blue)
//                                    .frame(width: 6, height: 6)
//                            }
//                            Text(marker.symbolTicker)
//                                .font(.system(size: 14, weight: .bold))
//                                .foregroundColor(AppColors.whiteText)
//                        }
//                        
//                        // Marker type label
//                        Text(marker.type.rawValue)
//                            .font(.system(size: 11, weight: .medium))
//                            .foregroundColor(marker.type.color.opacity(0.9))
//                        
//                        if showMyBadge {
//                            Text("YOU")
//                                .font(.system(size: 8, weight: .bold))
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 5)
//                                .padding(.vertical, 2)
//                                .background(Capsule().fill(Color.blue.opacity(0.6)))
//                        }
//                        
//                        Spacer()
//                        
//                        // Stats (top right)
//                        HStack(spacing: 8) {
//                            // Comments
//                            HStack(spacing: 2) {
//                                Image(systemName: "bubble.right")
//                                    .font(.system(size: 9))
//                                Text("\(marker.commentCount)")
//                                    .font(.system(size: 10, weight: .medium))
//                            }
//                            .foregroundColor(AppColors.whiteText.opacity(0.5))
//                            
//                            // Likes
//                            Button(action: onLike) {
//                                HStack(spacing: 2) {
//                                    Image(systemName: marker.isLikedByCurrentUser ? "heart.fill" : "heart")
//                                        .font(.system(size: 9))
//                                        .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
//                                    Text("\(marker.likeCount)")
//                                        .font(.system(size: 10, weight: .medium))
//                                }
//                                .foregroundColor(marker.isLikedByCurrentUser ? .red : AppColors.whiteText.opacity(0.5))
//                            }
//                            .buttonStyle(.plain)
//                        }
//                    }
//                    
//                    // Note preview
//                    if let note = marker.notePreview, !note.isEmpty {
//                        Text(note)
//                            .font(.system(size: 12))
//                            .foregroundColor(AppColors.whiteText.opacity(0.75))
//                            .lineLimit(2)
//                            .multilineTextAlignment(.leading)
//                            .padding(.leading, 40) // Align with content after icon
//                    }
//                }
//                .padding(.horizontal, 12)
//                .padding(.top, 10)
//                .padding(.bottom, 8)
//                
//                // MARK: - Author Footer Bar
//                HStack(spacing: 6) {
//                    // Username
//                    Text(marker.authorUsername)
//                        .font(.system(size: 11, weight: .semibold))
//                        .foregroundColor(AppColors.whiteText.opacity(0.9))
//                    
//                    // Online indicator
//                    if marker.authorIsOnline {
//                        Circle()
//                            .fill(Color.green)
//                            .frame(width: 5, height: 5)
//                    }
//                    
//                    // Separator dot
//                    Circle()
//                        .fill(AppColors.whiteText.opacity(0.3))
//                        .frame(width: 3, height: 3)
//                    
//                    // Role with color
//                    Text(marker.authorRole.rawValue)
//                        .font(.system(size: 10, weight: .medium))
//                        .foregroundColor(marker.authorRole.roleForegroundColor.opacity(0.9))
//                    
//                    // Separator dot
//                    Circle()
//                        .fill(AppColors.whiteText.opacity(0.3))
//                        .frame(width: 3, height: 3)
//                    
//                    // Reputation
//                    HStack(spacing: 2) {
//                        Image(systemName: "shield.fill")
//                            .font(.system(size: 8))
//                        Text("\(marker.authorReputation)")
//                            .font(.system(size: 10, weight: .semibold))
//                    }
//                    .foregroundColor(AppColors.accentColor.opacity(0.9))
//                    
//                    Spacer()
//                    
//                    // Time
//                    Text(marker.createdAtFormatted)
//                        .font(.system(size: 10))
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(
//                    UnevenRoundedRectangle(
//                        cornerRadii: .init(
//                            topLeading: 0,
//                            bottomLeading: 12,
//                            bottomTrailing: 12,
//                            topTrailing: 0
//                        )
//                    )
//                    .fill(Color.white.opacity(0.06))
//                )
//            }
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color.white.opacity(isPressed ? 0.06 : 0.03))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
//                    )
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//        .scaleEffect(isPressed ? 0.98 : 1.0)
//        .animation(.easeInOut(duration: 0.15), value: isPressed)
//        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = pressing
//            }
//        }, perform: {})
//    }
//}
//
//// MARK: - ================================================================================================
//// MARK: - SUPPORTING VIEWS
//// MARK: - ================================================================================================
//
//// MARK: - Marker Type Icon
//
//struct MarkerTypeIcon: View {
//    let type: MarkerType
//    
//    var body: some View {
//        ZStack {
//            Circle()
//                .fill(type.color.opacity(0.2))
//            Image(systemName: type.icon)
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundColor(type.color)
//        }
//        .frame(width: 32, height: 32)
//    }
//}
//
//// MARK: - Asset Class Marker Group
//
//struct AssetClassMarkerGroup: View {
//    let assetClass: AssetClass
//    let markers: [TopMarkerDTO]
//    @Binding var likedMarkerId: UUID?
//    let onLike: (TopMarkerDTO) -> Void
//    let onTap: (TopMarkerDTO) -> Void
//    
//    /// Color for asset class (matches WatchlistView)
//    private var assetClassColor: Color {
//        switch assetClass {
//        case .forex: return .blue
//        case .crypto: return .orange
//        case .stocks: return .green
//        case .commodities: return .yellow
//        case .indices: return .purple
//        case .futures: return .cyan
//        }
//    }
//    
//    var body: some View {
//        UnifiedDisclosureGroup(
//            title: assetClass.rawValue,
//            count: markers.count,
//            icon: assetClass.icon,
//            iconColor: assetClassColor,
//            isExpandedByDefault: true
//        ) {
//            VStack(spacing: 8) {
//                ForEach(markers) { marker in
//                    TopMarkerCard(
//                        marker: marker,
//                        showMyBadge: marker.isCurrentUserMarker,
//                        likedMarkerId: $likedMarkerId,
//                        onLike: { onLike(marker) },
//                        onTap: { onTap(marker) }
//                    )
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Symbol Marker Group (kept for backwards compatibility if needed)
//
//struct SymbolMarkerGroup: View {
//    let symbolTicker: String
//    let markers: [TopMarkerDTO]
//    @Binding var likedMarkerId: UUID?
//    let onLike: (TopMarkerDTO) -> Void
//    let onTap: (TopMarkerDTO) -> Void
//    
//    private var brandColor: Color {
//        if let colorHex = markers.first?.symbolBrandColor {
//            return Color(hex: colorHex) ?? .blue
//        }
//        return .blue
//    }
//    
//    var body: some View {
//        UnifiedDisclosureGroup(
//            title: symbolTicker,
//            count: markers.count,
//            icon: "chart.line.uptrend.xyaxis",
//            iconColor: brandColor,
//            isExpandedByDefault: true
//        ) {
//            VStack(spacing: 8) {
//                ForEach(markers) { marker in
//                    TopMarkerCard(
//                        marker: marker,
//                        showMyBadge: marker.isCurrentUserMarker,
//                        likedMarkerId: $likedMarkerId,
//                        onLike: { onLike(marker) },
//                        onTap: { onTap(marker) }
//                    )
//                }
//            }
//        }
//    }
//}
//
//// MARK: - ================================================================================================
//// MARK: - PREVIEW
//// MARK: - ================================================================================================
//
//#if DEBUG
//#Preview("Top Markers View") {
//    ZStack {
//        Color.black.ignoresSafeArea()
//        
//        ScrollView {
//            VStack(spacing: 16) {
//                TopMarkerCard(
//                    marker: TopMarkerDTO.sample,
//                    showMyBadge: false,
//                    likedMarkerId: .constant(nil),
//                    onLike: {},
//                    onTap: {}
//                )
//                
//                TopMarkerCard(
//                    marker: TopMarkerDTO.sample2,
//                    showMyBadge: false,
//                    likedMarkerId: .constant(nil),
//                    onLike: {},
//                    onTap: {}
//                )
//                
//                TopMarkerCard(
//                    marker: TopMarkerDTO.sample3,
//                    showMyBadge: true,
//                    likedMarkerId: .constant(nil),
//                    onLike: {},
//                    onTap: {}
//                )
//            }
//            .padding()
//        }
//    }
//}
//#endif
