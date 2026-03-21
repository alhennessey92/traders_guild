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
    private var api: RealAPIService
    private var currentChatChannel: String?
    private var cancellables = Set<AnyCancellable>()

    init(appState: RLAppState? = nil, api: RealAPIService) {
        self.appState = appState
        self.api = api
        setupRealTimeSubscriptions()
    }

    func configure(with appState: RLAppState) {
        self.appState = appState
        self.api = appState.realApi
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
            if var newMessage = message.payload(as: RLChartChatMessageDTO.self) {
                if !messages.contains(where: { $0.id == newMessage.id }) {
                    // Recompute isCurrentUserMessage for the receiving user
                    if let currentUserId = appState?.currentUser?.id {
                        let isMine = newMessage.author.userId == currentUserId
                        newMessage = newMessage.withCurrentUser(isMine)
                    }
                    messages.append(newMessage)
                }
            }
        case "message_edited":
            if var edited = message.payload(as: RLChartChatMessageDTO.self),
               let index = messages.firstIndex(where: { $0.id == edited.id }) {
                // Recompute isCurrentUserMessage for the receiving user
                if let currentUserId = appState?.currentUser?.id {
                    let isMine = edited.author.userId == currentUserId
                    edited = edited.withCurrentUser(isMine)
                }
                messages[index] = edited
            }
        case "message_deleted":
            if let payload = message.payload(as: WSMessageDeletedPayload.self),
               let messageId = UUID(uuidString: payload.messageId) {
                messages.removeAll { $0.id == messageId }
            }
        case "message_reaction_updated":
            handleReactionUpdated(message)
        default:
            break
        }
    }

    private func handleReactionUpdated(_ message: WSIncomingMessage) {
        guard let payload = message.payload(as: WSMessageReactionUpdatedPayload.self),
              let messageId = UUID(uuidString: payload.messageId),
              let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        let existingByEmoji = Dictionary(uniqueKeysWithValues: messages[index].reactions.map { ($0.emoji, $0) })
        let currentUserId = appState?.currentUser?.id.uuidString.lowercased()
        let actorUserId = payload.actorUserId.lowercased()
        let didCurrentUserAct = currentUserId == actorUserId
        let toggledEmoji = existingByEmoji.keys.first { emoji in
            let previousCount = existingByEmoji[emoji]?.count ?? 0
            let updatedCount = payload.reactions.first(where: { $0.emoji == emoji })?.count ?? 0
            return previousCount != updatedCount
        } ?? payload.reactions.first(where: { existingByEmoji[$0.emoji] == nil })?.emoji

        messages[index].reactions = payload.reactions.map { reaction in
            let wasReacted = existingByEmoji[reaction.emoji]?.reactedByCurrentUser ?? false
            let reactedByCurrentUser: Bool
            if didCurrentUserAct, toggledEmoji == reaction.emoji {
                reactedByCurrentUser = payload.action == "added"
            } else {
                reactedByCurrentUser = wasReacted
            }

            return RLMessageReactionDTO(
                emoji: reaction.emoji,
                count: reaction.count,
                reactedByCurrentUser: reactedByCurrentUser
            )
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
    func sendMessage(
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        replyToMessageId: UUID? = nil
    ) async throws {
        guard let chat = activeChartChat else { return }
        
        // Call RealAPIService to send message
        let newMessage = try await api.sendChartChatMessage(
            chatId: chat.id,
            content: content,
            attachmentUrl: attachmentUrl,
            attachmentType: attachmentType,
            attachmentName: attachmentName,
            replyToMessageId: replyToMessageId
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
        
        _ = try await api.deleteChartChatMessage(
            chatId: chat.id,
            messageId: messageId
        )
        
        // Remove from local messages
        messages.removeAll { $0.id == messageId }
    }

    func toggleReaction(messageId: UUID, emoji: String) async throws {
        guard let chat = activeChartChat else { return }
        let updatedMessage = try await api.toggleChartChatMessageReaction(
            chatId: chat.id,
            messageId: messageId,
            emoji: emoji
        )
        if let index = messages.firstIndex(where: { $0.id == updatedMessage.id }) {
            messages[index] = updatedMessage
        }
    }

    func fetchReactionReactors(messageId: UUID, emoji: String) async throws -> RLMessageReactionReactorsDTO {
        guard let chat = activeChartChat else {
            throw APIError.badRequest("Chart chat is not available")
        }
        return try await api.getChartChatMessageReactionReactors(
            chatId: chat.id,
            messageId: messageId,
            emoji: emoji
        )
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
