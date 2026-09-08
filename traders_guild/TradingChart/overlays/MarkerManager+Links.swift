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

    /// Ring treatment for one marker, or nil when it wears none.
    func linkRingStyle(for markerId: UUID) -> MarkerLinkRingStyle? {
        guard linkedMarkersEnabled, let focus = linkFocus, focus.memberIds.contains(markerId) else {
            return nil
        }
        return linkGraph.ringStyle(for: markerId)
    }

    /// Whether a marker should be drawn at the reduced opacity.
    func isDimmedByLinkFocus(_ markerId: UUID) -> Bool {
        guard let focus = linkFocus, focus.shouldFadeUnrelated else { return false }
        return !focus.memberIds.contains(markerId)
    }

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
                revision: response.parentResponsesRevision
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
                responsesRevision: update.revision
            )
        )
        if selectedMarker?.id == update.markerId {
            selectedMarker = markers[index]
        }
        refreshLinkFocus()
    }

    /// Reconcile a freshly loaded marker against counts we already know to be
    /// newer, so a stale list payload cannot roll a badge backwards.
    func reconcileLoadedCounts() {
        guard !responseCounts.isEmpty else { return }
        for index in markers.indices {
            let markerId = markers[index].id
            guard let known = responseCounts.count(for: markerId),
                  known != markers[index].responseCount else { continue }
            markers[index] = markers[index].withMarker(
                markers[index].marker.updating(
                    directResponseCount: known,
                    responsesRevision: responseCounts.revision(for: markerId)
                )
            )
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
