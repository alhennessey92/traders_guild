//
//  MarkerLinkFixtureGallery.swift
//  traders_guild
//
//  DEBUG-only visual harness for linked markers.
//
//  Renders the real chart marker canvas and the real linked-detail views
//  against synthetic data, with no backend, no auth and no network. It exists so
//  the visual rules that geometry tests can only assert numerically — legibility
//  in a dense stack, contrast at 0.22, Dynamic Type, Reduce Motion — can
//  actually be looked at.
//
//  Reached by launching with `-MarkerLinkFixtures`; never compiled into a
//  Release build, and never linked from any shipping surface.
//

#if DEBUG

import SwiftUI

/// Synthetic markers shaped like the cases that matter.
enum MarkerLinkFixtures {

    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    static func member(_ n: Int, username: String) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: uuid(500 + n),
            role: "member",
            reputation: 120,
            contributionScore: 40,
            dateJoined: Date(timeIntervalSinceReferenceDate: 0),
            accuracyRate: 0.62,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: uuid(400 + n),
            username: username,
            displayName: username.capitalized,
            avatarUrl: nil,
            isOnline: true,
            globalReputation: 300,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
    }

    static func marker(
        _ n: Int,
        author: String,
        intent: RLMarkerIntent,
        candle: Date,
        price: Double,
        title: String?,
        parent: Int? = nil,
        relationship: String? = nil,
        responses: Int = 0,
        likes: Int = 0,
        parentPreview: RLMarkerLinkPreviewDTO? = nil
    ) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: uuid(n),
            symbolId: uuid(1),
            guildId: uuid(2),
            author: member(n, username: author),
            candleTimestamp: candle,
            timeframe: "1h",
            price: price,
            intent: intent.rawValue,
            title: title,
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: false,
            trackingState: nil,
            alertSeverity: nil,
            createdAt: candle.addingTimeInterval(Double(n) * 60),
            createdAtFormatted: "just now",
            isVisible: true,
            likeCount: likes,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: false,
            canEdit: false,
            canDelete: false,
            components: [],
            primaryComponentId: nil,
            pollQuestion: nil,
            pollOptions: nil,
            userPollVote: nil,
            predictionResult: nil,
            parentMarkerId: parent.map(uuid),
            linkRelationship: relationship,
            parentPreview: parentPreview,
            directResponseCount: responses
        )
    }

    static func preview(
        _ n: Int,
        author: String?,
        title: String?,
        relationship: String?,
        parentKey: String? = nil,
        depth: Int = 0,
        responses: Int = 0,
        unavailable: Bool = false
    ) -> RLMarkerLinkPreviewDTO {
        RLMarkerLinkPreviewDTO(
            nodeKey: "n\(n)",
            parentKey: parentKey,
            markerId: unavailable ? nil : uuid(n),
            linkRelationship: relationship,
            isUnavailable: unavailable,
            authorDisplayName: unavailable ? nil : author?.capitalized,
            authorUsername: unavailable ? nil : author,
            symbolId: unavailable ? nil : uuid(1),
            ticker: unavailable ? nil : "BTC",
            timeframe: unavailable ? nil : "1h",
            candleTimestamp: unavailable ? nil : Date(timeIntervalSinceReferenceDate: 0),
            price: unavailable ? nil : 64_000,
            intent: unavailable ? nil : RLMarkerIntent.analysis.rawValue,
            title: unavailable ? nil : title,
            directResponseCount: responses,
            depth: depth
        )
    }

    static let baseCandle = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// The case the whole design turns on: a parent, an unrelated marker from
    /// someone else, and a response — all on one candle, which is what
    /// parent-candle seeding produces.
    static func parentUnrelatedResponse() -> [ChartMarkerUI] {
        let parent = marker(
            1, author: "alex", intent: .setup, candle: baseCandle, price: 64_000,
            title: "BTC breakout", responses: 2, likes: 4
        )
        let unrelated = marker(
            2, author: "sam", intent: .news, candle: baseCandle, price: 64_000,
            title: "CPI print", likes: 1
        )
        let response = marker(
            3, author: "jamie", intent: .analysis, candle: baseCandle, price: 64_000,
            title: "Agree, higher target", parent: 1, relationship: "supports"
        )
        return positioned([parent, unrelated, response])
    }

    /// One parent with all three relationship types plus a stranger.
    static func allRelationships() -> [ChartMarkerUI] {
        let parent = marker(
            1, author: "alex", intent: .setup, candle: baseCandle, price: 64_000,
            title: "BTC breakout", responses: 3, likes: 7
        )
        let supports = marker(
            2, author: "jamie", intent: .analysis, candle: baseCandle.addingTimeInterval(3600),
            price: 64_200, title: "Backing this", parent: 1, relationship: "supports"
        )
        let challenges = marker(
            3, author: "sam", intent: .setup, candle: baseCandle.addingTimeInterval(7200),
            price: 63_600, title: "Bearish instead", parent: 1, relationship: "challenges", likes: 2
        )
        let buildsOn = marker(
            4, author: "kit", intent: .analysis, candle: baseCandle.addingTimeInterval(10800),
            price: 64_800, title: "Second leg", parent: 1, relationship: "builds_on", responses: 1
        )
        let stranger = marker(
            5, author: "lee", intent: .reaction, candle: baseCandle.addingTimeInterval(5400),
            price: 63_900, title: nil
        )
        return positioned([parent, supports, challenges, buildsOn, stranger])
    }

    /// The owner's report: a parent stacked *above* a candle, its response
    /// stacked *below* the same candle, with strangers in the slots between —
    /// and the response's own response one slot further down. Every edge of
    /// the thesis must draw, none may cross a stranger, and the long one has
    /// to leave the column at once rather than bulge through the middle.
    static func oppositeStacks() -> [ChartMarkerUI] {
        let parent = marker(
            1, author: "alex", intent: .setup, candle: baseCandle, price: 64_000,
            title: "BTC breakout", responses: 1, likes: 3
        )
        let strangerAbove = marker(
            2, author: "sam", intent: .news, candle: baseCandle, price: 64_000,
            title: "CPI print", likes: 1
        )
        let strangerBelow = marker(
            3, author: "lee", intent: .reaction, candle: baseCandle, price: 64_000,
            title: nil, likes: 2
        )
        let response = marker(
            4, author: "jamie", intent: .analysis, candle: baseCandle, price: 64_000,
            title: "Agree, higher target", parent: 1, relationship: "supports", responses: 1
        )
        let grandchild = marker(
            5, author: "kit", intent: .analysis, candle: baseCandle, price: 64_000,
            title: "Next leg from here", parent: 4, relationship: "builds_on"
        )
        var laid = positioned([parent, strangerAbove, strangerBelow, response, grandchild])
        // The position calculator keeps one candle's markers on one side; the
        // real chart ends up with both sides populated over time, which is the
        // shape being reviewed here. Place the second half below explicitly.
        func place(_ n: Int, below: Bool, stack: Int) {
            guard let index = laid.firstIndex(where: { $0.id == uuid(n) }) else { return }
            laid[index].positionedBelow = below
            laid[index].stackIndex = stack
            laid[index].hasStableLayout = true
        }
        place(2, below: false, stack: 0)
        place(1, below: false, stack: 1)
        place(3, below: true, stack: 0)
        place(4, below: true, stack: 1)
        place(5, below: true, stack: 2)
        return laid
    }

    /// A crowded chart: many markers, several theses, deep stacks.
    static func denseChart() -> [ChartMarkerUI] {
        var dtos: [RLChartMarkerDTO] = []
        let intents: [RLMarkerIntent] = [.analysis, .setup, .news, .reaction, .question, .alert]

        // A focused thesis with eight responses spread over nearby candles.
        dtos.append(
            marker(1, author: "alex", intent: .setup, candle: baseCandle, price: 64_000,
                   title: "BTC breakout", responses: 8, likes: 12)
        )
        for index in 0..<8 {
            dtos.append(
                marker(
                    10 + index,
                    author: "trader\(index)",
                    intent: intents[index % intents.count],
                    candle: baseCandle.addingTimeInterval(Double(index % 3) * 3600),
                    price: 64_000 + Double(index) * 40,
                    title: "Response \(index + 1)",
                    parent: 1,
                    relationship: ["supports", "challenges", "builds_on"][index % 3],
                    likes: index % 4
                )
            )
        }
        // Plus unrelated traffic on the same candles.
        for index in 0..<10 {
            dtos.append(
                marker(
                    50 + index,
                    author: "other\(index)",
                    intent: intents[(index + 2) % intents.count],
                    candle: baseCandle.addingTimeInterval(Double(index % 4) * 3600),
                    price: 63_800 + Double(index) * 30,
                    title: nil,
                    likes: index % 3
                )
            )
        }
        return positioned(dtos)
    }

    /// Assign the same layout the chart would, so stacks and tiers are real.
    static func positioned(_ dtos: [RLChartMarkerDTO]) -> [ChartMarkerUI] {
        let candles = self.candles()
        let markers = dtos.map { dto -> ChartMarkerUI in
            let index = candles.firstIndex { $0.timestamp == dto.candleTimestamp } ?? 0
            return ChartMarkerUI(marker: dto, candleIndex: index)
        }
        return MarkerPositionCalculator.assignStablePositions(markers: markers, candles: candles)
    }

    /// Candles before the fixture markers, so the cluster lands mid-canvas
    /// rather than jammed against the left edge.
    static let leadingCandles = 4

    /// A flat-ish candle series so marker layout, not price action, is what the
    /// screenshots show.
    static func candles(count: Int = 12) -> [RLCandleDTO] {
        (0..<count).map { index in
            let offset = Double(index - leadingCandles) * 3600
            let base = 63_900 + Double((index % 5)) * 30
            return RLCandleDTO(
                timestamp: baseCandle.addingTimeInterval(offset),
                open: base,
                high: base + 120,
                low: base - 120,
                close: base + 20,
                volume: 1000
            )
        }
    }

    static func threadWindow() -> MarkerThreadWindow {
        let page = RLMarkerThreadResponseDTO(
            requestedMarkerId: uuid(3),
            rootMarkerId: uuid(1),
            rootKey: "n1",
            rootResolved: true,
            windowRootKey: "n1",
            nodes: [
                preview(1, author: "alex", title: "BTC breakout", relationship: nil, responses: 3),
                preview(2, author: "jamie", title: "Backing this", relationship: "supports",
                        parentKey: "n1", depth: 1),
                preview(3, author: "sam", title: "Bearish instead", relationship: "challenges",
                        parentKey: "n1", depth: 1, responses: 1),
                preview(6, author: nil, title: nil, relationship: "supports",
                        parentKey: "n3", depth: 2, unavailable: true),
                preview(4, author: "kit", title: "Second leg", relationship: "builds_on",
                        parentKey: "n1", depth: 1),
            ],
            branches: [RLMarkerThreadBranchDTO(nodeKey: "n1", cursor: "more")],
            totalCount: nil,
            loadedCount: 5,
            truncated: false
        )
        return MarkerThreadWindow(page: page)
    }
}

// MARK: - Gallery

/// Scrollable board of every visual case, so one screenshot covers a lot.
struct MarkerLinkFixtureGallery: View {
    @State private var selectedCase: FixtureCase = .parentUnrelatedResponse
    @State private var focusEnabled = true
    @State private var revealProgress: CGFloat = 1

    enum FixtureCase: String, CaseIterable, Identifiable {
        case parentUnrelatedResponse = "Parent → unrelated → response"
        case oppositeStacks = "Opposite stacks"
        case allRelationships = "All three relationships"
        case dense = "Dense chart"

        var id: String { rawValue }

        var markers: [ChartMarkerUI] {
            switch self {
            case .parentUnrelatedResponse: return MarkerLinkFixtures.parentUnrelatedResponse()
            case .oppositeStacks: return MarkerLinkFixtures.oppositeStacks()
            case .allRelationships: return MarkerLinkFixtures.allRelationships()
            case .dense: return MarkerLinkFixtures.denseChart()
            }
        }

        /// The marker focus is centred on — always the thesis root here.
        var selectedId: UUID { MarkerLinkFixtures.uuid(1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controls
                chartSection
                detailSection
                threadSection
                placementSection
            }
            .padding(16)
        }
        .background(AppColors.tgGradientBackground.ignoresSafeArea())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked marker fixtures")
                .font(.headline)
                .foregroundColor(AppColors.primaryForeground)
            Picker("Case", selection: $selectedCase) {
                ForEach(FixtureCase.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Focus active", isOn: $focusEnabled)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
        }
    }

    // MARK: Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Chart — focus, rings, connectors, badges")
            MarkerLinkFixtureCanvas(
                markers: selectedCase.markers,
                selectedId: selectedCase.selectedId,
                focusEnabled: focusEnabled,
                revealProgress: revealProgress
            )
            .frame(height: 420)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(AppColors.chartPanelBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.surfaceGray20, lineWidth: 1)
            )
        }
    }

    // MARK: Detail rows

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Relationship row")
            MarkerLinkRelationshipRow(
                relationship: MarkerLinkRelationshipValue(.supports),
                preview: MarkerLinkFixtures.preview(
                    1, author: "alex", title: "BTC breakout", relationship: nil
                ),
                onOpenParent: {}
            )
            MarkerLinkRelationshipRow(
                relationship: MarkerLinkRelationshipValue(.challenges),
                preview: MarkerLinkFixtures.preview(
                    1, author: "sam", title: "CPI reaction", relationship: nil
                ),
                onOpenParent: {}
            )
            MarkerLinkRelationshipRow(
                relationship: MarkerLinkRelationshipValue(raw: "partially_refutes"),
                preview: MarkerLinkFixtures.preview(
                    1, author: "kit", title: "Unknown relationship", relationship: nil
                ),
                onOpenParent: {}
            )
            MarkerLinkRelationshipRow(
                relationship: MarkerLinkRelationshipValue(.buildsOn),
                preview: MarkerLinkFixtures.preview(
                    9, author: nil, title: nil, relationship: "builds_on", unavailable: true
                ),
                onOpenParent: nil
            )
            MarkerLinkRelationshipRow(
                relationship: MarkerLinkRelationshipValue(.supports),
                preview: nil,
                onOpenParent: nil
            )
        }
    }

    // MARK: Thread

    private var threadSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("Thesis rows — indent, tombstone, current marker")
            let window = MarkerLinkFixtures.threadWindow()
            ForEach(window.displayRows()) { row in
                MarkerThreadRowView(row: row, onOpen: {})
            }
            Text(window.totalCount.displayText + " in this thesis")
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
                .padding(.top, 4)
        }
    }

    // MARK: Placement

    private var placementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Placement banner + picker")
            MarkerLinkPlacementBanner(
                context: MarkerLinkContext(
                    parentMarkerId: MarkerLinkFixtures.uuid(1),
                    parentGuildId: MarkerLinkFixtures.uuid(2),
                    parentSymbolId: MarkerLinkFixtures.uuid(1),
                    parentCandleTimestamp: MarkerLinkFixtures.baseCandle,
                    parentAuthorDisplayText: "alex",
                    parentTitle: "BTC breakout",
                    parentIntent: .setup,
                    relationship: .challenges
                ),
                failureMessage: nil,
                onChangeRelationship: {},
                onRemove: {}
            )
            MarkerLinkPlacementBanner(
                context: MarkerLinkContext(
                    parentMarkerId: MarkerLinkFixtures.uuid(1),
                    parentGuildId: MarkerLinkFixtures.uuid(2),
                    parentSymbolId: MarkerLinkFixtures.uuid(1),
                    parentCandleTimestamp: MarkerLinkFixtures.baseCandle,
                    parentAuthorDisplayText: "alex",
                    parentTitle: "BTC breakout",
                    parentIntent: .setup,
                    relationship: .supports
                ),
                failureMessage: "Placement Failed",
                onChangeRelationship: {},
                onRemove: {}
            )
            MarkerLinkRelationshipPicker(
                parentSummary: "alex's BTC breakout",
                onSelect: { _ in },
                onCancel: {}
            )
            .background(
                RoundedRectangle(cornerRadius: 12).fill(AppColors.whiteText.opacity(0.05))
            )
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.greyText)
    }
}

/// Draws the real marker layer against fixture data.
///
/// Calls `ChartMarkerSystem.drawMarkers` with a genuine
/// `MarkerLinkRenderContext`, so what appears here is what the chart draws —
/// the same rings, connectors, badges, dimming and z-order.
struct MarkerLinkFixtureCanvas: View {
    let markers: [ChartMarkerUI]
    let selectedId: UUID
    let focusEnabled: Bool
    let revealProgress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var candles: [RLCandleDTO] { MarkerLinkFixtures.candles() }

    private var graph: MarkerLinkGraph {
        MarkerLinkGraph(nodes: markers.map(\.linkNode))
    }

    var body: some View {
        Canvas { context, size in
            let priceRange = priceRange()
            let totalCandleWidth = size.width / CGFloat(max(candles.count, 1))

            ChartMarkerSystem.drawMarkers(
                context: context,
                markers: markers,
                candles: candles,
                chartSize: size,
                priceRange: priceRange,
                priceScale: 1,
                verticalOffset: 0,
                totalCandleWidth: totalCandleWidth,
                actualCandleWidth: totalCandleWidth * 0.7,
                totalOffset: 0,
                selectedMarkerId: selectedId,
                selectedMarkerScale: 1.5,
                selectedMarkerRotation: 0,
                linkRender: renderContext(size: size),
                // The harness exists to review the decorated states, so the
                // capability is on; the disabled state is covered by tests.
                linkedMarkersEnabled: true
            )
        }
    }

    private func renderContext(size: CGSize) -> MarkerLinkRenderContext? {
        guard focusEnabled else { return nil }
        let visible = Set(markers.map(\.id))
        let focus = graph.focusState(selectedId: selectedId, visibleIds: visible)
        guard focus.isActive else { return nil }

        var ringStyles: [UUID: MarkerLinkRingStyle] = [:]
        for id in focus.memberIds {
            if let style = graph.ringStyle(for: id) { ringStyles[id] = style }
        }
        return MarkerLinkRenderContext(
            focus: focus,
            ringStyles: ringStyles,
            revealProgress: reduceMotion ? 1 : revealProgress,
            plotRect: CGRect(origin: .zero, size: size)
        )
    }

    /// Deliberately lopsided headroom.
    ///
    /// Markers stack *upward* from the candle high at 70pt + 40pt per slot, and
    /// `computeMarkerScreenPosition` clamps anything that would leave the
    /// viewport — so with the candles centred, a three-deep stack piles up
    /// against the top edge and the upper markers land on top of each other.
    /// Pushing the candles into the lower third gives the stack the room the
    /// real chart has.
    private func priceRange() -> (min: Double, max: Double) {
        let lows = candles.map(\.low)
        let highs = candles.map(\.high)
        guard let low = lows.min(), let high = highs.max(), high > low else {
            return (0, 1)
        }
        // A scene with markers stacked *below* the candle needs the same room
        // underneath, or the below stack is clamped to the canvas edge and
        // piles up — which is not the geometry under review.
        let hasBelowStack = markers.contains(where: \.positionedBelow)
        let floor = hasBelowStack ? low - (high - low) * 1.8 : low
        return (floor, high + (high - low) * 2.4)
    }
}

#endif
