//
//  RLMessagingState.swift
//  traders_guild
//
//  UPDATED: Uses RLAppState and new RL messaging DTOs.
//  Replaces old MessagingState that used AppState.
//

import SwiftUI

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
    
    private var dmCache: [UUID: RLDMThreadDTO] = [:]
    private var chatroomCache: [UUID: RLGuildChatroomDTO] = [:]
    
    private weak var appState: RLAppState?
    
    init(appState: RLAppState? = nil) {
        self.appState = appState
    }
    
    func configure(with appState: RLAppState) {
        self.appState = appState
    }
    
    // MARK: - Open DM Thread
    
    func openDMThread(_ thread: RLDMThreadDTO) {
        dmCache[thread.id] = thread
        activeMessage = .dmThread(thread)
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
                        return RLMessageContentItem(contentType: activeMessage)
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
    let id = UUID()
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
    @EnvironmentObject var legacyAppState: AppState
    
    @State private var messageText = ""
    @State private var showUserProfile = false
    @State private var selectedChatroomUser: RLGuildMemberDTO? = nil
    @State private var showSettings = false
    @State private var hasMarkedAsRead = false
    
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
    @State private var profileMarkers: [TopMarkerDTO] = []
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
        HStack(spacing: 8) {
            // Avatar - using unified ChatAvatar
            ChatAvatar(
                initials: thread.participant.initials,
                isOnline: thread.participant.isOnline,
                size: 36
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.participant.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text(thread.participant.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(thread.participant.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
            }
        }
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
                chatroomMessages = response.messages
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
                
            case .dmThread(let thread):
                let response = try await appState.fetchDMMessages(threadId: thread.id)
                dmMessages = response.messages
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
                chatroomMessages.insert(contentsOf: response.messages, at: 0)
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
                
            case .dmThread(let thread):
                let response = try await appState.fetchDMMessages(threadId: thread.id, cursor: cursor)
                dmMessages.insert(contentsOf: response.messages, at: 0)
                hasMoreMessages = response.hasMore
                nextCursor = response.nextCursor
            }
        } catch {
            // Error shown by appState
        }
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
            appState: legacyAppState,
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
        [
            ProfileStatDTO(
                label: "Guild Reputation",
                value: "\(member.reputation)",
                icon: "shield.checkered",
                color: AppColors.accentColor,
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
                color: .green,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Contribution",
                value: "\(member.contributionScore)%",
                icon: "chart.bar.fill",
                color: .orange,
                trend: nil
            )
        ]
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
            onSend: { Task { await sendMessage() } }
        )
    }
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard chatroom.canSendMessages else {
            appState.showError(title: "Cannot Send", message: "You don't have permission to send messages here", style: .toast)
            return
        }
        
        let textToSend = messageText
        messageText = ""
        isSending = true
        defer { isSending = false }
        
        do {
            let message = try await appState.sendChatroomMessage(chatroomId: chatroom.id, content: textToSend)
            onMessageSent(message)
        } catch {
            messageText = textToSend
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
            onSend: { Task { await sendMessage() } }
        )
    }
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if thread.isBlocked {
            appState.showError(title: "Cannot Send", message: "You have blocked this user", style: .toast)
            return
        }
        
        let textToSend = messageText
        messageText = ""
        isSending = true
        defer { isSending = false }
        
        do {
            let message = try await appState.sendDMMessage(threadId: thread.id, content: textToSend)
            onMessageSent(message)
        } catch {
            messageText = textToSend
        }
    }
}

// MARK: - Chatroom Message View (Using RLChatMessageBubble)
struct RLChatroomMessageView: View {
    let message: RLChatroomMessageDTO
    let onAvatarTap: () -> Void
    
    @EnvironmentObject var appState: RLAppState
    @State private var showEditSheet = false
    
    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .guildChatroom,
            onAvatarTap: onAvatarTap,
            onEdit: message.canEdit ? { showEditSheet = true } : nil,
            onDelete: message.canDelete ? { Task { await deleteMessage() } } : nil,
            onReport: !message.isCurrentUserMessage ? { Task { await reportMessage() } } : nil,
            onCopy: { appState.showSuccess("Copied to clipboard") }
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
    
    private func reportMessage() async {
        // TODO: Implement report API call
        appState.showInfo("Report submitted for review")
    }
}

// MARK: - DM Message View (Using RLChatMessageBubble)
struct RLDMMessageView: View {
    let message: RLDMMessageDTO
    
    @EnvironmentObject var appState: RLAppState
    @State private var showEditSheet = false
    
    var body: some View {
        RLChatMessageBubble(
            message: message,
            context: .directMessage,
            isRead: message.isRead,
            onEdit: message.canEdit ? { showEditSheet = true } : nil,
            onDelete: message.canDelete ? { Task { await deleteMessage() } } : nil,
            onCopy: { appState.showSuccess("Copied to clipboard") }
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
}




////
////  RLMessagingState.swift
////  traders_guild
////
////  UPDATED: Uses RLAppState and new RL messaging DTOs.
////  Replaces old MessagingState that used AppState.
////
//
//import SwiftUI
//
//// MARK: - Message Content Types
//enum RLMessageContentType: Equatable {
//    case dmThread(RLDMThreadDTO)
//    case chatroom(RLGuildChatroomDTO)
//    
//    var id: UUID {
//        switch self {
//        case .dmThread(let thread): return thread.id
//        case .chatroom(let chatroom): return chatroom.id
//        }
//    }
//}
//
//// MARK: - Global Messaging Manager
//@MainActor
//class RLMessagingManager: ObservableObject {
//    @Published var activeMessage: RLMessageContentType? = nil
//    @Published var isLoadingChat: Bool = false
//    
//    private var dmCache: [UUID: RLDMThreadDTO] = [:]
//    private var chatroomCache: [UUID: RLGuildChatroomDTO] = [:]
//    
//    private weak var appState: RLAppState?
//    
//    init(appState: RLAppState? = nil) {
//        self.appState = appState
//    }
//    
//    func configure(with appState: RLAppState) {
//        self.appState = appState
//    }
//    
//    // MARK: - Open DM Thread
//    
//    func openDMThread(_ thread: RLDMThreadDTO) {
//        dmCache[thread.id] = thread
//        activeMessage = .dmThread(thread)
//    }
//    
//    /// Open a DM chat with a guild member (creates thread if needed)
//    func openDMChat(with member: RLGuildMemberDTO) async {
//        guard let appState = appState else {
//            print("⚠️ AppState not configured")
//            return
//        }
//        
//        // Check cache first
//        if let cachedThread = dmCache.values.first(where: { $0.participant.membershipId == member.membershipId }) {
//            openDMThread(cachedThread)
//            return
//        }
//        
//        isLoadingChat = true
//        defer { isLoadingChat = false }
//        
//        do {
//            let thread = try await appState.fetchOrCreateDMThread(participantUserId: member.userId)
//            dmCache[thread.id] = thread
//            openDMThread(thread)
//        } catch is CancellationError {
//            return
//        } catch {
//            // Error already shown by appState
//        }
//    }
//    
//    // MARK: - Open Chatroom
//    
//    func openChatroom(_ chatroom: RLGuildChatroomDTO) {
//        chatroomCache[chatroom.id] = chatroom
//        activeMessage = .chatroom(chatroom)
//    }
//    
//    /// Open a chatroom by ID (fetches if not cached)
//    func openChatroom(id: UUID) async {
//        guard let appState = appState else {
//            print("⚠️ AppState not configured")
//            return
//        }
//        
//        // Check cache first
//        if let cached = chatroomCache[id] {
//            openChatroom(cached)
//            return
//        }
//        
//        isLoadingChat = true
//        defer { isLoadingChat = false }
//        
//        do {
//            let chatroom = try await appState.fetchChatroom(chatroomId: id)
//            chatroomCache[chatroom.id] = chatroom
//            openChatroom(chatroom)
//        } catch is CancellationError {
//            return
//        } catch {
//            // Error already shown by appState
//        }
//    }
//    
//    // MARK: - Close & Clear
//    
//    func closeMessage() {
//        activeMessage = nil
//    }
//    
//    func clearCache() {
//        dmCache.removeAll()
//        chatroomCache.removeAll()
//    }
//}
//
//// MARK: - Global Messaging Overlay
//struct RLGlobalMessagingOverlay: ViewModifier {
//    @EnvironmentObject var messagingManager: RLMessagingManager
//    
//    func body(content: Content) -> some View {
//        content
//            .sheet(item: Binding<RLMessageContentItem?>(
//                get: {
//                    if let activeMessage = messagingManager.activeMessage {
//                        return RLMessageContentItem(contentType: activeMessage)
//                    }
//                    return nil
//                },
//                set: { _ in
//                    messagingManager.closeMessage()
//                }
//            )) { item in
//                RLMessagingSheet(contentType: item.contentType)
//                    .environmentObject(messagingManager)
//                    .presentationDetents([.fraction(0.9)])
//                    .presentationBackground {
//                        ZStack {
//                            Color.clear
//                                .background(.ultraThinMaterial)
//                            AppColors.sheetBackground
//                        }
//                    }
//                    .presentationCornerRadius(33)
//                    .interactiveDismissDisabled(true)
//            }
//    }
//}
//
//// MARK: - Helper for Sheet Presentation
//struct RLMessageContentItem: Identifiable {
//    let id = UUID()
//    let contentType: RLMessageContentType
//}
//
//// MARK: - View Extension for Easy Access
//extension View {
//    func rlGlobalMessaging() -> some View {
//        self.modifier(RLGlobalMessagingOverlay())
//    }
//}
//
//// MARK: - Unified Messaging Sheet
//struct RLMessagingSheet: View {
//    let contentType: RLMessageContentType
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var messagingManager: RLMessagingManager
//    @EnvironmentObject var appState: RLAppState
//    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    @EnvironmentObject var legacyAppState: AppState
//    
//    @State private var messageText = ""
//    @State private var showUserProfile = false
//    @State private var selectedChatroomUser: RLGuildMemberDTO? = nil
//    @State private var showSettings = false
//    @State private var hasMarkedAsRead = false
//    
//    // Message state
//    @State private var chatroomMessages: [RLChatroomMessageDTO] = []
//    @State private var dmMessages: [RLDMMessageDTO] = []
//    @State private var isLoadingMessages = false
//    @State private var hasMoreMessages = false
//    @State private var nextCursor: String? = nil
//    @State private var isLoadingMore = false
//
//    // Profile state
//    @State private var profileExtendedProfile: RLUserProfileDTO? = nil
//    @State private var profileStatistics: RLUserGlobalStatisticsDTO? = nil
//    @State private var profileMarkers: [TopMarkerDTO] = []
//    @State private var profileAwards: [RLUserAwardDTO] = []
//    @State private var profileAwardsSummary: RLAwardsSummaryDTO? = nil
//    @State private var isProfileLoading: Bool = false
//    
//    var body: some View {
//        ZStack {
//            // Main messaging view
//            if !showUserProfile && !showSettings {
//                messagingView
//                    .transition(.move(edge: .leading))
//                    .onAppear {
//                        markAsRead()
//                    }
//            }
//            
//            // User profile view for DMs
//            if showUserProfile, case .dmThread(let thread) = contentType {
//                userProfileView(for: thread.participant, backTitle: "Back to Chat")
//                    .transition(.move(edge: .trailing))
//            }
//            
//            // User profile view for chatroom users
//            if showUserProfile, case .chatroom = contentType, let selectedUser = selectedChatroomUser {
//                userProfileView(for: selectedUser, backTitle: "Back to Chatroom")
//                    .transition(.move(edge: .trailing))
//            }
//            
//            // Settings view
//            if showSettings {
//                settingsView
//                    .transition(.move(edge: .trailing))
//            }
//        }
//        .animation(.easeInOut(duration: 0.3), value: showUserProfile)
//        .animation(.easeInOut(duration: 0.3), value: showSettings)
//    }
//    
//    // MARK: - Mark as Read Function
//    private func markAsRead() {
//        guard !hasMarkedAsRead else { return }
//        hasMarkedAsRead = true
//        
//        Task {
//            do {
//                switch contentType {
//                case .dmThread(let thread):
//                    try await appState.markDMAsRead(threadId: thread.id)
//                    rightDrawerViewModel.markDMAsRead(threadId: thread.id)
//                    
//                case .chatroom(let chatroom):
//                    try await appState.markChatroomAsRead(chatroomId: chatroom.id)
//                    rightDrawerViewModel.markChatroomAsRead(chatroomId: chatroom.id)
//                }
//            } catch {
//                print("Failed to mark as read: \(error)")
//            }
//        }
//    }
//    
//    // MARK: - Messaging View
//    private var messagingView: some View {
//        VStack(spacing: 0) {
//            // Header section
//            VStack(spacing: 0) {
//                HStack {
//                    // Settings button
//                    Button(action: {
//                        withAnimation {
//                            showSettings = true
//                        }
//                        HapticFeedback.light.trigger()
//                    }) {
//                        Image(systemName: "gearshape.fill")
//                            .font(.title3)
//                            .foregroundColor(AppColors.whiteText.opacity(0.6))
//                    }
//                    
//                    Spacer()
//                    
//                    // Header content
//                    switch contentType {
//                    case .chatroom(let chatroom):
//                        chatroomHeader(chatroom)
//                    case .dmThread(let thread):
//                        Button(action: {
//                            withAnimation {
//                                showUserProfile = true
//                            }
//                        }) {
//                            dmHeader(thread)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                    }
//                    
//                    Spacer()
//                    
//                    // Close button
//                    Button(action: {
//                        dismiss()
//                    }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(AppColors.whiteText.opacity(0.6))
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 12)
//                
//                Divider()
//                    .background(Color.white.opacity(0.1))
//            }
//            
//            // Messages list
//            messagesListView
//            
//            // Input footer
//            switch contentType {
//            case .chatroom(let chatroom):
//                RLChatroomFooterView(
//                    chatroom: chatroom,
//                    messageText: $messageText,
//                    onMessageSent: { message in
//                        chatroomMessages.append(message)
//                    }
//                )
//            case .dmThread(let thread):
//                RLDMFooterView(
//                    thread: thread,
//                    messageText: $messageText,
//                    onMessageSent: { message in
//                        dmMessages.append(message)
//                    }
//                )
//            }
//        }
//        .task(id: contentType.id) {
//            resetMessageState()
//            await loadMessages()
//        }
//    }
//    
//    // MARK: - Headers
//    
//    private func chatroomHeader(_ chatroom: RLGuildChatroomDTO) -> some View {
//        VStack(spacing: 2) {
//            HStack(spacing: 4) {
//                Image(systemName: "number")
//                    .font(.headline)
//                Text(chatroom.name)
//                    .font(.headline)
//                    .fontWeight(.semibold)
//            }
//            .foregroundColor(AppColors.whiteText)
//            
//            Text("\(chatroom.memberCount) members")
//                .font(.caption)
//                .foregroundColor(AppColors.whiteText.opacity(0.6))
//        }
//    }
//    
//    private func dmHeader(_ thread: RLDMThreadDTO) -> some View {
//        HStack(spacing: 8) {
//            // Avatar
//            Circle()
//                .fill(AppColors.accentColor.opacity(0.3))
//                .frame(width: 36, height: 36)
//                .overlay(
//                    Text(thread.participant.displayName.prefix(2))
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                )
//                .overlay(alignment: .bottomTrailing) {
//                    Circle()
//                        .fill(thread.participant.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
//                        .frame(width: 10, height: 10)
//                        .overlay(Circle().stroke(AppColors.sheetBackground, lineWidth: 2))
//                }
//            
//            VStack(alignment: .leading, spacing: 2) {
//                Text(thread.participant.displayName)
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(AppColors.whiteText)
//                
//                Text(thread.participant.isOnline ? "Online" : "Offline")
//                    .font(.caption)
//                    .foregroundColor(thread.participant.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
//            }
//        }
//    }
//    
//    // MARK: - Messages List
//    
//    private var messagesListView: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(spacing: 8) {
//                    // Load more button
//                    if hasMoreMessages {
//                        Button("Load earlier messages") {
//                            Task { await loadMoreMessages() }
//                        }
//                        .font(.caption)
//                        .foregroundColor(AppColors.accentColor)
//                        .padding(.vertical, 8)
//                    }
//                    
//                    switch contentType {
//                    case .chatroom:
//                        ForEach(chatroomMessages) { message in
//                            RLChatroomMessageView(
//                                message: message,
//                                onAvatarTap: {
//                                    selectedChatroomUser = message.author
//                                    showUserProfile = true
//                                }
//                            )
//                            .id(message.id)
//                        }
//                    case .dmThread:
//                        ForEach(dmMessages) { message in
//                            RLDMMessageView(message: message)
//                                .id(message.id)
//                        }
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 8)
//            }
//            .onChange(of: chatroomMessages.count) { _, _ in
//                guard !isLoadingMore else { return }
//                scrollToBottom(proxy: proxy)
//            }
//            .onChange(of: dmMessages.count) { _, _ in
//                guard !isLoadingMore else { return }
//                scrollToBottom(proxy: proxy)
//            }
//        }
//        .overlay {
//            if isLoadingMessages {
//                ProgressView()
//            }
//        }
//    }
//    
//    private func scrollToBottom(proxy: ScrollViewProxy) {
//        switch contentType {
//        case .chatroom:
//            if let lastMessage = chatroomMessages.last {
//                withAnimation(.easeOut(duration: 0.2)) {
//                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                }
//            }
//        case .dmThread:
//            if let lastMessage = dmMessages.last {
//                withAnimation(.easeOut(duration: 0.2)) {
//                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
//                }
//            }
//        }
//    }
//    
//    // MARK: - Load Messages
//    
//    private func loadMessages() async {
//        await MainActor.run {
//            isLoadingMessages = true
//            hasMoreMessages = false
//            nextCursor = nil
//        }
//        defer { isLoadingMessages = false }
//        
//        do {
//            switch contentType {
//            case .chatroom(let chatroom):
//                let response = try await appState.fetchChatroomMessages(chatroomId: chatroom.id)
//                chatroomMessages = response.messages
//                hasMoreMessages = response.hasMore
//                nextCursor = response.nextCursor
//                
//            case .dmThread(let thread):
//                let response = try await appState.fetchDMMessages(threadId: thread.id)
//                dmMessages = response.messages
//                hasMoreMessages = response.hasMore
//                nextCursor = response.nextCursor
//            }
//        } catch {
//            // Error shown by appState
//        }
//    }
//    
//    private func loadMoreMessages() async {
//        guard let cursor = nextCursor else { return }
//        isLoadingMore = true
//        defer { isLoadingMore = false }
//        
//        do {
//            switch contentType {
//            case .chatroom(let chatroom):
//                let response = try await appState.fetchChatroomMessages(chatroomId: chatroom.id, cursor: cursor)
//                chatroomMessages.insert(contentsOf: response.messages, at: 0)
//                hasMoreMessages = response.hasMore
//                nextCursor = response.nextCursor
//                
//            case .dmThread(let thread):
//                let response = try await appState.fetchDMMessages(threadId: thread.id, cursor: cursor)
//                dmMessages.insert(contentsOf: response.messages, at: 0)
//                hasMoreMessages = response.hasMore
//                nextCursor = response.nextCursor
//            }
//        } catch {
//            // Error shown by appState
//        }
//    }
//
//    private func resetMessageState() {
//        chatroomMessages = []
//        dmMessages = []
//        hasMoreMessages = false
//        nextCursor = nil
//        hasMarkedAsRead = false
//    }
//
//    // MARK: - User Profile View
//    private func userProfileView(for member: RLGuildMemberDTO, backTitle: String) -> some View {
//        VStack(spacing: 0) {
//            HStack {
//                Button(action: {
//                    withAnimation {
//                        showUserProfile = false
//                        selectedChatroomUser = nil
//                    }
//                }) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                            .font(.title3)
//                            .fontWeight(.semibold)
//                        Text(backTitle)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                    }
//                    .foregroundColor(AppColors.accentColor)
//                }
//                
//                Spacer()
//                
//                Text("Profile")
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(AppColors.whiteText)
//                
//                Spacer()
//                
//                Button(action: { dismiss() }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title2)
//                        .foregroundColor(AppColors.whiteText.opacity(0.6))
//                }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            
//            Divider()
//                .background(Color.white.opacity(0.1))
//            
//            ScrollView {
//                VStack(spacing: 16) {
//                    GuildMemberProfileHeaderViewRL(member: member)
//
//                    if isProfileLoading {
//                        ProgressView()
//                            .scaleEffect(1.1)
//                            .padding(.top, 12)
//                    } else {
//                        ProfileContentView(
//                            extendedProfile: profileExtendedProfile,
//                            markersSummary: profileStatistics,
//                            userMarkers: profileMarkers,
//                            awards: profileAwards,
//                            awardsSummary: profileAwardsSummary,
//                            stats: buildProfileStats(for: member),
//                            isCurrentUser: false,
//                            username: member.username,
//                            onMarkerTap: { marker in
//                                leftDrawerViewModel.requestNavigationToMarker(marker)
//                                dismiss()
//                            }
//                        )
//                    }
//                }
//                .padding(.top, 12)
//            }
//        }
//        .background(
//            ZStack {
//                Color.clear
//                    .background(.ultraThinMaterial)
//                AppColors.sheetBackground
//            }
//        )
//        .task(id: member.userId) {
//            await loadProfileData(for: member)
//        }
//    }
//
//    private func loadProfileData(for member: RLGuildMemberDTO) async {
//        guard let guildId = appState.currentGuild?.id else { return }
//        isProfileLoading = true
//        let data = await leftDrawerViewModel.loadMemberProfile(
//            member: member,
//            appState: legacyAppState,
//            rlAppState: appState,
//            guildId: guildId
//        )
//        await MainActor.run {
//            profileExtendedProfile = data.profile
//            profileStatistics = data.statistics
//            profileMarkers = data.userMarkers
//            profileAwards = data.awards
//            profileAwardsSummary = data.awardsSummary
//            isProfileLoading = false
//        }
//    }
//
//    private func buildProfileStats(for member: RLGuildMemberDTO) -> [ProfileStatDTO] {
//        [
//            ProfileStatDTO(
//                label: "Guild Reputation",
//                value: "\(member.reputation)",
//                icon: "shield.checkered",
//                color: AppColors.accentColor,
//                trend: nil
//            ),
//            ProfileStatDTO(
//                label: "Global Reputation",
//                value: "\(member.globalReputation)",
//                icon: "globe",
//                color: .blue,
//                trend: nil
//            ),
//            ProfileStatDTO(
//                label: "Days in Guild",
//                value: "\(member.daysInGuild)",
//                icon: "calendar",
//                color: .green,
//                trend: nil
//            ),
//            ProfileStatDTO(
//                label: "Contribution",
//                value: "\(member.contributionScore)%",
//                icon: "chart.bar.fill",
//                color: .orange,
//                trend: nil
//            )
//        ]
//    }
//    
//    // MARK: - Settings View
//    
//    @ViewBuilder
//    private var settingsView: some View {
//        VStack(spacing: 0) {
//            // Header with back button
//            HStack {
//                Button(action: {
//                    withAnimation {
//                        showSettings = false
//                    }
//                }) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "chevron.left")
//                            .font(.title3)
//                            .fontWeight(.semibold)
//                        Text("Back")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                    }
//                    .foregroundColor(AppColors.accentColor)
//                }
//                Spacer()
//                
//                Text("Settings")
//                    .font(.headline)
//                    .fontWeight(.semibold)
//                    .foregroundColor(AppColors.whiteText)
//                
//                Spacer()
//                
//                // Spacer for balance
//                Color.clear.frame(width: 60)
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            
//            Divider()
//                .background(Color.white.opacity(0.1))
//            
//            // Settings content based on content type
//            switch contentType {
//            case .chatroom(let chatroom):
//                RLChatroomSettingsView(chatroom: chatroom)
//                
//            case .dmThread(let thread):
//                RLDMSettingsView(thread: thread)
//            }
//        }
//    }
//}
//
//// MARK: - Chatroom Footer View
//struct RLChatroomFooterView: View {
//    let chatroom: RLGuildChatroomDTO
//    @Binding var messageText: String
//    let onMessageSent: (RLChatroomMessageDTO) -> Void
//    
//    @EnvironmentObject var appState: RLAppState
//    @State private var isSending: Bool = false
//    
//    var body: some View {
//        ChatInputFooter(
//            messageText: $messageText,
//            placeholder: "Message #\(chatroom.name.lowercased().replacingOccurrences(of: " ", with: "-"))...",
//            isSending: isSending,
//            onSend: { Task { await sendMessage() } }
//        )
//    }
//    
//    private func sendMessage() async {
//        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
//        guard chatroom.canSendMessages else {
//            appState.showError(title: "Cannot Send", message: "You don't have permission to send messages here", style: .toast)
//            return
//        }
//        
//        let textToSend = messageText
//        messageText = ""
//        isSending = true
//        defer { isSending = false }
//        
//        do {
//            let message = try await appState.sendChatroomMessage(chatroomId: chatroom.id, content: textToSend)
//            onMessageSent(message)
//        } catch {
//            messageText = textToSend
//        }
//    }
//}
//
//// MARK: - DM Footer View
//struct RLDMFooterView: View {
//    let thread: RLDMThreadDTO
//    @Binding var messageText: String
//    let onMessageSent: (RLDMMessageDTO) -> Void
//    
//    @EnvironmentObject var appState: RLAppState
//    @State private var isSending: Bool = false
//    
//    var body: some View {
//        ChatInputFooter(
//            messageText: $messageText,
//            placeholder: "Message \(thread.participant.username.lowercased())...",
//            isSending: isSending,
//            onSend: { Task { await sendMessage() } }
//        )
//    }
//    
//    private func sendMessage() async {
//        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
//        
//        if thread.isBlocked {
//            appState.showError(title: "Cannot Send", message: "You have blocked this user", style: .toast)
//            return
//        }
//        
//        let textToSend = messageText
//        messageText = ""
//        isSending = true
//        defer { isSending = false }
//        
//        do {
//            let message = try await appState.sendDMMessage(threadId: thread.id, content: textToSend)
//            onMessageSent(message)
//        } catch {
//            messageText = textToSend
//        }
//    }
//}
//
//// MARK: - Chatroom Message View
//struct RLChatroomMessageView: View {
//    let message: RLChatroomMessageDTO
//    let onAvatarTap: () -> Void
//    
//    @EnvironmentObject var appState: RLAppState
//    @State private var showEditSheet = false
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 8) {
//            if message.isCurrentUserMessage {
//                Spacer(minLength: 60)
//            } else {
//                // Avatar
//                Button(action: onAvatarTap) {
//                    Circle()
//                        .fill(AppColors.accentColor.opacity(0.3))
//                        .frame(width: 32, height: 32)
//                        .overlay(
//                            Text(message.author.username.prefix(2))
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.accentColor)
//                        )
//                }
//            }
//            
//            VStack(alignment: message.isCurrentUserMessage ? .trailing : .leading, spacing: 4) {
//                if !message.isCurrentUserMessage {
//                    HStack(spacing: 4) {
//                        Text(message.author.username)
//                            .font(.caption)
//                            .fontWeight(.semibold)
//                            .foregroundColor(message.author.memberRole.color)
//                        
//                        Text("·")
//                            .foregroundColor(AppColors.greyText)
//                        
//                        Text(message.timestampFormatted)
//                            .font(.caption2)
//                            .foregroundColor(AppColors.greyText)
//                    }
//                }
//                
//                Text(message.content)
//                    .font(.subheadline)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(
//                        message.isCurrentUserMessage
//                            ? AppColors.accentColor.opacity(0.2)
//                            : Color.white.opacity(0.1)
//                    )
//                    .cornerRadius(16)
//                
//                if message.isEdited {
//                    Text("edited")
//                        .font(.caption2)
//                        .foregroundColor(AppColors.greyText)
//                }
//            }
//            
//            if !message.isCurrentUserMessage {
//                Spacer(minLength: 60)
//            }
//        }
//        .contextMenu {
//            if message.canEdit {
//                Button {
//                    showEditSheet = true
//                } label: {
//                    Label("Edit", systemImage: "pencil")
//                }
//            }
//            
//            if message.canDelete {
//                Button(role: .destructive) {
//                    Task {
//                        try? await appState.deleteChatroomMessage(
//                            chatroomId: message.chatroomId,
//                            messageId: message.id
//                        )
//                    }
//                } label: {
//                    Label("Delete", systemImage: "trash")
//                }
//            }
//            
//            Button {
//                UIPasteboard.general.string = message.content
//                appState.showSuccess("Copied to clipboard")
//            } label: {
//                Label("Copy", systemImage: "doc.on.doc")
//            }
//        }
//        .sheet(isPresented: $showEditSheet) {
//            // Edit sheet - using UnifiedEditMessageSheet if available
//            NavigationStack {
//                VStack {
//                    TextEditor(text: .constant(message.content))
//                        .padding()
//                }
//                .navigationTitle("Edit Message")
//                .navigationBarTitleDisplayMode(.inline)
//            }
//        }
//    }
//}
//
//// MARK: - DM Message View
//struct RLDMMessageView: View {
//    let message: RLDMMessageDTO
//    
//    @EnvironmentObject var appState: RLAppState
//    @State private var showEditSheet = false
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 8) {
//            if message.isCurrentUserMessage {
//                Spacer(minLength: 60)
//            }
//            
//            VStack(alignment: message.isCurrentUserMessage ? .trailing : .leading, spacing: 4) {
//                Text(message.content)
//                    .font(.subheadline)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(
//                        message.isCurrentUserMessage
//                            ? AppColors.accentColor.opacity(0.2)
//                            : Color.white.opacity(0.1)
//                    )
//                    .cornerRadius(16)
//                
//                HStack(spacing: 4) {
//                    Text(message.timestampFormatted)
//                        .font(.caption2)
//                        .foregroundColor(AppColors.greyText)
//                    
//                    if message.isEdited {
//                        Text("· edited")
//                            .font(.caption2)
//                            .foregroundColor(AppColors.greyText)
//                    }
//                    
//                    if message.isCurrentUserMessage && message.isRead {
//                        Image(systemName: "checkmark.circle.fill")
//                            .font(.caption2)
//                            .foregroundColor(AppColors.bullCandleGreen)
//                    }
//                }
//            }
//            
//            if !message.isCurrentUserMessage {
//                Spacer(minLength: 60)
//            }
//        }
//        .contextMenu {
//            if message.canEdit {
//                Button {
//                    showEditSheet = true
//                } label: {
//                    Label("Edit", systemImage: "pencil")
//                }
//            }
//            
//            if message.canDelete {
//                Button(role: .destructive) {
//                    Task {
//                        try? await appState.deleteDMMessage(
//                            threadId: message.dmId,
//                            messageId: message.id
//                        )
//                    }
//                } label: {
//                    Label("Delete", systemImage: "trash")
//                }
//            }
//            
//            Button {
//                UIPasteboard.general.string = message.content
//                appState.showSuccess("Copied to clipboard")
//            } label: {
//                Label("Copy", systemImage: "doc.on.doc")
//            }
//        }
//    }
//}
