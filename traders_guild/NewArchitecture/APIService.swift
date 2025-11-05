//
//  APIService.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//


import Foundation

class MockAPIService {
    
    // Simulate network delay
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    // ================================================================================================
    // MARK: - Authentication - API
    // ================================================================================================
    
    func signUp(data: SignupData) async throws -> authResponse {
        try await simulateNetworkDelay()
        
        // Mock successful signup
        return authResponse(
            user: SampleData.currentUser,
            token: "mock-jwt-token-\(UUID().uuidString)"
        )
    }
    
    func login(email: String, password: String) async throws -> authResponse {
        try await simulateNetworkDelay()
        
        // ✅ Mock successful login with sample data
        return authResponse(
            user: SampleData.currentUser,
            token: "mock-jwt-token-\(UUID().uuidString)"
        )
    }
    
    // ================================================================================================
    // MARK: - Guild Management - API
    // ================================================================================================
    
    /// fetch all open guilds for signup that require no authentication
    func fetchOpenGuilds() async throws -> [GuildDTO] {
        try await simulateNetworkDelay()
        return SampleData.openGuilds
    }
    
    /// Fetch guilds user is joined
    func fetchUserGuilds() async throws -> [GuildDTO] {
        try await simulateNetworkDelay()
        // ✅ Return guilds the user is a member of
        return SampleData.userGuilds  // User is member of this guild
    }
    
    /// Fetch guilds user is joined
    func fetchUserGuildMemberships() async throws -> [GuildMembershipDTO] {
        try await simulateNetworkDelay()
        // ✅ Return guilds the user is a member of
        return SampleData.userMembershipGuilds  // User is member of this guild
    }
    
    func fetchGuildById(guildId: UUID) async throws -> GuildMembershipDTO? {
        try await simulateNetworkDelay()
        
        // Return mock guild with matching ID
        //        return SampleData.openGuilds.first { $0.id == guildId }
        //            ?? SampleData.sampleGuild
        return SampleData.sampleGuild
    }
    
    func joinGuild(guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful join
    }
    
    func leaveGuild(guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful leave
    }
    
    
    func fetchGuildAnnouncements(guildId: UUID) async throws -> [GuildAnnouncementDTO] {
        try await simulateNetworkDelay()
        return SampleData.announcements
    }
    
    func fetchGuildEvents(guildId: UUID) async throws -> [GuildEventDTO] {
        try await simulateNetworkDelay()
        return SampleData.events
    }
    
    func fetchGuildMembers(guildId: UUID) async throws -> [GuildMembershipDTO] {
        try await simulateNetworkDelay()
        return SampleData.guildMemberships
    }
    
    func fetchGuildWatchlist(guildId: UUID) async throws -> GuildWatchlistDTO {
        try await simulateNetworkDelay()
        return SampleData.guildWatchlist
    }
    
    func fetchUserNotifications(guildId: UUID, userId: UUID) async throws -> [GuildNotificationDTO] {
        try await simulateNetworkDelay()
        return SampleData.userNotifications
    }
    
    func fetchGuildStatistics(guildId: UUID) async throws -> GuildStatisticsDTO {
        try await simulateNetworkDelay()
        return SampleData.guildStatistics
    }
    
    // ================================================================================================
    // MARK: - Announcement - API
    // ================================================================================================
    
    func recordAnnouncementView(announcementId: UUID, userId: UUID, guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: record announcement view
    }
    
    
    // ================================================================================================
    // MARK: - Event - API
    // ================================================================================================
    
    func attendEvent(eventId: UUID, userId: UUID, guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: attend event
    }
    
    func unAttendEvent(eventId: UUID, userId: UUID, guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: un attend event
    }
    
    func shareEvent(eventId: UUID, userId: UUID, guildId: UUID, friendId: String) async throws {
        try await simulateNetworkDelay()
        // Mock: Share event
    }
    
    func recordEventView(eventId: UUID, userId: UUID, guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: record event view
    }
    
    
    // ================================================================================================
    // MARK: - Notification - API
    // ================================================================================================
    
    func recordNotificationView(notificationId: UUID, userId: UUID, guildId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: record notification view
    }
    
    
    // ================================================================================================
    // MARK: - Messaging - API
    // ================================================================================================
    
    /// UserDM
    func fetchOrCreateUserDM(userId: UUID) async throws -> DMDTO {
        try await simulateNetworkDelay()
        return SampleData.userDMbyUserId
    }
    
    /// Chatroom
    func fetchChatroomById(chatroomId: UUID) async throws -> GuildChatroomDTO {
        try await simulateNetworkDelay()
        return SampleData.chatroomByChatroomId
    }
    
    func fetchDMMessagesByDmId(dmId: UUID) async throws -> [DMMessageDTO] {
        try await simulateNetworkDelay()
        return SampleData.dmMessages
    }
    
    func fetchGuildChatrooms(guildId: UUID) async throws -> [GuildChatroomDTO] {
        try await simulateNetworkDelay()
        return SampleData.allGuildChatrooms
    }
    
    func fetchChatroomMessagesByChatroomId(chatroomId: UUID) async throws -> [ChatroomMessageDTO] {
        try await simulateNetworkDelay()
        return SampleData.chatroomMessages
    }
    
    func fetchGuildFriendDM(guildId: UUID) async throws -> [DMDTO] {
        try await simulateNetworkDelay()
        return SampleData.allGuildFriendDM
    }
    
    func fetchGuildOnlineNonFriendDM(guildId: UUID) async throws -> [DMDTO] {
        try await simulateNetworkDelay()
        return SampleData.allGuildOnlineNonFriendDM
    }
    
    func fetchGuildOfflineNonFriendDM(guildId: UUID) async throws -> [DMDTO] {
        try await simulateNetworkDelay()
        return SampleData.allGuildOfflineNonFriendDM
    }
    
    func sendChatroomMessage(chatroomId: UUID, userId: UUID, content: String) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func sendDMMessage(dmId: UUID, userId: UUID, content: String) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func deleteChatroomMessage(messageId: UUID, userId: UUID, chatroomId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func reportChatroomMessage(messageId: UUID, userId: UUID, chatroomId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func editChatroomMessage(messageId: UUID, userId: UUID, chatroomId: UUID, newContent: String) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func deleteDMMessage(messageId: UUID, userId: UUID, dmId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func editDMMessage(messageId: UUID, userId: UUID, dmId: UUID, newContent: String) async throws {
        try await simulateNetworkDelay()
        // Mock: send message
    }
    
    func deleteDMMessagesEntire(guildId: UUID, userId: UUID, dmId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: delete entire messages for dm
    }
    
    func reportChatroom(guildId: UUID, chatroomId: UUID, userId: UUID, reason: String) async throws {
        try await simulateNetworkDelay()
        // Mock: delete entire messages for dm
    }
    
    func markDMAsRead(guildId: UUID, userId: UUID, dmId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: mark dm as read
    }
    
    func markChatroomAsRead(guildId: UUID, chatroomId: UUID, userId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: mark chatroom as read
    }
    
    // ================================================================================================
    // MARK: - User Management - API
    // ================================================================================================
    
    func blockUser(userId: UUID, guildId: UUID, currentUserId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful block user
    }
    
    func unBlockUser(userId: UUID, guildId: UUID, currentUserId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful join
    }
    
    func sendFriendRequest(userId: UUID, guildId: UUID, currentUserId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful send friend request
    }
    
    func sendCancelFriendship(userId: UUID, guildId: UUID, currentUserId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful end friendship
    }
    
    func reportUser(userId: UUID, guildId: UUID, currentUserId: UUID, reason: String) async throws {
        try await simulateNetworkDelay()
        // Mock: successful report
    }

}

// ================================================================================================
// MARK: - Response Models
// ================================================================================================

struct authResponse {
    let user: CurrentUserDTO
    let token: String
}

