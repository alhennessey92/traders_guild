//
//  IndicatorSettingsView.swift
//  traders_guild
//
//  Professional indicator settings UI for the bottom sheet
//  Allows adding, configuring, and removing indicators
//  SCROLLABLE to ensure all content is accessible
//

import SwiftUI

// MARK: - Main Indicator Settings Content (for MainView bottom sheet)

/// The indicator content view for ChartBottomSheet
/// Drop this into your indicatorContent in MainView
struct IndicatorSettingsContent: View {
    @ObservedObject var indicatorManager: IndicatorManager
    let onRecalculate: () -> Void
    
    // Sheet presentation states
    @State private var showEMASheet = false
    @State private var showRSISheet = false
    @State private var editingMAConfig: MovingAverageConfig?
    @State private var editingRSIConfig: RSIConfig?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Add Indicator Buttons
                addIndicatorButtons
                
                // Active Indicators List
                if indicatorManager.activeIndicatorCount > 0 {
                    activeIndicatorsSection
                } else {
                    emptyStateView
                }
                
                // Extra bottom padding for safe area/scrolling
                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
                
                if indicatorManager.activeIndicatorCount > 0 {
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
    
    // MARK: - Add Indicator Buttons
    
    private var addIndicatorButtons: some View {
        HStack(spacing: 12) {
            // Add EMA Button
            AddIndicatorButton(
                title: "Add EMA",
                subtitle: "Moving Average",
                icon: "chart.line.uptrend.xyaxis",
                color: .cyan
            ) {
                showEMASheet = true
            }
            
            // Add RSI Button
            AddIndicatorButton(
                title: "Add RSI",
                subtitle: "Oscillator",
                icon: "waveform.path.ecg",
                color: .purple,
                isActive: indicatorManager.isRSIActive
            ) {
                if indicatorManager.isRSIActive {
                    // If already active, show edit sheet
                    editingRSIConfig = indicatorManager.activeIndicators.rsi
                } else {
                    showRSISheet = true
                }
            }
        }
        .sheet(isPresented: $showEMASheet) {
            AddEMASheet(indicatorManager: indicatorManager) {
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRSISheet) {
            AddRSISheet(indicatorManager: indicatorManager) {
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Active Indicators Section
    
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
                    ActiveIndicatorRow(
                        label: config.label,
                        color: config.color.color,
                        isEnabled: config.isEnabled,
                        onToggle: {
                            indicatorManager.toggleMovingAverage(id: config.id)
                            onRecalculate()
                        },
                        onEdit: {
                            editingMAConfig = config
                        },
                        onRemove: {
                            indicatorManager.removeMovingAverage(id: config.id)
                            onRecalculate()
                        }
                    )
                }
                
                // RSI
                if let rsiConfig = indicatorManager.activeIndicators.rsi {
                    ActiveIndicatorRow(
                        label: rsiConfig.label,
                        color: rsiConfig.color.color,
                        isEnabled: rsiConfig.isEnabled,
                        onToggle: {
                            indicatorManager.toggleRSI()
                            onRecalculate()
                        },
                        onEdit: {
                            editingRSIConfig = rsiConfig
                        },
                        onRemove: {
                            indicatorManager.disableRSI()
                            onRecalculate()
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .sheet(item: $editingMAConfig) { config in
            EditEMASheet(config: config) { updatedConfig in
                indicatorManager.updateMovingAverage(updatedConfig)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingRSIConfig) { config in
            EditRSISheet(config: config) { updatedConfig in
                indicatorManager.updateRSI(updatedConfig)
                onRecalculate()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No indicators active")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Tap the buttons above to add EMA or RSI")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func clearAllIndicators() {
        indicatorManager.resetToDefaults()
        onRecalculate()
    }
}

// MARK: - Add Indicator Button

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
                ZStack {
                    Circle()
                        .fill(isActive ? color : color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isActive ? .white : color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Indicator Row

struct ActiveIndicatorRow: View {
    let label: String
    let color: Color
    let isEnabled: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            // Label
            Text(label)
                .font(.subheadline)
                .foregroundColor(isEnabled ? .white : .gray)
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: color))
            .labelsHidden()
            .scaleEffect(0.8)
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Add EMA Sheet

struct AddEMASheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    
    @State private var selectedPeriod: Int = 20
    @State private var selectedColor: Color = .cyan
    
    private let presetPeriods = [9, 20, 50, 100, 200]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Period")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        // Preset buttons
                        HStack(spacing: 8) {
                            ForEach(presetPeriods, id: \.self) { period in
                                PeriodButton(
                                    period: period,
                                    isSelected: selectedPeriod == period,
                                    color: colorForPeriod(period)
                                ) {
                                    selectedPeriod = period
                                    selectedColor = colorForPeriod(period)
                                }
                            }
                        }
                        
                        // Custom stepper
                        HStack {
                            Text("Custom:")
                                .foregroundColor(.gray)
                            Stepper("\(selectedPeriod)", value: $selectedPeriod, in: 5...300)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Line Color")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                            .frame(height: 40)
                    }
                    
                    // Preview
                    HStack {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 12, height: 12)
                        Text("EMA \(selectedPeriod)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Spacer(minLength: 20)
                    
                    // Add Button
                    Button(action: addEMA) {
                        Text("Add EMA \(selectedPeriod)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedColor)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Add EMA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func addEMA() {
        indicatorManager.addEMA(period: selectedPeriod, color: selectedColor)
        onAdd()
        dismiss()
    }
    
    private func colorForPeriod(_ period: Int) -> Color {
        switch period {
        case 9: return .cyan
        case 20: return .yellow
        case 50: return .orange
        case 100: return .red
        case 200: return .purple
        default: return .blue
        }
    }
}

// MARK: - Add RSI Sheet

struct AddRSISheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indicatorManager: IndicatorManager
    let onAdd: () -> Void
    
    @State private var period: Int = 14
    @State private var overboughtLevel: Double = 70
    @State private var oversoldLevel: Double = 30
    @State private var lineColor: Color = .purple
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Period")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            ForEach([7, 14, 21], id: \.self) { p in
                                PeriodButton(period: p, isSelected: period == p, color: .purple) {
                                    period = p
                                }
                            }
                        }
                        
                        HStack {
                            Text("Custom:")
                                .foregroundColor(.gray)
                            Stepper("\(period)", value: $period, in: 5...50)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Levels
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Levels")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Overbought")
                                .foregroundColor(.gray)
                            Spacer()
                            HStack {
                                Slider(value: $overboughtLevel, in: 50...90, step: 5)
                                    .frame(width: 120)
                                Text("\(Int(overboughtLevel))")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                            }
                        }
                        
                        HStack {
                            Text("Oversold")
                                .foregroundColor(.gray)
                            Spacer()
                            HStack {
                                Slider(value: $oversoldLevel, in: 10...50, step: 5)
                                    .frame(width: 120)
                                Text("\(Int(oversoldLevel))")
                                    .foregroundColor(.green)
                                    .frame(width: 30)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Color
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Line Color")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ColorPicker("", selection: $lineColor)
                            .labelsHidden()
                            .frame(height: 40)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Add Button
                    Button(action: addRSI) {
                        Text("Add RSI \(period)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(lineColor)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Add RSI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func addRSI() {
        let config = RSIConfig(
            color: CodableColor(lineColor),
            period: period,
            overboughtLevel: overboughtLevel,
            oversoldLevel: oversoldLevel
        )
        indicatorManager.enableRSI(config: config)
        onAdd()
        dismiss()
    }
}

// MARK: - Edit EMA Sheet

struct EditEMASheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: MovingAverageConfig
    let onSave: (MovingAverageConfig) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Period") {
                    Stepper("Period: \(config.period)", value: $config.period, in: 5...300)
                }
                
                Section("Appearance") {
                    ColorPicker("Line Color", selection: Binding(
                        get: { config.color.color },
                        set: { config.color = CodableColor($0) }
                    ))
                    
                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))",
                            value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
                }
                
                Section("Price Source") {
                    Picker("Source", selection: $config.priceSource) {
                        ForEach(PriceSource.allCases, id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Edit \(config.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit RSI Sheet

struct EditRSISheet: View {
    @Environment(\.dismiss) var dismiss
    @State var config: RSIConfig
    let onSave: (RSIConfig) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Period") {
                    Stepper("Period: \(config.period)", value: $config.period, in: 5...50)
                }
                
                Section("Levels") {
                    HStack {
                        Text("Overbought")
                        Spacer()
                        TextField("", value: $config.overboughtLevel, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("Oversold")
                        Spacer()
                        TextField("", value: $config.oversoldLevel, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    Toggle("Show Level Zones", isOn: $config.showLevels)
                }
                
                Section("Appearance") {
                    ColorPicker("Line Color", selection: Binding(
                        get: { config.color.color },
                        set: { config.color = CodableColor($0) }
                    ))
                    
                    Stepper("Line Width: \(String(format: "%.1f", config.lineWidth))",
                            value: $config.lineWidth, in: 0.5...4.0, step: 0.5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Edit RSI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Period Button

struct PeriodButton: View {
    let period: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(period)")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? color : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Identifiable Extensions

extension MovingAverageConfig: Identifiable {}
extension RSIConfig: Identifiable {}
