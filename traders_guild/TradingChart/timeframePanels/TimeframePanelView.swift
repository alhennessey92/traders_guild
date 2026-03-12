//
//  TimeframePanelView.swift
//  traders_guild
//
//  Timeframe snapshot panel — displays OHLCV candles for a linked timeframe
//  with the marker's time position indicated. Supports independent pan/pinch.
//  Matches indicator panel UI pattern (RSIPanelView structure).
//

import SwiftUI

struct TimeframePanelView: View {

    // MARK: - Properties

    @ObservedObject var dataManager: TimeframePanelDataManager
    @ObservedObject var gestureState: TimeframePanelGestureState

    let markerTimestamp: Date
    let intentColor: Color
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat

    @Binding var panelHeight: CGFloat
    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 250
    var isBottomPanel: Bool = false

    // MARK: - Private State

    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragTranslation: CGSize = .zero
    @State private var hasCenteredOnMarker = false
    @State private var isCollapsed = false
    @State private var expandedPanelHeight: CGFloat = 0

    // MARK: - Computed

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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            resizeHandleBar

            if !isCollapsed {
                candleContentArea
                    .frame(height: panelHeight)
                    .gesture(panGesture)
                    .gesture(pinchGesture)
                if isBottomPanel {
                    xAxisLabels
                }
            }
        }
        .background(AppColors.surfaceBlack85)
        .onChange(of: dataManager.candles.count) { _, _ in
            centerOnMarkerIfNeeded()
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
                .fill(AppColors.chartIndicatorHandleFill)

            HStack(spacing: 8) {
                Capsule()
                    .fill(isDraggingHandle ? AppColors.surfaceWhite80 : AppColors.surfaceGray50)
                    .frame(width: 36, height: 5)

                if isCollapsed {
                    Text(dataManager.timeframe.shortName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.surfaceWhite80)
                        .lineLimit(1)

                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.surfaceWhite80)
                }
            }
        }
        .frame(height: 22)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    if !isDraggingHandle {
                        isDraggingHandle = true
                        if isCollapsed {
                            expandPanel()
                        }
                        dragStartHeight = panelHeight
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    let delta = -value.translation.height
                    let rawHeight = dragStartHeight + delta
                    if rawHeight < minPanelHeight - 12 {
                        collapsePanel()
                        return
                    }
                    let newHeight = min(maxPanelHeight, max(minPanelHeight, rawHeight))
                    panelHeight = newHeight
                    expandedPanelHeight = newHeight
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
        guard !isCollapsed else { return }
        expandedPanelHeight = max(minPanelHeight, panelHeight)
        panelHeight = 0
        isCollapsed = true
    }

    private func expandPanel() {
        guard isCollapsed else { return }
        let restoredHeight = expandedPanelHeight > 0 ? expandedPanelHeight : minPanelHeight
        panelHeight = min(maxPanelHeight, max(minPanelHeight, restoredHeight))
        isCollapsed = false
    }

    // MARK: - Candle Content

    private var candleContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale

        return ZStack {
            AppColors.surfaceBlack80

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
            IndicatorPanelHeaderRow(
                title: dataManager.timeframe.shortName,
                valueText: dataManager.latestClose.map { formatAxisPrice($0) },
                valueColor: .white,
                badgeText: "SNAPSHOT",
                badgeColor: intentColor
            )
            Spacer()
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
                    style: .indicatorPanel
                )
            }
            .frame(height: 24)
            .background(AppColors.systemBlack)
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
