//
//  ChartControlViewModel.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/11/2025.
//

//
//  ChartControlViewModel.swift
//  traders_guild
//
//  Created by Al Hennessey
//

import SwiftUI
import Combine

/// ViewModel that manages chart control state and actions
/// This is the bridge between the chart view and the bottom sheet controls
/// Ensures proper state synchronization and action delegation
class ChartControlViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether marker placement mode is currently active
    @Published var isMarkerPlacementMode: Bool = false
    
    /// Whether auto-scroll is currently enabled
    @Published var isAutoScrolling: Bool = false
    
    /// Current horizontal zoom level (1.0 = default)
    @Published var horizontalZoom: Double = 1.0
    
    /// Current vertical zoom level (1.0 = default)
    @Published var verticalZoom: Double = 1.0
    
    // MARK: - Action Closures
    // These are set by the TradingChartView and called by the bottom sheet
    
    /// Reset all chart transformations to default
    var resetChartAction: (() -> Void)?
    
    /// Jump to the first candle
    var jumpToStartAction: (() -> Void)?
    
    /// Jump to the most recent candle
    var jumpToLatestAction: (() -> Void)?
    
    /// Toggle auto-scroll behavior
    var toggleAutoScrollAction: (() -> Void)?
    
    /// Set horizontal zoom level
    var setHorizontalZoomAction: ((Double) -> Void)?
    
    /// Set vertical zoom level
    var setVerticalZoomAction: ((Double) -> Void)?
    
    // MARK: - Public Methods
    // These are called by the ChartBottomSheet controls
    
    /// Reset the chart view to default state
    func resetChart() {
        resetChartAction?()
        horizontalZoom = 1.0
        verticalZoom = 1.0
    }
    
    /// Navigate to the first candle
    func jumpToStart() {
        jumpToStartAction?()
    }
    
    /// Navigate to the most recent candle
    func jumpToLatest() {
        jumpToLatestAction?()
    }
    
    /// Toggle auto-scroll on/off
    func toggleAutoScroll() {
        toggleAutoScrollAction?()
        isAutoScrolling.toggle()
    }
    
    /// Toggle marker placement mode
    func toggleMarkerPlacement() {
        isMarkerPlacementMode.toggle()
    }
    
    /// Set horizontal zoom level
    /// - Parameter zoom: Zoom level (0.3 to 3.0)
    func setHorizontalZoom(_ zoom: Double) {
        let clampedZoom = min(3.0, max(0.3, zoom))
        horizontalZoom = clampedZoom
        setHorizontalZoomAction?(clampedZoom)
    }
    
    /// Set vertical zoom level
    /// - Parameter zoom: Zoom level (0.5 to 5.0)
    func setVerticalZoom(_ zoom: Double) {
        let clampedZoom = min(5.0, max(0.5, zoom))
        verticalZoom = clampedZoom
        setVerticalZoomAction?(clampedZoom)
    }
    
    // MARK: - Convenience Methods
    
    /// Increase horizontal zoom by 20%
    func zoomInHorizontal() {
        setHorizontalZoom(horizontalZoom * 1.2)
    }
    
    /// Decrease horizontal zoom by 20%
    func zoomOutHorizontal() {
        setHorizontalZoom(horizontalZoom / 1.2)
    }
    
    /// Increase vertical zoom by 20%
    func zoomInVertical() {
        setVerticalZoom(verticalZoom * 1.2)
    }
    
    /// Decrease vertical zoom by 20%
    func zoomOutVertical() {
        setVerticalZoom(verticalZoom / 1.2)
    }
}
