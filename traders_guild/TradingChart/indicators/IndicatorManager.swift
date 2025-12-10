//
//  IndicatorManager.swift
//  traders_guild
//
//  EXPANDED VERSION - Adds MACD/Stochastic management with 2-panel limit enforcement
//

import SwiftUI
import Combine

// MARK: - Indicator Manager

@MainActor
final class IndicatorManager: ObservableObject {
    
    // MARK: - Panel Height Constants
    
    static let minPanelHeight: CGFloat = 80
    static let maxPanelHeight: CGFloat = 250
    static let maxPanelHeightWith2Panels: CGFloat = 180
    
    // MARK: - Published State
    
    @Published var activeIndicators = ActiveIndicators()
    
    /// Computed moving average data (keyed by config ID)
    @Published var movingAverageData: [UUID: [MovingAverageDataPoint]] = [:]
    
    /// Computed Bollinger Bands data
    @Published var bollingerBandsData: [BollingerBandsDataPoint] = []
    
    /// Computed VWAP data
    @Published var vwapData: [VWAPDataPoint] = []
    
    /// Computed RSI data
    @Published var rsiData: [RSIDataPoint] = []
    
    /// Computed MACD data
    @Published var macdData: [MACDDataPoint] = []
    
    /// Computed Stochastic data
    @Published var stochasticData: [StochasticDataPoint] = []
    
    /// Whether calculations are in progress
    @Published var isCalculating: Bool = false
    
    /// Error message (e.g., panel limit reached)
    @Published var errorMessage: String?
    
    // MARK: - Internal State
    
    private var lastCandleCount: Int = 0
    private var lastClosePrice: Double = 0
    
    // MARK: - Initialization
    
    init() {
        loadSavedConfiguration()
    }
    
    // MARK: - Recalculate All Indicators
    
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
        
        // Calculate MACD
        if let macdConfig = activeIndicators.macd, macdConfig.isEnabled {
            macdData = IndicatorCalculator.calculateMACD(
                candles: candles,
                fastPeriod: macdConfig.fastPeriod,
                slowPeriod: macdConfig.slowPeriod,
                signalPeriod: macdConfig.signalPeriod
            )
        } else {
            macdData = []
        }
        
        // Calculate Stochastic
        if let stochConfig = activeIndicators.stochastic, stochConfig.isEnabled {
            stochasticData = IndicatorCalculator.calculateStochastic(
                candles: candles,
                kPeriod: stochConfig.kPeriod,
                dPeriod: stochConfig.dPeriod,
                smoothK: stochConfig.smoothK
            )
        } else {
            stochasticData = []
        }
        
        // Calculate Bollinger Bands
        if let bbConfig = activeIndicators.bollingerBands, bbConfig.isEnabled {
            bollingerBandsData = IndicatorCalculator.calculateBollingerBands(
                candles: candles,
                period: bbConfig.period,
                standardDeviations: bbConfig.standardDeviations
            )
        } else {
            bollingerBandsData = []
        }
        
        // Calculate VWAP
        if let vwapConfig = activeIndicators.vwap, vwapConfig.isEnabled {
            vwapData = IndicatorCalculator.calculateVWAP(
                candles: candles,
                resetDaily: true
            )
        } else {
            vwapData = []
        }
        
        lastCandleCount = candles.count
        if let lastCandle = candles.last {
            lastClosePrice = lastCandle.close
        }
        
        isCalculating = false
    }
    
    func updateWithTick(candles: [Candle]) {
        guard !candles.isEmpty else { return }
        
        if candles.count != lastCandleCount || candles.last?.close != lastClosePrice {
            recalculateIndicators(candles: candles)
        }
    }
    
    func clearAllData() {
        movingAverageData = [:]
        bollingerBandsData = []
        vwapData = []
        rsiData = []
        macdData = []
        stochasticData = []
        lastCandleCount = 0
        lastClosePrice = 0
    }
    
    // MARK: - Moving Average Management
    
    func addMovingAverage(_ config: MovingAverageConfig) {
        guard !activeIndicators.movingAverages.contains(where: { $0.id == config.id }) else { return }
        activeIndicators.movingAverages.append(config)
        saveConfiguration()
    }
    
    func addEMA(period: Int, color: Color = .cyan) {
        let config = MovingAverageConfig(
            type: .ema,
            color: CodableColor(color),
            period: period
        )
        addMovingAverage(config)
    }
    
    func addSMA(period: Int, color: Color = .orange) {
        let config = MovingAverageConfig(
            type: .sma,
            color: CodableColor(color),
            period: period
        )
        addMovingAverage(config)
    }
    
    func removeMovingAverage(id: UUID) {
        activeIndicators.movingAverages.removeAll { $0.id == id }
        movingAverageData.removeValue(forKey: id)
        saveConfiguration()
    }
    
    func updateMovingAverage(_ config: MovingAverageConfig) {
        if let index = activeIndicators.movingAverages.firstIndex(where: { $0.id == config.id }) {
            activeIndicators.movingAverages[index] = config
            saveConfiguration()
        }
    }
    
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
    
    func enableRSI(config: RSIConfig = RSIConfig()) {
        // Check panel limit
        if activeIndicators.rsi == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.rsi = config
        saveConfiguration()
    }
    
    func disableRSI() {
        activeIndicators.rsi = nil
        rsiData = []
        saveConfiguration()
    }
    
    func toggleRSI() {
        if var rsiConfig = activeIndicators.rsi {
            // Toggling off is always allowed
            if rsiConfig.isEnabled {
                rsiConfig.isEnabled = false
                activeIndicators.rsi = rsiConfig
                rsiData = []
            } else {
                // Toggling on - check limit
                if canEnablePanelIndicator(excluding: .rsi) {
                    rsiConfig.isEnabled = true
                    activeIndicators.rsi = rsiConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableRSI()
        }
        saveConfiguration()
    }
    
    func updateRSI(_ config: RSIConfig) {
        activeIndicators.rsi = config
        saveConfiguration()
    }
    
    // MARK: - MACD Management
    
    func enableMACD(config: MACDConfig = MACDConfig()) {
        // Check panel limit
        if activeIndicators.macd == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.macd = config
        saveConfiguration()
    }
    
    func disableMACD() {
        activeIndicators.macd = nil
        macdData = []
        saveConfiguration()
    }
    
    func toggleMACD() {
        if var macdConfig = activeIndicators.macd {
            if macdConfig.isEnabled {
                macdConfig.isEnabled = false
                activeIndicators.macd = macdConfig
                macdData = []
            } else {
                if canEnablePanelIndicator(excluding: .macd) {
                    macdConfig.isEnabled = true
                    activeIndicators.macd = macdConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableMACD()
        }
        saveConfiguration()
    }
    
    func updateMACD(_ config: MACDConfig) {
        activeIndicators.macd = config
        saveConfiguration()
    }
    
    // MARK: - Stochastic Management
    
    func enableStochastic(config: StochasticConfig = StochasticConfig()) {
        // Check panel limit
        if activeIndicators.stochastic == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.stochastic = config
        saveConfiguration()
    }
    
    func disableStochastic() {
        activeIndicators.stochastic = nil
        stochasticData = []
        saveConfiguration()
    }
    
    func toggleStochastic() {
        if var stochConfig = activeIndicators.stochastic {
            if stochConfig.isEnabled {
                stochConfig.isEnabled = false
                activeIndicators.stochastic = stochConfig
                stochasticData = []
            } else {
                if canEnablePanelIndicator(excluding: .stochastic) {
                    stochConfig.isEnabled = true
                    activeIndicators.stochastic = stochConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableStochastic()
        }
        saveConfiguration()
    }
    
    func updateStochastic(_ config: StochasticConfig) {
        activeIndicators.stochastic = config
        saveConfiguration()
    }
    
    // MARK: - Bollinger Bands Management
    
    func enableBollingerBands(config: BollingerBandsConfig = BollingerBandsConfig()) {
        activeIndicators.bollingerBands = config
        saveConfiguration()
    }
    
    func disableBollingerBands() {
        activeIndicators.bollingerBands = nil
        bollingerBandsData = []
        saveConfiguration()
    }
    
    func toggleBollingerBands() {
        if var bbConfig = activeIndicators.bollingerBands {
            bbConfig.isEnabled.toggle()
            activeIndicators.bollingerBands = bbConfig
            if !bbConfig.isEnabled {
                bollingerBandsData = []
            }
        } else {
            enableBollingerBands()
        }
        saveConfiguration()
    }
    
    func updateBollingerBands(_ config: BollingerBandsConfig) {
        activeIndicators.bollingerBands = config
        saveConfiguration()
    }
    
    var isBollingerBandsActive: Bool {
        activeIndicators.bollingerBands?.isEnabled ?? false
    }
    
    // MARK: - VWAP Management
    
    func enableVWAP(config: VWAPConfig = VWAPConfig()) {
        activeIndicators.vwap = config
        saveConfiguration()
    }
    
    func disableVWAP() {
        activeIndicators.vwap = nil
        vwapData = []
        saveConfiguration()
    }
    
    func toggleVWAP() {
        if var vwapConfig = activeIndicators.vwap {
            vwapConfig.isEnabled.toggle()
            activeIndicators.vwap = vwapConfig
            if !vwapConfig.isEnabled {
                vwapData = []
            }
        } else {
            enableVWAP()
        }
        saveConfiguration()
    }
    
    func updateVWAP(_ config: VWAPConfig) {
        activeIndicators.vwap = config
        saveConfiguration()
    }
    
    var isVWAPActive: Bool {
        activeIndicators.vwap?.isEnabled ?? false
    }
    
    // MARK: - Panel Limit Helpers
    
    /// Check if a panel indicator can be enabled, optionally excluding one type from the count
    func canEnablePanelIndicator(excluding: PanelIndicatorType? = nil) -> Bool {
        var count = 0
        
        if activeIndicators.rsi?.isEnabled == true && excluding != .rsi {
            count += 1
        }
        if activeIndicators.macd?.isEnabled == true && excluding != .macd {
            count += 1
        }
        if activeIndicators.stochastic?.isEnabled == true && excluding != .stochastic {
            count += 1
        }
        
        return count < ActiveIndicators.maxPanelIndicators
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Convenience Properties
    
    var isRSIActive: Bool {
        activeIndicators.rsi?.isEnabled ?? false
    }
    
    var isMACDActive: Bool {
        activeIndicators.macd?.isEnabled ?? false
    }
    
    var isStochasticActive: Bool {
        activeIndicators.stochastic?.isEnabled ?? false
    }
    
    var activePanelCount: Int {
        activeIndicators.enabledPanelCount
    }
    
    func hasMovingAverage(type: IndicatorType, period: Int) -> Bool {
        activeIndicators.movingAverages.contains { $0.type == type && $0.period == period }
    }
    
    func getMovingAverageConfig(id: UUID) -> MovingAverageConfig? {
        activeIndicators.movingAverages.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private let configKey = "indicatorConfiguration_v2"
    
    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(activeIndicators)
            UserDefaults.standard.set(data, forKey: configKey)
        } catch {
            print("Failed to save indicator configuration: \(error)")
        }
    }
    
    private func loadSavedConfiguration() {
        // Try v2 first
        if let data = UserDefaults.standard.data(forKey: configKey) {
            do {
                activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
                return
            } catch {
                print("Failed to load v2 config: \(error)")
            }
        }
        
        // Fall back to legacy key
        if let data = UserDefaults.standard.data(forKey: "indicatorConfiguration") {
            do {
                activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
                // Migrate to new key
                saveConfiguration()
            } catch {
                print("Failed to load legacy config: \(error)")
            }
        }
    }
    
    func resetToDefaults() {
        activeIndicators = ActiveIndicators()
        clearAllData()
        UserDefaults.standard.removeObject(forKey: configKey)
        UserDefaults.standard.removeObject(forKey: "indicatorConfiguration")
    }
}

// MARK: - Convenience Computed Properties

extension IndicatorManager {
    
    var activeIndicatorCount: Int {
        activeIndicators.enabledMovingAverages.count +
        (isRSIActive ? 1 : 0) +
        (isMACDActive ? 1 : 0) +
        (isStochasticActive ? 1 : 0)
    }
    
    /// Whether ANY panel should be shown
    var shouldShowAnyPanel: Bool {
        isRSIActive || isMACDActive || isStochasticActive
    }
    
    /// Backward compatibility - whether RSI panel specifically should be shown
    var shouldShowRSIPanel: Bool {
        isRSIActive
    }
    
    var shouldShowMACDPanel: Bool {
        isMACDActive
    }
    
    var shouldShowStochasticPanel: Bool {
        isStochasticActive
    }
    
    // MARK: - Data Access
    
    var latestRSI: RSIDataPoint? {
        rsiData.last
    }
    
    var latestMACD: MACDDataPoint? {
        macdData.last
    }
    
    var latestStochastic: StochasticDataPoint? {
        stochasticData.last
    }
    
    func rsiValue(at candleIndex: Int) -> Double? {
        rsiData.first { $0.candleIndex == candleIndex }?.value
    }
    
    func macdValue(at candleIndex: Int) -> MACDDataPoint? {
        macdData.first { $0.candleIndex == candleIndex }
    }
    
    func stochasticValue(at candleIndex: Int) -> StochasticDataPoint? {
        stochasticData.first { $0.candleIndex == candleIndex }
    }
    
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
        print("MACD: \(activeIndicators.macd?.label ?? "disabled"), dataPoints=\(macdData.count)")
        print("Stochastic: \(activeIndicators.stochastic?.label ?? "disabled"), dataPoints=\(stochasticData.count)")
        print("Panel count: \(activePanelCount)/\(ActiveIndicators.maxPanelIndicators)")
        print("==============================")
    }
}


















////
////  IndicatorManager.swift
////  traders_guild
////
////  Created by Al Hennessey on 05/12/2025.
////
//
////
////  IndicatorManager.swift
////  traders_guild
////
////  Central manager for indicator state, calculations, and persistence
////  Handles computed indicator data and configuration
////
//
//import SwiftUI
//import Combine
//
//// MARK: - Indicator Manager
//
//@MainActor
//final class IndicatorManager: ObservableObject {
//    
//    // MARK: - Published State
//    
//    /// Active indicator configurations
//    @Published var activeIndicators = ActiveIndicators()
//    
//    /// Computed moving average data (keyed by config ID)
//    @Published var movingAverageData: [UUID: [MovingAverageDataPoint]] = [:]
//    
//    /// Computed RSI data
//    @Published var rsiData: [RSIDataPoint] = []
//    
//    /// Whether calculations are in progress
//    @Published var isCalculating: Bool = false
//    
//    /// Error message if calculation fails
//    @Published var errorMessage: String?
//    
//    // MARK: - Internal State
//    
//    /// Cache of last candle count to detect data changes
//    private var lastCandleCount: Int = 0
//    
//    /// Cache of last candle close price for tick updates
//    private var lastClosePrice: Double = 0
//    
//    // MARK: - Initialization
//    
//    init() {
//        loadSavedConfiguration()
//    }
//    
//    // MARK: - Public API
//    
//    /// Recalculate all indicators with new candle data
//    func recalculateIndicators(candles: [Candle]) {
//        guard !candles.isEmpty else {
//            clearAllData()
//            return
//        }
//        
//        isCalculating = true
//        errorMessage = nil
//        
//        // Calculate moving averages
//        let maConfigs = activeIndicators.enabledMovingAverages
//        if !maConfigs.isEmpty {
//            movingAverageData = IndicatorCalculator.calculateAllMovingAverages(
//                candles: candles,
//                configs: maConfigs
//            )
//        } else {
//            movingAverageData = [:]
//        }
//        
//        // Calculate RSI
//        if let rsiConfig = activeIndicators.rsi, rsiConfig.isEnabled {
//            rsiData = IndicatorCalculator.calculateRSI(
//                candles: candles,
//                period: rsiConfig.period
//            )
//        } else {
//            rsiData = []
//        }
//        
//        lastCandleCount = candles.count
//        if let lastCandle = candles.last {
//            lastClosePrice = lastCandle.close
//        }
//        
//        isCalculating = false
//    }
//    
//    /// Update indicators efficiently when only the last candle changes (tick update)
//    func updateWithTick(candles: [Candle]) {
//        guard !candles.isEmpty else { return }
//        
//        // For now, just recalculate everything
//        // In a production app, you'd implement incremental updates
//        if candles.count != lastCandleCount || candles.last?.close != lastClosePrice {
//            recalculateIndicators(candles: candles)
//        }
//    }
//    
//    /// Clear all calculated data
//    func clearAllData() {
//        movingAverageData = [:]
//        rsiData = []
//        lastCandleCount = 0
//        lastClosePrice = 0
//    }
//    
//    // MARK: - Moving Average Management
//    
//    /// Add a new moving average indicator
//    func addMovingAverage(_ config: MovingAverageConfig) {
//        // Prevent duplicates
//        guard !activeIndicators.movingAverages.contains(where: { $0.id == config.id }) else { return }
//        activeIndicators.movingAverages.append(config)
//        saveConfiguration()
//    }
//    
//    /// Add EMA with specific period
//    func addEMA(period: Int, color: Color = .cyan) {
//        let config = MovingAverageConfig(
//            type: .ema,
//            color: CodableColor(color),
//            period: period
//        )
//        addMovingAverage(config)
//    }
//    
//    /// Add SMA with specific period
//    func addSMA(period: Int, color: Color = .orange) {
//        let config = MovingAverageConfig(
//            type: .sma,
//            color: CodableColor(color),
//            period: period
//        )
//        addMovingAverage(config)
//    }
//    
//    /// Remove a moving average by ID
//    func removeMovingAverage(id: UUID) {
//        activeIndicators.movingAverages.removeAll { $0.id == id }
//        movingAverageData.removeValue(forKey: id)
//        saveConfiguration()
//    }
//    
//    /// Update a moving average configuration
//    func updateMovingAverage(_ config: MovingAverageConfig) {
//        if let index = activeIndicators.movingAverages.firstIndex(where: { $0.id == config.id }) {
//            activeIndicators.movingAverages[index] = config
//            saveConfiguration()
//        }
//    }
//    
//    /// Toggle moving average visibility
//    func toggleMovingAverage(id: UUID) {
//        if let index = activeIndicators.movingAverages.firstIndex(where: { $0.id == id }) {
//            activeIndicators.movingAverages[index].isEnabled.toggle()
//            if !activeIndicators.movingAverages[index].isEnabled {
//                movingAverageData.removeValue(forKey: id)
//            }
//            saveConfiguration()
//        }
//    }
//    
//    // MARK: - RSI Management
//    
//    /// Enable RSI with configuration
//    func enableRSI(config: RSIConfig = RSIConfig()) {
//        activeIndicators.rsi = config
//        saveConfiguration()
//    }
//    
//    /// Disable RSI
//    func disableRSI() {
//        activeIndicators.rsi = nil
//        rsiData = []
//        saveConfiguration()
//    }
//    
//    /// Toggle RSI visibility
//    func toggleRSI() {
//        if var rsiConfig = activeIndicators.rsi {
//            rsiConfig.isEnabled.toggle()
//            activeIndicators.rsi = rsiConfig
//            if !rsiConfig.isEnabled {
//                rsiData = []
//            }
//        } else {
//            enableRSI()
//        }
//        saveConfiguration()
//    }
//    
//    /// Update RSI configuration
//    func updateRSI(_ config: RSIConfig) {
//        activeIndicators.rsi = config
//        saveConfiguration()
//    }
//    
//    // MARK: - Quick Add Methods (for UI)
//    
//    /// Check if a specific MA period is already active
//    func hasMovingAverage(type: IndicatorType, period: Int) -> Bool {
//        activeIndicators.movingAverages.contains { $0.type == type && $0.period == period }
//    }
//    
//    /// Check if RSI is active
//    var isRSIActive: Bool {
//        activeIndicators.rsi?.isEnabled ?? false
//    }
//    
//    /// Get MA config by ID
//    func getMovingAverageConfig(id: UUID) -> MovingAverageConfig? {
//        activeIndicators.movingAverages.first { $0.id == id }
//    }
//    
//    // MARK: - Persistence
//    
//    private let configKey = "indicatorConfiguration"
//    
//    private func saveConfiguration() {
//        do {
//            let data = try JSONEncoder().encode(activeIndicators)
//            UserDefaults.standard.set(data, forKey: configKey)
//        } catch {
//            print("Failed to save indicator configuration: \(error)")
//        }
//    }
//    
//    private func loadSavedConfiguration() {
//        guard let data = UserDefaults.standard.data(forKey: configKey) else { return }
//        
//        do {
//            activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
//        } catch {
//            print("Failed to load indicator configuration: \(error)")
//        }
//    }
//    
//    /// Reset to defaults
//    func resetToDefaults() {
//        activeIndicators = ActiveIndicators()
//        clearAllData()
//        UserDefaults.standard.removeObject(forKey: configKey)
//    }
//}
//
//// MARK: - Convenience Computed Properties
//
//extension IndicatorManager {
//    
//    /// Total count of active indicators
//    var activeIndicatorCount: Int {
//        activeIndicators.enabledMovingAverages.count + (isRSIActive ? 1 : 0)
//    }
//    
//    /// Whether the RSI panel should be shown
//    var shouldShowRSIPanel: Bool {
//        activeIndicators.rsi?.isEnabled ?? false
//    }
//    
//    /// Get RSI value at a specific candle index
//    func rsiValue(at candleIndex: Int) -> Double? {
//        rsiData.first { $0.candleIndex == candleIndex }?.value
//    }
//    
//    /// Get latest RSI value
//    var latestRSI: RSIDataPoint? {
//        rsiData.last
//    }
//    
//    /// Get MA value at a specific candle index for a config
//    func maValue(configId: UUID, at candleIndex: Int) -> Double? {
//        movingAverageData[configId]?.first { $0.candleIndex == candleIndex }?.value
//    }
//}
//
//// MARK: - Debug Helpers
//
//extension IndicatorManager {
//    
//    func debugPrintState() {
//        print("=== IndicatorManager State ===")
//        print("Active MAs: \(activeIndicators.movingAverages.count)")
//        for ma in activeIndicators.movingAverages {
//            print("  - \(ma.label): enabled=\(ma.isEnabled), dataPoints=\(movingAverageData[ma.id]?.count ?? 0)")
//        }
//        print("RSI: \(activeIndicators.rsi?.label ?? "disabled"), dataPoints=\(rsiData.count)")
//        print("Latest RSI: \(latestRSI?.value ?? 0)")
//        print("==============================")
//    }
//}
