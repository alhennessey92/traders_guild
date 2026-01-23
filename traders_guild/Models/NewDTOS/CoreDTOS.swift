//
//  DTOs.swift
//  traders_guild
//
//  Clean DTOs that match backend Pydantic schemas EXACTLY.
//  No conversion layers, no deep nesting - just flat data that mirrors the API.
//
//  Backend snake_case -> Swift camelCase (via .convertFromSnakeCase decoder)
//
//  Created for clean rebuild - replace old GeneralDTOs.swift with this.
//

import Foundation
import SwiftUI


// ================================================================================================
// MARK: - Auth Request DTOs
// ================================================================================================

/// Matches backend RegisterRequest schema
struct RLRegisterRequestDTO: Codable {
    let email: String
    let username: String
    let displayName: String          // backend: display_name
    let password: String
}

/// Matches backend LoginRequest schema
struct RLLoginRequestDTO: Codable {
    let email: String
    let password: String
}

/// Matches backend RefreshTokenRequest schema
struct RLRefreshTokenRequestDTO: Codable {
    let refreshToken: String         // backend: refresh_token
}


// ================================================================================================
// MARK: - Auth Response DTOs
// ================================================================================================

/// Matches backend LoginResponse schema exactly
struct RLLoginResponseDTO: Codable {
    let user: RLUserDTO
    let tokens: RLTokenDTO
}

/// Matches backend RegistrationResponse schema exactly
struct RLRegistrationResponseDTO: Codable {
    let user: RLUserDTO
    let tokens: RLTokenDTO
    let defaultGuild: RLGuildDTO                       // backend: default_guild
    let defaultGuildMembership: RLGuildMembershipDTO   // backend: default_guild_membership
}


// ================================================================================================
// MARK: - Token DTO
// ================================================================================================

/// Matches backend TokenResponse schema exactly
struct RLTokenDTO: Codable, Equatable {
    let accessToken: String          // backend: access_token
    let refreshToken: String         // backend: refresh_token
    let tokenType: String            // backend: token_type
    let expiresIn: Int               // backend: expires_in (seconds)
}


// ================================================================================================
// MARK: - App State Container
// ================================================================================================

/// Combined state for the currently logged-in user's context
/// This replaces the old nested CurrentUserDTO approach
struct RLCurrentUserState: Codable, Equatable {
    var user: RLUserDTO
    var guild: RLGuildDTO
    var membership: RLGuildMembershipDTO
    
    // App-local state (not from API)
    var notificationCount: Int = 0
    var unreadMessages: Int = 0
    
    // MARK: - Computed Properties
    
    var hasUnreadItems: Bool {
        notificationCount > 0 || unreadMessages > 0
    }
    
    var totalBadgeCount: Int {
        notificationCount + unreadMessages
    }
    
    var canPostInGuild: Bool {
        membership.canModerate
    }
    
    var canManageGuild: Bool {
        membership.canAdmin
    }
    
    var isGuildOwner: Bool {
        guild.ownerId == user.id
    }
}



// ================================================================================================
// MARK: - User DTO
// ================================================================================================

/// Matches backend UserResponse schema exactly
struct RLUserDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let username: String
    let displayName: String          // backend: display_name
    let avatarUrl: String?           // backend: avatar_url
    let globalReputation: Int        // backend: global_reputation
    let isOnline: Bool               // backend: is_online
    let isVerified: Bool             // backend: is_verified
    let isSuperuser: Bool            // backend: is_superuser
    let lastSeenAt: Date?            // backend: last_seen_at
    let createdAt: Date              // backend: created_at
    let updatedAt: Date              // backend: updated_at
    let dateOfBirth: Date?           // backend: date_of_birth
    let status: String
    
    // MARK: - Computed Properties
    
    var displayUsername: String {
        "@\(username)"
    }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    var isActive: Bool {
        status == "active"
    }
}



// ================================================================================================
// MARK: - Guild DTO
// ================================================================================================

/// Matches backend GuildResponse schema exactly
/// NOTE: Returns owner_id (UUID), NOT an embedded owner object
struct RLGuildDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String?
    let imageUrl: String?            // backend: image_url
    let ownerId: UUID                // backend: owner_id (UUID, not embedded!)
    let isOpen: Bool                 // backend: is_open
    let reputation: Int
    let memberCount: Int             // backend: member_count
    let membersOnline: Int           // backend: members_online
    let status: String
    let dateCreated: Date            // backend: date_created
    let updatedAt: Date              // backend: updated_at
    
    // MARK: - Computed Properties
    
    var formattedDate: String {
        dateCreated.formatted(date: .abbreviated, time: .omitted)
    }
    
    var reputationDisplay: String {
        if reputation >= 1000 {
            return "\(reputation / 1000)k"
        }
        return "\(reputation)"
    }
    
    var memberCountDisplay: String {
        if memberCount >= 1000 {
            return "\(memberCount / 1000)k members"
        }
        return "\(memberCount) members"
    }
    
    var statusText: String {
        isOpen ? "Open" : "Closed"
    }
    
    var isActive: Bool {
        status == "active"
    }
}



// ================================================================================================
// MARK: - Guild Membership DTO
// ================================================================================================

/// Matches backend GuildMembershipResponse schema exactly
struct RLGuildMembershipDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID                 // backend: user_id
    let guildId: UUID                // backend: guild_id
    let role: String                 // backend returns string: "member", "moderator", "admin"
    let reputation: Int
    let contributionScore: Int       // backend: contribution_score
    let status: String
    let dateJoined: Date             // backend: date_joined
    
    // MARK: - Computed Properties
    
    var memberRole: RLMemberRole {
        RLMemberRole(from: role)
    }
    
    var canModerate: Bool {
        memberRole.canModerate
    }
    
    var canAdmin: Bool {
        memberRole.canAdmin
    }
    
    var daysInGuild: Int {
        Calendar.current.dateComponents([.day], from: dateJoined, to: Date()).day ?? 0
    }
    
    var memberSince: String {
        let days = daysInGuild
        if days < 7 {
            return "Member for \(days) days"
        } else if days < 30 {
            return "Member for \(days / 7) weeks"
        } else if days < 365 {
            return "Member for \(days / 30) months"
        } else {
            return "Member for \(days / 365) years"
        }
    }
}

/// Guild Simple Membership Response (for embedding in other responses)
/// Matches backend GuildSimpleMembershipResponse exactly
struct RLGuildSimpleMembershipResponse: Codable {
    let userId: UUID                         // backend: user_id
    let guildId: UUID                        // backend: guild_id
    let role: String                         // backend: role
    let reputation: Int                      // backend: reputation
    
    // Optional user display info (backend may include these)
    let userDisplayName: String?             // backend: user_display_name
    let userUsername: String?                // backend: user_username
    let userAvatarUrl: String?               // backend: user_avatar_url
    
    // Computed
    var memberRole: RLMemberRole {
        RLMemberRole(from: role)
    }
    
    // Safe accessors with fallbacks
    var displayName: String {
        userDisplayName ?? "Unknown User"
    }
    
    var username: String {
        userUsername ?? "unknown"
    }
}

/// Combined guild with membership - matches backend GuildMembershipCombinedResponse
/// Now Codable since backend returns already-combined data
struct RLGuildWithMembership: Codable, Identifiable {
    let guild: RLGuildDTO
    let membership: RLGuildMembershipDTO
    
    var id: UUID { guild.id }
    
    // MARK: - Guild Convenience Accessors
    var guildId: UUID { guild.id }
    var name: String { guild.name }
    var description: String? { guild.description }
    var imageUrl: String? { guild.imageUrl }
    var ownerId: UUID { guild.ownerId }
    var isOpen: Bool { guild.isOpen }
    var memberCount: Int { guild.memberCount }
    var membersOnline: Int { guild.membersOnline }
    var memberCountDisplay: String { guild.memberCountDisplay }
    
    // MARK: - Membership Convenience Accessors
    var membershipId: UUID { membership.id }
    var role: RLMemberRole { membership.memberRole }
    var roleString: String { membership.role }
    var reputation: Int { membership.reputation }
    var contributionScore: Int { membership.contributionScore }
    var dateJoined: Date { membership.dateJoined }
}

// ================================================================================================
// MARK: - Guild Statistics DTO
// ================================================================================================

/// Guild Statistics Response - matches backend GuildStatisticsResponse exactly
/// Fetched from: GET /guilds/{guild_id}/statistics
struct RLGuildStatisticsResponse: Codable {
    let totalPredictions: Int           // backend: total_predictions
    let correctPredictions: Int         // backend: correct_predictions
    let averageAccuracy: Double         // backend: average_accuracy (0.0 - 1.0)
    let guildRank: Int                  // backend: guild_rank
    let newMembersWeek: Int             // backend: new_members_week
    let activeMembersWeek: Int          // backend: active_members_week
    let predictionsWeek: Int            // backend: predictions_week
    let reputationEarnedWeek: Int       // backend: reputation_earned_week
    let lastCalculatedAt: Date          // backend: last_calculated_at
    
    // MARK: - Display Computed Properties (used by StatisticsView)
    
    var totalPredictionsDisplay: String {
        formatNumber(totalPredictions)
    }
    
    var correctPredictionsDisplay: String {
        formatNumber(correctPredictions)
    }
    
    var averageAccuracyDisplay: String {
        let percentage = averageAccuracy * 100
        return String(format: "%.1f%%", percentage)
    }
    
    var guildRankDisplay: String {
        guildRank == 0 ? "Unranked" : "#\(guildRank)"
    }
    
    var newMembersDisplay: String {
        "+\(newMembersWeek)"
    }
    
    var activeUsersDisplay: String {
        "\(activeMembersWeek)"
    }
    
    var predictionsMadeDisplay: String {
        formatNumber(predictionsWeek)
    }
    
    var reputationEarnedDisplay: String {
        reputationEarnedWeek >= 0 ? "+\(formatNumber(reputationEarnedWeek))" : formatNumber(reputationEarnedWeek)
    }
    
    var lastCalculatedDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastCalculatedAt, relativeTo: Date())
    }
    
    // MARK: - Helper
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
}


// ================================================================================================
// MARK: - Guild Request DTOs
// ================================================================================================

/// Request to create a new guild
struct RLCreateGuildRequestDTO: Codable {
    let name: String
    let description: String?
    let isOpen: Bool                 // backend: is_open
}



// ================================================================================================
// MARK: - Guild List Response
// ================================================================================================

/// Matches backend GuildListResponse schema - already combined data
struct RLGuildListResponseDTO: Codable {
    let guilds: [RLGuildWithMembership]
}

/// Response when creating a guild - returns both guild and membership
/// Matches backend GuildMembershipCombinedResponse
struct RLCreateGuildResponseDTO: Codable {
    let guild: RLGuildDTO
    let membership: RLGuildMembershipDTO
    
    /// Convert to combined view model for consistency
    var asGuildWithMembership: RLGuildWithMembership {
        RLGuildWithMembership(guild: guild, membership: membership)
    }
}

/// Response when joining a guild - returns both guild and membership
/// Matches backend GuildMembershipCombinedResponse
struct RLJoinGuildResponseDTO: Codable {
    let guild: RLGuildDTO
    let membership: RLGuildMembershipDTO
    
    /// Convert to combined view model for consistency
    var asGuildWithMembership: RLGuildWithMembership {
        RLGuildWithMembership(guild: guild, membership: membership)
    }
}






// ================================================================================================
// MARK: - Guild Announcements DTOs
// ================================================================================================


/// Create Guild Announcement
struct RLCreateGuildAnnouncementRequestDTO: Codable {
    let title: String
    let content: String
    let preview: String?
    let isImportant: Bool
}

/// Guild Announcement Response - matches backend GuildAnnouncementResponse exactly
struct RLGuildAnnouncementResponseDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID                    // backend: guild_id
    let authorMembershipId: UUID         // backend: author_membership_id
    let title: String
    let content: String
    let preview: String?
    let postedAt: Date                   // backend: posted_at
    let isImportant: Bool                // backend: is_important
    let readCount: Int                   // backend: read_count
    let status: String
    var isRead: Bool                     // backend: is_read (var for local cache updates)
}


/// Guild Announcement with author membership response - matches backend exactly
/// Use this directly in views (like RLGuildWithMembership)
struct RLGuildAnnouncementWithAuthorDTO: Codable, Identifiable {
    var announcement: RLGuildAnnouncementResponseDTO  // var to allow isRead mutation
    let authorMembership: RLGuildSimpleMembershipResponse
    
    var id: UUID { announcement.id }
    
    // MARK: - Convenience Accessors (like RLGuildWithMembership)
    
    // Announcement properties
    var guildId: UUID { announcement.guildId }
    var title: String { announcement.title }
    var content: String { announcement.content }
    var isImportant: Bool { announcement.isImportant }
    var postedAt: Date { announcement.postedAt }
    var readCount: Int { announcement.readCount }
    
    // Mutable for local cache updates
    var isRead: Bool {
        get { announcement.isRead }
        set { announcement.isRead = newValue }
    }
    
    var preview: String {
        announcement.preview ?? String(announcement.content.prefix(100))
    }
    
    // Author properties (with fallbacks from DTO)
    var authorDisplayName: String { authorMembership.displayName }
    var authorUsername: String { authorMembership.username }
    var authorAvatarUrl: String? { authorMembership.userAvatarUrl }
    var authorRole: RLMemberRole { authorMembership.memberRole }
    var authorReputation: Int { authorMembership.reputation }
    
    // Time formatting
    var timeAgoFormatted: String {
        let now = Date()
        let interval = now.timeIntervalSince(postedAt)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: postedAt)
        }
    }
}


/// List of Announcements with author membership response
struct RLGuildAnnouncementsListDTO: Codable {
    let announcements: [RLGuildAnnouncementWithAuthorDTO]
}


// ================================================================================================
// MARK: - Guild Events DTOs (Real API)
// ================================================================================================

/// Create Guild Event Request - matches backend GuildEventCreateRequest
struct RLCreateGuildEventRequestDTO: Codable {
    let title: String
    let content: String
    let preview: String
    let eventDate: Date           // backend: event_date
    let isImportant: Bool         // backend: is_important
}


/// Guild Event Response - matches backend GuildEventResponse exactly
struct RLGuildEventResponseDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID                    // backend: guild_id
    let authorMembershipId: UUID         // backend: author_membership_id
    let title: String
    let content: String
    let preview: String
    let eventDate: Date                  // backend: event_date
    let postedAt: Date                   // backend: posted_at
    let isImportant: Bool                // backend: is_important
    var attendeeCount: Int               // backend: attendee_count (var for local cache updates)
    var isAttending: Bool                // backend: is_attending (var for local cache updates)
    let status: String
    var isRead: Bool                     // backend: is_read (var for local cache updates)
}

/// Guild Event with author membership response - matches backend exactly
/// Use this directly in views (like RLGuildAnnouncementWithAuthorDTO)
struct RLGuildEventWithAuthorDTO: Codable, Identifiable {
    var event: RLGuildEventResponseDTO  // var to allow mutation
    let authorMembership: RLGuildSimpleMembershipResponse
    
    var id: UUID { event.id }
    
    // MARK: - Event Convenience Accessors
    var guildId: UUID { event.guildId }
    var title: String { event.title }
    var content: String { event.content }
    var preview: String { event.preview }
    var eventDate: Date { event.eventDate }
    var postedAt: Date { event.postedAt }
    var isImportant: Bool { event.isImportant }
    
    // Mutable for local cache updates
    var attendeeCount: Int {
        get { event.attendeeCount }
        set { event.attendeeCount = newValue }
    }
    
    var isAttending: Bool {
        get { event.isAttending }
        set { event.isAttending = newValue }
    }
    
    var isRead: Bool {
        get { event.isRead }
        set { event.isRead = newValue }
    }
    
    // MARK: - Author Convenience Accessors
    var author: RLGuildSimpleMembershipResponse { authorMembership }
    var authorDisplayName: String { authorMembership.displayName }
    var authorUsername: String { authorMembership.username }
    var authorAvatarUrl: String? { authorMembership.userAvatarUrl }
    var authorRole: RLMemberRole { authorMembership.memberRole }
    
    // MARK: - Computed Properties
    
    /// Check if event has already happened
    var isPastEvent: Bool {
        eventDate < Date()
    }
    
    /// User-friendly attendance display
    var attendanceDisplay: String {
        if isAttending {
            if attendeeCount == 1 {
                return "Just you"
            } else {
                return "You + \(attendeeCount - 1) others"
            }
        }
        return "\(attendeeCount) attending"
    }
    
    /// Time formatting for display
    var timeAgoFormatted: String {
        let now = Date()
        let interval = now.timeIntervalSince(postedAt)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: postedAt)
        }
    }
    
    /// Time until event for display
    var timeUntilEvent: String {
        let now = Date()
        let interval = eventDate.timeIntervalSince(now)
        
        if interval < 0 {
            return "Past event"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "in \(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "in \(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "in \(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: eventDate)
        }
    }
}

/// List of Events with author membership response
struct RLGuildEventsListDTO: Codable {
    let events: [RLGuildEventWithAuthorDTO]
}


// ================================================================================================
// MARK: - Member Role
// ================================================================================================

/// Role within a guild - matches backend role strings
enum RLMemberRole: String, Codable, CaseIterable {
    case member = "member"
    case moderator = "moderator"
    case admin = "admin"
    
    /// Initialize from backend string (case-insensitive)
    init(from string: String) {
        switch string.lowercased() {
        case "admin", "owner": self = .admin
        case "moderator", "mod": self = .moderator
        default: self = .member
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .member: return .gray
        case .moderator: return .orange
        case .admin: return .red
        }
    }
    
    var canModerate: Bool {
        self == .moderator || self == .admin
    }
    
    var canAdmin: Bool {
        self == .admin
    }
}


// ================================================================================================
// MARK: - Alert Types (App UI)
// ================================================================================================

struct RLAppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: RLAlertSeverity
    let style: RLAlertDisplayStyle
}


enum RLAlertSeverity {
    case error, warning, info, success
    
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .success: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}


enum RLAlertDisplayStyle {
    case alert
    case toast
}


// ================================================================================================
// MARK: - Signup Form Data (UI Only)
// ================================================================================================

/// Form data collected during signup flow - NOT sent directly to API
struct RLSignupData {
    var email: String = ""
    var username: String = ""
    var password: String = ""
    var name: String = ""            // Maps to displayName when creating RegisterRequestDTO
    
    /// Convert to API request format
    func toRequest() -> RLRegisterRequestDTO {
        RLRegisterRequestDTO(
            email: email,
            username: username,
            displayName: name,
            password: password
        )
    }
}

enum RLSignupStep: Hashable {
    case accountInfo
    case username
    case basics
    case guild
    
}

