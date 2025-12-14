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

// MARK: - WMA Calculation

extension IndicatorCalculator {
    
    /// Calculate Weighted Moving Average
    static func calculateWMA(
        candles: [Candle],
        period: Int,
        priceSource: PriceSource = .close
    ) -> [MovingAverageDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [MovingAverageDataPoint] = []
        let denominator = Double(period * (period + 1)) / 2.0
        
        for i in (period - 1)..<candles.count {
            var weightedSum: Double = 0
            
            for j in 0..<period {
                let weight = Double(j + 1)
                let candle = candles[i - period + 1 + j]
                let price = priceSource.price(from: candle)
                weightedSum += price * weight
            }
            
            let wma = weightedSum / denominator
            
            results.append(MovingAverageDataPoint(
                candleIndex: i,
                value: wma,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - HMA Calculation

extension IndicatorCalculator {
    
    /// Calculate Hull Moving Average
    /// HMA = WMA(2 * WMA(n/2) - WMA(n), sqrt(n))
    static func calculateHMA(
        candles: [Candle],
        period: Int,
        priceSource: PriceSource = .close
    ) -> [MovingAverageDataPoint] {
        guard period >= 4 else { return [] }
        
        let halfPeriod = period / 2
        let sqrtPeriod = Int(sqrt(Double(period)))
        
        // Get prices
        let prices = candles.map { priceSource.price(from: $0) }
        guard prices.count >= period else { return [] }
        
        // Calculate WMA(n/2)
        let wmaHalf = calculateWMAFromPrices(prices: prices, period: halfPeriod)
        
        // Calculate WMA(n)
        let wmaFull = calculateWMAFromPrices(prices: prices, period: period)
        
        // Both arrays should align at the end
        guard wmaHalf.count > 0 && wmaFull.count > 0 else { return [] }
        
        // Calculate 2 * WMA(n/2) - WMA(n)
        let diff = min(wmaHalf.count, wmaFull.count)
        var rawHMA: [Double] = []
        
        let halfOffset = wmaHalf.count - diff
        let fullOffset = wmaFull.count - diff
        
        for i in 0..<diff {
            rawHMA.append(2 * wmaHalf[halfOffset + i] - wmaFull[fullOffset + i])
        }
        
        // Calculate WMA of the difference
        let finalWMA = calculateWMAFromPrices(prices: rawHMA, period: sqrtPeriod)
        
        // Map back to candle indices
        var results: [MovingAverageDataPoint] = []
        let startIndex = candles.count - finalWMA.count
        
        for (i, value) in finalWMA.enumerated() {
            let candleIndex = startIndex + i
            if candleIndex >= 0 && candleIndex < candles.count {
                results.append(MovingAverageDataPoint(
                    candleIndex: candleIndex,
                    value: value,
                    timestamp: candles[candleIndex].timestamp
                ))
            }
        }
        
        return results
    }
    
    /// Helper: Calculate WMA from raw price array
    private static func calculateWMAFromPrices(prices: [Double], period: Int) -> [Double] {
        guard prices.count >= period && period > 0 else { return [] }
        
        var results: [Double] = []
        let denominator = Double(period * (period + 1)) / 2.0
        
        for i in (period - 1)..<prices.count {
            var weightedSum: Double = 0
            
            for j in 0..<period {
                let weight = Double(j + 1)
                weightedSum += prices[i - period + 1 + j] * weight
            }
            
            results.append(weightedSum / denominator)
        }
        
        return results
    }
}

// MARK: - Donchian Channels Calculation

extension IndicatorCalculator {
    
    /// Calculate Donchian Channels
    static func calculateDonchianChannels(
        candles: [Candle],
        period: Int = 20
    ) -> [DonchianChannelsDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [DonchianChannelsDataPoint] = []
        
        for i in (period - 1)..<candles.count {
            var highestHigh = candles[i].high
            var lowestLow = candles[i].low
            
            for j in (i - period + 1)...i {
                highestHigh = max(highestHigh, candles[j].high)
                lowestLow = min(lowestLow, candles[j].low)
            }
            
            let middleLine = (highestHigh + lowestLow) / 2.0
            
            results.append(DonchianChannelsDataPoint(
                candleIndex: i,
                upperBand: highestHigh,
                lowerBand: lowestLow,
                middleLine: middleLine,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - ATR Calculation

extension IndicatorCalculator {
    
    /// Calculate Average True Range
    static func calculateATR(
        candles: [Candle],
        period: Int = 14
    ) -> [ATRDataPoint] {
        guard candles.count >= period + 1 && period > 0 else { return [] }
        
        var results: [ATRDataPoint] = []
        var trueRanges: [Double] = []
        
        // Calculate true ranges
        for i in 1..<candles.count {
            let high = candles[i].high
            let low = candles[i].low
            let prevClose = candles[i - 1].close
            
            let tr = max(
                high - low,
                abs(high - prevClose),
                abs(low - prevClose)
            )
            trueRanges.append(tr)
        }
        
        // Calculate initial ATR (simple average)
        guard trueRanges.count >= period else { return [] }
        
        var atr = trueRanges.prefix(period).reduce(0, +) / Double(period)
        
        // First ATR value
        results.append(ATRDataPoint(
            candleIndex: period,
            value: atr,
            timestamp: candles[period].timestamp
        ))
        
        // Calculate subsequent ATR values using smoothed method
        for i in period..<trueRanges.count {
            atr = ((atr * Double(period - 1)) + trueRanges[i]) / Double(period)
            
            results.append(ATRDataPoint(
                candleIndex: i + 1,
                value: atr,
                timestamp: candles[i + 1].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - Keltner Channels Calculation

extension IndicatorCalculator {
    
    /// Calculate Keltner Channels
    static func calculateKeltnerChannels(
        candles: [Candle],
        emaPeriod: Int = 20,
        atrPeriod: Int = 10,
        atrMultiplier: Double = 2.0
    ) -> [KeltnerChannelsDataPoint] {
        // Get EMA
        let emaData = calculateEMA(candles: candles, period: emaPeriod)
        guard !emaData.isEmpty else { return [] }
        
        // Get ATR
        let atrData = calculateATR(candles: candles, period: atrPeriod)
        guard !atrData.isEmpty else { return [] }
        
        var results: [KeltnerChannelsDataPoint] = []
        
        // Create lookup maps
        var emaMap: [Int: Double] = [:]
        for point in emaData {
            emaMap[point.candleIndex] = point.value
        }
        
        var atrMap: [Int: Double] = [:]
        for point in atrData {
            atrMap[point.candleIndex] = point.value
        }
        
        // Calculate channels where both EMA and ATR are available
        for i in 0..<candles.count {
            guard let ema = emaMap[i], let atr = atrMap[i] else { continue }
            
            let upperBand = ema + (atr * atrMultiplier)
            let lowerBand = ema - (atr * atrMultiplier)
            
            results.append(KeltnerChannelsDataPoint(
                candleIndex: i,
                ema: ema,
                upperBand: upperBand,
                lowerBand: lowerBand,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - Parabolic SAR Calculation

extension IndicatorCalculator {
    
    /// Calculate Parabolic SAR
    static func calculateParabolicSAR(
        candles: [Candle],
        accelerationStart: Double = 0.02,
        accelerationIncrement: Double = 0.02,
        accelerationMax: Double = 0.2
    ) -> [ParabolicSARDataPoint] {
        guard candles.count >= 2 else { return [] }
        
        var results: [ParabolicSARDataPoint] = []
        
        // Initialize
        var isUptrend = candles[1].close > candles[0].close
        var sar = isUptrend ? candles[0].low : candles[0].high
        var extremePoint = isUptrend ? candles[0].high : candles[0].low
        var acceleration = accelerationStart
        
        for i in 1..<candles.count {
            let candle = candles[i]
            
            // Calculate new SAR
            var newSAR = sar + acceleration * (extremePoint - sar)
            
            // Limit SAR
            if isUptrend {
                newSAR = min(newSAR, candles[i - 1].low)
                if i >= 2 {
                    newSAR = min(newSAR, candles[i - 2].low)
                }
            } else {
                newSAR = max(newSAR, candles[i - 1].high)
                if i >= 2 {
                    newSAR = max(newSAR, candles[i - 2].high)
                }
            }
            
            // Check for reversal
            var reversed = false
            if isUptrend {
                if candle.low < newSAR {
                    reversed = true
                    isUptrend = false
                    newSAR = extremePoint
                    extremePoint = candle.low
                    acceleration = accelerationStart
                }
            } else {
                if candle.high > newSAR {
                    reversed = true
                    isUptrend = true
                    newSAR = extremePoint
                    extremePoint = candle.high
                    acceleration = accelerationStart
                }
            }
            
            // Update extreme point and acceleration if no reversal
            if !reversed {
                if isUptrend {
                    if candle.high > extremePoint {
                        extremePoint = candle.high
                        acceleration = min(acceleration + accelerationIncrement, accelerationMax)
                    }
                } else {
                    if candle.low < extremePoint {
                        extremePoint = candle.low
                        acceleration = min(acceleration + accelerationIncrement, accelerationMax)
                    }
                }
            }
            
            sar = newSAR
            
            results.append(ParabolicSARDataPoint(
                candleIndex: i,
                sar: sar,
                isUptrend: isUptrend,
                timestamp: candle.timestamp
            ))
        }
        
        return results
    }
}

// MARK: - CCI Calculation

extension IndicatorCalculator {
    
    /// Calculate Commodity Channel Index
    static func calculateCCI(
        candles: [Candle],
        period: Int = 20
    ) -> [CCIDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [CCIDataPoint] = []
        let constant = 0.015
        
        for i in (period - 1)..<candles.count {
            // Calculate typical prices for the period
            var typicalPrices: [Double] = []
            for j in (i - period + 1)...i {
                let tp = (candles[j].high + candles[j].low + candles[j].close) / 3.0
                typicalPrices.append(tp)
            }
            
            // Calculate SMA of typical prices
            let smaTP = typicalPrices.reduce(0, +) / Double(period)
            
            // Calculate mean deviation
            let meanDeviation = typicalPrices.map { abs($0 - smaTP) }.reduce(0, +) / Double(period)
            
            // Calculate CCI
            let currentTP = typicalPrices.last ?? 0
            let cci: Double
            if meanDeviation > 0 {
                cci = (currentTP - smaTP) / (constant * meanDeviation)
            } else {
                cci = 0
            }
            
            results.append(CCIDataPoint(
                candleIndex: i,
                value: cci,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - Williams %R Calculation

extension IndicatorCalculator {
    
    /// Calculate Williams %R
    static func calculateWilliamsR(
        candles: [Candle],
        period: Int = 14
    ) -> [WilliamsRDataPoint] {
        guard candles.count >= period && period > 0 else { return [] }
        
        var results: [WilliamsRDataPoint] = []
        
        for i in (period - 1)..<candles.count {
            var highestHigh = candles[i].high
            var lowestLow = candles[i].low
            
            for j in (i - period + 1)...i {
                highestHigh = max(highestHigh, candles[j].high)
                lowestLow = min(lowestLow, candles[j].low)
            }
            
            let range = highestHigh - lowestLow
            let williamsR: Double
            if range > 0 {
                williamsR = ((highestHigh - candles[i].close) / range) * -100
            } else {
                williamsR = -50  // Neutral if no range
            }
            
            results.append(WilliamsRDataPoint(
                candleIndex: i,
                value: williamsR,
                timestamp: candles[i].timestamp
            ))
        }
        
        return results
    }
}

// MARK: - Volume Calculation

extension IndicatorCalculator {
    
    /// Calculate Volume data with optional MA
    static func calculateVolume(
        candles: [Candle],
        maPeriod: Int = 20
    ) -> [VolumeDataPoint] {
        guard !candles.isEmpty else { return [] }
        
        var results: [VolumeDataPoint] = []
        var volumes: [Double] = []
        
        for (i, candle) in candles.enumerated() {
            let vol: Double
            if let candleVolume = candle.volume, candleVolume > 0 {
                vol = candleVolume
            } else {
                vol = 1000.0  // Default for simulation
            }
            volumes.append(vol)
            
            let isBullish = candle.close >= candle.open
            
            // Calculate MA if enough data
            var ma: Double? = nil
            if i >= maPeriod - 1 {
                let maVolumes = volumes.suffix(maPeriod)
                ma = maVolumes.reduce(0, +) / Double(maPeriod)
            }
            
            results.append(VolumeDataPoint(
                candleIndex: i,
                volume: vol,
                isBullish: isBullish,
                ma: ma,
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
////  EXPANDED VERSION - Adds MACD and Stochastic calculations
////
//
//import Foundation
//
//// MARK: - Indicator Calculator
//
//final class IndicatorCalculator {
//    
//    // MARK: - Simple Moving Average (SMA)
//    
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
//    // MARK: - Exponential Moving Average (EMA)
//    
//    static func calculateEMA(
//        candles: [Candle],
//        period: Int,
//        priceSource: PriceSource = .close
//    ) -> [MovingAverageDataPoint] {
//        guard candles.count >= period && period > 0 else { return [] }
//        
//        var results: [MovingAverageDataPoint] = []
//        let multiplier = 2.0 / Double(period + 1)
//        
//        // Calculate initial SMA as seed for EMA
//        var sum: Double = 0
//        for i in 0..<period {
//            sum += priceSource.price(from: candles[i])
//        }
//        var ema = sum / Double(period)
//        
//        // First EMA value
//        results.append(MovingAverageDataPoint(
//            candleIndex: period - 1,
//            value: ema,
//            timestamp: candles[period - 1].timestamp
//        ))
//        
//        // Calculate EMA for remaining candles
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
//    static func calculateRSI(
//        candles: [Candle],
//        period: Int = 14
//    ) -> [RSIDataPoint] {
//        guard candles.count > period && period > 0 else { return [] }
//        
//        var results: [RSIDataPoint] = []
//        var gains: [Double] = []
//        var losses: [Double] = []
//        
//        // Calculate price changes
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
//        guard gains.count >= period else { return [] }
//        
//        // Calculate initial average gain and loss
//        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
//        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
//        
//        // First RSI value
//        let firstRSI = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
//        results.append(RSIDataPoint(
//            candleIndex: period,
//            value: firstRSI,
//            timestamp: candles[period].timestamp
//        ))
//        
//        // Calculate remaining RSI values using Wilder's smoothing
//        for i in period..<gains.count {
//            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
//            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
//            
//            let rsi = calculateRSIValue(avgGain: avgGain, avgLoss: avgLoss)
//            results.append(RSIDataPoint(
//                candleIndex: i + 1,
//                value: rsi,
//                timestamp: candles[i + 1].timestamp
//            ))
//        }
//        
//        return results
//    }
//    
//    private static func calculateRSIValue(avgGain: Double, avgLoss: Double) -> Double {
//        if avgLoss == 0 {
//            return avgGain == 0 ? 50 : 100
//        }
//        let rs = avgGain / avgLoss
//        let rsi = 100 - (100 / (1 + rs))
//        return rsi.clamped(to: 0...100)
//    }
//    
//    // MARK: - MACD Calculation
//    
//    /// Calculate MACD indicator
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - fastPeriod: Fast EMA period (default 12)
//    ///   - slowPeriod: Slow EMA period (default 26)
//    ///   - signalPeriod: Signal line EMA period (default 9)
//    /// - Returns: Array of MACD data points
//    static func calculateMACD(
//        candles: [Candle],
//        fastPeriod: Int = 12,
//        slowPeriod: Int = 26,
//        signalPeriod: Int = 9
//    ) -> [MACDDataPoint] {
//        // Need enough candles for slow EMA + signal period
//        let minCandles = slowPeriod + signalPeriod
//        guard candles.count >= minCandles else { return [] }
//        
//        // Calculate fast and slow EMAs
//        let fastEMA = calculateEMAValues(candles: candles, period: fastPeriod)
//        let slowEMA = calculateEMAValues(candles: candles, period: slowPeriod)
//        
//        guard !fastEMA.isEmpty && !slowEMA.isEmpty else { return [] }
//        
//        // Calculate MACD line (fast EMA - slow EMA)
//        // MACD starts at slowPeriod - 1 (where slow EMA starts)
//        var macdValues: [(index: Int, value: Double, timestamp: Date)] = []
//        
//        let macdStartIndex = slowPeriod - 1
//        for i in macdStartIndex..<candles.count {
//            let fastIndex = i - (fastPeriod - 1)
//            let slowIndex = i - (slowPeriod - 1)
//            
//            if fastIndex >= 0 && fastIndex < fastEMA.count && slowIndex >= 0 && slowIndex < slowEMA.count {
//                let macdValue = fastEMA[fastIndex] - slowEMA[slowIndex]
//                macdValues.append((index: i, value: macdValue, timestamp: candles[i].timestamp))
//            }
//        }
//        
//        guard macdValues.count >= signalPeriod else { return [] }
//        
//        // Calculate signal line (EMA of MACD values)
//        let signalLine = calculateEMAFromValues(
//            values: macdValues.map { $0.value },
//            period: signalPeriod
//        )
//        
//        guard !signalLine.isEmpty else { return [] }
//        
//        // Build final MACD data points
//        var results: [MACDDataPoint] = []
//        
//        let signalStartOffset = signalPeriod - 1
//        for i in signalStartOffset..<macdValues.count {
//            let macd = macdValues[i]
//            let signalIndex = i - signalStartOffset
//            
//            if signalIndex < signalLine.count {
//                let signal = signalLine[signalIndex]
//                let histogram = macd.value - signal
//                
//                results.append(MACDDataPoint(
//                    candleIndex: macd.index,
//                    timestamp: macd.timestamp,
//                    macdLine: macd.value,
//                    signalLine: signal,
//                    histogram: histogram
//                ))
//            }
//        }
//        
//        return results
//    }
//    
//    /// Calculate EMA and return just the values (for internal use)
//    private static func calculateEMAValues(
//        candles: [Candle],
//        period: Int,
//        priceSource: PriceSource = .close
//    ) -> [Double] {
//        guard candles.count >= period && period > 0 else { return [] }
//        
//        var results: [Double] = []
//        let multiplier = 2.0 / Double(period + 1)
//        
//        // Initial SMA as seed
//        var sum: Double = 0
//        for i in 0..<period {
//            sum += priceSource.price(from: candles[i])
//        }
//        var ema = sum / Double(period)
//        results.append(ema)
//        
//        // Calculate remaining EMAs
//        for i in period..<candles.count {
//            let price = priceSource.price(from: candles[i])
//            ema = (price - ema) * multiplier + ema
//            results.append(ema)
//        }
//        
//        return results
//    }
//    
//    /// Calculate EMA from raw values (for signal line calculation)
//    private static func calculateEMAFromValues(values: [Double], period: Int) -> [Double] {
//        guard values.count >= period && period > 0 else { return [] }
//        
//        var results: [Double] = []
//        let multiplier = 2.0 / Double(period + 1)
//        
//        // Initial SMA as seed
//        var ema = values[0..<period].reduce(0, +) / Double(period)
//        results.append(ema)
//        
//        // Calculate remaining EMAs
//        for i in period..<values.count {
//            ema = (values[i] - ema) * multiplier + ema
//            results.append(ema)
//        }
//        
//        return results
//    }
//    
//    // MARK: - Stochastic Calculation
//    
//    /// Calculate Stochastic Oscillator
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - kPeriod: %K lookback period (default 14)
//    ///   - dPeriod: %D smoothing period (default 3)
//    ///   - smoothK: %K smoothing period (default 3, use 1 for fast stochastic)
//    /// - Returns: Array of Stochastic data points
//    static func calculateStochastic(
//        candles: [Candle],
//        kPeriod: Int = 14,
//        dPeriod: Int = 3,
//        smoothK: Int = 3
//    ) -> [StochasticDataPoint] {
//        // Need enough candles
//        let minCandles = kPeriod + smoothK + dPeriod - 2
//        guard candles.count >= minCandles else { return [] }
//        
//        // Step 1: Calculate raw %K values
//        var rawKValues: [(index: Int, value: Double, timestamp: Date)] = []
//        
//        for i in (kPeriod - 1)..<candles.count {
//            // Find highest high and lowest low in the lookback period
//            var highestHigh = candles[i].high
//            var lowestLow = candles[i].low
//            
//            for j in (i - kPeriod + 1)...i {
//                highestHigh = max(highestHigh, candles[j].high)
//                lowestLow = min(lowestLow, candles[j].low)
//            }
//            
//            // Calculate raw %K: (Close - Lowest Low) / (Highest High - Lowest Low) * 100
//            let range = highestHigh - lowestLow
//            let rawK: Double
//            if range > 0 {
//                rawK = ((candles[i].close - lowestLow) / range) * 100
//            } else {
//                rawK = 50  // Neutral if no range
//            }
//            
//            rawKValues.append((index: i, value: rawK, timestamp: candles[i].timestamp))
//        }
//        
//        guard rawKValues.count >= smoothK else { return [] }
//        
//        // Step 2: Smooth %K (SMA of raw %K)
//        var smoothedK: [(index: Int, value: Double, timestamp: Date)] = []
//        
//        for i in (smoothK - 1)..<rawKValues.count {
//            var sum: Double = 0
//            for j in (i - smoothK + 1)...i {
//                sum += rawKValues[j].value
//            }
//            let smoothedValue = sum / Double(smoothK)
//            smoothedK.append((
//                index: rawKValues[i].index,
//                value: smoothedValue,
//                timestamp: rawKValues[i].timestamp
//            ))
//        }
//        
//        guard smoothedK.count >= dPeriod else { return [] }
//        
//        // Step 3: Calculate %D (SMA of smoothed %K)
//        var results: [StochasticDataPoint] = []
//        
//        for i in (dPeriod - 1)..<smoothedK.count {
//            var sum: Double = 0
//            for j in (i - dPeriod + 1)...i {
//                sum += smoothedK[j].value
//            }
//            let dValue = sum / Double(dPeriod)
//            
//            results.append(StochasticDataPoint(
//                candleIndex: smoothedK[i].index,
//                timestamp: smoothedK[i].timestamp,
//                kValue: smoothedK[i].value.clamped(to: 0...100),
//                dValue: dValue.clamped(to: 0...100)
//            ))
//        }
//        
//        return results
//    }
//    
//    // MARK: - Incremental Updates
//    
//    static func updateEMA(previousEMA: Double, newPrice: Double, period: Int) -> Double {
//        let multiplier = 2.0 / Double(period + 1)
//        return (newPrice - previousEMA) * multiplier + previousEMA
//    }
//    
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
//
//// MARK: - Bollinger Bands Calculation
//
//extension IndicatorCalculator {
//    
//    /// Calculate Bollinger Bands
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - period: Number of periods for the SMA (default 20)
//    ///   - standardDeviations: Number of standard deviations for bands (default 2.0)
//    /// - Returns: Array of Bollinger Bands data points
//    static func calculateBollingerBands(
//        candles: [Candle],
//        period: Int = 20,
//        standardDeviations: Double = 2.0
//    ) -> [BollingerBandsDataPoint] {
//        guard candles.count >= period && period > 0 else { return [] }
//        
//        var results: [BollingerBandsDataPoint] = []
//        
//        for i in (period - 1)..<candles.count {
//            // Calculate SMA (middle band)
//            var sum: Double = 0
//            for j in (i - period + 1)...i {
//                sum += candles[j].close
//            }
//            let sma = sum / Double(period)
//            
//            // Calculate standard deviation
//            var squaredDiffSum: Double = 0
//            for j in (i - period + 1)...i {
//                let diff = candles[j].close - sma
//                squaredDiffSum += diff * diff
//            }
//            let variance = squaredDiffSum / Double(period)
//            let stdDev = sqrt(variance)
//            
//            // Calculate bands
//            let upperBand = sma + (stdDev * standardDeviations)
//            let lowerBand = sma - (stdDev * standardDeviations)
//            
//            // Calculate bandwidth: (Upper - Lower) / Middle * 100
//            let bandwidth = sma > 0 ? ((upperBand - lowerBand) / sma) * 100 : 0
//            
//            results.append(BollingerBandsDataPoint(
//                candleIndex: i,
//                middleBand: sma,
//                upperBand: upperBand,
//                lowerBand: lowerBand,
//                bandwidth: bandwidth,
//                timestamp: candles[i].timestamp
//            ))
//        }
//        
//        return results
//    }
//}
//
//// MARK: - VWAP Calculation
//
//extension IndicatorCalculator {
//    
//    /// Calculate Volume Weighted Average Price (VWAP)
//    /// VWAP resets at the start of each trading day for intraday charts
//    /// - Parameters:
//    ///   - candles: Array of candle data
//    ///   - resetDaily: Whether to reset VWAP at start of each day (default true for intraday)
//    /// - Returns: Array of VWAP data points
//    static func calculateVWAP(
//        candles: [Candle],
//        resetDaily: Bool = true
//    ) -> [VWAPDataPoint] {
//        guard !candles.isEmpty else { return [] }
//        
//        var results: [VWAPDataPoint] = []
//        
//        var cumulativeTPV: Double = 0  // Cumulative Typical Price * Volume
//        var cumulativeVolume: Double = 0
//        var cumulativeTPVSquared: Double = 0  // For standard deviation
//        
//        var lastDay: Int = -1
//        let calendar = Calendar.current
//        
//        for (index, candle) in candles.enumerated() {
//            // Check if we need to reset for a new day
//            if resetDaily {
//                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: candle.timestamp) ?? 0
//                if dayOfYear != lastDay {
//                    // Reset for new day
//                    cumulativeTPV = 0
//                    cumulativeVolume = 0
//                    cumulativeTPVSquared = 0
//                    lastDay = dayOfYear
//                }
//            }
//            
//            // Typical Price = (High + Low + Close) / 3
//            let typicalPrice = (candle.high + candle.low + candle.close) / 3.0
//            
//            // Use a simulated volume if volume isn't available or is zero
//            let volume: Double
//            if let candleVolume = candle.volume, candleVolume > 0 {
//                volume = candleVolume
//            } else {
//                volume = 1000.0  // Default volume for simulation
//            }
//            
//            // Accumulate
//            cumulativeTPV += typicalPrice * volume
//            cumulativeVolume += volume
//            cumulativeTPVSquared += (typicalPrice * typicalPrice) * volume
//            
//            // Calculate VWAP
//            let vwap = cumulativeVolume > 0 ? cumulativeTPV / cumulativeVolume : typicalPrice
//            
//            // Calculate standard deviation bands (optional)
//            var upperBand: Double? = nil
//            var lowerBand: Double? = nil
//            
//            if cumulativeVolume > 0 {
//                let meanSquared = cumulativeTPVSquared / cumulativeVolume
//                let vwapSquared = vwap * vwap
//                let variance = meanSquared - vwapSquared
//                if variance > 0 {
//                    let stdDev = sqrt(variance)
//                    upperBand = vwap + stdDev
//                    lowerBand = vwap - stdDev
//                }
//            }
//            
//            results.append(VWAPDataPoint(
//                candleIndex: index,
//                vwap: vwap,
//                upperBand: upperBand,
//                lowerBand: lowerBand,
//                timestamp: candle.timestamp
//            ))
//        }
//        
//        return results
//    }
//}
//
//



