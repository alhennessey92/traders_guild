//
//  ChartSettingsView.swift
//  traders_guild
//
//  Settings sheet for chart display options (grid, candle colors).
//

import SwiftUI

struct ChartSettingsView: View {
    @ObservedObject var settings: ChartSettings
    @ObservedObject private var markerLayoutSettings = MarkerDisplaySettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Grid Lines
                Section(header: Text("Grid Lines")) {
                    Toggle("Show Grid Lines", isOn: $settings.showGridLines)
                        .tint(.cyan)

                    if settings.showGridLines {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Grid Opacity")
                                Spacer()
                                Text("\(Int(settings.gridOpacity * 100))%")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }

                            Slider(value: $settings.gridOpacity, in: 0.05...0.5, step: 0.01)
                                .tint(.cyan)

                            Text("Adjust how visible grid lines appear on the chart")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - Candle Colors
                Section(header: Text("Candle Colors")) {
                    ColorPicker("Bullish (Up)", selection: $settings.bullishCandleColor, supportsOpacity: false)
                    ColorPicker("Bearish (Down)", selection: $settings.bearishCandleColor, supportsOpacity: false)

                    Button("Reset to Default") {
                        settings.bullishCandleColor = .green
                        settings.bearishCandleColor = .red
                    }
                    .foregroundColor(.cyan)
                    .font(.caption)
                }

                Section(header: Text("Marker Layout")) {
                    markerLayoutSliderRow(
                        title: "Candle Distance",
                        value: baseOffsetBinding,
                        range: 40...140
                    )
                    markerLayoutSliderRow(
                        title: "Stack Distance",
                        value: stackOffsetBinding,
                        range: 18...90
                    )
                    markerLayoutSliderRow(
                        title: "Min Stack Spacing",
                        value: minStackSpacingBinding,
                        range: 16...80
                    )
                    markerLayoutSliderRow(
                        title: "Proximity Spread",
                        value: proximityTierOffsetBinding,
                        range: 8...70
                    )
                    markerLayoutSliderRow(
                        title: "Placement Extra Offset",
                        value: placementExtraOffsetBinding,
                        range: 10...100
                    )

                    Button("Reset Marker Layout") {
                        markerLayoutSettings.resetToDefaults()
                    }
                    .foregroundColor(.cyan)
                    .font(.caption)
                }
            }
            .navigationTitle("Chart Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var baseOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(markerLayoutSettings.baseOffset) },
            set: { markerLayoutSettings.baseOffset = CGFloat($0) }
        )
    }

    private var stackOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(markerLayoutSettings.stackOffset) },
            set: { markerLayoutSettings.stackOffset = CGFloat($0) }
        )
    }

    private var minStackSpacingBinding: Binding<Double> {
        Binding(
            get: { Double(markerLayoutSettings.minStackSpacing) },
            set: { markerLayoutSettings.minStackSpacing = CGFloat($0) }
        )
    }

    private var proximityTierOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(markerLayoutSettings.proximityTierOffset) },
            set: { markerLayoutSettings.proximityTierOffset = CGFloat($0) }
        )
    }

    private var placementExtraOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(markerLayoutSettings.placementExtraOffset) },
            set: { markerLayoutSettings.placementExtraOffset = CGFloat($0) }
        )
    }

    @ViewBuilder
    private func markerLayoutSliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))")
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
            }

            Slider(value: value, in: range, step: 1)
                .tint(.cyan)
        }
        .padding(.vertical, 2)
    }
}
