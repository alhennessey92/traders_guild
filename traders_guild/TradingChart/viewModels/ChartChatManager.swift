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
import Combine

// MARK: - Chart Chat Manager
@MainActor
class ChartChatManager: ObservableObject {
    @Published var activeChartChat: RLChartChatDTO? = nil
    @Published var isLoadingChat: Bool = false
    @Published var messages: [RLChartChatMessageDTO] = []

    private var chatCache: [String: RLChartChatDTO] = [:]
    private weak var appState: RLAppState?
    private let api: RealAPIService
    private var currentChatChannel: String?
    private var cancellables = Set<AnyCancellable>()

    init(appState: RLAppState? = nil, api: RealAPIService) {
        self.appState = appState
        self.api = api
        setupRealTimeSubscriptions()
    }

    func configure(with appState: RLAppState) {
        self.appState = appState
    }

    // MARK: - Real-time WebSocket

    private func setupRealTimeSubscriptions() {
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleRealTimeMessage(message)
            }
            .store(in: &cancellables)
    }

    private func handleRealTimeMessage(_ message: WSIncomingMessage) {
        guard let channel = message.channel,
              channel == currentChatChannel else { return }

        switch message.type {
        case "new_message":
            if let newMessage = message.payload(as: RLChartChatMessageDTO.self) {
                if !messages.contains(where: { $0.id == newMessage.id }) {
                    messages.append(newMessage)
                }
            }
        case "message_edited":
            if let edited = message.payload(as: RLChartChatMessageDTO.self),
               let index = messages.firstIndex(where: { $0.id == edited.id }) {
                messages[index] = edited
            }
        case "message_deleted":
            if let payload = message.payload as? [String: Any],
               let messageIdStr = (payload as? [String: Any])?["message_id"] as? String,
               let messageId = UUID(uuidString: messageIdStr) {
                messages.removeAll { $0.id == messageId }
            }
        default:
            break
        }
    }

    private func subscribeToChat(_ chatId: UUID) {
        unsubscribeFromChat()
        let channel = "chart_chat:\(chatId.uuidString.lowercased())"
        currentChatChannel = channel
        RealTimeService.shared.subscribe(to: [channel], owner: "chart_chat")
    }

    private func unsubscribeFromChat() {
        if let channel = currentChatChannel {
            RealTimeService.shared.unsubscribe(from: [channel], owner: "chart_chat")
            currentChatChannel = nil
        }
    }
    
    /// Open or create a chart chat for a specific symbol and guild
    func openChartChat(symbol: RLTradingSymbolDTO, guildId: UUID) async {
        let cacheKey = "\(symbol.id)-\(guildId)"
        
        // Check cache first
        if let cachedChat = chatCache[cacheKey] {
            activeChartChat = cachedChat
            subscribeToChat(cachedChat.id)
            await loadMessages(chatId: cachedChat.id)
            return
        }
        
        isLoadingChat = true
        
        do {
            // Fetch or create chart chat from RealAPIService
            let chartChat = try await api.getOrCreateChartChat(
                guildId: guildId,
                symbolId: symbol.id
            )
            
            chatCache[cacheKey] = chartChat
            activeChartChat = chartChat

            // Subscribe to real-time updates for this chat
            subscribeToChat(chartChat.id)

            // Load messages for this chat
            await loadMessages(chatId: chartChat.id)
            
        } catch {
            print("⚠️ Failed to open chart chat: \(error)")
            appState?.showError(error, title: "Failed to Open Chat", style: .toast)
        }
        
        isLoadingChat = false
    }
    
    /// Load messages for the active chart chat
    func loadMessages(chatId: UUID, cursor: String? = nil) async {
        do {
            let messagesListDTO = try await api.getChartChatMessages(
                chatId: chatId,
                limit: 50,
                cursor: cursor
            )
            messages = messagesListDTO.messages
        } catch {
            print("⚠️ Failed to load chart chat messages: \(error)")
            appState?.showError(error, title: "Failed to Load Messages", style: .toast)
            messages = []
        }
    }
    
    /// Send a new message to the active chart chat
    func sendMessage(content: String) async throws {
        guard let chat = activeChartChat else { return }
        
        // Call RealAPIService to send message
        let newMessage = try await api.sendChartChatMessage(
            chatId: chat.id,
            content: content
        )
        
        // Add to local messages
        messages.append(newMessage)
    }
    
    /// Edit an existing message
    func editMessage(messageId: UUID, newContent: String) async throws {
        guard let chat = activeChartChat else { return }
        
        let updatedMessage = try await api.editChartChatMessage(
            chatId: chat.id,
            messageId: messageId,
            content: newContent
        )
        
        // Update local message
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index] = updatedMessage
        }
    }
    
    /// Delete a message
    func deleteMessage(messageId: UUID) async throws {
        guard let chat = activeChartChat else { return }
        
        try await api.deleteChartChatMessage(
            chatId: chat.id,
            messageId: messageId
        )
        
        // Remove from local messages
        messages.removeAll { $0.id == messageId }
    }
    
    /// Close the active chart chat
    func closeChat() {
        unsubscribeFromChat()
        activeChartChat = nil
        messages = []
    }

    /// Clear all cached chats (e.g., on logout)
    func clearCache() {
        unsubscribeFromChat()
        chatCache.removeAll()
        messages = []
        activeChartChat = nil
    }
    
    /// Update chat when symbol or guild changes
    func updateForSymbol(_ symbol: RLTradingSymbolDTO?, guildId: UUID?) async {
        guard let symbol = symbol, let guildId = guildId else {
            closeChat()
            return
        }
        
        await openChartChat(symbol: symbol, guildId: guildId)
    }
}
