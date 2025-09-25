//
//  RootView.swift
//  traders_guild
//
//  Created by Al Hennessey on 19/09/2025.
//


// NOTES !!!!!!!!!!!!!!!!
// I have commented the fade animation for dev
// v43 claude code is best so far

import SwiftUI

// MARK: - Constants
// Layout constants for consistent spacing, sizing, and ratios throughout the app
enum LayoutConstants {
    static let drawerWidthRatio: CGFloat = 0.8              // Drawer width as % of screen width (80%)
    static let dragThreshold: CGFloat = 50                   // General drag threshold for gestures
    static let drawerDismissThreshold: CGFloat = 100         // How far user must drag to dismiss drawer
    static let overlayOpacity: CGFloat = 0.4                 // Darkness of overlay behind drawers
    static let topBarOpacity: CGFloat = 0.8                  // Opacity of top navigation bar
    static let cornerRadius: CGFloat = 20                    // Standard corner radius for rounded elements
    static let shadowRadius: CGFloat = 8                     // Shadow blur radius for depth
}

// Animation constants for consistent motion throughout the app
enum AnimationConstants {
    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)  // Standard spring animation
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)     // Quick snap animation
}

// MARK: - RootView
// Main container view that manages the entire app layout including drawers and charts
struct RootView: View {
    // Environment object for session management across the app
    @EnvironmentObject var session: SessionStore
    
    // MARK: - State Properties
    // Drawer state management
    @State private var showLeftDrawer: Bool = false          // Controls left drawer visibility
    @State private var showRightDrawer: Bool = false         // Controls right drawer visibility
    @State private var showOverlay: Bool = false             // Controls overlay visibility (separate from drawers for smooth fade)
    
    // Drag translation states - track how far drawers are dragged during gestures
    @State private var leftDragTranslation: CGFloat = 0      // Current drag offset for left drawer
    @State private var rightDragTranslation: CGFloat = 0     // Current drag offset for right drawer
    
    // Chart and content state
    @State private var selectedSymbol: String = "AAPL"       // Currently selected stock symbol
    
    // Bottom sheet state management - using native .sheet()
    @State private var showBottomSheet: Bool = false         // Controls native bottom sheet visibility (starts hidden for entrance animation)
    @State private var hasAppeared: Bool = false             // Track if view has appeared for entrance animation
    @State private var fadeIn: Bool = false                  // Controls elegant fade-in animation on first app launch
    @State private var bottomSheetBounce: Bool = false       // Controls bottom sheet bounce animation when returning from background
    
    // Stock symbols array - could be moved to SessionStore for dynamic data
    let symbols: [String] = ["AAPL", "TSLA", "GOOG", "MSFT", "AMZN", "NVDA", "META", "NFLX"]
    
    // MARK: - Computed Properties
    // Get current screen size for responsive layout calculations
    private var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    // Calculate drawer width based on screen width and ratio constant
    private var drawerWidth: CGFloat {
        screenSize.width * LayoutConstants.drawerWidthRatio
    }
    
    // MARK: - Body
    var body: some View {
        // ZStack layers all UI elements with proper z-ordering
        ZStack {
            // MARK: - Background Layer
            backgroundGradient
            
            // MARK: - Main Content Layer
            // Disable interaction when drawers are open to prevent conflicts
            mainContentStack
                .disabled(showLeftDrawer || showRightDrawer)
            
            // MARK: - Overlay Layer
            // Semi-transparent overlay that appears behind open drawers
            if showOverlay {
                overlayView
                    .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)           // Animate opacity based on drawer state
                    .animation(.easeOut(duration: 0.4), value: showLeftDrawer)    // Smooth fade animation for left drawer
                    .animation(.easeOut(duration: 0.4), value: showRightDrawer)   // Smooth fade animation for right drawer
                    .gesture(
                        // Allow dragging from anywhere on the overlay to dismiss drawers
                        DragGesture()
                            .onChanged { value in
                                // Update drag translation based on which drawer is open and drag direction
                                if showLeftDrawer && value.translation.width < 0 {
                                    leftDragTranslation = value.translation.width
                                } else if showRightDrawer && value.translation.width > 0 {
                                    rightDragTranslation = value.translation.width
                                }
                            }
                            .onEnded { value in
                                // Handle drag end with current position to allow "change of mind" gestures
                                handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
                            }
                    )
            }
            
            // MARK: - Drawer Layers
            leftDrawerView       // Left side navigation drawer
            rightDrawerView      // Right side options drawer
        }
        .opacity(fadeIn ? 1 : 0)    // Elegant fade-in animation from invisible to visible on first launch
        .animation(.easeIn(duration: 1.5), value: fadeIn)  // 1.5 second smooth fade for premium feel
        // Native bottom sheet using Apple's .sheet modifier
        // Conditionally hidden when drawers are open to prevent layering conflicts
        .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
            BottomSheetView()
                .presentationDetents([.fraction(0.1), .fraction(0.4), .fraction(0.7)])  // Three snap positions: 10%, 40%, 70%
                .presentationDragIndicator(.visible)                                     // Show system drag handle
                .presentationBackgroundInteraction(.enabled)                            // Allow interaction with background content
                .interactiveDismissDisabled(true)                                       // Prevent accidental dismissal by dragging down
                .scaleEffect(bottomSheetBounce ? 1.12 : 1.0)                            // 12% scale-up bounce for background returns
                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: bottomSheetBounce) // Bouncy spring animation
        }
        // Layered entrance animation sequence on app launch
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                
                // Start elegant fade-in animation immediately for premium first impression
                withAnimation(.easeIn(duration: 1.5)) {
                    fadeIn = true
                }
                
                // Delay bottom sheet entrance for layered effect (content fades in, then sheet slides up)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        showBottomSheet = true
                    }
                }
            }
        }
        // Subtle "welcome back" bounce animation when returning from background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Focused animation - only bottom sheet bounces, main content stays stable
            bottomSheetBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                bottomSheetBounce = false  // Return to normal size after 0.4 seconds
            }
        }
        // Haptic feedback for user interactions
        .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedSymbol)  // Soft feedback when symbol changes
        .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)      // Light feedback when left drawer toggles
        .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)     // Light feedback when right drawer toggles
    }
    
    // MARK: - View Components
    
    // Background gradient that covers the entire screen
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()  // Extend gradient behind safe areas
    }
    
    // Main content stack containing navigation bar, ticker, and chart
    private var mainContentStack: some View {
        // Main content in vertical stack
        VStack(spacing: 0) {
            topBarView                                                          // Navigation bar with menu buttons
            TickerView(symbols: symbols, selectedSymbol: $selectedSymbol)       // Horizontal scrolling stock ticker
            ChartView(symbol: selectedSymbol)                                   // Main chart display
                .frame(maxWidth: .infinity, maxHeight: .infinity)               // Fill remaining space
        }
    }
    
    // Top navigation bar with menu buttons
    private var topBarView: some View {
        HStack {
            menuButton          // Left menu button (hamburger)
            Spacer()           // Push buttons to edges
            rightMenuButton    // Right menu button (ellipsis)
        }
        .background(Color.black.opacity(LayoutConstants.topBarOpacity))  // Semi-transparent dark background
    }
    
    // Left menu button that toggles the left drawer
    private var menuButton: some View {
        Button(action: {
            withAnimation(AnimationConstants.standard) {
                showLeftDrawer.toggle()     // Toggle left drawer state
                showRightDrawer = false     // Close right drawer if open
                showOverlay = showLeftDrawer // Update overlay state to match drawer
            }
        }) {
            Image(systemName: "line.horizontal.3")  // Hamburger menu icon
                .font(.title2)
                .foregroundColor(.white)
                .padding()
        }
    }
    
    // Right menu button that toggles the right drawer
    private var rightMenuButton: some View {
        Button(action: {
            withAnimation(AnimationConstants.standard) {
                showRightDrawer.toggle()     // Toggle right drawer state
                showLeftDrawer = false       // Close left drawer if open
                showOverlay = showRightDrawer // Update overlay state to match drawer
            }
        }) {
            Image(systemName: "ellipsis.circle")  // Options menu icon
                .font(.title2)
                .foregroundColor(.white)
                .padding()
        }
    }
    
    // Semi-transparent overlay that dims content when drawers are open
    private var overlayView: some View {
        Color.black.opacity(LayoutConstants.overlayOpacity)
            .ignoresSafeArea()  // Cover entire screen including safe areas
            .onTapGesture {
                // Close drawers when overlay is tapped
                withAnimation(AnimationConstants.standard) {
                    showLeftDrawer = false
                    showRightDrawer = false
                    leftDragTranslation = 0      // Reset drag states
                    rightDragTranslation = 0
                }
                // Delay hiding overlay to allow smooth fade-out animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
    }
    
    // Left drawer view with swipe-to-dismiss functionality
    private var leftDrawerView: some View {
        HStack(spacing: 0) {  // No spacing to ensure drawer touches screen edge
            DrawerView(side: .left) {
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
            .frame(width: drawerWidth)      // Set fixed width
            .frame(maxHeight: .infinity)    // Extend to full height
            .offset(x: leftDragTranslation) // Apply drag translation for following gesture
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
                        // Handle drag end with current position for "change of mind" support
                        handleDrawerDragEnd(currentPosition: leftDragTranslation)
                    }
            )
            Spacer(minLength: 0)  // Fill remaining space with minimum length 0
        }
        .frame(maxHeight: .infinity)  // Full height container
        .offset(x: showLeftDrawer ? 0 : -drawerWidth)  // Slide drawer in/out based on state
        .animation(AnimationConstants.standard, value: showLeftDrawer)  // Animate position changes
    }
    
    // Right drawer view with swipe-to-dismiss functionality
    private var rightDrawerView: some View {
        HStack(spacing: 0) {  // No spacing to ensure drawer touches screen edge
            Spacer(minLength: 0)  // Fill space before drawer
            DrawerView(side: .right) {
                // Closure called when drawer close button is tapped
                withAnimation(AnimationConstants.standard) {
                    showRightDrawer = false
                    rightDragTranslation = 0
                }
                // Delay hiding overlay for smooth animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
            .frame(width: drawerWidth)       // Set fixed width
            .frame(maxHeight: .infinity)     // Extend to full height
            .offset(x: rightDragTranslation) // Apply drag translation for following gesture
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
                        // Handle drag end with current position for "change of mind" support
                        handleDrawerDragEnd(currentPosition: rightDragTranslation)
                    }
            )
        }
        .frame(maxHeight: .infinity)  // Full height container
        .offset(x: showRightDrawer ? 0 : drawerWidth)  // Slide drawer in/out based on state
        .animation(AnimationConstants.standard, value: showRightDrawer)  // Animate position changes
    }
    
    // MARK: - Helper Functions
    
    // Handle drawer drag ending - dismiss or snap back based on current position
    // This function enables "change of mind" gestures where users can drag to dismiss then drag back to cancel
    private func handleDrawerDragEnd(currentPosition: CGFloat) {
        if showLeftDrawer {
            // Check if left drawer is dragged far enough past threshold to dismiss
            if currentPosition < -LayoutConstants.drawerDismissThreshold {
                // Close the drawer smoothly - user dragged far enough
                showLeftDrawer = false
                leftDragTranslation = 0
                // Delay hiding overlay for smooth 0.4s fade-out animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                // Snap back to open position - user didn't drag far enough or changed their mind
                withAnimation(AnimationConstants.quick) {
                    leftDragTranslation = 0
                }
            }
        } else if showRightDrawer {
            // Check if right drawer is dragged far enough past threshold to dismiss
            if currentPosition > LayoutConstants.drawerDismissThreshold {
                // Close the drawer smoothly - user dragged far enough
                showRightDrawer = false
                rightDragTranslation = 0
                // Delay hiding overlay for smooth 0.4s fade-out animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            } else {
                // Snap back to open position - user didn't drag far enough or changed their mind
                withAnimation(AnimationConstants.quick) {
                    rightDragTranslation = 0
                }
            }
        }
    }
}

// MARK: - Drawer View
// Enum to specify which side a drawer appears on (affects corner rounding)
enum DrawerSide { case left, right }

// Individual drawer view with content and close functionality
struct DrawerView: View {
    let side: DrawerSide        // Which side this drawer appears on
    let onClose: () -> Void     // Closure called when drawer should close
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with title and close button
            HStack {
                Text(side == .left ? "Left Drawer" : "Right Drawer")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()  // Push close button to the right
                Button(action: {
                    withAnimation(AnimationConstants.standard) { onClose() }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding()                    // Standard padding around header content
            .padding(.bottom, 8)          // Extra bottom padding for visual separation
            .padding(.top, 60)            // Extra top padding to clear status bar/notch area
            
            Spacer()  // Fill remaining space (where drawer content would go)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        .background(Color(.systemBackground))              // System background color (adapts to light/dark mode)
        .clipShape(
            // Custom corner rounding - only round corners opposite to the edge drawer slides from
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: side == .left ? 0 : LayoutConstants.cornerRadius,      // Left drawer: square top-left corner
                    bottomLeading: side == .left ? 0 : LayoutConstants.cornerRadius,   // Left drawer: square bottom-left corner
                    bottomTrailing: side == .left ? LayoutConstants.cornerRadius : 0,  // Left drawer: round bottom-right corner
                    topTrailing: side == .left ? LayoutConstants.cornerRadius : 0      // Left drawer: round top-right corner
                )
            )
        )
        .shadow(radius: LayoutConstants.shadowRadius)  // Drop shadow for depth
        .ignoresSafeArea()                            // Extend to screen edges including safe areas
    }
}

// MARK: - Ticker View
// Horizontal scrolling stock symbol selector
struct TickerView: View {
    let symbols: [String]                    // Array of stock symbols to display
    @Binding var selectedSymbol: String      // Currently selected symbol (two-way binding)
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {  // Horizontal scroll without scroll indicators
            HStack(spacing: 12) {  // Horizontal stack with consistent spacing
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(symbol == selectedSymbol
                                      ? Color.blue.opacity(0.8)    // Highlighted background for selected symbol
                                      : Color.gray.opacity(0.25))   // Subtle background for unselected symbols
                        )
                        .foregroundColor(.white)
                        .onTapGesture {
                            withAnimation { selectedSymbol = symbol }  // Update selection with animation
                        }
                }
            }
            .padding(.horizontal)  // Padding on sides for edge spacing
            .padding(.vertical, 8) // Padding on top/bottom
        }
        .background(Color(.systemBackground).opacity(0.95))  // Semi-transparent background
    }
}

// MARK: - Chart View Placeholder
// Placeholder chart view - replace with actual chart implementation
struct ChartView: View {
    let symbol: String  // Stock symbol to display chart for
    
    var body: some View {
        Rectangle()
            .fill(Color.blue.gradient)  // Blue gradient background
            .overlay(
                Text("Chart for \(symbol)")  // Placeholder text showing current symbol
                    .foregroundColor(.white)
                    .bold()
            )
    }
}

// MARK: - Bottom Sheet
// Native iOS bottom sheet for additional information and controls
struct BottomSheetView: View {
    var body: some View {
        VStack {
            // Content for the bottom sheet
            Text("Chart Info")
                .font(.title3)
                .padding()
            
            Text("Additional chart details and controls would go here")
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()  // Fill remaining space
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // Fill available space
        .background(Color(.systemBackground))               // System background color
    }
}

// lateset claude

//import SwiftUI
//
//// MARK: - Constants
//enum LayoutConstants {
//    static let drawerWidthRatio: CGFloat = 0.8
//    static let dragThreshold: CGFloat = 50
//    static let bottomSheetMinRatio: CGFloat = 0.1
//    static let bottomSheetMidRatio: CGFloat = 0.4
//    static let bottomSheetMaxRatio: CGFloat = 0.7
//    static let overlayOpacity: CGFloat = 0.4
//    static let topBarOpacity: CGFloat = 0.8
//    static let cornerRadius: CGFloat = 20
//    static let shadowRadius: CGFloat = 8
//}
//
//enum AnimationConstants {
//    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
//    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
//}
//
//// MARK: - RootView
//struct RootView: View {
//    // Environment object for session management
//    @EnvironmentObject var session: SessionStore
//
//    // MARK: - State Properties
//    @State private var showLeftDrawer: Bool = false
//    @State private var showRightDrawer: Bool = false
//    @State private var leftDragTranslation: CGFloat = 0
//    @State private var rightDragTranslation: CGFloat = 0
//    @State private var selectedSymbol: String = "AAPL"
//    @State private var bottomSheetOffset: CGFloat = 0
//    @State private var isBottomSheetInitialized: Bool = false
//    @GestureState private var dragOffset: CGFloat = 0
//    @GestureState private var leftDrawerDragOffset: CGFloat = 0
//    @GestureState private var rightDrawerDragOffset: CGFloat = 0
//
//    // Stock symbols - could be moved to SessionStore for dynamic data
//    let symbols: [String] = ["AAPL", "TSLA", "GOOG", "MSFT", "AMZN", "NVDA", "META", "NFLX"]
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
//    private func bottomSheetMinOffset(for height: CGFloat) -> CGFloat {
//        height * LayoutConstants.bottomSheetMinRatio
//    }
//
//    private func bottomSheetMidOffset(for height: CGFloat) -> CGFloat {
//        height * LayoutConstants.bottomSheetMidRatio
//    }
//
//    private func bottomSheetMaxOffset(for height: CGFloat) -> CGFloat {
//        height * LayoutConstants.bottomSheetMaxRatio
//    }
//
//    // MARK: - Body
//    var body: some View {
//        GeometryReader { geo in
//            let minOffset = bottomSheetMinOffset(for: geo.size.height)
//            let midOffset = bottomSheetMidOffset(for: geo.size.height)
//            let maxOffset = bottomSheetMaxOffset(for: geo.size.height)
//            
//            ZStack {
//                // MARK: - Background
//                backgroundGradient
//                
//                // MARK: - Main Content + Bottom Sheet
//                mainContentStack(minOffset: minOffset, midOffset: midOffset, maxOffset: maxOffset)
//                    .disabled(showLeftDrawer || showRightDrawer)
//                
//                // MARK: - Dimmed Overlay
//                if showLeftDrawer || showRightDrawer {
//                    overlayView
//                }
//                
//                // MARK: - Left Drawer
//                leftDrawerView
//                
//                // MARK: - Right Drawer
//                rightDrawerView
//            }
//            .onAppear {
//                initializeBottomSheet(midOffset: midOffset)
//            }
//        }
//        .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedSymbol)
//        .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
//        .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
//    }
//
//    // MARK: - View Components
//
//    private var backgroundGradient: some View {
//        LinearGradient(
//            colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .ignoresSafeArea()
//    }
//
//    private func mainContentStack(minOffset: CGFloat, midOffset: CGFloat, maxOffset: CGFloat) -> some View {
//        ZStack(alignment: .bottom) {
//            VStack(spacing: 0) {
//                topBarView
//                TickerView(symbols: symbols, selectedSymbol: $selectedSymbol)
//                ChartView(symbol: selectedSymbol)
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//            
//            bottomSheetView(minOffset: minOffset, midOffset: midOffset, maxOffset: maxOffset)
//        }
//    }
//
//    private var topBarView: some View {
//        HStack {
//            menuButton
//            Spacer()
//            rightMenuButton
//        }
//        .background(Color.black.opacity(LayoutConstants.topBarOpacity))
//    }
//
//    private var menuButton: some View {
//        Button(action: {
//            withAnimation(AnimationConstants.standard) {
//                showLeftDrawer.toggle()
//                showRightDrawer = false
//            }
//        }) {
//            Image(systemName: "line.horizontal.3")
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding()
//        }
//    }
//
//    private var rightMenuButton: some View {
//        Button(action: {
//            withAnimation(AnimationConstants.standard) {
//                showRightDrawer.toggle()
//                showLeftDrawer = false
//            }
//        }) {
//            Image(systemName: "ellipsis.circle")
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding()
//        }
//    }
//
//    private var overlayView: some View {
//        Color.black.opacity(LayoutConstants.overlayOpacity)
//            .ignoresSafeArea()
//            .onTapGesture {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    showRightDrawer = false
//                }
//            }
//            .gesture(
//                DragGesture()
//                    .onChanged { value in
//                        if showLeftDrawer {
//                            leftDragTranslation = min(0, value.translation.width)
//                        } else if showRightDrawer {
//                            rightDragTranslation = max(0, value.translation.width)
//                        }
//                    }
//                    .onEnded { value in
//                        if showLeftDrawer {
//                            handleLeftDrawerDrag(value: value)
//                        } else if showRightDrawer {
//                            handleRightDrawerDrag(value: value)
//                        }
//                        // Reset translations
//                        leftDragTranslation = 0
//                        rightDragTranslation = 0
//                    }
//            )
//    }
//
//    private var leftDrawerView: some View {
//        HStack(spacing: 0) {
//            DrawerView(side: .left) {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                }
//            }
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: leftDragTranslation)
//            Spacer(minLength: 0)
//        }
//        .frame(maxHeight: .infinity)
//        .offset(x: showLeftDrawer ? 0 : -drawerWidth)
//        .animation(AnimationConstants.standard, value: showLeftDrawer)
//    }
//
//    private var rightDrawerView: some View {
//        HStack(spacing: 0) {
//            Spacer(minLength: 0)
//            DrawerView(side: .right) {
//                withAnimation(AnimationConstants.standard) {
//                    showRightDrawer = false
//                }
//            }
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: rightDragTranslation)
//        }
//        .frame(maxHeight: .infinity)
//        .offset(x: showRightDrawer ? 0 : drawerWidth)
//        .animation(AnimationConstants.standard, value: showRightDrawer)
//    }
//
//    private func bottomSheetView(minOffset: CGFloat, midOffset: CGFloat, maxOffset: CGFloat) -> some View {
//        BottomSheetView()
//            .offset(y: bottomSheetOffset + dragOffset)
//            .gesture(
//                DragGesture()
//                    .updating($dragOffset) { value, state, _ in
//                        state = value.translation.height
//                    }
//                    .onEnded { value in
//                        handleBottomSheetDrag(value: value, minOffset: minOffset, midOffset: midOffset, maxOffset: maxOffset)
//                    }
//            )
//            .animation(AnimationConstants.standard, value: bottomSheetOffset)
//    }
//
//    // MARK: - Helpers
//
//    private func initializeBottomSheet(midOffset: CGFloat) {
//        if !isBottomSheetInitialized {
//            bottomSheetOffset = midOffset
//            isBottomSheetInitialized = true
//        }
//    }
//
//    private func handleBottomSheetDrag(value: DragGesture.Value, minOffset: CGFloat, midOffset: CGFloat, maxOffset: CGFloat) {
//        let newOffset = bottomSheetOffset + value.translation.height
//        
//        if newOffset < (minOffset + midOffset) / 2 {
//            bottomSheetOffset = minOffset
//        } else if newOffset < (midOffset + maxOffset) / 2 {
//            bottomSheetOffset = midOffset
//        } else {
//            bottomSheetOffset = maxOffset
//        }
//    }
//
//    private func handleLeftDrawerDrag(value: DragGesture.Value) {
//        let dragDistance = value.translation.width
//        let velocity = value.predictedEndTranslation.width
//        
//        // If dragged more than threshold or has significant velocity to the left, close drawer
//        if dragDistance < -LayoutConstants.dragThreshold || velocity < -100 {
//            withAnimation(AnimationConstants.standard) {
//                showLeftDrawer = false
//            }
//        } else {
//            // Snap back to open position if not dismissed
//            withAnimation(AnimationConstants.quick) {
//                leftDragTranslation = 0
//            }
//        }
//    }
//
//    private func handleRightDrawerDrag(value: DragGesture.Value) {
//        let dragDistance = value.translation.width
//        let velocity = value.predictedEndTranslation.width
//        
//        // If dragged more than threshold or has significant velocity to the right, close drawer
//        if dragDistance > LayoutConstants.dragThreshold || velocity > 100 {
//            withAnimation(AnimationConstants.standard) {
//                showRightDrawer = false
//            }
//        } else {
//            // Snap back to open position if not dismissed
//            withAnimation(AnimationConstants.quick) {
//                rightDragTranslation = 0
//            }
//        }
//    }
//}
//
//// MARK: - Drawer View
//enum DrawerSide { case left, right }
//
//struct DrawerView: View {
//    let side: DrawerSide
//    let onClose: () -> Void
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack {
//                Text(side == .left ? "Left Drawer" : "Right Drawer")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                Spacer()
//                Button(action: {
//                    withAnimation(AnimationConstants.standard) {
//                        onClose()
//                    }
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title2)
//                        .foregroundColor(.primary)
//                }
//            }
//            .padding()
//            .padding(.bottom, 8)
//            .padding(.top, 60) // Add extra top padding for status bar/notch
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemBackground))
//        .clipShape(
//            UnevenRoundedRectangle(
//                cornerRadii: .init(
//                    topLeading: side == .left ? 0 : LayoutConstants.cornerRadius,
//                    bottomLeading: side == .left ? 0 : LayoutConstants.cornerRadius,
//                    bottomTrailing: side == .left ? LayoutConstants.cornerRadius : 0,
//                    topTrailing: side == .left ? LayoutConstants.cornerRadius : 0
//                )
//            )
//        )
//        .shadow(radius: LayoutConstants.shadowRadius)
//        .ignoresSafeArea()
//    }
//}
//
//// MARK: - Ticker View
//struct TickerView: View {
//    let symbols: [String]
//    @Binding var selectedSymbol: String
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 12) {
//                ForEach(symbols, id: \.self) { symbol in
//                    Text(symbol)
//                        .font(.callout)
//                        .fontWeight(.medium)
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 8)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .fill(symbol == selectedSymbol
//                                      ? Color.blue.opacity(0.8)
//                                      : Color.gray.opacity(0.25))
//                        )
//                        .foregroundColor(.white)
//                        .onTapGesture {
//                            withAnimation { selectedSymbol = symbol }
//                        }
//                }
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 8)
//        }
//        .background(Color(.systemBackground).opacity(0.95))
//    }
//}
//
//// MARK: - Chart View Placeholder
//struct ChartView: View {
//    let symbol: String
//    var body: some View {
//        Rectangle()
//            .fill(Color.blue.gradient)
//            .overlay(
//                Text("Chart for \(symbol)")
//                    .foregroundColor(.white)
//                    .bold()
//            )
//    }
//}
//
//// MARK: - Bottom Sheet
//struct BottomSheetView: View {
//    var body: some View {
//        VStack {
//            Capsule()
//                .frame(width: 40, height: 5)
//                .foregroundColor(.secondary)
//                .padding(.top, 8)
//            
//            Text("Chart Info")
//                .font(.title3)
//                .padding()
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(.thinMaterial)
//        .cornerRadius(LayoutConstants.cornerRadius)
//        .ignoresSafeArea(edges: .bottom)
//    }
//}


// NEW IMPROVED FROM CLAUDE THA THAS GOOD DRAWER WORKABILITY BUT NO

//import SwiftUI
//
//// MARK: - Constants
//enum LayoutConstants {
//    static let drawerWidthRatio: CGFloat = 0.8
//    static let dragThreshold: CGFloat = 50
//    static let bottomSheetMinRatio: CGFloat = 0.1
//    static let bottomSheetMidRatio: CGFloat = 0.4
//    static let bottomSheetMaxRatio: CGFloat = 0.7
//    static let overlayOpacity: CGFloat = 0.4
//    static let topBarOpacity: CGFloat = 0.8
//    static let cornerRadius: CGFloat = 20
//    static let shadowRadius: CGFloat = 8
//}
//
//enum AnimationConstants {
//    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
//    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
//}
//
//// MARK: - RootView
//struct RootView: View {
//    // Environment object for session management
//    @EnvironmentObject var session: SessionStore
//
//    // MARK: - State Properties
//    @State private var showLeftDrawer: Bool = false
//    @State private var showRightDrawer: Bool = false
//    @State private var leftDragTranslation: CGFloat = 0
//    @State private var rightDragTranslation: CGFloat = 0
//    @State private var selectedSymbol: String = "AAPL"
//    @State private var bottomSheetOffset: CGFloat = 0
//    @State private var isBottomSheetInitialized: Bool = false
//    @GestureState private var dragOffset: CGFloat = 0
//    @GestureState private var leftDrawerDragOffset: CGFloat = 0
//    @GestureState private var rightDrawerDragOffset: CGFloat = 0
//
//    // Stock symbols - could be moved to SessionStore for dynamic data
//    let symbols: [String] = ["AAPL", "TSLA", "GOOG", "MSFT", "AMZN", "NVDA", "META", "NFLX"]
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
//    private func bottomSheetMinOffset(for height: CGFloat) -> CGFloat {
//        height * LayoutConstants.bottomSheetMinRatio
//    }
//
//    private func bottomSheetMidOffset(for height: CGFloat) -> CGFloat {
//        height * LayoutConstants.bottomSheetMidRatio
//    }
//
//    private func bottomSheetMaxOffset(for height: CGFloat) -> CGFloat {
//        height * LayoutConstants.bottomSheetMaxRatio
//    }
//
//    // MARK: - Body
//    var body: some View {
//        GeometryReader { geo in
//            let minOffset = bottomSheetMinOffset(for: geo.size.height)
//            let midOffset = bottomSheetMidOffset(for: geo.size.height)
//            let maxOffset = bottomSheetMaxOffset(for: geo.size.height)
//            
//            ZStack {
//                // MARK: - Background
//                backgroundGradient
//                
//                // MARK: - Main Content + Bottom Sheet
//                mainContentStack(minOffset: minOffset, midOffset: midOffset, maxOffset: maxOffset)
//                    .disabled(showLeftDrawer || showRightDrawer)
//                
//                // MARK: - Dimmed Overlay
//                if showLeftDrawer || showRightDrawer {
//                    overlayView
//                }
//                
//                // MARK: - Left Drawer
//                leftDrawerView
//                
//                // MARK: - Right Drawer
//                rightDrawerView
//            }
//            .onAppear {
//                initializeBottomSheet(midOffset: midOffset)
//            }
//        }
//        .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedSymbol)
//        .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)
//        .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)
//    }
//
//    // MARK: - View Components
//
//    private var backgroundGradient: some View {
//        LinearGradient(
//            colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .ignoresSafeArea()
//    }
//
//    private func mainContentStack(minOffset: CGFloat, midOffset: CGFloat, maxOffset: CGFloat) -> some View {
//        ZStack(alignment: .bottom) {
//            VStack(spacing: 0) {
//                topBarView
//                TickerView(symbols: symbols, selectedSymbol: $selectedSymbol)
//                ChartView(symbol: selectedSymbol)
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//            
//            bottomSheetView(minOffset: minOffset, midOffset: midOffset, maxOffset: maxOffset)
//        }
//    }
//
//    private var topBarView: some View {
//        HStack {
//            menuButton
//            Spacer()
//            rightMenuButton
//        }
//        .background(Color.black.opacity(LayoutConstants.topBarOpacity))
//    }
//
//    private var menuButton: some View {
//        Button(action: {
//            withAnimation(AnimationConstants.standard) {
//                showLeftDrawer.toggle()
//                showRightDrawer = false
//            }
//        }) {
//            Image(systemName: "line.horizontal.3")
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding()
//        }
//    }
//
//    private var rightMenuButton: some View {
//        Button(action: {
//            withAnimation(AnimationConstants.standard) {
//                showRightDrawer.toggle()
//                showLeftDrawer = false
//            }
//        }) {
//            Image(systemName: "ellipsis.circle")
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding()
//        }
//    }
//
//    private var overlayView: some View {
//        Color.black.opacity(LayoutConstants.overlayOpacity)
//            .ignoresSafeArea()
//            .onTapGesture {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    showRightDrawer = false
//                }
//            }
//    }
//
//    private var leftDrawerView: some View {
//        HStack(spacing: 0) {
//            DrawerView(side: .left) {
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                }
//            }
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: leftDrawerDragOffset)
//            .gesture(
//                DragGesture()
//                    .updating($leftDrawerDragOffset) { value, state, _ in
//                        // Only allow dragging to the left (negative values)
//                        state = min(0, value.translation.width)
//                    }
//                    .onEnded { value in
//                        handleLeftDrawerDrag(value: value)
//                    }
//            )
//            Spacer(minLength: 0)
//        }
//        .frame(maxHeight: .infinity)
//        .offset(x: showLeftDrawer ? 0 : -drawerWidth)
//        .animation(AnimationConstants.standard, value: showLeftDrawer)
//    }
//
//    private var rightDrawerView: some View {
//        HStack(spacing: 0) {
//            Spacer(minLength: 0)
//            DrawerView(side: .right) {
//                withAnimation(AnimationConstants.standard) {
//                    showRightDrawer = false
//                }
//            }
//            .frame(width: drawerWidth)
//            .frame(maxHeight: .infinity)
//            .offset(x: rightDrawerDragOffset)
//            .gesture(
//                DragGesture()
//                    .updating($rightDrawerDragOffset) { value, state, _ in
//                        // Only allow dragging to the right (positive values)
//                        state = max(0, value.translation.width)
//                    }
//                    .onEnded { value in
//                        handleRightDrawerDrag(value: value)
//                    }
//            )
//        }
//        .frame(maxHeight: .infinity)
//        .offset(x: showRightDrawer ? 0 : drawerWidth)
//        .animation(AnimationConstants.standard, value: showRightDrawer)
//    }
//
//    private func bottomSheetView(minOffset: CGFloat, midOffset: CGFloat, maxOffset: CGFloat) -> some View {
//        BottomSheetView()
//            .offset(y: bottomSheetOffset + dragOffset)
//            .gesture(
//                DragGesture()
//                    .updating($dragOffset) { value, state, _ in
//                        state = value.translation.height
//                    }
//                    .onEnded { value in
//                        handleBottomSheetDrag(value: value, minOffset: minOffset, midOffset: midOffset, maxOffset: maxOffset)
//                    }
//            )
//            .animation(AnimationConstants.standard, value: bottomSheetOffset)
//    }
//
//    // MARK: - Helpers
//
//    private func initializeBottomSheet(midOffset: CGFloat) {
//        if !isBottomSheetInitialized {
//            bottomSheetOffset = midOffset
//            isBottomSheetInitialized = true
//        }
//    }
//
//    private func handleBottomSheetDrag(value: DragGesture.Value, minOffset: CGFloat, midOffset: CGFloat, maxOffset: CGFloat) {
//        let newOffset = bottomSheetOffset + value.translation.height
//        
//        if newOffset < (minOffset + midOffset) / 2 {
//            bottomSheetOffset = minOffset
//        } else if newOffset < (midOffset + maxOffset) / 2 {
//            bottomSheetOffset = midOffset
//        } else {
//            bottomSheetOffset = maxOffset
//        }
//    }
//
//    private func handleLeftDrawerDrag(value: DragGesture.Value) {
//        let dragDistance = value.translation.width
//        let velocity = value.predictedEndTranslation.width
//        
//        // If dragged more than threshold or has significant velocity to the left, close drawer
//        if dragDistance < -LayoutConstants.dragThreshold || velocity < -100 {
//            withAnimation(AnimationConstants.standard) {
//                showLeftDrawer = false
//            }
//        }
//    }
//
//    private func handleRightDrawerDrag(value: DragGesture.Value) {
//        let dragDistance = value.translation.width
//        let velocity = value.predictedEndTranslation.width
//        
//        // If dragged more than threshold or has significant velocity to the right, close drawer
//        if dragDistance > LayoutConstants.dragThreshold || velocity > 100 {
//            withAnimation(AnimationConstants.standard) {
//                showRightDrawer = false
//            }
//        }
//    }
//}
//
//// MARK: - Drawer View
//enum DrawerSide { case left, right }
//
//struct DrawerView: View {
//    let side: DrawerSide
//    let onClose: () -> Void
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack {
//                Text(side == .left ? "Left Drawer" : "Right Drawer")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                Spacer()
//                Button(action: {
//                    withAnimation(AnimationConstants.standard) {
//                        onClose()
//                    }
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title2)
//                        .foregroundColor(.primary)
//                }
//            }
//            .padding()
//            .padding(.bottom, 8)
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color(.systemBackground))
//        .clipShape(
//            UnevenRoundedRectangle(
//                cornerRadii: .init(
//                    topLeading: side == .left ? 0 : LayoutConstants.cornerRadius,
//                    bottomLeading: side == .left ? 0 : LayoutConstants.cornerRadius,
//                    bottomTrailing: side == .left ? LayoutConstants.cornerRadius : 0,
//                    topTrailing: side == .left ? LayoutConstants.cornerRadius : 0
//                )
//            )
//        )
//        .shadow(radius: LayoutConstants.shadowRadius)
//        .ignoresSafeArea()
//    }
//}
//
//// MARK: - Ticker View
//struct TickerView: View {
//    let symbols: [String]
//    @Binding var selectedSymbol: String
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 12) {
//                ForEach(symbols, id: \.self) { symbol in
//                    Text(symbol)
//                        .font(.callout)
//                        .fontWeight(.medium)
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 8)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .fill(symbol == selectedSymbol
//                                      ? Color.blue.opacity(0.8)
//                                      : Color.gray.opacity(0.25))
//                        )
//                        .foregroundColor(.white)
//                        .onTapGesture {
//                            withAnimation { selectedSymbol = symbol }
//                        }
//                }
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 8)
//        }
//        .background(Color(.systemBackground).opacity(0.95))
//    }
//}
//
//// MARK: - Chart View Placeholder
//struct ChartView: View {
//    let symbol: String
//    var body: some View {
//        Rectangle()
//            .fill(Color.blue.gradient)
//            .overlay(
//                Text("Chart for \(symbol)")
//                    .foregroundColor(.white)
//                    .bold()
//            )
//    }
//}
//
//// MARK: - Bottom Sheet
//struct BottomSheetView: View {
//    var body: some View {
//        VStack {
//            Capsule()
//                .frame(width: 40, height: 5)
//                .foregroundColor(.secondary)
//                .padding(.top, 8)
//            
//            Text("Chart Info")
//                .font(.title3)
//                .padding()
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(.thinMaterial)
//        .cornerRadius(LayoutConstants.cornerRadius)
//        .ignoresSafeArea(edges: .bottom)
//    }
//}




























//import SwiftUI
//
//// MARK: - RootView
///// Main container view of the app. Contains:
///// - Top navigation bar with left/right drawer buttons
///// - Horizontal ticker
///// - Main chart area
///// - Bottom sheet
///// - Left and right drawers with interactive drag-to-close gestures
//struct RootView: View {
//    @EnvironmentObject var session: SessionStore // Global session for user/auth/settings
//    
//    // MARK: Drawer state
//    @State private var showLeftDrawer = false   // Whether the left drawer is open
//    @State private var showRightDrawer = false  // Whether the right drawer is open
//    
//    // Drag offsets for interactive drawer gestures
//    @State private var leftDragTranslation: CGFloat = 0
//    @State private var rightDragTranslation: CGFloat = 0
//    
//    // MARK: Chart state
//    @State private var selectedSymbol: String = "AAPL" // Currently selected stock symbol
//    
//    // MARK: Bottom sheet state
//    @State private var bottomSheetOffset: CGFloat = 300 // Y-offset of bottom sheet
//    @GestureState private var dragOffset: CGFloat = 0   // Live tracking of drag movement
//    
//    // Example ticker symbols
//    let symbols = ["AAPL", "TSLA", "GOOG", "MSFT", "AMZN", "NVDA", "META", "NFLX"]
//    
//    var body: some View {
//        GeometryReader { geo in
//            // Compute drawer width as 80% of screen width
//            let drawerWidth = geo.size.width * 0.8
//            
//            // Compute main content offset based on drawer state + interactive drag
//            let contentOffset = showLeftDrawer ? drawerWidth + leftDragTranslation
//                                 : showRightDrawer ? -drawerWidth + rightDragTranslation
//                                 : 0
//            
//            ZStack {
//                // === BACKGROUND ===
//                LinearGradient(
//                    colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
//                    startPoint: .top,
//                    endPoint: .bottom
//                )
//                .ignoresSafeArea() // Fill entire screen
//                
//                // === MAIN CONTENT + BOTTOM SHEET ===
//                ZStack(alignment: .bottom) {
//                    VStack(spacing: 0) {
//                        // --- Top Navigation Bar ---
//                        HStack {
//                            // Left drawer button
//                            Button(action: {
//                                withAnimation(.spring()) {
//                                    showLeftDrawer.toggle()  // Open/close left drawer
//                                    showRightDrawer = false // Close right drawer if open
//                                }
//                            }) {
//                                Image(systemName: "line.horizontal.3")
//                                    .font(.title2)
//                                    .foregroundColor(.white)
//                                    .padding()
//                            }
//                            Spacer()
//                            // Right drawer button
//                            Button(action: {
//                                withAnimation(.spring()) {
//                                    showRightDrawer.toggle() // Open/close right drawer
//                                    showLeftDrawer = false  // Close left drawer if open
//                                }
//                            }) {
//                                Image(systemName: "ellipsis.circle")
//                                    .font(.title2)
//                                    .foregroundColor(.white)
//                                    .padding()
//                            }
//                        }
//                        .background(Color.black.opacity(0.8)) // Dark top bar background
//                        
//                        // --- Horizontal Ticker Bar ---
//                        TickerView(symbols: symbols, selectedSymbol: $selectedSymbol)
//                        
//                        // --- Chart Area ---
//                        ChartView(symbol: selectedSymbol)
//                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    }
//                    
//                    // --- Bottom Sheet ---
//                    BottomSheetView()
//                        .offset(y: bottomSheetOffset + dragOffset) // Move sheet with drag
//                        .gesture(
//                            DragGesture()
//                                // Track live drag offset
//                                .updating($dragOffset) { value, state, _ in
//                                    state = value.translation.height
//                                }
//                                // Snap to nearest position on release
//                                .onEnded { value in
//                                    let newOffset = bottomSheetOffset + value.translation.height
//                                    if newOffset < 200 {
//                                        bottomSheetOffset = 100 // fully expanded
//                                    } else if newOffset > 500 {
//                                        bottomSheetOffset = 550 // fully collapsed
//                                    } else {
//                                        bottomSheetOffset = 300 // mid position
//                                    }
//                                }
//                        )
//                        .animation(.spring(), value: bottomSheetOffset)
//                }
//                .offset(x: contentOffset) // Slide main content with drawer
//                .disabled(showLeftDrawer || showRightDrawer) // Prevent interaction when drawer open
//                
//                // === DIMMED OVERLAY ===
//                if showLeftDrawer || showRightDrawer {
//                    Color.black.opacity(0.4)
//                        .ignoresSafeArea()
//                        .gesture(
//                            DragGesture()
//                                .onChanged { value in
//                                    // Allow interactive drag only in the closing direction
//                                    if showLeftDrawer && value.translation.width < 0 {
//                                        leftDragTranslation = value.translation.width
//                                    } else if showRightDrawer && value.translation.width > 0 {
//                                        rightDragTranslation = value.translation.width
//                                    }
//                                }
//                                .onEnded { value in
//                                    // Close drawer if dragged in closing direction
//                                    if showLeftDrawer && value.translation.width < 0 {
//                                        withAnimation(.spring()) { showLeftDrawer = false }
//                                    }
//                                    if showRightDrawer && value.translation.width > 0 {
//                                        withAnimation(.spring()) { showRightDrawer = false }
//                                    }
//                                    // Reset drag offsets
//                                    leftDragTranslation = 0
//                                    rightDragTranslation = 0
//                                }
//                        )
//                        .onTapGesture {
//                            // Tap outside drawer to close
//                            withAnimation(.spring()) {
//                                showLeftDrawer = false
//                                showRightDrawer = false
//                            }
//                        }
//                        .zIndex(1) // Ensure overlay is above main content but below drawers
//                }
//                
//                // === LEFT DRAWER ===
//                ZStack(alignment: .leading) {
//                    DrawerView(side: .left) {
//                        // Close drawer via button inside drawer
//                        withAnimation(.spring()) { showLeftDrawer = false }
//                    }
//                    .frame(width: drawerWidth)
//                    .offset(x: showLeftDrawer ? leftDragTranslation : -drawerWidth) // fully offscreen when closed
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                // Restrict drag to left direction only
//                                leftDragTranslation = min(0, value.translation.width)
//                            }
//                            .onEnded { value in
//                                // Close only if dragged left
//                                if value.translation.width < 0 {
//                                    withAnimation(.spring()) { showLeftDrawer = false }
//                                }
//                                leftDragTranslation = 0 // Reset offset
//                            }
//                    )
//                }
//                .frame(width: geo.size.width, alignment: .leading)
//                .zIndex(2) // Ensure drawer is above overlay
//                
//                // === RIGHT DRAWER ===
//                ZStack(alignment: .trailing) {
//                    DrawerView(side: .right) {
//                        withAnimation(.spring()) { showRightDrawer = false }
//                    }
//                    .frame(width: drawerWidth)
//                    .offset(x: showRightDrawer ? rightDragTranslation : drawerWidth) // fully offscreen when closed
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                // Restrict drag to right direction only
//                                rightDragTranslation = max(0, value.translation.width)
//                            }
//                            .onEnded { value in
//                                // Close only if dragged right
//                                if value.translation.width > 0 {
//                                    withAnimation(.spring()) { showRightDrawer = false }
//                                }
//                                rightDragTranslation = 0 // Reset offset
//                            }
//                    )
//                }
//                .frame(width: geo.size.width, alignment: .trailing)
//                .zIndex(2)
//            }
//        }
//    }
//}
//
//// MARK: - Drawer View
///// A simple side drawer containing a title and close button.
//enum DrawerSide { case left, right }
//
//struct DrawerView: View {
//    let side: DrawerSide
//    let onClose: () -> Void
//    
//    var body: some View {
//        VStack(alignment: .leading) {
//            HStack {
//                Text(side == .left ? "Left Drawer" : "Right Drawer")
//                    .font(.headline)
//                Spacer()
//                // Close button inside drawer
//                Button(action: { withAnimation(.spring()) { onClose() } }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title2)
//                }
//            }
//            .padding(.bottom)
//            
//            Spacer() // Push content to top
//        }
//        .padding()
//        .background(Color(.systemBackground)) // Drawer background
//        .shadow(radius: 8) // Subtle shadow
//    }
//}
//
//// MARK: - Ticker View
///// Horizontally scrollable list of stock symbols
//struct TickerView: View {
//    let symbols: [String]
//    @Binding var selectedSymbol: String
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 12) {
//                ForEach(symbols, id: \.self) { symbol in
//                    Text(symbol)
//                        .font(.callout)
//                        .fontWeight(.medium)
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 8)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .fill(symbol == selectedSymbol
//                                      ? Color.blue.opacity(0.8)  // Highlight selected
//                                      : Color.gray.opacity(0.25)) // Unselected
//                        )
//                        .foregroundColor(.white)
//                        .onTapGesture {
//                            // Animate selection change
//                            withAnimation { selectedSymbol = symbol }
//                        }
//                }
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 8)
//        }
//        .background(Color(.systemBackground).opacity(0.95))
//    }
//}
//
//// MARK: - Chart View Placeholder
//struct ChartView: View {
//    let symbol: String
//    var body: some View {
//        Rectangle()
//            .fill(Color.blue.gradient)
//            .overlay(
//                Text("Chart for \(symbol)")
//                    .foregroundColor(.white)
//                    .bold()
//            )
//    }
//}
//
//// MARK: - Bottom Sheet
//struct BottomSheetView: View {
//    var body: some View {
//        VStack {
//            Capsule()
//                .frame(width: 40, height: 5)
//                .foregroundColor(.secondary)
//                .padding(.top, 8)
//            
//            Text("Chart Info")
//                .font(.title3)
//                .padding()
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(.thinMaterial)
//        .cornerRadius(20)
//        .ignoresSafeArea(edges: .bottom)
//    }
//}

#Preview {
    RootView()
}
