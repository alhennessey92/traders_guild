//
//  MarkerGuidedCreationHarness.swift
//  traders_guild
//
//  Backend-free interaction fixture for v1.5 guided creation.
//
//  Renders the real guided panel, bottom bar and discard confirmation over a
//  real `MarkerPlacementState`, and posts through the production
//  `MarkerPlacementSubmitter` → `MarkerManager` path to `MarkerFixtureTransport`
//  — which records the exact request and answers as told. The chart itself is
//  not here; the sheet is what is under review.
//
//  Launch: `-MarkerGuidedCreationFixture <scenario> -TGAvatarMarkersExperiment YES`
//  (see `Scenario`). Debug and isolated-DEV builds only.
//

#if DEBUG || TG_ISOLATED_DEV

import SwiftUI

struct MarkerGuidedCreationHarness: View {
    enum Scenario: String, CaseIterable {
        case entry, analysisEmpty, analysisDetails, questionShort, context, analysisReview
        case setupTracked, setupUntracked, setupReview
        case responseChooser, responseSetupReview
        case failedPost, retrySuccess, discardConfirm
        /// A linked Setup whose anchor keeps the parent candle's old price:
        /// Review shows the Entry line, not the anchor.
        case responseSetupEntry
        /// The same Setup posted after the price rose through its stop: the
        /// post is stopped on the device and nothing reaches the transport.
        case setupMarketMoved

        static var launch: Scenario? {
            UserDefaults.standard.string(forKey: "MarkerGuidedCreationFixture").flatMap(Scenario.init(rawValue:))
        }

        var transportMode: MarkerFixtureTransport.Mode {
            switch self {
            case .failedPost, .retrySuccess:
                return .failFirst(detail: MarkerFixtureTransport.analysisNeedsComponentDetail)
            default:
                return .succeed
            }
        }

        var autoPosts: Int {
            switch self {
            case .failedPost: return 1
            case .retrySuccess: return 2
            case .setupMarketMoved: return 1
            default: return 0
            }
        }
    }

    static let symbolId = MarkerLinkFixtures.uuid(1)
    static let guildId = MarkerLinkFixtures.uuid(2)
    static let candles = MarkerLinkFixtures.candles()

    let scenario: Scenario
    @StateObject private var placementState: MarkerPlacementState
    @State private var transport: MarkerFixtureTransport
    @State private var markerManager: MarkerManager
    @State private var shareContext: MarkerShareContext?
    @State private var showDiscardConfirmation = false
    @State private var closed = false

    init(scenario: Scenario) {
        self.scenario = scenario
        let author = MarkerLinkFixtures.member(1, username: "alex")
        let transport = MarkerFixtureTransport(mode: scenario.transportMode, author: author)
        let manager = MarkerManager(userId: author.userId, guildId: Self.guildId, currentUserMember: author)
        manager.configure(api: transport, symbolId: Self.symbolId, timeframe: .h1)
        _transport = State(initialValue: transport)
        _markerManager = State(initialValue: manager)
        _placementState = StateObject(wrappedValue: Self.makeDraft(for: scenario))
    }

    private var author: MarkerAvatarIdentity {
        var identity = MarkerAvatarIdentity.forCurrentUser(
            username: "alex",
            avatarUrl: MarkerAvatarFixtureImages.defaultURL(forUsername: "alex")
        )
        identity.authorId = MarkerLinkFixtures.uuid(401)
        return identity
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    sheet
                    transportPanel
                }
                .padding(12)
            }
        }
        .background(AppColors.tgGradientBackground.ignoresSafeArea())
        .task {
            if scenario == .discardConfirm { showDiscardConfirmation = placementState.cancellingNeedsConfirmation }
            for _ in 0..<scenario.autoPosts {
                await post()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                if placementState.cancellingNeedsConfirmation {
                    showDiscardConfirmation = true
                } else {
                    closed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppColors.statusNegative55))
            }
            .disabled(placementState.isGuidedSubmissionInFlight)
            .modifier(MarkerGuidedDiscardConfirmation(isPresented: $showDiscardConfirmation) { closed = true })
            VStack(alignment: .leading, spacing: 1) {
                Text(placementState.guidedToolbarTitle ?? (closed ? "Closed" : "Legacy panel"))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text("Fixture · \(scenario.rawValue) · transport: in-memory (not the backend)")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Fixture chrome, not product UI: kept compact so the sheet under
        // review stays on screen at accessibility text sizes.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            if closed {
                Text("Draft discarded: placement would end here.")
                    .font(.footnote)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if placementState.isGuidedFlowActive {
                MarkerGuidedPlacementPanel(
                    placementState: placementState,
                    author: author,
                    guildName: "Alpha Traders",
                    currentChartTimeframe: .h1
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(height: 470)
                Divider()
                MarkerGuidedPlacementBar(placementState: placementState) {
                    Task { await post() }
                }
            } else {
                Text("Left the guided flow for the legacy panel (\(placementState.intent.displayName)).")
                    .font(.footnote)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(AppColors.sheetBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var transportPanel: some View {
        if let shareContext {
            VStack(alignment: .leading, spacing: 4) {
                Label("Posted — share prompt handoff", systemImage: "square.and.arrow.up")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(AppColors.statusPositive)
                Text("The app presents MarkerSharePromptSheet with: \(shareContext.marker.intent) · \"\(shareContext.marker.note ?? "")\" · \(shareContext.symbolTicker ?? "") · visibility \(shareContext.marker.visibility)")
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.statusPositive.opacity(0.10)))
        }
        if let json = transport.lastRequestJSON {
            VStack(alignment: .leading, spacing: 4) {
                Text("Request #\(transport.createRequests.count) sent to the fixture transport")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColors.primaryForeground)
                Text(json)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(AppColors.greyText)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.whiteText.opacity(0.05)))
        }
    }

    private func post() async {
        guard placementState.isValid else { return }
        if scenario == .setupMarketMoved {
            // What the chart does just before sending a Setup, at a latest
            // price above the draft's stop.
            placementState.refreshSetupEntryForPosting(latest: Self.priceRoseThroughStop)
        }
        let outcome = await MarkerPlacementSubmitter.submitCreate(
            request: placementState.buildCreateRequest(symbolId: Self.symbolId, timeframe: "1h"),
            candleIndex: 5,
            candles: Self.candles,
            placementState: placementState,
            markerManager: markerManager,
            symbolTicker: "BTC"
        )
        if let context = outcome.shareContext {
            shareContext = context
        }
    }

    // MARK: Drafts

    private static func makeDraft(for scenario: Scenario) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        let candle = candles[5]
        let isSetup = [.setupTracked, .setupUntracked, .setupReview].contains(scenario)
        let isResponse = [.responseChooser, .responseSetupReview, .responseSetupEntry, .setupMarketMoved].contains(scenario)
        if isResponse {
            state.beginRespondingTo(MarkerLinkContext(
                parentMarkerId: MarkerLinkFixtures.uuid(77),
                parentGuildId: guildId,
                parentSymbolId: symbolId,
                parentCandleTimestamp: candle.timestamp,
                parentAuthorDisplayText: "sam",
                parentTitle: "BTC breakout",
                parentIntent: .analysis,
                relationship: .challenges
            ))
        }
        state.prepareGuidedFlow()
        state.reset(to: isSetup ? .setup : .analysis, anchorTime: candle.timestamp, anchorPrice: candle.close)
        if isSetup {
            seedSetupLevels(state, entry: candle.close, long: true)
            state.recordSetupLevelSeed()
        }
        state.captureDraftBaseline()

        switch scenario {
        case .entry:
            state.openTypeChooser()
        case .analysisEmpty:
            break
        case .analysisDetails, .discardConfirm:
            state.title = "Higher lows"
            state.note = "BTC is holding higher lows into the open. Watching 63.8k."
        case .questionShort:
            _ = state.requestGuidedIntentChange(to: .question)
            state.note = "Breakout?"
        case .context:
            state.title = "Higher lows"
            state.note = "Range low is holding."
            state.upsertComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 63_780, label: "Range low")))
            state.upsertComponent(.timeframeLink, payload: .timeframeLink(TimeframeLinkPayload(timeframe: "4h", note: nil)))
            state.openContext()
        case .analysisReview, .failedPost, .retrySuccess:
            state.title = "Higher lows"
            state.note = "BTC is holding higher lows into the open. Watching 63.8k."
            state.continueToReview()
        case .setupTracked:
            state.note = "Retest of the range high."
        case .setupUntracked:
            state.note = "Retest of the range high."
            state.trackingEnabled = false
        case .setupReview:
            state.title = "Range high retest"
            state.note = "Retest of the range high."
            state.continueToReview()
        case .responseChooser:
            state.note = "Not convinced — volume is fading."
            state.openTypeChooser()
        case .responseSetupReview:
            state.note = "Short the failed breakout."
            _ = state.requestGuidedIntentChange(to: .setup)
            seedSetupLevels(state, entry: candle.close, long: false)
            state.recordSetupLevelSeed()
            state.continueToReview()
        case .responseSetupEntry, .setupMarketMoved:
            state.note = "Short the failed breakout."
            _ = state.requestGuidedIntentChange(to: .setup)
            // As on the chart: the anchor keeps the parent's candle and an
            // old price; the Entry line is the latest price.
            state.upsertComponent(.anchor, payload: .anchor(AnchorPayload(time: candle.timestamp, price: candle.close - 400)))
            seedSetupLevels(state, entry: candle.close, long: false)
            state.recordSetupLevelSeed()
            state.continueToReview()
        }
        return state
    }

    /// The next candle, closing 200 above the fixture's Entry — above the
    /// short's stop at Entry + 120.
    static var priceRoseThroughStop: RLCandleDTO {
        let candle = candles[5]
        return RLCandleDTO(
            timestamp: candle.timestamp.addingTimeInterval(3600),
            open: candle.close, high: candle.close + 260, low: candle.close - 20,
            close: candle.close + 200, volume: 1000
        )
    }

    /// What the chart's Setup line system seeds.
    private static func seedSetupLevels(_ state: MarkerPlacementState, entry: Double, long: Bool) {
        state.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: entry, label: "Entry")))
        state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: long ? entry + 240 : entry - 240, label: "TP")))
        state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: long ? entry - 120 : entry + 120, label: "SL")))
        state.trackingEnabled = true
    }
}

#endif
