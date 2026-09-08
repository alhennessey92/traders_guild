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
        #expect(MarkerLinkGraph.maximumEdges == 12)
    }
}
