//
//  MarkerManager+Links.swift
//  traders_guild
//
//  Linked-marker behaviour on the marker manager: focus derivation, count
//  reconciliation, and thread paging.
//

import Foundation

extension MarkerManager {

    // MARK: - Focus

    /// Markers currently eligible to be drawn — already through the intent and
    /// visibility-mode filters. Viewport culling happens later in the renderer,
    /// so this is the widest honest definition of "on screen".
    /// Markers the renderer actually painted this frame.
    ///
    /// Set by the chart after viewport culling. The fade rule asks whether at
    /// least two members of the thesis are *visible*, and `filteredMarkers`
    /// answers a different question — it includes markers scrolled far off
    /// screen, so the rule would dim the chart around a lone glyph whose only
    /// companion is a thousand candles away.
    var focusVisibleIds: Set<UUID> {
        renderedMarkerIds ?? Set(filteredMarkers.map(\.id))
    }

    var linkGraph: MarkerLinkGraph {
        MarkerLinkGraph(nodes: markers.map(\.linkNode))
    }

    /// Recompute focus for the current selection.
    ///
    /// Runs synchronously off loaded markers — never a network round-trip — so
    /// a selection can never leave the chart half-dimmed waiting on a request.
    /// The fade decision is latched per selection: progressive thread pages and
    /// realtime arrivals change how many members are visible, and re-evaluating
    /// would toggle the dim on and off underneath the user.
    func refreshLinkFocus() {
        guard linkedMarkersEnabled, let selected = selectedMarker else {
            linkFocus = nil
            clearFadeLatch()
            return
        }

        let state = linkGraph.focusState(selectedId: selected.id, visibleIds: focusVisibleIds)

        guard state.isActive else {
            linkFocus = nil
            clearFadeLatch()
            return
        }

        // The latch exists so progressive pages cannot flicker the dim, but it
        // must not capture a guess. Until the renderer has reported which
        // members it painted for THIS selection, the visible set is a fallback,
        // and latching it would freeze the wrong answer for the whole selection.
        //
        // It also must not outlive the fact it was derived from. "Suppress the
        // fade below two visible members" is an invariant of the design, not a
        // preference the latch may override: panning a second member off screen
        // has to undim the chart, or a lone glyph sits in a darkened chart with
        // nothing to compare it to. So a latched decision is still floored by
        // the current threshold — the latch may suppress a fade, never resurrect
        // one. `reportRenderedMarkers` drops the latch outright when the painted
        // set changes, so this floor is a second line rather than the only one.
        let meetsVisibilityThreshold = state.shouldFadeUnrelated
        let shouldFade: Bool
        if let latch = fadeLatch, latch.selectionId == selected.id {
            shouldFade = latch.shouldFade && meetsVisibilityThreshold
        } else {
            shouldFade = meetsVisibilityThreshold
            if renderedMarkerIds != nil {
                setFadeLatch(selectionId: selected.id, shouldFade: shouldFade)
            }
        }

        linkFocus = MarkerFocusState(
            selectedId: state.selectedId,
            memberIds: state.memberIds,
            visibleMemberIds: state.visibleMemberIds,
            shouldFadeUnrelated: shouldFade,
            candidateEdges: state.candidateEdges
        )
    }

    // Ring style and dim state are deliberately *not* exposed here. The
    // renderer derives both from `MarkerLinkRenderContext`, and a second copy
    // of the same decision on the manager is how the two drift apart.

    // MARK: - Count reconciliation

    /// Apply every absolute count an incoming marker payload carries.
    ///
    /// Deliberately called *before* the symbol/timeframe guards in the realtime
    /// handlers: a response placed on the 1h chart still changes the badge on a
    /// parent the viewer is looking at on the 5m chart, and an early return
    /// would drop that correction entirely.
    /// Absolute counts ride on every marker payload, not just creations.
    ///
    /// `marker_updated`, tracking snapshots and list hydration all carry them,
    /// and skipping those paths left a badge stale until the next create.
    func applyLinkCounts(from dto: RLChartMarkerDTO) {
        if let parentUpdate = dto.parentCountUpdate {
            applyResponseCount(parentUpdate)
        }
        if let ownUpdate = dto.ownCountUpdate {
            applyResponseCount(ownUpdate)
        }
    }

    func applyLinkCounts(fromDeletion payload: MarkerDeletedPayload) {
        guard let update = payload.parentCountUpdate else { return }
        applyResponseCount(update)
    }

    func applyLinkCounts(fromDeletion response: RLMarkerDeleteResponseDTO) {
        guard let parentId = response.parentMarkerId,
              let count = response.parentDirectResponseCount else { return }
        applyResponseCount(
            MarkerResponseCountUpdate(
                markerId: parentId,
                directResponseCount: count,
                revision: MarkerRevision.make(response.parentResponsesRevision),
                hasResponses: response.parentHasResponses
            )
        )
    }

    /// Offer one absolute observation and write it through to a loaded marker.
    func applyResponseCount(_ update: MarkerResponseCountUpdate) {
        let outcome = responseCounts.apply(update)
        // `.unchanged` still matters here. A soft delete of the only response
        // can leave the count where it was — zero to zero, when the parent had
        // already been corrected — while flipping the structural answer, and
        // that flip is the whole signal that the thesis survives.
        let count: Int
        switch outcome {
        case .applied(let value), .unchanged(let value):
            count = value
        case .stale:
            return
        }
        let structural = responseCounts.hasResponses(for: update.markerId)

        guard let index = markers.firstIndex(where: { $0.id == update.markerId }) else {
            // The marker is not loaded on this chart — the reconciler still
            // holds the value, so it applies the moment the marker arrives.
            return
        }
        guard count != markers[index].responseCount
                || structural != markers[index].marker.hasResponses else {
            return
        }
        markers[index] = markers[index].withMarker(
            markers[index].marker.updating(
                directResponseCount: count,
                responsesRevision: update.revision?.wireText,
                hasResponses: structural
            )
        )
        if selectedMarker?.id == update.markerId {
            selectedMarker = markers[index]
        }
        refreshLinkFocus()
    }

    /// Reconcile freshly loaded markers with the reconciler, in both directions.
    ///
    /// An HTTP list is an observation like any other, so it is *offered* rather
    /// than overwritten: a list newer than anything cached must win, and only a
    /// genuinely newer cached value may correct the list. Blindly writing the
    /// cache over the list rolled a newer server count backwards.
    func reconcileLoadedCounts() {
        for index in markers.indices {
            let marker = markers[index].marker
            let markerId = marker.id

            // Offer the list's own value first, with its revision, so a newer
            // list advances the reconciler instead of being discarded by it.
            if let listUpdate = marker.ownCountUpdate {
                responseCounts.apply(listUpdate)
            }

            // Then correct the row only if the reconciler now knows better.
            guard let known = responseCounts.count(for: markerId) else { continue }
            let structural = responseCounts.hasResponses(for: markerId)
            guard known != markers[index].responseCount
                    || structural != marker.hasResponses else { continue }
            markers[index] = markers[index].withMarker(
                marker.updating(
                    directResponseCount: known,
                    responsesRevision: responseCounts.revision(for: markerId)?.wireText,
                    hasResponses: structural
                )
            )
        }
    }

    /// Rewrite a payload's response count with the reconciler's accepted one.
    ///
    /// Offering a count and then storing the payload are two different acts,
    /// and the order they happen in is the whole problem. A `marker_updated` or
    /// tracking snapshot that arrives out of order is correctly *rejected* by
    /// the reconciler — it carries an older revision — and then written to the
    /// loaded marker anyway by the wholesale replacement that follows, putting
    /// the stale number straight back on the glyph and in the detail sheet. The
    /// reconciler's verdict has to survive the replacement, not just precede it.
    ///
    /// Only the count and its revision are touched; every other field on the
    /// payload is newer than what is loaded and is meant to win.
    func withReconciledCount(_ dto: RLChartMarkerDTO) -> RLChartMarkerDTO {
        guard let known = responseCounts.count(for: dto.id) else { return dto }
        let knownRevision = responseCounts.revision(for: dto.id)?.wireText
        // The reconciler only ever holds a structural answer a payload gave it,
        // so a nil here means nobody has said — leave the payload's own value
        // alone rather than blanking it.
        let knownStructural = responseCounts.hasResponses(for: dto.id) ?? dto.hasResponses
        guard known != dto.responseCount
                || knownRevision != dto.responsesRevision
                || knownStructural != dto.hasResponses else {
            return dto
        }
        return dto.updating(
            directResponseCount: known,
            responsesRevision: knownRevision,
            hasResponses: knownStructural
        )
    }

    /// Partial invalidation for a marker event, escalating when the cache
    /// cannot see the connection.
    ///
    /// A created or updated marker changes a thesis the viewer may be reading —
    /// including branches not yet loaded, whose counts and tombstones the server
    /// would now render differently. Dropping the thesis that contains the
    /// marker or its parent handles the common case.
    ///
    /// It is not sufficient on its own. When **neither** endpoint is indexed —
    /// a response created on a branch the viewer has never paged into, whose
    /// parent is likewise unloaded — matching by id finds nothing, and a window
    /// that is genuinely now stale would survive with no way to discover it,
    /// because nothing in it names the marker that changed. So an unmatched
    /// event escalates to dropping cached theses on that symbol, which a thesis
    /// can never leave.
    func invalidateThreadsTouched(by dto: RLChartMarkerDTO) {
        invalidateThreads(markerId: dto.id, parentMarkerId: dto.parentMarkerId, symbolId: dto.symbolId)
    }

    /// The deletion counterpart. A delete leaves a tombstone the server renders
    /// in place of the node, so an unmatched deletion is exactly as capable of
    /// staling a window as an unmatched creation.
    func invalidateThreadsTouched(byDeletionOf payload: MarkerDeletedPayload) {
        invalidateThreads(
            markerId: UUID(uuidString: payload.markerId),
            parentMarkerId: payload.parentMarkerId.flatMap(UUID.init(uuidString:)),
            symbolId: payload.symbolId.flatMap(UUID.init(uuidString:))
        )
    }

    /// The acknowledgement variant, for a delete the viewer performed themselves.
    ///
    /// The author never receives their own realtime event — the server
    /// suppresses the echo — so this HTTP acknowledgement is the *only* place
    /// their client learns the thesis changed. Without it the author is the one
    /// person who keeps seeing the pre-delete window.
    func invalidateThreadsTouched(byDeletionOf response: RLMarkerDeleteResponseDTO) {
        invalidateThreads(
            markerId: response.markerId,
            parentMarkerId: response.parentMarkerId,
            symbolId: response.symbolId
        )
    }

    private func invalidateThreads(markerId: UUID?, parentMarkerId: UUID?, symbolId: UUID?) {
        guard let store = threadStore else { return }
        // One call, one generation bump. The store decides what an event of this
        // shape could have staled; doing it in steps here published several
        // changes for a single event and made the disclosure re-read each time.
        store.invalidateForEvent(
            markerIds: [markerId, parentMarkerId].compactMap { $0 },
            symbolId: symbolId
        )
    }

    /// Merge a realtime marker without adopting somebody else's identity.
    ///
    /// The backend personalises delivery, so in normal operation a payload's
    /// viewer-relative fields already describe the recipient. This does not rely
    /// on that. Personalisation is a property of the current server, applied
    /// per delivery path, and a client that trusts it has no defence when one
    /// path changes: the failure is silent, and it shows another member's Edit
    /// and Delete affordances on a marker that is not theirs. Deriving locally
    /// costs nothing and cannot regress.
    ///
    /// Two repairs, for two different reasons:
    ///
    /// - **Engagement is preserved** from the loaded copy. Only this client
    ///   knows what this viewer has liked or voted for.
    /// - **Permissions are re-derived** from the authenticated user and their
    ///   membership in the current guild. Preserving them would be wrong too —
    ///   the loaded copy predates the update — so local derivation is the only
    ///   answer that is right in both directions.
    func neutralMerge(_ incoming: RLChartMarkerDTO, into existing: RLChartMarkerDTO) -> RLChartMarkerDTO {
        locallyPermissioned(incoming).updating(
            isLikedByCurrentUser: existing.isLikedByCurrentUser,
            // Nested per-viewer state the top-level vote field does not cover:
            // the counts are authoritative, the `hasVoted` flags are not.
            pollOptions: mergedPollOptions(incoming: incoming, existing: existing),
            userPollVote: existing.userPollVote
        )
    }

    /// A marker's permissions as they apply to *this* viewer.
    ///
    /// Used where there is no loaded copy to merge against — a newly created
    /// marker — and as the first half of `neutralMerge`.
    func locallyPermissioned(_ dto: RLChartMarkerDTO) -> RLChartMarkerDTO {
        let isMine = dto.author.userId == userId
        return dto.updating(
            isCurrentUserMarker: isMine,
            // Editing someone else's marker is refused server-side however
            // senior the viewer, so moderation does not widen this.
            canEdit: isMine,
            // Moderators and admins can remove other members' markers.
            canDelete: isMine || viewerCanModerate
        )
    }

    /// Incoming counts with this viewer's own `hasVoted` flags restored.
    ///
    /// Every flag is rewritten from the loaded copy, including the false ones,
    /// and including when this viewer has voted for nothing. Returning the
    /// incoming options untouched in that case would let a foreign `hasVoted`
    /// through — the exact leak this function exists to close — and "the viewer
    /// has no votes" is precisely when a stray true is most misleading.
    ///
    /// Matched by option id rather than position: an edited poll can reorder or
    /// drop options, and carrying a flag across by index would attribute the
    /// viewer's vote to an option they never chose.
    private func mergedPollOptions(
        incoming: RLChartMarkerDTO,
        existing: RLChartMarkerDTO
    ) -> [RLPollOptionDTO]? {
        guard let incomingOptions = incoming.pollOptions else { return nil }
        let voted = Set((existing.pollOptions ?? []).filter(\.hasVoted).map(\.id))
        return incomingOptions.map { option in
            RLPollOptionDTO(
                id: option.id,
                text: option.text,
                voteCount: option.voteCount,
                hasVoted: voted.contains(option.id)
            )
        }
    }

    // MARK: - Pending navigation

    /// Re-select a marker the user travelled to, once it has actually loaded.
    ///
    /// A symbol or timeframe change clears `markers` and `selectedMarker`
    /// wholesale (`activateLayoutContext`), so following a response onto another
    /// timeframe would otherwise centre the chart correctly and then leave
    /// nothing selected and no thesis focused. The staged target is honoured
    /// only within the generation that staged it.
    func restorePendingLinkSelection() {
        guard linkedMarkersEnabled, let store = threadStore else { return }
        guard let pending = store.consumePendingNavigation() else { return }
        guard let marker = markers.first(where: { $0.id == pending.markerId }) else {
            // Not loaded yet — put it back, carrying the ORIGINAL instant.
            // Consuming then re-staging with a fresh timestamp would restart the
            // expiry clock on every load and let an unreachable target wait
            // indefinitely, then hijack a much later selection.
            store.stagePendingNavigation(
                markerId: pending.markerId,
                preservingStagedAt: pending.stagedAt
            )
            return
        }
        selectedMarker = marker
    }

    // MARK: - Cross-timeframe jumps

    /// Badges the selected glyph wears for linked markers on other timeframes.
    ///
    /// Derived on read, not cached: the parent half is a field on the marker,
    /// and the response half appears on its own once the thesis window lands,
    /// which is exactly when the next frame should start showing it.
    var timeframeJumps: [MarkerTimeframeJump] {
        guard linkedMarkersEnabled,
              let selected = selectedMarker,
              let timeframe = currentTimeframe else { return [] }
        return MarkerTimeframeJumpResolver.jumps(
            for: selected,
            currentTimeframe: timeframe,
            thread: threadStore?.window(forMarkerId: selected.id)
        )
    }

    /// Fetch the selected marker's thesis window if a response badge could
    /// need it and nothing has loaded it yet.
    ///
    /// The sheet's disclosure normally fetches the same window and both go
    /// through the store, which refuses a page from a superseded generation;
    /// this just stops the badge depending on whether the sheet happened to be
    /// built. Only responded-to markers fetch — a leaf or an unlinked marker
    /// has no response to jump to.
    func loadThreadForTimeframeJumps() {
        timeframeJumpThreadTask?.cancel()
        timeframeJumpThreadTask = nil
        guard linkedMarkersEnabled,
              let selected = selectedMarker,
              selected.hasAnyResponses,
              let store = threadStore,
              store.window(forMarkerId: selected.id) == nil else { return }
        let markerId = selected.id
        let generation = store.generation
        timeframeJumpThreadTask = Task { @MainActor [weak self, weak store] in
            guard let self else { return }
            guard let page = try? await self.fetchThreadPage(markerId: markerId, cursor: nil),
                  !Task.isCancelled,
                  let store, store.generation == generation,
                  self.selectedMarker?.id == markerId else { return }
            _ = store.ingest(page: page, requestedMarkerId: markerId, expectedGeneration: generation)
            // Nothing observes the window itself; nudge the layer to redraw.
            self.objectWillChange.send()
        }
    }

    // MARK: - Thread paging

    /// Fetch one bounded window of a thesis.
    ///
    /// - Parameter cursor: continues either ancestry or a branch, depending on
    ///   which cursor it came from. `nil` requests the initial window.
    func fetchThreadPage(
        markerId: UUID,
        cursor: String? = nil
    ) async throws -> RLMarkerThreadResponseDTO {
        guard linkedMarkersEnabled else { throw MarkerLinkUnavailableError() }
        guard let api = markerAPI else { throw MarkerLinkUnavailableError() }
        return try await api.getMarkerThread(markerId: markerId, cursor: cursor)
    }
}
