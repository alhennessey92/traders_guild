import SwiftUI
import Testing
import UIKit
@testable import traders_guild

/// The avatar as the chart actually paints it: real `ChartMarkerSystem`
/// drawing, real Canvas symbol registration, rendered to pixels.
///
/// The picture is a known two-colour image — red left half, blue right — so
/// its painted extent and orientation can be measured directly.
@MainActor
struct MarkerAvatarRenderTests {

    private static let avatarURL = URL(string: "https://render-tests.invalid/avatar.png")!
    private static let authorNumber = 77

    private static let twoToneImage: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120), format: format).image { ctx in
            UIColor(red: 1, green: 0, blue: 0, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 120))
            UIColor(red: 0, green: 0, blue: 1, alpha: 1).setFill()
            ctx.fill(CGRect(x: 60, y: 0, width: 60, height: 120))
        }
    }()

    private let renderScale: CGFloat = 3

    private struct Probe: View {
        let markers: [ChartMarkerUI]
        let candles: [RLCandleDTO]
        let scale: CGFloat
        let rotation: CGFloat
        let avatarIntents: Set<RLMarkerIntent>
        let avatars: [MarkerAvatarSymbolEntry]

        var body: some View {
            Canvas { context, size in
                ChartMarkerSystem.drawMarkers(
                    context: context,
                    markers: markers,
                    candles: candles,
                    chartSize: size,
                    priceRange: (63_000, 65_000),
                    priceScale: 1,
                    verticalOffset: 0,
                    totalCandleWidth: 40,
                    actualCandleWidth: 28,
                    totalOffset: 0,
                    selectedMarkerId: markers.first?.id,
                    selectedMarkerScale: scale,
                    selectedMarkerRotation: rotation,
                    avatarIntents: avatarIntents
                )
            } symbols: {
                MarkerCanvasSymbols.content(avatars: avatars)
            }
            .frame(width: 200, height: 300)
        }
    }

    private struct Extent {
        var red: CGRect = .null
        var blue: CGRect = .null
        var farthestFromCentre: CGFloat = 0
    }

    private func render(
        intent: RLMarkerIntent = .analysis,
        scale: CGFloat,
        rotation: CGFloat = 0,
        experiment: Bool = true
    ) throws -> Extent {
        AvatarImageCache.shared.store(Self.twoToneImage, for: Self.avatarURL)
        let author = MarkerLinkFixtures.member(Self.authorNumber, username: "probe", avatarUrl: Self.avatarURL.absoluteString)
        let candles = MarkerLinkFixtures.candles(count: 5)
        let base = MarkerLinkFixtures.marker(
            1, author: "probe", intent: intent, candle: candles[2].timestamp, price: 64_000, title: nil
        )
        let dto = RLChartMarkerDTO(
            id: base.id, symbolId: base.symbolId, guildId: base.guildId, author: author,
            candleTimestamp: base.candleTimestamp, timeframe: base.timeframe, price: base.price,
            intent: base.intent, title: nil, note: nil, visibility: "guild", confidence: nil,
            trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: base.createdAt, createdAtFormatted: "", isVisible: true, likeCount: 0,
            isLikedByCurrentUser: false, commentCount: 0, comments: [], isCurrentUserMarker: false,
            canEdit: false, canDelete: false, components: [], primaryComponentId: nil,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil
        )
        let markers = MarkerLinkFixtures.positioned([dto], candles: candles)
        let entry = MarkerAvatarSymbolEntry(
            authorId: author.userId,
            identity: MarkerAvatarIdentity(url: Self.avatarURL.absoluteString, initials: "PR")
        )

        let renderer = ImageRenderer(content: Probe(
            markers: markers, candles: candles, scale: scale, rotation: rotation,
            avatarIntents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: experiment),
            avatars: [entry]
        ))
        renderer.scale = renderScale
        let cgImage = try #require(renderer.cgImage)
        return measure(cgImage)
    }

    /// Bounds of the pure red and pure blue pixels, in points.
    private func measure(_ image: CGImage) -> Extent {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var extent = Extent()
        var points: [CGPoint] = []
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3]
                guard a > 250, g < 40 else { continue }
                let point = CGRect(x: CGFloat(x) / renderScale, y: CGFloat(y) / renderScale,
                                   width: 1 / renderScale, height: 1 / renderScale)
                if r > 215, b < 40 {
                    extent.red = extent.red.union(point)
                    points.append(point.origin)
                } else if b > 215, r < 40 {
                    extent.blue = extent.blue.union(point)
                    points.append(point.origin)
                }
            }
        }
        let face = extent.red.union(extent.blue)
        let centre = CGPoint(x: face.midX, y: face.midY)
        extent.farthestFromCentre = points.map { hypot($0.x - centre.x, $0.y - centre.y) }.max() ?? 0
        return extent
    }

    /// Painted at every point of the selection animation, the face fills the
    /// inner avatar circle of the disc *at that scale* — it neither overflows a
    /// disc still growing nor lags one that has grown.
    @Test(arguments: [1.0, 1.1, 1.25, 1.4, 1.5] as [CGFloat])
    func theFaceTracksTheAnimatedDisc(scale: CGFloat) throws {
        let extent = try render(scale: scale)
        let face = extent.red.union(extent.blue)
        let disc = MarkerVisualSpec.baseCanvasDiameter * scale
        let expected = MarkerVisualSpec.avatarDiameter(for: disc)

        #expect(!face.isNull)
        #expect(abs(face.width - expected) <= 1.5, "painted \(face.width)pt, expected \(expected)pt")
        #expect(abs(face.height - expected) <= 1.5)
        // Clipped to a circle inside the disc: no corner of the square picture.
        #expect(extent.farthestFromCentre <= expected / 2 + 0.75)
        #expect(extent.farthestFromCentre < disc / 2)
    }

    /// The selection wiggle turns the glyph; the face stays upright.
    @Test(arguments: [8, -6, 45] as [CGFloat])
    func theFaceStaysUprightThroughTheWiggle(rotation: CGFloat) throws {
        let extent = try render(scale: MarkerVisualSpec.selectedScale, rotation: rotation)
        #expect(!extent.red.isNull && !extent.blue.isNull)
        // Upright: the red half is entirely left of the blue half.
        #expect(extent.red.maxX <= extent.blue.minX + 1)
    }

    @Test
    func legacyIntentsKeepTheirGlyph() throws {
        let extent = try render(intent: .news, scale: 1)
        #expect(extent.red.isNull && extent.blue.isNull)
    }

    @Test
    func theExperimentOffLeavesAnalysisAsAGlyph() throws {
        let extent = try render(scale: 1, experiment: false)
        #expect(extent.red.isNull && extent.blue.isNull)
    }

    @Test
    func personalMarkersWearTheirAuthorsFaceWithTheExperimentOff() throws {
        let extent = try render(intent: .personal, scale: 1, experiment: false)
        #expect(!extent.red.isNull)
    }
}

/// The geometry the avatar prototype must not move. Stage 2 builds badges,
/// rings and arcs around these numbers; a change here is a design decision,
/// not a side effect.
struct MarkerGeometryInvariantTests {
    @Test
    func discAndSelectionSizes() {
        #expect(MarkerVisualSpec.baseCanvasDiameter == 36)
        #expect(MarkerVisualSpec.selectedScale == 1.5)
        #expect(MarkerTimeframeJumpLayout.selectedGlyphScale == MarkerVisualSpec.selectedScale)
        #expect(MarkerAvatarLayout.symbolDiscDiameter == 54)
    }

    @Test
    func stackingAndHitTargets() {
        #expect(MarkerPositionCalculator.hitRadius == 28)
        #expect(MarkerPositionCalculator.hardMinimumStackSpacing == 40)
        #expect(MarkerStackLayout.selectionNudge == 10)
    }

    @Test
    func theFaceIsAlwaysInsideTheDisc() {
        for step in 0...50 {
            let scale = 1 + CGFloat(step) / 100
            let disc = MarkerVisualSpec.baseCanvasDiameter * scale
            let rect = MarkerAvatarLayout.avatarRect(center: .zero, discDiameter: disc)
            #expect(rect.width < disc)
            #expect(rect.midX == 0 && rect.midY == 0)
        }
    }

    @Test
    func theDrawScaleMapsTheSymbolOntoTheFace() {
        let symbol = CGSize(width: MarkerAvatarLayout.symbolAvatarDiameter, height: MarkerAvatarLayout.symbolAvatarDiameter)
        #expect(abs(MarkerAvatarLayout.drawScale(symbolSize: symbol, discDiameter: 54) - 1) < 0.0001)
        let resting = MarkerAvatarLayout.drawScale(symbolSize: symbol, discDiameter: 36)
        #expect(abs(resting * symbol.width - MarkerVisualSpec.avatarDiameter(for: 36)) < 0.0001)
        #expect(MarkerAvatarLayout.drawScale(symbolSize: .zero, discDiameter: 36) == 0)
    }
}
