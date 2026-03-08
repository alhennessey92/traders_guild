//
//  ChartControlViewModel.swift
//  traders_guild
//
//  UPDATED VERSION - Now tracks current marker type for placement mode
//

import SwiftUI
import Combine

/// ViewModel that manages chart control state and actions
/// This is the bridge between the chart view and the bottom sheet controls
class ChartControlViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether marker placement mode is currently active
    @Published var isMarkerPlacementMode: Bool = false

    /// Whether marker viewing mode is currently active.
    @Published var isMarkerViewingMode: Bool = false
    
    /// Marker intent currently being placed (nil when not in placement mode).
    @Published var currentMarkerIntent: RLMarkerIntent?
    
    /// Whether auto-scroll is currently enabled
    @Published var isAutoScrolling: Bool = false
    
    /// Current horizontal zoom level (1.0 = default)
    @Published var horizontalZoom: Double = 1.0
    
    /// Current vertical zoom level (1.0 = default)
    @Published var verticalZoom: Double = 1.0
    
    // MARK: - Action Closures
    
    var resetChartAction: (() -> Void)?
    var jumpToStartAction: (() -> Void)?
    var jumpToLatestAction: (() -> Void)?
    var toggleAutoScrollAction: (() -> Void)?
    var setHorizontalZoomAction: ((Double) -> Void)?
    var setVerticalZoomAction: ((Double) -> Void)?
    
    // MARK: - Public Methods
    
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
    
    /// Start marker placement mode with intent.
    func startMarkerPlacement(intent: RLMarkerIntent) {
        currentMarkerIntent = intent
        isMarkerPlacementMode = true
        isMarkerViewingMode = false
    }
    
    /// Cancel marker placement mode
    func cancelMarkerPlacement() {
        isMarkerPlacementMode = false
        currentMarkerIntent = nil
    }
    
    /// Toggle marker placement mode (legacy method for compatibility)
    func toggleMarkerPlacement() {
        if isMarkerPlacementMode {
            cancelMarkerPlacement()
        } else {
            // Default to analysis intent if no intent specified
            startMarkerPlacement(intent: .analysis)
        }
    }
    
    /// Set horizontal zoom level
    func setHorizontalZoom(_ zoom: Double) {
        let clampedZoom = min(3.0, max(0.3, zoom))
        horizontalZoom = clampedZoom
        setHorizontalZoomAction?(clampedZoom)
    }
    
    /// Set vertical zoom level
    func setVerticalZoom(_ zoom: Double) {
        let clampedZoom = min(5.0, max(0.5, zoom))
        verticalZoom = clampedZoom
        setVerticalZoomAction?(clampedZoom)
    }
    
    // MARK: - Convenience Methods
    
    func zoomInHorizontal() {
        setHorizontalZoom(horizontalZoom * 1.2)
    }
    
    func zoomOutHorizontal() {
        setHorizontalZoom(horizontalZoom / 1.2)
    }
    
    func zoomInVertical() {
        setVerticalZoom(verticalZoom * 1.2)
    }
    
    func zoomOutVertical() {
        setVerticalZoom(verticalZoom / 1.2)
    }
}
