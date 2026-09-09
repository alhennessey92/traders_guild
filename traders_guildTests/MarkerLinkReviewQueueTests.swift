import Foundation
import Testing
@testable import traders_guild

/// The queued integration-review repairs, each pinned at the call site that was
/// actually wrong rather than at the pure type underneath it.
///
/// Several of these bugs were invisible to unit tests of the types involved:
/// the window merged correctly, the reconciler ordered correctly, the graph
/// computed the right fade. What was wrong was the *order* the call site did
/// things in, or a guard it never reached. So these drive the manager and the
/// loader.
@MainActor
struct MarkerLinkReviewQueueTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let otherSymbolId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    // MARK: - Fixtures

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        responses: Int = 0,
        symbol: UUID? = nil
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
            authorUsername: "author-\(key)",
            symbolId: symbol,
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

    private func member(_ n: Int, role: String = "member") -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n),
            role: role,
            reputation: 0,
            contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 0),
            accuracyRate: nil,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: id(n),
            username: "user\(n)",
            displayName: "User \(n)",
            avatarUrl: nil,
            isOnline: false,
            globalReputation: 0,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
    }

    private func manager(as viewer: Int = 1, canModerate: Bool = false) -> MarkerManager {
        let me = member(viewer)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.linkedMarkersEnabled = true
        manager.viewerCanModerate = canModerate
        return manager
    }

    // MARK: - Escalating thread invalidation

    /// The gap: matching an event by id only invalidates what the cache has
    /// already seen. A response created deep in a branch nobody has paged into
    /// names neither a cached node nor a cached parent, so the id lookup finds
    /// nothing — and the window it silently staled has no way to discover that,
    /// because nothing in it mentions the marker that changed.
    @Test
    func eventOnAnUnseenBranchStillInvalidatesTheCachedThesis() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        store.ingest(
            page: page(
                requested: 10,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 10, responses: 1, symbol: symbolId),
                    node("c", parent: "root", marker: 11, symbol: symbolId)
                ],
                rootMarker: 10,
                rootResolved: true
            ),
            requestedMarkerId: id(10),
            expectedGeneration: store.generation
        )
        #expect(store.window(forMarkerId: id(10)) != nil)

        let manager = manager()
        manager.threadStore = store

        // Marker 77 answers 78. Neither is in the cache: 78 sits on a branch the
        // viewer has never expanded.
        let unseen = makeMarkerDTO(
            id: id(77),
            author: member(2),
            symbolId: symbolId,
            parentMarkerId: id(78),
            linkRelationship: "challenges"
        )
        #expect(store.window(forMarkerId: id(77)) == nil)
        #expect(store.window(forMarkerId: id(78)) == nil)

        manager.invalidateThreadsTouched(by: unseen)

        #expect(
            store.window(forMarkerId: id(10)) == nil,
            "a same-symbol event the cache cannot place must still drop the window"
        )
    }

    /// Escalation is scoped, not indiscriminate: a thesis is same-symbol by
    /// contract, so a window on another symbol is provably unaffected and must
    /// survive. Otherwise every unrelated event throws away the viewer's cache.
    @Test
    func escalationSparesTheasesOnOtherSymbols() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        store.ingest(
            page: page(
                requested: 20,
                windowRoot: "other",
                nodes: [node("other", marker: 20, symbol: otherSymbolId)],
                rootMarker: 20,
                rootResolved: true
            ),
            requestedMarkerId: id(20),
            expectedGeneration: store.generation
        )

        let manager = manager()
        manager.threadStore = store

        manager.invalidateThreadsTouched(
            by: makeMarkerDTO(
                id: id(77),
                author: member(2),
                symbolId: symbolId,
                parentMarkerId: id(78),
                linkRelationship: "supports"
            )
        )

        #expect(
            store.window(forMarkerId: id(20)) != nil,
            "a thesis cannot span symbols, so this one cannot have been affected"
        )
    }

    /// Deletion leaves a tombstone the server renders in place of the node, so
    /// an unplaceable deletion stales a window exactly as a creation does.
    @Test
    func unplaceableDeletionAlsoInvalidates() throws {
        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        store.ingest(
            page: page(
                requested: 30,
                windowRoot: "root",
                nodes: [node("root", marker: 30, symbol: symbolId)],
                rootMarker: 30,
                rootResolved: true
            ),
            requestedMarkerId: id(30),
            expectedGeneration: store.generation
        )

        let manager = manager()
        manager.threadStore = store

        let payload = try #require(
            decodeDeletePayload(
                markerId: id(88),
                guildId: guildId,
                symbolId: symbolId,
                parentMarkerId: id(89)
            )
        )
        manager.invalidateThreadsTouched(byDeletionOf: payload)

        #expect(store.window(forMarkerId: id(30)) == nil)
    }

    // MARK: - neutralMerge derives permissions locally

    /// A realtime payload is serialised with the *creator's* viewer context and
    /// broadcast verbatim, so its permission flags describe whoever acted. Left
    /// alone they hand every recipient the creator's Edit and Delete affordances
    /// on somebody else's marker.
    ///
    /// The fixture deliberately arrives with all three flags true, as a payload
    /// created by its author genuinely does.
    @Test
    func neutralMergeRefusesAnotherMembersPermissions() {
        let manager = manager(as: 1)
        let theirs = makeMarkerDTO(
            id: id(50),
            author: member(2),
            symbolId: symbolId,
            isCurrentUserMarker: true,
            canEdit: true,
            canDelete: true
        )
        let loaded = makeMarkerDTO(id: id(50), author: member(2), symbolId: symbolId)

        let merged = manager.neutralMerge(theirs, into: loaded)

        #expect(!merged.isCurrentUserMarker)
        #expect(!merged.canEdit)
        #expect(!merged.canDelete, "an ordinary member cannot delete another's marker")
    }

    /// The viewer's own marker keeps its affordances — the repair must not
    /// simply clear everything.
    @Test
    func neutralMergeKeepsTheViewersOwnPermissions() {
        let manager = manager(as: 1)
        let mine = makeMarkerDTO(
            id: id(51),
            author: member(1),
            symbolId: symbolId,
            isCurrentUserMarker: false,
            canEdit: false,
            canDelete: false
        )
        let loaded = makeMarkerDTO(id: id(51), author: member(1), symbolId: symbolId)

        let merged = manager.neutralMerge(mine, into: loaded)

        #expect(merged.isCurrentUserMarker)
        #expect(merged.canEdit)
        #expect(merged.canDelete)
    }

    /// A moderator may remove another member's marker but still may not edit it,
    /// which the server enforces however senior the viewer.
    @Test
    func moderatorGainsDeleteButNeverEdit() {
        let manager = manager(as: 1, canModerate: true)
        let theirs = makeMarkerDTO(id: id(52), author: member(2), symbolId: symbolId)
        let loaded = makeMarkerDTO(id: id(52), author: member(2), symbolId: symbolId)

        let merged = manager.neutralMerge(theirs, into: loaded)

        #expect(!merged.isCurrentUserMarker)
        #expect(!merged.canEdit, "editing someone else's marker is refused server-side")
        #expect(merged.canDelete)
    }

    /// Nested per-viewer state the top-level vote field does not cover. The
    /// incoming counts are authoritative; the `hasVoted` flags are not, and a
    /// neutral payload's `false` would silently un-check the viewer's choice.
    @Test
    func neutralMergeRestoresNestedPollVotes() throws {
        let manager = manager(as: 1)
        let optionA = id(701)
        let optionB = id(702)

        let loaded = makeMarkerDTO(
            id: id(53),
            author: member(2),
            symbolId: symbolId,
            pollOptions: [
                RLPollOptionDTO(id: optionA, text: "Up", voteCount: 3, hasVoted: true),
                RLPollOptionDTO(id: optionB, text: "Down", voteCount: 1, hasVoted: false)
            ],
            userPollVote: optionA
        )
        // Reordered and recounted, with every flag neutral — the broadcast shape.
        let incoming = makeMarkerDTO(
            id: id(53),
            author: member(2),
            symbolId: symbolId,
            pollOptions: [
                RLPollOptionDTO(id: optionB, text: "Down", voteCount: 2, hasVoted: false),
                RLPollOptionDTO(id: optionA, text: "Up", voteCount: 9, hasVoted: false)
            ],
            userPollVote: nil
        )

        let merged = manager.neutralMerge(incoming, into: loaded)
        let options = try #require(merged.pollOptions)

        #expect(options.map(\.id) == [optionB, optionA], "incoming order is authoritative")
        #expect(options.first { $0.id == optionA }?.voteCount == 9, "incoming counts win")
        #expect(options.first { $0.id == optionA }?.hasVoted == true, "the viewer's vote survives")
        #expect(options.first { $0.id == optionB }?.hasVoted == false)
        #expect(merged.userPollVote == optionA)
    }

    // MARK: - The reconciler's verdict survives the replacement

    /// Offering a count and then storing the payload are two acts, and the order
    /// is the bug. An out-of-order update is correctly *rejected* by the
    /// reconciler and then written to the loaded marker anyway by the wholesale
    /// replacement that follows.
    @Test
    func aRejectedOlderCountCannotBeWrittenBackByTheReplacement() throws {
        let manager = manager()
        let markerId = id(60)

        // Newer observation lands first.
        let newer = try #require(
            MarkerRevision(wire: "2026-09-09T10:00:00.500000Z")
        )
        _ = manager.responseCounts.apply(
            MarkerResponseCountUpdate(markerId: markerId, directResponseCount: 7, revision: newer)
        )

        // An older payload, still carrying its own stale count.
        let stale = makeMarkerDTO(
            id: markerId,
            author: member(2),
            symbolId: symbolId,
            directResponseCount: 2,
            responsesRevision: "2026-09-09T10:00:00.100000Z"
        )
        // The reconciler refuses it...
        manager.applyLinkCounts(from: stale)
        #expect(manager.responseCounts.count(for: markerId) == 7)

        // ...and the value that actually reaches the loaded marker must agree.
        let reconciled = manager.withReconciledCount(stale)
        #expect(
            reconciled.responseCount == 7,
            "the reconciler's verdict has to survive the replacement, not just precede it"
        )
        #expect(reconciled.responsesRevision == newer.wireText)
    }

    /// The counterpart: a genuinely newer payload is not clamped to the cache.
    @Test
    func aNewerCountIsAdoptedRatherThanClamped() {
        let manager = manager()
        let markerId = id(61)

        _ = manager.responseCounts.apply(
            MarkerResponseCountUpdate(
                markerId: markerId,
                directResponseCount: 3,
                revision: MarkerRevision(wire: "2026-09-09T10:00:00.100000Z")
            )
        )

        let fresher = makeMarkerDTO(
            id: markerId,
            author: member(2),
            symbolId: symbolId,
            directResponseCount: 11,
            responsesRevision: "2026-09-09T10:00:00.900000Z"
        )
        manager.applyLinkCounts(from: fresher)

        #expect(manager.withReconciledCount(fresher).responseCount == 11)
    }

    // MARK: - The fade invariant outranks the latch

    /// The rule is "suppress the fade below two visible members". The latch
    /// existed to stop progressive pages flickering the dim, but it also froze
    /// the decision across panning: two related glyphs visible, pan one off, and
    /// the chart stayed dimmed around a single lonely marker.
    @Test
    func panningAMemberOffScreenUndimsAndBackOnRedims() throws {
        let manager = manager()
        let parent = makeMarkerUI(id: id(70), author: member(1), responses: 1)
        let child = makeMarkerUI(
            id: id(71),
            author: member(2),
            parentMarkerId: id(70),
            relationship: "supports"
        )
        let bystander = makeMarkerUI(id: id(72), author: member(2))
        manager.markers = [parent, child, bystander]
        manager.selectedMarker = parent

        // Two members painted: the fade is on.
        manager.reportRenderedMarkers([id(70), id(71)], forSelection: id(70))
        #expect(try #require(manager.linkFocus).shouldFadeUnrelated)

        // One painted: the invariant says suppress, latch or no latch.
        manager.reportRenderedMarkers([id(70)], forSelection: id(70))
        #expect(
            !(try #require(manager.linkFocus).shouldFadeUnrelated),
            "a lone visible member must not sit in a dimmed chart"
        )

        // Back to two: it returns.
        manager.reportRenderedMarkers([id(70), id(71)], forSelection: id(70))
        #expect(try #require(manager.linkFocus).shouldFadeUnrelated)
    }

    /// The report is dispatched to the main actor from inside a draw pass, so
    /// the selection can move before it lands. A report about the previous
    /// thesis would otherwise install that thesis's painted set as the new one's
    /// — and the fade decision derived from it would be about the wrong markers.
    @Test
    func aReportFromAPriorSelectionIsIgnored() throws {
        let manager = manager()
        let parent = makeMarkerUI(id: id(80), author: member(1), responses: 1)
        let child = makeMarkerUI(
            id: id(81),
            author: member(2),
            parentMarkerId: id(80),
            relationship: "supports"
        )
        let elsewhere = makeMarkerUI(id: id(82), author: member(2), responses: 1)
        let elsewhereChild = makeMarkerUI(
            id: id(83),
            author: member(1),
            parentMarkerId: id(82),
            relationship: "challenges"
        )
        manager.markers = [parent, child, elsewhere, elsewhereChild]

        manager.selectedMarker = parent
        manager.reportRenderedMarkers([id(80), id(81)], forSelection: id(80))
        #expect(manager.renderedMarkerIds == [id(80), id(81)])

        // Selection moves to an unrelated thesis; a late frame reports the old one.
        manager.selectedMarker = elsewhere
        #expect(manager.renderedMarkerIds == nil, "a new selection starts with no painted set")

        manager.reportRenderedMarkers([id(80), id(81)], forSelection: id(80))
        #expect(
            manager.renderedMarkerIds == nil,
            "a report tagged with the previous selection must not apply to this one"
        )

        // The correctly tagged report still works.
        manager.reportRenderedMarkers([id(82), id(83)], forSelection: id(82))
        #expect(manager.renderedMarkerIds == [id(82), id(83)])
    }

    // MARK: - Row highlighting follows selection, not window provenance

    /// One window is shared by every marker in a thesis, and its
    /// `requestedMarkerId` records which marker it was first built for — cursor
    /// provenance depends on that staying put. Deriving the highlight from it
    /// leaves the original row marked current however far the viewer walks.
    @Test
    func highlightFollowsTheSelectionOnARetainedWindow() throws {
        let window = MarkerThreadWindow(
            page: page(
                requested: 1,
                windowRoot: "root",
                nodes: [
                    node("root", marker: 1, responses: 1),
                    node("c", parent: "root", marker: 2)
                ],
                rootMarker: 1,
                rootResolved: true
            )
        )

        let atRoot = window.displayRows(selectedMarkerId: id(1))
        #expect(atRoot.first { $0.isRequested }?.node.nodeKey == "root")

        // Same window, viewer has walked to the child.
        let atChild = window.displayRows(selectedMarkerId: id(2))
        #expect(
            atChild.first { $0.isRequested }?.node.nodeKey == "c",
            "the highlight must move with the selection, not stay on the window's origin"
        )
        #expect(atChild.filter(\.isRequested).count == 1, "exactly one row is current")

        // Provenance is untouched by any of this.
        #expect(window.requestedMarkerId == id(1))
    }
}

// MARK: - Shared fixtures

private func makeMarkerDTO(
    id: UUID,
    author: RLGuildMemberDTO,
    symbolId: UUID,
    isCurrentUserMarker: Bool = false,
    canEdit: Bool = false,
    canDelete: Bool = false,
    pollOptions: [RLPollOptionDTO]? = nil,
    userPollVote: UUID? = nil,
    parentMarkerId: UUID? = nil,
    linkRelationship: String? = nil,
    directResponseCount: Int? = nil,
    responsesRevision: String? = nil
) -> RLChartMarkerDTO {
    RLChartMarkerDTO(
        id: id,
        symbolId: symbolId,
        guildId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        author: author,
        candleTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
        timeframe: "1h",
        price: 100,
        intent: "analysis",
        title: "Marker",
        note: nil,
        visibility: "guild",
        confidence: nil,
        trackingEnabled: false,
        trackingState: nil,
        alertSeverity: nil,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        createdAtFormatted: "just now",
        isVisible: true,
        likeCount: 0,
        isLikedByCurrentUser: false,
        commentCount: 0,
        comments: [],
        isCurrentUserMarker: isCurrentUserMarker,
        canEdit: canEdit,
        canDelete: canDelete,
        components: [],
        primaryComponentId: nil,
        pollQuestion: pollOptions == nil ? nil : "Which way?",
        pollOptions: pollOptions,
        userPollVote: userPollVote,
        predictionResult: nil,
        parentMarkerId: parentMarkerId,
        linkRelationship: linkRelationship,
        parentPreview: nil,
        directResponseCount: directResponseCount,
        responsesRevision: responsesRevision
    )
}

private func makeMarkerUI(
    id: UUID,
    author: RLGuildMemberDTO,
    parentMarkerId: UUID? = nil,
    relationship: String? = nil,
    responses: Int = 0
) -> ChartMarkerUI {
    var ui = ChartMarkerUI(
        marker: makeMarkerDTO(
            id: id,
            author: author,
            symbolId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            parentMarkerId: parentMarkerId,
            linkRelationship: relationship,
            directResponseCount: responses
        ),
        candleIndex: 0
    )
    ui.hasStableLayout = true
    return ui
}

/// `MarkerDeletedPayload` is decode-only, so the fixture goes through JSON —
/// which also proves the additive fields decode from the wire spelling.
private func decodeDeletePayload(
    markerId: UUID,
    guildId: UUID,
    symbolId: UUID,
    parentMarkerId: UUID
) -> MarkerDeletedPayload? {
    let json = """
    {
      "marker_id": "\(markerId.uuidString)",
      "guild_id": "\(guildId.uuidString)",
      "symbol_id": "\(symbolId.uuidString)",
      "parent_marker_id": "\(parentMarkerId.uuidString)",
      "parent_direct_response_count": 4,
      "parent_responses_revision": "2026-09-09T10:00:00.400000Z"
    }
    """
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try? decoder.decode(MarkerDeletedPayload.self, from: Data(json.utf8))
}
