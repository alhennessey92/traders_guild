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

/// The per-marker state the glyph loop would otherwise recompute for every
/// marker, on every frame: the theme's colours and the symbols it draws.
///
/// Both were measured, not guessed. On the dense QA thesis the chart's
/// main-thread profile was dominated by two things inside the glyph loop:
///
/// * `GraphicsContext.resolve(Image(systemName:))`, which is not a lookup — it
///   goes through `Image.NamedImageProvider.resolve` and rebuilds the symbol
///   from its name, for the same handful of names hundreds of times a frame.
/// * every `AppColors` read, because a themed colour resolves through
///   `ThemeManager.shared.currentTheme`, an `@AppStorage`, and so performs a
///   `UserDefaults` read. There are roughly eight per marker.
///
/// Scoped to one draw pass deliberately, and passed `inout` rather than stored.
/// A resolved symbol reflects the environment of the context that resolved it,
/// and a colour reflects the theme at the moment it was read; a cache outliving
/// the pass could serve either one stale after a theme or trait change, while
/// one that dies with the pass cannot.
struct MarkerDrawPass {
    let markerShadow: Color
    let markerFill: Color
    let markerNeutralTint: Color
    let glassStroke: Color
    let heartBadge: Color
    let onAccent: Color
    let neutralBadgeFill: Color

    private let supports: Color
    private let challenges: Color
    private let buildsOn: Color
    private let unknownRelationship: Color

    private var resolvedSymbols: [String: GraphicsContext.ResolvedImage] = [:]
    private var resolvedBadgeGlyphs: [String: GraphicsContext.ResolvedImage] = [:]
    private var resolvedBadgeShapes: [String: GraphicsContext.ResolvedImage] = [:]

    init() {
        markerShadow = AppColors.canvasMarkerShadow
        markerFill = AppColors.canvasMarkerFill
        markerNeutralTint = AppColors.canvasMarkerNeutralTint
        glassStroke = MarkerVisualSpec.glassStrokeColor
        heartBadge = AppColors.markerHeartBadge
        onAccent = AppColors.onAccentForeground
        neutralBadgeFill = AppColors.surfaceGray40
        supports = AppColors.statusPositive
        challenges = AppColors.statusNegative
        buildsOn = AppColors.accentColor
        unknownRelationship = AppColors.greyText
    }

    /// The same value `MarkerLinkRelationshipValue.accentColor` returns, read
    /// once for each of the three relationships rather than once per marker.
    func accent(for relationship: MarkerLinkRelationshipValue) -> Color {
        switch relationship.known {
        case .supports: return supports
        case .challenges: return challenges
        case .buildsOn: return buildsOn
        case nil: return unknownRelationship
        }
    }

    mutating func symbol(
        named name: String,
        in context: GraphicsContext
    ) -> GraphicsContext.ResolvedImage {
        if let hit = resolvedSymbols[name] { return hit }
        let image = context.resolve(Image(systemName: name))
        resolvedSymbols[name] = image
        return image
    }

    /// A badge glyph at badge size, resolved once per pass rather than once per
    /// marker. Heavy weight, as the leaf badge: at eight points a regular
    /// outline reads as a smudge.
    ///
    /// An image, not `Text(Image(systemName:))`: drawn as text, every badge went
    /// through string layout on every frame, which was the whole of the avatar
    /// prototype's extra pan cost in controlled simulator profiling; device confirmation remains pending.
    /// The symbol shape is theme-free and cached for the process; the colour is
    /// applied per pass.
    mutating func badgeGlyph(
        named name: String,
        in context: GraphicsContext
    ) -> GraphicsContext.ResolvedImage {
        if let hit = resolvedBadgeGlyphs[name] { return hit }
        var image = context.resolve(Image(uiImage: MarkerBadgeGlyphImages.image(named: name)).renderingMode(.template))
        image.shading = .color(onAccent)
        resolvedBadgeGlyphs[name] = image
        return image
    }

    /// A badge outline (an alert's urgency shape) at badge size, resolved
    /// once per pass like the glyphs; the caller shades it per marker.
    mutating func badgeShape(
        named name: String,
        in context: GraphicsContext
    ) -> GraphicsContext.ResolvedImage {
        if let hit = resolvedBadgeShapes[name] { return hit }
        let image = context.resolve(Image(uiImage: MarkerBadgeGlyphImages.shape(named: name)).renderingMode(.template))
        resolvedBadgeShapes[name] = image
        return image
    }
}

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
    /// The plot rectangle the layer is clipped to. Routing never reads it;
    /// it only orders the idle cap.
    let plotRect: CGRect
    /// Connector stroke width, from chart settings.
    let lineWidth: CGFloat
    /// Multiplier on every bow and bracket offset, from chart settings.
    let curvature: CGFloat

    /// The two appearance values default to the persisted chart settings, so
    /// a caller that does not name them gets the user's choice rather than a
    /// constant. `TradingChartView` observes that same object, so a slider
    /// change re-renders the canvas with the new values through this path.
    init(
        focus: MarkerFocusState,
        ringStyles: [UUID: MarkerLinkRingStyle],
        revealProgress: CGFloat,
        plotRect: CGRect,
        lineWidth: CGFloat = ChartSettings.shared.linkLineWidth,
        curvature: CGFloat = ChartSettings.shared.linkCurvature
    ) {
        self.focus = focus
        self.ringStyles = ringStyles
        self.revealProgress = revealProgress
        self.plotRect = plotRect
        self.lineWidth = lineWidth
        self.curvature = curvature
    }

    func isDimmed(_ markerId: UUID) -> Bool {
        focus.shouldFadeUnrelated && !focus.memberIds.contains(markerId)
    }
}

/// Everything the marker layer needs to draw the chart's resting link lines.
///
/// With nothing selected, every direct parent→child pair on the chart wears a
/// faint dotted line — enough to see that markers belong together without
/// tapping, never enough to compete with the candles. Focus replaces it with
/// the full-strength connectors; placement's dim suppresses it.
struct MarkerIdleLinkContext {
    /// Every drawable loaded edge, bridges included.
    let edges: [MarkerLinkEdge]
    let plotRect: CGRect
    let lineWidth: CGFloat
    let curvature: CGFloat

    init(
        edges: [MarkerLinkEdge],
        plotRect: CGRect,
        lineWidth: CGFloat = ChartSettings.shared.linkLineWidth,
        curvature: CGFloat = ChartSettings.shared.linkCurvature
    ) {
        self.edges = edges
        self.plotRect = plotRect
        self.lineWidth = lineWidth
        self.curvature = curvature
    }

    /// Lines beyond this many are not routed at rest; the plan orders edges
    /// nearest the viewport centre first, so the ones the reader is looking
    /// at are the ones kept.
    static let maximumEdges = 60
}

/// While a response is being placed: the marker it answers, and where the
/// ghost currently is.
///
/// The placement dim used to take the parent down with everything else, and
/// the only statement of the relationship was a banner in the panel below.
/// With this the parent stays lit and ringed in the relationship's colour, and
/// one full-strength connector runs from it to the ghost — re-routed every
/// frame, so it follows the drag.
struct MarkerPlacementLinkContext {
    /// A stable id for the ghost, so it can take part in routing as a glyph.
    static let ghostId = UUID(uuidString: "9A05B0D9-6E2A-4C7E-9E8F-000000000001")!

    let parentId: UUID
    let relationship: MarkerLinkRelationshipValue
    /// The ghost glyph's centre in chart coordinates.
    let ghostPoint: CGPoint
    let plotRect: CGRect
    let lineWidth: CGFloat
    let curvature: CGFloat

    init(
        parentId: UUID,
        relationship: MarkerLinkRelationshipValue,
        ghostPoint: CGPoint,
        plotRect: CGRect,
        lineWidth: CGFloat = ChartSettings.shared.linkLineWidth,
        curvature: CGFloat = ChartSettings.shared.linkCurvature
    ) {
        self.parentId = parentId
        self.relationship = relationship
        self.ghostPoint = ghostPoint
        self.plotRect = plotRect
        self.lineWidth = lineWidth
        self.curvature = curvature
    }

    var edge: MarkerLinkEdge {
        MarkerLinkEdge(parentId: parentId, childId: Self.ghostId, relationship: relationship, kind: .childOfSelected)
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

    /// Default stroke width; the persisted setting overrides it per frame.
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
        revealProgress: CGFloat,
        lineWidth: CGFloat = connectorWidth
    ) {
        let progress = max(0, min(1, revealProgress))
        guard progress > 0 else { return }
        let width = min(max(lineWidth, ChartSettings.linkLineWidthRange.lowerBound),
                        ChartSettings.linkLineWidthRange.upperBound)

        for route in plan.routes {
            let relationship = route.relationship
            let color = relationship?.accentColor ?? AppColors.greyText
            // Dash patterns are the relationship's own and are not scaled with
            // the width: a thicker "challenges" line is still the same
            // rhythm, which is what keeps it readable as the same relationship.
            // A bridge over a deleted marker is fainter and more broken: still
            // the relationship's colour, but plainly not a direct answer.
            let bridged = route.edge.viaUnavailable
            let dash = bridged ? viaUnavailableDash : (relationship?.dashPattern ?? [4, 3])
            let opacity = bridged ? connectorOpacity * viaUnavailableOpacityFactor : connectorOpacity

            let path = trimmedPath(for: route, progress: progress)
            context.stroke(
                path,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: dash
                )
            )
        }
    }

    /// Dash for an edge that passes over a deleted marker: sparser than any
    /// relationship's own, so it reads as a gap rather than a rhythm.
    static let viaUnavailableDash: [CGFloat] = [2, 4]
    static let viaUnavailableOpacityFactor: Double = 0.5

    /// Opacity of the resting lines. Deliberately close to the focus dim
    /// (0.22), so the two read as one idiom: what is not in focus is faint.
    static let idleConnectorOpacity: Double = 0.22
    static let idleDash: [CGFloat] = [3, 3]

    /// The resting lines: one pass, no reveal, no gradient, one weight. The
    /// relationship still carries its colour so a supports line and a
    /// challenges line can be told apart even at rest.
    static func drawIdleConnectors(
        context: GraphicsContext,
        plan: MarkerLinkRoutePlan,
        lineWidth: CGFloat = connectorWidth
    ) {
        let width = max(1, min(lineWidth, ChartSettings.linkLineWidthRange.upperBound) * 0.75)
        for route in plan.routes {
            let color = route.relationship?.accentColor ?? AppColors.greyText
            let bridged = route.edge.viaUnavailable
            context.stroke(
                trimmedPath(for: route, progress: 1),
                with: .color(color.opacity(bridged ? idleConnectorOpacity * viaUnavailableOpacityFactor : idleConnectorOpacity)),
                style: StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: bridged ? viaUnavailableDash : idleDash
                )
            )
        }
    }

    /// The quadratic route, cut at `progress`.
    ///
    /// Emits one real quadratic segment. It used to emit 32 straight ones,
    /// which on a short bowed span put as much as 38 degrees of direction
    /// change into a single join — the connector's angular look.
    static func trimmedPath(for route: MarkerLinkRoute, progress: CGFloat) -> Path {
        let t = max(0, min(1, progress))
        var path = Path()
        path.move(to: route.start)
        guard t > 0 else { return path }
        // One real curve, not 32 chords of one. The flattened version put up to
        // 38 degrees of turn into a single miter join on a short bowed span,
        // which is what the connector's angular look actually was. Both
        // families are exactly representable, so nothing is approximated.
        if let control2 = route.control2 {
            let piece = MarkerLinkGeometry.subCubic(
                start: route.start,
                control1: route.control,
                control2: control2,
                end: route.end,
                t0: 0,
                t1: t
            )
            path.addCurve(to: piece.end, control1: piece.control1, control2: piece.control2)
        } else {
            path.addQuadCurve(
                to: route.point(at: t),
                control: MarkerLinkGeometry.subCurveControl(
                    start: route.start,
                    control: route.control,
                    end: route.end,
                    t0: 0,
                    t1: t
                )
            )
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

    /// How far a badge moves out along its diagonal when the glyph is drawn
    /// at `scale`, so it keeps straddling the disc's edge instead of sinking
    /// inside the enlarged disc of a selected marker. The resting geometry
    /// (scale 1) is unchanged.
    static func badgeOutset(scale: CGFloat) -> CGFloat {
        let baseRadius = MarkerVisualSpec.baseCanvasDiameter / 2
        return max(0, baseRadius * scale - baseRadius) * 0.7071
    }

    /// Like badge on the right, candle side; response badge mirrors it on the left.
    static func likeBadgeRect(center: CGPoint, isBelow: Bool, scale: CGFloat = 1) -> CGRect {
        let outset = badgeOutset(scale: scale)
        let badgeOffset: CGFloat = isBelow ? -17 - outset : 5 + outset
        return CGRect(
            x: center.x + 8 + outset,
            y: center.y + badgeOffset,
            width: badgeSize,
            height: badgeSize
        )
    }

    /// Mirror of the like badge, on the opposite side of the glyph.
    static func responseBadgeRect(center: CGPoint, isBelow: Bool, scale: CGFloat = 1) -> CGRect {
        let outset = badgeOutset(scale: scale)
        let badgeOffset: CGFloat = isBelow ? -17 - outset : 5 + outset
        return CGRect(
            x: center.x - badgeLeadingInset - outset,
            y: center.y + badgeOffset,
            width: badgeSize,
            height: badgeSize
        )
    }

    static func drawResponseBadge(
        context: GraphicsContext,
        center: CGPoint,
        isBelow: Bool,
        badge: BadgeKind?,
        scale: CGFloat = 1,
        pass: inout MarkerDrawPass
    ) {
        guard let badge else { return }
        let rect = responseBadgeRect(center: center, isBelow: isBelow, scale: scale)

        let fill: Color
        switch badge {
        case .rootCount:
            fill = pass.neutralBadgeFill
        case let .linkedCount(_, relationship), let .leafIcon(relationship):
            fill = pass.accent(for: relationship)
        }

        context.fill(
            Path(roundedRect: rect, cornerRadius: badgeSize / 2),
            with: .color(fill)
        )

        switch badge {
        case let .rootCount(count), let .linkedCount(count, _):
            // `verbatim:`, not interpolation. `Text("\(count)")` is a
            // `LocalizedStringKey` with an argument, so every frame it walked
            // the localisation path — resolving arguments and enumerating an
            // attributed string per marker. A count is a number, never
            // translated prose, so none of that work has anything to do.
            context.draw(
                Text(verbatim: count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(pass.onAccent),
                at: CGPoint(x: rect.midX, y: rect.midY)
            )
        case let .leafIcon(relationship):
            // Drawn as text so the symbol takes a weight: at nine points a
            // regular-weight outline glyph reads as a hollow smudge, a heavy
            // one reads as a mark.
            context.draw(
                Text(Image(systemName: relationship.icon))
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundColor(pass.onAccent),
                at: CGPoint(x: rect.midX, y: rect.midY)
            )
        }
    }

    // MARK: - Cross-timeframe jump badges

    /// Draw the selected glyph's cross-timeframe badges.
    ///
    /// A filled disc in the relationship's colour with the target timeframe in
    /// the middle, and a circular arrow running around the outside — clockwise
    /// down to a response, anticlockwise up to a parent. `reveal` fades them in
    /// with the selection pop so they arrive with the glyph rather than
    /// blinking on after it.
    static func drawTimeframeJumpBadges(
        context: GraphicsContext,
        placements: [MarkerTimeframeJumpLayout.Placement],
        reveal: CGFloat,
        pass: inout MarkerDrawPass
    ) {
        let alpha = max(0, min(1, reveal))
        guard alpha > 0, !placements.isEmpty else { return }
        var badgeContext = context
        badgeContext.opacity = alpha

        for placement in placements {
            let center = placement.center
            // "Choose" is not a relationship. The ellipsis badge used to borrow
            // the newest response's colour and read as that relationship; it
            // takes the neutral badge fill instead, like a root's count.
            let accent = placement.jump.requiresChoice
                ? pass.neutralBadgeFill
                : pass.accent(for: placement.jump.relationship)
            let disc = MarkerTimeframeJumpLayout.badgeRadius
            let ring = MarkerTimeframeJumpLayout.arrowRadius

            // The tether: a thin dotted line from the glyph's ring to the
            // arrow ring, so a badge floating clear of the candle still
            // reads as belonging to this glyph and not to a neighbour.
            var tether = Path()
            tether.move(to: placement.tetherStart)
            tether.addLine(to: placement.tetherEnd)
            badgeContext.stroke(
                tether,
                with: .color(accent.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 3])
            )

            // A hairline of chart background under the disc and the arrow so
            // they stay legible over a candle or another glyph.
            badgeContext.fill(
                Path(ellipseIn: CGRect(x: center.x - ring - 1.5, y: center.y - ring - 1.5,
                                       width: (ring + 1.5) * 2, height: (ring + 1.5) * 2)),
                with: .color(pass.markerShadow.opacity(0.55))
            )
            badgeContext.fill(
                Path(ellipseIn: CGRect(x: center.x - disc, y: center.y - disc, width: disc * 2, height: disc * 2)),
                with: .color(accent)
            )

            // The arrow: a 300° arc with a small head at its leading end.
            let clockwise = placement.jump.direction == .toResponse
            let start = Angle.degrees(-120)
            let end = Angle.degrees(clockwise ? 180 : -420)
            var arc = Path()
            arc.addArc(center: center, radius: ring, startAngle: start, endAngle: end, clockwise: !clockwise)
            badgeContext.stroke(arc, with: .color(accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            let tip = CGPoint(x: center.x + ring * CGFloat(cos(end.radians)),
                              y: center.y + ring * CGFloat(sin(end.radians)))
            // Tangent direction of travel at the tip.
            let tangent = end.radians + (clockwise ? .pi / 2 : -.pi / 2)
            var head = Path()
            for side in [-1.0, 1.0] {
                let angle = tangent + .pi + side * 0.55
                head.move(to: tip)
                head.addLine(to: CGPoint(x: tip.x + 4.5 * CGFloat(cos(angle)),
                                         y: tip.y + 4.5 * CGFloat(sin(angle))))
            }
            badgeContext.stroke(head, with: .color(accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            badgeContext.draw(
                Text(verbatim: placement.jump.badgeText)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(pass.onAccent),
                at: center
            )
        }
    }

    /// Badge rectangles a connector must avoid for one glyph: the like badge on
    /// the right, the response badge on the left, and an avatar-led marker's
    /// intent badge outward.
    ///
    /// A leaf icon occupies exactly the same rect as a count, so it has to be
    /// declared here too — otherwise a connector would route straight through
    /// the one badge that identifies a leaf as a response. The intent badge is
    /// declared for the same reason. None of these are tap targets: hit testing
    /// is disc-only (`MarkerGlyphBounds.isHit`).
    static func badgeRects(
        center: CGPoint,
        isBelow: Bool,
        likeCount: Int,
        badge: BadgeKind?,
        scale: CGFloat = 1,
        intentBadge: Bool = false
    ) -> [CGRect] {
        var rects: [CGRect] = []
        if likeCount > 0 {
            rects.append(likeBadgeRect(center: center, isBelow: isBelow, scale: scale))
        }
        if badge != nil {
            rects.append(responseBadgeRect(center: center, isBelow: isBelow, scale: scale))
        }
        if intentBadge {
            rects.append(MarkerIntentBadge.rect(center: center, isBelow: isBelow, scale: scale))
        }
        return rects
    }
}


/// SF Symbol badge glyphs at the badge's 8 pt heavy configuration, built once per
/// symbol name. Shape only: the draw pass tints them.
enum MarkerBadgeGlyphImages {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]  // guarded by `lock`

    static func image(named name: String) -> UIImage {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[name] { return hit }
        let configuration = UIImage.SymbolConfiguration(pointSize: 8, weight: .heavy)
        let image = (UIImage(systemName: name, withConfiguration: configuration) ?? UIImage())
            .withRenderingMode(.alwaysTemplate)
        cache[name] = image
        return image
    }

    /// A filled outline sized to stand in for the badge's disc.
    static func shape(named name: String) -> UIImage {
        let key = "shape:" + name
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        let configuration = UIImage.SymbolConfiguration(pointSize: MarkerLinkRenderer.badgeSize * 0.92, weight: .regular)
        let image = (UIImage(systemName: name, withConfiguration: configuration) ?? UIImage())
            .withRenderingMode(.alwaysTemplate)
        cache[key] = image
        return image
    }
}
