//
//  backup.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/12/2025.
//



//import SwiftUI
//
//// MARK: - Pending Marker Info
//
///// FIXED: Captures marker type at placement time to prevent sheet presentation errors
///// Now Identifiable to support sheet(item:) binding for more robust presentation
//struct PendingMarkerInfo: Identifiable {
//    let id = UUID()  // FIXED: Add id for Identifiable conformance
//    let candleIndex: Int
//    let timestamp: Date
//    let price: Double
//    let markerType: MarkerType
//    let targetPrice: Double?  // NEW: For prediction markers
//
//    // Convenience initializer without target price (for non-prediction markers)
//    init(candleIndex: Int, timestamp: Date, price: Double, markerType: MarkerType, targetPrice: Double? = nil) {
//        self.candleIndex = candleIndex
//        self.timestamp = timestamp
//        self.price = price
//        self.markerType = markerType
//        self.targetPrice = targetPrice
//    }
//}
//
///// Main trading chart view that handles all chart rendering and interactions
///// Features centered scaling that keeps visible candles in view during zoom
///// Includes marker placement system for collaborative chart annotations
//struct TradingChartView: View {
//    // MARK: - State Properties
//
//    // MARK: - Chart Context Accessors
//
//    private var currentTimeframe: ChartTimeframe {
//        chartViewModel.currentTimeframe
//    }
//
//    private var currentSymbol: TradingSymbol? {
//        chartViewModel.currentSymbol
//    }
//
//    // MARK: - Chart Control ViewModel
//    @ObservedObject var controlViewModel: ChartControlViewModel
//
//    /// Gesture state manager that handles all pan/zoom transformations
//    /// This is the single source of truth for chart positioning
//    @StateObject private var gestureState = ChartGestureState()
//
//    /// Current drag translation for smooth real-time panning feedback
//    /// Using @State instead of @GestureState to avoid spring-back animation
//    @State private var dragState: CGSize = .zero
//
//    /// Track the previous drag translation for incremental updates
//    @State private var lastDragTranslation: CGSize = .zero
//
//    /// Y-axis pinch scale for vertical price range scaling (not used but kept for reference)
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
//    /// Used to calculate total drag distance for scaling
//    @State private var yAxisDragStart: CGFloat = 0
//
//    /// The initial price scale when Y-axis gesture begins
//    /// Used as the base for calculating the new scale
//    @State private var initialPriceScale: CGFloat = 1.0
//
//    /// The initial vertical offset when Y-axis gesture begins
//    /// Used to properly adjust offset during scaling to keep center fixed
//    @State private var initialVerticalOffset: CGFloat = 0
//
//    /// Track if user is currently pinching on the main chart (horizontal zoom)
//    /// Used to store initial state for proper symmetric scaling
//    @State private var isPinchingOnChart = false
//
//    /// The initial candle width scale when chart pinch begins
//    /// Used as the base for calculating the new scale
//    @State private var initialCandleWidthScale: CGFloat = 1.0
//
//    /// The initial horizontal offset when chart pinch begins
//    /// Used to properly adjust offset during scaling to keep pinch center fixed
//    @State private var initialHorizontalOffset: CGFloat = 0
//
//    /// The X position of the pinch center when gesture begins
//    /// Used as the fixed point for symmetric horizontal scaling
//    @State private var pinchCenterX: CGFloat = 0
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
//    /// Whether we're in marker placement mode (user is positioning new marker)
//    /// When true, drag gestures move the preview marker instead of panning chart
//    // Marker placement mode is now controlled by ViewModel
//    private var isMarkerPlacementMode: Bool {
//        controlViewModel.isMarkerPlacementMode
//    }
//
//    /// Track if marker is actively being dragged (for scale animation)
//    @State private var isMarkerBeingDragged = false
//
//    /// Haptic feedback generator for marker interactions
//    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
//
//    /// Temporary storage for marker info before final creation
//    /// FIXED: Now Identifiable and used with sheet(item:) for robust presentation
//    /// Contains candle index, timestamp, price, and marker type of pending marker
//    @State private var pendingMarkerInfo: PendingMarkerInfo?
//
//    /// PREDICTION TARGET STATE
//    /// For prediction markers, user must set entry (candle) then target (draggable line)
//    /// Target price is selected via draggable horizontal line before opening config sheet
//    @State private var predictionTargetPrice: Double? = nil
//    @State private var isDraggingTarget: Bool = false
//    @State private var isAwaitingTargetSelection: Bool = false
//
//    /// Current candle index where the preview marker is positioned
//    /// Updates in real-time as user drags during placement mode
//    @State private var previewCandleIndex: Int = 0
//
//    /// Track the actual drag position for free-form marker movement
//    /// This allows marker to follow finger in 2D before snapping on release
//    @State private var markerDragPosition: CGPoint?
//
//    @State private var chartSize: CGSize = .zero
//
//    /// Stores crosshair position at start of drag for relative movement
//    /// This allows crosshair to move by delta instead of jumping to finger position
//    @State private var crosshairDragStartPosition: CGPoint? = nil
//
//
//    /// Whether to show duplicate marker type alert
//    @State private var showDuplicateMarkerAlert = false
//
//
//
//    /// Track if chart has been initialized with proper position
//    @State private var hasInitializedPosition = false
//
//    /// Track if chart is loading (waiting for data)
//    @State private var isChartLoading = true
//
//    /// Track the marker ID that was just tapped (for animation)
//    @State private var tappedMarkerId: UUID? = nil
//
//    /// Haptic feedback generator for marker interactions
//    private let markerHaptic = UIImpactFeedbackGenerator(style: .medium)
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
//    private let edgePadding: CGFloat = 200
//
//    /// Width of the Y-axis interaction area on the right side
//    /// This area captures vertical drag/pinch gestures for price scaling
//    private let yAxisWidth: CGFloat = 60
//
//    // MARK: - Chart View Model
//
//    /// Chart view model that coordinates chart state and data
//    @ObservedObject var chartViewModel: ChartViewModel
//
//    /// Shorthand accessor for data manager
//    /// This computed property lets us keep using "chartData" throughout the file
//    private var chartData: ChartDataManager {
//        chartViewModel.dataManager
//    }
//
//    // MARK: - Sensitivity Configuration
//
//    /// Dampening factor for horizontal pinch gesture (0.0 to 1.0)
//    /// Lower = less sensitive and smoother, Higher = more responsive but jittery
//    /// 0.15 provides a good balance for production use
//    private let pinchSensitivity: CGFloat = 0.7
//
//    /// Dampening factor for Y-axis drag/pinch scaling (0.0 to 1.0)
//    /// Controls how quickly vertical gestures change price scale
//    /// 0.15 = controlled (original), 0.25 = moderate, 0.35 = responsive, 0.5 = very sensitive
//    /// Higher values = faster scaling response, but may feel too jumpy
//    private let yAxisSensitivity: CGFloat = 0.7
//
//    // MARK: - Scale Limits Configuration
//
//    /// Maximum vertical scale (price axis)
//    /// How much you can zoom in vertically (taller candles)
//    /// 3.0 = 3x max height, 5.0 = 5x max height, 10.0 = 10x max height
//    private let maxVerticalScale: CGFloat = 5.0
//
//    /// Minimum vertical scale (price axis)
//    /// How much you can zoom out vertically (shorter candles)
//    /// 0.5 = half height, 0.3 = 30% height, 0.1 = 10% height
//    private let minVerticalScale: CGFloat = 0.5
//
//    /// Maximum horizontal scale (candle width)
//    /// How much you can zoom in horizontally (wider candles)
//    /// 3.0 = 3x max width, 5.0 = 5x max width
//    private let maxHorizontalScale: CGFloat = 3.0
//
//    /// Minimum horizontal scale (candle width)
//    /// How much you can zoom out horizontally (narrower candles)
//    /// 0.3 = 30% width, 0.1 = 10% width
//    private let minHorizontalScale: CGFloat = 0.3
//
//    // MARK: - Computed Properties
//
//    /// Actual width of each candle including current zoom scale
//    /// Uses the stored scale directly (no live pinch scale needed)
//    /// This is what's actually rendered on screen
//    private var actualCandleWidth: CGFloat {
//        baseCandleWidth * gestureState.candleWidthScale
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
//    /// FIXED: No longer uses dragState (translation applied incrementally)
//    private func clampedVerticalOffset(chartHeight: CGFloat) -> CGFloat {
//        // Use stored offset directly - incremental updates already applied
//        let totalOffset = gestureState.verticalPanOffset
//
//        // Calculate scaled height to determine valid pan range
//        let scaledHeight = chartHeight * gestureState.priceScale
//
//        // Very generous base limit
//        let baseMultiplier: CGFloat = 3.0
//
//        // Extra room when zoomed out so prices NEVER run out
//        let zoomAdjustment: CGFloat
//        if gestureState.priceScale < 0.5 {
//            zoomAdjustment = 4.0
//        } else if gestureState.priceScale < 0.7 {
//            zoomAdjustment = 3.0
//        } else if gestureState.priceScale < 0.9 {
//            zoomAdjustment = 2.0
//        } else if gestureState.priceScale > 2.0 {
//            zoomAdjustment = 2.0
//        } else {
//            zoomAdjustment = 1.5
//        }
//
//        let verticalPadding = scaledHeight * baseMultiplier * zoomAdjustment
//
//        // Hard clamp - no animation, just stop at the wall
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
//    ///   - controlViewModel: View model for chart controls
//    ///   - chartViewModel: View model for chart data and state
//    init(
//        userId: String = "user123",
//        username: String = "TestUser",
//        guildId: String = "guild1",
//        controlViewModel: ChartControlViewModel,
//        chartViewModel: ChartViewModel
//    ) {
//        _markerManager = StateObject(wrappedValue: MarkerManager(userId: userId, guildId: guildId))
//        self.controlViewModel = controlViewModel
//        self.chartViewModel = chartViewModel
//    }
//
//    // MARK: - Target Line Helpers
//
//    /// Whether to show interactive target line during selection
//    private var shouldShowInteractiveTargetLine: Bool {
//        guard let markerType = controlViewModel.currentMarkerType else { return false }
//        guard markerType == .predictionTarget else { return false }
//        guard previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count else { return false }
//        guard predictionTargetPrice != nil else { return false }
//        return true
//    }
//
//    /// Whether to show static target line during configuration
//    private var shouldShowStaticTargetLine: Bool {
//        guard let pending = pendingMarkerInfo else { return false }
//        guard pending.markerType == .predictionTarget else { return false }
//        guard pending.targetPrice != nil else { return false }
//        guard pending.candleIndex >= 0 && pending.candleIndex < chartData.candles.count else { return false }
//        return true
//    }
//
//    // MARK: - Marker Preview Helpers
//
//    /// Get the currently selected or tapped marker
//    private var activeSelectedMarker: ChartMarker? {
//        if let selected = markerManager.selectedMarker {
//            return selected
//        }
//        if let tappedId = tappedMarkerId {
//            return markerManager.markers.first(where: { $0.id == tappedId })
//        }
//        return nil
//    }
//
//    /// Get preview marker data for price line display
//    private var previewMarkerForPriceLine: (candle: Candle, type: MarkerType)? {
//        // When sheet is open (pendingMarkerInfo exists), use that data
//        if let pending = pendingMarkerInfo,
//           pending.candleIndex >= 0,
//           pending.candleIndex < chartData.candles.count,
//           pending.markerType.hasHorizontalLine {
//            return (chartData.candles[pending.candleIndex], pending.markerType)
//        }
//
//        // Otherwise use placement mode preview
//        if isMarkerPlacementMode,
//           previewCandleIndex >= 0,
//           previewCandleIndex < chartData.candles.count,
//           let markerType = controlViewModel.currentMarkerType,
//           markerType.hasHorizontalLine {
//            return (chartData.candles[previewCandleIndex], markerType)
//        }
//
//        return nil
//    }
//
//    /// Color for price display based on recent movement
//    private var priceChangeColor: Color {
//        guard chartData.candles.count > 1,
//              let lastCandle = chartData.candles.last,
//              let prevCandle = chartData.candles.dropLast().last else {
//            return .white
//        }
//
//        if lastCandle.close > prevCandle.close {
//            return .green
//        } else if lastCandle.close < prevCandle.close {
//            return .red
//        } else {
//            return .white
//        }
//    }
//
//    /// Whether loading overlay should be shown
//    private var shouldShowLoadingOverlay: Bool {
//        isChartLoading || chartViewModel.currentSymbol == nil || chartData.candles.isEmpty
//    }
//
//    /// Effective candle index for marker preview (from pending or placement mode)
//    private var effectiveCandleIndex: Int {
//        pendingMarkerInfo?.candleIndex ?? previewCandleIndex
//    }
//
//    /// Effective marker type for preview (from pending or placement mode)
//    private var effectiveMarkerType: MarkerType? {
//        pendingMarkerInfo?.markerType ?? controlViewModel.currentMarkerType
//    }
//
//    /// Whether marker placement overlay should be shown
//    private var shouldShowMarkerPlacementOverlay: Bool {
//        isMarkerPlacementMode || pendingMarkerInfo != nil
//    }
//
//    /// Whether instruction banner should be shown
//    private var shouldShowInstructionBanner: Bool {
//        // FIXED: Check pendingMarkerInfo instead of showMarkerSheet/isShowingSheet
//        isMarkerPlacementMode && pendingMarkerInfo == nil
//    }
//
//    // MARK: - Body
//
//    var body: some View {
//        ZStack {
//            GeometryReader { geometry in
//                chartContent(geometry: geometry)
//            }
//        }
//        // FIXED: Use sheet(item:) instead of sheet(isPresented:) for more robust presentation
//        // This ensures the sheet content always has valid data when shown
//        .sheet(item: $pendingMarkerInfo) { info in
//            MarkerCreationSheet(
//                markerManager: markerManager,
//                candleIndex: info.candleIndex,
//                timestamp: info.timestamp,
//                price: info.price,
//                username: "TestUser",
//                chartData: chartData,
//                candles: chartData.candles,
//                markerType: info.markerType,
//                initialTargetPrice: info.targetPrice
//            )
//            .onDisappear(perform: handleMarkerSheetDismiss)
//        }
//        .sheet(item: $markerManager.selectedMarker) { marker in
//            MarkerDetailSheet(
//                markerManager: markerManager,
//                marker: marker,
//                currentUserId: "user123",
//                chartData: chartData
//            )
//            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
//        }
//        .onAppear(perform: handleOnAppear)
//        .onChange(of: controlViewModel.isMarkerPlacementMode) { oldValue, newValue in
//            handleMarkerPlacementModeChange(oldValue: oldValue, newValue: newValue)
//        }
//        .onChange(of: chartViewModel.currentSymbol) { oldValue, newValue in
//            handleSymbolChange(oldValue: oldValue, newValue: newValue)
//        }
//        .onChange(of: chartViewModel.currentSymbol?.symbol) { oldValue, newValue in
//            handleSymbolStringChange(oldValue: oldValue, newValue: newValue)
//        }
//        .onChange(of: chartViewModel.currentTimeframe) { oldValue, newValue in
//            handleTimeframeChange(oldValue: oldValue, newValue: newValue)
//        }
//        .onChange(of: chartData.candles.count) { oldCount, newCount in
//            handleCandleCountChange(oldCount: oldCount, newCount: newCount)
//        }
//    }
//
//    // MARK: - Main Chart Content
//
//    @ViewBuilder
//    private func chartContent(geometry: GeometryProxy) -> some View {
//        let coordinateSystem = createCoordinateSystem(geometry: geometry)
//
//        ZStack {
//            Color.black.ignoresSafeArea().opacity(0.2)
//
//            mainChartCanvas(geometry: geometry)
//
//            if shouldShowMarkerPlacementOverlay {
//                markerPlacementOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
//            }
//
//            yAxisOverlay(geometry: geometry)
//
//            priceIndicatorView(geometry: geometry)
//
//            xAxisOverlay(geometry: geometry)
//
//            chartInfoBox(geometry: geometry)
//
//            chartControlsBox(geometry: geometry)
//
//            markerPriceLinesOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
//
//            targetLineOverlays(coordinateSystem: coordinateSystem, geometry: geometry)
//
//            CrosshairView(
//                crosshairManager: crosshairManager,
//                chartSize: geometry.size,
//                chartData: chartData
//            )
//
//            if shouldShowInstructionBanner {
//                instructionBanner(coordinateSystem: coordinateSystem)
//            }
//        }
//        .gesture(crosshairDismissTapGesture())
//        .gesture(crosshairGesture(coordinateSystem: coordinateSystem))
//        .simultaneousGesture(tapGestureForMarkers(geometry: geometry))
//        .simultaneousGesture(dragGesture(in: geometry.size, coordinateSystem: coordinateSystem))
//        .simultaneousGesture(pinchGesture(in: geometry.size))
//        .overlay(yAxisGestureOverlay)
//        .overlay(loadingOverlayIfNeeded)
//        .overlay(duplicateMarkerOverlayIfNeeded)
//        .onAppear {
//            updateChartSize(geometry.size)
//        }
//    }
//
//    // MARK: - Coordinate System Factory
//
//    private func createCoordinateSystem(geometry: GeometryProxy) -> ChartCoordinateSystem {
//        let coordinateSystem = ChartCoordinateSystem(
//            chartData: chartData,
//            gestureState: gestureState,
//            chartSize: geometry.size,
//            baseCandleWidth: baseCandleWidth,
//            candleSpacing: candleSpacing
//        )
//        _ = coordinateSystem.updateLiveState(dragState: dragState, pinchScale: 1.0)
//        return coordinateSystem
//    }
//
//    private func updateChartSize(_ size: CGSize) {
//        if chartSize != size {
//            DispatchQueue.main.async {
//                chartSize = size
//            }
//        }
//    }
//
//    // MARK: - Main Chart Canvas
//
//    @ViewBuilder
//    private func mainChartCanvas(geometry: GeometryProxy) -> some View {
//        Canvas { context, size in
//            drawChart(context: context, size: size, geometry: geometry)
//        }
//        .contentShape(Rectangle())
//    }
//
//    // MARK: - Price Indicator View
//
//    @ViewBuilder
//    private func priceIndicatorView(geometry: GeometryProxy) -> some View {
//        PriceIndicatorView(
//            currentPrice: chartData.currentPrice,
//            priceScale: gestureState.priceScale,
//            verticalOffset: clampedVerticalOffset(chartHeight: geometry.size.height),
//            chartHeight: geometry.size.height,
//            priceRange: chartData.priceRange,
//            chartData: chartData
//        )
//    }
//
//    // MARK: - Marker Price Lines Overlay
//
//    @ViewBuilder
//    private func markerPriceLinesOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
//        MarkerPriceLinesOverlay(
//            selectedMarker: activeSelectedMarker,
//            previewMarker: previewMarkerForPriceLine,
//            coordinateSystem: coordinateSystem,
//            chartWidth: geometry.size.width,
//            chartHeight: geometry.size.height,
//            chartData: chartData
//        )
//    }
//
//    // MARK: - Target Line Overlays
//
//    @ViewBuilder
//    private func targetLineOverlays(coordinateSystem: ChartCoordinateSystem, geometry: GeometryProxy) -> some View {
//        if shouldShowInteractiveTargetLine {
//            interactiveTargetLineOverlay(coordinateSystem: coordinateSystem, geometry: geometry)
//        }
//
//        if shouldShowStaticTargetLine {
//            staticTargetLineOverlay(coordinateSystem: coordinateSystem, geometry: geometry)
//        }
//    }
//
//    @ViewBuilder
//    private func interactiveTargetLineOverlay(coordinateSystem: ChartCoordinateSystem, geometry: GeometryProxy) -> some View {
//        let entryCandle = chartData.candles[previewCandleIndex]
//        let entryPrice = entryCandle.close
//
//        PredictionTargetLineOverlay(
//            entryPrice: entryPrice,
//            targetPrice: $predictionTargetPrice,
//            isDragging: $isDraggingTarget,
//            isInteractive: isAwaitingTargetSelection,
//            coordinateSystem: coordinateSystem,
//            chartWidth: geometry.size.width,
//            chartHeight: geometry.size.height,
//            chartData: chartData
//        )
//    }
//
//    @ViewBuilder
//    private func staticTargetLineOverlay(coordinateSystem: ChartCoordinateSystem, geometry: GeometryProxy) -> some View {
//        if let pending = pendingMarkerInfo,
//           let targetPrice = pending.targetPrice {
//            let entryCandle = chartData.candles[pending.candleIndex]
//            let entryPrice = entryCandle.close
//
//            StaticTargetLineOverlay(
//                entryPrice: entryPrice,
//                targetPrice: targetPrice,
//                coordinateSystem: coordinateSystem,
//                chartWidth: geometry.size.width,
//                chartHeight: geometry.size.height,
//                chartData: chartData
//            )
//        }
//    }
//
//    // MARK: - Y-Axis Gesture Overlay
//
//    @ViewBuilder
//    private var yAxisGestureOverlay: some View {
//        HStack {
//            Spacer()
//            Color.clear
//                .frame(width: yAxisWidth)
//                .contentShape(Rectangle())
//                .gesture(yAxisDragGesture)
//                .simultaneousGesture(yAxisPinchGesture)
//        }
//        .allowsHitTesting(true)
//        .onDisappear {
//            isDraggingOnYAxis = false
//            isPinchingOnYAxis = false
//        }
//    }
//
//    // MARK: - Loading Overlay
//
//    @ViewBuilder
//    private var loadingOverlayIfNeeded: some View {
//        if shouldShowLoadingOverlay {
//            loadingOverlay
//        }
//    }
//
//    @ViewBuilder
//    private var loadingOverlay: some View {
//        ZStack {
//            Color.black.opacity(0.85)
//                .ignoresSafeArea()
//
//            VStack(spacing: 20) {
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                    .scaleEffect(1.5)
//
//                Text("Loading Chart...")
//                    .font(.headline)
//                    .foregroundColor(.white)
//
//                loadingSubtitle
//            }
//        }
//        .transition(.opacity.animation(.easeOut(duration: 0.3)))
//    }
//
//    @ViewBuilder
//    private var loadingSubtitle: some View {
//        if chartViewModel.currentSymbol == nil {
//            Text("Fetching symbol data")
//                .font(.caption)
//                .foregroundColor(.gray)
//        } else if chartData.candles.isEmpty {
//            Text("Loading candles")
//                .font(.caption)
//                .foregroundColor(.gray)
//        }
//    }
//
//    // MARK: - Duplicate Marker Overlay
//
//    @ViewBuilder
//    private var duplicateMarkerOverlayIfNeeded: some View {
//        if markerManager.showDuplicateAlert {
//            duplicateMarkerOverlay
//        }
//    }
//
//
//    @ViewBuilder
//    private var duplicateMarkerOverlay: some View {
//        Color.black.opacity(0.4)
//            .ignoresSafeArea()
//            .onTapGesture {
//                markerManager.showDuplicateAlert = false
//                markerManager.duplicateMarkerToLike = nil
//            }
//
//        duplicateMarkerDialog
//    }
//
//    @ViewBuilder
//    private var duplicateMarkerDialog: some View {
//        VStack(spacing: 0) {
//            Spacer()
//
//            VStack(spacing: 20) {
//                Image(systemName: "exclamationmark.triangle.fill")
//                    .font(.system(size: 50))
//                    .foregroundColor(.orange)
//
//                Text("Marker Exists")
//                    .font(.title2)
//                    .fontWeight(.bold)
//
//                Text("A \(markerManager.duplicateMarkerToLike?.type.rawValue ?? "marker") already exists on this candle. Would you like to like it instead?")
//                    .font(.body)
//                    .multilineTextAlignment(.center)
//                    .foregroundColor(.secondary)
//                    .padding(.horizontal)
//
//                duplicateMarkerButtons
//            }
//            .padding(30)
//            .background(Color(.systemBackground))
//            .cornerRadius(20)
//            .shadow(radius: 20)
//            .padding(.horizontal, 40)
//
//            Spacer()
//        }
//        .transition(.scale.combined(with: .opacity))
//        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: markerManager.showDuplicateAlert)
//        .zIndex(999)
//    }
//
//    @ViewBuilder
//    private var duplicateMarkerButtons: some View {
//        VStack(spacing: 12) {
//            Button(action: handleLikeExistingMarker) {
//                HStack {
//                    Image(systemName: "heart.fill")
//                    Text("Like Existing")
//                }
//                .font(.headline)
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(Color.blue)
//                .cornerRadius(12)
//            }
//
//            Button(action: handleDismissDuplicateAlert) {
//                Text("Cancel")
//                    .font(.headline)
//                    .foregroundColor(.blue)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color(.systemGray6))
//                    .cornerRadius(12)
//            }
//        }
//        .padding(.horizontal, 30)
//    }
//
//    // MARK: - Instruction Banner
//
//    @ViewBuilder
//    private func instructionBanner(coordinateSystem: ChartCoordinateSystem) -> some View {
//        VStack {
//            HStack(spacing: 12) {
//                cancelPlacementButton
//
//                if isAwaitingTargetSelection {
//                    confirmTargetButton(coordinateSystem: coordinateSystem)
//                } else {
//                    placeMarkerButton(coordinateSystem: coordinateSystem)
//                }
//                Spacer()
//            }
//            .padding(.horizontal, 20)
//            .padding(.top, 120)
//            Spacer()
//        }
//        .allowsHitTesting(true)
//        .transition(.move(edge: .top).combined(with: .opacity))
//    }
//
//    @ViewBuilder
//    private var cancelPlacementButton: some View {
//        Button(action: handleCancelPlacement) {
//            HStack(spacing: 6) {
//                Image(systemName: "xmark.circle.fill")
//                    .font(.system(size: 22))
//            }
//            .foregroundColor(.white)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .background(Color.red)
//            .cornerRadius(12)
//        }
//    }
//
//    @ViewBuilder
//    private func confirmTargetButton(coordinateSystem: ChartCoordinateSystem) -> some View {
//        Button(action: { handleConfirmTargetPress(coordinateSystem: coordinateSystem) }) {
//            HStack(spacing: 6) {
//                Image(systemName: "checkmark.circle.fill")
//                    .font(.system(size: 22))
//                Text("Confirm Target")
//                    .font(.system(size: 14, weight: .semibold))
//            }
//            .foregroundColor(.white)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .background(Color.orange)
//            .cornerRadius(12)
//        }
//    }
//
//    @ViewBuilder
//    private func placeMarkerButton(coordinateSystem: ChartCoordinateSystem) -> some View {
//        Button(action: { handlePlaceMarkerPress(coordinateSystem: coordinateSystem) }) {
//            HStack(spacing: 6) {
//                Image(systemName: "checkmark.circle.fill")
//                    .font(.system(size: 22))
//            }
//            .foregroundColor(.white)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .background(Color.green)
//            .cornerRadius(12)
//        }
//    }
//
//    // MARK: - Marker Placement Overlay
//
//    @ViewBuilder
//    private func markerPlacementOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
//        ZStack {
//            if effectiveCandleIndex >= 0 && effectiveCandleIndex < chartData.candles.count {
//                verticalGuideLine(geometry: geometry, coordinateSystem: coordinateSystem)
//                previewMarkerView(geometry: geometry, coordinateSystem: coordinateSystem)
//            }
//        }
//    }
//
//    @ViewBuilder
//    private func verticalGuideLine(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
//        let candle = chartData.candles[effectiveCandleIndex]
//        let x = coordinateSystem.xCenterPosition(forCandleIndex: effectiveCandleIndex)
//
//        if x >= -50 && x <= geometry.size.width + 50 {
//            Path { path in
//                path.move(to: CGPoint(x: x, y: 0))
//                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
//            }
//            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
//            .foregroundColor(.blue.opacity(0.6))
//            .allowsHitTesting(false)
//
//            MarkerXAxisTimeIndicator(
//                timestamp: candle.timestamp,
//                xPosition: x,
//                chartHeight: geometry.size.height
//            )
//        }
//    }
//
//    @ViewBuilder
//    private func previewMarkerView(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
//        let candle = chartData.candles[effectiveCandleIndex]
//        let snapX = coordinateSystem.xCenterPosition(forCandleIndex: effectiveCandleIndex)
//        let candleHighY = coordinateSystem.yPosition(forPrice: candle.high)
//        let candleLowY = coordinateSystem.yPosition(forPrice: candle.low)
//
//        let (snapPosition, _) = MarkerPositionCalculator.calculatePreviewPosition(
//            candleIndex: effectiveCandleIndex,
//            existingMarkers: markerManager.filteredMarkers,
//            candles: chartData.candles,
//            candleHighY: candleHighY,
//            candleLowY: candleLowY,
//            centerX: snapX,
//            priceScale: gestureState.priceScale
//        )
//
//        let markerX = markerDragPosition?.x ?? snapPosition.x
//        let markerY = markerDragPosition?.y ?? snapPosition.y
//
//        if markerX >= -50 && markerX <= geometry.size.width + 50 {
//            previewMarkerContent(candle: candle, x: markerX, y: markerY, coordinateSystem: coordinateSystem)
//        }
//    }
//
//    @ViewBuilder
//    private func previewMarkerContent(candle: Candle, x: CGFloat, y: CGFloat, coordinateSystem: ChartCoordinateSystem) -> some View {
//        ZStack {
//            Circle()
//                .fill(Color.clear)
//                .frame(width: 80, height: 80)
//                .contentShape(Circle())
//
//            Circle()
//                .fill(Color.black.opacity(0.85))
//                .frame(width: 40, height: 40)
//                .overlay(
//                    Circle()
//                        .stroke(effectiveMarkerType?.color ?? .blue, lineWidth: 3)
//                )
//
//            Circle()
//                .fill(effectiveMarkerType?.color ?? .blue)
//                .frame(width: 24, height: 24)
//                .overlay(
//                    Image(systemName: effectiveMarkerType?.icon ?? "mappin")
//                        .font(.system(size: 12, weight: .bold))
//                        .foregroundColor(.white)
//                )
//
//            previewMarkerInfoBox(candle: candle)
//        }
//        .position(x: x, y: y)
//        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarkerBeingDragged)
//        .gesture(previewMarkerDragGesture(coordinateSystem: coordinateSystem))
//    }
//
//    @ViewBuilder
//    private func previewMarkerInfoBox(candle: Candle) -> some View {
//        VStack(spacing: 2) {
//            Text(candle.timestamp.chartTimeLabel)
//                .font(.caption2)
//                .foregroundColor(.white)
//            Text(chartData.formatPrice(candle.close))
//                .font(.caption)
//                .fontWeight(.bold)
//                .foregroundColor(.white)
//        }
//        .padding(4)
//        .background(Color.blue)
//        .cornerRadius(4)
//        .offset(y: 40)
//        .allowsHitTesting(false)
//    }
//
//    private func previewMarkerDragGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
//        DragGesture(minimumDistance: 0)
//            .onChanged { value in
//                if !isMarkerBeingDragged {
//                    isMarkerBeingDragged = true
//                    impactFeedback.impactOccurred()
//                }
//                markerDragPosition = value.location
//
//                if let index = coordinateSystem.candleIndex(atXPosition: value.location.x) {
//                    let clampedIndex = max(0, min(chartData.candles.count - 1, index))
//                    previewCandleIndex = clampedIndex
//                }
//            }
//            .onEnded { value in
//                isMarkerBeingDragged = false
//                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
//                    markerDragPosition = nil
//                }
//            }
//    }
//
//    // MARK: - Button Action Handlers
//
//    private func handleConfirmTargetPress(coordinateSystem: ChartCoordinateSystem) {
//        // FIXED: Check pendingMarkerInfo instead of isShowingSheet
//        guard pendingMarkerInfo == nil else { return }
//
//        guard let timestamp = coordinateSystem.timestamp(forCandleIndex: previewCandleIndex),
//              previewCandleIndex >= 0,
//              previewCandleIndex < chartData.candles.count,
//              let markerType = controlViewModel.currentMarkerType,
//              let targetPrice = predictionTargetPrice else {
//            return
//        }
//
//        let candle = chartData.candles[previewCandleIndex]
//        markerManager.selectedMarker = nil
//
//        // FIXED: Setting pendingMarkerInfo automatically presents the sheet via sheet(item:)
//        pendingMarkerInfo = PendingMarkerInfo(
//            candleIndex: previewCandleIndex,
//            timestamp: timestamp,
//            price: candle.close,
//            markerType: markerType,
//            targetPrice: targetPrice
//        )
//
//        isAwaitingTargetSelection = false
//        impactFeedback.impactOccurred()
//    }
//
//    private func handlePlaceMarkerPress(coordinateSystem: ChartCoordinateSystem) {
//        // FIXED: Check pendingMarkerInfo instead of isShowingSheet
//        guard pendingMarkerInfo == nil else { return }
//
//        guard let timestamp = coordinateSystem.timestamp(forCandleIndex: previewCandleIndex),
//              previewCandleIndex >= 0,
//              previewCandleIndex < chartData.candles.count,
//              let markerType = controlViewModel.currentMarkerType else {
//            return
//        }
//
//        if let existingMarker = markerManager.existingMarkerOfType(markerType, atCandleIndex: previewCandleIndex) {
//            controlViewModel.cancelMarkerPlacement()
//            markerManager.duplicateMarkerToLike = existingMarker
//            markerManager.showDuplicateAlert = true
//            return
//        }
//
//        let candle = chartData.candles[previewCandleIndex]
//
//        if markerType == .predictionTarget {
//            let entryPrice = candle.close
//            let priceRangeSpan = chartData.priceRange.max - chartData.priceRange.min
//            predictionTargetPrice = entryPrice + (priceRangeSpan * 0.05)
//            isAwaitingTargetSelection = true
//            impactFeedback.impactOccurred()
//        } else {
//            markerManager.selectedMarker = nil
//
//            // FIXED: Setting pendingMarkerInfo automatically presents the sheet via sheet(item:)
//            pendingMarkerInfo = PendingMarkerInfo(
//                candleIndex: previewCandleIndex,
//                timestamp: timestamp,
//                price: candle.close,
//                markerType: markerType
//            )
//
//            impactFeedback.impactOccurred()
//        }
//    }
//
//    private func handleCancelPlacement() {
//        withAnimation {
//            controlViewModel.isMarkerPlacementMode = false
//            isMarkerBeingDragged = false
//            markerDragPosition = nil
//            isAwaitingTargetSelection = false
//            predictionTargetPrice = nil
//            isDraggingTarget = false
//        }
//    }
//
//    private func handleLikeExistingMarker() {
//        if let marker = markerManager.duplicateMarkerToLike {
//            markerManager.toggleLike(markerId: marker.id)
//        }
//        markerManager.duplicateMarkerToLike = nil
//        markerManager.showDuplicateAlert = false
//    }
//
//    private func handleDismissDuplicateAlert() {
//        markerManager.duplicateMarkerToLike = nil
//        markerManager.showDuplicateAlert = false
//    }
//
//    private func handleMarkerSheetDismiss() {
//        controlViewModel.cancelMarkerPlacement()
//        markerManager.selectedMarker = nil
//        // FIXED: Setting pendingMarkerInfo to nil automatically dismisses sheet via sheet(item:)
//        pendingMarkerInfo = nil
//        isAwaitingTargetSelection = false
//        predictionTargetPrice = nil
//        isDraggingTarget = false
//    }
//
//    // MARK: - Lifecycle Handlers
//
//    private func handleOnAppear() {
//        setupControlActions()
//        chartViewModel.markerManager = markerManager
//        isChartLoading = chartViewModel.currentSymbol == nil || chartData.candles.isEmpty
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            if !hasInitializedPosition && !chartData.candles.isEmpty && chartViewModel.currentSymbol != nil {
//                resetChartToMostRecentCandles()
//                hasInitializedPosition = true
//            }
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            if markerManager.markers.isEmpty && !chartData.candles.isEmpty {
//                Task {
//                    await loadMarkersFromAPI()
//                }
//            }
//        }
//    }
//
//    private func handleMarkerPlacementModeChange(oldValue: Bool, newValue: Bool) {
//        if !oldValue && newValue {
//            let centerIndex = calculateCenterCandleIndex()
//            previewCandleIndex = centerIndex
//        }
//    }
//
//    private func handleSymbolChange(oldValue: TradingSymbol?, newValue: TradingSymbol?) {
//        if oldValue == nil && newValue != nil && !chartData.candles.isEmpty {
//            if !hasInitializedPosition {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    resetChartToMostRecentCandles()
//                    hasInitializedPosition = true
//                }
//            }
//        }
//    }
//
//    private func handleSymbolStringChange(oldValue: String?, newValue: String?) {
//        if oldValue != newValue && oldValue != nil {
//            isChartLoading = true
//            markerManager.clearMarkers()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                resetChartToMostRecentCandles()
//                Task {
//                    await loadMarkersFromAPI()
//                }
//            }
//        }
//    }
//
//    private func handleTimeframeChange(oldValue: ChartTimeframe, newValue: ChartTimeframe) {
//        if oldValue != newValue {
//            isChartLoading = true
//            markerManager.clearMarkers()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                resetChartToMostRecentCandles()
//                Task {
//                    await loadMarkersFromAPI()
//                }
//            }
//        }
//    }
//
//    private func handleCandleCountChange(oldCount: Int, newCount: Int) {
//        if abs(newCount - oldCount) > 10 {
//            resetChartToMostRecentCandles()
//        }
//    }
//
//    // MARK: - Helper Functions
//
//    private func calculateCenterCandleIndex() -> Int {
//        let totalOffset = gestureState.panOffset.width
//        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
//        let candlesOnScreen = Int(chartSize.width / totalCandleWidth)
//        let visibleEndIndex = Swift.min(
//            chartData.candles.count,
//            visibleStartIndex + candlesOnScreen + 2
//        )
//        let middleIndex = (visibleStartIndex + visibleEndIndex) / 2
//        return max(0, min(chartData.candles.count - 1, middleIndex))
//    }
//
//    // MARK: - Crosshair Gestures
//
//    private func crosshairGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
//        LongPressGesture(minimumDuration: 0.2)
//            .sequenced(before: DragGesture(minimumDistance: 0))
//            .onChanged { value in
//                switch value {
//                case .second(true, let drag):
//                    if let location = drag?.location {
//                        if !crosshairManager.isActive {
//                            let generator = UIImpactFeedbackGenerator(style: .medium)
//                            generator.impactOccurred()
//
//                            crosshairManager.activate(
//                                at: location,
//                                coordinateSystem: coordinateSystem,
//                                chartData: chartData
//                            )
//                        } else {
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
//    }
//
//    private func crosshairDismissTapGesture() -> some Gesture {
//        TapGesture()
//            .onEnded {
//                if crosshairManager.isActive {
//                    let generator = UIImpactFeedbackGenerator(style: .light)
//                    generator.impactOccurred()
//                    crosshairManager.deactivate()
//                }
//            }
//    }
//
//    // MARK: - Tap Gesture for Markers
//
//    private func tapGestureForMarkers(geometry: GeometryProxy) -> some Gesture {
//        DragGesture(minimumDistance: 0)
//            .onEnded { value in
//                // FIXED: Check pendingMarkerInfo instead of showMarkerSheet/isShowingSheet
//                guard !crosshairManager.isActive &&
//                        !isMarkerPlacementMode &&
//                        pendingMarkerInfo == nil else { return }
//
//                let location = value.location
//                let totalOffset = gestureState.panOffset.width
//                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
//
//                if let marker = ChartMarkerSystem.findMarkerAtLocation(
//                    location,
//                    markers: markerManager.filteredMarkers,
//                    candles: chartData.candles,
//                    chartSize: geometry.size,
//                    priceRange: chartData.priceRange,
//                    priceScale: gestureState.priceScale,
//                    verticalOffset: totalVerticalOffset,
//                    totalCandleWidth: totalCandleWidth,
//                    actualCandleWidth: actualCandleWidth,
//                    totalOffset: totalOffset
//                ) {
//                    markerHaptic.impactOccurred()
//                    tappedMarkerId = marker.id
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
//                        tappedMarkerId = nil
//                    }
//                    markerManager.selectedMarker = marker
//                }
//            }
//    }
//
//    // MARK: - Pan Gesture
//
//    private func dragGesture(in size: CGSize, coordinateSystem: ChartCoordinateSystem) -> some Gesture {
//        DragGesture(minimumDistance: 10)
//            .onChanged { value in
//                if crosshairManager.isActive {
//                    handleCrosshairDrag(value: value, size: size, coordinateSystem: coordinateSystem)
//                    return
//                }
//
//                // FIXED: Added isDraggingTarget to prevent panning while dragging target line
//                if !isDraggingOnYAxis && !isPinchingOnYAxis && !isMarkerBeingDragged && !isDraggingTarget {
//                    let incrementalX = value.translation.width - lastDragTranslation.width
//                    let incrementalY = -(value.translation.height - lastDragTranslation.height)
//
//                    gestureState.applyPan(
//                        translation: CGSize(width: incrementalX, height: incrementalY),
//                        chartWidth: size.width,
//                        candleCount: chartData.candles.count,
//                        candleWidth: totalCandleWidth,
//                        chartHeight: size.height,
//                        priceScale: gestureState.priceScale
//                    )
//
//                    lastDragTranslation = value.translation
//                }
//            }
//            .onEnded { value in
//                if crosshairManager.isActive {
//                    crosshairDragStartPosition = nil
//                }
//                lastDragTranslation = .zero
//                dragState = .zero
//            }
//    }
//
//    private func handleCrosshairDrag(value: DragGesture.Value, size: CGSize, coordinateSystem: ChartCoordinateSystem) {
//        if crosshairDragStartPosition == nil {
//            crosshairDragStartPosition = crosshairManager.position
//        }
//
//        if let startPos = crosshairDragStartPosition {
//            let newPosition = CGPoint(
//                x: startPos.x + value.translation.width,
//                y: startPos.y + value.translation.height
//            )
//
//            let clampedPosition = CGPoint(
//                x: max(0, min(size.width, newPosition.x)),
//                y: max(0, min(size.height, newPosition.y))
//            )
//
//            crosshairManager.updatePosition(
//                clampedPosition,
//                coordinateSystem: coordinateSystem,
//                chartData: chartData
//            )
//        }
//    }
//
//    // MARK: - Pinch Gesture
//
//    private func pinchGesture(in size: CGSize) -> some Gesture {
//        MagnificationGesture()
//            .onChanged { value in
//                guard !crosshairManager.isActive && !isMarkerBeingDragged && !isPinchingOnYAxis else { return }
//
//                if !isPinchingOnChart {
//                    isPinchingOnChart = true
//                    initialCandleWidthScale = gestureState.candleWidthScale
//                    initialHorizontalOffset = gestureState.panOffset.width
//                    pinchCenterX = size.width / 2
//                }
//
//                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
//                let newScale = initialCandleWidthScale * dampenedValue
//                let clampedScale = Swift.min(maxHorizontalScale, Swift.max(minHorizontalScale, newScale))
//
//                let oldTotalWidth = baseCandleWidth * initialCandleWidthScale + candleSpacing
//                let newTotalWidth = baseCandleWidth * clampedScale + candleSpacing
//                let totalWidthRatio = newTotalWidth / oldTotalWidth
//
//                let newHorizontalOffset = initialHorizontalOffset * totalWidthRatio + pinchCenterX * (1.0 - totalWidthRatio)
//
//                gestureState.candleWidthScale = clampedScale
//                gestureState.panOffset.width = newHorizontalOffset
//            }
//            .onEnded { _ in
//                isPinchingOnChart = false
//            }
//    }
//
//    // MARK: - Y-Axis Gestures
//
//    private var yAxisDragGesture: some Gesture {
//        DragGesture(minimumDistance: 0)
//            .onChanged { value in
//                if !isDraggingOnYAxis {
//                    if isPinchingOnYAxis {
//                        isPinchingOnYAxis = false
//                    }
//
//                    isDraggingOnYAxis = true
//                    yAxisDragStart = value.startLocation.y
//                    initialPriceScale = gestureState.priceScale
//                    initialVerticalOffset = gestureState.verticalPanOffset
//                }
//
//                let dragDistance = value.location.y - yAxisDragStart
//                let scaleMultiplier = 1.0 - (dragDistance / 300.0) * yAxisSensitivity
//                let newScale = initialPriceScale * scaleMultiplier
//                let clampedScale = Swift.min(maxVerticalScale, Swift.max(minVerticalScale, newScale))
//
//                let chartHeight = UIScreen.main.bounds.height
//                let screenCenterY = chartHeight / 2
//
//                let scaleRatio = clampedScale / initialPriceScale
//                let newVerticalOffset = initialVerticalOffset * scaleRatio + screenCenterY * (1.0 - scaleRatio)
//
//                gestureState.priceScale = clampedScale
//                gestureState.verticalPanOffset = newVerticalOffset
//            }
//            .onEnded { _ in
//                isDraggingOnYAxis = false
//            }
//    }
//
//    private var yAxisPinchGesture: some Gesture {
//        MagnificationGesture()
//            .onChanged { value in
//                if !isPinchingOnYAxis {
//                    if isDraggingOnYAxis {
//                        isDraggingOnYAxis = false
//                    }
//
//                    isPinchingOnYAxis = true
//                    initialPriceScale = gestureState.priceScale
//                    initialVerticalOffset = gestureState.verticalPanOffset
//                }
//
//                let dampenedValue = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
//                let newScale = initialPriceScale * dampenedValue
//                let clampedScale = Swift.min(maxVerticalScale, Swift.max(minVerticalScale, newScale))
//
//                let chartHeight = UIScreen.main.bounds.height
//                let screenCenterY = chartHeight / 2
//
//                let scaleRatio = clampedScale / initialPriceScale
//                let newVerticalOffset = initialVerticalOffset * scaleRatio + screenCenterY * (1.0 - scaleRatio)
//
//                gestureState.priceScale = clampedScale
//                gestureState.verticalPanOffset = newVerticalOffset
//            }
//            .onEnded { _ in
//                isPinchingOnYAxis = false
//            }
//    }
//
//    // MARK: - Axis Overlays
//
//    @ViewBuilder
//    func xAxisOverlay(geometry: GeometryProxy) -> some View {
//        let bottomAreaHeight = geometry.size.height * 0.11
//
//        VStack(spacing: 0) {
//            Spacer()
//
//            xAxisLabelsCanvas(geometry: geometry)
//
//            Rectangle()
//                .fill(Color.black)
//                .frame(height: bottomAreaHeight)
//                .edgesIgnoringSafeArea(.bottom)
//        }
//        .allowsHitTesting(false)
//    }
//
//    @ViewBuilder
//    private func xAxisLabelsCanvas(geometry: GeometryProxy) -> some View {
//        Canvas { context, size in
//            drawXAxisLabels(context: context, size: size)
//        }
//        .frame(height: 22)
//        .padding(.top, 10)
//        .background(Color.black)
//    }
//
//    private func drawXAxisLabels(context: GraphicsContext, size: CGSize) {
//        let totalOffset = gestureState.panOffset.width
//        let timeframe = chartViewModel.currentTimeframe
//
//        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 30)
//        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 60)
//
//        guard visibleStartIndex < visibleEndIndex else { return }
//
//        let niceInterval = getNiceTimeInterval(timeframe: timeframe, zoomScale: gestureState.candleWidthScale)
//
//        var drawnPositions: [CGFloat] = []
//
//        let minLabelSpacing: CGFloat = getMinLabelSpacing(for: timeframe)
//
//        // First pass: Draw DATE labels at midnight
//        for i in visibleStartIndex..<visibleEndIndex {
//            guard i >= 0 && i < chartData.candles.count else { continue }
//
//            let candle = chartData.candles[i]
//            let x = CGFloat(i) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//
//            guard x >= -50 && x <= size.width + 50 else { continue }
//
//            if isAtMidnight(candle.timestamp, timeframe: timeframe) {
//                let tooClose = drawnPositions.contains { abs($0 - x) < minLabelSpacing }
//                if tooClose { continue }
//
//                let dateText = formatDateLabel(candle.timestamp, timeframe: timeframe)
//
//                context.draw(
//                    Text(dateText)
//                        .font(.system(size: 12, weight: .bold))
//                        .foregroundColor(.white),
//                    at: CGPoint(x: x, y: 10)
//                )
//
//                drawnPositions.append(x)
//            }
//        }
//
//        // Second pass: Draw TIME labels
//        for i in visibleStartIndex..<visibleEndIndex {
//            guard i >= 0 && i < chartData.candles.count else { continue }
//
//            let candle = chartData.candles[i]
//            let x = CGFloat(i) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//
//            guard x >= -50 && x <= size.width + 50 else { continue }
//
//            if isAtMidnight(candle.timestamp, timeframe: timeframe) {
//                continue
//            }
//
//            if isNiceTimeBoundary(candle.timestamp, interval: niceInterval, timeframe: timeframe) {
//                let tooClose = drawnPositions.contains { abs($0 - x) < minLabelSpacing }
//                if tooClose { continue }
//
//                let timeText = formatTimeLabel(candle.timestamp, timeframe: timeframe)
//
//                context.draw(
//                    Text(timeText)
//                        .font(.system(size: 11))
//                        .foregroundColor(.gray),
//                    at: CGPoint(x: x, y: 10)
//                )
//
//                drawnPositions.append(x)
//            }
//        }
//    }
//
//    private func getMinLabelSpacing(for timeframe: ChartTimeframe) -> CGFloat {
//        switch timeframe {
//        case .m1: return 40
//        case .m5: return 45
//        case .m15, .m30: return 50
//        default: return 55
//        }
//    }
//
//    // MARK: - X-Axis Time Helpers
//
//    private func getNiceTimeInterval(timeframe: ChartTimeframe, zoomScale: CGFloat) -> Int {
//        switch timeframe {
//        case .m1:
//            if zoomScale >= 2.5 { return 1 }
//            else if zoomScale >= 1.8 { return 2 }
//            else if zoomScale >= 1.2 { return 3 }
//            else if zoomScale >= 0.8 { return 5 }
//            else if zoomScale >= 0.5 { return 10 }
//            else if zoomScale >= 0.35 { return 15 }
//            else { return 30 }
//
//        case .m5:
//            if zoomScale >= 2.5 { return 5 }
//            else if zoomScale >= 1.8 { return 10 }
//            else if zoomScale >= 0.8 { return 15 }
//            else if zoomScale >= 0.5 { return 30 }
//            else if zoomScale >= 0.35 { return 60 }
//            else { return 120 }
//
//        case .m15:
//            if zoomScale >= 2.0 { return 15 }
//            else if zoomScale >= 1.2 { return 30 }
//            else if zoomScale >= 0.6 { return 60 }
//            else { return 120 }
//
//        case .m30:
//            if zoomScale >= 2.0 { return 30 }
//            else if zoomScale >= 1.2 { return 60 }
//            else if zoomScale >= 0.6 { return 120 }
//            else { return 240 }
//
//        case .h1:
//            if zoomScale >= 2.0 { return 60 }
//            else if zoomScale >= 1.2 { return 120 }
//            else if zoomScale >= 0.6 { return 240 }
//            else { return 480 }
//
//        case .h4:
//            if zoomScale >= 2.0 { return 240 }
//            else if zoomScale >= 1.2 { return 480 }
//            else if zoomScale >= 0.6 { return 720 }
//            else { return 1440 }
//
//        case .d1:
//            if zoomScale >= 2.0 { return 1440 * 2 }
//            else if zoomScale >= 1.2 { return 1440 * 5 }
//            else if zoomScale >= 0.6 { return 1440 * 7 }
//            else { return 1440 * 14 }
//
//        case .w1:
//            if zoomScale >= 1.2 { return 1440 * 7 }
//            else if zoomScale >= 0.6 { return 1440 * 14 }
//            else { return 1440 * 28 }
//
//        case .mn:
//            if zoomScale >= 1.0 { return 1440 * 30 }
//            else { return 1440 * 90 }
//        }
//    }
//
//    private func isNiceTimeBoundary(_ timestamp: Date, interval: Int, timeframe: ChartTimeframe) -> Bool {
//        let calendar = Calendar.current
//        let hour = calendar.component(.hour, from: timestamp)
//        let minute = calendar.component(.minute, from: timestamp)
//
//        switch timeframe {
//        case .m1:
//            return checkM1Boundary(interval: interval, hour: hour, minute: minute)
//        case .m5:
//            return checkM5Boundary(interval: interval, hour: hour, minute: minute)
//        case .m15:
//            return checkM15Boundary(interval: interval, hour: hour, minute: minute)
//        case .m30:
//            return checkM30Boundary(interval: interval, hour: hour, minute: minute)
//        case .h1:
//            return checkH1Boundary(interval: interval, hour: hour, minute: minute)
//        case .h4:
//            return checkH4Boundary(interval: interval, hour: hour, minute: minute)
//        case .d1:
//            return checkD1Boundary(interval: interval, timestamp: timestamp)
//        case .w1:
//            return checkW1Boundary(interval: interval, timestamp: timestamp)
//        case .mn:
//            return checkMNBoundary(interval: interval, timestamp: timestamp)
//        }
//    }
//
//    private func checkM1Boundary(interval: Int, hour: Int, minute: Int) -> Bool {
//        if interval <= 1 { return true }
//        else if interval < 60 { return minute % interval == 0 }
//        else {
//            let intervalHours = interval / 60
//            return minute == 0 && hour % intervalHours == 0
//        }
//    }
//
//    private func checkM5Boundary(interval: Int, hour: Int, minute: Int) -> Bool {
//        if interval <= 5 { return minute % 5 == 0 }
//        else if interval < 60 { return minute % interval == 0 }
//        else {
//            let intervalHours = interval / 60
//            return minute == 0 && hour % intervalHours == 0
//        }
//    }
//
//    private func checkM15Boundary(interval: Int, hour: Int, minute: Int) -> Bool {
//        if interval <= 15 { return minute % 15 == 0 }
//        else if interval < 60 { return minute % interval == 0 }
//        else {
//            let intervalHours = interval / 60
//            return minute == 0 && hour % intervalHours == 0
//        }
//    }
//
//    private func checkM30Boundary(interval: Int, hour: Int, minute: Int) -> Bool {
//        if interval <= 30 { return minute % 30 == 0 }
//        else {
//            let intervalHours = interval / 60
//            return minute == 0 && hour % intervalHours == 0
//        }
//    }
//
//    private func checkH1Boundary(interval: Int, hour: Int, minute: Int) -> Bool {
//        let intervalHours = max(1, interval / 60)
//        return minute == 0 && hour % intervalHours == 0
//    }
//
//    private func checkH4Boundary(interval: Int, hour: Int, minute: Int) -> Bool {
//        let validH4Hours = [0, 4, 8, 12, 16, 20]
//        guard validH4Hours.contains(hour) && minute == 0 else { return false }
//
//        let intervalHours = max(4, interval / 60)
//        if intervalHours <= 4 { return true }
//        else if intervalHours <= 8 { return [0, 8, 16].contains(hour) }
//        else if intervalHours <= 12 { return [0, 12].contains(hour) }
//        else { return hour == 0 }
//    }
//
//    private func checkD1Boundary(interval: Int, timestamp: Date) -> Bool {
//        let calendar = Calendar.current
//        let intervalDays = interval / 1440
//        if intervalDays <= 2 {
//            let day = calendar.component(.day, from: timestamp)
//            return intervalDays <= 1 || day % 2 == 1
//        } else if intervalDays <= 5 {
//            let weekday = calendar.component(.weekday, from: timestamp)
//            return weekday == 2 || weekday == 5
//        } else if intervalDays <= 7 {
//            let weekday = calendar.component(.weekday, from: timestamp)
//            return weekday == 2
//        } else {
//            let day = calendar.component(.day, from: timestamp)
//            return day == 1 || day == 15
//        }
//    }
//
//    private func checkW1Boundary(interval: Int, timestamp: Date) -> Bool {
//        let calendar = Calendar.current
//        let day = calendar.component(.day, from: timestamp)
//        let intervalWeeks = interval / (1440 * 7)
//        if intervalWeeks <= 1 { return true }
//        else if intervalWeeks <= 2 { return day <= 7 || (day >= 15 && day <= 21) }
//        else { return day <= 7 }
//    }
//
//    private func checkMNBoundary(interval: Int, timestamp: Date) -> Bool {
//        let calendar = Calendar.current
//        let month = calendar.component(.month, from: timestamp)
//        let intervalMonths = interval / (1440 * 30)
//        if intervalMonths <= 1 { return true }
//        else { return [1, 4, 7, 10].contains(month) }
//    }
//
//    private func isAtMidnight(_ timestamp: Date, timeframe: ChartTimeframe) -> Bool {
//        let calendar = Calendar.current
//        let hour = calendar.component(.hour, from: timestamp)
//        let minute = calendar.component(.minute, from: timestamp)
//
//        switch timeframe {
//        case .m1:
//            return hour == 0 && minute == 0
//        case .m5:
//            return hour == 0 && minute <= 5
//        case .m15, .m30:
//            return hour == 0 && minute == 0
//        case .h1, .h4:
//            return hour == 0
//        case .d1:
//            let day = calendar.component(.day, from: timestamp)
//            return day == 1
//        case .w1:
//            let day = calendar.component(.day, from: timestamp)
//            return day <= 7
//        case .mn:
//            let month = calendar.component(.month, from: timestamp)
//            return [1, 4, 7, 10].contains(month)
//        }
//    }
//
//    private func formatDateLabel(_ timestamp: Date, timeframe: ChartTimeframe) -> String {
//        let formatter = DateFormatter()
//
//        switch timeframe {
//        case .m1, .m5, .m15, .m30, .h1, .h4:
//            formatter.dateFormat = "dd/MM"
//        case .d1:
//            formatter.dateFormat = "MMM"
//        case .w1:
//            formatter.dateFormat = "MMM yy"
//        case .mn:
//            let calendar = Calendar.current
//            let month = calendar.component(.month, from: timestamp)
//            let year = calendar.component(.year, from: timestamp)
//            let quarter = (month - 1) / 3 + 1
//            return "Q\(quarter) '\(year % 100)"
//        }
//
//        return formatter.string(from: timestamp)
//    }
//
//    private func formatTimeLabel(_ timestamp: Date, timeframe: ChartTimeframe) -> String {
//        let formatter = DateFormatter()
//
//        switch timeframe {
//        case .m1, .m5, .m15, .m30, .h1, .h4:
//            formatter.dateFormat = "HH:mm"
//        case .d1:
//            formatter.dateFormat = "dd"
//        case .w1:
//            formatter.dateFormat = "dd MMM"
//        case .mn:
//            formatter.dateFormat = "MMM yy"
//        }
//
//        return formatter.string(from: timestamp)
//    }
//
//    // MARK: - Y-Axis Overlay
//
//    @ViewBuilder
//    func yAxisOverlay(geometry: GeometryProxy) -> some View {
//        HStack {
//            Spacer()
//            Canvas { context, size in
//                drawYAxisLabels(context: context, size: size, geometry: geometry)
//            }
//            .frame(width: yAxisWidth)
//            .background(Color.black.opacity(0.8))
//        }
//        .allowsHitTesting(false)
//    }
//
//    private func drawYAxisLabels(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
//        let priceRange = chartData.priceRange
//        let scaledHeight = geometry.size.height * gestureState.priceScale
//        let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
//
//        let priceHelper = PriceAxisHelper(
//            symbol: currentSymbol,
//            priceRange: priceRange,
//            priceScale: gestureState.priceScale,
//            chartHeight: geometry.size.height
//        )
//
//        let step = priceHelper.nicePriceStep
//
//        let extendedStartPrice = floor((priceRange.min - step * 30) / step) * step
//        let extendedEndPrice = ceil((priceRange.max + step * 30) / step) * step
//
//        var currentPrice = extendedStartPrice
//        var labelCount = 0
//        let maxLabels = 100
//
//        while currentPrice <= extendedEndPrice && labelCount < maxLabels {
//            let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
//            let y = size.height - (CGFloat(normalizedPrice) * scaledHeight) - totalVerticalOffset
//
//            if y >= -300 && y <= size.height + 300 {
//                let priceText = chartData.formatPrice(currentPrice)
//
//                context.draw(
//                    Text(priceText)
//                        .font(.system(size: 11))
//                        .foregroundColor(.gray),
//                    at: CGPoint(x: 30, y: y)
//                )
//                labelCount += 1
//            }
//
//            currentPrice += step
//        }
//    }
//
//    // MARK: - Chart Info Box
//
//    @ViewBuilder
//    func chartInfoBox(geometry: GeometryProxy) -> some View {
//        VStack {
//            HStack {
//                chartInfoContent
//                Spacer()
//            }
//            .padding(.leading, 8)
//            .padding(.top, 8)
//
//            Spacer()
//        }
//        .allowsHitTesting(false)
//    }
//
//    @ViewBuilder
//    private var chartInfoContent: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            symbolTimeframeRow
//            priceRow
//        }
//        .padding(.horizontal, 10)
//        .padding(.vertical, 8)
//        .background(Color.black.opacity(0.7))
//        .cornerRadius(8)
//    }
//
//    @ViewBuilder
//    private var symbolTimeframeRow: some View {
//        HStack(spacing: 8) {
//            Text(currentSymbol?.symbol ?? "—")
//                .font(.system(size: 14, weight: .bold))
//                .foregroundColor(.white)
//
//            Text(currentTimeframe.shortName)
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundColor(.white.opacity(0.8))
//                .padding(.horizontal, 6)
//                .padding(.vertical, 2)
//                .background(Color.blue.opacity(0.6))
//                .cornerRadius(4)
//        }
//    }
//
//    @ViewBuilder
//    private var priceRow: some View {
//        HStack(spacing: 6) {
//            Text(chartData.formatPrice(chartData.currentPrice))
//                .font(.system(size: 13, weight: .medium, design: .monospaced))
//                .foregroundColor(priceChangeColor)
//
//            priceChangeIndicator
//        }
//    }
//
//    @ViewBuilder
//    private var priceChangeIndicator: some View {
//        if let lastCandle = chartData.candles.last,
//           chartData.candles.count > 1,
//           let prevCandle = chartData.candles.dropLast().last {
//            let change = lastCandle.close - prevCandle.close
//            let changePercent = (change / prevCandle.close) * 100
//
//            HStack(spacing: 2) {
//                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
//                    .font(.system(size: 9, weight: .bold))
//                Text(String(format: "%.2f%%", abs(changePercent)))
//                    .font(.system(size: 10, weight: .medium))
//            }
//            .foregroundColor(change >= 0 ? .green : .red)
//        }
//    }
//
//    // MARK: - Chart Controls Box
//
//    @ViewBuilder
//    func chartControlsBox(geometry: GeometryProxy) -> some View {
//        let bottomAreaHeight = geometry.size.height * 0.11 + 40
//        let yaxisOverlayWidth = yAxisWidth + 10
//        VStack {
//            Spacer()
//            HStack(spacing: 10) {
//                Spacer()
//                ChartBottomControlButton(
//                    title: "Reset",
//                    icon: "arrow.counterclockwise",
//                    color: .white.opacity(0.5)
//                ) {
//                    controlViewModel.resetChart()
//                }
//                .allowsHitTesting(true)
//
//                ChartBottomControlButton(
//                    title: "Latest",
//                    icon: "arrow.right.to.line",
//                    color: .white.opacity(0.5)
//                ) {
//                    controlViewModel.jumpToLatest()
//                }
//                .allowsHitTesting(true)
//            }
//            .padding(.bottom, bottomAreaHeight)
//            .padding(.trailing, yaxisOverlayWidth)
//        }
//    }
//
//    // MARK: - Chart Drawing
//
//    private func drawChart(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
//        var drawingContext = context
//
//        drawingContext.clip(to: Path(CGRect(origin: .zero, size: size)))
//
//        let totalOffset = gestureState.panOffset.width
//        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
//
//        drawGrid(context: drawingContext, size: size)
//        drawCandlesticks(context: drawingContext, size: size)
//
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
//            totalOffset: totalOffset,
//            markerManager: markerManager,
//            selectedMarkerId: markerManager.selectedMarker?.id ?? tappedMarkerId
//        )
//    }
//
//    private func drawGrid(context: GraphicsContext, size: CGSize) {
//        let priceRange = chartData.priceRange
//        let scaledHeight = size.height * gestureState.priceScale
//        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
//        let totalOffset = gestureState.panOffset.width
//        let timeframe = chartViewModel.currentTimeframe
//
//        let gridPath = Path { path in
//            drawVerticalGridLines(path: &path, size: size, totalOffset: totalOffset, timeframe: timeframe)
//            drawHorizontalGridLines(path: &path, size: size, priceRange: priceRange, scaledHeight: scaledHeight, totalVerticalOffset: totalVerticalOffset)
//        }
//
//        context.stroke(gridPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
//    }
//
//    private func drawVerticalGridLines(path: inout Path, size: CGSize, totalOffset: CGFloat, timeframe: ChartTimeframe) {
//        let niceInterval = getNiceTimeInterval(timeframe: timeframe, zoomScale: gestureState.candleWidthScale)
//
//        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 30)
//        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 60)
//
//        guard visibleStartIndex < visibleEndIndex else { return }
//
//        for i in visibleStartIndex..<visibleEndIndex {
//            guard i >= 0 && i < chartData.candles.count else { continue }
//
//            let candle = chartData.candles[i]
//
//            let isMidnight = isAtMidnight(candle.timestamp, timeframe: timeframe)
//            let isNiceBoundary = isNiceTimeBoundary(candle.timestamp, interval: niceInterval, timeframe: timeframe)
//
//            if isMidnight || isNiceBoundary {
//                let x = CGFloat(i) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//
//                if x >= -100 && x <= size.width + 100 {
//                    path.move(to: CGPoint(x: x, y: 0))
//                    path.addLine(to: CGPoint(x: x, y: size.height))
//                }
//            }
//        }
//    }
//
//    private func drawHorizontalGridLines(path: inout Path, size: CGSize, priceRange: (min: Double, max: Double), scaledHeight: CGFloat, totalVerticalOffset: CGFloat) {
//        let priceHelper = PriceAxisHelper(
//            symbol: currentSymbol,
//            priceRange: priceRange,
//            priceScale: gestureState.priceScale,
//            chartHeight: size.height
//        )
//
//        let step = priceHelper.nicePriceStep
//
//        let extendedStartPrice = floor((priceRange.min - step * 30) / step) * step
//        let extendedEndPrice = ceil((priceRange.max + step * 30) / step) * step
//
//        var currentPrice = extendedStartPrice
//        var lineCount = 0
//        let maxLines = 100
//
//        while currentPrice <= extendedEndPrice && lineCount < maxLines {
//            let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
//            let y = size.height - (CGFloat(normalizedPrice) * scaledHeight) - totalVerticalOffset
//
//            if y >= -500 && y <= size.height + 500 {
//                path.move(to: CGPoint(x: 0, y: y))
//                path.addLine(to: CGPoint(x: size.width, y: y))
//                lineCount += 1
//            }
//
//            currentPrice += step
//        }
//    }
//
//    private func drawCandlesticks(context: GraphicsContext, size: CGSize) {
//        let priceRange = chartData.priceRange
//        let scaledHeight = size.height * gestureState.priceScale
//        let totalOffset = gestureState.panOffset.width
//
//        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
//        let visibleEndIndex = Swift.min(
//            chartData.candles.count,
//            Swift.max(visibleStartIndex, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
//        )
//
//        guard visibleStartIndex < visibleEndIndex else { return }
//
//        for i in visibleStartIndex..<visibleEndIndex {
//            guard i < chartData.candles.count else { continue }
//            drawSingleCandle(context: context, size: size, index: i, priceRange: priceRange, scaledHeight: scaledHeight, totalOffset: totalOffset)
//        }
//    }
//
//    private func drawSingleCandle(context: GraphicsContext, size: CGSize, index: Int, priceRange: (min: Double, max: Double), scaledHeight: CGFloat, totalOffset: CGFloat) {
//        let candle = chartData.candles[index]
//        let x = CGFloat(index) * totalCandleWidth + totalOffset
//
//        if x < -totalCandleWidth || x > size.width + totalCandleWidth {
//            return
//        }
//
//        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
//        let highY = size.height -
//            (CGFloat(candle.high - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//            scaledHeight - totalVerticalOffset
//        let lowY = size.height -
//            (CGFloat(candle.low - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//            scaledHeight - totalVerticalOffset
//        let openY = size.height -
//            (CGFloat(candle.open - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//            scaledHeight - totalVerticalOffset
//        let closeY = size.height -
//            (CGFloat(candle.close - priceRange.min) / CGFloat(priceRange.max - priceRange.min)) *
//            scaledHeight - totalVerticalOffset
//
//        let candleColor = candle.close >= candle.open ? Color.green : Color.red
//
//        // Draw wick
//        let wickPath = Path { path in
//            path.move(to: CGPoint(x: x + actualCandleWidth / 2, y: highY))
//            path.addLine(to: CGPoint(x: x + actualCandleWidth / 2, y: lowY))
//        }
//        context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)
//
//        // Draw body
//        let bodyRect = CGRect(
//            x: x,
//            y: Swift.min(openY, closeY),
//            width: actualCandleWidth,
//            height: Swift.max(1, abs(closeY - openY))
//        )
//
//        if candle.close >= candle.open {
//            context.stroke(
//                Path(roundedRect: bodyRect, cornerRadius: 0),
//                with: .color(candleColor),
//                lineWidth: 1
//            )
//            context.fill(
//                Path(roundedRect: bodyRect, cornerRadius: 0),
//                with: .color(candleColor.opacity(0.3))
//            )
//        } else {
//            context.fill(
//                Path(roundedRect: bodyRect, cornerRadius: 0),
//                with: .color(candleColor)
//            )
//        }
//    }
//
//    // MARK: - Chart Position Management
//
//    private func resetChartToMostRecentCandles() {
//        guard !chartData.candles.isEmpty else { return }
//
//        let screenWidth = chartSize.width > 0 ? chartSize.width : UIScreen.main.bounds.width
//        let totalChartWidth = CGFloat(chartData.candles.count) * totalCandleWidth
//
//        let rightPadding = screenWidth * 0.3
//        let targetOffset = -(totalChartWidth - screenWidth + rightPadding)
//
//        let minOffset = -(totalChartWidth - screenWidth + edgePadding)
//        let maxOffset = edgePadding
//        let clampedOffset = max(minOffset, min(maxOffset, targetOffset))
//
//        withAnimation(.easeOut(duration: 0.3)) {
//            gestureState.panOffset.width = clampedOffset
//            gestureState.panOffset.height = 0
//            gestureState.verticalPanOffset = 0
//            gestureState.priceScale = 1.0
//        }
//
//        isChartLoading = false
//    }
//
//    // MARK: - Marker API Loading
//
//    private func loadMarkersFromAPI() async {
//        guard !chartData.candles.isEmpty else { return }
//
//        let symbol = chartViewModel.currentSymbol?.symbol ?? "EURUSD"
//        let guildId = markerManager.guildId
//
//        var markers = SampleData.generateChartMarkers(
//            forSymbol: symbol,
//            guildId: guildId,
//            candleCount: chartData.candles.count,
//            count: 8
//        )
//
//        markers = SampleData.updateMarkerPrices(
//            markers: markers,
//            candles: chartData.candles
//        )
//
//        markers = MarkerPositionCalculator.assignStablePositions(
//            markers: markers,
//            candles: chartData.candles
//        )
//
//        await MainActor.run {
//            markerManager.markers = markers
//        }
//    }
//
//    // MARK: - Control Actions Setup
//
//    private func setupControlActions() {
//        controlViewModel.resetChartAction = {
//            self.gestureState.reset()
//        }
//
//        controlViewModel.jumpToStartAction = {
//            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
//                self.gestureState.panOffset.width = 0
//            }
//        }
//
//        controlViewModel.jumpToLatestAction = {
//            guard !self.chartData.candles.isEmpty else { return }
//            let targetOffset = -CGFloat(self.chartData.candles.count - 1) * self.totalCandleWidth + 100
//            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
//                self.gestureState.panOffset.width = targetOffset
//            }
//        }
//
//        controlViewModel.toggleAutoScrollAction = {
//            print("Auto-scroll toggled")
//        }
//
//        controlViewModel.setHorizontalZoomAction = { zoom in
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                self.gestureState.candleWidthScale = CGFloat(zoom)
//            }
//        }
//
//        controlViewModel.setVerticalZoomAction = { zoom in
//            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                self.gestureState.priceScale = CGFloat(zoom)
//            }
//        }
//    }
//}
//
//// MARK: - ChartBottomControlButton
//
//struct ChartBottomControlButton: View {
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
//                    .font(.system(size: 14))
//                    .foregroundColor(isActive ? .white : color)
//                    .padding(.horizontal, 5)
//                    .padding(.vertical, 3)
//            }
//            .frame(height: 22)
//            .background(
//                isActive ?
//                color :
//                Color.white.opacity(0.08)
//            )
//            .cornerRadius(2)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//// MARK: - Horizontal Line Preview Helper View
//
//struct MarkerHorizontalLinePreview: View {
//    let candle: Candle
//    let markerType: MarkerType
//    let coordinateSystem: ChartCoordinateSystem
//    let chartWidth: CGFloat
//    let chartData: ChartDataManager
//
//    private var linePrice: Double {
//        switch markerType.lineSource {
//        case .candleOpen: return candle.open
//        case .candleClose: return candle.close
//        case .candleHigh: return candle.high
//        case .candleLow: return candle.low
//        case .custom, .none: return candle.close
//        }
//    }
//
//    private var lineY: CGFloat {
//        coordinateSystem.yPosition(forPrice: linePrice)
//    }
//
//    var body: some View {
//        ZStack {
//            Path { path in
//                path.move(to: CGPoint(x: 0, y: lineY))
//                path.addLine(to: CGPoint(x: chartWidth - 65, y: lineY))
//            }
//            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
//            .foregroundColor(markerType.color.opacity(0.7))
//            .allowsHitTesting(false)
//
//            Text(chartData.formatPrice(linePrice))
//                .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                .foregroundColor(.white)
//                .padding(.horizontal, 6)
//                .padding(.vertical, 3)
//                .background(markerType.color)
//                .cornerRadius(4)
//                .position(x: 40, y: lineY)
//                .allowsHitTesting(false)
//        }
//    }
//}
//
//// MARK: - Marker Price Lines Overlay
//
//struct MarkerPriceLinesOverlay: View {
//    let selectedMarker: ChartMarker?
//    let previewMarker: (candle: Candle, type: MarkerType)?
//    let coordinateSystem: ChartCoordinateSystem
//    let chartWidth: CGFloat
//    let chartHeight: CGFloat
//    let chartData: ChartDataManager
//
//    var body: some View {
//        GeometryReader { geometry in
//            Canvas { context, size in
//                drawSelectedMarkerLine(context: context, size: size)
//                drawPreviewMarkerLine(context: context, size: size)
//            }
//        }
//        .allowsHitTesting(false)
//    }
//
//    private func drawSelectedMarkerLine(context: GraphicsContext, size: CGSize) {
//        guard let marker = selectedMarker,
//              marker.type.hasHorizontalLine,
//              let candle = getCandleForMarker(marker) else { return }
//
//        // FIXED: For prediction markers, use horizontalLinePrice (entry price) directly
//        // since getLinePrice may return nil for custom line source types
//        let linePrice: Double?
//        if marker.type == .predictionTarget {
//            // Use stored entry price for prediction markers
//            linePrice = marker.horizontalLinePrice ?? marker.getLinePrice(candle: candle)
//        } else {
//            linePrice = marker.getLinePrice(candle: candle)
//        }
//
//        // Draw entry/main line if we have a price
//        if let price = linePrice {
//            let label = marker.type == .predictionTarget ? "Entry" : nil
//
//            drawPriceLine(
//                context: context,
//                size: size,
//                price: price,
//                color: marker.type.color,
//                isDashed: false,
//                label: label
//            )
//        }
//
//        // Draw target price line for prediction markers
//        if marker.type == .predictionTarget, let targetPrice = marker.targetPrice {
//            drawPriceLine(
//                context: context,
//                size: size,
//                price: targetPrice,
//                color: .orange,
//                isDashed: false,
//                label: "Target"
//            )
//        }
//    }
//
//    private func drawPreviewMarkerLine(context: GraphicsContext, size: CGSize) {
//        guard let preview = previewMarker else { return }
//
//        let linePrice: Double
//        switch preview.type.lineSource {
//        case .candleOpen: linePrice = preview.candle.open
//        case .candleClose: linePrice = preview.candle.close
//        case .candleHigh: linePrice = preview.candle.high
//        case .candleLow: linePrice = preview.candle.low
//        case .custom, .none: linePrice = preview.candle.close
//        }
//
//        let label = preview.type == .predictionTarget ? "Entry" : nil
//
//        drawPriceLine(
//            context: context,
//            size: size,
//            price: linePrice,
//            color: preview.type.color,
//            isDashed: true,
//            label: label
//        )
//    }
//
//    private func getCandleForMarker(_ marker: ChartMarker) -> Candle? {
//        guard marker.candleIndex >= 0 && marker.candleIndex < chartData.candles.count else {
//            return nil
//        }
//        return chartData.candles[marker.candleIndex]
//    }
//
//    private func drawPriceLine(
//        context: GraphicsContext,
//        size: CGSize,
//        price: Double,
//        color: Color,
//        isDashed: Bool,
//        label: String? = nil
//    ) {
//        let y = coordinateSystem.yPosition(forPrice: price)
//
//        guard y >= 0 && y <= chartHeight else { return }
//
//        let lineEndX = size.width - 60
//
//        let linePath = Path { path in
//            path.move(to: CGPoint(x: 0, y: y))
//            path.addLine(to: CGPoint(x: lineEndX, y: y))
//        }
//
//        let strokeStyle = isDashed ?
//            StrokeStyle(lineWidth: 1.5, dash: [6, 4]) :
//            StrokeStyle(lineWidth: 2)
//
//        context.stroke(linePath, with: .color(color.opacity(0.6)), style: strokeStyle)
//
//        let labelX = size.width - 35
//        let priceText = chartData.formatPrice(price)
//
//        let displayText: String
//        if let label = label {
//            displayText = "\(label) \(priceText)"
//        } else {
//            displayText = priceText
//        }
//
//        let estimatedWidth: CGFloat = label != nil ? 110 : 70
//        let labelRect = CGRect(
//            x: labelX - estimatedWidth/2,
//            y: y - 11,
//            width: estimatedWidth,
//            height: 22
//        )
//
//        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
//        context.fill(roundedPath, with: .color(color))
//
//        context.draw(
//            Text(displayText)
//                .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                .foregroundColor(.white),
//            at: CGPoint(x: labelX, y: y)
//        )
//    }
//}
//
//// MARK: - Prediction Target Line Overlay
//
//struct PredictionTargetLineOverlay: View {
//    let entryPrice: Double
//    @Binding var targetPrice: Double?
//    @Binding var isDragging: Bool
//    let isInteractive: Bool
//    let coordinateSystem: ChartCoordinateSystem
//    let chartWidth: CGFloat
//    let chartHeight: CGFloat
//    let chartData: ChartDataManager
//
//    // FIXED: Store initial Y position when drag starts to prevent feedback loop
//    @State private var dragStartY: CGFloat = 0
//    @State private var dragStartPrice: Double = 0
//
//    var body: some View {
//        ZStack {
//            targetLineCanvas
//
//            if isInteractive, let currentTargetPrice = targetPrice {
//                draggableArea(currentTargetPrice: currentTargetPrice)
//            }
//        }
//    }
//
//    @ViewBuilder
//    private var targetLineCanvas: some View {
//        Canvas { context, size in
//            guard let targetPrice = targetPrice else { return }
//
//            let y = coordinateSystem.yPosition(forPrice: targetPrice)
//            guard y >= 0 && y <= chartHeight else { return }
//
//            drawTargetLine(context: context, size: size, y: y)
//            drawTargetLabel(context: context, size: size, y: y)
//
//            if isInteractive {
//                drawDragHandle(context: context, y: y)
//            }
//        }
//        .allowsHitTesting(false)
//    }
//
//    private func drawTargetLine(context: GraphicsContext, size: CGSize, y: CGFloat) {
//        let lineEndX = size.width - 60
//        let linePath = Path { path in
//            path.move(to: CGPoint(x: 0, y: y))
//            path.addLine(to: CGPoint(x: lineEndX, y: y))
//        }
//
//        let lineWidth: CGFloat = isDragging ? 3 : 2
//        context.stroke(linePath, with: .color(Color.orange.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth))
//    }
//
//    private func drawTargetLabel(context: GraphicsContext, size: CGSize, y: CGFloat) {
//        guard let targetPrice = targetPrice else { return }
//
//        let labelX = size.width - 35
//        let priceText = chartData.formatPrice(targetPrice)
//        let displayText = "Target \(priceText)"
//
//        let estimatedWidth: CGFloat = 110
//        let labelRect = CGRect(
//            x: labelX - estimatedWidth/2,
//            y: y - 11,
//            width: estimatedWidth,
//            height: 22
//        )
//
//        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
//        context.fill(roundedPath, with: .color(Color.orange))
//
//        context.draw(
//            Text(displayText)
//                .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                .foregroundColor(.white),
//            at: CGPoint(x: labelX, y: y)
//        )
//    }
//
//    private func drawDragHandle(context: GraphicsContext, y: CGFloat) {
//        let handleSize: CGFloat = 40
//        let handleRect = CGRect(
//            x: 10,
//            y: y - handleSize/2,
//            width: handleSize,
//            height: handleSize
//        )
//
//        let handlePath = Path(roundedRect: handleRect, cornerRadius: 8)
//        context.fill(handlePath, with: .color(Color.orange.opacity(isDragging ? 0.3 : 0.2)))
//
//        let arrowsImage = Image(systemName: "arrow.up.arrow.down")
//        context.draw(arrowsImage, in: handleRect)
//    }
//
//    @ViewBuilder
//    private func draggableArea(currentTargetPrice: Double) -> some View {
//        // FIXED: Capture initial position on drag start to prevent feedback loop
//        GeometryReader { geo in
//            let currentY = coordinateSystem.yPosition(forPrice: currentTargetPrice)
//
//            Color.clear
//                .contentShape(Rectangle())
//                .frame(width: geo.size.width, height: 60)
//                .position(x: geo.size.width / 2, y: currentY)
//                .highPriorityGesture(
//                    DragGesture(minimumDistance: 0)
//                        .onChanged { value in
//                            if !isDragging {
//                                // FIXED: Capture starting position on first touch
//                                isDragging = true
//                                dragStartY = currentY
//                                dragStartPrice = currentTargetPrice
//                            }
//
//                            // FIXED: Calculate new Y based on drag translation from START position
//                            // This prevents the feedback loop where changing price changes Y
//                            let newY = dragStartY + value.translation.height
//
//                            // Convert to price
//                            let newPrice = coordinateSystem.price(atYPosition: newY)
//
//                            // Clamp to visible price range
//                            let minPrice = chartData.priceRange.min
//                            let maxPrice = chartData.priceRange.max
//                            self.targetPrice = max(minPrice, min(maxPrice, newPrice))
//                        }
//                        .onEnded { _ in
//                            isDragging = false
//                        }
//                )
//        }
//    }
//}
//
//// MARK: - Static Target Line
//
//struct StaticTargetLineOverlay: View {
//    let entryPrice: Double
//    let targetPrice: Double
//    let coordinateSystem: ChartCoordinateSystem
//    let chartWidth: CGFloat
//    let chartHeight: CGFloat
//    let chartData: ChartDataManager
//
//    var body: some View {
//        Canvas { context, size in
//            let y = coordinateSystem.yPosition(forPrice: targetPrice)
//            guard y >= 0 && y <= chartHeight else { return }
//
//            let lineEndX = size.width - 60
//
//            let linePath = Path { path in
//                path.move(to: CGPoint(x: 0, y: y))
//                path.addLine(to: CGPoint(x: lineEndX, y: y))
//            }
//
//            context.stroke(linePath, with: .color(Color.orange.opacity(0.8)), style: StrokeStyle(lineWidth: 2))
//
//            let labelX = size.width - 35
//            let priceText = chartData.formatPrice(targetPrice)
//            let displayText = "Target \(priceText)"
//
//            let labelRect = CGRect(
//                x: labelX - 55,
//                y: y - 11,
//                width: 110,
//                height: 22
//            )
//
//            let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
//            context.fill(roundedPath, with: .color(Color.orange))
//
//            context.draw(
//                Text(displayText)
//                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
//                    .foregroundColor(.white),
//                at: CGPoint(x: labelX, y: y)
//            )
//        }
//        .allowsHitTesting(false)
//    }
//}
//
//
