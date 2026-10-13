//
//  MarkerGuideView.swift
//  traders_guild
//
//  How to read a marker (owner, 12 Oct 2026). Drawn, not a picture: the
//  example at the top is the chart's own marker layer
//  (`ChartMarkerSystem.drawMarkers`) over a small sample, so the guide always
//  shows exactly what the chart draws, in every theme, and follows any change
//  to the markers without a new image.
//

import SwiftUI

// MARK: - Sample

/// A thesis, selected so its context arcs show, with a reply that supports it
/// and one that challenges it. Built from the app's own marker types; nothing
/// here is fetched or saved.
enum MarkerGuideSample {
    static let thesisId = UUID(uuidString: "6A1D3F00-0000-4000-8000-000000000001")!
    static let supportsId = UUID(uuidString: "6A1D3F00-0000-4000-8000-000000000002")!
    static let challengesId = UUID(uuidString: "6A1D3F00-0000-4000-8000-000000000003")!
    private static let symbolId = UUID(uuidString: "6A1D3F00-0000-4000-8000-0000000000A1")!
    private static let guildId = UUID(uuidString: "6A1D3F00-0000-4000-8000-0000000000A2")!
    static let otherAuthorIds = [
        UUID(uuidString: "6A1D3F00-0000-4000-8000-0000000000B1")!,
        UUID(uuidString: "6A1D3F00-0000-4000-8000-0000000000B2")!,
    ]
    static let thesisIndex = 3
    static let supportsIndex = 7
    static let challengesIndex = 10

    private static let start = Date(timeIntervalSince1970: 1_770_000_000)

    /// A gently rising series, so the thesis sits low and its replies climb
    /// away from it: the lines between them have room to read.
    static let candles: [RLCandleDTO] = (0..<12).map { index in
        let base = 63_800 + Double(index) * 28 + Double(index % 3) * 18
        return RLCandleDTO(
            timestamp: start.addingTimeInterval(Double(index) * 3600),
            open: base, high: base + 46, low: base - 40, close: base + 20, volume: nil
        )
    }

    struct Person {
        let id: UUID
        let username: String
        let avatarUrl: String?
    }

    private static let viewerFallbackId = UUID(uuidString: "6A1D3F00-0000-4000-8000-0000000000B0")!

    /// The reader, as the thesis's author: their own face is the example.
    static func viewer(_ identity: MarkerAvatarIdentity) -> Person {
        Person(id: identity.authorId ?? viewerFallbackId, username: "you", avatarUrl: identity.url)
    }

    static func markers(viewer: Person) -> [ChartMarkerUI] {
        let others = [
            Person(id: otherAuthorIds[0], username: "sam", avatarUrl: nil),
            Person(id: otherAuthorIds[1], username: "jo", avatarUrl: nil),
        ]
        let thesis = marker(
            id: thesisId, author: viewer, intent: .analysis, candleIndex: thesisIndex,
            title: "Range low holds", likes: 3, responses: 2,
            components: [.indicator, .drawingHorizontalLine, .timeframeLink]
        )
        let supports = marker(
            id: supportsId, author: others[0], intent: .analysis, candleIndex: supportsIndex,
            title: "Volume agrees", parent: thesisId, relationship: .supports
        )
        let challenges = marker(
            id: challengesId, author: others[1], intent: .question, candleIndex: challengesIndex,
            title: "What if it fails?", parent: thesisId, relationship: .challenges
        )
        let positioned = [thesis, supports, challenges].map { dto in
            ChartMarkerUI(marker: dto, candleIndex: candles.firstIndex { $0.timestamp == dto.candleTimestamp } ?? 0)
        }
        return MarkerPositionCalculator.assignStablePositions(markers: positioned, candles: candles)
    }

    static func avatarEntries(viewer: Person, identity: MarkerAvatarIdentity) -> [MarkerAvatarSymbolEntry] {
        [
            MarkerAvatarSymbolEntry(authorId: viewer.id, identity: identity),
            MarkerAvatarSymbolEntry(authorId: otherAuthorIds[0], identity: MarkerAvatarIdentity(url: nil, initials: "SA")),
            MarkerAvatarSymbolEntry(authorId: otherAuthorIds[1], identity: MarkerAvatarIdentity(url: nil, initials: "JO")),
        ]
    }

    private static func marker(
        id: UUID, author: Person, intent: RLMarkerIntent, candleIndex: Int, title: String,
        likes: Int = 0, responses: Int = 0, components types: [RLComponentType] = [],
        parent: UUID? = nil, relationship: MarkerLinkRelationship? = nil
    ) -> RLChartMarkerDTO {
        let candle = candles[candleIndex]
        let anchor = RLMarkerComponentDTO(
            id: UUID(), componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: candle.timestamp, price: candle.high)), ordering: 0
        )
        let context = types.enumerated().map { index, type in
            RLMarkerComponentDTO(id: UUID(), componentType: type.rawValue,
                                 payload: .unknown(type: type.rawValue, rawPayload: [:]), ordering: index + 1)
        }
        let member = RLGuildMemberDTO(
            membershipId: author.id, role: "member", reputation: 0, contributionScore: 0,
            dateJoined: start, accuracyRate: nil, mutedUntil: nil, suspendedUntil: nil,
            userId: author.id, username: author.username, displayName: author.username,
            avatarUrl: author.avatarUrl, isOnline: false, globalReputation: 0,
            isFriend: false, friendshipStatus: nil, isBlocked: false, isBlockedBy: false
        )
        return RLChartMarkerDTO(
            id: id, symbolId: symbolId, guildId: guildId, author: member,
            candleTimestamp: candle.timestamp, timeframe: "1h", price: candle.high,
            intent: intent.rawValue, title: title, note: nil, visibility: "guild", confidence: nil,
            trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: candle.timestamp, createdAtFormatted: "", isVisible: true,
            likeCount: likes, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: false, canEdit: false, canDelete: false,
            components: [anchor] + context, primaryComponentId: anchor.id,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: parent, linkRelationship: relationship?.rawValue, parentPreview: nil,
            directResponseCount: responses
        )
    }
}

// MARK: - The example

/// The sample, drawn by the chart's marker layer, with numbered callouts on
/// the parts the legend below explains.
struct MarkerGuideExample: View {
    let identity: MarkerAvatarIdentity

    private var viewer: MarkerGuideSample.Person { MarkerGuideSample.viewer(identity) }

    /// Callout numbers, in the order the legend reads them.
    enum Part: Int, CaseIterable {
        case face = 1, ring, badge, arcs, counts, lines
    }

    private var markers: [ChartMarkerUI] { MarkerGuideSample.markers(viewer: viewer) }

    /// The thesis is drawn selected, a little larger than the chart's own
    /// selection, so its parts are big enough to point at.
    static let heroScale: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            let layout = Layout(size: size)
            let markers = self.markers
            drawCandles(context: context, size: size, layout: layout)
            ChartMarkerSystem.drawMarkers(
                context: context,
                markers: markers,
                candles: MarkerGuideSample.candles,
                chartSize: size,
                priceRange: layout.priceRange,
                priceScale: 1,
                verticalOffset: 0,
                totalCandleWidth: layout.candleWidth,
                actualCandleWidth: layout.candleWidth * 0.7,
                totalOffset: 0,
                selectedMarkerId: MarkerGuideSample.thesisId,
                selectedMarkerScale: Self.heroScale,
                linkRender: renderContext(markers: markers, size: size),
                linkedMarkersEnabled: true,
                avatarIntents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: true)
            )
            drawCallouts(context: context, markers: markers, size: size, layout: layout)
        } symbols: {
            MarkerCanvasSymbols.content(avatars: MarkerGuideSample.avatarEntries(viewer: viewer, identity: identity))
        }
        .frame(height: 280)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An example marker with its parts numbered: the author's face, the ring, the type badge, the context arcs, the counts, and the lines to its replies.")
    }

    // MARK: Layout

    private struct Layout {
        let priceRange: (min: Double, max: Double)
        let candleWidth: CGFloat

        init(size: CGSize) {
            let lows = MarkerGuideSample.candles.map(\.low)
            let highs = MarkerGuideSample.candles.map(\.high)
            let low = lows.min() ?? 0
            let high = highs.max() ?? 1
            // Candles in the lower part, so the markers above have the room
            // the real chart gives them.
            let span = high - low
            priceRange = (low - span * 0.15, high + span * 1.35)
            candleWidth = size.width / CGFloat(MarkerGuideSample.candles.count)
        }

        func y(_ price: Double, height: CGFloat) -> CGFloat {
            height - CGFloat((price - priceRange.min) / (priceRange.max - priceRange.min)) * height
        }
    }

    private func drawCandles(context: GraphicsContext, size: CGSize, layout: Layout) {
        let bodyWidth = max(1, layout.candleWidth * 0.7)
        for (index, candle) in MarkerGuideSample.candles.enumerated() {
            let x = CGFloat(index) * layout.candleWidth
            let centerX = x + bodyWidth / 2
            let color = (candle.close >= candle.open ? AppColors.statusPositive : AppColors.statusNegative).opacity(0.3)
            context.stroke(Path { path in
                path.move(to: CGPoint(x: centerX, y: layout.y(candle.high, height: size.height)))
                path.addLine(to: CGPoint(x: centerX, y: layout.y(candle.low, height: size.height)))
            }, with: .color(color), lineWidth: 1)
            let top = layout.y(max(candle.open, candle.close), height: size.height)
            let bottom = layout.y(min(candle.open, candle.close), height: size.height)
            context.fill(Path(CGRect(x: x, y: top, width: bodyWidth, height: max(1, bottom - top))), with: .color(color))
        }
    }

    private func renderContext(markers: [ChartMarkerUI], size: CGSize) -> MarkerLinkRenderContext? {
        let graph = MarkerLinkGraph(nodes: markers.map(\.linkNode))
        let focus = graph.focusState(selectedId: MarkerGuideSample.thesisId, visibleIds: Set(markers.map(\.id)))
        guard focus.isActive else { return nil }
        var ringStyles: [UUID: MarkerLinkRingStyle] = [:]
        for id in focus.memberIds {
            if let style = graph.ringStyle(for: id) { ringStyles[id] = style }
        }
        return MarkerLinkRenderContext(focus: focus, ringStyles: ringStyles, revealProgress: 1,
                                       plotRect: CGRect(origin: .zero, size: size))
    }

    /// Where the chart puts a marker, by the same calculation it draws with.
    private func position(of marker: ChartMarkerUI, size: CGSize, layout: Layout) -> CGPoint {
        let candle = MarkerGuideSample.candles[marker.candleIndex]
        return MarkerPositionCalculator.computeMarkerScreenPosition(
            marker: marker,
            candleHighY: layout.y(candle.high, height: size.height),
            candleLowY: layout.y(candle.low, height: size.height),
            centerX: CGFloat(marker.candleIndex) * layout.candleWidth + layout.candleWidth * 0.35,
            priceScale: 1,
            viewportHeight: size.height
        )
    }

    // MARK: Callouts

    private func drawCallouts(context: GraphicsContext, markers: [ChartMarkerUI], size: CGSize, layout: Layout) {
        guard let thesis = markers.first(where: { $0.id == MarkerGuideSample.thesisId }),
              let supports = markers.first(where: { $0.id == MarkerGuideSample.supportsId }) else { return }
        let center = position(of: thesis, size: size, layout: layout)
        let scale = Self.heroScale
        let radius = MarkerVisualSpec.baseCanvasDiameter / 2 * scale
        let badge = MarkerIntentBadge.paletteRect(center: center, isBelow: thesis.positionedBelow, scale: scale)
        let like = MarkerLinkRenderer.likeBadgeRect(center: center, isBelow: thesis.positionedBelow, scale: scale)
        let reply = position(of: supports, size: size, layout: layout)
        let replyRadius = MarkerVisualSpec.baseCanvasDiameter / 2
        let arcRadius = radius + 6

        // Each target, and where its number sits: around the marker, clear of
        // its badges and the lines leaving it.
        let lineTarget = CGPoint(x: reply.x - replyRadius - 10, y: reply.y - 1)
        let pins: [(Part, CGPoint, CGPoint)] = [
            (.face, CGPoint(x: center.x - radius * 0.5, y: center.y + radius * 0.2),
             CGPoint(x: center.x - radius - 34, y: center.y + 6)),
            (.ring, CGPoint(x: center.x, y: center.y + radius),
             CGPoint(x: center.x - 8, y: center.y + radius + 34)),
            (.badge, CGPoint(x: badge.midX, y: badge.minY),
             CGPoint(x: badge.midX + 10, y: badge.minY - 26)),
            (.arcs, CGPoint(x: center.x - arcRadius * 0.62, y: center.y - arcRadius * 0.78),
             CGPoint(x: center.x - radius - 22, y: center.y - radius - 26)),
            (.counts, CGPoint(x: like.maxX, y: like.midY),
             CGPoint(x: like.maxX + 24, y: like.maxY + 22)),
            (.lines, lineTarget, CGPoint(x: lineTarget.x - 6, y: lineTarget.y + 40)),
        ]
        for (part, target, label) in pins {
            let label = CGPoint(x: min(max(label.x, 12), size.width - 12), y: min(max(label.y, 12), size.height - 12))
            context.stroke(Path { path in
                path.move(to: label)
                path.addLine(to: target)
            }, with: .color(AppColors.primaryForeground.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            context.fill(Path(ellipseIn: CGRect(x: target.x - 2.5, y: target.y - 2.5, width: 5, height: 5)),
                         with: .color(AppColors.primaryForeground))
            let disc = CGRect(x: label.x - 10, y: label.y - 10, width: 20, height: 20)
            context.fill(Path(ellipseIn: disc), with: .color(AppColors.primaryForeground))
            context.draw(
                Text("\(part.rawValue)").font(.system(size: 11, weight: .heavy)).foregroundColor(AppColors.sheetBackground),
                at: label
            )
        }
    }
}


// MARK: - The guide

/// How to read a marker: the example, then each part in turn.
struct MarkerGuideView: View {
    let identity: MarkerAvatarIdentity
    var onClose: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 10)
            Rectangle()
                .fill(AppColors.whiteText.opacity(0.08))
                .frame(height: 1)
                .accessibilityHidden(true)
            ScrollView { content }
        }
        .background(AppColors.sheetBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("markerGuide")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Every mark on the chart is a person. Here is how to read one.")
                .font(.subheadline)
                .foregroundColor(AppColors.overlayPanelSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, -8)
            MarkerGuideExample(identity: identity)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.whiteText.opacity(0.04)))
            partsLegend
            section("What it is", subtitle: "The ring and badge say what kind of post it is.") { typesGrid }
            section("Context arcs", subtitle: "Tap a marker and arcs show what's attached to it.") { arcsLegend }
            section("Alerts", subtitle: "An alert's badge and colour show how urgent it is.") { alertsGrid }
            section("Setups", subtitle: "A tracked Setup's badge follows the trade.") { setupsGrid }
            section("Replies", subtitle: "Lines join a reply to the marker it answers, in how it relates.") { repliesLegend }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 28)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("How markers work")
                .font(.title2.weight(.bold))
                .foregroundColor(AppColors.primaryForeground)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.primaryForeground)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.whiteText.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("markerGuide.close")
            }
        }
    }

    private var partsLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            legendRow(1, "Face", "Who posted it. Every marker is a person.")
            legendRow(2, "Ring", "Its colour is the kind of post: teal Analysis, blue Question, purple Poll, green Setup, and an alert's urgency.")
            legendRow(3, "Badge", "The type at a glance, in its own colours.")
            legendRow(4, "Arcs", "When selected: what is attached. Orange indicators, purple drawings and levels, cyan timeframes and links.")
            legendRow(5, "Counts", "Red counts likes. Grey counts the replies to it.")
            legendRow(6, "Lines", "Join it to its replies: green supports, red challenges, teal builds on. A reply's own badge says the same.")
        }
    }

    private func legendRow(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(AppColors.sheetBackground)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppColors.primaryForeground))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold)).foregroundColor(AppColors.primaryForeground)
                Text(text).font(.subheadline).foregroundColor(AppColors.overlayPanelSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func section<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.primaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count)
    }

    private func sample(_ intent: RLMarkerIntent, severity: MarkerAlertSeverity? = nil,
                        status: MarkerIntentBadge.SetupStatus = .unknown, label: String, detail: String? = nil) -> some View {
        var face = identity
        face.setupStatus = status
        return VStack(spacing: 6) {
            UnifiedMarkerBadge(intent: intent, alertSeverity: severity, size: 48, avatar: face)
                .padding(6)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.primaryForeground)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(AppColors.overlayPanelSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var typesGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            sample(.analysis, label: "Analysis", detail: "What you see")
            sample(.question, label: "Question", detail: "Ask the guild")
            sample(.poll, label: "Poll", detail: "Let them vote")
            sample(.alert, severity: .moderate, label: "Alert", detail: "Flag an area")
            sample(.setup, status: .armed, label: "Setup", detail: "A planned trade")
        }
    }

    /// All four on one row, least to most urgent, where the text size allows.
    private var alertsGrid: some View {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: count),
                         spacing: 14) {
            ForEach([MarkerAlertSeverity.mild, .moderate, .severe, .critical], id: \.self) { severity in
                sample(.alert, severity: severity, label: severity.displayLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var setupsGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            sample(.setup, status: .untracked, label: "Not tracked")
            sample(.setup, status: .armed, label: "Tracking", detail: "Waiting for entry")
            sample(.setup, status: .active, label: "Active", detail: "In the trade")
            sample(.setup, status: .takeProfit, label: "Target hit")
            sample(.setup, status: .stopLoss, label: "Stopped out")
            sample(.setup, status: .expired, label: "Expired")
        }
    }

    private var arcsLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            arcRow(.indicators, "Indicators", "Moving averages, RSI and the like")
            arcRow(.drawings, "Drawings and levels", "Lines, zones, support and resistance")
            arcRow(.timeframesAndLinks, "Timeframes and links", "Other timeframes, and a source")
        }
    }

    private func arcRow(_ category: MarkerComponentArcs.Category, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Canvas { context, size in
                var path = Path()
                path.addArc(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: size.width / 2 - 2,
                            startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                context.stroke(path, with: .color(category.color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(AppColors.primaryForeground)
                Text(detail).font(.caption).foregroundColor(AppColors.overlayPanelSecondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var repliesLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MarkerLinkRelationship.allCases, id: \.self) { relationship in
                HStack(spacing: 12) {
                    Canvas { context, size in
                        var path = Path()
                        path.move(to: CGPoint(x: 2, y: size.height / 2))
                        path.addLine(to: CGPoint(x: size.width - 2, y: size.height / 2))
                        context.stroke(path, with: .color(relationship.accentColor),
                                       style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: relationship.dashPattern))
                    }
                    .frame(width: 40, height: 14)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(relationship.displayName).font(.subheadline.weight(.semibold))
                            .foregroundColor(relationship.accentColor)
                        Text(relationship.pickerSubtitle).font(.caption)
                            .foregroundColor(AppColors.overlayPanelSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
