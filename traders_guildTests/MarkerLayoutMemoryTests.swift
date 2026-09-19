import Foundation
import Testing
@testable import traders_guild

/// A marker keeps its side and stack across a timeframe or symbol round trip.
///
/// Layout used to be retained only from the wrappers still in `markers`, and a
/// context switch empties that array — so every switch re-allocated from
/// scratch and the chart appeared to shuffle. The manager now remembers each
/// context's slots when the layer is cleared and restores them on return.
@MainActor
struct MarkerLayoutMemoryTests {

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

    private func hourly(_ count: Int) -> [RLCandleDTO] {
        (0..<count).map { i in
            RLCandleDTO(timestamp: t0.addingTimeInterval(Double(i) * hour), open: 1, high: 2, low: 0.5, close: 1.5, volume: nil)
        }
    }

    private func fiveMinute(_ count: Int) -> [RLCandleDTO] {
        (0..<count).map { i in
            RLCandleDTO(timestamp: t0.addingTimeInterval(Double(i) * 300), open: 1, high: 2, low: 0.5, close: 1.5, volume: nil)
        }
    }

    /// `created` orders allocation; `candle` is the hourly candle index.
    private func marker(_ n: Int, candle: Int, created: Int, timeframe: String = "1h") -> RLChartMarkerDTO {
        RLChartMarkerDTO(
            id: id(n), symbolId: symbolId, guildId: guildId, author: member(1),
            candleTimestamp: t0.addingTimeInterval(Double(candle) * (timeframe == "1h" ? hour : 300)),
            timeframe: timeframe, price: 1,
            intent: "analysis", title: "M\(n)", note: nil, visibility: "guild",
            confidence: nil, trackingEnabled: false, trackingState: nil, alertSeverity: nil,
            createdAt: t0.addingTimeInterval(Double(created)), createdAtFormatted: "now", isVisible: true,
            likeCount: 0, isLikedByCurrentUser: false, commentCount: 0, comments: [],
            isCurrentUserMarker: true, canEdit: true, canDelete: true,
            components: [], primaryComponentId: nil,
            pollQuestion: nil, pollOptions: nil, userPollVote: nil, predictionResult: nil
        )
    }

    private func manager() -> MarkerManager {
        let me = member(1)
        return MarkerManager(userId: me.userId, guildId: guildId, currentUserMember: me)
    }

    private func load(_ manager: MarkerManager, _ page: [RLChartMarkerDTO], timeframe: RLChartTimeframe, candles: [RLCandleDTO]) async {
        let api = LayoutFakeAPI()
        api.page = page
        await manager.loadMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: guildId, timeframe: timeframe, candles: candles
        )
    }

    private func slots(_ manager: MarkerManager) -> [UUID: (below: Bool, stack: Int)] {
        Dictionary(uniqueKeysWithValues: manager.markers.map { ($0.id, ($0.positionedBelow, $0.stackIndex)) })
    }

    // Run 1 allocation, in `created` order: m1 on candle 5 → above/0; m2 on
    // candle 7 sees m1 above within two candles → below/0; m3 on candle 5
    // joins m1 → above/1.
    private var firstPage: [RLChartMarkerDTO] {
        [marker(1, candle: 5, created: 1), marker(2, candle: 7, created: 2), marker(3, candle: 5, created: 5)]
    }

    @Test
    func aRoundTripPutsEveryMarkerBackWhereItWas() async {
        let candles = hourly(10)
        let subject = manager()
        await load(subject, firstPage, timeframe: .h1, candles: candles)
        let before = slots(subject)
        #expect(before[id(1)]?.below == false && before[id(2)]?.below == true && before[id(3)]?.below == false,
                "fixture allocates as documented")

        // Switch away (the chart clears the layer) and load another timeframe.
        subject.clearMarkers()
        await load(subject, [marker(40, candle: 3, created: 1, timeframe: "5m")], timeframe: .m5, candles: fiveMinute(10))
        #expect(subject.markers.count == 1)

        // Come back. The page now also carries an older marker on candle 7:
        // allocated from scratch it would go first and flip all three others
        // (the control below proves that); with memory they keep their slots
        // and only the newcomer allocates around them.
        let secondPage = [marker(0, candle: 7, created: 0)] + firstPage
        await load(subject, secondPage, timeframe: .h1, candles: candles)
        let after = slots(subject)
        for n in 1...3 {
            #expect(after[id(n)]?.below == before[id(n)]?.below, "m\(n) changed side")
            #expect(after[id(n)]?.stack == before[id(n)]?.stack, "m\(n) changed stack")
        }
        #expect(after[id(0)]?.below == true && after[id(0)]?.stack == 1, "the newcomer joins m2's side on candle 7")

        // Control: the same second page on a fresh manager allocates differently.
        let fresh = manager()
        await load(fresh, secondPage, timeframe: .h1, candles: candles)
        let control = slots(fresh)
        #expect(control[id(1)]?.below != before[id(1)]?.below, "without memory the switch would have shuffled")
    }

    @Test
    func aMarkerWhoseAnchorMovedIsAllocatedAfresh() async {
        let candles = hourly(12)
        let subject = manager()
        await load(subject, firstPage, timeframe: .h1, candles: candles)
        #expect(slots(subject)[id(2)]?.below == true)

        subject.clearMarkers()
        await load(subject, [marker(40, candle: 3, created: 1, timeframe: "5m")], timeframe: .m5, candles: fiveMinute(10))

        // m2 was edited onto candle 9 while we were away. Its remembered slot
        // belongs to the old anchor and must not be applied.
        let moved = [marker(1, candle: 5, created: 1), marker(2, candle: 9, created: 2), marker(3, candle: 5, created: 5)]
        await load(subject, moved, timeframe: .h1, candles: candles)
        let after = slots(subject)
        #expect(after[id(1)]?.below == false && after[id(3)]?.below == false, "unmoved markers restored")
        #expect(after[id(2)]?.below == false, "no neighbours on candle 9 → default above, not the remembered below")
    }

    @Test
    func memoryIsScopedToTheGuild() async {
        let candles = hourly(10)
        let subject = manager()
        await load(subject, firstPage, timeframe: .h1, candles: candles)
        subject.clearMarkers()

        // Another guild entirely: nothing from the first should apply.
        let otherGuild = UUID()
        let api = LayoutFakeAPI()
        api.page = [marker(0, candle: 7, created: 0)] + firstPage
        await subject.loadMarkersFromAPI(
            api: api, symbolId: symbolId, symbol: "BTCUSD",
            guildId: otherGuild, timeframe: .h1, candles: candles
        )
        #expect(slots(subject)[id(1)]?.below == true, "allocated from scratch, m0 first")
    }
}

private final class LayoutFakeAPI: MarkerAPIClient, @unchecked Sendable {
    var page: [RLChartMarkerDTO] = []

    func getMarkers(
        guildId: UUID, symbolId: UUID, timeframe: String, limit: Int,
        cursor: String?, startTime: Date?, endTime: Date?
    ) async throws -> RLMarkersListDTO {
        RLMarkersListDTO(markers: page, totalCount: page.count, hasMore: false, nextCursor: nil)
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
