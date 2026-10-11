import Foundation
import Testing
@testable import traders_guild

/// Poll and Alert as v1.5 Post types (owner, 11 Oct): one text field shared
/// with Analysis and Question, plus the type's own setting — a poll's choices,
/// an alert's severity — sent the way chart-service and older apps read them.
///
/// Server rules mirrored (chart_schema `validate_marker_content_rules`):
/// a poll needs `poll_question` and two non-empty `poll_options`, and its
/// question is stored as the title (200 characters); an alert's note must
/// start with "[Informational] ", "[Warning] ", "[Severe] " or "[Critical] "
/// and carry at least 10 characters after it.
@MainActor
struct MarkerGuidedPollAlertTests {

    private let symbolId = MarkerLinkFixtures.uuid(1)
    private let guildId = MarkerLinkFixtures.uuid(2)
    private let candles = MarkerLinkFixtures.candles()
    private let markerId = MarkerLinkFixtures.uuid(610)
    private var candle: RLCandleDTO { candles[5] }

    // MARK: Helpers

    private func guidedDraft(_ intent: RLMarkerIntent) -> MarkerPlacementState {
        let state = MarkerPlacementState()
        state.prepareGuidedFlow()
        state.reset(to: intent, anchorTime: candle.timestamp, anchorPrice: candle.close)
        state.captureDraftBaseline()
        return state
    }

    private func request(_ state: MarkerPlacementState) -> RLCreateMarkerRequest {
        state.buildCreateRequest(symbolId: symbolId, timeframe: "1h")
    }

    private func dto(
        intent: RLMarkerIntent,
        title: String?,
        note: String?,
        pollQuestion: String? = nil,
        pollOptions: [RLPollOptionDTO]? = nil
    ) -> RLChartMarkerDTO {
        let anchor = RLMarkerComponentDTO(
            id: MarkerLinkFixtures.uuid(8_110), componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: candle.timestamp, price: candle.close)), ordering: 0
        )
        return RLChartMarkerDTO(
            id: markerId, symbolId: symbolId, guildId: guildId, author: MarkerLinkFixtures.member(1, username: "alex"),
            candleTimestamp: candle.timestamp, timeframe: "1h", price: candle.close,
            intent: intent.rawValue, title: title, note: note, visibility: "guild", confidence: nil,
            trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: candle.timestamp, createdAtFormatted: "2h ago", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: [anchor], primaryComponentId: anchor.id,
            pollQuestion: pollQuestion, pollOptions: pollOptions, userPollVote: nil, predictionResult: nil,
            parentMarkerId: nil, linkRelationship: nil, parentPreview: nil,
            directResponseCount: 0
        )
    }

    /// What the edit entry point does under the experiment.
    private func edit(_ marker: RLChartMarkerDTO) -> MarkerPlacementState {
        let ui = MarkerLinkFixtures.positioned([marker], candles: candles)[0]
        let state = MarkerPlacementState()
        state.beginEditingMarker(ui)
        state.allowTextOnlyAnalysisEdit()
        state.prepareGuidedEdit(of: ui)
        return state
    }

    // MARK: Poll

    @Test
    func aPollPostsItsQuestionAsTheTitleWithItsChoices() {
        let state = guidedDraft(.poll)
        state.note = "  Which target gets hit first?  "
        state.pollOptions = ["64k", " 66k ", ""]
        #expect(state.isValid)

        let sent = request(state)
        #expect(sent.intent == "poll")
        #expect(sent.title == "Which target gets hit first?")
        #expect(sent.pollQuestion == "Which target gets hit first?")
        #expect(sent.pollOptions == ["64k", "66k"])
        // The question is not repeated as a note.
        #expect(sent.note == nil)
    }

    @Test
    func aPollNeedsTwoChoicesAndStaysInsideTheServersLimits() {
        let state = guidedDraft(.poll)
        #expect(state.guidedNextStepPrompt == "Ask your poll question to continue")

        state.note = "Which target first?"
        state.pollOptions = ["64k", ""]
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Add at least two choices")

        state.pollOptions = ["64k", "66k"]
        #expect(state.isValid)
        #expect(state.guidedNextStepPrompt == nil)

        // The question is the title on the server: 200 characters.
        state.note = String(repeating: "q", count: 201)
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Shorten your question by 1 character")
        state.note = String(repeating: "q", count: 200)
        #expect(state.isValid)

        state.pollOptions = ["64k", String(repeating: "c", count: 81)]
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Keep each choice to 80 characters")

        state.pollOptions = ["a", "b", "c", "d", "e"]
        #expect(!state.isValid, "the sheet offers at most four choices")
    }

    // MARK: Alert

    @Test
    func anAlertSendsItsSeverityAtTheFrontOfItsNote() {
        let state = guidedDraft(.alert)
        state.note = "Liquidity sweep under the Asia lows"
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Choose how urgent this is")

        state.alertSeverity = .severe
        #expect(state.isValid)
        #expect(request(state).note == "[Severe] Liquidity sweep under the Asia lows")
        #expect(request(state).intent == "alert")

        // The four words the server reads, from mildest to most urgent.
        for (severity, prefix) in [(MarkerAlertSeverity.mild, "[Informational] "), (.moderate, "[Warning] "),
                                   (.severe, "[Severe] "), (.critical, "[Critical] ")] {
            state.alertSeverity = severity
            #expect(request(state).note == prefix + "Liquidity sweep under the Asia lows")
        }
    }

    @Test
    func anAlertNeedsTenCharactersOfDescription() {
        let state = guidedDraft(.alert)
        state.alertSeverity = .moderate
        #expect(state.guidedNextStepPrompt == "Say what the guild should watch")
        state.note = "Sweep"
        #expect(!state.isValid)
        #expect(state.guidedNextStepPrompt == "Write 5 more characters")
        state.note = "Sweep lows"
        #expect(state.isValid)
    }

    // MARK: Switching type

    @Test
    func switchingTypeKeepsTheTextAndEachTypesSetting() {
        let state = guidedDraft(.analysis)
        state.note = "Range low is holding for now"

        #expect(state.requestGuidedIntentChange(to: .poll) == nil)
        #expect(state.intent == .poll)
        #expect(state.note == "Range low is holding for now")
        state.pollOptions = ["Holds", "Breaks"]

        #expect(state.requestGuidedIntentChange(to: .alert) == nil)
        state.alertSeverity = .critical
        #expect(state.pollOptions == ["Holds", "Breaks"], "kept while trying another type")
        #expect(request(state).pollOptions == nil, "only the chosen type's setting is sent")
        #expect(request(state).note == "[Critical] Range low is holding for now")

        #expect(state.requestGuidedIntentChange(to: .poll) == nil)
        #expect(state.alertSeverity == .critical)
        #expect(request(state).pollOptions == ["Holds", "Breaks"])
        #expect(request(state).note == nil)

        #expect(state.requestGuidedIntentChange(to: .analysis) == nil)
        let analysis = request(state)
        #expect(analysis.note == "Range low is holding for now")
        #expect(analysis.title == nil)
        #expect(analysis.pollQuestion == nil)
        #expect(analysis.pollOptions == nil)
    }

    @Test
    func aSourceLinkIsNotCarriedSilentlyIntoAPollOrAnAlert() throws {
        for target in [RLMarkerIntent.poll, .alert] {
            let state = guidedDraft(.analysis)
            state.note = "Range low is holding"
            state.upsertComponent(.linkURL, payload: .link(LinkPayload(url: "https://example.com/a", title: nil, previewImage: nil)))
            let change = try #require(state.requestGuidedIntentChange(to: target))
            #expect(change.targetIntent == target)
            #expect(state.intent == .analysis, "nothing changes until the author agrees")
            state.applyGuidedIntentChange(change)
            #expect(state.intent == target)
            #expect(state.component(.linkURL) == nil)
        }
    }

    @Test
    func theLegacyComposerIsUnchanged() {
        let legacy = MarkerPlacementState()
        legacy.reset(to: .poll, anchorTime: candle.timestamp, anchorPrice: candle.close)
        legacy.pollQuestion = "Legacy question?"
        legacy.pollOptions = ["a", "b"]
        legacy.note = "A note beside it"
        let sent = legacy.buildCreateRequest(symbolId: symbolId, timeframe: "1h")
        #expect(sent.title == "Legacy question?")
        #expect(sent.pollQuestion == "Legacy question?")
        #expect(sent.note == "A note beside it")

        legacy.setIntent(.analysis)
        #expect(legacy.pollQuestion.isEmpty)
        #expect(legacy.pollOptions == ["", ""])

        legacy.setIntent(.alert)
        legacy.alertSeverity = .severe
        legacy.note = "[Severe] Written by the legacy composer"
        #expect(legacy.buildCreateRequest(symbolId: symbolId, timeframe: "1h").note == "[Severe] Written by the legacy composer")
        legacy.setIntent(.question)
        #expect(legacy.alertSeverity == nil)
    }

    // MARK: Editing

    @Test
    func aPollEditChangesItsQuestionAndKeepsItsChoices() {
        let options = [
            RLPollOptionDTO(id: MarkerLinkFixtures.uuid(9_001), text: "64k", voteCount: 3, hasVoted: false),
            RLPollOptionDTO(id: MarkerLinkFixtures.uuid(9_002), text: "66k", voteCount: 1, hasVoted: true),
        ]
        let state = edit(dto(intent: .poll, title: "Which target first?", note: nil,
                             pollQuestion: "Which target first?", pollOptions: options))
        #expect(state.isGuidedEdit)
        #expect(state.note == "Which target first?")
        #expect(state.title.isEmpty)
        #expect(state.validPollOptions == ["64k", "66k"])
        #expect(!state.guidedEditHasChanges)

        state.note = "Which target gets hit first?"
        #expect(state.guidedEditHasChanges)
        #expect(state.canContinueToReview)
        #expect(state.guidedEditChangeLines == ["Question edited"])
        let sent = state.buildGuidedUpdateRequest()
        #expect(sent.title == "Which target gets hit first?")
        #expect(sent.pollQuestion == "Which target gets hit first?")
        #expect(sent.note == nil)
        #expect(sent.pollOptions == nil, "choices are fixed once posted")
        #expect(sent.components == nil)
        #expect(sent.intent == nil)
    }

    @Test
    func anAlertEditReadsItsSeverityApartAndSendsBothBack() {
        let state = edit(dto(intent: .alert, title: nil, note: "[Warning] Funding flipped negative on the perp"))
        #expect(state.isGuidedEdit)
        #expect(state.alertSeverity == .moderate)
        #expect(state.note == "Funding flipped negative on the perp")
        #expect(!state.guidedEditHasChanges)

        state.alertSeverity = .critical
        #expect(state.guidedEditHasChanges)
        #expect(state.guidedEditChangeLines == ["Severity: Warning → Critical"])
        let sent = state.buildGuidedUpdateRequest()
        #expect(sent.note == "[Critical] Funding flipped negative on the perp")
        #expect(sent.title == nil)
        #expect(!sent.clearsNote)

        state.alertSeverity = .moderate
        state.note = "Funding flipped negative on every perp"
        #expect(state.guidedEditChangeLines == ["Description edited"])
        #expect(state.buildGuidedUpdateRequest().note == "[Warning] Funding flipped negative on every perp")
    }
}
