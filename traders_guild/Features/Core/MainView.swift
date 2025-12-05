//
//  MainView.swift
//  traders_guild
//
//  COMPLETE CORRECTED VERSION
//  Based on your working commented version with ChartViewModel added
//

import SwiftUI
import SwiftTradingView

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
    
    // MARK: - Indicators
    // RSI Panel state
    @State private var rsiPanelHeight: CGFloat = 120
    
    // MARK: - Computed Properties
    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    private var drawerWidth: CGFloat {
        screenSize.width * LayoutConstants.drawerWidthRatio
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
                
                // MARK: - RSI Panel Overlay
                // Positioned ABOVE main content, BELOW bottom sheet
                if chartViewModel.indicatorManager.shouldShowRSIPanel {
                    VStack {
                        Spacer()
                        
                        RSIPanelView(
                            indicatorManager: chartViewModel.indicatorManager,
                            chartData: chartViewModel.dataManager,
                            gestureState: chartGestureState,  // Same instance!
                            baseCandleWidth: 12,
                            candleSpacing: 4,
                            panelHeight: $rsiPanelHeight
                        )
                        
                        // Bottom padding to clear the minimized bottom sheet
                        // (.fraction(0.11) ≈ 100pt on most devices)
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
            
            // MARK: - Bottom Sheet
            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
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
                
                // FIXED: Correct method signature
                notificationNavigationManager.configure(
                    appState: appState,
                    messagingManager: messagingManager,
                    rightDrawerViewModel: rightDrawerViewModel
                )
                
                // Initialize chart with data
                await chartViewModel.initialize()
            }
            .onChange(of: appState.currentGuild?.id) { oldValue, newValue in
                if let guildId = newValue, oldValue != newValue {
                    Task {
                        leftDrawerViewModel.clearCache()
                        rightDrawerViewModel.clearCache()
                        await leftDrawerViewModel.preloadData(for: guildId, appState: appState)
                        await rightDrawerViewModel.preloadData(for: guildId, appState: appState)
                        await chartViewModel.initialize()
                    }
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
    
    // FIXED: chartView function that uses TradingChartView with ChartViewModel
    private func chartView(controlViewModel: ChartControlViewModel) -> some View {
        TradingChartView(
            controlViewModel: controlViewModel,
            chartViewModel: chartViewModel,
            gestureState: chartGestureState 
        )
    }
    
    private var overlayView: some View {
        Color.black.opacity(LayoutConstants.overlayOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(AnimationConstants.standard) {
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
            LeftDrawerMainView(sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal) {
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    leftDragTranslation = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
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
}

// MARK: - Drawer Side
enum DrawerSide { case left, right }

// MARK: - Chart Bottom Sheet
struct ChartBottomSheet: View {
    @State private var selectedView: ChartView = .symbol
    @ObservedObject var controlViewModel: ChartControlViewModel
    @ObservedObject var chartViewModel: ChartViewModel
    @Binding var selectedDetent: PresentationDetent
    
    enum ChartView: String, CaseIterable {
        case symbol = "Symbol"
        case chat = "Chat"
        case indicator = "Indicator"
        case markers = "Markers"
//        case controls = "Controls"
        
        var icon: String {
            switch self {
            case .symbol: return "chart.bar.fill"
            case .chat: return "message.fill"
            case .indicator: return "chart.line.uptrend.xyaxis.circle"
            case .markers: return "mappin.circle.fill"
//            case .controls: return "slider.horizontal.3"
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
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedView {
                        case .symbol:
                            symbolAndSettingsContent
                        case .chat:
                            chatContent
                        case .indicator:
                            indicatorContent
                        case .markers:
                            markersContent
//                        case .controls:
//                            chartControlsContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    .animation(.easeInOut(duration: 0.3), value: selectedView)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
            
            // Fixed Button Bar
            VStack(spacing: 0) {
                if isExpanded {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 0.5)
                }
                
                HStack(spacing: 4) {
                    // Symbol button
                    RootBottomBarSymbolButton(
                        symbol: chartViewModel.currentSymbol?.symbol ?? "EUR/USD",
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
                    
                    HStack(spacing: 4) {
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
                        
//                        // Controls button
//                        RootBottomBarIconButton(
//                            systemName: "slider.horizontal.3",
//                            fontSize: 25,
//                            backgroundColor: selectedView == .controls ?
//                                AppColors.whiteText :
//                                AppColors.whiteText.opacity(0.5),
//                            foregroundColor: selectedView == .controls ?
//                                AppColors.gradientBackgroundDark :
//                                AppColors.gradientBackgroundDark.opacity(0.8)
//                        ) {
//                            withAnimation(.easeInOut(duration: 0.25)) {
//                                selectedView = .controls
//                            }
//                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, isExpanded ? 16 : 0)
                .padding(.bottom, 2)
            }
            .frame(height: isExpanded ? 70 : 68)
        }
    }
    
    // MARK: - Symbol Tab Content (NEW - Enhanced with timeframe and watchlist)
    private var symbolAndSettingsContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10){
                ChartControlButton(
                    title: "Latest",
                    icon: "arrow.right.to.line",
                    color: .blue
                ) {
                    controlViewModel.jumpToLatest()
                }
                
                ChartControlButton(
                    title: "Reset View",
                    icon: "arrow.counterclockwise",
                    color: .purple
                ) {
                    controlViewModel.resetChart()
                }
            }
            // SECTION: Current Symbol Info
            if let symbol = chartViewModel.currentSymbol {
                VStack(spacing: 12) {
                    HStack(alignment: .top) {
                        // Symbol details
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: symbol.assetClass.icon)
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(symbol.displayName)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    Text(symbol.symbol)
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.caption)
                                }
                            }
                            
                            Text(symbol.assetClass.rawValue)
                                .foregroundColor(.white.opacity(0.5))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Current price
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(symbol.formatPrice(chartViewModel.dataManager.currentPrice))
                                .foregroundColor(.white)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(chartViewModel.currentTimeframe.displayName)
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            
            // Loading indicator
            if chartViewModel.isLoadingData {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Loading data...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
            }
            
            // SECTION: Timeframe Selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeframe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Grouped by category
                VStack(spacing: 12) {
                    // Minutes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Minutes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([ChartTimeframe.m1, .m5, .m15, .m30], id: \.self) { timeframe in
                                TimeframeButton(
                                    timeframe: timeframe,
                                    isSelected: chartViewModel.currentTimeframe == timeframe
                                ) {
                                    chartViewModel.setTimeframe(timeframe)
                                }
                            }
                        }
                    }
                    
                    // Hours
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hours")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([ChartTimeframe.h1, .h4], id: \.self) { timeframe in
                                TimeframeButton(
                                    timeframe: timeframe,
                                    isSelected: chartViewModel.currentTimeframe == timeframe
                                ) {
                                    chartViewModel.setTimeframe(timeframe)
                                }
                            }
                        }
                    }
                    
                    // Daily+
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Daily & Weekly")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([ChartTimeframe.d1, .w1, .mn], id: \.self) { timeframe in
                                TimeframeButton(
                                    timeframe: timeframe,
                                    isSelected: chartViewModel.currentTimeframe == timeframe
                                ) {
                                    chartViewModel.setTimeframe(timeframe)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            
            // SECTION: Watchlist
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Watchlist")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(chartViewModel.combinedWatchlist.count) symbols")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if chartViewModel.combinedWatchlist.isEmpty {
                    Text("No symbols in watchlist")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(chartViewModel.combinedWatchlist) { symbol in
                            SymbolRow(
                                symbol: symbol,
                                isSelected: chartViewModel.currentSymbol?.id == symbol.id
                            ) {
                                chartViewModel.setSymbol(symbol)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Other Tab Contents
    
    private var chatContent: some View {
        VStack(spacing: 16) {
            Text("Chart Chat")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Real-time chat with guild members while analyzing the chart")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    private var indicatorContent: some View {
        IndicatorSettingsContent(
            indicatorManager: chartViewModel.indicatorManager,
            onRecalculate: {
                chartViewModel.recalculateIndicators()
            }
        )
    }
    

    /// Updated markersContent with specific marker type buttons
    /// Each button triggers placement mode for its specific marker type
    var markersContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add a Marker")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 15)
                
                Text("Place markers on the chart to share insights with your guild. Each candle can have one of each marker type.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                
                VStack(spacing: 8) {
                    
                    // MARK: - Core Markers Section
                    Text("Core Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .note,
                            isActive: isMarkerPlacementActive(for: .note),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .question,
                            isActive: isMarkerPlacementActive(for: .question),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .alert,
                            isActive: isMarkerPlacementActive(for: .alert),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .entry,
                            isActive: isMarkerPlacementActive(for: .entry),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .exit,
                            isActive: isMarkerPlacementActive(for: .exit),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    // MARK: - Analysis Markers Section
                    Text("Analysis Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .support,
                            isActive: isMarkerPlacementActive(for: .support),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .resistance,
                            isActive: isMarkerPlacementActive(for: .resistance),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .indicator,
                            isActive: isMarkerPlacementActive(for: .indicator),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .trendline,
                            isActive: isMarkerPlacementActive(for: .trendline),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .pattern,
                            isActive: isMarkerPlacementActive(for: .pattern),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .volumeSpike,
                            isActive: isMarkerPlacementActive(for: .volumeSpike),
                            controlViewModel: controlViewModel
                        )
                    }
                    
                    // MARK: - Prediction Markers Section
                    Text("Prediction Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .predictionTarget,
                            isActive: isMarkerPlacementActive(for: .predictionTarget),
                            controlViewModel: controlViewModel
                        )
                        
                        Spacer()
                        Spacer()
                    }
                    
                    // MARK: - Social Markers Section
                    Text("Social Markers")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 10) {
                        MarkerButton(
                            type: .emoji,
                            isActive: isMarkerPlacementActive(for: .emoji),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .poll,
                            isActive: isMarkerPlacementActive(for: .poll),
                            controlViewModel: controlViewModel
                        )
                        
                        MarkerButton(
                            type: .personal,
                            isActive: isMarkerPlacementActive(for: .personal),
                            controlViewModel: controlViewModel
                        )
                    }
                }
            }
        }
    }
    
    /// Check if marker placement is active for a specific type
    private func isMarkerPlacementActive(for type: MarkerType) -> Bool {
        controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerType == type
    }
    
    
//    private var markersContent: some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Add a Marker")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.top, 15)
//
//                Text("Place markers on the chart to share insights with your guild")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                    .padding(.bottom, 8)
//
//                // chart markers
//                // core - note, question, entry, exit
//                // analysis - support, resistance, pattern, trendline, volume spike, indicator
//                // prediction - prediction (direction), prediction (target price)
//                // social - reaction(emoji), poll
//
//                VStack(spacing: 8) {
//
//                    Text("Core Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 4)
//                        .padding(.bottom, 4)
//
//
//                    // TODO: - All markers allow a note section for the user to write a basic note/message about their marker placement, also allow likes, and display marker set time and price, all markers should allow basic commenting for other users, not real messaging like the other parts of the app just a basic commenting section,  there should be a couple of buttons allowing to share, save and report marker, everything else is custom to the marker
//
//                    HStack(spacing: 10){
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Note",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "pencil.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .gray,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Question",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "questionmark.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .blue,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Alert",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "bell.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .yellow,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - custom detail view allow to pick from a few types of alert, mild, severe etc...
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                    }
//
//
//
//
//                    HStack(spacing: 10){
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Entry",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "arrow.up.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .green,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - a set horizontal line is placed at the open of the selected candle indicating entry line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Exit",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "arrow.down.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .orange,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - a set horizontal line is placed at the close of the selected candle indicating exit line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                    }
//
//
//
//
//
//                    Text("Analysis Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 12)
//                        .padding(.bottom, 4)
//
//                    HStack(spacing: 10){
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Support",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "s.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .purple,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - a set horizontal line is placed at the high of the selected candle indicating support line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Resistance",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "r.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .pink,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - a set horizontal line is placed at the low of the selected candle indicating resistance line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Indicator",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "star.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .teal,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//
//                            // TODO: - custom detail view section allows user to select indicator to reference
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                    }
//
//                    HStack(spacing: 10){
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Trendline",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "chart.line.uptrend.xyaxis.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .indigo,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - custom detail view section allows user to select direction of trendline
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Pattern",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "circle.hexagongrid.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .cyan,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//
//                            // TODO: - custom detail view section allows user to select pattern from a selection of known chart patterns
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Volume Spike",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "chart.line.downtrend.xyaxis.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .mint,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                    }
//
//
//
//                    Text("Prediction Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 12)
//                        .padding(.bottom, 4)
//
//                    HStack(spacing: 10){
//
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Prediction (Target Price)",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "staroflife.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .tgAccentDark,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - custom detail view section allows user to select a target price (stop Loss) via a draggable target price horizontal line, there is also a fixed entry line showing price of entry, when selecting the marker the lines are displayed and price highlighted on y axis like the price indicator
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                    }
//
//                    Text("Social Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 12)
//                        .padding(.bottom, 4)
//
//                    HStack(spacing: 10){
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Emoji",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "face.smiling.inverse",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .white,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - custom detail view section allows user to select emoji symbol
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Poll",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "newspaper.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .blue,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - custom detail view section allows user to set a poll question and answers, users can select their answer, show results
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                        ChartControlButton(
//                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Personal",
//                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "person.circle",
//                            color: controlViewModel.isMarkerPlacementMode ? .red : .tgMidGrey,
//                            isActive: controlViewModel.isMarkerPlacementMode
//                        ) {
//                            // TODO: - custom detail view section allows user to set a poll question and answers, users can select their answer, show results
//                            controlViewModel.toggleMarkerPlacement()
//                        }
//
//                    }
//
//                }
//            }
//        }
//    }
    
//    private var chartControlsContent: some View {
//        VStack(spacing: 20) {
//            // SECTION: Marker Tools
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Marker Tools")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//
//                HStack(spacing: 16) {
//                    ChartControlButton(
//                        title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Place Marker",
//                        icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "mappin.circle",
//                        color: controlViewModel.isMarkerPlacementMode ? .red : .green,
//                        isActive: controlViewModel.isMarkerPlacementMode
//                    ) {
//                        controlViewModel.toggleMarkerPlacement()
//                    }
//
//                    ChartControlButton(
//                        title: "Filter",
//                        icon: "line.3.horizontal.decrease.circle",
//                        color: .orange
//                    ) {
//                        print("Filter tapped")
//                    }
//                }
//            }
//
//            // SECTION: Navigation
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Navigation")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//
//                HStack(spacing: 16) {
//                    ChartControlButton(
//                        title: "Start",
//                        icon: "arrow.left.to.line",
//                        color: .blue
//                    ) {
//                        controlViewModel.jumpToStart()
//                    }
//
//                    ChartControlButton(
//                        title: "Latest",
//                        icon: "arrow.right.to.line",
//                        color: .blue
//                    ) {
//                        controlViewModel.jumpToLatest()
//                    }
//                }
//
//                HStack(spacing: 16) {
//                    ChartControlButton(
//                        title: "Reset View",
//                        icon: "arrow.counterclockwise",
//                        color: .purple
//                    ) {
//                        controlViewModel.resetChart()
//                    }
//
//                    ChartControlButton(
//                        title: "Auto-Scroll",
//                        icon: "arrow.right.circle",
//                        color: .indigo,
//                        isActive: controlViewModel.isAutoScrolling
//                    ) {
//                        controlViewModel.toggleAutoScroll()
//                    }
//                }
//            }
//
//            // SECTION: Zoom Info
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Zoom & Scale")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//
//                VStack(spacing: 12) {
//                    HStack {
//                        Text("Horizontal Zoom")
//                            .font(.caption)
//                            .foregroundColor(.white.opacity(0.8))
//                        Spacer()
//                        Text("Use pinch gesture")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                    }
//
//                    HStack {
//                        Text("Vertical Scale")
//                            .font(.caption)
//                            .foregroundColor(.white.opacity(0.8))
//                        Spacer()
//                        Text("Drag Y-axis area")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                    }
//                }
//                .padding()
//                .background(Color.white.opacity(0.05))
//                .cornerRadius(8)
//            }
//        }
//    }
}





// MARK: - Helper Components






// MARK: - Marker Button Component

/// A button for selecting a marker type to place
/// Shows cancel state when this type is currently being placed
struct MarkerButton: View {
    let type: MarkerType
    let isActive: Bool
    @ObservedObject var controlViewModel: ChartControlViewModel
    
    var body: some View {
        Button {
            if isActive {
                // Currently placing this type - cancel
                controlViewModel.cancelMarkerPlacement()
            } else {
                // Start placing this type
                controlViewModel.startMarkerPlacement(type: type)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isActive ? "xmark.circle" : type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isActive ? .white : type.color)
                
                Text(isActive ? "Cancel" : type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                isActive ?
                Color.red :
                Color.white.opacity(0.1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}




struct SymbolRow: View {
    let symbol: TradingSymbol
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol.assetClass.icon)
                    .foregroundColor(isSelected ? .white : .blue)
                    .font(.title3)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.displayName)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    HStack(spacing: 6) {
                        Text(symbol.symbol)
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text("•")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text(symbol.assetClass.rawValue)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            // EVEN BETTER ✅
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]
                        : [Color.white.opacity(0.05), Color.white.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct TimeframeButton: View {
    let timeframe: ChartTimeframe
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.shortName)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ?
                    Color.blue :
                    Color.white.opacity(0.1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
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









////
////  MainView.swift
////  traders_guild
////
////  COMPLETE CORRECTED VERSION
////  Based on your working commented version with ChartViewModel added
////
//
//import SwiftUI
//import SwiftTradingView
//
//// MARK: - Constants
//enum LayoutConstants {
//    static let drawerWidthRatio: CGFloat = 0.9
//    static let drawerDismissThreshold: CGFloat = 100
//    static let overlayOpacity: CGFloat = 0.4
//    static let cornerRadius: CGFloat = 33
//    static let shadowRadius: CGFloat = 8
//}
//
//enum AnimationConstants {
//    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
//    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
//}
//
//// MARK: - Main View
//struct MainView: View {
//    // MARK: - Properties
//    @EnvironmentObject var appState: AppState
//    @EnvironmentObject var messagingManager: MessagingManager
//    @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
//    @StateObject private var rightDrawerViewModel = RightDrawerViewModel()
//    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
//    
//    // MARK: - Chart State
//    @StateObject private var chartControlVM = ChartControlViewModel()
//    @StateObject private var chartDataManager = ChartDataManager()
//    @StateObject private var chartViewModel: ChartViewModel
//    
//    @State private var fadeIn: Bool = false
//    
//    // MARK: - Drawer State Management
//    @State private var showLeftDrawer: Bool = false
//    @State private var showRightDrawer: Bool = false
//    @State private var showOverlay: Bool = false
//    @State private var leftDragTranslation: CGFloat = 0
//    @State private var rightDragTranslation: CGFloat = 0
//    
//    // MARK: - Bottom Sheet State
//    @State private var showBottomSheet: Bool = false
//    @State private var selectedDetent: PresentationDetent = .fraction(0.11)
//    
//    // MARK: - Sheet Overlay State
//    @State private var showSheetOverlay: Bool = false
//    @State private var dismissRightSheetsSignal: Bool = false
//    @State private var dismissLeftSheetsSignal: Bool = false
//    
//    // MARK: - Computed Properties
//    private var screenSize: CGSize {
//        UIScreen.main.bounds.size
//    }
//    
//    private var drawerWidth: CGFloat {
//        screenSize.width * LayoutConstants.drawerWidthRatio
//    }
//    
//    // MARK: - Initialization
//    init() {
//        let dataManager = ChartDataManager()
//        _chartDataManager = StateObject(wrappedValue: dataManager)
//        _chartViewModel = StateObject(wrappedValue: ChartViewModel(
//            appState: AppState(),
//            dataManager: dataManager,
//            api: MockAPIService()
//        ))
//    }
//    
//    // MARK: - Body
//    var body: some View {
//        if let user = appState.currentUser,
//           let guild = appState.currentGuild {
//            ZStack {
//                // MARK: - Main Content Layer
//                mainContentStack
//                    .disabled(showLeftDrawer || showRightDrawer)
//                
//                // MARK: - Overlay Layer
//                if showOverlay {
//                    overlayView
//                        .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
//                        .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
//                        .animation(.easeOut(duration: 0.4), value: showRightDrawer)
//                        .gesture(
//                            DragGesture()
//                                .onChanged { value in
//                                    dismissRightSheetsSignal = true
//                                    if showLeftDrawer && value.translation.width < 0 {
//                                        leftDragTranslation = value.translation.width
//                                    } else if showRightDrawer && value.translation.width > 0 {
//                                        rightDragTranslation = value.translation.width
//                                    }
//                                }
//                                .onEnded { value in
//                                    handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
//                                }
//                        )
//                }
//                
//                // MARK: - Drawer Layers
//                leftDrawerView
//                    .opacity(fadeIn ? 1 : 0)
//                    .animation(.easeIn(duration: 1.5), value: fadeIn)
//                
//                rightDrawerView
//                    .opacity(fadeIn ? 1 : 0)
//                    .animation(.easeIn(duration: 1.5), value: fadeIn)
//                
//                // MARK: - Sheet Overlay Layer
//                if showSheetOverlay {
//                    sheetOverlayView
//                        .opacity(showSheetOverlay ? 1 : 0)
//                        .animation(.linear(duration: 0.05), value: showSheetOverlay)
//                }
//            }
//            .ignoresSafeArea()
//            .globalMessaging()
//            
//            // MARK: - Bottom Sheet
//            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
//                ChartBottomSheet(
//                    controlViewModel: chartControlVM,
//                    chartViewModel: chartViewModel,
//                    selectedDetent: $selectedDetent
//                )
//                .presentationDetents([.fraction(0.11), .fraction(0.5), .fraction(0.9)],
//                                      selection: $selectedDetent)
//                .presentationDragIndicator(.visible)
//                .presentationBackgroundInteraction(.enabled)
//                .interactiveDismissDisabled(true)
//                .presentationContentInteraction(.resizes)
//                .presentationBackground {
//                    ZStack {
//                        Color.clear
//                            .background(.ultraThinMaterial)
//                        AppColors.drawerBackground.opacity(0.4)
//                    }
//                }
//            }
//            .onAppear {
//                withAnimation(.easeIn(duration: 1.5)) {
//                    fadeIn = true
//                }
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
//                        showBottomSheet = true
//                    }
//                }
//            }
//            .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
//            .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
//            
//            .environmentObject(leftDrawerViewModel)
//            .environmentObject(rightDrawerViewModel)
//            .environmentObject(notificationNavigationManager)
//            .task {
//                await leftDrawerViewModel.preloadData(for: guild.id, appState: appState)
//                await rightDrawerViewModel.preloadData(for: guild.id, appState: appState)
//                
//                // FIXED: Correct method signature
//                notificationNavigationManager.configure(
//                    appState: appState,
//                    messagingManager: messagingManager,
//                    rightDrawerViewModel: rightDrawerViewModel
//                )
//                
//                // Initialize chart with data
//                await chartViewModel.initialize()
//            }
//            .onChange(of: appState.currentGuild?.id) { oldValue, newValue in
//                if let guildId = newValue, oldValue != newValue {
//                    Task {
//                        leftDrawerViewModel.clearCache()
//                        rightDrawerViewModel.clearCache()
//                        await leftDrawerViewModel.preloadData(for: guildId, appState: appState)
//                        await rightDrawerViewModel.preloadData(for: guildId, appState: appState)
//                        await chartViewModel.initialize()
//                    }
//                }
//            }
//        } else {
//            VStack(spacing: 20) {
//                ProgressView()
//                    .scaleEffect(1.5)
//                Text("Reconnecting...")
//                    .foregroundColor(.secondary)
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .onAppear {
//                Task {
//                    if appState.currentUser != nil && appState.currentGuild == nil {
//                        await appState.openGuildSelector()
//                    } else if appState.currentUser == nil {
//                        appState.logout()
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - View Components
//    
//    private var mainContentStack: some View {
//        NavigationStack {
//            ZStack {
//                StaticBackgroundView()
//                
//                VStack(spacing: 0) {
//                    chartView(controlViewModel: chartControlVM)
//                }
//                .opacity(fadeIn ? 1 : 0)
//                .animation(.easeIn(duration: 1.5), value: fadeIn)
//            }
//            .toolbar {
//                // Left Drawer Button
//                ToolbarItem(placement: .topBarLeading) {
//                    ToolbarIconButton(
//                        systemName: "shield.pattern.checkered",
//                        backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
//                        fontType: .headline,
//                        symbolRenderingMode: .monochrome,
//                        foregroundStyle: AppColors.whiteText,
//                        padding: 8
//                    ) {
//                        withAnimation(AnimationConstants.standard) {
//                            selectedDetent = .fraction(0.11)
//                            showLeftDrawer.toggle()
//                            showRightDrawer = false
//                            showOverlay = showLeftDrawer
//                        }
//                    }
//                }
//                
//                // App Title
//                ToolbarItem(placement: .principal) {
//                    Text("TG")
//                        .font(.largeTitle)
//                        .fontWeight(.heavy)
//                        .foregroundColor(AppColors.fadedBackground)
//                }
//                
//                // Right Drawer Button
//                ToolbarItem(placement: .topBarTrailing) {
//                    ToolbarIconButton(
//                        systemName: "message.badge.filled.fill",
//                        backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
//                        fontType: .subheadline,
//                        symbolRenderingMode: .monochrome,
//                        foregroundStyle: AppColors.whiteText,
//                        padding: 8
//                    ) {
//                        withAnimation(AnimationConstants.standard) {
//                            selectedDetent = .fraction(0.11)
//                            showRightDrawer.toggle()
//                            showLeftDrawer = false
//                            showOverlay = showRightDrawer
//                        }
//                    }
//                }
//            }
//            .toolbarBackground(.hidden, for: .navigationBar)
//            .toolbarColorScheme(.dark, for: .navigationBar)
//            .tint(.white)
//            .navigationBarTitleDisplayMode(.inline)
//        }
//    }
//    
//    // FIXED: chartView function that uses TradingChartView with ChartViewModel
//    private func chartView(controlViewModel: ChartControlViewModel) -> some View {
//        TradingChartView(
//            controlViewModel: controlViewModel,
//            chartViewModel: chartViewModel
//        )
//    }
//    
//    private var overlayView: some View {
//        Color.black.opacity(LayoutConstants.overlayOpacity)
//            .ignoresSafeArea()
//            .onTapGesture {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    showRightDrawer = false
//                    leftDragTranslation = 0
//                    rightDragTranslation = 0
//                    dismissRightSheetsSignal = true
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
//    }
//    
//    private var sheetOverlayView: some View {
//        Color.black.opacity(LayoutConstants.overlayOpacity * 0.8)
//            .ignoresSafeArea()
//            .contentShape(Rectangle())
//            .onTapGesture {
//                dismissRightSheetsSignal = true
//                dismissLeftSheetsSignal = true
//            }
//            .simultaneousGesture(DragGesture().onChanged { _ in
//                dismissRightSheetsSignal = true
//                dismissLeftSheetsSignal = true
//            })
//    }
//    
//    // FIXED: Using LeftDrawerMainView (correct name)
//    private var leftDrawerView: some View {
//        HStack(spacing: 0) {
//            LeftDrawerMainView(sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal) {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    leftDragTranslation = 0
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: leftDragTranslation)
//            .gesture(
//                DragGesture()
//                    .onChanged { value in
//                        if value.translation.width < 0 {
//                            leftDragTranslation = value.translation.width
//                        }
//                    }
//                    .onEnded { value in
//                        handleDrawerDragEnd(currentPosition: leftDragTranslation)
//                    }
//            )
//            Spacer(minLength: 0)
//        }
//        .frame(maxHeight: .infinity)
//        .offset(x: showLeftDrawer ? 0 : -drawerWidth)
//        .animation(AnimationConstants.standard, value: showLeftDrawer)
//    }
//    
//    // FIXED: Using RightDrawerMainView (correct name)
//    private var rightDrawerView: some View {
//        HStack(spacing: 0) {
//            Spacer(minLength: 0)
//            RightDrawerMainView(
//                onClose: {
//                    withAnimation(AnimationConstants.standard) {
//                        showRightDrawer = false
//                        rightDragTranslation = 0
//                    }
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                        showOverlay = false
//                    }
//                }
//            )
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: rightDragTranslation)
//            .gesture(
//                DragGesture()
//                    .onChanged { value in
//                        if value.translation.width > 0 {
//                            rightDragTranslation = value.translation.width
//                        }
//                    }
//                    .onEnded { value in
//                        handleDrawerDragEnd(currentPosition: rightDragTranslation)
//                    }
//            )
//        }
//        .frame(maxHeight: .infinity)
//        .offset(x: showRightDrawer ? 0 : drawerWidth)
//        .animation(AnimationConstants.standard, value: showRightDrawer)
//    }
//    
//    // MARK: - Helper Functions
//    
//    private func handleDrawerDragEnd(currentPosition: CGFloat) {
//        if showLeftDrawer {
//            if currentPosition < -LayoutConstants.drawerDismissThreshold {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    leftDragTranslation = 0
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            } else {
//                withAnimation(AnimationConstants.standard) {
//                    leftDragTranslation = 0
//                }
//            }
//        } else if showRightDrawer {
//            if currentPosition > LayoutConstants.drawerDismissThreshold {
//                withAnimation(AnimationConstants.standard) {
//                    showRightDrawer = false
//                    rightDragTranslation = 0
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            } else {
//                withAnimation(AnimationConstants.standard) {
//                    rightDragTranslation = 0
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Drawer Side
//enum DrawerSide { case left, right }
//
//// MARK: - Chart Bottom Sheet
//struct ChartBottomSheet: View {
//    @State private var selectedView: ChartView = .symbol
//    @ObservedObject var controlViewModel: ChartControlViewModel
//    @ObservedObject var chartViewModel: ChartViewModel
//    @Binding var selectedDetent: PresentationDetent
//    
//    enum ChartView: String, CaseIterable {
//        case symbol = "Symbol"
//        case chat = "Chat"
//        case indicator = "Indicator"
//        case markers = "Markers"
////        case controls = "Controls"
//        
//        var icon: String {
//            switch self {
//            case .symbol: return "chart.bar.fill"
//            case .chat: return "message.fill"
//            case .indicator: return "chart.line.uptrend.xyaxis.circle"
//            case .markers: return "mappin.circle.fill"
////            case .controls: return "slider.horizontal.3"
//            }
//        }
//    }
//    
//    private var isExpanded: Bool {
//        selectedDetent != .fraction(0.11)
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Content Area
//            if isExpanded {
//                ScrollView {
//                    VStack(spacing: 16) {
//                        switch selectedView {
//                        case .symbol:
//                            symbolAndSettingsContent
//                        case .chat:
//                            chatContent
//                        case .indicator:
//                            indicatorContent
//                        case .markers:
//                            markersContent
////                        case .controls:
////                            chartControlsContent
//                        }
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.top, 20)
//                    .padding(.bottom, 20)
//                    .animation(.easeInOut(duration: 0.3), value: selectedView)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            } else {
//                Spacer()
//            }
//            
//            // Fixed Button Bar
//            VStack(spacing: 0) {
//                if isExpanded {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(height: 0.5)
//                }
//                
//                HStack(spacing: 4) {
//                    // Symbol button
//                    RootBottomBarSymbolButton(
//                        symbol: chartViewModel.currentSymbol?.symbol ?? "EUR/USD",
//                        backgroundColor: selectedView == .symbol ?
//                            AppColors.gradientBackgroundDark :
//                            AppColors.gradientBackgroundMid.opacity(0.9),
//                        foregroundColor: selectedView == .symbol ?
//                            .white :
//                            AppColors.whiteText.opacity(0.8)
//                    ) {
//                        withAnimation(.easeInOut(duration: 0.25)) {
//                            selectedView = .symbol
//                        }
//                    }
//                    
//                    Spacer()
//                    
//                    HStack(spacing: 4) {
//                        // Chat button
//                        RootBottomBarIconButton(
//                            systemName: "message.fill",
//                            backgroundColor: selectedView == .chat ?
//                                AppColors.gradientBackgroundDark :
//                                AppColors.gradientBackgroundMid.opacity(0.9),
//                            foregroundColor: selectedView == .chat ?
//                                .white :
//                                AppColors.whiteText.opacity(0.8)
//                        ) {
//                            withAnimation(.easeInOut(duration: 0.25)) {
//                                selectedView = .chat
//                            }
//                        }
//                        
//                        // Indicator button
//                        RootBottomBarIconButton(
//                            systemName: "chart.line.uptrend.xyaxis.circle",
//                            fontSize: 25,
//                            backgroundColor: selectedView == .indicator ?
//                                AppColors.gradientBackgroundDark :
//                                AppColors.gradientBackgroundMid.opacity(0.9),
//                            foregroundColor: selectedView == .indicator ?
//                                .white :
//                                AppColors.whiteText.opacity(0.8)
//                        ) {
//                            withAnimation(.easeInOut(duration: 0.25)) {
//                                selectedView = .indicator
//                            }
//                        }
//                        
//                        // Markers button
//                        RootBottomBarIconButton(
//                            systemName: "target",
//                            fontSize: 25,
//                            backgroundColor: selectedView == .markers ?
//                                AppColors.whiteText :
//                                AppColors.whiteText.opacity(0.5),
//                            foregroundColor: selectedView == .markers ?
//                                AppColors.gradientBackgroundDark :
//                                AppColors.gradientBackgroundDark.opacity(0.8)
//                        ) {
//                            withAnimation(.easeInOut(duration: 0.25)) {
//                                selectedView = .markers
//                            }
//                        }
//                        
////                        // Controls button
////                        RootBottomBarIconButton(
////                            systemName: "slider.horizontal.3",
////                            fontSize: 25,
////                            backgroundColor: selectedView == .controls ?
////                                AppColors.whiteText :
////                                AppColors.whiteText.opacity(0.5),
////                            foregroundColor: selectedView == .controls ?
////                                AppColors.gradientBackgroundDark :
////                                AppColors.gradientBackgroundDark.opacity(0.8)
////                        ) {
////                            withAnimation(.easeInOut(duration: 0.25)) {
////                                selectedView = .controls
////                            }
////                        }
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.top, isExpanded ? 16 : 0)
//                .padding(.bottom, 2)
//            }
//            .frame(height: isExpanded ? 70 : 68)
//        }
//    }
//    
//    // MARK: - Symbol Tab Content (NEW - Enhanced with timeframe and watchlist)
//    private var symbolAndSettingsContent: some View {
//        VStack(spacing: 20) {
//            HStack(spacing: 10){
//                ChartControlButton(
//                    title: "Latest",
//                    icon: "arrow.right.to.line",
//                    color: .blue
//                ) {
//                    controlViewModel.jumpToLatest()
//                }
//                
//                ChartControlButton(
//                    title: "Reset View",
//                    icon: "arrow.counterclockwise",
//                    color: .purple
//                ) {
//                    controlViewModel.resetChart()
//                }
//            }
//            // SECTION: Current Symbol Info
//            if let symbol = chartViewModel.currentSymbol {
//                VStack(spacing: 12) {
//                    HStack(alignment: .top) {
//                        // Symbol details
//                        VStack(alignment: .leading, spacing: 6) {
//                            HStack(spacing: 8) {
//                                Image(systemName: symbol.assetClass.icon)
//                                    .foregroundColor(.blue)
//                                    .font(.title3)
//                                
//                                VStack(alignment: .leading, spacing: 2) {
//                                    Text(symbol.displayName)
//                                        .foregroundColor(.white)
//                                        .font(.headline)
//                                    Text(symbol.symbol)
//                                        .foregroundColor(.white.opacity(0.6))
//                                        .font(.caption)
//                                }
//                            }
//                            
//                            Text(symbol.assetClass.rawValue)
//                                .foregroundColor(.white.opacity(0.5))
//                                .font(.caption2)
//                                .padding(.horizontal, 8)
//                                .padding(.vertical, 4)
//                                .background(Color.white.opacity(0.1))
//                                .cornerRadius(4)
//                        }
//                        
//                        Spacer()
//                        
//                        // Current price
//                        VStack(alignment: .trailing, spacing: 4) {
//                            Text(symbol.formatPrice(chartViewModel.dataManager.currentPrice))
//                                .foregroundColor(.white)
//                                .font(.title2)
//                                .fontWeight(.bold)
//                            Text(chartViewModel.currentTimeframe.displayName)
//                                .foregroundColor(.gray)
//                                .font(.caption)
//                        }
//                    }
//                }
//                .padding()
//                .background(
//                    LinearGradient(
//                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                    )
//                )
//                .cornerRadius(12)
//            }
//            
//            // Loading indicator
//            if chartViewModel.isLoadingData {
//                HStack {
//                    ProgressView()
//                        .tint(.white)
//                    Text("Loading data...")
//                        .foregroundColor(.gray)
//                        .font(.caption)
//                }
//                .padding()
//            }
//            
//            // SECTION: Timeframe Selector
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Timeframe")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
//                // Grouped by category
//                VStack(spacing: 12) {
//                    // Minutes
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("Minutes")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        
//                        LazyVGrid(columns: [
//                            GridItem(.flexible()),
//                            GridItem(.flexible()),
//                            GridItem(.flexible()),
//                            GridItem(.flexible())
//                        ], spacing: 8) {
//                            ForEach([ChartTimeframe.m1, .m5, .m15, .m30], id: \.self) { timeframe in
//                                TimeframeButton(
//                                    timeframe: timeframe,
//                                    isSelected: chartViewModel.currentTimeframe == timeframe
//                                ) {
//                                    chartViewModel.setTimeframe(timeframe)
//                                }
//                            }
//                        }
//                    }
//                    
//                    // Hours
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("Hours")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        
//                        LazyVGrid(columns: [
//                            GridItem(.flexible()),
//                            GridItem(.flexible()),
//                            GridItem(.flexible()),
//                            GridItem(.flexible())
//                        ], spacing: 8) {
//                            ForEach([ChartTimeframe.h1, .h4], id: \.self) { timeframe in
//                                TimeframeButton(
//                                    timeframe: timeframe,
//                                    isSelected: chartViewModel.currentTimeframe == timeframe
//                                ) {
//                                    chartViewModel.setTimeframe(timeframe)
//                                }
//                            }
//                        }
//                    }
//                    
//                    // Daily+
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("Daily & Weekly")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        
//                        LazyVGrid(columns: [
//                            GridItem(.flexible()),
//                            GridItem(.flexible()),
//                            GridItem(.flexible()),
//                            GridItem(.flexible())
//                        ], spacing: 8) {
//                            ForEach([ChartTimeframe.d1, .w1, .mn], id: \.self) { timeframe in
//                                TimeframeButton(
//                                    timeframe: timeframe,
//                                    isSelected: chartViewModel.currentTimeframe == timeframe
//                                ) {
//                                    chartViewModel.setTimeframe(timeframe)
//                                }
//                            }
//                        }
//                    }
//                }
//                .padding()
//                .background(Color.white.opacity(0.05))
//                .cornerRadius(12)
//            }
//            
//            // SECTION: Watchlist
//            VStack(alignment: .leading, spacing: 12) {
//                HStack {
//                    Text("Watchlist")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                    
//                    Spacer()
//                    
//                    Text("\(chartViewModel.combinedWatchlist.count) symbols")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                }
//                
//                if chartViewModel.combinedWatchlist.isEmpty {
//                    Text("No symbols in watchlist")
//                        .foregroundColor(.gray)
//                        .font(.caption)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.white.opacity(0.05))
//                        .cornerRadius(8)
//                } else {
//                    VStack(spacing: 8) {
//                        ForEach(chartViewModel.combinedWatchlist) { symbol in
//                            SymbolRow(
//                                symbol: symbol,
//                                isSelected: chartViewModel.currentSymbol?.id == symbol.id
//                            ) {
//                                chartViewModel.setSymbol(symbol)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Other Tab Contents
//    
//    private var chatContent: some View {
//        VStack(spacing: 16) {
//            Text("Chart Chat")
//                .font(.headline)
//                .foregroundColor(.white)
//            
//            Text("Real-time chat with guild members while analyzing the chart")
//                .font(.caption)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//        }
//    }
//    
//    private var indicatorContent: some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Indicators")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
//                VStack(spacing: 8) {
//                    IndicatorItem(title: "Moving Average", icon: "chart.line.uptrend.xyaxis", color: .blue)
//                    IndicatorItem(title: "RSI", icon: "chart.bar", color: .orange)
//                    IndicatorItem(title: "MACD", icon: "waveform.path.ecg", color: .green)
//                    IndicatorItem(title: "Bollinger Bands", icon: "arrow.up.and.down", color: .purple)
//                }
//            }
//        }
//    }
//    
//
//    /// Updated markersContent with specific marker type buttons
//    /// Each button triggers placement mode for its specific marker type
//    var markersContent: some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Add a Marker")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.top, 15)
//                
//                Text("Place markers on the chart to share insights with your guild. Each candle can have one of each marker type.")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                    .padding(.bottom, 8)
//                
//                VStack(spacing: 8) {
//                    
//                    // MARK: - Core Markers Section
//                    Text("Core Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 4)
//                        .padding(.bottom, 4)
//                    
//                    HStack(spacing: 10) {
//                        MarkerButton(
//                            type: .note,
//                            isActive: isMarkerPlacementActive(for: .note),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .question,
//                            isActive: isMarkerPlacementActive(for: .question),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .alert,
//                            isActive: isMarkerPlacementActive(for: .alert),
//                            controlViewModel: controlViewModel
//                        )
//                    }
//                    
//                    HStack(spacing: 10) {
//                        MarkerButton(
//                            type: .entry,
//                            isActive: isMarkerPlacementActive(for: .entry),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .exit,
//                            isActive: isMarkerPlacementActive(for: .exit),
//                            controlViewModel: controlViewModel
//                        )
//                    }
//                    
//                    // MARK: - Analysis Markers Section
//                    Text("Analysis Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 12)
//                        .padding(.bottom, 4)
//                    
//                    HStack(spacing: 10) {
//                        MarkerButton(
//                            type: .support,
//                            isActive: isMarkerPlacementActive(for: .support),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .resistance,
//                            isActive: isMarkerPlacementActive(for: .resistance),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .indicator,
//                            isActive: isMarkerPlacementActive(for: .indicator),
//                            controlViewModel: controlViewModel
//                        )
//                    }
//                    
//                    HStack(spacing: 10) {
//                        MarkerButton(
//                            type: .trendline,
//                            isActive: isMarkerPlacementActive(for: .trendline),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .pattern,
//                            isActive: isMarkerPlacementActive(for: .pattern),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .volumeSpike,
//                            isActive: isMarkerPlacementActive(for: .volumeSpike),
//                            controlViewModel: controlViewModel
//                        )
//                    }
//                    
//                    // MARK: - Prediction Markers Section
//                    Text("Prediction Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 12)
//                        .padding(.bottom, 4)
//                    
//                    HStack(spacing: 10) {
//                        MarkerButton(
//                            type: .predictionTarget,
//                            isActive: isMarkerPlacementActive(for: .predictionTarget),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        Spacer()
//                        Spacer()
//                    }
//                    
//                    // MARK: - Social Markers Section
//                    Text("Social Markers")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.top, 12)
//                        .padding(.bottom, 4)
//                    
//                    HStack(spacing: 10) {
//                        MarkerButton(
//                            type: .emoji,
//                            isActive: isMarkerPlacementActive(for: .emoji),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .poll,
//                            isActive: isMarkerPlacementActive(for: .poll),
//                            controlViewModel: controlViewModel
//                        )
//                        
//                        MarkerButton(
//                            type: .personal,
//                            isActive: isMarkerPlacementActive(for: .personal),
//                            controlViewModel: controlViewModel
//                        )
//                    }
//                }
//            }
//        }
//    }
//    
//    /// Check if marker placement is active for a specific type
//    private func isMarkerPlacementActive(for type: MarkerType) -> Bool {
//        controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerType == type
//    }
//    
//    
////    private var markersContent: some View {
////        VStack(spacing: 16) {
////            VStack(alignment: .leading, spacing: 12) {
////                Text("Add a Marker")
////                    .font(.title2)
////                    .fontWeight(.bold)
////                    .foregroundColor(.white)
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                    .padding(.top, 15)
////                
////                Text("Place markers on the chart to share insights with your guild")
////                    .font(.caption)
////                    .foregroundColor(.gray)
////                    .padding(.bottom, 8)
////                
////                // chart markers
////                // core - note, question, entry, exit
////                // analysis - support, resistance, pattern, trendline, volume spike, indicator
////                // prediction - prediction (direction), prediction (target price)
////                // social - reaction(emoji), poll
////                
////                VStack(spacing: 8) {
////                    
////                    Text("Core Markers")
////                        .font(.headline)
////                        .foregroundColor(.white)
////                        .frame(maxWidth: .infinity, alignment: .leading)
////                        .padding(.top, 4)
////                        .padding(.bottom, 4)
////                        
////                    
////                    // TODO: - All markers allow a note section for the user to write a basic note/message about their marker placement, also allow likes, and display marker set time and price, all markers should allow basic commenting for other users, not real messaging like the other parts of the app just a basic commenting section,  there should be a couple of buttons allowing to share, save and report marker, everything else is custom to the marker
////                    
////                    HStack(spacing: 10){
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Note",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "pencil.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .gray,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Question",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "questionmark.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .blue,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Alert",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "bell.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .yellow,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - custom detail view allow to pick from a few types of alert, mild, severe etc...
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                    }
////                    
////                    
////                    
////                    
////                    HStack(spacing: 10){
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Entry",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "arrow.up.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .green,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - a set horizontal line is placed at the open of the selected candle indicating entry line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Exit",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "arrow.down.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .orange,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - a set horizontal line is placed at the close of the selected candle indicating exit line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                    }
////                    
////                    
////                    
////                    
////                    
////                    Text("Analysis Markers")
////                        .font(.headline)
////                        .foregroundColor(.white)
////                        .frame(maxWidth: .infinity, alignment: .leading)
////                        .padding(.top, 12)
////                        .padding(.bottom, 4)
////                    
////                    HStack(spacing: 10){
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Support",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "s.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .purple,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - a set horizontal line is placed at the high of the selected candle indicating support line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Resistance",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "r.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .pink,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - a set horizontal line is placed at the low of the selected candle indicating resistance line, when selecting the marker later the line is displayed and price highlighted on y axis like the price indicator
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Indicator",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "star.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .teal,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            
////                            // TODO: - custom detail view section allows user to select indicator to reference
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                    }
////                    
////                    HStack(spacing: 10){
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Trendline",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "chart.line.uptrend.xyaxis.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .indigo,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - custom detail view section allows user to select direction of trendline
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Pattern",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "circle.hexagongrid.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .cyan,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            
////                            // TODO: - custom detail view section allows user to select pattern from a selection of known chart patterns
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Volume Spike",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "chart.line.downtrend.xyaxis.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .mint,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                    }
////                    
////                    
////                    
////                    Text("Prediction Markers")
////                        .font(.headline)
////                        .foregroundColor(.white)
////                        .frame(maxWidth: .infinity, alignment: .leading)
////                        .padding(.top, 12)
////                        .padding(.bottom, 4)
////                    
////                    HStack(spacing: 10){
////                        
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Prediction (Target Price)",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "staroflife.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .tgAccentDark,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - custom detail view section allows user to select a target price (stop Loss) via a draggable target price horizontal line, there is also a fixed entry line showing price of entry, when selecting the marker the lines are displayed and price highlighted on y axis like the price indicator
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                    }
////                    
////                    Text("Social Markers")
////                        .font(.headline)
////                        .foregroundColor(.white)
////                        .frame(maxWidth: .infinity, alignment: .leading)
////                        .padding(.top, 12)
////                        .padding(.bottom, 4)
////                    
////                    HStack(spacing: 10){
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Emoji",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "face.smiling.inverse",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .white,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - custom detail view section allows user to select emoji symbol
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Poll",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "newspaper.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .blue,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - custom detail view section allows user to set a poll question and answers, users can select their answer, show results
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                        ChartControlButton(
////                            title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Personal",
////                            icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "person.circle",
////                            color: controlViewModel.isMarkerPlacementMode ? .red : .tgMidGrey,
////                            isActive: controlViewModel.isMarkerPlacementMode
////                        ) {
////                            // TODO: - custom detail view section allows user to set a poll question and answers, users can select their answer, show results
////                            controlViewModel.toggleMarkerPlacement()
////                        }
////                        
////                    }
////
////                }
////            }
////        }
////    }
//    
////    private var chartControlsContent: some View {
////        VStack(spacing: 20) {
////            // SECTION: Marker Tools
////            VStack(alignment: .leading, spacing: 12) {
////                Text("Marker Tools")
////                    .font(.headline)
////                    .foregroundColor(.white)
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                
////                HStack(spacing: 16) {
////                    ChartControlButton(
////                        title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Place Marker",
////                        icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "mappin.circle",
////                        color: controlViewModel.isMarkerPlacementMode ? .red : .green,
////                        isActive: controlViewModel.isMarkerPlacementMode
////                    ) {
////                        controlViewModel.toggleMarkerPlacement()
////                    }
////                    
////                    ChartControlButton(
////                        title: "Filter",
////                        icon: "line.3.horizontal.decrease.circle",
////                        color: .orange
////                    ) {
////                        print("Filter tapped")
////                    }
////                }
////            }
////            
////            // SECTION: Navigation
////            VStack(alignment: .leading, spacing: 12) {
////                Text("Navigation")
////                    .font(.headline)
////                    .foregroundColor(.white)
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                
////                HStack(spacing: 16) {
////                    ChartControlButton(
////                        title: "Start",
////                        icon: "arrow.left.to.line",
////                        color: .blue
////                    ) {
////                        controlViewModel.jumpToStart()
////                    }
////                    
////                    ChartControlButton(
////                        title: "Latest",
////                        icon: "arrow.right.to.line",
////                        color: .blue
////                    ) {
////                        controlViewModel.jumpToLatest()
////                    }
////                }
////                
////                HStack(spacing: 16) {
////                    ChartControlButton(
////                        title: "Reset View",
////                        icon: "arrow.counterclockwise",
////                        color: .purple
////                    ) {
////                        controlViewModel.resetChart()
////                    }
////                    
////                    ChartControlButton(
////                        title: "Auto-Scroll",
////                        icon: "arrow.right.circle",
////                        color: .indigo,
////                        isActive: controlViewModel.isAutoScrolling
////                    ) {
////                        controlViewModel.toggleAutoScroll()
////                    }
////                }
////            }
////            
////            // SECTION: Zoom Info
////            VStack(alignment: .leading, spacing: 12) {
////                Text("Zoom & Scale")
////                    .font(.headline)
////                    .foregroundColor(.white)
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                
////                VStack(spacing: 12) {
////                    HStack {
////                        Text("Horizontal Zoom")
////                            .font(.caption)
////                            .foregroundColor(.white.opacity(0.8))
////                        Spacer()
////                        Text("Use pinch gesture")
////                            .font(.caption)
////                            .foregroundColor(.gray)
////                    }
////                    
////                    HStack {
////                        Text("Vertical Scale")
////                            .font(.caption)
////                            .foregroundColor(.white.opacity(0.8))
////                        Spacer()
////                        Text("Drag Y-axis area")
////                            .font(.caption)
////                            .foregroundColor(.gray)
////                    }
////                }
////                .padding()
////                .background(Color.white.opacity(0.05))
////                .cornerRadius(8)
////            }
////        }
////    }
//}
//
//
//
//
//
//// MARK: - Helper Components
//
//
//
//
//
//
//// MARK: - Marker Button Component
//
///// A button for selecting a marker type to place
///// Shows cancel state when this type is currently being placed
//struct MarkerButton: View {
//    let type: MarkerType
//    let isActive: Bool
//    @ObservedObject var controlViewModel: ChartControlViewModel
//    
//    var body: some View {
//        Button {
//            if isActive {
//                // Currently placing this type - cancel
//                controlViewModel.cancelMarkerPlacement()
//            } else {
//                // Start placing this type
//                controlViewModel.startMarkerPlacement(type: type)
//            }
//        } label: {
//            VStack(spacing: 8) {
//                Image(systemName: isActive ? "xmark.circle" : type.icon)
//                    .font(.system(size: 32))
//                    .foregroundColor(isActive ? .white : type.color)
//                
//                Text(isActive ? "Cancel" : type.rawValue)
//                    .font(.caption)
//                    .fontWeight(.medium)
//                    .foregroundColor(.white.opacity(0.9))
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.7)
//            }
//            .frame(maxWidth: .infinity)
//            .frame(height: 90)
//            .background(
//                isActive ?
//                Color.red :
//                Color.white.opacity(0.1)
//            )
//            .cornerRadius(12)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//
//
//
//struct SymbolRow: View {
//    let symbol: TradingSymbol
//    let isSelected: Bool
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 12) {
//                Image(systemName: symbol.assetClass.icon)
//                    .foregroundColor(isSelected ? .white : .blue)
//                    .font(.title3)
//                    .frame(width: 32)
//                
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(symbol.displayName)
//                        .foregroundColor(.white)
//                        .font(.subheadline)
//                        .fontWeight(isSelected ? .semibold : .regular)
//                    HStack(spacing: 6) {
//                        Text(symbol.symbol)
//                            .foregroundColor(.gray)
//                            .font(.caption)
//                        Text("•")
//                            .foregroundColor(.gray)
//                            .font(.caption)
//                        Text(symbol.assetClass.rawValue)
//                            .foregroundColor(.gray)
//                            .font(.caption)
//                    }
//                }
//                
//                Spacer()
//                
//                if isSelected {
//                    Image(systemName: "checkmark.circle.fill")
//                        .foregroundColor(.blue)
//                        .font(.title3)
//                }
//            }
//            .padding()
//            // EVEN BETTER ✅
//            .background(
//                LinearGradient(
//                    colors: isSelected
//                        ? [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]
//                        : [Color.white.opacity(0.05), Color.white.opacity(0.05)],
//                    startPoint: .leading,
//                    endPoint: .trailing
//                )
//            )
//            .cornerRadius(12)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//struct TimeframeButton: View {
//    let timeframe: ChartTimeframe
//    let isSelected: Bool
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            Text(timeframe.shortName)
//                .font(.caption)
//                .fontWeight(isSelected ? .bold : .regular)
//                .foregroundColor(isSelected ? .white : .gray)
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 10)
//                .background(
//                    isSelected ?
//                    Color.blue :
//                    Color.white.opacity(0.1)
//                )
//                .cornerRadius(8)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//struct IndicatorItem: View {
//    let title: String
//    let icon: String
//    let color: Color
//    
//    var body: some View {
//        Button { } label: {
//            HStack(spacing: 12) {
//                Image(systemName: icon)
//                    .foregroundColor(color)
//                    .font(.title3)
//                    .frame(width: 32)
//                Text(title)
//                    .foregroundColor(.white)
//                    .fontWeight(.medium)
//                Spacer()
//                Image(systemName: "plus.circle")
//                    .foregroundColor(.gray)
//            }
//            .padding()
//            .background(Color.white.opacity(0.05))
//            .cornerRadius(8)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//struct MarkerTypeItem: View {
//    let title: String
//    let icon: String
//    let color: Color
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: icon)
//                .foregroundColor(color)
//                .font(.title3)
//                .frame(width: 32)
//            Text(title)
//                .foregroundColor(.white)
//                .fontWeight(.medium)
//            Spacer()
//        }
//        .padding()
//        .background(Color.white.opacity(0.05))
//        .cornerRadius(8)
//    }
//}
//
//struct ChartControlButton: View {
//    let title: String
//    let icon: String
//    let color: Color
//    var isActive: Bool = false
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            VStack(spacing: 8) {
//                Image(systemName: icon)
//                    .font(.system(size: 32))
//                    .foregroundColor(isActive ? .white : color)
//                
//                Text(title)
//                    .font(.caption)
//                    .fontWeight(.medium)
//                    .foregroundColor(.white.opacity(0.9))
//            }
//            .frame(maxWidth: .infinity)
//            .frame(height: 90)
//            .background(
//                isActive ?
//                color :
//                Color.white.opacity(0.1)
//            )
//            .cornerRadius(12)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
