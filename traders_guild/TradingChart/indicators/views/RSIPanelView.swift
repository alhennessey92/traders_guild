//
//  RSIPanelView.swift
//  traders_guild
//
//  UPDATED VERSION - Supports stacked panels with isBottomPanel parameter
//  When isBottomPanel=false, X-axis labels are hidden (shown only on bottom panel)
//

import SwiftUI

// MARK: - RSI Panel View

struct RSIPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var timeframe: ChartTimeframe = .h1
    
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
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandleBar
            
            // RSI content area with pan gesture
            rsiContentArea
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
    
    // MARK: - Resize Handle
    
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
    
    // MARK: - RSI Content
    
    private var rsiContentArea: some View {
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        let _ = gestureState.crosshairActive
        
        return ZStack {
            Color.black.opacity(0.95)
            
            Canvas { context, size in
                drawRSIPanel(context: context, size: size)
            }
            
            if gestureState.crosshairActive {
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
                path.move(to: CGPoint(x: gestureState.crosshairX, y: 0))
                path.addLine(to: CGPoint(x: gestureState.crosshairX, y: geometry.size.height))
            }
            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
        }
        .allowsHitTesting(false)
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
            HStack(spacing: 6) {
                Text(rsiConfig?.label ?? "RSI 14")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                if let latest = indicatorManager.latestRSI {
                    Text(String(format: "%.1f", latest.value))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(rsiValueColor(latest.value))
                    
                    rsiConditionBadge(value: latest.value)
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func rsiConditionBadge(value: Double) -> some View {
        let overbought = rsiConfig?.overboughtLevel ?? 70
        let oversold = rsiConfig?.oversoldLevel ?? 30
        
        if value >= overbought {
            badgeView(text: "OVERBOUGHT", color: .red)
        } else if value <= oversold {
            badgeView(text: "OVERSOLD", color: .green)
        }
    }
    
    private func badgeView(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.8))
            .cornerRadius(3)
    }
    
    // MARK: - Y-Axis Labels
    
    private var yAxisLabelsOverlay: some View {
        HStack {
            Spacer()
            
            VStack {
                Text(String(format: "%.0f", rsiConfig?.overboughtLevel ?? 70))
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.7))
                
                Spacer()
                
                Text("50")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.7))
                
                Spacer()
                
                Text(String(format: "%.0f", rsiConfig?.oversoldLevel ?? 30))
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
    
    // MARK: - Canvas Drawing
    
    private func drawRSIPanel(context: GraphicsContext, size: CGSize) {
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
        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
        
        let oversoldZone = Path { p in
            p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY))
        }
        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
    }
    
    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 30
        
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
        let overbought = rsiConfig?.overboughtLevel ?? 70
        let oversold = rsiConfig?.oversoldLevel ?? 30
        if value >= overbought { return .red }
        if value <= oversold { return .green }
        return .white.opacity(0.9)
    }
    
    // MARK: - X-Axis Labels
    
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
    
    private func getNiceTimeStep(timeframe: ChartTimeframe, zoomScale: CGFloat) -> Double {
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
}






////
////  RSIPanelView.swift
////  traders_guild
////
////  UPDATED VERSION - Supports stacked panels with isBottomPanel parameter
////  When isBottomPanel=false, X-axis labels are hidden (shown only on bottom panel)
////
//
//import SwiftUI
//
//// MARK: - RSI Panel View
//
//struct RSIPanelView: View {
//    
//    // MARK: - Properties
//    
//    @ObservedObject var indicatorManager: IndicatorManager
//    @ObservedObject var chartData: ChartDataManager
//    @ObservedObject var gestureState: ChartGestureState
//    let baseCandleWidth: CGFloat
//    let candleSpacing: CGFloat
//    
//    var timeframe: ChartTimeframe = .h1
//    
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 300
//    
//    /// NEW: Whether this is the bottom panel (shows X-axis labels)
//    /// When stacking multiple panels, only the bottom one shows the X-axis
//    var isBottomPanel: Bool = true
//    
//    // MARK: - Private State
//    
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//    @State private var lastDragTranslation: CGSize = .zero
//    
//    // MARK: - Computed Properties
//    
//    private var totalCandleWidth: CGFloat {
//        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
//    }
//    
//    private var actualCandleWidth: CGFloat {
//        baseCandleWidth * gestureState.candleWidthScale
//    }
//    
//    private var rsiConfig: RSIConfig? {
//        indicatorManager.activeIndicators.rsi
//    }
//    
//    private var totalOffset: CGFloat {
//        gestureState.panOffset.width
//    }
//    
//    // MARK: - Body
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Resize handle
//            resizeHandleBar
//            
//            // RSI content area with pan gesture
//            rsiContentArea
//                .frame(height: panelHeight)
//                .gesture(panGesture)
//            
//            // X-axis labels only if this is the bottom panel
//            if isBottomPanel {
//                xAxisLabels
//            }
//        }
//        .background(Color.black)
//    }
//    
//    // MARK: - Pan Gesture
//    
//    private var panGesture: some Gesture {
//        DragGesture(minimumDistance: 10)
//            .onChanged { value in
//                if lastDragTranslation == .zero {
//                    gestureState.beginDrag()
//                }
//                
//                let incrementalX = value.translation.width - lastDragTranslation.width
//                
//                gestureState.applyPan(
//                    translation: CGSize(width: incrementalX, height: 0),
//                    chartWidth: UIScreen.main.bounds.width,
//                    candleCount: chartData.candles.count,
//                    candleWidth: totalCandleWidth,
//                    chartHeight: panelHeight,
//                    priceScale: 1.0,
//                    trackVelocity: true
//                )
//                
//                lastDragTranslation = value.translation
//            }
//            .onEnded { value in
//                gestureState.endDrag(
//                    chartWidth: UIScreen.main.bounds.width,
//                    candleCount: chartData.candles.count,
//                    candleWidth: totalCandleWidth,
//                    chartHeight: panelHeight,
//                    priceScale: 1.0
//                )
//                lastDragTranslation = .zero
//            }
//    }
//    
//    // MARK: - Resize Handle
//    
//    private var resizeHandleBar: some View {
//        ZStack {
//            Rectangle()
//                .fill(Color(white: 0.08))
//            
//            VStack(spacing: 3) {
//                Capsule()
//                    .fill(isDraggingHandle ? Color.white.opacity(0.8) : Color.gray.opacity(0.5))
//                    .frame(width: 36, height: 5)
//            }
//        }
//        .frame(height: 22)
//        .contentShape(Rectangle())
//        .gesture(
//            DragGesture(minimumDistance: 0, coordinateSpace: .global)
//                .onChanged { value in
//                    if !isDraggingHandle {
//                        isDraggingHandle = true
//                        dragStartHeight = panelHeight
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                    }
//                    let delta = -value.translation.height
//                    let newHeight = dragStartHeight + delta
//                    panelHeight = min(maxPanelHeight, max(minPanelHeight, newHeight))
//                }
//                .onEnded { _ in
//                    isDraggingHandle = false
//                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                }
//        )
//        .overlay(
//            Rectangle()
//                .fill(Color.gray.opacity(0.3))
//                .frame(height: 1),
//            alignment: .bottom
//        )
//    }
//    
//    // MARK: - RSI Content
//    
//    private var rsiContentArea: some View {
//        let _ = gestureState.panOffset.width
//        let _ = gestureState.candleWidthScale
//        let _ = gestureState.crosshairActive
//        
//        return ZStack {
//            Color.black.opacity(0.95)
//            
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//            
//            if gestureState.crosshairActive {
//                crosshairLine
//            }
//            
//            yAxisLabelsOverlay
//            currentRSIIndicator
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//    
//    // MARK: - Crosshair Line
//    
//    private var crosshairLine: some View {
//        GeometryReader { geometry in
//            Path { path in
//                path.move(to: CGPoint(x: gestureState.crosshairX, y: 0))
//                path.addLine(to: CGPoint(x: gestureState.crosshairX, y: geometry.size.height))
//            }
//            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
//        }
//        .allowsHitTesting(false)
//    }
//    
//    // MARK: - Current RSI Indicator
//    
//    private var currentRSIIndicator: some View {
//        GeometryReader { geometry in
//            if let latestRSI = indicatorManager.latestRSI {
//                let rsiValue = latestRSI.value
//                let normalizedRSI = rsiValue / 100.0
//                let y = geometry.size.height * (1 - normalizedRSI)
//                
//                if y >= 0 && y <= geometry.size.height && !rsiValue.isNaN {
//                    Canvas { context, size in
//                        let lineEndX = size.width - 30
//                        
//                        let linePath = Path { path in
//                            path.move(to: CGPoint(x: 0, y: y))
//                            path.addLine(to: CGPoint(x: lineEndX, y: y))
//                        }
//                        
//                        let lineColor = rsiIndicatorColor(for: rsiValue)
//                        context.stroke(
//                            linePath,
//                            with: .color(lineColor.opacity(0.8)),
//                            style: StrokeStyle(lineWidth: 1, dash: [5, 3])
//                        )
//                        
//                        let labelX = size.width - 15
//                        let labelRect = CGRect(x: labelX - 20, y: y - 9, width: 40, height: 18)
//                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: 3)
//                        context.fill(roundedPath, with: .color(lineColor))
//                        
//                        let text = Text(String(format: "%.1f", rsiValue))
//                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
//                            .foregroundColor(.white)
//                        
//                        context.draw(text, at: CGPoint(x: labelX, y: y))
//                    }
//                }
//            }
//        }
//        .allowsHitTesting(false)
//    }
//    
//    private func rsiIndicatorColor(for value: Double) -> Color {
//        let overbought = rsiConfig?.overboughtLevel ?? 70
//        let oversold = rsiConfig?.oversoldLevel ?? 30
//        
//        if value >= overbought {
//            return .red
//        } else if value <= oversold {
//            return .green
//        } else {
//            return .purple
//        }
//    }
//    
//    // MARK: - Panel Header
//    
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//                
//                if let latest = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latest.value))
//                        .font(.system(size: 10, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latest.value))
//                    
//                    rsiConditionBadge(value: latest.value)
//                }
//                
//                Spacer()
//            }
//            .padding(.horizontal, 8)
//            .padding(.top, 4)
//            
//            Spacer()
//        }
//    }
//    
//    @ViewBuilder
//    private func rsiConditionBadge(value: Double) -> some View {
//        let overbought = rsiConfig?.overboughtLevel ?? 70
//        let oversold = rsiConfig?.oversoldLevel ?? 30
//        
//        if value >= overbought {
//            badgeView(text: "OVERBOUGHT", color: .red)
//        } else if value <= oversold {
//            badgeView(text: "OVERSOLD", color: .green)
//        }
//    }
//    
//    private func badgeView(text: String, color: Color) -> some View {
//        Text(text)
//            .font(.system(size: 8, weight: .bold))
//            .foregroundColor(.white)
//            .padding(.horizontal, 4)
//            .padding(.vertical, 2)
//            .background(color.opacity(0.8))
//            .cornerRadius(3)
//    }
//    
//    // MARK: - Y-Axis Labels
//    
//    private var yAxisLabelsOverlay: some View {
//        HStack {
//            Spacer()
//            
//            VStack {
//                Text(String(format: "%.0f", rsiConfig?.overboughtLevel ?? 70))
//                    .font(.system(size: 9))
//                    .foregroundColor(.red.opacity(0.7))
//                
//                Spacer()
//                
//                Text("50")
//                    .font(.system(size: 9))
//                    .foregroundColor(.gray.opacity(0.7))
//                
//                Spacer()
//                
//                Text(String(format: "%.0f", rsiConfig?.oversoldLevel ?? 30))
//                    .font(.system(size: 9))
//                    .foregroundColor(.green.opacity(0.7))
//            }
//            .frame(width: 25)
//            .padding(.top, 18)
//            .padding(.bottom, 4)
//            .padding(.trailing, 4)
//            .background(Color.black.opacity(0.6))
//        }
//    }
//    
//    // MARK: - Canvas Drawing
//    
//    private func drawRSIPanel(context: GraphicsContext, size: CGSize) {
//        guard let config = rsiConfig else { return }
//        
//        let drawableHeight = size.height - 20
//        let topPadding: CGFloat = 18
//        
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//    
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//        
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//        
//        let overboughtZone = Path { p in
//            p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY))
//        }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//        
//        let oversoldZone = Path { p in
//            p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY))
//        }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
//    }
//    
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//        
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//        
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//        
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: oversoldY))
//        path.addLine(to: CGPoint(x: lineEndX, y: oversoldY))
//        context.stroke(path, with: .color(.green.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//    }
//    
//    private func drawRSILine(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let dataPoints = indicatorManager.rsiData
//        guard dataPoints.count >= 2 else { return }
//        
//        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
//        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
//        
//        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
//        guard visiblePoints.count >= 2 else { return }
//        
//        var path = Path()
//        var isFirst = true
//        
//        for point in visiblePoints {
//            let x = xPosition(for: point.candleIndex)
//            let y = yPosition(for: point.value, height: drawableHeight, topPadding: topPadding)
//            
//            guard x >= -50 && x <= size.width + 50 else { continue }
//            
//            if isFirst {
//                path.move(to: CGPoint(x: x, y: y))
//                isFirst = false
//            } else {
//                path.addLine(to: CGPoint(x: x, y: y))
//            }
//        }
//        
//        context.stroke(path, with: .color(config.color.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
//    }
//    
//    // MARK: - Coordinate Helpers
//    
//    private func xPosition(for candleIndex: Int) -> CGFloat {
//        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//    }
//    
//    private func yPosition(for rsiValue: Double, height: CGFloat, topPadding: CGFloat) -> CGFloat {
//        let normalized = rsiValue / 100.0
//        return topPadding + height * (1.0 - CGFloat(normalized))
//    }
//    
//    private func rsiValueColor(_ value: Double) -> Color {
//        let overbought = rsiConfig?.overboughtLevel ?? 70
//        let oversold = rsiConfig?.oversoldLevel ?? 30
//        if value >= overbought { return .red }
//        if value <= oversold { return .green }
//        return .white.opacity(0.9)
//    }
//    
//    // MARK: - X-Axis Labels
//    
//    private static let dateFormatter: DateFormatter = {
//        let f = DateFormatter()
//        f.dateFormat = "dd MMM"
//        return f
//    }()
//    
//    private static let timeFormatter: DateFormatter = {
//        let f = DateFormatter()
//        f.dateFormat = "HH:mm"
//        return f
//    }()
//    
//    private var xAxisLabels: some View {
//        let _ = gestureState.panOffset.width
//        let _ = gestureState.candleWidthScale
//        let _ = gestureState.crosshairActive
//        let _ = gestureState.crosshairX
//        
//        return ZStack {
//            Canvas { context, size in
//                drawXAxisLabels(context: context, size: size)
//            }
//            .frame(height: 22)
//            .background(Color.black)
//            
//            if gestureState.crosshairActive, let timestamp = gestureState.crosshairTimestamp {
//                crosshairTimeLabelOverlay(timestamp: timestamp)
//            }
//        }
//        .frame(height: 22)
//    }
//    
//    @ViewBuilder
//    private func crosshairTimeLabelOverlay(timestamp: Date) -> some View {
//        VStack(spacing: 1) {
//            Image(systemName: "arrowtriangle.up.fill")
//                .font(.system(size: 5))
//                .foregroundColor(.cyan)
//            
//            Text(formatCrosshairTime(timestamp))
//                .font(.system(size: 9, weight: .semibold, design: .monospaced))
//                .foregroundColor(.white)
//                .padding(.horizontal, 6)
//                .padding(.vertical, 3)
//                .background(
//                    RoundedRectangle(cornerRadius: 3)
//                        .fill(Color.cyan.opacity(0.9))
//                )
//        }
//        .position(x: gestureState.crosshairX, y: 11)
//    }
//    
//    private func formatCrosshairTime(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        switch timeframe {
//        case .d1, .w1, .mn:
//            formatter.dateFormat = "dd MMM yyyy"
//        default:
//            formatter.dateFormat = "dd MMM HH:mm"
//        }
//        return formatter.string(from: date)
//    }
//    
//    private func drawXAxisLabels(context: GraphicsContext, size: CGSize) {
//        guard chartData.candles.count >= 2 else { return }
//        
//        let firstCandle = chartData.candles.first!
//        let lastCandle = chartData.candles.last!
//        let timePerCandle = chartData.candles[1].timestamp.timeIntervalSince(chartData.candles[0].timestamp)
//        guard timePerCandle > 0 else { return }
//        
//        let niceTimeStep = getNiceTimeStep(timeframe: timeframe, zoomScale: gestureState.candleWidthScale)
//        
//        let calendar = Calendar.current
//        let startTime = firstCandle.timestamp.timeIntervalSince1970
//        let alignedStart = floor(startTime / niceTimeStep) * niceTimeStep
//        
//        var currentTime = alignedStart
//        let endTime = lastCandle.timestamp.timeIntervalSince1970 + timePerCandle * 10
//        
//        var lastDrawnX: CGFloat = -200
//        let minSpacing: CGFloat = 30
//        
//        while currentTime <= endTime {
//            let candleIndex = (currentTime - startTime) / timePerCandle
//            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//            
//            if x >= -50 && x <= size.width + 50 && (x - lastDrawnX) >= minSpacing {
//                let date = Date(timeIntervalSince1970: currentTime)
//                let components = calendar.dateComponents([.hour, .minute], from: date)
//                let hour = components.hour ?? 0
//                let minute = components.minute ?? 0
//                let isMidnight = hour == 0 && minute == 0
//                
//                if isMidnight {
//                    let text = Self.dateFormatter.string(from: date)
//                    context.draw(
//                        Text(text)
//                            .font(.system(size: 10, weight: .bold))
//                            .foregroundColor(.white),
//                        at: CGPoint(x: x, y: 10)
//                    )
//                } else {
//                    let text = Self.timeFormatter.string(from: date)
//                    context.draw(
//                        Text(text)
//                            .font(.system(size: 9))
//                            .foregroundColor(.gray),
//                        at: CGPoint(x: x, y: 10)
//                    )
//                }
//                lastDrawnX = x
//            }
//            
//            currentTime += niceTimeStep
//        }
//    }
//    
//    private func getNiceTimeStep(timeframe: ChartTimeframe, zoomScale: CGFloat) -> Double {
//        let screenWidth: CGFloat = UIScreen.main.bounds.width
//        let visibleCandles = screenWidth / totalCandleWidth
//        
//        let secondsPerCandle: Double
//        switch timeframe {
//        case .m1: secondsPerCandle = 60
//        case .m5: secondsPerCandle = 300
//        case .m15: secondsPerCandle = 900
//        case .m30: secondsPerCandle = 1800
//        case .h1: secondsPerCandle = 3600
//        case .h4: secondsPerCandle = 14400
//        case .d1: secondsPerCandle = 86400
//        case .w1: secondsPerCandle = 604800
//        case .mn: secondsPerCandle = 2592000
//        }
//        
//        let visibleTimeSpan = Double(visibleCandles) * secondsPerCandle
//        let targetLabels: Double = 5.0
//        let roughStep = visibleTimeSpan / targetLabels
//        
//        return roundToNiceTimeInterval(roughStep)
//    }
//    
//    private func roundToNiceTimeInterval(_ roughStep: Double) -> Double {
//        let niceIntervals: [Double] = [
//            60, 120, 300, 600, 900, 1800,
//            3600, 7200, 14400, 21600, 28800, 43200,
//            86400, 172800, 259200, 432000,
//            604800, 1209600, 2592000, 5184000
//        ]
//        
//        for interval in niceIntervals {
//            if interval >= roughStep * 0.7 {
//                return interval
//            }
//        }
//        
//        return niceIntervals.last!
//    }
//}

