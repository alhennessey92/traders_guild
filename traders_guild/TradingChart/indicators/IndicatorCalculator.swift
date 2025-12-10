//
//  IndicatorCalculator.swift
//  traders_guild
//
//  EXPANDED VERSION - Adds MACD and Stochastic calculations
//

import Foundation

// MARK: - Indicator Calculator

final class IndicatorCalculator {
    
    // MARK: - Simple Moving Average (SMA)
    
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
    
    // MARK: - Exponential Moving Average (EMA)
    
    static func calculateEMA(
        candles: [Candle],
        period: Int,
        priceSource: PriceSource = .close
    ) -> [MovingAverageDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [MovingAverageDataPoint] = []
        let multiplier = 2.0 / Double(period + 1)
        
        // Calculate initial SMA as seed for EMA
        var sum: Double = 0
        for i in 0..<period {
            sum += priceSource.price(from: candles[i])
        }
        var ema = sum / Double(period)
        
        // First EMA value
        results.append(MovingAverageDataPoint(
            candleIndex: period - 1,
            value: ema,
            timestamp: candles[period - 1].timestamp
        ))
        
        // Calculate EMA for remaining candles
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
    
    static func calculateRSI(
        candles: [Candle],
        period: Int = 14
    ) -> [RSIDataPoint] {
        guard candles.count > period && period > 0 else { return [] }
        
        var results: [RSIDataPoint] = []
        var gains: [Double] = []
        var losses: [Double] = []
        
        // Calculate price changes
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
        
        guard gains.count >= period else { return [] }
        
        // Calculate initial average gain and loss
        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        // First RSI value
        let firstRSI = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
        results.append(RSIDataPoint(
            candleIndex: period,
            value: firstRSI,
            timestamp: candles[period].timestamp
        ))
        
        // Calculate remaining RSI values using Wilder's smoothing
        for i in period..<gains.count {
            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
            
            let rsi = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
            results.append(RSIDataPoint(
                candleIndex: i + 1,
                value: rsi,
                timestamp: candles[i + 1].timestamp
            ))
        }
        
        return results
    }
    
    private static func calculateRSIValue(avgGain: Double, avgLoss: Double) -> Double {
        if avgLoss == 0 {
            return avgGain == 0 ? 50 : 100
        }
        let rs = avgGain / avgLoss
        let rsi = 100 - (100 / (1 + rs))
        return rsi.clamped(to: 0...100)
    }
    
    // MARK: - MACD Calculation
    
    /// Calculate MACD indicator
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - fastPeriod: Fast EMA period (default 12)
    ///   - slowPeriod: Slow EMA period (default 26)
    ///   - signalPeriod: Signal line EMA period (default 9)
    /// - Returns: Array of MACD data points
    static func calculateMACD(
        candles: [Candle],
        fastPeriod: Int = 12,
        slowPeriod: Int = 26,
        signalPeriod: Int = 9
    ) -> [MACDDataPoint] {
        // Need enough candles for slow EMA + signal period
        let minCandles = slowPeriod + signalPeriod
        guard candles.count >= minCandles else { return [] }
        
        // Calculate fast and slow EMAs
        let fastEMA = calculateEMAValues(candles: candles, period: fastPeriod)
        let slowEMA = calculateEMAValues(candles: candles, period: slowPeriod)
        
        guard !fastEMA.isEmpty && !slowEMA.isEmpty else { return [] }
        
        // Calculate MACD line (fast EMA - slow EMA)
        // MACD starts at slowPeriod - 1 (where slow EMA starts)
        var macdValues: [(index: Int, value: Double, timestamp: Date)] = []
        
        let macdStartIndex = slowPeriod - 1
        for i in macdStartIndex..<candles.count {
            let fastIndex = i - (fastPeriod - 1)
            let slowIndex = i - (slowPeriod - 1)
            
            if fastIndex >= 0 && fastIndex < fastEMA.count && slowIndex >= 0 && slowIndex < slowEMA.count {
                let macdValue = fastEMA[fastIndex] - slowEMA[slowIndex]
                macdValues.append((index: i, value: macdValue, timestamp: candles[i].timestamp))
            }
        }
        
        guard macdValues.count >= signalPeriod else { return [] }
        
        // Calculate signal line (EMA of MACD values)
        let signalLine = calculateEMAFromValues(
            values: macdValues.map { $0.value },
            period: signalPeriod
        )
        
        guard !signalLine.isEmpty else { return [] }
        
        // Build final MACD data points
        var results: [MACDDataPoint] = []
        
        let signalStartOffset = signalPeriod - 1
        for i in signalStartOffset..<macdValues.count {
            let macd = macdValues[i]
            let signalIndex = i - signalStartOffset
            
            if signalIndex < signalLine.count {
                let signal = signalLine[signalIndex]
                let histogram = macd.value - signal
                
                results.append(MACDDataPoint(
                    candleIndex: macd.index,
                    timestamp: macd.timestamp,
                    macdLine: macd.value,
                    signalLine: signal,
                    histogram: histogram
                ))
            }
        }
        
        return results
    }
    
    /// Calculate EMA and return just the values (for internal use)
    private static func calculateEMAValues(
        candles: [Candle],
        period: Int,
        priceSource: PriceSource = .close
    ) -> [Double] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [Double] = []
        let multiplier = 2.0 / Double(period + 1)
        
        // Initial SMA as seed
        var sum: Double = 0
        for i in 0..<period {
            sum += priceSource.price(from: candles[i])
        }
        var ema = sum / Double(period)
        results.append(ema)
        
        // Calculate remaining EMAs
        for i in period..<candles.count {
            let price = priceSource.price(from: candles[i])
            ema = (price - ema) * multiplier + ema
            results.append(ema)
        }
        
        return results
    }
    
    /// Calculate EMA from raw values (for signal line calculation)
    private static func calculateEMAFromValues(values: [Double], period: Int) -> [Double] {
        guard values.count >= period && period > 0 else { return [] }
        
        var results: [Double] = []
        let multiplier = 2.0 / Double(period + 1)
        
        // Initial SMA as seed
        var ema = values[0..<period].reduce(0, +) / Double(period)
        results.append(ema)
        
        // Calculate remaining EMAs
        for i in period..<values.count {
            ema = (values[i] - ema) * multiplier + ema
            results.append(ema)
        }
        
        return results
    }
    
    // MARK: - Stochastic Calculation
    
    /// Calculate Stochastic Oscillator
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - kPeriod: %K lookback period (default 14)
    ///   - dPeriod: %D smoothing period (default 3)
    ///   - smoothK: %K smoothing period (default 3, use 1 for fast stochastic)
    /// - Returns: Array of Stochastic data points
    static func calculateStochastic(
        candles: [Candle],
        kPeriod: Int = 14,
        dPeriod: Int = 3,
        smoothK: Int = 3
    ) -> [StochasticDataPoint] {
        // Need enough candles
        let minCandles = kPeriod + smoothK + dPeriod - 2
        guard candles.count >= minCandles else { return [] }
        
        // Step 1: Calculate raw %K values
        var rawKValues: [(index: Int, value: Double, timestamp: Date)] = []
        
        for i in (kPeriod - 1)..<candles.count {
            // Find highest high and lowest low in the lookback period
            var highestHigh = candles[i].high
            var lowestLow = candles[i].low
            
            for j in (i - kPeriod + 1)...i {
                highestHigh = max(highestHigh, candles[j].high)
                lowestLow = min(lowestLow, candles[j].low)
            }
            
            // Calculate raw %K: (Close - Lowest Low) / (Highest High - Lowest Low) * 100
            let range = highestHigh - lowestLow
            let rawK: Double
            if range > 0 {
                rawK = ((candles[i].close - lowestLow) / range) * 100
            } else {
                rawK = 50  // Neutral if no range
            }
            
            rawKValues.append((index: i, value: rawK, timestamp: candles[i].timestamp))
        }
        
        guard rawKValues.count >= smoothK else { return [] }
        
        // Step 2: Smooth %K (SMA of raw %K)
        var smoothedK: [(index: Int, value: Double, timestamp: Date)] = []
        
        for i in (smoothK - 1)..<rawKValues.count {
            var sum: Double = 0
            for j in (i - smoothK + 1)...i {
                sum += rawKValues[j].value
            }
            let smoothedValue = sum / Double(smoothK)
            smoothedK.append((
                index: rawKValues[i].index,
                value: smoothedValue,
                timestamp: rawKValues[i].timestamp
            ))
        }
        
        guard smoothedK.count >= dPeriod else { return [] }
        
        // Step 3: Calculate %D (SMA of smoothed %K)
        var results: [StochasticDataPoint] = []
        
        for i in (dPeriod - 1)..<smoothedK.count {
            var sum: Double = 0
            for j in (i - dPeriod + 1)...i {
                sum += smoothedK[j].value
            }
            let dValue = sum / Double(dPeriod)
            
            results.append(StochasticDataPoint(
                candleIndex: smoothedK[i].index,
                timestamp: smoothedK[i].timestamp,
                kValue: smoothedK[i].value.clamped(to: 0...100),
                dValue: dValue.clamped(to: 0...100)
            ))
        }
        
        return results
    }
    
    // MARK: - Incremental Updates
    
    static func updateEMA(previousEMA: Double, newPrice: Double, period: Int) -> Double {
        let multiplier = 2.0 / Double(period + 1)
        return (newPrice - previousEMA) * multiplier + previousEMA
    }
    
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

// MARK: - Bollinger Bands Calculation

extension IndicatorCalculator {
    
    /// Calculate Bollinger Bands
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - period: Number of periods for the SMA (default 20)
    ///   - standardDeviations: Number of standard deviations for bands (default 2.0)
    /// - Returns: Array of Bollinger Bands data points
    static func calculateBollingerBands(
        candles: [Candle],
        period: Int = 20,
        standardDeviations: Double = 2.0
    ) -> [BollingerBandsDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [BollingerBandsDataPoint] = []
        
        for i in (period - 1)..<candles.count {
            // Calculate SMA (middle band)
            var sum: Double = 0
            for j in (i - period + 1)...i {
                sum += candles[j].close
            }
            let sma = sum / Double(period)
            
            // Calculate standard deviation
            var squaredDiffSum: Double = 0
            for j in (i - period + 1)...i {
                let diff = candles[j].close - sma
                squaredDiffSum += diff * diff
            }
            let variance = squaredDiffSum / Double(period)
            let stdDev = sqrt(variance)
            
            // Calculate bands
            let upperBand = sma + (stdDev * standardDeviations)
            let lowerBand = sma - (stdDev * standardDeviations)
            
            // Calculate bandwidth: (Upper - Lower) / Middle * 100
            let bandwidth = sma > 0 ? ((upperBand - lowerBand) / sma) * 100 : 0
            
            results.append(BollingerBandsDataPoint(
                candleIndex: i,
                middleBand: sma,
                upperBand: upperBand,
                lowerBand: lowerBand,
                bandwidth: bandwidth,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - VWAP Calculation

extension IndicatorCalculator {
    
    /// Calculate Volume Weighted Average Price (VWAP)
    /// VWAP resets at the start of each trading day for intraday charts
    /// - Parameters:
    ///   - candles: Array of candle data
    ///   - resetDaily: Whether to reset VWAP at start of each day (default true for intraday)
    /// - Returns: Array of VWAP data points
    static func calculateVWAP(
        candles: [Candle],
        resetDaily: Bool = true
    ) -> [VWAPDataPoint] {
        guard !candles.isEmpty else { return [] }
        
        var results: [VWAPDataPoint] = []
        
        var cumulativeTPV: Double = 0  // Cumulative Typical Price * Volume
        var cumulativeVolume: Double = 0
        var cumulativeTPVSquared: Double = 0  // For standard deviation
        
        var lastDay: Int = -1
        let calendar = Calendar.current
        
        for (index, candle) in candles.enumerated() {
            // Check if we need to reset for a new day
            if resetDaily {
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: candle.timestamp) ?? 0
                if dayOfYear != lastDay {
                    // Reset for new day
                    cumulativeTPV = 0
                    cumulativeVolume = 0
                    cumulativeTPVSquared = 0
                    lastDay = dayOfYear
                }
            }
            
            // Typical Price = (High + Low + Close) / 3
            let typicalPrice = (candle.high + candle.low + candle.close) / 3.0
            
            // Use a simulated volume if volume isn't available or is zero
            let volume: Double
            if let candleVolume = candle.volume, candleVolume > 0 {
                volume = candleVolume
            } else {
                volume = 1000.0  // Default volume for simulation
            }
            
            // Accumulate
            cumulativeTPV += typicalPrice * volume
            cumulativeVolume += volume
            cumulativeTPVSquared += (typicalPrice * typicalPrice) * volume
            
            // Calculate VWAP
            let vwap = cumulativeVolume > 0 ? cumulativeTPV / cumulativeVolume : typicalPrice
            
            // Calculate standard deviation bands (optional)
            var upperBand: Double? = nil
            var lowerBand: Double? = nil
            
            if cumulativeVolume > 0 {
                let meanSquared = cumulativeTPVSquared / cumulativeVolume
                let vwapSquared = vwap * vwap
                let variance = meanSquared - vwapSquared
                if variance > 0 {
                    let stdDev = sqrt(variance)
                    upperBand = vwap + stdDev
                    lowerBand = vwap - stdDev
                }
            }
            
            results.append(VWAPDataPoint(
                candleIndex: index,
                vwap: vwap,
                upperBand: upperBand,
                lowerBand: lowerBand,
                timestamp: candle.timestamp
            ))
        }
        
        return results
    }
}













////
////  IndicatorCalculator.swift
////  traders_guild
////
////  Created by Al Hennessey on 05/12/2025.
////
//
////
////  IndicatorCalculator.swift
////  traders_guild
////
////  Professional indicator calculation engine
////  Handles EMA, SMA, and RSI computations from candle data
////
//
//import Foundation
//
//// MARK: - Indicator Calculator
//
///// Efficient indicator calculation engine
///// Uses optimized algorithms for real-time updates
//final class IndicatorCalculator {
//    
//    // MARK: - Moving Average Calculations
//    
//    /// Calculate Simple Moving Average (SMA)
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - period: Number of periods for the average
//    ///   - priceSource: Which price to use (open, high, low, close, etc.)
//    /// - Returns: Array of SMA data points (starts at index period-1)
//    static func calculateSMA(
//        candles: [Candle],
//        period: Int,
//        priceSource: PriceSource = .close
//    ) -> [MovingAverageDataPoint] {
//        guard candles.count >= period && period > 0 else { return [] }
//        
//        var results: [MovingAverageDataPoint] = []
//        var sum: Double = 0
//        
//        // Initial sum for first period
//        for i in 0..<period {
//            sum += priceSource.price(from: candles[i])
//        }
//        
//        // First SMA value
//        let firstValue = sum / Double(period)
//        results.append(MovingAverageDataPoint(
//            candleIndex: period - 1,
//            value: firstValue,
//            timestamp: candles[period - 1].timestamp
//        ))
//        
//        // Rolling calculation for remaining values
//        for i in period..<candles.count {
//            sum -= priceSource.price(from: candles[i - period])
//            sum += priceSource.price(from: candles[i])
//            
//            let sma = sum / Double(period)
//            results.append(MovingAverageDataPoint(
//                candleIndex: i,
//                value: sma,
//                timestamp: candles[i].timestamp
//            ))
//        }
//        
//        return results
//    }
//    
//    /// Calculate Exponential Moving Average (EMA)
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - period: Number of periods for the EMA
//    ///   - priceSource: Which price to use
//    /// - Returns: Array of EMA data points
//    static func calculateEMA(
//        candles: [Candle],
//        period: Int,
//        priceSource: PriceSource = .close
//    ) -> [MovingAverageDataPoint] {
//        guard candles.count >= period && period > 0 else { return [] }
//        
//        var results: [MovingAverageDataPoint] = []
//        
//        // EMA multiplier: 2 / (period + 1)
//        let multiplier = 2.0 / Double(period + 1)
//        
//        // Calculate initial SMA as seed for EMA
//        var sum: Double = 0
//        for i in 0..<period {
//            sum += priceSource.price(from: candles[i])
//        }
//        var ema = sum / Double(period)
//        
//        // First EMA value (same as SMA for the initial point)
//        results.append(MovingAverageDataPoint(
//            candleIndex: period - 1,
//            value: ema,
//            timestamp: candles[period - 1].timestamp
//        ))
//        
//        // Calculate EMA for remaining candles
//        // EMA = (Price - Previous EMA) × Multiplier + Previous EMA
//        for i in period..<candles.count {
//            let price = priceSource.price(from: candles[i])
//            ema = (price - ema) * multiplier + ema
//            
//            results.append(MovingAverageDataPoint(
//                candleIndex: i,
//                value: ema,
//                timestamp: candles[i].timestamp
//            ))
//        }
//        
//        return results
//    }
//    
//    // MARK: - RSI Calculation
//    
//    /// Calculate Relative Strength Index (RSI)
//    /// Uses Wilder's smoothing method (exponential moving average of gains/losses)
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - period: Number of periods (typically 14)
//    /// - Returns: Array of RSI data points (0-100 scale)
//    static func calculateRSI(
//        candles: [Candle],
//        period: Int = 14
//    ) -> [RSIDataPoint] {
//        guard candles.count > period && period > 0 else { return [] }
//        
//        var results: [RSIDataPoint] = []
//        
//        // Calculate price changes
//        var gains: [Double] = []
//        var losses: [Double] = []
//        
//        for i in 1..<candles.count {
//            let change = candles[i].close - candles[i-1].close
//            if change >= 0 {
//                gains.append(change)
//                losses.append(0)
//            } else {
//                gains.append(0)
//                losses.append(abs(change))
//            }
//        }
//        
//        // Need at least 'period' price changes
//        guard gains.count >= period else { return [] }
//        
//        // Calculate initial average gain and loss (first period using SMA)
//        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
//        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
//        
//        // First RSI value
//        let firstRSI = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
//        results.append(RSIDataPoint(
//            candleIndex: period,  // RSI starts at candle index = period (0-based)
//            value: firstRSI,
//            timestamp: candles[period].timestamp
//        ))
//        
//        // Calculate remaining RSI values using Wilder's smoothing
//        // Smoothed Average = ((Previous Average × (period - 1)) + Current Value) / period
//        for i in period..<gains.count {
//            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
//            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
//            
//            let rsi = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
//            results.append(RSIDataPoint(
//                candleIndex: i + 1,  // +1 because gains/losses array is offset by 1
//                value: rsi,
//                timestamp: candles[i + 1].timestamp
//            ))
//        }
//        
//        return results
//    }
//    
//    /// Calculate RSI value from average gain and loss
//    private static func calculateRSIValue(avgGain: Double, avgLoss: Double) -> Double {
//        if avgLoss == 0 {
//            return avgGain == 0 ? 50 : 100  // No loss = RSI 100, no movement = RSI 50
//        }
//        let rs = avgGain / avgLoss
//        let rsi = 100 - (100 / (1 + rs))
//        return rsi.clamped(to: 0...100)
//    }
//    
//    // MARK: - Incremental Updates (for real-time data)
//    
//    /// Update EMA with a new candle (efficient for live data)
//    /// - Parameters:
//    ///   - previousEMA: The last calculated EMA value
//    ///   - newPrice: The new price to incorporate
//    ///   - period: The EMA period
//    /// - Returns: Updated EMA value
//    static func updateEMA(previousEMA: Double, newPrice: Double, period: Int) -> Double {
//        let multiplier = 2.0 / Double(period + 1)
//        return (newPrice - previousEMA) * multiplier + previousEMA
//    }
//    
//    /// Update RSI with a new candle (efficient for live data)
//    /// - Parameters:
//    ///   - previousAvgGain: Previous average gain
//    ///   - previousAvgLoss: Previous average loss
//    ///   - currentChange: Price change from last candle
//    ///   - period: RSI period
//    /// - Returns: Tuple of (new RSI value, new avg gain, new avg loss)
//    static func updateRSI(
//        previousAvgGain: Double,
//        previousAvgLoss: Double,
//        currentChange: Double,
//        period: Int
//    ) -> (rsi: Double, avgGain: Double, avgLoss: Double) {
//        let currentGain = max(currentChange, 0)
//        let currentLoss = abs(min(currentChange, 0))
//        
//        let newAvgGain = ((previousAvgGain * Double(period - 1)) + currentGain) / Double(period)
//        let newAvgLoss = ((previousAvgLoss * Double(period - 1)) + currentLoss) / Double(period)
//        
//        let rsi = calculateRSIValue(avgGain: newAvgGain, avgLoss: newAvgLoss)
//        
//        return (rsi, newAvgGain, newAvgLoss)
//    }
//}
//
//// MARK: - Clamped Extension
//
//extension Comparable {
//    func clamped(to range: ClosedRange<Self>) -> Self {
//        return min(max(self, range.lowerBound), range.upperBound)
//    }
//}
//
//// MARK: - Batch Calculation Helper
//
//extension IndicatorCalculator {
//    
//    /// Calculate all configured moving averages at once
//    static func calculateAllMovingAverages(
//        candles: [Candle],
//        configs: [MovingAverageConfig]
//    ) -> [UUID: [MovingAverageDataPoint]] {
//        var results: [UUID: [MovingAverageDataPoint]] = [:]
//        
//        for config in configs where config.isEnabled {
//            let data: [MovingAverageDataPoint]
//            
//            switch config.type {
//            case .ema:
//                data = calculateEMA(
//                    candles: candles,
//                    period: config.period,
//                    priceSource: config.priceSource
//                )
//            case .sma:
//                data = calculateSMA(
//                    candles: candles,
//                    period: config.period,
//                    priceSource: config.priceSource
//                )
//            default:
//                continue
//            }
//            
//            results[config.id] = data
//        }
//        
//        return results
//    }
//}
