import Foundation
import Testing
@testable import traders_guild

/// Approved Stage 4 correction: a guided tracked Setup is only posted with its
/// Entry strictly between stop and target, checked after the Entry moves to
/// the latest price, and Review shows the Entry the chart shows.
///
/// Posts go through the production `refreshSetupEntryForPosting` (what the
/// chart calls just before building the request) and
/// `MarkerPlacementSubmitter` to a fixture transport that records every
/// request it receives.
@MainActor
struct MarkerTrackedSetupGuardTests {

    private let symbolId = MarkerLinkFixtures.uuid(1)
    private let guildId = MarkerLinkFixtures.uuid(2)
    private let candles = MarkerLinkFixtures.candles()
    private var candle: RLCandleDTO { candles[5] }
    private var entry: Double { candle.close }

    // MARK: Helpers

    private func response() -> MarkerLinkContext {
        MarkerLinkContext(
            parentMarkerId: MarkerLinkFixtures.uuid(70),
            parentGuildId: guildId,
            parentSymbolId: symbolId,
            parentCandleTimestamp: candle.timestamp,
            parentAuthorDisplayText: "sam",
            parentTitle: "Parent",
            parentIntent: .analysis,
            relationship: .challenges
        )
    }

    /// A Setup draft as the chart builds one. A linked Setup's anchor keeps
    /// the parent's candle and an old price; the Entry line is the latest
    /// price. Levels are a short (TP below, SL above) or a long.
    private func setupDraft(
        guided: Bool = true,
        linked: Bool = false,
        long: Bool = false,
        tracked: Bool = true
    ) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        if linked {
            state.beginRespondingTo(response())
            let change = state.beginResponseTimeframeChange()
            state.finishResponseTimeframeChange(change, succeeded: true)
        }
        if guided { state.prepareGuidedFlow() }
        state.reset(to: .setup, anchorTime: candle.timestamp, anchorPrice: linked ? entry - 400 : entry)
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: entry, label: "Entry")))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: long ? entry + 240 : entry - 240, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: long ? entry - 120 : entry + 120, label: "SL")))
        state.trackingEnabled = tracked
        state.recordSetupLevelSeed()
        state.captureDraftBaseline()
        state.note = "Short the failed breakout"
        return state
    }

    private func candle(closingAt close: Double) -> RLCandleDTO {
        RLCandleDTO(
            timestamp: candle.timestamp.addingTimeInterval(3600),
            open: entry, high: max(entry, close) + 20, low: min(entry, close) - 20,
            close: close, volume: 1000
        )
    }

    private func wire() -> (MarkerFixtureTransport, MarkerManager) {
        let me = MarkerLinkFixtures.member(1, username: "alex")
        let transport = MarkerFixtureTransport(mode: .succeed, author: me)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.configure(api: transport, symbolId: symbolId, timeframe: .m15)
        return (transport, manager)
    }

    /// What `TradingChartView.placeMarkerFromState` does for a Setup: move
    /// Entry to the latest price, build the request, submit it.
    private func post(
        _ state: MarkerPlacementState,
        latest: RLCandleDTO,
        via markers: MarkerManager
    ) async -> MarkerPlacementSubmitter.Outcome {
        state.refreshSetupEntryForPosting(latest: latest)
        return await MarkerPlacementSubmitter.submitCreate(
            request: state.buildCreateRequest(symbolId: symbolId, timeframe: "15m"),
            candleIndex: 5, candles: candles, placementState: state,
            markerManager: markers, symbolTicker: "BTC"
        )
    }

    private func levelPrice(_ request: RLCreateMarkerRequest, _ type: RLComponentType) -> Double? {
        request.components.first { $0.componentType == type.rawValue }.flatMap {
            MarkerComponentPayload.decode(componentType: $0.componentType, rawPayload: $0.payload).levelPrice
        }
    }

    // MARK: Review Entry

    /// Stage 4's runtime Review showed a linked Setup's anchor price as its
    /// Entry. Review, side and R:R now read the Entry line.
    @Test
    func aLinkedSetupReviewsTheEntryTheChartShows() {
        let state = setupDraft(linked: true)
        #expect(state.setupEntryPrice == entry - 400, "the anchor keeps the parent's old price")
        #expect(state.guidedSetupEntryPrice == entry)
        #expect(state.setupSide == .short)
        #expect(state.guidedSetupRiskReward.map { abs($0 - 2) < 0.0001 } == true)
        #expect(!state.guidedTrackedSetupLevelsNeedAdjusting)
        #expect(!state.unmetRequiredChecklistItems.contains { $0.id == "setup_direction_required" })
        #expect(state.continueToReview())
        #expect(state.canPostGuidedDraft)
    }

    // MARK: Valid posts

    @Test
    func validLongAndShortPostAtTheLatestPrice() async {
        for long in [true, false] {
            let (transport, markers) = wire()
            let state = setupDraft(long: long)
            #expect(state.continueToReview())
            let outcome = await post(state, latest: candle(closingAt: entry + (long ? 30 : -30)), via: markers)
            #expect(outcome.result.isSuccess)
            #expect(transport.createRequests.count == 1)
            let sent = transport.createRequests[0]
            #expect(levelPrice(sent, .levelEntry) == entry + (long ? 30 : -30), "Entry is the latest price, as before")
            #expect(levelPrice(sent, .levelTp) == (long ? entry + 240 : entry - 240))
            #expect(levelPrice(sent, .levelSl) == (long ? entry - 120 : entry + 120))
        }
    }

    // MARK: The market moved

    /// The Stage 4 failure: a valid short at Review, then the price rises
    /// through its stop before Post. Nothing is sent, and nothing about the
    /// draft other than the refreshed Entry changes.
    @Test
    func aPriceMoveThroughTheStopIsStoppedBeforeSending() async {
        let (transport, markers) = wire()
        let state = setupDraft(linked: true)
        let link = state.linkSession.context
        #expect(state.continueToReview())

        let outcome = await post(state, latest: candle(closingAt: entry + 200), via: markers)

        #expect(outcome.result == .failure(.trackedSetupLevelsOutOfOrder))
        #expect(!outcome.isStale)
        #expect(outcome.shareContext == nil)
        #expect(transport.createRequests.isEmpty, "no request for an out-of-order tracked Setup")

        // Explained, not stranded.
        #expect(state.submissionPhase == .failed(MarkerPlacementFailure.trackedSetupLevelsOutOfOrder.userMessage))
        #expect(!state.submissionPhase.isSubmitting)
        #expect(!state.isGuidedSubmissionInFlight)
        #expect(state.activeSubmissionID == nil)
        #expect(state.guidedStep == .review)

        // Draft, link and response timeframe kept; exits not moved.
        #expect(state.linkSession.isActive && state.linkSession.context == link)
        #expect(state.linkSession.lastFailureMessage == MarkerPlacementFailure.trackedSetupLevelsOutOfOrder.toastTitle)
        #expect(!state.isChangingResponseTimeframe && !state.responseTimeframeLoadFailed)
        #expect(state.note == "Short the failed breakout")
        #expect(state.trackingEnabled)
        #expect(state.componentPrice(.levelTp) == entry - 240)
        #expect(state.componentPrice(.levelSl) == entry + 120)
        #expect(state.guidedSetupEntryPrice == entry + 200, "Review shows the Entry that was checked")
        #expect(state.setupSide == .inconsistent)

        // Post / Retry stays off until the levels are adjusted; retrying the
        // same draft still sends nothing.
        #expect(state.guidedTrackedSetupLevelsNeedAdjusting)
        #expect(!state.canPostGuidedDraft)
        let again = await post(state, latest: candle(closingAt: entry + 200), via: markers)
        #expect(again.result == .failure(.trackedSetupLevelsOutOfOrder))
        #expect(transport.createRequests.isEmpty)
    }

    @Test
    func adjustingTheLevelsThenPostingSucceeds() async {
        let (transport, markers) = wire()
        let state = setupDraft(linked: true)
        #expect(state.continueToReview())
        let moved = candle(closingAt: entry + 200)
        _ = await post(state, latest: moved, via: markers)
        #expect(transport.createRequests.isEmpty)

        state.backToDetails()
        #expect(state.guidedStep == .details, "the author can edit after the rejection")
        #expect(!state.continueToReview(), "not while the levels are out of order")

        // The author moves the stop above the new Entry (still a short).
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: entry + 320, label: "SL")))
        #expect(state.setupSide == .short)
        #expect(state.continueToReview())
        #expect(state.canPostGuidedDraft)

        let outcome = await post(state, latest: moved, via: markers)
        #expect(outcome.result.isSuccess)
        #expect(transport.createRequests.count == 1)
        let sent = transport.createRequests[0]
        #expect(sent.trackingEnabled)
        #expect(sent.timeframe == "15m")
        #expect(sent.parentMarkerId == MarkerLinkFixtures.uuid(70))
        #expect(sent.linkRelationship == "challenges")
        #expect(levelPrice(sent, .levelEntry) == entry + 200)
        #expect(levelPrice(sent, .levelSl) == entry + 320)
        #expect(levelPrice(sent, .levelTp) == entry - 240)
        #expect(!state.linkSession.isActive, "the post that was sent ends its own session")
    }

    // MARK: Unchanged behaviour

    @Test
    func anUntrackedSetupIsSentAsBefore() async {
        let (transport, markers) = wire()
        let state = setupDraft(tracked: false)
        #expect(state.continueToReview())
        let outcome = await post(state, latest: candle(closingAt: entry + 200), via: markers)
        #expect(outcome.result.isSuccess)
        #expect(transport.createRequests.count == 1)
        #expect(!transport.createRequests[0].trackingEnabled)
        #expect(!state.guidedTrackedSetupLevelsNeedAdjusting)
    }

    /// Experiment off: the legacy flow sends what it always sent, reads its
    /// checklist against the anchor as before, and is never held on the device.
    @Test
    func theLegacyFlowIsUnchanged() async {
        let (transport, markers) = wire()
        let linkedLegacy = setupDraft(guided: false, linked: true)
        #expect(!linkedLegacy.guidedTrackedSetupLevelsNeedAdjusting)
        #expect(linkedLegacy.unmetRequiredChecklistItems.contains { $0.id == "setup_direction_required" },
                "the legacy checklist still reads the anchor")

        let legacy = setupDraft(guided: false)
        #expect(legacy.isValid)
        let outcome = await post(legacy, latest: candle(closingAt: entry + 200), via: markers)
        #expect(outcome.result.isSuccess)
        #expect(transport.createRequests.count == 1, "the device does not hold a legacy post")
    }

    @Test
    func theLatestPriceRefreshMovesOnlyEntryAndAnchor() {
        let state = setupDraft()
        let moved = candle(closingAt: entry + 55)
        state.refreshSetupEntryForPosting(latest: moved)
        #expect(state.componentPrice(.levelEntry) == entry + 55)
        #expect(state.anchorDraft?.payload.levelPrice == entry + 55)
        #expect(state.anchorDraft?.payload.anchorTime == moved.timestamp)
        #expect(state.componentPrice(.levelTp) == entry - 240)
        #expect(state.componentPrice(.levelSl) == entry + 120)

        let analysis = MarkerPlacementState()
        analysis.reset(to: .analysis, anchorTime: candle.timestamp, anchorPrice: entry)
        analysis.refreshSetupEntryForPosting(latest: moved)
        #expect(analysis.anchorDraft?.payload.levelPrice == entry, "only a Setup moves")
    }

    // MARK: The request check

    @Test
    func theRequestCheckMatchesTheBackendRule() {
        func request(entry: Double, sl: Double?, tp: Double?, tracked: Bool = true, extraEntry: Bool = false,
                     intent: RLMarkerIntent = .setup) -> RLCreateMarkerRequest {
            let state = MarkerPlacementState()
            state.reset(to: intent, anchorTime: candle.timestamp, anchorPrice: entry)
            state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: entry, label: "Entry")))
            if let sl { state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: sl, label: "SL"))) }
            if let tp { state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: tp, label: "TP"))) }
            state.trackingEnabled = tracked
            var body = state.buildCreateRequest(symbolId: symbolId, timeframe: "15m")
            if extraEntry, let duplicate = body.components.first(where: { $0.componentType == RLComponentType.levelEntry.rawValue }) {
                body = RLCreateMarkerRequest(
                    symbolId: body.symbolId, timeframe: body.timeframe, intent: body.intent, title: body.title,
                    note: body.note, visibility: body.visibility, confidence: body.confidence,
                    trackingEnabled: body.trackingEnabled, components: body.components + [duplicate],
                    pollQuestion: body.pollQuestion, pollOptions: body.pollOptions
                )
            }
            return body
        }
        let check = MarkerPlacementSubmitter.trackedSetupLevelsOutOfOrder(in:)
        #expect(!check(request(entry: 100, sl: 90, tp: 120)), "long")
        #expect(!check(request(entry: 100, sl: 110, tp: 80)), "short")
        #expect(check(request(entry: 100, sl: 110, tp: 120)), "both above")
        #expect(check(request(entry: 100, sl: 100, tp: 120)), "strict: stop at Entry")
        #expect(check(request(entry: 100, sl: nil, tp: 120)), "missing stop")
        #expect(check(request(entry: 100, sl: 90, tp: 120, extraEntry: true)), "two Entry levels")
        #expect(!check(request(entry: 100, sl: 110, tp: 120, tracked: false)), "untracked is not checked")
        #expect(!check(request(entry: 100, sl: 110, tp: 120, intent: .analysis)), "only a Setup")
        #expect(check(request(entry: 100, sl: 90, tp: .infinity)), "infinite target")
        #expect(check(request(entry: 100, sl: -.infinity, tp: 120)), "infinite stop")
        #expect(check(request(entry: .nan, sl: 90, tp: 120)), "NaN Entry")
        #expect(check(request(entry: 100, sl: .nan, tp: 120)), "NaN stop")
    }

    // MARK: Non-finite prices

    /// A typed "1e400" parses to infinity and "nan" to NaN. Neither has a side.
    @Test
    func aNonFiniteLevelHasNoSide() {
        let bad: [Double] = [.infinity, -.infinity, .nan]
        for value in bad {
            #expect(MarkerSetupSide.of(entry: value, takeProfit: 120, stopLoss: 90) == .invalidPrice)
            #expect(MarkerSetupSide.of(entry: 100, takeProfit: value, stopLoss: 90) == .invalidPrice)
            #expect(MarkerSetupSide.of(entry: 100, takeProfit: 120, stopLoss: value) == .invalidPrice)
        }
        #expect(Double("1e400") == .infinity, "how an infinite level gets typed")
        #expect(MarkerSetupSide.of(entry: 100, takeProfit: 120, stopLoss: 90) == .long)
        #expect(MarkerSetupSide.of(entry: 100, takeProfit: 80, stopLoss: 110) == .short)
        #expect(MarkerSetupSide.of(entry: 100, takeProfit: 120, stopLoss: 110) == .inconsistent)
        #expect(MarkerSetupSide.of(entry: 100, takeProfit: nil, stopLoss: 90) == nil)
    }

    @Test
    func aNonFiniteLevelBlocksAGuidedTrackedSetupAndIsNeverSent() async {
        for (type, value) in [(RLComponentType.levelTp, Double.infinity), (.levelSl, .nan)] {
            let (transport, markers) = wire()
            let state = setupDraft(linked: true)
            if type == .levelTp {
                state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: value, label: "TP")))
            } else {
                state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: value, label: "SL")))
            }
            #expect(state.setupSide == .invalidPrice)
            #expect(state.guidedTrackedSetupLevelsNeedAdjusting)
            #expect(state.unmetRequiredChecklistItems.contains { $0.id == "setup_direction_required" })
            #expect(!state.continueToReview(), "Review stays closed")
            #expect(!state.canPostGuidedDraft)
            #expect(state.guidedSetupRiskReward.map(\.isFinite) != true, "no finite R:R is shown for it")

            let outcome = await post(state, latest: candle(closingAt: entry), via: markers)
            #expect(outcome.result == .failure(.trackedSetupLevelsOutOfOrder))
            #expect(transport.createRequests.isEmpty, "a non-finite tracked level is never sent")
            #expect(!state.submissionPhase.isSubmitting)
            #expect(state.linkSession.isActive, "the draft and its link are kept")
        }
    }

    /// Untracked Setups and the legacy flow keep their rules for non-finite
    /// values: this correction is the guided tracked guard only.
    @Test
    func nonFiniteHandlingOutsideTheGuidedTrackedGuardIsUnchanged() async {
        let untracked = setupDraft(tracked: false)
        untracked.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: .nan, label: "TP")))
        #expect(!untracked.guidedTrackedSetupLevelsNeedAdjusting)

        let (transport, markers) = wire()
        let legacy = setupDraft(guided: false, long: true)
        legacy.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: .infinity, label: "TP")))
        #expect(legacy.isValid)
        #expect(!legacy.unmetRequiredChecklistItems.contains { $0.id == "setup_direction_required" },
                "the legacy direction check is as before")
        let outcome = await post(legacy, latest: candle, via: markers)
        #expect(outcome.result.isSuccess)
        #expect(transport.createRequests.count == 1, "the device does not hold a legacy post")
    }
}
