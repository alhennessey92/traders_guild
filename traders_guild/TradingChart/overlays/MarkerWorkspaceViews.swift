import SwiftUI
import UIKit

/// Embedded adapters share the placement session's navigation and editor models.
/// Chart tools use the existing drawing workflow; no routine action presents a sheet.
struct MarkerWorkspaceContent: View {
    @ObservedObject var placementState: MarkerPlacementState
    let currentChartTimeframe: RLChartTimeframe?
    let activeChartIndicators: [IndicatorPayload]
    let activeChartDrawings: [ChartDrawing]
    let onSelectTimeframe: ((RLChartTimeframe) -> Void)?
    let onBeginInteractiveDrawing: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = placementState.workspace.message {
                Text(message).font(.footnote).foregroundColor(AppColors.statusWarning)
            }
            switch placementState.workspaceDestination {
            case .context: contextSummary
            case .indicators: indicatorPicker
            case .indicatorSettings:
                if let draft = placementState.workspace.indicatorDraft {
                    IndicatorSettingsEditorContent(draft: draft)
                }
            case .drawings: drawingPicker
            case .drawingEditor: drawingEditor
            case .levelEditor:
                editorField("Price", text: placementState.workspaceLevelPriceInput, keyboard: .decimalPad)
                if placementState.workspace.selectedComponentID != nil {
                    routeRow("Work on chart", icon: "chart.xyaxis.line") {
                        if placementState.beginWorkspaceLevelChartEditing() {
                            dismissKeyboard()
                            onBeginInteractiveDrawing?()
                        }
                    }.disabled(!placementState.workspaceCanEditLevelOnChart)
                }
            case .sourceEditor:
                editorField("https://example.com/source", text: $placementState.workspace.editorText, keyboard: .URL)
                    .accessibilityIdentifier("workspace.sourceURL")
                editorField("Title (optional)", text: $placementState.workspace.editorTitle)
                Text("Use a complete http or https link.").font(.caption).foregroundColor(AppColors.greyText)
            case .noteEditor:
                MarkerWorkspaceTextInput(placeholder: "Chart note", text: $placementState.workspace.editorText, placementState: placementState, fieldID: "contextNote")
                    .accessibilityIdentifier("workspace.note")
            case .timeframes: timeframePicker
            case .relationship:
                ForEach(MarkerLinkRelationship.allCases, id: \.self) { relationship in
                    routeRow(relationship.displayName, icon: relationship.icon, detail: relationship.pickerSubtitle) {
                        placementState.changeLinkRelationship(relationship)
                        placementState.cancelWorkspaceEditor()
                    }
                }
            case .responseTimeframe:
                ForEach(RLChartTimeframe.allCases, id: \.rawValue) { timeframe in
                    routeRow(timeframe.displayName, icon: "clock", detail: timeframe == currentChartTimeframe ? "Current" : nil) {
                        onSelectTimeframe?(timeframe)
                        placementState.cancelWorkspaceEditor()
                    }.disabled(placementState.isChangingResponseTimeframe)
                }
            default: EmptyView()
            }
        }.scrollTargetLayout()
    }

    private var contextDrafts: [MarkerComponentDraft] {
        placementState.components.filter {
            ![RLComponentType.anchor, .levelEntry, .levelSl, .levelTp].contains($0.componentType)
        }
    }

    private var contextSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optional. Your context stays with this draft.").font(.footnote).foregroundColor(AppColors.greyText)
            ForEach(contextDrafts) { draft in
                HStack {
                    Button { edit(draft) } label: {
                        HStack {
                            Image(systemName: draft.componentType.icon)
                            Text(summary(draft)).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "pencil")
                        }.frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!placementState.workspaceAllows(draft.componentType))
                    .accessibilityIdentifier("workspace.edit.\(draft.id)")
                    Button { placementState.removeWorkspaceComponent(draft.id) } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }.buttonStyle(.plain)
                    .disabled(!placementState.workspaceAllows(draft.componentType))
                    .accessibilityLabel("Remove \(summary(draft))")
                }.foregroundColor(AppColors.primaryForeground).id(draft.id.uuidString)
            }
            if placementState.workspaceAllows(.indicator) {
                routeRow("Add indicator", icon: "waveform.path.ecg") { placementState.openWorkspace(.indicators) }
            }
            if placementState.workspaceAllows(.drawingTrendline) {
                routeRow("Add drawing", icon: "pencil.and.ruler") { placementState.openWorkspace(.drawings) }
            }
            if placementState.workspaceAllows(.levelSupport) {
                routeRow("Add support", icon: "arrow.down.to.line") { placementState.beginWorkspaceLevel(.levelSupport) }
                routeRow("Add resistance", icon: "arrow.up.to.line") { placementState.beginWorkspaceLevel(.levelResistance) }
            }
            if placementState.workspaceAllows(.timeframeLink) {
                routeRow("Add timeframe", icon: "clock") { placementState.openWorkspace(.timeframes) }
            }
            if placementState.workspaceAllows(.textNote) {
                routeRow("Add chart note", icon: "text.bubble") { placementState.beginWorkspaceText(.noteEditor) }
            }
            if placementState.workspaceCanAddSource {
                routeRow("Add source link", icon: "link") { placementState.beginWorkspaceText(.sourceEditor) }
            }
        }
    }

    private var indicatorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !activeChartIndicators.isEmpty {
                routeRow("Copy chart indicators", icon: "doc.on.doc") {
                    guard placementState.workspaceAllows(.indicator) else { return }
                    let result = placementState.attachActiveChartIndicators(activeChartIndicators)
                    placementState.workspace.message = result.blockedByLimit ? placementState.limitMessage(for: .indicatorPanels) : nil
                }
            }
            ForEach(IndicatorCatalogItem.all) { item in
                routeRow(item.title, icon: item.icon, detail: item.description) {
                    placementState.beginWorkspaceIndicator(item)
                }.id(item.id).accessibilityIdentifier("workspace.indicator.\(item.id)")
            }
        }
    }

    private var drawingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !activeChartDrawings.isEmpty {
                routeRow("Copy chart drawings", icon: "doc.on.doc") {
                    guard placementState.workspaceAllows(.drawingTrendline) else { return }
                    // Existing attach path enforces drawing count; filter semantic
                    // capabilities before it creates any component.
                    let supported = activeChartDrawings.filter { drawing in
                        let draft = ChartDrawingBridge.markerDraft(from: drawing, anchorTime: placementState.anchorDraft?.payload.anchorTime ?? Date(),
                                                                  anchorPrice: placementState.anchorDraft?.payload.levelPrice ?? 0)
                        return placementState.workspaceAllows(draft.componentType)
                    }
                    let result = placementState.attachActiveChartDrawings(supported)
                    placementState.workspace.message = result.blockedByLimit ? placementState.limitMessage(for: .drawingOverlays) : nil
                }
            }
            ForEach(MarkerDrawingToolKind.allCases.filter { tool in
                guard let type = tool.componentType else { return false }
                return tool.isPhaseOneEnabled && tool.group != .annotation && placementState.workspaceAllows(type)
            }, id: \.self) { tool in
                routeRow(tool.title, icon: tool.icon) {
                    if placementState.beginWorkspaceDrawing(tool) { onBeginInteractiveDrawing?() }
                }.id(tool.rawValue)
            }
        }
    }

    private var drawingEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust this drawing on the chart. Done keeps it; Cancel restores it.")
                .font(.footnote).foregroundColor(AppColors.greyText)
            routeRow("Work on chart", icon: "chart.xyaxis.line") { onBeginInteractiveDrawing?() }
            if let id = placementState.drawingSession.editingDraftId {
                if let draft = placementState.components.first(where: { $0.id == id }),
                   draft.componentType == .drawingHorizontalLine {
                    TextField("Price", value: placementState.workspaceHorizontalPriceBinding(for: id),
                              formatter: MarkerGuidedFormat.priceFormatter).keyboardType(.decimalPad)
                }
                Picker("Line style", selection: Binding(
                    get: { placementState.drawingLineStyle(for: id) },
                    set: { placementState.setDrawingLineStyle($0, for: id) }
                )) {
                    ForEach(MarkerDrawingLineStyle.allCases, id: \.self) { style in Text(style.rawValue.capitalized).tag(style) }
                }
                HStack {
                    ForEach(["#10B981", "#38BDF8", "#F59E0B", "#F43F5E", "#8B5CF6"], id: \.self) { hex in
                        Button { placementState.setDrawingColorHex(hex, for: id) } label: {
                            Circle().fill(Color(hex: hex) ?? .white).frame(width: 28, height: 28).frame(width: 44, height: 44)
                        }.accessibilityLabel("Drawing color \(hex)")
                    }
                }
            } else {
                Text("Finish placing the drawing on the chart before Done.").font(.caption)
            }
        }
    }

    private var timeframePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Up to two supporting timeframes.").font(.caption).foregroundColor(AppColors.greyText)
            ForEach(RLChartTimeframe.allCases, id: \.rawValue) { timeframe in
                let value = timeframe.toBackendString()
                let linked = placementState.isTimeframeLinked(value)
                routeRow(timeframe.displayName, icon: linked ? "checkmark.circle.fill" : "plus.circle", detail: linked ? "Linked · tap to remove" : nil) {
                    guard placementState.workspaceAllows(.timeframeLink) else { return }
                    if linked { placementState.removeTimeframeLink(value) }
                    else if !placementState.upsertTimeframeLink(value) {
                        placementState.workspace.message = placementState.limitMessage(for: .timeframeLinks)
                    }
                }.id(value)
            }
        }
    }

    private func edit(_ draft: MarkerComponentDraft) {
        switch draft.payload {
        case .indicator(let payload):
            if let item = IndicatorCatalogItem.item(forIndicatorName: payload.name) {
                placementState.beginWorkspaceIndicator(item, draftID: draft.id)
            }
        case .link: placementState.beginWorkspaceText(.sourceEditor, componentID: draft.id)
        case .note: placementState.beginWorkspaceText(.noteEditor, componentID: draft.id)
        case .timeframeLink: placementState.openWorkspace(.timeframes)
        case .levelSupport, .levelResistance: placementState.beginWorkspaceLevel(draft.componentType, componentID: draft.id)
        default:
            let tool: MarkerDrawingToolKind? = {
                if case .drawingPattern(let payload) = draft.payload { return MarkerDrawingToolKind.from(patternKey: payload.patternKey) }
                return MarkerDrawingToolKind.from(componentType: draft.componentType)
            }()
            if let tool, placementState.beginWorkspaceDrawing(tool, componentID: draft.id) { onBeginInteractiveDrawing?() }
        }
    }

    private func summary(_ draft: MarkerComponentDraft) -> String {
        switch draft.payload {
        case .indicator(let payload): return payload.name
        case .timeframeLink(let payload): return "\(payload.timeframe) timeframe"
        case .link(let payload): return payload.title ?? payload.url
        case .note(let payload): return payload.text
        default: return draft.componentType.displayName
        }
    }

    private func editorField(_ prompt: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        MarkerWorkspaceLineInput(placeholder: prompt, text: text, placementState: placementState,
                                 fieldID: "workspace.\(placementState.workspaceDestination.rawValue).\(prompt)", keyboard: keyboard)
    }

    private func routeRow(_ title: String, icon: String, detail: String? = nil, action: @escaping () -> Void) -> some View {
        MarkerGuidedOptionalRow(icon: icon, title: title, detail: detail, identifier: "workspace.\(title)", action: action)
            .frame(minHeight: 44)
    }
}
