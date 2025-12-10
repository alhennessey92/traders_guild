//
//  IndicatorOverlayRenderer.swift
//  traders_guild
//
//  EXPANDED VERSION - Renders EMA, SMA, Bollinger Bands, and VWAP
//  Designed to integrate with TradingChartView canvas drawing
//

import SwiftUI

// MARK: - Indicator Drawing Data

/// Pre-computed data for drawing indicators (avoids MainActor issues)
struct IndicatorDrawingData {
    let movingAverages: [(config: MovingAverageConfig, data: [MovingAverageDataPoint])]
    let bollingerBands: (config: BollingerBandsConfig, data: [BollingerBandsDataPoint])?
    let vwap: (config: VWAPConfig, data: [VWAPDataPoint])?
    
    init(
        maConfigs: [MovingAverageConfig],
        maDataMap: [UUID: [MovingAverageDataPoint]],
        bbConfig: BollingerBandsConfig? = nil,
        bbData: [BollingerBandsDataPoint] = [],
        vwapConfig: VWAPConfig? = nil,
        vwapData: [VWAPDataPoint] = []
    ) {
        self.movingAverages = maConfigs.compactMap { config in
            guard let data = maDataMap[config.id], !data.isEmpty else { return nil }
            return (config: config, data: data)
        }
        
        if let bbConfig = bbConfig, bbConfig.isEnabled, !bbData.isEmpty {
            self.bollingerBands = (config: bbConfig, data: bbData)
        } else {
            self.bollingerBands = nil
        }
        
        if let vwapConfig = vwapConfig, vwapConfig.isEnabled, !vwapData.isEmpty {
            self.vwap = (config: vwapConfig, data: vwapData)
        } else {
            self.vwap = nil
        }
    }
    
    static let empty = IndicatorDrawingData(maConfigs: [], maDataMap: [:])
}

// MARK: - Indicator Overlay Renderer

struct IndicatorOverlayRenderer {
    
    // MARK: - Main Drawing Entry Point
    
    static func drawOverlayIndicators(
        context: GraphicsContext,
        size: CGSize,
        drawingData: IndicatorDrawingData,
        priceRange: (min: Double, max: Double),
        priceScale: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        let scaledHeight = size.height * priceScale
        
        // Draw Bollinger Bands first (behind other indicators)
        if let (bbConfig, bbData) = drawingData.bollingerBands {
            drawBollingerBands(
                context: context,
                size: size,
                dataPoints: bbData,
                config: bbConfig,
                priceRange: priceRange,
                scaledHeight: scaledHeight,
                verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                totalOffset: totalOffset
            )
        }
        
        // Draw VWAP
        if let (vwapConfig, vwapData) = drawingData.vwap {
            drawVWAP(
                context: context,
                size: size,
                dataPoints: vwapData,
                config: vwapConfig,
                priceRange: priceRange,
                scaledHeight: scaledHeight,
                verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                totalOffset: totalOffset
            )
        }
        
        // Draw moving averages on top
        for (config, dataPoints) in drawingData.movingAverages {
            drawMovingAverage(
                context: context,
                size: size,
                dataPoints: dataPoints,
                config: config,
                priceRange: priceRange,
                scaledHeight: scaledHeight,
                verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: actualCandleWidth,
                totalOffset: totalOffset
            )
        }
    }
    
    // MARK: - Moving Average Drawing
    
    private static func drawMovingAverage(
        context: GraphicsContext,
        size: CGSize,
        dataPoints: [MovingAverageDataPoint],
        config: MovingAverageConfig,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(
            dataPoints.last?.candleIndex ?? 0,
            visibleStartIndex + Int(size.width / totalCandleWidth) + 10
        )
        
        let visiblePoints = dataPoints.filter { point in
            point.candleIndex >= visibleStartIndex && point.candleIndex <= visibleEndIndex
        }
        
        guard visiblePoints.count >= 2 else { return }
        
        var path = Path()
        var isFirstPoint = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            let y = yPosition(for: point.value, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(config.color.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Bollinger Bands Drawing
    
    private static func drawBollingerBands(
        context: GraphicsContext,
        size: CGSize,
        dataPoints: [BollingerBandsDataPoint],
        config: BollingerBandsConfig,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(
            dataPoints.last?.candleIndex ?? 0,
            visibleStartIndex + Int(size.width / totalCandleWidth) + 10
        )
        
        let visiblePoints = dataPoints.filter { point in
            point.candleIndex >= visibleStartIndex && point.candleIndex <= visibleEndIndex
        }
        
        guard visiblePoints.count >= 2 else { return }
        
        // Draw fill between bands if enabled
        if config.showFill {
            var fillPath = Path()
            var upperPoints: [CGPoint] = []
            var lowerPoints: [CGPoint] = []
            
            for point in visiblePoints {
                let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
                guard x >= -50 && x <= size.width + 50 else { continue }
                
                let upperY = yPosition(for: point.upperBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
                let lowerY = yPosition(for: point.lowerBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
                
                upperPoints.append(CGPoint(x: x, y: upperY))
                lowerPoints.append(CGPoint(x: x, y: lowerY))
            }
            
            if !upperPoints.isEmpty {
                fillPath.move(to: upperPoints[0])
                for point in upperPoints.dropFirst() {
                    fillPath.addLine(to: point)
                }
                for point in lowerPoints.reversed() {
                    fillPath.addLine(to: point)
                }
                fillPath.closeSubpath()
                
                context.fill(fillPath, with: .color(config.fillColor.color))
            }
        }
        
        // Draw upper band
        var upperPath = Path()
        var isFirst = true
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            guard x >= -50 && x <= size.width + 50 else { continue }
            let y = yPosition(for: point.upperBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            if isFirst {
                upperPath.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                upperPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(upperPath, with: .color(config.upperBandColor.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
        
        // Draw lower band
        var lowerPath = Path()
        isFirst = true
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            guard x >= -50 && x <= size.width + 50 else { continue }
            let y = yPosition(for: point.lowerBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            if isFirst {
                lowerPath.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                lowerPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(lowerPath, with: .color(config.lowerBandColor.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
        
        // Draw middle band (SMA)
        var middlePath = Path()
        isFirst = true
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            guard x >= -50 && x <= size.width + 50 else { continue }
            let y = yPosition(for: point.middleBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            if isFirst {
                middlePath.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                middlePath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(middlePath, with: .color(config.color.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round, dash: [4, 2]))
    }
    
    // MARK: - VWAP Drawing
    
    private static func drawVWAP(
        context: GraphicsContext,
        size: CGSize,
        dataPoints: [VWAPDataPoint],
        config: VWAPConfig,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        guard dataPoints.count >= 2 else { return }
        
        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let visibleEndIndex = min(
            dataPoints.last?.candleIndex ?? 0,
            visibleStartIndex + Int(size.width / totalCandleWidth) + 10
        )
        
        let visiblePoints = dataPoints.filter { point in
            point.candleIndex >= visibleStartIndex && point.candleIndex <= visibleEndIndex
        }
        
        guard visiblePoints.count >= 2 else { return }
        
        // Draw standard deviation bands if enabled
        if config.showStandardDeviationBands {
            // Upper band
            var upperPath = Path()
            var isFirst = true
            for point in visiblePoints {
                guard let upperBand = point.upperBand else { continue }
                let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
                guard x >= -50 && x <= size.width + 50 else { continue }
                let y = yPosition(for: upperBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
                
                if isFirst {
                    upperPath.move(to: CGPoint(x: x, y: y))
                    isFirst = false
                } else {
                    upperPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(upperPath, with: .color(config.upperBandColor.color), style: StrokeStyle(lineWidth: config.lineWidth * 0.7, lineCap: .round, lineJoin: .round, dash: [3, 3]))
            
            // Lower band
            var lowerPath = Path()
            isFirst = true
            for point in visiblePoints {
                guard let lowerBand = point.lowerBand else { continue }
                let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
                guard x >= -50 && x <= size.width + 50 else { continue }
                let y = yPosition(for: lowerBand, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
                
                if isFirst {
                    lowerPath.move(to: CGPoint(x: x, y: y))
                    isFirst = false
                } else {
                    lowerPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(lowerPath, with: .color(config.lowerBandColor.color), style: StrokeStyle(lineWidth: config.lineWidth * 0.7, lineCap: .round, lineJoin: .round, dash: [3, 3]))
        }
        
        // Draw main VWAP line
        var path = Path()
        var isFirstPoint = true
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            let y = yPosition(for: point.vwap, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(config.color.color), style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Coordinate Helpers
    
    private static func xPosition(for candleIndex: Int, totalCandleWidth: CGFloat, actualCandleWidth: CGFloat, totalOffset: CGFloat) -> CGFloat {
        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
    }
    
    private static func yPosition(for price: Double, priceRange: (min: Double, max: Double), scaledHeight: CGFloat, chartHeight: CGFloat, verticalOffset: CGFloat) -> CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * scaledHeight) - verticalOffset
    }
}

















////
////  IndicatorOverlayRenderer.swift
////  traders_guild
////
////  Renders overlay indicators (EMA, SMA) directly on the chart canvas
////  Designed to integrate with the existing TradingChartView canvas drawing
////
////  NOTE: This renderer uses pre-computed data passed as parameters to avoid
////  MainActor isolation issues when called from Canvas drawing contexts.
////
//
//import SwiftUI
//
//// MARK: - Indicator Drawing Data
//
///// Pre-computed data for drawing indicators (avoids MainActor issues)
///// Create this on the main thread before passing to Canvas
//struct IndicatorDrawingData {
//    let movingAverages: [(config: MovingAverageConfig, data: [MovingAverageDataPoint])]
//    
//    init(configs: [MovingAverageConfig], dataMap: [UUID: [MovingAverageDataPoint]]) {
//        self.movingAverages = configs.compactMap { config in
//            guard let data = dataMap[config.id], !data.isEmpty else { return nil }
//            return (config: config, data: data)
//        }
//    }
//    
//    static let empty = IndicatorDrawingData(configs: [], dataMap: [:])
//}
//
//// MARK: - Indicator Overlay Renderer
//
///// Static methods for rendering indicator overlays on the chart canvas
///// Call these from within the TradingChartView's Canvas drawing context
//struct IndicatorOverlayRenderer {
//    
//    // MARK: - Main Drawing Entry Point
//    
//    /// Draw all active overlay indicators on the chart
//    /// - Parameters:
//    ///   - context: The graphics context from Canvas
//    ///   - size: The canvas size
//    ///   - drawingData: Pre-computed indicator data (create on main thread)
//    ///   - priceRange: The chart's price range
//    ///   - priceScale: Current vertical zoom scale
//    ///   - verticalOffset: Current vertical pan offset
//    ///   - totalCandleWidth: Width of each candle including spacing
//    ///   - actualCandleWidth: Actual candle width without spacing
//    ///   - totalOffset: Current horizontal pan offset
//    static func drawOverlayIndicators(
//        context: GraphicsContext,
//        size: CGSize,
//        drawingData: IndicatorDrawingData,
//        priceRange: (min: Double, max: Double),
//        priceScale: CGFloat,
//        verticalOffset: CGFloat,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat
//    ) {
//        let scaledHeight = size.height * priceScale
//        
//        // Draw each enabled moving average
//        for (config, dataPoints) in drawingData.movingAverages {
//            drawMovingAverage(
//                context: context,
//                size: size,
//                dataPoints: dataPoints,
//                config: config,
//                priceRange: priceRange,
//                scaledHeight: scaledHeight,
//                verticalOffset: verticalOffset,
//                totalCandleWidth: totalCandleWidth,
//                actualCandleWidth: actualCandleWidth,
//                totalOffset: totalOffset
//            )
//        }
//    }
//    
//    // MARK: - Moving Average Drawing
//    
//    /// Draw a single moving average line
//    private static func drawMovingAverage(
//        context: GraphicsContext,
//        size: CGSize,
//        dataPoints: [MovingAverageDataPoint],
//        config: MovingAverageConfig,
//        priceRange: (min: Double, max: Double),
//        scaledHeight: CGFloat,
//        verticalOffset: CGFloat,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat
//    ) {
//        guard dataPoints.count >= 2 else { return }
//        
//        // Calculate visible range for optimization
//        let visibleStartIndex = max(0, Int(-totalOffset / totalCandleWidth) - 5)
//        let visibleEndIndex = min(
//            dataPoints.last?.candleIndex ?? 0,
//            visibleStartIndex + Int(size.width / totalCandleWidth) + 10
//        )
//        
//        // Filter to visible data points
//        let visiblePoints = dataPoints.filter { point in
//            point.candleIndex >= visibleStartIndex && point.candleIndex <= visibleEndIndex
//        }
//        
//        guard visiblePoints.count >= 2 else { return }
//        
//        // Build the path
//        var path = Path()
//        var isFirstPoint = true
//        
//        for point in visiblePoints {
//            let x = xPosition(
//                for: point.candleIndex,
//                totalCandleWidth: totalCandleWidth,
//                actualCandleWidth: actualCandleWidth,
//                totalOffset: totalOffset
//            )
//            
//            let y = yPosition(
//                for: point.value,
//                priceRange: priceRange,
//                scaledHeight: scaledHeight,
//                chartHeight: size.height,
//                verticalOffset: verticalOffset
//            )
//            
//            // Skip points outside visible area
//            guard x >= -50 && x <= size.width + 50 else { continue }
//            
//            if isFirstPoint {
//                path.move(to: CGPoint(x: x, y: y))
//                isFirstPoint = false
//            } else {
//                path.addLine(to: CGPoint(x: x, y: y))
//            }
//        }
//        
//        // Draw the line
//        context.stroke(
//            path,
//            with: .color(config.color.color),
//            style: StrokeStyle(
//                lineWidth: config.lineWidth,
//                lineCap: .round,
//                lineJoin: .round
//            )
//        )
//    }
//    
//    // MARK: - Coordinate Helpers
//    
//    /// Calculate X position for a candle index
//    private static func xPosition(
//        for candleIndex: Int,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat
//    ) -> CGFloat {
//        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
//    }
//    
//    /// Calculate Y position for a price value
//    private static func yPosition(
//        for price: Double,
//        priceRange: (min: Double, max: Double),
//        scaledHeight: CGFloat,
//        chartHeight: CGFloat,
//        verticalOffset: CGFloat
//    ) -> CGFloat {
//        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
//        return chartHeight - (CGFloat(normalizedPrice) * scaledHeight) - verticalOffset
//    }
//    
//    // MARK: - Label Drawing (Optional)
//    
//    /// Draw indicator labels on the right edge of visible lines
//    static func drawIndicatorLabels(
//        context: GraphicsContext,
//        size: CGSize,
//        drawingData: IndicatorDrawingData,
//        priceRange: (min: Double, max: Double),
//        priceScale: CGFloat,
//        verticalOffset: CGFloat,
//        yAxisWidth: CGFloat = 60
//    ) {
//        let scaledHeight = size.height * priceScale
//        let labelX = size.width - yAxisWidth - 8
//        
//        // Draw labels for each MA at its current value
//        for (config, dataPoints) in drawingData.movingAverages {
//            guard let lastPoint = dataPoints.last else { continue }
//            
//            let y = yPosition(
//                for: lastPoint.value,
//                priceRange: priceRange,
//                scaledHeight: scaledHeight,
//                chartHeight: size.height,
//                verticalOffset: verticalOffset
//            )
//            
//            // Only draw if visible
//            guard y >= 10 && y <= size.height - 10 else { continue }
//            
//            // Draw label background
//            let labelWidth: CGFloat = 50
//            let labelHeight: CGFloat = 16
//            let labelRect = CGRect(
//                x: labelX - labelWidth,
//                y: y - labelHeight / 2,
//                width: labelWidth,
//                height: labelHeight
//            )
//            
//            let bgPath = Path(roundedRect: labelRect, cornerRadius: 3)
//            context.fill(bgPath, with: .color(config.color.color.opacity(0.8)))
//            
//            // Draw label text
//            let labelText = Text(config.label)
//                .font(.system(size: 9, weight: .semibold))
//                .foregroundColor(.white)
//            
//            context.draw(labelText, at: CGPoint(x: labelX - labelWidth / 2, y: y))
//        }
//    }
//}
//
//// MARK: - Smooth Line Drawing (Alternative)
//
//extension IndicatorOverlayRenderer {
//    
//    /// Draw a smoother moving average using quadratic curves
//    /// Use this for a more polished look at the cost of slight performance
//    static func drawSmoothMovingAverage(
//        context: GraphicsContext,
//        size: CGSize,
//        dataPoints: [MovingAverageDataPoint],
//        config: MovingAverageConfig,
//        priceRange: (min: Double, max: Double),
//        scaledHeight: CGFloat,
//        verticalOffset: CGFloat,
//        totalCandleWidth: CGFloat,
//        actualCandleWidth: CGFloat,
//        totalOffset: CGFloat
//    ) {
//        guard dataPoints.count >= 3 else { return }
//        
//        // Convert to screen points
//        var screenPoints: [CGPoint] = []
//        
//        for point in dataPoints {
//            let x = xPosition(
//                for: point.candleIndex,
//                totalCandleWidth: totalCandleWidth,
//                actualCandleWidth: actualCandleWidth,
//                totalOffset: totalOffset
//            )
//            
//            let y = yPosition(
//                for: point.value,
//                priceRange: priceRange,
//                scaledHeight: scaledHeight,
//                chartHeight: size.height,
//                verticalOffset: verticalOffset
//            )
//            
//            // Only include visible points (with buffer)
//            if x >= -100 && x <= size.width + 100 {
//                screenPoints.append(CGPoint(x: x, y: y))
//            }
//        }
//        
//        guard screenPoints.count >= 3 else { return }
//        
//        // Build smooth path using Catmull-Rom spline approximation
//        var path = Path()
//        path.move(to: screenPoints[0])
//        
//        for i in 1..<screenPoints.count - 1 {
//            let p0 = i > 0 ? screenPoints[i - 1] : screenPoints[i]
//            let p1 = screenPoints[i]
//            let p2 = screenPoints[i + 1]
//            
//            // Control point for smoothing
//            let controlX = (p0.x + p2.x) / 2
//            let controlY = (p0.y + p2.y) / 2
//            
//            // Blend between linear and curved
//            let midX = (p1.x + controlX) / 2
//            let midY = (p1.y + controlY) / 2
//            
//            path.addQuadCurve(to: p1, control: CGPoint(x: midX, y: midY))
//        }
//        
//        // Add last point
//        if let last = screenPoints.last {
//            path.addLine(to: last)
//        }
//        
//        context.stroke(
//            path,
//            with: .color(config.color.color),
//            style: StrokeStyle(
//                lineWidth: config.lineWidth,
//                lineCap: .round,
//                lineJoin: .round
//            )
//        )
//    }
//}
