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
    var focusVisibleIds: Set<UUID> {
        Set(filteredMarkers.map(\.id))
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

        let shouldFade: Bool
        if let latch = fadeLatch, latch.selectionId == selected.id {
            shouldFade = latch.shouldFade
        } else {
            shouldFade = state.shouldFadeUnrelated
            setFadeLatch(selectionId: selected.id, shouldFade: shouldFade)
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
            // Not loaded yet — put it back for the next load to pick up.
            store.stagePendingNavigation(markerId: pending.markerId)
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
