//
//  ChartSettingsView.swift
//  traders_guild
//
//  Settings sheet for chart display options (grid, candle colors).
//

import SwiftUI

struct ChartSettingsView: View {
    @ObservedObject var settings: ChartSettings
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
}
