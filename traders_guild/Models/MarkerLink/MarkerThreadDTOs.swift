//
//  MarkerThreadDTOs.swift
//  traders_guild
//
//  Wire types for linked markers. Mirrors the 1.3.0 Backend / iOS interface
//  contract; every field the server may omit is optional with a safe default so
//  an older response still decodes.
//

import Foundation

/// One node in a thesis, and also the inline "what this answers" preview carried
/// on a marker.
///
/// Identity is `nodeKey`, not `markerId`. A node that the viewer may not see —
/// deleted, blocked, or outside their privacy scope — arrives as a *tombstone*:
/// it keeps its structural identity, relationship, count and depth, and carries
/// no marker id, no navigation fields and no author or content. That is what
/// lets a thesis stay readable through a hole in the middle without leaking
/// anything about the hole.
struct RLMarkerLinkPreviewDTO: Codable, Equatable, Hashable, Identifiable {
    /// Opaque structural identity. Stable across pages; the merge key.
    let nodeKey: String
    let parentKey: String?

    let markerId: UUID?
    let parentMarkerId: UUID?
    let linkRelationship: String?
    let isUnavailable: Bool

    let authorId: UUID?
    let authorDisplayName: String?
    let authorUsername: String?
    let authorAvatarUrl: String?

    let guildId: UUID?
    let symbolId: UUID?
    let ticker: String?
    let timeframe: String?
    let candleTimestamp: Date?
    let price: Double?
    let intent: String?
    let title: String?
    let note: String?
    let createdAt: Date?

    let directResponseCount: Int
    /// Depth **relative to the displayed window**, not to the true root. Branch
    /// pages arrive with their own zero-based depths and must be rebased by
    /// `parentKey` when merged — see `MarkerThreadWindow`.
    let depth: Int

    var id: String { nodeKey }

    init(
        nodeKey: String,
        parentKey: String? = nil,
        markerId: UUID? = nil,
        parentMarkerId: UUID? = nil,
        linkRelationship: String? = nil,
        isUnavailable: Bool = false,
        authorId: UUID? = nil,
        authorDisplayName: String? = nil,
        authorUsername: String? = nil,
        authorAvatarUrl: String? = nil,
        guildId: UUID? = nil,
        symbolId: UUID? = nil,
        ticker: String? = nil,
        timeframe: String? = nil,
        candleTimestamp: Date? = nil,
        price: Double? = nil,
        intent: String? = nil,
        title: String? = nil,
        note: String? = nil,
        createdAt: Date? = nil,
        directResponseCount: Int = 0,
        depth: Int = 0
    ) {
        self.nodeKey = nodeKey
        self.parentKey = parentKey
        self.markerId = markerId
        self.parentMarkerId = parentMarkerId
        self.linkRelationship = linkRelationship
        self.isUnavailable = isUnavailable
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.authorUsername = authorUsername
        self.authorAvatarUrl = authorAvatarUrl
        self.guildId = guildId
        self.symbolId = symbolId
        self.ticker = ticker
        self.timeframe = timeframe
        self.candleTimestamp = candleTimestamp
        self.price = price
        self.intent = intent
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.directResponseCount = directResponseCount
        self.depth = depth
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // nodeKey is the one structurally required field. Older servers that
        // predate the contract cannot send this type at all, so a missing key
        // here is a genuine decode failure rather than something to paper over.
        nodeKey = try c.decode(String.self, forKey: .nodeKey)
        parentKey = try c.decodeIfPresent(String.self, forKey: .parentKey)
        markerId = try c.decodeIfPresent(UUID.self, forKey: .markerId)
        parentMarkerId = try c.decodeIfPresent(UUID.self, forKey: .parentMarkerId)
        linkRelationship = try c.decodeIfPresent(String.self, forKey: .linkRelationship)
        isUnavailable = try c.decodeIfPresent(Bool.self, forKey: .isUnavailable) ?? false
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
        authorDisplayName = try c.decodeIfPresent(String.self, forKey: .authorDisplayName)
        authorUsername = try c.decodeIfPresent(String.self, forKey: .authorUsername)
        authorAvatarUrl = try c.decodeIfPresent(String.self, forKey: .authorAvatarUrl)
        guildId = try c.decodeIfPresent(UUID.self, forKey: .guildId)
        symbolId = try c.decodeIfPresent(UUID.self, forKey: .symbolId)
        ticker = try c.decodeIfPresent(String.self, forKey: .ticker)
        timeframe = try c.decodeIfPresent(String.self, forKey: .timeframe)
        candleTimestamp = try c.decodeIfPresent(Date.self, forKey: .candleTimestamp)
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        intent = try c.decodeIfPresent(String.self, forKey: .intent)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        directResponseCount = try c.decodeIfPresent(Int.self, forKey: .directResponseCount) ?? 0
        depth = try c.decodeIfPresent(Int.self, forKey: .depth) ?? 0
    }

    // MARK: - Derived

    var relationship: MarkerLinkRelationshipValue? {
        MarkerLinkRelationshipValue.make(linkRelationship)
    }

    var intentEnum: RLMarkerIntent? {
        guard let intent else { return nil }
        return RLMarkerIntent(rawValue: intent)
    }

    /// What to call this node's author in a sentence. Never falls back to a
    /// user id, and never invents a name for a tombstone.
    var authorDisplayText: String? {
        if isUnavailable { return nil }
        if let name = authorDisplayName, !name.isEmpty { return name }
        if let username = authorUsername, !username.isEmpty { return "@\(username)" }
        return nil
    }

    /// A short human label for the node itself — the marker's title if it has
    /// one, otherwise its intent.
    var titleDisplayText: String? {
        if isUnavailable { return nil }
        if let title, !title.isEmpty { return title }
        return intentEnum?.displayName
    }

    /// "Alex's BTC breakout" — the object of a relationship sentence.
    var possessiveSummary: String? {
        guard !isUnavailable else { return nil }
        switch (authorDisplayText, titleDisplayText) {
        case let (author?, title?): return "\(author)'s \(title)"
        case let (author?, nil): return "\(author)'s marker"
        case let (nil, title?): return title
        default: return nil
        }
    }

    /// Every field the chart needs to travel to this node. Tombstones can never
    /// satisfy this, which is what makes them non-tappable by construction
    /// rather than by a UI flag someone can forget to set.
    var canNavigate: Bool {
        !isUnavailable
            && markerId != nil
            && symbolId != nil
            && timeframe != nil
            && candleTimestamp != nil
            && price != nil
    }
}

/// One resumable branch: "there are more responses under this structural node".
struct RLMarkerThreadBranchDTO: Codable, Equatable, Hashable {
    let nodeKey: String
    let cursor: String
}

/// One bounded window onto a thesis.
///
/// Deliberately *not* a whole thesis: `totalCount` is nil unless the server
/// knows the thread is complete, and `rootResolved` is false until upward
/// traversal actually reached a real root. Callers must not present
/// `loadedCount` as a total.
struct RLMarkerThreadResponseDTO: Codable, Equatable {
    let requestedMarkerId: UUID
    let rootMarkerId: UUID?
    let rootKey: String?
    let rootResolved: Bool
    let windowRootKey: String
    let nodes: [RLMarkerLinkPreviewDTO]
    let ancestorCursor: String?
    let branches: [RLMarkerThreadBranchDTO]
    /// Exact only when the whole thesis is loaded; nil means "not known".
    let totalCount: Int?
    let loadedCount: Int
    let truncated: Bool

    init(
        requestedMarkerId: UUID,
        rootMarkerId: UUID? = nil,
        rootKey: String? = nil,
        rootResolved: Bool = false,
        windowRootKey: String,
        nodes: [RLMarkerLinkPreviewDTO] = [],
        ancestorCursor: String? = nil,
        branches: [RLMarkerThreadBranchDTO] = [],
        totalCount: Int? = nil,
        loadedCount: Int = 0,
        truncated: Bool = false
    ) {
        self.requestedMarkerId = requestedMarkerId
        self.rootMarkerId = rootMarkerId
        self.rootKey = rootKey
        self.rootResolved = rootResolved
        self.windowRootKey = windowRootKey
        self.nodes = nodes
        self.ancestorCursor = ancestorCursor
        self.branches = branches
        self.totalCount = totalCount
        self.loadedCount = loadedCount
        self.truncated = truncated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestedMarkerId = try c.decode(UUID.self, forKey: .requestedMarkerId)
        rootMarkerId = try c.decodeIfPresent(UUID.self, forKey: .rootMarkerId)
        rootKey = try c.decodeIfPresent(String.self, forKey: .rootKey)
        rootResolved = try c.decodeIfPresent(Bool.self, forKey: .rootResolved) ?? false
        windowRootKey = try c.decode(String.self, forKey: .windowRootKey)
        nodes = try c.decodeIfPresent([RLMarkerLinkPreviewDTO].self, forKey: .nodes) ?? []
        ancestorCursor = try c.decodeIfPresent(String.self, forKey: .ancestorCursor)
        branches = try c.decodeIfPresent([RLMarkerThreadBranchDTO].self, forKey: .branches) ?? []
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount)
        loadedCount = try c.decodeIfPresent(Int.self, forKey: .loadedCount) ?? nodes.count
        truncated = try c.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
    }
}

/// Delete acknowledgement. Retains the pre-1.3.0 `detail` and adds the parent
/// reconciliation metadata so the caller can correct the parent's badge without
/// a synthetic update event.
struct RLMarkerDeleteResponseDTO: Codable, Equatable {
    let detail: String?
    let markerId: UUID?
    let guildId: UUID?
    let symbolId: UUID?
    let parentMarkerId: UUID?
    let parentDirectResponseCount: Int?
    let parentResponsesRevision: String?

    init(
        detail: String? = nil,
        markerId: UUID? = nil,
        guildId: UUID? = nil,
        symbolId: UUID? = nil,
        parentMarkerId: UUID? = nil,
        parentDirectResponseCount: Int? = nil,
        parentResponsesRevision: String? = nil
    ) {
        self.detail = detail
        self.markerId = markerId
        self.guildId = guildId
        self.symbolId = symbolId
        self.parentMarkerId = parentMarkerId
        self.parentDirectResponseCount = parentDirectResponseCount
        self.parentResponsesRevision = parentResponsesRevision
    }
}

/// Raised when the server has linked markers switched off. The feature is
/// capability-gated and defaults to off, so this is an expected state rather
/// than an error worth surfacing as a failure.
struct MarkerLinkUnavailableError: LocalizedError, Equatable {
    static let detail = "linked_markers_unavailable"

    var errorDescription: String? {
        "Linked markers are temporarily unavailable."
    }
}
