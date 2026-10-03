//
//  MarkerGuidedEditing.swift
//  traders_guild
//
//  v1.5 guided editing: an existing Analysis, Question or Setup is edited in
//  the guided sheet (Details → Review → Save changes) under the avatar
//  prototype. The same `MarkerPlacementState`, seeded by `beginEditingMarker`;
//  the update is the existing PUT, sent with only what changed.
//
//  Server contract (chart-service `update_marker`, read from Sol's accepted
//  snapshot, not changed here):
//  - every field present in the body is applied, `null` included (a clear);
//    a field left out is unchanged
//  - `components`, when present, replace all of the marker's components and
//    must hold exactly one anchor
//  - components cannot change on a tracked Setup in ACTIVE, TP_HIT, SL_HIT or
//    EXPIRED (400 "Cannot edit components on a tracked setup after activation")
//  - `parent_marker_id` and `link_relationship` are refused: links are fixed
//

import Foundation

/// The marker as it stood when the guided edit began: what "changed" is
/// measured against, and what Review compares.
struct MarkerGuidedEditOriginal {
    let markerId: UUID
    let intent: RLMarkerIntent
    let title: String
    let note: String
    let trackingEnabled: Bool
    let trackingState: RLTrackingState?
    let fingerprint: MarkerDraftFingerprint
    /// "Supports alex's BTC breakout" — the fixed relationship, shown read-only.
    let linkSentence: String?
    /// Components whose type this client does not know. Hydration cannot
    /// carry them as drafts; they are sent back untouched whenever the
    /// components are replaced, so an edit never deletes them.
    let unrecognisedComponents: [RLMarkerComponentRequest]
    /// The tracked-Setup states in which the server refuses component edits.
    static let componentLockedStates: Set<RLTrackingState> = [.active, .tpHit, .slHit, .expired]

    /// Levels, context and tracking are fixed: a tracked Setup past ARMED.
    var isSetupLocked: Bool {
        intent == .setup && trackingEnabled && trackingState.map(Self.componentLockedStates.contains) == true
    }
}

extension MarkerPlacementState {

    /// The types the guided sheet edits, under the experiment. Everything
    /// else, and every edit with the experiment off, keeps the existing editor.
    static func usesGuidedEdit(
        for intent: RLMarkerIntent,
        experimentEnabled: Bool = MarkerAvatarExperiment.isEnabled
    ) -> Bool {
        experimentEnabled && [RLMarkerIntent.analysis, .question, .setup].contains(intent)
    }

    /// The guided sheet is editing an existing marker.
    var isGuidedEdit: Bool { isGuidedFlowActive && isEditingExistingMarker && guidedEditOriginal != nil }

    /// A tracked Setup past ARMED: only its title and thesis can change.
    var isGuidedEditLocked: Bool { isGuidedEdit && guidedEditOriginal?.isSetupLocked == true }

    /// Open the guided sheet on an edit. Called after `beginEditingMarker`
    /// (which hydrates the draft and ends any guided flow or link session)
    /// and before placement starts. The draft is the baseline: an untouched
    /// edit closes without asking.
    func prepareGuidedEdit(of marker: ChartMarkerUI) {
        guard isEditingExistingMarker, editingMarkerId == marker.id else { return }
        guidedStep = .details
        submissionPhase = .idle
        draftID = UUID()
        activeSubmissionID = nil
        let fingerprint = draftFingerprint()
        draftBaseline = fingerprint
        setupLevelSeed = fingerprint.setupLevels
        guidedEditOriginal = MarkerGuidedEditOriginal(
            markerId: marker.id,
            intent: marker.intent,
            title: fingerprint.title,
            note: fingerprint.note,
            trackingEnabled: marker.trackingEnabled,
            trackingState: marker.trackingState,
            fingerprint: fingerprint,
            linkSentence: Self.linkSentence(for: marker),
            unrecognisedComponents: marker.components
                .sorted { $0.ordering < $1.ordering }
                .filter { $0.componentTypeEnum == nil }
                .map { RLMarkerComponentRequest(componentType: $0.componentType, payload: $0.payload.rawPayload) }
        )
    }

    private static func linkSentence(for marker: ChartMarkerUI) -> String? {
        guard marker.isLinkedResponse else { return nil }
        let relationship = marker.linkRelationship?.known?.displayName ?? "Responds to"
        guard let parent = marker.parentPreview, !parent.isUnavailable else {
            return "\(relationship) a removed marker"
        }
        let author = parent.authorUsername ?? parent.authorDisplayName ?? "another member"
        if let title = parent.title, !title.isEmpty {
            return "\(relationship) \(author)'s \(title)"
        }
        return "\(relationship) \(author)'s marker"
    }

    // MARK: What changed

    /// Context or Setup levels differ from the marker's. The anchor is not
    /// editable here, so it never counts.
    var guidedEditComponentsChanged: Bool {
        guard let original = guidedEditOriginal else { return false }
        let now = draftFingerprint()
        return now.contextComponents != original.fingerprint.contextComponents
            || !MarkerDraftFingerprint.levelsMatch(now.setupLevels, original.fingerprint.setupLevels)
    }

    /// Anything the author can save differs from the marker.
    var guidedEditHasChanges: Bool {
        guard let original = guidedEditOriginal else { return false }
        let now = draftFingerprint()
        if now.title != original.title || now.note != original.note { return true }
        if isGuidedEditLocked { return false }
        return guidedEditComponentsChanged
            || (intent == .setup && trackingEnabled != original.trackingEnabled)
    }

    /// Save is available: a valid draft with a change, not already saving,
    /// and — for a tracked Setup that is still editable — levels in order.
    var canSaveGuidedEdit: Bool {
        isGuidedEdit && isValid && guidedEditHasChanges
            && !submissionPhase.isSubmitting && !guidedTrackedSetupLevelsNeedAdjusting
    }

    // MARK: The update

    /// The PUT body for this edit: only what changed. A cleared title or
    /// thesis is sent as `null` so the server clears it. The type, link and
    /// visibility are never sent. Components go only when the author changed
    /// context or levels on a Setup the server still lets change — then all
    /// of them, the Entry and anchor exactly as they were, plus any component
    /// this client cannot read. Tracking goes only when it was switched on an
    /// editable Setup.
    func buildGuidedUpdateRequest() -> RLUpdateMarkerRequest {
        guard let original = guidedEditOriginal else { return buildUpdateRequest() }
        let now = draftFingerprint()
        let titleChanged = now.title != original.title
        let noteChanged = now.note != original.note
        let sendsComponents = !isGuidedEditLocked && guidedEditComponentsChanged
        let sendsTracking = !isGuidedEditLocked && intent == .setup && trackingEnabled != original.trackingEnabled
        return RLUpdateMarkerRequest(
            intent: nil,
            title: titleChanged && !now.title.isEmpty ? now.title : nil,
            note: noteChanged && !now.note.isEmpty ? now.note : nil,
            visibility: nil,
            confidence: nil,
            trackingEnabled: sendsTracking ? trackingEnabled : nil,
            components: sendsComponents
                ? requestComponentsForCurrentState(rewritesSetupEntry: false) + original.unrecognisedComponents
                : nil,
            clearsTitle: titleChanged && now.title.isEmpty,
            clearsNote: noteChanged && now.note.isEmpty
        )
    }

    /// Review's "What changes", in plain words; empty when nothing does.
    var guidedEditChangeLines: [String] {
        guard let original = guidedEditOriginal else { return [] }
        let now = draftFingerprint()
        var lines: [String] = []
        func describe(_ name: String, from old: String, to new: String) {
            guard old != new else { return }
            if old.isEmpty { lines.append("\(name) added") }
            else if new.isEmpty { lines.append("\(name) removed") }
            else { lines.append("\(name) edited") }
        }
        describe("Title", from: original.title, to: now.title)
        describe(intent == .setup ? "Thesis" : (intent == .question ? "Question" : "Text"),
                 from: original.note, to: now.note)
        guard !isGuidedEditLocked else { return lines }
        for (type, name) in [(RLComponentType.levelTp, "Take Profit"), (.levelSl, "Stop Loss")] {
            let old = original.fingerprint.setupLevels[type]
            let new = now.setupLevels[type]
            if !MarkerDraftFingerprint.levelsMatch(old.map { [type: $0] } ?? [:], new.map { [type: $0] } ?? [:]) {
                lines.append("\(name) \(MarkerGuidedFormat.displayPrice(old)) → \(MarkerGuidedFormat.displayPrice(new))")
            }
        }
        if intent == .setup, trackingEnabled != original.trackingEnabled {
            lines.append(trackingEnabled ? "Tracking turned on" : "Tracking turned off")
        }
        if now.contextComponents != original.fingerprint.contextComponents {
            let before = MarkerGuidedFormat.contextSummary(contextDrafts(in: original.fingerprint)) ?? "none"
            let after = MarkerGuidedFormat.contextSummary(components) ?? "none"
            lines.append("Context: \(before) → \(after)")
        }
        return lines
    }

    /// Context drafts rebuilt from a fingerprint's "type|payload" keys, for
    /// counting only.
    private func contextDrafts(in fingerprint: MarkerDraftFingerprint) -> [MarkerComponentDraft] {
        fingerprint.contextComponents.compactMap { key in
            guard let raw = key.split(separator: "|", maxSplits: 1).first,
                  let type = RLComponentType(rawValue: String(raw)) else { return nil }
            return MarkerComponentDraft(componentType: type, payload: .unknown(type: type.rawValue, rawPayload: [:]))
        }
    }

    /// Why the Setup's levels are fixed, for the locked card.
    var guidedEditLockExplanation: String? {
        guard isGuidedEditLocked, let state = guidedEditOriginal?.trackingState else { return nil }
        let status = state == .active ? "is active" : "has finished (\(state.displayName))"
        return "This Setup \(status), so its levels, tracking and context can't change. You can still edit the title and thesis."
    }
}

// MARK: - Submission

extension MarkerPlacementSubmitter {
    struct UpdateOutcome {
        let result: MarkerPlacementSubmissionResult
        /// The edit was left, or replaced, while the save was in flight.
        /// Nothing was changed on the current draft; the caller must not end
        /// placement for it.
        var isStale: Bool = false
    }

    /// Save a guided edit through the existing update path
    /// (`MarkerManager.updateMarkerFromPlacement`: optimistic patch, server
    /// reconciliation, rollback on failure). Owned like a guided post: the
    /// draft and the attempt are remembered, and a completion for a draft that
    /// has gone changes nothing. No share prompt, link or creation follows.
    static func submitUpdate(
        placementState: MarkerPlacementState,
        markerManager: MarkerManager
    ) async -> UpdateOutcome {
        guard let markerId = placementState.editingMarkerId, placementState.isGuidedEdit else {
            return UpdateOutcome(result: .failure(.genericUpdateFailure))
        }
        let request = placementState.buildGuidedUpdateRequest()
        let draftID = placementState.draftID
        let submissionID = UUID()
        placementState.submissionPhase = .submitting
        placementState.activeSubmissionID = submissionID

        let result = await markerManager.updateMarkerFromPlacement(id: markerId, request: request)

        guard placementState.draftID == draftID,
              placementState.activeSubmissionID == submissionID else {
            return UpdateOutcome(result: result, isStale: true)
        }
        placementState.activeSubmissionID = nil
        switch result {
        case .success:
            placementState.submissionPhase = .idle
        case .failure(let failure):
            placementState.submissionPhase = .failed(failure.userMessage)
        }
        return UpdateOutcome(result: result)
    }
}
