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

/// What a delete attempt actually did.
///
/// A `Bool` would collapse the two failures that matter to a user into one:
/// "the server said no" and "the request never landed" call for different
/// words on screen, and only one of them is worth a Retry button.
enum MarkerDeleteOutcome: Equatable {
    case deleted
    /// This viewer may not delete it — checked before the request, so no
    /// destructive call is made on a marker the server would refuse.
    case notPermitted
    /// Not on this chart; nothing to delete.
    case notFound
    /// The request failed. **Nothing was removed** — the marker is still there,
    /// still selected, and the caller must say so rather than dismissing.
    case failed
}

/// One absolute observation of a parent's response count.
struct MarkerResponseCountUpdate: Equatable {
    let markerId: UUID
    let directResponseCount: Int
    /// Whether any child row survives, tombstones included.
    ///
    /// Travels with the count and is ordered by the same revision, because the
    /// two answer different questions about the same instant: the count says
    /// how many *active* responses there are, this says whether the thesis
    /// still exists at all. A soft delete drops the first to zero and leaves
    /// the second true.
    ///
    /// `nil` is "the server did not say", never "no".
    let hasResponses: Bool?
    /// Server-advanced revision, exact to the microsecond.
    ///
    /// Deliberately not a `Date`: the backend advances this by microseconds
    /// under a row lock, and every Foundation date formatter on this path
    /// rounds to milliseconds, which would make two genuinely different
    /// revisions compare equal and silently drop a real count change.
    let revision: MarkerRevision?

    init(
        markerId: UUID,
        directResponseCount: Int,
        revision: MarkerRevision? = nil,
        hasResponses: Bool? = nil
    ) {
        self.markerId = markerId
        self.directResponseCount = directResponseCount
        self.revision = revision
        self.hasResponses = hasResponses
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
        /// Kept across a rejected or unchanged update, so a payload that omits
        /// the structural flag cannot erase one an earlier payload supplied.
        var hasResponses: Bool?
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
            entries[update.markerId] = Entry(
                count: update.directResponseCount,
                revision: update.revision,
                hasResponses: update.hasResponses
            )
            return .applied(update.directResponseCount)
        }

        // An accepted update carries the structural flag forward only when it
        // actually supplied one; a payload from a server that predates the
        // field must not be read as "this thesis no longer exists".
        func accept() -> MarkerResponseCountOutcome {
            entries[update.markerId] = Entry(
                count: update.directResponseCount,
                revision: update.revision ?? existing.revision,
                hasResponses: update.hasResponses ?? existing.hasResponses
            )
            return existing.count == update.directResponseCount
                ? .unchanged(update.directResponseCount)
                : .applied(update.directResponseCount)
        }

        switch (existing.revision, update.revision) {
        case let (stored?, incoming?):
            if incoming > stored {
                return accept()
            }
            if incoming == stored {
                // Same instant: the count cannot move, but a redelivery that
                // carries the structural flag may still fill in one that was
                // missing, which is strictly more information about that same
                // revision.
                if existing.hasResponses == nil, let known = update.hasResponses {
                    entries[update.markerId]?.hasResponses = known
                }
                return .unchanged(existing.count)
            }
            return .stale

        case (nil, .some):
            // A versioned value always supersedes an unversioned one.
            return accept()

        case (.some, nil):
            // Unversioned cannot be proven newer than versioned.
            return .stale

        case (nil, nil):
            return accept()
        }
    }

    /// The newest known count, if any observation has been made.
    func count(for markerId: UUID) -> Int? {
        entries[markerId]?.count
    }

    func revision(for markerId: UUID) -> MarkerRevision? {
        entries[markerId]?.revision
    }

    /// The newest known structural answer, or nil if no payload has supplied one.
    func hasResponses(for markerId: UUID) -> Bool? {
        entries[markerId]?.hasResponses
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
