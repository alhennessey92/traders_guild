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
        /// A linked response being written: the banner first, then the text,
        /// then where it is placed.
        case responseDetails
        case failedPost, retrySuccess, discardConfirm
        /// A linked Setup whose anchor keeps the parent candle's old price:
        /// Review shows the Entry line, not the anchor.
        case responseSetupEntry
        /// The same Setup posted after the price rose through its stop: the
        /// post is stopped on the device and nothing reaches the transport.
        case setupMarketMoved

        // Guided editing of an existing marker (the fixture transport answers
        // updates as chart-service does).
        /// An untouched edit of a titled Analysis that answers another marker.
        case editAnalysis
        /// Title cleared and text edited, on Review.
        case editAnalysisReview
        case editQuestion
        /// A tracked Setup still ARMED, its take profit moved, on Review.
        case editSetupArmedReview
        /// A tracked ACTIVE Setup: levels, tracking and context locked.
        case editSetupActive
        /// Save fails once; the changes stay for a retry.
        case editFailedSave
        /// Save fails once, then Retry succeeds.
        case editRetrySuccess
        /// An edited draft being closed.
        case editDiscard

        var isEdit: Bool { rawValue.hasPrefix("edit") }

        static var launch: Scenario? {
            UserDefaults.standard.string(forKey: "MarkerGuidedCreationFixture").flatMap(Scenario.init(rawValue:))
        }

        var transportMode: MarkerFixtureTransport.Mode {
            switch self {
            case .editFailedSave, .editRetrySuccess:
                return .failFirst(detail: "The server is busy. Try again.")
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
            case .editFailedSave: return 1
            case .editRetrySuccess: return 2
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
    @State private var savedEdit = false
    @State private var showDiscardConfirmation = false
    @State private var closed = false

    init(scenario: Scenario) {
        self.scenario = scenario
        let author = MarkerLinkFixtures.member(1, username: "alex")
        let transport = MarkerFixtureTransport(mode: scenario.transportMode, author: author)
        let manager = MarkerManager(userId: author.userId, guildId: Self.guildId, currentUserMember: author)
        manager.configure(api: transport, symbolId: Self.symbolId, timeframe: .h1)
        if let edited = Self.editedMarker(for: scenario) {
            transport.storedMarkers[edited.id] = edited
            manager.markers = MarkerLinkFixtures.positioned([edited], candles: Self.candles)
        }
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
            if scenario == .discardConfirm || scenario == .editDiscard {
                showDiscardConfirmation = placementState.cancellingNeedsConfirmation
            }
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
            .modifier(MarkerGuidedDiscardConfirmation(
                isPresented: $showDiscardConfirmation,
                isEditing: placementState.isGuidedEdit
            ) { closed = true })
            VStack(alignment: .leading, spacing: 1) {
                Text(placementState.guidedToolbarTitle ?? (closed ? "Closed" : (savedEdit ? "Saved" : "Legacy panel")))
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
            } else if savedEdit {
                Text("Saved: placement would end here. No share prompt, no new marker.")
                    .font(.footnote)
                    .foregroundColor(AppColors.greyText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if placementState.isGuidedFlowActive {
                MarkerGuidedPlacementPanel(
                    placementState: placementState,
                    author: author,
                    guildName: "Alpha Traders",
                    currentChartTimeframe: .h1,
                    // Shown, not acted on: the chart is not in the fixture.
                    onSelectTimeframe: { _ in }
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
        if let json = transport.lastUpdateJSON {
            VStack(alignment: .leading, spacing: 4) {
                Text("Update #\(transport.updateRequests.count) sent to the fixture transport (creates: \(transport.createRequests.count))")
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
        if placementState.isGuidedEdit {
            guard placementState.canSaveGuidedEdit else { return }
            let outcome = await MarkerPlacementSubmitter.submitUpdate(
                placementState: placementState,
                markerManager: markerManager
            )
            if !outcome.isStale, case .success = outcome.result {
                // What the chart does on success: leave placement.
                placementState.clearMarkerEditSession()
                placementState.endGuidedFlow()
                savedEdit = true
            }
            return
        }
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
        if let edited = editedMarker(for: scenario) {
            return makeEditDraft(for: scenario, marker: MarkerLinkFixtures.positioned([edited], candles: candles)[0])
        }
        let state = MarkerPlacementState()
        let candle = candles[5]
        let isSetup = [.setupTracked, .setupUntracked, .setupReview].contains(scenario)
        let isResponse = [.responseChooser, .responseDetails, .responseSetupReview, .responseSetupEntry, .setupMarketMoved].contains(scenario)
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
        case .responseDetails:
            state.note = "Not convinced — volume is fading."
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
        case .editAnalysis, .editAnalysisReview, .editQuestion, .editSetupArmedReview,
             .editSetupActive, .editFailedSave, .editRetrySuccess, .editDiscard:
            break  // built by makeEditDraft
        }
        return state
    }

    // MARK: Edits

    /// What the edit entry point does: hydrate, allow a text-only Analysis,
    /// open the guided sheet; then what the author did.
    private static func makeEditDraft(for scenario: Scenario, marker: ChartMarkerUI) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        state.beginEditingMarker(marker)
        state.allowTextOnlyAnalysisEdit()
        state.prepareGuidedEdit(of: marker)
        switch scenario {
        case .editAnalysisReview, .editFailedSave, .editRetrySuccess, .editDiscard:
            state.title = ""
            state.note = "Sellers stalled at 63.8k three times. Still expecting the range high."
            if scenario == .editAnalysisReview { state.continueToReview() }
            if scenario == .editFailedSave || scenario == .editRetrySuccess { state.continueToReview() }
        case .editSetupArmedReview:
            let tp = state.componentPrice(.levelTp) ?? 0
            state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: tp + 160, label: "TP")))
            state.continueToReview()
        default:
            break
        }
        return state
    }

    /// The marker each edit scenario opens, as the server holds it.
    static func editedMarker(for scenario: Scenario) -> RLChartMarkerDTO? {
        guard scenario.isEdit else { return nil }
        let candle = candles[5]
        let me = MarkerLinkFixtures.member(1, username: "alex")
        func level(_ type: RLComponentType, _ price: Double, _ n: Int) -> RLMarkerComponentDTO {
            let payload = LevelPayload(price: price, label: nil, colorHex: nil, lineStyle: nil, lineWidth: nil)
            let typed: MarkerComponentPayload = type == .levelEntry ? .levelEntry(payload)
                : (type == .levelTp ? .levelTp(payload) : .levelSl(payload))
            return RLMarkerComponentDTO(id: MarkerLinkFixtures.uuid(8_000 + n), componentType: type.rawValue, payload: typed, ordering: n)
        }
        let anchor = RLMarkerComponentDTO(
            id: MarkerLinkFixtures.uuid(8_100), componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: candle.timestamp, price: candle.close)), ordering: 0
        )
        var intent = RLMarkerIntent.analysis
        var title: String? = "Higher lows"
        var note: String? = "BTC is holding higher lows into the open. Watching 63.8k."
        var components = [anchor]
        var tracking = false
        var state: String?
        var parent: UUID?
        var relationship: String?
        var preview: RLMarkerLinkPreviewDTO?
        switch scenario {
        case .editQuestion:
            intent = .question
            title = nil
            note = "Is the range high still the target?"
        case .editSetupArmedReview, .editSetupActive:
            intent = .setup
            title = "Long the range-low retest"
            note = "Invalidated below the shelf."
            tracking = true
            state = scenario == .editSetupActive ? "ACTIVE" : "ARMED"
            components = [anchor, level(.levelEntry, candle.close, 1), level(.levelTp, candle.close + 480, 2),
                          level(.levelSl, candle.close - 220, 3)]
        default:
            parent = MarkerLinkFixtures.uuid(77)
            relationship = "supports"
            preview = MarkerLinkFixtures.preview(77, author: "sam", title: "BTC breakout", relationship: nil)
        }
        return RLChartMarkerDTO(
            id: MarkerLinkFixtures.uuid(600), symbolId: symbolId, guildId: guildId, author: me,
            candleTimestamp: candle.timestamp, timeframe: "1h", price: candle.close,
            intent: intent.rawValue, title: title, note: note, visibility: "guild", confidence: nil,
            trackingEnabled: tracking, trackingState: state, alertSeverity: nil,
            createdAt: candle.timestamp, createdAtFormatted: "2h ago", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: components, primaryComponentId: anchor.id,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: parent, linkRelationship: relationship, parentPreview: preview,
            directResponseCount: 0
        )
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
