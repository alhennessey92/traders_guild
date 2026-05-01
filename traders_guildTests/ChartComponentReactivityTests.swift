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
    func chartComponentsAdapterClearsPlacementWorkflowWhenActiveHostDrawingIsRemoved() async throws {
        let placementState = MarkerPlacementState()
        let indicatorManager = IndicatorManager()
        let drawingManager = ChartDrawingManager()
        let timeframeLinkManager = ChartTimeframeLinkManager()
        let anchorTime = Date(timeIntervalSince1970: 1_700_000_000)

        let inactiveId = drawingManager.addDrawing(type: .trendline, note: "Trend")
        let activeId = drawingManager.addDrawing(type: .horizontalLine, note: "Liquidity")
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
        #expect(adapter.activeChartDrawings.map(\.id).contains(activeId))

        placementState.beginEditingDrawing(activeId, tool: .horizontalLine)
        #expect(placementState.drawingInteractionPhase == .editing)
        #expect(placementState.editingDrawingId == activeId)

        drawingManager.removeDrawing(id: inactiveId)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(placementState.drawingInteractionPhase == .editing)
        #expect(placementState.editingDrawingId == activeId)

        drawingManager.removeDrawing(id: activeId)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(placementState.drawingInteractionPhase == .idle)
        #expect(placementState.editingDrawingId == nil)
        #expect(placementState.activeTool == nil)
        #expect(placementState.activeSubTool == nil)
        #expect(!placementState.components.contains(where: { $0.id == activeId }))
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

    @Test
    func markerEmojiNormalizationRejectsBlankAndNonEmojiPayloads() {
        #expect(MarkerEmojiNormalization.normalized("   ") == nil)
        #expect(MarkerEmojiNormalization.normalized("not-an-emoji") == nil)
        #expect(MarkerEmojiNormalization.normalized("🔥") == "🔥")
        #expect(MarkerEmojiNormalization.normalized("🔥 extra") == "🔥")
    }

    @Test
    func oandaForexSymbolsUseSundayFridaySessionBoundaries() {
        let symbol = RLTradingSymbolDTO(
            id: UUID(),
            ticker: "EUR/USD",
            displayName: "Euro / US Dollar",
            assetClass: "forex",
            exchange: "OANDA",
            tickSize: 0.0001,
            lotSize: 1,
            decimalPlaces: 5,
            isActive: true,
            iconName: nil,
            iconUrl: nil,
            primaryColor: "#003399",
            secondaryColor: "#FFD700",
            currentPrice: 1.0842,
            priceFormatted: "1.08420",
            change24h: 0.0012,
            changePercent24h: 0.11,
            changeFormatted: "+0.00120 (+0.11%)",
            isUp: true,
            high24h: nil,
            low24h: nil,
            volume24h: nil,
            volumeFormatted: nil,
            inPersonalWatchlist: nil,
            inGuildWatchlist: nil,
            isRequestedForGuild: nil,
            activeMarketProvider: "oanda",
            isSupportedByActiveProvider: true,
            isMarketOpen: true,
            marketStatusUpdatedAt: nil,
            activityBadges: nil
        )

        #expect(symbol.usesOandaForexSessionBoundaries)
        #expect(symbol.marketSession.openHour == 22)
        #expect(symbol.marketSession.closeHour == 22)
        #expect(symbol.marketSession.closedWeekend)
    }

    @Test
    func cryptoYAxisFormatterClampsHighPriceLabelsToTwoDecimals() {
        let symbol = RLTradingSymbolDTO(
            id: UUID(),
            ticker: "BTC/USD",
            displayName: "Bitcoin / US Dollar",
            assetClass: "crypto",
            exchange: "Coinbase",
            tickSize: 0.01,
            lotSize: 1,
            decimalPlaces: 8,
            isActive: true,
            iconName: nil,
            iconUrl: nil,
            primaryColor: "#F7931A",
            secondaryColor: "#1C1C1C",
            currentPrice: 65000.12345678,
            priceFormatted: "65000.12345678",
            change24h: 1200.55,
            changePercent24h: 1.88,
            changeFormatted: "+1200.55 (+1.88%)",
            isUp: true,
            high24h: nil,
            low24h: nil,
            volume24h: nil,
            volumeFormatted: nil,
            inPersonalWatchlist: nil,
            inGuildWatchlist: nil,
            isRequestedForGuild: nil,
            activeMarketProvider: "coinbase",
            isSupportedByActiveProvider: true,
            isMarketOpen: true,
            marketStatusUpdatedAt: nil,
            activityBadges: nil
        )
        let helper = PriceAxisHelper(
            symbol: symbol,
            priceRange: (min: 64_000, max: 66_000),
            priceScale: 1.0,
            chartHeight: 320
        )

        #expect(helper.formatPrice(65000.12345678) == "65000.12")
    }

    @Test
    func cryptoYAxisFormatterKeepsUsefulPrecisionForSubDollarPrices() {
        let symbol = RLTradingSymbolDTO(
            id: UUID(),
            ticker: "DOGE/USD",
            displayName: "Dogecoin / US Dollar",
            assetClass: "crypto",
            exchange: "Kraken",
            tickSize: 0.0001,
            lotSize: 1,
            decimalPlaces: 8,
            isActive: true,
            iconName: nil,
            iconUrl: nil,
            primaryColor: "#C2A633",
            secondaryColor: "#1C1C1C",
            currentPrice: 0.07345678,
            priceFormatted: "0.07345678",
            change24h: 0.0012,
            changePercent24h: 1.66,
            changeFormatted: "+0.0012 (+1.66%)",
            isUp: true,
            high24h: nil,
            low24h: nil,
            volume24h: nil,
            volumeFormatted: nil,
            inPersonalWatchlist: nil,
            inGuildWatchlist: nil,
            isRequestedForGuild: nil,
            activeMarketProvider: "kraken",
            isSupportedByActiveProvider: true,
            isMarketOpen: true,
            marketStatusUpdatedAt: nil,
            activityBadges: nil
        )
        let helper = PriceAxisHelper(
            symbol: symbol,
            priceRange: (min: 0.0711, max: 0.0749),
            priceScale: 1.0,
            chartHeight: 320
        )

        #expect(helper.formatPrice(0.07345678) == "0.0735")
    }

    @Test
    func cryptoChartsUseDeviceTimeZoneForXAxisAndCrosshairLabels() {
        let symbol = RLTradingSymbolDTO(
            id: UUID(),
            ticker: "BTC/USD",
            displayName: "Bitcoin / US Dollar",
            assetClass: "crypto",
            exchange: "Binance",
            tickSize: 0.01,
            lotSize: 1,
            decimalPlaces: 8,
            isActive: true,
            iconName: nil,
            iconUrl: nil,
            primaryColor: "#F7931A",
            secondaryColor: "#1C1C1C",
            currentPrice: 65000.12345678,
            priceFormatted: "65000.12345678",
            change24h: 1200.55,
            changePercent24h: 1.88,
            changeFormatted: "+1200.55 (+1.88%)",
            isUp: true,
            high24h: nil,
            low24h: nil,
            volume24h: nil,
            volumeFormatted: nil,
            inPersonalWatchlist: nil,
            inGuildWatchlist: nil,
            isRequestedForGuild: nil,
            activeMarketProvider: "binance",
            isSupportedByActiveProvider: true,
            isMarketOpen: true,
            marketStatusUpdatedAt: nil,
            activityBadges: nil
        )

        #expect(symbol.exchangeTimeZone.identifier == TimeZone.current.identifier)
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
