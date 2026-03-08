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

    @Test func markerStatusUsesComponentPrices() async throws {
        let marker = RLChartMarkerDTO(
            id: UUID(),
            symbolId: UUID(),
            guildId: UUID(),
            author: sampleMember(),
            candleTimestamp: Date(),
            timeframe: "1h",
            price: 100,
            intent: "setup",
            title: nil,
            note: nil,
            visibility: "guild",
            confidence: nil,
            trackingEnabled: true,
            trackingState: "ACTIVE",
            createdAt: Date(),
            createdAtFormatted: "now",
            isVisible: true,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: true,
            canEdit: true,
            canDelete: true,
            components: [
                RLMarkerComponentDTO(
                    id: UUID(),
                    componentType: RLComponentType.anchor.rawValue,
                    payload: .anchor(AnchorPayload(time: Date(), price: 100)),
                    ordering: 0
                ),
                RLMarkerComponentDTO(
                    id: UUID(),
                    componentType: RLComponentType.levelEntry.rawValue,
                    payload: .levelEntry(LevelPayload(price: 100, label: nil)),
                    ordering: 1
                ),
                RLMarkerComponentDTO(
                    id: UUID(),
                    componentType: RLComponentType.levelTp.rawValue,
                    payload: .levelTp(LevelPayload(price: 120, label: nil)),
                    ordering: 2
                ),
                RLMarkerComponentDTO(
                    id: UUID(),
                    componentType: RLComponentType.levelSl.rawValue,
                    payload: .levelSl(LevelPayload(price: 90, label: nil)),
                    ordering: 3
                ),
            ],
            primaryComponentId: nil,
            pollQuestion: nil,
            pollOptions: nil,
            userPollVote: nil
        )

        let status = MarkerPredictionProgress.status(marker: marker, currentPrice: 118)
        #expect(status == .approachingTP)
    }

    @Test func unknownComponentPayloadFallsBackWithoutDecodeFailure() async throws {
        let payload: [String: Any] = [
            "id": UUID().uuidString,
            "symbol_id": UUID().uuidString,
            "guild_id": UUID().uuidString,
            "author": [
                "membership_id": UUID().uuidString,
                "role": "member",
                "reputation": 0,
                "contribution_score": 0,
                "date_joined": "2026-03-01T10:00:00Z",
                "accuracy_rate": NSNull(),
                "muted_until": NSNull(),
                "suspended_until": NSNull(),
                "user_id": UUID().uuidString,
                "username": "tester",
                "display_name": "Tester",
                "avatar_url": NSNull(),
                "is_online": true,
                "global_reputation": 0,
                "is_friend": false,
                "friendship_status": NSNull(),
                "is_blocked": false,
                "is_blocked_by": false,
            ],
            "candle_timestamp": "2026-03-01T10:00:00Z",
            "timeframe": "1h",
            "price": 100,
            "intent": "analysis",
            "title": NSNull(),
            "note": "note",
            "visibility": "guild",
            "confidence": NSNull(),
            "tracking_enabled": false,
            "tracking_state": NSNull(),
            "created_at": "2026-03-01T10:00:00Z",
            "created_at_formatted": "now",
            "is_visible": true,
            "like_count": 0,
            "is_liked_by_current_user": false,
            "comment_count": 0,
            "comments": [],
            "components": [
                [
                    "id": UUID().uuidString,
                    "component_type": "custom.future_component",
                    "payload": [
                        "foo": "bar",
                        "nested": ["x": 1],
                    ],
                    "ordering": 0,
                ],
            ],
            "primary_component_id": NSNull(),
            "is_current_user_marker": true,
            "can_edit": true,
            "can_delete": true,
            "poll_question": NSNull(),
            "poll_options": NSNull(),
            "user_poll_vote": NSNull(),
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let marker = try decoder.decode(RLChartMarkerDTO.self, from: data)
        #expect(marker.components.count == 1)
        if case .unknown(let type, _) = marker.components[0].payload {
            #expect(type == "custom.future_component")
        } else {
            Issue.record("Expected unknown component payload fallback")
        }
    }

    @Test func topMarkerSetupSummaryDecodesFromSnakeCase() async throws {
        let payload: [String: Any] = [
            "id": UUID().uuidString,
            "symbol_id": UUID().uuidString,
            "symbol_ticker": "BTCUSD",
            "symbol_brand_color": "#f7931a",
            "symbol_asset_class": "crypto",
            "guild_id": UUID().uuidString,
            "author_id": UUID().uuidString,
            "author_username": "tester",
            "author_initials": "TS",
            "author_avatar_url": NSNull(),
            "author_is_online": true,
            "author_reputation": 10,
            "author_accuracy_rate": 0.6,
            "author_role": "member",
            "intent": "setup",
            "title": "Breakout setup",
            "note_preview": "Break and retest",
            "created_at": "2026-03-01T10:00:00Z",
            "created_at_formatted": "now",
            "candle_timestamp": "2026-03-01T10:00:00Z",
            "timeframe": "1h",
            "price": 100.0,
            "setup_summary": [
                "entry_price": 100.0,
                "sl_price": 95.0,
                "tp_price": 115.0,
                "tracking_state": "ARMED",
            ],
            "like_count": 2,
            "is_liked_by_current_user": false,
            "comment_count": 1,
            "trending_score": 1.1,
            "is_current_user_marker": false,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let marker = try decoder.decode(RLTopMarkerDTO.self, from: data)
        #expect(marker.intentEnum == .setup)
        #expect(marker.setupSummary?.entryPrice == 100.0)
        #expect(marker.setupSummary?.trackingState == "ARMED")
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

private func sampleMember() -> RLGuildMemberDTO {
    RLGuildMemberDTO(
        membershipId: UUID(),
        role: "member",
        reputation: 0,
        contributionScore: 0,
        dateJoined: Date(),
        accuracyRate: nil,
        mutedUntil: nil,
        suspendedUntil: nil,
        userId: UUID(),
        username: "tester",
        displayName: "Tester",
        avatarUrl: nil,
        isOnline: true,
        globalReputation: 0,
        isFriend: false,
        friendshipStatus: nil,
        isBlocked: false,
        isBlockedBy: false
    )
}
