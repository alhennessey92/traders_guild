import SwiftUI

/// Main trading chart view that handles all chart rendering and interactions
/// Features centered scaling that keeps visible candles in view during zoom
/// Includes marker placement system for collaborative chart annotations
struct TradingChartView: View {
    // MARK: - State Properties
    
    // MARK: - Chart Context Accessors

    private var currentTimeframe: ChartTimeframe {
        chartViewModel.currentTimeframe
    }

    private var currentSymbol: TradingSymbol? {
        chartViewModel.currentSymbol
    }
    
    // MARK: - Chart Control ViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel
    
    /// Gesture state manager that handles all pan/zoom transformations
    /// This is the single source of truth for chart positioning
    @StateObject private var gestureState = ChartGestureState()
    
    /// Current drag translation for smooth real-time panning feedback
    /// Using @State instead of @GestureState to avoid spring-back animation
    @State private var dragState: CGSize = .zero
    
    /// Track the previous drag translation for incremental updates
    @State private var lastDragTranslation: CGSize = .zero
    
    /// Y-axis pinch scale for vertical price range scaling (not used but kept for reference)
    @GestureState private var yAxisPinchScale: CGFloat = 1.0
    
    /// Track if user is currently dragging on the Y-axis area
    /// Prevents interference between Y-axis drag and normal chart pan
    @State private var isDraggingOnYAxis = false
    
    /// Track if user is currently pinching on the Y-axis area
    /// Prevents interference between Y-axis pinch and normal chart horizontal zoom
    @State private var isPinchingOnYAxis = false
    
    /// Starting Y position when beginning Y-axis drag
    /// Used to calculate total drag distance for scaling
    @State private var yAxisDragStart: CGFloat = 0
    
    /// The initial price scale when Y-axis gesture begins
    /// Used as the base for calculating the new scale
    @State private var initialPriceScale: CGFloat = 1.0
    
    /// The initial vertical offset when Y-axis gesture begins
    /// Used to properly adjust offset during scaling to keep center fixed
    @State private var initialVerticalOffset: CGFloat = 0
    
    /// Track if user is currently pinching on the main chart (horizontal zoom)
    /// Used to store initial state for proper symmetric scaling
    @State private var isPinchingOnChart = false
    
    /// The initial candle width scale when chart pinch begins
    /// Used as the base for calculating the new scale
    @State private var initialCandleWidthScale: CGFloat = 1.0
    
    /// The initial horizontal offset when chart pinch begins
    /// Used to properly adjust offset during scaling to keep pinch center fixed
    @State private var initialHorizontalOffset: CGFloat = 0
    
    /// The X position of the pinch center when gesture begins
    /// Used as the fixed point for symmetric horizontal scaling
    @State private var pinchCenterX: CGFloat = 0
    
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
    // Marker placement mode is now controlled by ViewModel
    private var isMarkerPlacementMode: Bool {
        controlViewModel.isMarkerPlacementMode
    }
    
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
    
    @State private var chartSize: CGSize = .zero
    
    /// Stores crosshair position at start of drag for relative movement
    /// This allows crosshair to move by delta instead of jumping to finger position
    @State private var crosshairDragStartPosition: CGPoint? = nil

    
    /// Whether to show duplicate marker type alert
    @State private var showDuplicateMarkerAlert = false
    

    
    /// Track if chart has been initialized with proper position
    @State private var hasInitializedPosition = false
    
    /// Track if chart is loading (waiting for data)
    @State private var isChartLoading = true
    
    /// Track the marker ID that was just tapped (for animation)
    @State private var tappedMarkerId: UUID? = nil
    
    /// Haptic feedback generator for marker interactions
    private let markerHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Chart Configuration
    
    /// Base width of each candle before any scaling is applied
    /// This is the "normal" candle width at 1x zoom
    private let baseCandleWidth: CGFloat = 12
    
    /// Spacing between adjacent candles
    /// Creates visual separation for readability
    private let candleSpacing: CGFloat = 4
    
    /// Edge padding to prevent endless scrolling
    /// Provides buffer space at chart boundaries
    private let edgePadding: CGFloat = 200
    
    /// Width of the Y-axis interaction area on the right side
    /// This area captures vertical drag/pinch gestures for price scaling
    private let yAxisWidth: CGFloat = 60
    
    // MARK: - Chart View Model
    
    /// Chart view model that coordinates chart state and data
    @ObservedObject var chartViewModel: ChartViewModel
    
    /// Shorthand accessor for data manager
    /// This computed property lets us keep using "chartData" throughout the file
    private var chartData: ChartDataManager {
        chartViewModel.dataManager
    }
    
    // MARK: - Sensitivity Configuration
    
    /// Dampening factor for horizontal pinch gesture (0.0 to 1.0)
    /// Lower = less sensitive and smoother, Higher = more responsive but jittery
    /// 0.15 provides a good balance for production use
    private let pinchSensitivity: CGFloat = 0.7
    
    /// Dampening factor for Y-axis drag/pinch scaling (0.0 to 1.0)
    /// Controls how quickly vertical gestures change price scale
    /// 0.15 = controlled (original), 0.25 = moderate, 0.35 = responsive, 0.5 = very sensitive
    /// Higher values = faster scaling response, but may feel too jumpy
    private let yAxisSensitivity: CGFloat = 0.7
    
    // MARK: - Scale Limits Configuration
    
    /// Maximum vertical scale (price axis)
    /// How much you can zoom in vertically (taller candles)
    /// 3.0 = 3x max height, 5.0 = 5x max height, 10.0 = 10x max height
    private let maxVerticalScale: CGFloat = 5.0
    
    /// Minimum vertical scale (price axis)
    /// How much you can zoom out vertically (shorter candles)
    /// 0.5 = half height, 0.3 = 30% height, 0.1 = 10% height
    private let minVerticalScale: CGFloat = 0.5
    
    /// Maximum horizontal scale (candle width)
    /// How much you can zoom in horizontally (wider candles)
    /// 3.0 = 3x max width, 5.0 = 5x max width
    private let maxHorizontalScale: CGFloat = 3.0
    
    /// Minimum horizontal scale (candle width)
    /// How much you can zoom out horizontally (narrower candles)
    /// 0.3 = 30% width, 0.1 = 10% width
    private let minHorizontalScale: CGFloat = 0.3
    
    // MARK: - Computed Properties
    
    /// Actual width of each candle including current zoom scale
    /// Uses the stored scale directly (no live pinch scale needed)
    /// This is what's actually rendered on screen
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }
    
    /// Total width per candle including spacing
    /// Used for all positioning calculations throughout the chart
    private var totalCandleWidth: CGFloat {
        actualCandleWidth + candleSpacing
    }
    
    /// Calculate clamped vertical offset that respects pan limits
    /// Prevents user from panning too far up or down
    /// FIXED: No longer uses dragState (translation applied incrementally)
    private func clampedVerticalOffset(chartHeight: CGFloat) -> CGFloat {
        // Use stored offset directly - incremental updates already applied
        let totalOffset = gestureState.verticalPanOffset
        
        // Calculate scaled height to determine valid pan range
        let scaledHeight = chartHeight * gestureState.priceScale
        
        // Very generous base limit
        let baseMultiplier: CGFloat = 3.0
        
        // Extra room when zoomed out so prices NEVER run out
        let zoomAdjustment: CGFloat
        if gestureState.priceScale < 0.5 {
            zoomAdjustment = 4.0
        } else if gestureState.priceScale < 0.7 {
            zoomAdjustment = 3.0
        } else if gestureState.priceScale < 0.9 {
            zoomAdjustment = 2.0
        } else if gestureState.priceScale > 2.0 {
            zoomAdjustment = 2.0
        } else {
            zoomAdjustment = 1.5
        }
        
        let verticalPadding = scaledHeight * baseMultiplier * zoomAdjustment
        
        // Hard clamp - no animation, just stop at the wall
        return Swift.min(verticalPadding, Swift.max(-verticalPadding, totalOffset))
    }
    
    // MARK: - Initialization
    
    /// Initialize the trading chart view with user and guild context
    /// - Parameters:
    ///   - userId: Current user's ID for marker ownership
    ///   - username: Current user's display name
    ///   - guildId: Guild context for marker filtering
    ///   - controlViewModel: View model for chart controls
    ///   - chartViewModel: View model for chart data and state
    init(
        userId: String = "user123",
        username: String = "TestUser",
        guildId: String = "guild1",
        controlViewModel: ChartControlViewModel,
        chartViewModel: ChartViewModel
    ) {
        _markerManager = StateObject(wrappedValue: MarkerManager(userId: userId, guildId: guildId))
        self.controlViewModel = controlViewModel
        self.chartViewModel = chartViewModel
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
                // Note: We update stored scale directly now, so no live pinch scale needed
                let _ = coordinateSystem.updateLiveState(dragState: dragState, pinchScale: 1.0)
                
                let _ = {
                    if chartSize != geometry.size {
                        DispatchQueue.main.async {
                            chartSize = geometry.size
                        }
                    }
                }()
                
                ZStack {
                    // Black background for professional trading chart appearance
                    Color.black.ignoresSafeArea().opacity(0.2)
                    
                    // MAIN CHART CANVAS
                    // Draws: grid, candlesticks, and placed markers
                    // Does NOT draw preview marker (that's a SwiftUI overlay for smooth updates)
                    Canvas { context, size in
                        drawChart(context: context, size: size, geometry: geometry)
                    }
                    .contentShape(Rectangle()) // Make entire canvas tappable/draggable
                    // Canvas will now redraw automatically when any @Published property changes
                    
                    
                    
                    
                    
                    // MARKER PLACEMENT OVERLAY with improved time indicator
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
                                    
                                    // X-AXIS TIME INDICATOR - styled like the Y-axis price indicator
                                    MarkerXAxisTimeIndicator(
                                        timestamp: candle.timestamp,
                                        xPosition: x,
                                        chartHeight: geometry.size.height
                                    )
                                    
                                    // HORIZONTAL LINE PREVIEW for markers that show horizontal lines
                                    if let markerType = controlViewModel.currentMarkerType,
                                       markerType.hasHorizontalLine {
                                        MarkerHorizontalLinePreview(
                                            candle: candle,
                                            markerType: markerType,
                                            coordinateSystem: coordinateSystem,
                                            chartWidth: geometry.size.width,
                                            chartData: chartData
                                        )
                                    }
                                }
                            }
                            
                            // PREVIEW MARKER - SwiftUI overlay for instant updates
                            if previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count {
                                let candle = chartData.candles[previewCandleIndex]
                                
                                // Calculate snap position - now properly calculates above/below
                                let snapX = coordinateSystem.xCenterPosition(forCandleIndex: previewCandleIndex)
                                let candleHighY = coordinateSystem.yPosition(forPrice: candle.high)
                                let candleLowY = coordinateSystem.yPosition(forPrice: candle.low)

                                // Use position calculator to determine proper placement
                                let (snapPosition, _) = MarkerPositionCalculator.calculatePreviewPosition(
                                    candleIndex: previewCandleIndex,
                                    existingMarkers: markerManager.filteredMarkers,
                                    candles: chartData.candles,
                                    candleHighY: candleHighY,
                                    candleLowY: candleLowY,
                                    centerX: snapX
                                )

                                // Use drag position if actively dragging, otherwise use snap position
                                let markerX = markerDragPosition?.x ?? snapPosition.x
                                let markerY = markerDragPosition?.y ?? snapPosition.y
                                
                                if markerX >= -50 && markerX <= geometry.size.width + 50 {
                                    ZStack {
                                        // Invisible hit area
                                        Circle()
                                            .fill(Color.clear)
                                            .frame(width: 80, height: 80)
                                            .contentShape(Circle())
                                        
                                        // Marker circle with current type's color
                                        Circle()
                                            .fill(Color.black.opacity(0.85))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(controlViewModel.currentMarkerType?.color ?? .blue, lineWidth: 3)
                                            )
                                        
                                        // Inner colored circle with icon
                                        Circle()
                                            .fill(controlViewModel.currentMarkerType?.color ?? .blue)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Image(systemName: controlViewModel.currentMarkerType?.icon ?? "mappin")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                        
                                        // Info box
                                        VStack(spacing: 2) {
                                            Text(candle.timestamp.chartTimeLabel)
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                            Text(chartData.formatPrice(candle.close))
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
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                if !isMarkerBeingDragged {
                                                    isMarkerBeingDragged = true
                                                    impactFeedback.impactOccurred()
                                                }
                                                markerDragPosition = value.location
                                                
                                                if let index = coordinateSystem.candleIndex(atXPosition: value.location.x) {
                                                    let clampedIndex = max(0, min(chartData.candles.count - 1, index))
                                                    previewCandleIndex = clampedIndex
                                                }
                                            }
                                            .onEnded { value in
                                                isMarkerBeingDragged = false
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
                    
                    // CHART INFO BOX
                    // Top-left overlay showing symbol, timeframe, price, guild
                    chartInfoBox(geometry: geometry)
                    
                    // CHART Controls BOX
                    // Bottom Right control box
                    chartControlsBox(geometry: geometry)
                    
                    // NOTE: Y-axis gesture area moved outside ZStack to avoid gesture conflicts
                    
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
                        chartSize: geometry.size,
                        chartData: chartData
                    )
                    
                    // INSTRUCTION BANNER
                    // Shown during marker placement mode
                    // Tells user how to place marker and provides cancel/place buttons
                    // FIXED: Hide buttons when sheet is showing
                    if isMarkerPlacementMode && !showMarkerSheet && !isShowingSheet {
                        VStack {
                            HStack(spacing: 12) {
                                // Cancel button to exit placement mode
                                Button(action: {
                                    withAnimation {
                                        controlViewModel.isMarkerPlacementMode = false
                                        isMarkerBeingDragged = false
                                        markerDragPosition = nil
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                }
                                
                                // Place button to commit marker placement
                                Button(action: {
                                    // Check if sheet is already showing to prevent duplicates
                                    guard !isShowingSheet else { return }
                                    
                                    // Validate candle index and get timestamp
                                    if let timestamp = coordinateSystem.timestamp(forCandleIndex: previewCandleIndex),
                                       previewCandleIndex >= 0,
                                       previewCandleIndex < chartData.candles.count,
                                       let markerType = controlViewModel.currentMarkerType {
                                        
                                        // Check for duplicate marker type on this candle
                                        if let existingMarker = markerManager.existingMarkerOfType(markerType, atCandleIndex: previewCandleIndex) {
                                            // Show duplicate alert instead of creation sheet
                                            markerManager.duplicateMarkerToLike = existingMarker
                                            markerManager.showDuplicateAlert = true
                                            return
                                        }
                                        
                                        let candle = chartData.candles[previewCandleIndex]
                                        markerManager.selectedMarker = nil
                                        pendingMarkerInfo = (previewCandleIndex, timestamp, candle.close)
                                        impactFeedback.impactOccurred()
                                        isShowingSheet = true
                                        showMarkerSheet = true
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
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
                    
                }
                // GESTURE LAYER
                // These gestures only apply when NOT in marker placement mode
                // Order matters: tap to dismiss crosshair first, then long press to activate, then others
                .gesture(crosshairDismissTapGesture())  // NEW: Tap to dismiss crosshair
                .gesture(crosshairGesture(coordinateSystem: coordinateSystem))
                .simultaneousGesture(tapGestureForMarkers(geometry: geometry))
                .simultaneousGesture(dragGesture(in: geometry.size, coordinateSystem: coordinateSystem))  // MODIFIED: Pass coordinateSystem
                .simultaneousGesture(pinchGesture(in: geometry.size))
                // Y-AXIS GESTURE OVERLAY
                // CRITICAL: This must be OUTSIDE the main ZStack and AFTER the gesture layer
                // to prevent the main chart gestures from competing with Y-axis gestures
                .overlay(
                    HStack {
                        Spacer()
                        Color.clear
                            .frame(width: yAxisWidth)
                            .contentShape(Rectangle())
                            .gesture(yAxisDragGesture)  // Drag for vertical scaling
                            .simultaneousGesture(yAxisPinchGesture)  // Pinch for vertical scaling
                    }
                    .allowsHitTesting(true)  // Ensure this layer can receive touches
                    .onDisappear {
                        // Safety: Clear flags if view disappears during gesture
                        isDraggingOnYAxis = false
                        isPinchingOnYAxis = false
                        print("⚠️ Y-axis overlay disappeared - clearing gesture flags")
                    }
                )
                
                // LOADING OVERLAY
                // Shows when chart is loading or symbol is not yet set
                if isChartLoading || chartViewModel.currentSymbol == nil || chartData.candles.isEmpty {
                    ZStack {
                        Color.black.opacity(0.85)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            // Animated loading indicator
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading Chart...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if chartViewModel.currentSymbol == nil {
                                Text("Fetching symbol data")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else if chartData.candles.isEmpty {
                                Text("Loading candles")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .transition(.opacity.animation(.easeOut(duration: 0.3)))
                }
                
                // BOTTOM TOOLBAR
                // Contains marker placement button and reset zoom button

            }
        }
        // MARKER CREATION SHEET
        // Shows when user releases marker preview
        // Allows user to select marker type and add notes
        .sheet(isPresented: $showMarkerSheet) {
            if let info = pendingMarkerInfo,
               let markerType = controlViewModel.currentMarkerType {
                MarkerCreationSheet(
                    markerManager: markerManager,
                    candleIndex: info.candleIndex,
                    timestamp: info.timestamp,
                    price: info.price,
                    username: "TestUser",
                    chartData: chartData,
                    candles: chartData.candles,
                    markerType: markerType
                )
                .onDisappear {
                    controlViewModel.cancelMarkerPlacement()
                    isShowingSheet = false
                    markerManager.selectedMarker = nil
                }
            } else {
                // FIXED: Fallback view when data is missing (prevents blank sheet)
                NavigationView {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Unable to Create Marker")
                            .font(.headline)
                        Text("Please try again")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .navigationTitle("Error")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Dismiss") {
                                showMarkerSheet = false
                                controlViewModel.cancelMarkerPlacement()
                                isShowingSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        
        .alert("Marker Exists", isPresented: $markerManager.showDuplicateAlert) {
            Button("Like Existing") {
                if let marker = markerManager.duplicateMarkerToLike {
                    markerManager.toggleLike(markerId: marker.id)
                }
                markerManager.duplicateMarkerToLike = nil
                controlViewModel.cancelMarkerPlacement()
            }
            Button("Cancel", role: .cancel) {
                markerManager.duplicateMarkerToLike = nil
            }
        } message: {
            Text("A \(markerManager.duplicateMarkerToLike?.type.rawValue ?? "marker") already exists on this candle. Would you like to like it instead?")
        }
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        // MARKER DETAIL SHEET
        // Shows when user taps an existing marker
        // Displays marker info and allows editing/deletion for own markers
        .sheet(item: $markerManager.selectedMarker) { marker in
            MarkerDetailSheet(
                markerManager: markerManager,
                marker: marker,
                currentUserId: "user123",
                chartData: chartData
            )
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        
        .onAppear {
            // Set up control actions
            setupControlActions()
            
            // UPDATED: Load markers via API instead of direct generation
            // Connect marker manager to view model for coordinated loading
            chartViewModel.markerManager = markerManager
            
            // Start with loading state until we have symbol and candles
            isChartLoading = chartViewModel.currentSymbol == nil || chartData.candles.isEmpty
            
            // Position chart at most recent candles on initial load (with delay for data to load)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !hasInitializedPosition && !chartData.candles.isEmpty && chartViewModel.currentSymbol != nil {
                    resetChartToMostRecentCandles()
                    hasInitializedPosition = true
                }
            }
            
            // Load markers after a short delay to ensure candles are loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if markerManager.markers.isEmpty && !chartData.candles.isEmpty {
                    Task {
                        await loadMarkersFromAPI()
                    }
                }
            }
            
            // Note: Data generation is handled by ChartViewModel in MainView
            // This ensures proper coordination with symbol/timeframe changes
        }
        
        .onChange(of: controlViewModel.isMarkerPlacementMode) { oldValue, newValue in
            if !oldValue && newValue {
                let centerIndex = calculateCenterCandleIndex()
                previewCandleIndex = centerIndex
            }
        }
        // Watch for symbol becoming available (initial load)
        .onChange(of: chartViewModel.currentSymbol) { oldValue, newValue in
            if oldValue == nil && newValue != nil && !chartData.candles.isEmpty {
                // Symbol just became available - position chart properly
                if !hasInitializedPosition {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        resetChartToMostRecentCandles()
                        hasInitializedPosition = true
                    }
                }
            }
        }
        // Reload markers and reset position when symbol changes (not initial load)
        .onChange(of: chartViewModel.currentSymbol?.symbol) { oldValue, newValue in
            if oldValue != newValue && oldValue != nil {
                // Symbol changed (not initial nil -> value)
                isChartLoading = true
                markerManager.clearMarkers()
                // Short delay to let new candles load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    resetChartToMostRecentCandles()
                    Task {
                        await loadMarkersFromAPI()
                    }
                }
            }
        }
        // Reload markers and reset position when timeframe changes
        .onChange(of: chartViewModel.currentTimeframe) { oldValue, newValue in
            if oldValue != newValue {
                isChartLoading = true
                markerManager.clearMarkers()
                // Short delay to let new candles load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    resetChartToMostRecentCandles()
                    Task {
                        await loadMarkersFromAPI()
                    }
                }
            }
        }
        // Also reset when candle count changes significantly (data reload)
        .onChange(of: chartData.candles.count) { oldCount, newCount in
            // If candle count changed significantly (not just a new candle), reset position
            if abs(newCount - oldCount) > 10 {
                resetChartToMostRecentCandles()
            }
        }
    }
    
    // MARK: - Chart Position Management
    
    /// Reset chart position to show most recent candles centered on screen
    /// Called on initial load, timeframe change, and symbol change
    /// Also resets vertical position and price scale for proper centering
    private func resetChartToMostRecentCandles() {
        guard !chartData.candles.isEmpty else { return }
        
        // Calculate the offset to show most recent candles
        // Position the last candle about 1/3 from the right edge of the screen
        let screenWidth = chartSize.width > 0 ? chartSize.width : UIScreen.main.bounds.width
        let totalChartWidth = CGFloat(chartData.candles.count) * totalCandleWidth
        
        // Negative offset means we've scrolled to the right (towards more recent candles)
        // We want the most recent candles visible, with some space on the right
        let rightPadding = screenWidth * 0.3  // 30% of screen width as right padding
        let targetOffset = -(totalChartWidth - screenWidth + rightPadding)
        
        // Clamp to prevent scrolling too far
        let minOffset = -(totalChartWidth - screenWidth + edgePadding)
        let maxOffset = edgePadding
        let clampedOffset = max(minOffset, min(maxOffset, targetOffset))
        
        // Apply the position change (with animation for smoother UX)
        withAnimation(.easeOut(duration: 0.3)) {
            // Reset horizontal position to show recent candles
            gestureState.panOffset.width = clampedOffset
            
            // Reset vertical offset to center (0 = centered on price range)
            gestureState.panOffset.height = 0
            gestureState.verticalPanOffset = 0
            
            // Reset price scale to default (1.0 = candles fit screen vertically)
            gestureState.priceScale = 1.0
        }
        
        // Mark loading as complete since we now have data and position
        isChartLoading = false
    }
    
    // MARK: - Marker API Loading
    
    /// Load markers from API and update their prices based on actual candle data
    /// NOTE: For proper cross-timeframe persistence, markers should be stored by timestamp
    /// and mapped to the appropriate candleIndex based on which candle contains that timestamp.
    /// The current sample data implementation regenerates markers, but a real API would:
    /// 1. Store markers with their exact timestamp
    /// 2. On timeframe change, find the candle that contains each marker's timestamp
    /// 3. Remap candleIndex accordingly
    private func loadMarkersFromAPI() async {
        guard !chartData.candles.isEmpty else { return }
        
        let symbol = chartViewModel.currentSymbol?.symbol ?? "EURUSD"
        let guildId = markerManager.guildId
        
        // Generate sample markers (this simulates API response)
        var markers = SampleData.generateChartMarkers(
            forSymbol: symbol,
            guildId: guildId,
            candleCount: chartData.candles.count,
            count: 8
        )
        
        // Update marker prices based on actual candle data
        markers = SampleData.updateMarkerPrices(
            markers: markers,
            candles: chartData.candles
        )
        
        // CRITICAL: Assign stable positions that won't change when new candles arrive
        markers = MarkerPositionCalculator.assignStablePositions(
            markers: markers,
            candles: chartData.candles
        )
        
        // Update marker manager on main thread
        await MainActor.run {
            markerManager.markers = markers
        }
    }
    
    /// Find the candle index that contains a given timestamp
    /// Used for mapping timestamp-based markers to the current timeframe's candles
    /// - Parameters:
    ///   - timestamp: The marker's timestamp
    ///   - candles: The current candle array
    ///   - timeframe: The current timeframe (determines candle duration)
    /// - Returns: The candle index containing the timestamp, or nil if not found
    private func findCandleIndex(forTimestamp timestamp: Date, in candles: [Candle], timeframe: ChartTimeframe) -> Int? {
        // Get the duration of each candle in seconds
        let candleDuration: TimeInterval
        switch timeframe {
        case .m1: candleDuration = 60
        case .m5: candleDuration = 5 * 60
        case .m15: candleDuration = 15 * 60
        case .m30: candleDuration = 30 * 60
        case .h1: candleDuration = 60 * 60
        case .h4: candleDuration = 4 * 60 * 60
        case .d1: candleDuration = 24 * 60 * 60
        case .w1: candleDuration = 7 * 24 * 60 * 60
        case .mn: candleDuration = 30 * 24 * 60 * 60
        }
        
        // Find the candle that contains this timestamp
        for (index, candle) in candles.enumerated() {
            let candleEnd = candle.timestamp.addingTimeInterval(candleDuration)
            if timestamp >= candle.timestamp && timestamp < candleEnd {
                return index
            }
        }
        
        // If not found in range, check if timestamp is close to any candle
        // (handles edge cases at chart boundaries)
        if let firstCandle = candles.first, timestamp < firstCandle.timestamp {
            return 0  // Before first candle
        }
        if let lastCandle = candles.last {
            let lastCandleEnd = lastCandle.timestamp.addingTimeInterval(candleDuration)
            if timestamp >= lastCandleEnd {
                return candles.count - 1  // After last candle
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    /// Calculate which candle is at the center of the current visible area
    /// This ensures marker preview starts where the user is actually looking
    /// Uses visible range calculation instead of screen center math
    /// - Parameter geometry: The geometry of the chart view
    /// - Returns: Clamped candle index at the center of visible range
    private func getCenterVisibleCandleIndex(geometry: GeometryProxy) -> Int {
        // Get current pan offset (includes both stored and active drag)
        let totalOffset = gestureState.panOffset.width
        
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
    
    private func calculateCenterCandleIndex() -> Int {
        let totalOffset = gestureState.panOffset.width
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
        let candlesOnScreen = Int(chartSize.width / totalCandleWidth)
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            visibleStartIndex + candlesOnScreen + 2
        )
        let middleIndex = (visibleStartIndex + visibleEndIndex) / 2
        return max(0, min(chartData.candles.count - 1, middleIndex))
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
    
    // MARK: - Crosshair Gestures
    
    /// Long press gesture for activating crosshair (price inspection tool)
    /// Crosshair stays visible until user taps to dismiss
    /// - Parameter coordinateSystem: Coordinate converter for screen<->chart mapping
    /// - Returns: Combined long press + drag gesture
    private func crosshairGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)  // Fast activation (0.2s)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    // Long press succeeded, now user is dragging
                    if let location = drag?.location {
                        if !crosshairManager.isActive {
                            // First activation - haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
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
        // NO .onEnded - crosshair stays visible until tapped to dismiss!
    }
    
    /// Tap anywhere to dismiss active crosshair
    /// Only triggers when crosshair is active
    private func crosshairDismissTapGesture() -> some Gesture {
        TapGesture()
            .onEnded {
                if crosshairManager.isActive {
                    // Light haptic on dismiss
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    crosshairManager.deactivate()
                }
            }
    }
    
    // MARK: - Tap Gesture for Markers
    
    /// Detect taps on markers using UNIFIED hit detection
    private func tapGestureForMarkers(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard !crosshairManager.isActive &&
                        !isMarkerPlacementMode &&
                        !showMarkerSheet &&
                        !isShowingSheet else { return }
                
                let location = value.location
                let totalOffset = gestureState.panOffset.width
                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
                
                // Use UNIFIED hit detection
                if let marker = ChartMarkerSystem.findMarkerAtLocation(
                    location,
                    markers: markerManager.filteredMarkers,
                    candles: chartData.candles,
                    chartSize: geometry.size,
                    priceRange: chartData.priceRange,
                    priceScale: gestureState.priceScale,
                    verticalOffset: totalVerticalOffset,
                    totalCandleWidth: totalCandleWidth,
                    actualCandleWidth: actualCandleWidth,
                    totalOffset: totalOffset
                ) {
                    markerHaptic.impactOccurred()
                    tappedMarkerId = marker.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        tappedMarkerId = nil
                    }
                    markerManager.selectedMarker = marker
                }
            }
    }
    
    // MARK: - Pan Gesture
    
    /// Drag gesture for panning the chart horizontally and vertically
    /// FIXED: Uses incremental updates to eliminate spring-back animation
    /// When crosshair is active, moves the crosshair by drag delta
    /// - Parameters:
    ///   - size: Chart view size for boundary calculations
    ///   - coordinateSystem: Coordinate converter for crosshair positioning
    /// - Returns: Pan drag gesture
    private func dragGesture(in size: CGSize, coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // If crosshair is active, move it by drag delta
                if crosshairManager.isActive {
                    if crosshairDragStartPosition == nil {
                        crosshairDragStartPosition = crosshairManager.position
                    }
                    
                    if let startPos = crosshairDragStartPosition {
                        let newPosition = CGPoint(
                            x: startPos.x + value.translation.width,
                            y: startPos.y + value.translation.height
                        )
                        
                        let clampedPosition = CGPoint(
                            x: max(0, min(size.width, newPosition.x)),
                            y: max(0, min(size.height, newPosition.y))
                        )
                        
                        crosshairManager.updatePosition(
                            clampedPosition,
                            coordinateSystem: coordinateSystem,
                            chartData: chartData
                        )
                    }
                    return
                }
                
                // Normal panning - apply INCREMENTALLY for no spring-back
                if !isDraggingOnYAxis && !isPinchingOnYAxis && !isMarkerBeingDragged {
                    // Calculate incremental change since last update
                    let incrementalX = value.translation.width - lastDragTranslation.width
                    let incrementalY = -(value.translation.height - lastDragTranslation.height)
                    
                    // Apply incremental pan immediately to gestureState
                    gestureState.applyPan(
                        translation: CGSize(width: incrementalX, height: incrementalY),
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale
                    )
                    
                    // Update last translation for next increment
                    lastDragTranslation = value.translation
                }
            }
            .onEnded { value in
                // Clear crosshair drag state
                if crosshairManager.isActive {
                    crosshairDragStartPosition = nil
                }
                
                // Reset drag tracking - NO ANIMATION, instant reset
                lastDragTranslation = .zero
                dragState = .zero
            }
    }
    
    // MARK: - Pinch Gesture
    
    /// Pinch gesture for horizontal zoom (changes candle width)
    /// Scales symmetrically from screen center - candles expand/contract left and right
    /// Dampened for smooth, controlled zooming
    /// - Parameter size: Chart view size for center calculations
    /// - Returns: Magnification pinch gesture
    private func pinchGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Disable zoom while crosshair is active
                guard !crosshairManager.isActive && !isMarkerBeingDragged && !isPinchingOnYAxis else { return }
                
                // Initialize on first pinch
                if !isPinchingOnChart {
                    isPinchingOnChart = true
                    initialCandleWidthScale = gestureState.candleWidthScale
                    initialHorizontalOffset = gestureState.panOffset.width
                    pinchCenterX = size.width / 2  // Use screen center as pinch center
                    print("🤏 Horizontal pinch started - scale: \(initialCandleWidthScale), offset: \(initialHorizontalOffset)")
                }
                
                // Apply dampening to make pinch feel smooth and controlled
                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                let newScale = initialCandleWidthScale * dampenedValue
                let clampedScale = Swift.min(maxHorizontalScale, Swift.max(minHorizontalScale, newScale))
                
                // CRITICAL: We need to use total width ratio (candle + spacing), not just scale ratio
                // Because spacing is FIXED and doesn't scale, the relationship is more complex
                let oldTotalWidth = baseCandleWidth * initialCandleWidthScale + candleSpacing
                let newTotalWidth = baseCandleWidth * clampedScale + candleSpacing
                let totalWidthRatio = newTotalWidth / oldTotalWidth
                
                // Calculate new offset using interpolation with TOTAL width ratio
                // This causes candles to expand/contract symmetrically left and right
                let newHorizontalOffset = initialHorizontalOffset * totalWidthRatio + pinchCenterX * (1.0 - totalWidthRatio)
                
                // Apply both scale and offset
                gestureState.candleWidthScale = clampedScale
                gestureState.panOffset.width = newHorizontalOffset
                
                print("📊 Pinch: scale=\(String(format: "%.2f", clampedScale)), offset=\(String(format: "%.1f", newHorizontalOffset)), widthRatio=\(String(format: "%.3f", totalWidthRatio))")
            }
            .onEnded { _ in
                isPinchingOnChart = false
                print("🤏 Horizontal pinch ended - final scale: \(gestureState.candleWidthScale)")
            }
    }
    
    // MARK: - Y-Axis Gestures
    
    /// Drag gesture on Y-axis area for vertical price scaling
    /// Scales from screen center to keep visible content stable
    /// Drag up = zoom in (increase scale), Drag down = zoom out (decrease scale)
    private var yAxisDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Initialize on first drag
                if !isDraggingOnYAxis {
                    // Safety: Clear pinch flag if it's stuck
                    if isPinchingOnYAxis {
                        print("⚠️ Clearing stuck pinch flag")
                        isPinchingOnYAxis = false
                    }
                    
                    isDraggingOnYAxis = true
                    yAxisDragStart = value.startLocation.y
                    initialPriceScale = gestureState.priceScale
                    initialVerticalOffset = gestureState.verticalPanOffset
                    print("🎯 Y-axis drag started - scale: \(initialPriceScale), offset: \(initialVerticalOffset)")
                }
                
                // Calculate drag distance from start
                let dragDistance = value.location.y - yAxisDragStart
                
                // Convert to scale factor (drag up = zoom in, drag down = zoom out)
                // Using 300 as the distance for 1x change in scale
                let scaleMultiplier = 1.0 - (dragDistance / 300.0) * yAxisSensitivity
                let newScale = initialPriceScale * scaleMultiplier
                let clampedScale = Swift.min(maxVerticalScale, Swift.max(minVerticalScale, newScale))
                
                // Calculate offset adjustment to keep screen center at same price
                // This causes candles to expand/contract symmetrically from center
                let chartHeight = UIScreen.main.bounds.height
                let screenCenterY = chartHeight / 2
                
                // CORRECT formula: interpolate between initialOffset and screenCenter
                // This ensures the price at screen center stays at screen center
                // Candles above center move up, candles below center move down
                let scaleRatio = clampedScale / initialPriceScale
                let newVerticalOffset = initialVerticalOffset * scaleRatio + screenCenterY * (1.0 - scaleRatio)
                
                // Apply both scale and offset
                gestureState.priceScale = clampedScale
                gestureState.verticalPanOffset = newVerticalOffset
            }
            .onEnded { _ in
                isDraggingOnYAxis = false
                print("🎯 Y-axis drag ended - final scale: \(gestureState.priceScale)")
            }
    }
    
    /// Pinch gesture on Y-axis area for vertical price scaling
    /// Scales from screen center to keep visible content stable
    /// Alternative to drag gesture - uses two-finger pinch for more natural scaling
    private var yAxisPinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Initialize on first pinch
                if !isPinchingOnYAxis {
                    // Safety: Clear drag flag if it's stuck
                    if isDraggingOnYAxis {
                        print("⚠️ Clearing stuck drag flag")
                        isDraggingOnYAxis = false
                    }
                    
                    isPinchingOnYAxis = true
                    initialPriceScale = gestureState.priceScale
                    initialVerticalOffset = gestureState.verticalPanOffset
                    print("🤏 Y-axis pinch started - scale: \(initialPriceScale), offset: \(initialVerticalOffset)")
                }
                
                // Apply dampening to make pinch feel smooth and controlled
                let dampenedValue = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
                let newScale = initialPriceScale * dampenedValue
                let clampedScale = Swift.min(maxVerticalScale, Swift.max(minVerticalScale, newScale))
                
                // Calculate offset adjustment to keep screen center at same price
                // This causes candles to expand/contract symmetrically from center
                let chartHeight = UIScreen.main.bounds.height
                let screenCenterY = chartHeight / 2
                
                // CORRECT formula: interpolate between initialOffset and screenCenter
                // This ensures the price at screen center stays at screen center
                // Candles above center move up, candles below center move down
                let scaleRatio = clampedScale / initialPriceScale
                let newVerticalOffset = initialVerticalOffset * scaleRatio + screenCenterY * (1.0 - scaleRatio)
                
                // Apply both scale and offset
                gestureState.priceScale = clampedScale
                gestureState.verticalPanOffset = newVerticalOffset
            }
            .onEnded { _ in
                isPinchingOnYAxis = false
                print("🤏 Y-axis pinch ended - final scale: \(gestureState.priceScale)")
            }
    }
    
    // MARK: - Axis Overlays
    
    @ViewBuilder
    func xAxisOverlay(geometry: GeometryProxy) -> some View {
        // Calculate the bottom area height (includes bottom sheet space)
        let bottomAreaHeight = geometry.size.height * 0.11
        
        VStack(spacing: 0) {
            Spacer()
            
            // X-AXIS LABELS
            Canvas { context, size in
                let totalOffset = gestureState.panOffset.width
                let timeframe = chartViewModel.currentTimeframe
                
                // Calculate visible range with buffer
                let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 30)
                let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 60)
                
                guard visibleStartIndex < visibleEndIndex else { return }
                
                // Get the nice time interval for this timeframe and zoom level
                let niceInterval = getNiceTimeInterval(timeframe: timeframe, zoomScale: gestureState.candleWidthScale)
                
                // Track drawn positions to avoid overlap
                var drawnPositions: [CGFloat] = []
                
                // FIXED: Adaptive minimum spacing based on timeframe
                // M1/M5 need tighter spacing to show more labels
                let minLabelSpacing: CGFloat
                switch timeframe {
                case .m1:
                    minLabelSpacing = 40  // Tighter for M1
                case .m5:
                    minLabelSpacing = 45  // Tighter for M5
                case .m15, .m30:
                    minLabelSpacing = 50
                default:
                    minLabelSpacing = 55
                }
                
                // First pass: Draw DATE labels at midnight (these take priority)
                for i in visibleStartIndex..<visibleEndIndex {
                    guard i >= 0 && i < chartData.candles.count else { continue }
                    
                    let candle = chartData.candles[i]
                    let x = CGFloat(i) * totalCandleWidth + totalOffset + actualCandleWidth / 2
                    
                    guard x >= -50 && x <= size.width + 50 else { continue }
                    
                    // Check if this candle is at midnight (date boundary)
                    if isAtMidnight(candle.timestamp, timeframe: timeframe) {
                        // Check not too close to existing labels
                        let tooClose = drawnPositions.contains { abs($0 - x) < minLabelSpacing }
                        if tooClose { continue }
                        
                        let dateText = formatDateLabel(candle.timestamp, timeframe: timeframe)
                        
                        // Draw date label in BOLD WHITE
                        context.draw(
                            Text(dateText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white),
                            at: CGPoint(x: x, y: 10)
                        )
                        
                        drawnPositions.append(x)
                    }
                }
                
                // Second pass: Draw TIME labels at nice boundaries
                for i in visibleStartIndex..<visibleEndIndex {
                    guard i >= 0 && i < chartData.candles.count else { continue }
                    
                    let candle = chartData.candles[i]
                    let x = CGFloat(i) * totalCandleWidth + totalOffset + actualCandleWidth / 2
                    
                    guard x >= -50 && x <= size.width + 50 else { continue }
                    
                    // Skip midnight candles (already drawn as date labels)
                    if isAtMidnight(candle.timestamp, timeframe: timeframe) {
                        continue
                    }
                    
                    // Check if this candle falls on a nice time boundary
                    if isNiceTimeBoundary(candle.timestamp, interval: niceInterval, timeframe: timeframe) {
                        // Check not too close to existing labels
                        let tooClose = drawnPositions.contains { abs($0 - x) < minLabelSpacing }
                        if tooClose { continue }
                        
                        let timeText = formatTimeLabel(candle.timestamp, timeframe: timeframe)
                        
                        // Draw time label in gray
                        context.draw(
                            Text(timeText)
                                .font(.system(size: 11))
                                .foregroundColor(.gray),
                            at: CGPoint(x: x, y: 10)
                        )
                        
                        drawnPositions.append(x)
                    }
                }
            }
            .frame(height: 22)
            .padding(.top, 10)
            .background(Color.black)
            
            // SOLID BLACK AREA below X-axis to hide any chart content
            // This extends to the bottom of the visible area (before bottom sheet)
            Rectangle()
                .fill(Color.black)
                .frame(height: bottomAreaHeight)
                
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - X-Axis Time Helpers
    
    /// Get the "nice" time interval in minutes based on timeframe and zoom
    /// FIXED: Correct thresholds so M1/M5 show more labels at default zoom (1.0)
    private func getNiceTimeInterval(timeframe: ChartTimeframe, zoomScale: CGFloat) -> Int {
        switch timeframe {
        case .m1:
            // M1: At default zoom (1.0), show every 5 minutes
            // The key is using <= instead of > to include the boundary values
            if zoomScale >= 2.5 {
                return 1    // Very zoomed in: every 1 minute
            } else if zoomScale >= 1.8 {
                return 2    // Highly zoomed in: every 2 minutes
            } else if zoomScale >= 1.2 {
                return 3    // Zoomed in: every 3 minutes
            } else if zoomScale >= 0.8 {
                return 5    // Normal (includes 1.0): every 5 minutes
            } else if zoomScale >= 0.5 {
                return 10   // Zoomed out: every 10 minutes
            } else if zoomScale >= 0.35 {
                return 15   // More zoomed out: every 15 minutes
            } else {
                return 30   // Very zoomed out: every 30 minutes
            }
            
        case .m5:
            // M5: At default zoom (1.0), show every 15 minutes
            if zoomScale >= 2.5 {
                return 5    // Very zoomed in: every 5 minutes (each candle)
            } else if zoomScale >= 1.8 {
                return 10   // Highly zoomed in: every 10 minutes
            } else if zoomScale >= 0.8 {
                return 15   // Normal (includes 1.0): every 15 minutes
            } else if zoomScale >= 0.5 {
                return 30   // Zoomed out: every 30 minutes
            } else if zoomScale >= 0.35 {
                return 60   // More zoomed out: every hour
            } else {
                return 120  // Very zoomed out: every 2 hours
            }
            
        case .m15:
            // M15: Every 15, 30, 60, or 120 min
            if zoomScale >= 2.0 {
                return 15   // Zoomed in: every 15 minutes (each candle)
            } else if zoomScale >= 1.2 {
                return 30   // Slightly zoomed: every 30 minutes
            } else if zoomScale >= 0.6 {
                return 60   // Normal: every hour
            } else {
                return 120  // Zoomed out: every 2 hours
            }
            
        case .m30:
            // M30: Every 30, 60, 120, or 240 min
            if zoomScale >= 2.0 {
                return 30   // Zoomed in: every 30 minutes (each candle)
            } else if zoomScale >= 1.2 {
                return 60   // Slightly zoomed: every hour
            } else if zoomScale >= 0.6 {
                return 120  // Normal: every 2 hours
            } else {
                return 240  // Zoomed out: every 4 hours
            }
            
        case .h1:
            // H1: Every 1, 2, 4, or 8 hours
            if zoomScale >= 2.0 {
                return 60   // Zoomed in: every hour (each candle)
            } else if zoomScale >= 1.2 {
                return 120  // Slightly zoomed: every 2 hours
            } else if zoomScale >= 0.6 {
                return 240  // Normal: every 4 hours
            } else {
                return 480  // Zoomed out: every 8 hours
            }
            
        case .h4:
            // H4: Every 4, 8, 12, or 24 hours
            // H4 candles are ONLY at: 00, 04, 08, 12, 16, 20
            if zoomScale >= 2.0 {
                return 240  // Zoomed in: every 4 hours (each candle)
            } else if zoomScale >= 1.2 {
                return 480  // Slightly zoomed: every 8 hours
            } else if zoomScale >= 0.6 {
                return 720  // Normal: every 12 hours
            } else {
                return 1440 // Zoomed out: every 24 hours
            }
            
        case .d1:
            // D1: Every 2, 5, 7, or 14 days
            if zoomScale >= 2.0 {
                return 1440 * 2  // Zoomed in: every 2 days
            } else if zoomScale >= 1.2 {
                return 1440 * 5  // Slightly zoomed: every 5 days
            } else if zoomScale >= 0.6 {
                return 1440 * 7  // Normal: every week
            } else {
                return 1440 * 14 // Zoomed out: every 2 weeks
            }
            
        case .w1:
            // W1: Every 1 or 2 weeks
            if zoomScale >= 1.2 {
                return 1440 * 7     // Zoomed in: every week
            } else if zoomScale >= 0.6 {
                return 1440 * 14    // Normal: every 2 weeks
            } else {
                return 1440 * 28    // Zoomed out: every 4 weeks
            }
            
        case .mn:
            // MN: Every 1 or 3 months
            if zoomScale >= 1.0 {
                return 1440 * 30    // Zoomed in: monthly
            } else {
                return 1440 * 90    // Zoomed out: quarterly
            }
        }
    }
    
    /// Check if a timestamp falls on a "nice" time boundary
    /// FIXED: Better handling for H4 and D1
    private func isNiceTimeBoundary(_ timestamp: Date, interval: Int, timeframe: ChartTimeframe) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        let minute = calendar.component(.minute, from: timestamp)
        
        switch timeframe {
        case .m1:
            // M1: Check minute alignment
            if interval <= 1 {
                return true  // Every minute
            } else if interval < 60 {
                return minute % interval == 0
            } else {
                let intervalHours = interval / 60
                return minute == 0 && hour % intervalHours == 0
            }
            
        case .m5:
            // M5: Check 5-minute alignment
            if interval <= 5 {
                return minute % 5 == 0  // Every M5 candle
            } else if interval < 60 {
                return minute % interval == 0
            } else {
                let intervalHours = interval / 60
                return minute == 0 && hour % intervalHours == 0
            }
            
        case .m15:
            // M15: Check 15-minute alignment
            if interval <= 15 {
                return minute % 15 == 0  // Every M15 candle
            } else if interval < 60 {
                return minute % interval == 0
            } else {
                let intervalHours = interval / 60
                return minute == 0 && hour % intervalHours == 0
            }
            
        case .m30:
            // M30: Check 30-minute alignment
            if interval <= 30 {
                return minute % 30 == 0  // Every M30 candle
            } else {
                let intervalHours = interval / 60
                return minute == 0 && hour % intervalHours == 0
            }
            
        case .h1:
            // H1: Check hourly alignment
            let intervalHours = max(1, interval / 60)
            return minute == 0 && hour % intervalHours == 0
            
        case .h4:
            // H4: FIXED - Check against actual H4 boundaries (0, 4, 8, 12, 16, 20)
            let validH4Hours = [0, 4, 8, 12, 16, 20]
            guard validH4Hours.contains(hour) && minute == 0 else { return false }
            
            let intervalHours = max(4, interval / 60)
            if intervalHours <= 4 {
                return true  // Every H4 candle
            } else if intervalHours <= 8 {
                // Every 8 hours: 0, 8, 16
                return [0, 8, 16].contains(hour)
            } else if intervalHours <= 12 {
                // Every 12 hours: 0, 12
                return [0, 12].contains(hour)
            } else {
                // Every 24 hours: midnight only
                return hour == 0
            }
            
        case .d1:
            // D1: FIXED - Check day intervals properly
            let intervalDays = interval / 1440
            if intervalDays <= 2 {
                // Every 1-2 days: check if day number is even/odd
                let day = calendar.component(.day, from: timestamp)
                return intervalDays <= 1 || day % 2 == 1
            } else if intervalDays <= 5 {
                // Every ~5 days: show Mon and Thu
                let weekday = calendar.component(.weekday, from: timestamp)
                return weekday == 2 || weekday == 5  // Monday and Thursday
            } else if intervalDays <= 7 {
                // Weekly: show Mondays only
                let weekday = calendar.component(.weekday, from: timestamp)
                return weekday == 2
            } else {
                // Bi-weekly: show 1st and 15th of month
                let day = calendar.component(.day, from: timestamp)
                return day == 1 || day == 15
            }
            
        case .w1:
            // Weekly: check week boundaries
            let day = calendar.component(.day, from: timestamp)
            let intervalWeeks = interval / (1440 * 7)
            if intervalWeeks <= 1 {
                return true  // Every week
            } else if intervalWeeks <= 2 {
                // Bi-weekly: first and third week
                return day <= 7 || (day >= 15 && day <= 21)
            } else {
                // Monthly: first week only
                return day <= 7
            }
            
        case .mn:
            // Monthly: check month boundaries
            let month = calendar.component(.month, from: timestamp)
            let intervalMonths = interval / (1440 * 30)
            if intervalMonths <= 1 {
                return true  // Every month
            } else {
                // Quarterly
                return [1, 4, 7, 10].contains(month)
            }
        }
    }
    
    /// Check if timestamp is at midnight (for date labels)
    private func isAtMidnight(_ timestamp: Date, timeframe: ChartTimeframe) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        let minute = calendar.component(.minute, from: timestamp)
        
        switch timeframe {
        case .m1:
            // M1: The 00:00 candle exactly
            return hour == 0 && minute == 0
        case .m5:
            // M5: The 00:00 candle (might be 00:00 or 00:05 depending on alignment)
            return hour == 0 && minute <= 5
        case .m15:
            // M15: The 00:00 candle
            return hour == 0 && minute == 0
        case .m30:
            // M30: The 00:00 candle
            return hour == 0 && minute == 0
        case .h1, .h4:
            // Hourly: The 00:00 candle
            return hour == 0
        case .d1:
            // Daily: First of month
            let day = calendar.component(.day, from: timestamp)
            return day == 1
        case .w1:
            // Weekly: First week of month
            let day = calendar.component(.day, from: timestamp)
            return day <= 7
        case .mn:
            // Monthly: Quarter start
            let month = calendar.component(.month, from: timestamp)
            return [1, 4, 7, 10].contains(month)
        }
    }
    
    /// Format a date label for display (shown at midnight/boundaries in BOLD)
    private func formatDateLabel(_ timestamp: Date, timeframe: ChartTimeframe) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .m1, .m5, .m15, .m30, .h1, .h4:
            // Intraday: Show day/month
            formatter.dateFormat = "dd/MM"
        case .d1:
            // Daily: Show month name
            formatter.dateFormat = "MMM"
        case .w1:
            // Weekly: Show month and year
            formatter.dateFormat = "MMM yy"
        case .mn:
            // Monthly: Show quarter
            let calendar = Calendar.current
            let month = calendar.component(.month, from: timestamp)
            let year = calendar.component(.year, from: timestamp)
            let quarter = (month - 1) / 3 + 1
            return "Q\(quarter) '\(year % 100)"
        }
        
        return formatter.string(from: timestamp)
    }
    
    /// Format a time label for display (shown at nice time boundaries in gray)
    private func formatTimeLabel(_ timestamp: Date, timeframe: ChartTimeframe) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .m1, .m5, .m15, .m30, .h1, .h4:
            // Intraday: Show HH:mm
            formatter.dateFormat = "HH:mm"
        case .d1:
            // Daily: Show day number
            formatter.dateFormat = "dd"
        case .w1:
            // Weekly: Show day and month
            formatter.dateFormat = "dd MMM"
        case .mn:
            // Monthly: Show month and year
            formatter.dateFormat = "MMM yy"
        }
        
        return formatter.string(from: timestamp)
    }
    
    // MARK: - Y-Axis Overlay (Symbol-Aware Formatting)
    
    /// Y-axis overlay with symbol-aware price formatting
    /// FIXED: Uses zoom-aware PriceAxisHelper for proper grid density
    @ViewBuilder
    func yAxisOverlay(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            Canvas { context, size in
                let priceRange = chartData.priceRange
                let scaledHeight = geometry.size.height * gestureState.priceScale
                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
                
                // Use PriceAxisHelper with chart height for zoom-aware calculation
                let priceHelper = PriceAxisHelper(
                    symbol: currentSymbol,
                    priceRange: priceRange,
                    priceScale: gestureState.priceScale,
                    chartHeight: geometry.size.height
                )
                
                let step = priceHelper.nicePriceStep
                
                // VERY extended range - prices should NEVER run out
                let extendedStartPrice = floor((priceRange.min - step * 30) / step) * step
                let extendedEndPrice = ceil((priceRange.max + step * 30) / step) * step
                
                var currentPrice = extendedStartPrice
                var labelCount = 0
                let maxLabels = 100  // Generous limit for zoomed-in views
                
                while currentPrice <= extendedEndPrice && labelCount < maxLabels {
                    let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
                    let y = size.height - (CGFloat(normalizedPrice) * scaledHeight) - totalVerticalOffset
                    
                    // Very extended bounds
                    if y >= -300 && y <= size.height + 300 {
                        let priceText = chartData.formatPrice(currentPrice)
                        
                        context.draw(
                            Text(priceText)
                                .font(.system(size: 11))
                                .foregroundColor(.gray),
                            at: CGPoint(x: 30, y: y)
                        )
                        labelCount += 1
                    }
                    
                    currentPrice += step
                }
            }
            .frame(width: yAxisWidth)
            .background(Color.black.opacity(0.8))
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Chart Info Box
    
    /// Top-left info box showing symbol, timeframe, price, and guild
    @ViewBuilder
    func chartInfoBox(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Symbol and timeframe row
                    HStack(spacing: 8) {
                        // Symbol
                        Text(currentSymbol?.symbol ?? "—")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Timeframe badge
                        Text(currentTimeframe.shortName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.6))
                            .cornerRadius(4)
                    }
                    
                    // Price row
                    HStack(spacing: 6) {
                        Text(chartData.formatPrice(chartData.currentPrice))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(priceChangeColor)
                        
                        // Price change indicator (simple up/down)
                        if let lastCandle = chartData.candles.last,
                           chartData.candles.count > 1,
                           let prevCandle = chartData.candles.dropLast().last {
                            let change = lastCandle.close - prevCandle.close
                            let changePercent = (change / prevCandle.close) * 100
                            
                            HStack(spacing: 2) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text(String(format: "%.2f%%", abs(changePercent)))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(change >= 0 ? .green : .red)
                        }
                    }
                    
                    // Guild indicator (optional - only show if guild context exists)
                    // Uncomment below to show guild name
                    // Text("Guild Name")
                    //     .font(.system(size: 10))
                    //     .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(.leading, 8)
            .padding(.top, 8)
            
            Spacer()
        }
        .allowsHitTesting(false)
    }
    
    
    // MARK: - Chart Controls Box
    
    /// Top-left info box showing symbol, timeframe, price, and guild
    @ViewBuilder
    func chartControlsBox(geometry: GeometryProxy) -> some View {
        let bottomAreaHeight = geometry.size.height * 0.11 + 40
        let yaxisOverlayWidth = yAxisWidth + 10
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Spacer()
                ChartBottomControlButton(
                    title: "Reset",
                    icon: "arrow.counterclockwise",
                    color: .white.opacity(0.5)
                ) {
                    controlViewModel.resetChart()
                }
                .allowsHitTesting(true)
                
                ChartBottomControlButton(
                    title: "Latest",
                    icon: "arrow.right.to.line",
                    color: .white.opacity(0.5)
                ) {
                    controlViewModel.jumpToLatest()
                }
                .allowsHitTesting(true)
            }
            
            .padding(.bottom, bottomAreaHeight)
            .padding(.trailing, yaxisOverlayWidth)
        }
    }
    
    /// Color for price display based on recent movement
    private var priceChangeColor: Color {
        guard chartData.candles.count > 1,
              let lastCandle = chartData.candles.last,
              let prevCandle = chartData.candles.dropLast().last else {
            return .white
        }
        
        if lastCandle.close > prevCandle.close {
            return .green
        } else if lastCandle.close < prevCandle.close {
            return .red
        } else {
            return .white
        }
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
        let totalOffset = gestureState.panOffset.width
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
            totalOffset: totalOffset,
            markerManager: markerManager,
            selectedMarkerId: markerManager.selectedMarker?.id ?? tappedMarkerId
        )
    }
    
    /// Draw background grid for visual reference
    /// FIXED: Grid lines EXACTLY match axis labels, zoom-aware density
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let priceRange = chartData.priceRange
        let scaledHeight = size.height * gestureState.priceScale
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
        let totalOffset = gestureState.panOffset.width
        let timeframe = chartViewModel.currentTimeframe
        
        let gridPath = Path { path in
            
            // ========================================
            // VERTICAL GRID LINES
            // TIME-BASED: Draws lines at nice time boundaries
            // (matches X-axis labels for consistency)
            // ========================================
            
            let niceInterval = getNiceTimeInterval(timeframe: timeframe, zoomScale: gestureState.candleWidthScale)
            
            let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 30)
            let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 60)
            
            // FIXED: Guard against invalid range when candles array changes during timeframe switch
            guard visibleStartIndex < visibleEndIndex else { return }
            
            for i in visibleStartIndex..<visibleEndIndex {
                guard i >= 0 && i < chartData.candles.count else { continue }
                
                let candle = chartData.candles[i]
                
                // Draw grid line at nice time boundaries OR midnight
                let isMidnight = isAtMidnight(candle.timestamp, timeframe: timeframe)
                let isNiceBoundary = isNiceTimeBoundary(candle.timestamp, interval: niceInterval, timeframe: timeframe)
                
                if isMidnight || isNiceBoundary {
                    let x = CGFloat(i) * totalCandleWidth + totalOffset + actualCandleWidth / 2
                    
                    if x >= -100 && x <= size.width + 100 {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
            }
            
            // ========================================
            // HORIZONTAL GRID LINES
            // Zoom-aware step calculation (same as Y-axis)
            // ========================================
            
            let priceHelper = PriceAxisHelper(
                symbol: currentSymbol,
                priceRange: priceRange,
                priceScale: gestureState.priceScale,
                chartHeight: size.height
            )
            
            let step = priceHelper.nicePriceStep
            
            // VERY extended range - grid should NEVER run out
            let extendedStartPrice = floor((priceRange.min - step * 30) / step) * step
            let extendedEndPrice = ceil((priceRange.max + step * 30) / step) * step
            
            var currentPrice = extendedStartPrice
            var lineCount = 0
            let maxLines = 100  // Safety limit
            
            while currentPrice <= extendedEndPrice && lineCount < maxLines {
                let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
                let y = size.height - (CGFloat(normalizedPrice) * scaledHeight) - totalVerticalOffset
                
                // Very extended bounds
                if y >= -500 && y <= size.height + 500 {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    lineCount += 1
                }
                
                currentPrice += step
            }
        }
        
        context.stroke(gridPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
    }
    
    /// Calculate the candle stride for vertical grid lines based on horizontal zoom
    /// Returns how many candles between each vertical grid line
    /// - Returns: Candle stride (1, 2, 3, 5, 10, 20, etc.)
    private func calculateCandleStride() -> Int {
        let zoomFactor = gestureState.candleWidthScale
        
        // More zoom = smaller stride (more lines)
        // Less zoom = larger stride (fewer lines)
        if zoomFactor > 2.5 {
            return 2  // Very zoomed in: line every 2 candles
        } else if zoomFactor > 2.0 {
            return 3  // Highly zoomed in: line every 3 candles
        } else if zoomFactor > 1.5 {
            return 4  // Zoomed in: line every 4 candles
        } else if zoomFactor >= 0.8 {
            return 5  // Normal: line every 5 candles
        } else if zoomFactor >= 0.5 {
            return 10  // Zoomed out: line every 10 candles
        } else {
            return 20  // Very zoomed out: line every 20 candles
        }
    }
    
    /// Calculate a "nice" price step for grid lines and labels
    /// Returns values like 0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10, 20, 50, 100, etc.
    /// Adjusts target grid count based on zoom level for dynamic density
    /// - Parameter range: The total price range to display
    /// - Returns: A nice step value
    private func calculateNicePriceStep(range: Double) -> Double {
        // Adjust target grid lines based on zoom level
        // UPDATED: Increased base from 10 to 14 for denser Y-axis grid
        let baseTargetLines: Double = 14.0
        let zoomFactor = gestureState.priceScale
        
        // Scale inversely with zoom: more zoom = more lines
        let targetLines: Double
        if zoomFactor > 2.0 {
            targetLines = baseTargetLines * 1.3  // 18 lines when highly zoomed in
        } else if zoomFactor > 1.5 {
            targetLines = baseTargetLines * 1.2  // 17 lines
        } else if zoomFactor < 0.7 {
            targetLines = baseTargetLines * 0.7  // 10 lines when zoomed out
        } else {
            targetLines = baseTargetLines  // 14 lines at normal zoom
        }
        
        // Target the adjusted number of grid lines
        let roughStep = range / targetLines
        
        // Find the magnitude (power of 10)
        let magnitude = pow(10.0, floor(log10(roughStep)))
        
        // Normalize to 1-10 range
        let normalized = roughStep / magnitude
        
        // Pick nice number: 1, 2, 5, or 10
        let niceNormalized: Double
        if normalized <= 1.5 {
            niceNormalized = 1.0
        } else if normalized <= 3.0 {
            niceNormalized = 2.0
        } else if normalized <= 7.0 {
            niceNormalized = 5.0
        } else {
            niceNormalized = 10.0
        }
        
        return niceNormalized * magnitude
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
        let totalOffset = gestureState.panOffset.width
        
        // Calculate visible candle range for performance
        // Only draw candles that are actually on screen
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            Swift.max(visibleStartIndex, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
        )

        // Safe guard - prevents crash when panning past chart bounds
        guard visibleStartIndex < visibleEndIndex else { return }

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
    
    // MARK: - Control Actions Setup

    /// Set up action closures for the control ViewModel
    private func setupControlActions() {
        // Reset chart to default state
        controlViewModel.resetChartAction = {
            self.gestureState.reset()
        }
        
        // Jump to the first candle
        controlViewModel.jumpToStartAction = {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.gestureState.panOffset.width = 0
            }
        }
        
        // Jump to the most recent candle
        controlViewModel.jumpToLatestAction = {
            guard !self.chartData.candles.isEmpty else { return }
            let targetOffset = -CGFloat(self.chartData.candles.count - 1) * self.totalCandleWidth + 100
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.gestureState.panOffset.width = targetOffset
            }
        }
        
        // Toggle auto-scroll
        controlViewModel.toggleAutoScrollAction = {
            // If it's a @Published property:
            print("Auto-scroll toggled")
            
            // OR if it needs to be set directly:
            // self.navigationManager.isAutoScrolling = !self.navigationManager.isAutoScrolling
        }
        
        // Set horizontal zoom
        controlViewModel.setHorizontalZoomAction = { zoom in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.gestureState.candleWidthScale = CGFloat(zoom)
            }
        }
        
        // Set vertical zoom
        controlViewModel.setVerticalZoomAction = { zoom in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.gestureState.priceScale = CGFloat(zoom)
            }
        }
    }
}

// MARK: - ChartBottomControlButton

struct ChartBottomControlButton: View {
    let title: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? .white : color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                
            }
//            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(
                isActive ?
                color :
                Color.white.opacity(0.08)
            )
            .cornerRadius(2)
            
            
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Horizontal Line Preview Helper View

/// Helper view to show horizontal line preview during marker placement
/// Extracted to reduce type-checking complexity in main view
struct MarkerHorizontalLinePreview: View {
    let candle: Candle
    let markerType: MarkerType
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartData: ChartDataManager
    
    private var linePrice: Double {
        switch markerType.lineSource {
        case .candleOpen:
            return candle.open
        case .candleClose:
            return candle.close
        case .candleHigh:
            return candle.high
        case .candleLow:
            return candle.low
        case .custom, .none:
            return candle.close
        }
    }
    
    private var lineY: CGFloat {
        coordinateSystem.yPosition(forPrice: linePrice)
    }
    
    var body: some View {
        ZStack {
            // Horizontal line
            Path { path in
                path.move(to: CGPoint(x: 0, y: lineY))
                path.addLine(to: CGPoint(x: chartWidth - 65, y: lineY))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .foregroundColor(markerType.color.opacity(0.7))
            .allowsHitTesting(false)
            
            // Price label on left
            Text(chartData.formatPrice(linePrice))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(markerType.color)
                .cornerRadius(4)
                .position(x: 40, y: lineY)
                .allowsHitTesting(false)
        }
    }
}

