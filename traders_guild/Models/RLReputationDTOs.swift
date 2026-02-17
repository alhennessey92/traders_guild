// =============================================================================
// REPUTATION DTOs
// =============================================================================
//
// Backend schemas: shared/schemas/reputation.py
//
// Backend -> iOS mapping:
//   ReputationTierResponse          -> RLReputationTierDTO
//   ReputationEventResponse         -> RLReputationEventDTO
//   ReputationBreakdownResponse     -> RLReputationBreakdownDTO
//   ReputationProfileResponse       -> RLReputationProfileDTO
//   GlobalReputationResponse        -> RLGlobalReputationDTO
//   GuildContributionResponse       -> RLGuildContributionDTO
//   GlobalModifiersResponse         -> RLGlobalModifiersDTO
//   LeaderboardMemberResponse       -> RLLeaderboardMemberDTO
//   GuildReputationLeaderboardResponse -> RLReputationLeaderboardDTO
//   ReputationHistoryResponse       -> RLReputationHistoryDTO
//   ReputationUpdatePayload         -> RLReputationUpdatePayload (WebSocket)
// =============================================================================

import Foundation
import SwiftUI


// MARK: - Reputation Tier

/// Tier definition for display. Maps to backend ReputationTierResponse.
struct RLReputationTierDTO: Codable, Equatable {
    let tierName: String?
    let tierLevel: Int
    let minReputation: Int
    let icon: String?
    let colorHex: String
    let influenceBonus: Double

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }

    /// SF Symbol for tier display
    var displayIcon: String {
        icon ?? "circle.fill"
    }
}


// MARK: - Reputation Event (History Item)

/// Single reputation event for history display. Maps to backend ReputationEventResponse.
struct RLReputationEventDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let eventType: String
    let sourceType: String?
    let sourceId: UUID?
    let finalPoints: Double
    let guildRepDelta: Int
    let globalRepDelta: Int
    let metadata: [String: AnyCodableValue]?
    let createdAt: Date

    // MARK: - Computed

    var isPositive: Bool {
        finalPoints >= 0
    }

    var pointsFormatted: String {
        let pts = Int(finalPoints)
        return pts >= 0 ? "+\(pts)" : "\(pts)"
    }

    var displayEventType: String {
        switch eventType {
        case "prediction_win":    return "Prediction Win"
        case "prediction_loss":   return "Prediction Loss"
        case "marker_liked":      return "Marker Liked"
        case "marker_unliked":    return "Unlike"
        case "marker_commented":  return "Marker Comment"
        case "comment_liked":     return "Comment Liked"
        case "message_liked":     return "Message Liked"
        case "content_trending":  return "Trending Bonus"
        case "activity_bonus":    return "Activity Bonus"
        case "streak_bonus":      return "Streak Bonus"
        case "decay":             return "Inactivity Decay"
        case "report_penalty":    return "Report Penalty"
        default:                  return eventType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var eventIcon: String {
        switch eventType {
        case "prediction_win":    return "chart.line.uptrend.xyaxis"
        case "prediction_loss":   return "chart.line.downtrend.xyaxis"
        case "marker_liked":      return "heart.fill"
        case "marker_unliked":    return "heart.slash"
        case "marker_commented":  return "bubble.left.fill"
        case "comment_liked":     return "hand.thumbsup.fill"
        case "message_liked":     return "hand.thumbsup"
        case "content_trending":  return "flame.fill"
        case "activity_bonus":    return "checkmark.circle.fill"
        case "streak_bonus":      return "bolt.fill"
        case "decay":             return "clock.arrow.circlepath"
        case "report_penalty":    return "exclamationmark.triangle.fill"
        default:                  return "star.fill"
        }
    }

    var eventColor: Color {
        switch eventType {
        case "prediction_win":                    return .green
        case "prediction_loss":                   return .red
        case "marker_liked", "comment_liked",
             "message_liked":                     return .pink
        case "marker_unliked":                    return .gray
        case "marker_commented":                  return .blue
        case "content_trending":                  return .orange
        case "activity_bonus", "streak_bonus":    return .cyan
        case "decay", "report_penalty":           return .red
        default:                                  return .gray
        }
    }

    /// Coding keys to map metadata_ from backend
    enum CodingKeys: String, CodingKey {
        case id, eventType, sourceType, sourceId, finalPoints
        case guildRepDelta, globalRepDelta, createdAt
        case metadata = "metadata_"
    }

    static func == (lhs: RLReputationEventDTO, rhs: RLReputationEventDTO) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Reputation Breakdown

/// Breakdown of reputation by source category. Maps to backend ReputationBreakdownResponse.
struct RLReputationBreakdownDTO: Codable, Equatable {
    let predictionRep: Int
    let socialRep: Int
    let activityRep: Int
    let penaltyRep: Int
    let total: Int
}


// MARK: - Guild Reputation Profile

/// User's reputation profile within a specific guild. Maps to backend ReputationProfileResponse.
struct RLReputationProfileDTO: Codable, Equatable {
    let userId: UUID
    let guildId: UUID
    let reputation: Int
    let tier: RLReputationTierDTO
    let breakdown: RLReputationBreakdownDTO
    let recentEvents: [RLReputationEventDTO]
    let rankInGuild: Int
    let predictionsToday: Int
    let dailySocialCapRemaining: Double
    let weeklyDelta: Int

    static func == (lhs: RLReputationProfileDTO, rhs: RLReputationProfileDTO) -> Bool {
        lhs.userId == rhs.userId && lhs.guildId == rhs.guildId && lhs.reputation == rhs.reputation
    }
}


// MARK: - Guild Contribution (Global Rep)

/// How much a single guild contributes to global reputation.
struct RLGuildContributionDTO: Codable, Equatable {
    let guildId: UUID
    let guildName: String
    let guildImageUrl: String?
    let reputation: Int
    let weight: Double

    var weightPercentFormatted: String {
        "\(Int(weight * 100))%"
    }
}


// MARK: - Global Modifiers

/// Active global reputation modifiers. Maps to backend GlobalModifiersResponse.
struct RLGlobalModifiersDTO: Codable, Equatable {
    let cleanRecordBonus: Bool
    let cleanRecordMultiplier: Double
    let consecutiveActiveDays: Int
    let activityMultiplier: Double
    let totalModifier: Double

    var totalModifierFormatted: String {
        String(format: "%.0f%%", (totalModifier - 1.0) * 100)
    }
}


// MARK: - Global Reputation

/// User's global cross-guild reputation. Maps to backend GlobalReputationResponse.
struct RLGlobalReputationDTO: Codable, Equatable {
    let userId: UUID
    let globalReputation: Int
    let tier: RLReputationTierDTO
    let guildContributions: [RLGuildContributionDTO]
    let modifiers: RLGlobalModifiersDTO
    let consecutiveActiveDays: Int
    let weeklyDelta: Int

    static func == (lhs: RLGlobalReputationDTO, rhs: RLGlobalReputationDTO) -> Bool {
        lhs.userId == rhs.userId && lhs.globalReputation == rhs.globalReputation
    }
}


// MARK: - Leaderboard

/// Single member in a reputation leaderboard.
struct RLLeaderboardMemberDTO: Codable, Identifiable, Equatable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let reputation: Int
    let tier: RLReputationTierDTO
    let rank: Int

    var id: UUID { userId }

    static func == (lhs: RLLeaderboardMemberDTO, rhs: RLLeaderboardMemberDTO) -> Bool {
        lhs.userId == rhs.userId && lhs.rank == rhs.rank
    }
}

/// Guild reputation leaderboard response.
struct RLReputationLeaderboardDTO: Codable {
    let members: [RLLeaderboardMemberDTO]
    let totalMembers: Int
}


// MARK: - Reputation History (Paginated)

/// Paginated reputation event history.
struct RLReputationHistoryDTO: Codable {
    let events: [RLReputationEventDTO]
    let total: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}


// MARK: - Reputation Tier List

/// For decoding the tiers endpoint which returns a plain array.
typealias RLReputationTierListDTO = [RLReputationTierDTO]


// MARK: - WebSocket Payload

/// Published via WebSocket when a user's reputation changes.
/// Sent on user:{user_id}:notifications channel with type "reputation_update".
struct RLReputationUpdatePayload: Codable, Equatable {
    let userId: String
    let guildId: String
    let eventType: String
    let pointsAwarded: Int
    let newGuildReputation: Int
    let newGlobalReputation: Int
    let tierLevel: Int
    let tierColorHex: String
    let tierChanged: Bool
    let previousTierLevel: Int?

    var tierColor: Color {
        Color(hex: tierColorHex) ?? .gray
    }

    var isPositive: Bool {
        pointsAwarded >= 0
    }

    var pointsFormatted: String {
        pointsAwarded >= 0 ? "+\(pointsAwarded)" : "\(pointsAwarded)"
    }
}
