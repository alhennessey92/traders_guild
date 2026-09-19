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
///
/// Only used for ordering and for the reveal. Every loaded edge of the focused
/// thesis is a candidate — a response-of-a-response is a connection the reader
/// needs to see just as much as the selected marker's own — so the kinds are
/// priorities, not a filter.
enum MarkerLinkEdgeKind: Equatable {
    /// From the selected marker up to the marker it answers.
    case parentOfSelected
    /// From the selected marker down to one of its direct responses.
    case childOfSelected
    /// Any other parent→child edge inside the focused thesis: a sibling's
    /// response, a grandchild, a branch two levels away.
    case withinThesis
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
    /// The child's real parent is gone (soft-deleted) and `parentId` is the
    /// nearest surviving ancestor. Drawn fainter, so the reader sees "linked
    /// through a deleted marker" rather than a direct answer.
    var viaUnavailable: Bool = false

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
    /// Candidate connectors: the selected marker's parent edge, then its child
    /// edges, then every other loaded edge of the thesis. Geometry may drop an
    /// edge only when no safe path exists for it.
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

    /// A thesis selection: the chart fades what is unrelated and shows what
    /// is. A marker whose only links are on other timeframes — or scrolled out
    /// of the loaded window — still counts: its badge is the link, and the
    /// fade is what makes the badge read. Only `.standalone` is inactive.
    var isActive: Bool { shouldFadeUnrelated || memberIds.count > 1 || !candidateEdges.isEmpty }
}

/// A loaded marker whose real parent is gone, tied to the nearest ancestor
/// that is loaded. Resolved by the manager from the thesis window (which
/// still lists the deleted marker as a tombstone) and handed to the graph,
/// which treats it as the child's parent link for topology and drawing.
struct MarkerLinkBridge: Equatable, Hashable {
    let childId: UUID
    let ancestorId: UUID
}

/// Link topology over a set of loaded markers.
struct MarkerLinkGraph: Equatable {
    /// Opacity applied to markers outside the focused thesis.
    static let unrelatedOpacity: Double = 0.22

    private let nodesById: [UUID: MarkerLinkNode]
    private let childIdsByParent: [UUID: [UUID]]
    /// Child → ancestor for every bridge in effect.
    private let bridgedParentById: [UUID: UUID]

    init(nodes: [MarkerLinkNode], bridges: [MarkerLinkBridge] = []) {
        var byId: [UUID: MarkerLinkNode] = [:]
        var children: [UUID: [UUID]] = [:]
        var bridged: [UUID: UUID] = [:]
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
        // A bridge stands in for a parent that is not here. Never for one that
        // is: the real edge wins, and a loaded parent is not a tombstone.
        for bridge in bridges {
            guard let child = byId[bridge.childId],
                  byId[bridge.ancestorId] != nil,
                  bridge.ancestorId != bridge.childId,
                  let realParent = child.parentId,
                  byId[realParent] == nil,
                  bridged[bridge.childId] == nil else { continue }
            bridged[bridge.childId] = bridge.ancestorId
            children[bridge.ancestorId, default: []].append(bridge.childId)
        }
        nodesById = byId
        childIdsByParent = children
        bridgedParentById = bridged
    }

    // MARK: - Topology

    func node(_ id: UUID) -> MarkerLinkNode? { nodesById[id] }

    /// The parent this graph draws for `id`: the real one when loaded, else the
    /// bridged ancestor, else nil.
    private func effectiveParentId(of id: UUID) -> UUID? {
        if let ancestor = bridgedParentById[id] { return ancestor }
        guard let parentId = nodesById[id]?.parentId, nodesById[parentId] != nil else { return nil }
        return parentId
    }

    func isBridged(_ id: UUID) -> Bool { bridgedParentById[id] != nil }

    /// The parent, only when it is itself loaded — or the bridged ancestor.
    func loadedParent(of id: UUID) -> MarkerLinkNode? {
        guard let parentId = effectiveParentId(of: id) else { return nil }
        return nodesById[parentId]
    }

    /// Every drawable parent→child edge among the loaded markers, bridges
    /// included: the idle chart's faint lines. Order is deterministic.
    var allEdges: [MarkerLinkEdge] {
        var edges: [MarkerLinkEdge] = []
        for parentId in childIdsByParent.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            for childId in childIdsByParent[parentId] ?? [] {
                guard let child = nodesById[childId] else { continue }
                edges.append(MarkerLinkEdge(
                    parentId: parentId,
                    childId: childId,
                    relationship: child.relationship,
                    kind: .withinThesis,
                    viaUnavailable: isBridged(childId)
                ))
            }
        }
        return edges
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
            if let parent = effectiveParentId(of: current),
               seen.insert(parent).inserted {
                queue.append(parent)
            }
            for childId in childIdsByParent[current] ?? [] where seen.insert(childId).inserted {
                queue.append(childId)
            }
        }
        return seen
    }

    /// Members of a component in breadth-first order from `origin`, so edges
    /// nearer the selection are listed — and therefore drawn — before farther
    /// ones. Deterministic: ties break on id.
    func membersByDistance(from origin: UUID, within members: Set<UUID>) -> [UUID] {
        guard members.contains(origin) else { return [] }
        var order: [UUID] = [origin]
        var seen: Set<UUID> = [origin]
        var frontier: [UUID] = [origin]
        while !frontier.isEmpty {
            var next: [UUID] = []
            for current in frontier {
                var neighbours: [UUID] = []
                if let parent = effectiveParentId(of: current), members.contains(parent) {
                    neighbours.append(parent)
                }
                neighbours.append(contentsOf: (childIdsByParent[current] ?? []).filter { members.contains($0) })
                for neighbour in neighbours.sorted(by: { $0.uuidString < $1.uuidString })
                where seen.insert(neighbour).inserted {
                    order.append(neighbour)
                    next.append(neighbour)
                }
            }
            frontier = next
        }
        return order
    }

    // MARK: - Focus

    /// Derive the focus decision for a selection.
    ///
    /// - Parameters:
    ///   - selectedId: the marker the user tapped.
    ///   - visibleIds: markers actually being rendered — already through
    ///     `filteredMarkers`, the current timeframe and viewport culling.
    func focusState(selectedId: UUID, visibleIds: Set<UUID>) -> MarkerFocusState {
        // Loaded topology counts as well as the reported figure. A marker's
        // `directResponseCount` can lag — that is the whole reason the count
        // reconciler exists — and a stale zero must not suppress focus on a
        // marker whose responses are visibly on screen.
        let hasLoadedChildren = !(childIdsByParent[selectedId] ?? []).isEmpty
        guard let selected = nodesById[selectedId],
              selected.isLinked || hasLoadedChildren else {
            return .standalone(selectedId: selectedId)
        }

        let members = connectedComponent(containing: selectedId)
        let visibleMembers = members.intersection(visibleIds)

        // The selected marker's own edges first, so they draw first and read
        // first; then every other loaded edge of the thesis, nearest branches
        // first. "Loaded" is the whole condition — this never reaches for the
        // network, and an edge whose parent is off-window simply is not here.
        var edges: [MarkerLinkEdge] = []
        var covered: Set<MarkerLinkEdge> = []
        if let parent = loadedParent(of: selectedId) {
            let edge = MarkerLinkEdge(
                parentId: parent.id,
                childId: selectedId,
                relationship: selected.relationship,
                kind: .parentOfSelected,
                viaUnavailable: isBridged(selectedId)
            )
            edges.append(edge)
            covered.insert(edge)
        }
        for child in loadedChildren(of: selectedId) {
            let edge = MarkerLinkEdge(
                parentId: selectedId,
                childId: child.id,
                relationship: child.relationship,
                kind: .childOfSelected,
                viaUnavailable: isBridged(child.id)
            )
            edges.append(edge)
            covered.insert(edge)
        }
        for memberId in membersByDistance(from: selectedId, within: members) {
            for child in loadedChildren(of: memberId) {
                let edge = MarkerLinkEdge(
                    parentId: memberId,
                    childId: child.id,
                    relationship: child.relationship,
                    kind: .withinThesis,
                    viaUnavailable: isBridged(child.id)
                )
                if covered.insert(edge).inserted {
                    edges.append(edge)
                }
            }
        }

        // Fade whenever a linked marker is selected. The rule used to need two
        // painted members, which left a response whose parent was off-screen
        // or on another timeframe sitting in an undimmed chart with nothing to
        // say it belonged to anything (production feedback, 1.3.0).
        return MarkerFocusState(
            selectedId: selectedId,
            memberIds: members,
            visibleMemberIds: visibleMembers,
            shouldFadeUnrelated: true,
            candidateEdges: edges
        )
    }
}
