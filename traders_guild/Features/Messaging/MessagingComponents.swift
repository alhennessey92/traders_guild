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
    var avatarURL: String? = nil
    let isOnline: Bool
    var size: CGFloat = 32
    var showOnlineIndicator: Bool = true
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .overlay(
                                Text(initials.uppercased())
                                    .font(size > 40 ? .caption : .caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.accentColor)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials.uppercased())
                            .font(size > 40 ? .caption : .caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
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

    /// Callback when user selects a file/photo attachment: (fileData, filename, mimeType)
    var onAttachmentSelected: ((Data, String, String) -> Void)? = nil

    /// Optional: For sheet contexts where we need to expand to full height
    var selectedDetent: Binding<PresentationDetent>? = nil
    @FocusState private var isInputFocused: Bool

    /// Speech recognition service — self-contained dictation
    @StateObject private var speechService = SpeechRecognitionService()

    /// Attachment picker state
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator bar
            if speechService.isRecording {
                recordingIndicator
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Plus/attachment button — shows menu
                    Menu {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Photo", systemImage: "photo.fill")
                        }
                        Button {
                            showDocumentPicker = true
                        } label: {
                            Label("File", systemImage: "doc.fill")
                        }
                    } label: {
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
                        // Mic button — toggles dictation
                        Button(action: {
                            HapticFeedback.light.trigger()
                            speechService.toggleRecording()
                        }) {
                            Image(systemName: speechService.isRecording ? "mic.circle.fill" : "mic.fill")
                                .font(.title3)
                                .foregroundColor(speechService.isRecording ? .red : .secondary)
                                .frame(width: 32, height: 32)
                                .symbolEffect(.pulse, isActive: speechService.isRecording)
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
        .onChange(of: speechService.transcribedText) { _, newValue in
            // Append transcribed text to message input
            if !newValue.isEmpty {
                if messageText.isEmpty {
                    messageText = newValue
                } else {
                    // If user had existing text, append with a space
                    let trimmedExisting = messageText.trimmingCharacters(in: .whitespaces)
                    messageText = trimmedExisting + " " + newValue
                }
            }
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            if !isRecording && !speechService.transcribedText.isEmpty {
                // Recording stopped — final text is already in messageText via transcribedText observer
                speechService.transcribedText = ""
            }
        }
        .onDisappear {
            speechService.cleanup()
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            PhotoPickerView(
                onImageSelected: { data, filename, mimeType in
                    showPhotoPicker = false
                    onAttachmentSelected?(data, filename, mimeType)
                },
                onCancel: { showPhotoPicker = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                onDocumentSelected: { data, filename, mimeType in
                    showDocumentPicker = false
                    onAttachmentSelected?(data, filename, mimeType)
                },
                onCancel: { showDocumentPicker = false }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(speechService.isRecording ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechService.isRecording)

            Text("Listening...")
                .font(.caption)
                .foregroundColor(.red)

            Spacer()

            if let errorMessage = speechService.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }

            Button(action: {
                speechService.stopRecording()
            }) {
                Text("Stop")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.1))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
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
struct ChatScrollView<Message: RLChatMessageDisplayable, Content: View>: View {
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
// MARK: - RL MESSAGE PROTOCOL (for RLAppState-based messaging)
// MARK: - ================================================================================================

/// Protocol for RL message types - uses RLMemberRole instead of MemberRole
protocol RLChatMessageDisplayable: Identifiable {
    var id: UUID { get }
    var content: String { get }
    var timestampFormatted: String { get }
    var isEdited: Bool { get }
    var isCurrentUserMessage: Bool { get }
    var canEdit: Bool { get }
    var canDelete: Bool { get }

    // Author info
    var authorUsername: String { get }
    var authorInitials: String { get }
    var authorAvatarUrl: String? { get }
    var authorIsOnline: Bool { get }
    var authorRole: RLMemberRole { get }
    var authorReputation: Int { get }
    var authorIsFriend: Bool { get }
    var authorIsBlocked: Bool { get }

    // Attachment info
    var attachmentUrl: String? { get }
    var attachmentType: String? { get }
    var attachmentName: String? { get }
}

// MARK: - ================================================================================================
// MARK: - RL MESSAGE BUBBLE
// MARK: - ================================================================================================

/// RL version of ChatMessageBubble - works with RLAppState and RLMemberRole
struct RLChatMessageBubble<Message: RLChatMessageDisplayable>: View {
    let message: Message
    let context: ChatContext
    let isRead: Bool
    let onAvatarTap: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReport: (() -> Void)?
    let onCopy: (() -> Void)?
    
    @EnvironmentObject var appState: RLAppState
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
                avatarURL: message.authorAvatarUrl,
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
            
            // Username - always grey/white, NOT role colored
            Text(message.authorUsername)
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
            
            // Role and reputation (for full detail contexts like guild chatrooms)
            if context.showsFullUserDetails {
                Circle()
                    .fill(AppColors.whiteText.opacity(0.7))
                    .frame(width: 3, height: 3)
                    .padding(.horizontal, 3)
                
                // Role text gets role color
                Text(message.authorRole.displayName)
                    .font(.caption)
                    .foregroundColor(message.authorRole.color.opacity(0.9))
                    .fontWeight(message.authorRole.canModerate ? .bold : .regular)
                
                Circle()
                    .fill(AppColors.whiteText.opacity(0.7))
                    .frame(width: 3, height: 3)
                    .padding(.horizontal, 3)
                
                Image(systemName: "shield.pattern.checkered")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
                
                Text("\(message.authorReputation)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentColor)
            }
        }
    }
    
    // MARK: - Message Bubble Content
    private var messageBubbleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Attachment preview (if present)
            if let attachmentUrl = message.attachmentUrl, !attachmentUrl.isEmpty {
                attachmentView(url: attachmentUrl, type: message.attachmentType, name: message.attachmentName)
            }

            // Text content + edited indicator
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

    // MARK: - Attachment View
    @ViewBuilder
    private func attachmentView(url: String, type: String?, name: String?) -> some View {
        let isImage = type?.hasPrefix("image/") == true

        if isImage, let imageUrl = URL(string: url) {
            // Image attachment — show inline preview
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    fileAttachmentRow(name: name, type: type)
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 80)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            // Non-image attachment — show file row
            fileAttachmentRow(name: name, type: type)
        }
    }

    private func fileAttachmentRow(name: String?, type: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon(for: type))
                .font(.title3)
                .foregroundColor(message.isCurrentUserMessage ? .white : AppColors.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? "Attachment")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(message.isCurrentUserMessage ? .white : .primary)
                    .lineLimit(1)

                Text(type ?? "File")
                    .font(.caption2)
                    .foregroundColor(message.isCurrentUserMessage ? .white.opacity(0.7) : .secondary)
            }
        }
        .padding(8)
        .background(
            (message.isCurrentUserMessage ? Color.white.opacity(0.15) : Color.gray.opacity(0.15))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fileIcon(for mimeType: String?) -> String {
        guard let type = mimeType else { return "doc.fill" }
        if type.hasPrefix("image/") { return "photo.fill" }
        if type == "application/pdf" { return "doc.text.fill" }
        if type == "text/plain" { return "doc.plaintext.fill" }
        if type == "application/zip" { return "doc.zipper" }
        return "doc.fill"
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
// MARK: - RL DTO PROTOCOL CONFORMANCES
// MARK: - ================================================================================================

extension RLChatroomMessageDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension RLDMMessageDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}

extension RLChartChatMessageDTO: RLChatMessageDisplayable {
    var authorUsername: String { author.username }
    var authorInitials: String { author.initials }
    var authorAvatarUrl: String? { author.avatarUrl }
    var authorIsOnline: Bool { author.isOnline }
    var authorRole: RLMemberRole { author.memberRole }
    var authorReputation: Int { author.reputation }
    var authorIsFriend: Bool { author.isFriend }
    var authorIsBlocked: Bool { author.isBlocked }
}












//
//  MessagingComponents+RL.swift
//  traders_guild
//
//  Extension to add RLChatMessageDisplayable conformance to new RL messaging DTOs.
//  This allows RLChatroomMessageDTO and RLDMMessageDTO to work with RLChatMessageBubble.
//


// MARK: - ================================================================================================
// MARK: - RL CHATROOM SETTINGS VIEW
// MARK: - ================================================================================================

/// Settings view for RLGuildChatroomDTO
struct RLChatroomSettingsView: View {
    let chatroom: RLGuildChatroomDTO
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    
    @State private var notificationsEnabled = true
    @State private var showMuteOptions = false
    @State private var showReportOptions = false
    @State private var isPinned = false
    @State private var isMuted = false
    
    var body: some View {
        ZStack {
            StaticMessagingBackgroundView()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Chatroom Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.gradientBackgroundDark.opacity(0.4))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "number")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.whiteText.opacity(0.4))
                                
                                if chatroom.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                        .offset(x: 20, y: -20)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(chatroom.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.whiteText)
                                    
                                    if chatroom.isMuted {
                                        Image(systemName: "speaker.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.greyText)
                                    }
                                }
                                
                                if let description = chatroom.description {
                                    Text(description)
                                        .font(.caption2)
                                        .foregroundColor(AppColors.greyText)
                                }
                                
                                Text("\(chatroom.memberCount) members")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.greyText)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    // Quick Actions Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Quick Actions")
                        
                        SettingsToggleRow(
                            icon: "pin.fill",
                            title: "Pin Chatroom",
                            subtitle: "Keep at top of list",
                            isOn: Binding(
                                get: { isPinned },
                                set: { newValue in
                                    isPinned = newValue
                                    Task {
                                        _ = try? await rlAppState.updateChatroomSettings(
                                            chatroomId: chatroom.id,
                                            isPinned: newValue
                                        )
                                        await rightDrawerViewModel.refresh(for: chatroom.guildId, appState: rlAppState)
                                    }
                                }
                            ),
                            iconColor: .yellow
                        )
                    }
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Notifications")
                        
                        SettingsToggleRow(
                            icon: "bell.fill",
                            title: "Push Notifications",
                            subtitle: "Get notified about new messages",
                            isOn: Binding(
                                get: { !isMuted },
                                set: { newValue in
                                    isMuted = !newValue
                                    Task {
                                        _ = try? await rlAppState.updateChatroomSettings(
                                            chatroomId: chatroom.id,
                                            isMuted: !newValue
                                        )
                                        await rightDrawerViewModel.refresh(for: chatroom.guildId, appState: rlAppState)
                                    }
                                }
                            ),
                            iconColor: AppColors.accentColor
                        )
                        
                        SettingsButtonRow(
                            icon: "bell.slash.fill",
                            title: "Mute Chatroom",
                            subtitle: "Silence notifications temporarily",
                            iconColor: .orange
                        ) {
                            showMuteOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Privacy & Safety Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Privacy & Safety")
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report Chatroom",
                            subtitle: "Report inappropriate content",
                            iconColor: .red
                        ) {
                            showReportOptions = true
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .onAppear {
            isPinned = chatroom.isPinned
            isMuted = chatroom.isMuted
        }
        .alert("Mute Chatroom", isPresented: $showMuteOptions) {
            Button("Cancel", role: .cancel) { }
            Button("15 Minutes") { muteChatroom(duration: .minutes15) }
            Button("1 Hour") { muteChatroom(duration: .hour1) }
            Button("8 Hours") { muteChatroom(duration: .hours8) }
            Button("24 Hours") { muteChatroom(duration: .hours24) }
        } message: {
            Text("How long would you like to mute this chatroom?")
        }
        .alert("Report Chatroom", isPresented: $showReportOptions) {
            Button("Spam or Scam") { reportChatroom(reason: "spam") }
            Button("Harassment") { reportChatroom(reason: "harassment") }
            Button("Inappropriate Content") { reportChatroom(reason: "inappropriate") }
            Button("Other") { reportChatroom(reason: "other") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Why are you reporting this chatroom?")
        }
    }
    
    private func muteChatroom(duration: MuteDuration) {
        Task {
            do {
                _ = try await rlAppState.updateChatroomSettings(chatroomId: chatroom.id, isMuted: true)
                isMuted = true
                await rightDrawerViewModel.refresh(for: chatroom.guildId, appState: rlAppState)
                rlAppState.showSuccess("Chatroom muted for \(duration.displayName)")
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
    
    private func reportChatroom(reason: String) {
        Task {
            guard let guildId = rlAppState.currentGuild?.id else {
                rlAppState.showError(title: "No Guild Selected", message: "Please select a guild first.", style: .toast)
                return
            }
            do {
                try await rlAppState.reportChatroom(guildId: guildId, chatroomId: chatroom.id, reason: reason)
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - RL DM SETTINGS VIEW
// MARK: - ================================================================================================

/// Settings view for RLDMThreadDTO
struct RLDMSettingsView: View {
    let thread: RLDMThreadDTO
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showMuteOptions = false
    @State private var showBlockConfirmation = false
    @State private var showUnblockConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showReportOptions = false
    
    private var participant: RLGuildMemberDTO {
        thread.participant
    }
    
    var body: some View {
        ZStack {
            StaticMessagingBackgroundView()
            
            ScrollView {
                VStack(spacing: 0) {
                    // User Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            // Avatar
                            UnifiedMemberAvatar(
                                username: participant.username,
                                avatarURL: participant.avatarUrl,
                                isOnline: participant.isOnline,
                                size: 36
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    if thread.isBlocked {
                                        Image(systemName: "nosign")
                                            .font(.caption)
                                            .foregroundColor(AppColors.bearCandleRed)
                                    }

                                    Text(participant.username)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(thread.isBlocked ? AppColors.greyText : AppColors.whiteText)
                                    
                                    if participant.isFriend {
                                        Image(systemName: "person.crop.circle.badge.checkmark")
                                            .font(.caption)
                                            .foregroundColor(AppColors.friendAccent)
                                    }
                                }
                                
                                Text("@\(participant.username)")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.greyText)
                                
                                HStack(spacing: 4) {
                                    Text(participant.memberRole.displayName)
                                        .font(.caption2)
                                        .foregroundColor(participant.memberRole.color)
                                    
                                    Text("·")
                                        .foregroundColor(AppColors.greyText)
                                    
                                    Image(systemName: "shield.pattern.checkered")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.accentColor)
                                    
                                    Text("\(participant.reputation)")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.accentColor)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Notifications")
                        
                        SettingsButtonRow(
                            icon: "bell.slash.fill",
                            title: "Mute Conversation",
                            subtitle: "Silence notifications temporarily",
                            iconColor: .orange
                        ) {
                            showMuteOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Privacy & Safety Section
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Privacy & Safety")
                        
                        if thread.isBlocked {
                            SettingsButtonRow(
                                icon: "hand.raised.slash.fill",
                                title: "Unblock User",
                                subtitle: "Allow messages from this user",
                                iconColor: .green
                            ) {
                                showUnblockConfirmation = true
                            }
                        } else {
                            SettingsButtonRow(
                                icon: "hand.raised.fill",
                                title: "Block User",
                                subtitle: "Stop receiving messages",
                                iconColor: .red
                            ) {
                                showBlockConfirmation = true
                            }
                        }
                        
                        SettingsButtonRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report User",
                            subtitle: "Report inappropriate behavior",
                            iconColor: .red
                        ) {
                            showReportOptions = true
                        }
                    }
                    
                    Divider()
                    
                    // Danger Zone
                    VStack(spacing: 0) {
                        SettingsSectionHeader(title: "Conversation")
                        
                        SettingsButtonRow(
                            icon: "trash.fill",
                            title: "Delete Conversation",
                            subtitle: "This cannot be undone",
                            iconColor: .red
                        ) {
                            showDeleteConfirmation = true
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .alert("Mute Conversation", isPresented: $showMuteOptions) {
            Button("Cancel", role: .cancel) { }
            Button("15 Minutes") { muteConversation(duration: .minutes15) }
            Button("1 Hour") { muteConversation(duration: .hour1) }
            Button("8 Hours") { muteConversation(duration: .hours8) }
            Button("24 Hours") { muteConversation(duration: .hours24) }
        } message: {
            Text("How long would you like to mute this conversation?")
        }
        .alert("Block User", isPresented: $showBlockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(participant.username)? You won't receive messages from them.")
        }
        .alert("Unblock User", isPresented: $showUnblockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock") {
                unblockUser()
            }
        } message: {
            Text("Are you sure you want to unblock \(participant.username)?")
        }
        .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteConversation()
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This cannot be undone.")
        }
        .alert("Report User", isPresented: $showReportOptions) {
            Button("Spam") { reportUser(reason: "spam") }
            Button("Harassment") { reportUser(reason: "harassment") }
            Button("Inappropriate Content") { reportUser(reason: "inappropriate") }
            Button("Scam or Fraud") { reportUser(reason: "scam") }
            Button("Other") { reportUser(reason: "other") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Why are you reporting this user?")
        }
    }
    
    private func muteConversation(duration: MuteDuration) {
        rlAppState.showSuccess("Conversation muted for \(duration.displayName)")
    }
    
    private func blockUser() {
        Task {
            do {
                _ = try await rlAppState.blockUser(membershipId: participant.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                rlAppState.showSuccess("User blocked")
                rlMessagingManager.closeMessage()
                dismiss()
            } catch {
                // Error already shown
            }
        }
    }
    
    private func unblockUser() {
        Task {
            do {
                _ = try await rlAppState.unblockUser(membershipId: participant.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                rlAppState.showSuccess("User unblocked")
                dismiss()
            } catch {
                // Error already shown
            }
        }
    }
    
    private func deleteConversation() {
        Task {
            do {
                try await rlAppState.deleteDMThread(threadId: thread.id)
                rlMessagingManager.closeMessage()
                dismiss()
            } catch {
                // Error already shown
            }
        }
    }
    
    private func reportUser(reason: String) {
        Task {
            do {
                try await rlAppState.reportUser(
                    guildId: thread.guildId,
                    membershipId: participant.membershipId,
                    reason: reason
                )
            } catch {
                // Error already shown by rlAppState
            }
        }
    }
}
