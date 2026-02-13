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

    /// Create a copy with updated guild settings fields
    func withUpdatedSettings(name: String? = nil, description: String? = nil, isOpen: Bool? = nil) -> RLGuildDTO {
        RLGuildDTO(
            id: id,
            name: name ?? self.name,
            description: description ?? self.description,
            imageUrl: imageUrl,
            ownerId: ownerId,
            isOpen: isOpen ?? self.isOpen,
            reputation: reputation,
            memberCount: memberCount,
            membersOnline: membersOnline,
            status: status,
            dateCreated: dateCreated,
            updatedAt: Date()
        )
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

    /// Create a copy with an updated role
    func withRole(_ newRole: String) -> RLGuildMembershipDTO {
        RLGuildMembershipDTO(
            id: id,
            userId: userId,
            guildId: guildId,
            role: newRole,
            reputation: reputation,
            contributionScore: contributionScore,
            status: status,
            dateJoined: dateJoined
        )
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





// NEW ADDITION FOR GUILD MEMBERS AND USERS ...

// ================================================================================================
// MARK: - Guild Member DTOs (For Member Lists)
// ================================================================================================

/// Guild member with embedded user data - matches backend GuildMemberResponse
/// This combines membership data with user data in one response (no lookups needed!)
struct RLGuildMemberDTO: Codable, Identifiable, Equatable, Hashable {
    // Membership data
    let membershipId: UUID              // backend: membership_id
    let role: String
    let reputation: Int
    let contributionScore: Int          // backend: contribution_score
    let dateJoined: Date                // backend: date_joined

    // Moderation data
    let mutedUntil: Date?               // backend: muted_until
    let suspendedUntil: Date?           // backend: suspended_until

    // User data (embedded - no lookup!)
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let isOnline: Bool                  // backend: is_online
    let globalReputation: Int           // backend: global_reputation

    // Relationship to current user (personalized per request)
    let isFriend: Bool                  // backend: is_friend
    let friendshipStatus: String?       // backend: friendship_status (none, pending_sent, pending_received, accepted)
    let isBlocked: Bool                 // backend: is_blocked
    let isBlockedBy: Bool               // backend: is_blocked_by

    var id: UUID { membershipId }

    // MARK: - Computed Properties

    var memberRole: RLMemberRole {
        RLMemberRole(from: role)
    }

    var isMuted: Bool {
        guard let mutedUntil = mutedUntil else { return false }
        return mutedUntil > Date()
    }

    var isSuspended: Bool {
        guard let suspendedUntil = suspendedUntil else { return false }
        return suspendedUntil > Date()
    }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    var daysInGuild: Int {
        Calendar.current.dateComponents([.day], from: dateJoined, to: Date()).day ?? 0
    }
    
    var memberSince: String {
        let days = daysInGuild
        if days < 7 { return "Member for \(days) days" }
        else if days < 30 { return "Member for \(days / 7) weeks" }
        else if days < 365 { return "Member for \(days / 30) months" }
        else { return "Member for \(days / 365) years" }
    }
    
    var displayUsername: String {
        "@\(username)"
    }

    func withOnlineStatus(_ isOnline: Bool) -> RLGuildMemberDTO {
        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self)
        ) as? [String: Any] else {
            return self
        }
        dict["isOnline"] = isOnline
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLGuildMemberDTO.self, from: data) else {
            return self
        }
        return updated
    }

    func withRole(_ newRole: String) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: membershipId,
            role: newRole,
            reputation: reputation,
            contributionScore: contributionScore,
            dateJoined: dateJoined,
            mutedUntil: mutedUntil,
            suspendedUntil: suspendedUntil,
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isOnline: isOnline,
            globalReputation: globalReputation,
            isFriend: isFriend,
            friendshipStatus: friendshipStatus,
            isBlocked: isBlocked,
            isBlockedBy: isBlockedBy
        )
    }
    
    /// Friendship status display text
    var friendshipStatusDisplay: String {
        switch friendshipStatus {
        case "accepted": return "Friends"
        case "pending_sent": return "Request Sent"
        case "pending_received": return "Request Received"
        default: return "Not Friends"
        }
    }
    
    /// Whether a friend action button should be shown
    var canSendFriendRequest: Bool {
        !isFriend && friendshipStatus == nil && !isBlocked && !isBlockedBy
    }
    
    /// Whether to show "Accept/Decline" buttons
    var hasPendingIncomingRequest: Bool {
        friendshipStatus == "pending_received"
    }
    
    /// Whether to show "Cancel Request" option
    var hasPendingOutgoingRequest: Bool {
        friendshipStatus == "pending_sent"
    }
}

/// Guild members list response - matches backend GuildMembersListResponse
struct RLGuildMembersListDTO: Codable {
    let members: [RLGuildMemberDTO]
    let totalCount: Int                 // backend: total_count
    let onlineCount: Int                // backend: online_count
}



// ================================================================================================
// MARK: - User Extended Profile DTOs
// ================================================================================================

/// Social link item - matches backend SocialLinkItem
struct RLSocialLinkItem: Codable, Identifiable, Equatable, Hashable {
    var id: String { platform + username }
    
    let platform: String                // twitter, discord, telegram, tradingview, youtube
    let username: String
    let url: String?
    
    var icon: String {
        switch platform.lowercased() {
        case "twitter", "x": return "bird"
        case "discord": return "bubble.left.and.bubble.right"
        case "telegram": return "paperplane.fill"
        case "tradingview": return "chart.xyaxis.line"
        case "youtube": return "play.rectangle.fill"
        default: return "link"
        }
    }
    
    var color: Color {
        switch platform.lowercased() {
        case "twitter", "x": return .blue
        case "discord": return .indigo
        case "telegram": return .cyan
        case "tradingview": return .orange
        case "youtube": return .red
        default: return .gray
        }
    }
    
    var displayName: String {
        platform.capitalized
    }
}

/// Trading interest item - matches backend TradingInterestItem
struct RLTradingInterestItem: Codable, Identifiable, Equatable, Hashable {
    var id: String { name }
    
    let name: String                    // Forex, Crypto, Stocks, etc.
    let icon: String                    // SF Symbol name
    let isPrimary: Bool                 // backend: is_primary
}

/// User extended profile - matches backend UserProfileResponse
struct RLUserProfileDTO: Codable, Equatable {
    let userId: UUID                    // backend: user_id
    let bio: String?
    let location: String?
    let timezone: String?
    let experienceLevel: String         // backend: experience_level
    let tradingStyle: String?           // backend: trading_style
    let preferredPairs: [String]        // backend: preferred_pairs
    let socialLinks: [RLSocialLinkItem] // backend: social_links
    let tradingInterests: [RLTradingInterestItem] // backend: trading_interests
    let isProfilePublic: Bool           // backend: is_profile_public
    let showOnlineStatus: Bool          // backend: show_online_status
    let createdAt: Date                 // backend: created_at
    let updatedAt: Date                 // backend: updated_at
    
    var experienceLevelDisplay: String {
        experienceLevel.capitalized
    }
    
    var experienceColor: Color {
        switch experienceLevel.lowercased() {
        case "beginner": return .gray
        case "intermediate": return .blue
        case "advanced": return .green
        case "expert": return .purple
        case "professional": return .orange
        default: return .gray
        }
    }
    
    var primaryInterest: RLTradingInterestItem? {
        tradingInterests.first { $0.isPrimary } ?? tradingInterests.first
    }
    
    var hasCompletedProfile: Bool {
        bio != nil || location != nil || !tradingInterests.isEmpty
    }
}

/// Update user profile request - matches backend UserProfileUpdateRequest
struct RLUserProfileUpdateRequest: Codable {
    var bio: String?
    var location: String?
    var timezone: String?
    var experienceLevel: String?        // backend: experience_level
    var tradingStyle: String?           // backend: trading_style
    var preferredPairs: [String]?       // backend: preferred_pairs
    var socialLinks: [RLSocialLinkItem]? // backend: social_links
    var tradingInterests: [RLTradingInterestItem]? // backend: trading_interests
    var isProfilePublic: Bool?          // backend: is_profile_public
    var showOnlineStatus: Bool?         // backend: show_online_status
    
    init(
        bio: String? = nil,
        location: String? = nil,
        timezone: String? = nil,
        experienceLevel: String? = nil,
        tradingStyle: String? = nil,
        preferredPairs: [String]? = nil,
        socialLinks: [RLSocialLinkItem]? = nil,
        tradingInterests: [RLTradingInterestItem]? = nil,
        isProfilePublic: Bool? = nil,
        showOnlineStatus: Bool? = nil
    ) {
        self.bio = bio
        self.location = location
        self.timezone = timezone
        self.experienceLevel = experienceLevel
        self.tradingStyle = tradingStyle
        self.preferredPairs = preferredPairs
        self.socialLinks = socialLinks
        self.tradingInterests = tradingInterests
        self.isProfilePublic = isProfilePublic
        self.showOnlineStatus = showOnlineStatus
    }
}



// ================================================================================================
// MARK: - User Statistics DTO
// ================================================================================================

/// User global statistics - matches backend UserGlobalStatisticsResponse
struct RLUserGlobalStatisticsDTO: Codable, Equatable {
    let userId: UUID                    // backend: user_id
    let totalMarkersPlaced: Int         // backend: total_markers_placed
    let successfulMarkers: Int          // backend: successful_markers
    let accuracyRate: Double            // backend: accuracy_rate (0.0 to 1.0)
    let totalLikesReceived: Int         // backend: total_likes_received
    let totalCommentsMade: Int          // backend: total_comments_made
    let currentStreakDays: Int          // backend: current_streak_days
    let bestStreakDays: Int             // backend: best_streak_days
    let totalGuildsJoined: Int          // backend: total_guilds_joined
    let totalAwardsEarned: Int          // backend: total_awards_earned
    let totalAwardPoints: Int           // backend: total_award_points
    let topSymbols: [String]            // backend: top_symbols
    let markersByType: [String: Int]    // backend: markers_by_type
    let lastCalculatedAt: Date          // backend: last_calculated_at
    
    var accuracyFormatted: String {
        String(format: "%.1f%%", accuracyRate * 100)
    }
    
    var accuracyColor: Color {
        if accuracyRate >= 0.7 { return .green }
        else if accuracyRate >= 0.5 { return .orange }
        else { return .red }
    }
    
    var failedMarkers: Int {
        totalMarkersPlaced - successfulMarkers
    }
    
    var streakEmoji: String {
        if currentStreakDays >= 30 { return "🔥" }
        else if currentStreakDays >= 7 { return "⚡" }
        else if currentStreakDays >= 3 { return "✨" }
        else { return "" }
    }
}



// ================================================================================================
// MARK: - Award DTOs
// ================================================================================================


/// Award type/definition - matches backend AwardTypeResponse
struct RLAwardTypeDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let category: String
    let rarity: String
    let pointsValue: Int                // backend: points_value
    let requiredValue: Int?             // backend: required_value
    
    var categoryEnum: RLAwardCategory {
        RLAwardCategory(rawValue: category) ?? .special
    }
    
    var rarityEnum: RLAwardRarity {
        RLAwardRarity(rawValue: rarity) ?? .common
    }
}

/// User's earned award - matches backend UserAwardResponse
struct RLUserAwardDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let membershipId: UUID              // backend: membership_id
    let guildId: UUID                   // backend: guild_id
    let awardTypeId: UUID               // backend: award_type_id
    let name: String                    // From award_type
    let description: String             // From award_type
    let icon: String                    // From award_type
    let category: String                // From award_type
    let rarity: String                  // From award_type
    let pointsValue: Int                // backend: points_value
    let progress: Double?               // 0.0-1.0, nil if complete
    let currentValue: Int?              // backend: current_value
    let isNew: Bool                     // backend: is_new
    let earnedAt: Date                  // backend: earned_at
    
    var categoryEnum: RLAwardCategory {
        RLAwardCategory(rawValue: category) ?? .special
    }
    
    var rarityEnum: RLAwardRarity {
        RLAwardRarity(rawValue: rarity) ?? .common
    }
    
    var isEarned: Bool {
        progress == nil || (progress ?? 0) >= 1.0
    }
    
    var progressPercentage: Int {
        guard let progress = progress else { return 100 }
        return Int(progress * 100)
    }
    
    var earnedAtFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: earnedAt)
    }
    
    var progressDisplay: String {
        guard let progress = progress, let currentValue = currentValue else {
            return "Completed"
        }
        return "\(currentValue) (\(Int(progress * 100))%)"
    }
}

/// Awards summary - matches backend AwardsSummaryResponse
struct RLAwardsSummaryDTO: Codable, Equatable {
    let totalAwards: Int                // backend: total_awards
    let totalPoints: Int                // backend: total_points
    let rarityBreakdown: [String: Int]  // backend: rarity_breakdown
    let recentAwards: [RLUserAwardDTO]  // backend: recent_awards
    
    var pointsFormatted: String {
        if totalPoints >= 1000 {
            return String(format: "%.1fk", Double(totalPoints) / 1000)
        }
        return "\(totalPoints)"
    }
    
    func count(for rarity: RLAwardRarity) -> Int {
        rarityBreakdown[rarity.rawValue] ?? 0
    }
}

/// User awards list - matches backend UserAwardsListResponse
struct RLUserAwardsListDTO: Codable {
    let awards: [RLUserAwardDTO]
}



// ================================================================================================
// MARK: - Friend DTOs
// ================================================================================================

/// Friend in friends list - matches backend FriendResponse
struct RLFriendDTO: Codable, Identifiable, Equatable, Hashable {
    let friendshipId: UUID              // backend: friendship_id
    let membershipId: UUID              // backend: membership_id
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let isOnline: Bool                  // backend: is_online
    let globalReputation: Int           // backend: global_reputation
    let friendsSince: Date              // backend: friends_since
    
    var id: UUID { friendshipId }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    var displayUsername: String {
        "@\(username)"
    }
    
    var friendsSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: friendsSince)
    }
    
    var friendsDuration: String {
        let days = Calendar.current.dateComponents([.day], from: friendsSince, to: Date()).day ?? 0
        if days < 7 { return "\(days) days" }
        else if days < 30 { return "\(days / 7) weeks" }
        else if days < 365 { return "\(days / 30) months" }
        else { return "\(days / 365) years" }
    }

    func withOnlineStatus(_ isOnline: Bool) -> RLFriendDTO {
        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self)
        ) as? [String: Any] else {
            return self
        }
        dict["isOnline"] = isOnline
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLFriendDTO.self, from: data) else {
            return self
        }
        return updated
    }
}

/// Incoming friend request - matches backend FriendRequestIncomingResponse
struct RLFriendRequestIncomingDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let fromMembershipId: UUID          // backend: from_membership_id
    let fromUserId: UUID                // backend: from_user_id
    let fromUsername: String            // backend: from_username
    let fromDisplayName: String         // backend: from_display_name
    let fromAvatarUrl: String?          // backend: from_avatar_url
    let message: String?
    let createdAt: Date                 // backend: created_at
    
    var initials: String {
        let parts = fromDisplayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(fromDisplayName.prefix(2)).uppercased()
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// Outgoing friend request - matches backend FriendRequestOutgoingResponse
struct RLFriendRequestOutgoingDTO: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let toMembershipId: UUID            // backend: to_membership_id
    let toUserId: UUID                  // backend: to_user_id
    let toUsername: String              // backend: to_username
    let toDisplayName: String           // backend: to_display_name
    let toAvatarUrl: String?            // backend: to_avatar_url
    let message: String?
    let createdAt: Date                 // backend: created_at
    
    var initials: String {
        let parts = toDisplayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(toDisplayName.prefix(2)).uppercased()
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// Friends list response - matches backend FriendsListResponse
struct RLFriendsListDTO: Codable {
    let friends: [RLFriendDTO]
    let totalCount: Int                 // backend: total_count
    let onlineCount: Int                // backend: online_count
    
    var offlineCount: Int {
        totalCount - onlineCount
    }
}

/// Friend requests list response - matches backend FriendRequestsListResponse
struct RLFriendRequestsListDTO: Codable {
    let incoming: [RLFriendRequestIncomingDTO]
    let outgoing: [RLFriendRequestOutgoingDTO]
    
    var totalPendingCount: Int {
        incoming.count + outgoing.count
    }
    
    var hasIncoming: Bool {
        !incoming.isEmpty
    }
}

/// Send friend request - matches backend FriendRequestCreateRequest
struct RLFriendRequestCreateRequest: Codable {
    let toMembershipId: UUID            // backend: to_membership_id
    let message: String?
    
    init(toMembershipId: UUID, message: String? = nil) {
        self.toMembershipId = toMembershipId
        self.message = message
    }
}

/// Friendship response - matches backend FriendshipResponse
struct RLFriendshipResponseDTO: Codable, Identifiable {
    let id: UUID
    let requesterMembershipId: UUID     // backend: requester_membership_id
    let addresseeMembershipId: UUID     // backend: addressee_membership_id
    let status: String
    let message: String?
    let createdAt: Date                 // backend: created_at
    let updatedAt: Date                 // backend: updated_at
    
    var isAccepted: Bool {
        status == "accepted"
    }
    
    var isPending: Bool {
        status == "pending"
    }
}



// ================================================================================================
// MARK: - Block DTOs
// ================================================================================================

/// Blocked user in list - matches backend BlockedUserResponse
struct RLBlockedUserDTO: Codable, Identifiable, Equatable, Hashable {
    let blockId: UUID                   // backend: block_id
    let membershipId: UUID              // backend: membership_id
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let blockedAt: Date                 // backend: blocked_at
    
    var id: UUID { blockId }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    var blockedAtFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: blockedAt)
    }
}

/// Blocked users list response - matches backend BlockedUsersListResponse
struct RLBlockedUsersListDTO: Codable {
    let blockedUsers: [RLBlockedUserDTO] // backend: blocked_users
    let totalCount: Int                  // backend: total_count
}



// ================================================================================================
// MARK: - Full User Profile DTO
// ================================================================================================

/// Complete user profile - matches backend UserFullProfileResponse
struct RLUserFullProfileDTO: Codable, Equatable {
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let globalReputation: Int           // backend: global_reputation
    let isOnline: Bool                  // backend: is_online
    let isVerified: Bool                // backend: is_verified
    let createdAt: Date                 // backend: created_at
    
    // Extended profile (optional - may be nil if private)
    let profile: RLUserProfileDTO?
    
    // Statistics (optional)
    let statistics: RLUserGlobalStatisticsDTO?
    
    // Awards summary (optional)
    let awardsSummary: RLAwardsSummaryDTO?  // backend: awards_summary
    
    // Relationship to current user (for viewing other profiles)
    let isFriend: Bool                  // backend: is_friend
    let friendshipStatus: String?       // backend: friendship_status
    let isBlocked: Bool                 // backend: is_blocked
    let isBlockedBy: Bool               // backend: is_blocked_by
    
    // Guild context (if viewing within a guild)
    let guildMembership: RLGuildMemberDTO?  // backend: guild_membership
    
    // MARK: - Computed Properties
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    var displayUsername: String {
        "@\(username)"
    }
    
    var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: createdAt)
    }
    
    var daysOnPlatform: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
    
    /// Whether current user can send a friend request to this user
    var canSendFriendRequest: Bool {
        !isFriend && friendshipStatus == nil && !isBlocked && !isBlockedBy
    }
    
    /// Whether there's a pending incoming request from this user
    var hasPendingIncomingRequest: Bool {
        friendshipStatus == "pending_received"
    }
    
    /// Whether current user has sent a pending request to this user
    var hasPendingOutgoingRequest: Bool {
        friendshipStatus == "pending_sent"
    }
}



// ================================================================================================
// MARK: - Simple Response DTOs
// ================================================================================================

/// Generic detail response for simple operations
struct RLDetailResponseDTO: Codable {
    let detail: String
}



// ================================================================================================
// MARK: - Member Role
// ================================================================================================

/// Role within a guild - matches backend role strings
enum RLMemberRole: String, Codable, CaseIterable {
    case member = "member"
    case moderator = "moderator"
    case admin = "admin"
    case owner = "owner"

    /// Initialize from backend string (case-insensitive)
    init(from string: String) {
        switch string.lowercased() {
        case "owner": self = .owner
        case "admin": self = .admin
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
        case .owner: return .yellow
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "star.fill"
        case .moderator: return "shield.fill"
        case .member: return "person.fill"
        }
    }

    var canModerate: Bool {
        self == .moderator || self == .admin || self == .owner
    }

    var canAdmin: Bool {
        self == .admin || self == .owner
    }

    var isOwner: Bool {
        self == .owner
    }

    var canManageMembers: Bool {
        self == .admin || self == .owner
    }
}


// ================================================================================================
// MARK: - Admin Panel DTOs
// ================================================================================================

/// Request DTO for updating guild settings
struct RLUpdateGuildRequestDTO: Codable {
    let name: String?
    let description: String?
    let isOpen: Bool?
}

/// Guild invitation response DTO
struct RLGuildInvitationDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID
    let invitedUserId: UUID
    let invitedByUserId: UUID
    let invitedUsername: String
    let invitedDisplayName: String
    let invitedAvatarUrl: String?
    let invitedByDisplayName: String
    let status: String
    let createdAt: Date
}

/// List of guild invitations
struct RLGuildInvitationsListDTO: Codable {
    let invitations: [RLGuildInvitationDTO]
}

/// User search result for invite
struct RLUserSearchResultDTO: Codable, Identifiable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isMember: Bool
    let hasPendingInvite: Bool

    var id: UUID { userId }
}

/// List of user search results
struct RLUserSearchResultsDTO: Codable {
    let users: [RLUserSearchResultDTO]
}

/// Request DTO for banning a member
struct RLGuildBanRequestDTO: Codable {
    let reason: String?
}

/// Guild ban response DTO
struct RLGuildBanDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID
    let bannedUserId: UUID
    let bannedUsername: String
    let bannedDisplayName: String
    let bannedAvatarUrl: String?
    let bannedByDisplayName: String
    let reason: String?
    let bannedAt: Date
}

/// List of guild bans
struct RLGuildBansListDTO: Codable {
    let bans: [RLGuildBanDTO]
}

/// Request DTO for changing a member's role
struct RLGuildRoleChangeRequestDTO: Codable {
    let role: String
}

/// Response DTO after changing a member's role
struct RLGuildMemberRoleResponseDTO: Codable {
    let userId: UUID
    let membershipId: UUID
    let oldRole: String
    let newRole: String
}

/// Request DTO for muting a member
struct RLGuildMuteRequestDTO: Codable {
    let durationMinutes: Int
    let reason: String?
}

/// Request DTO for suspending a member
struct RLGuildSuspendRequestDTO: Codable {
    let durationMinutes: Int
    let reason: String?
}

/// Response DTO after performing a moderation action (mute/unmute/suspend/unsuspend)
struct RLGuildMemberActionResponseDTO: Codable {
    let userId: UUID
    let membershipId: UUID
    let action: String  // "muted", "unmuted", "suspended", "unsuspended"
    let until: Date?
    let reason: String?
}


// ================================================================================================
// MARK: - Content Reports DTOs
// ================================================================================================

/// Request to report content
struct RLContentReportRequestDTO: Codable {
    let reason: String
    let details: String?
}

/// Single content report response
struct RLContentReportDTO: Codable, Identifiable {
    let id: UUID
    let reporterId: UUID
    let reporterUsername: String?
    let reporterDisplayName: String?
    let contentType: String
    let contentId: UUID
    let guildId: UUID?
    let reason: String
    let details: String?
    let status: String
    let reviewedBy: UUID?
    let reviewerDisplayName: String?
    let reviewedAt: Date?
    let resolutionNote: String?
    let createdAt: Date

    var isPending: Bool { status == "pending" }
    var isResolved: Bool { status == "resolved" }
    var isDismissed: Bool { status == "dismissed" }

    var contentTypeDisplay: String {
        switch contentType {
        case "user": return "User"
        case "chatroom_message": return "Chat Message"
        case "dm_message": return "DM Message"
        case "chart_chat_message": return "Chart Chat"
        case "marker_comment": return "Marker Comment"
        case "chart_marker": return "Marker"
        default: return contentType.capitalized
        }
    }

    var contentTypeIcon: String {
        switch contentType {
        case "user": return "person.fill"
        case "chatroom_message", "dm_message", "chart_chat_message": return "bubble.left.fill"
        case "marker_comment": return "text.bubble.fill"
        case "chart_marker": return "mappin.circle.fill"
        default: return "doc.fill"
        }
    }

    var reasonDisplay: String {
        switch reason {
        case "spam": return "Spam"
        case "harassment": return "Harassment"
        case "hate_speech": return "Hate Speech"
        case "inappropriate": return "Inappropriate"
        case "misinformation": return "Misinformation"
        case "other": return "Other"
        default: return reason.capitalized
        }
    }

    var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "resolved": return .green
        case "dismissed": return .gray
        default: return .secondary
        }
    }
}

/// List of content reports
struct RLContentReportsListDTO: Codable {
    let reports: [RLContentReportDTO]
    let totalCount: Int
    let pendingCount: Int
}

/// Request to resolve or dismiss a report
struct RLResolveReportRequestDTO: Codable {
    let action: String  // "resolved" or "dismissed"
    let resolutionNote: String?
}



// ================================================================================================
// MARK: - Award TYPES
// ================================================================================================

/// Award category enum
enum RLAwardCategory: String, Codable, CaseIterable {
    case trading = "trading"
    case community = "community"
    case milestones = "milestones"
    case special = "special"
    
    var displayName: String { rawValue.capitalized }
    
    var color: Color {
        switch self {
        case .trading: return .green
        case .community: return .blue
        case .milestones: return .orange
        case .special: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .trading: return "chart.line.uptrend.xyaxis"
        case .community: return "person.3.fill"
        case .milestones: return "flag.fill"
        case .special: return "sparkles"
        }
    }
}

/// Award rarity enum
enum RLAwardRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String { rawValue.capitalized }
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var glowColor: Color {
        switch self {
        case .common: return .clear
        case .uncommon: return .green.opacity(0.3)
        case .rare: return .blue.opacity(0.4)
        case .epic: return .purple.opacity(0.5)
        case .legendary: return .orange.opacity(0.6)
        }
    }
    
    var pointValue: Int {
        switch self {
        case .common: return 10
        case .uncommon: return 25
        case .rare: return 50
        case .epic: return 100
        case .legendary: return 250
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .legendary: return 0
        case .epic: return 1
        case .rare: return 2
        case .uncommon: return 3
        case .common: return 4
        }
    }
}


// ================================================================================================
// MARK: - Account Management Request DTOs
// ================================================================================================

struct RLBasicUserUpdateRequest: Codable {
    var displayName: String?
    var username: String?
}

struct RLEmailChangeRequest: Codable {
    let newEmail: String
    let currentPassword: String
}

struct RLPasswordChangeRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

struct RLDOBUpdateRequest: Codable {
    let dateOfBirth: Date
}

struct RLDeleteAccountRequest: Codable {
    let password: String
    let confirmation: String
}

// MARK: - User Settings DTOs

struct RLUserSettingsDTO: Codable {
    let showOnlineStatus: Bool
    let allowFriendRequests: Bool
    let activityVisible: Bool
    let analyticsEnabled: Bool
    let personalizedContentEnabled: Bool
}

struct RLUserSettingsUpdateRequest: Codable {
    let showOnlineStatus: Bool?
    let allowFriendRequests: Bool?
    let activityVisible: Bool?
    let analyticsEnabled: Bool?
    let personalizedContentEnabled: Bool?
}

// MARK: - Support Request DTOs

struct RLSupportTicketRequest: Codable {
    let category: String
    let subject: String
    let message: String
    let includeDeviceInfo: Bool
    let deviceInfo: [String: String]?
}

// MARK: - Reporting & Sharing Requests

struct RLChatroomReportRequest: Codable {
    let reason: String
}

struct RLUserReportRequest: Codable {
    let reason: String
}

struct RLContentReportRequest: Codable {
    let reason: String
    let details: String?

    init(reason: String, details: String? = nil) {
        self.reason = reason
        self.details = details
    }
}

struct RLShareEventRequest: Codable {
    let friendId: UUID
}

// MARK: - Activity Feed DTOs

struct RLActivityItem: Codable, Identifiable {
    let id: UUID
    let type: String
    let title: String
    let description: String
    let timestamp: Date
    let guildId: UUID?
    let guildName: String?
}

struct RLActivityFeedResponse: Codable {
    let items: [RLActivityItem]
    let hasMore: Bool
}

// MARK: - Avatar Response

struct RLAvatarUpdateResponse: Codable {
    let avatarUrl: String
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

