import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import traders_guild

@MainActor
struct MarkerPlanFixesTests {
    @Test
    func markerSpacingFloorAppliesAcrossZoomLevels() {
        let settings = MarkerDisplaySettings.shared
        let originalMinStackSpacing = settings.minStackSpacing
        let originalStackOffset = settings.stackOffset
        defer {
            settings.stackOffset = originalStackOffset
            settings.minStackSpacing = originalMinStackSpacing
        }

        settings.stackOffset = 2
        settings.minStackSpacing = 1
        #expect(settings.minStackSpacing == MarkerPositionCalculator.hardMinimumStackSpacing)

        var markerA = makeMarkerUI(intent: .analysis, title: "A")
        var markerB = markerA
        markerA.stackIndex = 0
        markerB.stackIndex = 1
        markerA.positionedBelow = false
        markerB.positionedBelow = false

        let zooms: [CGFloat] = [0.35, 0.75, 1.0, 1.6, 2.4]
        for zoom in zooms {
            let p0 = MarkerPositionCalculator.computeMarkerScreenPosition(
                marker: markerA,
                candleHighY: 180,
                candleLowY: 220,
                centerX: 120,
                priceScale: zoom
            )
            let p1 = MarkerPositionCalculator.computeMarkerScreenPosition(
                marker: markerB,
                candleHighY: 180,
                candleLowY: 220,
                centerX: 120,
                priceScale: zoom
            )

            let separation = abs(p1.y - p0.y)
            #expect(separation + 0.001 >= MarkerPositionCalculator.hardMinimumStackSpacing)
        }
    }

    @Test
    func alertIntentDefaultsToNeutralWhenSeverityIsUnset() {
        let neutralExpected = Color(hex: "#8E959D") ?? .gray
        let neutralAlertColor = RLMarkerIntent.alert.color
        let neutralDistance = colorDistance(rgba(neutralExpected), rgba(neutralAlertColor))
        #expect(neutralDistance < 0.02)

        let neutralMarker = makeMarkerUI(intent: .alert, title: "Neutral Alert", alertSeverity: nil)
        let criticalMarker = makeMarkerUI(intent: .alert, title: "Critical Alert", alertSeverity: "critical")

        let markerNeutralDistance = colorDistance(rgba(neutralMarker.displayColor), rgba(neutralAlertColor))
        #expect(markerNeutralDistance < 0.02)

        let severityDistance = colorDistance(rgba(neutralMarker.displayColor), rgba(criticalMarker.displayColor))
        #expect(severityDistance > 0.12)

        let neutralPalette = RLMarkerIntent.alert.markerPalette(for: nil)
        let criticalPalette = RLMarkerIntent.alert.markerPalette(for: .critical)
        #expect(colorDistance(rgba(neutralPalette[1]), rgba(criticalPalette[1])) > 0.12)
    }

    @Test
    func drawingDefaultsMatchUpdatedHorizontalAndLevelPalette() {
        #expect(ChartDrawingType.horizontalLine.defaultColorHex == "#9CA3AF")
        #expect(ChartDrawingType.supportLevel.defaultColorHex == "#7C3AED")
        #expect(ChartDrawingType.resistanceLevel.defaultColorHex == "#DC2626")

        let expectedColors: [(RLComponentType, Color)] = [
            (.drawingHorizontalLine, Color(hex: "#9CA3AF") ?? .gray),
            (.levelSupport, Color(hex: "#7C3AED") ?? .purple),
            (.levelResistance, Color(hex: "#DC2626") ?? .red),
        ]

        for (componentType, expectedColor) in expectedColors {
            #expect(colorDistance(rgba(componentType.color), rgba(expectedColor)) < 0.02)
        }
    }

    @Test
    func displayableComponentCountOnlyIncludesSurfacedTypes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let components: [RLMarkerComponentDTO] = [
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.anchor.rawValue,
                payload: .anchor(AnchorPayload(time: now, price: 100)),
                ordering: 0
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.indicator.rawValue,
                payload: .indicator(IndicatorPayload(name: "rsi", settings: ["length": AnyCodable(14)], isPrimary: nil)),
                ordering: 1
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.drawingZone.rawValue,
                payload: .drawingZone(
                    ZonePayload(
                        topPrice: 102,
                        bottomPrice: 98,
                        startTime: now.addingTimeInterval(-300),
                        endTime: now.addingTimeInterval(300)
                    )
                ),
                ordering: 2
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.timeframeLink.rawValue,
                payload: .timeframeLink(TimeframeLinkPayload(timeframe: "4h", note: "Higher timeframe")),
                ordering: 3
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.textNote.rawValue,
                payload: .note(NotePayload(text: "Context")),
                ordering: 4
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.reactionEmoji.rawValue,
                payload: .reactionEmoji(EmojiPayload(emoji: "🔥")),
                ordering: 5
            ),
        ]

        let marker = makeMarkerUI(intent: .analysis, title: "Count Test", components: components)
        let metrics = MarkerViewingComponentMetrics(marker: marker)

        #expect(metrics.indicatorComponents.count == 1)
        #expect(metrics.drawingComponents.count == 1)
        #expect(metrics.timeframeComponents.count == 1)
        #expect(metrics.displayedComponentCount == 3)
        #expect(metrics.hiddenComponentCount == 3)
    }

    @Test
    func markerAnalysisNoteDoesNotSynthesizeTextDrawingComponent() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        state.reset(to: .analysis, anchorTime: now, anchorPrice: 100)
        state.note = "Breakout retest is holding above prior resistance."
        state.upsertComponent(
            .levelSupport,
            payload: .levelSupport(LevelPayload(price: 99.5, label: "Support"))
        )

        let request = state.buildCreateRequest(symbolId: UUID(), timeframe: "5m")

        #expect(request.note == "Breakout retest is holding above prior resistance.")
        #expect(request.components.contains { $0.componentType == RLComponentType.textNote.rawValue } == false)
        #expect(request.components.contains { $0.componentType == RLComponentType.levelSupport.rawValue })
    }

    @Test
    func editSessionLocksAnchorButAllowsIndicatorsAndDrawings() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let anchor = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: now, price: 101.5)),
            ordering: 0
        )

        let marker = makeMarkerUI(
            intent: .personal,
            title: "Editable Marker",
            visibility: "private",
            components: [anchor],
            isCurrentUserMarker: true,
            canEdit: true
        )

        let state = MarkerPlacementState()
        state.beginEditingMarker(marker)

        #expect(state.isEditingExistingMarker)
        #expect(state.editingMarkerId == marker.id)
        #expect(state.isAnchorLocked)
        #expect(state.selectedPlacementTab == .components)

        let originalAnchorPrice = state.anchorDraft?.payload.levelPrice
        let originalAnchorTime = state.anchorDraft?.payload.anchorTime

        state.upsertComponent(
            .anchor,
            payload: .anchor(
                AnchorPayload(
                    time: now.addingTimeInterval(300),
                    price: 777
                )
            )
        )

        #expect(state.anchorDraft?.payload.levelPrice == originalAnchorPrice)
        #expect(state.anchorDraft?.payload.anchorTime == originalAnchorTime)

        state.upsertComponent(
            .indicator,
            payload: .indicator(
                IndicatorPayload(
                    name: "rsi",
                    settings: ["length": AnyCodable(14)],
                    isPrimary: nil
                )
            )
        )
        #expect(state.component(.indicator) != nil)

        state.upsertComponent(
            .drawingZone,
            payload: .drawingZone(
                ZonePayload(
                    topPrice: 103,
                    bottomPrice: 99,
                    startTime: now.addingTimeInterval(-120),
                    endTime: now.addingTimeInterval(120)
                )
            )
        )
        #expect(state.component(.drawingZone) != nil)

        let updateRequest = state.buildUpdateRequest()
        #expect(updateRequest.intent == nil)
        if let anchorRequest = updateRequest.components?.first(where: { $0.componentType == RLComponentType.anchor.rawValue }) {
            let decoded = MarkerComponentPayload.decode(
                componentType: anchorRequest.componentType,
                rawPayload: anchorRequest.payload
            )
            #expect(decoded.levelPrice == originalAnchorPrice)
            #expect(decoded.anchorTime == originalAnchorTime)
        } else {
            Issue.record("Expected anchor component in edit-session update request")
        }
    }

    @Test
    func switchingAwayFromReactionIntentRemovesReactionEmojiState() {
        let state = MarkerPlacementState()
        let anchorTime = Date(timeIntervalSince1970: 1_700_000_000)

        state.reset(to: .reaction, anchorTime: anchorTime, anchorPrice: 101.25)
        state.upsertComponent(
            .reactionEmoji,
            payload: .reactionEmoji(state.anchoredEmojiPayload(emoji: "🔥"))
        )

        guard case let .reactionEmoji(payload)? = state.component(.reactionEmoji)?.payload else {
            Issue.record("Expected reaction emoji draft before switching intents")
            return
        }
        #expect(payload.emoji == "🔥")

        state.setIntent(.analysis)

        #expect(state.intent == .analysis)
        #expect(state.component(.reactionEmoji) == nil)

        let request = state.buildCreateRequest(
            symbolId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            timeframe: RLChartTimeframe.h1.toBackendString()
        )
        #expect(request.components.contains(where: { $0.componentType == RLComponentType.reactionEmoji.rawValue }) == false)
    }

    @Test
    func chartMarkerUINormalizesMissingAnnotationAnchors() {
        let anchorTime = Date(timeIntervalSince1970: 1_700_000_321)
        let anchorPrice = 104.75
        let components = [
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.anchor.rawValue,
                payload: .anchor(AnchorPayload(time: anchorTime, price: anchorPrice)),
                ordering: 0
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.textNote.rawValue,
                payload: .note(NotePayload(text: "Hold here")),
                ordering: 1
            ),
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.reactionEmoji.rawValue,
                payload: .reactionEmoji(EmojiPayload(emoji: "🔥")),
                ordering: 2
            ),
        ]

        let marker = makeMarkerDTO(
            author: makeMember(
                userId: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                username: "author"
            ),
            intent: .reaction,
            title: "Anchor Fix",
            components: components,
            candleTimestamp: anchorTime
        )
        let normalized = ChartMarkerUI(marker: marker, candleIndex: 12)

        let notePayload = normalized.marker.components.first {
            $0.componentType == RLComponentType.textNote.rawValue
        }?.payload
        let emojiPayload = normalized.marker.components.first {
            $0.componentType == RLComponentType.reactionEmoji.rawValue
        }?.payload

        if case let .note(note)? = notePayload {
            #expect(note.anchorTime == anchorTime)
            #expect(note.anchorPrice == anchorPrice)
        } else {
            Issue.record("Expected normalized note payload")
        }

        if case let .reactionEmoji(emoji)? = emojiPayload {
            #expect(emoji.anchorTime == anchorTime)
            #expect(emoji.anchorPrice == anchorPrice)
        } else {
            Issue.record("Expected normalized reaction emoji payload")
        }
    }

    @Test
    func chartDrawingManagerCanCreateAnchoredEmojiAndNoteDrawings() {
        let manager = ChartDrawingManager()
        let anchor = ChartDrawingPoint(
            time: Date(timeIntervalSince1970: 1_700_001_000),
            price: 99.25
        )

        _ = manager.addDrawing(
            type: .textNote,
            points: [anchor],
            colorHex: ChartDrawingType.textNote.defaultColorHex,
            note: "Anchored note"
        )
        _ = manager.addDrawing(
            type: .emoji,
            points: [anchor],
            colorHex: ChartDrawingType.emoji.defaultColorHex,
            emoji: "🔥"
        )

        let noteDrawing = manager.drawings.first { $0.type == .textNote }
        let emojiDrawing = manager.drawings.first { $0.type == .emoji }

        #expect(noteDrawing?.points == [anchor])
        #expect(emojiDrawing?.points == [anchor])
    }

    @Test
    func legacyAnnotationNormalizationFreezesMissingPointAtFallbackOnce() {
        let fallbackTime = Date(timeIntervalSince1970: 1_700_002_000)
        let fallbackPrice = 108.5
        let original = ChartDrawing(
            type: .emoji,
            colorHex: ChartDrawingType.emoji.defaultColorHex,
            emoji: "🔥"
        )

        let normalized = ChartDrawingBridge.normalizedAnnotationDrawing(
            from: original,
            fallbackAnchorTime: fallbackTime,
            fallbackAnchorPrice: fallbackPrice
        )

        #expect(normalized.points == [ChartDrawingPoint(time: fallbackTime, price: fallbackPrice)])

        let laterFallback = Date(timeIntervalSince1970: 1_700_003_000)
        let frozen = ChartDrawingBridge.normalizedAnnotationDrawing(
            from: normalized,
            fallbackAnchorTime: laterFallback,
            fallbackAnchorPrice: 999
        )

        #expect(frozen.points == normalized.points)
    }

    @Test
    func prePlacementSnapshotRetainsMirrorSourceAndAttachesIndicators() {
        var activeBeforePlacement = ActiveIndicators()
        activeBeforePlacement.rsi = RSIConfig(period: 14)
        let mirroredDrawings = [
            ChartDrawing(
                type: .horizontalLine,
                points: [ChartDrawingPoint(time: Date(timeIntervalSince1970: 1_700_000_000), price: 42000)],
                colorHex: "#10B981",
                note: "Line"
            )
        ]

        var snapshot = PlacementIndicatorSnapshot()
        snapshot.captureIfNeeded(from: activeBeforePlacement, drawings: mirroredDrawings)

        #expect(snapshot.didCapture)
        #expect(snapshot.payloads.contains { $0.name.uppercased().contains("RSI") })
        #expect(snapshot.drawings.count == 1)

        // A second capture attempt should not overwrite the first snapshot.
        snapshot.captureIfNeeded(from: ActiveIndicators(), drawings: [])
        #expect(snapshot.payloads.contains { $0.name.uppercased().contains("RSI") })
        #expect(snapshot.drawings.count == 1)

        let state = MarkerPlacementState()
        let result = state.attachActiveChartIndicators(snapshot.payloads)
        #expect(result.added == 1)
        #expect(state.indicatorDrafts.contains { draft in
            guard case let .indicator(payload) = draft.payload else { return false }
            return payload.name.uppercased().contains("RSI")
        })

        let drawingResult = state.attachActiveChartDrawings(snapshot.drawings)
        #expect(drawingResult.added == 1)
        #expect(state.components.contains { $0.componentType == .drawingHorizontalLine })
    }

    @Test
    func copyChartDrawingsPreservesZoneAndTextColors() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_003_600)
        let drawings = [
            ChartDrawing(
                type: .zone,
                points: [
                    ChartDrawingPoint(time: start, price: 1.25),
                    ChartDrawingPoint(time: end, price: 1.20),
                ],
                colorHex: "#F43F5E",
                lineStyle: .solid,
                lineWidth: 2.0
            ),
            ChartDrawing(
                type: .textNote,
                points: [ChartDrawingPoint(time: start, price: 1.22)],
                colorHex: "#38BDF8",
                note: "Watch reaction",
                offsetX: 12,
                offsetY: -6,
                fontSize: 18
            ),
        ]

        let state = MarkerPlacementState()
        let result = state.attachActiveChartDrawings(drawings)

        #expect(result.added == 2)
        if case let .drawingZone(payload)? = state.components.first(where: { $0.componentType == .drawingZone })?.payload {
            #expect(payload.colorHex == "#F43F5E")
            #expect(payload.lineStyle == .solid)
            #expect(payload.lineWidth == 2.0)
            #expect(state.drawingColorHex(for: drawings[0].id) == "#F43F5E")
        } else {
            Issue.record("Expected copied zone payload")
        }

        if case let .note(payload)? = state.components.first(where: { $0.componentType == .textNote })?.payload {
            #expect(payload.colorHex == "#38BDF8")
            #expect(payload.fontSize == 18)
            #expect(payload.offsetX == 12)
            #expect(payload.offsetY == -6)
            #expect(state.drawingColorHex(for: drawings[1].id) == "#38BDF8")
        } else {
            Issue.record("Expected copied text note payload")
        }
    }

    @Test
    func legendSummaryIncludesPanelIndicators() {
        var active = ActiveIndicators()
        active.rsi = RSIConfig(period: 14)
        active.macd = MACDConfig(fastPeriod: 12, slowPeriod: 26, signalPeriod: 9)

        let labels = ActiveIndicatorsLegendComposer.labels(from: active)
        #expect(labels.contains("RSI(14)"))
        #expect(labels.contains("MACD(12,26,9)"))
    }

    @Test
    func drawingLegendSummaryIncludesLineAndAnnotationEntries() {
        let drawings = [
            ChartDrawing(
                type: .supportLevel,
                points: [ChartDrawingPoint(time: Date(timeIntervalSince1970: 1_700_000_000), price: 101.25)],
                colorHex: "#10B981",
                note: "Support"
            ),
            ChartDrawing(
                type: .emoji,
                colorHex: "#F59E0B",
                emoji: "🔥"
            ),
        ]

        let labels = ChartDrawingsLegendComposer.labels(from: drawings) { price in
            String(format: "%.2f", price)
        }

        #expect(labels.contains("Support 101.25"))
        #expect(labels.contains("🔥"))
    }

    @Test
    func collapsedPanelReserveSkipsBottomLabelStrip() {
        let collapsedStackReserve = ChartPanelReserveCalculator.stackReserve(panelHeights: [0])
        #expect(abs(collapsedStackReserve - 22) < 0.0001)

        let bottomBoundaryStrip = ChartPanelReserveCalculator.bottomBoundaryLabelReserve(
            indicatorPanelHeights: [0],
            timeframePanelHeights: []
        )
        #expect(bottomBoundaryStrip == 0)

        let normalized = ChartPanelReserveCalculator.normalizedPanelReserve(
            totalPanelReserve: collapsedStackReserve,
            bottomBoundaryLabelReserve: bottomBoundaryStrip
        )
        #expect(abs(normalized - 22) < 0.0001)
    }

    @Test
    func tinyPanelHeightDoesNotTriggerBottomStripOrReserveJitter() {
        let nearZeroStackReserve = ChartPanelReserveCalculator.stackReserve(panelHeights: [0.9])
        #expect(abs(nearZeroStackReserve - 22) < 0.0001)

        let bottomBoundaryStrip = ChartPanelReserveCalculator.bottomBoundaryLabelReserve(
            indicatorPanelHeights: [0.9],
            timeframePanelHeights: []
        )
        #expect(bottomBoundaryStrip == 0)
    }

    @Test
    func timeframePanelReserveIncludesAxisStripForEveryExpandedPanel() {
        let twoPanelReserve = ChartPanelReserveCalculator.timeframeStackReserve(panelHeights: [120, 130])
        let expectedReserve = CGFloat(120 + 130)
            + CGFloat(2) * ChartPanelReserveCalculator.panelResizeHandleHeight
            + CGFloat(2) * ChartPanelReserveCalculator.panelXAxisLabelStripHeight
        #expect(abs(twoPanelReserve - expectedReserve) < 0.0001)

        let layout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [120, 130],
            indicatorPanelHeights: []
        )
        #expect(layout.indicatorAxisPanelIndex == nil)
        #expect(layout.bottomBoundaryOwner == .timeframe(index: 1))
        #expect(layout.bottomBoundaryLabelReserve == 0)
        #expect(layout.mainChartXAxisClearance == ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
        #expect(abs(layout.totalReserve - expectedReserve) < 0.0001)
    }

    @Test
    func timeframePanelGestureStateTracksXAxisAndYAxisIndependently() {
        let state = TimeframePanelGestureState()
        state.applyPinch(scale: 1.5)
        let xZoom = state.candleWidthScale
        let xPan = state.panOffset

        state.applyVerticalPan(deltaY: 40, panelHeight: 180)
        state.applyPricePinch(scale: 1.4, panelHeight: 180)

        #expect(state.candleWidthScale == xZoom)
        #expect(state.panOffset == xPan)
        #expect(state.verticalPanOffset > 0)
        #expect(state.priceScale > 1)
    }

    @Test
    func timeframePanelGestureStateRecentersVerticalPanAndZoom() {
        let state = TimeframePanelGestureState()
        state.applyVerticalPan(deltaY: 48, panelHeight: 180)
        state.applyPricePinch(scale: 1.8, panelHeight: 180)

        #expect(state.verticalPanOffset != 0)
        #expect(state.priceScale > 1)

        state.recenterVertical(resetScale: true)

        #expect(state.verticalPanOffset == 0)
        #expect(state.priceScale == 1)
    }

    @Test
    func annotationBubbleMetricsPreserveExplicitNewlinesAndWrapLongText() {
        let multiline = "line 1\nline 2"
        #expect(ChartAnnotationBubbleMetrics.visibleLineCount(for: multiline, plotWidth: 220) == 2)

        let longText = "Watch for liquidity sweep confirmation before chasing this candle higher"
        #expect(ChartAnnotationBubbleMetrics.visibleLineCount(for: longText, plotWidth: 120) > 1)
        #expect(ChartAnnotationBubbleMetrics.maxBubbleWidth(plotWidth: 500) == ChartAnnotationBubbleMetrics.maxWidth)

        let center = CGPoint(x: 100, y: 100)
        let rect = ChartAnnotationBubbleMetrics.hitRect(
            center: center,
            text: multiline,
            plotWidth: 220,
            touchExpansion: 0
        )
        #expect(rect.contains(center))
        #expect(rect.height >= ChartAnnotationBubbleMetrics.lineHeight * 2 + ChartAnnotationBubbleMetrics.verticalPadding * 2)
    }

    @Test
    func timeframePriceViewportKeepsCandleHeightStableAcrossPanelResize() {
        let smallPanel = TimeframePanelPriceViewport(
            rawPriceRange: (min: 100, max: 200),
            topPadding: 18,
            bottomPadding: 4,
            visualHeight: 80,
            scaleBasisHeight: 140,
            priceScale: 1,
            verticalPanOffset: 0
        )
        let tallPanel = TimeframePanelPriceViewport(
            rawPriceRange: (min: 100, max: 200),
            topPadding: 18,
            bottomPadding: 4,
            visualHeight: 250,
            scaleBasisHeight: 140,
            priceScale: 1,
            verticalPanOffset: 0
        )
        let scaledPanel = TimeframePanelPriceViewport(
            rawPriceRange: (min: 100, max: 200),
            topPadding: 18,
            bottomPadding: 4,
            visualHeight: 80,
            scaleBasisHeight: 140,
            priceScale: 1.6,
            verticalPanOffset: 0
        )

        let smallBodyHeight = abs(smallPanel.yPosition(for: 130) - smallPanel.yPosition(for: 120))
        let tallBodyHeight = abs(tallPanel.yPosition(for: 130) - tallPanel.yPosition(for: 120))
        let scaledBodyHeight = abs(scaledPanel.yPosition(for: 130) - scaledPanel.yPosition(for: 120))

        #expect(abs(smallBodyHeight - tallBodyHeight) < 0.0001)
        #expect(scaledBodyHeight > smallBodyHeight)
    }

    @Test
    func timeframePanelSourcesStayIsolatedAcrossModeSwitches() {
        let manager = TimeframePanelManager()

        manager.replacePanels(
            for: .chartDefaults,
            backendValues: ["1h"],
            symbolId: nil,
            guildId: nil
        )

        guard let chartPanel = manager.panels(for: .chartDefaults).first else {
            Issue.record("Expected chart-default timeframe panel")
            return
        }

        chartPanel.collapse()

        manager.replacePanels(
            for: .markerPlacement,
            backendValues: ["4h"],
            symbolId: nil,
            guildId: nil,
            resetPresentationState: true
        )

        let chartPanels = manager.panels(for: .chartDefaults)
        let placementPanels = manager.panels(for: .markerPlacement)

        #expect(chartPanels.count == 1)
        #expect(chartPanels.first?.timeframe == .h1)
        #expect(chartPanels.first?.isCollapsed == true)
        #expect(placementPanels.count == 1)
        #expect(placementPanels.first?.timeframe == .h4)
        #expect(placementPanels.first?.isCollapsed == false)
        #expect(abs((placementPanels.first?.currentHeight ?? 0) - TimeframePanelManager.defaultPanelHeight) < 0.001)
    }

    @Test
    func removedCollapsedPanelDoesNotPoisonNewTimeframeEntryState() {
        let manager = TimeframePanelManager()

        manager.replacePanels(
            for: .markerPlacement,
            backendValues: ["1h"],
            symbolId: nil,
            guildId: nil,
            resetPresentationState: true
        )

        guard let existingPanel = manager.panels(for: .markerPlacement).first else {
            Issue.record("Expected placement timeframe panel")
            return
        }

        existingPanel.collapse()
        #expect(existingPanel.isCollapsed)
        #expect(existingPanel.currentHeight == 0)

        manager.replacePanels(
            for: .markerPlacement,
            backendValues: [],
            symbolId: nil,
            guildId: nil
        )
        manager.replacePanels(
            for: .markerPlacement,
            backendValues: ["4h", "1d"],
            symbolId: nil,
            guildId: nil
        )

        let replacementPanels = manager.panels(for: .markerPlacement)
        #expect(replacementPanels.count == 2)
        #expect(replacementPanels.allSatisfy { !$0.isCollapsed })
        #expect(replacementPanels.allSatisfy {
            abs($0.currentHeight - TimeframePanelManager.defaultPanelHeight) < 0.001
        })
    }

    @Test
    func timeframeLegendTracksOnlyTheActiveSourcePanels() {
        let manager = TimeframePanelManager()

        manager.replacePanels(
            for: .chartDefaults,
            backendValues: ["1h"],
            symbolId: nil,
            guildId: nil
        )
        manager.replacePanels(
            for: .markerPlacement,
            backendValues: ["4h", "1d"],
            symbolId: nil,
            guildId: nil
        )

        manager.setActiveSource(.markerPlacement)
        #expect(TimeframeLegendComposer.labels(from: manager.panels) == ["TF 4H", "TF 1D"])

        manager.setActiveSource(.chartDefaults)
        #expect(TimeframeLegendComposer.labels(from: manager.panels) == ["TF 1H"])
    }

    @Test
    func timeframeLegendTextPartsSplitPrefixFromToken() {
        let fifteenMinute = TimeframeLegendTextParts.split("TF 15m")
        #expect(fifteenMinute.prefix == "TF ")
        #expect(fifteenMinute.token == "15m")

        let daily = TimeframeLegendTextParts.split("TF 1D")
        #expect(daily.prefix == "TF ")
        #expect(daily.token == "1D")

        let fallback = TimeframeLegendTextParts.split("RSI(14)")
        #expect(fallback.prefix.isEmpty)
        #expect(fallback.token == "RSI(14)")
    }

    @Test
    func timeframePanelLockStatePersistsForReusedEntryButResetsForReplacement() {
        let manager = TimeframePanelManager()

        manager.replacePanels(
            for: .chartDefaults,
            backendValues: ["1h"],
            symbolId: nil,
            guildId: nil
        )

        guard let originalPanel = manager.panels(for: .chartDefaults).first else {
            Issue.record("Expected chart-default timeframe panel")
            return
        }

        originalPanel.isLockedToMainChart = true
        originalPanel.collapse()

        manager.replacePanels(
            for: .chartDefaults,
            backendValues: ["1h"],
            symbolId: nil,
            guildId: nil,
            resetPresentationState: true
        )

        let reusedPanel = manager.panels(for: .chartDefaults).first
        #expect(reusedPanel?.id == originalPanel.id)
        #expect(reusedPanel?.isLockedToMainChart == true)
        #expect(reusedPanel?.isCollapsed == false)

        manager.replacePanels(
            for: .chartDefaults,
            backendValues: [],
            symbolId: nil,
            guildId: nil
        )
        manager.replacePanels(
            for: .chartDefaults,
            backendValues: ["1h"],
            symbolId: nil,
            guildId: nil
        )

        let replacementPanel = manager.panels(for: .chartDefaults).first
        #expect(replacementPanel?.id != originalPanel.id)
        #expect(replacementPanel?.isLockedToMainChart == false)
    }

    @Test
    func lockedTimeframeViewportCentersVisibleDateRangeAndClampsToLoadedData() {
        let timeframeSeconds: TimeInterval = 3_600
        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let candles = (0..<10).map { index in
            makeTestCandle(
                timestamp: firstTimestamp.addingTimeInterval(Double(index) * timeframeSeconds),
                close: 100 + Double(index)
            )
        }

        let visibleStart = firstTimestamp.addingTimeInterval(2 * timeframeSeconds)
        let visibleEnd = firstTimestamp.addingTimeInterval(6 * timeframeSeconds)
        let resolution = TimeframePanelLockedViewport.resolution(
            candles: candles,
            timeframeSeconds: timeframeSeconds,
            mainChartVisibleStart: visibleStart,
            mainChartVisibleEnd: visibleEnd,
            plotWidth: 80,
            historicalRenderIndexOffset: 0,
            candleWidthScale: 1,
            baseCandleWidth: 12,
            candleSpacing: 4,
            minScale: 0.15,
            maxScale: 3
        )

        #expect(abs((resolution?.candleWidthScale ?? 0) - 1.0) < 0.0001)
        #expect(abs((resolution?.panOffsetWidth ?? 0) - (-30)) < 0.0001)
        #expect(abs((resolution?.centerIndex ?? 0) - 4.0) < 0.0001)

        let halfStepIndex = TimeframePanelLockedViewport.fractionalIndex(
            for: firstTimestamp.addingTimeInterval(2.5 * timeframeSeconds),
            in: candles,
            timeframeSeconds: timeframeSeconds
        )
        #expect(abs(halfStepIndex - 2.5) < 0.0001)

        let outOfRangeResolution = TimeframePanelLockedViewport.resolution(
            candles: candles,
            timeframeSeconds: timeframeSeconds,
            mainChartVisibleStart: firstTimestamp.addingTimeInterval(-20 * timeframeSeconds),
            mainChartVisibleEnd: firstTimestamp.addingTimeInterval(-16 * timeframeSeconds),
            plotWidth: 80,
            historicalRenderIndexOffset: 0,
            candleWidthScale: 1,
            baseCandleWidth: 12,
            candleSpacing: 4,
            minScale: 0.15,
            maxScale: 3
        )
        #expect(outOfRangeResolution?.centerIndex == 0)
        #expect(abs((outOfRangeResolution?.panOffsetWidth ?? 0) - 34) < 0.0001)
    }

    @Test
    func timeframeLockIsUnavailableForPanelsLowerThanMainChartTimeframe() {
        #expect(TimeframePanelLockedViewport.canLockToMainChart(panelTimeframeSeconds: 60, mainChartTimeframeSeconds: 300) == false)
        #expect(TimeframePanelLockedViewport.canLockToMainChart(panelTimeframeSeconds: 300, mainChartTimeframeSeconds: 300) == true)
        #expect(TimeframePanelLockedViewport.canLockToMainChart(panelTimeframeSeconds: 900, mainChartTimeframeSeconds: 300) == true)
    }

    @Test
    func centeredTimeframePriceRangeUsesCandlesAroundResolvedMainChartCenter() {
        let timeframeSeconds: TimeInterval = 3_600
        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let candles = (0..<10).map { index in
            makeTestCandle(
                timestamp: firstTimestamp.addingTimeInterval(Double(index) * timeframeSeconds),
                close: 100 + Double(index)
            )
        }

        let range = TimeframePanelLockedViewport.centeredPriceRange(
            candles: candles,
            centerIndex: 4,
            plotWidth: 80,
            candleWidthScale: 1,
            baseCandleWidth: 12,
            candleSpacing: 4
        )

        #expect(abs((range?.min ?? 0) - 97.12) < 0.0001)
        #expect(abs((range?.max ?? 0) - 109.88) < 0.0001)
    }

    @Test
    func timeframeCenterWaitsForOlderCandlesWhenTargetTimeIsBeforeLoadedWindow() {
        let timeframeSeconds: TimeInterval = 60
        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let candles = (0..<10).map { index in
            makeTestCandle(
                timestamp: firstTimestamp.addingTimeInterval(Double(index) * timeframeSeconds),
                close: 100 + Double(index)
            )
        }

        let visibleStart = firstTimestamp.addingTimeInterval(-10 * timeframeSeconds)
        let visibleEnd = firstTimestamp.addingTimeInterval(-6 * timeframeSeconds)
        let centerTime = TimeframePanelLockedViewport.visibleCenterDate(
            mainChartVisibleStart: visibleStart,
            mainChartVisibleEnd: visibleEnd
        )

        #expect(centerTime == firstTimestamp.addingTimeInterval(-8 * timeframeSeconds))
        #expect(TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: centerTime!,
            candles: candles,
            hasMoreHistoricalCandles: true
        ) == true)
        #expect(TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: centerTime!,
            candles: candles,
            hasMoreHistoricalCandles: false
        ) == false)
        #expect(TimeframePanelLockedViewport.needsOlderCandlesToCenter(
            targetTime: firstTimestamp.addingTimeInterval(4 * timeframeSeconds),
            candles: candles,
            hasMoreHistoricalCandles: true
        ) == false)
    }

    @Test
    func timeframeHistoricalWindowEndTimeCentersTargetTimestampInFetchedPage() {
        let target = Date(timeIntervalSince1970: 1_700_000_000)
        let endTime = TimeframePanelHistoricalWindow.centeredEndTime(
            for: target,
            timeframeSeconds: 60,
            candleLimit: 1_000
        )

        #expect(endTime == target.addingTimeInterval(500 * 60))
    }

    @Test
    func timeframeVisiblePriceRangeTracksPannedCandleWindow() {
        let firstTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let candles = [
            makeTestCandle(timestamp: firstTimestamp, close: 100),
            makeTestCandle(timestamp: firstTimestamp.addingTimeInterval(60), close: 102),
            makeTestCandle(timestamp: firstTimestamp.addingTimeInterval(120), close: 1_000),
            makeTestCandle(timestamp: firstTimestamp.addingTimeInterval(180), close: 1_010),
        ]

        let firstWindow = TimeframePanelLockedViewport.visiblePriceRange(
            candles: candles,
            visibleStartIndex: 0,
            visibleCandleCount: 2
        )
        let pannedWindow = TimeframePanelLockedViewport.visiblePriceRange(
            candles: candles,
            visibleStartIndex: 2,
            visibleCandleCount: 2
        )

        #expect((firstWindow?.max ?? 0) < 110)
        #expect((pannedWindow?.min ?? 0) > 900)
    }

    @Test
    func timeframeMarkerLabelHugsBottomAndStaysReadableAtEdges() {
        let panelSize = CGSize(width: 180, height: 120)
        let centered = TimeframePanelMarkerLabelLayout.bottomLabelRect(
            centerX: 90,
            panelSize: panelSize
        )
        #expect(centered.minY > 90)
        #expect(centered.midX == 90)

        let edge = TimeframePanelMarkerLabelLayout.bottomLabelRect(
            centerX: 4,
            panelSize: panelSize
        )
        #expect(edge.minX >= TimeframePanelMarkerLabelLayout.horizontalInset)
        #expect(TimeframePanelMarkerLabelLayout.textPoint(for: edge).y == edge.midY)
    }

    @Test
    func multiSeriesLegendEntriesExposeAllExpectedSwatches() {
        var active = ActiveIndicators()
        active.macd = MACDConfig(showHistogram: true, showSignalLine: true)
        active.stochastic = StochasticConfig()
        active.volume = VolumeConfig(showMA: true)
        active.parabolicSAR = ParabolicSARConfig()

        let entries = ActiveIndicatorsLegendComposer.entries(from: active)

        let macdEntry = entries.first { $0.text == "MACD(12,26,9)" }
        #expect(macdEntry?.swatches.count == 4)

        let stochasticEntry = entries.first { $0.text == "Stoch(14,3)" }
        #expect(stochasticEntry?.swatches.count == 2)

        let volumeEntry = entries.first { $0.text == "VOL(MA20)" }
        #expect(volumeEntry?.swatches.count == 3)

        let sarEntry = entries.first { $0.text == "SAR" }
        #expect(sarEntry?.swatches.count == 2)
    }

    @Test
    func liveSetupMetricsLongSetupUsesExpectedPositionOrdering() {
        guard let metrics = LiveSetupMetrics.compute(
            entryPrice: 100,
            stopLossPrice: 95,
            targetPrice: 110,
            currentPrice: 104
        ) else {
            Issue.record("Expected long setup live metrics")
            return
        }

        #expect(metrics.isLong)
        #expect(metrics.stopLossPosition < metrics.entryPosition)
        #expect(metrics.entryPosition < metrics.targetPosition)
        #expect(metrics.isMovingTowardTarget)
    }

    @Test
    func liveSetupMetricsShortSetupUsesExpectedPositionOrdering() {
        guard let metrics = LiveSetupMetrics.compute(
            entryPrice: 100,
            stopLossPrice: 105,
            targetPrice: 90,
            currentPrice: 103
        ) else {
            Issue.record("Expected short setup live metrics")
            return
        }

        #expect(!metrics.isLong)
        #expect(metrics.targetPosition < metrics.entryPosition)
        #expect(metrics.entryPosition < metrics.stopLossPosition)
        #expect(!metrics.isMovingTowardTarget)
    }

    @Test
    func liveSetupMetricsFallbackUsesEntryWhenLivePriceMissing() {
        guard let metrics = LiveSetupMetrics.compute(
            entryPrice: 100,
            stopLossPrice: 95,
            targetPrice: 110,
            currentPrice: nil as Double?
        ) else {
            Issue.record("Expected setup live metrics with nil current price")
            return
        }

        #expect(metrics.currentPosition == metrics.entryPosition)
        #expect(!metrics.isMovingTowardTarget)
    }

    @Test
    func setupCorePriceLineLayoutKeepsHandlesInPlotButLetsChipReachYAxis() {
        let layout = SetupCorePriceLineLayout(renderWidth: 320, plotWidth: 261)
        let labelRect = layout.labelRect(centerY: 120)

        #expect(abs(layout.lineEndX - labelRect.maxX) < 0.0001)
        #expect(abs(layout.fillWidth - layout.lineEndX) < 0.0001)
        #expect(abs(layout.plotHandleCenterX - 130.5) < 0.0001)
        #expect(labelRect.minX < layout.plotWidth)
    }

    @Test
    func editModePreviewDragResolverIgnoresDragCandidate() {
        let lockedIndex = MarkerPlacementPreviewDragResolver.resolvedPreviewIndex(
            isEditingExistingMarker: true,
            currentIndex: 44,
            candidateIndex: 88,
            candleCount: 120
        )
        #expect(lockedIndex == 44)

        let movedIndex = MarkerPlacementPreviewDragResolver.resolvedPreviewIndex(
            isEditingExistingMarker: false,
            currentIndex: 44,
            candidateIndex: 88,
            candleCount: 120
        )
        #expect(movedIndex == 88)
    }

    @Test
    func placementPreviewDragResolverKeepsLastValidIndexForInvalidCandidates() {
        let negativeCandidate = MarkerPlacementPreviewDragResolver.resolvedPreviewIndex(
            isEditingExistingMarker: false,
            currentIndex: 44,
            candidateIndex: -1,
            candleCount: 120
        )
        #expect(negativeCandidate == 44)

        let offEndCandidate = MarkerPlacementPreviewDragResolver.resolvedPreviewIndex(
            isEditingExistingMarker: false,
            currentIndex: 44,
            candidateIndex: 120,
            candleCount: 120
        )
        #expect(offEndCandidate == 44)
    }

    @Test
    func placementPreviewDragLocationStaysInsideRenderablePlot() {
        let lowerLeft = MarkerPlacementPreviewDragResolver.clampedDragLocation(
            CGPoint(x: -500, y: 999),
            plotSize: CGSize(width: 300, height: 220)
        )
        #expect(abs(lowerLeft.x - 46) < 0.0001)
        #expect(abs(lowerLeft.y - 174) < 0.0001)

        let upperRight = MarkerPlacementPreviewDragResolver.clampedDragLocation(
            CGPoint(x: 500, y: -999),
            plotSize: CGSize(width: 300, height: 220)
        )
        #expect(abs(upperRight.x - 254) < 0.0001)
        #expect(abs(upperRight.y - 46) < 0.0001)

        let tinyPlot = MarkerPlacementPreviewDragResolver.clampedDragLocation(
            CGPoint(x: -20, y: 80),
            plotSize: CGSize(width: 60, height: 40)
        )
        #expect(abs(tinyPlot.x - 30) < 0.0001)
        #expect(abs(tinyPlot.y - 20) < 0.0001)
    }

    @Test
    func placementPreviewPositionClampsInsideViewport() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let candles = [makeTestCandle(timestamp: timestamp, close: 100)]

        let position = MarkerPositionCalculator.calculatePreviewPosition(
            candleIndex: 0,
            existingMarkers: [],
            candles: candles,
            candleHighY: 2,
            candleLowY: 12,
            centerX: 40,
            priceScale: 1,
            viewportHeight: 100
        ).position

        #expect(position.y >= MarkerVisualSpec.baseCanvasDiameter / 2)
    }

    @Test
    func setupMarkersRemainPlaceableEvenWithDirectionalMismatch() {
        let state = MarkerPlacementState()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        state.reset(to: .setup, anchorTime: now, anchorPrice: 100)

        state.trackingEnabled = true
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 90, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 95, label: "SL")))

        #expect(state.isValid)
    }

    @Test
    func updateMarkerFromPlacementUsesUpdatePathAndRollsBackOnFailure() async {
        let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let member = makeMember(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "tester")
        let markerId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let anchor = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: now, price: 100)),
            ordering: 0
        )

        let manager = MarkerManager(userId: member.userId, guildId: guildId, currentUserMember: member)
        manager.markers = [
            makeMarkerUI(
                id: markerId,
                intent: .personal,
                title: "Original",
                visibility: "private",
                components: [anchor],
                isCurrentUserMarker: true,
                canEdit: true
            ),
        ]

        let api = MarkerPlacementUpdateFakeAPI()
        api.updateResponse = makeMarkerDTO(
            id: markerId,
            author: member,
            intent: .personal,
            title: "Updated",
            visibility: "private",
            trackingEnabled: true,
            components: [anchor],
            candleTimestamp: now
        )

        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)

        let updateRequest = RLUpdateMarkerRequest(
            intent: nil,
            title: "Updated",
            note: nil,
            visibility: "private",
            confidence: nil,
            trackingEnabled: true,
            components: [RLMarkerComponentRequest(componentType: anchor.componentType, payload: anchor.payload.rawPayload)]
        )

        let firstSuccess = await manager.updateMarkerFromPlacement(id: markerId, request: updateRequest)
        #expect(firstSuccess.isSuccess)
        #expect(api.updateCalls == 1)
        #expect(api.createCalls == 0)
        #expect(manager.markers.first?.title == "Updated")

        api.shouldFailUpdate = true
        let failedRequest = RLUpdateMarkerRequest(
            intent: nil,
            title: "Broken Title",
            note: nil,
            visibility: "private",
            confidence: nil,
            trackingEnabled: true,
            components: [RLMarkerComponentRequest(componentType: anchor.componentType, payload: anchor.payload.rawPayload)]
        )

        let secondSuccess = await manager.updateMarkerFromPlacement(id: markerId, request: failedRequest)
        #expect(secondSuccess == .failure(.genericUpdateFailure))
        #expect(api.updateCalls == 2)
        #expect(api.createCalls == 0)
        #expect(manager.markers.first?.title == "Updated")
    }

    @Test
    func analysisNewsQuestionAndAlertValidationFollowPlanRules() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let analysisState = MarkerPlacementState()
        analysisState.reset(to: .analysis, anchorTime: now, anchorPrice: 100)
        #expect(!analysisState.isValid)
        analysisState.note = "Detailed bias shift"
        #expect(!analysisState.isValid)
        analysisState.upsertComponent(
            .timeframeLink,
            payload: .timeframeLink(TimeframeLinkPayload(timeframe: "4h", note: "Higher timeframe"))
        )
        #expect(analysisState.isValid)

        let newsState = MarkerPlacementState()
        newsState.reset(to: .news, anchorTime: now, anchorPrice: 100)
        newsState.newsURL = "https://example.com/news"
        #expect(!newsState.isValid)
        newsState.upsertComponent(
            .linkURL,
            payload: .link(LinkPayload(url: "https://example.com/news", title: nil, previewImage: nil))
        )
        #expect(newsState.isValid)

        let questionState = MarkerPlacementState()
        questionState.reset(to: .question, anchorTime: now, anchorPrice: 100)
        questionState.note = "Too short"
        #expect(!questionState.isValid)
        questionState.note = "Will this breakout hold?"
        #expect(questionState.isValid)

        let alertState = MarkerPlacementState()
        alertState.reset(to: .alert, anchorTime: now, anchorPrice: 100)
        alertState.alertSeverity = .critical
        alertState.note = "[Critical] short"
        #expect(!alertState.isValid)
        alertState.note = "[Critical] Market structure failed"
        #expect(alertState.isValid)
    }

    @Test
    func reactionUpdateReconcilesSelectedEmojiAcrossPersistedMarkerState() async {
        let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let member = makeMember(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "tester")
        let markerId = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let anchor = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: now, price: 100)),
            ordering: 0
        )
        let initialEmoji = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.reactionEmoji.rawValue,
            payload: .reactionEmoji(EmojiPayload(emoji: "🎯")),
            ordering: 1
        )
        let updatedEmoji = RLMarkerComponentDTO(
            id: initialEmoji.id,
            componentType: RLComponentType.reactionEmoji.rawValue,
            payload: .reactionEmoji(EmojiPayload(emoji: "🔥")),
            ordering: 1
        )

        let manager = MarkerManager(userId: member.userId, guildId: guildId, currentUserMember: member)
        manager.markers = [
            makeMarkerUI(
                id: markerId,
                intent: .reaction,
                title: "Reaction",
                visibility: "guild",
                components: [anchor, initialEmoji],
                isCurrentUserMarker: true,
                canEdit: true,
                author: member
            ),
        ]

        let api = MarkerPlacementUpdateFakeAPI()
        api.updateResponse = makeMarkerDTO(
            id: markerId,
            author: member,
            intent: .reaction,
            title: "Reaction",
            visibility: "guild",
            trackingEnabled: false,
            components: [anchor, updatedEmoji],
            isCurrentUserMarker: true,
            canEdit: true,
            candleTimestamp: now
        )
        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)

        let request = RLUpdateMarkerRequest(
            intent: nil,
            title: "Reaction",
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: false,
            components: [
                RLMarkerComponentRequest(componentType: anchor.componentType, payload: anchor.payload.rawPayload),
                RLMarkerComponentRequest(componentType: updatedEmoji.componentType, payload: updatedEmoji.payload.rawPayload),
            ]
        )

        let result = await manager.updateMarkerFromPlacement(id: markerId, request: request)
        #expect(result.isSuccess)
        #expect(manager.markers.first?.selectedEmoji == "🔥")
    }

    @Test
    func editableMarkersUseOwnershipAndCanEditOnly() {
        let ownedEditableAnalysis = makeMarkerUI(
            intent: .analysis,
            title: "Owned analysis",
            isCurrentUserMarker: true,
            canEdit: true
        )
        let ownedLockedPersonal = makeMarkerUI(
            intent: .personal,
            title: "Owned locked",
            isCurrentUserMarker: true,
            canEdit: false
        )
        let foreignEditablePersonal = makeMarkerUI(
            intent: .personal,
            title: "Foreign personal",
            isCurrentUserMarker: false,
            canEdit: true
        )

        #expect(ownedEditableAnalysis.isEditableByCurrentUser)
        #expect(!ownedLockedPersonal.isEditableByCurrentUser)
        #expect(!foreignEditablePersonal.isEditableByCurrentUser)
    }

    @Test
    func placementPreviewIndexLocksToInitialCenterUntilExplicitReposition() {
        let initial = MarkerPlacementPreviewIndexResolver.fixedPreviewIndex(
            currentPreviewIndex: -1,
            centerIndex: 42,
            candleCount: 120
        )
        #expect(initial == 42)

        let afterPan = MarkerPlacementPreviewIndexResolver.fixedPreviewIndex(
            currentPreviewIndex: initial,
            centerIndex: 88,
            candleCount: 120
        )
        #expect(afterPan == 42)
    }

    @Test
    func placementOffsetMigrationOnlyRemapsLegacyDefault() {
        let suiteName = "MarkerDisplaySettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(
            MarkerDisplaySettings.placementExtraOffsetLegacyDefault,
            forKey: MarkerDisplaySettings.keyPlacementExtraOffset
        )
        defaults.set(false, forKey: MarkerDisplaySettings.keyPlacementOffsetMigrated)
        let migrated = MarkerDisplaySettings(userDefaults: defaults)
        #expect(abs(migrated.placementExtraOffset - MarkerDisplaySettings.placementExtraOffsetDefault) < 0.0001)

        defaults.set(31, forKey: MarkerDisplaySettings.keyPlacementExtraOffset)
        defaults.set(false, forKey: MarkerDisplaySettings.keyPlacementOffsetMigrated)
        let customPreserved = MarkerDisplaySettings(userDefaults: defaults)
        #expect(abs(customPreserved.placementExtraOffset - 31) < 0.0001)
    }

    @Test
    func pollQuestionResolutionUsesFallbackOrder() {
        let withQuestion = makeMarkerUI(
            intent: .poll,
            title: "Fallback title",
            note: "Fallback note",
            pollQuestion: "Primary question"
        )
        let withNote = makeMarkerUI(
            intent: .poll,
            title: "Fallback title",
            note: "Fallback note",
            pollQuestion: nil
        )
        let withTitle = makeMarkerUI(
            intent: .poll,
            title: "Fallback title",
            note: nil,
            pollQuestion: nil
        )

        #expect(withQuestion.resolvedPollQuestion == "Primary question")
        #expect(withNote.resolvedPollQuestion == "Fallback note")
        #expect(withTitle.resolvedPollQuestion == "Fallback title")
    }

    @Test
    func optimisticCreatePreservesPollQuestionWhenServerPayloadOmitsIt() async {
        let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let member = makeMember(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "creator")
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let manager = MarkerManager(userId: member.userId, guildId: guildId, currentUserMember: member)
        let api = MarkerPlacementUpdateFakeAPI()
        api.createResponse = makeMarkerDTO(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            author: member,
            intent: .poll,
            title: "Server Poll",
            note: "Fallback note",
            visibility: "guild",
            trackingEnabled: false,
            components: [
                RLMarkerComponentDTO(
                    id: UUID(),
                    componentType: RLComponentType.anchor.rawValue,
                    payload: .anchor(AnchorPayload(time: timestamp, price: 100)),
                    ordering: 0
                ),
            ],
            isCurrentUserMarker: true,
            canEdit: true,
            pollQuestion: nil,
            pollOptions: nil,
            candleTimestamp: timestamp
        )
        manager.configure(api: api, symbolId: symbolId, timeframe: .h1)

        let request = RLCreateMarkerRequest(
            symbolId: symbolId,
            timeframe: RLChartTimeframe.h1.toBackendString(),
            intent: RLMarkerIntent.poll.rawValue,
            title: "Client Poll",
            note: "Fallback note",
            visibility: "guild",
            confidence: nil,
            trackingEnabled: false,
            components: [
                RLMarkerComponentRequest(
                    componentType: RLComponentType.anchor.rawValue,
                    payload: ["time": AnyCodable(timestamp), "price": AnyCodable(100.0)]
                ),
            ],
            pollQuestion: "Will this breakout hold?",
            pollOptions: ["Yes", "No"]
        )
        let candles = [
            RLCandleDTO(
                timestamp: timestamp,
                timestampFormatted: nil,
                open: 99,
                high: 101,
                low: 98,
                close: 100,
                volume: 1_000,
                volumeFormatted: nil
            ),
        ]

        let success = await manager.addMarkerV2(
            request: request,
            candleIndex: 0,
            candles: candles
        )
        #expect(success.isSuccess)
        #expect(api.createCalls == 1)

        guard let created = manager.markers.first else {
            Issue.record("Expected optimistic-create marker in manager")
            return
        }
        #expect(created.pollQuestion == "Will this breakout hold?")
        #expect(created.pollOptions?.map(\.text) == ["Yes", "No"])
    }

    @Test
    func pollStyleTokensMatchSharedPaletteForAllSurfaces() {
        #expect(colorDistance(rgba(MarkerPollStyleTokens.selectedAccent), rgba(AppColors.statusInfo95)) < 0.02)
        #expect(colorDistance(rgba(MarkerPollStyleTokens.selectedBackground), rgba(AppColors.statusInfo20)) < 0.02)
        #expect(colorDistance(rgba(MarkerPollStyleTokens.selectedBorder), rgba(AppColors.statusInfo52)) < 0.02)
        #expect(colorDistance(rgba(MarkerPollStyleTokens.unselectedCount), rgba(AppColors.greyText)) < 0.02)
    }

    @Test
    func combinedPanelLayoutUsesLastExpandedPanelForBottomAxisOwnership() {
        let handle = ChartPanelReserveCalculator.panelResizeHandleHeight
        let strip = ChartPanelReserveCalculator.panelXAxisLabelStripHeight
        let gap = ChartPanelReserveCalculator.panelStackChartUniformGap
        let baseline = ChartPanelReserveCalculator.mainChartControlRowBaselineClearance
        let controlBase = ChartPanelReserveCalculator.chartControlRowXAxisBaseOffset

        func expectedControlReserve(totalReserve: CGFloat, mainChartClearance: CGFloat) -> CGFloat {
            max(
                0,
                totalReserve
                    + ChartPanelReserveCalculator.panelStackBottomSpacerClearance(
                        mainChartXAxisClearance: mainChartClearance
                    )
                    + gap
                    - controlBase
            )
        }

        let noPanelsLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: []
        )
        #expect(noPanelsLayout.indicatorAxisPanelIndex == nil)
        #expect(noPanelsLayout.bottomBoundaryOwner == nil)
        #expect(noPanelsLayout.totalReserve == 0)
        #expect(noPanelsLayout.bottomBoundaryLabelReserve == 0)
        #expect(noPanelsLayout.mainChartXAxisClearance == 0)
        #expect(noPanelsLayout.controlRowReserve == baseline)

        let collapsedIndicatorLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: [0]
        )
        #expect(collapsedIndicatorLayout.indicatorAxisPanelIndex == nil)
        #expect(collapsedIndicatorLayout.bottomBoundaryOwner == nil)
        #expect(collapsedIndicatorLayout.totalReserve == handle)
        #expect(collapsedIndicatorLayout.bottomBoundaryLabelReserve == 0)
        #expect(collapsedIndicatorLayout.mainChartXAxisClearance == strip)
        #expect(collapsedIndicatorLayout.controlRowReserve == expectedControlReserve(
            totalReserve: handle,
            mainChartClearance: strip
        ))

        let collapsedTimeframeLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [0],
            indicatorPanelHeights: []
        )
        #expect(collapsedTimeframeLayout.indicatorAxisPanelIndex == nil)
        #expect(collapsedTimeframeLayout.bottomBoundaryOwner == nil)
        #expect(collapsedTimeframeLayout.totalReserve == handle)
        #expect(collapsedTimeframeLayout.bottomBoundaryLabelReserve == 0)
        #expect(collapsedTimeframeLayout.mainChartXAxisClearance == strip)
        #expect(collapsedTimeframeLayout.controlRowReserve == expectedControlReserve(
            totalReserve: handle,
            mainChartClearance: strip
        ))

        let oneExpandedIndicatorLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: [120]
        )
        let expectedOneExpandedIndicatorReserve = CGFloat(120) + handle
        #expect(oneExpandedIndicatorLayout.indicatorAxisPanelIndex == nil)
        #expect(oneExpandedIndicatorLayout.bottomBoundaryOwner == nil)
        #expect(oneExpandedIndicatorLayout.bottomBoundaryLabelReserve == 0)
        #expect(oneExpandedIndicatorLayout.mainChartXAxisClearance == strip)
        #expect(abs(oneExpandedIndicatorLayout.totalReserve - expectedOneExpandedIndicatorReserve) < 0.0001)
        #expect(abs(oneExpandedIndicatorLayout.controlRowReserve - expectedControlReserve(
            totalReserve: expectedOneExpandedIndicatorReserve,
            mainChartClearance: strip
        )) < 0.0001)

        let twoExpandedIndicatorsLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: [120, 130]
        )
        let expectedTwoExpandedIndicatorsReserve = CGFloat(120 + 130)
            + CGFloat(2) * handle
        #expect(twoExpandedIndicatorsLayout.indicatorAxisPanelIndex == nil)
        #expect(twoExpandedIndicatorsLayout.bottomBoundaryOwner == nil)
        #expect(twoExpandedIndicatorsLayout.bottomBoundaryLabelReserve == 0)
        #expect(twoExpandedIndicatorsLayout.mainChartXAxisClearance == strip)
        #expect(abs(twoExpandedIndicatorsLayout.totalReserve - expectedTwoExpandedIndicatorsReserve) < 0.0001)
        #expect(abs(twoExpandedIndicatorsLayout.controlRowReserve - expectedControlReserve(
            totalReserve: expectedTwoExpandedIndicatorsReserve,
            mainChartClearance: strip
        )) < 0.0001)

        let timeframeOwnedLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [140],
            indicatorPanelHeights: [0]
        )
        let expectedTimeframeOwnedReserve = CGFloat(140)
            + CGFloat(2) * handle
            + strip
        #expect(timeframeOwnedLayout.indicatorAxisPanelIndex == nil)
        #expect(timeframeOwnedLayout.bottomBoundaryOwner == nil)
        #expect(timeframeOwnedLayout.bottomBoundaryLabelReserve == 0)
        #expect(timeframeOwnedLayout.mainChartXAxisClearance == strip)
        #expect(abs(timeframeOwnedLayout.totalReserve - expectedTimeframeOwnedReserve) < 0.0001)
        #expect(abs(timeframeOwnedLayout.controlRowReserve - expectedControlReserve(
            totalReserve: expectedTimeframeOwnedReserve,
            mainChartClearance: strip
        )) < 0.0001)

        let timeframeAndExpandedIndicatorLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [120],
            indicatorPanelHeights: [130]
        )
        let expectedTimeframeAndExpandedIndicatorReserve = CGFloat(120 + 130)
            + CGFloat(2) * handle
            + strip
        #expect(timeframeAndExpandedIndicatorLayout.indicatorAxisPanelIndex == nil)
        #expect(timeframeAndExpandedIndicatorLayout.bottomBoundaryOwner == nil)
        #expect(timeframeAndExpandedIndicatorLayout.bottomBoundaryLabelReserve == 0)
        #expect(timeframeAndExpandedIndicatorLayout.mainChartXAxisClearance == strip)
        #expect(abs(timeframeAndExpandedIndicatorLayout.totalReserve - expectedTimeframeAndExpandedIndicatorReserve) < 0.0001)
        #expect(abs(timeframeAndExpandedIndicatorLayout.controlRowReserve - expectedControlReserve(
            totalReserve: expectedTimeframeAndExpandedIndicatorReserve,
            mainChartClearance: strip
        )) < 0.0001)

        let indicatorOwnedLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [120],
            indicatorPanelHeights: [0, 130, 0]
        )
        let expectedIndicatorOwnedReserve = CGFloat(120 + 130)
            + CGFloat(4) * handle
            + strip
        #expect(indicatorOwnedLayout.indicatorAxisPanelIndex == nil)
        #expect(indicatorOwnedLayout.bottomBoundaryOwner == nil)
        #expect(indicatorOwnedLayout.bottomBoundaryLabelReserve == 0)
        #expect(indicatorOwnedLayout.mainChartXAxisClearance == strip)
        #expect(abs(indicatorOwnedLayout.totalReserve - expectedIndicatorOwnedReserve) < 0.0001)
        #expect(abs(indicatorOwnedLayout.controlRowReserve - expectedControlReserve(
            totalReserve: expectedIndicatorOwnedReserve,
            mainChartClearance: strip
        )) < 0.0001)
    }

    @Test
    func combinedPanelLayoutCountsEveryCollapsedIndicatorHandle() {
        let handle = ChartPanelReserveCalculator.panelResizeHandleHeight
        let strip = ChartPanelReserveCalculator.panelXAxisLabelStripHeight
        let gap = ChartPanelReserveCalculator.panelStackChartUniformGap
        let controlBase = ChartPanelReserveCalculator.chartControlRowXAxisBaseOffset

        func expectedControlReserve(totalReserve: CGFloat, mainChartClearance: CGFloat) -> CGFloat {
            max(
                0,
                totalReserve
                    + ChartPanelReserveCalculator.panelStackBottomSpacerClearance(
                        mainChartXAxisClearance: mainChartClearance
                    )
                    + gap
                    - controlBase
            )
        }

        let topExpandedBottomCollapsed = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: [120, 0]
        )
        let topExpandedBottomCollapsedReserve = CGFloat(120) + CGFloat(2) * handle
        #expect(topExpandedBottomCollapsed.indicatorAxisPanelIndex == nil)
        #expect(topExpandedBottomCollapsed.bottomBoundaryOwner == nil)
        #expect(topExpandedBottomCollapsed.totalReserve == topExpandedBottomCollapsedReserve)
        #expect(topExpandedBottomCollapsed.bottomBoundaryLabelReserve == 0)
        #expect(topExpandedBottomCollapsed.mainChartXAxisClearance == strip)
        #expect(topExpandedBottomCollapsed.controlRowReserve == expectedControlReserve(
            totalReserve: topExpandedBottomCollapsedReserve,
            mainChartClearance: strip
        ))

        let topCollapsedBottomExpanded = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: [0, 120]
        )
        let topCollapsedBottomExpandedReserve = CGFloat(120) + CGFloat(2) * handle
        #expect(topCollapsedBottomExpanded.indicatorAxisPanelIndex == nil)
        #expect(topCollapsedBottomExpanded.bottomBoundaryOwner == nil)
        #expect(topCollapsedBottomExpanded.totalReserve == topCollapsedBottomExpandedReserve)
        #expect(topCollapsedBottomExpanded.bottomBoundaryLabelReserve == 0)
        #expect(topCollapsedBottomExpanded.mainChartXAxisClearance == strip)
        #expect(topCollapsedBottomExpanded.controlRowReserve == expectedControlReserve(
            totalReserve: topCollapsedBottomExpandedReserve,
            mainChartClearance: strip
        ))

        let allCollapsed = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [],
            indicatorPanelHeights: [0, 0]
        )
        #expect(allCollapsed.indicatorAxisPanelIndex == nil)
        #expect(allCollapsed.bottomBoundaryOwner == nil)
        #expect(allCollapsed.totalReserve == CGFloat(2) * handle)
        #expect(allCollapsed.bottomBoundaryLabelReserve == 0)
        #expect(allCollapsed.mainChartXAxisClearance == strip)
        #expect(allCollapsed.controlRowReserve == expectedControlReserve(
            totalReserve: CGFloat(2) * handle,
            mainChartClearance: strip
        ))
    }

    @Test
    func indicatorPanelPresentationMatchesTimeframeCollapseRestoreRules() {
        let collapsed = ChartPanelPresentationPolicy.collapsed(
            currentHeight: 132,
            expandedHeight: 90,
            minHeight: 80
        )
        #expect(collapsed.currentHeight == 0)
        #expect(collapsed.expandedHeight == 132)
        #expect(collapsed.isCollapsed)

        let expanded = ChartPanelPresentationPolicy.expanded(
            expandedHeight: collapsed.expandedHeight,
            minHeight: 80,
            maxHeight: 120
        )
        #expect(expanded.currentHeight == 120)
        #expect(expanded.expandedHeight == 120)
        #expect(!expanded.isCollapsed)

        let clampedCollapsed = ChartPanelPresentationPolicy.clamped(
            currentHeight: 0,
            expandedHeight: 180,
            minHeight: 80,
            maxHeight: 140
        )
        #expect(clampedCollapsed.currentHeight == 0)
        #expect(clampedCollapsed.expandedHeight == 140)
        #expect(clampedCollapsed.isCollapsed)

        let newlyActive = ChartPanelPresentationPolicy.restoredActiveHeight(
            currentHeight: 0,
            expandedHeight: 0,
            defaultHeight: 120,
            minHeight: 80,
            maxHeight: 140
        )
        #expect(newlyActive.currentHeight == 120)
        #expect(newlyActive.expandedHeight == 120)
        #expect(!newlyActive.isCollapsed)
    }

    @Test
    func markerNotificationFallbackPayloadAndStopLossStylingStayRoutable() {
        let notification = makeMarkerResultNotification(resultType: "stop_loss", includeCandleTimestamp: false)

        guard let payload = notification.markerNavigationPayload else {
            Issue.record("Expected fallback marker navigation payload")
            return
        }

        #expect(payload.markerId == UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!)
        #expect(payload.symbolId == UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
        #expect(payload.timeframe == "5m")
        #expect(payload.candleTimestamp == notification.createdAt)

        if case .symbolChart(let symbolId, let ticker) = notification.navigationDestination {
            #expect(symbolId == UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
            #expect(ticker == "EURUSD")
        } else {
            Issue.record("Expected symbol-chart navigation destination")
        }

        #expect(colorDistance(rgba(notification.accentColor), rgba(AppColors.statusNegative85)) < 0.02)
        guard let semanticBorderColor = notification.semanticBorderColor else {
            Issue.record("Expected stop-loss semantic border color")
            return
        }
        #expect(colorDistance(rgba(semanticBorderColor), rgba(AppColors.statusNegative40)) < 0.02)
    }

    @Test
    func markerPlacementFailureMapsTrackedSetupBackendErrors() {
        #expect(
            MarkerPlacementFailure.from(
                error: APIError.badRequest("tracked_setup_conflict_symbol_timeframe"),
                fallback: .genericCreateFailure
            ) == .trackedSetupConflictSymbolTimeframe
        )
        #expect(
            MarkerPlacementFailure.from(
                error: APIError.serverError(400, "tracked_setup_limit_reached"),
                fallback: .genericCreateFailure
            ) == .trackedSetupLimitReached
        )
        #expect(
            MarkerPlacementFailure.from(
                error: APIError.badRequest("something_else"),
                fallback: .genericUpdateFailure
            ) == .genericUpdateFailure
        )
    }

    @Test
    func addMarkerPreflightRejectsDuplicateOpenTrackedSetupForSameSymbolAndTimeframe() async {
        let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let member = makeMember(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "creator")
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = MarkerManager(userId: member.userId, guildId: guildId, currentUserMember: member)

        manager.markers = [
            makeMarkerUI(
                intent: .setup,
                title: "Existing tracked setup",
                components: [
                    RLMarkerComponentDTO(
                        id: UUID(),
                        componentType: RLComponentType.anchor.rawValue,
                        payload: .anchor(AnchorPayload(time: timestamp, price: 100)),
                        ordering: 0
                    ),
                ],
                trackingEnabled: true,
                trackingState: .active,
                author: member,
                symbolId: symbolId,
                timeframe: RLChartTimeframe.h1.toBackendString()
            )
        ]

        let request = RLCreateMarkerRequest(
            symbolId: symbolId,
            timeframe: RLChartTimeframe.h1.toBackendString(),
            intent: RLMarkerIntent.setup.rawValue,
            title: "New tracked setup",
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: true,
            components: [
                RLMarkerComponentRequest(
                    componentType: RLComponentType.anchor.rawValue,
                    payload: ["time": AnyCodable(timestamp), "price": AnyCodable(100.0)]
                ),
                RLMarkerComponentRequest(
                    componentType: RLComponentType.levelEntry.rawValue,
                    payload: ["price": AnyCodable(100.0), "label": AnyCodable("Entry")]
                ),
                RLMarkerComponentRequest(
                    componentType: RLComponentType.levelSl.rawValue,
                    payload: ["price": AnyCodable(95.0), "label": AnyCodable("SL")]
                ),
                RLMarkerComponentRequest(
                    componentType: RLComponentType.levelTp.rawValue,
                    payload: ["price": AnyCodable(110.0), "label": AnyCodable("TP")]
                ),
            ],
            pollQuestion: nil,
            pollOptions: nil
        )

        let candles = [
            RLCandleDTO(
                timestamp: timestamp,
                timestampFormatted: nil,
                open: 99,
                high: 101,
                low: 98,
                close: 100,
                volume: 1_000,
                volumeFormatted: nil
            ),
        ]

        let result = await manager.addMarkerV2(
            request: request,
            candleIndex: 0,
            candles: candles
        )

        #expect(result == .failure(.trackedSetupConflictSymbolTimeframe))
        #expect(manager.markers.count == 1)
    }

    @Test
    func setupSelectionPreflightRejectsDuplicateOpenTrackedSetupBeforePlacement() {
        let guildId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let member = makeMember(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "creator")
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = MarkerManager(userId: member.userId, guildId: guildId, currentUserMember: member)

        manager.markers = [
            makeMarkerUI(
                intent: .setup,
                title: "Existing tracked setup",
                components: [
                    RLMarkerComponentDTO(
                        id: UUID(),
                        componentType: RLComponentType.anchor.rawValue,
                        payload: .anchor(AnchorPayload(time: timestamp, price: 100)),
                        ordering: 0
                    ),
                ],
                trackingEnabled: true,
                trackingState: .armed,
                author: member,
                symbolId: symbolId,
                timeframe: RLChartTimeframe.h1.toBackendString()
            )
        ]

        let preflightFailure = manager.preflightPlacementFailure(
            for: .setup,
            symbolId: symbolId,
            timeframe: RLChartTimeframe.h1.toBackendString(),
            trackingEnabled: true
        )

        #expect(preflightFailure == .trackedSetupConflictSymbolTimeframe)
    }

    @Test
    func secondaryPriceChipMetricsStaySmallerThanCurrentPriceChip() {
        #expect(ChartAxisMetrics.secondaryPriceChipHeight < ChartAxisMetrics.currentPriceChipHeight)
        #expect(ChartAxisMetrics.secondaryPriceChipWidth < ChartAxisMetrics.horizontalLabeledChipWidth)
        #expect(ChartAxisMetrics.secondaryPriceChipHorizontalPadding < ChartAxisMetrics.horizontalPriceChipHorizontalPadding)
        #expect(ChartAxisMetrics.setupCorePriceChipWidth == ChartAxisMetrics.secondaryPriceChipWidth)
        #expect(ChartAxisMetrics.setupCorePriceChipHeight == ChartAxisMetrics.secondaryPriceChipHeight)
    }

    @Test
    func priceLineMaskRespectsTopExclusionHeight() {
        #expect(
            ChartAxisMetrics.priceLineVisibleMaskHeight(
                totalHeight: 300,
                xAxisReservedHeight: 62,
                topExclusionHeight: 84
            ) == 154
        )
        #expect(
            ChartAxisMetrics.priceLineVisibleMaskHeight(
                totalHeight: 90,
                xAxisReservedHeight: 62,
                topExclusionHeight: 84
            ) == 0
        )
    }

    @Test
    func horizontalPriceChipCenterRespectsHeaderExclusion() {
        let topClamped = ChartAxisMetrics.clampedPriceChipCenterY(
            centerY: 18,
            totalHeight: 300,
            chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
            topExclusionHeight: 84
        )
        #expect(abs(topClamped - 99) < 0.0001)

        let inline = ChartAxisMetrics.clampedPriceChipCenterY(
            centerY: 150,
            totalHeight: 300,
            chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
            topExclusionHeight: 84
        )
        #expect(abs(inline - 150) < 0.0001)

        let bottomClamped = ChartAxisMetrics.clampedPriceChipCenterY(
            centerY: 290,
            totalHeight: 300,
            chipHeight: ChartAxisMetrics.secondaryPriceChipHeight,
            topExclusionHeight: 84,
            bottomExclusionHeight: 62
        )
        #expect(abs(bottomClamped - 223) < 0.0001)
    }

    @Test
    func rightDrawerDisclosureExpansionStatePersistsUntilCacheIsCleared() {
        let viewModel = RLRightDrawerViewModel()

        #expect(viewModel.isDisclosureExpanded(.friends) == true)
        viewModel.setDisclosureExpanded(.friends, isExpanded: false)
        viewModel.lastRefresh = Date()
        #expect(viewModel.isDisclosureExpanded(.friends) == false)

        let onlineBinding = viewModel.disclosureBinding(for: .online)
        onlineBinding.wrappedValue = false
        #expect(viewModel.isDisclosureExpanded(.online) == false)

        viewModel.clearCache()
        #expect(viewModel.isDisclosureExpanded(.friends) == true)
        #expect(viewModel.isDisclosureExpanded(.online) == true)
    }
}

private func makeTestCandle(timestamp: Date, close: Double) -> RLCandleDTO {
    RLCandleDTO(
        timestamp: timestamp,
        timestampFormatted: nil,
        open: close - 1,
        high: close + 1,
        low: close - 2,
        close: close,
        volume: 1_000,
        volumeFormatted: nil
    )
}

private final class MarkerPlacementUpdateFakeAPI: MarkerAPIClient {
    var updateCalls = 0
    var createCalls = 0
    var shouldFailUpdate = false
    var createResponse: RLChartMarkerDTO?
    var updateResponse: RLChartMarkerDTO?

    func getMarkers(
        guildId: UUID,
        symbolId: UUID,
        timeframe: String,
        limit: Int,
        cursor: String?,
        startTime: Date?,
        endTime: Date?
    ) async throws -> RLMarkersListDTO {
        fatalError("getMarkers should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        createCalls += 1
        if let createResponse {
            return createResponse
        }
        return updateResponse ?? makeMarkerDTO(author: makeMember(userId: UUID(), username: "fallback"), intent: .analysis)
    }

    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        updateCalls += 1
        if shouldFailUpdate {
            throw MarkerPlacementUpdateError.simulatedFailure
        }
        if let updateResponse {
            return updateResponse
        }
        return makeMarkerDTO(id: markerId, author: makeMember(userId: UUID(), username: "fallback"), intent: .analysis)
    }

    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLDetailResponseDTO {
        fatalError("deleteMarker should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO {
        fatalError("toggleMarkerLike should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO {
        fatalError("voteOnPoll should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func addMarkerComment(
        guildId: UUID,
        markerId: UUID,
        content: String,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO {
        fatalError("addMarkerComment should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func toggleMarkerCommentReaction(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMarkerCommentDTO {
        fatalError("toggleMarkerCommentReaction should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func getMarkerCommentReactionReactors(
        guildId: UUID,
        markerId: UUID,
        commentId: UUID,
        emoji: String
    ) async throws -> RLMessageReactionReactorsDTO {
        fatalError("getMarkerCommentReactionReactors should not be called in MarkerPlacementUpdateFakeAPI")
    }

    func deleteMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID) async throws -> RLDetailResponseDTO {
        fatalError("deleteMarkerComment should not be called in MarkerPlacementUpdateFakeAPI")
    }
}

private enum MarkerPlacementUpdateError: Error {
    case simulatedFailure
}

private func makeMember(userId: UUID, username: String) -> RLGuildMemberDTO {
    RLGuildMemberDTO(
        membershipId: UUID(),
        role: "member",
        reputation: 100,
        contributionScore: 10,
        dateJoined: Date(timeIntervalSince1970: 1_600_000_000),
        accuracyRate: 0.5,
        mutedUntil: nil,
        suspendedUntil: nil,
        userId: userId,
        username: username,
        displayName: username,
        avatarUrl: nil,
        isOnline: true,
        globalReputation: 100,
        isFriend: false,
        friendshipStatus: nil,
        isBlocked: false,
        isBlockedBy: false
    )
}

private func makeMarkerUI(
    id: UUID = UUID(),
    intent: RLMarkerIntent,
    title: String? = nil,
    note: String? = nil,
    visibility: String = "guild",
    components: [RLMarkerComponentDTO]? = nil,
    isCurrentUserMarker: Bool = false,
    canEdit: Bool = false,
    alertSeverity: String? = nil,
    pollQuestion: String? = nil,
    pollOptions: [RLPollOptionDTO]? = nil,
    trackingEnabled: Bool = false,
    trackingState: RLTrackingState? = nil,
    author: RLGuildMemberDTO? = nil,
    symbolId: UUID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
    guildId: UUID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
    timeframe: String = RLChartTimeframe.h1.toBackendString()
) -> ChartMarkerUI {
    let member = author ?? makeMember(userId: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!, username: "author")
    let dto = makeMarkerDTO(
        id: id,
        author: member,
        intent: intent,
        title: title,
        note: note,
        visibility: visibility,
        trackingEnabled: trackingEnabled,
        components: components,
        isCurrentUserMarker: isCurrentUserMarker,
        canEdit: canEdit,
        alertSeverity: alertSeverity,
        pollQuestion: pollQuestion,
        pollOptions: pollOptions,
        symbolId: symbolId,
        guildId: guildId,
        timeframe: timeframe,
        trackingState: trackingState
    )
    return ChartMarkerUI(marker: dto, candleIndex: 0)
}

private func makeMarkerDTO(
    id: UUID = UUID(),
    author: RLGuildMemberDTO,
    intent: RLMarkerIntent,
    title: String? = nil,
    note: String? = nil,
    visibility: String = "guild",
    trackingEnabled: Bool = false,
    components: [RLMarkerComponentDTO]? = nil,
    isCurrentUserMarker: Bool = false,
    canEdit: Bool = false,
    alertSeverity: String? = nil,
    pollQuestion: String? = nil,
    pollOptions: [RLPollOptionDTO]? = nil,
    candleTimestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
    symbolId: UUID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
    guildId: UUID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
    timeframe: String = RLChartTimeframe.h1.toBackendString(),
    trackingState: RLTrackingState? = nil
) -> RLChartMarkerDTO {
    let resolvedComponents: [RLMarkerComponentDTO]
    if let components, !components.isEmpty {
        resolvedComponents = components
    } else {
        resolvedComponents = [
            RLMarkerComponentDTO(
                id: UUID(),
                componentType: RLComponentType.anchor.rawValue,
                payload: .anchor(AnchorPayload(time: candleTimestamp, price: 100)),
                ordering: 0
            ),
        ]
    }

    return RLChartMarkerDTO(
        id: id,
        symbolId: symbolId,
        guildId: guildId,
        author: author,
        candleTimestamp: candleTimestamp,
        timeframe: timeframe,
        price: 100,
        intent: intent.rawValue,
        title: title,
        note: note,
        visibility: visibility,
        confidence: nil,
        trackingEnabled: trackingEnabled,
        trackingState: trackingState?.rawValue,
        alertSeverity: alertSeverity,
        createdAt: candleTimestamp,
        createdAtFormatted: "now",
        isVisible: true,
        likeCount: 0,
        isLikedByCurrentUser: false,
        commentCount: 0,
        comments: [],
        isCurrentUserMarker: isCurrentUserMarker,
        canEdit: canEdit,
        canDelete: canEdit,
        components: resolvedComponents,
        primaryComponentId: resolvedComponents.first?.id,
        pollQuestion: pollQuestion,
        pollOptions: pollOptions,
        userPollVote: nil,
        predictionResult: nil
    )
}

private func makeMarkerResultNotification(
    resultType: String,
    includeCandleTimestamp: Bool
) -> RLNotificationDTO {
    let createdAt = Date(timeIntervalSince1970: 1_700_000_300)
    var data: [String: AnyCodableValue] = [
        "marker_id": .string("CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"),
        "symbol_id": .string("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
        "symbol_ticker": .string("EURUSD"),
        "timeframe": .string("5m"),
        "result_type": .string(resultType),
        "marker_type": .string("setup"),
        "intent": .string("analysis"),
    ]
    if includeCandleTimestamp {
        data["candle_timestamp"] = .string("2026-03-27T15:35:00Z")
    }

    return RLNotificationDTO(
        id: UUID(),
        recipientId: UUID(),
        notificationType: RLNotificationType.markerResult.rawValue,
        title: "Marker Result",
        body: "Result body",
        data: data,
        destination: RLNotificationDestination(
            type: .symbolChart,
            userId: nil,
            guildId: nil,
            symbolId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
            chatroomId: nil,
            announcementId: nil,
            eventId: nil,
            reportId: nil
        ),
        isRead: false,
        readAt: nil,
        viewCount: 0,
        firstViewedAt: nil,
        lastViewedAt: nil,
        createdAt: createdAt,
        updatedAt: createdAt
    )
}

private func rgba(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        return (red, green, blue, alpha)
    }
    return (0, 0, 0, 0)
}

private func colorDistance(
    _ lhs: (CGFloat, CGFloat, CGFloat, CGFloat),
    _ rhs: (CGFloat, CGFloat, CGFloat, CGFloat)
) -> CGFloat {
    let dr = lhs.0 - rhs.0
    let dg = lhs.1 - rhs.1
    let db = lhs.2 - rhs.2
    return sqrt((dr * dr) + (dg * dg) + (db * db))
}
