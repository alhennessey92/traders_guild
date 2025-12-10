//
//  IndicatorSettingsView.swift
//  traders_guild
//
//  EXPANDED VERSION - Full support for EMA, SMA, BB, VWAP, RSI, MACD, Stochastic
//

import SwiftUI

// MARK: - Main Settings Content

struct IndicatorSettingsContent: View {
    @ObservedObject var indicatorManager: IndicatorManager
    let onRecalculate: () -> Void
    
    // Add sheets
    @State private var showEMASheet = false
    @State private var showSMASheet = false
    @State private var showBBSheet = false
    @State private var showVWAPSheet = false
    @State private var showRSISheet = false
    @State private var showMACDSheet = false
    @State private var showStochasticSheet = false
    
    // Edit sheets
    @State private var editingMAConfig: MovingAverageConfig?
    @State private var editingBBConfig: BollingerBandsConfig?
    @State private var editingVWAPConfig: VWAPConfig?
    @State private var editingRSIConfig: RSIConfig?
    @State private var editingMACDConfig: MACDConfig?
    @State private var editingStochasticConfig: StochasticConfig?
    
    @State private var showLimitAlert = false
    
    private var hasAnyIndicators: Bool {
        !indicatorManager.activeIndicators.movingAverages.isEmpty ||
        indicatorManager.activeIndicators.bollingerBands != nil ||
        indicatorManager.activeIndicators.vwap != nil ||
        indicatorManager.activeIndicators.rsi != nil ||
        indicatorManager.activeIndicators.macd != nil ||
        indicatorManager.activeIndicators.stochastic != nil
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                headerSection
                limitsIndicator
                overlayIndicatorsSection
                panelIndicatorsSection
                
                if hasAnyIndicators {
                    activeIndicatorsSection
                } else {
                    emptyStateView
                }
                
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .alert("Panel Limit Reached", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Maximum 2 panel indicators allowed. Disable or remove an existing panel indicator first.")
        }
        .onChange(of: indicatorManager.errorMessage) { _, newValue in
            if newValue != nil {
                showLimitAlert = true
                indicatorManager.clearError()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Indicators")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if hasAnyIndicators {
                    Text("\(indicatorManager.activeIndicatorCount) active")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            
            Text("Add technical indicators to enhance your chart analysis")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Limits
    
    private var limitsIndicator: some View {
        HStack(spacing: 12) {
            LimitBadge(label: "Overlays", current: indicatorManager.activeIndicators.enabledMovingAverages.count + (indicatorManager.isBollingerBandsActive ? 1 : 0) + (indicatorManager.isVWAPActive ? 1 : 0), max: nil, color: .cyan)
            LimitBadge(label: "Panels", current: indicatorManager.activePanelCount, max: ActiveIndicators.maxPanelIndicators, color: indicatorManager.activePanelCount >= ActiveIndicators.maxPanelIndicators ? .orange : .purple)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Overlay Indicators
    
    private var overlayIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overlay Indicators")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                AddIndicatorButton(title: "EMA", subtitle: "Exponential MA", icon: "chart.line.uptrend.xyaxis", color: .cyan) {
                    showEMASheet = true
                }
                AddIndicatorButton(title: "SMA", subtitle: "Simple MA", icon: "chart.line.uptrend.xyaxis", color: .orange) {
                    showSMASheet = true
                }
                AddIndicatorButton(title: "Bollinger", subtitle: "Bands", icon: "arrow.up.and.down", color: .pink, isActive: indicatorManager.isBollingerBandsActive) {
                    if indicatorManager.isBollingerBandsActive {
                        editingBBConfig = indicatorManager.activeIndicators.bollingerBands
                    } else {
                        showBBSheet = true
                    }
                }
                AddIndicatorButton(title: "VWAP", subtitle: "Vol Weighted", icon: "chart.line.flattrend.xyaxis", color: .orange, isActive: indicatorManager.isVWAPActive) {
                    if indicatorManager.isVWAPActive {
                        editingVWAPConfig = indicatorManager.activeIndicators.vwap
                    } else {
                        showVWAPSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEMASheet) {
            AddEMASheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSMASheet) {
            AddSMASheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBBSheet) {
            AddBollingerBandsSheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVWAPSheet) {
            AddVWAPSheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingBBConfig) { config in
            EditBollingerBandsSheet(config: config) { updated in
                indicatorManager.updateBollingerBands(updated)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingVWAPConfig) { config in
            EditVWAPSheet(config: config) { updated in
                indicatorManager.updateVWAP(updated)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Panel Indicators
    
    private var panelIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Panel Indicators")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("Max 2")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
            
            VStack(spacing: 8) {
                PanelIndicatorButton(title: "RSI", subtitle: "Relative Strength Index", icon: "waveform.path.ecg", color: .purple, isActive: indicatorManager.isRSIActive, canAdd: indicatorManager.activeIndicators.canAddPanelIndicator || indicatorManager.isRSIActive) {
                    if indicatorManager.isRSIActive {
                        editingRSIConfig = indicatorManager.activeIndicators.rsi
                    } else {
                        showRSISheet = true
                    }
                }
                
                PanelIndicatorButton(title: "MACD", subtitle: "Moving Average Convergence Divergence", icon: "chart.bar.xaxis", color: .cyan, isActive: indicatorManager.isMACDActive, canAdd: indicatorManager.activeIndicators.canAddPanelIndicator || indicatorManager.isMACDActive) {
                    if indicatorManager.isMACDActive {
                        editingMACDConfig = indicatorManager.activeIndicators.macd
                    } else {
                        showMACDSheet = true
                    }
                }
                
                PanelIndicatorButton(title: "Stochastic", subtitle: "Stochastic Oscillator", icon: "waveform.path.ecg.rectangle", color: .yellow, isActive: indicatorManager.isStochasticActive, canAdd: indicatorManager.activeIndicators.canAddPanelIndicator || indicatorManager.isStochasticActive) {
                    if indicatorManager.isStochasticActive {
                        editingStochasticConfig = indicatorManager.activeIndicators.stochastic
                    } else {
                        showStochasticSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showRSISheet) {
            AddRSISheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMACDSheet) {
            AddMACDSheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStochasticSheet) {
            AddStochasticSheet(indicatorManager: indicatorManager) { onRecalculate() }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingRSIConfig) { config in
            EditRSISheet(config: config) { updated in
                indicatorManager.updateRSI(updated)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingMACDConfig) { config in
            EditMACDSheet(config: config) { updated in
                indicatorManager.updateMACD(updated)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingStochasticConfig) { config in
            EditStochasticSheet(config: config) { updated in
                indicatorManager.updateStochastic(updated)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Active Indicators
    
    private var activeIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Indicators")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Button(action: clearAllIndicators) {
                    Text("Clear All")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            
            VStack(spacing: 8) {
                // Moving Averages
                ForEach(indicatorManager.activeIndicators.movingAverages) { config in
                    ActiveIndicatorRow(label: config.label, color: config.color.color, isEnabled: config.isEnabled, isPanelIndicator: false, onToggle: { indicatorManager.toggleMovingAverage(id: config.id); onRecalculate() }, onEdit: { editingMAConfig = config }, onRemove: { indicatorManager.removeMovingAverage(id: config.id); onRecalculate() })
                }
                
                // Bollinger Bands
                if let bbConfig = indicatorManager.activeIndicators.bollingerBands {
                    ActiveIndicatorRow(label: bbConfig.label, color: bbConfig.color.color, isEnabled: bbConfig.isEnabled, isPanelIndicator: false, onToggle: { indicatorManager.toggleBollingerBands(); onRecalculate() }, onEdit: { editingBBConfig = bbConfig }, onRemove: { indicatorManager.disableBollingerBands(); onRecalculate() })
                }
                
                // VWAP
                if let vwapConfig = indicatorManager.activeIndicators.vwap {
                    ActiveIndicatorRow(label: vwapConfig.label, color: vwapConfig.color.color, isEnabled: vwapConfig.isEnabled, isPanelIndicator: false, onToggle: { indicatorManager.toggleVWAP(); onRecalculate() }, onEdit: { editingVWAPConfig = vwapConfig }, onRemove: { indicatorManager.disableVWAP(); onRecalculate() })
                }
                
                // RSI
                if let rsiConfig = indicatorManager.activeIndicators.rsi {
                    ActiveIndicatorRow(label: rsiConfig.label, color: rsiConfig.color.color, isEnabled: rsiConfig.isEnabled, isPanelIndicator: true, onToggle: { indicatorManager.toggleRSI(); onRecalculate() }, onEdit: { editingRSIConfig = rsiConfig }, onRemove: { indicatorManager.disableRSI(); onRecalculate() })
                }
                
                // MACD
                if let macdConfig = indicatorManager.activeIndicators.macd {
                    ActiveIndicatorRow(label: macdConfig.label, color: macdConfig.color.color, isEnabled: macdConfig.isEnabled, isPanelIndicator: true, onToggle: { indicatorManager.toggleMACD(); onRecalculate() }, onEdit: { editingMACDConfig = macdConfig }, onRemove: { indicatorManager.disableMACD(); onRecalculate() })
                }
                
                // Stochastic
                if let stochConfig = indicatorManager.activeIndicators.stochastic {
                    ActiveIndicatorRow(label: stochConfig.label, color: stochConfig.color.color, isEnabled: stochConfig.isEnabled, isPanelIndicator: true, onToggle: { indicatorManager.toggleStochastic(); onRecalculate() }, onEdit: { editingStochasticConfig = stochConfig }, onRemove: { indicatorManager.disableStochastic(); onRecalculate() })
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .sheet(item: $editingMAConfig) { config in
            EditEMASheet(config: config) { updated in
                indicatorManager.updateMovingAverage(updated)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("No indicators active")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Add indicators above to start analyzing")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    private func clearAllIndicators() {
        indicatorManager.resetToDefaults()
        onRecalculate()
    }
}

// MARK: - Supporting Views

struct LimitBadge: View {
    let label: String
    let current: Int
    let max: Int?
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            if let max = max {
                Text("\(current)/\(max)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(current >= max ? color : .white)
            } else {
                Text("\(current)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

struct PanelIndicatorButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isActive: Bool
    let canAdd: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isActive ? .white : color)
                    .font(.title3)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .foregroundColor(.white)
                            .fontWeight(isActive ? .semibold : .regular)
                        if isActive {
                            Text("ACTIVE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(color)
                                .cornerRadius(3)
                        }
                    }
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "gear").foregroundColor(.gray)
                } else if canAdd {
                    Image(systemName: "plus.circle").foregroundColor(color)
                } else {
                    Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding()
            .background(isActive ? color.opacity(0.2) : Color.white.opacity(0.05))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!canAdd && !isActive)
        .opacity(canAdd || isActive ? 1.0 : 0.5)
    }
}

struct AddIndicatorButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? .white : color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isActive ? color : Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ActiveIndicatorRow: View {
    let label: String
    let color: Color
    let isEnabled: Bool
    var isPanelIndicator: Bool = false
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10).opacity(isEnabled ? 1.0 : 0.4)
            Text(label).foregroundColor(.white).opacity(isEnabled ? 1.0 : 0.5)
            if isPanelIndicator {
                Text("PANEL").font(.system(size: 8, weight: .bold)).foregroundColor(.gray).padding(.horizontal, 4).padding(.vertical, 2).background(Color.gray.opacity(0.3)).cornerRadius(3)
            }
            Spacer()
            Button(action: onToggle) { Image(systemName: isEnabled ? "eye.fill" : "eye.slash.fill").foregroundColor(isEnabled ? .blue : .gray) }
            Button(action: onEdit) { Image(systemName: "pencil").foregroundColor(.gray) }
            Button(action: onRemove) { Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7)) }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

// MARK: - Add Sheets

struct AddEMASheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var selectedPeriod: Int = 20
    @State private var lineColor: Color = .cyan
    private let commonPeriods = [9, 12, 20, 26, 50, 100, 200]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Presets").font(.headline).foregroundColor(.white)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(commonPeriods, id: \.self) { period in
                                Button { selectedPeriod = period } label: {
                                    Text("\(period)").font(.subheadline).fontWeight(selectedPeriod == period ? .bold : .regular).foregroundColor(selectedPeriod == period ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(selectedPeriod == period ? lineColor : Color.white.opacity(0.1)).cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Period: \(selectedPeriod)").font(.headline).foregroundColor(.white)
                        Slider(value: Binding(get: { Double(selectedPeriod) }, set: { selectedPeriod = Int($0) }), in: 2...300, step: 1).tint(lineColor)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
                    
                    Button { indicatorManager.addEMA(period: selectedPeriod, color: lineColor); onAdd(); dismiss() } label: {
                        Text("Add EMA \(selectedPeriod)").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12)
                    }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add EMA").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct AddSMASheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var selectedPeriod: Int = 20
    @State private var lineColor: Color = .orange
    private let commonPeriods = [10, 20, 50, 100, 200]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Presets").font(.headline).foregroundColor(.white)
                        HStack(spacing: 10) {
                            ForEach(commonPeriods, id: \.self) { period in
                                Button { selectedPeriod = period } label: {
                                    Text("\(period)").font(.subheadline).fontWeight(selectedPeriod == period ? .bold : .regular).foregroundColor(selectedPeriod == period ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(selectedPeriod == period ? lineColor : Color.white.opacity(0.1)).cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Period: \(selectedPeriod)").font(.headline).foregroundColor(.white)
                        Slider(value: Binding(get: { Double(selectedPeriod) }, set: { selectedPeriod = Int($0) }), in: 2...300, step: 1).tint(lineColor)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
                    
                    Button { indicatorManager.addSMA(period: selectedPeriod, color: lineColor); onAdd(); dismiss() } label: {
                        Text("Add SMA \(selectedPeriod)").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12)
                    }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add SMA").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct AddBollingerBandsSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var period: Int = 20
    @State private var stdDev: Double = 2.0
    @State private var middleColor: Color = .gray
    @State private var upperColor: Color = .red.opacity(0.7)
    @State private var lowerColor: Color = .green.opacity(0.7)
    @State private var showFill: Bool = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Settings").font(.headline).foregroundColor(.white)
                        Stepper("Period: \(period)", value: $period, in: 5...100).foregroundColor(.white)
                        HStack {
                            Text("Std Dev: \(String(format: "%.1f", stdDev))").foregroundColor(.white)
                            Slider(value: $stdDev, in: 1.0...4.0, step: 0.5).tint(.pink)
                        }
                        Toggle("Show Fill", isOn: $showFill).foregroundColor(.white)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colors").font(.headline).foregroundColor(.white)
                        HStack { Text("Middle Band").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $middleColor).labelsHidden() }
                        HStack { Text("Upper Band").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $upperColor).labelsHidden() }
                        HStack { Text("Lower Band").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $lowerColor).labelsHidden() }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    Button {
                        let config = BollingerBandsConfig(color: CodableColor(middleColor), period: period, standardDeviations: stdDev, upperBandColor: CodableColor(upperColor), lowerBandColor: CodableColor(lowerColor), showFill: showFill)
                        indicatorManager.enableBollingerBands(config: config)
                        onAdd(); dismiss()
                    } label: {
                        Text("Add Bollinger Bands").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.pink).cornerRadius(12)
                    }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add Bollinger Bands").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct AddVWAPSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var lineColor: Color = .orange
    @State private var showBands: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("VWAP resets daily for intraday charts").font(.caption).foregroundColor(.gray)
                        Toggle("Show Std Dev Bands", isOn: $showBands).foregroundColor(.white)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(12)
                    
                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
                    
                    Button {
                        let config = VWAPConfig(color: CodableColor(lineColor), showStandardDeviationBands: showBands)
                        indicatorManager.enableVWAP(config: config)
                        onAdd(); dismiss()
                    } label: {
                        Text("Add VWAP").font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12)
                    }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add VWAP").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct AddRSISheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var period: Int = 14
    @State private var lineColor: Color = .purple
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Period: \(period)").font(.headline).foregroundColor(.white)
                        HStack {
                            ForEach([7, 14, 21], id: \.self) { p in
                                Button { period = p } label: { Text("\(p)").font(.subheadline).fontWeight(period == p ? .bold : .regular).foregroundColor(period == p ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(period == p ? lineColor : Color.white.opacity(0.1)).cornerRadius(8) }.buttonStyle(.plain)
                            }
                        }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    HStack { Text("Line Color").foregroundColor(.white); Spacer(); ColorPicker("", selection: $lineColor).labelsHidden() }
                    Button { indicatorManager.enableRSI(config: RSIConfig(color: CodableColor(lineColor), period: period)); onAdd(); dismiss() } label: { Text("Add RSI \(period)").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(lineColor).cornerRadius(12) }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add RSI").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct AddMACDSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var fastPeriod: Int = 12
    @State private var slowPeriod: Int = 26
    @State private var signalPeriod: Int = 9
    @State private var macdColor: Color = .cyan
    @State private var signalColor: Color = .orange
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presets").font(.headline).foregroundColor(.white)
                        HStack(spacing: 10) {
                            PresetButton(title: "Standard", subtitle: "12,26,9", isSelected: fastPeriod == 12 && slowPeriod == 26) { fastPeriod = 12; slowPeriod = 26; signalPeriod = 9 }
                            PresetButton(title: "Fast", subtitle: "8,17,9", isSelected: fastPeriod == 8 && slowPeriod == 17) { fastPeriod = 8; slowPeriod = 17; signalPeriod = 9 }
                        }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Periods").font(.headline).foregroundColor(.white)
                        Stepper("Fast EMA: \(fastPeriod)", value: $fastPeriod, in: 2...50).foregroundColor(.white)
                        Stepper("Slow EMA: \(slowPeriod)", value: $slowPeriod, in: 5...100).foregroundColor(.white)
                        Stepper("Signal: \(signalPeriod)", value: $signalPeriod, in: 2...30).foregroundColor(.white)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colors").font(.headline).foregroundColor(.white)
                        HStack { Text("MACD Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $macdColor).labelsHidden() }
                        HStack { Text("Signal Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $signalColor).labelsHidden() }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    Button { indicatorManager.enableMACD(config: MACDConfig(color: CodableColor(macdColor), fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod, signalColor: CodableColor(signalColor))); onAdd(); dismiss() } label: { Text("Add MACD(\(fastPeriod),\(slowPeriod),\(signalPeriod))").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(macdColor).cornerRadius(12) }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add MACD").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct AddStochasticSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    @State private var kPeriod: Int = 14
    @State private var dPeriod: Int = 3
    @State private var smoothK: Int = 3
    @State private var kColor: Color = .yellow
    @State private var dColor: Color = .red
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presets").font(.headline).foregroundColor(.white)
                        HStack(spacing: 10) {
                            PresetButton(title: "Standard", subtitle: "14,3,3", isSelected: kPeriod == 14 && dPeriod == 3) { kPeriod = 14; dPeriod = 3; smoothK = 3 }
                            PresetButton(title: "Fast", subtitle: "5,3,1", isSelected: kPeriod == 5 && smoothK == 1) { kPeriod = 5; dPeriod = 3; smoothK = 1 }
                        }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Periods").font(.headline).foregroundColor(.white)
                        Stepper("%K Period: \(kPeriod)", value: $kPeriod, in: 3...30).foregroundColor(.white)
                        Stepper("%D Period: \(dPeriod)", value: $dPeriod, in: 1...10).foregroundColor(.white)
                        Stepper("Smooth %K: \(smoothK)", value: $smoothK, in: 1...10).foregroundColor(.white)
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colors").font(.headline).foregroundColor(.white)
                        HStack { Text("%K Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $kColor).labelsHidden() }
                        HStack { Text("%D Line").foregroundColor(.gray); Spacer(); ColorPicker("", selection: $dColor).labelsHidden() }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    Button { indicatorManager.enableStochastic(config: StochasticConfig(color: CodableColor(kColor), kPeriod: kPeriod, dPeriod: dPeriod, smoothK: smoothK, dColor: CodableColor(dColor))); onAdd(); dismiss() } label: { Text("Add Stochastic(\(kPeriod),\(dPeriod),\(smoothK))").font(.headline).foregroundColor(.black).frame(maxWidth: .infinity).padding().background(kColor).cornerRadius(12) }
                }.padding()
            }.background(Color.black.ignoresSafeArea()).navigationTitle("Add Stochastic").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) } }
        }
    }
}

struct PresetButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { VStack(spacing: 4) { Text(title).font(.caption).fontWeight(isSelected ? .bold : .regular); Text(subtitle).font(.caption2).foregroundColor(.gray) }.frame(maxWidth: .infinity).padding(.vertical, 10).background(isSelected ? Color.blue : Color.white.opacity(0.1)).foregroundColor(isSelected ? .white : .gray).cornerRadius(8) }.buttonStyle(.plain)
    }
}

// MARK: - Edit Sheets

struct EditEMASheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: MovingAverageConfig
    let onSave: (MovingAverageConfig) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Period") { Stepper("Period: \(config.period)", value: $config.period, in: 2...300) }
                Section("Appearance") {
                    ColorPicker("Line Color", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))", value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
                }
            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit \(config.label)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
        }
    }
}

struct EditBollingerBandsSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: BollingerBandsConfig
    let onSave: (BollingerBandsConfig) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Settings") {
                    Stepper("Period: \(config.period)", value: $config.period, in: 5...100)
                    HStack { Text("Std Dev: \(String(format: "%.1f", config.standardDeviations))"); Slider(value: $config.standardDeviations, in: 1.0...4.0, step: 0.5) }
                    Toggle("Show Fill", isOn: $config.showFill)
                }
                Section("Colors") {
                    ColorPicker("Middle Band", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
                    ColorPicker("Upper Band", selection: Binding(get: { config.upperBandColor.color }, set: { config.upperBandColor = CodableColor($0) }))
                    ColorPicker("Lower Band", selection: Binding(get: { config.lowerBandColor.color }, set: { config.lowerBandColor = CodableColor($0) }))
                }
            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit Bollinger Bands").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
        }
    }
}

struct EditVWAPSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: VWAPConfig
    let onSave: (VWAPConfig) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Settings") { Toggle("Show Std Dev Bands", isOn: $config.showStandardDeviationBands) }
                Section("Appearance") {
                    ColorPicker("Line Color", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))", value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
                }
            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit VWAP").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
        }
    }
}

struct EditRSISheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: RSIConfig
    let onSave: (RSIConfig) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Period") { Stepper("Period: \(config.period)", value: $config.period, in: 5...50) }
                Section("Levels") {
                    HStack { Text("Overbought"); Spacer(); TextField("", value: $config.overboughtLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
                    HStack { Text("Oversold"); Spacer(); TextField("", value: $config.oversoldLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
                    Toggle("Show Level Zones", isOn: $config.showLevels)
                }
                Section("Appearance") {
                    ColorPicker("Line Color", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))", value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
                }
            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit RSI").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
        }
    }
}

struct EditMACDSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: MACDConfig
    let onSave: (MACDConfig) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Periods") {
                    Stepper("Fast EMA: \(config.fastPeriod)", value: $config.fastPeriod, in: 2...50)
                    Stepper("Slow EMA: \(config.slowPeriod)", value: $config.slowPeriod, in: 5...100)
                    Stepper("Signal: \(config.signalPeriod)", value: $config.signalPeriod, in: 2...30)
                }
                Section("Display") { Toggle("Show Histogram", isOn: $config.showHistogram); Toggle("Show Signal Line", isOn: $config.showSignalLine) }
                Section("Colors") {
                    ColorPicker("MACD Line", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
                    ColorPicker("Signal Line", selection: Binding(get: { config.signalColor.color }, set: { config.signalColor = CodableColor($0) }))
                    ColorPicker("Histogram +", selection: Binding(get: { config.histogramPositiveColor.color }, set: { config.histogramPositiveColor = CodableColor($0) }))
                    ColorPicker("Histogram -", selection: Binding(get: { config.histogramNegativeColor.color }, set: { config.histogramNegativeColor = CodableColor($0) }))
                }
            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit MACD").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
        }
    }
}

struct EditStochasticSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: StochasticConfig
    let onSave: (StochasticConfig) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Periods") {
                    Stepper("%K Period: \(config.kPeriod)", value: $config.kPeriod, in: 3...30)
                    Stepper("%D Period: \(config.dPeriod)", value: $config.dPeriod, in: 1...10)
                    Stepper("Smooth %K: \(config.smoothK)", value: $config.smoothK, in: 1...10)
                }
                Section("Levels") {
                    HStack { Text("Overbought"); Spacer(); TextField("", value: $config.overboughtLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
                    HStack { Text("Oversold"); Spacer(); TextField("", value: $config.oversoldLevel, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60) }
                    Toggle("Show Level Zones", isOn: $config.showLevels)
                }
                Section("Colors") {
                    ColorPicker("%K Line", selection: Binding(get: { config.color.color }, set: { config.color = CodableColor($0) }))
                    ColorPicker("%D Line", selection: Binding(get: { config.dColor.color }, set: { config.dColor = CodableColor($0) }))
                }
            }.scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea()).navigationTitle("Edit Stochastic").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(config); dismiss() } } }
        }
    }
}













////
////  IndicatorSettingsView.swift
////  traders_guild
////
////  Professional indicator settings UI for the bottom sheet
////  Allows adding, configuring, and removing indicators
////  SCROLLABLE to ensure all content is accessible
////
//
//import SwiftUI
//
//// MARK: - Main Indicator Settings Content (for MainView bottom sheet)
//
///// The indicator content view for ChartBottomSheet
///// Drop this into your indicatorContent in MainView
//struct IndicatorSettingsContent: View {
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onRecalculate: () -> Void
//    
//    // Sheet presentation states
//    @State private var showEMASheet = false
//    @State private var showRSISheet = false
//    @State private var editingMAConfig: MovingAverageConfig?
//    @State private var editingRSIConfig: RSIConfig?
//    
//    /// Check if there are any indicators (enabled or disabled)
//    private var hasAnyIndicators: Bool {
//        !indicatorManager.activeIndicators.movingAverages.isEmpty ||
//        indicatorManager.activeIndicators.rsi != nil
//    }
//    
//    var body: some View {
//        ScrollView(.vertical, showsIndicators: true) {
//            VStack(spacing: 20) {
//                // Header
//                headerSection
//                
//                // Add Indicator Buttons
//                addIndicatorButtons
//                
//                // Active Indicators List
//                if hasAnyIndicators {
//                    activeIndicatorsSection
//                } else {
//                    emptyStateView
//                }
//                
//                // Extra bottom padding for safe area/scrolling
//                Spacer()
//                    .frame(height: 60)
//            }
//            .padding(.horizontal, 16)
//            .padding(.top, 8)
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
//                    let enabledCount = indicatorManager.activeIndicatorCount
//                    let totalCount = indicatorManager.activeIndicators.movingAverages.count +
//                        (indicatorManager.activeIndicators.rsi != nil ? 1 : 0)
//                    Text("\(enabledCount)/\(totalCount) active")
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
//    // MARK: - Add Indicator Buttons
//    
//    private var addIndicatorButtons: some View {
//        HStack(spacing: 12) {
//            // Add EMA Button
//            AddIndicatorButton(
//                title: "Add EMA",
//                subtitle: "Moving Average",
//                icon: "chart.line.uptrend.xyaxis",
//                color: .cyan
//            ) {
//                showEMASheet = true
//            }
//            
//            // Add RSI Button
//            AddIndicatorButton(
//                title: "Add RSI",
//                subtitle: "Oscillator",
//                icon: "waveform.path.ecg",
//                color: .purple,
//                isActive: indicatorManager.isRSIActive
//            ) {
//                if indicatorManager.isRSIActive {
//                    // If already active, show edit sheet
//                    editingRSIConfig = indicatorManager.activeIndicators.rsi
//                } else {
//                    showRSISheet = true
//                }
//            }
//        }
//        .sheet(isPresented: $showEMASheet) {
//            AddEMASheet(indicatorManager: indicatorManager) {
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//        .sheet(isPresented: $showRSISheet) {
//            AddRSISheet(indicatorManager: indicatorManager) {
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//    }
//    
//    // MARK: - Active Indicators Section
//    
//    private var activeIndicatorsSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack {
//                Text("Active Indicators")
//                    .font(.headline)
//                    .foregroundColor(.white.opacity(0.8))
//                
//                Spacer()
//                
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
//                    ActiveIndicatorRow(
//                        label: config.label,
//                        color: config.color.color,
//                        isEnabled: config.isEnabled,
//                        onToggle: {
//                            indicatorManager.toggleMovingAverage(id: config.id)
//                            onRecalculate()
//                        },
//                        onEdit: {
//                            editingMAConfig = config
//                        },
//                        onRemove: {
//                            indicatorManager.removeMovingAverage(id: config.id)
//                            onRecalculate()
//                        }
//                    )
//                }
//                
//                // RSI
//                if let rsiConfig = indicatorManager.activeIndicators.rsi {
//                    ActiveIndicatorRow(
//                        label: rsiConfig.label,
//                        color: rsiConfig.color.color,
//                        isEnabled: rsiConfig.isEnabled,
//                        onToggle: {
//                            indicatorManager.toggleRSI()
//                            onRecalculate()
//                        },
//                        onEdit: {
//                            editingRSIConfig = rsiConfig
//                        },
//                        onRemove: {
//                            indicatorManager.disableRSI()
//                            onRecalculate()
//                        }
//                    )
//                }
//            }
//        }
//        .padding()
//        .background(Color.white.opacity(0.05))
//        .cornerRadius(12)
//        .sheet(item: $editingMAConfig) { config in
//            EditEMASheet(config: config) { updatedConfig in
//                indicatorManager.updateMovingAverage(updatedConfig)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//        .sheet(item: $editingRSIConfig) { config in
//            EditRSISheet(config: config) { updatedConfig in
//                indicatorManager.updateRSI(updatedConfig)
//                onRecalculate()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.visible)
//        }
//    }
//    
//    // MARK: - Empty State
//    
//    private var emptyStateView: some View {
//        VStack(spacing: 12) {
//            Image(systemName: "chart.line.uptrend.xyaxis.circle")
//                .font(.system(size: 40))
//                .foregroundColor(.gray.opacity(0.5))
//            
//            Text("No indicators active")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//            
//            Text("Tap the buttons above to add EMA or RSI")
//                .font(.caption)
//                .foregroundColor(.gray.opacity(0.7))
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 30)
//        .background(Color.white.opacity(0.03))
//        .cornerRadius(12)
//    }
//    
//    // MARK: - Actions
//    
//    private func clearAllIndicators() {
//        indicatorManager.resetToDefaults()
//        onRecalculate()
//    }
//}
//
//// MARK: - Add Indicator Button
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
//                ZStack {
//                    Circle()
//                        .fill(isActive ? color : color.opacity(0.2))
//                        .frame(width: 50, height: 50)
//                    
//                    Image(systemName: icon)
//                        .font(.system(size: 22))
//                        .foregroundColor(isActive ? .white : color)
//                }
//                
//                Text(title)
//                    .font(.subheadline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.white)
//                
//                Text(subtitle)
//                    .font(.caption2)
//                    .foregroundColor(.gray)
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 16)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color.white.opacity(0.05))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1)
//                    )
//            )
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//// MARK: - Active Indicator Row
//
//struct ActiveIndicatorRow: View {
//    let label: String
//    let color: Color
//    let isEnabled: Bool
//    let onToggle: () -> Void
//    let onEdit: () -> Void
//    let onRemove: () -> Void
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            // Color indicator
//            Circle()
//                .fill(color)
//                .frame(width: 10, height: 10)
//            
//            // Label
//            Text(label)
//                .font(.subheadline)
//                .foregroundColor(isEnabled ? .white : .gray)
//            
//            Spacer()
//            
//            // Toggle
//            Toggle("", isOn: Binding(
//                get: { isEnabled },
//                set: { _ in onToggle() }
//            ))
//            .toggleStyle(SwitchToggleStyle(tint: color))
//            .labelsHidden()
//            .scaleEffect(0.8)
//            
//            // Edit button
//            Button(action: onEdit) {
//                Image(systemName: "gearshape")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//            }
//            
//            // Remove button
//            Button(action: onRemove) {
//                Image(systemName: "xmark.circle.fill")
//                    .font(.caption)
//                    .foregroundColor(.red.opacity(0.7))
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 10)
//        .background(Color.white.opacity(0.05))
//        .cornerRadius(8)
//    }
//}
//
//// MARK: - Add EMA Sheet
//
//struct AddEMASheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    
//    @State private var selectedPeriod: Int = 20
//    @State private var selectedColor: Color = .cyan
//    
//    private let presetPeriods = [9, 20, 50, 100, 200]
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 24) {
//                    // Period Selection
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Period")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        // Preset buttons
//                        HStack(spacing: 8) {
//                            ForEach(presetPeriods, id: \.self) { period in
//                                PeriodButton(
//                                    period: period,
//                                    isSelected: selectedPeriod == period,
//                                    color: colorForPeriod(period)
//                                ) {
//                                    selectedPeriod = period
//                                    selectedColor = colorForPeriod(period)
//                                }
//                            }
//                        }
//                        
//                        // Custom stepper
//                        HStack {
//                            Text("Custom:")
//                                .foregroundColor(.gray)
//                            Stepper("\(selectedPeriod)", value: $selectedPeriod, in: 2...300)
//                                .foregroundColor(.white)
//                        }
//                        .padding()
//                        .background(Color.white.opacity(0.05))
//                        .cornerRadius(8)
//                    }
//                    
//                    // Color Selection
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Line Color")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        ColorPicker("", selection: $selectedColor)
//                            .labelsHidden()
//                            .frame(height: 40)
//                    }
//                    
//                    // Preview
//                    HStack {
//                        Circle()
//                            .fill(selectedColor)
//                            .frame(width: 12, height: 12)
//                        Text("EMA \(selectedPeriod)")
//                            .font(.title3)
//                            .fontWeight(.semibold)
//                            .foregroundColor(.white)
//                        Spacer()
//                    }
//                    .padding()
//                    .background(Color.white.opacity(0.05))
//                    .cornerRadius(8)
//                    
//                    Spacer(minLength: 20)
//                    
//                    // Add Button
//                    Button(action: addEMA) {
//                        Text("Add EMA \(selectedPeriod)")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(selectedColor)
//                            .cornerRadius(12)
//                    }
//                }
//                .padding()
//            }
//            .background(Color.black.ignoresSafeArea())
//            .navigationTitle("Add EMA")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                        .foregroundColor(.white)
//                }
//            }
//        }
//    }
//    
//    private func addEMA() {
//        indicatorManager.addEMA(period: selectedPeriod, color: selectedColor)
//        onAdd()
//        dismiss()
//    }
//    
//    private func colorForPeriod(_ period: Int) -> Color {
//        switch period {
//        case 9: return .cyan
//        case 20: return .yellow
//        case 50: return .orange
//        case 100: return .red
//        case 200: return .purple
//        default: return .blue
//        }
//    }
//}
//
//// MARK: - Add RSI Sheet
//
//struct AddRSISheet: View {
//    @Environment(\.dismiss) var dismiss
//    @ObservedObject var indicatorManager: IndicatorManager
//    let onAdd: () -> Void
//    
//    @State private var period: Int = 14
//    @State private var overboughtLevel: Double = 70
//    @State private var oversoldLevel: Double = 30
//    @State private var lineColor: Color = .purple
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 24) {
//                    // Period Selection
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Period")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        HStack(spacing: 8) {
//                            ForEach([7, 14, 21], id: \.self) { p in
//                                PeriodButton(period: p, isSelected: period == p, color: .purple) {
//                                    period = p
//                                }
//                            }
//                        }
//                        
//                        HStack {
//                            Text("Custom:")
//                                .foregroundColor(.gray)
//                            Stepper("\(period)", value: $period, in: 5...50)
//                                .foregroundColor(.white)
//                        }
//                        .padding()
//                        .background(Color.white.opacity(0.05))
//                        .cornerRadius(8)
//                    }
//                    
//                    // Levels
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Levels")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        HStack {
//                            Text("Overbought")
//                                .foregroundColor(.gray)
//                            Spacer()
//                            HStack {
//                                Slider(value: $overboughtLevel, in: 50...90, step: 5)
//                                    .frame(width: 120)
//                                Text("\(Int(overboughtLevel))")
//                                    .foregroundColor(.red)
//                                    .frame(width: 30)
//                            }
//                        }
//                        
//                        HStack {
//                            Text("Oversold")
//                                .foregroundColor(.gray)
//                            Spacer()
//                            HStack {
//                                Slider(value: $oversoldLevel, in: 10...50, step: 5)
//                                    .frame(width: 120)
//                                Text("\(Int(oversoldLevel))")
//                                    .foregroundColor(.green)
//                                    .frame(width: 30)
//                            }
//                        }
//                    }
//                    .padding()
//                    .background(Color.white.opacity(0.05))
//                    .cornerRadius(8)
//                    
//                    // Color
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("Line Color")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        ColorPicker("", selection: $lineColor)
//                            .labelsHidden()
//                            .frame(height: 40)
//                    }
//                    
//                    Spacer(minLength: 20)
//                    
//                    // Add Button
//                    Button(action: addRSI) {
//                        Text("Add RSI \(period)")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(lineColor)
//                            .cornerRadius(12)
//                    }
//                }
//                .padding()
//            }
//            .background(Color.black.ignoresSafeArea())
//            .navigationTitle("Add RSI")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                        .foregroundColor(.white)
//                }
//            }
//        }
//    }
//    
//    private func addRSI() {
//        let config = RSIConfig(
//            color: CodableColor(lineColor),
//            period: period,
//            overboughtLevel: overboughtLevel,
//            oversoldLevel: oversoldLevel
//        )
//        indicatorManager.enableRSI(config: config)
//        onAdd()
//        dismiss()
//    }
//}
//
//// MARK: - Edit EMA Sheet
//
//struct EditEMASheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: MovingAverageConfig
//    let onSave: (MovingAverageConfig) -> Void
//    
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Period") {
//                    Stepper("Period: \(config.period)", value: $config.period, in: 2...300)
//                }
//                
//                Section("Appearance") {
//                    ColorPicker("Line Color", selection: Binding(
//                        get: { config.color.color },
//                        set: { config.color = CodableColor($0) }
//                    ))
//                    
//                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))",
//                            value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
//                }
//                
//                Section("Price Source") {
//                    Picker("Source", selection: $config.priceSource) {
//                        ForEach(PriceSource.allCases, id: \.self) { source in
//                            Text(source.rawValue).tag(source)
//                        }
//                    }
//                }
//            }
//            .scrollContentBackground(.hidden)
//            .background(Color.black.ignoresSafeArea())
//            .navigationTitle("Edit \(config.label)")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Save") {
//                        onSave(config)
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Edit RSI Sheet
//
//struct EditRSISheet: View {
//    @Environment(\.dismiss) var dismiss
//    @State var config: RSIConfig
//    let onSave: (RSIConfig) -> Void
//    
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Period") {
//                    Stepper("Period: \(config.period)", value: $config.period, in: 5...50)
//                }
//                
//                Section("Levels") {
//                    HStack {
//                        Text("Overbought")
//                        Spacer()
//                        TextField("", value: $config.overboughtLevel, format: .number)
//                            .keyboardType(.decimalPad)
//                            .multilineTextAlignment(.trailing)
//                            .frame(width: 60)
//                    }
//                    
//                    HStack {
//                        Text("Oversold")
//                        Spacer()
//                        TextField("", value: $config.oversoldLevel, format: .number)
//                            .keyboardType(.decimalPad)
//                            .multilineTextAlignment(.trailing)
//                            .frame(width: 60)
//                    }
//                    
//                    Toggle("Show Level Zones", isOn: $config.showLevels)
//                }
//                
//                Section("Appearance") {
//                    ColorPicker("Line Color", selection: Binding(
//                        get: { config.color.color },
//                        set: { config.color = CodableColor($0) }
//                    ))
//                    
//                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))",
//                            value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
//                }
//            }
//            .scrollContentBackground(.hidden)
//            .background(Color.black.ignoresSafeArea())
//            .navigationTitle("Edit RSI")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Save") {
//                        onSave(config)
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Period Button
//
//struct PeriodButton: View {
//    let period: Int
//    let isSelected: Bool
//    let color: Color
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            Text("\(period)")
//                .font(.subheadline)
//                .fontWeight(isSelected ? .bold : .regular)
//                .foregroundColor(isSelected ? .white : .gray)
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 10)
//                .background(isSelected ? color : Color.white.opacity(0.1))
//                .cornerRadius(8)
//        }
//        .buttonStyle(.plain)
//    }
//}
//
//// MARK: - Identifiable Extensions
//
//extension MovingAverageConfig: Identifiable {}
//extension RSIConfig: Identifiable {}
//
