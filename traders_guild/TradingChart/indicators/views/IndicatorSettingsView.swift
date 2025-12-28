//
//  IndicatorSettingsView.swift
//  traders_guild
//
//  FULL CUSTOMIZATION VERSION - All indicators have settings sheets
//  UPDATED: Now uses UnifiedComponents for consistent styling
//  Categories: Trend, Volatility, Momentum, Volume
//

import SwiftUI

// MARK: - Make IndicatorCategory conform to UnifiedTabItem

extension IndicatorCategory: UnifiedTabItem {
    var title: String { rawValue }
    // icon property is already defined in IndicatorModels.swift
}

// MARK: - Main Settings Content

struct IndicatorSettingsContent: View {
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    
    @State private var selectedCategory: IndicatorCategory = .trend
    @State private var addingIndicatorType: IndicatorType?
    
    // Edit sheet states
    @State private var editingMA: MovingAverageConfig?
    @State private var editingBB = false
    @State private var editingDC = false
    @State private var editingKC = false
    @State private var editingVWAP = false
    @State private var editingSAR = false
    @State private var editingRSI = false
    @State private var editingMACD = false
    @State private var editingStochastic = false
    @State private var editingCCI = false
    @State private var editingWilliamsR = false
    @State private var editingATR = false
    @State private var editingVolume = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Use UnifiedCategoryTabBar for consistent tab styling
            categoryTabs
            
            panelLimitBadge
            
            ScrollView {
                VStack(spacing: 12) {
                    switch selectedCategory {
                    case .trend: trendIndicators
                    case .volatility: volatilityIndicators
                    case .momentum: momentumIndicators
                    case .volume: volumeIndicators
                    }
                }
            }
            
            if let error = indicatorManager.errorMessage {
                errorBanner(error)
            }
        }
        .padding(.top, 16)
        .sheet(item: $addingIndicatorType) { type in
            AddMASheet(indicatorType: type, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
        }
        .sheet(item: $editingMA) { config in
            EditMASheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
        }
        .sheet(isPresented: $editingBB) {
            if let config = indicatorManager.activeIndicators.bollingerBands {
                EditBollingerBandsSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingDC) {
            if let config = indicatorManager.activeIndicators.donchianChannels {
                EditDonchianSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingKC) {
            if let config = indicatorManager.activeIndicators.keltnerChannels {
                EditKeltnerSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingVWAP) {
            if let config = indicatorManager.activeIndicators.vwap {
                EditVWAPSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingSAR) {
            if let config = indicatorManager.activeIndicators.parabolicSAR {
                EditSARSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingRSI) {
            if let config = indicatorManager.activeIndicators.rsi {
                EditRSISheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingMACD) {
            if let config = indicatorManager.activeIndicators.macd {
                EditMACDSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingStochastic) {
            if let config = indicatorManager.activeIndicators.stochastic {
                EditStochasticSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingCCI) {
            if let config = indicatorManager.activeIndicators.cci {
                EditCCISheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingWilliamsR) {
            if let config = indicatorManager.activeIndicators.williamsR {
                EditWilliamsRSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingATR) {
            if let config = indicatorManager.activeIndicators.atr {
                EditATRSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
        .sheet(isPresented: $editingVolume) {
            if let config = indicatorManager.activeIndicators.volume {
                EditVolumeSheet(config: config, indicatorManager: indicatorManager, onRecalculate: onRecalculate)
            }
        }
    }
    
    // MARK: - Category Tabs (Using UnifiedCategoryTabBar)
    
    private var categoryTabs: some View {
        UnifiedCategoryTabBar(
            selectedTab: $selectedCategory,
            theme: .blue,
            spacing: 8
        )
    }
    
    private var panelLimitBadge: some View {
        HStack {
            Text("Panel Indicators")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text("\(indicatorManager.activePanelCount)/2")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(indicatorManager.activePanelCount >= 2 ? .orange : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Trend Indicators
    
    private var trendIndicators: some View {
        VStack(spacing: 8) {
            IndicatorSectionHeader(title: "Moving Averages", icon: "chart.line.uptrend.xyaxis")
            
            ForEach(indicatorManager.activeIndicators.movingAverages) { ma in
                ActiveIndicatorRow(
                    title: ma.label,
                    color: ma.color.color,
                    isActive: ma.isEnabled,
                    onToggle: {
                        indicatorManager.toggleMovingAverage(id: ma.id)
                        onRecalculate()
                    },
                    onEdit: { editingMA = ma },
                    onRemove: {
                        indicatorManager.removeMovingAverage(id: ma.id)
                        onRecalculate()
                    }
                )
            }
            
            HStack(spacing: 8) {
                AddButton(title: "EMA", color: .cyan) { addingIndicatorType = .ema }
                AddButton(title: "SMA", color: .orange) { addingIndicatorType = .sma }
                AddButton(title: "WMA", color: .yellow) { addingIndicatorType = .wma }
                AddButton(title: "HMA", color: .mint) { addingIndicatorType = .hma }
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // VWAP
            IndicatorRowWithEdit(
                title: "VWAP",
                subtitle: indicatorManager.activeIndicators.vwap?.showStandardDeviationBands == true ? "with std bands" : nil,
                icon: "chart.line.flattrend.xyaxis",
                isActive: indicatorManager.isVWAPActive,
                color: indicatorManager.activeIndicators.vwap?.color.color ?? .orange,
                onToggle: {
                    indicatorManager.toggleVWAP()
                    onRecalculate()
                },
                onEdit: indicatorManager.isVWAPActive ? { editingVWAP = true } : nil
            )
            
            // Parabolic SAR
            IndicatorRowWithEdit(
                title: "Parabolic SAR",
                subtitle: nil,
                icon: "circle.dotted",
                isActive: indicatorManager.isParabolicSARActive,
                color: indicatorManager.activeIndicators.parabolicSAR?.bullishColor.color ?? .green,
                onToggle: {
                    indicatorManager.toggleParabolicSAR()
                    onRecalculate()
                },
                onEdit: indicatorManager.isParabolicSARActive ? { editingSAR = true } : nil
            )
        }
    }
    
    // MARK: - Volatility Indicators
    
    private var volatilityIndicators: some View {
        VStack(spacing: 8) {
            IndicatorSectionHeader(title: "Channel Overlays", icon: "arrow.up.and.down")
            
            // Bollinger Bands
            IndicatorRowWithEdit(
                title: "Bollinger Bands",
                subtitle: indicatorManager.activeIndicators.bollingerBands.map { "(\($0.period), \(String(format: "%.1f", $0.standardDeviations))σ)" },
                icon: "arrow.up.and.down",
                isActive: indicatorManager.isBollingerBandsActive,
                color: indicatorManager.activeIndicators.bollingerBands?.upperBandColor.color ?? .pink,
                onToggle: {
                    indicatorManager.toggleBollingerBands()
                    onRecalculate()
                },
                onEdit: indicatorManager.isBollingerBandsActive ? { editingBB = true } : nil
            )
            
            // Donchian Channels
            IndicatorRowWithEdit(
                title: "Donchian Channels",
                subtitle: indicatorManager.activeIndicators.donchianChannels.map { "(\($0.period))" },
                icon: "arrow.up.and.down",
                isActive: indicatorManager.isDonchianChannelsActive,
                color: indicatorManager.activeIndicators.donchianChannels?.upperBandColor.color ?? .blue,
                onToggle: {
                    indicatorManager.toggleDonchianChannels()
                    onRecalculate()
                },
                onEdit: indicatorManager.isDonchianChannelsActive ? { editingDC = true } : nil
            )
            
            // Keltner Channels
            IndicatorRowWithEdit(
                title: "Keltner Channels",
                subtitle: indicatorManager.activeIndicators.keltnerChannels.map { "(\($0.emaPeriod), \($0.atrPeriod))" },
                icon: "arrow.up.and.down",
                isActive: indicatorManager.isKeltnerChannelsActive,
                color: indicatorManager.activeIndicators.keltnerChannels?.color.color ?? .purple,
                onToggle: {
                    indicatorManager.toggleKeltnerChannels()
                    onRecalculate()
                },
                onEdit: indicatorManager.isKeltnerChannelsActive ? { editingKC = true } : nil
            )
            
            Divider().background(Color.gray.opacity(0.3))
            IndicatorSectionHeader(title: "Volatility Panels", icon: "ruler")
            
            // ATR
            PanelIndicatorRowWithEdit(
                title: "ATR",
                subtitle: indicatorManager.activeIndicators.atr.map { "(\($0.period))" },
                icon: "ruler",
                isActive: indicatorManager.isATRActive,
                color: indicatorManager.activeIndicators.atr?.color.color ?? .red,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleATR()
                    onRecalculate()
                },
                onEdit: indicatorManager.isATRActive ? { editingATR = true } : nil
            )
        }
    }
    
    // MARK: - Momentum Indicators
    
    private var momentumIndicators: some View {
        VStack(spacing: 8) {
            IndicatorSectionHeader(title: "Oscillators (Panels)", icon: "waveform.path.ecg")
            
            // RSI
            PanelIndicatorRowWithEdit(
                title: "RSI",
                subtitle: indicatorManager.activeIndicators.rsi.map { "(\($0.period))" },
                icon: "waveform.path.ecg",
                isActive: indicatorManager.isRSIActive,
                color: indicatorManager.activeIndicators.rsi?.color.color ?? .purple,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleRSI()
                    onRecalculate()
                },
                onEdit: indicatorManager.isRSIActive ? { editingRSI = true } : nil
            )
            
            // MACD
            PanelIndicatorRowWithEdit(
                title: "MACD",
                subtitle: indicatorManager.activeIndicators.macd.map { "(\($0.fastPeriod),\($0.slowPeriod),\($0.signalPeriod))" },
                icon: "chart.bar.xaxis",
                isActive: indicatorManager.isMACDActive,
                color: indicatorManager.activeIndicators.macd?.color.color ?? .cyan,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleMACD()
                    onRecalculate()
                },
                onEdit: indicatorManager.isMACDActive ? { editingMACD = true } : nil
            )
            
            // Stochastic
            PanelIndicatorRowWithEdit(
                title: "Stochastic",
                subtitle: indicatorManager.activeIndicators.stochastic.map { "(\($0.kPeriod),\($0.dPeriod))" },
                icon: "waveform.path.ecg.rectangle",
                isActive: indicatorManager.isStochasticActive,
                color: indicatorManager.activeIndicators.stochastic?.color.color ?? .yellow,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleStochastic()
                    onRecalculate()
                },
                onEdit: indicatorManager.isStochasticActive ? { editingStochastic = true } : nil
            )
            
            // CCI
            PanelIndicatorRowWithEdit(
                title: "CCI",
                subtitle: indicatorManager.activeIndicators.cci.map { "(\($0.period))" },
                icon: "arrow.up.arrow.down.circle",
                isActive: indicatorManager.isCCIActive,
                color: indicatorManager.activeIndicators.cci?.color.color ?? .orange,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleCCI()
                    onRecalculate()
                },
                onEdit: indicatorManager.isCCIActive ? { editingCCI = true } : nil
            )
            
            // Williams %R
            PanelIndicatorRowWithEdit(
                title: "Williams %R",
                subtitle: indicatorManager.activeIndicators.williamsR.map { "(\($0.period))" },
                icon: "waveform.path.ecg.rectangle",
                isActive: indicatorManager.isWilliamsRActive,
                color: indicatorManager.activeIndicators.williamsR?.color.color ?? .pink,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleWilliamsR()
                    onRecalculate()
                },
                onEdit: indicatorManager.isWilliamsRActive ? { editingWilliamsR = true } : nil
            )
        }
    }
    
    // MARK: - Volume Indicators
    
    private var volumeIndicators: some View {
        VStack(spacing: 8) {
            IndicatorSectionHeader(title: "Volume Analysis", icon: "chart.bar")
            
            PanelIndicatorRowWithEdit(
                title: "Volume",
                subtitle: indicatorManager.activeIndicators.volume?.showMA == true ? "with MA(\(indicatorManager.activeIndicators.volume?.maPeriod ?? 20))" : nil,
                icon: "chart.bar",
                isActive: indicatorManager.isVolumeActive,
                color: indicatorManager.activeIndicators.volume?.bullishColor.color ?? .green,
                canAdd: indicatorManager.activeIndicators.canAddPanelIndicator,
                onToggle: {
                    indicatorManager.toggleVolume()
                    onRecalculate()
                },
                onEdit: indicatorManager.isVolumeActive ? { editingVolume = true } : nil
            )
        }
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
            Button { indicatorManager.clearError() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Helper Views

struct IndicatorSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct AddButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct ActiveIndicatorRow: View {
    let title: String
    let color: Color
    let isActive: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            Toggle("", isOn: Binding(get: { isActive }, set: { _ in onToggle() }))
                .labelsHidden()
                .scaleEffect(0.8)
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct IndicatorRowWithEdit: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isActive: Bool
    let color: Color
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isActive ? color : .gray)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let onEdit = onEdit, isActive {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }
            
            Button(action: onToggle) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isActive ? color : .gray)
            }
        }
        .padding(12)
        .background(isActive ? color.opacity(0.15) : Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct PanelIndicatorRowWithEdit: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isActive: Bool
    let color: Color
    let canAdd: Bool
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isActive ? color : .gray)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text("PANEL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let onEdit = onEdit, isActive {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }
            
            if !isActive && !canAdd {
                Text("MAX")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            } else {
                Button(action: onToggle) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isActive ? color : .gray)
                }
                .disabled(!isActive && !canAdd)
            }
        }
        .padding(12)
        .background(isActive ? color.opacity(0.15) : Color.white.opacity(0.05))
        .cornerRadius(10)
        .opacity(!isActive && !canAdd ? 0.5 : 1.0)
    }
}

// MARK: - Color Picker Grid

struct ColorPickerGrid: View {
    @Binding var selectedColor: Color
    let colors: [Color] = [.cyan, .yellow, .orange, .red, .pink, .purple, .blue, .green, .mint, .white, .gray]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2))
                    .onTapGesture { selectedColor = color }
            }
        }
    }
}

// MARK: - Add MA Sheet

struct AddMASheet: View {
    let indicatorType: IndicatorType
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int = 20
    @State private var selectedColor: Color = .cyan
    
    private let presets: [Int] = [9, 10, 12, 14, 20, 21, 26, 50, 100, 200]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Period") {
                    Stepper("Period: \(period)", value: $period, in: 2...300)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button("\(preset)") { period = preset }
                                .buttonStyle(.bordered)
                                .tint(period == preset ? .blue : .gray)
                        }
                    }
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
            }
            .navigationTitle("Add \(indicatorType.shortName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let config = MovingAverageConfig(type: indicatorType, color: CodableColor(selectedColor), period: period)
                        indicatorManager.addMovingAverage(config)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit MA Sheet

struct EditMASheet: View {
    let config: MovingAverageConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var selectedColor: Color
    
    init(config: MovingAverageConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _selectedColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Period") {
                    Stepper("Period: \(period)", value: $period, in: 2...300)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $selectedColor)
                }
            }
            .navigationTitle("Edit \(config.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.color = CodableColor(selectedColor)
                        indicatorManager.updateMovingAverage(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Bollinger Bands Sheet

struct EditBollingerBandsSheet: View {
    let config: BollingerBandsConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var stdDev: Double
    @State private var showFill: Bool
    @State private var upperColor: Color
    @State private var lowerColor: Color
    
    init(config: BollingerBandsConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _stdDev = State(initialValue: config.standardDeviations)
        _showFill = State(initialValue: config.showFill)
        _upperColor = State(initialValue: config.upperBandColor.color)
        _lowerColor = State(initialValue: config.lowerBandColor.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("Period: \(period)", value: $period, in: 5...100)
                    HStack {
                        Text("Std Dev: \(String(format: "%.1f", stdDev))")
                        Slider(value: $stdDev, in: 1...4, step: 0.5)
                    }
                    Toggle("Show Fill", isOn: $showFill)
                }
                Section("Upper Band Color") {
                    ColorPickerGrid(selectedColor: $upperColor)
                }
                Section("Lower Band Color") {
                    ColorPickerGrid(selectedColor: $lowerColor)
                }
            }
            .navigationTitle("Bollinger Bands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.standardDeviations = stdDev
                        updated.showFill = showFill
                        updated.upperBandColor = CodableColor(upperColor)
                        updated.lowerBandColor = CodableColor(lowerColor)
                        indicatorManager.updateBollingerBands(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Donchian Sheet

struct EditDonchianSheet: View {
    let config: DonchianChannelsConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var showFill: Bool
    @State private var showMiddle: Bool
    @State private var bandColor: Color
    
    init(config: DonchianChannelsConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _showFill = State(initialValue: config.showFill)
        _showMiddle = State(initialValue: config.showMiddleLine)
        _bandColor = State(initialValue: config.upperBandColor.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("Period: \(period)", value: $period, in: 5...100)
                    Toggle("Show Fill", isOn: $showFill)
                    Toggle("Show Middle Line", isOn: $showMiddle)
                }
                Section("Band Color") {
                    ColorPickerGrid(selectedColor: $bandColor)
                }
            }
            .navigationTitle("Donchian Channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.showFill = showFill
                        updated.showMiddleLine = showMiddle
                        updated.upperBandColor = CodableColor(bandColor)
                        updated.lowerBandColor = CodableColor(bandColor)
                        indicatorManager.updateDonchianChannels(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Keltner Sheet

struct EditKeltnerSheet: View {
    let config: KeltnerChannelsConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var emaPeriod: Int
    @State private var atrPeriod: Int
    @State private var multiplier: Double
    @State private var showFill: Bool
    @State private var bandColor: Color
    
    init(config: KeltnerChannelsConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _emaPeriod = State(initialValue: config.emaPeriod)
        _atrPeriod = State(initialValue: config.atrPeriod)
        _multiplier = State(initialValue: config.atrMultiplier)
        _showFill = State(initialValue: config.showFill)
        _bandColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("EMA Period: \(emaPeriod)", value: $emaPeriod, in: 5...100)
                    Stepper("ATR Period: \(atrPeriod)", value: $atrPeriod, in: 5...50)
                    HStack {
                        Text("Multiplier: \(String(format: "%.1f", multiplier))")
                        Slider(value: $multiplier, in: 1...4, step: 0.5)
                    }
                    Toggle("Show Fill", isOn: $showFill)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $bandColor)
                }
            }
            .navigationTitle("Keltner Channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.emaPeriod = emaPeriod
                        updated.atrPeriod = atrPeriod
                        updated.atrMultiplier = multiplier
                        updated.showFill = showFill
                        updated.color = CodableColor(bandColor)
                        indicatorManager.updateKeltnerChannels(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit VWAP Sheet

struct EditVWAPSheet: View {
    let config: VWAPConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var showBands: Bool
    @State private var lineColor: Color
    
    init(config: VWAPConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _showBands = State(initialValue: config.showStandardDeviationBands)
        _lineColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Toggle("Show Std Dev Bands", isOn: $showBands)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $lineColor)
                }
            }
            .navigationTitle("VWAP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.showStandardDeviationBands = showBands
                        updated.color = CodableColor(lineColor)
                        indicatorManager.updateVWAP(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit SAR Sheet

struct EditSARSheet: View {
    let config: ParabolicSARConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var accStart: Double
    @State private var accMax: Double
    @State private var bullColor: Color
    @State private var bearColor: Color
    
    init(config: ParabolicSARConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _accStart = State(initialValue: config.accelerationStart)
        _accMax = State(initialValue: config.accelerationMax)
        _bullColor = State(initialValue: config.bullishColor.color)
        _bearColor = State(initialValue: config.bearishColor.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Acceleration") {
                    HStack {
                        Text("Start: \(String(format: "%.2f", accStart))")
                        Slider(value: $accStart, in: 0.01...0.1, step: 0.01)
                    }
                    HStack {
                        Text("Max: \(String(format: "%.2f", accMax))")
                        Slider(value: $accMax, in: 0.1...0.5, step: 0.05)
                    }
                }
                Section("Bullish Color") {
                    ColorPickerGrid(selectedColor: $bullColor)
                }
                Section("Bearish Color") {
                    ColorPickerGrid(selectedColor: $bearColor)
                }
            }
            .navigationTitle("Parabolic SAR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.accelerationStart = accStart
                        updated.accelerationMax = accMax
                        updated.bullishColor = CodableColor(bullColor)
                        updated.bearishColor = CodableColor(bearColor)
                        indicatorManager.updateParabolicSAR(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit RSI Sheet

struct EditRSISheet: View {
    let config: RSIConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var overbought: Double
    @State private var oversold: Double
    @State private var lineColor: Color
    
    init(config: RSIConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _overbought = State(initialValue: config.overboughtLevel)
        _oversold = State(initialValue: config.oversoldLevel)
        _lineColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("Period: \(period)", value: $period, in: 2...50)
                    Stepper("Overbought: \(Int(overbought))", value: $overbought, in: 50...90, step: 5)
                    Stepper("Oversold: \(Int(oversold))", value: $oversold, in: 10...50, step: 5)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $lineColor)
                }
            }
            .navigationTitle("RSI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.overboughtLevel = overbought
                        updated.oversoldLevel = oversold
                        updated.color = CodableColor(lineColor)
                        indicatorManager.updateRSI(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit MACD Sheet

struct EditMACDSheet: View {
    let config: MACDConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var fastPeriod: Int
    @State private var slowPeriod: Int
    @State private var signalPeriod: Int
    @State private var macdColor: Color
    @State private var signalColor: Color
    
    init(config: MACDConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _fastPeriod = State(initialValue: config.fastPeriod)
        _slowPeriod = State(initialValue: config.slowPeriod)
        _signalPeriod = State(initialValue: config.signalPeriod)
        _macdColor = State(initialValue: config.color.color)
        _signalColor = State(initialValue: config.signalColor.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Periods") {
                    Stepper("Fast: \(fastPeriod)", value: $fastPeriod, in: 5...20)
                    Stepper("Slow: \(slowPeriod)", value: $slowPeriod, in: 15...50)
                    Stepper("Signal: \(signalPeriod)", value: $signalPeriod, in: 5...20)
                }
                Section("MACD Line Color") {
                    ColorPickerGrid(selectedColor: $macdColor)
                }
                Section("Signal Line Color") {
                    ColorPickerGrid(selectedColor: $signalColor)
                }
            }
            .navigationTitle("MACD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.fastPeriod = fastPeriod
                        updated.slowPeriod = slowPeriod
                        updated.signalPeriod = signalPeriod
                        updated.color = CodableColor(macdColor)
                        updated.signalColor = CodableColor(signalColor)
                        indicatorManager.updateMACD(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Stochastic Sheet

struct EditStochasticSheet: View {
    let config: StochasticConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var kPeriod: Int
    @State private var dPeriod: Int
    @State private var kColor: Color
    @State private var dColor: Color
    
    init(config: StochasticConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _kPeriod = State(initialValue: config.kPeriod)
        _dPeriod = State(initialValue: config.dPeriod)
        _kColor = State(initialValue: config.color.color)
        _dColor = State(initialValue: config.dColor.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Periods") {
                    Stepper("%K Period: \(kPeriod)", value: $kPeriod, in: 5...30)
                    Stepper("%D Period: \(dPeriod)", value: $dPeriod, in: 1...10)
                }
                Section("%K Color") {
                    ColorPickerGrid(selectedColor: $kColor)
                }
                Section("%D Color") {
                    ColorPickerGrid(selectedColor: $dColor)
                }
            }
            .navigationTitle("Stochastic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.kPeriod = kPeriod
                        updated.dPeriod = dPeriod
                        updated.color = CodableColor(kColor)
                        updated.dColor = CodableColor(dColor)
                        indicatorManager.updateStochastic(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit CCI Sheet

struct EditCCISheet: View {
    let config: CCIConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var overbought: Double
    @State private var oversold: Double
    @State private var lineColor: Color
    
    init(config: CCIConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _overbought = State(initialValue: config.overboughtLevel)
        _oversold = State(initialValue: config.oversoldLevel)
        _lineColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("Period: \(period)", value: $period, in: 5...50)
                    Stepper("Overbought: \(Int(overbought))", value: $overbought, in: 50...200, step: 25)
                    Stepper("Oversold: \(Int(oversold))", value: $oversold, in: -200...(-50), step: 25)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $lineColor)
                }
            }
            .navigationTitle("CCI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.overboughtLevel = overbought
                        updated.oversoldLevel = oversold
                        updated.color = CodableColor(lineColor)
                        indicatorManager.updateCCI(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Williams %R Sheet

struct EditWilliamsRSheet: View {
    let config: WilliamsRConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var lineColor: Color
    
    init(config: WilliamsRConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _lineColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("Period: \(period)", value: $period, in: 5...30)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $lineColor)
                }
            }
            .navigationTitle("Williams %R")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.color = CodableColor(lineColor)
                        indicatorManager.updateWilliamsR(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit ATR Sheet

struct EditATRSheet: View {
    let config: ATRConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var period: Int
    @State private var lineColor: Color
    
    init(config: ATRConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _period = State(initialValue: config.period)
        _lineColor = State(initialValue: config.color.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Settings") {
                    Stepper("Period: \(period)", value: $period, in: 5...30)
                }
                Section("Color") {
                    ColorPickerGrid(selectedColor: $lineColor)
                }
            }
            .navigationTitle("ATR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.period = period
                        updated.color = CodableColor(lineColor)
                        indicatorManager.updateATR(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Volume Sheet

struct EditVolumeSheet: View {
    let config: VolumeConfig
    @ObservedObject var indicatorManager: IndicatorManager
    var onRecalculate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var showMA: Bool
    @State private var maPeriod: Int
    @State private var bullColor: Color
    @State private var bearColor: Color
    
    init(config: VolumeConfig, indicatorManager: IndicatorManager, onRecalculate: @escaping () -> Void) {
        self.config = config
        self.indicatorManager = indicatorManager
        self.onRecalculate = onRecalculate
        _showMA = State(initialValue: config.showMA)
        _maPeriod = State(initialValue: config.maPeriod)
        _bullColor = State(initialValue: config.bullishColor.color)
        _bearColor = State(initialValue: config.bearishColor.color)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Moving Average") {
                    Toggle("Show Volume MA", isOn: $showMA)
                    if showMA {
                        Stepper("MA Period: \(maPeriod)", value: $maPeriod, in: 5...50)
                    }
                }
                Section("Bullish Color") {
                    ColorPickerGrid(selectedColor: $bullColor)
                }
                Section("Bearish Color") {
                    ColorPickerGrid(selectedColor: $bearColor)
                }
            }
            .navigationTitle("Volume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.showMA = showMA
                        updated.maPeriod = maPeriod
                        updated.bullishColor = CodableColor(bullColor)
                        updated.bearishColor = CodableColor(bearColor)
                        indicatorManager.updateVolume(updated)
                        onRecalculate()
                        dismiss()
                    }
                }
            }
        }
    }
}
