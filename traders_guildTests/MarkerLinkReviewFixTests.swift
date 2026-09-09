import Foundation
import Testing
@testable import traders_guild

/// Regression cover for the concrete failures raised in independent review.
struct MarkerLinkReviewFixTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        depth: Int = 0,
        responses: Int = 0,
        unavailable: Bool = false
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: unavailable ? nil : marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
            isUnavailable: unavailable,
            authorUsername: unavailable ? nil : "t\(key)",
            title: unavailable ? nil : "Node \(key)",
            directResponseCount: responses,
            depth: depth
        )
    }

    private func page(
        requested: Int,
        windowRoot: String,
        nodes: [RLMarkerLinkPreviewDTO],
        branches: [RLMarkerThreadBranchDTO] = [],
        totalCount: Int? = nil,
        rootMarker: Int? = nil,
        rootKey: String? = nil,
        rootResolved: Bool = false,
        ancestorCursor: String? = nil,
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

    // MARK: - (3) Sibling order across pages

    /// Deep-link case. The initial window must contain the requested node, so
    /// it can carry a *late* sibling; paging that branch then returns the
    /// earlier ones. Appending would file them after the late sibling and
    /// reverse the chronological order the contract promises.
    @Test
    func earlierSiblingsFromAContinuationLandBeforeAKnownLateSibling() {
        // Deep link to c3, the third response under the root.
        var window = MarkerThreadWindow(
            page: page(
                requested: 3,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 3),
                    node("c3", parent: "root", marker: 3, depth: 1),
                ],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")],
                rootMarker: 1,
                rootKey: "root",
                rootResolved: true
            )
        )
        #expect(window.displayRows().map(\.node.nodeKey) == ["root", "c3"])

        // The branch window carries the anchor plus its earlier children.
        window.merge(
            page: page(
                requested: 3,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 3),
                    node("c1", parent: "root", marker: 11, depth: 1),
                    node("c2", parent: "root", marker: 12, depth: 1),
                ]
            ),
            consumedBranchKey: "root"
        )

        #expect(
            window.displayRows().map(\.node.nodeKey) == ["root", "c1", "c2", "c3"],
            "earlier siblings must precede the late one the deep link brought in"
        )
    }

    /// Tombstones carry no timestamp, so ordering cannot fall back to sorting.
    /// The server's per-page sequence is the only authority.
    @Test
    func tombstoneSiblingsKeepServerOrderWithoutTimestamps() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 5,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 1), node("c4", parent: "root", marker: 5, depth: 1)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")]
            )
        )
        window.merge(
            page: page(
                requested: 5,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 1),
                    node("x1", parent: "root", depth: 1, unavailable: true),
                    node("c2", parent: "root", marker: 22, depth: 1),
                    node("x3", parent: "root", depth: 1, unavailable: true),
                ]
            ),
            consumedBranchKey: "root"
        )

        #expect(window.displayRows().map(\.node.nodeKey) == ["root", "x1", "c2", "x3", "c4"])
    }

    /// A page that overlaps in the middle splices around its anchors rather
    /// than reordering what is already held.
    @Test
    func anchoredMergePreservesBothOrderings() {
        #expect(
            MarkerThreadWindow.anchoredMerge(existing: ["b"], incoming: ["a"]) == ["a", "b"],
            "no overlap: incoming is earlier and lands ahead"
        )
        #expect(
            MarkerThreadWindow.anchoredMerge(existing: ["a", "c"], incoming: ["a", "b", "c"]) == ["a", "b", "c"],
            "b splices between its anchors"
        )
        #expect(
            MarkerThreadWindow.anchoredMerge(existing: ["a"], incoming: ["a", "b"]) == ["a", "b"],
            "later siblings follow their anchor"
        )
        #expect(
            MarkerThreadWindow.anchoredMerge(existing: ["a", "b"], incoming: ["a", "b"]) == ["a", "b"],
            "a repeat page changes nothing"
        )
    }

    // MARK: - (4) Cursor retirement by consumed identity

    /// The old rule compared `directResponseCount` to the number of loaded
    /// children. Direct counts exclude deleted children while the returned rows
    /// include their tombstones, so the two never reconcile and the cursor was
    /// offered forever.
    @Test
    func branchWithTombstonedChildrenStillRetiresItsCursor() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                // Two live children reported, but three structural rows exist.
                nodes: [node("root", marker: 1, responses: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")]
            )
        )
        #expect(window.branchCursor(for: "root") == "b1")

        window.merge(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 2),
                    node("c1", parent: "root", marker: 11, depth: 1),
                    node("x2", parent: "root", depth: 1, unavailable: true),
                    node("c3", parent: "root", marker: 13, depth: 1),
                ]
            ),
            consumedBranchKey: "root"
        )

        #expect(
            window.branchCursor(for: "root") == nil,
            "the server returned no replacement for the consumed branch, so it is exhausted"
        )
        #expect(!window.hasMoreBranches)
    }

    /// A replacement cursor for the consumed branch keeps it live.
    @Test
    func replacementCursorKeepsTheBranchLive() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 5)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")]
            )
        )
        window.merge(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 5), node("c1", parent: "root", marker: 11, depth: 1)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b2")]
            ),
            consumedBranchKey: "root"
        )
        #expect(window.branchCursor(for: "root") == "b2")
    }

    /// A page that was not fetched by spending a cursor must not retire one.
    @Test
    func unrelatedPageDoesNotRetireAnyCursor() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")]
            )
        )
        // An ancestry continuation says nothing about the branch.
        window.merge(
            page: page(requested: 1, windowRoot: "up", nodes: [node("up", marker: 99, responses: 1)])
        )
        #expect(window.branchCursor(for: "root") == "b1")
    }

    // MARK: - (1) Failure classification

    /// The core of the finding: a transient failure must never retire a cursor,
    /// because doing so permanently loses every remaining response.
    @Test
    func transientFailuresAreDistinguishedFromGoneOnes() {
        #expect(MarkerThreadRequestFailure.classify(APIError.networkError("offline")) == .transient)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(500, "boom")) == .transient)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(429, "slow down")) == .transient)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(502, "gateway")) == .transient)
        #expect(
            MarkerThreadRequestFailure.classify(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            ) == .transient
        )

        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(409, "stale cursor")) == .staleCursor)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(404, "no such node")) == .gone)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(410, "gone")) == .gone)
    }

    @Test
    func capabilityOffIsRecognisedFromEitherSignal() {
        #expect(MarkerThreadRequestFailure.classify(MarkerLinkUnavailableError()) == .unavailable)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(503, "nope")) == .unavailable)
        #expect(
            MarkerThreadRequestFailure.classify(
                APIError.serverError(500, MarkerLinkUnavailableError.detail)
            ) == .unavailable
        )
    }

    @Test
    func staleCursorIsRecognisedFromABadRequestToo() {
        #expect(
            MarkerThreadRequestFailure.classify(APIError.badRequest("Unknown cursor")) == .staleCursor
        )
        #expect(MarkerThreadRequestFailure.classify(APIError.badRequest("bad intent")) == .transient)
    }

    // MARK: - (2) Stale pages cannot mutate another selection

    /// The store refuses a page from a superseded generation, so the check
    /// cannot be forgotten by a caller.
    @MainActor
    @Test
    func storeRefusesAPageFromASupersededGeneration() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))
        let generation = store.generation

        store.invalidateAll(reason: .privacyChanged)

        let accepted = store.ingest(
            page: page(requested: 1, windowRoot: "root", nodes: [node("root", marker: 1)]),
            requestedMarkerId: id(1),
            expectedGeneration: generation
        )
        #expect(accepted == nil, "a page in flight across an invalidation must be dropped")
        #expect(store.window(forMarkerId: id(1)) == nil)

        // The same page under the current generation is accepted.
        let now = store.ingest(
            page: page(requested: 1, windowRoot: "root", nodes: [node("root", marker: 1)]),
            requestedMarkerId: id(1),
            expectedGeneration: store.generation
        )
        #expect(now != nil)
    }

    // MARK: - (5) Capability flip

    @MainActor
    @Test
    func capabilityFlipDropsCachedWindows() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))
        store.ingest(
            page: page(requested: 1, windowRoot: "root", nodes: [node("root", marker: 1)]),
            requestedMarkerId: id(1)
        )
        #expect(store.window(forMarkerId: id(1)) != nil)

        store.invalidateAll(reason: .capabilityChanged)

        #expect(store.window(forMarkerId: id(1)) == nil)
        #expect(store.lastInvalidationReason == .capabilityChanged)
    }

    // MARK: - Privacy and membership invalidation

    @MainActor
    @Test
    func privacyAndMembershipChangesDropEveryWindow() {
        for reason in [
            MarkerThreadStore.InvalidationReason.privacyChanged,
            .moderation,
            .membershipLost,
            .reconnect,
        ] {
            let store = MarkerThreadStore()
            store.activate(accountId: id(900), guildId: id(901))
            store.ingest(
                page: page(requested: 1, windowRoot: "root", nodes: [node("root", marker: 1)]),
                requestedMarkerId: id(1)
            )
            store.setExpanded(true, forMarkerId: id(1))
            store.stagePendingNavigation(markerId: id(1))
            let before = store.generation

            store.invalidateAll(reason: reason)

            #expect(store.window(forMarkerId: id(1)) == nil, "\(reason) must drop windows")
            #expect(!store.isExpanded(forMarkerId: id(1)), "\(reason) must drop disclosure state")
            #expect(store.consumePendingNavigation() == nil, "\(reason) must drop staged navigation")
            #expect(store.generation > before)
            #expect(store.lastInvalidationReason == reason)
        }
    }

    // MARK: - Totals never inferred

    /// Tombstones occupy structural rows but are not contributions, so they
    /// must not inflate the "at least" floor.
    @Test
    func atLeastFloorExcludesTombstones() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 1),
                    node("c1", parent: "root", marker: 11, depth: 1),
                    node("x2", parent: "root", depth: 1, unavailable: true),
                    node("x3", parent: "root", depth: 1, unavailable: true),
                ],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")]
            )
        )
        #expect(window.loadedCount == 4, "structural rows include tombstones")
        #expect(window.activeLoadedCount == 2, "contributions do not")
        #expect(window.totalCount == .atLeast(2))
        #expect(window.totalCount.displayText == "2+")
    }

    /// The last continuation page still carries no total, so the window must
    /// keep reporting a floor rather than promoting the row count.
    @Test
    func lastContinuationPageWithoutATotalStaysAFloor() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "b1")],
                rootMarker: 1,
                rootKey: "root",
                rootResolved: true
            )
        )
        // Final page: branch exhausted, ancestry settled, but no total sent.
        window.merge(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 2),
                    node("c1", parent: "root", marker: 11, depth: 1),
                    node("c2", parent: "root", marker: 12, depth: 1),
                ]
            ),
            consumedBranchKey: "root"
        )

        #expect(window.completeness == .complete)
        #expect(!window.totalCount.isExact, "no server total means no exact total, even when complete")
        #expect(window.totalCount == .atLeast(3))
    }
}
