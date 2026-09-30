import Foundation
import Testing
@testable import traders_guild

/// Stage 3 review corrections: a guided post in flight, and what counts as an
/// edit worth confirming before a draft is discarded.
///
/// Posts go through the production `MarkerPlacementSubmitter` and
/// `MarkerManager` to a fixture transport that can hold a create until the
/// test releases it — a slow server.
@MainActor
struct MarkerGuidedSubmissionSafetyTests {

    private let symbolId = MarkerLinkFixtures.uuid(1)
    private let guildId = MarkerLinkFixtures.uuid(2)
    private let candles = MarkerLinkFixtures.candles()
    private var anchorCandle: RLCandleDTO { candles[5] }

    // MARK: Helpers

    private func response(_ n: Int, _ relationship: MarkerLinkRelationship = .supports) -> MarkerLinkContext {
        MarkerLinkContext(
            parentMarkerId: MarkerLinkFixtures.uuid(n),
            parentGuildId: guildId,
            parentSymbolId: symbolId,
            parentCandleTimestamp: anchorCandle.timestamp,
            parentAuthorDisplayText: "sam",
            parentTitle: "Parent \(n)",
            parentIntent: .analysis,
            relationship: relationship
        )
    }

    /// A draft as the chart starts one, optionally in the guided flow.
    private func startDraft(
        _ state: MarkerPlacementState,
        intent: RLMarkerIntent = .analysis,
        guided: Bool = true,
        response: MarkerLinkContext? = nil
    ) {
        if let response { state.beginRespondingTo(response) }
        if guided { state.prepareGuidedFlow() }
        state.reset(to: intent, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)
        if intent == .setup { seedSetup(state) }
        state.captureDraftBaseline()
    }

    /// What `TradingChartView.initializePredictionPlacement` does for a Setup.
    private func seedSetup(_ state: MarkerPlacementState, long: Bool = true) {
        let entry = anchorCandle.close
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: entry, label: "Entry")))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: long ? entry + 240 : entry - 240, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: long ? entry - 120 : entry + 120, label: "SL")))
        state.trackingEnabled = true
        state.recordSetupLevelSeed()
    }

    private func transport(_ mode: MarkerFixtureTransport.Mode = .succeed, held: Bool = true) -> MarkerFixtureTransport {
        let transport = MarkerFixtureTransport(mode: mode, author: MarkerLinkFixtures.member(1, username: "alex"))
        transport.holdsCreates = held
        return transport
    }

    private func manager(_ transport: MarkerFixtureTransport) -> MarkerManager {
        let me = MarkerLinkFixtures.member(1, username: "alex")
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.configure(api: transport, symbolId: symbolId, timeframe: .h1)
        return manager
    }

    /// Start a post and return once the transport is holding it.
    private func postHeld(
        _ state: MarkerPlacementState,
        via markers: MarkerManager,
        transport: MarkerFixtureTransport
    ) async -> Task<MarkerPlacementSubmitter.Outcome, Never> {
        let request = state.buildCreateRequest(symbolId: symbolId, timeframe: "1h")
        let task = Task { @MainActor in
            await MarkerPlacementSubmitter.submitCreate(
                request: request, candleIndex: 5, candles: candles,
                placementState: state, markerManager: markers, symbolTicker: "BTC"
            )
        }
        for _ in 0..<1_000 where transport.heldCreateCount == 0 {
            await Task.yield()
        }
        #expect(transport.heldCreateCount == 1, "the post should be in flight")
        return task
    }

    // MARK: In flight

    /// While the server has not answered, the draft that was sent cannot be
    /// navigated away from, retyped or discarded.
    @Test
    func whilePostingTheGuidedDraftIsFrozen() async {
        let wire = transport()
        let markers = manager(wire)
        let state = MarkerPlacementState()
        startDraft(state, response: response(70))
        state.note = "Holding higher lows"
        #expect(state.continueToReview())

        let pending = await postHeld(state, via: markers, transport: wire)
        #expect(state.submissionPhase == .submitting)
        #expect(state.isGuidedSubmissionInFlight)

        state.backToDetails()
        state.openContext()
        state.openTypeChooser()
        #expect(state.guidedStep == .review, "no navigation while posting")
        #expect(state.requestGuidedIntentChange(to: .question) == nil)
        #expect(state.intent == .analysis, "no type change while posting")

        wire.releaseHeldCreates()
        let outcome = await pending.value
        #expect(outcome.result.isSuccess && !outcome.isStale)
        #expect(!state.isGuidedSubmissionInFlight)
        #expect(!state.linkSession.isActive, "the post that was sent ends its own session")
        #expect(outcome.shareContext?.marker.note == "Holding higher lows")
    }

    /// A failure unfreezes the draft: the author can go back, edit, and post
    /// again, and the retry carries the edit.
    @Test
    func aFailureUnfreezesTheDraftForEditingAndRetry() async {
        let wire = transport(.failFirst(detail: MarkerFixtureTransport.analysisNeedsComponentDetail))
        let markers = manager(wire)
        let state = MarkerPlacementState()
        startDraft(state)
        state.note = "First try"
        #expect(state.continueToReview())

        let pending = await postHeld(state, via: markers, transport: wire)
        state.backToDetails()
        #expect(state.guidedStep == .review, "frozen while posting")
        wire.releaseHeldCreates()
        let failed = await pending.value
        #expect(failed.result == .failure(.genericCreateFailure))
        #expect(!failed.isStale)
        #expect(state.submissionPhase.isFailed)

        state.backToDetails()
        #expect(state.guidedStep == .details, "editable after the failure")
        state.note = "Second try, edited"
        #expect(state.continueToReview())

        wire.holdsCreates = false
        let retried = await MarkerPlacementSubmitter.submitCreate(
            request: state.buildCreateRequest(symbolId: symbolId, timeframe: "1h"),
            candleIndex: 5, candles: candles, placementState: state, markerManager: markers, symbolTicker: "BTC"
        )
        #expect(retried.result.isSuccess)
        #expect(wire.createRequests.map(\.note) == ["First try", "Second try, edited"])
    }

    /// The chart can end placement while a post is in flight — dismissing the
    /// sheet, switching guild or symbol — and a new draft can start. The late
    /// answer must not end the new draft's response session, change its state
    /// or ask the chart to close it.
    @Test
    func aLateSuccessCannotTouchTheNextDraft() async {
        let wire = transport()
        let markers = manager(wire)
        let state = MarkerPlacementState()
        startDraft(state, response: response(70))
        state.note = "Draft A"
        #expect(state.continueToReview())
        let pending = await postHeld(state, via: markers, transport: wire)

        // What `TradingChartView` does when placement ends, then a new draft.
        state.endLinkSession(.cancelled)
        state.endGuidedFlow()
        let nextParent = response(71, .challenges)
        startDraft(state, response: nextParent)
        state.note = "Draft B"

        wire.releaseHeldCreates()
        let outcome = await pending.value
        #expect(outcome.isStale)
        #expect(outcome.shareContext == nil, "nothing to present for a draft that is gone")
        #expect(outcome.result.isSuccess, "the post itself did go through")
        #expect(markers.markers.count == 1)

        #expect(state.linkSession.context == nextParent && state.linkSession.isActive)
        #expect(state.submissionPhase == .idle)
        #expect(state.guidedStep == .details)
        #expect(state.note == "Draft B")
    }

    @Test
    func aLateFailureCannotTouchTheNextDraft() async {
        let wire = transport(.failAlways(detail: "boom"))
        let markers = manager(wire)
        let state = MarkerPlacementState()
        startDraft(state)
        state.note = "Draft A"
        #expect(state.continueToReview())
        let pending = await postHeld(state, via: markers, transport: wire)

        state.endGuidedFlow()
        startDraft(state, response: response(72))
        state.note = "Draft B"

        wire.releaseHeldCreates()
        let outcome = await pending.value
        #expect(outcome.isStale)
        #expect(state.submissionPhase == .idle)
        #expect(state.linkSession.lastFailureMessage == nil, "no failure recorded against the new draft")
        #expect(state.linkSession.isActive)
    }

    /// Experiment off: the legacy flow's submission behaves exactly as before
    /// — no staleness check, and it reads the composer state at completion.
    @Test
    func theLegacyFlowKeepsItsBehaviour() async {
        let wire = transport()
        let markers = manager(wire)
        let state = MarkerPlacementState()
        startDraft(state, guided: false)
        state.note = "Legacy"
        state.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 63_800, label: "S")))
        #expect(state.isValid)

        let pending = await postHeld(state, via: markers, transport: wire)
        #expect(!state.isGuidedSubmissionInFlight, "the guided lock does not apply")
        state.reset(to: .analysis, anchorTime: anchorCandle.timestamp, anchorPrice: anchorCandle.close)

        wire.releaseHeldCreates()
        let outcome = await pending.value
        #expect(!outcome.isStale)
        #expect(outcome.shareContext != nil)
    }

    // MARK: Material edits

    /// Astra's repro: an untouched Analysis changed to Setup, tracking turned
    /// back off, then only the levels edited. Discarding that must ask.
    @Test
    func levelEditsAfterAChangeToSetupNeedConfirmation() {
        let state = MarkerPlacementState()
        startDraft(state)
        #expect(!state.cancellingNeedsConfirmation)

        state.openTypeChooser()
        #expect(state.requestGuidedIntentChange(to: .setup) == nil)
        seedSetup(state)                 // the chart seeds the levels
        state.trackingEnabled = false    // back to the Analysis baseline
        state.backToDetails()
        #expect(!state.cancellingNeedsConfirmation, "the chart's levels are not the author's")

        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: anchorCandle.close + 400, label: "TP")))
        #expect(state.cancellingNeedsConfirmation, "a moved target is an edit")
        #expect(state.title.isEmpty && state.note.isEmpty)
    }

    /// Recording a seed on a type change keeps the author's earlier text and
    /// context as edits — it re-bases the levels only.
    @Test
    func seedingLevelsDoesNotForgetEarlierEdits() {
        let state = MarkerPlacementState()
        startDraft(state)
        state.note = "Written before the change"
        _ = state.requestGuidedIntentChange(to: .setup)
        seedSetup(state)
        state.trackingEnabled = false
        #expect(state.cancellingNeedsConfirmation)
    }

    @Test
    func addedAndRemovedLevelsCount() {
        let setup = MarkerPlacementState()
        startDraft(setup, intent: .setup)
        #expect(!setup.cancellingNeedsConfirmation)
        let stop = setup.components.first { $0.componentType == .levelSl }
        if let stop { setup.removeComponent(id: stop.id) }
        #expect(setup.cancellingNeedsConfirmation, "a removed Setup level is an edit")

        let analysis = MarkerPlacementState()
        startDraft(analysis)
        analysis.upsertComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: 64_300, label: "R")))
        #expect(analysis.cancellingNeedsConfirmation, "an added level is an edit")
        if let added = analysis.components.first(where: { $0.componentType == .levelResistance }) {
            analysis.removeComponent(id: added.id)
        }
        #expect(!analysis.cancellingNeedsConfirmation, "and removing it again restores the draft")
    }
}
