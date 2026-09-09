//
//  MarkerThreadWindow.swift
//  traders_guild
//
//  Pure, testable accumulation of the bounded thread pages that make up a
//  thesis. No networking, no SwiftUI, no app state — hand it pages, ask it for
//  rows.
//

import Foundation

/// How much of a thesis this window can honestly claim to hold.
///
/// The server returns bounded pages (max 200 nodes, max 32 ancestor steps), so a
/// window is almost never the whole thing. Nothing here ever reports a total the
/// server did not vouch for.
enum MarkerThreadCompleteness: Equatable {
    /// There is more thesis above the highest node we hold.
    case ancestryPending
    /// Ancestry is settled but at least one branch has unread responses.
    case branchesPending
    /// Ancestry reached a real root and every branch is exhausted.
    case complete
}

/// A count the UI may render. `atLeast` must be shown with a "+" or equivalent.
enum MarkerThreadCount: Equatable {
    case exact(Int)
    case atLeast(Int)

    var value: Int {
        switch self {
        case .exact(let n), .atLeast(let n): return n
        }
    }

    var isExact: Bool {
        if case .exact = self { return true }
        return false
    }

    /// "12" or "12+".
    var displayText: String {
        switch self {
        case .exact(let n): return "\(n)"
        case .atLeast(let n): return "\(n)+"
        }
    }
}

/// One flattened row for the thesis list, with a depth computed from the merged
/// tree rather than trusted from any single page.
struct MarkerThreadRow: Equatable, Identifiable {
    let node: RLMarkerLinkPreviewDTO
    /// Depth within the merged window: 0 for the window root.
    let depth: Int
    /// True when this row is the marker the sheet is currently showing.
    let isRequested: Bool
    /// A resumable cursor exists for this node's children.
    let hasMoreResponses: Bool

    var id: String { node.nodeKey }
}

/// Accumulates bounded thread pages into one coherent, progressively growing
/// view of a thesis.
///
/// Merge rules, all from the 1.3.0 contract:
/// - nodes are merged by `nodeKey`, never appended blindly;
/// - a re-sent node replaces its stored copy but keeps its sibling position;
/// - branch page depths are **recomputed** from `parentKey` rather than rebased
///   arithmetically, so a page whose depths are relative to its own window root
///   cannot corrupt the tree;
/// - root identity latches once resolved and is never un-resolved by a later
///   page;
/// - a branch cursor survives until the server omits it, which is the only
///   signal that the branch is exhausted.
struct MarkerThreadWindow: Equatable {
    let requestedMarkerId: UUID

    private(set) var windowRootKey: String
    private(set) var rootMarkerId: UUID?
    private(set) var rootKey: String?
    private(set) var rootResolved: Bool

    private(set) var nodesByKey: [String: RLMarkerLinkPreviewDTO]
    /// Ordered child keys per parent key. `nil` parent holds detached window roots.
    private(set) var childKeysByParent: [String: [String]]
    private(set) var orphanRootKeys: [String]

    private(set) var ancestorCursor: String?
    private(set) var branchCursors: [String: String]
    private(set) var serverTotalCount: Int?
    private(set) var truncated: Bool

    // MARK: - Construction

    init(page: RLMarkerThreadResponseDTO, consumedBranchKey: String? = nil) {
        requestedMarkerId = page.requestedMarkerId
        windowRootKey = page.windowRootKey
        rootMarkerId = nil
        rootKey = nil
        rootResolved = false
        nodesByKey = [:]
        childKeysByParent = [:]
        orphanRootKeys = []
        ancestorCursor = nil
        branchCursors = [:]
        serverTotalCount = nil
        truncated = false
        merge(page: page, consumedBranchKey: consumedBranchKey)
    }

    // MARK: - Merging

    /// Fold another bounded page into this window.
    ///
    /// - Parameter consumedBranchKey: the branch whose cursor was spent to
    ///   fetch this page, when it was a branch continuation. This is the only
    ///   reliable way to know a branch is exhausted: the server includes the
    ///   anchor plus its direct children in a branch window, so the *absence*
    ///   of a replacement cursor for that anchor means there is no more to
    ///   read. Counting rows cannot substitute — `directResponseCount` excludes
    ///   deleted children while the returned rows include their tombstones, so
    ///   the two never reconcile and the cursor would live forever.
    mutating func merge(
        page: RLMarkerThreadResponseDTO,
        consumedBranchKey: String? = nil
    ) {
        // Root identity latches. An ancestry continuation may resolve the root;
        // a later branch page that does not know about it must not clear it.
        if page.rootResolved {
            rootResolved = true
            if let id = page.rootMarkerId { rootMarkerId = id }
            if let key = page.rootKey { rootKey = key }
        } else {
            if rootMarkerId == nil, let id = page.rootMarkerId { rootMarkerId = id }
            if rootKey == nil, let key = page.rootKey { rootKey = key }
        }

        // The window root only ever moves *upward*: an ancestry page introduces
        // a higher root, a branch page must not pull it back down.
        if isNewWindowRootHigher(page.windowRootKey, incomingNodes: page.nodes) {
            windowRootKey = page.windowRootKey
        }

        // Nodes first, then sibling order. Order is merged per parent from the
        // page's own sequence rather than appended, so a page that arrives
        // carrying earlier siblings than ones already held still lands in the
        // server's chronological order.
        for node in page.nodes {
            insert(node)
        }
        mergeSiblingOrder(from: page.nodes)

        // Ancestry cursor is authoritative per ancestry page. A branch page
        // never speaks about ancestry, and sends nil, so only adopt nil from a
        // page that actually carried ancestry (one whose nodes include the
        // current window root's parent chain) — otherwise a branch page would
        // falsely declare ancestry complete.
        if page.ancestorCursor != nil {
            ancestorCursor = page.ancestorCursor
        } else if pageCarriesAncestry(page) {
            ancestorCursor = nil
        }

        // A returned entry replaces the stored one: it represents the
        // *remaining* siblings, not the whole set.
        let returnedKeys = Set(page.branches.map(\.nodeKey))
        for branch in page.branches {
            branchCursors[branch.nodeKey] = branch.cursor
        }

        // Exhaustion is decided by consumed-branch identity alone. If this page
        // was fetched by spending a branch's cursor and the server did not hand
        // back a replacement for that same branch, that branch is finished.
        if let consumedBranchKey, !returnedKeys.contains(consumedBranchKey) {
            branchCursors[consumedBranchKey] = nil
        }

        if let total = page.totalCount {
            serverTotalCount = total
        }
        truncated = truncated || page.truncated
    }

    /// Marks a branch as consumed without a server round-trip. Used when a page
    /// request fails permanently and the UI must stop offering "load more".
    mutating func dropBranchCursor(for nodeKey: String) {
        branchCursors[nodeKey] = nil
    }

    /// Store the node. Sibling *position* is decided separately, by
    /// `mergeSiblingOrder`, so a re-sent node keeps its place.
    private mutating func insert(_ node: RLMarkerLinkPreviewDTO) {
        nodesByKey[node.nodeKey] = node
    }

    /// Splice each page's sibling sequences into the ones already held, using
    /// shared keys as anchors.
    ///
    /// Append-only merging was wrong. A deep-link opens on a node the server
    /// must include, so the initial window can carry a *late* sibling; paging
    /// that branch afterwards returns its *earlier* siblings, which appending
    /// would file after the late one and reverse the order the contract
    /// promises. Tombstones carry no `createdAt`, so sorting by timestamp is
    /// not available either — the server's per-page sequence is the only
    /// authority, and this preserves it.
    private mutating func mergeSiblingOrder(from nodes: [RLMarkerLinkPreviewDTO]) {
        var sequences: [String: [String]] = [:]
        var rootSequence: [String] = []

        for node in nodes {
            if let parentKey = node.parentKey {
                sequences[parentKey, default: []].append(node.nodeKey)
            } else {
                rootSequence.append(node.nodeKey)
            }
        }

        for (parentKey, incoming) in sequences {
            childKeysByParent[parentKey] = Self.anchoredMerge(
                existing: childKeysByParent[parentKey] ?? [],
                incoming: incoming
            )
        }
        if !rootSequence.isEmpty {
            orphanRootKeys = Self.anchoredMerge(existing: orphanRootKeys, incoming: rootSequence)
        }
    }

    /// Merge two orderings of the same sibling set, preserving both.
    ///
    /// Keys present in `existing` act as anchors: the cursor jumps to just past
    /// each one, so new keys arriving before an anchor are inserted before it,
    /// and new keys after an anchor follow it. With no overlap at all, the
    /// incoming sequence lands ahead of what is held — which is the deep-link
    /// case, where everything already held is later than what just arrived.
    static func anchoredMerge(existing: [String], incoming: [String]) -> [String] {
        guard !incoming.isEmpty else { return existing }
        guard !existing.isEmpty else { return incoming }

        var result = existing
        var cursor = 0

        for key in incoming {
            if let index = result.firstIndex(of: key) {
                cursor = index + 1
            } else {
                result.insert(key, at: min(cursor, result.count))
                cursor += 1
            }
        }
        return result
    }

    /// A page introduces a higher window root when it contains a node that is an
    /// ancestor of our current root — i.e. our current root now has a parent we
    /// hold.
    private func isNewWindowRootHigher(
        _ candidate: String,
        incomingNodes: [RLMarkerLinkPreviewDTO]
    ) -> Bool {
        guard candidate != windowRootKey else { return false }
        // The candidate is higher if our current window root descends from it
        // once these nodes are folded in.
        var lookup = nodesByKey
        for node in incomingNodes { lookup[node.nodeKey] = node }

        var cursor: String? = windowRootKey
        var guard_ = 0
        while let key = cursor, guard_ < Self.maxAncestryWalk {
            if key == candidate { return true }
            cursor = lookup[key]?.parentKey
            guard_ += 1
        }
        return false
    }

    /// True when the page walked ancestry — it carries the current window root
    /// or one of its ancestors.
    private func pageCarriesAncestry(_ page: RLMarkerThreadResponseDTO) -> Bool {
        page.nodes.contains { $0.nodeKey == windowRootKey || $0.parentKey == nil }
    }

    // MARK: - Derived state

    static let maxAncestryWalk = 512

    /// Every structural row this window holds, tombstones included. This is a
    /// *structural* figure — never present it as a contribution count.
    var loadedCount: Int { nodesByKey.count }

    /// Rows that represent an actual, visible contribution.
    ///
    /// Deleted intermediates occupy a structural row so descendants stay
    /// readable, but they are not contributions, so they must not inflate any
    /// number shown to the reader.
    var activeLoadedCount: Int {
        nodesByKey.values.reduce(into: 0) { total, node in
            if !node.isUnavailable { total += 1 }
        }
    }

    var hasMoreAncestry: Bool { ancestorCursor != nil }

    var hasMoreBranches: Bool { !branchCursors.isEmpty }

    var completeness: MarkerThreadCompleteness {
        if hasMoreAncestry { return .ancestryPending }
        if hasMoreBranches { return .branchesPending }
        return rootResolved ? .complete : .ancestryPending
    }

    /// Whole-thesis size.
    ///
    /// Exact only when the server itself supplied a total *and* nothing is
    /// still pending locally. The server sends no total on a partial page —
    /// including the last continuation page — so on every other path this
    /// reports a floor built from active rows only. A total is never inferred
    /// from the loaded or tombstone row count.
    var totalCount: MarkerThreadCount {
        if let total = serverTotalCount, completeness == .complete, !truncated {
            return .exact(total)
        }
        return .atLeast(activeLoadedCount)
    }

    /// The node the sheet is showing, if this window holds it.
    var requestedNode: RLMarkerLinkPreviewDTO? {
        nodesByKey.values.first { $0.markerId == requestedMarkerId }
    }

    /// Where the window's traversal starts. Falls back to any orphan root so a
    /// malformed page can never produce an empty list.
    private var effectiveRootKeys: [String] {
        if nodesByKey[windowRootKey] != nil { return [windowRootKey] }
        if !orphanRootKeys.isEmpty { return orphanRootKeys }
        // Every node has a parent we do not hold: surface them all rather than
        // rendering nothing.
        return nodesByKey.values
            .filter { node in
                guard let parentKey = node.parentKey else { return true }
                return nodesByKey[parentKey] == nil
            }
            .map(\.nodeKey)
            .sorted()
    }

    /// Flattened preorder rows with depths computed from the merged tree.
    ///
    /// Depth is derived here, never taken from the page, because branch pages
    /// report depths relative to their own window root.
    func displayRows() -> [MarkerThreadRow] {
        var rows: [MarkerThreadRow] = []
        var visited = Set<String>()

        func walk(_ key: String, depth: Int) {
            guard !visited.contains(key), let node = nodesByKey[key] else { return }
            visited.insert(key)
            rows.append(
                MarkerThreadRow(
                    node: node,
                    depth: depth,
                    isRequested: node.markerId != nil && node.markerId == requestedMarkerId,
                    hasMoreResponses: branchCursors[key] != nil
                )
            )
            for childKey in childKeysByParent[key] ?? [] {
                walk(childKey, depth: depth + 1)
            }
        }

        for rootKey in effectiveRootKeys {
            walk(rootKey, depth: 0)
        }

        // Anything unreachable from a root (a page that arrived before its
        // parent) is still worth showing rather than silently dropping.
        for key in nodesByKey.keys.sorted() where !visited.contains(key) {
            walk(key, depth: 0)
        }

        return rows
    }

    /// Relationship tallies over the nodes this window holds. Tombstones occupy
    /// a structural row but are not counted as contributions, matching the
    /// server's own counting rule.
    func relationshipTallies() -> [MarkerLinkRelationship: Int] {
        var tallies: [MarkerLinkRelationship: Int] = [:]
        for node in nodesByKey.values where !node.isUnavailable {
            guard let known = node.relationship?.known else { continue }
            tallies[known, default: 0] += 1
        }
        return tallies
    }

    /// Cursor for continuing a specific branch, if one is outstanding.
    func branchCursor(for nodeKey: String) -> String? {
        branchCursors[nodeKey]
    }
}
