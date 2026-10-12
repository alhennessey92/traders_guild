import Foundation
import Testing
@testable import traders_guild

/// The drawer's thesis reading of the activity feed (owner, 12 Oct): which
/// markers are debates, what their replies say, and how the Live Feed tucks a
/// reply under the marker it answers.
struct MarkerThesisFeedTests {
    private static let base = Date(timeIntervalSince1970: 1_770_000_000)

    private func item(
        _ id: UUID = UUID(), at minutes: Double, parent: UUID? = nil, relationship: String? = nil,
        responses: Int? = 0, counts: [String: Int]? = nil, lastResponse: Double? = nil,
        preview: RLMarkerLinkPreviewDTO? = nil
    ) -> RLMarkerActivityItemDTO {
        let date = Self.base.addingTimeInterval(minutes * 60)
        var dto = RLMarkerActivityItemDTO(
            id: id, symbolId: UUID(), symbolTicker: "BTC/USD", symbolBrandColor: nil, symbolAssetClass: "crypto",
            guildId: UUID(), authorId: UUID(), authorUsername: "alex", authorInitials: "AL", authorAvatarUrl: nil,
            authorIsOnline: false, authorReputation: 0, authorAccuracyRate: nil, authorRole: "member",
            intent: RLMarkerIntent.analysis.rawValue, title: "Marker", notePreview: nil, pollQuestion: nil,
            pollOptions: nil, selectedEmoji: nil, alertSeverity: nil, createdAt: date, createdAtFormatted: "",
            activityTimestamp: date, activityTimestampFormatted: "", candleTimestamp: date, timeframe: "1h",
            price: 1, setupSummary: nil, predictionResult: nil, likeCount: 0, isLikedByCurrentUser: false,
            commentCount: 0, isCurrentUserMarker: false
        )
        dto.parentMarkerId = parent
        dto.linkRelationship = relationship
        dto.directResponseCount = responses
        dto.responseCounts = counts
        dto.lastResponseAt = lastResponse.map { Self.base.addingTimeInterval($0 * 60) }
        dto.parentPreview = preview
        return dto
    }

    @Test func anOlderServerIsNotTreatedAsHavingNoTheses() {
        let old = [item(at: 0, responses: nil), item(at: 1, responses: nil)]
        #expect(!MarkerThesisFeed.isSupported(old))
        #expect(MarkerThesisFeed.isSupported([item(at: 0, responses: 0)]))
    }

    @Test func aMarkerWithRepliesIsAThesisWithTheServersBreakdown() throws {
        let root = UUID()
        let items = [
            item(at: 30, parent: root, relationship: "challenges"),
            item(at: 20, parent: root, relationship: "supports"),
            item(root, at: 0, responses: 5, counts: ["supports": 3, "challenges": 1, "builds_on": 1], lastResponse: 30),
            item(at: 10),
        ]
        let theses = MarkerThesisFeed.theses(from: items)
        #expect(theses.count == 1)
        let thesis = try #require(theses.first)
        #expect(thesis.id == root)
        #expect(thesis.replyCount == 5, "the server's count, not just the replies in hand")
        #expect(thesis.stance == MarkerThesisStance(supports: 3, challenges: 1, buildsOn: 1))
        #expect(thesis.replies.map(\.createdAt) == [items[0].createdAt, items[1].createdAt], "newest first")
        #expect(thesis.lastActivity == Self.base.addingTimeInterval(30 * 60))
    }

    @Test func theDecodersCamelCasedKeysCountTheSame() {
        #expect(MarkerThesisStance(counts: ["buildsOn": 2, "supports": 1]) == MarkerThesisStance(supports: 1, buildsOn: 2))
        #expect(MarkerThesisStance(counts: ["unknown_kind": 4]).total == 0)
    }

    @Test func aThesisOutsideTheFeedIsKnownFromItsRepliesPreview() throws {
        let root = UUID()
        let preview = RLMarkerLinkPreviewDTO(
            nodeKey: "k", markerId: root, authorUsername: "sam", guildId: UUID(), symbolId: UUID(), ticker: "ETH/USD",
            timeframe: "4h", candleTimestamp: Self.base, price: 2, intent: "question", title: "Breakout?",
            createdAt: Self.base, directResponseCount: 3
        )
        let items = [
            item(at: 50, parent: root, relationship: "supports", preview: preview),
            item(at: 40, parent: root, relationship: "challenges", preview: preview),
        ]
        let thesis = try #require(MarkerThesisFeed.theses(from: items).first)
        #expect(thesis.head == .preview(preview))
        #expect(thesis.replyCount == 3)
        #expect(thesis.stance == MarkerThesisStance(supports: 1, challenges: 1))
        #expect(preview.navigationTarget(guildFallback: nil)?.id == root)
    }

    @Test func anUnavailableParentIsNotAThesis() {
        let root = UUID()
        let tombstone = RLMarkerLinkPreviewDTO(nodeKey: "t", isUnavailable: true, directResponseCount: 1)
        var reply = item(at: 5, parent: root, relationship: "supports", preview: tombstone)
        reply.parentPreview = tombstone
        #expect(MarkerThesisFeed.theses(from: [reply]).isEmpty)
        #expect(tombstone.navigationTarget(guildFallback: UUID()) == nil)
    }

    @Test func thesesAreOrderedByTheirNewestReply() {
        let quiet = UUID(), busy = UUID()
        let items = [
            item(quiet, at: 100, responses: 1, counts: ["supports": 1], lastResponse: 110),
            item(busy, at: 0, responses: 1, counts: ["challenges": 1], lastResponse: 200),
        ]
        #expect(MarkerThesisFeed.theses(from: items).map(\.id) == [busy, quiet])
    }

    @Test func theLiveFeedTucksRepliesUnderTheirThread() {
        let root = UUID(), reply = UUID()
        let items = [
            item(at: 90, parent: reply, relationship: "challenges"),
            item(at: 60),
            item(reply, at: 30, parent: root, relationship: "supports", responses: 1),
            item(root, at: 0, responses: 1),
        ]
        let clusters = MarkerThesisFeed.clusters(from: items)
        #expect(clusters.count == 2)
        #expect(clusters[0].head.id == root, "the thread rises with its newest reply")
        #expect(clusters[0].replies.map(\.id) == [reply, items[0].id], "a reply to a reply joins the same thread, oldest first")
        #expect(clusters[1].head.id == items[1].id && clusters[1].replies.isEmpty)
    }

    @Test func aReplyToAReplySitsUnderTheReplyItAnswers() throws {
        let root = UUID(), first = UUID(), second = UUID(), answer = UUID()
        let items = [
            item(answer, at: 30, parent: first, relationship: "challenges"),
            item(second, at: 20, parent: root, relationship: "builds_on"),
            item(first, at: 10, parent: root, relationship: "supports", responses: 1),
            item(root, at: 0, responses: 2),
        ]
        let cluster = try #require(MarkerThesisFeed.clusters(from: items).first)
        #expect(cluster.replies.map(\.id) == [first, answer, second])
        #expect(cluster.depths == [first: 1, answer: 2, second: 1])
    }

    @Test func aReplyWhoseParentIsNotInTheFeedStandsAlone() {
        let reply = item(at: 10, parent: UUID(), relationship: "builds_on")
        let clusters = MarkerThesisFeed.clusters(from: [reply])
        #expect(clusters.map(\.head.id) == [reply.id])
        #expect(reply.linkRelationshipKnown == .buildsOn)
    }

    @Test func anOlderServersFeedKeepsItsOrder() {
        let items = (0..<4).map { item(at: Double(10 - $0), responses: nil) }
        #expect(MarkerThesisFeed.clusters(from: items).map(\.head.id) == items.map(\.id))
        #expect(MarkerThesisFeed.theses(from: items).isEmpty)
    }

    @Test func theWireShapeDecodesFromBothServers() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let common = """
        "id":"6A1D3F00-0000-4000-8000-000000000001","symbol_id":"6A1D3F00-0000-4000-8000-000000000002",
        "symbol_ticker":"BTC/USD","symbol_asset_class":"crypto","guild_id":"6A1D3F00-0000-4000-8000-000000000003",
        "author_id":"6A1D3F00-0000-4000-8000-000000000004","author_username":"alex","author_initials":"AL",
        "author_is_online":false,"author_reputation":0,"author_role":"member","intent":"analysis",
        "created_at":"2026-10-12T10:00:00Z","created_at_formatted":"now","activity_timestamp":"2026-10-12T10:00:00Z",
        "activity_timestamp_formatted":"now","candle_timestamp":"2026-10-12T10:00:00Z","timeframe":"1h","price":1,
        "like_count":0,"is_liked_by_current_user":false,"comment_count":0,"is_current_user_marker":false
        """
        let old = try decoder.decode(RLMarkerActivityItemDTO.self, from: Data("{\(common)}".utf8))
        #expect(old.directResponseCount == nil && old.responseCounts == nil && old.parentPreview == nil)

        let new = try decoder.decode(RLMarkerActivityItemDTO.self, from: Data("""
        {\(common),"parent_marker_id":null,"link_relationship":null,"parent_preview":null,"direct_response_count":2,
        "response_counts":{"supports":1,"builds_on":1},"last_response_at":"2026-10-12T11:00:00Z"}
        """.utf8))
        #expect(new.directResponseCount == 2)
        #expect(MarkerThesisStance(counts: try #require(new.responseCounts)) == MarkerThesisStance(supports: 1, buildsOn: 1))
        #expect(new.lastResponseAt != nil)
    }
}
