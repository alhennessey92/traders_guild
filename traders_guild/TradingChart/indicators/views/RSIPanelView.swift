//
//  RSIPanelView.swift
//  traders_guild
//
//  UPDATED VERSION - Supports stacked panels with isBottomPanel parameter
//  When isBottomPanel=false, X-axis labels are hidden (shown only on bottom panel)
//

import SwiftUI

struct IndicatorPanelHeaderRow: View {
    let title: String
    let valueText: String?
    let valueColor: Color
    let badgeText: String?
    let badgeColor: Color?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.surfaceWhite80)

            if let valueText {
                Text(valueText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
            }

            if let badgeText, let badgeColor, !badgeText.isEmpty {
                Text(badgeText)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.8))
                    .cornerRadius(3)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

// MARK: - RSI Panel View

struct RSIPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var timeframe: RLChartTimeframe = .h1
    
    // Panel height state
    @Binding var panelHeight: CGFloat
    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 300
    
    /// NEW: Whether this is the bottom panel (shows X-axis labels)
    /// When stacking multiple panels, only the bottom one shows the X-axis
    var isBottomPanel: Bool = true
    
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
    
    private var rsiConfig: RSIConfig? {
        indicatorManager.activeIndicators.rsi
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }

    private var panelDisplayName: String {
        (rsiConfig?.label ?? "RSI 14") + " Indicator"
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandleBar

            if !isCollapsed {
                // RSI content area with pan gesture
                rsiContentArea
                    .frame(height: panelHeight)
                    .gesture(panGesture)

                // X-axis labels only if this is the bottom panel
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

            // Capsule always centered
            Capsule()
                .fill(isDraggingHandle ? AppColors.surfaceWhite80 : AppColors.surfaceGray50)
                .frame(width: 36, height: 5)

            // Panel label left-aligned
            HStack(spacing: 4) {
                (Text(rsiConfig?.label ?? "RSI 14")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                 + Text("  Indicator")
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
    
    // MARK: - RSI Content
    
    private var rsiContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        
        return ZStack {
            AppColors.chartPanelBackground
            
            Canvas { context, size in
                drawRSIPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            yAxisLabelsOverlay
            currentRSIIndicator
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
    
    // MARK: - Current RSI Indicator
    
    private var currentRSIIndicator: some View {
        GeometryReader { geometry in
            if let latestRSI = indicatorManager.latestRSI {
                let rsiValue = latestRSI.value
                let normalizedRSI = rsiValue / 100.0
                let y = geometry.size.height * (1 - normalizedRSI)
                
                if y >= 0 && y <= geometry.size.height && !rsiValue.isNaN {
                    Canvas { context, size in
                        let lineEndX = size.width - 30
                        
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
                        
                        let labelX = size.width - 15
                        let labelRect = CGRect(x: labelX - 20, y: y - 9, width: 40, height: 18)
                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
                        context.fill(roundedPath, with: .color(lineColor))
                        
                        let text = Text(String(format: "%.1f", rsiValue))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        context.draw(text, at: CGPoint(x: labelX, y: y))
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
    
    // MARK: - Panel Header
    
    private var panelHeaderOverlay: some View {
        VStack {
            if let latest = indicatorManager.latestRSI {
                let condition = rsiCondition(for: latest.value)
                IndicatorPanelHeaderRow(
                    title: "",
                    valueText: String(format: "%.1f", latest.value),
                    valueColor: condition.label.isEmpty ? AppColors.surfaceWhite90 : condition.color,
                    badgeText: condition.label.isEmpty ? nil : condition.label,
                    badgeColor: condition.label.isEmpty ? nil : condition.color
                )
            }

            Spacer()
        }
    }
    
    // MARK: - Y-Axis Labels
    
    private var yAxisLabelsOverlay: some View {
        HStack {
            Spacer()
            
            VStack {
                Text(String(format: "%.0f", rsiConfig?.overboughtLevel ?? 70))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.statusNegative85)
                
                Spacer()
                
                Text("50")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.surfaceWhite66)
                
                Spacer()
                
                Text(String(format: "%.0f", rsiConfig?.oversoldLevel ?? 30))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.statusPositive85)
            }
            .frame(width: 28)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .padding(.trailing, 5)
            .background(AppColors.surfaceBlack62)
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

        let drawableHeight = size.height - 20
        let topPadding: CGFloat = 18

        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
    }
    
    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        guard config.showLevels else { return }
        
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 30
        
        let overboughtZone = Path { p in
            p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY))
        }
        context.fill(overboughtZone, with: .color(AppColors.statusNegative08))
        
        let oversoldZone = Path { p in
            p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY))
        }
        context.fill(oversoldZone, with: .color(AppColors.statusPositive08))
    }
    
    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 30
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: overboughtY))
        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
        context.stroke(path, with: .color(AppColors.statusNegative40), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        
        path = Path()
        path.move(to: CGPoint(x: 0, y: middleY))
        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
        context.stroke(path, with: .color(AppColors.surfaceGray30), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        
        path = Path()
        path.move(to: CGPoint(x: 0, y: oversoldY))
        path.addLine(to: CGPoint(x: lineEndX, y: oversoldY))
        context.stroke(path, with: .color(AppColors.statusPositive40), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
    }
    
    private func drawRSILine(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
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
            let y = yPosition(for: point.value, height: drawableHeight, topPadding: topPadding)
            
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
    
    private func yPosition(for rsiValue: Double, height: CGFloat, topPadding: CGFloat) -> CGFloat {
        let normalized = rsiValue / 100.0
        return topPadding + height * (1.0 - CGFloat(normalized))
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
