import SwiftUI

struct MarkerPlacementIndicatorsTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]
    var showsTitleHeader: Bool = true
    var showsMirrorButton: Bool = false

    @State private var selectedSubTab: IndicatorSubTab = .trend
    @State private var limitWarning: String?
    @State private var infoMessage: String?
    @State private var editingContext: IndicatorEditingContext?

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
                if showsTitleHeader {
                    tabTitleHeader
                }

                UnifiedTabBar(
                    selectedTab: $selectedSubTab,
                    size: .compact,
                    theme: .deepSubTab,
                    spacing: 6
                )

                if showsMirrorButton {
                    attachCurrentChartSetButton
                }

                panelUsageHeader

                if let infoMessage {
                    statusMessage(infoMessage, color: AppColors.greyText)
                }

                if let limitWarning {
                    statusMessage(limitWarning, color: AppColors.statusWarning95)
                }

                categoryTabSection(category: selectedSubTab.category)
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
                    .foregroundColor(AppColors.primaryForeground)
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
                .foregroundColor(
                    placementState.indicatorPanelCount >= 2
                        ? AppColors.chartOrangeGradientStart
                        : AppColors.statusPositive
                )
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
                    emptyAttachedIndicatorsState
                } else {
                    ForEach(attachedIndicators) { attached in
                        attachedIndicatorRow(attached)
                    }
                }
            }
        }
    }

    private var emptyAttachedIndicatorsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 24))
                .foregroundColor(AppColors.whiteText.opacity(0.42))

            Text("No indicator components attached.")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Button("Browse indicator categories") {
                selectedSubTab = .trend
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(AppColors.onAccentForeground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(placementState.intent.color.opacity(0.4))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.whiteText.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                )
        )
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
            Text("Mirror Chart Setup")
                .font(.caption)
                .foregroundColor(AppColors.greyText)

            Button {
                attachActiveIndicators()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Copy Current Chart Indicators")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                }
                .foregroundColor(
                    activeChartIndicators.isEmpty
                        ? AppColors.primaryForeground
                        : AppColors.onAccentForeground
                )
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
                    .foregroundColor(AppColors.primaryForeground)

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
                        .foregroundColor(AppColors.primaryForeground)
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
                withAnimation(.none) {
                    toggleIndicator(item)
                }
            } label: {
                Image(systemName: isAttached ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isAttached ? AppColors.statusNegative85 : placementState.intent.color)
                    .frame(width: 28, height: 28)
                    .contentTransition(.identity)
            }
            .buttonStyle(.plain)
            .opacity((!isAttached && !canAttach) ? 0.45 : 1)
            .disabled(!isAttached && !canAttach)
            .transaction { $0.animation = nil }
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
            if !isAttached && canAttach {
                withAnimation(.none) {
                    toggleIndicator(item)
                }
            }
        }
        .transaction { $0.animation = nil }
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
            infoMessage = "Mirrored \(result.added) indicator\(result.added == 1 ? "" : "s") from chart."
        } else {
            infoMessage = "No new chart indicators to mirror."
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

        if placementState.upsertIndicator(name: item.payloadName, settings: item.defaultSettings) {
            infoMessage = "Added \(item.title)."
            limitWarning = nil
            // Auto-open settings editor for newly added indicator
            if let attached = attachedIndicator(for: item) {
                openSettingsEditor(item: item, payload: attached.payload)
            }
        } else {
            limitWarning = placementState.limitMessage(for: .indicatorPanels)
            HapticFeedback.light.trigger()
        }
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
            IndicatorCatalogItem.type(forIndicatorName: attached.payload.name) == item.type
        }
    }

    private func indicatorItem(for indicatorName: String) -> IndicatorCatalogItem? {
        IndicatorCatalogItem.item(forIndicatorName: indicatorName)
    }

    private func isPanelIndicatorName(_ name: String) -> Bool {
        guard let item = IndicatorCatalogItem.item(forIndicatorName: name) else { return false }
        return item.isPanelIndicator
    }
}

private struct AttachedIndicator: Identifiable {
    let draftID: UUID
    let payload: IndicatorPayload

    var id: String { "\(draftID.uuidString)|\(payload.name)" }
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
