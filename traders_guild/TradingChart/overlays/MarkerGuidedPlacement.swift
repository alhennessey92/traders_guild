//
//  MarkerGuidedPlacement.swift
//  traders_guild
//
//  The v1.5 guided creation flow: Details → Review → Post, with optional
//  context. A second view onto `MarkerPlacementState`, never a second draft.
//

import Foundation

/// Where the guided panel is.
enum MarkerGuidedStep: Equatable {
    /// The creation hierarchy — social contribution, structured Setup, other
    /// types — reached from "Change type". The draft and any response session
    /// are kept.
    case chooseType
    /// Social (Analysis / Question) or Setup details.
    case details
    /// The existing component editors, opened from "Add context".
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

    /// Equal apart from levels, which are compared only where both drafts have
    /// them and within float noise: the chart re-syncs level prices, and a
    /// type change adds a Setup's defaults, neither of which the author did.
    func matches(_ other: MarkerDraftFingerprint) -> Bool {
        guard title == other.title,
              note == other.note,
              trackingEnabled == other.trackingEnabled,
              pollQuestion == other.pollQuestion,
              pollOptions == other.pollOptions,
              contextComponents == other.contextComponents else { return false }
        for (type, price) in setupLevels {
            guard let base = other.setupLevels[type] else { continue }
            if abs(price - base) > max(1e-9, abs(base) * 1e-7) { return false }
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

    /// The guided panel is showing, rather than the legacy tabs.
    var isGuidedFlowActive: Bool { guidedStep != nil }

    /// Analysis needs a chart component everywhere except the guided flow,
    /// where text alone is a post. The live backend only accepts that from
    /// Stage 4 (a local-DEV validation change); until then it refuses, and the
    /// guided Review shows the failure with the draft intact.
    var requiresAnalysisContext: Bool { !isGuidedFlowActive }

    // MARK: Lifecycle

    /// Choose the guided flow for the placement about to start. Called by an
    /// entry point before `startMarkerPlacement`; `reset` leaves it in place.
    func prepareGuidedFlow() {
        guidedStep = .details
        submissionPhase = .idle
        draftBaseline = nil
    }

    /// Placement ended, or the author chose a legacy type: back to the legacy
    /// panel.
    func endGuidedFlow() {
        guidedStep = nil
        submissionPhase = .idle
        draftBaseline = nil
    }

    // MARK: Navigation

    /// Details → Review, only when the draft could be posted.
    @discardableResult
    func continueToReview() -> Bool {
        guard guidedStep == .details, isValid else { return false }
        guidedStep = .review
        return true
    }

    func backToDetails() {
        guard isGuidedFlowActive else { return }
        guidedStep = .details
    }

    func openContext() {
        guard isGuidedFlowActive else { return }
        guidedStep = .context
    }

    func openTypeChooser() {
        guard isGuidedFlowActive else { return }
        guidedStep = .chooseType
    }

    /// Whether the details step is the social one (Analysis / Question) or
    /// Setup's.
    var isSocialDetails: Bool { intent == .analysis || intent == .question }

    /// The toolbar title for the guided step; a drawing tool's instruction
    /// still wins while one is active.
    var guidedToolbarTitle: String? {
        switch guidedStep {
        case .chooseType?: return "Change type"
        case .details?: return isSocialDetails ? "Post to the chart" : "Setup"
        case .context?: return "Add context"
        case .review?: return "Review"
        case nil: return nil
        }
    }

    /// The first thing still stopping this draft from being posted, for the
    /// Details step's primary button.
    var firstUnmetRequirementTitle: String? {
        unmetRequiredChecklistItems.first?.title
    }

    // MARK: Type changes

    /// Switch to `newIntent` from the guided flow. If that would remove
    /// components, nothing changes and the pending change is returned for the
    /// author to confirm; otherwise it is applied.
    ///
    /// The response session, text, title and compatible components all stay.
    func requestGuidedIntentChange(to newIntent: RLMarkerIntent) -> MarkerGuidedIntentChange? {
        guard newIntent != intent else { return nil }
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
        for id in change.incompatibleComponentIDs {
            removeComponent(id: id)
        }
        switchIntentKeepingDefaults(change.targetIntent)
    }

    /// `setIntent`, plus the one default a fresh placement of that type would
    /// have had: a Setup starts tracked, as it does from Structured → Setup.
    private func switchIntentKeepingDefaults(_ newIntent: RLMarkerIntent) {
        setIntent(newIntent)
        if newIntent == .setup {
            trackingEnabled = true
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

    /// Whether cancelling would throw away something the author did.
    var hasMaterialEdits: Bool {
        let now = draftFingerprint()
        guard let draftBaseline else {
            return !now.title.isEmpty || !now.note.isEmpty || !now.contextComponents.isEmpty
        }
        return !now.matches(draftBaseline)
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
    }

    static func submitCreate(
        request: RLCreateMarkerRequest,
        candleIndex: Int,
        candles: [RLCandleDTO],
        placementState: MarkerPlacementState,
        markerManager: MarkerManager,
        symbolTicker: String?
    ) async -> Outcome {
        placementState.submissionPhase = .submitting
        let result = await markerManager.addMarkerV2(
            request: request,
            candleIndex: candleIndex,
            candles: candles
        )

        switch result {
        case .success(let created):
            // Read before the session ends: the composer's Discord choice is
            // carried through so the prompt shows the post already went,
            // rather than offering to send a second copy.
            let postedTo = placementState.selectedDiscordChannelId.flatMap { id in
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
}
