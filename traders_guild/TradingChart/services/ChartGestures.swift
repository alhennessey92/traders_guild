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

/// Manages the state of all gestures for the trading chart
/// IMPORTANT: This should be instantiated as @StateObject in TradingChartView
/// for optimal performance. Do NOT route through ChartViewModel's @Published properties.
class ChartGestureState: ObservableObject {
    // MARK: - Published Properties
    
    /// Current scale for candle width (horizontal zoom)
    @Published var candleWidthScale: CGFloat = 1.0
    
    /// Current scale for price range (vertical zoom)
    @Published var priceScale: CGFloat = 1.0
    
    /// Horizontal and vertical pan offset
    @Published var panOffset: CGSize = .zero
    
    /// Separate vertical pan offset for finer control
    @Published var verticalPanOffset: CGFloat = 0
    
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
    private let decelerationRate: CGFloat = 0.92
    
    /// Minimum velocity to continue momentum (points per second)
    private let minimumVelocity: CGFloat = 10
    
    /// Cached chart dimensions for momentum bounds checking
    private var cachedChartWidth: CGFloat = 0
    private var cachedChartHeight: CGFloat = 0
    private var cachedCandleCount: Int = 0
    private var cachedCandleWidth: CGFloat = 0
    
    // MARK: - Configuration Constants
    
    let minCandleScale: CGFloat = 0.3
    let maxCandleScale: CGFloat = 3.0
    let minPriceScale: CGFloat = 0.5
    let maxPriceScale: CGFloat = 3.0
    
    // MARK: - Initialization
    
    deinit {
        stopMomentum()
    }
    
    // MARK: - Pan Methods
    
    /// Begin a drag gesture - call this in onChanged when drag starts
    func beginDrag() {
        stopMomentum()
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
        trackVelocity: Bool = true
    ) {
        // Cache dimensions for momentum
        cachedChartWidth = chartWidth
        cachedChartHeight = chartHeight
        cachedCandleCount = candleCount
        cachedCandleWidth = candleWidth
        
        // Calculate velocity if tracking
        if trackVelocity, let lastTime = lastDragTime {
            let now = Date()
            let dt = now.timeIntervalSince(lastTime)
            if dt > 0 && dt < 0.1 { // Only track reasonable intervals
                let dx = translation.width - lastDragTranslation.width
                let dy = translation.height - lastDragTranslation.height
                
                // Exponential moving average for smooth velocity
                let alpha: CGFloat = 0.3
                velocity.width = velocity.width * (1 - alpha) + (dx / CGFloat(dt)) * alpha
                velocity.height = velocity.height * (1 - alpha) + (dy / CGFloat(dt)) * alpha
            }
            lastDragTime = now
            lastDragTranslation = translation
        }
        
        // Apply the pan
        applyPanInternal(
            translation: translation,
            chartWidth: chartWidth,
            candleCount: candleCount,
            candleWidth: candleWidth,
            chartHeight: chartHeight,
            priceScale: priceScale
        )
    }
    
    /// Internal pan application without velocity tracking (used by momentum)
    private func applyPanInternal(
        translation: CGSize,
        chartWidth: CGFloat,
        candleCount: Int,
        candleWidth: CGFloat,
        chartHeight: CGFloat,
        priceScale: CGFloat
    ) {
        var newHorizontalOffset = panOffset.width + translation.width
        var newVerticalOffset = verticalPanOffset + translation.height
        
        // Horizontal limits
        let edgePadding: CGFloat = 100
        let totalChartWidth = CGFloat(candleCount) * candleWidth
        let maxHorizontalOffset = edgePadding
        let minHorizontalOffset = -(totalChartWidth - chartWidth + edgePadding)
        
        newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
        
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
    func endDrag(chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat, chartHeight: CGFloat, priceScale: CGFloat) {
        // Cache final dimensions
        cachedChartWidth = chartWidth
        cachedChartHeight = chartHeight
        cachedCandleCount = candleCount
        cachedCandleWidth = candleWidth
        
        // Only start momentum if velocity is significant
        let speed = hypot(velocity.width, velocity.height)
        if speed > minimumVelocity * 3 {
            startMomentum(priceScale: priceScale)
        } else {
            velocity = .zero
        }
        
        lastDragTime = nil
        lastDragTranslation = .zero
    }
    
    // MARK: - Momentum Animation
    
    private func startMomentum(priceScale: CGFloat) {
        stopMomentum()
        
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
            priceScale: priceScale
        )
    }
    
    func stopMomentum() {
        displayLink?.invalidate()
        displayLink = nil
        velocity = .zero
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
        candleWidthScale = 1.0
        priceScale = 1.0
        panOffset = .zero
        verticalPanOffset = 0
    }
    
    // MARK: - Navigation
    
    /// Center chart on specific candle index
    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat) {
        stopMomentum()
        let targetX = CGFloat(index) * candleWidth
        let centerOffset = chartWidth / 2
        panOffset.width = centerOffset - targetX - (candleWidth / 2)
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












////
////  ChartGestures_FIXED.swift
////  traders_guild
////
////  FIXED VERSION:
////  - Removed spring animation from reset()
////  - Made vertical padding consistent with TradingChartView
////  - Symmetric boundaries for ceiling/floor
////
//
//import SwiftUI
//
///// Manages the state of all gestures for the trading chart
///// This centralizes all transformation logic for pan and zoom
//class ChartGestureState: ObservableObject {
//    // MARK: - Published Properties
//    
//    /// Current scale for candle width (horizontal zoom)
//    @Published var candleWidthScale: CGFloat = 1.0
//    
//    /// Current scale for price range (vertical zoom)
//    @Published var priceScale: CGFloat = 1.0
//    
//    /// Horizontal and vertical pan offset
//    @Published var panOffset: CGSize = .zero
//    
//    /// Separate vertical pan offset for finer control
//    @Published var verticalPanOffset: CGFloat = 0
//    
//    // MARK: - Configuration Constants
//    
//    let minCandleScale: CGFloat = 0.3
//    let maxCandleScale: CGFloat = 3.0
//    let minPriceScale: CGFloat = 0.5
//    let maxPriceScale: CGFloat = 3.0
//    
//    // MARK: - Methods
//    
//    /// Apply pan gesture with boundary limits
//    /// FIXED: Vertical padding now matches clampedVerticalOffset calculation
//    func applyPan(translation: CGSize, chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat, chartHeight: CGFloat, priceScale: CGFloat) {
//        var newHorizontalOffset = panOffset.width + translation.width
//        var newVerticalOffset = verticalPanOffset + translation.height
//        
//        // Horizontal limits
//        let edgePadding: CGFloat = 100
//        let totalChartWidth = CGFloat(candleCount) * candleWidth
//        let maxHorizontalOffset = edgePadding
//        let minHorizontalOffset = -(totalChartWidth - chartWidth + edgePadding)
//        
//        newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
//        
//        // FIXED: Vertical limits - MUST match clampedVerticalOffset exactly!
//        // Using same formula: scaledHeight * baseMultiplier * zoomAdjustment
//        let scaledHeight = chartHeight * priceScale
//        let baseMultiplier: CGFloat = 3.0
//        
//        let zoomAdjustment: CGFloat
//        if priceScale < 0.5 {
//            zoomAdjustment = 4.0
//        } else if priceScale < 0.7 {
//            zoomAdjustment = 3.0
//        } else if priceScale < 0.9 {
//            zoomAdjustment = 2.0
//        } else if priceScale > 2.0 {
//            zoomAdjustment = 2.0
//        } else {
//            zoomAdjustment = 1.5
//        }
//        
//        let verticalPadding = scaledHeight * baseMultiplier * zoomAdjustment
//        
//        // SYMMETRIC limits - same distance up and down
//        newVerticalOffset = Swift.min(verticalPadding, Swift.max(-verticalPadding, newVerticalOffset))
//        
//        // Update state
//        panOffset.width = newHorizontalOffset
//        verticalPanOffset = newVerticalOffset
//    }
//    
//    /// Apply horizontal scale
//    func applyHorizontalScale(_ scale: CGFloat) {
//        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, scale))
//    }
//    
//    /// Apply vertical scale
//    func applyVerticalScale(_ scale: CGFloat) {
//        priceScale = Swift.min(maxPriceScale, Swift.max(minPriceScale, scale))
//    }
//    
//    /// Reset all gesture states to default
//    /// FIXED: NO ANIMATION - instant reset
//    func reset() {
//        candleWidthScale = 1.0
//        priceScale = 1.0
//        panOffset = .zero
//        verticalPanOffset = 0
//    }
//    
//    /// Center chart on specific candle index
//    /// FIXED: No spring animation
//    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat) {
//        let targetX = CGFloat(index) * candleWidth
//        let centerOffset = chartWidth / 2
//        panOffset.width = centerOffset - targetX - (candleWidth / 2)
//    }
//    
//    /// Zoom to fit a specific number of candles
//    /// FIXED: No spring animation
//    func zoomToFitCandles(count: Int, chartWidth: CGFloat, baseCandleWidth: CGFloat) {
//        let desiredTotalWidth = chartWidth
//        let currentTotalWidth = CGFloat(count) * (baseCandleWidth + 4)
//        let requiredScale = desiredTotalWidth / currentTotalWidth
//        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, requiredScale))
//    }
//}
//
//// MARK: - Gesture Modifiers
//
//struct ChartGestureModifier: ViewModifier {
//    @ObservedObject var gestureState: ChartGestureState
//    let chartData: ChartDataManager
//    let geometry: GeometryProxy
//    
//    func body(content: Content) -> some View {
//        content
//            .onTapGesture(count: 2) {
//                gestureState.reset()
//            }
//    }
//}
//
//extension View {
//    func chartGestures(
//        gestureState: ChartGestureState,
//        chartData: ChartDataManager,
//        geometry: GeometryProxy
//    ) -> some View {
//        self.modifier(
//            ChartGestureModifier(
//                gestureState: gestureState,
//                chartData: chartData,
//                geometry: geometry
//            )
//        )
//    }
//}














////
////  ChartGestures_FIXED.swift
////  traders_guild
////
////  FIXED VERSION:
////  - Removed spring animation from reset()
////  - Made vertical padding consistent with TradingChartView
////  - Symmetric boundaries for ceiling/floor
////
//
//import SwiftUI
//
///// Manages the state of all gestures for the trading chart
///// This centralizes all transformation logic for pan and zoom
//class ChartGestureState: ObservableObject {
//    // MARK: - Published Properties
//    
//    /// Current scale for candle width (horizontal zoom)
//    @Published var candleWidthScale: CGFloat = 1.0
//    
//    /// Current scale for price range (vertical zoom)
//    @Published var priceScale: CGFloat = 1.0
//    
//    /// Horizontal and vertical pan offset
//    @Published var panOffset: CGSize = .zero
//    
//    /// Separate vertical pan offset for finer control
//    @Published var verticalPanOffset: CGFloat = 0
//    
//    // MARK: - Configuration Constants
//    
//    let minCandleScale: CGFloat = 0.3
//    let maxCandleScale: CGFloat = 3.0
//    let minPriceScale: CGFloat = 0.5
//    let maxPriceScale: CGFloat = 3.0
//    
//    // MARK: - Methods
//    
//    /// Apply pan gesture with boundary limits
//    /// FIXED: Vertical padding now matches clampedVerticalOffset calculation
//    func applyPan(translation: CGSize, chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat, chartHeight: CGFloat, priceScale: CGFloat) {
//        var newHorizontalOffset = panOffset.width + translation.width
//        var newVerticalOffset = verticalPanOffset + translation.height
//        
//        // Horizontal limits
//        let edgePadding: CGFloat = 100
//        let totalChartWidth = CGFloat(candleCount) * candleWidth
//        let maxHorizontalOffset = edgePadding
//        let minHorizontalOffset = -(totalChartWidth - chartWidth + edgePadding)
//        
//        newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
//        
//        // FIXED: Vertical limits - MUST match clampedVerticalOffset exactly!
//        // Using same formula: scaledHeight * baseMultiplier * zoomAdjustment
//        let scaledHeight = chartHeight * priceScale
//        let baseMultiplier: CGFloat = 3.0
//        
//        let zoomAdjustment: CGFloat
//        if priceScale < 0.5 {
//            zoomAdjustment = 4.0
//        } else if priceScale < 0.7 {
//            zoomAdjustment = 3.0
//        } else if priceScale < 0.9 {
//            zoomAdjustment = 2.0
//        } else if priceScale > 2.0 {
//            zoomAdjustment = 2.0
//        } else {
//            zoomAdjustment = 1.5
//        }
//        
//        let verticalPadding = scaledHeight * baseMultiplier * zoomAdjustment
//        
//        // SYMMETRIC limits - same distance up and down
//        newVerticalOffset = Swift.min(verticalPadding, Swift.max(-verticalPadding, newVerticalOffset))
//        
//        // Update state
//        panOffset.width = newHorizontalOffset
//        verticalPanOffset = newVerticalOffset
//    }
//    
//    /// Apply horizontal scale
//    func applyHorizontalScale(_ scale: CGFloat) {
//        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, scale))
//    }
//    
//    /// Apply vertical scale
//    func applyVerticalScale(_ scale: CGFloat) {
//        priceScale = Swift.min(maxPriceScale, Swift.max(minPriceScale, scale))
//    }
//    
//    /// Reset all gesture states to default
//    /// FIXED: NO ANIMATION - instant reset
//    func reset() {
//        candleWidthScale = 1.0
//        priceScale = 1.0
//        panOffset = .zero
//        verticalPanOffset = 0
//    }
//    
//    /// Center chart on specific candle index
//    /// FIXED: No spring animation
//    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat) {
//        let targetX = CGFloat(index) * candleWidth
//        let centerOffset = chartWidth / 2
//        panOffset.width = centerOffset - targetX - (candleWidth / 2)
//    }
//    
//    /// Zoom to fit a specific number of candles
//    /// FIXED: No spring animation
//    func zoomToFitCandles(count: Int, chartWidth: CGFloat, baseCandleWidth: CGFloat) {
//        let desiredTotalWidth = chartWidth
//        let currentTotalWidth = CGFloat(count) * (baseCandleWidth + 4)
//        let requiredScale = desiredTotalWidth / currentTotalWidth
//        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, requiredScale))
//    }
//}
//
//// MARK: - Gesture Modifiers
//
//struct ChartGestureModifier: ViewModifier {
//    @ObservedObject var gestureState: ChartGestureState
//    let chartData: ChartDataManager
//    let geometry: GeometryProxy
//    
//    func body(content: Content) -> some View {
//        content
//            .onTapGesture(count: 2) {
//                gestureState.reset()
//            }
//    }
//}
//
//extension View {
//    func chartGestures(
//        gestureState: ChartGestureState,
//        chartData: ChartDataManager,
//        geometry: GeometryProxy
//    ) -> some View {
//        self.modifier(
//            ChartGestureModifier(
//                gestureState: gestureState,
//                chartData: chartData,
//                geometry: geometry
//            )
//        )
//    }
//}





