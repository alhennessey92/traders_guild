import SwiftUI

struct TradingChartView: View {
    private struct DrawingHandleDragOrigin {
        let draftId: UUID
        let handle: MarkerDrawingHandle
        let screenPoint: CGPoint
    }

    // MARK: - State Properties
    
    // MARK: - Chart Context Accessors

    private var currentTimeframe: RLChartTimeframe {
        chartViewModel.currentTimeframe
    }

    private var currentSymbol: RLTradingSymbolDTO? {
        chartViewModel.currentSymbol
    }

    private func compactMainChartPriceLabel(_ price: Double, chartHeight: CGFloat? = nil) -> String {
        formatMainChartPriceLabel(
            price,
            symbol: currentSymbol,
            priceRange: chartData.priceRange,
            priceScale: gestureState.priceScale,
            chartHeight: chartHeight
        )
    }
    
    // MARK: - Chart Control ViewModel
    @ObservedObject var controlViewModel: ChartControlViewModel
    @EnvironmentObject private var rlAppState: RLAppState
    
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
    var activeTimeframeLegendEntries: [ActiveIndicatorLegendEntry] = []
    
    /// Total height of all active indicator panels (for bottom controls positioning)
    /// Passed from MainView to ensure controls float above panels
    var indicatorPanelBottomPadding: CGFloat = 0
    /// Label-strip reserve currently present at the bottom chart/panel boundary.
    /// Used to avoid double-counting that strip in control/info offsets.
    var panelBottomBoundaryLabelReserve: CGFloat = 0
    /// Extra clearance for floating controls when multiple lower panels are expanded.
    var floatingOverlayPanelClearance: CGFloat = 0
    /// Dedicated reserve for the bottom control row and current-price exclusion zone.
    var chartControlRowPanelReserve: CGFloat = 0

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
    @State private var isChartPanning = false

    @State private var didEvaluateDrawingPanLockForCurrentDrag = false
    
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

    /// Intrinsic width of the chart info header rows.
    /// The legend is constrained to this width so active drawings/indicators don't widen the panel.
    @State private var chartInfoBaseContentWidth: CGFloat = 0
    
    
    
    // MARK: - UI State
    
    /// Whether we're in marker placement mode (user is positioning new marker)
    /// When true, drag gestures move the preview marker instead of panning chart
    // Marker placement mode is now controlled by ViewModel
    private var isMarkerPlacementMode: Bool {
        controlViewModel.isMarkerPlacementMode
    }

    @ObservedObject private var chartDrawingPlacementState: MarkerPlacementState

    private var isDrawingPanLockActive: Bool {
        activeInteractiveDrawingState?.drawingSession.isPanLocked ?? false
    }

    private var isDraggingDrawingControlHandle: Bool {
        activeInteractiveDrawingState?.drawingSession.selectedHandle != nil
    }
    
    /// Track if marker is actively being dragged (for scale animation)
    @State private var isMarkerBeingDragged = false
    
    /// Haptic feedback generator for marker interactions
    private let impactFeedback = PlatformImpactGenerator(style: .medium)
    
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
    @State private var isSubmittingPlacement = false
    @State private var placementSubmitErrorMessage: String?

    /// NEW PREDICTION PLACEMENT STATE (3-line system: Entry + TP + SL)
    @State private var predictionPlacement: PredictionPlacementState? = nil
    @State private var draggingPredictionLine: PredictionLineType? = nil
    @State private var isSyncingSetupPlacementState = false

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
    @State private var markerDragStartPosition: CGPoint?
    
    @State private var chartSize: CGSize = .zero
    
    /// Stores crosshair position at start of drag for relative movement
    /// This allows crosshair to move by delta instead of jumping to finger position
    @State private var crosshairDragStartPosition: CGPoint? = nil
    @State private var drawingGuideDragStartScreenPoint: CGPoint? = nil
    @State private var drawingGuideDragStartGuidePoint: MarkerDrawingGuidePoint? = nil
    @State private var drawingHandleDragOrigin: DrawingHandleDragOrigin? = nil

    
    /// Whether to show duplicate marker type alert
    @State private var showDuplicateMarkerAlert = false

    /// Marker visibility type-filter sheet state.
    @State private var showMarkerTypeFilterSheet = false
    @State private var isMarkerVisibilityPanelExpanded = false

    /// Chart display settings (grid, candle colors).
    @ObservedObject private var chartSettings = ChartSettings.shared
    @State private var showChartSettingsSheet = false
    @State private var isSubmittingViewingPollVote = false
    @State private var viewingPollVoteOptionId: UUID?
    @State private var isViewingInfoPanelCollapsed = false
    @State private var drawingTextEditorContext: DrawingTextEditorContext?
    

    
    /// Components from the selected marker to render as temporary chart overlays.
    @State private var markerOverlayComponents: [RLMarkerComponentDTO] = []

    /// Shared placement state for the on-chart marker placement UI.
    /// Drives MarkerPlacementPanel and GhostPreviewLayer.
    /// Owned by MainView and passed down so ChartBottomSheet can also access it.
    @ObservedObject var placementState: MarkerPlacementState

    /// Track if chart has been initialized with proper position
    @State private var hasInitializedPosition = false

    /// True while a programmatic scroll animation is in flight (reset-to-latest, jump-to-start/
    /// latest). These animate panOffset toward a FIXED target; if historical preloading fired
    /// during the animation it would page at the front of the data and the animation would
    /// overwrite the prepend's offset shift toward its stale target, chain-loading pages and
    /// jerking the chart. Preload is suppressed while this is set; user-driven pans never set it.
    @State private var isProgrammaticScroll = false
    @State private var historicalPriceRangeTransitionTask: Task<Void, Never>?
    @State private var lastHistoricalPreloadCheckAt: Date = .distantPast
    @State private var suppressHistoricalPreloadUntil: Date = .distantPast

    /// Track if chart is loading (waiting for data)
    @State private var isChartLoading = true

    /// Breathing animation for marker-navigation loading state.
    @State private var markerNavigationPulse = false
    
    /// Track the marker ID that was just tapped (for animation)
    @State private var tappedMarkerId: UUID? = nil
    @State private var pendingMarkerSelectionId: UUID? = nil
    
    /// Animated scale for selected marker (1.0 -> 1.3 with spring for selection feedback)
    @State private var selectionScale: CGFloat = 1.0
    /// Animated rotation for selected marker wiggle effect (degrees)
    @State private var selectionRotation: CGFloat = 0

    // MARK: - Chart Configuration
    
    /// Base width of each candle before any scaling is applied
    /// This is the "normal" candle width at 1x zoom
    private let baseCandleWidth: CGFloat = 12
    
    /// Spacing between adjacent candles
    /// Creates visual separation for readability
    private let candleSpacing: CGFloat = 4
    
    /// Edge padding to prevent endless scrolling
    /// Provides buffer space at chart boundaries
    private let edgePadding: CGFloat = ChartGestureState.horizontalEdgePadding
    
    /// Width of the Y-axis interaction area on the right side
    /// This area captures vertical drag/pinch gestures for price scaling
    private let yAxisWidth: CGFloat = ChartAxisMetrics.yAxisLaneWidth
    
    // MARK: - Chart View Model
    
    /// Chart view model that coordinates chart state and data
    @ObservedObject var chartViewModel: ChartViewModel
    
    /// Observe indicator changes directly so chart overlays redraw reliably.
    @ObservedObject private var indicatorManager: IndicatorManager
    @ObservedObject private var chartDrawingManager: ChartDrawingManager
    
    /// Shorthand accessor for data manager
    /// This computed property lets us keep using "chartData" throughout the file
    private var chartData: ChartDataManager {
        chartViewModel.dataManager
    }

    private var axisTimeZone: TimeZone {
        currentSymbol?.exchangeTimeZone ?? .current
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
    
    /// Dampening factor for chart pan drag response.
    /// Lower values smooth touch jitter but increase perceived lag.
    private let panDragSensitivity: CGFloat = 0.84
    private let panDragMellowThreshold: CGFloat = 10
    private let panDragMellowCompression: CGFloat = 0.76
    
    /// Ignore tiny per-frame drag deltas to reduce micro-jitter during panning.
    private let panDragNoiseFloor: CGFloat = 0.16
    private let drawingGuideDragActivationDistance: CGFloat = 6
    private let drawingHandleDragActivationDistance: CGFloat = 8
    
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
        clampedVerticalOffset(gestureState.verticalPanOffset, chartHeight: chartHeight)
    }

    private func clampedVerticalOffset(_ proposedOffset: CGFloat, chartHeight: CGFloat) -> CGFloat {
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
        return Swift.min(verticalPadding, Swift.max(-verticalPadding, proposedOffset))
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
    ///   - activeTimeframeLegendEntries: Label-only timeframe summaries for the active panel source
    ///   - indicatorPanelBottomPadding: Total height of all active indicator panels
    ///   - panelBottomBoundaryLabelReserve: Bottom boundary x-axis-strip reserve, if visible
    init(
        userId: UUID = UUID(),
        username: String = "TestUser",
        guildId: UUID = UUID(),
        currentUserMember: RLGuildMemberDTO? = nil,
        controlViewModel: ChartControlViewModel,
        chartViewModel: ChartViewModel,
        gestureState: ChartGestureState,
        placementState: MarkerPlacementState,
        rsiPanelHeight: Binding<CGFloat> = .constant(120),
        activeTimeframeLegendEntries: [ActiveIndicatorLegendEntry] = [],
        indicatorPanelBottomPadding: CGFloat = 0,
        panelBottomBoundaryLabelReserve: CGFloat = 0,
        floatingOverlayPanelClearance: CGFloat = 0,
        chartControlRowPanelReserve: CGFloat = 0
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
        self._indicatorManager = ObservedObject(wrappedValue: chartViewModel.indicatorManager)
        self._chartDrawingManager = ObservedObject(wrappedValue: chartViewModel.chartDrawingManager)
        self._chartDrawingPlacementState = ObservedObject(wrappedValue: chartViewModel.chartComponentsPlacementState)
        self.gestureState = gestureState
        self.placementState = placementState
        self._rsiPanelHeight = rsiPanelHeight
        self.activeTimeframeLegendEntries = activeTimeframeLegendEntries
        self.indicatorPanelBottomPadding = indicatorPanelBottomPadding
        self.panelBottomBoundaryLabelReserve = panelBottomBoundaryLabelReserve
        self.floatingOverlayPanelClearance = floatingOverlayPanelClearance
        self.chartControlRowPanelReserve = chartControlRowPanelReserve
    }
    
    // MARK: - Target Line Helpers
    
    /// Whether to show interactive target line during selection
    private var shouldShowInteractiveTargetLine: Bool {
        guard controlViewModel.currentMarkerIntent == .setup else { return false }
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

    private func shouldAllowSelectedMarkerLevelEditing(_ marker: ChartMarkerUI) -> Bool {
        guard !controlViewModel.isMarkerViewingMode,
              !isMarkerPlacementMode,
              !isInteractiveDrawingSessionActive,
              marker.canEdit else {
            return false
        }

        if marker.intent == .setup,
           marker.trackingEnabled,
           let trackingState = marker.trackingState,
           trackingState != .draft {
            return false
        }

        return true
    }
    
    /// Get preview marker data for price line display
    private var previewMarkerForPriceLine: PreviewPriceLine? {
        // When sheet is open (pendingMarkerInfo exists), use that data
        if let pending = pendingMarkerInfo,
           pending.candleIndex >= 0,
           pending.candleIndex < chartData.candles.count {
            guard pending.markerIntent == .setup else { return nil }
            let label = pending.markerIntent == .setup ? "Entry" : nil
            return PreviewPriceLine(
                candle: chartData.candles[pending.candleIndex],
                intent: pending.markerIntent,
                color: pending.markerIntent == .setup ? .green : pending.markerIntent.color,
                label: label,
                explicitPrice: pending.horizontalLinePrice ?? pending.price
            )
        }

        // Suppress preview line when prediction overlay is active
        if isMarkerPlacementMode,
           controlViewModel.currentMarkerIntent == .setup,
           predictionPlacement != nil {
            return nil
        }

        // Otherwise use placement mode preview
        if isMarkerPlacementMode,
           previewCandleIndex >= 0,
           previewCandleIndex < chartData.candles.count,
           let markerIntent = controlViewModel.currentMarkerIntent {
            guard markerIntent == .setup else { return nil }
            let explicitPrice: Double?
            if markerIntent == .setup {
                explicitPrice = predictionPlacement?.entryPrice
            } else {
                explicitPrice = placementLinePrice
            }
            return PreviewPriceLine(
                candle: chartData.candles[previewCandleIndex],
                intent: markerIntent,
                color: markerIntent.color,
                label: markerIntent == .setup ? "Entry" : nil,
                explicitPrice: explicitPrice
            )
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
        if chartViewModel.markerNavigationSession != nil {
            return true
        }
        if chartViewModel.currentSymbol == nil {
            return true
        }
        if chartViewModel.isLoadingData {
            return true
        }
        return isChartLoading && !chartData.candles.isEmpty
    }

    private var shouldShowNoDataOverlay: Bool {
        chartViewModel.currentSymbol != nil
            && !chartViewModel.isLoadingData
            && chartData.candles.isEmpty
    }
    
    /// Effective candle index for marker preview (from pending or placement mode)
    /// Prediction markers are pinned to the most recent candle.
    private var effectiveCandleIndex: Int {
        if let pending = pendingMarkerInfo {
            return pending.candleIndex
        }
        guard !chartData.candles.isEmpty else { return -1 }
        if isMarkerPlacementMode {
            // Prediction: always use latest candle (entry pinned to most recent)
            if controlViewModel.currentMarkerIntent == .setup {
                return snappedMarkerCandleIndex(from: chartData.candles.count - 1) ?? -1
            }
            if previewCandleIndex < 0 {
                return snappedMarkerCandleIndex(from: calculateCenterCandleIndex()) ?? -1
            }
            return snappedMarkerCandleIndex(from: previewCandleIndex) ?? -1
        }
        return snappedMarkerCandleIndex(from: previewCandleIndex) ?? -1
    }
    
    /// Effective marker intent for preview (from pending or placement mode).
    private var effectiveMarkerIntent: RLMarkerIntent? {
        pendingMarkerInfo?.markerIntent ?? controlViewModel.currentMarkerIntent
    }

    /// Whether marker placement overlay should be shown
    private var shouldShowMarkerPlacementOverlay: Bool {
        isMarkerPlacementMode || pendingMarkerInfo != nil
    }

    private var hasDefaultChartDrawingComponents: Bool {
        chartDrawingPlacementState.components.contains { draft in
            switch draft.componentType {
            case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .textNote, .reactionEmoji, .levelSupport, .levelResistance:
                return true
            default:
                return false
            }
        }
    }

    private var isDefaultChartDrawingContextEnabled: Bool {
        !isMarkerPlacementMode
        && !controlViewModel.isMarkerViewingMode
        && (
            hasDefaultChartDrawingComponents
            || chartDrawingPlacementState.drawingInteractionPhase != .idle
            || chartDrawingPlacementState.activeDrawingWorkflowTool != nil
        )
    }

    private var activeInteractiveDrawingState: MarkerPlacementState? {
        if isMarkerPlacementMode {
            return placementState
        }
        if isDefaultChartDrawingContextEnabled {
            return chartDrawingPlacementState
        }
        return nil
    }

    private var shouldShowDefaultChartDrawingOverlay: Bool {
        !isMarkerPlacementMode && isDefaultChartDrawingContextEnabled
    }

    private var isInteractiveDrawingSessionActive: Bool {
        guard let drawingState = activeInteractiveDrawingState else { return false }
        if drawingState.drawingSession.isActive {
            return true
        }
        switch drawingState.drawingInteractionPhase {
        case .idle:
            return false
        case .placingFirstPoint, .placingSecondPoint, .editing, .committing:
            return true
        }
    }

    private var shouldShowDrawingGuideAxisIndicators: Bool {
        guard let drawingState = activeInteractiveDrawingState,
              currentDrawingGuidePoint != nil else {
            return false
        }

        switch drawingState.drawingInteractionPhase {
        case .placingFirstPoint, .placingSecondPoint:
            return true
        case .editing:
            return drawingState.drawingSession.selectedHandle != nil
        case .idle, .committing:
            return false
        }
    }
    
    /// Whether instruction banner should be shown
    /// Disabled — replaced by inline MarkerPlacementPanel during placement mode
    private var shouldShowInstructionBanner: Bool {
        false
    }
    
    // MARK: - Body
    
    var body: some View {
        withNotificationHandlers(
            withPlacementAndChartObservers(
                withSheetPresentations(rootChartContainer)
            )
        )
    }

    private var rootChartContainer: some View {
        ZStack {
            if ThemeManager.shared.currentTheme == .midGrey {
                AppColors.chartPanelBackgroundMuted
                    .ignoresSafeArea()
                PatternOverlay(patternType: .honeycomb, hexSize: 16, strokeColor: AppColors.patternStroke)
                    .opacity(0.015)
                    .ignoresSafeArea()
            } else if ThemeManager.shared.currentTheme == .lightGrey {
                AppColors.chartPanelBackgroundMuted
                    .ignoresSafeArea()
                PatternOverlay(patternType: .honeycomb, hexSize: 16, strokeColor: AppColors.patternStroke)
                    .opacity(AppColors.chartLightGreyHoneycombOpacity)
                    .ignoresSafeArea()
            }

            GeometryReader { geometry in
                chartContent(geometry: geometry)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private func withSheetPresentations<Content: View>(_ content: Content) -> some View {
        // Modal MarkerComposerSheet removed — placement UI is now inline on the chart
        // (MarkerPlacementPanel bottom + GhostPreviewLayer on canvas)
        return content
            .sheet(isPresented: $showMarkerTypeFilterSheet) {
                markerTypeFilterSheet
            }
            .sheet(isPresented: $showChartSettingsSheet) {
                ChartSettingsView(
                    settings: chartSettings,
                    onResetToLatest: {
                        controlViewModel.resetToLatest()
                    }
                )
            }
            .sheet(item: $drawingTextEditorContext) { context in
                DrawingTextEditorSheet(
                    context: context,
                    onSave: { value in
                        applyDrawingTextEditorValue(value, context: context)
                    }
                )
            }
    }

    private func withPlacementAndChartObservers<Content: View>(_ content: Content) -> some View {
        withMarketObservers(
            withPlacementObservers(
                withContextObservers(content)
            )
        )
    }

    private func withContextObservers<Content: View>(_ content: Content) -> some View {
        content
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
            .onChange(of: controlViewModel.isMarkerViewingMode) { _, isViewing in
                if isViewing {
                    isViewingInfoPanelCollapsed = false
                } else {
                    settleHistoricalPriceRangeAfterMarkerExit()
                }
            }
    }

    private func withPlacementObservers<Content: View>(_ content: Content) -> some View {
        content
            .onChange(of: placementState.intent) { oldValue, newValue in
                handlePlacementIntentChange(oldIntent: oldValue, newIntent: newValue)
            }
            .onChange(of: placementState.activeTool) { _, _ in
                reconcileDrawingInteractionState()
            }
            .onChange(of: placementState.activeSubTool) { _, _ in
                reconcileDrawingInteractionState()
            }
            .onChange(of: placementState.selectedPlacementTab) { _, _ in
                reconcileDrawingInteractionState()
            }
            .onChange(of: placementState.drawingInteractionPhase) { _, _ in
                reconcileDrawingInteractionState()
            }
            .onChange(of: predictionPlacement) { _, _ in
                syncSetupComponentsFromPredictionPlacement()
            }
            .onChange(of: placementState.componentPrice(.levelTp)) { _, _ in
                syncPredictionPlacementFromSetupComponents()
            }
            .onChange(of: placementState.componentPrice(.levelSl)) { _, _ in
                syncPredictionPlacementFromSetupComponents()
            }
    }

    private func withMarketObservers<Content: View>(_ content: Content) -> some View {
        content
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
            .onChange(of: chartData.candles.last?.timestamp) { _, _ in
                initializeLatestPositionIfNeeded()
            }
            .onChange(of: rlAppState.isNetworkReachable) { wasReachable, isReachable in
                // Connectivity returned while stuck with no candles → recover now
                // rather than waiting for the backoff timer.
                guard isReachable, !wasReachable else { return }
                if chartViewModel.currentSymbol != nil, chartData.candles.isEmpty {
                    Task { await chartViewModel.retryChartDataLoad(reason: "network_restored") }
                }
            }
    }

    private func withNotificationHandlers<Content: View>(_ content: Content) -> some View {
        content
            // Each of these is addressed to a single pane. Without the filter,
            // one "Place Marker" tap would fire on every chart on screen.
            .onReceive(NotificationCenter.default.publisher(for: .focusSharedMarker)) { notification in
                guard ChartPaneAddressing.isAddressed(notification, to: chartViewModel.paneID) else { return }
                guard let userInfo = notification.userInfo,
                      let payload = MarkerSharePayloadV1(userInfo) else { return }
                focusSharedMarker(payload)
            }
            .onReceive(NotificationCenter.default.publisher(for: .markerOverlayApply)) { notification in
                guard ChartPaneAddressing.isAddressed(notification, to: chartViewModel.paneID) else { return }
                guard let marker = notification.userInfo?["marker"] as? ChartMarkerUI else { return }
                applyMarkerOverlay(marker)
            }
            .onReceive(NotificationCenter.default.publisher(for: .markerOverlayClear)) { notification in
                guard ChartPaneAddressing.isAddressed(notification, to: chartViewModel.paneID) else { return }
                clearMarkerOverlay()
            }
            .onReceive(NotificationCenter.default.publisher(for: .placeMarkerRequested)) { notification in
                guard ChartPaneAddressing.isAddressed(notification, to: chartViewModel.paneID) else { return }
                placeMarkerFromState()
            }
    }
    
    // MARK: - Main Chart Content
    
    @ViewBuilder
    private func chartContent(geometry: GeometryProxy) -> some View {
        let coordinateSystem = createCoordinateSystem(geometry: geometry)
        let predictionPlacementActive = isPredictionPlacementOverlayActive

        ZStack {
            interactiveChartLayer(
                geometry: geometry,
                coordinateSystem: coordinateSystem,
                predictionPlacementActive: predictionPlacementActive
            )
            .gesture(crosshairDismissTapGesture())
            .gesture(crosshairGesture(coordinateSystem: coordinateSystem))
            .simultaneousGesture(tapGestureForMarkers(geometry: geometry))
            .simultaneousGesture(drawingInteractionTapGesture(coordinateSystem: coordinateSystem))
            .simultaneousGesture(drawingInteractionDragGesture(coordinateSystem: coordinateSystem))
            .simultaneousGesture(dragGesture(in: geometry.size, coordinateSystem: coordinateSystem))
            .simultaneousGesture(pinchGesture(in: geometry.size))
            .overlay(yAxisGestureOverlay)
            .overlay(loadingOverlayIfNeeded)
            .overlay(duplicateMarkerOverlayIfNeeded)
            .onAppear {
                updateChartSize(geometry.size)
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
                syncChartDrawingPlacementAnchorToVisibleCenter()
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: markerManager.selectedMarker?.id) { _, newId in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
                if newId == nil {
                    settleHistoricalPriceRangeAfterMarkerExit(
                        chartWidth: geometry.size.width,
                        chartHeight: geometry.size.height
                    )
                    withAnimation(.easeOut(duration: 0.3)) { selectionScale = 1.0 }
                    selectionRotation = 0
                } else {
                    suppressHistoricalPreloadBriefly()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { selectionScale = 1.5 }
                    // Delay wiggle so centering pan settles first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        triggerChartMarkerWiggle()
                    }
                }
            }
            .onChange(of: markerManager.selectedMarker?.candleIndex) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
            }
            .onChange(of: gestureState.panOffset.width) { _, _ in
                if !isChartPanning {
                    syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
                }
                syncChartDrawingPlacementAnchorToVisibleCenter()
                requestOlderCandlesIfNeeded(chartWidth: geometry.size.width)
            }
            .onChange(of: gestureState.candleWidthScale) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
                syncChartDrawingPlacementAnchorToVisibleCenter()
            }
            .onChange(of: chartData.candles.count) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
                syncChartDrawingPlacementAnchorToVisibleCenter()
                requestOlderCandlesIfNeeded(chartWidth: geometry.size.width)
                if !gestureState.isUserDrivenScrollActive {
                    refreshDeferredHistoricalPriceRangeIfNeeded(
                        chartWidth: geometry.size.width,
                        chartHeight: geometry.size.height,
                        force: true
                    )
                }
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: gestureState.isUserDrivenScrollActive) { _, isActive in
                guard !isActive else { return }
                refreshDeferredHistoricalPriceRangeIfNeeded(
                    chartWidth: geometry.size.width,
                    chartHeight: geometry.size.height,
                    force: true
                )
            }
            .onChange(of: controlViewModel.isMarkerPlacementMode) { _, _ in
                syncSelectedMarkerGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
                syncChartDrawingPlacementAnchorToVisibleCenter()
            }
            .onChange(of: placementState.activeTool) { _, _ in
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: placementState.activeSubTool) { _, _ in
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: placementState.drawingInteractionPhase) { _, _ in
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: chartDrawingPlacementState.activeTool) { _, _ in
                reconcileDrawingInteractionState()
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: chartDrawingPlacementState.activeSubTool) { _, _ in
                reconcileDrawingInteractionState()
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }
            .onChange(of: chartDrawingPlacementState.selectedPlacementTab) { _, _ in
                reconcileDrawingInteractionState()
            }
            .onChange(of: chartDrawingPlacementState.drawingInteractionPhase) { _, _ in
                reconcileDrawingInteractionState()
                seedInitialDrawingGuidePointIfNeeded(
                    coordinateSystem: coordinateSystem,
                    size: geometry.size
                )
            }

            chartInfoBox(geometry: geometry)
                .zIndex(50)

            // MARK: - On-Chart Placement Mode UI
            if isMarkerPlacementMode {
                // Ghost preview: render placement components (levels, trendlines, zones)
                // on the actual chart canvas using real coordinate mapping
                GhostPreviewLayer(
                    placementState: placementState,
                    yForPrice: { price in coordinateSystem.yPosition(forPrice: price) },
                    width: max(0, geometry.size.width - yAxisWidth),
                    topSafeAreaInset: geometry.safeAreaInsets.top,
                    bottomPanelPadding: bottomInfoPanelsPadding(geometry: geometry),
                    xForTime: { time in
                        guard let index = coordinateSystem.candleIndex(forTimestamp: time) else { return nil }
                        return coordinateSystem.xCenterPosition(forCandleIndex: index)
                    },
                    timeForX: { x in
                        guard let index = coordinateSystem.candleIndex(atXPosition: x) else { return nil }
                        return coordinateSystem.timestamp(forCandleIndex: index)
                    },
                    guidePoint: currentDrawingGuidePoint,
                    drawingInteractionPhase: placementState.drawingInteractionPhase,
                    editingDrawingId: placementState.editingDrawingId,
                    showsInfoPanels: false,
                    formatPrice: { price in compactMainChartPriceLabel(price, chartHeight: geometry.size.height) }
                )
                .mask(plotAreaMask(geometry: geometry))
                .zIndex(30)

                drawingControlHandlesOverlay(
                    geometry: geometry,
                    coordinateSystem: coordinateSystem
                )
                .mask(plotAreaMask(geometry: geometry))
                .zIndex(31)
            }

            if shouldShowDefaultChartDrawingOverlay {
                GhostPreviewLayer(
                    placementState: chartDrawingPlacementState,
                    yForPrice: { price in coordinateSystem.yPosition(forPrice: price) },
                    width: max(0, geometry.size.width - yAxisWidth),
                    topSafeAreaInset: geometry.safeAreaInsets.top,
                    bottomPanelPadding: bottomInfoPanelsPadding(geometry: geometry),
                    xForTime: { time in
                        guard let index = coordinateSystem.candleIndex(forTimestamp: time) else { return nil }
                        return coordinateSystem.xCenterPosition(forCandleIndex: index)
                    },
                    timeForX: { x in
                        guard let index = coordinateSystem.candleIndex(atXPosition: x) else { return nil }
                        return coordinateSystem.timestamp(forCandleIndex: index)
                    },
                    guidePoint: currentDrawingGuidePoint,
                    drawingInteractionPhase: chartDrawingPlacementState.drawingInteractionPhase,
                    editingDrawingId: chartDrawingPlacementState.editingDrawingId,
                    showsInfoPanels: false,
                    formatPrice: { price in compactMainChartPriceLabel(price, chartHeight: geometry.size.height) },
                    suppressEmojiBackground: true
                )
                .mask(plotAreaMask(geometry: geometry))
                .zIndex(26)

                drawingControlHandlesOverlay(
                    geometry: geometry,
                    coordinateSystem: coordinateSystem
                )
                .mask(plotAreaMask(geometry: geometry))
                .zIndex(27)
            }

            if shouldShowSelectedDrawingToolbar {
                selectedDrawingToolbar(geometry: geometry)
                    .zIndex(60)
            } else if !isMarkerPlacementMode && !controlViewModel.isMarkerViewingMode {
                // Standard chart controls — hidden during placement, marker viewing,
                // and while a drawing is actively selected for editing.
                chartControlsBox(geometry: geometry)
                    .zIndex(60)
            }
        }
    }

    @ViewBuilder
    private func interactiveChartLayer(
        geometry: GeometryProxy,
        coordinateSystem: ChartCoordinateSystem,
        predictionPlacementActive: Bool
    ) -> some View {
        ZStack {
            if ThemeManager.shared.currentTheme == .dark {
                LinearGradient(
                    colors: [
                        AppColors.surfaceWhite04,
                        AppColors.surfaceWhite0015
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if ThemeManager.shared.currentTheme == .lightGrey {
                LinearGradient(
                    colors: [
                        AppColors.surfaceBlack10.opacity(0.04),
                        AppColors.surfaceBlack10.opacity(0.015)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Emoji annotations behind candles — non-editing emojis from default chart drawings
            if shouldShowDefaultChartDrawingOverlay {
                chartDrawingEmojiBackgroundLayer(geometry: geometry, coordinateSystem: coordinateSystem)
                    .mask(plotAreaMask(geometry: geometry))
                    .allowsHitTesting(false)
            }

            mainChartCanvas(geometry: geometry)
                .mask(topFadeMask(geometry: geometry))

            if shouldShowMarkerPlacementOverlay,
               !isInteractiveDrawingSessionActive {
                markerPlacementOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                    .mask(alignment: .top) {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: priceIndicatorTopExclusionHeight(geometry: geometry))
                            Rectangle()
                                .fill(Color.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .zIndex(18)
            }

            // Y-axis has no zIndex so document order controls layering (later = on top).
            // Price lines for markers are drawn after the live price chip so Entry/TP/SL stay readable.
            yAxisOverlay(geometry: geometry)

            markerDrawingOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                .mask(plotAreaMask(geometry: geometry))

            // Marker component overlays (trendlines, zones, levels from selected marker)
            // Positioned after drawings but before price lines, labels, and info boxes.
            if !markerOverlayComponents.isEmpty,
               !isInteractiveDrawingSessionActive {
                MarkerComponentOverlayLayer(
                    components: markerOverlayComponents,
                    yForPrice: { price in coordinateSystem.yPosition(forPrice: price) },
                    width: max(0, geometry.size.width - yAxisWidth),
                    xForTime: { time in
                        guard let index = coordinateSystem.candleIndex(forTimestamp: time) else { return nil }
                        return coordinateSystem.xCenterPosition(forCandleIndex: index)
                    },
                    formatPrice: { price in compactMainChartPriceLabel(price, chartHeight: geometry.size.height) },
                    chartHeight: geometry.size.height,
                    topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry)
                )
                .mask(plotAreaMask(geometry: geometry))
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            horizontalDrawingAxisLabelsOverlay(
                geometry: geometry,
                coordinateSystem: coordinateSystem
            )

            if !shouldHideCurrentPriceIndicator {
                priceIndicatorView(geometry: geometry)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(FixedRectClip(rect: priceIndicatorClipRect(geometry: geometry)))
            }

            // Drawn after the live price chip so Entry / TP / SL labels stay visible when prices align.
            //
            // Grouped under a single clip rather than clipped four times: these four were previously
            // masked individually with the *same* rectangle, costing four offscreen passes a frame
            // for one shared cut-out. Document order inside the stack is unchanged, so layering is
            // identical.
            if !isInteractiveDrawingSessionActive {
                ZStack {
                    markerPriceLinesOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                    draggableMarkerLineOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                    draggablePredictionLinesOverlay(geometry: geometry, coordinateSystem: coordinateSystem)
                    targetLineOverlays(coordinateSystem: coordinateSystem, geometry: geometry)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(FixedRectClip(rect: priceLinesFullWidthClipRect(geometry: geometry)))
            }

            markerTopPriorityOverlay()
                .mask(alignment: .top) {
                    markerTopPriorityToolbarMask(geometry: geometry)
                }

            xAxisOverlay(geometry: geometry)

            if let markerIntent = linePlacementOverlayIntent,
               !isInteractiveDrawingSessionActive {
                linePlacementOverlay(
                    markerIntent: markerIntent,
                    geometry: geometry,
                    coordinateSystem: coordinateSystem
                )
                .mask(plotAreaMask(geometry: geometry))
                .zIndex(40)
            }

            if predictionPlacementActive,
               !isInteractiveDrawingSessionActive {
                PredictionPlacementOverlay(
                    placement: $predictionPlacement,
                    draggingLine: $draggingPredictionLine,
                    coordinateSystem: coordinateSystem,
                    renderWidth: geometry.size.width,
                    plotWidth: max(0, geometry.size.width - yAxisWidth),
                    chartHeight: geometry.size.height,
                    chartData: chartData,
                    priceScale: gestureState.priceScale,
                    topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry)
                )
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                .clipShape(FixedRectClip(rect: priceLinesFullWidthClipRect(geometry: geometry)))
                .zIndex(40)
            }

            CrosshairView(
                crosshairManager: crosshairManager,
                chartSize: geometry.size,
                chartData: chartData,
                showsTimeLabelOnMainXAxis: !panelOwnsBottomXAxisStrip,
                indicatorManager: indicatorManager,
                timeframe: chartViewModel.currentTimeframe,
                timeZone: axisTimeZone
            )

            drawingGuideAxisOverlay(geometry: geometry, coordinateSystem: coordinateSystem)

            if shouldShowInstructionBanner {
                instructionBanner(coordinateSystem: coordinateSystem)
            }
        }
    }

    private var linePlacementOverlayIntent: RLMarkerIntent? { nil }

    private var isPredictionPlacementOverlayActive: Bool {
        controlViewModel.isMarkerPlacementMode &&
        controlViewModel.currentMarkerIntent == .setup &&
        predictionPlacement != nil
    }

    private var shouldHideCurrentPriceIndicator: Bool {
        (controlViewModel.isMarkerPlacementMode && controlViewModel.currentMarkerIntent == .setup)
            || isInteractiveDrawingSessionActive
    }

    @ViewBuilder
    private func linePlacementOverlay(
        markerIntent: RLMarkerIntent,
        geometry: GeometryProxy,
        coordinateSystem: ChartCoordinateSystem
    ) -> some View {
        let candle = chartData.candles[effectiveCandleIndex]
        let defaultPrice = placementLinePrice ?? candle.close

        PlacementLineDragOverlay(
            markerIntent: markerIntent,
            defaultPrice: defaultPrice,
            linePrice: $placementLinePrice,
            isDragging: $isDraggingPlacementLine,
            coordinateSystem: coordinateSystem,
            chartWidth: geometry.size.width,
            chartHeight: geometry.size.height,
            chartData: chartData,
            priceScale: gestureState.priceScale,
            topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry)
        )
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
        coordinateSystem.updateLiveState(dragState: dragState, pinchScale: 1.0)
        return coordinateSystem
    }
    
    
    
    
    // MARK: - Indicators
    
    /// Create drawing data for indicators (computed on main thread before Canvas)
    /// UPDATED: Now includes all overlay indicators (BB, VWAP, Donchian, Keltner, SAR)
    private var indicatorDrawingData: IndicatorDrawingData {
        let im = indicatorManager
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
    
    // MARK: - Emoji Background Layer (behind candles)

    @ViewBuilder
    private func chartDrawingEmojiBackgroundLayer(
        geometry: GeometryProxy,
        coordinateSystem: ChartCoordinateSystem
    ) -> some View {
        let emojiDrafts = chartDrawingPlacementState.components.filter {
            $0.componentType == .reactionEmoji
        }
        if !emojiDrafts.isEmpty {
            ZStack {
                ForEach(emojiDrafts) { draft in
                    if case let .reactionEmoji(payload) = draft.payload {
                        let anchorPrice = payload.anchorPrice ?? 0
                        let anchorTime = payload.anchorTime
                        let anchorY = coordinateSystem.yPosition(forPrice: anchorPrice)
                        let anchorX: CGFloat = {
                            guard let time = anchorTime,
                                  let index = coordinateSystem.candleIndex(forTimestamp: time) else {
                                return (geometry.size.width - yAxisWidth) * 0.5
                            }
                            return coordinateSystem.xCenterPosition(forCandleIndex: index)
                        }()
                        let offsetX = CGFloat(payload.offsetX ?? 0)
                        let offsetY = CGFloat(payload.offsetY ?? -68)
                        let x = anchorX + offsetX
                        let y = anchorY + offsetY
                        let isEditing = chartDrawingPlacementState.drawingInteractionPhase == .editing
                            && chartDrawingPlacementState.editingDrawingId == draft.id

                        if x.isFinite, y.isFinite, !isEditing {
                            let scale = chartDrawingPlacementState.emojiScale(for: draft.id)
                            Text(payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🎯" : payload.emoji)
                                .font(.system(size: 24))
                                .scaleEffect(scale)
                                .position(x: x, y: y)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Main Chart Canvas

    @ViewBuilder
    private func mainChartCanvas(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            drawChart(context: context, size: size)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func markerTopPriorityOverlay() -> some View {
        Canvas { context, size in
            drawTopPriorityMarkers(context: context, size: size)
        } symbols: {
            ForEach(MarkerVisualSpec.allSymbolIDs, id: \.tag) { symbolId in
                markerSymbolView(for: symbolId).tag(symbolId.tag)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func markerSymbolView(for symbolId: MarkerSymbolID) -> some View {
        let symbol = MarkerVisualSpec.symbol(for: symbolId.intent, severity: symbolId.alertSeverity)
        let palette = MarkerVisualSpec.palette(for: symbolId.intent, severity: symbolId.alertSeverity)
        let diameter = symbolId.isSelected
            ? MarkerVisualSpec.baseCanvasDiameter * 1.5
            : MarkerVisualSpec.baseCanvasDiameter
        let iconSize = MarkerVisualSpec.iconSize(for: diameter, intent: symbolId.intent)

        if palette.count >= 3 {
            Image(systemName: symbol)
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(palette[0], palette[1], palette[2])
        } else if palette.count == 2 {
            Image(systemName: symbol)
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(palette[0], palette[1])
        } else {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundColor(palette.first ?? MarkerVisualSpec.iconBaseColor)
        }
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
            chartData: chartData,
            latestCandle: chartData.candles.last,
            topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry),
            bottomExclusionHeight: priceIndicatorBottomExclusionHeight(geometry: geometry)
        )
    }

    private func priceIndicatorTopExclusionHeight(geometry: GeometryProxy) -> CGFloat {
        let topInset = geometry.safeAreaInsets.top
        return topInset > 0 ? topInset + 52 : 114
    }

    private func priceIndicatorBottomExclusionHeight(geometry: GeometryProxy) -> CGFloat {
        let panelPadding = chartControlRowPanelReserve
        let controlsBottomPadding = geometry.size.height * 0.085 + 34 + panelPadding
        let controlRowHeight: CGFloat = 28
        return controlsBottomPadding + controlRowHeight
    }
    
    @ViewBuilder
    private func draggableMarkerLineOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        if let marker = activeSelectedMarker,
           shouldAllowSelectedMarkerLevelEditing(marker),
           marker.intent != .setup,
           !marker.levelComponents.isEmpty {
            ForEach(marker.levelComponents) { component in
                if let levelType = component.componentTypeEnum,
                   let price = component.payload.levelPrice {
                    DraggableMarkerLineOverlay(
                        marker: marker,
                        currentPrice: price,
                        levelType: levelType,
                        markerManager: markerManager,
                        coordinateSystem: coordinateSystem,
                        chartWidth: geometry.size.width,
                        chartHeight: geometry.size.height,
                        chartData: chartData
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func draggablePredictionLinesOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        if let marker = activeSelectedMarker,
           shouldAllowSelectedMarkerLevelEditing(marker),
           marker.intent == .setup,
           marker.candleIndex >= 0,
           marker.candleIndex < chartData.candles.count {
            let candle = chartData.candles[marker.candleIndex]
            let entryPrice = marker.horizontalLinePrice ?? marker.linePrice(for: candle) ?? marker.price
            DraggablePredictionLinesOverlay(
                marker: marker,
                entryPrice: entryPrice,
                targetPrice: marker.targetPrice,
                stopLossPrice: marker.stopLossPrice,
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
            chartData: chartData,
            priceScale: gestureState.priceScale,
            topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry),
            isPredictionPlacementActive: isPredictionPlacementOverlayActive
        )
    }

    @ViewBuilder
    private func markerDrawingOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        MarkerDrawingOverlay(
            selectedMarker: activeSelectedMarker,
            coordinateSystem: coordinateSystem,
            chartWidth: max(0, geometry.size.width - yAxisWidth),
            chartHeight: geometry.size.height
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
            chartData: chartData,
            topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry),
            formatPrice: { price in compactMainChartPriceLabel(price, chartHeight: geometry.size.height) }
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
                chartData: chartData,
                topExclusionHeight: priceIndicatorTopExclusionHeight(geometry: geometry),
                formatPrice: { price in compactMainChartPriceLabel(price, chartHeight: geometry.size.height) }
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
        .allowsHitTesting(yAxisGesturesEnabled)
        .onDisappear {
            isDraggingOnYAxis = false
            isPinchingOnYAxis = false
        }
    }

    private var yAxisGesturesEnabled: Bool {
        if isDraggingDrawingControlHandle { return false }
        if isDraggingPlacementLine || draggingPredictionLine != nil {
            return false
        }
        return true
    }
    
    // MARK: - Loading Overlay
    
    @ViewBuilder
    private var loadingOverlayIfNeeded: some View {
        if shouldShowLoadingOverlay {
            loadingOverlay
        } else if shouldShowNoDataOverlay {
            noDataOverlay
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if let session = chartViewModel.markerNavigationSession {
            markerNavigationLoadingOverlay(session: session)
        } else {
            chartLoadingOverlay
        }
    }

    @ViewBuilder
    private func markerNavigationLoadingOverlay(session: MarkerNavigationSession) -> some View {
        let intent = session.target.intent
        let severity = session.target.alertSeverity
        let symbol = MarkerVisualSpec.symbol(for: intent, severity: severity)
        let palette = MarkerVisualSpec.palette(for: intent, severity: severity)
        let accent = palette.first ?? AppColors.primaryForeground
        let title = session.phase.title
        let subtitle = session.phase.subtitle

        ZStack {
            AppColors.surfaceBlack85
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    if session.phase.isLoading {
                        Circle()
                            .stroke(accent.opacity(0.45), lineWidth: 1.4)
                            .frame(width: 68, height: 68)
                            .scaleEffect(markerNavigationPulse ? 1.18 : 0.88)
                            .opacity(markerNavigationPulse ? 0.05 : 0.62)
                            .animation(
                                .easeOut(duration: 1.15).repeatForever(autoreverses: false),
                                value: markerNavigationPulse
                            )

                        Circle()
                            .fill(accent.opacity(0.12))
                            .frame(width: 58, height: 58)
                            .scaleEffect(markerNavigationPulse ? 1.1 : 0.96)
                            .animation(
                                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                                value: markerNavigationPulse
                            )
                    }

                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(MarkerVisualSpec.borderColor(for: intent, severity: severity), lineWidth: 1)
                        )
                        .frame(width: 58, height: 58)
                        .scaleEffect(session.phase.isLoading && markerNavigationPulse ? 1.03 : 1.0)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: markerNavigationPulse
                        )

                    Image(systemName: symbol)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(accent)
                        .scaleEffect(session.phase.isLoading && markerNavigationPulse ? 1.07 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: markerNavigationPulse
                        )
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.primaryForeground)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryForeground)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.surfaceBlack70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.surfaceWhite12, lineWidth: 1)
                    )
            )
        }
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
        .onAppear {
            markerNavigationPulse = false
            DispatchQueue.main.async {
                markerNavigationPulse = true
            }
        }
        .onDisappear {
            markerNavigationPulse = false
        }
    }

    @ViewBuilder
    private var chartLoadingOverlay: some View {
        ZStack {
            AppColors.surfaceBlack85
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primaryForeground))
                    .scaleEffect(1.5)
                
                Text("Loading Chart...")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryForeground)
                
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
                .foregroundColor(AppColors.secondaryForeground)
        } else if chartData.candles.isEmpty {
            Text("Loading candles")
                .font(.caption)
                .foregroundColor(AppColors.secondaryForeground)
        }
    }

    @ViewBuilder
    private var noDataOverlay: some View {
        ZStack {
            AppColors.surfaceBlack85
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(AppColors.primaryForeground)

                Text("Market Data Unavailable")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryForeground)

                Text(noDataSubtitle)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondaryForeground)
                    .frame(maxWidth: 260)

                if chartViewModel.isRetryingChartLoad {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accentColor))
                            .scaleEffect(0.8)
                        Text(chartViewModel.chartRetryAttempt > 0
                             ? "Reconnecting… (attempt \(chartViewModel.chartRetryAttempt))"
                             : "Reconnecting…")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryForeground)
                    }
                    .padding(.top, 2)
                }

                Button {
                    Task { await chartViewModel.retryChartDataLoad(reason: "manual") }
                } label: {
                    Text("Try Again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(AppColors.accentColor))
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
        .transition(.opacity.animation(.easeOut(duration: 0.3)))
        .animation(.easeInOut(duration: 0.2), value: chartViewModel.isRetryingChartLoad)
    }

    private var noDataSubtitle: String {
        if APIEnvironment.current == .production {
            return "Live candles are unavailable for this symbol right now in public beta. Please try again shortly."
        }
        return "No candles are available for this symbol yet."
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
        AppColors.surfaceBlack40
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
                    .foregroundColor(AppColors.statusWarning)
                
                Text("Marker Exists")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("A \(markerManager.duplicateMarkerToLike?.intent.displayName.lowercased() ?? "marker") already exists on this candle. Would you like to like it instead?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondaryForeground)
                    .padding(.horizontal)
                
                duplicateMarkerButtons
            }
            .padding(30)
            .background(AppColors.duplicateDialogCardBackground)
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
                .foregroundColor(AppColors.onAccentForeground)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.statusInfo)
                .cornerRadius(12)
            }
            
            Button(action: handleDismissDuplicateAlert) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(AppColors.statusInfo)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.duplicateDialogSecondaryButtonFill)
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
                .foregroundColor(AppColors.secondaryForeground)
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

            if let placementSubmitErrorMessage, !placementSubmitErrorMessage.isEmpty {
                Text(placementSubmitErrorMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.statusNegative85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let instruction = placementState.toolbarInstructionText {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Image(systemName: placementState.activeDrawingWorkflowTool?.icon ?? "pencil.and.ruler")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(placementState.intent.color)

                        Text(instruction)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.primaryForeground)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let detail = placementState.toolbarInstructionDetailText {
                        Text(detail)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.secondaryForeground)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: 260, alignment: .leading)
                .background(AppColors.chartPanelBackgroundAlt.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Prediction info box (right-aligned)
            if let state = predictionPlacement,
               controlViewModel.currentMarkerIntent == .setup {
                predictionInfoBox(state: state)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    AppColors.chartPanelBackground.opacity(0.95),
                    AppColors.chartPanelBackground.opacity(0.7)
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
                    .foregroundColor(AppColors.secondaryForeground)
                Text(String(format: "%.2f", state.riskRewardRatio))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.primaryForeground)
            }

            // Profit %
            VStack(alignment: .leading, spacing: 1) {
                Text("Profit")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AppColors.secondaryForeground)
                Text(String(format: "+%.2f%%", state.potentialProfitPercent))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.statusPositive)
            }

            // Risk %
            VStack(alignment: .leading, spacing: 1) {
                Text("Risk")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AppColors.secondaryForeground)
                Text(String(format: "-%.2f%%", state.potentialLossPercent))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.statusNegative)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.chartPanelBackgroundAlt.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: state.takeProfitPrice)
        .animation(.easeInOut(duration: 0.15), value: state.stopLossPrice)
    }

    @ViewBuilder
    private var cancelPlacementButton: some View {
        Button(action: handleCancelPlacement) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.onAccentForeground)
                .frame(width: 36, height: 36)
                .background(AppColors.statusNegative70)
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
            .foregroundColor(AppColors.onAccentForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.statusWarning70)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func placeMarkerButton(coordinateSystem: ChartCoordinateSystem) -> some View {
        let actionLabel = placementState.isEditingExistingMarker ? "Save Changes" : "Place Marker"
        let activeColor = placementActionColor
        let hasSelectedAlertSeverity = placementState.intent == .alert && placementPreviewAlertSeverity != nil
        let showsMarkerColor = placementState.isValid || hasSelectedAlertSeverity
        let activeOpacity: Double = placementState.isValid ? 0.96 : 0.58
        let secondaryOpacity: Double = placementState.isValid ? 0.74 : 0.36
        Button(action: { handlePlaceMarkerPress(coordinateSystem: coordinateSystem) }) {
            HStack(spacing: 6) {
                if isSubmittingPlacement {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppColors.onAccentForeground)
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: placementState.isEditingExistingMarker ? "checkmark.circle.fill" : "target")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(actionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(showsMarkerColor ? AppColors.onAccentForeground : AppColors.whiteText.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 122)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            showsMarkerColor
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: placementState.isEditingExistingMarker
                                            ? [
                                                AppColors.statusPositive70.opacity(0.96),
                                                AppColors.statusPositive70.opacity(0.74),
                                              ]
                                            : [
                                                activeColor.opacity(activeOpacity),
                                                activeColor.opacity(secondaryOpacity),
                                              ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(AppColors.gradientBackgroundMid.opacity(0.9))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            showsMarkerColor
                                ? (placementState.isEditingExistingMarker
                                    ? AppColors.statusPositive70.opacity(0.72)
                                    : activeColor.opacity(placementState.isValid ? 0.72 : 0.48))
                                : AppColors.whiteText.opacity(0.16),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!placementState.isValid || isSubmittingPlacement)
        .opacity(placementState.isValid || hasSelectedAlertSeverity ? 1.0 : 0.5)
    }
    
    // MARK: - Marker Placement Overlay
    
    @ViewBuilder
    private func markerPlacementOverlay(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        let xAxisReservedHeight = xAxisReservedBandHeight(
            chartHeight: geometry.size.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        let plotWidth = max(0, geometry.size.width - yAxisWidth)
        let plotHeight = max(0, geometry.size.height - xAxisReservedHeight)
        let maskWidth = markerDragPosition == nil ? plotWidth : geometry.size.width
        let maskHeight = markerDragPosition == nil ? plotHeight : geometry.size.height

        ZStack {
            if !placementState.isEditingExistingMarker,
               effectiveCandleIndex >= 0 && effectiveCandleIndex < chartData.candles.count {
                previewMarkerView(geometry: geometry, coordinateSystem: coordinateSystem)
            }
        }
        .mask(alignment: .topLeading) {
            Rectangle()
                .frame(width: maskWidth, height: maskHeight)
        }
        .onAppear {
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onChange(of: effectiveCandleIndex) { _, _ in
            updatePlacementGuideState(geometry: geometry, coordinateSystem: coordinateSystem)
        }
        .onChange(of: controlViewModel.currentMarkerIntent) { _, _ in
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
    private func previewMarkerView(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) -> some View {
        let snapPosition = previewMarkerSnapPosition(coordinateSystem: coordinateSystem)
        let displayPosition = markerDragPosition ?? snapPosition
        let markerX = displayPosition?.x
        let markerY = displayPosition?.y

        if let markerX,
           let markerY,
           markerX.isFinite,
           markerY.isFinite,
           markerDragPosition != nil || (markerX >= -50 && markerX <= geometry.size.width + 50) {
            previewMarkerContent(x: markerX, y: markerY, coordinateSystem: coordinateSystem)
        }
    }

    private func previewMarkerSnapPosition(coordinateSystem: ChartCoordinateSystem) -> CGPoint? {
        guard effectiveCandleIndex >= 0,
              effectiveCandleIndex < chartData.candles.count else {
            return nil
        }

        let candle = chartData.candles[effectiveCandleIndex]
        let snapX = coordinateSystem.xCenterPosition(forCandleIndex: effectiveCandleIndex)
        let candleHighY = coordinateSystem.yPosition(forPrice: candle.high)
        let candleLowY = coordinateSystem.yPosition(forPrice: candle.low)
        let viewportHeight = max(0, chartSize.height - xAxisReservedBandHeight(
            chartHeight: chartSize.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        ))

        let (snapPosition, _) = MarkerPositionCalculator.calculatePreviewPosition(
            candleIndex: effectiveCandleIndex,
            existingMarkers: markerManager.filteredMarkers,
            candles: chartData.candles,
            candleHighY: candleHighY,
            candleLowY: candleLowY,
            centerX: snapX,
            priceScale: gestureState.priceScale,
            viewportHeight: viewportHeight
        )

        guard snapPosition.x.isFinite, snapPosition.y.isFinite else { return nil }
        return snapPosition
    }
    
    @ViewBuilder
    private func previewMarkerContent(x: CGFloat, y: CGFloat, coordinateSystem: ChartCoordinateSystem) -> some View {
        let markerIntent = effectiveMarkerIntent ?? .analysis
        let displayColor = markerPreviewDisplayColor(for: markerIntent)
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 92, height: 92)
                .contentShape(Circle())

            UnifiedMarkerBadge(
                intent: markerIntent,
                displayColor: displayColor,
                alertSeverity: markerIntent == .alert ? placementPreviewAlertSeverity : nil,
                sizeToken: .large,
                emoji: markerIntent == .reaction ? placementPreviewReactionEmoji : nil,
                isSelected: true
            )
        }
        .position(x: x, y: y)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMarkerBeingDragged)
        .gesture(
            previewMarkerDragGesture(coordinateSystem: coordinateSystem),
            including: placementState.isEditingExistingMarker ? .none : .all
        )
    }

    private func markerPreviewDisplayColor(for intent: RLMarkerIntent) -> Color {
        guard intent == .alert else { return intent.color }
        return placementPreviewAlertSeverity?.color ?? intent.color
    }

    private var placementGuideLineColor: Color {
        guard let intent = gestureState.markerPlacementGuide.markerIntent else {
            return AppColors.statusInfo50
        }

        if intent == .alert {
            switch gestureState.markerPlacementGuide.source {
            case .placement:
                return placementPreviewAlertSeverity?.color ?? intent.color
            case .selected:
                return markerManager.selectedMarker?.alertSeverity?.color ?? intent.color
            }
        }

        return intent.color
    }

    private var placementPreviewAlertSeverity: MarkerAlertSeverity? {
        if let selected = placementState.alertSeverity {
            return selected
        }

        let trimmedNote = placementState.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNote.hasPrefix("[Critical] ") { return .critical }
        if trimmedNote.hasPrefix("[Severe] ") { return .severe }
        if trimmedNote.hasPrefix("[Warning] ") { return .moderate }
        if trimmedNote.hasPrefix("[Informational] ") { return .mild }
        return nil
    }

    private var placementPreviewReactionEmoji: String {
        if case let .reactionEmoji(payload)? = placementState.component(.reactionEmoji)?.payload {
            let emoji = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
            if !emoji.isEmpty {
                return emoji
            }
        }
        return "🎯"
    }

    private var placementActionColor: Color {
        guard placementState.intent == .alert else {
            return placementState.intent.color
        }
        return placementPreviewAlertSeverity?.color ?? placementState.intent.color
    }

    /// Compute a placement-guide x from a candle index using the live pan
    /// offset. Mirrors `ChartCoordinateSystem.xCenterPosition(forCandleIndex:)`
    /// without the `dragState`/`pinchScale` fields (the chart's pan path
    /// commits directly to `panOffset`, so dragState is always zero here).
    private func liveGuideXPosition(forCandleIndex index: Int) -> CGFloat? {
        guard index >= 0 else { return nil }
        let total = totalCandleWidth
        guard total > 0 else { return nil }
        let baseX = CGFloat(index - chartData.historicalRenderIndexOffset) * total
        return baseX + gestureState.panOffset.width + actualCandleWidth / 2
    }

    private func updatePlacementGuideState(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) {
        guard !isInteractiveDrawingSessionActive else {
            applyPlacementGuideState(MarkerPlacementGuideState())
            return
        }

        guard effectiveCandleIndex >= 0,
              effectiveCandleIndex < chartData.candles.count,
              let markerIntent = effectiveMarkerIntent else {
            applyPlacementGuideState(MarkerPlacementGuideState())
            return
        }

        let candle = chartData.candles[effectiveCandleIndex]
        let x = coordinateSystem.xCenterPosition(forCandleIndex: effectiveCandleIndex)
        guard x.isFinite else {
            applyPlacementGuideState(MarkerPlacementGuideState())
            return
        }
        let isVisible = x >= -50 && x <= geometry.size.width + 50

        applyPlacementGuideState(MarkerPlacementGuideState(
            isActive: isVisible,
            x: x,
            candleIndex: effectiveCandleIndex,
            timestamp: candle.timestamp,
            markerIntent: markerIntent,
            source: .placement
        ))
    }

    private func triggerChartMarkerWiggle() {
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { selectionRotation = 8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { selectionRotation = -6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) { selectionRotation = 4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { selectionRotation = -2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.14, dampingFraction: 0.6)) { selectionRotation = 0 }
        }
    }

    private func syncSelectedMarkerGuideState(geometry: GeometryProxy, coordinateSystem: ChartCoordinateSystem) {
        syncSelectedMarkerGuideState(
            chartWidth: geometry.size.width,
            coordinateSystem: coordinateSystem
        )
    }

    private func syncSelectedMarkerGuideState(chartWidth: CGFloat, coordinateSystem: ChartCoordinateSystem) {
        guard !isInteractiveDrawingSessionActive else {
            applyPlacementGuideState(MarkerPlacementGuideState())
            return
        }

        guard !isMarkerPlacementMode else { return }
        guard controlViewModel.isMarkerViewingMode else {
            if gestureState.markerPlacementGuide.source == .selected {
                applyPlacementGuideState(MarkerPlacementGuideState())
            }
            return
        }

        guard let selectedMarker = markerManager.selectedMarker,
              chartData.candles.indices.contains(selectedMarker.candleIndex) else {
            if gestureState.markerPlacementGuide.source == .selected {
                applyPlacementGuideState(MarkerPlacementGuideState())
            }
            return
        }

        let candle = chartData.candles[selectedMarker.candleIndex]
        let x = coordinateSystem.xCenterPosition(forCandleIndex: selectedMarker.candleIndex)
        guard x.isFinite else {
            applyPlacementGuideState(MarkerPlacementGuideState())
            return
        }
        let isVisible = x >= -50 && x <= chartWidth + 50
        applyPlacementGuideState(MarkerPlacementGuideState(
            isActive: isVisible,
            x: x,
            candleIndex: selectedMarker.candleIndex,
            timestamp: candle.timestamp,
            markerIntent: selectedMarker.intent,
            source: .selected
        ))
    }

    private func applyPlacementGuideState(_ newState: MarkerPlacementGuideState) {
        guard !newState.isActive || (newState.x.isFinite && newState.timestamp != nil) else {
            if gestureState.markerPlacementGuide.isActive {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
            return
        }

        let current = gestureState.markerPlacementGuide

        // Skip tiny x-only deltas to reduce per-frame guide churn while panning.
        if current.source == newState.source,
           current.isActive == newState.isActive,
           current.timestamp == newState.timestamp,
           current.markerIntent == newState.markerIntent,
           abs(current.x - newState.x) < 1.5 {
            return
        }

        if current != newState {
            gestureState.markerPlacementGuide = newState
        }
    }

    private func previewMarkerDragGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard !placementState.isEditingExistingMarker else { return }
                guard effectiveMarkerIntent != .setup else { return }
                let dragStart = markerDragStartPosition
                    ?? markerDragPosition
                    ?? previewMarkerSnapPosition(coordinateSystem: coordinateSystem)
                guard let dragStart else { return }

                if !isMarkerBeingDragged {
                    isMarkerBeingDragged = true
                    markerDragStartPosition = dragStart
                    impactFeedback.impactOccurred()
                }

                let chartLocation = CGPoint(
                    x: dragStart.x + value.translation.width,
                    y: dragStart.y + value.translation.height
                )
                markerDragPosition = chartLocation
                let boundedChartLocation = boundedPreviewDragLocation(chartLocation)

                let resolvedPreviewIndex = MarkerPlacementPreviewDragResolver.resolvedPreviewIndex(
                    isEditingExistingMarker: placementState.isEditingExistingMarker,
                    currentIndex: previewCandleIndex,
                    candidateIndex: nearestMarkerCandleIndex(atXPosition: boundedChartLocation.x),
                    candleCount: chartData.candles.count
                )
                if resolvedPreviewIndex != previewCandleIndex {
                    previewCandleIndex = resolvedPreviewIndex
                }
            }
            .onEnded { value in
                guard !placementState.isEditingExistingMarker else { return }
                isMarkerBeingDragged = false
                let dragEnd = markerDragPosition
                    ?? markerDragStartPosition.map {
                        CGPoint(
                            x: $0.x + value.translation.width,
                            y: $0.y + value.translation.height
                        )
                    }
                if let dragEnd {
                    persistPreviewMarkerDragIfNeeded(
                        location: boundedPreviewDragLocation(dragEnd),
                        coordinateSystem: coordinateSystem
                    )
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    markerDragPosition = nil
                }
                markerDragStartPosition = nil
            }
    }
    
    // MARK: - Button Action Handlers
    
    private func handleConfirmTargetPress(coordinateSystem: ChartCoordinateSystem) {
        // With inline placement mode, confirming a target price now updates the
        // placementState's TP component rather than opening a modal sheet.
        guard let targetPrice = predictionTargetPrice else { return }
        placementState.upsertComponent(
            .levelTp,
            payload: .levelTp(LevelPayload(price: targetPrice, label: "TP"))
        )
        isAwaitingTargetSelection = false
        impactFeedback.impactOccurred()
    }
    
    private func handlePlaceMarkerPress(coordinateSystem: ChartCoordinateSystem) {
        // With inline placement mode, this now delegates to placeMarkerFromState().
        // The user finalizes via the on-chart MarkerPlacementPanel "Place Marker" button.
        placeMarkerFromState()
    }
    
    private func handleCancelPlacement() {
        withAnimation {
            controlViewModel.isMarkerPlacementMode = false
            isMarkerBeingDragged = false
            markerDragPosition = nil
            markerDragStartPosition = nil
            isAwaitingTargetSelection = false
            predictionTargetPrice = nil
            isDraggingTarget = false
            placementLinePrice = nil
            isDraggingPlacementLine = false
            predictionPlacement = nil
            draggingPredictionLine = nil
            placementState.setDrawingPanLocked(false)
            didEvaluateDrawingPanLockForCurrentDrag = false
            isSubmittingPlacement = false
            placementSubmitErrorMessage = nil
            placementState.clearMarkerEditSession()
            if gestureState.markerPlacementGuide.source == .placement {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
        }
    }

    private func presentPlacementFailure(_ failure: MarkerPlacementFailure) {
        placementSubmitErrorMessage = failure.userMessage
        chartViewModel.showPlacementFailure(failure)
    }
    
    /// Place a marker using the on-chart placement state.
    /// Builds an RLCreateMarkerRequest from placementState and calls the API.
    @MainActor
    private func placeMarkerFromState() {
        guard !isSubmittingPlacement else { return }
        guard placementState.isValid,
              let symbolId = chartData.currentSymbol?.id else { return }

        isSubmittingPlacement = true
        placementSubmitErrorMessage = nil

        if let editingMarkerId = placementState.editingMarkerId {
            let updateRequest = placementState.buildUpdateRequest()
            Task { @MainActor in
                let result = await markerManager.updateMarkerFromPlacement(
                    id: editingMarkerId,
                    request: updateRequest
                )
                isSubmittingPlacement = false

                switch result {
                case .success:
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        placementState.clearMarkerEditSession()
                        controlViewModel.cancelMarkerPlacement()
                    }
                    impactFeedback.impactOccurred()
                case .failure(let failure):
                    presentPlacementFailure(failure)
                }
            }
            return
        }

        if placementState.intent == .setup,
           let lastCandle = chartData.candles.last {
            placementState.upsertComponent(
                .anchor,
                payload: .anchor(AnchorPayload(time: lastCandle.timestamp, price: lastCandle.close))
            )
            placementState.upsertComponent(
                .levelEntry,
                payload: .levelEntry(LevelPayload(price: lastCandle.close, label: "Entry"))
            )
        }

        let request = placementState.buildCreateRequest(
            symbolId: symbolId,
            timeframe: chartViewModel.currentTimeframe.toBackendString()
        )
        let fallbackCandleIndex = effectiveCandleIndex
        let candleIdx = optimisticCandleIndex(from: request, fallback: fallbackCandleIndex)

        Task { @MainActor in
            let result = await markerManager.addMarkerV2(
                request: request,
                candleIndex: candleIdx,
                candles: chartData.candles
            )
            isSubmittingPlacement = false

            switch result {
            case .success(let created):
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    controlViewModel.cancelMarkerPlacement()
                }
                impactFeedback.impactOccurred()
                if let created, created.visibility == "guild" {
                    // Presented by MainView (above the persistent chart bottom sheet);
                    // a sheet from here would contend with that one and flood the log.
                    let shareContext = MarkerShareContext(
                        marker: created,
                        symbolTicker: chartViewModel.currentSymbol?.ticker,
                        isCurrentUserMarker: true
                    )
                    NotificationCenter.default.post(
                        name: .presentMarkerSharePrompt,
                        object: nil,
                        userInfo: [MarkerSharePromptNotification.contextKey: shareContext]
                    )
                }
            case .failure(let failure):
                presentPlacementFailure(failure)
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

    private func applyMarkerOverlay(_ marker: ChartMarkerUI) {
        // Store the marker's components for on-chart overlay rendering
        markerOverlayComponents = marker.components
    }

    private func clearMarkerOverlay() {
        markerOverlayComponents = []
    }

    private func handleViewingPollVote(markerId: UUID, optionId: UUID) {
        guard !isSubmittingViewingPollVote else { return }
        isSubmittingViewingPollVote = true
        viewingPollVoteOptionId = optionId

        Task {
            defer {
                isSubmittingViewingPollVote = false
                viewingPollVoteOptionId = nil
            }

            do {
                try await markerManager.voteOnPoll(markerId: markerId, optionId: optionId)
                HapticFeedback.light.trigger()
            } catch {
                print("Failed to vote on poll marker: \(error)")
            }
        }
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleOnAppear() {
        syncMarkerContext()
        setupControlActions()
        chartViewModel.markerManager = markerManager
        chartViewModel.observeMarkerSelection()
        markerManager.configureRealTime(dataManager: chartData)
        isChartLoading = chartViewModel.currentSymbol == nil || chartData.candles.isEmpty
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            initializeLatestPositionIfNeeded()
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
            // Prefer crosshair's target candle if active, otherwise fall back to center
            let preferredIndex: Int
            if crosshairManager.isActive,
               let targetCandle = crosshairManager.targetCandle,
               let idx = chartData.candles.firstIndex(where: { $0.timestamp == targetCandle.timestamp }) {
                preferredIndex = idx
            } else {
                preferredIndex = calculateCenterCandleIndex()
            }

            previewCandleIndex = MarkerPlacementPreviewIndexResolver.fixedPreviewIndex(
                currentPreviewIndex: preferredIndex,
                centerIndex: calculateCenterCandleIndex(),
                candleCount: chartData.candles.count
            )
            placementState.setDrawingPanLocked(false)
            didEvaluateDrawingPanLockForCurrentDrag = false
            placementSubmitErrorMessage = nil

            if placementState.isEditingExistingMarker {
                isMarkerBeingDragged = false
                markerDragPosition = nil
                markerDragStartPosition = nil
                if let editingMarker = markerManager.markers.first(where: { $0.id == placementState.editingMarkerId }) {
                    if let index = chartData.candles.firstIndex(where: { $0.timestamp == editingMarker.candleTimestamp }) {
                        previewCandleIndex = index
                    } else if chartData.candles.indices.contains(editingMarker.candleIndex) {
                        previewCandleIndex = editingMarker.candleIndex
                    }
                }
            } else {
                // Initialize the on-chart placement state with anchor at the selected candle
                initializePlacementState()

                // For prediction markers: immediately initialize 3-line system
                if controlViewModel.currentMarkerIntent == .setup {
                    initializePredictionPlacement()
                }
            }
        } else if oldValue && !newValue {
            // Exiting placement mode - reset to invalid index
            previewCandleIndex = -1
            markerDragPosition = nil
            markerDragStartPosition = nil
            placementState.resetDrawingInteraction()
            placementState.clearMarkerEditSession()
            liveDrawingGuidePoint = nil
            clearDrawingGuideDragState()
            placementState.setDrawingPanLocked(false)
            didEvaluateDrawingPanLockForCurrentDrag = false
            isSubmittingPlacement = false
            placementSubmitErrorMessage = nil
            if gestureState.markerPlacementGuide.source == .placement {
                gestureState.markerPlacementGuide = MarkerPlacementGuideState()
            }
        }
    }

    private func handlePlacementIntentChange(oldIntent: RLMarkerIntent, newIntent: RLMarkerIntent) {
        guard oldIntent != newIntent else { return }
        guard controlViewModel.isMarkerPlacementMode else { return }

        if controlViewModel.currentMarkerIntent != newIntent {
            controlViewModel.currentMarkerIntent = newIntent
        }

        if newIntent == .setup {
            if predictionPlacement == nil {
                initializePredictionPlacement()
            }
            return
        }

        predictionPlacement = nil
        draggingPredictionLine = nil
        isAwaitingTargetSelection = false
        predictionTargetPrice = nil
        isDraggingTarget = false
    }

    /// Initialize the on-chart placement state from the current chart context.
    /// Sets the anchor at the visible center candle with current close price.
    private func initializePlacementState() {
        let intent = controlViewModel.currentMarkerIntent ?? .analysis
        let centerIdx = effectiveCandleIndex
        let candles = chartData.candles

        let anchorTime: Date
        let anchorPrice: Double
        if centerIdx >= 0 && centerIdx < candles.count {
            let candle = candles[centerIdx]
            anchorTime = candle.timestamp
            anchorPrice = candle.close
        } else if let lastCandle = candles.last {
            anchorTime = lastCandle.timestamp
            anchorPrice = lastCandle.close
        } else {
            anchorTime = Date()
            anchorPrice = 0
        }

        placementState.reset(to: intent, anchorTime: anchorTime, anchorPrice: anchorPrice)

        // For setup markers, pre-populate Entry/TP/SL levels
        if intent == .setup {
            placementState.upsertComponent(
                .levelEntry,
                payload: .levelEntry(LevelPayload(price: anchorPrice, label: "Entry"))
            )
            let tpPrice = anchorPrice * 1.01
            let slPrice = anchorPrice * 0.99
            placementState.upsertComponent(
                .levelTp,
                payload: .levelTp(LevelPayload(price: tpPrice, label: "TP"))
            )
            placementState.upsertComponent(
                .levelSl,
                payload: .levelSl(LevelPayload(price: slPrice, label: "SL"))
            )
            placementState.trackingEnabled = true
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
        guard let lastIndex = snappedMarkerCandleIndex(from: chartData.candles.count - 1) else { return }
        let lastCandle = chartData.candles[lastIndex]
        let entryPrice = lastCandle.close
        let priceRange = chartData.priceRange.max - chartData.priceRange.min

        predictionPlacement = PredictionPlacementState(
            entryPrice: entryPrice,
            takeProfitPrice: entryPrice + priceRange * 0.05,
            stopLossPrice: entryPrice - priceRange * 0.03,
            candleIndex: lastIndex
        )

        syncSetupComponentsFromPredictionPlacement()

        // Auto-scroll to latest candle with smooth animation
        gestureState.animateCenterOnMarker(
            at: lastIndex,
            chartWidth: chartSize.width > 0 ? chartSize.width : PlatformScreen.bounds.width,
            candleWidth: totalCandleWidth,
            price: entryPrice,
            chartHeight: chartSize.height > 0 ? chartSize.height : PlatformScreen.bounds.height * 0.6,
            priceRange: chartData.priceRange,
            historicalRenderIndexOffset: chartData.historicalRenderIndexOffset
        )
    }

    private func syncSetupComponentsFromPredictionPlacement() {
        guard controlViewModel.isMarkerPlacementMode,
              placementState.intent == .setup,
              let prediction = predictionPlacement,
              !isSyncingSetupPlacementState else {
            return
        }

        let epsilon = 0.0000001
        isSyncingSetupPlacementState = true
        defer { isSyncingSetupPlacementState = false }

        let entry = placementState.componentPrice(.levelEntry)
            ?? placementState.setupEntryPrice
            ?? .zero
        if abs(entry - prediction.entryPrice) > epsilon {
            placementState.upsertComponent(
                .levelEntry,
                payload: .levelEntry(LevelPayload(price: prediction.entryPrice, label: "Entry"))
            )
        }

        let tp = placementState.componentPrice(.levelTp) ?? .zero
        if abs(tp - prediction.takeProfitPrice) > epsilon {
            placementState.upsertComponent(
                .levelTp,
                payload: .levelTp(LevelPayload(price: prediction.takeProfitPrice, label: "TP"))
            )
        }

        let sl = placementState.componentPrice(.levelSl) ?? .zero
        if abs(sl - prediction.stopLossPrice) > epsilon {
            placementState.upsertComponent(
                .levelSl,
                payload: .levelSl(LevelPayload(price: prediction.stopLossPrice, label: "SL"))
            )
        }
    }

    private func syncPredictionPlacementFromSetupComponents() {
        guard controlViewModel.isMarkerPlacementMode,
              placementState.intent == .setup,
              !isSyncingSetupPlacementState,
              var prediction = predictionPlacement else {
            return
        }

        let targetTP = placementState.componentPrice(.levelTp) ?? prediction.takeProfitPrice
        let targetSL = placementState.componentPrice(.levelSl) ?? prediction.stopLossPrice
        let epsilon = 0.0000001
        let tpChanged = abs(targetTP - prediction.takeProfitPrice) > epsilon
        let slChanged = abs(targetSL - prediction.stopLossPrice) > epsilon

        guard tpChanged || slChanged else { return }

        isSyncingSetupPlacementState = true
        prediction.takeProfitPrice = targetTP
        prediction.stopLossPrice = targetSL
        predictionPlacement = prediction
        isSyncingSetupPlacementState = false
    }
    
    private func handleSymbolChange(oldValue: RLTradingSymbolDTO?, newValue: RLTradingSymbolDTO?) {
        if oldValue == nil && newValue != nil && !chartData.candles.isEmpty {
            if !hasInitializedPosition {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializeLatestPositionIfNeeded()
                }
            }
        }
        indicatorManager.recalculateIndicators(candles: chartData.candles)
    }
    
    private func handleSymbolStringChange(oldValue: String?, newValue: String?) {
        if oldValue != newValue && oldValue != nil {
            hasInitializedPosition = false
            isChartLoading = true
            if !chartViewModel.isNavigatingToMarker {
                markerManager.clearMarkers()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    initializeLatestPositionIfNeeded()
                    Task {
                        await loadMarkersFromAPI()
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isChartLoading = false
                }
            }
        }
    }
    
    private func handleTimeframeChange(oldValue: RLChartTimeframe, newValue: RLChartTimeframe) {
        if oldValue != newValue {
            hasInitializedPosition = false
            isChartLoading = true
            markerManager.clearMarkers()
            // While a marker-panel navigation is in flight, MarkerNavigationHelper owns the
            // scroll position and will reload markers itself. Skipping the snap-to-latest reset
            // prevents the chart from jumping to the right edge before navigation can land.
            if !chartViewModel.isNavigatingToMarker {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    initializeLatestPositionIfNeeded()
                    Task {
                        await loadMarkersFromAPI()
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isChartLoading = false
                }
            }
        }
        indicatorManager.recalculateIndicators(candles: chartData.candles)
    }

    private func handleCandleCountChange(oldCount: Int, newCount: Int) {
        let historicalPrependedCount = chartData.consumeLastPrependedCandleCount()
        if historicalPrependedCount > 0 {
            return
        }

        let didInitializePosition = initializeLatestPositionIfNeeded()

        // Skip the auto-snap-to-latest while marker navigation is in flight - otherwise a fresh
        // batch of candles arriving during navigation kills the centering animation.
        if !didInitializePosition,
           abs(newCount - oldCount) > 10,
           !chartViewModel.isNavigatingToMarker {
            resetChartToMostRecentCandles()
        }
        if newCount != oldCount {
            indicatorManager.recalculateIndicators(candles: chartData.candles)
        }

        // Keep prediction placement pinned to latest candle
        if var state = predictionPlacement,
           controlViewModel.currentMarkerIntent == .setup,
           newCount > 0 {
            guard let lastIndex = snappedMarkerCandleIndex(from: chartData.candles.count - 1) else {
                predictionPlacement = nil
                return
            }
            let lastCandle = chartData.candles[lastIndex]
            state.candleIndex = lastIndex
            state.entryPrice = lastCandle.close
            predictionPlacement = state
        }
    }
    
    // MARK: - Helper Functions

    private func requestOlderCandlesIfNeeded(chartWidth: CGFloat, allowWithoutUserScroll: Bool = false) {
        guard chartViewModel.hasMoreHistoricalCandles,
              !chartViewModel.isLoadingOlderCandles,
              !chartViewModel.isNavigatingToMarker,
              chartViewModel.markerNavigationSession == nil,
              !isChartLoading,
              (allowWithoutUserScroll || gestureState.isUserDrivenScrollActive),
              !chartData.candles.isEmpty,
              totalCandleWidth > 0,
              chartWidth > 0 else {
            return
        }

        // Pagination must only be driven by the user moving toward older candles. Lifecycle,
        // layout, and reset animations can also change panOffset; letting those request history
        // starts a visible page-load cascade on app open.
        guard !isProgrammaticScroll else { return }
        if Date() < suppressHistoricalPreloadUntil, markerManager.selectedMarker != nil {
            return
        }

        if !allowWithoutUserScroll {
            let now = Date()
            guard now.timeIntervalSince(lastHistoricalPreloadCheckAt) >= 0.08 else { return }
            lastHistoricalPreloadCheckAt = now
        }

        let visibleStartIndex = visibleStartIndexForCurrentOffset()
        let visibleCandleCount = max(1, Int(ceil(chartWidth / totalCandleWidth)))
        guard HistoricalPreloadPolicy.shouldPreload(
            visibleStartIndex: visibleStartIndex,
            visibleCandleCount: visibleCandleCount,
            hasMoreHistoricalCandles: chartViewModel.hasMoreHistoricalCandles
        ) else { return }

        Task { @MainActor in
            await chartViewModel.loadOlderCandlesIfNeeded(
                visibleStartIndex: visibleStartIndex,
                visibleCandleCount: visibleCandleCount,
                reason: .viewport
            )
        }
    }

    private func suppressHistoricalPreloadBriefly(duration: TimeInterval = 3.0) {
        suppressHistoricalPreloadUntil = Date().addingTimeInterval(duration)
    }

    private func olderEdgeGuardCandleCount(chartWidth: CGFloat) -> Int {
        guard chartViewModel.hasMoreHistoricalCandles,
              chartWidth > 0,
              totalCandleWidth > 0,
              !chartData.candles.isEmpty else {
            return 0
        }

        let visibleCandleCount = max(1, Int(ceil(chartWidth / totalCandleWidth)))
        return HistoricalPreloadPolicy.edgeGuardCandleCount(
            visibleCandleCount: visibleCandleCount,
            candleCount: chartData.candles.count,
            hasMoreHistoricalCandles: chartViewModel.hasMoreHistoricalCandles
        )
    }

    private func refreshDeferredHistoricalPriceRangeIfNeeded(
        chartWidth: CGFloat,
        chartHeight: CGFloat? = nil,
        force: Bool = false
    ) {
        guard chartData.hasDeferredHistoricalPriceRangeUpdate,
              chartWidth > 0,
              totalCandleWidth > 0 else {
            return
        }

        let visibleStartIndex = visibleStartIndexForCurrentOffset()
        let visibleCandleCount = max(1, Int(ceil(chartWidth / totalCandleWidth)))
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + visibleCandleCount)
        let isViewingDeferredHistoricalCandles = visibleStartIndex < chartData.historicalRenderIndexOffset
            && visibleEndIndex > 0

        guard force || isViewingDeferredHistoricalCandles else {
            return
        }

        let effectiveHeight = chartHeight ?? (chartSize.height > 0 ? chartSize.height : PlatformScreen.bounds.height * 0.55)
        updateHistoricalPriceRangePreservingVerticalPosition(
            anchorPrice: visibleCenterPriceForCurrentOffset(chartWidth: chartWidth),
            chartHeight: effectiveHeight
        ) {
            chartData.focusVisibleHistoricalPriceRangeIfNeeded(
                visibleStartIndex: visibleStartIndex,
                visibleCandleCount: visibleCandleCount
            )
        }
    }
    
    private func calculateCenterCandleIndex() -> Int {
        // Guard against division by zero and empty data: during a transition (e.g. timeframe
        // change) totalCandleWidth or candle count can briefly be 0, which would otherwise
        // pin the preview to candle 0.
        guard totalCandleWidth > 0, !chartData.candles.isEmpty else {
            return max(0, chartData.candles.count - 1)
        }

        let visibleStartIndex = visibleStartIndexForCurrentOffset()

        // FIXED: Use screen width as fallback when chartSize not yet set
        let effectiveWidth = chartSize.width > 0 ? chartSize.width : PlatformScreen.bounds.width
        let candlesOnScreen = Int(effectiveWidth / totalCandleWidth)

        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            visibleStartIndex + candlesOnScreen + 2
        )
        let middleIndex = (visibleStartIndex + visibleEndIndex) / 2
        return max(0, min(chartData.candles.count - 1, middleIndex))
    }

    private func visibleStartIndexForCurrentOffset() -> Int {
        guard totalCandleWidth > 0 else {
            return min(chartData.historicalRenderIndexOffset, max(0, chartData.candles.count - 1))
        }
        let visualIndex = Int(floor(-gestureState.panOffset.width / totalCandleWidth))
        return max(0, min(chartData.candles.count - 1, visualIndex + chartData.historicalRenderIndexOffset))
    }

    private func totalCandleWidth(forCandleWidthScale candleWidthScale: CGFloat) -> CGFloat {
        baseCandleWidth * candleWidthScale + candleSpacing
    }

    private func actualCandleWidth(forCandleWidthScale candleWidthScale: CGFloat) -> CGFloat {
        baseCandleWidth * candleWidthScale
    }

    private func visibleCandleCount(for chartWidth: CGFloat, candleWidthScale: CGFloat? = nil) -> Int {
        let resolvedCandleWidth = candleWidthScale.map {
            totalCandleWidth(forCandleWidthScale: $0)
        } ?? totalCandleWidth
        guard chartWidth > 0, resolvedCandleWidth > 0 else { return 1 }
        return max(1, Int(ceil(chartWidth / resolvedCandleWidth)))
    }

    private func visibleCenterPriceForCurrentOffset(chartWidth: CGFloat) -> Double? {
        guard !chartData.candles.isEmpty else { return nil }
        let centerIndex = max(
            0,
            min(
                chartData.candles.count - 1,
                visibleStartIndexForCurrentOffset() + visibleCandleCount(for: chartWidth) / 2
            )
        )
        return chartData.candles[centerIndex].close
    }

    @discardableResult
    private func updateHistoricalPriceRangePreservingVerticalPosition(
        anchorPrice: Double?,
        chartHeight: CGFloat,
        animateRange: Bool = true,
        update: () -> Bool
    ) -> (min: Double, max: Double) {
        let oldRange = chartData.priceRange
        let oldVerticalOffset = gestureState.verticalPanOffset
        historicalPriceRangeTransitionTask?.cancel()
        let didChangeRange = update()
        let targetRange = chartData.priceRange
        guard didChangeRange,
              let anchorPrice,
              chartHeight > 0,
              gestureState.priceScale > 0,
              oldRange.max > oldRange.min,
              targetRange.max > targetRange.min else {
            return targetRange
        }

        let adjustedOffset = verticalOffsetPreservingScreenPosition(
            anchorPrice: anchorPrice,
            from: oldRange,
            to: targetRange,
            startingVerticalOffset: oldVerticalOffset,
            chartHeight: chartHeight
        )

        guard animateRange else {
            gestureState.verticalPanOffset = clampedVerticalOffset(adjustedOffset, chartHeight: chartHeight)
            return targetRange
        }

        chartData.priceRange = oldRange
        gestureState.verticalPanOffset = oldVerticalOffset
        animateHistoricalPriceRangeTransition(
            from: oldRange,
            to: targetRange,
            anchorPrice: anchorPrice,
            startingVerticalOffset: oldVerticalOffset,
            chartHeight: chartHeight
        )
        return targetRange
    }

    private func verticalOffsetPreservingScreenPosition(
        anchorPrice: Double,
        from oldRange: (min: Double, max: Double),
        to targetRange: (min: Double, max: Double),
        startingVerticalOffset: CGFloat,
        chartHeight: CGFloat
    ) -> CGFloat {
        let oldRangeSpan = oldRange.max - oldRange.min
        let targetRangeSpan = targetRange.max - targetRange.min
        guard oldRangeSpan > 0, targetRangeSpan > 0 else { return startingVerticalOffset }

        let oldNormalized = (anchorPrice - oldRange.min) / oldRangeSpan
        let targetNormalized = (anchorPrice - targetRange.min) / targetRangeSpan
        guard oldNormalized.isFinite, targetNormalized.isFinite else { return startingVerticalOffset }

        let scaledHeight = chartHeight * gestureState.priceScale
        return startingVerticalOffset + CGFloat(oldNormalized - targetNormalized) * scaledHeight
    }

    private func animateHistoricalPriceRangeTransition(
        from oldRange: (min: Double, max: Double),
        to targetRange: (min: Double, max: Double),
        anchorPrice: Double,
        startingVerticalOffset: CGFloat,
        chartHeight: CGFloat
    ) {
        let oldRangeSpan = oldRange.max - oldRange.min
        let targetRangeSpan = targetRange.max - targetRange.min
        let oldNormalized = (anchorPrice - oldRange.min) / oldRangeSpan
        let targetNormalized = (anchorPrice - targetRange.min) / targetRangeSpan
        guard oldNormalized.isFinite, targetNormalized.isFinite else {
            chartData.priceRange = targetRange
            return
        }

        let scaledHeight = chartHeight * gestureState.priceScale
        let frameCount = 18
        historicalPriceRangeTransitionTask = Task { @MainActor in
            for frame in 1...frameCount {
                if Task.isCancelled { return }

                let rawProgress = CGFloat(frame) / CGFloat(frameCount)
                let eased = 1 - (1 - rawProgress) * (1 - rawProgress) * (1 - rawProgress)
                let progress = Double(eased)
                let interpolatedRange = (
                    min: oldRange.min + (targetRange.min - oldRange.min) * progress,
                    max: oldRange.max + (targetRange.max - oldRange.max) * progress
                )
                chartData.priceRange = interpolatedRange

                let interpolatedSpan = interpolatedRange.max - interpolatedRange.min
                if interpolatedSpan > 0 {
                    let interpolatedNormalized = (anchorPrice - interpolatedRange.min) / interpolatedSpan
                    if interpolatedNormalized.isFinite {
                        let adjustedOffset = startingVerticalOffset + CGFloat(oldNormalized - interpolatedNormalized) * scaledHeight
                        gestureState.verticalPanOffset = clampedVerticalOffset(adjustedOffset, chartHeight: chartHeight)
                    }
                }

                try? await Task.sleep(nanoseconds: 12_000_000)
            }

            chartData.priceRange = targetRange
            let adjustedOffset = startingVerticalOffset + CGFloat(oldNormalized - targetNormalized) * scaledHeight
            gestureState.verticalPanOffset = clampedVerticalOffset(adjustedOffset, chartHeight: chartHeight)
        }
    }

    @discardableResult
    private func focusHistoricalMarkerPriceRange(
        forCandleIndex candleIndex: Int,
        anchorPrice: Double?,
        chartWidth: CGFloat,
        chartHeight: CGFloat,
        animateRange: Bool = false
    ) -> (min: Double, max: Double) {
        updateHistoricalPriceRangePreservingVerticalPosition(
            anchorPrice: anchorPrice,
            chartHeight: chartHeight,
            animateRange: animateRange
        ) {
            chartData.focusDeferredHistoricalPriceRangeIfNeeded(
                forCandleIndex: candleIndex,
                visibleCandleCount: visibleCandleCount(for: chartWidth)
            )
        }
    }

    private func centeredPanOffset(
        forCandleIndex candleIndex: Int,
        chartWidth: CGFloat,
        candleWidth: CGFloat
    ) -> CGFloat {
        let targetX = CGFloat(candleIndex - chartData.historicalRenderIndexOffset) * candleWidth
        return chartWidth / 2 - targetX - candleWidth / 2
    }

    private func animateHistoricalMarkerEntry(
        focusMarker: ChartMarkerUI?,
        candleIndex: Int,
        chartWidth: CGFloat,
        chartHeight: CGFloat,
        candleWidth: CGFloat
    ) {
        guard chartData.candles.indices.contains(candleIndex),
              candleWidth > 0,
              chartWidth > 0,
              chartHeight > 0 else {
            return
        }

        historicalPriceRangeTransitionTask?.cancel()
        gestureState.stopMomentum()
        gestureState.stopCenteringAnimation()

        let startRange = chartData.priceRange
        let startPanX = gestureState.panOffset.width
        let startVertical = gestureState.verticalPanOffset
        let candle = chartData.candles[candleIndex]
        let rangePreservationAnchorPrice = focusMarker.map {
            $0.positionedBelow ? candle.low : candle.high
        } ?? candle.close
        let didFocusHistoricalRange = chartData.focusDeferredHistoricalPriceRangeIfNeeded(
            forCandleIndex: candleIndex,
            visibleCandleCount: visibleCandleCount(for: chartWidth)
        )
        let targetRange = chartData.priceRange

        guard didFocusHistoricalRange,
              startRange.max > startRange.min,
              targetRange.max > targetRange.min else {
            let targetFocusPrice = focusMarker.map {
                renderedMarkerFocusPrice(
                    for: $0,
                    chartSize: CGSize(width: chartWidth, height: chartHeight),
                    clampToRange: false
                )
            } ?? candle.close
            gestureState.animateCenterOnMarker(
                at: candleIndex,
                chartWidth: chartWidth,
                candleWidth: candleWidth,
                price: targetFocusPrice,
                chartHeight: chartHeight,
                priceRange: chartData.priceRange,
                historicalRenderIndexOffset: chartData.historicalRenderIndexOffset
            )
            return
        }

        let rangeAdjustedStartVertical = verticalOffsetPreservingScreenPosition(
            anchorPrice: rangePreservationAnchorPrice,
            from: startRange,
            to: targetRange,
            startingVerticalOffset: startVertical,
            chartHeight: chartHeight
        )
        let clampedRangeAdjustedStartVertical = clampedVerticalOffset(
            rangeAdjustedStartVertical,
            chartHeight: chartHeight
        )

        chartData.priceRange = targetRange
        gestureState.panOffset.width = startPanX
        gestureState.verticalPanOffset = clampedRangeAdjustedStartVertical

        let targetFocusPrice = focusMarker.map {
            renderedMarkerFocusPrice(
                for: $0,
                chartSize: CGSize(width: chartWidth, height: chartHeight),
                clampToRange: false
            )
        } ?? candle.close
        gestureState.animateCenterOnMarker(
            at: candleIndex,
            chartWidth: chartWidth,
            candleWidth: candleWidth,
            price: targetFocusPrice,
            chartHeight: chartHeight,
            priceRange: targetRange,
            historicalRenderIndexOffset: chartData.historicalRenderIndexOffset
        )
    }

    private func settleHistoricalPriceRangeAfterMarkerExit(chartWidth: CGFloat? = nil, chartHeight: CGFloat? = nil) {
        let effectiveWidth = chartWidth ?? (chartSize.width > 0 ? chartSize.width : PlatformScreen.bounds.width)
        let effectiveHeight = chartHeight ?? (chartSize.height > 0 ? chartSize.height : PlatformScreen.bounds.height * 0.55)
        updateHistoricalPriceRangePreservingVerticalPosition(
            anchorPrice: visibleCenterPriceForCurrentOffset(chartWidth: effectiveWidth),
            chartHeight: effectiveHeight
        ) {
            chartData.focusVisibleHistoricalPriceRangeIfNeeded(
                visibleStartIndex: visibleStartIndexForCurrentOffset(),
                visibleCandleCount: visibleCandleCount(for: effectiveWidth)
            )
        }
    }

    private func visualX(forCandleIndex index: Int, totalOffset: CGFloat) -> CGFloat {
        CGFloat(index - chartData.historicalRenderIndexOffset) * totalCandleWidth + totalOffset
    }

    private func syncChartDrawingPlacementAnchorToVisibleCenter() {
        guard !chartData.candles.isEmpty,
              controlViewModel.isMarkerPlacementMode || isDefaultChartDrawingContextEnabled || isInteractiveDrawingSessionActive else {
            return
        }
        let centerIndex = snappedMarkerCandleIndex(from: calculateCenterCandleIndex())
            ?? max(0, min(chartData.candles.count - 1, calculateCenterCandleIndex()))
        guard chartData.candles.indices.contains(centerIndex) else { return }

        let candle = chartData.candles[centerIndex]
        // Push the viewport center to marker placement state so newly-added
        // text/emoji annotations land where the user is looking, not at the
        // marker's own anchor (which may be the latest candle for setups).
        placementState.currentViewportAnchorTime = candle.timestamp
        placementState.currentViewportAnchorPrice = candle.close

        guard isDefaultChartDrawingContextEnabled, !isChartPanning else { return }
        chartViewModel.updateChartDrawingPlacementAnchor(
            time: candle.timestamp,
            price: candle.close
        )
    }

    static func nearestNonGapCandleIndex(for targetIndex: Int, candles: [RLCandleDTO]) -> Int? {
        guard candles.indices.contains(targetIndex) else { return nil }
        if !candles[targetIndex].isGapFill {
            return targetIndex
        }

        var distance = 1
        while targetIndex - distance >= 0 || targetIndex + distance < candles.count {
            let previousIndex = targetIndex - distance
            if previousIndex >= 0, !candles[previousIndex].isGapFill {
                return previousIndex
            }

            let nextIndex = targetIndex + distance
            if nextIndex < candles.count, !candles[nextIndex].isGapFill {
                return nextIndex
            }

            distance += 1
        }

        return nil
    }

    private func snappedMarkerCandleIndex(from rawIndex: Int?) -> Int? {
        guard let rawIndex, !chartData.candles.isEmpty else { return nil }
        let clampedIndex = max(0, min(chartData.candles.count - 1, rawIndex))
        return Self.nearestNonGapCandleIndex(for: clampedIndex, candles: chartData.candles)
    }

    private func nearestMarkerCandleIndex(atXPosition x: CGFloat) -> Int? {
        guard !chartData.candles.isEmpty else { return nil }
        let scaledWidth = actualCandleWidth
        let totalWidth = totalCandleWidth
        guard totalWidth > 0 else { return nil }

        let totalOffset = gestureState.panOffset.width + dragState.width
        let centeredX = x - totalOffset - (scaledWidth / 2)
        let roundedIndex = Int(round(centeredX / totalWidth)) + chartData.historicalRenderIndexOffset
        let clampedIndex = max(0, min(chartData.candles.count - 1, roundedIndex))
        return snappedMarkerCandleIndex(from: clampedIndex)
    }

    private var previewDragPlotSize: CGSize {
        let effectiveWidth = chartSize.width > 0 ? chartSize.width : PlatformScreen.bounds.width
        let effectiveHeight = chartSize.height > 0 ? chartSize.height : PlatformScreen.bounds.height * 0.55
        let xAxisReservedHeight = xAxisReservedBandHeight(
            chartHeight: effectiveHeight,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        return CGSize(
            width: max(1, effectiveWidth - yAxisWidth),
            height: max(1, effectiveHeight - xAxisReservedHeight)
        )
    }

    private func boundedPreviewDragLocation(_ location: CGPoint) -> CGPoint {
        MarkerPlacementPreviewDragResolver.clampedDragLocation(
            location,
            plotSize: previewDragPlotSize
        )
    }

    private func persistPreviewMarkerDragIfNeeded(
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard controlViewModel.isMarkerPlacementMode else { return }
        guard placementState.intent != .setup else { return }
        guard let candleIndex = nearestMarkerCandleIndex(atXPosition: location.x),
              chartData.candles.indices.contains(candleIndex) else {
            return
        }

        previewCandleIndex = candleIndex
        let timestamp = chartData.candles[candleIndex].timestamp
        let anchorPrice = coordinateSystem.price(atYPosition: location.y)
        placementState.upsertComponent(
            .anchor,
            payload: .anchor(AnchorPayload(time: timestamp, price: anchorPrice))
        )
    }

    private func optimisticCandleIndex(from request: RLCreateMarkerRequest, fallback: Int) -> Int {
        guard let anchorRequest = request.components.first(where: { $0.componentType == RLComponentType.anchor.rawValue }) else {
            return fallback
        }

        let anchorPayload = MarkerComponentPayload.decode(
            componentType: RLComponentType.anchor.rawValue,
            rawPayload: anchorRequest.payload
        )

        guard let anchorTime = anchorPayload.anchorTime,
              let rawIndex = Self.findCandleIndexForTimestamp(anchorTime, in: chartData.candles),
              let snapped = snappedMarkerCandleIndex(from: rawIndex) else {
            return fallback
        }

        return snapped
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
                            let generator = PlatformImpactGenerator(style: .medium)
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
                    let generator = PlatformImpactGenerator(style: .light)
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

    private func renderedMarkerFocusPrice(
        for marker: ChartMarkerUI,
        chartSize: CGSize,
        clampToRange: Bool = true
    ) -> Double {
        MarkerFocusHelper.renderedGlyphFocusPrice(
            marker: marker,
            candles: chartData.candles,
            chartSize: chartSize,
            priceRange: chartData.priceRange,
            priceScale: gestureState.priceScale,
            verticalOffset: clampedVerticalOffset(chartHeight: chartSize.height),
            totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth,
            totalOffset: gestureState.panOffset.width - CGFloat(chartData.historicalRenderIndexOffset) * totalCandleWidth,
            clampToRange: clampToRange
        ) ?? marker.price
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

        var focusMarker = matchingMarker
        focusMarker?.candleIndex = resolvedIndex

        let chartWidth = PlatformScreen.bounds.width
        let chartHeight = PlatformScreen.bounds.height * 0.55
        let candleWidth = totalCandleWidth
        if let focusMarker {
            tappedMarkerId = focusMarker.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                tappedMarkerId = nil
            }
        }

        animateHistoricalMarkerEntry(
            focusMarker: focusMarker,
            candleIndex: resolvedIndex,
            chartWidth: chartWidth,
            chartHeight: chartHeight,
            candleWidth: candleWidth
        )
        if let focusMarker {
            stageMarkerSelection(focusMarker)
        }
    }

    private func stageMarkerSelection(_ marker: ChartMarkerUI, delay: TimeInterval = 0.12) {
        pendingMarkerSelectionId = marker.id
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard pendingMarkerSelectionId == marker.id else { return }
            markerManager.selectedMarker = marker
            pendingMarkerSelectionId = nil
        }
    }
    
    private func tapGestureForMarkers(geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard !crosshairManager.isActive,
                      !isMarkerPlacementMode,
                      pendingMarkerInfo == nil else {
                    return
                }

                let location = value.location
                let coordinateSystem = createCoordinateSystem(geometry: geometry)
                if isDefaultChartDrawingContextEnabled,
                   hitTestEditableDrawing(
                    at: location,
                    coordinateSystem: coordinateSystem,
                    intent: .reenterEditing
                   ) != nil {
                    return
                }
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
                    totalOffset: totalOffset - CGFloat(chartData.historicalRenderIndexOffset) * totalCandleWidth
                ) {
                    HapticFeedback.selection.trigger()
                    tappedMarkerId = marker.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        tappedMarkerId = nil
                    }
                    let chartWidth = geometry.size.width
                    let chartHeight = geometry.size.height
                    let timestamp = marker.candleTimestamp
                    let markerId = marker.id
                    let width = totalCandleWidth
                    DispatchQueue.main.async {
                        let candles = chartData.candles
                        guard !candles.isEmpty else { return }

                        let index = Self.findCandleIndexForTimestamp(timestamp, in: candles) ?? max(0, candles.count - 50)
                        var focusMarker = markerManager.markers.first(where: { $0.id == markerId }) ?? marker
                        focusMarker.candleIndex = index

                        animateHistoricalMarkerEntry(
                            focusMarker: focusMarker,
                            candleIndex: index,
                            chartWidth: chartWidth,
                            chartHeight: chartHeight,
                            candleWidth: width
                        )
                        stageMarkerSelection(focusMarker)
                    }
                }
            }
    }
    
    // MARK: - Placement Tool Tap Gesture

    /// During placement mode, tapping the chart interacts with the placement state
    /// based on the currently active placement action state.
    private func drawingInteractionTapGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard activeInteractiveDrawingState != nil else { return }

                let location = value.location
                let commitPoint = resolvedPlacementCommitPoint(
                    fallbackLocation: location,
                    coordinateSystem: coordinateSystem
                )
                clearDrawingGuideDragState()
                clearDrawingHandleDragState()

                handlePlacementToolTap(
                    price: commitPoint.price,
                    time: commitPoint.time,
                    candleIndex: commitPoint.candleIndex,
                    location: location,
                    coordinateSystem: coordinateSystem
                )
            }
    }

    private func drawingInteractionDragGesture(coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard activeInteractiveDrawingState != nil else { return }
                if shouldUpdateLiveDrawingGuidePoint(with: value) {
                    updateLiveDrawingGuidePoint(value: value, coordinateSystem: coordinateSystem)
                    return
                }

                _ = updateActiveDrawingHandleIfNeeded(
                    with: value,
                    coordinateSystem: coordinateSystem
                )
            }
            .onEnded { value in
                guard activeInteractiveDrawingState != nil else { return }

                let dragDistance = hypot(value.translation.width, value.translation.height)
                let didDragEditingHandle =
                    drawingHandleDragOrigin != nil
                    && dragDistance >= drawingHandleDragActivationDistance
                let isGuideDrag = isDrawingPointPlacementActive && dragDistance >= drawingGuideDragActivationDistance
                if didDragEditingHandle {
                    clearDrawingHandleDragState()
                    activeInteractiveDrawingState?.setSelectedDrawingHandle(nil)
                    return
                }
                if isGuideDrag {
                    clearDrawingGuideDragState()
                    return
                }
                clearDrawingGuideDragState()
                clearDrawingHandleDragState()
            }
    }

    /// Process a tap on the chart during placement mode.
    /// The action depends on the currently selected tool group and sub-tool.
    private func handlePlacementToolTap(
        price: Double,
        time: Date,
        candleIndex: Int?,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState else { return }

        let drawingTapContextEnabled =
            drawingState.activeDrawingWorkflowTool != nil
            || drawingState.drawingInteractionPhase != .idle
            || drawingStateHasEditableComponents(drawingState)

        let isPlacingDrawingPoint =
            drawingState.drawingInteractionPhase == .placingFirstPoint ||
            drawingState.drawingInteractionPhase == .placingSecondPoint

        let drawingHitIntent: DrawingHitIntent =
            drawingState.drawingInteractionPhase == .editing ? .maintainEditing : .reenterEditing

        if drawingTapContextEnabled, !isPlacingDrawingPoint,
           let target = hitTestEditableDrawing(
               at: location,
               coordinateSystem: coordinateSystem,
               intent: drawingHitIntent
           ) {
            beginEditing(target: target)
            return
        }

        if drawingTapContextEnabled, drawingState.drawingInteractionPhase == .editing {
            lockCurrentDrawingEdits()
            return
        }

        guard let activeTool = drawingState.activeTool else { return }

        impactFeedback.impactOccurred(intensity: 0.6)

        switch activeTool {
        case .anchor:
            // Move anchor to tapped position
            placementState.upsertComponent(
                .anchor,
                payload: .anchor(AnchorPayload(time: time, price: price))
            )

        case .levels:
            // Set the active level sub-tool's price to the tapped position
            if let subTool = placementState.activeSubTool {
                switch subTool {
                case MarkerToolOption.levelEntry.rawValue:
                    // Setup entry is fixed to anchor; ignore chart taps for entry edits.
                    if placementState.intent != .setup {
                        placementState.upsertComponent(
                            .levelEntry,
                            payload: .levelEntry(LevelPayload(price: price, label: "Entry"))
                        )
                    }
                case MarkerToolOption.levelSl.rawValue:
                    placementState.upsertComponent(
                        .levelSl,
                        payload: .levelSl(LevelPayload(price: price, label: "SL"))
                    )
                case MarkerToolOption.levelTp.rawValue:
                    placementState.upsertComponent(
                        .levelTp,
                        payload: .levelTp(LevelPayload(price: price, label: "TP"))
                    )
                case MarkerToolOption.levelSupport.rawValue:
                    handleDrawingToolTap(tool: .support, drawingState: drawingState, price: price, time: time)
                case MarkerToolOption.levelResistance.rawValue:
                    handleDrawingToolTap(tool: .resistance, drawingState: drawingState, price: price, time: time)
                default:
                    break
                }
            }

        case .draw:
            if let tool = drawingState.activeDrawingWorkflowTool {
                handleDrawingToolTap(tool: tool, drawingState: drawingState, price: price, time: time)
            }

        default:
            // Other tools (indicators, note, link, etc.) don't need chart taps
            break
        }
    }

    private var liveDrawingGuidePoint: (time: Date, price: Double)? {
        get { activeInteractiveDrawingState?.drawingGuidePoint }
        nonmutating set { activeInteractiveDrawingState?.drawingGuidePoint = newValue }
    }

    private enum EditableDrawingHitTarget {
        case trendline(UUID)
        case horizontalLine(UUID)
        case support(UUID)
        case resistance(UUID)
        case zone(UUID)
        case pattern(UUID)
        case note(UUID)
        case emoji(UUID)

        var draftId: UUID {
            switch self {
            case .trendline(let id), .horizontalLine(let id), .support(let id), .resistance(let id), .zone(let id), .pattern(let id), .note(let id), .emoji(let id):
                return id
            }
        }
    }

    private enum DrawingHitIntent {
        case reenterEditing
        case maintainEditing
    }

    private func drawingStateHasEditableComponents(_ drawingState: MarkerPlacementState) -> Bool {
        drawingState.components.contains { draft in
            switch draft.componentType {
            case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .textNote, .reactionEmoji, .levelSupport, .levelResistance:
                return true
            default:
                return false
            }
        }
    }

    private func beginEditing(target: EditableDrawingHitTarget) {
        guard let drawingState = activeInteractiveDrawingState else { return }
        switch target {
        case .trendline(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .trendline)
        case .horizontalLine(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .horizontalLine)
        case .support(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .support)
        case .resistance(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .resistance)
        case .zone(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .zone)
        case .pattern(let draftId):
            let tool = patternTool(for: draftId, in: drawingState) ?? .headAndShoulders
            drawingState.beginEditingDrawing(draftId, tool: tool)
        case .note(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .note)
        case .emoji(let draftId):
            drawingState.beginEditingDrawing(draftId, tool: .emoji)
        }
        liveDrawingGuidePoint = nil
        clearDrawingGuideDragState()
        clearDrawingHandleDragState()
        drawingState.setDrawingPanLocked(false)
        impactFeedback.impactOccurred(intensity: 0.6)
    }

    private func lockCurrentDrawingEdits() {
        guard let drawingState = activeInteractiveDrawingState else { return }
        drawingState.commitDrawingAndExit()
        liveDrawingGuidePoint = nil
        clearDrawingGuideDragState()
        clearDrawingHandleDragState()
        drawingState.setDrawingPanLocked(false)
        didEvaluateDrawingPanLockForCurrentDrag = false
        drawingState.setSelectedDrawingHandle(nil)
    }

    private func shouldUpdateLiveDrawingGuidePoint(with value: DragGesture.Value) -> Bool {
        guard let drawingState = activeInteractiveDrawingState else { return false }
        guard drawingState.drawingSession.isPointPlacementActive else { return false }
        guard let tool = drawingState.activeDrawingWorkflowTool else { return false }
        guard MarkerDrawingToolRegistry.definition(for: tool).requiresGuidePlacement else { return false }

        let dragDistance = hypot(value.translation.width, value.translation.height)
        switch drawingState.drawingInteractionPhase {
        case .placingFirstPoint, .placingSecondPoint:
            return dragDistance >= drawingGuideDragActivationDistance
        case .idle, .editing, .committing:
            return false
        }
    }

    private var isDrawingPointPlacementActive: Bool {
        activeInteractiveDrawingState?.drawingSession.isPointPlacementActive ?? false
    }

    private var isEmojiEditingActive: Bool {
        guard let drawingState = activeInteractiveDrawingState,
              drawingState.drawingInteractionPhase == .editing,
              let editingId = drawingState.editingDrawingId,
              let draft = drawingState.components.first(where: { $0.id == editingId }) else {
            return false
        }
        if isStyleOnlyReactionEmojiDraft(draft) {
            return false
        }
        if case .reactionEmoji = draft.payload {
            return true
        }
        return false
    }

    /// Ensures unfinished drawing interaction state is cleaned up when tools/tabs change.
    private func reconcileDrawingInteractionState() {
        guard let drawingState = activeInteractiveDrawingState else {
            liveDrawingGuidePoint = nil
            clearDrawingGuideDragState()
            clearDrawingHandleDragState()
            placementState.setDrawingPanLocked(false)
            chartDrawingPlacementState.setDrawingPanLocked(false)
            didEvaluateDrawingPanLockForCurrentDrag = false
            placementState.setSelectedDrawingHandle(nil)
            chartDrawingPlacementState.setSelectedDrawingHandle(nil)
            return
        }

        if drawingState.drawingInteractionPhase != .editing && drawingState.drawingInteractionPhase != .committing {
            drawingState.setSelectedDrawingHandle(nil)
        }

        if drawingState.drawingInteractionPhase == .idle || drawingState.drawingInteractionPhase == .committing {
            drawingState.setDrawingPanLocked(false)
            didEvaluateDrawingPanLockForCurrentDrag = false
            clearDrawingHandleDragState()
        } else if drawingState.drawingInteractionPhase == .editing,
                  drawingState.drawingSession.selectedHandle == nil {
            drawingState.setDrawingPanLocked(false)
        }
    }

    private func handleDrawingToolTap(
        tool: MarkerDrawingToolKind,
        drawingState: MarkerPlacementState,
        price: Double,
        time: Date
    ) {
        guard drawingState.drawingInteractionPhase != .editing else { return }

        switch tool {
        case .trendline:
            if let firstTap = drawingState.pendingDrawingFirstPoint {
                let finalPayload = MarkerComponentPayload.drawingTrendline(
                    TrendlinePayload(
                        startTime: firstTap.time,
                        startPrice: firstTap.price,
                        endTime: time,
                        endPrice: price
                    )
                )
                guard let draftId = drawingState.addDrawingOverlayComponent(.drawingTrendline, payload: finalPayload) else {
                    HapticFeedback.light.trigger()
                    return
                }
                drawingState.beginDrawingCommit()
                beginEditing(target: .trendline(draftId))
            } else {
                drawingState.setDrawingFirstPoint(time: time, price: price)
                liveDrawingGuidePoint = (time: time, price: price)
            }
        case .horizontalLine:
            guard let draftId = drawingState.addDrawingOverlayComponent(
                .drawingHorizontalLine,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(price: price, label: "Line")
                )
            ) else {
                HapticFeedback.light.trigger()
                return
            }
            drawingState.beginDrawingCommit()
            beginEditing(target: .horizontalLine(draftId))
        case .support:
            drawingState.upsertComponent(
                .levelSupport,
                payload: .levelSupport(
                    LevelPayload(
                        price: price,
                        label: drawingState.levelLabel(for: .levelSupport, fallback: "Support"),
                        colorHex: drawingState.component(.levelSupport)?.payload.drawingColorHex
                    )
                )
            )
            if let draftId = drawingState.component(.levelSupport)?.id {
                drawingState.beginDrawingCommit()
                beginEditing(target: .support(draftId))
            }
        case .resistance:
            drawingState.upsertComponent(
                .levelResistance,
                payload: .levelResistance(
                    LevelPayload(
                        price: price,
                        label: drawingState.levelLabel(for: .levelResistance, fallback: "Resistance"),
                        colorHex: drawingState.component(.levelResistance)?.payload.drawingColorHex
                    )
                )
            )
            if let draftId = drawingState.component(.levelResistance)?.id {
                drawingState.beginDrawingCommit()
                beginEditing(target: .resistance(draftId))
            }
        case .zone:
            if let firstTap = drawingState.pendingDrawingFirstPoint {
                guard let draftId = drawingState.addDrawingOverlayComponent(
                    .drawingZone,
                    payload: .drawingZone(
                        ZonePayload(
                            topPrice: max(firstTap.price, price),
                            bottomPrice: min(firstTap.price, price),
                            startTime: firstTap.time,
                            endTime: time
                        )
                    )
                ) else {
                    HapticFeedback.light.trigger()
                    return
                }
                drawingState.beginDrawingCommit()
                beginEditing(target: .zone(draftId))
            } else {
                drawingState.setDrawingFirstPoint(time: time, price: price)
                liveDrawingGuidePoint = (time: time, price: price)
            }
        case .breakoutRetest, .rangeReversal, .risingChannel, .headAndShoulders:
            handlePatternToolTap(tool: tool, drawingState: drawingState, price: price, time: time)
        case .note, .emoji, .rayLine, .verticalLine, .crossLine, .parallelChannel, .longPosition, .shortPosition, .takeProfitIdea, .stopLossIdea:
            break
        }
    }

    private func handlePatternToolTap(
        tool: MarkerDrawingToolKind,
        drawingState: MarkerPlacementState,
        price: Double,
        time: Date
    ) {
        let definition = MarkerDrawingToolRegistry.definition(for: tool)
        guard definition.componentType == .drawingPattern else { return }

        var points = drawingState.drawingSession.committedPoints
        let nextPoint = MarkerDrawingGuidePoint(time: time, price: price)
        if points.count < definition.requiredPointCount {
            points.append(nextPoint)
        }

        if points.count < definition.requiredPointCount {
            drawingState.drawingSession.committedPoints = points
            drawingState.drawingSession.phase = .placing(stepIndex: points.count)
            drawingState.drawingSession.isPanLocked = true
            liveDrawingGuidePoint = (time: time, price: price)
            return
        }

        let payload = patternPayload(for: tool, points: points)
        guard let draftId = drawingState.addDrawingOverlayComponent(.drawingPattern, payload: payload) else {
            HapticFeedback.light.trigger()
            return
        }
        drawingState.beginDrawingCommit()
        beginEditing(target: .pattern(draftId))
    }

    private func patternPayload(
        for tool: MarkerDrawingToolKind,
        points: [MarkerDrawingGuidePoint]
    ) -> MarkerComponentPayload {
        let template = ChartPatternDrawingTemplate(rawValue: tool.rawValue)
        let labels = template?.pointLabels ?? []
        let guidePoints = points.enumerated().map { index, point in
            PatternGuidePointPayload(
                time: point.time,
                price: point.price,
                label: labels.indices.contains(index) ? labels[index] : nil
            )
        }
        return .drawingPattern(
            ChartPatternPayload(
                patternKey: template?.rawValue ?? tool.rawValue,
                title: template?.title ?? tool.title,
                points: guidePoints,
                colorHex: template?.tintHex ?? "#F59E0B",
                lineStyle: .dashed,
                lineWidth: 2
            )
        )
    }

    private func patternTool(for draftId: UUID, in drawingState: MarkerPlacementState) -> MarkerDrawingToolKind? {
        guard let draft = drawingState.components.first(where: { $0.id == draftId }),
              case let .drawingPattern(payload) = draft.payload else {
            return nil
        }
        return MarkerDrawingToolKind.from(patternKey: payload.patternKey)
    }

    private func updateLiveDrawingGuidePoint(
        value: DragGesture.Value,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let tool = drawingState.activeDrawingWorkflowTool else { return }
        let definition = MarkerDrawingToolRegistry.definition(for: tool)
        guard definition.requiresGuidePlacement else { return }

        let dragOrigin = ensureDrawingGuideDragOrigin(coordinateSystem: coordinateSystem)
        guard let dragOrigin else {
            return
        }

        let width = max(1, coordinateSystem.chartSize.width)
        let translatedX = min(max(0, dragOrigin.screenPoint.x + value.translation.width), width - 1)
        let translatedY = dragOrigin.screenPoint.y + value.translation.height
        var candleIndex = coordinateSystem.candleIndex(atXPosition: translatedX)
        // Clamp to last candle when dragging past the most recent candle edge
        if candleIndex == nil, !chartData.candles.isEmpty {
            candleIndex = chartData.candles.count - 1
        }
        let timestamp = resolvedPlacementTapTime(
            candleIndex: candleIndex,
            coordinateSystem: coordinateSystem
        )
        let price = coordinateSystem.unclampedPrice(atYPosition: translatedY)

        liveDrawingGuidePoint = (time: timestamp, price: price)
    }

    private func resolvedPlacementCommitPoint(
        fallbackLocation: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) -> (time: Date, price: Double, candleIndex: Int?) {
        if let drawingState = activeInteractiveDrawingState,
           let tool = drawingState.activeDrawingWorkflowTool,
           MarkerDrawingToolRegistry.definition(for: tool).requiresGuidePlacement,
           let guidePoint = currentDrawingGuidePoint {
            return (
                time: guidePoint.time,
                price: guidePoint.price,
                candleIndex: coordinateSystem.candleIndex(forTimestamp: guidePoint.time)
            )
        }

        var tappedCandleIndex = coordinateSystem.candleIndex(atXPosition: fallbackLocation.x)
        // Clamp to last candle when tapping past the most recent candle edge
        if tappedCandleIndex == nil, !chartData.candles.isEmpty {
            tappedCandleIndex = chartData.candles.count - 1
        }
        let tappedTime = resolvedPlacementTapTime(
            candleIndex: tappedCandleIndex,
            coordinateSystem: coordinateSystem
        )
        let tappedPrice = coordinateSystem.unclampedPrice(atYPosition: fallbackLocation.y)
        return (time: tappedTime, price: tappedPrice, candleIndex: tappedCandleIndex)
    }

    private func ensureDrawingGuideDragOrigin(
        coordinateSystem: ChartCoordinateSystem
    ) -> (guidePoint: MarkerDrawingGuidePoint, screenPoint: CGPoint)? {
        if let guidePoint = drawingGuideDragStartGuidePoint,
           let screenPoint = drawingGuideDragStartScreenPoint {
            return (guidePoint, screenPoint)
        }

        seedInitialDrawingGuidePointIfNeeded(
            coordinateSystem: coordinateSystem,
            size: coordinateSystem.chartSize
        )

        guard let guidePoint = currentDrawingGuidePoint.map({ MarkerDrawingGuidePoint(time: $0.time, price: $0.price) }),
              let screenPoint = drawingGuideScreenPoint(
                for: guidePoint,
                coordinateSystem: coordinateSystem
              ) else {
            return nil
        }

        drawingGuideDragStartGuidePoint = guidePoint
        drawingGuideDragStartScreenPoint = screenPoint
        return (guidePoint, screenPoint)
    }

    private func drawingGuideScreenPoint(
        for guidePoint: MarkerDrawingGuidePoint,
        coordinateSystem: ChartCoordinateSystem
    ) -> CGPoint? {
        let x: CGFloat
        if let candleIndex = coordinateSystem.candleIndex(forTimestamp: guidePoint.time) {
            x = coordinateSystem.xCenterPosition(forCandleIndex: candleIndex)
        } else {
            x = coordinateSystem.chartSize.width * 0.5
        }
        let y = coordinateSystem.yPosition(forPrice: guidePoint.price)
        return CGPoint(x: x, y: y)
    }

    private func clearDrawingGuideDragState() {
        drawingGuideDragStartScreenPoint = nil
        drawingGuideDragStartGuidePoint = nil
    }

    @discardableResult
    private func updateActiveDrawingHandleIfNeeded(
        with value: DragGesture.Value,
        coordinateSystem: ChartCoordinateSystem
    ) -> Bool {
        guard let drawingState = activeInteractiveDrawingState,
              drawingState.drawingInteractionPhase == .editing else { return false }

        let dragDistance = hypot(value.translation.width, value.translation.height)
        guard dragDistance >= drawingHandleDragActivationDistance else { return false }
        guard let dragOrigin = ensureDrawingHandleDragOrigin(
            startLocation: value.startLocation,
            coordinateSystem: coordinateSystem
        ) else {
            return false
        }

        let translatedLocation = CGPoint(
            x: dragOrigin.screenPoint.x + value.translation.width,
            y: dragOrigin.screenPoint.y + value.translation.height
        )
        guard let draft = drawingState.components.first(where: { $0.id == dragOrigin.draftId }) else {
            return false
        }

        drawingState.setSelectedDrawingHandle(dragOrigin.handle)

        switch dragOrigin.handle {
        case .center:
            switch draft.payload {
            case .drawingTrendline:
                updateTrendlineHandle(
                    draftId: dragOrigin.draftId,
                    isStart: true,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            case .drawingHorizontalLine:
                updateHorizontalLineHandle(
                    draftId: dragOrigin.draftId,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            case .levelSupport:
                updatePlacementLevelHandle(
                    componentType: .levelSupport,
                    draftId: dragOrigin.draftId,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            case .levelResistance:
                updatePlacementLevelHandle(
                    componentType: .levelResistance,
                    draftId: dragOrigin.draftId,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            default:
                return false
            }
        case .point(let index):
            switch draft.payload {
            case .drawingTrendline:
                updateTrendlineHandle(
                    draftId: dragOrigin.draftId,
                    isStart: index == 0,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            case .drawingZone:
                updateZoneHandle(
                    draftId: dragOrigin.draftId,
                    isStart: index == 0,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            case .drawingPattern:
                updatePatternHandle(
                    draftId: dragOrigin.draftId,
                    pointIndex: index,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            case .reactionEmoji:
                updateEmojiScaleHandle(
                    draftId: dragOrigin.draftId,
                    handleIndex: index,
                    location: translatedLocation,
                    coordinateSystem: coordinateSystem
                )
            default:
                return false
            }
        case .annotation:
            return false
        }

        return true
    }

    private func ensureDrawingHandleDragOrigin(
        startLocation: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) -> DrawingHandleDragOrigin? {
        if let drawingHandleDragOrigin {
            return drawingHandleDragOrigin
        }

        guard let handleHit = activeDrawingHandleHitTarget(
            at: startLocation,
            coordinateSystem: coordinateSystem,
            hitRadius: 24
        ) else {
            return nil
        }

        drawingHandleDragOrigin = handleHit
        return handleHit
    }

    private func clearDrawingHandleDragState() {
        drawingHandleDragOrigin = nil
    }

    private func resolvedPlacementTapTime(
        candleIndex: Int?,
        coordinateSystem: ChartCoordinateSystem
    ) -> Date {
        if let candleIndex,
           let timestamp = coordinateSystem.timestamp(forCandleIndex: candleIndex) {
            return timestamp
        }

        if chartData.candles.indices.contains(effectiveCandleIndex),
           let timestamp = coordinateSystem.timestamp(forCandleIndex: effectiveCandleIndex) {
            return timestamp
        }

        if let lastIndex = chartData.candles.indices.last,
           let timestamp = coordinateSystem.timestamp(forCandleIndex: lastIndex) {
            return timestamp
        }

        return chartData.candles.last?.timestamp ?? Date()
    }

    private func seedInitialDrawingGuidePointIfNeeded(
        coordinateSystem: ChartCoordinateSystem,
        size: CGSize
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let tool = drawingState.activeDrawingWorkflowTool else { return }
        let definition = MarkerDrawingToolRegistry.definition(for: tool)
        guard definition.requiresGuidePlacement else { return }
        guard drawingState.drawingInteractionPhase == .placingFirstPoint else { return }
        guard drawingState.pendingDrawingFirstPoint == nil else { return }
        guard liveDrawingGuidePoint == nil else { return }

        let centerX = size.width * 0.5
        let centerY = size.height * 0.5
        let centerIndex = coordinateSystem.candleIndex(atXPosition: centerX)
        let centerTime = resolvedPlacementTapTime(candleIndex: centerIndex, coordinateSystem: coordinateSystem)
        let centerPrice = coordinateSystem.price(atYPosition: centerY)

        liveDrawingGuidePoint = (time: centerTime, price: centerPrice)
    }

    private var currentDrawingGuidePoint: (time: Date, price: Double)? {
        guard let drawingState = activeInteractiveDrawingState,
              let tool = drawingState.activeDrawingWorkflowTool else { return nil }
        let definition = MarkerDrawingToolRegistry.definition(for: tool)
        guard definition.requiresGuidePlacement else { return nil }

        switch drawingState.drawingInteractionPhase {
        case .placingFirstPoint:
            return liveDrawingGuidePoint
        case .placingSecondPoint:
            return liveDrawingGuidePoint ?? drawingState.pendingDrawingFirstPoint
        case .editing:
            if drawingState.drawingSession.selectedHandle != nil,
               tool.group == .pointSequence {
                return liveDrawingGuidePoint
            }
            fallthrough
        case .idle, .committing:
            if let firstTap = drawingState.pendingDrawingFirstPoint {
                return liveDrawingGuidePoint ?? firstTap
            }
        }
        return nil
    }

    @ViewBuilder
    private func drawingControlHandlesOverlay(
        geometry: GeometryProxy,
        coordinateSystem: ChartCoordinateSystem
    ) -> some View {
        if let drawingState = activeInteractiveDrawingState,
           drawingState.drawingInteractionPhase == .editing,
           let editingDraftId = drawingState.editingDrawingId {
            ZStack {
                ForEach(drawingState.components) { draft in
                    if draft.id == editingDraftId {
                        switch draft.payload {
                        case .drawingTrendline(let payload):
                            let trendlineColor = drawingState.drawingColor(
                                for: draft.id,
                                fallback: RLComponentType.drawingTrendline.color
                            )
                            if isHorizontallyLockedTrendline(payload) {
                                if let centerPoint = horizontalTrendlineCenterHandlePoint(
                                    payload: payload,
                                    coordinateSystem: coordinateSystem
                                ) {
                                    drawingHandleView(
                                        at: centerPoint,
                                        handle: .center,
                                        color: trendlineColor,
                                        size: 24
                                    ) { location in
                                        updateTrendlineHandle(
                                            draftId: draft.id,
                                            isStart: true,
                                            location: location,
                                            coordinateSystem: coordinateSystem
                                        )
                                    }
                                }
                            } else {
                                if let startPoint = drawingHandlePoint(
                                    time: payload.startTime,
                                    price: payload.startPrice,
                                    coordinateSystem: coordinateSystem
                                ) {
                                    drawingHandleView(
                                        at: startPoint,
                                        handle: .point(0),
                                        color: trendlineColor,
                                        size: 24
                                    ) { location in
                                        updateTrendlineHandle(
                                            draftId: draft.id,
                                            isStart: true,
                                            location: location,
                                            coordinateSystem: coordinateSystem
                                        )
                                    }
                                }
                                if let endPoint = drawingHandlePoint(
                                    time: payload.endTime,
                                    price: payload.endPrice,
                                    coordinateSystem: coordinateSystem
                                ) {
                                    drawingHandleView(
                                        at: endPoint,
                                        handle: .point(1),
                                        color: trendlineColor,
                                        size: 24
                                    ) { location in
                                        updateTrendlineHandle(
                                            draftId: draft.id,
                                            isStart: false,
                                            location: location,
                                            coordinateSystem: coordinateSystem
                                        )
                                    }
                                }
                            }
                        case .drawingHorizontalLine(let payload):
                            let lineColor = drawingState.drawingColor(
                                for: draft.id,
                                fallback: RLComponentType.drawingHorizontalLine.color
                            )
                            let handlePoint = horizontalLineHandlePoint(
                                payload: payload,
                                coordinateSystem: coordinateSystem
                            )
                            horizontalGripHandleView(
                                at: handlePoint,
                                color: lineColor,
                                isActive: drawingState.drawingSession.selectedHandle != nil
                            )
                        case .levelSupport(let payload):
                            let supportColor = drawingState.drawingColor(
                                for: draft.id,
                                fallback: RLComponentType.levelSupport.color
                            )
                            let handlePoint = horizontalLineHandlePoint(
                                payload: HorizontalLinePayload(
                                    price: payload.price,
                                    label: payload.label,
                                    colorHex: payload.colorHex,
                                    lineStyle: payload.lineStyle,
                                    lineWidth: payload.lineWidth
                                ),
                                coordinateSystem: coordinateSystem
                            )
                            horizontalGripHandleView(
                                at: handlePoint,
                                color: supportColor,
                                isActive: drawingState.drawingSession.selectedHandle != nil
                            )
                        case .levelResistance(let payload):
                            let resistanceColor = drawingState.drawingColor(
                                for: draft.id,
                                fallback: RLComponentType.levelResistance.color
                            )
                            let handlePoint = horizontalLineHandlePoint(
                                payload: HorizontalLinePayload(
                                    price: payload.price,
                                    label: payload.label,
                                    colorHex: payload.colorHex,
                                    lineStyle: payload.lineStyle,
                                    lineWidth: payload.lineWidth
                                ),
                                coordinateSystem: coordinateSystem
                            )
                            horizontalGripHandleView(
                                at: handlePoint,
                                color: resistanceColor,
                                isActive: drawingState.drawingSession.selectedHandle != nil
                            )
                        case .drawingZone(let payload):
                            let zoneColor = drawingState.drawingColor(
                                for: draft.id,
                                fallback: RLComponentType.drawingZone.color
                            )
                            if let startTime = payload.startTime,
                               let topLeft = drawingHandlePoint(
                                   time: startTime,
                                   price: payload.topPrice,
                                   coordinateSystem: coordinateSystem
                               ) {
                                drawingHandleView(
                                    at: topLeft,
                                    handle: .point(0),
                                    color: zoneColor,
                                    size: 24
                                ) { location in
                                    updateZoneHandle(
                                        draftId: draft.id,
                                        isStart: true,
                                        location: location,
                                        coordinateSystem: coordinateSystem
                                    )
                                }
                            }
                            if let endTime = payload.endTime,
                               let bottomRight = drawingHandlePoint(
                                   time: endTime,
                                   price: payload.bottomPrice,
                                   coordinateSystem: coordinateSystem
                               ) {
                                drawingHandleView(
                                    at: bottomRight,
                                    handle: .point(1),
                                    color: zoneColor,
                                    size: 24
                                ) { location in
                                    updateZoneHandle(
                                        draftId: draft.id,
                                        isStart: false,
                                        location: location,
                                        coordinateSystem: coordinateSystem
                                    )
                                }
                            }
                        case .drawingPattern(let payload):
                            let patternColor = drawingState.drawingColor(
                                for: draft.id,
                                fallback: RLComponentType.drawingPattern.color
                            )
                            ForEach(Array(payload.points.enumerated()), id: \.offset) { index, point in
                                if let handlePoint = drawingHandlePoint(
                                    time: point.time,
                                    price: point.price,
                                    coordinateSystem: coordinateSystem
                                ) {
                                    drawingHandleView(
                                        at: handlePoint,
                                        handle: .point(index),
                                        color: patternColor,
                                        size: 24
                                    ) { location in
                                        updatePatternHandle(
                                            draftId: draft.id,
                                            pointIndex: index,
                                            location: location,
                                            coordinateSystem: coordinateSystem
                                        )
                                    }
                                }
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        } else {
            EmptyView()
        }
    }

    private func drawingHandlePoint(
        time: Date,
        price: Double,
        coordinateSystem: ChartCoordinateSystem
    ) -> CGPoint? {
        guard let index = coordinateSystem.candleIndex(forTimestamp: time) else {
            return nil
        }
        let y = coordinateSystem.yPosition(forPrice: price)
        return CGPoint(
            x: coordinateSystem.xCenterPosition(forCandleIndex: index),
            y: y
        )
    }

    @ViewBuilder
    private func drawingHandleView(
        at point: CGPoint,
        handle _: MarkerDrawingHandle,
        color: Color,
        size: CGFloat,
        onChanged _: @escaping (CGPoint) -> Void
    ) -> some View {
        if point.x.isFinite, point.y.isFinite {
            Circle()
                .fill(AppColors.surfaceBlack85)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.9), lineWidth: 1.4)
                )
                .frame(width: size, height: size)
                .position(point)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func horizontalGripHandleView(
        at point: CGPoint,
        color: Color,
        isActive: Bool
    ) -> some View {
        if point.x.isFinite, point.y.isFinite {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(isActive ? 0.5 : 0.32))
                .frame(width: 40, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.58), lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(AppColors.surfaceWhite60)
                                .frame(width: 20, height: 1)
                        }
                    }
                )
                .position(point)
                .allowsHitTesting(false)
        }
    }

    private func horizontalTrendlineCenterHandlePoint(
        payload: TrendlinePayload,
        coordinateSystem: ChartCoordinateSystem
    ) -> CGPoint? {
        guard
            let startPoint = drawingHandlePoint(
                time: payload.startTime,
                price: payload.startPrice,
                coordinateSystem: coordinateSystem
            ),
            let endPoint = drawingHandlePoint(
                time: payload.endTime,
                price: payload.endPrice,
                coordinateSystem: coordinateSystem
            )
        else {
            return nil
        }

        return CGPoint(x: (startPoint.x + endPoint.x) * 0.5, y: startPoint.y)
    }

    private func horizontalLineHandlePoint(
        payload: HorizontalLinePayload,
        coordinateSystem: ChartCoordinateSystem
    ) -> CGPoint {
        let y = coordinateSystem.yPosition(forPrice: payload.price)
        // Match support/resistance placement controls: centered drag handle with right-side price label.
        let x = coordinateSystem.chartSize.width * 0.5
        return CGPoint(x: x, y: y)
    }

    private func updateTrendlineHandle(
        draftId: UUID,
        isStart: Bool,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.drawingOverlayDrafts.first(where: { $0.id == draftId }),
              case let .drawingTrendline(payload) = draft.payload else {
            return
        }

        let fallbackTime = isStart ? payload.startTime : payload.endTime
        let resolvedTime = resolveHandleTime(
            locationX: location.x,
            coordinateSystem: coordinateSystem,
            fallback: fallbackTime
        )
        let resolvedPrice = coordinateSystem.unclampedPrice(atYPosition: location.y)

        let updatedPayload: TrendlinePayload
        if isHorizontallyLockedTrendline(payload) {
            updatedPayload = TrendlinePayload(
                startTime: payload.startTime,
                startPrice: resolvedPrice,
                endTime: payload.endTime,
                endPrice: resolvedPrice,
                colorHex: payload.colorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )
        } else if isStart {
            updatedPayload = TrendlinePayload(
                startTime: resolvedTime,
                startPrice: resolvedPrice,
                endTime: payload.endTime,
                endPrice: payload.endPrice,
                colorHex: payload.colorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )
        } else {
            updatedPayload = TrendlinePayload(
                startTime: payload.startTime,
                startPrice: payload.startPrice,
                endTime: resolvedTime,
                endPrice: resolvedPrice,
                colorHex: payload.colorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )
        }

        liveDrawingGuidePoint = (time: resolvedTime, price: resolvedPrice)
        drawingState.updateComponent(id: draftId, payload: .drawingTrendline(updatedPayload))
    }

    private func isHorizontallyLockedTrendline(_ payload: TrendlinePayload) -> Bool {
        abs(payload.startPrice - payload.endPrice) < 0.0000001
    }

    private func updateHorizontalLineHandle(
        draftId: UUID,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.drawingOverlayDrafts.first(where: { $0.id == draftId }),
              case let .drawingHorizontalLine(payload) = draft.payload else {
            return
        }

        let resolvedPrice = coordinateSystem.unclampedPrice(atYPosition: location.y)
        liveDrawingGuidePoint = nil
        drawingState.updateComponent(
            id: draftId,
            payload: .drawingHorizontalLine(
                HorizontalLinePayload(
                    price: resolvedPrice,
                    label: payload.label,
                    colorHex: payload.colorHex,
                    lineStyle: payload.lineStyle,
                    lineWidth: payload.lineWidth
                )
            )
        )
    }

    private func updatePlacementLevelHandle(
        componentType: RLComponentType,
        draftId: UUID,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.components.first(where: { $0.id == draftId }) else {
            return
        }

        let resolvedPrice = coordinateSystem.unclampedPrice(atYPosition: location.y)
        liveDrawingGuidePoint = nil

        switch draft.payload {
        case let .levelSupport(payload) where componentType == .levelSupport:
            drawingState.updateComponent(
                id: draftId,
                payload: .levelSupport(
                    LevelPayload(
                        price: resolvedPrice,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .levelResistance(payload) where componentType == .levelResistance:
            drawingState.updateComponent(
                id: draftId,
                payload: .levelResistance(
                    LevelPayload(
                        price: resolvedPrice,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        default:
            break
        }
    }

    private func updateZoneHandle(
        draftId: UUID,
        isStart: Bool,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.drawingOverlayDrafts.first(where: { $0.id == draftId }),
              case let .drawingZone(payload) = draft.payload else {
            return
        }

        let resolvedPrice = coordinateSystem.unclampedPrice(atYPosition: location.y)
        let fallbackTime = isStart ? payload.startTime : payload.endTime
        let resolvedTime = resolveHandleTime(
            locationX: location.x,
            coordinateSystem: coordinateSystem,
            fallback: fallbackTime ?? Date()
        )

        let updatedPayload: ZonePayload
        if isStart {
            updatedPayload = ZonePayload(
                topPrice: max(resolvedPrice, payload.bottomPrice),
                bottomPrice: min(resolvedPrice, payload.bottomPrice),
                startTime: resolvedTime,
                endTime: payload.endTime,
                colorHex: payload.colorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )
        } else {
            updatedPayload = ZonePayload(
                topPrice: max(payload.topPrice, resolvedPrice),
                bottomPrice: min(payload.topPrice, resolvedPrice),
                startTime: payload.startTime,
                endTime: resolvedTime,
                colorHex: payload.colorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )
        }

        liveDrawingGuidePoint = (time: resolvedTime, price: resolvedPrice)
        drawingState.updateComponent(id: draftId, payload: .drawingZone(updatedPayload))
    }

    private func updatePatternHandle(
        draftId: UUID,
        pointIndex: Int,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.drawingOverlayDrafts.first(where: { $0.id == draftId }),
              case let .drawingPattern(payload) = draft.payload,
              payload.points.indices.contains(pointIndex) else {
            return
        }

        let currentPoint = payload.points[pointIndex]
        let resolvedTime = resolveHandleTime(
            locationX: location.x,
            coordinateSystem: coordinateSystem,
            fallback: currentPoint.time
        )
        let resolvedPrice = coordinateSystem.unclampedPrice(atYPosition: location.y)
        var updatedPoints = payload.points
        updatedPoints[pointIndex] = PatternGuidePointPayload(
            time: resolvedTime,
            price: resolvedPrice,
            label: currentPoint.label
        )

        liveDrawingGuidePoint = (time: resolvedTime, price: resolvedPrice)
        drawingState.updateComponent(
            id: draftId,
            payload: .drawingPattern(
                ChartPatternPayload(
                    patternKey: payload.patternKey,
                    title: payload.title,
                    points: updatedPoints,
                    colorHex: payload.colorHex,
                    lineStyle: payload.lineStyle,
                    lineWidth: payload.lineWidth
                )
            )
        )
    }

    private func updateEmojiScaleHandle(
        draftId: UUID,
        handleIndex: Int,
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.components.first(where: { $0.id == draftId }),
              case let .reactionEmoji(payload) = draft.payload else {
            return
        }

        // Calculate emoji center position
        let anchorPrice = payload.anchorPrice ?? 0
        let anchorY = coordinateSystem.yPosition(forPrice: anchorPrice)
        let anchorX: CGFloat = {
            guard let time = payload.anchorTime,
                  let index = coordinateSystem.candleIndex(forTimestamp: time) else { return 0 }
            return coordinateSystem.xCenterPosition(forCandleIndex: index)
        }()
        let offsetX = CGFloat(payload.offsetX ?? 0)
        let offsetY = CGFloat(payload.offsetY ?? -68)
        let centerX = anchorX + offsetX
        let centerY = anchorY + offsetY

        // Compute new scale from drag distance to center
        let dragDist = max(abs(location.x - centerX), abs(location.y - centerY))
        let baseSize: CGFloat = 13 // half the emoji size at scale 1.0
        let newScale = min(2.4, max(0.6, dragDist / baseSize))

        drawingState.setEmojiScale(newScale, for: draftId)
        drawingState.updateComponent(
            id: draftId,
            payload: .reactionEmoji(
                EmojiPayload(
                    emoji: payload.emoji,
                    offsetX: payload.offsetX,
                    offsetY: payload.offsetY,
                    anchorTime: payload.anchorTime,
                    anchorPrice: payload.anchorPrice,
                    scale: Double(newScale)
                )
            )
        )
    }

    private func resolveHandleTime(
        locationX: CGFloat,
        coordinateSystem: ChartCoordinateSystem,
        fallback: Date
    ) -> Date {
        guard let candleIndex = coordinateSystem.candleIndex(atXPosition: locationX),
              let timestamp = coordinateSystem.timestamp(forCandleIndex: candleIndex) else {
            return fallback
        }
        return timestamp
    }

    private func activeDrawingHandleHitTarget(
        at location: CGPoint,
        coordinateSystem: ChartCoordinateSystem,
        hitRadius: CGFloat
    ) -> DrawingHandleDragOrigin? {
        guard let drawingState = activeInteractiveDrawingState,
              drawingState.drawingInteractionPhase == .editing,
              let editingId = drawingState.editingDrawingId,
              let draft = drawingState.components.first(where: { $0.id == editingId }) else {
            return nil
        }

        let candidates: [(handle: MarkerDrawingHandle, point: CGPoint)]

        switch draft.payload {
        case .drawingTrendline(let payload):
            if isHorizontallyLockedTrendline(payload),
               let centerPoint = horizontalTrendlineCenterHandlePoint(
                   payload: payload,
                   coordinateSystem: coordinateSystem
               ) {
                candidates = [(.center, centerPoint)]
            } else {
                candidates = [
                    drawingHandlePoint(
                        time: payload.startTime,
                        price: payload.startPrice,
                        coordinateSystem: coordinateSystem
                    ).map { (.point(0), $0) },
                    drawingHandlePoint(
                        time: payload.endTime,
                        price: payload.endPrice,
                        coordinateSystem: coordinateSystem
                    ).map { (.point(1), $0) },
                ].compactMap { $0 }
            }

        case .drawingHorizontalLine(let payload):
            candidates = [
                (
                    .center,
                    horizontalLineHandlePoint(
                        payload: payload,
                        coordinateSystem: coordinateSystem
                    )
                )
            ]

        case .levelSupport(let payload), .levelResistance(let payload):
            candidates = [
                (
                    .center,
                    horizontalLineHandlePoint(
                        payload: HorizontalLinePayload(
                            price: payload.price,
                            label: payload.label,
                            colorHex: payload.colorHex,
                            lineStyle: payload.lineStyle,
                            lineWidth: payload.lineWidth
                        ),
                        coordinateSystem: coordinateSystem
                    )
                )
            ]

        case .drawingZone(let payload):
            candidates = [
                payload.startTime.flatMap { startTime in
                    drawingHandlePoint(
                        time: startTime,
                        price: payload.topPrice,
                        coordinateSystem: coordinateSystem
                    ).map { (.point(0), $0) }
                },
                payload.endTime.flatMap { endTime in
                    drawingHandlePoint(
                        time: endTime,
                        price: payload.bottomPrice,
                        coordinateSystem: coordinateSystem
                    ).map { (.point(1), $0) }
                },
            ].compactMap { $0 }

        case .drawingPattern(let payload):
            candidates = payload.points.enumerated().compactMap { index, point in
                drawingHandlePoint(
                    time: point.time,
                    price: point.price,
                    coordinateSystem: coordinateSystem
                ).map { (.point(index), $0) }
            }

        case .reactionEmoji(let payload):
            let anchorPrice = payload.anchorPrice ?? 0
            let anchorY = coordinateSystem.yPosition(forPrice: anchorPrice)
            let anchorX: CGFloat = {
                guard let time = payload.anchorTime,
                      let index = coordinateSystem.candleIndex(forTimestamp: time) else {
                    return 0
                }
                return coordinateSystem.xCenterPosition(forCandleIndex: index)
            }()
            let offsetX = CGFloat(payload.offsetX ?? 0)
            let offsetY = CGFloat(payload.offsetY ?? -68)
            let x = anchorX + offsetX
            let y = anchorY + offsetY
            let scale = drawingState.emojiScale(for: editingId)
            let halfSize = 13 * scale
            candidates = [
                (.point(0), CGPoint(x: x - halfSize, y: y - halfSize)),
                (.point(1), CGPoint(x: x + halfSize, y: y + halfSize)),
            ]

        default:
            return nil
        }

        return candidates
            .map { candidate in
                (
                    origin: DrawingHandleDragOrigin(
                        draftId: editingId,
                        handle: candidate.handle,
                        screenPoint: candidate.point
                    ),
                    distance: hypot(location.x - candidate.point.x, location.y - candidate.point.y)
                )
            }
            .filter { $0.distance <= hitRadius }
            .min { $0.distance < $1.distance }?
            .origin
    }

    private func isTapOnActiveDrawingHandle(
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) -> Bool {
        activeDrawingHandleHitTarget(
            at: location,
            coordinateSystem: coordinateSystem,
            hitRadius: 18
        ) != nil
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func expandedZoneHitRect(
        payload: ZonePayload,
        coordinateSystem: ChartCoordinateSystem,
        inset: CGFloat
    ) -> CGRect? {
        guard
            let startTime = payload.startTime,
            let endTime = payload.endTime,
            let startPoint = drawingHandlePoint(
                time: startTime,
                price: payload.topPrice,
                coordinateSystem: coordinateSystem
            ),
            let endPoint = drawingHandlePoint(
                time: endTime,
                price: payload.bottomPrice,
                coordinateSystem: coordinateSystem
            )
        else {
            return nil
        }

        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        ).insetBy(dx: -inset, dy: -inset)
    }

    private func patternScreenPoints(
        payload: ChartPatternPayload,
        coordinateSystem: ChartCoordinateSystem
    ) -> [CGPoint] {
        payload.points.compactMap { point in
            drawingHandlePoint(
                time: point.time,
                price: point.price,
                coordinateSystem: coordinateSystem
            )
        }
    }

    private func pointsAdjacentSegments(_ points: [CGPoint]) -> [(start: CGPoint, end: CGPoint)] {
        guard points.count >= 2 else { return [] }
        return (1..<points.count).map { index in
            (start: points[index - 1], end: points[index])
        }
    }

    private func hitTestEditableDrawing(
        at location: CGPoint,
        coordinateSystem: ChartCoordinateSystem,
        intent: DrawingHitIntent = .reenterEditing
    ) -> EditableDrawingHitTarget? {
        guard let drawingState = activeInteractiveDrawingState else { return nil }

        let handleHitRadius: CGFloat
        let emojiHitRadius: CGFloat
        let lineBodyHitRadius: CGFloat

        switch intent {
        case .reenterEditing:
            handleHitRadius = 18
            emojiHitRadius = 28
            lineBodyHitRadius = 14
        case .maintainEditing:
            handleHitRadius = 18
            emojiHitRadius = 36
            lineBodyHitRadius = 14
        }

        if drawingState.drawingInteractionPhase == .editing,
           isTapOnActiveDrawingHandle(location: location, coordinateSystem: coordinateSystem),
           let editingId = drawingState.editingDrawingId,
           let editingDraft = drawingState.components.first(where: { $0.id == editingId }) {
            switch editingDraft.payload {
            case .drawingTrendline:
                return .trendline(editingId)
            case .drawingHorizontalLine:
                return .horizontalLine(editingId)
            case .levelSupport:
                return .support(editingId)
            case .levelResistance:
                return .resistance(editingId)
            case .drawingZone:
                return .zone(editingId)
            case .drawingPattern:
                return .pattern(editingId)
            case .note:
                return .note(editingId)
            case .reactionEmoji:
                if !isStyleOnlyReactionEmojiDraft(editingDraft) {
                    return .emoji(editingId)
                }
            default:
                break
            }
        }

        for draft in drawingState.components.reversed() {
            if isStyleOnlyReactionEmojiDraft(draft) {
                continue
            }
            switch draft.payload {
            case .drawingTrendline(let payload):
                if intent == .maintainEditing {
                    continue
                }
                guard
                    let startPoint = drawingHandlePoint(
                        time: payload.startTime,
                        price: payload.startPrice,
                        coordinateSystem: coordinateSystem
                    ),
                    let endPoint = drawingHandlePoint(
                        time: payload.endTime,
                        price: payload.endPrice,
                        coordinateSystem: coordinateSystem
                    )
                else {
                    continue
                }

                if isHorizontallyLockedTrendline(payload),
                   let centerPoint = horizontalTrendlineCenterHandlePoint(
                    payload: payload,
                    coordinateSystem: coordinateSystem
                   ),
                   hypot(location.x - centerPoint.x, location.y - centerPoint.y) <= handleHitRadius {
                    return .trendline(draft.id)
                }

                let nearStart = hypot(location.x - startPoint.x, location.y - startPoint.y) <= handleHitRadius
                let nearEnd = hypot(location.x - endPoint.x, location.y - endPoint.y) <= handleHitRadius
                if nearStart || nearEnd {
                    return .trendline(draft.id)
                }
                if distanceFromPoint(location, toSegmentStart: startPoint, end: endPoint) <= lineBodyHitRadius {
                    return .trendline(draft.id)
                }

            case .drawingHorizontalLine(let payload):
                if intent == .maintainEditing {
                    continue
                }
                let handlePoint = horizontalLineHandlePoint(
                    payload: payload,
                    coordinateSystem: coordinateSystem
                )
                if hypot(location.x - handlePoint.x, location.y - handlePoint.y) <= handleHitRadius {
                    return .horizontalLine(draft.id)
                }
                if abs(location.y - handlePoint.y) <= lineBodyHitRadius {
                    return .horizontalLine(draft.id)
                }

            case .levelSupport(let payload):
                if intent == .maintainEditing {
                    continue
                }
                let handlePoint = horizontalLineHandlePoint(
                    payload: HorizontalLinePayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    ),
                    coordinateSystem: coordinateSystem
                )
                if hypot(location.x - handlePoint.x, location.y - handlePoint.y) <= handleHitRadius {
                    return .support(draft.id)
                }
                if abs(location.y - handlePoint.y) <= lineBodyHitRadius {
                    return .support(draft.id)
                }

            case .levelResistance(let payload):
                if intent == .maintainEditing {
                    continue
                }
                let handlePoint = horizontalLineHandlePoint(
                    payload: HorizontalLinePayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    ),
                    coordinateSystem: coordinateSystem
                )
                if hypot(location.x - handlePoint.x, location.y - handlePoint.y) <= handleHitRadius {
                    return .resistance(draft.id)
                }
                if abs(location.y - handlePoint.y) <= lineBodyHitRadius {
                    return .resistance(draft.id)
                }

            case .drawingZone(let payload):
                if intent == .maintainEditing {
                    continue
                }

                let startPoint: CGPoint? = payload.startTime.flatMap { startTime in
                    drawingHandlePoint(
                        time: startTime,
                        price: payload.topPrice,
                        coordinateSystem: coordinateSystem
                    )
                }
                let endPoint: CGPoint? = payload.endTime.flatMap { endTime in
                    drawingHandlePoint(
                        time: endTime,
                        price: payload.bottomPrice,
                        coordinateSystem: coordinateSystem
                    )
                }

                if [startPoint, endPoint].compactMap({ $0 }).contains(where: { point in
                    hypot(location.x - point.x, location.y - point.y) <= handleHitRadius
                }) {
                    return .zone(draft.id)
                }
                if let zoneRect = expandedZoneHitRect(
                    payload: payload,
                    coordinateSystem: coordinateSystem,
                    inset: lineBodyHitRadius
                ),
                   zoneRect.contains(location) {
                    return .zone(draft.id)
                }

            case .drawingPattern(let payload):
                if intent == .maintainEditing {
                    continue
                }
                let points = patternScreenPoints(payload: payload, coordinateSystem: coordinateSystem)
                if points.contains(where: { point in
                    hypot(location.x - point.x, location.y - point.y) <= handleHitRadius
                }) {
                    return .pattern(draft.id)
                }
                if pointsAdjacentSegments(points).contains(where: { segment in
                    distanceFromPoint(location, toSegmentStart: segment.start, end: segment.end) <= lineBodyHitRadius
                }) {
                    return .pattern(draft.id)
                }

            case .note(let payload):
                let touchExpansion: CGFloat = intent == .maintainEditing ? 10 : 6
                if noteAnnotationHitRect(
                    for: payload,
                    coordinateSystem: coordinateSystem,
                    touchExpansion: touchExpansion
                )?.contains(location) == true {
                    return .note(draft.id)
                }

            case .reactionEmoji(let payload):
                guard
                    let center = annotationCenter(
                        for: .reactionEmoji(payload),
                        coordinateSystem: coordinateSystem
                    )
                else {
                    continue
                }
                if hypot(location.x - center.x, location.y - center.y) <= emojiHitRadius {
                    return .emoji(draft.id)
                }

            default:
                continue
            }
        }

        return nil
    }

    private func isStyleOnlyReactionEmojiDraft(_ draft: MarkerComponentDraft) -> Bool {
        activeInteractiveDrawingState?.intent == .reaction && draft.componentType == .reactionEmoji
    }

    private func shouldLockChartPanForDrawingGesture(
        at startLocation: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) -> Bool {
        guard let drawingState = activeInteractiveDrawingState else { return false }
        let drawingContextEnabled =
            drawingState.activeDrawingWorkflowTool != nil
            || drawingState.drawingInteractionPhase != .idle
            || drawingStateHasEditableComponents(drawingState)
        guard drawingContextEnabled else { return false }

        guard drawingState.drawingInteractionPhase == .editing else { return false }

        if activeDrawingHandleHitTarget(
            at: startLocation,
            coordinateSystem: coordinateSystem,
            hitRadius: 24
        ) != nil {
            return true
        }

        return isTapOnActiveDrawingAnnotation(
            location: startLocation,
            coordinateSystem: coordinateSystem
        )
    }

    private func isTapOnActiveDrawingAnnotation(
        location: CGPoint,
        coordinateSystem: ChartCoordinateSystem
    ) -> Bool {
        guard let drawingState = activeInteractiveDrawingState,
              drawingState.drawingInteractionPhase == .editing,
              let editingId = drawingState.editingDrawingId,
              let draft = drawingState.components.first(where: { $0.id == editingId }) else {
            return false
        }

        if isStyleOnlyReactionEmojiDraft(draft) {
            return false
        }

        switch draft.payload {
        case .note(let payload):
            return noteAnnotationHitRect(
                for: payload,
                coordinateSystem: coordinateSystem,
                touchExpansion: 8
            )?.contains(location) == true
        case .reactionEmoji(let payload):
            guard let center = annotationCenter(for: .reactionEmoji(payload), coordinateSystem: coordinateSystem) else {
                return false
            }
            return hypot(location.x - center.x, location.y - center.y) <= 38
        default:
            return false
        }
    }

    private func annotationCenter(
        for payload: MarkerComponentPayload,
        coordinateSystem: ChartCoordinateSystem
    ) -> CGPoint? {
        guard let anchorPoint = annotationAnchorPoint(
            for: payload,
            coordinateSystem: coordinateSystem
        ) else {
            return nil
        }
        let offset = annotationOffset(for: payload)
        return CGPoint(x: anchorPoint.x + offset.x, y: anchorPoint.y + offset.y)
    }

    private func noteAnnotationHitRect(
        for payload: NotePayload,
        coordinateSystem: ChartCoordinateSystem,
        touchExpansion: CGFloat
    ) -> CGRect? {
        guard let center = annotationCenter(
            for: .note(payload),
            coordinateSystem: coordinateSystem
        ) else {
            return nil
        }

        return ChartAnnotationBubbleMetrics.hitRect(
            center: center,
            text: payload.text,
            plotWidth: max(1, coordinateSystem.chartSize.width - yAxisWidth),
            touchExpansion: touchExpansion
        )
    }

    private func annotationAnchorPoint(
        for payload: MarkerComponentPayload,
        coordinateSystem: ChartCoordinateSystem
    ) -> CGPoint? {
        let fallbackAnchorTime = activeInteractiveDrawingState?.anchorDraft?.payload.anchorTime
        let fallbackAnchorPrice = activeInteractiveDrawingState?.anchorDraft?.payload.levelPrice

        let anchorTime: Date?
        let anchorPrice: Double?
        switch payload {
        case let .note(note):
            anchorTime = note.anchorTime ?? fallbackAnchorTime
            anchorPrice = note.anchorPrice ?? fallbackAnchorPrice
        case let .reactionEmoji(emoji):
            anchorTime = emoji.anchorTime ?? fallbackAnchorTime
            anchorPrice = emoji.anchorPrice ?? fallbackAnchorPrice
        default:
            anchorTime = fallbackAnchorTime
            anchorPrice = fallbackAnchorPrice
        }

        guard let anchorPrice else { return nil }

        let anchorY = coordinateSystem.yPosition(forPrice: anchorPrice)
        guard let anchorTime,
              let anchorIndex = coordinateSystem.candleIndex(forTimestamp: anchorTime) else {
            return nil
        }
        let anchorX = coordinateSystem.xCenterPosition(forCandleIndex: anchorIndex)

        return CGPoint(x: anchorX, y: anchorY)
    }

    private func annotationOffset(for payload: MarkerComponentPayload) -> CGPoint {
        switch payload {
        case let .note(note):
            return CGPoint(x: note.offsetX ?? 0, y: note.offsetY ?? -36)
        case let .reactionEmoji(emoji):
            return CGPoint(x: emoji.offsetX ?? 0, y: emoji.offsetY ?? -68)
        default:
            return .zero
        }
    }

    // MARK: - Pan Gesture

    private func mellowedPanDelta(_ delta: CGFloat) -> CGFloat {
        let magnitude = abs(delta)
        guard magnitude > panDragMellowThreshold else { return delta }
        let compressedMagnitude = panDragMellowThreshold
            + (magnitude - panDragMellowThreshold) * panDragMellowCompression
        return delta < 0 ? -compressedMagnitude : compressedMagnitude
    }

    private func dragGesture(in size: CGSize, coordinateSystem: ChartCoordinateSystem) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if crosshairManager.isActive {
                    handleCrosshairDrag(value: value, size: size, coordinateSystem: coordinateSystem)
                    return
                }

                if let drawingState = activeInteractiveDrawingState {
                    if isDrawingPointPlacementActive {
                        drawingState.setDrawingPanLocked(true)
                        return
                    }

                    if !didEvaluateDrawingPanLockForCurrentDrag {
                        didEvaluateDrawingPanLockForCurrentDrag = true
                        drawingState.setDrawingPanLocked(shouldLockChartPanForDrawingGesture(
                            at: value.startLocation,
                            coordinateSystem: coordinateSystem
                        ))
                    }

                    if isDrawingPanLockActive {
                        return
                    }
                }
                
                if !isDraggingOnYAxis && !isPinchingOnYAxis && !isMarkerBeingDragged && !isDraggingTarget && !isDraggingPlacementLine && draggingPredictionLine == nil {
                    // Start tracking on first drag event
                    if lastDragTranslation == .zero {
                        gestureState.beginDrag()
                    }
                    isChartPanning = true
                    
                    let incrementalX = value.translation.width - lastDragTranslation.width
                    let incrementalY = -(value.translation.height - lastDragTranslation.height)
                    let responsiveX = incrementalX * panDragSensitivity
                    let responsiveY = incrementalY * panDragSensitivity
                    let dampenedX = mellowedPanDelta(responsiveX)
                    let dampenedY = mellowedPanDelta(responsiveY)
                    lastDragTranslation = value.translation

                    // Drop tiny delta jitter to keep panning visually stable.
                    if abs(dampenedX) < panDragNoiseFloor &&
                        abs(dampenedY) < panDragNoiseFloor {
                        return
                    }
                    
                    gestureState.applyPan(
                        translation: CGSize(width: dampenedX, height: dampenedY),
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale,
                        olderEdgeGuardCandleCount: olderEdgeGuardCandleCount(chartWidth: size.width),
                        historicalRenderIndexOffset: chartData.historicalRenderIndexOffset,
                        velocityTranslation: CGSize(width: responsiveX, height: responsiveY),
                        trackVelocity: true  // Enable velocity tracking for momentum
                    )
                    requestOlderCandlesIfNeeded(chartWidth: size.width)
                }
            }
            .onEnded { value in
                if crosshairManager.isActive {
                    crosshairDragStartPosition = nil
                } else if isDrawingPointPlacementActive {
                    lastDragTranslation = .zero
                    dragState = .zero
                    activeInteractiveDrawingState?.setDrawingPanLocked(false)
                    didEvaluateDrawingPanLockForCurrentDrag = false
                    return
                } else if !isDrawingPanLockActive &&
                            !isDraggingOnYAxis &&
                            !isPinchingOnYAxis &&
                            !isMarkerBeingDragged &&
                            !isDraggingTarget &&
                            !isDraggingPlacementLine &&
                            draggingPredictionLine == nil {
                    // Trigger momentum scrolling
                    gestureState.endDrag(
                        chartWidth: size.width,
                        candleCount: chartData.candles.count,
                        candleWidth: totalCandleWidth,
                        chartHeight: size.height,
                        priceScale: gestureState.priceScale,
                        olderEdgeGuardCandleCount: olderEdgeGuardCandleCount(chartWidth: size.width),
                        historicalRenderIndexOffset: chartData.historicalRenderIndexOffset
                    )
                    requestOlderCandlesIfNeeded(chartWidth: size.width, allowWithoutUserScroll: true)
                }
                
                lastDragTranslation = .zero
                dragState = .zero
                activeInteractiveDrawingState?.setDrawingPanLocked(false)
                didEvaluateDrawingPanLockForCurrentDrag = false
                isChartPanning = false
                syncSelectedMarkerGuideState(
                    chartWidth: size.width,
                    coordinateSystem: coordinateSystem
                )
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
                guard !crosshairManager.isActive,
                      !isMarkerBeingDragged,
                      !isPinchingOnYAxis,
                      !isDrawingPointPlacementActive else { return }
                
                if !isPinchingOnChart {
                    isPinchingOnChart = true
                    initialCandleWidthScale = gestureState.candleWidthScale
                    initialHorizontalOffset = gestureState.panOffset.width
                    pinchCenterX = size.width / 2
                    isChartPanning = false
                    gestureState.stopMomentum()
                }
                
                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                let newScale = initialCandleWidthScale * dampenedValue
                let clampedScale = Swift.min(maxHorizontalScale, Swift.max(minHorizontalScale, newScale))
                
                let oldTotalWidth = baseCandleWidth * initialCandleWidthScale + candleSpacing
                let newTotalWidth = baseCandleWidth * clampedScale + candleSpacing
                let totalWidthRatio = newTotalWidth / oldTotalWidth
                
                let newHorizontalOffset = initialHorizontalOffset * totalWidthRatio + pinchCenterX * (1.0 - totalWidthRatio)
                let clampedHorizontalOffset = clampedHorizontalPanOffset(
                    proposedOffset: newHorizontalOffset,
                    chartWidth: size.width,
                    candleWidthScale: clampedScale
                )
                
                gestureState.candleWidthScale = clampedScale
                gestureState.panOffset.width = clampedHorizontalOffset
            }
            .onEnded { _ in
                isPinchingOnChart = false
            }
    }

    private func clampedHorizontalPanOffset(
        proposedOffset: CGFloat,
        chartWidth: CGFloat,
        candleWidthScale: CGFloat
    ) -> CGFloat {
        let totalWidth = baseCandleWidth * candleWidthScale + candleSpacing
        let edgePadding = ChartGestureState.horizontalEdgePadding
        let renderOffset = max(0, min(chartData.historicalRenderIndexOffset, chartData.candles.count))
        let visibleContentCount = max(0, chartData.candles.count - renderOffset)
        let totalChartWidth = CGFloat(visibleContentCount) * totalWidth
        let maxOffset = CGFloat(renderOffset) * totalWidth + edgePadding
        let minOffset = -(totalChartWidth - chartWidth + edgePadding)
        return Swift.min(maxOffset, Swift.max(minOffset, proposedOffset))
    }
    
    // MARK: - Y-Axis Gestures
    
    private var yAxisDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isDraggingDrawingControlHandle, !isDrawingPointPlacementActive, !isEmojiEditingActive else { return }
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
                
                // Anchor the zoom at the centre of *this chart*, not the centre of
                // the display. `verticalPanOffset` is consumed in chart-local space
                // (ChartCoordinateSystem.yPosition uses chartSize.height), so a
                // screen-derived anchor was a coordinate-space mismatch: the chart
                // never fills the whole screen, so the anchor sat below its visual
                // centre and the price axis crept while zooming. In a 2x2 grid the
                // anchor would land outside the pane entirely.
                let newVerticalOffset = VerticalZoomAnchor.adjustedVerticalOffset(
                    initialOffset: initialVerticalOffset,
                    initialScale: initialPriceScale,
                    newScale: clampedScale,
                    anchorY: VerticalZoomAnchor.anchorY(chartHeight: chartSize.height)
                )
                
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
                guard !isDraggingDrawingControlHandle, !isDrawingPointPlacementActive, !isEmojiEditingActive else { return }
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
                
                // Anchor the zoom at the centre of *this chart*, not the centre of
                // the display. `verticalPanOffset` is consumed in chart-local space
                // (ChartCoordinateSystem.yPosition uses chartSize.height), so a
                // screen-derived anchor was a coordinate-space mismatch: the chart
                // never fills the whole screen, so the anchor sat below its visual
                // centre and the price axis crept while zooming. In a 2x2 grid the
                // anchor would land outside the pane entirely.
                let newVerticalOffset = VerticalZoomAnchor.adjustedVerticalOffset(
                    initialOffset: initialVerticalOffset,
                    initialScale: initialPriceScale,
                    newScale: clampedScale,
                    anchorY: VerticalZoomAnchor.anchorY(chartHeight: chartSize.height)
                )
                
                gestureState.priceScale = clampedScale
                gestureState.verticalPanOffset = newVerticalOffset
            }
            .onEnded { _ in
                isPinchingOnYAxis = false
            }
    }
    
    // MARK: - Axis Overlays

    private var xAxisPanelBackground: Color {
        AppColors.xAxisBackground
    }

    /// True when the bottom panel currently renders its own x-axis label strip.
    private var panelOwnsBottomXAxisStrip: Bool {
        panelBottomBoundaryLabelReserve > 0
    }

    /// When a stacked panel owns time labels, the main chart still reserves this band so plot/masks don't jump when panels close.
    private var mainChartLayoutAlwaysIncludesXAxisLabelStripHeight: Bool { true }

    private var yAxisPanelBackground: some View {
        Color.clear
    }
    
    @ViewBuilder
    func xAxisOverlay(geometry: GeometryProxy) -> some View {
        let bottomAreaHeight = geometry.size.height * 0.085
        let shouldShowMainXAxisLabels = !panelOwnsBottomXAxisStrip

        ZStack {
            VStack(spacing: 0) {
                Spacer()

                if shouldShowMainXAxisLabels {
                    xAxisLabelsCanvas(geometry: geometry)
                } else {
                    Rectangle()
                        .fill(xAxisPanelBackground)
                        .frame(height: ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
                }

                Rectangle()
                    .fill(xAxisPanelBackground)
                    .frame(height: bottomAreaHeight + geometry.safeAreaInsets.bottom)
            }

            if shouldShowMainXAxisLabels,
               !crosshairManager.isActive,
               !isInteractiveDrawingSessionActive,
               gestureState.markerPlacementGuide.isActive,
               let timestamp = gestureState.markerPlacementGuide.timestamp {
                let liveX = liveGuideXPosition(forCandleIndex: gestureState.markerPlacementGuide.candleIndex)
                    ?? gestureState.markerPlacementGuide.x
                if liveX.isFinite {
                    MarkerXAxisTimeIndicator(
                        timestamp: timestamp,
                        xPosition: liveX,
                        chartHeight: geometry.size.height,
                        timeframe: chartViewModel.currentTimeframe,
                        timeZone: axisTimeZone
                    )
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func horizontalDrawingAxisLabelsOverlay(
        geometry: GeometryProxy,
        coordinateSystem: ChartCoordinateSystem
    ) -> some View {
        let items = combinedHorizontalAxisPriceLabels()
        let plotHeight = max(
            0,
            geometry.size.height
                - xAxisReservedBandHeight(
                    chartHeight: geometry.size.height,
                    includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
                )
        )
        let topExclusion = priceIndicatorTopExclusionHeight(geometry: geometry)

        if !items.isEmpty {
            ZStack {
                ForEach(items) { item in
                    let y = coordinateSystem.yPosition(forPrice: item.price)
                    if y.isFinite, y >= 0, y <= plotHeight {
                        let displayY = ChartAxisMetrics.clampedPriceChipCenterY(
                            centerY: y,
                            totalHeight: geometry.size.height,
                            chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
                            topExclusionHeight: topExclusion
                        )
                        horizontalAxisPriceLabelView(
                            label: item.text,
                            price: item.price,
                            color: item.color
                        )
                        .position(
                            x: ChartAxisMetrics.trailingLabelCenterX(
                                totalWidth: geometry.size.width,
                                width: ChartAxisMetrics.secondaryPriceChipWidth
                            ),
                            y: displayY
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func drawingGuideAxisOverlay(
        geometry: GeometryProxy,
        coordinateSystem: ChartCoordinateSystem
    ) -> AnyView {
        guard shouldShowDrawingGuideAxisIndicators,
              let guidePoint = currentDrawingGuidePoint else {
            return AnyView(EmptyView())
        }

        let guideY = coordinateSystem.yPosition(forPrice: guidePoint.price)
        guard guideY.isFinite else {
            return AnyView(EmptyView())
        }

        let guideX: CGFloat
        if let guideIndex = coordinateSystem.candleIndex(forTimestamp: guidePoint.time) {
            guideX = coordinateSystem.xCenterPosition(forCandleIndex: guideIndex)
        } else {
            guideX = geometry.size.width * 0.5
        }
        guard guideX.isFinite else {
            return AnyView(EmptyView())
        }

        let timeLabelY = CrosshairTimeLabel.mainChartCenterY(chartHeight: geometry.size.height)
        guard timeLabelY.isFinite else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ZStack {
                drawingGuidePriceLabel(price: guidePoint.price)
                .position(x: ChartAxisMetrics.yAxisLaneCenterX(totalWidth: geometry.size.width), y: guideY)

                CrosshairTimeLabel(
                    timestamp: guidePoint.time,
                    timeframe: chartViewModel.currentTimeframe,
                    timeZone: axisTimeZone
                )
                .position(
                    x: CrosshairTimeLabel.clampedCenterX(
                        rawX: guideX,
                        timestamp: guidePoint.time,
                        timeframe: chartViewModel.currentTimeframe,
                        timeZone: axisTimeZone,
                        availableWidth: geometry.size.width
                    ),
                    y: timeLabelY
                )
            }
            .allowsHitTesting(false)
        )
    }

    private func drawingGuidePriceLabel(price: Double) -> some View {
        Text(compactMainChartPriceLabel(price))
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.statusHighlight95)
                    .shadow(color: AppColors.statusHighlight40, radius: 3, x: 0, y: 1)
            )
    }

    private func combinedHorizontalAxisPriceLabels() -> [HorizontalAxisPriceLabelItem] {
        var items: [HorizontalAxisPriceLabelItem] = []

        if let drawingState = activeInteractiveDrawingState {
            items.append(contentsOf: horizontalAxisPriceLabels(from: drawingState))
        }

        if !markerOverlayComponents.isEmpty {
            items.append(contentsOf: horizontalAxisPriceLabels(from: markerOverlayComponents))
        }

        var seen = Set<String>()
        return items.filter { item in
            seen.insert(item.id).inserted
        }
    }

    private func horizontalAxisPriceLabels(
        from state: MarkerPlacementState
    ) -> [HorizontalAxisPriceLabelItem] {
        state.components.compactMap { draft in
            switch draft.payload {
            case let .drawingHorizontalLine(payload):
                return HorizontalAxisPriceLabelItem(
                    id: draft.id.uuidString,
                    text: resolvedHorizontalAxisLabel(payload.label, fallback: "Line"),
                    price: payload.price,
                    color: state.drawingColor(
                        for: draft.id,
                        fallback: RLComponentType.drawingHorizontalLine.color
                    )
                )
            case let .levelSupport(payload):
                return HorizontalAxisPriceLabelItem(
                    id: draft.id.uuidString,
                    text: resolvedHorizontalAxisLabel(payload.label, fallback: "Support"),
                    price: payload.price,
                    color: state.drawingColor(
                        for: draft.id,
                        fallback: RLComponentType.levelSupport.color
                    )
                )
            case let .levelResistance(payload):
                return HorizontalAxisPriceLabelItem(
                    id: draft.id.uuidString,
                    text: resolvedHorizontalAxisLabel(payload.label, fallback: "Resistance"),
                    price: payload.price,
                    color: state.drawingColor(
                        for: draft.id,
                        fallback: RLComponentType.levelResistance.color
                    )
                )
            default:
                return nil
            }
        }
    }

    private func horizontalAxisPriceLabels(
        from components: [RLMarkerComponentDTO]
    ) -> [HorizontalAxisPriceLabelItem] {
        components.compactMap { component in
            let fallbackColor = component.componentTypeEnum?.color ?? AppColors.surfaceWhite70
            let resolvedColor = Color(hex: component.payload.drawingColorHex ?? "") ?? fallbackColor

            switch component.payload {
            case let .drawingHorizontalLine(payload):
                return HorizontalAxisPriceLabelItem(
                    id: component.id.uuidString,
                    text: resolvedHorizontalAxisLabel(payload.label, fallback: "Line"),
                    price: payload.price,
                    color: resolvedColor
                )
            case let .levelSupport(payload):
                return HorizontalAxisPriceLabelItem(
                    id: component.id.uuidString,
                    text: resolvedHorizontalAxisLabel(payload.label, fallback: "Support"),
                    price: payload.price,
                    color: resolvedColor
                )
            case let .levelResistance(payload):
                return HorizontalAxisPriceLabelItem(
                    id: component.id.uuidString,
                    text: resolvedHorizontalAxisLabel(payload.label, fallback: "Resistance"),
                    price: payload.price,
                    color: resolvedColor
                )
            default:
                return nil
            }
        }
    }

    private func resolvedHorizontalAxisLabel(
        _ raw: String?,
        fallback: String
    ) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return compactHorizontalPriceLabel(trimmed.isEmpty ? fallback : trimmed)
    }

    private func horizontalAxisPriceLabelView(
        label: String,
        price: Double,
        color: Color
    ) -> some View {
        SecondaryPriceChipView(
            label: label,
            priceText: compactMainChartPriceLabel(price),
            color: color
        )
    }
    
    @ViewBuilder
    private func xAxisLabelsCanvas(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Canvas { context, size in
                drawXAxisLabels(context: context, size: size)
            }
            .frame(height: ChartPanelReserveCalculator.panelXAxisTimeLabelAreaHeight)
            .background(xAxisPanelBackground)

            Rectangle()
                .fill(xAxisPanelBackground)
                .frame(height: ChartPanelReserveCalculator.panelXAxisLabelBottomFootHeight)
        }
        .frame(height: ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
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
                historicalRenderIndexOffset: chartData.historicalRenderIndexOffset,
                width: size.width,
                timeZone: axisTimeZone,
                locale: Locale(identifier: "en_US_POSIX"),
                minSpacing: 60
            ),
            style: .indicatorPanel
        )
    }
    
    // MARK: - Top Fade Mask

    /// Reusable mask that hides content behind the toolbar then fades in near the info box.
    private func topFadeMask(geometry: GeometryProxy) -> some View {
        let topInset = geometry.safeAreaInsets.top
        let fadeHeight = topInset > 0 ? topInset + 42 : 104
        return VStack(spacing: 0) {
            Color.clear
                .frame(height: fadeHeight)
            LinearGradient(
                colors: [.clear, AppColors.chartMaskFade],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            AppColors.chartMaskFade
        }
    }

    /// Hides marker symbols under the nav toolbar; same fade pattern as `topFadeMask` below the cleared band.
    private func markerTopPriorityToolbarMask(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: priceIndicatorTopExclusionHeight(geometry: geometry))
            LinearGradient(
                colors: [.clear, AppColors.chartMaskFade],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            AppColors.chartMaskFade
        }
    }

    private func plotAreaMask(geometry: GeometryProxy) -> some View {
        let xAxisReservedHeight = xAxisReservedBandHeight(
            chartHeight: geometry.size.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        let plotWidth = max(0, geometry.size.width - yAxisWidth)
        let plotHeight = max(0, geometry.size.height - xAxisReservedHeight)
        let topInset = geometry.safeAreaInsets.top
        let fadeStart = topInset > 0 ? topInset + 42 : 104

        return Color.clear
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: fadeStart)
                    LinearGradient(
                        colors: [.clear, AppColors.chartMaskFade],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                    AppColors.chartMaskFade
                        .frame(height: max(0, plotHeight - fadeStart - 60))
                }
                .frame(width: plotWidth, height: plotHeight, alignment: .top)
            }
    }

    /// Band the live-price chip is allowed to occupy: below the toolbar, above the controls.
    ///
    /// A `.clipShape`, not a `.mask`. Both were opaque rectangles — no gradient, no partial alpha —
    /// but `.mask()` forces a full-size offscreen render pass every frame regardless, which a
    /// rectangular clip does not. Free on a Mac GPU, not free on a phone at 1290×2796.
    private func priceIndicatorClipRect(geometry: GeometryProxy) -> CGRect {
        let topExclusion = priceIndicatorTopExclusionHeight(geometry: geometry)
        let bottomExclusion = priceIndicatorBottomExclusionHeight(geometry: geometry)
        let visibleHeight = max(0, geometry.size.height - topExclusion - bottomExclusion)
        return CGRect(x: 0, y: topExclusion, width: geometry.size.width, height: visibleHeight)
    }

    /// Mask for price lines (TP/SL) — full width (spans y-axis), clipped below the
    /// toolbar exclusion and above the x-axis band so chips cannot overlap chrome.
    private func priceLinesFullWidthClipRect(geometry: GeometryProxy) -> CGRect {
        let xAxisReservedHeight = xAxisReservedBandHeight(
            chartHeight: geometry.size.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        let topExclusion = priceIndicatorTopExclusionHeight(geometry: geometry)
        let visibleHeight = ChartAxisMetrics.priceLineVisibleMaskHeight(
            totalHeight: geometry.size.height,
            xAxisReservedHeight: xAxisReservedHeight,
            topExclusionHeight: topExclusion
        )
        return CGRect(x: 0, y: topExclusion, width: geometry.size.width, height: visibleHeight)
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
            .background(yAxisPanelBackground)
        }
        .mask(topFadeMask(geometry: geometry))
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
                let priceText = priceHelper.formatPrice(currentPrice)
                
                context.draw(
                    Text(priceText)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.chartAxisLabelPrimary),
                    at: CGPoint(x: size.width * 0.5, y: y)
                )
                labelCount += 1
            }
            
            currentPrice += step
        }
    }
    
    // MARK: - Chart Info Box
    
    @ViewBuilder
    func chartInfoBox(geometry: GeometryProxy) -> some View {
        let topInset = geometry.safeAreaInsets.top
        let topPadding = topInset > 0 ? topInset + 62 : 124
        let availablePanelWidth = max(132, geometry.size.width - yAxisWidth - 16)
        let intrinsicPanelWidth = chartInfoBaseContentWidth > 0
            ? chartInfoBaseContentWidth + 20
            : 132
        let chartInfoPanelWidth = min(intrinsicPanelWidth, availablePanelWidth)
        let placementChecklistPanel = chartInfoPlacementChecklistPanel(geometry: geometry)
        let viewingInfoPanel = chartInfoViewingPanel(geometry: geometry)

        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    chartInfoContent(panelWidth: chartInfoPanelWidth)
                        .allowsHitTesting(false)

                    if let placementChecklistPanel {
                        placementChecklistPanel
                    }

                    if let viewingInfoPanel {
                        viewingInfoPanel
                    }
                }
                Spacer()
            }
            .padding(.leading, 8)
            .padding(.top, topPadding)
            
            Spacer()
        }
    }

    private func chartInfoPlacementChecklistPanel(geometry: GeometryProxy) -> AnyView? {
        guard isMarkerPlacementMode,
              !placementState.placementChecklistItems.isEmpty else {
            return nil
        }

        let panelWidth = min(196, max(156, (geometry.size.width - yAxisWidth) * 0.30))
        return AnyView(
            MarkerPlacementChecklistPanel(
                placementState: placementState,
                panelWidth: panelWidth
            )
        )
    }

    private func chartInfoViewingPanel(geometry: GeometryProxy) -> AnyView? {
        guard let marker = viewingInfoMarker else { return nil }

        return AnyView(
            MarkerViewingInfoBox(
                marker: marker,
                chartWidth: geometry.size.width,
                yAxisWidth: yAxisWidth,
                isCollapsed: $isViewingInfoPanelCollapsed,
                formatPrice: { price in chartData.formatPrice(price) },
                currentPrice: chartData.currentPrice,
                isSubmittingPollVote: isSubmittingViewingPollVote,
                submittingPollVoteOptionId: viewingPollVoteOptionId,
                onVote: { markerId, optionId in
                    handleViewingPollVote(markerId: markerId, optionId: optionId)
                }
            )
        )
    }
    
    @ViewBuilder
    private func chartInfoContent(panelWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            chartInfoPrimaryRows
            ActiveIndicatorsLegendView(
                indicatorManager: indicatorManager,
                timeframeEntries: activeTimeframeLegendEntries,
                drawings: chartInfoLegendDrawings,
                formatPrice: { price in chartData.formatPrice(price) }
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: panelWidth, alignment: .leading)
        .background(OverlayPanelChrome.background(cornerRadius: 10, showsBorder: false))
    }

    private var chartInfoPrimaryRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            symbolTimeframeRow
            providerRow
            priceRow
        }
        .fixedSize(horizontal: true, vertical: true)
        .measureSize { size in
            let measuredWidth = ceil(size.width)
            guard measuredWidth.isFinite, measuredWidth > 0 else { return }
            if abs(chartInfoBaseContentWidth - measuredWidth) > 0.5 {
                chartInfoBaseContentWidth = measuredWidth
            }
        }
    }

    private var chartInfoLegendDrawings: [ChartDrawing] {
        guard !controlViewModel.isMarkerViewingMode else { return [] }
        return chartDrawingManager.activeDrawings
    }

    private var viewingInfoMarker: ChartMarkerUI? {
        guard controlViewModel.isMarkerViewingMode,
              let selected = markerManager.selectedMarker else {
            return nil
        }
        return markerManager.markers.first(where: { $0.id == selected.id }) ?? selected
    }

    private func bottomInfoPanelsPadding(geometry: GeometryProxy) -> CGFloat {
        let xAxisReserve = xAxisReservedBandHeight(
            chartHeight: geometry.size.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        let panelStackReserve = indicatorPanelBottomPadding + floatingOverlayPanelClearance
        let markerInfoGap: CGFloat = 5
        // Viewing mode: float above active indicator panels as well.
        if controlViewModel.isMarkerViewingMode {
            return xAxisReserve + panelStackReserve + geometry.safeAreaInsets.bottom + markerInfoGap
        }
        let controlsReserve: CGFloat = !isMarkerPlacementMode
            ? 40
            : 0
        return xAxisReserve + panelStackReserve + controlsReserve + geometry.safeAreaInsets.bottom + markerInfoGap
    }

    private func xAxisReservedBandHeight(chartHeight: CGFloat, includeLabelStrip: Bool) -> CGFloat {
        let baseBand = chartHeight * 0.085
        return includeLabelStrip
            ? (baseBand + ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
            : baseBand
    }

    private var selectedDrawingToolbarDraft: MarkerComponentDraft? {
        guard !controlViewModel.isMarkerViewingMode,
              let drawingState = activeInteractiveDrawingState,
              drawingState.drawingInteractionPhase == .editing,
              let draft = drawingState.activeDrawingDraft else {
            return nil
        }
        return isStyleOnlyReactionEmojiDraft(draft) ? nil : draft
    }

    private var shouldShowSelectedDrawingToolbar: Bool {
        selectedDrawingToolbarDraft != nil
    }

    private var drawingToolbarColorHexes: [String] {
        ["#10B981", "#38BDF8", "#F59E0B", "#F43F5E", "#8B5CF6", "#94A3B8"]
    }

    private var drawingEmojiPickerCategories: [(title: String, emojis: [String])] {
        [
            ("Trading", ["🎯", "🔥", "🐻", "🐂", "✅", "❌", "⚠️", "💡", "📌", "🚀", "👀", "🧠"]),
            ("Momentum", ["📈", "📉", "⚡", "💥", "🔍", "⏳", "🛑", "💰", "💎", "🔔", "📣", "🎉"]),
            ("Reactions", ["😀", "😎", "🤔", "😬", "😮", "😤", "😭", "🥶", "🥵", "🤯", "😴", "🤝"]),
            ("Signals", ["📝", "📊", "📍", "🔒", "🔓", "⏰", "🗓️", "🔁", "🏁", "🧭", "🏆", "🎲"]),
        ]
    }

    @ViewBuilder
    private func selectedDrawingToolbar(geometry: GeometryProxy) -> some View {
        if let draft = selectedDrawingToolbarDraft,
           let drawingState = activeInteractiveDrawingState {
            let bottomAreaHeight = geometry.size.height * 0.085 + 34
            let panelPadding = indicatorPanelBottomPadding + floatingOverlayPanelClearance
            let toolbarWidth = max(280, geometry.size.width - yAxisWidth - 16)

            VStack {
                Spacer()

                HStack {
                    if supportsSelectedDrawingEmojiEditing(draft) {
                        selectedDrawingEmojiPicker(
                            draft: draft,
                            drawingState: drawingState,
                            toolbarWidth: toolbarWidth
                        )
                        .padding(.leading, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: draft.componentType.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.chartOverlayToolbarSecondary)

                                Text(draft.componentType.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.chartOverlayToolbarPrimary)

                                Spacer(minLength: 0)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(drawingToolbarColorHexes, id: \.self) { hex in
                                        drawingColorSwatchButton(
                                            hex: hex,
                                            isSelected: drawingState.drawingColorHex(for: draft.id) == hex,
                                            draftId: draft.id,
                                            drawingState: drawingState
                                        )
                                    }

                                    if supportsSelectedDrawingLineStyle(draft) {
                                        ForEach(MarkerDrawingLineStyle.allCases, id: \.self) { style in
                                            drawingLineStyleButton(
                                                style: style,
                                                isSelected: drawingState.drawingLineStyle(
                                                    for: draft.id,
                                                    fallback: defaultLineStyle(for: draft.componentType)
                                                ) == style,
                                                draftId: draft.id,
                                                drawingState: drawingState
                                            )
                                        }
                                    }

                                    if supportsSelectedDrawingLabelEditing(draft) {
                                        drawingToolbarActionButton(icon: "character.cursor.ibeam", title: "Label") {
                                            openDrawingTextEditor(for: draft)
                                        }
                                    }

                                    if supportsSelectedDrawingNoteEditing(draft) {
                                        drawingToolbarActionButton(icon: "text.cursor", title: "Text") {
                                            openDrawingTextEditor(for: draft)
                                        }

                                        drawingToolbarActionButton(icon: "textformat.size.smaller", title: "A-") {
                                            adjustTextNoteFontSize(draft: draft, drawingState: drawingState, delta: -1)
                                        }

                                        drawingToolbarActionButton(icon: "textformat.size.larger", title: "A+") {
                                            adjustTextNoteFontSize(draft: draft, drawingState: drawingState, delta: 1)
                                        }
                                    }

                                    drawingToolbarActionButton(
                                        icon: "trash",
                                        title: "Delete",
                                        foreground: AppColors.statusNegative85
                                    ) {
                                        drawingState.removeComponent(id: draft.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(width: toolbarWidth, alignment: .leading)
                        .background(OverlayPanelChrome.background(cornerRadius: 12))
                        .padding(.leading, 8)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, bottomAreaHeight + panelPadding)
            }
        }
    }

    private func supportsSelectedDrawingLineStyle(_ draft: MarkerComponentDraft) -> Bool {
        switch draft.componentType {
        case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .levelSupport, .levelResistance:
            return true
        default:
            return false
        }
    }

    private func supportsSelectedDrawingLabelEditing(_ draft: MarkerComponentDraft) -> Bool {
        switch draft.componentType {
        case .drawingHorizontalLine, .levelSupport, .levelResistance:
            return true
        default:
            return false
        }
    }

    private func supportsSelectedDrawingNoteEditing(_ draft: MarkerComponentDraft) -> Bool {
        draft.componentType == .textNote
    }

    private func supportsSelectedDrawingEmojiEditing(_ draft: MarkerComponentDraft) -> Bool {
        draft.componentType == .reactionEmoji
    }

    private func defaultLineStyle(for componentType: RLComponentType) -> MarkerDrawingLineStyle {
        switch componentType {
        case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .levelSupport, .levelResistance:
            return .dashed
        default:
            return .solid
        }
    }

    private func drawingColorSwatchButton(
        hex: String,
        isSelected: Bool,
        draftId: UUID,
        drawingState: MarkerPlacementState
    ) -> some View {
        let color = Color(hex: hex) ?? AppColors.surfaceWhite70
        return Button {
            drawingState.setDrawingColorHex(hex, for: draftId)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? AppColors.adaptiveOverlay94 : AppColors.adaptiveOverlay18,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func drawingLineStyleButton(
        style: MarkerDrawingLineStyle,
        isSelected: Bool,
        draftId: UUID,
        drawingState: MarkerPlacementState
    ) -> some View {
        Button {
            drawingState.setDrawingLineStyle(style, for: draftId)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? AppColors.drawingStyleSwatchFillSelected : AppColors.drawingStyleSwatchFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isSelected ? AppColors.adaptiveAccessoryForeground : AppColors.drawingStyleSwatchStroke, lineWidth: 1)
                    )

                Path { path in
                    path.move(to: CGPoint(x: 6, y: 14))
                    path.addLine(to: CGPoint(x: 26, y: 14))
                }
                .stroke(AppColors.drawingStylePreviewLine, style: StrokeStyle(lineWidth: 2, dash: style.dashPattern))
            }
            .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func selectedDrawingEmojiPicker(
        draft: MarkerComponentDraft,
        drawingState: MarkerPlacementState,
        toolbarWidth: CGFloat
    ) -> some View {
        let selectedEmoji = drawingToolbarSelectedEmoji(for: draft)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.chartOverlayToolbarSecondary)

                Text("Emoji Picker")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.chartOverlayToolbarPrimary)

                Spacer(minLength: 0)

                drawingToolbarActionButton(
                    icon: "trash",
                    title: "Delete",
                    foreground: AppColors.statusNegative85
                ) {
                    drawingState.removeComponent(id: draft.id)
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(drawingEmojiPickerCategories.enumerated()), id: \.offset) { entry in
                        let category = entry.element
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppColors.greyText)
                                .textCase(.uppercase)

                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    drawingEmojiToolbarButton(
                                        emoji: emoji,
                                        isSelected: selectedEmoji == emoji,
                                        draft: draft,
                                        drawingState: drawingState
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxHeight: 110)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: toolbarWidth, alignment: .leading)
        .background(OverlayPanelChrome.background(cornerRadius: 14))
    }

    private func drawingEmojiToolbarButton(
        emoji: String,
        isSelected: Bool,
        draft: MarkerComponentDraft,
        drawingState: MarkerPlacementState
    ) -> some View {
        Button {
            guard case let .reactionEmoji(payload) = draft.payload else { return }
            drawingState.updateComponent(
                id: draft.id,
                payload: .reactionEmoji(
                    EmojiPayload(
                        emoji: emoji,
                        offsetX: payload.offsetX,
                        offsetY: payload.offsetY,
                        anchorTime: payload.anchorTime,
                        anchorPrice: payload.anchorPrice,
                        scale: payload.scale
                    )
                )
            )
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? AppColors.whiteText.opacity(0.18) : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected
                                    ? AppColors.chartAxisLabelPrimary.opacity(0.55)
                                    : AppColors.adaptiveOverlay18.opacity(0.35),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
                Text(emoji)
                    .font(.system(size: 18))
            }
            .frame(width: 32, height: 32)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func drawingToolbarActionButton(
        icon: String,
        title: String,
        foreground: Color = AppColors.chartOverlayToolbarPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppColors.symbolDetailCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func drawingToolbarSelectedEmoji(for draft: MarkerComponentDraft) -> String? {
        guard case let .reactionEmoji(payload) = draft.payload else { return nil }
        let trimmed = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func adjustTextNoteFontSize(
        draft: MarkerComponentDraft,
        drawingState: MarkerPlacementState,
        delta: CGFloat
    ) {
        guard case let .note(payload) = draft.payload else { return }
        let current = CGFloat(payload.fontSize ?? Double(ChartAnnotationBubbleMetrics.fontSize))
        let newSize = min(28, max(8, current + delta))
        drawingState.updateComponent(
            id: draft.id,
            payload: .note(
                NotePayload(
                    text: payload.text,
                    offsetX: payload.offsetX,
                    offsetY: payload.offsetY,
                    anchorTime: payload.anchorTime,
                    anchorPrice: payload.anchorPrice,
                    fontSize: Double(newSize),
                    colorHex: payload.colorHex
                )
            )
        )
    }

    private func openDrawingTextEditor(for draft: MarkerComponentDraft) {
        switch draft.payload {
        case let .drawingHorizontalLine(payload):
            drawingTextEditorContext = DrawingTextEditorContext(
                draftId: draft.id,
                title: "Edit Label",
                placeholder: "Line label",
                initialValue: payload.label ?? "",
                kind: .lineLabel
            )
        case let .levelSupport(payload):
            drawingTextEditorContext = DrawingTextEditorContext(
                draftId: draft.id,
                title: "Edit Label",
                placeholder: "Support label",
                initialValue: payload.label ?? "",
                kind: .levelLabel
            )
        case let .levelResistance(payload):
            drawingTextEditorContext = DrawingTextEditorContext(
                draftId: draft.id,
                title: "Edit Label",
                placeholder: "Resistance label",
                initialValue: payload.label ?? "",
                kind: .levelLabel
            )
        case let .note(payload):
            drawingTextEditorContext = DrawingTextEditorContext(
                draftId: draft.id,
                title: "Edit Note",
                placeholder: "Add your context",
                initialValue: payload.text,
                kind: .note
            )
        case let .reactionEmoji(payload):
            drawingTextEditorContext = DrawingTextEditorContext(
                draftId: draft.id,
                title: "Edit Emoji",
                placeholder: "Emoji",
                initialValue: payload.emoji,
                kind: .emoji
            )
        default:
            drawingTextEditorContext = nil
        }
    }

    private func applyDrawingTextEditorValue(_ value: String, context: DrawingTextEditorContext) {
        guard let drawingState = activeInteractiveDrawingState,
              let draft = drawingState.components.first(where: { $0.id == context.draftId }) else {
            return
        }

        switch (context.kind, draft.payload) {
        case (.lineLabel, .drawingHorizontalLine):
            drawingState.setHorizontalLineLabel(value, for: draft.id)

        case let (.levelLabel, .levelSupport(payload)):
            let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(15))
            drawingState.updateComponent(
                id: draft.id,
                payload: .levelSupport(
                    LevelPayload(
                        price: payload.price,
                        label: trimmed.isEmpty ? nil : trimmed,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )

        case let (.levelLabel, .levelResistance(payload)):
            let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(15))
            drawingState.updateComponent(
                id: draft.id,
                payload: .levelResistance(
                    LevelPayload(
                        price: payload.price,
                        label: trimmed.isEmpty ? nil : trimmed,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )

        case let (.note, .note(payload)):
            drawingState.updateComponent(
                id: draft.id,
                payload: .note(
                    NotePayload(
                        text: value,
                        offsetX: payload.offsetX,
                        offsetY: payload.offsetY,
                        anchorTime: payload.anchorTime,
                        anchorPrice: payload.anchorPrice,
                        fontSize: payload.fontSize,
                        colorHex: payload.colorHex
                    )
                )
            )

        case let (.emoji, .reactionEmoji(payload)):
            drawingState.updateComponent(
                id: draft.id,
                payload: .reactionEmoji(
                    EmojiPayload(
                        emoji: value.trimmingCharacters(in: .whitespacesAndNewlines),
                        offsetX: payload.offsetX,
                        offsetY: payload.offsetY,
                        anchorTime: payload.anchorTime,
                        anchorPrice: payload.anchorPrice,
                        scale: payload.scale
                    )
                )
            )

        default:
            break
        }
    }
    
    @ViewBuilder
    private var symbolTimeframeRow: some View {
        HStack(spacing: 8) {
            if let symbol = currentSymbol {
                TickerSymbolIconView(
                    ticker: symbol.ticker,
                    assetClass: symbol.assetClass,
                    brandColorHex: symbol.primaryColor,
                    size: 18,
                    cornerRadiusRatio: 0.24,
                    strokeOpacity: 0.14
                )

                Text(symbol.ticker)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
            }

            if let symbol = currentSymbol {
                Image(systemName: symbol.effectiveIsMarketOpen ? "circle.fill" : "moon.fill")
                    .font(.system(size: symbol.effectiveIsMarketOpen ? 7 : 8, weight: .semibold))
                    .foregroundColor(
                        symbol.effectiveIsMarketOpen
                            ? RLComponentType.levelEntry.color
                            : AppColors.surfaceGray75
                    )
            }
        }
    }

    @ViewBuilder
    private var providerRow: some View {
        HStack(spacing: 6) {
            if let symbol = currentSymbol {
                Text(symbol.providerDisplayLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.surfaceWhite85)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.statusInfo24)
                    .clipShape(Capsule())
            }

            Text(currentTimeframe.shortName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.surfaceWhite88)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppColors.statusInfo40)
                .clipShape(Capsule())
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
            .foregroundColor(
                change >= 0
                    ? RLComponentType.levelEntry.color
                    : RLComponentType.levelSl.color
            )
        }
    }

    // MARK: - Chart Controls Box
    
    @ViewBuilder
    func chartControlsBox(geometry: GeometryProxy) -> some View {
        let bottomAreaHeight = geometry.size.height * 0.085 + 34
        let yAxisTrailingInset: CGFloat = yAxisWidth + 4
        let panelPadding = chartControlRowPanelReserve

        VStack {
            Spacer()

            // Expanded marker visibility panel (above buttons)
            if isMarkerVisibilityPanelExpanded {
                HStack {
                    Spacer()
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
                            .foregroundColor(AppColors.chartOverlayStripLabel)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(AppColors.markerFilterPanelControlWell)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .colorScheme(.dark)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppColors.markerFilterExpandedPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.trailing, yAxisTrailingInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.bottom, 6)
            }

            // Button row (always anchored just above x-axis)
            HStack(alignment: .bottom) {
                dayDatePill
                    .padding(.leading, 6)

                Spacer()

                HStack(spacing: 6) {
                    ChartBottomControlButton(
                        title: isMarkerVisibilityPanelExpanded ? "Close" : "Markers",
                        icon: isMarkerVisibilityPanelExpanded ? "xmark.circle" : "eye",
                        color: AppColors.chartBottomControlForeground,
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
                        color: AppColors.chartBottomControlForeground
                    ) {
                        controlViewModel.jumpToLatest()
                    }
                    .allowsHitTesting(true)

                    // Chart settings (icon-only)
                    ChartBottomIconControlButton(
                        icon: "gearshape",
                        color: AppColors.chartBottomControlForeground
                    ) {
                        showChartSettingsSheet = true
                    }
                    .allowsHitTesting(true)
                }
                .padding(.trailing, yAxisTrailingInset)
            }
            .padding(.bottom, bottomAreaHeight + panelPadding)
        }
        .animation(.easeInOut(duration: 0.2), value: isMarkerVisibilityPanelExpanded)
        .allowsHitTesting(true)
    }

    // MARK: - Day/Date Pill

    @ViewBuilder
    private var dayDatePill: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let labelText = visibleDayLabelText

        if !labelText.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.chartBottomControlForeground)
                Text(labelText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.chartBottomControlForeground)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ChartBottomControlButton.inactiveBackground)
            .cornerRadius(ChartBottomControlButton.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ChartBottomControlButton.cornerRadius)
                    .stroke(ChartBottomControlButton.inactiveBorder, lineWidth: 1)
            )
            .allowsHitTesting(false)
        }
    }

    private var visibleDayLabelText: String {
        let effectiveWidth = chartSize.width > 0 ? chartSize.width : PlatformScreen.bounds.width
        return ChartXAxisLabelEngine.visibleDayLabel(
            input: .init(
                candles: chartData.candles,
                timeframe: chartViewModel.currentTimeframe,
                totalOffset: gestureState.panOffset.width,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                historicalRenderIndexOffset: chartData.historicalRenderIndexOffset,
                width: effectiveWidth,
                timeZone: axisTimeZone,
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
    }

    private var markerTypeFilterSummary: String {
        let selectedCount = markerManager.visibleIntents.count
        let total = RLMarkerIntent.allCases.count
        if selectedCount == total {
            return "Intents: All"
        }
        return "Intents: \(selectedCount)"
    }

    @ViewBuilder
    private var markerTypeFilterSheet: some View {
        NavigationStack {
            List {
                ForEach(RLMarkerIntent.allCases, id: \.self) { intent in
                    Toggle(isOn: Binding(
                        get: { markerManager.visibleIntents.contains(intent) },
                        set: { isOn in
                            if isOn {
                                markerManager.visibleIntents.insert(intent)
                            } else {
                                markerManager.visibleIntents.remove(intent)
                            }
                        }
                    )) {
                        HStack(spacing: 10) {
                            UnifiedMarkerBadge(
                                intent: intent,
                                sizeToken: .tiny
                            )
                            Text(intent.displayName)
                        }
                    }
                    .tint(AppColors.accentColor)
                }
            }
            .navigationTitle("Marker Intents")
            .toolbar {
                ToolbarItem(placement: .platformLeading) {
                    Button("All") {
                        markerManager.visibleIntents = Set(RLMarkerIntent.allCases)
                    }
                }
                ToolbarItem(placement: .platformTrailing) {
                    SheetCloseButton(action: {
                        showMarkerTypeFilterSheet = false
                    })
                }
            }
        }
        .presentationDetents([.fraction(0.55), .large])
    }
    
    // MARK: - Chart Drawing
    
    private func drawChart(context: GraphicsContext, size: CGSize) {
        var drawingContext = context

        let xAxisBand = xAxisReservedBandHeight(
            chartHeight: size.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        let plotRect = CGRect(x: 0, y: 0, width: max(0, size.width - yAxisWidth), height: max(0, size.height - xAxisBand))
        drawingContext.clip(to: Path(plotRect))

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
            verticalOffset: totalVerticalOffset,
            totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth,
            totalOffset: gestureState.panOffset.width - CGFloat(chartData.historicalRenderIndexOffset) * totalCandleWidth
        )

        // Guide line drawn BEFORE markers so markers occlude it (todo 38 — no dashes inside marker body)
        if !crosshairManager.isActive,
           !isInteractiveDrawingSessionActive,
           gestureState.markerPlacementGuide.isActive,
           gestureState.markerPlacementGuide.timestamp != nil {
            // Recompute x from the cached candle index using the live pan
            // offset. The cached `x` field updates one onChange tick behind the
            // pan, which would cause the line to drift mid-pan and snap back
            // when the gesture settles.
            let liveGuideX = liveGuideXPosition(forCandleIndex: gestureState.markerPlacementGuide.candleIndex)
                ?? gestureState.markerPlacementGuide.x
            if liveGuideX.isFinite {
                let guidePath = Path { path in
                    path.move(to: CGPoint(x: liveGuideX, y: 0))
                    path.addLine(to: CGPoint(x: liveGuideX, y: size.height))
                }
                drawingContext.stroke(
                    guidePath,
                    with: .color(placementGuideLineColor.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                )
            }
        }

        // Reset opacity after dimmed-base pass.
        if chartDimmed {
            drawingContext.opacity = 1.0
        }
    }

    private func drawTopPriorityMarkers(context: GraphicsContext, size: CGSize) {
        var markerContext = context
        let xAxisReservedHeight = xAxisReservedBandHeight(
            chartHeight: size.height,
            includeLabelStrip: mainChartLayoutAlwaysIncludesXAxisLabelStripHeight
        )
        let plotRect = CGRect(
            x: 0,
            y: 0,
            width: max(0, size.width - yAxisWidth),
            height: max(0, size.height - xAxisReservedHeight)
        )
        markerContext.clip(to: Path(plotRect))

        let totalOffset = gestureState.panOffset.width
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)

        ChartMarkerSystem.drawMarkers(
            context: markerContext,
            markers: markerManager.filteredMarkers,
            candles: chartData.candles,
            chartSize: size,
            priceRange: chartData.priceRange,
            priceScale: gestureState.priceScale,
            verticalOffset: totalVerticalOffset,
            totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth,
            totalOffset: totalOffset - CGFloat(chartData.historicalRenderIndexOffset) * totalCandleWidth,
            markerManager: markerManager,
            selectedMarkerId: markerManager.selectedMarker?.id ?? tappedMarkerId,
            selectedMarkerScale: selectionScale,
            selectedMarkerRotation: selectionRotation,
            dimmed: controlViewModel.isMarkerPlacementMode,
            editingEmojiOverride: editingEmojiOverrideForMarkers
        )
    }

    private var editingEmojiOverrideForMarkers: (markerId: UUID, emoji: String)? {
        guard let markerId = placementState.editingMarkerId,
              placementState.intent == .reaction,
              case let .reactionEmoji(payload)? = placementState.component(.reactionEmoji)?.payload else {
            return nil
        }
        return (markerId: markerId, emoji: payload.emoji)
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        guard chartSettings.showGridLines else { return }

        let priceRange = chartData.priceRange
        guard priceRange.max > priceRange.min,
              totalCandleWidth > 0,
              actualCandleWidth > 0 else { return }
        let scaledHeight = size.height * gestureState.priceScale
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)
        let totalOffset = gestureState.panOffset.width
        let timeframe = chartViewModel.currentTimeframe
        let opacity = chartSettings.gridOpacity

        let verticalGrid = verticalGridPaths(size: size, totalOffset: totalOffset, timeframe: timeframe)
        let horizontalPath = Path { path in
            drawHorizontalGridLines(path: &path, size: size, priceRange: priceRange, scaledHeight: scaledHeight, totalVerticalOffset: totalVerticalOffset)
        }

        context.stroke(horizontalPath, with: .color(.gray.opacity(opacity)), lineWidth: 0.5)
        context.stroke(verticalGrid.minor, with: .color(.gray.opacity(opacity * 0.9)), lineWidth: 0.45)
        context.stroke(verticalGrid.major, with: .color(.gray.opacity(min(opacity * 1.7, 1.0))), lineWidth: 0.6)
    }

    private func verticalGridPaths(size: CGSize, totalOffset: CGFloat, timeframe: RLChartTimeframe) -> (major: Path, minor: Path) {
        var majorPath = Path()
        var minorPath = Path()
        guard totalCandleWidth > 0, actualCandleWidth > 0 else {
            return (majorPath, minorPath)
        }
        let labels = ChartXAxisLabelEngine.makeLabels(
            input: .init(
                candles: chartData.candles,
                timeframe: timeframe,
                totalOffset: totalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                historicalRenderIndexOffset: chartData.historicalRenderIndexOffset,
                width: size.width,
                timeZone: axisTimeZone,
                locale: Locale(identifier: "en_US_POSIX"),
                minSpacing: 60
            )
        )

        for label in labels {
            if label.x >= -100 && label.x <= size.width + 100 {
                if label.kind == .primary {
                    majorPath.move(to: CGPoint(x: label.x, y: 0))
                    majorPath.addLine(to: CGPoint(x: label.x, y: size.height))
                } else {
                    minorPath.move(to: CGPoint(x: label.x, y: 0))
                    minorPath.addLine(to: CGPoint(x: label.x, y: size.height))
                }
            }
        }

        return (major: majorPath, minor: minorPath)
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
        let totalVerticalOffset = clampedVerticalOffset(chartHeight: size.height)

        // Skip drawing during transitional states where the math collapses to NaN/Infinity
        // (timeframe change in flight, empty data, single-price range). This is what produces
        // the "flat single line" rendering during marker navigation if not guarded.
        guard totalCandleWidth > 0,
              !chartData.candles.isEmpty,
              priceRange.max > priceRange.min else { return }

        let visibleStartIndex = Swift.max(
            0,
            Int(-totalOffset / totalCandleWidth) + chartData.historicalRenderIndexOffset - 1
        )
        let visibleEndIndex = Swift.min(
            chartData.candles.count,
            Swift.max(visibleStartIndex, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
        )

        guard visibleStartIndex < visibleEndIndex else { return }

        for i in visibleStartIndex..<visibleEndIndex {
            guard i < chartData.candles.count else { continue }
            drawSingleCandle(
                context: context,
                size: size,
                index: i,
                priceRange: priceRange,
                scaledHeight: scaledHeight,
                totalOffset: totalOffset,
                totalVerticalOffset: totalVerticalOffset
            )
        }
    }
    
    private func drawSingleCandle(
        context: GraphicsContext,
        size: CGSize,
        index: Int,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        totalOffset: CGFloat,
        totalVerticalOffset: CGFloat
    ) {
        let candle = chartData.candles[index]
        guard !candle.isGapFill else { return }
        let x = visualX(forCandleIndex: index, totalOffset: totalOffset)
        
        if x < -totalCandleWidth || x > size.width + totalCandleWidth {
            return
        }

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
        
        let isLightGreyChart = ThemeManager.shared.currentTheme == .lightGrey
        let bullishColor = chartSettings.bullishCandleColor
        let candleColor = candle.close >= candle.open ? bullishColor : chartSettings.bearishCandleColor

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
            let bullFillOpacity = chartSettings.bullishBodyFillOpacity(isLightGreyTheme: isLightGreyChart)
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: 0),
                with: .color(candleColor.opacity(bullFillOpacity))
            )
        } else {
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: 0),
                with: .color(candleColor)
            )
        }
    }
    
    // MARK: - Chart Position Management

    @discardableResult
    private func initializeLatestPositionIfNeeded() -> Bool {
        guard !hasInitializedPosition,
              !chartViewModel.isNavigatingToMarker,
              !chartData.candles.isEmpty,
              chartViewModel.currentSymbol != nil else {
            return false
        }

        resetChartToMostRecentCandles()
        hasInitializedPosition = true
        return true
    }

    private func latestVisibleCandles(chartWidth: CGFloat, candleWidthScale: CGFloat? = nil) -> [RLCandleDTO] {
        guard !chartData.candles.isEmpty else { return [] }
        let recentCount = min(
            chartData.candles.count,
            max(12, visibleCandleCount(for: chartWidth, candleWidthScale: candleWidthScale))
        )
        return Array(chartData.candles.suffix(recentCount))
    }

    private func latestVisiblePriceRange(chartWidth: CGFloat, candleWidthScale: CGFloat? = nil) -> (min: Double, max: Double)? {
        let recentCandles = latestVisibleCandles(chartWidth: chartWidth, candleWidthScale: candleWidthScale)
        guard !recentCandles.isEmpty else { return nil }

        let rangeSource = recentCandles.contains(where: { !$0.isGapFill })
            ? recentCandles.filter { !$0.isGapFill }
            : recentCandles
        guard let minLow = rangeSource.map(\.low).min(),
              let maxHigh = rangeSource.map(\.high).max(),
              minLow.isFinite,
              maxHigh.isFinite else {
            return nil
        }

        let span = maxHigh - minLow
        if span > 0 {
            let padding = span * 0.1
            return (minLow - padding, maxHigh + padding)
        }

        let center = maxHigh > 0 ? maxHigh : max(chartData.currentPrice, 1)
        let padding = max(abs(center) * 0.001, 0.0001)
        return (center - padding, center + padding)
    }

    private func latestVisiblePriceAnchor(chartWidth: CGFloat, candleWidthScale: CGFloat? = nil) -> Double? {
        let recentCandles = latestVisibleCandles(chartWidth: chartWidth, candleWidthScale: candleWidthScale)
        guard !recentCandles.isEmpty else { return nil }
        let rangeSource = recentCandles.contains(where: { !$0.isGapFill })
            ? recentCandles.filter { !$0.isGapFill }
            : recentCandles
        guard let minLow = rangeSource.map(\.low).min(),
              let maxHigh = rangeSource.map(\.high).max(),
              minLow.isFinite,
              maxHigh.isFinite else {
            return chartData.candles.last?.close
        }

        return (minLow + maxHigh) / 2
    }

    private func latestCandlePanOffset(chartWidth: CGFloat, candleWidthScale: CGFloat) -> CGFloat {
        guard !chartData.candles.isEmpty else { return gestureState.panOffset.width }
        let totalWidth = totalCandleWidth(forCandleWidthScale: candleWidthScale)
        let actualWidth = actualCandleWidth(forCandleWidthScale: candleWidthScale)
        guard chartWidth > 0, totalWidth > 0, actualWidth > 0 else {
            return gestureState.panOffset.width
        }

        let latestVisualIndex = max(
            0,
            chartData.candles.count - 1 - chartData.historicalRenderIndexOffset
        )
        let latestCenterX = CGFloat(latestVisualIndex) * totalWidth + actualWidth * 0.5
        let defaultLatestX = chartWidth * 0.70
        return defaultLatestX - latestCenterX
    }

    private func verticalOffsetCentering(
        price: Double,
        chartHeight: CGFloat,
        priceScale: CGFloat,
        priceRange: (min: Double, max: Double)? = nil
    ) -> CGFloat? {
        let effectiveRange = priceRange ?? chartData.priceRange
        let range = effectiveRange.max - effectiveRange.min
        guard range > 0,
              chartHeight > 0,
              priceScale > 0,
              price.isFinite else {
            return nil
        }

        let normalizedPrice = CGFloat((price - effectiveRange.min) / range)
        guard normalizedPrice.isFinite else { return nil }

        return chartHeight / 2 - normalizedPrice * chartHeight * priceScale
    }
    
    private func resetChartToMostRecentCandles() {
        guard !chartData.candles.isEmpty else { return }
        
        let resetCandleWidthScale: CGFloat = 1.0
        let chartWidth = chartSize.width > 0 ? chartSize.width : PlatformScreen.bounds.width
        let chartHeight = chartSize.height > 0 ? chartSize.height : PlatformScreen.bounds.height * 0.55
        let targetOffset = latestCandlePanOffset(
            chartWidth: chartWidth,
            candleWidthScale: resetCandleWidthScale
        )
        let clampedOffset = clampedHorizontalPanOffset(
            proposedOffset: targetOffset,
            chartWidth: chartWidth,
            candleWidthScale: resetCandleWidthScale
        )
        let targetPriceRange = latestVisiblePriceRange(
            chartWidth: chartWidth,
            candleWidthScale: resetCandleWidthScale
        ) ?? chartData.priceRange
        let targetVerticalOffset = latestVisiblePriceAnchor(
            chartWidth: chartWidth,
            candleWidthScale: resetCandleWidthScale
        )
            .flatMap { anchorPrice in
                verticalOffsetCentering(
                    price: anchorPrice,
                    chartHeight: chartHeight,
                    priceScale: 1.0,
                    priceRange: targetPriceRange
                )
            } ?? 0
        
        // Guard preload for the animation's duration so interpolated frames near the data front
        // don't trigger a page-load cascade that fights this animation.
        isProgrammaticScroll = true
        gestureState.stopMomentum()
        withAnimation(.easeOut(duration: 0.3)) {
            chartData.priceRange = targetPriceRange
            gestureState.candleWidthScale = resetCandleWidthScale
            gestureState.priceScale = 1.0
            gestureState.panOffset.width = clampedOffset
            gestureState.panOffset.height = 0
            gestureState.verticalPanOffset = clampedVerticalOffset(targetVerticalOffset, chartHeight: chartHeight)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isProgrammaticScroll = false
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

        controlViewModel.resetToLatestAction = {
            self.resetChartToMostRecentCandles()
        }
        
        controlViewModel.jumpToStartAction = {
            self.isProgrammaticScroll = true
            let width = self.chartSize.width > 0 ? self.chartSize.width : PlatformScreen.bounds.width
            let guardCount = self.olderEdgeGuardCandleCount(chartWidth: width)
            let targetOffset = CGFloat(self.chartData.historicalRenderIndexOffset - guardCount) * self.totalCandleWidth
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.gestureState.panOffset.width = targetOffset
            }
            // Jump-to-start lands on the guarded historical edge while more history exists. Once
            // the animation settles there are no further panOffset changes to trigger preload, so
            // kick one check explicitly to keep loading history from the front.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.isProgrammaticScroll = false
                self.requestOlderCandlesIfNeeded(chartWidth: width, allowWithoutUserScroll: true)
            }
        }

        controlViewModel.jumpToLatestAction = {
            guard !self.chartData.candles.isEmpty else { return }
            let width = self.chartSize.width > 0 ? self.chartSize.width : PlatformScreen.bounds.width
            let height = self.chartSize.height > 0 ? self.chartSize.height : PlatformScreen.bounds.height * 0.55
            let targetOffset = self.latestCandlePanOffset(
                chartWidth: width,
                candleWidthScale: self.gestureState.candleWidthScale
            )
            let clampedOffset = self.clampedHorizontalPanOffset(
                proposedOffset: targetOffset,
                chartWidth: width,
                candleWidthScale: self.gestureState.candleWidthScale
            )
            let targetPriceRange = self.latestVisiblePriceRange(
                chartWidth: width,
                candleWidthScale: self.gestureState.candleWidthScale
            ) ?? self.chartData.priceRange
            let targetVerticalOffset = self.latestVisiblePriceAnchor(
                chartWidth: width,
                candleWidthScale: self.gestureState.candleWidthScale
            )
                .flatMap { anchorPrice in
                    self.verticalOffsetCentering(
                        price: anchorPrice,
                        chartHeight: height,
                        priceScale: self.gestureState.priceScale,
                        priceRange: targetPriceRange
                    )
                } ?? 0
            self.isProgrammaticScroll = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.chartData.priceRange = targetPriceRange
                self.gestureState.panOffset.width = clampedOffset
                self.gestureState.panOffset.height = 0
                self.gestureState.verticalPanOffset = self.clampedVerticalOffset(targetVerticalOffset, chartHeight: height)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.isProgrammaticScroll = false
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

