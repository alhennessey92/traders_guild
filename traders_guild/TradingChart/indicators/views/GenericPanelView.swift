//
//  GenericIndicatorPanelView.swift
//  traders_guild
//
//  Generic panel view that can display CCI, Williams %R, ATR, or Volume indicators
//  Matches RSIPanelView structure exactly - crosshairs, Y-axis, pan gesture, x-axis
//

import SwiftUI

struct GenericIndicatorPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    
    let panelType: PanelIndicatorType
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    var timeframe: RLChartTimeframe = .h1
    
    @Binding var panelHeight: CGFloat
    let minPanelHeight: CGFloat
    let maxPanelHeight: CGFloat
    var isBottomPanel: Bool = false
    
    // MARK: - Private State
    
    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragTranslation: CGSize = .zero
    @State private var isCollapsed = false
    @State private var expandedPanelHeight: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }
    
    private var totalCandleWidth: CGFloat {
        actualCandleWidth + candleSpacing
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }
    
    private var panelTitle: String {
        switch panelType {
        case .cci: return indicatorManager.activeIndicators.cci?.label ?? "CCI"
        case .williamsR: return indicatorManager.activeIndicators.williamsR?.label ?? "%R"
        case .atr: return indicatorManager.activeIndicators.atr?.label ?? "ATR"
        case .volume: return indicatorManager.activeIndicators.volume?.label ?? "Volume"
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
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandleBar

            if !isCollapsed {
                // Panel content area with pan gesture
                panelContentArea
                    .frame(height: panelHeight)
                    .gesture(panGesture)

                // X-axis labels only if this is the bottom panel
                if isBottomPanel {
                    xAxisLabels
                }
            }
        }
        .background(AppColors.surfaceBlack85)
    }

    // MARK: - Pan Gesture
    
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if lastDragTranslation == .zero {
                    gestureState.beginDrag()
                }
                
                let incrementalX = value.translation.width - lastDragTranslation.width
                
                gestureState.applyPan(
                    translation: CGSize(width: incrementalX, height: 0),
                    chartWidth: UIScreen.main.bounds.width,
                    candleCount: chartData.candles.count,
                    candleWidth: totalCandleWidth,
                    chartHeight: panelHeight,
                    priceScale: 1.0,
                    trackVelocity: true
                )
                
                lastDragTranslation = value.translation
            }
            .onEnded { value in
                gestureState.endDrag(
                    chartWidth: UIScreen.main.bounds.width,
                    candleCount: chartData.candles.count,
                    candleWidth: totalCandleWidth,
                    chartHeight: panelHeight,
                    priceScale: 1.0
                )
                lastDragTranslation = .zero
            }
    }
    
    // MARK: - Resize Handle (matches RSIPanelView exactly)
    
    private var resizeHandleBar: some View {
        ZStack {
            Rectangle()
                .fill(AppColors.chartIndicatorHandleFill)

            HStack(spacing: 8) {
                Capsule()
                    .fill(isDraggingHandle ? AppColors.surfaceWhite80 : AppColors.surfaceGray50)
                    .frame(width: 36, height: 5)

                if isCollapsed {
                    Text(panelTitle)
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
    
    // MARK: - Panel Content Area
    
    private var panelContentArea: some View {
        // Force view update when gesture state changes
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        
        return ZStack {
            AppColors.surfaceBlack80
            
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
            
            // Panel header with label
            panelHeaderOverlay
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
        gestureState.crosshairActive ? AppColors.surfaceWhite40 : AppColors.statusInfo60
    }
    
    // MARK: - Y-Axis Labels Overlay
    
    private var yAxisLabelsOverlay: some View {
        GeometryReader { geometry in
            let yAxisValues = getYAxisValues()
            let range = getValueRange()
            
            ForEach(yAxisValues, id: \.self) { value in
                let y = yPosition(for: value, in: geometry.size.height, range: range)
                
                if y >= 0 && y <= geometry.size.height {
                    Text(formatValue(value))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.surfaceWhite76)
                        .position(x: geometry.size.width - 20, y: y)
                }
            }
        }
    }
    
    // MARK: - Current Value Indicator
    
    private var currentValueIndicator: some View {
        GeometryReader { geometry in
            if let currentValue = getCurrentValue() {
                let range = getValueRange()
                let y = yPosition(for: currentValue, in: geometry.size.height, range: range)
                
                if y >= 0 && y <= geometry.size.height {
                    // Dashed line to current value
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width - 40, y: y))
                    }
                    .stroke(lineColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    
                    // Current value label
                    Text(formatValue(currentValue))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(lineColor.opacity(0.8))
                        .cornerRadius(3)
                        .position(x: geometry.size.width - 20, y: y)
                }
            }
        }
    }
    
    // MARK: - Panel Header Overlay
    
    private var panelHeaderOverlay: some View {
        VStack {
            let headerState = panelHeaderState
            IndicatorPanelHeaderRow(
                title: panelTitle,
                valueText: headerState.valueText,
                valueColor: headerState.valueColor,
                badgeText: headerState.badgeText,
                badgeColor: headerState.badgeColor
            )
            Spacer()
        }
    }

    private var panelHeaderState: (valueText: String?, valueColor: Color, badgeText: String?, badgeColor: Color?) {
        switch panelType {
        case .cci:
            guard let latest = indicatorManager.latestCCI else {
                return (nil, AppColors.surfaceWhite90, nil, nil)
            }
            let condition = cciCondition(for: latest.value)
            return (
                formatValue(latest.value),
                condition.label.isEmpty ? AppColors.surfaceWhite90 : condition.color,
                condition.label.isEmpty ? nil : condition.label,
                condition.label.isEmpty ? nil : condition.color
            )
        case .volume:
            guard let latest = indicatorManager.volumeData.last else {
                return (nil, AppColors.surfaceWhite90, nil, nil)
            }
            let condition = latest.condition
            let badgeColor = condition == .bullish
                ? (volumeConfig?.bullishColor.color ?? .green)
                : (volumeConfig?.bearishColor.color ?? .red)
            return (
                formatValue(latest.volume),
                badgeColor,
                condition.label,
                badgeColor
            )
        default:
            guard let currentValue = getCurrentValue() else {
                return (nil, AppColors.surfaceWhite90, nil, nil)
            }
            return (formatValue(currentValue), lineColor, nil, nil)
        }
    }
    
    // MARK: - X-Axis Labels (matches RSIPanelView exactly)
    
    private var xAxisLabels: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = gestureState.crosshairX
        let _ = gestureState.markerPlacementGuide.isActive
        
        return ZStack {
            Canvas { context, size in
                drawXAxisLabels(context: context, size: size)
            }
            .frame(height: 24)
            .background(AppColors.systemBlack)
            
            if gestureState.crosshairActive, let timestamp = gestureState.crosshairTimestamp {
                crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: gestureState.crosshairX)
            } else if gestureState.markerPlacementGuide.isActive, let timestamp = gestureState.markerPlacementGuide.timestamp {
                crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: gestureState.markerPlacementGuide.x)
            }
        }
        .frame(height: 24)
    }
    
    @ViewBuilder
    private func crosshairTimeLabelOverlay(timestamp: Date, xPosition: CGFloat) -> some View {
        VStack(spacing: 1) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 6))
                .foregroundColor(.cyan)
            
            Text(formatCrosshairTime(timestamp))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.statusAccent90)
                )
        }
        .position(x: xPosition, y: 12)
    }
    
    private func formatCrosshairTime(_ date: Date) -> String {
        MarkerPlacementLabelFormatter.format(
            date,
            timeframe: timeframe,
            timeZone: chartData.currentSymbol?.exchangeTimeZone ?? .current
        )
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

        switch panelType {
        case .cci:
            drawCCI(context: context, size: size)
        case .williamsR:
            drawWilliamsR(context: context, size: size)
        case .atr:
            drawATR(context: context, size: size)
        case .volume:
            drawVolume(context: context, size: size)
        default:
            break
        }
    }
    
    // MARK: - CCI Drawing
    
    private func drawCCI(context: GraphicsContext, size: CGSize) {
        let data = indicatorManager.cciData
        guard !data.isEmpty else { return }
        
        let config = indicatorManager.activeIndicators.cci
        let overbought = config?.overboughtLevel ?? 100
        let oversold = config?.oversoldLevel ?? -100
        
        // Draw zones
        drawOscillatorZones(context: context, size: size, overbought: overbought, oversold: oversold, midLine: 0, minValue: -200, maxValue: 200)
        
        // Draw CCI line
        drawIndicatorLine(context: context, size: size, data: data.map { ($0.candleIndex, $0.value) }, minValue: -200, maxValue: 200, color: lineColor)
    }
    
    // MARK: - Williams %R Drawing
    
    private func drawWilliamsR(context: GraphicsContext, size: CGSize) {
        let data = indicatorManager.williamsRData
        guard !data.isEmpty else { return }
        
        let config = indicatorManager.activeIndicators.williamsR
        let overbought = config?.overboughtLevel ?? -20
        let oversold = config?.oversoldLevel ?? -80
        
        // Williams %R is 0 to -100, overbought at -20, oversold at -80
        drawOscillatorZones(context: context, size: size, overbought: overbought, oversold: oversold, midLine: -50, minValue: -100, maxValue: 0)
        
        // Draw Williams %R line
        drawIndicatorLine(context: context, size: size, data: data.map { ($0.candleIndex, $0.value) }, minValue: -100, maxValue: 0, color: lineColor)
    }
    
    // MARK: - ATR Drawing
    
    private func drawATR(context: GraphicsContext, size: CGSize) {
        let data = indicatorManager.atrData
        guard !data.isEmpty else { return }
        
        let maxATR = data.map { $0.value }.max() ?? 1
        let minATR: Double = 0
        
        // Draw horizontal grid lines
        let gridColor = AppColors.surfaceGray20
        for i in 1...3 {
            let y = size.height * CGFloat(i) / 4
            let gridPath = Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width - 50, y: y))
            }
            context.stroke(gridPath, with: .color(gridColor), lineWidth: 0.5)
        }
        
        // Draw ATR line
        drawIndicatorLine(context: context, size: size, data: data.map { ($0.candleIndex, $0.value) }, minValue: minATR, maxValue: maxATR * 1.1, color: lineColor)
    }
    
    // MARK: - Volume Drawing
    
    private func drawVolume(context: GraphicsContext, size: CGSize) {
        let data = indicatorManager.volumeData
        guard !data.isEmpty else { return }
        
        let config = indicatorManager.activeIndicators.volume
        let bullColor = config?.bullishColor.color ?? .green
        let bearColor = config?.bearishColor.color ?? .red
        
        let chartWidth = size.width - 50
        let startOffset = totalOffset
        
        let firstVisibleIndex = max(0, Int(-startOffset / totalCandleWidth) - 1)
        let visibleCandleCount = Int(chartWidth / totalCandleWidth) + 3
        let lastVisibleIndex = min(data.count - 1, firstVisibleIndex + visibleCandleCount)
        
        guard firstVisibleIndex <= lastVisibleIndex else { return }
        
        // Find max volume in visible range
        var maxVolume: Double = 0
        for i in firstVisibleIndex...lastVisibleIndex {
            if i < data.count {
                maxVolume = max(maxVolume, data[i].volume)
            }
        }
        
        guard maxVolume > 0 else { return }
        
        // Draw volume bars
        for i in firstVisibleIndex...lastVisibleIndex {
            guard i < data.count else { continue }
            let point = data[i]
            let x = CGFloat(point.candleIndex) * totalCandleWidth + startOffset
            
            guard x + actualCandleWidth >= 0 && x <= chartWidth else { continue }
            
            let barHeight = CGFloat(point.volume / maxVolume) * size.height * 0.9
            let barY = size.height - barHeight
            
            let barRect = CGRect(
                x: x + candleSpacing / 2,
                y: barY,
                width: actualCandleWidth,
                height: barHeight
            )
            
            let barColor = point.isBullish ? bullColor : bearColor
            context.fill(Path(barRect), with: .color(barColor.opacity(0.7)))
        }
        
        // Draw Volume MA if enabled
        if config?.showMA == true {
            var maPath = Path()
            var started = false
            
            for i in firstVisibleIndex...lastVisibleIndex {
                guard i < data.count, let ma = data[i].ma else { continue }
                let x = CGFloat(data[i].candleIndex) * totalCandleWidth + startOffset + totalCandleWidth / 2
                let y = size.height - CGFloat(ma / maxVolume) * size.height * 0.9
                
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
    
    private func drawOscillatorZones(context: GraphicsContext, size: CGSize, overbought: Double, oversold: Double, midLine: Double, minValue: Double, maxValue: Double) {
        let chartWidth = size.width - 50
        let range = maxValue - minValue
        
        // Overbought zone
        let obY = size.height * CGFloat((maxValue - overbought) / range)
        let obRect = CGRect(x: 0, y: 0, width: chartWidth, height: obY)
        context.fill(Path(obRect), with: .color(AppColors.statusNegative10))
        
        // Oversold zone
        let osY = size.height * CGFloat((maxValue - oversold) / range)
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
        
        // Middle line
        let midY = size.height * CGFloat((maxValue - midLine) / range)
        let midPath = Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: chartWidth, y: midY))
        }
        context.stroke(midPath, with: .color(AppColors.surfaceGray30), lineWidth: 0.5)
    }
    
    private func drawIndicatorLine(context: GraphicsContext, size: CGSize, data: [(candleIndex: Int, value: Double)], minValue: Double, maxValue: Double, color: Color) {
        guard !data.isEmpty else { return }
        
        let chartWidth = size.width - 50
        let startOffset = totalOffset
        let range = maxValue - minValue
        
        var path = Path()
        var started = false
        
        for point in data {
            let x = CGFloat(point.candleIndex) * totalCandleWidth + startOffset + totalCandleWidth / 2
            
            guard x >= -totalCandleWidth && x <= chartWidth + totalCandleWidth else { continue }
            
            let normalizedValue = (point.value - minValue) / range
            let y = size.height * CGFloat(1 - normalizedValue)
            
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
    
    private func getYAxisValues() -> [Double] {
        switch panelType {
        case .cci:
            return [-200, -100, 0, 100, 200]
        case .williamsR:
            return [-100, -80, -50, -20, 0]
        case .atr:
            if let maxATR = indicatorManager.atrData.map({ $0.value }).max() {
                let step = maxATR / 4
                return [0, step, step * 2, step * 3, maxATR]
            }
            return []
        case .volume:
            return []  // Volume doesn't show Y-axis values typically
        default:
            return []
        }
    }
    
    private func getValueRange() -> (min: Double, max: Double) {
        switch panelType {
        case .cci:
            return (-200, 200)
        case .williamsR:
            return (-100, 0)
        case .atr:
            let max = (indicatorManager.atrData.map { $0.value }.max() ?? 1) * 1.1
            return (0, max)
        case .volume:
            let max = (indicatorManager.volumeData.map { $0.volume }.max() ?? 1) * 1.1
            return (0, max)
        default:
            return (0, 100)
        }
    }
    
    private func yPosition(for value: Double, in height: CGFloat, range: (min: Double, max: Double)) -> CGFloat {
        let normalizedValue = (value - range.min) / (range.max - range.min)
        return height * CGFloat(1 - normalizedValue)
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
