import Foundation
import Testing
@testable import traders_guild

struct MarkerActivityNavigationTests {
    @Test
    func navigationTargetFromActivityMarkerPreservesChartContext() {
        let markerId = UUID()
        let symbolId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        var marker = makeActivityMarker(
            id: markerId,
            symbolId: symbolId,
            ticker: "DOGE/USD",
            timeframe: "1m",
            activityOffset: 0,
            createdOffset: 0
        )
        marker = marker.withNavigationContext(
            candleTimestamp: timestamp,
            price: 0.1087,
            intent: RLMarkerIntent.alert.rawValue,
            alertSeverity: MarkerAlertSeverity.critical.rawValue
        )

        let target = MarkerNavigationTarget(topMarker: marker.asTopMarkerDTO())

        #expect(target.markerId == markerId)
        #expect(target.symbolId == symbolId)
        #expect(target.symbolTicker == "DOGE/USD")
        #expect(target.timeframe == .m1)
        #expect(target.candleTimestamp == timestamp)
        #expect(target.price == 0.1087)
        #expect(target.intent == .alert)
        #expect(target.alertSeverity == .critical)
    }

    @Test
    func navigationTargetFromSharedPayloadPreservesMarkerIdentity() {
        let markerId = UUID()
        let symbolId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_060)
        let payload = MarkerSharePayloadV1(
            markerId: markerId,
            symbolId: symbolId,
            symbolTicker: "BTC/USD",
            symbolAssetClass: "crypto",
            symbolBrandColor: "#F7931A",
            timeframe: "5m",
            candleTimestamp: timestamp,
            intent: RLMarkerIntent.reaction.rawValue,
            selectedEmoji: "🔥"
        )

        let target = MarkerNavigationTarget(sharedPayload: payload)

        #expect(target.markerId == markerId)
        #expect(target.symbolId == symbolId)
        #expect(target.symbolTicker == "BTC/USD")
        #expect(target.symbolAssetClass == "crypto")
        #expect(target.symbolBrandColor == "#F7931A")
        #expect(target.timeframe == .m5)
        #expect(target.candleTimestamp == timestamp)
        #expect(target.intent == .reaction)
        #expect(target.selectedEmoji == "🔥")
        #expect(target.price == nil)
    }

    @Test
    func chartDataManagerGivesSinglePriceWindowsAUsableRange() {
        let manager = ChartDataManager()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        manager.updateWithMarketData([
            RLCandleDTO(timestamp: timestamp, open: 100, high: 100, low: 100, close: 100, volume: 0, isGapFill: true),
            RLCandleDTO(timestamp: timestamp.addingTimeInterval(60), open: 100, high: 100, low: 100, close: 100, volume: 0, isGapFill: true)
        ])

        #expect(manager.priceRange.max > manager.priceRange.min)
        #expect(manager.priceRange.min < 100)
        #expect(manager.priceRange.max > 100)
    }

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
    id: UUID = UUID(),
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
        id: id,
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
        pollQuestion: nil,
        pollOptions: nil,
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

private extension RLMarkerActivityItemDTO {
    func withNavigationContext(
        candleTimestamp: Date,
        price: Double,
        intent: String,
        alertSeverity: String?
    ) -> RLMarkerActivityItemDTO {
        RLMarkerActivityItemDTO(
            id: id,
            symbolId: symbolId,
            symbolTicker: symbolTicker,
            symbolBrandColor: symbolBrandColor,
            symbolAssetClass: symbolAssetClass,
            guildId: guildId,
            authorId: authorId,
            authorUsername: authorUsername,
            authorInitials: authorInitials,
            authorAvatarUrl: authorAvatarUrl,
            authorIsOnline: authorIsOnline,
            authorReputation: authorReputation,
            authorAccuracyRate: authorAccuracyRate,
            authorRole: authorRole,
            intent: intent,
            title: title,
            notePreview: notePreview,
            pollQuestion: pollQuestion,
            pollOptions: pollOptions,
            selectedEmoji: selectedEmoji,
            alertSeverity: alertSeverity,
            createdAt: createdAt,
            createdAtFormatted: createdAtFormatted,
            activityTimestamp: activityTimestamp,
            activityTimestampFormatted: activityTimestampFormatted,
            candleTimestamp: candleTimestamp,
            timeframe: timeframe,
            price: price,
            setupSummary: setupSummary,
            predictionResult: predictionResult,
            likeCount: likeCount,
            isLikedByCurrentUser: isLikedByCurrentUser,
            commentCount: commentCount,
            isCurrentUserMarker: isCurrentUserMarker
        )
    }
}
