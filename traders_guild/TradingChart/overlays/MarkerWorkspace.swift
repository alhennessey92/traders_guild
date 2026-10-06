import SwiftUI

/// Navigation and unfinished editor values have the same lifetime as the draft,
/// held by its `MarkerWorkspaceSession`. One route stack: Details at the root,
/// Review and Context screens pushed on top. `guidedStep` is derived from it
/// for the outer shell. No destination ever presents another sheet.
enum MarkerWorkspaceDestination: String, Hashable {
    case details, context, indicators, indicatorSettings, drawings, drawingEditor
    case levelEditor, timeframes, sourceEditor, noteEditor, relationship, responseTimeframe, review

    var isEditor: Bool { [.indicatorSettings, .levelEditor, .sourceEditor, .noteEditor, .drawingEditor].contains(self) }

    var title: String {
        switch self {
        case .details: return "Details"
        case .context: return "Context"
        case .indicators: return "Add indicator"
        case .indicatorSettings: return "Indicator settings"
        case .drawings: return "Add drawing"
        case .drawingEditor: return "Drawing"
        case .levelEditor: return "Level"
        case .timeframes: return "Supporting timeframes"
        case .sourceEditor: return "Source link"
        case .noteEditor: return "Chart note"
        case .relationship: return "Response relationship"
        case .responseTimeframe: return "Response timeframe"
        case .review: return "Review"
        }
    }
}

/// Where each screen was scrolled to and each field's cursor and offset. Read
/// back only when a screen is rebuilt; kept by reference so writing it (every
/// keystroke, cursor move and scroll) never copies or announces the state.
final class MarkerWorkspaceMemory {
    var scrollAnchors: [MarkerWorkspaceDestination: String] = [:]
    var textOffsets: [String: CGPoint] = [:]
    var textSelections: [String: NSRange] = [:]
}

struct MarkerWorkspaceState {
    var path: [MarkerWorkspaceDestination] = [.details]
    var destination: MarkerWorkspaceDestination { path.last ?? .details }
    /// A fresh state is a fresh memory.
    let memory = MarkerWorkspaceMemory()
    var scrollAnchors: [MarkerWorkspaceDestination: String] {
        get { memory.scrollAnchors }
        nonmutating set { memory.scrollAnchors = newValue }
    }
    var textOffsets: [String: CGPoint] {
        get { memory.textOffsets }
        nonmutating set { memory.textOffsets = newValue }
    }
    var textSelections: [String: NSRange] {
        get { memory.textSelections }
        nonmutating set { memory.textSelections = newValue }
    }
    var showsTitle = false
    var editorBaselineText = ""
    var editorBaselineTitle = ""
    var indicatorDraft: IndicatorSettingsDraft?
    var selectedComponentID: UUID?
    var selectedLevel: RLComponentType?
    var editorText = ""
    var editorTitle = ""
    var levelInputs: [RLComponentType: String] = [:]
    /// A level's chart handoff stays inside its existing numeric editor.
    var levelDrawingBaseline: MarkerComponentDraft?
    var levelDrawingBaselineIndex: Int?
    var levelDrawingColor: String?
    /// Drawing tools already mutate chart-native placement state. Cancel restores
    /// that editor's exact snapshot, including local component identities.
    var drawingBaseline: [MarkerComponentDraft]?
    var drawingColors: [UUID: String] = [:]
    var drawingScales: [UUID: CGFloat] = [:]
    var message: String?
}

extension MarkerPlacementState {
    var workspaceDestination: MarkerWorkspaceDestination {
        isGuidedFlowActive ? workspace.destination : .details
    }

    /// How deep the current screen sits, for the direction a new screen
    /// enters from: Details 0, then one more for each screen opened on top.
    var workspaceDepth: Int {
        isGuidedFlowActive ? max(0, workspace.path.count - 1) : 0
    }

    /// A drawing or level is being worked on the chart itself; the collapsed
    /// sheet shows that tool's bar instead of the resume dock.
    var isWorkspaceChartToolActive: Bool {
        guard guidedStep == .context else { return false }
        switch workspace.destination {
        case .drawingEditor: return true
        case .levelEditor: return workspace.levelDrawingBaseline != nil
        default: return false
        }
    }

    /// Semantic client support intersected with typed backend components. Poll,
    /// future tools and an activated Setup cannot be created through this path.
    func workspaceAllows(_ type: RLComponentType) -> Bool {
        isGuidedFlowActive && !isGuidedSubmissionInFlight && !isGuidedEditLocked
            && (!isGuidedEdit || guidedEditOriginal?.componentsMatched == true)
            && allowedComponentTypes(for: intent).contains(type) && type != .anchor
    }

    var workspaceCanAddSource: Bool {
        workspaceAllows(.linkURL) && component(.linkURL) == nil
    }

    var workspaceHasInvalidLevelInput: Bool {
        workspace.levelInputs.contains { type, input in
            guard [.levelSl, .levelTp].contains(type) else { return false }
            guard let price = Double(input), price.isFinite, price > 0 else { return true }
            return false
        }
    }

    /// Opens a screen on top of the current one; Back or Done returns to it,
    /// so an edit begun from Review comes back to Review.
    func openWorkspace(_ destination: MarkerWorkspaceDestination) {
        guard isGuidedFlowActive, !isGuidedSubmissionInFlight else { return }
        workspace.message = nil
        guard workspace.destination != destination else { return }
        workspace.path.append(destination)
    }

    /// Back from a picker keeps committed context. Back/Cancel from an editor
    /// discards only that editor's uncommitted changes, never the marker draft.
    func cancelWorkspaceEditor() {
        guard !isGuidedSubmissionInFlight else { return }
        if workspace.destination == .drawingEditor, let baseline = workspace.drawingBaseline {
            restoreWorkspaceDrawingSnapshot(baseline)
            commitDrawingAndExit()
        }
        if workspace.destination == .levelEditor, let baseline = workspace.levelDrawingBaseline {
            if let index = components.firstIndex(where: { $0.id == baseline.id }) { components[index] = baseline }
            else { components.insert(baseline, at: min(workspace.levelDrawingBaselineIndex ?? components.count, components.count)) }
            drawingColorOverrides[baseline.id] = workspace.levelDrawingColor
            commitDrawingAndExit()
        }
        workspace.levelDrawingBaseline = nil
        workspace.levelDrawingBaselineIndex = nil
        workspace.levelDrawingColor = nil
        workspace.indicatorDraft = nil
        workspace.selectedComponentID = nil
        workspace.selectedLevel = nil
        workspace.editorText = ""
        workspace.editorTitle = ""
        workspace.drawingBaseline = nil
        workspace.message = nil
        if workspace.path.count > 1 { workspace.path.removeLast() }
    }

    func beginWorkspaceIndicator(_ item: IndicatorCatalogItem, draftID: UUID? = nil) {
        guard workspaceAllows(.indicator) else { return }
        let context: IndicatorEditingContext
        if let draftID {
            guard let draft = components.first(where: { $0.id == draftID }),
                  case .indicator(let payload) = draft.payload else { return }
            context = IndicatorEditingContext(item: item, draftId: draftID, payload: payload)
        } else {
            guard canAttachIndicator(named: item.payloadName) else {
                workspace.message = limitMessage(for: .indicatorPanels); return
            }
            // A single-instance attached indicator edits the existing instance.
            let existing = indicatorDrafts.first { draft in
                guard case .indicator(let payload) = draft.payload else { return false }
                return payload.name == item.payloadName && payload.instanceId == nil
            }
            if let existing, case .indicator(let payload) = existing.payload {
                context = IndicatorEditingContext(item: item, draftId: existing.id, payload: payload)
            } else {
                context = IndicatorEditingContext(item: item, indicatorName: item.payloadName, existingSettings: item.defaultSettings)
            }
        }
        openWorkspace(.indicatorSettings)
        workspace.indicatorDraft = IndicatorSettingsDraft(context: context)
        workspace.selectedComponentID = context.draftId
    }

    func beginWorkspaceText(_ destination: MarkerWorkspaceDestination, componentID: UUID? = nil) {
        let type: RLComponentType = destination == .sourceEditor ? .linkURL : .textNote
        guard workspaceAllows(type) else { return }
        if destination == .sourceEditor, componentID == nil, !workspaceCanAddSource { return }
        openWorkspace(destination)
        workspace.selectedComponentID = componentID
        workspace.editorText = ""
        workspace.editorTitle = ""
        if let componentID, let draft = components.first(where: { $0.id == componentID }) {
            switch draft.payload {
            case .link(let payload):
                workspace.editorText = payload.url; workspace.editorTitle = payload.title ?? ""
            case .note(let payload): workspace.editorText = payload.text
            default: break
            }
        }
        workspace.editorBaselineText = workspace.editorText
        workspace.editorBaselineTitle = workspace.editorTitle
    }

    func beginWorkspaceLevel(_ type: RLComponentType, componentID: UUID? = nil) {
        guard [.levelSupport, .levelResistance].contains(type), workspaceAllows(type) else { return }
        let prior: MarkerComponentDraft?
        if let componentID {
            guard let exact = components.first(where: { $0.id == componentID }),
                  exact.componentType == type, exact.payload.guidedLevelPayload != nil else { return }
            prior = exact
        } else { prior = component(type) }
        openWorkspace(.levelEditor)
        workspace.selectedLevel = type
        workspace.selectedComponentID = prior?.id
        workspace.editorText = String(prior?.payload.levelPrice ?? anchorDraft?.payload.levelPrice ?? 0)
        workspace.editorBaselineText = workspace.editorText
    }

    /// When chart editing belongs to a level editor, re-entry must keep its ID.
    /// Nil leaves the existing drawing selection behaviour unchanged elsewhere.
    var workspaceLevelChartComponentID: UUID? {
        guard isGuidedFlowActive, workspaceDestination == .levelEditor,
              workspace.levelDrawingBaseline != nil else { return nil }
        return workspace.selectedComponentID
    }

    var workspaceCanEditLevelOnChart: Bool {
        guard workspaceDestination == .levelEditor, workspaceCanCommit,
              let id = workspace.selectedComponentID,
              let draft = components.first(where: { $0.id == id }) else { return false }
        return draft.componentType == workspace.selectedLevel
    }

    @discardableResult
    func beginWorkspaceLevelChartEditing() -> Bool {
        guard workspaceCanEditLevelOnChart, let id = workspace.selectedComponentID,
              let index = components.firstIndex(where: { $0.id == id }),
              let price = Double(workspace.editorText), let type = workspace.selectedLevel else { return false }
        if workspace.levelDrawingBaseline == nil {
            workspace.levelDrawingBaseline = components[index]
            workspace.levelDrawingBaselineIndex = index
            workspace.levelDrawingColor = drawingColorOverrides[id]
        }
        guard updateWorkspaceLevelFromChart(id: id, price: price) else { return false }
        beginEditingDrawing(id, tool: type == .levelSupport ? .support : .resistance)
        return true
    }

    var workspaceLevelPriceInput: Binding<String> {
        Binding(get: { self.workspace.editorText }, set: { value in
            self.workspace.editorText = value
            if let id = self.workspaceLevelChartComponentID, let price = Double(value) {
                _ = self.updateWorkspaceLevelFromChart(id: id, price: price)
            }
        })
    }

    /// Called by the existing chart handle after coordinate-to-price conversion.
    /// Also used for numeric adjustment while that same chart editor is open.
    @discardableResult
    func updateWorkspaceLevelFromChart(id: UUID, price: Double) -> Bool {
        guard workspaceLevelChartComponentID == id, let type = workspace.selectedLevel,
              workspaceAllows(type), price.isFinite, price > 0,
              let draft = components.first(where: { $0.id == id }), draft.componentType == type,
              let prior = draft.payload.guidedLevelPayload else { return false }
        if prior.price != price {
            let level = LevelPayload(price: price, label: prior.label, colorHex: prior.colorHex,
                                     lineStyle: prior.lineStyle, lineWidth: prior.lineWidth)
            updateComponent(id: id, payload: type == .levelSupport ? .levelSupport(level) : .levelResistance(level))
        }
        if Double(workspace.editorText) != price { workspace.editorText = String(price) }
        return true
    }

    @discardableResult
    func beginWorkspaceDrawing(_ tool: MarkerDrawingWorkflowTool, componentID: UUID? = nil) -> Bool {
        guard let type = tool.componentType, workspaceAllows(type), tool.isPhaseOneEnabled else { return false }
        guard componentID != nil || canAddDrawing else {
            workspace.message = limitMessage(for: .drawingOverlays); return false
        }
        openWorkspace(.drawingEditor)
        workspace.drawingBaseline = components
        workspace.drawingColors = drawingColorOverrides
        workspace.drawingScales = emojiScaleOverrides
        workspace.selectedComponentID = componentID
        if let componentID { beginEditingDrawing(componentID, tool: tool) }
        else if tool == .horizontalLine { _ = activateImmediateHorizontalDrawing(tool: tool) }
        else { startDrawingWorkflow(tool: tool) }
        return true
    }

    func workspaceHorizontalPriceBinding(for id: UUID) -> Binding<Double> {
        Binding(get: { self.components.first { $0.id == id }?.payload.levelPrice ?? 0 }, set: { price in
            guard self.workspaceAllows(.drawingHorizontalLine), price.isFinite, price > 0,
                  let draft = self.components.first(where: { $0.id == id }),
                  case .drawingHorizontalLine(let prior) = draft.payload else { return }
            self.updateComponent(id: id, payload: .drawingHorizontalLine(HorizontalLinePayload(
                price: price, label: prior.label, colorHex: prior.colorHex,
                lineStyle: prior.lineStyle, lineWidth: prior.lineWidth)))
        })
    }

    var workspaceCanCommit: Bool {
        guard !isGuidedSubmissionInFlight else { return false }
        switch workspace.destination {
        case .indicatorSettings: return workspace.indicatorDraft?.fields.isEmpty == false && workspaceAllows(.indicator)
        case .sourceEditor:
            return workspaceAllows(.linkURL) && Self.validWorkspaceURL(workspace.editorText)
        case .noteEditor: return workspaceAllows(.textNote) && !workspace.editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .levelEditor:
            guard let type = workspace.selectedLevel, workspaceAllows(type),
                  let price = Double(workspace.editorText) else { return false }
            if workspace.levelDrawingBaseline != nil {
                guard let id = workspace.selectedComponentID,
                      components.contains(where: { $0.id == id && $0.componentType == type }) else { return false }
            }
            return price.isFinite && price > 0
        case .drawingEditor:
            return drawingSession.editingDraftId != nil || (!drawingSession.isActive && workspace.drawingBaseline != nil && workspaceDrawingHasChanges)
        default: return !isGuidedSubmissionInFlight
        }
    }

    static func validWorkspaceURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return true
    }

    /// Commit exactly once at Done. No invalid placeholder component is created
    /// on editor entry, and settings keep multi-instance and saved draft identity.
    @discardableResult
    func commitWorkspaceEditor() -> Bool {
        guard workspaceCanCommit else { return false }
        switch workspace.destination {
        case .indicatorSettings:
            guard let draft = workspace.indicatorDraft,
                  draft.context.save(settings: draft.buildSettings(), to: self) else {
                workspace.message = limitMessage(for: .indicatorPanels); return false
            }
        case .sourceEditor:
            let prior = components.first { $0.id == workspace.selectedComponentID }
            let preview: String? = {
                if let prior, case .link(let payload) = prior.payload { return payload.previewImage }; return nil
            }()
            let link = LinkPayload(url: workspace.editorText.trimmingCharacters(in: .whitespacesAndNewlines),
                                   title: workspace.editorTitle.isEmpty ? nil : workspace.editorTitle, previewImage: preview)
            saveWorkspacePayload(.linkURL, payload: .link(link))
        case .noteEditor:
            let prior = components.first { $0.id == workspace.selectedComponentID }
            let payload = anchoredNotePayload(text: workspace.editorText, preserving: prior.flatMap {
                if case .note(let value) = $0.payload { return value }; return nil
            })
            saveWorkspacePayload(.textNote, payload: .note(payload))
        case .levelEditor:
            guard let type = workspace.selectedLevel, let price = Double(workspace.editorText) else { return false }
            let prior = components.first { $0.id == workspace.selectedComponentID }?.payload.guidedLevelPayload
            let level = LevelPayload(price: price, label: prior == nil ? type.displayName : prior?.label, colorHex: prior?.colorHex,
                                     lineStyle: prior?.lineStyle, lineWidth: prior?.lineWidth)
            saveWorkspacePayload(type, payload: type == .levelSupport ? .levelSupport(level) : .levelResistance(level))
            if workspace.levelDrawingBaseline != nil { commitDrawingAndExit() }
            workspace.levelDrawingBaseline = nil // Done keeps the selected chart level.
        case .drawingEditor:
            commitDrawingAndExit()
            workspace.drawingBaseline = nil // Done keeps the chart's changes.
        default: break
        }
        cancelWorkspaceEditor()
        // Done returns to the removable Context summary; Cancel returns to
        // the picker, where another item can be chosen without attachment.
        while [.indicators, .drawings].contains(workspace.destination), workspace.path.count > 1 {
            workspace.path.removeLast()
        }
        return true
    }

    private func saveWorkspacePayload(_ type: RLComponentType, payload: MarkerComponentPayload) {
        guard workspaceAllows(type) else { return }
        if let id = workspace.selectedComponentID { updateComponent(id: id, payload: payload) }
        else if type == .textNote { appendComponent(type, payload: payload) }
        else { upsertComponent(type, payload: payload) }
    }

    private var workspaceDrawingTypes: Set<RLComponentType> {
        [.levelSupport, .levelResistance, .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .textNote, .reactionEmoji]
    }

    private var workspaceDrawingHasChanges: Bool {
        guard let baseline = workspace.drawingBaseline else { return false }
        return components.filter { workspaceDrawingTypes.contains($0.componentType) }
            != baseline.filter { workspaceDrawingTypes.contains($0.componentType) }
    }

    private func restoreWorkspaceDrawingSnapshot(_ baseline: [MarkerComponentDraft]) {
        let saved = baseline.filter { workspaceDrawingTypes.contains($0.componentType) }
        let savedByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        let currentDrawingIDs = Set(components.filter { workspaceDrawingTypes.contains($0.componentType) }.map(\.id))
        var restored = components.compactMap { draft in
            workspaceDrawingTypes.contains(draft.componentType) ? savedByID[draft.id] : draft
        }
        for (index, draft) in baseline.enumerated() where workspaceDrawingTypes.contains(draft.componentType) && !restored.contains(where: { $0.id == draft.id }) {
            restored.insert(draft, at: min(index, restored.count))
        }
        components = restored
        for id in currentDrawingIDs.union(savedByID.keys) {
            drawingColorOverrides[id] = workspace.drawingColors[id]
            emojiScaleOverrides[id] = workspace.drawingScales[id]
        }
    }

    var hasWorkspaceEdits: Bool {
        if workspaceHasInvalidLevelInput { return true }
        if let baseline = workspace.levelDrawingBaseline,
           components.first(where: { $0.id == baseline.id }) != baseline { return true }
        if let draft = workspace.indicatorDraft {
            return draft.hasChanges
        }
        if workspace.drawingBaseline != nil { return workspaceDrawingHasChanges }
        return workspaceDestination.isEditor && (workspace.editorText != workspace.editorBaselineText || workspace.editorTitle != workspace.editorBaselineTitle)
    }

    func removeWorkspaceComponent(_ id: UUID) {
        guard let draft = components.first(where: { $0.id == id }), workspaceAllows(draft.componentType) else { return }
        removeComponent(id: id)
    }
}
