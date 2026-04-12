//
//  StochasticPanelView.swift
//  traders_guild
//
//  Stochastic Panel View - Follows RSIPanelView pattern
//  Features: %K line, %D line, Overbought/Oversold zones (80/20)
//

import SwiftUI

struct StochasticPanelView: View {
    
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
    
    private var stochConfig: StochasticConfig? {
        indicatorManager.activeIndicators.stochastic
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }

    private var stochHeaderLabel: String {
        if let config = stochConfig {
            return "Stoch \(config.kPeriod) \(config.dPeriod) \(config.smoothK)"
        }
        return "Stochastic"
    }

    private var zoomPolicy: IndicatorPanelZoomPolicy {
        .fixed(range: 0...100, minimumScale: 1.0)
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
                    stochasticContentArea
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
            primaryText: stochHeaderLabel,
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
    
    // MARK: - Stochastic Content
    
    private var stochasticContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = viewportState.priceScale
        let _ = viewportState.verticalPanOffset
        
        return ZStack {
            AppColors.indicatorPanelPlotBackground
            
            Canvas { context, size in
                drawStochasticPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            yAxisLabelsOverlay
            currentStochIndicator
            miniInfoOverlay
        }
        .clipped()
    }
    
    // MARK: - Canvas Drawing
    
    private func drawStochasticPanel(context: GraphicsContext, size: CGSize) {
        PanelGridHelper.drawVerticalGridLines(
            context: context, size: size,
            candles: chartData.candles, timeframe: timeframe,
            totalOffset: totalOffset, totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth
        )

        guard let config = stochConfig else { return }

        let viewport = transformedViewport(height: size.height)

        drawZones(context: context, size: size, config: config, viewport: viewport)
        drawReferenceLevels(context: context, size: size, config: config, viewport: viewport)
        drawDLine(context: context, size: size, config: config, viewport: viewport)
        drawKLine(context: context, size: size, config: config, viewport: viewport)
    }
    
    private func drawZones(context: GraphicsContext, size: CGSize, config: StochasticConfig, viewport: IndicatorPanelViewport) {
        guard config.showLevels else { return }
        
        let overboughtY = viewport.yPosition(for: config.overboughtLevel)
        let oversoldY = viewport.yPosition(for: config.oversoldLevel)
        let topY = viewport.yPosition(for: 100)
        let bottomY = viewport.yPosition(for: 0)
        let lineEndX = plotEndX(totalWidth: size.width)
        
        let overboughtZone = Path { p in
            p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY))
        }
        context.fill(overboughtZone, with: .color(config.overboughtColor.color))
        
        let oversoldZone = Path { p in
            p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY))
        }
        context.fill(oversoldZone, with: .color(config.oversoldColor.color))
    }
    
    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: StochasticConfig, viewport: IndicatorPanelViewport) {
        let lineEndX = plotEndX(totalWidth: size.width)

        drawIndicatorPanelGuideLines(
            context: context,
            viewport: viewport,
            plotWidth: lineEndX,
            guides: [
                IndicatorPanelGuideLine(
                    value: 100,
                    color: AppColors.panelYAxisLaneText.opacity(0.5),
                    lineWidth: 0.7,
                    dash: [3, 3]
                ),
                IndicatorPanelGuideLine(
                    value: config.overboughtLevel,
                    color: AppColors.statusNegative40,
                    lineWidth: 0.5,
                    dash: [4, 4]
                ),
                IndicatorPanelGuideLine(
                    value: 50,
                    color: AppColors.surfaceGray30,
                    lineWidth: 0.5,
                    dash: [2, 2]
                ),
                IndicatorPanelGuideLine(
                    value: config.oversoldLevel,
                    color: AppColors.statusPositive40,
                    lineWidth: 0.5,
                    dash: [4, 4]
                ),
                IndicatorPanelGuideLine(
                    value: 0,
                    color: AppColors.panelYAxisLaneText.opacity(0.5),
                    lineWidth: 0.7,
                    dash: [3, 3]
                ),
            ]
        )
    }
    
    private func drawKLine(context: GraphicsContext, size: CGSize, config: StochasticConfig, viewport: IndicatorPanelViewport) {
        let dataPoints = indicatorManager.stochasticData
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = viewport.yPosition(for: point.kValue)
            
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
    
    private func drawDLine(context: GraphicsContext, size: CGSize, config: StochasticConfig, viewport: IndicatorPanelViewport) {
        let dataPoints = indicatorManager.stochasticData
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = viewport.yPosition(for: point.dValue)
            
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(config.dColor.color), style: StrokeStyle(lineWidth: config.lineWidth * 0.8, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Coordinate Helpers
    
    private func xPosition(for candleIndex: Int) -> CGFloat {
        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
    }

    private func transformedViewport(height: CGFloat) -> IndicatorPanelViewport {
        IndicatorPanelViewport(
            rawValueRange: zoomPolicy.resolvedRange(visibleValues: [], fallbackValues: [], emphasisValues: []),
            topPadding: panelTopPadding,
            bottomPadding: panelBottomPadding,
            visualHeight: height,
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
    
    // MARK: - Current Value Indicator
    
    private var currentStochIndicator: some View {
        GeometryReader { geometry in
            if let latestStoch = indicatorManager.latestStochastic {
                let kValue = latestStoch.kValue
                let viewport = transformedViewport(height: geometry.size.height)
                let y = viewport.yPosition(for: kValue)
                
                if y >= viewport.topPadding && y <= viewport.contentBottomY && !kValue.isNaN {
                    Canvas { context, size in
                        let lineEndX = plotEndX(totalWidth: size.width)
                        
                        let linePath = Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: lineEndX, y: y))
                        }
                        
                        let lineColor = stochIndicatorColor(for: kValue)
                        context.stroke(linePath, with: .color(lineColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        
                        let labelRect = CGRect(x: size.width - 45, y: y - 9, width: 40, height: 18)
                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
                        context.fill(roundedPath, with: .color(lineColor))
                        
                        let text = Text(String(format: "%.1f", kValue))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(PanelChromeTextColorResolver.textColor(for: lineColor))
                        
                        context.draw(text, at: CGPoint(x: labelRect.midX, y: y))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func stochIndicatorColor(for value: Double) -> Color {
        let overbought = stochConfig?.overboughtLevel ?? 80
        let oversold = stochConfig?.oversoldLevel ?? 20
        
        if value >= overbought { return .red }
        else if value <= oversold { return .green }
        else { return .yellow }
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
            HStack(spacing: 0) {
                Spacer()
                IndicatorPanelYAxisLane(
                    viewport: transformedViewport(height: geometry.size.height),
                    labels: yAxisLabels,
                    laneWidth: ChartAxisMetrics.indicatorPanelYAxisLaneWidth,
                    labelWidth: ChartAxisMetrics.indicatorPanelYAxisLabelWidth
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var miniInfoOverlay: some View {
        Group {
            if let latest = indicatorManager.latestStochastic {
                PanelMiniInfoOverlay(
                    tokens: [
                        PanelMiniInfoToken(
                            label: "%K",
                            value: String(format: "%.1f", latest.kValue),
                            valueColor: PanelChromeTextColorResolver.readableAccentColor(stochConfig?.color.color ?? .yellow)
                        ),
                        PanelMiniInfoToken(
                            label: "%D",
                            value: String(format: "%.1f", latest.dValue),
                            valueColor: PanelChromeTextColorResolver.readableAccentColor(stochConfig?.dColor.color ?? .red)
                        ),
                    ],
                    trailingBadge: stochConditionBadge(value: latest.kValue)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
        .padding(.leading, 8)
        .allowsHitTesting(false)
    }
    
    private func stochConditionBadge(value: Double) -> PanelMiniInfoBadge? {
        let overbought = stochConfig?.overboughtLevel ?? 80
        let oversold = stochConfig?.oversoldLevel ?? 20
        
        if value >= overbought {
            return PanelMiniInfoBadge(text: "OVERBOUGHT", color: AppColors.statusNegative80)
        } else if value <= oversold {
            return PanelMiniInfoBadge(text: "OVERSOLD", color: AppColors.statusPositive80)
        }
        return nil
    }

    private var yAxisLabels: [IndicatorPanelYAxisLabel] {
        deduplicatedLabels([
            IndicatorPanelYAxisLabel(value: 100, text: "100", color: AppColors.panelYAxisLaneText),
            IndicatorPanelYAxisLabel(
                value: stochConfig?.overboughtLevel ?? 80,
                text: String(format: "%.0f", stochConfig?.overboughtLevel ?? 80),
                color: AppColors.statusNegative85
            ),
            IndicatorPanelYAxisLabel(value: 50, text: "50", color: AppColors.panelYAxisLaneText),
            IndicatorPanelYAxisLabel(
                value: stochConfig?.oversoldLevel ?? 20,
                text: String(format: "%.0f", stochConfig?.oversoldLevel ?? 20),
                color: AppColors.statusPositive85
            ),
            IndicatorPanelYAxisLabel(value: 0, text: "0", color: AppColors.panelYAxisLaneText),
        ])
    }

    private func deduplicatedLabels(
        _ labels: [IndicatorPanelYAxisLabel],
        tolerance: Double = 0.25
    ) -> [IndicatorPanelYAxisLabel] {
        var filtered: [IndicatorPanelYAxisLabel] = []

        for label in labels {
            guard !filtered.contains(where: { abs($0.value - label.value) <= tolerance }) else { continue }
            filtered.append(label)
        }

        return filtered
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
