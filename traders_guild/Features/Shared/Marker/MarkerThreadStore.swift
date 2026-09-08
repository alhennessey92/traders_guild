//
//  MarkerThreadStore.swift
//  traders_guild
//
//  Thesis cache that outlives chart layout.
//
//  The chart tears down its marker set on every symbol *or timeframe* change
//  (`MarkerManager.activateLayoutContext`), which would otherwise discard a
//  thesis the moment a user follows a response onto another timeframe. This
//  store sits above that lifecycle: it is scoped to an account and guild, keyed
//  first provisionally and then by confirmed root, and holds only data — never
//  geometry, which must always be recomputed from live positions.
//

import Combine
import Foundation

/// Cache identity for one thesis.
///
/// A thread opened on a node whose root is not yet known is filed provisionally
/// under that node. Once ancestry actually reaches a real root the entry is
/// promoted, and every node that pointed at the provisional key is repointed, so
/// opening a sibling later reuses the same accumulated window.
enum MarkerThreadCacheKey: Hashable {
    case provisional(UUID)
    case confirmedRoot(UUID)
}

/// Where the chart should return to after a reload destroys the marker set.
struct MarkerThreadPendingNavigation: Equatable {
    let generation: Int
    let markerId: UUID
    let cacheKey: MarkerThreadCacheKey
}

/// The scope a cached thesis belongs to. Changing either half invalidates
/// everything: a different account or guild must never see another's thesis.
struct MarkerThreadScope: Equatable {
    let accountId: UUID?
    let guildId: UUID?

    static let none = MarkerThreadScope(accountId: nil, guildId: nil)
}

@MainActor
final class MarkerThreadStore: ObservableObject {

    /// Bumped whenever cached content can no longer be trusted. Anything
    /// carrying an older generation — in particular a pending navigation — is
    /// discarded rather than applied.
    @Published private(set) var generation: Int = 0

    @Published private(set) var scope: MarkerThreadScope = .none

    /// Thesis keys whose disclosure the user has opened. Preserved while moving
    /// between markers of the same thesis, dropped when the thesis changes.
    @Published private(set) var expandedKeys: Set<MarkerThreadCacheKey> = []

    private(set) var pendingNavigation: MarkerThreadPendingNavigation?

    private var windows: [MarkerThreadCacheKey: MarkerThreadWindow] = [:]
    private var keysByMarkerId: [UUID: MarkerThreadCacheKey] = [:]

    // MARK: - Scope

    /// Point the store at an account/guild pair. A change clears everything.
    func activate(accountId: UUID?, guildId: UUID?) {
        let next = MarkerThreadScope(accountId: accountId, guildId: guildId)
        guard next != scope else { return }
        scope = next
        invalidateAll(reason: .scopeChanged)
    }

    enum InvalidationReason: Equatable {
        case scopeChanged
        case logout
        case reconnect
        case privacyChanged
        case moderation
        case markerRemoved(UUID)
    }

    /// Drop everything and advance the generation so in-flight work is ignored.
    func invalidateAll(reason: InvalidationReason) {
        windows.removeAll()
        keysByMarkerId.removeAll()
        expandedKeys.removeAll()
        pendingNavigation = nil
        generation &+= 1
    }

    /// Drop only the thesis containing a marker — used when one marker is
    /// deleted, hidden, or becomes invisible to this viewer.
    func invalidateThesis(containing markerId: UUID) {
        guard let key = keysByMarkerId[markerId] else { return }
        windows[key] = nil
        expandedKeys.remove(key)
        for (id, existing) in keysByMarkerId where existing == key {
            keysByMarkerId[id] = nil
        }
        if pendingNavigation?.cacheKey == key {
            pendingNavigation = nil
        }
        generation &+= 1
    }

    // MARK: - Lookup

    func cacheKey(forMarkerId markerId: UUID) -> MarkerThreadCacheKey {
        keysByMarkerId[markerId] ?? .provisional(markerId)
    }

    func window(forMarkerId markerId: UUID) -> MarkerThreadWindow? {
        windows[cacheKey(forMarkerId: markerId)]
    }

    func window(for key: MarkerThreadCacheKey) -> MarkerThreadWindow? {
        windows[key]
    }

    /// True when two markers are known to belong to the same thesis, so the
    /// disclosure and scroll position should survive moving between them.
    func sharesThesis(_ lhs: UUID, _ rhs: UUID) -> Bool {
        guard let left = keysByMarkerId[lhs], let right = keysByMarkerId[rhs] else { return false }
        return left == right
    }

    // MARK: - Ingestion

    /// Fold a page into the cache, promoting the entry once a real root appears.
    ///
    /// - Returns: the key the thesis now lives under.
    @discardableResult
    func ingest(page: RLMarkerThreadResponseDTO, requestedMarkerId: UUID) -> MarkerThreadCacheKey {
        var key = cacheKey(forMarkerId: requestedMarkerId)

        var window: MarkerThreadWindow
        if var existing = windows[key] {
            existing.merge(page: page)
            window = existing
        } else {
            window = MarkerThreadWindow(page: page)
        }

        // Promote provisional -> confirmed once ancestry reached a real root.
        if window.rootResolved, let rootId = window.rootMarkerId {
            let confirmed = MarkerThreadCacheKey.confirmedRoot(rootId)
            if confirmed != key {
                windows[key] = nil
                // Carry an open disclosure across the promotion so the sheet
                // does not collapse the moment ancestry resolves.
                if expandedKeys.remove(key) != nil {
                    expandedKeys.insert(confirmed)
                }
                repoint(from: key, to: confirmed)
                key = confirmed
            }
        }

        windows[key] = window

        // Index every marker this window mentions so opening any of them later
        // reuses the accumulated pages instead of starting a new window.
        for node in window.nodesByKey.values {
            guard let markerId = node.markerId else { continue }
            keysByMarkerId[markerId] = key
        }
        keysByMarkerId[requestedMarkerId] = key

        return key
    }

    private func repoint(from old: MarkerThreadCacheKey, to new: MarkerThreadCacheKey) {
        for (id, existing) in keysByMarkerId where existing == old {
            keysByMarkerId[id] = new
        }
        if let pending = pendingNavigation, pending.cacheKey == old {
            pendingNavigation = MarkerThreadPendingNavigation(
                generation: pending.generation,
                markerId: pending.markerId,
                cacheKey: new
            )
        }
    }

    /// Record that a branch could not be paged, so the UI stops offering it.
    func markBranchExhausted(markerId: UUID, nodeKey: String) {
        let key = cacheKey(forMarkerId: markerId)
        guard var window = windows[key] else { return }
        window.dropBranchCursor(for: nodeKey)
        windows[key] = window
    }

    // MARK: - Disclosure context

    func setExpanded(_ expanded: Bool, forMarkerId markerId: UUID) {
        let key = cacheKey(forMarkerId: markerId)
        if expanded {
            expandedKeys.insert(key)
        } else {
            expandedKeys.remove(key)
        }
    }

    func isExpanded(forMarkerId markerId: UUID) -> Bool {
        expandedKeys.contains(cacheKey(forMarkerId: markerId))
    }

    // MARK: - Pending navigation

    /// Stage a selection to restore once the chart finishes reloading — the
    /// cross-timeframe case, where `MarkerManager` clears `selectedMarker`.
    func stagePendingNavigation(markerId: UUID) {
        pendingNavigation = MarkerThreadPendingNavigation(
            generation: generation,
            markerId: markerId,
            cacheKey: cacheKey(forMarkerId: markerId)
        )
    }

    /// Take the staged selection if it is still valid for this generation.
    func consumePendingNavigation() -> MarkerThreadPendingNavigation? {
        guard let pending = pendingNavigation else { return nil }
        pendingNavigation = nil
        guard pending.generation == generation else { return nil }
        return pending
    }

    func clearPendingNavigation() {
        pendingNavigation = nil
    }
}
