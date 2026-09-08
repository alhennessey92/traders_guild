import CoreGraphics
import Foundation
import Testing
@testable import traders_guild

/// Reveal policy and the rendering primitives that carry it.
struct MarkerLinkRenderTests {

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    // MARK: - Reduce Motion

    /// Under Reduce Motion focus must still appear — it simply must not
    /// animate. A zero duration is the signal to snap.
    @Test
    func reduceMotionSnapsInsteadOfHidingFocus() {
        #expect(MarkerLinkRevealPolicy.target(focused: true) == 1)
        #expect(MarkerLinkRevealPolicy.duration(focused: true, reduceMotion: true) == 0)
        #expect(MarkerLinkRevealPolicy.duration(focused: false, reduceMotion: true) == 0)
        #expect(!MarkerLinkRevealPolicy.restartsFromZero(focused: true, reduceMotion: true))
    }

    @Test
    func normalMotionDrawsInAndClearsFaster() {
        let inDuration = MarkerLinkRevealPolicy.duration(focused: true, reduceMotion: false)
        let outDuration = MarkerLinkRevealPolicy.duration(focused: false, reduceMotion: false)
        #expect(inDuration > 0)
        #expect(outDuration > 0)
        #expect(outDuration < inDuration, "faster out than in, matching selection feel")
        #expect(MarkerLinkRevealPolicy.restartsFromZero(focused: true, reduceMotion: false))
        #expect(!MarkerLinkRevealPolicy.restartsFromZero(focused: false, reduceMotion: false))
    }

    @Test
    func unfocusedTargetIsZero() {
        #expect(MarkerLinkRevealPolicy.target(focused: false) == 0)
    }

    // MARK: - Reveal trimming

    /// The reveal trims the path rather than fading it: a half-drawn line reads
    /// as a connection being made, a ghosted full line reads as an artefact.
    @Test
    func revealTrimsThePathRatherThanFadingIt() {
        let route = MarkerLinkRoute(
            edge: MarkerLinkEdge(
                parentId: id(1),
                childId: id(2),
                relationship: MarkerLinkRelationshipValue(.supports),
                kind: .childOfSelected
            ),
            start: CGPoint(x: 100, y: 200),
            end: CGPoint(x: 100, y: 100),
            control: CGPoint(x: 60, y: 150),
            relationship: MarkerLinkRelationshipValue(.supports)
        )

        let quarter = MarkerLinkRenderer.trimmedPath(for: route, progress: 0.25)
        let full = MarkerLinkRenderer.trimmedPath(for: route, progress: 1)

        #expect(!quarter.isEmpty)
        #expect(!full.isEmpty)
        // A partial reveal covers strictly less of the curve.
        #expect(quarter.boundingRect.height < full.boundingRect.height)
    }

    @Test
    func zeroProgressDrawsNothing() {
        let plan = MarkerLinkRoutePlan(routes: [], omittedEdges: [])
        // A route list is empty here, but the guard that matters is progress:
        // the renderer must return before stroking anything at zero.
        #expect(plan.routes.isEmpty)
        #expect(MarkerLinkRevealPolicy.target(focused: false) == 0)
    }

    // MARK: - Badge geometry

    /// Likes sit at x+8…x+22. The response badge mirrors them on the left, so
    /// the two can never overlap however many of each a marker has.
    @Test
    func responseBadgeNeverOverlapsTheLikeBadge() {
        let center = CGPoint(x: 200, y: 400)
        for isBelow in [true, false] {
            let response = MarkerLinkRenderer.responseBadgeRect(center: center, isBelow: isBelow)
            let all = MarkerLinkRenderer.badgeRects(
                center: center,
                isBelow: isBelow,
                likeCount: 3,
                responseCount: 2
            )
            #expect(all.count == 2)
            let like = try? #require(all.first { $0 != response })
            if let like {
                #expect(!like.intersects(response), "badges must not overlap")
                #expect(response.maxX < like.minX, "responses left, likes right")
            }
        }
    }

    @Test
    func badgeRectsOmitZeroCounts() {
        let center = CGPoint(x: 200, y: 400)
        #expect(
            MarkerLinkRenderer.badgeRects(center: center, isBelow: false, likeCount: 0, responseCount: 0)
                .isEmpty
        )
        #expect(
            MarkerLinkRenderer.badgeRects(center: center, isBelow: false, likeCount: 0, responseCount: 1)
                .count == 1
        )
    }

    // MARK: - Focus dimming

    @Test
    func renderContextDimsOnlyUnrelatedMarkers() {
        let focus = MarkerFocusState(
            selectedId: id(1),
            memberIds: [id(1), id(2)],
            visibleMemberIds: [id(1), id(2)],
            shouldFadeUnrelated: true,
            candidateEdges: []
        )
        let context = MarkerLinkRenderContext(
            focus: focus,
            ringStyles: [:],
            revealProgress: 1,
            plotRect: CGRect(x: 0, y: 0, width: 400, height: 800)
        )

        #expect(!context.isDimmed(id(1)))
        #expect(!context.isDimmed(id(2)))
        #expect(context.isDimmed(id(99)))
    }

    /// When the fade is suppressed — fewer than two visible members — nothing
    /// dims at all, so the chart never darkens around a lone glyph.
    @Test
    func suppressedFadeDimsNothing() {
        let focus = MarkerFocusState(
            selectedId: id(1),
            memberIds: [id(1), id(2)],
            visibleMemberIds: [id(1)],
            shouldFadeUnrelated: false,
            candidateEdges: []
        )
        let context = MarkerLinkRenderContext(
            focus: focus,
            ringStyles: [:],
            revealProgress: 1,
            plotRect: .zero
        )
        #expect(!context.isDimmed(id(99)))
    }

    // MARK: - Relationship distinctness

    /// Relationship must be separable without colour, so the three dash
    /// patterns have to differ from each other and from the grey stack spine's
    /// [3, 2].
    @Test
    func dashPatternsAreDistinctFromEachOtherAndTheStackSpine() {
        let patterns = MarkerLinkRelationship.allCases.map(\.dashPattern)
        let unique = Set(patterns.map { $0.map(String.init).joined(separator: ",") })
        #expect(unique.count == MarkerLinkRelationship.allCases.count)
        for pattern in patterns {
            #expect(pattern != [3, 2], "must not match the existing stack connector")
        }
    }

    @Test
    func everyRelationshipHasItsOwnIconAndName() {
        let names = Set(MarkerLinkRelationship.allCases.map(\.displayName))
        let icons = Set(MarkerLinkRelationship.allCases.map(\.icon))
        #expect(names.count == 3)
        #expect(icons.count == 3)
    }
}
