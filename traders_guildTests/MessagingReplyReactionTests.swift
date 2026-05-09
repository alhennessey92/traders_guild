import Foundation
import Testing
@testable import traders_guild

private struct JSONObjectEncodingError: Error {}

struct MessagingReplyReactionTests {
    @Test
    func chatroomAndDMMessagesDecodeReplyPreviewAndReactions() throws {
        let replyMessageId = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
        let author = authorJSON(
            membershipId: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!,
            userId: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!
        )

        let chatroomMessage: RLChatroomMessageDTO = try decodeDTO([
            "id": "DDDDDDDD-0000-0000-0000-000000000001",
            "chatroom_id": "EEEEEEEE-0000-0000-0000-000000000001",
            "author": author,
            "content": "Taking the retest here",
            "timestamp": "2026-03-15T12:00:00Z",
            "timestamp_formatted": "12:00",
            "is_edited": false,
            "is_current_user_message": false,
            "can_edit": false,
            "can_delete": false,
            "attachment_url": "https://example.com/chart.png",
            "attachment_type": "image/png",
            "attachment_name": "chart.png",
            "reply_preview": replyPreviewJSON(messageId: replyMessageId),
            "reactions": reactionsJSON(),
        ])

        #expect(chatroomMessage.replyPreview?.messageId == replyMessageId)
        #expect(chatroomMessage.replyPreview?.authorDisplayName == "Alex Trader")
        #expect(chatroomMessage.reactions.map(\.emoji) == ["🔥", "🎯"])
        #expect(chatroomMessage.reactions.first?.reactedByCurrentUser == true)
        #expect(chatroomMessage.reactions.last?.count == 1)

        let dmMessage: RLDMMessageDTO = try decodeDTO([
            "id": "FFFFFFFF-0000-0000-0000-000000000001",
            "dm_id": "11111111-0000-0000-0000-000000000001",
            "author": author,
            "content": "Replying in DM",
            "timestamp": "2026-03-15T12:01:00Z",
            "timestamp_formatted": "12:01",
            "is_edited": true,
            "is_current_user_message": true,
            "can_edit": true,
            "can_delete": true,
            "is_read": true,
            "reply_preview": replyPreviewJSON(messageId: replyMessageId),
            "reactions": reactionsJSON(),
        ])

        #expect(dmMessage.replyPreview?.messageId == replyMessageId)
        #expect(dmMessage.reactions.count == 2)
        #expect(dmMessage.reactions[0].emoji == "🔥")
        #expect(dmMessage.reactions[0].reactedByCurrentUser == true)
    }

    @Test
    func markerCommentAndChartChatMessagesDecodeReplyPreviewAndReactions() throws {
        let replyMessageId = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!
        let author = authorJSON(
            membershipId: UUID(uuidString: "33333333-0000-0000-0000-000000000001")!,
            userId: UUID(uuidString: "44444444-0000-0000-0000-000000000001")!
        )

        let comment: RLMarkerCommentDTO = try decodeDTO([
            "id": "55555555-0000-0000-0000-000000000001",
            "marker_id": "66666666-0000-0000-0000-000000000001",
            "author": author,
            "content": "Adding context to the marker",
            "timestamp": "2026-03-15T12:02:00Z",
            "timestamp_formatted": "12:02",
            "is_edited": false,
            "is_current_user_message": false,
            "can_edit": false,
            "can_delete": true,
            "reply_preview": replyPreviewJSON(messageId: replyMessageId),
            "reactions": reactionsJSON(),
        ])

        #expect(comment.replyPreview?.messageId == replyMessageId)
        #expect(comment.reactions.count == 2)
        #expect(comment.reactions[1].emoji == "🎯")

        let chartMessage: RLChartChatMessageDTO = try decodeDTO([
            "id": "77777777-0000-0000-0000-000000000001",
            "chat_id": "88888888-0000-0000-0000-000000000001",
            "author": author,
            "content": "Chart chat follow-up",
            "timestamp": "2026-03-15T12:03:00Z",
            "timestamp_formatted": "12:03",
            "is_edited": true,
            "is_current_user_message": true,
            "can_edit": true,
            "can_delete": true,
            "reply_preview": replyPreviewJSON(messageId: replyMessageId),
            "reactions": reactionsJSON(),
        ])

        #expect(chartMessage.replyPreview?.messageId == replyMessageId)
        #expect(chartMessage.reactions.map(\.count) == [3, 1])
    }

    @Test
    func requestModelsEncodeReplyTargetsUsingSnakeCaseKeys() throws {
        let replyId = UUID(uuidString: "99999999-0000-0000-0000-000000000001")!

        let messageRequest = try encodeJSONObject(
            RLSendMessageRequest(content: "Hello", replyToMessageId: replyId)
        )
        #expect(messageRequest["reply_to_message_id"] as? String == replyId.uuidString)

        let markerRequest = try encodeJSONObject(
            RLCreateMarkerCommentRequest(content: "Marker reply", replyToMessageId: replyId)
        )
        #expect(markerRequest["reply_to_message_id"] as? String == replyId.uuidString)

        let chartRequest = try encodeJSONObject(
            RLSendChartChatMessageRequest(content: "Chart reply", replyToMessageId: replyId)
        )
        #expect(chartRequest["reply_to_message_id"] as? String == replyId.uuidString)

        let reactionRequest = try encodeJSONObject(
            RLToggleMessageReactionRequest(emoji: "🔥")
        )
        #expect(reactionRequest["emoji"] as? String == "🔥")

        let announcementRequest = try encodeJSONObject(
            RLCreateGuildAnnouncementRequestDTO(
                title: "Guild update",
                content: "Content",
                preview: "Preview",
                isImportant: true,
                iconKey: .bell
            )
        )
        #expect(announcementRequest["icon_key"] as? String == "bell")

        let eventRequest = try encodeJSONObject(
            RLCreateGuildEventRequestDTO(
                title: "Review session",
                content: "Bring your charts",
                preview: "Tonight",
                eventDate: Date(timeIntervalSince1970: 1_700_000_000),
                isImportant: false,
                iconKey: .calendar,
                locationType: nil,
                locationId: nil
            )
        )
        #expect(eventRequest["icon_key"] as? String == "calendar")
    }

    @Test
    func reactionReactorsDecodeSharedMemberRows() throws {
        let author = authorJSON(
            membershipId: UUID(uuidString: "ABABABAB-0000-0000-0000-000000000001")!,
            userId: UUID(uuidString: "CDCDCDCD-0000-0000-0000-000000000001")!
        )
        let payload: RLMessageReactionReactorsDTO = try decodeDTO([
            "emoji": "🔥",
            "count": 3,
            "reactors": [author, author],
        ])

        #expect(payload.emoji == "🔥")
        #expect(payload.count == 3)
        #expect(payload.reactors.count == 2)
        #expect(payload.reactors.first?.displayName == "Alex Trader")
    }

    @Test
    func reactionBubbleCountTextStaysHiddenUntilMoreThanTwo() {
        #expect(RLMessageReactionDTO(emoji: "🔥", count: 1, reactedByCurrentUser: false).compactBubbleCountText == nil)
        #expect(RLMessageReactionDTO(emoji: "🔥", count: 2, reactedByCurrentUser: false).compactBubbleCountText == nil)
        #expect(RLMessageReactionDTO(emoji: "🔥", count: 3, reactedByCurrentUser: false).compactBubbleCountText == "3")
    }

    @Test
    func sharedReactionPaletteAndDeletedTombstoneHelpersStayStable() {
        #expect(ChatQuickReactionPalette.emojis == ["👍", "❤️", "😂", "😮", "😢", "😡", "🎉", "🔥", "👏", "🙌", "👀", "🤔"])
        #expect(ChatDeletedMessagePresentation.tombstoneText == "Message deleted")

        let deletedID = UUID()
        #expect(ChatDeletedMessagePresentation.isDeleted(messageId: deletedID, within: [deletedID]))
        #expect(!ChatDeletedMessagePresentation.isDeleted(messageId: UUID(), within: [deletedID]))
    }

    @Test
    func composerPayloadKeepsSingleAttachmentAndReplyDraftTogether() {
        let attachment = ChatAttachmentDraft(
            data: Data([0x01, 0x02]),
            filename: "chart.png",
            mimeType: "image/png"
        )
        let replyDraft = ChatReplyDraft(
            messageId: UUID(uuidString: "AAAAAAAA-1111-1111-1111-111111111111")!,
            authorDisplayName: "Alex Trader",
            contentPreview: "Watch the breakout",
            attachmentType: nil,
            attachmentName: nil
        )

        let payload = ChatComposerPayload(
            text: "Looks good",
            attachment: attachment,
            replyDraft: replyDraft
        )

        #expect(payload.attachments.count == 1)
        #expect(payload.attachments.first?.filename == "chart.png")
        #expect(payload.replyDraft == replyDraft)
        #expect(payload.hasBodyContent)
    }
}

private func decodeDTO<T: Decodable>(_ jsonObject: [String: Any]) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: jsonObject)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: data)
}

private func encodeJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let data = try encoder.encode(value)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any] else {
        throw JSONObjectEncodingError()
    }
    return dictionary
}

private func authorJSON(membershipId: UUID, userId: UUID) -> [String: Any] {
    [
        "membership_id": membershipId.uuidString,
        "role": "member",
        "reputation": 42,
        "contribution_score": 8,
        "date_joined": "2026-01-01T00:00:00Z",
        "accuracy_rate": 0.73,
        "muted_until": NSNull(),
        "suspended_until": NSNull(),
        "user_id": userId.uuidString,
        "username": "alextrader",
        "display_name": "Alex Trader",
        "avatar_url": NSNull(),
        "is_online": true,
        "global_reputation": 128,
        "is_friend": true,
        "friendship_status": "accepted",
        "is_blocked": false,
        "is_blocked_by": false,
    ]
}

private func replyPreviewJSON(messageId: UUID) -> [String: Any] {
    [
        "message_id": messageId.uuidString,
        "author_username": "alextrader",
        "author_display_name": "Alex Trader",
        "content_preview": "Original insight",
        "attachment_type": NSNull(),
        "attachment_name": NSNull(),
        "is_deleted": false,
    ]
}

private func reactionsJSON() -> [[String: Any]] {
    [
        [
            "emoji": "🔥",
            "count": 3,
            "reacted_by_current_user": true,
        ],
        [
            "emoji": "🎯",
            "count": 1,
            "reacted_by_current_user": false,
        ],
    ]
}
