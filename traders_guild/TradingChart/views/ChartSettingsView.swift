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
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                AdminSheetHeader(
                    icon: "slider.horizontal.3",
                    iconColor: AppColors.accentColor,
                    title: "Chart Settings",
                    subtitle: "Grid, timeframe panel, and marker layout controls"
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)

                Divider()
                    .background(AppColors.surfaceWhite15)
                    .padding(.top, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        gridLinesCard
                        candleColorsCard
                        timeframeViewportCard
                        markerLayoutCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }

            SheetCloseButton(action: { dismiss() })
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .background(AdminSheetBackground())
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    private var gridLinesCard: some View {
        AdminSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Grid Lines", subtitle: "Control visibility and chart contrast.")

                settingsToggleRow(
                    title: "Show Grid Lines",
                    subtitle: "Display horizontal and vertical guides on the chart.",
                    isOn: $settings.showGridLines
                )

                if settings.showGridLines {
                    sliderRow(
                        title: "Grid Opacity",
                        valueText: "\(Int(settings.gridOpacity * 100))%",
                        value: $settings.gridOpacity,
                        range: 0.05...0.5,
                        step: 0.01
                    )
                }
            }
        }
    }

    private var candleColorsCard: some View {
        AdminSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Candle Colors", subtitle: "Match bullish and bearish candles to your preferred contrast.")

                settingsColorPicker(
                    title: "Bullish (Up)",
                    selection: $settings.bullishCandleColor
                )

                settingsColorPicker(
                    title: "Bearish (Down)",
                    selection: $settings.bearishCandleColor
                )

                settingsToggleRow(
                    title: "Semi-Transparent Bullish Candles",
                    subtitle: "Keep the default tinted fill for bullish bodies instead of rendering them solid.",
                    isOn: $settings.useSemiTransparentBullishCandles
                )

                secondaryActionButton(title: "Reset to Default") {
                    settings.bullishCandleColor = AppColors.defaultBullishCandleGreen
                    settings.bearishCandleColor = .red
                    settings.useSemiTransparentBullishCandles = true
                }
            }
        }
    }

    private var timeframeViewportCard: some View {
        AdminSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Timeframe Panel Viewport", subtitle: "Show where the main chart window sits inside higher-timeframe panels.")

                settingsToggleRow(
                    title: "Show Viewport Window",
                    subtitle: "Highlights the part of the main chart visible in linked timeframe panels.",
                    isOn: $settings.showViewportWindow
                )

                if settings.showViewportWindow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Style")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.greyText)

                        Picker("Style", selection: $settings.viewportWindowStyle) {
                            ForEach(ViewportWindowStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(ThemeManager.shared.currentTheme.colorScheme)
                    }

                    sliderRow(
                        title: "Opacity",
                        valueText: "\(Int(settings.viewportWindowOpacity * 100))%",
                        value: $settings.viewportWindowOpacity,
                        range: 0.1...0.7,
                        step: 0.05
                    )
                }
            }
        }
    }

    private var markerLayoutCard: some View {
        AdminSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Marker Layout", subtitle: "Tune spacing and stacking behavior for marker rendering.")

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
                    range: Double(MarkerPositionCalculator.hardMinimumStackSpacing)...80
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

                secondaryActionButton(title: "Reset Marker Layout") {
                    markerLayoutSettings.resetToDefaults()
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
        sliderRow(
            title: title,
            valueText: "\(Int(value.wrappedValue.rounded()))",
            value: value,
            range: range,
            step: 1
        )
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.whiteText)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
    }

    private func settingsToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.whiteText)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.accentColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.insetPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.standardSearchFieldStroke.opacity(0.65), lineWidth: 1)
                )
        )
    }

    private func settingsColorPicker(
        title: String,
        selection: Binding<Color>
    ) -> some View {
        ColorPicker(title, selection: selection, supportsOpacity: false)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppColors.whiteText)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.insetPanelBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppColors.standardSearchFieldStroke.opacity(0.65), lineWidth: 1)
                    )
            )
    }

    private func secondaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.accentColor.opacity(0.14))
            )
            .buttonStyle(.plain)
    }

    private func sliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
                Spacer()
                Text(valueText)
                    .foregroundColor(AppColors.surfaceWhite80)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
            }

            Slider(value: value, in: range, step: step)
                .tint(AppColors.accentColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.insetPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.standardSearchFieldStroke.opacity(0.65), lineWidth: 1)
                )
        )
    }
}
