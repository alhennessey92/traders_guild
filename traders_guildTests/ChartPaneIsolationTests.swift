import Foundation
import Testing
@testable import traders_guild

/// Guards the invariants that let several charts coexist on one screen.
///
/// The macOS app puts up to four independent chart panes in one window. Before
/// this, every chart subscribed to the shared WebSocket as the literal owner
/// `"chart"` and every marker manager as `"markers"`, so the owner set held one
/// entry no matter how many charts existed — and the first pane to switch symbol
/// or tear down unsubscribed the channel out from under all the others. The
/// failure is silent: the other panes simply stop receiving ticks.
@MainActor
struct ChartPaneIsolationTests {

    private func makeViewModel(ownerToken: String? = nil) -> ChartViewModel {
        ChartViewModel(
            appState: RLAppState(restoreSessionOnInit: false),
            dataManager: ChartDataManager(),
            api: RealAPIService(),
            ownerToken: ownerToken
        )
    }

    private func makeMarkerManager(ownerToken: String? = nil) -> MarkerManager {
        MarkerManager(
            userId: UUID(),
            guildId: UUID(),
            currentUserMember: Self.member(),
            ownerToken: ownerToken
        )
    }

    private static func member() -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: UUID(),
            role: "member",
            reputation: 100,
            contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 1_700_000_000),
            accuracyRate: 0.5,
            mutedUntil: nil,
            suspendedUntil: nil,
            userId: UUID(),
            username: "pane_test",
            displayName: "Pane Test",
            avatarUrl: nil,
            isOnline: false,
            globalReputation: 100,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
    }

    // MARK: - Owner tokens are per instance

    @Test
    func twoChartsGetDistinctOwnerTokens() {
        let a = makeViewModel()
        let b = makeViewModel()
        #expect(a.ownerToken != b.ownerToken)
        #expect(a.ownerToken.hasPrefix("chart_"))
    }

    @Test
    func twoMarkerManagersGetDistinctOwnerTokens() {
        let a = makeMarkerManager()
        let b = makeMarkerManager()
        #expect(a.ownerToken != b.ownerToken)
        #expect(a.ownerToken.hasPrefix("markers_"))
    }

    @Test
    func anExplicitOwnerTokenIsHonoured() {
        #expect(makeViewModel(ownerToken: "pane-1").ownerToken == "pane-1")
        #expect(makeMarkerManager(ownerToken: "pane-1-markers").ownerToken == "pane-1-markers")
    }

    // MARK: - The regression itself

    /// Two panes on the same symbol; one switches away. The channel must stay
    /// subscribed for the pane that is still watching it.
    @Test
    func onePaneLeavingAChannelDoesNotUnsubscribeTheOther() {
        let service = RealTimeService.shared
        // Unique per run: `shared` is a singleton and these tests must not
        // collide with each other or with anything the app already subscribed to.
        let channel = "market:candles:\(UUID().uuidString.lowercased()):1m"

        let paneA = makeViewModel()
        let paneB = makeViewModel()

        service.subscribe(to: [channel], owner: paneA.ownerToken)
        service.subscribe(to: [channel], owner: paneB.ownerToken)
        #expect(service.channelOwnersSnapshot[channel]?.count == 2)

        // Pane A changes symbol and drops the old channel.
        service.unsubscribe(from: [channel], owner: paneA.ownerToken)

        #expect(service.channelOwnersSnapshot[channel] == [paneB.ownerToken],
                "pane B is still watching this channel, so it must stay subscribed")
        #expect(service.trackedChannelsSnapshot.contains(channel))

        // Only when the last pane leaves does the channel go.
        service.unsubscribe(from: [channel], owner: paneB.ownerToken)
        #expect(service.channelOwnersSnapshot[channel] == nil)
        #expect(!service.trackedChannelsSnapshot.contains(channel))
    }

    /// The marker channel is guild-scoped, so every pane subscribes to the very
    /// same channel — which makes this the worse of the two cases.
    @Test
    func markerChannelSurvivesUntilTheLastPaneLeaves() {
        let service = RealTimeService.shared
        let channel = "guild:\(UUID().uuidString.lowercased()):markers"

        let managers = (0..<4).map { _ in makeMarkerManager() }
        for manager in managers {
            service.subscribe(to: [channel], owner: manager.ownerToken)
        }
        #expect(service.channelOwnersSnapshot[channel]?.count == 4)

        for manager in managers.dropLast() {
            service.unsubscribe(from: [channel], owner: manager.ownerToken)
            #expect(service.trackedChannelsSnapshot.contains(channel))
        }

        service.unsubscribe(from: [channel], owner: managers.last!.ownerToken)
        #expect(service.channelOwnersSnapshot[channel] == nil)
    }

    /// The tests above drive `RealTimeService` directly, which would still pass if
    /// the chart's own call sites regressed to a shared literal. This one goes
    /// through `ChartViewModel` so that regression is caught too.
    @Test
    func chartsSubscribeUnderTheirOwnTokenNotASharedLiteral() {
        let service = RealTimeService.shared
        let guildId = UUID()
        let symbolId = UUID()

        let paneA = makeViewModel()
        let paneB = makeViewModel()

        paneA.subscribeToRealTimeTicks(guildId: guildId, symbolId: symbolId, timeframe: .m1)
        paneB.subscribeToRealTimeTicks(guildId: guildId, symbolId: symbolId, timeframe: .m1)

        let tickChannel = "market:ticks:\(symbolId.uuidString.lowercased())"
        #expect(service.channelOwnersSnapshot[tickChannel] == [paneA.ownerToken, paneB.ownerToken],
                "both panes must appear as separate owners of the shared channel")

        // Pane A moves on. Pane B is still watching, so the channel stays.
        paneA.unsubscribeFromRealTimeTicks()
        #expect(service.channelOwnersSnapshot[tickChannel] == [paneB.ownerToken])
        #expect(service.trackedChannelsSnapshot.contains(tickChannel))

        paneB.unsubscribeFromRealTimeTicks()
        #expect(service.channelOwnersSnapshot[tickChannel] == nil)
    }

    /// Pins the old behaviour as a failure: a shared literal owner collapses the
    /// reference count to one entry regardless of how many panes there are.
    @Test
    func aSharedLiteralOwnerWouldCollapseTheReferenceCount() {
        let service = RealTimeService.shared
        let channel = "market:ticks:\(UUID().uuidString.lowercased())"

        service.subscribe(to: [channel], owner: "chart")
        service.subscribe(to: [channel], owner: "chart")
        #expect(service.channelOwnersSnapshot[channel]?.count == 1,
                "this is why the hardcoded owner was a bug")

        service.unsubscribe(from: [channel], owner: "chart")
        #expect(service.channelOwnersSnapshot[channel] == nil)
    }
}
