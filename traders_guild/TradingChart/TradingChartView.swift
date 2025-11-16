import SwiftUI

/// Main trading chart view that handles all chart rendering and interactions
/// Features centered scaling that keeps visible candles in view during zoom
/// Includes marker placement system for collaborative chart annotations
struct TradingChartView: View {
    // MARK: - State Properties
    
    /// Gesture state manager that handles all pan/zoom transformations
    /// This is the single source of truth for chart positioning
    @StateObject private var gestureState = ChartGestureState()
    
    /// Current drag translation for smooth real-time panning feedback
    /// This is a @GestureState so it automatically resets when gesture ends
    @GestureState private var dragState: CGSize = .zero
    
    /// Current pinch scale for smooth real-time horizontal zoom feedback
    /// Dampened and combined with stored scale for natural feel
    @GestureState private var pinchScale: CGFloat = 1.0
    
    /// Y-axis pinch scale for vertical price range scaling
    @GestureState private var yAxisPinchScale: CGFloat = 1.0
    
    /// Track if user is currently dragging on the Y-axis area
    /// Prevents interference between Y-axis drag and normal chart pan
    @State private var isDraggingOnYAxis = false
    
    /// Track if user is currently pinching on the Y-axis area
    /// Prevents interference between Y-axis pinch and normal chart horizontal zoom
    @State private var isPinchingOnYAxis = false
    
    /// Starting Y position when beginning Y-axis drag
    /// Used to calculate relative drag distance for scaling
    @State private var yAxisDragStart: CGFloat = 0
    
    /// The price scale value when starting Y-axis drag
    /// Used as baseline for relative scaling calculations
    @State private var initialPriceScale: CGFloat = 1.0
    
    /// Track the center of visible candles for centered scaling operations
    @State private var visibleCandlesCenter: CGFloat = 0
    
    // MARK: - Overlay Managers
    
    /// Manages all markers on the chart (creation, deletion, filtering)
    @StateObject private var markerManager: MarkerManager
    
    /// Manages crosshair functionality for price inspection
    /// Activated by long press, allows precise price/time reading
    @StateObject private var crosshairManager = CrosshairManager()
    
    /// Manages chart navigation controls (auto-scroll, jump to latest, etc)
    @StateObject private var navigationManager = ChartNavigationManager()
    
    // MARK: - UI State
    
    /// Whether the marker creation sheet is currently showing
    @State private var showMarkerSheet = false
    
    /// Whether we're in marker placement mode (user is positioning new marker)
    /// When true, drag gestures move the preview marker instead of panning chart
    @State private var isMarkerPlacementMode = false
    
    /// Track if marker is actively being dragged (for scale animation)
    @State private var isMarkerBeingDragged = false
    
    /// Haptic feedback generator for marker interactions
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    /// Temporary storage for marker info before final creation
    /// Contains candle index, timestamp, and price of pending marker
    @State private var pendingMarkerInfo: (candleIndex: Int, timestamp: Date, price: Double)?
    
    /// Current candle index where the preview marker is positioned
    /// Updates in real-time as user drags during placement mode
    @State private var previewCandleIndex: Int = 0
    
    /// Track the actual drag position for free-form marker movement
    /// This allows marker to follow finger in 2D before snapping on release
    @State private var markerDragPosition: CGPoint?
    
    /// Prevents multiple sheet presentations when user taps rapidly
    @State private var isShowingSheet = false
    
    // MARK: - Chart Configuration
    
    /// Base width of each candle before any scaling is applied
    /// This is the "normal" candle width at 1x zoom
    private let baseCandleWidth: CGFloat = 12
    
    /// Spacing between adjacent candles
    /// Creates visual separation for readability
    private let candleSpacing: CGFloat = 4
    
    /// Edge padding to prevent endless scrolling
    /// Provides buffer space at chart boundaries
    private let edgePadding: CGFloat = 100
    
    /// Width of the Y-axis interaction area on the right side
    /// This area captures vertical drag/pinch gestures for price scaling
    private let yAxisWidth: CGFloat = 60
    
    /// Chart data manager that generates and maintains candlestick data
    /// Handles real-time data generation and price range calculations
    @StateObject private var chartData = ChartDataManager()
    
    // MARK: - Sensitivity Configuration
    
    /// Dampening factor for horizontal pinch gesture (0.0 to 1.0)
    /// Lower = less sensitive and smoother, Higher = more responsive but jittery
    /// 0.15 provides a good balance for production use
    private let pinchSensitivity: CGFloat = 0.1
    
    /// Dampening factor for Y-axis drag scaling (0.0 to 1.0)
    /// Controls how quickly vertical drag changes price scale
    /// 0.15 makes scaling feel controlled and predictable
    private let yAxisSensitivity: CGFloat = 0.15
    
    // MARK: - Computed Properties
    
    /// Actual width of each candle including current zoom scale
    /// Combines base width, stored scale, and active pinch gesture
    /// This is what's actually rendered on screen
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale * pinchScale
    }
    
    /// Total width per candle including spacing
    /// Used for all positioning calculations throughout the chart
    private var totalCandleWidth: CGFloat {
        actualCandleWidth + candleSpacing
    }
    
    /// Calculate clamped vertical offset that respects pan limits
    /// Prevents user from panning too far up or down
    /// Provides natural boundaries to vertical movement
    private func clampedVerticalOffset(chartHeight: CGFloat) -> CGFloat {
        // Combine stored offset with active drag gesture
        let totalOffset = gestureState.verticalPanOffset + dragState.height
        
        // Calculate scaled height to determine valid pan range
        let scaledHeight = chartHeight * gestureState.priceScale
        
        // Allow panning up to 50% of scaled height in either direction
        let verticalPadding = scaledHeight * 0.5
        
        // Clamp the offset to valid range
        return Swift.min(verticalPadding, Swift.max(-verticalPadding, totalOffset))
    }
    
    // MARK: - Initialization
    
    /// Initialize the trading chart view with user and guild context
    /// - Parameters:
    ///   - userId: Current user's ID for marker ownership
    ///   - username: Current user's display name
    ///   - guildId: Guild context for marker filtering
    init(userId: String = "user123", username: String = "TestUser", guildId: String = "guild1") {
        // Initialize marker manager with user context
        _markerManager = StateObject(wrappedValue: MarkerManager(userId: userId, guildId: guildId))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // GeometryReader provides the available chart space
            // This is the canvas we draw everything on
            GeometryReader { geometry in
                // Create coordinate system for converting between screen and chart coordinates
                // This handles all the math for positioning elements correctly
                let coordinateSystem = ChartCoordinateSystem(
                    chartData: chartData,
                    gestureState: gestureState,
                    chartSize: geometry.size,
                    baseCandleWidth: baseCandleWidth,
                    candleSpacing: candleSpacing
                )
                
                // Update coordinate system with live gesture state
                // This ensures real-time accuracy during active gestures
                let _ = coordinateSystem.updateLiveState(dragState: dragState, pinchScale: pinchScale)
                
                ZStack {
                    // Black background for professional trading chart appearance
                    Color.black.ignoresSafeArea()
                    
                    // MAIN CHART CANVAS
                    // Draws: grid, candlesticks, and placed markers
                    // Does NOT draw preview marker (that's a SwiftUI overlay for smooth updates)
                    Canvas { context, size in
                        drawChart(context: context, size: size, geometry: geometry)
                    }
                    .contentShape(Rectangle()) // Make entire canvas tappable/draggable
                    // Only redraw Canvas when markers are added/removed or data changes
                    // NOT when preview is dragging (that's SwiftUI overlay)
                    .id("\(markerManager.markers.count)-\(chartData.candles.count)")
                    
                    // MARKER PLACEMENT OVERLAY
                    // This entire section is SwiftUI (not Canvas) for instant updates
                    // Shows preview marker and handles drag-to-position interaction
                    if isMarkerPlacementMode {
                        ZStack {
                            // VERTICAL GUIDE LINE - shows which candle is selected
                            if previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count {
                                let candle = chartData.candles[previewCandleIndex]
                                let x = coordinateSystem.xCenterPosition(forCandleIndex: previewCandleIndex)
                                
                                if x >= -50 && x <= geometry.size.width + 50 {
                                    // Dashed vertical line from top to bottom
                                    Path { path in
                                        path.move(to: CGPoint(x: x, y: 0))
                                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                                    }
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                    .foregroundColor(.blue.opacity(0.6))
                                    .allowsHitTesting(false)
                                    
                                    // Timestamp label at bottom
                                    Text(candle.timestamp.chartTimeLabel)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                        .position(x: x, y: geometry.size.height - 15)
                                        .allowsHitTesting(false)
                                }
                            }
                            
                            // PREVIEW MARKER - SwiftUI overlay for instant updates
                            // Follows finger position in 2D while dragging, snaps to candle position when released
                            // Only the marker itself is draggable - chart remains fully interactive
                            if previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count {
                                let candle = chartData.candles[previewCandleIndex]
                                
                                // Calculate snap position (above candle)
                                let snapX = coordinateSystem.xCenterPosition(forCandleIndex: previewCandleIndex)
                                let snapY = coordinateSystem.yPosition(forPrice: candle.high) - 50
                                
                                // Use drag position if actively dragging, otherwise use snap position
                                let markerX = markerDragPosition?.x ?? snapX
                                let markerY = markerDragPosition?.y ?? snapY
                                
                                if markerX >= -50 && markerX <= geometry.size.width + 50 {
                                    ZStack {
                                        // EXPANDED HIT AREA - invisible touch target
                                        // Makes marker easier to grab without blocking chart gestures
                                        Circle()
                                            .fill(Color.clear)
                                            .frame(width: 80, height: 80)
                                            .contentShape(Circle())
                                        
                                        // Large blue circle background
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                // White border for visibility
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 3)
                                            )
                                            .scaleEffect(isMarkerBeingDragged ? 1.2 : 1.0)
                                        
                                        // White center dot
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 12, height: 12)
                                            .scaleEffect(isMarkerBeingDragged ? 1.2 : 1.0)
                                        
                                        // Info box showing time and price
                                        VStack(spacing: 2) {
                                            Text(candle.timestamp.chartTimeLabel)
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                            Text(candle.close.formattedPrice)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        }
                                        .padding(4)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                        .offset(y: 40)
                                        .allowsHitTesting(false)
                                    }
                                    .position(x: markerX, y: markerY)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarkerBeingDragged)
                                    .gesture(
                                        // Marker-specific drag gesture - only captures touches on the marker
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                // Trigger haptic on first movement
                                                if !isMarkerBeingDragged {
                                                    isMarkerBeingDragged = true
                                                    impactFeedback.impactOccurred()
                                                }
                                                
                                                // Update marker to follow finger position exactly (2D movement)
                                                markerDragPosition = value.location
                                                
                                                // Update candle index based on X position (for vertical line and final placement)
                                                if let index = coordinateSystem.candleIndex(atXPosition: value.location.x) {
                                                    let clampedIndex = max(0, min(chartData.candles.count - 1, index))
                                                    previewCandleIndex = clampedIndex
                                                }
                                            }
                                            .onEnded { value in
                                                // Stop dragging and snap to position
                                                isMarkerBeingDragged = false
                                                // Clear drag position to trigger snap animation
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                    markerDragPosition = nil
                                                }
                                            }
                                    )
                                }
                            }
                        }
                    }
                    
                    // FIXED Y-AXIS OVERLAY
                    // Shows price labels on the right side
                    // Stays fixed during horizontal panning
                    yAxisOverlay(geometry: geometry)
                    
                    // FIXED X-AXIS OVERLAY
                    // Shows time labels at the bottom
                    // Moves with horizontal pan to stay aligned with candles
                    xAxisOverlay(geometry: geometry)
                    
                    // Y-AXIS INTERACTION OVERLAY
                    // Invisible overlay on right side that captures vertical scaling gestures
                    // Allows users to drag/pinch on Y-axis to scale price range
                    HStack {
                        Spacer()
                        Color.clear
                            .frame(width: yAxisWidth)
                            .contentShape(Rectangle())
                            .highPriorityGesture(yAxisDragGesture)
                            .highPriorityGesture(yAxisPinchGesture)
                    }
                    
                    // PRICE INDICATOR
                    // Shows current/latest price with animated movement
                    // Follows price changes in real-time
                    PriceIndicatorView(
                        currentPrice: chartData.currentPrice,
                        priceScale: gestureState.priceScale,
                        verticalOffset: clampedVerticalOffset(chartHeight: geometry.size.height),
                        chartHeight: geometry.size.height,
                        priceRange: chartData.priceRange
                    )
                    
                    // CROSSHAIR OVERLAY
                    // Activated by long press for precise price inspection
                    // Shows exact price and time at touch location
                    CrosshairView(
                        crosshairManager: crosshairManager,
                        chartSize: geometry.size
                    )
                    
                    // INSTRUCTION BANNER
                    // Shown during marker placement mode
                    // Tells user how to place marker and provides cancel/place buttons
                    if isMarkerPlacementMode {
                        VStack {
                            HStack(spacing: 12) {
                                // Cancel button to exit placement mode
                                Button(action: {
                                    withAnimation {
                                        isMarkerPlacementMode = false
                                        isMarkerBeingDragged = false
                                        markerDragPosition = nil
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
//                                        Text("Cancel")
//                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                }
                                
                                
                                
//                                // Instruction text
//                                Text("Drag marker to position")
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                                    .padding(.horizontal, 16)
//                                    .padding(.vertical, 12)
//                                    .background(Color.blue.opacity(0.9))
//                                    .cornerRadius(12)
//                                
//                                Spacer()
                                
                                // Place button to commit marker placement
                                Button(action: {
                                    // Check if sheet is already showing to prevent duplicates
                                    guard !isShowingSheet else { return }
                                    
                                    // Validate candle index and get timestamp
                                    if let timestamp = coordinateSystem.timestamp(forCandleIndex: previewCandleIndex),
                                       previewCandleIndex >= 0,
                                       previewCandleIndex < chartData.candles.count {
                                        
                                        let candle = chartData.candles[previewCandleIndex]
                                        
                                        // Clear any existing selected marker to prevent conflicts
                                        markerManager.selectedMarker = nil
                                        
                                        // Store marker info for sheet
                                        pendingMarkerInfo = (previewCandleIndex, timestamp, candle.close)
                                        
                                        // Trigger haptic feedback for placement
                                        impactFeedback.impactOccurred()
                                        
                                        // Show creation sheet
                                        isShowingSheet = true
                                        showMarkerSheet = true
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
//                                        Text("Place")
//                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .cornerRadius(12)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 120)
                            Spacer()
                        }
                        .allowsHitTesting(true) // Allow button taps
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // NAVIGATION CONTROLS
                    // Top-right corner controls for auto-scroll, jump to latest, etc.
                    VStack {
                        HStack {
                            Spacer()
                            ChartNavigationControls(
                                navigationManager: navigationManager,
                                gestureState: gestureState,
                                chartData: chartData,
                                chartWidth: geometry.size.width,
                                baseCandleWidth: baseCandleWidth
                            )
                        }
                        Spacer()
                    }
                }
                // GESTURE LAYER
                // These gestures only apply when NOT in marker placement mode
                // Order matters: crosshair has priority, then tap, then pan/zoom
                .gesture(crosshairGesture(coordinateSystem: coordinateSystem))
                .simultaneousGesture(tapGestureForMarkers(geometry: geometry))
                .simultaneousGesture(dragGesture(in: geometry.size))
                .simultaneousGesture(pinchGesture(in: geometry.size))
                
                // BOTTOM TOOLBAR
                // Contains marker placement button and reset zoom button
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        // Marker placement toggle button
                        Button(action: {
                            withAnimation {
                                // Toggle placement mode
                                isMarkerPlacementMode.toggle()
                                
                                if isMarkerPlacementMode {
                                    // Start preview at CENTER of currently visible area
                                    // This ensures marker appears where user is looking
                                    previewCandleIndex = centerCandleIndex(using: coordinateSystem, chartWidth: geometry.size.width)
                                    // Clear drag position so marker starts in snapped position
                                    markerDragPosition = nil
                                    print("📍 Marker placement mode ON - preview at candle \(previewCandleIndex)")
                                } else {
                                    // Clear all marker-related state when exiting
                                    markerDragPosition = nil
                                    isMarkerBeingDragged = false
                                    print("📍 Marker placement mode OFF")
                                }
                            }
                        }) {
                            VStack(spacing: 2) {
                                // Icon changes when placement mode is active
                                Image(systemName: isMarkerPlacementMode ? "mappin.circle.fill" : "mappin.circle")
                                    .font(.system(size: 24))
                                Text("Marker")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(isMarkerPlacementMode ? .blue : .white)
                        
                        // Reset zoom and pan button
                        Button(action: {
                            gestureState.reset()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 24))
                                Text("Reset")
                                    .font(.caption2)
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.bottom, 80)
                }
            }
        }
        // MARKER CREATION SHEET
        // Shows when user releases marker preview
        // Allows user to select marker type and add notes
        .sheet(isPresented: $showMarkerSheet) {
            if let info = pendingMarkerInfo {
                MarkerCreationSheet(
                    markerManager: markerManager,
                    candleIndex: info.candleIndex,
                    timestamp: info.timestamp,
                    price: info.price,
                    username: "TestUser"
                )
                .onDisappear {
                    // Exit placement mode after marker is created or cancelled
                    isMarkerPlacementMode = false
                    isShowingSheet = false
                    markerManager.selectedMarker = nil
                }
            }
        }
        // MARKER DETAIL SHEET
        // Shows when user taps an existing marker
        // Displays marker info and allows editing/deletion for own markers
        .sheet(item: $markerManager.selectedMarker) { marker in
            MarkerDetailSheet(
                markerManager: markerManager,
                marker: marker,
                currentUserId: "user123"
            )
        }
        .onAppear {
            // Start generating real-time candle data when view appears
            chartData.startDataGeneration()
        }
    }
    
    // MARK: - Helper Functions
    
    /// Calculate which candle is at the center of the current visible area
    /// This ensures marker preview starts where the user is actually looking
    /// Uses visible range calculation instead of screen center math
    /// - Parameter geometry: The geometry of the chart view
    /// - Returns: Clamped candle index at the center of visible range
    private func getCenterVisibleCandleIndex(geometry: GeometryProxy) -> Int {
        // Get current pan offset (includes both stored and active drag)
        let totalOffset = gestureState.panOffset.width + dragState.width
        
        // Calculate which candles are currently visible on screen
        // Start index: first candle visible on left edge
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
        
        // End index: last candle visible on right edge (plus buffer)
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            visibleStartIndex + Int(geometry.size.width / totalCandleWidth) + 2
        )
        
        // Return the middle candle of the visible range
        // This is where the user is most likely looking
        let middleIndex = (visibleStartIndex + visibleEndIndex) / 2
        
        // Clamp to valid array bounds
        let clampedIndex = max(0, min(chartData.candles.count - 1, middleIndex))
        
        print("📍 Visible range: \(visibleStartIndex) to \(visibleEndIndex)")
        print("📍 Center candle: \(clampedIndex) of \(chartData.candles.count)")
        
        return clampedIndex
    }
    
    /// Compute the candle index at the actual screen center using the coordinate system
    /// - Parameters:
    ///   - coordinateSystem: The chart coordinate system configured with live gesture state
    ///   - chartWidth: The current width of the chart view
    /// - Returns: A clamped candle index at the screen center
    private func centerCandleIndex(using coordinateSystem: ChartCoordinateSystem, chartWidth: CGFloat) -> Int {
        let centerX = chartWidth / 2
        if let idx = coordinateSystem.candleIndex(atXPosition: centerX) {
            return max(0, min(chartData.candles.count - 1, idx))
        }
        return max(0, min(chartData.candles.count - 1, chartData.candles.count / 2))
    }
    
    // MARK: - Crosshair Gesture
    
    /// Long press gesture for activating crosshair (price inspection tool)
    /// User must hold for 0.5 seconds, then can drag to inspect different prices
    /// - Parameter coordinateSystem: Coordinate converter for screen<->chart mapping
    /// - Returns: Combined long press + drag gesture
    private func crosshairGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    // Long press succeeded, now user is dragging
                    if let location = drag?.location {
                        if !crosshairManager.isActive {
                            // First activation - show crosshair at touch location
                            crosshairManager.activate(
                                at: location,
                                coordinateSystem: coordinateSystem,
                                chartData: chartData
                            )
                        } else {
                            // Already active - update position as user drags
                            crosshairManager.updatePosition(
                                location,
                                coordinateSystem: coordinateSystem,
                                chartData: chartData
                            )
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                // User released - hide crosshair
                crosshairManager.deactivate()
            }
    }
    
    // MARK: - Tap Gesture for Markers
    
    /// Detect taps on existing markers to show their details
    /// Checks if tap location is within 30 points of any marker
    /// Only works when not in crosshair or placement mode
    /// - Parameter geometry: Chart view geometry for position calculations
    /// - Returns: Tap gesture that selects markers
    private func tapGestureForMarkers(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                // Don't handle taps during special modes or when creation sheet is showing
                guard !crosshairManager.isActive && !isMarkerPlacementMode && !showMarkerSheet && !isShowingSheet else { return }
                
                let location = value.location
                
                // Calculate current chart offsets for marker positioning
                let totalOffset = gestureState.panOffset.width + dragState.width
                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
                let scaledHeight = geometry.size.height * gestureState.priceScale
                
                // Check each visible marker to see if it was tapped
                for marker in markerManager.filteredMarkers {
                    // Skip markers with invalid candle indices
                    guard marker.candleIndex < chartData.candles.count else { continue }
                    
                    // Calculate marker's current screen position
                    // Uses same formula as Canvas drawing for perfect alignment
                    let markerX = CGFloat(marker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
                    let candle = chartData.candles[marker.candleIndex]
                    let markerY = geometry.size.height -
                        (CGFloat(candle.high - chartData.priceRange.min) /
                         CGFloat(chartData.priceRange.max - chartData.priceRange.min)) *
                        scaledHeight - totalVerticalOffset - 30
                    
                    // Calculate distance from tap to marker center
                    let distance = hypot(location.x - markerX, location.y - markerY)
                    
                    // If tap is within 30 points, select this marker
                    if distance <= 30 {
                        markerManager.selectedMarker = marker
                        return // Found a marker, stop checking
                    }
                }
            }
    }
    
    // MARK: - Pan Gesture
    
    /// Drag gesture for panning the chart horizontally and vertically
    /// Only active when NOT in Y-axis drag, crosshair, or actively dragging marker
    /// Requires 10pt movement to distinguish from tap gestures
    /// - Parameter size: Chart view size for boundary calculations
    /// - Returns: Pan drag gesture
    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragState) { value, state, _ in
                // Only update drag state if not in special modes or actively dragging marker
                if !isDraggingOnYAxis && !crosshairManager.isActive && !isMarkerBeingDragged {
                    // Reverse vertical direction for natural feel
                    // (drag up = chart moves up, revealing lower prices)
                    state = CGSize(width: value.translation.width, height: -value.translation.height)
                }
            }
            .onEnded { value in
                // Apply final pan position when gesture ends
                if !isDraggingOnYAxis && !crosshairManager.isActive && !isMarkerBeingDragged {
                    let adjustedTranslation = CGSize(
                        width: value.translation.width,
                        height: -value.translation.height
                    )
                    
                    // Update stored pan offset with boundary clamping
                    gestureState.applyPan(
                        translation: adjustedTranslation,
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale
                    )
                }
            }
    }
    
    // MARK: - Pinch Gesture
    
    /// Pinch gesture for horizontal zoom (changes candle width)
    /// Zoom is centered on screen center to keep visible candles in view
    /// Dampened for smooth, controlled zooming
    /// - Parameter size: Chart view size for center calculations
    /// - Returns: Magnification pinch gesture
    private func pinchGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                // Don't zoom during special modes OR when pinching on Y-axis OR actively dragging marker
                guard !crosshairManager.isActive && !isMarkerBeingDragged && !isPinchingOnYAxis else { return }
                
                // Apply dampening to make zoom feel smoother
                // Raw pinch values can be jumpy; dampening smooths them out
                let dampened = 1.0 + (value - 1.0) * pinchSensitivity
                state = dampened
            }
            .onChanged { value in
                guard !crosshairManager.isActive && !isMarkerBeingDragged && !isPinchingOnYAxis else { return }
                
                // Apply dampening
                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                
                // Calculate which candle is at screen center BEFORE zoom
                let screenCenterX = size.width / 2
                let totalOffset = gestureState.panOffset.width + dragState.width
                
                let oldCandleWidth = baseCandleWidth * gestureState.candleWidthScale
                let oldTotalWidth = oldCandleWidth + candleSpacing
                let centerCandleIndex = (screenCenterX - totalOffset) / oldTotalWidth
                let oldCandlePosition = centerCandleIndex * oldTotalWidth + totalOffset
                
                // Apply new zoom level with limits (0.3x to 3x)
                let newScale = gestureState.candleWidthScale * dampenedValue
                let clampedScale = Swift.min(3.0, Swift.max(0.3, newScale))
                
                // Calculate where center candle WOULD BE after zoom
                let newCandleWidth = baseCandleWidth * clampedScale
                let newTotalWidth = newCandleWidth + candleSpacing
                let newCandlePosition = centerCandleIndex * newTotalWidth + totalOffset
                
                // Adjust pan offset to keep center candle at screen center
                // This is what makes the zoom feel "centered" instead of anchored to left
                let offsetAdjustment = oldCandlePosition - newCandlePosition
                gestureState.panOffset.width += offsetAdjustment
                
                // Apply the new scale
                gestureState.candleWidthScale = clampedScale
            }
            .onEnded { _ in }
    }
    
    // MARK: - Y-Axis Gestures
    
    /// Drag gesture on Y-axis area for vertical price scaling
    /// Ignores horizontal drag and zooming state.
    /// Drag up = compress price range (zoom in), Drag down = expand range (zoom out)
    /// Scaling is centered on the middle price of visible candles
    private var yAxisDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Initialize drag tracking on first movement
                if !isDraggingOnYAxis {
                    isDraggingOnYAxis = true
                    yAxisDragStart = value.startLocation.y
                    initialPriceScale = gestureState.priceScale
                }
                
                // Use the chart height and width from screen bounds for calculations
                let chartHeight = UIScreen.main.bounds.height
                let chartWidth = UIScreen.main.bounds.width
                
                // Calculate total horizontal pan offset WITHOUT active horizontal drag to avoid jitter
                let totalOffset = gestureState.panOffset.width
                
                // Calculate visible candle range based on horizontal pan only
                let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
                let visibleEndIndex = Swift.min(
                    chartData.candles.count,
                    visibleStartIndex + Int(chartWidth / totalCandleWidth) + 2
                )
                
                // Extract visible candles to find price range extremes
                let visibleCandles = Array(chartData.candles[visibleStartIndex..<visibleEndIndex])
                let visibleHighs = visibleCandles.map { $0.high }
                let visibleLows = visibleCandles.map { $0.low }
                let visibleMaxPrice = visibleHighs.max() ?? chartData.priceRange.max
                let visibleMinPrice = visibleLows.min() ?? chartData.priceRange.min
                let centerPrice = (visibleMaxPrice + visibleMinPrice) / 2
                
                // Calculate center price position BEFORE scaling
                let oldScaledHeight = chartHeight * gestureState.priceScale
                let priceRange = chartData.priceRange
                let normalizedCenterPrice = (centerPrice - priceRange.min) / (priceRange.max - priceRange.min)
                let centerYBeforeScale = chartHeight -
                    (CGFloat(normalizedCenterPrice) * oldScaledHeight) -
                    gestureState.verticalPanOffset
                
                // Calculate scale factor from drag distance
                // Drag up (negative) = increase scale = compress price range
                let dragDistance = value.location.y - yAxisDragStart
                let scaleFactor = 1.0 - (dragDistance / 500.0) * yAxisSensitivity
                
                // Apply scale with limits (0.5x to 3x)
                let newScale = initialPriceScale * scaleFactor
                let clampedScale = Swift.min(3.0, Swift.max(0.5, newScale))
                
                // Calculate center price position AFTER scaling
                let newScaledHeight = chartHeight * clampedScale
                let centerYAfterScale = chartHeight -
                    (CGFloat(normalizedCenterPrice) * newScaledHeight) -
                    gestureState.verticalPanOffset
                
                // Adjust vertical offset to keep center price at same screen position
                let offsetAdjustment = centerYAfterScale - centerYBeforeScale
                gestureState.verticalPanOffset += offsetAdjustment
                gestureState.priceScale = clampedScale
            }
            .onEnded { _ in
                isDraggingOnYAxis = false
            }
    }
    
    /// Pinch gesture on Y-axis area for vertical price scaling
    /// Ignores horizontal drag and zooming state.
    /// Alternative to drag gesture - uses two-finger pinch
    /// Same centering logic as drag but with pinch input
    private var yAxisPinchGesture: some Gesture {
        MagnificationGesture()
            .updating($yAxisPinchScale) { value, state, _ in
                // Apply dampening for smooth pinch
                let dampened = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
                state = dampened
            }
            .onChanged { value in
                // Mark that we're pinching on Y-axis to block main chart horizontal zoom
                if !isPinchingOnYAxis {
                    isPinchingOnYAxis = true
                }
                
                // Use the chart height and width from screen bounds for calculations
                let chartHeight = UIScreen.main.bounds.height
                let chartWidth = UIScreen.main.bounds.width
                
                // Calculate total horizontal pan offset WITHOUT active horizontal drag to avoid jitter
                let totalOffset = gestureState.panOffset.width
                
                // Calculate visible candle range based on horizontal pan only
                let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
                let visibleEndIndex = Swift.min(
                    chartData.candles.count,
                    visibleStartIndex + Int(chartWidth / totalCandleWidth) + 2
                )
                
                // Extract visible candles to find price range extremes
                let visibleCandles = Array(chartData.candles[visibleStartIndex..<visibleEndIndex])
                let visibleHighs = visibleCandles.map { $0.high }
                let visibleLows = visibleCandles.map { $0.low }
                let visibleMaxPrice = visibleHighs.max() ?? chartData.priceRange.max
                let visibleMinPrice = visibleLows.min() ?? chartData.priceRange.min
                let centerPrice = (visibleMaxPrice + visibleMinPrice) / 2
                
                // Calculate center price position BEFORE scaling
                let oldScaledHeight = chartHeight * gestureState.priceScale
                let priceRange = chartData.priceRange
                let normalizedCenterPrice = (centerPrice - priceRange.min) / (priceRange.max - priceRange.min)
                let centerYBeforeScale = chartHeight -
                    (CGFloat(normalizedCenterPrice) * oldScaledHeight) -
                    gestureState.verticalPanOffset
                
                // Apply dampened scaling factor
                let dampenedValue = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
                let newScale = gestureState.priceScale * dampenedValue
                let clampedScale = Swift.min(3.0, Swift.max(0.5, newScale))
                
                // Calculate center price position AFTER scaling
                let newScaledHeight = chartHeight * clampedScale
                let centerYAfterScale = chartHeight -
                    (CGFloat(normalizedCenterPrice) * newScaledHeight) -
                    gestureState.verticalPanOffset
                
                // Adjust vertical offset to keep center price at same screen position
                let offsetAdjustment = centerYAfterScale - centerYBeforeScale
                gestureState.verticalPanOffset += offsetAdjustment
                gestureState.priceScale = clampedScale
            }
            .onEnded { _ in
                isPinchingOnYAxis = false
            }
    }
    
    // MARK: - Axis Overlays
    
    /// Y-axis overlay showing price labels
    /// Stays fixed on right side while chart pans horizontally
    /// Moves vertically with price scaling
    /// - Parameter geometry: Chart view geometry
    /// - Returns: Y-axis label overlay view
    @ViewBuilder
    private func yAxisOverlay(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            Canvas { context, size in
                let priceRange = chartData.priceRange
                let scaledHeight = geometry.size.height * gestureState.priceScale
                let priceStep = (priceRange.max - priceRange.min) / 10
                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
                
                // Draw 10 evenly-spaced price labels
                for i in 0...10 {
                    let price = priceRange.min + (priceStep * Double(i))
                    let y = size.height -
                        (CGFloat(price - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
                        scaledHeight - totalVerticalOffset
                    
                    // Only draw labels that are visible on screen
                    if y >= -20 && y <= size.height + 20 {
                        context.draw(
                            Text(String(format: "%.2f", price))
                                .font(.system(size: 10))
                                .foregroundColor(.gray),
                            at: CGPoint(x: 30, y: y)
                        )
                    }
                }
            }
            .frame(width: yAxisWidth)
            .background(Color.black.opacity(0.8))
        }
        .allowsHitTesting(false) // Let touches pass through to Y-axis gesture area
    }
    
    /// X-axis overlay showing time labels
    /// Stays fixed at bottom but moves horizontally with pan
    /// Shows time label every 5 candles
    /// - Parameter geometry: Chart view geometry
    /// - Returns: X-axis label overlay view
    @ViewBuilder
    private func xAxisOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            Canvas { context, size in
                let totalOffset = gestureState.panOffset.width + dragState.width
                let labelStride = 5 // Show label every 5 candles
                
                // Draw time labels that move with horizontal pan
                for i in stride(from: 0, to: chartData.candles.count, by: labelStride) {
                    let x = CGFloat(i) * totalCandleWidth + totalOffset
                    
                    // Only draw labels that are visible on screen
                    if x >= -50 && x <= size.width + 50 {
                        let candle = chartData.candles[i]
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        let timeText = formatter.string(from: candle.timestamp)
                        
                        context.draw(
                            Text(timeText)
                                .font(.system(size: 10))
                                .foregroundColor(.gray),
                            at: CGPoint(x: x + actualCandleWidth / 2, y: 10)
                        )
                    }
                }
            }
            .frame(height: 20)
            .background(Color.black.opacity(0.8))
            .padding(.bottom, geometry.size.height * 0.11 + 10)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Chart Drawing
    
    /// Main chart drawing coordinator
    /// Calls individual drawing methods in correct order (back to front)
    /// Draws: grid, candlesticks, placed markers (NOT preview)
    /// - Parameters:
    ///   - context: Graphics context for drawing
    ///   - size: Canvas size
    ///   - geometry: View geometry
    private func drawChart(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        var drawingContext = context
        
        // Clip drawing to chart bounds
        drawingContext.clip(to: Path(CGRect(origin: .zero, size: size)))
        
        // Calculate current offsets for all positioning
        let totalOffset = gestureState.panOffset.width + dragState.width
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
        
        // Draw components in order (back to front)
        drawGrid(context: drawingContext, size: size)
        drawCandlesticks(context: drawingContext, size: size)
        
        // Draw placed markers (NOT preview - that's SwiftUI overlay)
        // Uses EXACT same positioning math as candlesticks for perfect alignment
        ChartMarkerSystem.drawMarkers(
            context: drawingContext,
            markers: markerManager.filteredMarkers,
            candles: chartData.candles,
            chartSize: size,
            priceRange: chartData.priceRange,
            priceScale: gestureState.priceScale,
            verticalOffset: totalVerticalOffset,
            totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth,
            totalOffset: totalOffset
        )
    }
    
    /// Draw background grid for visual reference
    /// Vertical lines every 5 candles, horizontal lines every 10% of price range
    /// - Parameters:
    ///   - context: Graphics context
    ///   - size: Canvas size
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridPath = Path { path in
            // Vertical grid lines (aligned with time)
            let verticalSpacing = totalCandleWidth * 5
            let totalOffset = gestureState.panOffset.width + dragState.width
            
            // Calculate starting position for seamless grid during pan
            var x = totalOffset.truncatingRemainder(dividingBy: verticalSpacing)
            if x > 0 { x -= verticalSpacing }
            
            // Draw vertical lines across entire height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += verticalSpacing
            }
            
            // Horizontal grid lines (aligned with price)
            let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
            let scaledHeight = size.height * gestureState.priceScale
            let horizontalSpacing = scaledHeight / 10
            
            // Calculate starting position for seamless grid during vertical pan
            var y = -totalVerticalOffset.truncatingRemainder(dividingBy: horizontalSpacing)
            if y > 0 { y -= horizontalSpacing }
            
            // Draw horizontal lines across entire width
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += horizontalSpacing
            }
        }
        
        // Draw grid with subtle gray color
        context.stroke(gridPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
    }
    
    /// Draw candlesticks - the main chart content
    /// Only draws visible candles for performance
    /// Green = bullish (close >= open), Red = bearish (close < open)
    /// - Parameters:
    ///   - context: Graphics context
    ///   - size: Canvas size
    private func drawCandlesticks(context: GraphicsContext, size: CGSize) {
        let priceRange = chartData.priceRange
        let scaledHeight = size.height * gestureState.priceScale
        let totalOffset = gestureState.panOffset.width + dragState.width
        
        // Calculate visible candle range for performance
        // Only draw candles that are actually on screen
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            visibleStartIndex + Int(size.width / totalCandleWidth) + 3
        )
        
        // Draw each visible candle
        for i in visibleStartIndex..<visibleEndIndex {
            guard i < chartData.candles.count else { continue }
            
            let candle = chartData.candles[i]
            
            // Calculate X position
            // This is the EXACT formula used for marker positioning
            let x = CGFloat(i) * totalCandleWidth + totalOffset
            
            // Skip if definitely outside visible area (optimization)
            if x < -totalCandleWidth || x > size.width + totalCandleWidth {
                continue
            }
            
            // Calculate Y positions for OHLC values
            let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
            let highY = size.height -
                (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
                scaledHeight - totalVerticalOffset
            let lowY = size.height -
                (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
                scaledHeight - totalVerticalOffset
            let openY = size.height -
                (CGFloat(candle.open - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
                scaledHeight - totalVerticalOffset
            let closeY = size.height -
                (CGFloat(candle.close - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
                scaledHeight - totalVerticalOffset
            
            // Determine candle color based on price movement
            let candleColor = candle.close >= candle.open ? Color.green : Color.red
            
            // Draw wick (thin line from high to low)
            let wickPath = Path { path in
                path.move(to: CGPoint(x: x + actualCandleWidth / 2, y: highY))
                path.addLine(to: CGPoint(x: x + actualCandleWidth / 2, y: lowY))
            }
            context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)
            
            // Draw body (rectangle from open to close)
            let bodyRect = CGRect(
                x: x,
                y: Swift.min(openY, closeY),
                width: actualCandleWidth,
                height: Swift.max(1, abs(closeY - openY)) // Min height of 1 for doji candles
            )
            
            if candle.close >= candle.open {
                // Bullish candle - hollow with green outline
                context.stroke(
                    Path(roundedRect: bodyRect, cornerRadius: 0),
                    with: .color(candleColor),
                    lineWidth: 1
                )
                context.fill(
                    Path(roundedRect: bodyRect, cornerRadius: 0),
                    with: .color(candleColor.opacity(0.3))
                )
            } else {
                // Bearish candle - solid red fill
                context.fill(
                    Path(roundedRect: bodyRect, cornerRadius: 0),
                    with: .color(candleColor)
                )
            }
        }
    }
}

//import SwiftUI
//
///// Main trading chart view that handles all chart rendering and interactions
///// Features centered scaling that keeps visible candles in view during zoom
///// Includes marker placement system for collaborative chart annotations
//struct TradingChartView: View {
//    // MARK: - State Properties
//    
//    /// Gesture state manager that handles all pan/zoom transformations
//    /// This is the single source of truth for chart positioning
//    @StateObject private var gestureState = ChartGestureState()
//    
//    /// Current drag translation for smooth real-time panning feedback
//    /// This is a @GestureState so it automatically resets when gesture ends
//    @GestureState private var dragState: CGSize = .zero
//    
//    /// Current pinch scale for smooth real-time horizontal zoom feedback
//    /// Dampened and combined with stored scale for natural feel
//    @GestureState private var pinchScale: CGFloat = 1.0
//    
//    /// Y-axis pinch scale for vertical price range scaling
//    @GestureState private var yAxisPinchScale: CGFloat = 1.0
//    
//    /// Track if user is currently dragging on the Y-axis area
//    /// Prevents interference between Y-axis drag and normal chart pan
//    @State private var isDraggingOnYAxis = false
//    
//    /// Track if user is currently pinching on the Y-axis area
//    /// Prevents interference between Y-axis pinch and normal chart horizontal zoom
//    @State private var isPinchingOnYAxis = false
//    
//    /// Starting Y position when beginning Y-axis drag
//    /// Used to calculate relative drag distance for scaling
//    @State private var yAxisDragStart: CGFloat = 0
//    
//    /// The price scale value when starting Y-axis drag
//    /// Used as baseline for relative scaling calculations
//    @State private var initialPriceScale: CGFloat = 1.0
//    
//    /// Track the center of visible candles for centered scaling operations
//    @State private var visibleCandlesCenter: CGFloat = 0
//    
//    // MARK: - Overlay Managers
//    
//    /// Manages all markers on the chart (creation, deletion, filtering)
//    @StateObject private var markerManager: MarkerManager
//    
//    /// Manages crosshair functionality for price inspection
//    /// Activated by long press, allows precise price/time reading
//    @StateObject private var crosshairManager = CrosshairManager()
//    
//    /// Manages chart navigation controls (auto-scroll, jump to latest, etc)
//    @StateObject private var navigationManager = ChartNavigationManager()
//    
//    // MARK: - UI State
//    
//    /// Whether the marker creation sheet is currently showing
//    @State private var showMarkerSheet = false
//    
//    /// Whether we're in marker placement mode (user is positioning new marker)
//    /// When true, drag gestures move the preview marker instead of panning chart
//    @State private var isMarkerPlacementMode = false
//    
//    /// Track if marker is actively being dragged (for scale animation)
//    @State private var isMarkerBeingDragged = false
//    
//    /// Haptic feedback generator for marker interactions
//    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
//    
//    /// Temporary storage for marker info before final creation
//    /// Contains candle index, timestamp, and price of pending marker
//    @State private var pendingMarkerInfo: (candleIndex: Int, timestamp: Date, price: Double)?
//    
//    /// Current candle index where the preview marker is positioned
//    /// Updates in real-time as user drags during placement mode
//    @State private var previewCandleIndex: Int = 0
//    
//    /// Track the actual drag position for free-form marker movement
//    /// This allows marker to follow finger in 2D before snapping on release
//    @State private var markerDragPosition: CGPoint?
//    
//    /// Prevents multiple sheet presentations when user taps rapidly
//    @State private var isShowingSheet = false
//    
//    // MARK: - Chart Configuration
//    
//    /// Base width of each candle before any scaling is applied
//    /// This is the "normal" candle width at 1x zoom
//    private let baseCandleWidth: CGFloat = 12
//    
//    /// Spacing between adjacent candles
//    /// Creates visual separation for readability
//    private let candleSpacing: CGFloat = 4
//    
//    /// Edge padding to prevent endless scrolling
//    /// Provides buffer space at chart boundaries
//    private let edgePadding: CGFloat = 100
//    
//    /// Width of the Y-axis interaction area on the right side
//    /// This area captures vertical drag/pinch gestures for price scaling
//    private let yAxisWidth: CGFloat = 60
//    
//    /// Chart data manager that generates and maintains candlestick data
//    /// Handles real-time data generation and price range calculations
//    @StateObject private var chartData = ChartDataManager()
//    
//    // MARK: - Sensitivity Configuration
//    
//    /// Dampening factor for horizontal pinch gesture (0.0 to 1.0)
//    /// Lower = less sensitive and smoother, Higher = more responsive but jittery
//    /// 0.15 provides a good balance for production use
//    private let pinchSensitivity: CGFloat = 0.15
//    
//    /// Dampening factor for Y-axis drag scaling (0.0 to 1.0)
//    /// Controls how quickly vertical drag changes price scale
//    /// 0.15 makes scaling feel controlled and predictable
//    private let yAxisSensitivity: CGFloat = 0.15
//    
//    // MARK: - Computed Properties
//    
//    /// Actual width of each candle including current zoom scale
//    /// Combines base width, stored scale, and active pinch gesture
//    /// This is what's actually rendered on screen
//    private var actualCandleWidth: CGFloat {
//        baseCandleWidth * gestureState.candleWidthScale * pinchScale
//    }
//    
//    /// Total width per candle including spacing
//    /// Used for all positioning calculations throughout the chart
//    private var totalCandleWidth: CGFloat {
//        actualCandleWidth + candleSpacing
//    }
//    
//    /// Calculate clamped vertical offset that respects pan limits
//    /// Prevents user from panning too far up or down
//    /// Provides natural boundaries to vertical movement
//    private func clampedVerticalOffset(chartHeight: CGFloat) -> CGFloat {
//        // Combine stored offset with active drag gesture
//        let totalOffset = gestureState.verticalPanOffset + dragState.height
//        
//        // Calculate scaled height to determine valid pan range
//        let scaledHeight = chartHeight * gestureState.priceScale
//        
//        // Allow panning up to 50% of scaled height in either direction
//        let verticalPadding = scaledHeight * 0.5
//        
//        // Clamp the offset to valid range
//        return Swift.min(verticalPadding, Swift.max(-verticalPadding, totalOffset))
//    }
//    
//    // MARK: - Initialization
//    
//    /// Initialize the trading chart view with user and guild context
//    /// - Parameters:
//    ///   - userId: Current user's ID for marker ownership
//    ///   - username: Current user's display name
//    ///   - guildId: Guild context for marker filtering
//    init(userId: String = "user123", username: String = "TestUser", guildId: String = "guild1") {
//        // Initialize marker manager with user context
//        _markerManager = StateObject(wrappedValue: MarkerManager(userId: userId, guildId: guildId))
//    }
//    
//    // MARK: - Body
//    
//    var body: some View {
//        ZStack {
//            // GeometryReader provides the available chart space
//            // This is the canvas we draw everything on
//            GeometryReader { geometry in
//                // Create coordinate system for converting between screen and chart coordinates
//                // This handles all the math for positioning elements correctly
//                let coordinateSystem = ChartCoordinateSystem(
//                    chartData: chartData,
//                    gestureState: gestureState,
//                    chartSize: geometry.size,
//                    baseCandleWidth: baseCandleWidth,
//                    candleSpacing: candleSpacing
//                )
//                
//                // Update coordinate system with live gesture state
//                // This ensures real-time accuracy during active gestures
//                let _ = coordinateSystem.updateLiveState(dragState: dragState, pinchScale: pinchScale)
//                
//                ZStack {
//                    // Black background for professional trading chart appearance
//                    Color.black.ignoresSafeArea()
//                    
//                    // MAIN CHART CANVAS
//                    // Draws: grid, candlesticks, and placed markers
//                    // Does NOT draw preview marker (that's a SwiftUI overlay for smooth updates)
//                    Canvas { context, size in
//                        drawChart(context: context, size: size, geometry: geometry)
//                    }
//                    .contentShape(Rectangle()) // Make entire canvas tappable/draggable
//                    // Only redraw Canvas when markers are added/removed or data changes
//                    // NOT when preview is dragging (that's SwiftUI overlay)
//                    .id("\(markerManager.markers.count)-\(chartData.candles.count)")
//                    
//                    // MARKER PLACEMENT OVERLAY
//                    // This entire section is SwiftUI (not Canvas) for instant updates
//                    // Shows preview marker and handles drag-to-position interaction
//                    if isMarkerPlacementMode {
//                        ZStack {
//                            // VERTICAL GUIDE LINE - shows which candle is selected
//                            if previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count {
//                                let candle = chartData.candles[previewCandleIndex]
//                                let x = coordinateSystem.xCenterPosition(forCandleIndex: previewCandleIndex)
//                                
//                                if x >= -50 && x <= geometry.size.width + 50 {
//                                    // Dashed vertical line from top to bottom
//                                    Path { path in
//                                        path.move(to: CGPoint(x: x, y: 0))
//                                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
//                                    }
//                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
//                                    .foregroundColor(.blue.opacity(0.6))
//                                    .allowsHitTesting(false)
//                                    
//                                    // Timestamp label at bottom
//                                    Text(candle.timestamp.chartTimeLabel)
//                                        .font(.caption)
//                                        .fontWeight(.semibold)
//                                        .foregroundColor(.white)
//                                        .padding(.horizontal, 8)
//                                        .padding(.vertical, 4)
//                                        .background(Color.blue)
//                                        .cornerRadius(6)
//                                        .position(x: x, y: geometry.size.height - 15)
//                                        .allowsHitTesting(false)
//                                }
//                            }
//                            
//                            // PREVIEW MARKER - SwiftUI overlay for instant updates
//                            // Follows finger position in 2D while dragging, snaps to candle position when released
//                            // Only the marker itself is draggable - chart remains fully interactive
//                            if previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count {
//                                let candle = chartData.candles[previewCandleIndex]
//                                
//                                // Calculate snap position (above candle)
//                                let snapX = coordinateSystem.xCenterPosition(forCandleIndex: previewCandleIndex)
//                                let snapY = coordinateSystem.yPosition(forPrice: candle.high) - 50
//                                
//                                // Use drag position if actively dragging, otherwise use snap position
//                                let markerX = markerDragPosition?.x ?? snapX
//                                let markerY = markerDragPosition?.y ?? snapY
//                                
//                                if markerX >= -50 && markerX <= geometry.size.width + 50 {
//                                    ZStack {
//                                        // EXPANDED HIT AREA - invisible touch target
//                                        // Makes marker easier to grab without blocking chart gestures
//                                        Circle()
//                                            .fill(Color.clear)
//                                            .frame(width: 80, height: 80)
//                                            .contentShape(Circle())
//                                        
//                                        // Large blue circle background
//                                        Circle()
//                                            .fill(Color.blue)
//                                            .frame(width: 40, height: 40)
//                                            .overlay(
//                                                // White border for visibility
//                                                Circle()
//                                                    .stroke(Color.white, lineWidth: 3)
//                                            )
//                                            .scaleEffect(isMarkerBeingDragged ? 1.2 : 1.0)
//                                        
//                                        // White center dot
//                                        Circle()
//                                            .fill(Color.white)
//                                            .frame(width: 12, height: 12)
//                                            .scaleEffect(isMarkerBeingDragged ? 1.2 : 1.0)
//                                        
//                                        // Info box showing time and price
//                                        VStack(spacing: 2) {
//                                            Text(candle.timestamp.chartTimeLabel)
//                                                .font(.caption2)
//                                                .foregroundColor(.white)
//                                            Text(candle.close.formattedPrice)
//                                                .font(.caption)
//                                                .fontWeight(.bold)
//                                                .foregroundColor(.white)
//                                        }
//                                        .padding(4)
//                                        .background(Color.blue)
//                                        .cornerRadius(4)
//                                        .offset(y: 40)
//                                        .allowsHitTesting(false)
//                                    }
//                                    .position(x: markerX, y: markerY)
//                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarkerBeingDragged)
//                                    .gesture(
//                                        // Marker-specific drag gesture - only captures touches on the marker
//                                        DragGesture(minimumDistance: 0)
//                                            .onChanged { value in
//                                                // Trigger haptic on first movement
//                                                if !isMarkerBeingDragged {
//                                                    isMarkerBeingDragged = true
//                                                    impactFeedback.impactOccurred()
//                                                }
//                                                
//                                                // Update marker to follow finger position exactly (2D movement)
//                                                markerDragPosition = value.location
//                                                
//                                                // Update candle index based on X position (for vertical line and final placement)
//                                                if let index = coordinateSystem.candleIndex(atXPosition: value.location.x) {
//                                                    let clampedIndex = max(0, min(chartData.candles.count - 1, index))
//                                                    previewCandleIndex = clampedIndex
//                                                }
//                                            }
//                                            .onEnded { value in
//                                                // Stop dragging and snap to position
//                                                isMarkerBeingDragged = false
//                                                // Clear drag position to trigger snap animation
//                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
//                                                    markerDragPosition = nil
//                                                }
//                                            }
//                                    )
//                                }
//                            }
//                        }
//                    }
//                    
//                    // FIXED Y-AXIS OVERLAY
//                    // Shows price labels on the right side
//                    // Stays fixed during horizontal panning
//                    yAxisOverlay(geometry: geometry)
//                    
//                    // FIXED X-AXIS OVERLAY
//                    // Shows time labels at the bottom
//                    // Moves with horizontal pan to stay aligned with candles
//                    xAxisOverlay(geometry: geometry)
//                    
//                    // Y-AXIS INTERACTION OVERLAY
//                    // Invisible overlay on right side that captures vertical scaling gestures
//                    // Allows users to drag/pinch on Y-axis to scale price range
//                    HStack {
//                        Spacer()
//                        Color.clear
//                            .frame(width: yAxisWidth)
//                            .contentShape(Rectangle())
//                            .highPriorityGesture(yAxisDragGesture)
//                            .highPriorityGesture(yAxisPinchGesture)
//                    }
//                    
//                    // PRICE INDICATOR
//                    // Shows current/latest price with animated movement
//                    // Follows price changes in real-time
//                    PriceIndicatorView(
//                        currentPrice: chartData.currentPrice,
//                        priceScale: gestureState.priceScale,
//                        verticalOffset: clampedVerticalOffset(chartHeight: geometry.size.height),
//                        chartHeight: geometry.size.height,
//                        priceRange: chartData.priceRange
//                    )
//                    
//                    // CROSSHAIR OVERLAY
//                    // Activated by long press for precise price inspection
//                    // Shows exact price and time at touch location
//                    CrosshairView(
//                        crosshairManager: crosshairManager,
//                        chartSize: geometry.size
//                    )
//                    
//                    // INSTRUCTION BANNER
//                    // Shown during marker placement mode
//                    // Tells user how to place marker and provides cancel/place buttons
//                    if isMarkerPlacementMode {
//                        VStack {
//                            HStack(spacing: 12) {
//                                // Cancel button to exit placement mode
//                                Button(action: {
//                                    withAnimation {
//                                        isMarkerPlacementMode = false
//                                        isMarkerBeingDragged = false
//                                        markerDragPosition = nil
//                                    }
//                                }) {
//                                    HStack(spacing: 6) {
//                                        Image(systemName: "xmark.circle.fill")
//                                            .font(.system(size: 22))
//                                        Text("Cancel")
//                                            .font(.headline)
//                                    }
//                                    .foregroundColor(.white)
//                                    .padding(.horizontal, 16)
//                                    .padding(.vertical, 12)
//                                    .background(Color.red)
//                                    .cornerRadius(12)
//                                }
//                                
//                                Spacer()
//                                
//                                // Instruction text
//                                Text("Drag marker to position")
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                                    .padding(.horizontal, 16)
//                                    .padding(.vertical, 12)
//                                    .background(Color.blue.opacity(0.9))
//                                    .cornerRadius(12)
//                                
//                                Spacer()
//                                
//                                // Place button to commit marker placement
//                                Button(action: {
//                                    // Check if sheet is already showing to prevent duplicates
//                                    guard !isShowingSheet else { return }
//                                    
//                                    // Validate candle index and get timestamp
//                                    if let timestamp = coordinateSystem.timestamp(forCandleIndex: previewCandleIndex),
//                                       previewCandleIndex >= 0,
//                                       previewCandleIndex < chartData.candles.count {
//                                        
//                                        let candle = chartData.candles[previewCandleIndex]
//                                        
//                                        // Clear any existing selected marker to prevent conflicts
//                                        markerManager.selectedMarker = nil
//                                        
//                                        // Store marker info for sheet
//                                        pendingMarkerInfo = (previewCandleIndex, timestamp, candle.close)
//                                        
//                                        // Trigger haptic feedback for placement
//                                        impactFeedback.impactOccurred()
//                                        
//                                        // Show creation sheet
//                                        isShowingSheet = true
//                                        showMarkerSheet = true
//                                    }
//                                }) {
//                                    HStack(spacing: 6) {
//                                        Image(systemName: "checkmark.circle.fill")
//                                            .font(.system(size: 22))
//                                        Text("Place")
//                                            .font(.headline)
//                                    }
//                                    .foregroundColor(.white)
//                                    .padding(.horizontal, 16)
//                                    .padding(.vertical, 12)
//                                    .background(Color.green)
//                                    .cornerRadius(12)
//                                }
//                            }
//                            .padding(.horizontal, 20)
//                            .padding(.top, 60)
//                            Spacer()
//                        }
//                        .allowsHitTesting(true) // Allow button taps
//                        .transition(.move(edge: .top).combined(with: .opacity))
//                    }
//                    
//                    // NAVIGATION CONTROLS
//                    // Top-right corner controls for auto-scroll, jump to latest, etc.
//                    VStack {
//                        HStack {
//                            Spacer()
//                            ChartNavigationControls(
//                                navigationManager: navigationManager,
//                                gestureState: gestureState,
//                                chartData: chartData,
//                                chartWidth: geometry.size.width,
//                                baseCandleWidth: baseCandleWidth
//                            )
//                        }
//                        Spacer()
//                    }
//                }
//                // GESTURE LAYER
//                // These gestures only apply when NOT in marker placement mode
//                // Order matters: crosshair has priority, then tap, then pan/zoom
//                .gesture(crosshairGesture(coordinateSystem: coordinateSystem))
//                .simultaneousGesture(tapGestureForMarkers(geometry: geometry))
//                .simultaneousGesture(dragGesture(in: geometry.size))
//                .simultaneousGesture(pinchGesture(in: geometry.size))
//                
//                // BOTTOM TOOLBAR
//                // Contains marker placement button and reset zoom button
//                VStack {
//                    Spacer()
//                    HStack(spacing: 20) {
//                        // Marker placement toggle button
//                        Button(action: {
//                            withAnimation {
//                                // Toggle placement mode
//                                isMarkerPlacementMode.toggle()
//                                
//                                if isMarkerPlacementMode {
//                                    // Start preview at CENTER of currently visible area
//                                    // This ensures marker appears where user is looking
//                                    previewCandleIndex = centerCandleIndex(using: coordinateSystem, chartWidth: geometry.size.width)
//                                    // Clear drag position so marker starts in snapped position
//                                    markerDragPosition = nil
//                                    print("📍 Marker placement mode ON - preview at candle \(previewCandleIndex)")
//                                } else {
//                                    // Clear all marker-related state when exiting
//                                    markerDragPosition = nil
//                                    isMarkerBeingDragged = false
//                                    print("📍 Marker placement mode OFF")
//                                }
//                            }
//                        }) {
//                            VStack(spacing: 2) {
//                                // Icon changes when placement mode is active
//                                Image(systemName: isMarkerPlacementMode ? "mappin.circle.fill" : "mappin.circle")
//                                    .font(.system(size: 24))
//                                Text("Marker")
//                                    .font(.caption2)
//                            }
//                        }
//                        .foregroundColor(isMarkerPlacementMode ? .blue : .white)
//                        
//                        // Reset zoom and pan button
//                        Button(action: {
//                            gestureState.reset()
//                        }) {
//                            VStack(spacing: 2) {
//                                Image(systemName: "arrow.counterclockwise")
//                                    .font(.system(size: 24))
//                                Text("Reset")
//                                    .font(.caption2)
//                            }
//                        }
//                    }
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(Color.black.opacity(0.8))
//                    .cornerRadius(12)
//                    .padding(.bottom, 80)
//                }
//            }
//        }
//        // MARKER CREATION SHEET
//        // Shows when user releases marker preview
//        // Allows user to select marker type and add notes
//        .sheet(isPresented: $showMarkerSheet) {
//            if let info = pendingMarkerInfo {
//                MarkerCreationSheet(
//                    markerManager: markerManager,
//                    candleIndex: info.candleIndex,
//                    timestamp: info.timestamp,
//                    price: info.price,
//                    username: "TestUser"
//                )
//                .onDisappear {
//                    // Exit placement mode after marker is created or cancelled
//                    isMarkerPlacementMode = false
//                    isShowingSheet = false
//                    markerManager.selectedMarker = nil
//                }
//            }
//        }
//        // MARKER DETAIL SHEET
//        // Shows when user taps an existing marker
//        // Displays marker info and allows editing/deletion for own markers
//        .sheet(item: $markerManager.selectedMarker) { marker in
//            MarkerDetailSheet(
//                markerManager: markerManager,
//                marker: marker,
//                currentUserId: "user123"
//            )
//        }
//        .onAppear {
//            // Start generating real-time candle data when view appears
//            chartData.startDataGeneration()
//        }
//    }
//    
//    // MARK: - Helper Functions
//    
//    /// Calculate which candle is at the center of the current visible area
//    /// This ensures marker preview starts where the user is actually looking
//    /// Uses visible range calculation instead of screen center math
//    /// - Parameter geometry: The geometry of the chart view
//    /// - Returns: Clamped candle index at the center of visible range
//    private func getCenterVisibleCandleIndex(geometry: GeometryProxy) -> Int {
//        // Get current pan offset (includes both stored and active drag)
//        let totalOffset = gestureState.panOffset.width + dragState.width
//        
//        // Calculate which candles are currently visible on screen
//        // Start index: first candle visible on left edge
//        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
//        
//        // End index: last candle visible on right edge (plus buffer)
//        let visibleEndIndex = Swift.min(
//            chartData.candles.count,
//            visibleStartIndex + Int(geometry.size.width / totalCandleWidth) + 2
//        )
//        
//        // Return the middle candle of the visible range
//        // This is where the user is most likely looking
//        let middleIndex = (visibleStartIndex + visibleEndIndex) / 2
//        
//        // Clamp to valid array bounds
//        let clampedIndex = max(0, min(chartData.candles.count - 1, middleIndex))
//        
//        print("📍 Visible range: \(visibleStartIndex) to \(visibleEndIndex)")
//        print("📍 Center candle: \(clampedIndex) of \(chartData.candles.count)")
//        
//        return clampedIndex
//    }
//    
//    /// Compute the candle index at the actual screen center using the coordinate system
//    /// - Parameters:
//    ///   - coordinateSystem: The chart coordinate system configured with live gesture state
//    ///   - chartWidth: The current width of the chart view
//    /// - Returns: A clamped candle index at the screen center
//    private func centerCandleIndex(using coordinateSystem: ChartCoordinateSystem, chartWidth: CGFloat) -> Int {
//        let centerX = chartWidth / 2
//        if let idx = coordinateSystem.candleIndex(atXPosition: centerX) {
//            return max(0, min(chartData.candles.count - 1, idx))
//        }
//        return max(0, min(chartData.candles.count - 1, chartData.candles.count / 2))
//    }
//    
//    // MARK: - Crosshair Gesture
//    
//    /// Long press gesture for activating crosshair (price inspection tool)
//    /// User must hold for 0.5 seconds, then can drag to inspect different prices
//    /// - Parameter coordinateSystem: Coordinate converter for screen<->chart mapping
//    /// - Returns: Combined long press + drag gesture
//    private func crosshairGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
//        LongPressGesture(minimumDuration: 0.5)
//            .sequenced(before: DragGesture(minimumDistance: 0))
//            .onChanged { value in
//                switch value {
//                case .second(true, let drag):
//                    // Long press succeeded, now user is dragging
//                    if let location = drag?.location {
//                        if !crosshairManager.isActive {
//                            // First activation - show crosshair at touch location
//                            crosshairManager.activate(
//                                at: location,
//                                coordinateSystem: coordinateSystem,
//                                chartData: chartData
//                            )
//                        } else {
//                            // Already active - update position as user drags
//                            crosshairManager.updatePosition(
//                                location,
//                                coordinateSystem: coordinateSystem,
//                                chartData: chartData
//                            )
//                        }
//                    }
//                default:
//                    break
//                }
//            }
//            .onEnded { _ in
//                // User released - hide crosshair
//                crosshairManager.deactivate()
//            }
//    }
//    
//    // MARK: - Tap Gesture for Markers
//    
//    /// Detect taps on existing markers to show their details
//    /// Checks if tap location is within 30 points of any marker
//    /// Only works when not in crosshair or placement mode
//    /// - Parameter geometry: Chart view geometry for position calculations
//    /// - Returns: Tap gesture that selects markers
//    private func tapGestureForMarkers(geometry: GeometryProxy) -> some Gesture {
//        DragGesture(minimumDistance: 0)
//            .onEnded { value in
//                // Don't handle taps during special modes or when creation sheet is showing
//                guard !crosshairManager.isActive && !isMarkerPlacementMode && !showMarkerSheet && !isShowingSheet else { return }
//                
//                let location = value.location
//                
//                // Calculate current chart offsets for marker positioning
//                let totalOffset = gestureState.panOffset.width + dragState.width
//                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
//                let scaledHeight = geometry.size.height * gestureState.priceScale
//                
//                // Check each visible marker to see if it was tapped
//                for marker in markerManager.filteredMarkers {
//                    // Skip markers with invalid candle indices
//                    guard marker.candleIndex < chartData.candles.count else { continue }
//                    
//                    // Calculate marker's current screen position
//                    // Uses same formula as Canvas drawing for perfect alignment
//                    let markerX = CGFloat(marker.candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//                    let candle = chartData.candles[marker.candleIndex]
//                    let markerY = geometry.size.height -
//                        (CGFloat(candle.high - chartData.priceRange.min) /
//                         CGFloat(chartData.priceRange.max - chartData.priceRange.min)) *
//                        scaledHeight - totalVerticalOffset - 30
//                    
//                    // Calculate distance from tap to marker center
//                    let distance = hypot(location.x - markerX, location.y - markerY)
//                    
//                    // If tap is within 30 points, select this marker
//                    if distance <= 30 {
//                        markerManager.selectedMarker = marker
//                        return // Found a marker, stop checking
//                    }
//                }
//            }
//    }
//    
//    // MARK: - Pan Gesture
//    
//    /// Drag gesture for panning the chart horizontally and vertically
//    /// Only active when NOT in Y-axis drag, crosshair, or marker placement modes
//    /// Requires 10pt movement to distinguish from tap gestures
//    /// - Parameter size: Chart view size for boundary calculations
//    /// - Returns: Pan drag gesture
//    private func dragGesture(in size: CGSize) -> some Gesture {
//        DragGesture(minimumDistance: 10)
//            .updating($dragState) { value, state, _ in
//                // Only update drag state if not in special modes
//                if !isDraggingOnYAxis && !crosshairManager.isActive && !isMarkerPlacementMode {
//                    // Reverse vertical direction for natural feel
//                    // (drag up = chart moves up, revealing lower prices)
//                    state = CGSize(width: value.translation.width, height: -value.translation.height)
//                }
//            }
//            .onEnded { value in
//                // Apply final pan position when gesture ends
//                if !isDraggingOnYAxis && !crosshairManager.isActive && !isMarkerPlacementMode {
//                    let adjustedTranslation = CGSize(
//                        width: value.translation.width,
//                        height: -value.translation.height
//                    )
//                    
//                    // Update stored pan offset with boundary clamping
//                    gestureState.applyPan(
//                        translation: adjustedTranslation,
//                        chartWidth: size.width,
//                        candleCount: chartData.candles.count,
//                        candleWidth: totalCandleWidth,
//                        chartHeight: size.height,
//                        priceScale: gestureState.priceScale
//                    )
//                }
//            }
//    }
//    
//    // MARK: - Pinch Gesture
//    
//    /// Pinch gesture for horizontal zoom (changes candle width)
//    /// Zoom is centered on screen center to keep visible candles in view
//    /// Dampened for smooth, controlled zooming
//    /// - Parameter size: Chart view size for center calculations
//    /// - Returns: Magnification pinch gesture
//    private func pinchGesture(in size: CGSize) -> some Gesture {
//        MagnificationGesture()
//            .updating($pinchScale) { value, state, _ in
//                // Don't zoom during special modes OR when pinching on Y-axis
//                guard !crosshairManager.isActive && !isMarkerPlacementMode && !isPinchingOnYAxis else { return }
//                
//                // Apply dampening to make zoom feel smoother
//                // Raw pinch values can be jumpy; dampening smooths them out
//                let dampened = 1.0 + (value - 1.0) * pinchSensitivity
//                state = dampened
//            }
//            .onChanged { value in
//                guard !crosshairManager.isActive && !isMarkerPlacementMode && !isPinchingOnYAxis else { return }
//                
//                // Apply dampening
//                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
//                
//                // Calculate which candle is at screen center BEFORE zoom
//                let screenCenterX = size.width / 2
//                let totalOffset = gestureState.panOffset.width + dragState.width
//                
//                let oldCandleWidth = baseCandleWidth * gestureState.candleWidthScale
//                let oldTotalWidth = oldCandleWidth + candleSpacing
//                let centerCandleIndex = (screenCenterX - totalOffset) / oldTotalWidth
//                let oldCandlePosition = centerCandleIndex * oldTotalWidth + totalOffset
//                
//                // Apply new zoom level with limits (0.3x to 3x)
//                let newScale = gestureState.candleWidthScale * dampenedValue
//                let clampedScale = Swift.min(3.0, Swift.max(0.3, newScale))
//                
//                // Calculate where center candle WOULD BE after zoom
//                let newCandleWidth = baseCandleWidth * clampedScale
//                let newTotalWidth = newCandleWidth + candleSpacing
//                let newCandlePosition = centerCandleIndex * newTotalWidth + totalOffset
//                
//                // Adjust pan offset to keep center candle at screen center
//                // This is what makes the zoom feel "centered" instead of anchored to left
//                let offsetAdjustment = oldCandlePosition - newCandlePosition
//                gestureState.panOffset.width += offsetAdjustment
//                
//                // Apply the new scale
//                gestureState.candleWidthScale = clampedScale
//            }
//            .onEnded { _ in }
//    }
//    
//    // MARK: - Y-Axis Gestures
//    
//    /// Drag gesture on Y-axis area for vertical price scaling
//    /// Ignores horizontal drag and zooming state.
//    /// Drag up = compress price range (zoom in), Drag down = expand range (zoom out)
//    /// Scaling is centered on the middle price of visible candles
//    private var yAxisDragGesture: some Gesture {
//        DragGesture()
//            .onChanged { value in
//                // Initialize drag tracking on first movement
//                if !isDraggingOnYAxis {
//                    isDraggingOnYAxis = true
//                    yAxisDragStart = value.startLocation.y
//                    initialPriceScale = gestureState.priceScale
//                }
//                
//                // Use the chart height and width from screen bounds for calculations
//                let chartHeight = UIScreen.main.bounds.height
//                let chartWidth = UIScreen.main.bounds.width
//                
//                // Calculate total horizontal pan offset WITHOUT active horizontal drag to avoid jitter
//                let totalOffset = gestureState.panOffset.width
//                
//                // Calculate visible candle range based on horizontal pan only
//                let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
//                let visibleEndIndex = Swift.min(
//                    chartData.candles.count,
//                    visibleStartIndex + Int(chartWidth / totalCandleWidth) + 2
//                )
//                
//                // Extract visible candles to find price range extremes
//                let visibleCandles = Array(chartData.candles[visibleStartIndex..<visibleEndIndex])
//                let visibleHighs = visibleCandles.map { $0.high }
//                let visibleLows = visibleCandles.map { $0.low }
//                let visibleMaxPrice = visibleHighs.max() ?? chartData.priceRange.max
//                let visibleMinPrice = visibleLows.min() ?? chartData.priceRange.min
//                let centerPrice = (visibleMaxPrice + visibleMinPrice) / 2
//                
//                // Calculate center price position BEFORE scaling
//                let oldScaledHeight = chartHeight * gestureState.priceScale
//                let priceRange = chartData.priceRange
//                let normalizedCenterPrice = (centerPrice - priceRange.min) / (priceRange.max - priceRange.min)
//                let centerYBeforeScale = chartHeight -
//                    (CGFloat(normalizedCenterPrice) * oldScaledHeight) -
//                    gestureState.verticalPanOffset
//                
//                // Calculate scale factor from drag distance
//                // Drag up (negative) = increase scale = compress price range
//                let dragDistance = value.location.y - yAxisDragStart
//                let scaleFactor = 1.0 - (dragDistance / 500.0) * yAxisSensitivity
//                
//                // Apply scale with limits (0.5x to 3x)
//                let newScale = initialPriceScale * scaleFactor
//                let clampedScale = Swift.min(3.0, Swift.max(0.5, newScale))
//                
//                // Calculate center price position AFTER scaling
//                let newScaledHeight = chartHeight * clampedScale
//                let centerYAfterScale = chartHeight -
//                    (CGFloat(normalizedCenterPrice) * newScaledHeight) -
//                    gestureState.verticalPanOffset
//                
//                // Adjust vertical offset to keep center price at same screen position
//                let offsetAdjustment = centerYAfterScale - centerYBeforeScale
//                gestureState.verticalPanOffset += offsetAdjustment
//                gestureState.priceScale = clampedScale
//            }
//            .onEnded { _ in
//                isDraggingOnYAxis = false
//            }
//    }
//    
//    /// Pinch gesture on Y-axis area for vertical price scaling
//    /// Ignores horizontal drag and zooming state.
//    /// Alternative to drag gesture - uses two-finger pinch
//    /// Same centering logic as drag but with pinch input
//    private var yAxisPinchGesture: some Gesture {
//        MagnificationGesture()
//            .updating($yAxisPinchScale) { value, state, _ in
//                // Apply dampening for smooth pinch
//                let dampened = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
//                state = dampened
//            }
//            .onChanged { value in
//                // Mark that we're pinching on Y-axis to block main chart horizontal zoom
//                if !isPinchingOnYAxis {
//                    isPinchingOnYAxis = true
//                }
//                
//                // Use the chart height and width from screen bounds for calculations
//                let chartHeight = UIScreen.main.bounds.height
//                let chartWidth = UIScreen.main.bounds.width
//                
//                // Calculate total horizontal pan offset WITHOUT active horizontal drag to avoid jitter
//                let totalOffset = gestureState.panOffset.width
//                
//                // Calculate visible candle range based on horizontal pan only
//                let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
//                let visibleEndIndex = Swift.min(
//                    chartData.candles.count,
//                    visibleStartIndex + Int(chartWidth / totalCandleWidth) + 2
//                )
//                
//                // Extract visible candles to find price range extremes
//                let visibleCandles = Array(chartData.candles[visibleStartIndex..<visibleEndIndex])
//                let visibleHighs = visibleCandles.map { $0.high }
//                let visibleLows = visibleCandles.map { $0.low }
//                let visibleMaxPrice = visibleHighs.max() ?? chartData.priceRange.max
//                let visibleMinPrice = visibleLows.min() ?? chartData.priceRange.min
//                let centerPrice = (visibleMaxPrice + visibleMinPrice) / 2
//                
//                // Calculate center price position BEFORE scaling
//                let oldScaledHeight = chartHeight * gestureState.priceScale
//                let priceRange = chartData.priceRange
//                let normalizedCenterPrice = (centerPrice - priceRange.min) / (priceRange.max - priceRange.min)
//                let centerYBeforeScale = chartHeight -
//                    (CGFloat(normalizedCenterPrice) * oldScaledHeight) -
//                    gestureState.verticalPanOffset
//                
//                // Apply dampened scaling factor
//                let dampenedValue = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
//                let newScale = gestureState.priceScale * dampenedValue
//                let clampedScale = Swift.min(3.0, Swift.max(0.5, newScale))
//                
//                // Calculate center price position AFTER scaling
//                let newScaledHeight = chartHeight * clampedScale
//                let centerYAfterScale = chartHeight -
//                    (CGFloat(normalizedCenterPrice) * newScaledHeight) -
//                    gestureState.verticalPanOffset
//                
//                // Adjust vertical offset to keep center price at same screen position
//                let offsetAdjustment = centerYAfterScale - centerYBeforeScale
//                gestureState.verticalPanOffset += offsetAdjustment
//                gestureState.priceScale = clampedScale
//            }
//            .onEnded { _ in
//                isPinchingOnYAxis = false
//            }
//    }
//    
//    // MARK: - Axis Overlays
//    
//    /// Y-axis overlay showing price labels
//    /// Stays fixed on right side while chart pans horizontally
//    /// Moves vertically with price scaling
//    /// - Parameter geometry: Chart view geometry
//    /// - Returns: Y-axis label overlay view
//    @ViewBuilder
//    private func yAxisOverlay(geometry: GeometryProxy) -> some View {
//        HStack {
//            Spacer()
//            Canvas { context, size in
//                let priceRange = chartData.priceRange
//                let scaledHeight = geometry.size.height * gestureState.priceScale
//                let priceStep = (priceRange.max - priceRange.min) / 10
//                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
//                
//                // Draw 10 evenly-spaced price labels
//                for i in 0...10 {
//                    let price = priceRange.min + (priceStep * Double(i))
//                    let y = size.height -
//                        (CGFloat(price - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//                        scaledHeight - totalVerticalOffset
//                    
//                    // Only draw labels that are visible on screen
//                    if y >= -20 && y <= size.height + 20 {
//                        context.draw(
//                            Text(String(format: "%.2f", price))
//                                .font(.system(size: 10))
//                                .foregroundColor(.gray),
//                            at: CGPoint(x: 30, y: y)
//                        )
//                    }
//                }
//            }
//            .frame(width: yAxisWidth)
//            .background(Color.black.opacity(0.8))
//        }
//        .allowsHitTesting(false) // Let touches pass through to Y-axis gesture area
//    }
//    
//    /// X-axis overlay showing time labels
//    /// Stays fixed at bottom but moves horizontally with pan
//    /// Shows time label every 5 candles
//    /// - Parameter geometry: Chart view geometry
//    /// - Returns: X-axis label overlay view
//    @ViewBuilder
//    private func xAxisOverlay(geometry: GeometryProxy) -> some View {
//        VStack {
//            Spacer()
//            Canvas { context, size in
//                let totalOffset = gestureState.panOffset.width + dragState.width
//                let labelStride = 5 // Show label every 5 candles
//                
//                // Draw time labels that move with horizontal pan
//                for i in stride(from: 0, to: chartData.candles.count, by: labelStride) {
//                    let x = CGFloat(i) * totalCandleWidth + totalOffset
//                    
//                    // Only draw labels that are visible on screen
//                    if x >= -50 && x <= size.width + 50 {
//                        let candle = chartData.candles[i]
//                        let formatter = DateFormatter()
//                        formatter.dateFormat = "HH:mm"
//                        let timeText = formatter.string(from: candle.timestamp)
//                        
//                        context.draw(
//                            Text(timeText)
//                                .font(.system(size: 10))
//                                .foregroundColor(.gray),
//                            at: CGPoint(x: x + actualCandleWidth / 2, y: 10)
//                        )
//                    }
//                }
//            }
//            .frame(height: 20)
//            .background(Color.black.opacity(0.8))
//            .padding(.bottom, geometry.size.height * 0.11 + 10)
//        }
//        .allowsHitTesting(false)
//    }
//    
//    // MARK: - Chart Drawing
//    
//    /// Main chart drawing coordinator
//    /// Calls individual drawing methods in correct order (back to front)
//    /// Draws: grid, candlesticks, placed markers (NOT preview)
//    /// - Parameters:
//    ///   - context: Graphics context for drawing
//    ///   - size: Canvas size
//    ///   - geometry: View geometry
//    private func drawChart(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
//        var drawingContext = context
//        
//        // Clip drawing to chart bounds
//        drawingContext.clip(to: Path(CGRect(origin: .zero, size: size)))
//        
//        // Calculate current offsets for all positioning
//        let totalOffset = gestureState.panOffset.width + dragState.width
//        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
//        
//        // Draw components in order (back to front)
//        drawGrid(context: drawingContext, size: size)
//        drawCandlesticks(context: drawingContext, size: size)
//        
//        // Draw placed markers (NOT preview - that's SwiftUI overlay)
//        // Uses EXACT same positioning math as candlesticks for perfect alignment
//        ChartMarkerSystem.drawMarkers(
//            context: drawingContext,
//            markers: markerManager.filteredMarkers,
//            candles: chartData.candles,
//            chartSize: size,
//            priceRange: chartData.priceRange,
//            priceScale: gestureState.priceScale,
//            verticalOffset: totalVerticalOffset,
//            totalCandleWidth: totalCandleWidth,
//            actualCandleWidth: actualCandleWidth,
//            totalOffset: totalOffset
//        )
//    }
//    
//    /// Draw background grid for visual reference
//    /// Vertical lines every 5 candles, horizontal lines every 10% of price range
//    /// - Parameters:
//    ///   - context: Graphics context
//    ///   - size: Canvas size
//    private func drawGrid(context: GraphicsContext, size: CGSize) {
//        let gridPath = Path { path in
//            // Vertical grid lines (aligned with time)
//            let verticalSpacing = totalCandleWidth * 5
//            let totalOffset = gestureState.panOffset.width + dragState.width
//            
//            // Calculate starting position for seamless grid during pan
//            var x = totalOffset.truncatingRemainder(dividingBy: verticalSpacing)
//            if x > 0 { x -= verticalSpacing }
//            
//            // Draw vertical lines across entire height
//            while x < size.width {
//                path.move(to: CGPoint(x: x, y: 0))
//                path.addLine(to: CGPoint(x: x, y: size.height))
//                x += verticalSpacing
//            }
//            
//            // Horizontal grid lines (aligned with price)
//            let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
//            let scaledHeight = size.height * gestureState.priceScale
//            let horizontalSpacing = scaledHeight / 10
//            
//            // Calculate starting position for seamless grid during vertical pan
//            var y = -totalVerticalOffset.truncatingRemainder(dividingBy: horizontalSpacing)
//            if y > 0 { y -= horizontalSpacing }
//            
//            // Draw horizontal lines across entire width
//            while y < size.height {
//                path.move(to: CGPoint(x: 0, y: y))
//                path.addLine(to: CGPoint(x: size.width, y: y))
//                y += horizontalSpacing
//            }
//        }
//        
//        // Draw grid with subtle gray color
//        context.stroke(gridPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
//    }
//    
//    /// Draw candlesticks - the main chart content
//    /// Only draws visible candles for performance
//    /// Green = bullish (close >= open), Red = bearish (close < open)
//    /// - Parameters:
//    ///   - context: Graphics context
//    ///   - size: Canvas size
//    private func drawCandlesticks(context: GraphicsContext, size: CGSize) {
//        let priceRange = chartData.priceRange
//        let scaledHeight = size.height * gestureState.priceScale
//        let totalOffset = gestureState.panOffset.width + dragState.width
//        
//        // Calculate visible candle range for performance
//        // Only draw candles that are actually on screen
//        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
//        let visibleEndIndex = Swift.min(
//            chartData.candles.count,
//            visibleStartIndex + Int(size.width / totalCandleWidth) + 3
//        )
//        
//        // Draw each visible candle
//        for i in visibleStartIndex..<visibleEndIndex {
//            guard i < chartData.candles.count else { continue }
//            
//            let candle = chartData.candles[i]
//            
//            // Calculate X position
//            // This is the EXACT formula used for marker positioning
//            let x = CGFloat(i) * totalCandleWidth + totalOffset
//            
//            // Skip if definitely outside visible area (optimization)
//            if x < -totalCandleWidth || x > size.width + totalCandleWidth {
//                continue
//            }
//            
//            // Calculate Y positions for OHLC values
//            let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
//            let highY = size.height -
//                (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//                scaledHeight - totalVerticalOffset
//            let lowY = size.height -
//                (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//                scaledHeight - totalVerticalOffset
//            let openY = size.height -
//                (CGFloat(candle.open - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//                scaledHeight - totalVerticalOffset
//            let closeY = size.height -
//                (CGFloat(candle.close - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//                scaledHeight - totalVerticalOffset
//            
//            // Determine candle color based on price movement
//            let candleColor = candle.close >= candle.open ? Color.green : Color.red
//            
//            // Draw wick (thin line from high to low)
//            let wickPath = Path { path in
//                path.move(to: CGPoint(x: x + actualCandleWidth / 2, y: highY))
//                path.addLine(to: CGPoint(x: x + actualCandleWidth / 2, y: lowY))
//            }
//            context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)
//            
//            // Draw body (rectangle from open to close)
//            let bodyRect = CGRect(
//                x: x,
//                y: Swift.min(openY, closeY),
//                width: actualCandleWidth,
//                height: Swift.max(1, abs(closeY - openY)) // Min height of 1 for doji candles
//            )
//            
//            if candle.close >= candle.open {
//                // Bullish candle - hollow with green outline
//                context.stroke(
//                    Path(roundedRect: bodyRect, cornerRadius: 0),
//                    with: .color(candleColor),
//                    lineWidth: 1
//                )
//                context.fill(
//                    Path(roundedRect: bodyRect, cornerRadius: 0),
//                    with: .color(candleColor.opacity(0.3))
//                )
//            } else {
//                // Bearish candle - solid red fill
//                context.fill(
//                    Path(roundedRect: bodyRect, cornerRadius: 0),
//                    with: .color(candleColor)
//                )
//            }
//        }
//    }
//}
