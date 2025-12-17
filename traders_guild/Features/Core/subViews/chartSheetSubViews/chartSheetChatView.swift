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










////
////  ImprovedChartSheetChatView.swift
////  traders_guild
////
////  IMPROVED: Chat input is managed by parent (MainView ChartBottomSheet)
////  - Parent replaces tab bar with chat input + back button
////  - No double-footer situation
////  - More vertical space for messages
////  - Clean keyboard handling with safeAreaInset
//
//import SwiftUI
//import Combine
//
//struct ImprovedChartSheetChatView: View {
//    @ObservedObject var chartViewModel: ChartViewModel
//    @ObservedObject var chartChatManager: ChartChatManager
//    @EnvironmentObject var appState: AppState
//    @Binding var selectedDetent: PresentationDetent
//    
//    // Message input state - shared with parent footer (for display purposes)
//    @Binding var messageText: String
//    
//    @State private var showEditSheet = false
//    @State private var messageToEdit: ChartChatMessageDTO? = nil
//    
//    var body: some View {
//        ZStack {
//            if chartChatManager.isLoadingChat {
//                loadingView
//            } else if let chat = chartChatManager.activeChartChat {
//                chatContentView(for: chat)
//            } else {
//                emptyStateView
//            }
//        }
//        // Parent (ChartBottomSheet) handles chat loading with onAppear/onChange
//    }
//    
//    // MARK: - Loading View
//    private var loadingView: some View {
//        VStack(spacing: 16) {
//            ProgressView()
//                .scaleEffect(1.2)
//                .tint(AppColors.accentColor)
//            
//            Text("Loading chat...")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    // MARK: - Empty State View
//    private var emptyStateView: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "chart.line.uptrend.xyaxis")
//                .font(.system(size: 48))
//                .foregroundColor(.gray.opacity(0.5))
//            
//            Text("No Symbol Selected")
//                .font(.headline)
//                .foregroundColor(.white)
//            
//            Text("Select a symbol to start chatting with your guild")
//                .font(.caption)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//    
//    // MARK: - Main Chat Content View
//    private func chatContentView(for chat: ChartChatDTO) -> some View {
//        VStack(spacing: 0) {
//            // Header - compact and clean
//            chartChatHeader(for: chat)
//            
//            Divider()
//                .background(Color.gray.opacity(0.3))
//            
//            // Messages area - takes all remaining space
//            if chartChatManager.messages.isEmpty {
//                emptyMessagesView
//            } else {
//                messagesScrollView
//            }
//        }
//        // Input is handled by parent's footer replacement
//        .sheet(isPresented: $showEditSheet) {
//            if let message = messageToEdit {
//                EditChartMessageSheet(
//                    message: message,
//                    onSave: { newContent in
//                        Task {
//                            await editMessage(message, newContent: newContent)
//                        }
//                    }
//                )
//                .environmentObject(appState)
//            }
//        }
//    }
//    
//    // MARK: - Chat Header
//    private func chartChatHeader(for chat: ChartChatDTO) -> some View {
//        HStack(spacing: 12) {
//            // Symbol avatar with chart icon
//            Circle()
//                .fill(AppColors.accentColor.opacity(0.2))
//                .frame(width: 40, height: 40)
//                .overlay(
//                    Image(systemName: "chart.line.uptrend.xyaxis")
//                        .font(.system(size: 16, weight: .semibold))
//                        .foregroundColor(AppColors.accentColor)
//                )
//            
//            // Symbol info
//            VStack(alignment: .leading, spacing: 2) {
//                Text(chat.symbolTicker)
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(.white)
//                
//                Text(chat.guildName)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//            Spacer()
//            
//            // Active users pill
//            if chat.activeUserCount > 0 {
//                HStack(spacing: 6) {
//                    Circle()
//                        .fill(Color.green)
//                        .frame(width: 6, height: 6)
//                    
//                    Text("\(chat.activeUserCount) active")
//                        .font(.caption2)
//                        .fontWeight(.medium)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.horizontal, 10)
//                .padding(.vertical, 6)
//                .background(Color.white.opacity(0.06))
//                .clipShape(Capsule())
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.bottom, 12)
//        .padding(.top, 20)
//    }
//    
//    // MARK: - Empty Messages View
//    private var emptyMessagesView: some View {
//        VStack(spacing: 12) {
//            Spacer()
//            
//            Image(systemName: "bubble.left.and.bubble.right")
//                .font(.system(size: 36))
//                .foregroundColor(.gray.opacity(0.4))
//            
//            Text("Start the conversation")
//                .font(.subheadline)
//                .fontWeight(.medium)
//                .foregroundColor(.secondary)
//            
//            Text("Be the first to share your analysis on \(chartChatManager.activeChartChat?.symbolTicker ?? "this symbol")")
//                .font(.caption)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal, 32)
//            
//            Spacer()
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(
//            ZStack {
//                Color.clear
//                    .background(.ultraThinMaterial)
//                AppColors.sheetBackground
//                StaticPatternView()
//            }
//        )
//    }
//    
//    // MARK: - Messages Scroll View
//    private var messagesScrollView: some View {
//        ScrollViewReader { proxy in
//            ScrollView(.vertical, showsIndicators: false) {
//                LazyVStack(spacing: 12) {
//                    ForEach(chartChatManager.messages) { message in
//                        ChartMessageRow(
//                            message: message,
//                            chartChatManager: chartChatManager,
//                            onDelete: {
//                                Task { await deleteMessage(message) }
//                            },
//                            onEdit: {
//                                messageToEdit = message
//                                showEditSheet = true
//                            },
//                            onReport: {
//                                Task { await reportMessage(message) }
//                            }
//                        )
//                        .environmentObject(appState)
//                        .id(message.id)
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.top, 16)
//                .padding(.bottom, 20)
//            }
//            .scrollDismissesKeyboard(.interactively)
//            .onChange(of: chartChatManager.messages.count) { _ in
//                if let lastMessage = chartChatManager.messages.last {
//                    withAnimation(.easeOut(duration: 0.2)) {
//                        proxy.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
//                    }
//                }
//            }
//            .onAppear {
//                if let lastMessage = chartChatManager.messages.last {
//                    proxy.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
//                }
//            }
//            .background(
//                ZStack {
//                    Color.clear
//                        .background(.ultraThinMaterial)
//                    AppColors.sheetBackground
//                    StaticPatternView()
//                }
//            )
//        }
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func deleteMessage(_ message: ChartChatMessageDTO) async {
//        do {
//            try await chartChatManager.deleteMessage(
//                messageId: message.id,
//                api: MockAPIService()
//            )
//            HapticFeedback.medium.trigger()
//            appState.showSuccess("Message deleted")
//        } catch {
//            appState.showError(error, title: "Failed to Delete")
//        }
//    }
//    
//    private func editMessage(_ message: ChartChatMessageDTO, newContent: String) async {
//        do {
//            try await chartChatManager.editMessage(
//                messageId: message.id,
//                newContent: newContent,
//                api: MockAPIService()
//            )
//            HapticFeedback.light.trigger()
//            appState.showSuccess("Message updated")
//        } catch {
//            appState.showError(error, title: "Failed to Edit")
//        }
//    }
//    
//    private func reportMessage(_ message: ChartChatMessageDTO) async {
//        HapticFeedback.medium.trigger()
//        appState.showInfo("Message reported for review")
//    }
//}
//
//// MARK: - Supporting Views (ChartMessageRow, EditChartMessageSheet remain the same as before)
//
//struct ChartMessageRow: View {
//    let message: ChartChatMessageDTO
//    @ObservedObject var chartChatManager: ChartChatManager
//    let onDelete: () -> Void
//    let onEdit: () -> Void
//    let onReport: () -> Void
//    
//    @EnvironmentObject var appState: AppState
//    @State private var showDeleteConfirmation = false
//    
//    private var canEditMessage: Bool {
//        message.isCurrentUserMessage && !message.author.isBlocked
//    }
//    
//    private var canDeleteMessage: Bool {
//        guard let currentUserRole = appState.currentGuild?.roleInGuild else {
//            return false
//        }
//        
//        return currentUserRole.canDelete(
//            messageFrom: message.author.roleInGuild,
//            isOwnMessage: message.isCurrentUserMessage
//        )
//    }
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 8) {
//            if message.isCurrentUserMessage {
//                Spacer()
//            } else {
//                // Avatar with online indicator
//                Button(action: {
//                    // Navigate to user profile
//                }) {
//                    Circle()
//                        .fill(AppColors.accentColor.opacity(0.3))
//                        .frame(width: 32, height: 32)
//                        .overlay(
//                            Text(String(message.author.globalMember.username.prefix(2)))
//                                .font(.caption)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.accentColor)
//                        )
//                        .overlay(alignment: .bottomTrailing) {
//                            Circle()
//                                .fill(message.author.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
//                                .frame(width: 10, height: 10)
//                                .overlay(
//                                    Circle()
//                                        .stroke(AppColors.drawerBackground, lineWidth: 1)
//                                )
//                        }
//                }
//                .buttonStyle(PlainButtonStyle())
//            }
//            
//            VStack(alignment: message.alignment, spacing: 4) {
//                // User info row (only for other users)
//                if !message.isCurrentUserMessage {
//                    HStack(spacing: 2) {
//                        if message.author.isBlocked {
//                            Image(systemName: "nosign")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.bearCandleRed)
//                        }
//                        
//                        Text(message.author.globalMember.username)
//                            .font(.caption)
//                            .fontWeight(.semibold)
//                            .foregroundColor(message.author.isBlocked ? AppColors.greyText : AppColors.whiteText.opacity(0.9))
//                        
//                        if message.author.isFriend {
//                            Image(systemName: "person.crop.circle")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(message.author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
//                                .padding(.leading, 3)
//                        }
//                        
//                        let role = message.author.roleInGuild
//                        Circle()
//                            .fill(AppColors.whiteText.opacity(0.7))
//                            .frame(width: 3, height: 3)
//                            .padding(.horizontal, 3)
//                        
//                        Text(role.rawValue)
//                            .font(.caption)
//                            .foregroundColor(role.roleForegroundColor)
//                            .fontWeight(role.roleFontWeight)
//                        
//                        Circle()
//                            .fill(AppColors.whiteText.opacity(0.7))
//                            .frame(width: 3, height: 3)
//                            .padding(.horizontal, 3)
//                        
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        
//                        Text("\(message.author.reputation)")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                    }
//                }
//                
//                // Message bubble
//                Text(message.content)
//                    .font(.subheadline)
//                    .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(
//                        message.isCurrentUserMessage ?
//                        AppColors.accentDarkColor :
//                        Color.gray.opacity(0.2)
//                    )
//                    .clipShape(chatRoomMessageBubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
//                    .contextMenu {
//                        if canEditMessage {
//                            Button {
//                                onEdit()
//                            } label: {
//                                Label("Edit", systemImage: "pencil")
//                            }
//                        }
//                        
//                        if canDeleteMessage {
//                            Button(role: .destructive) {
//                                showDeleteConfirmation = true
//                            } label: {
//                                Label("Delete", systemImage: "trash")
//                            }
//                        }
//                        
//                        Button {
//                            UIPasteboard.general.string = message.content
//                            appState.showSuccess("Copied to clipboard")
//                        } label: {
//                            Label("Copy", systemImage: "doc.on.doc")
//                        }
//                        
//                        if !message.isCurrentUserMessage {
//                            Divider()
//                            Button(role: .destructive) {
//                                onReport()
//                            } label: {
//                                Label("Report", systemImage: "exclamationmark.triangle")
//                            }
//                        }
//                    }
//                
//                // Timestamp row
//                HStack(spacing: 4) {
//                    Text(message.timestampFormatted)
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                    
//                    if message.isEdited {
//                        Text("(edited)")
//                            .font(.caption2)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//            
//            if !message.isCurrentUserMessage {
//                Spacer()
//            }
//        }
//        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Delete", role: .destructive) {
//                onDelete()
//            }
//        } message: {
//            Text("Are you sure you want to delete this message? This cannot be undone.")
//        }
//    }
//    
//    private func chatRoomMessageBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
//        if isFromCurrentUser {
//            return UnevenRoundedRectangle(
//                topLeadingRadius: 16,
//                bottomLeadingRadius: 16,
//                bottomTrailingRadius: 4,
//                topTrailingRadius: 16
//            )
//        } else {
//            return UnevenRoundedRectangle(
//                topLeadingRadius: 4,
//                bottomLeadingRadius: 16,
//                bottomTrailingRadius: 16,
//                topTrailingRadius: 16
//            )
//        }
//    }
//}
//
//// MARK: - Edit Chart Message Sheet
//
//struct EditChartMessageSheet: View {
//    let message: ChartChatMessageDTO
//    let onSave: (String) -> Void
//    
//    @Environment(\.dismiss) private var dismiss
//    @State private var editedText: String
//    
//    init(message: ChartChatMessageDTO, onSave: @escaping (String) -> Void) {
//        self.message = message
//        self.onSave = onSave
//        _editedText = State(initialValue: message.content)
//    }
//    
//    var body: some View {
//        NavigationStack {
//            VStack {
//                TextField("Message", text: $editedText, axis: .vertical)
//                    .lineLimit(5...10)
//                    .padding()
//                    .background(Color.gray.opacity(0.1))
//                    .cornerRadius(10)
//                    .padding()
//                
//                Spacer()
//            }
//            .navigationTitle("Edit Message")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        onSave(editedText)
//                        dismiss()
//                    }
//                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                }
//            }
//        }
//    }
//}
