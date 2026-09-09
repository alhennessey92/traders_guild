import Foundation
import Testing
@testable import traders_guild

/// Progressive thread accumulation.
struct MarkerThreadWindowTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        relationship: String? = "supports",
        depth: Int = 0,
        responses: Int = 0,
        unavailable: Bool = false,
        created: TimeInterval = 0
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: relationship,
            isUnavailable: unavailable,
            authorUsername: unavailable ? nil : "trader\(key)",
            title: unavailable ? nil : "Node \(key)",
            createdAt: unavailable ? nil : Date(timeIntervalSinceReferenceDate: created),
            directResponseCount: responses,
            depth: depth
        )
    }

    private func page(
        requested: Int,
        windowRoot: String,
        nodes: [RLMarkerLinkPreviewDTO],
        ancestorCursor: String? = nil,
        branches: [RLMarkerThreadBranchDTO] = [],
        totalCount: Int? = nil,
        rootMarker: Int? = nil,
        rootKey: String? = nil,
        rootResolved: Bool = false,
        truncated: Bool = false
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
            totalCount: totalCount,
            loadedCount: nodes.count,
            truncated: truncated
        )
    }

    // MARK: - Never overclaiming

    /// A page's `loadedCount` is not a whole-thesis total. Until ancestry has
    /// reached a real root and every branch is exhausted, the window may only
    /// report "at least".
    @Test
    func neverReportsAPageCountAsATotal() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 2,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 40),
                        node("b", parent: "a", marker: 2, depth: 1)],
                ancestorCursor: "more-ancestry",
                branches: [RLMarkerThreadBranchDTO(nodeKey: "a", cursor: "c1")]
            )
        )

        #expect(window.totalCount == .atLeast(2))
        #expect(!window.totalCount.isExact)
        #expect(window.totalCount.displayText == "2+")
        #expect(window.completeness == .ancestryPending)
    }

    /// Even with no ancestry left, an unresolved root keeps the window honest.
    @Test
    func rootStaysUnknownUntilAncestryReachesARealRoot() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 2,
                windowRoot: "b",
                nodes: [node("b", marker: 2)],
                ancestorCursor: "up"
            )
        )
        #expect(!window.rootResolved)
        #expect(window.rootMarkerId == nil)
        #expect(window.completeness == .ancestryPending)

        window.merge(
            page: page(
                requested: 2,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 1),
                        node("b", parent: "a", marker: 2, depth: 1)],
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true
            )
        )
        #expect(window.rootResolved)
        #expect(window.rootMarkerId == id(1))
        #expect(window.completeness == .complete)
    }

    /// Root identity latches: a later branch page that says nothing about the
    /// root must not un-resolve it.
    @Test
    func laterBranchPageDoesNotUnresolveTheRoot() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "a", cursor: "c1")],
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true
            )
        )
        #expect(window.rootResolved)

        window.merge(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("b", parent: "a", marker: 2, depth: 1)]
            )
        )
        #expect(window.rootResolved)
        #expect(window.rootMarkerId == id(1))
    }

    @Test
    func exactTotalOnlyWhenCompleteAndUntruncated() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 1),
                        node("b", parent: "a", marker: 2, depth: 1)],
                totalCount: 2,
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true
            )
        )
        #expect(window.totalCount == .exact(2))
        #expect(window.totalCount.displayText == "2")
    }

    @Test
    func truncatedWindowNeverReportsAnExactTotal() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil)],
                totalCount: 500,
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true,
                truncated: true
            )
        )
        #expect(!window.totalCount.isExact)
    }

    // MARK: - Merging

    @Test
    func mergesByNodeKeyRatherThanAppending() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 1),
                        node("b", parent: "a", marker: 2, depth: 1)]
            )
        )
        #expect(window.loadedCount == 2)

        // The same nodes again, with a fresher count on the root.
        window.merge(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 7),
                        node("b", parent: "a", marker: 2, depth: 1)]
            )
        )
        #expect(window.loadedCount == 2, "a re-sent node must not duplicate")
        #expect(window.nodesByKey["a"]?.directResponseCount == 7, "a re-sent node refreshes in place")

        let rows = window.displayRows()
        #expect(rows.map(\.node.nodeKey) == ["a", "b"], "sibling position survives replacement")
    }

    /// Branch pages report depths relative to their own window root. The merged
    /// tree must recompute depth from parentKey, or a deep branch renders flat.
    @Test
    func rebasesBranchPageDepthsByParentKey() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 1),
                        node("b", parent: "a", marker: 2, depth: 1)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "b", cursor: "cb")]
            )
        )

        // A branch page rooted at "b" reports its own children at depth 1.
        window.merge(
            page: page(
                requested: 1,
                windowRoot: "b",
                nodes: [node("c", parent: "b", marker: 3, depth: 1),
                        node("d", parent: "c", marker: 4, depth: 2)]
            )
        )

        let rows = window.displayRows()
        let byKey = Dictionary(uniqueKeysWithValues: rows.map { ($0.node.nodeKey, $0.depth) })
        #expect(byKey["a"] == 0)
        #expect(byKey["b"] == 1)
        #expect(byKey["c"] == 2, "page-relative depth 1 must rebase to 2 under b")
        #expect(byKey["d"] == 3)
    }

    /// A branch page must not drag the window root back down to itself.
    @Test
    func branchPageDoesNotLowerTheWindowRoot() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 2,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 1),
                        node("b", parent: "a", marker: 2, depth: 1)]
            )
        )
        window.merge(
            page: page(
                requested: 2,
                windowRoot: "b",
                nodes: [node("c", parent: "b", marker: 3, depth: 1)]
            )
        )
        #expect(window.windowRootKey == "a")
        #expect(window.displayRows().first?.node.nodeKey == "a")
    }

    /// An ancestry page introduces a higher root, and the window must adopt it.
    @Test
    func ancestryPageRaisesTheWindowRoot() {
        var window = MarkerThreadWindow(
            page: page(requested: 2, windowRoot: "b", nodes: [node("b", marker: 2)], ancestorCursor: "up")
        )
        window.merge(
            page: page(
                requested: 2,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 1),
                        node("b", parent: "a", marker: 2, depth: 1)],
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true
            )
        )
        #expect(window.windowRootKey == "a")
        #expect(window.displayRows().map(\.node.nodeKey) == ["a", "b"])
    }

    // MARK: - Cursors

    @Test
    func branchCursorSurvivesUntilTheServerStopsSendingIt() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "a", cursor: "page-1")]
            )
        )
        #expect(window.branchCursor(for: "a")?.cursor == "page-1")
        #expect(window.hasMoreBranches)

        // First continuation delivers one of two children and a replacement cursor.
        window.merge(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("b", parent: "a", marker: 2, depth: 1)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "a", cursor: "page-2")]
            ),
            consumedBranchKey: "a"
        )
        #expect(window.branchCursor(for: "a")?.cursor == "page-2", "a replacement cursor means remaining siblings")

        // Final continuation delivers the rest and omits the cursor. Retirement
        // is decided by the consumed branch's identity, not by comparing row
        // counts — direct counts exclude deleted children while returned rows
        // include their tombstones, so counts never reconcile.
        window.merge(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [node("a", marker: 1, relationship: nil, responses: 2),
                        node("c", parent: "a", marker: 3, depth: 1)]
            ),
            consumedBranchKey: "a"
        )
        #expect(window.branchCursor(for: "a") == nil, "an omitted cursor means the branch is exhausted")
        #expect(!window.hasMoreBranches)
    }

    /// The owner's question: does the 200/32 window stop you reaching a deep
    /// marker or a later branch? It must not — the requested node is present in
    /// the first page, and branches keep paging.
    @Test
    func deepRequestedMarkerIsReachableDespiteTruncation() {
        // A truncated first window that nonetheless contains the requested node
        // plus its bounded ancestry.
        var window = MarkerThreadWindow(
            page: page(
                requested: 40,
                windowRoot: "n30",
                nodes: (30...40).map { index in
                    node(
                        "n\(index)",
                        parent: index == 30 ? nil : "n\(index - 1)",
                        marker: index,
                        depth: index - 30
                    )
                },
                ancestorCursor: "higher",
                branches: [RLMarkerThreadBranchDTO(nodeKey: "n40", cursor: "deeper")],
                truncated: true
            )
        )

        let requested = window.requestedNode
        #expect(requested?.markerId == id(40), "the requested marker is always in the window")
        #expect(window.displayRows().contains { $0.isRequested })
        #expect(window.hasMoreAncestry, "earlier ancestry stays reachable")
        #expect(window.branchCursor(for: "n40") != nil, "later branches stay reachable")

        // Paging deeper reaches a node beyond the first window.
        window.merge(
            page: page(
                requested: 40,
                windowRoot: "n40",
                nodes: [node("n41", parent: "n40", marker: 41, depth: 1)]
            )
        )
        #expect(window.nodesByKey["n41"] != nil)
        let depths = Dictionary(uniqueKeysWithValues: window.displayRows().map { ($0.node.nodeKey, $0.depth) })
        #expect(depths["n41"] == 11)
    }

    // MARK: - Tombstones

    /// A hole in the middle of a thesis keeps its structural row so descendants
    /// stay readable, but carries no identity, content or navigation.
    @Test
    func tombstonesHoldStructureWithoutIdentity() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 3,
                windowRoot: "a",
                nodes: [
                    node("a", marker: 1, relationship: nil, responses: 1),
                    node("b", parent: "a", depth: 1, responses: 1, unavailable: true),
                    node("c", parent: "b", marker: 3, depth: 2),
                ]
            )
        )

        let rows = window.displayRows()
        #expect(rows.map(\.node.nodeKey) == ["a", "b", "c"])

        let tombstone = window.nodesByKey["b"]!
        #expect(tombstone.isUnavailable)
        #expect(tombstone.markerId == nil)
        #expect(tombstone.authorDisplayText == nil)
        #expect(tombstone.titleDisplayText == nil)
        #expect(tombstone.possessiveSummary == nil)
        #expect(!tombstone.canNavigate, "a tombstone can never be tapped through")

        // Descendants below the hole remain reachable and correctly nested.
        #expect(rows.last?.depth == 2)
    }

    /// Deleted intermediates occupy structural rows but are not contributions.
    @Test
    func tombstonesAreNotCountedAsContributions() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [
                    node("a", marker: 1, relationship: nil),
                    node("b", parent: "a", marker: 2, relationship: "supports", depth: 1),
                    node("x", parent: "a", relationship: "challenges", depth: 1, unavailable: true),
                ]
            )
        )
        let tallies = window.relationshipTallies()
        #expect(tallies[.supports] == 1)
        #expect(tallies[.challenges] == nil)
    }

    /// An unknown relationship must not be tallied as a known one, but the node
    /// still appears.
    @Test
    func unknownRelationshipAppearsButIsNotTallied() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "a",
                nodes: [
                    node("a", marker: 1, relationship: nil),
                    node("b", parent: "a", marker: 2, relationship: "refutes", depth: 1),
                ]
            )
        )
        #expect(window.relationshipTallies().isEmpty)
        #expect(window.displayRows().count == 2)
        #expect(window.nodesByKey["b"]?.relationship?.displayName == "Refutes")
    }

    /// Nodes whose parent has not arrived yet must still be shown rather than
    /// silently vanishing.
    @Test
    func orphanNodesAreStillRendered() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 5,
                windowRoot: "missing",
                nodes: [node("z", parent: "not-here", marker: 5, depth: 3)]
            )
        )
        #expect(window.displayRows().count == 1)
        #expect(window.displayRows().first?.node.nodeKey == "z")
    }
}
