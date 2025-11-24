//
//  MessagingView.swift
//  traders_guild
//
//  Created by Al Hennessey on 17/10/2025.
//
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
    @EnvironmentObject var appState: AppState  // ✅ Add if not already present
    @EnvironmentObject var rightDrawerViewModel: RightDrawerViewModel
    
    @State private var messageText = ""
    @State private var showUserProfile = false
    @State private var selectedChatroomUser: GuildMembershipDTO? = nil
    @State private var showSettings = false
    @State private var hasMarkedAsRead = false  // ✅ Prevent duplicate API calls
    
    var body: some View {
        ZStack {
            // ✅ Main messaging view
            if !showUserProfile && !showSettings {
                messagingView
                    .transition(.move(edge: .leading))
                    .onAppear {  // ✅ Mark as read when messaging view appears
                        markAsRead()
                    }
            }
            
            // ✅ User profile view for DMs
            if showUserProfile, case .userDM(let userDM) = contentType {
                userProfileView(for: userDM.participant, backTitle: "Back to Chat")
                    .transition(.move(edge: .trailing))
            }
            
            // ✅ User profile view for chatroom users
            if showUserProfile, case .chatroom = contentType, let selectedUser = selectedChatroomUser {
                userProfileView(for: selectedUser, backTitle: "Back to Chatroom")
                    .transition(.move(edge: .trailing))
            }
            
            // ✅ Settings view
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
        // Prevent duplicate calls
        guard !hasMarkedAsRead else { return }
        hasMarkedAsRead = true
        
        Task {
            do {
                switch contentType {
                case .userDM(let userDM):
                    // ✅ Mark DM as read
                    try await appState.markDMAsRead(dmId: userDM.id)
                    // Silently succeed - no need for success message
                    // 2. Update cache directly
                    rightDrawerViewModel.markDMAsRead(dmId: userDM.id)
                    
                case .chatroom(let chatroom):
                    // ✅ Mark chatroom as read
                    try await appState.markChatroomAsRead(chatroomId: chatroom.id)
                    // Silently succeed - no need for success message
                    // 2. Update cache directly
                    rightDrawerViewModel.markChatroomAsRead(chatroomId: chatroom.id)
                }
            } catch {
                // Silently fail - marking as read is not critical
                // Optionally log for debugging
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
                    // ✅ Settings button
                    Button(action: {
                        withAnimation {
                            showSettings = true
                        }
                        HapticFeedback.light.trigger()
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.secondary)
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
                    Button(action: {
                        messagingManager.closeMessage()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
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
                Button(action: {
                    withAnimation {
                        showUserProfile = false
                        selectedChatroomUser = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(backTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.accentColor)
                }
                
                Spacer()
                
                Button(action: {
                    messagingManager.closeMessage()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppColors.sheetBackground)
            
            Divider()
            
            GuildMemberProfileHeaderView(user: user)
            GuildUserProfileContent(user: user)
            
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
                Button(action: {
                    withAnimation {
                        showSettings = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.accentColor)
                }
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(AppColors.whiteText)
                
                Spacer()
                
                Button(action: {
                    messagingManager.closeMessage()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
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
            // Avatar with online indicator
            Circle()
                .fill(AppColors.accentColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(userDM.participant.globalMember.username.prefix(2)))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                )
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(userDM.participant.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(AppColors.drawerBackground, lineWidth: 1)
                        )
                        .padding(.trailing, 2)
                        .padding(.bottom, 2)
                }
            
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
    let onUserAvatarTap: (GuildMembershipDTO) -> Void  // ✅ Add callback
    
    @EnvironmentObject var appState: AppState
    @State private var dmMessages: [DMMessageDTO] = []
    @State private var chatroomMessages: [ChatroomMessageDTO] = []
    @State private var isLoadingMessages: Bool = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch contentType {
                case .chatroom(let chatroom):
                    if isLoadingMessages {
                        LoadingView(message: "Loading messages...")
                    } else if chatroomMessages.isEmpty {
                        EmptyMessagesView(
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
                        }
                    }
                    
                case .userDM(let userDM):
                    if isLoadingMessages {
                        LoadingView(message: "Loading messages...")
                    } else if dmMessages.isEmpty {
                        EmptyMessagesView(
                            title: "No messages yet",
                            subtitle: "Start the conversation with \(userDM.displayName)!"
                        )
                    } else {
                        ForEach(dmMessages) { message in
                            UserDMMessageView(message: message)
                        }
                    }
                }
            }
            .padding()
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// ✅ Reusable loading view
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// ✅ Reusable empty state view
struct EmptyMessagesView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Chatroom Footer Component
struct ChatroomFooterView: View {
    let chatroom: GuildChatroomDTO
    @Binding var messageText: String
    
    @EnvironmentObject var appState: AppState
    @State private var isSending: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    // Handle attachment/plus action
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                
                TextField("Message #\(chatroom.name.lowercased().replacingOccurrences(of: " ", with: "-"))...", text: $messageText)
                    .font(.subheadline)
                    .submitLabel(.send)
                    .disabled(isSending)
                    .onSubmit {
                        Task { await sendMessage() }
                    }
                
                HStack(spacing: 8) {
                    Button(action: {
                        // Handle voice message
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 40, height: 40)
                    } else {
                        Button(action: {
                            Task { await sendMessage() }
                        }) {
                            Image(systemName: "chevron.forward.2")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(messageText.isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .padding(.leading, 2)
                                .background(messageText.isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                                .clipShape(Capsule())
                        }
                        .disabled(messageText.isEmpty)
                    }
                }
            }
            .padding(.leading, 10)
            .frame(height: 44)
            .background(AppColors.whiteText.opacity(0.08))
            .cornerRadius(25)
        }
        .padding()
        .background(AppColors.sheetBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 0)
        }
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

// MARK: - User DM Footer Component
struct UserDMFooterView: View {
    let userDM: DMDTO
    @Binding var messageText: String
    
    @EnvironmentObject var appState: AppState
    @State private var isSending: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    // Handle emoji picker
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                
                TextField("Message \(userDM.participant.globalMember.username.lowercased().replacingOccurrences(of: " ", with: "-"))...", text: $messageText)
                    .font(.subheadline)
                    .submitLabel(.send)
                    .disabled(isSending)
                    .onSubmit {
                        Task { await sendMessage() }
                    }
                
                HStack(spacing: 8) {
                    Button(action: {
                        // Handle voice message
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 40, height: 40)
                    } else {
                        Button(action: {
                            Task { await sendMessage() }
                        }) {
                            Image(systemName: "chevron.forward.2")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(messageText.isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                                .frame(width: 40, height: 40)
                                .padding(.leading, 2)
                                .background(messageText.isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                                .clipShape(Capsule())
                        }
                        .disabled(messageText.isEmpty)
                    }
                }
            }
            .padding(.leading, 10)
            .frame(height: 44)
            .background(AppColors.whiteText.opacity(0.08))
            .cornerRadius(25)
        }
        .padding()
        .background(AppColors.sheetBackground)
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

// MARK: - Chatroom Message View
struct ChatroomMessageView: View {
    let message: ChatroomMessageDTO
    let onAvatarTap: () -> Void  // ✅ Add callback
    
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
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
    
    private var canEditMessage: Bool {
        return message.isCurrentUserMessage
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isCurrentUserMessage {
                Spacer()
            } else {
                // ✅ Make avatar tappable
                Button(action: {
                    onAvatarTap()
                }) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(message.author.globalMember.username.prefix(2)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(message.author.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.drawerBackground, lineWidth: 1)
                                )
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: message.alignment, spacing: 4) {
                if !message.isCurrentUserMessage {
                    HStack(spacing: 2) {
                        if message.author.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(message.author.globalMember.username)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(message.author.isBlocked ? AppColors.greyText : AppColors.whiteText.opacity(0.9))
                        
                        if message.author.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(message.author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                .padding(.leading, 3)
                        }
                        
                        let role = message.author.roleInGuild
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.horizontal, 3)
                        
                        Text(role.rawValue)
                            .font(.caption)
                            .foregroundColor(role.roleForegroundColor)
                            .fontWeight(role.roleFontWeight)
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.horizontal, 3)
                        
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        
                        Text("\(message.author.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }
                }
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isCurrentUserMessage ?
                        AppColors.accentDarkColor :
                        Color.gray.opacity(0.2)
                    )
                    .clipShape(chatRoomMessageBubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
                    .contextMenu {
                        if canEditMessage {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        
                        if canDeleteMessage {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        Button {
                            UIPasteboard.general.string = message.content
                            appState.showSuccess("Copied to clipboard")
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        if !message.isCurrentUserMessage {
                            Divider()
                            Button(role: .destructive) {
                                Task { await reportMessage() }
                            } label: {
                                Label("Report", systemImage: "exclamationmark.triangle")
                            }
                        }
                    }
                
                HStack(spacing: 4) {
                    Text(message.timestampFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !message.isCurrentUserMessage {
                Spacer()
            }
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteMessage() }
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditChatroomMessageSheet(message: message)
                .environmentObject(appState)
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
    
    private func chatRoomMessageBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
        if isFromCurrentUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        }
    }
}

// MARK: - Edit Chatroom Message Sheet
struct EditChatroomMessageSheet: View {
    let message: ChatroomMessageDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var editedText: String
    @State private var isSaving: Bool = false

    init(message: ChatroomMessageDTO) {
        self.message = message
        _editedText = State(initialValue: message.content)
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Message", text: $editedText, axis: .vertical)
                    .lineLimit(5...10)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()

                Spacer()
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await saveEdit() }
                        }
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func saveEdit() async {
        isSaving = true

        do {
            try await appState.editChatroomMessage(messageId: message.id, newContent: editedText, chatroomId: message.chatroom)
            appState.showSuccess("Message updated")
            dismiss()
        } catch {
            appState.showError(error, title: "Failed to Update Message")
        }

        isSaving = false
    }
}

// MARK: - User DM Message View
struct UserDMMessageView: View {
    let message: DMMessageDTO
    
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    
    var body: some View {
        HStack {
            if message.isCurrentUserMessage {
                Spacer()
            } else {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.author.globalMember.username.prefix(2)))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            VStack(alignment: message.alignment, spacing: 4) {
                HStack(spacing: 8) {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    
                    if message.isEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(message.isCurrentUserMessage ? .white.opacity(0.7) : .secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.isCurrentUserMessage ?
                    AppColors.accentDarkColor :
                    Color.gray.opacity(0.2)
                )
                .clipShape(userChatMessageBubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
                .contextMenu {
                    if message.canEdit {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    if message.canDelete {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    Button {
                        UIPasteboard.general.string = message.content
                        appState.showSuccess("Copied to clipboard")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                
                HStack(spacing: 4) {
                    Text(message.timestampFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if message.isCurrentUserMessage {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(message.isRead ? AppColors.accentColor : .secondary)
                    }
                }
            }
            
            if !message.isCurrentUserMessage {
                Spacer()
            }
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteMessage() }
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditMessageSheet(message: message)
                .environmentObject(appState)
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
    
    private func userChatMessageBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
        if isFromCurrentUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        }
    }
}

// MARK: - Edit DM Message Sheet
struct EditMessageSheet: View {
    let message: DMMessageDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var editedText: String
    @State private var isSaving: Bool = false
    
    init(message: DMMessageDTO) {
        self.message = message
        _editedText = State(initialValue: message.content)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Message", text: $editedText, axis: .vertical)
                    .lineLimit(5...10)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await saveEdit() }
                        }
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    private func saveEdit() async {
        isSaving = true
        
        do {
            try await appState.editDMMessage(messageId: message.id, newContent: editedText, dmId: message.dmId)
            appState.showSuccess("Message updated")
            dismiss()
        } catch {
            appState.showError(error, title: "Failed to Update Message")
        }
        
        isSaving = false
    }
}

