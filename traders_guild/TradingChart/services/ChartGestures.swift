//
//  ChartGestures_FIXED.swift
//  traders_guild
//
//  FIXED VERSION:
//  - Removed spring animation from reset()
//  - Made vertical padding consistent with TradingChartView
//  - Symmetric boundaries for ceiling/floor
//

import SwiftUI

/// Manages the state of all gestures for the trading chart
/// This centralizes all transformation logic for pan and zoom
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
    
    // MARK: - Configuration Constants
    
    let minCandleScale: CGFloat = 0.3
    let maxCandleScale: CGFloat = 3.0
    let minPriceScale: CGFloat = 0.5
    let maxPriceScale: CGFloat = 3.0
    
    // MARK: - Methods
    
    /// Apply pan gesture with boundary limits
    /// FIXED: Vertical padding now matches clampedVerticalOffset calculation
    func applyPan(translation: CGSize, chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat, chartHeight: CGFloat, priceScale: CGFloat) {
        var newHorizontalOffset = panOffset.width + translation.width
        var newVerticalOffset = verticalPanOffset + translation.height
        
        // Horizontal limits
        let edgePadding: CGFloat = 100
        let totalChartWidth = CGFloat(candleCount) * candleWidth
        let maxHorizontalOffset = edgePadding
        let minHorizontalOffset = -(totalChartWidth - chartWidth + edgePadding)
        
        newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
        
        // FIXED: Vertical limits - MUST match clampedVerticalOffset exactly!
        // Using same formula: scaledHeight * baseMultiplier * zoomAdjustment
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
        
        // SYMMETRIC limits - same distance up and down
        newVerticalOffset = Swift.min(verticalPadding, Swift.max(-verticalPadding, newVerticalOffset))
        
        // Update state
        panOffset.width = newHorizontalOffset
        verticalPanOffset = newVerticalOffset
    }
    
    /// Apply horizontal scale
    func applyHorizontalScale(_ scale: CGFloat) {
        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, scale))
    }
    
    /// Apply vertical scale
    func applyVerticalScale(_ scale: CGFloat) {
        priceScale = Swift.min(maxPriceScale, Swift.max(minPriceScale, scale))
    }
    
    /// Reset all gesture states to default
    /// FIXED: NO ANIMATION - instant reset
    func reset() {
        candleWidthScale = 1.0
        priceScale = 1.0
        panOffset = .zero
        verticalPanOffset = 0
    }
    
    /// Center chart on specific candle index
    /// FIXED: No spring animation
    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat) {
        let targetX = CGFloat(index) * candleWidth
        let centerOffset = chartWidth / 2
        panOffset.width = centerOffset - targetX - (candleWidth / 2)
    }
    
    /// Zoom to fit a specific number of candles
    /// FIXED: No spring animation
    func zoomToFitCandles(count: Int, chartWidth: CGFloat, baseCandleWidth: CGFloat) {
        let desiredTotalWidth = chartWidth
        let currentTotalWidth = CGFloat(count) * (baseCandleWidth + 4)
        let requiredScale = desiredTotalWidth / currentTotalWidth
        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, requiredScale))
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





