import CoreGraphics
import Foundation
import Testing
@testable import traders_guild

/// Connector routing.
///
/// Geometry here uses the real chart constants: a 36pt glyph (radius 18), the
/// 40pt hard minimum stack spacing, the 1.5 selection scale, and the like badge
/// at x+8…x+22 with the response badge mirrored at x−22…x−8.
struct MarkerLinkGeometryTests {

    private let glyphRadius: CGFloat = 18
    private let selectedRadius: CGFloat = 27  // 18 * 1.5
    private let stackSpacing: CGFloat = 40
    private let plot = CGRect(x: 0, y: 0, width: 400, height: 800)

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    /// Badges as the renderer places them, in absolute coordinates.
    private func badges(at center: CGPoint, isBelow: Bool, likes: Bool, responses: Bool) -> [CGRect] {
        let offset: CGFloat = isBelow ? -17 : 5
        var rects: [CGRect] = []
        if likes {
            rects.append(CGRect(x: center.x + 8, y: center.y + offset, width: 14, height: 14))
        }
        if responses {
            rects.append(CGRect(x: center.x - 22, y: center.y + offset, width: 14, height: 14))
        }
        return rects
    }

    private func glyph(
        _ n: Int,
        _ center: CGPoint,
        radius: CGFloat? = nil,
        likes: Bool = false,
        responses: Bool = false
    ) -> MarkerGlyphBounds {
        MarkerGlyphBounds(
            id: id(n),
            center: center,
            radius: radius ?? glyphRadius,
            badgeRects: badges(at: center, isBelow: false, likes: likes, responses: responses)
        )
    }

    private func edge(parent: Int, child: Int) -> MarkerLinkEdge {
        MarkerLinkEdge(
            parentId: id(parent),
            childId: id(child),
            relationship: MarkerLinkRelationshipValue(.supports),
            kind: .childOfSelected
        )
    }

    // MARK: - The drawn curve must be the curve that was routed

    /// Maximum turn between consecutive samples of a path, in degrees.
    ///
    /// This is what "angular" means numerically: a polyline approximation of a
    /// too-tight arc puts the whole bend into one or two vertices.
    private func maxTurnDegrees(_ points: [CGPoint]) -> CGFloat {
        var worst: CGFloat = 0
        for index in 1..<(points.count - 1) {
            let a = CGPoint(x: points[index].x - points[index - 1].x,
                            y: points[index].y - points[index - 1].y)
            let b = CGPoint(x: points[index + 1].x - points[index].x,
                            y: points[index + 1].y - points[index].y)
            let na = sqrt(a.x * a.x + a.y * a.y)
            let nb = sqrt(b.x * b.x + b.y * b.y)
            guard na > 0.0001, nb > 0.0001 else { continue }
            let cosine = max(-1, min(1, (a.x * b.x + a.y * b.y) / (na * nb)))
            worst = max(worst, acos(cosine) * 180 / .pi)
        }
        return worst
    }

    /// Perpendicular distance from the chord, at its widest — the sagitta.
    private func sagitta(of route: MarkerLinkRoute) -> CGFloat {
        let dx = route.end.x - route.start.x
        let dy = route.end.y - route.start.y
        let chord = max(sqrt(dx * dx + dy * dy), 0.0001)
        var widest: CGFloat = 0
        for step in 0...100 {
            let point = route.point(at: CGFloat(step) / 100)
            let area = abs((point.x - route.start.x) * dy - (point.y - route.start.y) * dx)
            widest = max(widest, area / chord)
        }
        return widest
    }

    /// A trimmed connector must be the *sub-curve* of the routed one.
    ///
    /// Keeping the original control point after moving both endpoints does not
    /// shorten a Bézier, it substitutes a different and much tighter one: the
    /// control stays put while the chord collapses. Every drawn sample must lie
    /// on the curve that was collision-tested, so the two cannot diverge.
    @Test
    func aTrimmedConnectorLiesOnTheRoutedCurve() throws {
        let start = CGPoint(x: 200, y: 500)
        let end = CGPoint(x: 200, y: 460)
        let control = MarkerLinkGeometry.controlPoint(
            parent: start, child: end, magnitude: 22, side: -1
        )
        let trimmed = try #require(
            MarkerLinkGeometry.trim(
                start: start, end: end, control: control,
                startRadius: glyphRadius, endRadius: glyphRadius
            )
        )

        // Recover the parameters the trim landed on, then check the sub-curve
        // agrees with the original curve at every point between them.
        let tStart = try #require(parameter(of: trimmed.start, on: (start, control, end)))
        let tEnd = try #require(parameter(of: trimmed.end, on: (start, control, end)))

        for step in 0...20 {
            let local = CGFloat(step) / 20
            let onOriginal = MarkerLinkGeometry.quadraticPoint(
                start: start, control: control, end: end,
                t: tStart + (tEnd - tStart) * local
            )
            let onTrimmed = MarkerLinkGeometry.quadraticPoint(
                start: trimmed.start, control: trimmed.control, end: trimmed.end, t: local
            )
            #expect(abs(onOriginal.x - onTrimmed.x) < 0.5)
            #expect(abs(onOriginal.y - onTrimmed.y) < 0.5)
        }
    }

    /// Find the parameter on a quadratic nearest a point, or nil if it is not
    /// on the curve at all.
    private func parameter(
        of point: CGPoint,
        on curve: (CGPoint, CGPoint, CGPoint)
    ) -> CGFloat? {
        var best: (t: CGFloat, distance: CGFloat)?
        for step in 0...1000 {
            let t = CGFloat(step) / 1000
            let candidate = MarkerLinkGeometry.quadraticPoint(
                start: curve.0, control: curve.1, end: curve.2, t: t
            )
            let d = MarkerLinkGeometry.distance(candidate, point)
            if best == nil || d < best!.distance { best = (t, d) }
        }
        guard let best, best.distance < 0.5 else { return nil }
        return best.t
    }

    /// The same-candle case the user actually sees: a selected marker and its
    /// stacked neighbour. This is where the old retained-control trim produced
    /// a hairpin — a 19.6pt span bulging 14.5pt sideways.
    @Test
    func aSameCandleConnectorIsARoundArcNotAHairpin() throws {
        let selectedCenter = CGPoint(x: 200, y: 500)
        let neighbourCenter = CGPoint(x: 200, y: 500 - stackSpacing)
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, selectedCenter, radius: selectedRadius),
            id(2): glyph(2, neighbourCenter),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )

        let span = MarkerLinkGeometry.distance(route.start, route.end)
        let bulge = sagitta(of: route)
        #expect(span >= MarkerLinkGeometry.minimumDrawnSpan)
        // A hairpin is a sagitta approaching or exceeding half the chord; a
        // round arc sits well under it. The old geometry measured 0.74 here.
        #expect(bulge / span < 0.45, "sagitta ratio \(bulge / span) reads as a hairpin")
        // And it must still be a visible curve rather than a straight line.
        #expect(bulge / span > 0.1, "sagitta ratio \(bulge / span) is visually flat")
    }

    /// Sampling the route densely must not reveal a corner anywhere. The drawn
    /// path is a real `addQuadCurve`, so this is checking the geometry it is
    /// built from rather than the flattening.
    @Test
    func noSampleOfAConnectorTurnsSharply() throws {
        for (startY, endY, radius) in [
            (CGFloat(500), CGFloat(460), selectedRadius),   // same candle, selected
            (CGFloat(500), CGFloat(460), glyphRadius),      // same candle, plain
        ] {
            let glyphs: [UUID: MarkerGlyphBounds] = [
                id(1): glyph(1, CGPoint(x: 200, y: startY), radius: radius),
                id(2): glyph(2, CGPoint(x: 200, y: endY)),
            ]
            let route = try #require(
                MarkerLinkGeometry.route(
                    edge: edge(parent: 1, child: 2),
                    glyphs: glyphs,
                    obstacles: Array(glyphs.values)
                )
            )
            let samples = (0...32).map { route.point(at: CGFloat($0) / 32) }
            #expect(
                maxTurnDegrees(samples) < 8,
                "a 32-sample walk turned \(maxTurnDegrees(samples)) degrees at one vertex"
            )
        }
    }

    /// A cross-candle connector — the ordinary case — stays gentle and keeps
    /// its proportional bow.
    @Test
    func aCrossCandleConnectorStaysGentle() throws {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 120, y: 500)),
            id(2): glyph(2, CGPoint(x: 260, y: 430)),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )
        let samples = (0...32).map { route.point(at: CGFloat($0) / 32) }
        #expect(maxTurnDegrees(samples) < 5)
        let ratio = sagitta(of: route) / MarkerLinkGeometry.distance(route.start, route.end)
        #expect(ratio > 0.02 && ratio < 0.30, "cross-candle sagitta ratio \(ratio)")
    }

    /// The reveal draws a prefix of the connector, and that prefix must be the
    /// real sub-curve too — a partially revealed line cannot wander off the
    /// path it will settle on.
    @Test
    func aPartialRevealFollowsTheSamePath() throws {
        let start = CGPoint(x: 120, y: 500)
        let end = CGPoint(x: 260, y: 430)
        let control = MarkerLinkGeometry.controlPoint(
            parent: start, child: end, magnitude: 16, side: -1
        )
        let route = MarkerLinkRoute(
            edge: edge(parent: 1, child: 2),
            start: start, end: end, control: control,
            relationship: MarkerLinkRelationshipValue(.supports)
        )

        for progress in [CGFloat(0.25), 0.5, 0.75] {
            let partialControl = MarkerLinkGeometry.subCurveControl(
                start: start, control: control, end: end, t0: 0, t1: progress
            )
            let partialEnd = route.point(at: progress)
            for step in 0...10 {
                let local = CGFloat(step) / 10
                let onPartial = MarkerLinkGeometry.quadraticPoint(
                    start: start, control: partialControl, end: partialEnd, t: local
                )
                let onFull = route.point(at: progress * local)
                #expect(MarkerLinkGeometry.distance(onPartial, onFull) < 0.5)
            }
        }
    }

    // MARK: - The false-link case

    /// Parent, an unrelated marker, and the response all land on one candle,
    /// which is exactly what parent-candle seeding produces. The connector must
    /// route around the stranger in the middle and must never pass through it —
    /// that is what previously made tinting the shared stack spine unsafe.
    @Test
    func sameCandleStackRoutesAroundAnUnrelatedMarker() throws {
        let parentCenter = CGPoint(x: 200, y: 500)
        let strangerCenter = CGPoint(x: 200, y: 500 - stackSpacing)
        let responseCenter = CGPoint(x: 200, y: 500 - stackSpacing * 2)

        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, parentCenter, likes: true),
            id(2): glyph(2, strangerCenter, likes: true),
            id(3): glyph(3, responseCenter),
        ]

        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 3),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            ),
            "a safe lateral route exists around a single stacked stranger"
        )

        // Every drawn sample must clear the stranger's disc and its badge.
        let stranger = glyphs[id(2)]!
        for step in 0...48 {
            let point = route.point(at: CGFloat(step) / 48)
            #expect(
                !stranger.contains(point, clearance: 0),
                "connector passed through the unrelated marker at t=\(CGFloat(step) / 48)"
            )
        }

        // And it must actually bow clear of the shared stack column rather than
        // running down it, which is where the grey spine already lives.
        let apex = route.point(at: 0.5)
        #expect(abs(apex.x - 200) > glyphRadius, "route did not clear the stack column")
    }

    /// With strangers boxed in on both sides there is no safe path, and the
    /// contract says omit rather than draw something misleading.
    @Test
    func omitsEdgeWhenNoSafeRouteExists() {
        let parentCenter = CGPoint(x: 200, y: 500)
        let responseCenter = CGPoint(x: 200, y: 500 - stackSpacing * 2)
        let midY = 500 - stackSpacing

        var glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, parentCenter),
            id(3): glyph(3, responseCenter),
            id(2): glyph(2, CGPoint(x: 200, y: midY)),
        ]
        // Wall off every lateral escape either curve family could use: the
        // arc ladder reaches 44, the bracket ladder 72, and the widest
        // excursion the planner will ever search is `maximumLateralExcursion`
        // times the top of the curvature range. A wall past all of that means
        // there is genuinely no path — and the contract is then to omit, not
        // to draw through a stranger.
        let farthest = Int(MarkerLinkGeometry.maximumLateralExcursion * MarkerLinkGeometry.curvatureRange.upperBound) + 30
        var index = 0
        for dx in stride(from: 14, through: farthest, by: 18) {
            for side in [-1, 1] {
                glyphs[id(100 + index)] = glyph(100 + index, CGPoint(x: 200 + CGFloat(dx * side), y: midY))
                index += 1
            }
        }

        let route = MarkerLinkGeometry.route(
            edge: edge(parent: 1, child: 3),
            glyphs: glyphs,
            obstacles: Array(glyphs.values)
        )
        #expect(route == nil)
    }

    // MARK: - Trimming

    @Test
    func trimsToGlyphEdges() throws {
        let parentCenter = CGPoint(x: 200, y: 500)
        let childCenter = CGPoint(x: 260, y: 400)
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, parentCenter),
            id(2): glyph(2, childCenter),
        ]

        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )

        let startGap = MarkerLinkGeometry.distance(route.start, parentCenter)
        let endGap = MarkerLinkGeometry.distance(route.end, childCenter)
        // On the edge, not inside the glyph and not floating far from it.
        #expect(startGap >= glyphRadius)
        #expect(startGap < glyphRadius + 6)
        #expect(endGap >= glyphRadius)
        #expect(endGap < glyphRadius + 6)
    }

    /// A selected marker is drawn at 1.5 scale, so its disc overlaps an adjacent
    /// stack neighbour on the straight chord. The curve bows clear of the column
    /// and must still produce a usable span — this is the default flow, and it
    /// would be a silent regression if it started omitting.
    @Test
    func adjacentStackPairStillRoutesAtSelectionScale() throws {
        let selectedCenter = CGPoint(x: 200, y: 500)
        let neighbourCenter = CGPoint(x: 200, y: 500 - stackSpacing)

        // Discs overlap on the chord: 40 < 27 + 18.
        #expect(stackSpacing < selectedRadius + glyphRadius)

        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, selectedCenter, radius: selectedRadius),
            id(2): glyph(2, neighbourCenter),
        ]

        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            ),
            "an adjacent stacked pair must still connect at selection scale"
        )
        #expect(
            MarkerLinkGeometry.distance(route.start, route.end)
                >= MarkerLinkGeometry.minimumDrawnSpan
        )
    }

    @Test
    func rejectsChordsTooShortToDraw() {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 200, y: 500)),
            id(2): glyph(2, CGPoint(x: 200, y: 480)),  // 20pt apart
        ]
        #expect(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            ) == nil
        )
    }

    // MARK: - Post-nudge positions

    /// The renderer nudges stack neighbours by ±10pt when a marker is selected.
    /// Routing must consume those final positions, so the same edge produces
    /// different endpoints before and after the nudge.
    @Test
    func routesFollowPostNudgePositions() throws {
        let parentCenter = CGPoint(x: 200, y: 500)
        let childBefore = CGPoint(x: 200, y: 500 - stackSpacing * 2)
        let childAfter = CGPoint(x: childBefore.x, y: childBefore.y - 10)

        func route(childCenter: CGPoint) throws -> MarkerLinkRoute {
            let glyphs: [UUID: MarkerGlyphBounds] = [
                id(1): glyph(1, parentCenter),
                id(2): glyph(2, childCenter),
            ]
            return try #require(
                MarkerLinkGeometry.route(
                    edge: edge(parent: 1, child: 2),
                    glyphs: glyphs,
                    obstacles: Array(glyphs.values)
                )
            )
        }

        let before = try route(childCenter: childBefore)
        let after = try route(childCenter: childAfter)

        #expect(before.end != after.end, "endpoints must track the nudged position")
        // The trimmed end stays on the *nudged* glyph's edge.
        #expect(abs(MarkerLinkGeometry.distance(after.end, childAfter) - glyphRadius) < 6)
    }

    // MARK: - Opposite stacks and branches

    /// The owner's report: a parent stacked above the candle and its response
    /// stacked below it lost their connector. Both endpoints share the column,
    /// the chord is long, and there are stacked neighbours 40pt inside *each*
    /// end — a single-apex arc still hugs the column there. The bracket must
    /// find a path, and that path must not pass through either neighbour.
    @Test
    func oppositeStackConnectorRoutesAroundBothStacks() throws {
        let column: CGFloat = 200
        let parentCenter = CGPoint(x: column, y: 300)         // above the candle, slot 1
        let aboveSlot0 = CGPoint(x: column, y: 340)           // above the candle, slot 0
        let belowSlot0 = CGPoint(x: column, y: 560)           // below the candle, slot 0
        let responseCenter = CGPoint(x: column, y: 600)       // below the candle, slot 1

        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, parentCenter, likes: true, responses: true),
            id(2): glyph(2, aboveSlot0, likes: true, responses: true),
            id(3): glyph(3, belowSlot0, likes: true),
            id(4): glyph(4, responseCenter),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 4),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            ),
            "a long same-column chord past stacked neighbours must still be drawable"
        )
        #expect(route.isCubic, "this is the bracket case, not an arc")

        for strangerId in [id(2), id(3)] {
            let stranger = glyphs[strangerId]!
            for step in 0...64 {
                let point = route.point(at: CGFloat(step) / 64)
                #expect(!stranger.contains(point, clearance: 0),
                        "connector crossed a stacked neighbour at t=\(CGFloat(step) / 64)")
            }
        }
        // It leaves the column promptly rather than bulging only at the middle:
        // a quarter of the way along it is already clear of a glyph radius.
        #expect(abs(route.point(at: 0.25).x - column) > glyphRadius)
        #expect(abs(route.point(at: 0.75).x - column) > glyphRadius)
        // And it is anchored on the two glyph edges it joins.
        #expect(abs(MarkerLinkGeometry.distance(route.start, parentCenter) - glyphRadius) < 4)
        #expect(abs(MarkerLinkGeometry.distance(route.end, responseCenter) - glyphRadius) < 4)
    }

    /// The second cause of the owner's missing connectors, independent of the
    /// geometry: a thesis parent always wears the response badge at its lower
    /// corner, and with likes it wears one at the other corner too. A line
    /// leaving that glyph downward was rejected at its first sample for
    /// touching its own badge — on *both* sides. The badge is painted over the
    /// line's emergence anyway, so it must not veto the route.
    @Test
    func aParentWithBadgesOnBothSidesStillConnectsDownward() throws {
        let column: CGFloat = 200
        let glyphs: [UUID: MarkerGlyphBounds] = [
            // likes + responses: badges at both lower corners.
            id(1): glyph(1, CGPoint(x: column, y: 300), likes: true, responses: true),
            id(2): glyph(2, CGPoint(x: column, y: 340), likes: true),
            id(3): glyph(3, CGPoint(x: column, y: 560), likes: true),
            // the response also wears its own badge, lower-left when below.
            id(4): glyph(4, CGPoint(x: column, y: 600), responses: true),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 4), glyphs: glyphs,
                obstacles: Array(glyphs.values)
            ),
            "its own badges must not block a glyph's connector"
        )
        // The body still avoids every *other* glyph's badge.
        for strangerId in [id(2), id(3)] {
            let stranger = glyphs[strangerId]!
            for step in 0...64 {
                #expect(!stranger.contains(route.point(at: CGFloat(step) / 64), clearance: 0))
            }
        }
    }

    /// And when a badge-free side exists, it is still preferred — the softer
    /// second pass only runs if the first finds nothing.
    @Test
    func aBadgeFreeSideIsStillPreferredWhenThereIsOne() throws {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 200, y: 500), likes: true),   // badge on the right only
            id(2): glyph(2, CGPoint(x: 200, y: 460)),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2), glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )
        #expect(route.point(at: 0.5).x < 200, "bows left, away from the like badge")
    }

    /// Same as above with the response *selected* (1.5x), which is the exact
    /// configuration the owner was looking at.
    @Test
    func oppositeStackConnectorSurvivesTheSelectedScale() throws {
        let column: CGFloat = 200
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: column, y: 300)),
            id(2): glyph(2, CGPoint(x: column, y: 340), likes: true),
            id(3): glyph(3, CGPoint(x: column, y: 560), likes: true),
            id(4): glyph(4, CGPoint(x: column, y: 610), radius: selectedRadius),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 4),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )
        for strangerId in [id(2), id(3)] {
            let stranger = glyphs[strangerId]!
            for step in 0...64 {
                #expect(!stranger.contains(route.point(at: CGFloat(step) / 64), clearance: 0))
            }
        }
        #expect(abs(MarkerLinkGeometry.distance(route.end, CGPoint(x: column, y: 610)) - selectedRadius) < 4)
    }

    /// A branch grandchild: root above the candle, its response below, and
    /// that response's own response one slot further below. Both edges must
    /// route, and neither may touch the third glyph.
    @Test
    func branchGrandchildGetsBothEdgesWithoutTouchingTheThird() throws {
        let column: CGFloat = 200
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: column, y: 300)),          // root, above
            id(2): glyph(2, CGPoint(x: column, y: 560), likes: true), // response, below slot 0
            id(3): glyph(3, CGPoint(x: column, y: 600)),          // grandchild, below slot 1
        ]
        let edges = [
            MarkerLinkEdge(parentId: id(1), childId: id(2),
                           relationship: MarkerLinkRelationshipValue(.supports), kind: .childOfSelected),
            MarkerLinkEdge(parentId: id(2), childId: id(3),
                           relationship: MarkerLinkRelationshipValue(.buildsOn), kind: .withinThesis),
        ]
        let planned = MarkerLinkGeometry.plan(
            edges: edges, glyphs: glyphs, plotRect: plot, selectedId: id(1)
        )
        #expect(planned.routes.count == 2, "both edges of the branch are drawn")
        #expect(planned.omittedEdges.isEmpty)

        let rootToResponse = try #require(planned.routes.first { $0.edge.childId == id(2) })
        let grandchild = glyphs[id(3)]!
        for step in 0...64 {
            #expect(!grandchild.contains(rootToResponse.point(at: CGFloat(step) / 64), clearance: 0),
                    "the long edge must not run through the grandchild")
        }
        let responseToGrandchild = try #require(planned.routes.first { $0.edge.childId == id(3) })
        let root = glyphs[id(1)]!
        for step in 0...64 {
            #expect(!root.contains(responseToGrandchild.point(at: CGFloat(step) / 64), clearance: 0))
        }
    }

    /// A short same-column pair still gets the arc it always had. The bracket
    /// is a fallback for what the arc cannot do, not a replacement.
    @Test
    func shortSameColumnPairsKeepTheQuadraticArc() throws {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 200, y: 500)),
            id(2): glyph(2, CGPoint(x: 200, y: 460)),
        ]
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2), glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )
        #expect(!route.isCubic)
    }

    // MARK: - Curvature

    /// The setting scales every bow. Sagitta grows with it, and the shape
    /// family does not change.
    @Test
    func curvatureScalesTheBowWithoutChangingTheRoute() throws {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 120, y: 500)),
            id(2): glyph(2, CGPoint(x: 260, y: 430)),
        ]
        func sag(_ curvature: CGFloat) throws -> CGFloat {
            let r = try #require(MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2), glyphs: glyphs,
                obstacles: Array(glyphs.values), curvature: curvature
            ))
            return sagitta(of: r)
        }
        let flat = try sag(0.6), normal = try sag(1.0), round = try sag(1.6)
        #expect(flat < normal && normal < round)
        #expect(flat > 0, "the flattest setting is still a curve")
    }

    /// Out-of-range curvature is clamped by the planner, never applied raw.
    @Test
    func planClampsCurvatureToItsRange() {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 120, y: 500)),
            id(2): glyph(2, CGPoint(x: 260, y: 430)),
        ]
        let edges = [edge(parent: 1, child: 2)]
        let wild = MarkerLinkGeometry.plan(edges: edges, glyphs: glyphs, plotRect: plot, selectedId: id(1), curvature: 40)
        let top = MarkerLinkGeometry.plan(edges: edges, glyphs: glyphs, plotRect: plot, selectedId: id(1),
                                          curvature: MarkerLinkGeometry.curvatureRange.upperBound)
        #expect(wild.routes.first?.control == top.routes.first?.control)
    }

    // MARK: - Prioritisation, and the cap that is no longer there

    /// Every edge with a safe path is drawn. Twenty children is twenty lines,
    /// the parent still first; nothing is dropped for being the thirteenth.
    @Test
    func drawsParentFirstThenEveryChildWithASafePath() {
        let selected = CGPoint(x: 200, y: 400)
        var glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, selected, radius: selectedRadius),
            id(2): glyph(2, CGPoint(x: 60, y: 400)),  // the parent, far away
        ]
        var edges: [MarkerLinkEdge] = [
            MarkerLinkEdge(
                parentId: id(2),
                childId: id(1),
                relationship: MarkerLinkRelationshipValue(.supports),
                kind: .parentOfSelected
            )
        ]
        // 20 children on distinct candles, increasing distance, alternating
        // above and below so their discs do not overlap one another.
        for index in 0..<20 {
            let n = 10 + index
            let y: CGFloat = index % 2 == 0 ? 300 : 520
            glyphs[id(n)] = glyph(n, CGPoint(x: 200 + CGFloat(index + 1) * 52, y: y))
            edges.append(edge(parent: 1, child: n))
        }

        // Wide enough for every child to sit inside the plot, so the only
        // thing that could omit one is a real obstacle.
        let widePlot = CGRect(x: 0, y: 0, width: 1400, height: 800)
        let planned = MarkerLinkGeometry.plan(
            edges: edges,
            glyphs: glyphs,
            plotRect: widePlot,
            selectedId: id(1)
        )

        #expect(planned.routes.first?.edge.kind == .parentOfSelected,
                "the parent edge is drawn first regardless of distance")
        #expect(planned.routes.count + planned.omittedEdges.count == edges.count)
        // All twenty-one: the old cap would have stopped at twelve.
        #expect(planned.routes.count == edges.count, "got \(planned.routes.count) of \(edges.count)")
        #expect(planned.omittedEdges.isEmpty)
    }

    /// Spatial filtering must never change the answer: routing against every
    /// glyph and routing against only the nearby ones agree exactly.
    @Test
    func obstacleFilteringDoesNotChangeAnyRoute() {
        var glyphs: [UUID: MarkerGlyphBounds] = [:]
        // A 6×6 lattice of markers across the plot, plus a thesis in one corner.
        var n = 100
        for row in 0..<6 {
            for col in 0..<6 {
                glyphs[id(n)] = glyph(n, CGPoint(x: 60 + CGFloat(col) * 56, y: 120 + CGFloat(row) * 110), likes: row % 2 == 0)
                n += 1
            }
        }
        glyphs[id(1)] = glyph(1, CGPoint(x: 200, y: 300))
        glyphs[id(2)] = glyph(2, CGPoint(x: 200, y: 340), likes: true)
        glyphs[id(3)] = glyph(3, CGPoint(x: 200, y: 600))
        let edges = [edge(parent: 1, child: 3), edge(parent: 1, child: 2)]

        let filtered = MarkerLinkGeometry.plan(edges: edges, glyphs: glyphs, plotRect: plot, selectedId: id(1))
        let everything = edges.compactMap {
            MarkerLinkGeometry.route(edge: $0, glyphs: glyphs, obstacles: Array(glyphs.values))
        }
        #expect(filtered.routes.count == everything.count)
        for route in filtered.routes {
            let full = everything.first { $0.edge == route.edge }
            #expect(full?.start == route.start && full?.end == route.end
                    && full?.control == route.control && full?.control2 == route.control2)
        }
    }

    /// A connector must not slide under the like badge of the glyph it leaves.
    @Test
    func avoidsEndpointBadges() throws {
        let parentCenter = CGPoint(x: 200, y: 500)
        let childCenter = CGPoint(x: 200, y: 500 - stackSpacing * 2)
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, parentCenter, likes: true, responses: true),
            id(2): glyph(2, childCenter, likes: true, responses: true),
        ]

        // Badges at all four corners: the only way out is from under one of
        // the glyph's own. The owner would rather have that line than none —
        // the badge is painted over the line's emergence — so it must route.
        let route = try #require(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            )
        )

        // What is still forbidden: a badge under the line's *body*. Emergence
        // and arrival — within a glyph radius plus a badge of that endpoint —
        // are the only places a badge may sit over the line.
        let emergence = glyphRadius + 14
        for step in 0...48 {
            let point = route.point(at: CGFloat(step) / 48)
            let nearAnEndpoint = MarkerLinkGeometry.distance(point, parentCenter) <= emergence
                || MarkerLinkGeometry.distance(point, childCenter) <= emergence
            guard !nearAnEndpoint else { continue }
            for badge in glyphs.values.flatMap(\.badgeRects) {
                #expect(!badge.contains(point), "connector body ran under a badge at t=\(CGFloat(step) / 48)")
            }
        }
    }

    @Test
    func missingGlyphYieldsNoRoute() {
        let glyphs: [UUID: MarkerGlyphBounds] = [id(1): glyph(1, CGPoint(x: 200, y: 500))]
        #expect(
            MarkerLinkGeometry.route(
                edge: edge(parent: 1, child: 2),
                glyphs: glyphs,
                obstacles: Array(glyphs.values)
            ) == nil
        )
    }

    // MARK: - The viewport plays no part (production feedback: "lines jump sides while panning")

    /// A route is a function of the glyphs alone. Move every glyph by the
    /// same offset — which is what a pan does — and the route moves with
    /// them, whichever plot rect is handed in and wherever the plot edges
    /// fall relative to the pair. An earlier planner pulled off-plot ends to
    /// the edge and refused bows that left the plot, so the same two markers
    /// wore a different line at every pan position.
    @Test
    func aRouteMovesWithItsGlyphsAndNeverWithThePlot() throws {
        // A pair with a bystander the line must bend around, plus badges.
        let base: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 200, y: 400), likes: true, responses: true),
            id(2): glyph(2, CGPoint(x: 330, y: 250), likes: true),
            id(3): glyph(3, CGPoint(x: 262, y: 322)),
        ]
        let reference = try #require(MarkerLinkGeometry.plan(
            edges: [edge(parent: 1, child: 2)], glyphs: base, plotRect: plot, selectedId: id(1)
        ).routes.first)

        // Pans that put one or both ends off the plot, and the pair hard
        // against an edge where the old planner flipped the bow.
        let offsets = [CGPoint(x: -450, y: 0), CGPoint(x: 300, y: -500), CGPoint(x: -190, y: 0),
                       CGPoint(x: 120, y: 300), CGPoint(x: 2000, y: -3000)]
        for offset in offsets {
            var moved: [UUID: MarkerGlyphBounds] = [:]
            for (key, glyph) in base {
                moved[key] = MarkerGlyphBounds(
                    id: glyph.id,
                    center: CGPoint(x: glyph.center.x + offset.x, y: glyph.center.y + offset.y),
                    radius: glyph.radius,
                    badgeRects: glyph.badgeRects.map { $0.offsetBy(dx: offset.x, dy: offset.y) }
                )
            }
            let planned = MarkerLinkGeometry.plan(
                edges: [edge(parent: 1, child: 2)], glyphs: moved, plotRect: plot, selectedId: id(1)
            )
            let route = try #require(planned.routes.first, "pan \(offset): the line is still there")
            for step in 0...16 {
                let t = CGFloat(step) / 16
                let expected = reference.point(at: t)
                let actual = route.point(at: t)
                #expect(abs(actual.x - expected.x - offset.x) < 0.01 && abs(actual.y - expected.y - offset.y) < 0.01,
                        "pan \(offset): the route is the reference route, translated")
            }
        }
    }

    /// The same pair, the same plot, a different plot rect: identical route.
    @Test
    func thePlotRectDoesNotShapeARoute() throws {
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 20, y: 500)),
            id(2): glyph(2, CGPoint(x: 20, y: 500 - stackSpacing * 2)),
        ]
        let narrow = try #require(MarkerLinkGeometry.plan(
            edges: [edge(parent: 1, child: 2)], glyphs: glyphs, plotRect: plot, selectedId: id(1)
        ).routes.first)
        let wide = try #require(MarkerLinkGeometry.plan(
            edges: [edge(parent: 1, child: 2)], glyphs: glyphs,
            plotRect: CGRect(x: -1000, y: -1000, width: 3000, height: 3000), selectedId: id(1)
        ).routes.first)
        #expect(narrow == wide, "hard against the left edge or nowhere near one, the bow is the same")
    }

    /// An endpoint beyond the plot is routed to where it really is. The clip
    /// trims the line at the edge; what remains inside points at the marker.
    @Test
    func anEndpointBeyondThePlotIsRoutedToWhereItIs() throws {
        let inside = CGPoint(x: 200, y: 400)
        let farRight = CGPoint(x: 1400, y: 300)
        let glyphs: [UUID: MarkerGlyphBounds] = [id(1): glyph(1, inside), id(2): glyph(2, farRight)]
        let planned = MarkerLinkGeometry.plan(
            edges: [edge(parent: 1, child: 2)], glyphs: glyphs, plotRect: plot, selectedId: id(1)
        )
        let route = try #require(planned.routes.first)
        #expect(planned.omittedEdges.isEmpty)
        #expect(plot.contains(route.start))
        let endGap = MarkerLinkGeometry.distance(route.end, farRight)
        #expect(endGap >= glyphRadius && endGap < glyphRadius + 12,
                "ends at the far glyph's disc, a thousand points past the plot's edge")
        // Inside the plot the line heads for the real marker.
        let exit = try #require((0...256).map { route.point(at: CGFloat($0) / 256) }.first { $0.x >= plot.maxX })
        let expectedY = inside.y + (farRight.y - inside.y) * (plot.maxX - inside.x) / (farRight.x - inside.x)
        #expect(abs(exit.y - expectedY) < 40)
    }

    /// A cross-candle line that can clear nothing is drawn anyway, as its
    /// plainest arc, rather than omitted: it is painted behind the glyphs,
    /// and a line that depends on what is loaded around it is worse than one
    /// that passes under a stranger.
    @Test
    func aCrossCandleChordThatClearsNothingIsStillDrawn() throws {
        var glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 100, y: 500)),
            id(2): glyph(2, CGPoint(x: 300, y: 300)),
        ]
        // A wall of glyphs across the chord's whole neighbourhood.
        var n = 100
        for x in stride(from: 120, through: 280, by: 24) {
            for y in stride(from: 200, through: 600, by: 24) {
                glyphs[id(n)] = glyph(n, CGPoint(x: CGFloat(x), y: CGFloat(y)))
                n += 1
            }
        }
        let route = try #require(MarkerLinkGeometry.route(
            edge: edge(parent: 1, child: 2), glyphs: glyphs, obstacles: Array(glyphs.values)
        ))
        #expect(!MarkerLinkGeometry.isSafe(route: route, discObstacles: Array(glyphs.values).filter { $0.id != id(1) && $0.id != id(2) }, badgeObstacles: []),
                "the wall is genuinely impassable — this is the fallback, not a found path")
        #expect(route.control2 == nil, "the plain quadratic arc")
    }

    @Test
    func aRouteCapKeepsTheEdgesNearestTheViewportCentre() {
        // Five edges at increasing distance from the centre of the plot.
        var glyphs: [UUID: MarkerGlyphBounds] = [:]
        var edges: [MarkerLinkEdge] = []
        for n in 0..<5 {
            let x = CGFloat(200 + n * 40)
            glyphs[id(10 + n)] = glyph(10 + n, CGPoint(x: x, y: 400 - CGFloat(n) * 60))
            glyphs[id(20 + n)] = glyph(20 + n, CGPoint(x: x, y: 400 - CGFloat(n) * 60 - stackSpacing * 2))
            edges.append(edge(parent: 10 + n, child: 20 + n))
        }
        let planned = MarkerLinkGeometry.plan(
            edges: edges, glyphs: glyphs, plotRect: plot, selectedId: nil, maximumRoutes: 2
        )
        #expect(planned.routes.count == 2)
        #expect(planned.omittedEdges.count == 3)
        let kept = Set(planned.routes.map { $0.edge.parentId })
        #expect(kept == [id(10), id(11)], "the two nearest the plot centre survive the cap")
    }
}
