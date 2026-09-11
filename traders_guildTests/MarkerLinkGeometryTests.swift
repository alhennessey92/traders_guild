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
                obstacles: Array(glyphs.values),
                plotRect: plot
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
                    obstacles: Array(glyphs.values),
                    plotRect: plot
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
                obstacles: Array(glyphs.values),
                plotRect: plot
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
                obstacles: Array(glyphs.values),
                plotRect: plot
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
        // Wall off every lateral escape the bow ladder could use.
        for (index, dx) in [-14, -26, -34, -44, 14, 26, 34, 44].enumerated() {
            glyphs[id(100 + index)] = glyph(100 + index, CGPoint(x: 200 + CGFloat(dx), y: midY))
        }

        let route = MarkerLinkGeometry.route(
            edge: edge(parent: 1, child: 3),
            glyphs: glyphs,
            obstacles: Array(glyphs.values),
            plotRect: plot
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
                obstacles: Array(glyphs.values),
                plotRect: plot
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
                obstacles: Array(glyphs.values),
                plotRect: plot
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
                obstacles: Array(glyphs.values),
                plotRect: plot
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
                    obstacles: Array(glyphs.values),
                    plotRect: plot
                )
            )
        }

        let before = try route(childCenter: childBefore)
        let after = try route(childCenter: childAfter)

        #expect(before.end != after.end, "endpoints must track the nudged position")
        // The trimmed end stays on the *nudged* glyph's edge.
        #expect(abs(MarkerLinkGeometry.distance(after.end, childAfter) - glyphRadius) < 6)
    }

    // MARK: - Prioritisation and the cap

    @Test
    func drawsParentFirstThenNearestChildrenUpToTheCap() {
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
        // 20 children spread across distinct candles, increasing distance.
        for index in 0..<20 {
            let n = 10 + index
            glyphs[id(n)] = glyph(n, CGPoint(x: 200 + CGFloat(index + 1) * 9, y: 300))
            edges.append(edge(parent: 1, child: n))
        }

        let planned = MarkerLinkGeometry.plan(
            edges: edges,
            glyphs: glyphs,
            plotRect: plot,
            selectedId: id(1)
        )

        #expect(planned.routes.count <= MarkerLinkGraph.maximumEdges)
        #expect(planned.routes.first?.edge.kind == .parentOfSelected,
                "the parent edge is drawn first regardless of distance")
        #expect(!planned.omittedEdges.isEmpty, "edges beyond the cap are reported, not dropped silently")
        #expect(planned.routes.count + planned.omittedEdges.count == edges.count)
    }

    @Test
    func staysWithinThePlotRect() {
        // Parent hard against the left edge, so a left bow would leave the plot.
        let glyphs: [UUID: MarkerGlyphBounds] = [
            id(1): glyph(1, CGPoint(x: 20, y: 500)),
            id(2): glyph(2, CGPoint(x: 20, y: 500 - stackSpacing * 2)),
        ]
        let planned = MarkerLinkGeometry.plan(
            edges: [edge(parent: 1, child: 2)],
            glyphs: glyphs,
            plotRect: plot,
            selectedId: id(1)
        )
        for route in planned.routes {
            for step in 0...32 {
                #expect(plot.contains(route.point(at: CGFloat(step) / 32)))
            }
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

        guard let route = MarkerLinkGeometry.route(
            edge: edge(parent: 1, child: 2),
            glyphs: glyphs,
            obstacles: Array(glyphs.values),
            plotRect: plot
        ) else { return }  // omitting is an acceptable outcome here

        let allBadges = glyphs.values.flatMap(\.badgeRects)
        for step in 0...48 {
            let point = route.point(at: CGFloat(step) / 48)
            for badge in allBadges {
                #expect(!badge.contains(point), "connector crossed a badge")
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
                obstacles: Array(glyphs.values),
                plotRect: plot
            ) == nil
        )
    }
}
