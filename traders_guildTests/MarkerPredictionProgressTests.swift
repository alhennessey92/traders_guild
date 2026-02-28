import Foundation
import Testing
@testable import traders_guild

struct MarkerPredictionProgressTests {

    @Test func longPredictionApproachingTP() async throws {
        let status = MarkerPredictionProgress.status(
            entryPrice: 100,
            currentPrice: 118,
            targetPrice: 120,
            stopLossPrice: 90
        )
        #expect(status == .approachingTP)
    }

    @Test func shortPredictionApproachingSL() async throws {
        let status = MarkerPredictionProgress.status(
            entryPrice: 100,
            currentPrice: 108,
            targetPrice: 90,
            stopLossPrice: 110
        )
        #expect(status == .approachingSL)
    }

    @Test func predictionStatusFallsBackWhenLiveDataMissing() async throws {
        let status = MarkerPredictionProgress.status(
            entryPrice: 100,
            currentPrice: nil,
            targetPrice: 120,
            stopLossPrice: 90
        )
        #expect(status == .liveUnavailable)
    }

    @Test func predictionStatusInProgressWhenNotNearBounds() async throws {
        let status = MarkerPredictionProgress.status(
            entryPrice: 100,
            currentPrice: 105,
            targetPrice: 120,
            stopLossPrice: 90
        )
        #expect(status == .inProgress)
    }

    @Test func chatroomDTOCanManageDefaultsToFalseWhenAbsent() async throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "guild_id": "\(UUID().uuidString)",
          "name": "general",
          "description": "General chat",
          "is_active": true,
          "last_activity": "2026-02-27T12:00:00Z",
          "last_activity_formatted": "Just now",
          "unread_count": 0,
          "member_count": 42,
          "is_pinned": false,
          "is_muted": false,
          "can_send_messages": true
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLGuildChatroomDTO.self, from: data)
        #expect(dto.canManageChatroom == false)
    }
}
