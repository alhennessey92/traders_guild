import Foundation
import Testing
@testable import traders_guild

/// The realtime handlers driven through the actual websocket seam.
///
/// Written this way after `neutralMerge` was found to have no production caller
/// at all: it was correct, it was tested, and it repaired nothing, because the
/// handlers still replaced the loaded marker wholesale. A test that calls the
/// helper cannot catch that. These publish a real `WSIncomingMessage` and assert
/// on `manager.markers`.
@MainActor
struct MarkerRealtimeHandlerTests {

    /// A fresh guild per test, because the realtime seam is a process-wide
    /// singleton and the channel name is derived from the guild id. With a
    /// shared id every concurrently running test in this suite subscribes to the
    /// same channel and receives every other test's events — which shows up as
    /// a merge that mysteriously refused to apply, not as an obvious clash.
    /// swift-testing builds a new instance per test, so this is per test.
    private let guildId = UUID()
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    private func member(_ n: Int) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: id(900 + n), role: "member", reputation: 0, contributionScore: 0,
            dateJoined: Date(timeIntervalSince1970: 0), accuracyRate: nil, mutedUntil: nil,
            suspendedUntil: nil, userId: id(n), username: "user\(n)", displayName: "User \(n)",
            avatarUrl: nil, isOnline: false, globalReputation: 0, isFriend: false,
            friendshipStatus: nil, isBlocked: false, isBlockedBy: false
        )
    }

    private func marker(
        id markerId: UUID,
        author: RLGuildMemberDTO,
        isCurrentUserMarker: Bool = false,
        canEdit: Bool = false,
        canDelete: Bool = false,
        likeCount: Int = 0,
        isLiked: Bool = false,
        pollOptions: [RLPollOptionDTO]? = nil,
        userPollVote: UUID? = nil,
        title: String = "Marker"
    ) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: markerId, symbolId: symbolId, guildId: guildId, author: author,
            candleTimestamp: timestamp, timeframe: "1h", price: 100,
            intent: "analysis", title: title, note: nil, visibility: "guild",
            confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: timestamp, createdAtFormatted: "now", isVisible: true,
            likeCount: likeCount, isLikedByCurrentUser: isLiked, commentCount: 0, comments: [],
            isCurrentUserMarker: isCurrentUserMarker, canEdit: canEdit, canDelete: canDelete,
            components: [], primaryComponentId: nil,
            pollQuestion: pollOptions == nil ? nil : "Which way?",
            pollOptions: pollOptions, userPollVote: userPollVote, predictionResult: nil
        )
    }

    /// Stand up a manager subscribed to the guild's marker channel with one
    /// marker already loaded, the way the chart has it after a normal load.
    ///
    /// **Callers must keep the returned `ChartDataManager` alive.** The manager
    /// holds it weakly — the chart owns it, not the marker layer — and
    /// `handleMarkerCreated` needs its candles to position a new marker. Bind it
    /// to `_` and the create path silently does nothing, which reads as a
    /// handler that ignored the event.
    private func loadedManager(
        viewer: Int,
        canModerate: Bool,
        loaded: RLChartMarkerDTO
    ) async -> (MarkerManager, ChartDataManager, String) {
        let me = member(viewer)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        manager.linkedMarkersEnabled = true
        manager.viewerCanModerate = canModerate

        let api = RealtimeFakeAPI()
        api.markersResponse = RLMarkersListDTO(
            markers: [loaded], totalCount: 1, hasMore: false, nextCursor: nil
        )
        let data = ChartDataManager()
        data.candles = [
            RLCandleDTO(timestamp: timestamp, open: 1.2, high: 1.25, low: 1.19, close: 1.24, volume: nil)
        ]
        manager.configureRealTime(dataManager: data)
        await manager.loadMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: guildId, timeframe: .h1, candles: data.candles
        )
        return (manager, data, "guild:\(guildId.uuidString.lowercased()):markers")
    }

    private func send(_ type: String, _ payload: [String: Any], channel: String) async throws {
        RealTimeService.shared.messageSubject.send(
            WSIncomingMessage(
                type: type, channel: channel, payload: try anyCodable(payload),
                userId: nil, isTyping: nil, message: nil, channels: nil
            )
        )
        try await Task.sleep(nanoseconds: 40_000_000)
    }

    /// Encode a DTO the way the wire carries it.
    private func wire(_ dto: RLChartMarkerDTO) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Build the payload the way a real socket frame does: by *decoding* JSON,
    /// never by wrapping a `JSONSerialization` dictionary.
    ///
    /// `AnyCodable(someDictionary)` looks equivalent and is not.
    /// `JSONSerialization` yields `NSNumber`, and `AnyCodable.encode` tests
    /// `as? Bool` before `as? Int` — an `NSNumber(0)` satisfies the Bool cast,
    /// so every integer in the payload is re-encoded as `false` and the DTO
    /// then fails to decode. Production is unaffected because it goes through
    /// `AnyCodable.init(from:)`, where `JSONDecoder` refuses to read a number
    /// as a Bool and falls through to Int correctly.
    ///
    /// The symptom was a handler that appeared to silently ignore every event.
    private func anyCodable(_ dict: [String: Any]) throws -> AnyCodable {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(AnyCodable.self, from: data)
    }

    // MARK: - Harness self-check

    /// If this fails, every other test in this file is testing the harness
    /// rather than the handler: a payload that cannot decode makes the handler
    /// return early and leaves the loaded marker untouched, which looks exactly
    /// like a merge that refused to apply.
    @Test
    func theWirePayloadRoundTripsBackIntoAMarker() throws {
        let dto = marker(id: id(1), author: member(2), title: "RoundTrip")
        let message = WSIncomingMessage(
            type: "marker_updated", channel: "c", payload: try anyCodable(try wire(dto)),
            userId: nil, isTyping: nil, message: nil, channels: nil
        )
        let decoded = try #require(
            message.payload(as: RLChartMarkerDTO.self),
            "the realtime decoder must accept this fixture"
        )
        #expect(decoded.id == dto.id)
        #expect(decoded.title == "RoundTrip")
    }

    /// And the manager must actually be subscribed to the channel the tests
    /// publish on, or nothing reaches the handler regardless of the payload.
    @Test
    func theHarnessDeliversOnTheSubscribedChannel() async throws {
        let (manager, data, channel) = await loadedManager(
            viewer: 1, canModerate: false, loaded: marker(id: id(2), author: member(1))
        )
        #expect(manager.markers.count == 1, "the fixture marker must load")
        try await send(
            "marker_updated",
            try wire(marker(id: id(2), author: member(1), title: "Delivered")),
            channel: channel
        )
        #expect(
            manager.markers.first?.marker.title == "Delivered",
            "the update must reach the handler over channel \(channel)"
        )
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }

    // MARK: - marker_updated

    /// The payload arrives with the *acting* member's permissions and neutral
    /// engagement. After the handler runs, the loaded marker must show this
    /// viewer's own like and votes, and this viewer's own permissions.
    @Test
    func updateEventKeepsViewerEngagementAndRefusesForeignPermissions() async throws {
        let theirs = member(2)
        let optionA = id(701)
        let optionB = id(702)

        let loaded = marker(
            id: id(50), author: theirs,
            likeCount: 4, isLiked: true,
            pollOptions: [
                RLPollOptionDTO(id: optionA, text: "Up", voteCount: 3, hasVoted: true),
                RLPollOptionDTO(id: optionB, text: "Down", voteCount: 1, hasVoted: false)
            ],
            userPollVote: optionA
        )
        let (manager, data, channel) = await loadedManager(viewer: 1, canModerate: false, loaded: loaded)
        #expect(manager.markers.first?.isLikedByCurrentUser == true)

        // Built as its author would see it, and — the case that matters — with
        // a foreign `hasVoted` on an option this viewer never chose.
        let broadcast = marker(
            id: id(50), author: theirs,
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            likeCount: 9, isLiked: false,
            pollOptions: [
                RLPollOptionDTO(id: optionA, text: "Up", voteCount: 9, hasVoted: false),
                RLPollOptionDTO(id: optionB, text: "Down", voteCount: 2, hasVoted: true)
            ],
            userPollVote: nil,
            title: "Edited"
        )
        try await send("marker_updated", try wire(broadcast), channel: channel)

        let updated = try #require(manager.markers.first)
        #expect(updated.marker.title == "Edited", "the edit itself still lands")
        #expect(updated.marker.likeCount == 9, "authoritative counts still land")

        // Engagement preserved.
        #expect(updated.isLikedByCurrentUser, "this viewer's like must survive the broadcast")
        #expect(updated.marker.userPollVote == optionA)
        let options = try #require(updated.marker.pollOptions)
        #expect(options.first { $0.id == optionA }?.hasVoted == true, "the viewer's vote survives")
        #expect(
            options.first { $0.id == optionB }?.hasVoted == false,
            "and a foreign hasVoted must not leak in"
        )
        #expect(options.first { $0.id == optionA }?.voteCount == 9, "counts are still the server's")

        // Permissions refused.
        #expect(!updated.marker.isCurrentUserMarker)
        #expect(!updated.marker.canEdit, "no Edit affordance on another member's marker")
        #expect(!updated.marker.canDelete)
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }

    /// A moderator gains Delete and still never gains Edit — through the
    /// handler, not the helper.
    @Test
    func updateEventGivesAModeratorDeleteButNotEdit() async throws {
        let theirs = member(2)
        let loaded = marker(id: id(51), author: theirs)
        let (manager, data, channel) = await loadedManager(viewer: 1, canModerate: true, loaded: loaded)

        try await send(
            "marker_updated",
            try wire(marker(
                id: id(51), author: theirs,
                isCurrentUserMarker: true, canEdit: true, canDelete: true, title: "Edited"
            )),
            channel: channel
        )

        let updated = try #require(manager.markers.first)
        #expect(!updated.marker.isCurrentUserMarker)
        #expect(!updated.marker.canEdit)
        #expect(updated.marker.canDelete)
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }

    // MARK: - marker_created

    /// A created marker has no loaded copy to merge against, and its payload is
    /// the one that historically handed every recipient the creator's Edit
    /// affordance. Permissions are derived rather than adopted.
    @Test
    func createEventDerivesPermissionsForTheReceivingViewer() async throws {
        let theirs = member(2)
        let (manager, data, channel) = await loadedManager(
            viewer: 1, canModerate: false, loaded: marker(id: id(60), author: member(1))
        )

        try await send(
            "marker_created",
            try wire(marker(
                id: id(61), author: theirs,
                isCurrentUserMarker: true, canEdit: true, canDelete: true, title: "Theirs"
            )),
            channel: channel
        )

        let created = try #require(manager.markers.first { $0.id == id(61) })
        #expect(!created.marker.isCurrentUserMarker)
        #expect(!created.marker.canEdit)
        #expect(!created.marker.canDelete)
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }

    /// And the viewer's own creation keeps its affordances.
    @Test
    func createEventKeepsPermissionsOnTheViewersOwnMarker() async throws {
        let mine = member(1)
        let (manager, data, channel) = await loadedManager(
            viewer: 1, canModerate: false, loaded: marker(id: id(70), author: mine)
        )

        try await send(
            "marker_created",
            try wire(marker(
                id: id(71), author: mine,
                isCurrentUserMarker: false, canEdit: false, canDelete: false, title: "Mine"
            )),
            channel: channel
        )

        let created = try #require(manager.markers.first { $0.id == id(71) })
        #expect(created.marker.isCurrentUserMarker)
        #expect(created.marker.canEdit)
        #expect(created.marker.canDelete)
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }

    // MARK: - tracking_state_changed

    /// A tracking snapshot carries a whole marker, so it can strip permissions
    /// and engagement exactly as an update can.
    @Test
    func trackingSnapshotIsMergedRatherThanAdopted() async throws {
        let theirs = member(2)
        let loaded = marker(id: id(80), author: theirs, likeCount: 2, isLiked: true)
        let (manager, data, channel) = await loadedManager(viewer: 1, canModerate: false, loaded: loaded)

        var snapshot = try wire(marker(
            id: id(80), author: theirs,
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            likeCount: 6, isLiked: false
        ))
        snapshot["tracking_state"] = RLTrackingState.active.rawValue

        try await send(
            "tracking_state_changed",
            [
                "marker_id": id(80).uuidString,
                "old_state": RLTrackingState.armed.rawValue,
                "new_state": RLTrackingState.active.rawValue,
                "guild_id": guildId.uuidString,
                "symbol_id": symbolId.uuidString,
                "marker": snapshot,
            ],
            channel: channel
        )

        let updated = try #require(manager.markers.first)
        #expect(updated.isLikedByCurrentUser, "the viewer's like survives a tracking snapshot too")
        #expect(!updated.marker.canEdit)
        #expect(!updated.marker.canDelete)
        #expect(updated.marker.likeCount == 6)
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }

    /// Counts and thesis invalidation must happen before the loaded-marker
    /// guard. A tracking snapshot for a marker this chart has not loaded still
    /// carries an absolute parent count and still stales a cached thesis;
    /// handling those inside the guard dropped both precisely when the viewer
    /// could not see the marker for themselves.
    @Test
    func trackingSnapshotForAnUnloadedMarkerStillReconcilesAndInvalidates() async throws {
        let (manager, data, channel) = await loadedManager(
            viewer: 1, canModerate: false, loaded: marker(id: id(90), author: member(1))
        )

        let store = MarkerThreadStore()
        store.activate(accountId: id(1), guildId: guildId)
        store.ingest(
            page: RLMarkerThreadResponseDTO(
                requestedMarkerId: id(95),
                rootMarkerId: id(95), rootKey: "root", rootResolved: true,
                windowRootKey: "root",
                nodes: [RLMarkerLinkPreviewDTO(
                    nodeKey: "root", markerId: id(95), symbolId: symbolId, directResponseCount: 1
                )],
                ancestorCursor: nil, branches: [], loadedCount: 1
            ),
            requestedMarkerId: id(95),
            expectedGeneration: store.generation
        )
        manager.threadStore = store
        #expect(store.window(forMarkerId: id(95)) != nil)

        // A marker on another timeframe that this chart has never loaded.
        var snapshot = try wire(marker(id: id(96), author: member(2)))
        snapshot["timeframe"] = "1d"
        snapshot["parent_marker_id"] = id(95).uuidString
        snapshot["link_relationship"] = "supports"
        snapshot["parent_direct_response_count"] = 7
        snapshot["parent_responses_revision"] = "2026-09-09T10:00:00.500000Z"

        try await send(
            "tracking_state_changed",
            [
                "marker_id": id(96).uuidString,
                "old_state": RLTrackingState.armed.rawValue,
                "new_state": RLTrackingState.active.rawValue,
                "guild_id": guildId.uuidString,
                "symbol_id": symbolId.uuidString,
                "marker": snapshot,
            ],
            channel: channel
        )

        #expect(
            manager.responseCounts.count(for: id(95)) == 7,
            "the parent's absolute count applies even though the child is not loaded here"
        )
        #expect(
            store.window(forMarkerId: id(95)) == nil,
            "and the thesis it changed is invalidated rather than left stale"
        )
        #expect(data.candles.count == 1, "the chart data must outlive the manager's weak reference")
    }
}

private final class RealtimeFakeAPI: MarkerAPIClient, @unchecked Sendable {
    var markersResponse = RLMarkersListDTO(markers: [], totalCount: 0, hasMore: false, nextCursor: nil)

    func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO { markersResponse }

    func getMarkerThread(markerId: UUID, cursor: String?) async throws -> RLMarkerThreadResponseDTO {
        throw APIError.networkError("unused")
    }
    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.networkError("unused")
    }
    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO {
        throw APIError.networkError("unused")
    }
    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLMarkerDeleteResponseDTO {
        throw APIError.networkError("unused")
    }
    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO {
        throw APIError.networkError("unused")
    }
    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO {
        throw APIError.networkError("unused")
    }
    func addMarkerComment(
        guildId: UUID, markerId: UUID, content: String, attachmentUrl: String?,
        attachmentType: String?, attachmentName: String?, replyToMessageId: UUID?
    ) async throws -> RLMarkerCommentDTO { throw APIError.networkError("unused") }
    func toggleMarkerCommentReaction(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMarkerCommentDTO { throw APIError.networkError("unused") }
    func getMarkerCommentReactionReactors(
        guildId: UUID, markerId: UUID, commentId: UUID, emoji: String
    ) async throws -> RLMessageReactionReactorsDTO { throw APIError.networkError("unused") }
    func deleteMarkerComment(guildId: UUID, markerId: UUID, commentId: UUID) async throws -> RLDetailResponseDTO {
        throw APIError.networkError("unused")
    }
}
