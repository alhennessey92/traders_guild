//
//  MarkerLinkGeometry.swift
//  traders_guild
//
//  Pure routing for linked-marker connectors.
//
//  Everything here consumes *final rendered* glyph positions — after the
//  selected-marker neighbour nudge and after selection scaling — because those
//  are the only coordinates that match what the user sees. Nothing in this file
//  recomputes a marker position from candle data.
//

import CoreGraphics
import Foundation

/// A rendered glyph as an obstacle: its disc plus any badges hanging off it.
struct MarkerGlyphBounds: Equatable {
    let id: UUID
    /// Final on-screen centre, post-nudge and post-scale.
    let center: CGPoint
    /// Final radius, already multiplied by any selection scale.
    let radius: CGFloat
    /// Absolute badge rectangles (like count, relationship/response count).
    let badgeRects: [CGRect]

    init(id: UUID, center: CGPoint, radius: CGFloat, badgeRects: [CGRect] = []) {
        self.id = id
        self.center = center
        self.radius = radius
        self.badgeRects = badgeRects
    }

    /// Whether a tap lands on this glyph's disc.
    ///
    /// The disc only — badges and connectors are decoration, not targets. A
    /// like badge sits 8pt to the right of the disc edge, so treating it as
    /// tappable would silently widen every glyph asymmetrically.
    ///
    /// `touchRadius` is the minimum comfortable target; a selected glyph drawn
    /// at 1.5x is already larger than that and keeps its own radius.
    func isHit(by point: CGPoint, touchRadius: CGFloat) -> Bool {
        let limit = max(radius, touchRadius)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return dx * dx + dy * dy <= limit * limit
    }

    func contains(_ point: CGPoint, clearance: CGFloat) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let limit = radius + clearance
        if dx * dx + dy * dy <= limit * limit { return true }
        return badgeRects.contains { $0.insetBy(dx: -clearance, dy: -clearance).contains(point) }
    }
}

/// A connector that survived routing and collision testing.
///
/// Quadratic by default — one control point, the shape every short connector
/// has always had. A cubic — two controls — is what the router falls back to
/// for a long same-column chord, where the parent sits in the stack above a
/// candle and the response in the stack below it: no single-apex arc can clear
/// the glyphs beside *both* endpoints, but a curve that steps sideways at once,
/// runs beside the column and steps back can.
struct MarkerLinkRoute: Equatable {
    let edge: MarkerLinkEdge
    /// On the parent glyph's edge.
    let start: CGPoint
    /// On the child glyph's edge.
    let end: CGPoint
    /// Bézier control point; for a cubic, the first of two.
    let control: CGPoint
    /// Second control point. Nil means the route is quadratic.
    let control2: CGPoint?
    let relationship: MarkerLinkRelationshipValue?

    init(
        edge: MarkerLinkEdge,
        start: CGPoint,
        end: CGPoint,
        control: CGPoint,
        control2: CGPoint? = nil,
        relationship: MarkerLinkRelationshipValue?
    ) {
        self.edge = edge
        self.start = start
        self.end = end
        self.control = control
        self.control2 = control2
        self.relationship = relationship
    }

    var isCubic: Bool { control2 != nil }

    func point(at t: CGFloat) -> CGPoint {
        if let control2 {
            return MarkerLinkGeometry.cubicPoint(
                start: start, control1: control, control2: control2, end: end, t: t
            )
        }
        return MarkerLinkGeometry.quadraticPoint(start: start, control: control, end: end, t: t)
    }
}

/// The outcome of routing one focus state's candidate edges.
struct MarkerLinkRoutePlan: Equatable {
    let routes: [MarkerLinkRoute]
    /// Edges deliberately not drawn — no safe path existed, or the cap was hit.
    let omittedEdges: [MarkerLinkEdge]

    static let empty = MarkerLinkRoutePlan(routes: [], omittedEdges: [])
}

enum MarkerLinkGeometry {
    /// Gap kept between a connector and any glyph or badge it passes.
    static let clearance: CGFloat = 3.0

    /// Lateral bow magnitudes tried in order. The smallest clears the 1.5pt grey
    /// stack spine; the larger ones clear a stacked glyph (radius 18) and its
    /// badges (which extend to 22pt from centre) sitting between the endpoints.
    ///
    /// The first rung is 22 rather than 14 because of what trimming does to a
    /// same-candle pair. Both ends lose a disc radius from a 40pt chord, so the
    /// drawn span is the *middle* of the arc — its flattest part. Measured on
    /// the real stack spacing, a 14pt bow leaves 13pt of span bowing 1.6pt:
    /// visually a straight diagonal. 22 leaves 21.7pt bowing 6.5pt, a sagitta
    /// ratio of 0.30, which reads as a round arc without approaching the
    /// semicircle a ratio of 0.5 would give. Escalation is unchanged: a rung
    /// that collides simply moves to the next.
    static let bowLadder: [CGFloat] = [22, 26, 34, 44]

    /// Cross-candle chords get a proportional bow instead of a fixed ladder.
    static let diagonalBowRatio: CGFloat = 0.12
    static let diagonalBowCap: CGFloat = 28

    /// A chord shorter than this cannot be drawn as a legible curve.
    static let minimumChordLength: CGFloat = 24

    /// The drawn span left after trimming to both glyph edges must be at least
    /// this long, otherwise the connector is a stub rather than a line.
    ///
    /// This — not a straight-line clearance test — is what decides whether two
    /// close glyphs can be joined. A selected marker is drawn at 1.5 scale
    /// (radius 27), so an adjacent stack neighbour 40pt away has overlapping
    /// discs on the chord while a curve bowed 26pt clear of the column still
    /// has plenty of visible span.
    static let minimumDrawnSpan: CGFloat = 10

    /// Samples used when testing a candidate path for collisions.
    static let collisionSamples = 28

    /// Below this horizontal separation two glyphs are treated as sharing a
    /// candle column, and get the fixed lateral bow ladder.
    static let sameCandleXTolerance: CGFloat = 1.5

    /// Same-column chords at least this long skip the quadratic ladder and go
    /// straight to the bracket curve. Below it a quadratic's apex is close
    /// enough to the endpoints to clear their neighbours; above it the arc is
    /// still hugging the column where the next stack slot sits, 40pt in.
    static let bracketChordThreshold: CGFloat = 120

    /// Lateral offsets tried for the cubic bracket, in order. The curve holds
    /// roughly this distance from the column along its middle half, so the
    /// first rung clears a stacked glyph (18) with its badges (to 22) and the
    /// 3pt clearance; the later rungs clear two glyphs side by side, or a
    /// selected glyph at 1.5x.
    static let bracketLadder: [CGFloat] = [28, 36, 46, 58, 72]

    /// Where along the chord the bracket's controls sit: this far in from each
    /// end. Smaller steps sideways sooner and holds the offset longer.
    static let bracketControlFraction: CGFloat = 0.22

    /// User-adjustable curvature multiplier bounds. 1 is the geometry as
    /// tuned; below it flattens every bow, above it rounds them. The bottom of
    /// the range still clears the stack spine at the ladder's first rung.
    static let curvatureRange: ClosedRange<CGFloat> = 0.6...1.6
    static let defaultCurvature: CGFloat = 1.0

    /// The widest lateral excursion any candidate can make, used to bound the
    /// obstacle search. Curvature is applied by the caller.
    static let maximumLateralExcursion: CGFloat = 72

    // MARK: - Entry point

    /// Route every candidate edge that can be drawn safely.
    ///
    /// There is no cap. A thesis is whatever the reader has loaded, and every
    /// edge between two rendered members is a fact worth a line; dropping the
    /// thirteenth because there were twelve is not a design, it is a budget
    /// wearing one. The budget lives elsewhere: each edge only tests the
    /// obstacles whose bounds its own bounding box can reach, so cost is
    /// edges × nearby glyphs, not edges × every glyph.
    ///
    /// Order is the selected marker's own edges first, then by distance from
    /// the selection, so the routes that matter most are drawn first and the
    /// reveal grows outward from the reader's tap.
    static func plan(
        edges: [MarkerLinkEdge],
        glyphs: [UUID: MarkerGlyphBounds],
        plotRect: CGRect,
        selectedId: UUID,
        curvature: CGFloat = defaultCurvature
    ) -> MarkerLinkRoutePlan {
        let selectedCenter = glyphs[selectedId]?.center
        let priority: (MarkerLinkEdgeKind) -> Int = { kind in
            switch kind {
            case .parentOfSelected: return 0
            case .childOfSelected: return 1
            case .withinThesis: return 2
            }
        }
        let ordered = edges.sorted { lhs, rhs in
            let lhsPriority = priority(lhs.kind)
            let rhsPriority = priority(rhs.kind)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            guard let origin = selectedCenter else {
                return lhs.childId.uuidString < rhs.childId.uuidString
            }
            let lhsDistance = min(
                glyphs[lhs.parentId].map { distance($0.center, origin) } ?? .greatestFiniteMagnitude,
                glyphs[lhs.childId].map { distance($0.center, origin) } ?? .greatestFiniteMagnitude
            )
            let rhsDistance = min(
                glyphs[rhs.parentId].map { distance($0.center, origin) } ?? .greatestFiniteMagnitude,
                glyphs[rhs.childId].map { distance($0.center, origin) } ?? .greatestFiniteMagnitude
            )
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            if lhs.parentId != rhs.parentId { return lhs.parentId.uuidString < rhs.parentId.uuidString }
            return lhs.childId.uuidString < rhs.childId.uuidString
        }

        let clampedCurvature = min(max(curvature, curvatureRange.lowerBound), curvatureRange.upperBound)
        let index = ObstacleIndex(glyphs: Array(glyphs.values))
        var routes: [MarkerLinkRoute] = []
        var omitted: [MarkerLinkEdge] = []

        for edge in ordered {
            guard let parent = glyphs[edge.parentId], let child = glyphs[edge.childId] else {
                omitted.append(edge)
                continue
            }
            let reach = maximumLateralExcursion * clampedCurvature + clearance
            let nearby = index.obstacles(near: parent.center, and: child.center, reach: reach)
            if let route = route(
                edge: edge,
                glyphs: glyphs,
                obstacles: nearby,
                plotRect: plotRect,
                curvature: clampedCurvature
            ) {
                routes.append(route)
            } else {
                omitted.append(edge)
            }
        }

        return MarkerLinkRoutePlan(routes: routes, omittedEdges: omitted)
    }

    /// Glyph bounds, queryable by the rectangle a candidate route can reach.
    ///
    /// A plain scan over precomputed boxes. Glyph counts on one chart are in
    /// the hundreds at most, so a grid would not pay for itself; what matters is
    /// that the per-edge collision sampling only sees glyphs it could touch.
    struct ObstacleIndex {
        private let entries: [(box: CGRect, glyph: MarkerGlyphBounds)]

        init(glyphs: [MarkerGlyphBounds]) {
            entries = glyphs.map { glyph in
                var box = CGRect(
                    x: glyph.center.x - glyph.radius,
                    y: glyph.center.y - glyph.radius,
                    width: glyph.radius * 2,
                    height: glyph.radius * 2
                )
                for badge in glyph.badgeRects { box = box.union(badge) }
                return (box, glyph)
            }
        }

        func obstacles(near a: CGPoint, and b: CGPoint, reach: CGFloat) -> [MarkerGlyphBounds] {
            let chord = CGRect(
                x: min(a.x, b.x), y: min(a.y, b.y),
                width: abs(a.x - b.x), height: abs(a.y - b.y)
            ).insetBy(dx: -reach, dy: -reach)
            return entries.filter { $0.box.intersects(chord) }.map(\.glyph)
        }
    }

    // MARK: - Single edge

    /// Attempt every allowed route for one edge, returning the first that is
    /// collision-free. Returns nil when no safe path exists — the contract's
    /// "omit unsafe paths" case.
    static func route(
        edge: MarkerLinkEdge,
        glyphs: [UUID: MarkerGlyphBounds],
        obstacles: [MarkerGlyphBounds],
        plotRect: CGRect,
        curvature: CGFloat = defaultCurvature
    ) -> MarkerLinkRoute? {
        guard let parent = glyphs[edge.parentId], let child = glyphs[edge.childId] else {
            return nil
        }

        let chord = distance(parent.center, child.center)
        guard chord >= minimumChordLength else { return nil }

        let isSameCandle = abs(parent.center.x - child.center.x) <= sameCandleXTolerance

        // Obstacles that matter: everything except the two endpoint discs.
        let endpointIds: Set<UUID> = [edge.parentId, edge.childId]
        let discObstacles = obstacles.filter { !endpointIds.contains($0.id) }
        let endpointBadges = obstacles
            .filter { endpointIds.contains($0.id) }
            .flatMap(\.badgeRects)
        let sides = preferredSides(parent: parent, child: child, plotRect: plotRect)

        // Two passes over the same candidates. First with the endpoints' own
        // badges as obstacles, which is prettier: the line prefers to leave on
        // the side without a badge. Then, only if nothing routed, without
        // them — because a thesis parent *always* wears the response badge at
        // its lower corner, and a response leaving it downward is otherwise
        // rejected at its very first sample for touching its own decoration.
        // That decoration is painted over the line's emergence in any case;
        // the rule was meant to keep a line's *body* from running under a
        // badge, and the middle of a route is still tested against every
        // other glyph's badges in both passes.
        let badgePasses: [[CGRect]] = endpointBadges.isEmpty ? [[]] : [endpointBadges, []]

        func accept(_ candidate: MarkerLinkRoute, badgeObstacles: [CGRect]) -> MarkerLinkRoute? {
            isSafe(
                route: candidate,
                discObstacles: discObstacles,
                badgeObstacles: badgeObstacles,
                plotRect: plotRect
            ) ? candidate : nil
        }

        // A long same-column chord — the parent stacked above a candle, the
        // response stacked below it — cannot be cleared by a single-apex arc:
        // near either endpoint the arc is still hugging the column where the
        // neighbouring stack slots sit. Go straight to the bracket.
        let useBracketFirst = isSameCandle && chord >= bracketChordThreshold

        for badgeObstacles in badgePasses {
            if !useBracketFirst {
                let magnitudes: [CGFloat] = isSameCandle
                    ? bowLadder.map { $0 * curvature }
                    : [min(chord * diagonalBowRatio, diagonalBowCap) * curvature]

                // Prefer bowing away from the like badge, which always sits on the right.
                for magnitude in magnitudes {
                    for side in sides {
                        let control = controlPoint(
                            parent: parent.center,
                            child: child.center,
                            magnitude: magnitude,
                            side: side
                        )
                        guard let trimmed = trim(
                            start: parent.center,
                            end: child.center,
                            control: control,
                            startRadius: parent.radius,
                            endRadius: child.radius
                        ) else { continue }

                        if let route = accept(MarkerLinkRoute(
                            edge: edge,
                            start: trimmed.start,
                            end: trimmed.end,
                            control: trimmed.control,
                            relationship: edge.relationship
                        ), badgeObstacles: badgeObstacles) {
                            return route
                        }
                    }
                }
            }

            // The bracket: step sideways at once, run beside the column, step back.
            // Tried for every same-column chord that the arc could not clear, and
            // first for the long ones. Cross-candle chords never need it — a
            // diagonal already leaves the column by construction.
            guard isSameCandle else { continue }
            for offset in bracketLadder.map({ $0 * curvature }) {
                for side in sides {
                    let controls = bracketControls(
                        parent: parent.center,
                        child: child.center,
                        offset: offset,
                        side: side
                    )
                    guard let trimmed = trimCubic(
                        start: parent.center,
                        end: child.center,
                        control1: controls.0,
                        control2: controls.1,
                        startRadius: parent.radius,
                        endRadius: child.radius
                    ) else { continue }

                    if let route = accept(MarkerLinkRoute(
                        edge: edge,
                        start: trimmed.start,
                        end: trimmed.end,
                        control: trimmed.control1,
                        control2: trimmed.control2,
                        relationship: edge.relationship
                    ), badgeObstacles: badgeObstacles) {
                        return route
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Routing primitives

    /// Which lateral side to try first. Left is preferred because the like badge
    /// is always on the right of a glyph; the plot edge overrides that.
    static func preferredSides(
        parent: MarkerGlyphBounds,
        child: MarkerGlyphBounds,
        plotRect: CGRect
    ) -> [CGFloat] {
        let midX = (parent.center.x + child.center.x) / 2
        let roomLeft = midX - plotRect.minX
        let roomRight = plotRect.maxX - midX
        // Only let the plot edge override when one side is genuinely tight.
        if roomLeft < maximumLateralExcursion && roomRight > roomLeft {
            return [1, -1]
        }
        return [-1, 1]
    }

    static func controlPoint(
        parent: CGPoint,
        child: CGPoint,
        magnitude: CGFloat,
        side: CGFloat
    ) -> CGPoint {
        let mid = CGPoint(x: (parent.x + child.x) / 2, y: (parent.y + child.y) / 2)
        let dx = child.x - parent.x
        let dy = child.y - parent.y
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        // Perpendicular unit vector.
        let px = -dy / length
        let py = dx / length
        // A quadratic curve's apex sits at half the control offset, so double it
        // to make `magnitude` the actual lateral clearance at the midpoint.
        let scaled = magnitude * 2
        return CGPoint(x: mid.x + px * scaled * side, y: mid.y + py * scaled * side)
    }

    /// The control point of the sub-curve of a quadratic between `t0` and `t1`.
    ///
    /// De Casteljau, and the reason this exists: moving the two endpoints onto
    /// the curve and *keeping the original control point* does not shorten the
    /// curve, it replaces it with a different one. The control stays where it
    /// was while the chord collapses, so what gets drawn is a far tighter arc
    /// than the one that was routed — on a selected same-candle pair, a 19.6pt
    /// span bulging 14.5pt sideways, which is a hairpin, not a connector.
    static func subCurveControl(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint,
        t0: CGFloat,
        t1: CGFloat
    ) -> CGPoint {
        let a = lerp(start, control, t0)
        let b = lerp(control, end, t0)
        return lerp(a, b, t1)
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Two control points for the bracket: each `bracketControlFraction` of
    /// the way in from its end, offset laterally by `offset` on `side`.
    ///
    /// A cubic with both controls displaced the same way to the same side
    /// leaves its endpoints tangentially *toward* the offset, holds close to it
    /// through the middle, and returns — a "D" beside the column rather than a
    /// bulge in the middle of it. The lateral distance actually held through
    /// the middle half is about ¾ of `offset` for these fractions, which the
    /// ladder's rungs are sized for.
    static func bracketControls(
        parent: CGPoint,
        child: CGPoint,
        offset: CGFloat,
        side: CGFloat
    ) -> (CGPoint, CGPoint) {
        let dx = child.x - parent.x
        let dy = child.y - parent.y
        let length = max(sqrt(dx * dx + dy * dy), 0.0001)
        let px = -dy / length
        let py = dx / length
        // Cubic controls pull the curve to about ¾ of their offset at its
        // widest, so scale up to make `offset` the held clearance.
        let scaled = offset * 4 / 3
        let along = bracketControlFraction
        let c1 = CGPoint(
            x: parent.x + dx * along + px * scaled * side,
            y: parent.y + dy * along + py * scaled * side
        )
        let c2 = CGPoint(
            x: parent.x + dx * (1 - along) + px * scaled * side,
            y: parent.y + dy * (1 - along) + py * scaled * side
        )
        return (c1, c2)
    }

    static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let inv = 1 - t
        let a = inv * inv * inv
        let b = 3 * inv * inv * t
        let c = 3 * inv * t * t
        let d = t * t * t
        return CGPoint(
            x: a * start.x + b * control1.x + c * control2.x + d * end.x,
            y: a * start.y + b * control1.y + c * control2.y + d * end.y
        )
    }

    /// The sub-curve of a cubic between `t0` and `t1`: de Casteljau, split at
    /// `t0` and then the right-hand piece split at the rescaled `t1`.
    static func subCubic(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t0: CGFloat,
        t1: CGFloat
    ) -> (start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        // Split at t0, keep the right piece.
        let a1 = lerp(start, control1, t0), b1 = lerp(control1, control2, t0), c1 = lerp(control2, end, t0)
        let a2 = lerp(a1, b1, t0), b2 = lerp(b1, c1, t0)
        let p = lerp(a2, b2, t0)
        let rStart = p, rC1 = b2, rC2 = c1, rEnd = end
        // Split the right piece at the rescaled t1, keep the left piece.
        let u = t0 >= 1 ? 0 : (t1 - t0) / (1 - t0)
        let d1 = lerp(rStart, rC1, u), e1 = lerp(rC1, rC2, u), f1 = lerp(rC2, rEnd, u)
        let d2 = lerp(d1, e1, u), e2 = lerp(e1, f1, u)
        let q = lerp(d2, e2, u)
        return (rStart, d1, d2, q)
    }

    static func quadraticPoint(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let inv = 1 - t
        let a = inv * inv
        let b = 2 * inv * t
        let c = t * t
        return CGPoint(
            x: a * start.x + b * control.x + c * end.x,
            y: a * start.y + b * control.y + c * end.y
        )
    }

    /// Walk the curve inward from both ends until it clears each glyph's edge,
    /// so the connector touches the glass rather than crossing the glyph.
    ///
    /// Returns the *sub-curve*, control point included. Trimming a Bézier means
    /// taking the piece of it between two parameters, not keeping the original
    /// control and hoping — see `subCurveControl`.
    static func trim(
        start: CGPoint,
        end: CGPoint,
        control: CGPoint,
        startRadius: CGFloat,
        endRadius: CGFloat
    ) -> (start: CGPoint, end: CGPoint, control: CGPoint)? {
        let steps = 96
        var tStart: CGFloat?
        var tEnd: CGFloat?

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = quadraticPoint(start: start, control: control, end: end, t: t)
            if distance(point, start) >= startRadius {
                tStart = t
                break
            }
        }
        for step in 0...steps {
            let t = 1 - CGFloat(step) / CGFloat(steps)
            let point = quadraticPoint(start: start, control: control, end: end, t: t)
            if distance(point, end) >= endRadius {
                tEnd = t
                break
            }
        }

        guard let tS = tStart, let tE = tEnd, tE > tS else { return nil }
        let trimmedStart = quadraticPoint(start: start, control: control, end: end, t: tS)
        let trimmedEnd = quadraticPoint(start: start, control: control, end: end, t: tE)
        // Reject a stub: two glyphs can overlap on the chord and still leave a
        // usable span once the path bows clear, but not always.
        guard distance(trimmedStart, trimmedEnd) >= minimumDrawnSpan else { return nil }
        return (
            trimmedStart,
            trimmedEnd,
            subCurveControl(start: start, control: control, end: end, t0: tS, t1: tE)
        )
    }

    /// The cubic counterpart of `trim`: walk in from both ends until the curve
    /// clears each glyph, and return the true sub-curve.
    static func trimCubic(
        start: CGPoint,
        end: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        startRadius: CGFloat,
        endRadius: CGFloat
    ) -> (start: CGPoint, end: CGPoint, control1: CGPoint, control2: CGPoint)? {
        let steps = 96
        var tStart: CGFloat?
        var tEnd: CGFloat?

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = cubicPoint(start: start, control1: control1, control2: control2, end: end, t: t)
            if distance(point, start) >= startRadius {
                tStart = t
                break
            }
        }
        for step in 0...steps {
            let t = 1 - CGFloat(step) / CGFloat(steps)
            let point = cubicPoint(start: start, control1: control1, control2: control2, end: end, t: t)
            if distance(point, end) >= endRadius {
                tEnd = t
                break
            }
        }

        guard let tS = tStart, let tE = tEnd, tE > tS else { return nil }
        let piece = subCubic(
            start: start, control1: control1, control2: control2, end: end, t0: tS, t1: tE
        )
        guard distance(piece.start, piece.end) >= minimumDrawnSpan else { return nil }
        return (piece.start, piece.end, piece.control1, piece.control2)
    }

    /// Sample the drawn span and reject any path that grazes another glyph, a
    /// badge, or leaves the plot.
    static func isSafe(
        route: MarkerLinkRoute,
        discObstacles: [MarkerGlyphBounds],
        badgeObstacles: [CGRect],
        plotRect: CGRect
    ) -> Bool {
        for step in 0...collisionSamples {
            let t = CGFloat(step) / CGFloat(collisionSamples)
            let point = route.point(at: t)

            if !plotRect.contains(point) { return false }

            for obstacle in discObstacles where obstacle.contains(point, clearance: clearance) {
                return false
            }
            for badge in badgeObstacles
            where badge.insetBy(dx: -clearance, dy: -clearance).contains(point) {
                return false
            }
        }
        return true
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// Layout the renderer and hit testing must agree on.
///
/// Both need the same answer to "where did that glyph actually land, and which
/// one is on top". Writing it twice is how a tap starts selecting the marker
/// beside the one under the finger, so it is written once here and called from
/// both.
enum MarkerStackLayout {

    /// How far a selected glyph pushes its immediate stack neighbours.
    static let selectionNudge: CGFloat = 10

    /// Move the selected glyph's immediate neighbours clear of it.
    ///
    /// A selected marker is drawn at 1.5x and would otherwise overlap the
    /// glyphs directly above and below it in the same stack. Only `stackIndex`
    /// ±1 on the same side move, and only while the selection is actually
    /// scaled up.
    static func applySelectionNudge(
        to positions: inout [(marker: ChartMarkerUI, position: CGPoint)],
        selectedMarkerId: UUID?,
        selectedMarkerScale: CGFloat
    ) {
        guard let selectedMarkerId,
              selectedMarkerScale > 1.0,
              let selectedIndex = positions.firstIndex(where: { $0.marker.id == selectedMarkerId })
        else { return }

        let selected = positions[selectedIndex]
        let direction: CGFloat = selected.marker.positionedBelow ? 1.0 : -1.0

        for index in positions.indices where index != selectedIndex {
            let other = positions[index]
            guard other.marker.positionedBelow == selected.marker.positionedBelow else { continue }
            if other.marker.stackIndex == selected.marker.stackIndex - 1 {
                positions[index].position.y -= direction * selectionNudge
            } else if other.marker.stackIndex == selected.marker.stackIndex + 1 {
                positions[index].position.y += direction * selectionNudge
            }
        }
    }

    /// Paint priority, lowest first: unrelated, then focused thesis members,
    /// then the selected glyph on top.
    ///
    /// The renderer draws in this order and a tap resolves against its reverse,
    /// so what looks topmost is what a tap selects.
    static func paintPriority(
        markerId: UUID,
        isSelected: Bool,
        focusMemberIds: Set<UUID>
    ) -> Int {
        if isSelected { return 2 }
        return focusMemberIds.contains(markerId) ? 1 : 0
    }
}
