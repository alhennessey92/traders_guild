import Foundation
import CoreGraphics

/// A linked marker that lives on another timeframe of the same chart.
///
/// Connectors only join glyphs that are on this chart. A parent or a response
/// on a different interval has nothing here to attach to, so the selected
/// glyph wears a small round badge for it instead: the target's timeframe in
/// the middle, a circular arrow around it. Tap it to travel there; the marker
/// you land on wears the badge back, so a thesis that spans intervals can be
/// walked in both directions. Multiple response destinations open the thesis list.
struct MarkerTimeframeJump: Equatable, Identifiable {
    enum Direction: Equatable {
        /// Up to the marker this one answers.
        case toParent
        /// Down to a marker that answers this one.
        case toResponse
    }

    let markerId: UUID
    let direction: Direction
    /// The relationship the badge is coloured with: the selected marker's own
    /// for a parent jump, the response's for a response jump — the same colour
    /// a connector between the two would have had.
    let relationship: MarkerLinkRelationshipValue
    let timeframe: RLChartTimeframe
    /// Additional loaded response destinations. Multiple destinations use
    /// an ellipsis badge and the thesis list instead of an arbitrary jump.
    let others: Int
    let preview: RLMarkerLinkPreviewDTO
    /// Ambiguous or incomplete response branches open the existing thesis list.
    var requiresChoice: Bool = false

    var badgeText: String { requiresChoice ? "…" : timeframe.shortName }

    var id: UUID { markerId }
}

enum MarkerTimeframeJumpResolver {
    /// Parent first, then one response shortcut. Multiple destinations open a list.
    ///
    /// The parent comes from the marker's own preview and needs no request.
    /// Responses live in the thesis window; until it has loaded there is no
    /// badge for them, because a badge that cannot say where it goes is worse
    /// than none. Anything the navigation target initialiser would refuse — a
    /// tombstone, an unhydrated preview — is left out for the same reason.
    static func jumps(
        for marker: ChartMarkerUI,
        currentTimeframe: RLChartTimeframe,
        thread: MarkerThreadWindow?
    ) -> [MarkerTimeframeJump] {
        var jumps: [MarkerTimeframeJump] = []

        if let parent = marker.parentPreview,
           let target = elsewhere(parent, currentTimeframe: currentTimeframe) {
            jumps.append(
                MarkerTimeframeJump(
                    markerId: target.markerId,
                    direction: .toParent,
                    relationship: marker.linkRelationship ?? MarkerLinkRelationshipValue(raw: ""),
                    timeframe: target.timeframe,
                    others: 0,
                    preview: parent
                )
            )
        }

        if let thread,
           let node = thread.nodes.first(where: { $0.markerId == marker.id }) {
            let responses = (thread.childKeysByParent[node.nodeKey] ?? [])
                .compactMap { thread.nodesByKey[$0] }
                .compactMap { child -> (RLMarkerLinkPreviewDTO, (markerId: UUID, timeframe: RLChartTimeframe))? in
                    guard let target = elsewhere(child, currentTimeframe: currentTimeframe) else { return nil }
                    return (child, target)
                }
                .sorted { ($0.0.createdAt ?? .distantPast) > ($1.0.createdAt ?? .distantPast) }
            if let first = responses.first {
                let (child, target) = first
                jumps.append(
                    MarkerTimeframeJump(
                        markerId: target.markerId,
                        direction: .toResponse,
                        relationship: child.linkRelationship.map(MarkerLinkRelationshipValue.init(raw:))
                            ?? MarkerLinkRelationshipValue(raw: ""),
                        timeframe: target.timeframe,
                        others: responses.count - 1,
                        preview: child,
                        requiresChoice: responses.count > 1 || thread.branchCursors[node.nodeKey] != nil
                    )
                )
            } else if thread.branchCursors[node.nodeKey] != nil {
                // Responses exist that this window has not paged in, and none
                // of the loaded ones is elsewhere. The badge cannot say where
                // it goes, so it says "more": the ellipsis opens the thesis
                // list, which loads the branch. Without this a marker whose
                // count badge showed responses wore no badge at all.
                jumps.append(
                    MarkerTimeframeJump(
                        markerId: marker.id,
                        direction: .toResponse,
                        relationship: MarkerLinkRelationshipValue(raw: ""),
                        timeframe: currentTimeframe,
                        others: 0,
                        preview: node,
                        requiresChoice: true
                    )
                )
            }
        }

        return jumps
    }

    /// The preview's id and timeframe, only if it is navigable and not on the
    /// timeframe being looked at.
    private static func elsewhere(
        _ preview: RLMarkerLinkPreviewDTO,
        currentTimeframe: RLChartTimeframe
    ) -> (markerId: UUID, timeframe: RLChartTimeframe)? {
        guard let markerId = preview.markerId,
              let raw = preview.timeframe,
              let timeframe = RLChartTimeframe.fromBackendString(raw),
              timeframe != currentTimeframe,
              MarkerNavigationTarget(linkPreview: preview) != nil else { return nil }
        return (markerId, timeframe)
    }
}

/// Where the badges sit relative to the selected glyph, shared by the draw
/// pass and the tap hit-test so a tap lands on what was painted.
enum MarkerTimeframeJumpLayout {
    /// Filled disc.
    static let badgeRadius: CGFloat = 11
    /// The circular arrow runs just outside the disc.
    static let arrowRadius: CGFloat = 14.5
    /// Arrow ring plus its halo — the footprint used for clipping and avoidance.
    static let outerRadius: CGFloat = 16
    /// Disc plus arrow plus a finger's worth of slack.
    static let hitRadius: CGFloat = 18
    /// Glyph centre to badge centre, beyond the glyph's scaled radius. Long
    /// enough that a tether is visible between glyph ring and arrow ring.
    static let standoff: CGFloat = 36
    /// How far the badges splay off the outward vertical: 45° keeps them out
    /// of the stack column (neighbours sit straight above or below the
    /// selected glyph) while still reading as "away from the candle".
    static let splayAngle: CGFloat = .pi / 4
    /// How far a badge may slide sideways, from its preferred spot, to get
    /// past a stack neighbour or a badge already placed — enough to clear one
    /// badge's full width and a little more.
    static let maximumAvoidanceShift: CGFloat = 44
    /// Gap between the glyph's ring / the arrow ring and the tether's ends.
    static let tetherInset: CGFloat = 1.5
    /// The scale a selected glyph settles at (`selectionScale` in the chart);
    /// the badges are fully revealed once the pop reaches it.
    static let selectedGlyphScale: CGFloat = 1.5

    /// 0 while the glyph is at rest, 1 once it has popped to selected size.
    static func reveal(selectedMarkerScale: CGFloat) -> CGFloat {
        max(0, min(1, (selectedMarkerScale - 1) / (selectedGlyphScale - 1)))
    }

    struct Placement: Equatable {
        let jump: MarkerTimeframeJump
        let center: CGPoint
        /// The dotted tether: leaves the glyph's ring, meets the arrow ring.
        let tetherStart: CGPoint
        let tetherEnd: CGPoint
    }

    /// Outward, away from the candle: above a glyph that sits above its candle,
    /// below one that sits below. Each badge splays 45° off that vertical — a
    /// parent jump to the right, a response jump to the left — so neither
    /// lands on the stack neighbour directly outward of the selected glyph,
    /// and a thin dotted tether ties each one back to the glyph it belongs
    /// to. The like and count badges live on the candle side, so nothing
    /// competes for this lane.
    ///
    /// When the preferred spot is taken, the search runs in this order and
    /// stops at the first free one: slide outward on the same side; take the
    /// other side of the outward band (sliding past a badge already there);
    /// and only then the candle side. The tether makes attribution clear
    /// wherever a badge ends up, so keeping it *outward* matters more than
    /// keeping parent-right / response-left.
    ///
    /// **A badge is placed relative to its glyph and nothing else.** An
    /// earlier layout slid a badge back inside the plot and out from under
    /// the info card, which meant the badge crept along the screen edge as
    /// the chart was panned and jumped as the card passed over it; the
    /// owner's verdict was that it must move only with its marker. So a badge
    /// near the edge leaves with the glyph and comes back with it, and one
    /// under the card is hidden with the glyph it belongs to.
    ///
    /// - Parameter obstacles: the discs of the selected glyph's own stack
    ///   neighbours — the same column, so fixed relative to the glyph at any
    ///   zoom. A badge never sits on one of those; glyphs on other candles
    ///   are not avoided, because their distance changes with zoom and a
    ///   badge that hops between spots as the chart is pinched is worse than
    ///   one that overlaps a neighbour on its tether.
    static func placements(
        selectedCenter center: CGPoint,
        scaledRadius: CGFloat,
        isBelow: Bool,
        jumps: [MarkerTimeframeJump],
        obstacles: [CGRect] = []
    ) -> [Placement] {
        let distance = scaledRadius + standoff
        let along = distance * cos(splayAngle)
        let across = distance * sin(splayAngle)
        let outwardSign: CGFloat = isBelow ? 1 : -1
        var taken: [CGRect] = obstacles

        return jumps.map { jump in
            let ownSide: CGFloat = jump.direction == .toParent ? 1 : -1
            let preferred = CGPoint(x: center.x + ownSide * across, y: center.y + outwardSign * along)

            var chosen: CGPoint?
            search: for verticalSign in [outwardSign, -outwardSign] {
                let y = center.y + verticalSign * along
                for sideSign in [ownSide, -ownSide] {
                    var shift: CGFloat = 0
                    while shift <= maximumAvoidanceShift {
                        let point = CGPoint(x: center.x + sideSign * (across + shift), y: y)
                        let box = footprint(point)
                        // Badges placed so far and the stack neighbours.
                        if !taken.contains(where: { box.intersects($0) }) {
                            chosen = point
                            break search
                        }
                        shift += 4
                    }
                }
            }

            let final = chosen ?? preferred
            taken.append(footprint(final))

            let dx = final.x - center.x
            let dy = final.y - center.y
            let length = max(1, hypot(dx, dy))
            let unit = CGPoint(x: dx / length, y: dy / length)
            let startDistance = scaledRadius + tetherInset
            let endDistance = arrowRadius + tetherInset
            return Placement(
                jump: jump,
                center: final,
                tetherStart: CGPoint(x: center.x + unit.x * startDistance, y: center.y + unit.y * startDistance),
                tetherEnd: CGPoint(x: final.x - unit.x * endDistance, y: final.y - unit.y * endDistance)
            )
        }
    }

    static func footprint(_ center: CGPoint) -> CGRect {
        CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)
    }

    static func placement(
        at location: CGPoint,
        in placements: [Placement]
    ) -> Placement? {
        placements.first { hypot(location.x - $0.center.x, location.y - $0.center.y) <= hitRadius }
    }
}
