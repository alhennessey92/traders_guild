import Foundation
import CoreGraphics

/// A linked marker that lives on another timeframe of the same chart.
///
/// Connectors only join glyphs that are on this chart. A parent or a response
/// on a different interval has nothing here to attach to, so the selected
/// glyph wears a small round badge for it instead: the target's timeframe in
/// the middle, a circular arrow around it. Tap it to travel there; the marker
/// you land on wears the badge back, so a thesis that spans intervals can be
/// walked in both directions without opening the sheet.
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
    /// Responses on other timeframes beyond the one this badge names. The
    /// badge points at one target; the thesis sheet lists them all.
    let others: Int
    let preview: RLMarkerLinkPreviewDTO

    var id: UUID { markerId }
}

enum MarkerTimeframeJumpResolver {
    /// Parent first, then the most recent response elsewhere.
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
                        preview: child
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
    /// Disc plus arrow plus a finger's worth of slack.
    static let hitRadius: CGFloat = 18
    /// Gap between the glyph's (scaled) edge and the badge centre — enough
    /// for the arrow ring to clear the glyph's own ring.
    static let standoff: CGFloat = 22
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
    }

    /// Level with the glyph: a parent jump to its right, a response jump to
    /// its left. The like and response-count badges sit on the candle-facing
    /// side below the centre line, the stack spine runs on that side too, and
    /// the info card floats above — the horizontal axis is the one lane that
    /// stays clear on both sides of the candle. `isBelow` is accepted so the
    /// hit-test and the draw pass share one signature; it does not change
    /// the placement today.
    static func placements(
        selectedCenter center: CGPoint,
        scaledRadius: CGFloat,
        isBelow: Bool,
        jumps: [MarkerTimeframeJump]
    ) -> [Placement] {
        _ = isBelow
        let distance = scaledRadius + standoff
        return jumps.map { jump in
            let dx: CGFloat = jump.direction == .toParent ? distance : -distance
            return Placement(jump: jump, center: CGPoint(x: center.x + dx, y: center.y))
        }
    }

    static func placement(
        at location: CGPoint,
        in placements: [Placement]
    ) -> Placement? {
        placements.first { hypot(location.x - $0.center.x, location.y - $0.center.y) <= hitRadius }
    }
}
