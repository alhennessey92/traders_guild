// =============================================================================
// NOTIFICATION DTOs - ADD TO CoreDTOs.swift
// =============================================================================
//
// These replace the old GuildNotificationDTO from GeneralDTOs.swift.
// Backend schemas: shared/schemas/notification.py
//
// Backend -> iOS mapping:
//   NotificationResponse        -> RLNotificationDTO
//   NotificationListResponse    -> RLNotificationListDTO
//   NotificationStatsResponse   -> RLNotificationStatsDTO
// =============================================================================

import Foundation
import SwiftUI


// MARK: - Notification Type Enum

/// Maps to backend NotificationType enum.
/// Only user/messaging/guild types. Symbol/marker stay on old system.
enum RLNotificationType: String, Codable, CaseIterable {
    case dm = "dm"
    case chatroom = "chatroom"
    case announcement = "announcement"
    case event = "event"
    case friendRequest = "friend_request"
    case friendAccept = "friend_accept"
    case mention = "mention"
    case guildInvite = "guild_invite"
    
    /// Group for tab filtering
    var isPersonal: Bool {
        switch self {
        case .dm, .chatroom, .friendRequest, .friendAccept, .mention:
            return true
        case .announcement, .event, .guildInvite:
            return false
        }
    }
    
    var isGuild: Bool { !isPersonal }
}


// MARK: - Notification Destination Type

/// Maps to backend NotificationDestinationType enum.
enum RLNotificationDestinationType: String, Codable {
    case userDM = "user_dm"
    case chatroom = "chatroom"
    case userProfile = "user_profile"
    case announcement = "announcement"
    case event = "event"
}


// MARK: - Notification Destination

/// Maps to backend NotificationDestinationData schema.
/// Embedded in RLNotificationDTO.destination (JSONB field).
struct RLNotificationDestination: Codable, Equatable {
    let type: RLNotificationDestinationType
    let userId: UUID?
    let chatroomId: UUID?
    let announcementId: UUID?
    let eventId: UUID?
    
    /// Convert to the navigation enum used by NotificationNavigationManager
    var navigationDestination: NotificationDestination? {
        switch type {
        case .userDM:
            guard let userId = userId else { return nil }
            return .userDM(userId: userId)
        case .chatroom:
            guard let chatroomId = chatroomId else { return nil }
            return .chatroom(chatroomId: chatroomId)
        case .userProfile:
            guard let userId = userId else { return nil }
            return .userProfile(userId: userId)
        case .announcement:
            guard let announcementId = announcementId else { return nil }
            return .announcement(announcementId: announcementId)
        case .event:
            // TODO: Add event destination to NotificationDestination enum when ready
            return nil
        }
    }
}


// MARK: - Notification DTO

/// Maps to backend NotificationResponse schema.
///
/// Backend Field       -> JSON Key           -> Swift Property
/// ---------------     ---------------       ----------------
/// notification_type  -> notificationType   -> notificationType
/// is_read            -> isRead             -> isRead
/// view_count         -> viewCount          -> viewCount
/// created_at         -> createdAt          -> createdAt
struct RLNotificationDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let recipientId: UUID
    let notificationType: String              // Raw string from backend
    let title: String?
    let body: String?
    let data: [String: AnyCodableValue]       // Type-specific JSONB
    let destination: RLNotificationDestination?
    var isRead: Bool
    let readAt: Date?
    let viewCount: Int
    let firstViewedAt: Date?
    let lastViewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Parsed notification type enum
    var type: RLNotificationType? {
        RLNotificationType(rawValue: notificationType)
    }
    
    /// Display title (falls back to generated title)
    var displayTitle: String {
        title ?? "Notification"
    }
    
    /// Display body/content
    var displayBody: String {
        body ?? ""
    }
    
    /// Navigation destination from embedded data
    var navigationDestination: NotificationDestination? {
        destination?.navigationDestination
    }
    
    /// Whether this notification is tappable
    var isActionable: Bool {
        navigationDestination != nil
    }
    
    /// Relative time formatting (e.g., "2m ago", "1h ago")
    var timeAgoFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// Icon for the notification type
    var icon: String {
        switch type {
        case .dm:           return "envelope.fill"
        case .chatroom:     return "bubble.left.fill"
        case .announcement: return "megaphone.fill"
        case .event:        return "calendar"
        case .friendRequest: return "person.badge.plus"
        case .friendAccept: return "person.2.fill"
        case .mention:      return "at"
        case .guildInvite:  return "person.3.fill"
        case .none:         return "bell.fill"
        }
    }
    
    /// Accent color for the notification type
    var accentColor: Color {
        switch type {
        case .dm, .mention:                     return .blue
        case .chatroom:                         return .cyan
        case .announcement:                     return .orange
        case .event:                            return .purple
        case .friendRequest, .friendAccept:     return .green
        case .guildInvite:                      return .indigo
        case .none:                             return .gray
        }
    }
    
    /// Sender avatar URL extracted from the data payload
    var senderAvatarURL: String? {
        data["sender_avatar_url"]?.stringValue
            ?? data["from_avatar_url"]?.stringValue
            ?? data["friend_avatar_url"]?.stringValue
    }
    
    /// Whether this is a personal or guild notification
    var isPersonal: Bool {
        type?.isPersonal ?? true
    }
    
    // MARK: - Equatable
    
    static func == (lhs: RLNotificationDTO, rhs: RLNotificationDTO) -> Bool {
        lhs.id == rhs.id && lhs.isRead == rhs.isRead && lhs.viewCount == rhs.viewCount
    }
}


// MARK: - Notification List DTO

/// Maps to backend NotificationListResponse schema.
struct RLNotificationListDTO: Codable {
    let notifications: [RLNotificationDTO]
    let totalCount: Int
    let unreadCount: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}


// MARK: - Notification Stats DTO

/// Maps to backend NotificationStatsResponse schema.
/// Used for tab badges and app badge count.
struct RLNotificationStatsDTO: Codable, Equatable {
    let totalCount: Int
    let unreadCount: Int
    let personalCount: Int
    let guildCount: Int
}


// MARK: - Request DTOs

struct RLNotificationMarkReadRequest: Codable {
    let notificationIds: [UUID]
}

struct RLNotificationDeleteRequest: Codable {
    let notificationIds: [UUID]
    let softDelete: Bool
}


// MARK: - AnyCodableValue Helper

/// Simple wrapper for decoding heterogeneous JSONB values.
/// Handles string, int, double, bool, and null.
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }
}
