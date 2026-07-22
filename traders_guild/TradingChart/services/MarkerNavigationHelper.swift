//
//  MarkerNavigationHelper.swift
//  traders_guild
//
//  Helper for navigating from Top Markers list to chart position
//  Handles symbol switching, timeframe changes, and scroll positioning
//

import SwiftUI

enum MarkerNavigationPhase: Equatable {
    case preparing
    case loadingHistoricalWindow
    case centering
    case settled
    case failed(String)

    var isLoading: Bool {
        switch self {
        case .preparing, .loadingHistoricalWindow, .centering:
            return true
        case .settled, .failed:
            return false
        }
    }

    var title: String {
        switch self {
        case .preparing:
            return "Opening marker"
        case .loadingHistoricalWindow:
            return "Loading marker candles"
        case .centering:
            return "Centering marker"
        case .settled:
            return "Marker ready"
        case .failed:
            return "Marker unavailable"
        }
    }

    var subtitle: String {
        switch self {
        case .preparing:
            return "Preparing chart context"
        case .loadingHistoricalWindow:
            return "Fetching historical candles"
        case .centering:
            return "Moving to marker"
        case .settled:
            return "Marker loaded"
        case .failed(let message):
            return message
        }
    }
}

struct MarkerNavigationTarget: Identifiable {
    let markerId: UUID
    let symbolId: UUID
    let symbolTicker: String?
    let symbolBrandColor: String?
    let symbolAssetClass: String?
    let timeframeRaw: String
    let candleTimestamp: Date
    let price: Double?
    let intent: RLMarkerIntent
    let selectedEmoji: String?
    let alertSeverity: MarkerAlertSeverity?

    var id: UUID { markerId }

    var timeframe: RLChartTimeframe? {
        RLChartTimeframe.fromBackendString(timeframeRaw)
    }

    init(topMarker marker: RLTopMarkerDTO) {
        self.markerId = marker.id
        self.symbolId = marker.symbolId
        self.symbolTicker = marker.symbolTicker
        self.symbolBrandColor = marker.symbolBrandColor
        self.symbolAssetClass = marker.symbolAssetClass
        self.timeframeRaw = marker.timeframe
        self.candleTimestamp = marker.candleTimestamp
        self.price = marker.price
        self.intent = marker.intentEnum
        self.selectedEmoji = marker.selectedEmoji
        self.alertSeverity = MarkerAlertSeverity.resolved(rawValue: marker.alertSeverity)
    }

    init(sharedPayload payload: MarkerSharePayloadV1) {
        self.markerId = payload.markerId
        self.symbolId = payload.symbolId
        self.symbolTicker = payload.symbolTicker
        self.symbolBrandColor = payload.symbolBrandColor
        self.symbolAssetClass = payload.symbolAssetClass
        self.timeframeRaw = payload.timeframe
        self.candleTimestamp = payload.candleTimestamp
        self.price = nil
        self.intent = payload.intentEnum
        self.selectedEmoji = payload.selectedEmojiValue
        self.alertSeverity = payload.alertSeverityEnum
    }
}

struct MarkerNavigationSession: Identifiable {
    let id: UUID
    let target: MarkerNavigationTarget
    var phase: MarkerNavigationPhase

    init(id: UUID = UUID(), target: MarkerNavigationTarget, phase: MarkerNavigationPhase = .preparing) {
        self.id = id
        self.target = target
        self.phase = phase
    }
}

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
    @discardableResult
    func navigateToMarker(
        _ marker: RLTopMarkerDTO,
        chartWidth: CGFloat? = nil,
        completion: (() -> Void)? = nil
    ) -> Bool {
        navigateToMarker(
            MarkerNavigationTarget(topMarker: marker),
            chartWidth: chartWidth,
            resolvedSymbol: nil,
            completion: completion
        )
    }

    @discardableResult
    func navigateToMarker(
        _ target: MarkerNavigationTarget,
        chartWidth: CGFloat? = nil,
        resolvedSymbol: RLTradingSymbolDTO? = nil,
        completion: (() -> Void)? = nil
    ) -> Bool {
        print("🎯 === MARKER NAVIGATION START ===")
        print("🎯 Target: \(target.symbolTicker ?? target.symbolId.uuidString) | Timeframe: \(target.timeframeRaw) | Timestamp: \(target.candleTimestamp)")
        
        guard let chartViewModel = chartViewModel else {
            print("❌ MarkerNavigationHelper: chartViewModel is nil")
            completion?()
            return false
        }
        
        guard let gestureState = gestureState else {
            print("❌ MarkerNavigationHelper: gestureState is nil")
            completion?()
            return false
        }
        
        // Use provided width or fall back to screen width
        let width = chartWidth ?? UIScreen.main.bounds.width
        print("🎯 Chart width: \(width)")
        
        // Step 1: Check current state
        let currentTicker = chartViewModel.currentSymbol?.ticker ?? "none"
        let currentTimeframe = chartViewModel.currentTimeframe
        print("🎯 Current: \(currentTicker) | \(currentTimeframe.rawValue)")

        let sessionId = chartViewModel.beginMarkerNavigation(target)
        
        // Step 2: Check if we need to change symbol
        let targetSymbol = resolvedSymbol ?? findSymbol(for: target, in: chartViewModel)
        guard let targetSymbol else {
            print("❌ Symbol not found for marker navigation: \(target.symbolTicker ?? target.symbolId.uuidString)")
            chartViewModel.finishMarkerNavigation(
                sessionId: sessionId,
                phase: .failed("Symbol is not available")
            )
            completion?()
            return false
        }

        let needsSymbolChange = chartViewModel.currentSymbol?.id != target.symbolId
        print("🎯 Needs symbol change: \(needsSymbolChange)")
        
        // Step 3: Check if we need to change timeframe
        let markerTimeframe = target.timeframe ?? currentTimeframe
        let needsTimeframeChange = currentTimeframe != markerTimeframe
        print("🎯 Needs timeframe change: \(needsTimeframeChange)")

        // Capture values directly to avoid weak self issues
        let targetMarker = target
        let markerTimestamp = target.candleTimestamp
        let capturedGestureState = gestureState
        let capturedChartViewModel = chartViewModel
        let baseCandleWidth = self.baseCandleWidth
        let candleSpacing = self.candleSpacing
        let needsDataWait = needsSymbolChange || needsTimeframeChange

        Task { @MainActor in
            capturedChartViewModel.updateMarkerNavigationPhase(sessionId: sessionId, phase: .preparing)

            let prepared = await capturedChartViewModel.prepareForMarkerNavigation(
                target,
                symbol: targetSymbol,
                timeframe: markerTimeframe
            )
            guard prepared else {
                capturedChartViewModel.finishMarkerNavigation(
                    sessionId: sessionId,
                    phase: .failed("Chart context could not load")
                )
                completion?()
                return
            }
            guard capturedChartViewModel.isMarkerNavigationSessionActive(sessionId) else { return }

            if needsDataWait {
                print("🎯 Waiting for target timeframe data to arrive...")
                let deadline = Date().addingTimeInterval(3.0)
                while Date() < deadline {
                    let tfMatches = capturedChartViewModel.currentTimeframe == markerTimeframe
                    let candles = capturedChartViewModel.dataManager.candles
                    let inRange = !candles.isEmpty
                        && !Self.requiresHistoricalWindow(for: targetMarker, in: candles)
                    if tfMatches && inRange { break }
                    if tfMatches && !candles.isEmpty {
                        // Timeframe and candles arrived but marker is outside window - break
                        // out so we can explicitly load the historical slice below.
                        break
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            } else {
                // Same symbol+timeframe: brief yield so any in-flight UI work settles.
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            if Self.requiresHistoricalWindow(for: targetMarker, in: capturedChartViewModel.dataManager.candles) {
                print("🎯 Target lies outside current candle window - loading historical slice")
                capturedChartViewModel.updateMarkerNavigationPhase(sessionId: sessionId, phase: .loadingHistoricalWindow)
                await capturedChartViewModel.loadNavigationWindow(
                    around: markerTimestamp,
                    timeframe: markerTimeframe
                )
            }
            guard capturedChartViewModel.isMarkerNavigationSessionActive(sessionId) else { return }

            // Wait for the candle array to STABILIZE: setSymbol+setTimeframe often fire
            // multiple back-to-back fetches (initial load, refresh, historical merge), each
            // replacing the array. If we center while the array is still churning, the
            // computed pan offset becomes stale (target index in old array maps to off-screen
            // position in new array, which then gets clamped to the chart edge).
            // Stability = candle count unchanged for 400ms, with a 4s overall cap.
            print("🎯 Waiting for candle count to stabilize...")
            var lastSignature = Self.candleWindowSignature(capturedChartViewModel.dataManager.candles)
            var stableSince = Date()
            let stabilityDeadline = Date().addingTimeInterval(4.0)
            while Date() < stabilityDeadline {
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
                let currentSignature = Self.candleWindowSignature(capturedChartViewModel.dataManager.candles)
                if currentSignature != lastSignature {
                    lastSignature = currentSignature
                    stableSince = Date()
                } else if Date().timeIntervalSince(stableSince) >= 0.4 {
                    break
                }
            }

            let candles = capturedChartViewModel.dataManager.candles
            guard capturedChartViewModel.isMarkerNavigationSessionActive(sessionId) else { return }
            print("🎯 After wait - finding candle for timestamp \(markerTimestamp)")
            print("🎯 Current symbol after wait: \(capturedChartViewModel.currentSymbol?.ticker ?? "none")")
            print("🎯 Current timeframe after wait: \(capturedChartViewModel.currentTimeframe.rawValue)")
            print("🎯 Candle count: \(candles.count)")

            // Center the chart now, and capture the params we'll need for re-centering if more
            // data arrives during the settle window.
            capturedChartViewModel.updateMarkerNavigationPhase(sessionId: sessionId, phase: .centering)
            Self.centerChart(
                on: targetMarker,
                markerTimestamp: markerTimestamp,
                gestureState: capturedGestureState,
                chartViewModel: capturedChartViewModel,
                chartWidth: width,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing
            )

            let matchedMarker = await Self.waitForMarkerForDetail(
                targetMarker,
                in: capturedChartViewModel,
                timeout: 5.0
            )
            guard capturedChartViewModel.isMarkerNavigationSessionActive(sessionId) else { return }
            if let matchedMarker {
                capturedChartViewModel.markerManager?.selectedMarker = matchedMarker
            }

            print("🎯 Current panOffset after: \(capturedGestureState.panOffset.width)")
            print("🎯 === MARKER NAVIGATION COMPLETE ===")

            // Re-center for the next 1.5s on every candle-array change. Late-arriving fetches
            // (e.g. an initial-load response that lands after our stability window) replace the
            // candle array and shift the marker's index; without re-centering, panOffset
            // ends up clamped to the chart edge.
            let watchDeadline = Date().addingTimeInterval(1.5)
            var watchedSignature = Self.candleWindowSignature(capturedChartViewModel.dataManager.candles)
            while Date() < watchDeadline {
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard capturedChartViewModel.isMarkerNavigationSessionActive(sessionId) else { return }
                let nowSignature = Self.candleWindowSignature(capturedChartViewModel.dataManager.candles)
                if nowSignature != watchedSignature {
                    watchedSignature = nowSignature
                    Self.centerChart(
                        on: targetMarker,
                        markerTimestamp: markerTimestamp,
                        gestureState: capturedGestureState,
                        chartViewModel: capturedChartViewModel,
                        chartWidth: width,
                        baseCandleWidth: baseCandleWidth,
                        candleSpacing: candleSpacing
                    )
                }
            }

            if matchedMarker == nil {
                capturedChartViewModel.finishMarkerNavigation(
                    sessionId: sessionId,
                    phase: .failed("Marker data did not load")
                )
            } else {
                capturedChartViewModel.finishMarkerNavigation(
                    sessionId: sessionId,
                    phase: .settled
                )
            }
            completion?()
        }
        return true
    }

    /// Compute target candle index from the marker timestamp against the CURRENT candle array
    /// and snap the chart to it instantly. Safe to call repeatedly as the array changes.
    private static func centerChart(
        on targetMarker: MarkerNavigationTarget,
        markerTimestamp: Date,
        gestureState: ChartGestureState,
        chartViewModel: ChartViewModel,
        chartWidth: CGFloat,
        baseCandleWidth: CGFloat,
        candleSpacing: CGFloat
    ) {
        let candles = chartViewModel.dataManager.candles
        guard !candles.isEmpty else { return }

        let scaledCandleWidth = baseCandleWidth * gestureState.candleWidthScale
        let totalCandleWidth = scaledCandleWidth + candleSpacing
        guard totalCandleWidth > 0, chartWidth > 0 else { return }

        let targetCandleIndex: Int
        if let foundIndex = findCandleIndex(forTimestamp: markerTimestamp, in: candles) {
            targetCandleIndex = foundIndex
        } else {
            targetCandleIndex = max(0, candles.count - 50)
        }

        let historicalRenderIndexOffset = chartViewModel.dataManager.historicalRenderIndexOffset
        let chartHeight = UIScreen.main.bounds.height * 0.6
        let oldPriceRange = chartViewModel.dataManager.priceRange
        let oldVerticalOffset = gestureState.verticalPanOffset
        let anchorPrice = targetMarker.price ?? candles[targetCandleIndex].close
        chartViewModel.dataManager.focusDeferredHistoricalPriceRangeIfNeeded(
            forCandleIndex: targetCandleIndex,
            visibleCandleCount: max(1, Int(ceil(chartWidth / totalCandleWidth)))
        )

        let priceRange = chartViewModel.dataManager.priceRange
        if oldPriceRange.max > oldPriceRange.min,
           priceRange.max > priceRange.min {
            let oldNormalized = (anchorPrice - oldPriceRange.min) / (oldPriceRange.max - oldPriceRange.min)
            let newNormalized = (anchorPrice - priceRange.min) / (priceRange.max - priceRange.min)
            if oldNormalized.isFinite, newNormalized.isFinite {
                let scaledHeight = chartHeight * gestureState.priceScale
                gestureState.verticalPanOffset = oldVerticalOffset + CGFloat(oldNormalized - newNormalized) * scaledHeight
            }
        }

        if priceRange.max > priceRange.min {
            let focusMarker = chartViewModel.markerManager.flatMap { manager in
                matchingMarkerForNavigation(targetMarker, markers: manager.markers)
            }
            let focusPrice = focusMarker.flatMap { marker in
                MarkerFocusHelper.renderedGlyphFocusPrice(
                    marker: marker,
                    candles: candles,
                    chartSize: CGSize(width: chartWidth, height: chartHeight),
                    priceRange: priceRange,
                    priceScale: gestureState.priceScale,
                    verticalOffset: gestureState.verticalPanOffset,
                    totalCandleWidth: totalCandleWidth,
                    actualCandleWidth: scaledCandleWidth,
                    totalOffset: gestureState.panOffset.width - CGFloat(historicalRenderIndexOffset) * totalCandleWidth
                )
            } ?? targetMarker.price ?? candles[targetCandleIndex].close

            gestureState.animateCenterOnMarker(
                at: targetCandleIndex,
                chartWidth: chartWidth,
                candleWidth: totalCandleWidth,
                price: focusPrice,
                chartHeight: chartHeight,
                priceRange: priceRange,
                historicalRenderIndexOffset: historicalRenderIndexOffset,
                duration: 0.85
            )
        } else {
            gestureState.centerOnCandle(
                at: targetCandleIndex,
                chartWidth: chartWidth,
                candleWidth: totalCandleWidth,
                historicalRenderIndexOffset: historicalRenderIndexOffset
            )
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

    /// Try to select a marker on chart after symbol/timeframe navigation completes.
    /// Retries because marker arrays can populate shortly after candles.
    private static func waitForMarkerForDetail(
        _ target: MarkerNavigationTarget,
        in chartViewModel: ChartViewModel,
        timeout: TimeInterval
    ) async -> ChartMarkerUI? {
        guard let markerManager = chartViewModel.markerManager else { return nil }
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            markerManager.recalculateCandleIndices(candles: chartViewModel.dataManager.candles)
            if let exactMatch = matchingMarkerForNavigation(target, markers: markerManager.markers) {
                return exactMatch
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        return matchingMarkerForNavigation(target, markers: markerManager.markers)
    }

    private static func matchingMarkerForNavigation(
        _ target: MarkerNavigationTarget,
        markers: [ChartMarkerUI]
    ) -> ChartMarkerUI? {
        if let exactMatch = markers.first(where: { $0.id == target.markerId }) {
            return exactMatch
        }

        let closeTimeAndTypeMatches = markers.filter { marker in
            let timestampDiff = abs(marker.candleTimestamp.timeIntervalSince(target.candleTimestamp))
            return timestampDiff < 1 && marker.intent == target.intent
        }

        guard let targetPrice = target.price else {
            return closeTimeAndTypeMatches.first
        }

        return closeTimeAndTypeMatches.min(by: { lhs, rhs in
            abs(lhs.price - targetPrice) < abs(rhs.price - targetPrice)
        })
    }

    private static func requiresHistoricalWindow(
        for target: MarkerNavigationTarget,
        in candles: [RLCandleDTO]
    ) -> Bool {
        guard let firstTimestamp = candles.first?.timestamp,
              let lastTimestamp = candles.last?.timestamp else {
            return true
        }

        return target.candleTimestamp < firstTimestamp || target.candleTimestamp > lastTimestamp
    }

    private static func candleWindowSignature(_ candles: [RLCandleDTO]) -> String {
        "\(candles.count)|\(candles.first?.timestamp.timeIntervalSince1970 ?? 0)|\(candles.last?.timestamp.timeIntervalSince1970 ?? 0)"
    }
    
    // MARK: - Private Methods
    
    /// Find a symbol by ticker in the view model's watchlists or SampleData
    private func findSymbol(for target: MarkerNavigationTarget, in viewModel: ChartViewModel) -> RLTradingSymbolDTO? {
        print("🔍 Looking for symbol: \(target.symbolTicker ?? target.symbolId.uuidString)")

        let allSymbols = viewModel.allAvailableSymbols
        if let symbol = allSymbols.first(where: { $0.id == target.symbolId }) {
            print("🔍 Found by symbolId")
            return symbol
        }

        guard let ticker = target.symbolTicker else {
            print("🔍 Symbol ticker missing and id not found: \(target.symbolId)")
            return nil
        }
        
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
        withAnimation(.easeInOut(duration: 0.8)) {
            gestureState.centerOnCandle(
                at: index,
                chartWidth: chartWidth,
                candleWidth: totalCandleWidth,
                historicalRenderIndexOffset: chartViewModel?.dataManager.historicalRenderIndexOffset ?? 0
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
