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
struct MarkerLinkRoute: Equatable {
    let edge: MarkerLinkEdge
    /// On the parent glyph's edge.
    let start: CGPoint
    /// On the child glyph's edge.
    let end: CGPoint
    /// Quadratic Bézier control point.
    let control: CGPoint
    let relationship: MarkerLinkRelationshipValue?

    func point(at t: CGFloat) -> CGPoint {
        MarkerLinkGeometry.quadraticPoint(start: start, control: control, end: end, t: t)
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

    // MARK: - Entry point

    /// Route as many candidate edges as can be drawn safely.
    ///
    /// Priority is the contract's: the parent edge first, then children nearest
    /// to the selected marker, capped at `maxEdges` *actually drawn* edges.
    static func plan(
        edges: [MarkerLinkEdge],
        glyphs: [UUID: MarkerGlyphBounds],
        plotRect: CGRect,
        selectedId: UUID,
        maxEdges: Int = MarkerLinkGraph.maximumEdges
    ) -> MarkerLinkRoutePlan {
        guard maxEdges > 0 else {
            return MarkerLinkRoutePlan(routes: [], omittedEdges: edges)
        }

        let selectedCenter = glyphs[selectedId]?.center
        let ordered = edges.sorted { lhs, rhs in
            if (lhs.kind == .parentOfSelected) != (rhs.kind == .parentOfSelected) {
                return lhs.kind == .parentOfSelected
            }
            guard let origin = selectedCenter else {
                return lhs.childId.uuidString < rhs.childId.uuidString
            }
            let lhsOther = lhs.parentId == selectedId ? lhs.childId : lhs.parentId
            let rhsOther = rhs.parentId == selectedId ? rhs.childId : rhs.parentId
            let lhsDistance = glyphs[lhsOther].map { distance($0.center, origin) } ?? .greatestFiniteMagnitude
            let rhsDistance = glyphs[rhsOther].map { distance($0.center, origin) } ?? .greatestFiniteMagnitude
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return lhs.childId.uuidString < rhs.childId.uuidString
        }

        let obstacles = Array(glyphs.values)
        var routes: [MarkerLinkRoute] = []
        var omitted: [MarkerLinkEdge] = []

        for edge in ordered {
            guard routes.count < maxEdges else {
                omitted.append(edge)
                continue
            }
            if let route = route(
                edge: edge,
                glyphs: glyphs,
                obstacles: obstacles,
                plotRect: plotRect
            ) {
                routes.append(route)
            } else {
                omitted.append(edge)
            }
        }

        return MarkerLinkRoutePlan(routes: routes, omittedEdges: omitted)
    }

    // MARK: - Single edge

    /// Attempt every allowed route for one edge, returning the first that is
    /// collision-free. Returns nil when no safe path exists — the contract's
    /// "omit unsafe paths" case.
    static func route(
        edge: MarkerLinkEdge,
        glyphs: [UUID: MarkerGlyphBounds],
        obstacles: [MarkerGlyphBounds],
        plotRect: CGRect
    ) -> MarkerLinkRoute? {
        guard let parent = glyphs[edge.parentId], let child = glyphs[edge.childId] else {
            return nil
        }

        let chord = distance(parent.center, child.center)
        guard chord >= minimumChordLength else { return nil }

        let isSameCandle = abs(parent.center.x - child.center.x) <= sameCandleXTolerance
        let magnitudes: [CGFloat] = isSameCandle
            ? bowLadder
            : [min(chord * diagonalBowRatio, diagonalBowCap)]

        // Obstacles that matter: everything except the two endpoint discs. The
        // endpoints' *badges* still count — a connector must not run under the
        // like badge of the marker it starts from.
        let endpointIds: Set<UUID> = [edge.parentId, edge.childId]
        let discObstacles = obstacles.filter { !endpointIds.contains($0.id) }
        let badgeObstacles = obstacles
            .filter { endpointIds.contains($0.id) }
            .flatMap(\.badgeRects)

        // Prefer bowing away from the like badge, which always sits on the right.
        for magnitude in magnitudes {
            for side in preferredSides(parent: parent, child: child, plotRect: plotRect) {
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

                let candidate = MarkerLinkRoute(
                    edge: edge,
                    start: trimmed.start,
                    end: trimmed.end,
                    control: trimmed.control,
                    relationship: edge.relationship
                )

                if isSafe(
                    route: candidate,
                    discObstacles: discObstacles,
                    badgeObstacles: badgeObstacles,
                    plotRect: plotRect
                ) {
                    return candidate
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
        if roomLeft < bowLadder[bowLadder.count - 1] && roomRight > roomLeft {
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
