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
    
    
    // ================================================================================================
    // MARK: - Chart - API
    // ================================================================================================
    
    /// Fetch user's personal trading watchlist
    func fetchPersonalWatchlist(userId: UUID) async throws -> [TradingSymbol] {
        try await simulateNetworkDelay()
        return SampleData.personalWatchlist
    }
    
    /// Fetch guild's trading watchlist (RENAMED to avoid conflict)
    func fetchChartGuildWatchlist(guildId: UUID) async throws -> [TradingSymbol] {
        try await simulateNetworkDelay()
        return SampleData.chartGuildWatchlist  // UPDATED: Using renamed property
    }
    
    /// Search for trading symbols by query
    func searchSymbols(query: String) async throws -> [TradingSymbol] {
        try await simulateNetworkDelay()
        
        let lowercasedQuery = query.lowercased()
        return SampleData.allTradingSymbols.filter { symbol in
            symbol.symbol.lowercased().contains(lowercasedQuery) ||
            symbol.displayName.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Add symbol to user's watchlist
    func addToWatchlist(userId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        // TODO: Implement real API call when backend is ready
        print("Added symbol \(symbolId) to user \(userId) watchlist")
    }
    
    /// Remove symbol from user's watchlist
    func removeFromWatchlist(userId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        // TODO: Implement real API call when backend is ready
        print("Removed symbol \(symbolId) from user \(userId) watchlist")
    }
    
    /// Fetch historical candles for a symbol
    /// TODO: Replace with real API call when backend is ready
    func fetchHistoricalCandles(
        symbol: String,
        timeframe: ChartTimeframe,
        limit: Int = 200
    ) async throws -> [Candle] {
        try await simulateNetworkDelay()
        
        // For now, generate mock data
        // When backend is ready, this will make a real API call
        return Candle.generateSampleData(count: limit)
    }
    
    
    
    
    
    // MARK: - Chart Chat API
    
    /// Fetch or create a chart chat for a specific symbol and guild
    func fetchOrCreateChartChat(symbolId: UUID, guildId: UUID) async throws -> ChartChatDTO {
        try await simulateNetworkDelay()
        
        // Mock: Return chart chat for this symbol/guild combo
        // In production, this would fetch from backend or create if doesn't exist
        return SampleData.chartChatForSymbol(symbolId: symbolId, guildId: guildId)
    }
    
    /// Fetch messages for a chart chat
    func fetchChartChatMessages(chatId: UUID) async throws -> [ChartChatMessageDTO] {
        try await simulateNetworkDelay()
        
        // Mock: Return sample messages
        return SampleData.chartChatMessages
    }
    
    /// Send a new message to a chart chat
    func sendChartChatMessage(chatId: UUID, content: String, authorId: UUID) async throws -> ChartChatMessageDTO {
        try await simulateNetworkDelay()
        
        // Mock: Create and return new message
        return SampleData.createChartChatMessage(
            chatId: chatId,
            content: content,
            authorId: authorId
        )
    }
    
    /// Edit an existing chart chat message
    func editChartChatMessage(messageId: UUID, newContent: String, chatId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful edit
    }
    
    /// Delete a chart chat message
    func deleteChartChatMessage(messageId: UUID, chatId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful delete
    }
    
    /// Mark chart chat as read
    func markChartChatAsRead(chatId: UUID, userId: UUID) async throws {
        try await simulateNetworkDelay()
        // Mock: successful mark as read
    }

    

    // ================================================================================================
    // MARK: - Chart Markers - API
    // ================================================================================================
    
    /// Fetch chart markers for a specific symbol and guild
    func fetchGuildChartMarkers(
        symbol: String,
        guildId: UUID,
        timeframe: ChartTimeframe,
        candleCount: Int
    ) async throws -> [ChartMarker] {
        try await simulateNetworkDelay()
        return SampleData.generateChartMarkers(
            forSymbol: symbol,
            guildId: guildId.uuidString,
            candleCount: candleCount
        )
    }
    
    /// Fetch markers for a specific user
    func fetchUserChartMarkers(
        userId: UUID,
        symbol: String,
        guildId: UUID
    ) async throws -> [ChartMarker] {
        try await simulateNetworkDelay()
        let allMarkers = SampleData.generateChartMarkers(
            forSymbol: symbol,
            guildId: guildId.uuidString,
            candleCount: 200
        )
        return allMarkers.filter { $0.userId == userId.uuidString }
    }
    
    /// Post a new marker to the backend
    func postChartMarker(_ marker: ChartMarker) async throws -> ChartMarker {
        try await simulateNetworkDelay()
        return marker
    }
    
    /// Delete a marker
    func deleteChartMarker(markerId: UUID, guildId: UUID) async throws {
        try await simulateNetworkDelay()
    }
    
    /// Update a marker (edit note, etc.)
    func updateChartMarker(_ marker: ChartMarker) async throws -> ChartMarker {
        try await simulateNetworkDelay()
        return marker
    }
    
    /// Toggle like on a marker
    func toggleMarkerLike(markerId: UUID, userId: UUID) async throws -> (likeCount: Int, isLiked: Bool) {
        try await simulateNetworkDelay()
        let newLikeCount = Int.random(in: 1...15)
        return (newLikeCount, true)
    }
    
    // MARK: - Marker Comments API
    
    /// Add a comment to a marker
    func addMarkerComment(
        markerId: UUID,
        userId: UUID,
        username: String,
        text: String
    ) async throws -> MarkerComment {
        try await simulateNetworkDelay()
        
        return MarkerComment(
            id: UUID(),
            userId: userId.uuidString,
            username: username,
            text: text,
            createdAt: Date()
        )
    }
    
    /// Delete a comment from a marker
    func deleteMarkerComment(
        markerId: UUID,
        commentId: UUID
    ) async throws {
        try await simulateNetworkDelay()
        // Mock: successful delete
    }
    
    /// Edit a comment on a marker
    func editMarkerComment(
        markerId: UUID,
        commentId: UUID,
        newText: String
    ) async throws -> MarkerComment {
        try await simulateNetworkDelay()
        
        // Mock: return updated comment
        return MarkerComment(
            id: commentId,
            userId: SampleData.currentUser.id.uuidString,
            username: SampleData.currentUser.name,
            text: newText,
            createdAt: Date()
        )
    }
    
    /// Fetch comments for a marker (if loading separately from marker)
    func fetchMarkerComments(markerId: UUID) async throws -> [MarkerComment] {
        try await simulateNetworkDelay()
        return SampleData.generateMarkerComments()
    }
    
    /// Report a marker
    func reportMarker(
        markerId: UUID,
        userId: UUID,
        reason: String
    ) async throws {
        try await simulateNetworkDelay()
        // Mock: successful report
    }
    
    /// Share a marker (get shareable link/data)
    func shareMarker(markerId: UUID) async throws -> String {
        try await simulateNetworkDelay()
        return "https://tradersguild.app/marker/\(markerId.uuidString)"
    }

}

// ================================================================================================
// MARK: - Response Models
// ================================================================================================

struct authResponse {
    let user: CurrentUserDTO
    let token: String
}







