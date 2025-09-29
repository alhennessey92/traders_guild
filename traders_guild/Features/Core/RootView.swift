//
//  RootView.swift
//  traders_guild
//
//  Created by Al Hennessey on 19/09/2025.
//


// NOTES !!!!!!!!!!!!!!!!
// I have commented the fade animation for dev
// v43 claude code is best so far

//import SwiftUI
//
//// MARK: - Constants
//// Layout constants for consistent spacing, sizing, and ratios throughout the app
//enum LayoutConstants {
//    static let drawerWidthRatio: CGFloat = 0.9              // Drawer width as % of screen width (80%)
//    static let dragThreshold: CGFloat = 50                   // General drag threshold for gestures
//    static let drawerDismissThreshold: CGFloat = 100         // How far user must drag to dismiss drawer
//    static let overlayOpacity: CGFloat = 0.4                 // Darkness of overlay behind drawers
//    static let topBarOpacity: CGFloat = 0.8                  // Opacity of top navigation bar
//    static let cornerRadius: CGFloat = 33                    // Standard corner radius for rounded elements
//    static let shadowRadius: CGFloat = 8                     // Shadow blur radius for depth
//}
//
//// Animation constants for consistent motion throughout the app
//enum AnimationConstants {
//    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)  // Standard spring animation
//    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)     // Quick snap animation
//}
//
//// MARK: - RootView
//// Main container view that manages the entire app layout including drawers and charts
//struct RootView: View {
//    // Environment object for session management across the app
//    @EnvironmentObject var session: SessionStore
//    
//    // MARK: - State Properties
//    // Drawer state management
//    @State private var showLeftDrawer: Bool = false          // Controls left drawer visibility
//    @State private var showRightDrawer: Bool = false         // Controls right drawer visibility
//    @State private var showOverlay: Bool = false             // Controls overlay visibility (separate from drawers for smooth fade)
//    
//    // Drag translation states - track how far drawers are dragged during gestures
//    @State private var leftDragTranslation: CGFloat = 0      // Current drag offset for left drawer
//    @State private var rightDragTranslation: CGFloat = 0     // Current drag offset for right drawer
//    
//    // Chart and content state
//    @State private var selectedSymbol: String = "AAPL"       // Currently selected stock symbol
//    
//    // Bottom sheet state management - using native .sheet()
//    @State private var showBottomSheet: Bool = false         // Controls native bottom sheet visibility (starts hidden for entrance animation)
//    @State private var hasAppeared: Bool = false             // Track if view has appeared for entrance animation
//    @State private var fadeIn: Bool = false                  // Controls elegant fade-in animation on first app launch
//    @State private var bottomSheetBounce: Bool = false       // Controls bottom sheet bounce animation when returning from background
//    
//    // Stock symbols array - could be moved to SessionStore for dynamic data
//    let symbols: [String] = ["AAPL", "TSLA", "GOOG", "MSFT", "AMZN", "NVDA", "META", "NFLX"]
//    
//    // MARK: - Computed Properties
//    // Get current screen size for responsive layout calculations
//    private var screenSize: CGSize {
//        UIScreen.main.bounds.size
//    }
//    
//    // Calculate drawer width based on screen width and ratio constant
//    private var drawerWidth: CGFloat {
//        screenSize.width * LayoutConstants.drawerWidthRatio
//    }
//    
//    // MARK: - Body
//    var body: some View {
//        // ZStack layers all UI elements with proper z-ordering
//        ZStack {
//            // MARK: - Background Layer (always visible, no fade)
//            backgroundGradient
//            
//            // MARK: - Main Content Layer (fade animation applied here)
//            // Disable interaction when drawers are open to prevent conflicts
//            mainContentStack
//                .disabled(showLeftDrawer || showRightDrawer)
//                .opacity(fadeIn ? 1 : 0)    // Move fade animation to content only
//                .animation(.easeIn(duration: 1.5), value: fadeIn)  // Fade just the content
//            
//            // MARK: - Overlay Layer (no fade animation)
//            // Semi-transparent overlay that appears behind open drawers
//            if showOverlay {
//                overlayView
//                    .opacity(showLeftDrawer || showRightDrawer ? 1 : 0)           // Animate opacity based on drawer state
//                    .animation(.easeOut(duration: 0.4), value: showLeftDrawer)    // Smooth fade animation for left drawer
//                    .animation(.easeOut(duration: 0.4), value: showRightDrawer)   // Smooth fade animation for right drawer
//                    .gesture(
//                        // Allow dragging from anywhere on the overlay to dismiss drawers
//                        DragGesture()
//                            .onChanged { value in
//                                // Update drag translation based on which drawer is open and drag direction
//                                if showLeftDrawer && value.translation.width < 0 {
//                                    leftDragTranslation = value.translation.width
//                                } else if showRightDrawer && value.translation.width > 0 {
//                                    rightDragTranslation = value.translation.width
//                                }
//                            }
//                            .onEnded { value in
//                                // Handle drag end with current position to allow "change of mind" gestures
//                                handleDrawerDragEnd(currentPosition: showLeftDrawer ? leftDragTranslation : rightDragTranslation)
//                            }
//                    )
//            }
//            
//            // MARK: - Drawer Layers (fade animation applied here too)
//            leftDrawerView       // Left side navigation drawer
//                .opacity(fadeIn ? 1 : 0)    // Fade drawers with content
//                .animation(.easeIn(duration: 1.5), value: fadeIn)
//                
//            rightDrawerView      // Right side options drawer
//                .opacity(fadeIn ? 1 : 0)    // Fade drawers with content
//                .animation(.easeIn(duration: 1.5), value: fadeIn)
//        }
//        // Remove fade animation from here - it was affecting the entire ZStack including sheet overlay
//        // .opacity(fadeIn ? 1 : 0)    // REMOVED
//        // .animation(.easeIn(duration: 1.5), value: fadeIn)  // REMOVED
//        
//        // Native bottom sheet using Apple's .sheet modifier (no fade animation)
//        // Conditionally hidden when drawers are open to prevent layering conflicts
//        .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
//            BottomSheetView()
//                .presentationDetents([.fraction(0.1), .fraction(0.5), .fraction(0.9)])
//                .presentationDragIndicator(.visible)
//                .presentationBackgroundInteraction(.enabled)
//                .interactiveDismissDisabled(true)
//                .presentationBackground(AppColors.gradientBackgroundDark)
//                .presentationCornerRadius(33)
//                .scaleEffect(bottomSheetBounce ? 1.12 : 1.0)
//                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: bottomSheetBounce)
//        }
//
//        // Layered entrance animation sequence on app launch
//        .onAppear {
//            if !hasAppeared {
//                hasAppeared = true
//                
//                // Start elegant fade-in animation immediately for premium first impression
//                withAnimation(.easeIn(duration: 1.5)) {
//                    fadeIn = true
//                }
//                
//                // Delay bottom sheet entrance for layered effect (content fades in, then sheet slides up)
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
//                        showBottomSheet = true
//                    }
//                }
//            }
//        }
//        // Subtle "welcome back" bounce animation when returning from background
//        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
//            // Focused animation - only bottom sheet bounces, main content stays stable
//            bottomSheetBounce = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                bottomSheetBounce = false  // Return to normal size after 0.4 seconds
//            }
//        }
//        // Haptic feedback for user interactions
//        .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedSymbol)  // Soft feedback when symbol changes
//        .sensoryFeedback(.impact(weight: .light), trigger: showLeftDrawer)      // Light feedback when left drawer toggles
//        .sensoryFeedback(.impact(weight: .light), trigger: showRightDrawer)     // Light feedback when right drawer toggles
//    }
//    
//    // MARK: - View Components
//    
//    // Background gradient that covers the entire screen
//    private var backgroundGradient: some View {
//        LinearGradient(
//            colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundLight],
//            startPoint: .top,
//            endPoint: .bottom
//        )
//        .ignoresSafeArea()  // Extend gradient behind safe areas
//    }
//    
//    // Main content stack containing navigation bar, ticker, and chart
//    private var mainContentStack: some View {
//        // Main content in vertical stack
//        VStack(spacing: 0) {
//            topBarView                                                          // Navigation bar with menu buttons
//            TickerView(symbols: symbols, selectedSymbol: $selectedSymbol)       // Horizontal scrolling stock ticker
//            ChartView(symbol: selectedSymbol)                                   // Main chart display
//                .frame(maxWidth: .infinity, maxHeight: .infinity)               // Fill remaining space
//        }
//    }
//    
//    // Top navigation bar with menu buttons
//    private var topBarView: some View {
//        HStack {
//            menuButton          // Left menu button (hamburger)
//            Spacer()           // Push buttons to edges
//            rightMenuButton    // Right menu button (ellipsis)
//        }
//        .background(Color.black.opacity(LayoutConstants.topBarOpacity))  // Semi-transparent dark background
//    }
//    
//    // Left menu button that toggles the left drawer
//    private var menuButton: some View {
//        Button(action: {
//            withAnimation(AnimationConstants.standard) {
//                showLeftDrawer.toggle()     // Toggle left drawer state
//                showRightDrawer = false     // Close right drawer if open
//                showOverlay = showLeftDrawer // Update overlay state to match drawer
//            }
//        }) {
//            Image(systemName: "line.horizontal.3")  // Hamburger menu icon
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding()
//        }
//    }
//    
//    // Right menu button that toggles the right drawer
//    private var rightMenuButton: some View {
//        Button(action: {
//            withAnimation(AnimationConstants.standard) {
//                showRightDrawer.toggle()     // Toggle right drawer state
//                showLeftDrawer = false       // Close left drawer if open
//                showOverlay = showRightDrawer // Update overlay state to match drawer
//            }
//        }) {
//            Image(systemName: "ellipsis.circle")  // Options menu icon
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding()
//        }
//    }
//    
//    // Semi-transparent overlay that dims content when drawers are open
//    private var overlayView: some View {
//        Color.black.opacity(LayoutConstants.overlayOpacity)
//            .ignoresSafeArea()  // Cover entire screen including safe areas
//            .onTapGesture {
//                // Close drawers when overlay is tapped
//                withAnimation(AnimationConstants.standard) {
//                    showLeftDrawer = false
//                    showRightDrawer = false
//                    leftDragTranslation = 0      // Reset drag states
//                    rightDragTranslation = 0
//                }
//                // Delay hiding overlay to allow smooth fade-out animation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            }
//    }
//    
//    // Left drawer view with swipe-to-dismiss functionality
//    private var leftDrawerView: some View {
//        HStack(spacing: 0) {  // No spacing to ensure drawer touches screen edge
//            DrawerView(side: .left) {
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
//            .frame(width: drawerWidth)      // Set fixed width
//            .frame(maxHeight: .infinity)    // Extend to full height
//            .offset(x: leftDragTranslation) // Apply drag translation for following gesture
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
//                        // Handle drag end with current position for "change of mind" support
//                        handleDrawerDragEnd(currentPosition: leftDragTranslation)
//                    }
//            )
//            Spacer(minLength: 0)  // Fill remaining space with minimum length 0
//        }
//        .frame(maxHeight: .infinity)  // Full height container
//        .offset(x: showLeftDrawer ? 0 : -drawerWidth)  // Slide drawer in/out based on state
//        .animation(AnimationConstants.standard, value: showLeftDrawer)  // Animate position changes
//    }
//    
//    // Right drawer view with swipe-to-dismiss functionality
//    private var rightDrawerView: some View {
//        HStack(spacing: 0) {  // No spacing to ensure drawer touches screen edge
//            Spacer(minLength: 0)  // Fill space before drawer
//            DrawerView(side: .right) {
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
//            .frame(width: drawerWidth)       // Set fixed width
//            .frame(maxHeight: .infinity)     // Extend to full height
//            .offset(x: rightDragTranslation) // Apply drag translation for following gesture
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
//                        // Handle drag end with current position for "change of mind" support
//                        handleDrawerDragEnd(currentPosition: rightDragTranslation)
//                    }
//            )
//        }
//        .frame(maxHeight: .infinity)  // Full height container
//        .offset(x: showRightDrawer ? 0 : drawerWidth)  // Slide drawer in/out based on state
//        .animation(AnimationConstants.standard, value: showRightDrawer)  // Animate position changes
//    }
//    
//    // MARK: - Helper Functions
//    
//    // Handle drawer drag ending - dismiss or snap back based on current position
//    // This function enables "change of mind" gestures where users can drag to dismiss then drag back to cancel
//    private func handleDrawerDragEnd(currentPosition: CGFloat) {
//        if showLeftDrawer {
//            // Check if left drawer is dragged far enough past threshold to dismiss
//            if currentPosition < -LayoutConstants.drawerDismissThreshold {
//                // Close the drawer smoothly - user dragged far enough
//                showLeftDrawer = false
//                leftDragTranslation = 0
//                // Delay hiding overlay for smooth 0.4s fade-out animation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            } else {
//                // Snap back to open position - user didn't drag far enough or changed their mind
//                withAnimation(AnimationConstants.quick) {
//                    leftDragTranslation = 0
//                }
//            }
//        } else if showRightDrawer {
//            // Check if right drawer is dragged far enough past threshold to dismiss
//            if currentPosition > LayoutConstants.drawerDismissThreshold {
//                // Close the drawer smoothly - user dragged far enough
//                showRightDrawer = false
//                rightDragTranslation = 0
//                // Delay hiding overlay for smooth 0.4s fade-out animation
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    showOverlay = false
//                }
//            } else {
//                // Snap back to open position - user didn't drag far enough or changed their mind
//                withAnimation(AnimationConstants.quick) {
//                    rightDragTranslation = 0
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Drawer View
//// Enum to specify which side a drawer appears on (affects corner rounding)
//enum DrawerSide { case left, right }
//
//// Individual drawer view with content and close functionality
//struct DrawerView: View {
//    let side: DrawerSide        // Which side this drawer appears on
//    let onClose: () -> Void     // Closure called when drawer should close
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            // Header section with title and close button
//            HStack {
//                Text(side == .left ? "Left Drawer" : "Right Drawer")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                Spacer()  // Push close button to the right
//                Button(action: {
//                    withAnimation(AnimationConstants.standard) { onClose() }
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title2)
//                        .foregroundColor(.primary)
//                }
//            }
//            .padding()                    // Standard padding around header content
//            .padding(.bottom, 8)          // Extra bottom padding for visual separation
//            .padding(.top, 60)            // Extra top padding to clear status bar/notch area
//            
//            Spacer()  // Fill remaining space (where drawer content would go)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
//        .background(Color(.systemBackground))              // System background color (adapts to light/dark mode)
//        .clipShape(
//            // Custom corner rounding - only round corners opposite to the edge drawer slides from
//            UnevenRoundedRectangle(
//                cornerRadii: .init(
//                    topLeading: side == .left ? 0 : LayoutConstants.cornerRadius,      // Left drawer: square top-left corner
//                    bottomLeading: side == .left ? 0 : LayoutConstants.cornerRadius,   // Left drawer: square bottom-left corner
//                    bottomTrailing: side == .left ? LayoutConstants.cornerRadius : 0,  // Left drawer: round bottom-right corner
//                    topTrailing: side == .left ? LayoutConstants.cornerRadius : 0      // Left drawer: round top-right corner
//                )
//            )
//        )
//        .shadow(radius: LayoutConstants.shadowRadius)  // Drop shadow for depth
//        .ignoresSafeArea()                            // Extend to screen edges including safe areas
//    }
//}
//
//// MARK: - Ticker View
//// Horizontal scrolling stock symbol selector
//struct TickerView: View {
//    let symbols: [String]                    // Array of stock symbols to display
//    @Binding var selectedSymbol: String      // Currently selected symbol (two-way binding)
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {  // Horizontal scroll without scroll indicators
//            HStack(spacing: 12) {  // Horizontal stack with consistent spacing
//                ForEach(symbols, id: \.self) { symbol in
//                    Text(symbol)
//                        .font(.callout)
//                        .fontWeight(.medium)
//                        .padding(.horizontal, 16)
//                        .padding(.vertical, 8)
//                        .background(
//                            RoundedRectangle(cornerRadius: 10)
//                                .fill(symbol == selectedSymbol
//                                      ? Color.blue.opacity(0.8)    // Highlighted background for selected symbol
//                                      : Color.gray.opacity(0.25))   // Subtle background for unselected symbols
//                        )
//                        .foregroundColor(.white)
//                        .onTapGesture {
//                            withAnimation { selectedSymbol = symbol }  // Update selection with animation
//                        }
//                }
//            }
//            .padding(.horizontal)  // Padding on sides for edge spacing
//            .padding(.vertical, 8) // Padding on top/bottom
//        }
//        .background(Color.black.opacity(LayoutConstants.topBarOpacity)) 
//    }
//}
//
//// MARK: - Chart View Placeholder
//// Placeholder chart view - replace with actual chart implementation
//struct ChartView: View {
//    let symbol: String  // Stock symbol to display chart for
//    
//    var body: some View {
//        VStack {
//            Text("Chart for \(symbol)")  // Placeholder text showing current symbol
//                .foregroundColor(.white)
//                .bold()
//        }
//        
//    }
//}
//
//// MARK: - Bottom Sheet
//// Native iOS bottom sheet for additional information and controls
//
//struct BottomSheetView: View {
//    var body: some View {
//        VStack(spacing: 0) {
//            // Simple top border line
//            
//            
//            // Main content
//            VStack(spacing: 16) {
//                Text("Chart Info")
//                    .font(.title2)
//                    .fontWeight(.semibold)
//                    .foregroundStyle(.primary)
//                    .padding(.top, 20)
//                
//                Text("Additional chart details and controls would go here.")
//                    .font(.body)
//                    .foregroundStyle(.secondary)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal)
//                
//                Spacer()
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//    }
//}



//#Preview {
//    RootView()
//}



