//
//  IndicatorCalculator.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/12/2025.
//

//
//  IndicatorCalculator.swift
//  traders_guild
//
//  Professional indicator calculation engine
//  Handles EMA, SMA, and RSI computations from candle data
//

import Foundation

// MARK: - Indicator Calculator

/// Efficient indicator calculation engine
/// Uses optimized algorithms for real-time updates
final class IndicatorCalculator {
    
    // MARK: - Moving Average Calculations
    
    /// Calculate Simple Moving Average (SMA)
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - period: Number of periods for the average
    ///   - priceSource: Which price to use (open, high, low, close, etc.)
    /// - Returns: Array of SMA data points (starts at index period-1)
    static func calculateSMA(
        candles: [Candle],
        period: Int,
        priceSource: PriceSource = .close
    ) -> [MovingAverageDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [MovingAverageDataPoint] = []
        var sum: Double = 0
        
        // Initial sum for first period
        for i in 0..<period {
            sum += priceSource.price(from: candles[i])
        }
        
        // First SMA value
        let firstValue = sum / Double(period)
        results.append(MovingAverageDataPoint(
            candleIndex: period - 1,
            value: firstValue,
            timestamp: candles[period - 1].timestamp
        ))
        
        // Rolling calculation for remaining values
        for i in period..<candles.count {
            sum -= priceSource.price(from: candles[i - period])
            sum += priceSource.price(from: candles[i])
            
            let sma = sum / Double(period)
            results.append(MovingAverageDataPoint(
                candleIndex: i,
                value: sma,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
    
    /// Calculate Exponential Moving Average (EMA)
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - period: Number of periods for the EMA
    ///   - priceSource: Which price to use
    /// - Returns: Array of EMA data points
    static func calculateEMA(
        candles: [Candle],
        period: Int,
        priceSource: PriceSource = .close
    ) -> [MovingAverageDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [MovingAverageDataPoint] = []
        
        // EMA multiplier: 2 / (period + 1)
        let multiplier = 2.0 / Double(period + 1)
        
        // Calculate initial SMA as seed for EMA
        var sum: Double = 0
        for i in 0..<period {
            sum += priceSource.price(from: candles[i])
        }
        var ema = sum / Double(period)
        
        // First EMA value (same as SMA for the initial point)
        results.append(MovingAverageDataPoint(
            candleIndex: period - 1,
            value: ema,
            timestamp: candles[period - 1].timestamp
        ))
        
        // Calculate EMA for remaining candles
        // EMA = (Price - Previous EMA) × Multiplier + Previous EMA
        for i in period..<candles.count {
            let price = priceSource.price(from: candles[i])
            ema = (price - ema) * multiplier + ema
            
            results.append(MovingAverageDataPoint(
                candleIndex: i,
                value: ema,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
    
    // MARK: - RSI Calculation
    
    /// Calculate Relative Strength Index (RSI)
    /// Uses Wilder's smoothing method (exponential moving average of gains/losses)
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - period: Number of periods (typically 14)
    /// - Returns: Array of RSI data points (0-100 scale)
    static func calculateRSI(
        candles: [Candle],
        period: Int = 14
    ) -> [RSIDataPoint] {
        guard candles.count > period && period > 0 else { return [] }
        
        var results: [RSIDataPoint] = []
        
        // Calculate price changes
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<candles.count {
            let change = candles[i].close - candles[i-1].close
            if change >= 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(abs(change))
            }
        }
        
        // Need at least 'period' price changes
        guard gains.count >= period else { return [] }
        
        // Calculate initial average gain and loss (first period using SMA)
        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        // First RSI value
        let firstRSI = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
        results.append(RSIDataPoint(
            candleIndex: period,  // RSI starts at candle index = period (0-based)
            value: firstRSI,
            timestamp: candles[period].timestamp
        ))
        
        // Calculate remaining RSI values using Wilder's smoothing
        // Smoothed Average = ((Previous Average × (period - 1)) + Current Value) / period
        for i in period..<gains.count {
            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
            
            let rsi = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
            results.append(RSIDataPoint(
                candleIndex: i + 1,  // +1 because gains/losses array is offset by 1
                value: rsi,
                timestamp: candles[i + 1].timestamp
            ))
        }
        
        return results
    }
    
    /// Calculate RSI value from average gain and loss
    private static func calculateRSIValue(avgGain: Double, avgLoss: Double) -> Double {
        if avgLoss == 0 {
            return avgGain == 0 ? 50 : 100  // No loss = RSI 100, no movement = RSI 50
        }
        let rs = avgGain / avgLoss
        let rsi = 100 - (100 / (1 + rs))
        return rsi.clamped(to: 0...100)
    }
    
    // MARK: - Incremental Updates (for real-time data)
    
    /// Update EMA with a new candle (efficient for live data)
    /// - Parameters:
    ///   - previousEMA: The last calculated EMA value
    ///   - newPrice: The new price to incorporate
    ///   - period: The EMA period
    /// - Returns: Updated EMA value
    static func updateEMA(previousEMA: Double, newPrice: Double, period: Int) -> Double {
        let multiplier = 2.0 / Double(period + 1)
        return (newPrice - previousEMA) * multiplier + previousEMA
    }
    
    /// Update RSI with a new candle (efficient for live data)
    /// - Parameters:
    ///   - previousAvgGain: Previous average gain
    ///   - previousAvgLoss: Previous average loss
    ///   - currentChange: Price change from last candle
    ///   - period: RSI period
    /// - Returns: Tuple of (new RSI value, new avg gain, new avg loss)
    static func updateRSI(
        previousAvgGain: Double,
        previousAvgLoss: Double,
        currentChange: Double,
        period: Int
    ) -> (rsi: Double, avgGain: Double, avgLoss: Double) {
        let currentGain = max(currentChange, 0)
        let currentLoss = abs(min(currentChange, 0))
        
        let newAvgGain = ((previousAvgGain * Double(period - 1)) + currentGain) / Double(period)
        let newAvgLoss = ((previousAvgLoss * Double(period - 1)) + currentLoss) / Double(period)
        
        let rsi = calculateRSIValue(avgGain: newAvgGain, avgLoss: newAvgLoss)
        
        return (rsi, newAvgGain, newAvgLoss)
    }
}

// MARK: - Clamped Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Batch Calculation Helper

extension IndicatorCalculator {
    
    /// Calculate all configured moving averages at once
    static func calculateAllMovingAverages(
        candles: [Candle],
        configs: [MovingAverageConfig]
    ) -> [UUID: [MovingAverageDataPoint]] {
        var results: [UUID: [MovingAverageDataPoint]] = [:]
        
        for config in configs where config.isEnabled {
            let data: [MovingAverageDataPoint]
            
            switch config.type {
            case .ema:
                data = calculateEMA(
                    candles: candles,
                    period: config.period,
                    priceSource: config.priceSource
                )
            case .sma:
                data = calculateSMA(
                    candles: candles,
                    period: config.period,
                    priceSource: config.priceSource
                )
            default:
                continue
            }
            
            results[config.id] = data
        }
        
        return results
    }
}
