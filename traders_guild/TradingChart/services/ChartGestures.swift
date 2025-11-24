//
//  ChartGestures.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/11/2025.
//

import SwiftUI

/// Manages the state of all gestures for the trading chart
/// This centralizes all transformation logic for pan and zoom
class ChartGestureState: ObservableObject {
    // MARK: - Published Properties
    
    /// Current scale for candle width (horizontal zoom)
    /// 1.0 = default, <1.0 = zoomed out, >1.0 = zoomed in
    @Published var candleWidthScale: CGFloat = 1.0
    
    /// Current scale for price range (vertical zoom)
    /// Affects how compressed or expanded the price axis appears
    @Published var priceScale: CGFloat = 1.0
    
    /// Horizontal and vertical pan offset
    /// Tracks how far the user has scrolled from origin
    @Published var panOffset: CGSize = .zero
    
    /// Separate vertical pan offset for finer control
    /// Used in addition to panOffset.height
    @Published var verticalPanOffset: CGFloat = 0
    
    // MARK: - Configuration Constants
    
    /// Minimum allowed candle width scale (maximum zoom out)
    let minCandleScale: CGFloat = 0.3
    
    /// Maximum allowed candle width scale (maximum zoom in)
    let maxCandleScale: CGFloat = 3.0
    
    /// Minimum allowed price scale (most compressed view)
    let minPriceScale: CGFloat = 0.5
    
    /// Maximum allowed price scale (most expanded view)
    let maxPriceScale: CGFloat = 3.0
    
    // MARK: - Methods
    
    /// Apply pan gesture with boundary limits
    /// Prevents scrolling too far beyond available data
    func applyPan(translation: CGSize, chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat, chartHeight: CGFloat, priceScale: CGFloat) {
        // Calculate new positions
        var newHorizontalOffset = panOffset.width + translation.width
        var newVerticalOffset = verticalPanOffset + translation.height
        
        // Define edge padding (how far beyond data we allow scrolling)
        let edgePadding: CGFloat = 100
        
        // Calculate total width of all candles
        let totalChartWidth = CGFloat(candleCount) * candleWidth
        
        // Horizontal pan limits
        // Right limit: Can scroll right by edgePadding
        let maxHorizontalOffset = edgePadding
        
        // Left limit: Can see all candles plus edge padding
        let minHorizontalOffset = -(totalChartWidth - chartWidth + edgePadding)
        
        // Apply horizontal constraints
        newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
        
        // Vertical pan limits - based on scaled chart height
        // Allow panning up to 50% of the scaled chart height beyond the visible data
        let scaledHeight = chartHeight * priceScale
        let verticalPadding = scaledHeight * 0.5
        let maxVerticalOffset = verticalPadding
        let minVerticalOffset = -verticalPadding
        
        // Apply vertical constraints
        newVerticalOffset = Swift.min(maxVerticalOffset, Swift.max(minVerticalOffset, newVerticalOffset))
        
        // Update state with constrained values
        panOffset.width = newHorizontalOffset
        verticalPanOffset = newVerticalOffset
    }
    
    /// Apply horizontal scale (from pinch gesture)
    /// Updates candle width within allowed limits
    func applyHorizontalScale(_ scale: CGFloat) {
        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, scale))
    }
    
    /// Apply vertical scale (from Y-axis drag)
    /// Updates price scale within allowed limits
    func applyVerticalScale(_ scale: CGFloat) {
        priceScale = Swift.min(maxPriceScale, Swift.max(minPriceScale, scale))
    }
    
    /// Reset all gesture states to default
    /// Useful for "reset zoom" functionality
    func reset() {
        withAnimation(.spring()) {
            candleWidthScale = 1.0
            priceScale = 1.0
            panOffset = .zero
            verticalPanOffset = 0
        }
    }
    
    /// Center chart on specific candle index
    /// Useful for jumping to specific times or events
    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat) {
        let targetX = CGFloat(index) * candleWidth
        let centerOffset = chartWidth / 2
        
        withAnimation(.spring()) {
            panOffset.width = centerOffset - targetX - (candleWidth / 2)
        }
    }
    
    /// Zoom to fit a specific number of candles
    /// Useful for preset zoom levels (e.g., "show 50 candles")
    func zoomToFitCandles(count: Int, chartWidth: CGFloat, baseCandleWidth: CGFloat) {
        let desiredTotalWidth = chartWidth
        let currentTotalWidth = CGFloat(count) * (baseCandleWidth + 4) // 4 is spacing
        let requiredScale = desiredTotalWidth / currentTotalWidth
        
        withAnimation(.spring()) {
            candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, requiredScale))
        }
    }
}

// MARK: - Gesture Modifiers

/// Custom view modifier for handling chart-specific gestures
struct ChartGestureModifier: ViewModifier {
    @ObservedObject var gestureState: ChartGestureState
    let chartData: ChartDataManager
    let geometry: GeometryProxy
    
    func body(content: Content) -> some View {
        content
            // Add double tap to reset zoom
            .onTapGesture(count: 2) {
                gestureState.reset()
            }
            // Add keyboard shortcuts for zoom
            .onAppear {
                // Could add keyboard event handling here if needed
            }
    }
}

// MARK: - Helper Extensions

extension View {
    /// Add chart gesture handling to any view
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

//import SwiftUI
//
///// Manages the state of all gestures for the trading chart
///// This centralizes all transformation logic for pan and zoom
//class ChartGestureState: ObservableObject {
//    // MARK: - Published Properties
//    
//    /// Current scale for candle width (horizontal zoom)
//    /// 1.0 = default, <1.0 = zoomed out, >1.0 = zoomed in
//    @Published var candleWidthScale: CGFloat = 1.0
//    
//    /// Current scale for price range (vertical zoom)
//    /// Affects how compressed or expanded the price axis appears
//    @Published var priceScale: CGFloat = 1.0
//    
//    /// Horizontal and vertical pan offset
//    /// Tracks how far the user has scrolled from origin
//    @Published var panOffset: CGSize = .zero
//    
//    /// Separate vertical pan offset for finer control
//    /// Used in addition to panOffset.height
//    @Published var verticalPanOffset: CGFloat = 0
//    
//    // MARK: - Configuration Constants
//    
//    /// Minimum allowed candle width scale (maximum zoom out)
//    let minCandleScale: CGFloat = 0.3
//    
//    /// Maximum allowed candle width scale (maximum zoom in)
//    let maxCandleScale: CGFloat = 3.0
//    
//    /// Minimum allowed price scale (most compressed view)
//    let minPriceScale: CGFloat = 0.5
//    
//    /// Maximum allowed price scale (most expanded view)
//    let maxPriceScale: CGFloat = 3.0
//    
//    // MARK: - Methods
//    
//    /// Apply pan gesture with boundary limits
//    /// Prevents scrolling too far beyond available data
//    func applyPan(translation: CGSize, chartWidth: CGFloat, candleCount: Int, candleWidth: CGFloat) {
//        // Calculate new positions
//        var newHorizontalOffset = panOffset.width + translation.width
//        var newVerticalOffset = verticalPanOffset + translation.height
//        
//        // Define edge padding (how far beyond data we allow scrolling)
//        let edgePadding: CGFloat = 100
//        
//        // Calculate total width of all candles
//        let totalChartWidth = CGFloat(candleCount) * candleWidth
//        
//        // Horizontal pan limits
//        // Right limit: Can scroll right by edgePadding
//        let maxHorizontalOffset = edgePadding
//        
//        // Left limit: Can see all candles plus edge padding
//        let minHorizontalOffset = -(totalChartWidth - chartWidth + edgePadding)
//        
//        // Apply horizontal constraints
//        newHorizontalOffset = Swift.min(maxHorizontalOffset, Swift.max(minHorizontalOffset, newHorizontalOffset))
//        
//        // Vertical pan limits - much more generous to allow free vertical exploration
//        // Allow panning several screen heights in either direction
//        let maxVerticalOffset: CGFloat = 2000
//        let minVerticalOffset: CGFloat = -2000
//        
//        // Apply vertical constraints
//        newVerticalOffset = Swift.min(maxVerticalOffset, Swift.max(minVerticalOffset, newVerticalOffset))
//        
//        // Update state with constrained values
//        panOffset.width = newHorizontalOffset
//        verticalPanOffset = newVerticalOffset
//    }
//    
//    /// Apply horizontal scale (from pinch gesture)
//    /// Updates candle width within allowed limits
//    func applyHorizontalScale(_ scale: CGFloat) {
//        candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, scale))
//    }
//    
//    /// Apply vertical scale (from Y-axis drag)
//    /// Updates price scale within allowed limits
//    func applyVerticalScale(_ scale: CGFloat) {
//        priceScale = Swift.min(maxPriceScale, Swift.max(minPriceScale, scale))
//    }
//    
//    /// Reset all gesture states to default
//    /// Useful for "reset zoom" functionality
//    func reset() {
//        withAnimation(.spring()) {
//            candleWidthScale = 1.0
//            priceScale = 1.0
//            panOffset = .zero
//            verticalPanOffset = 0
//        }
//    }
//    
//    /// Center chart on specific candle index
//    /// Useful for jumping to specific times or events
//    func centerOnCandle(at index: Int, chartWidth: CGFloat, candleWidth: CGFloat) {
//        let targetX = CGFloat(index) * candleWidth
//        let centerOffset = chartWidth / 2
//        
//        withAnimation(.spring()) {
//            panOffset.width = centerOffset - targetX - (candleWidth / 2)
//        }
//    }
//    
//    /// Zoom to fit a specific number of candles
//    /// Useful for preset zoom levels (e.g., "show 50 candles")
//    func zoomToFitCandles(count: Int, chartWidth: CGFloat, baseCandleWidth: CGFloat) {
//        let desiredTotalWidth = chartWidth
//        let currentTotalWidth = CGFloat(count) * (baseCandleWidth + 4) // 4 is spacing
//        let requiredScale = desiredTotalWidth / currentTotalWidth
//        
//        withAnimation(.spring()) {
//            candleWidthScale = Swift.min(maxCandleScale, Swift.max(minCandleScale, requiredScale))
//        }
//    }
//}
//
//// MARK: - Gesture Modifiers
//
///// Custom view modifier for handling chart-specific gestures
//struct ChartGestureModifier: ViewModifier {
//    @ObservedObject var gestureState: ChartGestureState
//    let chartData: ChartDataManager
//    let geometry: GeometryProxy
//    
//    func body(content: Content) -> some View {
//        content
//            // Add double tap to reset zoom
//            .onTapGesture(count: 2) {
//                gestureState.reset()
//            }
//            // Add keyboard shortcuts for zoom
//            .onAppear {
//                // Could add keyboard event handling here if needed
//            }
//    }
//}
//
//// MARK: - Helper Extensions
//
//extension View {
//    /// Add chart gesture handling to any view
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
