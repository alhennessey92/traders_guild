import SwiftUI
import Testing
import UIKit
@testable import traders_guild

/// What an avatar-led marker wears around its face: intent badge, idle ring,
/// relationship-ring precedence and selected component arcs.
@MainActor
struct MarkerIntentDecorationTests {

    // MARK: Badge content

    @Test
    func theThreeIntentsHaveABadgeAndTheRestKeepTheirGlyph() {
        #expect(MarkerIntentBadge.style(intent: .analysis)?.symbol == "waveform.path.ecg")
        #expect(MarkerIntentBadge.style(intent: .question)?.symbol == "questionmark")
        #expect(MarkerIntentBadge.style(intent: .setup) != nil)
        for intent in [RLMarkerIntent.alert, .poll, .news, .reaction, .personal] {
            #expect(MarkerIntentBadge.style(intent: intent) == nil)
        }
    }

    @Test
    func aSetupBadgeFollowsItsLifecycle() {
        typealias Status = MarkerIntentBadge.SetupStatus
        let win = RLPredictionResultDTO(resultType: "take_profit", triggerPrice: 1, triggeredAt: .now,
                                        triggeredAtFormatted: "", pnl: nil, guildRepDelta: nil, globalRepDelta: nil)
        let loss = RLPredictionResultDTO(resultType: "stop_loss", triggerPrice: 1, triggeredAt: .now,
                                         triggeredAtFormatted: "", pnl: nil, guildRepDelta: nil, globalRepDelta: nil)

        #expect(Status.from(trackingEnabled: false, trackingState: nil, predictionResult: nil) == .untracked)
        #expect(Status.from(trackingEnabled: false, trackingState: .draft, predictionResult: nil) == .untracked)
        #expect(Status.from(trackingEnabled: true, trackingState: nil, predictionResult: nil) == .armed)
        #expect(Status.from(trackingEnabled: true, trackingState: .active, predictionResult: nil) == .active)
        #expect(Status.from(trackingEnabled: true, trackingState: .active, predictionResult: win) == .takeProfit,
                "a resolved result wins over a stale state")
        #expect(Status.from(trackingEnabled: true, trackingState: .slHit, predictionResult: nil) == .stopLoss)
        #expect(Status.from(trackingEnabled: true, trackingState: .tpHit, predictionResult: loss) == .stopLoss)
        #expect(Status.from(summaryTrackingState: nil) == .unknown)
        #expect(Status.from(summaryTrackingState: "ACTIVE") == .active)
        #expect(Status.from(summaryTrackingState: "DRAFT") == .untracked)

        // Untracked must read differently from a live one.
        let untracked = MarkerIntentBadge.style(intent: .setup, setupStatus: .untracked)
        let live = MarkerIntentBadge.style(intent: .setup, setupStatus: .active)
        #expect(untracked != live)
        #expect(MarkerIntentBadge.style(intent: .setup, setupStatus: .takeProfit)?.symbol == "checkmark")
        #expect(MarkerIntentBadge.style(intent: .setup, setupStatus: .stopLoss)?.symbol == "xmark")
    }

    // MARK: Rings

    @Test
    func theRelationshipRingReplacesTheIntentRing() {
        #expect(MarkerIntentRing.strokeColor(intent: .analysis, showsDecorations: true, hasRelationshipRing: false) != nil)
        #expect(MarkerIntentRing.strokeColor(intent: .analysis, showsDecorations: true, hasRelationshipRing: true) == nil)
        #expect(MarkerIntentRing.strokeColor(intent: .analysis, showsDecorations: false, hasRelationshipRing: false) == nil)
        #expect(MarkerIntentRing.strokeColor(intent: .personal, showsDecorations: true, hasRelationshipRing: false) == nil,
                "personal keeps its current presentation")
    }

    @Test
    func onlyThePrototypesIntentsWearDecorationsAndOnlyWhenItIsOn() {
        let on = MarkerAvatarPresentation.avatarIntents(experimentEnabled: true)
        let off = MarkerAvatarPresentation.avatarIntents(experimentEnabled: false)
        let fixtures = MarkerLinkFixtures.mixedLegacy().markers
        for marker in fixtures {
            let expected = [RLMarkerIntent.analysis, .question, .setup].contains(marker.intent)
            #expect(ChartMarkerSystem.wearsIntentDecorations(marker, avatarIntents: on) == expected)
            #expect(ChartMarkerSystem.wearsIntentDecorations(marker, avatarIntents: off) == false)
        }
    }

    // MARK: Component arcs

    private func components(_ types: [RLComponentType]) -> [RLMarkerComponentDTO] {
        MarkerLinkFixtures.fixtureComponents(types, marker: 1)
    }

    @Test
    func arcsGroupRepeatsKeepAFixedOrderAndSkipStructure() {
        typealias Arcs = MarkerComponentArcs
        #expect(Arcs.categories(of: components([.timeframeLink, .indicator, .indicator, .drawingZone])) ==
                [.indicators, .drawings, .timeframesAndLinks])
        #expect(Arcs.categories(of: components([.anchor, .levelEntry, .levelSl, .levelTp])).isEmpty)
        #expect(Arcs.categories(of: components([.levelSupport, .textNote, .linkURL])) == [.drawings, .timeframesAndLinks])
        #expect(Arcs.categories(of: []).isEmpty)
    }

    // MARK: Geometry

    private let diameter = MarkerVisualSpec.baseCanvasDiameter

    private func discRect(_ center: CGPoint, scale: CGFloat = 1) -> CGRect {
        let r = diameter / 2 * scale
        return CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
    }

    /// The intent badge clears the glyph's own like and response badges, and
    /// the stack neighbour directly outward (disc and like badge), at rest and
    /// once selected with the neighbour nudged — above and below the candle.
    @Test(arguments: [false, true])
    func theIntentBadgeClearsItsNeighbours(isBelow: Bool) {
        let outward: CGFloat = isBelow ? 1 : -1
        for scale in [CGFloat(1), MarkerVisualSpec.selectedScale] {
            let center = CGPoint(x: 200, y: 300)
            let intent = MarkerIntentBadge.rect(center: center, isBelow: isBelow, scale: scale)
            #expect(!intent.intersects(MarkerLinkRenderer.likeBadgeRect(center: center, isBelow: isBelow, scale: scale)))
            #expect(!intent.intersects(MarkerLinkRenderer.responseBadgeRect(center: center, isBelow: isBelow, scale: scale)))

            let spacing = MarkerPositionCalculator.hardMinimumStackSpacing
                + (scale > 1 ? MarkerStackLayout.selectionNudge : 0)
            let neighbour = CGPoint(x: center.x, y: center.y + outward * spacing)
            let neighbourLike = MarkerLinkRenderer.likeBadgeRect(center: neighbour, isBelow: isBelow)
            #expect(!intent.intersects(neighbourLike), "scale \(scale): into the neighbour's like badge")
            // Disc clearance: nearest point of the badge to the neighbour centre.
            let nearestX = min(max(neighbour.x, intent.minX), intent.maxX)
            let nearestY = min(max(neighbour.y, intent.minY), intent.maxY)
            let gap = hypot(neighbour.x - nearestX, neighbour.y - nearestY) - diameter / 2
            #expect(gap > 0, "scale \(scale): badge overlaps the neighbour's disc by \(-gap)pt")
        }
    }

    /// Arc slots never run under a badge of their own glyph, and never overlap
    /// each other.
    @Test(arguments: [false, true])
    func arcSlotsStayClearOfBadges(isBelow: Bool) {
        let scale = MarkerVisualSpec.selectedScale
        let center = CGPoint(x: 200, y: 300)
        let arcRadius = diameter / 2 * scale + MarkerComponentArcs.radiusOffset
        let badges = [
            MarkerIntentBadge.rect(center: center, isBelow: isBelow, scale: scale),
            MarkerLinkRenderer.likeBadgeRect(center: center, isBelow: isBelow, scale: scale),
            MarkerLinkRenderer.responseBadgeRect(center: center, isBelow: isBelow, scale: scale),
        ].map { $0.insetBy(dx: -1, dy: -1) }

        var previousEnd: Double?
        for category in MarkerComponentArcs.Category.allCases {
            let slot = MarkerComponentArcs.slot(for: category, isBelow: isBelow)
            #expect(slot.end.degrees > slot.start.degrees)
            for step in 0...20 {
                let degrees = slot.start.degrees + (slot.end.degrees - slot.start.degrees) * Double(step) / 20
                let point = CGPoint(
                    x: center.x + arcRadius * CGFloat(cos(degrees * .pi / 180)),
                    y: center.y + arcRadius * CGFloat(sin(degrees * .pi / 180))
                )
                for badge in badges {
                    #expect(!badge.contains(point), "\(category) arc under a badge at \(degrees)°")
                }
            }
            if !isBelow, let previousEnd { #expect(slot.start.degrees > previousEnd) }
            previousEnd = slot.end.degrees
        }
    }

    /// An intent badge is part of the glyph's obstacle for the connector
    /// router — the same predicate like and response badges go through.
    @Test
    func intentBadgesAreConnectorObstacles() {
        let center = CGPoint(x: 200, y: 300)
        let badge = MarkerIntentBadge.rect(center: center, isBelow: false)
        // The badge's far corner: outside the disc and its clearance.
        let corner = CGPoint(x: badge.maxX - 1, y: badge.minY + 1)
        #expect(hypot(corner.x - center.x, corner.y - center.y) > diameter / 2 + MarkerLinkGeometry.clearance)

        func bounds(intentBadge: Bool) -> MarkerGlyphBounds {
            MarkerGlyphBounds(
                id: MarkerLinkFixtures.uuid(1), center: center, radius: diameter / 2,
                badgeRects: MarkerLinkRenderer.badgeRects(
                    center: center, isBelow: false, likeCount: 0, badge: nil, intentBadge: intentBadge
                )
            )
        }
        #expect(bounds(intentBadge: true).contains(corner, clearance: MarkerLinkGeometry.clearance))
        #expect(!bounds(intentBadge: false).contains(corner, clearance: MarkerLinkGeometry.clearance))
    }

    /// Through the production router: a bystander placed so its intent badge
    /// sits on the route the pair would otherwise take is routed around.
    @Test
    func routesKeepOffIntentBadges() throws {
        func id(_ n: Int) -> UUID { MarkerLinkFixtures.uuid(n) }
        let edge = MarkerLinkEdge(parentId: id(1), childId: id(2),
                                  relationship: MarkerLinkRelationshipValue(.supports), kind: .childOfSelected)
        let parent = MarkerGlyphBounds(id: id(1), center: CGPoint(x: 200, y: 500), radius: diameter / 2)
        let child = MarkerGlyphBounds(id: id(2), center: CGPoint(x: 200, y: 380), radius: diameter / 2)
        let unobstructed = try #require(MarkerLinkGeometry.route(
            edge: edge, glyphs: [id(1): parent, id(2): child], obstacles: [parent, child]
        ))

        // Put the bystander's badge corner on the route's midpoint.
        let midpoint = unobstructed.point(at: 0.5)
        let bystanderCenter = CGPoint(x: midpoint.x - 21, y: midpoint.y + 16)
        let bystander = MarkerGlyphBounds(
            id: id(3), center: bystanderCenter, radius: diameter / 2,
            badgeRects: MarkerLinkRenderer.badgeRects(
                center: bystanderCenter, isBelow: false, likeCount: 0, badge: nil, intentBadge: true
            )
        )
        let badge = MarkerIntentBadge.rect(center: bystanderCenter, isBelow: false)
        #expect(badge.contains(midpoint), "fixture: the unobstructed route runs through the badge")

        let glyphs = [id(1): parent, id(2): child, id(3): bystander]
        let route = try #require(MarkerLinkGeometry.route(edge: edge, glyphs: glyphs, obstacles: Array(glyphs.values)))
        for step in 0...96 {
            #expect(!badge.contains(route.point(at: CGFloat(step) / 96)), "route ran under the intent badge")
        }
    }

    // MARK: Pixels: arcs through the real renderer

    private static let avatarURL = URL(string: "https://decoration-tests.invalid/avatar.png")!
    private let renderScale: CGFloat = 2
    private let canvasSize = CGSize(width: 240, height: 300)
    private let priceRange: (min: Double, max: Double) = (63_000, 65_000)
    private let candleWidth: CGFloat = 40

    private struct Probe: View {
        let markers: [ChartMarkerUI]
        let candles: [RLCandleDTO]
        let selectedId: UUID?
        let size: CGSize
        let priceRange: (min: Double, max: Double)
        let candleWidth: CGFloat
        let avatars: [MarkerAvatarSymbolEntry]

        var body: some View {
            Canvas { context, size in
                ChartMarkerSystem.drawMarkers(
                    context: context, markers: markers, candles: candles, chartSize: size,
                    priceRange: priceRange, priceScale: 1, verticalOffset: 0,
                    totalCandleWidth: candleWidth, actualCandleWidth: candleWidth * 0.7, totalOffset: 0,
                    selectedMarkerId: selectedId, selectedMarkerScale: MarkerVisualSpec.selectedScale,
                    avatarIntents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: true)
                )
            } symbols: {
                MarkerCanvasSymbols.content(avatars: avatars)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private struct Rendered {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let center: CGPoint
    }

    private func render(components types: [RLComponentType], selected: Bool, isBelow: Bool = false) throws -> Rendered {
        AvatarImageCache.shared.store(UIImage(systemName: "person.fill")!, for: Self.avatarURL)
        let candles = MarkerLinkFixtures.candles(count: 5)
        var dto = MarkerLinkFixtures.marker(
            1, author: "probe", intent: .analysis, candle: candles[2].timestamp, price: 64_000,
            title: nil, components: types
        )
        dto = RLChartMarkerDTO(
            id: dto.id, symbolId: dto.symbolId, guildId: dto.guildId,
            author: MarkerLinkFixtures.member(1, username: "probe", avatarUrl: Self.avatarURL.absoluteString),
            candleTimestamp: dto.candleTimestamp, timeframe: dto.timeframe, price: dto.price,
            intent: dto.intent, title: nil, note: nil, visibility: "guild", confidence: nil,
            trackingEnabled: false, trackingState: nil, alertSeverity: nil, createdAt: dto.createdAt,
            createdAtFormatted: "", isVisible: true, likeCount: 0, isLikedByCurrentUser: false,
            commentCount: 0, comments: [], isCurrentUserMarker: false, canEdit: false, canDelete: false,
            components: dto.components, primaryComponentId: nil, pollQuestion: nil, pollOptions: nil,
            userPollVote: nil, predictionResult: nil
        )
        var marker = ChartMarkerUI(marker: dto, candleIndex: 2)
        marker.positionedBelow = isBelow
        marker.hasStableLayout = true

        let candle = candles[2]
        let span = CGFloat(priceRange.max - priceRange.min)
        let highY = canvasSize.height - CGFloat(candle.high - priceRange.min) / span * canvasSize.height
        let lowY = canvasSize.height - CGFloat(candle.low - priceRange.min) / span * canvasSize.height
        let center = MarkerPositionCalculator.computeMarkerScreenPosition(
            marker: marker, candleHighY: highY, candleLowY: lowY,
            centerX: 2 * candleWidth + candleWidth * 0.35, priceScale: 1, viewportHeight: canvasSize.height
        )

        let renderer = ImageRenderer(content: Probe(
            markers: [marker], candles: candles, selectedId: selected ? marker.id : nil,
            size: canvasSize, priceRange: priceRange, candleWidth: candleWidth,
            avatars: [MarkerAvatarSymbolEntry(
                authorId: dto.author.userId,
                identity: MarkerAvatarIdentity(url: Self.avatarURL.absoluteString, initials: "PR")
            )]
        ))
        renderer.scale = renderScale
        let image = try #require(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(
            data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Rendered(pixels: pixels, width: image.width, height: image.height, center: center)
    }

    /// Points (in pt) where two renders differ.
    private func difference(_ a: Rendered, _ b: Rendered) -> [CGPoint] {
        var points: [CGPoint] = []
        for y in 0..<a.height {
            for x in 0..<a.width {
                let i = (y * a.width + x) * 4
                let delta = (0..<4).map { abs(Int(a.pixels[i + $0]) - Int(b.pixels[i + $0])) }.max() ?? 0
                if delta > 12 {
                    points.append(CGPoint(x: (CGFloat(x) + 0.5) / renderScale, y: (CGFloat(y) + 0.5) / renderScale))
                }
            }
        }
        return points
    }

    @Test(arguments: [false, true])
    func anIndicatorAddsOneArcInItsSlotOnSelection(isBelow: Bool) throws {
        let bare = try render(components: [], selected: true, isBelow: isBelow)
        let withIndicator = try render(components: [.indicator, .indicator], selected: true, isBelow: isBelow)
        let changed = difference(bare, withIndicator)
        #expect(changed.count > 20, "no arc was drawn")

        let slot = MarkerComponentArcs.slot(for: .indicators, isBelow: isBelow)
        let arcRadius = MarkerVisualSpec.baseCanvasDiameter / 2 * MarkerVisualSpec.selectedScale
            + MarkerComponentArcs.radiusOffset
        for point in changed {
            let dx = point.x - bare.center.x, dy = point.y - bare.center.y
            let distance = hypot(dx, dy)
            #expect(abs(distance - arcRadius) <= 2.5, "arc pixel off the band at \(distance)pt")
            var degrees = atan2(Double(dy), Double(dx)) * 180 / .pi
            while degrees < slot.start.degrees - 10 { degrees += 360 }
            while degrees >= slot.start.degrees + 350 { degrees -= 360 }
            #expect(degrees >= slot.start.degrees - 6 && degrees <= slot.end.degrees + 6,
                    "arc pixel at \(degrees)° outside the indicators slot")
        }
    }

    @Test
    func setupLevelsAndTheAnchorDrawNoArc() throws {
        let bare = try render(components: [], selected: true)
        let structural = try render(components: [.anchor, .levelEntry, .levelSl, .levelTp], selected: true)
        #expect(difference(bare, structural).isEmpty)
    }

    @Test
    func arcsAppearOnlyOnSelection() throws {
        let bare = try render(components: [], selected: false)
        let withContext = try render(components: [.indicator, .drawingTrendline, .timeframeLink], selected: false)
        #expect(difference(bare, withContext).isEmpty)
    }
}
