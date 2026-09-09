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
                revision: MarkerRevision.make(response.parentResponsesRevision)
            )
        )
    }

    /// Offer one absolute observation and write it through to a loaded marker.
    func applyResponseCount(_ update: MarkerResponseCountUpdate) {
        let outcome = responseCounts.apply(update)
        guard case .applied(let count) = outcome else { return }

        guard let index = markers.firstIndex(where: { $0.id == update.markerId }) else {
            // The marker is not loaded on this chart — the reconciler still
            // holds the value, so it applies the moment the marker arrives.
            return
        }
        markers[index] = markers[index].withMarker(
            markers[index].marker.updating(
                directResponseCount: count,
                responsesRevision: update.revision?.wireText
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
            guard let known = responseCounts.count(for: markerId),
                  known != markers[index].responseCount else { continue }
            markers[index] = markers[index].withMarker(
                marker.updating(
                    directResponseCount: known,
                    responsesRevision: responseCounts.revision(for: markerId)?.wireText
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
        guard known != dto.responseCount || knownRevision != dto.responsesRevision else {
            return dto
        }
        return dto.updating(
            directResponseCount: known,
            responsesRevision: knownRevision
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

    private func invalidateThreads(markerId: UUID?, parentMarkerId: UUID?, symbolId: UUID?) {
        guard let store = threadStore else { return }

        var matched = false
        if let markerId {
            matched = store.invalidateThesis(containing: markerId)
        }
        if let parentMarkerId {
            // Deliberately not short-circuited: a marker and its parent can sit
            // in two separately cached windows, and both are now stale.
            matched = store.invalidateThesis(containing: parentMarkerId) || matched
        }
        guard !matched else { return }

        store.invalidateTheses(onSymbolId: symbolId)
    }

    /// Merge a broadcast marker without adopting somebody else's identity.
    ///
    /// A realtime payload is built with the *creator's* viewer context and sent
    /// verbatim to the whole guild, so its permission flags describe whoever
    /// acted, not whoever is reading. Adopting them hands every recipient the
    /// creator's Edit and Delete affordances on a marker that is not theirs.
    /// Its engagement flags are equally wrong: they would clear this viewer's
    /// own like and poll vote.
    ///
    /// So two different repairs, for two different reasons:
    ///
    /// - **Engagement is preserved** from the loaded copy. Only this client
    ///   knows what this viewer has liked or voted for; the payload cannot.
    /// - **Permissions are re-derived** from the authenticated user and their
    ///   membership in the current guild. Preserving them would be wrong too —
    ///   the loaded copy predates the update — and trusting the payload is what
    ///   leaks authorship. Only local derivation is correct in both directions.
    ///
    /// The backend does personalise per recipient on some paths. This does not
    /// depend on that, because the paths that matter here demonstrably do not.
    func neutralMerge(_ incoming: RLChartMarkerDTO, into existing: RLChartMarkerDTO) -> RLChartMarkerDTO {
        let isMine = incoming.author.userId == userId
        return incoming.updating(
            isLikedByCurrentUser: existing.isLikedByCurrentUser,
            // Nested per-viewer state the top-level vote field does not cover:
            // the counts are authoritative, the `hasVoted` flags are not.
            pollOptions: mergedPollOptions(incoming: incoming, existing: existing),
            userPollVote: existing.userPollVote,
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
    /// Matched by option id rather than position: an edited poll can reorder or
    /// drop options, and carrying a flag across by index would attribute the
    /// viewer's vote to an option they never chose.
    private func mergedPollOptions(
        incoming: RLChartMarkerDTO,
        existing: RLChartMarkerDTO
    ) -> [RLPollOptionDTO]? {
        guard let incomingOptions = incoming.pollOptions else { return nil }
        guard let existingOptions = existing.pollOptions else { return incomingOptions }
        let voted = Set(existingOptions.filter(\.hasVoted).map(\.id))
        guard !voted.isEmpty else { return incomingOptions }
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
