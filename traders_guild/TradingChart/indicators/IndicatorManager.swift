//
//  IndicatorManager.swift
//  traders_guild
//
//  EXPANDED VERSION - Full indicator support with categorized indicators
//  Supports: Trend, Volatility, Momentum, Volume indicators
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
    
    // MARK: - Trend Overlay Data
    
    /// Computed moving average data (keyed by config ID) - EMA, SMA, WMA, HMA
    @Published var movingAverageData: [UUID: [MovingAverageDataPoint]] = [:]
    
    /// Computed VWAP data
    @Published var vwapData: [VWAPDataPoint] = []
    
    /// Computed Parabolic SAR data
    @Published var parabolicSARData: [ParabolicSARDataPoint] = []
    
    // MARK: - Volatility Overlay Data
    
    /// Computed Bollinger Bands data
    @Published var bollingerBandsData: [BollingerBandsDataPoint] = []
    
    /// Computed Donchian Channels data
    @Published var donchianChannelsData: [DonchianChannelsDataPoint] = []
    
    /// Computed Keltner Channels data
    @Published var keltnerChannelsData: [KeltnerChannelsDataPoint] = []
    
    // MARK: - Momentum Panel Data
    
    /// Computed RSI data
    @Published var rsiData: [RSIDataPoint] = []
    
    /// Computed MACD data
    @Published var macdData: [MACDDataPoint] = []
    
    /// Computed Stochastic data
    @Published var stochasticData: [StochasticDataPoint] = []
    
    /// Computed CCI data
    @Published var cciData: [CCIDataPoint] = []
    
    /// Computed Williams %R data
    @Published var williamsRData: [WilliamsRDataPoint] = []
    
    // MARK: - Volatility Panel Data
    
    /// Computed ATR data
    @Published var atrData: [ATRDataPoint] = []
    
    // MARK: - Volume Panel Data
    
    /// Computed Volume data
    @Published var volumeData: [VolumeDataPoint] = []
    
    // MARK: - Status
    
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
    
    func recalculateIndicators(candles: [RLCandleDTO]) {
        guard !candles.isEmpty else {
            clearAllData()
            return
        }
        
        isCalculating = true
        errorMessage = nil
        
        // === TREND OVERLAYS ===
        
        // Calculate moving averages (EMA, SMA, WMA, HMA)
        let maConfigs = activeIndicators.enabledMovingAverages
        if !maConfigs.isEmpty {
            movingAverageData = calculateAllMovingAverages(candles: candles, configs: maConfigs)
        } else {
            movingAverageData = [:]
        }
        
        // Calculate VWAP
        if let vwapConfig = activeIndicators.vwap, vwapConfig.isEnabled {
            vwapData = IndicatorCalculator.calculateVWAP(candles: candles, resetDaily: true)
        } else {
            vwapData = []
        }
        
        // Calculate Parabolic SAR
        if let sarConfig = activeIndicators.parabolicSAR, sarConfig.isEnabled {
            parabolicSARData = IndicatorCalculator.calculateParabolicSAR(
                candles: candles,
                accelerationStart: sarConfig.accelerationStart,
                accelerationIncrement: sarConfig.accelerationIncrement,
                accelerationMax: sarConfig.accelerationMax
            )
        } else {
            parabolicSARData = []
        }
        
        // === VOLATILITY OVERLAYS ===
        
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
        
        // Calculate Donchian Channels
        if let dcConfig = activeIndicators.donchianChannels, dcConfig.isEnabled {
            donchianChannelsData = IndicatorCalculator.calculateDonchianChannels(
                candles: candles,
                period: dcConfig.period
            )
        } else {
            donchianChannelsData = []
        }
        
        // Calculate Keltner Channels
        if let kcConfig = activeIndicators.keltnerChannels, kcConfig.isEnabled {
            keltnerChannelsData = IndicatorCalculator.calculateKeltnerChannels(
                candles: candles,
                emaPeriod: kcConfig.emaPeriod,
                atrPeriod: kcConfig.atrPeriod,
                atrMultiplier: kcConfig.atrMultiplier
            )
        } else {
            keltnerChannelsData = []
        }
        
        // === MOMENTUM PANELS ===
        
        // Calculate RSI
        if let rsiConfig = activeIndicators.rsi, rsiConfig.isEnabled {
            rsiData = IndicatorCalculator.calculateRSI(candles: candles, period: rsiConfig.period)
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
        
        // Calculate CCI
        if let cciConfig = activeIndicators.cci, cciConfig.isEnabled {
            cciData = IndicatorCalculator.calculateCCI(candles: candles, period: cciConfig.period)
        } else {
            cciData = []
        }
        
        // Calculate Williams %R
        if let wrConfig = activeIndicators.williamsR, wrConfig.isEnabled {
            williamsRData = IndicatorCalculator.calculateWilliamsR(candles: candles, period: wrConfig.period)
        } else {
            williamsRData = []
        }
        
        // === VOLATILITY PANELS ===
        
        // Calculate ATR
        if let atrConfig = activeIndicators.atr, atrConfig.isEnabled {
            atrData = IndicatorCalculator.calculateATR(candles: candles, period: atrConfig.period)
        } else {
            atrData = []
        }
        
        // === VOLUME PANELS ===
        
        // Calculate Volume
        if let volConfig = activeIndicators.volume, volConfig.isEnabled {
            volumeData = IndicatorCalculator.calculateVolume(candles: candles, maPeriod: volConfig.maPeriod)
        } else {
            volumeData = []
        }
        
        lastCandleCount = candles.count
        if let lastCandle = candles.last {
            lastClosePrice = lastCandle.close
        }
        
        isCalculating = false
    }
    
    /// Helper to calculate all MA types
    private func calculateAllMovingAverages(candles: [RLCandleDTO], configs: [MovingAverageConfig]) -> [UUID: [MovingAverageDataPoint]] {
        var results: [UUID: [MovingAverageDataPoint]] = [:]
        
        for config in configs where config.isEnabled {
            let data: [MovingAverageDataPoint]
            
            switch config.type {
            case .ema:
                data = IndicatorCalculator.calculateEMA(candles: candles, period: config.period, priceSource: config.priceSource)
            case .sma:
                data = IndicatorCalculator.calculateSMA(candles: candles, period: config.period, priceSource: config.priceSource)
            case .wma:
                data = IndicatorCalculator.calculateWMA(candles: candles, period: config.period, priceSource: config.priceSource)
            case .hma:
                data = IndicatorCalculator.calculateHMA(candles: candles, period: config.period, priceSource: config.priceSource)
            default:
                data = []
            }
            
            results[config.id] = data
        }
        
        return results
    }
    
    func updateWithTick(candles: [RLCandleDTO]) {
        guard !candles.isEmpty else { return }
        
        if candles.count != lastCandleCount || candles.last?.close != lastClosePrice {
            recalculateIndicators(candles: candles)
        }
    }
    
    func clearAllData() {
        movingAverageData = [:]
        vwapData = []
        parabolicSARData = []
        bollingerBandsData = []
        donchianChannelsData = []
        keltnerChannelsData = []
        rsiData = []
        macdData = []
        stochasticData = []
        cciData = []
        williamsRData = []
        atrData = []
        volumeData = []
        lastCandleCount = 0
        lastClosePrice = 0
    }
    
    // MARK: - Moving Average Management (EMA, SMA, WMA, HMA)
    
    func addMovingAverage(_ config: MovingAverageConfig) {
        guard !activeIndicators.movingAverages.contains(where: { $0.id == config.id }) else { return }
        activeIndicators.movingAverages.append(config)
        saveConfiguration()
    }
    
    func addEMA(period: Int, color: Color = .cyan) {
        let config = MovingAverageConfig(type: .ema, color: CodableColor(color), period: period)
        addMovingAverage(config)
    }
    
    func addSMA(period: Int, color: Color = .orange) {
        let config = MovingAverageConfig(type: .sma, color: CodableColor(color), period: period)
        addMovingAverage(config)
    }
    
    func addWMA(period: Int, color: Color = .yellow) {
        let config = MovingAverageConfig(type: .wma, color: CodableColor(color), period: period)
        addMovingAverage(config)
    }
    
    func addHMA(period: Int, color: Color = .mint) {
        let config = MovingAverageConfig(type: .hma, color: CodableColor(color), period: period)
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
            if !vwapConfig.isEnabled { vwapData = [] }
        } else {
            enableVWAP()
        }
        saveConfiguration()
    }
    
    func updateVWAP(_ config: VWAPConfig) {
        activeIndicators.vwap = config
        saveConfiguration()
    }
    
    var isVWAPActive: Bool { activeIndicators.vwap?.isEnabled ?? false }
    
    // MARK: - Parabolic SAR Management
    
    func enableParabolicSAR(config: ParabolicSARConfig = ParabolicSARConfig()) {
        activeIndicators.parabolicSAR = config
        saveConfiguration()
    }
    
    func disableParabolicSAR() {
        activeIndicators.parabolicSAR = nil
        parabolicSARData = []
        saveConfiguration()
    }
    
    func toggleParabolicSAR() {
        if var sarConfig = activeIndicators.parabolicSAR {
            sarConfig.isEnabled.toggle()
            activeIndicators.parabolicSAR = sarConfig
            if !sarConfig.isEnabled { parabolicSARData = [] }
        } else {
            enableParabolicSAR()
        }
        saveConfiguration()
    }
    
    func updateParabolicSAR(_ config: ParabolicSARConfig) {
        activeIndicators.parabolicSAR = config
        saveConfiguration()
    }
    
    var isParabolicSARActive: Bool { activeIndicators.parabolicSAR?.isEnabled ?? false }
    
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
            if !bbConfig.isEnabled { bollingerBandsData = [] }
        } else {
            enableBollingerBands()
        }
        saveConfiguration()
    }
    
    func updateBollingerBands(_ config: BollingerBandsConfig) {
        activeIndicators.bollingerBands = config
        saveConfiguration()
    }
    
    var isBollingerBandsActive: Bool { activeIndicators.bollingerBands?.isEnabled ?? false }
    
    // MARK: - Donchian Channels Management
    
    func enableDonchianChannels(config: DonchianChannelsConfig = DonchianChannelsConfig()) {
        activeIndicators.donchianChannels = config
        saveConfiguration()
    }
    
    func disableDonchianChannels() {
        activeIndicators.donchianChannels = nil
        donchianChannelsData = []
        saveConfiguration()
    }
    
    func toggleDonchianChannels() {
        if var dcConfig = activeIndicators.donchianChannels {
            dcConfig.isEnabled.toggle()
            activeIndicators.donchianChannels = dcConfig
            if !dcConfig.isEnabled { donchianChannelsData = [] }
        } else {
            enableDonchianChannels()
        }
        saveConfiguration()
    }
    
    func updateDonchianChannels(_ config: DonchianChannelsConfig) {
        activeIndicators.donchianChannels = config
        saveConfiguration()
    }
    
    var isDonchianChannelsActive: Bool { activeIndicators.donchianChannels?.isEnabled ?? false }
    
    // MARK: - Keltner Channels Management
    
    func enableKeltnerChannels(config: KeltnerChannelsConfig = KeltnerChannelsConfig()) {
        activeIndicators.keltnerChannels = config
        saveConfiguration()
    }
    
    func disableKeltnerChannels() {
        activeIndicators.keltnerChannels = nil
        keltnerChannelsData = []
        saveConfiguration()
    }
    
    func toggleKeltnerChannels() {
        if var kcConfig = activeIndicators.keltnerChannels {
            kcConfig.isEnabled.toggle()
            activeIndicators.keltnerChannels = kcConfig
            if !kcConfig.isEnabled { keltnerChannelsData = [] }
        } else {
            enableKeltnerChannels()
        }
        saveConfiguration()
    }
    
    func updateKeltnerChannels(_ config: KeltnerChannelsConfig) {
        activeIndicators.keltnerChannels = config
        saveConfiguration()
    }
    
    var isKeltnerChannelsActive: Bool { activeIndicators.keltnerChannels?.isEnabled ?? false }
    
    // MARK: - RSI Management
    
    func enableRSI(config: RSIConfig = RSIConfig()) {
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
            if rsiConfig.isEnabled {
                rsiConfig.isEnabled = false
                activeIndicators.rsi = rsiConfig
                rsiData = []
            } else {
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
    
    var isRSIActive: Bool { activeIndicators.rsi?.isEnabled ?? false }
    
    // MARK: - MACD Management
    
    func enableMACD(config: MACDConfig = MACDConfig()) {
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
    
    var isMACDActive: Bool { activeIndicators.macd?.isEnabled ?? false }
    
    // MARK: - Stochastic Management
    
    func enableStochastic(config: StochasticConfig = StochasticConfig()) {
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
    
    var isStochasticActive: Bool { activeIndicators.stochastic?.isEnabled ?? false }
    
    // MARK: - CCI Management
    
    func enableCCI(config: CCIConfig = CCIConfig()) {
        if activeIndicators.cci == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.cci = config
        saveConfiguration()
    }
    
    func disableCCI() {
        activeIndicators.cci = nil
        cciData = []
        saveConfiguration()
    }
    
    func toggleCCI() {
        if var cciConfig = activeIndicators.cci {
            if cciConfig.isEnabled {
                cciConfig.isEnabled = false
                activeIndicators.cci = cciConfig
                cciData = []
            } else {
                if canEnablePanelIndicator(excluding: .cci) {
                    cciConfig.isEnabled = true
                    activeIndicators.cci = cciConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableCCI()
        }
        saveConfiguration()
    }
    
    func updateCCI(_ config: CCIConfig) {
        activeIndicators.cci = config
        saveConfiguration()
    }
    
    var isCCIActive: Bool { activeIndicators.cci?.isEnabled ?? false }
    
    // MARK: - Williams %R Management
    
    func enableWilliamsR(config: WilliamsRConfig = WilliamsRConfig()) {
        if activeIndicators.williamsR == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.williamsR = config
        saveConfiguration()
    }
    
    func disableWilliamsR() {
        activeIndicators.williamsR = nil
        williamsRData = []
        saveConfiguration()
    }
    
    func toggleWilliamsR() {
        if var wrConfig = activeIndicators.williamsR {
            if wrConfig.isEnabled {
                wrConfig.isEnabled = false
                activeIndicators.williamsR = wrConfig
                williamsRData = []
            } else {
                if canEnablePanelIndicator(excluding: .williamsR) {
                    wrConfig.isEnabled = true
                    activeIndicators.williamsR = wrConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableWilliamsR()
        }
        saveConfiguration()
    }
    
    func updateWilliamsR(_ config: WilliamsRConfig) {
        activeIndicators.williamsR = config
        saveConfiguration()
    }
    
    var isWilliamsRActive: Bool { activeIndicators.williamsR?.isEnabled ?? false }
    
    // MARK: - ATR Management
    
    func enableATR(config: ATRConfig = ATRConfig()) {
        if activeIndicators.atr == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.atr = config
        saveConfiguration()
    }
    
    func disableATR() {
        activeIndicators.atr = nil
        atrData = []
        saveConfiguration()
    }
    
    func toggleATR() {
        if var atrConfig = activeIndicators.atr {
            if atrConfig.isEnabled {
                atrConfig.isEnabled = false
                activeIndicators.atr = atrConfig
                atrData = []
            } else {
                if canEnablePanelIndicator(excluding: .atr) {
                    atrConfig.isEnabled = true
                    activeIndicators.atr = atrConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableATR()
        }
        saveConfiguration()
    }
    
    func updateATR(_ config: ATRConfig) {
        activeIndicators.atr = config
        saveConfiguration()
    }
    
    var isATRActive: Bool { activeIndicators.atr?.isEnabled ?? false }
    
    // MARK: - Volume Management
    
    func enableVolume(config: VolumeConfig = VolumeConfig()) {
        if activeIndicators.volume == nil && !activeIndicators.canAddPanelIndicator {
            errorMessage = "Maximum 2 panel indicators allowed. Disable one first."
            return
        }
        activeIndicators.volume = config
        saveConfiguration()
    }
    
    func disableVolume() {
        activeIndicators.volume = nil
        volumeData = []
        saveConfiguration()
    }
    
    func toggleVolume() {
        if var volConfig = activeIndicators.volume {
            if volConfig.isEnabled {
                volConfig.isEnabled = false
                activeIndicators.volume = volConfig
                volumeData = []
            } else {
                if canEnablePanelIndicator(excluding: .volume) {
                    volConfig.isEnabled = true
                    activeIndicators.volume = volConfig
                } else {
                    errorMessage = "Maximum 2 panel indicators allowed."
                }
            }
        } else {
            enableVolume()
        }
        saveConfiguration()
    }
    
    func updateVolume(_ config: VolumeConfig) {
        activeIndicators.volume = config
        saveConfiguration()
    }
    
    var isVolumeActive: Bool { activeIndicators.volume?.isEnabled ?? false }
    
    // MARK: - Panel Limit Helpers
    
    /// Check if a panel indicator can be enabled, optionally excluding one type from the count
    func canEnablePanelIndicator(excluding: PanelIndicatorType? = nil) -> Bool {
        var count = 0
        
        if activeIndicators.rsi?.isEnabled == true && excluding != .rsi { count += 1 }
        if activeIndicators.macd?.isEnabled == true && excluding != .macd { count += 1 }
        if activeIndicators.stochastic?.isEnabled == true && excluding != .stochastic { count += 1 }
        if activeIndicators.cci?.isEnabled == true && excluding != .cci { count += 1 }
        if activeIndicators.williamsR?.isEnabled == true && excluding != .williamsR { count += 1 }
        if activeIndicators.atr?.isEnabled == true && excluding != .atr { count += 1 }
        if activeIndicators.volume?.isEnabled == true && excluding != .volume { count += 1 }
        
        return count < ActiveIndicators.maxPanelIndicators
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Convenience Properties
    
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
    
    private let configKey = "indicatorConfiguration_v3"
    
    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(activeIndicators)
            UserDefaults.standard.set(data, forKey: configKey)
        } catch {
            print("Failed to save indicator configuration: \(error)")
        }
    }
    
    private func loadSavedConfiguration() {
        // Try v3 first
        if let data = UserDefaults.standard.data(forKey: configKey) {
            do {
                activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
                return
            } catch {
                print("Failed to load v3 config: \(error)")
            }
        }
        
        // Fall back to v2
        if let data = UserDefaults.standard.data(forKey: "indicatorConfiguration_v2") {
            do {
                activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
                saveConfiguration()
                return
            } catch {
                print("Failed to load v2 config: \(error)")
            }
        }
        
        // Fall back to legacy key
        if let data = UserDefaults.standard.data(forKey: "indicatorConfiguration") {
            do {
                activeIndicators = try JSONDecoder().decode(ActiveIndicators.self, from: data)
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
        UserDefaults.standard.removeObject(forKey: "indicatorConfiguration_v2")
        UserDefaults.standard.removeObject(forKey: "indicatorConfiguration")
    }
}

// MARK: - Convenience Computed Properties

extension IndicatorManager {
    
    var activeIndicatorCount: Int {
        activeIndicators.enabledMovingAverages.count +
        (isVWAPActive ? 1 : 0) +
        (isParabolicSARActive ? 1 : 0) +
        (isBollingerBandsActive ? 1 : 0) +
        (isDonchianChannelsActive ? 1 : 0) +
        (isKeltnerChannelsActive ? 1 : 0) +
        (isRSIActive ? 1 : 0) +
        (isMACDActive ? 1 : 0) +
        (isStochasticActive ? 1 : 0) +
        (isCCIActive ? 1 : 0) +
        (isWilliamsRActive ? 1 : 0) +
        (isATRActive ? 1 : 0) +
        (isVolumeActive ? 1 : 0)
    }
    
    /// Whether ANY panel should be shown
    var shouldShowAnyPanel: Bool {
        isRSIActive || isMACDActive || isStochasticActive ||
        isCCIActive || isWilliamsRActive || isATRActive || isVolumeActive
    }
    
    /// Backward compatibility - whether RSI panel specifically should be shown
    var shouldShowRSIPanel: Bool { isRSIActive }
    var shouldShowMACDPanel: Bool { isMACDActive }
    var shouldShowStochasticPanel: Bool { isStochasticActive }
    var shouldShowCCIPanel: Bool { isCCIActive }
    var shouldShowWilliamsRPanel: Bool { isWilliamsRActive }
    var shouldShowATRPanel: Bool { isATRActive }
    var shouldShowVolumePanel: Bool { isVolumeActive }
    
    // MARK: - Data Access
    
    var latestRSI: RSIDataPoint? { rsiData.last }
    var latestMACD: MACDDataPoint? { macdData.last }
    var latestStochastic: StochasticDataPoint? { stochasticData.last }
    var latestCCI: CCIDataPoint? { cciData.last }
    var latestWilliamsR: WilliamsRDataPoint? { williamsRData.last }
    var latestATR: ATRDataPoint? { atrData.last }
    
    func rsiValue(at candleIndex: Int) -> Double? {
        rsiData.first { $0.candleIndex == candleIndex }?.value
    }
    
    func macdValue(at candleIndex: Int) -> MACDDataPoint? {
        macdData.first { $0.candleIndex == candleIndex }
    }
    
    func stochasticValue(at candleIndex: Int) -> StochasticDataPoint? {
        stochasticData.first { $0.candleIndex == candleIndex }
    }
    
    func cciValue(at candleIndex: Int) -> Double? {
        cciData.first { $0.candleIndex == candleIndex }?.value
    }
    
    func williamsRValue(at candleIndex: Int) -> Double? {
        williamsRData.first { $0.candleIndex == candleIndex }?.value
    }
    
    func atrValue(at candleIndex: Int) -> Double? {
        atrData.first { $0.candleIndex == candleIndex }?.value
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
        print("VWAP: \(isVWAPActive), dataPoints=\(vwapData.count)")
        print("Parabolic SAR: \(isParabolicSARActive), dataPoints=\(parabolicSARData.count)")
        print("Bollinger Bands: \(isBollingerBandsActive), dataPoints=\(bollingerBandsData.count)")
        print("Donchian: \(isDonchianChannelsActive), dataPoints=\(donchianChannelsData.count)")
        print("Keltner: \(isKeltnerChannelsActive), dataPoints=\(keltnerChannelsData.count)")
        print("RSI: \(isRSIActive), dataPoints=\(rsiData.count)")
        print("MACD: \(isMACDActive), dataPoints=\(macdData.count)")
        print("Stochastic: \(isStochasticActive), dataPoints=\(stochasticData.count)")
        print("CCI: \(isCCIActive), dataPoints=\(cciData.count)")
        print("Williams %R: \(isWilliamsRActive), dataPoints=\(williamsRData.count)")
        print("ATR: \(isATRActive), dataPoints=\(atrData.count)")
        print("Volume: \(isVolumeActive), dataPoints=\(volumeData.count)")
        print("Panel count: \(activePanelCount)/\(ActiveIndicators.maxPanelIndicators)")
        print("==============================")
    }
}







