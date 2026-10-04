import Foundation
import Testing
@testable import traders_guild

/// v1.5 guided editing over the real `MarkerPlacementState`,
/// `MarkerPlacementSubmitter.submitUpdate` and `MarkerManager.updateMarkerFromPlacement`,
/// with `MarkerFixtureTransport` answering updates as chart-service
/// `update_marker` does (fields present are applied, `null` clears; components
/// replace all and need one anchor; components on a tracked Setup past ARMED
/// are refused). The transport is not the backend.
@MainActor
struct MarkerGuidedEditingTests {

    private let symbolId = MarkerLinkFixtures.uuid(1)
    private let guildId = MarkerLinkFixtures.uuid(2)
    private let candles = MarkerLinkFixtures.candles()
    private let markerId = MarkerLinkFixtures.uuid(600)
    private var candle: RLCandleDTO { candles[5] }

    // MARK: Fixtures

    private func level(_ type: RLComponentType, _ price: Double, _ n: Int) -> RLMarkerComponentDTO {
        let payload = LevelPayload(price: price, label: nil, colorHex: nil, lineStyle: nil, lineWidth: nil)
        let typed: MarkerComponentPayload
        switch type {
        case .levelEntry: typed = .levelEntry(payload)
        case .levelTp: typed = .levelTp(payload)
        case .levelSl: typed = .levelSl(payload)
        default: typed = .levelSupport(payload)
        }
        return RLMarkerComponentDTO(id: MarkerLinkFixtures.uuid(8_000 + n), componentType: type.rawValue, payload: typed, ordering: n)
    }

    private func anchor(price: Double) -> RLMarkerComponentDTO {
        RLMarkerComponentDTO(id: MarkerLinkFixtures.uuid(8_100), componentType: RLComponentType.anchor.rawValue,
                             payload: .anchor(AnchorPayload(time: candle.timestamp, price: price)), ordering: 0)
    }

    /// A component type this build does not know, as a newer server could send.
    private var unrecognised: RLMarkerComponentDTO {
        RLMarkerComponentDTO(id: MarkerLinkFixtures.uuid(8_200), componentType: "future.widget",
                             payload: .unknown(type: "future.widget", rawPayload: ["shape": AnyCodable("star"), "size": AnyCodable(3)]),
                             ordering: 9)
    }

    private func dto(
        intent: RLMarkerIntent,
        title: String? = "Higher lows",
        note: String? = "BTC is holding higher lows into the open.",
        components: [RLMarkerComponentDTO]? = nil,
        tracking: Bool = false,
        state: RLTrackingState? = nil,
        linked: Bool = false
    ) -> RLChartMarkerDTO {
        let comps = components ?? [anchor(price: candle.close)]
        return RLChartMarkerDTO(
            id: markerId, symbolId: symbolId, guildId: guildId, author: MarkerLinkFixtures.member(1, username: "alex"),
            candleTimestamp: candle.timestamp, timeframe: "1h", price: candle.close,
            intent: intent.rawValue, title: title, note: note, visibility: "guild", confidence: nil,
            trackingEnabled: tracking, trackingState: state?.rawValue, alertSeverity: nil,
            createdAt: candle.timestamp, createdAtFormatted: "2h ago", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: comps, primaryComponentId: comps.first?.id,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: linked ? MarkerLinkFixtures.uuid(77) : nil,
            linkRelationship: linked ? "supports" : nil,
            parentPreview: linked ? MarkerLinkFixtures.preview(77, author: "sam", title: "BTC breakout", relationship: nil) : nil,
            directResponseCount: 0
        )
    }

    /// A Setup whose Entry is not the anchor price (as an API-created or
    /// linked Setup can be). Long: SL < Entry < TP.
    private func setupDTO(state: RLTrackingState, tracking: Bool = true) -> RLChartMarkerDTO {
        dto(intent: .setup, title: "Long the retest", note: "Invalidated below the shelf.",
            components: [anchor(price: 63_500), level(.levelEntry, 63_920.5, 1),
                         level(.levelTp, 64_400.25, 2), level(.levelSl, 63_700.75, 3)],
            tracking: tracking, state: state)
    }

    private struct Edit {
        let state: MarkerPlacementState
        let manager: MarkerManager
        let transport: MarkerFixtureTransport
    }

    /// What the edit entry point does under the experiment.
    private func edit(_ marker: RLChartMarkerDTO, mode: MarkerFixtureTransport.Mode = .succeed) -> Edit {
        let author = MarkerLinkFixtures.member(1, username: "alex")
        let transport = MarkerFixtureTransport(mode: mode, author: author)
        transport.storedMarkers[marker.id] = marker
        let manager = MarkerManager(userId: author.userId, guildId: guildId, currentUserMember: author)
        manager.configure(api: transport, symbolId: symbolId, timeframe: .h1)
        let ui = MarkerLinkFixtures.positioned([marker], candles: candles)[0]
        manager.markers = [ui]
        let state = MarkerPlacementState()
        state.beginEditingMarker(ui)
        state.allowTextOnlyAnalysisEdit()
        state.prepareGuidedEdit(of: ui)
        return Edit(state: state, manager: manager, transport: transport)
    }

    private func json(_ request: RLUpdateMarkerRequest) -> [String: Any] {
        let data = try! JSONEncoder().encode(request)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func price(_ components: [RLMarkerComponentRequest]?, _ type: RLComponentType) -> Double? {
        guard let match = components?.first(where: { $0.componentType == type.rawValue }) else { return nil }
        return MarkerComponentPayload.decode(componentType: match.componentType, rawPayload: match.payload).levelPrice
    }

    @Test(arguments: [RLTrackingState.armed, .active, .tpHit, .slHit, .expired])
    func workspaceEntryAndNavigationKeepSavedSetupGeometry(_ trackingState: RLTrackingState) {
        let e = edit(setupDTO(state: trackingState))
        let saved = e.state.components
        let anchor = e.state.anchorDraft
        e.state.refreshSetupEntryForPosting(latest: candles.last!)
        e.state.openContext()
        if trackingState == .armed {
            e.state.beginWorkspaceIndicator(IndicatorCatalogItem(type: .ema))
            e.state.workspace.indicatorDraft?.intValues["period"] = "123"
            e.state.goBack()
        } else {
            #expect(!e.state.workspaceAllows(.indicator))
            e.state.beginWorkspaceIndicator(IndicatorCatalogItem(type: .ema))
            #expect(e.state.workspace.indicatorDraft == nil)
        }
        e.state.backToDetails()
        #expect(e.state.components == saved)
        #expect(e.state.anchorDraft == anchor)
        #expect(e.state.componentPrice(.levelEntry) == 63_920.5)
        #expect(e.state.componentPrice(.levelSl) == 63_700.75)
        #expect(e.state.componentPrice(.levelTp) == 64_400.25)
        #expect(e.state.buildGuidedUpdateRequest().components == nil)
    }

    // MARK: Update, not create

    @Test
    func aGuidedEditSavesAnUpdateAndNeverCreates() async {
        let e = edit(dto(intent: .analysis))
        #expect(e.state.isGuidedEdit)
        #expect(e.state.guidedToolbarTitle == "Edit Analysis")
        e.state.note = "Sellers stalled at 63.8k three times."
        #expect(e.state.continueToReview())

        let outcome = await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager)

        #expect(!outcome.isStale)
        guard case .success(let saved) = outcome.result else { Issue.record("save failed"); return }
        #expect(saved?.note == "Sellers stalled at 63.8k three times.")
        #expect(e.transport.createRequests.isEmpty, "an edit never creates")
        #expect(e.transport.updateRequests.count == 1)
        #expect(e.transport.updateRequests.first?.markerId == markerId)
        #expect(e.manager.markers.count == 1, "no second marker")
        #expect(e.manager.markers.first?.note == "Sellers stalled at 63.8k three times.")
        #expect(e.state.submissionPhase == .idle)
        #expect(!e.state.linkSession.isActive, "no response is started")
    }

    @Test
    func onlyWhatChangedIsSent() {
        let e = edit(dto(intent: .analysis))
        e.state.note = "Edited."
        let body = json(e.state.buildGuidedUpdateRequest())
        #expect(Set(body.keys) == ["note"], "title, type, visibility, tracking and components are left out: \(body.keys)")
    }

    // MARK: Hydration and component preservation

    @Test
    func editingContextKeepsEveryComponentIncludingOnesThisBuildCannotRead() {
        let support = level(.levelSupport, 63_780, 4)
        let e = edit(dto(intent: .analysis, components: [anchor(price: 63_812.5), support, unrecognised]))
        #expect(e.state.title == "Higher lows")
        #expect(e.state.note == "BTC is holding higher lows into the open.")
        #expect(e.state.components.contains { $0.componentType == .levelSupport })

        // A title edit leaves the components alone.
        e.state.title = "Higher lows holding"
        #expect(e.state.buildGuidedUpdateRequest().components == nil)

        // A context edit sends all of them.
        e.state.upsertComponent(.timeframeLink, payload: .timeframeLink(TimeframeLinkPayload(timeframe: "4h", note: nil)))
        let components = e.state.buildGuidedUpdateRequest().components ?? []
        let types = components.map(\.componentType)
        #expect(types.filter { $0 == RLComponentType.anchor.rawValue }.count == 1)
        #expect(types.contains(RLComponentType.levelSupport.rawValue))
        #expect(types.contains(RLComponentType.timeframeLink.rawValue))
        #expect(types.contains("future.widget"), "the unreadable component is sent back, not deleted")
        let widget = components.first { $0.componentType == "future.widget" }
        #expect(widget?.payload["shape"]?.value as? String == "star")
        #expect(price(components, .anchor) == 63_812.5, "the anchor is exact")
    }

    // MARK: Type and link are fixed

    @Test
    func typeAndLinkCannotChange() {
        let e = edit(dto(intent: .analysis, linked: true))
        #expect(e.state.guidedEditOriginal?.linkSentence == "Supports sam's BTC breakout")
        #expect(e.state.requestGuidedIntentChange(to: .question) == nil)
        #expect(e.state.intent == .analysis)
        e.state.openTypeChooser()
        #expect(e.state.guidedStep == .details, "no type list in an edit")

        e.state.title = "Changed"
        let body = json(e.state.buildGuidedUpdateRequest())
        for key in ["intent", "parent_marker_id", "link_relationship", "visibility"] {
            #expect(body[key] == nil, "\(key) is never sent")
        }
    }

    // MARK: Setup restrictions

    @Test
    func anArmedSetupSendsItsLevelsExactlyWithoutRebasing() {
        let e = edit(setupDTO(state: .armed))
        #expect(!e.state.isGuidedEditLocked)
        #expect(e.state.guidedSetupEntryPrice == 63_920.5)
        e.state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 64_600.125, label: "TP")))
        #expect(e.state.canContinueToReview)

        let request = e.state.buildGuidedUpdateRequest()
        #expect(price(request.components, .levelEntry) == 63_920.5, "Entry exactly as saved, not the anchor or a latest price")
        #expect(price(request.components, .anchor) == 63_500, "the anchor is exact")
        #expect(price(request.components, .levelTp) == 64_600.125)
        #expect(price(request.components, .levelSl) == 63_700.75)
        #expect(request.trackingEnabled == nil, "tracking was not touched")

        // The legacy builder would have re-seated Entry on the anchor price.
        #expect(price(e.state.buildUpdateRequest().components, .levelEntry) == 63_500)
    }

    @Test
    func anActiveSetupLocksLevelsTrackingAndContext() async {
        let e = edit(setupDTO(state: .active))
        #expect(e.state.isGuidedEditLocked)
        #expect(e.state.guidedEditLockExplanation?.contains("is active") == true)

        // Moving a level or tracking (not offered by the sheet) is not a change.
        e.state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 65_000, label: "TP")))
        e.state.trackingEnabled = false
        #expect(!e.state.guidedEditHasChanges)
        #expect(!e.state.canContinueToReview)
        #expect(e.state.guidedNextStepPrompt == "Make a change to review it", "single Details requires a change before Review")
        #expect(e.state.continueToSetupReasoning())
        #expect(e.state.guidedNextStepPrompt == "Make a change to review it")

        e.state.note = "Moving my stop mentally to break-even."
        let request = e.state.buildGuidedUpdateRequest()
        #expect(request.components == nil, "the server refuses components after activation")
        #expect(request.trackingEnabled == nil)
        #expect(request.note == "Moving my stop mentally to break-even.")
        #expect(e.state.buildUpdateRequest().components != nil, "the legacy builder would have sent them")

        #expect(e.state.continueToReview())
        let outcome = await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager)
        guard case .success = outcome.result else { Issue.record("locked edit refused"); return }
        #expect(e.transport.storedMarkers[markerId]?.trackingState == "ACTIVE")
    }

    @Test
    func finishedSetupsAreLockedAndUntrackedOnesAreNot() {
        for state in [RLTrackingState.tpHit, .slHit, .expired] {
            let e = edit(setupDTO(state: state))
            #expect(e.state.isGuidedEditLocked, "\(state)")
            #expect(e.state.guidedEditLockExplanation?.contains("has finished") == true)
        }
        #expect(!edit(setupDTO(state: .draft, tracking: false)).state.isGuidedEditLocked)
        #expect(!edit(setupDTO(state: .armed)).state.isGuidedEditLocked)
    }

    @Test
    func anEditableTrackedSetupStillNeedsItsLevelsInOrder() {
        let e = edit(setupDTO(state: .armed))
        e.state.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 64_000, label: "SL")))  // above Entry
        #expect(e.state.guidedTrackedSetupLevelsNeedAdjusting)
        #expect(!e.state.canContinueToReview)
        #expect(e.state.guidedNextStepPrompt == "Put Entry between your stop and target")
    }

    // MARK: Clearing optional values

    @Test
    func clearingTheTitleAndThesisSendsExplicitNulls() async {
        let e = edit(setupDTO(state: .armed))
        e.state.title = ""
        e.state.note = "   "
        let body = json(e.state.buildGuidedUpdateRequest())
        #expect(body.keys.contains("title") && body["title"] is NSNull, "\(body)")
        #expect(body.keys.contains("note") && body["note"] is NSNull, "\(body)")
        #expect(e.state.guidedEditChangeLines.contains("Title removed"))
        #expect(e.state.guidedEditChangeLines.contains("Thesis removed"))

        #expect(e.state.continueToReview())
        let outcome = await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager)
        guard case .success(let saved) = outcome.result else { Issue.record("save failed"); return }
        #expect(saved?.title == nil)
        #expect(saved?.note == nil)
    }

    @Test
    func theLegacyEncodingIsUnchanged() {
        let legacy = RLUpdateMarkerRequest(title: nil, note: nil, trackingEnabled: false)
        let body = json(legacy)
        #expect(body["title"] == nil && body["note"] == nil, "nil is still left out unless a clear is asked for")
        let clearing = RLUpdateMarkerRequest(title: "kept", clearsTitle: true)
        #expect(json(clearing)["title"] as? String == "kept", "a value always wins over a clear")
    }

    // MARK: Validation

    @Test
    func validationMatchesCreation() {
        let question = edit(dto(intent: .question, title: nil, note: "Is the range high still the target?"))
        question.state.note = "Breakout?"
        #expect(!question.state.canContinueToReview)
        #expect(question.state.guidedNextStepPrompt == "Write 1 more character")

        let textOnly = edit(dto(intent: .analysis))
        #expect(textOnly.state.components.map(\.componentType) == [.anchor])
        textOnly.state.note = "Still text only."
        #expect(textOnly.state.canContinueToReview, "a text-only Analysis stays editable")
        textOnly.state.note = ""
        #expect(!textOnly.state.canContinueToReview)
        #expect(textOnly.state.guidedNextStepPrompt == "Write your analysis to continue")
    }

    // MARK: Failure, retry, ownership

    @Test
    func aFailedSaveKeepsTheChangesAndRetrySucceeds() async {
        let e = edit(dto(intent: .analysis), mode: .failFirst(detail: "The server is busy."))
        e.state.note = "Edited once."
        e.state.title = ""
        #expect(e.state.continueToReview())

        let first = await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager)
        guard case .failure = first.result else { Issue.record("expected a failure"); return }
        #expect(e.state.submissionPhase.isFailed)
        #expect(e.state.note == "Edited once." && e.state.title.isEmpty, "the changes stay")
        #expect(e.state.editingMarkerId == markerId && e.state.guidedStep == .review)
        #expect(e.manager.markers.first?.note == "BTC is holding higher lows into the open.", "the optimistic change rolled back")
        #expect(e.state.canSaveGuidedEdit, "Retry is available")

        let retry = await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager)
        guard case .success = retry.result else { Issue.record("retry failed"); return }
        #expect(e.transport.updateRequests.count == 2)
        #expect(e.transport.createRequests.isEmpty)
        #expect(e.transport.storedMarkers[markerId]?.title == nil)
    }

    @Test
    func whileSavingTheEditIsFrozenAndALateAnswerCannotTouchTheNextDraft() async {
        let e = edit(dto(intent: .analysis))
        e.transport.holdsUpdates = true
        e.state.note = "Edited."
        #expect(e.state.continueToReview())

        let saving = Task { await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager) }
        for _ in 0..<200 where e.transport.heldUpdateCount == 0 { await Task.yield() }
        #expect(e.transport.heldUpdateCount == 1)
        #expect(e.state.isGuidedSubmissionInFlight)
        #expect(!e.state.canSaveGuidedEdit, "no second save while one is in flight")
        e.state.backToDetails()
        e.state.openContext()
        #expect(e.state.guidedStep == .review, "navigation is frozen")

        // The edit is left (placement ends) and a new draft begins.
        e.state.endGuidedFlow()
        e.state.clearMarkerEditSession()
        e.state.prepareGuidedFlow()
        e.state.reset(to: .question, anchorTime: candle.timestamp, anchorPrice: candle.close)
        e.state.note = "A new question draft."

        e.transport.releaseHeldUpdates()
        let outcome = await saving.value
        #expect(outcome.isStale)
        #expect(e.state.submissionPhase == .idle, "the new draft is untouched")
        #expect(e.state.note == "A new question draft.")
        #expect(e.state.intent == .question)
    }

    // MARK: Discard

    @Test
    func onlyAnEditedDraftAsksBeforeDiscarding() {
        let e = edit(dto(intent: .analysis))
        #expect(!e.state.cancellingNeedsConfirmation, "an untouched edit closes without asking")
        e.state.title = "Changed"
        #expect(e.state.cancellingNeedsConfirmation)
        e.state.title = "Higher lows"
        #expect(!e.state.cancellingNeedsConfirmation, "changed back is untouched")
        e.state.openContext()
        e.state.backToDetails()
        #expect(e.state.title == "Higher lows" && e.state.note == "BTC is holding higher lows into the open.",
                "moving between steps resets nothing")
    }

    // MARK: Review

    @Test
    func reviewListsWhatChanges() {
        let e = edit(setupDTO(state: .armed))
        #expect(e.state.guidedEditChangeLines.isEmpty)
        e.state.title = "Long the range-low retest"
        e.state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 64_600, label: "TP")))
        e.state.trackingEnabled = false
        #expect(e.state.guidedEditChangeLines == [
            "Title edited",
            "Take Profit 64,400.25 → 64,600.00",
            "Tracking turned off",
        ])
        #expect(e.state.guidedStepPrompt == "Edit your Setup")
    }

    // MARK: Gate

    @Test
    func otherTypesAndTheExperimentOffKeepTheExistingEditor() {
        #expect(!MarkerPlacementState.usesGuidedEdit(for: .analysis, experimentEnabled: false))
        for intent in [RLMarkerIntent.analysis, .question, .setup] {
            #expect(MarkerPlacementState.usesGuidedEdit(for: intent, experimentEnabled: true))
        }
        for intent in [RLMarkerIntent.alert, .poll, .news, .reaction, .personal] {
            #expect(!MarkerPlacementState.usesGuidedEdit(for: intent, experimentEnabled: true))
        }
        let legacy = MarkerPlacementState()
        legacy.beginEditingMarker(MarkerLinkFixtures.positioned([dto(intent: .analysis)], candles: candles)[0])
        #expect(!legacy.isGuidedEdit)
        #expect(legacy.guidedToolbarTitle == nil)
    }
}
