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
}

struct MarkerPlacementChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let isRequired: Bool
    let isComplete: Bool
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
    /// Placement-local color overrides for drawing drafts (trendline/zone).
    /// Phase 3 persists these into payload/back-end fields.
    @Published var drawingColorOverrides: [UUID: String] = [:]
    @Published var drawingInteractionPhase: DrawingInteractionPhase = .idle
    @Published var pendingDrawingFirstPoint: (time: Date, price: Double)?
    @Published var editingDrawingId: UUID?

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

    var estimatedTrackingRepLoss: Int? {
        guard trackingEnabled, let riskPips = setupRiskPips else { return nil }
        return clampedRepEstimate(Int(riskPips.rounded()), minimum: 5, maximum: 60)
    }

    var estimatedTrackingRepGain: Int? {
        guard trackingEnabled, let rewardPips = setupRewardPips else { return nil }
        return clampedRepEstimate(Int(rewardPips.rounded()), minimum: 5, maximum: 120)
    }

    var placementChecklistItems: [MarkerPlacementChecklistItem] {
        var items: [MarkerPlacementChecklistItem] = [
            checklistItem(
                id: "anchor",
                title: "Anchor placed on chart",
                isRequired: true,
                isComplete: anchorDraft != nil
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
                    title: "Enable tracking for reputation impact",
                    isRequired: false,
                    isComplete: trackingEnabled
                )
            )

        case .analysis:
            items.append(
                checklistItem(
                    id: "analysis_note",
                    title: "Add analysis context",
                    isRequired: false,
                    isComplete: !trimmedNote.isEmpty
                )
            )
            items.append(
                checklistItem(
                    id: "analysis_structure",
                    title: "Add support/resistance or drawing",
                    isRequired: false,
                    isComplete: hasStructuredAnalysisComponents
                )
            )

        case .alert:
            items.append(
                checklistItem(
                    id: "alert_severity",
                    title: "Select alert severity",
                    isRequired: false,
                    isComplete: alertSeverity != nil
                )
            )
            items.append(
                checklistItem(
                    id: "alert_context",
                    title: "Add alert context",
                    isRequired: false,
                    isComplete: !trimmedNote.isEmpty
                )
            )

        case .question:
            items.append(
                checklistItem(
                    id: "question_required",
                    title: "Question text provided",
                    isRequired: true,
                    isComplete: !trimmedNote.isEmpty
                )
            )
            items.append(
                checklistItem(
                    id: "question_recommendation",
                    title: "Add a drawing for context",
                    isRequired: false,
                    isComplete: drawingOverlayCount > 0
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
                    isRequired: false,
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
                isComplete: isValid
            )
        )

        return items
    }

    private let maxIndicatorPanels = 2
    private let maxDrawingOverlays = 15
    private let maxTimeframeLinks = 2

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

        if intent == .question {
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if intent == .poll {
            let validOptions = pollOptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return !pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validOptions.count >= 2
        }

        if intent == .reaction {
            guard case let .reactionEmoji(payload)? = component(.reactionEmoji)?.payload else {
                return false
            }
            return !payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if intent == .setup && trackingEnabled {
            guard
                let entry = anchorDraft?.payload.levelPrice,
                let sl = componentPrice(.levelSl),
                let tp = componentPrice(.levelTp)
            else {
                return false
            }
            let isLong = tp > entry && sl < entry
            let isShort = tp < entry && sl > entry
            return isLong || isShort
        }

        return true
    }

    func reset(to intent: RLMarkerIntent, anchorTime: Date, anchorPrice: Double) {
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
                    payload: .reactionEmoji(EmojiPayload(emoji: "🎯"))
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
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(EmojiPayload(emoji: "🎯")))
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
        if isIndicatorAttached(named: name) {
            return true
        }
        if isPanelIndicator(name) {
            return canAddIndicator
        }
        return true
    }

    @discardableResult
    func upsertIndicator(
        name: String,
        settings: [String: AnyCodable]?
    ) -> Bool {
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
            components[index].payload = .indicator(payload)
        } else {
            components.append(
                MarkerComponentDraft(componentType: .indicator, payload: .indicator(payload))
            )
        }

        return true
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
            components[index].payload = .timeframeLink(
                TimeframeLinkPayload(timeframe: trimmedTimeframe, note: note)
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

    func upsertComponent(_ componentType: RLComponentType, payload: MarkerComponentPayload) {
        if componentType == .indicator {
            guard case let .indicator(indicatorPayload) = payload else { return }
            _ = upsertIndicator(
                name: indicatorPayload.name,
                settings: indicatorPayload.settings
            )
            return
        }

        if let index = components.firstIndex(where: { $0.componentType == componentType }) {
            components[index].payload = mergedDrawingAnnotationPayload(
                existing: components[index].payload,
                incoming: payload
            )
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
        components.removeAll { $0.componentType == componentType }
        for id in removedIDs {
            drawingColorOverrides.removeValue(forKey: id)
        }
    }

    func removeComponent(id: UUID) {
        guard let draft = components.first(where: { $0.id == id }),
              draft.componentType != .anchor else {
            return
        }
        components.removeAll { $0.id == id }
        drawingColorOverrides.removeValue(forKey: id)
    }

    func updateComponent(id: UUID, payload: MarkerComponentPayload) {
        guard let index = components.firstIndex(where: { $0.id == id }) else { return }
        components[index].payload = payload
        if let normalized = normalizedDrawingColorHex(from: payload) {
            drawingColorOverrides[id] = normalized
        } else if components[index].componentType.isDrawing {
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
            components[index].payload = .drawingTrendline(
                TrendlinePayload(
                    startTime: payload.startTime,
                    startPrice: payload.startPrice,
                    endTime: payload.endTime,
                    endPrice: payload.endPrice,
                    colorHex: normalized
                )
            )
        case let .drawingZone(payload):
            components[index].payload = .drawingZone(
                ZonePayload(
                    topPrice: payload.topPrice,
                    bottomPrice: payload.bottomPrice,
                    startTime: payload.startTime,
                    endTime: payload.endTime,
                    colorHex: normalized
                )
            )
        default:
            break
        }
    }

    func drawingColorHex(for draftId: UUID) -> String? {
        if let overrideHex = drawingColorOverrides[draftId] {
            return overrideHex
        }
        guard let draft = components.first(where: { $0.id == draftId }) else { return nil }
        return normalizedDrawingColorHex(from: draft.payload)
    }

    func drawingColor(for draftId: UUID, fallback: Color) -> Color {
        guard let hex = drawingColorHex(for: draftId),
              let resolved = Color(hex: hex) else {
            return fallback
        }
        return resolved
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

    func resetDrawingInteraction() {
        drawingInteractionPhase = .idle
        pendingDrawingFirstPoint = nil
        editingDrawingId = nil
    }

    func beginTrendlinePlacement() {
        activeTool = .draw
        activeSubTool = MarkerToolOption.drawTrendline.rawValue
        drawingInteractionPhase = .placingFirstPoint
        pendingDrawingFirstPoint = nil
        editingDrawingId = nil
    }

    func beginZonePlacement() {
        activeTool = .draw
        activeSubTool = MarkerToolOption.drawZone.rawValue
        drawingInteractionPhase = .placingFirstPoint
        pendingDrawingFirstPoint = nil
        editingDrawingId = nil
    }

    func beginEditingDrawing(_ draftId: UUID) {
        drawingInteractionPhase = .editing
        editingDrawingId = draftId
        pendingDrawingFirstPoint = nil
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
            return [.drawTrendline, .drawZone]
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
            let value = componentPrice(.levelSupport) ?? anchorPrice
            upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: value, label: "Support")))
        case .levelResistance:
            let value = componentPrice(.levelResistance) ?? anchorPrice
            upsertComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: value, label: "Resistance")))
        case .drawTrendline:
            break
        case .drawZone:
            break
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
            upsertComponent(.textNote, payload: .note(NotePayload(text: text)))
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
            upsertComponent(.textNote, payload: .note(NotePayload(text: text)))
        case .styleEmojiIdea:
            if component(.reactionEmoji) == nil && !canAddDrawing {
                return
            }
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(EmojiPayload(emoji: "🎯")))
        case .styleEmojiFire:
            if component(.reactionEmoji) == nil && !canAddDrawing {
                return
            }
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(EmojiPayload(emoji: "🔥")))
        case .styleEmojiBearish:
            if component(.reactionEmoji) == nil && !canAddDrawing {
                return
            }
            upsertComponent(.reactionEmoji, payload: .reactionEmoji(EmojiPayload(emoji: "🐻")))
        }
    }

    func buildCreateRequest(symbolId: UUID, timeframe: String) -> RLCreateMarkerRequest {
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

        let requestComponents = orderedDrafts.map { draft in
            RLMarkerComponentRequest(
                componentType: draft.componentType.rawValue,
                payload: draft.payload.rawPayload
            )
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPollQuestion = pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPollOptions = pollOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let resolvedVisibility = intent == .personal ? "private" : "guild"
        let resolvedConfidence: Int? = nil

        return RLCreateMarkerRequest(
            symbolId: symbolId,
            timeframe: timeframe,
            intent: intent.rawValue,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            visibility: resolvedVisibility,
            confidence: resolvedConfidence,
            trackingEnabled: trackingEnabled,
            components: requestComponents,
            pollQuestion: intent == .poll ? (trimmedPollQuestion.isEmpty ? nil : trimmedPollQuestion) : nil,
            pollOptions: intent == .poll ? normalizedPollOptions : nil
        )
    }

    private func componentOrderingRank(_ type: RLComponentType) -> Int {
        switch type {
        case .anchor:
            return 0
        case .levelEntry, .levelSl, .levelTp, .levelSupport, .levelResistance:
            return 1
        case .drawingTrendline, .drawingZone:
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

    private func clampedRepEstimate(_ value: Int, minimum: Int, maximum: Int) -> Int {
        min(maximum, max(minimum, value))
    }

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPollQuestion: String {
        pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
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
        if !newsURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        guard case let .link(payload)? = component(.linkURL)?.payload else {
            return false
        }
        return !payload.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasStructuredAnalysisComponents: Bool {
        component(.levelSupport) != nil
            || component(.levelResistance) != nil
            || drawingOverlayCount > 0
            || indicatorPanelCount > 0
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

    private func checklistItem(id: String, title: String, isRequired: Bool, isComplete: Bool) -> MarkerPlacementChecklistItem {
        MarkerPlacementChecklistItem(id: id, title: title, isRequired: isRequired, isComplete: isComplete)
    }

    private func isDrawingOverlayComponent(_ componentType: RLComponentType) -> Bool {
        if componentType == .reactionEmoji {
            return intent != .reaction
        }
        return componentType.isDrawing || componentType == .textNote
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
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex
                )
            )
        case let (.drawingZone(existingPayload), .drawingZone(incomingPayload)):
            return .drawingZone(
                ZonePayload(
                    topPrice: incomingPayload.topPrice,
                    bottomPrice: incomingPayload.bottomPrice,
                    startTime: incomingPayload.startTime,
                    endTime: incomingPayload.endTime,
                    colorHex: incomingPayload.colorHex ?? existingPayload.colorHex
                )
            )
        case let (.note(existingPayload), .note(incomingPayload)):
            return .note(
                NotePayload(
                    text: incomingPayload.text,
                    offsetX: incomingPayload.offsetX ?? existingPayload.offsetX,
                    offsetY: incomingPayload.offsetY ?? existingPayload.offsetY
                )
            )
        case let (.reactionEmoji(existingPayload), .reactionEmoji(incomingPayload)):
            return .reactionEmoji(
                EmojiPayload(
                    emoji: incomingPayload.emoji,
                    offsetX: incomingPayload.offsetX ?? existingPayload.offsetX,
                    offsetY: incomingPayload.offsetY ?? existingPayload.offsetY
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
        case let .drawingTrendline(value):
            return normalizedHexColor(value.colorHex)
        case let .drawingZone(value):
            return normalizedHexColor(value.colorHex)
        default:
            return nil
        }
    }

    private func allowedComponentTypes(for intent: RLMarkerIntent) -> Set<RLComponentType> {
        let drawingAndIndicators: Set<RLComponentType> = [.drawingTrendline, .drawingZone, .indicator]

        switch intent {
        case .analysis:
            return Set<RLComponentType>([.anchor, .levelSupport, .levelResistance, .textNote, .reactionEmoji, .timeframeLink, .linkURL])
                .union(drawingAndIndicators)
        case .setup:
            return Set<RLComponentType>([.anchor, .levelEntry, .levelSl, .levelTp, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .news:
            return Set<RLComponentType>([.anchor, .textNote, .reactionEmoji, .timeframeLink, .linkURL])
                .union(drawingAndIndicators)
        case .poll, .question:
            return Set<RLComponentType>([.anchor, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .reaction:
            return Set<RLComponentType>([.anchor, .reactionEmoji, .textNote, .timeframeLink])
                .union(drawingAndIndicators)
        case .alert:
            return Set<RLComponentType>([.anchor, .textNote, .reactionEmoji, .timeframeLink])
                .union(drawingAndIndicators)
        case .personal:
            return Set<RLComponentType>([.anchor, .levelSupport, .levelResistance, .textNote, .reactionEmoji, .timeframeLink])
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
                    .foregroundColor(.white)
                Spacer()
                Text("Placing Marker")
                    .font(.headline)
                    .foregroundColor(.white)
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
