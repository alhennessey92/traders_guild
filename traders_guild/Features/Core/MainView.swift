


//
//  MainView.swift
//  traders_guild
//
//  UPDATED VERSION - Fixes bottom controls overlap with multiple indicator panels
//

import SwiftUI
//import SwiftTradingView

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
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var messagingManager: MessagingManager
    @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
    @StateObject private var rightDrawerViewModel = RightDrawerViewModel()
    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
    
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
        
        // Add X-axis labels height
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
        _chartViewModel = StateObject(wrappedValue: ChartViewModel(
            appState: AppState(),
            dataManager: dataManager,
            api: MockAPIService()
        ))
    }
    
    // MARK: - Body
    var body: some View {
        if let user = appState.currentUser,
           let guild = appState.currentGuild {
            ZStack {
                // MARK: - Main Content Layer
                mainContentStack
                    .disabled(showLeftDrawer || showRightDrawer)
                
                // MARK: - Indicator Panels Overlay
                // Positioned ABOVE main content, BELOW bottom sheet
                if chartViewModel.indicatorManager.shouldShowAnyPanel {
                    VStack {
                        Spacer()
                        
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
                        
                        // DYNAMIC bottom padding - accounts for minimized bottom sheet
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
            .globalMessaging()
            
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
            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer && !appState.showingTransition)) {
                ChartBottomSheet(
                    controlViewModel: chartControlVM,
                    chartViewModel: chartViewModel,
                    selectedDetent: $selectedDetent
                )
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
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
            .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
            
            .environmentObject(leftDrawerViewModel)
            .environmentObject(rightDrawerViewModel)
            .environmentObject(notificationNavigationManager)
            .task {
                await leftDrawerViewModel.preloadData(for: guild.id, appState: appState)
                await rightDrawerViewModel.preloadData(for: guild.id, appState: appState)
                
                notificationNavigationManager.configure(
                    appState: appState,
                    messagingManager: messagingManager,
                    rightDrawerViewModel: rightDrawerViewModel
                )
                
                // Initialize chart with data
                await chartViewModel.initialize()
                
                appState.chartDidBecomeReady()
            }
            .onChange(of: appState.currentGuild?.id) { oldValue, newValue in
                if let guildId = newValue, oldValue != newValue {
                    Task {
                        leftDrawerViewModel.clearCache()
                        rightDrawerViewModel.clearCache()
                        await leftDrawerViewModel.preloadData(for: guildId, appState: appState)
                        await rightDrawerViewModel.preloadData(for: guildId, appState: appState)
                        await chartViewModel.initialize()
                        appState.chartDidBecomeReady()
                    }
                }
            }
            
//            .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
//                if let symbol = notification.userInfo?["symbol"] as? TradingSymbolDTO {
//                    // Dismiss keyboard first
//                    dismissKeyboard()
//                    
//                    // Update chart
//                    chartViewModel.setSymbol(symbol)
//                    
//                    // Close drawer if open
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                        showLeftDrawer = false
//                    }
//                }
//            }
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
                    if appState.currentUser != nil && appState.currentGuild == nil {
                        await appState.openGuildSelector()
                    } else if appState.currentUser == nil {
                        appState.logout()
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
                    chartView(controlViewModel: chartControlVM)
                }
                .opacity(fadeIn ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: fadeIn)
                .onReceive(NotificationCenter.default.publisher(for: .selectChartSymbol)) { notification in
                    if let symbol = notification.userInfo?["symbol"] as? TradingSymbolDTO {
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
                
                // Right Drawer Button
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarIconButton(
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
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // UPDATED: Pass total indicator panel height for proper bottom controls positioning
    private func chartView(controlViewModel: ChartControlViewModel) -> some View {
        TradingChartView(
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
//            LeftDrawerMainView(sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal, currentSymbolId: chartViewModel.currentSymbol?.id) {
//                dismissKeyboard()
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    leftDragTranslation = 0
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
            .frame(width: drawerWidth)
            .frame(maxHeight: .infinity)
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
    
    // FIXED: Using RightDrawerMainView (correct name)
    private var rightDrawerView: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            RightDrawerMainView(
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
}

// MARK: - Drawer Side
enum DrawerSide { case left, right }

// MARK: - Chart Bottom Sheet (IMPROVED CHAT VERSION)
// When in chat mode, the tab bar is replaced with chat input + back button
struct ChartBottomSheet: View {
    @State private var selectedView: ChartView = .symbol
    @ObservedObject var controlViewModel: ChartControlViewModel
    @ObservedObject var chartViewModel: ChartViewModel
    @Binding var selectedDetent: PresentationDetent
    @EnvironmentObject var appState: AppState
    
    // Chat state - managed here since parent handles input
    @StateObject private var chartChatManager = ChartChatManager()
    @State private var chatMessageText: String = ""
    @FocusState private var isChatInputFocused: Bool
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Content Area
            if isExpanded {
                if selectedView == .chat {
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
            
            // Conditional Footer: Tab Bar OR Chat Input
            if selectedView == .chat && isExpanded {
                // Chat Input Footer (replaces tab bar)
                chatInputFooter
            } else {
                // Standard Tab Bar
                standardTabBar
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedView)
        .onAppear {
            chartChatManager.configure(with: appState)
        }
        .onChange(of: chartViewModel.currentSymbol) { _ in
            loadChatForCurrentSymbol()
        }
        .onChange(of: appState.currentGuild) { _ in
            loadChatForCurrentSymbol()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadChatForCurrentSymbol() {
        guard let symbol = chartViewModel.currentSymbol,
              let guildId = appState.currentGuild?.id else {
            chartChatManager.closeChat()
            return
        }
        
        Task {
            await chartChatManager.updateForSymbol(
                symbol,
                guildId: guildId,
                api: MockAPIService()
            )
        }
    }
    
    // MARK: - Chat Input Footer (Replaces Tab Bar in Chat Mode)
    
    private var chatInputFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                // Back button - circular like tab buttons
                Button(action: {
                    isChatInputFocused = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedView = .symbol
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                        .frame(width: 50, height: 50)
                        .background(AppColors.gradientBackgroundDark)
                        .clipShape(Circle())
                        .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: 0)
                }
                .padding(.horizontal, 4)
                
                // Chat input (matching MarkerDetailView/MessagingState style)
                HStack(spacing: 12) {
                    // Plus button
                    Button(action: {
                        isChatInputFocused = false
                        // Handle attachments
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .compositingGroup()
                    
                    // Text field
                    TextField("Message #\(chartChatManager.activeChartChat?.symbolTicker.lowercased() ?? "chat")...", text: $chatMessageText)
                        .font(.subheadline)
                        .submitLabel(.send)
                        .focused($isChatInputFocused)
                        .onSubmit {
                            sendChatMessage()
                        }
                    
                    HStack(spacing: 8) {
                        // Mic button
                        Button(action: {
                            isChatInputFocused = false
                            // Handle voice
                        }) {
                            Image(systemName: "mic.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        .compositingGroup()
                        
                        // Send button
                        Button(action: {
                            sendChatMessage()
                        }) {
                            Image(systemName: "chevron.forward.2")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .padding(.leading, 2)
                                .background(chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                                .clipShape(Capsule())
                        }
                        .disabled(chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .compositingGroup()
                    }
                }
                .padding(.leading, 10)
                .frame(height: 44)
                .background(AppColors.whiteText.opacity(0.08))
                .cornerRadius(25)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.sheetBackground)
        }
        .frame(height: 70)
    }
    
    // MARK: - Chat Message Sending
    
    private func sendChatMessage() {
        let trimmed = chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Clear input immediately for responsive feel
        let messageToSend = trimmed
        chatMessageText = ""
        isChatInputFocused = false
        
        Task {
            do {
                try await chartChatManager.sendMessage(
                    content: messageToSend,
                    api: MockAPIService()
                )
                HapticFeedback.light.trigger()
            } catch {
                // Restore message on error
                chatMessageText = messageToSend
                appState.showError(error, title: "Failed to Send Message")
            }
        }
    }
    
    // MARK: - Standard Tab Bar
    
    
    // Helper to get current symbol as DTO for icon display
    private var currentSymbolDTO: TradingSymbolDTO? {
        guard let currentSymbol = chartViewModel.currentSymbol else { return nil }
        // TradingSymbol uses .symbol, TradingSymbolDTO uses .ticker
        return SampleData.allTradingSymbolDTOs.first { $0.ticker == currentSymbol.ticker }
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
            controlViewModel: controlViewModel
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
        .environmentObject(appState)
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


