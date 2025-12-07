//
//  RSIPanelView.swift
//  traders_guild
//
//  RSI indicator panel displayed below the main chart
//  Shares the X-axis alignment with the price chart for synchronized scrolling
//
//  IMPORTANT INTEGRATION NOTES:
//  ============================
//  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
//  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
//
//  Example integration in MainView:
//
//  ZStack {
//      mainContentStack  // Contains TradingChartView
//          .sheet(...) // Bottom sheet
//
//      // RSI Panel overlay - positioned independently of chart gestures
//      if chartViewModel.indicatorManager.shouldShowRSIPanel {
//          VStack {
//              Spacer()
//              RSIPanelView(...)
//                  .padding(.bottom, 100) // Clears the minimized bottom sheet
//          }
//          .ignoresSafeArea()
//      }
//  }
//

import SwiftUI

// MARK: - RSI Panel View

struct RSIPanelView: View {
    
    // MARK: - Properties
    
    @ObservedObject var indicatorManager: IndicatorManager
    @ObservedObject var chartData: ChartDataManager
    @ObservedObject var gestureState: ChartGestureState  // Must observe for pan sync
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    // Panel height state
    @Binding var panelHeight: CGFloat
    var minPanelHeight: CGFloat = 80
    var maxPanelHeight: CGFloat = 200
    
    // MARK: - Private State
    
    @State private var isDraggingHandle = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var lastDragTranslation: CGSize = .zero  // For pan gesture
    
    // MARK: - Computed Properties
    
    /// Total width of each candle including spacing
    private var totalCandleWidth: CGFloat {
        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
    }
    
    /// Actual candle body width (without spacing)
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
            // Resize handle - completely separate gesture context
            resizeHandleBar
            
            // RSI content area with pan gesture (syncs with main chart)
            rsiContentArea
                .frame(height: panelHeight)
                .gesture(panGesture)
            
            // X-axis labels at the bottom of RSI panel
            xAxisLabels
        }
        .background(Color.black)
    }
    
    // MARK: - Pan Gesture (syncs with main chart)
    
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Start tracking on first drag event
                if lastDragTranslation == .zero {
                    gestureState.beginDrag()
                }
                
                let incrementalX = value.translation.width - lastDragTranslation.width
                // RSI panel only supports horizontal panning
                let incrementalY: CGFloat = 0
                
                gestureState.applyPan(
                    translation: CGSize(width: incrementalX, height: incrementalY),
                    chartWidth: UIScreen.main.bounds.width,
                    candleCount: chartData.candles.count,
                    candleWidth: totalCandleWidth,
                    chartHeight: panelHeight,
                    priceScale: 1.0,  // RSI doesn't use price scale
                    trackVelocity: true
                )
                
                lastDragTranslation = value.translation
            }
            .onEnded { value in
                // Trigger momentum scrolling
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
    
    // MARK: - X-Axis Labels
    
    // Cached date formatters for performance
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
        // Explicit dependency on panOffset to force redraw
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        
        return Canvas { context, size in
            drawXAxisLabels(context: context, size: size)
        }
        .frame(height: 22)
        .background(Color.black)
    }
    
    private func drawXAxisLabels(context: GraphicsContext, size: CGSize) {
        guard chartData.candles.count >= 2 else { return }
        
        // Get the time range we need to cover
        let firstCandle = chartData.candles.first!
        let lastCandle = chartData.candles.last!
        
        // Derive time per candle from actual data
        let timePerCandle = chartData.candles[1].timestamp.timeIntervalSince(chartData.candles[0].timestamp)
        guard timePerCandle > 0 else { return }
        
        // Calculate nice time step based on candle timeframe and zoom
        let niceTimeStep: Double
        if timePerCandle <= 60 {  // 1 min
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 300 : 1800
        } else if timePerCandle <= 300 {  // 5 min
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 1800 : 3600
        } else if timePerCandle <= 900 {  // 15 min
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 3600 : 7200
        } else if timePerCandle <= 1800 {  // 30 min
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 7200 : 14400
        } else if timePerCandle <= 3600 {  // 1 hour
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 14400 : 28800
        } else if timePerCandle <= 14400 {  // 4 hour
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 43200 : 86400
        } else {  // Daily+
            niceTimeStep = gestureState.candleWidthScale > 0.7 ? 86400 : 172800
        }
        
        // Find the first "nice" time boundary before our data starts
        let calendar = Calendar.current
        let startTime = firstCandle.timestamp.timeIntervalSince1970
        let alignedStart = floor(startTime / niceTimeStep) * niceTimeStep
        
        // Draw labels at regular time intervals
        var currentTime = alignedStart
        let endTime = lastCandle.timestamp.timeIntervalSince1970 + timePerCandle * 10
        
        var lastDrawnX: CGFloat = -200
        let minSpacing: CGFloat = 60
        
        while currentTime <= endTime {
            // Convert time to candle index
            let candleIndex = (currentTime - startTime) / timePerCandle
            
            // Convert candle index to screen x position
            let x = CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
            
            // Only draw if in visible area and not too close to last label
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
    
    // MARK: - Resize Handle
    
    private var resizeHandleBar: some View {
        ZStack {
            // Full-width tap area
            Rectangle()
                .fill(Color(white: 0.08))
            
            // Visual indicator
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
                    // Dragging UP (negative translation) INCREASES height
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
            // Separator line at bottom
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - RSI Content
    
    private var rsiContentArea: some View {
        // Explicit dependencies to ensure Canvas redraws on gesture changes
        let _ = gestureState.panOffset.width
        let _ = gestureState.candleWidthScale
        
        return ZStack {
            // Background
            Color.black.opacity(0.95)
            
            // Canvas drawing
            Canvas { context, size in
                drawRSIPanel(context: context, size: size)
            }
            
            // Y-axis labels
            yAxisLabelsOverlay
            
            // Header with current value
            panelHeaderOverlay
        }
        .clipped()
    }
    
    // MARK: - Header
    
    private var panelHeaderOverlay: some View {
        VStack {
            HStack(spacing: 6) {
                Text(rsiConfig?.label ?? "RSI 14")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                if let latestRSI = indicatorManager.latestRSI {
                    Text(String(format: "%.1f", latestRSI.value))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(rsiValueColor(latestRSI.value))
                    
                    rsiConditionBadge(value: latestRSI.value)
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    // MARK: - RSI Condition Badge
    
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
        
        // Draw zones first (background)
        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        
        // Draw reference levels
        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
        
        // Draw RSI line on top
        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
    }
    
    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 30
        
        // Overbought line
        var path = Path()
        path.move(to: CGPoint(x: 0, y: overboughtY))
        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        
        // Middle line
        path = Path()
        path.move(to: CGPoint(x: 0, y: middleY))
        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        
        // Oversold line
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
    
    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
        guard config.showLevels else { return }
        
        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
        let lineEndX = size.width - 30
        
        // Overbought zone
        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
        
        // Oversold zone
        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
}

// MARK: - Preview

#if DEBUG
struct RSIPanelView_Previews: PreviewProvider {
    static var previews: some View {
        RSIPanelPreviewWrapper()
            .preferredColorScheme(.dark)
    }
}

struct RSIPanelPreviewWrapper: View {
    @State private var panelHeight: CGFloat = 120
    @StateObject private var manager = IndicatorManager()
    @StateObject private var gestureState = ChartGestureState()
    @StateObject private var chartData = ChartDataManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Text("Chart Area")
                    .foregroundColor(.gray)
                Spacer()
            }
            
            VStack {
                Spacer()
                
                RSIPanelView(
                    indicatorManager: manager,
                    chartData: chartData,
                    gestureState: gestureState,
                    baseCandleWidth: 12,
                    candleSpacing: 4,
                    panelHeight: $panelHeight
                )
                
                // Simulated bottom sheet
                Color.gray.opacity(0.2)
                    .frame(height: 100)
            }
        }
        .onAppear { manager.enableRSI() }
    }
}
#endif






////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    let chartData: ChartDataManager
//    let gestureState: ChartGestureState
//    let totalCandleWidth: CGFloat
//    let actualCandleWidth: CGFloat
//
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//
//    // MARK: - Private State
//
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//
//    // MARK: - Computed Properties
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//
//    // MARK: - Resize Handle
//
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//
//            // Y-axis labels
//            yAxisLabelsOverlay
//
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//
//    // MARK: - Header
//
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: ChartDataManager(),
//                    gestureState: ChartGestureState(),
//                    totalCandleWidth: 16,
//                    actualCandleWidth: 12,
//                    panelHeight: $panelHeight
//                )
//
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif






////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    let chartData: ChartDataManager
//    let gestureState: ChartGestureState
//    let totalCandleWidth: CGFloat
//    let actualCandleWidth: CGFloat
//
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//
//    // MARK: - Private State
//
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//
//    // MARK: - Computed Properties
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//
//    // MARK: - Resize Handle
//
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//
//            // Y-axis labels
//            yAxisLabelsOverlay
//
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//
//    // MARK: - Header
//
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: ChartDataManager(),
//                    gestureState: ChartGestureState(),
//                    totalCandleWidth: 16,
//                    actualCandleWidth: 12,
//                    panelHeight: $panelHeight
//                )
//
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif






////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    let chartData: ChartDataManager
//    let gestureState: ChartGestureState
//    let totalCandleWidth: CGFloat
//    let actualCandleWidth: CGFloat
//
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//
//    // MARK: - Private State
//
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//
//    // MARK: - Computed Properties
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//
//    // MARK: - Resize Handle
//
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//
//            // Y-axis labels
//            yAxisLabelsOverlay
//
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//
//    // MARK: - Header
//
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: ChartDataManager(),
//                    gestureState: ChartGestureState(),
//                    totalCandleWidth: 16,
//                    actualCandleWidth: 12,
//                    panelHeight: $panelHeight
//                )
//
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif






////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    let chartData: ChartDataManager
//    let gestureState: ChartGestureState
//    let totalCandleWidth: CGFloat
//    let actualCandleWidth: CGFloat
//
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//
//    // MARK: - Private State
//
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//
//    // MARK: - Computed Properties
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//
//    // MARK: - Resize Handle
//
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//
//            // Y-axis labels
//            yAxisLabelsOverlay
//
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//
//    // MARK: - Header
//
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: ChartDataManager(),
//                    gestureState: ChartGestureState(),
//                    totalCandleWidth: 16,
//                    actualCandleWidth: 12,
//                    panelHeight: $panelHeight
//                )
//
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif






////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    let chartData: ChartDataManager
//    let gestureState: ChartGestureState
//    let totalCandleWidth: CGFloat
//    let actualCandleWidth: CGFloat
//
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//
//    // MARK: - Private State
//
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//
//    // MARK: - Computed Properties
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//
//    // MARK: - Resize Handle
//
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//
//            // Y-axis labels
//            yAxisLabelsOverlay
//
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//
//    // MARK: - Header
//
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: ChartDataManager(),
//                    gestureState: ChartGestureState(),
//                    totalCandleWidth: 16,
//                    actualCandleWidth: 12,
//                    panelHeight: $panelHeight
//                )
//
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif





////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    let chartData: ChartDataManager
//    let gestureState: ChartGestureState
//    let totalCandleWidth: CGFloat
//    let actualCandleWidth: CGFloat
//
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//
//    // MARK: - Private State
//
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//
//    // MARK: - Computed Properties
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//
//    // MARK: - Resize Handle
//
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//
//            // Y-axis labels
//            yAxisLabelsOverlay
//
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//
//    // MARK: - Header
//
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: ChartDataManager(),
//                    gestureState: ChartGestureState(),
//                    totalCandleWidth: 16,
//                    actualCandleWidth: 12,
//                    panelHeight: $panelHeight
//                )
//
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif







////
////  RSIPanelView.swift
////  traders_guild
////
////  RSI indicator panel displayed below the main chart
////  Shares the X-axis alignment with the price chart for synchronized scrolling
////
////  IMPORTANT INTEGRATION NOTES:
////  ============================
////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
////
////  Example integration in MainView:
////
////  ZStack {
////      mainContentStack  // Contains TradingChartView
////          .sheet(...) // Bottom sheet
////
////      // RSI Panel overlay - positioned independently of chart gestures
////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
////          VStack {
////              Spacer()
////              RSIPanelView(...)
////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
////          }
////          .ignoresSafeArea()
////      }
////  }
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
//    @ObservedObject var gestureState: ChartGestureState  // Must observe for pan sync
//    let baseCandleWidth: CGFloat
//    let candleSpacing: CGFloat
//    
//    // Panel height state
//    @Binding var panelHeight: CGFloat
//    var minPanelHeight: CGFloat = 80
//    var maxPanelHeight: CGFloat = 200
//    
//    // MARK: - Private State
//    
//    @State private var isDraggingHandle = false
//    @State private var dragStartHeight: CGFloat = 0
//    
//    // MARK: - Computed Properties
//    
//    /// Total width of each candle including spacing
//    private var totalCandleWidth: CGFloat {
//        baseCandleWidth * gestureState.candleWidthScale + candleSpacing
//    }
//    
//    /// Actual candle body width (without spacing)
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
//            // Resize handle - completely separate gesture context
//            resizeHandleBar
//            
//            // RSI content area
//            rsiContentArea
//                .frame(height: panelHeight)
//        }
//        .background(Color.black)
//    }
//    
//    // MARK: - Resize Handle
//    
//    private var resizeHandleBar: some View {
//        ZStack {
//            // Full-width tap area
//            Rectangle()
//                .fill(Color(white: 0.08))
//            
//            // Visual indicator
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
//                    // Dragging UP (negative translation) INCREASES height
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
//            // Separator line at bottom
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
//        ZStack {
//            // Background
//            Color.black.opacity(0.95)
//            
//            // Canvas drawing
//            Canvas { context, size in
//                drawRSIPanel(context: context, size: size)
//            }
//            
//            // Y-axis labels
//            yAxisLabelsOverlay
//            
//            // Header with current value
//            panelHeaderOverlay
//        }
//        .clipped()
//    }
//    
//    // MARK: - Header
//    
//    private var panelHeaderOverlay: some View {
//        VStack {
//            HStack(spacing: 6) {
//                Text(rsiConfig?.label ?? "RSI 14")
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.8))
//                
//                if let latestRSI = indicatorManager.latestRSI {
//                    Text(String(format: "%.1f", latestRSI.value))
//                        .font(.system(size: 11, weight: .bold, design: .monospaced))
//                        .foregroundColor(rsiValueColor(latestRSI.value))
//                    
//                    rsiConditionBadge(value: latestRSI.value)
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
//    // MARK: - RSI Condition Badge
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
//        // Draw zones first (background)
//        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//        
//        // Draw reference levels
//        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//        
//        // Draw RSI line on top
//        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
//    }
//    
//    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//        
//        // Overbought line
//        var path = Path()
//        path.move(to: CGPoint(x: 0, y: overboughtY))
//        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
//        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
//        
//        // Middle line
//        path = Path()
//        path.move(to: CGPoint(x: 0, y: middleY))
//        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
//        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
//        
//        // Oversold line
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
//    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
//        guard config.showLevels else { return }
//        
//        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
//        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
//        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
//        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
//        let lineEndX = size.width - 30
//        
//        // Overbought zone
//        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
//        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
//        
//        // Oversold zone
//        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
//        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
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
//}
//
//// MARK: - Preview
//
//#if DEBUG
//struct RSIPanelView_Previews: PreviewProvider {
//    static var previews: some View {
//        RSIPanelPreviewWrapper()
//            .preferredColorScheme(.dark)
//    }
//}
//
//struct RSIPanelPreviewWrapper: View {
//    @State private var panelHeight: CGFloat = 120
//    @StateObject private var manager = IndicatorManager()
//    @StateObject private var gestureState = ChartGestureState()
//    @StateObject private var chartData = ChartDataManager()
//    
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//            
//            VStack {
//                Text("Chart Area")
//                    .foregroundColor(.gray)
//                Spacer()
//            }
//            
//            VStack {
//                Spacer()
//                
//                RSIPanelView(
//                    indicatorManager: manager,
//                    chartData: chartData,
//                    gestureState: gestureState,
//                    baseCandleWidth: 12,
//                    candleSpacing: 4,
//                    panelHeight: $panelHeight
//                )
//                
//                // Simulated bottom sheet
//                Color.gray.opacity(0.2)
//                    .frame(height: 100)
//            }
//        }
//        .onAppear { manager.enableRSI() }
//    }
//}
//#endif
//
//
//
//
//
//
//////
//////  RSIPanelView.swift
//////  traders_guild
//////
//////  RSI indicator panel displayed below the main chart
//////  Shares the X-axis alignment with the price chart for synchronized scrolling
//////
//////  IMPORTANT INTEGRATION NOTES:
//////  ============================
//////  This panel should be placed in a ZStack OVERLAY on MainView (not inside TradingChartView)
//////  to avoid gesture conflicts and ensure proper positioning above the bottom sheet.
//////
//////  Example integration in MainView:
//////
//////  ZStack {
//////      mainContentStack  // Contains TradingChartView
//////          .sheet(...) // Bottom sheet
//////
//////      // RSI Panel overlay - positioned independently of chart gestures
//////      if chartViewModel.indicatorManager.shouldShowRSIPanel {
//////          VStack {
//////              Spacer()
//////              RSIPanelView(...)
//////                  .padding(.bottom, 100) // Clears the minimized bottom sheet
//////          }
//////          .ignoresSafeArea()
//////      }
//////  }
//////
////
////import SwiftUI
////
////// MARK: - RSI Panel View
////
////struct RSIPanelView: View {
////    
////    // MARK: - Properties
////    
////    @ObservedObject var indicatorManager: IndicatorManager
////    let chartData: ChartDataManager
////    let gestureState: ChartGestureState
////    let totalCandleWidth: CGFloat
////    let actualCandleWidth: CGFloat
////    
////    // Panel height state
////    @Binding var panelHeight: CGFloat
////    var minPanelHeight: CGFloat = 80
////    var maxPanelHeight: CGFloat = 200
////    
////    // MARK: - Private State
////    
////    @State private var isDraggingHandle = false
////    @State private var dragStartHeight: CGFloat = 0
////    
////    // MARK: - Computed Properties
////    
////    private var rsiConfig: RSIConfig? {
////        indicatorManager.activeIndicators.rsi
////    }
////    
////    private var totalOffset: CGFloat {
////        gestureState.panOffset.width
////    }
////    
////    // MARK: - Body
////    
////    var body: some View {
////        VStack(spacing: 0) {
////            // Resize handle - completely separate gesture context
////            resizeHandleBar
////            
////            // RSI content area
////            rsiContentArea
////                .frame(height: panelHeight)
////        }
////        .background(Color.black)
////    }
////    
////    // MARK: - Resize Handle
////    
////    private var resizeHandleBar: some View {
////        ZStack {
////            // Full-width tap area
////            Rectangle()
////                .fill(Color(white: 0.08))
////            
////            // Visual indicator
////            VStack(spacing: 3) {
////                Capsule()
////                    .fill(isDraggingHandle ? Color.white.opacity(0.8) : Color.gray.opacity(0.5))
////                    .frame(width: 36, height: 5)
////            }
////        }
////        .frame(height: 22)
////        .contentShape(Rectangle())
////        .gesture(
////            DragGesture(minimumDistance: 0, coordinateSpace: .global)
////                .onChanged { value in
////                    if !isDraggingHandle {
////                        isDraggingHandle = true
////                        dragStartHeight = panelHeight
////                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
////                    }
////                    // Dragging UP (negative translation) INCREASES height
////                    let delta = -value.translation.height
////                    let newHeight = dragStartHeight + delta
////                    panelHeight = min(maxPanelHeight, max(minPanelHeight, newHeight))
////                }
////                .onEnded { _ in
////                    isDraggingHandle = false
////                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
////                }
////        )
////        .overlay(
////            // Separator line at bottom
////            Rectangle()
////                .fill(Color.gray.opacity(0.3))
////                .frame(height: 1),
////            alignment: .bottom
////        )
////    }
////    
////    // MARK: - RSI Content
////    
////    private var rsiContentArea: some View {
////        ZStack {
////            // Background
////            Color.black.opacity(0.95)
////            
////            // Canvas drawing
////            Canvas { context, size in
////                drawRSIPanel(context: context, size: size)
////            }
////            
////            // Y-axis labels
////            yAxisLabelsOverlay
////            
////            // Header with current value
////            panelHeaderOverlay
////        }
////        .clipped()
////    }
////    
////    // MARK: - Header
////    
////    private var panelHeaderOverlay: some View {
////        VStack {
////            HStack(spacing: 6) {
////                Text(rsiConfig?.label ?? "RSI 14")
////                    .font(.system(size: 11, weight: .semibold))
////                    .foregroundColor(.white.opacity(0.8))
////                
////                if let latestRSI = indicatorManager.latestRSI {
////                    Text(String(format: "%.1f", latestRSI.value))
////                        .font(.system(size: 11, weight: .bold, design: .monospaced))
////                        .foregroundColor(rsiValueColor(latestRSI.value))
////                    
////                    rsiConditionBadge(value: latestRSI.value)
////                }
////                
////                Spacer()
////            }
////            .padding(.horizontal, 8)
////            .padding(.top, 4)
////            
////            Spacer()
////        }
////    }
////    
////    // MARK: - RSI Condition Badge
////    
////    @ViewBuilder
////    private func rsiConditionBadge(value: Double) -> some View {
////        let overbought = rsiConfig?.overboughtLevel ?? 70
////        let oversold = rsiConfig?.oversoldLevel ?? 30
////        
////        if value >= overbought {
////            badgeView(text: "OVERBOUGHT", color: .red)
////        } else if value <= oversold {
////            badgeView(text: "OVERSOLD", color: .green)
////        }
////    }
////    
////    private func badgeView(text: String, color: Color) -> some View {
////        Text(text)
////            .font(.system(size: 8, weight: .bold))
////            .foregroundColor(.white)
////            .padding(.horizontal, 4)
////            .padding(.vertical, 2)
////            .background(color.opacity(0.8))
////            .cornerRadius(3)
////    }
////    
////    // MARK: - Y-Axis Labels
////    
////    private var yAxisLabelsOverlay: some View {
////        HStack {
////            Spacer()
////            
////            VStack {
////                Text(String(format: "%.0f", rsiConfig?.overboughtLevel ?? 70))
////                    .font(.system(size: 9))
////                    .foregroundColor(.red.opacity(0.7))
////                
////                Spacer()
////                
////                Text("50")
////                    .font(.system(size: 9))
////                    .foregroundColor(.gray.opacity(0.7))
////                
////                Spacer()
////                
////                Text(String(format: "%.0f", rsiConfig?.oversoldLevel ?? 30))
////                    .font(.system(size: 9))
////                    .foregroundColor(.green.opacity(0.7))
////            }
////            .frame(width: 25)
////            .padding(.top, 18)
////            .padding(.bottom, 4)
////            .padding(.trailing, 4)
////            .background(Color.black.opacity(0.6))
////        }
////    }
////    
////    // MARK: - Canvas Drawing
////    
////    private func drawRSIPanel(context: GraphicsContext, size: CGSize) {
////        guard let config = rsiConfig else { return }
////        
////        let drawableHeight = size.height - 20
////        let topPadding: CGFloat = 18
////        
////        // Draw zones first (background)
////        drawZones(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
////        
////        // Draw reference levels
////        drawReferenceLevels(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
////        
////        // Draw RSI line on top
////        drawRSILine(context: context, size: size, config: config, drawableHeight: drawableHeight, topPadding: topPadding)
////    }
////    
////    private func drawReferenceLevels(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
////        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
////        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
////        let middleY = yPosition(for: 50, height: drawableHeight, topPadding: topPadding)
////        let lineEndX = size.width - 30
////        
////        // Overbought line
////        var path = Path()
////        path.move(to: CGPoint(x: 0, y: overboughtY))
////        path.addLine(to: CGPoint(x: lineEndX, y: overboughtY))
////        context.stroke(path, with: .color(.red.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
////        
////        // Middle line
////        path = Path()
////        path.move(to: CGPoint(x: 0, y: middleY))
////        path.addLine(to: CGPoint(x: lineEndX, y: middleY))
////        context.stroke(path, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
////        
////        // Oversold line
////        path = Path()
////        path.move(to: CGPoint(x: 0, y: oversoldY))
////        path.addLine(to: CGPoint(x: lineEndX, y: oversoldY))
////        context.stroke(path, with: .color(.green.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
////    }
////    
////    private func drawRSILine(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
////        let dataPoints = indicatorManager.rsiData
////        guard dataPoints.count >= 2 else { return }
////        
////        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
////        let visibleEndIndex = min(chartData.candles.count, visibleStartIndex + Int(size.width / totalCandleWidth) + 10)
////        
////        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
////        guard visiblePoints.count >= 2 else { return }
////        
////        var path = Path()
////        var isFirst = true
////        
////        for point in visiblePoints {
////            let x = xPosition(for: point.candleIndex)
////            let y = yPosition(for: point.value, height: drawableHeight, topPadding: topPadding)
////            
////            guard x >= -50 && x <= size.width + 50 else { continue }
////            
////            if isFirst {
////                path.move(to: CGPoint(x: x, y: y))
////                isFirst = false
////            } else {
////                path.addLine(to: CGPoint(x: x, y: y))
////            }
////        }
////        
////        context.stroke(path, with: .color(config.color.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
////    }
////    
////    private func drawZones(context: GraphicsContext, size: CGSize, config: RSIConfig, drawableHeight: CGFloat, topPadding: CGFloat) {
////        guard config.showLevels else { return }
////        
////        let overboughtY = yPosition(for: config.overboughtLevel, height: drawableHeight, topPadding: topPadding)
////        let oversoldY = yPosition(for: config.oversoldLevel, height: drawableHeight, topPadding: topPadding)
////        let topY = yPosition(for: 100, height: drawableHeight, topPadding: topPadding)
////        let bottomY = yPosition(for: 0, height: drawableHeight, topPadding: topPadding)
////        let lineEndX = size.width - 30
////        
////        // Overbought zone
////        let overboughtZone = Path { p in p.addRect(CGRect(x: 0, y: topY, width: lineEndX, height: overboughtY - topY)) }
////        context.fill(overboughtZone, with: .color(.red.opacity(0.08)))
////        
////        // Oversold zone
////        let oversoldZone = Path { p in p.addRect(CGRect(x: 0, y: oversoldY, width: lineEndX, height: bottomY - oversoldY)) }
////        context.fill(oversoldZone, with: .color(.green.opacity(0.08)))
////    }
////    
////    // MARK: - Coordinate Helpers
////    
////    private func xPosition(for candleIndex: Int) -> CGFloat {
////        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
////    }
////    
////    private func yPosition(for rsiValue: Double, height: CGFloat, topPadding: CGFloat) -> CGFloat {
////        let normalized = rsiValue / 100.0
////        return topPadding + height * (1.0 - CGFloat(normalized))
////    }
////    
////    private func rsiValueColor(_ value: Double) -> Color {
////        let overbought = rsiConfig?.overboughtLevel ?? 70
////        let oversold = rsiConfig?.oversoldLevel ?? 30
////        if value >= overbought { return .red }
////        if value <= oversold { return .green }
////        return .white.opacity(0.9)
////    }
////}
////
////// MARK: - Preview
////
////#if DEBUG
////struct RSIPanelView_Previews: PreviewProvider {
////    static var previews: some View {
////        RSIPanelPreviewWrapper()
////            .preferredColorScheme(.dark)
////    }
////}
////
////struct RSIPanelPreviewWrapper: View {
////    @State private var panelHeight: CGFloat = 120
////    @StateObject private var manager = IndicatorManager()
////    
////    var body: some View {
////        ZStack {
////            Color.black.ignoresSafeArea()
////            
////            VStack {
////                Text("Chart Area")
////                    .foregroundColor(.gray)
////                Spacer()
////            }
////            
////            VStack {
////                Spacer()
////                
////                RSIPanelView(
////                    indicatorManager: manager,
////                    chartData: ChartDataManager(),
////                    gestureState: ChartGestureState(),
////                    totalCandleWidth: 16,
////                    actualCandleWidth: 12,
////                    panelHeight: $panelHeight
////                )
////                
////                // Simulated bottom sheet
////                Color.gray.opacity(0.2)
////                    .frame(height: 100)
////            }
////        }
////        .onAppear { manager.enableRSI() }
////    }
////}
////#endif
