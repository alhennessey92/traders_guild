//
//  MainView.swift
//  traders_guild
//
//  UPDATED VERSION - Integrated RLMessagingManager and RLRightDrawerViewModel
//  for live backend messaging (chatrooms and DMs).
//

import SwiftUI

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
    
    // MARK: - Computed Properties
    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    private var drawerWidth: CGFloat {
        screenSize.width * LayoutConstants.drawerWidthRatio
    }
    
    /// Calculate total height of active indicator panels for bottom padding
    private var indicatorPanelsTotalHeight: CGFloat {
        let activePanels = chartViewModel.indicatorManager.activeIndicators.activePanelTypes
        guard !activePanels.isEmpty else { return 0 }
        
        var totalHeight: CGFloat = 0
        
        for panelType in activePanels {
            switch panelType {
            case .rsi:
                totalHeight += rsiPanelHeight + 22  // +22 for resize handle
            case .macd:
                totalHeight += macdPanelHeight + 22
            case .stochastic:
                totalHeight += stochasticPanelHeight + 22
            case .cci:
                totalHeight += cciPanelHeight + 22
            case .williamsR:
                totalHeight += williamsRPanelHeight + 22
            case .atr:
                totalHeight += atrPanelHeight + 22
            case .volume:
                totalHeight += volumePanelHeight + 22
            }
        }

        // Add X-axis labels height from bottom indicator panel
        totalHeight += 22
        
        return totalHeight
    }
    
    /// Bottom padding for controls that need to float above indicator panels
    private var bottomControlsPadding: CGFloat {
        // Base padding for minimized bottom sheet + indicator panels
        return indicatorPanelsTotalHeight + 100
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
                
                // MARK: - Indicator Panels Overlay
                // Positioned ABOVE main content, BELOW bottom sheet
                // allowsHitTesting only on panels themselves (not the spacer above)
                // so chart controls beneath remain tappable
                if chartViewModel.indicatorManager.shouldShowAnyPanel {
                    VStack {
                        Spacer()
                            .allowsHitTesting(false)

                        IndicatorPanelContainer(
                            indicatorManager: chartViewModel.indicatorManager,
                            chartData: chartViewModel.dataManager,
                            gestureState: chartGestureState,
                            baseCandleWidth: 12,
                            candleSpacing: 4,
                            timeframe: chartViewModel.currentTimeframe,
                            rsiPanelHeight: $rsiPanelHeight,
                            macdPanelHeight: $macdPanelHeight,
                            stochasticPanelHeight: $stochasticPanelHeight,
                            cciPanelHeight: $cciPanelHeight,
                            williamsRPanelHeight: $williamsRPanelHeight,
                            atrPanelHeight: $atrPanelHeight,
                            volumePanelHeight: $volumePanelHeight
                        )
                        // Keep bottom sheet clearance while allowing panels to run down to x-axis area.
                        Color.clear
                            .frame(height: 100)
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
            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer && !rlAppState.showingTransition)) {
                ChartBottomSheet(
                    controlViewModel: chartControlVM,
                    chartViewModel: chartViewModel,
                    selectedDetent: $selectedDetent,
                    onNavigateToMarker: { marker in
                        leftDrawerViewModel.requestNavigationToMarker(marker)
                    }
                )
                .environmentObject(rlAppState)
                .presentationDetents([.fraction(0.11), .fraction(0.5), .fraction(0.9)],
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
                if isPlacing {
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
                        // Dismiss keyboard first
                        dismissKeyboard()
                        
                        // Update chart
                        chartViewModel.setSymbol(symbol)
                        
                        // Close drawer if open
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
            .toolbar {
                // Left Drawer Button
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarIconButton(
                        systemName: "shield.pattern.checkered",
                        backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                        fontType: .headline,
                        symbolRenderingMode: .monochrome,
                        foregroundStyle: AppColors.whiteText,
                        padding: 8
                    ) {
                        
                        withAnimation(AnimationConstants.standard) {
                            dismissKeyboard()
                            selectedDetent = .fraction(0.11)
                            showLeftDrawer.toggle()
                            showRightDrawer = false
                            showOverlay = showLeftDrawer
                        }
                    }
                }
                
                // App Title
                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                }
                
                // Right Drawer Button - with unread badge
                ToolbarItem(placement: .topBarTrailing) {
                    ZStack(alignment: .topTrailing) {
                        if rightDrawerViewModel.totalUnreadCount > 0 {

                            ToolbarIconButton(
                                // Unread badge
                                systemName: "message.badge.filled.fill",
                                backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                                fontType: .subheadline,
                                symbolRenderingMode: .palette,
                                foregroundStyles: [AppColors.accentColor, AppColors.whiteText],
                                padding: 8
                            ) {
                                withAnimation(AnimationConstants.standard) {
                                    dismissKeyboard()
                                    selectedDetent = .fraction(0.11)
                                    showRightDrawer.toggle()
                                    showLeftDrawer = false
                                    showOverlay = showRightDrawer
                                }
                            }

                        }else{
                            ToolbarIconButton(
                                // Unread badge
                                systemName: "message.badge.filled.fill",
                                backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                                fontType: .subheadline,
                                symbolRenderingMode: .monochrome,
                                foregroundStyle: AppColors.whiteText,
                                padding: 8
                            ) {
                                withAnimation(AnimationConstants.standard) {
                                    dismissKeyboard()
                                    selectedDetent = .fraction(0.11)
                                    showRightDrawer.toggle()
                                    showLeftDrawer = false
                                    showOverlay = showRightDrawer
                                }
                            }
                            
                        }
                        // ToolbarIconButton(
                        //     // Unread badge
                        //     systemName: "message.badge.filled.fill",
                        //     backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                        //     fontType: .subheadline,
                        //     symbolRenderingMode: .monochrome,
                        //     foregroundStyle: AppColors.whiteText,
                        //     padding: 8
                        // ) {
                        //     withAnimation(AnimationConstants.standard) {
                        //         dismissKeyboard()
                        //         selectedDetent = .fraction(0.11)
                        //         showRightDrawer.toggle()
                        //         showLeftDrawer = false
                        //         showOverlay = showRightDrawer
                        //     }
                        // }
                        
                        // // Unread badge
                        // if rightDrawerViewModel.totalUnreadCount > 0 {
                        //     Text("\(min(rightDrawerViewModel.totalUnreadCount, 99))")
                        //         .font(.caption2)
                        //         .fontWeight(.bold)
                        //         .foregroundColor(.white)
                        //         .padding(.horizontal, 5)
                        //         .padding(.vertical, 2)
                        //         .background(AppColors.bearCandleRed)
                        //         .clipShape(Capsule())
                        //         .offset(x: 8, y: -4)
                        // }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
            .navigationBarTitleDisplayMode(.inline)
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
            rsiPanelHeight: $rsiPanelHeight,
            indicatorPanelBottomPadding: indicatorPanelsTotalHeight
        )
    }
    
    private var overlayView: some View {
        Color.black.opacity(LayoutConstants.overlayOpacity)
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
        Color.black.opacity(LayoutConstants.overlayOpacity * 0.8)
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
//         Color.black.opacity(LayoutConstants.overlayOpacity)
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
//         Color.black.opacity(LayoutConstants.overlayOpacity * 0.8)
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
    @Binding var selectedDetent: PresentationDetent
    @EnvironmentObject var rlAppState: RLAppState
    let onNavigateToMarker: ((RLTopMarkerDTO) -> Void)?
    
    // Chat state - managed here since parent handles input
    @StateObject private var chartChatManager: ChartChatManager
    @State private var chatMessageText: String = ""
    @State private var isSendingChartMessage = false
    @State private var showMarkerActivitySheet = false
    @State private var markerDetailTab: MarkerDetailTab = .details

    init(
        controlViewModel: ChartControlViewModel,
        chartViewModel: ChartViewModel,
        selectedDetent: Binding<PresentationDetent>,
        onNavigateToMarker: ((RLTopMarkerDTO) -> Void)? = nil
    ) {
        self.controlViewModel = controlViewModel
        self.chartViewModel = chartViewModel
        self._selectedDetent = selectedDetent
        self.onNavigateToMarker = onNavigateToMarker
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
        case indicator = "Indicator"
        case markers = "Markers"
        
        var icon: String {
            switch self {
            case .symbol: return "chart.bar.fill"
            case .chat: return "message.fill"
            case .indicator: return "chart.line.uptrend.xyaxis.circle"
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

    var body: some View {
        VStack(spacing: 0) {
            // Content Area
            if isExpanded {
                if isMarkerDetailActive, let marker = chartViewModel.selectedMarkerForSheet,
                   let markerManager = chartViewModel.markerManager {
                    // Marker detail mode - replaces all tab content
                    markerDetailContent(marker: marker, markerManager: markerManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedView == .chat {
                    // Chat view - manages its own scroll and keyboard
                    chatContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Other views use standard scrollable layout
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedView {
                            case .symbol:
                                symbolAndSettingsContent
                            case .indicator:
                                indicatorContent
                            case .markers:
                                markersContent
                            case .chat:
                                EmptyView() // Handled above
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
            if isMarkerDetailActive {
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
                markerDetailTab = .details
                // Keep sheet at closed state (0.11) — user drags up to expand
            }
        }
        .sheet(isPresented: $showMarkerActivitySheet) {
            MarkerActivitySheet { marker in
                if let onNavigateToMarker {
                    onNavigateToMarker(marker)
                }
            }
            .environmentObject(rlAppState)
            .presentationDetents([.fraction(0.6), .large])
            .presentationDragIndicator(.visible)
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
                        .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
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
                    .fill(Color.gray.opacity(0.2))
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
                        systemName: "chart.line.uptrend.xyaxis.circle",
                        fontSize: 25,
                        backgroundColor: selectedView == .indicator ?
                            AppColors.gradientBackgroundDark :
                            AppColors.gradientBackgroundMid.opacity(0.9),
                        foregroundColor: selectedView == .indicator ?
                            .white :
                            AppColors.whiteText.opacity(0.8)
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedView = .indicator
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
    
    
    // MARK: - Symbol Tab Content
    private var symbolAndSettingsContent: some View {
        ChartSheetSymbolView(
            chartViewModel: chartViewModel
        )
    }
    
    // MARK: - Indicator Tab Content
    private var indicatorContent: some View {
        IndicatorSettingsContent(
            indicatorManager: chartViewModel.indicatorManager,
            onRecalculate: {
                chartViewModel.recalculateIndicators()
            }
        )
    }
    
    // MARK: - Markers Tab Content
    private var markersContent: some View {
        chartSheetMarkersView(
            chartViewModel: chartViewModel,
            controlViewModel: controlViewModel,
            onShowMarkerActivity: {
                showMarkerActivitySheet = true
            }
        )
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
        case .details:
            EmbeddedMarkerDetailView(
                marker: marker,
                markerManager: markerManager,
                onClose: clearSelectedMarker
            )
            .environmentObject(rlAppState)
        case .chat:
            EmbeddedMarkerChatTabView(
                marker: marker,
                markerManager: markerManager,
                selectedDetent: $selectedDetent
            )
            .environmentObject(rlAppState)
        case .analysis:
            markerDetailPlaceholder(
                icon: "chart.bar.xaxis",
                title: "Marker Analysis",
                subtitle: "Marker analysis and linked indicators"
            )
        }
    }

    private func markerDetailPlaceholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(AppColors.greyText.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.whiteText)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private func clearSelectedMarker() {
        withAnimation(.easeInOut(duration: 0.25)) {
            chartViewModel.markerManager?.selectedMarker = nil
        }
    }

    // MARK: - Marker Detail Tab Bar

    private var markerDetailTabBar: some View {
        VStack(spacing: 0) {
            if isExpanded {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)
            }

            HStack(spacing: 8) {
                // Close button - returns to normal bottom sheet tabs
                Button(action: clearSelectedMarker) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                        .frame(width: 50, height: 50)
                        .background(AppColors.gradientBackgroundDark)
                        .clipShape(Circle())
                        .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    // Details capsule - marker type + author name
                    if let marker = chartViewModel.selectedMarkerForSheet {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                markerDetailTab = .details
                            }
                        } label: {
                            HStack(spacing: 10) {
                                UnifiedMarkerBadge(
                                    type: marker.type,
                                    displayColor: marker.displayColor,
                                    size: 40,
                                    emoji: marker.type == .emoji ? marker.selectedEmoji : nil
                                )

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(marker.type.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(markerDetailTab == .details ? .white : AppColors.whiteText.opacity(0.8))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text(marker.author.username)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(markerDetailTab == .details ? .white.opacity(0.75) : AppColors.whiteText.opacity(0.5))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.trailing, 4)
                            }
                            .padding(.vertical, 5)
                            .padding(.leading, 5)
                            .padding(.trailing, 12)
                            .frame(height: 50)
                            .background(markerDetailTab == .details ?
                                AppColors.gradientBackgroundDark :
                                AppColors.gradientBackgroundMid.opacity(0.9))
                            .clipShape(Capsule())
                            .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
                        }
                    }

                    // Chat & Analysis icon buttons
                    ForEach([MarkerDetailTab.chat, MarkerDetailTab.analysis], id: \.self) { tab in
                        RootBottomBarIconButton(
                            systemName: tab.icon,
                            fontSize: 20,
                            backgroundColor: markerDetailTab == tab ?
                                AppColors.gradientBackgroundDark :
                                AppColors.gradientBackgroundMid.opacity(0.9),
                            foregroundColor: markerDetailTab == tab ?
                                .white :
                                AppColors.whiteText.opacity(0.8)
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                markerDetailTab = tab
                            }
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
            .background(Color.white.opacity(0.05))
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
        .background(Color.white.opacity(0.05))
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
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                isActive ?
                color :
                Color.white.opacity(0.1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
