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

    // MARK: - Private State

    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragTranslation: CGSize = .zero
    @State private var hasCenteredOnMarker = false

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

    private var markerCandleIndex: Int? {
        dataManager.markerCandleIndex(for: markerTimestamp)
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
        isBottomPanel: Bool = false
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
                if isBottomPanel {
                    xAxisLabels
                }
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
        }
        .onChange(of: maxPanelHeight) { _, newValue in
            entry.clampPresentation(minHeight: minPanelHeight, maxHeight: newValue)
        }
    }

    // MARK: - Center on Marker

    private func centerOnMarkerIfNeeded() {
        guard !hasCenteredOnMarker, let index = markerCandleIndex else { return }
        hasCenteredOnMarker = true
        gestureState.centerOn(
            candleIndex: index,
            totalCandleWidth: totalCandleWidth,
            chartWidth: UIScreen.main.bounds.width
        )
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if lastDragTranslation == .zero {
                    gestureState.beginDrag()
                }
                let incrementalX = value.translation.width - lastDragTranslation.width
                gestureState.applyPan(
                    translationX: incrementalX,
                    chartWidth: UIScreen.main.bounds.width,
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
                gestureState.applyPinch(scale: scale)
            }
            .onEnded { _ in
                gestureState.endPinch()
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
                    .foregroundColor(.white)
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

        return ZStack {
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
        }
        .clipped()
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
            let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
            let y = topPadding + drawableHeight * (1.0 - CGFloat(normalizedPrice))
            if y >= topPadding && y <= topPadding + drawableHeight {
                // Dashed price line
                let lineEndX = size.width - 30
                let linePath = Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: lineEndX, y: y))
                }
                context.stroke(
                    linePath,
                    with: .color(AppColors.statusHighlight80.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 0.8, dash: [4, 3])
                )

                // Yellow price badge on right edge
                let badgeWidth: CGFloat = 30
                let badgeHeight: CGFloat = 14
                let badgeX = size.width - badgeWidth
                let badgeRect = CGRect(
                    x: badgeX,
                    y: y - badgeHeight / 2,
                    width: badgeWidth,
                    height: badgeHeight
                )
                let roundedBadge = Path(roundedRect: badgeRect, cornerRadius: 3)
                context.fill(roundedBadge, with: .color(.yellow))

                let priceText = Text(formatPrice(currentPrice))
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                context.draw(priceText, at: CGPoint(x: badgeRect.midX, y: y))
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
                context.fill(Path(leftDim), with: .color(Color.black.opacity(opacity)))
            }
            if clampedRight < size.width {
                let rightDim = CGRect(x: clampedRight, y: 0, width: size.width - clampedRight, height: size.height)
                context.fill(Path(rightDim), with: .color(Color.black.opacity(opacity)))
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
        let lineEndX = size.width - 30

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
            .foregroundColor(.white)
        context.draw(label, at: CGPoint(x: x, y: 11))
    }

    // MARK: - Y-Axis Labels

    private var yAxisLabelsOverlay: some View {
        let range = candlePriceRange(candles: dataManager.candles)
        let mid = (range.max + range.min) / 2

        return HStack {
            Spacer()
            VStack {
                Text(formatAxisPrice(range.max))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite66)
                Spacer()
                Text(formatAxisPrice(mid))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite40)
                Spacer()
                Text(formatAxisPrice(range.min))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite66)
            }
            .frame(width: 28)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .padding(.trailing, 5)
            .background(AppColors.surfaceBlack62)
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
        return topPadding + height * (1.0 - CGFloat(normalized))
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
}
