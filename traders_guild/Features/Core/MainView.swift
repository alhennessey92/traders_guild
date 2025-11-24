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
            chartViewModel: chartViewModel
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
        case controls = "Controls"
        
        var icon: String {
            switch self {
            case .symbol: return "chart.bar.fill"
            case .chat: return "message.fill"
            case .indicator: return "chart.line.uptrend.xyaxis.circle"
            case .markers: return "mappin.circle.fill"
            case .controls: return "slider.horizontal.3"
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
                        case .controls:
                            chartControlsContent
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
                        
                        // Controls button
                        RootBottomBarIconButton(
                            systemName: "slider.horizontal.3",
                            fontSize: 25,
                            backgroundColor: selectedView == .controls ?
                                AppColors.whiteText :
                                AppColors.whiteText.opacity(0.5),
                            foregroundColor: selectedView == .controls ?
                                AppColors.gradientBackgroundDark :
                                AppColors.gradientBackgroundDark.opacity(0.8)
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedView = .controls
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
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Indicators")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    IndicatorItem(title: "Moving Average", icon: "chart.line.uptrend.xyaxis", color: .blue)
                    IndicatorItem(title: "RSI", icon: "chart.bar", color: .orange)
                    IndicatorItem(title: "MACD", icon: "waveform.path.ecg", color: .green)
                    IndicatorItem(title: "Bollinger Bands", icon: "arrow.up.and.down", color: .purple)
                }
            }
        }
    }
    
    private var markersContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Chart Markers")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Place markers on the chart to share insights with your guild")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                
                VStack(spacing: 8) {
                    MarkerTypeItem(title: "Support Level", icon: "arrow.up.circle", color: .green)
                    MarkerTypeItem(title: "Resistance Level", icon: "arrow.down.circle", color: .red)
                    MarkerTypeItem(title: "Entry Point", icon: "arrow.right.circle", color: .blue)
                    MarkerTypeItem(title: "Exit Point", icon: "xmark.circle", color: .orange)
                }
            }
        }
    }
    
    private var chartControlsContent: some View {
        VStack(spacing: 20) {
            // SECTION: Marker Tools
            VStack(alignment: .leading, spacing: 12) {
                Text("Marker Tools")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 16) {
                    ChartControlButton(
                        title: controlViewModel.isMarkerPlacementMode ? "Cancel" : "Place Marker",
                        icon: controlViewModel.isMarkerPlacementMode ? "xmark.circle" : "mappin.circle",
                        color: controlViewModel.isMarkerPlacementMode ? .red : .green,
                        isActive: controlViewModel.isMarkerPlacementMode
                    ) {
                        controlViewModel.toggleMarkerPlacement()
                    }
                    
                    ChartControlButton(
                        title: "Filter",
                        icon: "line.3.horizontal.decrease.circle",
                        color: .orange
                    ) {
                        print("Filter tapped")
                    }
                }
            }
            
            // SECTION: Navigation
            VStack(alignment: .leading, spacing: 12) {
                Text("Navigation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 16) {
                    ChartControlButton(
                        title: "Start",
                        icon: "arrow.left.to.line",
                        color: .blue
                    ) {
                        controlViewModel.jumpToStart()
                    }
                    
                    ChartControlButton(
                        title: "Latest",
                        icon: "arrow.right.to.line",
                        color: .blue
                    ) {
                        controlViewModel.jumpToLatest()
                    }
                }
                
                HStack(spacing: 16) {
                    ChartControlButton(
                        title: "Reset View",
                        icon: "arrow.counterclockwise",
                        color: .purple
                    ) {
                        controlViewModel.resetChart()
                    }
                    
                    ChartControlButton(
                        title: "Auto-Scroll",
                        icon: "arrow.right.circle",
                        color: .indigo,
                        isActive: controlViewModel.isAutoScrolling
                    ) {
                        controlViewModel.toggleAutoScroll()
                    }
                }
            }
            
            // SECTION: Zoom Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Zoom & Scale")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Horizontal Zoom")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("Use pinch gesture")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Vertical Scale")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("Drag Y-axis area")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Helper Components

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
////ZStack {
//
//// Darker translucent material
////AppColors.gradientBackgroundDark.opacity(0.7)
////    .background(.ultraThinMaterial.opacity(0.9))
////
////}
////  Created by Al Hennessey on 28/09/2025.
////
//
//// MARK: - Main View UI
//import SwiftUI
//import SwiftTradingView
//
//// MARK: - Constants
///// Layout constants for consistent spacing, sizing, and ratios throughout the app

////
////  MainView.swift
////  traders_guild
////ZStack {
//
//// Darker translucent material
////AppColors.gradientBackgroundDark.opacity(0.7)
////    .background(.ultraThinMaterial.opacity(0.9))
////
////}
////  Created by Al Hennessey on 28/09/2025.
////
//
//// MARK: - Main View UI
//import SwiftUI
//import SwiftTradingView
//
//// MARK: - Constants
///// Layout constants for consistent spacing, sizing, and ratios throughout the app
//enum LayoutConstants {
//    static let drawerWidthRatio: CGFloat = 0.9              // Drawer width as % of screen width
//    static let drawerDismissThreshold: CGFloat = 100        // How far user must drag to dismiss drawer
//    static let overlayOpacity: CGFloat = 0.4                // Darkness of overlay behind drawers
//    static let cornerRadius: CGFloat = 33                   // Standard corner radius for rounded elements
//    static let shadowRadius: CGFloat = 8                    // Shadow blur radius for depth
//}
//
///// Animation constants for consistent motion throughout the app
//enum AnimationConstants {
//    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)  // Standard spring animation
//    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)     // Quick snap animation
//}
//
//// MARK: - Main View
///// Main trading app view containing chart display and navigation
///// Manages guild-level drawers and chart-specific bottom sheet
//struct MainView: View {
//    // MARK: - Properties
//    /// Environment object for session management across the app
//    @EnvironmentObject var appState: AppState
//    @EnvironmentObject var messagingManager: MessagingManager // Get from app-level environment
//    @StateObject private var leftDrawerViewModel = LeftDrawerViewModel()
//    @StateObject private var rightDrawerViewModel = RightDrawerViewModel()
//    @StateObject private var notificationNavigationManager = NotificationNavigationManager()
//    
//
//    
//
//    
//    // MARK: - Chart Control State
//    @StateObject private var chartControlVM = ChartControlViewModel()
//    
//    
//    /// Controls fade-in animation on view appearance
//    @State private var fadeIn: Bool = false
//    
//    // MARK: - Drawer State Management
//    /// Controls left drawer visibility
//    @State private var showLeftDrawer: Bool = false
//    /// Controls right drawer visibility
//    @State private var showRightDrawer: Bool = false
//    /// Controls overlay visibility (separate from drawers for smooth fade)
//    @State private var showOverlay: Bool = false
//    
//    /// Current drag offset for left drawer (for swipe-to-dismiss)
//    @State private var leftDragTranslation: CGFloat = 0
//    /// Current drag offset for right drawer (for swipe-to-dismiss)
//    @State private var rightDragTranslation: CGFloat = 0
//    
//    // MARK: - Bottom Sheet State
//    /// Controls bottom sheet presentation
//    @State private var showBottomSheet: Bool = false
//    /// Currently selected detent for the bottom sheet
//    @State private var selectedDetent: PresentationDetent = .fraction(0.11)
//    
//    // MARK: - Sheet Overlay State
//    /// Controls overlay when chat sheets are presented
//    @State private var showSheetOverlay: Bool = false
//    @State private var dismissRightSheetsSignal: Bool = false
//    @State private var dismissLeftSheetsSignal: Bool = false
//    
//    // MARK: - Computed Properties
//    /// Get current screen size for responsive layout calculations
//    private var screenSize: CGSize {
//        UIScreen.main.bounds.size
//    }
//    
//    /// Calculate drawer width based on screen width and ratio constant
//    private var drawerWidth: CGFloat {
//        screenSize.width * LayoutConstants.drawerWidthRatio
//    }
//    
//
//    // MARK: - Body
//    var body: some View {
//        if let user = appState.currentUser,
//           let guild = appState.currentGuild {
//        // ZStack layers all UI elements with proper z-ordering
//            ZStack {
//                // MARK: - Main Content Layer
//                /// Chart content with fade-in animation
//                /// Disabled when drawers are open to prevent interaction conflicts
//                mainContentStack
//                    .disabled(showLeftDrawer || showRightDrawer)
//                
//                // MARK: - Overlay Layer
//                /// Semi-transparent overlay that appears behind open drawers
//                if showOverlay {
//                    overlayView
//                        .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
//                        .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
//                        .animation(.easeOut(duration: 0.4), value: showRightDrawer)
//                        .gesture(
//                            // Allow dragging from anywhere on the overlay to dismiss drawers
//                            DragGesture()
//                                .onChanged { value in
//                                    // Dismiss any right-drawer sheets when interacting with the overlay
//                                    dismissRightSheetsSignal = true
//                                    // Update drag translation based on which drawer is open
//                                    if showLeftDrawer && value.translation.width < 0 {
//                                        leftDragTranslation = value.translation.width
//                                    } else if showRightDrawer && value.translation.width > 0 {
//                                        rightDragTranslation = value.translation.width
//                                    }
//                                }
//                                .onEnded { value in
//                                    // Handle drag end with current position
//                                    handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
//                                }
//                        )
//                }
//                
//                // MARK: - Drawer Layers
//                /// Left drawer view with fade-in animation
//                leftDrawerView
//                    .opacity(fadeIn ? 1 : 0)
//                    .animation(.easeIn(duration: 1.5), value: fadeIn)
//                
//                /// Right drawer view with fade-in animation
//                rightDrawerView
//                    .opacity(fadeIn ? 1 : 0)
//                    .animation(.easeIn(duration: 1.5), value: fadeIn)
//                
//                // MARK: - Sheet Overlay Layer
//                /// Overlay that appears when chat sheets are presented over everything
//                if showSheetOverlay {
//                    sheetOverlayView
//                        .opacity(showSheetOverlay ? 1 : 0)
//                        .animation(.linear(duration: 0.05), value: showSheetOverlay)
//                }
//            }
//            .ignoresSafeArea()
//            .globalMessaging() // Apply global messaging to MainView only
//            
//            // MARK: - Bottom Sheet
//            /// Native bottom sheet using Apple's .sheet modifier
//            /// Conditionally hidden when drawers are open to prevent layering conflicts
//            .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
//                ChartBottomSheet(controlViewModel: chartControlVM, selectedDetent: $selectedDetent)
//                    
//                    .presentationDetents([.fraction(0.11), .fraction(0.5), .fraction(0.9)],
//                                          selection: $selectedDetent)
//                    .presentationDragIndicator(.visible)
//                    .presentationBackgroundInteraction(.enabled)
//                    .interactiveDismissDisabled(true)
//                    .presentationContentInteraction(.resizes)
//                    .presentationBackground {
//                        ZStack {
//                            Color.clear
//                                .background(.ultraThinMaterial)
//                            AppColors.drawerBackground.opacity(0.4)
//                        }
//                    }
//            }
//            .onAppear {
//                // Start fade-in animation
//                withAnimation(.easeIn(duration: 1.5)) {
//                    fadeIn = true
//                }
//                
//                // Show bottom sheet with slight delay for smooth presentation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
//                        showBottomSheet = true
//                    }
//                }
//            }
//            // Haptic feedback for drawer interactions
//            .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
//            .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
//            
//            .environmentObject(leftDrawerViewModel)  // ✅ Pass to child views
//            .environmentObject(rightDrawerViewModel)
//            .environmentObject(notificationNavigationManager)
//            .task {
//                // ✅ Preload drawer data when MainView appears
//                await leftDrawerViewModel.preloadData(for: guild.id, appState: appState)
//                await rightDrawerViewModel.preloadData(for: guild.id, appState: appState)
//                
//                notificationNavigationManager.configure(
//                    appState: appState,
//                    messagingManager: messagingManager,
//                    rightDrawerViewModel: rightDrawerViewModel
//                )
//            }
//            .onChange(of: appState.currentGuild?.id) { _, newGuildId in
//                // ✅ Reload data when guild changes
//                if let guildId = newGuildId {
//                    Task {
//                        leftDrawerViewModel.clearCache()  // Clear old guild data
//                        rightDrawerViewModel.clearCache()
//                        await leftDrawerViewModel.preloadData(for: guildId, appState: appState)
//                        await rightDrawerViewModel.preloadData(for: guildId, appState: appState)
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
//    /// Main content stack containing toolbar and chart
//    private var mainContentStack: some View {
//        NavigationStack {
//            ZStack {
//                // Pattern background inside NavigationStack
//                StaticBackgroundView()
//                
//                VStack(spacing: 0) {
//                    chartView(controlViewModel: chartControlVM)
//                    
//                }
//                .opacity(fadeIn ? 1 : 0)
//                .animation(.easeIn(duration: 1.5), value: fadeIn)
//            }
//            .toolbar {
//                // MARK: - Guild/App Level Toolbar
//                /// These buttons open drawers for guild-wide functionality
//                
//                // Left Drawer Button (Security/Settings)
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
//                            // Reset bottom sheet to first detent when opening drawer
//                            selectedDetent = .fraction(0.11)
//                            showLeftDrawer.toggle()
//                            showRightDrawer = false
//                            showOverlay = showLeftDrawer
//                        }
//                    }
//                }
//                
//                // App Title (Center)
//                ToolbarItem(placement: .principal) {
//                    Text("TG")
//                        .font(.largeTitle)
//                        .fontWeight(.heavy)
//                        .foregroundColor(AppColors.fadedBackground)
//                }
//                
//                // Right Drawer Button (Friends/Guild Members)
//                
//                //  MARK: - Need to handle coloring the message icon when there is new messages
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
//                            // Reset bottom sheet to first detent when opening drawer
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
////    private var chartViewContent: some View {
////        CleanCandlestickChartView(
////            candles: chartController.allCandles,
////            config: chartController.configuration
////        )
////        .frame(maxWidth: .infinity, maxHeight: .infinity)
////        .onAppear {
////            chartController.start()
////        }
////        .onDisappear {
////            chartController.stop()
////        }
////    }
//    
//    /// Semi-transparent overlay that dims content when drawers are open
//    private var overlayView: some View {
//        Color.black.opacity(LayoutConstants.overlayOpacity)
//            .ignoresSafeArea()
//            .onTapGesture {
//                // Close drawers when overlay is tapped
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    showRightDrawer = false
//                    leftDragTranslation = 0
//                    rightDragTranslation = 0
//                    dismissRightSheetsSignal = true
//                }
//                // Delay hiding overlay to allow smooth fade-out animation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
//    }
//    
//    /// Semi-transparent overlay that appears when chat sheets are presented
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
//    /// Left drawer view with swipe-to-dismiss functionality
//    private var leftDrawerView: some View {
//        HStack(spacing: 0) {
//            LeftDrawerMainView(sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal) {
//                // Closure called when drawer close button is tapped
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    leftDragTranslation = 0
//                }
//                // Delay hiding overlay for smooth animation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: leftDragTranslation)
//            .gesture(
//                // Drag gesture for swipe-to-dismiss functionality
//                DragGesture()
//                    .onChanged { value in
//                        // Only allow leftward drags (negative translation)
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
//    /// Right drawer view with swipe-to-dismiss functionality
//    private var rightDrawerView: some View {
//        HStack(spacing: 0) {
//            Spacer(minLength: 0)
//            RightDrawerMainView(
//                onClose: {
//                    // Closure called when drawer close button is tapped
//                    withAnimation(AnimationConstants.standard) {
//                        showRightDrawer = false
//                        rightDragTranslation = 0
//                    }
//                    // Delay hiding overlay for smooth animation
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                        showOverlay = false
//                    }
//                }
//                
//                //sheetOverlayVisible: $showSheetOverlay,
//                //dismissSheetsSignal: $dismissRightSheetsSignal
//            )
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: rightDragTranslation)
//            .gesture(
//                // Drag gesture for swipe-to-dismiss functionality
//                DragGesture()
//                    .onChanged { value in
//                        // Only allow rightward drags (positive translation)
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
//    
//    // MARK: - Helper Functions
//    
//    /// Handle drawer drag ending - dismiss or snap back based on current position
//    /// This function enables "change of mind" gestures where users can drag to dismiss then drag back to cancel
//    private func handleDrawerDragEnd(currentPosition: CGFloat) {
//        if showLeftDrawer {
//            // Check if left drawer is dragged far enough past threshold to dismiss
//            if currentPosition < -LayoutConstants.drawerDismissThreshold {
//                // Close the drawer smoothly
//                showLeftDrawer = false
//                leftDragTranslation = 0
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            } else {
//                // Snap back to open position
//                withAnimation(AnimationConstants.quick) {
//                    leftDragTranslation = 0
//                }
//            }
//        } else if showRightDrawer {
//            // Check if right drawer is dragged far enough past threshold to dismiss
//            if currentPosition > LayoutConstants.drawerDismissThreshold {
//                // Close the drawer smoothly
//                showRightDrawer = false
//                rightDragTranslation = 0
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            } else {
//                // Snap back to open position
//                withAnimation(AnimationConstants.quick) {
//                    rightDragTranslation = 0
//                }
//            }
//        }
//    }
//}
//
//
//
//
//struct chartView: View {
//    let controlViewModel: ChartControlViewModel
//
//    var body: some View {
//        TradingChartView(
//            
//            controlViewModel: controlViewModel // Pass the ViewModel
//        )
//            .ignoresSafeArea() // Full screen chart
//        
//    }
//}
//
//
//
//
//
//// MARK: - Drawer Side
///// Enum to specify which side a drawer appears on (affects corner rounding)
//enum DrawerSide { case left, right }
//
//// MARK: - Chart Bottom Sheet
///// Main chart interface hub containing all chart-related functionality
//struct ChartBottomSheet: View {
//    @State private var selectedView: ChartView = .symbol
//    @ObservedObject var controlViewModel: ChartControlViewModel
//    @Binding var selectedDetent: PresentationDetent
//    
//    
//    enum ChartView: String, CaseIterable {
//        case symbol = "Symbol"
//        case chat = "Chat"
//        case indicator = "Indicator"
//        case markers = "Markers"
//        case controls = "Controls"
//        
//        var icon: String {
//            switch self {
//            case .symbol: return "chart.bar.fill"
//            case .chat: return "message.fill"
//            case .indicator: return "chart.line.uptrend.xyaxis.circle"
//            case .markers: return "mappin.circle.fill"
//            case .controls: return "slider.horizontal.3"
//            }
//        }
//    }
//    
//    // Computed property to determine if expanded based on detent
//    private var isExpanded: Bool {
//        selectedDetent != .fraction(0.11)
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Content Area (only visible when sheet is pulled up)
//            if isExpanded {
//                ScrollView {
//                    VStack(spacing: 16) {
//                        switch selectedView {
//                        case .symbol:
//                            chartInfoContent
//                        case .chat:
//                            chatContent
//                        case .indicator:
//                            indicatorContent
//                        case .markers:
//                            toolsContent
//                        case .controls:  // NEW
//                            chartControlsContent
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
//            // Fixed Button Bar at Bottom
//            VStack(spacing: 0) {
//                // Divider (only show when sheet is pulled up)
//                if isExpanded {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(height: 0.5)
//                }
//                
//                // Navigation buttons using custom button components
//                HStack(spacing: 4) {
//                    // Symbol button (capsule style)
//                    RootBottomBarSymbolButton(
//                        symbol: "EUR/USD",
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
//                        // Markers button on the right
//                        RootBottomBarIconButton(
//                            systemName: "target",
//                            fontSize: 25,
//                            backgroundColor: selectedView == .markers ?
//                                AppColors.whiteText :
//                                AppColors.whiteText.opacity(0.5),
//                            foregroundColor: selectedView == .markers ?
//                            AppColors.gradientBackgroundDark :
//                                AppColors.gradientBackgroundDark.opacity(0.8)
//                        ) {
//                            withAnimation(.easeInOut(duration: 0.25)) {
//                                selectedView = .markers
//                            }
//                        }
//                        
//                        // Markers button on the right
//                        RootBottomBarIconButton(
//                            systemName: "target",
//                            fontSize: 25,
//                            backgroundColor: selectedView == .markers ?
//                                AppColors.whiteText :
//                                AppColors.whiteText.opacity(0.5),
//                            foregroundColor: selectedView == .markers ?
//                            AppColors.gradientBackgroundDark :
//                                AppColors.gradientBackgroundDark.opacity(0.8)
//                        ) {
//                            withAnimation(.easeInOut(duration: 0.25)) {
//                                selectedView = .controls
//                            }
//                        }
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
//
//    private var chartInfoContent: some View {
//        VStack(spacing: 16) {
//            VStack(spacing: 12) {
//                HStack {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("BTC/USD")
//                            .foregroundColor(.white.opacity(0.8))
//                            .font(.caption)
//                        Text("$45,234.56")
//                            .foregroundColor(.white)
//                            .font(.title2)
//                            .fontWeight(.bold)
//                    }
//                    Spacer()
//                    VStack(alignment: .trailing, spacing: 4) {
//                        Text("+$1,234.56")
//                            .foregroundColor(.green)
//                            .fontWeight(.semibold)
//                        Text("+2.81%")
//                            .foregroundColor(.green)
//                            .font(.caption)
//                    }
//                }
//                HStack {
//                    StatPill(title: "24h High", value: "$46,789", color: .green)
//                    StatPill(title: "24h Low", value: "$43,456", color: .red)
//                    StatPill(title: "Volume", value: "1.2M", color: .blue)
//                }
//            }
//            .padding()
//            .background(Color.white.opacity(0.1))
//            .cornerRadius(12)
//        }
//    }
//    
//    private var chatContent: some View {
//        VStack(spacing: 16) {
//            VStack(spacing: 12) {
//                ForEach(1...6, id: \.self) { index in
//                    HStack {
//                        if index % 3 == 0 {
//                            Spacer()
//                            Text("Great analysis! BTC looking bullish 🚀")
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 8)
//                                .background(Color.blue)
//                                .foregroundColor(.white)
//                                .cornerRadius(16)
//                        } else {
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text("Trader\(index)")
//                                    .font(.caption)
//                                    .foregroundColor(.gray)
//                                Text("What's everyone's take on this resistance level?")
//                                    .padding(.horizontal, 12)
//                                    .padding(.vertical, 8)
//                                    .background(Color.white.opacity(0.1))
//                                    .foregroundColor(.white)
//                                    .cornerRadius(16)
//                            }
//                            Spacer()
//                        }
//                    }
//                }
//            }
//            HStack {
//                TextField("Share your thoughts...", text: .constant(""))
//                    .textFieldStyle(.roundedBorder)
//                Button {
//                } label: {
//                    Image(systemName: "paperplane.fill")
//                        .foregroundColor(.blue)
//                        .font(.title2)
//                }
//            }
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
//                    ToolItem(title: "Support Line", icon: "minus", color: .green)
//                    ToolItem(title: "Resistance Line", icon: "minus", color: .red)
//                    ToolItem(title: "Trend Line", icon: "line.diagonal", color: .blue)
//                }
//            }
//        }
//    }
//    
//    private var toolsContent: some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Chart Markers")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
//                VStack(spacing: 8) {
//                    ToolItem(title: "Support Line", icon: "minus", color: .green)
//                    ToolItem(title: "Resistance Line", icon: "minus", color: .red)
//                    ToolItem(title: "Trend Line", icon: "line.diagonal", color: .blue)
//                }
//            }
//        }
//    }
//    
//    // MARK: - Chart Controls Content
//
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
//                    // Marker placement button
//                    ChartControlButton(
//                        title: controlViewModel.isMarkerPlacementMode ? "Cancel Marker" : "Place Marker",
//                        icon: controlViewModel.isMarkerPlacementMode ? "mappin.circle.fill" : "mappin.circle",
//                        color: controlViewModel.isMarkerPlacementMode ? .blue : .green,
//                        isActive: controlViewModel.isMarkerPlacementMode
//                    ) {
//                        controlViewModel.toggleMarkerPlacement()
//                    }
//                    
//                    // Filter markers button (placeholder for future feature)
//                    ChartControlButton(
//                        title: "Filter",
//                        icon: "line.3.horizontal.decrease.circle",
//                        color: .orange
//                    ) {
//                        // TODO: Implement marker filtering
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
//                    // Jump to start button
//                    ChartControlButton(
//                        title: "Start",
//                        icon: "arrow.left.to.line",
//                        color: .blue
//                    ) {
//                        controlViewModel.jumpToStart()
//                    }
//                    
//                    // Jump to latest button
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
//                    // Reset view button
//                    ChartControlButton(
//                        title: "Reset View",
//                        icon: "arrow.counterclockwise",
//                        color: .purple
//                    ) {
//                        controlViewModel.resetChart()
//                    }
//                    
//                    // Auto-scroll toggle button
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
//            // SECTION: Zoom & Scale
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Zoom & Scale")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
//                VStack(spacing: 12) {
//                    // Horizontal zoom info
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
//                    // Vertical scale info
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
//}
//
//
//// MARK: - Chart Control Button
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
//// MARK: - Helper Components
//
//struct StatPill: View {
//    let title: String
//    let value: String
//    let color: Color
//    
//    var body: some View {
//        VStack(spacing: 2) {
//            Text(title)
//                .font(.caption2)
//                .foregroundColor(.white.opacity(0.8))
//            Text(value)
//                .font(.caption)
//                .fontWeight(.medium)
//                .foregroundColor(color)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 8)
//        .background(Color.white.opacity(0.05))
//        .cornerRadius(8)
//    }
//}
//
//struct ToolItem: View {
//    let title: String
//    let icon: String
//    let color: Color
//    
//    var body: some View {
//        Button { } label: {
//            HStack {
//                Image(systemName: icon)
//                    .foregroundColor(color)
//                    .font(.title3)
//                    .frame(width: 24)
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
//#Preview {
//    MainView()
//        .environmentObject(AppState())
//        .environmentObject(MessagingManager())
//}
//
//
