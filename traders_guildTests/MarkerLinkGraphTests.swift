import Foundation
import Testing
@testable import traders_guild

/// Topology and focus rules for linked markers.
struct MarkerLinkGraphTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func supports() -> MarkerLinkRelationshipValue {
        MarkerLinkRelationshipValue(.supports)
    }

    // MARK: - Relationship tolerance

    @Test
    func knownRelationshipsResolve() {
        #expect(MarkerLinkRelationship(rawValue: "supports") == .supports)
        #expect(MarkerLinkRelationship(rawValue: "challenges") == .challenges)
        #expect(MarkerLinkRelationship(rawValue: "builds_on") == .buildsOn)
        #expect(MarkerLinkRelationship.buildsOn.rawValue == "builds_on")
    }

    /// A relationship this build has never heard of must stay renderable: the
    /// server may add one after we ship, and the marker still has to draw.
    @Test
    func unknownRelationshipStaysRenderable() {
        let value = MarkerLinkRelationshipValue(raw: "refutes_partially")
        #expect(value.known == nil)
        #expect(!value.isKnown)
        #expect(value.displayName == "Refutes partially")
        #expect(value.icon == "link")
        #expect(!value.dashPattern.isEmpty)
        #expect(value.sentence(subject: "Alex's setup") == "Refutes partially Alex's setup")
    }

    @Test
    func emptyOrMissingRelationshipIsAbsent() {
        #expect(MarkerLinkRelationshipValue.make(nil) == nil)
        #expect(MarkerLinkRelationshipValue.make("") == nil)
        #expect(MarkerLinkRelationshipValue.make("   ") == nil)
    }

    // MARK: - Topology

    @Test
    func rootIsAParentlessMarkerWithResponses() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 1),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports()),
        ])
        #expect(graph.isRoot(id(1)))
        #expect(!graph.isRoot(id(2)))
        #expect(graph.ringStyle(for: id(1)) == .root)
        #expect(graph.ringStyle(for: id(2)) == .response(supports()))
    }

    /// A marker with neither a parent nor responses is not part of any thesis
    /// and must keep 1.2.1 behaviour — no ring, no fade, no connectors.
    @Test
    func standaloneMarkerHasNoRingAndNoFocus() {
        let graph = MarkerLinkGraph(nodes: [MarkerLinkNode(id: id(1))])
        #expect(graph.ringStyle(for: id(1)) == nil)

        let focus = graph.focusState(selectedId: id(1), visibleIds: [id(1)])
        #expect(!focus.isActive)
        #expect(!focus.shouldFadeUnrelated)
        #expect(focus.candidateEdges.isEmpty)
    }

    /// A response whose parent is outside the loaded window is not a root — it
    /// simply has no drawable parent edge.
    @Test
    func responseWithUnloadedParentIsNotARoot() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(2), parentId: id(99), relationship: supports())
        ])
        #expect(!graph.isRoot(id(2)))
        #expect(graph.ringStyle(for: id(2)) == .response(supports()))
        #expect(graph.loadedParent(of: id(2)) == nil)

        let focus = graph.focusState(selectedId: id(2), visibleIds: [id(2)])
        #expect(focus.candidateEdges.isEmpty)
    }

    @Test
    func connectedComponentWalksBothDirections() {
        // 1 -> 2 -> 3, and 1 -> 4. Selecting 3 must reach all four.
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 2),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports(), directResponseCount: 1),
            MarkerLinkNode(id: id(3), parentId: id(2), relationship: supports()),
            MarkerLinkNode(id: id(4), parentId: id(1), relationship: supports()),
        ])
        #expect(graph.connectedComponent(containing: id(3)) == Set([id(1), id(2), id(3), id(4)]))
    }

    /// Two unrelated theses on the same chart must not bleed into each other.
    @Test
    func separateThesesStaySeparate() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 1),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports()),
            MarkerLinkNode(id: id(10), directResponseCount: 1),
            MarkerLinkNode(id: id(11), parentId: id(10), relationship: supports()),
        ])
        #expect(graph.connectedComponent(containing: id(1)) == Set([id(1), id(2)]))
        #expect(graph.connectedComponent(containing: id(10)) == Set([id(10), id(11)]))
    }

    // MARK: - Focus and the fade rule

    @Test
    func focusOffersParentEdgeFirstThenChildren() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 1),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports(), directResponseCount: 2),
            MarkerLinkNode(id: id(3), parentId: id(2), relationship: supports()),
            MarkerLinkNode(id: id(4), parentId: id(2), relationship: supports()),
        ])
        let focus = graph.focusState(selectedId: id(2), visibleIds: [id(1), id(2), id(3), id(4)])

        #expect(focus.candidateEdges.first?.kind == .parentOfSelected)
        #expect(focus.candidateEdges.first?.parentId == id(1))
        #expect(focus.candidateEdges.count == 3)
        #expect(focus.shouldFadeUnrelated)
    }

    // MARK: - Every loaded edge of the thesis

    /// The owner's requirement: selecting a responded thesis shows every
    /// connection among its loaded members, not only the selected marker's
    /// own. A grandchild's edge, a sibling's response, a branch two levels
    /// away — all of it, in that priority: mine first, then nearest.
    @Test
    func focusOffersEveryLoadedEdgeOfTheThesisNearestFirst() {
        // root(1) ── 2 ── 5 ── 7
        //         └─ 3 ── 6
        //         └─ 4
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 3),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports(), directResponseCount: 1),
            MarkerLinkNode(id: id(3), parentId: id(1), relationship: supports(), directResponseCount: 1),
            MarkerLinkNode(id: id(4), parentId: id(1), relationship: supports()),
            MarkerLinkNode(id: id(5), parentId: id(2), relationship: supports(), directResponseCount: 1),
            MarkerLinkNode(id: id(6), parentId: id(3), relationship: supports()),
            MarkerLinkNode(id: id(7), parentId: id(5), relationship: supports()),
        ])
        let all = Set((1...7).map(id))
        let focus = graph.focusState(selectedId: id(2), visibleIds: all)

        let pairs = focus.candidateEdges.map { ($0.parentId, $0.childId) }
        #expect(focus.candidateEdges.count == 6, "six parent→child edges exist; all six are offered")

        // Priority: the selected marker's own edges lead.
        #expect(pairs[0] == (id(1), id(2)))
        #expect(focus.candidateEdges[0].kind == .parentOfSelected)
        #expect(pairs[1] == (id(2), id(5)))
        #expect(focus.candidateEdges[1].kind == .childOfSelected)

        // Then the rest, every one of them, tagged as within the thesis.
        let rest = Set(focus.candidateEdges.dropFirst(2).map { "\($0.parentId)>\($0.childId)" })
        #expect(rest == Set([
            "\(id(1))>\(id(3))", "\(id(1))>\(id(4))",
            "\(id(3))>\(id(6))", "\(id(5))>\(id(7))"
        ]))
        #expect(focus.candidateEdges.dropFirst(2).allSatisfy { $0.kind == .withinThesis })

        // Nearest first among the rest: the grandchild edge 5→7 is one hop from
        // the selection's child, the cousin edge 3→6 is three hops away.
        let indexOf: (UUID, UUID) -> Int = { p, c in
            focus.candidateEdges.firstIndex { $0.parentId == p && $0.childId == c }!
        }
        #expect(indexOf(id(5), id(7)) < indexOf(id(3), id(6)))
    }

    /// No duplicate edges, whichever node is selected, and a separate thesis
    /// on the same chart contributes nothing.
    @Test
    func everyEdgeIsOfferedOnceAndOnlyFromTheSelectedThesis() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 1),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports(), directResponseCount: 1),
            MarkerLinkNode(id: id(3), parentId: id(2), relationship: supports()),
            MarkerLinkNode(id: id(10), directResponseCount: 1),
            MarkerLinkNode(id: id(11), parentId: id(10), relationship: supports()),
        ])
        for selected in [1, 2, 3] {
            let focus = graph.focusState(selectedId: id(selected), visibleIds: Set([1, 2, 3, 10, 11].map(id)))
            let keys = focus.candidateEdges.map { "\($0.parentId)>\($0.childId)" }
            #expect(Set(keys).count == keys.count, "no duplicates when \(selected) is selected")
            #expect(keys.count == 2)
            #expect(!keys.contains("\(id(10))>\(id(11))"), "the other thesis stays out")
        }
    }

    /// An edge whose other end is not loaded is not an edge — this never
    /// reaches for the network to complete it.
    @Test
    func unloadedEndpointsProduceNoEdge() {
        let graph = MarkerLinkGraph(nodes: [
            // 2's parent is 99, which is not loaded.
            MarkerLinkNode(id: id(2), parentId: id(99), relationship: supports(), directResponseCount: 1),
            MarkerLinkNode(id: id(3), parentId: id(2), relationship: supports()),
        ])
        let focus = graph.focusState(selectedId: id(3), visibleIds: [id(2), id(3)])
        #expect(focus.candidateEdges.count == 1)
        #expect(focus.candidateEdges.first?.parentId == id(2))
    }

    /// Dimming the whole chart to highlight a single glyph communicates nothing
    /// and reads as a rendering fault, so the fade needs two visible members.
    @Test
    func fadeSuppressedWhenOnlyOneRelatedGlyphVisible() {
        let graph = MarkerLinkGraph(nodes: [
            MarkerLinkNode(id: id(1), directResponseCount: 1),
            MarkerLinkNode(id: id(2), parentId: id(1), relationship: supports()),
        ])

        // Parent filtered out (for example the "mine" visibility mode).
        let hidden = graph.focusState(selectedId: id(2), visibleIds: [id(2)])
        #expect(!hidden.shouldFadeUnrelated)
        #expect(hidden.memberIds.count == 2, "membership is topological, not visual")
        #expect(hidden.visibleMemberIds == [id(2)])

        let shown = graph.focusState(selectedId: id(2), visibleIds: [id(1), id(2)])
        #expect(shown.shouldFadeUnrelated)
    }

    @Test
    func unrelatedOpacityMatchesContract() {
        #expect(MarkerLinkGraph.unrelatedOpacity == 0.22)
    }
}
