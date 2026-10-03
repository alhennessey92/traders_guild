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
import SwiftUI

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
    /// Every saved component, in saved order, with its payload exactly as
    /// the server sent it. When the components are replaced, each one goes
    /// back as it was unless the author changed it — see
    /// `guidedEditRequestComponents()`.
    let components: [MarkerGuidedEditComponent]
    /// False if the hydrated drafts could not be matched to the saved
    /// components one for one. The edit then fails closed for components:
    /// text can still be saved, but a context or level change is refused
    /// rather than sent in a form that could lose saved data.
    let componentsMatched: Bool
    /// The tracked-Setup states in which the server refuses component edits.
    static let componentLockedStates: Set<RLTrackingState> = [.active, .tpHit, .slHit, .expired]

    /// Levels, context and tracking are fixed: a tracked Setup past ARMED.
    var isSetupLocked: Bool {
        intent == .setup && trackingEnabled && trackingState.map(Self.componentLockedStates.contains) == true
    }
}

extension MarkerComponentPayload {
    /// The level, for a level component; nil otherwise.
    var guidedLevelPayload: LevelPayload? {
        switch self {
        case .levelEntry(let level), .levelTp(let level), .levelSl(let level),
             .levelSupport(let level), .levelResistance(let level):
            return level
        default:
            return nil
        }
    }
}

/// A saved component, for a guided edit.
struct MarkerGuidedEditComponent {
    let componentType: String
    /// The payload as the server sent it.
    let raw: [String: Any]
    /// The draft hydrated from it; nil for a type this build cannot read.
    let draftID: UUID?
    /// That draft's typed payload as hydrated: what "changed" is measured
    /// against.
    let hydrated: [String: Any]?

    var request: RLMarkerComponentRequest {
        RLMarkerComponentRequest(componentType: componentType, payload: MarkerRawPayload.wrap(raw))
    }
}

/// JSON-shaped payload helpers for preserving what this build does not model.
enum MarkerRawPayload {
    static func unwrap(_ payload: [String: AnyCodable]) -> [String: Any] {
        payload.mapValues(\.value)
    }

    static func wrap(_ payload: [String: Any]) -> [String: AnyCodable] {
        payload.mapValues { AnyCodable($0) }
    }

    /// The same JSON value (keys sorted; 63920 and 63920.0 alike).
    static func same(_ lhs: Any?, _ rhs: Any?) -> Bool {
        canonical(lhs) == canonical(rhs)
    }

    private static func canonical(_ value: Any?) -> String? {
        guard let value else { return nil }
        let encodable = AnyCodable(value)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode([encodable])).map { String(decoding: $0, as: UTF8.self) }
    }

    /// The saved payload with only the author's changes applied: a field
    /// whose modelled value did not change keeps its saved value; a changed
    /// one takes the new value (objects merged key by key, the same way); a
    /// modelled field that is gone is removed. Unmodelled keys are untouched.
    static func merge(saved: [String: Any], before: [String: Any], after: [String: Any]) -> [String: Any] {
        var merged = saved
        for key in Set(before.keys).union(after.keys) {
            let old = before[key]
            let new = after[key]
            guard !same(old, new) else { continue }
            guard let new, !(new is NSNull) else {
                merged.removeValue(forKey: key)
                continue
            }
            if let newObject = new as? [String: Any],
               let oldObject = old as? [String: Any],
               let savedObject = saved[key] as? [String: Any] {
                merged[key] = merge(saved: savedObject, before: oldObject, after: newObject)
            } else {
                merged[key] = new
            }
        }
        return merged
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
        let matched = matchSavedComponents(of: marker)
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
            components: matched.components,
            componentsMatched: matched.matched
        )
    }

    /// Pair each saved component with the draft `beginEditingMarker` made for
    /// it. That hydration keeps the saved order (ordering, then id), skips
    /// types this build cannot read, and adds an anchor first only if the
    /// marker had none — so the readable ones match the drafts one for one.
    private func matchSavedComponents(of marker: ChartMarkerUI) -> (components: [MarkerGuidedEditComponent], matched: Bool) {
        let saved = marker.components.sorted {
            if $0.ordering != $1.ordering { return $0.ordering < $1.ordering }
            return $0.id.uuidString < $1.id.uuidString
        }
        let readable = saved.filter { $0.componentTypeEnum != nil }
        // 0, or 1 for an anchor hydration added; anything else (including a
        // negative difference) is unverifiable and never used to index.
        let offset = components.count - readable.count
        let offsetIsValid = offset == 0
            || (offset == 1 && components.first?.componentType == .anchor
                && !readable.contains { $0.componentTypeEnum == .anchor })
        let matched = offsetIsValid
            && zip(components.dropFirst(offset), readable).allSatisfy { $0.componentType == $1.componentTypeEnum }
        var draftIndex = offset
        let paired = saved.map { component -> MarkerGuidedEditComponent in
            let raw = MarkerRawPayload.unwrap(component.originalRawPayload ?? component.payload.rawPayload)
            guard matched, component.componentTypeEnum != nil else {
                return MarkerGuidedEditComponent(componentType: component.componentType, raw: raw, draftID: nil, hydrated: nil)
            }
            let draft = components[draftIndex]
            draftIndex += 1
            return MarkerGuidedEditComponent(
                componentType: component.componentType,
                raw: raw,
                draftID: draft.id,
                hydrated: MarkerRawPayload.unwrap(draft.payload.rawPayload)
            )
        }
        return (paired, matched)
    }

    /// The components for a guided update, in saved order:
    /// - a component the author did not touch goes back exactly as saved,
    ///   unmodelled keys and all (so the anchor and a Setup's Entry are exact)
    /// - an edited one is the saved payload with only the fields the author
    ///   changed replaced, nested objects merged the same way, and a modelled
    ///   field the author cleared removed
    /// - one the author removed is not sent, and so is deleted
    /// - a type this build cannot read goes back as saved, where it was
    /// - anything the author added follows, as the editor built it
    func guidedEditRequestComponents() -> [RLMarkerComponentRequest] {
        guard let original = guidedEditOriginal, original.componentsMatched else { return [] }
        var requests: [RLMarkerComponentRequest] = []
        var accounted = Set<UUID>()
        for saved in original.components {
            guard let draftID = saved.draftID, let hydrated = saved.hydrated else {
                requests.append(saved.request)
                continue
            }
            guard let draft = components.first(where: { $0.id == draftID }),
                  draft.componentType.rawValue == saved.componentType else {
                continue  // removed (or replaced by another type): not sent
            }
            accounted.insert(draftID)
            let now = MarkerRawPayload.unwrap(draft.payload.rawPayload)
            if MarkerRawPayload.same(now, hydrated) {
                requests.append(saved.request)
            } else {
                requests.append(RLMarkerComponentRequest(
                    componentType: saved.componentType,
                    payload: MarkerRawPayload.wrap(MarkerRawPayload.merge(saved: saved.raw, before: hydrated, after: now))
                ))
            }
        }
        for draft in components where !accounted.contains(draft.id) {
            requests.append(RLMarkerComponentRequest(componentType: draft.componentType.rawValue, payload: draft.payload.rawPayload))
        }
        return requests
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

    /// The guided level fields' binding: typing a price changes the price
    /// and nothing else — a saved label, colour or style stays as it was.
    /// With no level of that type yet it adds one as the shared binding does.
    func guidedLevelPriceBinding(for type: RLComponentType) -> Binding<Double> {
        let shared = levelPriceBinding(for: type)
        return Binding<Double>(
            get: { shared.wrappedValue },
            set: { newValue in
                guard let index = self.components.firstIndex(where: { $0.componentType == type }),
                      let existing = self.components[index].payload.guidedLevelPayload else {
                    shared.wrappedValue = newValue
                    return
                }
                let repriced = LevelPayload(
                    price: newValue, label: existing.label, colorHex: existing.colorHex,
                    lineStyle: existing.lineStyle, lineWidth: existing.lineWidth
                )
                let payload: MarkerComponentPayload
                switch type {
                case .levelTp: payload = .levelTp(repriced)
                case .levelSl: payload = .levelSl(repriced)
                case .levelEntry: payload = .levelEntry(repriced)
                case .levelSupport: payload = .levelSupport(repriced)
                case .levelResistance: payload = .levelResistance(repriced)
                default:
                    shared.wrappedValue = newValue
                    return
                }
                // One assignment, so observers see a single change.
                var updated = self.components
                updated[index].payload = payload
                self.components = updated
            }
        )
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
            && !guidedEditComponentChangeRefused
    }

    /// The saved components could not be matched safely, and the author
    /// changed context or levels: the save is refused, the draft kept.
    var guidedEditComponentChangeRefused: Bool {
        guard let original = guidedEditOriginal, !original.componentsMatched, !isGuidedEditLocked else { return false }
        return guidedEditComponentsChanged
    }

    static let guidedEditComponentChangeRefusedMessage =
        "This marker's chart context can't be changed safely in this version. Undo the context or level change to save your text."

    // MARK: The update

    /// The PUT body for this edit: only what changed. A cleared title or
    /// thesis is sent as `null` so the server clears it. The type, link and
    /// visibility are never sent. Components go only when the author changed
    /// context or levels on a Setup the server still lets change — then all
    /// of them, each untouched one exactly as saved
    /// (`guidedEditRequestComponents`). Tracking goes only when it was
    /// switched on an editable Setup.
    func buildGuidedUpdateRequest() -> RLUpdateMarkerRequest {
        guard let original = guidedEditOriginal else { return buildUpdateRequest() }
        let now = draftFingerprint()
        let titleChanged = now.title != original.title
        let noteChanged = now.note != original.note
        let sendsComponents = !isGuidedEditLocked && guidedEditComponentsChanged
            && original.componentsMatched
        let sendsTracking = !isGuidedEditLocked && intent == .setup && trackingEnabled != original.trackingEnabled
        return RLUpdateMarkerRequest(
            intent: nil,
            title: titleChanged && !now.title.isEmpty ? now.title : nil,
            note: noteChanged && !now.note.isEmpty ? now.note : nil,
            visibility: nil,
            confidence: nil,
            trackingEnabled: sendsTracking ? trackingEnabled : nil,
            components: sendsComponents ? guidedEditRequestComponents() : nil,
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
