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
    @EnvironmentObject var rlAppState: RLAppState
    @Binding var selectedDetent: PresentationDetent
    
    // Message input state - shared with parent footer
    @Binding var messageText: String
    
    @State private var showEditSheet = false
    @State private var messageToEdit: RLChartChatMessageDTO? = nil
    @State private var showReportReasonSheet = false
    @State private var messageToReport: RLChartChatMessageDTO? = nil
    @State private var selectedAuthor: RLGuildMemberDTO? = nil
    
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
    private func chatContentView(for chat: RLChartChatDTO) -> some View {
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
        .sheet(isPresented: $showReportReasonSheet) {
            if let message = messageToReport {
                ReportReasonSheet(
                    title: "Why are you reporting this message?",
                    includeScam: false,
                    onReasonSelected: { reason in
                        Task {
                            await reportMessage(message, reason: reason)
                            await MainActor.run {
                                showReportReasonSheet = false
                                messageToReport = nil
                            }
                        }
                    },
                    onCancel: {
                        showReportReasonSheet = false
                        messageToReport = nil
                    }
                )
            }
        }
        .sheet(item: $selectedAuthor) { member in
            GuildUserDetailViewRL(member: member)
                .environmentObject(rlAppState)
        }
    }
    
    // MARK: - Chat Header
    private func chartChatHeader(for chat: RLChartChatDTO) -> some View {
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
                            onAuthorTap: { member in
                                selectedAuthor = member
                            },
                            onDelete: {
                                Task { await deleteMessage(message) }
                            },
                            onEdit: {
                                messageToEdit = message
                                showEditSheet = true
                            },
                            onReport: {
                                messageToReport = message
                                showReportReasonSheet = true
                            }
                        )
                        .environmentObject(rlAppState)
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
    
    private func deleteMessage(_ message: RLChartChatMessageDTO) async {
        do {
            try await chartChatManager.deleteMessage(messageId: message.id)
            HapticFeedback.medium.trigger()
            rlAppState.showSuccess("Message deleted")
        } catch {
            rlAppState.showError(error, title: "Failed to Delete", style: .toast)
        }
    }
    
    private func editMessage(_ message: RLChartChatMessageDTO, newContent: String) async {
        do {
            try await chartChatManager.editMessage(
                messageId: message.id,
                newContent: newContent
            )
            HapticFeedback.light.trigger()
            rlAppState.showSuccess("Message updated")
        } catch {
            rlAppState.showError(error, title: "Failed to Edit", style: .toast)
        }
    }
    
    private func reportMessage(_ message: RLChartChatMessageDTO, reason: String) async {
        guard let guildId = rlAppState.currentGuild?.id else { return }
        HapticFeedback.medium.trigger()
        do {
            _ = try await rlAppState.realApi.reportChartChatMessage(
                guildId: guildId,
                messageId: message.id,
                reason: reason
            )
            rlAppState.showSuccess("Report submitted")
        } catch {
            rlAppState.showError(error, title: "Failed to Report", style: .toast)
        }
    }
}

// MARK: - Chart Message Row (Using Unified ChatMessageBubble)

struct ChartMessageRow: View {
    let message: RLChartChatMessageDTO
    @ObservedObject var chartChatManager: ChartChatManager
    let onAuthorTap: (RLGuildMemberDTO) -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onReport: () -> Void
    
    @EnvironmentObject var rlAppState: RLAppState
    
    private var canDeleteMessage: Bool {
        // Check if current user can delete this message
        // For now, allow deletion if it's the current user's message or if user is admin
        guard let currentMembership = rlAppState.currentMembership else {
            return false
        }
        return message.isCurrentUserMessage || currentMembership.canModerate
    }
    
    private var canEditMessage: Bool {
        return message.isCurrentUserMessage
    }
    
    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .chartChat,
            onAvatarTap: { onAuthorTap(message.author) },
            onAuthorTap: { onAuthorTap(message.author) },
            onEdit: canEditMessage ? onEdit : nil,
            onDelete: canDeleteMessage ? onDelete : nil,
            onReport: !message.isCurrentUserMessage ? onReport : nil,
            onCopy: { rlAppState.showSuccess("Copied to clipboard") },
            onMarkerShareTap: { payload in
                NotificationCenter.default.post(
                    name: .openSharedMarker,
                    object: nil,
                    userInfo: payload.notificationUserInfo
                )
            }
        )
    }
}






