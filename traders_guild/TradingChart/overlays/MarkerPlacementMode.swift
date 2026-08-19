import Foundation
import SwiftUI

struct MarkerComponentDraft: Identifiable, Equatable {
    let id: UUID
    var componentType: RLComponentType
    var payload: MarkerComponentPayload

    init(id: UUID = UUID(), componentType: RLComponentType, payload: MarkerComponentPayload) {
        self.id = id
        self.componentType = componentType
        self.payload = payload
    }

    static func == (lhs: MarkerComponentDraft, rhs: MarkerComponentDraft) -> Bool {
        lhs.id == rhs.id &&
        lhs.componentType == rhs.componentType &&
        payloadFingerprint(lhs.payload) == payloadFingerprint(rhs.payload)
    }

    private static func payloadFingerprint(_ payload: MarkerComponentPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard
            let data = try? encoder.encode(payload.rawPayload),
            let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return value
    }
}

enum MarkerToolGroup: String, CaseIterable, Identifiable {
    case anchor
    case levels
    case draw
    case indicators
    case note
    case timeframes
    case link
    case style

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anchor: return "Anchor"
        case .levels: return "Levels"
        case .draw: return "Draw"
        case .indicators: return "Indicators"
        case .note: return "Note"
        case .timeframes: return "Timeframes"
        case .link: return "Link"
        case .style: return "Style"
        }
    }

    var icon: String {
        switch self {
        case .anchor: return "scope"
        case .levels: return "line.3.horizontal"
        case .draw: return "pencil.and.ruler"
        case .indicators: return "waveform.path.ecg"
        case .note: return "text.bubble"
        case .timeframes: return "clock"
        case .link: return "link"
        case .style: return "paintpalette"
        }
    }
}

enum MarkerToolOption: String, CaseIterable, Identifiable {
    case anchorTap = "anchor.tap"
    case levelEntry = "level.entry"
    case levelSl = "level.sl"
    case levelTp = "level.tp"
    case levelSupport = "level.support"
    case levelResistance = "level.resistance"
    case drawTrendline = "drawing.trendline"
    case drawHorizontalLine = "drawing.horizontal_line"
    case drawZone = "drawing.zone"
    case indicatorRSI = "indicator.rsi"
    case indicatorMACD = "indicator.macd"
    case indicatorEMA = "indicator.ema"
    case textNote = "text.note"
    case timeframe1m = "timeframe.1m"
    case timeframe5m = "timeframe.5m"
    case timeframe1h = "timeframe.1h"
    case timeframe1d = "timeframe.1d"
    case linkURL = "link.url"
    case styleSeverity = "style.severity"
    case styleEmojiIdea = "style.emoji.idea"
    case styleEmojiFire = "style.emoji.fire"
    case styleEmojiBearish = "style.emoji.bearish"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anchorTap: return "Tap Anchor"
        case .levelEntry: return "Entry"
        case .levelSl: return "SL"
        case .levelTp: return "TP"
        case .levelSupport: return "Support"
        case .levelResistance: return "Resistance"
        case .drawTrendline: return "Trendline"
        case .drawHorizontalLine: return "Horizontal Line"
        case .drawZone: return "Zone"
        case .indicatorRSI: return "RSI"
        case .indicatorMACD: return "MACD"
        case .indicatorEMA: return "EMA"
        case .textNote: return "Text Note"
        case .timeframe1m: return "1m"
        case .timeframe5m: return "5m"
        case .timeframe1h: return "1h"
        case .timeframe1d: return "1d"
        case .linkURL: return "URL"
        case .styleSeverity: return "Severity"
        case .styleEmojiIdea: return "🎯 Idea"
        case .styleEmojiFire: return "🔥 Momentum"
        case .styleEmojiBearish: return "🐻 Bearish"
        }
    }

    var icon: String {
        switch self {
        case .anchorTap: return "scope"
        case .levelEntry, .levelSl, .levelTp, .levelSupport, .levelResistance: return "line.3.horizontal"
        case .drawHorizontalLine: return "line.3.horizontal"
        case .drawTrendline, .drawZone: return "pencil.and.ruler"
        case .indicatorRSI, .indicatorMACD, .indicatorEMA: return "waveform.path.ecg"
        case .textNote: return "text.bubble"
        case .timeframe1m, .timeframe5m, .timeframe1h, .timeframe1d: return "clock"
        case .linkURL: return "link"
        case .styleSeverity: return "exclamationmark.triangle.fill"
        case .styleEmojiIdea, .styleEmojiFire, .styleEmojiBearish: return "face.smiling"
        }
    }
}

enum MarkerPlacementLimitType {
    case indicatorPanels
    case drawingOverlays
    case timeframeLinks
}

enum DrawingInteractionPhase: String {
    case idle
    case placingFirstPoint
    case placingSecondPoint
    case editing
    case committing
}

struct MarkerPlacementChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let isRequired: Bool
    let isComplete: Bool
    /// Which tab's UI satisfies this, so the bottom bar can point at the one still needing
    /// attention. `nil` means it is satisfied on the chart itself (the anchor).
    var tab: MarkerPlacementTab? = .general
}

enum MarkerPlacementRequirements {
    /// Minimum user-authored characters for ALERT context and QUESTION text.
    /// Was a bare `10` in four places across this file. Mirrors Android
    /// `MarkerPlacementController.MIN_CONTEXT_CHARACTERS`.
    static let minimumContextCharacters = 10
}

@MainActor
final class MarkerPlacementState: ObservableObject {
    @Published var intent: RLMarkerIntent = .analysis
    @Published var selectedPlacementTab: MarkerPlacementTab = .general
    @Published var components: [MarkerComponentDraft] = []
    @Published var activeTool: MarkerToolGroup? = .anchor
    @Published var activeSubTool: String?
    @Published var title: String = ""
    @Published var note: String = ""
    @Published var visibility: String = "guild"
    @Published var confidence: Int?
    @Published var trackingEnabled: Bool = false
    @Published var pollQuestion: String = ""
    @Published var pollOptions: [String] = ["", ""]
    @Published var alertSeverity: MarkerAlertSeverity?
    @Published var newsURL: String = ""
    @Published var isChecklistCollapsed: Bool = false
    @Published var isTextInputFocused: Bool = false
    /// Placement-local color overrides keep UI edits stable while payloads are replaced.
    @Published var drawingColorOverrides: [UUID: String] = [:]
    /// Placement-local emoji scale while editing (interaction-only, non-persisted).
    @Published var emojiScaleOverrides: [UUID: CGFloat] = [:]
    @Published var drawingSession: MarkerDrawingSession = .inactive

    /// Live viewport-center anchor pushed by the chart so newly-added text/emoji
    /// annotations can default to where the user is looking, not the marker's
    /// own anchor (which may be off-screen, especially for setup intents pinned
    /// to the latest candle).
    var currentViewportAnchorTime: Date?
    var currentViewportAnchorPrice: Double?
    @Published var editingMarkerId: UUID?
    @Published var isAnchorLocked: Bool = false

    var drawingInteractionPhase: DrawingInteractionPhase {
        get { drawingSession.drawingInteractionPhase }
        set {
            switch newValue {
            case .idle:
                drawingSession.phase = .idle
                drawingSession.committedPoints = []
            case .placingFirstPoint:
                drawingSession.phase = .placing(stepIndex: 0)
                if drawingSession.committedPoints.count > 1 {
                    drawingSession.committedPoints = Array(drawingSession.committedPoints.prefix(1))
                }
            case .placingSecondPoint:
                drawingSession.phase = .placing(stepIndex: 1)
            case .editing:
                drawingSession.phase = .editing
            case .committing:
                drawingSession.phase = .committing
            }
        }
    }

    var pendingDrawingFirstPoint: (time: Date, price: Double)? {
        get {
            guard let first = drawingSession.committedPoints.first else { return nil }
            return (time: first.time, price: first.price)
        }
        set {
            guard let newValue else {
                drawingSession.committedPoints = []
                return
            }
            let nextPoint = MarkerDrawingGuidePoint(time: newValue.time, price: newValue.price)
            if drawingSession.committedPoints.isEmpty {
                drawingSession.committedPoints = [nextPoint]
            } else {
                drawingSession.committedPoints[0] = nextPoint
            }
        }
    }

    var editingDrawingId: UUID? {
        get { drawingSession.editingDraftId }
        set { drawingSession.editingDraftId = newValue }
    }

    var drawingGuidePoint: (time: Date, price: Double)? {
        get {
            guard let point = drawingSession.guidePoint else { return nil }
            return (time: point.time, price: point.price)
        }
        set {
            drawingSession.guidePoint = newValue.map {
                MarkerDrawingGuidePoint(time: $0.time, price: $0.price)
            }
        }
    }

    var isEditingExistingMarker: Bool {
        editingMarkerId != nil
    }

    var anchorDraft: MarkerComponentDraft? {
        components.first { $0.componentType == .anchor }
    }

    var indicatorDrafts: [MarkerComponentDraft] {
        components.filter { $0.componentType == .indicator }
    }

    var timeframeLinkDrafts: [MarkerComponentDraft] {
        components.filter { $0.componentType == .timeframeLink }
    }

    var drawingOverlayDrafts: [MarkerComponentDraft] {
        components.filter { isDrawingOverlayComponent($0.componentType) }
    }

    var activeDrawingDraft: MarkerComponentDraft? {
        guard let editingDrawingId else { return nil }
        return components.first { $0.id == editingDrawingId }
    }

    var activeDrawingWorkflowTool: MarkerDrawingWorkflowTool? {
        if let sessionTool = drawingSession.tool {
            return sessionTool
        }

        if let activeSubTool,
           let mappedTool = MarkerDrawingToolKind.from(activeSubTool: activeSubTool) {
            return mappedTool
        }

        guard let activeDrawingDraft else { return nil }
        return MarkerDrawingToolKind.from(componentType: activeDrawingDraft.componentType)
    }

    var isDrawingWorkflowActive: Bool {
        if drawingSession.isActive {
            return true
        }
        return activeTool == .draw || activeTool == .levels
    }

    var shouldShowDrawingDiscardAction: Bool {
        if !isDrawingWorkflowActive {
            return false
        }
        return activeDrawingWorkflowTool != nil
            || pendingDrawingFirstPoint != nil
            || activeLevelComponentTypeForCurrentSelection != nil
    }

    var toolbarInstructionText: String? {
        if let tool = activeDrawingWorkflowTool {
            let definition = MarkerDrawingToolRegistry.definition(for: tool)
            switch drawingInteractionPhase {
            case .placingFirstPoint:
                return definition.placementInstruction(for: drawingSession.stepIndex ?? 0)
            case .placingSecondPoint:
                return definition.placementInstruction(for: drawingSession.stepIndex ?? 1)
            case .editing:
                if tool == .note || tool == .emoji {
                    return "\(tool.title): drag to place, tap chart to save"
                }
                if (tool == .horizontalLine || tool == .support || tool == .resistance),
                   let draft = activeDrawingDraft {
                    let lineLabel = levelOrHorizontalLabel(for: draft, fallback: tool.defaultLabel ?? tool.title)
                    return "\(lineLabel): drag handle, tap chart to save"
                }
                return "\(tool.title): drag handles, tap chart to save"
            case .committing:
                return "Saving..."
            case .idle:
                if definition.requiresGuidePlacement {
                    return definition.placementInstruction(for: 0)
                }
                return "\(tool.title) ready"
            }
        }

        if activeTool == .levels {
            switch activeSubTool {
            case MarkerToolOption.levelSupport.rawValue:
                let supportLabel = levelLabel(for: .levelSupport, fallback: "Support")
                return "\(supportLabel): drag to position, tap to set"
            case MarkerToolOption.levelResistance.rawValue:
                let resistanceLabel = levelLabel(for: .levelResistance, fallback: "Resistance")
                return "\(resistanceLabel): drag to position, tap to set"
            default:
                break
            }
        }

        if activeTool == .draw {
            return "Draw: place points"
        }

        return nil
    }

    var toolbarInstructionDetailText: String? {
        guard let tool = activeDrawingWorkflowTool,
              tool.group == .pattern,
              let sequence = tool.guideSequenceText else {
            return nil
        }
        return sequence
    }

    var setupEntryPrice: Double? {
        guard intent == .setup else { return nil }
        return anchorDraft?.payload.levelPrice ?? componentPrice(.levelEntry)
    }

    var setupPnLPips: Double? {
        guard
            intent == .setup,
            let entry = setupEntryPrice,
            let tp = componentPrice(.levelTp),
            let sl = componentPrice(.levelSl)
        else {
            return nil
        }

        let pipStep = inferredSetupPipStep(entryPrice: entry)
        guard pipStep > 0 else { return nil }
        return abs(tp - sl) / pipStep
    }

    var setupRiskReward: Double? {
        guard
            intent == .setup,
            let entry = setupEntryPrice,
            let tp = componentPrice(.levelTp),
            let sl = componentPrice(.levelSl)
        else {
            return nil
        }

        let reward = abs(tp - entry)
        let risk = abs(sl - entry)
        guard risk > .ulpOfOne else { return nil }
        return reward / risk
    }

    var setupRiskPips: Double? {
        guard
            intent == .setup,
            let entry = setupEntryPrice,
            let sl = componentPrice(.levelSl)
        else {
            return nil
        }
        let pipStep = inferredSetupPipStep(entryPrice: entry)
        guard pipStep > 0 else { return nil }
        return abs(sl - entry) / pipStep
    }

    var setupRewardPips: Double? {
        guard
            intent == .setup,
            let entry = setupEntryPrice,
            let tp = componentPrice(.levelTp)
        else {
            return nil
        }
        let pipStep = inferredSetupPipStep(entryPrice: entry)
        guard pipStep > 0 else { return nil }
        return abs(tp - entry) / pipStep
    }

    var setupRiskPercent: Double? {
        guard
            intent == .setup,
            let entry = setupEntryPrice,
            let sl = componentPrice(.levelSl),
            abs(entry) > .ulpOfOne
        else {
            return nil
        }
        return abs((sl - entry) / entry) * 100
    }

    var setupRewardPercent: Double? {
        guard
            intent == .setup,
            let entry = setupEntryPrice,
            let tp = componentPrice(.levelTp),
            abs(entry) > .ulpOfOne
        else {
            return nil
        }
        return abs((tp - entry) / entry) * 100
    }

    var estimatedTrackingRepLoss: Int? {
        guard trackingEnabled, let riskPercent = setupRiskPercent else { return nil }
        return predictionReputationEstimate(pnlPercent: riskPercent, isWin: false)
    }

    var estimatedTrackingRepGain: Int? {
        guard trackingEnabled, let rewardPercent = setupRewardPercent else { return nil }
        return predictionReputationEstimate(pnlPercent: rewardPercent, isWin: true)
    }

    var placementChecklistItems: [MarkerPlacementChecklistItem] {
        var items: [MarkerPlacementChecklistItem] = [
            checklistItem(
                id: "anchor",
                title: "Anchor placed on chart",
                isRequired: true,
                isComplete: anchorDraft != nil,
                tab: nil
            ),
        ]

        switch intent {
        case .setup:
            let hasTpSl = componentPrice(.levelTp) != nil && componentPrice(.levelSl) != nil
            let setupDirectionValid = isSetupDirectionValid
            if trackingEnabled {
                items.append(
                    checklistItem(
                        id: "setup_levels_required",
                        title: "TP and SL configured",
                        isRequired: true,
                        isComplete: hasTpSl
                    )
                )
                items.append(
                    checklistItem(
                        id: "setup_direction_required",
                        title: "TP/SL direction is valid",
                        isRequired: true,
                        isComplete: setupDirectionValid
                    )
                )
            } else {
                items.append(
                    checklistItem(
                        id: "setup_levels_recommended",
                        title: "Set TP and SL levels",
                        isRequired: false,
                        isComplete: hasTpSl
                    )
                )
            }
            items.append(
                checklistItem(
                    id: "setup_tracking_recommended",
                    title: "Enable tracking for accuracy and TP reputation impact",
                    isRequired: false,
                    isComplete: trackingEnabled
                )
            )

        case .analysis:
            items.append(
                checklistItem(
                    id: "analysis_note",
                    title: "Add analysis description",
                    isRequired: true,
                    isComplete: !trimmedNote.isEmpty
                )
            )
            items.append(
                checklistItem(
                    id: "analysis_structure",
                    title: "Add at least one chart component",
                    isRequired: true,
                    isComplete: hasStructuredAnalysisComponents,
                    tab: .components
                )
            )

        case .alert:
            items.append(
                checklistItem(
                    id: "alert_severity",
                    title: "Select alert severity",
                    isRequired: true,
                    isComplete: resolvedAlertSeverity != nil
                )
            )
            items.append(
                checklistItem(
                    id: "alert_context",
                    title: "Write at least \(MarkerPlacementRequirements.minimumContextCharacters) characters of alert context",
                    isRequired: true,
                    isComplete: trimmedAlertDescription.count >= MarkerPlacementRequirements.minimumContextCharacters
                )
            )

        case .question:
            items.append(
                checklistItem(
                    id: "question_required",
                    title: "Write at least \(MarkerPlacementRequirements.minimumContextCharacters) characters",
                    isRequired: true,
                    isComplete: trimmedQuestionNote.count >= MarkerPlacementRequirements.minimumContextCharacters
                )
            )
            items.append(
                checklistItem(
                    id: "question_recommendation",
                    title: "Add a drawing for context",
                    isRequired: false,
                    isComplete: drawingOverlayCount > 0,
                    tab: .components
                )
            )

        case .poll:
            items.append(
                checklistItem(
                    id: "poll_question",
                    title: "Poll question provided",
                    isRequired: true,
                    isComplete: !trimmedPollQuestion.isEmpty
                )
            )
            items.append(
                checklistItem(
                    id: "poll_options_required",
                    title: "At least 2 poll options",
                    isRequired: true,
                    isComplete: validPollOptions.count >= 2
                )
            )
            items.append(
                checklistItem(
                    id: "poll_options_recommended",
                    title: "Add a 3rd option",
                    isRequired: false,
                    isComplete: validPollOptions.count >= 3
                )
            )

        case .news:
            items.append(
                checklistItem(
                    id: "news_url",
                    title: "Attach source URL",
                    isRequired: true,
                    isComplete: hasNewsSourceURL
                )
            )
            items.append(
                checklistItem(
                    id: "news_summary",
                    title: "Add brief summary note",
                    isRequired: false,
                    isComplete: !trimmedNote.isEmpty
                )
            )

        case .reaction:
            items.append(
                checklistItem(
                    id: "reaction_emoji",
                    title: "Choose reaction emoji",
                    isRequired: true,
                    isComplete: hasSelectedReactionEmoji
                )
            )
            items.append(
                checklistItem(
                    id: "reaction_context",
                    title: "Add optional context note",
                    isRequired: false,
                    isComplete: !trimmedNote.isEmpty
                )
            )

        case .personal:
            items.append(
                checklistItem(
                    id: "personal_note",
                    title: "Add personal note",
                    isRequired: false,
                    isComplete: !trimmedNote.isEmpty
                )
            )
            items.append(
                checklistItem(
                    id: "personal_timeframe",
                    title: "Link a timeframe",
                    isRequired: false,
                    isComplete: timeframeLinkCount > 0
                )
            )
        }

        items.append(
            checklistItem(
                id: "validity",
                title: "Placement requirements met",
                isRequired: true,
                isComplete: isValid,
                tab: nil
            )
        )

        return items
    }

    private let maxIndicatorPanels = 2
    private let maxDrawingOverlays = 15
    private let maxTimeframeLinks = 2
    let maxMovingAveragesPerType = 5

    var indicatorPanelCount: Int {
        indicatorDrafts.reduce(0) { partialResult, draft in
            guard
                case let .indicator(payload) = draft.payload,
                isPanelIndicator(payload.name)
            else {
                return partialResult
            }
            return partialResult + 1
        }
    }

    var drawingOverlayCount: Int {
        drawingOverlayDrafts.count
    }

    var timeframeLinkCount: Int {
        timeframeLinkDrafts.count
    }

    var canAddIndicator: Bool {
        indicatorPanelCount < maxIndicatorPanels
    }

    var canAddDrawing: Bool {
        drawingOverlayCount < maxDrawingOverlays
    }

    var canAddTimeframe: Bool {
        timeframeLinkCount < maxTimeframeLinks
    }

    func limitMessage(for limitType: MarkerPlacementLimitType) -> String {
        switch limitType {
        case .indicatorPanels:
            return "Maximum \(maxIndicatorPanels) indicator panels"
        case .drawingOverlays:
            return "Maximum \(maxDrawingOverlays) drawing overlays"
        case .timeframeLinks:
            return "Maximum \(maxTimeframeLinks) linked timeframes"
        }
    }

    var isValid: Bool {
        let anchorCount = components.filter { $0.componentType == .anchor }.count
        guard anchorCount == 1 else { return false }

        if intent == .poll {
            let validOptions = pollOptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return !pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validOptions.count >= 2
        }

        switch intent {
        case .analysis:
            return !trimmedNote.isEmpty && hasStructuredAnalysisComponents
        case .setup:
            // Setup anchors are fixed by chart placement flow; do not block submit on
            // additional directional/location requirements.
            return true
        case .alert:
            return resolvedAlertSeverity != nil && trimmedAlertDescription.count >= MarkerPlacementRequirements.minimumContextCharacters
        case .question:
            return trimmedQuestionNote.count >= MarkerPlacementRequirements.minimumContextCharacters
        case .poll:
            return false
        case .news:
            return hasNewsSourceURL
        case .reaction:
            return hasSelectedReactionEmoji
        case .personal:
            return true
        }
    }

    func reset(to intent: RLMarkerIntent, anchorTime: Date, anchorPrice: Double) {
        clearMarkerEditSession()
        self.intent = intent
        self.selectedPlacementTab = .general
        var resetComponents = [
            MarkerComponentDraft(
                componentType: .anchor,
                payload: .anchor(AnchorPayload(time: anchorTime, price: anchorPrice))
            ),
        ]
        if intent == .setup {
            resetComponents.append(
                MarkerComponentDraft(
                    componentType: .levelEntry,
                    payload: .levelEntry(LevelPayload(price: anchorPrice, label: "Entry"))
                )
            )
        }
        if intent == .reaction {
            resetComponents.append(
                MarkerComponentDraft(
                    componentType: .reactionEmoji,
                    payload: .reactionEmoji(anchoredEmojiPayload(emoji: "🎯"))
                )
            )
        }
        self.components = resetComponents
        self.activeTool = .anchor
        self.activeSubTool = nil
        self.title = ""
        self.note = ""
        self.visibility = intent == .personal ? "private" : "guild"
        self.confidence = nil
        self.trackingEnabled = false
        self.pollQuestion = ""
        self.pollOptions = ["", ""]
        self.alertSeverity = nil
        self.newsURL = ""
        self.isChecklistCollapsed = false
        self.isTextInputFocused = false
        self.drawingColorOverrides = [:]
        resetDrawingInteraction()
    }

    func setIntent(_ newIntent: RLMarkerIntent) {
        intent = newIntent

        if newIntent == .personal {
            visibility = "private"
        } else if visibility != "guild" {
            visibility = "guild"
        }

        if newIntent != .setup {
            trackingEnabled = false
        }

        if newIntent != .analysis && newIntent != .setup {
            confidence = nil
        }

        if newIntent == .reaction, component(.reactionEmoji) == nil {
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(anchoredEmojiPayload(emoji: "🎯")))
        }

        if newIntent == .poll {
            if pollOptions.count < 2 {
                pollOptions = ["", ""]
            }
        } else {
            pollQuestion = ""
            pollOptions = ["", ""]
        }

        if newIntent != .alert {
            alertSeverity = nil
        }

        if newIntent == .news,
           case let .link(payload)? = component(.linkURL)?.payload {
            newsURL = payload.url
        } else if newIntent != .news {
            newsURL = ""
        }

        purgeIncompatibleComponents(for: newIntent)
        drawingColorOverrides = drawingColorOverrides.filter { draftId, _ in
            components.contains(where: { $0.id == draftId })
        }

        if newIntent == .setup, let anchorPrice = anchorDraft?.payload.levelPrice {
            upsertComponent(
                .levelEntry,
                payload: .levelEntry(LevelPayload(price: anchorPrice, label: "Entry"))
            )
        }

        resetDrawingInteraction()
    }

    func isIndicatorAttached(named name: String) -> Bool {
        indicatorComponent(named: name) != nil
    }

    func canAttachIndicator(named name: String) -> Bool {
        if isMovingAverageName(name) {
            return canAddMovingAverage(named: name)
        }
        if isIndicatorAttached(named: name) {
            return true
        }
        if isPanelIndicator(name) {
            return canAddIndicator
        }
        return true
    }

    // MARK: - Moving Average Multi-Instance Support

    /// Count of moving averages currently attached for a given type name ("EMA", "SMA", "WMA", "HMA").
    func movingAverageCount(named name: String) -> Int {
        let normalized = normalizedIndicatorName(name)
        return indicatorDrafts.reduce(0) { partial, draft in
            guard case let .indicator(payload) = draft.payload,
                  normalizedIndicatorName(payload.name) == normalized else {
                return partial
            }
            return partial + 1
        }
    }

    /// Whether another MA of this type can be attached (enforces 5-per-type cap).
    func canAddMovingAverage(named name: String) -> Bool {
        movingAverageCount(named: name) < maxMovingAveragesPerType
    }

    /// Insert or update a moving average instance. If `instanceId` matches an existing
    /// draft, updates in place; otherwise appends a new instance (respecting the per-type cap).
    @discardableResult
    func upsertMovingAverage(
        name: String,
        settings: [String: AnyCodable]?,
        instanceId: UUID
    ) -> Bool {
        if let index = components.firstIndex(where: { draft in
            guard case let .indicator(payload) = draft.payload else { return false }
            return payload.instanceId == instanceId
        }) {
            let updated = IndicatorPayload(
                name: name,
                settings: settings,
                isPrimary: nil,
                instanceId: instanceId
            )
            setComponentPayload(at: index, to: .indicator(updated))
            return true
        }

        guard canAddMovingAverage(named: name) else { return false }

        let payload = IndicatorPayload(
            name: name,
            settings: settings,
            isPrimary: nil,
            instanceId: instanceId
        )
        components.append(
            MarkerComponentDraft(componentType: .indicator, payload: .indicator(payload))
        )
        return true
    }

    /// Remove a specific moving average instance by its instanceId.
    func removeMovingAverage(instanceId: UUID) {
        components.removeAll { draft in
            guard case let .indicator(payload) = draft.payload else { return false }
            return payload.instanceId == instanceId
        }
    }

    @discardableResult
    func upsertIndicator(
        name: String,
        settings: [String: AnyCodable]?
    ) -> Bool {
        // Moving averages are multi-instance: each legacy call without an instanceId
        // creates a fresh instance (capped at 5 per type).
        if isMovingAverageName(name) {
            return upsertMovingAverage(name: name, settings: settings, instanceId: UUID())
        }

        let normalizedName = normalizedIndicatorName(name)
        let existingIndex = components.firstIndex { draft in
            guard draft.componentType == .indicator,
                  case let .indicator(payload) = draft.payload else {
                return false
            }
            return normalizedIndicatorName(payload.name) == normalizedName
        }

        let shouldInsert = existingIndex == nil
        if shouldInsert && !canAttachIndicator(named: name) {
            return false
        }

        let payload = IndicatorPayload(
            name: name,
            settings: settings,
            isPrimary: nil
        )

        if let index = existingIndex {
            setComponentPayload(at: index, to: .indicator(payload))
        } else {
            components.append(
                MarkerComponentDraft(componentType: .indicator, payload: .indicator(payload))
            )
        }

        return true
    }

    /// Insert or update an indicator from an existing payload (preserves instanceId for MAs).
    @discardableResult
    func upsertIndicator(payload: IndicatorPayload) -> Bool {
        if isMovingAverageName(payload.name) {
            let id = payload.instanceId ?? UUID()
            return upsertMovingAverage(name: payload.name, settings: payload.settings, instanceId: id)
        }
        return upsertIndicator(name: payload.name, settings: payload.settings)
    }

    func removeIndicator(named name: String) {
        let normalizedName = normalizedIndicatorName(name)
        guard let index = components.firstIndex(where: { draft in
            guard draft.componentType == .indicator,
                  case let .indicator(payload) = draft.payload else {
                return false
            }
            return normalizedIndicatorName(payload.name) == normalizedName
        }) else {
            return
        }

        components.remove(at: index)
    }

    func isTimeframeLinked(_ timeframe: String) -> Bool {
        timeframeLinkComponent(for: timeframe) != nil
    }

    @discardableResult
    func upsertTimeframeLink(_ timeframe: String, note: String? = nil) -> Bool {
        let trimmedTimeframe = timeframe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTimeframe.isEmpty else { return false }
        let normalized = normalizedTimeframeKey(trimmedTimeframe)

        if let index = components.firstIndex(where: { draft in
            guard draft.componentType == .timeframeLink,
                  case let .timeframeLink(payload) = draft.payload else {
                return false
            }
            return normalizedTimeframeKey(payload.timeframe) == normalized
        }) {
            setComponentPayload(
                at: index,
                to: .timeframeLink(
                    TimeframeLinkPayload(timeframe: trimmedTimeframe, note: note)
                )
            )
            return true
        }

        guard canAddTimeframe else { return false }

        components.append(
            MarkerComponentDraft(
                componentType: .timeframeLink,
                payload: .timeframeLink(
                    TimeframeLinkPayload(timeframe: trimmedTimeframe, note: note)
                )
            )
        )
        return true
    }

    func removeTimeframeLink(_ timeframe: String) {
        let normalized = normalizedTimeframeKey(timeframe)
        components.removeAll { draft in
            guard draft.componentType == .timeframeLink,
                  case let .timeframeLink(payload) = draft.payload else {
                return false
            }
            return normalizedTimeframeKey(payload.timeframe) == normalized
        }
    }

    @discardableResult
    func attachActiveChartIndicators(_ payloads: [IndicatorPayload]) -> (added: Int, blockedByLimit: Bool) {
        var added = 0
        var blockedByLimit = false

        for payload in payloads {
            if isMovingAverageName(payload.name) {
                let id = payload.instanceId ?? UUID()
                let alreadyPresent = components.contains { draft in
                    if case let .indicator(existing) = draft.payload {
                        return existing.instanceId == id
                    }
                    return false
                }
                if !upsertMovingAverage(name: payload.name, settings: payload.settings, instanceId: id) {
                    blockedByLimit = true
                    continue
                }
                if !alreadyPresent {
                    added += 1
                }
                continue
            }

            let hadIndicator = isIndicatorAttached(named: payload.name)
            if !upsertIndicator(name: payload.name, settings: payload.settings) {
                blockedByLimit = true
                continue
            }
            if !hadIndicator {
                added += 1
            }
        }

        return (added, blockedByLimit)
    }

    @discardableResult
    func attachActiveChartDrawings(_ drawings: [ChartDrawing]) -> (added: Int, blockedByLimit: Bool) {
        let anchorTime = anchorDraft?.payload.anchorTime ?? Date()
        let anchorPrice = anchorDraft?.payload.levelPrice ?? 0
        var added = 0
        var blockedByLimit = false

        for drawing in drawings where drawing.isVisible {
            let draft = ChartDrawingBridge.markerDraft(
                from: drawing,
                anchorTime: anchorTime,
                anchorPrice: anchorPrice
            )

            if components.contains(where: { $0.id == draft.id }) {
                continue
            }

            if isDrawingOverlayComponent(draft.componentType), !canAddDrawing {
                blockedByLimit = true
                continue
            }

            components.append(draft)
            if let normalized = normalizedDrawingColorHex(from: draft.payload) {
                drawingColorOverrides[draft.id] = normalized
            }
            added += 1
        }

        return (added, blockedByLimit)
    }

    /// Append a fresh draft for component types that allow multiples
    /// (text notes, emoji reactions). Returns the new draft's id so callers
    /// can begin editing it.
    @discardableResult
    func appendComponent(_ componentType: RLComponentType, payload: MarkerComponentPayload) -> UUID {
        let draft = MarkerComponentDraft(componentType: componentType, payload: payload)
        components.append(draft)
        return draft.id
    }

    func upsertComponent(_ componentType: RLComponentType, payload: MarkerComponentPayload) {
        if componentType == .anchor, isAnchorLocked {
            return
        }

        if componentType == .indicator {
            guard case let .indicator(indicatorPayload) = payload else { return }
            _ = upsertIndicator(
                name: indicatorPayload.name,
                settings: indicatorPayload.settings
            )
            return
        }

        if let index = components.firstIndex(where: { $0.componentType == componentType }) {
            let mergedPayload = mergedDrawingAnnotationPayload(
                existing: components[index].payload,
                incoming: payload
            )
            setComponentPayload(at: index, to: mergedPayload)
        } else {
            components.append(MarkerComponentDraft(componentType: componentType, payload: payload))
        }

        if componentType == .anchor,
           intent == .setup,
           let anchorPrice = payload.levelPrice {
            upsertComponent(
                .levelEntry,
                payload: .levelEntry(LevelPayload(price: anchorPrice, label: "Entry"))
            )
        }
    }

    func removeComponent(_ componentType: RLComponentType) {
        guard componentType != .anchor else { return }
        let removedIDs = components
            .filter { $0.componentType == componentType }
            .map(\.id)
        let shouldClearDrawingInteraction = shouldClearDrawingInteractionAfterRemoving(
            ids: Set(removedIDs),
            componentTypes: [componentType]
        )
        components.removeAll { $0.componentType == componentType }
        for id in removedIDs {
            drawingColorOverrides.removeValue(forKey: id)
            emojiScaleOverrides.removeValue(forKey: id)
        }
        if shouldClearDrawingInteraction {
            commitDrawingAndExit()
        }
    }

    func removeComponent(id: UUID) {
        guard let draft = components.first(where: { $0.id == id }),
              draft.componentType != .anchor else {
            return
        }
        let shouldClearDrawingInteraction = shouldClearDrawingInteractionAfterRemoving(
            ids: [id],
            componentTypes: [draft.componentType]
        )
        components.removeAll { $0.id == id }
        drawingColorOverrides.removeValue(forKey: id)
        emojiScaleOverrides.removeValue(forKey: id)
        if shouldClearDrawingInteraction {
            commitDrawingAndExit()
        }
    }

    func updateComponent(id: UUID, payload: MarkerComponentPayload) {
        guard let index = components.firstIndex(where: { $0.id == id }) else { return }
        let componentType = components[index].componentType
        setComponentPayload(at: index, to: payload)
        if let normalized = normalizedDrawingColorHex(from: payload) {
            drawingColorOverrides[id] = normalized
        } else if isStyledDrawingComponent(componentType) {
            drawingColorOverrides.removeValue(forKey: id)
        }
    }

    func setDrawingColorHex(_ hex: String?, for draftId: UUID) {
        guard let index = components.firstIndex(where: { $0.id == draftId }) else { return }
        let normalized = normalizedHexColor(hex)
        if let normalized {
            drawingColorOverrides[draftId] = normalized
        } else {
            drawingColorOverrides.removeValue(forKey: draftId)
        }

        switch components[index].payload {
        case let .drawingTrendline(payload):
            setComponentPayload(
                at: index,
                to: .drawingTrendline(
                    TrendlinePayload(
                        startTime: payload.startTime,
                        startPrice: payload.startPrice,
                        endTime: payload.endTime,
                        endPrice: payload.endPrice,
                        colorHex: normalized,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .drawingHorizontalLine(payload):
            setComponentPayload(
                at: index,
                to: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: normalized,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .drawingZone(payload):
            setComponentPayload(
                at: index,
                to: .drawingZone(
                    ZonePayload(
                        topPrice: payload.topPrice,
                        bottomPrice: payload.bottomPrice,
                        startTime: payload.startTime,
                        endTime: payload.endTime,
                        colorHex: normalized,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .drawingPattern(payload):
            setComponentPayload(
                at: index,
                to: .drawingPattern(
                    ChartPatternPayload(
                        patternKey: payload.patternKey,
                        title: payload.title,
                        points: payload.points,
                        colorHex: normalized,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .levelSupport(payload):
            setComponentPayload(
                at: index,
                to: .levelSupport(
                    LevelPayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: normalized,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .levelResistance(payload):
            setComponentPayload(
                at: index,
                to: .levelResistance(
                    LevelPayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: normalized,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .note(payload):
            setComponentPayload(
                at: index,
                to: .note(
                    NotePayload(
                        text: payload.text,
                        offsetX: payload.offsetX,
                        offsetY: payload.offsetY,
                        anchorTime: payload.anchorTime,
                        anchorPrice: payload.anchorPrice,
                        fontSize: payload.fontSize,
                        colorHex: normalized
                    )
                )
            )
        default:
            break
        }
    }

    private func setComponentPayload(at index: Int, to payload: MarkerComponentPayload) {
        guard components.indices.contains(index) else { return }
        var updated = components
        updated[index].payload = payload
        components = updated
    }

    func drawingColorHex(for draftId: UUID) -> String? {
        if let overrideHex = drawingColorOverrides[draftId] {
            return overrideHex
        }
        guard let draft = components.first(where: { $0.id == draftId }) else { return nil }
        return normalizedDrawingColorHex(from: draft.payload)
    }

    func drawingLineStyle(for draftId: UUID, fallback: MarkerDrawingLineStyle = .dashed) -> MarkerDrawingLineStyle {
        guard let draft = components.first(where: { $0.id == draftId }) else { return fallback }
        return draft.payload.drawingLineStyle ?? fallback
    }

    func setDrawingLineStyle(_ lineStyle: MarkerDrawingLineStyle, for draftId: UUID) {
        guard let draft = components.first(where: { $0.id == draftId }) else { return }

        switch draft.payload {
        case let .drawingTrendline(payload):
            updateComponent(
                id: draftId,
                payload: .drawingTrendline(
                    TrendlinePayload(
                        startTime: payload.startTime,
                        startPrice: payload.startPrice,
                        endTime: payload.endTime,
                        endPrice: payload.endPrice,
                        colorHex: payload.colorHex,
                        lineStyle: lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .drawingHorizontalLine(payload):
            updateComponent(
                id: draftId,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .drawingZone(payload):
            updateComponent(
                id: draftId,
                payload: .drawingZone(
                    ZonePayload(
                        topPrice: payload.topPrice,
                        bottomPrice: payload.bottomPrice,
                        startTime: payload.startTime,
                        endTime: payload.endTime,
                        colorHex: payload.colorHex,
                        lineStyle: lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .drawingPattern(payload):
            updateComponent(
                id: draftId,
                payload: .drawingPattern(
                    ChartPatternPayload(
                        patternKey: payload.patternKey,
                        title: payload.title,
                        points: payload.points,
                        colorHex: payload.colorHex,
                        lineStyle: lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .levelSupport(payload):
            updateComponent(
                id: draftId,
                payload: .levelSupport(
                    LevelPayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        case let .levelResistance(payload):
            updateComponent(
                id: draftId,
                payload: .levelResistance(
                    LevelPayload(
                        price: payload.price,
                        label: payload.label,
                        colorHex: payload.colorHex,
                        lineStyle: lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        default:
            break
        }
    }

    func drawingColor(for draftId: UUID, fallback: Color) -> Color {
        guard let hex = drawingColorHex(for: draftId),
              let resolved = Color(hex: hex) else {
            return fallback
        }
        return resolved
    }

    func horizontalLineLabel(for draftId: UUID, fallback: String = "Line") -> String {
        guard let draft = components.first(where: { $0.id == draftId }) else { return fallback }
        let raw: String?
        switch draft.payload {
        case .drawingHorizontalLine(let payload):
            raw = payload.label
        default:
            raw = nil
        }
        if let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        return fallback
    }

    func setHorizontalLineLabel(_ label: String, for draftId: UUID) {
        guard let draft = components.first(where: { $0.id == draftId }) else { return }
        let trimmed = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(15))
        switch draft.payload {
        case .drawingHorizontalLine(let payload):
            updateComponent(
                id: draftId,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: payload.price,
                        label: trimmed.isEmpty ? nil : trimmed,
                        colorHex: payload.colorHex,
                        lineStyle: payload.lineStyle,
                        lineWidth: payload.lineWidth
                    )
                )
            )
        default:
            break
        }
    }

    func emojiScale(for draftId: UUID) -> CGFloat {
        let value = emojiScaleOverrides[draftId] ?? 1
        return min(2.4, max(0.6, value))
    }

    func setEmojiScale(_ scale: CGFloat, for draftId: UUID) {
        emojiScaleOverrides[draftId] = min(2.4, max(0.6, scale))
    }

    @discardableResult
    func addDrawingOverlayComponent(_ componentType: RLComponentType, payload: MarkerComponentPayload) -> UUID? {
        guard componentType.isDrawing else { return nil }
        guard canAddDrawing else { return nil }

        let draft = MarkerComponentDraft(componentType: componentType, payload: payload)
        components.append(draft)
        if let normalized = normalizedDrawingColorHex(from: payload) {
            drawingColorOverrides[draft.id] = normalized
        }
        return draft.id
    }

    func component(_ componentType: RLComponentType) -> MarkerComponentDraft? {
        components.first { $0.componentType == componentType }
    }

    func componentPrice(_ componentType: RLComponentType) -> Double? {
        component(componentType)?.payload.levelPrice
    }

    func anchoredNotePayload(
        text: String,
        offsetX: Double? = nil,
        offsetY: Double? = nil,
        anchorTime explicitAnchorTime: Date? = nil,
        anchorPrice explicitAnchorPrice: Double? = nil,
        colorHex: String? = nil,
        preserving existing: NotePayload? = nil
    ) -> NotePayload {
        NotePayload(
            text: text,
            offsetX: offsetX,
            offsetY: offsetY,
            anchorTime: explicitAnchorTime ?? existing?.anchorTime ?? anchorDraft?.payload.anchorTime,
            anchorPrice: explicitAnchorPrice ?? existing?.anchorPrice ?? anchorDraft?.payload.levelPrice,
            fontSize: existing?.fontSize,
            colorHex: colorHex ?? existing?.colorHex
        )
    }

    func anchoredEmojiPayload(
        emoji: String,
        offsetX: Double? = nil,
        offsetY: Double? = nil,
        anchorTime explicitAnchorTime: Date? = nil,
        anchorPrice explicitAnchorPrice: Double? = nil,
        preserving existing: EmojiPayload? = nil
    ) -> EmojiPayload {
        EmojiPayload(
            emoji: emoji,
            offsetX: offsetX,
            offsetY: offsetY,
            anchorTime: explicitAnchorTime ?? existing?.anchorTime ?? anchorDraft?.payload.anchorTime,
            anchorPrice: explicitAnchorPrice ?? existing?.anchorPrice ?? anchorDraft?.payload.levelPrice,
            scale: existing?.scale
        )
    }

    func clearMarkerEditSession() {
        editingMarkerId = nil
        isAnchorLocked = false
        isTextInputFocused = false
    }

    func beginEditingMarker(_ marker: ChartMarkerUI) {
        intent = marker.intent
        selectedPlacementTab = .components
        activeTool = .indicators
        activeSubTool = nil

        title = marker.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        note = marker.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let normalizedVisibility = marker.visibility.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        visibility = normalizedVisibility == "private" ? "private" : "guild"
        confidence = nil
        trackingEnabled = marker.trackingEnabled

        pollQuestion = marker.resolvedPollQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let existingPollOptions = marker.pollOptions?.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        let nonEmptyPollOptions = existingPollOptions.filter { !$0.isEmpty }
        pollOptions = nonEmptyPollOptions.count >= 2 ? nonEmptyPollOptions : ["", ""]

        alertSeverity = marker.alertSeverity
        isChecklistCollapsed = false
        isTextInputFocused = false
        emojiScaleOverrides = [:]

        let orderedComponents = marker.components.sorted {
            if $0.ordering != $1.ordering { return $0.ordering < $1.ordering }
            return $0.id.uuidString < $1.id.uuidString
        }

        var seededComponents = orderedComponents.compactMap { component -> MarkerComponentDraft? in
            guard let componentType = component.componentTypeEnum else { return nil }
            return MarkerComponentDraft(componentType: componentType, payload: component.payload)
        }

        if !seededComponents.contains(where: { $0.componentType == .anchor }) {
            seededComponents.insert(
                MarkerComponentDraft(
                    componentType: .anchor,
                    payload: .anchor(AnchorPayload(time: marker.candleTimestamp, price: marker.price))
                ),
                at: 0
            )
        }

        components = seededComponents

        drawingColorOverrides = Dictionary(
            uniqueKeysWithValues: seededComponents.compactMap { draft in
                guard let colorHex = normalizedDrawingColorHex(from: draft.payload) else { return nil }
                return (draft.id, colorHex)
            }
        )

        if case let .link(payload)? = component(.linkURL)?.payload {
            newsURL = payload.url
        } else {
            newsURL = ""
        }

        resetDrawingInteraction()
        editingMarkerId = marker.id
        isAnchorLocked = true
    }

    func resetDrawingInteraction() {
        drawingSession = .inactive
    }

    func prepareForInteractiveDrawing() {
        isChecklistCollapsed = true
    }

    func startDrawingWorkflow(tool: MarkerDrawingWorkflowTool) {
        prepareForInteractiveDrawing()
        let definition = MarkerDrawingToolRegistry.definition(for: tool)
        activeTool = definition.preferredToolGroup
        activeSubTool = definition.preferredSubToolRawValue
        drawingSession = MarkerDrawingSession(
            tool: tool,
            phase: definition.requiresGuidePlacement ? .placing(stepIndex: 0) : .editing,
            committedPoints: [],
            guidePoint: nil,
            editingDraftId: nil,
            selectedHandle: nil,
            isPanLocked: definition.requiresGuidePlacement
        )
    }

    func setDrawingFirstPoint(time: Date, price: Double) {
        let firstPoint = MarkerDrawingGuidePoint(time: time, price: price)
        if drawingSession.committedPoints.isEmpty {
            drawingSession.committedPoints = [firstPoint]
        } else {
            drawingSession.committedPoints[0] = firstPoint
        }
        drawingSession.phase = .placing(stepIndex: 1)
        drawingSession.isPanLocked = true
    }

    func beginDrawingCommit() {
        drawingSession.phase = .committing
    }

    func setDrawingGuidePoint(_ point: MarkerDrawingGuidePoint?) {
        drawingSession.guidePoint = point
    }

    func setDrawingPanLocked(_ isLocked: Bool) {
        drawingSession.isPanLocked = isLocked
    }

    func setSelectedDrawingHandle(_ handle: MarkerDrawingHandle?) {
        drawingSession.selectedHandle = handle
        if drawingSession.drawingInteractionPhase == .editing {
            drawingSession.isPanLocked = handle != nil
        }
    }

    func commitDrawingAndExit() {
        let shouldClearTool =
            drawingSession.isActive
            || activeDrawingWorkflowTool != nil
            || activeTool == .draw
            || activeTool == .levels
            || activeTool == .note
        drawingSession = .inactive
        if shouldClearTool {
            activeTool = nil
            activeSubTool = nil
        }
    }

    func discardActiveDrawingAndExit() {
        if let editingDrawingId {
            removeComponent(id: editingDrawingId)
            commitDrawingAndExit()
            return
        }

        if let activeLevelType = activeLevelComponentTypeForCurrentSelection {
            removeComponent(activeLevelType)
            if activeTool == .levels {
                activeTool = nil
                activeSubTool = nil
            }
            return
        }

        commitDrawingAndExit()
    }

    func beginTrendlinePlacement() {
        startDrawingWorkflow(tool: .trendline)
    }

    @discardableResult
    func activateImmediateHorizontalDrawing(tool: MarkerDrawingWorkflowTool) -> UUID? {
        prepareForInteractiveDrawing()

        let definition = MarkerDrawingToolRegistry.definition(for: tool)
        activeTool = definition.preferredToolGroup
        activeSubTool = definition.preferredSubToolRawValue

        let anchorPrice = anchorDraft?.payload.levelPrice ?? 0

        switch tool {
        case .horizontalLine:
            guard canAddDrawing else { return nil }
            let draftId = addDrawingOverlayComponent(
                .drawingHorizontalLine,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: anchorPrice,
                        label: tool.defaultLabel
                    )
                )
            )
            if let draftId {
                beginEditingDrawing(draftId, tool: tool)
            }
            return draftId

        case .support:
            let existingColor = component(.levelSupport)?.payload.drawingColorHex
            let existingStyle = component(.levelSupport)?.payload.drawingLineStyle
            let existingWidth = component(.levelSupport)?.payload.drawingLineWidth
            upsertComponent(
                .levelSupport,
                payload: .levelSupport(
                    LevelPayload(
                        price: componentPrice(.levelSupport) ?? anchorPrice,
                        label: levelLabel(for: .levelSupport, fallback: tool.defaultLabel ?? "Support"),
                        colorHex: existingColor,
                        lineStyle: existingStyle,
                        lineWidth: existingWidth
                    )
                )
            )
            if let draftId = component(.levelSupport)?.id {
                beginEditingDrawing(draftId, tool: tool)
                return draftId
            }
            return nil

        case .resistance:
            let existingColor = component(.levelResistance)?.payload.drawingColorHex
            let existingStyle = component(.levelResistance)?.payload.drawingLineStyle
            let existingWidth = component(.levelResistance)?.payload.drawingLineWidth
            upsertComponent(
                .levelResistance,
                payload: .levelResistance(
                    LevelPayload(
                        price: componentPrice(.levelResistance) ?? anchorPrice,
                        label: levelLabel(for: .levelResistance, fallback: tool.defaultLabel ?? "Resistance"),
                        colorHex: existingColor,
                        lineStyle: existingStyle,
                        lineWidth: existingWidth
                    )
                )
            )
            if let draftId = component(.levelResistance)?.id {
                beginEditingDrawing(draftId, tool: tool)
                return draftId
            }
            return nil

        default:
            startDrawingWorkflow(tool: tool)
            return nil
        }
    }

    func beginHorizontalLinePlacement() {
        _ = activateImmediateHorizontalDrawing(tool: .horizontalLine)
    }

    func beginZonePlacement() {
        startDrawingWorkflow(tool: .zone)
    }

    func beginEditingDrawing(_ draftId: UUID, tool: MarkerDrawingWorkflowTool? = nil) {
        prepareForInteractiveDrawing()
        if let tool {
            let definition = MarkerDrawingToolRegistry.definition(for: tool)
            activeTool = definition.preferredToolGroup
            activeSubTool = definition.preferredSubToolRawValue
            drawingSession.tool = tool
        } else if let existingTool = activeDrawingWorkflowTool {
            let definition = MarkerDrawingToolRegistry.definition(for: existingTool)
            activeTool = definition.preferredToolGroup
            activeSubTool = definition.preferredSubToolRawValue
        } else {
            activeTool = .draw
        }
        drawingSession.phase = .editing
        drawingSession.editingDraftId = draftId
        drawingSession.committedPoints = []
        drawingSession.guidePoint = nil
        drawingSession.selectedHandle = nil
        drawingSession.isPanLocked = false
    }

    func availableGroups() -> [MarkerToolGroup] {
        switch intent {
        case .analysis:
            return [.anchor, .levels, .draw, .indicators, .note, .timeframes, .link]
        case .setup:
            return [.anchor, .levels, .draw, .indicators, .note, .timeframes]
        case .news:
            return [.anchor, .draw, .indicators, .note, .timeframes, .link]
        case .poll, .question:
            return [.anchor, .draw, .indicators, .note, .timeframes]
        case .reaction:
            return [.anchor, .draw, .indicators, .timeframes, .style]
        case .alert:
            return [.anchor, .draw, .indicators, .note, .timeframes, .style]
        case .personal:
            return [.anchor, .levels, .draw, .indicators, .note, .timeframes]
        }
    }

    func availableOptions(for group: MarkerToolGroup) -> [MarkerToolOption] {
        switch group {
        case .anchor:
            return [.anchorTap]
        case .levels:
            switch intent {
            case .setup:
                return [.levelSl, .levelTp]
            case .analysis, .personal:
                return [.levelSupport, .levelResistance]
            default:
                return []
            }
        case .draw:
            return [.drawTrendline, .drawHorizontalLine, .drawZone]
        case .indicators:
            return [.indicatorRSI, .indicatorMACD, .indicatorEMA]
        case .note:
            return [.textNote]
        case .timeframes:
            return [.timeframe1m, .timeframe5m, .timeframe1h, .timeframe1d]
        case .link:
            return [.linkURL]
        case .style:
            if intent == .reaction {
                return [.styleEmojiIdea, .styleEmojiFire, .styleEmojiBearish]
            }
            return intent == .alert ? [.styleSeverity] : []
        }
    }

    func applyToolOption(_ option: MarkerToolOption) {
        activeSubTool = option.rawValue
        let anchorTime = anchorDraft?.payload.anchorTime ?? Date()
        let anchorPrice = anchorDraft?.payload.levelPrice ?? 0

        switch option {
        case .anchorTap:
            if anchorDraft == nil {
                upsertComponent(
                    .anchor,
                    payload: .anchor(AnchorPayload(time: anchorTime, price: anchorPrice))
                )
            }
        case .levelEntry:
            let value: Double
            if intent == .setup {
                value = anchorPrice
            } else {
                value = componentPrice(.levelEntry) ?? anchorPrice
            }
            upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: value, label: "Entry")))
        case .levelSl:
            let fallback = anchorPrice > 0 ? anchorPrice * 0.99 : anchorPrice
            let value = componentPrice(.levelSl) ?? fallback
            upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: value, label: "SL")))
        case .levelTp:
            let fallback = anchorPrice > 0 ? anchorPrice * 1.01 : anchorPrice
            let value = componentPrice(.levelTp) ?? fallback
            upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: value, label: "TP")))
        case .levelSupport:
            _ = activateImmediateHorizontalDrawing(tool: .support)
        case .levelResistance:
            _ = activateImmediateHorizontalDrawing(tool: .resistance)
        case .drawTrendline:
            startDrawingWorkflow(tool: .trendline)
        case .drawHorizontalLine:
            _ = activateImmediateHorizontalDrawing(tool: .horizontalLine)
        case .drawZone:
            startDrawingWorkflow(tool: .zone)
        case .indicatorRSI:
            _ = upsertIndicator(name: "RSI", settings: nil)
        case .indicatorMACD:
            _ = upsertIndicator(name: "MACD", settings: nil)
        case .indicatorEMA:
            let settings: [String: AnyCodable] = [
                "period": AnyCodable(20),
                "source": AnyCodable("close"),
            ]
            _ = upsertIndicator(name: "EMA", settings: settings)
        case .textNote:
            if component(.textNote) == nil && !canAddDrawing {
                return
            }
            let text = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Add your context"
                : note.trimmingCharacters(in: .whitespacesAndNewlines)
            upsertComponent(.textNote, payload: .note(anchoredNotePayload(text: text)))
            if let draftId = component(.textNote)?.id {
                beginEditingDrawing(draftId, tool: .note)
            }
        case .timeframe1m:
            _ = upsertTimeframeLink("1m")
        case .timeframe5m:
            _ = upsertTimeframeLink("5m")
        case .timeframe1h:
            _ = upsertTimeframeLink("1h")
        case .timeframe1d:
            _ = upsertTimeframeLink("1d")
        case .linkURL:
            upsertComponent(.linkURL, payload: .link(LinkPayload(url: "https://", title: nil, previewImage: nil)))
        case .styleSeverity:
            if component(.textNote) == nil && !canAddDrawing {
                return
            }
            let text = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "High-priority alert"
                : note.trimmingCharacters(in: .whitespacesAndNewlines)
            upsertComponent(.textNote, payload: .note(anchoredNotePayload(text: text)))
            if let draftId = component(.textNote)?.id {
                beginEditingDrawing(draftId, tool: .note)
            }
        case .styleEmojiIdea:
            if component(.reactionEmoji) == nil && !canAddDrawing {
                return
            }
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(anchoredEmojiPayload(emoji: "🎯")))
            if let draftId = component(.reactionEmoji)?.id {
                beginEditingDrawing(draftId, tool: .emoji)
            }
        case .styleEmojiFire:
            if component(.reactionEmoji) == nil && !canAddDrawing {
                return
            }
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(anchoredEmojiPayload(emoji: "🔥")))
            if let draftId = component(.reactionEmoji)?.id {
                beginEditingDrawing(draftId, tool: .emoji)
            }
        case .styleEmojiBearish:
            if component(.reactionEmoji) == nil && !canAddDrawing {
                return
            }
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(anchoredEmojiPayload(emoji: "🐻")))
            if let draftId = component(.reactionEmoji)?.id {
                beginEditingDrawing(draftId, tool: .emoji)
            }
        }
    }

    func buildCreateRequest(symbolId: UUID, timeframe: String) -> RLCreateMarkerRequest {
        let requestComponents = requestComponentsForCurrentState()

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPollQuestion = pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String? = {
            if intent == .poll {
                return trimmedPollQuestion.isEmpty ? nil : trimmedPollQuestion
            }
            return trimmedTitle.isEmpty ? nil : trimmedTitle
        }()
        let normalizedPollOptions = pollOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let resolvedVisibility = intent == .personal ? "private" : "guild"
        let resolvedConfidence: Int? = nil

        return RLCreateMarkerRequest(
            symbolId: symbolId,
            timeframe: timeframe,
            intent: intent.rawValue,
            title: resolvedTitle,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            visibility: resolvedVisibility,
            confidence: resolvedConfidence,
            trackingEnabled: trackingEnabled,
            components: requestComponents,
            pollQuestion: intent == .poll ? (trimmedPollQuestion.isEmpty ? nil : trimmedPollQuestion) : nil,
            pollOptions: intent == .poll ? normalizedPollOptions : nil
        )
    }

    func buildUpdateRequest() -> RLUpdateMarkerRequest {
        let requestComponents = requestComponentsForCurrentState()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPollQuestion = pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String? = {
            if intent == .poll {
                return trimmedPollQuestion.isEmpty ? nil : trimmedPollQuestion
            }
            return trimmedTitle.isEmpty ? nil : trimmedTitle
        }()
        let normalizedPollOptions = pollOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let resolvedVisibility = intent == .personal ? "private" : "guild"

        return RLUpdateMarkerRequest(
            intent: nil,
            title: resolvedTitle,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            visibility: resolvedVisibility,
            confidence: nil,
            trackingEnabled: trackingEnabled,
            components: requestComponents,
            pollQuestion: intent == .poll ? (trimmedPollQuestion.isEmpty ? nil : trimmedPollQuestion) : nil,
            pollOptions: intent == .poll ? normalizedPollOptions : nil
        )
    }

    private func requestComponentsForCurrentState() -> [RLMarkerComponentRequest] {
        var requestDrafts = components
        if intent == .setup, let anchorPrice = anchorDraft?.payload.levelPrice {
            let entryPayload: MarkerComponentPayload = .levelEntry(
                LevelPayload(price: anchorPrice, label: "Entry")
            )
            if let existingEntryIndex = requestDrafts.firstIndex(where: { $0.componentType == .levelEntry }) {
                requestDrafts[existingEntryIndex].payload = entryPayload
            } else {
                requestDrafts.append(
                    MarkerComponentDraft(
                        componentType: .levelEntry,
                        payload: entryPayload
                    )
                )
            }
        }

        let orderedDrafts = requestDrafts.sorted {
            let lhsRank = componentOrderingRank($0.componentType)
            let rhsRank = componentOrderingRank($1.componentType)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return $0.id.uuidString < $1.id.uuidString
        }

        return orderedDrafts.map { draft in
            RLMarkerComponentRequest(
                componentType: draft.componentType.rawValue,
                payload: draft.payload.rawPayload
            )
        }
    }

    private func componentOrderingRank(_ type: RLComponentType) -> Int {
        switch type {
        case .anchor:
            return 0
        case .levelEntry, .levelSl, .levelTp, .levelSupport, .levelResistance:
            return 1
        case .drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern:
            return 2
        case .indicator:
            return 3
        case .linkURL, .timeframeLink:
            return 4
        case .textNote, .reactionEmoji:
            return 5
        }
    }

    private func indicatorComponent(named name: String) -> MarkerComponentDraft? {
        let normalizedName = normalizedIndicatorName(name)
        return indicatorDrafts.first { draft in
            guard case let .indicator(payload) = draft.payload else { return false }
            return normalizedIndicatorName(payload.name) == normalizedName
        }
    }

    func isMovingAverageName(_ name: String) -> Bool {
        let normalized = normalizedIndicatorName(name)
        return normalized == "EMA" || normalized == "SMA" || normalized == "WMA" || normalized == "HMA"
    }

    private func isPanelIndicator(_ name: String) -> Bool {
        let normalized = normalizedIndicatorName(name)
        if normalized.contains("VWAP") || normalized.contains("WEIGHTED AVERAGE PRICE") {
            return false
        }
        return normalized.contains("RSI")
            || normalized.contains("MACD")
            || normalized.contains("STOCH")
            || normalized.contains("CCI")
            || normalized.contains("WILLIAMS")
            || normalized.contains("ATR")
            || normalized.contains("VOLUME")
    }

    private func normalizedIndicatorName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func inferredSetupPipStep(entryPrice: Double) -> Double {
        let absolute = abs(entryPrice)
        if absolute >= 1000 { return 1.0 }
        if absolute >= 100 { return 0.01 }
        if absolute >= 1 { return 0.0001 }
        return 0.00001
    }

    private func timeframeLinkComponent(for timeframe: String) -> MarkerComponentDraft? {
        let normalized = normalizedTimeframeKey(timeframe)
        return timeframeLinkDrafts.first { draft in
            guard case let .timeframeLink(payload) = draft.payload else { return false }
            return normalizedTimeframeKey(payload.timeframe) == normalized
        }
    }

    private func normalizedTimeframeKey(_ timeframe: String) -> String {
        timeframe.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func drawingSubToolRawValue(for tool: MarkerDrawingWorkflowTool) -> String? {
        switch tool {
        case .trendline:
            return MarkerToolOption.drawTrendline.rawValue
        case .horizontalLine:
            return MarkerToolOption.drawHorizontalLine.rawValue
        case .support:
            return MarkerToolOption.levelSupport.rawValue
        case .resistance:
            return MarkerToolOption.levelResistance.rawValue
        case .zone:
            return MarkerToolOption.drawZone.rawValue
        case .note, .emoji, .rayLine, .verticalLine, .crossLine, .parallelChannel, .breakoutRetest, .rangeReversal, .risingChannel, .headAndShoulders, .longPosition, .shortPosition, .takeProfitIdea, .stopLossIdea:
            return nil
        }
    }

    private func predictionReputationEstimate(pnlPercent: Double, isWin: Bool) -> Int {
        let magnitude = abs(pnlPercent)
        let basePoints: Double

        if isWin {
            if magnitude < 1.0 {
                basePoints = 25.0 + (magnitude * 10.0)
            } else if magnitude < 3.0 {
                basePoints = 35.0 + ((magnitude - 1.0) * 7.5)
            } else if magnitude < 5.0 {
                basePoints = 50.0 + ((magnitude - 3.0) * 12.5)
            } else {
                basePoints = 75.0
            }
        } else {
            basePoints = max(-15.0, min(-5.0, -5.0 - (magnitude * 0.5)))
        }

        // Mirror the backend base prediction formula; server-side variance still applies later.
        return max(1, Int(abs(basePoints).rounded()))
    }

    private var activeLevelComponentTypeForCurrentSelection: RLComponentType? {
        guard activeTool == .levels else { return nil }
        switch activeSubTool {
        case MarkerToolOption.levelSupport.rawValue:
            return component(.levelSupport) != nil ? .levelSupport : nil
        case MarkerToolOption.levelResistance.rawValue:
            return component(.levelResistance) != nil ? .levelResistance : nil
        default:
            return nil
        }
    }

    func levelLabel(for componentType: RLComponentType, fallback: String) -> String {
        guard let component = component(componentType) else { return fallback }
        switch component.payload {
        case .levelSupport(let payload):
            let label = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return label.isEmpty ? fallback : label
        case .levelResistance(let payload):
            let label = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return label.isEmpty ? fallback : label
        default:
            return fallback
        }
    }

    private func levelOrHorizontalLabel(for draft: MarkerComponentDraft, fallback: String) -> String {
        switch draft.payload {
        case .drawingHorizontalLine(let payload):
            let label = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return label.isEmpty ? fallback : label
        case .levelSupport(let payload), .levelResistance(let payload):
            let label = payload.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return label.isEmpty ? fallback : label
        default:
            return fallback
        }
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Exposed (was private) so the General tab can show a live character-count hint.
    var trimmedQuestionNote: String {
        trimmedNote
    }

    private var trimmedPollQuestion: String {
        pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Exposed (was private) so the General tab can show a live character-count hint.
    var trimmedAlertDescription: String {
        stripAlertSeverityPrefix(from: trimmedNote)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validPollOptions: [String] {
        pollOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var hasSelectedReactionEmoji: Bool {
        guard case let .reactionEmoji(payload)? = component(.reactionEmoji)?.payload else {
            return false
        }
        return !payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasNewsSourceURL: Bool {
        guard case let .link(payload)? = component(.linkURL)?.payload else {
            return false
        }
        return !payload.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasStructuredAnalysisComponents: Bool {
        components.contains {
            switch $0.componentType {
            case .levelEntry, .levelSl, .levelTp, .levelSupport, .levelResistance:
                return true
            default:
                return false
            }
        }
            || drawingOverlayCount > 0
            || !indicatorDrafts.isEmpty
            || timeframeLinkCount > 0
    }

    private var resolvedAlertSeverity: MarkerAlertSeverity? {
        alertSeverity ?? inferredAlertSeverity(from: trimmedNote)
    }

    private func stripAlertSeverityPrefix(from text: String) -> String {
        let knownPrefixes = [
            "[Critical] ",
            "[Severe] ",
            "[Warning] ",
            "[Informational] ",
        ]
        for prefix in knownPrefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }

    private func inferredAlertSeverity(from note: String) -> MarkerAlertSeverity? {
        if note.hasPrefix("[Critical] ") { return .critical }
        if note.hasPrefix("[Severe] ") { return .severe }
        if note.hasPrefix("[Warning] ") { return .moderate }
        if note.hasPrefix("[Informational] ") { return .mild }
        return nil
    }

    private var isSetupDirectionValid: Bool {
        guard
            let entry = setupEntryPrice,
            let sl = componentPrice(.levelSl),
            let tp = componentPrice(.levelTp)
        else {
            return false
        }
        let isLong = tp > entry && sl < entry
        let isShort = tp < entry && sl > entry
        return isLong || isShort
    }

    /// Required requirements that are still unmet, in the order the checklist presents them.
    /// Drives the bottom-bar dots and the "tap the disabled Place button to jump" behaviour.
    var unmetRequiredChecklistItems: [MarkerPlacementChecklistItem] {
        // "validity" is the summary row (isComplete == isValid), not a requirement of its own —
        // counting it would badge General even when the only real gap is on Components.
        placementChecklistItems.filter { $0.isRequired && !$0.isComplete && $0.id != "validity" }
    }

    func unmetRequiredCount(for tab: MarkerPlacementTab) -> Int {
        unmetRequiredChecklistItems.filter { $0.tab == tab }.count
    }

    private func checklistItem(
        id: String,
        title: String,
        isRequired: Bool,
        isComplete: Bool,
        tab: MarkerPlacementTab? = .general
    ) -> MarkerPlacementChecklistItem {
        MarkerPlacementChecklistItem(id: id, title: title, isRequired: isRequired, isComplete: isComplete, tab: tab)
    }

    private func isStyledDrawingComponent(_ componentType: RLComponentType) -> Bool {
        componentType.isDrawing || componentType == .levelSupport || componentType == .levelResistance
    }

    private func isDrawingOverlayComponent(_ componentType: RLComponentType) -> Bool {
        if componentType == .reactionEmoji {
            return intent != .reaction
        }
        return componentType.isDrawing || componentType == .textNote
    }

    private func shouldClearDrawingInteractionAfterRemoving(
        ids removedIDs: Set<UUID>,
        componentTypes removedComponentTypes: Set<RLComponentType>
    ) -> Bool {
        if let editingDrawingId, removedIDs.contains(editingDrawingId) {
            return true
        }

        if let activeLevelType = activeLevelComponentTypeForCurrentSelection,
           removedComponentTypes.contains(activeLevelType) {
            return true
        }

        guard drawingSession.isActive,
              let activeToolComponentType = activeDrawingWorkflowTool?.componentType else {
            return false
        }
        return removedComponentTypes.contains(activeToolComponentType)
    }

    private func mergedDrawingAnnotationPayload(
        existing: MarkerComponentPayload,
        incoming: MarkerComponentPayload
    ) -> MarkerComponentPayload {
        switch (existing, incoming) {
        case let (.drawingTrendline(existingPayload), .drawingTrendline(incomingPayload)):
            return .drawingTrendline(
                TrendlinePayload(
                    startTime: incomingPayload.startTime,
                    startPrice: incomingPayload.startPrice,
                    endTime: incomingPayload.endTime,
                    endPrice: incomingPayload.endPrice,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex,
                    lineStyle: incomingPayload.lineStyle ?? existingPayload.lineStyle,
                    lineWidth: incomingPayload.lineWidth ?? existingPayload.lineWidth
                )
            )
        case let (.drawingHorizontalLine(existingPayload), .drawingHorizontalLine(incomingPayload)):
            return .drawingHorizontalLine(
                HorizontalLinePayload(
                    price: incomingPayload.price,
                    label: incomingPayload.label ?? existingPayload.label,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex,
                    lineStyle: incomingPayload.lineStyle ?? existingPayload.lineStyle,
                    lineWidth: incomingPayload.lineWidth ?? existingPayload.lineWidth
                )
            )
        case let (.drawingZone(existingPayload), .drawingZone(incomingPayload)):
            return .drawingZone(
                ZonePayload(
                    topPrice: incomingPayload.topPrice,
                    bottomPrice: incomingPayload.bottomPrice,
                    startTime: incomingPayload.startTime,
                    endTime: incomingPayload.endTime,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex,
                    lineStyle: incomingPayload.lineStyle ?? existingPayload.lineStyle,
                    lineWidth: incomingPayload.lineWidth ?? existingPayload.lineWidth
                )
            )
        case let (.drawingPattern(existingPayload), .drawingPattern(incomingPayload)):
            return .drawingPattern(
                ChartPatternPayload(
                    patternKey: incomingPayload.patternKey,
                    title: incomingPayload.title,
                    points: incomingPayload.points,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex,
                    lineStyle: incomingPayload.lineStyle ?? existingPayload.lineStyle,
                    lineWidth: incomingPayload.lineWidth ?? existingPayload.lineWidth
                )
            )
        case let (.levelSupport(existingPayload), .levelSupport(incomingPayload)):
            return .levelSupport(
                LevelPayload(
                    price: incomingPayload.price,
                    label: incomingPayload.label ?? existingPayload.label,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex,
                    lineStyle: incomingPayload.lineStyle ?? existingPayload.lineStyle,
                    lineWidth: incomingPayload.lineWidth ?? existingPayload.lineWidth
                )
            )
        case let (.levelResistance(existingPayload), .levelResistance(incomingPayload)):
            return .levelResistance(
                LevelPayload(
                    price: incomingPayload.price,
                    label: incomingPayload.label ?? existingPayload.label,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex,
                    lineStyle: incomingPayload.lineStyle ?? existingPayload.lineStyle,
                    lineWidth: incomingPayload.lineWidth ?? existingPayload.lineWidth
                )
            )
        case let (.note(existingPayload), .note(incomingPayload)):
            return .note(
                anchoredNotePayload(
                    text: incomingPayload.text,
                    offsetX: incomingPayload.offsetX ?? existingPayload.offsetX,
                    offsetY: incomingPayload.offsetY ?? existingPayload.offsetY,
                    preserving: existingPayload
                )
            )
        case let (.reactionEmoji(existingPayload), .reactionEmoji(incomingPayload)):
            return .reactionEmoji(
                anchoredEmojiPayload(
                    emoji: incomingPayload.emoji,
                    offsetX: incomingPayload.offsetX ?? existingPayload.offsetX,
                    offsetY: incomingPayload.offsetY ?? existingPayload.offsetY,
                    preserving: existingPayload
                )
            )
        default:
            return incoming
        }
    }

    private func purgeIncompatibleComponents(for intent: RLMarkerIntent) {
        let allowed = allowedComponentTypes(for: intent)
        components.removeAll { draft in
            draft.componentType != .anchor && !allowed.contains(draft.componentType)
        }
        drawingColorOverrides = drawingColorOverrides.filter { draftId, _ in
            components.contains(where: { $0.id == draftId })
        }
    }

    private func normalizedHexColor(_ hex: String?) -> String? {
        guard var raw = hex?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if !raw.hasPrefix("#") {
            raw = "#\(raw)"
        }

        guard Color(hex: raw) != nil else { return nil }
        return raw.uppercased()
    }

    private func normalizedDrawingColorHex(from payload: MarkerComponentPayload) -> String? {
        switch payload {
        case let .levelSupport(value):
            return normalizedHexColor(value.colorHex)
        case let .levelResistance(value):
            return normalizedHexColor(value.colorHex)
        case let .drawingTrendline(value):
            return normalizedHexColor(value.colorHex)
        case let .drawingHorizontalLine(value):
            return normalizedHexColor(value.colorHex)
        case let .drawingZone(value):
            return normalizedHexColor(value.colorHex)
        case let .drawingPattern(value):
            return normalizedHexColor(value.colorHex)
        case let .note(value):
            return normalizedHexColor(value.colorHex)
        default:
            return nil
        }
    }

    private func allowedComponentTypes(for intent: RLMarkerIntent) -> Set<RLComponentType> {
        let drawingAndIndicators: Set<RLComponentType> = [.drawingTrendline, .drawingHorizontalLine, .drawingZone, .drawingPattern, .indicator]

        switch intent {
        case .analysis:
            return Set<RLComponentType>([.anchor, .levelSupport, .levelResistance, .textNote, .timeframeLink, .linkURL])
                .union(drawingAndIndicators)
        case .setup:
            return Set<RLComponentType>([.anchor, .levelEntry, .levelSl, .levelTp, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        case .news:
            return Set<RLComponentType>([.anchor, .textNote, .timeframeLink, .linkURL])
                .union(drawingAndIndicators)
        case .poll, .question:
            return Set<RLComponentType>([.anchor, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        case .reaction:
            return Set<RLComponentType>([.anchor, .reactionEmoji, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        case .alert:
            return Set<RLComponentType>([.anchor, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        case .personal:
            return Set<RLComponentType>([.anchor, .levelSupport, .levelResistance, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        }
    }
}

struct MarkerPlacementMode: View {
    @ObservedObject var placementState: MarkerPlacementState
    let chartPreview: AnyView
    let onCancel: () -> Void
    let onPlace: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundColor(AppColors.primaryForeground)
                Spacer()
                Text("Placing Marker")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryForeground)
                Spacer()
                UnifiedMarkerBadge(
                    intent: placementState.intent,
                    alertSeverity: placementState.intent == .alert ? placementState.alertSeverity : nil,
                    sizeToken: .small
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            chartPreview
                .frame(height: 110)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.whiteText.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)

            MarkerPlacementPanel(
                placementState: placementState,
                onCancel: onCancel,
                onPlace: onPlace
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}
