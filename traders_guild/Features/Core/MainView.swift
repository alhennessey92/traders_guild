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
                            timeframe: chartViewModel.currentTimeframe,
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
            gestureState: chartGestureState,
            rsiPanelHeight: $rsiPanelHeight
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
        
        chartSheetMarkersView(
            chartViewModel: chartViewModel,
            controlViewModel: controlViewModel
        )
        
        
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
//    @StateObject private var chartGestureState = ChartGestureState()
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
//    // MARK: - Indicators
//    // RSI Panel state
//    @State private var rsiPanelHeight: CGFloat = 120
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
//                // MARK: - RSI Panel Overlay
//                // Positioned ABOVE main content, BELOW bottom sheet
//                if chartViewModel.indicatorManager.shouldShowRSIPanel {
//                    VStack {
//                        Spacer()
//                        
//                        RSIPanelView(
//                            indicatorManager: chartViewModel.indicatorManager,
//                            chartData: chartViewModel.dataManager,
//                            gestureState: chartGestureState,  // Same instance!
//                            baseCandleWidth: 12,
//                            candleSpacing: 4,
//                            panelHeight: $rsiPanelHeight
//                        )
//                        
//                        // Bottom padding to clear the minimized bottom sheet
//                        // (.fraction(0.11) ≈ 100pt on most devices)
//                        Color.clear
//                            .frame(height: 100)
//                    }
//                    .ignoresSafeArea(edges: .bottom)
//                }
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
//            chartViewModel: chartViewModel,
//            gestureState: chartGestureState,
//            rsiPanelHeight: $rsiPanelHeight
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
//
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
//
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
//        IndicatorSettingsContent(
//            indicatorManager: chartViewModel.indicatorManager,
//            onRecalculate: {
//                chartViewModel.recalculateIndicators()
//            }
//        )
//    }
//    
//
//    /// Updated markersContent with specific marker type buttons
//    /// Each button triggers placement mode for its specific marker type
//    var markersContent: some View {
//        
//        chartSheetMarkersView(
//            chartViewModel: chartViewModel,
//            controlViewModel: controlViewModel
//        )
//        
//        
//    }
//    
//
//}
//
//
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
//
