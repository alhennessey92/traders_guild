//
//  MACDPanelView.swift
//  traders_guild
//
//  MACD Panel View - Features histogram, MACD line, signal line
//  Follows RSIPanelView pattern for consistency
//

import SwiftUI

struct MACDPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    @ObservedObject var viewportState: IndicatorPanelViewportState
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var timeframe: RLChartTimeframe = .h1
    
    @Binding var panelHeight: CGFloat
    @Binding var expandedPanelHeight: CGFloat
    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 250
    // MARK: - Private State
    
    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var totalCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
    }
    
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }

    private var panelTopPadding: CGFloat {
        18
    }

    private var panelBottomPadding: CGFloat {
        4
    }

    private var isCollapsed: Bool {
        ChartPanelReserveCalculator.isCollapsedPanelHeight(panelHeight)
    }
    
    private var macdConfig: MACDConfig? {
        indicatorManager.activeIndicators.macd
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }

    private var macdHeaderLabel: String {
        if let config = macdConfig {
            return "MACD \(config.fastPeriod) \(config.slowPeriod) \(config.signalPeriod)"
        }
        return "MACD"
    }

    private var zoomPolicy: IndicatorPanelZoomPolicy {
        .visible(includeZero: true, symmetricAroundZero: true, minimumScale: 0.8)
    }

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            resizeHandleBar

            if !isCollapsed {
                LinkedIndicatorPanelGestureSurface(
                    gestureState: gestureState,
                    verticalState: viewportState,
                    candleCount: chartData.candles.count,
                    baseCandleWidth: baseCandleWidth,
                    candleSpacing: candleSpacing,
                    minVerticalScale: zoomPolicy.minimumScale,
                    yAxisWidth: ChartAxisMetrics.indicatorPanelYAxisLaneWidth
                ) {
                    macdContentArea
                }
                    .frame(height: panelHeight)
            }
        }
        .background(AppColors.chartPanelBackgroundMuted)
        .chartPanelBottomHairline()
    }
    
    // MARK: - Resize Handle
    
    private var resizeHandleBar: some View {
        ChartPanelResizeHandleLabel(
            primaryText: macdHeaderLabel,
            suffixText: "Indicator",
            isCollapsed: isCollapsed,
            isDragging: isDraggingHandle,
            style: .indicator
        )
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    if !isDraggingHandle {
                        isDraggingHandle = true
                        dragStartHeight = isCollapsed
                            ? max(minPanelHeight, expandedPanelHeight > 0 ? expandedPanelHeight : minPanelHeight)
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
                    if isCollapsed {
                        expandPanel()
                    }
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
    }

    private func collapsePanel() {
        guard !isCollapsed else { return }
        let nextState = ChartPanelPresentationPolicy.collapsed(
            currentHeight: panelHeight,
            expandedHeight: expandedPanelHeight,
            minHeight: minPanelHeight
        )
        panelHeight = nextState.currentHeight
        expandedPanelHeight = nextState.expandedHeight
    }

    private func expandPanel() {
        guard isCollapsed else { return }
        let nextState = ChartPanelPresentationPolicy.expanded(
            expandedHeight: expandedPanelHeight,
            minHeight: minPanelHeight,
            maxHeight: maxPanelHeight
        )
        panelHeight = nextState.currentHeight
        expandedPanelHeight = nextState.expandedHeight
    }
    
    // MARK: - MACD Content
    
    private var macdContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = viewportState.priceScale
        let _ = viewportState.verticalPanOffset
        
        return ZStack {
            AppColors.indicatorPanelPlotBackground
            
            Canvas { context, size in
                drawMACDPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            yAxisLabelsOverlay
            currentMACDIndicator
            miniInfoOverlay
        }
        .clipped()
    }
    
    // MARK: - Canvas Drawing
    
    private func drawMACDPanel(context: GraphicsContext, size: CGSize) {
        PanelGridHelper.drawVerticalGridLines(
            context: context, size: size,
            candles: chartData.candles, timeframe: timeframe,
            totalOffset: totalOffset, totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth
        )

        guard let config = macdConfig else { return }
        let viewport = transformedViewport(size: size)
        guard viewport.rawValueRange.max > viewport.rawValueRange.min else { return }

        // Draw zero line
        drawZeroLine(context: context, size: size, viewport: viewport)
        drawDomainBoundaryLines(context: context, size: size, viewport: viewport)
        
        // Draw histogram
        if config.showHistogram {
            drawHistogram(context: context, size: size, config: config, viewport: viewport)
        }
        
        // Draw signal line (behind MACD)
        if config.showSignalLine {
            drawSignalLine(context: context, size: size, config: config, viewport: viewport)
        }
        
        // Draw MACD line (on top)
        drawMACDLine(context: context, size: size, config: config, viewport: viewport)
    }
    
    private func drawZeroLine(context: GraphicsContext, size: CGSize, viewport: IndicatorPanelViewport) {
        let zeroY = viewport.yPosition(for: 0)
        let lineEndX = plotEndX(totalWidth: size.width)
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: zeroY))
        path.addLine(to: CGPoint(x: lineEndX, y: zeroY))
        
        context.stroke(path, with: .color(AppColors.surfaceGray50), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
    }
    
    private func drawHistogram(context: GraphicsContext, size: CGSize, config: MACDConfig, viewport: IndicatorPanelViewport) {
        let visiblePoints = visibleMACDPoints(for: size.width)
        let zeroY = viewport.yPosition(for: 0)
        let barWidth = actualCandleWidth * 0.6
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = viewport.yPosition(for: point.histogram)
            
            guard x >= -barWidth && x <= size.width + barWidth else { continue }
            
            let barRect: CGRect
            let color: Color
            
            if point.histogram >= 0 {
                barRect = CGRect(x: x - barWidth/2, y: y, width: barWidth, height: zeroY - y)
                color = config.histogramPositiveColor.color
            } else {
                barRect = CGRect(x: x - barWidth/2, y: zeroY, width: barWidth, height: y - zeroY)
                color = config.histogramNegativeColor.color
            }
            
            context.fill(Path(barRect), with: .color(color))
        }
    }
    
    private func drawMACDLine(context: GraphicsContext, size: CGSize, config: MACDConfig, viewport: IndicatorPanelViewport) {
        let visiblePoints = visibleMACDPoints(for: size.width)
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = viewport.yPosition(for: point.macdLine)
            
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(config.color.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    private func drawSignalLine(context: GraphicsContext, size: CGSize, config: MACDConfig, viewport: IndicatorPanelViewport) {
        let visiblePoints = visibleMACDPoints(for: size.width)
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = viewport.yPosition(for: point.signalLine)
            
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(config.signalColor.color), style: StrokeStyle(lineWidth: config.lineWidth * 0.8, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Coordinate Helpers
    
    private func xPosition(for candleIndex: Int) -> CGFloat {
        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
    }

    private func transformedViewport(size: CGSize) -> IndicatorPanelViewport {
        IndicatorPanelViewport(
            rawValueRange: macdDataRange(for: size.width),
            topPadding: panelTopPadding,
            bottomPadding: panelBottomPadding,
            visualHeight: size.height,
            priceScale: viewportState.priceScale,
            verticalPanOffset: viewportState.verticalPanOffset
        )
    }

    private func plotEndX(totalWidth: CGFloat) -> CGFloat {
        ChartAxisMetrics.plotWidth(
            totalWidth: totalWidth,
            axisLaneWidth: ChartAxisMetrics.indicatorPanelYAxisLaneWidth
        )
    }

    private func visibleMACDPoints(for totalWidth: CGFloat) -> [MACDDataPoint] {
        let dataPoints = indicatorManager.macdData
        guard !dataPoints.isEmpty else { return [] }

        let plotWidth = plotEndX(totalWidth: totalWidth)
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(plotWidth / totalCandleWidth) + 10)
        return dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
    }

    private func macdDataRange(for totalWidth: CGFloat) -> (min: Double, max: Double) {
        let visiblePoints = visibleMACDPoints(for: totalWidth)
        let allPoints = indicatorManager.macdData
        let visibleValues = visiblePoints.flatMap { [$0.macdLine, $0.signalLine, $0.histogram] }
        let fallbackValues = allPoints.flatMap { [$0.macdLine, $0.signalLine, $0.histogram] }
        return zoomPolicy.resolvedRange(
            visibleValues: visibleValues,
            fallbackValues: fallbackValues,
            emphasisValues: [0]
        )
    }
    
    // MARK: - Current Value Indicator
    
    private var currentMACDIndicator: some View {
        GeometryReader { geometry in
            if let latestMACD = indicatorManager.latestMACD {
                let viewport = transformedViewport(size: geometry.size)
                let y = viewport.yPosition(for: latestMACD.macdLine)
                
                if y >= viewport.topPadding && y <= viewport.contentBottomY {
                    Canvas { context, size in
                        let lineEndX = plotEndX(totalWidth: size.width)
                        
                        let linePath = Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: lineEndX, y: y))
                        }
                        
                        let lineColor = latestMACD.macdLine >= 0 ? AppColors.statusPositive : AppColors.statusNegative
                        context.stroke(linePath, with: .color(lineColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        
                        let labelRect = CGRect(x: size.width - 55, y: y - 9, width: 50, height: 18)
                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
                        context.fill(roundedPath, with: .color(lineColor))
                        
                        let text = Text(formatMACDValue(latestMACD.macdLine))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(PanelChromeTextColorResolver.textColor(for: lineColor))
                        
                        context.draw(text, at: CGPoint(x: labelRect.midX, y: y))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Crosshair Line
    
    private var crosshairLine: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: activeGuideX, y: 0))
                path.addLine(to: CGPoint(x: activeGuideX, y: geometry.size.height))
            }
            .stroke(activeGuideColor, style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
        }
        .allowsHitTesting(false)
    }

    private var activeGuideX: CGFloat {
        gestureState.crosshairActive ? gestureState.crosshairX : gestureState.markerPlacementGuide.x
    }

    private var activeGuideColor: Color {
        gestureState.crosshairActive ? AppColors.crosshairGuideStroke : AppColors.statusInfo60
    }
    
    // MARK: - Y-Axis Labels
    
    private var yAxisLabelsOverlay: some View {
        GeometryReader { geometry in
            let viewport = transformedViewport(size: geometry.size)
            HStack(spacing: 0) {
                Spacer()
                IndicatorPanelYAxisLane(
                    viewport: viewport,
                    labels: viewport.dynamicLevels(
                        emphasis: [0, viewport.rawValueRange.min, viewport.rawValueRange.max]
                    ).map { value in
                        IndicatorPanelYAxisLabel(
                            value: value,
                            text: formatMACDValue(value),
                            color: abs(value) < 0.000001
                                ? AppColors.panelYAxisLaneText
                                : AppColors.panelYAxisLaneText
                        )
                    },
                    laneWidth: ChartAxisMetrics.indicatorPanelYAxisLaneWidth,
                    labelWidth: ChartAxisMetrics.indicatorPanelYAxisLabelWidth
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var miniInfoOverlay: some View {
        Group {
            if let latest = indicatorManager.latestMACD {
                PanelMiniInfoOverlay(
                    tokens: [
                        PanelMiniInfoToken(
                            label: "M",
                            value: formatMACDValue(latest.macdLine),
                            valueColor: PanelChromeTextColorResolver.readableAccentColor(macdConfig?.color.color ?? .cyan)
                        ),
                        PanelMiniInfoToken(
                            label: "S",
                            value: formatMACDValue(latest.signalLine),
                            valueColor: PanelChromeTextColorResolver.readableAccentColor(macdConfig?.signalColor.color ?? .orange)
                        ),
                        PanelMiniInfoToken(
                            label: "H",
                            value: formatMACDValue(latest.histogram),
                            valueColor: latest.isHistogramPositive ? AppColors.statusPositive : AppColors.statusNegative
                        ),
                    ],
                    trailingBadge: latest.crossoverType == .neutral ? nil : macdConditionBadge(crossover: latest.crossoverType)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
        .padding(.leading, 8)
        .allowsHitTesting(false)
    }
    
    private func macdConditionBadge(crossover: MACDCrossover) -> PanelMiniInfoBadge {
        PanelMiniInfoBadge(text: crossover.label, color: crossover.color.opacity(0.82))
    }
    
    private func formatMACDValue(_ value: Double) -> String {
        if abs(value) >= 100 {
            return String(format: "%.1f", value)
        } else if abs(value) >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.4f", value)
        }
    }

    private func drawDomainBoundaryLines(
        context: GraphicsContext,
        size: CGSize,
        viewport: IndicatorPanelViewport
    ) {
        drawIndicatorPanelGuideLines(
            context: context,
            viewport: viewport,
            plotWidth: plotEndX(totalWidth: size.width),
            guides: [
                IndicatorPanelGuideLine(
                    value: viewport.rawValueRange.max,
                    color: AppColors.panelYAxisLaneText.opacity(0.48),
                    lineWidth: 0.7,
                    dash: [3, 3]
                ),
                IndicatorPanelGuideLine(
                    value: viewport.rawValueRange.min,
                    color: AppColors.panelYAxisLaneText.opacity(0.48),
                    lineWidth: 0.7,
                    dash: [3, 3]
                ),
            ]
        )
    }
    
    // MARK: - X-Axis Labels
    
    private var xAxisLabels: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = gestureState.crosshairX
        let _ = gestureState.markerPlacementGuide.isActive

        let labelH = ChartPanelReserveCalculator.panelXAxisTimeLabelAreaHeight
        let footH = ChartPanelReserveCalculator.panelXAxisLabelBottomFootHeight

        return VStack(spacing: 0) {
            ZStack {
                Canvas { context, size in
                    drawXAxisLabels(context: context, size: size)
                }
                .frame(height: labelH)
                .background(AppColors.xAxisBackground)

                if gestureState.crosshairActive, let timestamp = gestureState.crosshairTimestamp {
                    crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: gestureState.crosshairX)
                } else if gestureState.markerPlacementGuide.isActive, let timestamp = gestureState.markerPlacementGuide.timestamp {
                    crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: gestureState.markerPlacementGuide.x)
                }
            }
            .frame(height: labelH)

            Rectangle()
                .fill(AppColors.xAxisBackground)
                .frame(height: footH)
        }
        .frame(height: ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
    }
    
    @ViewBuilder
    private func crosshairTimeLabelOverlay(timestamp: Date, xPosition: CGFloat) -> some View {
        if xPosition.isFinite {
            CrosshairTimeLabel(
                timestamp: timestamp,
                timeframe: timeframe,
                timeZone: chartData.currentSymbol?.exchangeTimeZone ?? .current
            )
            .position(
                x: CrosshairTimeLabel.clampedCenterX(
                    rawX: xPosition,
                    timestamp: timestamp,
                    timeframe: timeframe,
                    timeZone: chartData.currentSymbol?.exchangeTimeZone ?? .current,
                    availableWidth: UIScreen.main.bounds.width
                ),
                y: CrosshairTimeLabel.indicatorHeight * 0.5
            )
        }
    }
    
    private func drawXAxisLabels(context: GraphicsContext, size: CGSize) {
        ChartXAxisLabelEngine.drawLabels(
            context: context,
            size: size,
            input: .init(
                candles: chartData.candles,
                timeframe: timeframe,
                totalOffset: totalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                width: size.width,
                timeZone: chartData.currentSymbol?.exchangeTimeZone ?? .current,
                locale: Locale(identifier: "en_US_POSIX"),
                minSpacing: 52
            ),
            style: .indicatorPanel
        )
    }
}
