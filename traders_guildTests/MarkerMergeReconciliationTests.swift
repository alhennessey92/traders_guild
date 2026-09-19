import Foundation
import Testing
@testable import traders_guild

/// `MarkerManager.mergeMarkersFromAPI` — the periodic resync and every
/// history prepend go through it. It was a union by id, so a marker the
/// server had stopped returning (deleted on another device, or made private)
/// survived every resync for the life of the chart. Inside a window the fetch
/// covered completely, a loaded marker the server did not send is gone.
@MainActor
struct MarkerMergeReconciliationTests {

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

    private func candles(_ count: Int) -> [RLCandleDTO] {
        (0..<count).map { i in
            RLCandleDTO(timestamp: t0.addingTimeInterval(Double(i) * hour), open: 1, high: 2, low: 0.5, close: 1.5, volume: nil)
        }
    }

    private func marker(_ n: Int, candle: Int, parent: Int? = nil) -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: id(n), symbolId: symbolId, guildId: guildId, author: member(1),
            candleTimestamp: t0.addingTimeInterval(Double(candle) * hour), timeframe: "1h", price: 1,
            intent: "analysis", title: "M\(n)", note: nil, visibility: "guild",
            confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: t0.addingTimeInterval(Double(n)), createdAtFormatted: "now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: [], primaryComponentId: nil,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil,
            parentMarkerId: parent.map(id), linkRelationship: parent == nil ? nil : "supports",
            parentPreview: parent.map { p in
                RLMarkerLinkPreviewDTO(
                    nodeKey: "p\(p)", markerId: id(p), guildId: guildId, symbolId: symbolId,
                    ticker: "BTC/USD", timeframe: "1h", candleTimestamp: t0, price: 1
                )
            }
        )
    }

    /// Loaded with markers on candles 1, 3 and 7 (the last a response to 3).
    private func loadedManager(api: MergeFakeAPI) async -> MarkerManager {
        let me = member(1)
        let manager = MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
        api.pages = [[marker(1, candle: 1), marker(3, candle: 3), marker(7, candle: 7, parent: 3)]]
        await manager.loadMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: guildId, timeframe: .h1, candles: candles(10)
        )
        #expect(manager.markers.count == 3)
        return manager
    }

    private func merge(_ manager: MarkerManager, api: MergeFakeAPI, from start: Int, to end: Int) async {
        await manager.mergeMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: guildId, timeframe: .h1, candles: candles(10),
            startTime: t0.addingTimeInterval(Double(start) * hour),
            endTime: t0.addingTimeInterval(Double(end) * hour)
        )
    }

    @Test
    func aLoadedMarkerTheServerNoLongerReturnsInsideTheWindowIsDropped() async {
        let api = MergeFakeAPI()
        let manager = await loadedManager(api: api)
        manager.selectedMarker = manager.markers.first { $0.id == id(3) }

        // The resync window covers candles 0…9; the server now returns 1 and 7 only.
        api.pages = [[marker(1, candle: 1), marker(7, candle: 7, parent: 3)]]
        await merge(manager, api: api, from: 0, to: 9)

        #expect(Set(manager.markers.map(\.id)) == [id(1), id(7)])
        #expect(manager.selectedMarker == nil, "a dropped marker cannot stay selected")
        #expect(manager.markers.first { $0.id == id(7) }?.hasUnavailableParent == true,
                "the response learns its parent is gone, as a delete event would tell it")
    }

    @Test
    func aLoadedMarkerOutsideTheWindowIsKept() async {
        let api = MergeFakeAPI()
        let manager = await loadedManager(api: api)

        // A history prepend covering candles 0…2 only. Marker 3 and 7 are
        // outside it; nothing is known about them from this page.
        api.pages = [[marker(1, candle: 1)]]
        await merge(manager, api: api, from: 0, to: 2)

        #expect(Set(manager.markers.map(\.id)) == [id(1), id(3), id(7)])
    }

    @Test
    func aTruncatedFetchDropsNothing() async {
        let api = MergeFakeAPI()
        let manager = await loadedManager(api: api)

        // Ten full pages and still more: the fetch is cut off by the page cap
        // and is not a complete picture of the window.
        api.pages = Array(repeating: [marker(1, candle: 1)], count: 12)
        api.alwaysHasMore = true
        await merge(manager, api: api, from: 0, to: 9)

        #expect(Set(manager.markers.map(\.id)) == [id(1), id(3), id(7)])
    }

    @Test
    func aMergeWithoutAWindowDropsNothing() async {
        let api = MergeFakeAPI()
        let manager = await loadedManager(api: api)
        api.pages = [[marker(1, candle: 1)]]
        await manager.mergeMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: guildId, timeframe: .h1, candles: candles(10),
            startTime: nil, endTime: nil
        )
        #expect(Set(manager.markers.map(\.id)) == [id(1), id(3), id(7)])
    }
}

private final class MergeFakeAPI: MarkerAPIClient, @unchecked Sendable {
    /// Served in order, one per `getMarkers` call; the last page repeats.
    var pages: [[RLChartMarkerDTO]] = []
    var alwaysHasMore = false
    private var served = 0

    func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO {
        let page = pages.isEmpty ? [] : pages[min(served, pages.count - 1)]
        served += 1
        let hasMore = alwaysHasMore || served < pages.count
        return RLMarkersListDTO(markers: page, totalCount: page.count, hasMore: hasMore, nextCursor: hasMore ? "c\(served)" : nil)
    }
    func getMarker(markerId: UUID) async throws -> RLChartMarkerDTO { throw APIError.networkError("unused") }
    func getMarkerThread(markerId: UUID, cursor: String?) async throws -> RLMarkerThreadResponseDTO { throw APIError.networkError("unused") }
    func createMarkerV2(guildId: UUID, request body: RLCreateMarkerRequest) async throws -> RLChartMarkerDTO { throw APIError.networkError("unused") }
    func updateMarkerV2(guildId: UUID, markerId: UUID, request body: RLUpdateMarkerRequest) async throws -> RLChartMarkerDTO { throw APIError.networkError("unused") }
    func deleteMarker(guildId: UUID, markerId: UUID) async throws -> RLMarkerDeleteResponseDTO { throw APIError.networkError("unused") }
    func toggleMarkerLike(guildId: UUID, markerId: UUID) async throws -> RLLikeMarkerDTO { throw APIError.networkError("unused") }
    func voteOnPoll(guildId: UUID, markerId: UUID, optionId: UUID) async throws -> RLVotePollDTO { throw APIError.networkError("unused") }
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
