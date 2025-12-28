//
//  chartSheetChatView.swift
//  traders_guild
//
//  REFACTORED: Now uses unified ChatComponents for consistent styling
//  - ChatMessageBubble replaces ChartMessageRow body
//  - ChatEmptyStateView and ChatLoadingView replace custom implementations
//  - UnifiedEditMessageSheet replaces EditChartMessageSheet
//  - ChatBackground for consistent styling
//
//  Parent (MainView ChartBottomSheet) still handles input footer

import SwiftUI
import Combine

struct ImprovedChartSheetChatView: View {
    @ObservedObject var chartViewModel: ChartViewModel
    @ObservedObject var chartChatManager: ChartChatManager
    @EnvironmentObject var appState: AppState
    @Binding var selectedDetent: PresentationDetent
    
    // Message input state - shared with parent footer
    @Binding var messageText: String
    
    @State private var showEditSheet = false
    @State private var messageToEdit: ChartChatMessageDTO? = nil
    
    var body: some View {
        ZStack {
            if chartChatManager.isLoadingChat {
                ChatLoadingView(message: "Loading chat...")
            } else if let chat = chartChatManager.activeChartChat {
                chatContentView(for: chat)
            } else {
                noSymbolSelectedView
            }
        }
    }
    
    // MARK: - No Symbol Selected View
    private var noSymbolSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Symbol Selected")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Select a symbol to start chatting with your guild")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Chat Content View
    private func chatContentView(for chat: ChartChatDTO) -> some View {
        VStack(spacing: 0) {
            // Header - compact and clean
            chartChatHeader(for: chat)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Messages area
            if chartChatManager.messages.isEmpty {
                emptyMessagesView
            } else {
                messagesScrollView
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let message = messageToEdit {
                UnifiedEditMessageSheet(originalContent: message.content) { newContent in
                    await editMessage(message, newContent: newContent)
                }
            }
        }
    }
    
    // MARK: - Chat Header
    private func chartChatHeader(for chat: ChartChatDTO) -> some View {
        HStack(spacing: 12) {
            // Symbol avatar with chart icon
            Circle()
                .fill(AppColors.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accentColor)
                )
            
            // Symbol info
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.symbolTicker)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(chat.guildName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Active users pill - using unified component
            ActiveUsersPill(count: chat.activeUserCount)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 20)
    }
    
    // MARK: - Empty Messages View (Using Unified ChatEmptyStateView)
    private var emptyMessagesView: some View {
        ChatEmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "Start the conversation",
            subtitle: "Be the first to share your analysis on \(chartChatManager.activeChartChat?.symbolTicker ?? "this symbol")"
        )
        .background(ChatBackground())
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(chartChatManager.messages) { message in
                        ChartMessageRow(
                            message: message,
                            chartChatManager: chartChatManager,
                            onDelete: {
                                Task { await deleteMessage(message) }
                            },
                            onEdit: {
                                messageToEdit = message
                                showEditSheet = true
                            },
                            onReport: {
                                Task { await reportMessage(message) }
                            }
                        )
                        .environmentObject(appState)
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chartChatManager.messages.count) { _ in
                if let lastMessage = chartChatManager.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = chartChatManager.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .background(ChatBackground())
        }
    }
    
    // MARK: - Message Actions
    
    private func deleteMessage(_ message: ChartChatMessageDTO) async {
        do {
            try await chartChatManager.deleteMessage(messageId: message.id, api: MockAPIService())
            HapticFeedback.medium.trigger()
            appState.showSuccess("Message deleted")
        } catch {
            appState.showError(error, title: "Failed to Delete", style: .toast)
        }
    }
    
    private func editMessage(_ message: ChartChatMessageDTO, newContent: String) async {
        do {
            try await chartChatManager.editMessage(
                messageId: message.id,
                newContent: newContent,
                api: MockAPIService()
            )
            HapticFeedback.light.trigger()
            appState.showSuccess("Message updated")
        } catch {
            appState.showError(error, title: "Failed to Edit", style: .toast)
        }
    }
    
    private func reportMessage(_ message: ChartChatMessageDTO) async {
        HapticFeedback.medium.trigger()
        appState.showInfo("Message reported for review")
    }
}

// MARK: - Chart Message Row (Using Unified ChatMessageBubble)

struct ChartMessageRow: View {
    let message: ChartChatMessageDTO
    @ObservedObject var chartChatManager: ChartChatManager
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onReport: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    private var canDeleteMessage: Bool {
        guard let currentUserRole = appState.currentGuild?.roleInGuild else {
            return false
        }
        return currentUserRole.canDelete(
            messageFrom: message.author.roleInGuild,
            isOwnMessage: message.isCurrentUserMessage
        )
    }
    
    private var canEditMessage: Bool {
        return message.isCurrentUserMessage
    }
    
    var body: some View {
        ChatMessageBubble(
            message: message,
            context: .chartChat,
            onAvatarTap: {
                // Could navigate to user profile if needed
            },
            onEdit: canEditMessage ? onEdit : nil,
            onDelete: canDeleteMessage ? onDelete : nil,
            onReport: !message.isCurrentUserMessage ? onReport : nil,
            onCopy: { appState.showSuccess("Copied to clipboard") }
        )
    }
}








