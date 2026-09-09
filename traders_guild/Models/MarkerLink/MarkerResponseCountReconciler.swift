//
//  MarkerResponseCountReconciler.swift
//  traders_guild
//
//  Monotonic reconciliation of a parent marker's direct-response count.
//
//  Counts arrive from three places — the HTTP create response, the HTTP delete
//  response, and the `marker_created` / `marker_deleted` websocket events — and
//  they can arrive out of order. Each carries an absolute count plus a revision
//  timestamp, so the rule is simply "never move backwards in revision".
//
//  This runs *before* the chart's symbol/timeframe filter. A response placed on
//  the 1h chart still changes the badge on a parent the user is looking at on
//  the 5m chart, and the early-return in `handleMarkerCreated` would otherwise
//  drop that update on the floor.
//

import Foundation

/// One absolute observation of a parent's response count.
struct MarkerResponseCountUpdate: Equatable {
    let markerId: UUID
    let directResponseCount: Int
    /// Server-advanced revision, exact to the microsecond.
    ///
    /// Deliberately not a `Date`: the backend advances this by microseconds
    /// under a row lock, and every Foundation date formatter on this path
    /// rounds to milliseconds, which would make two genuinely different
    /// revisions compare equal and silently drop a real count change.
    let revision: MarkerRevision?

    init(markerId: UUID, directResponseCount: Int, revision: MarkerRevision? = nil) {
        self.markerId = markerId
        self.directResponseCount = directResponseCount
        self.revision = revision
    }
}

/// Result of offering an update, so callers can skip redundant redraws.
enum MarkerResponseCountOutcome: Equatable {
    /// Accepted; the stored count changed to this value.
    case applied(Int)
    /// Accepted but the value was already current.
    case unchanged(Int)
    /// Rejected as older than what is already known.
    case stale
}

/// Keeps the newest known absolute count per marker.
///
/// Deliberately a value type with no chart knowledge: it can be exercised with
/// nothing but UUIDs and dates.
struct MarkerResponseCountReconciler: Equatable {

    private struct Entry: Equatable {
        var count: Int
        var revision: MarkerRevision?
    }

    private var entries: [UUID: Entry] = [:]

    init() {}

    /// Offer an absolute observation.
    ///
    /// Ordering rules:
    /// - a newer revision always wins;
    /// - an equal revision is accepted only if it does not change the count,
    ///   so two deliveries of the same revision cannot flip a value;
    /// - an older revision is rejected;
    /// - an update with no revision is accepted only when nothing with a
    ///   revision is already known, because an unversioned value cannot be
    ///   proven newer than a versioned one.
    @discardableResult
    mutating func apply(_ update: MarkerResponseCountUpdate) -> MarkerResponseCountOutcome {
        guard let existing = entries[update.markerId] else {
            entries[update.markerId] = Entry(count: update.directResponseCount, revision: update.revision)
            return .applied(update.directResponseCount)
        }

        switch (existing.revision, update.revision) {
        case let (stored?, incoming?):
            if incoming > stored {
                entries[update.markerId] = Entry(count: update.directResponseCount, revision: incoming)
                return existing.count == update.directResponseCount
                    ? .unchanged(update.directResponseCount)
                    : .applied(update.directResponseCount)
            }
            if incoming == stored {
                return .unchanged(existing.count)
            }
            return .stale

        case (nil, .some(let incoming)):
            // A versioned value always supersedes an unversioned one.
            entries[update.markerId] = Entry(count: update.directResponseCount, revision: incoming)
            return existing.count == update.directResponseCount
                ? .unchanged(update.directResponseCount)
                : .applied(update.directResponseCount)

        case (.some, nil):
            // Unversioned cannot be proven newer than versioned.
            return .stale

        case (nil, nil):
            entries[update.markerId] = Entry(count: update.directResponseCount, revision: nil)
            return existing.count == update.directResponseCount
                ? .unchanged(update.directResponseCount)
                : .applied(update.directResponseCount)
        }
    }

    /// The newest known count, if any observation has been made.
    func count(for markerId: UUID) -> Int? {
        entries[markerId]?.count
    }

    func revision(for markerId: UUID) -> MarkerRevision? {
        entries[markerId]?.revision
    }

    /// Forget a marker — it was deleted, or its thesis was invalidated.
    mutating func forget(_ markerId: UUID) {
        entries[markerId] = nil
    }

    mutating func removeAll() {
        entries.removeAll()
    }

    var isEmpty: Bool { entries.isEmpty }
}
