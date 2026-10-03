import Foundation
import Testing
@testable import traders_guild

/// A guided edit sends back everything it did not change, exactly as the
/// server sent it — including keys this build does not model inside known
/// component types — and changes only what the author changed.
///
/// Markers are decoded from JSON with the API's decoder settings, so the raw
/// payload is what the app really holds.
@MainActor
struct MarkerGuidedEditPayloadPreservationTests {

    // MARK: Decoding as the API does

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: raw) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "bad date \(raw)")
        }
        return decoder
    }

    private static let markerId = "11111111-1111-1111-1111-111111111111"

    private func markerJSON(intent: String, components: String, tracking: Bool = false, state: String? = nil) -> String {
        """
        {
          "id": "\(Self.markerId)",
          "symbol_id": "22222222-2222-2222-2222-222222222222",
          "guild_id": "33333333-3333-3333-3333-333333333333",
          "author": {
            "membership_id": "55555555-5555-5555-5555-555555555555", "role": "member",
            "reputation": 0, "contribution_score": 0, "date_joined": "2026-01-01T00:00:00Z",
            "user_id": "44444444-4444-4444-4444-444444444444", "username": "alex", "display_name": "Alex",
            "is_online": false, "global_reputation": 0, "is_friend": false, "is_blocked": false, "is_blocked_by": false
          },
          "candle_timestamp": "2026-09-01T12:00:00Z", "timeframe": "1h", "price": 64000.5,
          "intent": "\(intent)", "title": "Higher lows", "note": "Range low is holding.",
          "visibility": "guild", "tracking_enabled": \(tracking), "tracking_state": \(state.map { "\"\($0)\"" } ?? "null"),
          "created_at": "2026-09-01T12:00:00Z", "created_at_formatted": "just now", "is_visible": true,
          "like_count": 0, "is_liked_by_current_user": false, "comment_count": 0, "comments": [],
          "is_current_user_marker": true, "can_edit": true, "can_delete": true,
          "components": [\(components)]
        }
        """
    }

    private func component(_ n: Int, _ type: String, _ ordering: Int, _ payload: String) -> String {
        """
        {"id": "00000000-0000-0000-0000-0000000000\(String(format: "%02d", n))", "component_type": "\(type)",
         "ordering": \(ordering), "payload": \(payload)}
        """
    }

    /// Anchor, two supports (extra and nested keys), an unreadable type
    /// between them, and a timeframe link with an extra key.
    private var analysisComponents: String {
        [
            component(1, "anchor", 0, ##"{"time": "2026-09-01T12:00:00.123456Z", "price": 64000.5, "server_seq": 7}"##),
            component(2, "level.support", 1, ##"{"price": 63780, "label": "Range low", "color_hex": "#33AA55", "style": {"dash": [4, 2], "glow": true}, "source": "import-v2"}"##),
            component(3, "future.widget", 2, ##"{"shape": "star", "size": 3}"##),
            component(4, "level.support", 3, ##"{"price": 63500, "label": "Deep low", "x_note": "keep"}"##),
            component(5, "timeframe.link", 4, ##"{"timeframe": "4h", "extra": 1}"##),
        ].joined(separator: ",")
    }

    /// A payload decoded the way the app decodes one (`AnyCodable`), so
    /// numbers and booleans compare as the app holds them.
    private func savedRaw(_ json: String) -> [String: Any] {
        MarkerRawPayload.unwrap(try! JSONDecoder().decode([String: AnyCodable].self, from: Data(json.utf8)))
    }

    private struct Edit {
        let state: MarkerPlacementState
        let manager: MarkerManager
        let transport: MarkerFixtureTransport
        let marker: RLChartMarkerDTO
    }

    private func edit(_ json: String, mode: MarkerFixtureTransport.Mode = .succeed) throws -> Edit {
        let marker = try decoder().decode(RLChartMarkerDTO.self, from: Data(json.utf8))
        let author = marker.author
        let transport = MarkerFixtureTransport(mode: mode, author: author)
        transport.storedMarkers[marker.id] = marker
        let manager = MarkerManager(userId: author.userId, guildId: marker.guildId, currentUserMember: author)
        manager.configure(api: transport, symbolId: marker.symbolId, timeframe: .h1)
        let ui = ChartMarkerUI(marker: marker, candleIndex: 0)
        manager.markers = [ui]
        let state = MarkerPlacementState()
        state.beginEditingMarker(ui)
        state.allowTextOnlyAnalysisEdit()
        state.prepareGuidedEdit(of: ui)
        return Edit(state: state, manager: manager, transport: transport, marker: marker)
    }

    private func sent(_ requests: [RLMarkerComponentRequest]) -> [(type: String, payload: [String: Any])] {
        requests.map { ($0.componentType, MarkerRawPayload.unwrap($0.payload)) }
    }

    private func supportDraftIndex(_ state: MarkerPlacementState, price: Double) -> Int? {
        state.components.firstIndex {
            $0.componentType == .levelSupport && abs(($0.payload.levelPrice ?? 0) - price) < 0.001
        }
    }

    // MARK: Retention

    @Test
    func theDecodedComponentKeepsItsRawPayloadThroughTheAppsReencoding() throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        let support = e.marker.components.first { $0.componentType == "level.support" }
        let raw = MarkerRawPayload.unwrap(support?.originalRawPayload ?? [:])
        #expect(raw["source"] as? String == "import-v2")
        #expect((raw["style"] as? [String: Any])?["glow"] as? Bool == true)
        #expect(support?.payload.rawPayload["source"] == nil, "the typed payload cannot carry it")

        // An in-app copy (as a like or optimistic patch makes) keeps it.
        let copy = e.marker.updating(likeCount: 5)
        let copied = copy.components.first { $0.componentType == "level.support" }
        #expect(MarkerRawPayload.same(MarkerRawPayload.unwrap(copied?.originalRawPayload ?? [:]), raw))
    }

    // MARK: Untouched components

    @Test
    func anUnrelatedContextEditSendsEverySavedComponentExactlyAndInOrder() throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        e.state.upsertComponent(.levelResistance, payload: .levelResistance(LevelPayload(price: 64_400, label: "Range high")))
        let request = e.state.buildGuidedUpdateRequest()
        let components = sent(request.components ?? [])

        #expect(components.map(\.type) == ["anchor", "level.support", "future.widget", "level.support", "timeframe.link", "level.resistance"],
                "saved order, the unreadable type where it was, the new one after")
        let saved = [
            ##"{"time": "2026-09-01T12:00:00.123456Z", "price": 64000.5, "server_seq": 7}"##,
            ##"{"price": 63780, "label": "Range low", "color_hex": "#33AA55", "style": {"dash": [4, 2], "glow": true}, "source": "import-v2"}"##,
            ##"{"shape": "star", "size": 3}"##,
            ##"{"price": 63500, "label": "Deep low", "x_note": "keep"}"##,
            ##"{"timeframe": "4h", "extra": 1}"##,
        ]
        for (index, json) in saved.enumerated() {
            #expect(MarkerRawPayload.same(components[index].payload, savedRaw(json)),
                    "component \(index) goes back exactly as saved: \(components[index].payload)")
        }
        #expect(components[5].payload["price"] as? Double == 64_400 || components[5].payload["price"] as? Int == 64_400)
    }

    // MARK: Edited components

    @Test
    func anEditedFieldIsMergedIntoTheSavedPayloadAndNothingElseChanges() throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        let index = try #require(supportDraftIndex(e.state, price: 63_780))
        guard case .levelSupport(let hydrated) = e.state.components[index].payload else { Issue.record("not a support"); return }
        e.state.components[index].payload = .levelSupport(LevelPayload(
            price: 63_800, label: hydrated.label, colorHex: hydrated.colorHex,
            lineStyle: hydrated.lineStyle, lineWidth: hydrated.lineWidth
        ))
        let components = sent(e.state.buildGuidedUpdateRequest().components ?? [])
        #expect(components.map(\.type) == ["anchor", "level.support", "future.widget", "level.support", "timeframe.link"])

        let edited = components[1].payload
        #expect(MarkerRawPayload.same(edited["price"], 63_800))
        #expect(edited["label"] as? String == "Range low")
        #expect(edited["color_hex"] as? String == "#33AA55")
        #expect(edited["source"] as? String == "import-v2", "unmodelled key kept")
        #expect(MarkerRawPayload.same(edited["style"], ["dash": [4, 2], "glow": true]), "nested unmodelled object kept")
        #expect(MarkerRawPayload.same(components[3].payload, savedRaw(##"{"price": 63500, "label": "Deep low", "x_note": "keep"}"##)),
                "the other support of the same type is untouched")
        #expect(MarkerRawPayload.same(components[0].payload, savedRaw(##"{"time": "2026-09-01T12:00:00.123456Z", "price": 64000.5, "server_seq": 7}"##)),
                "the anchor is exact")
    }

    @Test
    func aClearedModelledFieldIsRemovedAndUnmodelledKeysStay() throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        let index = try #require(supportDraftIndex(e.state, price: 63_500))
        e.state.components[index].payload = .levelSupport(LevelPayload(price: 63_500, label: nil))
        let components = sent(e.state.buildGuidedUpdateRequest().components ?? [])
        let edited = components[3].payload
        #expect(edited["label"] == nil, "the author cleared it")
        #expect(edited["x_note"] as? String == "keep")
        #expect(MarkerRawPayload.same(edited["price"], 63_500))
    }

    @Test
    func aRemovedComponentStaysRemoved() throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        let index = try #require(supportDraftIndex(e.state, price: 63_500))
        e.state.removeComponent(id: e.state.components[index].id)
        let components = sent(e.state.buildGuidedUpdateRequest().components ?? [])
        #expect(components.map(\.type) == ["anchor", "level.support", "future.widget", "timeframe.link"])
        #expect(!components.contains { $0.payload["x_note"] != nil }, "not resurrected from the saved copy")
    }

    // MARK: Setup

    @Test
    func aSetupsAnchorAndEntryAreExactWhenATargetMoves() throws {
        let setup = [
            component(1, "anchor", 0, ##"{"time": "2026-09-01T12:00:00Z", "price": 63500.25, "server_seq": 1}"##),
            component(2, "level.entry", 1, ##"{"price": 63920.5, "label": "Entry", "filled_at": "2026-09-01T12:05:00Z"}"##),
            component(3, "level.tp", 2, ##"{"price": 64400, "label": "TP", "partial": [0.5, 0.5]}"##),
            component(4, "level.sl", 3, ##"{"price": 63700, "label": "SL"}"##),
        ].joined(separator: ",")
        let e = try edit(markerJSON(intent: "setup", components: setup, tracking: true, state: "ARMED"))
        #expect(!e.state.isGuidedEditLocked)
        e.state.upsertComponent(.levelTp, payload: .levelTp(LevelPayload(price: 64_600, label: "TP")))
        let components = sent(e.state.buildGuidedUpdateRequest().components ?? [])
        #expect(components.map(\.type) == ["anchor", "level.entry", "level.tp", "level.sl"])
        #expect(MarkerRawPayload.same(components[0].payload, savedRaw(##"{"time": "2026-09-01T12:00:00Z", "price": 63500.25, "server_seq": 1}"##)))
        #expect(MarkerRawPayload.same(components[1].payload, savedRaw(##"{"price": 63920.5, "label": "Entry", "filled_at": "2026-09-01T12:05:00Z"}"##)),
                "Entry exactly as saved")
        #expect(MarkerRawPayload.same(components[2].payload["price"], 64_600))
        #expect(MarkerRawPayload.same(components[2].payload["partial"], [0.5, 0.5]), "the target's unmodelled key kept")
    }

    /// Typing a new target in the guided field changes the price only: a
    /// saved label ("Target 1") is not replaced with the field's default.
    @Test
    func typingATargetChangesOnlyItsPrice() throws {
        let setup = [
            component(1, "anchor", 0, ##"{"time": "2026-09-01T12:00:00Z", "price": 63920.5}"##),
            component(2, "level.entry", 1, ##"{"price": 63920.5, "label": "Entry"}"##),
            component(3, "level.tp", 2, ##"{"price": 64400, "label": "Target 1", "color_hex": "#2266FF", "partial": [0.5, 0.5]}"##),
            component(4, "level.sl", 3, ##"{"price": 63700, "label": "SL"}"##),
        ].joined(separator: ",")
        let e = try edit(markerJSON(intent: "setup", components: setup, tracking: true, state: "ARMED"))
        e.state.guidedLevelPriceBinding(for: .levelTp).wrappedValue = 64_650
        let tp = sent(e.state.buildGuidedUpdateRequest().components ?? []).first { $0.type == "level.tp" }?.payload ?? [:]
        #expect(MarkerRawPayload.same(tp["price"], 64_650))
        #expect(tp["label"] as? String == "Target 1")
        #expect(tp["color_hex"] as? String == "#2266FF")
        #expect(MarkerRawPayload.same(tp["partial"], [0.5, 0.5]))
        #expect(e.state.guidedEditChangeLines == ["Take Profit 64,400.00 → 64,650.00"])

        // The shared binding the legacy editor uses still writes its default label.
        e.state.levelPriceBinding(for: .levelSl).wrappedValue = 63_650
        #expect(e.state.components.first { $0.componentType == .levelSl }?.payload.guidedLevelPayload?.label == "SL")
    }

    // MARK: Unverifiable pairing fails closed

    /// Open an edit whose hydrated drafts were disturbed before pairing, so
    /// the saved components cannot be matched one for one.
    private func mismatchedEdit(_ disturb: (MarkerPlacementState) -> Void) throws -> MarkerPlacementState {
        let marker = try decoder().decode(RLChartMarkerDTO.self,
                                          from: Data(markerJSON(intent: "analysis", components: analysisComponents).utf8))
        let ui = ChartMarkerUI(marker: marker, candleIndex: 0)
        let state = MarkerPlacementState()
        state.beginEditingMarker(ui)
        state.allowTextOnlyAnalysisEdit()
        disturb(state)
        state.prepareGuidedEdit(of: ui)
        return state
    }

    @Test
    func fewerDraftsThanSavedComponentsNeverIndexesAndStillSavesText() throws {
        // More saved components than drafts: a negative offset.
        let state = try mismatchedEdit { state in
            for draft in state.components.filter({ $0.componentType == .levelSupport }) {
                state.removeComponent(id: draft.id)
            }
        }
        #expect(state.guidedEditOriginal?.componentsMatched == false)
        state.title = "Higher lows holding"
        #expect(state.canContinueToReview, "a text-only edit is safe")
        let request = state.buildGuidedUpdateRequest()
        #expect(request.title == "Higher lows holding")
        #expect(request.components == nil, "nothing that could lose saved data is sent")
    }

    @Test
    func anUnverifiableComponentChangeIsRefusedWithTheDraftKept() throws {
        let state = try mismatchedEdit { state in
            state.components.append(MarkerComponentDraft(componentType: .levelResistance,
                                                         payload: .levelResistance(LevelPayload(price: 1, label: nil))))
            state.components.append(MarkerComponentDraft(componentType: .levelResistance,
                                                         payload: .levelResistance(LevelPayload(price: 2, label: nil))))
        }
        #expect(state.guidedEditOriginal?.componentsMatched == false)
        state.upsertComponent(.timeframeLink, payload: .timeframeLink(TimeframeLinkPayload(timeframe: "1d", note: nil)))
        #expect(state.guidedEditComponentChangeRefused)
        #expect(!state.canContinueToReview)
        #expect(!state.continueToReview())
        #expect(state.guidedNextStepPrompt == MarkerPlacementState.guidedEditComponentChangeRefusedMessage)
        #expect(state.buildGuidedUpdateRequest().components == nil)
        #expect(state.components.contains { $0.componentType == .timeframeLink }, "the draft is kept")
    }

    // MARK: Legacy output

    @Test
    func theLegacyRequestOutputIsUnchanged() throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        let legacy = sent(e.state.buildUpdateRequest().components ?? [])
        #expect(!legacy.contains { $0.type == "future.widget" }, "the legacy editor still drops what it cannot read")
        #expect(!legacy.contains { $0.payload["source"] != nil }, "and still sends typed payloads only")
    }

    // MARK: Clearing through the real MarkerManager

    @Test
    func aClearedTitleShowsClearedAtOnceAndAfterTheServerAnswers() async throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents))
        e.transport.holdsUpdates = true
        e.state.title = ""
        #expect(e.state.continueToReview())

        let saving = Task { await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager) }
        for _ in 0..<200 where e.transport.heldUpdateCount == 0 { await Task.yield() }
        #expect(e.transport.heldUpdateCount == 1)
        #expect(e.manager.markers.first?.title == nil, "optimistic: the title is cleared at once")
        #expect(e.manager.markers.first?.note == "Range low is holding.", "the note, not sent, is untouched")
        #expect(e.manager.markers.first?.components.contains { $0.componentType == "future.widget" } == true)

        e.transport.releaseHeldUpdates()
        let outcome = await saving.value
        guard case .success = outcome.result else { Issue.record("save failed"); return }
        #expect(e.manager.markers.first?.title == nil, "reconciled: still cleared")
        #expect(e.manager.markers.first?.note == "Range low is holding.")
    }

    @Test
    func aFailedClearRestoresTheTitle() async throws {
        let e = try edit(markerJSON(intent: "analysis", components: analysisComponents), mode: .failAlways(detail: "busy"))
        e.state.title = ""
        #expect(e.state.continueToReview())
        let outcome = await MarkerPlacementSubmitter.submitUpdate(placementState: e.state, markerManager: e.manager)
        guard case .failure = outcome.result else { Issue.record("expected failure"); return }
        #expect(e.manager.markers.first?.title == "Higher lows", "rolled back")
        #expect(e.state.title.isEmpty, "the author's change is kept for Retry")
    }
}
