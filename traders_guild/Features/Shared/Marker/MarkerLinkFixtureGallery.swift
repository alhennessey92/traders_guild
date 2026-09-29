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
//  Reached by launching with `-MarkerLinkFixtures`; compiled only into Debug
//  and the isolated DEV configurations (so it runs in the optimised
//  DevProfile build too), and never linked from any shipping surface.
//
//  Review launch arguments, all optional:
//    -MarkerFixtureScene <key>      open a case (see `FixtureCase.key`)
//    -MarkerFixtureSelect <n>       select fixture marker n (0 = none)
//    -MarkerFixtureScale <1.0-1.5>  the selected glyph's scale
//    -MarkerFixtureRotation <deg>   the selection wiggle's angle
//    -TGAvatarMarkersExperiment YES the avatar prototype (isolated DEV only)
//

#if DEBUG || TG_ISOLATED_DEV

import SwiftUI

/// Synthetic markers shaped like the cases that matter.
enum MarkerLinkFixtures {

    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    static func member(_ n: Int, username: String, avatarUrl: String? = nil) -> RLGuildMemberDTO {
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
            avatarUrl: avatarUrl ?? MarkerAvatarFixtureImages.defaultURL(forUsername: username),
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
    static func positioned(_ dtos: [RLChartMarkerDTO], candles: [RLCandleDTO] = MarkerLinkFixtures.candles()) -> [ChartMarkerUI] {
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
    @State private var selectedCase: FixtureCase = FixtureCase.launchCase ?? .parentUnrelatedResponse
    @State private var focusEnabled = true
    @State private var revealProgress: CGFloat = 1
    @State private var avatarsEnabled = MarkerAvatarExperiment.isEnabled
    @State private var selectedId: UUID?
    @State private var selectionScale: CGFloat = FixtureCase.launchScale ?? MarkerVisualSpec.selectedScale
    @State private var selectionRotation: CGFloat = FixtureCase.launchRotation ?? 0
    @State private var scene: MarkerFixtureScene?
    @StateObject private var avatarSymbols = MarkerAvatarSymbolStore(
        avatarIntents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: MarkerAvatarExperiment.isEnabled)
    )

    enum FixtureCase: String, CaseIterable, Identifiable {
        case parentUnrelatedResponse = "Parent → unrelated → response"
        case oppositeStacks = "Opposite stacks"
        case allRelationships = "All three relationships"
        case dense = "Dense chart"
        case avatarIntents = "Analysis · Question · Setup"
        case authors = "Repeated and distinct authors"
        case sameCandle = "Same-candle stacks"
        case adjacent = "Adjacent-candle stacks"
        case zoomedOut = "Zoomed out"
        case edges = "Chart edges"
        case setupStates = "Setup: untracked / armed / live / TP / SL"
        case avatarStates = "Avatar states"
        case mixedLegacy = "Mixed with legacy markers"

        var id: String { rawValue }

        /// Stable name for `-MarkerFixtureScene`.
        var key: String {
            switch self {
            case .parentUnrelatedResponse: return "parentUnrelatedResponse"
            case .oppositeStacks: return "oppositeStacks"
            case .allRelationships: return "relationships"
            case .dense: return "dense"
            case .avatarIntents: return "intents"
            case .authors: return "authors"
            case .sameCandle: return "sameCandle"
            case .adjacent: return "adjacent"
            case .zoomedOut: return "zoomedOut"
            case .edges: return "edges"
            case .setupStates: return "setupStates"
            case .avatarStates: return "avatarStates"
            case .mixedLegacy: return "mixedLegacy"
            }
        }

        var scene: MarkerFixtureScene {
            switch self {
            case .parentUnrelatedResponse: return MarkerFixtureScene(markers: MarkerLinkFixtures.parentUnrelatedResponse())
            case .oppositeStacks: return MarkerFixtureScene(markers: MarkerLinkFixtures.oppositeStacks())
            case .allRelationships: return MarkerFixtureScene(markers: MarkerLinkFixtures.allRelationships())
            case .dense: return MarkerFixtureScene(markers: MarkerLinkFixtures.denseChart())
            case .avatarIntents: return MarkerLinkFixtures.avatarIntents()
            case .authors: return MarkerLinkFixtures.repeatedAndDistinctAuthors()
            case .sameCandle: return MarkerLinkFixtures.sameCandleStacks()
            case .adjacent: return MarkerLinkFixtures.adjacentCandleStacks()
            case .zoomedOut: return MarkerLinkFixtures.zoomedOut()
            case .edges: return MarkerLinkFixtures.chartEdges()
            case .setupStates: return MarkerLinkFixtures.setupStates()
            case .avatarStates: return MarkerLinkFixtures.avatarStates()
            case .mixedLegacy: return MarkerLinkFixtures.mixedLegacy()
            }
        }

        static var launchCase: FixtureCase? {
            let key = UserDefaults.standard.string(forKey: "MarkerFixtureScene")
            return allCases.first { $0.key == key }
        }

        /// `nil` when not given; `.some(nil)` for `0`, meaning no selection.
        static var launchSelection: UUID?? {
            guard UserDefaults.standard.object(forKey: "MarkerFixtureSelect") != nil else { return nil }
            let n = UserDefaults.standard.integer(forKey: "MarkerFixtureSelect")
            return .some(n > 0 ? MarkerLinkFixtures.uuid(n) : nil)
        }

        static var launchScale: CGFloat? {
            guard UserDefaults.standard.object(forKey: "MarkerFixtureScale") != nil else { return nil }
            let value = CGFloat(UserDefaults.standard.double(forKey: "MarkerFixtureScale"))
            return min(max(value, 1), MarkerVisualSpec.selectedScale)
        }

        static var launchRotation: CGFloat? {
            guard UserDefaults.standard.object(forKey: "MarkerFixtureRotation") != nil else { return nil }
            return CGFloat(UserDefaults.standard.double(forKey: "MarkerFixtureRotation"))
        }
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
        .onAppear { load(selectedCase, isLaunch: true) }
        .onChange(of: selectedCase) { _, newCase in load(newCase, isLaunch: false) }
        .onChange(of: avatarsEnabled) { _, enabled in
            avatarSymbols.avatarIntents = MarkerAvatarPresentation.avatarIntents(experimentEnabled: enabled)
        }
    }

    /// Show a case: its markers, its selection, and the avatar directory it
    /// assumes — applied to the real shared directory, so the chart refreshes
    /// through the same observation the app uses.
    private func load(_ fixtureCase: FixtureCase, isLaunch: Bool) {
        let next = fixtureCase.scene
        scene = next
        if isLaunch, let launchSelection = FixtureCase.launchSelection {
            selectedId = launchSelection
        } else {
            selectedId = next.selectedId
        }
        let directory = MemberAvatarDirectory.shared
        directory.clear()
        for (userId, url) in next.directory {
            directory.note(userId: userId, avatarURL: url.isEmpty ? nil : url)
        }
        avatarSymbols.update(markers: next.markers)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Marker fixtures")
                .font(.headline)
                .foregroundColor(AppColors.primaryForeground)
            Picker("Case", selection: $selectedCase) {
                ForEach(FixtureCase.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            if MarkerAvatarExperiment.isAvailable {
                Toggle("Avatar markers experiment (saved)", isOn: $avatarsEnabled)
                    .disabled(MarkerAvatarExperiment.hasLaunchOverride)
                    .onChange(of: avatarsEnabled) { _, enabled in
                        #if TG_ISOLATED_DEV
                        if !MarkerAvatarExperiment.hasLaunchOverride {
                            MarkerAvatarExperiment.setPersisted(enabled)
                        }
                        #endif
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            Toggle("Focus active", isOn: $focusEnabled)
                .font(.caption)
                .foregroundColor(AppColors.greyText)
            HStack {
                Text(String(format: "Selected scale %.2f", selectionScale))
                Slider(value: $selectionScale, in: 1...MarkerVisualSpec.selectedScale)
            }
            .font(.caption)
            .foregroundColor(AppColors.greyText)
            HStack {
                Text(String(format: "Wiggle %.0f°", selectionRotation))
                Slider(value: $selectionRotation, in: -8...8, step: 1)
                Button("Clear selection") { selectedId = nil }
            }
            .font(.caption)
            .foregroundColor(AppColors.greyText)
            if selectedCase == .avatarStates {
                avatarDirectoryControls
            }
        }
    }

    /// Change or remove an author's avatar after the markers were fetched, as
    /// a profile edit elsewhere in the app would.
    private var avatarDirectoryControls: some View {
        let changed = MarkerLinkFixtures.uuid(400 + MarkerLinkFixtures.changedAuthorNumber)
        let removed = MarkerLinkFixtures.uuid(400 + MarkerLinkFixtures.removedAuthorNumber)
        return HStack(spacing: 12) {
            Button("Rae: next picture") {
                let current = MemberAvatarDirectory.shared.resolved(userId: changed, fallback: nil) ?? ""
                let next = current.hasSuffix("rae-after.png") ? "rae-later" : "rae-after"
                MemberAvatarDirectory.shared.note(userId: changed, avatarURL: MarkerAvatarFixtureImages.url(for: next))
            }
            Button("Ivy: toggle removal") {
                let current = MemberAvatarDirectory.shared.resolved(userId: removed, fallback: "snapshot")
                MemberAvatarDirectory.shared.note(
                    userId: removed,
                    avatarURL: current == nil ? MarkerAvatarFixtureImages.url(for: "ivy-new") : nil
                )
            }
        }
        .font(.caption)
    }

    // MARK: Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Chart — tap a marker to select it")
            if let scene {
                MarkerLinkFixtureCanvas(
                    markers: scene.markers,
                    candles: scene.candles,
                    selectedId: selectedId,
                    focusEnabled: focusEnabled,
                    revealProgress: revealProgress,
                    selectedMarkerScale: selectionScale,
                    selectedMarkerRotation: selectionRotation,
                    avatarIntents: MarkerAvatarPresentation.avatarIntents(experimentEnabled: avatarsEnabled),
                    avatarSymbols: avatarSymbols.entries,
                    onSelect: { selectedId = $0 }
                )
                // Tall enough for a four-deep stack above a candle and a
                // three-deep one below without the viewport clamp piling them.
                .frame(height: 520)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(AppColors.chartPanelBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.surfaceGray20, lineWidth: 1)
                )
            }
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
                parentIntent: .setup,
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
    var candles: [RLCandleDTO] = MarkerLinkFixtures.candles()
    let selectedId: UUID?
    let focusEnabled: Bool
    let revealProgress: CGFloat
    var selectedMarkerScale: CGFloat = MarkerVisualSpec.selectedScale
    var selectedMarkerRotation: CGFloat = 0
    var avatarIntents: Set<RLMarkerIntent> = MarkerAvatarPresentation.avatarIntents(experimentEnabled: false)
    var avatarSymbols: [MarkerAvatarSymbolEntry] = []
    var onSelect: ((UUID?) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var graph: MarkerLinkGraph {
        MarkerLinkGraph(nodes: markers.map(\.linkNode))
    }

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let geometry = layout(size: size)
                drawContextCandles(context: context, size: size, geometry: geometry)

                ChartMarkerSystem.drawMarkers(
                    context: context,
                    markers: markers,
                    candles: candles,
                    chartSize: size,
                    priceRange: geometry.priceRange,
                    priceScale: 1,
                    verticalOffset: 0,
                    totalCandleWidth: geometry.totalCandleWidth,
                    actualCandleWidth: geometry.totalCandleWidth * 0.7,
                    totalOffset: 0,
                    selectedMarkerId: selectedId,
                    selectedMarkerScale: selectedMarkerScale,
                    selectedMarkerRotation: selectedMarkerRotation,
                    linkRender: renderContext(size: size),
                    // The harness exists to review the decorated states, so the
                    // capability is on; the disabled state is covered by tests.
                    linkedMarkersEnabled: true,
                    avatarIntents: avatarIntents
                )
            } symbols: {
                // The same symbol content the chart registers.
                MarkerCanvasSymbols.content(avatars: avatarSymbols)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                onSelect?(hitMarkerId(at: location, size: proxy.size))
            }
        }
    }

    private struct Layout {
        let priceRange: (min: Double, max: Double)
        let totalCandleWidth: CGFloat
    }

    private func layout(size: CGSize) -> Layout {
        Layout(
            priceRange: priceRange(),
            totalCandleWidth: size.width / CGFloat(max(candles.count, 1))
        )
    }

    /// Faint candles for context only; the markers are the subject.
    private func drawContextCandles(context: GraphicsContext, size: CGSize, geometry: Layout) {
        let span = geometry.priceRange.max - geometry.priceRange.min
        guard span > 0 else { return }
        func y(_ price: Double) -> CGFloat {
            size.height - CGFloat((price - geometry.priceRange.min) / span) * size.height
        }
        let bodyWidth = max(1, geometry.totalCandleWidth * 0.7)
        for (index, candle) in candles.enumerated() {
            let x = CGFloat(index) * geometry.totalCandleWidth
            let centerX = x + bodyWidth / 2
            let color = (candle.close >= candle.open ? AppColors.statusPositive : AppColors.statusNegative).opacity(0.35)
            context.stroke(
                Path { $0.move(to: CGPoint(x: centerX, y: y(candle.high))); $0.addLine(to: CGPoint(x: centerX, y: y(candle.low))) },
                with: .color(color), lineWidth: 1
            )
            let top = y(max(candle.open, candle.close))
            let bottom = y(min(candle.open, candle.close))
            context.fill(Path(CGRect(x: x, y: top, width: bodyWidth, height: max(1, bottom - top))), with: .color(color))
        }
    }

    /// Selection through the production hit test, with the geometry drawn.
    private func hitMarkerId(at location: CGPoint, size: CGSize) -> UUID? {
        let geometry = layout(size: size)
        let focusIds = renderContext(size: size)?.focus.memberIds ?? []
        return ChartMarkerSystem.findMarkerAtLocation(
            location,
            markers: markers,
            candles: candles,
            chartSize: size,
            priceRange: geometry.priceRange,
            priceScale: 1,
            verticalOffset: 0,
            totalCandleWidth: geometry.totalCandleWidth,
            actualCandleWidth: geometry.totalCandleWidth * 0.7,
            totalOffset: 0,
            selectedMarkerId: selectedId,
            selectedMarkerScale: selectedMarkerScale,
            focusMemberIds: focusIds,
            plotRect: CGRect(origin: .zero, size: size)
        )?.id
    }

    private func renderContext(size: CGSize) -> MarkerLinkRenderContext? {
        guard focusEnabled, let selectedId else { return nil }
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
        let floor = hasBelowStack ? low - (high - low) * 2.4 : low
        return (floor, high + (high - low) * 2.4)
    }
}

#endif
