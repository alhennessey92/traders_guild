import Foundation
import SwiftUI
import UIKit
import Testing
@testable import traders_guild

@MainActor
struct MarkerWorkspaceTests {
    private func draft(_ intent: RLMarkerIntent = .analysis) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        state.prepareGuidedFlow()
        state.reset(to: intent, anchorTime: Date(timeIntervalSince1970: 1770000000), anchorPrice: 100)
        state.note = "A"
        state.captureDraftBaseline()
        return state
    }

    @Test
    func nestedIndicatorValuesIdentityAndScrollBelongToSession() {
        let state = draft()
        let id = state.appendComponent(.indicator, payload: .indicator(IndicatorPayload(name: "EMA", settings: ["period": AnyCodable(20)], isPrimary: false, instanceId: UUID())))
        state.openContext()
        state.beginWorkspaceIndicator(IndicatorCatalogItem(type: .ema), draftID: id)
        let editor = state.workspace.indicatorDraft!
        editor.intValues["period"] = "137"
        state.workspace.scrollAnchors[.indicatorSettings] = "lineWidth"
        state.workspace.textSelections["contextNote"] = NSRange(location: 2, length: 3)
        // Collapsing the sheet is a presenter change; navigation and editor
        // state live in the session and do not move.
        #expect(state.workspaceDestination == .indicatorSettings)
        #expect(state.workspace.indicatorDraft === editor)
        #expect(editor.intValues["period"] == "137")
        #expect(state.workspace.scrollAnchors[.indicatorSettings] == "lineWidth")
        #expect(state.workspace.selectedComponentID == id)
        #expect(state.commitWorkspaceEditor())
        #expect(state.workspaceDestination == .context)
        #expect(state.indicatorDrafts.count == 1)
        guard case .indicator(let payload) = state.components.first(where: { $0.id == id })?.payload else {
            Issue.record("lost exact indicator draft"); return
        }
        #expect(payload.settings?["period"]?.value as? Int == 137)
        #expect(payload.instanceId == editor.context.instanceId)
    }

    @Test
    func cancellingIndicatorDoesNotCreateOrMutateAComponent() {
        let state = draft()
        state.openContext()
        state.openWorkspace(.indicators)
        state.beginWorkspaceIndicator(IndicatorCatalogItem(type: .rsi))
        state.workspace.indicatorDraft?.intValues["period"] = "51"
        #expect(state.hasWorkspaceEdits)
        state.goBack()
        #expect(state.workspaceDestination == .indicators)
        #expect(state.indicatorDrafts.isEmpty)
        #expect(state.workspace.indicatorDraft == nil)
        state.goBack()
        #expect(state.workspaceDestination == .context)
        state.commitWorkspaceEditor()
        #expect(state.guidedStep == .details)
        #expect(state.note == "A")
    }

    @Test(arguments: [RLMarkerIntent.analysis, .question, .setup])
    func capabilityChecksPrecedeEditorAndPayloadCreation(_ intent: RLMarkerIntent) {
        let state = draft(intent)
        #expect(state.workspaceAllows(.indicator))
        #expect(state.workspaceAllows(.textNote))
        #expect(state.workspaceAllows(.timeframeLink))
        #expect(!state.workspaceAllows(.reactionEmoji))
        #expect(!state.workspaceAllows(.anchor))
        #expect(state.workspaceAllows(.linkURL) == (intent == .analysis))
        #expect(state.workspaceAllows(.levelSupport) == (intent == .analysis))
        if intent != .analysis {
            state.beginWorkspaceText(.sourceEditor)
            state.beginWorkspaceLevel(.levelSupport)
            #expect(state.guidedStep == .details)
            #expect(state.component(.linkURL) == nil)
            #expect(state.component(.levelSupport) == nil)
            #expect(!state.beginWorkspaceDrawing(.support))
        }
        #expect(!state.beginWorkspaceDrawing(.rayLine), "future unsupported tool")
    }

    @Test
    func invalidURLNeverCreatesPlaceholderAndCancelKeepsOriginal() {
        let state = draft()
        state.beginWorkspaceText(.sourceEditor)
        state.workspace.editorText = "https://"
        #expect(!state.commitWorkspaceEditor())
        #expect(state.component(.linkURL) == nil)
        state.workspace.editorText = "javascript:alert(1)"
        #expect(!state.workspaceCanCommit)
        state.workspace.editorText = " https://example.com/research "
        state.workspace.editorTitle = "Research"
        #expect(state.commitWorkspaceEditor())
        let before = state.components
        let id = state.component(.linkURL)!.id
        state.beginWorkspaceText(.sourceEditor, componentID: id)
        state.workspace.editorText = "https://example.org/new"
        state.goBack()
        #expect(state.components == before)
    }

    @Test
    func addingAnotherSourceCannotReplaceExistingSavedContext() {
        let state = draft()
        state.beginWorkspaceText(.sourceEditor)
        state.workspace.editorText = "https://example.com/original"
        #expect(state.commitWorkspaceEditor())
        let before = state.components
        #expect(!state.workspaceCanAddSource)
        state.beginWorkspaceText(.sourceEditor)
        #expect(state.guidedStep == .details, "use the existing summary's Edit action")
        #expect(state.components == before)
        let id = state.component(.linkURL)!.id
        state.beginWorkspaceText(.sourceEditor, componentID: id)
        #expect(state.workspace.selectedComponentID == id)
        #expect(state.workspace.editorText == "https://example.com/original")
    }

    @Test
    func chartDrawingCancelRestoresExactComponentAndDoneKeepsIt() {
        let state = draft()
        let id = state.appendComponent(.drawingHorizontalLine, payload: .drawingHorizontalLine(HorizontalLinePayload(price: 101, label: "Shelf")))
        let before = state.components
        state.openContext()
        #expect(state.beginWorkspaceDrawing(.horizontalLine, componentID: id))
        state.setDrawingColorHex("#F43F5E", for: id)
        state.goBack()
        #expect(state.components == before)
        #expect(!state.drawingSession.isActive)
        #expect(state.beginWorkspaceDrawing(.horizontalLine, componentID: id))
        state.setDrawingColorHex("#38BDF8", for: id)
        #expect(state.commitWorkspaceEditor())
        #expect(state.components != before)
        #expect(state.components.contains { $0.id == id })
    }

    @Test
    func horizontalNumericEditorRepricesOnlyItsExactDrawingAndCancelRestoresIt() {
        let state = draft()
        let first = state.appendComponent(.drawingHorizontalLine, payload: .drawingHorizontalLine(HorizontalLinePayload(price: 101, label: "First")))
        let second = state.appendComponent(.drawingHorizontalLine, payload: .drawingHorizontalLine(HorizontalLinePayload(price: 102, label: "Second", colorHex: "#38BDF8", lineStyle: .dashed, lineWidth: 2)))
        let before = state.components
        state.openContext()
        #expect(state.beginWorkspaceDrawing(.horizontalLine, componentID: second))
        let binding = state.workspaceHorizontalPriceBinding(for: second)
        #expect(binding.wrappedValue == 102)
        binding.wrappedValue = 103
        #expect(state.components.first { $0.id == first }?.payload.levelPrice == 101)
        guard case .drawingHorizontalLine(let edited) = state.components.first(where: { $0.id == second })?.payload else { Issue.record("missing second drawing"); return }
        #expect(edited.price == 103 && edited.label == "Second" && edited.colorHex == "#38BDF8" && edited.lineStyle == .dashed && edited.lineWidth == 2)
        state.goBack()
        #expect(state.components == before)
    }

    @Test
    func drawingCancelKeepsLiveSetupRepricingAndOtherDraftWork() {
        let state = draft(.setup)
        state.openContext()
        let before = state.components
        #expect(state.beginWorkspaceDrawing(.horizontalLine))
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: 105)))
        state.note = "Reasoning edited while on chart"
        state.goBack()
        #expect(state.componentPrice(.levelEntry) == 105)
        #expect(state.note == "Reasoning edited while on chart")
        #expect(state.components.count == before.count)
        #expect(state.component(.drawingHorizontalLine) == nil)
    }

    @Test
    func shortAnalysisAndTrimmedQuestionUseDifferentValidation() {
        let state = draft()
        #expect(state.canContinueToReview, "one nonempty Analysis character is enough")
        _ = state.requestGuidedIntentChange(to: .question)
        state.note = "  123456789  "
        #expect(!state.canContinueToReview)
        state.note = "  1234567890  "
        #expect(state.continueToReview())
        state.goBack()
        #expect(state.guidedStep == .details)
    }

    @Test
    func linkedConversionAndReturnKeepParentTextCompatibleContextAndTimeframe() {
        let state = draft()
        let context = MarkerLinkContext(parentMarkerId: MarkerLinkFixtures.uuid(77), parentGuildId: MarkerLinkFixtures.uuid(2),
                                       parentSymbolId: MarkerLinkFixtures.uuid(1), parentCandleTimestamp: Date(timeIntervalSince1970: 1770000000),
                                       parentAuthorDisplayText: "alex", parentTitle: "Shelf", parentIntent: .setup, relationship: .challenges)
        state.beginRespondingTo(context)
        state.title = "A response"
        _ = state.upsertTimeframeLink("4h")
        _ = state.upsertIndicator(name: "RSI", settings: nil)
        let timeframeID = state.timeframeLinkDrafts.first!.id
        let pendingLoad = state.beginResponseTimeframeChange()
        #expect(state.requestGuidedIntentChange(to: .setup) == nil)
        #expect(state.linkSession.context?.parentMarkerId == context.parentMarkerId)
        #expect(state.linkSession.context?.relationship == .challenges)
        #expect(state.responseTimeframeChangeID == pendingLoad)
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: 100)))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 99)))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 102)))
        let warning = state.requestGuidedIntentChange(to: .analysis)!
        #expect(state.intent == .setup, "no incompatible removal before confirmation")
        state.applyGuidedIntentChange(warning)
        #expect(state.intent == .analysis)
        #expect(state.timeframeLinkDrafts.first?.id == timeframeID)
        #expect(state.indicatorDrafts.count == 1)
        #expect(state.title == "A response" && state.note == "A")
        #expect(state.linkSession.context?.relationship == .challenges)
        #expect(state.responseTimeframeChangeID == pendingLoad)
    }

    @Test
    func multilineUpdatesPreserveMarkedCompositionAndApplyCommittedTextAfterward() throws {
        let view = UITextView()
        view.text = "Before "
        view.selectedRange = NSRange(location: 7, length: 0)
        view.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0))
        let marked = try #require(view.markedTextRange)
        let composedText = view.text
        let composedSelection = view.selectedRange
        let markedStart = view.offset(from: view.beginningOfDocument, to: marked.start)
        let editor = MarkerWorkspaceTextEditor(text: .constant("stale draft"),
            selection: .constant(NSRange(location: 0, length: 0)), offset: .constant(.zero),
            placeholder: "Text", onFocus: { _ in })
        editor.updateDraft(in: view)
        #expect(view.text == composedText)
        #expect(view.selectedRange == composedSelection)
        let retained = try #require(view.markedTextRange)
        #expect(view.offset(from: view.beginningOfDocument, to: retained.start) == markedStart)
        view.unmarkText()
        editor.updateDraft(in: view)
        #expect(view.text == "stale draft")
        #expect(view.selectedRange == NSRange(location: 0, length: 0))
    }

    @Test
    func chartLevelHandoffRefusesSetupLevelsAndPreservesNilSavedLabelOnDone() {
        let setup = draft(.setup)
        let setupBefore = setup.components
        setup.beginWorkspaceLevel(.levelEntry, componentID: setup.component(.levelEntry)?.id)
        #expect(!setup.beginWorkspaceLevelChartEditing())
        #expect(setup.components == setupBefore && !setup.drawingSession.isActive)
        let state = draft()
        let id = state.appendComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: 102, label: nil, colorHex: "#38BDF8", lineStyle: .dashed, lineWidth: 2)))
        let before = state.components
        state.openContext(); state.beginWorkspaceLevel(.levelResistance, componentID: id)
        #expect(state.beginWorkspaceLevelChartEditing())
        #expect(state.components == before)
        #expect(state.commitWorkspaceEditor())
        #expect(state.components == before, "Done without adjustment keeps a nil label and saved style")
    }

    @Test
    func newLevelStartsOnTheChartAndCancelRemovesIt() throws {
        let state = draft()
        state.chartLevelSeedPrice = { type, anchor in type == .levelSupport ? anchor - 2.123456 : anchor + 3 }
        state.openContext()
        let before = state.components
        #expect(state.beginWorkspaceLevelOnChart(.levelSupport))
        let id = try #require(state.workspace.selectedComponentID)
        // On the chart at once, below the anchor, rounded as the chart labels it.
        #expect(state.component(.levelSupport)?.id == id)
        #expect(state.component(.levelSupport)?.payload.levelPrice == 97.8765)
        #expect(state.drawingSession.editingDraftId == id)
        #expect(state.isWorkspaceChartToolActive)
        #expect(state.workspace.levelDrawingIsNew)
        // Dragging moves it; Cancel takes it off the chart and the draft.
        #expect(state.updateWorkspaceLevelFromChart(id: id, price: 96))
        state.cancelWorkspaceEditor()
        #expect(state.components == before)
        #expect(!state.drawingSession.isActive)
        #expect(state.workspaceDestination == .context)
        // Again, and Done keeps it where it was dragged, labelled.
        #expect(state.beginWorkspaceLevelOnChart(.levelResistance))
        let resistance = try #require(state.workspace.selectedComponentID)
        #expect(state.component(.levelResistance)?.payload.levelPrice == 103)
        #expect(state.updateWorkspaceLevelFromChart(id: resistance, price: 104.5))
        #expect(state.commitWorkspaceEditor())
        #expect(state.component(.levelResistance)?.payload.levelPrice == 104.5)
        #expect(state.component(.levelResistance)?.payload.guidedLevelPayload?.label == "Resistance")
        #expect(!state.workspace.levelDrawingIsNew && !state.drawingSession.isActive)
        #expect(state.workspaceDestination == .context)
    }

    @Test
    func savedLevelOnTheChartIsPickedUpAndCancelPutsItBack() {
        let state = draft()
        let id = state.appendComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 95, label: "Range low", colorHex: "#10B981", lineStyle: .dotted, lineWidth: 2)))
        state.openContext()
        let before = state.components
        // The tile picks up the one already there; it adds no second support.
        #expect(state.beginWorkspaceLevelOnChart(.levelSupport))
        #expect(state.workspace.selectedComponentID == id && !state.workspace.levelDrawingIsNew)
        #expect(state.drawingSession.editingDraftId == id)
        #expect(state.updateWorkspaceLevelFromChart(id: id, price: 93))
        state.setDrawingColorHex("#F43F5E", for: id)
        state.cancelWorkspaceEditor()
        #expect(state.components == before, "Cancel puts the saved level back exactly")
    }

    @Test
    func levelsNeverStartOnTheChartWhereTheIntentCannotCarryThem() {
        for intent in [RLMarkerIntent.question, .setup] {
            let state = draft(intent)
            let before = state.components
            #expect(!state.beginWorkspaceLevelOnChart(.levelSupport))
            #expect(state.components == before && !state.drawingSession.isActive)
        }
    }

    @Test(arguments: [CGFloat(311), 329, 366])
    func levelLinesStopBeforeTheirPriceChip(_ plotWidth: CGFloat) {
        // The chip is laid out on the full width; the line in the plot area.
        let chipMinX = ChartAxisMetrics.trailingLabelMinX(
            totalWidth: plotWidth + ChartAxisMetrics.yAxisLaneWidth,
            width: ChartAxisMetrics.secondaryPriceChipWidth
        )
        let end = ChartAxisMetrics.lineEndBeforeChip(plotWidth: plotWidth)
        #expect(end < chipMinX && end > chipMinX - 8)
        // The old end ran into the chip's label.
        #expect(ChartAxisMetrics.horizontalLineEndX(totalWidth: plotWidth, labelWidth: ChartAxisMetrics.secondaryPriceChipWidth) > chipMinX)
    }

    @Test
    func chartPricesRoundToTheChartsLabels() {
        #expect(MarkerGuidedFormat.roundedPrice(63780.2493184) == 63780.25)
        #expect(MarkerGuidedFormat.roundedPrice(1.234567) == 1.2346)
        #expect(MarkerGuidedFormat.roundedPrice(0.000123456789) == 0.000123457)
        #expect(MarkerGuidedFormat.roundedPrice(0) == 0)
    }

    @Test
    func incompleteSetupPriceSurvivesNavigationAndPreventsReview() {
        let state = draft(.setup)
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 99)))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 102)))
        state.trackingEnabled = true
        state.workspace.levelInputs[.levelSl] = "99.."
        state.openContext()
        state.goBack()
        #expect(state.workspace.levelInputs[.levelSl] == "99..")
        #expect(!state.canContinueToReview)
        state.workspace.levelInputs[.levelSl] = "99"
        #expect(state.canContinueToReview)
        #expect(state.continueToReview())
    }
}
