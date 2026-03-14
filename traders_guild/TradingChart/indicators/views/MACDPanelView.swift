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
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var timeframe: RLChartTimeframe = .h1
    
    @Binding var panelHeight: CGFloat
    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 250
    var isBottomPanel: Bool = false
    
    // MARK: - Private State
    
    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragTranslation: CGSize = .zero
    @State private var isCollapsed = false
    @State private var expandedPanelHeight: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var totalCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
    }
    
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }
    
    private var macdConfig: MACDConfig? {
        indicatorManager.activeIndicators.macd
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            resizeHandleBar

            if !isCollapsed {
                macdContentArea
                    .frame(height: panelHeight)
                    .gesture(panGesture)

                if isBottomPanel {
                    xAxisLabels
                }
            }
        }
        .background(AppColors.chartPanelBackgroundMuted)
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
                    Text("MACD")
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
    
    // MARK: - MACD Content
    
    private var macdContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        
        return ZStack {
            AppColors.chartPanelBackground
            
            Canvas { context, size in
                drawMACDPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            yAxisLabelsOverlay
            currentMACDIndicator
            panelHeaderOverlay
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

        let drawableHeight = size.height - 20
        let topPadding: CGFloat = 18
        let dataRange = macdDataRange
        guard dataRange.max > dataRange.min else { return }

        // Draw zero line
        drawZeroLine(context: context, size: size, dataRange: dataRange, drawableHeight: drawableHeight, topPadding: topPadding)
        
        // Draw histogram
        if config.showHistogram {
            drawHistogram(context: context, size: size, config: config, dataRange: dataRange, drawableHeight: drawableHeight, topPadding: topPadding)
        }
        
        // Draw signal line (behind MACD)
        if config.showSignalLine {
            drawSignalLine(context: context, size: size, config: config, dataRange: dataRange, drawableHeight: drawableHeight, topPadding: topPadding)
        }
        
        // Draw MACD line (on top)
        drawMACDLine(context: context, size: size, config: config, dataRange: dataRange, drawableHeight: drawableHeight, topPadding: topPadding)
    }
    
    private var macdDataRange: (min: Double, max: Double) {
        let dataPoints = indicatorManager.macdData
        guard !dataPoints.isEmpty else { return (-1, 1) }
        
        var minVal = Double.infinity
        var maxVal = -Double.infinity
        
        for point in dataPoints {
            minVal = min(minVal, point.macdLine, point.signalLine, point.histogram)
            maxVal = max(maxVal, point.macdLine, point.signalLine, point.histogram)
        }
        
        // Make symmetric around zero
        let absMax = max(abs(minVal), abs(maxVal))
        let padding = absMax * 0.1
        
        return (-absMax - padding, absMax + padding)
    }
    
    private func drawZeroLine(context: GraphicsContext, size: CGSize, dataRange: (min: Double, max: Double), drawableHeight: CGFloat, topPadding: CGFloat) {
        let zeroY = yPosition(for: 0, dataRange: dataRange, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 45
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: zeroY))
        path.addLine(to: CGPoint(x: lineEndX, y: zeroY))
        
        context.stroke(path, with: .color(AppColors.surfaceGray50), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
    }
    
    private func drawHistogram(context: GraphicsContext, size: CGSize, config: MACDConfig, dataRange: (min: Double, max: Double), drawableHeight: CGFloat, topPadding: CGFloat) {
        let dataPoints = indicatorManager.macdData
        guard !dataPoints.isEmpty else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        
        let zeroY = yPosition(for: 0, dataRange: dataRange, height: drawableHeight, topPadding: topPadding)
        let barWidth = actualCandleWidth * 0.6
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = yPosition(for: point.histogram, dataRange: dataRange, height: drawableHeight, topPadding: topPadding)
            
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
    
    private func drawMACDLine(context: GraphicsContext, size: CGSize, config: MACDConfig, dataRange: (min: Double, max: Double), drawableHeight: CGFloat, topPadding: CGFloat) {
        let dataPoints = indicatorManager.macdData
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = yPosition(for: point.macdLine, dataRange: dataRange, height: drawableHeight, topPadding: topPadding)
            
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
    
    private func drawSignalLine(context: GraphicsContext, size: CGSize, config: MACDConfig, dataRange: (min: Double, max: Double), drawableHeight: CGFloat, topPadding: CGFloat) {
        let dataPoints = indicatorManager.macdData
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirst = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex)
            let y = yPosition(for: point.signalLine, dataRange: dataRange, height: drawableHeight, topPadding: topPadding)
            
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
    
    private func yPosition(for value: Double, dataRange: (min: Double, max: Double), height: CGFloat, topPadding: CGFloat) -> CGFloat {
        let range = dataRange.max - dataRange.min
        guard range > 0 else { return topPadding + height / 2 }
        let normalized = (value - dataRange.min) / range
        return topPadding + height * (1.0 - CGFloat(normalized))
    }
    
    // MARK: - Current Value Indicator
    
    private var currentMACDIndicator: some View {
        GeometryReader { geometry in
            if let latestMACD = indicatorManager.latestMACD {
                let dataRange = macdDataRange
                let drawableHeight = geometry.size.height - 20
                let topPadding: CGFloat = 18
                let y = yPosition(for: latestMACD.macdLine, dataRange: dataRange, height: drawableHeight, topPadding: topPadding)
                
                if y >= 0 && y <= geometry.size.height {
                    Canvas { context, size in
                        let lineEndX = size.width - 45
                        
                        let linePath = Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: lineEndX, y: y))
                        }
                        
                        let lineColor = latestMACD.macdLine >= 0 ? AppColors.statusPositive : AppColors.statusNegative
                        context.stroke(linePath, with: .color(lineColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        
                        // Price label
                        let labelX = size.width - 22
                        let labelRect = CGRect(x: labelX - 25, y: y - 9, width: 50, height: 18)
                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
                        context.fill(roundedPath, with: .color(lineColor))
                        
                        let text = Text(formatMACDValue(latestMACD.macdLine))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        context.draw(text, at: CGPoint(x: labelX, y: y))
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
        gestureState.crosshairActive ? AppColors.surfaceWhite40 : AppColors.statusInfo60
    }
    
    // MARK: - Y-Axis Labels
    
    private var yAxisLabelsOverlay: some View {
        let dataRange = macdDataRange
        
        return HStack {
            Spacer()
            
            VStack {
                Text(formatMACDValue(dataRange.max * 0.7))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite78)
                
                Spacer()
                
                Text("0")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite66)
                
                Spacer()
                
                Text(formatMACDValue(dataRange.min * 0.7))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite78)
            }
            .frame(width: 42)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .padding(.trailing, 5)
            .background(AppColors.surfaceBlack62)
        }
    }
    
    // MARK: - Header
    
    private var panelHeaderOverlay: some View {
        VStack {
            HStack(spacing: 6) {
                Text(macdConfig?.shortLabel ?? "MACD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.surfaceWhite80)
                
                if let latest = indicatorManager.latestMACD {
                    Circle()
                        .fill(macdConfig?.color.color ?? .cyan)
                        .frame(width: 6, height: 6)
                    Text(formatMACDValue(latest.macdLine))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(macdConfig?.color.color ?? .cyan)
                    
                    Circle()
                        .fill(macdConfig?.signalColor.color ?? .orange)
                        .frame(width: 6, height: 6)
                    Text(formatMACDValue(latest.signalLine))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(macdConfig?.signalColor.color ?? .orange)
                    
                    Text("H:")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Text(formatMACDValue(latest.histogram))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(latest.isHistogramPositive ? .green : .red)
                    
                    if latest.crossoverType != .neutral {
                        macdConditionBadge(crossover: latest.crossoverType)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func macdConditionBadge(crossover: MACDCrossover) -> some View {
        Text(crossover.label)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(crossover.color.opacity(0.8))
            .cornerRadius(3)
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
    
    // MARK: - X-Axis Labels
    
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
        if xPosition.isFinite {
            CrosshairTimeLabel(
                timestamp: timestamp,
                timeframe: timeframe,
                timeZone: chartData.currentSymbol?.exchangeTimeZone ?? .current
            )
            .position(x: xPosition, y: CrosshairTimeLabel.indicatorHeight * 0.5)
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
