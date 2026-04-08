//
//  RLMessagingState.swift
//  traders_guild
//
//  UPDATED: Uses RLAppState and new RL messaging DTOs.
//  Replaces old MessagingState that used AppState.
//

import SwiftUI
import Combine

// MARK: - Message Content Types
enum RLMessageContentType: Equatable {
    case dmThread(RLDMThreadDTO)
    case chatroom(RLGuildChatroomDTO)
    
    var id: UUID {
        switch self {
        case .dmThread(let thread): return thread.id
        case .chatroom(let chatroom): return chatroom.id
        }
    }
}

// MARK: - Global Messaging Manager
@MainActor
class RLMessagingManager: ObservableObject {
    @Published var activeMessage: RLMessageContentType? = nil
    @Published var isLoadingChat: Bool = false
    @Published var activeTypingUsers = Set<String>()
    
    private var dmCache: [UUID: RLDMThreadDTO] = [:]
    private var chatroomCache: [UUID: RLGuildChatroomDTO] = [:]
    
    private weak var appState: RLAppState?
    private var cancellables = Set<AnyCancellable>()
    private var currentSubscribedChannel: String?
    
    // Publishers for the UI to react to
    enum IncomingMessageType {
        case chatroom(RLChatroomMessageDTO)
        case dm(RLDMMessageDTO)
    }
    
    let incomingMessageSubject = PassthroughSubject<IncomingMessageType, Never>()
    let editedMessageSubject = PassthroughSubject<IncomingMessageType, Never>()
    let deletedMessageSubject = PassthroughSubject<UUID, Never>()
    let reactionUpdatedSubject = PassthroughSubject<WSMessageReactionUpdatedPayload, Never>()
    
    init(appState: RLAppState? = nil) {
        self.appState = appState
        setupRealTimeListeners()
    }
    
    func configure(with appState: RLAppState) {
        self.appState = appState
    }
    
    // MARK: - Open DM Thread
    
    func openDMThread(_ thread: RLDMThreadDTO) {
        dmCache[thread.id] = thread
        activeMessage = .dmThread(thread)
        subscribeToActiveChat()
    }
    
    /// Open a DM chat with a guild member (creates thread if needed)
    func openDMChat(with member: RLGuildMemberDTO) async {
        guard let appState = appState else {
            print("⚠️ AppState not configured")
            return
        }
        
        // Check cache first
        if let cachedThread = dmCache.values.first(where: { $0.participant.membershipId == member.membershipId }) {
            openDMThread(cachedThread)
            return
        }
        
        isLoadingChat = true
        defer { isLoadingChat = false }
        
        do {
            let thread = try await appState.fetchOrCreateDMThread(participantUserId: member.userId)
            dmCache[thread.id] = thread
            openDMThread(thread)
        } catch is CancellationError {
            return
        } catch {
            // Error already shown by appState
        }
    }
    
    // MARK: - Open Chatroom
    
    func openChatroom(_ chatroom: RLGuildChatroomDTO) {
        chatroomCache[chatroom.id] = chatroom
        activeMessage = .chatroom(chatroom)
        subscribeToActiveChat()
    }
    
    /// Open a chatroom by ID (fetches if not cached)
    func openChatroom(id: UUID) async {
        guard let appState = appState else {
            print("⚠️ AppState not configured")
            return
        }
        
        // Check cache first
        if let cached = chatroomCache[id] {
            openChatroom(cached)
            return
        }
        
        isLoadingChat = true
        defer { isLoadingChat = false }
        
        do {
            let chatroom = try await appState.fetchChatroom(chatroomId: id)
            chatroomCache[chatroom.id] = chatroom
            openChatroom(chatroom)
        } catch is CancellationError {
            return
        } catch {
            // Error already shown by appState
        }
    }
    
    // MARK: - Close & Clear
    
    func closeMessage() {
        unsubscribeFromActiveChat()
        activeMessage = nil
    }
    
    func clearCache() {
        dmCache.removeAll()
        chatroomCache.removeAll()
    }
}

// MARK: - Global Messaging Overlay
struct RLGlobalMessagingOverlay: ViewModifier {
    @EnvironmentObject var messagingManager: RLMessagingManager
    
    func body(content: Content) -> some View {
        content
            .sheet(item: Binding<RLMessageContentItem?>(
                get: {
                    if let activeMessage = messagingManager.activeMessage {
                return RLMessageContentItem(id: activeMessage.id, contentType: activeMessage)
                    }
                    return nil
                },
                set: { _ in
                    messagingManager.closeMessage()
                }
            )) { item in
                RLMessagingSheet(contentType: item.contentType)
                    .environmentObject(messagingManager)
                    .presentationDetents([.fraction(0.9)])
                    .presentationBackground {
                        ZStack {
                            Color.clear
                                .background(.ultraThinMaterial)
                            AppColors.sheetBackground
                        }
                    }
                    .presentationCornerRadius(33)
                    .interactiveDismissDisabled(true)
            }
    }
}

// MARK: - Helper for Sheet Presentation
struct RLMessageContentItem: Identifiable {
    let id: UUID
    let contentType: RLMessageContentType
}

// MARK: - View Extension for Easy Access
extension View {
    func rlGlobalMessaging() -> some View {
        self.modifier(RLGlobalMessagingOverlay())
    }
}

// MARK: - Unified Messaging Sheet
struct RLMessagingSheet: View {
    let contentType: RLMessageContentType
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: RLMessagingManager
    @EnvironmentObject var appState: RLAppState
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var messageText = ""
    @State private var showUserProfile = false
    @State private var selectedChatroomUser: RLGuildMemberDTO? = nil
    @State private var showSettings = false
    @State private var hasMarkedAsRead = false
    @State private var typingWorkItem: DispatchWorkItem? = nil
    @State private var hasSentTyping: Bool = false
    @State private var lastChatroomMetadataSignature: String? = nil
    
    // Message state
    @State private var chatroomMessages: [RLChatroomMessageDTO] = []
    @State private var dmMessages: [RLDMMessageDTO] = []
    @State private var replyDraft: ChatReplyDraft? = nil
    @State private var isLoadingMessages = false
    @State private var hasMoreMessages = false
    @State private var nextCursor: String? = nil
    @State private var isLoadingMore = false
    @State private var editTarget: MessagingEditTarget? = nil
    @State private var reportTarget: MessagingReportTarget? = nil
    @State private var reactionReactorsState = ChatReactionReactorsState()
    @StateObject private var chatSurfaceOverlayCoordinator = ChatSurfaceOverlayCoordinator()

    // Scroll tracking
    @State private var isNearBottom = true
    @State private var newMessageCount = 0

    // Optimistic sending — track pending message IDs for delivery status indicator
    @State private var pendingMessageIds: Set<UUID> = []

    // Profile state
    @State private var profileExtendedProfile: RLUserProfileDTO? = nil
    @State private var profileStatistics: RLUserGlobalStatisticsDTO? = nil
    @State private var profileMarkers: [RLTopMarkerDTO] = []
    @State private var profileAwards: [RLUserAwardDTO] = []
    @State private var profileAwardsSummary: RLAwardsSummaryDTO? = nil
    @State private var isProfileLoading: Bool = false

    private var actionPanelVisibility: Binding<Bool> {
        Binding(
            get: { chatSurfaceOverlayCoordinator.isComposerActionPanelVisible },
            set: { isVisible in
                chatSurfaceOverlayCoordinator.setComposerActionPanelVisible(isVisible)
            }
        )
    }

    private enum MessagingEditTarget: Identifiable {
        case chatroom(RLChatroomMessageDTO)
        case dm(RLDMMessageDTO)

        var id: UUID {
            switch self {
            case .chatroom(let message):
                return message.id
            case .dm(let message):
                return message.id
            }
        }

        var originalContent: String {
            switch self {
            case .chatroom(let message):
                return ChatMessageVisibleText.value(for: message)
            case .dm(let message):
                return ChatMessageVisibleText.value(for: message)
            }
        }
    }

    private enum MessagingReportTarget: Identifiable {
        case chatroom(RLChatroomMessageDTO)
        case dm(RLDMMessageDTO)

        var id: UUID {
            switch self {
            case .chatroom(let message):
                return message.id
            case .dm(let message):
                return message.id
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Main messaging view
            if !showUserProfile && !showSettings {
                messagingView
                    .transition(.move(edge: .leading))
                    .onAppear {
                        markAsRead()
                    }
            }
            
            // User profile view for DMs
            if showUserProfile, case .dmThread(let thread) = contentType {
                userProfileView(for: thread.participant, backTitle: "Back to Chat")
                    .transition(.move(edge: .trailing))
            }
            
            // User profile view for chatroom users
            if showUserProfile, case .chatroom = contentType, let selectedUser = selectedChatroomUser {
                userProfileView(for: selectedUser, backTitle: "Back to Chatroom")
                    .transition(.move(edge: .trailing))
            }
            
            // Settings view
            if showSettings {
                settingsView
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showUserProfile)
        .animation(.easeInOut(duration: 0.3), value: showSettings)
        .environmentObject(chatSurfaceOverlayCoordinator)
    }
    
    // MARK: - Mark as Read Function
    private func markAsRead() {
        guard !hasMarkedAsRead else { return }
        hasMarkedAsRead = true
        
        Task {
            do {
                switch contentType {
                case .dmThread(let thread):
                    try await appState.markDMAsRead(threadId: thread.id)
                    rightDrawerViewModel.markDMAsRead(threadId: thread.id)
                    
                case .chatroom(let chatroom):
                    try await appState.markChatroomAsRead(chatroomId: chatroom.id)
                    rightDrawerViewModel.markChatroomAsRead(chatroomId: chatroom.id)
                }
            } catch {
                print("Failed to mark as read: \(error)")
            }
        }
    }
    
    // MARK: - Messaging View
    private var messagingView: some View {
        KeyboardAwareBottomInsetContainer(
            showsDivider: true,
            mode: .chat,
            footerBackground: AnyView(ChatChromeBarBackground())
        ) {
            VStack(spacing: 0) {
                ChatSurfaceHeader(horizontalPadding: 20, topPadding: 20, bottomPadding: 16) {
                    HStack {
                        // Settings button
                        ChatSettingsButton {
                            withAnimation {
                                showSettings = true
                            }
                            HapticFeedback.light.trigger()
                        }
                        
                        Spacer()
                        
                        // Header content
                        switch contentType {
                        case .chatroom(let chatroom):
                            chatroomHeader(resolvedChatroom(for: chatroom))
                        case .dmThread(let thread):
                            Button(action: {
                                withAnimation {
                                    showUserProfile = true
                                }
                                HapticFeedback.light.trigger()
                            }) {
                                dmHeader(thread)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()

                        // Close button
                        ChatDismissButton {
                            messagingManager.closeMessage()
                            dismiss()
                        }
                    }
                }

                // Messages list
                messagesListView
            }
        } footer: {
            switch contentType {
            case .chatroom(let chatroom):
                RLChatroomFooterView(
                    chatroom: resolvedChatroom(for: chatroom),
                    messageText: $messageText,
                    replyDraft: $replyDraft,
                    isActionPanelVisible: actionPanelVisibility,
                    mentionCandidates: rightDrawerViewModel.guildMembers,
                    onMessageSent: { message in
                        chatroomMessages.append(message)
                    },
                    onPendingMessage: { pending in
                        pendingMessageIds.insert(pending.id)
                        chatroomMessages.append(pending)
                    },
                    onMessageConfirmed: { pendingId, confirmed in
                        pendingMessageIds.remove(pendingId)
                        if let idx = chatroomMessages.firstIndex(where: { $0.id == pendingId }) {
                            chatroomMessages[idx] = confirmed
                        } else {
                            chatroomMessages.append(confirmed)
                        }
                    },
                    onSendFailed: { pendingId in
                        pendingMessageIds.remove(pendingId)
                        chatroomMessages.removeAll { $0.id == pendingId }
                    }
                )
            case .dmThread(let thread):
                RLDMFooterView(
                    thread: thread,
                    messageText: $messageText,
                    replyDraft: $replyDraft,
                    isActionPanelVisible: actionPanelVisibility,
                    onMessageSent: { message in
                        dmMessages.append(message)
                    },
                    onPendingMessage: { pending in
                        pendingMessageIds.insert(pending.id)
                        dmMessages.append(pending)
                    },
                    onMessageConfirmed: { pendingId, confirmed in
                        pendingMessageIds.remove(pendingId)
                        if let idx = dmMessages.firstIndex(where: { $0.id == pendingId }) {
                            dmMessages[idx] = confirmed
                        } else {
                            dmMessages.append(confirmed)
                        }
                    },
                    onSendFailed: { pendingId in
                        pendingMessageIds.remove(pendingId)
                        dmMessages.removeAll { $0.id == pendingId }
                    }
                )
            }
        }
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
        .task(id: contentType.id) {
            chatSurfaceOverlayCoordinator.dismissAll()
            resetMessageState()
            await loadMessages()
        }
        .onAppear {
            initializeMetadataSignature()
        }
        .onReceive(rightDrawerViewModel.$guildChatrooms) { _ in
            handleChatroomMetadataSync()
        }
        .onChange(of: messageText) { _, newValue in
            handleTypingChange(newValue)
        }
        .onReceive(messagingManager.incomingMessageSubject) { incoming in
            switch incoming {
            case .chatroom(let message):
                guard case .chatroom(let chatroom) = contentType,
                      message.chatroomId == chatroom.id else { return }
                if !chatroomMessages.contains(where: { $0.id == message.id }) {
                    chatroomMessages.append(message)
                }
            case .dm(let message):
                guard case .dmThread(let thread) = contentType,
                      message.dmId == thread.id else { return }
                if !dmMessages.contains(where: { $0.id == message.id }) {
                    dmMessages.append(message)
                }
            }
        }
        .onReceive(messagingManager.editedMessageSubject) { edited in
            switch edited {
            case .chatroom(let message):
                guard case .chatroom(let chatroom) = contentType,
                      message.chatroomId == chatroom.id,
                      let index = chatroomMessages.firstIndex(where: { $0.id == message.id }) else { return }
                chatroomMessages[index] = message
            case .dm(let message):
                guard case .dmThread(let thread) = contentType,
                      message.dmId == thread.id,
                      let index = dmMessages.firstIndex(where: { $0.id == message.id }) else { return }
                dmMessages[index] = message
            }
        }
        .onReceive(messagingManager.deletedMessageSubject) { deletedId in
            switch contentType {
            case .chatroom:
                chatroomMessages.removeAll { $0.id == deletedId }
            case .dmThread:
                dmMessages.removeAll { $0.id == deletedId }
            }
        }
        .onReceive(messagingManager.reactionUpdatedSubject) { payload in
            guard let messageId = UUID(uuidString: payload.messageId) else { return }
            switch contentType {
            case .chatroom:
                guard let index = chatroomMessages.firstIndex(where: { $0.id == messageId }) else { return }
                chatroomMessages[index].reactions = mergeReactions(
                    current: chatroomMessages[index].reactions,
                    incoming: payload.reactions
                )
            case .dmThread:
                guard let index = dmMessages.firstIndex(where: { $0.id == messageId }) else { return }
                dmMessages[index].reactions = mergeReactions(
                    current: dmMessages[index].reactions,
                    incoming: payload.reactions
                )
            }
        }
        .sheet(item: $editTarget) { target in
            UnifiedEditMessageSheet(originalContent: target.originalContent) { newContent in
                switch target {
                case .chatroom(let message):
                    try await appState.editChatroomMessage(
                        chatroomId: message.chatroomId,
                        messageId: message.id,
                        content: newContent
                    )
                case .dm(let message):
                    try await appState.editDMMessage(
                        threadId: message.dmId,
                        messageId: message.id,
                        content: newContent
                    )
                }
                appState.showSuccess(RLUserFacingCopy.text(.successMessageUpdated))
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportReasonSheet(
                title: "Why are you reporting this message?",
                includeScam: false,
                onReasonSelected: { reason in
                    Task {
                        await reportMessage(target, reason: reason)
                        await MainActor.run {
                            reportTarget = nil
                        }
                    }
                },
                onCancel: {
                    reportTarget = nil
                }
            )
        }
    }

    private func handleTypingChange(_ text: String) {
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEmpty {
            if hasSentTyping {
                messagingManager.sendTypingIndicator(isTyping: false)
                hasSentTyping = false
            }
            typingWorkItem?.cancel()
            typingWorkItem = nil
            return
        }
        
        if !hasSentTyping {
            messagingManager.sendTypingIndicator(isTyping: true)
            hasSentTyping = true
        }
        
        typingWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            messagingManager.sendTypingIndicator(isTyping: false)
            hasSentTyping = false
        }
        typingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }
    
    // MARK: - Headers
    
    private func chatroomHeader(_ chatroom: RLGuildChatroomDTO) -> some View {
        let trimmedDescription = chatroom.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subtitle = trimmedDescription.isEmpty ? "No description yet" : trimmedDescription

        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(chatroom.displayIcon)
                    .font(.headline.weight(.bold))
                Text(chatroom.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(AppColors.whiteText)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.whiteText.opacity(0.6))
                .lineLimit(1)
        }
    }
    
    private func dmHeader(_ thread: RLDMThreadDTO) -> some View {
        let isTyping = isTypingForCurrentDM(thread)
        let isOnline = appState.effectiveOnlineStatus(userId: thread.participant.userId, fallback: thread.participant.isOnline)
        let statusText = isTyping ? "Typing..." : (isOnline ? "Online" : "Offline")
        let statusColor = isTyping ? AppColors.accentColor : (isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
        
        return HStack(spacing: 8) {
            // Avatar - using unified ChatAvatar
            ChatAvatar(
                initials: thread.participant.initials,
                avatarURL: thread.participant.avatarUrl,
                isOnline: isOnline,
                size: 36
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.participant.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
    }

    private func isTypingForCurrentDM(_ thread: RLDMThreadDTO) -> Bool {
        let currentUserId = appState.currentUser?.id.uuidString.lowercased()
        let typingUsers = messagingManager.activeTypingUsers.filter { $0 != currentUserId }
        let threadUserId = thread.participant.userId.uuidString.lowercased()
        return typingUsers.contains(threadUserId)
    }

    /// Typing usernames for the current chatroom, excluding the current user.
    private var chatroomTypingUsernames: [String] {
        let currentUserId = appState.currentUser?.id.uuidString.lowercased()
        let typingIds = messagingManager.activeTypingUsers.filter { $0 != currentUserId }
        guard !typingIds.isEmpty else { return [] }
        return typingIds.compactMap { uid in
            rightDrawerViewModel.guildMembers.first { $0.userId.uuidString.lowercased() == uid }?.username
        }
    }

    @ViewBuilder
    private var typingIndicatorView: some View {
        switch contentType {
        case .chatroom:
            let usernames = chatroomTypingUsernames
            if !usernames.isEmpty {
                ChatroomTypingIndicator(typingUsernames: usernames)
                    .animation(.easeInOut(duration: 0.2), value: usernames.count)
            }
        case .dmThread(let thread):
            if isTypingForCurrentDM(thread) {
                TypingIndicatorBubble(username: thread.participant.username)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: true)
            }
        }
    }

    // MARK: - Messages List
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Auto-prefetch sentinel — triggers when scrolled near top
                    if hasMoreMessages {
                        Group {
                            if isLoadingMore {
                                ProgressView()
                                    .tint(AppColors.primaryForeground)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            } else {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task { await loadMoreMessages() }
                                    }
                            }
                        }
                    }
                    
                    switch contentType {
                    case .chatroom:
                        ForEach(Array(chatroomMessages.enumerated()), id: \.element.id) { index, message in
                            let previousMessage = index > 0 ? chatroomMessages[index - 1] : nil

                            if ChatMessageGrouping.shouldShowDateSeparator(message: message, previousMessage: previousMessage) {
                                ChatDateSeparator(date: message.timestamp)
                            }

                            RLChatroomMessageView(
                                message: message,
                                isGrouped: !ChatMessageGrouping.shouldShowHeader(message: message, previousMessage: previousMessage),
                                isPending: pendingMessageIds.contains(message.id),
                                onReply: { replyDraft = ChatReplyDraft(message: message) },
                                onReactionSelected: { emoji in
                                    Task { await toggleChatroomReaction(messageId: message.id, emoji: emoji) }
                                },
                                onVisibleReactionTap: {
                                    presentReactionReactors(messageId: message.id, reactions: message.reactions)
                                },
                                onAvatarTap: {
                                    selectedChatroomUser = message.author
                                    showUserProfile = true
                                }
                            )
                            .id(message.id)
                        }
                    case .dmThread:
                        ForEach(Array(dmMessages.enumerated()), id: \.element.id) { index, message in
                            let previousMessage = index > 0 ? dmMessages[index - 1] : nil

                            if ChatMessageGrouping.shouldShowDateSeparator(message: message, previousMessage: previousMessage) {
                                ChatDateSeparator(date: message.timestamp)
                            }

                            RLDMMessageView(
                                message: message,
                                isGrouped: !ChatMessageGrouping.shouldShowHeader(message: message, previousMessage: previousMessage),
                                isPending: pendingMessageIds.contains(message.id),
                                onReply: { replyDraft = ChatReplyDraft(message: message) },
                                onReactionSelected: { emoji in
                                    Task { await toggleDMReaction(messageId: message.id, emoji: emoji) }
                                },
                                onVisibleReactionTap: {
                                    presentReactionReactors(messageId: message.id, reactions: message.reactions)
                                },
                                onAuthorTap: {
                                    showUserProfile = true
                                }
                            )
                            .id(message.id)
                        }
                    }
                    // Typing indicator
                    typingIndicatorView

                    // Bottom anchor for scroll tracking
                    Color.clear
                        .frame(height: 18)
                        .id("bottomAnchor")
                        .onAppear { isNearBottom = true; newMessageCount = 0 }
                        .onDisappear { isNearBottom = false }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                chatSurfaceOverlayCoordinator.dismissAll()
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
            .onChange(of: chatroomMessages.count) { _, _ in
                guard !isLoadingMore else { return }
                if isNearBottom {
                    scrollToBottom(proxy: proxy)
                } else {
                    newMessageCount += 1
                }
            }
            .onChange(of: dmMessages.count) { _, _ in
                guard !isLoadingMore else { return }
                if isNearBottom {
                    scrollToBottom(proxy: proxy)
                } else {
                    newMessageCount += 1
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !isNearBottom {
                    ChatScrollToBottomButton(unreadCount: newMessageCount) {
                        newMessageCount = 0
                        scrollToBottom(proxy: proxy)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isNearBottom)
                }
            }
            .onChange(of: isLoadingMessages) { _, isLoading in
                guard !isLoading else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    scrollToBottom(proxy: proxy)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    scrollToBottom(proxy: proxy)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    scrollToBottom(proxy: proxy)
                }
            }
            .background(ChatBackground())
        }
        .overlay {
            ZStack {
                switch contentType {
                case .chatroom:
                    ChatSurfaceOverlayHost(
                        messages: chatroomMessages,
                        reactorsState: reactionReactorsState,
                        onQuickReactionSelected: { message, emoji in
                            Task { await toggleChatroomReaction(messageId: message.id, emoji: emoji) }
                        },
                        onReply: { message in
                            replyDraft = ChatReplyDraft(message: message)
                        },
                        onEdit: { message in
                            editTarget = .chatroom(message)
                        },
                        onDelete: { message in
                            Task { await deleteChatroomMessage(message) }
                        },
                        onCopy: { _ in
                            appState.showSuccess(RLUserFacingCopy.text(.successCopiedToClipboard))
                        },
                        onReport: { message in
                            reportTarget = .chatroom(message)
                        },
                        onFetchReactors: { message, emoji in
                            fetchReactorsForEmoji(messageId: message.id, emoji: emoji)
                        }
                    )
                case .dmThread:
                    ChatSurfaceOverlayHost(
                        messages: dmMessages,
                        reactorsState: reactionReactorsState,
                        onQuickReactionSelected: { message, emoji in
                            Task { await toggleDMReaction(messageId: message.id, emoji: emoji) }
                        },
                        onReply: { message in
                            replyDraft = ChatReplyDraft(message: message)
                        },
                        onEdit: { message in
                            editTarget = .dm(message)
                        },
                        onDelete: { message in
                            Task { await deleteDMMessage(message) }
                        },
                        onCopy: { _ in
                            appState.showSuccess(RLUserFacingCopy.text(.successCopiedToClipboard))
                        },
                        onReport: { message in
                            reportTarget = .dm(message)
                        },
                        onFetchReactors: { message, emoji in
                            fetchReactorsForEmoji(messageId: message.id, emoji: emoji)
                        }
                    )
                }

                if isLoadingMessages {
                    ProgressView()
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
        }
    }
    
    // MARK: - Load Messages
    
    private func loadMessages() async {
        await MainActor.run {
            isLoadingMessages = true
            hasMoreMessages = false
            nextCursor = nil
        }
        defer { isLoadingMessages = false }
        
        do {
            switch contentType {
            case .chatroom(let chatroom):
                let response = try await appState.fetchChatroomMessages(chatroomId: chatroom.id)
                chatroomMessages = normalizeChatroomMessages(response.messages)
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
                
            case .dmThread(let thread):
                let response = try await appState.fetchDMMessages(threadId: thread.id)
                dmMessages = normalizeDMMessages(response.messages)
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
            }
        } catch {
            // Error shown by appState
        }
    }
    
    private func loadMoreMessages() async {
        guard let cursor = nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            switch contentType {
            case .chatroom(let chatroom):
                let response = try await appState.fetchChatroomMessages(chatroomId: chatroom.id, cursor: cursor)
                let olderMessages = normalizeChatroomMessages(response.messages)
                chatroomMessages.insert(contentsOf: olderMessages, at: 0)
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
                
            case .dmThread(let thread):
                let response = try await appState.fetchDMMessages(threadId: thread.id, cursor: cursor)
                let olderMessages = normalizeDMMessages(response.messages)
                dmMessages.insert(contentsOf: olderMessages, at: 0)
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
            }
        } catch {
            // Error shown by appState
        }
    }

    private func normalizeChatroomMessages(_ messages: [RLChatroomMessageDTO]) -> [RLChatroomMessageDTO] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    private func normalizeDMMessages(_ messages: [RLDMMessageDTO]) -> [RLDMMessageDTO] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    private func toggleChatroomReaction(messageId: UUID, emoji: String) async {
        guard case .chatroom(let chatroom) = contentType else { return }
        do {
            let updated = try await appState.toggleChatroomMessageReaction(
                chatroomId: chatroom.id,
                messageId: messageId,
                emoji: emoji
            )
            if let index = chatroomMessages.firstIndex(where: { $0.id == updated.id }) {
                chatroomMessages[index] = updated
            }
        } catch {
            appState.showError(error, title: "Reaction Failed", style: .toast)
        }
    }

    private func toggleDMReaction(messageId: UUID, emoji: String) async {
        guard case .dmThread(let thread) = contentType else { return }
        do {
            let updated = try await appState.toggleDMMessageReaction(
                threadId: thread.id,
                messageId: messageId,
                emoji: emoji
            )
            if let index = dmMessages.firstIndex(where: { $0.id == updated.id }) {
                dmMessages[index] = updated
            }
        } catch {
            appState.showError(error, title: "Reaction Failed", style: .toast)
        }
    }

    private func mergeReactions(
        current: [RLMessageReactionDTO],
        incoming: [RLReactionAggregateDTO]
    ) -> [RLMessageReactionDTO] {
        let currentByEmoji = Dictionary(uniqueKeysWithValues: current.map { ($0.emoji, $0) })
        return incoming.map { reaction in
            RLMessageReactionDTO(
                emoji: reaction.emoji,
                count: reaction.count,
                reactedByCurrentUser: currentByEmoji[reaction.emoji]?.reactedByCurrentUser ?? false
            )
        }
    }

    private func presentReactionReactors(messageId: UUID, reactions: [RLMessageReactionDTO]) {
        chatSurfaceOverlayCoordinator.presentReactionReactors(for: messageId, reactions: reactions)

        // Reset state for new message
        if reactionReactorsState.messageID != messageId {
            reactionReactorsState = ChatReactionReactorsState(messageID: messageId)
        }
    }

    private func fetchReactorsForEmoji(messageId: UUID, emoji: String) {
        // Already fetched
        if reactionReactorsState.messageID == messageId,
           reactionReactorsState.response(for: emoji) != nil {
            return
        }

        // Mark as loading
        reactionReactorsState.loadingEmojis.insert(emoji)

        Task {
            do {
                let response: RLMessageReactionReactorsDTO
                switch contentType {
                case .chatroom(let chatroom):
                    response = try await appState.fetchChatroomMessageReactionReactors(
                        chatroomId: chatroom.id,
                        messageId: messageId,
                        emoji: emoji
                    )
                case .dmThread(let thread):
                    response = try await appState.fetchDMMessageReactionReactors(
                        threadId: thread.id,
                        messageId: messageId,
                        emoji: emoji
                    )
                }

                await MainActor.run {
                    reactionReactorsState.responses[emoji] = response
                    reactionReactorsState.loadingEmojis.remove(emoji)
                }
            } catch {
                await MainActor.run {
                    reactionReactorsState.loadingEmojis.remove(emoji)
                    appState.showError(error, title: "Failed to Load Reactions", style: .toast)
                }
            }
        }
    }

    private func deleteChatroomMessage(_ message: RLChatroomMessageDTO) async {
        do {
            try await appState.deleteChatroomMessage(
                chatroomId: message.chatroomId,
                messageId: message.id
            )
        } catch {
            appState.showError(error, title: "Failed to Delete", style: .toast)
        }
    }

    private func deleteDMMessage(_ message: RLDMMessageDTO) async {
        do {
            try await appState.deleteDMMessage(
                threadId: message.dmId,
                messageId: message.id
            )
        } catch {
            appState.showError(error, title: "Failed to Delete", style: .toast)
        }
    }

    private func reportMessage(_ target: MessagingReportTarget, reason: String) async {
        guard let guildId = appState.currentGuild?.id else { return }
        HapticFeedback.medium.trigger()
        do {
            switch target {
            case .chatroom(let message):
                _ = try await appState.realApi.reportChatroomMessage(
                    guildId: guildId,
                    chatroomId: message.chatroomId,
                    messageId: message.id,
                    reason: reason
                )
            case .dm(let message):
                _ = try await appState.realApi.reportDMMessage(
                    guildId: guildId,
                    threadId: message.dmId,
                    messageId: message.id,
                    reason: reason
                )
            }
            appState.showSuccess(RLUserFacingCopy.text(.successReportSubmitted))
        } catch {
            appState.showError(error, title: "Failed to Report", style: .toast)
        }
    }

    private func resetMessageState() {
        chatroomMessages = []
        dmMessages = []
        replyDraft = nil
        hasMoreMessages = false
        nextCursor = nil
        hasMarkedAsRead = false
        lastChatroomMetadataSignature = nil
        editTarget = nil
        reportTarget = nil
        reactionReactorsState = ChatReactionReactorsState()
        pendingMessageIds = []
    }

    private func initializeMetadataSignature() {
        guard case .chatroom(let chatroom) = contentType else {
            lastChatroomMetadataSignature = nil
            return
        }
        let resolved = resolvedChatroom(for: chatroom)
        lastChatroomMetadataSignature = metadataSignature(for: resolved)
    }

    private func handleChatroomMetadataSync() {
        guard case .chatroom(let chatroom) = contentType else { return }
        let resolved = resolvedChatroom(for: chatroom)
        let newSignature = metadataSignature(for: resolved)

        guard let previousSignature = lastChatroomMetadataSignature else {
            lastChatroomMetadataSignature = newSignature
            return
        }

        guard previousSignature != newSignature else { return }
        lastChatroomMetadataSignature = newSignature
        appState.showSuccess("Chatroom details updated")
    }

    private func metadataSignature(for chatroom: RLGuildChatroomDTO) -> String {
        let description = chatroom.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "\(chatroom.id.uuidString.lowercased())|\(chatroom.name)|\(chatroom.displayIcon)|\(description)"
    }

    // MARK: - User Profile View
    private func userProfileView(for member: RLGuildMemberDTO, backTitle: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                ChatBackButton(title: backTitle) {
                    withAnimation {
                        showUserProfile = false
                        selectedChatroomUser = nil
                    }
                }
                
                Spacer()
                
                Text("Profile")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                
                Spacer()
                
                ChatDismissButton {
                    messagingManager.closeMessage()
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppColors.sheetBackground)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    GuildMemberProfileHeaderViewRL(member: member)

                    if isProfileLoading {
                        ProgressView()
                            .scaleEffect(1.1)
                            .padding(.top, 12)
                    } else {
                        ProfileContentView(
                            extendedProfile: profileExtendedProfile,
                            markersSummary: profileStatistics,
                            userMarkers: profileMarkers,
                            awards: profileAwards,
                            awardsSummary: profileAwardsSummary,
                            stats: buildProfileStats(for: member),
                            isCurrentUser: false,
                            username: member.username,
                            tabs: [.overview, .markers, .awards],
                            onMarkerTap: { marker in
                                leftDrawerViewModel.requestNavigationToMarker(marker)
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
        .task(id: member.userId) {
            await loadProfileData(for: member)
        }
    }

    private func loadProfileData(for member: RLGuildMemberDTO) async {
        guard let guildId = appState.currentGuild?.id else { return }
        isProfileLoading = true
        let data = await leftDrawerViewModel.loadMemberProfile(
            member: member,
            rlAppState: appState,
            guildId: guildId
        )
        await MainActor.run {
            profileExtendedProfile = data.profile
            profileStatistics = data.statistics
            profileMarkers = data.userMarkers
            profileAwards = data.awards
            profileAwardsSummary = data.awardsSummary
            isProfileLoading = false
        }
    }

    private func buildProfileStats(for member: RLGuildMemberDTO) -> [ProfileStatDTO] {
        var stats = [
            ProfileStatDTO(
                label: "Guild Reputation",
                value: "\(member.reputation)",
                icon: "shield.checkered",
                color: AppColors.accentColor,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Accuracy",
                value: member.accuracyFormatted ?? "--",
                icon: "target",
                color: .green,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Global Reputation",
                value: "\(member.globalReputation)",
                icon: "globe",
                color: .blue,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Days in Guild",
                value: "\(member.daysInGuild)",
                icon: "calendar",
                color: .cyan,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Contribution",
                value: "\(member.contributionScore)%",
                icon: "chart.bar.fill",
                color: .orange,
                trend: nil
            ),
        ]
        return stats
    }
    
    // MARK: - Settings View
    
    @ViewBuilder
    private var settingsView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                ChatBackButton(title: "Back") {
                    withAnimation {
                        showSettings = false
                    }
                }
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                
                Spacer()
                
                ChatDismissButton {
                    messagingManager.closeMessage()
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppColors.sheetBackground)
            
            Divider()
            
            // Settings content based on content type
            switch contentType {
            case .chatroom(let chatroom):
                RLChatroomSettingsView(chatroom: resolvedChatroom(for: chatroom))
                
            case .dmThread(let thread):
                RLDMSettingsView(thread: thread)
            }
        }
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
            }
        )
    }

    private func resolvedChatroom(for fallback: RLGuildChatroomDTO) -> RLGuildChatroomDTO {
        rightDrawerViewModel.findChatroom(id: fallback.id) ?? fallback
    }
}

// MARK: - Chatroom Footer View
struct RLChatroomFooterView: View {
    let chatroom: RLGuildChatroomDTO
    @Binding var messageText: String
    @Binding var replyDraft: ChatReplyDraft?
    var isActionPanelVisible: Binding<Bool>? = nil
    var mentionCandidates: [RLGuildMemberDTO] = []
    let onMessageSent: (RLChatroomMessageDTO) -> Void
    var onPendingMessage: ((RLChatroomMessageDTO) -> Void)? = nil
    var onMessageConfirmed: ((UUID, RLChatroomMessageDTO) -> Void)? = nil
    var onSendFailed: ((UUID) -> Void)? = nil

    @EnvironmentObject var appState: RLAppState
    @State private var isSending: Bool = false

    var body: some View {
        ChatInputFooter(
            messageText: $messageText,
            replyDraft: $replyDraft,
            placeholder: "Message #\(chatroom.name.lowercased().replacingOccurrences(of: " ", with: "-"))...",
            isSending: isSending,
            onSend: { payload in
                await sendComposedMessage(payload)
            },
            allowsMarkerLinkAttachment: true,
            isActionPanelVisible: isActionPanelVisible,
            mentionCandidates: mentionCandidates
        )
    }

    private func sendComposedMessage(_ payload: ChatComposerPayload) async -> Bool {
        guard chatroom.canSendMessages else {
            appState.showError(
                title: "Cannot Send",
                message: RLUserFacingCopy.text(.errorCannotSendNoPermission),
                style: .toast
            )
            return false
        }

        guard payload.hasBodyContent else { return false }

        isSending = true
        defer { isSending = false }

        let savedText = payload.text
        let savedReply = payload.replyDraft
        var pendingId: UUID? = nil

        do {
            let uploadedAttachments = try await uploadAttachments(payload.attachments)

            // Optimistic insert — show the bundled message immediately
            let currentMember = appState.currentGuildMember
            let pendingMsg: RLChatroomMessageDTO? = currentMember.map {
                .pending(
                    chatroomId: chatroom.id,
                    content: payload.encodedContent(),
                    author: $0,
                    attachments: uploadedAttachments,
                    replyPreview: nil
                )
            }
            if let pendingMsg {
                onPendingMessage?(pendingMsg)
            }
            pendingId = pendingMsg?.id

            replyDraft = nil

            let message = try await appState.sendChatroomMessage(
                chatroomId: chatroom.id,
                content: payload.encodedContent(),
                attachmentUrl: uploadedAttachments.first?.attachmentUrl,
                attachmentType: uploadedAttachments.first?.attachmentType,
                attachmentName: uploadedAttachments.first?.attachmentName,
                attachments: uploadedAttachments,
                replyToMessageId: savedReply?.messageId
            )
            if let pendingId {
                onMessageConfirmed?(pendingId, message)
            } else {
                onMessageSent(message)
            }
            return true
        } catch {
            if let pendingId {
                onSendFailed?(pendingId)
            }
            messageText = savedText
            replyDraft = savedReply
            appState.showError(error, title: "Failed to Send Message", style: .toast)
            return false
        }
    }

    private func uploadAttachments(_ drafts: [ChatAttachmentDraft]) async throws -> [RLMessageAttachmentDTO] {
        guard !drafts.isEmpty else { return [] }
        guard let guild = appState.currentGuild else { return [] }

        var uploads: [RLMessageAttachmentDTO] = []
        for attachment in drafts {
            let upload = try await appState.realApi.uploadChatroomAttachment(
                guildId: guild.id,
                chatroomId: chatroom.id,
                fileData: attachment.data,
                filename: attachment.filename,
                mimeType: attachment.mimeType
            )
            uploads.append(
                RLMessageAttachmentDTO(
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName
                )
            )
        }
        return uploads
    }
}

// MARK: - DM Footer View
struct RLDMFooterView: View {
    let thread: RLDMThreadDTO
    @Binding var messageText: String
    @Binding var replyDraft: ChatReplyDraft?
    var isActionPanelVisible: Binding<Bool>? = nil
    let onMessageSent: (RLDMMessageDTO) -> Void
    var onPendingMessage: ((RLDMMessageDTO) -> Void)? = nil
    var onMessageConfirmed: ((UUID, RLDMMessageDTO) -> Void)? = nil
    var onSendFailed: ((UUID) -> Void)? = nil

    @EnvironmentObject var appState: RLAppState
    @State private var isSending: Bool = false

    var body: some View {
        ChatInputFooter(
            messageText: $messageText,
            replyDraft: $replyDraft,
            placeholder: "Message \(thread.participant.username.lowercased())...",
            isSending: isSending,
            onSend: { payload in
                await sendComposedMessage(payload)
            },
            allowsMarkerLinkAttachment: true,
            isActionPanelVisible: isActionPanelVisible
        )
    }

    private func sendComposedMessage(_ payload: ChatComposerPayload) async -> Bool {
        if thread.isBlocked {
            appState.showError(
                title: "Cannot Send",
                message: RLUserFacingCopy.text(.errorCannotSendBlockedUser),
                style: .toast
            )
            return false
        }

        guard payload.hasBodyContent else { return false }

        isSending = true
        defer { isSending = false }

        let savedText = payload.text
        let savedReply = payload.replyDraft
        var pendingId: UUID? = nil

        do {
            let uploadedAttachments = try await uploadAttachments(payload.attachments)

            let currentMember = appState.currentGuildMember
            let pendingMsg: RLDMMessageDTO? = currentMember.map {
                .pending(
                    dmId: thread.id,
                    content: payload.encodedContent(),
                    author: $0,
                    attachments: uploadedAttachments,
                    replyPreview: nil
                )
            }
            if let pendingMsg {
                onPendingMessage?(pendingMsg)
            }
            pendingId = pendingMsg?.id

            replyDraft = nil
            let message = try await appState.sendDMMessage(
                threadId: thread.id,
                content: payload.encodedContent(),
                attachmentUrl: uploadedAttachments.first?.attachmentUrl,
                attachmentType: uploadedAttachments.first?.attachmentType,
                attachmentName: uploadedAttachments.first?.attachmentName,
                attachments: uploadedAttachments,
                replyToMessageId: savedReply?.messageId
            )
            if let pendingId {
                onMessageConfirmed?(pendingId, message)
            } else {
                onMessageSent(message)
            }
            return true
        } catch {
            if let pendingId {
                onSendFailed?(pendingId)
            }
            messageText = savedText
            replyDraft = savedReply
            appState.showError(error, title: "Failed to Send Message", style: .toast)
            return false
        }
    }

    private func uploadAttachments(_ drafts: [ChatAttachmentDraft]) async throws -> [RLMessageAttachmentDTO] {
        guard !drafts.isEmpty else { return [] }
        guard let guild = appState.currentGuild else { return [] }

        var uploads: [RLMessageAttachmentDTO] = []
        for attachment in drafts {
            let upload = try await appState.realApi.uploadDMAttachment(
                guildId: guild.id,
                threadId: thread.id,
                fileData: attachment.data,
                filename: attachment.filename,
                mimeType: attachment.mimeType
            )
            uploads.append(
                RLMessageAttachmentDTO(
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName
                )
            )
        }
        return uploads
    }
}

// MARK: - Chatroom Message View (Using RLChatMessageBubble)
struct RLChatroomMessageView: View {
    let message: RLChatroomMessageDTO
    let isGrouped: Bool
    let isPending: Bool
    let onReply: () -> Void
    let onReactionSelected: (String) -> Void
    let onVisibleReactionTap: () -> Void
    let onAvatarTap: () -> Void

    init(
        message: RLChatroomMessageDTO,
        isGrouped: Bool = false,
        isPending: Bool = false,
        onReply: @escaping () -> Void,
        onReactionSelected: @escaping (String) -> Void,
        onVisibleReactionTap: @escaping () -> Void,
        onAvatarTap: @escaping () -> Void
    ) {
        self.message = message
        self.isGrouped = isGrouped
        self.isPending = isPending
        self.onReply = onReply
        self.onReactionSelected = onReactionSelected
        self.onVisibleReactionTap = onVisibleReactionTap
        self.onAvatarTap = onAvatarTap
    }

    @EnvironmentObject var rlMessagingManager: RLMessagingManager

    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .guildChatroom,
            isPending: isPending,
            isGrouped: isGrouped,
            onAvatarTap: onAvatarTap,
            onAuthorTap: onAvatarTap,
            onReply: onReply,
            onToggleReaction: onReactionSelected,
            onVisibleReactionTap: onVisibleReactionTap,
            onMarkerShareTap: { payload in
                rlMessagingManager.closeMessage()
                NotificationCenter.default.post(
                    name: .openSharedMarker,
                    object: nil,
                    userInfo: payload.notificationUserInfo
                )
            }
        )
    }
}

// MARK: - DM Message View (Using RLChatMessageBubble)
struct RLDMMessageView: View {
    let message: RLDMMessageDTO
    let isGrouped: Bool
    let isPending: Bool
    let onReply: () -> Void
    let onReactionSelected: (String) -> Void
    let onVisibleReactionTap: () -> Void
    let onAuthorTap: (() -> Void)?

    @EnvironmentObject var rlMessagingManager: RLMessagingManager

    init(
        message: RLDMMessageDTO,
        isGrouped: Bool = false,
        isPending: Bool = false,
        onReply: @escaping () -> Void,
        onReactionSelected: @escaping (String) -> Void,
        onVisibleReactionTap: @escaping () -> Void,
        onAuthorTap: (() -> Void)? = nil
    ) {
        self.message = message
        self.isGrouped = isGrouped
        self.isPending = isPending
        self.onReply = onReply
        self.onReactionSelected = onReactionSelected
        self.onVisibleReactionTap = onVisibleReactionTap
        self.onAuthorTap = onAuthorTap
    }

    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .directMessage,
            isRead: message.isRead,
            isPending: isPending,
            isGrouped: isGrouped,
            onAuthorTap: onAuthorTap,
            onReply: onReply,
            onToggleReaction: onReactionSelected,
            onVisibleReactionTap: onVisibleReactionTap,
            onMarkerShareTap: { payload in
                rlMessagingManager.closeMessage()
                NotificationCenter.default.post(
                    name: .openSharedMarker,
                    object: nil,
                    userInfo: payload.notificationUserInfo
                )
            }
        )
    }
}














//
//  RLMessagingManager+RealTime.swift
//  traders_guild
//
//  Handles real-time logic for the active messaging session.
//


extension RLMessagingManager {
    
    // MARK: - Setup
    
    /// Call this when MessagingManager is initialized or configured
    func setupRealTimeListeners() {
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables) // Ensure RLMessagingManager has cancellables
    }
    
    // MARK: - Subscription Management
    
    /// Subscribe to the active chat channel
    func subscribeToActiveChat() {
        guard let activeMessage = activeMessage else { return }
        
        let channel: String
        switch activeMessage {
        case .chatroom(let chatroom):
            channel = MessagingChannel.chatroom(chatroom.id).name
        case .dmThread(let thread):
            channel = MessagingChannel.dm(thread.id).name
        }
        
        if let current = currentSubscribedChannel, current != channel {
            print("📡 [MessagingManager] Unsubscribing from \(current)")
            RealTimeService.shared.unsubscribe(from: [current], owner: "messagingManager")
        }
        
        print("📡 [MessagingManager] Subscribing to \(channel)")
        RealTimeService.shared.subscribe(to: [channel], owner: "messagingManager")
        currentSubscribedChannel = channel
    }
    
    /// Unsubscribe from the active chat channel
    func unsubscribeFromActiveChat() {
        guard let activeMessage = activeMessage else { return }
        
        let channel: String
        switch activeMessage {
        case .chatroom(let chatroom):
            channel = MessagingChannel.chatroom(chatroom.id).name
        case .dmThread(let thread):
            channel = MessagingChannel.dm(thread.id).name
        }
        
        print("📡 [MessagingManager] Unsubscribing from \(channel)")
        RealTimeService.shared.unsubscribe(from: [channel], owner: "messagingManager")
        if currentSubscribedChannel == channel {
            currentSubscribedChannel = nil
        }
    }
    
    // MARK: - Typing Indicators
    
    func sendTypingIndicator(isTyping: Bool) {
        guard let activeMessage = activeMessage else { return }
        
        let channel: String
        switch activeMessage {
        case .chatroom(let chatroom):
            channel = MessagingChannel.chatroom(chatroom.id).name
        case .dmThread(let thread):
            channel = MessagingChannel.dm(thread.id).name
        }
        
        RealTimeService.shared.sendTyping(channel: channel, isTyping: isTyping)
    }
    
    // MARK: - Message Handling
    
    private func handleIncomingMessage(_ wsMessage: WSIncomingMessage) {
        guard let type = WSMessageType(rawValue: wsMessage.type) else { return }
        
        // Only process messages relevant to the ACTIVE chat
        guard let currentChannelID = currentChannelID,
              let msgChannel = wsMessage.channel,
              msgChannel.contains(currentChannelID) else {
            // Message is not for the currently open chat window
            // (e.g., notification for a different chat)
            return
        }
        
        switch type {
        case .newMessage:
            handleNewMessage(wsMessage)
            
        case .messageEdited:
            handleMessageEdited(wsMessage)
            
        case .messageDeleted:
            handleMessageDeleted(wsMessage)

        case .messageReactionUpdated:
            handleReactionUpdated(wsMessage)
            
        case .typing:
            handleTyping(wsMessage)
            
        default:
            break
        }
    }
    
    // MARK: - Handlers
    
    private func handleNewMessage(_ wsMessage: WSIncomingMessage) {
        // Determine type based on active context
        if case .chatroom = activeMessage {
            if let message = wsMessage.payload(as: RLChatroomMessageDTO.self) {
                let normalized = normalizeChatroomMessage(message)
                self.incomingMessageSubject.send(.chatroom(normalized))
            }
        } else if case .dmThread = activeMessage {
            if let message = wsMessage.payload(as: RLDMMessageDTO.self) {
                let normalized = normalizeDMMessage(message)
                self.incomingMessageSubject.send(.dm(normalized))
            }
        }
    }
    
    private func handleMessageEdited(_ wsMessage: WSIncomingMessage) {
        // Similar to new message, decode and update list
        if case .chatroom = activeMessage {
            if let message = wsMessage.payload(as: RLChatroomMessageDTO.self) {
                let normalized = normalizeChatroomMessage(message)
                self.editedMessageSubject.send(.chatroom(normalized))
            }
        } else if case .dmThread = activeMessage {
            if let message = wsMessage.payload(as: RLDMMessageDTO.self) {
                let normalized = normalizeDMMessage(message)
                self.editedMessageSubject.send(.dm(normalized))
            }
        }
    }
    
    private func handleMessageDeleted(_ wsMessage: WSIncomingMessage) {
        // Payload usually contains { "message_id": "uuid" }
        guard let payload = wsMessage.payload(as: WSMessageDeletedPayload.self),
              let uuid = UUID(uuidString: payload.messageId) else { return }
        
        self.deletedMessageSubject.send(uuid)
    }

    private func handleReactionUpdated(_ wsMessage: WSIncomingMessage) {
        guard let payload = wsMessage.payload(as: WSMessageReactionUpdatedPayload.self) else { return }
        reactionUpdatedSubject.send(payload)
    }
    
    private func handleTyping(_ wsMessage: WSIncomingMessage) {
        guard let isTyping = wsMessage.isTyping,
              let userId = wsMessage.userId else { return }
        
        // Update typing users list
        if isTyping {
            activeTypingUsers.insert(userId.lowercased())
        } else {
            activeTypingUsers.remove(userId.lowercased())
        }
    }

    private func normalizeChatroomMessage(_ message: RLChatroomMessageDTO) -> RLChatroomMessageDTO {
        guard let currentUserId = appState?.currentUser?.id else { return message }
        let isCurrent = message.author.userId == currentUserId
        return message.isCurrentUserMessage == isCurrent ? message : message.withCurrentUser(isCurrent)
    }

    private func normalizeDMMessage(_ message: RLDMMessageDTO) -> RLDMMessageDTO {
        guard let currentUserId = appState?.currentUser?.id else { return message }
        let isCurrent = message.author.userId == currentUserId
        return message.isCurrentUserMessage == isCurrent ? message : message.withCurrentUser(isCurrent)
    }
    
    // Helper to get ID string of active channel for comparison
    private var currentChannelID: String? {
        switch activeMessage {
        case .chatroom(let c): return c.id.uuidString.lowercased()
        case .dmThread(let t): return t.id.uuidString.lowercased()
        case .none: return nil
        }
    }
}

//
