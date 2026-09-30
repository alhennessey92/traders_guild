import Foundation
import Testing
@testable import traders_guild

/// The v1.5 guided creation flow, over the real `MarkerPlacementState` and the
/// production submission path (`MarkerPlacementSubmitter` → `MarkerManager`),
/// with a fixture transport standing in for the server.
///
/// The fixture transport is not the backend. Where it is told to refuse a
/// text-only Analysis it mirrors today's server; accepting one is the Stage 4
/// local-DEV change, which these tests do not claim.
@MainActor
struct MarkerGuidedCreationTests {

    private let symbolId = MarkerLinkFixtures.uuid(1)
    private let guildId = MarkerLinkFixtures.uuid(2)
    private let candles = MarkerLinkFixtures.candles()
    private var anchorCandle: RLCandleDTO { candles[5] }

    // MARK: Helpers

    /// A draft as the chart sets one up: the entry point chooses the guided
    /// flow, then placement resets the draft at the anchor candle.
    private func guidedDraft(_ intent: RLMarkerIntent = .analysis, response: MarkerLinkContext? = nil) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        if let response { state.beginRespondingTo(response) }
        state.prepareGuidedFlow()
        state.reset(to: intent, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)
        if intent == .setup {
            // What `TradingChartView.initializePlacementState` adds for a Setup.
            state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: anchorCandle.close * 1.01, label: "TP")))
            state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: anchorCandle.close * 0.99, label: "SL")))
            state.trackingEnabled = true
        }
        state.captureDraftBaseline()
        return state
    }

    private func request(_ state: MarkerPlacementState) -> RLCreateMarkerRequest {
        state.buildCreateRequest(symbolId: symbolId, timeframe: "1h")
    }

    private func componentTypes(_ request: RLCreateMarkerRequest) -> [String] {
        request.components.map(\.componentType)
    }

    private func responseContext(parentIntent: RLMarkerIntent = .setup) -> MarkerLinkContext {
        MarkerLinkContext(
            parentMarkerId: MarkerLinkFixtures.uuid(77),
            parentGuildId: guildId,
            parentSymbolId: symbolId,
            parentCandleTimestamp: anchorCandle.timestamp,
            parentAuthorDisplayText: "alex",
            parentTitle: "BTC breakout",
            parentIntent: parentIntent,
            relationship: .challenges
        )
    }

    private func encoded(_ request: RLCreateMarkerRequest) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: (try? encoder.encode(request)) ?? Data(), as: UTF8.self)
    }

    private func manager(_ transport: MarkerFixtureTransport) -> MarkerManager {
        let me = MarkerLinkFixtures.member(1, username: "alex")
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.configure(api: transport, symbolId: symbolId, timeframe: .h1)
        return manager
    }

    private func submit(_ state: MarkerPlacementState, via manager: MarkerManager) async -> MarkerPlacementSubmitter.Outcome {
        await MarkerPlacementSubmitter.submitCreate(
            request: request(state),
            candleIndex: 5,
            candles: candles,
            placementState: state,
            markerManager: manager,
            symbolTicker: "BTC"
        )
    }

    // MARK: Social details → Review

    @Test
    func analysisGoesFromDetailsToReviewWithTextAlone() {
        let state = guidedDraft()
        #expect(state.guidedStep == .details)
        #expect(state.continueToReview() == false, "no text yet")

        state.note = "  BTC holding higher lows into the open  "
        #expect(state.isValid)
        #expect(state.continueToReview())
        #expect(state.guidedStep == .review)

        let body = request(state)
        #expect(body.intent == "analysis")
        #expect(body.note == "BTC holding higher lows into the open")
        #expect(body.title == nil)
        #expect(componentTypes(body) == ["anchor"], "exactly one anchor, no context required")
        #expect(body.visibility == "guild")
    }

    @Test
    func whitespaceIsNotAnAnalysis() {
        let state = guidedDraft()
        state.note = "   \n  "
        #expect(!state.isValid)
        #expect(!state.continueToReview())
        #expect(state.guidedStep == .details)
    }

    /// Outside the guided flow Analysis still needs a chart component, exactly
    /// as in 1.4.1 — which is also what the current backend enforces.
    @Test
    func theLegacyFlowStillRequiresAnalysisContext() {
        let state = MarkerPlacementState()
        state.reset(to: .analysis, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)
        state.note = "Text only"
        #expect(!state.isGuidedFlowActive)
        #expect(!state.isValid)
        #expect(state.placementChecklistItems.first { $0.id == "analysis_structure" }?.isRequired == true)

        let guided = guidedDraft()
        guided.note = "Text only"
        #expect(guided.placementChecklistItems.first { $0.id == "analysis_structure" }?.isRequired == false)
    }

    @Test
    func questionKeepsItsTenCharacterMinimumAndTheDraftSurvivesTheSwitch() {
        let state = guidedDraft()
        state.title = "Range"
        state.note = "Breakout?"
        #expect(state.requestGuidedIntentChange(to: .question) == nil, "nothing to remove")
        #expect(state.intent == .question)
        #expect(state.title == "Range" && state.note == "Breakout?")
        #expect(!state.isValid, "9 characters")

        state.note = "Breakout or fakeout?"
        #expect(state.isValid)
        #expect(state.continueToReview())
        #expect(request(state).intent == "question")

        // And back, with the text intact.
        state.backToDetails()
        #expect(state.requestGuidedIntentChange(to: .analysis) == nil)
        #expect(state.note == "Breakout or fakeout?" && state.isValid)
    }

    // MARK: Context round trip, Back

    @Test
    func contextRoundTripAndBackKeepEverything() {
        let state = guidedDraft()
        state.title = "Higher lows"
        state.note = "Holding the range low"
        state.openContext()
        #expect(state.guidedStep == .context)
        state.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 63_800, label: "Range low")))
        state.upsertComponent(.timeframeLink, payload: .timeframeLink(TimeframeLinkPayload(timeframe: "4h", note: nil)))
        state.backToDetails()
        #expect(state.guidedStep == .details)
        #expect(state.title == "Higher lows" && state.note == "Holding the range low")

        #expect(state.continueToReview())
        let before = encoded(request(state))
        state.backToDetails()
        #expect(state.continueToReview())
        #expect(encoded(request(state)) == before, "Back and forward change nothing")
        #expect(Set(componentTypes(request(state))) == ["anchor", "level.support", "timeframe_link"])
    }

    // MARK: Change type, linked responses

    @Test
    func changingTypeNeverRemovesContextSilently() {
        let state = guidedDraft()
        state.note = "Support and a source"
        state.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 63_800, label: "Support")))
        state.upsertComponent(.linkURL, payload: .link(LinkPayload(url: "https://example.com", title: nil, previewImage: nil)))
        state.openTypeChooser()

        let pending = state.requestGuidedIntentChange(to: .setup)
        #expect(pending != nil)
        #expect(pending?.incompatibleSummary.contains("Support") == true)
        #expect(pending?.incompatibleSummary.contains("Link") == true)
        #expect(state.intent == .analysis, "nothing changes until the author confirms")
        #expect(state.components.count == 3)

        if let pending { state.applyGuidedIntentChange(pending) }
        #expect(state.intent == .setup)
        #expect(!state.components.contains { $0.componentType == .levelSupport || $0.componentType == .linkURL })
        #expect(state.trackingEnabled, "a Setup starts tracked, as from Structured → Setup")
        #expect(state.note == "Support and a source", "the text stays")
    }

    @Test
    func aResponseStartsAsAnalysisAndCanBecomeASetupWithoutLosingItsLink() {
        let context = responseContext()
        let state = guidedDraft(.analysis, response: context)
        #expect(state.intent == .analysis)
        #expect(state.linkSession.context == context)

        state.note = "Challenging this with a short"
        state.openTypeChooser()
        #expect(state.requestGuidedIntentChange(to: .setup) == nil)
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: anchorCandle.close * 0.98, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: anchorCandle.close * 1.01, label: "SL")))
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: anchorCandle.close, label: "Entry")))
        state.backToDetails()

        #expect(state.linkSession.isActive)
        #expect(state.linkSession.context == context)
        #expect(state.setupSide == .short)
        let body = request(state)
        #expect(body.intent == "setup")
        #expect(body.parentMarkerId == context.parentMarkerId)
        #expect(body.linkRelationship == "challenges")
        #expect(body.visibility == "guild")
    }

    // MARK: Setup

    @Test
    func trackedAndUntrackedSetupsCarryTheirLevelsAndTracking() {
        let state = guidedDraft(.setup)
        #expect(state.isValid)
        #expect(state.setupSide == .long)
        #expect(state.setupRiskReward.map { abs($0 - 1) < 0.0001 } == true)
        state.note = "Retest long"

        var body = request(state)
        #expect(body.intent == "setup")
        #expect(body.trackingEnabled)
        #expect(Set(componentTypes(body)).isSuperset(of: ["anchor", "level.entry", "level.tp", "level.sl"]))

        state.trackingEnabled = false
        body = request(state)
        #expect(!body.trackingEnabled, "untracked is what gets posted")
        #expect(MarkerIntentBadge.SetupStatus.from(trackingEnabled: false, trackingState: nil, predictionResult: nil) == .untracked)

        // Tracked validation as before: TP/SL on the same side is an unmet requirement.
        state.trackingEnabled = true
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: anchorCandle.close * 0.95, label: "TP")))
        #expect(state.setupSide == .inconsistent)
        #expect(state.unmetRequiredChecklistItems.contains { $0.id == "setup_direction_required" })
    }

    // MARK: Cancelling

    @Test
    func onlyMaterialEditsNeedAConfirmationToCancel() {
        let state = guidedDraft()
        #expect(!state.cancellingNeedsConfirmation, "an untouched draft closes")

        // Moving the anchor is not an edit worth confirming.
        state.upsertComponent(.anchor, payload: .anchor(AnchorPayload(time: candles[6].timestamp, price: 64_100)))
        #expect(!state.cancellingNeedsConfirmation)

        state.note = "Something worth keeping"
        #expect(state.cancellingNeedsConfirmation)
        state.note = "   "
        #expect(!state.cancellingNeedsConfirmation, "whitespace is not an edit")

        _ = state.upsertIndicator(name: "RSI", settings: [:])
        #expect(state.components.contains { $0.componentType == .indicator })
        #expect(state.cancellingNeedsConfirmation, "attached context counts")

        let setup = guidedDraft(.setup)
        #expect(!setup.cancellingNeedsConfirmation)
        setup.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: anchorCandle.close * 1.05, label: "TP")))
        #expect(setup.cancellingNeedsConfirmation, "a moved target counts")

        // The legacy flow never asks.
        let legacy = MarkerPlacementState()
        legacy.reset(to: .analysis, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)
        legacy.note = "Legacy draft"
        #expect(!legacy.cancellingNeedsConfirmation)
    }

    @Test
    func endingTheFlowClearsGuidedStateButNotTheLegacyDraft() {
        let state = guidedDraft()
        state.note = "Kept"
        state.submissionPhase = .failed("x")
        state.endGuidedFlow()
        #expect(state.guidedStep == nil && state.submissionPhase == .idle && state.draftBaseline == nil)
        #expect(state.note == "Kept")
        #expect(state.requiresAnalysisContext, "back to the legacy rule")
    }

    // MARK: Posting through the fixture transport

    /// Today's backend refuses a text-only Analysis. The draft, the step and a
    /// response's link all survive; the retry sends the identical payload and,
    /// once accepted, ends the session and hands the new marker to the share
    /// prompt.
    @Test
    func aFailedPostKeepsTheDraftAndARetryPostsTheSamePayload() async {
        let transport = MarkerFixtureTransport(
            mode: .failFirst(detail: MarkerFixtureTransport.analysisNeedsComponentDetail),
            author: MarkerLinkFixtures.member(1, username: "alex")
        )
        let markers = manager(transport)
        let state = guidedDraft(.analysis, response: responseContext(parentIntent: .analysis))
        state.title = "Not so fast"
        state.note = "Volume doesn't confirm this"
        #expect(state.continueToReview())

        let failed = await submit(state, via: markers)
        #expect(failed.result == .failure(.genericCreateFailure))
        #expect(failed.shareContext == nil)
        #expect(state.submissionPhase == .failed(MarkerPlacementFailure.genericCreateFailure.userMessage))
        #expect(state.guidedStep == .review, "still on Review, ready to retry")
        #expect(state.title == "Not so fast" && state.note == "Volume doesn't confirm this")
        #expect(state.linkSession.isActive)
        #expect(state.linkSession.lastFailureMessage == MarkerPlacementFailure.genericCreateFailure.toastTitle)
        #expect(markers.markers.isEmpty, "the optimistic marker is withdrawn")

        let retried = await submit(state, via: markers)
        #expect(retried.result.isSuccess)
        #expect(state.submissionPhase == .idle)
        #expect(!state.linkSession.isActive, "a successful post ends the response session")
        #expect(transport.createRequests.count == 2)
        #expect(encoded(transport.createRequests[0]) == encoded(transport.createRequests[1]), "the retry sends exactly what failed")
        #expect(transport.createRequests[1].components.map(\.componentType) == ["anchor"])
        #expect(transport.createRequests[1].parentMarkerId == MarkerLinkFixtures.uuid(77))

        // The share handoff: the created marker, for the existing prompt.
        #expect(retried.shareContext?.marker.note == "Volume doesn't confirm this")
        #expect(retried.shareContext?.symbolTicker == "BTC")
        #expect(retried.shareContext?.isCurrentUserMarker == true)
        #expect(markers.markers.count == 1)
    }

    @Test
    func aSuccessfulTrackedSetupHandsOffToSharing() async {
        let transport = MarkerFixtureTransport(mode: .succeed, author: MarkerLinkFixtures.member(1, username: "alex"))
        let markers = manager(transport)
        let state = guidedDraft(.setup)
        state.note = "Retest long"
        #expect(state.continueToReview())

        let outcome = await submit(state, via: markers)
        #expect(outcome.result.isSuccess)
        let sent = transport.createRequests.last
        #expect(sent?.intent == "setup" && sent?.trackingEnabled == true)
        #expect(outcome.shareContext?.marker.intent == "setup")
        #expect(outcome.shareContext?.marker.trackingState == "ARMED")
    }
}
