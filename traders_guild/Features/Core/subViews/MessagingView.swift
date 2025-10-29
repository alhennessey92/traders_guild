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
/// A global messaging state manager that can be used anywhere in the app
/// Add this to your app's environment to enable messaging from any view
@MainActor
class MessagingManager: ObservableObject {
    @Published var activeMessage: MessageContentType? = nil
    
    @Published var isLoadingChat: Bool = false
    @Published var chatLoadError: String? = nil
    
    // Cache to avoid refetching the same DM
    private var dmCache: [UUID: DMDTO] = [:]
    
    // Cache to avoid refetching the same Chatroom
    private var chatroomCache: [UUID: GuildChatroomDTO] = [:]
    
    private weak var appState: AppState?  // ✅ Store reference
        
    // ✅ Add initializer
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    // ✅ Configure after creation (if not passed in init)
    func configure(with appState: AppState) {
        self.appState = appState
    }
    
    /// Open a user chat from anywhere in the app
    func openUserDM(_ userDM: DMDTO) {
        activeMessage = .userDM(userDM)
    }
    
    /// Open a user chat by membership - finds or creates the DM
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
        chatLoadError = nil
        
        do {
            // ✅ Fetch from API
            let userDM = try await appState.fetchOrCreateUserDM(userId: membership.id)
            
            // Cache the result
            dmCache[membership.id] = userDM
            
            // Open the chat
            openUserDM(userDM)
            chatLoadError = nil
            
        } catch {
            print("⚠️ Failed to fetch/create DM for user \(membership.id): \(error)")
            chatLoadError = "Failed to open chat"
        }
        
        isLoadingChat = false
    }
    
    /// Open a chatroom from anywhere in the app
    func openChatroom(_ chatroom: GuildChatroomDTO) {
        activeMessage = .chatroom(chatroom)
    }
    
    /// Close any active messaging sheet
    func closeMessage() {
        activeMessage = nil
    }
    
    func clearCache() {
        dmCache.removeAll()
        chatroomCache.removeAll()
    }
}

// MARK: - Global Messaging Overlay
/// Add this to your main app view to enable global messaging
struct GlobalMessagingOverlay: ViewModifier {
    @EnvironmentObject var messagingManager: MessagingManager
    //@EnvironmentObject var appState: AppState
    
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
                    .environmentObject(messagingManager) // Pass the messaging manager to the sheet
                    //.environmentObject(appState)
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
    /// Add global messaging capability to any view
    func globalMessaging() -> some View {
        self.modifier(GlobalMessagingOverlay())
    }
}

// MARK: - Unified Messaging Sheet
/// A unified messaging sheet that handles both user chats and chatroom conversations
/// Similar structure to left drawer sheets with header, content, and footer sections
struct MessagingSheet: View {
    let contentType: MessageContentType
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager
    @State private var messageText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        // Handle settings action
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
                            UserDMHeaderView(userDM: userDM)
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
            MessagingScrollView(contentType: contentType)
            
            Divider()
            
            switch contentType {
                case .chatroom(let chatroom):
                    ChatroomFooterView(chatroom: chatroom, messageText: $messageText)
                case .userDM(let userDM):
                    UserDMFooterView(userDM: userDM, messageText: $messageText)
                }
            
            // Message input footer
//            MessagingFooterView(
//                contentType: contentType,
//                messageText: $messageText
//            )
        }
        .background(
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                AppColors.sheetBackground
                StaticPatternView()
                
            }
        )
        //.ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - User DM Header Component
struct UserDMHeaderView: View {
    let userDM: DMDTO
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(userDM.participant.globalMember.username.prefix(2)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
                
                if (userDM.participant.isOnline) {
                    Circle()
                        .fill(AppColors.bullCandleGreen)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(AppColors.sheetBackground, lineWidth: 2)
                        )
                }
                else{
                    Circle()
                        .fill(AppColors.bearCandleRed)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(AppColors.sheetBackground, lineWidth: 2)
                        )
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 3) {
                HStack (spacing: 2){

                    Text(userDM.participant.globalMember.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                }
                
                
                HStack (spacing:2){
                    
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
                Text(chatroom.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(chatroom.isActive ? AppColors.bullCandleGreen : Color.gray.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text("\(chatroom.memberCount) members")
                        .font(.caption2)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                }
            }
            
        }
        
        
    }
    
}


// MARK: - Scrollable Messages Content
// MARK: - Scrollable Messages Content
struct MessagingScrollView: View {
    let contentType: MessageContentType
    
    @EnvironmentObject var appState: AppState  // ✅ Add this
    @State private var dmMessages: [DMMessageDTO] = []  // ✅ Store fetched messages
    @State private var chatroomMessages: [ChatroomMessageDTO] = []  // ✅ Store fetched messages
    @State private var isLoadingMessages: Bool = false
    @State private var messageError: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch contentType {
                case .chatroom(let chatroom):
                    if isLoadingMessages {
                        // ✅ Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading messages...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        
                    } else if let error = messageError {
                        // ✅ Error state
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Failed to load messages")
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                Task {
                                    await loadChatroomMessages(for: chatroom)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        
                    } else if chatroomMessages.isEmpty {
                        // ✅ Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No messages yet")
                                .foregroundColor(.secondary)
                            Text("Start a conversation in \(chatroom.name)!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        
                    } else {
                        // ✅ Messages
                        ForEach(chatroomMessages) { message in
                            ChatroomMessageView(message: message)
                        }
                    }
                    
                    
                case .userDM(let userDM):
                    if isLoadingMessages {
                        // ✅ Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading messages...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        
                    } else if let error = messageError {
                        // ✅ Error state
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Failed to load messages")
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                Task {
                                    await loadDMMessages(for: userDM)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        
                    } else if dmMessages.isEmpty {
                        // ✅ Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No messages yet")
                                .foregroundColor(.secondary)
                            Text("Start the conversation with \(userDM.displayName)!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        
                    } else {
                        // ✅ Messages
                        ForEach(dmMessages) { message in
                            UserDMMessageView(message: message)
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            // ✅ Pull to refresh
            switch contentType {
            case .userDM(let userDM):
                await loadDMMessages(for: userDM, isRefresh: true)  // ✅ Add flag
            case .chatroom(let chatroom):
                await loadChatroomMessages(for: chatroom, isRefresh: true)  // ✅ Add flag
            }
        }
        .task(id: contentType) {
            // ✅ Load messages when view appears or contentType changes
            switch contentType {
            case .userDM(let userDM):
                await loadDMMessages(for: userDM, isRefresh: false)  // ✅ Add flag
            case .chatroom(let chatroom):
                await loadChatroomMessages(for: chatroom, isRefresh: false)  // ✅ Add flag
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // ✅ Updated function with better error handling
    private func loadChatroomMessages(for chatroom: GuildChatroomDTO, isRefresh: Bool = false) async {
        // Don't show loading spinner on refresh (pull-to-refresh has its own indicator)
        if !isRefresh {
            isLoadingMessages = true
        }
        messageError = nil
        
        do {
            // Fetch messages from API
            let fetchedMessages = try await appState.fetchChatroomMessages(chatroomId: chatroom.id)
            
            // Update state on main thread
            chatroomMessages = fetchedMessages
            
        } catch is CancellationError {
            // ✅ Ignore cancellation - this is normal behavior
            print("📌 Message loading was cancelled (this is normal)")
            return  // Don't set error state
            
        } catch {
            print("⚠️ Failed to load Chatroom messages: \(error)")
            messageError = error.localizedDescription
        }
        
        isLoadingMessages = false
    }
    
    // ✅ Updated function with better error handling
    private func loadDMMessages(for userDM: DMDTO, isRefresh: Bool = false) async {
        // Don't show loading spinner on refresh (pull-to-refresh has its own indicator)
        if !isRefresh {
            isLoadingMessages = true
        }
        messageError = nil
        
        do {
            // Fetch messages from API
            let fetchedMessages = try await appState.fetchDMMessages(dmId: userDM.id)
            
            // Update state on main thread
            dmMessages = fetchedMessages
            
        } catch is CancellationError {
            // ✅ Ignore cancellation - this is normal behavior
            print("📌 Message loading was cancelled (this is normal)")
            return  // Don't set error state
            
        } catch {
            print("⚠️ Failed to load DM messages: \(error)")
            messageError = error.localizedDescription
        }
        
        isLoadingMessages = false
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - Chatroom Footer Component
struct ChatroomFooterView: View {
    let chatroom: GuildChatroomDTO
    @Binding var messageText: String
    
    var body: some View {
        HStack(spacing: 0) {
            // Full-width capsule container with embedded buttons
            HStack(spacing: 12) {
                // Plus button (left side)
                Button(action: {
                    // Handle attachment/plus action
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                
                // Text input field (expands to fill available space)
                TextField("Message #\(chatroom.name.lowercased().replacingOccurrences(of: " ", with: "-"))...", text: $messageText)
                    .font(.subheadline)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Right side buttons
                HStack(spacing: 8) {
                    // Microphone button
                    Button(action: {
                        // Handle voice message
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "chevron.forward.2")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(messageText.isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .padding(.leading, 2)
                            .background(messageText.isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                            .clipShape(Capsule())
//                            .overlay(
//                                Capsule()
//                                    .strokeBorder(strokeColor ?? Color.clear, lineWidth: strokeWidth)
//                            )
                    }
                    .disabled(messageText.isEmpty)
                }
            }
            .padding(.leading, 10)
            .frame(height: 44)
            .background(AppColors.whiteText.opacity(0.08))
            .cornerRadius(25)
        }
        .padding()
        .background(AppColors.sheetBackground) // Add consistent background
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // This ensures the safe area is handled properly
            Color.clear.frame(height: 0)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Handle sending message
        messageText = ""
    }
}


// MARK: - User DM Footer Component
struct UserDMFooterView: View {
    let userDM: DMDTO
    @Binding var messageText: String
    
    var body: some View {
        HStack(spacing: 0) {
            // Full-width capsule container with embedded buttons
            HStack(spacing: 12) {
                // Emoji button (left side)
                Button(action: {
                    // Handle emoji picker
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                
                // Text input field (expands to fill available space)
                TextField("Message \(userDM.participant.globalMember.username.lowercased().replacingOccurrences(of: " ", with: "-"))...", text: $messageText)
                    .font(.subheadline)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Right side buttons
                HStack(spacing: 8) {
                    // Microphone button
                    Button(action: {
                        // Handle voice message
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "chevron.forward.2")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(messageText.isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .padding(.leading, 2)
                            .background(messageText.isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                            .clipShape(Capsule())
//                            .overlay(
//                                Capsule()
//                                    .strokeBorder(strokeColor ?? Color.clear, lineWidth: strokeWidth)
//                            )
                    }
                    .disabled(messageText.isEmpty)
                }
            }
            .padding(.leading, 10)
            .frame(height: 44)
            .background(AppColors.whiteText.opacity(0.08))
            .cornerRadius(25)
        }
        .padding()
        .background(AppColors.sheetBackground)
//        .safeAreaInset(edge: .bottom, spacing: 0) {
//            Color.clear.frame(height: 0)
//        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Handle sending message
        messageText = ""
    }
}

// MARK: - Chatroom Message View
struct ChatroomMessageView: View {
    let message: ChatroomMessageDTO
    //@EnvironmentObject var currentUser: UserStore // To check if message is from current user
    

    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isCurrentUserMessage {
                Spacer()
            } else {
                // Avatar for other users
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
                if !message.isCurrentUserMessage {
                    // User info header
                    HStack(spacing: 2) {
                        Text(message.author.globalMember.username)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText.opacity(0.9))
                        
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
                
                // Message bubble
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
                
                // Timestamp and edited indicator
                HStack(spacing: 4) {
                    Text(message.timestampFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    
                }
                
                // Reactions (if any)
//                if !message.reactions.isEmpty {
//                    HStack(spacing: 6) {
//                        ForEach(Array(Set(message.reactions.map { $0.emoji })), id: \.self) { emoji in
//                            let count = message.reactions.filter { $0.emoji == emoji }.count
//                            HStack(spacing: 2) {
//                                Text(emoji)
//                                    .font(.caption2)
//                                Text("\(count)")
//                                    .font(.caption2)
//                                    .foregroundColor(.secondary)
//                            }
//                            .padding(.horizontal, 6)
//                            .padding(.vertical, 2)
//                            .background(Color.gray.opacity(0.2))
//                            .cornerRadius(10)
//                        }
//                    }
//                }
            }
            
            if !message.isCurrentUserMessage {
                Spacer()
            }
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

struct UserDMMessageView: View {
    let message: DMMessageDTO  // FIX: Accept UserDMMessage instead of tuple
//    @EnvironmentObject var currentUser: UserStore
    
    
    
    var body: some View {
        HStack {
            if message.isCurrentUserMessage {
                Spacer()
            } else {
                // Avatar for other user
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
                // Message bubble
                HStack(spacing: 8) {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    
                    // Edited indicator
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
                    // Edit button (only if user can edit)
                    if message.canEdit {
                        Button {
                            // Handle edit
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    // Delete button (only if user can delete)
                    if message.canDelete {
                        Button(role: .destructive) {
                            // Handle delete
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    
                    // Copy button
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                
                // Timestamp
                HStack(spacing: 4) {
                    Text(message.timestampFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Read indicator for current user's messages
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
    }
    
    private func userChatMessageBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
        if isFromCurrentUser {
            // Current user: pointed on bottom right
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        } else {
            // Other user: pointed on bottom left
            return UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        }
    }
}




