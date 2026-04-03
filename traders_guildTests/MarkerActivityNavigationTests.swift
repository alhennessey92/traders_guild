import Foundation
import Testing
@testable import traders_guild

struct MarkerActivityNavigationTests {
    @Test
    func loadModesMatchRecentArchiveAndSetupPolicies() {
        #expect(MarkerActivityListLoadMode.recentFeed.state == .all)
        #expect(MarkerActivityListLoadMode.recentFeed.fetchAllPages == false)
        #expect(MarkerActivityListLoadMode.recentFeed.limit == 60)

        #expect(MarkerActivityListLoadMode.archive.state == .all)
        #expect(MarkerActivityListLoadMode.archive.fetchAllPages == true)

        #expect(MarkerActivityListLoadMode.setupsLive.state == .active)
        #expect(MarkerActivityListLoadMode.setupsLive.fetchAllPages == true)

        #expect(MarkerActivityListLoadMode.setupsResolved.state == .resolved)
        #expect(MarkerActivityListLoadMode.setupsResolved.fetchAllPages == true)
    }

    @Test
    func markerNavigationThemeUsesSemanticAccents() {
        #expect(UnifiedTabTheme.markerNavigation.markerAccent(forTitle: "Live Feed") == .orange)
        #expect(UnifiedTabTheme.markerNavigation.markerAccent(forTitle: "Setups") == .green)
        #expect(UnifiedTabTheme.markerNavigation.markerAccent(forTitle: "By Symbol") == .blue)
        #expect(UnifiedTabTheme.markerNavigation.markerAccent(forTitle: "All") == .blue)
    }

    @Test
    func symbolGroupsSortByCountThenLatestActivity() {
        let eurSymbol = UUID()
        let gbpSymbol = UUID()
        let audSymbol = UUID()

        let markers = [
            makeActivityMarker(symbolId: eurSymbol, ticker: "EURUSD", timeframe: "5m", activityOffset: 500, createdOffset: 510),
            makeActivityMarker(symbolId: eurSymbol, ticker: "EURUSD", timeframe: "1h", activityOffset: 420, createdOffset: 430),
            makeActivityMarker(symbolId: gbpSymbol, ticker: "GBPUSD", timeframe: "5m", activityOffset: 450, createdOffset: 455),
            makeActivityMarker(symbolId: gbpSymbol, ticker: "GBPUSD", timeframe: "1m", activityOffset: 320, createdOffset: 330),
            makeActivityMarker(symbolId: audSymbol, ticker: "AUDUSD", timeframe: "1m", activityOffset: 450, createdOffset: 451),
        ]

        let groups = MarkerActivityNavigation.symbolGroups(from: markers)

        #expect(groups.map(\.ticker) == ["EURUSD", "GBPUSD", "AUDUSD"])
        #expect(groups[0].count == 2)
        #expect(groups[1].count == 2)
        #expect(groups[0].markers.map(\.activityTimestamp) == groups[0].markers.map(\.activityTimestamp).sorted(by: >))
    }

    @Test
    func timeframeGroupsFollowCanonicalOrderAndExpandCurrentTimeframe() {
        let markers = [
            makeActivityMarker(ticker: "EURUSD", timeframe: "1h", activityOffset: 500, createdOffset: 505),
            makeActivityMarker(ticker: "EURUSD", timeframe: "1m", activityOffset: 450, createdOffset: 451),
            makeActivityMarker(ticker: "EURUSD", timeframe: "2h", activityOffset: 400, createdOffset: 401),
        ]

        let groups = MarkerActivityNavigation.timeframeGroups(from: markers, currentTimeframe: .h1)

        #expect(groups.map(\.title) == ["1m", "1H", "2H"])
        #expect(groups.map(\.isExpandedByDefault) == [false, true, false])
    }

    @Test
    func timeframeGroupsExpandFirstGroupWhenCurrentTimeframeIsMissing() {
        let markers = [
            makeActivityMarker(ticker: "EURUSD", timeframe: "5m", activityOffset: 500, createdOffset: 505),
            makeActivityMarker(ticker: "EURUSD", timeframe: "1d", activityOffset: 400, createdOffset: 401),
        ]

        let groups = MarkerActivityNavigation.timeframeGroups(from: markers, currentTimeframe: .h1)

        #expect(groups.map(\.title) == ["5m", "1D"])
        #expect(groups.map(\.isExpandedByDefault) == [true, false])
    }
}

private func makeActivityMarker(
    symbolId: UUID = UUID(),
    ticker: String,
    timeframe: String,
    activityOffset: TimeInterval,
    createdOffset: TimeInterval
) -> RLMarkerActivityItemDTO {
    let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
    let activityDate = baseDate.addingTimeInterval(activityOffset)
    let createdDate = baseDate.addingTimeInterval(createdOffset)

    return RLMarkerActivityItemDTO(
        id: UUID(),
        symbolId: symbolId,
        symbolTicker: ticker,
        symbolBrandColor: nil,
        symbolAssetClass: "forex",
        guildId: UUID(),
        authorId: UUID(),
        authorUsername: "tester",
        authorInitials: "TS",
        authorAvatarUrl: nil,
        authorIsOnline: true,
        authorReputation: 100,
        authorAccuracyRate: 0.72,
        authorRole: "member",
        intent: RLMarkerIntent.analysis.rawValue,
        title: "Marker",
        notePreview: "Preview",
        selectedEmoji: nil,
        alertSeverity: nil,
        createdAt: createdDate,
        createdAtFormatted: "now",
        activityTimestamp: activityDate,
        activityTimestampFormatted: "now",
        candleTimestamp: activityDate,
        timeframe: timeframe,
        price: 1.2345,
        setupSummary: nil,
        predictionResult: nil,
        likeCount: 0,
        isLikedByCurrentUser: false,
        commentCount: 0,
        isCurrentUserMarker: false
    )
}
