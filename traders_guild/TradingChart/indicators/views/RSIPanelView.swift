//
//  RSIPanelView.swift
//  traders_guild
//
//  Updated stacked-panel version
//

import SwiftUI

enum ChartPanelHeaderStripKind {
    case indicator
    /// Grey gradient strip with blue frame (timeframe resize bar only; matches main chart x-axis).
    case timeframe
    /// Solid dark strip for live price + LIVE row (no blue wash).
    case timeframePrice
}

struct IndicatorPanelHeaderRow: View {
    let title: String
    let valueText: String?
    let valueColor: Color
    let badgeText: String?
    let badgeColor: Color?
    var stripKind: ChartPanelHeaderStripKind = .indicator

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.indicatorPanelHeaderTitle)

            if let valueText {
                Text(valueText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
            }

            if let badgeText, let badgeColor, !badgeText.isEmpty {
                Text(badgeText)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.onAccentForeground)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.8))
                    .cornerRadius(3)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background { headerStripBackground }
    }

    @ViewBuilder
    private var headerStripBackground: some View {
        switch stripKind {
        case .indicator:
            AppColors.indicatorPanelChromeStripBackground
        case .timeframe:
            LinearGradient(
                colors: [
                    AppColors.timeframePanelAxisGradientTop,
                    AppColors.timeframePanelAxisGradientBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppColors.timeframePanelAxisFrameBorder)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.timeframePanelAxisFrameBorder)
                    .frame(height: 1)
            }
        case .timeframePrice:
            AppColors.timeframePanelPriceHeaderBackground
        }
    }
}

struct ChartPanelResizeHandleLabel: View {
    let primaryText: String
    let suffixText: String
    let isCollapsed: Bool
    let isDragging: Bool
    var style: ChartPanelResizeHandleStyle = .indicator

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundFill)

            Capsule()
                .fill(isDragging ? AppColors.panelResizeHandleCapsuleDragging : AppColors.panelResizeHandleCapsuleIdle)
                .frame(width: 36, height: 5)

            HStack(spacing: 4) {
                (Text(primaryText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.panelResizeHandlePrimaryLabel)
                 + Text("  \(suffixText)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(suffixForeground))
                    .lineLimit(1)

                if isCollapsed {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.panelResizeHandleChevronForeground)
                }

                Spacer()
            }
            .padding(.leading, 10)
        }
        .frame(height: ChartPanelReserveCalculator.panelResizeHandleHeight)
        .contentShape(Rectangle())
        .chartPanelBottomHairline()
    }

    private var backgroundFill: Color {
        switch style {
        case .indicator:
            return AppColors.indicatorPanelHandleBackground
        case .timeframe:
            return AppColors.timeframePanelHandleBackground
        }
    }

    private var suffixForeground: Color {
        switch style {
        case .indicator:
            return AppColors.panelResizeHandleIndicatorSuffixForeground
        case .timeframe:
            return AppColors.panelResizeHandleTimeframeSuffixForeground
        }
    }
}

private struct ChartPanelBottomHairlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(
            Rectangle()
                .fill(AppColors.surfaceGray30)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

extension View {
    func chartPanelBottomHairline() -> some View {
        modifier(ChartPanelBottomHairlineModifier())
    }
}

// MARK: - RSI Panel View

struct RSIPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    @ObservedObject var viewportState: IndicatorPanelViewportState
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var timeframe: RLChartTimeframe = .h1
    
    // Panel height state
    @Binding var panelHeight: CGFloat
    @Binding var expandedPanelHeight: CGFloat
    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 300
    
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

    private var plotWidth: CGFloat {
        ChartAxisMetrics.plotWidth(totalWidth: UIScreen.main.bounds.width)
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
    
    private var rsiConfig: RSIConfig? {
        indicatorManager.activeIndicators.rsi
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }

    private var panelDisplayName: String {
        (rsiConfig?.label ?? "RSI 14") + " Indicator"
    }

    private var zoomPolicy: IndicatorPanelZoomPolicy {
        .fixed(range: 0...100, minimumScale: 1.0)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandleBar

            if !isCollapsed {
                // RSI content area with pan gesture
                LinkedIndicatorPanelGestureSurface(
                    gestureState: gestureState,
                    verticalState: viewportState,
                    candleCount: chartData.candles.count,
                    baseCandleWidth: baseCandleWidth,
                    candleSpacing: candleSpacing,
                    minVerticalScale: zoomPolicy.minimumScale,
                    yAxisWidth: ChartAxisMetrics.indicatorPanelYAxisLaneWidth
                ) {
                    rsiContentArea
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
            primaryText: rsiConfig?.label ?? "RSI 14",
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
    
    // MARK: - RSI Content
    
    private var rsiContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = viewportState.priceScale
        let _ = viewportState.verticalPanOffset
        
        return ZStack {
            AppColors.indicatorPanelPlotBackground
            
            Canvas { context, size in
                drawRSIPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            yAxisLabelsOverlay
            currentRSIIndicator
            miniInfoOverlay
        }
        .clipped()
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
        if gestureState.crosshairActive {
            return gestureState.crosshairX
        }
        return liveGuideX(forCandleIndex: gestureState.markerPlacementGuide.candleIndex)
            ?? gestureState.markerPlacementGuide.x
    }

    private func liveGuideX(forCandleIndex index: Int) -> CGFloat? {
        guard index >= 0, totalCandleWidth > 0 else { return nil }
        return CGFloat(index) * totalCandleWidth
            + gestureState.panOffset.width
            + actualCandleWidth / 2
    }

    private var activeGuideColor: Color {
        gestureState.crosshairActive ? AppColors.crosshairGuideStroke : AppColors.statusInfo60
    }
    
    // MARK: - Current RSI Indicator
    
    private var currentRSIIndicator: some View {
        GeometryReader { geometry in
            if let latestRSI = indicatorManager.latestRSI {
                let rsiValue = latestRSI.value
                let viewport = transformedViewport(height: geometry.size.height)
                let y = viewport.yPosition(for: rsiValue)
                
                if y >= viewport.topPadding && y <= viewport.contentBottomY && !rsiValue.isNaN {
                    Canvas { context, size in
                        let lineEndX = plotEndX(totalWidth: size.width)
                        
                        let linePath = Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: lineEndX, y: y))
                        }
                        
                        let lineColor = rsiIndicatorColor(for: rsiValue)
                        context.stroke(
                            linePath,
                            with: .color(lineColor.opacity(0.8)),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                        )
                        
                        let labelRect = CGRect(
                            x: size.width - 45,
                            y: y - 9,
                            width: 40,
                            height: 18
                        )
                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
                        context.fill(roundedPath, with: .color(lineColor))
                        
                        let text = Text(String(format: "%.1f", rsiValue))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(PanelChromeTextColorResolver.textColor(for: lineColor))
                        
                        context.draw(text, at: CGPoint(x: labelRect.midX, y: y))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func rsiIndicatorColor(for value: Double) -> Color {
        let overbought = rsiConfig?.overboughtLevel ?? 70
        let oversold = rsiConfig?.oversoldLevel ?? 30
        
        if value >= overbought {
            return .red
        } else if value <= oversold {
            return .green
        } else {
            return .purple
        }
    }
    
    private var miniInfoOverlay: some View {
        Group {
            if let latest = indicatorManager.latestRSI {
                let condition = rsiCondition(for: latest.value)
                PanelMiniInfoOverlay(
                    tokens: [
                        PanelMiniInfoToken(
                            label: nil,
                            value: String(format: "%.1f", latest.value),
                            valueColor: condition.label.isEmpty ? AppColors.panelMiniInfoOverlayPrimaryText : condition.color
                        ),
                    ],
                    trailingBadge: condition.label.isEmpty
                        ? nil
                        : PanelMiniInfoBadge(text: condition.label, color: condition.color.opacity(0.88))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
        .padding(.leading, 8)
        .allowsHitTesting(false)
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
    
    // MARK: - Canvas Drawing
    
    private func drawRSIPanel(context: GraphicsContext, size: CGSize) {
        PanelGridHelper.drawVerticalGridLines(
            context: context, size: size,
            candles: chartData.candles, timeframe: timeframe,
            totalOffset: totalOffset, totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth
        )

        guard let config = rsiConfig else { return }

        let viewport = transformedViewport(height: size.height)

        drawZones(context: context, size: size, config: config, viewport: viewport)
        drawReferenceLevels(context: context, size: size, config: config, viewport: viewport)
        drawRSILine(context: context, size: size, config: config, viewport: viewport)
    }
    
    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, viewport: IndicatorPanelViewport) {
        guard config.showLevels else { return }
        
        let overboughtY = viewport.yPosition(for: config.overboughtLevel)
        let oversoldY = viewport.yPosition(for: config.oversoldLevel)
        let topY = viewport.yPosition(for: 100)
        let bottomY = viewport.yPosition(for: 0)
        let lineEndX = plotEndX(totalWidth: size.width)
        
        let overboughtZone = Path { p in
            p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY))
        }
        context.fill(overboughtZone, with: .color(AppColors.statusNegative08))
        
        let oversoldZone = Path { p in
            p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY))
        }
        context.fill(oversoldZone, with: .color(AppColors.statusPositive08))
    }
    
    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, viewport: IndicatorPanelViewport) {
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
    
    private func drawRSILine(context: GraphicsContext, size: CGSize, config: RSIConfig, viewport: IndicatorPanelViewport) {
        let dataPoints = indicatorManager.rsiData
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = viewport.yPosition(for: point.value)
            
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

    private var yAxisLabels: [IndicatorPanelYAxisLabel] {
        deduplicatedLabels([
            IndicatorPanelYAxisLabel(value: 100, text: "100", color: AppColors.panelYAxisLaneText),
            IndicatorPanelYAxisLabel(
                value: rsiConfig?.overboughtLevel ?? 70,
                text: String(format: "%.0f", rsiConfig?.overboughtLevel ?? 70),
                color: AppColors.statusNegative85
            ),
            IndicatorPanelYAxisLabel(value: 50, text: "50", color: AppColors.panelYAxisLaneText),
            IndicatorPanelYAxisLabel(
                value: rsiConfig?.oversoldLevel ?? 30,
                text: String(format: "%.0f", rsiConfig?.oversoldLevel ?? 30),
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
    
    private func rsiValueColor(_ value: Double) -> Color {
        rsiCondition(for: value).label.isEmpty ? AppColors.surfaceWhite90 : rsiCondition(for: value).color
    }

    private func rsiCondition(for value: Double) -> RSICondition {
        let overbought = rsiConfig?.overboughtLevel ?? 70
        let oversold = rsiConfig?.oversoldLevel ?? 30
        if value >= overbought { return .overbought }
        if value <= oversold { return .oversold }
        return .neutral
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
                    let liveX = liveGuideX(forCandleIndex: gestureState.markerPlacementGuide.candleIndex)
                        ?? gestureState.markerPlacementGuide.x
                    crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: liveX)
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
