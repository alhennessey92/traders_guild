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
        let shouldFade: Bool
        if let latch = fadeLatch, latch.selectionId == selected.id {
            shouldFade = latch.shouldFade
        } else {
            shouldFade = state.shouldFadeUnrelated
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

    /// Conservative partial invalidation for a marker event.
    ///
    /// A created or updated marker changes a thesis the viewer may be reading —
    /// including branches not yet loaded, whose counts and tombstones the server
    /// would now render differently. The thesis containing either the marker or
    /// its parent is dropped; unrelated theses are untouched.
    func invalidateThreadsTouched(by dto: RLChartMarkerDTO) {
        guard let store = threadStore else { return }
        store.invalidateThesis(containing: dto.id)
        if let parentId = dto.parentMarkerId {
            store.invalidateThesis(containing: parentId)
        }
    }

    /// Merge a broadcast marker without losing this viewer's own state.
    ///
    /// Broadcast payloads are actor-neutral, so their engagement and permission
    /// flags describe nobody in particular. Replacing a loaded marker wholesale
    /// would clear the viewer's own like and poll vote. The backend also
    /// personalises per recipient, but this build must not depend on that.
    func neutralMerge(_ incoming: RLChartMarkerDTO, into existing: RLChartMarkerDTO) -> RLChartMarkerDTO {
        incoming.updating(
            isLikedByCurrentUser: existing.isLikedByCurrentUser,
            userPollVote: existing.userPollVote
        )
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
