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
    
    // MARK: - Static Formatters (matches RSIPanelView)
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f
    }()
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
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
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandleBar
            
            // Panel content area with pan gesture
            panelContentArea
                .frame(height: panelHeight)
                .gesture(panGesture)
            
            // X-axis labels only if this is the bottom panel
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
    
    // MARK: - Resize Handle (matches RSIPanelView exactly)
    
    private var resizeHandleBar: some View {
        ZStack {
            Rectangle()
                .fill(Color(white: 0.08))
            
            VStack(spacing: 3) {
                Capsule()
                    .fill(isDraggingHandle ? Color.white.opacity(0.8) : Color.gray.opacity(0.5))
                    .frame(width: 36, height: 5)
            }
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
    
    // MARK: - Panel Content Area
    
    private var panelContentArea: some View {
        // Force view update when gesture state changes
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        
        return ZStack {
            Color.black.opacity(0.95)
            
            Canvas { context, size in
                drawPanel(context: context, size: size)
            }
            
            // Crosshair line overlay
            if gestureState.crosshairActive {
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
                path.move(to: CGPoint(x: gestureState.crosshairX, y: 0))
                path.addLine(to: CGPoint(x: gestureState.crosshairX, y: geometry.size.height))
            }
            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
        }
        .allowsHitTesting(false)
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
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
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
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
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
            HStack {
                Text(panelTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                Spacer()
            }
            .padding(.leading, 8)
            .padding(.top, 4)
            Spacer()
        }
    }
    
    // MARK: - X-Axis Labels (matches RSIPanelView exactly)
    
    private var xAxisLabels: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        let _ = gestureState.crosshairX
        
        return ZStack {
            Canvas { context, size in
                drawXAxisLabels(context: context, size: size)
            }
            .frame(height: 22)
            .background(Color.black)
            
            if gestureState.crosshairActive, let timestamp = gestureState.crosshairTimestamp {
                crosshairTimeLabelOverlay(timestamp: timestamp)
            }
        }
        .frame(height: 22)
    }
    
    @ViewBuilder
    private func crosshairTimeLabelOverlay(timestamp: Date) -> some View {
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
        .position(x: gestureState.crosshairX, y: 11)
    }
    
    private func formatCrosshairTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeframe {
        case .d1, .w1, .mn:
            formatter.dateFormat = "dd MMM yyyy"
        default:
            formatter.dateFormat = "dd MMM HH:mm"
        }
        return formatter.string(from: date)
    }
    
    private func drawXAxisLabels(context: GraphicsContext, size: CGSize) {
        guard chartData.candles.count >= 2 else { return }
        
        let firstCandle = chartData.candles.first!
        let lastCandle = chartData.candles.last!
        let timePerCandle = chartData.candles[1].timestamp.timeIntervalSince(chartData.candles[0].timestamp)
        guard timePerCandle > 0 else { return }
        
        let niceTimeStep = getNiceTimeStep(timeframe: timeframe, zoomScale: gestureState.candleWidthScale)
        
        let calendar = Calendar.current
        let startTime = firstCandle.timestamp.timeIntervalSince1970
        let alignedStart = floor(startTime / niceTimeStep) * niceTimeStep
        
        var currentTime = alignedStart
        let endTime = lastCandle.timestamp.timeIntervalSince1970 + timePerCandle * 10
        
        var lastDrawnX: CGFloat = -200
        let minSpacing: CGFloat = 30
        
        while currentTime <= endTime {
            let candleIndex = (currentTime - startTime) / timePerCandle
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
            
            if x >= -50 && x <= size.width + 50 && (x - lastDrawnX) >= minSpacing {
                let date = Date(timeIntervalSince1970: currentTime)
                let components = calendar.dateComponents([.hour, .minute], from: date)
                let hour = components.hour ?? 0
                let minute = components.minute ?? 0
                let isMidnight = hour == 0 && minute == 0
                
                if isMidnight {
                    let text = Self.dateFormatter.string(from: date)
                    context.draw(
                        Text(text)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white),
                        at: CGPoint(x: x, y: 10)
                    )
                } else {
                    let text = Self.timeFormatter.string(from: date)
                    context.draw(
                        Text(text)
                            .font(.system(size: 9))
                            .foregroundColor(.gray),
                        at: CGPoint(x: x, y: 10)
                    )
                }
                lastDrawnX = x
            }
            
            currentTime += niceTimeStep
        }
    }
    
    private func getNiceTimeStep(timeframe: RLChartTimeframe, zoomScale: CGFloat) -> Double {
        let screenWidth: CGFloat = UIScreen.main.bounds.width
        let visibleCandles = screenWidth / totalCandleWidth
        
        let secondsPerCandle: Double
        switch timeframe {
        case .m1: secondsPerCandle = 60
        case .m5: secondsPerCandle = 300
        case .m15: secondsPerCandle = 900
        case .m30: secondsPerCandle = 1800
        case .h1: secondsPerCandle = 3600
        case .h4: secondsPerCandle = 14400
        case .d1: secondsPerCandle = 86400
        case .w1: secondsPerCandle = 604800
        case .mn: secondsPerCandle = 2592000
        }
        
        let visibleTimeSpan = Double(visibleCandles) * secondsPerCandle
        let targetLabels: Double = 5.0
        let roughStep = visibleTimeSpan / targetLabels
        
        return roundToNiceTimeInterval(roughStep)
    }
    
    private func roundToNiceTimeInterval(_ roughStep: Double) -> Double {
        let niceIntervals: [Double] = [
            60, 120, 300, 600, 900, 1800,
            3600, 7200, 14400, 21600, 28800, 43200,
            86400, 172800, 259200, 432000,
            604800, 1209600, 2592000, 5184000
        ]
        
        for interval in niceIntervals {
            if interval >= roughStep * 0.7 {
                return interval
            }
        }
        
        return niceIntervals.last!
    }
    
    // MARK: - Drawing
    
    private func drawPanel(context: GraphicsContext, size: CGSize) {
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
        let gridColor = Color.gray.opacity(0.2)
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
        context.fill(Path(obRect), with: .color(Color.red.opacity(0.1)))
        
        // Oversold zone
        let osY = size.height * CGFloat((maxValue - oversold) / range)
        let osRect = CGRect(x: 0, y: osY, width: chartWidth, height: size.height - osY)
        context.fill(Path(osRect), with: .color(Color.green.opacity(0.1)))
        
        // Overbought line
        let obPath = Path { path in
            path.move(to: CGPoint(x: 0, y: obY))
            path.addLine(to: CGPoint(x: chartWidth, y: obY))
        }
        context.stroke(obPath, with: .color(Color.red.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        // Oversold line
        let osPath = Path { path in
            path.move(to: CGPoint(x: 0, y: osY))
            path.addLine(to: CGPoint(x: chartWidth, y: osY))
        }
        context.stroke(osPath, with: .color(Color.green.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        // Middle line
        let midY = size.height * CGFloat((maxValue - midLine) / range)
        let midPath = Path { path in
            path.move(to: CGPoint(x: 0, y: midY))
            path.addLine(to: CGPoint(x: chartWidth, y: midY))
        }
        context.stroke(midPath, with: .color(Color.gray.opacity(0.3)), lineWidth: 0.5)
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
