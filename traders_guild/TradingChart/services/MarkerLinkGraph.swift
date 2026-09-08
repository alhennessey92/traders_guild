//
//  MarkerLinkGraph.swift
//  traders_guild
//
//  Pure link topology over the markers currently loaded on the chart.
//
//  Focus is deliberately *synchronous and local*: it is derived from what the
//  chart already holds, never from a network round-trip, so selecting a marker
//  highlights instantly and can never leave the chart in a half-dimmed state
//  waiting on a request.
//

import Foundation

/// The minimum a marker must expose to take part in link topology. Keeping this
/// separate from `ChartMarkerUI` is what lets the graph be unit-tested without
/// constructing chart geometry, candles or DTOs.
struct MarkerLinkNode: Equatable, Hashable {
    let id: UUID
    let parentId: UUID?
    let relationship: MarkerLinkRelationshipValue?
    let directResponseCount: Int

    init(
        id: UUID,
        parentId: UUID? = nil,
        relationship: MarkerLinkRelationshipValue? = nil,
        directResponseCount: Int = 0
    ) {
        self.id = id
        self.parentId = parentId
        self.relationship = relationship
        self.directResponseCount = directResponseCount
    }

    /// Takes part in a thesis at all — either it answers something, or something
    /// answers it. A plain marker is neither and must keep 1.2.1 behaviour.
    var isLinked: Bool {
        parentId != nil || directResponseCount > 0
    }
}

/// How a drawn edge relates to the selected marker.
enum MarkerLinkEdgeKind: Equatable {
    /// From the selected marker up to the marker it answers.
    case parentOfSelected
    /// From the selected marker down to one of its direct responses.
    case childOfSelected
}

/// A candidate connector. Geometry decides whether it can actually be drawn.
struct MarkerLinkEdge: Equatable, Hashable {
    /// The marker being answered.
    let parentId: UUID
    /// The marker doing the answering.
    let childId: UUID
    /// The child's relationship to the parent; nil when unknown to this build.
    let relationship: MarkerLinkRelationshipValue?
    let kind: MarkerLinkEdgeKind

    func hash(into hasher: inout Hasher) {
        hasher.combine(parentId)
        hasher.combine(childId)
    }

    static func == (lhs: MarkerLinkEdge, rhs: MarkerLinkEdge) -> Bool {
        lhs.parentId == rhs.parentId && lhs.childId == rhs.childId
    }
}

/// What ring, if any, a marker wears while focus is active.
enum MarkerLinkRingStyle: Equatable {
    /// A marker that starts a thesis: no parent, and at least one response.
    case root
    /// A response: ringed in its own relationship colour.
    case response(MarkerLinkRelationshipValue?)
}

/// The complete, synchronously-derived focus decision for one selection.
struct MarkerFocusState: Equatable {
    let selectedId: UUID
    /// Every marker in the selected marker's connected component, including it.
    let memberIds: Set<UUID>
    /// Members that are actually being rendered right now.
    let visibleMemberIds: Set<UUID>
    /// Whether unrelated markers should drop to the dim opacity.
    let shouldFadeUnrelated: Bool
    /// Candidate connectors, parent first then children. Geometry may drop some.
    let candidateEdges: [MarkerLinkEdge]

    /// A selection that participates in no thesis: the chart must behave exactly
    /// as it did in 1.2.1 — no fade, no rings, no connectors.
    static func standalone(selectedId: UUID) -> MarkerFocusState {
        MarkerFocusState(
            selectedId: selectedId,
            memberIds: [selectedId],
            visibleMemberIds: [selectedId],
            shouldFadeUnrelated: false,
            candidateEdges: []
        )
    }

    var isActive: Bool { memberIds.count > 1 || !candidateEdges.isEmpty }
}

/// Link topology over a set of loaded markers.
struct MarkerLinkGraph: Equatable {
    /// Opacity applied to markers outside the focused thesis.
    static let unrelatedOpacity: Double = 0.22

    /// Below this many *visible* thesis members there is nothing to compare, so
    /// dimming the rest of the chart would communicate nothing and would read as
    /// a rendering fault. The selected marker counts toward this.
    static let minimumVisibleMembersForFade = 2

    /// Hard ceiling on drawn connectors, before geometry rejects any.
    static let maximumEdges = 12

    private let nodesById: [UUID: MarkerLinkNode]
    private let childIdsByParent: [UUID: [UUID]]

    init(nodes: [MarkerLinkNode]) {
        var byId: [UUID: MarkerLinkNode] = [:]
        var children: [UUID: [UUID]] = [:]
        byId.reserveCapacity(nodes.count)
        for node in nodes {
            byId[node.id] = node
        }
        // Only keep edges whose parent is also loaded; a node whose parent is
        // off-window is not a root, it simply has no drawable parent edge.
        for node in nodes {
            guard let parentId = node.parentId, byId[parentId] != nil else { continue }
            children[parentId, default: []].append(node.id)
        }
        nodesById = byId
        childIdsByParent = children
    }

    // MARK: - Topology

    func node(_ id: UUID) -> MarkerLinkNode? { nodesById[id] }

    /// The parent, only when it is itself loaded.
    func loadedParent(of id: UUID) -> MarkerLinkNode? {
        guard let parentId = nodesById[id]?.parentId else { return nil }
        return nodesById[parentId]
    }

    func loadedChildren(of id: UUID) -> [MarkerLinkNode] {
        (childIdsByParent[id] ?? []).compactMap { nodesById[$0] }
    }

    /// A thesis starter: nothing above it, and something below it.
    func isRoot(_ id: UUID) -> Bool {
        guard let node = nodesById[id] else { return false }
        return node.parentId == nil && !(childIdsByParent[id] ?? []).isEmpty
    }

    /// The ring a marker wears in focus, or nil if it wears none.
    func ringStyle(for id: UUID) -> MarkerLinkRingStyle? {
        guard let node = nodesById[id] else { return nil }
        if node.parentId != nil {
            return .response(node.relationship)
        }
        return isRoot(id) ? .root : nil
    }

    /// Undirected connected component containing `id`, walking both parent and
    /// child links across the loaded set.
    func connectedComponent(containing id: UUID) -> Set<UUID> {
        guard nodesById[id] != nil else { return [] }
        var seen: Set<UUID> = [id]
        var queue: [UUID] = [id]

        while let current = queue.popLast() {
            if let parent = nodesById[current]?.parentId,
               nodesById[parent] != nil,
               seen.insert(parent).inserted {
                queue.append(parent)
            }
            for childId in childIdsByParent[current] ?? [] where seen.insert(childId).inserted {
                queue.append(childId)
            }
        }
        return seen
    }

    // MARK: - Focus

    /// Derive the focus decision for a selection.
    ///
    /// - Parameters:
    ///   - selectedId: the marker the user tapped.
    ///   - visibleIds: markers actually being rendered — already through
    ///     `filteredMarkers`, the current timeframe and viewport culling.
    func focusState(selectedId: UUID, visibleIds: Set<UUID>) -> MarkerFocusState {
        guard let selected = nodesById[selectedId], selected.isLinked else {
            return .standalone(selectedId: selectedId)
        }

        let members = connectedComponent(containing: selectedId)
        let visibleMembers = members.intersection(visibleIds)

        var edges: [MarkerLinkEdge] = []
        if let parent = loadedParent(of: selectedId) {
            edges.append(
                MarkerLinkEdge(
                    parentId: parent.id,
                    childId: selectedId,
                    relationship: selected.relationship,
                    kind: .parentOfSelected
                )
            )
        }
        for child in loadedChildren(of: selectedId) {
            edges.append(
                MarkerLinkEdge(
                    parentId: selectedId,
                    childId: child.id,
                    relationship: child.relationship,
                    kind: .childOfSelected
                )
            )
        }

        return MarkerFocusState(
            selectedId: selectedId,
            memberIds: members,
            visibleMemberIds: visibleMembers,
            shouldFadeUnrelated: visibleMembers.count >= Self.minimumVisibleMembersForFade,
            candidateEdges: edges
        )
    }
}
