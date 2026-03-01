

import SwiftUI

// MARK: - Prediction Placement State

/// Tracks the state of the prediction marker placement flow (3-line system)
struct PredictionPlacementState {
    var entryPrice: Double
    var takeProfitPrice: Double
    var stopLossPrice: Double
    var candleIndex: Int

    /// Auto-detect direction from TP position relative to entry
    var isLong: Bool { takeProfitPrice > entryPrice }

    var riskRewardRatio: Double {
        let reward = abs(takeProfitPrice - entryPrice)
        let risk = abs(stopLossPrice - entryPrice)
        guard risk > 0 else { return 0 }
        return reward / risk
    }

    var potentialProfitPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return abs(takeProfitPrice - entryPrice) / entryPrice * 100
    }

    var potentialLossPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return abs(stopLossPrice - entryPrice) / entryPrice * 100
    }
}

/// Which prediction line is currently being dragged
enum PredictionLineType {
    case takeProfit
    case stopLoss
}

// MARK: - Pending Marker Info

/// FIXED: Captures marker type at placement time to prevent sheet presentation errors
/// Now Identifiable to support sheet(item:) binding for more robust presentation
struct PendingMarkerInfo: Identifiable {
    let id = UUID()
    let candleIndex: Int
    let timestamp: Date
    let price: Double
    let markerType: RLMarkerType
    let targetPrice: Double?
    let horizontalLinePrice: Double?
    let stopLossPrice: Double?

    init(candleIndex: Int, timestamp: Date, price: Double, markerType: RLMarkerType, targetPrice: Double? = nil, horizontalLinePrice: Double? = nil, stopLossPrice: Double? = nil) {
        self.candleIndex = candleIndex
        self.timestamp = timestamp
        self.price = price
        self.markerType = markerType
        self.targetPrice = targetPrice
        self.horizontalLinePrice = horizontalLinePrice
        self.stopLossPrice = stopLossPrice
    }
}

/// Main trading chart view that handles all chart rendering and interactions
/// Features centered scaling that keeps visible candles in view during zoom
/// Includes marker placement system for collaborative chart annotations
struct TradingChartView: View {
    // MARK: - State Properties
    
    // MARK: - Chart Context Accessors

    private var currentTimeframe: RLChartTimeframe {
        chartViewModel.currentTimeframe
    }

    private var currentSymbol: RLTradingSymbolDTO? {
        chartViewModel.currentSymbol
    }
    
    // MARK: - Chart Control ViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel
    
    /// Gesture state manager that handles all pan/zoom transformations
    /// This is the single source of truth for chart positioning
    @ObservedObject var gestureState: ChartGestureState
    
    // MARK: - Overlay Managers
    
    /// Manages all markers on the chart (creation, deletion, filtering)
    /// Initialized lazily when user/guild data is available
    @StateObject private var markerManager: MarkerManager = {
        // Temporary initialization - will be reconfigured when real data is available
        // This is a workaround since we need StateObject but don't have user/guild data at init time
        // The markerManager will be properly configured in onAppear or when chart loads
        let placeholderMember = RLGuildMemberDTO(
            membershipId: UUID(),
            role: "member",
            reputation: 0,
            contributionScore: 0,
            dateJoined: Date(),
            accuracyRate: nil,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: UUID(),
            username: "unknown",
            displayName: "Unknown",
            avatarUrl: nil,
            isOnline: false,
            globalReputation: 0,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
        return MarkerManager(
            userId: placeholderMember.userId,
            guildId: UUID(),
            currentUserMember: placeholderMember
        )
    }()
    
    /// Manages crosshair functionality for price inspection
    /// Activated by long press, allows precise price/time reading
    @StateObject private var crosshairManager = CrosshairManager()
    
    /// Manages chart navigation controls (auto-scroll, jump to latest, etc)
    @StateObject private var navigationManager = ChartNavigationManager()
    
    
    
    /// RSI panel height binding for control box positioning
    @Binding var rsiPanelHeight: CGFloat
    
    /// Total height of all active indicator panels (for bottom controls positioning)
    /// Passed from MainView to ensure controls float above panels
    var indicatorPanelBottomPadding: CGFloat = 0

    /// Current user/guild context for marker ownership and filtering.
    private let currentUserId: UUID
    private let currentGuildId: UUID
    private let currentUserMember: RLGuildMemberDTO
    private let currentUsername: String
    
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
    
    
    
    // MARK: - UI State
    
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
    /// FIXED: Now Identifiable and used with sheet(item:) for robust presentation
    /// Contains candle index, timestamp, price, and marker type of pending marker
    @State private var pendingMarkerInfo: PendingMarkerInfo?
    
    /// PREDICTION TARGET STATE (legacy — kept for backward compatibility but replaced by predictionPlacement)
    /// For prediction markers, user must set entry (candle) then target (draggable line)
    /// Target price is selected via draggable horizontal line before opening config sheet
    @State private var predictionTargetPrice: Double? = nil
    @State private var isDraggingTarget: Bool = false
    @State private var isAwaitingTargetSelection: Bool = false

    /// NEW PREDICTION PLACEMENT STATE (3-line system: Entry + TP + SL)
    @State private var predictionPlacement: PredictionPlacementState? = nil
    @State private var draggingPredictionLine: PredictionLineType? = nil

    /// Price for the interactive placement line (for Entry/Exit/TP/SL markers during placement)
    @State private var placementLinePrice: Double? = nil
    /// Whether the placement line is actively being dragged
    @State private var isDraggingPlacementLine: Bool = false

    /// Current candle index where the preview marker is positioned
    /// Updates in real-time as user drags during placement mode
    /// Initialized to -1 to indicate "not yet calculated"
    /// Will be set to center when placement mode starts
    @State private var previewCandleIndex: Int = -1
    
    /// Track the actual drag position for free-form marker movement
    /// This allows marker to follow finger in 2D before snapping on release
    @State private var markerDragPosition: CGPoint?
    
    @State private var chartSize: CGSize = .zero
    
    /// Stores crosshair position at start of drag for relative movement
    /// This allows crosshair to move by delta instead of jumping to finger position
    @State private var crosshairDragStartPosition: CGPoint? = nil

    
    /// Whether to show duplicate marker type alert
    @State private var showDuplicateMarkerAlert = false

    /// Marker visibility type-filter sheet state.
    @State private var showMarkerTypeFilterSheet = false
    @State private var isMarkerVisibilityPanelExpanded = false
    

    
    /// Placement options written by MarkerCreationSheet for preview (alert severity color, selected emoji)
    @State private var placementAlertSeverity: MarkerAlertSeverity? = nil
    @State private var placementSelectedEmoji: String? = nil

    /// Track if chart has been initialized with proper position
    @State private var hasInitializedPosition = false
    
    /// Track if chart is loading (waiting for data)
    @State private var isChartLoading = true
    
    /// Track the marker ID that was just tapped (for animation)
    @State private var tappedMarkerId: UUID? = nil
    
    /// Haptic feedback generator for marker interactions
    private let markerHaptic = UIImpactFeedbackGenerator(style: .medium)
    
    /// Marker detail sheet presentation detent (controls sheet size); starts small so sheet opens compact
    @State private var markerDetailDetent: PresentationDetent = .fraction(0.35)
    
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
    private let minHorizontalScale: CGFloat = 0.15
    
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
    ///   - rsiPanelHeight: Binding to RSI panel height (for control box positioning)
    ///   - indicatorPanelBottomPadding: Total height of all active indicator panels
    init(
        userId: UUID = UUID(),
        username: String = "TestUser",
        guildId: UUID = UUID(),
        currentUserMember: RLGuildMemberDTO? = nil,
        controlViewModel: ChartControlViewModel,
        chartViewModel: ChartViewModel,
        gestureState: ChartGestureState,
        rsiPanelHeight: Binding<CGFloat> = .constant(120),
        indicatorPanelBottomPadding: CGFloat = 0
    ) {
        let resolvedMember = currentUserMember ?? RLGuildMemberDTO(
            membershipId: UUID(),
            role: "member",
            reputation: 0,
            contributionScore: 0,
            dateJoined: Date(),
            accuracyRate: nil,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: userId,
            username: username,
            displayName: username,
            avatarUrl: nil,
            isOnline: false,
            globalReputation: 0,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )

        self.currentUserId = userId
        self.currentGuildId = guildId
        self.currentUserMember = resolvedMember
        self.currentUsername = username
        _markerManager = StateObject(wrappedValue: MarkerManager(
            userId: userId,
            guildId: guildId,
            currentUserMember: resolvedMember
        ))
        self.controlViewModel = controlViewModel
        self.chartViewModel = chartViewModel
        self.gestureState = gestureState
        self._rsiPanelHeight = rsiPanelHeight
        self.indicatorPanelBottomPadding = indicatorPanelBottomPadding
    }
    
    // MARK: - Target Line Helpers
    
    /// Whether to show interactive target line during selection
    private var shouldShowInteractiveTargetLine: Bool {
        guard let markerType = controlViewModel.currentMarkerType else { return false }
        guard markerType == .predictionTarget else { return false }
        guard previewCandleIndex >= 0 && previewCandleIndex < chartData.candles.count else { return false }
        guard predictionTargetPrice != nil else { return false }
        return true
    }
    
    /// Whether to show static target line during configuration
    /// Suppressed — prediction markers now use MarkerPriceLinesOverlay for full 3-line rendering
    private var shouldShowStaticTargetLine: Bool {
        return false
    }
    
    // MARK: - Marker Preview Helpers
    
    /// Get the currently selected or tapped marker
    private var activeSelectedMarker: ChartMarkerUI? {
        if let selected = markerManager.selectedMarker {
            return selected
        }
        if let tappedId = tappedMarkerId {
            return markerManager.markers.first(where: { $0.id == tappedId })
        }
        return nil
    }
    
    /// Get preview marker data for price line display
    private var previewMarkerForPriceLine: (candle: RLCandleDTO, type: RLMarkerType)? {
        // When sheet is open (pendingMarkerInfo exists), use that data
        if let pending = pendingMarkerInfo,
           pending.candleIndex >= 0,
           pending.candleIndex < chartData.candles.count,
           pending.markerType.hasHorizontalLine {
            return (chartData.candles[pending.candleIndex], pending.markerType)
        }

        // Suppress preview line when PlacementLineDragOverlay is active (avoids double line)
        if isMarkerPlacementMode,
           let markerType = controlViewModel.currentMarkerType,
           [RLMarkerType.entry, .exit, .takeProfit, .stopLoss, .support, .resistance].contains(markerType) {
            return nil
        }

        // Suppress preview line when prediction overlay is active
        if isMarkerPlacementMode,
           controlViewModel.currentMarkerType == .predictionTarget,
           predictionPlacement != nil {
            return nil
        }

        // Otherwise use placement mode preview
        if isMarkerPlacementMode,
           previewCandleIndex >= 0,
           previewCandleIndex < chartData.candles.count,
           let markerType = controlViewModel.currentMarkerType,
           markerType.hasHorizontalLine {
            return (chartData.candles[previewCandleIndex], markerType)
        }

        return nil
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
    
    /// Whether loading overlay should be shown
    private var shouldShowLoadingOverlay: Bool {
        isChartLoading || chartViewModel.currentSymbol == nil || chartData.candles.isEmpty
    }
    
    /// Effective candle index for marker preview (from pending or placement mode)
    /// Prediction markers are pinned to the most recent candle.
    private var effectiveCandleIndex: Int {
        if let pending = pendingMarkerInfo {
            return pending.candleIndex
        }
        if isMarkerPlacementMode {
            // Prediction: always use latest candle (entry pinned to most recent)
            if controlViewModel.currentMarkerType == .predictionTarget {
                return max(0, chartData.candles.count - 1)
            }
            if previewCandleIndex < 0 {
                return calculateCenterCandleIndex()
            }
            return max(0, min(chartData.candles.count - 1, previewCandleIndex))
        }
        return max(0, previewCandleIndex)
    }
    
    /// Effective marker type for preview (from pending or placement mode)
    private var effectiveMarkerType: RLMarkerType? {
        pendingMarkerInfo?.markerType ?? controlViewModel.currentMarkerType
    }
    
    /// Whether marker placement overlay should be shown
    private var shouldShowMarkerPlacementOverlay: Bool {
        isMarkerPlacementMode || pendingMarkerInfo != nil
    }
    
    /// Whether instruction banner should be shown
    private var shouldShowInstructionBanner: Bool {
        // FIXED: Check pendingMarkerInfo instead of showMarkerSheet/isShowingSheet
        isMarkerPlacementMode && pendingMarkerInfo == nil
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                chartContent(geometry: geometry)
            }
        }
        // FIXED: Use sheet(item:) instead of sheet(isPresented:) for more robust presentation
        // This ensures the sheet content always has valid data when shown
        .sheet(item: $pendingMarkerInfo) { info in
            MarkerCreationSheet(
                markerManager: markerManager,
                candleIndex: info.candleIndex,
                timestamp: info.timestamp,
                price: info.price,
                username: currentUsername,
                chartData: chartData,
                candles: chartData.candles,
                markerType: info.markerType,
                initialTargetPrice: info.targetPrice,
                initialHorizontalLinePrice: info.horizontalLinePrice,
                initialStopLossPrice: info.stopLossPrice,
                placementAlertSeverity: $placementAlertSeverity,
                placementSelectedEmoji: $placementSelectedEmoji
            )
            .presentationDetents([.fraction(0.5), .large])
            .presentationDragIndicator(.visible)
            .onDisappear(perform: handleMarkerSheetDismiss)
        }
        .sheet(item: $markerManager.selectedMarker) { marker in
            MarkerDetailView(
                marker: marker,
                markerManager: markerManager,
                selectedDetent: $markerDetailDetent
            )
            .presentationDetents([.fraction(0.35), .fraction(0.5), .large], selection: $markerDetailDetent)
            .presentationDragIndicator(.visible)
            .presentationBackground {
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                    AppColors.sheetBackground
                }
            }
            .presentationCornerRadius(33)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showMarkerTypeFilterSheet) {
            markerTypeFilterSheet
        }
        .onChange(of: markerManager.selectedMarker) { _, new in
            if new != nil {
                markerDetailDetent = .fraction(0.35)
            }
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: currentGuildId) { _, _ in
            syncMarkerContext()
        }
        .onChange(of: currentUserId) { _, _ in
            syncMarkerContext()
        }
        .onChange(of: controlViewModel.isMarkerPlacementMode) { oldValue, newValue in
            handleMarkerPlacementModeChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: chartViewModel.currentSymbol) { oldValue, newValue in
            handleSymbolChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: chartViewModel.currentSymbol?.ticker) { oldValue, newValue in
            handleSymbolStringChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: chartViewModel.currentTimeframe) { oldValue, newValue in
            handleTimeframeChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: chartData.candles.count) { oldCount, newCount in
            handleCandleCountChange(oldCount: oldCount, newCount: newCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSharedMarker)) { notification in
            guard let userInfo = notification.userInfo,
                  let payload = MarkerSharePayloadV1(userInfo) else { return }
            focusSharedMarker(payload)
        }
    }
    
    // MARK: - Main Chart Content
    
    @ViewBuilder
    private func chartContent(geometry: GeometryProxy) -> some View {
        let coordinateSystem = createCoordinateSystem(geometry: geometry)

        ZStack {
            ZStack {
                Color.black.ignoresSafeArea().opacity(0.2)

                mainChartCanvas(geometry: geometry)

                markerGuideOverlay(geometry: geometry)
                    .zIndex(8)

                if shouldShowMarkerPlacementOverlay {
                    markerPlacementOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                        .zIndex(18)
                }

                yAxisOverlay(geometry: geometry)

                // Interactive placement line for trade idea markers (Entry/Exit/TP/SL)
                // Placed AFTER yAxisOverlay so price labels render ON TOP of Y-axis background
                if controlViewModel.isMarkerPlacementMode,
                   let markerType = controlViewModel.currentMarkerType,
                   markerType != .predictionTarget,
                   [RLMarkerType.entry, .exit, .takeProfit, .stopLoss, .support, .resistance].contains(markerType),
                   effectiveCandleIndex >= 0,
                   effectiveCandleIndex < chartData.candles.count {
                    let candle = chartData.candles[effectiveCandleIndex]
                    let defaultPrice = markerType.lineSource.priceFromCandle(candle)
                    PlacementLineDragOverlay(
                        markerType: markerType,
                        defaultPrice: defaultPrice,
                        linePrice: $placementLinePrice,
                        isDragging: $isDraggingPlacementLine,
                        coordinateSystem: coordinateSystem,
                        chartWidth: geometry.size.width,
                        chartHeight: geometry.size.height,
                        chartData: chartData
                    )
                }

                // Prediction 3-line overlay (Entry + TP + SL)
                // Placed AFTER yAxisOverlay so price labels render ON TOP of Y-axis background
                if controlViewModel.isMarkerPlacementMode,
                   controlViewModel.currentMarkerType == .predictionTarget,
                   predictionPlacement != nil {
                    PredictionPlacementOverlay(
                        placement: $predictionPlacement,
                        draggingLine: $draggingPredictionLine,
                        coordinateSystem: coordinateSystem,
                        chartWidth: geometry.size.width,
                        chartHeight: geometry.size.height,
                        chartData: chartData
                    )
                }

                priceIndicatorView(geometry: geometry)
                xAxisOverlay(geometry: geometry)
                chartInfoBox(geometry: geometry)
                markerPriceLinesOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                draggableMarkerLineOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                draggablePredictionLinesOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                targetLineOverlays(coordinateSystem: coordinateSystem, geometry: geometry)

                CrosshairView(
                    crosshairManager: crosshairManager,
                    chartSize: geometry.size,
                    chartData: chartData,
                    rsiPanelActive: chartViewModel.indicatorManager.shouldShowAnyPanel,
                    rsiPanelHeight: rsiPanelHeight,
                    indicatorManager: chartViewModel.indicatorManager,
                    timeframe: chartViewModel.currentTimeframe
                )

                if shouldShowInstructionBanner {
                    instructionBanner(coordinateSystem: coordinateSystem)
                }
            }
            // Gestures are attached only to the interactive chart layer.
            .gesture(crosshairDismissTapGesture())
            .gesture(crosshairGesture(coordinateSystem: coordinateSystem))
            .simultaneousGesture(tapGestureForMarkers(geometry: geometry))
            .simultaneousGesture(dragGesture(in: geometry.size, coordinateSystem: coordinateSystem))
            .simultaneousGesture(pinchGesture(in: geometry.size))
            .overlay(yAxisGestureOverlay)
            .overlay(loadingOverlayIfNeeded)
            .overlay(duplicateMarkerOverlayIfNeeded)
            .onAppear {
                updateChartSize(geometry.size)
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: markerManager.selectedMarker?.id) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: markerManager.selectedMarker?.candleIndex) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: gestureState.panOffset.width) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: gestureState.candleWidthScale) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: chartData.candles.count) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: controlViewModel.isMarkerPlacementMode) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }

            chartControlsBox(geometry: geometry)
                .zIndex(60)
        }
    }
    
    // MARK: - Coordinate System Factory
    
    private func createCoordinateSystem(geometry: GeometryProxy) -> ChartCoordinateSystem {
        let coordinateSystem = ChartCoordinateSystem(
            chartData: chartData,
            gestureState: gestureState,
            chartSize: geometry.size,
            baseCandleWidth: baseCandleWidth,
            candleSpacing: candleSpacing
        )
        _ = coordinateSystem.updateLiveState(dragState: dragState, pinchScale: 1.0)
        return coordinateSystem
    }
    
    
    
    
    // MARK: - Indicators
    
    /// Create drawing data for indicators (computed on main thread before Canvas)
    /// UPDATED: Now includes all overlay indicators (BB, VWAP, Donchian, Keltner, SAR)
    private var indicatorDrawingData: IndicatorDrawingData {
        let im = chartViewModel.indicatorManager
        return IndicatorDrawingData(
            maConfigs: im.activeIndicators.enabledMovingAverages,
            maDataMap: im.movingAverageData,
            vwapConfig: im.activeIndicators.vwap,
            vwapData: im.vwapData,
            sarConfig: im.activeIndicators.parabolicSAR,
            sarData: im.parabolicSARData,
            bbConfig: im.activeIndicators.bollingerBands,
            bbData: im.bollingerBandsData,
            dcConfig: im.activeIndicators.donchianChannels,
            dcData: im.donchianChannelsData,
            kcConfig: im.activeIndicators.keltnerChannels,
            kcData: im.keltnerChannelsData
        )
    }
    
    
    
    
    private func updateChartSize(_ size: CGSize) {
        if chartSize != size {
            DispatchQueue.main.async {
                chartSize = size
            }
        }
    }
    
    // MARK: - Main Chart Canvas
    
    @ViewBuilder
    private func mainChartCanvas(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            drawChart(context: context, size: size, geometry: geometry)
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Price Indicator View
    
    @ViewBuilder
    private func priceIndicatorView(geometry: GeometryProxy) -> some View {
        PriceIndicatorView(
            currentPrice: chartData.currentPrice,
            priceScale: gestureState.priceScale,
            verticalOffset: clampedVerticalOffset(chartHeight: geometry.size.height),
            chartHeight: geometry.size.height,
            priceRange: chartData.priceRange,
            chartData: chartData
        )
    }
    
    @ViewBuilder
    private func draggableMarkerLineOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        if let marker = activeSelectedMarker,
           (marker.type == .entry || marker.type == .exit || marker.type == .takeProfit || marker.type == .stopLoss),
           marker.type.hasHorizontalLine,
           let candle = chartData.candles.indices.contains(marker.candleIndex) ? chartData.candles[marker.candleIndex] : nil,
           let linePrice = marker.horizontalLinePrice ?? marker.linePrice(for: candle) {
            DraggableMarkerLineOverlay(
                marker: marker,
                currentPrice: linePrice,
                markerManager: markerManager,
                coordinateSystem: coordinateSystem,
                chartWidth: geometry.size.width,
                chartHeight: geometry.size.height,
                chartData: chartData
            )
        }
    }

    @ViewBuilder
    private func draggablePredictionLinesOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        if let marker = activeSelectedMarker,
           marker.type == .predictionTarget,
           marker.candleIndex >= 0,
           marker.candleIndex < chartData.candles.count {
            let candle = chartData.candles[marker.candleIndex]
            let entryPrice = marker.horizontalLinePrice ?? marker.linePrice(for: candle) ?? marker.price
            DraggablePredictionLinesOverlay(
                marker: marker,
                entryPrice: entryPrice,
                targetPrice: marker.targetPrice,
                markerManager: markerManager,
                coordinateSystem: coordinateSystem,
                chartWidth: geometry.size.width,
                chartHeight: geometry.size.height,
                chartData: chartData
            )
        }
    }

    // MARK: - Marker Price Lines Overlay
    
    @ViewBuilder
    private func markerPriceLinesOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        MarkerPriceLinesOverlay(
            selectedMarker: activeSelectedMarker,
            previewMarker: previewMarkerForPriceLine,
            pendingInfo: pendingMarkerInfo,
            coordinateSystem: coordinateSystem,
            chartWidth: geometry.size.width,
            chartHeight: geometry.size.height,
            chartData: chartData
        )
    }
    
    // MARK: - Target Line Overlays
    
    @ViewBuilder
    private func targetLineOverlays(coordinateSystem: ChartCoordinateSystem, geometry: GeometryProxy) -> some View {
        if shouldShowInteractiveTargetLine {
            interactiveTargetLineOverlay(coordinateSystem: coordinateSystem, geometry: geometry)
        }
        
        if shouldShowStaticTargetLine {
            staticTargetLineOverlay(coordinateSystem: coordinateSystem, geometry: geometry)
        }
    }
    
    @ViewBuilder
    private func interactiveTargetLineOverlay(coordinateSystem: ChartCoordinateSystem, geometry: GeometryProxy) -> some View {
        let entryCandle = chartData.candles[previewCandleIndex]
        let entryPrice = entryCandle.close
        
        PredictionTargetLineOverlay(
            entryPrice: entryPrice,
            targetPrice: $predictionTargetPrice,
            isDragging: $isDraggingTarget,
            isInteractive: isAwaitingTargetSelection,
            coordinateSystem: coordinateSystem,
            chartWidth: geometry.size.width,
            chartHeight: geometry.size.height,
            chartData: chartData
        )
    }
    
    @ViewBuilder
    private func staticTargetLineOverlay(coordinateSystem: ChartCoordinateSystem, geometry: GeometryProxy) -> some View {
        if let pending = pendingMarkerInfo,
           let targetPrice = pending.targetPrice {
            let entryCandle = chartData.candles[pending.candleIndex]
            let entryPrice = entryCandle.close
            
            StaticTargetLineOverlay(
                entryPrice: entryPrice,
                targetPrice: targetPrice,
                coordinateSystem: coordinateSystem,
                chartWidth: geometry.size.width,
                chartHeight: geometry.size.height,
                chartData: chartData
            )
        }
    }
    
    // MARK: - Y-Axis Gesture Overlay
    
    @ViewBuilder
    private var yAxisGestureOverlay: some View {
        HStack {
            Spacer()
            Color.clear
                .frame(width: yAxisWidth)
                .contentShape(Rectangle())
                .gesture(yAxisDragGesture)
                .simultaneousGesture(yAxisPinchGesture)
        }
        // Disable Y-axis gestures during marker placement so buttons aren't blocked
        .allowsHitTesting(!isMarkerPlacementMode)
        .onDisappear {
            isDraggingOnYAxis = false
            isPinchingOnYAxis = false
        }
    }
    
    // MARK: - Loading Overlay
    
    @ViewBuilder
    private var loadingOverlayIfNeeded: some View {
        if shouldShowLoadingOverlay {
            loadingOverlay
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Loading Chart...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                loadingSubtitle
            }
        }
        .transition(.opacity.animation(.easeOut(duration: 0.3)))
    }
    
    @ViewBuilder
    private var loadingSubtitle: some View {
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
    
    // MARK: - Duplicate Marker Overlay
    
    @ViewBuilder
    private var duplicateMarkerOverlayIfNeeded: some View {
        if markerManager.showDuplicateAlert {
            duplicateMarkerOverlay
        }
    }
    
    
    @ViewBuilder
    private var duplicateMarkerOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                markerManager.showDuplicateAlert = false
                markerManager.duplicateMarkerToLike = nil
            }
        
        duplicateMarkerDialog
    }
    
    @ViewBuilder
    private var duplicateMarkerDialog: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("Marker Exists")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("A \(markerManager.duplicateMarkerToLike?.type.rawValue ?? "marker") already exists on this candle. Would you like to like it instead?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                duplicateMarkerButtons
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: markerManager.showDuplicateAlert)
        .zIndex(999)
    }
    
    @ViewBuilder
    private var duplicateMarkerButtons: some View {
        VStack(spacing: 12) {
            Button(action: handleLikeExistingMarker) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Like Existing")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Button(action: handleDismissDuplicateAlert) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Instruction Banner
    
    @ViewBuilder
    private func instructionBanner(coordinateSystem: ChartCoordinateSystem) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Header label
            Text("Marker Actions")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)

            // Buttons row — right-aligned
            HStack(spacing: 8) {
                cancelPlacementButton

                if isAwaitingTargetSelection {
                    confirmTargetButton(coordinateSystem: coordinateSystem)
                } else {
                    placeMarkerButton(coordinateSystem: coordinateSystem)
                }
            }

            // Prediction info box (right-aligned)
            if let state = predictionPlacement,
               controlViewModel.currentMarkerType == .predictionTarget {
                predictionInfoBox(state: state)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 20/255, green: 20/255, blue: 28/255).opacity(0.95),
                    Color(red: 20/255, green: 20/255, blue: 28/255).opacity(0.7)
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .padding(.trailing, 8)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(true)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Compact info box showing prediction trade stats (R:R, profit/loss %, direction)
    @ViewBuilder
    private func predictionInfoBox(state: PredictionPlacementState) -> some View {
        HStack(spacing: 12) {
            // Direction indicator
            Text(state.isLong ? "LONG" : "SHORT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(state.isLong ? .green : .red)

            // R:R ratio
            VStack(alignment: .leading, spacing: 1) {
                Text("R:R")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                Text(String(format: "%.2f", state.riskRewardRatio))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Profit %
            VStack(alignment: .leading, spacing: 1) {
                Text("Profit")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                Text(String(format: "+%.2f%%", state.potentialProfitPercent))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.green)
            }

            // Risk %
            VStack(alignment: .leading, spacing: 1) {
                Text("Risk")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                Text(String(format: "-%.2f%%", state.potentialLossPercent))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 25/255, green: 25/255, blue: 33/255).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: state.takeProfitPrice)
        .animation(.easeInOut(duration: 0.15), value: state.stopLossPrice)
    }

    @ViewBuilder
    private var cancelPlacementButton: some View {
        Button(action: handleCancelPlacement) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.red.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func confirmTargetButton(coordinateSystem: ChartCoordinateSystem) -> some View {
        Button(action: { handleConfirmTargetPress(coordinateSystem: coordinateSystem) }) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                Text("Confirm")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func placeMarkerButton(coordinateSystem: ChartCoordinateSystem) -> some View {
        Button(action: { handlePlaceMarkerPress(coordinateSystem: coordinateSystem) }) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Marker Placement Overlay
    
    @ViewBuilder
    private func markerPlacementOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        ZStack {
            if effectiveCandleIndex >= 0 && effectiveCandleIndex < chartData.candles.count {
                previewMarkerView(geometry: geometry, coordinateSystem: coordinateSystem)
            }
        }
        .onAppear {
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onChange(of: effectiveCandleIndex) { _, _ in
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onChange(of: controlViewModel.currentMarkerType) { _, _ in
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onChange(of: gestureState.panOffset.width) { _, _ in
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onChange(of: gestureState.candleWidthScale) { _, _ in
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onDisappear {
            if gestureState.markerPlacementGuide.source == .placement {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
        }
    }

    @ViewBuilder
    private func markerGuideOverlay(geometry: GeometryProxy) -> some View {
        if !crosshairManager.isActive,
           gestureState.markerPlacementGuide.isActive,
           let _ = gestureState.markerPlacementGuide.timestamp {
            Path { path in
                path.move(to: CGPoint(x: gestureState.markerPlacementGuide.x, y: 0))
                path.addLine(to: CGPoint(x: gestureState.markerPlacementGuide.x, y: geometry.size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            .foregroundColor(.blue.opacity(0.6))
            .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private func previewMarkerView(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        let candle = chartData.candles[effectiveCandleIndex]
        let snapX = coordinateSystem.xCenterPosition(forCandleIndex: effectiveCandleIndex)
        let candleHighY = coordinateSystem.yPosition(forPrice: candle.high)
        let candleLowY = coordinateSystem.yPosition(forPrice: candle.low)
        
        let (snapPosition, _) = MarkerPositionCalculator.calculatePreviewPosition(
            candleIndex: effectiveCandleIndex,
            existingMarkers: markerManager.filteredMarkers,
            candles: chartData.candles,
            candleHighY: candleHighY,
            candleLowY: candleLowY,
            centerX: snapX,
            priceScale: gestureState.priceScale
        )
        
        let markerX = markerDragPosition?.x ?? snapPosition.x
        let markerY = markerDragPosition?.y ?? snapPosition.y
        
        if markerX >= -50 && markerX <= geometry.size.width + 50 {
            previewMarkerContent(x: markerX, y: markerY, coordinateSystem: coordinateSystem)
        }
    }
    
    private var effectivePreviewColor: Color {
        if effectiveMarkerType == .alert, let severity = placementAlertSeverity { return severity.color }
        return effectiveMarkerType?.color ?? .blue
    }

    @ViewBuilder
    private func previewMarkerContent(x: CGFloat, y: CGFloat, coordinateSystem: ChartCoordinateSystem) -> some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 80, height: 80)
                .contentShape(Circle())
            
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(effectivePreviewColor, lineWidth: 3)
                )
            
            Circle()
                .fill(effectivePreviewColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Group {
                        if effectiveMarkerType == .emoji {
                            Text(placementSelectedEmoji ?? "🎯")
                                .font(.system(size: 14))
                        } else {
                            Image(systemName: effectiveMarkerType?.icon ?? "mappin")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
            
            previewMarkerInfoBox
        }
        .position(x: x, y: y)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarkerBeingDragged)
        .gesture(previewMarkerDragGesture(coordinateSystem: coordinateSystem))
    }
    
    @ViewBuilder
    private var previewMarkerInfoBox: some View {
        Text((effectiveMarkerType ?? .note).rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(effectivePreviewColor)
            .lineLimit(1)
        .padding(4)
        .background(Color.black.opacity(0.82))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(effectivePreviewColor.opacity(0.7), lineWidth: 1)
        )
        .cornerRadius(4)
        .offset(y: 40)
        .allowsHitTesting(false)
    }

    private func updatePlacementGuideState(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) {
        guard effectiveCandleIndex >= 0,
              effectiveCandleIndex < chartData.candles.count,
              let markerType = effectiveMarkerType else {
            gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            return
        }

        let candle = chartData.candles[effectiveCandleIndex]
        let x = coordinateSystem.xCenterPosition(forCandleIndex: effectiveCandleIndex)
        let isVisible = x >= -50 && x <= geometry.size.width + 50

        gestureState.markerPlacementGuide = MarkerPlacementGuideState(
            isActive: isVisible,
            x: x,
            timestamp: candle.timestamp,
            markerType: markerType,
            source: .placement
        )
    }

    private func syncSelectedMarkerGuideState(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) {
        guard !isMarkerPlacementMode else { return }

        guard let selectedMarker = markerManager.selectedMarker,
              chartData.candles.indices.contains(selectedMarker.candleIndex) else {
            if gestureState.markerPlacementGuide.source == .selected {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
            return
        }

        let candle = chartData.candles[selectedMarker.candleIndex]
        let x = coordinateSystem.xCenterPosition(forCandleIndex: selectedMarker.candleIndex)
        let isVisible = x >= -50 && x <= geometry.size.width + 50
        gestureState.markerPlacementGuide = MarkerPlacementGuideState(
            isActive: isVisible,
            x: x,
            timestamp: candle.timestamp,
            markerType: selectedMarker.type,
            source: .selected
        )
    }
    
    private func previewMarkerDragGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
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
    }
    
    // MARK: - Button Action Handlers
    
    private func handleConfirmTargetPress(coordinateSystem: ChartCoordinateSystem) {
        guard pendingMarkerInfo == nil else { return }
        
        let candleIdx = effectiveCandleIndex
        guard let timestamp = coordinateSystem.timestamp(forCandleIndex: candleIdx),
              candleIdx >= 0,
              candleIdx < chartData.candles.count,
              let markerType = controlViewModel.currentMarkerType,
              let targetPrice = predictionTargetPrice else {
            return
        }
        
        let candle = chartData.candles[candleIdx]
        markerManager.selectedMarker = nil
        
        // FIXED: Setting pendingMarkerInfo automatically presents the sheet via sheet(item:)
        pendingMarkerInfo = PendingMarkerInfo(
            candleIndex: candleIdx,
            timestamp: timestamp,
            price: candle.close,
            markerType: markerType,
            targetPrice: targetPrice
        )
        
        isAwaitingTargetSelection = false
        impactFeedback.impactOccurred()
    }
    
    private func handlePlaceMarkerPress(coordinateSystem: ChartCoordinateSystem) {
        guard pendingMarkerInfo == nil else { return }
        
        let candleIdx = effectiveCandleIndex
        guard let timestamp = coordinateSystem.timestamp(forCandleIndex: candleIdx),
              candleIdx >= 0,
              candleIdx < chartData.candles.count,
              let markerType = controlViewModel.currentMarkerType else {
            return
        }
        
        if let existingMarker = markerManager.existingMarkerOfType(markerType, atCandleIndex: candleIdx) {
            controlViewModel.cancelMarkerPlacement()
            markerManager.duplicateMarkerToLike = existingMarker
            markerManager.showDuplicateAlert = true
            return
        }
        
        let candle = chartData.candles[candleIdx]
        
        if markerType == .predictionTarget, let state = predictionPlacement {
            // New unified prediction flow: use the 3-line state directly
            markerManager.selectedMarker = nil
            pendingMarkerInfo = PendingMarkerInfo(
                candleIndex: state.candleIndex,
                timestamp: timestamp,
                price: state.entryPrice,
                markerType: .predictionTarget,
                targetPrice: state.takeProfitPrice,
                horizontalLinePrice: state.entryPrice,
                stopLossPrice: state.stopLossPrice
            )
            impactFeedback.impactOccurred()
            return
        } else if markerType == .predictionTarget {
            // Fallback if predictionPlacement wasn't initialized
            impactFeedback.impactOccurred()
            return
        } else {
            markerManager.selectedMarker = nil

            pendingMarkerInfo = PendingMarkerInfo(
                candleIndex: candleIdx,
                timestamp: timestamp,
                price: candle.close,
                markerType: markerType,
                horizontalLinePrice: placementLinePrice
            )

            impactFeedback.impactOccurred()
        }
    }
    
    private func handleCancelPlacement() {
        withAnimation {
            controlViewModel.isMarkerPlacementMode = false
            isMarkerBeingDragged = false
            markerDragPosition = nil
            isAwaitingTargetSelection = false
            predictionTargetPrice = nil
            isDraggingTarget = false
            placementLinePrice = nil
            isDraggingPlacementLine = false
            predictionPlacement = nil
            draggingPredictionLine = nil
            if gestureState.markerPlacementGuide.source == .placement {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
        }
    }
    
    private func handleLikeExistingMarker() {
        if let marker = markerManager.duplicateMarkerToLike {
            Task {
                await markerManager.toggleLike(markerId: marker.id)
            }
        }
        markerManager.duplicateMarkerToLike = nil
        markerManager.showDuplicateAlert = false
    }
    
    private func handleDismissDuplicateAlert() {
        markerManager.duplicateMarkerToLike = nil
        markerManager.showDuplicateAlert = false
    }
    
    private func handleMarkerSheetDismiss() {
        // FIXED: Don't set selectedMarker here - it can cause the detail sheet to briefly appear
        // when there's timing issues between sheets
        controlViewModel.cancelMarkerPlacement()

        // Small delay to let SwiftUI finish the sheet dismissal animation
        // before cleaning up state that might affect other sheets
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Only clear if we're not showing another sheet
            if self.pendingMarkerInfo == nil {
                self.isAwaitingTargetSelection = false
                self.predictionTargetPrice = nil
                self.isDraggingTarget = false
                self.placementAlertSeverity = nil
                self.placementSelectedEmoji = nil
                self.placementLinePrice = nil
                self.isDraggingPlacementLine = false
                self.predictionPlacement = nil
                self.draggingPredictionLine = nil
                if self.gestureState.markerPlacementGuide.source == .placement {
                    self.gestureState.markerPlacementGuide = MarkerPlacementGuideState()
                }
            }
        }
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleOnAppear() {
        syncMarkerContext()
        setupControlActions()
        chartViewModel.markerManager = markerManager
        markerManager.configureRealTime(dataManager: chartData)
        isChartLoading = chartViewModel.currentSymbol == nil || chartData.candles.isEmpty
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !hasInitializedPosition && !chartData.candles.isEmpty && chartViewModel.currentSymbol != nil {
                resetChartToMostRecentCandles()
                hasInitializedPosition = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if markerManager.markers.isEmpty && !chartData.candles.isEmpty {
                Task {
                    await loadMarkersFromAPI()
                }
            }
        }
    }
    
    private func handleMarkerPlacementModeChange(oldValue: Bool, newValue: Bool) {
        if !oldValue && newValue {
            // Entering placement mode - keep previewCandleIndex as -1
            // effectiveCandleIndex will calculate center dynamically until user drags
            // This ensures we always use the current visible center, not a stale value
            previewCandleIndex = -1

            // For prediction markers: immediately initialize 3-line system
            if controlViewModel.currentMarkerType == .predictionTarget {
                initializePredictionPlacement()
            }
        } else if oldValue && !newValue {
            // Exiting placement mode - reset to invalid index
            previewCandleIndex = -1
            if gestureState.markerPlacementGuide.source == .placement {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
        }
    }

    private func syncMarkerContext() {
        markerManager.updateContext(
            userId: currentUserId,
            guildId: currentGuildId,
            currentUserMember: currentUserMember
        )
    }

    /// Initialize the prediction placement 3-line system (Entry + TP + SL)
    /// Auto-scrolls to the latest candle and sets default TP/SL offsets
    private func initializePredictionPlacement() {
        guard !chartData.candles.isEmpty else { return }
        let lastIndex = chartData.candles.count - 1
        let lastCandle = chartData.candles[lastIndex]
        let entryPrice = lastCandle.close
        let priceRange = chartData.priceRange.max - chartData.priceRange.min

        predictionPlacement = PredictionPlacementState(
            entryPrice: entryPrice,
            takeProfitPrice: entryPrice + priceRange * 0.05,
            stopLossPrice: entryPrice - priceRange * 0.03,
            candleIndex: lastIndex
        )

        // Auto-scroll to latest candle with smooth animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gestureState.centerOnMarker(
                at: lastIndex,
                chartWidth: chartSize.width > 0 ? chartSize.width : UIScreen.main.bounds.width,
                candleWidth: totalCandleWidth,
                price: entryPrice,
                chartHeight: chartSize.height > 0 ? chartSize.height : UIScreen.main.bounds.height * 0.6,
                priceRange: chartData.priceRange
            )
        }
    }
    
    private func handleSymbolChange(oldValue: RLTradingSymbolDTO?, newValue: RLTradingSymbolDTO?) {
        if oldValue == nil && newValue != nil && !chartData.candles.isEmpty {
            if !hasInitializedPosition {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resetChartToMostRecentCandles()
                    hasInitializedPosition = true
                }
            }
        }
        chartViewModel.indicatorManager.recalculateIndicators(candles: chartData.candles)
    }
    
    private func handleSymbolStringChange(oldValue: String?, newValue: String?) {
        if oldValue != newValue && oldValue != nil {
            isChartLoading = true
            markerManager.clearMarkers()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                resetChartToMostRecentCandles()
                Task {
                    await loadMarkersFromAPI()
                }
            }
        }
    }
    
    private func handleTimeframeChange(oldValue: RLChartTimeframe, newValue: RLChartTimeframe) {
        if oldValue != newValue {
            isChartLoading = true
            markerManager.clearMarkers()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                resetChartToMostRecentCandles()
                Task {
                    await loadMarkersFromAPI()
                }
            }
        }
        chartViewModel.indicatorManager.recalculateIndicators(candles: chartData.candles)
    }
    
    private func handleCandleCountChange(oldCount: Int, newCount: Int) {
        if abs(newCount - oldCount) > 10 {
            resetChartToMostRecentCandles()
        }
        if newCount != oldCount {
            chartViewModel.indicatorManager.recalculateIndicators(candles: chartData.candles)
        }

        // Keep prediction placement pinned to latest candle
        if var state = predictionPlacement,
           controlViewModel.currentMarkerType == .predictionTarget,
           newCount > 0 {
            let lastIndex = max(0, chartData.candles.count - 1)
            let lastCandle = chartData.candles[lastIndex]
            state.candleIndex = lastIndex
            state.entryPrice = lastCandle.close
            predictionPlacement = state
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateCenterCandleIndex() -> Int {
        let totalOffset = gestureState.panOffset.width
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth))
        
        // FIXED: Use screen width as fallback when chartSize not yet set
        let effectiveWidth = chartSize.width > 0 ? chartSize.width : UIScreen.main.bounds.width
        let candlesOnScreen = Int(effectiveWidth / totalCandleWidth)
        
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            visibleStartIndex + candlesOnScreen + 2
        )
        let middleIndex = (visibleStartIndex + visibleEndIndex) / 2
        return max(0, min(chartData.candles.count - 1, middleIndex))
    }
    
    // MARK: - Crosshair Gestures
    
    private func crosshairGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if let location = drag?.location {
                        if !crosshairManager.isActive {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            crosshairManager.activate(
                                at: location,
                                coordinateSystem: coordinateSystem,
                                chartData: chartData
                            )
                        } else {
                            crosshairManager.updatePosition(
                                location,
                                coordinateSystem: coordinateSystem,
                                chartData: chartData
                            )
                        }
                        
                        // Sync crosshair state to gestureState for RSI panel
                        gestureState.crosshairActive = true
                        gestureState.crosshairX = location.x
                        gestureState.crosshairTimestamp = crosshairManager.targetCandle?.timestamp
                    }
                default:
                    break
                }
            }
    }
    
    private func crosshairDismissTapGesture() -> some Gesture {
        TapGesture()
            .onEnded {
                if crosshairManager.isActive {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    crosshairManager.deactivate()
                    
                    // Clear crosshair state in gestureState
                    gestureState.crosshairActive = false
                    gestureState.crosshairTimestamp = nil
                }
            }
    }
    
    // MARK: - Tap Gesture for Markers
    
    /// Find the candle index closest to the given timestamp (for centering chart on selected marker).
    private static func findCandleIndexForTimestamp(_ timestamp: Date, in candles: [RLCandleDTO]) -> Int? {
        guard !candles.isEmpty else { return nil }
        var left = 0
        var right = candles.count - 1
        var closestIndex: Int?
        var minDiff = TimeInterval.infinity
        while left <= right {
            let mid = (left + right) / 2
            let candle = candles[mid]
            let diff = abs(candle.timestamp.timeIntervalSince(timestamp))
            if diff < minDiff {
                minDiff = diff
                closestIndex = mid
            }
            if candle.timestamp < timestamp {
                left = mid + 1
            } else if candle.timestamp > timestamp {
                right = mid - 1
            } else {
                return mid
            }
        }
        if minDiff < 86400 { return closestIndex }
        return nil
    }

    private func focusSharedMarker(_ payload: MarkerSharePayloadV1) {
        attemptSharedMarkerFocus(payload, attemptsRemaining: 6)
    }

    private func attemptSharedMarkerFocus(_ payload: MarkerSharePayloadV1, attemptsRemaining: Int) {
        let matchingMarker = markerManager.markers.first { $0.id == payload.markerId }
        let candleIndex = matchingMarker?.candleIndex
            ?? Self.findCandleIndexForTimestamp(payload.candleTimestamp, in: chartData.candles)

        if matchingMarker == nil && candleIndex == nil && attemptsRemaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                attemptSharedMarkerFocus(payload, attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        guard let resolvedIndex = candleIndex else { return }
        guard chartData.candles.indices.contains(resolvedIndex) else { return }

        if let matchingMarker {
            markerManager.selectedMarker = matchingMarker
            tappedMarkerId = matchingMarker.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                tappedMarkerId = nil
            }
        }

        let chartWidth = UIScreen.main.bounds.width
        let chartHeight = UIScreen.main.bounds.height * 0.55
        let candleWidth = totalCandleWidth
        let focusPrice = matchingMarker?.price ?? chartData.candles[resolvedIndex].close

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gestureState.centerOnMarker(
                at: resolvedIndex,
                chartWidth: chartWidth,
                candleWidth: candleWidth,
                price: focusPrice,
                chartHeight: chartHeight,
                priceRange: chartData.priceRange
            )
        }
    }
    
    private func tapGestureForMarkers(geometry: GeometryProxy) -> some Gesture {
        // FIXED: Use a longer minimum distance and check start/end proximity
        // to prevent accidental marker selection while panning
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                // FIXED: Check pendingMarkerInfo instead of showMarkerSheet/isShowingSheet
                guard !crosshairManager.isActive &&
                        !isMarkerPlacementMode &&
                        pendingMarkerInfo == nil else { return }
                
                // FIXED: Require the gesture to be a deliberate tap, not a pan
                // Check that finger didn't move much (max 15 points in any direction)
                let dragDistance = sqrt(
                    pow(value.translation.width, 2) +
                    pow(value.translation.height, 2)
                )
                guard dragDistance < 15 else { return }
                
                let location = value.location
                let totalOffset = gestureState.panOffset.width
                let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
                
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        tappedMarkerId = nil
                    }
                    markerManager.selectedMarker = marker
                    let chartWidth = geometry.size.width
                    let chartHeight = geometry.size.height
                    let candles = chartData.candles
                    let timestamp = marker.candleTimestamp
                    let markerPrice = marker.price
                    let priceRange = chartData.priceRange
                    let width = totalCandleWidth
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let index = Self.findCandleIndexForTimestamp(timestamp, in: candles) ?? max(0, candles.count - 50)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            gestureState.centerOnMarker(
                                at: index,
                                chartWidth: chartWidth,
                                candleWidth: width,
                                price: markerPrice,
                                chartHeight: chartHeight,
                                priceRange: priceRange
                            )
                        }
                    }
                }
            }
    }
    
    // MARK: - Pan Gesture
    
    private func dragGesture(in size: CGSize, coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if crosshairManager.isActive {
                    handleCrosshairDrag(value: value, size: size, coordinateSystem: coordinateSystem)
                    return
                }
                
                if !isDraggingOnYAxis && !isPinchingOnYAxis && !isMarkerBeingDragged && !isDraggingTarget && !isDraggingPlacementLine && draggingPredictionLine == nil {
                    // Start tracking on first drag event
                    if lastDragTranslation == .zero {
                        gestureState.beginDrag()
                    }
                    
                    let incrementalX = value.translation.width - lastDragTranslation.width
                    let incrementalY = -(value.translation.height - lastDragTranslation.height)
                    
                    gestureState.applyPan(
                        translation: CGSize(width: incrementalX, height: incrementalY),
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale,
                        trackVelocity: true  // Enable velocity tracking for momentum
                    )
                    
                    lastDragTranslation = value.translation
                }
            }
            .onEnded { value in
                if crosshairManager.isActive {
                    crosshairDragStartPosition = nil
                } else if !isDraggingOnYAxis && !isPinchingOnYAxis && !isMarkerBeingDragged && !isDraggingTarget && !isDraggingPlacementLine && draggingPredictionLine == nil {
                    // Trigger momentum scrolling
                    gestureState.endDrag(
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale
                    )
                }
                
                lastDragTranslation = .zero
                dragState = .zero
            }
    }
    
    private func handleCrosshairDrag(value: DragGesture.Value, size: CGSize, coordinateSystem: ChartCoordinateSystem) {
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
            
            // Sync crosshair state to gestureState for RSI panel
            gestureState.crosshairX = clampedPosition.x
            gestureState.crosshairTimestamp = crosshairManager.targetCandle?.timestamp
        }
    }
    
    // MARK: - Pinch Gesture
    
    private func pinchGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !crosshairManager.isActive && !isMarkerBeingDragged && !isPinchingOnYAxis else { return }
                
                if !isPinchingOnChart {
                    isPinchingOnChart = true
                    initialCandleWidthScale = gestureState.candleWidthScale
                    initialHorizontalOffset = gestureState.panOffset.width
                    pinchCenterX = size.width / 2
                }
                
                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                let newScale = initialCandleWidthScale * dampenedValue
                let clampedScale = Swift.min(maxHorizontalScale, Swift.max(minHorizontalScale, newScale))
                
                let oldTotalWidth = baseCandleWidth * initialCandleWidthScale + candleSpacing
                let newTotalWidth = baseCandleWidth * clampedScale + candleSpacing
                let totalWidthRatio = newTotalWidth / oldTotalWidth
                
                let newHorizontalOffset = initialHorizontalOffset * totalWidthRatio + pinchCenterX * (1.0 - totalWidthRatio)
                
                gestureState.candleWidthScale = clampedScale
                gestureState.panOffset.width = newHorizontalOffset
            }
            .onEnded { _ in
                isPinchingOnChart = false
            }
    }
    
    // MARK: - Y-Axis Gestures
    
    private var yAxisDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDraggingOnYAxis {
                    if isPinchingOnYAxis {
                        isPinchingOnYAxis = false
                    }
                    
                    isDraggingOnYAxis = true
                    yAxisDragStart = value.startLocation.y
                    initialPriceScale = gestureState.priceScale
                    initialVerticalOffset = gestureState.verticalPanOffset
                }
                
                let dragDistance = value.location.y - yAxisDragStart
                let scaleMultiplier = 1.0 - (dragDistance / 300.0) * yAxisSensitivity
                let newScale = initialPriceScale * scaleMultiplier
                let clampedScale = Swift.min(maxVerticalScale, Swift.max(minVerticalScale, newScale))
                
                let chartHeight = UIScreen.main.bounds.height
                let screenCenterY = chartHeight / 2
                
                let scaleRatio = clampedScale / initialPriceScale
                let newVerticalOffset = initialVerticalOffset * scaleRatio + screenCenterY * (1.0 - scaleRatio)
                
                gestureState.priceScale = clampedScale
                gestureState.verticalPanOffset = newVerticalOffset
            }
            .onEnded { _ in
                isDraggingOnYAxis = false
            }
    }
    
    private var yAxisPinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isPinchingOnYAxis {
                    if isDraggingOnYAxis {
                        isDraggingOnYAxis = false
                    }
                    
                    isPinchingOnYAxis = true
                    initialPriceScale = gestureState.priceScale
                    initialVerticalOffset = gestureState.verticalPanOffset
                }
                
                let dampenedValue = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
                let newScale = initialPriceScale * dampenedValue
                let clampedScale = Swift.min(maxVerticalScale, Swift.max(minVerticalScale, newScale))
                
                let chartHeight = UIScreen.main.bounds.height
                let screenCenterY = chartHeight / 2
                
                let scaleRatio = clampedScale / initialPriceScale
                let newVerticalOffset = initialVerticalOffset * scaleRatio + screenCenterY * (1.0 - scaleRatio)
                
                gestureState.priceScale = clampedScale
                gestureState.verticalPanOffset = newVerticalOffset
            }
            .onEnded { _ in
                isPinchingOnYAxis = false
            }
    }
    
    // MARK: - Axis Overlays
    
    @ViewBuilder
    func xAxisOverlay(geometry: GeometryProxy) -> some View {
        let bottomAreaHeight = geometry.size.height * 0.11
        let hasIndicatorPanels = chartViewModel.indicatorManager.shouldShowAnyPanel

        ZStack {
            VStack(spacing: 0) {
                Spacer()

                if !hasIndicatorPanels {
                    xAxisLabelsCanvas(geometry: geometry)
                }

                Rectangle()
                    .fill(Color.black)
                    .frame(height: bottomAreaHeight)
                    .edgesIgnoringSafeArea(.bottom)
            }

            if !hasIndicatorPanels,
               !crosshairManager.isActive,
               gestureState.markerPlacementGuide.isActive,
               let timestamp = gestureState.markerPlacementGuide.timestamp {
                MarkerXAxisTimeIndicator(
                    timestamp: timestamp,
                    xPosition: gestureState.markerPlacementGuide.x,
                    chartHeight: geometry.size.height,
                    timeframe: chartViewModel.currentTimeframe
                )
            }
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func xAxisLabelsCanvas(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            drawXAxisLabels(context: context, size: size)
        }
        .frame(height: 22)
        .padding(.top, 10)
        .background(Color.black)
    }
    
    private func drawXAxisLabels(context: GraphicsContext, size: CGSize) {
        ChartXAxisLabelEngine.drawLabels(
            context: context,
            size: size,
            input: .init(
                candles: chartData.candles,
                timeframe: chartViewModel.currentTimeframe,
                totalOffset: gestureState.panOffset.width,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                width: size.width,
                timeZone: .current,
                locale: Locale(identifier: "en_US_POSIX"),
                minSpacing: 46
            ),
            style: .mainChart
        )
    }
    
    // MARK: - Y-Axis Overlay
    
    @ViewBuilder
    func yAxisOverlay(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            Canvas { context, size in
                drawYAxisLabels(context: context, size: size, geometry: geometry)
            }
            .frame(width: yAxisWidth)
            .background(Color.black.opacity(0.8))
        }
        .allowsHitTesting(false)
    }
    
    private func drawYAxisLabels(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        let priceRange = chartData.priceRange
        let scaledHeight = geometry.size.height * gestureState.priceScale
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: geometry.size.height)
        
        let priceHelper = PriceAxisHelper(
            symbol: currentSymbol,
            priceRange: priceRange,
            priceScale: gestureState.priceScale,
            chartHeight: geometry.size.height
        )
        
        let step = priceHelper.nicePriceStep
        
        let extendedStartPrice = floor((priceRange.min - step * 30) / step) * step
        let extendedEndPrice = ceil((priceRange.max + step * 30) / step) * step
        
        var currentPrice = extendedStartPrice
        var labelCount = 0
        let maxLabels = 100
        
        while currentPrice <= extendedEndPrice && labelCount < maxLabels {
            let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
            let y = size.height - (CGFloat(normalizedPrice) * scaledHeight) - totalVerticalOffset
            
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
    
    // MARK: - Chart Info Box
    
    @ViewBuilder
    func chartInfoBox(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                chartInfoContent
                Spacer()
            }
            .padding(.leading, 8)
            .padding(.top, 8)
            
            Spacer()
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var chartInfoContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            symbolTimeframeRow
            priceRow
            // Use chartViewModel.indicatorManager (not just indicatorManager)
            ActiveIndicatorsLegendView(indicatorManager: chartViewModel.indicatorManager)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var symbolTimeframeRow: some View {
        HStack(spacing: 8) {
            if let symbol = currentSymbol {
                Text(symbol.ticker)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Image(systemName: symbol.effectiveIsMarketOpen ? "circle.fill" : "moon.fill")
                    .font(.system(size: symbol.effectiveIsMarketOpen ? 7 : 8, weight: .semibold))
                    .foregroundColor(symbol.effectiveIsMarketOpen ? .green : .gray.opacity(0.75))

                Text(symbol.providerDisplayLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.24))
                    .clipShape(Capsule())
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(currentTimeframe.shortName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(4)
        }
    }
    
    @ViewBuilder
    private var priceRow: some View {
        HStack(spacing: 6) {
            Text(chartData.formatPrice(chartData.currentPrice))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(priceChangeColor)
            
            priceChangeIndicator
        }
    }
    
    @ViewBuilder
    private var priceChangeIndicator: some View {
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
    
    // MARK: - Chart Controls Box
    
    @ViewBuilder
    func chartControlsBox(geometry: GeometryProxy) -> some View {
        let bottomAreaHeight = geometry.size.height * 0.11 + 40
        let yAxisTrailingInset: CGFloat = 6
        let panelPadding: CGFloat = indicatorPanelBottomPadding > 0 ? indicatorPanelBottomPadding - 30 : 0

        VStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 10) {
                    ChartBottomControlButton(
                        title: isMarkerVisibilityPanelExpanded ? "Close" : "Marker Visibility",
                        icon: isMarkerVisibilityPanelExpanded ? "xmark.circle" : "eye",
                        color: .white.opacity(0.8),
                        isActive: isMarkerVisibilityPanelExpanded
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMarkerVisibilityPanelExpanded.toggle()
                        }
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

                if isMarkerVisibilityPanelExpanded {
                    VStack(alignment: .trailing, spacing: 8) {
                        Picker("Visibility", selection: $markerManager.visibilityMode) {
                            ForEach(MarkerVisibilityMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)

                        Button {
                            showMarkerTypeFilterSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(markerTypeFilterSummary)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(AppColors.whiteText.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, bottomAreaHeight + panelPadding)
            .padding(.trailing, yAxisTrailingInset)
            .animation(.easeInOut(duration: 0.2), value: isMarkerVisibilityPanelExpanded)
        }
        .allowsHitTesting(true)
    }

    private var markerTypeFilterSummary: String {
        let selectedCount = markerManager.visibleTypes.count
        let total = RLMarkerType.allCases.count
        if selectedCount == total {
            return "Types: All"
        }
        return "Types: \(selectedCount)"
    }

    @ViewBuilder
    private var markerTypeFilterSheet: some View {
        NavigationStack {
            List {
                ForEach(RLMarkerType.allCases, id: \.self) { type in
                    Toggle(isOn: Binding(
                        get: { markerManager.visibleTypes.contains(type) },
                        set: { isOn in
                            if isOn {
                                markerManager.visibleTypes.insert(type)
                            } else {
                                markerManager.visibleTypes.remove(type)
                            }
                        }
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 16)
                            Text(type.rawValue)
                        }
                    }
                    .tint(AppColors.accentColor)
                }
            }
            .navigationTitle("Marker Types")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("All") {
                        markerManager.visibleTypes = Set(RLMarkerType.allCases)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showMarkerTypeFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.55), .large])
    }
    
    // MARK: - Chart Drawing
    
    private func drawChart(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        var drawingContext = context

        drawingContext.clip(to: Path(CGRect(origin: .zero, size: size)))

        let totalOffset = gestureState.panOffset.width
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)

        // Dim candles/grid when actively dragging a placement line or prediction line
        let chartDimmed = isDraggingPlacementLine || draggingPredictionLine != nil
        if chartDimmed {
            drawingContext.opacity = 0.3
        }

        drawGrid(context: drawingContext, size: size)
        drawCandlesticks(context: drawingContext, size: size)

        IndicatorOverlayRenderer.drawOverlayIndicators(
            context: drawingContext,
            size: size,
            drawingData: indicatorDrawingData,
            priceRange: chartData.priceRange,
            priceScale: gestureState.priceScale,
            verticalOffset: clampedVerticalOffset(chartHeight: size.height),
            totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth,
            totalOffset: gestureState.panOffset.width
        )

        // Reset opacity for markers — they have their own dimming via the dimmed parameter
        if chartDimmed {
            drawingContext.opacity = 1.0
        }

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
            selectedMarkerId: markerManager.selectedMarker?.id ?? tappedMarkerId,
            dimmed: controlViewModel.isMarkerPlacementMode
        )
    }
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let priceRange = chartData.priceRange
        let scaledHeight = size.height * gestureState.priceScale
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
        let totalOffset = gestureState.panOffset.width
        let timeframe = chartViewModel.currentTimeframe
        
        let gridPath = Path { path in
            drawVerticalGridLines(path: &path, size: size, totalOffset: totalOffset, timeframe: timeframe)
            drawHorizontalGridLines(path: &path, size: size, priceRange: priceRange, scaledHeight: scaledHeight, totalVerticalOffset: totalVerticalOffset)
        }
        
        context.stroke(gridPath, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
    }
    
    private func drawVerticalGridLines(path: inout Path, size: CGSize, totalOffset: CGFloat, timeframe: RLChartTimeframe) {
        let labels = ChartXAxisLabelEngine.makeLabels(
            input: .init(
                candles: chartData.candles,
                timeframe: timeframe,
                totalOffset: totalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                width: size.width,
                timeZone: .current,
                locale: Locale(identifier: "en_US_POSIX"),
                minSpacing: 46
            )
        )

        for label in labels {
            if label.x >= -100 && label.x <= size.width + 100 {
                path.move(to: CGPoint(x: label.x, y: 0))
                path.addLine(to: CGPoint(x: label.x, y: size.height))
            }
        }
    }
    
    private func drawHorizontalGridLines(path: inout Path, size: CGSize, priceRange: (min: Double, max: Double), scaledHeight: CGFloat, totalVerticalOffset: CGFloat) {
        let priceHelper = PriceAxisHelper(
            symbol: currentSymbol,
            priceRange: priceRange,
            priceScale: gestureState.priceScale,
            chartHeight: size.height
        )
        
        let step = priceHelper.nicePriceStep
        
        let extendedStartPrice = floor((priceRange.min - step * 30) / step) * step
        let extendedEndPrice = ceil((priceRange.max + step * 30) / step) * step
        
        var currentPrice = extendedStartPrice
        var lineCount = 0
        let maxLines = 100
        
        while currentPrice <= extendedEndPrice && lineCount < maxLines {
            let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
            let y = size.height - (CGFloat(normalizedPrice) * scaledHeight) - totalVerticalOffset
            
            if y >= -500 && y <= size.height + 500 {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                lineCount += 1
            }
            
            currentPrice += step
        }
    }
    
    private func drawCandlesticks(context: GraphicsContext, size: CGSize) {
        let priceRange = chartData.priceRange
        let scaledHeight = size.height * gestureState.priceScale
        let totalOffset = gestureState.panOffset.width
        
        let visibleStartIndex = Swift.max(0, Int(-totalOffset / totalCandleWidth) - 1)
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            Swift.max(visibleStartIndex, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
        )

        guard visibleStartIndex < visibleEndIndex else { return }

        for i in visibleStartIndex..<visibleEndIndex {
            guard i < chartData.candles.count else { continue }
            drawSingleCandle(context: context, size: size, index: i, priceRange: priceRange, scaledHeight: scaledHeight, totalOffset: totalOffset)
        }
    }
    
    private func drawSingleCandle(context: GraphicsContext, size: CGSize, index: Int, priceRange: (min: Double, max: Double), scaledHeight: CGFloat, totalOffset: CGFloat) {
        let candle = chartData.candles[index]
        let x = CGFloat(index) * totalCandleWidth + totalOffset
        
        if x < -totalCandleWidth || x > size.width + totalCandleWidth {
            return
        }
        
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
        
        let candleColor = candle.close >= candle.open ? Color.green : Color.red
        
        // Draw wick
        let wickPath = Path { path in
            path.move(to: CGPoint(x: x + actualCandleWidth / 2, y: highY))
            path.addLine(to: CGPoint(x: x + actualCandleWidth / 2, y: lowY))
        }
        context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)
        
        // Draw body
        let bodyRect = CGRect(
            x: x,
            y: Swift.min(openY, closeY),
            width: actualCandleWidth,
            height: Swift.max(1, abs(closeY - openY))
        )
        
        if candle.close >= candle.open {
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
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: 0),
                with: .color(candleColor)
            )
        }
    }
    
    // MARK: - Chart Position Management
    
    private func resetChartToMostRecentCandles() {
        guard !chartData.candles.isEmpty else { return }
        
        let screenWidth = chartSize.width > 0 ? chartSize.width : UIScreen.main.bounds.width
        let totalChartWidth = CGFloat(chartData.candles.count) * totalCandleWidth
        
        let rightPadding = screenWidth * 0.3
        let targetOffset = -(totalChartWidth - screenWidth + rightPadding)
        
        let minOffset = -(totalChartWidth - screenWidth + edgePadding)
        let maxOffset = edgePadding
        let clampedOffset = max(minOffset, min(maxOffset, targetOffset))
        
        withAnimation(.easeOut(duration: 0.3)) {
            gestureState.panOffset.width = clampedOffset
            gestureState.panOffset.height = 0
            gestureState.verticalPanOffset = 0
            gestureState.priceScale = 1.0
        }
        
        isChartLoading = false
    }
    
    // MARK: - Marker API Loading
    
    private func loadMarkersFromAPI() async {
        guard !chartData.candles.isEmpty else { return }
        
        // Use ChartViewModel's loadMarkers which uses RealAPIService
        await chartViewModel.loadMarkers()
    }
    
    // MARK: - Control Actions Setup

    private func setupControlActions() {
        controlViewModel.resetChartAction = {
            self.gestureState.reset()
        }
        
        controlViewModel.jumpToStartAction = {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.gestureState.panOffset.width = 0
            }
        }
        
        controlViewModel.jumpToLatestAction = {
            guard !self.chartData.candles.isEmpty else { return }
            let targetOffset = -CGFloat(self.chartData.candles.count - 1) * self.totalCandleWidth + 100
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.gestureState.panOffset.width = targetOffset
            }
        }
        
        controlViewModel.toggleAutoScrollAction = {
            print("Auto-scroll toggled")
        }
        
        controlViewModel.setHorizontalZoomAction = { zoom in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.gestureState.candleWidthScale = CGFloat(zoom)
            }
        }
        
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? AppColors.gradientBackgroundDark : color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isActive ? AppColors.gradientBackgroundDark : color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isActive ?
                Color.white.opacity(0.85) :
                Color.white.opacity(0.08)
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placement Line Drag Overlay (Interactive line during marker placement)

struct PlacementLineDragOverlay: View {
    let markerType: RLMarkerType
    let defaultPrice: Double
    @Binding var linePrice: Double?
    @Binding var isDragging: Bool
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager

    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var effectivePrice: Double { linePrice ?? defaultPrice }
    private var lineY: CGFloat { coordinateSystem.yPosition(forPrice: effectivePrice) }

    private var handleCenterX: CGFloat { chartWidth / 2 }

    var body: some View {
        ZStack {
            // Horizontal dashed line
            Path { path in
                path.move(to: CGPoint(x: 0, y: lineY))
                path.addLine(to: CGPoint(x: chartWidth - 60, y: lineY))
            }
            .stroke(markerType.color, style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
            .allowsHitTesting(false)

            // Drag handle centered
            RoundedRectangle(cornerRadius: 4)
                .fill(markerType.color.opacity(isDragging ? 0.5 : 0.35))
                .frame(width: 40, height: 20)
                .overlay(
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 20, height: 1)
                        }
                    }
                )
                .position(x: handleCenterX, y: lineY)
                .allowsHitTesting(false)

            // Price + type label near Y-axis
            HStack(spacing: 3) {
                Text(markerType.lineLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text(chartData.formatPrice(effectivePrice))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(markerType.color.opacity(0.85))
            .cornerRadius(4)
            .position(x: chartWidth - 45, y: lineY)
            .allowsHitTesting(false)

            // Invisible drag hit area
            Color.clear
                .contentShape(Rectangle())
                .frame(width: chartWidth, height: 44)
                .position(x: chartWidth / 2, y: lineY)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartY = coordinateSystem.yPosition(forPrice: effectivePrice)
                                dragStartPrice = effectivePrice
                                haptic.impactOccurred()
                            }
                            let newY = dragStartY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            linePrice = newPrice
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .frame(width: chartWidth, height: chartHeight)
    }
}

// MARK: - Prediction Placement Overlay (3-line system: Entry + TP + SL)

struct PredictionPlacementOverlay: View {
    @Binding var placement: PredictionPlacementState?
    @Binding var draggingLine: PredictionLineType?
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager

    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        if let state = placement {
            ZStack {
                // Fill regions between lines
                fillRegions(state: state)

                // Entry line (green, solid, NOT draggable)
                priceLine(
                    price: state.entryPrice,
                    color: .green,
                    label: "Entry",
                    isDashed: false,
                    lineWidth: 2
                )

                // Take Profit line (blue, dashed, draggable)
                priceLine(
                    price: state.takeProfitPrice,
                    color: .blue,
                    label: "TP",
                    isDashed: true,
                    lineWidth: draggingLine == .takeProfit ? 2.5 : 1.5
                )

                // Stop Loss line (red, dashed, draggable)
                priceLine(
                    price: state.stopLossPrice,
                    color: .red,
                    label: "SL",
                    isDashed: true,
                    lineWidth: draggingLine == .stopLoss ? 2.5 : 1.5
                )

                // Drag handle for TP
                dragHandle(
                    price: state.takeProfitPrice,
                    color: .blue,
                    lineType: .takeProfit,
                    state: state
                )

                // Drag handle for SL
                dragHandle(
                    price: state.stopLossPrice,
                    color: .red,
                    lineType: .stopLoss,
                    state: state
                )
            }
            .frame(width: chartWidth, height: chartHeight)
        }
    }

    // MARK: - Fill Regions

    @ViewBuilder
    private func fillRegions(state: PredictionPlacementState) -> some View {
        let entryY = coordinateSystem.yPosition(forPrice: state.entryPrice)
        let tpY = coordinateSystem.yPosition(forPrice: state.takeProfitPrice)
        let slY = coordinateSystem.yPosition(forPrice: state.stopLossPrice)

        // Green fill between entry and TP
        let tpTop = min(entryY, tpY)
        let tpHeight = abs(entryY - tpY)
        Rectangle()
            .fill(Color.green.opacity(0.06))
            .frame(width: chartWidth - 60, height: max(0, tpHeight))
            .position(x: (chartWidth - 60) / 2, y: tpTop + tpHeight / 2)
            .allowsHitTesting(false)

        // Red fill between entry and SL
        let slTop = min(entryY, slY)
        let slHeight = abs(entryY - slY)
        Rectangle()
            .fill(Color.red.opacity(0.06))
            .frame(width: chartWidth - 60, height: max(0, slHeight))
            .position(x: (chartWidth - 60) / 2, y: slTop + slHeight / 2)
            .allowsHitTesting(false)
    }

    // MARK: - Price Line

    private var handleCenterX: CGFloat { chartWidth / 2 }

    @ViewBuilder
    private func priceLine(price: Double, color: Color, label: String, isDashed: Bool, lineWidth: CGFloat) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)

        // Line
        Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartWidth - 60, y: y))
        }
        .stroke(color.opacity(0.8), style: StrokeStyle(
            lineWidth: lineWidth,
            dash: isDashed ? [6, 3] : []
        ))
        .allowsHitTesting(false)

        // Price + label near Y-axis
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            Text(chartData.formatPrice(price))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.85))
        .cornerRadius(4)
        .position(x: chartWidth - 40, y: y)
        .allowsHitTesting(false)
    }

    // MARK: - Drag Handle

    @ViewBuilder
    private func dragHandle(price: Double, color: Color, lineType: PredictionLineType, state: PredictionPlacementState) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)
        let isActive = draggingLine == lineType

        // Visible handle centered
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(isActive ? 0.5 : 0.3))
            .frame(width: 40, height: 20)
            .overlay(
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 20, height: 1)
                    }
                }
            )
            .position(x: handleCenterX, y: y)
            .allowsHitTesting(false)

        // Invisible drag hit area
        Color.clear
            .contentShape(Rectangle())
            .frame(width: chartWidth, height: 44)
            .position(x: chartWidth / 2, y: y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if draggingLine != lineType {
                            draggingLine = lineType
                            dragStartY = coordinateSystem.yPosition(forPrice: price)
                            dragStartPrice = price
                            haptic.impactOccurred()
                        }
                        let newY = dragStartY + value.translation.height
                        let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)

                        // Auto-swap: when dragged line crosses entry, flip the other line
                        // to the opposite side to form a proper trade
                        if var p = placement {
                            let entry = p.entryPrice
                            let wasLong = p.takeProfitPrice > entry

                            switch lineType {
                            case .takeProfit:
                                p.takeProfitPrice = newPrice
                                let nowLong = newPrice > entry
                                // If direction flipped, mirror SL to opposite side
                                if wasLong != nowLong {
                                    let slOffset = abs(p.stopLossPrice - entry)
                                    p.stopLossPrice = nowLong ? entry - slOffset : entry + slOffset
                                }
                            case .stopLoss:
                                p.stopLossPrice = newPrice
                                let nowLong = p.takeProfitPrice > entry
                                let slCrossedToTPSide = (newPrice > entry) == nowLong
                                // If SL crossed to same side as TP, flip TP to other side
                                if slCrossedToTPSide {
                                    let tpOffset = abs(p.takeProfitPrice - entry)
                                    p.takeProfitPrice = newPrice > entry ? entry - tpOffset : entry + tpOffset
                                }
                            }
                            placement = p
                        }
                    }
                    .onEnded { _ in
                        draggingLine = nil
                    }
            )
    }
}

// MARK: - Horizontal Line Preview Helper View

struct MarkerHorizontalLinePreview: View {
    let candle: RLCandleDTO
    let markerType: RLMarkerType
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartData: ChartDataManager
    
    private var linePrice: Double {
        switch markerType.lineSource {
        case .candleOpen: return candle.open
        case .candleClose: return candle.close
        case .candleHigh: return candle.high
        case .candleLow: return candle.low
        case .custom, .none: return candle.close
        }
    }
    
    private var lineY: CGFloat {
        coordinateSystem.yPosition(forPrice: linePrice)
    }
    
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: lineY))
                path.addLine(to: CGPoint(x: chartWidth - 65, y: lineY))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .foregroundColor(markerType.color.opacity(0.7))
            .allowsHitTesting(false)
            
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

// MARK: - Draggable Marker Line Overlay (Entry / Exit / TP / SL)

struct DraggableMarkerLineOverlay: View {
    let marker: ChartMarkerUI
    let currentPrice: Double
    @ObservedObject var markerManager: MarkerManager
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager

    @State private var dragPrice: Double? = nil
    @State private var isDragging = false
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0

    private var effectivePrice: Double { dragPrice ?? currentPrice }
    private var lineY: CGFloat { coordinateSystem.yPosition(forPrice: effectivePrice) }

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: chartWidth, height: chartHeight)
            .overlay(
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: chartWidth, height: 44)
                    .position(x: chartWidth / 2, y: lineY)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    dragStartY = coordinateSystem.yPosition(forPrice: currentPrice)
                                    dragStartPrice = currentPrice
                                }
                                let newY = dragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                dragPrice = newPrice
                            }
                            .onEnded { value in
                                let newY = dragStartY + value.translation.height
                                let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                                Task {
                                    await markerManager.updateMarker(
                                        id: marker.id,
                                        horizontalLinePrice: newPrice
                                    )
                                }
                                dragPrice = nil
                                isDragging = false
                            }
                    )
            )
    }
}

// MARK: - Draggable Prediction Lines (Entry + Target)

struct DraggablePredictionLinesOverlay: View {
    let marker: ChartMarkerUI
    let entryPrice: Double
    let targetPrice: Double?
    @ObservedObject var markerManager: MarkerManager
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager

    @State private var dragEntryPrice: Double? = nil
    @State private var dragTargetPrice: Double? = nil
    @State private var entryDragStartY: CGFloat = 0
    @State private var targetDragStartY: CGFloat = 0

    private var effectiveEntryPrice: Double { dragEntryPrice ?? entryPrice }
    private var effectiveTargetPrice: Double? { targetPrice.map { dragTargetPrice ?? $0 } ?? dragTargetPrice }

    var body: some View {
        ZStack {
            if let target = effectiveTargetPrice {
                draggableStrip(price: target, isTarget: true)
            }
            draggableStrip(price: effectiveEntryPrice, isTarget: false)
        }
        .frame(width: chartWidth, height: chartHeight)
    }

    private func draggableStrip(price: Double, isTarget: Bool) -> some View {
        let y = coordinateSystem.yPosition(forPrice: price)
        return Color.clear
            .contentShape(Rectangle())
            .frame(width: chartWidth, height: 44)
            .position(x: chartWidth / 2, y: y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isTarget {
                            if dragTargetPrice == nil { targetDragStartY = y }
                            let newY = targetDragStartY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            dragTargetPrice = newPrice
                        } else {
                            if dragEntryPrice == nil { entryDragStartY = y }
                            let newY = entryDragStartY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            dragEntryPrice = newPrice
                        }
                    }
                    .onEnded { value in
                        if isTarget {
                            let newY = targetDragStartY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            Task { await markerManager.updateMarker(id: marker.id, targetPrice: newPrice) }
                            dragTargetPrice = nil
                        } else {
                            let newY = entryDragStartY + value.translation.height
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            Task { await markerManager.updateMarker(id: marker.id, horizontalLinePrice: newPrice) }
                            dragEntryPrice = nil
                        }
                    }
            )
    }
}

// MARK: - Marker Price Lines Overlay

struct MarkerPriceLinesOverlay: View {
    let selectedMarker: ChartMarkerUI?
    let previewMarker: (candle: RLCandleDTO, type: RLMarkerType)?
    let pendingInfo: PendingMarkerInfo?
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawSelectedMarkerLine(context: context, size: size)
                drawPreviewMarkerLine(context: context, size: size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawSelectedMarkerLine(context: GraphicsContext, size: CGSize) {
        guard let marker = selectedMarker,
              marker.type.hasHorizontalLine,
              let candle = getCandleForMarker(marker) else { return }

        // Prediction markers: show Entry (green) + TP (blue) + SL (red) with fill regions
        if marker.type == .predictionTarget {
            drawPredictionMarkerLines(context: context, size: size, marker: marker, candle: candle)
            return
        }

        // Non-prediction: use stored horizontal line price or derive from candle
        let linePrice: Double? = marker.horizontalLinePrice ?? marker.linePrice(for: candle)

        if let price = linePrice {
            drawPriceLine(
                context: context,
                size: size,
                price: price,
                color: marker.displayColor,
                isDashed: false,
                label: marker.type.lineLabel
            )
        }
    }

    private func drawPredictionMarkerLines(context: GraphicsContext, size: CGSize, marker: ChartMarkerUI, candle: RLCandleDTO) {
        let entryPrice = marker.horizontalLinePrice ?? marker.price
        let tpPrice = marker.targetPrice
        let slPrice = marker.stopLossPrice
        let lineEndX = size.width - 60

        // Entry line (green, solid)
        let entryY = coordinateSystem.yPosition(forPrice: entryPrice)
        if entryY >= 0 && entryY <= chartHeight {
            let entryPath = Path { p in
                p.move(to: CGPoint(x: 0, y: entryY))
                p.addLine(to: CGPoint(x: lineEndX, y: entryY))
            }
            context.stroke(entryPath, with: .color(Color.green.opacity(0.6)), style: StrokeStyle(lineWidth: 2))
            drawPriceLabel(context: context, size: size, y: entryY, price: entryPrice, color: .green, label: "Entry")
        }

        // TP line (blue, dashed) + green fill region
        if let tp = tpPrice {
            let tpY = coordinateSystem.yPosition(forPrice: tp)

            // Green fill between entry and TP
            let fillTop = min(entryY, tpY)
            let fillHeight = abs(entryY - tpY)
            if fillHeight > 0 {
                let fillRect = CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)
                context.fill(Path(fillRect), with: .color(Color.green.opacity(0.06)))
            }

            if tpY >= 0 && tpY <= chartHeight {
                let tpPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: tpY))
                    p.addLine(to: CGPoint(x: lineEndX, y: tpY))
                }
                context.stroke(tpPath, with: .color(Color.blue.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                drawPriceLabel(context: context, size: size, y: tpY, price: tp, color: .blue, label: "TP")
            }
        }

        // SL line (red, dashed) + red fill region
        if let sl = slPrice {
            let slY = coordinateSystem.yPosition(forPrice: sl)

            // Red fill between entry and SL
            let fillTop = min(entryY, slY)
            let fillHeight = abs(entryY - slY)
            if fillHeight > 0 {
                let fillRect = CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)
                context.fill(Path(fillRect), with: .color(Color.red.opacity(0.06)))
            }

            if slY >= 0 && slY <= chartHeight {
                let slPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: slY))
                    p.addLine(to: CGPoint(x: lineEndX, y: slY))
                }
                context.stroke(slPath, with: .color(Color.red.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                drawPriceLabel(context: context, size: size, y: slY, price: sl, color: .red, label: "SL")
            }
        }
    }

    private func drawPriceLabel(context: GraphicsContext, size: CGSize, y: CGFloat, price: Double, color: Color, label: String) {
        let labelX = size.width - 35
        let priceText = chartData.formatPrice(price)
        let displayText = "\(label) \(priceText)"
        let estimatedWidth: CGFloat = 110
        let labelRect = CGRect(
            x: labelX - estimatedWidth / 2,
            y: y - 11,
            width: estimatedWidth,
            height: 22
        )
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
        context.fill(roundedPath, with: .color(color))
        context.draw(
            Text(displayText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: labelX, y: y)
        )
    }
    
    private func drawPreviewMarkerLine(context: GraphicsContext, size: CGSize) {
        guard let preview = previewMarker else { return }

        // Prediction: draw full 3-line system using pending info
        if preview.type == .predictionTarget,
           let pending = pendingInfo,
           pending.markerType == .predictionTarget {
            let entryPrice = pending.horizontalLinePrice ?? pending.price
            let lineEndX = size.width - 60

            // Entry line (green)
            let entryY = coordinateSystem.yPosition(forPrice: entryPrice)
            if entryY >= 0 && entryY <= chartHeight {
                let entryPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: entryY))
                    p.addLine(to: CGPoint(x: lineEndX, y: entryY))
                }
                context.stroke(entryPath, with: .color(Color.green.opacity(0.6)), style: StrokeStyle(lineWidth: 2))
                drawPriceLabel(context: context, size: size, y: entryY, price: entryPrice, color: .green, label: "Entry")
            }

            // TP line (blue)
            if let tp = pending.targetPrice {
                let tpY = coordinateSystem.yPosition(forPrice: tp)
                let fillTop = min(entryY, tpY)
                let fillHeight = abs(entryY - tpY)
                if fillHeight > 0 {
                    context.fill(Path(CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)), with: .color(Color.green.opacity(0.06)))
                }
                if tpY >= 0 && tpY <= chartHeight {
                    let tpPath = Path { p in
                        p.move(to: CGPoint(x: 0, y: tpY))
                        p.addLine(to: CGPoint(x: lineEndX, y: tpY))
                    }
                    context.stroke(tpPath, with: .color(Color.blue.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    drawPriceLabel(context: context, size: size, y: tpY, price: tp, color: .blue, label: "TP")
                }
            }

            // SL line (red)
            if let sl = pending.stopLossPrice {
                let slY = coordinateSystem.yPosition(forPrice: sl)
                let fillTop = min(entryY, slY)
                let fillHeight = abs(entryY - slY)
                if fillHeight > 0 {
                    context.fill(Path(CGRect(x: 0, y: fillTop, width: lineEndX, height: fillHeight)), with: .color(Color.red.opacity(0.06)))
                }
                if slY >= 0 && slY <= chartHeight {
                    let slPath = Path { p in
                        p.move(to: CGPoint(x: 0, y: slY))
                        p.addLine(to: CGPoint(x: lineEndX, y: slY))
                    }
                    context.stroke(slPath, with: .color(Color.red.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    drawPriceLabel(context: context, size: size, y: slY, price: sl, color: .red, label: "SL")
                }
            }
            return
        }

        // Non-prediction: single static line
        // Use dragged price from pending info if available, otherwise default to candle price
        let linePrice: Double
        if let pending = pendingInfo, let draggedPrice = pending.horizontalLinePrice {
            linePrice = draggedPrice
        } else {
            switch preview.type.lineSource {
            case .candleOpen: linePrice = preview.candle.open
            case .candleClose: linePrice = preview.candle.close
            case .candleHigh: linePrice = preview.candle.high
            case .candleLow: linePrice = preview.candle.low
            case .custom, .none: linePrice = preview.candle.close
            }
        }

        drawPriceLine(
            context: context,
            size: size,
            price: linePrice,
            color: preview.type.color,
            isDashed: true,
            label: preview.type.lineLabel.isEmpty ? nil : preview.type.lineLabel
        )
    }
    
    private func getCandleForMarker(_ marker: ChartMarkerUI) -> RLCandleDTO? {
        guard marker.candleIndex >= 0 && marker.candleIndex < chartData.candles.count else {
            return nil
        }
        return chartData.candles[marker.candleIndex]
    }
    
    private func drawPriceLine(
        context: GraphicsContext,
        size: CGSize,
        price: Double,
        color: Color,
        isDashed: Bool,
        label: String? = nil
    ) {
        let y = coordinateSystem.yPosition(forPrice: price)
        
        guard y >= 0 && y <= chartHeight else { return }
        
        let lineEndX = size.width - 60
        
        let linePath = Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))
        }
        
        let strokeStyle = isDashed ?
            StrokeStyle(lineWidth: 1.5, dash: [6, 4]) :
            StrokeStyle(lineWidth: 2)
        
        context.stroke(linePath, with: .color(color.opacity(0.6)), style: strokeStyle)
        
        let labelX = size.width - 35
        let priceText = chartData.formatPrice(price)
        
        let displayText: String
        if let label = label {
            displayText = "\(label) \(priceText)"
        } else {
            displayText = priceText
        }
        
        let estimatedWidth: CGFloat = label != nil ? 110 : 70
        let labelRect = CGRect(
            x: labelX - estimatedWidth/2,
            y: y - 11,
            width: estimatedWidth,
            height: 22
        )
        
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
        context.fill(roundedPath, with: .color(color))
        
        context.draw(
            Text(displayText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: labelX, y: y)
        )
    }
}

// MARK: - Prediction Target Line Overlay

struct PredictionTargetLineOverlay: View {
    let entryPrice: Double
    @Binding var targetPrice: Double?
    @Binding var isDragging: Bool
    let isInteractive: Bool
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    
    // FIXED: Store initial Y position when drag starts to prevent feedback loop
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartPrice: Double = 0
    
    var body: some View {
        ZStack {
            targetLineCanvas
            
            if isInteractive, let currentTargetPrice = targetPrice {
                draggableArea(currentTargetPrice: currentTargetPrice)
            }
        }
    }
    
    @ViewBuilder
    private var targetLineCanvas: some View {
        Canvas { context, size in
            guard let targetPrice = targetPrice else { return }
            
            let y = coordinateSystem.yPosition(forPrice: targetPrice)
            guard y >= 0 && y <= chartHeight else { return }
            
            drawTargetLine(context: context, size: size, y: y)
            drawTargetLabel(context: context, size: size, y: y)
            
            if isInteractive {
                drawDragHandle(context: context, y: y)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawTargetLine(context: GraphicsContext, size: CGSize, y: CGFloat) {
        let lineEndX = size.width - 60
        let linePath = Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineEndX, y: y))
        }
        
        let lineWidth: CGFloat = isDragging ? 3 : 2
        context.stroke(linePath, with: .color(Color.orange.opacity(0.8)), style: StrokeStyle(lineWidth: lineWidth))
    }
    
    private func drawTargetLabel(context: GraphicsContext, size: CGSize, y: CGFloat) {
        guard let targetPrice = targetPrice else { return }
        
        let labelX = size.width - 35
        let priceText = chartData.formatPrice(targetPrice)
        let displayText = "Target \(priceText)"
        
        let estimatedWidth: CGFloat = 110
        let labelRect = CGRect(
            x: labelX - estimatedWidth/2,
            y: y - 11,
            width: estimatedWidth,
            height: 22
        )
        
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
        context.fill(roundedPath, with: .color(Color.orange))
        
        context.draw(
            Text(displayText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: labelX, y: y)
        )
    }
    
    private func drawDragHandle(context: GraphicsContext, y: CGFloat) {
        let handleSize: CGFloat = 40
        let handleRect = CGRect(
            x: 10,
            y: y - handleSize/2,
            width: handleSize,
            height: handleSize
        )
        
        let handlePath = Path(roundedRect: handleRect, cornerRadius: 8)
        context.fill(handlePath, with: .color(Color.orange.opacity(isDragging ? 0.3 : 0.2)))
        
        let arrowsImage = Image(systemName: "arrow.up.arrow.down")
        context.draw(arrowsImage, in: handleRect)
    }
    
    @ViewBuilder
    private func draggableArea(currentTargetPrice: Double) -> some View {
        // FIXED: Capture initial position on drag start to prevent feedback loop
        GeometryReader { geo in
            let currentY = coordinateSystem.yPosition(forPrice: currentTargetPrice)
            
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geo.size.width, height: 60)
                .position(x: geo.size.width / 2, y: currentY)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                // FIXED: Capture starting position on first touch
                                isDragging = true
                                dragStartY = currentY
                                dragStartPrice = currentTargetPrice
                            }
                            
                            // FIXED: Calculate new Y based on drag translation from START position
                            // This prevents the feedback loop where changing price changes Y
                            let newY = dragStartY + value.translation.height

                            // Convert to price (unclamped so lines can go beyond visible range)
                            let newPrice = coordinateSystem.unclampedPrice(atYPosition: newY)
                            self.targetPrice = newPrice
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
    }
}

// MARK: - Static Target Line

struct StaticTargetLineOverlay: View {
    let entryPrice: Double
    let targetPrice: Double
    let coordinateSystem: ChartCoordinateSystem
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let chartData: ChartDataManager
    
    var body: some View {
        Canvas { context, size in
            let y = coordinateSystem.yPosition(forPrice: targetPrice)
            guard y >= 0 && y <= chartHeight else { return }
            
            let lineEndX = size.width - 60
            
            let linePath = Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: lineEndX, y: y))
            }
            
            context.stroke(linePath, with: .color(Color.orange.opacity(0.8)), style: StrokeStyle(lineWidth: 2))
            
            let labelX = size.width - 35
            let priceText = chartData.formatPrice(targetPrice)
            let displayText = "Target \(priceText)"
            
            let labelRect = CGRect(
                x: labelX - 55,
                y: y - 11,
                width: 110,
                height: 22
            )
            
            let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
            context.fill(roundedPath, with: .color(Color.orange))
            
            context.draw(
                Text(displayText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white),
                at: CGPoint(x: labelX, y: y)
            )
        }
        .allowsHitTesting(false)
    }
}
