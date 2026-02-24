//
//  MarkerNavigationHelper.swift
//  traders_guild
//
//  Helper for navigating from Top Markers list to chart position
//  Handles symbol switching, timeframe changes, and scroll positioning
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - MARKER NAVIGATION HELPER
// MARK: - ================================================================================================

/// Handles navigation from Top Markers to the chart
/// Coordinates closing drawer, loading symbol, and scrolling to candle
@MainActor
class MarkerNavigationHelper {
    
    // MARK: - Dependencies
    
    private weak var chartViewModel: ChartViewModel?
    private weak var gestureState: ChartGestureState?
    
    // MARK: - Configuration
    
    /// Base candle width (should match TradingChartView)
    private let baseCandleWidth: CGFloat = 12
    
    /// Candle spacing (should match TradingChartView)
    private let candleSpacing: CGFloat = 4
    
    // MARK: - Initialization
    
    init(
        chartViewModel: ChartViewModel?,
        gestureState: ChartGestureState?
    ) {
        self.chartViewModel = chartViewModel
        self.gestureState = gestureState
    }
    
    // MARK: - Navigation
    
    /// Navigate to a marker on the chart
    /// - Parameters:
    ///   - marker: The marker to navigate to
    ///   - chartWidth: Current chart width (uses screen width if nil)
    ///   - completion: Called after navigation completes
    func navigateToMarker(
        _ marker: RLTopMarkerDTO,
        chartWidth: CGFloat? = nil,
        completion: (() -> Void)? = nil
    ) {
        print("🎯 === MARKER NAVIGATION START ===")
        print("🎯 Target: \(marker.symbolTicker) | Timeframe: \(marker.timeframe) | Timestamp: \(marker.candleTimestamp)")
        
        guard let chartViewModel = chartViewModel else {
            print("❌ MarkerNavigationHelper: chartViewModel is nil")
            completion?()
            return
        }
        
        guard let gestureState = gestureState else {
            print("❌ MarkerNavigationHelper: gestureState is nil")
            completion?()
            return
        }
        
        // Use provided width or fall back to screen width
        let width = chartWidth ?? UIScreen.main.bounds.width
        print("🎯 Chart width: \(width)")
        
        // Step 1: Check current state
        let currentTicker = chartViewModel.currentSymbol?.ticker ?? "none"
        let currentTimeframe = chartViewModel.currentTimeframe
        print("🎯 Current: \(currentTicker) | \(currentTimeframe.rawValue)")
        
        // Step 2: Check if we need to change symbol
        let needsSymbolChange = currentTicker != marker.symbolTicker
        print("🎯 Needs symbol change: \(needsSymbolChange)")
        
        // Step 3: Check if we need to change timeframe
        let markerTimeframe = RLChartTimeframe.fromBackendString(marker.timeframe) ?? currentTimeframe
        let needsTimeframeChange = currentTimeframe != markerTimeframe
        print("🎯 Needs timeframe change: \(needsTimeframeChange)")
        
        // Step 4: Perform symbol change if needed
        if needsSymbolChange {
            if let symbol = findSymbol(ticker: marker.symbolTicker, in: chartViewModel) {
                print("✅ Found symbol: \(symbol.ticker) - calling setSymbol")
                chartViewModel.setSymbol(symbol)
            } else {
                print("❌ Symbol not found: \(marker.symbolTicker)")
                print("📋 Available in personalWatchlist: \(chartViewModel.personalWatchlist.map { $0.ticker })")
                print("📋 Available in guildWatchlist: \(chartViewModel.guildWatchlist.map { $0.ticker })")
                print("📋 Available in combinedWatchlist: \(chartViewModel.combinedWatchlist.map { $0.ticker })")
            }
        }
        
        // Step 5: Perform timeframe change if needed
        if needsTimeframeChange {
            print("✅ Setting timeframe to: \(markerTimeframe.rawValue)")
            chartViewModel.setTimeframe(markerTimeframe)
        }
        
        // Step 6: Wait for data to load, then scroll to candle
        let scrollDelay: TimeInterval = (needsSymbolChange || needsTimeframeChange) ? 0.5 : 0.2
        print("🎯 Waiting \(scrollDelay)s for data to load...")
        
        // Capture values directly to avoid weak self issues
        let markerTimestamp = marker.candleTimestamp
        let capturedGestureState = gestureState
        let capturedChartViewModel = chartViewModel
        let baseCandleWidth = self.baseCandleWidth
        let candleSpacing = self.candleSpacing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollDelay) {
            let candles = capturedChartViewModel.dataManager.candles
            print("🎯 After delay - finding candle for timestamp \(markerTimestamp)")
            print("🎯 Current symbol after delay: \(capturedChartViewModel.currentSymbol?.ticker ?? "none")")
            print("🎯 Current timeframe after delay: \(capturedChartViewModel.currentTimeframe.rawValue)")
            print("🎯 Candle count: \(candles.count)")
            
            // Find the candle index that best matches the marker's timestamp
            let targetCandleIndex: Int
            if let foundIndex = Self.findCandleIndex(forTimestamp: markerTimestamp, in: candles) {
                print("🎯 Found candle at index \(foundIndex) for timestamp")
                targetCandleIndex = foundIndex
            } else {
                // Default to showing recent candles if timestamp isn't found
                let safeIndex = max(0, candles.count - 50)
                print("🎯 No candle match found, using safe index: \(safeIndex)")
                targetCandleIndex = safeIndex
            }
            
            print("🎯 Final target candle index: \(targetCandleIndex)")
            if targetCandleIndex < candles.count {
                let targetCandle = candles[targetCandleIndex]
                print("🎯 Target candle timestamp: \(targetCandle.timestamp)")
            }
            
            // Calculate the total candle width including spacing
            let scaledCandleWidth = baseCandleWidth * capturedGestureState.candleWidthScale
            let totalCandleWidth = scaledCandleWidth + candleSpacing
            
            print("🎯 Scroll params: candleWidthScale=\(capturedGestureState.candleWidthScale), totalCandleWidth=\(totalCandleWidth)")
            print("🎯 Current panOffset before: \(capturedGestureState.panOffset.width)")
            
            // Center on candle with smooth animation
            let candle = targetCandleIndex < candles.count ? candles[targetCandleIndex] : nil
            let priceRange = capturedChartViewModel.dataManager.priceRange
            let chartHeight = UIScreen.main.bounds.height * 0.6 // Approximate chart height

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                if let candle = candle, priceRange.max > priceRange.min {
                    capturedGestureState.centerOnMarker(
                        at: targetCandleIndex,
                        chartWidth: width,
                        candleWidth: totalCandleWidth,
                        price: candle.close,
                        chartHeight: chartHeight,
                        priceRange: priceRange
                    )
                } else {
                    capturedGestureState.centerOnCandle(
                        at: targetCandleIndex,
                        chartWidth: width,
                        candleWidth: totalCandleWidth
                    )
                }
            }

            print("🎯 Current panOffset after: \(capturedGestureState.panOffset.width)")
            print("🎯 === MARKER NAVIGATION COMPLETE ===")
            
            completion?()
        }
    }
    
    // MARK: - Private Methods
    
    /// Find the candle index closest to the given timestamp
    private static func findCandleIndex(forTimestamp timestamp: Date, in candles: [RLCandleDTO]) -> Int? {
        guard !candles.isEmpty else { return nil }
        
        // Binary search for efficiency
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
                // Exact match
                return mid
            }
        }
        
        // Only return if we found something reasonably close (within 1 day)
        if minDiff < 86400 {
            return closestIndex
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Find a symbol by ticker in the view model's watchlists or SampleData
    private func findSymbol(ticker: String, in viewModel: ChartViewModel) -> RLTradingSymbolDTO? {
        print("🔍 Looking for symbol: \(ticker)")
        
        // Check personal watchlist first
        if let symbol = viewModel.personalWatchlist.first(where: { $0.ticker == ticker }) {
            print("🔍 Found in personalWatchlist")
            return symbol
        }
        
        // Check guild watchlist
        if let symbol = viewModel.guildWatchlist.first(where: { $0.ticker == ticker }) {
            print("🔍 Found in guildWatchlist")
            return symbol
        }
        
        // Check combined watchlist
        if let symbol = viewModel.combinedWatchlist.first(where: { $0.ticker == ticker }) {
            print("🔍 Found in combinedWatchlist")
            return symbol
        }

        // Check global symbols fallback
        if let symbol = viewModel.globalSymbols.first(where: { $0.ticker == ticker }) {
            print("🔍 Found in globalSymbols")
            return symbol
        }
        
        print("🔍 Symbol not found anywhere: \(ticker)")
        return nil
    }
    
    /// Scroll the chart to center on a specific candle
    private func scrollToCandle(index: Int, chartWidth: CGFloat) {
        guard let gestureState = gestureState else {
            print("❌ scrollToCandle: gestureState is nil")
            return
        }
        
        // Calculate the total candle width including spacing
        let scaledCandleWidth = baseCandleWidth * gestureState.candleWidthScale
        let totalCandleWidth = scaledCandleWidth + candleSpacing
        
        print("🎯 Scroll params: candleWidthScale=\(gestureState.candleWidthScale), totalCandleWidth=\(totalCandleWidth)")
        print("🎯 Current panOffset before: \(gestureState.panOffset.width)")
        
        // Use the gestureState's built-in method with animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gestureState.centerOnCandle(
                at: index,
                chartWidth: chartWidth,
                candleWidth: totalCandleWidth
            )
        }

        print("🎯 Current panOffset after: \(gestureState.panOffset.width)")
    }
}

// MARK: - ================================================================================================
// MARK: - VIEW EXTENSION FOR NAVIGATION
// MARK: - ================================================================================================

/// View modifier that observes LeftDrawerViewModel for marker navigation requests
struct MarkerNavigationObserver: ViewModifier {
    @ObservedObject var leftDrawerViewModel: LeftDrawerViewModel
    let chartViewModel: ChartViewModel
    let gestureState: ChartGestureState
    let onCloseDrawer: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: leftDrawerViewModel.pendingMarkerNavigation) { oldValue, newValue in
                guard let marker = newValue else { return }
                
                print("📍 MarkerNavigationObserver: Detected pending navigation to \(marker.symbolTicker)")
                
                // Close the drawer first
                onCloseDrawer()
                
                // Navigate to the marker after a brief delay for drawer animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("📍 MarkerNavigationObserver: Starting navigation after drawer close delay")
                    
                    let helper = MarkerNavigationHelper(
                        chartViewModel: chartViewModel,
                        gestureState: gestureState
                    )
                    
                    helper.navigateToMarker(marker) {
                        // Clear the pending navigation after handling
                        leftDrawerViewModel.clearPendingNavigation()
                    }
                }
            }
    }
}

extension View {
    /// Observe and handle marker navigation requests from the left drawer
    func observeMarkerNavigation(
        leftDrawerViewModel: LeftDrawerViewModel,
        chartViewModel: ChartViewModel,
        gestureState: ChartGestureState,
        onCloseDrawer: @escaping () -> Void
    ) -> some View {
        self.modifier(
            MarkerNavigationObserver(
                leftDrawerViewModel: leftDrawerViewModel,
                chartViewModel: chartViewModel,
                gestureState: gestureState,
                onCloseDrawer: onCloseDrawer
            )
        )
    }
}

// MARK: - ================================================================================================
// MARK: - USAGE EXAMPLE
// MARK: - ================================================================================================

/*
 
 INTEGRATION IN MAINVIEW
 =======================
 
 Add this modifier to your ZStack in MainView body:
 
 ```swift
 var body: some View {
     if let user = appState.currentUser,
        let guild = appState.currentGuild {
         ZStack {
             // ... all your existing content ...
         }
         .ignoresSafeArea()
         .globalMessaging()
         // ADD THIS:
         .observeMarkerNavigation(
             leftDrawerViewModel: leftDrawerViewModel,
             chartViewModel: chartViewModel,
             gestureState: chartGestureState,
             onCloseDrawer: {
                 withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                     showLeftDrawer = false
                     showOverlay = false
                 }
             }
         )
         // ... rest of modifiers ...
     }
 }
 ```
 
 That's it! When a user taps a marker in TopMarkersView:
 1. TopMarkersView calls leftDrawerViewModel.requestNavigationToMarker(marker)
 2. The observer detects pendingMarkerNavigation change
 3. Drawer closes with animation
 4. Chart loads correct symbol/timeframe
 5. Chart scrolls to center on the candle
 
 */
