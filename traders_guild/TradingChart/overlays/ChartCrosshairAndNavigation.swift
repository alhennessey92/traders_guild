//
//  ChartCrosshairAndNavigation.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/11/2025.
//

//
//  ChartCrosshairAndNavigation.swift
//  traders_guild
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

// MARK: - Crosshair View

struct CrosshairView: View {
    @ObservedObject var crosshairManager: CrosshairManager
    let chartSize: CGSize
    
    var body: some View {
        if crosshairManager.isActive {
            ZStack {
                // Vertical line
                Path { path in
                    path.move(to: CGPoint(x: crosshairManager.position.x, y: 0))
                    path.addLine(to: CGPoint(x: crosshairManager.position.x, y: chartSize.height))
                }
                .stroke(Color.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                
                // Horizontal line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: crosshairManager.position.y))
                    path.addLine(to: CGPoint(x: chartSize.width, y: crosshairManager.position.y))
                }
                .stroke(Color.yellow.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                
                // Center circle
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                    .position(crosshairManager.position)
                
                // Price label
                PriceLabelView(price: crosshairManager.targetPrice)
                    .position(x: chartSize.width - 30, y: crosshairManager.position.y)
                
                // Time label
                if let candle = crosshairManager.targetCandle {
                    TimeLabelView(timestamp: candle.timestamp)
                        .position(x: crosshairManager.position.x, y: chartSize.height - 10)
                }
                
                // Info popup
                CrosshairInfoPopup(
                    candle: crosshairManager.targetCandle,
                    price: crosshairManager.targetPrice,
                    position: crosshairManager.position,
                    chartSize: chartSize
                )
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Crosshair Info Popup

struct CrosshairInfoPopup: View {
    let candle: Candle?
    let price: Double
    let position: CGPoint
    let chartSize: CGSize
    
    private var popupPosition: CGPoint {
        var x = position.x + 80
        var y = position.y - 60
        
        if x > chartSize.width - 160 {
            x = position.x - 80
        }
        if y < 60 {
            y = 60
        }
        if y > chartSize.height - 100 {
            y = chartSize.height - 100
        }
        
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let candle = candle {
                Text(candle.timestamp.chartTimeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Divider()
                
                HStack {
                    Text("O:")
                    Spacer()
                    Text(candle.open.formattedPrice)
                }
                HStack {
                    Text("H:")
                    Spacer()
                    Text(candle.high.formattedPrice)
                        .foregroundColor(.green)
                }
                HStack {
                    Text("L:")
                    Spacer()
                    Text(candle.low.formattedPrice)
                        .foregroundColor(.red)
                }
                HStack {
                    Text("C:")
                    Spacer()
                    Text(candle.close.formattedPrice)
                        .fontWeight(.semibold)
                        .foregroundColor(candle.isBullish ? .green : .red)
                }
                
                if let volume = candle.volume {
                    Divider()
                    HStack {
                        Text("Vol:")
                        Spacer()
                        Text(volume.formattedVolume)
                    }
                }
            } else {
                Text("Price: \(price.formattedPrice)")
                    .font(.caption)
            }
        }
        .font(.caption)
        .foregroundColor(.white)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                )
        )
        .position(popupPosition)
    }
}

// MARK: - Supporting Views

struct PriceLabelView: View {
    let price: Double
    
    var body: some View {
        Text(price.formattedPrice)
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

// MARK: - Crosshair Gesture

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
            // Jump to latest
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
            
            // Zoom controls
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
            // Zoom in
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
            
            // Reset
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
            
            // Zoom out
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
