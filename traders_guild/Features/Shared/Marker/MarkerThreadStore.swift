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
    /// When it was staged, so a target that never arrives cannot sit waiting
    /// and then hijack the selection much later.
    let stagedAt: Date

    /// A cross-timeframe load that has not produced the marker within this
    /// window is treated as abandoned. Generous enough for a history page on a
    /// slow connection, short enough that the user has not moved on.
    static let expiry: TimeInterval = 30

    func isValid(generation currentGeneration: Int, now: Date = Date()) -> Bool {
        generation == currentGeneration
            && now.timeIntervalSince(stagedAt) <= Self.expiry
    }
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
        /// A block was added or removed, in either direction, or guild-content
        /// visibility changed for this viewer.
        case privacyChanged
        /// The viewer reported content or a member, or a moderation action
        /// landed that can change what they are shown.
        case moderation
        /// The viewer is no longer a member of the guild the thesis belongs to.
        case membershipLost
        /// The server capability was switched on or off. A window cached while
        /// it was off predates whatever the server now considers authoritative.
        case capabilityChanged
        case markerRemoved(UUID)
    }

    /// The last reason the cache was dropped, for diagnostics and tests.
    private(set) var lastInvalidationReason: InvalidationReason?

    /// Drop everything and advance the generation so in-flight work is ignored.
    ///
    /// Advancing the generation is the load-bearing half: a page already on the
    /// wire when this runs is refused by `ingest`, so an invalidation cannot be
    /// undone a moment later by a request that predates it.
    func invalidateAll(reason: InvalidationReason) {
        lastInvalidationReason = reason
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
    /// - Parameter expectedGeneration: the generation the request was issued
    ///   under. A page from an earlier generation is refused: the cache was
    ///   invalidated while it was in flight, which is exactly the case where
    ///   accepting it could resurrect content the viewer may no longer see.
    ///   Enforced here so no caller can forget it.
    /// - Returns: the key the thesis lives under, or nil if the page was refused.
    @discardableResult
    func ingest(
        page: RLMarkerThreadResponseDTO,
        requestedMarkerId: UUID,
        expectedGeneration: Int? = nil,
        consumedBranchKey: String? = nil
    ) -> MarkerThreadCacheKey? {
        if let expectedGeneration, expectedGeneration != generation {
            return nil
        }
        let currentKey = cacheKey(forMarkerId: requestedMarkerId)

        // The destination is decided *before* the window is built. A window
        // filed provisionally has by definition never resolved a root — it
        // would have been promoted at the time — so the page alone determines
        // whether this belongs under a confirmed root.
        let key: MarkerThreadCacheKey = {
            if page.rootResolved, let rootId = page.rootMarkerId {
                return .confirmedRoot(rootId)
            }
            return currentKey
        }()

        var window = windows[key]

        // Promotion. Fold the provisional window into whatever already lives
        // at the confirmed key rather than overwriting it: a thesis opened from
        // two different nodes produces two provisional windows that later
        // resolve the same root, and clobbering would throw away the first
        // one's pages and its live branch cursors.
        if key != currentKey {
            if let provisional = windows[currentKey] {
                if var existing = window {
                    existing.absorb(provisional)
                    window = existing
                } else {
                    window = provisional
                }
                windows[currentKey] = nil
            }
            // Carry an open disclosure across the promotion so the sheet does
            // not collapse the moment ancestry resolves.
            if expandedKeys.remove(currentKey) != nil {
                expandedKeys.insert(key)
            }
            repoint(from: currentKey, to: key)
        }

        if var existing = window {
            existing.merge(page: page, consumedBranchKey: consumedBranchKey)
            window = existing
        } else {
            window = MarkerThreadWindow(page: page, consumedBranchKey: consumedBranchKey)
        }

        guard let window else { return nil }
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
                cacheKey: new,
                stagedAt: pending.stagedAt
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
    ///
    /// `stagedAt` is preserved across re-staging so the expiry measures from
    /// the user's original tap, not from the last load attempt; otherwise a
    /// target that never arrives would renew itself forever.
    func stagePendingNavigation(markerId: UUID, now: Date = Date()) {
        let stagedAt: Date = {
            if let existing = pendingNavigation, existing.markerId == markerId {
                return existing.stagedAt
            }
            return now
        }()
        pendingNavigation = MarkerThreadPendingNavigation(
            generation: generation,
            markerId: markerId,
            cacheKey: cacheKey(forMarkerId: markerId),
            stagedAt: stagedAt
        )
    }

    /// Take the staged selection if it is still valid for this generation and
    /// has not expired.
    func consumePendingNavigation(now: Date = Date()) -> MarkerThreadPendingNavigation? {
        guard let pending = pendingNavigation else { return nil }
        pendingNavigation = nil
        guard pending.isValid(generation: generation, now: now) else { return nil }
        return pending
    }

    func clearPendingNavigation() {
        pendingNavigation = nil
    }
}
