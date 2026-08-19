import Foundation
import Testing
@testable import traders_guild

@MainActor
struct ChartGapFillRealtimeFallbackTests {
    @Test
    func realtimeFallbackInsertsMissingBucketsForTickPath() async throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T10:00:00Z", close: 100)])

        manager.processRealTick(
            price: 101,
            volume: 3,
            timestamp: try date("2026-01-01T10:03:00Z")
        )
        try await waitForTickFlush()

        #expect(manager.candles.count == 4)
        #expect(manager.candles[1].isGapFill)
        #expect(manager.candles[2].isGapFill)
        #expect(!manager.candles[3].isGapFill)
    }

    @Test
    func realtimeFallbackInsertsMissingBucketsForCandlePath() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T10:00:00Z", close: 100)])

        let _ = manager.processRealCandle(
            makeCandle("2026-01-01T10:03:00Z", close: 103, isGapFill: false)
        )

        #expect(manager.candles.count == 4)
        #expect(manager.candles[1].isGapFill)
        #expect(manager.candles[2].isGapFill)
        #expect(!manager.candles[3].isGapFill)
    }

    @Test
    func realtimeFallbackCapIsRespected() async throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T00:00:00Z", close: 100)])

        manager.processRealTick(
            price: 101,
            volume: 1,
            timestamp: try date("2026-01-01T03:30:00Z")
        )
        try await waitForTickFlush()

        let gapCount = manager.candles.filter(\.isGapFill).count
        #expect(gapCount == 120)
        #expect(manager.candles.count == 122)
    }

    @Test
    func realCandleReplacesExistingPlaceholder() async throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([makeCandle("2026-01-01T10:00:00Z", close: 100)])

        manager.processRealTick(
            price: 101,
            volume: 1,
            timestamp: try date("2026-01-01T10:03:00Z")
        )
        try await waitForTickFlush()

        let replacement = makeCandle("2026-01-01T10:02:00Z", close: 150, isGapFill: false)
        let _ = manager.processRealCandle(replacement)

        let idx = try #require(manager.candles.firstIndex(where: { $0.timestamp == replacement.timestamp }))
        #expect(!manager.candles[idx].isGapFill)
        #expect(manager.candles[idx].close == 150)
    }

    @Test
    func historicalMergePrependsDedupesAndExposesPrependCount() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:02:00Z", close: 102),
            makeCandle("2026-01-01T10:03:00Z", close: 103),
        ])

        let prepended = manager.mergeHistoricalMarketData([
            makeCandle("2026-01-01T10:00:00Z", close: 100),
            makeCandle("2026-01-01T10:01:00Z", close: 101),
            makeCandle("2026-01-01T10:02:00Z", close: 999),
        ])

        #expect(prepended == 2)
        #expect(manager.candles.count == 4)
        #expect(manager.candles.first?.timestamp == (try date("2026-01-01T10:00:00Z")))
        #expect(manager.candles.last?.timestamp == (try date("2026-01-01T10:03:00Z")))
        #expect(manager.candles[2].close == 102)
        #expect(manager.consumeLastPrependedCandleCount() == 2)
        #expect(manager.consumeLastPrependedCandleCount() == 0)
    }

    @Test
    func historicalMergeResultPreservesPriceRangeForPureOffscreenPrepend() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:02:00Z", close: 100),
            makeCandle("2026-01-01T10:03:00Z", close: 105),
        ])
        let oldRange = manager.priceRange

        let result = manager.mergeHistoricalMarketData(
            [
                makeCandle("2026-01-01T10:00:00Z", close: 10_000),
                makeCandle("2026-01-01T10:01:00Z", close: 10_100),
                makeCandle("2026-01-01T10:02:00Z", close: 999),
            ],
            preservePriceRangeForPurePrepend: true
        )

        #expect(result.prependedCount == 2)
        #expect(result.insertedCount == 2)
        #expect(result.duplicateCount == 1)
        #expect(result.deferredPriceRangeUpdate)
        #expect(manager.priceRange.min == oldRange.min)
        #expect(manager.priceRange.max == oldRange.max)
        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)

        manager.refreshDeferredHistoricalPriceRangeIfNeeded()
        #expect(!manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.max > 10_000)
    }

    @Test
    func historicalPrependCallbackRunsBeforeCandlesPublish() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:02:00Z", close: 102),
            makeCandle("2026-01-01T10:03:00Z", close: 103),
        ])

        var callbackCount: Int?
        var candleCountDuringCallback: Int?
        var firstTimestampDuringCallback: Date?

        let result = manager.mergeHistoricalMarketData(
            [
                makeCandle("2026-01-01T10:00:00Z", close: 100),
                makeCandle("2026-01-01T10:01:00Z", close: 101),
            ],
            preservePriceRangeForPurePrepend: true,
            beforePublishingPrepend: { count in
                callbackCount = count
                candleCountDuringCallback = manager.candles.count
                firstTimestampDuringCallback = manager.candles.first?.timestamp
            }
        )

        #expect(result.prependedCount == 2)
        #expect(callbackCount == 2)
        #expect(candleCountDuringCallback == 2)
        #expect(firstTimestampDuringCallback == (try date("2026-01-01T10:02:00Z")))
        #expect(manager.candles.count == 4)
        #expect(manager.candles.first?.timestamp == (try date("2026-01-01T10:00:00Z")))
    }

    @Test
    func historicalPrependKeepsExistingCandlesAtSameVisualX() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:02:00Z", close: 102),
            makeCandle("2026-01-01T10:03:00Z", close: 103),
        ])

        let targetTimestamp = try date("2026-01-01T10:03:00Z")
        let totalCandleWidth: CGFloat = 10
        let initialIndex = try #require(manager.candles.firstIndex { $0.timestamp == targetTimestamp })
        let initialX = CGFloat(initialIndex - manager.historicalRenderIndexOffset) * totalCandleWidth

        let result = manager.mergeHistoricalMarketData(
            [
                makeCandle("2026-01-01T10:00:00Z", close: 100),
                makeCandle("2026-01-01T10:01:00Z", close: 101),
            ],
            preservePriceRangeForPurePrepend: true
        )

        let postMergeIndex = try #require(manager.candles.firstIndex { $0.timestamp == targetTimestamp })
        let postMergeX = CGFloat(postMergeIndex - manager.historicalRenderIndexOffset) * totalCandleWidth

        #expect(result.prependedCount == 2)
        #expect(manager.historicalRenderIndexOffset == 2)
        #expect(postMergeX == initialX)
    }

    @Test
    func realtimeTickAfterDeferredHistoricalPrependDoesNotExpandRangeFromOffscreenHistory() async throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:02:00Z", close: 100),
            makeCandle("2026-01-01T10:03:00Z", close: 105),
        ])

        let result = manager.mergeHistoricalMarketData(
            [
                makeCandle("2026-01-01T10:00:00Z", close: 10_000),
                makeCandle("2026-01-01T10:01:00Z", close: 10_100),
            ],
            preservePriceRangeForPurePrepend: true
        )

        manager.processRealTick(
            price: 106,
            volume: 1,
            timestamp: try date("2026-01-01T10:03:30Z")
        )
        try await waitForTickFlush()

        #expect(result.prependedCount == 2)
        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.max < 200)
    }

    @Test
    func markerFocusRefreshesDeferredRangeOnlyForPrependedHistoricalCandles() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:02:00Z", close: 100),
            makeCandle("2026-01-01T10:03:00Z", close: 105),
        ])

        let preservedRange = manager.priceRange
        let result = manager.mergeHistoricalMarketData(
            [
                makeCandle("2026-01-01T10:00:00Z", close: 10_000),
                makeCandle("2026-01-01T10:01:00Z", close: 10_100),
            ],
            preservePriceRangeForPurePrepend: true
        )

        manager.refreshDeferredHistoricalPriceRangeIfNeeded(forCandleIndex: result.prependedCount)

        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.min == preservedRange.min)
        #expect(manager.priceRange.max == preservedRange.max)

        manager.refreshDeferredHistoricalPriceRangeIfNeeded(forCandleIndex: result.prependedCount - 1)

        #expect(!manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.max > 10_000)
    }

    @Test
    func markerFocusUsesLocalHistoricalRangeInsteadOfAllLoadedHistory() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:00:00Z", close: 100),
            makeCandle("2026-01-01T10:01:00Z", close: 105),
        ])

        let start = try date("2026-01-01T08:00:00Z")
        var historical: [RLCandleDTO] = []
        historical.reserveCapacity(100)
        for index in 0..<100 {
            let close: Double
            if index == 0 {
                close = 10_000
            } else if index == 98 {
                close = 200
            } else {
                close = 190
            }

            historical.append(
                makeCandle(
                    timestamp: start.addingTimeInterval(TimeInterval(index * 60)),
                    close: close
                )
            )
        }

        let result = manager.mergeHistoricalMarketData(
            historical,
            preservePriceRangeForPurePrepend: true
        )

        #expect(result.prependedCount == 100)
        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)

        manager.focusDeferredHistoricalPriceRangeIfNeeded(
            forCandleIndex: 98,
            visibleCandleCount: 6
        )

        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.max < 1_000)
        #expect(manager.priceRange.max > 200)
    }

    @Test
    func markerExitKeepsHistoricalViewportRangeInsteadOfLatestRange() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:00:00Z", close: 100),
            makeCandle("2026-01-01T10:01:00Z", close: 105),
        ])

        let start = try date("2026-01-01T08:00:00Z")
        var historical: [RLCandleDTO] = []
        historical.reserveCapacity(100)
        for index in 0..<100 {
            let close: Double
            if index == 10 {
                close = 300
            } else if index == 98 {
                close = 10_000
            } else {
                close = 290
            }

            historical.append(
                makeCandle(
                    timestamp: start.addingTimeInterval(TimeInterval(index * 60)),
                    close: close
                )
            )
        }

        let result = manager.mergeHistoricalMarketData(
            historical,
            preservePriceRangeForPurePrepend: true
        )

        #expect(result.prependedCount == 100)

        manager.focusDeferredHistoricalPriceRangeIfNeeded(
            forCandleIndex: 10,
            visibleCandleCount: 6
        )
        #expect(manager.priceRange.max > 300)
        #expect(manager.priceRange.max < 1_000)

        manager.focusVisibleHistoricalPriceRangeIfNeeded(
            visibleStartIndex: 8,
            visibleCandleCount: 6
        )
        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.max > 300)
        #expect(manager.priceRange.max < 1_000)

        manager.focusVisibleHistoricalPriceRangeIfNeeded(
            visibleStartIndex: result.prependedCount,
            visibleCandleCount: 6
        )
        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)
        #expect(manager.priceRange.max < 200)
    }

    @Test
    func markerFocusDoesNotRefocusAlreadyWarmedVisibleHistoricalWindow() throws {
        let manager = ChartDataManager()
        manager.currentTimeframe = .m1
        manager.updateWithMarketData([
            makeCandle("2026-01-01T10:00:00Z", close: 100),
            makeCandle("2026-01-01T10:01:00Z", close: 105),
        ])

        let start = try date("2026-01-01T08:00:00Z")
        var historical: [RLCandleDTO] = []
        historical.reserveCapacity(100)
        for index in 0..<100 {
            historical.append(
                makeCandle(
                    timestamp: start.addingTimeInterval(TimeInterval(index * 60)),
                    close: index == 43 ? 10_000 : 220
                )
            )
        }

        let result = manager.mergeHistoricalMarketData(
            historical,
            preservePriceRangeForPurePrepend: true
        )
        #expect(result.prependedCount == 100)

        manager.focusVisibleHistoricalPriceRangeIfNeeded(
            visibleStartIndex: 88,
            visibleCandleCount: 12
        )
        let warmedRange = manager.priceRange
        #expect(warmedRange.max < 1_000)

        let didRefocus = manager.focusDeferredHistoricalPriceRangeIfNeeded(
            forCandleIndex: 90,
            visibleCandleCount: 12
        )

        #expect(!didRefocus)
        #expect(manager.priceRange.min == warmedRange.min)
        #expect(manager.priceRange.max == warmedRange.max)
        #expect(manager.hasDeferredHistoricalPriceRangeUpdate)
    }

    @Test
    func markerFocusHelperCanReturnUnclampedGlyphTargetForHistoricalEntry() throws {
        let candle = makeCandle("2026-01-01T10:00:00Z", close: 150)
        var marker = ChartMarkerUI(
            marker: makeMarkerDTO(
                candleTimestamp: candle.timestamp,
                price: 150
            ),
            candleIndex: 0
        )
        marker.positionedBelow = false

        let clamped = try #require(MarkerFocusHelper.renderedGlyphFocusPrice(
            marker: marker,
            candles: [candle],
            chartSize: CGSize(width: 300, height: 200),
            priceRange: (min: 100, max: 110),
            priceScale: 1,
            verticalOffset: 0,
            totalCandleWidth: 10,
            actualCandleWidth: 6,
            totalOffset: 0
        ))
        let unclamped = try #require(MarkerFocusHelper.renderedGlyphFocusPrice(
            marker: marker,
            candles: [candle],
            chartSize: CGSize(width: 300, height: 200),
            priceRange: (min: 100, max: 110),
            priceScale: 1,
            verticalOffset: 0,
            totalCandleWidth: 10,
            actualCandleWidth: 6,
            totalOffset: 0,
            clampToRange: false
        ))

        #expect(clamped == 110)
        #expect(unclamped > 110)
    }

    @Test
    func visibleDayLabelUsesHistoricalRenderOffsetForLeftEdgeCandle() throws {
        let candles = [
            makeCandle("2026-05-28T00:00:00Z", close: 100),
            makeCandle("2026-05-29T00:00:00Z", close: 100),
            makeCandle("2026-06-01T00:00:00Z", close: 100),
            makeCandle("2026-06-02T00:00:00Z", close: 100),
        ]

        let label = ChartXAxisLabelEngine.visibleDayLabel(
            input: .init(
                candles: candles,
                timeframe: .m5,
                totalOffset: 0,
                totalCandleWidth: 10,
                actualCandleWidth: 6,
                historicalRenderIndexOffset: 2,
                width: 10,
                timeZone: TimeZone(secondsFromGMT: 0)!,
                locale: Locale(identifier: "en_US_POSIX"),
                now: try date("2026-06-20T00:00:00Z")
            )
        )

        #expect(label == "01 Jun")
    }

    @Test
    func historicalPreloadPolicyUsesLargeSmoothnessBuffers() {
        #expect(HistoricalPreloadPolicy.pageSize == 1000)
        #expect(HistoricalPreloadPolicy.warmupTarget(for: .m5) == 3500)
        #expect(HistoricalPreloadPolicy.warmupTarget(for: .h1) == 2500)
        #expect(HistoricalPreloadPolicy.warmupTarget(for: .d1) == 1200)
        #expect(HistoricalPreloadPolicy.triggerThreshold(visibleCandleCount: 50) == 900)
        #expect(HistoricalPreloadPolicy.targetBuffer(visibleCandleCount: 50) == 1500)
        #expect(HistoricalPreloadPolicy.triggerThreshold(visibleCandleCount: 200) == 1600)
        #expect(HistoricalPreloadPolicy.targetBuffer(visibleCandleCount: 200) == 2400)
    }

    @Test
    func olderEdgeGuardPreventsSeeingLoadedStartUntilHistoryExhausted() {
        let state = ChartGestureState()
        state.applyPan(
            translation: CGSize(width: 10_000, height: 0),
            chartWidth: 300,
            candleCount: 200,
            candleWidth: 10,
            chartHeight: 200,
            priceScale: 1,
            olderEdgeGuardCandleCount: 20,
            trackVelocity: false
        )
        #expect(abs(state.panOffset.width + 200) < 0.0001)

        state.reset()
        state.applyPan(
            translation: CGSize(width: 10_000, height: 0),
            chartWidth: 300,
            candleCount: 200,
            candleWidth: 10,
            chartHeight: 200,
            priceScale: 1,
            olderEdgeGuardCandleCount: 0,
            trackVelocity: false
        )
        #expect(abs(state.panOffset.width - ChartGestureState.horizontalEdgePadding) < 0.0001)
    }

    @Test
    func olderEdgeGuardWallStillQualifiesForNextPreloadAfterPrepend() {
        let state = ChartGestureState()
        let candleWidth: CGFloat = 10
        let candleCount = 1_400
        let renderOffset = 1_000
        let guardCount = 120
        let visibleCandleCount = 40

        state.applyPan(
            translation: CGSize(width: 100_000, height: 0),
            chartWidth: 300,
            candleCount: candleCount,
            candleWidth: candleWidth,
            chartHeight: 200,
            priceScale: 1,
            olderEdgeGuardCandleCount: guardCount,
            historicalRenderIndexOffset: renderOffset,
            trackVelocity: false
        )

        let expectedWallOffset = CGFloat(renderOffset - guardCount) * candleWidth
        let visibleStartIndex = max(
            0,
            min(candleCount - 1, Int(floor(-state.panOffset.width / candleWidth)) + renderOffset)
        )

        #expect(abs(state.panOffset.width - expectedWallOffset) < 0.0001)
        #expect(visibleStartIndex == guardCount)
        #expect(HistoricalPreloadPolicy.shouldPreload(
            visibleStartIndex: visibleStartIndex,
            visibleCandleCount: visibleCandleCount,
            hasMoreHistoricalCandles: true
        ))
    }

    @Test
    func chartGestureMarksOnlyUserDrivenDragAsActive() {
        let state = ChartGestureState()
        #expect(!state.isUserDrivenScrollActive)

        state.beginDrag()
        #expect(state.isUserDrivenScrollActive)

        state.endDrag(
            chartWidth: 300,
            candleCount: 200,
            candleWidth: 10,
            chartHeight: 200,
            priceScale: 1
        )
        #expect(!state.isUserDrivenScrollActive)
    }

    @Test
    func decodeWithoutGapFlagDefaultsToFalse() throws {
        let json = """
        {
          "timestamp": "2026-01-01T00:00:00Z",
          "timestamp_formatted": "2026-01-01 00:00",
          "open": 100.0,
          "high": 101.0,
          "low": 99.0,
          "close": 100.5,
          "volume": 10.0
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let candle = try decoder.decode(RLCandleDTO.self, from: Data(json.utf8))
        #expect(candle.isGapFill == false)
    }

    @Test
    func markerSnapTieBreakPrefersPreviousThenNext() throws {
        let candles = [
            makeCandle("2026-01-01T10:00:00Z", close: 100, isGapFill: false),
            makeCandle("2026-01-01T10:01:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:02:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:03:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:04:00Z", close: 100, isGapFill: false),
        ]

        let snapped = TradingChartView.nearestNonGapCandleIndex(for: 2, candles: candles)
        #expect(snapped == 0)

        let onlyGaps = [
            makeCandle("2026-01-01T10:00:00Z", close: 100, isGapFill: true),
            makeCandle("2026-01-01T10:01:00Z", close: 100, isGapFill: true),
        ]
        #expect(TradingChartView.nearestNonGapCandleIndex(for: 1, candles: onlyGaps) == nil)
    }

    private func makeCandle(_ iso: String, close: Double, isGapFill: Bool = false) -> RLCandleDTO {
        let ts = (try? date(iso)) ?? Date(timeIntervalSince1970: 0)
        return makeCandle(timestamp: ts, close: close, isGapFill: isGapFill)
    }

    private func makeCandle(timestamp: Date, close: Double, isGapFill: Bool = false) -> RLCandleDTO {
        return RLCandleDTO(
            timestamp: timestamp,
            open: close,
            high: close,
            low: close,
            close: close,
            volume: 1,
            isGapFill: isGapFill
        )
    }

    private func date(_ iso8601: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso8601) else {
            throw DateParseError.invalid(iso8601)
        }
        return date
    }

    private func waitForTickFlush() async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
    }

    private func makeMarkerDTO(candleTimestamp: Date, price: Double) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: UUID(),
            symbolId: UUID(),
            guildId: UUID(),
            author: makeMember(),
            candleTimestamp: candleTimestamp,
            timeframe: "1m",
            price: price,
            intent: RLMarkerIntent.analysis.rawValue,
            title: nil,
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: false,
            trackingState: nil,
            alertSeverity: nil,
            createdAt: candleTimestamp,
            createdAtFormatted: "now",
            isVisible: true,
            likeCount: 0,
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
            predictionResult: nil
        )
    }

    private func makeMember() -> RLGuildMemberDTO {
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
            username: "marker_test",
            displayName: "Marker Test",
            avatarUrl: nil,
            isOnline: false,
            globalReputation: 100,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
    }
}

private enum DateParseError: Error {
    case invalid(String)
}
