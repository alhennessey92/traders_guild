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
    
    // Message state
    @State private var chatroomMessages: [RLChatroomMessageDTO] = []
    @State private var dmMessages: [RLDMMessageDTO] = []
    @State private var isLoadingMessages = false
    @State private var hasMoreMessages = false
    @State private var nextCursor: String? = nil
    @State private var isLoadingMore = false

    // Profile state
    @State private var profileExtendedProfile: RLUserProfileDTO? = nil
    @State private var profileStatistics: RLUserGlobalStatisticsDTO? = nil
    @State private var profileMarkers: [RLTopMarkerDTO] = []
    @State private var profileAwards: [RLUserAwardDTO] = []
    @State private var profileAwardsSummary: RLAwardsSummaryDTO? = nil
    @State private var isProfileLoading: Bool = false
    
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
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: 0) {
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
                        chatroomHeader(chatroom)
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(AppColors.sheetBackground)
                
                Divider()
            }
            
            // Messages list
            messagesListView
            Divider()
            
            // Input footer
            switch contentType {
            case .chatroom(let chatroom):
                RLChatroomFooterView(
                    chatroom: chatroom,
                    messageText: $messageText,
                    onMessageSent: { message in
                        chatroomMessages.append(message)
                    }
                )
            case .dmThread(let thread):
                RLDMFooterView(
                    thread: thread,
                    messageText: $messageText,
                    onMessageSent: { message in
                        dmMessages.append(message)
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
            resetMessageState()
            await loadMessages()
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
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.headline)
                Text(chatroom.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(AppColors.whiteText)
            
            Text("\(chatroom.memberCount) members")
                .font(.caption)
                .foregroundColor(AppColors.whiteText.opacity(0.6))
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
    
    // MARK: - Messages List
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Load more button
                    if hasMoreMessages {
                        Button("Load earlier messages") {
                            Task { await loadMoreMessages() }
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.accentColor)
                        .padding(.vertical, 8)
                    }
                    
                    switch contentType {
                    case .chatroom:
                        ForEach(chatroomMessages) { message in
                            RLChatroomMessageView(
                                message: message,
                                onAvatarTap: {
                                    selectedChatroomUser = message.author
                                    showUserProfile = true
                                }
                            )
                            .id(message.id)
                        }
                    case .dmThread:
                        ForEach(dmMessages) { message in
                            RLDMMessageView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: chatroomMessages.count) { _, _ in
                guard !isLoadingMore else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: dmMessages.count) { _, _ in
                guard !isLoadingMore else { return }
                scrollToBottom(proxy: proxy)
            }
        }
        .overlay {
            if isLoadingMessages {
                ProgressView()
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        switch contentType {
        case .chatroom:
            if let lastMessage = chatroomMessages.last {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        case .dmThread:
            if let lastMessage = dmMessages.last {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
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

    private func resetMessageState() {
        chatroomMessages = []
        dmMessages = []
        hasMoreMessages = false
        nextCursor = nil
        hasMarkedAsRead = false
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
                RLChatroomSettingsView(chatroom: chatroom)
                
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
}

// MARK: - Chatroom Footer View
struct RLChatroomFooterView: View {
    let chatroom: RLGuildChatroomDTO
    @Binding var messageText: String
    let onMessageSent: (RLChatroomMessageDTO) -> Void

    @EnvironmentObject var appState: RLAppState
    @State private var isSending: Bool = false

    var body: some View {
        ChatInputFooter(
            messageText: $messageText,
            placeholder: "Message #\(chatroom.name.lowercased().replacingOccurrences(of: " ", with: "-"))...",
            isSending: isSending,
            onSend: { payload in
                Task { await sendComposedMessage(payload) }
            }
        )
    }

    private func sendComposedMessage(_ payload: ChatComposerPayload) async {
        guard chatroom.canSendMessages else {
            appState.showError(title: "Cannot Send", message: "You don't have permission to send messages here", style: .toast)
            return
        }

        if !payload.attachments.isEmpty {
            await sendAttachments(payload)
            return
        }

        guard !payload.text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            let message = try await appState.sendChatroomMessage(
                chatroomId: chatroom.id,
                content: payload.text
            )
            onMessageSent(message)
        } catch {
            messageText = payload.text
        }
    }

    private func sendAttachments(_ payload: ChatComposerPayload) async {
        guard !payload.attachments.isEmpty else { return }
        guard let guild = appState.currentGuild else { return }
        guard chatroom.canSendMessages else {
            appState.showError(title: "Cannot Send", message: "You don't have permission to send messages here", style: .toast)
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            var isFirstMessage = true
            for attachment in payload.attachments {
                let upload = try await appState.realApi.uploadChatroomAttachment(
                    guildId: guild.id,
                    chatroomId: chatroom.id,
                    fileData: attachment.data,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType
                )
                let content: String
                if isFirstMessage {
                    content = payload.text.isEmpty ? attachment.filename : payload.text
                } else {
                    content = attachment.filename
                }
                let message = try await appState.sendChatroomMessage(
                    chatroomId: chatroom.id,
                    content: content,
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName
                )
                onMessageSent(message)
                isFirstMessage = false
            }
        } catch {
            appState.showError(error, title: "Failed to Send Attachment", style: .toast)
        }
    }
}

// MARK: - DM Footer View
struct RLDMFooterView: View {
    let thread: RLDMThreadDTO
    @Binding var messageText: String
    let onMessageSent: (RLDMMessageDTO) -> Void

    @EnvironmentObject var appState: RLAppState
    @State private var isSending: Bool = false

    var body: some View {
        ChatInputFooter(
            messageText: $messageText,
            placeholder: "Message \(thread.participant.username.lowercased())...",
            isSending: isSending,
            onSend: { payload in
                Task { await sendComposedMessage(payload) }
            }
        )
    }

    private func sendComposedMessage(_ payload: ChatComposerPayload) async {
        if thread.isBlocked {
            appState.showError(title: "Cannot Send", message: "You have blocked this user", style: .toast)
            return
        }

        if !payload.attachments.isEmpty {
            await sendAttachments(payload)
            return
        }

        guard !payload.text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            let message = try await appState.sendDMMessage(threadId: thread.id, content: payload.text)
            onMessageSent(message)
        } catch {
            messageText = payload.text
        }
    }

    private func sendAttachments(_ payload: ChatComposerPayload) async {
        guard !payload.attachments.isEmpty else { return }
        guard let guild = appState.currentGuild else { return }

        if thread.isBlocked {
            appState.showError(title: "Cannot Send", message: "You have blocked this user", style: .toast)
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            var isFirstMessage = true
            for attachment in payload.attachments {
                let upload = try await appState.realApi.uploadDMAttachment(
                    guildId: guild.id,
                    threadId: thread.id,
                    fileData: attachment.data,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType
                )
                let content: String
                if isFirstMessage {
                    content = payload.text.isEmpty ? attachment.filename : payload.text
                } else {
                    content = attachment.filename
                }
                let message = try await appState.sendDMMessage(
                    threadId: thread.id,
                    content: content,
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName
                )
                onMessageSent(message)
                isFirstMessage = false
            }
        } catch {
            appState.showError(error, title: "Failed to Send Attachment", style: .toast)
        }
    }
}

// MARK: - Chatroom Message View (Using RLChatMessageBubble)
struct RLChatroomMessageView: View {
    let message: RLChatroomMessageDTO
    let onAvatarTap: () -> Void
    
    @EnvironmentObject var appState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager
    @State private var showEditSheet = false
    @State private var showReportReasonSheet = false
    
    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .guildChatroom,
            onAvatarTap: onAvatarTap,
            onEdit: message.canEdit ? { showEditSheet = true } : nil,
            onDelete: message.canDelete ? { Task { await deleteMessage() } } : nil,
            onReport: !message.isCurrentUserMessage ? { showReportReasonSheet = true } : nil,
            onCopy: { appState.showSuccess("Copied to clipboard") },
            onMarkerShareTap: { payload in
                rlMessagingManager.closeMessage()
                NotificationCenter.default.post(
                    name: .openSharedMarker,
                    object: nil,
                    userInfo: payload.notificationUserInfo
                )
            }
        )
        .sheet(isPresented: $showEditSheet) {
            UnifiedEditMessageSheet(originalContent: message.content) { newContent in
                try await appState.editChatroomMessage(
                    chatroomId: message.chatroomId,
                    messageId: message.id,
                    content: newContent
                )
                appState.showSuccess("Message updated")
            }
        }
        .sheet(isPresented: $showReportReasonSheet) {
            ReportReasonSheet(
                title: "Why are you reporting this message?",
                includeScam: false,
                onReasonSelected: { reason in
                    Task {
                        await reportMessage(reason: reason)
                        await MainActor.run { showReportReasonSheet = false }
                    }
                },
                onCancel: { showReportReasonSheet = false }
            )
        }
    }
    
    private func deleteMessage() async {
        do {
            try await appState.deleteChatroomMessage(
                chatroomId: message.chatroomId,
                messageId: message.id
            )
            appState.showSuccess("Message deleted")
        } catch {
            appState.showError(error, title: "Failed to Delete Message")
        }
    }
    
    private func reportMessage(reason: String) async {
        guard let guildId = appState.currentGuild?.id else { return }
        HapticFeedback.medium.trigger()
        do {
            _ = try await appState.realApi.reportChatroomMessage(
                guildId: guildId,
                chatroomId: message.chatroomId,
                messageId: message.id,
                reason: reason
            )
            appState.showSuccess("Report submitted")
        } catch {
            appState.showError(error, title: "Failed to Report", style: .toast)
        }
    }
}

// MARK: - DM Message View (Using RLChatMessageBubble)
struct RLDMMessageView: View {
    let message: RLDMMessageDTO

    @EnvironmentObject var appState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager
    @State private var showEditSheet = false
    @State private var showReportReasonSheet = false

    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .directMessage,
            isRead: message.isRead,
            onEdit: message.canEdit ? { showEditSheet = true } : nil,
            onDelete: message.canDelete ? { Task { await deleteMessage() } } : nil,
            onReport: !message.isCurrentUserMessage ? { showReportReasonSheet = true } : nil,
            onCopy: { appState.showSuccess("Copied to clipboard") },
            onMarkerShareTap: { payload in
                rlMessagingManager.closeMessage()
                NotificationCenter.default.post(
                    name: .openSharedMarker,
                    object: nil,
                    userInfo: payload.notificationUserInfo
                )
            }
        )
        .sheet(isPresented: $showEditSheet) {
            UnifiedEditMessageSheet(originalContent: message.content) { newContent in
                try await appState.editDMMessage(
                    threadId: message.dmId,
                    messageId: message.id,
                    content: newContent
                )
                appState.showSuccess("Message updated")
            }
        }
        .sheet(isPresented: $showReportReasonSheet) {
            ReportReasonSheet(
                title: "Why are you reporting this message?",
                includeScam: false,
                onReasonSelected: { reason in
                    Task {
                        await reportMessage(reason: reason)
                        await MainActor.run { showReportReasonSheet = false }
                    }
                },
                onCancel: { showReportReasonSheet = false }
            )
        }
    }

    private func deleteMessage() async {
        do {
            try await appState.deleteDMMessage(
                threadId: message.dmId,
                messageId: message.id
            )
            appState.showSuccess("Message deleted")
        } catch {
            appState.showError(error, title: "Failed to Delete Message")
        }
    }

    private func reportMessage(reason: String) async {
        guard let guildId = appState.currentGuild?.id else { return }
        HapticFeedback.medium.trigger()
        do {
            _ = try await appState.realApi.reportDMMessage(
                guildId: guildId,
                threadId: message.dmId,
                messageId: message.id,
                reason: reason
            )
            appState.showSuccess("Report submitted")
        } catch {
            appState.showError(error, title: "Failed to Report", style: .toast)
        }
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
        guard let dict = wsMessage.payload as? [String: Any],
              let idString = dict["message_id"] as? String,
              let uuid = UUID(uuidString: idString) else { return }
        
        self.deletedMessageSubject.send(uuid)
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
