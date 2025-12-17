//
//  ChatComponents.swift
//  traders_guild
//
//  Unified chat UI components for consistent styling across:
//  - Guild chatrooms
//  - Direct messages (DM)
//  - Chart-specific chats
//  - Marker comments
//
//  All chat interfaces should use these components for consistency.
//  State management remains in individual managers (MessagingManager, ChartChatManager, etc.)

import SwiftUI

// MARK: - ================================================================================================
// MARK: - CHAT MESSAGE PROTOCOL
// MARK: - ================================================================================================

/// Protocol that all message types conform to for unified rendering
/// Implement this on your message DTOs to use the unified ChatMessageBubble
protocol ChatMessageDisplayable: Identifiable {
    var id: UUID { get }
    var content: String { get }
    var timestampFormatted: String { get }
    var isEdited: Bool { get }
    var isCurrentUserMessage: Bool { get }
    var canEdit: Bool { get }
    var canDelete: Bool { get }
    
    // Author info - provide these for user display
    var authorDisplayName: String { get }
    var authorInitials: String { get }
    var authorIsOnline: Bool { get }
    var authorRole: MemberRole? { get }
    var authorReputation: Int? { get }
    var authorIsFriend: Bool { get }
    var authorIsBlocked: Bool { get }
}

// MARK: - Default implementations for simpler message types
extension ChatMessageDisplayable {
    var authorRole: MemberRole? { nil }
    var authorReputation: Int? { nil }
    var authorIsFriend: Bool { false }
    var authorIsBlocked: Bool { false }
}

// MARK: - ================================================================================================
// MARK: - CHAT CONTEXT ENUM
// MARK: - ================================================================================================

/// Defines the context/type of chat for styling differences
enum ChatContext {
    case directMessage       // 1-1 chat - shows read receipts, no user info header
    case guildChatroom      // Group chat - shows username, role, reputation above bubble
    case chartChat          // Symbol-specific chat - similar to chatroom
    case markerComment      // Marker comments - simplified user info
    
    /// Whether to show user info row above message bubble (for non-current-user messages)
    var showsUserInfoHeader: Bool {
        switch self {
        case .directMessage: return false
        case .guildChatroom, .chartChat, .markerComment: return true
        }
    }
    
    /// Whether to show full user details (role, reputation)
    var showsFullUserDetails: Bool {
        switch self {
        case .directMessage, .markerComment: return false
        case .guildChatroom, .chartChat: return true
        }
    }
    
    /// Whether to show avatar for other users
    var showsAvatar: Bool { true }
    
    /// Whether to show read receipts (only for DMs)
    var showsReadReceipts: Bool {
        self == .directMessage
    }
}

// MARK: - ================================================================================================
// MARK: - UNIFIED MESSAGE BUBBLE
// MARK: - ================================================================================================

/// Unified message bubble view that works with any ChatMessageDisplayable
/// Use this as the base for all chat message rendering
struct ChatMessageBubble<Message: ChatMessageDisplayable>: View {
    let message: Message
    let context: ChatContext
    let isRead: Bool  // Only used for DMs
    let onAvatarTap: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReport: (() -> Void)?
    let onCopy: (() -> Void)?
    
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    
    init(
        message: Message,
        context: ChatContext,
        isRead: Bool = false,
        onAvatarTap: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onReport: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.message = message
        self.context = context
        self.isRead = isRead
        self.onAvatarTap = onAvatarTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onReport = onReport
        self.onCopy = onCopy
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isCurrentUserMessage {
                Spacer()
            } else if context.showsAvatar {
                avatarView
            }
            
            VStack(alignment: message.isCurrentUserMessage ? .trailing : .leading, spacing: 4) {
                // User info header (for group chats, non-current user)
                if !message.isCurrentUserMessage && context.showsUserInfoHeader {
                    userInfoHeader
                }
                
                // Message bubble
                messageBubbleContent
                    .contextMenu { contextMenuItems }
                
                // Timestamp and status row
                timestampRow
            }
            
            if !message.isCurrentUserMessage {
                Spacer()
            }
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
    }
    
    // MARK: - Avatar View
    @ViewBuilder
    private var avatarView: some View {
        Button(action: { onAvatarTap?() }) {
            ChatAvatar(
                initials: message.authorInitials,
                isOnline: message.authorIsOnline,
                size: 32
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - User Info Header
    @ViewBuilder
    private var userInfoHeader: some View {
        HStack(spacing: 2) {
            // Blocked indicator
            if message.authorIsBlocked {
                Image(systemName: "nosign")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.bearCandleRed)
            }
            
            // Username
            Text(message.authorDisplayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(message.authorIsBlocked ? AppColors.greyText : AppColors.whiteText.opacity(0.9))
            
            // Friend indicator
            if message.authorIsFriend {
                Image(systemName: "person.crop.circle")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(message.authorIsBlocked ? AppColors.greyText : AppColors.friendAccent)
                    .padding(.leading, 3)
            }
            
            // Role and reputation (for full detail contexts)
            if context.showsFullUserDetails, let role = message.authorRole {
                Circle()
                    .fill(AppColors.whiteText.opacity(0.7))
                    .frame(width: 3, height: 3)
                    .padding(.horizontal, 3)
                
                Text(role.rawValue)
                    .font(.caption)
                    .foregroundColor(role.roleForegroundColor)
                    .fontWeight(role.roleFontWeight)
                
                if let reputation = message.authorReputation {
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 3, height: 3)
                        .padding(.horizontal, 3)
                    
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    
                    Text("\(reputation)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
                }
            }
        }
    }
    
    // MARK: - Message Bubble Content
    private var messageBubbleContent: some View {
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
        .clipShape(ChatBubbleShape.bubbleShape(isFromCurrentUser: message.isCurrentUserMessage))
    }
    
    // MARK: - Timestamp Row
    private var timestampRow: some View {
        HStack(spacing: 4) {
            Text(message.timestampFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Read receipt for DMs
            if context.showsReadReceipts && message.isCurrentUserMessage {
                Image(systemName: isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(isRead ? AppColors.accentColor : .secondary)
            }
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuItems: some View {
        if message.canEdit, let editAction = onEdit {
            Button {
                editAction()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        
        if message.canDelete, let deleteAction = onDelete {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        
        Button {
            UIPasteboard.general.string = message.content
            onCopy?()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        if !message.isCurrentUserMessage, let reportAction = onReport {
            Divider()
            Button(role: .destructive) {
                reportAction()
            } label: {
                Label("Report", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT BUBBLE SHAPE
// MARK: - ================================================================================================

/// Unified bubble shape helper
struct ChatBubbleShape {
    static func bubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
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

// MARK: - ================================================================================================
// MARK: - CHAT AVATAR
// MARK: - ================================================================================================

/// Unified avatar view with online indicator
struct ChatAvatar: View {
    let initials: String
    let isOnline: Bool
    var size: CGFloat = 32
    var showOnlineIndicator: Bool = true
    
    var body: some View {
        Circle()
            .fill(AppColors.accentColor.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(initials.uppercased())
                    .font(size > 40 ? .caption : .caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
            )
            .overlay(alignment: .bottomTrailing) {
                if showOnlineIndicator {
                    Circle()
                        .fill(isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(
                            Circle()
                                .stroke(AppColors.drawerBackground, lineWidth: 1)
                        )
                }
            }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT INPUT FOOTER
// MARK: - ================================================================================================

/// Unified chat input footer - use across all chat interfaces
struct ChatInputFooter: View {
    @Binding var messageText: String
    let placeholder: String
    let isSending: Bool
    let onSend: () -> Void
    var onAttachment: (() -> Void)? = nil
    var onVoice: (() -> Void)? = nil
    
    /// Optional: For sheet contexts where we need to expand to full height
    var selectedDetent: Binding<PresentationDetent>? = nil
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Plus/attachment button
                    Button(action: { onAttachment?() }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .compositingGroup()
                    
                    // Text field
                    TextField(placeholder, text: $messageText)
                        .font(.subheadline)
                        .submitLabel(.send)
                        .focused($isInputFocused)
                        .disabled(isSending)
                        .onSubmit {
                            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSend()
                            }
                        }
                    
                    HStack(spacing: 8) {
                        // Mic button
                        Button(action: { onVoice?() }) {
                            Image(systemName: "mic.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        .compositingGroup()
                        
                        // Send button
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 40, height: 40)
                        } else {
                            sendButton
                        }
                    }
                }
                .padding(.leading, 10)
                .frame(height: 44)
                .background(AppColors.whiteText.opacity(0.08))
                .cornerRadius(25)
            }
            .padding()
        }
        .background(AppColors.sheetBackground)
        .overlay {
            // Tap to expand sheet if not at full height
            if let detent = selectedDetent, detent.wrappedValue != .large {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        detent.wrappedValue = .large
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isInputFocused = true
                        }
                    }
            }
        }
        .compositingGroup()
    }
    
    private var sendButton: some View {
        let isEmpty = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return Button(action: onSend) {
            Image(systemName: "chevron.forward.2")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                .frame(width: 40, height: 40)
                .padding(.leading, 2)
                .background(isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                .clipShape(Capsule())
        }
        .disabled(isEmpty)
        .compositingGroup()
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT BACKGROUND
// MARK: - ================================================================================================

/// Unified chat background with material and pattern
struct ChatBackground: View {
    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            AppColors.sheetBackground
            StaticPatternView()
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EMPTY & LOADING STATES
// MARK: - ================================================================================================

/// Unified loading view for chat
struct ChatLoadingView: View {
    var message: String = "Loading messages..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.accentColor)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Unified empty state view for chat
struct ChatEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    init(
        icon: String = "bubble.left.and.bubble.right",
        title: String = "No messages yet",
        subtitle: String = "Start the conversation!"
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accentColor.opacity(0.6))
            }
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT SCROLL VIEW
// MARK: - ================================================================================================

/// Unified scrollable messages container with auto-scroll behavior
struct ChatScrollView<Message: ChatMessageDisplayable, Content: View>: View {
    let messages: [Message]
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottomImmediately(proxy: proxy)
            }
            .background(ChatBackground())
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func scrollToBottomImmediately(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - EDIT MESSAGE SHEET
// MARK: - ================================================================================================

/// Unified edit message sheet - can be used for any message type
struct UnifiedEditMessageSheet: View {
    let originalContent: String
    let onSave: (String) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedText: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    init(originalContent: String, onSave: @escaping (String) async throws -> Void) {
        self.originalContent = originalContent
        self.onSave = onSave
        _editedText = State(initialValue: originalContent)
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
                            Task {
                                isSaving = true
                                do {
                                    try await onSave(editedText)
                                    dismiss()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isSaving = false
                            }
                        }
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CHAT HEADER COMPONENTS
// MARK: - ================================================================================================

/// Generic chat header view - customize for specific chat types
struct ChatHeader<LeftContent: View, CenterContent: View, RightContent: View>: View {
    @ViewBuilder let leftContent: () -> LeftContent
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let rightContent: () -> RightContent
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                leftContent()
                Spacer()
                centerContent()
                Spacer()
                rightContent()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(AppColors.sheetBackground)
            
            Divider()
        }
    }
}

/// Standard dismiss button for chat sheets
struct ChatDismissButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

/// Standard back button for chat navigation
struct ChatBackButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.accentColor)
        }
    }
}

/// Settings button for chat header
struct ChatSettingsButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - ACTIVE USERS PILL
// MARK: - ================================================================================================

/// Active users indicator pill (for chart chat headers)
struct ActiveUsersPill: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text("\(count) active")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
        }
    }
}

// MARK: - ================================================================================================
// MARK: - CONVENIENCE EXTENSIONS
// MARK: - ================================================================================================

extension View {
    /// Apply standard chat sheet presentation modifiers
    func chatSheetPresentation() -> some View {
        self
            .presentationDetents([.fraction(0.9)])
            .presentationBackground {
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                    AppColors.sheetBackground
                }
            }
            .presentationCornerRadius(33)
    }
    
    /// Hide keyboard helper
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - ================================================================================================
// MARK: - DTO PROTOCOL CONFORMANCES
// MARK: - ================================================================================================
// These extensions make existing DTOs work with the unified ChatMessageBubble component

extension ChatroomMessageDTO: ChatMessageDisplayable {
    var authorDisplayName: String { author.globalMember.username }
    var authorInitials: String { String(author.globalMember.username.prefix(2)) }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: MemberRole? { author.roleInGuild }
    var authorReputation: Int? { author.reputation }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension DMMessageDTO: ChatMessageDisplayable {
    var authorDisplayName: String { author.globalMember.username }
    var authorInitials: String { String(author.globalMember.username.prefix(2)) }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: MemberRole? { nil }  // DMs don't show role
    var authorReputation: Int? { nil }   // DMs don't show reputation
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension ChartChatMessageDTO: ChatMessageDisplayable {
    var authorDisplayName: String { author.globalMember.username }
    var authorInitials: String { String(author.globalMember.username.prefix(2)) }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: MemberRole? { author.roleInGuild }
    var authorReputation: Int? { author.reputation }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}
