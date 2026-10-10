//
//  MarkerGuidedPlacement.swift
//  traders_guild
//
//  The v1.5 guided creation flow: Details → Review → Post, with optional
//  context. A second view onto `MarkerPlacementState`, never a second draft.
//

import Foundation
import CoreGraphics

/// Where the guided panel is.
enum MarkerGuidedStep: Equatable {
    case details
    /// Nested destinations are stored in MarkerWorkspaceState.
    case context
    case review
}

/// The last submission's state, for the guided Review.
enum MarkerPlacementSubmissionPhase: Equatable {
    case idle
    case submitting
    /// The draft is untouched; the author can post again.
    case failed(String)

    var isSubmitting: Bool { self == .submitting }
}

/// What makes a draft worth confirming before it is thrown away: what the
/// author wrote, the context they attached, tracking, and where they put a
/// Setup's levels. The anchor's position is not in it — dropping the draft
/// loses nothing there that is not one drag to redo.
struct MarkerDraftFingerprint: Equatable {
    var title: String
    var note: String
    var trackingEnabled: Bool
    var pollQuestion: String
    var pollOptions: [String]
    /// Sorted "type|payload" for every component other than the anchor and a
    /// Setup's own levels.
    var contextComponents: [String]
    var setupLevels: [RLComponentType: Double]

    /// Equal in everything the author writes or attaches. Setup levels are
    /// judged separately, against where the chart seeded them
    /// (`MarkerPlacementState.setupLevelsEdited`).
    func matchesContent(_ other: MarkerDraftFingerprint) -> Bool {
        title == other.title
            && note == other.note
            && trackingEnabled == other.trackingEnabled
            && pollQuestion == other.pollQuestion
            && pollOptions == other.pollOptions
            && contextComponents == other.contextComponents
    }

    /// Same level types, and each within float noise — the chart re-syncs
    /// level prices through its line system.
    static func levelsMatch(_ lhs: [RLComponentType: Double], _ rhs: [RLComponentType: Double]) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else { return false }
        for (type, price) in lhs {
            guard let other = rhs[type] else { return false }
            if abs(price - other) > max(1e-9, abs(other) * 1e-7) { return false }
        }
        return true
    }
}

/// A type change that would remove components, waiting for the author to say
/// yes. Never applied silently.
struct MarkerGuidedIntentChange: Identifiable, Equatable {
    let id = UUID()
    let targetIntent: RLMarkerIntent
    let incompatibleComponentIDs: [UUID]
    /// "Support, Link" — the display names of what would go.
    let incompatibleSummary: String

    static func == (lhs: MarkerGuidedIntentChange, rhs: MarkerGuidedIntentChange) -> Bool {
        lhs.targetIntent == rhs.targetIntent && lhs.incompatibleComponentIDs == rhs.incompatibleComponentIDs
    }
}

extension MarkerPlacementState {

    /// Where the guided panel is, as the outer shell has always seen it:
    /// Details, Review, or somewhere in Context. `nil` is the legacy panel.
    /// The workspace session's route stack is the single source.
    var guidedStep: MarkerGuidedStep? {
        guard isGuidedFlowActive else { return nil }
        switch workspace.destination {
        case .details: return .details
        case .review: return .review
        default: return .context
        }
    }

    /// Analysis needs a chart component except where text alone is a post: the
    /// guided flow, and an edit the entry point allowed under the experiment.
    /// The backend accepts a text-only Analysis on create and update only from
    /// the Stage 4 local-DEV validation change; an older backend refuses, and
    /// the failure is shown with the draft intact.
    var requiresAnalysisContext: Bool {
        !(isGuidedFlowActive || (isEditingExistingMarker && textOnlyAnalysisEditAllowed))
    }

    // MARK: Setup levels

    /// A Setup draft's Entry as the chart's Entry line shows it: the Entry
    /// level. The anchor price is only a fallback — a linked Setup's anchor
    /// sits on the parent's candle and carries that candle's old price.
    var guidedSetupEntryPrice: Double? {
        guard intent == .setup else { return nil }
        return componentPrice(.levelEntry) ?? setupEntryPrice
    }

    /// Reward over risk, measured from `guidedSetupEntryPrice`.
    var guidedSetupRiskReward: Double? {
        guard
            let entry = guidedSetupEntryPrice,
            let sl = componentPrice(.levelSl),
            let tp = componentPrice(.levelTp)
        else { return nil }
        let risk = abs(sl - entry)
        guard risk > .ulpOfOne else { return nil }
        return abs(tp - entry) / risk
    }

    /// A tracked guided Setup is posted only with its Entry strictly between
    /// its stop and target, as the backend now requires. Untracked Setups and
    /// the legacy flow are unaffected.
    var guidedTrackedSetupLevelsNeedAdjusting: Bool {
        guard isGuidedFlowActive, intent == .setup, trackingEnabled, !isGuidedEditLocked else { return false }
        switch setupSide {
        case .long?, .short?: return false
        case .inconsistent?, .invalidPrice?, nil: return true
        }
    }

    /// Post / Retry: a postable draft, not already posting, and — for a
    /// tracked Setup — levels in order against the Entry shown.
    var canPostGuidedDraft: Bool {
        isValid && !submissionPhase.isSubmitting && !guidedTrackedSetupLevelsNeedAdjusting
    }

    /// Let the edit session that has just begun keep an Analysis text-only.
    /// Called by the edit entry point under the experiment, after
    /// `beginEditingMarker`; outside an edit session it does nothing.
    func allowTextOnlyAnalysisEdit() {
        guard isEditingExistingMarker else { return }
        textOnlyAnalysisEditAllowed = true
    }

    // MARK: Lifecycle

    /// Choose the guided flow for the placement about to start. Called by an
    /// entry point before `startMarkerPlacement`; `reset` leaves it in place.
    func prepareGuidedFlow() {
        guidedEditOriginal = nil
        workspace = MarkerWorkspaceState()
        isGuidedFlowActive = true
        trackingUnavailableReason = nil
        submissionPhase = .idle
        draftBaseline = nil
        draftID = UUID()
        activeSubmissionID = nil
    }

    /// Placement ended, or the author chose a legacy type: back to the legacy
    /// panel. A guided post still in flight is retired with the draft, so its
    /// completion cannot close or alter whatever comes next.
    func endGuidedFlow() {
        guidedEditOriginal = nil
        workspace = MarkerWorkspaceState()
        isGuidedFlowActive = false
        trackingUnavailableReason = nil
        submissionPhase = .idle
        draftBaseline = nil
        setupLevelSeed = nil
        draftID = UUID()
        activeSubmissionID = nil
    }

    /// A guided post is on its way. Until it answers, the draft it sent is
    /// frozen: no navigation, no type change, and no discarding.
    var isGuidedSubmissionInFlight: Bool {
        isGuidedFlowActive && submissionPhase.isSubmitting
    }

    // MARK: Navigation

    /// The Details step's Review button: a postable draft, levels in order
    /// for a tracked Setup, and — for an edit — something changed.
    var canContinueToReview: Bool {
        isValid && !guidedTrackedSetupLevelsNeedAdjusting && !workspaceHasInvalidLevelInput
            && (!isGuidedEdit || (guidedEditHasChanges && !guidedEditComponentChangeRefused))
    }

    /// Compatibility for old fixture callers. Setup now remains on Details;
    /// its reasoning is on the same scrolling surface.
    var canContinueToSetupReasoning: Bool {
        intent == .setup && isValid && !guidedTrackedSetupLevelsNeedAdjusting
    }

    @discardableResult
    func continueToSetupReasoning() -> Bool {
        guard guidedStep == .details, canContinueToSetupReasoning, !isGuidedSubmissionInFlight else { return false }
        return true
    }

    /// Details (or a Setup's reasoning) → Review, only when the draft could
    /// be posted.
    @discardableResult
    func continueToReview() -> Bool {
        guard guidedStep == .details,
              canContinueToReview, !isGuidedSubmissionInFlight else { return false }
        workspace.path.append(.review)
        return true
    }

    /// One screen back, to where this one was opened from: Review → Details;
    /// a Context screen → the screen beneath it (Cancel for an editor).
    func goBack() {
        guard isGuidedFlowActive, !isGuidedSubmissionInFlight else { return }
        switch guidedStep {
        case .review?:
            if workspace.path.count > 1 { workspace.path.removeLast() }
        case .context?:
            cancelWorkspaceEditor()
        case .details?, nil:
            break
        }
    }

    /// Straight back to Details, from Details or Review (a type change, or
    /// a refused post's levels to adjust).
    func backToDetails() {
        guard isGuidedFlowActive, !isGuidedSubmissionInFlight else { return }
        workspace.path = [.details]
    }

    func openContext() {
        guard isGuidedFlowActive, !isGuidedSubmissionInFlight else { return }
        openWorkspace(.context)
    }

    func openTypeChooser() {
        // An edit keeps its type.
        guard isGuidedFlowActive, !isGuidedSubmissionInFlight, !isGuidedEdit else { return }
        workspace.path = [.details]
    }

    /// Whether the details step is the social one (Analysis / Question) or
    /// Setup's.
    var isSocialDetails: Bool { intent == .analysis || intent == .question }

    /// The toolbar title for the guided flow: the task as a whole. The sheet
    /// names the step, so the two never repeat each other. A drawing tool's
    /// instruction still wins while one is active.
    var guidedToolbarTitle: String? {
        switch guidedStep {
        case .details?, .context?, .review?:
            if isGuidedEdit { return "Edit \(intent.displayName)" }
            return linkSession.isActive ? "New response" : "New \(intent.displayName)"
        case nil: return nil
        }
    }

    /// Under the avatar prototype an edit is titled as one ("Edit Analysis")
    /// rather than "Place a Marker". Nil otherwise, leaving the legacy title.
    func editToolbarTitle(experimentEnabled: Bool = MarkerAvatarExperiment.isEnabled) -> String? {
        guard experimentEnabled, isEditingExistingMarker else { return nil }
        return "Edit \(intent.displayName)"
    }

    /// The first thing still stopping this draft from being posted, for the
    /// Details step's primary button.
    var firstUnmetRequirementTitle: String? {
        unmetRequiredChecklistItems.first?.title
    }

    /// What the author does next, in plain words, while Review is not yet
    /// available; nil once the draft can be reviewed. Shown beside the
    /// disabled Review button so the reason is never a guess.
    var guidedNextStepPrompt: String? {
        guard guidedStep == .details else { return nil }
        // A response's timeframe holds Review back while it loads, and after
        // it fails to.
        if isChangingResponseTimeframe {
            return "Loading the response timeframe…"
        }
        if responseTimeframeLoadFailed {
            return "Choose a response timeframe that loads"
        }
        if workspaceHasInvalidLevelInput { return "Check your prices" }
        if guidedEditComponentChangeRefused {
            return Self.guidedEditComponentChangeRefusedMessage
        }
        // A Setup is always valid; a tracked one is held back by the level
        // guard instead, so its prompt names what the guard is waiting for.
        if guidedTrackedSetupLevelsNeedAdjusting {
            if componentPrice(.levelTp) == nil || componentPrice(.levelSl) == nil {
                return "Set a take profit and a stop loss"
            }
            return setupSide == .inconsistent ? setupLevelsStraddlePrompt : "Check your prices"
        }
        // A locked Setup's levels are not this edit's to fix.
        let unmetItems = isGuidedEditLocked
            ? unmetRequiredChecklistItems.filter { !$0.id.hasPrefix("setup_") }
            : unmetRequiredChecklistItems
        guard let unmet = unmetItems.first else {
            // Review requires an actual change for every saved type.
            return isGuidedEdit && !guidedEditHasChanges ? "Make a change to review it" : nil
        }
        switch unmet.id {
        case "anchor":
            return "Place your marker on the chart"
        case "analysis_note":
            return "Write your analysis to continue"
        case "question_required":
            let remaining = max(1, MarkerPlacementRequirements.minimumContextCharacters - trimmedQuestionNote.count)
            return trimmedQuestionNote.isEmpty
                ? "Write your question to continue"
                : "Write \(remaining) more character\(remaining == 1 ? "" : "s")"
        case "setup_levels_required":
            return "Set a take profit and a stop loss"
        case "setup_direction_required":
            return setupLevelsStraddlePrompt
        default:
            return unmet.title
        }
    }

    /// The stop and target must sit either side of Entry, and Entry is not the
    /// author's to move: on a new Setup it is the live price (refreshed by each
    /// new candle and again at Post), on an edit the saved one. So the prompt
    /// says where Entry is rather than asking to move it (owner, 10 Oct: tight
    /// levels on BTC 5m read as wrongly refused when the price drifted).
    var setupLevelsStraddlePrompt: String {
        let price = MarkerGuidedFormat.displayPrice(guidedSetupEntryPrice)
        return isGuidedEdit
            ? "Keep your stop and target either side of Entry, \(price)"
            : "Price is \(price): keep your stop and target either side"
    }

    /// Retained for fixture/test callers. The product header has no step track.
    var guidedStepNumber: Int? {
        switch guidedStep {
        case .details?: return 1
        case .review?: return guidedStepCount
        case .context?, nil: return nil
        }
    }

    /// Every guided draft goes from Details to Review.
    var guidedStepCount: Int { 2 }

    /// The step's prompt, as a question the author can answer.
    var guidedStepPrompt: String? {
        if isGuidedEdit {
            switch guidedStep {
            case .details?: return "Edit your \(intent == .setup ? "Setup" : intent.displayName.lowercased())"
            case .context?: return "Edit chart context"
            case .review?: return "Check your changes"
            case nil: return nil
            }
        }
        switch guidedStep {
        case .details?:
            switch intent {
            case .question: return "What do you want to ask?"
            case .setup: return "Plan your trade"
            default: return linkSession.isActive ? "What's your view?" : "What are you seeing?"
            }
        case .context?: return "Add chart context"
        case .review?: return "Check your post"
        case nil: return nil
        }
    }

    // MARK: Type changes

    /// Switch to `newIntent` from the guided flow. If that would remove
    /// components, nothing changes and the pending change is returned for the
    /// author to confirm; otherwise it is applied.
    ///
    /// The response session, text, title and compatible components all stay.
    func requestGuidedIntentChange(to newIntent: RLMarkerIntent) -> MarkerGuidedIntentChange? {
        // An edit keeps its type.
        guard newIntent != intent, !isGuidedSubmissionInFlight, !isGuidedEdit else { return nil }
        let incompatible = incompatibleComponents(for: newIntent)
        guard incompatible.isEmpty else {
            let names = Array(Set(incompatible.map(\.componentType.displayName))).sorted()
            return MarkerGuidedIntentChange(
                targetIntent: newIntent,
                incompatibleComponentIDs: incompatible.map(\.id),
                incompatibleSummary: names.joined(separator: ", ")
            )
        }
        switchIntentKeepingDefaults(newIntent)
        return nil
    }

    /// The author confirmed: remove exactly what they were told about, then
    /// switch.
    func applyGuidedIntentChange(_ change: MarkerGuidedIntentChange) {
        guard !isGuidedSubmissionInFlight, !isGuidedEdit else { return }
        for id in change.incompatibleComponentIDs {
            removeComponent(id: id)
        }
        switchIntentKeepingDefaults(change.targetIntent)
    }

    /// `setIntent`, plus the one default a fresh placement of that type would
    /// have had: a Setup starts tracked, as it does from Structured → Setup.
    private func switchIntentKeepingDefaults(_ newIntent: RLMarkerIntent) {
        if intent == .setup || newIntent == .setup { workspace.levelInputs = [:] }
        setIntent(newIntent)
        if newIntent == .setup {
            trackingEnabled = trackingUnavailableReason == nil
        }
    }

    // MARK: Draft edits

    func draftFingerprint() -> MarkerDraftFingerprint {
        let setupLevelTypes: Set<RLComponentType> = [.levelEntry, .levelTp, .levelSl]
        let context = components
            .filter { $0.componentType != .anchor && !setupLevelTypes.contains($0.componentType) }
            .map { "\($0.componentType.rawValue)|\(Self.payloadKey($0.payload))" }
            .sorted()
        var levels: [RLComponentType: Double] = [:]
        for type in setupLevelTypes {
            if let price = componentPrice(type) { levels[type] = price }
        }
        return MarkerDraftFingerprint(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            trackingEnabled: trackingEnabled,
            pollQuestion: pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
            pollOptions: pollOptions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            contextComponents: context,
            setupLevels: levels
        )
    }

    /// Remember the draft as placement set it up.
    func captureDraftBaseline() {
        draftBaseline = draftFingerprint()
    }

    /// Remember where the chart just put a Setup's levels. Called by the chart
    /// whenever it seeds them — a new Setup, or a draft changing to Setup — and
    /// only then, so the author's later moves are what differ from it.
    func recordSetupLevelSeed() {
        setupLevelSeed = draftFingerprint().setupLevels
    }

    /// Whether the Setup levels differ from where the chart last seeded them:
    /// a moved price, or a level added or removed. Without a seed the draft's
    /// starting levels are the reference.
    var setupLevelsEdited: Bool {
        let reference = setupLevelSeed ?? draftBaseline?.setupLevels ?? [:]
        return !MarkerDraftFingerprint.levelsMatch(draftFingerprint().setupLevels, reference)
    }

    /// Whether cancelling would throw away something the author did.
    var hasMaterialEdits: Bool {
        let now = draftFingerprint()
        guard let draftBaseline else {
            return !now.title.isEmpty || !now.note.isEmpty || !now.contextComponents.isEmpty
                || setupLevelsEdited
        }
        return !now.matchesContent(draftBaseline) || setupLevelsEdited
    }

    private static func payloadKey(_ payload: MarkerComponentPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload.rawPayload) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Submission

/// Creating a marker from placement state: one path for the chart and for
/// tests, which drive it with a fixture transport.
///
/// Extracted from `TradingChartView.placeMarkerFromState` without changing
/// what it does: success ends the response session and yields the context the
/// existing share prompt is presented with; failure keeps the draft and the
/// response session, and records why. Presentation — leaving placement,
/// haptics, the toast, posting the share prompt — stays with the chart.
@MainActor
enum MarkerPlacementSubmitter {
    struct Outcome {
        let result: MarkerPlacementSubmissionResult
        /// For the share prompt: set for a guild-visible marker only.
        let shareContext: MarkerShareContext?
        /// A guided post whose draft was left, or replaced, while it was in
        /// flight. Nothing was changed on the current draft; the caller must
        /// not end placement or present anything for it.
        var isStale: Bool = false
    }

    static func submitCreate(
        request: RLCreateMarkerRequest,
        candleIndex: Int,
        candles: [RLCandleDTO],
        placementState: MarkerPlacementState,
        markerManager: MarkerManager,
        symbolTicker: String?
    ) async -> Outcome {
        // A guided submission carries the identity of the draft it posted and
        // snapshots what the share prompt needs, so a completion that arrives
        // after the author has left cannot close, alter or mislabel a later
        // draft. The legacy flow keeps its behaviour exactly.
        let isGuided = placementState.isGuidedFlowActive

        // A guided tracked Setup is checked as it will be sent — after its
        // Entry moved to the latest price — and not sent at all if its Entry
        // no longer sits between stop and target. The draft, its link and its
        // timeframe stay as they are; no exit is moved. Nothing here is marked
        // as submitting, so nothing is left pending.
        if isGuided, trackedSetupLevelsOutOfOrder(in: request) {
            let failure = MarkerPlacementFailure.trackedSetupLevelsOutOfOrder
            placementState.linkSession.recordFailure(failure.toastTitle)
            placementState.submissionPhase = .failed(failure.userMessage)
            return Outcome(result: .failure(failure), shareContext: nil)
        }

        let draftID = placementState.draftID
        let submissionID = UUID()
        let postedToAtSubmission: String? = isGuided
            ? request.discordChannelId.flatMap { id in
                placementState.discordChannels.first { $0.id == id }?.displayLabel
            }
            : nil

        placementState.submissionPhase = .submitting
        if isGuided { placementState.activeSubmissionID = submissionID }

        let result = await markerManager.addMarkerV2(
            request: request,
            candleIndex: candleIndex,
            candles: candles
        )

        if isGuided {
            guard placementState.draftID == draftID,
                  placementState.activeSubmissionID == submissionID else {
                return Outcome(result: result, shareContext: nil, isStale: true)
            }
            placementState.activeSubmissionID = nil
        }

        switch result {
        case .success(let created):
            // The legacy flow reads the composer's Discord choice now, as it
            // always has; the guided flow uses what it sent. Either way the
            // prompt shows the post already went rather than offering to send
            // a second copy.
            let postedTo = isGuided
                ? postedToAtSubmission
                : placementState.selectedDiscordChannelId.flatMap { id in
                    placementState.discordChannels.first { $0.id == id }?.displayLabel
                }
            placementState.endLinkSession(.submitted)
            placementState.submissionPhase = .idle
            guard let created, created.visibility == "guild" else {
                return Outcome(result: result, shareContext: nil)
            }
            return Outcome(
                result: result,
                shareContext: MarkerShareContext(
                    marker: created,
                    symbolTicker: symbolTicker,
                    isCurrentUserMarker: true,
                    postedToDiscord: postedTo
                )
            )
        case .failure(let failure):
            // The link survives a failed submission so the author can retry
            // without rebuilding the response from scratch.
            placementState.linkSession.recordFailure(failure.toastTitle)
            placementState.submissionPhase = .failed(failure.userMessage)
            return Outcome(result: result, shareContext: nil)
        }
    }

    /// A tracked Setup request whose Entry, SL and TP — as sent — are not
    /// exactly one finite price each, ordered SL < Entry < TP or
    /// TP < Entry < SL: the backend's rule, read with the same side inference
    /// as the Setup editor.
    static func trackedSetupLevelsOutOfOrder(in request: RLCreateMarkerRequest) -> Bool {
        guard request.intent == RLMarkerIntent.setup.rawValue, request.trackingEnabled else { return false }
        func price(_ type: RLComponentType) -> Double? {
            let matches = request.components.filter { $0.componentType == type.rawValue }
            guard matches.count == 1, let match = matches.first else { return nil }
            return MarkerComponentPayload.decode(componentType: match.componentType, rawPayload: match.payload).levelPrice
        }
        switch MarkerSetupSide.of(entry: price(.levelEntry), takeProfit: price(.levelTp), stopLoss: price(.levelSl)) {
        case .long?, .short?: return false
        case .inconsistent?, .invalidPrice?, nil: return true
        }
    }
}
