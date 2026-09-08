//
//  MarkerLinkSession.swift
//  traders_guild
//
//  The "I am answering this marker" context carried through placement.
//
//  Modelled as a small pure state machine rather than loose fields on the
//  placement state, because its lifecycle has real rules: it must survive
//  intent and tool changes, must survive a *failed* submission so the author
//  does not lose their work, and must be cleared on exactly five events.
//

import Foundation

/// Everything the composer needs to know about the marker being answered.
/// Parent identity is immutable for the life of a session.
struct MarkerLinkContext: Equatable {
    let parentMarkerId: UUID
    let parentGuildId: UUID
    let parentSymbolId: UUID
    let parentCandleTimestamp: Date
    let parentAuthorDisplayText: String?
    let parentTitle: String?
    let parentIntent: RLMarkerIntent?

    /// Creation only ever uses a relationship this build understands; the
    /// tolerant wrapper exists for *reading* values a newer server may invent.
    var relationship: MarkerLinkRelationship

    init(
        parentMarkerId: UUID,
        parentGuildId: UUID,
        parentSymbolId: UUID,
        parentCandleTimestamp: Date,
        parentAuthorDisplayText: String? = nil,
        parentTitle: String? = nil,
        parentIntent: RLMarkerIntent? = nil,
        relationship: MarkerLinkRelationship
    ) {
        self.parentMarkerId = parentMarkerId
        self.parentGuildId = parentGuildId
        self.parentSymbolId = parentSymbolId
        self.parentCandleTimestamp = parentCandleTimestamp
        self.parentAuthorDisplayText = parentAuthorDisplayText
        self.parentTitle = parentTitle
        self.parentIntent = parentIntent
        self.relationship = relationship
    }

    /// "Supports Alex's BTC breakout" — the banner and detail-row sentence.
    var bannerSentence: String {
        let subject: String?
        switch (parentAuthorDisplayText, parentTitle) {
        case let (author?, title?) where !title.isEmpty: subject = "\(author)'s \(title)"
        case let (author?, _): subject = "\(author)'s marker"
        case let (nil, title?) where !title.isEmpty: subject = title
        default: subject = nil
        }
        guard let subject else { return relationship.displayName }
        return "\(relationship.displayName) \(subject)"
    }
}

/// Why a link session ended. Failure is deliberately absent — a failed
/// submission keeps the session so the author can retry.
enum MarkerLinkSessionEnd: Equatable {
    case submitted
    case cancelled
    case enteredEditMode
    case loggedOut
    /// The chart moved to a guild or symbol the parent does not belong to.
    case unrelatedContext
    /// The author explicitly removed the link from the banner.
    case removedByAuthor
}

/// Placement-time link state.
///
/// Holds at most one context. `visibilityBeforeLink` exists so removing the
/// link restores whatever the author's marker type would ordinarily default to
/// — a personal marker goes back to being private rather than staying stuck on
/// the guild visibility the link forced.
struct MarkerLinkSession: Equatable {
    private(set) var context: MarkerLinkContext?
    private(set) var visibilityBeforeLink: String?
    /// Set when a submission failed. The session survives; this is only used to
    /// tell the author what happened.
    private(set) var lastFailureMessage: String?

    init() {}

    var isActive: Bool { context != nil }

    /// While a link is active the marker must be guild-visible: a private
    /// response would notify an author who could never open it.
    var lockedVisibility: String? { isActive ? "guild" : nil }

    // MARK: - Transitions

    mutating func begin(_ context: MarkerLinkContext, currentVisibility: String?) {
        // Starting a new link from within an old one keeps the earliest
        // pre-link visibility, so removing the link still restores the value
        // the author actually chose.
        if self.context == nil {
            visibilityBeforeLink = currentVisibility
        }
        self.context = context
        lastFailureMessage = nil
    }

    /// The author picked a different relationship from the banner. Parent
    /// identity is untouched.
    mutating func changeRelationship(_ relationship: MarkerLinkRelationship) {
        guard var context else { return }
        context.relationship = relationship
        self.context = context
    }

    /// A submission failed. Deliberately does **not** clear the session.
    mutating func recordFailure(_ message: String?) {
        guard isActive else { return }
        lastFailureMessage = message
    }

    mutating func clearFailure() {
        lastFailureMessage = nil
    }

    /// End the session.
    ///
    /// - Returns: the visibility to restore, if the caller should restore one.
    ///   Only a removal or cancellation restores; a successful submission has
    ///   already consumed the state.
    @discardableResult
    mutating func end(_ reason: MarkerLinkSessionEnd) -> String? {
        let restore: String?
        switch reason {
        case .removedByAuthor, .cancelled:
            restore = visibilityBeforeLink
        case .submitted, .enteredEditMode, .loggedOut, .unrelatedContext:
            restore = nil
        }
        context = nil
        visibilityBeforeLink = nil
        lastFailureMessage = nil
        return restore
    }

    /// Ends the session when the chart has moved somewhere the parent cannot be
    /// answered from. Same guild and symbol are a server-side requirement, so
    /// carrying the link further would only produce a rejected create.
    ///
    /// - Returns: true when the session was ended.
    @discardableResult
    mutating func endIfUnrelated(guildId: UUID?, symbolId: UUID?) -> Bool {
        guard let context else { return false }
        let sameGuild = guildId == nil || guildId == context.parentGuildId
        let sameSymbol = symbolId == nil || symbolId == context.parentSymbolId
        guard !(sameGuild && sameSymbol) else { return false }
        end(.unrelatedContext)
        return true
    }
}
