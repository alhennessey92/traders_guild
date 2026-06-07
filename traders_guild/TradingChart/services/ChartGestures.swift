//
//  ChartGestures.swift
//  traders_guild
//
//  PERFORMANCE FIX + MOMENTUM SCROLLING:
//  - gestureState must be @StateObject LOCAL to TradingChartView
//  - DO NOT use computed property accessing ChartViewModel
//  - Momentum/deceleration added for smooth scroll feel
//

import SwiftUI
import Combine

enum MarkerPlacementGuideSource: String, Equatable {
    case placement
    case selected
}

/// Shared placement guide state so chart and indicator panels can render a synchronized marker guide.
///
/// `x` is a cached screen position computed at the time the guide state was
/// last published. For surfaces that have access to the live coordinate system
/// (e.g. the chart Canvas), prefer recomputing x from `candleIndex` on every
/// draw — the cached value lags one onChange tick behind a pan and that
/// causes the line to drift out of sync with the candles mid-pan.
struct MarkerPlacementGuideState: Equatable {
    var isActive: Bool = false
    var x: CGFloat = 0
    var candleIndex: Int = -1
    var timestamp: Date?
    var markerIntent: RLMarkerIntent?
    var source: MarkerPlacementGuideSource = .placement
}

/// Manages the state of all gestures for the trading chart
/// IMPORTANT: This should be instantiated as @StateObject in TradingChartView
/// for optimal performance. Do NOT route through ChartViewModel's @Published properties.
class ChartGestureState: ObservableObject {
    static let horizontalEdgePadding: CGFloat = 100
    // MARK: - Published Properties
    
    /// Current scale for candle width (horizontal zoom)
    @Published var candleWidthScale: CGFloat = 1.0
    
    /// Current scale for price range (vertical zoom)
    @Published var priceScale: CGFloat = 1.0
    
    /// Horizontal and vertical pan offset
    @Published var panOffset: CGSize = .zero

    /// True while chart movement is being driven by a user's drag or its momentum.
    @Published private(set) var isUserDrivenScrollActive: Bool = false
    
    /// Separate vertical pan offset for finer control
    @Published var verticalPanOffset: CGFloat = 0

    // MARK: - Crosshair State (shared with RSI panel for sync)
    
    /// Whether crosshair is currently active
    @Published var crosshairActive: Bool = false
    
    /// Crosshair X position (shared for vertical line sync)
    @Published var crosshairX: CGFloat = 0
    
    /// Crosshair timestamp for time label
    @Published var crosshairTimestamp: Date?

    /// Marker placement guide state shared with indicator panels.
    @Published var markerPlacementGuide = MarkerPlacementGuideState()
    
    // MARK: - Smooth Centering State

    /// Display link for smooth animated centering
    private var centeringDisplayLink: CADisplayLink?
    private var centeringStartPanX: CGFloat = 0
    private var centeringStartVertical: CGFloat = 0
    private var centeringTargetPanX: CGFloat = 0
    private var centeringTargetVertical: CGFloat = 0
    private var centeringStartTime: CFTimeInterval = 0
    private var centeringDuration: CFTimeInterval = 0.9

    // MARK: - Momentum State

    /// Current velocity for momentum scrolling (points per second)
    private var velocity: CGSize = .zero

    /// Display link for momentum animation
    private var displayLink: CADisplayLink?
    
    /// Last timestamp for velocity calculation
    private var lastDragTime: Date?
    
    /// Last translation for velocity calculation
    private var lastDragTranslation: CGSize = .zero
    
    /// Deceleration rate (0.95 = smooth, 0.99 = ice-like)
    private let decelerationRate: CGFloat = 0.974
    
    /// Minimum velocity to continue momentum (points per second)
    private let minimumVelocity: CGFloat = 10
    
    /// Maximum velocity to prevent violent scrolling (points per second)
    private let maxVelocity: CGFloat = 2800
    
    /// Cached chart dimensions for momentum bounds checking
    private var cachedChartWidth: CGFloat = 0
    private var cachedChartHeight: CGFloat = 0
    private var cachedCandleCount: Int = 0
    private var cachedCandleWidth: CGFloat = 0
    private var cachedPriceScale: CGFloat = 1.0
    private var cachedOlderEdgeGuardCandleCount: Int = 0
    private var cachedHistoricalRenderIndexOffset: Int = 0
    
    // MARK: - Configuration Constants
    
    let minCandleScale: CGFloat = 0.15
    let maxCandleScale: CGFloat = 3.0
    let minPriceScale: CGFloat = 0.5
    let maxPriceScale: CGFloat = 3.0
    
    // MARK: - Initialization
    
    deinit {
        stopMomentum()
        stopCenteringAnimation()
    }
    
    // MARK: - Pan Methods
    
    /// Begin a drag gesture - call this in onChanged when drag starts
    func beginDrag() {
        stopMomentum()
        isUserDrivenScrollActive = true
        lastDragTime = Date()
        lastDragTranslation = .zero
        velocity = .zero
    }
    
    /// Apply pan gesture with boundary limits and velocity tracking
    func applyPan(
        translation: CGSize,
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        chartHeight: CGFloat,
        priceScale: CGFloat,
        olderEdgeGuardCandleCount: Int = 0,
        historicalRenderIndexOffset: Int = 0,
        velocityTranslation: CGSize? = nil,
        trackVelocity: Bool = true
    ) {
        // Cache dimensions for momentum
        cachedChartWidth = chartWidth
        cachedChartHeight = chartHeight
        cachedCandleCount = candleCount
        cachedCandleWidth = candleWidth
        cachedPriceScale = priceScale
        cachedOlderEdgeGuardCandleCount = olderEdgeGuardCandleCount
        cachedHistoricalRenderIndexOffset = historicalRenderIndexOffset
        
        // Calculate velocity if tracking
        // NOTE: translation is INCREMENTAL (per-frame delta), not cumulative
        if trackVelocity, let lastTime = lastDragTime {
            let now = Date()
            let dt = now.timeIntervalSince(lastTime)
            let velocitySource = velocityTranslation ?? translation
            
            // Only track reasonable intervals (not too fast, not too slow)
            if dt > 0.008 && dt < 0.1 {
                // Calculate instantaneous velocity
                let instantVelX = velocitySource.width / CGFloat(dt)
                let instantVelY = velocitySource.height / CGFloat(dt)
                
                // Smooth velocity with exponential moving average (lower alpha = smoother)
                let alpha: CGFloat = 0.18
                velocity.width = velocity.width * (1 - alpha) + instantVelX * alpha
                velocity.height = velocity.height * (1 - alpha) + instantVelY * alpha
                
                // Clamp velocity to prevent violent scrolling
                velocity.width = max(-maxVelocity, min(maxVelocity, velocity.width))
                velocity.height = max(-maxVelocity, min(maxVelocity, velocity.height))
            }
            lastDragTime = now
        }
        
        // Apply the pan
        applyPanInternal(
            translation: translation,
            chartWidth: chartWidth,
            candleCount: candleCount,
            candleWidth: candleWidth,
            chartHeight: chartHeight,
            priceScale: priceScale,
            olderEdgeGuardCandleCount: olderEdgeGuardCandleCount,
            historicalRenderIndexOffset: historicalRenderIndexOffset
        )
    }
    
    /// Internal pan application without velocity tracking (used by momentum)
    private func applyPanInternal(
        translation: CGSize,
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        chartHeight: CGFloat,
        priceScale: CGFloat,
        olderEdgeGuardCandleCount: Int,
        historicalRenderIndexOffset: Int
    ) {
        var newHorizontalOffset = panOffset.width + translation.width
        var newVerticalOffset = verticalPanOffset + translation.height

        // Horizontal limits - skip clamping when there is no candle data, otherwise the
        // computed min/max collapse and the pan offset gets snapped to the first candle.
        if candleCount > 0 && candleWidth > 0 {
            let edgePadding: CGFloat = Self.horizontalEdgePadding
            let renderOffset = max(0, min(historicalRenderIndexOffset, candleCount))
            let visibleContentWidth = CGFloat(max(0, candleCount - renderOffset)) * candleWidth
            let guardedMaxOffset = CGFloat(renderOffset - max(0, olderEdgeGuardCandleCount)) * candleWidth
            let maxHorizontalOffset = olderEdgeGuardCandleCount > 0
                ? guardedMaxOffset
                : CGFloat(renderOffset) * candleWidth + edgePadding
            let minHorizontalOffset = -(visibleContentWidth - chartWidth + edgePadding)

            newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
        }
        
        // Vertical limits - matches clampedVerticalOffset exactly
        let scaledHeight = chartHeight * priceScale
        let baseMultiplier: CGFloat = 3.0
        
        let zoomAdjustment: CGFloat
        if priceScale < 0.5 {
            zoomAdjustment = 4.0
        } else if priceScale < 0.7 {
            zoomAdjustment = 3.0
        } else if priceScale < 0.9 {
            zoomAdjustment = 2.0
        } else if priceScale > 2.0 {
            zoomAdjustment = 2.0
        } else {
            zoomAdjustment = 1.5
        }
        
        let verticalPadding = scaledHeight * baseMultiplier * zoomAdjustment
        newVerticalOffset = Swift.min(verticalPadding, Swift.max(-verticalPadding, newVerticalOffset))
        
        // Update state
        panOffset.width = newHorizontalOffset
        verticalPanOffset = newVerticalOffset
    }
    
    /// End drag and start momentum scrolling
    func endDrag(
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        chartHeight: CGFloat,
        priceScale: CGFloat,
        olderEdgeGuardCandleCount: Int = 0,
        historicalRenderIndexOffset: Int = 0
    ) {
        // Cache final dimensions
        cachedChartWidth = chartWidth
        cachedChartHeight = chartHeight
        cachedCandleCount = candleCount
        cachedCandleWidth = candleWidth
        cachedOlderEdgeGuardCandleCount = olderEdgeGuardCandleCount
        cachedHistoricalRenderIndexOffset = historicalRenderIndexOffset
        
        // Only start momentum if velocity is significant
        let speed = hypot(velocity.width, velocity.height)
        if speed > minimumVelocity * 3 {
            startMomentum(priceScale: priceScale)
        } else {
            velocity = .zero
            isUserDrivenScrollActive = false
        }
        
        lastDragTime = nil
        lastDragTranslation = .zero
    }

    /// Account for historical candles being prepended at the front of the candle array.
    ///
    /// The visual x-origin is handled by `ChartDataManager.historicalRenderIndexOffset`; this only
    /// updates cached momentum bounds so an in-flight deceleration knows the data set expanded.
    func applyHistoricalPrepend(count: Int, totalCandleWidth: CGFloat) {
        guard count > 0 else { return }
        cachedCandleCount += count
        cachedHistoricalRenderIndexOffset += count
    }

    func applyPriceScale(
        proposedScale: CGFloat,
        initialPriceScale: CGFloat,
        initialVerticalOffset: CGFloat,
        anchorY: CGFloat,
        chartHeight: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) {
        let clampedScale = Swift.min(maxScale, Swift.max(minScale, proposedScale))
        let safeInitialScale = max(initialPriceScale, 0.0001)
        let scaleRatio = clampedScale / safeInitialScale
        let proposedOffset = initialVerticalOffset * scaleRatio + anchorY * (1.0 - scaleRatio)

        priceScale = clampedScale
        verticalPanOffset = clampedVerticalOffset(
            proposedOffset,
            chartHeight: chartHeight,
            priceScale: clampedScale
        )
    }
    
    // MARK: - Momentum Animation
    
    private func startMomentum(priceScale: CGFloat) {
        // Stop any existing animation but DON'T zero velocity yet
        displayLink?.invalidate()
        displayLink = nil

        // Cache priceScale for momentum tick
        cachedPriceScale = priceScale

        // Start the animation with current velocity
        displayLink = CADisplayLink(target: self, selector: #selector(momentumTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func momentumTick(_ displayLink: CADisplayLink) {
        // Apply deceleration
        velocity.width *= decelerationRate
        velocity.height *= decelerationRate
        
        // Check if we should stop
        let speed = hypot(velocity.width, velocity.height)
        if speed < minimumVelocity {
            stopMomentum()
            return
        }
        
        // Calculate frame delta (typically ~16ms for 60fps)
        let dt: CGFloat = CGFloat(displayLink.targetTimestamp - displayLink.timestamp)
        let clampedDt = Swift.min(dt, 0.033) // Cap at ~30fps worth to prevent jumps
        
        // Apply velocity as translation
        let translation = CGSize(
            width: velocity.width * clampedDt,
            height: velocity.height * clampedDt
        )
        
        applyPanInternal(
            translation: translation,
            chartWidth: cachedChartWidth,
            candleCount: cachedCandleCount,
            candleWidth: cachedCandleWidth,
            chartHeight: cachedChartHeight,
            priceScale: cachedPriceScale,
            olderEdgeGuardCandleCount: cachedOlderEdgeGuardCandleCount,
            historicalRenderIndexOffset: cachedHistoricalRenderIndexOffset
        )
    }
    
    func stopMomentum() {
        displayLink?.invalidate()
        displayLink = nil
        velocity = .zero
        isUserDrivenScrollActive = false
    }
    
    // MARK: - Scale Methods
    
    /// Apply horizontal scale
    func applyHorizontalScale(_ scale: CGFloat) {
        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, scale))
    }
    
    /// Apply vertical scale
    func applyVerticalScale(_ scale: CGFloat) {
        priceScale = Swift.min(maxPriceScale, Swift.max(minPriceScale, scale))
    }
    
    // MARK: - Reset
    
    /// Reset all gesture states to default (instant, no animation)
    func reset() {
        stopMomentum()
        isUserDrivenScrollActive = false
        candleWidthScale = 1.0
        priceScale = 1.0
        panOffset = .zero
        verticalPanOffset = 0
        markerPlacementGuide = MarkerPlacementGuideState()
    }

    private func clampedVerticalOffset(
        _ offset: CGFloat,
        chartHeight: CGFloat,
        priceScale: CGFloat
    ) -> CGFloat {
        let scaledHeight = chartHeight * priceScale
        let baseMultiplier: CGFloat = 3.0

        let zoomAdjustment: CGFloat
        if priceScale < 0.5 {
            zoomAdjustment = 4.0
        } else if priceScale < 0.7 {
            zoomAdjustment = 3.0
        } else if priceScale < 0.9 {
            zoomAdjustment = 2.0
        } else if priceScale > 2.0 {
            zoomAdjustment = 2.0
        } else {
            zoomAdjustment = 1.5
        }

        let verticalPadding = scaledHeight * baseMultiplier * zoomAdjustment
        return Swift.min(verticalPadding, Swift.max(-verticalPadding, offset))
    }
    
    // MARK: - Navigation
    
    /// Center chart on specific candle index (horizontal only)
    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat, historicalRenderIndexOffset: Int = 0) {
        guard candleWidth > 0, chartWidth > 0 else { return }
        stopMomentum()
        let targetX = CGFloat(index - historicalRenderIndexOffset) * candleWidth
        let centerOffset = chartWidth / 2
        panOffset.width = centerOffset - targetX - (candleWidth / 2)
    }

    /// Center chart on a specific candle and price level (instant, no animation)
    func centerOnMarker(
        at index: Int,
        chartWidth: CGFloat,
        candleWidth: CGFloat,
        price: Double,
        chartHeight: CGFloat,
        priceRange: (min: Double, max: Double),
        historicalRenderIndexOffset: Int = 0
    ) {
        guard candleWidth > 0, chartWidth > 0 else { return }
        stopMomentum()
        stopCenteringAnimation()

        // Horizontal: same as centerOnCandle
        let targetX = CGFloat(index - historicalRenderIndexOffset) * candleWidth
        let centerOffset = chartWidth / 2
        panOffset.width = centerOffset - targetX - (candleWidth / 2)

        // Vertical: calculate offset to center this price on screen
        let range = priceRange.max - priceRange.min
        guard range > 0 else { return }
        let normalizedPrice = CGFloat((price - priceRange.min) / range)
        let scaledHeight = chartHeight * priceScale
        verticalPanOffset = chartHeight / 2 - normalizedPrice * scaledHeight
    }

    /// Smoothly animate chart centering on a marker over time using display link
    func animateCenterOnMarker(
        at index: Int,
        chartWidth: CGFloat,
        candleWidth: CGFloat,
        price: Double,
        chartHeight: CGFloat,
        priceRange: (min: Double, max: Double),
        historicalRenderIndexOffset: Int = 0,
        duration: CFTimeInterval = 0.9
    ) {
        guard candleWidth > 0, chartWidth > 0 else { return }
        stopMomentum()
        stopCenteringAnimation()

        // Calculate target offsets
        let targetX = CGFloat(index - historicalRenderIndexOffset) * candleWidth
        let centerOffset = chartWidth / 2
        let targetPanX = centerOffset - targetX - (candleWidth / 2)

        let range = priceRange.max - priceRange.min
        guard range > 0 else {
            panOffset.width = targetPanX
            return
        }
        let normalizedPrice = CGFloat((price - priceRange.min) / range)
        let scaledHeight = chartHeight * priceScale
        let targetVertical = chartHeight / 2 - normalizedPrice * scaledHeight

        // Store animation state
        centeringStartPanX = panOffset.width
        centeringStartVertical = verticalPanOffset
        centeringTargetPanX = targetPanX
        centeringTargetVertical = targetVertical
        centeringDuration = duration
        centeringStartTime = CACurrentMediaTime()

        // Start display link
        centeringDisplayLink = CADisplayLink(target: self, selector: #selector(centeringTick))
        centeringDisplayLink?.add(to: .main, forMode: .common)
    }

    @objc private func centeringTick(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - centeringStartTime
        var t = elapsed / centeringDuration

        if t >= 1.0 {
            t = 1.0
            stopCenteringAnimation()
        }

        // Ease-in-out cubic: smooth acceleration and deceleration
        let eased: CGFloat
        if t < 0.5 {
            eased = CGFloat(4 * t * t * t)
        } else {
            let f = (2 * t - 2)
            eased = CGFloat(0.5 * f * f * f + 1)
        }

        panOffset.width = centeringStartPanX + (centeringTargetPanX - centeringStartPanX) * eased
        verticalPanOffset = centeringStartVertical + (centeringTargetVertical - centeringStartVertical) * eased
    }

    func stopCenteringAnimation() {
        centeringDisplayLink?.invalidate()
        centeringDisplayLink = nil
    }
    
    /// Zoom to fit a specific number of candles
    func zoomToFitCandles(count: Int, chartWidth: CGFloat, baseCandleWidth: CGFloat) {
        stopMomentum()
        let desiredTotalWidth = chartWidth
        let currentTotalWidth = CGFloat(count) * (baseCandleWidth + 4)
        let requiredScale = desiredTotalWidth / currentTotalWidth
        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, requiredScale))
    }
}

// MARK: - Lightweight Sync Publisher

/// Extension to provide a lightweight way for external views (like RSI panel)
/// to observe pan offset changes without full @Published overhead
extension ChartGestureState {
    /// Publisher for pan offset that external views can subscribe to
    /// This avoids the need to make gestureState @Published in ChartViewModel
    var panOffsetPublisher: AnyPublisher<CGSize, Never> {
        $panOffset.eraseToAnyPublisher()
    }
    
    /// Current horizontal offset (convenience for RSI panel)
    var horizontalOffset: CGFloat {
        panOffset.width
    }
}

struct LinkedIndicatorPanelGestureSurface<Content: View>: View {
    @ObservedObject var gestureState: ChartGestureState
    @ObservedObject var verticalState: IndicatorPanelViewportState

    let candleCount: Int
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    let minVerticalScale: CGFloat
    var yAxisWidth: CGFloat = ChartAxisMetrics.indicatorPanelYAxisLaneWidth
    @ViewBuilder let content: () -> Content

    @State private var lastDragTranslation: CGSize = .zero
    @State private var isYAxisGestureActive = false
    @State private var isBodyPinchActive = false
    @State private var initialCandleWidthScale: CGFloat = 1.0
    @State private var initialHorizontalOffset: CGFloat = 0
    @State private var pinchCenterX: CGFloat = 0
    @State private var yAxisDragStart: CGFloat = 0
    @State private var initialPriceScale: CGFloat = 1.0
    @State private var initialVerticalOffset: CGFloat = 0

    private let pinchSensitivity: CGFloat = 0.7
    private let yAxisSensitivity: CGFloat = 0.7
    private let panDragSensitivity: CGFloat = 0.84
    private let panDragNoiseFloor: CGFloat = 0.16
    private let maxVerticalScale: CGFloat = 5.0
    private let minHorizontalScale: CGFloat = 0.15
    private let maxHorizontalScale: CGFloat = 3.0

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = max(1, geometry.size.width - yAxisWidth)
            let panelHeight = max(1, geometry.size.height)

            content()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(bodyPanGesture(chartWidth: chartWidth, panelHeight: panelHeight))
                .simultaneousGesture(bodyPinchGesture(chartWidth: chartWidth))
                .overlay(alignment: .trailing) {
                    Color.clear
                        .frame(width: yAxisWidth)
                        .contentShape(Rectangle())
                        .highPriorityGesture(yAxisDragGesture(panelHeight: panelHeight))
                        .simultaneousGesture(yAxisPinchGesture(panelHeight: panelHeight))
                }
        }
        .onDisappear {
            lastDragTranslation = .zero
            isYAxisGestureActive = false
            isBodyPinchActive = false
        }
    }

    private var totalCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
    }

    private func bodyPanGesture(chartWidth: CGFloat, panelHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isYAxisGestureActive, !isBodyPinchActive else { return }

                if lastDragTranslation == .zero {
                    gestureState.beginDrag()
                }

                let incrementalX = value.translation.width - lastDragTranslation.width
                let incrementalY = value.translation.height - lastDragTranslation.height
                let dampenedX = incrementalX * panDragSensitivity
                let dampenedY = incrementalY * panDragSensitivity
                lastDragTranslation = value.translation

                guard abs(dampenedX) >= panDragNoiseFloor || abs(dampenedY) >= panDragNoiseFloor else {
                    return
                }

                gestureState.applyPan(
                    translation: CGSize(width: dampenedX, height: 0),
                    chartWidth: chartWidth,
                    candleCount: candleCount,
                    candleWidth: totalCandleWidth,
                    chartHeight: panelHeight,
                    priceScale: gestureState.priceScale,
                    trackVelocity: true
                )

                if abs(dampenedY) >= panDragNoiseFloor {
                    verticalState.applyBodyPan(
                        translationY: dampenedY,
                        panelHeight: panelHeight
                    )
                }
            }
            .onEnded { _ in
                gestureState.endDrag(
                    chartWidth: chartWidth,
                    candleCount: candleCount,
                    candleWidth: totalCandleWidth,
                    chartHeight: panelHeight,
                    priceScale: gestureState.priceScale
                )
                lastDragTranslation = .zero
            }
    }

    private func bodyPinchGesture(chartWidth: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !isYAxisGestureActive else { return }

                if !isBodyPinchActive {
                    isBodyPinchActive = true
                    initialCandleWidthScale = gestureState.candleWidthScale
                    initialHorizontalOffset = gestureState.panOffset.width
                    pinchCenterX = chartWidth * 0.5
                }

                let dampenedValue = 1.0 + (value - 1.0) * pinchSensitivity
                let proposedScale = initialCandleWidthScale * dampenedValue
                let clampedScale = min(maxHorizontalScale, max(minHorizontalScale, proposedScale))
                let oldTotalWidth = baseCandleWidth * initialCandleWidthScale + candleSpacing
                let newTotalWidth = baseCandleWidth * clampedScale + candleSpacing
                let totalWidthRatio = newTotalWidth / max(oldTotalWidth, 0.0001)
                let proposedOffset = initialHorizontalOffset * totalWidthRatio + pinchCenterX * (1.0 - totalWidthRatio)

                gestureState.candleWidthScale = clampedScale
                gestureState.panOffset.width = clampedHorizontalPanOffset(
                    proposedOffset: proposedOffset,
                    chartWidth: chartWidth,
                    candleWidthScale: clampedScale
                )
            }
            .onEnded { _ in
                isBodyPinchActive = false
            }
    }

    private func yAxisDragGesture(panelHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isYAxisGestureActive {
                    isYAxisGestureActive = true
                    yAxisDragStart = value.startLocation.y
                    initialPriceScale = verticalState.priceScale
                    initialVerticalOffset = verticalState.verticalPanOffset
                }

                let dragDistance = value.location.y - yAxisDragStart
                let scaleMultiplier = 1.0 - (dragDistance / 300.0) * yAxisSensitivity
                let proposedScale = initialPriceScale * scaleMultiplier

                verticalState.applyPriceScale(
                    proposedScale: proposedScale,
                    initialPriceScale: initialPriceScale,
                    initialVerticalOffset: initialVerticalOffset,
                    anchorY: panelHeight * 0.5,
                    panelHeight: panelHeight,
                    minScale: minVerticalScale,
                    maxScale: maxVerticalScale
                )
            }
            .onEnded { _ in
                isYAxisGestureActive = false
            }
    }

    private func yAxisPinchGesture(panelHeight: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isYAxisGestureActive {
                    isYAxisGestureActive = true
                    initialPriceScale = verticalState.priceScale
                    initialVerticalOffset = verticalState.verticalPanOffset
                }

                let dampenedValue = 1.0 + (value - 1.0) * (yAxisSensitivity * 0.7)
                let proposedScale = initialPriceScale * dampenedValue

                verticalState.applyPriceScale(
                    proposedScale: proposedScale,
                    initialPriceScale: initialPriceScale,
                    initialVerticalOffset: initialVerticalOffset,
                    anchorY: panelHeight * 0.5,
                    panelHeight: panelHeight,
                    minScale: minVerticalScale,
                    maxScale: maxVerticalScale
                )
            }
            .onEnded { _ in
                isYAxisGestureActive = false
            }
    }

    private func clampedHorizontalPanOffset(
        proposedOffset: CGFloat,
        chartWidth: CGFloat,
        candleWidthScale: CGFloat
    ) -> CGFloat {
        let totalWidth = baseCandleWidth * candleWidthScale + candleSpacing
        let totalContentWidth = CGFloat(candleCount) * totalWidth
        let edgePadding = ChartGestureState.horizontalEdgePadding
        let maxOffset = edgePadding
        let minOffset = -(totalContentWidth - chartWidth + edgePadding)
        return min(maxOffset, max(minOffset, proposedOffset))
    }
}

// MARK: - Gesture Modifiers

struct ChartGestureModifier: ViewModifier {
    @ObservedObject var gestureState: ChartGestureState
    let chartData: ChartDataManager
    let geometry: GeometryProxy
    
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) {
                gestureState.reset()
            }
    }
}

extension View {
    func chartGestures(
        gestureState: ChartGestureState,
        chartData: ChartDataManager,
        geometry: GeometryProxy
    ) -> some View {
        self.modifier(
            ChartGestureModifier(
                gestureState: gestureState,
                chartData: chartData,
                geometry: geometry
            )
        )
    }
}
