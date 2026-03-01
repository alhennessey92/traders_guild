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
    
    // MARK: - Computed Properties
    
    private var totalCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
    }
    
    private var actualCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale
    }
    
    private var stochConfig: StochasticConfig? {
        indicatorManager.activeIndicators.stochastic
    }
    
    private var totalOffset: CGFloat {
        gestureState.panOffset.width
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            resizeHandleBar
            
            stochasticContentArea
                .frame(height: panelHeight)
                .gesture(panGesture)
            
            if isBottomPanel {
                xAxisLabels
            }
        }
        .background(Color.black)
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
                .fill(Color(white: 0.08))
            
            Capsule()
                .fill(isDraggingHandle ? Color.white.opacity(0.8) : Color.gray.opacity(0.5))
                .frame(width: 36, height: 5)
        }
        .frame(height: 22)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if !isDraggingHandle {
                        isDraggingHandle = true
                        dragStartHeight = panelHeight
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    let delta = -value.translation.height
                    let newHeight = dragStartHeight + delta
                    panelHeight = min(maxPanelHeight, max(minPanelHeight, newHeight))
                }
                .onEnded { _ in
                    isDraggingHandle = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        )
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Stochastic Content
    
    private var stochasticContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        
        return ZStack {
            Color.black.opacity(0.95)
            
            Canvas { context, size in
                drawStochasticPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive || gestureState.markerPlacementGuide.isActive {
                crosshairLine
            }
            
            yAxisLabelsOverlay
            currentStochIndicator
            panelHeaderOverlay
        }
        .clipped()
    }
    
    // MARK: - Canvas Drawing
    
    private func drawStochasticPanel(context: GraphicsContext, size: CGSize) {
        guard let config = stochConfig else { return }
        
        let drawableHeight = size.height - 20
        let topPadding: CGFloat = 18
        
        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        drawDLine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        drawKLine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
    }
    
    private func drawZones(context: GraphicsContext, size: CGSize, config: StochasticConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        guard config.showLevels else { return }
        
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 45
        
        let overboughtZone = Path { p in
            p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY))
        }
        context.fill(overboughtZone, with: .color(config.overboughtColor.color))
        
        let oversoldZone = Path { p in
            p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY))
        }
        context.fill(oversoldZone, with: .color(config.oversoldColor.color))
    }
    
    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: StochasticConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 45
        
        var path = Path()
        path.move(to: CGPoint(x: 0, y: overboughtY))
        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        
        path = Path()
        path.move(to: CGPoint(x: 0, y: middleY))
        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        
        path = Path()
        path.move(to: CGPoint(x: 0, y: oversoldY))
        path.addLine(to: CGPoint(x: lineEndX, y: oversoldY))
        context.stroke(path, with: .color(.green.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
    }
    
    private func drawKLine(context: GraphicsContext, size: CGSize, config: StochasticConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
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
            let y = yPosition(for: point.kValue, height: drawableHeight, topPadding: topPadding)
            
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
    
    private func drawDLine(context: GraphicsContext, size: CGSize, config: StochasticConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
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
            let y = yPosition(for: point.dValue, height: drawableHeight, topPadding: topPadding)
            
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
    
    private func yPosition(for stochValue: Double, height: CGFloat, topPadding: CGFloat) -> CGFloat {
        let normalized = stochValue / 100.0
        return topPadding + height * (1.0 - CGFloat(normalized))
    }
    
    // MARK: - Current Value Indicator
    
    private var currentStochIndicator: some View {
        GeometryReader { geometry in
            if let latestStoch = indicatorManager.latestStochastic {
                let kValue = latestStoch.kValue
                let drawableHeight = geometry.size.height - 20
                let topPadding: CGFloat = 18
                let y = yPosition(for: kValue, height: drawableHeight, topPadding: topPadding)
                
                if y >= 0 && y <= geometry.size.height && !kValue.isNaN {
                    Canvas { context, size in
                        let lineEndX = size.width - 45
                        
                        let linePath = Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: lineEndX, y: y))
                        }
                        
                        let lineColor = stochIndicatorColor(for: kValue)
                        context.stroke(linePath, with: .color(lineColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        
                        let labelX = size.width - 22
                        let labelRect = CGRect(x: labelX - 20, y: y - 9, width: 40, height: 18)
                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
                        context.fill(roundedPath, with: .color(lineColor))
                        
                        let text = Text(String(format: "%.1f", kValue))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        context.draw(text, at: CGPoint(x: labelX, y: y))
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
        gestureState.crosshairActive ? Color.white.opacity(0.4) : Color.blue.opacity(0.6)
    }
    
    // MARK: - Y-Axis Labels
    
    private var yAxisLabelsOverlay: some View {
        HStack {
            Spacer()
            
            VStack {
                Text(String(format: "%.0f", stochConfig?.overboughtLevel ?? 80))
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.7))
                
                Spacer()
                
                Text("50")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.7))
                
                Spacer()
                
                Text(String(format: "%.0f", stochConfig?.oversoldLevel ?? 20))
                    .font(.system(size: 9))
                    .foregroundColor(.green.opacity(0.7))
            }
            .frame(width: 25)
            .padding(.top, 18)
            .padding(.bottom, 4)
            .padding(.trailing, 4)
            .background(Color.black.opacity(0.6))
        }
    }
    
    // MARK: - Header
    
    private var panelHeaderOverlay: some View {
        VStack {
            HStack(spacing: 6) {
                Text(stochConfig?.shortLabel ?? "Stochastic")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                if let latest = indicatorManager.latestStochastic {
                    Text("%K:")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f", latest.kValue))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(stochConfig?.color.color ?? .yellow)
                    
                    Text("%D:")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f", latest.dValue))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(stochConfig?.dColor.color ?? .red)
                    
                    stochConditionBadge(value: latest.kValue)
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func stochConditionBadge(value: Double) -> some View {
        let overbought = stochConfig?.overboughtLevel ?? 80
        let oversold = stochConfig?.oversoldLevel ?? 20
        
        if value >= overbought {
            Text("OVERBOUGHT")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.8))
                .cornerRadius(3)
        } else if value <= oversold {
            Text("OVERSOLD")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.8))
                .cornerRadius(3)
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
            .frame(height: 22)
            .background(Color.black)
            
            if gestureState.crosshairActive, let timestamp = gestureState.crosshairTimestamp {
                crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: gestureState.crosshairX)
            } else if gestureState.markerPlacementGuide.isActive, let timestamp = gestureState.markerPlacementGuide.timestamp {
                crosshairTimeLabelOverlay(timestamp: timestamp, xPosition: gestureState.markerPlacementGuide.x)
            }
        }
        .frame(height: 22)
    }
    
    @ViewBuilder
    private func crosshairTimeLabelOverlay(timestamp: Date, xPosition: CGFloat) -> some View {
        VStack(spacing: 1) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 5))
                .foregroundColor(.cyan)
            
            Text(formatCrosshairTime(timestamp))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.cyan.opacity(0.9))
                )
        }
        .position(x: xPosition, y: 11)
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
}

