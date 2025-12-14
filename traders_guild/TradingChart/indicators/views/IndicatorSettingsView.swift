//
//  IndicatorSettingsView.swift
//  traders_guild
//
//  FULL CUSTOMIZATION VERSION - All indicators have settings sheets
//  Categories: Trend, Volatility, Momentum, Volume
//

import SwiftUI

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
    
    // MARK: - Category Tabs
    
    private var categoryTabs: some View {
        HStack(spacing: 8) {
            ForEach(IndicatorCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategory = category
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                        Text(category.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedCategory == category ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                    .foregroundColor(selectedCategory == category ? .white : .gray)
                    .cornerRadius(8)
                }
            }
        }
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
                .cornerRadius(4)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Trend Indicators
    
    private var trendIndicators: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Moving Averages", icon: "chart.line.uptrend.xyaxis")
            
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
            SectionHeader(title: "Channel Overlays", icon: "arrow.up.and.down")
            
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
            SectionHeader(title: "Volatility Panels", icon: "ruler")
            
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
            SectionHeader(title: "Oscillators (Panels)", icon: "waveform.path.ecg")
            
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
            SectionHeader(title: "Volume Analysis", icon: "chart.bar")
            
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
        .cornerRadius(8)
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
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
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .cornerRadius(6)
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
        .cornerRadius(8)
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
                        .cornerRadius(3)
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
                    .cornerRadius(4)
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










////
////  IndicatorSettingsView.swift
////  traders_guild
////
////  EXPANDED VERSION - Full support for EMA, SMA, BB, VWAP, RSI, MACD, Stochastic
////
//
//import SwiftUI
//
//// MARK: - Main Settings Content
//
//struct IndicatorSettingsContent: View {
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onRecalculate: () -> Void
//    
//    // Add sheets
//    @State private var showEMASheet = false
//    @State private var showSMASheet = false
//    @State private var showBBSheet = false
//    @State private var showVWAPSheet = false
//    @State private var showRSISheet = false
//    @State private var showMACDSheet = false
//    @State private var showStochasticSheet = false
//    
//    // Edit sheets
//    @State private var editingMAConfig: MovingAverageConfig?
//    @State private var editingBBConfig: BollingerBandsConfig?
//    @State private var editingVWAPConfig: VWAPConfig?
//    @State private var editingRSIConfig: RSIConfig?
//    @State private var editingMACDConfig: MACDConfig?
//    @State private var editingStochasticConfig: StochasticConfig?
//    
//    @State private var showLimitAlert = false
//    
//    private var hasAnyIndicators: Bool {
//        !indicatorManager.activeIndicators.movingAverages.isEmpty ||
//        indicatorManager.activeIndicators.bollingerBands != nil ||
//        indicatorManager.activeIndicators.vwap != nil ||
//        indicatorManager.activeIndicators.rsi != nil ||
//        indicatorManager.activeIndicators.macd != nil ||
//        indicatorManager.activeIndicators.stochastic != nil
//    }
//    
//    var body: some View {
//        ScrollView(.vertical, showsIndicators: true) {
//            VStack(spacing: 20) {
//                headerSection
//                limitsIndicator
//                overlayIndicatorsSection
//                panelIndicatorsSection
//                
//                if hasAnyIndicators {
//                    activeIndicatorsSection
//                } else {
//                    emptyStateView
//                }
//                
//                Spacer().frame(height: 60)
//            }
//            .padding(.horizontal, 16)
//            .padding(.top, 8)
//        }
//        .alert("Panel Limit Reached", isPresented: $showLimitAlert) {
//            Button("OK", role: .cancel) { }
//        } message: {
//            Text("Maximum 2 panel indicators allowed. Disable or remove an existing panel indicator first.")
//        }
//        .onChange(of: indicatorManager.errorMessage) { _, newValue in
//            if newValue != nil {
//                showLimitAlert = true
//                indicatorManager.clearError()
//            }
//        }
//    }
//    
//    // MARK: - Header
//    
//    private var headerSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Text("Indicators")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                    .foregroundColor(.white)
//                
//                Spacer()
//                
//                if hasAnyIndicators {
//                    Text("\(indicatorManager.activeIndicatorCount) active")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 4)
//                        .background(Color.white.opacity(0.1))
//                        .cornerRadius(10)
//                }
//            }
//            
//            Text("Add technical indicators to enhance your chart analysis")
//                .font(.caption)
//                .foregroundColor(.gray)
//        }
//    }
//    
//    // MARK: - Limits
//    
//    private var limitsIndicator: some View {
//        HStack(spacing: 12) {
//            LimitBadge(label: "Overlays", current: indicatorManager.activeIndicators.enabledMovingAverages.count + (indicatorManager.isBollingerBandsActive ? 1 : 0) + (indicatorManager.isVWAPActive ? 1 : 0), max: nil, color: .cyan)
//            LimitBadge(label: "Panels", current: indicatorManager.activePanelCount, max: ActiveIndicators.maxPanelIndicators, color: indicatorManager.activePanelCount >= ActiveIndicators.maxPanelIndicators ? .orange : .purple)
//        }
//        .padding(.vertical, 8)
//    }
//    
//    // MARK: - Overlay Indicators
//    
//    private var overlayIndicatorsSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Overlay Indicators")
//                .font(.subheadline)
//                .fontWeight(.semibold)
//                .foregroundColor(.white.opacity(0.7))
//            
//            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
//                AddIndicatorButton(title: "EMA", subtitle: "Exponential MA", icon: "chart.line.uptrend.xyaxis", color: .cyan) {
//                    showEMASheet = true
//                }
//                AddIndicatorButton(title: "SMA", subtitle: "Simple MA", icon: "chart.line.uptrend.xyaxis", color: .orange) {
//                    showSMASheet = true
//                }
//                AddIndicatorButton(title: "Bollinger", subtitle: "Bands", icon: "arrow.up.and.down", color: .pink, isActive: indicatorManager.isBollingerBandsActive) {
//                    if indicatorManager.isBollingerBandsActive {
//                        editingBBConfig = indicatorManager.activeIndicators.bollingerBands
//                    } else {
//                        showBBSheet = true
//                    }
//                }
//                AddIndicatorButton(title: "VWAP", subtitle: "Vol Weighted", icon: "chart.line.flattrend.xyaxis", color: .orange, isActive: indicatorManager.isVWAPActive) {
//                    if indicatorManager.isVWAPActive {
//                        editingVWAPConfig = indicatorManager.activeIndicators.vwap
//                    } else {
//                        showVWAPSheet = true
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showEMASheet) {
//            AddEMASheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(isPresented: $showSMASheet) {
//            AddSMASheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(isPresented: $showBBSheet) {
//            AddBollingerBandsSheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(isPresented: $showVWAPSheet) {
//            AddVWAPSheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(item: $editingBBConfig) { config in
//            EditBollingerBandsSheet(config: config) { updated in
//                indicatorManager.updateBollingerBands(updated)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//        .sheet(item: $editingVWAPConfig) { config in
//            EditVWAPSheet(config: config) { updated in
//                indicatorManager.updateVWAP(updated)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//    }
//    
//    // MARK: - Panel Indicators
//    
//    private var panelIndicatorsSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text("Panel Indicators")
//                    .font(.subheadline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.white.opacity(0.7))
//                Spacer()
//                Text("Max 2")
//                    .font(.caption2)
//                    .foregroundColor(.orange)
//                    .padding(.horizontal, 6)
//                    .padding(.vertical, 2)
//                    .background(Color.orange.opacity(0.2))
//                    .cornerRadius(4)
//            }
//            
//            VStack(spacing: 8) {
//                PanelIndicatorButton(title: "RSI", subtitle: "Relative Strength Index", icon: "waveform.path.ecg", color: .purple, isActive: indicatorManager.isRSIActive, canAdd: indicatorManager.activeIndicators.canAddPanelIndicator || indicatorManager.isRSIActive) {
//                    if indicatorManager.isRSIActive {
//                        editingRSIConfig = indicatorManager.activeIndicators.rsi
//                    } else {
//                        showRSISheet = true
//                    }
//                }
//                
//                PanelIndicatorButton(title: "MACD", subtitle: "Moving Average Convergence Divergence", icon: "chart.bar.xaxis", color: .cyan, isActive: indicatorManager.isMACDActive, canAdd: indicatorManager.activeIndicators.canAddPanelIndicator || indicatorManager.isMACDActive) {
//                    if indicatorManager.isMACDActive {
//                        editingMACDConfig = indicatorManager.activeIndicators.macd
//                    } else {
//                        showMACDSheet = true
//                    }
//                }
//                
//                PanelIndicatorButton(title: "Stochastic", subtitle: "Stochastic Oscillator", icon: "waveform.path.ecg.rectangle", color: .yellow, isActive: indicatorManager.isStochasticActive, canAdd: indicatorManager.activeIndicators.canAddPanelIndicator || indicatorManager.isStochasticActive) {
//                    if indicatorManager.isStochasticActive {
//                        editingStochasticConfig = indicatorManager.activeIndicators.stochastic
//                    } else {
//                        showStochasticSheet = true
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showRSISheet) {
//            AddRSISheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(isPresented: $showMACDSheet) {
//            AddMACDSheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(isPresented: $showStochasticSheet) {
//            AddStochasticSheet(indicatorManager: indicatorManager) { onRecalculate() }
//                .presentationDetents([.medium])
//                .presentationDragIndicator(.visible)
//        }
//        .sheet(item: $editingRSIConfig) { config in
//            EditRSISheet(config: config) { updated in
//                indicatorManager.updateRSI(updated)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//        .sheet(item: $editingMACDConfig) { config in
//            EditMACDSheet(config: config) { updated in
//                indicatorManager.updateMACD(updated)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//        .sheet(item: $editingStochasticConfig) { config in
//            EditStochasticSheet(config: config) { updated in
//                indicatorManager.updateStochastic(updated)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//    }
//    
//    // MARK: - Active Indicators
//    
//    private var activeIndicatorsSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text("Active Indicators")
//                    .font(.headline)
//                    .foregroundColor(.white.opacity(0.8))
//                Spacer()
//                Button(action: clearAllIndicators) {
//                    Text("Clear All")
//                        .font(.caption)
//                        .foregroundColor(.red.opacity(0.8))
//                }
//            }
//            
//            VStack(spacing: 8) {
//                // Moving Averages
//                ForEach(indicatorManager.activeIndicators.movingAverages) { config in
//                    ActiveIndicatorRow(label: config.label, color: config.color.color, isEnabled: config.isEnabled, isPanelIndicator: false, onToggle: { indicatorManager.toggleMovingAverage(id: config.id); onRecalculate() }, onEdit: { editingMAConfig = config }, onRemove: { indicatorManager.removeMovingAverage(id: config.id); onRecalculate() })
//                }
//                
//                // Bollinger Bands
//                if let bbConfig = indicatorManager.activeIndicators.bollingerBands {
//                    ActiveIndicatorRow(label: bbConfig.label, color: bbConfig.color.color, isEnabled: bbConfig.isEnabled, isPanelIndicator: false, onToggle: { indicatorManager.toggleBollingerBands(); onRecalculate() }, onEdit: { editingBBConfig = bbConfig }, onRemove: { indicatorManager.disableBollingerBands(); onRecalculate() })
//                }
//                
//                // VWAP
//                if let vwapConfig = indicatorManager.activeIndicators.vwap {
//                    ActiveIndicatorRow(label: vwapConfig.label, color: vwapConfig.color.color, isEnabled: vwapConfig.isEnabled, isPanelIndicator: false, onToggle: { indicatorManager.toggleVWAP(); onRecalculate() }, onEdit: { editingVWAPConfig = vwapConfig }, onRemove: { indicatorManager.disableVWAP(); onRecalculate() })
//                }
//                
//                // RSI
//                if let rsiConfig = indicatorManager.activeIndicators.rsi {
//                    ActiveIndicatorRow(label: rsiConfig.label, color: rsiConfig.color.color, isEnabled: rsiConfig.isEnabled, isPanelIndicator: true, onToggle: { indicatorManager.toggleRSI(); onRecalculate() }, onEdit: { editingRSIConfig = rsiConfig }, onRemove: { indicatorManager.disableRSI(); onRecalculate() })
//                }
//                
//                // MACD
//                if let macdConfig = indicatorManager.activeIndicators.macd {
//                    ActiveIndicatorRow(label: macdConfig.label, color: macdConfig.color.color, isEnabled: macdConfig.isEnabled, isPanelIndicator: true, onToggle: { indicatorManager.toggleMACD(); onRecalculate() }, onEdit: { editingMACDConfig = macdConfig }, onRemove: { indicatorManager.disableMACD(); onRecalculate() })
//                }
//                
//                // Stochastic
//                if let stochConfig = indicatorManager.activeIndicators.stochastic {
//                    ActiveIndicatorRow(label: stochConfig.label, color: stochConfig.color.color, isEnabled: stochConfig.isEnabled, isPanelIndicator: true, onToggle: { indicatorManager.toggleStochastic(); onRecalculate() }, onEdit: { editingStochasticConfig = stochConfig }, onRemove: { indicatorManager.disableStochastic(); onRecalculate() })
//                }
//            }
//        }
//        .padding()
//        .background(Color.white.opacity(0.05))
//        .cornerRadius(12)
//        .sheet(item: $editingMAConfig) { config in
//            EditEMASheet(config: config) { updated in
//                indicatorManager.updateMovingAverage(updated)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//    }
//    
//    private var emptyStateView: some View {
//        VStack(spacing: 12) {
//            Image(systemName: "chart.line.uptrend.xyaxis.circle")
//                .font(.system(size: 40))
//                .foregroundColor(.gray.opacity(0.5))
//            Text("No indicators active")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//            Text("Add indicators above to start analyzing")
//                .font(.caption)
//                .foregroundColor(.gray.opacity(0.7))
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 40)
//        .background(Color.white.opacity(0.03))
//        .cornerRadius(12)
//    }
//    
//    private func clearAllIndicators() {
//        indicatorManager.resetToDefaults()
//        onRecalculate()
//    }
//}
//
//// MARK: - Supporting Views
//
//struct LimitBadge: View {
//    let label: String
//    let current: Int
//    let max: Int?
//    let color: Color
//    
//    var body: some View {
//        VStack(spacing: 4) {
//            if let max = max {
//                Text("\(current)/\(max)")
//                    .font(.system(size: 16, weight: .bold, design: .monospaced))
//                    .foregroundColor(current >= max ? color : .white)
//            } else {
//                Text("\(current)")
//                    .font(.system(size: 16, weight: .bold, design: .monospaced))
//                    .foregroundColor(.white)
//            }
//            Text(label)
//                .font(.caption2)
//                .foregroundColor(.gray)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 8)
//        .background(color.opacity(0.15))
//        .cornerRadius(8)
//    }
//}
//
//struct PanelIndicatorButton: View {
//    let title: String
//    let subtitle: String
//    let icon: String
//    let color: Color
//    let isActive: Bool
//    let canAdd: Bool
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 12) {
//                Image(systemName: icon)
//                    .foregroundColor(isActive ? .white : color)
//                    .font(.title3)
//                    .frame(width: 32)
//                
//                VStack(alignment: .leading, spacing: 2) {
//                    HStack {
//                        Text(title)
//                            .foregroundColor(.white)
//                            .fontWeight(isActive ? .semibold : .regular)
//                        if isActive {
//                            Text("ACTIVE")
//                                .font(.system(size: 8, weight: .bold))
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 4)
//                                .padding(.vertical, 2)
//                                .background(color)
//                                .cornerRadius(3)
//                        }
//                    }
//                    Text(subtitle)
//                        .font(.caption2)
//                        .foregroundColor(.gray)
//                        .lineLimit(1)
//                }
//                
//                Spacer()
//                
//                if isActive {
//                    Image(systemName: "gear").foregroundColor(.gray)
//                } else if canAdd {
//                    Image(systemName: "plus.circle").foregroundColor(color)
//                } else {
//                    Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.5))
//                }
//            }
//            .padding()
//            .background(isActive ? color.opacity(0.2) : Color.white.opacity(0.05))
//            .cornerRadius(10)
//            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1))
//        }
//        .buttonStyle(.plain)
//        .disabled(!canAdd && !isActive)
//        .opacity(canAdd || isActive ? 1.0 : 0.5)
//    }
//}
//
//struct AddIndicatorButton: View {
//    let title: String
//    let subtitle: String
//    let icon: String
//    let color: Color
//    var isActive: Bool = false
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            VStack(spacing: 8) {
//                Image(systemName: icon)
//                    .font(.system(size: 24))
//                    .foregroundColor(isActive ? .white : color)
//                Text(title)
//                    .font(.caption)
//                    .fontWeight(.medium)
//                    .foregroundColor(.white)
//                Text(subtitle)
//                    .font(.caption2)
//                    .foregroundColor(.gray)
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(isActive ? color : Color.white.opacity(0.08))
//            .cornerRadius(12)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//struct ActiveIndicatorRow: View {
//    let label: String
//    let color: Color
//    let isEnabled: Bool
//    var isPanelIndicator: Bool = false
//    let onToggle: () -> Void
//    let onEdit: () -> Void
//    let onRemove: () -> Void
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            Circle().fill(color).frame(width: 10, height: 10).opacity(isEnabled ? 1.0 : 0.4)
//            Text(label).foregroundColor(.white).opacity(isEnabled ? 1.0 : 0.5)
//            if isPanelIndicator {
//                Text("PANEL").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).padding(.horizontal, 4).padding(.vertical, 2).background(Color.gray.opacity(0.3)).cornerRadius(3)
//            }
//            Spacer()
//            Button(action: onToggle) { Image(systemName: isEnabled ? "eye.fill" : "eye.slash.fill").foregroundColor(isEnabled ? .blue : .gray) }
//            Button(action: onEdit) { Image(systemName: "pencil").foregroundColor(.gray) }
//            Button(action: onRemove) { Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7)) }
//        }
//        .padding(.vertical, 8)
//        .padding(.horizontal, 12)
//        .background(Color.white.opacity(0.03))
//        .cornerRadius(8)
//    }
//}
//
//// MARK: - Add Sheets
//
//struct AddEMASheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var selectedPeriod: Int = 20
//    @State private var lineColor: Color = .cyan
//    private let commonPeriods = [9, 12, 20, 26, 50, 100, 200]
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Quick Presets").font(.headline).foregroundColor(.white)
//                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
//                            ForEach(commonPeriods, id: \.self) { period in
//                                Button { selectedPeriod = period } label: {
//                                    Text("\(period)").font(.subheadline).fontWeight(selectedPeriod == period ? .bold : .regular).foregroundColor(selectedPeriod == period ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(selectedPeriod == period ? lineColor : Color.white.opacity(0.1)).cornerRadius(8)
//                                }.buttonStyle(.plain)
//                            }
//                        }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Custom Period: \(selectedPeriod)").font(.headline).foregroundColor(.white)
//                        Slider(value: Binding(get: { Double(selectedPeriod) }, set: { selectedPeriod = Int($0) }), in: 2...300, step: 1).tint(lineColor)
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
//                    
//                    Button { indicatorManager.addEMA(period: selectedPeriod, color: lineColor); onAdd(); dismiss() } label: {
//                        Text("Add EMA \(selectedPeriod)").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12)
//                    }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add EMA").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct AddSMASheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var selectedPeriod: Int = 20
//    @State private var lineColor: Color = .orange
//    private let commonPeriods = [10, 20, 50, 100, 200]
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Quick Presets").font(.headline).foregroundColor(.white)
//                        HStack(spacing: 10) {
//                            ForEach(commonPeriods, id: \.self) { period in
//                                Button { selectedPeriod = period } label: {
//                                    Text("\(period)").font(.subheadline).fontWeight(selectedPeriod == period ? .bold : .regular).foregroundColor(selectedPeriod == period ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(selectedPeriod == period ? lineColor : Color.white.opacity(0.1)).cornerRadius(8)
//                                }.buttonStyle(.plain)
//                            }
//                        }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Custom Period: \(selectedPeriod)").font(.headline).foregroundColor(.white)
//                        Slider(value: Binding(get: { Double(selectedPeriod) }, set: { selectedPeriod = Int($0) }), in: 2...300, step: 1).tint(lineColor)
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
//                    
//                    Button { indicatorManager.addSMA(period: selectedPeriod, color: lineColor); onAdd(); dismiss() } label: {
//                        Text("Add SMA \(selectedPeriod)").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12)
//                    }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add SMA").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct AddBollingerBandsSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var period: Int = 20
//    @State private var stdDev: Double = 2.0
//    @State private var middleColor: Color = .gray
//    @State private var upperColor: Color = .red.opacity(0.7)
//    @State private var lowerColor: Color = .green.opacity(0.7)
//    @State private var showFill: Bool = true
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 16) {
//                        Text("Settings").font(.headline).foregroundColor(.white)
//                        Stepper("Period: \(period)", value: $period, in: 5...100).foregroundColor(.white)
//                        HStack {
//                            Text("Std Dev: \(String(format: "%.1f", stdDev))").foregroundColor(.white)
//                            Slider(value: $stdDev, in: 1.0...4.0, step: 0.5).tint(.pink)
//                        }
//                        Toggle("Show Fill", isOn: $showFill).foregroundColor(.white)
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Colors").font(.headline).foregroundColor(.white)
//                        HStack { Text("Middle Band").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $middleColor).labelsHidden() }
//                        HStack { Text("Upper Band").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $upperColor).labelsHidden() }
//                        HStack { Text("Lower Band").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $lowerColor).labelsHidden() }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    Button {
//                        let config = BollingerBandsConfig(color: CodableColor(middleColor), period: period, standardDeviations: stdDev, upperBandColor: CodableColor(upperColor), lowerBandColor: CodableColor(lowerColor), showFill: showFill)
//                        indicatorManager.enableBollingerBands(config: config)
//                        onAdd(); dismiss()
//                    } label: {
//                        Text("Add Bollinger Bands").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.pink).cornerRadius(12)
//                    }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add Bollinger Bands").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct AddVWAPSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var lineColor: Color = .orange
//    @State private var showBands: Bool = false
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 16) {
//                        Text("VWAP resets daily for intraday charts").font(.caption).foregroundColor(.gray)
//                        Toggle("Show Std Dev Bands", isOn: $showBands).foregroundColor(.white)
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
//                    
//                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
//                    
//                    Button {
//                        let config = VWAPConfig(color: CodableColor(lineColor), showStandardDeviationBands: showBands)
//                        indicatorManager.enableVWAP(config: config)
//                        onAdd(); dismiss()
//                    } label: {
//                        Text("Add VWAP").font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12)
//                    }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add VWAP").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct AddRSISheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var period: Int = 14
//    @State private var lineColor: Color = .purple
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Period: \(period)").font(.headline).foregroundColor(.white)
//                        HStack {
//                            ForEach([7, 14, 21], id: \.self) { p in
//                                Button { period = p } label: { Text("\(p)").font(.subheadline).fontWeight(period == p ? .bold : .regular).foregroundColor(period == p ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(period == p ? lineColor : Color.white.opacity(0.1)).cornerRadius(8) }.buttonStyle(.plain)
//                            }
//                        }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
//                    Button { indicatorManager.enableRSI(config: RSIConfig(color: CodableColor(lineColor), period: period)); onAdd(); dismiss() } label: { Text("Add RSI \(period)").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12) }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add RSI").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct AddMACDSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var fastPeriod: Int = 12
//    @State private var slowPeriod: Int = 26
//    @State private var signalPeriod: Int = 9
//    @State private var macdColor: Color = .cyan
//    @State private var signalColor: Color = .orange
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Presets").font(.headline).foregroundColor(.white)
//                        HStack(spacing: 10) {
//                            PresetButton(title: "Standard", subtitle: "12,26,9", isSelected: fastPeriod == 12 && slowPeriod == 26) { fastPeriod = 12; slowPeriod = 26; signalPeriod = 9 }
//                            PresetButton(title: "Fast", subtitle: "8,17,9", isSelected: fastPeriod == 8 && slowPeriod == 17) { fastPeriod = 8; slowPeriod = 17; signalPeriod = 9 }
//                        }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    VStack(alignment: .leading, spacing: 16) {
//                        Text("Periods").font(.headline).foregroundColor(.white)
//                        Stepper("Fast EMA: \(fastPeriod)", value: $fastPeriod, in: 2...50).foregroundColor(.white)
//                        Stepper("Slow EMA: \(slowPeriod)", value: $slowPeriod, in: 5...100).foregroundColor(.white)
//                        Stepper("Signal: \(signalPeriod)", value: $signalPeriod, in: 2...30).foregroundColor(.white)
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Colors").font(.headline).foregroundColor(.white)
//                        HStack { Text("MACD Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $macdColor).labelsHidden() }
//                        HStack { Text("Signal Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $signalColor).labelsHidden() }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    Button { indicatorManager.enableMACD(config: MACDConfig(color: CodableColor(macdColor), fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod, signalColor: CodableColor(signalColor))); onAdd(); dismiss() } label: { Text("Add MACD(\(fastPeriod),\(slowPeriod),\(signalPeriod))").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(macdColor).cornerRadius(12) }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add MACD").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct AddStochasticSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    @State private var kPeriod: Int = 14
//    @State private var dPeriod: Int = 3
//    @State private var smoothK: Int = 3
//    @State private var kColor: Color = .yellow
//    @State private var dColor: Color = .red
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Presets").font(.headline).foregroundColor(.white)
//                        HStack(spacing: 10) {
//                            PresetButton(title: "Standard", subtitle: "14,3,3", isSelected: kPeriod == 14 && dPeriod == 3) { kPeriod = 14; dPeriod = 3; smoothK = 3 }
//                            PresetButton(title: "Fast", subtitle: "5,3,1", isSelected: kPeriod == 5 && smoothK == 1) { kPeriod = 5; dPeriod = 3; smoothK = 1 }
//                        }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    VStack(alignment: .leading, spacing: 16) {
//                        Text("Periods").font(.headline).foregroundColor(.white)
//                        Stepper("%K Period: \(kPeriod)", value: $kPeriod, in: 3...30).foregroundColor(.white)
//                        Stepper("%D Period: \(dPeriod)", value: $dPeriod, in: 1...10).foregroundColor(.white)
//                        Stepper("Smooth %K: \(smoothK)", value: $smoothK, in: 1...10).foregroundColor(.white)
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Colors").font(.headline).foregroundColor(.white)
//                        HStack { Text("%K Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $kColor).labelsHidden() }
//                        HStack { Text("%D Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $dColor).labelsHidden() }
//                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
//                    Button { indicatorManager.enableStochastic(config: StochasticConfig(color: CodableColor(kColor), kPeriod: kPeriod, dPeriod: dPeriod, smoothK: smoothK, dColor: CodableColor(dColor))); onAdd(); dismiss() } label: { Text("Add Stochastic(\(kPeriod),\(dPeriod),\(smoothK))").font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).padding().background(kColor).cornerRadius(12) }
//                }.padding()
//            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add Stochastic").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
//        }
//    }
//}
//
//struct PresetButton: View {
//    let title: String
//    let subtitle: String
//    let isSelected: Bool
//    let action: () -> Void
//    var body: some View {
//        Button(action: action) { VStack(spacing: 4) { Text(title).font(.caption).fontWeight(isSelected ? .bold : .regular); Text(subtitle).font(.caption2).foregroundColor(.gray) }.frame(maxWidth: .infinity).padding(.vertical, 10).background(isSelected ? Color.blue : Color.white.opacity(0.1)).foregroundColor(isSelected ? .white : .gray).cornerRadius(8) }.buttonStyle(.plain)
//    }
//}
//
//// MARK: - Edit Sheets
//
//struct EditEMASheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: MovingAverageConfig
//    let onSave: (MovingAverageConfig) -> Void
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Period") { Stepper("Period: \(config.period)", value: $config.period, in: 2...300) }
//                Section("Appearance") {
//                    ColorPicker("Line Color", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
//                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))", value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
//                }
//            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit \(config.label)").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
//        }
//    }
//}
//
//struct EditBollingerBandsSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: BollingerBandsConfig
//    let onSave: (BollingerBandsConfig) -> Void
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Settings") {
//                    Stepper("Period: \(config.period)", value: $config.period, in: 5...100)
//                    HStack { Text("Std Dev: \(String(format: "%.1f", config.standardDeviations))"); Slider(value: $config.standardDeviations, in: 1.0...4.0, step: 0.5) }
//                    Toggle("Show Fill", isOn: $config.showFill)
//                }
//                Section("Colors") {
//                    ColorPicker("Middle Band", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
//                    ColorPicker("Upper Band", selection: Binding(get: { config.upperBandColor.color }, set: { config.upperBandColor = CodableColor($0) }))
//                    ColorPicker("Lower Band", selection: Binding(get: { config.lowerBandColor.color }, set: { config.lowerBandColor = CodableColor($0) }))
//                }
//            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit Bollinger Bands").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
//        }
//    }
//}
//
//struct EditVWAPSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: VWAPConfig
//    let onSave: (VWAPConfig) -> Void
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Settings") { Toggle("Show Std Dev Bands", isOn: $config.showStandardDeviationBands) }
//                Section("Appearance") {
//                    ColorPicker("Line Color", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
//                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))", value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
//                }
//            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit VWAP").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
//        }
//    }
//}
//
//struct EditRSISheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: RSIConfig
//    let onSave: (RSIConfig) -> Void
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Period") { Stepper("Period: \(config.period)", value: $config.period, in: 5...50) }
//                Section("Levels") {
//                    HStack { Text("Overbought"); Spacer(); TextField("", value: $config.overboughtLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
//                    HStack { Text("Oversold"); Spacer(); TextField("", value: $config.oversoldLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
//                    Toggle("Show Level Zones", isOn: $config.showLevels)
//                }
//                Section("Appearance") {
//                    ColorPicker("Line Color", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
//                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))", value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
//                }
//            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit RSI").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
//        }
//    }
//}
//
//struct EditMACDSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: MACDConfig
//    let onSave: (MACDConfig) -> Void
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Periods") {
//                    Stepper("Fast EMA: \(config.fastPeriod)", value: $config.fastPeriod, in: 2...50)
//                    Stepper("Slow EMA: \(config.slowPeriod)", value: $config.slowPeriod, in: 5...100)
//                    Stepper("Signal: \(config.signalPeriod)", value: $config.signalPeriod, in: 2...30)
//                }
//                Section("Display") { Toggle("Show Histogram", isOn: $config.showHistogram); Toggle("Show Signal Line", isOn: $config.showSignalLine) }
//                Section("Colors") {
//                    ColorPicker("MACD Line", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
//                    ColorPicker("Signal Line", selection: Binding(get: { config.signalColor.color }, set: { config.signalColor = CodableColor($0) }))
//                    ColorPicker("Histogram +", selection: Binding(get: { config.histogramPositiveColor.color }, set: { config.histogramPositiveColor = CodableColor($0) }))
//                    ColorPicker("Histogram -", selection: Binding(get: { config.histogramNegativeColor.color }, set: { config.histogramNegativeColor = CodableColor($0) }))
//                }
//            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit MACD").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
//        }
//    }
//}
//
//struct EditStochasticSheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: StochasticConfig
//    let onSave: (StochasticConfig) -> Void
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Periods") {
//                    Stepper("%K Period: \(config.kPeriod)", value: $config.kPeriod, in: 3...30)
//                    Stepper("%D Period: \(config.dPeriod)", value: $config.dPeriod, in: 1...10)
//                    Stepper("Smooth %K: \(config.smoothK)", value: $config.smoothK, in: 1...10)
//                }
//                Section("Levels") {
//                    HStack { Text("Overbought"); Spacer(); TextField("", value: $config.overboughtLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
//                    HStack { Text("Oversold"); Spacer(); TextField("", value: $config.oversoldLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
//                    Toggle("Show Level Zones", isOn: $config.showLevels)
//                }
//                Section("Colors") {
//                    ColorPicker("%K Line", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
//                    ColorPicker("%D Line", selection: Binding(get: { config.dColor.color }, set: { config.dColor = CodableColor($0) }))
//                }
//            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit Stochastic").navigationBarTitleDisplayMode(.inline)
//            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
//        }
//    }
//}


