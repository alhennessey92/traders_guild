import Foundation
import Testing
@testable import traders_guild

/// Stage 4 finding: an Analysis the guided flow posted as text alone could not
/// be saved from the edit panel without adding a chart component, although the
/// Stage 4 backend accepts it on update. Under the experiment the edit entry
/// point now allows it; with the experiment off the legacy rule is unchanged.
@MainActor
struct MarkerTextOnlyAnalysisEditTests {

    private let candle = MarkerLinkFixtures.candles()[5]

    /// A text-only Analysis as the server returns it: the anchor and a thesis.
    private func textOnlyAnalysis(note: String = "Sellers stalled at the shelf") -> ChartMarkerUI {
        let anchor = RLMarkerComponentDTO(
            id: UUID(),
            componentType: RLComponentType.anchor.rawValue,
            payload: .anchor(AnchorPayload(time: candle.timestamp, price: candle.high)),
            ordering: 0
        )
        let author = MarkerLinkFixtures.member(1, username: "alex")
        let dto = RLChartMarkerDTO(
            id: UUID(), symbolId: MarkerLinkFixtures.uuid(1), guildId: MarkerLinkFixtures.uuid(2), author: author,
            candleTimestamp: candle.timestamp, timeframe: "5m", price: candle.high,
            intent: RLMarkerIntent.analysis.rawValue, title: nil, note: note,
            visibility: "guild", confidence: nil, trackingEnabled: false, trackingState: nil,
            alertSeverity: nil, createdAt: candle.timestamp, createdAtFormatted: "just now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: [anchor], primaryComponentId: anchor.id,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: nil, linkRelationship: nil
        )
        return ChartMarkerUI(marker: dto, candleIndex: 5)
    }

    /// What `MainView.beginEditingSelectedMarker` does with the experiment on or off.
    private func beginEdit(_ state: MarkerPlacementState, _ marker: ChartMarkerUI, experiment: Bool) {
        state.beginEditingMarker(marker)
        if experiment { state.allowTextOnlyAnalysisEdit() }
    }

    @Test
    func underTheExperimentATextOnlyAnalysisSavesAsText() {
        let state = MarkerPlacementState()
        beginEdit(state, textOnlyAnalysis(), experiment: true)
        #expect(state.isValid)
        #expect(state.unmetRequiredChecklistItems.isEmpty)

        state.note = "Revised: sellers stalled twice"
        let request = state.buildUpdateRequest()
        #expect(request.note == "Revised: sellers stalled twice")
        #expect(request.components?.map(\.componentType) == [RLComponentType.anchor.rawValue])

        state.note = "   "
        #expect(!state.isValid, "the thesis is still required")
    }

    @Test
    func withTheExperimentOffTheLegacyRuleStands() {
        let state = MarkerPlacementState()
        beginEdit(state, textOnlyAnalysis(), experiment: false)
        #expect(!state.isValid)
        #expect(state.unmetRequiredChecklistItems.map(\.id) == ["analysis_structure"])
    }

    @Test
    func theAllowanceEndsWithTheEditSession() {
        let state = MarkerPlacementState()
        beginEdit(state, textOnlyAnalysis(), experiment: true)
        #expect(state.isValid)

        state.clearMarkerEditSession()
        #expect(!state.textOnlyAnalysisEditAllowed)
        state.reset(to: .analysis, anchorTime: candle.timestamp, anchorPrice: candle.close)
        state.note = "A new legacy Analysis"
        #expect(!state.isValid, "a legacy create still needs a component")

        beginEdit(state, textOnlyAnalysis(), experiment: false)
        #expect(!state.isValid, "each edit session starts strict")
    }

    @Test
    func outsideAnEditSessionTheAllowanceIsIgnored() {
        let state = MarkerPlacementState()
        state.reset(to: .analysis, anchorTime: candle.timestamp, anchorPrice: candle.close)
        state.note = "A new legacy Analysis"
        state.allowTextOnlyAnalysisEdit()
        #expect(!state.textOnlyAnalysisEditAllowed)
        #expect(!state.isValid)
    }
}
