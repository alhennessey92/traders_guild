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
// MARK: - Guild List Response
// ================================================================================================

/// Matches backend GuildListResponse schema
struct RLGuildListResponseDTO: Codable {
    let guilds: [RLGuildDTO]
    let guildMemberships: [RLGuildMembershipDTO]   // backend: guild_memberships
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
