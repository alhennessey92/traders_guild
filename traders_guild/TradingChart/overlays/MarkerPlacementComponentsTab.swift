import SwiftUI

private enum MarkerComponentSubTab: String, CaseIterable, UnifiedTabItem {
    case active = "Active"
    case indicators = "Indicators"
    case drawings = "Drawings"
    case timeframes = "Timeframes"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .indicators: return "chart.line.uptrend.xyaxis.circle"
        case .drawings: return "pencil.circle"
        case .timeframes: return "clock.circle"
        }
    }
}

struct MarkerPlacementComponentsTab: View {
    @ObservedObject var placementState: MarkerPlacementState
    let activeChartIndicators: [IndicatorPayload]
    let activeChartDrawings: [ChartDrawing]
    let currentChartTimeframe: RLChartTimeframe?
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    let onBeginInteractiveDrawing: (() -> Void)?
    var showsMirrorButtons: Bool = true

    @State private var selectedSubTab: MarkerComponentSubTab = .active
    @State private var limitWarning: String?
    @State private var infoMessage: String?
    @State private var editingIndicatorContext: IndicatorEditingContext?

    private var orderedIndicatorDrafts: [MarkerComponentDraft] {
        placementState.indicatorDrafts.sorted { lhs, rhs in
            let lhsName = indicatorName(for: lhs).uppercased()
            let rhsName = indicatorName(for: rhs).uppercased()
            if lhsName != rhsName { return lhsName < rhsName }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var orderedDrawingDrafts: [MarkerComponentDraft] {
        placementState.components
            .filter { isActiveDrawingComponent($0.componentType) }
            .sorted { lhs, rhs in
                let lhsRank = drawingSortRank(for: lhs.componentType)
                let rhsRank = drawingSortRank(for: rhs.componentType)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private var orderedTimeframeDrafts: [MarkerComponentDraft] {
        placementState.timeframeLinkDrafts.sorted { lhs, rhs in
            let lhsRank = timeframeSortRank(for: timeframeBackendValue(for: lhs))
            let rhsRank = timeframeSortRank(for: timeframeBackendValue(for: rhs))
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var totalCount: Int {
        orderedIndicatorDrafts.count + orderedDrawingDrafts.count + orderedTimeframeDrafts.count
    }

    var body: some View {
        UnifiedComponentsScaffold(
            title: "Add Components",
            subtitle: "Build context with indicators, drawings, and timeframes",
            headerIcon: "plus.viewfinder",
            selectedTab: $selectedSubTab,
            tabTheme: .componentsTabs
        ) { tab in
            content(for: tab)
        }
        .sheet(item: $editingIndicatorContext) { context in
            IndicatorSettingsEditorSheet(
                context: context,
                onSave: { updatedSettings in
                    _ = placementState.upsertIndicator(
                        name: context.indicatorName,
                        settings: updatedSettings
                    )
                    infoMessage = "Updated \(context.item.title) settings."
                    limitWarning = nil
                }
            )
        }
    }

    @ViewBuilder
    private func content(for selectedSubTab: MarkerComponentSubTab) -> some View {
        switch selectedSubTab {
        case .active:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if showsMirrorButtons {
                        mirrorChartSetupButton
                    }

                    if let infoMessage {
                        statusMessage(infoMessage, color: AppColors.greyText)
                    }

                    if let limitWarning {
                        statusMessage(limitWarning, color: AppColors.statusWarning95)
                    }

                    overviewCard
                    activeIndicatorsSection
                    activeDrawingsSection
                    activeTimeframesSection
                }
            }
        case .indicators:
            MarkerPlacementIndicatorsTab(
                placementState: placementState,
                activeChartIndicators: activeChartIndicators,
                showsTitleHeader: false,
                showsMirrorButton: showsMirrorButtons
            )
        case .drawings:
            MarkerPlacementDrawingsTab(
                placementState: placementState,
                onBeginInteractiveDrawing: onBeginInteractiveDrawing,
                mirrorSourceIndicators: activeChartIndicators,
                mirrorSourceDrawings: activeChartDrawings,
                showsTitleHeader: false,
                showsMirrorButton: showsMirrorButtons
            )
        case .timeframes:
            MarkerPlacementTimeframesTab(
                placementState: placementState,
                currentChartTimeframe: currentChartTimeframe,
                onSelectTimeframe: onSelectTimeframe,
                mirrorSourceIndicators: activeChartIndicators,
                mirrorSourceDrawings: activeChartDrawings,
                showsTitleHeader: false,
                showsMirrorButton: showsMirrorButtons
            )
        }
    }

    private var mirrorChartSetupButton: some View {
        Button {
            mirrorChartSetup()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primaryForeground)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror Chart Setup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text("Copy current chart indicators and drawings to this marker")
                        .font(.caption2)
                        .foregroundColor(AppColors.greyText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.componentsMirrorButtonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.componentsMirrorButtonStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity((activeChartIndicators.isEmpty && activeChartDrawings.isEmpty) ? 0.55 : 1)
        .disabled(activeChartIndicators.isEmpty && activeChartDrawings.isEmpty)
    }

    private var overviewCard: some View {
        HStack(spacing: 8) {
            overviewBadge(title: "Total", value: "\(totalCount)")
            overviewBadge(title: "Indicators", value: "\(orderedIndicatorDrafts.count)")
            overviewBadge(title: "Drawings", value: "\(orderedDrawingDrafts.count)")
            overviewBadge(title: "Timeframes", value: "\(orderedTimeframeDrafts.count)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(sectionCardBackground())
    }

    private var activeIndicatorsSection: some View {
        sectionCard(title: "Active Indicators", icon: "waveform.path.ecg") {
            if orderedIndicatorDrafts.isEmpty {
                emptyStateRow("No indicators attached.")
            } else {
                ForEach(orderedIndicatorDrafts) { draft in
                    if case let .indicator(payload) = draft.payload {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.statusWarning90)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(indicatorTitle(for: payload))
                                    .font(.caption)
                                    .foregroundColor(AppColors.primaryForeground)
                                Text(indicatorSubtitle(for: payload))
                                    .font(.caption2)
                                    .foregroundColor(AppColors.greyText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            indicatorSettingsButton(for: payload)
                            removeDraftButton(draft.id)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(rowCardBackground())
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            openIndicatorEditor(for: payload)
                        }
                    }
                }
            }
        }
    }

    private var activeDrawingsSection: some View {
        sectionCard(title: "Active Drawings", icon: "pencil.and.ruler") {
            if orderedDrawingDrafts.isEmpty {
                emptyStateRow("No drawings attached.")
            } else {
                ForEach(orderedDrawingDrafts) { draft in
                    HStack(spacing: 10) {
                        Image(systemName: draft.componentType.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(draft.componentType.color.opacity(0.92))
                            .frame(width: 16)
                        Text(drawingTitle(for: draft))
                            .font(.caption)
                            .foregroundColor(AppColors.primaryForeground)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        removeDraftButton(draft.id)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(rowCardBackground())
                }
            }
        }
    }

    private var activeTimeframesSection: some View {
        sectionCard(title: "Linked Timeframes", icon: "clock.arrow.circlepath") {
            if orderedTimeframeDrafts.isEmpty {
                emptyStateRow("No linked timeframes.")
            } else {
                ForEach(orderedTimeframeDrafts) { draft in
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.statusInfo85)
                            .frame(width: 16)
                        Text(timeframeLabel(for: draft))
                            .font(.caption)
                            .foregroundColor(AppColors.primaryForeground)
                        Spacer(minLength: 0)
                        removeTimeframeDraftButton(draft)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(rowCardBackground())
                }
            }
        }
    }

    private func overviewBadge(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.primaryForeground)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.componentsOverviewChipFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.componentsOverviewChipStroke, lineWidth: 1)
                )
        )
    }

    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.componentsSectionHeaderIconForeground)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.greyText)
            }
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(sectionCardBackground())
    }

    private func emptyStateRow(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(AppColors.greyText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowCardBackground())
    }

    private func rowCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppColors.componentsRowCardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.componentsRowCardStroke, lineWidth: 1)
            )
    }

    private func sectionCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.componentsSectionCardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.componentsSectionCardStroke, lineWidth: 1)
            )
    }

    private func removeDraftButton(_ draftID: UUID) -> some View {
        Button {
            placementState.removeComponent(id: draftID)
            infoMessage = nil
            limitWarning = nil
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.statusNegative85)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func indicatorSettingsButton(for payload: IndicatorPayload) -> some View {
        if IndicatorCatalogItem.item(forIndicatorName: payload.name) != nil {
            Button {
                openIndicatorEditor(for: payload)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primaryForeground)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppColors.componentsOverviewChipFill))
            }
            .buttonStyle(.plain)
        }
    }

    private func removeTimeframeDraftButton(_ draft: MarkerComponentDraft) -> some View {
        Button {
            if let timeframe = timeframeBackendValue(for: draft) {
                placementState.removeTimeframeLink(timeframe)
            }
            infoMessage = nil
            limitWarning = nil
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.statusNegative85)
        }
        .buttonStyle(.plain)
    }

    private func mirrorChartSetup() {
        let indicatorResult = placementState.attachActiveChartIndicators(activeChartIndicators)
        let drawingResult = placementState.attachActiveChartDrawings(activeChartDrawings)
        let totalAdded = indicatorResult.added + drawingResult.added

        if totalAdded > 0 {
            var mirroredParts: [String] = []
            if indicatorResult.added > 0 {
                mirroredParts.append("\(indicatorResult.added) indicator\(indicatorResult.added == 1 ? "" : "s")")
            }
            if drawingResult.added > 0 {
                mirroredParts.append("\(drawingResult.added) drawing\(drawingResult.added == 1 ? "" : "s")")
            }
            infoMessage = "Mirrored \(mirroredParts.joined(separator: " and ")) from chart."
        } else {
            infoMessage = "No new chart indicators or drawings to mirror."
        }

        if indicatorResult.blockedByLimit || drawingResult.blockedByLimit {
            limitWarning = placementState.limitMessage(for: .indicatorPanels)
            if drawingResult.blockedByLimit {
                limitWarning = placementState.limitMessage(for: .drawingOverlays)
            }
            HapticFeedback.light.trigger()
        } else {
            limitWarning = nil
        }
    }

    private func openIndicatorEditor(for payload: IndicatorPayload) {
        guard let item = IndicatorCatalogItem.item(forIndicatorName: payload.name) else {
            infoMessage = "Settings editor unavailable for this indicator."
            return
        }
        editingIndicatorContext = IndicatorEditingContext(
            item: item,
            indicatorName: payload.name,
            existingSettings: payload.settings
        )
    }

    private func drawingSortRank(for componentType: RLComponentType) -> Int {
        switch componentType {
        case .drawingTrendline: return 0
        case .drawingHorizontalLine: return 1
        case .levelSupport: return 2
        case .levelResistance: return 3
        case .drawingZone: return 4
        case .textNote: return 5
        case .reactionEmoji: return 6
        default: return 7
        }
    }

    private func isActiveDrawingComponent(_ componentType: RLComponentType) -> Bool {
        switch componentType {
        case .drawingTrendline,
             .drawingHorizontalLine,
             .drawingZone,
             .levelSupport,
             .levelResistance,
             .textNote,
             .reactionEmoji:
            return true
        default:
            return false
        }
    }

    private func drawingTitle(for draft: MarkerComponentDraft) -> String {
        switch draft.payload {
        case let .note(payload):
            let note = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? "Text Note" : note
        case let .reactionEmoji(payload):
            return "Emoji \(payload.emoji)"
        default:
            return draft.componentType.displayName
        }
    }

    private func indicatorName(for draft: MarkerComponentDraft) -> String {
        guard case let .indicator(payload) = draft.payload else { return "" }
        return payload.name
    }

    private func indicatorTitle(for payload: IndicatorPayload) -> String {
        IndicatorCatalogItem.item(forIndicatorName: payload.name)?.title ?? payload.name
    }

    private func indicatorSubtitle(for payload: IndicatorPayload) -> String {
        let item = IndicatorCatalogItem.item(forIndicatorName: payload.name)
        let mode = (item?.isPanelIndicator ?? false) ? "Panel" : "Overlay"
        let summary = item?.description ?? "Custom indicator"
        return "\(mode) • \(summary)"
    }

    private func timeframeValue(for draft: MarkerComponentDraft) -> RLChartTimeframe? {
        guard case let .timeframeLink(payload) = draft.payload else { return nil }
        return RLChartTimeframe.fromBackendString(payload.timeframe)
    }

    private func timeframeLabel(for draft: MarkerComponentDraft) -> String {
        guard case let .timeframeLink(payload) = draft.payload else {
            return "Unknown timeframe"
        }
        guard let timeframe = RLChartTimeframe.fromBackendString(payload.timeframe) else {
            return payload.timeframe.uppercased()
        }
        return "\(timeframe.shortName) • \(timeframe.displayName)"
    }

    private func timeframeBackendValue(for draft: MarkerComponentDraft) -> String? {
        guard case let .timeframeLink(payload) = draft.payload else { return nil }
        return payload.timeframe
    }

    private func timeframeSortRank(for backendValue: String?) -> Int {
        guard let backendValue,
              let timeframe = RLChartTimeframe.fromBackendString(backendValue),
              let index = RLChartTimeframe.allCases.firstIndex(of: timeframe) else {
            return Int.max
        }
        return index
    }

    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
    }
}
