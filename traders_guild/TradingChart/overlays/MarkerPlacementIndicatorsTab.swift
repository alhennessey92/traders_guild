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
    @State private var pendingAddItem: IndicatorCatalogItem?

    private let indicatorCatalog = IndicatorCatalogItem.all

    private var attachedIndicators: [AttachedIndicator] {
        placementState.indicatorDrafts.compactMap { draft in
            guard case let .indicator(payload) = draft.payload else { return nil }
            return AttachedIndicator(draftID: draft.id, payload: payload)
        }
        .sorted { $0.payload.name < $1.payload.name }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                tabTitleHeader

                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .compact,
                    theme: .blue,
                    spacing: 6
                )

                panelUsageHeader

                if let infoMessage {
                    statusMessage(infoMessage, color: AppColors.greyText)
                }

                if let limitWarning {
                    statusMessage(limitWarning, color: AppColors.statusWarning95)
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
                    pendingAddItem = nil
                }
            )
        }
        .sheet(item: $pendingAddItem) { item in
            IndicatorSettingsEditorSheet(
                context: IndicatorEditingContext(
                    item: item,
                    indicatorName: item.payloadName,
                    existingSettings: item.defaultSettings
                ),
                onSave: { updatedSettings in
                    if placementState.upsertIndicator(
                        name: item.payloadName,
                        settings: updatedSettings
                    ) {
                        infoMessage = "Added \(item.title)."
                        limitWarning = nil
                    } else {
                        limitWarning = placementState.limitMessage(for: .indicatorPanels)
                        HapticFeedback.light.trigger()
                    }
                }
            )
        }
    }

    private var tabTitleHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppColors.statusInfo22)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.statusInfo95)
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

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                        .lineLimit(2)

                    indicatorModeBadge(isPanel: isPanel)
                }
            }

            Spacer(minLength: 0)

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
                    .foregroundColor(AppColors.statusNegative85)
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
                            placementState.intent.color.opacity(0.45),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            if let item {
                openSettingsEditor(item: item, payload: attached.payload)
            }
        }
    }

    private func catalogIndicatorRow(_ item: IndicatorCatalogItem) -> some View {
        let attached = attachedIndicator(for: item)
        let isAttached = attached != nil
        let canAttach = placementState.canAttachIndicator(named: item.payloadName) || isAttached

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.surfaceWhite88)
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
                    .foregroundColor(isAttached ? AppColors.statusNegative85 : AppColors.statusPositive90)
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
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            if let attached {
                openSettingsEditor(item: item, payload: attached.payload)
                return
            }
            if canAttach {
                toggleIndicator(item)
            }
        }
    }

    private func indicatorModeBadge(isPanel: Bool) -> some View {
        Text(isPanel ? "PANEL" : "OVERLAY")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(isPanel ? AppColors.statusWarning90 : AppColors.statusInfo90)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isPanel ? AppColors.statusWarning16 : AppColors.statusInfo16)
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

        guard placementState.canAttachIndicator(named: item.payloadName) else {
            limitWarning = placementState.limitMessage(for: .indicatorPanels)
            HapticFeedback.light.trigger()
            return
        }
        pendingAddItem = item
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

private struct IndicatorSettingsEditorSheet: View {
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

enum MarkerPlacementIndicatorFactory {
    static func activePayloads(from active: ActiveIndicators) -> [IndicatorPayload] {
        var payloads: [IndicatorPayload] = []

        for ma in active.enabledMovingAverages {
            payloads.append(payload(name: ma.type.rawValue, settings: movingAverageSettings(ma)))
        }

        if let vwap = active.vwap, vwap.isEnabled {
            payloads.append(payload(name: "VWAP", settings: vwapSettings(vwap)))
        }

        if let bollinger = active.bollingerBands, bollinger.isEnabled {
            payloads.append(payload(name: "Bollinger Bands", settings: bollingerSettings(bollinger)))
        }

        if let donchian = active.donchianChannels, donchian.isEnabled {
            payloads.append(payload(name: "Donchian Channels", settings: donchianSettings(donchian)))
        }

        if let keltner = active.keltnerChannels, keltner.isEnabled {
            payloads.append(payload(name: "Keltner Channels", settings: keltnerSettings(keltner)))
        }

        if let sar = active.parabolicSAR, sar.isEnabled {
            payloads.append(payload(name: "Parabolic SAR", settings: sarSettings(sar)))
        }

        if let rsi = active.rsi, rsi.isEnabled {
            payloads.append(payload(name: "RSI", settings: rsiSettings(rsi)))
        }

        if let macd = active.macd, macd.isEnabled {
            payloads.append(payload(name: "MACD", settings: macdSettings(macd)))
        }

        if let stochastic = active.stochastic, stochastic.isEnabled {
            payloads.append(payload(name: "Stochastic", settings: stochasticSettings(stochastic)))
        }

        if let cci = active.cci, cci.isEnabled {
            payloads.append(payload(name: "CCI", settings: cciSettings(cci)))
        }

        if let williamsR = active.williamsR, williamsR.isEnabled {
            payloads.append(payload(name: "Williams %R", settings: williamsRSettings(williamsR)))
        }

        if let atr = active.atr, atr.isEnabled {
            payloads.append(payload(name: "ATR", settings: atrSettings(atr)))
        }

        if let volume = active.volume, volume.isEnabled {
            payloads.append(payload(name: "Volume", settings: volumeSettings(volume)))
        }

        return deduplicated(payloads)
    }

    private static func payload(name: String, settings: [String: AnyCodable]?) -> IndicatorPayload {
        IndicatorPayload(name: name, settings: settings, isPrimary: nil)
    }

    private static func movingAverageSettings(_ config: MovingAverageConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "source": AnyCodable(config.priceSource.rawValue),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
        ]
    }

    private static func vwapSettings(_ config: VWAPConfig) -> [String: AnyCodable] {
        [
            "showStandardDeviationBands": AnyCodable(config.showStandardDeviationBands),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "upperBandColor": colorValue(config.upperBandColor),
            "lowerBandColor": colorValue(config.lowerBandColor),
        ]
    }

    private static func bollingerSettings(_ config: BollingerBandsConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "standardDeviations": AnyCodable(config.standardDeviations),
            "showFill": AnyCodable(config.showFill),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "upperBandColor": colorValue(config.upperBandColor),
            "lowerBandColor": colorValue(config.lowerBandColor),
            "fillColor": colorValue(config.fillColor),
        ]
    }

    private static func donchianSettings(_ config: DonchianChannelsConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "showFill": AnyCodable(config.showFill),
            "showMiddleLine": AnyCodable(config.showMiddleLine),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "upperBandColor": colorValue(config.upperBandColor),
            "lowerBandColor": colorValue(config.lowerBandColor),
            "fillColor": colorValue(config.fillColor),
        ]
    }

    private static func keltnerSettings(_ config: KeltnerChannelsConfig) -> [String: AnyCodable] {
        [
            "emaPeriod": AnyCodable(config.emaPeriod),
            "atrPeriod": AnyCodable(config.atrPeriod),
            "atrMultiplier": AnyCodable(config.atrMultiplier),
            "showFill": AnyCodable(config.showFill),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "upperBandColor": colorValue(config.upperBandColor),
            "lowerBandColor": colorValue(config.lowerBandColor),
            "fillColor": colorValue(config.fillColor),
        ]
    }

    private static func sarSettings(_ config: ParabolicSARConfig) -> [String: AnyCodable] {
        [
            "accelerationStart": AnyCodable(config.accelerationStart),
            "accelerationIncrement": AnyCodable(config.accelerationIncrement),
            "accelerationMax": AnyCodable(config.accelerationMax),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "bullishColor": colorValue(config.bullishColor),
            "bearishColor": colorValue(config.bearishColor),
        ]
    }

    private static func rsiSettings(_ config: RSIConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "overboughtLevel": AnyCodable(config.overboughtLevel),
            "oversoldLevel": AnyCodable(config.oversoldLevel),
            "showLevels": AnyCodable(config.showLevels),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "overboughtColor": colorValue(config.overboughtColor),
            "oversoldColor": colorValue(config.oversoldColor),
        ]
    }

    private static func macdSettings(_ config: MACDConfig) -> [String: AnyCodable] {
        [
            "fastPeriod": AnyCodable(config.fastPeriod),
            "slowPeriod": AnyCodable(config.slowPeriod),
            "signalPeriod": AnyCodable(config.signalPeriod),
            "showHistogram": AnyCodable(config.showHistogram),
            "showSignalLine": AnyCodable(config.showSignalLine),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "signalColor": colorValue(config.signalColor),
            "histogramPositiveColor": colorValue(config.histogramPositiveColor),
            "histogramNegativeColor": colorValue(config.histogramNegativeColor),
        ]
    }

    private static func stochasticSettings(_ config: StochasticConfig) -> [String: AnyCodable] {
        [
            "kPeriod": AnyCodable(config.kPeriod),
            "dPeriod": AnyCodable(config.dPeriod),
            "smoothK": AnyCodable(config.smoothK),
            "overboughtLevel": AnyCodable(config.overboughtLevel),
            "oversoldLevel": AnyCodable(config.oversoldLevel),
            "showLevels": AnyCodable(config.showLevels),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "dColor": colorValue(config.dColor),
            "overboughtColor": colorValue(config.overboughtColor),
            "oversoldColor": colorValue(config.oversoldColor),
        ]
    }

    private static func cciSettings(_ config: CCIConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "overboughtLevel": AnyCodable(config.overboughtLevel),
            "oversoldLevel": AnyCodable(config.oversoldLevel),
            "showLevels": AnyCodable(config.showLevels),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "overboughtColor": colorValue(config.overboughtColor),
            "oversoldColor": colorValue(config.oversoldColor),
        ]
    }

    private static func williamsRSettings(_ config: WilliamsRConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "overboughtLevel": AnyCodable(config.overboughtLevel),
            "oversoldLevel": AnyCodable(config.oversoldLevel),
            "showLevels": AnyCodable(config.showLevels),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "overboughtColor": colorValue(config.overboughtColor),
            "oversoldColor": colorValue(config.oversoldColor),
        ]
    }

    private static func atrSettings(_ config: ATRConfig) -> [String: AnyCodable] {
        [
            "period": AnyCodable(config.period),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
        ]
    }

    private static func volumeSettings(_ config: VolumeConfig) -> [String: AnyCodable] {
        [
            "showMA": AnyCodable(config.showMA),
            "maPeriod": AnyCodable(config.maPeriod),
            "lineWidth": AnyCodable(Double(config.lineWidth)),
            "color": colorValue(config.color),
            "bullishColor": colorValue(config.bullishColor),
            "bearishColor": colorValue(config.bearishColor),
            "maColor": colorValue(config.maColor),
        ]
    }

    private static func colorValue(_ color: CodableColor) -> AnyCodable {
        AnyCodable(
            [
                "red": color.red,
                "green": color.green,
                "blue": color.blue,
                "opacity": color.opacity,
            ]
        )
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
