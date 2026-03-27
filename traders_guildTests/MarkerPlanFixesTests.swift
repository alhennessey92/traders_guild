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

        let markerNeutralDistance = colorDistance(rgba(neutralMarker.effectiveColor), rgba(neutralAlertColor))
        #expect(markerNeutralDistance < 0.02)

        let severityDistance = colorDistance(rgba(neutralMarker.effectiveColor), rgba(criticalMarker.effectiveColor))
        #expect(severityDistance > 0.12)

        let neutralPalette = RLMarkerIntent.alert.markerPalette(for: nil)
        let criticalPalette = RLMarkerIntent.alert.markerPalette(for: .critical)
        #expect(colorDistance(rgba(neutralPalette[0]), rgba(criticalPalette[0])) > 0.12)
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
    func setupSwingStripMetricsLongSetupUsesTargetTintAndExpectedOrdering() {
        guard let metrics = SetupSwingStripMetrics.compute(
            entryPrice: 100,
            stopLossPrice: 95,
            targetPrice: 110,
            currentPrice: 104
        ) else {
            Issue.record("Expected long setup swing-strip metrics")
            return
        }

        #expect(metrics.isLong)
        #expect(metrics.stopLossPosition < metrics.entryPosition)
        #expect(metrics.entryPosition < metrics.targetPosition)
        #expect(metrics.currentPosition != nil)
        #expect(metrics.tint == .target)
    }

    @Test
    func setupSwingStripMetricsShortSetupUsesStopTintAndExpectedOrdering() {
        guard let metrics = SetupSwingStripMetrics.compute(
            entryPrice: 100,
            stopLossPrice: 105,
            targetPrice: 90,
            currentPrice: 103
        ) else {
            Issue.record("Expected short setup swing-strip metrics")
            return
        }

        #expect(!metrics.isLong)
        #expect(metrics.targetPosition < metrics.entryPosition)
        #expect(metrics.entryPosition < metrics.stopLossPosition)
        #expect(metrics.currentPosition != nil)
        #expect(metrics.tint == .stop)
    }

    @Test
    func setupSwingStripMetricsFallbackOmitsCurrentDotWhenLivePriceMissing() {
        guard let metrics = SetupSwingStripMetrics.compute(
            entryPrice: 100,
            stopLossPrice: 95,
            targetPrice: 110,
            currentPrice: nil
        ) else {
            Issue.record("Expected setup swing-strip fallback metrics")
            return
        }

        #expect(metrics.currentPosition == nil)
        #expect(metrics.tint == .neutral)
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
            candidateIndex: 88
        )
        #expect(lockedIndex == 44)

        let movedIndex = MarkerPlacementPreviewDragResolver.resolvedPreviewIndex(
            isEditingExistingMarker: false,
            currentIndex: 44,
            candidateIndex: 88
        )
        #expect(movedIndex == 88)
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
        #expect(firstSuccess == .success)
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
        #expect(success == .success)
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
        let timeframeOwnedLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [140],
            indicatorPanelHeights: [0]
        )
        #expect(timeframeOwnedLayout.bottomOwner == .timeframe(index: 0))
        #expect(timeframeOwnedLayout.bottomBoundaryLabelReserve == 0)
        #expect(abs(timeframeOwnedLayout.totalReserve - 208) < 0.0001)

        let indicatorOwnedLayout = ChartPanelReserveCalculator.combinedLayout(
            timeframePanelHeights: [120],
            indicatorPanelHeights: [0, 130, 0]
        )
        #expect(indicatorOwnedLayout.bottomOwner == .indicator(index: 1))
        #expect(indicatorOwnedLayout.bottomBoundaryLabelReserve == ChartPanelReserveCalculator.panelXAxisLabelStripHeight)
        #expect(abs(indicatorOwnedLayout.totalReserve - 340) < 0.0001)
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
    func secondaryPriceChipMetricsStaySmallerThanCurrentPriceChip() {
        #expect(ChartAxisMetrics.secondaryPriceChipHeight < ChartAxisMetrics.currentPriceChipHeight)
        #expect(ChartAxisMetrics.secondaryPriceChipWidth < ChartAxisMetrics.horizontalLabeledChipWidth)
        #expect(ChartAxisMetrics.secondaryPriceChipHorizontalPadding < ChartAxisMetrics.horizontalPriceChipHorizontalPadding)
        #expect(ChartAxisMetrics.setupCorePriceChipWidth == ChartAxisMetrics.secondaryPriceChipWidth)
        #expect(ChartAxisMetrics.setupCorePriceChipHeight == ChartAxisMetrics.secondaryPriceChipHeight)
    }
}

private final class MarkerPlacementUpdateFakeAPI: RealAPIService {
    var updateCalls = 0
    var createCalls = 0
    var shouldFailUpdate = false
    var createResponse: RLChartMarkerDTO?
    var updateResponse: RLChartMarkerDTO?

    override func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        createCalls += 1
        if let createResponse {
            return createResponse
        }
        return updateResponse ?? makeMarkerDTO(author: makeMember(userId: UUID(), username: "fallback"), intent: .analysis)
    }

    override func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        updateCalls += 1
        if shouldFailUpdate {
            throw MarkerPlacementUpdateError.simulatedFailure
        }
        if let updateResponse {
            return updateResponse
        }
        return makeMarkerDTO(id: markerId, author: makeMember(userId: UUID(), username: "fallback"), intent: .analysis)
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
        userPollVote: nil
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
