import Foundation
import Testing
@testable import traders_guild

/// Cover for the queued integration findings.
struct MarkerLinkIntegrationRepairTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func node(_ key: String, parent: String? = nil, marker: Int? = nil, responses: Int = 0)
        -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
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

    // MARK: - Cursor provenance

    /// Cursors are encrypted and bound to the `requested_marker_id` that issued
    /// them. Replaying one against whichever marker is selected after
    /// navigating within the thesis 409s, so provenance travels with it.
    @Test
    func cursorsRememberTheMarkerThatIssuedThem() {
        let window = MarkerThreadWindow(
            page: page(
                requested: 7,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 3)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "opaque-a")],
                ancestorCursor: "opaque-up"
            )
        )

        let branch = window.branchCursor(for: "root")
        #expect(branch?.cursor == "opaque-a")
        #expect(branch?.issuedFor == id(7), "bound to the requesting marker, not the root")
        #expect(window.ancestorCursor?.issuedFor == id(7))
    }

    /// A page fetched under a different marker re-issues cursors bound to *it*,
    /// which is exactly the navigate-within-thesis case.
    @Test
    func continuationRebindsProvenanceToItsOwnRequest() {
        var window = MarkerThreadWindow(
            page: page(
                requested: 7,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 3)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "opaque-a")]
            )
        )
        #expect(window.branchCursor(for: "root")?.issuedFor == id(7))

        window.merge(
            page: page(
                requested: 9,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 3), node("c", parent: "root", marker: 9)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "root", cursor: "opaque-b")]
            ),
            consumedBranchKey: "root"
        )

        let branch = window.branchCursor(for: "root")
        #expect(branch?.cursor == "opaque-b")
        #expect(branch?.issuedFor == id(9), "the replacement is bound to the marker that fetched it")
    }

    /// Merging two windows for one thesis must keep each cursor with its own
    /// issuing marker — the mixed-origin case.
    @Test
    func absorbKeepsEachCursorWithItsOwnProvenance() {
        var first = MarkerThreadWindow(
            page: page(
                requested: 7,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 5), node("a", parent: "root", marker: 2)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "a", cursor: "from-7")]
            )
        )
        let second = MarkerThreadWindow(
            page: page(
                requested: 9,
                windowRoot: "root",
                nodes: [node("root", marker: 1, responses: 5), node("b", parent: "root", marker: 3)],
                branches: [RLMarkerThreadBranchDTO(nodeKey: "b", cursor: "from-9")]
            )
        )

        first.absorb(second)
        #expect(first.branchCursor(for: "a")?.issuedFor == id(7))
        #expect(first.branchCursor(for: "b")?.issuedFor == id(9))
    }

    // MARK: - Failure classification

    /// Ancestry needs the same classification as branches. Treating every
    /// failure as transient left a stale 409 retrying a cursor the server will
    /// never accept again.
    @Test
    func staleAndGoneAreDistinguishedFromTransient() {
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(409, "stale")) == .staleCursor)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(404, "gone")) == .gone)
        #expect(MarkerThreadRequestFailure.classify(APIError.serverError(500, "boom")) == .transient)
        #expect(MarkerThreadRequestFailure.classify(APIError.networkError("offline")) == .transient)
    }

    // MARK: - Pending navigation

    /// The restore loop *consumes* the token before re-staging. Without
    /// carrying the original instant the expiry clock restarts on every
    /// attempt, which is the loop the expiry was added to stop.
    @MainActor
    @Test
    func consumeThenRestagePreservesTheOriginalInstant() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))
        let tapped = Date()

        store.stagePendingNavigation(markerId: id(7), now: tapped)

        // Three failed restore attempts, each consuming and re-staging.
        var carried = tapped
        for offset in [10.0, 20.0, 29.0] {
            let pending = store.consumePendingNavigation(now: tapped.addingTimeInterval(offset))
            let token = try? #require(pending)
            carried = token?.stagedAt ?? carried
            store.stagePendingNavigation(
                markerId: id(7),
                now: tapped.addingTimeInterval(offset),
                preservingStagedAt: carried
            )
        }

        #expect(
            store.consumePendingNavigation(now: tapped.addingTimeInterval(31)) == nil,
            "the clock must run from the original tap, not the last attempt"
        )
    }

    // MARK: - Counts

    /// A newer HTTP list must not be rolled back to an older cached count.
    @Test
    func newerListAdvancesTheReconcilerRatherThanBeingOverwritten() {
        var reconciler = MarkerResponseCountReconciler()
        let old = MarkerRevision(wire: "2026-09-09T10:00:00.100000Z")
        let new = MarkerRevision(wire: "2026-09-09T10:00:00.200000Z")

        _ = reconciler.apply(.init(markerId: id(1), directResponseCount: 2, revision: old))
        // A list arrives carrying a newer revision.
        #expect(reconciler.apply(.init(markerId: id(1), directResponseCount: 5, revision: new)) == .applied(5))
        #expect(reconciler.count(for: id(1)) == 5, "the newer list wins")
    }

    // MARK: - Neutral merge

    /// Broadcast payloads are actor-neutral, so merging one must not clear this
    /// viewer's own like or poll vote.
    @Test
    func neutralMergePreservesViewerEngagement() throws {
        let existing = Self.marker(liked: true, vote: id(50), likes: 4)
        let incoming = Self.marker(liked: false, vote: nil, likes: 9)

        let merged = incoming.updating(
            isLikedByCurrentUser: existing.isLikedByCurrentUser,
            userPollVote: existing.userPollVote
        )

        #expect(merged.isLikedByCurrentUser, "the viewer's own like survives a neutral broadcast")
        #expect(merged.userPollVote == id(50), "and so does their poll vote")
        #expect(merged.likeCount == 9, "while the server's absolute count is adopted")
    }

    // MARK: - Fade rule geometry

    /// The fade rule asks whether two members are *visible*. A member scrolled
    /// far off screen is loaded but not painted, and must not satisfy it.
    @Test
    func fadeRuleUsesPaintedMarkersNotLoadedOnes() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 1),
            MarkerLinkNode(
                id: id(2),
                parentId: id(1),
                relationship: MarkerLinkRelationshipValue(.supports)
            ),
        ])

        // Both loaded, but only the selected one was painted this frame.
        let painted = graph.focusState(selectedId: id(2), visibleIds: [id(2)])
        #expect(!painted.shouldFadeUnrelated, "one painted member must not dim the chart")

        let bothPainted = graph.focusState(selectedId: id(2), visibleIds: [id(1), id(2)])
        #expect(bothPainted.shouldFadeUnrelated)
    }

    // MARK: - Fixture

    private static func marker(liked: Bool, vote: UUID?, likes: Int) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            symbolId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            guildId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            author: RLGuildMemberDTO(
                membershipId: UUID(),
                role: "member",
                reputation: 0,
                contributionScore: 0,
                dateJoined: Date(timeIntervalSinceReferenceDate: 0),
                accuracyRate: nil,
                mutedUntil: nil,
                suspendedUntil: nil,
                userId: UUID(),
                username: "alex",
                displayName: "Alex",
                avatarUrl: nil,
                isOnline: false,
                globalReputation: 0,
                isFriend: false,
                friendshipStatus: nil,
                isBlocked: false,
                isBlockedBy: false
            ),
            candleTimestamp: Date(timeIntervalSinceReferenceDate: 0),
            timeframe: "1h",
            price: 1,
            intent: "poll",
            title: nil,
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: false,
            trackingState: nil,
            alertSeverity: nil,
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            createdAtFormatted: "now",
            isVisible: true,
            likeCount: likes,
            isLikedByCurrentUser: liked,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: false,
            canEdit: false,
            canDelete: false,
            components: [],
            primaryComponentId: nil,
            pollQuestion: nil,
            pollOptions: nil,
            userPollVote: vote,
            predictionResult: nil
        )
    }
}
