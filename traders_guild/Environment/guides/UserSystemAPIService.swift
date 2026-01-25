//
//  UserSystemAPIService.swift
//  traders_guild
//
//  API service methods for User System: Members, Profiles, Awards, Friends, Blocks
//  Add these methods to your existing RealAPIService.swift
//
//  ALL ENDPOINTS MATCH FINALIZED BACKEND:
//  - users.py (routes)
//  - guilds.py (member routes)
//  - awards.py (award type routes)
//

import Foundation

// ================================================================================================
// MARK: - Add to RealAPIService.swift
// ================================================================================================

extension RealAPIService {
    
    
}


// ================================================================================================
// MARK: - APIServiceProtocol Extension (Add to protocol if using protocol-based approach)
// ================================================================================================

/*
 If you're using a protocol-based approach, add these to your APIServiceProtocol:
 
 protocol APIServiceProtocol {
     // ... existing methods ...
     
     // Guild Members
     func getGuildMembers(guildId: UUID, skip: Int, limit: Int, search: String?) async throws -> RLGuildMembersListDTO
     func getGuildMember(guildId: UUID, userId: UUID) async throws -> RLGuildMemberDTO
     
     // User Profile
     func getCurrentUserFullProfile(guildId: UUID?) async throws -> RLUserFullProfileDTO
     func getCurrentUserExtendedProfile() async throws -> RLUserProfileDTO
     func updateCurrentUserProfile(_ request: RLUserProfileUpdateRequest) async throws -> RLUserProfileDTO
     func getCurrentUserStatistics() async throws -> RLUserGlobalStatisticsDTO
     func getUserProfile(userId: UUID, guildId: UUID?) async throws -> RLUserFullProfileDTO
     
     // Awards
     func getCurrentUserAwards(guildId: UUID?) async throws -> RLUserAwardsListDTO
     func getCurrentUserAwardsSummary(guildId: UUID?) async throws -> RLAwardsSummaryDTO
     func markAwardAsSeen(awardId: UUID) async throws -> RLDetailResponseDTO
     func getAwardTypes(category: String?) async throws -> [RLAwardTypeDTO]
     func getAwardType(awardId: UUID) async throws -> RLAwardTypeDTO
     
     // Friends
     func getFriends(guildId: UUID?) async throws -> RLFriendsListDTO
     func getFriendRequests(guildId: UUID?) async throws -> RLFriendRequestsListDTO
     func sendFriendRequest(toMembershipId: UUID, message: String?) async throws -> RLFriendshipResponseDTO
     func acceptFriendRequest(requestId: UUID) async throws -> RLFriendshipResponseDTO
     func declineFriendRequest(requestId: UUID) async throws -> RLDetailResponseDTO
     func removeFriend(membershipId: UUID) async throws -> RLDetailResponseDTO
     
     // Blocks
     func getBlockedUsers(guildId: UUID?) async throws -> RLBlockedUsersListDTO
     func blockUser(membershipId: UUID) async throws -> RLDetailResponseDTO
     func unblockUser(membershipId: UUID) async throws -> RLDetailResponseDTO
 }
 */


// ================================================================================================
// MARK: - MockAPIService Extension (for SwiftUI Previews)
// ================================================================================================

#if DEBUG
extension MockAPIService {
    
    // MARK: - Guild Members
    
    func getGuildMembers(guildId: UUID, skip: Int = 0, limit: Int = 50, search: String? = nil) async throws -> RLGuildMembersListDTO {
        return RLGuildMembersListDTO(
            members: [
                RLGuildMemberDTO(
                    membershipId: UUID(),
                    role: "admin",
                    reputation: 500,
                    contributionScore: 150,
                    dateJoined: Date().addingTimeInterval(-86400 * 90),
                    userId: UUID(),
                    username: "trader_pro",
                    displayName: "Professional Trader",
                    avatarUrl: nil,
                    isOnline: true,
                    globalReputation: 1500,
                    isFriend: true,
                    friendshipStatus: "accepted",
                    isBlocked: false,
                    isBlockedBy: false
                ),
                RLGuildMemberDTO(
                    membershipId: UUID(),
                    role: "member",
                    reputation: 100,
                    contributionScore: 25,
                    dateJoined: Date().addingTimeInterval(-86400 * 30),
                    userId: UUID(),
                    username: "new_trader",
                    displayName: "New Trader",
                    avatarUrl: nil,
                    isOnline: false,
                    globalReputation: 250,
                    isFriend: false,
                    friendshipStatus: nil,
                    isBlocked: false,
                    isBlockedBy: false
                ),
                RLGuildMemberDTO(
                    membershipId: UUID(),
                    role: "moderator",
                    reputation: 300,
                    contributionScore: 75,
                    dateJoined: Date().addingTimeInterval(-86400 * 60),
                    userId: UUID(),
                    username: "chart_master",
                    displayName: "Chart Master",
                    avatarUrl: nil,
                    isOnline: true,
                    globalReputation: 800,
                    isFriend: false,
                    friendshipStatus: "pending_sent",
                    isBlocked: false,
                    isBlockedBy: false
                )
            ],
            totalCount: 3,
            onlineCount: 2
        )
    }
    
    func getGuildMember(guildId: UUID, userId: UUID) async throws -> RLGuildMemberDTO {
        return RLGuildMemberDTO(
            membershipId: UUID(),
            role: "member",
            reputation: 200,
            contributionScore: 50,
            dateJoined: Date().addingTimeInterval(-86400 * 60),
            userId: userId,
            username: "sample_user",
            displayName: "Sample User",
            avatarUrl: nil,
            isOnline: true,
            globalReputation: 500,
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false
        )
    }
    
    // MARK: - Profile
    
    func getCurrentUserFullProfile(guildId: UUID? = nil) async throws -> RLUserFullProfileDTO {
        return RLUserFullProfileDTO(
            userId: UUID(),
            username: "current_user",
            displayName: "Current User",
            avatarUrl: nil,
            globalReputation: 1000,
            isOnline: true,
            isVerified: true,
            createdAt: Date().addingTimeInterval(-86400 * 365),
            profile: RLUserProfileDTO(
                userId: UUID(),
                bio: "Forex trader with 5 years experience. Specializing in EUR/USD and GBP/JPY pairs.",
                location: "London, UK",
                timezone: "GMT+0",
                experienceLevel: "advanced",
                tradingStyle: "Day Trader",
                preferredPairs: ["EUR/USD", "GBP/JPY", "USD/CHF"],
                socialLinks: [
                    RLSocialLinkItem(platform: "twitter", username: "trader123", url: nil),
                    RLSocialLinkItem(platform: "tradingview", username: "trader123", url: nil)
                ],
                tradingInterests: [
                    RLTradingInterestItem(name: "Forex", icon: "dollarsign.circle.fill", isPrimary: true),
                    RLTradingInterestItem(name: "Crypto", icon: "bitcoinsign.circle.fill", isPrimary: false)
                ],
                isProfilePublic: true,
                showOnlineStatus: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            statistics: RLUserGlobalStatisticsDTO(
                userId: UUID(),
                totalMarkersPlaced: 150,
                successfulMarkers: 105,
                accuracyRate: 0.70,
                totalLikesReceived: 250,
                totalCommentsMade: 80,
                currentStreakDays: 7,
                bestStreakDays: 21,
                totalGuildsJoined: 3,
                totalAwardsEarned: 12,
                totalAwardPoints: 450,
                topSymbols: ["EUR/USD", "GBP/JPY", "BTC/USD"],
                markersByType: ["buy": 80, "sell": 70],
                lastCalculatedAt: Date()
            ),
            awardsSummary: RLAwardsSummaryDTO(
                totalAwards: 12,
                totalPoints: 450,
                rarityBreakdown: ["common": 5, "uncommon": 4, "rare": 2, "epic": 1],
                recentAwards: []
            ),
            isFriend: false,
            friendshipStatus: nil,
            isBlocked: false,
            isBlockedBy: false,
            guildMembership: nil
        )
    }
    
    func getCurrentUserExtendedProfile() async throws -> RLUserProfileDTO {
        return RLUserProfileDTO(
            userId: UUID(),
            bio: "Forex trader with 5 years experience",
            location: "London, UK",
            timezone: "GMT+0",
            experienceLevel: "advanced",
            tradingStyle: "Day Trader",
            preferredPairs: ["EUR/USD", "GBP/JPY"],
            socialLinks: [],
            tradingInterests: [
                RLTradingInterestItem(name: "Forex", icon: "dollarsign.circle.fill", isPrimary: true)
            ],
            isProfilePublic: true,
            showOnlineStatus: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func updateCurrentUserProfile(_ request: RLUserProfileUpdateRequest) async throws -> RLUserProfileDTO {
        return try await getCurrentUserExtendedProfile()
    }
    
    func getCurrentUserStatistics() async throws -> RLUserGlobalStatisticsDTO {
        return RLUserGlobalStatisticsDTO(
            userId: UUID(),
            totalMarkersPlaced: 150,
            successfulMarkers: 105,
            accuracyRate: 0.70,
            totalLikesReceived: 250,
            totalCommentsMade: 80,
            currentStreakDays: 7,
            bestStreakDays: 21,
            totalGuildsJoined: 3,
            totalAwardsEarned: 12,
            totalAwardPoints: 450,
            topSymbols: ["EUR/USD", "GBP/JPY", "BTC/USD"],
            markersByType: ["buy": 80, "sell": 70],
            lastCalculatedAt: Date()
        )
    }
    
    func getUserProfile(userId: UUID, guildId: UUID? = nil) async throws -> RLUserFullProfileDTO {
        return try await getCurrentUserFullProfile(guildId: guildId)
    }
    
    // MARK: - Awards
    
    func getCurrentUserAwards(guildId: UUID? = nil) async throws -> RLUserAwardsListDTO {
        return RLUserAwardsListDTO(awards: [
            RLUserAwardDTO(
                id: UUID(),
                membershipId: UUID(),
                guildId: guildId ?? UUID(),
                awardTypeId: UUID(),
                name: "First Prediction",
                description: "Made your first market prediction",
                icon: "chart.line.uptrend.xyaxis",
                category: "milestones",
                rarity: "common",
                pointsValue: 10,
                progress: nil,
                currentValue: nil,
                isNew: true,
                earnedAt: Date().addingTimeInterval(-86400 * 5)
            ),
            RLUserAwardDTO(
                id: UUID(),
                membershipId: UUID(),
                guildId: guildId ?? UUID(),
                awardTypeId: UUID(),
                name: "Streak Master",
                description: "Maintain a 7-day prediction streak",
                icon: "flame.fill",
                category: "trading",
                rarity: "rare",
                pointsValue: 50,
                progress: 0.7,
                currentValue: 5,
                isNew: false,
                earnedAt: Date()
            )
        ])
    }
    
    func getCurrentUserAwardsSummary(guildId: UUID? = nil) async throws -> RLAwardsSummaryDTO {
        return RLAwardsSummaryDTO(
            totalAwards: 12,
            totalPoints: 450,
            rarityBreakdown: ["common": 5, "uncommon": 4, "rare": 2, "epic": 1],
            recentAwards: []
        )
    }
    
    func markAwardAsSeen(awardId: UUID) async throws -> RLDetailResponseDTO {
        return RLDetailResponseDTO(detail: "Award marked as seen")
    }
    
    func getAwardTypes(category: String? = nil) async throws -> [RLAwardTypeDTO] {
        return [
            RLAwardTypeDTO(
                id: UUID(),
                name: "First Prediction",
                description: "Made your first market prediction",
                icon: "chart.line.uptrend.xyaxis",
                category: "milestones",
                rarity: "common",
                pointsValue: 10,
                requiredValue: 1
            ),
            RLAwardTypeDTO(
                id: UUID(),
                name: "Streak Master",
                description: "Maintain a 7-day prediction streak",
                icon: "flame.fill",
                category: "trading",
                rarity: "rare",
                pointsValue: 50,
                requiredValue: 7
            )
        ]
    }
    
    func getAwardType(awardId: UUID) async throws -> RLAwardTypeDTO {
        return RLAwardTypeDTO(
            id: awardId,
            name: "First Prediction",
            description: "Made your first market prediction",
            icon: "chart.line.uptrend.xyaxis",
            category: "milestones",
            rarity: "common",
            pointsValue: 10,
            requiredValue: 1
        )
    }
    
    // MARK: - Friends
    
    func getFriends(guildId: UUID? = nil) async throws -> RLFriendsListDTO {
        return RLFriendsListDTO(
            friends: [
                RLFriendDTO(
                    friendshipId: UUID(),
                    membershipId: UUID(),
                    userId: UUID(),
                    username: "friend_one",
                    displayName: "Friend One",
                    avatarUrl: nil,
                    isOnline: true,
                    globalReputation: 500,
                    friendsSince: Date().addingTimeInterval(-86400 * 30)
                ),
                RLFriendDTO(
                    friendshipId: UUID(),
                    membershipId: UUID(),
                    userId: UUID(),
                    username: "friend_two",
                    displayName: "Friend Two",
                    avatarUrl: nil,
                    isOnline: false,
                    globalReputation: 300,
                    friendsSince: Date().addingTimeInterval(-86400 * 60)
                )
            ],
            totalCount: 2,
            onlineCount: 1
        )
    }
    
    func getFriendRequests(guildId: UUID? = nil) async throws -> RLFriendRequestsListDTO {
        return RLFriendRequestsListDTO(
            incoming: [
                RLFriendRequestIncomingDTO(
                    id: UUID(),
                    fromMembershipId: UUID(),
                    fromUserId: UUID(),
                    fromUsername: "requester",
                    fromDisplayName: "Friend Requester",
                    fromAvatarUrl: nil,
                    message: "Let's trade together!",
                    createdAt: Date().addingTimeInterval(-3600)
                )
            ],
            outgoing: [
                RLFriendRequestOutgoingDTO(
                    id: UUID(),
                    toMembershipId: UUID(),
                    toUserId: UUID(),
                    toUsername: "pending_friend",
                    toDisplayName: "Pending Friend",
                    toAvatarUrl: nil,
                    message: nil,
                    createdAt: Date().addingTimeInterval(-7200)
                )
            ]
        )
    }
    
    func sendFriendRequest(toMembershipId: UUID, message: String? = nil) async throws -> RLFriendshipResponseDTO {
        return RLFriendshipResponseDTO(
            id: UUID(),
            requesterMembershipId: UUID(),
            addresseeMembershipId: toMembershipId,
            status: "pending",
            message: message,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func acceptFriendRequest(requestId: UUID) async throws -> RLFriendshipResponseDTO {
        return RLFriendshipResponseDTO(
            id: requestId,
            requesterMembershipId: UUID(),
            addresseeMembershipId: UUID(),
            status: "accepted",
            message: nil,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date()
        )
    }
    
    func declineFriendRequest(requestId: UUID) async throws -> RLDetailResponseDTO {
        return RLDetailResponseDTO(detail: "Friend request declined")
    }
    
    func removeFriend(membershipId: UUID) async throws -> RLDetailResponseDTO {
        return RLDetailResponseDTO(detail: "Friendship removed")
    }
    
    // MARK: - Blocks
    
    func getBlockedUsers(guildId: UUID? = nil) async throws -> RLBlockedUsersListDTO {
        return RLBlockedUsersListDTO(
            blockedUsers: [
                RLBlockedUserDTO(
                    blockId: UUID(),
                    membershipId: UUID(),
                    userId: UUID(),
                    username: "blocked_user",
                    displayName: "Blocked User",
                    avatarUrl: nil,
                    blockedAt: Date().addingTimeInterval(-86400 * 7)
                )
            ],
            totalCount: 1
        )
    }
    
    func blockUser(membershipId: UUID) async throws -> RLDetailResponseDTO {
        return RLDetailResponseDTO(detail: "User blocked")
    }
    
    func unblockUser(membershipId: UUID) async throws -> RLDetailResponseDTO {
        return RLDetailResponseDTO(detail: "User unblocked")
    }
}
#endif
