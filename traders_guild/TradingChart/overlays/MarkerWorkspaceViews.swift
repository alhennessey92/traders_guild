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
    /// The screen this view was created for. A screen being left keeps
    /// rendering itself while it fades out, never the one replacing it.
    var destination: MarkerWorkspaceDestination? = nil

    private var current: MarkerWorkspaceDestination { destination ?? placementState.workspaceDestination }

    /// Workspace state publishes through its session, not the draft.
    var body: some View {
        MarkerWorkspaceObserving(session: placementState.workspaceSession) { observedBody }
    }

    @ViewBuilder private var observedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = placementState.workspace.message {
                Text(message).font(.footnote).foregroundColor(AppColors.statusWarning)
            }
            switch current {
            // Add context is one tabbed screen; the old picker routes land there too.
            case .context, .indicators, .drawings, .timeframes:
                MarkerWorkspaceContextScreen(placementState: placementState, currentChartTimeframe: currentChartTimeframe,
                                             activeChartIndicators: activeChartIndicators, activeChartDrawings: activeChartDrawings,
                                             onBeginInteractiveDrawing: onBeginInteractiveDrawing)
            case .indicatorSettings:
                if let draft = placementState.workspace.indicatorDraft {
                    IndicatorSettingsEditorContent(draft: draft)
                }
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
                Text("Use a complete http or https link.").font(.caption).foregroundColor(AppColors.overlayPanelSecondaryText)
            case .noteEditor:
                MarkerWorkspaceTextInput(placeholder: "Chart note", text: $placementState.workspace.editorText, placementState: placementState, fieldID: "contextNote")
                    .accessibilityIdentifier("workspace.note")
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

    private var drawingEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust this drawing on the chart. Done keeps it; Cancel restores it.")
                .font(.footnote).foregroundColor(AppColors.overlayPanelSecondaryText)
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

    private func editorField(_ prompt: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        MarkerWorkspaceLineInput(placeholder: prompt, text: text, placementState: placementState,
                                 fieldID: "workspace.\(current.rawValue).\(prompt)", keyboard: keyboard)
    }

    private func routeRow(_ title: String, icon: String, detail: String? = nil, action: @escaping () -> Void) -> some View {
        MarkerGuidedOptionalRow(icon: icon, title: title, detail: detail, identifier: "workspace.\(title)", action: action)
            .frame(minHeight: 44)
    }
}
