import Foundation
import Testing
@testable import traders_guild

/// `MarkerManager.loadMarker(id:candles:)` — the by-id fallback navigation uses
/// when the window fetch did not contain the marker it travelled to.
///
/// The window fetch is bounded by the candles the chart loaded. A marker on
/// the live candle, or on a candle the persisted series had not reached, is
/// outside that window and was reported as "Marker unavailable" even though
/// the chart had, by then, the candle to put it on.
@MainActor
struct MarkerLoadByIdTests {

    private let guildId = UUID()
    private let symbolId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let hour: TimeInterval = 3600

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
        at candleTimestamp: Date,
        timeframe: String = "1h",
        symbolId: UUID? = nil,
        visibility: String = "guild",
        author: RLGuildMemberDTO? = nil
    ) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: markerId, symbolId: symbolId ?? self.symbolId, guildId: guildId,
            author: author ?? member(2),
            candleTimestamp: candleTimestamp, timeframe: timeframe, price: 100,
            intent: "alert", title: "Marker", note: nil, visibility: visibility,
            confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: candleTimestamp, createdAtFormatted: "now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: false, canEdit: false, canDelete: false,
            components: [], primaryComponentId: nil,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil
        )
    }

    private func candles(_ count: Int, from start: Date) -> [RLCandleDTO] {
        (0..<count).map { i in
            RLCandleDTO(
                timestamp: start.addingTimeInterval(Double(i) * hour),
                open: 1.2, high: 1.25, low: 1.19, close: 1.24, volume: nil
            )
        }
    }

    /// A manager that has done its window fetch against `persisted` candles
    /// (an empty window — the marker under test is deliberately outside it).
    private func loadedManager(
        persisted: [RLCandleDTO],
        api: LoadByIdFakeAPI
    ) async -> (MarkerManager, ChartDataManager) {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        let data = ChartDataManager()
        data.candles = persisted
        manager.configureRealTime(dataManager: data)
        await manager.loadMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: guildId, timeframe: .h1, candles: persisted
        )
        return (manager, data)
    }

    @Test
    func loadsAMarkerTheWindowFetchMissedOntoTheLiveCandle() async throws {
        let persisted = candles(4, from: t0)
        let liveCandleTime = t0.addingTimeInterval(4 * hour)
        let api = LoadByIdFakeAPI()
        let target = marker(id: id(10), at: liveCandleTime)
        api.markersById[target.id] = target

        let (manager, data) = await loadedManager(persisted: persisted, api: api)
        #expect(manager.markers.isEmpty, "the window fetch did not contain it")

        // The live candle arrives after the window fetch, as it does on the chart.
        data.candles = persisted + [RLCandleDTO(
            timestamp: liveCandleTime, open: 1.2, high: 1.25, low: 1.19, close: 1.24, volume: nil
        )]

        let loaded = try #require(await manager.loadMarker(id: target.id, candles: data.candles))
        #expect(loaded.id == target.id)
        #expect(loaded.candleIndex == 4, "placed on the live candle, not the nearest persisted one")
        #expect(loaded.hasStableLayout)
        #expect(manager.markers.map(\.id) == [target.id])
        #expect(api.getMarkerCalls == [target.id])
    }

    @Test
    func returnsTheLoadedCopyWithoutAnotherFetch() async throws {
        let persisted = candles(4, from: t0)
        let api = LoadByIdFakeAPI()
        let loadedDTO = marker(id: id(11), at: t0.addingTimeInterval(hour))
        api.windowMarkers = [loadedDTO]

        let (manager, data) = await loadedManager(persisted: persisted, api: api)
        #expect(manager.markers.count == 1)

        let again = try #require(await manager.loadMarker(id: loadedDTO.id, candles: data.candles))
        #expect(again.id == loadedDTO.id)
        #expect(manager.markers.count == 1, "no duplicate")
        #expect(api.getMarkerCalls.isEmpty, "already loaded — nothing to fetch")
    }

    @Test
    func refusesAMarkerFromAnotherTimeframeOrSymbol() async throws {
        let persisted = candles(4, from: t0)
        let api = LoadByIdFakeAPI()
        let otherTimeframe = marker(id: id(12), at: t0.addingTimeInterval(hour), timeframe: "4h")
        let otherSymbol = marker(id: id(13), at: t0.addingTimeInterval(hour), symbolId: UUID())
        api.markersById[otherTimeframe.id] = otherTimeframe
        api.markersById[otherSymbol.id] = otherSymbol

        let (manager, data) = await loadedManager(persisted: persisted, api: api)

        #expect(await manager.loadMarker(id: otherTimeframe.id, candles: data.candles) == nil)
        #expect(await manager.loadMarker(id: otherSymbol.id, candles: data.candles) == nil)
        #expect(manager.markers.isEmpty, "nothing from another chart is inserted here")
    }

    @Test
    func doesNotConjureACandleTheChartDoesNotHave() async throws {
        // The persisted series stops at t0+3h; the marker sits a day later on a
        // candle nothing ever delivered. There is nothing to put it on.
        let persisted = candles(4, from: t0)
        let api = LoadByIdFakeAPI()
        let farAway = marker(id: id(14), at: t0.addingTimeInterval(24 * hour))
        api.markersById[farAway.id] = farAway

        let (manager, data) = await loadedManager(persisted: persisted, api: api)

        #expect(await manager.loadMarker(id: farAway.id, candles: data.candles) == nil)
        #expect(manager.markers.isEmpty)
        #expect(api.getMarkerCalls == [farAway.id], "it did ask; the answer just had no candle")
    }

    @Test
    func aPrivateMarkerOfSomeoneElseIsNotShown() async throws {
        let persisted = candles(4, from: t0)
        let api = LoadByIdFakeAPI()
        let theirs = marker(id: id(15), at: t0.addingTimeInterval(hour), visibility: "private")
        api.markersById[theirs.id] = theirs

        let (manager, data) = await loadedManager(persisted: persisted, api: api)

        #expect(await manager.loadMarker(id: theirs.id, candles: data.candles) == nil)
        #expect(manager.markers.isEmpty)
    }

    @Test
    func aFailedFetchLeavesMarkersUntouched() async throws {
        let persisted = candles(4, from: t0)
        let api = LoadByIdFakeAPI()
        // Nothing registered under this id: the fake throws, as a 404 would.
        let (manager, data) = await loadedManager(persisted: persisted, api: api)

        #expect(await manager.loadMarker(id: id(16), candles: data.candles) == nil)
        #expect(manager.markers.isEmpty)
    }
}

private final class LoadByIdFakeAPI: MarkerAPIClient, @unchecked Sendable {
    var windowMarkers: [RLChartMarkerDTO] = []
    var markersById: [UUID: RLChartMarkerDTO] = [:]
    private(set) var getMarkerCalls: [UUID] = []

    func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO {
        RLMarkersListDTO(markers: windowMarkers, totalCount: windowMarkers.count, hasMore: false, nextCursor: nil)
    }
    func getMarker(markerId: UUID) async throws -> RLChartMarkerDTO {
        getMarkerCalls.append(markerId)
        guard let dto = markersById[markerId] else {
            throw APIError.serverError(404, "Marker not found")
        }
        return dto
    }
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
