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

    /// The drawing being worked on: what it is, a clear way back to the
    /// chart, then its style as an inline strip (a line's stroke, its colour,
    /// a horizontal line's price). Done keeps it; Cancel puts it back exactly.
    private var drawingEditor: some View {
        let id = placementState.drawingSession.editingDraftId
        let draft = id.flatMap { id in placementState.components.first { $0.id == id } }
        let tool: MarkerDrawingToolKind? = draft.flatMap { draft in
            if case .drawingPattern(let payload) = draft.payload { return MarkerDrawingToolKind.from(patternKey: payload.patternKey) }
            return MarkerDrawingToolKind.from(componentType: draft.componentType)
        }
        let tint = MarkerContextTab.drawings.color
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: tool?.icon ?? "pencil.and.ruler")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(tint.opacity(0.16)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool?.title ?? "Drawing")
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.primaryForeground)
                    Text(id == nil ? "Finish placing it on the chart first." : "Done keeps it; Cancel puts it back exactly.")
                        .font(.caption)
                        .foregroundColor(AppColors.overlayPanelSecondaryText)
                }
            }
            Button { onBeginInteractiveDrawing?() } label: {
                Label(id == nil ? "Back to the chart" : "Move it on the chart", systemImage: "hand.draw")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.primaryForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(AppColors.whiteText.opacity(0.08)))
                    .overlay(Capsule().stroke(AppColors.whiteText.opacity(0.12), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workspace.drawing.adjust")
            if let id, let draft {
                if draft.componentType == .drawingHorizontalLine {
                    styleSection("Price") {
                        editorField("Price", text: Binding(
                            get: { MarkerGuidedFormat.priceFormatter.string(from: NSNumber(value: placementState.workspaceHorizontalPriceBinding(for: id).wrappedValue)) ?? "" },
                            set: { input in
                                let cleaned = input.replacingOccurrences(of: ",", with: "")
                                if let price = Double(cleaned), price.isFinite, price > 0 {
                                    placementState.workspaceHorizontalPriceBinding(for: id).wrappedValue = price
                                }
                            }
                        ), keyboard: .decimalPad)
                    }
                }
                styleSection("Line") {
                    HStack(spacing: 8) {
                        ForEach(MarkerDrawingLineStyle.allCases, id: \.self) { style in
                            lineStyleChip(style, selected: placementState.drawingLineStyle(for: id) == style, tint: tint) {
                                placementState.setDrawingLineStyle(style, for: id)
                            }
                        }
                    }
                }
                styleSection("Colour") {
                    HStack(spacing: 12) {
                        ForEach(Self.drawingSwatches, id: \.hex) { swatch in
                            let selected = placementState.drawingColorHex(for: id)?.uppercased() == swatch.hex
                            Button { placementState.setDrawingColorHex(swatch.hex, for: id) } label: {
                                Circle()
                                    .fill(Color(hex: swatch.hex) ?? .white)
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(AppColors.primaryForeground, lineWidth: selected ? 2.5 : 0).padding(-4))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(swatch.name) colour")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("workspace.drawing.colour.\(swatch.name)")
                        }
                    }
                }
            }
        }
    }

    private static let drawingSwatches: [(hex: String, name: String)] = [
        ("#10B981", "Green"), ("#38BDF8", "Blue"), ("#F59E0B", "Amber"), ("#F43F5E", "Red"), ("#8B5CF6", "Violet"),
    ]

    private func styleSection<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.primaryForeground)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// A stroke style, shown as the stroke itself.
    private func lineStyleChip(_ style: MarkerDrawingLineStyle, selected: Bool, tint: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 1.5))
                    path.addLine(to: CGPoint(x: 44, y: 1.5))
                }
                .stroke(selected ? tint : AppColors.overlayPanelSecondaryText,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: style.dashPattern))
                .frame(width: 44, height: 3)
                Text(style.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(selected ? AppColors.primaryForeground : AppColors.overlayPanelSecondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? tint.opacity(0.2) : AppColors.whiteText.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? tint : Color.clear, lineWidth: 1.2))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.title) line")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("workspace.drawing.style.\(style.rawValue)")
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
