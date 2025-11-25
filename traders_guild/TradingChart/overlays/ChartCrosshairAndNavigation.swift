////
////  ChartCrosshairAndNavigation_PERSISTENT.swift
////  traders_guild
////
////  UPDATED: Crosshair now stays visible after activation
////  - Long press activates crosshair (stays on screen)
////  - Drag ANYWHERE on chart moves the crosshair
////  - Single tap ANYWHERE dismisses crosshair
////  - Chart panning disabled while crosshair is active
////
//
//import SwiftUI
//
//// MARK: - Crosshair Manager (Persistent Mode)
//
//class CrosshairManager: ObservableObject {
//    @Published var isActive: Bool = false
//    @Published var position: CGPoint = .zero
//    @Published var targetCandle: Candle?
//    @Published var targetPrice: Double = 0
//    
//    /// Activates crosshair at the given point - crosshair stays visible until explicitly dismissed
//    func activate(at point: CGPoint, coordinateSystem: ChartCoordinateSystem, chartData: ChartDataManager) {
//        isActive = true
//        updatePosition(point, coordinateSystem: coordinateSystem, chartData: chartData)
//    }
//    
//    /// Updates crosshair position - can be called from any drag on the chart
//    func updatePosition(_ point: CGPoint, coordinateSystem: ChartCoordinateSystem, chartData: ChartDataManager) {
//        position = point
//        
//        if let candleIndex = coordinateSystem.candleIndex(atXPosition: point.x),
//           candleIndex < chartData.candles.count {
//            targetCandle = chartData.candles[candleIndex]
//        }
//        
//        targetPrice = coordinateSystem.price(atYPosition: point.y)
//    }
//    
//    /// Deactivates crosshair - called on tap to dismiss
//    func deactivate() {
//        isActive = false
//        targetCandle = nil
//        targetPrice = 0
//    }
//}
//
//// MARK: - Crosshair View (Unchanged visually)
//
//struct CrosshairView: View {
//    @ObservedObject var crosshairManager: CrosshairManager
//    let chartSize: CGSize
//    let chartData: ChartDataManager
//    
//    /// Backwards-compatible initializer
//    init(crosshairManager: CrosshairManager, chartSize: CGSize) {
//        self.crosshairManager = crosshairManager
//        self.chartSize = chartSize
//        self.chartData = ChartDataManager()
//    }
//    
//    /// Full initializer with chartData for symbol-aware formatting
//    init(crosshairManager: CrosshairManager, chartSize: CGSize, chartData: ChartDataManager) {
//        self.crosshairManager = crosshairManager
//        self.chartSize = chartSize
//        self.chartData = chartData
//    }
//    
//    var body: some View {
//        if crosshairManager.isActive {
//            ZStack {
//                // Vertical line
//                Path { path in
//                    path.move(to: CGPoint(x: crosshairManager.position.x, y: 0))
//                    path.addLine(to: CGPoint(x: crosshairManager.position.x, y: chartSize.height))
//                }
//                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
//                
//                // Horizontal line
//                Path { path in
//                    path.move(to: CGPoint(x: 0, y: crosshairManager.position.y))
//                    path.addLine(to: CGPoint(x: chartSize.width, y: crosshairManager.position.y))
//                }
//                .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
//                
//                // Center dot
//                Circle()
//                    .fill(Color.white)
//                    .frame(width: 6, height: 6)
//                    .position(crosshairManager.position)
//                
//                // Price label on Y-axis
//                CrosshairPriceLabel(
//                    price: crosshairManager.targetPrice,
//                    chartData: chartData
//                )
//                .position(x: chartSize.width - 35, y: crosshairManager.position.y)
//                
//                // Time label on X-axis
//                if let candle = crosshairManager.targetCandle {
//                    CrosshairTimeLabel(timestamp: candle.timestamp)
//                        .position(x: crosshairManager.position.x, y: chartSize.height - 12)
//                }
//                
//                // Compact info popup
//                CrosshairInfoPopupCompact(
//                    candle: crosshairManager.targetCandle,
//                    price: crosshairManager.targetPrice,
//                    position: crosshairManager.position,
//                    chartSize: chartSize,
//                    chartData: chartData
//                )
//            }
//            .allowsHitTesting(false)
//        }
//    }
//}
//
//// MARK: - Crosshair Price Label
//
//struct CrosshairPriceLabel: View {
//    let price: Double
//    let chartData: ChartDataManager
//    
//    var body: some View {
//        Text(chartData.formatPrice(price))
//            .font(.system(size: 9, weight: .medium, design: .monospaced))
//            .foregroundColor(.black)
//            .padding(.horizontal, 4)
//            .padding(.vertical, 2)
//            .background(
//                RoundedRectangle(cornerRadius: 3)
//                    .fill(Color.white.opacity(0.9))
//            )
//    }
//}
//
//// MARK: - Crosshair Time Label
//
//struct CrosshairTimeLabel: View {
//    let timestamp: Date
//    
//    var body: some View {
//        Text(timestamp.shortTimeLabel)
//            .font(.system(size: 9, weight: .medium, design: .monospaced))
//            .foregroundColor(.black)
//            .padding(.horizontal, 4)
//            .padding(.vertical, 2)
//            .background(
//                RoundedRectangle(cornerRadius: 3)
//                    .fill(Color.white.opacity(0.9))
//            )
//    }
//}
//
//// MARK: - Compact Crosshair Info Popup
//
//struct CrosshairInfoPopupCompact: View {
//    let candle: Candle?
//    let price: Double
//    let position: CGPoint
//    let chartSize: CGSize
//    let chartData: ChartDataManager
//    
//    private var popupPosition: CGPoint {
//        var x = position.x + 60
//        var y = position.y - 50
//        
//        if x > chartSize.width - 100 {
//            x = position.x - 60
//        }
//        if y < 40 {
//            y = position.y + 50
//        }
//        if y > chartSize.height - 80 {
//            y = chartSize.height - 80
//        }
//        
//        return CGPoint(x: x, y: y)
//    }
//    
//    var body: some View {
//        Group {
//            if let candle = candle {
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(candle.timestamp.chartTimeLabel)
//                        .font(.system(size: 9, weight: .semibold))
//                        .foregroundColor(.white.opacity(0.7))
//                    
//                    HStack(spacing: 8) {
//                        VStack(alignment: .leading, spacing: 1) {
//                            PriceRow(label: "O", value: chartData.formatPrice(candle.open), color: .white)
//                            PriceRow(label: "L", value: chartData.formatPrice(candle.low), color: .red)
//                        }
//                        VStack(alignment: .leading, spacing: 1) {
//                            PriceRow(label: "H", value: chartData.formatPrice(candle.high), color: .green)
//                            PriceRow(label: "C", value: chartData.formatPrice(candle.close), color: candle.isBullish ? .green : .red)
//                        }
//                    }
//                    
//                    if let volume = candle.volume {
//                        Text("Vol: \(volume.formattedVolume)")
//                            .font(.system(size: 8))
//                            .foregroundColor(.white.opacity(0.6))
//                    }
//                }
//                .padding(6)
//                .background(
//                    RoundedRectangle(cornerRadius: 6)
//                        .fill(Color.black.opacity(0.75))
//                )
//                .position(popupPosition)
//            }
//        }
//    }
//}
//
//// MARK: - Price Row Helper
//
//struct PriceRow: View {
//    let label: String
//    let value: String
//    let color: Color
//    
//    var body: some View {
//        HStack(spacing: 2) {
//            Text(label)
//                .font(.system(size: 8, weight: .medium))
//                .foregroundColor(.white.opacity(0.5))
//            Text(value)
//                .font(.system(size: 8, weight: .medium, design: .monospaced))
//                .foregroundColor(color)
//        }
//    }
//}
//
//// MARK: - Date Extensions
//
//extension Date {
//    var shortTimeLabel: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm"
//        return formatter.string(from: self)
//    }
//    
//    var chartTimeLabel: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "dd MMM HH:mm"
//        return formatter.string(from: self)
//    }
//}
//
//// MARK: - Volume Formatting
//
//extension Double {
//    var formattedVolume: String {
//        if self >= 1_000_000_000 {
//            return String(format: "%.1fB", self / 1_000_000_000)
//        } else if self >= 1_000_000 {
//            return String(format: "%.1fM", self / 1_000_000)
//        } else if self >= 1_000 {
//            return String(format: "%.1fK", self / 1_000)
//        } else {
//            return String(format: "%.0f", self)
//        }
//    }
//}






















//
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
    @Published var targetCandle: Candle?
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
                
                // Time label on X-axis
                if let candle = crosshairManager.targetCandle {
                    CrosshairTimeLabel(timestamp: candle.timestamp)
                        .position(x: crosshairManager.position.x, y: chartSize.height - 12)
                }
                
                // Compact info popup
                CrosshairInfoPopupCompact(
                    candle: crosshairManager.targetCandle,
                    price: crosshairManager.targetPrice,
                    position: crosshairManager.position,
                    chartSize: chartSize,
                    chartData: chartData
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
        Text(chartData.formatPrice(price))
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.9))
            )
    }
}

// MARK: - Crosshair Time Label

struct CrosshairTimeLabel: View {
    let timestamp: Date
    
    var body: some View {
        Text(timestamp.shortTimeLabel)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.9))
            )
    }
}

// MARK: - Compact Crosshair Info Popup (Subtle Design)

struct CrosshairInfoPopupCompact: View {
    let candle: Candle?
    let price: Double
    let position: CGPoint
    let chartSize: CGSize
    let chartData: ChartDataManager
    
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
    
    var body: some View {
        Group {
            if let candle = candle {
                VStack(alignment: .leading, spacing: 2) {
                    // Time header
                    Text(candle.timestamp.chartTimeLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // OHLC in compact format
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            PriceRow(label: "O", value: chartData.formatPrice(candle.open), color: .white)
                            PriceRow(label: "L", value: chartData.formatPrice(candle.low), color: .red)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            PriceRow(label: "H", value: chartData.formatPrice(candle.high), color: .green)
                            PriceRow(label: "C", value: chartData.formatPrice(candle.close), color: candle.isBullish ? .green : .red)
                        }
                    }
                    
                    // Volume if available
                    if let volume = candle.volume {
                        Text("Vol: \(volume.formattedVolume)")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                )
                .position(popupPosition)
            }
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
                LongPressGesture(minimumDuration: 0.5)
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
