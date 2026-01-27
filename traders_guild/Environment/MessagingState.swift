//
//  MessagingState.swift
//  traders_guild
//
//  Created by Al Hennessey on 17/10/2025.
//
//  REFACTORED: Now uses unified ChatComponents for consistent styling
//  - ChatMessageBubble replaces ChatroomMessageView and UserDMMessageView bodies
//  - ChatInputFooter replaces ChatroomFooterView and UserDMFooterView
//  - ChatEmptyStateView and ChatLoadingView replace custom implementations
//  - UnifiedEditMessageSheet replaces EditChatroomMessageSheet and EditMessageSheet

import SwiftUI

// MARK: - Message Content Types
enum MessageContentType: Equatable {
    case userDM(DMDTO)
    case chatroom(GuildChatroomDTO)
}

// MARK: - Global Messaging Manager
@MainActor
class MessagingManager: ObservableObject {
    @Published var activeMessage: MessageContentType? = nil
    @Published var isLoadingChat: Bool = false
    
    private var dmCache: [UUID: DMDTO] = [:]
    private var chatroomCache: [UUID: GuildChatroomDTO] = [:]
    
    private weak var appState: AppState?
    
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    func openUserDM(_ userDM: DMDTO) {
        activeMessage = .userDM(userDM)
    }
    
    func openUserChat(with membership: GuildMembershipDTO) async {
        guard let appState = appState else {
            print("⚠️ AppState not configured")
            return
        }
        
        // Check cache first
        if let cachedDM = dmCache[membership.id] {
            openUserDM(cachedDM)
            return
        }
        
        isLoadingChat = true
        
        do {
            let userDM = try await appState.fetchOrCreateUserDM(userId: membership.id)
            dmCache[membership.id] = userDM
            openUserDM(userDM)
            
        } catch is CancellationError {
            return
        } catch {
            appState.showError(error, title: "Failed to Open Chat", style: .toast)
        }
        
        isLoadingChat = false
    }
    
    func openChatroom(_ chatroom: GuildChatroomDTO) {
        activeMessage = .chatroom(chatroom)
    }
    
    func closeMessage() {
        activeMessage = nil
    }
    
    func clearCache() {
        dmCache.removeAll()
        chatroomCache.removeAll()
    }
}

// MARK: - Global Messaging Overlay
struct GlobalMessagingOverlay: ViewModifier {
    @EnvironmentObject var messagingManager: MessagingManager
    
    func body(content: Content) -> some View {
        content
            .sheet(item: Binding<MessageContentItem?>(
                get: {
                    if let activeMessage = messagingManager.activeMessage {
                        return MessageContentItem(contentType: activeMessage)
                    }
                    return nil
                },
                set: { _ in
                    messagingManager.closeMessage()
                }
            )) { item in
                MessagingSheet(contentType: item.contentType)
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
struct MessageContentItem: Identifiable {
    let id = UUID()
    let contentType: MessageContentType
}

// MARK: - View Extension for Easy Access
extension View {
    func globalMessaging() -> some View {
        self.modifier(GlobalMessagingOverlay())
    }
}

// MARK: - Unified Messaging Sheet
struct MessagingSheet: View {
    let contentType: MessageContentType
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState
    
    @State private var messageText = ""
    @State private var showUserProfile = false
    @State private var selectedChatroomUser: GuildMembershipDTO? = nil
    @State private var showSettings = false
    @State private var hasMarkedAsRead = false
    
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
            if showUserProfile, case .userDM(let userDM) = contentType {
                userProfileView(for: userDM.participant, backTitle: "Back to Chat")
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
                case .userDM(let userDM):
                    try await appState.markDMAsRead(dmId: userDM.id)
                    
                case .chatroom(let chatroom):
                    try await appState.markChatroomAsRead(chatroomId: chatroom.id)
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
                            ChatroomHeaderView(chatroom: chatroom)
                        case .userDM(let userDM):
                            Button(action: {
                                withAnimation {
                                    showUserProfile = true
                                }
                            }) {
                                UserDMHeaderView(userDM: userDM)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        HapticFeedback.light.trigger()
                                    }
                            )
                    }
                    
                    Spacer()
                    
                    // Dismiss button
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
            
            // Main content area with messages
            MessagingScrollView(
                contentType: contentType,
                onUserAvatarTap: { user in
                    selectedChatroomUser = user
                    withAnimation {
                        showUserProfile = true
                    }
                    HapticFeedback.light.trigger()
                }
            )
            
            Divider()
            
            // Footer - using unified ChatInputFooter
            switch contentType {
                case .chatroom(let chatroom):
                    ChatroomFooterView(chatroom: chatroom, messageText: $messageText)
                case .userDM(let userDM):
                    UserDMFooterView(userDM: userDM, messageText: $messageText)
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
    
    // MARK: - User Profile View
    private func userProfileView(for user: GuildMembershipDTO, backTitle: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                ChatBackButton(title: backTitle) {
                    withAnimation {
                        showUserProfile = false
                        selectedChatroomUser = nil
                    }
                }
                
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
            
            GuildMemberProfileHeaderView(user: user)
            
            // Updated: Using ProfileContentView instead of GuildUserProfileContent
            ProfileContentView(
                extendedProfile: RLUserProfileDTO.fromLegacy(SampleData.memberExtendedProfile),
                markersSummary: RLUserGlobalStatisticsDTO.fromLegacy(
                    SampleData.memberMarkersSummary,
                    userId: user.globalMember.id
                ),
                userMarkers: Array(SampleData.userPlacedMarkers.prefix(5)),
                awards: SampleData.memberAwards.map {
                    RLUserAwardDTO.fromLegacy($0, membershipId: user.id, guildId: user.guild.id)
                },
                awardsSummary: RLAwardsSummaryDTO.fromLegacy(SampleData.awardsSummary),
                stats: SampleData.profileStats,
                isCurrentUser: false,
                username: user.globalMember.username,
                onMarkerTap: { marker in
                    // Close profile and messaging, then navigate to marker
                    messagingManager.closeMessage()
                    dismiss()
                }
            )
            
            Divider()
            
            GuildUserActionButtons(user: user)
                .padding(.horizontal, 25)
                .padding(.top, 20)
                .background(AppColors.sheetBackground)
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
    
    // MARK: - Settings View
    private var settingsView: some View {
        VStack(spacing: 0) {
            // Header
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
            
            // Settings content based on type
            switch contentType {
            case .chatroom(let chatroom):
                ChatroomSettingsView(chatroom: chatroom)
            case .userDM(let userDM):
                DMSettingsView(userDM: userDM)
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


// MARK: - User DM Header Component
struct UserDMHeaderView: View {
    let userDM: DMDTO
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar with online indicator - using unified ChatAvatar
            ChatAvatar(
                initials: String(userDM.participant.globalMember.username.prefix(2)),
                isOnline: userDM.participant.isOnline,
                size: 40
            )
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    if userDM.participant.isBlocked {
                        Image(systemName: "nosign")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.bearCandleRed)
                    }
                    Text(userDM.participant.globalMember.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(userDM.participant.isBlocked ? AppColors.greyText : AppColors.whiteText)
                    
                    if userDM.participant.isFriend {
                        Image(systemName: "person.crop.circle")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(userDM.participant.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                            .padding(.leading, 3)
                    }
                }
                
                HStack(spacing: 2) {
                    Text(userDM.participant.roleInGuild.rawValue)
                        .font(.caption2)
                        .foregroundColor(userDM.participant.roleInGuild.roleForegroundColor)
                        .fontWeight(userDM.participant.roleInGuild.roleFontWeight)
                        .lineLimit(1)
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(userDM.participant.reputation)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
                }
            }
        }
        .opacity(isPressed ? 0.7 : 1.0)
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Chatroom Header Component
struct ChatroomHeaderView: View {
    let chatroom: GuildChatroomDTO
    
    var body: some View {
        HStack(spacing: 8) {
            // Chatroom icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.gradientBackgroundDark.opacity(0.4))
                    .frame(width: 40, height: 40)
                Image(systemName: "number")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText.opacity(0.4))
            }
            
            // Chatroom info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(chatroom.isActive ? AppColors.bullCandleGreen : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                    
                    Text(chatroom.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                }
                
                HStack(spacing: 6) {
                    Text(chatroom.description ?? chatroom.lastActivityFormatted)
                        .font(.caption2)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Scrollable Messages Content
struct MessagingScrollView: View {
    let contentType: MessageContentType
    let onUserAvatarTap: (GuildMembershipDTO) -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var dmMessages: [DMMessageDTO] = []
    @State private var chatroomMessages: [ChatroomMessageDTO] = []
    @State private var isLoadingMessages: Bool = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    switch contentType {
                    case .chatroom(let chatroom):
                        if isLoadingMessages {
                            ChatLoadingView(message: "Loading messages...")
                        } else if chatroomMessages.isEmpty {
                            ChatEmptyStateView(
                                title: "No messages yet",
                                subtitle: "Start a conversation in \(chatroom.name)!"
                            )
                        } else {
                            ForEach(chatroomMessages) { message in
                                ChatroomMessageView(
                                    message: message,
                                    onAvatarTap: {
                                        onUserAvatarTap(message.author)
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        
                    case .userDM(let userDM):
                        if isLoadingMessages {
                            ChatLoadingView(message: "Loading messages...")
                        } else if dmMessages.isEmpty {
                            ChatEmptyStateView(
                                title: "No messages yet",
                                subtitle: "Start the conversation with \(userDM.displayName)!"
                            )
                        } else {
                            ForEach(dmMessages) { message in
                                UserDMMessageView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                }
                .padding()
            }
            .onChange(of: chatroomMessages.count) { _ in
                scrollToBottom(proxy: proxy, messages: chatroomMessages)
            }
            .onChange(of: dmMessages.count) { _ in
                scrollToBottom(proxy: proxy, messages: dmMessages)
            }
        }
        .refreshable {
            switch contentType {
            case .userDM(let userDM):
                await loadDMMessages(for: userDM, isRefresh: true)
            case .chatroom(let chatroom):
                await loadChatroomMessages(for: chatroom, isRefresh: true)
            }
        }
        .task(id: contentType) {
            switch contentType {
            case .userDM(let userDM):
                await loadDMMessages(for: userDM, isRefresh: false)
            case .chatroom(let chatroom):
                await loadChatroomMessages(for: chatroom, isRefresh: false)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
        .background(ChatBackground())
    }
    
    private func scrollToBottom<T: Identifiable>(proxy: ScrollViewProxy, messages: [T]) {
        if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func loadChatroomMessages(for chatroom: GuildChatroomDTO, isRefresh: Bool = false) async {
        if !isRefresh {
            isLoadingMessages = true
        }
        
        do {
            let fetchedMessages = try await appState.fetchChatroomMessages(chatroomId: chatroom.id)
            chatroomMessages = fetchedMessages
            
        } catch is CancellationError {
            return
        } catch {
            appState.showError(error, title: "Failed to Load Messages", style: .toast)
        }
        
        isLoadingMessages = false
    }
    
    private func loadDMMessages(for userDM: DMDTO, isRefresh: Bool = false) async {
        if !isRefresh {
            isLoadingMessages = true
        }
        
        do {
            let fetchedMessages = try await appState.fetchDMMessages(dmId: userDM.id)
            dmMessages = fetchedMessages
            
        } catch is CancellationError {
            return
        } catch {
            appState.showError(error, title: "Failed to Load Messages", style: .toast)
        }
        
        isLoadingMessages = false
    }
}

// MARK: - Chatroom Footer Component (Using Unified ChatInputFooter)
struct ChatroomFooterView: View {
    let chatroom: GuildChatroomDTO
    @Binding var messageText: String
    
    @EnvironmentObject var appState: AppState
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
        
        let textToSend = messageText
        messageText = ""
        isSending = true
        
        do {
            try await appState.sendChatroomMessage(chatroomId: chatroom.id, content: textToSend)
        } catch is CancellationError {
            return
        } catch {
            messageText = textToSend
            appState.showError(error, title: "Failed to Send Message", style: .toast)
        }
        
        isSending = false
    }
}

// MARK: - User DM Footer Component (Using Unified ChatInputFooter)
struct UserDMFooterView: View {
    let userDM: DMDTO
    @Binding var messageText: String
    
    @EnvironmentObject var appState: AppState
    @State private var isSending: Bool = false
    
    var body: some View {
        ChatInputFooter(
            messageText: $messageText,
            placeholder: "Message \(userDM.participant.globalMember.username.lowercased())...",
            isSending: isSending,
            onSend: { Task { await sendMessage() } }
        )
    }
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let textToSend = messageText
        messageText = ""
        isSending = true
        
        do {
            try await appState.sendDMMessage(dmId: userDM.id, content: textToSend)
        } catch is CancellationError {
            return
        } catch {
            messageText = textToSend
            appState.showError(error, title: "Failed to Send Message", style: .toast)
        }
        
        isSending = false
    }
}

// MARK: - Chatroom Message View (Using Unified ChatMessageBubble)
struct ChatroomMessageView: View {
    let message: ChatroomMessageDTO
    let onAvatarTap: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var showEditSheet = false
    
    private var canDeleteMessage: Bool {
        guard let currentUserRole = appState.currentGuild?.roleInGuild else {
            return false
        }
        
        return currentUserRole.canDelete(
            messageFrom: message.author.roleInGuild,
            isOwnMessage: message.isCurrentUserMessage
        )
    }
    
    var body: some View {
        ChatMessageBubble(
            message: message,
            context: .guildChatroom,
            onAvatarTap: onAvatarTap,
            onEdit: message.canEdit ? { showEditSheet = true } : nil,
            onDelete: canDeleteMessage ? { Task { await deleteMessage() } } : nil,
            onReport: !message.isCurrentUserMessage ? { Task { await reportMessage() } } : nil,
            onCopy: { appState.showSuccess("Copied to clipboard") }
        )
        .sheet(isPresented: $showEditSheet) {
            UnifiedEditMessageSheet(originalContent: message.content) { newContent in
                try await appState.editChatroomMessage(
                    messageId: message.id,
                    newContent: newContent,
                    chatroomId: message.chatroom
                )
                appState.showSuccess("Message updated")
            }
        }
    }
    
    private func deleteMessage() async {
        do {
            try await appState.deleteChatroomMessage(messageId: message.id, chatroomId: message.chatroom)
            appState.showSuccess("Message deleted")
        } catch {
            appState.showError(error, title: "Failed to Delete Message")
        }
    }
    
    private func reportMessage() async {
        do {
            try await appState.reportChatroomMessage(messageId: message.id, chatroomId: message.chatroom)
            appState.showInfo("Report submitted for review")
        } catch {
            appState.showError(error, title: "Failed to Report Message")
        }
    }
}

// MARK: - User DM Message View (Using Unified ChatMessageBubble)
struct UserDMMessageView: View {
    let message: DMMessageDTO
    
    @EnvironmentObject var appState: AppState
    @State private var showEditSheet = false
    
    var body: some View {
        ChatMessageBubble(
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
                    messageId: message.id,
                    newContent: newContent,
                    dmId: message.dmId
                )
                appState.showSuccess("Message updated")
            }
        }
    }
    
    private func deleteMessage() async {
        do {
            try await appState.deleteDMMessage(messageId: message.id, dmId: message.dmId)
            appState.showSuccess("Message deleted")
        } catch {
            appState.showError(error, title: "Failed to Delete Message")
        }
    }
}

