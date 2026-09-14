import Foundation
import Testing
@testable import traders_guild

@MainActor
struct MarkerResponseTimeframeTests {
    private func candle(_ time: Date) -> RLCandleDTO {
        RLCandleDTO(timestamp: time, open: 100, high: 110, low: 90, close: 105, volume: 1)
    }

    private func draft() -> MarkerPlacementState {
        let state = MarkerPlacementState()
        let time = Date(timeIntervalSince1970: 24_060)
        state.reset(to: .alert, anchorTime: time, anchorPrice: 101)
        state.note = "A response that must survive timeframe changes"
        state.beginRespondingTo(MarkerLinkContext(
            parentMarkerId: UUID(), parentGuildId: UUID(), parentSymbolId: UUID(),
            parentCandleTimestamp: time, relationship: .buildsOn
        ))
        return state
    }

    @Test func switchingIntervalUsesTheContainingCandleNotTheNearestOrOldIndex() {
        let bars = [0, 14_400, 28_800].map { candle(Date(timeIntervalSince1970: Double($0))) }
        let index = MarkerResponseAnchorResolver.index(
            for: Date(timeIntervalSince1970: 24_060), candles: bars, timeframe: .h4
        )
        #expect(index == 1) // 06:41 belongs to 04:00, even though 08:00 is closer.
        #expect(MarkerResponseAnchorResolver.index(for: bars[2].timestamp, candles: bars, timeframe: .h4) == 2)
    }

    @Test func unloadedHistoryMustBeFetchedInsteadOfMovingTheResponse() {
        let bars = [candle(Date(timeIntervalSince1970: 14_400))]
        #expect(MarkerResponseAnchorResolver.index(for: Date(timeIntervalSince1970: 0), candles: bars, timeframe: .h4) == nil)
        #expect(MarkerResponseAnchorResolver.index(for: Date(timeIntervalSince1970: 28_800), candles: bars, timeframe: .h4) == nil)
        #expect(MarkerResponseAnchorResolver.index(for: Date(), candles: [], timeframe: .m1) == nil)
    }

    @Test func monthlyIntervalsUseCalendarMonths() throws {
        let formatter = ISO8601DateFormatter()
        let start = try #require(formatter.date(from: "2026-02-01T00:00:00Z"))
        let end = try #require(formatter.date(from: "2026-03-01T00:00:00Z"))
        let bars = [candle(start)]
        #expect(MarkerResponseAnchorResolver.index(for: end.addingTimeInterval(-1), candles: bars, timeframe: .mn) == 0)
        #expect(MarkerResponseAnchorResolver.index(for: end, candles: bars, timeframe: .mn) == nil)
    }

    @Test func loadingPreservesTheDraftAndPreventsPrematureSubmission() {
        let state = draft()
        let before = state.buildCreateRequest(symbolId: UUID(), timeframe: "1m")
        let components = state.components
        let context = state.linkSession.context
        let request = state.beginResponseTimeframeChange()
        #expect(state.isChangingResponseTimeframe)
        #expect(!state.isValid)
        state.finishResponseTimeframeChange(request, succeeded: true)
        let after = state.buildCreateRequest(symbolId: before.symbolId, timeframe: "4h")
        #expect(!state.isChangingResponseTimeframe)
        #expect(state.components == components)
        #expect(state.linkSession.context == context)
        #expect(after.note == before.note)
        #expect(after.parentMarkerId == before.parentMarkerId)
        #expect(after.linkRelationship == "builds_on")
        #expect(after.visibility == "guild")
        #expect(after.timeframe == "4h")
    }

    @Test func submissionUsesContainingCandleWithoutMovingTheDraft() throws {
        let state = draft()
        let originalTime = try #require(state.anchorDraft?.payload.anchorTime)
        let containingTime = Date(timeIntervalSince1970: 14_400)
        let request = state.buildCreateRequest(symbolId: UUID(), timeframe: "4h", resolvedAnchorTime: containingTime)
        let anchor = try #require(request.components.first { $0.componentType == "anchor" })
        let payload = MarkerComponentPayload.decode(componentType: anchor.componentType, rawPayload: anchor.payload)
        #expect(payload.anchorTime == containingTime)
        #expect(payload.levelPrice == state.anchorDraft?.payload.levelPrice)
        #expect(state.anchorDraft?.payload.anchorTime == originalTime)
        #expect(request.linkRelationship == "builds_on")
        let narrowRequest = state.buildCreateRequest(symbolId: request.symbolId, timeframe: "1m")
        let narrowAnchor = try #require(narrowRequest.components.first { $0.componentType == "anchor" })
        #expect(MarkerComponentPayload.decode(componentType: narrowAnchor.componentType, rawPayload: narrowAnchor.payload).anchorTime == originalTime)
    }

    @Test func failedLoadRetainsDraftAndAllowsRetry() {
        let state = draft()
        let components = state.components
        let request = state.beginResponseTimeframeChange()
        state.finishResponseTimeframeChange(request, succeeded: false)
        #expect(state.responseTimeframeLoadFailed)
        #expect(!state.isValid)
        #expect(state.linkSession.lastFailureMessage != nil)
        let retry = state.beginResponseTimeframeChange()
        state.finishResponseTimeframeChange(retry, succeeded: true)
        #expect(!state.responseTimeframeLoadFailed)
        #expect(state.linkSession.lastFailureMessage == nil)
        #expect(state.components == components)
    }

    @Test func cancelledSwitchCannotCompleteIntoANewerDraft() {
        let state = draft()
        let oldRequest = state.beginResponseTimeframeChange()
        state.endLinkSession(.cancelled)
        #expect(!state.isChangingResponseTimeframe)
        let nextContext = draft().linkSession.context!
        state.beginRespondingTo(nextContext)
        let nextRequest = state.beginResponseTimeframeChange()
        state.finishResponseTimeframeChange(oldRequest, succeeded: false)
        #expect(state.responseTimeframeChangeID == nextRequest)
        #expect(!state.responseTimeframeLoadFailed)
        #expect(state.linkSession.context == nextContext)
    }
}
