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

    /// The window has loaded, says the branch continues, and none of the
    /// loaded children is elsewhere: the badge cannot name a destination, so
    /// it says "more" and opens the list. Before this there was no badge at
    /// all under a count badge that plainly showed responses.
    @Test
    func anUnloadedBranchEarnsAnEllipsisThatOpensTheList() throws {
        let root = marker(1, timeframe: "5m", responses: 3)
        let thread = window(
            requested: 1, root: "r",
            nodes: [
                preview(key: "r", marker: 1, timeframe: "5m", relationship: nil),
                // One loaded child, on this timeframe: a connector, not a badge.
                preview(key: "a", parentKey: "r", marker: 2, timeframe: "5m", relationship: "supports"),
            ],
            branches: [RLMarkerThreadBranchDTO(nodeKey: "r", cursor: "more")]
        )
        let jumps = MarkerTimeframeJumpResolver.jumps(for: root, currentTimeframe: .m5, thread: thread)
        let jump = try #require(jumps.first)
        #expect(jump.direction == .toResponse)
        #expect(jump.requiresChoice)
        #expect(jump.badgeText == "…")
        #expect(jump.markerId == root.id, "it points at the marker itself; the chooser loads the branch")
        #expect(jump.relationship.known == nil, "no relationship to colour it with")
    }

    @Test
    func aCompleteBranchWithOnlyLocalChildrenEarnsNoBadge() {
        let root = marker(1, timeframe: "5m", responses: 1)
        let thread = window(requested: 1, root: "r", nodes: [
            preview(key: "r", marker: 1, timeframe: "5m", relationship: nil),
            preview(key: "a", parentKey: "r", marker: 2, timeframe: "5m", relationship: "supports"),
        ])
        #expect(MarkerTimeframeJumpResolver.jumps(for: root, currentTimeframe: .m5, thread: thread).isEmpty)
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

    private func jumpPair() -> [MarkerTimeframeJump] {
        let parent = preview(key: "p", marker: 1, timeframe: "1h")
        let child = preview(key: "c", parentKey: "m", marker: 3, timeframe: "5m", relationship: "builds_on")
        return [
            MarkerTimeframeJump(markerId: id(1), direction: .toParent, relationship: MarkerLinkRelationshipValue(raw: "supports"), timeframe: .h1, others: 0, preview: parent),
            MarkerTimeframeJump(markerId: id(3), direction: .toResponse, relationship: MarkerLinkRelationshipValue(raw: "builds_on"), timeframe: .m5, others: 0, preview: child),
        ]
    }

    private func footprint(_ placement: MarkerTimeframeJumpLayout.Placement) -> CGRect {
        MarkerTimeframeJumpLayout.footprint(placement.center)
    }

    @Test
    func badgesSplayOutwardAwayFromTheCandleParentRightResponseLeft() throws {
        let glyph = CGPoint(x: 100, y: 100)
        let above = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair()
        )
        #expect(above.count == 2)
        #expect(above[0].center.x > glyph.x && above[0].center.y < glyph.y, "parent: up and to the right")
        #expect(above[1].center.x < glyph.x && above[1].center.y < glyph.y, "response: up and to the left")
        for placement in above {
            let distance = hypot(placement.center.x - glyph.x, placement.center.y - glyph.y)
            #expect(abs(distance - (27 + MarkerTimeframeJumpLayout.standoff)) < 0.5)
            #expect(abs(abs(placement.center.x - glyph.x) - abs(placement.center.y - glyph.y)) < 0.5, "45° splay")
        }

        let below = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: true, jumps: jumpPair()
        )
        #expect(below[0].center.y > glyph.y && below[1].center.y > glyph.y, "a glyph under its candle hangs its badges downward")
        #expect(below[0].center.x == above[0].center.x && below[1].center.x == above[1].center.x, "mirrored, not moved sideways")
    }

    @Test
    func theTetherRunsFromTheGlyphRingToTheArrowRing() throws {
        let glyph = CGPoint(x: 100, y: 100)
        let placement = try #require(MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair()
        ).first)

        let startDistance = hypot(placement.tetherStart.x - glyph.x, placement.tetherStart.y - glyph.y)
        let endDistance = hypot(placement.tetherEnd.x - placement.center.x, placement.tetherEnd.y - placement.center.y)
        #expect(abs(startDistance - (27 + MarkerTimeframeJumpLayout.tetherInset)) < 0.01, "leaves the glyph just outside its ring")
        #expect(abs(endDistance - (MarkerTimeframeJumpLayout.arrowRadius + MarkerTimeframeJumpLayout.tetherInset)) < 0.01, "meets the badge just outside the arrow")
        // Collinear with glyph → badge, and pointing the same way.
        let cross = (placement.tetherEnd.x - placement.tetherStart.x) * (placement.center.y - glyph.y)
            - (placement.tetherEnd.y - placement.tetherStart.y) * (placement.center.x - glyph.x)
        #expect(abs(cross) < 0.01)
        let visibleLength = hypot(placement.tetherEnd.x - placement.tetherStart.x, placement.tetherEnd.y - placement.tetherStart.y)
        #expect(visibleLength > 10, "a tether too short to see is no tether")
    }

    @Test
    func badgesClearTheStackNeighbourAndTheCandleSideBadges() throws {
        let glyph = CGPoint(x: 100, y: 100)
        let above = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair()
        )
        // The next glyph outward in the same stack, after the selection nudge.
        let neighbour = CGRect(x: 100 - 18, y: 100 - 27 - 6 - 36, width: 36, height: 36)
        // Like badge (x+8…x+22, y+5…y+19) and count badge (x-22…x-8) sit on the candle side.
        let likeBadge = CGRect(x: 108, y: 105, width: 14, height: 14)
        let countBadge = CGRect(x: 78, y: 105, width: 14, height: 14)
        for placement in above {
            #expect(!footprint(placement).intersects(neighbour), "\(placement.jump.direction) lands on the stack neighbour")
            #expect(!footprint(placement).intersects(likeBadge))
            #expect(!footprint(placement).intersects(countBadge))
            let gap = hypot(placement.center.x - glyph.x, placement.center.y - glyph.y)
                - MarkerTimeframeJumpLayout.arrowRadius - 1.5 - 28.5
            #expect(gap > 2, "arrow ring touches the glyph ring")
        }
    }

    @Test
    func aBadgeThatWouldBeClippedAtTheTopFlipsToTheCandleSide() throws {
        let plot = CGRect(x: 0, y: 0, width: 400, height: 600)
        let glyph = CGPoint(x: 200, y: 40)
        let placements = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot
        )
        for placement in placements {
            #expect(placement.center.y > glyph.y, "outward would leave the plot, so \(placement.jump.direction) flips downward")
            #expect(plot.contains(footprint(placement)))
        }
        // Mirror: a glyph under its candle near the bottom flips upward.
        let low = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 200, y: 570), scaledRadius: 27, isBelow: true, jumps: jumpPair(), plotRect: plot
        )
        for placement in low {
            #expect(placement.center.y < 570)
            #expect(plot.contains(footprint(placement)))
        }
    }

    @Test
    func aBadgeAtTheSideOfThePlotSlidesBackIn() throws {
        let plot = CGRect(x: 0, y: 0, width: 400, height: 600)
        let placements = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 390, y: 300), scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot
        )
        let parentBadge = try #require(placements.first { $0.jump.direction == .toParent })
        #expect(plot.contains(footprint(parentBadge)), "slid in from the right edge")
        #expect(parentBadge.center.y < 300, "still outward — clamping sideways does not flip")
        #expect(parentBadge.tetherStart != parentBadge.tetherEnd, "the tether follows the badge to its final spot")
    }

    @Test
    func aBadgeBlockedOnItsOwnSideCrossesToTheOtherSideBeforeLeavingTheOutwardBand() throws {
        let plot = CGRect(x: 0, y: 0, width: 400, height: 600)
        let glyph = CGPoint(x: 200, y: 300)
        // A card covering the whole left half of the outward band.
        let leftCard = CGRect(x: 0, y: 200, width: 200, height: 80)
        let placements = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot, avoidRect: leftCard
        )
        let parent = try #require(placements.first { $0.jump.direction == .toParent })
        let response = try #require(placements.first { $0.jump.direction == .toResponse })

        #expect(parent.center.x > glyph.x && parent.center.y < glyph.y, "parent keeps its own outward spot")
        #expect(response.center.y < glyph.y, "response stays outward…")
        #expect(response.center.x > glyph.x, "…by crossing to the free side")
        #expect(!footprint(response).intersects(leftCard))
        #expect(!footprint(response).intersects(footprint(parent)), "and does not sit on the parent badge")
        #expect(plot.contains(footprint(response)))
    }

    @Test
    func aBadgeUnderTheInfoCardSlidesOutwardThenFlips() throws {
        let plot = CGRect(x: 0, y: 0, width: 400, height: 600)
        let glyph = CGPoint(x: 200, y: 200)
        let free = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot
        )
        let parentFree = try #require(free.first { $0.jump.direction == .toParent })

        // A card whose right edge crosses the parent badge by a few points:
        // sliding outward is enough.
        let narrowCard = CGRect(x: 0, y: 100, width: parentFree.center.x - MarkerTimeframeJumpLayout.outerRadius + 6, height: 80)
        let slid = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot, avoidRect: narrowCard
        )
        let parentSlid = try #require(slid.first { $0.jump.direction == .toParent })
        #expect(!footprint(parentSlid).intersects(narrowCard))
        #expect(parentSlid.center.y == parentFree.center.y, "kept outward")
        #expect(parentSlid.center.x > parentFree.center.x, "moved away from the glyph, not toward it")

        // A card covering the whole outward band on both sides: nowhere to
        // slide, so the candle side is the only band left.
        let wideCard = CGRect(x: 0, y: 100, width: 400, height: 80)
        let flipped = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot, avoidRect: wideCard
        )
        for placement in flipped {
            #expect(!footprint(placement).intersects(wideCard))
            #expect(placement.center.y > glyph.y, "\(placement.jump.direction) flipped to the candle side")
        }
    }

    @Test
    func aBadgeNeverSitsOnANeighbouringGlyph() throws {
        let plot = CGRect(x: 0, y: 0, width: 400, height: 600)
        let glyph = CGPoint(x: 200, y: 300)
        let free = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot
        )
        let responseFree = try #require(free.first { $0.jump.direction == .toResponse })
        // A marker on an earlier candle whose disc covers the response badge's
        // preferred spot — the shape of a neighbour a connector would join.
        let neighbour = CGRect(x: responseFree.center.x - 18, y: responseFree.center.y - 18, width: 36, height: 36)

        let placed = MarkerTimeframeJumpLayout.placements(
            selectedCenter: glyph, scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot, obstacles: [neighbour]
        )
        let response = try #require(placed.first { $0.jump.direction == .toResponse })
        let parent = try #require(placed.first { $0.jump.direction == .toParent })
        #expect(!footprint(response).intersects(neighbour))
        #expect(!footprint(response).intersects(footprint(parent)))
        #expect(response.center.y < glyph.y, "still outward — it slid, it did not flip")
        #expect(parent == free.first { $0.jump.direction == .toParent }, "the unblocked badge does not move")
    }

    @Test
    func drawAndHitTestShareOnePlacement() throws {
        // The renderer and the tap resolve through the same function with the
        // same inputs, so the same call twice must be identical — including
        // after avoidance moved a badge.
        let plot = CGRect(x: 0, y: 0, width: 400, height: 600)
        let card = CGRect(x: 0, y: 100, width: 400, height: 80)
        let a = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 200, y: 200), scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot, avoidRect: card
        )
        let b = MarkerTimeframeJumpLayout.placements(
            selectedCenter: CGPoint(x: 200, y: 200), scaledRadius: 27, isBelow: false, jumps: jumpPair(), plotRect: plot, avoidRect: card
        )
        #expect(a == b)
        let hit = try #require(MarkerTimeframeJumpLayout.placement(at: a[0].center, in: b))
        #expect(hit.jump == a[0].jump)
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
