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
//    func fetchUserGuilds() async throws -> [GuildDTO] {
//        try await simulateNetworkDelay()
//        // ✅ Return guilds the user is a member of
//        return SampleData.userGuilds  // User is member of this guild
//    }
    
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
    func fetchPersonalWatchlist(userId: UUID) async throws -> [TradingSymbolDTO] {
        try await simulateNetworkDelay()
        return SampleData.personalWatchlistDTOs
    }
    
    /// Fetch guild's trading watchlist (RENAMED to avoid conflict)
    func fetchChartGuildWatchlist(guildId: UUID) async throws -> [TradingSymbolDTO] {
        try await simulateNetworkDelay()
        return SampleData.chartGuildWatchlistDTOs  // UPDATED: Using renamed property
    }
    
    /// Search for trading symbols by query
    func searchSymbols(query: String) async throws -> [TradingSymbolDTO] {
        try await simulateNetworkDelay()
        
        let lowercasedQuery = query.lowercased()
        return SampleData.allTradingSymbolDTOs.filter { symbol in
            symbol.ticker.lowercased().contains(lowercasedQuery) ||
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
    ) async throws -> [CandleDTO] {
        try await simulateNetworkDelay()
        
        // For now, generate mock data
        // When backend is ready, this will make a real API call
        return CandleDTO.generateSampleData(count: limit)
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

    /// Fetch chart markers as DTOs (replaces legacy fetchGuildChartMarkers)
    func fetchGuildChartMarkerDTOs(
        symbol: String,
        guildId: UUID,
        timeframe: ChartTimeframe,
        candleCount: Int
    ) async throws -> [ChartMarkerDTO] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Generate sample markers
        let symbolId = SampleData.allTradingSymbolDTOs.first { $0.ticker == symbol }?.id ?? UUID()
        let currentUserId = SampleData.currentUser.id
        
        return SampleData.generateChartMarkerDTOs(
            forSymbol: symbol,
            symbolId: symbolId,
            guildId: guildId,
            candleCount: candleCount,
            currentUserId: currentUserId,
            count: 8
        )
    }
    
    /// Add a comment to a marker
    func addMarkerCommentDTO(
        markerId: UUID,
        content: String
    ) async throws -> MarkerCommentDTO {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        return MarkerCommentDTO(
            id: UUID(),
            markerId: markerId,
            author: SampleData.currentUser.guildMembership,
            content: content,
            timestamp: Date(),
            timestampFormatted: "Just now",
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true
        )
    }
    
    /// Edit a marker comment
    func editMarkerCommentDTO(
        markerId: UUID,
        commentId: UUID,
        newContent: String
    ) async throws -> MarkerCommentDTO {
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        return MarkerCommentDTO(
            id: commentId,
            markerId: markerId,
            author: SampleData.currentUser.guildMembership,
            content: newContent,
            timestamp: Date(),
            timestampFormatted: formatter.localizedString(for: Date(), relativeTo: Date()),
            isEdited: true,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true
        )
    }
    
    /// Delete a marker comment
    func deleteMarkerCommentDTO(markerId: UUID, commentId: UUID) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        // In real impl, would delete from backend
    }
    
    /// Toggle like on a marker
    func toggleMarkerLike(markerId: UUID) async throws -> (isLiked: Bool, likeCount: Int) {
        try await Task.sleep(nanoseconds: 100_000_000)
        // Return toggled state - in real impl would come from backend
        return (true, Int.random(in: 1...20))
    }
    
    /// Create a new marker
    func createChartMarkerDTO(
        symbolId: UUID,
        guildId: UUID,
        candleIndex: Int,
        timestamp: Date,
        price: Double,
        type: MarkerType,
        note: String?
    ) async throws -> ChartMarkerDTO {
        try await Task.sleep(nanoseconds: 150_000_000)
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        return ChartMarkerDTO(
            id: UUID(),
            symbolId: symbolId,
            guildId: guildId,
            author: SampleData.currentUser.guildMembership,
            candleIndex: candleIndex,
            timestamp: timestamp,
            price: price,
            type: type,
            note: note,
            createdAt: Date(),
            createdAtFormatted: "Just now",
            isVisible: true,
            likeCount: 0,
            isLikedByCurrentUser: false,
            commentCount: 0,
            comments: [],
            isCurrentUserMarker: true,
            canEdit: true,
            canDelete: true,
            positionedBelow: false,
            proximityTier: 0,
            stackIndex: 0,
            horizontalLinePrice: type.hasHorizontalLine ? price : nil,
            targetPrice: nil,
            alertSeverity: nil,
            trendlineDirection: nil,
            selectedIndicator: nil,
            chartPattern: nil,
            selectedEmoji: nil,
            pollQuestion: nil,
            pollOptions: nil,
            userPollVote: nil
        )
    }
    
    /// Delete a marker
    func deleteChartMarkerDTO(markerId: UUID) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        // In real impl, would delete from backend
    }
    
    /// Update a marker's note
    func updateChartMarkerDTO(markerId: UUID, note: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        // In real impl, would update backend
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
    
    


    // MARK: - Guild Trading Watchlist (TradingSymbolDTO)
    
    /// Fetch guild's trading watchlist as TradingSymbolDTOs (for chart-style display)
    func fetchGuildTradingWatchlist(guildId: UUID) async throws -> [TradingSymbolDTO] {
        try await simulateNetworkDelay()
        return SampleData.chartGuildWatchlistDTOs
    }
    
    /// Add symbol to guild watchlist
    func addToGuildWatchlist(guildId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        // TODO: Implement real API call when backend is ready
        print("API: Added symbol \(symbolId) to guild \(guildId) watchlist")
    }
    
    /// Remove symbol from guild watchlist
    func removeFromGuildWatchlist(guildId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        // TODO: Implement real API call when backend is ready
        print("API: Removed symbol \(symbolId) from guild \(guildId) watchlist")
    }
    
    /// Add symbol to user's personal watchlist
    func addToPersonalWatchlist(userId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        // TODO: Implement real API call when backend is ready
        print("API: Added symbol \(symbolId) to user \(userId) personal watchlist")
    }
    
    /// Remove symbol from user's personal watchlist
    func removeFromPersonalWatchlist(userId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        // TODO: Implement real API call when backend is ready
        print("API: Removed symbol \(symbolId) from user \(userId) personal watchlist")
    }
    
    func requestGuildWatchlistAddition(guildId: UUID, userId: UUID, symbolId: UUID) async throws {
        try await simulateNetworkDelay()
        print("API: User \(userId) requested to add symbol \(symbolId) to guild \(guildId) watchlist")
    }

}

// ================================================================================================
// MARK: - Response Models
// ================================================================================================

struct authResponse {
    let user: CurrentUserDTO
    let token: String
}







