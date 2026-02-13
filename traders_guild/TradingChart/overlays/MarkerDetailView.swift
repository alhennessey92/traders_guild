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
    @ObservedObject var markerManager: MarkerManager
    
    let marker: ChartMarkerUI
    @Binding var selectedDetent: PresentationDetent
    
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var comments: [RLMarkerCommentDTO] = []
    @State private var showComments: Bool = false
    @State private var showDeleteMarkerConfirmation: Bool = false
    @State private var showReportConfirmation: Bool = false
    
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
                    // Header with gradient
                    MarkerDetailHeaderView(
                        marker: marker,
                        isLiked: isLiked,
                        likeCount: likeCount,
                        commentCount: comments.count
                    )
                    
                    // Info content
                    ScrollView(.vertical, showsIndicators: false) {
                        MarkerInfoContent(marker: marker)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 20)
                    }
                    
                    Divider()
                    
                    // Footer
                    MarkerDetailFooterView(
                        marker: marker,
                        isLiked: $isLiked,
                        likeCount: $likeCount,
                        isOwner: marker.isCurrentUserMarker,
                        showComments: $showComments,
                        onLike: handleLike,
                        onShare: handleShare,
                        onReport: { showReportConfirmation = true },
                        onDelete: { showDeleteMarkerConfirmation = true }
                    )
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
                    .padding(.top, 20)
                    .padding(.trailing, 20)
            }
            .alert("Delete Marker", isPresented: $showDeleteMarkerConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    handleDelete()
                }
            } message: {
                Text("Are you sure you want to delete this marker? This action cannot be undone.")
            }
            .alert("Report Marker", isPresented: $showReportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Report", role: .destructive) {
                    handleReport()
                }
            } message: {
                Text("Report this marker as inappropriate or misleading?")
            }
            .navigationDestination(isPresented: $showComments) {
                CommentsView(
                    marker: marker,
                    comments: $comments,
                    markerManager: markerManager,
                    selectedDetent: $selectedDetent
                )
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
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
        print("Share marker: \(marker.id)")
    }
    
    private func handleReport() {
        HapticFeedback.medium.trigger()
        Task {
            guard let guildId = rlAppState.currentGuild?.id else { return }
            do {
                _ = try await rlAppState.realApi.reportMarker(
                    guildId: guildId,
                    markerId: marker.id,
                    reason: "inappropriate"
                )
                rlAppState.showSuccess("Marker reported. Thank you for your feedback.")
            } catch {
                rlAppState.showError(error, title: "Failed to Report", style: .toast)
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
}

// MARK: - Comments View (Using RLMarkerCommentDTO)

struct CommentsView: View {
    let marker: ChartMarkerUI
    @Binding var comments: [RLMarkerCommentDTO]
    @ObservedObject var markerManager: MarkerManager
    @EnvironmentObject var rlAppState: RLAppState
    
    @State private var commentText: String = ""
    @State private var isSendingComment: Bool = false
    @FocusState private var isCommentInputFocused: Bool
    
    @Binding var selectedDetent: PresentationDetent
    
    init(marker: ChartMarkerUI, comments: Binding<[RLMarkerCommentDTO]>, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
        self.marker = marker
        self._comments = comments
        self.markerManager = markerManager
        self._selectedDetent = selectedDetent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    if comments.isEmpty {
                        ChatEmptyStateView(
                            icon: "bubble.left.and.bubble.right",
                            title: "No comments yet",
                            subtitle: "Be the first to share your thoughts"
                        )
                        .padding(.top, 60)
                        Color.clear
                            .frame(height: 0)
                            .id("bottom")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(comments.sorted(by: { $0.timestamp < $1.timestamp })) { comment in
                                MarkerCommentRow(
                                    comment: comment,
                                    onReport: {
                                        handleReportComment(comment)
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
                        .padding(.bottom, 20)
                        Color.clear
                            .frame(height: 0)
                            .id("bottom")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isCommentInputFocused = false
                }
                .onChange(of: comments.count) { _ in
                    if let lastComment = comments.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastComment.id, anchor: UnitPoint.bottom)
                        }
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
                .onAppear {
                    if !comments.isEmpty, let lastComment = comments.last {
                        proxy.scrollTo(lastComment.id, anchor: UnitPoint.bottom)
                    } else {
                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
                    }
                }
                .background(ChatBackground())
            }
        }
        .safeAreaInset(edge: .bottom) {
            MarkerCommentInputFooter(
                commentText: $commentText,
                isInputFocused: _isCommentInputFocused,
                isSending: isSendingComment,
                onSend: handleAddComment,
                selectedDetent: $selectedDetent
            )
        }
        .background(AppColors.sheetBackground)
        .toolbarBackground(AppColors.sheetBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Actions
    
    private func handleAddComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        HapticFeedback.light.trigger()
        
        isSendingComment = true
        isCommentInputFocused = false
        
        commentText = ""

        // Add comment through marker manager (optimistic update happens there)
        Task {
            await markerManager.addComment(markerId: marker.id, content: trimmed)
            isSendingComment = false
        }
    }
    
    private func handleDeleteComment(_ comment: RLMarkerCommentDTO) {
        HapticFeedback.warning.trigger()
        
        withAnimation(.easeOut(duration: 0.2)) {
            comments.removeAll { $0.id == comment.id }
        }
        
        markerManager.deleteComment(markerId: marker.id, commentId: comment.id)
        rlAppState.showSuccess("Comment deleted")
    }
    
    private func handleReportComment(_ comment: RLMarkerCommentDTO) {
        HapticFeedback.medium.trigger()
        Task {
            guard let guildId = rlAppState.currentGuild?.id else { return }
            do {
                _ = try await rlAppState.realApi.reportChartChatMessage(
                    guildId: guildId,
                    messageId: comment.id,
                    reason: "inappropriate"
                )
                rlAppState.showSuccess("Comment reported. Thank you for your feedback.")
            } catch {
                rlAppState.showError(error, title: "Failed to Report", style: .toast)
            }
        }
    }
}

// MARK: - Marker Comment Input Footer

struct MarkerCommentInputFooter: View {
    @Binding var commentText: String
    @FocusState var isInputFocused: Bool
    let isSending: Bool
    let onSend: () -> Void
    @Binding var selectedDetent: PresentationDetent
    
    var body: some View {
        ChatInputFooter(
            messageText: $commentText,
            placeholder: "Add a comment...",
            isSending: isSending,
            onSend: onSend,
            selectedDetent: $selectedDetent
        )
    }
}

// MARK: - Marker Comment Row (Using RLMarkerCommentDTO)

struct MarkerCommentRow: View {
    let comment: RLMarkerCommentDTO
    let onReport: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @EnvironmentObject var rlAppState: RLAppState
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if comment.isCurrentUserMessage {
                Spacer()
            } else {
                // Avatar using embedded author info
                Button(action: {
                    // Could navigate to user profile
                }) {
                    ChatAvatar(
                        initials: comment.author.initials,
                        isOnline: comment.author.isOnline,
                        size: 32
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: comment.isCurrentUserMessage ? .trailing : .leading, spacing: 4) {
                // User info row (only for other users)
                if !comment.isCurrentUserMessage {
                    HStack(spacing: 2) {
                        Text(comment.author.username)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText.opacity(0.9))

                        UnifiedSeparatorDot(size: 3, opacity: 0.7)

                        UnifiedRoleBadge(
                            member: comment.author,
                            showReputation: true
                        )
                    }
                }
                
                // Message bubble
                Text(comment.content)
                    .font(.subheadline)
                    .foregroundColor(comment.isCurrentUserMessage ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        comment.isCurrentUserMessage ?
                        AppColors.accentDarkColor :
                        Color.gray.opacity(0.2)
                    )
                    .clipShape(ChatBubbleShape.bubbleShape(isFromCurrentUser: comment.isCurrentUserMessage))
                    .contextMenu {
                        // Delete (own comments only)
                        if let onDelete = onDelete {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        // Copy
                        Button {
                            UIPasteboard.general.string = comment.content
                            rlAppState.showSuccess("Copied to clipboard")
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        // Report (other users' comments)
                        if !comment.isCurrentUserMessage {
                            Divider()
                            Button(role: .destructive) {
                                onReport()
                            } label: {
                                Label("Report", systemImage: "exclamationmark.triangle")
                            }
                        }
                    }
                
                // Timestamp
                HStack(spacing: 4) {
                    Text(comment.timestampFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if comment.isEdited {
                        Text("• edited")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !comment.isCurrentUserMessage {
                Spacer()
            }
        }
        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this comment? This cannot be undone.")
        }
    }
}

// MARK: - Marker Detail Header (Using ChartMarkerUI)

struct MarkerDetailHeaderView: View {
    let marker: ChartMarkerUI
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main header row
            HStack(spacing: 15) {
                // Marker type icon with colored background
                ZStack {
                    Circle()
                        .fill(marker.type.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Circle()
                        .stroke(marker.type.color.opacity(0.4), lineWidth: 2)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: marker.type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(marker.type.color)
                }
                
                // Marker info
                VStack(alignment: .leading, spacing: 4) {
                    Text(marker.type.rawValue)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    
                    // User info row - now using embedded author DTO
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text(marker.author.initials.prefix(1))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.accentColor)
                            )
                        
                        Text(marker.author.username)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))

                        UnifiedSeparatorDot(size: 3, opacity: 0.5)

                        UnifiedRoleBadge(
                            member: marker.author,
                            showReputation: true
                        )

                        UnifiedSeparatorDot(size: 3, opacity: 0.5)

                        Text(marker.createdAtFormatted)
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                Spacer(minLength: 50)
            }
            
            // Note (if present)
            if let note = marker.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundColor(AppColors.whiteText.opacity(0.85))
                    .lineLimit(3)
                    .padding(.top, 4)
            }
            
            // Stats row
            HStack(spacing: 16) {
                // Likes
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(isLiked ? .red : AppColors.greyText)
                    Text("\(likeCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                // Comments
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                    Text("\(commentCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                Spacer()
                
                // Price badge
                Text(String(format: "%.5f", marker.price))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(marker.type.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(marker.type.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Divider()
        }
        .padding(.horizontal, 25)
        .padding(.top, 25)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [
                    marker.type.color.opacity(0.15),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Marker Detail Footer (Using ChartMarkerUI)

struct MarkerDetailFooterView: View {
    let marker: ChartMarkerUI
    @Binding var isLiked: Bool
    @Binding var likeCount: Int
    let isOwner: Bool
    @Binding var showComments: Bool
    let onLike: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void
    
    @State private var likeScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            // Like button - capsule with animation
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    likeScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        likeScale = 1.0
                    }
                }
                onLike()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isLiked ? .white : AppColors.whiteText.opacity(0.9))
                        .scaleEffect(likeScale)
                    
                    Text("\(likeCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isLiked ? .white : AppColors.whiteText.opacity(0.9))
                }
                .frame(minWidth: 80)
                .frame(height: 44)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(isLiked ? Color.red : AppColors.gradientBackgroundDark.opacity(0.3))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLiked ? Color.red.opacity(0.5) : AppColors.whiteText.opacity(0.2),
                            lineWidth: 1
                        )
                )
            }
            .compositingGroup()
            
            Spacer()
            
            // Share button
            DrawerActionButton(
                imageName: "square.and.arrow.up",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
                foregroundColor: AppColors.whiteText.opacity(0.9),
                strokeColor: AppColors.whiteText.opacity(0.2),
                strokeWidth: 1,
                action: onShare
            )
            
            // Comment button
            DrawerActionButton(
                imageName: "bubble.left",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
                foregroundColor: AppColors.whiteText.opacity(0.9),
                strokeColor: AppColors.whiteText.opacity(0.2),
                strokeWidth: 1,
                action: { showComments = true }
            )
            
            // Report or Delete button
            if isOwner {
                DrawerActionButton(
                    imageName: "trash",
                    backgroundColor: AppColors.bearCandleRed.opacity(0.15),
                    foregroundColor: AppColors.bearCandleRed,
                    strokeColor: AppColors.bearCandleRed.opacity(0.4),
                    strokeWidth: 1,
                    action: onDelete
                )
            } else {
                DrawerActionButton(
                    imageName: "flag",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.2),
                    strokeWidth: 1,
                    action: onReport
                )
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 16)
        .background(AppColors.sheetBackground)
        .compositingGroup()
    }
}

// MARK: - Marker Info Content (Using ChartMarkerUI)

struct MarkerInfoContent: View {
    let marker: ChartMarkerUI
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Price & Time info card
            infoCard {
                VStack(spacing: 12) {
                    infoRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Price Level",
                        value: String(format: "%.5f", marker.price),
                        valueColor: marker.type.color
                    )
                    
                    Divider()
                        .background(AppColors.whiteText.opacity(0.1))
                    
                    infoRow(
                        icon: "clock",
                        label: "Created",
                        value: marker.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    
                    if marker.type.hasHorizontalLine, let linePrice = marker.horizontalLinePrice {
                        Divider()
                            .background(AppColors.whiteText.opacity(0.1))
                        
                        infoRow(
                            icon: "minus",
                            label: "Line Price",
                            value: String(format: "%.5f", linePrice),
                            valueColor: marker.type.color
                        )
                    }
                }
            }
            
            // Type-specific content
            typeSpecificSection
        }
    }
    
    @ViewBuilder
    private var typeSpecificSection: some View {
        switch marker.type {
        case .predictionTarget:
            predictionSection
        case .alert:
            alertSection
        case .support, .resistance:
            levelSection
        case .trendline:
            trendlineSection
        case .pattern:
            patternSection
        case .indicator:
            indicatorSection
        case .emoji:
            emojiSection
        case .poll:
            pollSection
        case .entry, .exit, .stopLoss, .takeProfit:
            tradeSection
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var predictionSection: some View {
        if let targetPrice = marker.targetPrice {
            let entryPrice = marker.horizontalLinePrice ?? marker.price
            let percentChange = ((targetPrice - entryPrice) / entryPrice) * 100
            let isLong = targetPrice > entryPrice
            
            infoCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: isLong ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                        
                        Text(isLong ? "Long Prediction" : "Short Prediction")
                            .font(.headline)
                            .foregroundColor(AppColors.whiteText)
                        
                        Spacer()
                        
                        Text(String(format: "%+.2f%%", percentChange))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                    }
                    
                    Divider().background(AppColors.whiteText.opacity(0.1))
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry").font(.caption).foregroundColor(AppColors.greyText)
                            Text(String(format: "%.5f", entryPrice))
                                .font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                        }
                        Image(systemName: "arrow.right").font(.caption).foregroundColor(AppColors.greyText)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target").font(.caption).foregroundColor(AppColors.greyText)
                            Text(String(format: "%.5f", targetPrice))
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                        }
                        Spacer()
                    }
                }
            }
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
    private var levelSection: some View {
        infoCard {
            HStack {
                Image(systemName: marker.type == .support ? "arrow.down.to.line" : "arrow.up.to.line")
                    .font(.title3).foregroundColor(marker.type.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.type == .support ? "Support Level" : "Resistance Level")
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                    Text("Price may \(marker.type == .support ? "bounce up" : "reverse down") at this level")
                        .font(.caption).foregroundColor(AppColors.greyText)
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var trendlineSection: some View {
        if let direction = marker.trendlineDirection {
            let color: Color = direction == .up ? AppColors.bullCandleGreen : direction == .down ? AppColors.bearCandleRed : AppColors.greyText
            infoCard {
                HStack {
                    Image(systemName: direction == .up ? "arrow.up.right" : direction == .down ? "arrow.down.right" : "arrow.right")
                        .font(.title3).foregroundColor(color)
                    Text(direction.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var patternSection: some View {
        if let pattern = marker.chartPattern {
            infoCard {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal").font(.title3).foregroundColor(marker.type.color)
                    Text(pattern.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var indicatorSection: some View {
        if let indicator = marker.selectedIndicator {
            infoCard {
                HStack {
                    Image(systemName: "waveform.path.ecg").font(.title3).foregroundColor(marker.type.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Indicator Signal").font(.caption).foregroundColor(AppColors.greyText)
                        Text(indicator).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                    }
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
        if let question = marker.pollQuestion, let options = marker.pollOptions {
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
    
    @ViewBuilder
    private var tradeSection: some View {
        let isEntry = marker.type == .entry || marker.type == .takeProfit
        infoCard {
            HStack {
                Image(systemName: isEntry ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title3).foregroundColor(isEntry ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.type.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
                    if let linePrice = marker.horizontalLinePrice {
                        Text(String(format: "%.5f", linePrice)).font(.caption).foregroundColor(AppColors.greyText)
                    }
                }
                Spacer()
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


