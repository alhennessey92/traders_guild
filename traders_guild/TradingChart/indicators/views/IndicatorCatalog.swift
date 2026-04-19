import SwiftUI

struct IndicatorCatalogItem: Identifiable, Hashable {
    let type: IndicatorType

    var id: String { type.rawValue }
    var title: String { type.shortName }
    var description: String { type.displayName }
    var icon: String { type.icon }
    var category: IndicatorCategory { type.category }
    var isPanelIndicator: Bool { !type.isOverlay }

    var payloadName: String {
        switch type {
        case .bollingerBands:
            return "Bollinger Bands"
        case .donchianChannels:
            return "Donchian Channels"
        case .keltnerChannels:
            return "Keltner Channels"
        case .parabolicSAR:
            return "Parabolic SAR"
        default:
            return type.rawValue
        }
    }

    var defaultSettings: [String: AnyCodable]? {
        switch type {
        case .ema, .sma, .wma, .hma:
            return [
                "period": AnyCodable(20),
                "source": AnyCodable("close"),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(type.defaultColor),
            ]
        case .vwap:
            return [
                "showStandardDeviationBands": AnyCodable(false),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.orange),
                "upperBandColor": Self.colorValue(AppColors.statusWarning50),
                "lowerBandColor": Self.colorValue(AppColors.statusWarning50),
            ]
        case .bollingerBands:
            return [
                "period": AnyCodable(20),
                "standardDeviations": AnyCodable(2.0),
                "showFill": AnyCodable(true),
                "lineWidth": AnyCodable(1.0),
                "color": Self.colorValue(.gray),
                "upperBandColor": Self.colorValue(AppColors.statusNegative70),
                "lowerBandColor": Self.colorValue(AppColors.statusPositive70),
                "fillColor": Self.colorValue(AppColors.statusInfo10),
            ]
        case .donchianChannels:
            return [
                "period": AnyCodable(20),
                "showFill": AnyCodable(true),
                "showMiddleLine": AnyCodable(true),
                "lineWidth": AnyCodable(1.0),
                "color": Self.colorValue(.gray),
                "upperBandColor": Self.colorValue(AppColors.statusInfo80),
                "lowerBandColor": Self.colorValue(AppColors.statusInfo80),
                "fillColor": Self.colorValue(AppColors.statusInfo10),
            ]
        case .keltnerChannels:
            return [
                "emaPeriod": AnyCodable(20),
                "atrPeriod": AnyCodable(14),
                "atrMultiplier": AnyCodable(2.0),
                "showFill": AnyCodable(true),
                "lineWidth": AnyCodable(1.0),
                "color": Self.colorValue(.purple),
                "upperBandColor": Self.colorValue(AppColors.statusSecondary70),
                "lowerBandColor": Self.colorValue(AppColors.statusSecondary70),
                "fillColor": Self.colorValue(AppColors.statusSecondary10),
            ]
        case .parabolicSAR:
            return [
                "accelerationStart": AnyCodable(0.02),
                "accelerationIncrement": AnyCodable(0.02),
                "accelerationMax": AnyCodable(0.2),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.yellow),
                "bullishColor": Self.colorValue(.green),
                "bearishColor": Self.colorValue(.red),
            ]
        case .rsi:
            return [
                "period": AnyCodable(14),
                "overboughtLevel": AnyCodable(70.0),
                "oversoldLevel": AnyCodable(30.0),
                "showLevels": AnyCodable(true),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.purple),
                "overboughtColor": Self.colorValue(AppColors.statusNegative15),
                "oversoldColor": Self.colorValue(AppColors.statusPositive15),
            ]
        case .macd:
            return [
                "fastPeriod": AnyCodable(12),
                "slowPeriod": AnyCodable(26),
                "signalPeriod": AnyCodable(9),
                "showHistogram": AnyCodable(true),
                "showSignalLine": AnyCodable(true),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.cyan),
                "signalColor": Self.colorValue(.orange),
                "histogramPositiveColor": Self.colorValue(AppColors.statusPositive70),
                "histogramNegativeColor": Self.colorValue(AppColors.statusNegative70),
            ]
        case .stochastic:
            return [
                "kPeriod": AnyCodable(14),
                "dPeriod": AnyCodable(3),
                "smoothK": AnyCodable(3),
                "overboughtLevel": AnyCodable(80.0),
                "oversoldLevel": AnyCodable(20.0),
                "showLevels": AnyCodable(true),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.yellow),
                "dColor": Self.colorValue(.red),
                "overboughtColor": Self.colorValue(AppColors.statusNegative15),
                "oversoldColor": Self.colorValue(AppColors.statusPositive15),
            ]
        case .cci:
            return [
                "period": AnyCodable(20),
                "overboughtLevel": AnyCodable(100.0),
                "oversoldLevel": AnyCodable(-100.0),
                "showLevels": AnyCodable(true),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.orange),
                "overboughtColor": Self.colorValue(AppColors.statusNegative15),
                "oversoldColor": Self.colorValue(AppColors.statusPositive15),
            ]
        case .williamsR:
            return [
                "period": AnyCodable(14),
                "overboughtLevel": AnyCodable(-20.0),
                "oversoldLevel": AnyCodable(-80.0),
                "showLevels": AnyCodable(true),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.pink),
                "overboughtColor": Self.colorValue(AppColors.statusNegative15),
                "oversoldColor": Self.colorValue(AppColors.statusPositive15),
            ]
        case .atr:
            return [
                "period": AnyCodable(14),
                "lineWidth": AnyCodable(1.5),
                "color": Self.colorValue(.red),
            ]
        case .volume:
            return [
                "showMA": AnyCodable(false),
                "maPeriod": AnyCodable(20),
                "lineWidth": AnyCodable(1.0),
                "color": Self.colorValue(.blue),
                "bullishColor": Self.colorValue(AppColors.statusPositive70),
                "bearishColor": Self.colorValue(AppColors.statusNegative70),
                "maColor": Self.colorValue(.yellow),
            ]
        }
    }

    private static func colorValue(_ color: Color) -> AnyCodable {
        let codable = CodableColor(color)
        return AnyCodable(
            [
                "red": codable.red,
                "green": codable.green,
                "blue": codable.blue,
                "opacity": codable.opacity,
            ]
        )
    }

    static let all: [IndicatorCatalogItem] = IndicatorType.allCases.map { IndicatorCatalogItem(type: $0) }

    static func item(forIndicatorName indicatorName: String) -> IndicatorCatalogItem? {
        guard let type = type(forIndicatorName: indicatorName) else { return nil }
        return all.first { $0.type == type }
    }

    static func type(forIndicatorName indicatorName: String) -> IndicatorType? {
        let normalized = indicatorName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if normalized.contains("BOLL") { return .bollingerBands }
        if normalized.contains("DONCHIAN") { return .donchianChannels }
        if normalized.contains("KELTNER") { return .keltnerChannels }
        if normalized.contains("PARABOLIC") || normalized.contains(" SAR") || normalized == "SAR" {
            return .parabolicSAR
        }
        if normalized.contains("WILLIAMS") { return .williamsR }
        if normalized == "RSI" || normalized.contains("RELATIVE STRENGTH") { return .rsi }
        if normalized == "MACD" { return .macd }
        if normalized.contains("STOCH") { return .stochastic }
        if normalized == "CCI" || normalized.contains("COMMODITY CHANNEL") { return .cci }
        if normalized == "ATR" || normalized.contains("AVERAGE TRUE RANGE") { return .atr }
        if normalized == "VOLUME" { return .volume }
        if normalized == "VWAP" || normalized.contains("WEIGHTED AVERAGE PRICE") { return .vwap }
        if normalized == "EMA" || normalized.contains("EXPONENTIAL MOVING") { return .ema }
        if normalized == "SMA" || normalized.contains("SIMPLE MOVING") { return .sma }
        if normalized == "WMA" || normalized.contains("WEIGHTED MOVING") { return .wma }
        if normalized == "HMA" || normalized.contains("HULL MOVING") { return .hma }

        return nil
    }
}

struct IndicatorEditingContext: Identifiable {
    let id: UUID = UUID()
    let item: IndicatorCatalogItem
    let indicatorName: String
    let existingSettings: [String: AnyCodable]?
    /// Non-nil for multi-instance indicators (moving averages) so saves route to the
    /// specific instance rather than creating a new one.
    let instanceId: UUID?

    init(
        item: IndicatorCatalogItem,
        indicatorName: String,
        existingSettings: [String: AnyCodable]?,
        instanceId: UUID? = nil
    ) {
        self.item = item
        self.indicatorName = indicatorName
        self.existingSettings = existingSettings
        self.instanceId = instanceId
    }
}

struct IndicatorSettingField: Identifiable {
    enum ValueType {
        case int
        case double
        case bool
        case color
    }

    let key: String
    let label: String
    let valueType: ValueType
    let defaultValue: Any

    var id: String { key }

    static func fields(for type: IndicatorType) -> [IndicatorSettingField] {
        switch type {
        case .ema, .sma, .wma, .hma:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
                .init(key: "color", label: "Color", valueType: .color, defaultValue: AppColors.systemCyan),
            ]
        case .vwap:
            return [
                .init(key: "showStandardDeviationBands", label: "Show Std Dev Bands", valueType: .bool, defaultValue: false),
                .init(key: "color", label: "Line Color", valueType: .color, defaultValue: AppColors.statusWarning),
                .init(key: "upperBandColor", label: "Upper Band Color", valueType: .color, defaultValue: AppColors.statusWarning50),
                .init(key: "lowerBandColor", label: "Lower Band Color", valueType: .color, defaultValue: AppColors.statusWarning50),
            ]
        case .bollingerBands:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
                .init(key: "standardDeviations", label: "Std Deviations", valueType: .double, defaultValue: 2.0),
                .init(key: "showFill", label: "Show Fill", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "Middle Line Color", valueType: .color, defaultValue: AppColors.systemGray),
                .init(key: "upperBandColor", label: "Upper Band Color", valueType: .color, defaultValue: AppColors.statusNegative70),
                .init(key: "lowerBandColor", label: "Lower Band Color", valueType: .color, defaultValue: AppColors.statusPositive70),
                .init(key: "fillColor", label: "Fill Color", valueType: .color, defaultValue: AppColors.statusInfo10),
            ]
        case .donchianChannels:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
                .init(key: "showFill", label: "Show Fill", valueType: .bool, defaultValue: true),
                .init(key: "showMiddleLine", label: "Show Middle Line", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "Middle Line Color", valueType: .color, defaultValue: AppColors.systemGray),
                .init(key: "upperBandColor", label: "Upper Band Color", valueType: .color, defaultValue: AppColors.statusInfo80),
                .init(key: "lowerBandColor", label: "Lower Band Color", valueType: .color, defaultValue: AppColors.statusInfo80),
                .init(key: "fillColor", label: "Fill Color", valueType: .color, defaultValue: AppColors.statusInfo10),
            ]
        case .keltnerChannels:
            return [
                .init(key: "emaPeriod", label: "EMA Period", valueType: .int, defaultValue: 20),
                .init(key: "atrPeriod", label: "ATR Period", valueType: .int, defaultValue: 14),
                .init(key: "atrMultiplier", label: "ATR Multiplier", valueType: .double, defaultValue: 2.0),
                .init(key: "showFill", label: "Show Fill", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "EMA Color", valueType: .color, defaultValue: AppColors.systemPurple),
                .init(key: "upperBandColor", label: "Upper Band Color", valueType: .color, defaultValue: AppColors.statusSecondary70),
                .init(key: "lowerBandColor", label: "Lower Band Color", valueType: .color, defaultValue: AppColors.statusSecondary70),
                .init(key: "fillColor", label: "Fill Color", valueType: .color, defaultValue: AppColors.statusSecondary10),
            ]
        case .parabolicSAR:
            return [
                .init(key: "accelerationStart", label: "Acceleration Start", valueType: .double, defaultValue: 0.02),
                .init(key: "accelerationIncrement", label: "Acceleration Increment", valueType: .double, defaultValue: 0.02),
                .init(key: "accelerationMax", label: "Acceleration Max", valueType: .double, defaultValue: 0.2),
                .init(key: "color", label: "Primary Color", valueType: .color, defaultValue: AppColors.systemYellow),
                .init(key: "bullishColor", label: "Bullish Color", valueType: .color, defaultValue: AppColors.statusPositive),
                .init(key: "bearishColor", label: "Bearish Color", valueType: .color, defaultValue: AppColors.statusNegative),
            ]
        case .rsi:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 14),
                .init(key: "overboughtLevel", label: "Overbought", valueType: .double, defaultValue: 70.0),
                .init(key: "oversoldLevel", label: "Oversold", valueType: .double, defaultValue: 30.0),
                .init(key: "showLevels", label: "Show Levels", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "Line Color", valueType: .color, defaultValue: AppColors.systemPurple),
                .init(key: "overboughtColor", label: "Overbought Color", valueType: .color, defaultValue: AppColors.statusNegative15),
                .init(key: "oversoldColor", label: "Oversold Color", valueType: .color, defaultValue: AppColors.statusPositive15),
            ]
        case .macd:
            return [
                .init(key: "fastPeriod", label: "Fast Period", valueType: .int, defaultValue: 12),
                .init(key: "slowPeriod", label: "Slow Period", valueType: .int, defaultValue: 26),
                .init(key: "signalPeriod", label: "Signal Period", valueType: .int, defaultValue: 9),
                .init(key: "showHistogram", label: "Show Histogram", valueType: .bool, defaultValue: true),
                .init(key: "showSignalLine", label: "Show Signal", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "MACD Color", valueType: .color, defaultValue: AppColors.systemCyan),
                .init(key: "signalColor", label: "Signal Color", valueType: .color, defaultValue: AppColors.statusWarning),
                .init(key: "histogramPositiveColor", label: "Histogram + Color", valueType: .color, defaultValue: AppColors.statusPositive70),
                .init(key: "histogramNegativeColor", label: "Histogram - Color", valueType: .color, defaultValue: AppColors.statusNegative70),
            ]
        case .stochastic:
            return [
                .init(key: "kPeriod", label: "K Period", valueType: .int, defaultValue: 14),
                .init(key: "dPeriod", label: "D Period", valueType: .int, defaultValue: 3),
                .init(key: "smoothK", label: "Smooth K", valueType: .int, defaultValue: 3),
                .init(key: "overboughtLevel", label: "Overbought", valueType: .double, defaultValue: 80.0),
                .init(key: "oversoldLevel", label: "Oversold", valueType: .double, defaultValue: 20.0),
                .init(key: "showLevels", label: "Show Levels", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "K Color", valueType: .color, defaultValue: AppColors.systemYellow),
                .init(key: "dColor", label: "D Color", valueType: .color, defaultValue: AppColors.statusNegative),
                .init(key: "overboughtColor", label: "Overbought Color", valueType: .color, defaultValue: AppColors.statusNegative15),
                .init(key: "oversoldColor", label: "Oversold Color", valueType: .color, defaultValue: AppColors.statusPositive15),
            ]
        case .cci:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
                .init(key: "overboughtLevel", label: "Overbought", valueType: .double, defaultValue: 100.0),
                .init(key: "oversoldLevel", label: "Oversold", valueType: .double, defaultValue: -100.0),
                .init(key: "showLevels", label: "Show Levels", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "Line Color", valueType: .color, defaultValue: AppColors.statusWarning),
                .init(key: "overboughtColor", label: "Overbought Color", valueType: .color, defaultValue: AppColors.statusNegative15),
                .init(key: "oversoldColor", label: "Oversold Color", valueType: .color, defaultValue: AppColors.statusPositive15),
            ]
        case .williamsR:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 14),
                .init(key: "overboughtLevel", label: "Overbought", valueType: .double, defaultValue: -20.0),
                .init(key: "oversoldLevel", label: "Oversold", valueType: .double, defaultValue: -80.0),
                .init(key: "showLevels", label: "Show Levels", valueType: .bool, defaultValue: true),
                .init(key: "color", label: "Line Color", valueType: .color, defaultValue: AppColors.systemPink),
                .init(key: "overboughtColor", label: "Overbought Color", valueType: .color, defaultValue: AppColors.statusNegative15),
                .init(key: "oversoldColor", label: "Oversold Color", valueType: .color, defaultValue: AppColors.statusPositive15),
            ]
        case .atr:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 14),
                .init(key: "color", label: "Line Color", valueType: .color, defaultValue: AppColors.statusNegative),
            ]
        case .volume:
            return [
                .init(key: "showMA", label: "Show MA", valueType: .bool, defaultValue: false),
                .init(key: "maPeriod", label: "MA Period", valueType: .int, defaultValue: 20),
                .init(key: "color", label: "Base Color", valueType: .color, defaultValue: AppColors.statusInfo),
                .init(key: "bullishColor", label: "Bullish Color", valueType: .color, defaultValue: AppColors.statusPositive70),
                .init(key: "bearishColor", label: "Bearish Color", valueType: .color, defaultValue: AppColors.statusNegative70),
                .init(key: "maColor", label: "MA Color", valueType: .color, defaultValue: AppColors.systemYellow),
            ]
        }
    }
}

struct IndicatorSettingsEditorSheet: View {
    let context: IndicatorEditingContext
    let onSave: ([String: AnyCodable]?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var intValues: [String: String] = [:]
    @State private var doubleValues: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]
    @State private var colorValues: [String: Color] = [:]

    private var fields: [IndicatorSettingField] {
        IndicatorSettingField.fields(for: context.item.type)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(context.item.description)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)

                    if fields.isEmpty {
                        Text("No editable settings available for this indicator.")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                    } else {
                        ForEach(fields) { field in
                            settingFieldView(field)
                        }
                    }
                }
                .padding(14)
            }
            .background(AppColors.surfaceBlack96)
            .navigationTitle(context.item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildSettings())
                        dismiss()
                    }
                    .disabled(fields.isEmpty)
                }
            }
        }
        .onAppear(perform: loadCurrentValues)
    }

    @ViewBuilder
    private func settingFieldView(_ field: IndicatorSettingField) -> some View {
        switch field.valueType {
        case .int:
            numericField(
                label: field.label,
                text: Binding(
                    get: { intValues[field.key, default: ""] },
                    set: { intValues[field.key] = $0 }
                ),
                keyboard: .numberPad
            )
        case .double:
            numericField(
                label: field.label,
                text: Binding(
                    get: { doubleValues[field.key, default: ""] },
                    set: { doubleValues[field.key] = $0 }
                ),
                keyboard: .decimalPad
            )
        case .bool:
            Toggle(isOn: Binding(
                get: { boolValues[field.key, default: false] },
                set: { boolValues[field.key] = $0 }
            )) {
                Text(field.label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.primaryForeground)
            }
            .tint(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.whiteText.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
                    )
            )
        case .color:
            colorField(
                label: field.label,
                selection: Binding(
                    get: { colorValues[field.key, default: field.defaultValue as? Color ?? .white] },
                    set: { colorValues[field.key] = $0 }
                )
            )
        }
    }

    private func numericField(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryForeground)
                .keyboardType(keyboard)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.whiteText.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }

    private func colorField(label: String, selection: Binding<Color>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            ColorPickerGrid(selectedColor: selection)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.whiteText.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.whiteText.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }

    private func loadCurrentValues() {
        for field in fields {
            switch field.valueType {
            case .int:
                let value = intValue(for: field.key, fallback: field.defaultValue as? Int ?? 0)
                intValues[field.key] = String(value)
            case .double:
                let value = doubleValue(for: field.key, fallback: field.defaultValue as? Double ?? 0)
                doubleValues[field.key] = String(value)
            case .bool:
                let value = boolValue(for: field.key, fallback: field.defaultValue as? Bool ?? false)
                boolValues[field.key] = value
            case .color:
                let fallback = field.defaultValue as? Color ?? .white
                colorValues[field.key] = colorValue(for: field.key, fallback: fallback)
            }
        }
    }

    private func buildSettings() -> [String: AnyCodable]? {
        var merged = context.existingSettings ?? [:]

        for field in fields {
            switch field.valueType {
            case .int:
                let fallback = field.defaultValue as? Int ?? 0
                let parsed = Int(intValues[field.key] ?? "") ?? fallback
                merged[field.key] = AnyCodable(parsed)
            case .double:
                let fallback = field.defaultValue as? Double ?? 0
                let parsed = Double(doubleValues[field.key] ?? "") ?? fallback
                merged[field.key] = AnyCodable(parsed)
            case .bool:
                merged[field.key] = AnyCodable(boolValues[field.key] ?? false)
            case .color:
                let fallback = field.defaultValue as? Color ?? .white
                let selected = colorValues[field.key] ?? fallback
                merged[field.key] = encodedColor(selected)
            }
        }

        return merged.isEmpty ? nil : merged
    }

    private func intValue(for key: String, fallback: Int) -> Int {
        guard let value = context.existingSettings?[key]?.value else { return fallback }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String, let parsed = Int(string) { return parsed }
        return fallback
    }

    private func doubleValue(for key: String, fallback: Double) -> Double {
        guard let value = context.existingSettings?[key]?.value else { return fallback }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String, let parsed = Double(string) { return parsed }
        return fallback
    }

    private func boolValue(for key: String, fallback: Bool) -> Bool {
        guard let value = context.existingSettings?[key]?.value else { return fallback }
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            return ["true", "1", "yes", "on"].contains(string.lowercased())
        }
        if let int = value as? Int { return int != 0 }
        return fallback
    }

    private func colorValue(for key: String, fallback: Color) -> Color {
        guard let value = context.existingSettings?[key]?.value else { return fallback }

        if let hex = value as? String, let color = Color(hex: hex) {
            return color
        }

        if let codableColor = codableColor(from: value) {
            return codableColor.color
        }

        return fallback
    }

    private func codableColor(from value: Any) -> CodableColor? {
        if let dict = value as? [String: Any] {
            return codableColor(from: dict)
        }
        if let dict = value as? [String: Double] {
            return codableColor(from: dict.mapValues { $0 as Any })
        }
        if let dict = value as? [String: Int] {
            return codableColor(from: dict.mapValues { Double($0) as Any })
        }
        return nil
    }

    private func codableColor(from dict: [String: Any]) -> CodableColor? {
        guard let red = numberValue(dict["red"]),
              let green = numberValue(dict["green"]),
              let blue = numberValue(dict["blue"]) else {
            return nil
        }
        let opacity = numberValue(dict["opacity"]) ?? 1.0
        return CodableColor(red: red, green: green, blue: blue, opacity: opacity)
    }

    private func numberValue(_ raw: Any?) -> Double? {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? String, let parsed = Double(value) { return parsed }
        return nil
    }

    private func encodedColor(_ color: Color) -> AnyCodable {
        let codable = CodableColor(color)
        return AnyCodable(
            [
                "red": codable.red,
                "green": codable.green,
                "blue": codable.blue,
                "opacity": codable.opacity,
            ]
        )
    }
}
