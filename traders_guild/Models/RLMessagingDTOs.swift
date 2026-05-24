//
//  MessagingDTOs.swift
//  TradersGuild
//
//  Messaging DTOs - Maps to backend shared/schemas/messaging.py
//
//  NOTE: Uses existing RLGuildMemberDTO from CoreDTOs.swift as embedded author type.
//
//  Backend Field      → Swift Property (via .convertFromSnakeCase)
//  -------------      ----------------
//  chatroom_id       → chatroomId
//  is_edited         → isEdited
//  timestamp_formatted → timestampFormatted
//

import Foundation

private enum WSDateParsing {
    static func parse(_ rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeFractionalSeconds(in: trimmed)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: normalized) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: normalized) {
            return date
        }

        let noTimezoneFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
        ]
        let noTimezoneFormatter = DateFormatter()
        noTimezoneFormatter.locale = Locale(identifier: "en_US_POSIX")
        noTimezoneFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in noTimezoneFormats {
            noTimezoneFormatter.dateFormat = format
            if let date = noTimezoneFormatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }

    private static func normalizeFractionalSeconds(in rawValue: String) -> String {
        guard let dotIndex = rawValue.firstIndex(of: ".") else {
            return rawValue
        }

        guard let timezoneIndex = rawValue[dotIndex...].firstIndex(where: {
            $0 == "Z" || $0 == "+" || $0 == "-"
        }) else {
            return rawValue
        }

        let fractionStart = rawValue.index(after: dotIndex)
        let fraction = rawValue[fractionStart..<timezoneIndex]
        guard !fraction.isEmpty else {
            return rawValue
        }

        let cappedFraction: Substring
        if fraction.count > 6 {
            cappedFraction = fraction.prefix(6)
        } else {
            cappedFraction = fraction
        }

        return String(rawValue[..<dotIndex]) + "." + cappedFraction + String(rawValue[timezoneIndex...])
    }
}

struct RLMessageReplyPreviewDTO: Codable, Equatable, Hashable {
    let messageId: UUID
    let authorUsername: String
    let authorDisplayName: String?
    let contentPreview: String
    let attachmentType: String?
    let attachmentName: String?
    let isDeleted: Bool
}

struct RLMessageReactionDTO: Codable, Equatable, Hashable {
    let emoji: String
    let count: Int
    var reactedByCurrentUser: Bool
}

struct RLReactionAggregateDTO: Codable, Equatable, Hashable {
    let emoji: String
    let count: Int
}

struct RLMessageReactionReactorsDTO: Codable, Equatable, Hashable {
    let emoji: String
    let count: Int
    let reactors: [RLGuildMemberDTO]
}

struct RLMessageAttachmentDTO: Codable, Equatable, Hashable, Identifiable {
    let attachmentUrl: String
    let attachmentType: String?
    let attachmentName: String?

    var id: String {
        "\(attachmentUrl)|\(attachmentName ?? "")"
    }
}

// MARK: - Chatroom Message

/// Individual chatroom message response
/// Backend: ChatroomMessageResponse
struct RLChatroomMessageDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let chatroomId: UUID
    let author: RLGuildMemberDTO              // Uses existing DTO from CoreDTOs.swift
    let content: String
    let timestamp: Date
    let timestampFormatted: String
    let isEdited: Bool
    let isCurrentUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    let attachments: [RLMessageAttachmentDTO]
    let replyPreview: RLMessageReplyPreviewDTO?
    var reactions: [RLMessageReactionDTO]
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLChatroomMessageDTO, rhs: RLChatroomMessageDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited &&
        lhs.attachments == rhs.attachments &&
        lhs.replyPreview == rhs.replyPreview &&
        lhs.reactions == rhs.reactions
    }

    enum CodingKeys: String, CodingKey {
        case id, chatroomId, author, content
        case timestamp
        case createdAt
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
        case attachmentUrl, attachmentType, attachmentName, attachments
        case replyPreview, reactions
    }

    init(
        id: UUID,
        chatroomId: UUID,
        author: RLGuildMemberDTO,
        content: String,
        timestamp: Date,
        timestampFormatted: String,
        isEdited: Bool,
        isCurrentUserMessage: Bool,
        canEdit: Bool,
        canDelete: Bool,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        attachments: [RLMessageAttachmentDTO],
        replyPreview: RLMessageReplyPreviewDTO?,
        reactions: [RLMessageReactionDTO]
    ) {
        self.id = id
        self.chatroomId = chatroomId
        self.author = author
        self.content = content
        self.timestamp = timestamp
        self.timestampFormatted = timestampFormatted
        self.isEdited = isEdited
        self.isCurrentUserMessage = isCurrentUserMessage
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.attachments = attachments
        self.replyPreview = replyPreview
        self.reactions = reactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let attachmentUrl = try container.decodeIfPresent(String.self, forKey: .attachmentUrl)
        let attachmentType = try container.decodeIfPresent(String.self, forKey: .attachmentType)
        let attachmentName = try container.decodeIfPresent(String.self, forKey: .attachmentName)
        let attachments = try container.decodeIfPresent([RLMessageAttachmentDTO].self, forKey: .attachments)
            ?? Self.fallbackAttachments(
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName
            )

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            chatroomId: try container.decode(UUID.self, forKey: .chatroomId),
            author: try container.decode(RLGuildMemberDTO.self, forKey: .author),
            content: try container.decode(String.self, forKey: .content),
            timestamp: try container.decodeIfPresent(Date.self, forKey: .timestamp)
                ?? container.decode(Date.self, forKey: .createdAt),
            timestampFormatted: try container.decode(String.self, forKey: .timestampFormatted),
            isEdited: try container.decode(Bool.self, forKey: .isEdited),
            isCurrentUserMessage: try container.decode(Bool.self, forKey: .isCurrentUserMessage),
            canEdit: try container.decode(Bool.self, forKey: .canEdit),
            canDelete: try container.decode(Bool.self, forKey: .canDelete),
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            attachments: attachments,
            replyPreview: try container.decodeIfPresent(RLMessageReplyPreviewDTO.self, forKey: .replyPreview),
            reactions: try container.decodeIfPresent([RLMessageReactionDTO].self, forKey: .reactions) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(chatroomId, forKey: .chatroomId)
        try container.encode(author, forKey: .author)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(timestampFormatted, forKey: .timestampFormatted)
        try container.encode(isEdited, forKey: .isEdited)
        try container.encode(isCurrentUserMessage, forKey: .isCurrentUserMessage)
        try container.encode(canEdit, forKey: .canEdit)
        try container.encode(canDelete, forKey: .canDelete)
        try container.encodeIfPresent(attachmentUrl, forKey: .attachmentUrl)
        try container.encodeIfPresent(attachmentType, forKey: .attachmentType)
        try container.encodeIfPresent(attachmentName, forKey: .attachmentName)
        try container.encode(attachments, forKey: .attachments)
        try container.encodeIfPresent(replyPreview, forKey: .replyPreview)
        try container.encode(reactions, forKey: .reactions)
    }
    
    // MARK: - Convenience
    
    /// Check if message was sent recently (within last minute)
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 60
    }

    func withCurrentUser(_ isCurrent: Bool) -> RLChatroomMessageDTO {
        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self)
        ) as? [String: Any] else {
            return self
        }
        dict["isCurrentUserMessage"] = isCurrent
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLChatroomMessageDTO.self, from: data) else {
            return self
        }
        return updated
    }

    private static func fallbackAttachments(
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?
    ) -> [RLMessageAttachmentDTO] {
        guard let attachmentUrl else { return [] }
        return [
            RLMessageAttachmentDTO(
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName
            )
        ]
    }

    /// Create a pending (optimistic) message for immediate display before server confirmation.
    static func pending(
        chatroomId: UUID,
        content: String,
        author: RLGuildMemberDTO,
        attachments: [RLMessageAttachmentDTO] = [],
        replyPreview: RLMessageReplyPreviewDTO? = nil
    ) -> RLChatroomMessageDTO {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return RLChatroomMessageDTO(
            id: UUID(),
            chatroomId: chatroomId,
            author: author,
            content: content,
            timestamp: now,
            timestampFormatted: formatter.string(from: now),
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true,
            attachmentUrl: attachments.first?.attachmentUrl,
            attachmentType: attachments.first?.attachmentType,
            attachmentName: attachments.first?.attachmentName,
            attachments: attachments,
            replyPreview: replyPreview,
            reactions: []
        )
    }
}

// MARK: - Guild Chatroom

/// Guild chatroom/channel response
/// Backend: GuildChatroomResponse
struct RLGuildChatroomDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let guildId: UUID
    let name: String
    let description: String?
    let icon: String
    let lastMessage: RLChatroomMessageDTO?
    let isActive: Bool
    let lastActivity: Date
    let lastActivityFormatted: String
    let unreadCount: Int
    let memberCount: Int
    let isPinned: Bool
    let isMuted: Bool
    let canSendMessages: Bool
    let canManageChatroom: Bool

    init(
        id: UUID,
        guildId: UUID,
        name: String,
        description: String?,
        icon: String,
        lastMessage: RLChatroomMessageDTO?,
        isActive: Bool,
        lastActivity: Date,
        lastActivityFormatted: String,
        unreadCount: Int,
        memberCount: Int,
        isPinned: Bool,
        isMuted: Bool,
        canSendMessages: Bool,
        canManageChatroom: Bool
    ) {
        self.id = id
        self.guildId = guildId
        self.name = name
        self.description = description
        self.icon = icon
        self.lastMessage = lastMessage
        self.isActive = isActive
        self.lastActivity = lastActivity
        self.lastActivityFormatted = lastActivityFormatted
        self.unreadCount = unreadCount
        self.memberCount = memberCount
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.canSendMessages = canSendMessages
        self.canManageChatroom = canManageChatroom
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLGuildChatroomDTO, rhs: RLGuildChatroomDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.icon == rhs.icon &&
        lhs.unreadCount == rhs.unreadCount &&
        lhs.isPinned == rhs.isPinned &&
        lhs.isMuted == rhs.isMuted
    }

    enum CodingKeys: String, CodingKey {
        case id
        case guildId
        case name
        case description
        case icon
        case lastMessage
        case isActive
        case lastActivity
        case lastActivityFormatted
        case unreadCount
        case memberCount
        case isPinned
        case isMuted
        case canSendMessages
        case canManageChatroom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        guildId = try container.decode(UUID.self, forKey: .guildId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "#"
        lastMessage = try container.decodeIfPresent(RLChatroomMessageDTO.self, forKey: .lastMessage)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        lastActivity = try container.decode(Date.self, forKey: .lastActivity)
        lastActivityFormatted = try container.decode(String.self, forKey: .lastActivityFormatted)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        canSendMessages = try container.decode(Bool.self, forKey: .canSendMessages)
        canManageChatroom = try container.decodeIfPresent(Bool.self, forKey: .canManageChatroom) ?? false
    }
    
    // MARK: - Convenience
    
    /// Check if chatroom has unread messages
    var hasUnread: Bool {
        unreadCount > 0
    }

    /// Safe icon for display, defaults to # if server value is missing/invalid.
    var displayIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 1 ? trimmed : "#"
    }
}

// MARK: - Chatroom List Responses

/// List of guild chatrooms
/// Backend: GuildChatroomsListResponse
struct RLGuildChatroomsListDTO: Codable {
    let chatrooms: [RLGuildChatroomDTO]
}

/// Paginated list of chatroom messages
/// Backend: ChatroomMessagesListResponse
struct RLChatroomMessagesListDTO: Codable {
    let messages: [RLChatroomMessageDTO]
    let hasMore: Bool
    let nextCursor: String?
}

// MARK: - Chatroom User Settings

/// Chatroom user settings response
/// Backend: ChatroomUserSettingsResponse
struct RLChatroomUserSettingsDTO: Codable, Equatable {
    let chatroomId: UUID
    let userId: UUID
    let isPinned: Bool
    let isMuted: Bool
}

// MARK: - DM Message

/// Individual DM message response
/// Backend: DMMessageResponse
struct RLDMMessageDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let dmId: UUID                            // Backend: thread_id with validation_alias dm_id
    let author: RLGuildMemberDTO
    let content: String
    let timestamp: Date
    let timestampFormatted: String
    let isEdited: Bool
    let isCurrentUserMessage: Bool
    let canEdit: Bool
    let canDelete: Bool
    let isRead: Bool
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    let attachments: [RLMessageAttachmentDTO]
    let replyPreview: RLMessageReplyPreviewDTO?
    var reactions: [RLMessageReactionDTO]
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLDMMessageDTO, rhs: RLDMMessageDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited &&
        lhs.isRead == rhs.isRead &&
        lhs.attachments == rhs.attachments &&
        lhs.replyPreview == rhs.replyPreview &&
        lhs.reactions == rhs.reactions
    }

    enum CodingKeys: String, CodingKey {
        case id, dmId, author, content
        case timestamp
        case createdAt
        case timestampFormatted, isEdited
        case isCurrentUserMessage, canEdit, canDelete
        case isRead
        case attachmentUrl, attachmentType, attachmentName, attachments
        case replyPreview, reactions
    }

    init(
        id: UUID,
        dmId: UUID,
        author: RLGuildMemberDTO,
        content: String,
        timestamp: Date,
        timestampFormatted: String,
        isEdited: Bool,
        isCurrentUserMessage: Bool,
        canEdit: Bool,
        canDelete: Bool,
        isRead: Bool,
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?,
        attachments: [RLMessageAttachmentDTO],
        replyPreview: RLMessageReplyPreviewDTO?,
        reactions: [RLMessageReactionDTO]
    ) {
        self.id = id
        self.dmId = dmId
        self.author = author
        self.content = content
        self.timestamp = timestamp
        self.timestampFormatted = timestampFormatted
        self.isEdited = isEdited
        self.isCurrentUserMessage = isCurrentUserMessage
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.isRead = isRead
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.attachments = attachments
        self.replyPreview = replyPreview
        self.reactions = reactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let attachmentUrl = try container.decodeIfPresent(String.self, forKey: .attachmentUrl)
        let attachmentType = try container.decodeIfPresent(String.self, forKey: .attachmentType)
        let attachmentName = try container.decodeIfPresent(String.self, forKey: .attachmentName)
        let attachments = try container.decodeIfPresent([RLMessageAttachmentDTO].self, forKey: .attachments)
            ?? Self.fallbackAttachments(
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName
            )

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            dmId: try container.decode(UUID.self, forKey: .dmId),
            author: try container.decode(RLGuildMemberDTO.self, forKey: .author),
            content: try container.decode(String.self, forKey: .content),
            timestamp: try container.decodeIfPresent(Date.self, forKey: .timestamp)
                ?? container.decode(Date.self, forKey: .createdAt),
            timestampFormatted: try container.decode(String.self, forKey: .timestampFormatted),
            isEdited: try container.decode(Bool.self, forKey: .isEdited),
            isCurrentUserMessage: try container.decode(Bool.self, forKey: .isCurrentUserMessage),
            canEdit: try container.decode(Bool.self, forKey: .canEdit),
            canDelete: try container.decode(Bool.self, forKey: .canDelete),
            isRead: try container.decode(Bool.self, forKey: .isRead),
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            attachments: attachments,
            replyPreview: try container.decodeIfPresent(RLMessageReplyPreviewDTO.self, forKey: .replyPreview),
            reactions: try container.decodeIfPresent([RLMessageReactionDTO].self, forKey: .reactions) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dmId, forKey: .dmId)
        try container.encode(author, forKey: .author)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(timestampFormatted, forKey: .timestampFormatted)
        try container.encode(isEdited, forKey: .isEdited)
        try container.encode(isCurrentUserMessage, forKey: .isCurrentUserMessage)
        try container.encode(canEdit, forKey: .canEdit)
        try container.encode(canDelete, forKey: .canDelete)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(attachmentUrl, forKey: .attachmentUrl)
        try container.encodeIfPresent(attachmentType, forKey: .attachmentType)
        try container.encodeIfPresent(attachmentName, forKey: .attachmentName)
        try container.encode(attachments, forKey: .attachments)
        try container.encodeIfPresent(replyPreview, forKey: .replyPreview)
        try container.encode(reactions, forKey: .reactions)
    }
    
    // MARK: - Convenience
    
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 60
    }

    func withCurrentUser(_ isCurrent: Bool) -> RLDMMessageDTO {
        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self)
        ) as? [String: Any] else {
            return self
        }
        dict["isCurrentUserMessage"] = isCurrent
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLDMMessageDTO.self, from: data) else {
            return self
        }
        return updated
    }

    private static func fallbackAttachments(
        attachmentUrl: String?,
        attachmentType: String?,
        attachmentName: String?
    ) -> [RLMessageAttachmentDTO] {
        guard let attachmentUrl else { return [] }
        return [
            RLMessageAttachmentDTO(
                attachmentUrl: attachmentUrl,
                attachmentType: attachmentType,
                attachmentName: attachmentName
            )
        ]
    }

    /// Create a pending (optimistic) message for immediate display before server confirmation.
    static func pending(
        dmId: UUID,
        content: String,
        author: RLGuildMemberDTO,
        attachments: [RLMessageAttachmentDTO] = [],
        replyPreview: RLMessageReplyPreviewDTO? = nil
    ) -> RLDMMessageDTO {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return RLDMMessageDTO(
            id: UUID(),
            dmId: dmId,
            author: author,
            content: content,
            timestamp: now,
            timestampFormatted: formatter.string(from: now),
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true,
            isRead: false,
            attachmentUrl: attachments.first?.attachmentUrl,
            attachmentType: attachments.first?.attachmentType,
            attachmentName: attachments.first?.attachmentName,
            attachments: attachments,
            replyPreview: replyPreview,
            reactions: []
        )
    }
}

// MARK: - DM Thread

/// DM thread/conversation response
/// Backend: DMThreadResponse
struct RLDMThreadDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let guildId: UUID
    let participant: RLGuildMemberDTO         // The OTHER person in the conversation
    let lastMessage: RLDMMessageDTO?
    let lastActivity: Date
    let lastActivityFormatted: String
    let unreadCount: Int
    let isBlocked: Bool                       // Has current user blocked participant?
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLDMThreadDTO, rhs: RLDMThreadDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.unreadCount == rhs.unreadCount &&
        lhs.isBlocked == rhs.isBlocked
    }
    
    // MARK: - Convenience
    
    var hasUnread: Bool {
        unreadCount > 0
    }
    
    /// Display name for the thread (participant's name)
    var displayName: String {
        participant.displayName
    }
}

// MARK: - DM List Responses

/// List of DM threads
/// Backend: DMThreadsListResponse
struct RLDMThreadsListDTO: Codable {
    let threads: [RLDMThreadDTO]
}

/// Paginated list of DM messages
/// Backend: DMMessagesListResponse
struct RLDMMessagesListDTO: Codable {
    let messages: [RLDMMessageDTO]
    let hasMore: Bool
    let nextCursor: String?
}

// MARK: - DM User Settings

/// DM user settings response
/// Backend: DMUserSettingsResponse
struct RLDMUserSettingsDTO: Codable, Equatable {
    let threadId: UUID
    let userId: UUID
    let isPinned: Bool
    let isMuted: Bool
}

// MARK: - Combined Responses

/// Combined messaging data for right drawer preload
/// Backend: GuildMessagingDataResponse
struct RLGuildMessagingDataDTO: Codable {
    let chatrooms: [RLGuildChatroomDTO]
    let friendDms: [RLDMThreadDTO]
    let onlineDms: [RLDMThreadDTO]
    let offlineDms: [RLDMThreadDTO]
    
    /// All DM threads combined (convenience)
    var allDms: [RLDMThreadDTO] {
        friendDms + onlineDms + offlineDms
    }
    
    /// Total unread count across all messaging
    var totalUnreadCount: Int {
        let chatroomUnread = chatrooms.reduce(0) { $0 + $1.unreadCount }
        let dmUnread = allDms.reduce(0) { $0 + $1.unreadCount }
        return chatroomUnread + dmUnread
    }
}

/// Unread counts response
/// Backend: UnreadCountsResponse
struct RLUnreadCountsDTO: Codable, Equatable {
    let chatrooms: Int
    let dms: Int
    let chartChats: Int
    let total: Int
}

// MARK: - Request DTOs

/// Send message request
/// Backend: SendMessageRequest
struct RLSendMessageRequest: Codable {
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    let attachments: [RLMessageAttachmentDTO]?
    let replyToMessageId: UUID?

    init(
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachments: [RLMessageAttachmentDTO]? = nil,
        replyToMessageId: UUID? = nil
    ) {
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.attachments = attachments
        self.replyToMessageId = replyToMessageId
    }
}

/// Edit message request
/// Backend: EditMessageRequest
struct RLEditMessageRequest: Codable {
    let content: String
}

/// Create chatroom request
/// Backend: CreateChatroomRequest
struct RLCreateChatroomRequest: Codable {
    let name: String
    let description: String
    let icon: String?
}

/// Update chatroom request
/// Backend: UpdateChatroomRequest
struct RLUpdateChatroomRequest: Codable {
    let name: String?
    let description: String?
    let icon: String?
}

/// Update chatroom settings request
/// Backend: UpdateChatroomSettingsRequest
struct RLUpdateChatroomSettingsRequest: Codable {
    let isPinned: Bool?
    let isMuted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case isPinned = "is_pinned"
        case isMuted = "is_muted"
    }
}

struct RLToggleMessageReactionRequest: Codable {
    let emoji: String
}

// MARK: - WebSocket Message Types

/// WebSocket message types for real-time updates
enum WSMessageType: String, Codable {
    case newMessage = "new_message"
    case messageEdited = "message_edited"
    case messageDeleted = "message_deleted"
    case messageReactionUpdated = "message_reaction_updated"
    case typing = "typing"
    case presence = "presence"
    case unreadUpdate = "unread_update"
    case subscribed = "subscribed"
    case unsubscribed = "unsubscribed"
    case pong = "pong"
    case error = "error"
    // Notification events
    case notification = "notification"
    case notificationStatsUpdate = "notification_stats_update"
    case notificationRead = "notification_read"
    case notificationDeleted = "notification_deleted"
    case reputationUpdate = "reputation_update"
    case accuracyUpdate = "accuracy_update"
    // Guild events
    case guildUpdated = "guild_updated"
    case memberRoleChanged = "member_role_changed"
    case memberMuted = "member_muted"
    case memberSuspended = "member_suspended"
    case memberPerformanceUpdated = "member_performance_updated"
}

// MARK: - Guild Event Payloads

/// Payload for guild_updated WebSocket event
struct WSGuildUpdatedPayload: Codable {
    let guildId: String
    let name: String?
    let description: String?
    let isOpen: Bool?
    let language: String?
    let location: String?
}

/// Payload for member_role_changed WebSocket event
struct WSMemberRoleChangedPayload: Codable {
    let guildId: String
    let userId: String
    let oldRole: String
    let newRole: String
}

/// Payload for member_muted WebSocket event
struct WSMemberMutedPayload: Codable {
    let guildId: String
    let userId: String
    let mutedUntil: String?
    let action: String  // "muted" or "unmuted"
}

/// Payload for member_suspended WebSocket event
struct WSMemberSuspendedPayload: Codable {
    let guildId: String
    let userId: String
    let suspendedUntil: String?
    let action: String  // "suspended" or "unsuspended"
}

struct WSMessageReactionUpdatedPayload: Codable {
    let messageId: String
    let chatroomId: String?
    let threadId: String?
    let chatId: String?
    let markerId: String?
    let actorUserId: String
    let action: String
    let reactions: [RLReactionAggregateDTO]
}

struct WSMessageDeletedPayload: Codable {
    let messageId: String
}

/// Incoming WebSocket message wrapper
struct WSIncomingMessage: Codable {
    let type: String
    let channel: String?
    let payload: AnyCodable?
    let userId: String?
    let isTyping: Bool?
    let message: String?                      // For error messages
    let channels: [String]?                   // For subscribed/unsubscribed
    
    /// Parse payload as specific type
    func payload<T: Decodable>(as type: T.Type) -> T? {
        guard let payload = payload else { return nil }

        do {
            let data = try JSONEncoder().encode(payload)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                if let date = WSDateParsing.parse(dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode payload: \(error)")
            return nil
        }
    }
}

/// Outgoing WebSocket message for subscription
struct WSSubscribeMessage: Encodable {
    let type: String = "subscribe"
    let channels: [String]
}

/// Outgoing WebSocket message for unsubscription
struct WSUnsubscribeMessage: Encodable {
    let type: String = "unsubscribe"
    let channels: [String]
}

/// Outgoing WebSocket message for typing indicator
struct WSTypingMessage: Codable {
    let type: String = "typing"
    let channel: String
    let isTyping: Bool
    
    enum CodingKeys: String, CodingKey {
        case type
        case channel
        case isTyping = "is_typing"
    }
}

/// Outgoing WebSocket ping message
struct WSPingMessage: Encodable {
    let type: String = "ping"
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic WebSocket payloads
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Channel Helpers

/// Channel name builders (match backend redis.py)
enum MessagingChannel {
    case chatroom(UUID)
    case dm(UUID)
    case chartChat(UUID)
    case guildPresence(UUID)
    case userNotifications(UUID)
    
    var name: String {
        switch self {
        case .chatroom(let id):
            return "chatroom:\(id.uuidString.lowercased())"
        case .dm(let id):
            return "dm:\(id.uuidString.lowercased())"
        case .chartChat(let id):
            return "chart_chat:\(id.uuidString.lowercased())"
        case .guildPresence(let id):
            return "guild:\(id.uuidString.lowercased()):presence"
        case .userNotifications(let id):
            return "user:\(id.uuidString.lowercased()):notifications"
        }
    }
}

// MARK: - Sample Data (DEBUG only)

#if DEBUG
extension RLGuildChatroomDTO {
    static let sample = RLGuildChatroomDTO(
        id: UUID(),
        guildId: UUID(),
        name: "general",
        description: "General discussion",
        icon: "#",
        lastMessage: nil,
        isActive: true,
        lastActivity: Date(),
        lastActivityFormatted: "Just now",
        unreadCount: 3,
        memberCount: 42,
        isPinned: false,
        isMuted: false,
        canSendMessages: true,
        canManageChatroom: true
    )
    
    static let samples: [RLGuildChatroomDTO] = [
        RLGuildChatroomDTO(
            id: UUID(),
            guildId: UUID(),
            name: "general",
            description: "General chat",
            icon: "#",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date(),
            lastActivityFormatted: "2m ago",
            unreadCount: 5,
            memberCount: 128,
            isPinned: true,
            isMuted: false,
            canSendMessages: true,
            canManageChatroom: true
        ),
        RLGuildChatroomDTO(
            id: UUID(),
            guildId: UUID(),
            name: "trading-signals",
            description: "Share your trades",
            icon: "@",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date().addingTimeInterval(-3600),
            lastActivityFormatted: "1h ago",
            unreadCount: 0,
            memberCount: 89,
            isPinned: false,
            isMuted: false,
            canSendMessages: true,
            canManageChatroom: true
        ),
        RLGuildChatroomDTO(
            id: UUID(),
            guildId: UUID(),
            name: "announcements",
            description: "Important updates",
            icon: "A",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date().addingTimeInterval(-86400),
            lastActivityFormatted: "Yesterday",
            unreadCount: 1,
            memberCount: 128,
            isPinned: true,
            isMuted: true,
            canSendMessages: false,
            canManageChatroom: false
        )
    ]
}
#endif

// MARK: - Message Search

/// Individual message search result with chatroom context.
/// Backend: MessageSearchResultResponse
struct RLMessageSearchResultDTO: Codable, Identifiable {
    let message: RLChatroomMessageDTO
    let chatroomId: UUID
    let chatroomName: String

    var id: UUID { message.id }
}

/// Paginated message search response.
/// Backend: MessageSearchResponse
struct RLMessageSearchResponseDTO: Codable {
    let results: [RLMessageSearchResultDTO]
    let totalCount: Int
    let hasMore: Bool
    let nextCursor: String?
}
