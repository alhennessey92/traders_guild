import Foundation
import Testing
@testable import traders_guild

/// The refresh paths driven through a spy client, so what is asserted is that a
/// request was actually issued — not that a helper exists which would issue one.
///
/// Both bugs these cover were invisible to type-level tests. The window merged
/// correctly and the store cached correctly; what was wrong was that the call
/// site returned early without asking the server, and that a merge cannot
/// express the one topology change a 409 announces.
@MainActor
struct MarkerThreadRefreshCallSiteTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    // MARK: - Harness

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        responses: Int = 0
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
            authorUsername: "author-\(key)",
            symbolId: symbolId,
            title: "Node \(key)",
            directResponseCount: responses
        )
    }

    private func page(
        requested: Int,
        windowRoot: String,
        nodes: [RLMarkerLinkPreviewDTO],
        branches: [RLMarkerThreadBranchDTO] = [],
        ancestorCursor: String? = nil,
        rootMarker: Int? = nil,
        rootResolved: Bool = false
    ) -> RLMarkerThreadResponseDTO {
        RLMarkerThreadResponseDTO(
            requestedMarkerId: id(requested),
            rootMarkerId: rootMarker.map(id),
            rootKey: rootMarker != nil ? windowRoot : nil,
            rootResolved: rootResolved,
            windowRootKey: windowRoot,
            nodes: nodes,
            ancestorCursor: ancestorCursor,
            branches: branches,
            loadedCount: nodes.count
        )
    }

    private func member(_ n: Int) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n), role: "member", reputation: 0, contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 0), accuracyRate: nil, mutedUntil: nil,
            suspendedUntil: nil, userId: id(n), username: "user\(n)", displayName: "User \(n)",
            avatarUrl: nil, isOnline: false, globalReputation: 0, isFriend: false,
            friendshipStatus: nil, isBlocked: false, isBlockedBy: false
        )
    }

    private func makeManager(spy: ThreadSpyAPI) -> MarkerManager {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.linkedMarkersEnabled = true
        manager.configure(api: spy, symbolId: symbolId, timeframe: .h1)
        return manager
    }

    /// The loader dispatches its work into detached `Task`s, so a test has to
    /// let the runloop turn. Bounded so a genuine hang fails rather than spins.
    private func settle(
        until condition: @MainActor () -> Bool,
        _ description: String
    ) async throws {
        for _ in 0..<400 {
            if condition() { return }
            await Task.yield()
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        Issue.record("timed out waiting for: \(description)")
        throw CancellationError()
    }

    // MARK: - Reopen actually asks the server

    /// Reopening the disclosure took `load`'s cached fast path and returned
    /// without going near the server, so a node hidden since the last read
    /// stayed on screen.
    ///
    /// The second page here deliberately omits node `b` — the shape of a node
    /// that has become invisible to this viewer, with no generation bump to
    /// announce it, which is precisely the case the cache cannot detect. It also
    /// proves discarding rather than merging: a merge would have kept `b`,
    /// because a merge can only add or replace.
    @Test
    func reopenIssuesARequestAndCannotShowContentTheServerDropped() async throws {
        let spy = ThreadSpyAPI()
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        let manager = makeManager(spy: spy)
        let loader = MarkerThreadLoader()

        spy.pages = [
            page(
                requested: 1, windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 2),
                        node("a", parent: "root", marker: 2),
                        node("b", parent: "root", marker: 3)],
                rootMarker: 1, rootResolved: true
            ),
            page(
                requested: 1, windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 1),
                        node("a", parent: "root", marker: 2)],
                rootMarker: 1, rootResolved: true
            )
        ]

        loader.load(markerId: id(1), manager: manager, store: store)
        try await settle(until: { loader.state == .loaded }, "initial load")
        #expect(spy.requests.count == 1)
        #expect(loader.rows.map(\.node.nodeKey) == ["root", "a", "b"])

        // A plain re-load is the cached fast path: it must NOT ask the server.
        // Pinning this makes the reopen assertion below mean something.
        loader.load(markerId: id(1), manager: manager, store: store)
        #expect(spy.requests.count == 1, "walking reuses the cache by design")
        #expect(loader.rows.count == 3)

        loader.reopen(markerId: id(1), manager: manager, store: store)
        try await settle(
            until: { loader.state == .loaded && loader.rows.count == 2 },
            "reopen to re-read"
        )

        #expect(spy.requests.count == 2, "reopening must actually ask the server")
        #expect(spy.requests.last?.cursor == nil, "an initial window, not a continuation")
        #expect(
            !loader.rows.contains { $0.node.nodeKey == "b" },
            "a node the fresh page omits must be gone, which a merge could never do"
        )
        #expect(loader.rows.map(\.node.nodeKey) == ["root", "a"])
    }

    /// The cache is not thrown away for a walk. Reopening is the deliberate
    /// exception, and if this stopped holding, tapping through a thesis would
    /// issue a request per node.
    @Test
    func walkingWithinAnOpenThesisStillReusesTheCache() async throws {
        let spy = ThreadSpyAPI()
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        let manager = makeManager(spy: spy)
        let loader = MarkerThreadLoader()

        spy.pages = [
            page(
                requested: 1, windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 1), node("a", parent: "root", marker: 2)],
                rootMarker: 1, rootResolved: true
            )
        ]

        loader.load(markerId: id(1), manager: manager, store: store)
        try await settle(until: { loader.state == .loaded }, "initial load")
        #expect(spy.requests.count == 1)

        // Walk to the child, which shares the thesis and so the cached window.
        loader.load(markerId: id(2), manager: manager, store: store)
        #expect(spy.requests.count == 1, "a walk must not re-request")
        #expect(
            loader.rows.first(where: \.isRequested)?.node.nodeKey == "a",
            "and the highlight still follows the selection"
        )
    }

    // MARK: - A structural 409 rebuilds the topology

    /// Cached root R with child C. C's branch cursor 409s, which means the
    /// server's idea of this thesis has moved. Here it moved in the one
    /// direction a merge cannot express: R was hard-deleted, C detached, and the
    /// real root moved *down* to C — while `MarkerThreadWindow` only ever raises
    /// a window root and `insert` never removes a parent edge.
    ///
    /// So a force-load alone would have kept R and kept C pointing at it. The
    /// selection is on C, and must survive; R and the edge must not.
    @Test
    func staleCursorDiscardsTheDeletedRootAndKeepsTheDetachedChild() async throws {
        let spy = ThreadSpyAPI()
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        let manager = makeManager(spy: spy)
        let loader = MarkerThreadLoader()

        // Selection is C (marker 2), reached by walking down from R.
        spy.pages = [
            page(
                requested: 2, windowRoot: "R",
                nodes: [node("R", marker: 1, responses: 1),
                        node("C", parent: "R", marker: 2, responses: 4)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "C", cursor: "cursor-under-C")],
                rootMarker: 1, rootResolved: true
            )
        ]
        loader.load(markerId: id(2), manager: manager, store: store)
        try await settle(until: { loader.state == .loaded }, "initial load")

        #expect(loader.rows.map(\.node.nodeKey) == ["R", "C"])
        let cRow = try #require(loader.rows.first { $0.node.nodeKey == "C" })
        #expect(cRow.depth == 1, "C starts as a child of R")
        #expect(cRow.hasMoreResponses, "and has a branch to page")

        // Expanding C's branch 409s, then the refresh returns the new truth:
        // R is gone and C is a detached root of its own.
        spy.errors = [APIError.serverError(409, "marker_thread_refresh_required")]
        spy.pages = [
            page(
                requested: 2, windowRoot: "C",
                nodes: [node("C", marker: 2, responses: 1),
                        node("C1", parent: "C", marker: 5)],
                rootMarker: 2, rootResolved: true
            )
        ]

        loader.expandBranch(nodeKey: "C", manager: manager, store: store)
        try await settle(
            until: { loader.state == .loaded && !loader.rows.contains { $0.node.nodeKey == "R" } },
            "409 to trigger an authoritative refresh"
        )

        // Two requests after the initial load: the 409'd branch page, then the refresh.
        #expect(spy.requests.count == 3)
        #expect(spy.requests[1].cursor == "cursor-under-C", "the branch attempt")
        #expect(spy.requests[2].cursor == nil, "then a fresh initial window")
        #expect(spy.requests[2].markerId == id(2), "anchored on the surviving selection")

        // The deleted root and its edge are gone.
        #expect(
            !loader.rows.contains { $0.node.nodeKey == "R" },
            "a merge would have kept the deleted root; discarding first is what removes it"
        )
        #expect(store.window(forMarkerId: id(1)) == nil, "R is not addressable either")

        // The selection survived, now as a root in its own right.
        let refreshed = try #require(loader.rows.first { $0.node.nodeKey == "C" })
        #expect(refreshed.depth == 0, "C is its own root now, not a child of a dead node")
        #expect(refreshed.isRequested, "and is still the row being read")
        #expect(refreshed.node.parentKey == nil, "the obsolete parent edge is gone")
        #expect(loader.rows.map(\.node.nodeKey) == ["C", "C1"])
    }

    /// The ancestry cursor takes the same path, for the same reason: a refused
    /// ancestry cursor means the chain above this marker changed.
    @Test
    func staleAncestryCursorAlsoRebuildsRatherThanMerging() async throws {
        let spy = ThreadSpyAPI()
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        let manager = makeManager(spy: spy)
        let loader = MarkerThreadLoader()

        spy.pages = [
            page(
                requested: 9, windowRoot: "mid",
                nodes: [node("mid", parent: "gone", marker: 9)],
                ancestorCursor: "up-from-9"
            )
        ]
        loader.load(markerId: id(9), manager: manager, store: store)
        try await settle(until: { loader.state == .loaded }, "initial load")
        #expect(loader.window?.ancestorCursor?.cursor == "up-from-9")

        spy.errors = [APIError.serverError(409, "marker_thread_refresh_required")]
        spy.pages = [
            page(
                requested: 9, windowRoot: "mid",
                nodes: [node("mid", marker: 9)],
                rootMarker: 9, rootResolved: true
            )
        ]

        loader.loadMoreAncestry(manager: manager, store: store)
        try await settle(
            until: { loader.window?.ancestorCursor == nil && loader.state == .loaded },
            "ancestry 409 to trigger a refresh"
        )

        #expect(spy.requests.count == 3)
        #expect(spy.requests[2].cursor == nil, "a fresh initial window, not another cursor")
        #expect(loader.rows.map(\.node.nodeKey) == ["mid"])
        #expect(
            loader.rows.first?.node.parentKey == nil,
            "the edge to the vanished ancestor is gone, not merged forward"
        )
        #expect(loader.ancestryFailure == nil)
    }

    /// A transient failure must NOT discard anything. Cursors and rows survive,
    /// or an offline blip would cost the viewer every response under a node.
    @Test
    func transientFailureKeepsTheWindowAndTheCursor() async throws {
        let spy = ThreadSpyAPI()
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        let manager = makeManager(spy: spy)
        let loader = MarkerThreadLoader()

        spy.pages = [
            page(
                requested: 1, windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 3), node("c", parent: "root", marker: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "c", cursor: "keep-me")],
                rootMarker: 1, rootResolved: true
            )
        ]
        loader.load(markerId: id(1), manager: manager, store: store)
        try await settle(until: { loader.state == .loaded }, "initial load")

        spy.errors = [APIError.serverError(500, "upstream unavailable")]
        loader.expandBranch(nodeKey: "c", manager: manager, store: store)
        try await settle(until: { loader.branchFailures["c"] != nil }, "the transient failure")

        #expect(spy.requests.count == 2, "no refresh was issued")
        #expect(loader.rows.map(\.node.nodeKey) == ["root", "c"], "rows are untouched")
        #expect(loader.window?.branchCursor(for: "c")?.cursor == "keep-me", "cursor survives")
    }
}

/// Records every thread request and replays canned pages or errors.
private final class ThreadSpyAPI: MarkerAPIClient, @unchecked Sendable {
    struct Request: Equatable {
        let markerId: UUID
        let cursor: String?
    }

    private(set) var requests: [Request] = []
    var pages: [RLMarkerThreadResponseDTO] = []
    var errors: [Error] = []

    func getMarkerThread(markerId: UUID, cursor: String?) async throws -> RLMarkerThreadResponseDTO {
        requests.append(Request(markerId: markerId, cursor: cursor))
        if !errors.isEmpty { throw errors.removeFirst() }
        guard !pages.isEmpty else { throw APIError.networkError("no page queued") }
        return pages.removeFirst()
    }

    // MARK: - Unused by these tests

    func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO {
        RLMarkersListDTO(markers: [], totalCount: 0, hasMore: false, nextCursor: nil)
    }
    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.networkError("unused")
    }
    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.networkError("unused")
    }
    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLMarkerDeleteResponseDTO {
        throw APIError.networkError("unused")
    }
    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO {
        throw APIError.networkError("unused")
    }
    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO {
        throw APIError.networkError("unused")
    }
    func addMarkerComment(
        guildId: UUID, markerId: UUID, content: String, attachmentUrl: String?,
        attachmentType: String?, attachmentName: String?, replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO {
        throw APIError.networkError("unused")
    }
    func toggleMarkerCommentReaction(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMarkerCommentDTO {
        throw APIError.networkError("unused")
    }
    func getMarkerCommentReactionReactors(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        throw APIError.networkError("unused")
    }
    func deleteMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID) async throws -> RLDetailResponseDTO {
        throw APIError.networkError("unused")
    }
}
