//
//  MarkerLinkRenderer.swift
//  traders_guild
//
//  Canvas drawing for linked markers: relationship rings, the response-count
//  badge, and the connectors themselves.
//
//  Everything here is drawn from final rendered positions supplied by
//  `ChartMarkerSystem.drawMarkers`, after the selected-marker neighbour nudge.
//  Nothing recomputes geometry.
//

import SwiftUI

/// Everything the marker layer needs to draw one focus state.
///
/// Assembled once per frame by the chart from `MarkerManager`, so the renderer
/// stays a pure function of what it is handed.
struct MarkerLinkRenderContext {
    let focus: MarkerFocusState
    /// Ring treatment per marker, for members of the focused thesis only.
    let ringStyles: [UUID: MarkerLinkRingStyle]
    /// 0…1 stroke reveal. Callers pass 1 immediately under Reduce Motion.
    let revealProgress: CGFloat
    /// The plot rectangle connectors must stay inside.
    let plotRect: CGRect

    init(
        focus: MarkerFocusState,
        ringStyles: [UUID: MarkerLinkRingStyle],
        revealProgress: CGFloat,
        plotRect: CGRect
    ) {
        self.focus = focus
        self.ringStyles = ringStyles
        self.revealProgress = revealProgress
        self.plotRect = plotRect
    }

    func isDimmed(_ markerId: UUID) -> Bool {
        focus.shouldFadeUnrelated && !focus.memberIds.contains(markerId)
    }
}

/// How the connector/ring reveal behaves, extracted so Reduce Motion is a
/// tested rule rather than an inspected one.
enum MarkerLinkRevealPolicy {
    /// Faster out than in, matching the chart's existing selection feel.
    static let inDuration: Double = 0.22
    static let outDuration: Double = 0.14

    /// Where the reveal should end up.
    static func target(focused: Bool) -> CGFloat {
        focused ? 1 : 0
    }

    /// How long to take getting there. Zero means "no animation" — under
    /// Reduce Motion focus still appears, it simply does not draw itself in.
    static func duration(focused: Bool, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        return focused ? inDuration : outDuration
    }

    /// Whether the reveal should restart from zero before animating. Only the
    /// inward direction does, so the line draws from the parent outward.
    static func restartsFromZero(focused: Bool, reduceMotion: Bool) -> Bool {
        focused && !reduceMotion
    }
}

enum MarkerLinkRenderer {

    // MARK: - Constants

    /// Ring weight. The resting glyph stroke is 0.8pt, so this reads as a
    /// deliberate addition rather than a thicker border.
    static let ringWidth: CGFloat = 1.5

    /// Drawn just *inside* the glass edge.
    ///
    /// Outside, it encroached on the neighbouring glyph: stack spacing is 40pt
    /// and a 36pt disc leaves only 4pt between edges, so an outward ring put
    /// two stacked members ~1pt apart and a focused stack read as one
    /// continuous coloured tube instead of separate markers. Inside the edge
    /// the 4pt gap survives and each member stays distinct.
    static let ringInset: CGFloat = -1.25
    static let ringOpacity: Double = 0.9

    static let connectorWidth: CGFloat = 1.5
    static let connectorOpacity: Double = 0.75

    /// Badge geometry mirrors the like badge, which sits at `x + 8`. Likes stay
    /// on the right; responses take the left.
    static let badgeSize: CGFloat = 14
    static let badgeLeadingInset: CGFloat = 22

    // MARK: - Connectors

    /// Draw every routed connector, behind all glyphs.
    ///
    /// `revealProgress` trims each path so the line draws itself from the
    /// parent toward the child. It is not an opacity fade: a partially drawn
    /// line reads as a connection being made, where a ghosted full-length line
    /// just reads as a rendering artefact.
    static func drawConnectors(
        context: GraphicsContext,
        plan: MarkerLinkRoutePlan,
        revealProgress: CGFloat
    ) {
        let progress = max(0, min(1, revealProgress))
        guard progress > 0 else { return }

        for route in plan.routes {
            let relationship = route.relationship
            let color = relationship?.accentColor ?? AppColors.greyText
            let dash = relationship?.dashPattern ?? [4, 3]

            let path = trimmedPath(for: route, progress: progress)
            context.stroke(
                path,
                with: .color(color.opacity(connectorOpacity)),
                style: StrokeStyle(
                    lineWidth: connectorWidth,
                    lineCap: .round,
                    dash: dash
                )
            )
        }
    }

    /// The quadratic route, flattened and cut at `progress`.
    static func trimmedPath(for route: MarkerLinkRoute, progress: CGFloat) -> Path {
        let steps = 32
        let limit = max(1, Int((CGFloat(steps) * progress).rounded()))
        var path = Path()
        path.move(to: route.start)
        for step in 1...limit {
            path.addLine(to: route.point(at: CGFloat(step) / CGFloat(steps)))
        }
        return path
    }

    // MARK: - Rings

    /// Ring identifying a marker as part of the focused thesis.
    ///
    /// Colour appears here and nowhere else in the resting chart: the glyph's
    /// own tint and border stay neutral, so deselecting restores exactly the
    /// 1.2.1 appearance.
    static func drawRing(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        style: MarkerLinkRingStyle,
        progress: CGFloat
    ) {
        let opacity = ringOpacity * Double(max(0, min(1, progress)))
        guard opacity > 0.01 else { return }

        let color: Color
        switch style {
        case .root:
            color = AppColors.accentColor
        case .response(let relationship):
            color = relationship?.accentColor ?? AppColors.greyText
        }

        let ringRadius = radius + ringInset
        let rect = CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        )
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: ringWidth)
        )
    }

    // MARK: - Visibility

    /// Whether a glyph's painted disc actually falls inside the plot.
    ///
    /// The render queue is culled horizontally, by candle index and a margin, so
    /// membership in it does not mean a glyph was seen: a companion can sit
    /// above or below the price range, behind the y-axis, or inside the margin
    /// and never be painted. The fade rule counts *visible* members, so it needs
    /// this rather than queue membership.
    ///
    /// Circle-against-rect, using the final scaled radius, so a partly visible
    /// disc still counts — half a glyph at the edge is a glyph the viewer can
    /// see and compare against.
    static func isGlyphVisible(
        center: CGPoint,
        scaledRadius: CGFloat,
        in plotRect: CGRect
    ) -> Bool {
        guard !plotRect.isEmpty, scaledRadius > 0 else { return false }
        let nearestX = min(max(center.x, plotRect.minX), plotRect.maxX)
        let nearestY = min(max(center.y, plotRect.minY), plotRect.maxY)
        let dx = center.x - nearestX
        let dy = center.y - nearestY
        return (dx * dx + dy * dy) <= (scaledRadius * scaledRadius)
    }

    // MARK: - Response badge

    /// What the single left-hand badge shows for one marker.
    ///
    /// One badge, not two: a relationship pip *and* a count badge would be a
    /// third decoration on a 36pt disc and unreadable in a dense stack. So the
    /// one badge carries whichever fact matters most for that marker — how many
    /// answered it, or, for a leaf, how it answered.
    enum BadgeKind: Equatable {
        /// An unlinked marker that has been answered: neutral count.
        case rootCount(Int)
        /// A response that has itself been answered: count in its own colour.
        case linkedCount(Int, MarkerLinkRelationshipValue)
        /// A response nothing has answered yet. A count of zero says nothing, so
        /// the badge shows the relationship glyph instead — without it a leaf is
        /// indistinguishable from an ordinary marker until you tap it.
        case leafIcon(MarkerLinkRelationshipValue)
    }

    /// Resolve the badge from marker facts, or `nil` for no badge at all.
    ///
    /// **The capability gate lives here, not at the call site.** Linked DTOs
    /// stay in memory after the flag goes false — turning the capability off
    /// must undecorate them, so every drawing and collision path routes through
    /// this one function rather than reading counts directly.
    static func badgeKind(
        linkedMarkersEnabled: Bool,
        responseCount: Int,
        relationship: MarkerLinkRelationshipValue?
    ) -> BadgeKind? {
        guard linkedMarkersEnabled else { return nil }
        if let relationship {
            return responseCount > 0
                ? .linkedCount(responseCount, relationship)
                : .leafIcon(relationship)
        }
        return responseCount > 0 ? .rootCount(responseCount) : nil
    }

    /// Mirror of the like badge, on the opposite side of the glyph.
    static func responseBadgeRect(center: CGPoint, isBelow: Bool) -> CGRect {
        let badgeOffset: CGFloat = isBelow ? -17 : 5
        return CGRect(
            x: center.x - badgeLeadingInset,
            y: center.y + badgeOffset,
            width: badgeSize,
            height: badgeSize
        )
    }

    static func drawResponseBadge(
        context: GraphicsContext,
        center: CGPoint,
        isBelow: Bool,
        badge: BadgeKind?
    ) {
        guard let badge else { return }
        let rect = responseBadgeRect(center: center, isBelow: isBelow)

        let fill: Color
        switch badge {
        case .rootCount:
            fill = AppColors.surfaceGray40
        case let .linkedCount(_, relationship), let .leafIcon(relationship):
            fill = relationship.accentColor
        }

        context.fill(
            Path(roundedRect: rect, cornerRadius: badgeSize / 2),
            with: .color(fill)
        )

        switch badge {
        case let .rootCount(count), let .linkedCount(count, _):
            context.draw(
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppColors.onAccentForeground),
                at: CGPoint(x: rect.midX, y: rect.midY)
            )
        case let .leafIcon(relationship):
            var icon = context.resolve(Image(systemName: relationship.icon))
            icon.shading = .color(AppColors.onAccentForeground)
            let side = min(badgeSize - 5, max(icon.size.width, icon.size.height))
            context.draw(
                icon,
                in: CGRect(
                    x: rect.midX - side / 2,
                    y: rect.midY - side / 2,
                    width: side,
                    height: side
                )
            )
        }
    }

    /// Badge rectangles a connector must avoid for one glyph: the like badge on
    /// the right, the response badge on the left.
    ///
    /// A leaf icon occupies exactly the same rect as a count, so it has to be
    /// declared here too — otherwise a connector would route straight through
    /// the one badge that identifies a leaf as a response.
    static func badgeRects(
        center: CGPoint,
        isBelow: Bool,
        likeCount: Int,
        badge: BadgeKind?
    ) -> [CGRect] {
        let badgeOffset: CGFloat = isBelow ? -17 : 5
        var rects: [CGRect] = []
        if likeCount > 0 {
            rects.append(
                CGRect(x: center.x + 8, y: center.y + badgeOffset, width: badgeSize, height: badgeSize)
            )
        }
        if badge != nil {
            rects.append(responseBadgeRect(center: center, isBelow: isBelow))
        }
        return rects
    }
}
