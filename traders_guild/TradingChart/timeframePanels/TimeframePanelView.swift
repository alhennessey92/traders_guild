//
//  TimeframePanelView.swift
//  traders_guild
//
//  Timeframe snapshot panel — displays OHLCV candles for a linked timeframe
//  with the marker's time position indicated. Supports independent pan/pinch
//  (not linked to main chart). Matches indicator panel UI pattern.
//

import SwiftUI

struct TimeframePanelPriceViewport {
    let rawPriceRange: (min: Double, max: Double)
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let visualHeight: CGFloat
    let scaleBasisHeight: CGFloat
    let priceScale: CGFloat
    let verticalPanOffset: CGFloat

    var scaleDrawableHeight: CGFloat {
        max(1, scaleBasisHeight - topPadding - bottomPadding)
    }

    var visualDrawableHeight: CGFloat {
        max(1, visualHeight - topPadding - bottomPadding)
    }

    var contentBottomY: CGFloat {
        visualHeight - bottomPadding
    }

    var visualCenterY: CGFloat {
        topPadding + visualDrawableHeight / 2
    }

    var scaleCenterY: CGFloat {
        topPadding + scaleDrawableHeight / 2
    }

    var transformedTopPrice: Double {
        price(atY: topPadding)
    }

    var transformedMidPrice: Double {
        price(atY: visualCenterY)
    }

    var transformedBottomPrice: Double {
        price(atY: contentBottomY)
    }

    func yPosition(for price: Double) -> CGFloat {
        guard rawPriceRange.max > rawPriceRange.min else { return visualCenterY }
        let normalized = (price - rawPriceRange.min) / (rawPriceRange.max - rawPriceRange.min)
        let basisY = topPadding + scaleDrawableHeight * (1.0 - CGFloat(normalized))
        return visualCenterY + (basisY - scaleCenterY) * priceScale + verticalPanOffset
    }

    func price(atY y: CGFloat) -> Double {
        guard rawPriceRange.max > rawPriceRange.min, priceScale > 0 else {
            return rawPriceRange.min
        }

        let unscaledY = ((y - verticalPanOffset - visualCenterY) / priceScale) + scaleCenterY
        let normalized = 1.0 - ((unscaledY - topPadding) / scaleDrawableHeight)
        return rawPriceRange.min + Double(normalized) * (rawPriceRange.max - rawPriceRange.min)
    }
}

struct TimeframePanelLockedViewportResolution: Equatable {
    let candleWidthScale: CGFloat
    let panOffsetWidth: CGFloat
    let centerIndex: Double
}

enum TimeframePanelLockedViewport {
    static func visibleCenterDate(
        mainChartVisibleStart: Date?,
        mainChartVisibleEnd: Date?
    ) -> Date? {
        guard let mainChartVisibleStart,
              let mainChartVisibleEnd,
              mainChartVisibleEnd > mainChartVisibleStart else {
            return nil
        }

        return Date(
            timeIntervalSince1970: (
                mainChartVisibleStart.timeIntervalSince1970
                    + mainChartVisibleEnd.timeIntervalSince1970
            ) / 2
        )
    }

    static func needsOlderCandlesToCenter(
        targetTime: Date,
        candles: [RLCandleDTO],
        hasMoreHistoricalCandles: Bool
    ) -> Bool {
        guard hasMoreHistoricalCandles,
              let firstTimestamp = candles.first?.timestamp else {
            return false
        }

        return targetTime < firstTimestamp
    }

    static func canLockToMainChart(
        panelTimeframeSeconds: TimeInterval,
        mainChartTimeframeSeconds: TimeInterval
    ) -> Bool {
        mainChartTimeframeSeconds <= 0 || panelTimeframeSeconds >= mainChartTimeframeSeconds
    }

    static func resolution(
        candles: [RLCandleDTO],
        timeframeSeconds: TimeInterval,
        mainChartVisibleStart: Date?,
        mainChartVisibleEnd: Date?,
        plotWidth: CGFloat,
        historicalRenderIndexOffset: Int,
        candleWidthScale: CGFloat,
        baseCandleWidth: CGFloat,
        candleSpacing: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) -> TimeframePanelLockedViewportResolution? {
        guard candles.count >= 2,
              timeframeSeconds > 0,
              plotWidth > 0,
              baseCandleWidth > 0,
              let mainChartVisibleStart,
              let mainChartVisibleEnd,
              mainChartVisibleEnd > mainChartVisibleStart else {
            return nil
        }

        let visibleCenterTime = (mainChartVisibleStart.timeIntervalSince1970 + mainChartVisibleEnd.timeIntervalSince1970) / 2
        let rawCenterIndex = fractionalIndex(
            for: Date(timeIntervalSince1970: visibleCenterTime),
            in: candles,
            timeframeSeconds: timeframeSeconds
        )
        let centerIndex = min(Double(candles.count - 1), max(0, rawCenterIndex))
        let scale = min(maxScale, max(minScale, candleWidthScale))
        let totalCandleWidth = baseCandleWidth * scale + candleSpacing
        let actualCandleWidth = baseCandleWidth * scale
        let offset = plotWidth / 2
            - CGFloat(centerIndex - Double(historicalRenderIndexOffset)) * totalCandleWidth
            - actualCandleWidth / 2

        guard scale.isFinite, offset.isFinite else { return nil }
        return TimeframePanelLockedViewportResolution(
            candleWidthScale: scale,
            panOffsetWidth: offset,
            centerIndex: centerIndex
        )
    }

    static func fractionalIndex(
        for date: Date,
        in candles: [RLCandleDTO],
        timeframeSeconds: TimeInterval
    ) -> Double {
        guard let first = candles.first, let last = candles.last else { return 0 }
        let targetTime = date.timeIntervalSince1970
        let safeFrame = max(timeframeSeconds, 1)

        if targetTime <= first.timestamp.timeIntervalSince1970 {
            return (targetTime - first.timestamp.timeIntervalSince1970) / safeFrame
        }

        if targetTime >= last.timestamp.timeIntervalSince1970 {
            return Double(candles.count - 1) + (targetTime - last.timestamp.timeIntervalSince1970) / safeFrame
        }

        var low = 0
        var high = candles.count - 1
        while low < high - 1 {
            let mid = (low + high) / 2
            if candles[mid].timestamp.timeIntervalSince1970 <= targetTime {
                low = mid
            } else {
                high = mid
            }
        }

        let lowTime = candles[low].timestamp.timeIntervalSince1970
        let highTime = candles[high].timestamp.timeIntervalSince1970
        guard highTime > lowTime else { return Double(low) }
        return Double(low) + (targetTime - lowTime) / (highTime - lowTime)
    }

    static func centeredPriceRange(
        candles: [RLCandleDTO],
        centerIndex: Double,
        plotWidth: CGFloat,
        candleWidthScale: CGFloat,
        baseCandleWidth: CGFloat,
        candleSpacing: CGFloat
    ) -> (min: Double, max: Double)? {
        guard !candles.isEmpty,
              plotWidth > 0,
              baseCandleWidth > 0,
              candleWidthScale > 0 else {
            return nil
        }

        let totalWidth = baseCandleWidth * candleWidthScale + candleSpacing
        guard totalWidth > 0 else { return nil }

        let visibleCandleCount = max(8, Int(ceil(plotWidth / totalWidth)))
        let halfWindow = max(4, visibleCandleCount / 2)
        let roundedCenter = Int(round(centerIndex))
        let clampedCenter = min(candles.count - 1, max(0, roundedCenter))
        let startIndex = max(0, clampedCenter - halfWindow)
        let endIndex = min(candles.count, clampedCenter + halfWindow + 1)
        guard startIndex < endIndex else { return nil }

        let visibleCandles = candles[startIndex..<endIndex].filter { !$0.isGapFill }
        guard let minPrice = visibleCandles.map(\.low).min(),
              let maxPrice = visibleCandles.map(\.high).max() else {
            return nil
        }

        let rawRange = maxPrice - minPrice
        let fallbackPadding = max(abs(maxPrice) * 0.01, 0.01)
        let padding = rawRange > 0 ? rawRange * 0.08 : fallbackPadding
        return (minPrice - padding, maxPrice + padding)
    }
}

struct TimeframePanelView: View {
    // MARK: - Properties

    @ObservedObject var entry: TimeframePanelEntry
    @ObservedObject private var dataManager: TimeframePanelDataManager
    @ObservedObject private var gestureState: TimeframePanelGestureState

    let markerTimestamp: Date
    let intentColor: Color
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var mainChartVisibleStart: Date? = nil
    var mainChartVisibleEnd: Date? = nil
    var mainChartTimeframeSeconds: TimeInterval = 0
    var showMarkerLine: Bool = false

    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 250
    var isBottomPanel: Bool = false
    var bottomAxisOverlayTimestamp: Date? = nil
    var bottomAxisOverlayStyle: CrosshairTimeLabelStyle = .standard
    private let priceFormatter: (Double) -> String

    // MARK: - Private State

    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragTranslation: CGSize = .zero
    @State private var isYAxisGestureActive = false
    @State private var isBodyPinchActive = false
    @State private var initialCandleWidthScale: CGFloat = 1.0
    @State private var initialHorizontalOffset: CGFloat = 0
    @State private var pinchCenterX: CGFloat = 0
    @State private var yAxisDragStart: CGFloat = 0
    @State private var initialPriceScale: CGFloat = 1.0
    @State private var initialVerticalOffset: CGFloat = 0
    @State private var hasCenteredOnMarker = false
    @State private var lastKnownChartWidth: CGFloat = UIScreen.main.bounds.width
    @State private var lockedRawPriceRange: (min: Double, max: Double)?
    @State private var isCenteringToMainChartTime = false
    @State private var isLoadingCandlesForMarkerCenter = false
    @State private var centerOperationID = UUID()

    private let livePriceBadgeWidth: CGFloat = 60
    private let livePriceBadgeHeight: CGFloat = 20
    private let livePriceBadgeTrailingInset: CGFloat = 2
    private let yAxisOverlayWidth: CGFloat = 48
    private let yAxisLabelWidth: CGFloat = 44
    private let maxVisibleYAxisLabels = 5
    private let targetYAxisIntervals: Double = 4
    private let livePriceTopClearance: CGFloat = 24
    private let livePriceBottomClearance: CGFloat = 10
    private let pinchSensitivity: CGFloat = 0.7
    private let yAxisSensitivity: CGFloat = 0.7
    private let maxVerticalScale: CGFloat = 5.0
    private let minVerticalScale: CGFloat = 0.5
    private let maxHorizontalScale: CGFloat = 3.0
    private let minHorizontalScale: CGFloat = 0.15
    private let lockedHorizontalFollowScale: CGFloat = 1.0

    // MARK: - Computed

    private var panelHeight: CGFloat {
        entry.currentHeight
    }

    private var isCollapsed: Bool {
        entry.isCollapsed
    }

    private var isLockedToMainChart: Bool {
        entry.isLockedToMainChart
    }

    private var canLockToMainChart: Bool {
        TimeframePanelLockedViewport.canLockToMainChart(
            panelTimeframeSeconds: dataManager.timeframe.seconds,
            mainChartTimeframeSeconds: mainChartTimeframeSeconds
        )
    }

    private var canCenterToMainChart: Bool {
        mainChartVisibleStart != nil && mainChartVisibleEnd != nil && dataManager.candles.count >= 2
    }

    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }

    private var totalCandleWidth: CGFloat {
        actualCandleWidth + candleSpacing
    }

    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }

    private var plotWidth: CGFloat {
        max(1, lastKnownChartWidth - yAxisOverlayWidth)
    }

    private var panelTopPadding: CGFloat {
        18
    }

    private var panelBottomPadding: CGFloat {
        4
    }

    private var transformedViewport: TimeframePanelPriceViewport {
        TimeframePanelPriceViewport(
            rawPriceRange: lockedRawPriceRange ?? candlePriceRange(candles: dataManager.candles),
            topPadding: panelTopPadding,
            bottomPadding: panelBottomPadding,
            visualHeight: panelHeight,
            scaleBasisHeight: entry.priceScaleBasisHeight,
            priceScale: gestureState.priceScale,
            verticalPanOffset: gestureState.verticalPanOffset
        )
    }

    private var markerCandleIndex: Int? {
        dataManager.markerCandleIndex(for: markerTimestamp)
    }

    private var livePriceOverlayModel: (y: CGFloat, text: String)? {
        let candles = dataManager.candles
        guard let currentPrice = dataManager.livePrice ?? candles.last?.close,
              !candles.isEmpty else {
            return nil
        }

        let viewport = transformedViewport
        guard viewport.rawPriceRange.max > viewport.rawPriceRange.min else { return nil }

        let rawY = viewport.yPosition(for: currentPrice)
        let minY = livePriceTopClearance + livePriceBadgeHeight / 2
        let maxY = panelHeight - livePriceBottomClearance - livePriceBadgeHeight / 2
        guard maxY > minY else { return nil }

        return (
            y: min(max(rawY, minY), maxY),
            text: formatPrice(currentPrice)
        )
    }

    init(
        entry: TimeframePanelEntry,
        markerTimestamp: Date,
        intentColor: Color,
        baseCandleWidth: CGFloat,
        candleSpacing: CGFloat,
        mainChartVisibleStart: Date? = nil,
        mainChartVisibleEnd: Date? = nil,
        mainChartTimeframeSeconds: TimeInterval = 0,
        showMarkerLine: Bool = false,
        minPanelHeight: CGFloat = 80,
        maxPanelHeight: CGFloat = 250,
        isBottomPanel: Bool = false,
        bottomAxisOverlayTimestamp: Date? = nil,
        bottomAxisOverlayStyle: CrosshairTimeLabelStyle = .standard,
        formatPrice: @escaping (Double) -> String = TimeframePanelView.defaultPriceFormatter
    ) {
        self._entry = ObservedObject(wrappedValue: entry)
        self._dataManager = ObservedObject(wrappedValue: entry.dataManager)
        self._gestureState = ObservedObject(wrappedValue: entry.gestureState)
        self.markerTimestamp = markerTimestamp
        self.intentColor = intentColor
        self.baseCandleWidth = baseCandleWidth
        self.candleSpacing = candleSpacing
        self.mainChartVisibleStart = mainChartVisibleStart
        self.mainChartVisibleEnd = mainChartVisibleEnd
        self.mainChartTimeframeSeconds = mainChartTimeframeSeconds
        self.showMarkerLine = showMarkerLine
        self.minPanelHeight = minPanelHeight
        self.maxPanelHeight = maxPanelHeight
        self.isBottomPanel = isBottomPanel
        self.bottomAxisOverlayTimestamp = bottomAxisOverlayTimestamp
        self.bottomAxisOverlayStyle = bottomAxisOverlayStyle
        self.priceFormatter = formatPrice
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            resizeHandleBar

            if !isCollapsed {
                candleContentArea
                    .frame(height: panelHeight)
                    .contentShape(Rectangle())
                    .gesture(panGesture)
                    .simultaneousGesture(pinchGesture)
                xAxisLabels
            }
        }
        .overlay(
            Rectangle()
                .fill(AppColors.surfaceGray30)
                .frame(height: 1),
            alignment: .bottom
        )
        .background(AppColors.chartPanelBackgroundMuted)
        .onAppear {
            entry.clampPresentation(minHeight: minPanelHeight, maxHeight: maxPanelHeight)
            lockInitialPriceRangeIfNeeded()
            enforceLockAvailability()
            applyLockedMainChartViewportIfNeeded()
        }
        .onChange(of: dataManager.candles.count) { _, _ in
            centerOnMarkerIfNeeded()
            lockInitialPriceRangeIfNeeded()
            applyLockedMainChartViewportIfNeeded()
            requestOlderCandlesIfNeeded(chartWidth: plotWidth)
        }
        .onChange(of: dataManager.dataRevision) { _, _ in
            lockedRawPriceRange = nil
            hasCenteredOnMarker = false
            centerOnMarkerIfNeeded()
            lockInitialPriceRangeIfNeeded()
            applyLockedMainChartViewportIfNeeded()
        }
        .onChange(of: maxPanelHeight) { _, newValue in
            entry.clampPresentation(minHeight: minPanelHeight, maxHeight: newValue)
        }
        .onChange(of: gestureState.panOffset.width) { _, _ in
            requestOlderCandlesIfNeeded(chartWidth: plotWidth)
        }
        .onChange(of: entry.isLockedToMainChart) { _, isLocked in
            handleLockStateChanged(isLocked: isLocked)
        }
        .onChange(of: mainChartVisibleStart) { _, _ in
            applyLockedMainChartViewportIfNeeded()
        }
        .onChange(of: mainChartVisibleEnd) { _, _ in
            applyLockedMainChartViewportIfNeeded()
        }
        .onChange(of: mainChartTimeframeSeconds) { _, _ in
            enforceLockAvailability()
        }
    }

    // MARK: - Center on Marker

    private func centerOnMarkerIfNeeded() {
        guard !isLockedToMainChart,
              !hasCenteredOnMarker,
              !isCenteringToMainChartTime else {
            return
        }
        if TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: markerTimestamp,
            candles: dataManager.candles,
            hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
        ) {
            loadOlderCandlesThenCenterOnMarkerIfNeeded()
            return
        }

        applyMarkerCenterIfPossible()
    }

    private func applyMarkerCenterIfPossible() {
        guard let index = markerCandleIndex else { return }
        hasCenteredOnMarker = true
        gestureState.centerOn(
            candleIndex: index,
            totalCandleWidth: totalCandleWidth,
            chartWidth: plotWidth,
            historicalRenderIndexOffset: dataManager.historicalRenderIndexOffset
        )
    }

    private func applyLockedMainChartViewportIfNeeded() {
        guard isLockedToMainChart,
              canLockToMainChart,
              let resolution = TimeframePanelLockedViewport.resolution(
                candles: dataManager.candles,
                timeframeSeconds: dataManager.timeframe.seconds,
                mainChartVisibleStart: mainChartVisibleStart,
                mainChartVisibleEnd: mainChartVisibleEnd,
                plotWidth: plotWidth,
                historicalRenderIndexOffset: dataManager.historicalRenderIndexOffset,
                candleWidthScale: gestureState.candleWidthScale,
                baseCandleWidth: baseCandleWidth,
                candleSpacing: candleSpacing,
                minScale: minHorizontalScale,
                maxScale: maxHorizontalScale
              ) else {
            return
        }

        if abs(gestureState.candleWidthScale - resolution.candleWidthScale) > 0.0001 {
            gestureState.candleWidthScale = resolution.candleWidthScale
        }
        if abs(gestureState.panOffset.width - resolution.panOffsetWidth) > 0.5 {
            gestureState.panOffset.width = resolution.panOffsetWidth
        }
        if let centeredRange = centeredPriceRange(for: resolution) {
            lockedRawPriceRange = centeredRange
            if abs(gestureState.verticalPanOffset) > 0.5 {
                gestureState.recenterVertical(resetScale: false)
            }
        }
    }

    private func handleLockStateChanged(isLocked: Bool) {
        if isLocked {
            guard canLockToMainChart else {
                entry.isLockedToMainChart = false
                return
            }
            gestureState.candleWidthScale = lockedHorizontalFollowScale
            gestureState.recenterVertical(resetScale: false)
            applyLockedMainChartViewportIfNeeded()
        } else {
            lockedRawPriceRange = nil
            lockInitialPriceRangeIfNeeded()
        }
    }

    private func enforceLockAvailability() {
        guard entry.isLockedToMainChart, !canLockToMainChart else { return }
        entry.isLockedToMainChart = false
        lockedRawPriceRange = nil
        lockInitialPriceRangeIfNeeded()
    }

    private func recenterToMainChartTime() {
        guard !isCenteringToMainChartTime else { return }
        guard let centerTime = TimeframePanelLockedViewport.visibleCenterDate(
            mainChartVisibleStart: mainChartVisibleStart,
            mainChartVisibleEnd: mainChartVisibleEnd
        ) else {
            return
        }

        let operationID = startCenterOperation()
        if TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: centerTime,
            candles: dataManager.candles,
            hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
        ) {
            isCenteringToMainChartTime = true
            Task { @MainActor in
                await loadOlderCandlesUntilTimestampIsLoaded(centerTime)
                guard centerOperationID == operationID else { return }
                if !TimeframePanelLockedViewport.needsOlderCandlesToCenter(
                    targetTime: centerTime,
                    candles: dataManager.candles,
                    hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
                ) {
                    applyMainChartTimeCenterIfPossible()
                }
                isCenteringToMainChartTime = false
            }
            return
        }

        applyMainChartTimeCenterIfPossible()
    }

    private func applyMainChartTimeCenterIfPossible() {
        guard let resolution = TimeframePanelLockedViewport.resolution(
            candles: dataManager.candles,
            timeframeSeconds: dataManager.timeframe.seconds,
            mainChartVisibleStart: mainChartVisibleStart,
            mainChartVisibleEnd: mainChartVisibleEnd,
            plotWidth: plotWidth,
            historicalRenderIndexOffset: dataManager.historicalRenderIndexOffset,
            candleWidthScale: gestureState.candleWidthScale,
            baseCandleWidth: baseCandleWidth,
            candleSpacing: candleSpacing,
            minScale: minHorizontalScale,
            maxScale: maxHorizontalScale
        ) else {
            return
        }

        gestureState.panOffset.width = resolution.panOffsetWidth
        if let centeredRange = centeredPriceRange(for: resolution) {
            lockedRawPriceRange = centeredRange
            gestureState.recenterVertical(resetScale: true)
        }
    }

    private func loadOlderCandlesThenCenterOnMarkerIfNeeded() {
        guard !isLoadingCandlesForMarkerCenter else { return }
        let operationID = startCenterOperation()
        Task { @MainActor in
            isLoadingCandlesForMarkerCenter = true
            await loadOlderCandlesUntilTimestampIsLoaded(markerTimestamp)
            isLoadingCandlesForMarkerCenter = false
            guard centerOperationID == operationID else { return }
            guard !TimeframePanelLockedViewport.needsOlderCandlesToCenter(
                targetTime: markerTimestamp,
                candles: dataManager.candles,
                hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
            ) else {
                return
            }
            applyMarkerCenterIfPossible()
        }
    }

    private func loadOlderCandlesUntilTimestampIsLoaded(_ timestamp: Date) async {
        if TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: timestamp,
            candles: dataManager.candles,
            hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
        ), !dataManager.isLoading, !dataManager.isLoadingOlderCandles {
            _ = await dataManager.loadCandlesAround(timestamp)
        }

        var attempts = 0
        let maxAttempts = 4

        while TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: timestamp,
            candles: dataManager.candles,
            hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
        ), attempts < maxAttempts {
            attempts += 1

            if dataManager.isLoading || dataManager.isLoadingOlderCandles {
                try? await Task.sleep(nanoseconds: 90_000_000)
                continue
            }

            let prependedCount = await dataManager.loadOlderCandles()
            guard prependedCount > 0 else { break }
        }
    }

    private func startCenterOperation() -> UUID {
        let operationID = UUID()
        centerOperationID = operationID
        return operationID
    }

    private func centeredPriceRange(
        for resolution: TimeframePanelLockedViewportResolution
    ) -> (min: Double, max: Double)? {
        TimeframePanelLockedViewport.centeredPriceRange(
            candles: dataManager.candles,
            centerIndex: resolution.centerIndex,
            plotWidth: plotWidth,
            candleWidthScale: resolution.candleWidthScale,
            baseCandleWidth: baseCandleWidth,
            candleSpacing: candleSpacing
        )
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isYAxisGestureActive, !isBodyPinchActive else { return }
                let incrementalX = value.translation.width - lastDragTranslation.width
                let incrementalY = value.translation.height - lastDragTranslation.height

                if isLockedToMainChart {
                    gestureState.applyVerticalPan(
                        deltaY: incrementalY,
                        panelHeight: panelHeight
                    )
                    lastDragTranslation = value.translation
                    return
                }

                if lastDragTranslation == .zero {
                    gestureState.beginDrag()
                }
                gestureState.applyBodyPan(
                    translationX: incrementalX,
                    translationY: incrementalY,
                    chartWidth: plotWidth,
                    candleCount: dataManager.candles.count,
                    candleWidth: totalCandleWidth,
                    panelHeight: panelHeight,
                    olderEdgeGuardCandleCount: olderEdgeGuardCandleCount(chartWidth: plotWidth),
                    historicalRenderIndexOffset: dataManager.historicalRenderIndexOffset
                )
                requestOlderCandlesIfNeeded(chartWidth: plotWidth)
                lastDragTranslation = value.translation
            }
            .onEnded { _ in
                if !isLockedToMainChart {
                    requestOlderCandlesIfNeeded(chartWidth: plotWidth)
                    gestureState.endDrag()
                }
                lastDragTranslation = .zero
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard !isYAxisGestureActive, !isLockedToMainChart else { return }
                if !isBodyPinchActive {
                    isBodyPinchActive = true
                    initialCandleWidthScale = gestureState.candleWidthScale
                    initialHorizontalOffset = gestureState.panOffset.width
                    pinchCenterX = plotWidth / 2
                }

                let dampedScale = 1 + (scale - 1) * pinchSensitivity
                let proposedScale = initialCandleWidthScale * dampedScale
                let clampedScale = min(maxHorizontalScale, max(minHorizontalScale, proposedScale))
                let oldTotalWidth = baseCandleWidth * initialCandleWidthScale + candleSpacing
                let newTotalWidth = baseCandleWidth * clampedScale + candleSpacing
                let totalWidthRatio = newTotalWidth / max(oldTotalWidth, 0.0001)
                let proposedOffset = initialHorizontalOffset * totalWidthRatio + pinchCenterX * (1.0 - totalWidthRatio)

                gestureState.candleWidthScale = clampedScale
                gestureState.panOffset.width = clampedHorizontalPanOffset(
                    proposedOffset: proposedOffset,
                    chartWidth: plotWidth,
                    candleWidthScale: clampedScale
                )
            }
            .onEnded { _ in
                isBodyPinchActive = false
                gestureState.endPinch()
            }
    }

    private var yAxisDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isYAxisGestureActive {
                    isYAxisGestureActive = true
                    yAxisDragStart = value.startLocation.y
                    initialPriceScale = gestureState.priceScale
                    initialVerticalOffset = gestureState.verticalPanOffset
                }

                let dragDistance = value.location.y - yAxisDragStart
                let scaleMultiplier = 1.0 - (dragDistance / 300.0) * yAxisSensitivity
                let proposedScale = initialPriceScale * scaleMultiplier
                gestureState.applyPriceScale(
                    proposedScale: proposedScale,
                    initialPriceScale: initialPriceScale,
                    initialVerticalOffset: initialVerticalOffset,
                    anchorY: panelHeight / 2,
                    panelHeight: panelHeight,
                    minScale: minVerticalScale,
                    maxScale: maxVerticalScale
                )
            }
            .onEnded { _ in
                isYAxisGestureActive = false
            }
    }

    private var yAxisPinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if !isYAxisGestureActive {
                    isYAxisGestureActive = true
                    initialPriceScale = gestureState.priceScale
                    initialVerticalOffset = gestureState.verticalPanOffset
                }

                let dampedScale = 1 + (scale - 1) * (yAxisSensitivity * 0.7)
                let proposedScale = initialPriceScale * dampedScale
                gestureState.applyPriceScale(
                    proposedScale: proposedScale,
                    initialPriceScale: initialPriceScale,
                    initialVerticalOffset: initialVerticalOffset,
                    anchorY: panelHeight / 2,
                    panelHeight: panelHeight,
                    minScale: minVerticalScale,
                    maxScale: maxVerticalScale
                )
            }
            .onEnded { _ in
                gestureState.endPricePinch()
                isYAxisGestureActive = false
            }
    }

    // MARK: - Resize Handle

    private var resizeHandleBar: some View {
        ChartPanelResizeHandleLabel(
            primaryText: dataManager.timeframe.shortName,
            suffixText: "Timeframe",
            isCollapsed: isCollapsed,
            isDragging: isDraggingHandle,
            style: .timeframe
        )
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    if !isDraggingHandle {
                        isDraggingHandle = true
                        dragStartHeight = isCollapsed
                            ? max(minPanelHeight, entry.expandedHeight > 0 ? entry.expandedHeight : minPanelHeight)
                            : panelHeight
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    let delta = -value.translation.height
                    let rawHeight = dragStartHeight + delta
                    if rawHeight < minPanelHeight - 12 {
                        collapsePanel()
                        return
                    }
                    let newHeight = min(maxPanelHeight, max(minPanelHeight, rawHeight))
                    entry.setHeight(newHeight, minHeight: minPanelHeight, maxHeight: maxPanelHeight)
                }
                .onEnded { _ in
                    isDraggingHandle = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                if isCollapsed {
                    expandPanel()
                } else {
                    collapsePanel()
                }
            }
        }
    }

    private func collapsePanel() {
        entry.collapse(minHeight: minPanelHeight)
    }

    private func expandPanel() {
        entry.expand(minHeight: minPanelHeight, maxHeight: maxPanelHeight)
    }

    // MARK: - Candle Content

    private var candleContentArea: some View {
        // Force SwiftUI to re-render when gesture state changes
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.priceScale
        let _ = gestureState.verticalPanOffset

        return GeometryReader { geometry in
            ZStack {
                AppColors.chartPanelBackground

                if dataManager.isLoading {
                    ProgressView()
                        .tint(AppColors.surfaceWhite40)
                } else if dataManager.candles.isEmpty {
                    Text("No data")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                } else {
                    Canvas { context, size in
                        drawPanel(context: context, size: size)
                    }
                }

                yAxisLabelsOverlay
                panelHeaderControlsOverlay
                livePriceBadgeOverlay
            }
            .clipped()
            .onAppear {
                lastKnownChartWidth = max(geometry.size.width, 1)
                lockInitialPriceRangeIfNeeded()
                applyLockedMainChartViewportIfNeeded()
            }
            .onChange(of: geometry.size.width) { _, newValue in
                lastKnownChartWidth = max(newValue, 1)
                applyLockedMainChartViewportIfNeeded()
            }
        }
    }

    // MARK: - Canvas Drawing

    private func drawPanel(context: GraphicsContext, size: CGSize) {
        let candles = dataManager.candles
        guard candles.count >= 2 else { return }
        let viewport = transformedViewport
        let priceRange = viewport.rawPriceRange
        guard priceRange.max > priceRange.min else { return }

        // Vertical grid
        PanelGridHelper.drawVerticalGridLines(
            context: context, size: size,
            candles: candles, timeframe: dataManager.timeframe,
            totalOffset: totalOffset, totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth
        )

        drawHorizontalGridLines(context: context, size: size, viewport: viewport)

        // Draw candles
        drawCandlesticks(
            context: context, size: size,
            candles: candles,
            viewport: viewport
        )

        // Draw marker time position indicator
        drawMarkerPositionIndicator(
            context: context, size: size,
        )

        // Draw current price line + badge (live price or latest candle close)
        if let currentPrice = dataManager.livePrice ?? candles.last?.close {
            let y = viewport.yPosition(for: currentPrice)
            if y >= viewport.topPadding && y <= viewport.contentBottomY {
                // Dashed price line
                let livePriceBadgeMinX = max(0, size.width - livePriceBadgeWidth - livePriceBadgeTrailingInset)
                let lineEndX = livePriceBadgeMinX
                let linePath = Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: lineEndX, y: y))
                }
                context.stroke(
                    linePath,
                    with: .color(AppColors.statusHighlight80.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 0.9, dash: [4, 3])
                )
            }
        }

        // Draw main chart viewport window
        drawMainChartViewport(context: context, size: size, candles: candles)
    }

    // MARK: - Main Chart Viewport Window

    private func drawMainChartViewport(context: GraphicsContext, size: CGSize, candles: [RLCandleDTO]) {
        let settings = ChartSettings.shared
        guard settings.showViewportWindow else { return }

        // Only show viewport when this panel is a HIGHER timeframe than the main chart
        let panelSeconds = dataManager.timeframe.seconds
        guard mainChartTimeframeSeconds > 0, panelSeconds > mainChartTimeframeSeconds else { return }

        guard let visStart = mainChartVisibleStart,
              let visEnd = mainChartVisibleEnd,
              candles.count >= 2 else { return }

        // Interpolate fractional X positions for smooth movement
        let leftX = interpolatedX(for: visStart, in: candles)
        let rightX = interpolatedX(for: visEnd, in: candles)

        guard rightX > leftX else { return }

        // Clamp to visible area
        let clampedLeft = max(0, leftX)
        let clampedRight = min(size.width, rightX)
        let opacity = settings.viewportWindowOpacity
        let visibleWidth = clampedRight - clampedLeft
        let minimumVisibleWidth = max(14, totalCandleWidth * 1.25)
        guard visibleWidth >= minimumVisibleWidth else {
            drawOffscreenViewportFallback(
                context: context,
                size: size,
                style: settings.viewportWindowStyle,
                opacity: opacity,
                leftX: leftX,
                rightX: rightX
            )
            return
        }

        let viewportRect = CGRect(
            x: clampedLeft,
            y: 0,
            width: visibleWidth,
            height: size.height
        )

        switch settings.viewportWindowStyle {
        case .dimmed:
            // Dim regions outside the viewport
            if clampedLeft > 0 {
                let leftDim = CGRect(x: 0, y: 0, width: clampedLeft, height: size.height)
                context.fill(Path(leftDim), with: .color(AppColors.viewportDim.opacity(opacity)))
            }
            if clampedRight < size.width {
                let rightDim = CGRect(x: clampedRight, y: 0, width: size.width - clampedRight, height: size.height)
                context.fill(Path(rightDim), with: .color(AppColors.viewportDim.opacity(opacity)))
            }
            // Subtle border
            context.stroke(
                Path(viewportRect),
                with: .color(AppColors.surfaceWhite40.opacity(0.5)),
                style: StrokeStyle(lineWidth: 1)
            )

        case .bordered:
            // Just a border, no dim
            context.stroke(
                Path(viewportRect),
                with: .color(AppColors.surfaceWhite40.opacity(opacity + 0.3)),
                style: StrokeStyle(lineWidth: 1.5)
            )
            // Thin top/bottom accent lines
            let topLine = Path { p in
                p.move(to: CGPoint(x: clampedLeft, y: 0))
                p.addLine(to: CGPoint(x: clampedRight, y: 0))
            }
            let bottomLine = Path { p in
                p.move(to: CGPoint(x: clampedLeft, y: size.height))
                p.addLine(to: CGPoint(x: clampedRight, y: size.height))
            }
            context.stroke(topLine, with: .color(AppColors.statusInfo40.opacity(0.4)), style: StrokeStyle(lineWidth: 2))
            context.stroke(bottomLine, with: .color(AppColors.statusInfo40.opacity(0.4)), style: StrokeStyle(lineWidth: 2))

        case .tinted:
            // Light tinted fill inside the viewport
            context.fill(
                Path(viewportRect),
                with: .color(AppColors.statusInfo40.opacity(opacity * 0.4))
            )
            context.stroke(
                Path(viewportRect),
                with: .color(AppColors.statusInfo40.opacity(opacity + 0.1)),
                style: StrokeStyle(lineWidth: 1)
            )
        }
    }

    private func drawOffscreenViewportFallback(
        context: GraphicsContext,
        size: CGSize,
        style: ViewportWindowStyle,
        opacity: Double,
        leftX: CGFloat,
        rightX: CGFloat
    ) {
        if style == .dimmed {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(AppColors.viewportDim.opacity(opacity))
            )
        }

        let viewportMidX = (leftX + rightX) / 2
        let isOffscreenLeft = viewportMidX < size.width / 2
        let stripeWidth: CGFloat = 5
        let stripeX = isOffscreenLeft ? 0 : max(0, size.width - stripeWidth)
        let stripeRect = CGRect(x: stripeX, y: 0, width: stripeWidth, height: size.height)
        context.fill(
            Path(stripeRect),
            with: .color(AppColors.statusInfo40.opacity(max(opacity, 0.45)))
        )

        let lineX = isOffscreenLeft
            ? stripeWidth + 0.5
            : max(0.5, size.width - stripeWidth - 0.5)
        let edgeLine = Path { path in
            path.move(to: CGPoint(x: lineX, y: 0))
            path.addLine(to: CGPoint(x: lineX, y: size.height))
        }
        context.stroke(
            edgeLine,
            with: .color(AppColors.surfaceWhite40.opacity(0.65)),
            style: StrokeStyle(lineWidth: 1)
        )
    }

    /// Interpolates a smooth fractional X position for a given date within the candle array.
    /// This avoids snapping to discrete candle boundaries, producing fluid movement.
    private func interpolatedX(for date: Date, in candles: [RLCandleDTO]) -> CGFloat {
        let targetTime = date.timeIntervalSince1970

        // Before first candle
        if targetTime <= candles.first!.timestamp.timeIntervalSince1970 {
            let fraction = (targetTime - candles.first!.timestamp.timeIntervalSince1970) / dataManager.timeframe.seconds
            return CGFloat(fraction - Double(dataManager.historicalRenderIndexOffset)) * totalCandleWidth + totalOffset
        }

        // After last candle — cap extrapolation to 1 candle beyond the last
        if targetTime >= candles.last!.timestamp.timeIntervalSince1970 {
            let lastIdx = CGFloat(candles.count - 1 - dataManager.historicalRenderIndexOffset)
            let fraction = (targetTime - candles.last!.timestamp.timeIntervalSince1970) / dataManager.timeframe.seconds
            let cappedFraction = min(CGFloat(fraction), 1.0)
            return (lastIdx + cappedFraction) * totalCandleWidth + totalOffset + actualCandleWidth / 2
        }

        // Binary search for the surrounding candles
        var lo = 0
        var hi = candles.count - 1
        while lo < hi - 1 {
            let mid = (lo + hi) / 2
            if candles[mid].timestamp.timeIntervalSince1970 <= targetTime {
                lo = mid
            } else {
                hi = mid
            }
        }

        let t0 = candles[lo].timestamp.timeIntervalSince1970
        let t1 = candles[hi].timestamp.timeIntervalSince1970
        let fraction: CGFloat
        if t1 > t0 {
            fraction = CGFloat((targetTime - t0) / (t1 - t0))
        } else {
            fraction = 0
        }

        let interpolatedIndex = CGFloat(lo - dataManager.historicalRenderIndexOffset) + fraction
        return interpolatedIndex * totalCandleWidth + totalOffset + actualCandleWidth / 2
    }

    private func drawCandlesticks(
        context: GraphicsContext,
        size: CGSize,
        candles: [RLCandleDTO],
        viewport: TimeframePanelPriceViewport
    ) {
        let visibleStartIndex = max(
            0,
            Int(-totalOffset / totalCandleWidth) + dataManager.historicalRenderIndexOffset - 1
        )
        let visibleEndIndex = min(
            candles.count,
            max(visibleStartIndex, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
        )
        guard visibleStartIndex < visibleEndIndex else { return }
        let lineEndX = size.width - yAxisOverlayWidth
        let isLightGreyChart = ThemeManager.shared.currentTheme == .lightGrey
        let chartSettings = ChartSettings.shared
        let bullishPaint = chartSettings.bullishCandleColor

        for i in visibleStartIndex..<visibleEndIndex {
            guard i < candles.count else { continue }
            let candle = candles[i]
            guard !candle.isGapFill else { continue }

            let x = CGFloat(i - dataManager.historicalRenderIndexOffset) * totalCandleWidth + totalOffset
            guard x >= -totalCandleWidth && x <= lineEndX + totalCandleWidth else { continue }

            let isBullish = candle.close >= candle.open
            let candleColor: Color = isBullish ? bullishPaint : chartSettings.bearishCandleColor

            // Y positions
            let highY = viewport.yPosition(for: candle.high)
            let lowY = viewport.yPosition(for: candle.low)
            let openY = viewport.yPosition(for: candle.open)
            let closeY = viewport.yPosition(for: candle.close)

            let centerX = x + actualCandleWidth / 2

            // Wick
            let wickPath = Path { path in
                path.move(to: CGPoint(x: centerX, y: highY))
                path.addLine(to: CGPoint(x: centerX, y: lowY))
            }
            context.stroke(wickPath, with: .color(candleColor), lineWidth: 1)

            // Body
            let bodyRect = CGRect(
                x: x,
                y: min(openY, closeY),
                width: actualCandleWidth,
                height: max(1, abs(closeY - openY))
            )

            if isBullish {
                context.stroke(Path(bodyRect), with: .color(candleColor), lineWidth: 1)
                let bullFillOpacity = chartSettings.bullishBodyFillOpacity(isLightGreyTheme: isLightGreyChart)
                context.fill(Path(bodyRect), with: .color(candleColor.opacity(bullFillOpacity)))
            } else {
                context.fill(Path(bodyRect), with: .color(candleColor))
            }
        }
    }

    private func drawMarkerPositionIndicator(
        context: GraphicsContext,
        size: CGSize
    ) {
        // Only draw marker line when there's an actual marker context (not default chart mode)
        guard showMarkerLine else { return }
        guard let markerIndex = markerCandleIndex else { return }

        let x = CGFloat(markerIndex - dataManager.historicalRenderIndexOffset) * totalCandleWidth + totalOffset + actualCandleWidth / 2
        guard x >= 0 && x <= size.width else { return }

        // Dashed vertical line in marker intent color
        let linePath = Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(
            linePath,
            with: .color(intentColor.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
        )

        // Small label badge at top
        let labelRect = CGRect(x: x - 20, y: 4, width: 40, height: 14)
        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
        context.fill(roundedPath, with: .color(intentColor.opacity(0.8)))

        let label = Text("MARKER")
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(AppColors.onAccentForeground)
        context.draw(label, at: CGPoint(x: x, y: 11))
    }

    // MARK: - Y-Axis Labels

    private var yAxisLabelsOverlay: some View {
        HStack {
            Spacer()
            Canvas { context, size in
                drawDynamicYAxisLabels(context: context, size: size, viewport: transformedViewport)
            }
            .frame(width: yAxisOverlayWidth)
            .background(AppColors.panelYAxisLaneBackground)
            .contentShape(Rectangle())
            .highPriorityGesture(yAxisDragGesture)
            .simultaneousGesture(yAxisPinchGesture)
        }
    }

    // MARK: - Panel Header

    private var panelHeaderControlsOverlay: some View {
        HStack(spacing: 6) {
            miniInfoHeaderContent
                .allowsHitTesting(false)

            lockControlButton

            panelHeaderControlButton(
                title: isCenteringToMainChartTime ? "Loading" : "Center",
                icon: "scope",
                isActive: false,
                isEnabled: canCenterToMainChart && !isCenteringToMainChartTime
            ) {
                recenterToMainChartTime()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 5)
        .padding(.leading, 8)
        .padding(.trailing, yAxisOverlayWidth + 8)
    }

    @ViewBuilder
    private var miniInfoHeaderContent: some View {
        if let latestPrice = dataManager.livePrice ?? dataManager.candles.last?.close {
            PanelMiniInfoOverlay(
                leadingBadge: PanelMiniInfoBadge(
                    text: dataManager.livePrice != nil ? "LIVE" : "SNAPSHOT",
                    color: intentColor.opacity(0.88)
                ),
                tokens: [
                    PanelMiniInfoToken(
                        label: nil,
                        value: formatPrice(latestPrice),
                        valueColor: AppColors.panelMiniInfoOverlayPrimaryText
                    ),
                ]
            )
        }
    }

    private var lockControlButton: some View {
        let title: String = canLockToMainChart
            ? (entry.isLockedToMainChart ? "Locked" : "Lock")
            : "N/A"
        let icon = canLockToMainChart
            ? (entry.isLockedToMainChart ? "lock.fill" : "lock.open")
            : "lock.slash"

        return panelHeaderControlButton(
            title: title,
            icon: icon,
            isActive: entry.isLockedToMainChart && canLockToMainChart,
            isEnabled: canLockToMainChart
        ) {
            withAnimation(.easeInOut(duration: 0.16)) {
                entry.isLockedToMainChart.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .accessibilityLabel(entry.isLockedToMainChart ? "Unlock timeframe from main chart" : "Lock timeframe to main chart")
    }

    private func panelHeaderControlButton(
        title: String,
        icon: String,
        isActive: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(panelHeaderControlForeground(isActive: isActive, isEnabled: isEnabled))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isActive && isEnabled ? ChartBottomControlButton.activeBackground : ChartBottomControlButton.inactiveBackground)
            .cornerRadius(ChartBottomControlButton.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ChartBottomControlButton.cornerRadius)
                    .stroke(
                        isActive && isEnabled ? ChartBottomControlButton.activeBorder : ChartBottomControlButton.inactiveBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.66)
    }

    private func panelHeaderControlForeground(isActive: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else { return AppColors.greyText }
        return isActive ? AppColors.gradientBackgroundDark : AppColors.chartBottomControlForeground
    }

    private var livePriceBadgeOverlay: some View {
        GeometryReader { geometry in
            if let overlayModel = livePriceOverlayModel {
                let x = geometry.size.width - livePriceBadgeWidth / 2 - livePriceBadgeTrailingInset

                Text(overlayModel.text)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: livePriceBadgeWidth, height: livePriceBadgeHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(AppColors.statusHighlight90)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(AppColors.surfaceBlack62.opacity(0.38), lineWidth: 0.9)
                    )
                    .position(x: x, y: overlayModel.y)
                    .shadow(color: AppColors.surfaceBlack62.opacity(0.16), radius: 2, x: 0, y: 1)
            }
        }
        .allowsHitTesting(false)
    }

    static func defaultPriceFormatter(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2f", value)
        } else if value >= 1 {
            return String(format: "%.4f", value)
        } else {
            return String(format: "%.6f", value)
        }
    }

    private func formatPrice(_ value: Double) -> String {
        priceFormatter(value)
    }

    // MARK: - X-Axis Labels

    private var xAxisLabels: some View {
        let labelH = ChartPanelReserveCalculator.panelXAxisTimeLabelAreaHeight
        let footH = ChartPanelReserveCalculator.panelXAxisLabelBottomFootHeight

        return VStack(spacing: 0) {
            ZStack {
                Canvas { context, size in
                    ChartXAxisLabelEngine.drawLabels(
                        context: context,
                        size: size,
                        input: .init(
                            candles: dataManager.candles,
                            timeframe: dataManager.timeframe,
                            totalOffset: totalOffset,
                            totalCandleWidth: totalCandleWidth,
                            actualCandleWidth: actualCandleWidth,
                            historicalRenderIndexOffset: dataManager.historicalRenderIndexOffset,
                            width: size.width,
                            timeZone: .current,
                            locale: Locale(identifier: "en_US_POSIX"),
                            minSpacing: 52
                        ),
                        style: .timeframePanel
                    )
                }
                .frame(height: labelH)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.timeframePanelAxisGradientTop,
                            AppColors.timeframePanelAxisGradientBottom,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColors.timeframePanelAxisFrameBorder)
                        .frame(height: 1)
                }

                if isBottomPanel, let overlayTimestamp = bottomAxisOverlayTimestamp,
                   let overlayX = xPosition(forTimestamp: overlayTimestamp) {
                    CrosshairTimeLabel(
                        timestamp: overlayTimestamp,
                        timeframe: dataManager.timeframe,
                        timeZone: .current,
                        style: bottomAxisOverlayStyle
                    )
                    .position(
                        x: CrosshairTimeLabel.clampedCenterX(
                            rawX: overlayX,
                            timestamp: overlayTimestamp,
                            timeframe: dataManager.timeframe,
                            timeZone: .current,
                            availableWidth: lastKnownChartWidth
                        ),
                        y: CrosshairTimeLabel.indicatorHeight * 0.5
                    )
                }
            }
            .frame(height: labelH)

            Rectangle()
                .fill(AppColors.timeframePanelAxisGradientBottom)
                .frame(height: footH)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.timeframePanelAxisFrameBorder)
                .frame(height: 1)
        }
        .frame(height: ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
    }

    // MARK: - Helpers

    private func candlePriceRange(candles: [RLCandleDTO]) -> (min: Double, max: Double) {
        guard !candles.isEmpty else { return (0, 1) }

        // Only calculate range for visible candles
        let visibleStartIndex = max(
            0,
            Int(-totalOffset / totalCandleWidth) + dataManager.historicalRenderIndexOffset - 5
        )
        let visibleEndIndex = min(candles.count, visibleStartIndex + Int(UIScreen.main.bounds.width / totalCandleWidth) + 10)

        guard visibleStartIndex < visibleEndIndex else {
            return (candles.map(\.low).min() ?? 0, candles.map(\.high).max() ?? 1)
        }

        let visibleCandles = Array(candles[visibleStartIndex..<visibleEndIndex])
        let minPrice = visibleCandles.map(\.low).min() ?? 0
        let maxPrice = visibleCandles.map(\.high).max() ?? 1

        // Add 5% padding
        let padding = (maxPrice - minPrice) * 0.05
        return (minPrice - padding, maxPrice + padding)
    }

    private func lockInitialPriceRangeIfNeeded() {
        guard !dataManager.candles.isEmpty else {
            lockedRawPriceRange = nil
            return
        }
        guard lockedRawPriceRange == nil else { return }
        lockedRawPriceRange = candlePriceRange(candles: dataManager.candles)
    }

    private func formatAxisPrice(_ price: Double) -> String {
        formatPrice(price)
    }

    private func dynamicPriceAxisLevels(for viewport: TimeframePanelPriceViewport) -> [Double] {
        let visibleMin = min(viewport.transformedTopPrice, viewport.transformedBottomPrice)
        let visibleMax = max(viewport.transformedTopPrice, viewport.transformedBottomPrice)
        let visibleRange = visibleMax - visibleMin
        let step = sparseNicePriceStep(for: visibleRange)
        guard step.isFinite, step > 0 else { return [] }

        let startPrice = floor(visibleMin / step) * step
        let endPrice = ceil(visibleMax / step) * step
        guard startPrice.isFinite, endPrice.isFinite, startPrice <= endPrice else { return [] }

        var levels: [Double] = []
        var currentPrice = startPrice
        var count = 0
        while currentPrice <= endPrice && count < 40 {
            levels.append(currentPrice)
            currentPrice += step
            count += 1
        }

        guard levels.count > maxVisibleYAxisLabels else { return levels }
        let stride = Int(ceil(Double(levels.count) / Double(maxVisibleYAxisLabels)))
        return levels.enumerated().compactMap { index, level in
            index.isMultiple(of: stride) ? level : nil
        }
    }

    private func sparseNicePriceStep(for visibleRange: Double) -> Double {
        guard visibleRange.isFinite, visibleRange > 0 else { return 1 }

        let roughStep = visibleRange / targetYAxisIntervals
        let magnitude = pow(10.0, floor(log10(roughStep)))
        let normalized = roughStep / magnitude

        let niceNormalized: Double
        if normalized <= 1.0 {
            niceNormalized = 1.0
        } else if normalized <= 2.0 {
            niceNormalized = 2.0
        } else if normalized <= 2.5 {
            niceNormalized = 2.5
        } else if normalized <= 5.0 {
            niceNormalized = 5.0
        } else {
            niceNormalized = 10.0
        }

        return niceNormalized * magnitude
    }

    private func drawDynamicYAxisLabels(
        context: GraphicsContext,
        size: CGSize,
        viewport: TimeframePanelPriceViewport
    ) {
        let x = max(2, min(size.width - 3, yAxisLabelWidth + 1))

        for price in dynamicPriceAxisLevels(for: viewport) {
            let y = viewport.yPosition(for: price)
            guard y >= viewport.topPadding - 12, y <= viewport.contentBottomY + 12 else { continue }

            context.draw(
                Text(formatAxisPrice(price))
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.panelYAxisLaneText),
                at: CGPoint(x: x, y: y),
                anchor: .trailing
            )
        }
    }

    private func drawHorizontalGridLines(
        context: GraphicsContext,
        size: CGSize,
        viewport: TimeframePanelPriceViewport
    ) {
        let settings = ChartSettings.shared
        guard settings.showGridLines else { return }

        let plotEndX = max(0, size.width - yAxisOverlayWidth)
        guard plotEndX > 0 else { return }

        var path = Path()
        var lineCount = 0
        for price in dynamicPriceAxisLevels(for: viewport) {
            let y = viewport.yPosition(for: price)
            guard y >= -40, y <= size.height + 40 else { continue }
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: plotEndX, y: y))
            lineCount += 1
            if lineCount >= 80 { break }
        }

        context.stroke(
            path,
            with: .color(.gray.opacity(settings.gridOpacity * 0.75)),
            lineWidth: 0.42
        )
    }

    private func requestOlderCandlesIfNeeded(chartWidth: CGFloat) {
        guard chartWidth > 0,
              !dataManager.candles.isEmpty,
              totalCandleWidth > 0,
              (gestureState.isUserDrivenPanActive || isLockedToMainChart),
              dataManager.hasMoreHistoricalCandles,
              !dataManager.isLoadingOlderCandles,
              !dataManager.isLoading else {
            return
        }

        let visibleStartIndex = visibleStartIndexForCurrentOffset()
        let visibleCandleCount = max(1, Int(ceil(chartWidth / totalCandleWidth)))
        guard HistoricalPreloadPolicy.shouldPreload(
            visibleStartIndex: visibleStartIndex,
            visibleCandleCount: visibleCandleCount,
            hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
        ) else { return }

        Task { @MainActor in
            await dataManager.loadOlderCandlesIfNeeded(
                visibleStartIndex: visibleStartIndex,
                visibleCandleCount: visibleCandleCount,
                beforePublishingPrepend: { prependedCount in
                    gestureState.shiftForPrependedCandles(
                        count: prependedCount,
                        totalCandleWidth: totalCandleWidth
                    )
                }
            )
        }
    }

    private func olderEdgeGuardCandleCount(chartWidth: CGFloat) -> Int {
        guard chartWidth > 0, totalCandleWidth > 0 else { return 0 }
        let visibleCandleCount = max(1, Int(ceil(chartWidth / totalCandleWidth)))
        return HistoricalPreloadPolicy.edgeGuardCandleCount(
            visibleCandleCount: visibleCandleCount,
            candleCount: dataManager.candles.count,
            hasMoreHistoricalCandles: dataManager.hasMoreHistoricalCandles
        )
    }

    private func clampedHorizontalPanOffset(
        proposedOffset: CGFloat,
        chartWidth: CGFloat,
        candleWidthScale: CGFloat
    ) -> CGFloat {
        let totalWidth = baseCandleWidth * candleWidthScale + candleSpacing
        let renderOffset = max(0, min(dataManager.historicalRenderIndexOffset, dataManager.candles.count))
        let totalContentWidth = CGFloat(max(0, dataManager.candles.count - renderOffset)) * totalWidth
        let maxOffset = CGFloat(renderOffset) * totalWidth + chartWidth * 0.5
        let minOffset = -(totalContentWidth - chartWidth * 0.5)
        return min(maxOffset, max(minOffset, proposedOffset))
    }

    private func xPosition(forTimestamp timestamp: Date) -> CGFloat? {
        guard let candleIndex = dataManager.markerCandleIndex(for: timestamp) else { return nil }
        let rawX = CGFloat(candleIndex - dataManager.historicalRenderIndexOffset) * totalCandleWidth + totalOffset + actualCandleWidth / 2
        return rawX.isFinite ? rawX : nil
    }

    private func visibleStartIndexForCurrentOffset() -> Int {
        guard totalCandleWidth > 0 else {
            return min(dataManager.historicalRenderIndexOffset, max(0, dataManager.candles.count - 1))
        }
        let visualIndex = Int(floor(-gestureState.panOffset.width / totalCandleWidth))
        return max(0, min(dataManager.candles.count - 1, visualIndex + dataManager.historicalRenderIndexOffset))
    }
}
