//
//  IndicatorManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/12/2025.
//

//
//  IndicatorManager.swift
//  traders_guild
//
//  Central manager for indicator state, calculations, and persistence
//  Handles computed indicator data and configuration
//

import SwiftUI
import Combine

// MARK: - Indicator Manager

@MainActor
final class IndicatorManager: ObservableObject {
    
    // MARK: - Published State
    
    /// Active indicator configurations
    @Published var activeIndicators = ActiveIndicators()
    
    /// Computed moving average data (keyed by config ID)
    @Published var movingAverageData: [UUID: [MovingAverageDataPoint]] = [:]
    
    /// Computed RSI data
    @Published var rsiData: [RSIDataPoint] = []
    
    /// Whether calculations are in progress
    @Published var isCalculating: Bool = false
    
    /// Error message if calculation fails
    @Published var errorMessage: String?
    
    // MARK: - Internal State
    
    /// Cache of last candle count to detect data changes
    private var lastCandleCount: Int = 0
    
    /// Cache of last candle close price for tick updates
    private var lastClosePrice: Double = 0
    
    // MARK: - Initialization
    
    init() {
        loadSavedConfiguration()
    }
    
    // MARK: - Public API
    
    /// Recalculate all indicators with new candle data
    func recalculateIndicators(candles: [Candle]) {
        guard !candles.isEmpty else {
            clearAllData()
            return
        }
        
        isCalculating = true
        errorMessage = nil
        
        // Calculate moving averages
        let maConfigs = activeIndicators.enabledMovingAverages
        if !maConfigs.isEmpty {
            movingAverageData = IndicatorCalculator.calculateAllMovingAverages(
                candles: candles,
                configs: maConfigs
            )
        } else {
            movingAverageData = [:]
        }
        
        // Calculate RSI
        if let rsiConfig = activeIndicators.rsi, rsiConfig.isEnabled {
            rsiData = IndicatorCalculator.calculateRSI(
                candles: candles,
                period: rsiConfig.period
            )
        } else {
            rsiData = []
        }
        
        lastCandleCount = candles.count
        if let lastCandle = candles.last {
            lastClosePrice = lastCandle.close
        }
        
        isCalculating = false
    }
    
    /// Update indicators efficiently when only the last candle changes (tick update)
    func updateWithTick(candles: [Candle]) {
        guard !candles.isEmpty else { return }
        
        // For now, just recalculate everything
        // In a production app, you'd implement incremental updates
        if candles.count != lastCandleCount || candles.last?.close != lastClosePrice {
            recalculateIndicators(candles: candles)
        }
    }
    
    /// Clear all calculated data
    func clearAllData() {
        movingAverageData = [:]
        rsiData = []
        lastCandleCount = 0
        lastClosePrice = 0
    }
    
    // MARK: - Moving Average Management
    
    /// Add a new moving average indicator
    func addMovingAverage(_ config: MovingAverageConfig) {
        // Prevent duplicates
        guard !activeIndicators.movingAverages.contains(where: { $0.id == config.id }) else { return }
        activeIndicators.movingAverages.append(config)
        saveConfiguration()
    }
    
    /// Add EMA with specific period
    func addEMA(period: Int, color: Color = .cyan) {
        let config = MovingAverageConfig(
            type: .ema,
            color: CodableColor(color),
            period: period
        )
        addMovingAverage(config)
    }
    
    /// Add SMA with specific period
    func addSMA(period: Int, color: Color = .orange) {
        let config = MovingAverageConfig(
            type: .sma,
            color: CodableColor(color),
            period: period
        )
        addMovingAverage(config)
    }
    
    /// Remove a moving average by ID
    func removeMovingAverage(id: UUID) {
        activeIndicators.movingAverages.removeAll { $0.id == id }
        movingAverageData.removeValue(forKey: id)
        saveConfiguration()
    }
    
    /// Update a moving average configuration
    func updateMovingAverage(_ config: MovingAverageConfig) {
        if let index = activeIndicators.movingAverages.firstIndex(where: { $0.id == config.id }) {
            activeIndicators.movingAverages[index] = config
            saveConfiguration()
        }
    }
    
    /// Toggle moving average visibility
    func toggleMovingAverage(id: UUID) {
        if let index = activeIndicators.movingAverages.firstIndex(where: { $0.id == id }) {
            activeIndicators.movingAverages[index].isEnabled.toggle()
            if !activeIndicators.movingAverages[index].isEnabled {
                movingAverageData.removeValue(forKey: id)
            }
            saveConfiguration()
        }
    }
    
    // MARK: - RSI Management
    
    /// Enable RSI with configuration
    func enableRSI(config: RSIConfig = RSIConfig()) {
        activeIndicators.rsi = config
        saveConfiguration()
    }
    
    /// Disable RSI
    func disableRSI() {
        activeIndicators.rsi = nil
        rsiData = []
        saveConfiguration()
    }
    
    /// Toggle RSI visibility
    func toggleRSI() {
        if var rsiConfig = activeIndicators.rsi {
            rsiConfig.isEnabled.toggle()
            activeIndicators.rsi = rsiConfig
            if !rsiConfig.isEnabled {
                rsiData = []
            }
        } else {
            enableRSI()
        }
        saveConfiguration()
    }
    
    /// Update RSI configuration
    func updateRSI(_ config: RSIConfig) {
        activeIndicators.rsi = config
        saveConfiguration()
    }
    
    // MARK: - Quick Add Methods (for UI)
    
    /// Check if a specific MA period is already active
    func hasMovingAverage(type: IndicatorType, period: Int) -> Bool {
        activeIndicators.movingAverages.contains { $0.type == type && $0.period == period }
    }
    
    /// Check if RSI is active
    var isRSIActive: Bool {
        activeIndicators.rsi?.isEnabled ?? false
    }
    
    /// Get MA config by ID
    func getMovingAverageConfig(id: UUID) -> MovingAverageConfig? {
        activeIndicators.movingAverages.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private let configKey = "indicatorConfiguration"
    
    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(activeIndicators)
            UserDefaults.standard.set(data, forKey: configKey)
        } catch {
            print("Failed to save indicator configuration: \(error)")
        }
    }
    
    private func loadSavedConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configKey) else { return }
        
        do {
            activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
        } catch {
            print("Failed to load indicator configuration: \(error)")
        }
    }
    
    /// Reset to defaults
    func resetToDefaults() {
        activeIndicators = ActiveIndicators()
        clearAllData()
        UserDefaults.standard.removeObject(forKey: configKey)
    }
}

// MARK: - Convenience Computed Properties

extension IndicatorManager {
    
    /// Total count of active indicators
    var activeIndicatorCount: Int {
        activeIndicators.enabledMovingAverages.count + (isRSIActive ? 1 : 0)
    }
    
    /// Whether the RSI panel should be shown
    var shouldShowRSIPanel: Bool {
        activeIndicators.rsi?.isEnabled ?? false
    }
    
    /// Get RSI value at a specific candle index
    func rsiValue(at candleIndex: Int) -> Double? {
        rsiData.first { $0.candleIndex == candleIndex }?.value
    }
    
    /// Get latest RSI value
    var latestRSI: RSIDataPoint? {
        rsiData.last
    }
    
    /// Get MA value at a specific candle index for a config
    func maValue(configId: UUID, at candleIndex: Int) -> Double? {
        movingAverageData[configId]?.first { $0.candleIndex == candleIndex }?.value
    }
}

// MARK: - Debug Helpers

extension IndicatorManager {
    
    func debugPrintState() {
        print("=== IndicatorManager State ===")
        print("Active MAs: \(activeIndicators.movingAverages.count)")
        for ma in activeIndicators.movingAverages {
            print("  - \(ma.label): enabled=\(ma.isEnabled), dataPoints=\(movingAverageData[ma.id]?.count ?? 0)")
        }
        print("RSI: \(activeIndicators.rsi?.label ?? "disabled"), dataPoints=\(rsiData.count)")
        print("Latest RSI: \(latestRSI?.value ?? 0)")
        print("==============================")
    }
}
