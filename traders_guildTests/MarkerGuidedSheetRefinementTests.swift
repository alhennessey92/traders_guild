import Foundation
import Testing
@testable import traders_guild

/// The v1.5 bottom-sheet refinement: the guided flow names its step, asks one
/// question, and says in plain words what is still needed before Review.
@MainActor
struct MarkerGuidedSheetRefinementTests {

    private let candles = MarkerLinkFixtures.candles()
    private var anchorCandle: RLCandleDTO { candles[5] }

    private func guidedDraft(_ intent: RLMarkerIntent, response: Bool = false) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        if response {
            state.beginRespondingTo(MarkerLinkContext(
                parentMarkerId: MarkerLinkFixtures.uuid(77),
                parentGuildId: MarkerLinkFixtures.uuid(2),
                parentSymbolId: MarkerLinkFixtures.uuid(1),
                parentCandleTimestamp: anchorCandle.timestamp,
                parentAuthorDisplayText: "sam",
                parentTitle: "BTC breakout",
                parentIntent: .analysis,
                relationship: .supports
            ))
        }
        state.prepareGuidedFlow()
        state.reset(to: intent, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)
        state.captureDraftBaseline()
        return state
    }

    private func setLevels(_ state: MarkerPlacementState, tp: Double, sl: Double) {
        let entry = anchorCandle.close
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: entry, label: "Entry")))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: entry + tp, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: entry + sl, label: "SL")))
    }

    // MARK: Titles and steps

    @Test
    func theToolbarNamesTheTaskAndTheSheetNamesTheStep() {
        let analysis = guidedDraft(.analysis)
        #expect(analysis.guidedToolbarTitle == "New Analysis")
        #expect(analysis.guidedStepNumber == 1)
        #expect(analysis.guidedStepPrompt == "What are you seeing?")

        analysis.note = "Higher lows into the open."
        #expect(analysis.continueToReview())
        #expect(analysis.guidedToolbarTitle == "New Analysis", "the task title stays put across steps")
        #expect(analysis.guidedStepNumber == 2)
        #expect(analysis.guidedStepPrompt == "Check your post")

        analysis.backToDetails()
        analysis.openContext()
        #expect(analysis.guidedStepNumber == nil, "context is a side trip, not a numbered step")
        #expect(analysis.guidedStepPrompt == "Add chart context")

        #expect(guidedDraft(.question).guidedStepPrompt == "What do you want to ask?")
        #expect(guidedDraft(.setup).guidedToolbarTitle == "New Setup")
        #expect(guidedDraft(.setup).guidedStepPrompt == "Plan your trade")
    }

    @Test
    func aResponseIsTitledAsOne() {
        let response = guidedDraft(.analysis, response: true)
        #expect(response.guidedToolbarTitle == "New response")
        #expect(response.guidedStepPrompt == "What's your view?")
        response.openTypeChooser()
        #expect(response.guidedToolbarTitle == "Change type")
        #expect(response.guidedStepPrompt == "What do you want to post?")
        #expect(response.guidedStepNumber == nil)
        #expect(response.linkSession.isActive, "Change type keeps the response")
    }

    @Test
    func outsideTheGuidedFlowThereIsNoGuidedTitleOrPrompt() {
        let legacy = MarkerPlacementState()
        legacy.reset(to: .analysis, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)
        #expect(legacy.guidedToolbarTitle == nil)
        #expect(legacy.guidedStepPrompt == nil)
        #expect(legacy.guidedNextStepPrompt == nil)
    }

    /// Editing keeps the existing editor; under the prototype its toolbar
    /// says "Edit Analysis" instead of "Place a Marker".
    @Test
    func anEditIsTitledAsOneOnlyUnderThePrototype() {
        let dto = MarkerLinkFixtures.marker(
            1, author: "alex", intent: .analysis, candle: anchorCandle.timestamp,
            price: anchorCandle.close, title: "Higher lows"
        )
        let state = MarkerPlacementState()
        state.beginEditingMarker(MarkerLinkFixtures.positioned([dto])[0])
        #expect(state.editToolbarTitle(experimentEnabled: true) == "Edit Analysis")
        #expect(state.editToolbarTitle(experimentEnabled: false) == nil, "the legacy title is unchanged")
        #expect(state.guidedToolbarTitle == nil, "an edit is not the guided flow")

        #expect(guidedDraft(.analysis).editToolbarTitle(experimentEnabled: true) == nil, "a new post is not an edit")
    }

    // MARK: What is still needed

    @Test
    func analysisAsksForItsTextThenStepsAside() {
        let state = guidedDraft(.analysis)
        #expect(state.guidedNextStepPrompt == "Write your analysis to continue")
        state.note = "Range low is holding."
        #expect(state.guidedNextStepPrompt == nil)
        #expect(state.isValid)
    }

    @Test
    func aQuestionCountsDownToItsMinimum() {
        let state = guidedDraft(.question)
        #expect(state.guidedNextStepPrompt == "Write your question to continue")
        state.note = "Breakout?"
        #expect(state.guidedNextStepPrompt == "Write 1 more character")
        state.note = "Break out?"
        #expect(state.guidedNextStepPrompt == nil)
    }

    /// A Setup is always valid; a tracked one waits on the level guard, and
    /// the prompt names what the guard wants, in the guard's approved words.
    @Test
    func aTrackedSetupAsksForItsLevelsInPlainWords() {
        let state = guidedDraft(.setup)
        state.trackingEnabled = true
        #expect(state.guidedNextStepPrompt == "Set a take profit and a stop loss")
        #expect(!state.continueToReview())

        setLevels(state, tp: 240, sl: 120)  // both above Entry
        #expect(state.guidedNextStepPrompt == "Put Entry between your stop and target")
        #expect(!state.continueToReview())

        setLevels(state, tp: 240, sl: -120)
        #expect(state.guidedNextStepPrompt == nil)
        #expect(state.continueToReview())
        #expect(state.guidedNextStepPrompt == nil, "nothing is asked once on Review")
    }

    @Test
    func anUntrackedSetupAsksForNothing() {
        let state = guidedDraft(.setup)
        state.trackingEnabled = false
        #expect(state.guidedNextStepPrompt == nil)
        #expect(state.continueToReview())
    }

    /// Review is held back while a response's timeframe loads, and after it
    /// fails; the bar says so rather than going quiet.
    @Test
    func aResponseTimeframeChangeExplainsTheWait() {
        let state = guidedDraft(.analysis, response: true)
        state.note = "Not convinced."
        #expect(state.guidedNextStepPrompt == nil)

        let request = state.beginResponseTimeframeChange()
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Loading the response timeframe…")

        state.finishResponseTimeframeChange(request, succeeded: false)
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Choose a response timeframe that loads")

        state.finishResponseTimeframeChange(state.beginResponseTimeframeChange(), succeeded: true)
        #expect(state.guidedNextStepPrompt == nil)
        #expect(state.isValid)
    }

    // MARK: Sections and height

    /// A Setup is split in two so each section fits a half-height sheet:
    /// levels, then reasoning, then Review — three steps, with Back going one
    /// section at a time.
    @Test
    func aSetupIsLevelsThenReasoningThenReview() {
        let state = guidedDraft(.setup)
        setLevels(state, tp: 240, sl: -120)
        state.trackingEnabled = true
        #expect(state.guidedStepNumber == 1 && state.guidedStepCount == 3)
        #expect(state.continueToSetupReasoning())
        #expect(state.guidedStep == .setupReasoning)
        #expect(state.guidedStepNumber == 2)
        state.note = "Retest of the range high."
        #expect(state.guidedStepPrompt == "Why this trade?")
        #expect(state.guidedToolbarTitle == "New Setup")
        #expect(state.continueToReview())
        #expect(state.guidedStepNumber == 3)

        state.goBack()
        #expect(state.guidedStep == .setupReasoning, "Review goes back to the reasoning")
        state.openContext()
        state.goBack()
        #expect(state.guidedStep == .setupReasoning, "context returns to where it was opened")
        state.goBack()
        #expect(state.guidedStep == .details)
        #expect(state.note == "Retest of the range high.", "nothing is reset on the way")
        #expect(state.componentPrice(.levelTp) != nil)

        // Levels out of order hold the Setup on its first section.
        setLevels(state, tp: 240, sl: 120)
        #expect(!state.continueToSetupReasoning())
        #expect(state.guidedStep == .details)
    }

    @Test
    func analysisAndQuestionStayTwoSteps() {
        let state = guidedDraft(.analysis)
        #expect(state.guidedStepCount == 2)
        state.note = "Range low is holding."
        #expect(!state.continueToSetupReasoning(), "only a Setup has a reasoning section")
        #expect(state.continueToReview())
        #expect(state.guidedStepNumber == 2)
        state.goBack()
        #expect(state.guidedStep == .details)
    }

    @Test
    func theSheetKeepsTheDraftWhenReturningFromReview() {
        let state = guidedDraft(.analysis)
        state.note = "Range low is holding."
        #expect(state.continueToReview())
        state.goBack()
        #expect(state.guidedStep == .details)
        #expect(state.note == "Range low is holding.")
    }

    @Test
    func theTrackingLineCarriesTheEstimate() {
        #expect(MarkerGuidedFormat.trackingSummary(tracked: true, gain: 29, loss: 5)
                == "Counts toward accuracy · reputation +29 if TP, −5 if SL")
        #expect(MarkerGuidedFormat.trackingSummary(tracked: true, gain: nil, loss: nil)
                == "Counts toward your accuracy and reputation")
        #expect(MarkerGuidedFormat.trackingSummary(tracked: false, gain: 29, loss: 5).hasPrefix("Off"))
    }

    // MARK: Formatting

    @Test
    func reviewPricesMatchTheChartsPrecision() {
        #expect(MarkerGuidedFormat.displayPrice(83_393.8058) == "83,393.81")
        #expect(MarkerGuidedFormat.displayPrice(63_920) == "63,920.00")
        #expect(MarkerGuidedFormat.displayPrice(1.08543) == "1.0854")
        #expect(MarkerGuidedFormat.displayPrice(0.000123456) == "0.000123456")
        #expect(MarkerGuidedFormat.displayPrice(nil) == "—")
        #expect(MarkerGuidedFormat.displayPrice(.nan) == "—")
    }

    @Test
    func theAudienceLineNamesTheGuild() {
        #expect(MarkerGuidedFormat.audience("Alpha Traders") == "Members of Alpha Traders will see this on the chart.")
        #expect(MarkerGuidedFormat.audience(nil) == "Your guild will see this on the chart.")
        // The approved separation: Setup is not in the social selector.
        #expect(MarkerGuidedFlowEntry.socialIntents == [.analysis, .question])
        #expect(!MarkerGuidedFlowEntry.otherIntents.contains(.setup))
    }
}
