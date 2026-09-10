import CoreGraphics
import Foundation
import Testing
@testable import traders_guild

/// Which marker a tap selects, at the production seam.
///
/// The bug this covers: focus-mode taps went through the legacy path, which
/// recomputes *unnudged* centres, walks *creation* order and uses a fixed
/// radius. None of those is what was drawn, so a tap in a dense stack could
/// select the glyph behind the one under the finger. Walking a thesis by
/// tapping is the feature, so the hit has to agree with the picture.
@MainActor
struct MarkerFocusHitTestingTests {

    private let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func member(_ n: Int) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n), role: "member", reputation: 0, contributionScore: 0,
            dateJoined: anchor, accuracyRate: nil, mutedUntil: nil, suspendedUntil: nil,
            userId: id(n), username: "user\(n)", displayName: "User \(n)", avatarUrl: nil,
            isOnline: false, globalReputation: 0, isFriend: false, friendshipStatus: nil,
            isBlocked: false, isBlockedBy: false
        )
    }

    /// One candle's stack: markers share a candle index and differ by stack slot,
    /// which is exactly the arrangement the nudge and paint order exist for.
    private func marker(
        _ n: Int,
        stackIndex: Int,
        createdOffset: TimeInterval,
        below: Bool = false,
        parent: UUID? = nil
    ) -> ChartMarkerUI {
        var ui = ChartMarkerUI(
            marker: RLChartMarkerDTO(
                id: id(n), symbolId: symbolId, guildId: guildId, author: member(1),
                candleTimestamp: anchor, timeframe: "1h", price: 100,
                intent: "analysis", title: "M\(n)", note: nil, visibility: "guild",
                confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
                createdAt: anchor.addingTimeInterval(createdOffset), createdAtFormatted: "now",
                isVisible: true, likeCount: 0, isLikedByCurrentUser: false,
                commentCount: 0, comments: [],
                isCurrentUserMarker: false, canEdit: false, canDelete: false,
                components: [], primaryComponentId: nil,
                pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
                parentMarkerId: parent,
                linkRelationship: parent == nil ? nil : "supports"
            ),
            candleIndex: 0
        )
        ui.positionedBelow = below
        ui.stackIndex = stackIndex
        ui.hasStableLayout = true
        return ui
    }

    private let candles = [
        RLCandleDTO(timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                    open: 100, high: 110, low: 90, close: 105, volume: nil)
    ]
    private let chartSize = CGSize(width: 400, height: 800)

    /// The candle sits in the middle of the price range on purpose. Fill the
    /// whole range and every marker is pushed above the top and clamped by
    /// `computeMarkerScreenPosition` to the same y, so a stack fixture stops
    /// being a stack.
    private let priceFloor = 0.0
    private let priceCeiling = 200.0

    /// Where the renderer would actually paint a marker, including the nudge.
    private func paintedCenter(
        of marker: ChartMarkerUI,
        among all: [ChartMarkerUI],
        selectedId: UUID?,
        selectedScale: CGFloat
    ) -> CGPoint {
        let range = CGFloat(priceCeiling - priceFloor)
        let highY = chartSize.height - (CGFloat(110.0 - priceFloor) / range) * chartSize.height
        let lowY = chartSize.height - (CGFloat(90.0 - priceFloor) / range) * chartSize.height
        var positions: [(marker: ChartMarkerUI, position: CGPoint)] = all
            .sorted { $0.createdAt < $1.createdAt }
            .map { m in
                (m, MarkerPositionCalculator.computeMarkerScreenPosition(
                    marker: m, candleHighY: highY, candleLowY: lowY,
                    centerX: chartSize.width / 2, priceScale: 1.0,
                    viewportHeight: chartSize.height
                ))
            }
        MarkerStackLayout.applySelectionNudge(
            to: &positions, selectedMarkerId: selectedId, selectedMarkerScale: selectedScale
        )
        return positions.first { $0.marker.id == marker.id }!.position
    }

    private func hit(
        at point: CGPoint,
        markers: [ChartMarkerUI],
        selectedId: UUID? = nil,
        selectedScale: CGFloat = 1.0,
        focusMemberIds: Set<UUID> = []
    ) -> ChartMarkerUI? {
        ChartMarkerSystem.findMarkerAtLocation(
            point,
            markers: markers,
            candles: candles,
            chartSize: chartSize,
            priceRange: (min: priceFloor, max: priceCeiling),
            priceScale: 1.0,
            verticalOffset: 0,
            totalCandleWidth: 40,
            actualCandleWidth: 28,
            totalOffset: chartSize.width / 2 - 14,
            selectedMarkerId: selectedId,
            selectedMarkerScale: selectedScale,
            focusMemberIds: focusMemberIds
        )
    }

    // MARK: - The nudge must be shared

    /// The renderer moves a selected glyph's immediate neighbours 10pt clear.
    /// Hit testing that ignores the nudge is looking where the glyph *was*.
    @Test
    func theSelectionNudgeMovesOnlyImmediateNeighboursOnTheSameSide() {
        let selected = marker(1, stackIndex: 1, createdOffset: 0)
        let above = marker(2, stackIndex: 0, createdOffset: 1)
        let below = marker(3, stackIndex: 2, createdOffset: 2)
        let distant = marker(4, stackIndex: 5, createdOffset: 3)
        let otherSide = marker(5, stackIndex: 2, createdOffset: 4, below: true)
        let all = [selected, above, below, distant, otherSide]

        var unnudged: [(marker: ChartMarkerUI, position: CGPoint)] =
            all.map { ($0, CGPoint(x: 100, y: 100)) }
        var nudged = unnudged
        MarkerStackLayout.applySelectionNudge(
            to: &nudged, selectedMarkerId: selected.id, selectedMarkerScale: 1.5
        )

        #expect(nudged[0].position == unnudged[0].position, "the selected glyph does not move")
        #expect(nudged[1].position != unnudged[1].position, "stackIndex - 1 moves")
        #expect(nudged[2].position != unnudged[2].position, "stackIndex + 1 moves")
        #expect(nudged[3].position == unnudged[3].position, "a distant slot stays put")
        #expect(nudged[4].position == unnudged[4].position, "the other side stays put")

        // And nothing moves at all when the selection is not scaled up.
        var unscaled = unnudged
        MarkerStackLayout.applySelectionNudge(
            to: &unscaled, selectedMarkerId: selected.id, selectedMarkerScale: 1.0
        )
        #expect(unscaled.map(\.position) == unnudged.map(\.position))
    }

    // MARK: - Paint priority decides overlaps

    /// Unrelated below, members above, selected on top.
    @Test
    func paintPriorityOrdersUnrelatedThenMemberThenSelected() {
        let members: Set<UUID> = [id(1), id(2)]
        #expect(MarkerStackLayout.paintPriority(markerId: id(9), isSelected: false, focusMemberIds: members) == 0)
        #expect(MarkerStackLayout.paintPriority(markerId: id(2), isSelected: false, focusMemberIds: members) == 1)
        #expect(MarkerStackLayout.paintPriority(markerId: id(1), isSelected: true, focusMemberIds: members) == 2)
    }

    /// A focus member drawn over a dimmed neighbour must win the tap. This is
    /// the case the plan calls out: prefer thesis members when two candidates
    /// fall within radius, so a tap near a cluster lands on the marker being
    /// read about.
    @Test
    func aFocusMemberAboveADimmedMarkerWinsTheTap() throws {
        // Deliberately far down the stack, clear of the selected glyph: this
        // isolates member-over-unrelated. A tap *inside* the selected glyph
        // correctly selects it — that is what being drawn on top at 1.5x means
        // — and is covered separately below.
        let root = marker(1, stackIndex: 0, createdOffset: 0)
        let unrelated = marker(9, stackIndex: 6, createdOffset: 1)
        let response = marker(2, stackIndex: 6, createdOffset: 2, parent: id(1))
        let all = [root, unrelated, response]

        // Same stack slot on the same side, so both land on the same point —
        // the overlap the tap has to resolve by paint order.
        let point = paintedCenter(of: response, among: all, selectedId: id(1), selectedScale: 1.5)
        #expect(
            point == paintedCenter(of: unrelated, among: all, selectedId: id(1), selectedScale: 1.5),
            "the fixture must actually overlap, or this proves nothing"
        )

        let picked = try #require(hit(
            at: point, markers: all,
            selectedId: id(1), selectedScale: 1.5,
            focusMemberIds: [id(1), id(2)]
        ))
        #expect(picked.id == id(2), "the thesis member paints above the dimmed marker, so it takes the tap")
    }

    /// The complement: a tap that lands inside the selected glyph selects the
    /// selected glyph, because that is what is on top. Recorded so the
    /// member-preference rule above is not mistaken for "members always win".
    @Test
    func aTapInsideTheSelectedGlyphSelectsIt() throws {
        let root = marker(1, stackIndex: 0, createdOffset: 0)
        let response = marker(2, stackIndex: 1, createdOffset: 1, parent: id(1))
        let all = [root, response]
        let center = paintedCenter(of: root, among: all, selectedId: id(1), selectedScale: 1.5)

        let picked = try #require(hit(
            at: center, markers: all,
            selectedId: id(1), selectedScale: 1.5, focusMemberIds: [id(1), id(2)]
        ))
        #expect(picked.id == id(1))
    }

    /// The scaled selected glyph is bigger than its resting self; a tap inside
    /// its enlarged disc but outside the resting one must still find it.
    @Test
    func theScaledSelectedGlyphKeepsItsEnlargedTarget() throws {
        let selected = marker(1, stackIndex: 0, createdOffset: 0)
        let all = [selected]
        let center = paintedCenter(of: selected, among: all, selectedId: id(1), selectedScale: 1.5)
        // Inside the 28pt touch radius, which is what the plan preserves.
        let nearby = CGPoint(x: center.x + 20, y: center.y)

        let picked = try #require(hit(
            at: nearby, markers: all,
            selectedId: id(1), selectedScale: 1.5, focusMemberIds: [id(1)]
        ))
        #expect(picked.id == id(1))
    }

    /// Parent → unrelated → response, the fixture shape from the plan: the
    /// unrelated marker sits between them and must not steal a tap aimed at the
    /// response.
    @Test
    func parentUnrelatedResponseResolvesToTheIntendedMember() throws {
        let parent = marker(1, stackIndex: 0, createdOffset: 0)
        let unrelated = marker(9, stackIndex: 5, createdOffset: 1)
        let response = marker(2, stackIndex: 5, createdOffset: 2, parent: id(1))
        let all = [parent, unrelated, response]

        // Clear of the selected parent, and coincident with the unrelated
        // marker so the tap genuinely has to choose between them.
        let point = paintedCenter(of: response, among: all, selectedId: id(1), selectedScale: 1.5)
        let picked = try #require(hit(
            at: point, markers: all,
            selectedId: id(1), selectedScale: 1.5, focusMemberIds: [id(1), id(2)]
        ))
        #expect(picked.id == id(2))
    }

    /// A tap on empty chart selects nothing, which is what lets focus exit.
    @Test
    func anEmptyTapSelectsNothing() {
        let all = [marker(1, stackIndex: 0, createdOffset: 0)]
        #expect(hit(
            at: CGPoint(x: 10, y: 10), markers: all,
            selectedId: id(1), selectedScale: 1.5, focusMemberIds: [id(1)]
        ) == nil)
    }

    // MARK: - Legacy behaviour is untouched

    /// With no focus, the 1.2.1 path runs verbatim. A standalone marker outside
    /// any thesis must behave exactly as it always has.
    @Test
    func standaloneHitTestingIsUnchangedWhenNoThesisIsFocused() throws {
        let standalone = marker(1, stackIndex: 0, createdOffset: 0)
        let all = [standalone]
        let center = paintedCenter(of: standalone, among: all, selectedId: nil, selectedScale: 1.0)

        let picked = try #require(hit(at: center, markers: all))
        #expect(picked.id == id(1))

        // Well outside the fixed 28pt radius: still a miss, as before.
        #expect(hit(at: CGPoint(x: center.x + 200, y: center.y), markers: all) == nil)
    }

    /// And an empty focus set takes the legacy path even with a selection —
    /// `selectedStandalone` must not start behaving like focus mode.
    @Test
    func aSelectedStandaloneMarkerStillUsesTheLegacyPath() throws {
        let standalone = marker(1, stackIndex: 0, createdOffset: 0)
        let all = [standalone]
        let center = paintedCenter(of: standalone, among: all, selectedId: nil, selectedScale: 1.0)

        let picked = try #require(hit(
            at: center, markers: all,
            selectedId: id(1), selectedScale: 1.5, focusMemberIds: []
        ))
        #expect(picked.id == id(1))
    }
}
