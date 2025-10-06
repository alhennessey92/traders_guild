//
//  MainView.swift
//  traders_guild
//ZStack {

// Darker translucent material
//AppColors.gradientBackgroundDark.opacity(0.7)
//    .background(.ultraThinMaterial.opacity(0.9))
//    
//}
//  Created by Al Hennessey on 28/09/2025.
//

// MARK: - Main View UI
import SwiftUI

// MARK: - Constants
/// Layout constants for consistent spacing, sizing, and ratios throughout the app
enum LayoutConstants {
    static let drawerWidthRatio: CGFloat = 0.9              // Drawer width as % of screen width
    static let drawerDismissThreshold: CGFloat = 100        // How far user must drag to dismiss drawer
    static let overlayOpacity: CGFloat = 0.4                // Darkness of overlay behind drawers
    static let cornerRadius: CGFloat = 33                   // Standard corner radius for rounded elements
    static let shadowRadius: CGFloat = 8                    // Shadow blur radius for depth
}

/// Animation constants for consistent motion throughout the app
enum AnimationConstants {
    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)  // Standard spring animation
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)     // Quick snap animation
}

// MARK: - Main View
/// Main trading app view containing chart display and navigation
/// Manages guild-level drawers and chart-specific bottom sheet
struct MainView: View {
    // MARK: - Properties
    /// Environment object for session management across the app
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var currentUser: UserStore
    
    
    // MARK: - Sample data
    
    
    // FRIENDS
    @State private var friends: [GuildUser] = [
        GuildUser(name: "SeanPain", reputation: 50, isOnline: true, isFriend: true, status: "Always online", role: .moderator, newMessage: false),
        GuildUser(name: "OldFriend", reputation: 44, isOnline: false, isFriend: true, status: "Busy IRL", role: .member, newMessage: true)
    ]
    
    // CHATROOM
    @State private var chatrooms: [Chatroom] = [
        Chatroom(name: "General Discussion", memberCount: 42, isActive: true, lastMessage: "Great analysis on BTC!"),
        Chatroom(name: "Trading Talk", memberCount: 28, isActive: true, lastMessage: "AAPL looking bullish"),
        Chatroom(name: "Market Analysis", memberCount: 15, isActive: false, lastMessage: "Chart patterns forming"),
        Chatroom(name: "Off Topic", memberCount: 8, isActive: false, lastMessage: "Anyone watching the game?"),
        Chatroom(name: "Announcements", memberCount: 52, isActive: false, lastMessage: "New guild event tomorrow!"),
    ]
    
    // ONLINE USERS
    @State private var onlineUsers: [GuildUser] = [
        GuildUser(name: "TradeMaster", reputation: 45, isOnline: true, isFriend: true, status: "Trading AAPL", role: .member, newMessage: false),
        GuildUser(name: "ChartWizard", reputation: 38, isOnline: true, isFriend: false, status: "Analyzing markets", role: .admin, newMessage: true),
        GuildUser(name: "BullRunner", reputation: 52, isOnline: true, isFriend: true, status: nil, role: .member, newMessage: false),
        GuildUser(name: "MarketGuru", reputation: 41, isOnline: true, isFriend: false, status: "In a meeting", role: .moderator, newMessage: true),
        GuildUser(name: "StockHawk", reputation: 33, isOnline: true, isFriend: true, status: nil, role: .member, newMessage: true)
    ]
    
    // OFFLINE USERS
    @State private var offlineUsers: [GuildUser] = [
        GuildUser(name: "SleepyTrader", reputation: 29, isOnline: false, isFriend: false, status: nil, role: .member, newMessage: true),
        GuildUser(name: "NightOwl", reputation: 47, isOnline: false, isFriend: true, status: "Away", role: .admin, newMessage: true),
        GuildUser(name: "QuietInvestor", reputation: 36, isOnline: false, isFriend: false, status: nil, role: .member, newMessage: false)
    ]
    
    // ANNOUNCEMENTS
    @State private var announcements: [GuildAnnouncement] = [
        GuildAnnouncement(
            title: "New Trading Tournament Announced",
            content: "We're excited to announce our biggest trading tournament yet! Starting next Monday, all guild members can participate in a week-long competition to see who can achieve the highest returns.\n\nPrizes include:\n• 1st Place: 1000 reputation points + Special badge\n• 2nd Place: 500 reputation points\n• 3rd Place: 250 reputation points\n\nAll trades must be documented with screenshots and verified by moderators. Good luck to everyone participating!",
            author: "Guild Master",
            authorRole: .admin,
            postedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            isImportant: true
        ),
        GuildAnnouncement(
            title: "Market Analysis Session - This Friday",
            content: "Join us this Friday at 7 PM EST for our weekly market analysis session. We'll be reviewing the latest market trends, discussing upcoming earnings reports, and sharing trading strategies.\n\nTopics to cover:\n• SPY technical analysis\n• Earnings plays for next week\n• Crypto market outlook\n• Q&A session\n\nAll guild members are welcome to join and share their insights!",
            author: "ChartMaster",
            authorRole: .moderator,
            postedAt: Date().addingTimeInterval(-7200), // 2 hours ago
            isImportant: false
        ),
        GuildAnnouncement(
            title: "Guild Rules Update",
            content: "Please review the updated guild rules in the #rules channel. Key changes include:\n\n• Updated posting guidelines for trade ideas\n• New reputation system rules\n• Community conduct standards\n\nAll members are expected to follow these guidelines. Violations may result in temporary or permanent removal from the guild.",
            author: "Moderator Team",
            authorRole: .moderator,
            postedAt: Date().addingTimeInterval(-14400), // 4 hours ago
            isImportant: true
        ),
        GuildAnnouncement(
            title: "Weekly Leaderboard Results",
            content: "Congratulations to this week's top performers!\n\n🥇 TradeMaster - 85% win rate\n🥈 ChartWizard - 82% win rate\n🥉 BullRunner - 78% win rate\n\nGreat work everyone! Keep up the excellent trading and analysis. Remember, consistency is key in trading success.",
            author: "System",
            authorRole: .admin,
            postedAt: Date().addingTimeInterval(-21600), // 6 hours ago
            isImportant: false
        )
       
    ]
    
    /// Controls fade-in animation on view appearance
    @State private var fadeIn: Bool = false
    
    // MARK: - Drawer State Management
    /// Controls left drawer visibility
    @State private var showLeftDrawer: Bool = false
    /// Controls right drawer visibility
    @State private var showRightDrawer: Bool = false
    /// Controls overlay visibility (separate from drawers for smooth fade)
    @State private var showOverlay: Bool = false
    
    /// Current drag offset for left drawer (for swipe-to-dismiss)
    @State private var leftDragTranslation: CGFloat = 0
    /// Current drag offset for right drawer (for swipe-to-dismiss)
    @State private var rightDragTranslation: CGFloat = 0
    
    // MARK: - Bottom Sheet State
    /// Controls bottom sheet presentation
    @State private var showBottomSheet: Bool = false
    /// Currently selected detent for the bottom sheet
    @State private var selectedDetent: PresentationDetent = .fraction(0.11)
    
    // MARK: - Sheet Overlay State
    /// Controls overlay when chat sheets are presented
    @State private var showSheetOverlay: Bool = false
    @State private var dismissRightSheetsSignal: Bool = false
    @State private var dismissLeftSheetsSignal: Bool = false
    
    // MARK: - Computed Properties
    /// Get current screen size for responsive layout calculations
    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    /// Calculate drawer width based on screen width and ratio constant
    private var drawerWidth: CGFloat {
        screenSize.width * LayoutConstants.drawerWidthRatio
    }
    
    // MARK: - Body
    var body: some View {
        // ZStack layers all UI elements with proper z-ordering
        ZStack {
            // MARK: - Main Content Layer
            /// Chart content with fade-in animation
            /// Disabled when drawers are open to prevent interaction conflicts
            mainContentStack
                .disabled(showLeftDrawer || showRightDrawer)
            
            // MARK: - Overlay Layer
            /// Semi-transparent overlay that appears behind open drawers
            if showOverlay {
                overlayView
                    .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: showLeftDrawer)
                    .animation(.easeOut(duration: 0.4), value: showRightDrawer)
                    .gesture(
                        // Allow dragging from anywhere on the overlay to dismiss drawers
                        DragGesture()
                            .onChanged { value in
                                // Dismiss any right-drawer sheets when interacting with the overlay
                                dismissRightSheetsSignal = true
                                // Update drag translation based on which drawer is open
                                if showLeftDrawer && value.translation.width < 0 {
                                    leftDragTranslation = value.translation.width
                                } else if showRightDrawer && value.translation.width > 0 {
                                    rightDragTranslation = value.translation.width
                                }
                            }
                            .onEnded { value in
                                // Handle drag end with current position
                                handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
                            }
                    )
            }
            
            // MARK: - Drawer Layers
            /// Left drawer view with fade-in animation
            leftDrawerView
                .opacity(fadeIn ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: fadeIn)
            
            /// Right drawer view with fade-in animation
            rightDrawerView
                .opacity(fadeIn ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: fadeIn)
            
            // MARK: - Sheet Overlay Layer
            /// Overlay that appears when chat sheets are presented over everything
            if showSheetOverlay {
                sheetOverlayView
                    .opacity(showSheetOverlay ? 1 : 0)
                    .animation(.linear(duration: 0.05), value: showSheetOverlay)
            }
        }
        .ignoresSafeArea()
        
        // MARK: - Bottom Sheet
        /// Native bottom sheet using Apple's .sheet modifier
        /// Conditionally hidden when drawers are open to prevent layering conflicts
        .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
            ChartBottomSheet(selectedDetent: $selectedDetent)
                .presentationDetents([.fraction(0.11), .fraction(0.5), .fraction(0.9)],
                                      selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled(true)
                .presentationContentInteraction(.resizes)
                .presentationBackground {
                    ZStack {
                        Color.clear
                            .background(.thinMaterial)
                        AppColors.drawerBackground.opacity(0.4)
                    }
                }
        }
        .onAppear {
            // Start fade-in animation
            withAnimation(.easeIn(duration: 1.5)) {
                fadeIn = true
            }
            
            // Show bottom sheet with slight delay for smooth presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    showBottomSheet = true
                }
            }
        }
        // Haptic feedback for drawer interactions
        .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
        .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
    }
    
    // MARK: - View Components
    
    /// Main content stack containing toolbar and chart
    private var mainContentStack: some View {
        NavigationStack {
            ZStack {
                // Pattern background inside NavigationStack
                StaticBackgroundView()
                
                VStack(spacing: 0) {
                    chartView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .opacity(fadeIn ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: fadeIn)
            }
            .toolbar {
                // MARK: - Guild/App Level Toolbar
                /// These buttons open drawers for guild-wide functionality
                
                // Left Drawer Button (Security/Settings)
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
                            // Reset bottom sheet to first detent when opening drawer
                            selectedDetent = .fraction(0.11)
                            showLeftDrawer.toggle()
                            showRightDrawer = false
                            showOverlay = showLeftDrawer
                        }
                    }
                }
                
                // App Title (Center)
                ToolbarItem(placement: .principal) {
                    Text("TG")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.fadedBackground)
                }
                
                // Right Drawer Button (Friends/Guild Members)
                
                //  MARK: - Need to handle coloring the message icon when there is new messages
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
                            // Reset bottom sheet to first detent when opening drawer
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
    
    /// Semi-transparent overlay that dims content when drawers are open
    private var overlayView: some View {
        Color.black.opacity(LayoutConstants.overlayOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                // Close drawers when overlay is tapped
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    showRightDrawer = false
                    leftDragTranslation = 0
                    rightDragTranslation = 0
                    dismissRightSheetsSignal = true
                }
                // Delay hiding overlay to allow smooth fade-out animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
    }
    
    /// Semi-transparent overlay that appears when chat sheets are presented
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
    
    /// Left drawer view with swipe-to-dismiss functionality
    private var leftDrawerView: some View {
        HStack(spacing: 0) {
            LeftDrawerMainView(announcements: announcements, sheetOverlayVisible: $showSheetOverlay, dismissSheetsSignal: $dismissLeftSheetsSignal) {
                // Closure called when drawer close button is tapped
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    leftDragTranslation = 0
                }
                // Delay hiding overlay for smooth animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
            .frame(width: drawerWidth)
            .frame(maxHeight: .infinity)
            .offset(x: leftDragTranslation)
            .gesture(
                // Drag gesture for swipe-to-dismiss functionality
                DragGesture()
                    .onChanged { value in
                        // Only allow leftward drags (negative translation)
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
    
    /// Right drawer view with swipe-to-dismiss functionality
    private var rightDrawerView: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            RightDrawerMainView(
                onClose: {
                    // Closure called when drawer close button is tapped
                    withAnimation(AnimationConstants.standard) {
                        showRightDrawer = false
                        rightDragTranslation = 0
                    }
                    // Delay hiding overlay for smooth animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOverlay = false
                    }
                },
                chatrooms: chatrooms,
                onlineUsers: onlineUsers,
                offlineUsers: offlineUsers,
                friends: friends,
                sheetOverlayVisible: $showSheetOverlay,
                dismissSheetsSignal: $dismissRightSheetsSignal
            )
            .frame(width: drawerWidth)
            .frame(maxHeight: .infinity)
            .offset(x: rightDragTranslation)
            .gesture(
                // Drag gesture for swipe-to-dismiss functionality
                DragGesture()
                    .onChanged { value in
                        // Only allow rightward drags (positive translation)
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
//    private var rightDrawerView: some View {
//        HStack(spacing: 0) {
//            Spacer(minLength: 0)
//            RightDrawerMainView(friends: friends) {
//                // Closure called when drawer close button is tapped
//                withAnimation(AnimationConstants.standard) {
//                    showRightDrawer = false
//                    rightDragTranslation = 0
//                }
//                // Delay hiding overlay for smooth animation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
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
    
    // MARK: - Helper Functions
    
    /// Handle drawer drag ending - dismiss or snap back based on current position
    /// This function enables "change of mind" gestures where users can drag to dismiss then drag back to cancel
    private func handleDrawerDragEnd(currentPosition: CGFloat) {
        if showLeftDrawer {
            // Check if left drawer is dragged far enough past threshold to dismiss
            if currentPosition < -LayoutConstants.drawerDismissThreshold {
                // Close the drawer smoothly
                showLeftDrawer = false
                leftDragTranslation = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                // Snap back to open position
                withAnimation(AnimationConstants.quick) {
                    leftDragTranslation = 0
                }
            }
        } else if showRightDrawer {
            // Check if right drawer is dragged far enough past threshold to dismiss
            if currentPosition > LayoutConstants.drawerDismissThreshold {
                // Close the drawer smoothly
                showRightDrawer = false
                rightDragTranslation = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                // Snap back to open position
                withAnimation(AnimationConstants.quick) {
                    rightDragTranslation = 0
                }
            }
        }
    }
}

// MARK: - Static Background View
/// Background view that is completely isolated from animations
struct StaticBackgroundView: View {
    @State private var patternOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundMid],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Pattern overlay - fades in smoothly
            PatternOverlay(patternType: .honeycomb, hexSize: 18)
                .opacity(patternOpacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.5)) {
                patternOpacity = 0.025
            }
        }
    }
}

// MARK: - Chart View
/// Placeholder for the main chart component
struct chartView: View {
    var body: some View {
        VStack {
            Text("Chart UI")
                .foregroundColor(.white)
                .bold()
        }
    }
}

// MARK: - Drawer Side
/// Enum to specify which side a drawer appears on (affects corner rounding)
enum DrawerSide { case left, right }

// MARK: - Chart Bottom Sheet
/// Main chart interface hub containing all chart-related functionality
struct ChartBottomSheet: View {
    @State private var selectedView: ChartView = .symbol
    @Binding var selectedDetent: PresentationDetent
    
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
    
    // Computed property to determine if expanded based on detent
    private var isExpanded: Bool {
        selectedDetent != .fraction(0.11)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content Area (only visible when sheet is pulled up)
            if isExpanded {
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedView {
                        case .symbol:
                            chartInfoContent
                        case .chat:
                            chatContent
                        case .indicator:
                            indicatorContent
                        case .markers:
                            toolsContent
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
            
            // Fixed Button Bar at Bottom
            VStack(spacing: 0) {
                // Divider (only show when sheet is pulled up)
                if isExpanded {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 0.5)
                }
                
                // Navigation buttons using custom button components
                HStack(spacing: 4) {
                    // Symbol button (capsule style)
                    RootBottomBarSymbolButton(
                        symbol: "EUR/USD",
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
                        
                        // Markers button on the right
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
    
    // MARK: - Content Views
    
    private var chartInfoContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BTC/USD")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                        Text("$45,234.56")
                            .foregroundColor(.white)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("+$1,234.56")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                        Text("+2.81%")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                HStack {
                    StatPill(title: "24h High", value: "$46,789", color: .green)
                    StatPill(title: "24h Low", value: "$43,456", color: .red)
                    StatPill(title: "Volume", value: "1.2M", color: .blue)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var chatContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                ForEach(1...6, id: \.self) { index in
                    HStack {
                        if index % 3 == 0 {
                            Spacer()
                            Text("Great analysis! BTC looking bullish 🚀")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trader\(index)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("What's everyone's take on this resistance level?")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            Spacer()
                        }
                    }
                }
            }
            HStack {
                TextField("Share your thoughts...", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                Button {
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
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
                    ToolItem(title: "Support Line", icon: "minus", color: .green)
                    ToolItem(title: "Resistance Line", icon: "minus", color: .red)
                    ToolItem(title: "Trend Line", icon: "line.diagonal", color: .blue)
                }
            }
        }
    }
    
    private var toolsContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Chart Markers")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    ToolItem(title: "Support Line", icon: "minus", color: .green)
                    ToolItem(title: "Resistance Line", icon: "minus", color: .red)
                    ToolItem(title: "Trend Line", icon: "line.diagonal", color: .blue)
                }
            }
        }
    }
}

// MARK: - Helper Components

struct StatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ToolItem: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        Button { } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 24)
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



#Preview {
    MainView()
        .environmentObject(UserStore())
        .environmentObject(SessionStore())
}

