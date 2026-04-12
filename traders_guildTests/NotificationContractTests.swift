import Foundation
import Testing
@testable import traders_guild

struct NotificationContractTests {

    @Test func notificationTypeClassificationCoversNewCases() async throws {
        #expect(RLNotificationType.markerLike.isPersonal)
        #expect(RLNotificationType.markerComment.isPersonal)
        #expect(RLNotificationType.contentReaction.isPersonal)

        #expect(!RLNotificationType.contentReport.isPersonal)
        #expect(!RLNotificationType.memberUnmuted.isPersonal)
        #expect(!RLNotificationType.memberUnsuspended.isPersonal)
    }

    @Test func notificationDestinationMapsEventAndAdminReports() async throws {
        let eventId = UUID()
        let reportId = UUID()
        let guildId = UUID()
        let symbolId = UUID()
        let userId = UUID()

        let eventDestination = RLNotificationDestination(
            type: .event,
            userId: nil,
            guildId: nil,
            symbolId: nil,
            chatroomId: nil,
            announcementId: nil,
            eventId: eventId,
            reportId: nil
        )
        let reportsDestination = RLNotificationDestination(
            type: .adminReports,
            userId: nil,
            guildId: guildId,
            symbolId: nil,
            chatroomId: nil,
            announcementId: nil,
            eventId: nil,
            reportId: reportId
        )
        let chartDestination = RLNotificationDestination(
            type: .symbolChart,
            userId: nil,
            guildId: guildId,
            symbolId: symbolId,
            chatroomId: nil,
            announcementId: nil,
            eventId: nil,
            reportId: nil
        )
        let friendRequestDestination = RLNotificationDestination(
            type: .userProfile,
            userId: userId,
            guildId: nil,
            symbolId: nil,
            chatroomId: nil,
            announcementId: nil,
            eventId: nil,
            reportId: nil
        )

        #expect(eventDestination.navigationDestination == .event(eventId: eventId))
        #expect(reportsDestination.navigationDestination == .adminReports(guildId: guildId, reportId: reportId))
        #expect(chartDestination.navigationDestination == .symbolChart(symbolId: symbolId, ticker: ""))
        #expect(friendRequestDestination.navigationDestination == .userProfile(userId: userId))
    }

    @Test func notificationDTODecodesAdminReportPayload() async throws {
        let notificationId = UUID()
        let recipientId = UUID()
        let guildId = UUID()
        let reportId = UUID()

        let json = """
        {
          "id": "\(notificationId.uuidString)",
          "recipient_id": "\(recipientId.uuidString)",
          "notification_type": "content_report",
          "title": "New content report in Guild",
          "body": "Reporter reported chatroom message for spam",
          "data": {
            "report_id": "\(reportId.uuidString)",
            "guild_id": "\(guildId.uuidString)",
            "guild_name": "Guild",
            "reporter_user_id": "\(UUID().uuidString)",
            "reporter_display_name": "Reporter",
            "content_type": "chatroom_message",
            "content_id": "\(UUID().uuidString)",
            "reason": "spam"
          },
          "destination": {
            "type": "admin_reports",
            "guild_id": "\(guildId.uuidString)",
            "report_id": "\(reportId.uuidString)"
          },
          "is_read": false,
          "read_at": null,
          "view_count": 0,
          "first_viewed_at": null,
          "last_viewed_at": null,
          "created_at": "2026-03-26T10:00:00Z",
          "updated_at": "2026-03-26T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLNotificationDTO.self, from: Data(json.utf8))

        #expect(dto.type == .contentReport)
        #expect(dto.navigationDestination == .adminReports(guildId: guildId, reportId: reportId))
    }

    @Test func contentReportResolutionSummaryBuildsFromNotificationPayload() async throws {
        let notificationId = UUID()
        let recipientId = UUID()
        let guildId = UUID()
        let reportId = UUID()

        let json = """
        {
          "id": "\(notificationId.uuidString)",
          "recipient_id": "\(recipientId.uuidString)",
          "notification_type": "content_report",
          "title": "Report resolved",
          "body": "Your report was resolved",
          "data": {
            "report_id": "\(reportId.uuidString)",
            "guild_id": "\(guildId.uuidString)",
            "guild_name": "Guild",
            "content_type": "chatroom_message",
            "resolution_status": "resolved",
            "reviewer_display_name": "Moderator Mia",
            "resolution_note": "Removed for spam."
          },
          "destination": {
            "type": "admin_reports",
            "guild_id": "\(guildId.uuidString)",
            "report_id": "\(reportId.uuidString)"
          },
          "is_read": false,
          "read_at": null,
          "view_count": 0,
          "first_viewed_at": null,
          "last_viewed_at": null,
          "created_at": "2026-03-26T10:00:00Z",
          "updated_at": "2026-03-26T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLNotificationDTO.self, from: Data(json.utf8))
        let summary = try #require(dto.contentReportResolutionSummary)

        #expect(summary.reportId == reportId)
        #expect(summary.guildId == guildId)
        #expect(summary.guildName == "Guild")
        #expect(summary.contentTypeDisplay == "Chat Message")
        #expect(summary.statusTitle == "Resolved")
        #expect(summary.reviewerDisplayName == "Moderator Mia")
        #expect(summary.resolutionNote == "Removed for spam.")
    }

    @Test func websocketMessageTypeIncludesNotificationLifecycleCases() async throws {
        #expect(WSMessageType(rawValue: "notification") == .notification)
        #expect(WSMessageType(rawValue: "notification_stats_update") == .notificationStatsUpdate)
        #expect(WSMessageType(rawValue: "notification_read") == .notificationRead)
        #expect(WSMessageType(rawValue: "notification_deleted") == .notificationDeleted)
        #expect(WSMessageType(rawValue: "reputation_update") == .reputationUpdate)
        #expect(WSMessageType(rawValue: "accuracy_update") == .accuracyUpdate)
        #expect(WSMessageType(rawValue: "member_performance_updated") == .memberPerformanceUpdated)
    }

    @Test func markerResultNotificationBuildsSharePayload() async throws {
        let notificationId = UUID()
        let recipientId = UUID()
        let markerId = UUID()
        let guildId = UUID()
        let symbolId = UUID()

        let json = """
        {
          "id": "\(notificationId.uuidString)",
          "recipient_id": "\(recipientId.uuidString)",
          "notification_type": "marker_result",
          "title": "Trade Result: Win",
          "body": "Your setup hit TP",
          "data": {
            "marker_id": "\(markerId.uuidString)",
            "guild_id": "\(guildId.uuidString)",
            "symbol_id": "\(symbolId.uuidString)",
            "symbol_ticker": "BTCUSD",
            "timeframe": "1h",
            "candle_timestamp": "2026-03-26T10:00:00Z",
            "intent": "setup",
            "result_type": "take_profit",
            "pnl": 2.45,
            "trigger_price": 84000.0
          },
          "destination": {
            "type": "symbol_chart",
            "guild_id": "\(guildId.uuidString)",
            "symbol_id": "\(symbolId.uuidString)"
          },
          "is_read": false,
          "read_at": null,
          "view_count": 0,
          "first_viewed_at": null,
          "last_viewed_at": null,
          "created_at": "2026-03-26T10:05:00Z",
          "updated_at": "2026-03-26T10:05:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLNotificationDTO.self, from: Data(json.utf8))

        #expect(dto.navigationDestination == .symbolChart(symbolId: symbolId, ticker: "BTCUSD"))
        #expect(dto.markerSharePayload?.markerId == markerId)
        #expect(dto.markerSharePayload?.symbolId == symbolId)
        #expect(dto.markerSharePayload?.timeframe == "1h")
    }

    @Test func announcementNotificationsReusePersistedGuildPostIcons() async throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "recipient_id": "\(UUID().uuidString)",
          "notification_type": "announcement",
          "title": "Guild update",
          "body": "New schedule posted",
          "data": {
            "announcement_id": "\(UUID().uuidString)",
            "icon_key": "bell"
          },
          "destination": {
            "type": "announcement",
            "announcement_id": "\(UUID().uuidString)"
          },
          "is_read": false,
          "read_at": null,
          "view_count": 0,
          "first_viewed_at": null,
          "last_viewed_at": null,
          "created_at": "2026-03-26T10:05:00Z",
          "updated_at": "2026-03-26T10:05:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLNotificationDTO.self, from: Data(json.utf8))

        #expect(dto.guildPostIconKey == .bell)
        #expect(dto.icon == "bell.fill")
    }

    @Test func createAnnouncementRequestAlwaysEncodesPreview() throws {
        let request = RLCreateGuildAnnouncementRequestDTO(
            title: "Guild update",
            content: "Expanded announcement body",
            preview: "Expanded announcement body",
            isImportant: true,
            iconKey: .megaphone
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["preview"] as? String == "Expanded announcement body")
        #expect(json["is_important"] as? Bool == true)
        #expect(json["icon_key"] as? String == GuildPostIconKey.megaphone.rawValue)
    }

    @Test func announcementPreviewFallsBackToContentWhenBackendOmitsIt() {
        let now = Date()
        let content = String(repeating: "A", count: 120)
        let announcement = RLGuildAnnouncementWithAuthorDTO(
            announcement: RLGuildAnnouncementResponseDTO(
                id: UUID(),
                guildId: UUID(),
                authorMembershipId: UUID(),
                title: "Guild update",
                content: content,
                preview: nil,
                postedAt: now,
                isImportant: true,
                iconKey: nil,
                readCount: 0,
                status: "posted",
                isRead: false
            ),
            authorMembership: RLGuildSimpleMembershipResponse(
                userId: UUID(),
                guildId: UUID(),
                role: "owner",
                reputation: 10,
                accuracyRate: nil,
                userDisplayName: "Alice",
                userUsername: "alice",
                userAvatarUrl: nil
            )
        )

        #expect(announcement.preview == String(content.prefix(100)))
    }

    @Test func pushTapPayloadParsesSnakeCaseDMDestination() async throws {
        let notificationId = UUID()
        let userId = UUID()

        let payload = try #require(
            RLPushNotificationTapPayload(
                userInfo: [
                    "notification_type": "dm",
                    "notification_id": notificationId.uuidString,
                    "destination": [
                        "type": "user_dm",
                        "user_id": userId.uuidString,
                    ],
                    "notification_data": [
                        "thread_id": UUID().uuidString,
                        "sender_username": "alice",
                    ],
                ]
            )
        )

        #expect(payload.notificationId == notificationId)
        #expect(payload.navigationDestination == .userDM(userId: userId))
    }

    @Test func pushTapPayloadBuildsMarkerNavigationPayloadFromAPNsData() async throws {
        let symbolId = UUID()
        let markerId = UUID()

        let payload = try #require(
            RLPushNotificationTapPayload(
                userInfo: [
                    "notification_type": "marker_comment",
                    "destination": [
                        "type": "symbol_chart",
                        "symbol_id": symbolId.uuidString,
                    ],
                    "notification_data": [
                        "marker_id": markerId.uuidString,
                        "symbol_id": symbolId.uuidString,
                        "symbol_ticker": "BTCUSD",
                        "timeframe": "4h",
                        "intent": "setup",
                    ],
                ]
            )
        )

        #expect(payload.navigationDestination == .symbolChart(symbolId: symbolId, ticker: "BTCUSD"))
        #expect(payload.markerNavigationPayload?.markerId == markerId)
        #expect(payload.markerNavigationPayload?.symbolId == symbolId)
        #expect(payload.markerNavigationPayload?.timeframe == "4h")
    }

    @Test func friendRequestNotificationRoutesToRequestedUserProfile() async throws {
        let notificationId = UUID()
        let recipientId = UUID()
        let requestedUserId = UUID()

        let json = """
        {
          "id": "\(notificationId.uuidString)",
          "recipient_id": "\(recipientId.uuidString)",
          "notification_type": "friend_request",
          "title": "Friend request sent to Alice",
          "body": "Waiting for Alice to respond",
          "data": {
            "from_user_id": "\(requestedUserId.uuidString)",
            "from_username": "alice",
            "from_display_name": "Alice",
            "from_avatar_url": "https://example.com/alice.png",
            "message": "Let's connect"
          },
          "destination": {
            "type": "user_profile",
            "user_id": "\(requestedUserId.uuidString)"
          },
          "is_read": false,
          "read_at": null,
          "view_count": 0,
          "first_viewed_at": null,
          "last_viewed_at": null,
          "created_at": "2026-04-06T10:00:00Z",
          "updated_at": "2026-04-06T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLNotificationDTO.self, from: Data(json.utf8))

        #expect(dto.type == .friendRequest)
        #expect(dto.navigationDestination == .userProfile(userId: requestedUserId))
        #expect(dto.senderAvatarURL == "https://example.com/alice.png")
        #expect(dto.friendRequestFromUserId == requestedUserId)
    }

    @Test func markerActivityDTODecodesResolvedPredictionResult() async throws {
        let markerId = UUID()
        let guildId = UUID()
        let symbolId = UUID()
        let authorId = UUID()

        let json = """
        {
          "markers": [
            {
              "id": "\(markerId.uuidString)",
              "symbol_id": "\(symbolId.uuidString)",
              "symbol_ticker": "BTCUSD",
              "symbol_brand_color": "#33AAFF",
              "symbol_asset_class": "crypto",
              "guild_id": "\(guildId.uuidString)",
              "author_id": "\(authorId.uuidString)",
              "author_username": "alice",
              "author_initials": "AL",
              "author_avatar_url": null,
              "author_is_online": false,
              "author_reputation": 1200,
              "author_accuracy_rate": 0.61,
              "author_role": "member",
              "intent": "setup",
              "title": "BTC breakout",
              "note_preview": "Watching the breakout retest",
              "created_at": "2026-03-26T09:00:00Z",
              "created_at_formatted": "1h ago",
              "activity_timestamp": "2026-03-26T10:05:00Z",
              "activity_timestamp_formatted": "just now",
              "candle_timestamp": "2026-03-26T08:00:00Z",
              "timeframe": "1h",
              "price": 82000.0,
              "setup_summary": {
                "entry_price": 82000.0,
                "sl_price": 81000.0,
                "tp_price": 84000.0,
                "tracking_state": "TP_HIT"
              },
              "prediction_result": {
                "result_type": "take_profit",
                "trigger_price": 84000.0,
                "triggered_at": "2026-03-26T10:05:00Z",
                "triggered_at_formatted": "just now",
                "pnl": 2.44
              },
              "like_count": 4,
              "is_liked_by_current_user": true,
              "comment_count": 1,
              "is_current_user_marker": false
            }
          ],
          "total_count": 1,
          "has_more": false,
          "next_cursor": null,
          "last_updated": "2026-03-26T10:05:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let dto = try decoder.decode(RLMarkerActivityListDTO.self, from: Data(json.utf8))
        let marker = try #require(dto.markers.first)

        #expect(marker.intentEnum == .setup)
        #expect(marker.trackingStateEnum == .tpHit)
        #expect(marker.predictionResult?.displayLabel == "TP Hit")
        #expect(marker.asTopMarkerDTO().setupSummary?.trackingState == "TP_HIT")
    }

    @Test func markerTopTabsMapToExpectedActivityRequests() async throws {
        #expect(RLMarkerActivityTopTab.active.activityState == .active)
        #expect(RLMarkerActivityTopTab.active.activityWindow == nil)

        #expect(RLMarkerActivityTopTab.today.activityState == .all)
        #expect(RLMarkerActivityTopTab.today.activityWindow == .today)

        #expect(RLMarkerActivityTopTab.thisWeek.activityState == .all)
        #expect(RLMarkerActivityTopTab.thisWeek.activityWindow == .week)

        #expect(RLMarkerActivityTopTab.thisMonth.activityState == .all)
        #expect(RLMarkerActivityTopTab.thisMonth.activityWindow == .month)

        #expect(RLMarkerActivityTopTab.resolved.activityState == .resolved)
        #expect(RLMarkerActivityTopTab.resolved.activityWindow == nil)
    }
}
