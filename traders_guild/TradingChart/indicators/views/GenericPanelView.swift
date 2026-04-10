//
//  GenericIndicatorPanelView.swift
//  traders_guild
//
//  Generic panel view that can display CCI, Williams %R, ATR, or Volume indicators
//

import SwiftUI

struct GenericIndicatorPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    @ObservedObject var viewportState: IndicatorPanelViewportState
    
    let panelType: PanelIndicatorType
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var timeframe: RLChartTimeframe = .h1
    
    @Binding var panelHeight: CGFloat
    @Binding var expandedPanelHeight: CGFloat
    let minPanelHeight: CGFloat
    let maxPanelHeight: CGFloat
    
    // MARK: - Private State
    
    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }
    
    private var totalCandleWidth: CGFloat {
        actualCandleWidth + candleSpacing
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
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }
    
    private var panelTitleBase: String {
        switch panelType {
        case .cci:
            if let config = indicatorManager.activeIndicators.cci {
                return "CCI \(config.period)"
            }
            return "CCI"
        case .williamsR:
            if let config = indicatorManager.activeIndicators.williamsR {
                return "%R \(config.period)"
            }
            return "%R"
        case .atr:
            if let config = indicatorManager.activeIndicators.atr {
                return "ATR \(config.period)"
            }
            return "ATR"
        case .volume: return "Volume"
        default: return panelType.displayName
        }
    }
    
    private var lineColor: Color {
        switch panelType {
        case .cci: return indicatorManager.activeIndicators.cci?.color.color ?? .orange
        case .williamsR: return indicatorManager.activeIndicators.williamsR?.color.color ?? .pink
        case .atr: return indicatorManager.activeIndicators.atr?.color.color ?? .red
        case .volume: return indicatorManager.activeIndicators.volume?.color.color ?? .blue
        default: return .white
        }
    }

    private var cciConfig: CCIConfig? {
        indicatorManager.activeIndicators.cci
    }

    private var volumeConfig: VolumeConfig? {
        indicatorManager.activeIndicators.volume
    }

    private var zoomPolicy: IndicatorPanelZoomPolicy {
        switch panelType {
        case .cci:
            return .visible(includeZero: true, minimumScale: 0.8)
        case .williamsR:
            return .fixed(range: -100...0, minimumScale: 1.0)
        case .atr:
            return .visible(hardLowerBound: 0, includeZero: true, minimumScale: 0.8)
        case .volume:
            return .visible(hardLowerBound: 0, includeZero: true, minimumScale: 0.8)
        default:
            return .visible(minimumScale: 0.8)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandleBar

            if !isCollapsed {
                // Panel content area with pan gesture
                LinkedIndicatorPanelGestureSurface(
                    gestureState: gestureState,
                    verticalState: viewportState,
                    candleCount: chartData.candles.count,
                    baseCandleWidth: baseCandleWidth,
                    candleSpacing: candleSpacing,
                    minVerticalScale: zoomPolicy.minimumScale
                ) {
                    panelContentArea
                }
                    .frame(height: panelHeight)
            }
        }
        .background(AppColors.chartPanelBackgroundMuted)
        .chartPanelBottomHairline()
    }
    
    // MARK: - Resize Handle (matches RSIPanelView exactly)
    
    private var resizeHandleBar: some View {
        ChartPanelResizeHandleLabel(
            primaryText: panelTitleBase,
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
    
    // MARK: - Panel Content Area
    
    private var panelContentArea: some View {
        // Force view update when gesture state changes
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = viewportState.priceScale
        let _ = viewportState.verticalPanOffset
        
        return ZStack {
            AppColors.indicatorPanelPlotBackground

            Canvas { context, size in
                drawPanel(context: context, size: size)
            }
            
            // Crosshair line overlay
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            // Y-axis labels on the right
            yAxisLabelsOverlay
            
            // Current value indicator
            currentValueIndicator
            
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
        gestureState.crosshairActive ? gestureState.crosshairX : gestureState.markerPlacementGuide.x
    }

    private var activeGuideColor: Color {
        gestureState.crosshairActive ? AppColors.crosshairGuideStroke : AppColors.statusInfo60
    }
    
    // MARK: - Y-Axis Labels Overlay
    
    private var yAxisLabelsOverlay: some View {
        GeometryReader { geometry in
            let viewport = transformedViewport(size: geometry.size)
            HStack(spacing: 0) {
                Spacer()
                IndicatorPanelYAxisLane(
                    viewport: viewport,
                    labels: yAxisLabels(for: viewport)
                )
            }
        }
    }
    
    // MARK: - Current Value Indicator
    
    private var currentValueIndicator: some View {
        GeometryReader { geometry in
            if let currentValue = getCurrentValue() {
                let viewport = transformedViewport(size: geometry.size)
                let y = viewport.yPosition(for: currentValue)
                
                if y >= viewport.topPadding && y <= viewport.contentBottomY {
                    // Dashed line to current value
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: plotEndX(totalWidth: geometry.size.width), y: y))
                    }
                    .stroke(lineColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    
                    // Current value label
                    Text(formatValue(currentValue))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.onAccentForeground)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(lineColor.opacity(0.8))
                        .cornerRadius(3)
                        .position(x: geometry.size.width - 24, y: y)
                }
            }
        }
    }
    
    private var miniInfoOverlay: some View {
        VStack(alignment: .leading) {
            let state = panelHeaderState
            if !state.tokens.isEmpty || state.badge != nil {
                PanelMiniInfoOverlay(
                    tokens: state.tokens,
                    trailingBadge: state.badge
                )
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.leading, 8)
        .allowsHitTesting(false)
    }

    private var panelHeaderState: (tokens: [PanelMiniInfoToken], badge: PanelMiniInfoBadge?) {
        switch panelType {
        case .cci:
            guard let latest = indicatorManager.latestCCI else {
                return ([], nil)
            }
            let condition = cciCondition(for: latest.value)
            return (
                [
                    PanelMiniInfoToken(
                        label: nil,
                        value: String(format: "%.1f", latest.value),
                        valueColor: condition.label.isEmpty ? AppColors.panelMiniInfoOverlayPrimaryText : condition.color
                    ),
                ],
                condition.label.isEmpty ? nil : PanelMiniInfoBadge(text: condition.label, color: condition.color.opacity(0.88))
            )
        case .williamsR:
            guard let latest = indicatorManager.latestWilliamsR else {
                return ([], nil)
            }
            return (
                [
                    PanelMiniInfoToken(
                        label: nil,
                        value: String(format: "%.1f", latest.value),
                        valueColor: AppColors.panelMiniInfoOverlayPrimaryText
                    ),
                ],
                nil
            )
        case .atr:
            guard let latest = indicatorManager.latestATR else {
                return ([], nil)
            }
            let formatted = abs(latest.value) >= 1
                ? String(format: "%.2f", latest.value)
                : String(format: "%.4f", latest.value)
            return (
                [
                    PanelMiniInfoToken(
                        label: nil,
                        value: formatted,
                        valueColor: AppColors.panelMiniInfoOverlayPrimaryText
                    ),
                ],
                nil
            )
        case .volume:
            guard let latest = indicatorManager.volumeData.last else {
                return ([], nil)
            }
            let condition = latest.condition
            let badgeColor = condition == .bullish
                ? (volumeConfig?.bullishColor.color ?? .green)
                : (volumeConfig?.bearishColor.color ?? .red)
            let formatted = latest.volume >= 1_000_000
                ? String(format: "%.1fM", latest.volume / 1_000_000)
                : latest.volume >= 1_000
                    ? String(format: "%.1fK", latest.volume / 1_000)
                    : String(format: "%.0f", latest.volume)
            return (
                [
                    PanelMiniInfoToken(
                        label: nil,
                        value: formatted,
                        valueColor: badgeColor
                    ),
                ],
                PanelMiniInfoBadge(text: condition.label, color: badgeColor.opacity(0.88))
            )
        default:
            return ([], nil)
        }
    }
    
    // MARK: - X-Axis Labels (matches RSIPanelView exactly)
    
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
    
    // MARK: - Drawing
    
    private func drawPanel(context: GraphicsContext, size: CGSize) {
        PanelGridHelper.drawVerticalGridLines(
            context: context, size: size,
            candles: chartData.candles, timeframe: timeframe,
            totalOffset: totalOffset, totalCandleWidth: totalCandleWidth,
            actualCandleWidth: actualCandleWidth
        )

        let viewport = transformedViewport(size: size)

        switch panelType {
        case .cci:
            drawCCI(context: context, size: size, viewport: viewport)
        case .williamsR:
            drawWilliamsR(context: context, size: size, viewport: viewport)
        case .atr:
            drawATR(context: context, size: size, viewport: viewport)
        case .volume:
            drawVolume(context: context, size: size, viewport: viewport)
        default:
            break
        }
    }
    
    // MARK: - CCI Drawing
    
    private func drawCCI(context: GraphicsContext, size: CGSize, viewport: IndicatorPanelViewport) {
        let data = visibleCCIData(for: size.width)
        guard !data.isEmpty else { return }
        
        let config = indicatorManager.activeIndicators.cci
        let overbought = config?.overboughtLevel ?? 100
        let oversold = config?.oversoldLevel ?? -100
        
        drawOscillatorZones(
            context: context,
            size: size,
            viewport: viewport,
            overbought: overbought,
            oversold: oversold,
            midLine: 0
        )
        drawIndicatorLine(
            context: context,
            size: size,
            data: data.map { ($0.candleIndex, $0.value) },
            viewport: viewport,
            color: lineColor
        )
    }
    
    // MARK: - Williams %R Drawing
    
    private func drawWilliamsR(context: GraphicsContext, size: CGSize, viewport: IndicatorPanelViewport) {
        let data = visibleWilliamsRData(for: size.width)
        guard !data.isEmpty else { return }
        
        let config = indicatorManager.activeIndicators.williamsR
        let overbought = config?.overboughtLevel ?? -20
        let oversold = config?.oversoldLevel ?? -80
        
        drawOscillatorZones(
            context: context,
            size: size,
            viewport: viewport,
            overbought: overbought,
            oversold: oversold,
            midLine: -50
        )
        drawIndicatorLine(
            context: context,
            size: size,
            data: data.map { ($0.candleIndex, $0.value) },
            viewport: viewport,
            color: lineColor
        )
    }
    
    // MARK: - ATR Drawing
    
    private func drawATR(context: GraphicsContext, size: CGSize, viewport: IndicatorPanelViewport) {
        let data = visibleATRData(for: size.width)
        guard !data.isEmpty else { return }

        drawHorizontalReferenceGridLines(context: context, size: size, viewport: viewport)
        drawIndicatorLine(
            context: context,
            size: size,
            data: data.map { ($0.candleIndex, $0.value) },
            viewport: viewport,
            color: lineColor
        )
    }
    
    // MARK: - Volume Drawing
    
    private func drawVolume(context: GraphicsContext, size: CGSize, viewport: IndicatorPanelViewport) {
        let data = visibleVolumeData(for: size.width)
        guard !data.isEmpty else { return }
        
        let config = indicatorManager.activeIndicators.volume
        let bullColor = config?.bullishColor.color ?? .green
        let bearColor = config?.bearishColor.color ?? .red
        
        drawHorizontalReferenceGridLines(context: context, size: size, viewport: viewport)

        let plotEndX = plotEndX(totalWidth: size.width)
        let zeroY = viewport.yPosition(for: 0)

        for point in data {
            let x = CGFloat(point.candleIndex) * totalCandleWidth + totalOffset
            guard x + actualCandleWidth >= 0 && x <= plotEndX else { continue }

            let volumeY = viewport.yPosition(for: point.volume)
            let barRect = CGRect(
                x: x + candleSpacing / 2,
                y: min(volumeY, zeroY),
                width: actualCandleWidth,
                height: max(1, abs(zeroY - volumeY))
            )

            let barColor = point.isBullish ? bullColor : bearColor
            context.fill(Path(barRect), with: .color(barColor.opacity(0.7)))
        }
        
        if config?.showMA == true {
            var maPath = Path()
            var started = false
            
            for point in data {
                guard let ma = point.ma else { continue }
                let x = CGFloat(point.candleIndex) * totalCandleWidth + totalOffset + totalCandleWidth / 2
                let y = viewport.yPosition(for: ma)
                
                if !started {
                    maPath.move(to: CGPoint(x: x, y: y))
                    started = true
                } else {
                    maPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(maPath, with: .color(config?.maColor.color ?? .white), lineWidth: 1)
        }
    }
    
    // MARK: - Helper Drawing Functions
    
    private func drawOscillatorZones(
        context: GraphicsContext,
        size: CGSize,
        viewport: IndicatorPanelViewport,
        overbought: Double,
        oversold: Double,
        midLine: Double
    ) {
        let chartWidth = plotEndX(totalWidth: size.width)
        let obY = viewport.yPosition(for: overbought)
        let obRect = CGRect(x: 0, y: 0, width: chartWidth, height: obY)
        context.fill(Path(obRect), with: .color(AppColors.statusNegative10))
        
        let osY = viewport.yPosition(for: oversold)
        let osRect = CGRect(x: 0, y: osY, width: chartWidth, height: size.height - osY)
        context.fill(Path(osRect), with: .color(AppColors.statusPositive10))
        
        // Overbought line
        let obPath = Path { path in
            path.move(to: CGPoint(x: 0, y: obY))
            path.addLine(to: CGPoint(x: chartWidth, y: obY))
        }
        context.stroke(obPath, with: .color(AppColors.statusNegative50), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        // Oversold line
        let osPath = Path { path in
            path.move(to: CGPoint(x: 0, y: osY))
            path.addLine(to: CGPoint(x: chartWidth, y: osY))
        }
        context.stroke(osPath, with: .color(AppColors.statusPositive50), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        let midY = viewport.yPosition(for: midLine)
        let midPath = Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: chartWidth, y: midY))
        }
        context.stroke(midPath, with: .color(AppColors.surfaceGray30), lineWidth: 0.5)
    }
    
    private func drawHorizontalReferenceGridLines(
        context: GraphicsContext,
        size: CGSize,
        viewport: IndicatorPanelViewport
    ) {
        let plotWidth = plotEndX(totalWidth: size.width)
        guard plotWidth > 0 else { return }

        var path = Path()
        for value in viewport.dynamicLevels(emphasis: emphasisValues) {
            let y = viewport.yPosition(for: value)
            guard y >= viewport.topPadding - 20, y <= viewport.contentBottomY + 20 else { continue }
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: plotWidth, y: y))
        }

        context.stroke(path, with: .color(AppColors.surfaceGray20), lineWidth: 0.5)
    }

    private func drawIndicatorLine(
        context: GraphicsContext,
        size: CGSize,
        data: [(candleIndex: Int, value: Double)],
        viewport: IndicatorPanelViewport,
        color: Color
    ) {
        guard !data.isEmpty else { return }
        
        let chartWidth = plotEndX(totalWidth: size.width)
        
        var path = Path()
        var started = false
        
        for point in data {
            let x = CGFloat(point.candleIndex) * totalCandleWidth + totalOffset + totalCandleWidth / 2
            
            guard x >= -totalCandleWidth && x <= chartWidth + totalCandleWidth else { continue }
            
            let y = viewport.yPosition(for: point.value)
            
            if !started {
                path.move(to: CGPoint(x: x, y: y))
                started = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
    
    // MARK: - Value Helpers
    
    private func transformedViewport(size: CGSize) -> IndicatorPanelViewport {
        IndicatorPanelViewport(
            rawValueRange: resolvedValueRange(totalWidth: size.width),
            topPadding: panelTopPadding,
            bottomPadding: panelBottomPadding,
            visualHeight: size.height,
            priceScale: viewportState.priceScale,
            verticalPanOffset: viewportState.verticalPanOffset
        )
    }

    private func plotEndX(totalWidth: CGFloat) -> CGFloat {
        ChartAxisMetrics.plotWidth(totalWidth: totalWidth)
    }

    private func visibleIndexBounds(totalWidth: CGFloat) -> ClosedRange<Int>? {
        guard !chartData.candles.isEmpty, totalCandleWidth > 0 else { return nil }
        let plotWidth = plotEndX(totalWidth: totalWidth)
        let start = max(0, Int(floor(-totalOffset / totalCandleWidth)) - 5)
        let end = min(chartData.candles.count - 1, start + Int(ceil(plotWidth / totalCandleWidth)) + 10)
        guard start <= end else { return nil }
        return start...end
    }

    private func visibleCCIData(for totalWidth: CGFloat) -> [CCIDataPoint] {
        guard let bounds = visibleIndexBounds(totalWidth: totalWidth) else { return [] }
        return indicatorManager.cciData.filter { bounds.contains($0.candleIndex) }
    }

    private func visibleWilliamsRData(for totalWidth: CGFloat) -> [WilliamsRDataPoint] {
        guard let bounds = visibleIndexBounds(totalWidth: totalWidth) else { return [] }
        return indicatorManager.williamsRData.filter { bounds.contains($0.candleIndex) }
    }

    private func visibleATRData(for totalWidth: CGFloat) -> [ATRDataPoint] {
        guard let bounds = visibleIndexBounds(totalWidth: totalWidth) else { return [] }
        return indicatorManager.atrData.filter { bounds.contains($0.candleIndex) }
    }

    private func visibleVolumeData(for totalWidth: CGFloat) -> [VolumeDataPoint] {
        guard let bounds = visibleIndexBounds(totalWidth: totalWidth) else { return [] }
        return indicatorManager.volumeData.filter { bounds.contains($0.candleIndex) }
    }

    private var emphasisValues: [Double] {
        switch panelType {
        case .cci:
            return [cciConfig?.overboughtLevel ?? 100, cciConfig?.oversoldLevel ?? -100, 0]
        case .williamsR:
            return [
                indicatorManager.activeIndicators.williamsR?.overboughtLevel ?? -20,
                indicatorManager.activeIndicators.williamsR?.oversoldLevel ?? -80,
                -50
            ]
        case .atr, .volume:
            return [0]
        default:
            return [0]
        }
    }

    private func resolvedValueRange(totalWidth: CGFloat) -> (min: Double, max: Double) {
        switch panelType {
        case .cci:
            return zoomPolicy.resolvedRange(
                visibleValues: visibleCCIData(for: totalWidth).map(\.value),
                fallbackValues: indicatorManager.cciData.map(\.value),
                emphasisValues: emphasisValues
            )
        case .williamsR:
            return zoomPolicy.resolvedRange(
                visibleValues: visibleWilliamsRData(for: totalWidth).map(\.value),
                fallbackValues: indicatorManager.williamsRData.map(\.value),
                emphasisValues: emphasisValues
            )
        case .atr:
            return zoomPolicy.resolvedRange(
                visibleValues: visibleATRData(for: totalWidth).map(\.value),
                fallbackValues: indicatorManager.atrData.map(\.value),
                emphasisValues: emphasisValues
            )
        case .volume:
            let visibleValues = visibleVolumeData(for: totalWidth).flatMap { point -> [Double] in
                if let ma = point.ma {
                    return [point.volume, ma]
                }
                return [point.volume]
            }
            let fallbackValues = indicatorManager.volumeData.flatMap { point -> [Double] in
                if let ma = point.ma {
                    return [point.volume, ma]
                }
                return [point.volume]
            }
            return zoomPolicy.resolvedRange(
                visibleValues: visibleValues,
                fallbackValues: fallbackValues,
                emphasisValues: emphasisValues
            )
        default:
            return (0, 100)
        }
    }

    private func yAxisLabels(for viewport: IndicatorPanelViewport) -> [IndicatorPanelYAxisLabel] {
        viewport.dynamicLevels(emphasis: emphasisValues).map { value in
            IndicatorPanelYAxisLabel(
                value: value,
                text: formatValue(value),
                color: axisLabelColor(for: value)
            )
        }
    }

    private func axisLabelColor(for value: Double) -> Color {
        switch panelType {
        case .cci:
            let overbought = cciConfig?.overboughtLevel ?? 100
            let oversold = cciConfig?.oversoldLevel ?? -100
            if abs(value - overbought) < 0.5 { return AppColors.statusNegative85 }
            if abs(value - oversold) < 0.5 { return AppColors.statusPositive85 }
            return AppColors.panelYAxisLaneText
        case .williamsR:
            let overbought = indicatorManager.activeIndicators.williamsR?.overboughtLevel ?? -20
            let oversold = indicatorManager.activeIndicators.williamsR?.oversoldLevel ?? -80
            if abs(value - overbought) < 0.5 { return AppColors.statusNegative85 }
            if abs(value - oversold) < 0.5 { return AppColors.statusPositive85 }
            return AppColors.panelYAxisLaneText
        default:
            return AppColors.panelYAxisLaneText
        }
    }

    private func getCurrentValue() -> Double? {
        switch panelType {
        case .cci:
            return indicatorManager.cciData.last?.value
        case .williamsR:
            return indicatorManager.williamsRData.last?.value
        case .atr:
            return indicatorManager.atrData.last?.value
        case .volume:
            return indicatorManager.volumeData.last?.volume
        default:
            return nil
        }
    }

    private func cciCondition(for value: Double) -> CCICondition {
        let overbought = cciConfig?.overboughtLevel ?? 100
        let oversold = cciConfig?.oversoldLevel ?? -100
        if value >= overbought { return .overbought }
        if value <= oversold { return .oversold }
        return .neutral
    }
    
    private func formatValue(_ value: Double) -> String {
        switch panelType {
        case .cci, .williamsR:
            return String(format: "%.0f", value)
        case .atr:
            return String(format: "%.4f", value)
        case .volume:
            if value >= 1_000_000 {
                return String(format: "%.1fM", value / 1_000_000)
            } else if value >= 1_000 {
                return String(format: "%.1fK", value / 1_000)
            }
            return String(format: "%.0f", value)
        default:
            return String(format: "%.2f", value)
        }
    }
}
