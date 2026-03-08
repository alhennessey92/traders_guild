import SwiftUI

private enum MarkerIndicatorSubTab: String, CaseIterable, UnifiedTabItem {
    case active = "Active"
    case trend = "Trend"
    case volatility = "Volatility"
    case momentum = "Momentum"
    case volume = "Volume"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .trend: return IndicatorCategory.trend.icon
        case .volatility: return IndicatorCategory.volatility.icon
        case .momentum: return IndicatorCategory.momentum.icon
        case .volume: return IndicatorCategory.volume.icon
        }
    }

    var category: IndicatorCategory? {
        switch self {
        case .active: return nil
        case .trend: return .trend
        case .volatility: return .volatility
        case .momentum: return .momentum
        case .volume: return .volume
        }
    }
}

struct MarkerPlacementIndicatorsTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]

    @State private var selectedSubTab: MarkerIndicatorSubTab = .active
    @State private var limitWarning: String?
    @State private var infoMessage: String?
    @State private var editingContext: IndicatorEditingContext?

    private let indicatorCatalog = IndicatorCatalogItem.all

    private var attachedIndicators: [AttachedIndicator] {
        placementState.indicatorDrafts.compactMap { draft in
            guard case let .indicator(payload) = draft.payload else { return nil }
            return AttachedIndicator(draftID: draft.id, payload: payload)
        }
        .sorted { lhs, rhs in
            let lhsPrimary = lhs.payload.isPrimary ?? false
            let rhsPrimary = rhs.payload.isPrimary ?? false
            if lhsPrimary != rhsPrimary { return lhsPrimary && !rhsPrimary }
            return lhs.payload.name < rhs.payload.name
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                tabTitleHeader

                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .standard,
                    theme: .blue,
                    spacing: 6
                )

                panelUsageHeader

                if let infoMessage {
                    statusMessage(infoMessage, color: AppColors.greyText)
                }

                if let limitWarning {
                    statusMessage(limitWarning, color: .orange.opacity(0.95))
                }

                switch selectedSubTab {
                case .active:
                    activeTabSection
                case .trend, .volatility, .momentum, .volume:
                    if let category = selectedSubTab.category {
                        categoryTabSection(category: category)
                    }
                }
            }
            .padding(.trailing, 2)
        }
        .sheet(item: $editingContext) { context in
            IndicatorSettingsEditorSheet(
                context: context,
                onSave: { updatedSettings in
                    _ = placementState.upsertIndicator(
                        name: context.indicatorName,
                        settings: updatedSettings
                    )
                    infoMessage = "Updated \(context.item.title) settings."
                }
            )
        }
    }

    private var tabTitleHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.opacity(0.22))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue.opacity(0.95))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Indicators")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Attach and configure marker indicator context")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }

            Spacer(minLength: 0)
        }
    }

    private var panelUsageHeader: some View {
        HStack(spacing: 8) {
            Text("Panel Indicators")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Spacer(minLength: 0)

            Text("\(placementState.indicatorPanelCount)/2")
                .font(.caption.weight(.semibold))
                .foregroundColor(placementState.indicatorPanelCount >= 2 ? .orange : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(AppColors.whiteText.opacity(0.09)))
        }
    }

    private var activeTabSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            attachCurrentChartSetButton

            VStack(alignment: .leading, spacing: 8) {
                Text("Attached Indicators")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)

                if attachedIndicators.isEmpty {
                    Text("No indicator components attached.")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                } else {
                    ForEach(attachedIndicators) { attached in
                        attachedIndicatorRow(attached)
                    }
                }
            }
        }
    }

    private func categoryTabSection(category: IndicatorCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(category.rawValue) Catalog")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            ForEach(indicatorCatalog.filter { $0.category == category }) { item in
                catalogIndicatorRow(item)
            }
        }
    }

    private var attachCurrentChartSetButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Attach Active Chart Indicators")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Button {
                attachActiveIndicators()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Attach Current Chart Set")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            activeChartIndicators.isEmpty
                                ? AppColors.whiteText.opacity(0.08)
                                : placementState.intent.color.opacity(0.36)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            activeChartIndicators.isEmpty
                                ? AppColors.whiteText.opacity(0.08)
                                : placementState.intent.color.opacity(0.55),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(activeChartIndicators.isEmpty ? 0.55 : 1)
            .disabled(activeChartIndicators.isEmpty)
        }
    }

    private func attachedIndicatorRow(_ attached: AttachedIndicator) -> some View {
        let item = indicatorItem(for: attached.payload.name)
        let title = item?.title ?? attached.payload.name
        let subtitle = item?.description ?? "Custom indicator"
        let isPanel = item?.isPanelIndicator ?? isPanelIndicatorName(attached.payload.name)
        let isPrimary = attached.payload.isPrimary ?? false

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)

                    indicatorModeBadge(isPanel: isPanel)

                    if isPrimary {
                        Text("PRIMARY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#FBBF24") ?? .yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill((Color(hex: "#FBBF24") ?? .yellow).opacity(0.16)))
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                placementState.setPrimaryIndicator(named: attached.payload.name)
            } label: {
                Image(systemName: isPrimary ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isPrimary ? Color(hex: "#FBBF24") ?? .yellow : AppColors.greyText)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppColors.whiteText.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Button {
                openSettingsEditor(item: item, payload: attached.payload)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(item == nil ? 0.35 : 0.9))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppColors.whiteText.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(item == nil)

            Button {
                placementState.removeIndicator(named: attached.payload.name)
                limitWarning = nil
                infoMessage = nil
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isPrimary
                                ? placementState.intent.color.opacity(0.45)
                                : AppColors.whiteText.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    private func catalogIndicatorRow(_ item: IndicatorCatalogItem) -> some View {
        let attached = attachedIndicator(for: item)
        let isAttached = attached != nil
        let isPrimary = attached?.payload.isPrimary ?? false
        let canAttach = placementState.canAttachIndicator(named: item.payloadName) || isAttached

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }

                HStack(spacing: 6) {
                    Text(item.description)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(1)
                    indicatorModeBadge(isPanel: item.isPanelIndicator)
                }
            }

            Spacer(minLength: 0)

            Button {
                if let attached {
                    placementState.setPrimaryIndicator(named: attached.payload.name)
                }
            } label: {
                Image(systemName: isPrimary ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isPrimary ? Color(hex: "#FBBF24") ?? .yellow : AppColors.greyText)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppColors.whiteText.opacity(isAttached ? 0.12 : 0.06)))
            }
            .buttonStyle(.plain)
            .opacity(isAttached ? 1 : 0.45)
            .disabled(!isAttached)

            Button {
                if let attached {
                    openSettingsEditor(item: item, payload: attached.payload)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(isAttached ? 0.9 : 0.35))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppColors.whiteText.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(!isAttached)

            Button {
                toggleIndicator(item)
            } label: {
                Image(systemName: isAttached ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isAttached ? .red.opacity(0.85) : .green.opacity(0.9))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .opacity((!isAttached && !canAttach) ? 0.45 : 1)
            .disabled(!isAttached && !canAttach)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isAttached
                                ? placementState.intent.color.opacity(0.45)
                                : AppColors.whiteText.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }

    private func indicatorModeBadge(isPanel: Bool) -> some View {
        Text(isPanel ? "PANEL" : "OVERLAY")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(isPanel ? .orange.opacity(0.9) : .blue.opacity(0.9))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isPanel ? .orange.opacity(0.16) : .blue.opacity(0.16))
            )
    }

    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
    }

    private func attachActiveIndicators() {
        let result = placementState.attachActiveChartIndicators(activeChartIndicators)

        if result.added > 0 {
            infoMessage = "Attached \(result.added) indicator\(result.added == 1 ? "" : "s")."
        } else {
            infoMessage = "No new chart indicators to attach."
        }

        if result.blockedByLimit {
            limitWarning = placementState.limitMessage(for: .indicatorPanels)
            HapticFeedback.light.trigger()
        } else {
            limitWarning = nil
        }
    }

    private func toggleIndicator(_ item: IndicatorCatalogItem) {
        infoMessage = nil

        if let attached = attachedIndicator(for: item) {
            placementState.removeIndicator(named: attached.payload.name)
            limitWarning = nil
            return
        }

        if placementState.upsertIndicator(name: item.payloadName, settings: item.defaultSettings) {
            limitWarning = nil
            return
        }

        limitWarning = placementState.limitMessage(for: .indicatorPanels)
        HapticFeedback.light.trigger()
    }

    private func openSettingsEditor(item: IndicatorCatalogItem?, payload: IndicatorPayload) {
        guard let item else {
            infoMessage = "Settings editor unavailable for this indicator."
            return
        }
        editingContext = IndicatorEditingContext(
            item: item,
            indicatorName: payload.name,
            existingSettings: payload.settings
        )
    }

    private func attachedIndicator(for item: IndicatorCatalogItem) -> AttachedIndicator? {
        attachedIndicators.first { attached in
            inferredIndicatorType(from: attached.payload.name) == item.type
        }
    }

    private func indicatorItem(for indicatorName: String) -> IndicatorCatalogItem? {
        guard let type = inferredIndicatorType(from: indicatorName) else { return nil }
        return indicatorCatalog.first { $0.type == type }
    }

    private func inferredIndicatorType(from name: String) -> IndicatorType? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if normalized.contains("BOLL") { return .bollingerBands }
        if normalized.contains("DONCHIAN") { return .donchianChannels }
        if normalized.contains("KELTNER") { return .keltnerChannels }
        if normalized.contains("PARABOLIC") || normalized.contains(" SAR") || normalized == "SAR" { return .parabolicSAR }
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

    private func isPanelIndicatorName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.contains("RSI")
            || normalized.contains("MACD")
            || normalized.contains("STOCH")
            || normalized.contains("CCI")
            || normalized.contains("WILLIAMS")
            || normalized.contains("ATR")
            || normalized.contains("VOLUME")
    }
}

private struct AttachedIndicator: Identifiable {
    let draftID: UUID
    let payload: IndicatorPayload

    var id: String { "\(draftID.uuidString)|\(payload.name)" }
}

private struct IndicatorCatalogItem: Identifiable, Hashable {
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
            ]
        case .vwap:
            return ["showStandardDeviationBands": AnyCodable(false)]
        case .bollingerBands:
            return [
                "period": AnyCodable(20),
                "standardDeviations": AnyCodable(2.0),
            ]
        case .donchianChannels:
            return ["period": AnyCodable(20)]
        case .keltnerChannels:
            return [
                "emaPeriod": AnyCodable(20),
                "atrPeriod": AnyCodable(14),
                "atrMultiplier": AnyCodable(2.0),
            ]
        case .parabolicSAR:
            return [
                "accelerationStart": AnyCodable(0.02),
                "accelerationIncrement": AnyCodable(0.02),
                "accelerationMax": AnyCodable(0.2),
            ]
        case .rsi:
            return ["period": AnyCodable(14)]
        case .macd:
            return [
                "fastPeriod": AnyCodable(12),
                "slowPeriod": AnyCodable(26),
                "signalPeriod": AnyCodable(9),
            ]
        case .stochastic:
            return [
                "kPeriod": AnyCodable(14),
                "dPeriod": AnyCodable(3),
                "smoothK": AnyCodable(3),
            ]
        case .cci:
            return ["period": AnyCodable(20)]
        case .williamsR:
            return ["period": AnyCodable(14)]
        case .atr:
            return ["period": AnyCodable(14)]
        case .volume:
            return [
                "showMA": AnyCodable(false),
                "maPeriod": AnyCodable(20),
            ]
        }
    }

    static let all: [IndicatorCatalogItem] = IndicatorType.allCases.map { IndicatorCatalogItem(type: $0) }
}

private struct IndicatorEditingContext: Identifiable {
    let id: UUID = UUID()
    let item: IndicatorCatalogItem
    let indicatorName: String
    let existingSettings: [String: AnyCodable]?
}

private struct IndicatorSettingField: Identifiable {
    enum ValueType {
        case int
        case double
        case bool
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
            ]
        case .vwap:
            return [
                .init(key: "showStandardDeviationBands", label: "Show Std Dev Bands", valueType: .bool, defaultValue: false),
            ]
        case .bollingerBands:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
                .init(key: "standardDeviations", label: "Std Deviations", valueType: .double, defaultValue: 2.0),
            ]
        case .donchianChannels:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
            ]
        case .keltnerChannels:
            return [
                .init(key: "emaPeriod", label: "EMA Period", valueType: .int, defaultValue: 20),
                .init(key: "atrPeriod", label: "ATR Period", valueType: .int, defaultValue: 14),
                .init(key: "atrMultiplier", label: "ATR Multiplier", valueType: .double, defaultValue: 2.0),
            ]
        case .parabolicSAR:
            return [
                .init(key: "accelerationStart", label: "Acceleration Start", valueType: .double, defaultValue: 0.02),
                .init(key: "accelerationIncrement", label: "Acceleration Increment", valueType: .double, defaultValue: 0.02),
                .init(key: "accelerationMax", label: "Acceleration Max", valueType: .double, defaultValue: 0.2),
            ]
        case .rsi:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 14),
            ]
        case .macd:
            return [
                .init(key: "fastPeriod", label: "Fast Period", valueType: .int, defaultValue: 12),
                .init(key: "slowPeriod", label: "Slow Period", valueType: .int, defaultValue: 26),
                .init(key: "signalPeriod", label: "Signal Period", valueType: .int, defaultValue: 9),
            ]
        case .stochastic:
            return [
                .init(key: "kPeriod", label: "K Period", valueType: .int, defaultValue: 14),
                .init(key: "dPeriod", label: "D Period", valueType: .int, defaultValue: 3),
                .init(key: "smoothK", label: "Smooth K", valueType: .int, defaultValue: 3),
            ]
        case .cci:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 20),
            ]
        case .williamsR:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 14),
            ]
        case .atr:
            return [
                .init(key: "period", label: "Period", valueType: .int, defaultValue: 14),
            ]
        case .volume:
            return [
                .init(key: "showMA", label: "Show MA", valueType: .bool, defaultValue: false),
                .init(key: "maPeriod", label: "MA Period", valueType: .int, defaultValue: 20),
            ]
        }
    }
}

private struct IndicatorSettingsEditorSheet: View {
    let context: IndicatorEditingContext
    let onSave: ([String: AnyCodable]?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var intValues: [String: String] = [:]
    @State private var doubleValues: [String: String] = [:]
    @State private var boolValues: [String: Bool] = [:]

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
            .background(Color.black.opacity(0.96))
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
                    .foregroundColor(.white)
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
                .foregroundColor(.white)
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
}

enum MarkerPlacementIndicatorFactory {
    static func activePayloads(from active: ActiveIndicators) -> [IndicatorPayload] {
        var payloads: [IndicatorPayload] = []

        for ma in active.enabledMovingAverages {
            let settings: [String: AnyCodable] = [
                "period": AnyCodable(ma.period),
                "source": AnyCodable(ma.priceSource.rawValue),
            ]
            payloads.append(
                IndicatorPayload(
                    name: ma.type.rawValue,
                    settings: settings,
                    isPrimary: nil
                )
            )
        }

        if let vwap = active.vwap, vwap.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "VWAP",
                    settings: [
                        "showStandardDeviationBands": AnyCodable(vwap.showStandardDeviationBands),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let bollinger = active.bollingerBands, bollinger.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Bollinger Bands",
                    settings: [
                        "period": AnyCodable(bollinger.period),
                        "standardDeviations": AnyCodable(bollinger.standardDeviations),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let donchian = active.donchianChannels, donchian.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Donchian Channels",
                    settings: [
                        "period": AnyCodable(donchian.period),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let keltner = active.keltnerChannels, keltner.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Keltner Channels",
                    settings: [
                        "emaPeriod": AnyCodable(keltner.emaPeriod),
                        "atrPeriod": AnyCodable(keltner.atrPeriod),
                        "atrMultiplier": AnyCodable(keltner.atrMultiplier),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let sar = active.parabolicSAR, sar.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Parabolic SAR",
                    settings: [
                        "accelerationStart": AnyCodable(sar.accelerationStart),
                        "accelerationIncrement": AnyCodable(sar.accelerationIncrement),
                        "accelerationMax": AnyCodable(sar.accelerationMax),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let rsi = active.rsi, rsi.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "RSI",
                    settings: ["period": AnyCodable(rsi.period)],
                    isPrimary: nil
                )
            )
        }

        if let stochastic = active.stochastic, stochastic.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Stochastic",
                    settings: [
                        "kPeriod": AnyCodable(stochastic.kPeriod),
                        "dPeriod": AnyCodable(stochastic.dPeriod),
                        "smoothK": AnyCodable(stochastic.smoothK),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let cci = active.cci, cci.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "CCI",
                    settings: [
                        "period": AnyCodable(cci.period),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let williamsR = active.williamsR, williamsR.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Williams %R",
                    settings: [
                        "period": AnyCodable(williamsR.period),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let atr = active.atr, atr.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "ATR",
                    settings: [
                        "period": AnyCodable(atr.period),
                    ],
                    isPrimary: nil
                )
            )
        }

        if let volume = active.volume, volume.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "Volume",
                    settings: nil,
                    isPrimary: nil
                )
            )
        }

        if let macd = active.macd, macd.isEnabled {
            payloads.append(
                IndicatorPayload(
                    name: "MACD",
                    settings: [
                        "fastPeriod": AnyCodable(macd.fastPeriod),
                        "slowPeriod": AnyCodable(macd.slowPeriod),
                        "signalPeriod": AnyCodable(macd.signalPeriod),
                    ],
                    isPrimary: nil
                )
            )
        }

        return deduplicated(payloads)
    }

    private static func deduplicated(_ payloads: [IndicatorPayload]) -> [IndicatorPayload] {
        var seen = Set<String>()
        var unique: [IndicatorPayload] = []

        for payload in payloads {
            let key = payload.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            unique.append(payload)
        }

        return unique
    }
}
