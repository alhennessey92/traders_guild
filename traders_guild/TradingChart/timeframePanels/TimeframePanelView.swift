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

    // MARK: - Computed

    private var panelHeight: CGFloat {
        entry.currentHeight
    }

    private var isCollapsed: Bool {
        entry.isCollapsed
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
        }
        .onChange(of: dataManager.candles.count) { _, _ in
            centerOnMarkerIfNeeded()
            lockInitialPriceRangeIfNeeded()
            requestOlderCandlesIfNeeded(chartWidth: plotWidth)
        }
        .onChange(of: dataManager.dataRevision) { _, _ in
            lockedRawPriceRange = nil
            hasCenteredOnMarker = false
            centerOnMarkerIfNeeded()
            lockInitialPriceRangeIfNeeded()
            requestOlderCandlesIfNeeded(chartWidth: plotWidth)
        }
        .onChange(of: maxPanelHeight) { _, newValue in
            entry.clampPresentation(minHeight: minPanelHeight, maxHeight: newValue)
        }
        .onChange(of: gestureState.panOffset.width) { _, _ in
            requestOlderCandlesIfNeeded(chartWidth: plotWidth)
        }
        .onChange(of: gestureState.candleWidthScale) { _, _ in
            requestOlderCandlesIfNeeded(chartWidth: plotWidth)
        }
    }

    // MARK: - Center on Marker

    private func centerOnMarkerIfNeeded() {
        guard !hasCenteredOnMarker, let index = markerCandleIndex else { return }
        hasCenteredOnMarker = true
        gestureState.centerOn(
            candleIndex: index,
            totalCandleWidth: totalCandleWidth,
            chartWidth: plotWidth
        )
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isYAxisGestureActive, !isBodyPinchActive else { return }
                if lastDragTranslation == .zero {
                    gestureState.beginDrag()
                }
                let incrementalX = value.translation.width - lastDragTranslation.width
                let incrementalY = value.translation.height - lastDragTranslation.height
                gestureState.applyBodyPan(
                    translationX: incrementalX,
                    translationY: incrementalY,
                    chartWidth: plotWidth,
                    candleCount: dataManager.candles.count,
                    candleWidth: totalCandleWidth,
                    panelHeight: panelHeight
                )
                lastDragTranslation = value.translation
            }
            .onEnded { _ in
                gestureState.endDrag()
                lastDragTranslation = .zero
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard !isYAxisGestureActive else { return }
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
                miniInfoOverlay
                livePriceBadgeOverlay
            }
            .clipped()
            .onAppear {
                lastKnownChartWidth = max(geometry.size.width, 1)
                lockInitialPriceRangeIfNeeded()
                requestOlderCandlesIfNeeded(chartWidth: plotWidth)
            }
            .onChange(of: geometry.size.width) { _, newValue in
                lastKnownChartWidth = max(newValue, 1)
                requestOlderCandlesIfNeeded(chartWidth: max(newValue - yAxisOverlayWidth, 1))
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
                opacity: opacity
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
        opacity: Double
    ) {
        guard style == .dimmed else { return }
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(AppColors.viewportDim.opacity(opacity))
        )
    }

    /// Interpolates a smooth fractional X position for a given date within the candle array.
    /// This avoids snapping to discrete candle boundaries, producing fluid movement.
    private func interpolatedX(for date: Date, in candles: [RLCandleDTO]) -> CGFloat {
        let targetTime = date.timeIntervalSince1970

        // Before first candle
        if targetTime <= candles.first!.timestamp.timeIntervalSince1970 {
            let fraction = (targetTime - candles.first!.timestamp.timeIntervalSince1970) / dataManager.timeframe.seconds
            return CGFloat(fraction) * totalCandleWidth + totalOffset
        }

        // After last candle — cap extrapolation to 1 candle beyond the last
        if targetTime >= candles.last!.timestamp.timeIntervalSince1970 {
            let lastIdx = CGFloat(candles.count - 1)
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

        let interpolatedIndex = CGFloat(lo) + fraction
        return interpolatedIndex * totalCandleWidth + totalOffset + actualCandleWidth / 2
    }

    private func drawCandlesticks(
        context: GraphicsContext,
        size: CGSize,
        candles: [RLCandleDTO],
        viewport: TimeframePanelPriceViewport
    ) {
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 1)
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

            let x = CGFloat(i) * totalCandleWidth + totalOffset
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

        let x = CGFloat(markerIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
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

    private var miniInfoOverlay: some View {
        Group {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
        .padding(.leading, 8)
        .allowsHitTesting(false)
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
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
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
              dataManager.hasMoreHistoricalCandles,
              !dataManager.isLoadingOlderCandles,
              !dataManager.isLoading else {
            return
        }

        let visibleStartIndex = max(0, Int(floor(-gestureState.panOffset.width / totalCandleWidth)))
        let visibleCandleCount = max(1, Int(ceil(chartWidth / totalCandleWidth)))
        let preloadThreshold = max(24, visibleCandleCount)
        guard visibleStartIndex <= preloadThreshold else { return }

        Task { @MainActor in
            let prependedCount = await dataManager.loadOlderCandlesIfNeeded(
                visibleStartIndex: visibleStartIndex,
                preloadThreshold: preloadThreshold
            )
            if prependedCount > 0 {
                gestureState.shiftForPrependedCandles(count: prependedCount, totalCandleWidth: totalCandleWidth)
            }
        }
    }

    private func clampedHorizontalPanOffset(
        proposedOffset: CGFloat,
        chartWidth: CGFloat,
        candleWidthScale: CGFloat
    ) -> CGFloat {
        let totalWidth = baseCandleWidth * candleWidthScale + candleSpacing
        let totalContentWidth = CGFloat(dataManager.candles.count) * totalWidth
        let maxOffset = chartWidth * 0.5
        let minOffset = -(totalContentWidth - chartWidth * 0.5)
        return min(maxOffset, max(minOffset, proposedOffset))
    }

    private func xPosition(forTimestamp timestamp: Date) -> CGFloat? {
        guard let candleIndex = dataManager.markerCandleIndex(for: timestamp) else { return nil }
        let rawX = CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
        return rawX.isFinite ? rawX : nil
    }
}
