import Foundation
import Testing
@testable import traders_guild

/// Cover for defects found by auditing my own implementation rather than by
/// working from the contract.
struct MarkerLinkSelfAuditTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        depth: Int = 0,
        responses: Int = 0
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
            authorUsername: "t\(key)",
            title: "Node \(key)",
            directResponseCount: responses,
            depth: depth
        )
    }

    private func page(
        requested: Int,
        windowRoot: String,
        nodes: [RLMarkerLinkPreviewDTO],
        branches: [RLMarkerThreadBranchDTO] = [],
        rootMarker: Int? = nil,
        rootKey: String? = nil,
        rootResolved: Bool = false,
        ancestorCursor: String? = nil
    ) -> RLMarkerThreadResponseDTO {
        RLMarkerThreadResponseDTO(
            requestedMarkerId: id(requested),
            rootMarkerId: rootMarker.map(id),
            rootKey: rootKey,
            rootResolved: rootResolved,
            windowRootKey: windowRoot,
            nodes: nodes,
            ancestorCursor: ancestorCursor,
            branches: branches,
            loadedCount: nodes.count
        )
    }

    // MARK: - Converging windows must not clobber each other

    /// A thesis opened from two different responses produces two provisional
    /// windows that later resolve the same root. Promotion used to overwrite
    /// whichever arrived first, discarding its accumulated pages and — worse —
    /// its live branch cursors, so a branch the reader had started paging
    /// became silently unreachable.
    @MainActor
    @Test
    func secondPromotionAbsorbsTheFirstWindowInsteadOfReplacingIt() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))

        // Reader opens response 2, ancestry resolves root 1, then pages a
        // branch under node c so the window accumulates real state.
        store.ingest(
            page: page(
                requested: 2,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 2),
                    node("b", parent: "root", marker: 2, depth: 1),
                    node("c", parent: "root", marker: 3, depth: 1, responses: 4),
                ],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "c", cursor: "c-page-1")],
                rootMarker: 1,
                rootKey: "root",
                rootResolved: true
            ),
            requestedMarkerId: id(2)
        )

        let first = store.window(forMarkerId: id(2))
        #expect(first?.loadedCount == 3)
        #expect(first?.branchCursor(for: "c") == "c-page-1")

        // Reader now opens response 9, which was in an unpaged branch and so
        // is not indexed. It arrives as its own window, resolving the same root.
        store.ingest(
            page: page(
                requested: 9,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 2),
                    node("z", parent: "root", marker: 9, depth: 1),
                ],
                rootMarker: 1,
                rootKey: "root",
                rootResolved: true
            ),
            requestedMarkerId: id(9)
        )

        let merged = store.window(forMarkerId: id(9))
        #expect(merged != nil)
        #expect(
            merged?.branchCursor(for: "c") == "c-page-1",
            "the first window's live branch cursor must survive the second promotion"
        )
        #expect(
            merged?.nodesByKey["b"] != nil,
            "nodes from the first window must survive"
        )
        #expect(merged?.nodesByKey["z"] != nil, "and the new node is present")
        #expect(merged?.loadedCount == 4)

        // Both markers now address the same window.
        #expect(store.sharesThesis(id(2), id(9)))
        #expect(store.cacheKey(forMarkerId: id(2)) == .confirmedRoot(id(1)))
    }

    /// Absorbing keeps the less advanced cursor when both windows hold one for
    /// the same node: a redundant page dedupes harmlessly, while an
    /// over-advanced cursor would skip siblings for good.
    @Test
    func absorbKeepsTheLessAdvancedCursor() {
        var advanced = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 5),
                    node("c1", parent: "root", marker: 11, depth: 1),
                    node("c2", parent: "root", marker: 12, depth: 1),
                ],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "page-3")]
            )
        )
        let behind = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 5)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "page-1")]
            )
        )

        advanced.absorb(behind)
        #expect(advanced.branchCursor(for: "root") == "page-1")
    }

    /// Absorbing must not claim ancestry is settled when the other window knows
    /// it is not.
    @Test
    func absorbKeepsOutstandingAncestry() {
        var settled = MarkerThreadWindow(
            page: page(requested: 1, windowRoot: "root", nodes: [node("root", marker: 1)])
        )
        #expect(!settled.hasMoreAncestry)

        let unsettled = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1)],
                ancestorCursor: "up"
            )
        )
        settled.absorb(unsettled)
        #expect(settled.hasMoreAncestry, "the window with further to walk decides")
    }

    // MARK: - Focus must not trust a lagging count

    /// `directResponseCount` lags by design — the reconciler exists because of
    /// it. A stale zero must not suppress focus on a marker whose responses are
    /// already on screen.
    @Test
    func staleZeroCountDoesNotSuppressFocus() {
        let graph = MarkerLinkGraph(nodes: [
            // Reported count is 0, but a child is loaded and points at it.
            MarkerLinkNode(id: id(1), directResponseCount: 0),
            MarkerLinkNode(
                id: id(2),
                parentId: id(1),
                relationship: MarkerLinkRelationshipValue(.supports)
            ),
        ])

        let focus = graph.focusState(selectedId: id(1), visibleIds: [id(1), id(2)])
        #expect(focus.isActive, "loaded topology counts, not just the reported figure")
        #expect(focus.candidateEdges.count == 1)
        #expect(focus.shouldFadeUnrelated)
        #expect(graph.isRoot(id(1)))
    }

    /// A genuinely standalone marker still gets no focus.
    @Test
    func genuinelyStandaloneMarkerStillGetsNoFocus() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 0),
            MarkerLinkNode(id: id(5), directResponseCount: 0),
        ])
        #expect(!graph.focusState(selectedId: id(1), visibleIds: [id(1), id(5)]).isActive)
    }

    // MARK: - Pending navigation cannot hijack a later selection

    /// Re-staging a target that never arrives used to renew itself on every
    /// load, so a marker that finally appeared minutes later could yank the
    /// user's selection. The expiry is measured from the original tap.
    @MainActor
    @Test
    func abandonedPendingNavigationExpires() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))

        let tapped = Date()
        store.stagePendingNavigation(markerId: id(7), now: tapped)

        // The marker has not loaded, so the manager re-stages on each attempt.
        store.stagePendingNavigation(markerId: id(7), now: tapped.addingTimeInterval(10))
        store.stagePendingNavigation(markerId: id(7), now: tapped.addingTimeInterval(20))

        // Still inside the window, measured from the tap.
        #expect(
            store.consumePendingNavigation(now: tapped.addingTimeInterval(25)) != nil
        )

        // Past the window it is abandoned, however many times it was re-staged.
        store.stagePendingNavigation(markerId: id(7), now: tapped)
        store.stagePendingNavigation(markerId: id(7), now: tapped.addingTimeInterval(29))
        #expect(
            store.consumePendingNavigation(now: tapped.addingTimeInterval(31)) == nil,
            "re-staging must not renew the expiry clock"
        )
    }

    /// A different target replaces the old one and starts its own clock.
    @MainActor
    @Test
    func stagingADifferentTargetResetsTheClock() {
        let store = MarkerThreadStore()
        let start = Date()
        store.stagePendingNavigation(markerId: id(7), now: start)
        store.stagePendingNavigation(markerId: id(8), now: start.addingTimeInterval(29))

        let pending = store.consumePendingNavigation(now: start.addingTimeInterval(31))
        #expect(pending?.markerId == id(8))
    }
}
