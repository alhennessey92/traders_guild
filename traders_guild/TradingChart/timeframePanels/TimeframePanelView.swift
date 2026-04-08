//
//  TimeframePanelView.swift
//  traders_guild
//
//  Timeframe snapshot panel — displays OHLCV candles for a linked timeframe
//  with the marker's time position indicated. Supports independent pan/pinch
//  (not linked to main chart). Matches indicator panel UI pattern.
//

import SwiftUI

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

    private let livePriceBadgeWidth: CGFloat = 46
    private let livePriceBadgeHeight: CGFloat = 16
    private let yAxisOverlayWidth: CGFloat = ChartAxisMetrics.yAxisLaneWidth
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

    private var markerCandleIndex: Int? {
        dataManager.markerCandleIndex(for: markerTimestamp)
    }

    private var livePriceOverlayModel: (y: CGFloat, text: String)? {
        let candles = dataManager.candles
        guard let currentPrice = dataManager.livePrice ?? candles.last?.close,
              !candles.isEmpty else {
            return nil
        }

        let priceRange = candlePriceRange(candles: candles)
        guard priceRange.max > priceRange.min else { return nil }

        let topPadding: CGFloat = 18
        let bottomPadding: CGFloat = 4
        let drawableHeight = panelHeight - topPadding - bottomPadding
        guard drawableHeight > 0 else { return nil }

        let rawY = yPosition(
            for: currentPrice,
            priceRange: priceRange,
            height: drawableHeight,
            topPadding: topPadding
        )
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
        bottomAxisOverlayStyle: CrosshairTimeLabelStyle = .standard
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
        }
        .onChange(of: dataManager.candles.count) { _, _ in
            centerOnMarkerIfNeeded()
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
                gestureState.applyPan(
                    translationX: incrementalX,
                    chartWidth: plotWidth,
                    candleCount: dataManager.candles.count,
                    candleWidth: totalCandleWidth
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
        ZStack {
            Rectangle()
                .fill(AppColors.panelHeaderBackground)

            // Capsule always centered
            Capsule()
                .fill(isDraggingHandle ? AppColors.surfaceWhite80 : AppColors.surfaceGray50)
                .frame(width: 36, height: 5)

            // Panel label left-aligned
            HStack(spacing: 4) {
                (Text(dataManager.timeframe.shortName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.primaryForeground)
                 + Text("  Timeframe")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.surfaceWhite50))
                    .lineLimit(1)

                if isCollapsed {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.surfaceWhite80)
                }

                Spacer()
            }
            .padding(.leading, 10)
        }
        .frame(height: 22)
        .contentShape(Rectangle())
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
        .overlay(
            Rectangle()
                .fill(AppColors.surfaceGray30)
                .frame(height: 1),
            alignment: .bottom
        )
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
                panelHeaderOverlay
                livePriceBadgeOverlay
            }
            .clipped()
            .onAppear {
                lastKnownChartWidth = max(geometry.size.width, 1)
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

        // Vertical grid
        PanelGridHelper.drawVerticalGridLines(
            context: context, size: size,
            candles: candles, timeframe: dataManager.timeframe,
            totalOffset: totalOffset, totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth
        )

        // Price range for this timeframe's candles
        let priceRange = candlePriceRange(candles: candles)
        guard priceRange.max > priceRange.min else { return }

        let topPadding: CGFloat = 18
        let bottomPadding: CGFloat = 4
        let drawableHeight = size.height - topPadding - bottomPadding

        // Draw candles
        drawCandlesticks(
            context: context, size: size,
            candles: candles, priceRange: priceRange,
            drawableHeight: drawableHeight, topPadding: topPadding
        )

        // Draw marker time position indicator
        drawMarkerPositionIndicator(
            context: context, size: size,
            priceRange: priceRange,
            drawableHeight: drawableHeight, topPadding: topPadding
        )

        // Draw current price line + badge (live price or latest candle close)
        if let currentPrice = dataManager.livePrice ?? candles.last?.close {
            let y = yPosition(for: currentPrice, priceRange: priceRange, height: drawableHeight, topPadding: topPadding)
            if y >= topPadding && y <= topPadding + drawableHeight {
                // Dashed price line
                let lineEndX = max(0, size.width - yAxisOverlayWidth - livePriceBadgeWidth - 6)
                let linePath = Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: lineEndX, y: y))
                }
                context.stroke(
                    linePath,
                    with: .color(AppColors.statusHighlight80.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 0.8, dash: [4, 3])
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
        guard clampedRight > clampedLeft else { return }

        let viewportRect = CGRect(
            x: clampedLeft,
            y: 0,
            width: clampedRight - clampedLeft,
            height: size.height
        )

        let opacity = settings.viewportWindowOpacity

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
        priceRange: (min: Double, max: Double),
        drawableHeight: CGFloat,
        topPadding: CGFloat
    ) {
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 1)
        let visibleEndIndex = min(
            candles.count,
            max(visibleStartIndex, visibleStartIndex + Int(size.width / totalCandleWidth) + 3)
        )
        guard visibleStartIndex < visibleEndIndex else { return }
        let lineEndX = size.width - yAxisOverlayWidth

        for i in visibleStartIndex..<visibleEndIndex {
            guard i < candles.count else { continue }
            let candle = candles[i]
            guard !candle.isGapFill else { continue }

            let x = CGFloat(i) * totalCandleWidth + totalOffset
            guard x >= -totalCandleWidth && x <= lineEndX + totalCandleWidth else { continue }

            let isBullish = candle.close >= candle.open
            let candleColor: Color = isBullish ? .green : .red

            // Y positions
            let highY = yPosition(for: candle.high, priceRange: priceRange, height: drawableHeight, topPadding: topPadding)
            let lowY = yPosition(for: candle.low, priceRange: priceRange, height: drawableHeight, topPadding: topPadding)
            let openY = yPosition(for: candle.open, priceRange: priceRange, height: drawableHeight, topPadding: topPadding)
            let closeY = yPosition(for: candle.close, priceRange: priceRange, height: drawableHeight, topPadding: topPadding)

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
                context.fill(Path(bodyRect), with: .color(candleColor.opacity(0.3)))
            } else {
                context.fill(Path(bodyRect), with: .color(candleColor))
            }
        }
    }

    private func drawMarkerPositionIndicator(
        context: GraphicsContext,
        size: CGSize,
        priceRange: (min: Double, max: Double),
        drawableHeight: CGFloat,
        topPadding: CGFloat
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
        let range = candlePriceRange(candles: dataManager.candles)
        let topPadding: CGFloat = 18
        let bottomPadding: CGFloat = 4
        let drawableHeight = max(1, panelHeight - topPadding - bottomPadding)
        let top = price(atY: topPadding, priceRange: range, height: drawableHeight, topPadding: topPadding)
        let bottom = price(atY: panelHeight - bottomPadding, priceRange: range, height: drawableHeight, topPadding: topPadding)
        let mid = (top + bottom) / 2

        return HStack {
            Spacer()
            VStack {
                Text(formatAxisPrice(top))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite66)
                Spacer()
                Text(formatAxisPrice(mid))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite40)
                Spacer()
                Text(formatAxisPrice(bottom))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite66)
            }
            .frame(width: 28)
            .frame(minWidth: yAxisOverlayWidth)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .padding(.trailing, 5)
            .background(AppColors.chartPanelBackgroundDeep.opacity(0.92))
            .contentShape(Rectangle())
            .highPriorityGesture(yAxisDragGesture)
            .simultaneousGesture(yAxisPinchGesture)
        }
    }

    // MARK: - Panel Header

    private var panelHeaderOverlay: some View {
        VStack {
            let latestPrice = dataManager.livePrice ?? dataManager.candles.last?.close
            IndicatorPanelHeaderRow(
                title: "",
                valueText: latestPrice.map { formatPrice($0) },
                valueColor: .white,
                badgeText: dataManager.livePrice != nil ? "LIVE" : "SNAPSHOT",
                badgeColor: intentColor
            )
            Spacer()
        }
    }

    private var livePriceBadgeOverlay: some View {
        GeometryReader { geometry in
            if let overlayModel = livePriceOverlayModel {
                let x = geometry.size.width - livePriceBadgeWidth / 2 - 2

                Text(overlayModel.text)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: livePriceBadgeWidth, height: livePriceBadgeHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppColors.statusHighlight90)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(AppColors.surfaceBlack62.opacity(0.35), lineWidth: 0.8)
                    )
                    .position(x: x, y: overlayModel.y)
                    .shadow(color: AppColors.surfaceBlack62.opacity(0.16), radius: 2, x: 0, y: 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func formatPrice(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2f", value)
        } else if value >= 1 {
            return String(format: "%.4f", value)
        } else {
            return String(format: "%.6f", value)
        }
    }

    // MARK: - X-Axis Labels

    private var xAxisLabels: some View {
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
            .frame(height: 24)
            .background(
                LinearGradient(
                    colors: [
                        AppColors.statusInfo15,
                        AppColors.xAxisBackground,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppColors.statusInfo40)
                    .frame(height: 1)
                    .opacity(0.7)
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
        .frame(height: 24)
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

    private func yPosition(for price: Double, priceRange: (min: Double, max: Double), height: CGFloat, topPadding: CGFloat) -> CGFloat {
        let normalized = (price - priceRange.min) / (priceRange.max - priceRange.min)
        let baseY = topPadding + height * (1.0 - CGFloat(normalized))
        let centerY = topPadding + height / 2
        return centerY + (baseY - centerY) * gestureState.priceScale + gestureState.verticalPanOffset
    }

    private func price(atY y: CGFloat, priceRange: (min: Double, max: Double), height: CGFloat, topPadding: CGFloat) -> Double {
        guard priceRange.max > priceRange.min, gestureState.priceScale > 0 else { return priceRange.min }
        let centerY = topPadding + height / 2
        let unscaledY = ((y - gestureState.verticalPanOffset - centerY) / gestureState.priceScale) + centerY
        let normalized = 1.0 - ((unscaledY - topPadding) / height)
        return priceRange.min + Double(normalized) * (priceRange.max - priceRange.min)
    }

    private func formatAxisPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        } else if price >= 1 {
            return String(format: "%.2f", price)
        } else {
            return String(format: "%.4f", price)
        }
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
