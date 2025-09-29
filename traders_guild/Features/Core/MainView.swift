//
//  MainView.swift
//  traders_guild
//
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
    @State private var selectedDetent: PresentationDetent = .fraction(0.1)
    
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
            // MARK: - Background Layer
            /// Gradient background that fills the entire screen
            backgroundGradient
            
            // MARK: - Main Content Layer
            /// Chart content with fade-in animation
            /// Disabled when drawers are open to prevent interaction conflicts
            mainContentStack
                .disabled(showLeftDrawer || showRightDrawer)
                .opacity(fadeIn ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: fadeIn)
            
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
        }
        .ignoresSafeArea()
        
        // MARK: - Bottom Sheet
        /// Native bottom sheet using Apple's .sheet modifier
        /// Conditionally hidden when drawers are open to prevent layering conflicts
        .sheet(isPresented: .constant(showBottomSheet && !showLeftDrawer && !showRightDrawer)) {
            ChartBottomSheet()
                .presentationDetents([.fraction(0.1), .fraction(0.5), .fraction(0.9)],
                                      selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled(true)
                .presentationContentInteraction(.resizes)
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
    
    /// Gradient background that covers the entire screen
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [AppColors.gradientBackgroundDark, AppColors.gradientBackgroundDark],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    /// Main content stack containing toolbar and chart
    private var mainContentStack: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    chartView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                // MARK: - Guild/App Level Toolbar
                /// These buttons open drawers for guild-wide functionality
                
                // Left Drawer Button (Security/Settings)
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarIconButton(
                        systemName: "shield.pattern.checkered",
                        backgroundTint: AppColors.accentDarkColor.opacity(0.5),
                        fontType: .headline,
                        symbolRenderingMode: .monochrome,
                        foregroundStyle: AppColors.whiteText,
                        padding: 8
                    ) {
                        withAnimation(AnimationConstants.standard) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarIconButton(
                        systemName: "person.2.fill",
                        backgroundTint: AppColors.unhighlightedTextBoxBackground.opacity(0.5),
                        fontType: .subheadline,
                        symbolRenderingMode: .monochrome,
                        foregroundStyle: AppColors.whiteText,
                        padding: 8
                    ) {
                        withAnimation(AnimationConstants.standard) {
                            showRightDrawer.toggle()
                            showLeftDrawer = false
                            showOverlay = showRightDrawer
                        }
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
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
                }
                // Delay hiding overlay to allow smooth fade-out animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showOverlay = false
                }
            }
    }
    
    /// Left drawer view with swipe-to-dismiss functionality
    private var leftDrawerView: some View {
        HStack(spacing: 0) {
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

// MARK: - Drawer View
/// Individual drawer view with content and close functionality
/// Uses translucent material for modern iOS glass effect
struct DrawerView: View {
    let side: DrawerSide
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with title and close button
            HStack {
                Text(side == .left ? "Guild Settings" : "Friends & Guild")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    withAnimation(AnimationConstants.standard) { onClose() }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .padding(.bottom, 8)
            .padding(.top, 60)
            
            // Placeholder content area
            ScrollView {
                VStack(spacing: 16) {
                    Text("Drawer content goes here")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    // Add your drawer-specific content here
                    ForEach(1...10, id: \.self) { index in
                        HStack {
                            Text("Item \(index)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)  // Translucent glass effect - lighter than ultraThinMaterial
        .clipShape(
            // Custom corner rounding - only round corners opposite to the edge
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: side == .left ? 0 : LayoutConstants.cornerRadius,
                    bottomLeading: side == .left ? 0 : LayoutConstants.cornerRadius,
                    bottomTrailing: side == .left ? LayoutConstants.cornerRadius : 0,
                    topTrailing: side == .left ? LayoutConstants.cornerRadius : 0
                )
            )
        )
        .shadow(radius: LayoutConstants.shadowRadius)
        .ignoresSafeArea()
    }
}

// MARK: - Chart Bottom Sheet
/// Main chart interface hub containing all chart-related functionality
struct ChartBottomSheet: View {
    @State private var selectedView: ChartView = .info
    
    enum ChartView: String, CaseIterable {
        case info = "Info"
        case chat = "Chat"
        case timeframes = "Time"
        case tools = "Tools"
        
        var icon: String {
            switch self {
            case .info: return "chart.bar.fill"
            case .chat: return "message.fill"
            case .timeframes: return "clock.fill"
            case .tools: return "wrench.and.screwdriver.fill"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Content Area (only visible when sheet is pulled up)
                if geometry.size.height > 100 {
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedView {
                            case .info:
                                chartInfoContent
                            case .chat:
                                chatContent
                            case .timeframes:
                                timeframesContent
                            case .tools:
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
                    if geometry.size.height > 100 {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 0.5)
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 8) {
                        ForEach(ChartView.allCases, id: \.self) { view in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedView = view
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: view.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(selectedView == view ? .blue : .gray)
                                    
                                    Text(view.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedView == view ? .blue : .gray)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedView == view ? Color.blue.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                }
                .frame(height: geometry.size.height > 100 ? 60 : 58)
            }
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
    
    private var timeframesContent: some View {
        VStack(spacing: 16) {
            Text("Select Timeframe")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(["1m", "5m", "15m", "1h", "4h", "1D", "1W", "1M"], id: \.self) { timeframe in
                    Button(timeframe) { }
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(timeframe == "1D" ? Color.blue : Color.white.opacity(0.1))
                    )
                    .foregroundColor(.white)
                    .fontWeight(.medium)
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
}

