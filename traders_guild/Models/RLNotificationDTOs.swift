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


// MARK: - Notification Destination (App Navigation)

enum NotificationDestination: Equatable {
    /// Navigate to a user's DM chat
    case userDM(userId: UUID)
    
    /// Navigate to a guild chatroom
    case chatroom(chatroomId: UUID)
    
    /// Navigate to a symbol's chart
    case symbolChart(symbolId: UUID, ticker: String)
    
    /// Navigate to a user's profile
    case userProfile(userId: UUID)
    
    /// Navigate to a guild announcement detail
    case announcement(announcementId: UUID)

    /// Navigate to a guild event detail
    case event(eventId: UUID)

    /// Navigate to the admin reports screen
    case adminReports(guildId: UUID?, reportId: UUID?)
}

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
    case memberBanned = "member_banned"
    case memberUnbanned = "member_unbanned"
    case roleChanged = "role_changed"
    case memberKicked = "member_kicked"
    case memberMuted = "member_muted"
    case memberUnmuted = "member_unmuted"
    case memberSuspended = "member_suspended"
    case memberUnsuspended = "member_unsuspended"
    case membershipRequestSubmitted = "membership_request_submitted"
    case membershipRequestDecision = "membership_request_decision"
    case memberJoined = "member_joined"
    case markerResult = "marker_result"
    case markerLike = "marker_like"
    case markerComment = "marker_comment"
    case contentReaction = "content_reaction"
    case contentReport = "content_report"
    case reputationTierChange = "reputation_tier_change"

    /// Group for tab filtering
    var isPersonal: Bool {
        switch self {
        case .dm, .chatroom, .friendRequest, .friendAccept, .mention, .markerResult, .markerLike, .markerComment, .contentReaction, .reputationTierChange:
            return true
        case .announcement, .event, .guildInvite, .memberBanned, .memberUnbanned, .roleChanged, .memberKicked, .memberMuted, .memberUnmuted, .memberSuspended, .memberUnsuspended, .membershipRequestSubmitted, .membershipRequestDecision, .memberJoined, .contentReport:
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
    case symbolChart = "symbol_chart"
    case userProfile = "user_profile"
    case announcement = "announcement"
    case event = "event"
    case adminReports = "admin_reports"
}

// MARK: - Notification Destination

/// Maps to backend NotificationDestinationData schema.
/// Embedded in RLNotificationDTO.destination (JSONB field).
struct RLNotificationDestination: Codable, Equatable {
    let type: RLNotificationDestinationType
    let userId: UUID?
    let guildId: UUID?
    let symbolId: UUID?
    let chatroomId: UUID?
    let announcementId: UUID?
    let eventId: UUID?
    let reportId: UUID?
    
    /// Convert to the navigation enum used by NotificationNavigationManager
    var navigationDestination: NotificationDestination? {
        switch type {
        case .userDM:
            guard let userId = userId else { return nil }
            return .userDM(userId: userId)
        case .chatroom:
            guard let chatroomId = chatroomId else { return nil }
            return .chatroom(chatroomId: chatroomId)
        case .symbolChart:
            guard let symbolId = symbolId else { return nil }
            return .symbolChart(symbolId: symbolId, ticker: "")
        case .userProfile:
            guard let userId = userId else { return nil }
            return .userProfile(userId: userId)
        case .announcement:
            guard let announcementId = announcementId else { return nil }
            return .announcement(announcementId: announcementId)
        case .event:
            guard let eventId = eventId else { return nil }
            return .event(eventId: eventId)
        case .adminReports:
            return .adminReports(guildId: guildId, reportId: reportId)
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
        guard let destination else { return nil }
        switch destination.type {
        case .symbolChart:
            guard let symbolId = destination.symbolId else { return nil }
            return .symbolChart(symbolId: symbolId, ticker: stringDataValue(for: "symbol_ticker") ?? "")
        default:
            return destination.navigationDestination
        }
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
        case .dm:             return "envelope.fill"
        case .chatroom:       return "bubble.left.fill"
        case .announcement:   return "megaphone.fill"
        case .event:          return "calendar"
        case .friendRequest:  return "person.badge.plus"
        case .friendAccept:   return "person.2.fill"
        case .mention:        return "at"
        case .guildInvite:    return "person.3.fill"
        case .memberBanned:   return "nosign"
        case .memberUnbanned: return "checkmark.circle.fill"
        case .roleChanged:    return "arrow.up.arrow.down"
        case .memberKicked:   return "person.badge.minus"
        case .memberMuted:    return "speaker.slash.fill"
        case .memberUnmuted:  return "speaker.wave.2.fill"
        case .memberSuspended: return "pause.circle.fill"
        case .memberUnsuspended: return "play.circle.fill"
        case .membershipRequestSubmitted: return "person.badge.plus"
        case .membershipRequestDecision: return "checkmark.seal.fill"
        case .memberJoined: return "person.crop.circle.badge.checkmark"
        case .markerResult:   return "chart.line.uptrend.xyaxis"
        case .markerLike:     return "heart.fill"
        case .markerComment:  return "text.bubble.fill"
        case .contentReaction: return "face.smiling.fill"
        case .contentReport:  return "exclamationmark.bubble.fill"
        case .reputationTierChange: return "star.fill"
        case .none:           return "bell.fill"
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
        case .memberBanned, .memberKicked:      return .red
        case .memberUnbanned:                   return .green
        case .memberUnmuted:                    return .green
        case .roleChanged:                      return .orange
        case .memberMuted:                      return .orange
        case .memberSuspended:                  return .red
        case .memberUnsuspended:                return .green
        case .membershipRequestSubmitted:       return .indigo
        case .membershipRequestDecision:        return .blue
        case .memberJoined:                     return .green
        case .markerResult:
            return markerResultType == "stop_loss" ? AppColors.statusNegative85 : AppColors.statusPositive90
        case .markerLike:                       return .pink
        case .markerComment:                    return .orange
        case .contentReaction:                  return .teal
        case .contentReport:                    return .red
        case .reputationTierChange:             return .yellow
        case .none:                             return .gray
        }
    }

    var semanticBorderColor: Color? {
        switch type {
        case .markerResult:
            return markerResultType == "stop_loss" ? AppColors.statusNegative40 : AppColors.statusPositive35
        default:
            return nil
        }
    }

    private func stringDataValue(for key: String) -> String? {
        data[key]?.stringValue
    }

    private func uuidDataValue(for key: String) -> UUID? {
        guard let raw = stringDataValue(for: key) else { return nil }
        return UUID(uuidString: raw)
    }

    private func dateDataValue(for key: String) -> Date? {
        guard let raw = stringDataValue(for: key) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
    
    /// Sender avatar URL extracted from the data payload
    var senderAvatarURL: String? {
        let preferredKeys = [
            "sender_avatar_url",
            "from_avatar_url",
            "friend_avatar_url",
            "liked_by_avatar_url",
            "commenter_avatar_url",
            "reactor_avatar_url"
        ]

        for key in preferredKeys {
            if let value = stringDataValue(for: key) {
                return value
            }
        }

        return nil
    }
    
    /// Whether this is a guild invite notification with actionable accept/decline
    var isGuildInvite: Bool {
        type == .guildInvite
    }

    /// Guild ID extracted from data payload (for guild invite actions)
    var guildId: UUID? {
        uuidDataValue(for: "guild_id")
    }

    /// Invite ID extracted from data payload (for guild invite actions)
    var inviteId: UUID? {
        uuidDataValue(for: "invite_id")
    }

    /// Guild name extracted from data payload
    var guildName: String? {
        data["guild_name"]?.stringValue
    }

    /// Whether this is a personal or guild notification
    var isPersonal: Bool {
        type?.isPersonal ?? true
    }

    var markerResultType: String? {
        stringDataValue(for: "result_type")
    }

    var markerSharePayload: MarkerSharePayloadV1? {
        guard let markerId = uuidDataValue(for: "marker_id"),
              let symbolId = uuidDataValue(for: "symbol_id"),
              let timeframe = stringDataValue(for: "timeframe"),
              let candleTimestamp = dateDataValue(for: "candle_timestamp") else {
            return nil
        }

        return MarkerSharePayloadV1(
            markerId: markerId,
            symbolId: symbolId,
            symbolTicker: stringDataValue(for: "symbol_ticker"),
            timeframe: timeframe,
            candleTimestamp: candleTimestamp,
            markerType: stringDataValue(for: "marker_type"),
            intent: stringDataValue(for: "intent"),
            selectedEmoji: stringDataValue(for: "selected_emoji") ?? stringDataValue(for: "selectedEmoji"),
            alertSeverity: stringDataValue(for: "alert_severity") ?? stringDataValue(for: "alertSeverity")
        )
    }

    var markerNavigationPayload: MarkerSharePayloadV1? {
        if let payload = markerSharePayload {
            return payload
        }

        guard let markerId = uuidDataValue(for: "marker_id"),
              let symbolId = uuidDataValue(for: "symbol_id"),
              let timeframe = stringDataValue(for: "timeframe") else {
            return nil
        }

        return MarkerSharePayloadV1(
            markerId: markerId,
            symbolId: symbolId,
            symbolTicker: stringDataValue(for: "symbol_ticker"),
            timeframe: timeframe,
            candleTimestamp: dateDataValue(for: "candle_timestamp") ?? createdAt,
            markerType: stringDataValue(for: "marker_type"),
            intent: stringDataValue(for: "intent"),
            selectedEmoji: stringDataValue(for: "selected_emoji") ?? stringDataValue(for: "selectedEmoji"),
            alertSeverity: stringDataValue(for: "alert_severity") ?? stringDataValue(for: "alertSeverity")
        )
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

struct RLNotificationReadEventDTO: Codable, Equatable {
    let recipientId: UUID
    let notificationIds: [UUID]
    let readAt: Date
}

struct RLNotificationDeletedEventDTO: Codable, Equatable {
    let recipientId: UUID
    let notificationIds: [UUID]
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
