//
//  ChartCoordinateSystem.swift
//  traders_guild
//

import SwiftUI

class ChartCoordinateSystem {
    let chartData: ChartDataManager
    let gestureState: ChartGestureState
    let chartSize: CGSize
    let baseCandleWidth: CGFloat
    let candleSpacing: CGFloat
    
    var dragState: CGSize = .zero
    var pinchScale: CGFloat = 1.0
    
    init(
        chartData: ChartDataManager,
        gestureState: ChartGestureState,
        chartSize: CGSize,
        baseCandleWidth: CGFloat = 12,
        candleSpacing: CGFloat = 4
    ) {
        self.chartData = chartData
        self.gestureState = gestureState
        self.chartSize = chartSize
        self.baseCandleWidth = baseCandleWidth
        self.candleSpacing = candleSpacing
    }
    
    func updateLiveState(dragState: CGSize, pinchScale: CGFloat) {
        self.dragState = dragState
        self.pinchScale = pinchScale
    }
    
    // MARK: - Candle Index to X Position
    
    func xPosition(forCandleIndex index: Int) -> CGFloat {
        let scaledWidth = baseCandleWidth * gestureState.candleWidthScale * pinchScale
        let totalWidth = scaledWidth + candleSpacing
        let totalOffset = gestureState.panOffset.width + dragState.width
        let baseX = CGFloat(index - chartData.historicalRenderIndexOffset) * totalWidth
        return baseX + totalOffset
    }
    
    func xCenterPosition(forCandleIndex index: Int) -> CGFloat {
        let x = xPosition(forCandleIndex: index)
        let scaledWidth = baseCandleWidth * gestureState.candleWidthScale * pinchScale
        return x + (scaledWidth / 2)
    }
    
    // MARK: - Price to Y Position
    
    func yPosition(forPrice price: Double) -> CGFloat {
        let priceRange = chartData.priceRange
        guard priceRange.max > priceRange.min,
              chartSize.height > 0,
              gestureState.priceScale > 0 else {
            return chartSize.height * 0.5
        }
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        let baseY = chartSize.height - (CGFloat(normalizedPrice) * chartSize.height * gestureState.priceScale)
        return baseY - gestureState.verticalPanOffset - dragState.height
    }
    
    // MARK: - Screen Position to Chart Values
    
    func candleIndex(atXPosition x: CGFloat) -> Int? {
        let totalOffset = gestureState.panOffset.width + dragState.width
        let adjustedX = x - totalOffset
        let scaledWidth = baseCandleWidth * gestureState.candleWidthScale * pinchScale
        let totalWidth = scaledWidth + candleSpacing
        guard totalWidth > 0 else { return nil }
        let index = Int(floor(adjustedX / totalWidth)) + chartData.historicalRenderIndexOffset
        guard index >= 0 && index < chartData.candles.count else { return nil }
        return index
    }
    
    func price(atYPosition y: CGFloat) -> Double {
        let priceRange = chartData.priceRange
        guard priceRange.max > priceRange.min,
              chartSize.height > 0,
              gestureState.priceScale > 0 else {
            return priceRange.min
        }
        let adjustedY = y + gestureState.verticalPanOffset + dragState.height
        let normalizedY = (chartSize.height - adjustedY) / (chartSize.height * gestureState.priceScale)
        let price = priceRange.min + (normalizedY * (priceRange.max - priceRange.min))
        return price.clamped(to: priceRange.min...priceRange.max)
    }

    /// Unclamped version — allows prices beyond the visible candle range
    /// Used by drag overlays for TP/SL/placement lines where users may want targets
    /// beyond the currently visible price range
    func unclampedPrice(atYPosition y: CGFloat) -> Double {
        let priceRange = chartData.priceRange
        guard priceRange.max > priceRange.min,
              chartSize.height > 0,
              gestureState.priceScale > 0 else {
            return max(0.0001, priceRange.min)
        }
        let adjustedY = y + gestureState.verticalPanOffset + dragState.height
        let normalizedY = (chartSize.height - adjustedY) / (chartSize.height * gestureState.priceScale)
        let price = priceRange.min + (normalizedY * (priceRange.max - priceRange.min))
        // Only enforce price > 0 (can't have negative prices)
        return max(0.0001, price)
    }
    
    // MARK: - Visibility Checks
    
    func isVisible(candleIndex: Int) -> Bool {
        let x = xPosition(forCandleIndex: candleIndex)
        let scaledWidth = baseCandleWidth * gestureState.candleWidthScale * pinchScale
        return x + scaledWidth >= 0 && x <= chartSize.width
    }
    
    func isVisible(price: Double) -> Bool {
        let y = yPosition(forPrice: price)
        return y >= 0 && y <= chartSize.height
    }
    
    func isVisible(candleIndex: Int, price: Double) -> Bool {
        return isVisible(candleIndex: candleIndex) && isVisible(price: price)
    }
    
    // MARK: - Helpers
    
    func point(candleIndex: Int, price: Double) -> CGPoint {
        CGPoint(
            x: xCenterPosition(forCandleIndex: candleIndex),
            y: yPosition(forPrice: price)
        )
    }
    
    func timestamp(forCandleIndex index: Int) -> Date? {
        guard index >= 0 && index < chartData.candles.count else { return nil }
        return chartData.candles[index].timestamp
    }
    
    func candleIndex(forTimestamp timestamp: Date) -> Int? {
        var left = 0
        var right = chartData.candles.count - 1
        var closest: Int?
        var minDiff = TimeInterval.infinity
        
        while left <= right {
            let mid = (left + right) / 2
            let candle = chartData.candles[mid]
            let diff = abs(candle.timestamp.timeIntervalSince(timestamp))
            
            if diff < minDiff {
                minDiff = diff
                closest = mid
            }
            
            if candle.timestamp < timestamp {
                left = mid + 1
            } else if candle.timestamp > timestamp {
                right = mid - 1
            } else {
                return mid
            }
        }
        return closest
    }
}
