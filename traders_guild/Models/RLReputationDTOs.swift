// =============================================================================
// REPUTATION & ACCURACY DTOs
// =============================================================================
//
// Backend schemas: shared/schemas/reputation.py
//
// Backend -> iOS mapping:
//   ReputationTierResponse              -> RLReputationTierDTO
//   ReputationEventResponse             -> RLReputationEventDTO
//   ReputationBreakdownResponse         -> RLReputationBreakdownDTO
//   ReputationProfileResponse           -> RLReputationProfileDTO
//   GlobalReputationResponse            -> RLGlobalReputationDTO
//   GuildContributionResponse           -> RLGuildContributionDTO
//   GlobalModifiersResponse             -> RLGlobalModifiersDTO
//   LeaderboardMemberResponse           -> RLLeaderboardMemberDTO
//   GuildReputationLeaderboardResponse  -> RLReputationLeaderboardDTO
//   ReputationHistoryResponse           -> RLReputationHistoryDTO
//   ReputationUpdatePayload             -> RLReputationUpdatePayload (WebSocket)
//   AccuracyProfileResponse             -> RLAccuracyProfileDTO
//   AccuracyLeaderboardMemberResponse   -> RLAccuracyLeaderboardMemberDTO
//   AccuracyLeaderboardResponse         -> RLAccuracyLeaderboardDTO
//   AccuracyUpdatePayload               -> RLAccuracyUpdatePayload (WebSocket)
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
        case "marker_comment_deleted": return "Comment Removed"
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
        case "marker_comment_deleted": return "bubble.left.and.exclamationmark.bubble.right.fill"
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
        case "marker_unliked", "marker_comment_deleted":
                                                   return .gray
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

struct RLReputationTrendPointDTO: Codable, Equatable, Identifiable {
    let day: Date
    let value: Int

    var id: Date { day }
}

struct RLAccuracyTrendPointDTO: Codable, Equatable, Identifiable {
    let day: Date
    let value: Double

    var id: Date { day }
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
    let reputationTrend30d: [RLReputationTrendPointDTO]

    enum CodingKeys: String, CodingKey {
        case userId
        case guildId
        case reputation
        case tier
        case breakdown
        case recentEvents
        case rankInGuild
        case predictionsToday
        case dailySocialCapRemaining
        case weeklyDelta
        case reputationTrend30d
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        guildId = try container.decode(UUID.self, forKey: .guildId)
        reputation = try container.decodeIfPresent(Int.self, forKey: .reputation) ?? 0
        tier = try container.decode(RLReputationTierDTO.self, forKey: .tier)
        breakdown = try container.decode(RLReputationBreakdownDTO.self, forKey: .breakdown)
        recentEvents = try container.decodeIfPresent([RLReputationEventDTO].self, forKey: .recentEvents) ?? []
        rankInGuild = try container.decodeIfPresent(Int.self, forKey: .rankInGuild) ?? 0
        predictionsToday = try container.decodeIfPresent(Int.self, forKey: .predictionsToday) ?? 0
        dailySocialCapRemaining = try container.decodeIfPresent(Double.self, forKey: .dailySocialCapRemaining) ?? 0
        weeklyDelta = try container.decodeIfPresent(Int.self, forKey: .weeklyDelta) ?? 0
        reputationTrend30d = try container.decodeIfPresent([RLReputationTrendPointDTO].self, forKey: .reputationTrend30d) ?? []
    }

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

    init(
        cleanRecordBonus: Bool,
        cleanRecordMultiplier: Double,
        consecutiveActiveDays: Int,
        activityMultiplier: Double,
        totalModifier: Double
    ) {
        self.cleanRecordBonus = cleanRecordBonus
        self.cleanRecordMultiplier = cleanRecordMultiplier
        self.consecutiveActiveDays = consecutiveActiveDays
        self.activityMultiplier = activityMultiplier
        self.totalModifier = totalModifier
    }

    enum CodingKeys: String, CodingKey {
        case cleanRecordBonus
        case cleanRecordMultiplier
        case consecutiveActiveDays
        case activityMultiplier
        case totalModifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cleanRecordBonus = try container.decodeIfPresent(Bool.self, forKey: .cleanRecordBonus) ?? false
        cleanRecordMultiplier = try container.decodeIfPresent(Double.self, forKey: .cleanRecordMultiplier) ?? 1.0
        consecutiveActiveDays = try container.decodeIfPresent(Int.self, forKey: .consecutiveActiveDays) ?? 0
        activityMultiplier = try container.decodeIfPresent(Double.self, forKey: .activityMultiplier) ?? 1.0
        totalModifier = try container.decodeIfPresent(Double.self, forKey: .totalModifier) ?? 1.0
    }

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
    let breakdown: RLReputationBreakdownDTO
    let guildContributions: [RLGuildContributionDTO]
    let modifiers: RLGlobalModifiersDTO
    let consecutiveActiveDays: Int
    let weeklyDelta: Int
    let reputationTrend30d: [RLReputationTrendPointDTO]

    enum CodingKeys: String, CodingKey {
        case userId
        case globalReputation
        case tier
        case breakdown
        case guildContributions
        case modifiers
        case consecutiveActiveDays
        case weeklyDelta
        case reputationTrend30d
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        globalReputation = try container.decodeIfPresent(Int.self, forKey: .globalReputation) ?? 0
        tier = try container.decodeIfPresent(RLReputationTierDTO.self, forKey: .tier) ?? RLReputationTierDTO(
            tierName: nil,
            tierLevel: 0,
            minReputation: 0,
            icon: "circle.fill",
            colorHex: "#8E8E93",
            influenceBonus: 1.0
        )
        breakdown = try container.decodeIfPresent(RLReputationBreakdownDTO.self, forKey: .breakdown) ?? RLReputationBreakdownDTO(
            predictionRep: 0,
            socialRep: 0,
            activityRep: 0,
            penaltyRep: 0,
            total: 0
        )
        guildContributions = try container.decodeIfPresent([RLGuildContributionDTO].self, forKey: .guildContributions) ?? []
        modifiers = try container.decodeIfPresent(RLGlobalModifiersDTO.self, forKey: .modifiers) ?? RLGlobalModifiersDTO(
            cleanRecordBonus: false,
            cleanRecordMultiplier: 1.0,
            consecutiveActiveDays: 0,
            activityMultiplier: 1.0,
            totalModifier: 1.0
        )
        consecutiveActiveDays = try container.decodeIfPresent(Int.self, forKey: .consecutiveActiveDays) ?? 0
        weeklyDelta = try container.decodeIfPresent(Int.self, forKey: .weeklyDelta) ?? 0
        reputationTrend30d = try container.decodeIfPresent([RLReputationTrendPointDTO].self, forKey: .reputationTrend30d) ?? []
    }

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
    let accuracyRate: Double?

    var id: UUID { userId }

    /// Accuracy formatted as percentage string (e.g. "72%")
    var accuracyFormatted: String? {
        guard let rate = accuracyRate else { return nil }
        return "\(Int(rate * 100))%"
    }

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


// MARK: - Accuracy Profile

/// User's trading accuracy profile within a guild. Maps to backend AccuracyProfileResponse.
struct RLAccuracyProfileDTO: Codable, Equatable {
    let userId: UUID
    let guildId: UUID?
    let accuracyRate: Double
    let totalPredictions: Int
    let successfulPredictions: Int
    let avgRrRatio: Double?
    let winStreak: Int
    let lossStreak: Int
    let bestWinStreak: Int
    let rollingAccuracy30d: Double?
    let rollingWins30d: Int
    let rollingTotal30d: Int
    let rankInGuild: Int?
    let accuracyTrend30d: [RLAccuracyTrendPointDTO]
                                 
    enum CodingKeys: String, CodingKey {
        case userId
        case guildId
        case accuracyRate
        case totalPredictions
        case successfulPredictions
        case avgRrRatio
        case winStreak
        case lossStreak
        case bestWinStreak
        case rollingAccuracy30d
        case rollingWins30d
        case rollingTotal30d
        case accuracyTrend30d
        case rankInGuild
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        guildId = try container.decodeIfPresent(UUID.self, forKey: .guildId)
        accuracyRate = try container.decodeIfPresent(Double.self, forKey: .accuracyRate) ?? 0
        totalPredictions = try container.decodeIfPresent(Int.self, forKey: .totalPredictions) ?? 0
        successfulPredictions = try container.decodeIfPresent(Int.self, forKey: .successfulPredictions) ?? 0
        avgRrRatio = try container.decodeIfPresent(Double.self, forKey: .avgRrRatio)
        winStreak = try container.decodeIfPresent(Int.self, forKey: .winStreak) ?? 0
        lossStreak = try container.decodeIfPresent(Int.self, forKey: .lossStreak) ?? 0
        bestWinStreak = try container.decodeIfPresent(Int.self, forKey: .bestWinStreak) ?? 0
        rollingAccuracy30d = try container.decodeIfPresent(Double.self, forKey: .rollingAccuracy30d)
        rollingWins30d = try container.decodeIfPresent(Int.self, forKey: .rollingWins30d) ?? 0
        rollingTotal30d = try container.decodeIfPresent(Int.self, forKey: .rollingTotal30d) ?? 0
        accuracyTrend30d = try container.decodeIfPresent([RLAccuracyTrendPointDTO].self, forKey: .accuracyTrend30d) ?? []
        rankInGuild = try container.decodeIfPresent(Int.self, forKey: .rankInGuild)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(guildId, forKey: .guildId)
        try container.encode(accuracyRate, forKey: .accuracyRate)
        try container.encode(totalPredictions, forKey: .totalPredictions)
        try container.encode(successfulPredictions, forKey: .successfulPredictions)
        try container.encodeIfPresent(avgRrRatio, forKey: .avgRrRatio)
        try container.encode(winStreak, forKey: .winStreak)
        try container.encode(lossStreak, forKey: .lossStreak)
        try container.encode(bestWinStreak, forKey: .bestWinStreak)
        try container.encodeIfPresent(rollingAccuracy30d, forKey: .rollingAccuracy30d)
        try container.encode(rollingWins30d, forKey: .rollingWins30d)
        try container.encode(rollingTotal30d, forKey: .rollingTotal30d)
        try container.encode(accuracyTrend30d, forKey: .accuracyTrend30d)
        try container.encodeIfPresent(rankInGuild, forKey: .rankInGuild)
    }

    // MARK: - Computed

    /// Accuracy as percentage string (e.g. "72%")
    var accuracyFormatted: String {
        "\(Int(accuracyRate * 100))%"
    }

    /// Accuracy as decimal percentage string (e.g. "72.5%")
    var accuracyDetailedFormatted: String {
        String(format: "%.1f%%", accuracyRate * 100)
    }

    /// Average R:R ratio formatted (e.g. "2.3:1")
    var rrRatioFormatted: String? {
        guard let rr = avgRrRatio else { return nil }
        return String(format: "%.1f:1", rr)
    }

    /// Rolling 30d accuracy as percentage string
    var rollingAccuracyFormatted: String? {
        guard let rolling = rollingAccuracy30d else { return nil }
        return "\(Int(rolling * 100))%"
    }

    /// Win/loss record string (e.g. "150W / 50L")
    var recordFormatted: String {
        let losses = totalPredictions - successfulPredictions
        return "\(successfulPredictions)W / \(losses)L"
    }

    static func == (lhs: RLAccuracyProfileDTO, rhs: RLAccuracyProfileDTO) -> Bool {
        lhs.userId == rhs.userId && lhs.guildId == rhs.guildId && lhs.accuracyRate == rhs.accuracyRate
    }
}


// MARK: - Accuracy Leaderboard

/// Single member in an accuracy leaderboard.
struct RLAccuracyLeaderboardMemberDTO: Codable, Identifiable, Equatable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let accuracyRate: Double
    let totalPredictions: Int
    let successfulPredictions: Int
    let avgRrRatio: Double?
    let rank: Int

    var id: UUID { userId }

    /// Accuracy as percentage string (e.g. "72%")
    var accuracyFormatted: String {
        "\(Int(accuracyRate * 100))%"
    }

    /// Average R:R ratio formatted (e.g. "2.3:1")
    var rrRatioFormatted: String? {
        guard let rr = avgRrRatio else { return nil }
        return String(format: "%.1f:1", rr)
    }

    static func == (lhs: RLAccuracyLeaderboardMemberDTO, rhs: RLAccuracyLeaderboardMemberDTO) -> Bool {
        lhs.userId == rhs.userId && lhs.rank == rhs.rank
    }
}

/// The period a set of accuracy standings covers.
///
/// The raw values are the server's query-parameter vocabulary, so a case can
/// go straight into a URL without a second mapping table drifting from it.
enum LeaderboardWindow: String, CaseIterable, Identifiable, Equatable {
    case week = "7d"
    case month = "30d"
    case all = "all"

    var id: String { rawValue }

    /// Short enough for a segmented control.
    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .all: return "All time"
        }
    }

    /// Spelled out, for a card caption or a share message.
    var caption: String {
        switch self {
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .all: return "All time"
        }
    }

    /// A rolling window covers far fewer resolutions than a lifetime, so the
    /// bar for appearing has to drop with it or a small guild's week is empty.
    var minimumPredictions: Int {
        switch self {
        case .week: return 1
        case .month: return 2
        case .all: return 10
        }
    }
}

/// Guild accuracy leaderboard response.
struct RLAccuracyLeaderboardDTO: Codable {
    let members: [RLAccuracyLeaderboardMemberDTO]
    let totalMembers: Int
    let minPredictionsThreshold: Int
    /// The period these standings cover — `7d`, `30d` or `all`. Echoed by the
    /// server so a screen showing "Last 7 days" can be sure that is what it
    /// received. Optional: a server predating windows omits it.
    let window: String?
    /// Set when the board was scoped to a single instrument.
    let symbolId: UUID?
}

struct RLGlobalUserLeaderboardMemberDTO: Codable, Identifiable, Equatable {
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let isOnline: Bool
    let globalReputation: Int
    let accuracyRate: Double
    let totalPredictions: Int
    let guildId: UUID?
    let guildName: String?
    let guildRole: String?

    var id: UUID { userId }
}

struct RLGlobalUserLeaderboardDTO: Codable {
    let members: [RLGlobalUserLeaderboardMemberDTO]
    let totalMembers: Int
}


// MARK: - Accuracy WebSocket Payload

/// Published via WebSocket when a user's trading accuracy changes.
/// Sent on user:{user_id}:notifications channel with type "accuracy_update".
struct RLAccuracyUpdatePayload: Codable, Equatable {
    let userId: String
    let guildId: String
    let eventType: String
    let isWin: Bool
    let newAccuracyRate: Double
    let newGlobalAccuracy: Double
    let totalPredictions: Int
    let successfulPredictions: Int
    let winStreak: Int
    let avgRrRatio: Double?

    /// Accuracy as percentage string (e.g. "72%")
    var accuracyFormatted: String {
        "\(Int(newAccuracyRate * 100))%"
    }

    /// Result display string
    var resultDisplay: String {
        isWin ? "Win" : "Loss"
    }

    /// Result color for display
    var resultColor: Color {
        isWin ? .green : .red
    }
}

struct RLGuildMemberPerformanceUpdatePayload: Codable, Equatable {
    let guildId: String
    let membershipId: String
    let userId: String
    let eventType: String
    let newGuildReputation: Int
    let newGlobalReputation: Int
    let newAccuracyRate: Double
    let newGlobalAccuracy: Double
    let totalPredictions: Int
    let successfulPredictions: Int
    let tierLevel: Int
    let tierColorHex: String
    let guildReputation: Int
    let guildTotalPredictions: Int
    let guildCorrectPredictions: Int
    let guildAverageAccuracy: Double
}
