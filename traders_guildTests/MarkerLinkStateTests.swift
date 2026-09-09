import Foundation
import Testing
@testable import traders_guild

/// Thesis cache lifecycle, placement link session, and count reconciliation.
struct MarkerLinkStateTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func node(
        _ key: String,
        parent: String? = nil,
        marker: Int? = nil,
        depth: Int = 0
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parent,
            markerId: marker.map(id),
            linkRelationship: parent == nil ? nil : "supports",
            depth: depth
        )
    }

    private func page(
        requested: Int,
        windowRoot: String,
        nodes: [RLMarkerLinkPreviewDTO],
        rootMarker: Int? = nil,
        rootKey: String? = nil,
        rootResolved: Bool = false,
        branches: [RLMarkerThreadBranchDTO] = []
    ) -> RLMarkerThreadResponseDTO {
        RLMarkerThreadResponseDTO(
            requestedMarkerId: id(requested),
            rootMarkerId: rootMarker.map(id),
            rootKey: rootKey,
            rootResolved: rootResolved,
            windowRootKey: windowRoot,
            nodes: nodes,
            branches: branches,
            loadedCount: nodes.count
        )
    }

    // MARK: - Cache lifecycle

    /// The chart clears every marker on a timeframe change. The thesis must
    /// survive that, or following a response onto another timeframe would throw
    /// away the thread the user was reading.
    @MainActor
    @Test
    func threadSurvivesTimeframeChange() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))

        store.ingest(
            page: page(
                requested: 2,
                windowRoot: "a",
                nodes: [node("a", marker: 1), node("b", parent: "a", marker: 2, depth: 1)],
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true
            ),
            requestedMarkerId: id(2)
        )

        // Simulate what a timeframe change does to the chart: markers are gone,
        // but the store is untouched because it is not scoped to layout.
        #expect(store.window(forMarkerId: id(2)) != nil)
        #expect(store.window(forMarkerId: id(1)) != nil, "any node in the thesis reaches the same window")
        #expect(store.sharesThesis(id(1), id(2)))
    }

    /// Provisional keys are promoted once ancestry resolves a real root, and
    /// every marker that pointed at the old key follows.
    @MainActor
    @Test
    func provisionalKeyIsPromotedToConfirmedRoot() {
        let store = MarkerThreadStore()

        store.ingest(
            page: page(requested: 2, windowRoot: "b", nodes: [node("b", marker: 2)]),
            requestedMarkerId: id(2)
        )
        #expect(store.cacheKey(forMarkerId: id(2)) == .provisional(id(2)))

        store.setExpanded(true, forMarkerId: id(2))

        store.ingest(
            page: page(
                requested: 2,
                windowRoot: "a",
                nodes: [node("a", marker: 1), node("b", parent: "a", marker: 2, depth: 1)],
                rootMarker: 1,
                rootKey: "a",
                rootResolved: true
            ),
            requestedMarkerId: id(2)
        )

        #expect(store.cacheKey(forMarkerId: id(2)) == .confirmedRoot(id(1)))
        #expect(store.cacheKey(forMarkerId: id(1)) == .confirmedRoot(id(1)))
        #expect(store.isExpanded(forMarkerId: id(2)), "an open disclosure survives promotion")
        #expect(store.window(forMarkerId: id(2))?.loadedCount == 2)
    }

    @MainActor
    @Test
    func guildChangeClearsTheCacheAndAdvancesGeneration() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))
        store.ingest(
            page: page(requested: 1, windowRoot: "a", nodes: [node("a", marker: 1)]),
            requestedMarkerId: id(1)
        )
        let before = store.generation
        #expect(store.window(forMarkerId: id(1)) != nil)

        store.activate(accountId: id(900), guildId: id(902))

        #expect(store.window(forMarkerId: id(1)) == nil)
        #expect(store.generation > before)
    }

    /// A staged selection is only restored within the generation that staged
    /// it, so an invalidation cannot resurrect a stale target.
    @MainActor
    @Test
    func pendingNavigationIsDiscardedAcrossInvalidation() {
        let store = MarkerThreadStore()
        store.activate(accountId: id(900), guildId: id(901))
        store.stagePendingNavigation(markerId: id(5))
        #expect(store.consumePendingNavigation()?.markerId == id(5))

        store.stagePendingNavigation(markerId: id(6))
        store.invalidateAll(reason: .reconnect)
        #expect(store.consumePendingNavigation() == nil)
    }

    @MainActor
    @Test
    func invalidatingOneThesisLeavesOthersAlone() {
        let store = MarkerThreadStore()
        store.ingest(
            page: page(requested: 1, windowRoot: "a", nodes: [node("a", marker: 1)]),
            requestedMarkerId: id(1)
        )
        store.ingest(
            page: page(requested: 10, windowRoot: "z", nodes: [node("z", marker: 10)]),
            requestedMarkerId: id(10)
        )

        store.invalidateThesis(containing: id(1))
        #expect(store.window(forMarkerId: id(1)) == nil)
        #expect(store.window(forMarkerId: id(10)) != nil)
    }

    // MARK: - Placement link session

    private func context(_ relationship: MarkerLinkRelationship = .supports) -> MarkerLinkContext {
        MarkerLinkContext(
            parentMarkerId: id(1),
            parentGuildId: id(100),
            parentSymbolId: id(200),
            parentCandleTimestamp: Date(timeIntervalSinceReferenceDate: 0),
            parentAuthorDisplayText: "alex",
            parentTitle: "BTC breakout",
            relationship: relationship
        )
    }

    /// The whole point of retaining a failed draft: a rejected submission must
    /// not cost the author the response they just composed.
    @Test
    func failedSubmissionKeepsTheDraft() {
        var session = MarkerLinkSession()
        session.begin(context(), currentVisibility: "private")
        session.recordFailure("Placement Failed")

        #expect(session.isActive)
        #expect(session.context?.parentMarkerId == id(1))
        #expect(session.lastFailureMessage == "Placement Failed")

        // Retrying and succeeding ends it.
        session.end(.submitted)
        #expect(!session.isActive)
        #expect(session.lastFailureMessage == nil)
    }

    /// Removing the link restores whatever the marker type would ordinarily
    /// default to, rather than leaving it stuck on the guild visibility the
    /// link forced.
    @Test
    func removingTheLinkRestoresPreLinkVisibility() {
        var session = MarkerLinkSession()
        session.begin(context(), currentVisibility: "private")
        #expect(session.lockedVisibility == "guild")

        let restored = session.end(.removedByAuthor)
        #expect(restored == "private")
        #expect(session.lockedVisibility == nil)
    }

    @Test
    func submittingDoesNotRestoreVisibility() {
        var session = MarkerLinkSession()
        session.begin(context(), currentVisibility: "private")
        #expect(session.end(.submitted) == nil)
    }

    @Test
    func relationshipChangesButParentIdentityDoesNot() {
        var session = MarkerLinkSession()
        session.begin(context(.supports), currentVisibility: "guild")
        session.changeRelationship(.challenges)

        #expect(session.context?.relationship == .challenges)
        #expect(session.context?.parentMarkerId == id(1), "parent identity is immutable")
    }

    @Test
    func sessionEndsWhenTheChartLeavesTheParentsContext() {
        var session = MarkerLinkSession()
        session.begin(context(), currentVisibility: "guild")

        // Hoisted: `#expect` captures its operand immutably, so a mutating call
        // cannot be made inside the macro.
        let sameContext = session.endIfUnrelated(guildId: id(100), symbolId: id(200))
        #expect(!sameContext)
        #expect(session.isActive)

        let otherSymbol = session.endIfUnrelated(guildId: id(100), symbolId: id(999))
        #expect(otherSymbol)
        #expect(!session.isActive)
    }

    @Test
    func bannerSentenceReadsAsASentence() {
        #expect(context(.supports).bannerSentence == "Supports alex's BTC breakout")
        #expect(context(.buildsOn).bannerSentence == "Builds on alex's BTC breakout")
    }

    // MARK: - Count reconciliation

    /// Events arrive out of order. An older revision must never roll a badge
    /// backwards.
    @Test
    func outOfOrderCountsAreRejected() {
        var reconciler = MarkerResponseCountReconciler()
        // Microsecond-exact revisions, not Dates: Foundation rounds these to
        // milliseconds and would collapse adjacent server revisions.
        let early = MarkerRevision(microsecondsSinceEpoch: 100_000_000)
        let late = MarkerRevision(microsecondsSinceEpoch: 200_000_000)

        #expect(reconciler.apply(.init(markerId: id(1), directResponseCount: 5, revision: late)) == .applied(5))
        #expect(reconciler.apply(.init(markerId: id(1), directResponseCount: 4, revision: early)) == .stale)
        #expect(reconciler.count(for: id(1)) == 5)

        // A newer revision wins.
        let later = MarkerRevision(microsecondsSinceEpoch: 300_000_000)
        #expect(reconciler.apply(.init(markerId: id(1), directResponseCount: 6, revision: later)) == .applied(6))
        #expect(reconciler.count(for: id(1)) == 6)
    }

    @Test
    func repeatedRevisionCannotFlipAValue() {
        var reconciler = MarkerResponseCountReconciler()
        let revision = MarkerRevision(microsecondsSinceEpoch: 100_000_000)
        _ = reconciler.apply(.init(markerId: id(1), directResponseCount: 3, revision: revision))
        #expect(reconciler.apply(.init(markerId: id(1), directResponseCount: 9, revision: revision)) == .unchanged(3))
        #expect(reconciler.count(for: id(1)) == 3)
    }

    @Test
    func unversionedCannotSupersedeVersioned() {
        var reconciler = MarkerResponseCountReconciler()
        _ = reconciler.apply(
            .init(markerId: id(1), directResponseCount: 3, revision: MarkerRevision(microsecondsSinceEpoch: 100_000_000))
        )
        #expect(reconciler.apply(.init(markerId: id(1), directResponseCount: 1, revision: nil)) == .stale)
        #expect(reconciler.count(for: id(1)) == 3)
    }

    @Test
    func versionedSupersedesUnversioned() {
        var reconciler = MarkerResponseCountReconciler()
        _ = reconciler.apply(.init(markerId: id(1), directResponseCount: 1, revision: nil))
        #expect(
            reconciler.apply(
                .init(markerId: id(1), directResponseCount: 7, revision: MarkerRevision(microsecondsSinceEpoch: 100_000_000))
            ) == .applied(7)
        )
    }

    @Test
    func forgettingAMarkerDropsItsCount() {
        var reconciler = MarkerResponseCountReconciler()
        _ = reconciler.apply(.init(markerId: id(1), directResponseCount: 2, revision: nil))
        reconciler.forget(id(1))
        #expect(reconciler.count(for: id(1)) == nil)
    }
}
