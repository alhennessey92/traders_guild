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
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLChatroomMessageDTO, rhs: RLChatroomMessageDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited
    }
    
    // MARK: - Convenience
    
    /// Check if message was sent recently (within last minute)
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 60
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
    let lastMessage: RLChatroomMessageDTO?
    let isActive: Bool
    let lastActivity: Date
    let lastActivityFormatted: String
    let unreadCount: Int
    let memberCount: Int
    let isPinned: Bool
    let isMuted: Bool
    let canSendMessages: Bool
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLGuildChatroomDTO, rhs: RLGuildChatroomDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.unreadCount == rhs.unreadCount &&
        lhs.isPinned == rhs.isPinned &&
        lhs.isMuted == rhs.isMuted
    }
    
    // MARK: - Convenience
    
    /// Check if chatroom has unread messages
    var hasUnread: Bool {
        unreadCount > 0
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
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RLDMMessageDTO, rhs: RLDMMessageDTO) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isEdited == rhs.isEdited &&
        lhs.isRead == rhs.isRead
    }
    
    // MARK: - Convenience
    
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 60
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
    let description: String?
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

// MARK: - WebSocket Message Types

/// WebSocket message types for real-time updates
enum WSMessageType: String, Codable {
    case newMessage = "new_message"
    case messageEdited = "message_edited"
    case messageDeleted = "message_deleted"
    case typing = "typing"
    case presence = "presence"
    case unreadUpdate = "unread_update"
    case subscribed = "subscribed"
    case unsubscribed = "unsubscribed"
    case pong = "pong"
    case error = "error"
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
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to decode payload: \(error)")
            return nil
        }
    }
}

/// Outgoing WebSocket message for subscription
struct WSSubscribeMessage: Codable {
    let type: String = "subscribe"
    let channels: [String]
}

/// Outgoing WebSocket message for unsubscription
struct WSUnsubscribeMessage: Codable {
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
struct WSPingMessage: Codable {
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
        lastMessage: nil,
        isActive: true,
        lastActivity: Date(),
        lastActivityFormatted: "Just now",
        unreadCount: 3,
        memberCount: 42,
        isPinned: false,
        isMuted: false,
        canSendMessages: true
    )
    
    static let samples: [RLGuildChatroomDTO] = [
        RLGuildChatroomDTO(
            id: UUID(),
            guildId: UUID(),
            name: "general",
            description: "General chat",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date(),
            lastActivityFormatted: "2m ago",
            unreadCount: 5,
            memberCount: 128,
            isPinned: true,
            isMuted: false,
            canSendMessages: true
        ),
        RLGuildChatroomDTO(
            id: UUID(),
            guildId: UUID(),
            name: "trading-signals",
            description: "Share your trades",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date().addingTimeInterval(-3600),
            lastActivityFormatted: "1h ago",
            unreadCount: 0,
            memberCount: 89,
            isPinned: false,
            isMuted: false,
            canSendMessages: true
        ),
        RLGuildChatroomDTO(
            id: UUID(),
            guildId: UUID(),
            name: "announcements",
            description: "Important updates",
            lastMessage: nil,
            isActive: true,
            lastActivity: Date().addingTimeInterval(-86400),
            lastActivityFormatted: "Yesterday",
            unreadCount: 1,
            memberCount: 128,
            isPinned: true,
            isMuted: true,
            canSendMessages: false
        )
    ]
}
#endif