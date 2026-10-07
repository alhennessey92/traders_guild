import Foundation
import SwiftUI
import Testing
@testable import traders_guild

/// The Setup ticket's rules (owner decisions, 6 Oct 2026): Long/Short mirrors
/// Take Profit and Stop Loss around Entry by itself only while they are the
/// chart's suggestion; otherwise it asks, showing what moves. "Adjust on
/// chart" can always be cancelled back to the exact levels.
@MainActor
struct MarkerGuidedSetupTests {
    private func setup(entry: Double = 100, takeProfit: Double = 105, stopLoss: Double = 97) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        state.prepareGuidedFlow()
        state.reset(to: .setup, anchorTime: Date(timeIntervalSince1970: 1770000000), anchorPrice: entry)
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: entry, label: "Entry")))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: takeProfit, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: stopLoss, label: "SL")))
        // As the chart does when it seeds a Setup.
        state.recordSetupLevelSeed()
        state.captureDraftBaseline()
        return state
    }

    private func levels(_ state: MarkerPlacementState) -> (Double?, Double?) {
        (state.componentPrice(.levelTp), state.componentPrice(.levelSl))
    }

    @Test
    func theChartsSuggestedLevelsFlipAtOnceAndStayTheChartsSuggestion() {
        let state = setup()
        #expect(state.setupDirection == .long)
        #expect(state.requestSetupDirection(.short) == nil, "nothing of the author's to confirm")
        #expect(levels(state) == (95, 103))
        #expect(state.setupDirection == .short)
        #expect(!state.setupLevelsEdited, "still the chart's suggestion, mirrored")
        #expect(state.requestSetupDirection(.long) == nil)
        #expect(levels(state) == (105, 97))
    }

    @Test
    func levelsTheAuthorSetAreNeverMirroredWithoutAsking() {
        let state = setup()
        state.guidedLevelPriceBinding(for: .levelTp).wrappedValue = 110
        #expect(state.setupLevelsEdited)
        let change = state.requestSetupDirection(.short)
        #expect(change != nil, "a confirmation, not a silent flip")
        #expect(levels(state) == (110, 97), "nothing moved yet")
        #expect(change?.summary == "Take Profit 110.00 → 90.00 · Stop Loss 97.00 → 103.00")
        state.applySetupSideChange(change!)
        #expect(levels(state) == (90, 103))
        #expect(state.setupDirection == .short)
    }

    @Test
    func choosingTheSideItIsOnDoesNothing() {
        let state = setup()
        let before = state.components
        #expect(state.requestSetupDirection(.long) == nil)
        #expect(state.components == before)
    }

    @Test
    func sameSideLevelsArePutOnTheChosenSidesAtTheirDistances() {
        let state = setup()
        state.guidedLevelPriceBinding(for: .levelTp).wrappedValue = 95
        #expect(state.setupSide == .inconsistent)
        #expect(state.setupDirection == nil)
        let long = state.requestSetupDirection(.long)
        #expect(long?.takeProfitTo == 105)
        #expect(long?.stopLossTo == 97)
        let short = state.requestSetupDirection(.short)
        #expect(short?.takeProfitTo == 95)
        #expect(short?.stopLossTo == 103)
    }

    @Test
    func aMirrorThatIsNotAPriceIsNotOffered() {
        let state = setup(entry: 10, takeProfit: 25, stopLoss: 8)
        #expect(state.setupLevels(for: .short) == nil, "a Take Profit of -5 is not a price")
        #expect(state.requestSetupDirection(.short) == nil)
        #expect(levels(state) == (25, 8))
    }

    @Test
    func flippingKeepsEachLevelsLabelAndStyle() {
        let state = setup()
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 105, label: "Target 1", colorHex: "#2266FF", lineStyle: .dashed, lineWidth: 2)))
        state.recordSetupLevelSeed()
        let id = state.component(.levelTp)?.id
        _ = state.requestSetupDirection(.short)
        let tp = state.component(.levelTp)
        #expect(tp?.id == id)
        #expect(tp?.payload.guidedLevelPayload?.label == "Target 1")
        #expect(tp?.payload.guidedLevelPayload?.colorHex == "#2266FF")
        #expect(tp?.payload.guidedLevelPayload?.lineWidth == 2)
    }

    // MARK: Tracking unavailable here

    /// An open tracked Setup on this symbol and timeframe no longer stops a
    /// Setup from starting: it starts untracked, and turning a post into a
    /// Setup keeps it untracked; a new draft forgets the reason.
    @Test
    func aSetupWhereTrackingIsUnavailableStaysUntracked() {
        let state = MarkerPlacementState()
        state.prepareGuidedFlow()
        state.trackingUnavailableReason = "You already have an open tracked setup on this symbol and timeframe."
        state.reset(to: .analysis, anchorTime: Date(timeIntervalSince1970: 1770000000), anchorPrice: 100)
        state.note = "A"
        _ = state.requestGuidedIntentChange(to: .setup)
        #expect(state.intent == .setup)
        #expect(!state.trackingEnabled, "never switched on where it cannot be")
        state.prepareGuidedFlow()
        #expect(state.trackingUnavailableReason == nil)
    }

    // MARK: Adjust on chart

    @Test
    func cancellingAnAdjustmentRestoresTheLevelsExactly() {
        let state = setup()
        let before = state.components
        #expect(state.beginSetupAdjust())
        #expect(state.isAdjustingSetupOnChart)
        #expect(state.isWorkspaceChartToolActive, "the collapsed workspace shows the tool bar")
        state.guidedLevelPriceBinding(for: .levelTp).wrappedValue = 120
        state.guidedLevelPriceBinding(for: .levelSl).wrappedValue = 90
        #expect(state.setupAdjustReadout == "TP 120.00 · SL 90.00 · R:R 1:2.00")
        state.cancelSetupAdjust()
        #expect(state.components == before)
        #expect(!state.isAdjustingSetupOnChart)
        #expect(!state.isWorkspaceChartToolActive)
    }

    @Test
    func finishingAnAdjustmentKeepsWhereTheLevelsWereMoved() {
        let state = setup()
        #expect(state.beginSetupAdjust())
        state.guidedLevelPriceBinding(for: .levelTp).wrappedValue = 120
        state.finishSetupAdjust()
        #expect(levels(state) == (120, 97))
        #expect(!state.isAdjustingSetupOnChart)
        state.cancelSetupAdjust()
        #expect(levels(state) == (120, 97), "nothing left to cancel")
    }

    @Test
    func onlyASetupAdjustsOnTheChart() {
        let state = MarkerPlacementState()
        state.prepareGuidedFlow()
        state.reset(to: .analysis, anchorTime: Date(timeIntervalSince1970: 1770000000), anchorPrice: 100)
        #expect(!state.beginSetupAdjust())
        #expect(state.requestSetupDirection(.short) == nil)
    }
}
