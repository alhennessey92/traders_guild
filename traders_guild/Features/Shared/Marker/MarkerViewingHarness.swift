//
//  MarkerViewingHarness.swift
//  traders_guild
//
//  Backend-free fixture for the marker detail sheet's General tab, so the v1.5
//  refined viewing layout can be looked at without an account or network.
//
//  Renders the real `MarkerViewingGeneralTab` over fixture markers in a
//  `MarkerManager` that never loads. Nothing here writes app state, the
//  keychain or the network; Respond, Share, Edit and the author face only
//  report that they were tapped.
//
//  Launch: `-MarkerViewingFixture <scenario> [-TGAvatarMarkersExperiment YES]`
//  (see `Scenario`). Debug and isolated-DEV builds only.
//

#if DEBUG || TG_ISOLATED_DEV

import SwiftUI

struct MarkerViewingHarness: View {
    enum Scenario: String, CaseIterable {
        /// Another member's Analysis with a title, text and context.
        case analysis
        /// A Question that answers another marker.
        case response
        /// A live, tracked Setup.
        case setup
        /// The viewer's own Analysis: Edit and Delete.
        case own
        /// Another member's Poll with votes, one of them the viewer's.
        case poll
        /// Another member's Severe Alert.
        case alert

        static var launch: Scenario? {
            UserDefaults.standard.string(forKey: "MarkerViewingFixture").flatMap(Scenario.init(rawValue:))
        }
    }

    let scenario: Scenario
    @State private var markerManager: MarkerManager
    @State private var lastAction = "—"

    init(scenario: Scenario) {
        self.scenario = scenario
        let viewer = MarkerLinkFixtures.member(9, username: "you")
        let manager = MarkerManager(userId: viewer.userId, guildId: MarkerLinkFixtures.uuid(2), currentUserMember: viewer)
        manager.linkedMarkersEnabled = true
        manager.markers = MarkerLinkFixtures.positioned([Self.marker(for: scenario)])
        _markerManager = State(initialValue: manager)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Fixture · \(scenario.rawValue) · last tap: \(lastAction)")
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .dynamicTypeSize(...DynamicTypeSize.large)
            if let marker = markerManager.markers.first {
                MarkerViewingGeneralTab(
                    marker: marker,
                    markerManager: markerManager,
                    onClose: {},
                    onAuthorTap: { lastAction = "author" },
                    canEditMarker: scenario == .own,
                    onEditMarker: { _ in lastAction = "edit" },
                    onShareMarker: { lastAction = "share" },
                    onRespondToMarker: { relationship in lastAction = "respond \(relationship.rawValue)" },
                    onOpenLinkedMarker: { _ in lastAction = "open parent" },
                    fixtureViewerContext: (guildId: MarkerLinkFixtures.uuid(2), symbolId: MarkerLinkFixtures.uuid(1))
                )
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .fill(AppColors.sheetBackground)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .background(AppColors.tgGradientBackground.ignoresSafeArea())
    }

    // MARK: Markers

    private static let candle = MarkerLinkFixtures.candles()[6]

    private static func level(_ type: RLComponentType, _ price: Double, order: Int) -> RLMarkerComponentDTO {
        let payload = LevelPayload(price: price, label: nil, colorHex: nil, lineStyle: nil, lineWidth: nil)
        let typed: MarkerComponentPayload
        switch type {
        case .levelEntry: typed = .levelEntry(payload)
        case .levelTp: typed = .levelTp(payload)
        default: typed = .levelSl(payload)
        }
        return RLMarkerComponentDTO(id: MarkerLinkFixtures.uuid(9_000 + order), componentType: type.rawValue,
                                    payload: typed, ordering: order)
    }

    private static func marker(for scenario: Scenario) -> RLChartMarkerDTO {
        let isOwn = scenario == .own
        let author = isOwn
            ? MarkerLinkFixtures.member(9, username: "you")
            : MarkerLinkFixtures.member(2, username: "sam")
        let intent: RLMarkerIntent
        var title: String?
        var note: String?
        var components = MarkerLinkFixtures.fixtureComponents([.indicator, .levelSupport], marker: 1)
        var trackingEnabled = false
        var trackingState: String?
        var parent: UUID?
        var relationship: String?
        var preview: RLMarkerLinkPreviewDTO?
        var pollQuestion: String?
        var pollOptions: [RLPollOptionDTO]?
        var userPollVote: UUID?
        switch scenario {
        case .analysis, .own:
            intent = .analysis
            title = "Higher lows into the open"
            note = "Sellers stalled at the 63.8k shelf three times. As long as that holds, I expect a push back to the range high."
        case .response:
            intent = .question
            title = "Is the range high still the target?"
            note = "Volume is fading on each push. Does anyone see a reason this doesn't fail at 64.4k?"
            parent = MarkerLinkFixtures.uuid(77)
            relationship = "challenges"
            preview = MarkerLinkFixtures.preview(77, author: "alex", title: "Breakout to 65k", relationship: nil)
            components = []
        case .setup:
            intent = .setup
            title = "Long the range-low retest"
            note = "Invalidated below the shelf."
            trackingEnabled = true
            trackingState = RLTrackingState.active.rawValue
            components = [
                level(.levelEntry, 63_920, order: 0),
                level(.levelTp, 64_400, order: 1),
                level(.levelSl, 63_700, order: 2),
            ]
        case .poll:
            intent = .poll
            title = "Which target gets hit first?"
            pollQuestion = title
            note = nil
            components = []
            let voted = MarkerLinkFixtures.uuid(9_102)
            pollOptions = [
                RLPollOptionDTO(id: MarkerLinkFixtures.uuid(9_101), text: "Range high, 64.4k", voteCount: 7, hasVoted: false),
                RLPollOptionDTO(id: voted, text: "Range low, 63.2k", voteCount: 4, hasVoted: true),
                RLPollOptionDTO(id: MarkerLinkFixtures.uuid(9_103), text: "Neither this session", voteCount: 1, hasVoted: false),
            ]
            userPollVote = voted
        case .alert:
            intent = .alert
            title = "Liquidity sweep below Asia"
            note = "[Severe] Stops under 63.5k got run on rising volume. Watch for a reclaim before trusting longs."
            components = MarkerLinkFixtures.fixtureComponents([.drawingZone], marker: 1)
        }
        return RLChartMarkerDTO(
            id: MarkerLinkFixtures.uuid(1), symbolId: MarkerLinkFixtures.uuid(1), guildId: MarkerLinkFixtures.uuid(2),
            author: author, candleTimestamp: candle.timestamp, timeframe: "1h", price: candle.close,
            intent: intent.rawValue, title: title, note: note, visibility: "guild", confidence: nil,
            trackingEnabled: trackingEnabled, trackingState: trackingState, alertSeverity: nil,
            createdAt: Date().addingTimeInterval(-2 * 3600), createdAtFormatted: "2h ago", isVisible: true,
            likeCount: 4, isLikedByCurrentUser: false, commentCount: 2, comments: [],
            isCurrentUserMarker: isOwn, canEdit: isOwn, canDelete: isOwn,
            components: components, primaryComponentId: nil,
            pollQuestion: pollQuestion, pollOptions: pollOptions, userPollVote: userPollVote, predictionResult: nil,
            parentMarkerId: parent, linkRelationship: relationship, parentPreview: preview,
            directResponseCount: scenario == .analysis ? 2 : 0
        )
    }
}

#endif
