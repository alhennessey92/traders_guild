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

// MARK: - Usage Example in TradingChartView

/*
 In TradingChartView.swift, add this property:
 
 @ObservedObject var controlViewModel: ChartControlViewModel
 
 Then in the body's .onAppear:
 
 .onAppear {
     // Set up action closures
     controlViewModel.resetChartAction = { [weak gestureState] in
         gestureState?.reset()
     }
     
     controlViewModel.jumpToStartAction = { [weak gestureState] in
         withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
             gestureState?.panOffset.width = 0
         }
     }
     
     controlViewModel.jumpToLatestAction = { [weak chartData, weak gestureState] in
         guard let candles = chartData?.candles, !candles.isEmpty else { return }
         let targetOffset = -CGFloat(candles.count - 1) * totalCandleWidth + 100
         withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
             gestureState?.panOffset.width = targetOffset
         }
     }
     
     controlViewModel.toggleAutoScrollAction = { [weak navigationManager] in
         navigationManager?.isAutoScrolling.toggle()
     }
     
     controlViewModel.setHorizontalZoomAction = { [weak gestureState] zoom in
         withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
             gestureState?.candleWidthScale = CGFloat(zoom)
         }
     }
     
     controlViewModel.setVerticalZoomAction = { [weak gestureState] zoom in
         withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
             gestureState?.priceScale = CGFloat(zoom)
         }
     }
     
     // Start generating data
     chartData.startDataGeneration()
 }
 
 And replace isMarkerPlacementMode state with:
 
 var isMarkerPlacementMode: Bool {
     controlViewModel.isMarkerPlacementMode
 }
*/

// MARK: - Usage Example in MainView

/*
 In MainView.swift, add this property:
 
 @StateObject private var chartControlVM = ChartControlViewModel()
 
 Then pass it to both views:
 
 TradingChartView(
     userId: appState.currentUser?.id ?? "user123",
     username: appState.currentUser?.username ?? "TestUser",
     guildId: appState.currentGuild?.id ?? "guild1",
     controlViewModel: chartControlVM
 )
 
 And in the sheet:
 
 .sheet(isPresented: ...) {
     ChartBottomSheet(
         selectedDetent: $selectedDetent,
         controlViewModel: chartControlVM
     )
     // ... presentation modifiers
 }
*/

// MARK: - Usage Example in ChartBottomSheet

/*
 In ChartBottomSheet, add this property:
 
 @ObservedObject var controlViewModel: ChartControlViewModel
 
 Then use it in the controls:
 
 // Marker placement button
 ChartControlButton(
     title: controlViewModel.isMarkerPlacementMode ? "Cancel Marker" : "Place Marker",
     icon: controlViewModel.isMarkerPlacementMode ? "mappin.circle.fill" : "mappin.circle",
     color: controlViewModel.isMarkerPlacementMode ? .blue : .green,
     isActive: controlViewModel.isMarkerPlacementMode
 ) {
     controlViewModel.toggleMarkerPlacement()
 }
 
 // Reset button
 ChartControlButton(
     title: "Reset View",
     icon: "arrow.counterclockwise",
     color: .purple
 ) {
     controlViewModel.resetChart()
 }
 
 // Jump to start
 ChartControlButton(
     title: "Start",
     icon: "arrow.left.to.line",
     color: .blue
 ) {
     controlViewModel.jumpToStart()
 }
 
 // Jump to latest
 ChartControlButton(
     title: "Latest",
     icon: "arrow.right.to.line",
     color: .blue
 ) {
     controlViewModel.jumpToLatest()
 }
 
 // Auto-scroll toggle
 ChartControlButton(
     title: "Auto-Scroll",
     icon: "arrow.right.circle",
     color: .indigo,
     isActive: controlViewModel.isAutoScrolling
 ) {
     controlViewModel.toggleAutoScroll()
 }
 
 // Zoom sliders (optional advanced controls)
 VStack(spacing: 12) {
     HStack {
         Text("Horizontal Zoom")
             .font(.caption)
             .foregroundColor(.white.opacity(0.8))
         Spacer()
         Slider(
             value: Binding(
                 get: { controlViewModel.horizontalZoom },
                 set: { controlViewModel.setHorizontalZoom($0) }
             ),
             in: 0.3...3.0
         )
         .frame(width: 150)
     }
     
     HStack {
         Text("Vertical Scale")
             .font(.caption)
             .foregroundColor(.white.opacity(0.8))
         Spacer()
         Slider(
             value: Binding(
                 get: { controlViewModel.verticalZoom },
                 set: { controlViewModel.setVerticalZoom($0) }
             ),
             in: 0.5...5.0
         )
         .frame(width: 150)
     }
 }
 .padding()
 .background(Color.white.opacity(0.05))
 .cornerRadius(8)
*/
