//
//  PriceIndicatorView.swift
//  traders_guild
//
//  UPDATED v2 - Fixed lag between line and price label
//  The animation was causing the label to lag behind the dotted line
//  Solution: Removed animation entirely for instant real-time updates
//

import SwiftUI

enum PriceIndicatorClampMode: Equatable {
    case inline
    case clampedToTop
    case clampedToBottom
}

enum LatestCandleDirection: Equatable {
    case up
    case down

    var symbol: String {
        switch self {
        case .up:
            return "↑"
        case .down:
            return "↓"
        }
    }
}

enum PriceIndicatorTone: Equatable {
    case bullish
    case bearish

    var fillColor: Color {
        switch self {
        case .bullish:
            return AppColors.statusPositive70
        case .bearish:
            return AppColors.statusNegative70
        }
    }
}

struct PriceIndicatorLayout: Equatable {
    let mode: PriceIndicatorClampMode
    let rawY: CGFloat
    let displayY: CGFloat
    let direction: LatestCandleDirection?
    let tone: PriceIndicatorTone?

    var isInline: Bool {
        mode == .inline
    }
}

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
    let latestCandle: RLCandleDTO?
    let topExclusionHeight: CGFloat
    let bottomExclusionHeight: CGFloat
    
    // MARK: - Computed Properties

    /// Formatted price using symbol-aware formatting
    private var formattedPrice: String {
        chartData.formatPrice(currentPrice)
    }

    private var layout: PriceIndicatorLayout? {
        Self.layout(
            currentPrice: currentPrice,
            priceScale: priceScale,
            verticalOffset: verticalOffset,
            chartHeight: chartHeight,
            priceRange: priceRange,
            latestCandle: latestCandle,
            topExclusionHeight: topExclusionHeight,
            bottomExclusionHeight: bottomExclusionHeight
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            if let layout, currentPrice > 0 {
                // Use Canvas for synchronized drawing - no animation lag
                Canvas { context, size in
                    let y = layout.displayY

                    if layout.isInline {
                        // Inline: show price chip with dashed line
                        let labelWidth = ChartAxisMetrics.currentPriceChipWidth
                        let labelRect = ChartAxisMetrics.labelRect(
                            totalWidth: size.width,
                            centerY: y,
                            width: labelWidth,
                            height: ChartAxisMetrics.currentPriceChipHeight
                        )
                        let lineEndX = labelRect.maxX

                        let linePath = Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: lineEndX, y: y))
                        }
                        context.stroke(
                            linePath,
                            with: .color(AppColors.statusHighlight80),
                            style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                        )

                        let roundedPath = Path(roundedRect: labelRect, cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
                        context.fill(roundedPath, with: .color(.yellow))

                        let text = Text(formattedPrice)
                            .font(.system(size: ChartAxisMetrics.horizontalPriceFontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(.black)
                        context.draw(text, at: CGPoint(x: labelRect.midX, y: y))
                    } else {
                        // Clamped: arrow-only chip within y-axis lane
                        let chipWidth = ChartAxisMetrics.directionalArrowChipWidth
                        let chipHeight = ChartAxisMetrics.directionalArrowChipHeight
                        let chipX = size.width - ChartAxisMetrics.yAxisLaneWidth + (ChartAxisMetrics.yAxisLaneWidth - chipWidth) * 0.5
                        let chipRect = CGRect(
                            x: chipX,
                            y: y - chipHeight * 0.5,
                            width: chipWidth,
                            height: chipHeight
                        )

                        let roundedPath = Path(roundedRect: chipRect, cornerRadius: ChartAxisMetrics.horizontalPriceChipCornerRadius)
                        context.fill(roundedPath, with: .color(AppColors.statusHighlight80))

                        let arrowText = Text(layout.direction?.symbol ?? "↑")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        context.draw(arrowText, at: CGPoint(x: chipRect.midX, y: y))
                    }
                }
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
        priceRange: (min: Double, max: Double),
        latestCandle: RLCandleDTO? = nil,
        topExclusionHeight: CGFloat = 0,
        bottomExclusionHeight: CGFloat = 0
    ) {
        self.currentPrice = currentPrice
        self.priceScale = priceScale
        self.verticalOffset = verticalOffset
        self.chartHeight = chartHeight
        self.priceRange = priceRange
        self.chartData = ChartDataManager() // Fallback, will use magnitude-based formatting
        self.latestCandle = latestCandle
        self.topExclusionHeight = topExclusionHeight
        self.bottomExclusionHeight = bottomExclusionHeight
    }
}

extension PriceIndicatorView {
    static func layout(
        currentPrice: Double,
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        chartHeight: CGFloat,
        priceRange: (min: Double, max: Double),
        latestCandle: RLCandleDTO?,
        topExclusionHeight: CGFloat,
        bottomExclusionHeight: CGFloat
    ) -> PriceIndicatorLayout? {
        guard currentPrice > 0 else { return nil }
        let priceSpan = priceRange.max - priceRange.min
        guard priceSpan > 0, chartHeight > 0 else { return nil }

        let normalizedPrice = (currentPrice - priceRange.min) / priceSpan
        let rawY = chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
        let inlineChipHalf = ChartAxisMetrics.currentPriceChipHeight * 0.5
        let topLimit = max(inlineChipHalf + 4, topExclusionHeight + inlineChipHalf + 4)
        let bottomLimit = max(
            topLimit,
            chartHeight - bottomExclusionHeight - inlineChipHalf - 4
        )

        if rawY >= topLimit && rawY <= bottomLimit {
            return PriceIndicatorLayout(
                mode: .inline,
                rawY: rawY,
                displayY: rawY,
                direction: nil,
                tone: nil
            )
        }

        let mode: PriceIndicatorClampMode = rawY < topLimit ? .clampedToTop : .clampedToBottom
        let direction: LatestCandleDirection = mode == .clampedToTop ? .up : .down
        let tone: PriceIndicatorTone? = latestCandle.map {
            $0.close >= $0.open ? .bullish : .bearish
        }

        let arrowChipHalf = ChartAxisMetrics.directionalArrowChipHeight * 0.5
        let arrowTopY = max(topLimit, topExclusionHeight + arrowChipHalf + 4)
        let arrowBottomY = max(
            arrowTopY,
            chartHeight - bottomExclusionHeight - arrowChipHalf - 4
        )
        let displayY = mode == .clampedToTop ? arrowTopY : arrowBottomY

        return PriceIndicatorLayout(
            mode: mode,
            rawY: rawY,
            displayY: displayY,
            direction: direction,
            tone: tone
        )
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
                        path.addLine(to: CGPoint(x: ChartAxisMetrics.horizontalLineEndX(totalWidth: geometry.size.width), y: y))
                    }
                    .stroke(level.color, style: level.lineStyle)
                    
                    if let label = level.label {
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundColor(level.color)
                            .background(AppColors.surfaceBlack70)
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
    let candles: [RLCandleDTO]
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
        .background(AppColors.surfaceBlack80)
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
                AppColors.statusPositive50 : AppColors.statusNegative50
            
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
