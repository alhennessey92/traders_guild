//
//  ChartChatManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/12/2025.
//

//
//  ChartChatManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 14/12/2025.
//
//  Manages chart-specific chats tied to symbols and guilds
//  Follows the same architecture patterns as MessagingManager

import SwiftUI

// MARK: - Chart Chat Manager
@MainActor
class ChartChatManager: ObservableObject {
    @Published var activeChartChat: ChartChatDTO? = nil
    @Published var isLoadingChat: Bool = false
    @Published var messages: [ChartChatMessageDTO] = []
    
    private var chatCache: [String: ChartChatDTO] = [:]
    private weak var appState: AppState?
    
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    /// Open or create a chart chat for a specific symbol and guild
    func openChartChat(symbol: TradingSymbol, guildId: UUID, api: MockAPIService) async {
        let cacheKey = "\(symbol.id)-\(guildId)"
        
        // Check cache first
        if let cachedChat = chatCache[cacheKey] {
            activeChartChat = cachedChat
            await loadMessages(chatId: cachedChat.id, api: api)
            return
        }
        
        isLoadingChat = true
        
        do {
            // Fetch or create chart chat from API
            let chartChat = try await api.fetchOrCreateChartChat(
                symbolId: symbol.id,
                guildId: guildId
            )
            
            chatCache[cacheKey] = chartChat
            activeChartChat = chartChat
            
            // Load messages for this chat
            await loadMessages(chatId: chartChat.id, api: api)
            
        } catch {
            print("⚠️ Failed to open chart chat: \(error)")
        }
        
        isLoadingChat = false
    }
    
    /// Load messages for the active chart chat
    func loadMessages(chatId: UUID, api: MockAPIService) async {
        do {
            let loadedMessages = try await api.fetchChartChatMessages(chatId: chatId)
            messages = loadedMessages
        } catch {
            print("⚠️ Failed to load chart chat messages: \(error)")
            messages = []
        }
    }
    
    /// Send a new message to the active chart chat
    func sendMessage(content: String, api: MockAPIService) async throws {
        guard let chat = activeChartChat else { return }
        guard let appState = appState else { return }
        guard let currentUser = appState.currentUser else { return }
        
        // Call API to send message
        let newMessage = try await api.sendChartChatMessage(
            chatId: chat.id,
            content: content,
            authorId: currentUser.id
        )
        
        // Add to local messages
        messages.append(newMessage)
    }
    
    /// Edit an existing message
    func editMessage(messageId: UUID, newContent: String, api: MockAPIService) async throws {
        guard let chat = activeChartChat else { return }
        
        try await api.editChartChatMessage(
            messageId: messageId,
            newContent: newContent,
            chatId: chat.id
        )
        
        // Update local message
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            messages[index] = ChartChatMessageDTO(
                id: updatedMessage.id,
                chartChatId: updatedMessage.chartChatId,
                author: updatedMessage.author,
                content: newContent,
                timestamp: updatedMessage.timestamp,
                timestampFormatted: updatedMessage.timestampFormatted,
                isEdited: true,
                isCurrentUserMessage: updatedMessage.isCurrentUserMessage,
                canEdit: updatedMessage.canEdit,
                canDelete: updatedMessage.canDelete
            )
        }
    }
    
    /// Delete a message
    func deleteMessage(messageId: UUID, api: MockAPIService) async throws {
        guard let chat = activeChartChat else { return }
        
        try await api.deleteChartChatMessage(
            messageId: messageId,
            chatId: chat.id
        )
        
        // Remove from local messages
        messages.removeAll { $0.id == messageId }
    }
    
    /// Close the active chart chat
    func closeChat() {
        activeChartChat = nil
        messages = []
    }
    
    /// Clear all cached chats (e.g., on logout)
    func clearCache() {
        chatCache.removeAll()
        messages = []
        activeChartChat = nil
    }
    
    /// Update chat when symbol or guild changes
    func updateForSymbol(_ symbol: TradingSymbol?, guildId: UUID?, api: MockAPIService) async {
        guard let symbol = symbol, let guildId = guildId else {
            closeChat()
            return
        }
        
        await openChartChat(symbol: symbol, guildId: guildId, api: api)
    }
}
