//
//  MarkerDetailView.swift
//  traders_guild
//
//  CONVERTED: Now uses ChartMarkerUI and MarkerCommentDTO instead of legacy types
//
//  Comprehensive marker detail view with:
//  - Header: Gradient background, icon, user info, stats
//  - Info: Type-specific content
//  - Footer: Circular action buttons
//  - Navigation to full-screen comments view using unified ChatComponents

import SwiftUI
import Combine

// MARK: - Marker Detail View

struct MarkerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @ObservedObject var markerManager: MarkerManager
    
    let marker: ChartMarkerUI
    @Binding var selectedDetent: PresentationDetent
    
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var comments: [RLMarkerCommentDTO] = []
    @State private var showDeleteMarkerConfirmation: Bool = false
    @State private var showReportReasonSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var selectedAuthorProfileMember: RLGuildMemberDTO? = nil
    @State private var authorProfileDetent: PresentationDetent = .fraction(0.6)
    @StateObject private var overlayState = MarkerOverlayState()
    
    init(marker: ChartMarkerUI, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
        self.marker = marker
        self.markerManager = markerManager
        self._selectedDetent = selectedDetent
        
        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
        _likeCount = State(initialValue: marker.likeCount)
        _comments = State(initialValue: marker.comments)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Hero header with gradient
                    MarkerDetailHeaderView(
                        marker: marker,
                        isLiked: isLiked,
                        likeCount: likeCount,
                        commentCount: comments.count,
                        isOwner: marker.isCurrentUserMarker,
                        onAuthorTap: {
                            selectedAuthorProfileMember = marker.author
                        }
                    )

                    // Info content
                    ScrollView(.vertical, showsIndicators: false) {
                        MarkerInfoContent(marker: marker)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .padding(.bottom, 80) // space for floating engagement bar
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(
                    ZStack {
                        Color.clear
                            .background(.ultraThinMaterial)
                        AppColors.sheetBackground
                        StaticPatternView()
                    }
                )

                // Floating dismiss button
                ChatDismissButton { dismiss() }
                    .padding(.top, 16)
                    .padding(.trailing, 16)

                // Floating engagement bar at bottom
                VStack {
                    Spacer()
                    FloatingEngagementBar(
                        isLiked: isLiked,
                        likeCount: likeCount,
                        commentCount: comments.count,
                        isOwner: marker.isCurrentUserMarker,
                        intentColor: marker.intent.color,
                        onLike: handleLike,
                        onShare: handleShare,
                        onReport: { showReportReasonSheet = true },
                        onDelete: { showDeleteMarkerConfirmation = true }
                    )
                }
            }
            .alert("Delete Marker", isPresented: $showDeleteMarkerConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    handleDelete()
                }
            } message: {
                Text("Are you sure you want to delete this marker? This action cannot be undone.")
            }
            .sheet(isPresented: $showReportReasonSheet) {
                ReportReasonSheet(
                    title: "Why are you reporting this marker?",
                    includeScam: false,
                    onReasonSelected: { reason in
                        handleReport(reason: reason)
                        showReportReasonSheet = false
                    },
                    onCancel: { showReportReasonSheet = false }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                MarkerShareSheet(marker: marker)
                    .environmentObject(rlAppState)
            }
            .sheet(item: $selectedAuthorProfileMember) { member in
                if member.userId == rlAppState.currentUser?.id {
                    UserProfileDetailView(selectedDetent: $authorProfileDetent)
                        .environmentObject(rlAppState)
                        .environmentObject(leftDrawerViewModel)
                } else {
                    GuildUserDetailViewRL(member: member)
                        .environmentObject(rlAppState)
                }
            }
            .onReceive(markerManager.$markers) { updatedMarkers in
                guard let updated = updatedMarkers.first(where: { $0.id == marker.id }) else { return }
                if updated.comments != comments {
                    comments = updated.comments
                }
                if updated.likeCount != likeCount {
                    likeCount = updated.likeCount
                }
                if updated.isLikedByCurrentUser != isLiked {
                    isLiked = updated.isLikedByCurrentUser
                }
            }
            .onAppear {
                overlayState.apply(marker: marker)
                syncStateWithLatestMarker()
            }
            .onDisappear {
                overlayState.clear()
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleLike() {
        HapticFeedback.light.trigger()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }
        
        // Update marker manager
        Task {
            await markerManager.toggleLike(markerId: marker.id)
        }
    }
    
    private func handleShare() {
        HapticFeedback.medium.trigger()
        showShareSheet = true
    }
    
    private func handleReport(reason: String) {
        HapticFeedback.medium.trigger()
        Task {
            do {
                _ = try await rlAppState.reportMarker(
                    guildId: marker.guildId,
                    markerId: marker.id,
                    reason: reason
                )
            } catch {
                return
            }
        }
    }
    
    private func handleDelete() {
        HapticFeedback.warning.trigger()
        Task {
            await markerManager.deleteMarker(id: marker.id)
            rlAppState.showSuccess("Marker deleted")
            dismiss()
        }
    }

    private func syncStateWithLatestMarker() {
        guard let updated = markerManager.markers.first(where: { $0.id == marker.id }) else { return }
        comments = updated.comments
        likeCount = updated.likeCount
        isLiked = updated.isLikedByCurrentUser
    }
}

struct MarkerShareSheet: View {
    enum DestinationMode: String, CaseIterable, Identifiable {
        case chatroom = "Chatroom"
        case dm = "DM"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rlAppState: RLAppState

    let marker: ChartMarkerUI

    @State private var mode: DestinationMode = .chatroom
    @State private var note: String = ""
    @State private var chatrooms: [RLGuildChatroomDTO] = []
    @State private var dmThreads: [RLDMThreadDTO] = []
    @State private var selectedChatroomId: UUID?
    @State private var selectedThreadId: UUID?
    @State private var symbolTicker: String?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Destination", selection: $mode) {
                    ForEach(DestinationMode.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Optional Note")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    TextEditor(text: $note)
                        .frame(minHeight: 90, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.surfaceWhite06)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.surfaceWhite10, lineWidth: 1)
                                )
                        )
                }

                if isLoading {
                    VStack(spacing: 10) {
                        ProgressView().tint(AppColors.accentColor)
                        Text("Loading destinations...")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let loadError {
                    UnifiedEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Unable to load destinations",
                        subtitle: loadError
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    destinationList
                }

                Button {
                    Task { await sendMarkerShare() }
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Share Marker")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accentColor)
                .disabled(isSending || !hasSelection || isLoading || loadError != nil)
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 16)
            .navigationTitle("Share Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.accentColor)
                }
            }
            .background(AppColors.sheetBackground.ignoresSafeArea())
            .task { await loadDestinations() }
        }
    }

    @ViewBuilder
    private var destinationList: some View {
        if mode == .chatroom {
            if chatrooms.isEmpty {
                emptyDestination(icon: "number", text: "No chatrooms available")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(chatrooms) { chatroom in
                            destinationRow(
                                title: "#\(chatroom.name)",
                                subtitle: "\(chatroom.memberCount) members",
                                isSelected: selectedChatroomId == chatroom.id
                            ) {
                                selectedChatroomId = chatroom.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } else {
            if dmThreads.isEmpty {
                emptyDestination(icon: "person.2", text: "No DM threads available")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(dmThreads) { thread in
                            destinationRow(
                                title: thread.participant.displayName,
                                subtitle: "@\(thread.participant.username)",
                                isSelected: selectedThreadId == thread.id
                            ) {
                                selectedThreadId = thread.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var hasSelection: Bool {
        switch mode {
        case .chatroom:
            return selectedChatroomId != nil
        case .dm:
            return selectedThreadId != nil
        }
    }

    private func destinationRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.accentColor : AppColors.greyText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppColors.intentPickerPillFillSelected : AppColors.intentPickerPillFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? AppColors.accentColor.opacity(0.65) : AppColors.markerListCapsuleStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func emptyDestination(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.greyText.opacity(0.8))
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 22)
    }

    private func loadDestinations() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            loadError = "No guild selected"
            isLoading = false
            return
        }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            async let chatroomsTask = rlAppState.fetchCurrentGuildChatrooms()
            async let dmsTask = rlAppState.fetchCurrentGuildDMThreads()

            let (loadedChatrooms, loadedDms) = try await (chatroomsTask, dmsTask)
            chatrooms = loadedChatrooms.filter { $0.isActive && $0.canSendMessages }
            dmThreads = loadedDms.filter { !$0.isBlocked }
            selectedChatroomId = chatrooms.first?.id
            selectedThreadId = dmThreads.first?.id
            symbolTicker = try? await rlAppState.realApi.getSymbol(symbolId: marker.symbolId).ticker
        } catch {
            if error is CancellationError { return }
            loadError = RLUserFacingErrorMapper.message(from: error)
        }
    }

    private func sendMarkerShare() async {
        guard !isSending else { return }

        let targetChatroomId = selectedChatroomId
        let targetThreadId = selectedThreadId
        if mode == .chatroom, targetChatroomId == nil { return }
        if mode == .dm, targetThreadId == nil { return }

        isSending = true
        defer { isSending = false }

        let payload = MarkerSharePayloadV1(
            markerId: marker.id,
            symbolId: marker.symbolId,
            symbolTicker: symbolTicker,
            timeframe: marker.timeframe,
            candleTimestamp: marker.candleTimestamp,
            markerType: marker.intent.rawValue,
            intent: marker.intent.rawValue,
            selectedEmoji: marker.selectedEmoji,
            alertSeverity: marker.alertSeverity?.toBackendString()
        )
        let content = MarkerShareCodec.buildMessage(note: note, payload: payload)

        do {
            switch mode {
            case .chatroom:
                guard let targetChatroomId else { return }
                _ = try await rlAppState.sendChatroomMessage(chatroomId: targetChatroomId, content: content)
            case .dm:
                guard let targetThreadId else { return }
                _ = try await rlAppState.sendDMMessage(threadId: targetThreadId, content: content)
            }

            rlAppState.showSuccess("Marker shared")
            dismiss()
        } catch {
            rlAppState.showError(error, title: "Failed to Share Marker", style: .toast)
        }
    }
}

// MARK: - Embedded Marker Chat Tab

struct EmbeddedMarkerChatTabView: View {
    let marker: ChartMarkerUI
    @ObservedObject var markerManager: MarkerManager
    @Binding var selectedDetent: PresentationDetent
    let onExitChat: () -> Void

    @State private var comments: [RLMarkerCommentDTO] = []

    init(
        marker: ChartMarkerUI,
        markerManager: MarkerManager,
        selectedDetent: Binding<PresentationDetent>,
        onExitChat: @escaping () -> Void
    ) {
        self.marker = marker
        self.markerManager = markerManager
        self._selectedDetent = selectedDetent
        self.onExitChat = onExitChat
        _comments = State(initialValue: marker.comments)
    }

    var body: some View {
        CommentsView(
            marker: marker,
            comments: $comments,
            markerManager: markerManager,
            selectedDetent: $selectedDetent,
            onExitChat: onExitChat
        )
        .onReceive(markerManager.$markers) { updatedMarkers in
            guard let updated = updatedMarkers.first(where: { $0.id == marker.id }) else { return }
            if updated.comments != comments {
                comments = updated.comments
            }
        }
        .onAppear {
            syncStateWithLatestMarker()
        }
    }

    private func syncStateWithLatestMarker() {
        guard let updated = markerManager.markers.first(where: { $0.id == marker.id }) else { return }
        comments = updated.comments
    }
}

// MARK: - Comments View (Using RLMarkerCommentDTO)

struct CommentsView: View {
    let marker: ChartMarkerUI
    @Binding var comments: [RLMarkerCommentDTO]
    @ObservedObject var markerManager: MarkerManager
    let onExitChat: () -> Void
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var chatSurfaceOverlayCoordinator: ChatSurfaceOverlayCoordinator
    
    @State private var commentText: String = ""
    @State private var replyDraft: ChatReplyDraft? = nil
    @State private var isSendingComment: Bool = false
    @FocusState private var isCommentInputFocused: Bool
    @State private var showReportCommentReasonSheet: Bool = false
    @State private var commentToReport: RLMarkerCommentDTO? = nil
    @State private var selectedProfileMember: RLGuildMemberDTO? = nil
    @State private var reactionReactorsState = ChatReactionReactorsState()
    @State private var localSendScrollSignal = ChatLocalSendScrollSignal()
    
    @Binding var selectedDetent: PresentationDetent
    
    init(
        marker: ChartMarkerUI,
        comments: Binding<[RLMarkerCommentDTO]>,
        markerManager: MarkerManager,
        selectedDetent: Binding<PresentationDetent>,
        onExitChat: @escaping () -> Void
    ) {
        self.marker = marker
        self._comments = comments
        self.markerManager = markerManager
        self._selectedDetent = selectedDetent
        self.onExitChat = onExitChat
    }

    private var liveMarker: ChartMarkerUI {
        markerManager.markers.first(where: { $0.id == marker.id }) ?? marker
    }

    private var sortedComments: [RLMarkerCommentDTO] {
        comments.sorted { $0.timestamp < $1.timestamp }
    }

    private var participantCount: Int {
        let participantIds = Set(comments.map { $0.author.userId }).union([liveMarker.author.userId])
        return max(1, participantIds.count)
    }

    private var actionPanelVisibility: Binding<Bool> {
        Binding(
            get: { chatSurfaceOverlayCoordinator.isComposerActionPanelVisible },
            set: { isVisible in
                chatSurfaceOverlayCoordinator.setComposerActionPanelVisible(isVisible)
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            markerChatHeader

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    if sortedComments.isEmpty {
                        ChatEmptyStateView(
                            icon: "bubble.left.and.bubble.right",
                            title: "Start the marker chat",
                            subtitle: "Be the first to comment on this \(liveMarker.intent.displayName.lowercased()) marker."
                        )
                        .padding(.top, 60)
                        Color.clear
                            .frame(height: 0)
                            .id("bottom")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedComments) { comment in
                                MarkerCommentRow(
                                    comment: comment,
                                    onReply: { replyDraft = ChatReplyDraft(message: comment) },
                                    onReactionSelected: { emoji in
                                        Task { await toggleReaction(comment, emoji: emoji) }
                                    },
                                    onVisibleReactionTap: {
                                        presentReactionReactors(comment, reactions: comment.reactions)
                                    },
                                    onAuthorTap: { member in
                                        selectedProfileMember = member
                                    },
                                    onReport: {
                                        commentToReport = comment
                                        showReportCommentReasonSheet = true
                                    },
                                    onDelete: comment.canDelete ? {
                                        handleDeleteComment(comment)
                                    } : nil
                                )
                                .id(comment.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                        Color.clear
                            .frame(height: 18)
                            .id("bottom")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isCommentInputFocused = false
                    chatSurfaceOverlayCoordinator.dismissAll()
                }
                .onChange(of: comments.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                    }
                }
                .onChange(of: isCommentInputFocused) { focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                            }
                        }
                    }
                }
                .onChange(of: localSendScrollSignal.revision) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                    }
                }
            }
        }
        .background(ChatBackground())
        .overlay {
            ChatSurfaceOverlayHost(
                messages: sortedComments,
                reactorsState: reactionReactorsState,
                onQuickReactionSelected: { comment, emoji in
                    Task { await toggleReaction(comment, emoji: emoji) }
                },
                onReply: { comment in
                    replyDraft = ChatReplyDraft(message: comment)
                },
                onEdit: nil,
                onDelete: { comment in
                    handleDeleteComment(comment)
                },
                onCopy: { _ in
                    rlAppState.showSuccess(RLUserFacingCopy.text(.successCopiedToClipboard))
                },
                onReport: { comment in
                    commentToReport = comment
                    showReportCommentReasonSheet = true
                },
                onFetchReactors: { comment, emoji in
                    fetchReactorsForEmoji(commentId: comment.id, emoji: emoji)
                }
            )
        }
        .keyboardPinnedBottomInset(mode: .chat, background: AnyView(ChatChromeBarBackground())) {
            MarkerCommentInputFooter(
                commentText: $commentText,
                replyDraft: $replyDraft,
                isInputFocused: _isCommentInputFocused,
                isSending: isSendingComment,
                onSend: { payload in
                    await handleAddComment(payload)
                },
                selectedDetent: $selectedDetent,
                isActionPanelVisible: actionPanelVisibility,
                onBack: onExitChat
            )
        }
        .toolbarBackground(AppColors.sheetBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showReportCommentReasonSheet) {
            if let comment = commentToReport {
                ReportReasonSheet(
                    title: "Why are you reporting this comment?",
                    includeScam: false,
                    onReasonSelected: { reason in
                        handleReportComment(comment, reason: reason)
                        showReportCommentReasonSheet = false
                        commentToReport = nil
                    },
                    onCancel: {
                        showReportCommentReasonSheet = false
                        commentToReport = nil
                    }
                )
            }
        }
        .sheet(item: $selectedProfileMember) { member in
            GuildUserDetailViewRL(member: member)
                .environmentObject(rlAppState)
        }
    }

    private var markerChatHeader: some View {
        ChatSurfaceHeader(horizontalPadding: 16, topPadding: 20, bottomPadding: 16) {
            HStack(spacing: 12) {
                UnifiedMarkerBadge(
                    intent: liveMarker.intent,
                    alertSeverity: liveMarker.alertSeverity,
                    sizeToken: .medium,
                    emoji: liveMarker.intent == .reaction ? liveMarker.selectedEmoji : nil
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(liveMarker.intent.displayName) Chat")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryForeground)

                    Text("@\(liveMarker.author.username) • \(liveMarker.timeframe.uppercased()) • \(comments.count) comments")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryForeground)
                }

                Spacer()

                ActiveUsersPill(count: participantCount)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleAddComment(_ payload: ChatComposerPayload) async -> Bool {
        let trimmed = payload.text
        guard !trimmed.isEmpty || !payload.attachments.isEmpty || payload.replyDraft != nil else {
            return false
        }

        HapticFeedback.light.trigger()
        
        isSendingComment = true
        isCommentInputFocused = false

        if !payload.attachments.isEmpty {
            Task {
                await sendCommentWithAttachments(caption: trimmed, attachments: payload.attachments)
                isSendingComment = false
            }
            return true
        }

        // Add comment through marker manager (optimistic update happens there)
        Task {
            await markerManager.addComment(
                markerId: marker.id,
                content: trimmed,
                replyToMessageId: payload.replyDraft?.messageId
            )
            isSendingComment = false
            replyDraft = nil
            localSendScrollSignal.commit()
        }
        return true
    }

    private func sendCommentWithAttachments(caption: String, attachments: [ChatAttachmentDraft]) async {
        guard let guildId = rlAppState.currentGuild?.id else { return }

        do {
            var isFirstMessage = true
            for attachment in attachments {
                let upload = try await rlAppState.realApi.uploadMarkerCommentAttachment(
                    guildId: guildId,
                    markerId: marker.id,
                    fileData: attachment.data,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType
                )

                let content: String
                if isFirstMessage {
                    content = caption.isEmpty ? attachment.filename : caption
                } else {
                    content = attachment.filename
                }
                await markerManager.addComment(
                    markerId: marker.id,
                    content: content,
                    attachmentUrl: upload.attachmentUrl,
                    attachmentType: upload.attachmentType,
                    attachmentName: upload.attachmentName,
                    replyToMessageId: replyDraft?.messageId
                )
                localSendScrollSignal.commit()
                isFirstMessage = false
            }
            replyDraft = nil
        } catch {
            rlAppState.showError(error, title: "Failed to Send Attachment", style: .toast)
        }
    }

    private func toggleReaction(_ comment: RLMarkerCommentDTO, emoji: String) async {
        do {
            try await markerManager.toggleCommentReaction(
                markerId: marker.id,
                commentId: comment.id,
                emoji: emoji
            )
        } catch {
            rlAppState.showError(error, title: "Failed to Update Reaction", style: .toast)
        }
    }

    private func presentReactionReactors(_ comment: RLMarkerCommentDTO, reactions: [RLMessageReactionDTO]) {
        chatSurfaceOverlayCoordinator.presentReactionReactors(for: comment.id, reactions: reactions)

        if reactionReactorsState.messageID != comment.id {
            reactionReactorsState = ChatReactionReactorsState(messageID: comment.id)
        }
    }

    private func fetchReactorsForEmoji(commentId: UUID, emoji: String) {
        if reactionReactorsState.messageID == commentId,
           reactionReactorsState.response(for: emoji) != nil {
            return
        }

        reactionReactorsState.loadingEmojis.insert(emoji)

        Task {
            do {
                let response = try await markerManager.fetchCommentReactionReactors(
                    markerId: marker.id,
                    commentId: commentId,
                    emoji: emoji
                )
                await MainActor.run {
                    reactionReactorsState.responses[emoji] = response
                    reactionReactorsState.loadingEmojis.remove(emoji)
                }
            } catch {
                await MainActor.run {
                    reactionReactorsState.loadingEmojis.remove(emoji)
                    rlAppState.showError(error, title: "Failed to Load Reactions", style: .toast)
                }
            }
        }
    }
    
    private func handleDeleteComment(_ comment: RLMarkerCommentDTO) {
        HapticFeedback.warning.trigger()
        
        withAnimation(.easeOut(duration: 0.2)) {
            comments.removeAll { $0.id == comment.id }
        }

        Task {
            let success = await markerManager.deleteComment(markerId: marker.id, commentId: comment.id)
            if success {
                rlAppState.showSuccess("Comment deleted")
                return
            }

            withAnimation(.easeOut(duration: 0.2)) {
                comments.append(comment)
                comments.sort { $0.timestamp < $1.timestamp }
            }
            rlAppState.showError(title: "Failed to Delete Comment", message: "Please try again.", style: .toast)
        }
    }
    
    private func handleReportComment(_ comment: RLMarkerCommentDTO, reason: String) {
        HapticFeedback.medium.trigger()
        Task {
            guard let guildId = rlAppState.currentGuild?.id else { return }
            do {
                _ = try await rlAppState.realApi.reportMarkerComment(
                    guildId: guildId,
                    markerId: marker.id,
                    commentId: comment.id,
                    reason: reason
                )
                rlAppState.showSuccess(RLUserFacingCopy.text(.successReportSubmitted))
            } catch {
                rlAppState.showError(error, title: "Failed to Report", style: .toast)
            }
        }
    }
}

// MARK: - Marker Comment Input Footer

struct MarkerCommentInputFooter: View {
    @Binding var commentText: String
    @Binding var replyDraft: ChatReplyDraft?
    @FocusState var isInputFocused: Bool
    let isSending: Bool
    let onSend: @MainActor (ChatComposerPayload) async -> Bool
    @Binding var selectedDetent: PresentationDetent
    var isActionPanelVisible: Binding<Bool>? = nil
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        ChatInputFooter(
            messageText: $commentText,
            replyDraft: $replyDraft,
            placeholder: "Add a comment...",
            isSending: isSending,
            onSend: onSend,
            selectedDetent: $selectedDetent,
            expandedDetent: .fraction(0.9),
            leadingAccessory: onBack.map { onBack in
                AnyView(
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.whiteText.opacity(0.9))
                            .frame(width: 40, height: 40)
                            .background(AppColors.gradientBackgroundDark)
                            .clipShape(Circle())
                            .shadow(color: AppColors.surfaceWhite30, radius: 1, x: 0, y: 0)
                    }
                )
            },
            isActionPanelVisible: isActionPanelVisible
        )
    }
}

// MARK: - Marker Comment Row (Using RLMarkerCommentDTO)

struct MarkerCommentRow: View {
    let comment: RLMarkerCommentDTO
    let onReply: () -> Void
    let onReactionSelected: (String) -> Void
    let onVisibleReactionTap: () -> Void
    var onAuthorTap: ((RLGuildMemberDTO) -> Void)? = nil
    let onReport: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @EnvironmentObject var rlAppState: RLAppState
    
    var body: some View {
        RLChatMessageBubble(
            message: comment,
            context: .markerComment,
            onAvatarTap: { onAuthorTap?(comment.author) },
            onAuthorTap: { onAuthorTap?(comment.author) },
            onDelete: onDelete,
            onReport: !comment.isCurrentUserMessage ? onReport : nil,
            onCopy: { rlAppState.showSuccess(RLUserFacingCopy.text(.successCopiedToClipboard)) },
            onReply: onReply,
            onToggleReaction: onReactionSelected,
            onVisibleReactionTap: onVisibleReactionTap
        )
    }
}

// MARK: - Marker Detail Header (Using ChartMarkerUI)

struct MarkerDetailHeaderView: View {
    let marker: ChartMarkerUI
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let isOwner: Bool
    var showsActionRow: Bool = false
    var onAuthorTap: (() -> Void)? = nil
    var onLike: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var glowPulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero gradient zone
            ZStack(alignment: .bottomLeading) {
                // Multi-stop gradient background
                LinearGradient(
                    stops: [
                        .init(color: marker.intent.color.opacity(0.28), location: 0.0),
                        .init(color: marker.intent.color.opacity(0.12), location: 0.45),
                        .init(color: AppColors.sheetBackground, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 190)

                // Hero content overlaid on gradient
                VStack(alignment: .leading, spacing: 10) {
                    // Intent icon in glowing circle
                    HStack(spacing: 14) {
                        ZStack {
                            // Glow ring
                            Circle()
                                .fill(marker.intent.color.opacity(0.15))
                                .frame(width: 52, height: 52)
                                .blur(radius: 8)
                                .scaleEffect(glowPulse ? 1.15 : 1.0)

                            UnifiedMarkerBadge(
                                intent: marker.intent,
                                alertSeverity: marker.alertSeverity,
                                sizeToken: .large,
                                emoji: marker.intent == .reaction ? marker.selectedEmoji : nil,
                                isSelected: true
                            )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            // Intent label
                            Text(marker.intent.displayName.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(marker.intent.color)
                                .tracking(1.5)

                            // Title
                            Text(marker.title ?? marker.intent.displayName)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColors.primaryForeground)
                                .lineLimit(2)
                        }

                        Spacer()

                        // Tracking state pill
                        if let trackingState = marker.trackingState {
                            TrackingStatePill(state: trackingState)
                        }
                    }

                    // Confidence stars (if applicable)
                    if let confidence = marker.confidence, confidence > 0 {
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= confidence ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundColor(star <= confidence ? Color(hex: "#FBBF24") ?? .yellow : AppColors.greyText.opacity(0.4))
                            }
                        }
                    }

                    // Author row
                    if let onAuthorTap {
                        Button(action: onAuthorTap) {
                            authorRowContent
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        authorRowContent
                    }

                    // Note (if present)
                    if let note = marker.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.85))
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var authorRowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            ChatAvatar(
                initials: marker.author.initials,
                avatarURL: marker.author.avatarUrl,
                isOnline: marker.author.isOnline,
                size: 38
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    if marker.author.isBlocked {
                        Image(systemName: "nosign")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.bearCandleRed)
                    }

                    Text(marker.author.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(marker.author.isBlocked ? AppColors.greyText : AppColors.whiteText)

                    if marker.author.isFriend {
                        Image(systemName: "person.crop.circle")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(marker.author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                            .padding(.leading, 2)
                    }
                }

                UnifiedRoleBadge(
                    member: marker.author,
                    showReputation: true,
                    fontSize: .caption,
                    iconSize: .caption2
                )
            }

            Spacer()

            Text(marker.createdAtFormatted)
                .font(.caption2)
                .foregroundColor(AppColors.greyText)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Marker Info Content (Using ChartMarkerUI)

/// Timeline node model for setup tracker — extracted from ViewBuilder scope.
private struct SetupTimelineNode: Identifiable {
    let id = UUID()
    let state: RLTrackingState
    let icon: String
    var overrideLabel: String? = nil
    var overrideColor: Color? = nil
}

struct MarkerInfoContent: View {
    let marker: ChartMarkerUI
    var currentPrice: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // For setup markers, skip the generic price card — LevelLadderCard shows Entry/TP/SL
            if marker.intent != .setup {
                infoCard {
                    VStack(spacing: 8) {
                        infoRow(
                            icon: "chart.line.uptrend.xyaxis",
                            label: "Price Level",
                            value: String(format: "%.5f", marker.price),
                            valueColor: marker.displayColor
                        )

                        if let linePrice = marker.horizontalLinePrice {
                            Divider()
                                .background(AppColors.whiteText.opacity(0.1))

                            infoRow(
                                icon: "line.3.horizontal",
                                label: "Level Price",
                                value: String(format: "%.5f", linePrice),
                                valueColor: marker.displayColor
                            )
                        }
                    }
                }
            }

            // Created date as a subtle caption
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.greyText)
                Text(marker.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }

            componentSummarySection

            // Type-specific content
            typeSpecificSection
        }
    }

    @ViewBuilder
    private var componentSummarySection: some View {
        let levelRows = marker.components.filter { $0.componentTypeEnum?.isLevel == true }
        let drawingRows = marker.components.filter { $0.componentTypeEnum?.isDrawing == true }
        let indicatorRows = marker.components.filter { $0.componentTypeEnum == .indicator }
        let linkRows = marker.components.filter { $0.componentTypeEnum == .linkURL }

        if !levelRows.isEmpty || !drawingRows.isEmpty || !indicatorRows.isEmpty || !linkRows.isEmpty {
            let parts: [String] = [
                levelRows.isEmpty ? nil : "\(levelRows.count) level\(levelRows.count == 1 ? "" : "s")",
                drawingRows.isEmpty ? nil : "\(drawingRows.count) drawing\(drawingRows.count == 1 ? "" : "s")",
                indicatorRows.isEmpty ? nil : "\(indicatorRows.count) indicator\(indicatorRows.count == 1 ? "" : "s")",
                linkRows.isEmpty ? nil : "\(linkRows.count) link\(linkRows.count == 1 ? "" : "s")"
            ].compactMap { $0 }

            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(marker.intent.color.opacity(0.9))
                Text(parts.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.listCardSecondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.markerListCapsuleFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                    )
            )
        }
    }

    private func formatPrice(_ price: Double?) -> String? {
        guard let price else { return nil }
        return String(format: "%.5f", price)
    }

    private var newsURL: String? {
        for component in marker.components where component.componentTypeEnum == .linkURL {
            guard case let .link(payload) = component.payload else { continue }
            let trimmed = payload.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch marker.intent {
        case .setup:
            VStack(spacing: 16) {
                if let outcome = MarkerPredictionProgress.outcomeDescription(for: marker.marker) {
                    setupOutcomeSection(outcome)
                }

                // Live progress strip for active setups
                if let state = marker.trackingState, state.isLive,
                   let entryPrice = marker.entryPrice ?? marker.horizontalLinePrice,
                   let tpPrice = marker.targetPrice,
                   let slPrice = marker.stopLossPrice,
                   let price = currentPrice,
                   let metrics = LiveSetupMetrics.compute(
                       entryPrice: entryPrice,
                       stopLossPrice: slPrice,
                       targetPrice: tpPrice,
                       currentPrice: price
                   ) {
                    UnifiedSetupProgressStrip(
                        metrics: metrics,
                        size: .detail,
                        formatPrice: { String(format: "%.5f", $0) }
                    )
                }

                // Level Ladder Card (replaces old prediction section for cleaner UX)
                LevelLadderCard(
                    entryPrice: marker.entryPrice ?? marker.horizontalLinePrice ?? marker.price,
                    tpPrice: marker.targetPrice,
                    slPrice: marker.stopLossPrice,
                    intentColor: marker.intent.color
                )
                setupTrackerTimeline
            }
        case .alert:
            alertSection
        case .news:
            if let newsURL {
                NewsLinkPreviewCard(
                    urlString: newsURL,
                    accentColor: marker.intent.color
                )
            }
        case .reaction:
            emojiSection
        case .poll:
            pollSection
        default:
            EmptyView()
        }
    }

    private func setupOutcomeSection(_ outcome: SetupOutcome) -> some View {
        infoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: outcome.displayIcon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(outcome.state.color)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Setup Outcome")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.greyText)
                        Text(outcome.displayLabel)
                            .font(.headline.weight(.bold))
                            .foregroundColor(AppColors.primaryForeground)
                    }

                    Spacer()

                    if let pnl = outcome.pnl {
                        Text(String(format: "%+.2f%%", pnl))
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(pnl >= 0 ? AppColors.markerPositiveForeground : AppColors.statusNegative85)
                    }
                }

                if let repText = outcome.repChangeText {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.caption)
                                .foregroundColor(marker.intent.color.opacity(0.95))
                            Text("Rep")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                        }
                        Spacer()
                        Text(repText)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(
                                (outcome.guildRepDelta ?? 0) >= 0
                                    ? AppColors.markerPositiveForeground
                                    : AppColors.statusNegative85
                            )
                    }
                }

                // Merged trigger price + resolved time into a single compact row
                let triggerText = outcome.triggerPrice.map { formatPrice($0) ?? "" }
                let resolvedText = outcome.triggeredAtFormatted
                let mergedParts = [triggerText.map { "Hit \($0)" }, resolvedText].compactMap { $0 }
                if !mergedParts.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "scope")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.greyText)
                        Text(mergedParts.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(AppColors.listCardSecondaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var setupTrackerTimeline: some View {
        let current = marker.trackingState ?? (marker.trackingEnabled ? .armed : .draft)

        let baseNodes: [SetupTimelineNode] = [
            SetupTimelineNode(state: .draft, icon: "doc.text"),
            SetupTimelineNode(state: .armed, icon: "bolt.fill"),
            SetupTimelineNode(state: .active, icon: "chart.line.uptrend.xyaxis"),
        ]

        let resolvedNode: SetupTimelineNode? = {
            switch current {
            case .tpHit:
                return SetupTimelineNode(state: .tpHit, icon: "checkmark.circle.fill", overrideLabel: "TP Hit", overrideColor: AppColors.markerPositiveForeground)
            case .slHit:
                return SetupTimelineNode(state: .slHit, icon: "xmark.circle.fill", overrideLabel: "SL Hit", overrideColor: .red)
            case .expired:
                return SetupTimelineNode(state: .expired, icon: "clock.badge.exclamationmark", overrideLabel: "Expired", overrideColor: .gray)
            default:
                return SetupTimelineNode(state: .tpHit, icon: "questionmark.circle", overrideLabel: "Resolved", overrideColor: AppColors.greyText)
            }
        }()

        let allNodes = baseNodes + (resolvedNode.map { [$0] } ?? [])

        VStack(spacing: 0) {
            Divider()
                .background(AppColors.whiteText.opacity(0.08))
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                ForEach(Array(allNodes.enumerated()), id: \.element.id) { index, node in
                    let nodeState = node.state
                    let isCurrent = nodeState == current
                    let isPast = nodeOrderIndex(nodeState) < nodeOrderIndex(current)
                    let nodeColor = node.overrideColor ?? nodeState.color
                    let nodeLabel = node.overrideLabel ?? nodeState.displayName

                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? nodeColor : isPast ? nodeColor.opacity(0.4) : AppColors.whiteText.opacity(0.1))
                                .frame(width: 22, height: 22)
                            Image(systemName: node.icon)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isCurrent ? AppColors.onAccentForeground : isPast ? AppColors.surfaceWhite70 : AppColors.greyText.opacity(0.5))
                        }
                        Text(nodeLabel)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(isCurrent ? nodeColor : isPast ? nodeColor.opacity(0.6) : AppColors.greyText.opacity(0.5))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)

                    if index < allNodes.count - 1 {
                        Rectangle()
                            .fill(isPast ? nodeColor.opacity(0.4) : AppColors.whiteText.opacity(0.1))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -8)
                    }
                }
            }
        }
    }

    /// Maps tracking states to a numeric order for timeline comparison.
    private func nodeOrderIndex(_ state: RLTrackingState) -> Int {
        switch state {
        case .draft: return 0
        case .armed: return 1
        case .active: return 2
        case .tpHit, .slHit, .expired: return 3
        }
    }

    @ViewBuilder
    private var alertSection: some View {
        if let severity = marker.alertSeverity {
            infoCard {
                HStack {
                    Circle().fill(severity.color).frame(width: 12, height: 12)
                    Text("Severity: \(severity.rawValue)")
                        .font(.subheadline).fontWeight(.medium).foregroundColor(AppColors.whiteText)
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var emojiSection: some View {
        if let emoji = marker.selectedEmoji {
            infoCard { HStack { Text(emoji).font(.system(size: 44)); Spacer() } }
        }
    }
    
    @ViewBuilder
    private var pollSection: some View {
        if let question = marker.resolvedPollQuestion, let options = marker.pollOptions {
            infoCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(question).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                    ForEach(options) { option in
                        PollOptionRow(
                            option: option,
                            totalVotes: marker.totalPollVotes,
                            hasVoted: option.hasVoted
                        )
                    }
                }
            }
        }
    }
    
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.whiteText.opacity(0.05))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1))
    }
    
    private func infoRow(icon: String, label: String, value: String, valueColor: Color = AppColors.whiteText) -> some View {
        HStack {
            Image(systemName: icon).font(.subheadline).foregroundColor(AppColors.greyText).frame(width: 20)
            Text(label).font(.subheadline).foregroundColor(AppColors.greyText)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(valueColor)
        }
    }
}

// MARK: - Floating Engagement Bar

/// Floating capsule bar at the bottom of the marker detail view.
/// Contains like, comment count, share, and more menu actions.
struct FloatingEngagementBar: View {
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let isOwner: Bool
    let intentColor: Color
    let onLike: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            // Like button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    likeScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        likeScale = 1.0
                    }
                }
                onLike()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isLiked ? AppColors.markerHeartTint : AppColors.listCardBodyText)
                        .scaleEffect(likeScale)
                    Text("\(likeCount)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isLiked ? AppColors.markerHeartTint : AppColors.listCardBodyText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isLiked ? AppColors.markerHeartBackground : AppColors.symbolDetailCardFill)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Comment count
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.listCardTertiaryText)
                Text("\(commentCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.listCardContextSummaryFallback)
            }

            Spacer()

            // Share button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.listCardBodyText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.symbolDetailCardFill))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // More menu
            Menu {
                if isOwner {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Marker", systemImage: "trash")
                    }
                } else {
                    Button(action: onReport) {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.listCardBodyText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.symbolDetailCardFill))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(AppColors.chartPanelBackgroundInset.opacity(0.95))
                .overlay(
                    Capsule()
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                )
                .shadow(color: AppColors.surfaceBlack40, radius: 12, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Level Ladder Card

/// Visual mini price ladder showing Entry, TP, and SL levels for setup markers.
/// Includes proportional vertical positioning and R:R ratio badge.
struct LevelLadderCard: View {
    let entryPrice: Double
    let tpPrice: Double?
    let slPrice: Double?
    let intentColor: Color

    private var rrRatio: Double? {
        guard let tp = tpPrice, let sl = slPrice else { return nil }
        let reward = abs(tp - entryPrice)
        let risk = abs(sl - entryPrice)
        guard risk > 0 else { return nil }
        return reward / risk
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Price Levels")
                    .font(.headline)
                    .foregroundColor(AppColors.primaryForeground)
                Spacer()
                if let rr = rrRatio {
                    Text(String(format: "R:R %.2f", rr))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.primaryForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.panelFillEmphasis)
                                .overlay(Capsule().stroke(AppColors.surfaceWhite15, lineWidth: 1))
                        )
                }
            }

            // Mini price ladder
            VStack(spacing: 8) {
                if let tp = tpPrice {
                    ladderRow(
                        label: "Take Profit",
                        shortLabel: "TP",
                        price: tp,
                        color: RLComponentType.levelTp.color,
                        percentFromEntry: abs(tp - entryPrice) / entryPrice * 100,
                        isProfit: true
                    )
                }

                ladderRow(
                    label: "Entry",
                    shortLabel: "ENT",
                    price: entryPrice,
                    color: RLComponentType.levelEntry.color,
                    percentFromEntry: nil,
                    isProfit: nil
                )

                if let sl = slPrice {
                    ladderRow(
                        label: "Stop Loss",
                        shortLabel: "SL",
                        price: sl,
                        color: RLComponentType.levelSl.color,
                        percentFromEntry: abs(sl - entryPrice) / entryPrice * 100,
                        isProfit: false
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.symbolSheetGroupedPanelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.markerListCapsuleStroke, lineWidth: 1)
                )
        )
    }

    private func ladderRow(label: String, shortLabel: String, price: Double, color: Color, percentFromEntry: Double?, isProfit: Bool?) -> some View {
        HStack(spacing: 10) {
            // Colored dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Label
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)

            Spacer()

            // Percentage badge
            if let pct = percentFromEntry, let profit = isProfit {
                Text(String(format: "%@%.2f%%", profit ? "+" : "-", pct))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(profit ? AppColors.markerPositiveForegroundMuted : AppColors.statusNegative80)
                    .padding(.trailing, 4)
            }

            // Price
            Text(String(format: "%.5f", price))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Poll Option Row (Using PollOptionDTO)

struct PollOptionRow: View {
    let option: RLPollOptionDTO
    let totalVotes: Int
    let hasVoted: Bool
    
    private var percentage: Double {
        option.votePercentage(totalVotes: totalVotes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.text).font(.subheadline).fontWeight(hasVoted ? .semibold : .regular)
                    .foregroundColor(hasVoted ? AppColors.accentColor : AppColors.whiteText)
                Spacer()
                Text("\(Int(percentage))%").font(.caption).fontWeight(.semibold).foregroundColor(AppColors.greyText)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(AppColors.whiteText.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(hasVoted ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                        .frame(width: geometry.size.width * (percentage / 100), height: 6)
                }
            }.frame(height: 6)
        }.padding(.vertical, 6)
    }
}

extension RLPollOptionDTO {
    func votePercentage(totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return (Double(voteCount) / Double(totalVotes)) * 100
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
