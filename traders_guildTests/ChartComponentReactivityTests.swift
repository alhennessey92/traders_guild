import Foundation
import Testing
@testable import traders_guild

@MainActor
struct ChartComponentReactivityTests {
    @Test
    func chartComponentsAdapterRemovesDrawingSnapshotAndDraftsImmediately() async throws {
        let placementState = MarkerPlacementState()
        let indicatorManager = IndicatorManager()
        let drawingManager = ChartDrawingManager()
        let timeframeLinkManager = ChartTimeframeLinkManager()
        let anchorTime = Date(timeIntervalSince1970: 1_700_000_000)

        let drawingId = drawingManager.addDrawing(type: .horizontalLine, note: "Liquidity")
        let adapter = ChartComponentsAdapter(
            placementState: placementState,
            indicatorManager: indicatorManager,
            drawingManager: drawingManager,
            timeframeLinkManager: timeframeLinkManager,
            currentChartTimeframe: .m5,
            onSelectTimeframeAction: nil,
            onRecalculate: {},
            onBeginInteractiveDrawing: nil,
            symbolId: nil,
            anchorTime: anchorTime,
            anchorPrice: 1.205
        )

        #expect(adapter.activeChartDrawings.map(\.id) == [drawingId])
        #expect(placementState.components.contains(where: { $0.id == drawingId }))

        drawingManager.removeDrawing(id: drawingId)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(adapter.activeChartDrawings.isEmpty)
        #expect(!placementState.components.contains(where: { $0.id == drawingId }))
    }

    @Test
    func chartComponentsAdapterRemovesCurrentlySelectedLinkedTimeframeImmediately() async throws {
        let placementState = MarkerPlacementState()
        let indicatorManager = IndicatorManager()
        let drawingManager = ChartDrawingManager()
        let timeframeLinkManager = ChartTimeframeLinkManager()
        timeframeLinkManager.setLinkedTimeframes(["1h", "4h"])

        let adapter = ChartComponentsAdapter(
            placementState: placementState,
            indicatorManager: indicatorManager,
            drawingManager: drawingManager,
            timeframeLinkManager: timeframeLinkManager,
            currentChartTimeframe: .h1,
            onSelectTimeframeAction: nil,
            onRecalculate: {},
            onBeginInteractiveDrawing: nil,
            symbolId: nil,
            anchorTime: Date(timeIntervalSince1970: 1_700_000_000),
            anchorPrice: 1.205
        )
        #expect(adapter.currentChartTimeframe == .h1)

        #expect(
            placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue).sorted() == ["1h", "4h"]
        )

        placementState.removeTimeframeLink("1h")
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(timeframeLinkManager.linkedTimeframes == ["4h"])
        #expect(placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue) == ["4h"])
    }

    @Test
    func chartComponentsAdapterAddsLinkedTimeframesToManagerImmediately() async throws {
        let placementState = MarkerPlacementState()
        let indicatorManager = IndicatorManager()
        let drawingManager = ChartDrawingManager()
        let timeframeLinkManager = ChartTimeframeLinkManager()

        let adapter = ChartComponentsAdapter(
            placementState: placementState,
            indicatorManager: indicatorManager,
            drawingManager: drawingManager,
            timeframeLinkManager: timeframeLinkManager,
            currentChartTimeframe: .m5,
            onSelectTimeframeAction: nil,
            onRecalculate: {},
            onBeginInteractiveDrawing: nil,
            symbolId: nil,
            anchorTime: Date(timeIntervalSince1970: 1_700_000_000),
            anchorPrice: 1.205
        )
        #expect(adapter.currentChartTimeframe == .m5)

        #expect(timeframeLinkManager.linkedTimeframes.isEmpty)

        #expect(placementState.upsertTimeframeLink("1h"))
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(timeframeLinkManager.linkedTimeframes == ["1h"])
        #expect(placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue) == ["1h"])
    }

    @Test
    func chartComponentsAdapterKeepsLinkedTimeframesInSyncAcrossAddAddRemoveSequence() async throws {
        let placementState = MarkerPlacementState()
        let indicatorManager = IndicatorManager()
        let drawingManager = ChartDrawingManager()
        let timeframeLinkManager = ChartTimeframeLinkManager()

        let adapter = ChartComponentsAdapter(
            placementState: placementState,
            indicatorManager: indicatorManager,
            drawingManager: drawingManager,
            timeframeLinkManager: timeframeLinkManager,
            currentChartTimeframe: .m5,
            onSelectTimeframeAction: nil,
            onRecalculate: {},
            onBeginInteractiveDrawing: nil,
            symbolId: nil,
            anchorTime: Date(timeIntervalSince1970: 1_700_000_000),
            anchorPrice: 1.205
        )
        #expect(adapter.currentChartTimeframe == .m5)

        #expect(placementState.upsertTimeframeLink("1h"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(timeframeLinkManager.linkedTimeframes == ["1h"])
        #expect(placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue) == ["1h"])

        #expect(placementState.upsertTimeframeLink("4h"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(timeframeLinkManager.linkedTimeframes == ["1h", "4h"])
        #expect(placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue) == ["1h", "4h"])

        placementState.removeTimeframeLink("1h")
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(timeframeLinkManager.linkedTimeframes == ["4h"])
        #expect(placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue) == ["4h"])
    }

    @Test
    func chartComponentsAdapterPreservesLinkedTimeframesWhenDrawingsChange() async throws {
        let placementState = MarkerPlacementState()
        let indicatorManager = IndicatorManager()
        let drawingManager = ChartDrawingManager()
        let timeframeLinkManager = ChartTimeframeLinkManager()

        let adapter = ChartComponentsAdapter(
            placementState: placementState,
            indicatorManager: indicatorManager,
            drawingManager: drawingManager,
            timeframeLinkManager: timeframeLinkManager,
            currentChartTimeframe: .m5,
            onSelectTimeframeAction: nil,
            onRecalculate: {},
            onBeginInteractiveDrawing: nil,
            symbolId: nil,
            anchorTime: Date(timeIntervalSince1970: 1_700_000_000),
            anchorPrice: 1.205
        )
        #expect(adapter.currentChartTimeframe == .m5)

        #expect(placementState.upsertTimeframeLink("1h"))
        try await Task.sleep(nanoseconds: 50_000_000)

        _ = drawingManager.addDrawing(type: .horizontalLine, note: "Swing high")
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(timeframeLinkManager.linkedTimeframes == ["1h"])
        #expect(placementState.timeframeLinkDrafts.compactMap(\.payload.timeframeValue) == ["1h"])
    }

    @Test
    func priceIndicatorLayoutStaysInlineWhenLatestPriceIsVisible() {
        let layout = PriceIndicatorView.layout(
            currentPrice: 105,
            priceScale: 1,
            verticalOffset: 0,
            chartHeight: 300,
            priceRange: (min: 100, max: 110),
            latestCandle: makeCandle(open: 104, close: 105),
            topExclusionHeight: 0,
            bottomExclusionHeight: 62
        )

        #expect(layout?.mode == .inline)
        #expect(layout?.direction == nil)
        #expect(layout?.tone == nil)
    }

    @Test
    func priceIndicatorLayoutClampsAboveRangeWithBullishDirection() {
        let layout = PriceIndicatorView.layout(
            currentPrice: 120,
            priceScale: 1,
            verticalOffset: 0,
            chartHeight: 300,
            priceRange: (min: 100, max: 110),
            latestCandle: makeCandle(open: 108, close: 109),
            topExclusionHeight: 64,
            bottomExclusionHeight: 62
        )

        #expect(layout?.mode == .clampedToTop)
        #expect(layout?.direction == .up)
        #expect(layout?.tone == .bullish)
        #expect((layout?.displayY ?? 0) >= 64 + (ChartAxisMetrics.directionalArrowChipHeight * 0.5) + 4)
    }

    @Test
    func priceIndicatorLayoutClampsBelowRangeWithBearishDirection() {
        let layout = PriceIndicatorView.layout(
            currentPrice: 90,
            priceScale: 1,
            verticalOffset: 0,
            chartHeight: 300,
            priceRange: (min: 100, max: 110),
            latestCandle: makeCandle(open: 101, close: 100),
            topExclusionHeight: 40,
            bottomExclusionHeight: 74
        )

        #expect(layout?.mode == .clampedToBottom)
        #expect(layout?.direction == .down)
        #expect(layout?.tone == .bearish)
        #expect((layout?.displayY ?? .infinity) <= 300 - 74 - (ChartAxisMetrics.directionalArrowChipHeight * 0.5) - 4)
    }

    @Test
    func priceIndicatorLayoutHonorsExplicitTopAndBottomExclusionBands() {
        let topClamped = PriceIndicatorView.layout(
            currentPrice: 110,
            priceScale: 1,
            verticalOffset: 0,
            chartHeight: 220,
            priceRange: (min: 100, max: 110),
            latestCandle: makeCandle(open: 109, close: 110),
            topExclusionHeight: 72,
            bottomExclusionHeight: 84
        )
        let bottomClamped = PriceIndicatorView.layout(
            currentPrice: 100,
            priceScale: 1,
            verticalOffset: 0,
            chartHeight: 220,
            priceRange: (min: 100, max: 110),
            latestCandle: makeCandle(open: 101, close: 100),
            topExclusionHeight: 72,
            bottomExclusionHeight: 84
        )

        #expect((topClamped?.displayY ?? 0) >= 72 + (ChartAxisMetrics.directionalArrowChipHeight * 0.5) + 4)
        #expect((bottomClamped?.displayY ?? .infinity) <= 220 - 84 - (ChartAxisMetrics.directionalArrowChipHeight * 0.5) - 4)
    }

    @Test
    func chartDrawingBridgePreservesNoteAnchorCoordinatesAcrossRoundTrip() {
        let noteAnchorTime = Date(timeIntervalSince1970: 1_700_000_000)
        let fallbackAnchorTime = noteAnchorTime.addingTimeInterval(14_400)
        let draft = MarkerComponentDraft(
            componentType: .textNote,
            payload: .note(
                NotePayload(
                    text: "Anchor stays put",
                    anchorTime: noteAnchorTime,
                    anchorPrice: 1.245
                )
            )
        )

        let drawing = ChartDrawingBridge.chartDrawing(
            from: draft,
            anchorTime: fallbackAnchorTime,
            anchorPrice: 9.999
        )

        #expect(drawing?.points.first?.time == noteAnchorTime)
        #expect(drawing?.points.first?.price == 1.245)

        if let drawing {
            let roundTripDraft = ChartDrawingBridge.markerDraft(
                from: drawing,
                anchorTime: fallbackAnchorTime,
                anchorPrice: 9.999
            )

            if case let .note(payload) = roundTripDraft.payload {
                #expect(payload.anchorTime == noteAnchorTime)
                #expect(payload.anchorPrice == 1.245)
            } else {
                Issue.record("Expected note payload after chart drawing round-trip")
            }
        } else {
            Issue.record("Expected chart drawing for note payload")
        }
    }

    @Test
    func chartDrawingBridgePreservesEmojiAnchorCoordinatesAcrossRoundTrip() {
        let emojiAnchorTime = Date(timeIntervalSince1970: 1_700_000_120)
        let fallbackAnchorTime = emojiAnchorTime.addingTimeInterval(28_800)
        let draft = MarkerComponentDraft(
            componentType: .reactionEmoji,
            payload: .reactionEmoji(
                EmojiPayload(
                    emoji: "🚀",
                    anchorTime: emojiAnchorTime,
                    anchorPrice: 1.3125
                )
            )
        )

        let drawing = ChartDrawingBridge.chartDrawing(
            from: draft,
            anchorTime: fallbackAnchorTime,
            anchorPrice: 7.777
        )

        #expect(drawing?.points.first?.time == emojiAnchorTime)
        #expect(drawing?.points.first?.price == 1.3125)

        if let drawing {
            let roundTripDraft = ChartDrawingBridge.markerDraft(
                from: drawing,
                anchorTime: fallbackAnchorTime,
                anchorPrice: 7.777
            )

            if case let .reactionEmoji(payload) = roundTripDraft.payload {
                #expect(payload.anchorTime == emojiAnchorTime)
                #expect(payload.anchorPrice == 1.3125)
            } else {
                Issue.record("Expected emoji payload after chart drawing round-trip")
            }
        } else {
            Issue.record("Expected chart drawing for emoji payload")
        }
    }

    private func makeCandle(open: Double, close: Double) -> RLCandleDTO {
        RLCandleDTO(
            timestamp: Date(timeIntervalSince1970: 0),
            timestampFormatted: nil,
            open: open,
            high: max(open, close),
            low: min(open, close),
            close: close,
            volume: 1,
            volumeFormatted: "1"
        )
    }
}

private extension MarkerComponentPayload {
    var timeframeValue: String? {
        guard case let .timeframeLink(payload) = self else { return nil }
        return payload.timeframe
    }
}
