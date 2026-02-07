//
//  IndicatorOverlayRenderer.swift
//  traders_guild
//
//  EXPANDED VERSION - Renders all overlay indicators
//  Trend: EMA, SMA, WMA, HMA, VWAP, Parabolic SAR
//  Volatility: Bollinger Bands, Donchian Channels, Keltner Channels
//

import SwiftUI

// MARK: - Indicator Drawing Data

/// Pre-computed data for drawing indicators (avoids MainActor issues)
struct IndicatorDrawingData {
    let movingAverages: [(config: MovingAverageConfig, data: [MovingAverageDataPoint])]
    let vwap: (config: VWAPConfig, data: [VWAPDataPoint])?
    let parabolicSAR: (config: ParabolicSARConfig, data: [ParabolicSARDataPoint])?
    let bollingerBands: (config: BollingerBandsConfig, data: [BollingerBandsDataPoint])?
    let donchianChannels: (config: DonchianChannelsConfig, data: [DonchianChannelsDataPoint])?
    let keltnerChannels: (config: KeltnerChannelsConfig, data: [KeltnerChannelsDataPoint])?
    
    init(
        maConfigs: [MovingAverageConfig],
        maDataMap: [UUID: [MovingAverageDataPoint]],
        vwapConfig: VWAPConfig? = nil,
        vwapData: [VWAPDataPoint] = [],
        sarConfig: ParabolicSARConfig? = nil,
        sarData: [ParabolicSARDataPoint] = [],
        bbConfig: BollingerBandsConfig? = nil,
        bbData: [BollingerBandsDataPoint] = [],
        dcConfig: DonchianChannelsConfig? = nil,
        dcData: [DonchianChannelsDataPoint] = [],
        kcConfig: KeltnerChannelsConfig? = nil,
        kcData: [KeltnerChannelsDataPoint] = []
    ) {
        self.movingAverages = maConfigs.compactMap { config in
            guard let data = maDataMap[config.id], !data.isEmpty else { return nil }
            return (config: config, data: data)
        }
        
        if let vwapConfig = vwapConfig, vwapConfig.isEnabled, !vwapData.isEmpty {
            self.vwap = (config: vwapConfig, data: vwapData)
        } else {
            self.vwap = nil
        }
        
        if let sarConfig = sarConfig, sarConfig.isEnabled, !sarData.isEmpty {
            self.parabolicSAR = (config: sarConfig, data: sarData)
        } else {
            self.parabolicSAR = nil
        }
        
        if let bbConfig = bbConfig, bbConfig.isEnabled, !bbData.isEmpty {
            self.bollingerBands = (config: bbConfig, data: bbData)
        } else {
            self.bollingerBands = nil
        }
        
        if let dcConfig = dcConfig, dcConfig.isEnabled, !dcData.isEmpty {
            self.donchianChannels = (config: dcConfig, data: dcData)
        } else {
            self.donchianChannels = nil
        }
        
        if let kcConfig = kcConfig, kcConfig.isEnabled, !kcData.isEmpty {
            self.keltnerChannels = (config: kcConfig, data: kcData)
        } else {
            self.keltnerChannels = nil
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
        
        // Draw channel indicators first (behind everything)
        
        // Donchian Channels
        if let (dcConfig, dcData) = drawingData.donchianChannels {
            drawDonchianChannels(
                context: context, size: size, dataPoints: dcData, config: dcConfig,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset
            )
        }
        
        // Keltner Channels
        if let (kcConfig, kcData) = drawingData.keltnerChannels {
            drawKeltnerChannels(
                context: context, size: size, dataPoints: kcData, config: kcConfig,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset
            )
        }
        
        // Bollinger Bands
        if let (bbConfig, bbData) = drawingData.bollingerBands {
            drawBollingerBands(
                context: context, size: size, dataPoints: bbData, config: bbConfig,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset
            )
        }
        
        // Draw VWAP
        if let (vwapConfig, vwapData) = drawingData.vwap {
            drawVWAP(
                context: context, size: size, dataPoints: vwapData, config: vwapConfig,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset
            )
        }
        
        // Draw moving averages
        for (config, dataPoints) in drawingData.movingAverages {
            drawMovingAverage(
                context: context, size: size, dataPoints: dataPoints, config: config,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset
            )
        }
        
        // Draw Parabolic SAR on top (dots need visibility)
        if let (sarConfig, sarData) = drawingData.parabolicSAR {
            drawParabolicSAR(
                context: context, size: size, dataPoints: sarData, config: sarConfig,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset
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
        
        let (visibleStartIndex, visibleEndIndex) = visibleRange(totalOffset: totalOffset, totalCandleWidth: totalCandleWidth, chartWidth: size.width, lastIndex: dataPoints.last?.candleIndex ?? 0)
        
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
        
        let (visibleStartIndex, visibleEndIndex) = visibleRange(totalOffset: totalOffset, totalCandleWidth: totalCandleWidth, chartWidth: size.width, lastIndex: dataPoints.last?.candleIndex ?? 0)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        // Draw fill between bands if enabled
        if config.showFill {
            drawChannelFill(context: context, size: size, visiblePoints: visiblePoints,
                           upperGetter: { $0.upperBand }, lowerGetter: { $0.lowerBand },
                           fillColor: config.fillColor.color,
                           priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                           totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        }
        
        // Draw bands
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.upperBand },
                color: config.upperBandColor.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.lowerBand },
                color: config.lowerBandColor.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        
        // Middle band (dashed)
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.middleBand },
                color: config.color.color, lineWidth: config.lineWidth, dash: [4, 2],
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
    }
    
    // MARK: - Donchian Channels Drawing
    
    private static func drawDonchianChannels(
        context: GraphicsContext,
        size: CGSize,
        dataPoints: [DonchianChannelsDataPoint],
        config: DonchianChannelsConfig,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        guard dataPoints.count >= 2 else { return }
        
        let (visibleStartIndex, visibleEndIndex) = visibleRange(totalOffset: totalOffset, totalCandleWidth: totalCandleWidth, chartWidth: size.width, lastIndex: dataPoints.last?.candleIndex ?? 0)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        // Draw fill
        if config.showFill {
            drawChannelFill(context: context, size: size, visiblePoints: visiblePoints,
                           upperGetter: { $0.upperBand }, lowerGetter: { $0.lowerBand },
                           fillColor: config.fillColor.color,
                           priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                           totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        }
        
        // Draw bands
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.upperBand },
                color: config.upperBandColor.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.lowerBand },
                color: config.lowerBandColor.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        
        // Middle line (optional)
        if config.showMiddleLine {
            drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.middleLine },
                    color: config.color.color, lineWidth: config.lineWidth, dash: [4, 2],
                    priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                    totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        }
    }
    
    // MARK: - Keltner Channels Drawing
    
    private static func drawKeltnerChannels(
        context: GraphicsContext,
        size: CGSize,
        dataPoints: [KeltnerChannelsDataPoint],
        config: KeltnerChannelsConfig,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        guard dataPoints.count >= 2 else { return }
        
        let (visibleStartIndex, visibleEndIndex) = visibleRange(totalOffset: totalOffset, totalCandleWidth: totalCandleWidth, chartWidth: size.width, lastIndex: dataPoints.last?.candleIndex ?? 0)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        // Draw fill
        if config.showFill {
            drawChannelFill(context: context, size: size, visiblePoints: visiblePoints,
                           upperGetter: { $0.upperBand }, lowerGetter: { $0.lowerBand },
                           fillColor: config.fillColor.color,
                           priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                           totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        }
        
        // Draw bands
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.upperBand },
                color: config.upperBandColor.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.lowerBand },
                color: config.lowerBandColor.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
        
        // EMA (middle)
        drawLine(context: context, size: size, points: visiblePoints, valueGetter: { $0.ema },
                color: config.color.color, lineWidth: config.lineWidth,
                priceRange: priceRange, scaledHeight: scaledHeight, verticalOffset: verticalOffset,
                totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
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
        
        let (visibleStartIndex, visibleEndIndex) = visibleRange(totalOffset: totalOffset, totalCandleWidth: totalCandleWidth, chartWidth: size.width, lastIndex: dataPoints.last?.candleIndex ?? 0)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        guard visiblePoints.count >= 2 else { return }
        
        // Draw standard deviation bands if enabled
        if config.showStandardDeviationBands {
            for point in visiblePoints where point.upperBand != nil && point.lowerBand != nil {
                // We'll draw these as dashed lines
            }
            
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
    
    // MARK: - Parabolic SAR Drawing
    
    private static func drawParabolicSAR(
        context: GraphicsContext,
        size: CGSize,
        dataPoints: [ParabolicSARDataPoint],
        config: ParabolicSARConfig,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) {
        let (visibleStartIndex, visibleEndIndex) = visibleRange(totalOffset: totalOffset, totalCandleWidth: totalCandleWidth, chartWidth: size.width, lastIndex: dataPoints.last?.candleIndex ?? 0)
        
        let visiblePoints = dataPoints.filter { $0.candleIndex >= visibleStartIndex && $0.candleIndex <= visibleEndIndex }
        
        let dotRadius: CGFloat = max(2.0, actualCandleWidth * 0.15)
        
        for point in visiblePoints {
            let x = xPosition(for: point.candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            guard x >= -20 && x <= size.width + 20 else { continue }
            
            let y = yPosition(for: point.sar, priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            let color = point.isUptrend ? config.bullishColor.color : config.bearishColor.color
            
            let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            let dotPath = Path(ellipseIn: dotRect)
            
            context.fill(dotPath, with: .color(color))
        }
    }
    
    // MARK: - Generic Line Drawing Helper
    
    private static func drawLine<T>(
        context: GraphicsContext,
        size: CGSize,
        points: [T],
        valueGetter: (T) -> Double,
        color: Color,
        lineWidth: CGFloat,
        dash: [CGFloat]? = nil,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) where T: Any {
        var path = Path()
        var isFirst = true
        
        for point in points {
            let candleIndex: Int
            if let p = point as? BollingerBandsDataPoint { candleIndex = p.candleIndex }
            else if let p = point as? DonchianChannelsDataPoint { candleIndex = p.candleIndex }
            else if let p = point as? KeltnerChannelsDataPoint { candleIndex = p.candleIndex }
            else { continue }
            
            let x = xPosition(for: candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            let y = yPosition(for: valueGetter(point), priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        var style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        if let dash = dash {
            style.dash = dash
        }
        
        context.stroke(path, with: .color(color), style: style)
    }
    
    // MARK: - Generic Channel Fill Helper
    
    private static func drawChannelFill<T>(
        context: GraphicsContext,
        size: CGSize,
        visiblePoints: [T],
        upperGetter: (T) -> Double,
        lowerGetter: (T) -> Double,
        fillColor: Color,
        priceRange: (min: Double, max: Double),
        scaledHeight: CGFloat,
        verticalOffset: CGFloat,
        totalCandleWidth: CGFloat,
        actualCandleWidth: CGFloat,
        totalOffset: CGFloat
    ) where T: Any {
        var fillPath = Path()
        var upperPoints: [CGPoint] = []
        var lowerPoints: [CGPoint] = []
        
        for point in visiblePoints {
            let candleIndex: Int
            if let p = point as? BollingerBandsDataPoint { candleIndex = p.candleIndex }
            else if let p = point as? DonchianChannelsDataPoint { candleIndex = p.candleIndex }
            else if let p = point as? KeltnerChannelsDataPoint { candleIndex = p.candleIndex }
            else { continue }
            
            let x = xPosition(for: candleIndex, totalCandleWidth: totalCandleWidth, actualCandleWidth: actualCandleWidth, totalOffset: totalOffset)
            guard x >= -50 && x <= size.width + 50 else { continue }
            
            let upperY = yPosition(for: upperGetter(point), priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            let lowerY = yPosition(for: lowerGetter(point), priceRange: priceRange, scaledHeight: scaledHeight, chartHeight: size.height, verticalOffset: verticalOffset)
            
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
            
            context.fill(fillPath, with: .color(fillColor))
        }
    }
    
    // MARK: - Coordinate Helpers
    
    private static func visibleRange(totalOffset: CGFloat, totalCandleWidth: CGFloat, chartWidth: CGFloat, lastIndex: Int) -> (start: Int, end: Int) {
        let start = max(0, Int(-totalOffset / totalCandleWidth) - 5)
        let end = min(lastIndex, start + Int(chartWidth / totalCandleWidth) + 10)
        return (start, end)
    }
    
    private static func xPosition(for candleIndex: Int, totalCandleWidth: CGFloat, actualCandleWidth: CGFloat, totalOffset: CGFloat) -> CGFloat {
        CGFloat(candleIndex) * totalCandleWidth + totalOffset + actualCandleWidth / 2
    }
    
    private static func yPosition(for price: Double, priceRange: (min: Double, max: Double), scaledHeight: CGFloat, chartHeight: CGFloat, verticalOffset: CGFloat) -> CGFloat {
        let normalizedPrice = (price - priceRange.min) / (priceRange.max - priceRange.min)
        return chartHeight - (CGFloat(normalizedPrice) * scaledHeight) - verticalOffset
    }
}

