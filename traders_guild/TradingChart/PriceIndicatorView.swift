//
//  PriceIndicatorView.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/11/2025.
//

import SwiftUI

/// Price indicator that shows current price with a horizontal line
/// This provides visual feedback for the latest trading price
struct PriceIndicatorView: View {
    // MARK: - Properties
    
    /// Current price to display
    let currentPrice: Double
    
    /// Current price scale from the chart (vertical zoom level)
    let priceScale: CGFloat
    
    /// Current vertical offset from panning
    let verticalOffset: CGFloat
    
    /// Total height of the chart area
    let chartHeight: CGFloat
    
    /// Price range for calculating position
    let priceRange: (min: Double, max: Double)
    
    // MARK: - Computed Properties
    
    /// Calculate Y position for the current price indicator
    /// This ensures the indicator moves with pan and zoom
    private var indicatorYPosition: CGFloat {
        // Normalize price to 0-1 range
        let normalizedPrice = (currentPrice - priceRange.min) / (priceRange.max - priceRange.min)
        
        // Calculate Y position with scale and offset
        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
    }
    
    /// Check if the indicator is currently visible on screen
    /// Hide it when scrolled out of view for performance
    private var isVisible: Bool {
        indicatorYPosition >= 0 && indicatorYPosition <= chartHeight
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible && currentPrice > 0 {
                ZStack {
                    // Horizontal dashed line across the chart
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: indicatorYPosition))
                        path.addLine(to: CGPoint(x: geometry.size.width - 60, y: indicatorYPosition))
                    }
                    .stroke(
                        Color.yellow.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: [5, 3] // Dashed pattern: 5 points on, 3 points off
                        )
                    )
                    
                    // Price label background (yellow tag)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow)
                        .frame(width: 60, height: 24)
                        .position(
                            x: geometry.size.width - 30,
                            y: indicatorYPosition
                        )
                    
                    // Price label text
                    Text(String(format: "%.2f", currentPrice))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.black)
                        .position(
                            x: geometry.size.width - 30,
                            y: indicatorYPosition
                        )
                }
                // Smooth animation when price changes
                .animation(.easeInOut(duration: 0.2), value: indicatorYPosition)
            }
        }
        // Don't block touch events - let them pass through to the chart
        .allowsHitTesting(false)
    }
}

// MARK: - Additional Price Level Indicator

/// Represents a configurable price level to display on the chart
/// Used for support/resistance lines, stop losses, take profits, etc.
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

/// View for displaying multiple price levels on the chart
/// Can be used for technical indicators, alerts, or order levels
struct PriceLevelsView: View {
    // MARK: - Properties
    
    /// Array of price levels to display
    let priceLevels: [PriceLevel]
    
    /// Current price scale from the chart
    let priceScale: CGFloat
    
    /// Current vertical offset from the chart
    let verticalOffset: CGFloat
    
    /// Total height of the chart
    let chartHeight: CGFloat
    
    /// Price range from the chart
    let priceRange: (min: Double, max: Double)
    
    // MARK: - Helper Methods
    
    /// Calculate Y position for a given price
    private func yPosition(for price: Double) -> CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * chartHeight * priceScale) - verticalOffset
    }
    
    /// Check if a price level is visible
    private func isVisible(_ price: Double) -> Bool {
        let y = yPosition(for: price)
        return y >= 0 && y <= chartHeight
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(priceLevels) { level in
                if isVisible(level.price) {
                    let y = yPosition(for: level.price)
                    
                    // Draw the horizontal line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width - 60, y: y))
                    }
                    .stroke(level.color, style: level.lineStyle)
                    
                    // Draw label if provided
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

// MARK: - Volume Indicator (for future expansion)

/// Shows volume bars below the main chart
/// Helps traders see trading activity alongside price movement
struct VolumeIndicatorView: View {
    // MARK: - Properties
    
    /// Candles data including volume information
    let candles: [Candle]
    
    /// Horizontal offset for syncing with main chart
    let panOffset: CGSize
    
    /// Candle width for proper alignment
    let candleWidth: CGFloat
    
    /// Spacing between candles
    let candleSpacing: CGFloat
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawVolumeBars(context: context, size: size)
            }
        }
        .frame(height: 60)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Drawing Methods
    
    /// Draw volume bars synchronized with candlesticks
    private func drawVolumeBars(context: GraphicsContext, size: CGSize) {
        guard !candles.isEmpty else { return }
        
        // Find maximum volume for scaling bars
        let maxVolume = candles.compactMap { $0.volume }.max() ?? 1.0
        
        // Calculate visible range matching the main chart
        let totalWidth = candleWidth + candleSpacing
        let visibleStartIndex = max(0, Int(-panOffset.width / totalWidth))
        let visibleEndIndex = min(candles.count, visibleStartIndex + Int(size.width / totalWidth) + 2)
        
        // Draw volume bars for visible candles
        for i in visibleStartIndex..<visibleEndIndex {
            guard i < candles.count,
                  let volume = candles[i].volume else { continue }
            
            let x = CGFloat(i) * totalWidth + panOffset.width
            let barHeight = CGFloat(volume / maxVolume) * size.height * 0.8
            let candle = candles[i]
            
            // Color based on price movement
            let barColor = candle.close >= candle.open ?
                Color.green.opacity(0.5) : Color.red.opacity(0.5)
            
            // Draw volume bar
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
