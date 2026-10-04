import XCTest
@testable import traders_guild

/// Opt-in local integration, never an authentication path in the app.
/// Run only after outbound-safe stack preflight; credentials remain in their
/// protected host file, and this test's token lives only in its API instance.
#if targetEnvironment(simulator)
@MainActor
final class MarkerLocalWorkspaceIntegrationTests: XCTestCase {
    private struct Credentials: Decodable {
        struct Account: Decodable { let email: String; let password: String }
        let gateway: String
        let accounts: [String: Account]
        let guild_id: UUID
        let symbol_id: UUID
    }
    private enum HarnessError: Error { case unsafeConfiguration, authenticationFailed, submissionFailed }

    func testFinalWorkspaceAgainstExistingLocalBackend() async throws {
        guard MarkerAvatarExperiment.isAvailable else { throw XCTSkip("Isolated DEV build required.") }
        guard let path = ProcessInfo.processInfo.environment["TG_LOCAL_WORKSPACE_QA_FILE"] else {
            throw XCTSkip("Opt-in local QA credentials path is required; run stack safety preflight first.")
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else { throw HarnessError.unsafeConfiguration }
        let creds = try JSONDecoder().decode(Credentials.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let base = APIService.chart.baseURL
        guard creds.gateway == "http://127.0.0.1:30080/api/v1",
              ["http://localhost:30080/api/v1", creds.gateway].contains(base),
              APIService.core.baseURL == base, APIService.auth.baseURL == base,
              let account = creds.accounts["a"] else { throw HarnessError.unsafeConfiguration }
        // Use a silent URLSession login, so credentials/tokens never reach the
        // API debug logger, test attachments or persistent app authentication.
        var login = URLRequest(url: URL(string: creds.gateway + "/auth/login")!)
        login.httpMethod = "POST"
        login.setValue("application/json", forHTTPHeaderField: "Content-Type")
        login.httpBody = try JSONSerialization.data(withJSONObject: ["email": account.email, "password": account.password])
        let (data, response) = try await URLSession.shared.data(for: login)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = body["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else { throw HarnessError.authenticationFailed }
        let api = RealAPIService()
        api.setAccessToken(token)
        let user = try await api.getCurrentUser()
        let member = try await api.getGuildMember(guildId: creds.guild_id, userId: user.id)
        let candles = try await api.getCandles(symbolId: creds.symbol_id, timeframe: "1w", limit: 10).candles
        let candle = try XCTUnwrap(candles.last)
        let run = "phaseb-" + String(UUID().uuidString.lowercased().prefix(8))
        var created: [UUID] = []
        let manager = MarkerManager(userId: user.id, guildId: creds.guild_id, currentUserMember: member)
        manager.configure(api: api, symbolId: creds.symbol_id, timeframe: .w1)

        func draft(_ intent: RLMarkerIntent, price: Double? = nil) -> MarkerPlacementState {
            let state = MarkerPlacementState()
            state.prepareGuidedFlow()
            state.reset(to: intent, anchorTime: candle.timestamp, anchorPrice: price ?? candle.close)
            state.title = String(run)
            state.note = intent == .question ? "Does this local QA range hold?" : "A"
            state.captureDraftBaseline()
            return state
        }
        func post(_ state: MarkerPlacementState, timeframe: String = "1w", requestOverride: RLCreateMarkerRequest? = nil) async throws -> RLChartMarkerDTO {
            XCTAssertTrue(state.continueToReview())
            var result = await MarkerPlacementSubmitter.submitCreate(request: requestOverride ?? state.buildCreateRequest(symbolId: creds.symbol_id, timeframe: timeframe),
                candleIndex: candles.count - 1, candles: candles, placementState: state, markerManager: manager, symbolTicker: "BTC")
            if case .failure(let failure) = result.result,
               failure == .trackedSetupConflictSymbolTimeframe || failure == .trackedSetupLimitReached {
                guard state.intent == .setup, state.trackingEnabled else { throw HarnessError.submissionFailed }
                let preserved = state.components
                let preservedNote = state.note
                // Preserve existing tracked QA setups. This dedicated new draft
                // exercises the existing quota error and retries untracked.
                state.trackingEnabled = false
                result = await MarkerPlacementSubmitter.submitCreate(request: state.buildCreateRequest(symbolId: creds.symbol_id, timeframe: timeframe),
                    candleIndex: candles.count - 1, candles: candles, placementState: state, markerManager: manager, symbolTicker: "BTC")
                XCTAssertEqual(state.components, preserved)
                XCTAssertEqual(state.note, preservedNote)
                print("LOCAL_QA_TRACKED_CREATE_REFUSAL \(failure); untracked retry preserves existing tracked data")
            }
            guard case .success(let saved) = result.result, let saved else { throw HarnessError.submissionFailed }
            created.append(saved.id)
            print("LOCAL_QA_CREATED \(run) \(saved.id) \(saved.intent) \(saved.timeframe)")
            return try await api.getMarker(markerId: saved.id)
        }
        func edit(_ marker: RLChartMarkerDTO) -> MarkerPlacementState {
            let ui = ChartMarkerUI(marker: marker, candleIndex: candles.count - 1)
            manager.markers = [ui]
            let state = MarkerPlacementState()
            state.beginEditingMarker(ui)
            state.allowTextOnlyAnalysisEdit()
            state.prepareGuidedEdit(of: ui)
            return state
        }
        func save(_ state: MarkerPlacementState) async throws {
            let outcome = await MarkerPlacementSubmitter.submitUpdate(placementState: state, markerManager: manager)
            guard case .success = outcome.result else { throw HarnessError.submissionFailed }
        }
        let analysis = try await post(draft(.analysis))
        XCTAssertEqual(analysis.note, "A")
        XCTAssertEqual(analysis.components.count, 1)
        let analysisEdit = edit(analysis)
        analysisEdit.note = "Local analysis edited"
        XCTAssertNil(analysisEdit.buildGuidedUpdateRequest().components)
        try await save(analysisEdit)
        let editedAnalysis = try await api.getMarker(markerId: analysis.id)
        XCTAssertEqual(editedAnalysis.note, "Local analysis edited")
        let question = try await post(draft(.question))
        let questionEdit = edit(question)
        questionEdit.note = "Does the edited local range still hold?"
        try await save(questionEdit)
        let editedQuestion = try await api.getMarker(markerId: question.id)
        XCTAssertEqual(editedQuestion.note, questionEdit.note)

        let setupDraft = draft(.setup, price: 50_000)
        setupDraft.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 49_800)))
        setupDraft.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 50_400)))
        setupDraft.trackingEnabled = true
        let setup = try await post(setupDraft)
        let setupEdit = edit(setup)
        let geometry = setupEdit.components
        setupEdit.refreshSetupEntryForPosting(latest: candle)
        setupEdit.openContext(); setupEdit.backToDetails()
        XCTAssertEqual(setupEdit.components, geometry)
        XCTAssertEqual(setupEdit.componentPrice(.levelEntry), 50_000)
        setupEdit.note = "Local saved Setup reasoning edited"
        XCTAssertNil(setupEdit.buildGuidedUpdateRequest().components)
        try await save(setupEdit)
        let reread = try await api.getMarker(markerId: setup.id)
        XCTAssertEqual(reread.components.map(\.payload.levelPrice), setup.components.map(\.payload.levelPrice))

        // Existing readable legacy Setup states are inspected, never changed.
        let existing = try await api.getMarkers(guildId: creds.guild_id, symbolId: creds.symbol_id,
            timeframe: "1h", limit: 100, cursor: nil, startTime: nil, endTime: nil).markers
        var lockedStates = Set<String>()
        for marker in existing where marker.intent == "setup" && marker.trackingEnabled {
            let state = edit(marker)
            if ["ACTIVE", "TP_HIT", "SL_HIT", "EXPIRED"].contains(marker.trackingState ?? "") {
                XCTAssertTrue(state.isGuidedEditLocked)
                XCTAssertFalse(state.workspaceAllows(.indicator))
                XCTAssertNil(state.buildGuidedUpdateRequest().components)
                lockedStates.insert(marker.trackingState!)
            }
        }
        print("LOCAL_QA_READONLY_LOCK_STATES \(lockedStates.sorted())")

        let context = draft(.analysis)
        context.appendComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 49_500, label: "First", colorHex: "#33AA55")))
        context.appendComponent(.levelSupport, payload: .levelSupport(LevelPayload(price: 49_000, label: "Second", colorHex: "#38BDF8")))
        context.beginWorkspaceIndicator(IndicatorCatalogItem(type: .rsi))
        context.workspace.indicatorDraft?.intValues["period"] = "19"
        XCTAssertTrue(context.commitWorkspaceEditor())
        context.beginWorkspaceText(.sourceEditor)
        context.workspace.editorText = "https://example.com/local-qa"
        XCTAssertTrue(context.commitWorkspaceEditor())
        context.appendComponent(.drawingHorizontalLine, payload: .drawingHorizontalLine(HorizontalLinePayload(price: 50_100, label: "Drawing", colorHex: "#38BDF8")))
        // Model a known legacy payload with future keys through the real API.
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(context.buildCreateRequest(symbolId: creds.symbol_id, timeframe: "1w"))) as! [String: Any]
        var components = object["components"] as! [[String: Any]]
        var payload = components[2]["payload"] as! [String: Any]
        payload["future_qa_metadata"] = ["keep": true, "label": "phaseb"]
        components[2]["payload"] = payload
        object["components"] = components
        let legacyRequest = try JSONDecoder().decode(RLCreateMarkerRequest.self, from: JSONSerialization.data(withJSONObject: object))
        let attached = try await post(context, requestOverride: legacyRequest)
        let contextEdit = edit(attached)
        let second = try XCTUnwrap(contextEdit.components.first { $0.componentType == .levelSupport && $0.payload.levelPrice == 49_000 })
        contextEdit.openContext()
        contextEdit.beginWorkspaceLevel(.levelSupport, componentID: second.id)
        XCTAssertEqual(Double(contextEdit.workspace.editorText), 49_000)
        contextEdit.workspace.editorText = "49025"
        XCTAssertTrue(contextEdit.commitWorkspaceEditor())
        try await save(contextEdit)
        let contextSaved = try await api.getMarker(markerId: attached.id)
        XCTAssertEqual(contextSaved.components.map(\.componentType), attached.components.map(\.componentType))
        XCTAssertEqual(contextSaved.components[1].payload.levelPrice, 49_500)
        XCTAssertEqual(contextSaved.components[2].payload.levelPrice, 49_025)
        let initialExtras = MarkerRawPayload.unwrap(attached.components[2].originalRawPayload ?? [:])
        let extras = MarkerRawPayload.unwrap(contextSaved.components[2].originalRawPayload ?? [:])
        XCTAssertNil(initialExtras["future_qa_metadata"], "existing backend normalizes payloads on CREATE")
        XCTAssertNil(extras["future_qa_metadata"])
        print("LOCAL_QA_BACKEND_LIMIT future keys normalized away at create; historical raw-key preservation is client-fixture verified only")
        XCTAssertEqual(contextSaved.components[2].payload.guidedLevelPayload?.colorHex, "#38BDF8")

        for relationship in MarkerLinkRelationship.allCases {
            let response = draft(.analysis)
            response.beginRespondingTo(MarkerLinkContext(parentMarkerId: analysis.id, parentGuildId: creds.guild_id,
                parentSymbolId: creds.symbol_id, parentCandleTimestamp: analysis.candleTimestamp,
                parentAuthorDisplayText: "Local QA", parentTitle: analysis.title, parentIntent: .analysis, relationship: relationship))
            response.note = "Local linked contribution"
            _ = response.upsertTimeframeLink("1w")
            let timeframeOperation = response.beginResponseTimeframeChange()
            XCTAssertNil(response.requestGuidedIntentChange(to: .setup))
            response.upsertComponent(.levelEntry, payload: .levelEntry(LevelPayload(price: 50_000)))
            response.upsertComponent(.levelSl, payload: .levelSl(LevelPayload(price: 49_800)))
            response.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 50_400)))
            response.trackingEnabled = false
            let warning = try XCTUnwrap(response.requestGuidedIntentChange(to: .analysis))
            response.applyGuidedIntentChange(warning)
            XCTAssertEqual(response.responseTimeframeChangeID, timeframeOperation)
            response.finishResponseTimeframeChange(timeframeOperation, succeeded: true)
            let saved = try await post(response, timeframe: "4h")
            XCTAssertEqual(saved.parentMarkerId, analysis.id)
            XCTAssertEqual(saved.linkRelationship, relationship.rawValue)
            XCTAssertEqual(saved.timeframe, "4h")
            XCTAssertTrue(saved.components.contains { $0.componentType == RLComponentType.timeframeLink.rawValue })
        }
        // Real authorization failure and recovery through the production
        // submitter: the draft/geometry and pending text survive the refusal.
        let retry = edit(try await api.getMarker(markerId: analysis.id))
        retry.note = "Local retry preserved"
        let snapshot = retry.components
        api.setAccessToken(nil)
        let failed = await MarkerPlacementSubmitter.submitUpdate(placementState: retry, markerManager: manager)
        guard case .failure = failed.result else { throw HarnessError.submissionFailed }
        XCTAssertEqual(retry.components, snapshot)
        XCTAssertEqual(retry.note, "Local retry preserved")
        api.setAccessToken(token)
        try await save(retry)
        let retried = try await api.getMarker(markerId: analysis.id)
        XCTAssertEqual(retried.note, "Local retry preserved")
        XCTAssertEqual(created.count, 7)
        print("LOCAL_QA_PASS \(run) social/create/read/edit setup/geometry linked/conversion/timeframes retry; API/model integration, not UI end-to-end")
    }
}
#endif
