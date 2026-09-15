import Foundation
import Testing
@testable import traders_guild

/// The cross-timeframe badges on a selected glyph: which linked markers earn
/// one, and where the badges sit so a tap lands on what was painted.
struct MarkerTimeframeJumpTests {

    private let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func member(_ n: Int) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n), role: "member", reputation: 0, contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 0), accuracyRate: nil, mutedUntil: nil,
            suspendedUntil: nil, userId: id(n), username: "user\(n)", displayName: "User \(n)",
            avatarUrl: nil, isOnline: false, globalReputation: 0, isFriend: false,
            friendshipStatus: nil, isBlocked: false, isBlockedBy: false
        )
    }

    /// A navigable preview: everything `MarkerNavigationTarget(linkPreview:)`
    /// needs, unless `unavailable`.
    private func preview(
        key: String,
        parentKey: String? = nil,
        marker: Int,
        timeframe: String,
        relationship: String? = "supports",
        unavailable: Bool = false,
        created: TimeInterval = 0
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: key,
            parentKey: parentKey,
            markerId: id(marker),
            linkRelationship: relationship,
            isUnavailable: unavailable,
            authorUsername: unavailable ? nil : "trader",
            guildId: guildId,
            symbolId: unavailable ? nil : symbolId,
            ticker: "BTC/USD",
            timeframe: timeframe,
            candleTimestamp: unavailable ? nil : t0,
            price: 100,
            intent: "alert",
            title: "Node \(key)",
            createdAt: Date(timeIntervalSinceReferenceDate: created),
            directResponseCount: 0,
            depth: parentKey == nil ? 0 : 1
        )
    }

    private func marker(
        _ n: Int,
        timeframe: String = "5m",
        relationship: String? = nil,
        parent: RLMarkerLinkPreviewDTO? = nil,
        responses: Int = 0
    ) -> ChartMarkerUI {
        let dto = RLChartMarkerDTO(
            id: id(n), symbolId: symbolId, guildId: guildId, author: member(1),
            candleTimestamp: t0, timeframe: timeframe, price: 100,
            intent: "alert", title: "Marker", note: nil, visibility: "guild",
            confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: t0, createdAtFormatted: "now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: [], primaryComponentId: nil,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: parent?.markerId,
            linkRelationship: relationship,
            parentPreview: parent,
            directResponseCount: responses
        )
        return ChartMarkerUI(marker: dto, candleIndex: 0)
    }

    private func window(requested: Int, root: String, nodes: [RLMarkerLinkPreviewDTO], branches: [RLMarkerThreadBranchDTO] = []) -> MarkerThreadWindow {
        MarkerThreadWindow(
            page: RLMarkerThreadResponseDTO(
                requestedMarkerId: id(requested),
                rootMarkerId: nil, rootKey: nil, rootResolved: false,
                windowRootKey: root, nodes: nodes,
                ancestorCursor: nil, branches: branches, totalCount: nil,
                loadedCount: nodes.count, truncated: false
            )
        )
    }

    // MARK: - Resolver

    @Test
    func aParentOnAnotherTimeframeEarnsAParentBadgeInTheMarkersOwnColour() throws {
        let parent = preview(key: "p", marker: 1, timeframe: "5m")
        let response = marker(2, timeframe: "30m", relationship: "builds_on", parent: parent)

        let jumps = MarkerTimeframeJumpResolver.jumps(for: response, currentTimeframe: .m30, thread: nil)

        let jump = try #require(jumps.first)
        #expect(jumps.count == 1)
        #expect(jump.direction == .toParent)
        #expect(jump.markerId == id(1))
        #expect(jump.timeframe == .m5)
        #expect(jump.relationship.known == .buildsOn, "coloured like the connector would be")
    }

    @Test
    func aParentOnThisTimeframeGetsAConnectorNotABadge() {
        let parent = preview(key: "p", marker: 1, timeframe: "30m")
        let response = marker(2, timeframe: "30m", relationship: "supports", parent: parent)

        #expect(MarkerTimeframeJumpResolver.jumps(for: response, currentTimeframe: .m30, thread: nil).isEmpty)
    }

    @Test
    func anUnavailableParentEarnsNothing() {
        let tombstone = preview(key: "p", marker: 1, timeframe: "5m", unavailable: true)
        let response = marker(2, timeframe: "30m", relationship: "supports", parent: tombstone)

        #expect(MarkerTimeframeJumpResolver.jumps(for: response, currentTimeframe: .m30, thread: nil).isEmpty)
    }

    @Test
    func multipleResponsesOfferAChoiceInsteadOfSilentlyJumpingToTheNewest() throws {
        let root = marker(1, timeframe: "5m", responses: 3)
        let thread = window(requested: 1, root: "r", nodes: [
            preview(key: "r", marker: 1, timeframe: "5m", relationship: nil),
            preview(key: "a", parentKey: "r", marker: 2, timeframe: "30m", relationship: "supports", created: 10),
            preview(key: "b", parentKey: "r", marker: 3, timeframe: "4h", relationship: "challenges", created: 20),
            preview(key: "c", parentKey: "r", marker: 4, timeframe: "5m", relationship: "builds_on", created: 30),
        ])

        let jumps = MarkerTimeframeJumpResolver.jumps(for: root, currentTimeframe: .m5, thread: thread)

        let jump = try #require(jumps.first)
        #expect(jumps.count == 1)
        #expect(jump.direction == .toResponse)
        #expect(jump.markerId == id(3), "newest response that is not on this chart")
        #expect(jump.timeframe == .h4)
        #expect(jump.relationship.known == .challenges, "the response's own relationship")
        #expect(jump.others == 1, "one more elsewhere; the same-timeframe one is a connector")
        #expect(jump.requiresChoice)
        #expect(jump.badgeText == "…")
    }

    @Test
    func noThreadWindowMeansNoResponseBadge() {
        let root = marker(1, timeframe: "5m", responses: 3)
        #expect(MarkerTimeframeJumpResolver.jumps(for: root, currentTimeframe: .m5, thread: nil).isEmpty)
    }

    @Test
    func aMiddleNodeCanWearBothBadges() {
        let parent = preview(key: "p", marker: 1, timeframe: "1h")
        let middle = marker(2, timeframe: "30m", relationship: "supports", parent: parent, responses: 1)
        let thread = window(requested: 2, root: "p", nodes: [
            preview(key: "p", marker: 1, timeframe: "1h", relationship: nil),
            preview(key: "m", parentKey: "p", marker: 2, timeframe: "30m", relationship: "supports"),
            preview(key: "c", parentKey: "m", marker: 3, timeframe: "5m", relationship: "builds_on"),
        ])

        let jumps = MarkerTimeframeJumpResolver.jumps(for: middle, currentTimeframe: .m30, thread: thread)

        #expect(jumps.map(\.direction) == [.toParent, .toResponse])
        #expect(jumps.map(\.timeframe) == [.h1, .m5])
    }

    @Test
    func oneResponseOpensDirectlyOnlyWhenItsBranchIsComplete() throws {
        let root = marker(1, timeframe: "5m", responses: 2)
        let nodes = [
            preview(key: "r", marker: 1, timeframe: "5m", relationship: nil),
            preview(key: "a", parentKey: "r", marker: 2, timeframe: "1h")
        ]
        let complete = window(requested: 1, root: "r", nodes: nodes)
        let direct = try #require(MarkerTimeframeJumpResolver.jumps(for: root, currentTimeframe: .m5, thread: complete).first)
        #expect(!direct.requiresChoice)
        #expect(direct.badgeText == RLChartTimeframe.h1.shortName)
        let partial = window(requested: 1, root: "r", nodes: nodes,
                             branches: [RLMarkerThreadBranchDTO(nodeKey: "r", cursor: "more")])
        let choice = try #require(MarkerTimeframeJumpResolver.jumps(for: root, currentTimeframe: .m5, thread: partial).first)
        #expect(choice.requiresChoice)
        #expect(choice.badgeText == "…")
    }

    // MARK: - Layout

    @Test
    func parentSitsRightResponseSitsLeftLevelWithTheGlyph() throws {
        let parent = preview(key: "p", marker: 1, timeframe: "1h")
        let middle = marker(2, timeframe: "30m", relationship: "supports", parent: parent)
        let child = preview(key: "c", parentKey: "m", marker: 3, timeframe: "5m", relationship: "builds_on")
        let jumps = [
            MarkerTimeframeJump(markerId: id(1), direction: .toParent, relationship: MarkerLinkRelationshipValue(raw: "supports"), timeframe: .h1, others: 0, preview: parent),
            MarkerTimeframeJump(markerId: id(3), direction: .toResponse, relationship: MarkerLinkRelationshipValue(raw: "builds_on"), timeframe: .m5, others: 0, preview: child),
        ]
        _ = middle

        let above = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 100, y: 100), scaledRadius: 27, isBelow: false, jumps: jumps
        )
        #expect(above.count == 2)
        #expect(above[0].center.x > 100 && above[0].center.y == 100, "parent: to the right, level")
        #expect(above[1].center.x < 100 && above[1].center.y == 100, "response: to the left, level")
        let distance = hypot(above[0].center.x - 100, above[0].center.y - 100)
        #expect(abs(distance - (27 + MarkerTimeframeJumpLayout.standoff)) < 0.5)

        let below = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 100, y: 100), scaledRadius: 27, isBelow: true, jumps: jumps
        )
        #expect(below == above, "the side of the candle does not move the badges")

        // The arrow ring clears the glyph's own ring (radius 27 + 1.5).
        for placement in above {
            let gap = hypot(placement.center.x - 100, placement.center.y - 100)
                - MarkerTimeframeJumpLayout.arrowRadius - 1.5 - 28.5
            #expect(gap > 2, "badge \(placement.jump.direction) touches the glyph ring")
        }

        // Badges clear the like badge (x+8…x+22, y+5…y+19 for an above glyph)
        // and the response-count badge (x-22…x-8, same rows).
        let likeBadge = CGRect(x: 108, y: 105, width: 14, height: 14)
        let countBadge = CGRect(x: 78, y: 105, width: 14, height: 14)
        for placement in above {
            let badge = CGRect(
                x: placement.center.x - MarkerTimeframeJumpLayout.arrowRadius,
                y: placement.center.y - MarkerTimeframeJumpLayout.arrowRadius,
                width: MarkerTimeframeJumpLayout.arrowRadius * 2,
                height: MarkerTimeframeJumpLayout.arrowRadius * 2
            )
            #expect(!badge.intersects(likeBadge))
            #expect(!badge.intersects(countBadge))
        }
    }

    @Test
    func aTapInsideTheHitRadiusResolvesAndOutsideDoesNot() throws {
        let parent = preview(key: "p", marker: 1, timeframe: "1h")
        let jump = MarkerTimeframeJump(markerId: id(1), direction: .toParent, relationship: MarkerLinkRelationshipValue(raw: "supports"), timeframe: .h1, others: 0, preview: parent)
        let placements = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 100, y: 100), scaledRadius: 27, isBelow: false, jumps: [jump]
        )
        let center = try #require(placements.first?.center)

        let inside = CGPoint(x: center.x + MarkerTimeframeJumpLayout.hitRadius - 1, y: center.y)
        let outside = CGPoint(x: center.x + MarkerTimeframeJumpLayout.hitRadius + 1, y: center.y)
        #expect(MarkerTimeframeJumpLayout.placement(at: inside, in: placements)?.jump == jump)
        #expect(MarkerTimeframeJumpLayout.placement(at: outside, in: placements) == nil)
        #expect(MarkerTimeframeJumpLayout.placement(at: CGPoint(x: 100, y: 100), in: placements) == nil,
                "the glyph centre is the glyph's, not the badge's")
    }

    @Test
    func badgesRevealWithTheSelectionPop() {
        #expect(MarkerTimeframeJumpLayout.reveal(selectedMarkerScale: 1.0) == 0)
        #expect(MarkerTimeframeJumpLayout.reveal(selectedMarkerScale: 1.25) == 0.5)
        #expect(MarkerTimeframeJumpLayout.reveal(selectedMarkerScale: 1.5) == 1)
        #expect(MarkerTimeframeJumpLayout.reveal(selectedMarkerScale: 1.7) == 1, "overshoot clamps")
    }
}
