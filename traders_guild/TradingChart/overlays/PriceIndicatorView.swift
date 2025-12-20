//
//  PriceIndicatorView.swift
//  traders_guild
//
//  UPDATED v2 - Fixed lag between line and price label
//  The animation was causing the label to lag behind the dotted line
//  Solution: Removed animation entirely for instant real-time updates
//

import SwiftUI

/// Price indicator that shows current price with a horizontal line
/// Now uses symbol-aware formatting for consistent decimal places
/// FIXED: No animation delay - line and label move together instantly
struct PriceIndicatorView: View {
    // MARK: - Properties
    
    let currentPrice: Double
    let priceScale: CGFloat
    let verticalOffset: CGFloat
    let chartHeight: CGFloat
    let priceRange: (min: Double, max: Double)
    
    /// Chart data manager for symbol-aware formatting
    let chartData: ChartDataManager
    
    // MARK: - Computed Properties
    
    private var indicatorYPosition: CGFloat {
        let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
    }
    
    private var isVisible: Bool {
        indicatorYPosition >= 0 && indicatorYPosition <= chartHeight
    }
    
    /// Formatted price using symbol-aware formatting
    private var formattedPrice: String {
        chartData.formatPrice(currentPrice)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible && currentPrice > 0 {
                // Use Canvas for synchronized drawing - no animation lag
                Canvas { context, size in
                    let y = indicatorYPosition
                    let lineEndX = size.width - 60
                    
                    // Draw horizontal dashed line
                    let linePath = Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: lineEndX, y: y))
                    }
                    context.stroke(
                        linePath,
                        with: .color(Color.yellow.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                    )
                    
                    // Draw price label background
                    let labelX = size.width - 35
                    let labelRect = CGRect(
                        x: labelX - 35,
                        y: y - 11,
                        width: 70,
                        height: 22
                    )
                    let roundedPath = Path(roundedRect: labelRect, cornerRadius: 4)
                    context.fill(roundedPath, with: .color(.yellow))
                    
                    // Draw price text
                    let text = Text(formattedPrice)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.black)
                    
                    context.draw(text, at: CGPoint(x: labelX, y: y))
                }
                // NO animation - this was causing the lag!
                // The line and label are now drawn in the same Canvas pass
                // so they always move together perfectly in sync
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Alternative Initializer (Backwards Compatible)

extension PriceIndicatorView {
    /// Backwards compatible initializer without chartData
    /// Uses magnitude-based formatting as fallback
    init(
        currentPrice: Double,
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        chartHeight: CGFloat,
        priceRange: (min: Double, max: Double)
    ) {
        self.currentPrice = currentPrice
        self.priceScale = priceScale
        self.verticalOffset = verticalOffset
        self.chartHeight = chartHeight
        self.priceRange = priceRange
        self.chartData = ChartDataManager() // Fallback, will use magnitude-based formatting
    }
}

// MARK: - Price Level Indicator

struct PriceLevel: Identifiable {
    let id = UUID()
    let price: Double
    let color: Color
    let label: String?
    let lineStyle: StrokeStyle
    
    init(
        price: Double,
        color: Color = .gray,
        label: String? = nil,
        lineWidth: CGFloat = 1,
        dash: [CGFloat] = []
    ) {
        self.price = price
        self.color = color
        self.label = label
        self.lineStyle = StrokeStyle(lineWidth: lineWidth, dash: dash)
    }
}

struct PriceLevelsView: View {
    let priceLevels: [PriceLevel]
    let priceScale: CGFloat
    let verticalOffset: CGFloat
    let chartHeight: CGFloat
    let priceRange: (min: Double, max: Double)
    let chartData: ChartDataManager
    
    private func yPosition(for price: Double) -> CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
    }
    
    private func isVisible(_ price: Double) -> Bool {
        let y = yPosition(for: price)
        return y >= 0 && y <= chartHeight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(priceLevels) { level in
                if isVisible(level.price) {
                    let y = yPosition(for: level.price)
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width - 60, y: y))
                    }
                    .stroke(level.color, style: level.lineStyle)
                    
                    if let label = level.label {
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundColor(level.color)
                            .background(Color.black.opacity(0.7))
                            .position(x: 30, y: y - 10)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Volume Indicator

struct VolumeIndicatorView: View {
    let candles: [CandleDTO]
    let panOffset: CGSize
    let candleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawVolumeBars(context: context, size: size)
            }
        }
        .frame(height: 60)
        .background(Color.black.opacity(0.8))
    }
    
    private func drawVolumeBars(context: GraphicsContext, size: CGSize) {
        guard !candles.isEmpty else { return }
        
        let maxVolume = candles.compactMap { $0.volume }.max() ?? 1.0
        let totalWidth = candleWidth + candleSpacing
        let visibleStartIndex = max(0, Int(-panOffset.width / totalWidth))
        let visibleEndIndex = min(candles.count, visibleStartIndex + Int(size.width / totalWidth) + 2)
        
        for i in visibleStartIndex..<visibleEndIndex {
            guard i < candles.count,
                  let volume = candles[i].volume else { continue }
            
            let x = CGFloat(i) * totalWidth + panOffset.width
            let barHeight = CGFloat(volume / maxVolume) * size.height * 0.8
            let candle = candles[i]
            
            let barColor = candle.close >= candle.open ?
                Color.green.opacity(0.5) : Color.red.opacity(0.5)
            
            let rect = CGRect(
                x: x,
                y: size.height - barHeight,
                width: candleWidth,
                height: barHeight
            )
            
            context.fill(Path(rect), with: .color(barColor))
        }
    }
}


