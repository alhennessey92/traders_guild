//
//  MainView.swift
//  traders_guild
//
//  UPDATED VERSION - Integrated RLMessagingManager and RLRightDrawerViewModel
//  for live backend messaging (chatrooms and DMs).
//

import SwiftUI
import UIKit

// MARK: - Constants
enum LayoutConstants {
    static let drawerWidthRatio: CGFloat = 0.9
    static let drawerDismissThreshold: CGFloat = 100
    static let overlayOpacity: CGFloat = 0.4
    static let cornerRadius: CGFloat = 33
    static let shadowRadius: CGFloat = 8
}

enum AnimationConstants {
    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
}

private enum MarkerAuthorProfileRoute: Identifiable {
    case currentUser
    case guildMember(RLGuildMemberDTO)

    var id: String {
        switch self {
        case .currentUser:
            return "current-user"
        case .guildMember(let member):
            return "member-\(member.userId.uuidString)"
        }
    }
}

// MARK: - Main View
struct MainView: View {
    // MARK: - Properties
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager       // NEW: chatrooms/DMs
    
    @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
    @StateObject private var rightDrawerViewModel = RLRightDrawerViewModel()  // NEW: Uses RLAppState
    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Chart State
    @StateObject private var chartControlVM = ChartControlViewModel()
    @StateObject private var chartDataManager = ChartDataManager()
    @StateObject private var chartViewModel: ChartViewModel
    @StateObject private var chartGestureState = ChartGestureState()
    @StateObject private var placementState = MarkerPlacementState()
    @StateObject private var markerOverlayState = MarkerOverlayState()
    
    @State private var fadeIn: Bool = false
    
    // MARK: - Drawer State Management
    @State private var showLeftDrawer: Bool = false
    @State private var showRightDrawer: Bool = false
    @State private var showOverlay: Bool = false
    @State private var leftDragTranslation: CGFloat = 0
    @State private var rightDragTranslation: CGFloat = 0
    
    // MARK: - Bottom Sheet State
    @State private var showBottomSheet: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.11)
    
    // MARK: - Sheet Overlay State
    @State private var showSheetOverlay: Bool = false
    @State private var dismissRightSheetsSignal: Bool = false
    @State private var dismissLeftSheetsSignal: Bool = false
    
    // MARK: - Indicator Panel State
    @State private var rsiPanelHeight: CGFloat = 120
    @State private var macdPanelHeight: CGFloat = 140
    @State private var stochasticPanelHeight: CGFloat = 120
    @State private var cciPanelHeight: CGFloat = 120
    @State private var williamsRPanelHeight: CGFloat = 120
    @State private var atrPanelHeight: CGFloat = 120
    @State private var volumePanelHeight: CGFloat = 120

    // MARK: - Timeframe Panel State
    @StateObject private var timeframePanelManager = TimeframePanelManager()
    @State private var tfPanel1Height: CGFloat = 140
    @State private var tfPanel2Height: CGFloat = 140
    @State private var selectedViewingMarkerAuthorRoute: MarkerAuthorProfileRoute?
    @State private var markerAuthorProfileDetent: PresentationDetent = .fraction(0.6)
    
    // MARK: - Computed Properties
    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    private var drawerWidth: CGFloat {
        screenSize.width * LayoutConstants.drawerWidthRatio
    }

    /// Marker timestamp for timeframe panels — uses viewed marker or placement anchor
    private var activeMarkerTimestamp: Date {
        if let viewedMarker = chartViewModel.selectedMarkerForSheet {
            return viewedMarker.marker.candleTimestamp
        }
        return placementState.anchorDraft?.payload.anchorTime ?? Date()
    }

    /// Intent color for timeframe panels — uses viewed marker or placement intent
    private var activeMarkerIntentColor: Color {
        if let viewedMarker = chartViewModel.selectedMarkerForSheet {
            return viewedMarker.intent.color
        }
        return placementState.intent.color
    }

    private var indicatorPanelHeights: [CGFloat] {
        chartViewModel.indicatorManager.activeIndicators.activePanelTypes.map(indicatorPanelHeight(for:))
    }

    private var timeframePanelHeights: [CGFloat] {
        let count = timeframePanelManager.activePanelCount
        if count >= 2 {
            return [tfPanel1Height, tfPanel2Height]
        }
        if count == 1 {
            return [tfPanel1Height]
        }
        return []
    }

    /// Calculate total height of active indicator panels for bottom padding.
    private var indicatorPanelsTotalHeight: CGFloat {
        ChartPanelReserveCalculator.stackReserve(panelHeights: indicatorPanelHeights)
    }

    /// Calculate total height of active timeframe panels for bottom padding.
    private var timeframePanelsTotalHeight: CGFloat {
        ChartPanelReserveCalculator.stackReserve(panelHeights: timeframePanelHeights)
    }

    /// Combined stack height for indicator + timeframe panel overlays.
    private var chartPanelsTotalHeight: CGFloat {
        indicatorPanelsTotalHeight + timeframePanelsTotalHeight
    }

    /// Label-strip reserve only when the bottom-most visible panel is expanded.
    private var chartPanelsBottomLabelStripReserve: CGFloat {
        ChartPanelReserveCalculator.bottomBoundaryLabelReserve(
            indicatorPanelHeights: indicatorPanelHeights,
            timeframePanelHeights: timeframePanelHeights
        )
    }

    /// When the bottom panel is collapsed, lift the panel stack so it doesn't cover
    /// the chart x-axis strip.
    private var collapsedPanelXAxisClearance: CGFloat {
        guard chartPanelsTotalHeight > 0 else { return 0 }
        return chartPanelsBottomLabelStripReserve == 0
            ? ChartPanelReserveCalculator.panelXAxisLabelStripHeight
            : 0
    }
    
    /// Bottom padding for controls that need to float above indicator panels
    private var bottomControlsPadding: CGFloat {
        // Base padding for minimized bottom sheet + indicator panels
        return chartPanelsTotalHeight + 100
    }

    private func indicatorPanelHeight(for panelType: PanelIndicatorType) -> CGFloat {
        switch panelType {
        case .rsi:
            return rsiPanelHeight
        case .macd:
            return macdPanelHeight
        case .stochastic:
            return stochasticPanelHeight
        case .cci:
            return cciPanelHeight
        case .williamsR:
            return williamsRPanelHeight
        case .atr:
            return atrPanelHeight
        case .volume:
            return volumePanelHeight
        }
    }

    // MARK: - Initialization
    init() {
        let dataManager = ChartDataManager()
        _chartDataManager = StateObject(wrappedValue: dataManager)
        // ChartViewModel will be properly initialized in onAppear with rlAppState
        // For now, create a temporary one - it will be replaced
        _chartViewModel = StateObject(wrappedValue: ChartViewModel(
            appState: RLAppState(),
            dataManager: dataManager,
            api: RealAPIService()
        ))
    }
    
    // MARK: - Body
    var body: some View {
        if let user = rlAppState.currentUser,
           let guild = rlAppState.currentGuild {
            ZStack {
                // MARK: - Main Content Layer
                mainContentStack
                    .disabled(showLeftDrawer || showRightDrawer)
                
                // MARK: - Chart Panels Overlay (Timeframe + Indicator)
                // Positioned ABOVE main content, BELOW bottom sheet
                // allowsHitTesting only on panels themselves (not the spacer above)
                // so chart controls beneath remain tappable
                // Visible in placement/viewing so linked panel indicators remain visible.
                if chartViewModel.indicatorManager.shouldShowAnyPanel || timeframePanelManager.hasActivePanels {
                    VStack(spacing: 0) {
                        Spacer()
                            .allowsHitTesting(false)

                        // Timeframe panels (above indicator panels)
                        TimeframePanelContainer(
                            timeframePanelManager: timeframePanelManager,
                            markerTimestamp: activeMarkerTimestamp,
                            intentColor: activeMarkerIntentColor,
                            baseCandleWidth: 12,
                            candleSpacing: 4,
                            indicatorPanelCount: chartViewModel.indicatorManager.activeIndicators.activePanelTypes.count,
                            panel1Height: $tfPanel1Height,
                            panel2Height: $tfPanel2Height
                        )

                        // Indicator panels
                        IndicatorPanelContainer(
                            indicatorManager: chartViewModel.indicatorManager,
                            chartData: chartViewModel.dataManager,
                            gestureState: chartGestureState,
                            baseCandleWidth: 12,
                            candleSpacing: 4,
                            timeframe: chartViewModel.currentTimeframe,
                            timeframePanelCount: timeframePanelManager.activePanelCount,
                            rsiPanelHeight: $rsiPanelHeight,
                            macdPanelHeight: $macdPanelHeight,
                            stochasticPanelHeight: $stochasticPanelHeight,
                            cciPanelHeight: $cciPanelHeight,
                            williamsRPanelHeight: $williamsRPanelHeight,
                            atrPanelHeight: $atrPanelHeight,
                            volumePanelHeight: $volumePanelHeight
                        )
                        // Keep bottom-sheet clearance. Mask only while an expanded bottom panel
                        // owns the x-axis strip; keep transparent when collapsed so controls remain visible.
                        Rectangle()
                            .fill(chartPanelsBottomLabelStripReserve > 0 ? AppColors.systemBlack : Color.clear)
                            .frame(height: 100 + collapsedPanelXAxisClearance)
                            .allowsHitTesting(false)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                // MARK: - Overlay Layer
                if showOverlay {
                    overlayView
                        .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
                        .animation(.easeOut(duration: 0.4), value: showRightDrawer)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dismissRightSheetsSignal = true
                                    if showLeftDrawer && value.translation.width < 0 {
                                        leftDragTranslation = value.translation.width
                                    } else if showRightDrawer && value.translation.width > 0 {
                                        rightDragTranslation = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
                                }
                        )
                }
                
                // MARK: - Drawer Layers
                leftDrawerView
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn(duration: 1.5), value: fadeIn)
                
                rightDrawerView
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn(duration: 1.5), value: fadeIn)
                
                // MARK: - Sheet Overlay Layer
                if showSheetOverlay {
                    sheetOverlayView
                        .opacity(showSheetOverlay ? 1 : 0)
                        .animation(.linear(duration: 0.05), value: showSheetOverlay)
                }
            }
            .ignoresSafeArea()
            .rlGlobalMessaging()          // RL: chatrooms/DMs sheets
            .rlGlobalMessaging()        // NEW: Chatroom/DM sheets
            
            .observeMarkerNavigation(
                leftDrawerViewModel: leftDrawerViewModel,
                chartViewModel: chartViewModel,
                gestureState: chartGestureState,
                onCloseDrawer: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showLeftDrawer = false
                        showOverlay = false
                    }
                }
            )
            
            // MARK: - Bottom Sheet
            // Bottom sheet — stays visible during placement mode with swapped content
            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer && !rlAppState.showingTransition)) {
                ChartBottomSheet(
                    controlViewModel: chartControlVM,
                    chartViewModel: chartViewModel,
                    placementState: placementState,
                    markerOverlayState: markerOverlayState,
                    timeframePanelManager: timeframePanelManager,
                    selectedDetent: $selectedDetent,
                    onNavigateToMarker: { marker in
                        leftDrawerViewModel.requestNavigationToMarker(marker)
                    },
                    onPlaceMarker: {
                        NotificationCenter.default.post(name: .placeMarkerRequested, object: nil)
                    },
                    onViewingAuthorTap: { marker in
                        if marker.author.userId == rlAppState.currentUser?.id {
                            markerAuthorProfileDetent = .fraction(0.6)
                            selectedViewingMarkerAuthorRoute = .currentUser
                        } else {
                            selectedViewingMarkerAuthorRoute = .guildMember(marker.author)
                        }
                    }
                )
                .environmentObject(rlAppState)
                .presentationDetents([.fraction(0.11), .fraction(0.35), .fraction(0.5), .fraction(0.9)],
                                      selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled(true)
                .presentationContentInteraction(.resizes)
                .presentationBackground {
                    ZStack {
                        Color.clear
                            .background(.ultraThinMaterial)
                        AppColors.drawerBackground.opacity(0.4)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.5)) {
                    fadeIn = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        showBottomSheet = true
                    }
                }
                leftDrawerViewModel.configure(with: rlAppState)
                rightDrawerViewModel.configure(with: rlMessagingManager)
                rightDrawerViewModel.configurePresence(with: rlAppState)
                
                // Configure ChartViewModel with proper RLAppState and RealAPIService
                chartViewModel.configure(appState: rlAppState, api: rlAppState.realApi)
                timeframePanelManager.api = rlAppState.realApi

                print(rlAppState.currentUser?.displayUsername ?? "Username")
                print(rlAppState.currentGuild?.name ?? "Guild Name")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
            .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
            
            .environmentObject(leftDrawerViewModel)
            .environmentObject(rightDrawerViewModel)
            .environmentObject(notificationNavigationManager)
            .task {
                // Use rlAppState guild ID for all data loading
                guard let rlGuildId = rlAppState.currentGuild?.id else { return }
                
                // leftDrawerViewModel uses rlGuildId for all data via rlAppState
                await leftDrawerViewModel.preloadData(for: rlGuildId, rlAppState: rlAppState)
                
                // NEW: rightDrawerViewModel now uses RLAppState for live messaging data
                await rightDrawerViewModel.preloadData(for: rlGuildId, appState: rlAppState)
                
                // Configure notification navigation (still uses old system for now)
                notificationNavigationManager.configure(
                    rlAppState: rlAppState,
                    messagingManager: rlMessagingManager,
                    rightDrawerViewModel: rightDrawerViewModel
                )
                
                // Initialize chart with data
                await chartViewModel.initialize()
                
                rlAppState.chartDidBecomeReady()
            }
            .onChange(of: rlAppState.currentGuild?.id) { oldValue, newValue in
                if let guildId = newValue, oldValue != newValue {
                    Task {
                        leftDrawerViewModel.clearCache()
                        rightDrawerViewModel.clearCache()
                        
                        // Uses real rlAppState guild ID for all data
                        await leftDrawerViewModel.preloadData(for: guildId, rlAppState: rlAppState)
                        await rightDrawerViewModel.preloadData(for: guildId, appState: rlAppState)
                        
                        await chartViewModel.initialize()
                        rlAppState.chartDidBecomeReady()
                    }
                }
            }
            .onChange(of: chartControlVM.isMarkerPlacementMode) { _, isPlacing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isPlacing {
                        // Show placement panel at compact height — maximize chart space
                        selectedDetent = .fraction(0.35)
                    }
                }
            }
            .onChange(of: chartViewModel.selectedMarkerForSheet?.id) { oldId, newId in
                chartControlVM.isMarkerViewingMode = (newId != nil)
                handleMarkerViewingSelectionChange(oldId: oldId, newId: newId)
                if newId != nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDetent = .fraction(0.11)
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    if rlAppState.accessToken != nil {
                        rlAppState.connectRealTimeService()
                    }
                    Task { await rlAppState.refreshCurrentGuildReputation() }
                case .inactive, .background:
                    rlAppState.disconnectRealTimeService()
                @unknown default:
                    break
                }
            }
        } else {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Reconnecting...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                Task {
                    if rlAppState.currentUser != nil && rlAppState.currentGuild == nil {
                        await rlAppState.openGuildSelector()
                    } else if rlAppState.currentUser == nil {
                        rlAppState.logout()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var mainContentStack: some View {
        NavigationStack {
            ZStack {
                StaticBackgroundView()
                mainChartContentLayer
            }
            .toolbar {
                mainToolbarContent
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                configureNavigationBarAppearance()
            }
            .sheet(item: $selectedViewingMarkerAuthorRoute) { route in
                switch route {
                case .currentUser:
                    UserProfileDetailView(selectedDetent: $markerAuthorProfileDetent)
                        .environmentObject(rlAppState)
                        .environmentObject(leftDrawerViewModel)
                case .guildMember(let member):
                    GuildUserDetailViewRL(member: member)
                        .environmentObject(rlAppState)
                }
            }
        }
    }

    private var mainChartContentLayer: some View {
        VStack(spacing: 0) {
            if let user = rlAppState.currentUser,
               let guild = rlAppState.currentGuild {
                chartView(controlViewModel: chartControlVM, user: user, guild: guild)
            }
        }
        .opacity(fadeIn ? 1 : 0)
        .animation(.easeIn(duration: 1.5), value: fadeIn)
        .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
            if let symbol = notification.userInfo?["symbol"] as? RLTradingSymbolDTO {
                dismissKeyboard()
                chartViewModel.setSymbol(symbol)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showLeftDrawer = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSharedMarker)) { notification in
            Task {
                await handleOpenSharedMarker(notification.userInfo)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildWatchlistUpdated)) { _ in
            guard let guildId = rlAppState.currentGuild?.id else { return }
            Task {
                do {
                    async let guildTask = rlAppState.fetchGuildWatchlist(guildId: guildId)
                    async let globalTask = rlAppState.realApi.getGlobalSymbols(guildId: guildId, limit: 100)
                    let (guildWatchlist, globalSymbols) = try await (guildTask, globalTask)
                    await MainActor.run {
                        leftDrawerViewModel.guildTradingWatchlist = guildWatchlist.symbols.map { $0.symbol }
                        leftDrawerViewModel.globalTradingSymbols = globalSymbols.symbols
                    }
                } catch {
                    // Errors are surfaced via RLAppState.
                }
                await chartViewModel.reloadData()
            }
        }
    }

    @ToolbarContentBuilder
    private var mainToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            mainToolbarLeadingItem
        }
        ToolbarItem(placement: .principal) {
            mainToolbarPrincipalItem
        }
        mainToolbarTrailingContent
    }

    @ViewBuilder
    private var mainToolbarLeadingItem: some View {
        if chartControlVM.isMarkerPlacementMode {
            markerToolbarCloseButton(
                iconColor: .white,
                tintColor: AppColors.statusNegative55
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    chartControlVM.cancelMarkerPlacement()
                }
            }
        } else if chartControlVM.isMarkerViewingMode {
            markerToolbarCloseButton(
                iconColor: AppColors.whiteText.opacity(0.95),
                tintColor: AppColors.surfaceWhite18
            ) {
                closeMarkerViewingMode()
            }
        } else {
            ToolbarIconButton(
                systemName: "shield.pattern.checkered",
                backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                fontType: .headline,
                symbolRenderingMode: .monochrome,
                foregroundStyle: AppColors.whiteText,
                padding: 8
            ) {
                toggleLeftDrawerFromToolbar()
            }
        }
    }

    @ViewBuilder
    private var mainToolbarPrincipalItem: some View {
        if chartControlVM.isMarkerPlacementMode {
            Text(placementState.toolbarInstructionText ?? "Place a Marker")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
        } else if chartControlVM.isMarkerViewingMode {
            markerViewingToolbarTitle
        } else {
            Text("TG")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(AppColors.chartLogo)
        }
    }

    @ToolbarContentBuilder
    private var mainToolbarTrailingContent: some ToolbarContent {
        if chartControlVM.isMarkerPlacementMode {
            if placementState.shouldShowDrawingDiscardAction {
                ToolbarItem(placement: .topBarTrailing) {
                    drawingDiscardToolbarButton
                }
            }
        } else if chartControlVM.isMarkerViewingMode {
            ToolbarItem(placement: .topBarTrailing) {
                markerViewingAuthorToolbarButton
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                rightDrawerToolbarButton
            }
        }
    }

    private var drawingDiscardToolbarButton: some View {
        Button {
            placementState.discardActiveDrawingAndExit()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.whiteText.opacity(0.95))
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .fill(AppColors.surfaceWhite12)
                        Circle()
                            .stroke(AppColors.surfaceWhite24, lineWidth: 0.8)
                    }
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var rightDrawerToolbarButton: some View {
        ZStack(alignment: .topTrailing) {
            if rightDrawerViewModel.totalUnreadCount > 0 {
                ToolbarIconButton(
                    systemName: "message.badge.filled.fill",
                    backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                    fontType: .subheadline,
                    symbolRenderingMode: .palette,
                    foregroundStyles: [AppColors.accentColor, AppColors.whiteText],
                    padding: 8
                ) {
                    toggleRightDrawerFromToolbar()
                }
            } else {
                ToolbarIconButton(
                    systemName: "message.badge.filled.fill",
                    backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                    fontType: .subheadline,
                    symbolRenderingMode: .monochrome,
                    foregroundStyle: AppColors.whiteText,
                    padding: 8
                ) {
                    toggleRightDrawerFromToolbar()
                }
            }
        }
    }

    private func toggleLeftDrawerFromToolbar() {
        withAnimation(AnimationConstants.standard) {
            dismissKeyboard()
            selectedDetent = .fraction(0.11)
            showLeftDrawer.toggle()
            showRightDrawer = false
            showOverlay = showLeftDrawer
        }
    }

    private func toggleRightDrawerFromToolbar() {
        withAnimation(AnimationConstants.standard) {
            dismissKeyboard()
            selectedDetent = .fraction(0.11)
            showRightDrawer.toggle()
            showLeftDrawer = false
            showOverlay = showRightDrawer
        }
    }
    
    // UPDATED: Pass total indicator panel height for proper bottom controls positioning
    private func chartView(controlViewModel: ChartControlViewModel, user: RLUserDTO, guild: RLGuildDTO) -> some View {
        let currentMember: RLGuildMemberDTO
        if let membership = rlAppState.currentMembership {
            currentMember = RLGuildMemberDTO.fromCurrentUser(user: user, membership: membership)
        } else {
            currentMember = RLGuildMemberDTO(
                membershipId: UUID(),
                role: "member",
                reputation: 0,
                contributionScore: 0,
                dateJoined: Date(),
                accuracyRate: nil,
                mutedUntil: nil,
                suspendedUntil: nil,
                userId: user.id,
                username: user.username,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                isOnline: user.isOnline,
                globalReputation: user.globalReputation,
                isFriend: false,
                friendshipStatus: nil,
                isBlocked: false,
                isBlockedBy: false
            )
        }

        return TradingChartView(
            userId: user.id,
            username: user.username,
            guildId: guild.id,
            currentUserMember: currentMember,
            controlViewModel: controlViewModel,
            chartViewModel: chartViewModel,
            gestureState: chartGestureState,
            placementState: placementState,
            rsiPanelHeight: $rsiPanelHeight,
            indicatorPanelBottomPadding: chartPanelsTotalHeight,
            panelBottomBoundaryLabelReserve: chartPanelsBottomLabelStripReserve
        )
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = nil

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
    
    private var overlayView: some View {
        AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(AnimationConstants.standard) {
                    dismissKeyboard()
                    showLeftDrawer = false
                    showRightDrawer = false
                    leftDragTranslation = 0
                    rightDragTranslation = 0
                    dismissRightSheetsSignal = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
    }
    
    private var sheetOverlayView: some View {
        AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity * 0.8)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                dismissRightSheetsSignal = true
                dismissLeftSheetsSignal = true
            }
            .simultaneousGesture(DragGesture().onChanged { _ in
                dismissRightSheetsSignal = true
                dismissLeftSheetsSignal = true
            })
    }
    
    // FIXED: Using LeftDrawerMainView (correct name)
    private var leftDrawerView: some View {
        HStack(spacing: 0) {
            LeftDrawerMainView(
                sheetOverlayVisible: $showSheetOverlay,
                dismissSheetsSignal: $dismissLeftSheetsSignal,
                onClose: {
                    dismissKeyboard()
                    withAnimation(AnimationConstants.standard) {
                        showLeftDrawer = false
                        leftDragTranslation = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOverlay = false
                    }
                },
                currentSymbolId: chartViewModel.currentSymbol?.id
            )
            .frame(width: drawerWidth)
            .frame(maxHeight: CGFloat.infinity)
            .offset(x: leftDragTranslation)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            leftDragTranslation = value.translation.width
                        }
                    }
                    .onEnded { value in
                        handleDrawerDragEnd(currentPosition: leftDragTranslation)
                    }
            )
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .offset(x: showLeftDrawer ? 0 : -drawerWidth)
        .animation(AnimationConstants.standard, value: showLeftDrawer)
    }
    
    // UPDATED: Using RLRightDrawerMainView for live messaging
    private var rightDrawerView: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            RLRightDrawerMainView(
                onClose: {
                    dismissKeyboard()
                    withAnimation(AnimationConstants.standard) {
                        showRightDrawer = false
                        rightDragTranslation = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOverlay = false
                    }
                }
            )
            .frame(width: drawerWidth)
            .frame(maxHeight: .infinity)
            .offset(x: rightDragTranslation)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 {
                            rightDragTranslation = value.translation.width
                        }
                    }
                    .onEnded { value in
                        handleDrawerDragEnd(currentPosition: rightDragTranslation)
                    }
            )
        }
        .frame(maxHeight: .infinity)
        .offset(x: showRightDrawer ? 0 : drawerWidth)
        .animation(AnimationConstants.standard, value: showRightDrawer)
    }
    
    // MARK: - Helper Functions
    
    private func handleDrawerDragEnd(currentPosition: CGFloat) {
        if showLeftDrawer {
            if currentPosition < -LayoutConstants.drawerDismissThreshold {
                dismissKeyboard()
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    leftDragTranslation = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                withAnimation(AnimationConstants.standard) {
                    leftDragTranslation = 0
                }
            }
        } else if showRightDrawer {
            if currentPosition > LayoutConstants.drawerDismissThreshold {
                dismissKeyboard()
                withAnimation(AnimationConstants.standard) {
                    showRightDrawer = false
                    rightDragTranslation = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                withAnimation(AnimationConstants.standard) {
                    rightDragTranslation = 0
                }
            }
        }
    }
    
    private func markerToolbarCloseButton(
        iconColor: Color,
        tintColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .fill(tintColor)
                        Circle()
                            .stroke(AppColors.surfaceWhite24, lineWidth: 0.8)
                    }
                )
                .clipShape(Circle())
                .shadow(color: tintColor.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var markerViewingToolbarTitle: some View {
        if let marker = chartViewModel.selectedMarkerForSheet {
            HStack(spacing: 10) {
                UnifiedMarkerBadge(
                    intent: marker.intent,
                    alertSeverity: marker.alertSeverity,
                    size: 30
                )
                Text("\(marker.intent.displayName) Marker")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        } else {
            Text("Viewing Marker")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var markerViewingAuthorToolbarButton: some View {
        if let marker = chartViewModel.selectedMarkerForSheet {
            Button {
                if marker.author.userId == rlAppState.currentUser?.id {
                    markerAuthorProfileDetent = .fraction(0.6)
                    selectedViewingMarkerAuthorRoute = .currentUser
                } else {
                    selectedViewingMarkerAuthorRoute = .guildMember(marker.author)
                }
            } label: {
                UnifiedMemberAvatar(
                    username: marker.author.username,
                    avatarURL: marker.author.avatarUrl,
                    isOnline: marker.author.isOnline,
                    size: 28,
                    showOnlineIndicator: false
                )
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(AppColors.surfaceWhite12)
                        Circle().stroke(AppColors.surfaceWhite24, lineWidth: 0.8)
                    }
                )
                .clipShape(Circle())
                .shadow(color: AppColors.surfaceWhite12.opacity(0.35), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
    }

    private func closeMarkerViewingMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            chartViewModel.markerManager?.selectedMarker = nil
            chartControlVM.isMarkerViewingMode = false
        }
    }

    private func handleMarkerViewingSelectionChange(oldId: UUID?, newId: UUID?) {
        guard oldId != newId else { return }
        guard let marker = chartViewModel.selectedMarkerForSheet else {
            markerOverlayState.deactivateViewing(
                indicatorManager: chartViewModel.indicatorManager,
                candles: chartDataManager.candles
            )
            if chartControlVM.isMarkerPlacementMode {
                populateTimeframePanelsForPlacement()
            } else {
                populateTimeframePanelsForChart()
            }
            return
        }

        markerOverlayState.activateViewing(
            marker: marker,
            indicatorManager: chartViewModel.indicatorManager,
            candles: chartDataManager.candles
        )

        // Populate timeframe panels from marker's linked timeframes
        populateTimeframePanels(for: marker)
    }

    private func populateTimeframePanels(for marker: ChartMarkerUI) {
        let linkedValues = marker.marker.components.compactMap { component -> String? in
            guard component.componentTypeEnum == .timeframeLink,
                  case .timeframeLink(let payload) = component.payload else {
                return nil
            }
            return payload.timeframe
        }
        populateTimeframePanels(fromBackendValues: linkedValues)
    }

    private func populateTimeframePanelsForChart() {
        populateTimeframePanels(fromBackendValues: chartViewModel.chartTimeframeLinkManager.linkedTimeframes)
    }

    private func populateTimeframePanelsForPlacement() {
        let linkedValues = placementState.timeframeLinkDrafts.compactMap { draft -> String? in
            guard case .timeframeLink(let payload) = draft.payload else { return nil }
            return payload.timeframe
        }
        populateTimeframePanels(fromBackendValues: linkedValues)
    }

    private func populateTimeframePanels(fromBackendValues values: [String]) {
        timeframePanelManager.clearAll()

        guard let symbolId = chartViewModel.currentSymbol?.id,
              let guildId = rlAppState.currentGuild?.id else { return }

        var inserted = Set<RLChartTimeframe>()
        for value in values {
            guard let timeframe = RLChartTimeframe.fromBackendString(value),
                  inserted.insert(timeframe).inserted else {
                continue
            }
            timeframePanelManager.addPanel(timeframe: timeframe, symbolId: symbolId, guildId: guildId)
        }

        if !timeframePanelManager.panels.isEmpty {
            timeframePanelManager.reloadAll(symbolId: symbolId, guildId: guildId)
        }
    }
    
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleOpenSharedMarker(_ userInfo: [AnyHashable: Any]?) async {
        guard let userInfo, let payload = MarkerSharePayloadV1(userInfo) else { return }

        dismissKeyboard()
        withAnimation(AnimationConstants.standard) {
            showLeftDrawer = false
            showRightDrawer = false
            showOverlay = false
            leftDragTranslation = 0
            rightDragTranslation = 0
            selectedDetent = .fraction(0.11)
        }

        if chartViewModel.currentSymbol?.id != payload.symbolId {
            if let cached = chartViewModel.allAvailableSymbols.first(where: { $0.id == payload.symbolId }) {
                chartViewModel.setSymbol(cached)
            } else {
                do {
                    let symbol = try await rlAppState.realApi.getSymbol(symbolId: payload.symbolId)
                    chartViewModel.setSymbol(symbol)
                } catch {
                    rlAppState.showError(error, title: "Unable to Open Marker", style: .toast)
                    return
                }
            }
        }

        if let timeframe = RLChartTimeframe.fromBackendString(payload.timeframe),
           chartViewModel.currentTimeframe != timeframe {
            chartViewModel.setTimeframe(timeframe)
        }

        NotificationCenter.default.post(
            name: .focusSharedMarker,
            object: nil,
            userInfo: payload.notificationUserInfo
        )
    }
}

// MARK: - Drawer Side
enum DrawerSide { case left, right }





// //
// //  MainView.swift
// //  traders_guild
// //
// //  UPDATED VERSION - Fixes bottom controls overlap with multiple indicator panels
// //

// import SwiftUI
// //import SwiftTradingView

// // MARK: - Constants
// enum LayoutConstants {
//     static let drawerWidthRatio: CGFloat = 0.9
//     static let drawerDismissThreshold: CGFloat = 100
//     static let overlayOpacity: CGFloat = 0.4
//     static let cornerRadius: CGFloat = 33
//     static let shadowRadius: CGFloat = 8
// }

// enum AnimationConstants {
//     static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
//     static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
// }

// // MARK: - Main View
// struct MainView: View {
//     // MARK: - Properties
//     @EnvironmentObject var rlAppState: RLAppState
    
//     @EnvironmentObject var appState: AppState // TODO: remove
//     @EnvironmentObject var messagingManager: MessagingManager
//     @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
//     @StateObject private var rightDrawerViewModel = RightDrawerViewModel()
//     @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
//     // MARK: - Chart State
//     @StateObject private var chartControlVM = ChartControlViewModel()
//     @StateObject private var chartDataManager = ChartDataManager()
//     @StateObject private var chartViewModel: ChartViewModel
//     @StateObject private var chartGestureState = ChartGestureState()
    
//     @State private var fadeIn: Bool = false
    
//     // MARK: - Drawer State Management
//     @State private var showLeftDrawer: Bool = false
//     @State private var showRightDrawer: Bool = false
//     @State private var showOverlay: Bool = false
//     @State private var leftDragTranslation: CGFloat = 0
//     @State private var rightDragTranslation: CGFloat = 0
    
//     // MARK: - Bottom Sheet State
//     @State private var showBottomSheet: Bool = false
//     @State private var selectedDetent: PresentationDetent = .fraction(0.11)
    
//     // MARK: - Sheet Overlay State
//     @State private var showSheetOverlay: Bool = false
//     @State private var dismissRightSheetsSignal: Bool = false
//     @State private var dismissLeftSheetsSignal: Bool = false
    
//     // MARK: - Indicator Panel State
//     @State private var rsiPanelHeight: CGFloat = 120
//     @State private var macdPanelHeight: CGFloat = 140
//     @State private var stochasticPanelHeight: CGFloat = 120
//     @State private var cciPanelHeight: CGFloat = 120
//     @State private var williamsRPanelHeight: CGFloat = 120
//     @State private var atrPanelHeight: CGFloat = 120
//     @State private var volumePanelHeight: CGFloat = 120
    
//     // MARK: - Computed Properties
//     private var screenSize: CGSize {
//         UIScreen.main.bounds.size
//     }
    
//     private var drawerWidth: CGFloat {
//         screenSize.width * LayoutConstants.drawerWidthRatio
//     }
    
//     /// Calculate total height of active indicator panels for bottom padding
//     private var indicatorPanelsTotalHeight: CGFloat {
//         let activePanels = chartViewModel.indicatorManager.activeIndicators.activePanelTypes
//         guard !activePanels.isEmpty else { return 0 }
        
//         var totalHeight: CGFloat = 0
        
//         for panelType in activePanels {
//             switch panelType {
//             case .rsi:
//                 totalHeight += rsiPanelHeight + 22  // +22 for resize handle
//             case .macd:
//                 totalHeight += macdPanelHeight + 22
//             case .stochastic:
//                 totalHeight += stochasticPanelHeight + 22
//             case .cci:
//                 totalHeight += cciPanelHeight + 22
//             case .williamsR:
//                 totalHeight += williamsRPanelHeight + 22
//             case .atr:
//                 totalHeight += atrPanelHeight + 22
//             case .volume:
//                 totalHeight += volumePanelHeight + 22
//             }
//         }
        
//         // Add X-axis labels height
//         totalHeight += 22
        
//         return totalHeight
//     }
    
//     /// Bottom padding for controls that need to float above indicator panels
//     private var bottomControlsPadding: CGFloat {
//         // Base padding for minimized bottom sheet + indicator panels
//         return indicatorPanelsTotalHeight + 100
//     }
    
//     // MARK: - Initialization
//     init() {
//         let dataManager = ChartDataManager()
//         _chartDataManager = StateObject(wrappedValue: dataManager)
//         _chartViewModel = StateObject(wrappedValue: ChartViewModel(
//             appState: AppState(),
//             dataManager: dataManager,
//             api: MockAPIService()
//         ))
        
        
//     }
    
//     // MARK: - Body
//     var body: some View {
//         if let user = appState.currentUser,
//            let guild = appState.currentGuild {
//             ZStack {
//                 // MARK: - Main Content Layer
//                 mainContentStack
//                     .disabled(showLeftDrawer || showRightDrawer)
                
//                 // MARK: - Indicator Panels Overlay
//                 // Positioned ABOVE main content, BELOW bottom sheet
//                 if chartViewModel.indicatorManager.shouldShowAnyPanel {
//                     VStack {
//                         Spacer()
                        
//                         IndicatorPanelContainer(
//                             indicatorManager: chartViewModel.indicatorManager,
//                             chartData: chartViewModel.dataManager,
//                             gestureState: chartGestureState,
//                             baseCandleWidth: 12,
//                             candleSpacing: 4,
//                             timeframe: chartViewModel.currentTimeframe,
//                             rsiPanelHeight: $rsiPanelHeight,
//                             macdPanelHeight: $macdPanelHeight,
//                             stochasticPanelHeight: $stochasticPanelHeight,
//                             cciPanelHeight: $cciPanelHeight,
//                             williamsRPanelHeight: $williamsRPanelHeight,
//                             atrPanelHeight: $atrPanelHeight,
//                             volumePanelHeight: $volumePanelHeight
//                         )
                        
//                         // DYNAMIC bottom padding - accounts for minimized bottom sheet
//                         Color.clear
//                             .frame(height: 100)
//                     }
//                     .ignoresSafeArea(edges: .bottom)
//                 }
                
//                 // MARK: - Overlay Layer
//                 if showOverlay {
//                     overlayView
//                         .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
//                         .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
//                         .animation(.easeOut(duration: 0.4), value: showRightDrawer)
//                         .gesture(
//                             DragGesture()
//                                 .onChanged { value in
//                                     dismissRightSheetsSignal = true
//                                     if showLeftDrawer && value.translation.width < 0 {
//                                         leftDragTranslation = value.translation.width
//                                     } else if showRightDrawer && value.translation.width > 0 {
//                                         rightDragTranslation = value.translation.width
//                                     }
//                                 }
//                                 .onEnded { value in
//                                     handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
//                                 }
//                         )
//                 }
                
//                 // MARK: - Drawer Layers
//                 leftDrawerView
//                     .opacity(fadeIn ? 1 : 0)
//                     .animation(.easeIn(duration: 1.5), value: fadeIn)
                
//                 rightDrawerView
//                     .opacity(fadeIn ? 1 : 0)
//                     .animation(.easeIn(duration: 1.5), value: fadeIn)
                
//                 // MARK: - Sheet Overlay Layer
//                 if showSheetOverlay {
//                     sheetOverlayView
//                         .opacity(showSheetOverlay ? 1 : 0)
//                         .animation(.linear(duration: 0.05), value: showSheetOverlay)
//                 }
//             }
//             .ignoresSafeArea()
//             .globalMessaging()
            
//             .observeMarkerNavigation(
//                 leftDrawerViewModel: leftDrawerViewModel,
//                 chartViewModel: chartViewModel,
//                 gestureState: chartGestureState,
//                 onCloseDrawer: {
//                     withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                         showLeftDrawer = false
//                         showOverlay = false
//                     }
//                 }
//             )
            
//             // MARK: - Bottom Sheet
//             .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer && !rlAppState.showingTransition)) {
//                 ChartBottomSheet(
//                     controlViewModel: chartControlVM,
//                     chartViewModel: chartViewModel,
//                     selectedDetent: $selectedDetent
//                 )
//                 .presentationDetents([.fraction(0.11), .fraction(0.5), .fraction(0.9)],
//                                       selection: $selectedDetent)
//                 .presentationDragIndicator(.visible)
//                 .presentationBackgroundInteraction(.enabled)
//                 .interactiveDismissDisabled(true)
//                 .presentationContentInteraction(.resizes)
//                 .presentationBackground {
//                     ZStack {
//                         Color.clear
//                             .background(.ultraThinMaterial)
//                         AppColors.drawerBackground.opacity(0.4)
//                     }
//                 }
//             }
//             .onAppear {
//                 withAnimation(.easeIn(duration: 1.5)) {
//                     fadeIn = true
//                 }
                
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                     withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
//                         showBottomSheet = true
//                     }
//                 }
//                 print(rlAppState.currentUser?.displayUsername ?? "Username")
//                 print(rlAppState.currentGuild?.name ?? "Guild Name")
//             }
//             .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
//             .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
            
//             .environmentObject(leftDrawerViewModel)
//             .environmentObject(rightDrawerViewModel)
//             .environmentObject(notificationNavigationManager)
//             .task {
//                 // Use rlAppState guild ID for announcements (real API), fallback to old guild.id for other data
//                 let rlGuildId = rlAppState.currentGuild?.id ?? guild.id
                
//                 // leftDrawerViewModel uses rlGuildId for announcements via rlAppState
//                 await leftDrawerViewModel.preloadData(for: rlGuildId, appState: appState, rlAppState: rlAppState)
//                 // rightDrawerViewModel still uses old guild.id (no announcements)
//                 await rightDrawerViewModel.preloadData(for: guild.id, appState: appState)
                
//                 notificationNavigationManager.configure(
//                     appState: appState,
//                     messagingManager: messagingManager,
//                     rightDrawerViewModel: rightDrawerViewModel
//                 )
                
//                 // Initialize chart with data
//                 await chartViewModel.initialize()
                
//                 rlAppState.chartDidBecomeReady()
//             }
//             .onChange(of: rlAppState.currentGuild?.id) { oldValue, newValue in
//                 if let guildId = newValue, oldValue != newValue {
//                     Task {
//                         leftDrawerViewModel.clearCache()
//                         rightDrawerViewModel.clearCache()
//                         // Uses real rlAppState guild ID for announcements
//                         await leftDrawerViewModel.preloadData(for: guildId, appState: appState, rlAppState: rlAppState)
//                         await rightDrawerViewModel.preloadData(for: guildId, appState: appState)
//                         await chartViewModel.initialize()
//                         rlAppState.chartDidBecomeReady()
//                     }
//                 }
//             }
            
// //            .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
// //                if let symbol = notification.userInfo?["symbol"] as? TradingSymbolDTO {
// //                    // Dismiss keyboard first
// //                    dismissKeyboard()
// //
// //                    // Update chart
// //                    chartViewModel.setSymbol(symbol)
// //
// //                    // Close drawer if open
// //                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
// //                        showLeftDrawer = false
// //                    }
// //                }
// //            }
//         } else {
//             VStack(spacing: 20) {
//                 ProgressView()
//                     .scaleEffect(1.5)
//                 Text("Reconnecting...")
//                     .foregroundColor(.secondary)
//             }
//             .frame(maxWidth: .infinity, maxHeight: .infinity)
//             .onAppear {
//                 Task {
//                     if rlAppState.currentUser != nil && rlAppState.currentGuild == nil {
//                         await rlAppState.openGuildSelector()
//                     } else if rlAppState.currentUser == nil {
//                         rlAppState.logout()
//                     }
//                 }
//             }
//         }
//     }
    
//     // MARK: - View Components
    
//     private var mainContentStack: some View {
//         NavigationStack {
//             ZStack {
//                 StaticBackgroundView()
                
//                 VStack(spacing: 0) {
//                     chartView(controlViewModel: chartControlVM)
//                 }
//                 .opacity(fadeIn ? 1 : 0)
//                 .animation(.easeIn(duration: 1.5), value: fadeIn)
//                 .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
//                     if let symbol = notification.userInfo?["symbol"] as? TradingSymbolDTO {
//                         // Dismiss keyboard first
//                         dismissKeyboard()
                        
//                         // Update chart
//                         chartViewModel.setSymbol(symbol)
                        
//                         // Close drawer if open
//                         withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                             showLeftDrawer = false
//                         }
//                     }
//                 }
//             }
//             .toolbar {
//                 // Left Drawer Button
//                 ToolbarItem(placement: .topBarLeading) {
//                     ToolbarIconButton(
//                         systemName: "shield.pattern.checkered",
//                         backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
//                         fontType: .headline,
//                         symbolRenderingMode: .monochrome,
//                         foregroundStyle: AppColors.whiteText,
//                         padding: 8
//                     ) {
                        
//                         withAnimation(AnimationConstants.standard) {
//                             dismissKeyboard()
//                             selectedDetent = .fraction(0.11)
//                             showLeftDrawer.toggle()
//                             showRightDrawer = false
//                             showOverlay = showLeftDrawer
//                         }
//                     }
//                 }
                
//                 // App Title
//                 ToolbarItem(placement: .principal) {
//                     Text("TG")
//                         .font(.largeTitle)
//                         .fontWeight(.heavy)
//                         .foregroundColor(AppColors.fadedBackground)
//                 }
                
//                 // Right Drawer Button
//                 ToolbarItem(placement: .topBarTrailing) {
//                     ToolbarIconButton(
//                         systemName: "message.badge.filled.fill",
//                         backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
//                         fontType: .subheadline,
//                         symbolRenderingMode: .monochrome,
//                         foregroundStyle: AppColors.whiteText,
//                         padding: 8
//                     ) {
//                         withAnimation(AnimationConstants.standard) {
//                             dismissKeyboard()
//                             selectedDetent = .fraction(0.11)
//                             showRightDrawer.toggle()
//                             showLeftDrawer = false
//                             showOverlay = showRightDrawer
//                         }
//                     }
//                 }
//             }
//             .toolbarBackground(.hidden, for: .navigationBar)
//             .toolbarColorScheme(.dark, for: .navigationBar)
//             .tint(.white)
//             .navigationBarTitleDisplayMode(.inline)
//         }
//     }
    
//     // UPDATED: Pass total indicator panel height for proper bottom controls positioning
//     private func chartView(controlViewModel: ChartControlViewModel) -> some View {
//         TradingChartView(
//             controlViewModel: controlViewModel,
//             chartViewModel: chartViewModel,
//             gestureState: chartGestureState,
//             rsiPanelHeight: $rsiPanelHeight,
//             indicatorPanelBottomPadding: indicatorPanelsTotalHeight
//         )
//     }
    
//     private var overlayView: some View {
//         AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity)
//             .ignoresSafeArea()
//             .onTapGesture {
//                 withAnimation(AnimationConstants.standard) {
//                     dismissKeyboard()
//                     showLeftDrawer = false
//                     showRightDrawer = false
//                     leftDragTranslation = 0
//                     rightDragTranslation = 0
//                     dismissRightSheetsSignal = true
//                 }
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                     showOverlay = false
//                 }
//             }
//     }
    
//     private var sheetOverlayView: some View {
//         AppColors.systemBlack.opacity(LayoutConstants.overlayOpacity * 0.8)
//             .ignoresSafeArea()
//             .contentShape(Rectangle())
//             .onTapGesture {
//                 dismissRightSheetsSignal = true
//                 dismissLeftSheetsSignal = true
//             }
//             .simultaneousGesture(DragGesture().onChanged { _ in
//                 dismissRightSheetsSignal = true
//                 dismissLeftSheetsSignal = true
//             })
//     }
    
//     // FIXED: Using LeftDrawerMainView (correct name)
//     private var leftDrawerView: some View {
//         HStack(spacing: 0) {
//             LeftDrawerMainView(
//                 sheetOverlayVisible: $showSheetOverlay,
//                 dismissSheetsSignal: $dismissLeftSheetsSignal,
//                 onClose: {
//                     dismissKeyboard()
//                     withAnimation(AnimationConstants.standard) {
//                         showLeftDrawer = false
//                         leftDragTranslation = 0
//                     }
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                         showOverlay = false
//                     }
//                 },
//                 currentSymbolId: chartViewModel.currentSymbol?.id
//             )
// //            LeftDrawerMainView(sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal, currentSymbolId: chartViewModel.currentSymbol?.id) {
// //                dismissKeyboard()
// //                withAnimation(AnimationConstants.standard) {
// //                    showLeftDrawer = false
// //                    leftDragTranslation = 0
// //                }
// //                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
// //                    showOverlay = false
// //                }
// //            }
//             .frame(width: drawerWidth)
//             .frame(maxHeight: .infinity)
//             .offset(x: leftDragTranslation)
//             .gesture(
//                 DragGesture()
//                     .onChanged { value in
//                         if value.translation.width < 0 {
//                             leftDragTranslation = value.translation.width
//                         }
//                     }
//                     .onEnded { value in
//                         handleDrawerDragEnd(currentPosition: leftDragTranslation)
//                     }
//             )
//             Spacer(minLength: 0)
//         }
//         .frame(maxHeight: .infinity)
//         .offset(x: showLeftDrawer ? 0 : -drawerWidth)
//         .animation(AnimationConstants.standard, value: showLeftDrawer)
//     }
    
//     // FIXED: Using RightDrawerMainView (correct name)
//     private var rightDrawerView: some View {
//         HStack(spacing: 0) {
//             Spacer(minLength: 0)
//             RightDrawerMainView(
//                 onClose: {
//                     dismissKeyboard()
//                     withAnimation(AnimationConstants.standard) {
//                         showRightDrawer = false
//                         rightDragTranslation = 0
//                     }
//                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                         showOverlay = false
//                     }
//                 }
//             )
//             .frame(width: drawerWidth)
//             .frame(maxHeight: .infinity)
//             .offset(x: rightDragTranslation)
//             .gesture(
//                 DragGesture()
//                     .onChanged { value in
//                         if value.translation.width > 0 {
//                             rightDragTranslation = value.translation.width
//                         }
//                     }
//                     .onEnded { value in
//                         handleDrawerDragEnd(currentPosition: rightDragTranslation)
//                     }
//             )
//         }
//         .frame(maxHeight: .infinity)
//         .offset(x: showRightDrawer ? 0 : drawerWidth)
//         .animation(AnimationConstants.standard, value: showRightDrawer)
//     }
    
//     // MARK: - Helper Functions
    
//     private func handleDrawerDragEnd(currentPosition: CGFloat) {
//         if showLeftDrawer {
//             if currentPosition < -LayoutConstants.drawerDismissThreshold {
//                 dismissKeyboard()
//                 withAnimation(AnimationConstants.standard) {
//                     showLeftDrawer = false
//                     leftDragTranslation = 0
//                 }
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                     showOverlay = false
//                 }
//             } else {
//                 withAnimation(AnimationConstants.standard) {
//                     leftDragTranslation = 0
//                 }
//             }
//         } else if showRightDrawer {
//             if currentPosition > LayoutConstants.drawerDismissThreshold {
//                 dismissKeyboard()
//                 withAnimation(AnimationConstants.standard) {
//                     showRightDrawer = false
//                     rightDragTranslation = 0
//                 }
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                     showOverlay = false
//                 }
//             } else {
//                 withAnimation(AnimationConstants.standard) {
//                     rightDragTranslation = 0
//                 }
//             }
//         }
//     }
    
    
//     private func dismissKeyboard() {
//         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//     }
// }

// // MARK: - Drawer Side
// enum DrawerSide { case left, right }

// MARK: - Chart Bottom Sheet (IMPROVED CHAT VERSION)
// When in chat mode, the tab bar is replaced with chat input + back button
struct ChartBottomSheet: View {
    @State private var selectedView: ChartView = .symbol
    @ObservedObject var controlViewModel: ChartControlViewModel
    @ObservedObject var chartViewModel: ChartViewModel
    @ObservedObject var placementState: MarkerPlacementState
    @ObservedObject var markerOverlayState: MarkerOverlayState
    @ObservedObject var timeframePanelManager: TimeframePanelManager
    @Binding var selectedDetent: PresentationDetent
    @EnvironmentObject var rlAppState: RLAppState
    let onNavigateToMarker: ((RLTopMarkerDTO) -> Void)?
    let onPlaceMarker: (() -> Void)?
    var onViewingAuthorTap: ((ChartMarkerUI) -> Void)? = nil

    // Chat state - managed here since parent handles input
    @StateObject private var chartChatManager: ChartChatManager
    @State private var chatMessageText: String = ""
    @State private var isSendingChartMessage = false
    @State private var markerDetailTab: MarkerViewingTab = .general
    @State private var placementIndicatorSnapshot = PlacementIndicatorSnapshot()

    init(
        controlViewModel: ChartControlViewModel,
        chartViewModel: ChartViewModel,
        placementState: MarkerPlacementState,
        markerOverlayState: MarkerOverlayState,
        timeframePanelManager: TimeframePanelManager,
        selectedDetent: Binding<PresentationDetent>,
        onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil,
        onPlaceMarker: (() -> Void)? = nil,
        onViewingAuthorTap: ((ChartMarkerUI) -> Void)? = nil
    ) {
        self.controlViewModel = controlViewModel
        self.chartViewModel = chartViewModel
        self.placementState = placementState
        self.markerOverlayState = markerOverlayState
        self.timeframePanelManager = timeframePanelManager
        self._selectedDetent = selectedDetent
        self.onNavigateToMarker = onNavigateToMarker
        self.onPlaceMarker = onPlaceMarker
        self.onViewingAuthorTap = onViewingAuthorTap
        // Initialize ChartChatManager with RealAPIService
        // We'll configure it with rlAppState in onAppear
        _chartChatManager = StateObject(wrappedValue: ChartChatManager(
            appState: nil,
            api: RealAPIService()
        ))
    }
    
    enum ChartView: String, CaseIterable {
        case symbol = "Symbol"
        case chat = "Chat"
        case components = "Components"
        case markers = "Markers"
        
        var icon: String {
            switch self {
            case .symbol: return "chart.bar.fill"
            case .chat: return "message.fill"
            case .components: return "plus.viewfinder"
            case .markers: return "mappin.circle.fill"
            }
        }
    }
    
    private var isExpanded: Bool {
        selectedDetent != .fraction(0.11)
    }

    private var isMarkerDetailActive: Bool {
        chartViewModel.selectedMarkerForSheet != nil
    }

    private var shouldIgnoreKeyboardSafeArea: Bool {
        !(isMarkerDetailActive && markerDetailTab == .chat)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content Area
            if isExpanded {
                if controlViewModel.isMarkerPlacementMode {
                    // PLACEMENT MODE: show MarkerPlacementPanel instead of normal tabs
                    placementModeContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isMarkerDetailActive, let marker = chartViewModel.selectedMarkerForSheet,
                   let markerManager = chartViewModel.markerManager {
                    // Marker detail mode - replaces all tab content
                    markerDetailContent(marker: marker, markerManager: markerManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedView == .chat {
                    // Chat view - manages its own scroll and keyboard
                    chatContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedView == .components {
                    // Components has internal scroll behavior; avoid nested scroll views.
                    componentsContent
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Other views use standard scrollable layout
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedView {
                            case .symbol:
                                symbolAndSettingsContent
                            case .markers:
                                markersContent
                            case .components, .chat:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollDismissesKeyboard(.interactively)
                }
            } else {
                Spacer()
            }

            // Conditional Footer: Marker Detail Tab Bar, Chat Input, or Standard Tab Bar
            if controlViewModel.isMarkerPlacementMode {
                placementTabBar
            } else if isMarkerDetailActive {
                markerDetailTabBar
            } else if selectedView == .chat && isExpanded {
                // Chat Input Footer (replaces tab bar)
                chatInputFooter
            } else {
                // Standard Tab Bar
                standardTabBar
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedView)
        .animation(.easeInOut(duration: 0.3), value: isMarkerDetailActive)
        .ignoresSafeArea(.keyboard, edges: shouldIgnoreKeyboardSafeArea ? .bottom : [])
        .onAppear {
            chartChatManager.configure(with: rlAppState)
        }
        .onChange(of: chartViewModel.currentSymbol) { _ in
            loadChatForCurrentSymbol()
        }
        .onChange(of: rlAppState.currentGuild?.id) { _ in
            loadChatForCurrentSymbol()
        }
        .onChange(of: selectedView) { newView in
            if newView == .chat {
                loadChatForCurrentSymbol()
            }
        }
        .onChange(of: chartViewModel.selectedMarkerForSheet?.id) { _, newId in
            if newId != nil {
                markerDetailTab = .general
                // Keep sheet at closed state (0.11) — user drags up to expand
            }
        }
        .onChange(of: controlViewModel.isMarkerPlacementMode) { _, isPlacing in
            handlePlacementIndicatorLifecycle(isPlacing: isPlacing)
        }
        .onChange(of: placementIndicatorFingerprint) { _, _ in
            guard controlViewModel.isMarkerPlacementMode else { return }
            applyPlacementIndicatorsToChart()
        }
        .onChange(of: viewingIndicatorFingerprint) { _, _ in
            refreshViewingIndicatorsIfNeeded()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadChatForCurrentSymbol() {
        guard let symbol = chartViewModel.currentSymbol,
              let guildId = rlAppState.currentGuild?.id else {
            chartChatManager.closeChat()
            return
        }
        
        Task {
            await chartChatManager.updateForSymbol(
                symbol,
                guildId: guildId
            )
        }
    }
    
    // MARK: - Chat Input Footer (Replaces Tab Bar in Chat Mode)
    
    private var chatInputFooter: some View {
        ChatInputFooter(
            messageText: $chatMessageText,
            placeholder: "Message #\(chartChatManager.activeChartChat?.symbolTicker.lowercased() ?? "chat")...",
            isSending: isSendingChartMessage,
            onSend: { payload in
                Task {
                    await sendChartComposedMessage(payload)
                }
            },
            allowsMarkerLinkAttachment: true,
            selectedDetent: $selectedDetent,
            expandedDetent: .fraction(0.9),
            leadingAccessory: AnyView(
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedView = .symbol
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background(AppColors.gradientBackgroundDark)
                        .clipShape(Circle())
                        .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
                }
            )
        )
    }

    // MARK: - Chat Message Sending
    
    private func sendChartComposedMessage(_ payload: ChatComposerPayload) async {
        guard !isSendingChartMessage else { return }
        isSendingChartMessage = true
        defer { isSendingChartMessage = false }

        if !payload.attachments.isEmpty {
            await sendChartAttachments(payload: payload)
            return
        }

        guard payload.hasBodyContent else { return }

        do {
            try await chartChatManager.sendMessage(content: payload.encodedContent())
            HapticFeedback.light.trigger()
        } catch {
            rlAppState.showError(error, title: "Failed to Send Message", style: .toast)
        }
    }

    private func sendChartAttachments(payload: ChatComposerPayload) async {
        guard let guildId = rlAppState.currentGuild?.id,
              let chatId = chartChatManager.activeChartChat?.id else {
            rlAppState.showError(
                title: "Unable to Send",
                message: "No active chart chat was found.",
                style: .toast
            )
            return
        }

        do {
            var isFirstMessage = true
            for attachment in payload.attachments {
                let upload = try await rlAppState.realApi.uploadChartChatAttachment(
                    guildId: guildId,
                    chatId: chatId,
                    fileData: attachment.data,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType
                )
                let content: String
                if isFirstMessage {
                    content = payload.encodedContent(
                        fallback: payload.text.isEmpty ? attachment.filename : payload.text
                    )
                } else {
                    content = attachment.filename
                }
                try await chartChatManager.sendMessage(
                    content: content,
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName
                )
                isFirstMessage = false
            }
            HapticFeedback.light.trigger()
        } catch {
            rlAppState.showError(error, title: "Failed to Send Attachment", style: .toast)
        }
    }
    
    // MARK: - Standard Tab Bar
    
    
    // Helper to get current symbol as DTO for icon display
    private var currentSymbolDTO: RLTradingSymbolDTO? {
        return chartViewModel.currentSymbol
    }
    
    private var standardTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceGray20)
                    .frame(height: 0.5)
            }
            
            HStack(spacing: 4) {
                // Symbol button - NOW WITH PROPER ICON
                RootBottomBarSymbolButton(
                    symbol: chartViewModel.currentSymbol?.ticker ?? "EURUSD",
                    symbolDTO: currentSymbolDTO,  // <-- ADD THIS LINE
                    backgroundColor: selectedView == .symbol ?
                        AppColors.gradientBackgroundDark :
                        AppColors.gradientBackgroundMid.opacity(0.9),
                    foregroundColor: selectedView == .symbol ?
                        .white :
                        AppColors.whiteText.opacity(0.8)
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedView = .symbol
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    // Chat button
                    RootBottomBarIconButton(
                        systemName: "message.fill",
                        backgroundColor: selectedView == .chat ?
                            AppColors.gradientBackgroundDark :
                            AppColors.gradientBackgroundMid.opacity(0.9),
                        foregroundColor: selectedView == .chat ?
                            .white :
                            AppColors.whiteText.opacity(0.8)
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .chat
                        }
                    }

                    
                    // Indicator button
                    RootBottomBarIconButton(
                        systemName: "plus.viewfinder",
                        fontSize: 25,
                        backgroundColor: selectedView == .components ?
                            AppColors.gradientBackgroundDark :
                            AppColors.gradientBackgroundMid.opacity(0.9),
                        foregroundColor: selectedView == .components ?
                            .white :
                            AppColors.whiteText.opacity(0.8)
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .components
                        }
                    }
                    
                    // Markers button
                    RootBottomBarIconButton(
                        systemName: "target",
                        fontSize: 25,
                        backgroundColor: selectedView == .markers ?
                            AppColors.whiteText :
                            AppColors.whiteText.opacity(0.5),
                        foregroundColor: selectedView == .markers ?
                            AppColors.gradientBackgroundDark :
                            AppColors.gradientBackgroundDark.opacity(0.8)
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .markers
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, isExpanded ? 16 : 0)
            .padding(.bottom, 2)
        }
        .frame(height: isExpanded ? 70 : 68)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Placement Tab Bar

    private var bottomBarSelectedBackground: Color {
        AppColors.gradientBackgroundDark
    }

    private var bottomBarUnselectedBackground: Color {
        AppColors.gradientBackgroundMid.opacity(0.9)
    }

    private var bottomBarSelectedForeground: Color {
        .white
    }

    private var bottomBarUnselectedForeground: Color {
        AppColors.whiteText.opacity(0.8)
    }

    private var placementTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceGray20)
                    .frame(height: 0.5)
            }

            HStack(spacing: 4) {
                placementGeneralTabButton(
                    isSelected: placementState.selectedPlacementTab == .general
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        placementState.selectedPlacementTab = .general
                    }
                }
                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    ForEach(MarkerPlacementTab.allCases.filter { $0 != .general }, id: \.self) { tab in
                        RootBottomBarIconButton(
                            systemName: tab.icon,
                            fontSize: 21,
                            backgroundColor: placementState.selectedPlacementTab == tab ?
                                bottomBarSelectedBackground :
                                bottomBarUnselectedBackground,
                            foregroundColor: placementState.selectedPlacementTab == tab ?
                                bottomBarSelectedForeground :
                                bottomBarUnselectedForeground
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                placementState.selectedPlacementTab = tab
                            }
                        }
                    }

                    Button {
                        onPlaceMarker?()
                    } label: {
                        Image(systemName: "target")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(placementState.isValid ? .white : AppColors.whiteText.opacity(0.55))
                            .frame(width: 54, height: 54)
                            .background(
                                Circle()
                                    .fill(
                                        placementState.isValid
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [
                                                        placementState.intent.color.opacity(0.96),
                                                        placementState.intent.color.opacity(0.74),
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            : AnyShapeStyle(bottomBarUnselectedBackground)
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        placementState.isValid
                                            ? placementState.intent.color.opacity(0.72)
                                            : AppColors.whiteText.opacity(0.16),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: placementState.isValid
                                    ? placementState.intent.color.opacity(0.22)
                                    : .clear,
                                radius: 6,
                                x: 0,
                                y: 1
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!placementState.isValid)
                    .opacity(placementState.isValid ? 1.0 : 0.55)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, isExpanded ? 16 : 0)
            .padding(.bottom, 2)
        }
        .frame(height: isExpanded ? 70 : 68)
        .ignoresSafeArea(.keyboard)
    }
    
    
    // MARK: - Symbol Tab Content
    private var symbolAndSettingsContent: some View {
        ChartSheetSymbolView(
            chartViewModel: chartViewModel
        )
    }
    
    // MARK: - Components Tab Content
    private var componentsContent: some View {
        let latestCandle = chartViewModel.dataManager.candles.last
        return ChartComponentsContent(
            indicatorManager: chartViewModel.indicatorManager,
            drawingManager: chartViewModel.chartDrawingManager,
            timeframeLinkManager: chartViewModel.chartTimeframeLinkManager,
            currentChartTimeframe: chartViewModel.currentTimeframe,
            onSelectTimeframe: { timeframe in
                if chartViewModel.currentTimeframe != timeframe {
                    chartViewModel.setTimeframe(timeframe)
                }
            },
            onRecalculate: {
                chartViewModel.recalculateIndicators()
            },
            onBeginInteractiveDrawing: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDetent = .fraction(0.11)
                }
            },
            timeframePanelManager: timeframePanelManager,
            symbolId: chartViewModel.currentSymbol?.id,
            guildId: rlAppState.currentGuild?.id,
            anchorTime: latestCandle?.timestamp,
            anchorPrice: latestCandle?.close
        )
    }
    
    // MARK: - Markers Tab Content
    private var markersContent: some View {
        chartSheetMarkersView(
            chartViewModel: chartViewModel,
            controlViewModel: controlViewModel,
            onNavigateToMarker: onNavigateToMarker,
            onMarkerSelection: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDetent = .fraction(0.11)
                }
            }
        )
    }
    
    // MARK: - Placement Mode Content
    private var placementModeContent: some View {
        let liveChartIndicatorPayloads = MarkerPlacementIndicatorFactory.activePayloads(
            from: chartViewModel.indicatorManager.activeIndicators
        )
        return MarkerPlacementPanel(
            placementState: placementState,
            activeChartIndicators: placementIndicatorSnapshot.didCapture
                ? placementIndicatorSnapshot.payloads
                : liveChartIndicatorPayloads,
            currentChartTimeframe: chartViewModel.currentTimeframe,
            onSelectTimeframe: { timeframe in
                if chartViewModel.currentTimeframe != timeframe {
                    chartViewModel.setTimeframe(timeframe)
                }
            },
            onBeginInteractiveDrawing: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDetent = .fraction(0.11)
                }
            },
            timeframePanelManager: timeframePanelManager,
            symbolId: chartViewModel.currentSymbol?.id,
            guildId: rlAppState.currentGuild?.id
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Chat Tab Content
    private var chatContent: some View {
        ImprovedChartSheetChatView(
            chartViewModel: chartViewModel,
            chartChatManager: chartChatManager,
            selectedDetent: $selectedDetent,
            messageText: $chatMessageText
        )
        .environmentObject(rlAppState)
    }

    // MARK: - Marker Detail Mode

    @ViewBuilder
    private func markerDetailContent(marker: ChartMarkerUI, markerManager: MarkerManager) -> some View {
        switch markerDetailTab {
        case .general:
            MarkerViewingGeneralTab(
                marker: marker,
                markerManager: markerManager,
                onClose: clearSelectedMarker,
                symbolDTO: chartViewModel.currentSymbol,
                onAuthorTap: { onViewingAuthorTap?(marker) },
                canEditMarker: canEditSelectedMarker,
                onEditMarker: { liveMarker in
                    beginEditingSelectedMarker(liveMarker)
                }
            )
            .environmentObject(rlAppState)
        case .chat:
            EmbeddedMarkerChatTabView(
                marker: marker,
                markerManager: markerManager,
                selectedDetent: $selectedDetent
            )
            .environmentObject(rlAppState)
        case .components:
            MarkerViewingComponentsTab(marker: marker)
        }
    }

    private func clearSelectedMarker() {
        withAnimation(.easeInOut(duration: 0.25)) {
            chartViewModel.markerManager?.selectedMarker = nil
        }
    }

    private func beginEditingSelectedMarker(_ sourceMarker: ChartMarkerUI? = nil) {
        let marker = resolvedMarkerForEditing(sourceMarker)
        guard let marker,
              isMarkerEditableForCurrentUser(marker) else {
            return
        }

        placementState.beginEditingMarker(marker)

        withAnimation(.easeInOut(duration: 0.25)) {
            chartViewModel.markerManager?.selectedMarker = nil
            controlViewModel.startMarkerPlacement(intent: marker.intent)
        }
    }

    private func resolvedMarkerForEditing(_ sourceMarker: ChartMarkerUI?) -> ChartMarkerUI? {
        let candidate = sourceMarker ?? chartViewModel.selectedMarkerForSheet
        guard let candidate else { return nil }
        if let live = chartViewModel.markerManager?.markers.first(where: { $0.id == candidate.id }) {
            return live
        }
        return candidate
    }

    private func toggleSelectedMarkerLike() {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return }
        Task {
            await chartViewModel.markerManager?.toggleLike(markerId: marker.id)
        }
    }

    private var placementIndicatorFingerprint: String {
        placementState.indicatorDrafts
            .map { draft in
                switch draft.payload {
                case .indicator(let payload):
                    return indicatorPayloadFingerprint(payload)
                default:
                    return draft.id.uuidString
                }
            }
            .joined(separator: "||")
    }

    private var viewingIndicatorFingerprint: String {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return "" }
        return marker.components
            .filter { $0.componentTypeEnum == .indicator }
            .sorted { lhs, rhs in
                if lhs.ordering != rhs.ordering { return lhs.ordering < rhs.ordering }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { component in
                guard case let .indicator(payload) = component.payload else {
                    return component.id.uuidString
                }
                return "\(component.id.uuidString)|\(indicatorPayloadFingerprint(payload))"
            }
            .joined(separator: "||")
    }

    private func indicatorPayloadFingerprint(_ payload: IndicatorPayload) -> String {
        "\(payload.name)|\(indicatorSettingsFingerprint(payload.settings))"
    }

    private func indicatorSettingsFingerprint(_ settings: [String: AnyCodable]?) -> String {
        guard let settings, !settings.isEmpty else { return "no-settings" }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(settings),
              let encoded = String(data: data, encoding: .utf8) else {
            return "settings-encoding-failed"
        }
        return encoded
    }

    private var placementIndicatorComponents: [RLMarkerComponentDTO] {
        placementState.indicatorDrafts.compactMap { draft in
            guard case let .indicator(payload) = draft.payload else { return nil }
            return RLMarkerComponentDTO(
                id: draft.id,
                componentType: RLComponentType.indicator.rawValue,
                payload: .indicator(payload),
                ordering: 0
            )
        }
    }

    private func handlePlacementIndicatorLifecycle(isPlacing: Bool) {
        if isPlacing {
            if !placementIndicatorSnapshot.didCapture {
                chartViewModel.indicatorManager.saveSnapshot()
                placementIndicatorSnapshot.captureIfNeeded(
                    from: chartViewModel.indicatorManager.activeIndicators
                )
            }
            applyPlacementIndicatorsToChart()
            syncPlacementTimeframePanels()
            return
        }

        if placementIndicatorSnapshot.didCapture {
            chartViewModel.indicatorManager.restoreSnapshot()
            chartViewModel.indicatorManager.recalculateIndicators(candles: chartViewModel.dataManager.candles)
            placementIndicatorSnapshot.reset()
        }

        if let marker = chartViewModel.selectedMarkerForSheet {
            populateTimeframePanelsFromMarker(marker)
        } else {
            restoreChartLinkedTimeframePanels()
        }
    }

    private func applyPlacementIndicatorsToChart() {
        chartViewModel.indicatorManager.applyMarkerIndicators(placementIndicatorComponents)
        chartViewModel.indicatorManager.recalculateIndicators(candles: chartViewModel.dataManager.candles)
    }

    private func restoreChartLinkedTimeframePanels() {
        syncTimeframePanels(fromBackendValues: chartViewModel.chartTimeframeLinkManager.linkedTimeframes)
    }

    private func syncPlacementTimeframePanels() {
        let linkedValues = placementState.timeframeLinkDrafts.compactMap { draft -> String? in
            guard case .timeframeLink(let payload) = draft.payload else { return nil }
            return payload.timeframe
        }
        syncTimeframePanels(fromBackendValues: linkedValues)
    }

    private func populateTimeframePanelsFromMarker(_ marker: ChartMarkerUI) {
        let linkedValues = marker.components.compactMap { component -> String? in
            guard component.componentTypeEnum == .timeframeLink,
                  case .timeframeLink(let payload) = component.payload else {
                return nil
            }
            return payload.timeframe
        }
        syncTimeframePanels(fromBackendValues: linkedValues)
    }

    private func syncTimeframePanels(fromBackendValues values: [String]) {
        timeframePanelManager.clearAll()

        guard let symbolId = chartViewModel.currentSymbol?.id,
              let guildId = rlAppState.currentGuild?.id else { return }

        var inserted = Set<RLChartTimeframe>()
        for value in values {
            guard let timeframe = RLChartTimeframe.fromBackendString(value),
                  inserted.insert(timeframe).inserted else {
                continue
            }
            timeframePanelManager.addPanel(timeframe: timeframe, symbolId: symbolId, guildId: guildId)
        }

        if !timeframePanelManager.panels.isEmpty {
            timeframePanelManager.reloadAll(symbolId: symbolId, guildId: guildId)
        }
    }

    private func refreshViewingIndicatorsIfNeeded() {
        guard controlViewModel.isMarkerViewingMode,
              let marker = chartViewModel.selectedMarkerForSheet else {
            return
        }

        markerOverlayState.activateViewing(
            marker: marker,
            indicatorManager: chartViewModel.indicatorManager,
            candles: chartViewModel.dataManager.candles
        )
    }

    // MARK: - Marker Detail Tab Bar

    private var markerDetailTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceGray20)
                    .frame(height: 0.5)
            }

            HStack(spacing: 4) {
                // General tab (left, gets more space via Spacer)
                if let marker = chartViewModel.selectedMarkerForSheet {
                    markerDetailGeneralTabButton(
                        marker: marker,
                        isSelected: markerDetailTab == .general
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            markerDetailTab = .general
                        }
                    }
                }

                Spacer()

                // Action buttons (right) — mirrors standardTabBar layout
                HStack(spacing: 6) {
                    ForEach(MarkerViewingTab.allCases, id: \.self) { tab in
                        if tab != .general {
                            RootBottomBarIconButton(
                                systemName: tab == .chat ? "message.fill" : tab.icon,
                                fontSize: 20,
                                backgroundColor: markerDetailTab == tab ?
                                    bottomBarSelectedBackground :
                                    bottomBarUnselectedBackground,
                                foregroundColor: markerDetailTab == tab ?
                                    bottomBarSelectedForeground :
                                    bottomBarUnselectedForeground
                            ) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    markerDetailTab = tab
                                }
                            }
                        }
                    }
                    markerLikeCapsuleButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, isExpanded ? 16 : 0)
            .padding(.bottom, 2)
        }
        .frame(height: isExpanded ? 70 : 68)
        .ignoresSafeArea(.keyboard, edges: markerDetailTab == .chat ? [] : .bottom)
    }

    private var canEditSelectedMarker: Bool {
        guard let marker = chartViewModel.selectedMarkerForSheet else { return false }
        return isMarkerEditableForCurrentUser(marker)
    }

    private func isMarkerEditableForCurrentUser(_ marker: ChartMarkerUI) -> Bool {
        if marker.canOpenEditFlow {
            return true
        }

        guard let currentUserId = rlAppState.currentUser?.id else {
            return false
        }
        return marker.author.userId == currentUserId
    }

    private var markerLikeCapsuleButton: some View {
        let isLiked = chartViewModel.selectedMarkerForSheet?.isLikedByCurrentUser ?? false
        let likeCount = chartViewModel.selectedMarkerForSheet?.likeCount ?? 0

        return Button(action: toggleSelectedMarkerLike) {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.headline)
                Text("\(likeCount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(isLiked ? AppColors.markerHeartBadge : AppColors.bearCandleRed.opacity(0.12))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isLiked ? AppColors.markerHeartTint : AppColors.bearCandleRed.opacity(0.6), lineWidth: isLiked ? 0.9 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func placementGeneralTabButton(
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                UnifiedMarkerBadge(
                    intent: placementState.intent,
                    alertSeverity: placementState.intent == .alert ? placementState.alertSeverity : nil,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(placementState.intent.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Marker")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .frame(height: 50)
            .background(
                isSelected
                    ? bottomBarSelectedBackground
                    : bottomBarUnselectedBackground
            )
            .clipShape(Capsule())
            .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    private func markerDetailGeneralTabButton(
        marker: ChartMarkerUI,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                UnifiedMarkerBadge(
                    intent: marker.intent,
                    alertSeverity: marker.alertSeverity,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(marker.intent.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(markerAuthorHandle(marker))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .frame(height: 50)
            .background(
                isSelected
                    ? bottomBarSelectedBackground
                    : bottomBarUnselectedBackground
            )
            .clipShape(Capsule())
            .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    private func markerAuthorHandle(_ marker: ChartMarkerUI) -> String {
        let username = marker.author.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return "@unknown" }
        return username.hasPrefix("@") ? username : "@\(username)"
    }

    private var placementAuthorHandle: String {
        let username = rlAppState.currentUser?.username
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !username.isEmpty else { return "@you" }
        return username.hasPrefix("@") ? username : "@\(username)"
    }
}



struct IndicatorItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        Button { } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 32)
                Text(title)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(AppColors.surfaceWhite05)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MarkerTypeItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 32)
            Text(title)
                .foregroundColor(.white)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(AppColors.surfaceWhite05)
        .cornerRadius(8)
    }
}

struct ChartControlButton: View {
    let title: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isActive ? .white : color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.surfaceWhite90)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                isActive ?
                color :
                AppColors.surfaceWhite10
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
