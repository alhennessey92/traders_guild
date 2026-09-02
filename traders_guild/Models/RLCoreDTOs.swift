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
    let language: String?
    let location: String?
}

struct RLEmailAvailabilityRequestDTO: Codable {
    let email: String
}

struct RLUsernameAvailabilityRequestDTO: Codable {
    let username: String
}

/// Matches backend LoginRequest schema
struct RLLoginRequestDTO: Codable {
    let identifier: String
    let password: String

    init(identifier: String, password: String) {
        self.identifier = identifier
        self.password = password
    }

    // Backward-compatible convenience for old call sites.
    init(email: String, password: String) {
        self.identifier = email
        self.password = password
    }
}

/// Matches backend RefreshTokenRequest schema
struct RLRefreshTokenRequestDTO: Codable {
    let refreshToken: String         // backend: refresh_token
}

/// Matches backend PasswordForgotRequest schema
struct RLPasswordForgotRequestDTO: Codable {
    let identifier: String
}

/// Matches backend PasswordResetRequest schema
struct RLPasswordResetRequestDTO: Codable {
    let token: String
    let newPassword: String          // backend: new_password
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
    let defaultGuild: RLGuildDTO?                      // backend: default_guild
    let defaultGuildMembership: RLGuildMembershipDTO?  // backend: default_guild_membership
}

struct RLFieldAvailabilityResponseDTO: Codable {
    let available: Bool
    let detail: String
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

/// Matches backend PasswordForgotResponse schema
struct RLPasswordForgotResponseDTO: Codable {
    let detail: String
}

/// Matches backend PasswordResetVerifyResponse schema
struct RLPasswordResetVerifyResponseDTO: Codable {
    let valid: Bool
    let detail: String
}

/// Matches backend PasswordResetResponse schema
struct RLPasswordResetResponseDTO: Codable {
    let detail: String
}

/// Apple Sign In request DTO — sent to POST /auth/apple
struct RLAppleSignInRequestDTO: Codable {
    let identityToken: String        // backend: identity_token
    let authorizationCode: String    // backend: authorization_code
    let fullName: String?            // backend: full_name
    let email: String?               // backend: email
}

/// Apple Sign In response DTO — returned from POST /auth/apple
/// Extends login response with new-user indicator for onboarding routing.
struct RLAppleSignInResponseDTO: Codable {
    let user: RLUserDTO
    let tokens: RLTokenDTO
    let isNewUser: Bool?             // backend: is_new_user (nil until backend sends it)
    let onboardingState: String?     // backend: onboarding_state (e.g. "account_created", "onboarding_complete")
}

/// Email verification request DTO — sent to POST /auth/email/verify
struct RLEmailVerifyRequestDTO: Codable {
    let token: String
}

/// Matches backend EmailVerifyResponse schema
struct RLEmailVerifyResponseDTO: Codable {
    let detail: String
    let verified: Bool
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
    /// Backend `auth_provider`: e.g. `email`, `apple`. Absent in older payloads → treated as email.
    let authProvider: String?

    // MARK: - Computed Properties

    /// Account uses email/password (vs Sign in with Apple, etc.).
    var usesEmailPasswordAuth: Bool {
        (authProvider ?? "email").lowercased() == "email"
    }
    
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

    func withGlobalReputation(_ newGlobalReputation: Int) -> RLUserDTO {
        RLUserDTO(
            id: id,
            email: email,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            globalReputation: newGlobalReputation,
            isOnline: isOnline,
            isVerified: isVerified,
            isSuperuser: isSuperuser,
            lastSeenAt: lastSeenAt,
            createdAt: createdAt,
            updatedAt: Date(),
            dateOfBirth: dateOfBirth,
            status: status,
            authProvider: authProvider
        )
    }

    func withAvatarUrl(_ newAvatarUrl: String?) -> RLUserDTO {
        RLUserDTO(
            id: id,
            email: email,
            username: username,
            displayName: displayName,
            avatarUrl: newAvatarUrl,
            globalReputation: globalReputation,
            isOnline: isOnline,
            isVerified: isVerified,
            isSuperuser: isSuperuser,
            lastSeenAt: lastSeenAt,
            createdAt: createdAt,
            updatedAt: Date(),
            dateOfBirth: dateOfBirth,
            status: status,
            authProvider: authProvider
        )
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
    let slug: String?                // backend: slug (vanity handle for share URLs)
    let description: String?
    let imageUrl: String?            // backend: image_url
    let ownerId: UUID                // backend: owner_id (UUID, not embedded!)
    let isOpen: Bool                 // backend: is_open
    let isOnboardingSystemGuild: Bool?   // backend: is_onboarding_system_guild
    let reputation: Int
    let memberCount: Int             // backend: member_count
    let membersOnline: Int           // backend: members_online
    let ownerDisplayName: String?    // backend: owner_display_name
    let ownerUsername: String?       // backend: owner_username
    let ownerAvatarUrl: String?      // backend: owner_avatar_url
    let language: String?            // backend: language
    let location: String?            // backend: location
    let status: String
    let dateCreated: Date            // backend: date_created
    let updatedAt: Date              // backend: updated_at
    let crestSymbol: String?         // backend: crest_symbol (neutral key, nil → "checkered")
    let crestColor: String?          // backend: crest_color (palette key, nil → "brand")
    // Wide header artwork for the guild page. Optional: a guild without one
    // renders a gradient derived from its crest colour, so nil is a permanent
    // valid state rather than missing data.
    let bannerUrl: String?           // backend: banner_url
    /// Whether this guild publishes its accuracy standings at
    /// tradersguild.co/g/{slug}/leaderboard. Optional so the app decodes
    /// against a server that predates the public page.
    let publicLeaderboard: Bool?     // backend: public_leaderboard

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

    /// Whether this is a system/onboarding guild (new users start here).
    var isSystemGuild: Bool {
        isOnboardingSystemGuild == true
    }

    /// The guild's permanent public address (vanity handle), suitable for
    /// sharing on X / Discord. Falls back to nil if no slug is set.
    var shareURL: URL? {
        guard let slug, !slug.isEmpty else { return nil }
        return URL(string: "https://tradersguild.co/g/\(slug)")
    }

    /// Create a copy with updated guild settings fields
    func withUpdatedSettings(
        name: String? = nil,
        description: String? = nil,
        isOpen: Bool? = nil,
        language: String? = nil,
        location: String? = nil
    ) -> RLGuildDTO {
        RLGuildDTO(
            id: id,
            name: name ?? self.name,
            slug: slug,
            description: description ?? self.description,
            imageUrl: imageUrl,
            ownerId: ownerId,
            isOpen: isOpen ?? self.isOpen,
            isOnboardingSystemGuild: isOnboardingSystemGuild,
            reputation: reputation,
            memberCount: memberCount,
            membersOnline: membersOnline,
            ownerDisplayName: ownerDisplayName,
            ownerUsername: ownerUsername,
            ownerAvatarUrl: ownerAvatarUrl,
            language: language ?? self.language,
            location: location ?? self.location,
            status: status,
            dateCreated: dateCreated,
            updatedAt: Date(),
            crestSymbol: crestSymbol,
            crestColor: crestColor,
            bannerUrl: bannerUrl,
            publicLeaderboard: publicLeaderboard
        )
    }

    func withReputation(_ newReputation: Int) -> RLGuildDTO {
        RLGuildDTO(
            id: id,
            name: name,
            slug: slug,
            description: description,
            imageUrl: imageUrl,
            ownerId: ownerId,
            isOpen: isOpen,
            isOnboardingSystemGuild: isOnboardingSystemGuild,
            reputation: newReputation,
            memberCount: memberCount,
            membersOnline: membersOnline,
            ownerDisplayName: ownerDisplayName,
            ownerUsername: ownerUsername,
            ownerAvatarUrl: ownerAvatarUrl,
            language: language,
            location: location,
            status: status,
            dateCreated: dateCreated,
            updatedAt: Date(),
            crestSymbol: crestSymbol,
            crestColor: crestColor,
            bannerUrl: bannerUrl,
            publicLeaderboard: publicLeaderboard
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
    let accuracyRate: Double?        // backend: accuracy_rate (trading accuracy 0.0–1.0)
    
    // MARK: - Computed Properties
    
    /// Accuracy as percentage string (e.g. "72%"), or nil if no accuracy data
    var accuracyFormatted: String? {
        guard let rate = accuracyRate else { return nil }
        return "\(Int(rate * 100))%"
    }
    
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
            dateJoined: dateJoined,
            accuracyRate: accuracyRate
        )
    }

    /// Create a copy with updated reputation (and optionally accuracy) from reputation-service.
    func withReputation(_ newReputation: Int, accuracyRate newAccuracyRate: Double? = nil) -> RLGuildMembershipDTO {
        RLGuildMembershipDTO(
            id: id,
            userId: userId,
            guildId: guildId,
            role: role,
            reputation: newReputation,
            contributionScore: contributionScore,
            status: status,
            dateJoined: dateJoined,
            accuracyRate: newAccuracyRate ?? accuracyRate
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
    let accuracyRate: Double?                // backend: accuracy_rate
    
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
    
    /// Accuracy as percentage string (e.g. "72%"), or nil if no accuracy data
    var accuracyFormatted: String? {
        guard let rate = accuracyRate else { return nil }
        return "\(Int(rate * 100))%"
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


/// A single day of guild statistics (backend: GuildStatisticsHistoryPoint).
struct RLGuildStatisticsHistoryPoint: Codable, Identifiable, Equatable {
    let day: Date                       // backend: day (yyyy-MM-dd)
    let reputationEarned: Int           // backend: reputation_earned
    let predictionsMade: Int            // backend: predictions_made
    let correctPredictions: Int         // backend: correct_predictions
    let accuracy: Double                // backend: accuracy (0.0 - 1.0)
    let activeMembers: Int              // backend: active_members
    let newMembers: Int                 // backend: new_members

    var id: Date { day }
}

/// Daily time-series of guild statistics over a recent window.
struct RLGuildStatisticsHistoryResponse: Codable, Equatable {
    let guildId: UUID                                       // backend: guild_id
    let period: String                                      // backend: period ("7d" | "30d" | "90d")
    let points: [RLGuildStatisticsHistoryPoint]             // backend: points
    let generatedAt: Date                                   // backend: generated_at
}


// ================================================================================================
// MARK: - Guild Request DTOs
// ================================================================================================

struct RLGuildJoinQuestionInputDTO: Codable, Identifiable {
    let prompt: String
    let isRequired: Bool
    let displayOrder: Int

    var id: String { "\(displayOrder)-\(prompt)" }
}

/// Request to create a new guild
struct RLCreateGuildRequestDTO: Codable {
    let name: String
    let description: String?
    let isOpen: Bool                 // backend: is_open
    let language: String?
    let location: String?
    let joinQuestions: [RLGuildJoinQuestionInputDTO]
    // Optional: creation asks for a name only, and the welcome post is
    // offered afterwards via the invite hub's setup checklist. The backend
    // accepts the pair as absent but rejects half of one.
    let initialAnnouncementTitle: String?
    let initialAnnouncementContent: String?
    let initialAnnouncementPreview: String?
    let initialAnnouncementIsImportant: Bool
    let crestSymbol: String?         // backend: crest_symbol (neutral key)
    let crestColor: String?          // backend: crest_color (palette key)
}

struct RLGuildJoinQuestionDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID
    let prompt: String
    let isRequired: Bool
    let displayOrder: Int
    let isActive: Bool
}

struct RLGuildJoinQuestionsListDTO: Codable {
    let questions: [RLGuildJoinQuestionDTO]
}

struct RLGuildJoinQuestionsUpdateRequestDTO: Codable {
    let questions: [RLGuildJoinQuestionInputDTO]
}

struct RLGuildJoinRequestAnswerInputDTO: Codable {
    let questionId: UUID
    let answerText: String
}

struct RLGuildJoinRequestCreateRequestDTO: Codable {
    let note: String?
    let answers: [RLGuildJoinRequestAnswerInputDTO]
}

struct RLGuildJoinRequestDecisionRequestDTO: Codable {
    let reviewNote: String?
}

struct RLGuildJoinRequestAnswerDTO: Codable, Identifiable {
    let id: UUID
    let questionId: UUID
    let questionPrompt: String
    let answerText: String
}

struct RLGuildJoinRequestDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID
    let requesterUserId: UUID
    let requesterUsername: String
    let requesterDisplayName: String
    let requesterAvatarUrl: String?
    let status: String
    let note: String?
    let reviewNote: String?
    let reviewedByUserId: UUID?
    let reviewedByDisplayName: String?
    let createdAt: Date
    let reviewedAt: Date?
    let answers: [RLGuildJoinRequestAnswerDTO]
}

struct RLGuildJoinRequestsListDTO: Codable {
    let requests: [RLGuildJoinRequestDTO]
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

enum GuildPostIconKey: String, Codable, CaseIterable, Identifiable {
    case megaphone
    case calendar
    case bell
    case chart
    case flag
    case bolt
    case star
    case trophy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .megaphone: return "Megaphone"
        case .calendar: return "Calendar"
        case .bell: return "Bell"
        case .chart: return "Chart"
        case .flag: return "Flag"
        case .bolt: return "Bolt"
        case .star: return "Star"
        case .trophy: return "Trophy"
        }
    }

    var systemImage: String {
        switch self {
        case .megaphone: return "megaphone.fill"
        case .calendar: return "calendar"
        case .bell: return "bell.fill"
        case .chart: return "chart.line.uptrend.xyaxis"
        case .flag: return "flag.fill"
        case .bolt: return "bolt.fill"
        case .star: return "star.fill"
        case .trophy: return "trophy.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .megaphone: return AppColors.statusWarning
        case .calendar: return AppColors.statusPositive
        case .bell: return AppColors.statusInfo
        case .chart: return AppColors.themeAwareTeal
        case .flag: return AppColors.statusNegative
        case .bolt: return AppColors.themeAwareYellow
        case .star: return AppColors.themeAwarePink
        case .trophy: return AppColors.themeAwareIndigo
        }
    }

    static let announcementDefault: GuildPostIconKey = .megaphone
    static let eventDefault: GuildPostIconKey = .calendar
}


/// Create Guild Announcement
struct RLCreateGuildAnnouncementRequestDTO: Codable {
    let title: String
    let content: String
    let preview: String
    let isImportant: Bool
    let iconKey: GuildPostIconKey?
}

struct RLCreateGlobalAnnouncementRequestDTO: Codable {
    let title: String
    let content: String
    let preview: String?
    let isImportant: Bool
    let iconKey: GuildPostIconKey?
}

struct RLGlobalAnnouncementBroadcastResponseDTO: Codable {
    let targetGuildCount: Int
    let createdAnnouncementCount: Int
    let authorDisplayName: String
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
    let iconKey: GuildPostIconKey?
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
    var iconKey: GuildPostIconKey { announcement.iconKey ?? .announcementDefault }

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
    var authorAccuracy: String? { authorMembership.accuracyFormatted }
    
    
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

/// Event location target — "symbol" or "chatroom".
/// Stored raw so we never fail to decode an event with an unknown location type.
enum RLEventLocationType: String, Codable {
    case symbol
    case chatroom
}

/// Create Guild Event Request - matches backend GuildEventCreateRequest
struct RLCreateGuildEventRequestDTO: Codable {
    let title: String
    let content: String
    let preview: String
    let eventDate: Date           // backend: event_date
    let isImportant: Bool         // backend: is_important
    let iconKey: GuildPostIconKey?
    let locationType: String?     // backend: location_type — "symbol" | "chatroom" | nil
    let locationId: UUID?         // backend: location_id
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
    let iconKey: GuildPostIconKey?
    var attendeeCount: Int               // backend: attendee_count (var for local cache updates)
    var isAttending: Bool                // backend: is_attending (var for local cache updates)
    let status: String
    var isRead: Bool                     // backend: is_read (var for local cache updates)
    let locationType: String?            // backend: location_type
    let locationId: UUID?                // backend: location_id
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
    var iconKey: GuildPostIconKey { event.iconKey ?? .eventDefault }
    
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

    // MARK: - Location
    /// Parsed location type — nil when no location set or value is unknown.
    var locationType: RLEventLocationType? {
        guard let raw = event.locationType else { return nil }
        return RLEventLocationType(rawValue: raw)
    }

    var locationId: UUID? { event.locationId }

    /// True when we have both a recognized type and an id to navigate to.
    var hasNavigableLocation: Bool {
        locationType != nil && locationId != nil
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

    var isActiveEvent: Bool {
        !isPastEvent
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
    let accuracyRate: Double?           // backend: accuracy_rate (trading accuracy 0.0-1.0)

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

    /// Accuracy as percentage string (e.g. "72%"), or nil if no accuracy data
    var accuracyFormatted: String? {
        guard let rate = accuracyRate else { return nil }
        return "\(Int(rate * 100))%"
    }

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
            accuracyRate: accuracyRate,
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

    func withPerformance(
        guildReputation newGuildReputation: Int? = nil,
        accuracyRate newAccuracyRate: Double? = nil,
        globalReputation newGlobalReputation: Int? = nil
    ) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: membershipId,
            role: role,
            reputation: newGuildReputation ?? reputation,
            contributionScore: contributionScore,
            dateJoined: dateJoined,
            accuracyRate: newAccuracyRate ?? accuracyRate,
            mutedUntil: mutedUntil,
            suspendedUntil: suspendedUntil,
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isOnline: isOnline,
            globalReputation: newGlobalReputation ?? globalReputation,
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
        case "twitter", "x": return AppColors.socialBlue
        case "discord": return AppColors.socialIndigo
        case "telegram": return AppColors.socialCyan
        case "tradingview": return AppColors.socialOrange
        case "youtube": return AppColors.socialRed
        default: return AppColors.secondaryForeground
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
    let language: String?
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
        case "beginner": return AppColors.secondaryForeground
        case "intermediate": return AppColors.statusInfo
        case "advanced": return AppColors.statusPositive
        case "expert": return AppColors.themeAwarePurple
        case "professional": return AppColors.statusWarning
        default: return AppColors.secondaryForeground
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
    var language: String?
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
        language: String? = nil,
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
        self.language = language
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

    enum CodingKeys: String, CodingKey {
        case userId
        case totalMarkersPlaced
        case successfulMarkers
        case accuracyRate
        case totalLikesReceived
        case totalCommentsMade
        case currentStreakDays
        case bestStreakDays
        case totalGuildsJoined
        case totalAwardsEarned
        case totalAwardPoints
        case topSymbols
        case markersByType
        case lastCalculatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        totalMarkersPlaced = try container.decodeIfPresent(Int.self, forKey: .totalMarkersPlaced) ?? 0
        successfulMarkers = try container.decodeIfPresent(Int.self, forKey: .successfulMarkers) ?? 0
        accuracyRate = try container.decodeIfPresent(Double.self, forKey: .accuracyRate) ?? 0
        totalLikesReceived = try container.decodeIfPresent(Int.self, forKey: .totalLikesReceived) ?? 0
        totalCommentsMade = try container.decodeIfPresent(Int.self, forKey: .totalCommentsMade) ?? 0
        currentStreakDays = try container.decodeIfPresent(Int.self, forKey: .currentStreakDays) ?? 0
        bestStreakDays = try container.decodeIfPresent(Int.self, forKey: .bestStreakDays) ?? 0
        totalGuildsJoined = try container.decodeIfPresent(Int.self, forKey: .totalGuildsJoined) ?? 0
        totalAwardsEarned = try container.decodeIfPresent(Int.self, forKey: .totalAwardsEarned) ?? 0
        totalAwardPoints = try container.decodeIfPresent(Int.self, forKey: .totalAwardPoints) ?? 0
        topSymbols = try container.decodeIfPresent([String].self, forKey: .topSymbols) ?? []
        markersByType = try container.decodeIfPresent([String: Int].self, forKey: .markersByType) ?? [:]
        lastCalculatedAt = try container.decodeIfPresent(Date.self, forKey: .lastCalculatedAt) ?? Date.distantPast
    }
    
    var accuracyFormatted: String {
        String(format: "%.1f%%", accuracyRate * 100)
    }
    
    var accuracyColor: Color {
        if accuracyRate >= 0.7 { return AppColors.statusPositive }
        else if accuracyRate >= 0.5 { return AppColors.moderationOrange }
        else { return AppColors.statusNegative }
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
    let familyKey: String?              // backend: family_key
    let tier: Int?
    let nextAwardTypeId: UUID?          // backend: next_award_type_id
    let scope: String?
    
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
    let membershipId: UUID?             // backend: membership_id
    let guildId: UUID?                  // backend: guild_id
    let userId: UUID?                   // backend: user_id
    let awardTypeId: UUID               // backend: award_type_id
    let name: String                    // From award_type
    let description: String             // From award_type
    let icon: String                    // From award_type
    let category: String                // From award_type
    let rarity: String                  // From award_type
    let pointsValue: Int                // backend: points_value
    let familyKey: String?              // backend: family_key
    let tier: Int?
    let scope: String?
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

    func withGlobalReputation(_ newGlobalReputation: Int) -> RLFriendDTO {
        RLFriendDTO(
            friendshipId: friendshipId,
            membershipId: membershipId,
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isOnline: isOnline,
            globalReputation: newGlobalReputation,
            friendsSince: friendsSince
        )
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

struct RLRuntimeFlagsDTO: Codable, Equatable {
    let betaWelcomeEnabled: Bool
    let betaFeedbackEnabled: Bool
    let awardsEnabled: Bool

    static let disabled = RLRuntimeFlagsDTO(
        betaWelcomeEnabled: false,
        betaFeedbackEnabled: false,
        awardsEnabled: false
    )

    init(
        betaWelcomeEnabled: Bool = false,
        betaFeedbackEnabled: Bool = false,
        awardsEnabled: Bool = false
    ) {
        self.betaWelcomeEnabled = betaWelcomeEnabled
        self.betaFeedbackEnabled = betaFeedbackEnabled
        self.awardsEnabled = awardsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        betaWelcomeEnabled = try container.decodeIfPresent(Bool.self, forKey: .betaWelcomeEnabled) ?? false
        betaFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .betaFeedbackEnabled) ?? false
        awardsEnabled = try container.decodeIfPresent(Bool.self, forKey: .awardsEnabled) ?? false
    }
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
        AppColors.memberRoleColor(self)
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
    let language: String?
    let location: String?
    var crestSymbol: String? = nil   // backend: crest_symbol
    var crestColor: String? = nil    // backend: crest_color
    /// Publish the guild's accuracy standings publicly. Separate from
    /// `isOpen`: who may join and what the world may read are different calls.
    var publicLeaderboard: Bool? = nil   // backend: public_leaderboard
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

/// Request DTO for creating a shareable guild invite/referral link
struct RLGuildInviteLinkCreateRequestDTO: Codable {
    let maxUses: Int?
    let expiresAt: Date?

    init(maxUses: Int? = nil, expiresAt: Date? = nil) {
        self.maxUses = maxUses
        self.expiresAt = expiresAt
    }
}

/// Shareable guild invite/referral link response DTO
struct RLGuildInviteLinkDTO: Codable, Identifiable {
    let id: UUID
    let guildId: UUID
    let createdByUserId: UUID
    let code: String
    let shareUrl: String
    let status: String
    let maxUses: Int?
    let useCount: Int
    let expiresAt: Date?
    let revokedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

/// List of shareable guild invite/referral links
struct RLGuildInviteLinksListDTO: Codable {
    let inviteLinks: [RLGuildInviteLinkDTO]
}

/// Connect a named Discord destination. A webhook belongs to exactly one
/// Discord channel, so guilds connect one webhook for each channel they want
/// members to be able to target.
struct RLGuildDiscordChannelCreateRequestDTO: Codable {
    let webhookUrl: String
    let label: String
}

/// Rename or update one Discord destination without ever returning its bearer
/// webhook URL to the client. `autoPostMarkers` is retained for compatibility
/// with servers that already understand the field; release UI leaves it nil.
struct RLGuildDiscordChannelUpdateRequestDTO: Codable {
    let label: String?
    let isDefault: Bool?
    let autoPostMarkers: Bool?
    /// Opt this channel into the weekly standings digest.
    let postWeeklyDigest: Bool?

    init(
        label: String? = nil,
        isDefault: Bool? = nil,
        autoPostMarkers: Bool? = nil,
        postWeeklyDigest: Bool? = nil
    ) {
        self.label = label
        self.isDefault = isDefault
        self.autoPostMarkers = autoPostMarkers
        self.postWeeklyDigest = postWeeklyDigest
    }
}

/// Post an existing invite link into the guild's Discord channel.
struct RLGuildDiscordShareInviteRequestDTO: Codable {
    let code: String
}

/// Post the guild's current accuracy standings into a Discord channel.
struct RLGuildDiscordShareLeaderboardRequestDTO: Codable {
    /// `7d`, `30d` or `all` — the server's own vocabulary.
    let window: String
}

/// Destination and optional note posted alongside a marker in Discord.
struct RLMarkerDiscordShareRequestDTO: Codable {
    let channelId: UUID
    let caption: String?

    init(channelId: UUID, caption: String? = nil) {
        self.channelId = channelId
        self.caption = caption
    }
}

/// Server-issued capability URL. A bare marker UUID is never a public share.
struct RLMarkerExternalShareLinkDTO: Codable, Equatable {
    let shareUrl: String
}

/// One named Discord channel destination connected to a guild.
///
/// The webhook URL is a bearer capability, so the server only ever returns the
/// masked form — there is no way to read back a usable URL from the client.
struct RLGuildDiscordChannelDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let guildId: UUID
    let label: String
    let webhookMasked: String?
    let webhookId: String
    let isDefault: Bool
    let autoPostMarkers: Bool
    /// Whether the weekly guild standings digest is posted here. Optional so
    /// this decodes against a server that predates the digest.
    let postWeeklyDigest: Bool?
    /// `active` | `failing` | `invalid`.
    let status: String
    let consecutiveFailures: Int
    let lastSuccessAt: Date?
    let lastFailureReason: String?
    let createdAt: Date

    /// Whether a share attempt is worth making right now.
    var canPost: Bool { status != "invalid" }

    /// Discord is connected but recent deliveries have been failing.
    var needsAttention: Bool { status == "failing" || status == "invalid" }

    /// Admin labels are free-form; present them consistently as Discord
    /// channels without storing duplicate `#` prefixes.
    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Discord channel" }
        return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
    }
}

/// List response used by settings and every share destination picker.
struct RLGuildDiscordChannelsListDTO: Codable {
    let channels: [RLGuildDiscordChannelDTO]

    /// Default channel first, then the first-added usable destination. Keeping
    /// this policy in one place makes every share surface agree.
    var preferredChannel: RLGuildDiscordChannelDTO? {
        channels.first(where: { $0.isDefault && $0.canPost })
            ?? channels.first(where: \.canPost)
    }
}

/// Preview response for a shareable guild invite/referral link
struct RLGuildInviteLinkResolveDTO: Codable {
    let code: String
    let guild: RLGuildDTO
    let createdByUserId: UUID
    let createdByDisplayName: String?
    let status: String
    let isJoinable: Bool
    let expiresAt: Date?
    let maxUses: Int?
    let useCount: Int
}

/// User search result for invite
struct RLUserSearchResultDTO: Codable, Identifiable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isMember: Bool
    let hasPendingInvite: Bool
    let guildId: UUID?
    let guildName: String?
    let guildRole: String?

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
    let reportedUserId: UUID?
    let contentSnippet: String?

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
        case "pending": return AppColors.statusWarning
        case "resolved": return AppColors.statusPositive
        case "dismissed": return AppColors.secondaryForeground
        default: return AppColors.secondaryForeground
        }
    }

    var shortReference: String {
        let compact = id.uuidString
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        return "#\(String(compact.prefix(8)))"
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
    case social = "social"
    case guild = "guild"
    case contribution = "contribution"
    case loyalty = "loyalty"
    case community = "community"
    case milestones = "milestones"
    case special = "special"
    
    var displayName: String { rawValue.capitalized }
    
    var color: Color {
        switch self {
        case .trading: return AppColors.awardCategoryTrading
        case .social, .community: return AppColors.awardCategoryCommunity
        case .guild: return AppColors.statusInfo
        case .contribution: return AppColors.statusPositive
        case .loyalty, .milestones: return AppColors.awardCategoryMilestones
        case .special: return AppColors.awardCategorySpecial
        }
    }
    
    var icon: String {
        switch self {
        case .trading: return "chart.line.uptrend.xyaxis"
        case .social, .community: return "person.3.fill"
        case .guild: return "shield.lefthalf.filled"
        case .contribution: return "checkmark.seal.fill"
        case .loyalty, .milestones: return "flame.fill"
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
        case .common: return AppColors.secondaryForeground
        case .uncommon: return AppColors.awardRarityUncommon
        case .rare: return AppColors.awardRarityRare
        case .epic: return AppColors.awardRarityEpic
        case .legendary: return AppColors.awardRarityLegendary
        }
    }
    
    var glowColor: Color {
        switch self {
        case .common: return .clear
        case .uncommon: return AppColors.statusPositive30
        case .rare: return AppColors.statusInfo40
        case .epic: return AppColors.statusSecondary50
        case .legendary: return AppColors.statusWarning60
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

struct RLDeleteAccountRequest: Codable {
    let password: String?
    let confirmation: String
}

// MARK: - User Settings DTOs

struct RLUserSettingsDTO: Codable {
    let showOnlineStatus: Bool
    let allowFriendRequests: Bool
    let activityVisible: Bool
    let analyticsEnabled: Bool
    let personalizedContentEnabled: Bool
    let dmPermissionMode: String
    let pushNotificationPreferences: RLPushNotificationPreferences

    var dmPermission: RLDMPermissionMode {
        RLDMPermissionMode(rawValue: dmPermissionMode) ?? .all
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showOnlineStatus = try container.decodeIfPresent(Bool.self, forKey: .showOnlineStatus) ?? true
        allowFriendRequests = try container.decodeIfPresent(Bool.self, forKey: .allowFriendRequests) ?? true
        activityVisible = try container.decodeIfPresent(Bool.self, forKey: .activityVisible) ?? true
        analyticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .analyticsEnabled) ?? true
        personalizedContentEnabled = try container.decodeIfPresent(Bool.self, forKey: .personalizedContentEnabled) ?? true
        dmPermissionMode = try container.decodeIfPresent(String.self, forKey: .dmPermissionMode) ?? "all"
        pushNotificationPreferences = try container.decodeIfPresent(RLPushNotificationPreferences.self, forKey: .pushNotificationPreferences) ?? RLPushNotificationPreferences()
    }
}

// MARK: - Push Notification Preferences

struct RLPushNotificationPreferences: Codable, Equatable {
    var dm: Bool
    var mention: Bool
    var markerResult: Bool
    var markerEngagement: Bool
    var awards: Bool
    var announcement: Bool
    var event: Bool
    var eventReminder: Bool
    var friendRequest: Bool

    init(
        dm: Bool = true,
        mention: Bool = true,
        markerResult: Bool = true,
        markerEngagement: Bool = true,
        awards: Bool = true,
        announcement: Bool = true,
        event: Bool = true,
        eventReminder: Bool = true,
        friendRequest: Bool = true
    ) {
        self.dm = dm
        self.mention = mention
        self.markerResult = markerResult
        self.markerEngagement = markerEngagement
        self.awards = awards
        self.announcement = announcement
        self.event = event
        self.eventReminder = eventReminder
        self.friendRequest = friendRequest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dm = try container.decodeIfPresent(Bool.self, forKey: .dm) ?? true
        mention = try container.decodeIfPresent(Bool.self, forKey: .mention) ?? true
        markerResult = try container.decodeIfPresent(Bool.self, forKey: .markerResult) ?? true
        markerEngagement = try container.decodeIfPresent(Bool.self, forKey: .markerEngagement) ?? true
        awards = try container.decodeIfPresent(Bool.self, forKey: .awards) ?? true
        announcement = try container.decodeIfPresent(Bool.self, forKey: .announcement) ?? true
        event = try container.decodeIfPresent(Bool.self, forKey: .event) ?? true
        eventReminder = try container.decodeIfPresent(Bool.self, forKey: .eventReminder) ?? true
        friendRequest = try container.decodeIfPresent(Bool.self, forKey: .friendRequest) ?? true
    }
}

struct RLPushPreferencesUpdateRequest: Codable {
    let dm: Bool?
    let mention: Bool?
    let markerResult: Bool?
    let markerEngagement: Bool?
    let awards: Bool?
    let announcement: Bool?
    let event: Bool?
    let eventReminder: Bool?
    let friendRequest: Bool?

    init(
        dm: Bool? = nil,
        mention: Bool? = nil,
        markerResult: Bool? = nil,
        markerEngagement: Bool? = nil,
        awards: Bool? = nil,
        announcement: Bool? = nil,
        event: Bool? = nil,
        eventReminder: Bool? = nil,
        friendRequest: Bool? = nil
    ) {
        self.dm = dm
        self.mention = mention
        self.markerResult = markerResult
        self.markerEngagement = markerEngagement
        self.awards = awards
        self.announcement = announcement
        self.event = event
        self.eventReminder = eventReminder
        self.friendRequest = friendRequest
    }
}

// MARK: - Device Token DTOs

struct RLDeviceTokenRegisterRequest: Codable {
    let deviceToken: String
    let platform: String
}

struct RLDeviceTokenResponse: Codable {
    let id: UUID
    let deviceToken: String
    let platform: String
    let isActive: Bool
    let createdAt: Date
}

struct RLDeviceTokenDeleteRequest: Codable {
    let deviceToken: String
}

struct RLUserSettingsUpdateRequest: Codable {
    let showOnlineStatus: Bool?
    let allowFriendRequests: Bool?
    let activityVisible: Bool?
    let analyticsEnabled: Bool?
    let personalizedContentEnabled: Bool?
    let dmPermissionMode: String?

    init(
        showOnlineStatus: Bool? = nil,
        allowFriendRequests: Bool? = nil,
        activityVisible: Bool? = nil,
        analyticsEnabled: Bool? = nil,
        personalizedContentEnabled: Bool? = nil,
        dmPermissionMode: String? = nil
    ) {
        self.showOnlineStatus = showOnlineStatus
        self.allowFriendRequests = allowFriendRequests
        self.activityVisible = activityVisible
        self.analyticsEnabled = analyticsEnabled
        self.personalizedContentEnabled = personalizedContentEnabled
        self.dmPermissionMode = dmPermissionMode
    }
}

enum RLDMPermissionMode: String, CaseIterable, Codable, Identifiable {
    case all
    case friends
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All users"
        case .friends: return "Friends only"
        case .none: return "No one"
        }
    }

    var subtitle: String {
        switch self {
        case .all: return "Allow direct messages from anyone."
        case .friends: return "Only users in your friends list can DM you."
        case .none: return "Block all incoming direct messages."
        }
    }
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
    let guildRepDelta: Int?
    let globalRepDelta: Int?
    let metricDelta: Int?
    let metricLabel: String?
    let sourceType: String?
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
        case .error: return AppColors.statusNegative
        case .warning: return AppColors.statusWarning
        case .info: return AppColors.statusInfo
        case .success: return AppColors.statusPositive
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

    /// Solid background colour for the full-width toast bar.
    var toastBackground: Color {
        switch self {
        case .error: return AppColors.toastErrorRed
        case .warning: return AppColors.toastWarningYellow
        case .info: return AppColors.toastInfoBlue
        case .success: return AppColors.toastSuccessGreen
        }
    }

    /// Text/icon colour that stays legible on the toast bar background.
    var toastForeground: Color {
        switch self {
        case .warning: return AppColors.toastOnYellow
        default: return .white
        }
    }
}


enum RLAlertDisplayStyle {
    case alert
    case toast
}


// ================================================================================================
// MARK: - Trading Interests Catalog (Shared)
// ================================================================================================

enum RLTradingInterestsCatalog {
    static let categories: [(category: String, items: [RLTradingInterestItem])] = [
        (
            "Markets",
            [
                RLTradingInterestItem(name: "Forex", icon: "dollarsign.circle.fill", isPrimary: false),
                RLTradingInterestItem(name: "Stocks", icon: "chart.line.uptrend.xyaxis", isPrimary: false),
                RLTradingInterestItem(name: "Crypto", icon: "bitcoinsign.circle.fill", isPrimary: false),
                RLTradingInterestItem(name: "Commodities", icon: "cube.fill", isPrimary: false),
                RLTradingInterestItem(name: "Indices", icon: "chart.bar.fill", isPrimary: false),
                RLTradingInterestItem(name: "Futures", icon: "calendar.circle.fill", isPrimary: false),
                RLTradingInterestItem(name: "Options", icon: "arrow.left.arrow.right", isPrimary: false),
            ]
        ),
        (
            "Trading Styles",
            [
                RLTradingInterestItem(name: "Day Trading", icon: "sun.max.fill", isPrimary: false),
                RLTradingInterestItem(name: "Swing Trading", icon: "waveform.path.ecg", isPrimary: false),
                RLTradingInterestItem(name: "Scalping", icon: "bolt.fill", isPrimary: false),
                RLTradingInterestItem(name: "Position Trading", icon: "calendar", isPrimary: false),
                RLTradingInterestItem(name: "Algorithmic", icon: "cpu.fill", isPrimary: false),
                RLTradingInterestItem(name: "Event Trading", icon: "newspaper.fill", isPrimary: false),
            ]
        ),
        (
            "Analysis",
            [
                RLTradingInterestItem(name: "Technical Analysis", icon: "chart.xyaxis.line", isPrimary: false),
                RLTradingInterestItem(name: "Fundamental Analysis", icon: "doc.text.magnifyingglass", isPrimary: false),
                RLTradingInterestItem(name: "Sentiment Analysis", icon: "person.3.fill", isPrimary: false),
                RLTradingInterestItem(name: "Price Action", icon: "candybarphone", isPrimary: false),
                RLTradingInterestItem(name: "Macro", icon: "globe.europe.africa.fill", isPrimary: false),
            ]
        ),
        (
            "Risk & Execution",
            [
                RLTradingInterestItem(name: "Risk Management", icon: "shield.checkered", isPrimary: false),
                RLTradingInterestItem(name: "Portfolio Building", icon: "briefcase.fill", isPrimary: false),
                RLTradingInterestItem(name: "Copy Trading", icon: "person.2.wave.2.fill", isPrimary: false),
                RLTradingInterestItem(name: "High Frequency", icon: "speedometer", isPrimary: false),
            ]
        ),
    ]

    static var allItems: [RLTradingInterestItem] {
        categories.flatMap(\.items)
    }
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
    var selectedInterests: [String] = []
    var language: String = RLSignupData.defaultLanguage()
    var location: String = RLSignupData.defaultLocation()
    var profileBio: String = ""
    var profileTradingStyle: String = ""
    var profileTwitterHandle: String = ""
    var profileDiscordHandle: String = ""
    var profileTelegramHandle: String = ""
    var profileTradingViewHandle: String = ""
    var profileYoutubeHandle: String = ""
    var profileAvatarImageData: Data?

    /// True when this signup was initiated via Apple Sign In (skips password, pre-fills Apple data)
    var isAppleSignUp: Bool = false

    static func defaultLanguage() -> String {
        LocaleOptionCatalog.defaultLanguageCode()
    }

    static func defaultLocation() -> String {
        LocaleOptionCatalog.defaultCountryCode()
    }

    /// Convert to API request format
    func toRequest() -> RLRegisterRequestDTO {
        let normalizedLanguage = RLAuthValidator.trimmed(language)
        let normalizedLocation = RLAuthValidator.trimmed(location)
        return RLRegisterRequestDTO(
            email: email,
            username: username,
            displayName: name,
            password: password,
            language: normalizedLanguage.isEmpty ? nil : normalizedLanguage,
            location: normalizedLocation.isEmpty ? nil : normalizedLocation
        )
    }
}

enum RLAuthValidator {
    private static let emailRegex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,64}$"#
    private static let usernameRegex = #"^[A-Za-z0-9_.-]{3,50}$"#

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedAppleDisplayName(_ value: String?) -> String {
        trimmed(value ?? "")
    }

    static func isValidDisplayName(_ value: String) -> Bool {
        let trimmedValue = trimmed(value)
        return !trimmedValue.isEmpty && trimmedValue.count <= 100
    }

    static func isValidEmail(_ email: String) -> Bool {
        let normalized = trimmed(email)
        guard !normalized.isEmpty else { return false }
        return normalized.range(of: emailRegex, options: .regularExpression) != nil
    }

    static func isValidUsername(_ username: String) -> Bool {
        let normalized = trimmed(username)
        guard !normalized.isEmpty else { return false }
        return normalized.range(of: usernameRegex, options: .regularExpression) != nil
    }

    static func isLikelyEmailIdentifier(_ identifier: String) -> Bool {
        trimmed(identifier).contains("@")
    }

    static func isValidIdentifier(_ identifier: String) -> Bool {
        if isLikelyEmailIdentifier(identifier) {
            return isValidEmail(identifier)
        }
        return isValidUsername(identifier)
    }

    static func isValidPassword(_ password: String) -> Bool {
        let bytes = password.utf8.count
        guard bytes >= 8 && bytes <= 72 else { return false }
        guard password.rangeOfCharacter(from: .uppercaseLetters) != nil else { return false }
        guard password.rangeOfCharacter(from: .lowercaseLetters) != nil else { return false }
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else { return false }
        return true
    }

    static func doPasswordsMatch(_ first: String, _ second: String) -> Bool {
        !first.isEmpty && first == second
    }
}

enum RLSignupStep: Hashable {
    case accountInfo
    case appleProfileCompletion
    case username
    case interests
    case guild
    case profile
    case emailVerification
}

/// Tracks how far a user has progressed through onboarding.
/// Persisted locally so returning users (including Apple users) can resume.
enum RLOnboardingState: String, Codable, Equatable {
    case accountCreated = "account_created"
    case profileCompleted = "profile_completed"
    case usernameCompleted = "username_completed"
    case basicsCompleted = "basics_completed"
    case interestsCompleted = "interests_completed"
    case guildSelected = "guild_selected"
    case optionalDetailsCompleted = "optional_details_completed"
    case complete = "onboarding_complete"
}

/// A join request from the requester's own point of view.
///
/// Carries the guild inline so a "pending" row renders without a round-trip
/// each. Backend: `GuildMyJoinRequestResponse`.
struct RLGuildMyJoinRequestDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let guild: RLGuildDTO
    /// "pending" | "approved" | "declined"
    let status: String
    let note: String?
    let createdAt: Date
    let reviewedAt: Date?
}

struct RLGuildMyJoinRequestsListDTO: Codable, Equatable {
    let requests: [RLGuildMyJoinRequestDTO]
}
