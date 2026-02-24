//
//  UserSystemAPIService.swift
//  traders_guild
//
//  API service guide for User System: Members, Profiles, Awards, Friends, Blocks
//  Add these methods to your existing RealAPIService.swift if needed.
//

import Foundation

// ================================================================================================
// MARK: - Add to RealAPIService.swift
// ================================================================================================

extension RealAPIService {
    // Guide file intentionally left empty.
}

// ================================================================================================
// MARK: - APIServiceProtocol Extension (if using protocol-based approach)
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

