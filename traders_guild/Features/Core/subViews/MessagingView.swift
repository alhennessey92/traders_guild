//
//  MessagingView.swift
//  traders_guild
//
//  Created by Al Hennessey on 17/10/2025.
//
import SwiftUI

// MARK: - Message Content Types
enum MessageContentType {
    case user(GuildMembership)
    case chatroom(Chatroom)
}

// MARK: - Global Messaging Manager
/// A global messaging state manager that can be used anywhere in the app
/// Add this to your app's environment to enable messaging from any view
class MessagingManager: ObservableObject {
    @Published var activeMessage: MessageContentType? = nil
    
    /// Open a user chat from anywhere in the app
    func openUserChat(_ membership: GuildMembership) {
        activeMessage = .user(membership)
    }
    
    /// Open a chatroom from anywhere in the app
    func openChatroom(_ chatroom: Chatroom) {
        activeMessage = .chatroom(chatroom)
    }
    
    /// Close any active messaging sheet
    func closeMessage() {
        activeMessage = nil
    }
}

// MARK: - Global Messaging Overlay
/// Add this to your main app view to enable global messaging
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
                    .environmentObject(messagingManager) // Pass the messaging manager to the sheet
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
                        case .user(let membership):
                            UserChatHeaderView(membership: membership)
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
                case .user(let membership):
                    UserChatFooterView(membership: membership, messageText: $messageText)
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
        
    }
}

// MARK: - User Chat Header Component
struct UserChatHeaderView: View {
    let membership: GuildMembership
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(membership.userName?.prefix(2) ?? "unKnown"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
                
                if membership.isUserOnline {
                    Circle()
                        .fill(AppColors.bullCandleGreen)
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

                    Text(membership.userName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                }
                
                
                HStack (spacing:2){
                    Text(membership.roleInGuild.rawValue)
                        .font(.caption2)
                        .foregroundColor(membership.roleInGuild.foregroundColor)
                        .fontWeight(membership.roleInGuild.fontWeight)
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
                    Text("\(membership.reputation)")
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
    let chatroom: Chatroom
    
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
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch contentType {
                case .chatroom(let chatroom):
                    // Filter messages for this specific chatroom
                    ForEach(chatroomMessages(for: chatroom)) { message in
                        ChatroomMessageView(message: message)
                    }
                    
                case .user(_):
                    ForEach(Array(UserChatSampleData.messages.enumerated()), id: \.offset) { index, message in
                        UserChatMessageView(message: message)
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // Helper to get messages for specific chatroom
    private func chatroomMessages(for chatroom: Chatroom) -> [ChatroomMessage] {
        ChatroomMessage.sampleChatroomMessages.filter { $0.roomId == chatroom.id }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - Chatroom Footer Component
struct ChatroomFooterView: View {
    let chatroom: Chatroom
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
            .frame(height: 40)
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


// MARK: - User Chat Footer Component
struct UserChatFooterView: View {
    let membership: GuildMembership
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
                TextField("Message \(membership.userName?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "user")...", text: $messageText)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 0)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Handle sending message
        messageText = ""
    }
}

// MARK: - Chatroom Message View
struct ChatroomMessageView: View {
    let message: ChatroomMessage
    @EnvironmentObject var currentUser: UserStore // To check if message is from current user
    
    var isFromCurrentUser: Bool {
        message.senderMembershipId == MembershipIDs.currentUserKaos
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isFromCurrentUser {
                Spacer()
            } else {
                // Avatar for other users
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.authorName?.prefix(2) ?? "?"))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    // User info header
                    HStack(spacing: 2) {
                        Text(message.authorName ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText.opacity(0.9))
                        
                        if let role = message.authorRole {
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.7))
                                .frame(width: 3, height: 3)
                                .padding(.horizontal, 3)
                            
                            Text(role.rawValue)
                                .font(.caption)
                                .foregroundColor(role.foregroundColor)
                                .fontWeight(role.fontWeight)
                            
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.7))
                                .frame(width: 3, height: 3)
                                .padding(.horizontal, 3)
                            
                            Image(systemName: "shield.pattern.checkered")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                            
                            Text("\(message.authorGuildReputation ?? 0)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accentColor)
                        }
                    }
                }
                
                // Message bubble
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isFromCurrentUser ?
                        AppColors.accentDarkColor :
                        Color.gray.opacity(0.2)
                    )
                    .clipShape(chatRoomMessageBubbleShape(isFromCurrentUser: isFromCurrentUser))
                
                // Timestamp and edited indicator
                HStack(spacing: 4) {
                    Text(message.timeAgo)
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
            
            if !isFromCurrentUser {
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

struct UserChatMessageView: View {
    let message: (message: String, isFromCurrentUser: Bool, timestamp: String)
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isFromCurrentUser ?
                        AppColors.accentDarkColor :
                        Color.gray.opacity(0.2)
                    )
                    .clipShape(userChatMessageBubbleShape(isFromCurrentUser: message.isFromCurrentUser))
                
                Text(message.timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromCurrentUser {
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

// MARK: - Sample Data


struct UserChatSampleData {
    static let messages = [
        (message: "Hi! How's the trading going today?", isFromCurrentUser: false, timestamp: "10:23 AM"),
        (message: "Pretty good! Just caught a nice move on AAPL", isFromCurrentUser: true, timestamp: "10:24 AM"),
        (message: "Nice! What was your entry?", isFromCurrentUser: false, timestamp: "10:25 AM"),
        (message: "Got in at 175.20, targeting 178", isFromCurrentUser: true, timestamp: "10:26 AM"),
        (message: "Solid trade! I'm watching TSLA right now", isFromCurrentUser: false, timestamp: "10:28 AM"),
        (message: "Yeah TSLA looks interesting. Check the 4h chart", isFromCurrentUser: true, timestamp: "10:29 AM"),
        (message: "Hi! How's the trading going today?", isFromCurrentUser: false, timestamp: "10:23 AM"),
        (message: "Pretty good! Just caught a nice move on AAPL", isFromCurrentUser: true, timestamp: "10:24 AM"),
        (message: "Nice! What was your entry?", isFromCurrentUser: false, timestamp: "10:25 AM"),
        (message: "Got in at 175.20, targeting 178", isFromCurrentUser: true, timestamp: "10:26 AM"),
        (message: "Solid trade! I'm watching TSLA right now", isFromCurrentUser: false, timestamp: "10:28 AM"),
        (message: "Yeah TSLA looks interesting. Check the 4h chart", isFromCurrentUser: true, timestamp: "10:29 AM"),
        (message: "Hi! How's the trading going today?", isFromCurrentUser: false, timestamp: "10:23 AM"),
        (message: "Pretty good! Just caught a nice move on AAPL", isFromCurrentUser: true, timestamp: "10:24 AM"),
        (message: "Nice! What was your entry?", isFromCurrentUser: false, timestamp: "10:25 AM"),
        (message: "Got in at 175.20, targeting 178", isFromCurrentUser: true, timestamp: "10:26 AM"),
        (message: "Solid trade! I'm watching TSLA right now", isFromCurrentUser: false, timestamp: "10:28 AM"),
        (message: "Yeah TSLA looks interesting. Check the 4h chart", isFromCurrentUser: true, timestamp: "10:29 AM")
    ]
}


