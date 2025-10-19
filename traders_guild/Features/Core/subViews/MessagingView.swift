//
//  MessagingView.swift
//  traders_guild
//
//  Created by Al Hennessey on 17/10/2025.
//
import SwiftUI

// MARK: - Message Content Types
enum MessageContentType {
    case user(GuildUser)
    case chatroom(Chatroom)
}

// MARK: - Global Messaging Manager
/// A global messaging state manager that can be used anywhere in the app
/// Add this to your app's environment to enable messaging from any view
class MessagingManager: ObservableObject {
    @Published var activeMessage: MessageContentType? = nil
    
    /// Open a user chat from anywhere in the app
    func openUserChat(_ user: GuildUser) {
        activeMessage = .user(user)
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
                    .presentationDetents([.large])
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
                        case .user(let user):
                            UserChatHeaderView(user: user)
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
                
                
                Divider()
            }
            
            // Main content area with messages
            MessagingScrollView(contentType: contentType)
            
            Divider()
            
            switch contentType {
                case .chatroom(let chatroom):
                ChatroomFooterView(chatroom: chatroom, messageText: $messageText)
                case .user(let user):
                    UserChatFooterView(user: user, messageText: $messageText)
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
            }
        )
        
    }
}

// MARK: - User Chat Header Component
struct UserChatHeaderView: View {
    let user: GuildUser
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(user.name.prefix(2)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
                
                if user.isOnline {
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

                    Text(user.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                }
                
                
                HStack (spacing:2){
                    Text(user.role.rawValue)
                        .font(.caption2)
                        .foregroundColor(user.role.foregroundColor)
                        .fontWeight(user.role.fontWeight)
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
                    Text("\(user.reputation)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
                    
                    
                }
            }
            
        }
        .padding(.top, 4)
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
                    .frame(width: 34, height: 34)
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
        .padding(.top, 4)
    }
    
}


// MARK: - Scrollable Messages Content
struct MessagingScrollView: View {
    let contentType: MessageContentType
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch contentType {
                case .chatroom(_):
                    ForEach(Array(ChatroomSampleData.messages.enumerated()), id: \.offset) { index, message in
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
                        Image(systemName: messageText.isEmpty ? "paperplane" : "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(messageText.isEmpty ? .secondary : AppColors.accentColor)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(messageText.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
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
    let user: GuildUser
    @Binding var messageText: String
    
    var body: some View {
        HStack(spacing: 0) {
            // Full-width capsule container with embedded buttons
            HStack(spacing: 12) {
                // Emoji button (left side)
                Button(action: {
                    // Handle emoji picker
                }) {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                
                // Text input field (expands to fill available space)
                TextField("Message \(user.name.lowercased().replacingOccurrences(of: " ", with: "-"))...", text: $messageText)
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
                        Image(systemName: messageText.isEmpty ? "paperplane" : "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(messageText.isEmpty ? .secondary : AppColors.accentColor)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(messageText.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
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

// MARK: - Message Views
struct ChatroomMessageView: View {
    let message: (message: String, user: String, isFromCurrentUser: Bool, timestamp: String)
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromCurrentUser {
                Spacer()
            } else {
                // Avatar for other users
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.user.prefix(2)))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.user)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isFromCurrentUser ?
                        AppColors.accentColor :
                        Color.gray.opacity(0.2)
                    )
                    .cornerRadius(16)
                
                Text(message.timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
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
                        AppColors.accentColor :
                        Color.gray.opacity(0.2)
                    )
                    .cornerRadius(16)
                
                Text(message.timestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

// MARK: - Sample Data
struct ChatroomSampleData {
    static let messages = [
        (message: "Hey everyone! What's the market looking like today?", user: "User1", isFromCurrentUser: false, timestamp: "9:15 AM"),
        (message: "BTC broke resistance, looking bullish!", user: "User2", isFromCurrentUser: false, timestamp: "9:18 AM"),
        (message: "I caught that move! Entry at 45.2k", user: "You", isFromCurrentUser: true, timestamp: "9:20 AM"),
        (message: "Nice entry! What's your target?", user: "User3", isFromCurrentUser: false, timestamp: "9:21 AM"),
        (message: "Aiming for 47k, stop at 44.5k", user: "You", isFromCurrentUser: true, timestamp: "9:22 AM"),
        (message: "Smart play. I'm watching ETH right now", user: "User1", isFromCurrentUser: false, timestamp: "9:25 AM"),
        (message: "ETH looks good too, check the 4h chart", user: "User4", isFromCurrentUser: false, timestamp: "9:27 AM")
    ]
}

struct UserChatSampleData {
    static let messages = [
        (message: "Hi! How's the trading going today?", isFromCurrentUser: false, timestamp: "10:23 AM"),
        (message: "Pretty good! Just caught a nice move on AAPL", isFromCurrentUser: true, timestamp: "10:24 AM"),
        (message: "Nice! What was your entry?", isFromCurrentUser: false, timestamp: "10:25 AM"),
        (message: "Got in at 175.20, targeting 178", isFromCurrentUser: true, timestamp: "10:26 AM"),
        (message: "Solid trade! I'm watching TSLA right now", isFromCurrentUser: false, timestamp: "10:28 AM"),
        (message: "Yeah TSLA looks interesting. Check the 4h chart", isFromCurrentUser: true, timestamp: "10:29 AM")
    ]
}


