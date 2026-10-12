//
//  MarkerThesisFeed.swift
//  traders_guild
//
//  The drawer's marker activity read as theses (owner, 12 Oct 2026): a marker
//  with replies is a debate, and its replies belong with it rather than
//  scattered down a long list. Built only from what the activity feed sends;
//  a server that predates the thesis fields leaves everything as it was.
//

import Foundation

/// How a thesis's direct replies divide.
struct MarkerThesisStance: Equatable {
    var supports = 0
    var challenges = 0
    var buildsOn = 0

    var total: Int { supports + challenges + buildsOn }

    /// The server's breakdown. Accepts the wire keys and the decoder's
    /// camel-cased ones (`builds_on` / `buildsOn`); ignores relationships this
    /// build does not know.
    init(counts: [String: Int]) {
        for (key, value) in counts {
            switch MarkerThesisStance.relationship(forKey: key) {
            case .supports: supports += value
            case .challenges: challenges += value
            case .buildsOn: buildsOn += value
            case nil: continue
            }
        }
    }

    /// Counted from the replies in hand, where the server sent no breakdown.
    init(replies: [RLMarkerActivityItemDTO]) {
        for reply in replies {
            switch reply.linkRelationship.flatMap(MarkerThesisStance.relationship(forKey:)) {
            case .supports: supports += 1
            case .challenges: challenges += 1
            case .buildsOn: buildsOn += 1
            case nil: continue
            }
        }
    }

    init(supports: Int = 0, challenges: Int = 0, buildsOn: Int = 0) {
        self.supports = supports
        self.challenges = challenges
        self.buildsOn = buildsOn
    }

    func count(_ relationship: MarkerLinkRelationship) -> Int {
        switch relationship {
        case .supports: return supports
        case .challenges: return challenges
        case .buildsOn: return buildsOn
        }
    }

    static func relationship(forKey key: String) -> MarkerLinkRelationship? {
        let folded = key.replacingOccurrences(of: "_", with: "").lowercased()
        return MarkerLinkRelationship.allCases.first {
            $0.rawValue.replacingOccurrences(of: "_", with: "").lowercased() == folded
        }
    }
}

/// A marker with replies, and the replies the feed brought with it.
struct MarkerThesis: Identifiable, Equatable {
    /// The marker itself when it is in the feed; otherwise the preview its
    /// replies carry.
    enum Head: Equatable {
        case item(RLMarkerActivityItemDTO)
        case preview(RLMarkerLinkPreviewDTO)
    }

    let id: UUID
    let head: Head
    /// Direct replies in the feed, newest first.
    let replies: [RLMarkerActivityItemDTO]
    /// Every direct reply, including those the feed did not bring.
    let replyCount: Int
    let stance: MarkerThesisStance
    /// The newest reply, or the thesis itself.
    let lastActivity: Date
}

/// A Live Feed entry: a marker, with the replies to it (and to them) that are
/// also in the feed tucked beneath it.
struct MarkerFeedCluster: Identifiable, Equatable {
    let head: RLMarkerActivityItemDTO
    /// Replies in the feed whose thread starts at `head`, in thread order:
    /// each reply oldest first, followed by the replies to it.
    let replies: [RLMarkerActivityItemDTO]
    /// How far each reply sits from `head`: 1 answers the head, 2 answers a
    /// reply, and so on.
    let depths: [UUID: Int]
    let lastActivity: Date

    var id: UUID { head.id }
}

enum MarkerThesisFeed {
    /// Whether the server sends thesis context at all. A 1.5 server sends a
    /// response count on every item (zero included); an older one, none.
    static func isSupported(_ items: [RLMarkerActivityItemDTO]) -> Bool {
        items.contains { $0.directResponseCount != nil }
    }

    /// Every marker with replies, newest debate first.
    ///
    /// A marker in the feed speaks for itself (its counts are the server's).
    /// One that is not, but whose replies are, is known from the preview they
    /// carry; its stance is then counted from those replies. Unavailable
    /// parents (deleted, blocked) are not theses: their replies stand alone.
    static func theses(from items: [RLMarkerActivityItemDTO]) -> [MarkerThesis] {
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let repliesByParent = Dictionary(grouping: items.filter { $0.parentMarkerId != nil }) { $0.parentMarkerId! }
            .mapValues { $0.sorted { $0.createdAt > $1.createdAt } }

        var theses: [MarkerThesis] = []
        var seen = Set<UUID>()

        for item in items where (item.directResponseCount ?? 0) > 0 {
            guard seen.insert(item.id).inserted else { continue }
            let replies = repliesByParent[item.id] ?? []
            let stance = item.responseCounts.map(MarkerThesisStance.init(counts:))
                ?? MarkerThesisStance(replies: replies)
            let last = [item.lastResponseAt, replies.first?.createdAt].compactMap { $0 }.max() ?? item.createdAt
            theses.append(MarkerThesis(
                id: item.id, head: .item(item), replies: replies,
                replyCount: max(item.directResponseCount ?? 0, replies.count),
                stance: stance, lastActivity: last
            ))
        }

        for (parentId, replies) in repliesByParent where byId[parentId] == nil && !seen.contains(parentId) {
            guard let preview = replies.lazy.compactMap(\.parentPreview).first(where: { $0.markerId == parentId }),
                  !preview.isUnavailable else { continue }
            seen.insert(parentId)
            theses.append(MarkerThesis(
                id: parentId, head: .preview(preview), replies: replies,
                replyCount: max(preview.directResponseCount, replies.count),
                stance: MarkerThesisStance(replies: replies),
                lastActivity: replies.first?.createdAt ?? preview.createdAt ?? .distantPast
            ))
        }

        return theses.sorted {
            $0.lastActivity == $1.lastActivity ? $0.id.uuidString < $1.id.uuidString : $0.lastActivity > $1.lastActivity
        }
    }

    /// The feed with each reply moved under the oldest ancestor the feed also
    /// holds, the thread ordered by its newest activity.
    static func clusters(from items: [RLMarkerActivityItemDTO]) -> [MarkerFeedCluster] {
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func root(of item: RLMarkerActivityItemDTO) -> UUID {
            var current = item
            var visited: Set<UUID> = [item.id]
            while let parentId = current.parentMarkerId, let parent = byId[parentId], visited.insert(parentId).inserted {
                current = parent
            }
            return current.id
        }

        var order: [UUID] = []
        var members: [UUID: [RLMarkerActivityItemDTO]] = [:]
        for item in items {
            let rootId = root(of: item)
            if members[rootId] == nil {
                order.append(rootId)
                members[rootId] = []
            }
            if rootId != item.id { members[rootId]?.append(item) }
        }

        let clusters = order.compactMap { rootId -> MarkerFeedCluster? in
            guard let head = byId[rootId] else { return nil }
            let members = members[rootId] ?? []
            let children = Dictionary(grouping: members) { $0.parentMarkerId ?? rootId }
                .mapValues { $0.sorted { $0.createdAt < $1.createdAt } }
            var replies: [RLMarkerActivityItemDTO] = []
            var depths: [UUID: Int] = [:]
            func walk(_ parentId: UUID, depth: Int) {
                for child in children[parentId] ?? [] where depths[child.id] == nil {
                    replies.append(child)
                    depths[child.id] = depth
                    walk(child.id, depth: depth + 1)
                }
            }
            walk(rootId, depth: 1)
            let last = ([head.activityTimestamp] + replies.map(\.activityTimestamp)).max() ?? head.activityTimestamp
            return MarkerFeedCluster(head: head, replies: replies, depths: depths, lastActivity: last)
        }
        return clusters.enumerated().sorted { lhs, rhs in
            lhs.element.lastActivity == rhs.element.lastActivity
                ? lhs.offset < rhs.offset
                : lhs.element.lastActivity > rhs.element.lastActivity
        }.map(\.element)
    }
}

extension RLMarkerActivityItemDTO {
    var linkRelationshipKnown: MarkerLinkRelationship? {
        linkRelationship.flatMap(MarkerThesisStance.relationship(forKey:))
    }
}

extension RLMarkerLinkPreviewDTO {
    /// Enough of the marker to take the chart to it from the drawer. Nil for a
    /// preview that cannot be opened (a tombstone, or missing its place).
    func navigationTarget(guildFallback: UUID?) -> RLTopMarkerDTO? {
        guard !isUnavailable, let markerId, let symbolId, let candleTimestamp, let timeframe,
              let guildId = guildId ?? guildFallback else { return nil }
        let username = authorUsername ?? authorDisplayName ?? ""
        return RLTopMarkerDTO(
            id: markerId,
            symbolId: symbolId,
            symbolTicker: ticker ?? "",
            symbolBrandColor: nil,
            symbolAssetClass: "unknown",
            guildId: guildId,
            authorId: authorId ?? markerId,
            authorUsername: username,
            authorInitials: String(username.prefix(2)).uppercased(),
            authorAvatarUrl: authorAvatarUrl,
            authorIsOnline: false,
            authorReputation: 0,
            authorAccuracyRate: nil,
            authorRole: "member",
            intent: intent ?? RLMarkerIntent.analysis.rawValue,
            title: title,
            notePreview: note,
            pollQuestion: nil,
            pollOptions: nil,
            selectedEmoji: nil,
            alertSeverity: nil,
            createdAt: createdAt ?? candleTimestamp,
            createdAtFormatted: "",
            candleTimestamp: candleTimestamp,
            timeframe: timeframe,
            price: price ?? 0,
            setupSummary: nil,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            trendingScore: 0,
            isCurrentUserMarker: false
        )
    }
}
