///
//  ChartCrosshairAndNavigation.swift
//  traders_guild
//
//  UPDATED - Subtle crosshair design + symbol-aware price formatting
//

import SwiftUI

// MARK: - Crosshair Manager

class CrosshairManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var position: CGPoint = .zero
    @Published var targetCandle: CandleDTO?
    @Published var targetPrice: Double = 0
    
    func activate(at point: CGPoint, coordinateSystem: ChartCoordinateSystem, chartData: ChartDataManager) {
        isActive = true
        updatePosition(point, coordinateSystem: coordinateSystem, chartData: chartData)
    }
    
    func updatePosition(_ point: CGPoint, coordinateSystem: ChartCoordinateSystem, chartData: ChartDataManager) {
        position = point
        
        if let candleIndex = coordinateSystem.candleIndex(atXPosition: point.x),
           candleIndex < chartData.candles.count {
            targetCandle = chartData.candles[candleIndex]
        }
        
        targetPrice = coordinateSystem.price(atYPosition: point.y)
    }
    
    func deactivate() {
        isActive = false
        targetCandle = nil
        targetPrice = 0
    }
}

// MARK: - Crosshair View (Updated - More Subtle)

struct CrosshairView: View {
    @ObservedObject var crosshairManager: CrosshairManager
    let chartSize: CGSize
    let chartData: ChartDataManager
    
    // RSI Panel state - for positioning time label correctly
    var rsiPanelActive: Bool = false
    var rsiPanelHeight: CGFloat = 120
    
    // Indicator manager for showing indicator values
    var indicatorManager: IndicatorManager? = nil
    
    // Current timeframe for time formatting
    var timeframe: ChartTimeframe = .h1
    
    /// Backwards-compatible initializer (creates fallback ChartDataManager)
    init(crosshairManager: CrosshairManager, chartSize: CGSize) {
        self.crosshairManager = crosshairManager
        self.chartSize = chartSize
        self.chartData = ChartDataManager()
    }
    
    /// Full initializer with chartData for symbol-aware formatting
    init(crosshairManager: CrosshairManager, chartSize: CGSize, chartData: ChartDataManager) {
        self.crosshairManager = crosshairManager
        self.chartSize = chartSize
        self.chartData = chartData
    }
    
    /// Extended initializer with RSI panel state, indicators, and timeframe
    init(
        crosshairManager: CrosshairManager,
        chartSize: CGSize,
        chartData: ChartDataManager,
        rsiPanelActive: Bool,
        rsiPanelHeight: CGFloat,
        indicatorManager: IndicatorManager?,
        timeframe: ChartTimeframe
    ) {
        self.crosshairManager = crosshairManager
        self.chartSize = chartSize
        self.chartData = chartData
        self.rsiPanelActive = rsiPanelActive
        self.rsiPanelHeight = rsiPanelHeight
        self.indicatorManager = indicatorManager
        self.timeframe = timeframe
    }
    
    /// Computed property for time label Y position
    /// Always positioned at the x-axis area at the bottom of the chart
    private var timeLabelY: CGFloat {
        let bottomAreaHeight = chartSize.height * 0.11
        // Position inline with x-axis labels (22pt canvas + 10pt padding = 32pt total, center at ~21pt from bottom of canvas)
        // This positions it at the same y as the x-axis labels regardless of RSI panel
        return chartSize.height - bottomAreaHeight - 21
    }
    
    var body: some View {
        if crosshairManager.isActive {
            ZStack {
                // Vertical line - thinner and more subtle
                Path { path in
                    path.move(to: CGPoint(x: crosshairManager.position.x, y: 0))
                    path.addLine(to: CGPoint(x: crosshairManager.position.x, y: chartSize.height))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
                
                // Horizontal line - thinner and more subtle
                Path { path in
                    path.move(to: CGPoint(x: 0, y: crosshairManager.position.y))
                    path.addLine(to: CGPoint(x: chartSize.width, y: crosshairManager.position.y))
                }
                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
                
                // Center dot - smaller
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .position(crosshairManager.position)
                
                // Price label on Y-axis
                CrosshairPriceLabel(
                    price: crosshairManager.targetPrice,
                    chartData: chartData
                )
                .position(x: chartSize.width - 35, y: crosshairManager.position.y)
                
                // Time label on X-axis - only show when RSI panel is NOT active
                // (RSI panel has its own time label on its x-axis)
                if !rsiPanelActive, let candle = crosshairManager.targetCandle {
                    CrosshairTimeLabel(timestamp: candle.timestamp, timeframe: timeframe)
                        .position(x: crosshairManager.position.x, y: timeLabelY)
                }
                
                // Compact info popup with indicator values
                CrosshairInfoPopupCompact(
                    candle: crosshairManager.targetCandle,
                    price: crosshairManager.targetPrice,
                    position: crosshairManager.position,
                    chartSize: chartSize,
                    chartData: chartData,
                    indicatorManager: indicatorManager,
                    timeframe: timeframe
                )
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Crosshair Price Label (Symbol-Aware)

struct CrosshairPriceLabel: View {
    let price: Double
    let chartData: ChartDataManager
    
    var body: some View {
        HStack(spacing: 2) {
            // Arrow pointing to crosshair
            Image(systemName: "arrowtriangle.left.fill")
                .font(.system(size: 6))
                .foregroundColor(.yellow)
            
            Text(chartData.formatPrice(price))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow.opacity(0.95))
                        .shadow(color: .yellow.opacity(0.4), radius: 3, x: 0, y: 1)
                )
        }
    }
}

// MARK: - Crosshair Time Label

struct CrosshairTimeLabel: View {
    let timestamp: Date
    var timeframe: ChartTimeframe = .h1
    
    /// Format time based on timeframe
    /// - Daily and above: Just show date (no time)
    /// - Below daily: Show date and time (hour:minute)
    private var formattedTime: String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .d1, .w1, .mn:
            // Daily and above - just show date
            formatter.dateFormat = "dd MMM yyyy"
        case .h4:
            // 4-hour - show date and hour
            formatter.dateFormat = "dd MMM HH:mm"
        case .h1:
            // Hourly - show date and time
            formatter.dateFormat = "dd MMM HH:mm"
        case .m30, .m15, .m5, .m1:
            // Sub-hourly - show date and time
            formatter.dateFormat = "dd MMM HH:mm"
        }
        
        return formatter.string(from: timestamp)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Arrow indicator pointing up to the crosshair
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 6))
                .foregroundColor(.cyan)
            
            Text(formattedTime)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.cyan.opacity(0.9))
                        .shadow(color: .cyan.opacity(0.4), radius: 3, x: 0, y: 1)
                )
        }
    }
}

// MARK: - Compact Crosshair Info Popup (Subtle Design)

struct CrosshairInfoPopupCompact: View {
    let candle: CandleDTO?
    let price: Double
    let position: CGPoint
    let chartSize: CGSize
    let chartData: ChartDataManager
    var indicatorManager: IndicatorManager? = nil
    var timeframe: ChartTimeframe = .h1
    
    private var popupPosition: CGPoint {
        var x = position.x + 60
        var y = position.y - 50
        
        // Keep popup on screen
        if x > chartSize.width - 100 {
            x = position.x - 60
        }
        if y < 40 {
            y = position.y + 50
        }
        if y > chartSize.height - 80 {
            y = chartSize.height - 80
        }
        
        return CGPoint(x: x, y: y)
    }
    
    /// Format time based on timeframe for the info popup header
    private func formatTimeForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .d1, .w1, .mn:
            // Daily and above - just date
            formatter.dateFormat = "EEE, dd MMM yyyy"
        case .h4, .h1:
            // Hourly - date and time
            formatter.dateFormat = "dd MMM HH:mm"
        case .m30, .m15, .m5, .m1:
            // Sub-hourly - full timestamp
            formatter.dateFormat = "dd MMM HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    /// Get EMA values at the crosshair candle index
    private var emaValues: [(period: Int, value: Double, color: Color)]? {
        guard let manager = indicatorManager,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        var values: [(period: Int, value: Double, color: Color)] = []
        
        for maConfig in manager.activeIndicators.movingAverages where maConfig.isEnabled {
            // Get the calculated values from indicator manager
            if let maDataPoints = manager.movingAverageData[maConfig.id] {
                // Find the data point for this candle index
                if let dataPoint = maDataPoints.first(where: { $0.candleIndex == candleIndex }) {
                    if !dataPoint.value.isNaN {
                        // Convert CodableColor to Color using .color property
                        values.append((period: maConfig.period, value: dataPoint.value, color: maConfig.color.color))
                    }
                }
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    /// Get RSI value at the crosshair candle index
    private var rsiValue: Double? {
        guard let manager = indicatorManager,
              let rsiConfig = manager.activeIndicators.rsi,
              rsiConfig.isEnabled,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        // Find RSI data point for this candle index
        if let dataPoint = manager.rsiData.first(where: { $0.candleIndex == candleIndex }) {
            return dataPoint.value.isNaN ? nil : dataPoint.value
        }
        
        return nil
    }
    
    /// Get MACD values at the crosshair candle index
    private var macdValues: (macd: Double, signal: Double, histogram: Double)? {
        guard let manager = indicatorManager,
              let macdConfig = manager.activeIndicators.macd,
              macdConfig.isEnabled,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        if let dataPoint = manager.macdData.first(where: { $0.candleIndex == candleIndex }) {
            if !dataPoint.macdLine.isNaN {
                return (dataPoint.macdLine, dataPoint.signalLine, dataPoint.histogram)
            }
        }
        return nil
    }
    
    /// Get Stochastic values at the crosshair candle index
    private var stochasticValues: (k: Double, d: Double)? {
        guard let manager = indicatorManager,
              let stochConfig = manager.activeIndicators.stochastic,
              stochConfig.isEnabled,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        if let dataPoint = manager.stochasticData.first(where: { $0.candleIndex == candleIndex }) {
            if !dataPoint.kValue.isNaN {
                return (dataPoint.kValue, dataPoint.dValue)
            }
        }
        return nil
    }
    
    /// Get CCI value at the crosshair candle index
    private var cciValue: Double? {
        guard let manager = indicatorManager,
              let cciConfig = manager.activeIndicators.cci,
              cciConfig.isEnabled,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        if let dataPoint = manager.cciData.first(where: { $0.candleIndex == candleIndex }) {
            return dataPoint.value.isNaN ? nil : dataPoint.value
        }
        return nil
    }
    
    /// Get Williams %R value at the crosshair candle index
    private var williamsRValue: Double? {
        guard let manager = indicatorManager,
              let wrConfig = manager.activeIndicators.williamsR,
              wrConfig.isEnabled,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        if let dataPoint = manager.williamsRData.first(where: { $0.candleIndex == candleIndex }) {
            return dataPoint.value.isNaN ? nil : dataPoint.value
        }
        return nil
    }
    
    /// Get ATR value at the crosshair candle index
    private var atrValue: Double? {
        guard let manager = indicatorManager,
              let atrConfig = manager.activeIndicators.atr,
              atrConfig.isEnabled,
              let candle = candle,
              let candleIndex = chartData.candles.firstIndex(where: { $0.timestamp == candle.timestamp })
        else { return nil }
        
        if let dataPoint = manager.atrData.first(where: { $0.candleIndex == candleIndex }) {
            return dataPoint.value.isNaN ? nil : dataPoint.value
        }
        return nil
    }
    
    /// Check if any indicator values are available
    private var hasAnyIndicatorValues: Bool {
        emaValues != nil || rsiValue != nil || macdValues != nil ||
        stochasticValues != nil || cciValue != nil || williamsRValue != nil || atrValue != nil
    }
    
    var body: some View {
        Group {
            if let candle = candle {
                VStack(alignment: .leading, spacing: 2) {
                    // Time header - timeframe aware
                    Text(formatTimeForHeader(candle.timestamp))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // OHLC in ultra-compact format
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 0) {
                            PriceRow(label: "O", value: chartData.formatPrice(candle.open), color: .white)
                            PriceRow(label: "L", value: chartData.formatPrice(candle.low), color: .red)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            PriceRow(label: "H", value: chartData.formatPrice(candle.high), color: .green)
                            PriceRow(label: "C", value: chartData.formatPrice(candle.close), color: candle.isBullish ? .green : .red)
                        }
                    }
                    
                    // Volume if available - more compact
                    if let volume = candle.volume {
                        Text("V:\(volume.formattedVolume)")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    // Indicator values section - more compact
                    if hasAnyIndicatorValues {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 0.5)
                            .padding(.vertical, 1)
                        
                        // EMA values - inline format
                        if let emas = emaValues {
                            ForEach(emas, id: \.period) { ema in
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(ema.color)
                                        .frame(width: 5, height: 5)
                                    Text("\(ema.period)")
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(chartData.formatPrice(ema.value))
                                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                                        .foregroundColor(ema.color)
                                }
                            }
                        }
                        
                        // RSI value
                        if let rsi = rsiValue {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(rsiColor(for: rsi))
                                    .frame(width: 5, height: 5)
                                Text("RSI")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f", rsi))
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(rsiColor(for: rsi))
                            }
                        }
                        
                        // MACD values
                        if let macd = macdValues {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 5, height: 5)
                                Text("MACD")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.4f", macd.macd))
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        // Stochastic values
                        if let stoch = stochasticValues {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(stochColor(for: stoch.k))
                                    .frame(width: 5, height: 5)
                                Text("Stoch")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f/%.0f", stoch.k, stoch.d))
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(stochColor(for: stoch.k))
                            }
                        }
                        
                        // CCI value
                        if let cci = cciValue {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(cciColor(for: cci))
                                    .frame(width: 5, height: 5)
                                Text("CCI")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f", cci))
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(cciColor(for: cci))
                            }
                        }
                        
                        // Williams %R value
                        if let wr = williamsRValue {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(williamsRColor(for: wr))
                                    .frame(width: 5, height: 5)
                                Text("%R")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.0f", wr))
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(williamsRColor(for: wr))
                            }
                        }
                        
                        // ATR value
                        if let atr = atrValue {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 5, height: 5)
                                Text("ATR")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.4f", atr))
                                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                )
                .fixedSize()  // Prevent expansion - use intrinsic size
                .position(popupPosition)
            }
        }
    }
    
    /// Color for RSI based on value (overbought/oversold zones)
    private func rsiColor(for value: Double) -> Color {
        if value >= 70 {
            return .red  // Overbought
        } else if value <= 30 {
            return .green  // Oversold
        } else {
            return .purple  // Neutral
        }
    }
    
    /// Color for Stochastic based on value
    private func stochColor(for value: Double) -> Color {
        if value >= 80 {
            return .red  // Overbought
        } else if value <= 20 {
            return .green  // Oversold
        } else {
            return .yellow  // Neutral
        }
    }
    
    /// Color for CCI based on value
    private func cciColor(for value: Double) -> Color {
        if value >= 100 {
            return .red  // Overbought
        } else if value <= -100 {
            return .green  // Oversold
        } else {
            return .orange  // Neutral
        }
    }
    
    /// Color for Williams %R based on value (inverted scale: 0 to -100)
    private func williamsRColor(for value: Double) -> Color {
        if value >= -20 {
            return .red  // Overbought (near 0)
        } else if value <= -80 {
            return .green  // Oversold (near -100)
        } else {
            return .pink  // Neutral
        }
    }
}

// MARK: - Helper View for Price Rows

private struct PriceRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 10, alignment: .leading)
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Legacy Supporting Views (for backwards compatibility)

struct PriceLabelView: View {
    let price: Double
    var chartData: ChartDataManager? = nil
    
    var body: some View {
        Text(chartData?.formatPrice(price) ?? String(format: "%.2f", price))
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.yellow))
    }
}

struct TimeLabelView: View {
    let timestamp: Date
    
    var body: some View {
        Text(timestamp.shortTimeLabel)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.yellow))
    }
}

// MARK: - Crosshair Gesture Modifier

struct CrosshairGestureModifier: ViewModifier {
    @ObservedObject var crosshairManager: CrosshairManager
    let coordinateSystem: ChartCoordinateSystem
    let chartData: ChartDataManager
    
    func body(content: Content) -> some View {
        content
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location {
                                if !crosshairManager.isActive {
                                    crosshairManager.activate(
                                        at: location,
                                        coordinateSystem: coordinateSystem,
                                        chartData: chartData
                                    )
                                } else {
                                    crosshairManager.updatePosition(
                                        location,
                                        coordinateSystem: coordinateSystem,
                                        chartData: chartData
                                    )
                                }
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        crosshairManager.deactivate()
                    }
            )
    }
}

extension View {
    func crosshairGesture(
        crosshairManager: CrosshairManager,
        coordinateSystem: ChartCoordinateSystem,
        chartData: ChartDataManager
    ) -> some View {
        self.modifier(
            CrosshairGestureModifier(
                crosshairManager: crosshairManager,
                coordinateSystem: coordinateSystem,
                chartData: chartData
            )
        )
    }
}

// MARK: - Navigation Manager

class ChartNavigationManager: ObservableObject {
    @Published var autoScrollEnabled: Bool = true
    
    func jumpToLatest(
        gestureState: ChartGestureState,
        chartData: ChartDataManager,
        chartWidth: CGFloat,
        baseCandleWidth: CGFloat
    ) {
        let scaledWidth = baseCandleWidth * gestureState.candleWidthScale
        let totalWidth = scaledWidth + 4
        let targetOffset = CGFloat(chartData.candles.count - 1) * totalWidth - chartWidth + scaledWidth
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gestureState.panOffset.width = -targetOffset
        }
    }
    
    func jumpToCandle(
        index: Int,
        gestureState: ChartGestureState,
        chartWidth: CGFloat,
        baseCandleWidth: CGFloat
    ) {
        let scaledWidth = baseCandleWidth * gestureState.candleWidthScale
        let totalWidth = scaledWidth + 4
        let targetX = CGFloat(index) * totalWidth
        let centerOffset = chartWidth / 2 - targetX
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            gestureState.panOffset.width = centerOffset
        }
    }
}

// MARK: - Navigation Controls

struct ChartNavigationControls: View {
    @ObservedObject var navigationManager: ChartNavigationManager
    @ObservedObject var gestureState: ChartGestureState
    let chartData: ChartDataManager
    let chartWidth: CGFloat
    let baseCandleWidth: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                navigationManager.jumpToLatest(
                    gestureState: gestureState,
                    chartData: chartData,
                    chartWidth: chartWidth,
                    baseCandleWidth: baseCandleWidth
                )
            }) {
                HStack {
                    Image(systemName: "arrow.right.to.line")
                    Text("Latest")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.top, 100)
            
            ZoomControls(gestureState: gestureState)
        }
        .padding()
    }
}

// MARK: - Zoom Controls

struct ZoomControls: View {
    @ObservedObject var gestureState: ChartGestureState
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring()) {
                    gestureState.candleWidthScale = min(
                        gestureState.maxCandleScale,
                        gestureState.candleWidthScale * 1.2
                    )
                }
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 16))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                gestureState.reset()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    gestureState.candleWidthScale = max(
                        gestureState.minCandleScale,
                        gestureState.candleWidthScale / 1.2
                    )
                }
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 16))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}





