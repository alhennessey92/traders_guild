//
//  MarkerDetailView.swift
//  traders_guild
//
//  CONVERTED: Now uses ChartMarkerDTO and MarkerCommentDTO instead of legacy types
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
    @EnvironmentObject var appState: AppState
    @ObservedObject var markerManager: MarkerManager
    
    let marker: ChartMarkerDTO
    @Binding var selectedDetent: PresentationDetent
    
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var comments: [MarkerCommentDTO] = []
    @State private var showComments: Bool = false
    @State private var showDeleteMarkerConfirmation: Bool = false
    @State private var showReportConfirmation: Bool = false
    
    init(marker: ChartMarkerDTO, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
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
        markerManager.toggleLike(markerId: marker.id)
    }
    
    private func handleShare() {
        HapticFeedback.medium.trigger()
        print("Share marker: \(marker.id)")
    }
    
    private func handleReport() {
        HapticFeedback.medium.trigger()
        Task {
            appState.showSuccess("Marker reported. Thank you for your feedback.")
        }
    }
    
    private func handleDelete() {
        HapticFeedback.warning.trigger()
        markerManager.deleteMarker(id: marker.id)
        appState.showSuccess("Marker deleted")
        dismiss()
    }
}

// MARK: - Comments View (Using MarkerCommentDTO)

struct CommentsView: View {
    let marker: ChartMarkerDTO
    @Binding var comments: [MarkerCommentDTO]
    @ObservedObject var markerManager: MarkerManager
    @EnvironmentObject var appState: AppState
    
    @State private var commentText: String = ""
    @State private var isSendingComment: Bool = false
    @FocusState private var isCommentInputFocused: Bool
    
    @Binding var selectedDetent: PresentationDetent
    
    init(marker: ChartMarkerDTO, comments: Binding<[MarkerCommentDTO]>, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
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
                                .environmentObject(appState)
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
        
        // Add comment through marker manager
        markerManager.addComment(markerId: marker.id, content: trimmed)
        
        // Create local DTO for immediate UI update
        let newComment = MarkerCommentDTO(
            id: UUID(),
            markerId: marker.id,
            author: appState.currentUser?.guildMembership ?? SampleData.currentUser.guildMembership,
            content: trimmed,
            timestamp: Date(),
            timestampFormatted: "Just now",
            isEdited: false,
            isCurrentUserMessage: true,
            canEdit: true,
            canDelete: true
        )
        
        withAnimation(.easeOut(duration: 0.2)) {
            comments.append(newComment)
        }
        commentText = ""
        isSendingComment = false
        
        HapticFeedback.light.trigger()
    }
    
    private func handleDeleteComment(_ comment: MarkerCommentDTO) {
        HapticFeedback.warning.trigger()
        
        withAnimation(.easeOut(duration: 0.2)) {
            comments.removeAll { $0.id == comment.id }
        }
        
        markerManager.deleteComment(markerId: marker.id, commentId: comment.id)
        appState.showSuccess("Comment deleted")
    }
    
    private func handleReportComment(_ comment: MarkerCommentDTO) {
        HapticFeedback.medium.trigger()
        appState.showInfo("Comment reported for review")
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

// MARK: - Marker Comment Row (Using MarkerCommentDTO)

struct MarkerCommentRow: View {
    let comment: MarkerCommentDTO
    let onReport: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @EnvironmentObject var appState: AppState
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
                        initials: comment.authorInitials,
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
                        Text(comment.authorDisplayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText.opacity(0.9))
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.horizontal, 3)
                        
                        Text(comment.author.roleInGuild.displayName)
                            .font(.caption)
                            .foregroundColor(comment.author.roleInGuild.roleForegroundColor)
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
                            appState.showSuccess("Copied to clipboard")
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

// MARK: - Marker Detail Header (Using ChartMarkerDTO)

struct MarkerDetailHeaderView: View {
    let marker: ChartMarkerDTO
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
                                Text(marker.authorInitials.prefix(1))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.accentColor)
                            )
                        
                        Text(marker.authorDisplayName)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))
                        
                        Circle()
                            .fill(AppColors.greyText.opacity(0.5))
                            .frame(width: 3, height: 3)
                        
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

// MARK: - Marker Detail Footer (Using ChartMarkerDTO)

struct MarkerDetailFooterView: View {
    let marker: ChartMarkerDTO
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

// MARK: - Marker Info Content (Using ChartMarkerDTO)

struct MarkerInfoContent: View {
    let marker: ChartMarkerDTO
    
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
    let option: PollOptionDTO
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

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}




//
////
////  MarkerDetailView.swift
////  traders_guild
////
////  Comprehensive marker detail view with:
////  - Header: Gradient background, icon, user info, stats
////  - Info: Type-specific content
////  - Footer: Circular action buttons matching profile view design with added comment button
////  - Navigation to full-screen comments view
////
////  REFACTORED: Now uses unified ChatComponents for comment section
////  - ChatMessageBubble replaces MarkerCommentRow body
////  - ChatInputFooter replaces MarkerCommentInputFooter
////  - ChatEmptyStateView replaces custom empty comments view
////  - ChatBackground for consistent styling
//
//import SwiftUI
//import Combine
//
//// MARK: - Marker Detail View
//
//struct MarkerDetailView: View {
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var appState: AppState
//    @ObservedObject var markerManager: MarkerManager
//    
//    let marker: ChartMarker
//    @Binding var selectedDetent: PresentationDetent
//    
//    @State private var isLiked: Bool = false
//    @State private var likeCount: Int = 0
//    @State private var comments: [MarkerCommentDTO] = []
//    @State private var showComments: Bool = false
//    @State private var showDeleteMarkerConfirmation: Bool = false
//    @State private var showReportConfirmation: Bool = false
//    
//    init(marker: ChartMarker, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
//        self.marker = marker
//        self.markerManager = markerManager
//        self._selectedDetent = selectedDetent
//        
//        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
//        _likeCount = State(initialValue: marker.likeCount)
//        _comments = State(initialValue: marker.comments)
//    }
//    
//    var body: some View {
//        NavigationStack {
//            ZStack(alignment: .topTrailing) {
//                VStack(spacing: 0) {
//                    // Header with gradient
//                    MarkerDetailHeaderView(
//                        marker: marker,
//                        isLiked: isLiked,
//                        likeCount: likeCount,
//                        commentCount: comments.count
//                    )
//                    
//                    // Info content
//                    ScrollView(.vertical, showsIndicators: false) {
//                        MarkerInfoContent(marker: marker)
//                            .padding(.horizontal, 25)
//                            .padding(.vertical, 20)
//                    }
//                    
//                    Divider()
//                    
//                    // Footer
//                    MarkerDetailFooterView(
//                        marker: marker,
//                        isLiked: $isLiked,
//                        likeCount: $likeCount,
//                        isOwner: marker.userId == markerManager.userId,
//                        showComments: $showComments,
//                        onLike: handleLike,
//                        onShare: handleShare,
//                        onReport: { showReportConfirmation = true },
//                        onDelete: { showDeleteMarkerConfirmation = true }
//                    )
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//                .background(
//                    ZStack {
//                        Color.clear
//                            .background(.ultraThinMaterial)
//                        AppColors.sheetBackground
//                        StaticPatternView()
//                    }
//                )
//                
//                // Floating dismiss button
//                ChatDismissButton { dismiss() }
//                    .padding(.top, 20)
//                    .padding(.trailing, 20)
//            }
//            .alert("Delete Marker", isPresented: $showDeleteMarkerConfirmation) {
//                Button("Cancel", role: .cancel) { }
//                Button("Delete", role: .destructive) {
//                    handleDelete()
//                }
//            } message: {
//                Text("Are you sure you want to delete this marker? This action cannot be undone.")
//            }
//            .alert("Report Marker", isPresented: $showReportConfirmation) {
//                Button("Cancel", role: .cancel) { }
//                Button("Report", role: .destructive) {
//                    handleReport()
//                }
//            } message: {
//                Text("Report this marker as inappropriate or misleading?")
//            }
//            .navigationDestination(isPresented: $showComments) {
//                CommentsView(
//                    marker: marker,
//                    comments: $comments,
//                    markerManager: markerManager,
//                    selectedDetent: $selectedDetent
//                )
//                .navigationTitle("Comments")
//                .navigationBarTitleDisplayMode(.inline)
//                
//            }
//        }
//    }
//    
//    // MARK: - Actions
//    
//    private func handleLike() {
//        HapticFeedback.light.trigger()
//        
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//            isLiked.toggle()
//            likeCount += isLiked ? 1 : -1
//        }
//        
//        Task {
//            do {
//                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
//                    markerManager.markers[index].isLikedByCurrentUser = isLiked
//                    markerManager.markers[index].likeCount = likeCount
//                }
//            } catch {
//                withAnimation {
//                    isLiked.toggle()
//                    likeCount += isLiked ? 1 : -1
//                }
//                appState.showError(error, title: "Failed to Like", style: .toast)
//            }
//        }
//    }
//    
//    private func handleShare() {
//        HapticFeedback.medium.trigger()
//        print("Share marker: \(marker.id)")
//    }
//    
//    private func handleReport() {
//        HapticFeedback.medium.trigger()
//        Task {
//            appState.showSuccess("Marker reported. Thank you for your feedback.")
//        }
//    }
//    
//    private func handleDelete() {
//        HapticFeedback.warning.trigger()
//        
//        Task {
//            do {
//                markerManager.markers.removeAll { $0.id == marker.id }
//                appState.showSuccess("Marker deleted")
//                dismiss()
//            } catch {
//                appState.showError(error, title: "Failed to Delete", style: .toast)
//            }
//        }
//    }
//}
//
//// MARK: - Comments View (Refactored with Unified Components)
//
//struct CommentsView: View {
//    let marker: ChartMarker
//    @Binding var comments: [MarkerComment]
//    @ObservedObject var markerManager: MarkerManager
//    @EnvironmentObject var appState: AppState
//    
//    @State private var commentText: String = ""
//    @State private var isSendingComment: Bool = false
//    @FocusState private var isCommentInputFocused: Bool
//    
//    @State private var isLiked: Bool = false
//    @State private var likeCount: Int = 0
//    
//    @Binding var selectedDetent: PresentationDetent
//    
//    init(marker: ChartMarker, comments: Binding<[MarkerComment]>, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
//        self.marker = marker
//        self._comments = comments
//        self.markerManager = markerManager
//        self._selectedDetent = selectedDetent
//        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
//        _likeCount = State(initialValue: marker.likeCount)
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollViewReader { proxy in
//                ScrollView(.vertical, showsIndicators: false) {
//                    if comments.isEmpty {
//                        // Using unified ChatEmptyStateView
//                        ChatEmptyStateView(
//                            icon: "bubble.left.and.bubble.right",
//                            title: "No comments yet",
//                            subtitle: "Be the first to share your thoughts"
//                        )
//                        .padding(.top, 60)
//                        Color.clear
//                            .frame(height: 0)
//                            .id("bottom")
//                    } else {
//                        LazyVStack(spacing: 12) {
//                            ForEach(comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
//                                MarkerCommentRow(
//                                    comment: comment,
//                                    isCurrentUser: comment.userId == markerManager.userId,
//                                    onReport: {
//                                        handleReportComment(comment)
//                                    },
//                                    onDelete: comment.userId == markerManager.userId ? {
//                                        handleDeleteComment(comment)
//                                    } : nil
//                                )
//                                .environmentObject(appState)
//                                .id(comment.id)
//                            }
//                        }
//                        .padding(.horizontal, 16)
//                        .padding(.top, 16)
//                        .padding(.bottom, 20)
//                        Color.clear
//                            .frame(height: 0)
//                            .id("bottom")
//                    }
//                }
//                .scrollDismissesKeyboard(.interactively)
//                .onTapGesture {
//                    isCommentInputFocused = false
//                }
//                .onChange(of: comments.count) { _ in
//                    if let lastComment = comments.last {
//                        withAnimation(.easeOut(duration: 0.2)) {
//                            proxy.scrollTo(lastComment.id, anchor: UnitPoint.bottom)
//                        }
//                    }
//                }
//                .onChange(of: isCommentInputFocused) { focused in
//                    if focused {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                            withAnimation(.easeOut(duration: 0.2)) {
//                                proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
//                            }
//                        }
//                    }
//                }
//                .onAppear {
//                    if !comments.isEmpty, let lastComment = comments.last {
//                        proxy.scrollTo(lastComment.id, anchor: UnitPoint.bottom)
//                    } else {
//                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
//                    }
//                }
//                .background(ChatBackground())
//            }
//        }
//        .safeAreaInset(edge: .bottom) {
//            // Using unified ChatInputFooter
//            MarkerCommentInputFooter(
//                commentText: $commentText,
//                isInputFocused: _isCommentInputFocused,
//                isSending: isSendingComment,
//                onSend: handleAddComment,
//                selectedDetent: $selectedDetent
//            )
//        }
//        .background(AppColors.sheetBackground)
//        .toolbarBackground(AppColors.sheetBackground, for: .navigationBar)
//        .toolbarBackground(.visible, for: .navigationBar)
//    }
//    
//    // MARK: - Actions
//    
//    private func handleLike() {
//        HapticFeedback.light.trigger()
//        
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//            isLiked.toggle()
//            likeCount += isLiked ? 1 : -1
//        }
//        
//        Task {
//            do {
//                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
//                    markerManager.markers[index].isLikedByCurrentUser = isLiked
//                    markerManager.markers[index].likeCount = likeCount
//                }
//            } catch {
//                withAnimation {
//                    isLiked.toggle()
//                    likeCount += isLiked ? 1 : -1
//                }
//                appState.showError(error, title: "Failed to Like", style: .toast)
//            }
//        }
//    }
//    
//    private func handleShare() {
//        HapticFeedback.medium.trigger()
//        print("Share marker: \(marker.id)")
//    }
//    
//    private func handleAddComment() {
//        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else { return }
//        
//        HapticFeedback.light.trigger()
//        
//        isSendingComment = true
//        isCommentInputFocused = false
//        
//        let newComment = MarkerComment(
//            userId: markerManager.userId,
//            username: appState.currentUser?.name ?? "Unknown",
//            text: trimmed,
//            createdAt: Date()
//        )
//        
//        withAnimation(.easeOut(duration: 0.2)) {
//            comments.append(newComment)
//        }
//        commentText = ""
//        
//        Task {
//            do {
//                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
//                    markerManager.markers[index].comments.append(newComment)
//                }
//                HapticFeedback.light.trigger()
//            } catch {
//                comments.removeAll { $0.id == newComment.id }
//                appState.showError(error, title: "Failed to Add Comment", style: .toast)
//            }
//            isSendingComment = false
//        }
//    }
//    
//    private func handleDeleteComment(_ comment: MarkerComment) {
//        HapticFeedback.warning.trigger()
//        
//        withAnimation(.easeOut(duration: 0.2)) {
//            comments.removeAll { $0.id == comment.id }
//        }
//        
//        Task {
//            do {
//                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
//                    markerManager.markers[index].comments.removeAll { $0.id == comment.id }
//                }
//                appState.showSuccess("Comment deleted")
//            } catch {
//                comments.append(comment)
//                appState.showError(error, title: "Failed to Delete Comment", style: .toast)
//            }
//        }
//    }
//    
//    private func handleReportComment(_ comment: MarkerComment) {
//        HapticFeedback.medium.trigger()
//        Task {
//            appState.showInfo("Comment reported for review")
//        }
//    }
//}
//
//// MARK: - Marker Comment Input Footer (Using Unified ChatInputFooter Pattern)
//
//struct MarkerCommentInputFooter: View {
//    @Binding var commentText: String
//    @FocusState var isInputFocused: Bool
//    let isSending: Bool
//    let onSend: () -> Void
//    @Binding var selectedDetent: PresentationDetent
//    
//    var body: some View {
//        ChatInputFooter(
//            messageText: $commentText,
//            placeholder: "Add a comment...",
//            isSending: isSending,
//            onSend: onSend,
//            selectedDetent: $selectedDetent
//        )
//    }
//}
//
//// MARK: - Marker Comment Row (Using Unified ChatMessageBubble)
//
//struct MarkerCommentRow: View {
//    let comment: MarkerComment
//    let isCurrentUser: Bool
//    let onReport: () -> Void
//    var onDelete: (() -> Void)? = nil
//    
//    @EnvironmentObject var appState: AppState
//    @State private var showDeleteConfirmation = false
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 8) {
//            if isCurrentUser {
//                Spacer()
//            } else {
//                // Avatar - using unified ChatAvatar
//                Button(action: {
//                    // Could navigate to user profile
//                }) {
//                    ChatAvatar(
//                        initials: String(comment.username.prefix(2)),
//                        isOnline: true,
//                        size: 32
//                    )
//                }
//                .buttonStyle(PlainButtonStyle())
//            }
//            
//            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
//                // User info row (only for other users)
//                if !isCurrentUser {
//                    HStack(spacing: 2) {
//                        Text(comment.username)
//                            .font(.caption)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.whiteText.opacity(0.9))
//                        
//                        Circle()
//                            .fill(AppColors.whiteText.opacity(0.7))
//                            .frame(width: 3, height: 3)
//                            .padding(.horizontal, 3)
//                        
//                        Text("Member")
//                            .font(.caption)
//                            .foregroundColor(AppColors.greyText)
//                    }
//                }
//                
//                // Message bubble - using unified bubble shape
//                Text(comment.text)
//                    .font(.subheadline)
//                    .foregroundColor(isCurrentUser ? .white : .primary)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(
//                        isCurrentUser ?
//                        AppColors.accentDarkColor :
//                        Color.gray.opacity(0.2)
//                    )
//                    .clipShape(ChatBubbleShape.bubbleShape(isFromCurrentUser: isCurrentUser))
//                    .contextMenu {
//                        // Delete (own comments only)
//                        if let onDelete = onDelete {
//                            Button(role: .destructive) {
//                                showDeleteConfirmation = true
//                            } label: {
//                                Label("Delete", systemImage: "trash")
//                            }
//                        }
//                        
//                        // Copy
//                        Button {
//                            UIPasteboard.general.string = comment.text
//                            appState.showSuccess("Copied to clipboard")
//                        } label: {
//                            Label("Copy", systemImage: "doc.on.doc")
//                        }
//                        
//                        // Report (other users' comments)
//                        if !isCurrentUser {
//                            Divider()
//                            Button(role: .destructive) {
//                                onReport()
//                            } label: {
//                                Label("Report", systemImage: "exclamationmark.triangle")
//                            }
//                        }
//                    }
//                
//                // Timestamp
//                Text(comment.createdAt.timeAgoDisplay())
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//            }
//            
//            if !isCurrentUser {
//                Spacer()
//            }
//        }
//        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Delete", role: .destructive) {
//                onDelete?()
//            }
//        } message: {
//            Text("Are you sure you want to delete this comment? This cannot be undone.")
//        }
//    }
//}
//
//// MARK: - Marker Detail Header
//
//struct MarkerDetailHeaderView: View {
//    let marker: ChartMarker
//    let isLiked: Bool
//    let likeCount: Int
//    let commentCount: Int
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            // Main header row
//            HStack(spacing: 15) {
//                // Marker type icon with colored background
//                ZStack {
//                    Circle()
//                        .fill(marker.type.color.opacity(0.2))
//                        .frame(width: 56, height: 56)
//                    
//                    Circle()
//                        .stroke(marker.type.color.opacity(0.4), lineWidth: 2)
//                        .frame(width: 56, height: 56)
//                    
//                    Image(systemName: marker.type.icon)
//                        .font(.system(size: 24, weight: .semibold))
//                        .foregroundColor(marker.type.color)
//                }
//                
//                // Marker info
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(marker.type.rawValue)
//                        .font(.title3)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.whiteText)
//                    
//                    // User info row
//                    HStack(spacing: 6) {
//                        Circle()
//                            .fill(AppColors.accentColor.opacity(0.3))
//                            .frame(width: 18, height: 18)
//                            .overlay(
//                                Text(String(marker.username.prefix(1)))
//                                    .font(.system(size: 9, weight: .bold))
//                                    .foregroundColor(AppColors.accentColor)
//                            )
//                        
//                        Text(marker.username)
//                            .font(.subheadline)
//                            .foregroundColor(AppColors.whiteText.opacity(0.8))
//                        
//                        Circle()
//                            .fill(AppColors.greyText.opacity(0.5))
//                            .frame(width: 3, height: 3)
//                        
//                        Text(marker.createdAt.timeAgoDisplay())
//                            .font(.caption)
//                            .foregroundColor(AppColors.greyText)
//                    }
//                }
//                
//                Spacer(minLength: 50)
//            }
//            
//            // Note (if present)
//            if let note = marker.note, !note.isEmpty {
//                Text(note)
//                    .font(.subheadline)
//                    .foregroundColor(AppColors.whiteText.opacity(0.85))
//                    .lineLimit(3)
//                    .padding(.top, 4)
//            }
//            
//            // Stats row
//            HStack(spacing: 16) {
//                // Likes
//                HStack(spacing: 4) {
//                    Image(systemName: isLiked ? "heart.fill" : "heart")
//                        .font(.caption)
//                        .foregroundColor(isLiked ? .red : AppColors.greyText)
//                    Text("\(likeCount)")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.greyText)
//                }
//                
//                // Comments
//                HStack(spacing: 4) {
//                    Image(systemName: "bubble.left")
//                        .font(.caption)
//                        .foregroundColor(AppColors.greyText)
//                    Text("\(commentCount)")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.greyText)
//                }
//                
//                Spacer()
//                
//                // Price badge
//                Text(String(format: "%.5f", marker.price))
//                    .font(.caption)
//                    .fontWeight(.semibold)
//                    .foregroundColor(marker.type.color)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 4)
//                    .background(marker.type.color.opacity(0.15))
//                    .clipShape(Capsule())
//            }
//            
//            Divider()
//        }
//        .padding(.horizontal, 25)
//        .padding(.top, 25)
//        .padding(.bottom, 8)
//        .background(
//            LinearGradient(
//                colors: [
//                    marker.type.color.opacity(0.15),
//                    AppColors.sheetBackground
//                ],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        )
//    }
//}
//
//// MARK: - Marker Detail Footer
//
//struct MarkerDetailFooterView: View {
//    let marker: ChartMarker
//    @Binding var isLiked: Bool
//    @Binding var likeCount: Int
//    let isOwner: Bool
//    @Binding var showComments: Bool
//    let onLike: () -> Void
//    let onShare: () -> Void
//    let onReport: () -> Void
//    let onDelete: () -> Void
//    
//    @State private var likeScale: CGFloat = 1.0
//    
//    var body: some View {
//        HStack(spacing: 8) {
//            // Like button - capsule with animation
//            Button(action: {
//                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
//                    likeScale = 1.3
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
//                        likeScale = 1.0
//                    }
//                }
//                onLike()
//            }) {
//                HStack(spacing: 6) {
//                    Image(systemName: isLiked ? "heart.fill" : "heart")
//                        .font(.system(size: 16, weight: .medium))
//                        .foregroundColor(isLiked ? .white : AppColors.whiteText.opacity(0.9))
//                        .scaleEffect(likeScale)
//                    
//                    Text("\(likeCount)")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(isLiked ? .white : AppColors.whiteText.opacity(0.9))
//                }
//                .frame(minWidth: 80)
//                .frame(height: 44)
//                .padding(.horizontal, 16)
//                .background(
//                    Capsule()
//                        .fill(isLiked ? Color.red : AppColors.gradientBackgroundDark.opacity(0.3))
//                )
//                .overlay(
//                    Capsule()
//                        .stroke(
//                            isLiked ? Color.red.opacity(0.5) : AppColors.whiteText.opacity(0.2),
//                            lineWidth: 1
//                        )
//                )
//            }
//            .compositingGroup()
//            
//            Spacer()
//            
//            // Share button - circular
//            DrawerActionButton(
//                imageName: "square.and.arrow.up",
//                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
//                foregroundColor: AppColors.whiteText.opacity(0.9),
//                strokeColor: AppColors.whiteText.opacity(0.2),
//                strokeWidth: 1,
//                action: onShare
//            )
//            
//            // Comment button - circular
//            DrawerActionButton(
//                imageName: "bubble.left",
//                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
//                foregroundColor: AppColors.whiteText.opacity(0.9),
//                strokeColor: AppColors.whiteText.opacity(0.2),
//                strokeWidth: 1,
//                action: { showComments = true }
//            )
//            
//            // Report or Delete button - circular
//            if isOwner {
//                DrawerActionButton(
//                    imageName: "trash",
//                    backgroundColor: AppColors.bearCandleRed.opacity(0.15),
//                    foregroundColor: AppColors.bearCandleRed,
//                    strokeColor: AppColors.bearCandleRed.opacity(0.4),
//                    strokeWidth: 1,
//                    action: onDelete
//                )
//            } else {
//                DrawerActionButton(
//                    imageName: "flag",
//                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
//                    foregroundColor: AppColors.whiteText.opacity(0.9),
//                    strokeColor: AppColors.whiteText.opacity(0.2),
//                    strokeWidth: 1,
//                    action: onReport
//                )
//            }
//        }
//        .padding(.horizontal, 25)
//        .padding(.vertical, 16)
//        .background(AppColors.sheetBackground)
//        .compositingGroup()
//    }
//}
//
//// MARK: - Marker Info Content
//
//struct MarkerInfoContent: View {
//    let marker: ChartMarker
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 24) {
//            // Price & Time info card
//            infoCard {
//                VStack(spacing: 12) {
//                    infoRow(
//                        icon: "chart.line.uptrend.xyaxis",
//                        label: "Price Level",
//                        value: String(format: "%.5f", marker.price),
//                        valueColor: marker.type.color
//                    )
//                    
//                    Divider()
//                        .background(AppColors.whiteText.opacity(0.1))
//                    
//                    infoRow(
//                        icon: "clock",
//                        label: "Created",
//                        value: marker.createdAt.formatted(date: .abbreviated, time: .shortened)
//                    )
//                    
//                    if marker.type.hasHorizontalLine, let linePrice = marker.horizontalLinePrice {
//                        Divider()
//                            .background(AppColors.whiteText.opacity(0.1))
//                        
//                        infoRow(
//                            icon: "minus",
//                            label: "Line Price",
//                            value: String(format: "%.5f", linePrice),
//                            valueColor: marker.type.color
//                        )
//                    }
//                }
//            }
//            
//            // Type-specific content
//            typeSpecificSection
//        }
//    }
//    
//    @ViewBuilder
//    private var typeSpecificSection: some View {
//        switch marker.type {
//        case .predictionTarget:
//            predictionSection
//        case .alert:
//            alertSection
//        case .support, .resistance:
//            levelSection
//        case .trendline:
//            trendlineSection
//        case .pattern:
//            patternSection
//        case .indicator:
//            indicatorSection
//        case .emoji:
//            emojiSection
//        case .poll:
//            pollSection
//        case .entry, .exit, .stopLoss, .takeProfit:
//            tradeSection
//        default:
//            EmptyView()
//        }
//    }
//    
//    @ViewBuilder
//    private var predictionSection: some View {
//        if let targetPrice = marker.targetPrice {
//            let entryPrice = marker.horizontalLinePrice ?? marker.price
//            let percentChange = ((targetPrice - entryPrice) / entryPrice) * 100
//            let isLong = percentChange > 0
//            
//            infoCard {
//                VStack(spacing: 16) {
//                    HStack {
//                        Image(systemName: isLong ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
//                            .font(.title2)
//                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
//                        
//                        Text(isLong ? "Long Position" : "Short Position")
//                            .font(.headline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.whiteText)
//                        
//                        Spacer()
//                        
//                        Text(String(format: "%+.2f%%", percentChange))
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
//                    }
//                    
//                    Divider().background(AppColors.whiteText.opacity(0.1))
//                    
//                    HStack(spacing: 20) {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Entry").font(.caption).foregroundColor(AppColors.greyText)
//                            Text(String(format: "%.5f", entryPrice))
//                                .font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                        }
//                        Image(systemName: "arrow.right").font(.caption).foregroundColor(AppColors.greyText)
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Target").font(.caption).foregroundColor(AppColors.greyText)
//                            Text(String(format: "%.5f", targetPrice))
//                                .font(.subheadline).fontWeight(.semibold)
//                                .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
//                        }
//                        Spacer()
//                    }
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder private var alertSection: some View {
//        if let severity = marker.alertSeverity {
//            infoCard {
//                HStack {
//                    Circle().fill(severity.color).frame(width: 12, height: 12)
//                    Text("Severity: \(severity.rawValue)")
//                        .font(.subheadline).fontWeight(.medium).foregroundColor(AppColors.whiteText)
//                    Spacer()
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder private var levelSection: some View {
//        infoCard {
//            HStack {
//                Image(systemName: marker.type == .support ? "arrow.down.to.line" : "arrow.up.to.line")
//                    .font(.title3).foregroundColor(marker.type.color)
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(marker.type == .support ? "Support Level" : "Resistance Level")
//                        .font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                    Text("Price may \(marker.type == .support ? "bounce up" : "reverse down") at this level")
//                        .font(.caption).foregroundColor(AppColors.greyText)
//                }
//                Spacer()
//            }
//        }
//    }
//    
//    @ViewBuilder private var trendlineSection: some View {
//        if let direction = marker.trendlineDirection {
//            let color: Color = direction == .up ? AppColors.bullCandleGreen : direction == .down ? AppColors.bearCandleRed : AppColors.greyText
//            infoCard {
//                HStack {
//                    Image(systemName: direction == .up ? "arrow.up.right" : direction == .down ? "arrow.down.right" : "arrow.right")
//                        .font(.title3).foregroundColor(color)
//                    Text(direction.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                    Spacer()
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder private var patternSection: some View {
//        if let pattern = marker.chartPattern {
//            infoCard {
//                HStack {
//                    Image(systemName: "chart.bar.doc.horizontal").font(.title3).foregroundColor(marker.type.color)
//                    Text(pattern.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                    Spacer()
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder private var indicatorSection: some View {
//        if let indicator = marker.selectedIndicator {
//            infoCard {
//                HStack {
//                    Image(systemName: "waveform.path.ecg").font(.title3).foregroundColor(marker.type.color)
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text("Indicator Signal").font(.caption).foregroundColor(AppColors.greyText)
//                        Text(indicator).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                    }
//                    Spacer()
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder private var emojiSection: some View {
//        if let emoji = marker.selectedEmoji {
//            infoCard { HStack { Text(emoji).font(.system(size: 44)); Spacer() } }
//        }
//    }
//    
//    @ViewBuilder private var pollSection: some View {
//        if let question = marker.pollQuestion, let options = marker.pollOptions {
//            infoCard {
//                VStack(alignment: .leading, spacing: 12) {
//                    Text(question).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                    ForEach(options) { option in
//                        PollOptionRow(option: option, totalVotes: options.reduce(0) { $0 + $1.voteCount }, hasVoted: marker.userPollVote == option.id)
//                    }
//                }
//            }
//        }
//    }
//    
//    @ViewBuilder private var tradeSection: some View {
//        let isEntry = marker.type == .entry || marker.type == .takeProfit
//        infoCard {
//            HStack {
//                Image(systemName: isEntry ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
//                    .font(.title3).foregroundColor(isEntry ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(marker.type.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
//                    if let linePrice = marker.horizontalLinePrice {
//                        Text(String(format: "%.5f", linePrice)).font(.caption).foregroundColor(AppColors.greyText)
//                    }
//                }
//                Spacer()
//            }
//        }
//    }
//    
//    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
//        content()
//            .padding(16)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(AppColors.whiteText.opacity(0.05))
//            .cornerRadius(16)
//            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1))
//    }
//    
//    private func infoRow(icon: String, label: String, value: String, valueColor: Color = AppColors.whiteText) -> some View {
//        HStack {
//            Image(systemName: icon).font(.subheadline).foregroundColor(AppColors.greyText).frame(width: 20)
//            Text(label).font(.subheadline).foregroundColor(AppColors.greyText)
//            Spacer()
//            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(valueColor)
//        }
//    }
//}
//
//// MARK: - Poll Option Row
//
//struct PollOptionRow: View {
//    let option: PollOption
//    let totalVotes: Int
//    let hasVoted: Bool
//    
//    private var percentage: Double {
//        guard totalVotes > 0 else { return 0 }
//        return Double(option.voteCount) / Double(totalVotes)
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            HStack {
//                Text(option.text).font(.subheadline).fontWeight(hasVoted ? .semibold : .regular)
//                    .foregroundColor(hasVoted ? AppColors.accentColor : AppColors.whiteText)
//                Spacer()
//                Text("\(Int(percentage * 100))%").font(.caption).fontWeight(.semibold).foregroundColor(AppColors.greyText)
//            }
//            GeometryReader { geometry in
//                ZStack(alignment: .leading) {
//                    RoundedRectangle(cornerRadius: 4).fill(AppColors.whiteText.opacity(0.1)).frame(height: 6)
//                    RoundedRectangle(cornerRadius: 4).fill(hasVoted ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
//                        .frame(width: geometry.size.width * percentage, height: 6)
//                }
//            }.frame(height: 6)
//        }.padding(.vertical, 6)
//    }
//}
//
//// MARK: - Date Extension
//
//extension Date {
//    func timeAgoDisplay() -> String {
//        let formatter = RelativeDateTimeFormatter()
//        formatter.unitsStyle = .abbreviated
//        return formatter.localizedString(for: self, relativeTo: Date())
//    }
//}
//
//
//
//
//
//
//
//
//
//
//////
//////  MarkerDetailView.swift
//////  traders_guild
//////
//////  Comprehensive marker detail view with:
//////  - Header: Gradient background, icon, user info, stats
//////  - Info: Type-specific content
//////  - Footer: Circular action buttons matching profile view design with added comment button
//////  - Navigation to full-screen comments view
//////
//////  FIXED: Removed manual keyboard handling to prevent jumping animations
////
////import SwiftUI
////import Combine
////
////// MARK: - Marker Detail View
////
////struct MarkerDetailView: View {
////    @Environment(\.dismiss) private var dismiss
////    @EnvironmentObject var appState: AppState
////    @ObservedObject var markerManager: MarkerManager
////    
////    let marker: ChartMarker
////    @Binding var selectedDetent: PresentationDetent
////    
////    @State private var isLiked: Bool = false
////    @State private var likeCount: Int = 0
////    @State private var comments: [MarkerComment] = []
////    @State private var showComments: Bool = false
////    @State private var showDeleteMarkerConfirmation: Bool = false
////    @State private var showReportConfirmation: Bool = false
////    
////    init(marker: ChartMarker, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
////        self.marker = marker
////        self.markerManager = markerManager
////        self._selectedDetent = selectedDetent
////        
////        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
////        _likeCount = State(initialValue: marker.likeCount)
////        _comments = State(initialValue: marker.comments)
////    }
////    
////    var body: some View {
////        NavigationStack {
////            ZStack(alignment: .topTrailing) {
////                VStack(spacing: 0) {
////                    // Header with gradient
////                    MarkerDetailHeaderView(
////                        marker: marker,
////                        isLiked: isLiked,
////                        likeCount: likeCount,
////                        commentCount: comments.count
////                    )
////                    
////                    // Info content
////                    ScrollView(.vertical, showsIndicators: false) {
////                        MarkerInfoContent(marker: marker)
////                            .padding(.horizontal, 25)
////                            .padding(.vertical, 20)
////                    }
////                    
////                    Divider()
////                    
////                    // Footer
////                    MarkerDetailFooterView(
////                        marker: marker,
////                        isLiked: $isLiked,
////                        likeCount: $likeCount,
////                        isOwner: marker.userId == markerManager.userId,
////                        showComments: $showComments,
////                        onLike: handleLike,
////                        onShare: handleShare,
////                        onReport: { showReportConfirmation = true },
////                        onDelete: { showDeleteMarkerConfirmation = true }
////                    )
////                }
////                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
////                .background(
////                    ZStack {
////                        Color.clear
////                            .background(.ultraThinMaterial)
////                        AppColors.sheetBackground
////                        StaticPatternView()
////                    }
////                )
////                
////                // Floating dismiss button
////                Button(action: { dismiss() }) {
////                    Image(systemName: "xmark.circle.fill")
////                        .font(.title2)
////                        .foregroundColor(.secondary)
////                }
////                .padding(.top, 20)
////                .padding(.trailing, 20)
////            }
////            .alert("Delete Marker", isPresented: $showDeleteMarkerConfirmation) {
////                Button("Cancel", role: .cancel) { }
////                Button("Delete", role: .destructive) {
////                    handleDelete()
////                }
////            } message: {
////                Text("Are you sure you want to delete this marker? This action cannot be undone.")
////            }
////            .alert("Report Marker", isPresented: $showReportConfirmation) {
////                Button("Cancel", role: .cancel) { }
////                Button("Report", role: .destructive) {
////                    handleReport()
////                }
////            } message: {
////                Text("Report this marker as inappropriate or misleading?")
////            }
////            .navigationDestination(isPresented: $showComments) {
////                CommentsView(
////                    marker: marker,
////                    comments: $comments,
////                    markerManager: markerManager,
////                    selectedDetent: $selectedDetent
////                )
////                .navigationTitle("Comments")
////                .navigationBarTitleDisplayMode(.inline)
////                
////            }
////        }
////    }
////    
////    // MARK: - Actions
////    
////    private func handleLike() {
////        HapticFeedback.light.trigger()
////        
////        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
////            isLiked.toggle()
////            likeCount += isLiked ? 1 : -1
////        }
////        
////        Task {
////            do {
////                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
////                    markerManager.markers[index].isLikedByCurrentUser = isLiked
////                    markerManager.markers[index].likeCount = likeCount
////                }
////            } catch {
////                withAnimation {
////                    isLiked.toggle()
////                    likeCount += isLiked ? 1 : -1
////                }
////                appState.showError(error, title: "Failed to Like", style: .toast)
////            }
////        }
////    }
////    
////    private func handleShare() {
////        HapticFeedback.medium.trigger()
////        print("Share marker: \(marker.id)")
////    }
////    
////    private func handleReport() {
////        HapticFeedback.medium.trigger()
////        Task {
////            appState.showSuccess("Marker reported. Thank you for your feedback.")
////        }
////    }
////    
////    private func handleDelete() {
////        HapticFeedback.warning.trigger()
////        
////        Task {
////            do {
////                markerManager.markers.removeAll { $0.id == marker.id }
////                appState.showSuccess("Marker deleted")
////                dismiss()
////            } catch {
////                appState.showError(error, title: "Failed to Delete", style: .toast)
////            }
////        }
////    }
////}
////
////// MARK: - Comments View
////
////struct CommentsView: View {
////    let marker: ChartMarker
////    @Binding var comments: [MarkerComment]
////    @ObservedObject var markerManager: MarkerManager
////    @EnvironmentObject var appState: AppState
////    
////    @State private var commentText: String = ""
////    @State private var isSendingComment: Bool = false
////    @FocusState private var isCommentInputFocused: Bool
////    
////    @State private var isLiked: Bool = false
////    @State private var likeCount: Int = 0
////    
////    @Binding var selectedDetent: PresentationDetent
////    
////    init(marker: ChartMarker, comments: Binding<[MarkerComment]>, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
////        self.marker = marker
////        self._comments = comments
////        self.markerManager = markerManager
////        self._selectedDetent = selectedDetent
////        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
////        _likeCount = State(initialValue: marker.likeCount)
////    }
////    
////    var body: some View {
////        VStack(spacing: 0) {
////            ScrollViewReader { proxy in
////                ScrollView(.vertical, showsIndicators: false) {
////                    if comments.isEmpty {
////                        emptyCommentsView
////                            .padding(.top, 60)
////                        Color.clear
////                            .frame(height: 0)
////                            .id("bottom")
////                    } else {
////                        LazyVStack(spacing: 12) {
////                            ForEach(comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
////                                MarkerCommentRow(
////                                    comment: comment,
////                                    isCurrentUser: comment.userId == markerManager.userId,
////                                    onReport: {
////                                        handleReportComment(comment)
////                                    },
////                                    onDelete: comment.userId == markerManager.userId ? {
////                                        handleDeleteComment(comment)
////                                    } : nil
////                                )
////                                .environmentObject(appState)
////                                .id(comment.id)
////                            }
////                        }
////                        .padding(.horizontal, 16)
////                        .padding(.top, 16)
////                        .padding(.bottom, 20)
////                        Color.clear
////                            .frame(height: 0)
////                            .id("bottom")
////                    }
////                }
////                .scrollDismissesKeyboard(.interactively)
////                .onTapGesture {
////                    isCommentInputFocused = false
////                }
////                .onChange(of: comments.count) { _ in
////                    if let lastComment = comments.last {
////                        withAnimation(.easeOut(duration: 0.2)) {
////                            proxy.scrollTo(lastComment.id, anchor: UnitPoint.bottom)
////                        }
////                    }
////                }
////                .onChange(of: isCommentInputFocused) { focused in
////                    if focused {
////                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
////                            withAnimation(.easeOut(duration: 0.2)) {
////                                proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
////                            }
////                        }
////                    }
////                }
////                .onAppear {
////                    if !comments.isEmpty, let lastComment = comments.last {
////                        proxy.scrollTo(lastComment.id, anchor: UnitPoint.bottom)
////                    } else {
////                        proxy.scrollTo("bottom", anchor: UnitPoint.bottom)
////                    }
////                }
////                .background(
////                    ZStack {
////                        Color.clear
////                            .background(.ultraThinMaterial)
////                        AppColors.sheetBackground
////                        StaticPatternView()
////                    }
////                )
////            }
////        }
////        .safeAreaInset(edge: .bottom) {
////            MarkerCommentInputFooter(
////                commentText: $commentText,
////                isInputFocused: _isCommentInputFocused,
////                isSending: isSendingComment,
////                onSend: handleAddComment,
////                selectedDetent: $selectedDetent
////            )
////        }
////        .background(AppColors.sheetBackground)
////        .toolbarBackground(AppColors.sheetBackground, for: .navigationBar)
////        .toolbarBackground(.visible, for: .navigationBar)
////    }
////    
////    // MARK: - Empty Comments View
////    
////    private var emptyCommentsView: some View {
////        VStack(spacing: 16) {
////            ZStack {
////                Circle()
////                    .fill(AppColors.accentColor.opacity(0.1))
////                    .frame(width: 80, height: 80)
////                
////                Image(systemName: "bubble.left.and.bubble.right")
////                    .font(.system(size: 32))
////                    .foregroundColor(AppColors.accentColor.opacity(0.6))
////            }
////            
////            VStack(spacing: 6) {
////                Text("No comments yet")
////                    .font(.headline)
////                    .fontWeight(.semibold)
////                    .foregroundColor(AppColors.whiteText)
////                
////                Text("Be the first to share your thoughts")
////                    .font(.subheadline)
////                    .foregroundColor(AppColors.greyText)
////            }
////        }
////        .frame(maxWidth: .infinity)
////    }
////    
////    // MARK: - Actions
////    
////    private func handleLike() {
////        HapticFeedback.light.trigger()
////        
////        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
////            isLiked.toggle()
////            likeCount += isLiked ? 1 : -1
////        }
////        
////        Task {
////            do {
////                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
////                    markerManager.markers[index].isLikedByCurrentUser = isLiked
////                    markerManager.markers[index].likeCount = likeCount
////                }
////            } catch {
////                withAnimation {
////                    isLiked.toggle()
////                    likeCount += isLiked ? 1 : -1
////                }
////                appState.showError(error, title: "Failed to Like", style: .toast)
////            }
////        }
////    }
////    
////    private func handleShare() {
////        HapticFeedback.medium.trigger()
////        print("Share marker: \(marker.id)")
////    }
////    
////    private func handleAddComment() {
////        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
////        guard !trimmed.isEmpty else { return }
////        
////        HapticFeedback.light.trigger()
////        
////        isSendingComment = true
////        isCommentInputFocused = false
////        
////        let newComment = MarkerComment(
////            userId: markerManager.userId,
////            username: appState.currentUser?.name ?? "Unknown",
////            text: trimmed,
////            createdAt: Date()
////        )
////        
////        withAnimation(.easeOut(duration: 0.2)) {
////            comments.append(newComment)
////        }
////        commentText = ""
////        
////        Task {
////            do {
////                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
////                    markerManager.markers[index].comments.append(newComment)
////                }
////                HapticFeedback.light.trigger()
////            } catch {
////                comments.removeAll { $0.id == newComment.id }
////                appState.showError(error, title: "Failed to Add Comment", style: .toast)
////            }
////            isSendingComment = false
////        }
////    }
////    
////    private func handleDeleteComment(_ comment: MarkerComment) {
////        HapticFeedback.warning.trigger()
////        
////        withAnimation(.easeOut(duration: 0.2)) {
////            comments.removeAll { $0.id == comment.id }
////        }
////        
////        Task {
////            do {
////                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
////                    markerManager.markers[index].comments.removeAll { $0.id == comment.id }
////                }
////                appState.showSuccess("Comment deleted")
////            } catch {
////                comments.append(comment)
////                appState.showError(error, title: "Failed to Delete Comment", style: .toast)
////            }
////        }
////    }
////    
////    private func handleReportComment(_ comment: MarkerComment) {
////        HapticFeedback.medium.trigger()
////        Task {
////            appState.showInfo("Comment reported for review")
////        }
////    }
////}
////
////// MARK: - Marker Comment Input Footer
////
////struct MarkerCommentInputFooter: View {
////    @Binding var commentText: String
////    @FocusState var isInputFocused: Bool
////    let isSending: Bool
////    let onSend: () -> Void
////    @Binding var selectedDetent: PresentationDetent
////    
////    var body: some View {
////        VStack(spacing: 0) {
////            Divider()
////                .background(Color.gray.opacity(0.3))
////            
////            HStack(spacing: 0) {
////                HStack(spacing: 12) {
////                    // Plus button
////                    Button(action: {
////                        // Handle attachment/emoji
////                    }) {
////                        Image(systemName: "plus")
////                            .font(.title3)
////                            .foregroundColor(.secondary)
////                            .frame(width: 32, height: 32)
////                    }
////                    .compositingGroup()
////                    
////                    // Text field
////                    TextField("Add a comment...", text: $commentText)
////                        .font(.subheadline)
////                        .submitLabel(.send)
////                        .focused($isInputFocused)
////                        .disabled(isSending)
////                        .onSubmit {
////                            onSend()
////                        }
////                    
////                    HStack(spacing: 8) {
////                        // Mic button
////                        Button(action: {
////                            // Handle voice
////                        }) {
////                            Image(systemName: "mic.fill")
////                                .font(.title3)
////                                .foregroundColor(.secondary)
////                                .frame(width: 32, height: 32)
////                        }
////                        .compositingGroup()
////                        
////                        // Send button
////                        if isSending {
////                            ProgressView()
////                                .scaleEffect(0.8)
////                                .frame(width: 40, height: 40)
////                        } else {
////                            Button(action: onSend) {
////                                Image(systemName: "chevron.forward.2")
////                                    .font(.title3)
////                                    .fontWeight(.bold)
////                                    .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
////                                    .frame(width: 40, height: 40)
////                                    .padding(.leading, 2)
////                                    .background(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
////                                    .clipShape(Capsule())
////                            }
////                            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
////                            .compositingGroup()
////                        }
////                    }
////                }
////                .padding(.leading, 10)
////                .frame(height: 44)
////                .background(AppColors.whiteText.opacity(0.08))
////                .cornerRadius(25)
////            }
////            .padding()
////        }
////        .background(AppColors.sheetBackground)
////        .overlay {
////            if selectedDetent != .large {
////                Color.clear
////                    .contentShape(Rectangle())
////                    .onTapGesture {
////                        selectedDetent = .large
////                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
////                            isInputFocused = true
////                        }
////                    }
////            }
////        }
////        .compositingGroup()
////    }
////}
////
////// MARK: - Marker Comment Row
////
////struct MarkerCommentRow: View {
////    let comment: MarkerComment
////    let isCurrentUser: Bool
////    let onReport: () -> Void
////    var onDelete: (() -> Void)? = nil
////    
////    @EnvironmentObject var appState: AppState
////    @State private var showDeleteConfirmation = false
////    
////    var body: some View {
////        HStack(alignment: .top, spacing: 8) {
////            if isCurrentUser {
////                Spacer()
////            } else {
////                // Avatar with online indicator
////                Button(action: {
////                    // Could navigate to user profile
////                }) {
////                    Circle()
////                        .fill(AppColors.accentColor.opacity(0.3))
////                        .frame(width: 32, height: 32)
////                        .overlay(
////                            Text(String(comment.username.prefix(2)))
////                                .font(.caption)
////                                .fontWeight(.bold)
////                                .foregroundColor(AppColors.accentColor)
////                        )
////                        .overlay(alignment: .bottomTrailing) {
////                            Circle()
////                                .fill(AppColors.bullCandleGreen)
////                                .frame(width: 10, height: 10)
////                                .overlay(
////                                    Circle()
////                                        .stroke(AppColors.drawerBackground, lineWidth: 1)
////                                )
////                        }
////                }
////                .buttonStyle(PlainButtonStyle())
////            }
////            
////            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
////                // User info row (only for other users)
////                if !isCurrentUser {
////                    HStack(spacing: 2) {
////                        Text(comment.username)
////                            .font(.caption)
////                            .fontWeight(.semibold)
////                            .foregroundColor(AppColors.whiteText.opacity(0.9))
////                        
////                        Circle()
////                            .fill(AppColors.whiteText.opacity(0.7))
////                            .frame(width: 3, height: 3)
////                            .padding(.horizontal, 3)
////                        
////                        Text("Member")
////                            .font(.caption)
////                            .foregroundColor(AppColors.greyText)
////                        
////                        Circle()
////                            .fill(AppColors.whiteText.opacity(0.7))
////                            .frame(width: 3, height: 3)
////                            .padding(.horizontal, 3)
////                        
////                        Image(systemName: "shield.pattern.checkered")
////                            .font(.caption2)
////                            .fontWeight(.bold)
////                            .foregroundColor(AppColors.accentColor)
////                        
////                        Text("0")
////                            .font(.caption2)
////                            .fontWeight(.semibold)
////                            .foregroundColor(AppColors.accentColor)
////                    }
////                }
////                
////                // Message bubble
////                Text(comment.text)
////                    .font(.subheadline)
////                    .foregroundColor(isCurrentUser ? .white : .primary)
////                    .padding(.horizontal, 12)
////                    .padding(.vertical, 8)
////                    .background(
////                        isCurrentUser ?
////                        AppColors.accentDarkColor :
////                        Color.gray.opacity(0.2)
////                    )
////                    .clipShape(commentBubbleShape(isFromCurrentUser: isCurrentUser))
////                    .contextMenu {
////                        // Delete (own comments only)
////                        if let onDelete = onDelete {
////                            Button(role: .destructive) {
////                                showDeleteConfirmation = true
////                            } label: {
////                                Label("Delete", systemImage: "trash")
////                            }
////                        }
////                        
////                        // Copy
////                        Button {
////                            UIPasteboard.general.string = comment.text
////                            appState.showSuccess("Copied to clipboard")
////                        } label: {
////                            Label("Copy", systemImage: "doc.on.doc")
////                        }
////                        
////                        // Report (other users' comments)
////                        if !isCurrentUser {
////                            Divider()
////                            Button(role: .destructive) {
////                                onReport()
////                            } label: {
////                                Label("Report", systemImage: "exclamationmark.triangle")
////                            }
////                        }
////                    }
////                
////                // Timestamp
////                Text(comment.createdAt.timeAgoDisplay())
////                    .font(.caption2)
////                    .foregroundColor(.secondary)
////            }
////            
////            if !isCurrentUser {
////                Spacer()
////            }
////        }
////        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
////            Button("Cancel", role: .cancel) { }
////            Button("Delete", role: .destructive) {
////                onDelete?()
////            }
////        } message: {
////            Text("Are you sure you want to delete this comment? This cannot be undone.")
////        }
////    }
////    
////    private func commentBubbleShape(isFromCurrentUser: Bool) -> UnevenRoundedRectangle {
////        if isFromCurrentUser {
////            return UnevenRoundedRectangle(
////                topLeadingRadius: 16,
////                bottomLeadingRadius: 16,
////                bottomTrailingRadius: 4,
////                topTrailingRadius: 16
////            )
////        } else {
////            return UnevenRoundedRectangle(
////                topLeadingRadius: 4,
////                bottomLeadingRadius: 16,
////                bottomTrailingRadius: 16,
////                topTrailingRadius: 16
////            )
////        }
////    }
////}
////
////// MARK: - Marker Detail Header
////
////struct MarkerDetailHeaderView: View {
////    let marker: ChartMarker
////    let isLiked: Bool
////    let likeCount: Int
////    let commentCount: Int
////    
////    var body: some View {
////        VStack(alignment: .leading, spacing: 16) {
////            // Main header row
////            HStack(spacing: 15) {
////                // Marker type icon with colored background
////                ZStack {
////                    Circle()
////                        .fill(marker.type.color.opacity(0.2))
////                        .frame(width: 56, height: 56)
////                    
////                    Circle()
////                        .stroke(marker.type.color.opacity(0.4), lineWidth: 2)
////                        .frame(width: 56, height: 56)
////                    
////                    Image(systemName: marker.type.icon)
////                        .font(.system(size: 24, weight: .semibold))
////                        .foregroundColor(marker.type.color)
////                }
////                
////                // Marker info
////                VStack(alignment: .leading, spacing: 4) {
////                    Text(marker.type.rawValue)
////                        .font(.title3)
////                        .fontWeight(.bold)
////                        .foregroundColor(AppColors.whiteText)
////                    
////                    // User info row
////                    HStack(spacing: 6) {
////                        Circle()
////                            .fill(AppColors.accentColor.opacity(0.3))
////                            .frame(width: 18, height: 18)
////                            .overlay(
////                                Text(String(marker.username.prefix(1)))
////                                    .font(.system(size: 9, weight: .bold))
////                                    .foregroundColor(AppColors.accentColor)
////                            )
////                        
////                        Text(marker.username)
////                            .font(.subheadline)
////                            .foregroundColor(AppColors.whiteText.opacity(0.8))
////                        
////                        Circle()
////                            .fill(AppColors.greyText.opacity(0.5))
////                            .frame(width: 3, height: 3)
////                        
////                        Text(marker.createdAt.timeAgoDisplay())
////                            .font(.caption)
////                            .foregroundColor(AppColors.greyText)
////                    }
////                }
////                
////                Spacer(minLength: 50)
////            }
////            
////            // Note (if present)
////            if let note = marker.note, !note.isEmpty {
////                Text(note)
////                    .font(.subheadline)
////                    .foregroundColor(AppColors.whiteText.opacity(0.85))
////                    .lineLimit(3)
////                    .padding(.top, 4)
////            }
////            
////            // Stats row
////            HStack(spacing: 16) {
////                // Likes
////                HStack(spacing: 4) {
////                    Image(systemName: isLiked ? "heart.fill" : "heart")
////                        .font(.caption)
////                        .foregroundColor(isLiked ? .red : AppColors.greyText)
////                    Text("\(likeCount)")
////                        .font(.caption)
////                        .fontWeight(.semibold)
////                        .foregroundColor(AppColors.greyText)
////                }
////                
////                // Comments
////                HStack(spacing: 4) {
////                    Image(systemName: "bubble.left")
////                        .font(.caption)
////                        .foregroundColor(AppColors.greyText)
////                    Text("\(commentCount)")
////                        .font(.caption)
////                        .fontWeight(.semibold)
////                        .foregroundColor(AppColors.greyText)
////                }
////                
////                Spacer()
////                
////                // Price badge
////                Text(String(format: "%.5f", marker.price))
////                    .font(.caption)
////                    .fontWeight(.semibold)
////                    .foregroundColor(marker.type.color)
////                    .padding(.horizontal, 10)
////                    .padding(.vertical, 4)
////                    .background(marker.type.color.opacity(0.15))
////                    .clipShape(Capsule())
////            }
////            
////            Divider()
////        }
////        .padding(.horizontal, 25)
////        .padding(.top, 25)
////        .padding(.bottom, 8)
////        .background(
////            LinearGradient(
////                colors: [
////                    marker.type.color.opacity(0.15),
////                    AppColors.sheetBackground
////                ],
////                startPoint: .top,
////                endPoint: .bottom
////            )
////        )
////    }
////}
////
////// MARK: - Marker Detail Footer
////
////struct MarkerDetailFooterView: View {
////    let marker: ChartMarker
////    @Binding var isLiked: Bool
////    @Binding var likeCount: Int
////    let isOwner: Bool
////    @Binding var showComments: Bool
////    let onLike: () -> Void
////    let onShare: () -> Void
////    let onReport: () -> Void
////    let onDelete: () -> Void
////    
////    @State private var likeScale: CGFloat = 1.0
////    
////    var body: some View {
////        HStack(spacing: 8) {
////            // Like button - capsule with animation
////            Button(action: {
////                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
////                    likeScale = 1.3
////                }
////                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
////                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
////                        likeScale = 1.0
////                    }
////                }
////                onLike()
////            }) {
////                HStack(spacing: 6) {
////                    Image(systemName: isLiked ? "heart.fill" : "heart")
////                        .font(.system(size: 16, weight: .medium))
////                        .foregroundColor(isLiked ? .white : AppColors.whiteText.opacity(0.9))
////                        .scaleEffect(likeScale)
////                    
////                    Text("\(likeCount)")
////                        .font(.subheadline)
////                        .fontWeight(.semibold)
////                        .foregroundColor(isLiked ? .white : AppColors.whiteText.opacity(0.9))
////                }
////                .frame(minWidth: 80)
////                .frame(height: 44)
////                .padding(.horizontal, 16)
////                .background(
////                    Capsule()
////                        .fill(isLiked ? Color.red : AppColors.gradientBackgroundDark.opacity(0.3))
////                )
////                .overlay(
////                    Capsule()
////                        .stroke(
////                            isLiked ? Color.red.opacity(0.5) : AppColors.whiteText.opacity(0.2),
////                            lineWidth: 1
////                        )
////                )
////            }
////            .compositingGroup()
////            
////            Spacer()
////            
////            // Share button - circular
////            DrawerActionButton(
////                imageName: "square.and.arrow.up",
////                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
////                foregroundColor: AppColors.whiteText.opacity(0.9),
////                strokeColor: AppColors.whiteText.opacity(0.2),
////                strokeWidth: 1,
////                action: onShare
////            )
////            
////            // Comment button - circular
////            DrawerActionButton(
////                imageName: "bubble.left",
////                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
////                foregroundColor: AppColors.whiteText.opacity(0.9),
////                strokeColor: AppColors.whiteText.opacity(0.2),
////                strokeWidth: 1,
////                action: { showComments = true }
////            )
////            
////            // Report or Delete button - circular
////            if isOwner {
////                DrawerActionButton(
////                    imageName: "trash",
////                    backgroundColor: AppColors.bearCandleRed.opacity(0.15),
////                    foregroundColor: AppColors.bearCandleRed,
////                    strokeColor: AppColors.bearCandleRed.opacity(0.4),
////                    strokeWidth: 1,
////                    action: onDelete
////                )
////            } else {
////                DrawerActionButton(
////                    imageName: "flag",
////                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
////                    foregroundColor: AppColors.whiteText.opacity(0.9),
////                    strokeColor: AppColors.whiteText.opacity(0.2),
////                    strokeWidth: 1,
////                    action: onReport
////                )
////            }
////        }
////        .padding(.horizontal, 25)
////        .padding(.vertical, 16)
////        .background(AppColors.sheetBackground)
////        .compositingGroup()
////    }
////}
////
////// MARK: - Marker Info Content
////
////struct MarkerInfoContent: View {
////    let marker: ChartMarker
////    
////    var body: some View {
////        VStack(alignment: .leading, spacing: 24) {
////            // Price & Time info card
////            infoCard {
////                VStack(spacing: 12) {
////                    infoRow(
////                        icon: "chart.line.uptrend.xyaxis",
////                        label: "Price Level",
////                        value: String(format: "%.5f", marker.price),
////                        valueColor: marker.type.color
////                    )
////                    
////                    Divider()
////                        .background(AppColors.whiteText.opacity(0.1))
////                    
////                    infoRow(
////                        icon: "clock",
////                        label: "Created",
////                        value: marker.createdAt.formatted(date: .abbreviated, time: .shortened)
////                    )
////                    
////                    if marker.type.hasHorizontalLine, let linePrice = marker.horizontalLinePrice {
////                        Divider()
////                            .background(AppColors.whiteText.opacity(0.1))
////                        
////                        infoRow(
////                            icon: "minus",
////                            label: "Line Price",
////                            value: String(format: "%.5f", linePrice),
////                            valueColor: marker.type.color
////                        )
////                    }
////                }
////            }
////            
////            // Type-specific content
////            typeSpecificSection
////        }
////    }
////    
////    @ViewBuilder
////    private var typeSpecificSection: some View {
////        switch marker.type {
////        case .predictionTarget:
////            predictionSection
////        case .alert:
////            alertSection
////        case .support, .resistance:
////            levelSection
////        case .trendline:
////            trendlineSection
////        case .pattern:
////            patternSection
////        case .indicator:
////            indicatorSection
////        case .emoji:
////            emojiSection
////        case .poll:
////            pollSection
////        case .entry, .exit, .stopLoss, .takeProfit:
////            tradeSection
////        default:
////            EmptyView()
////        }
////    }
////    
////    @ViewBuilder
////    private var predictionSection: some View {
////        if let targetPrice = marker.targetPrice {
////            let entryPrice = marker.horizontalLinePrice ?? marker.price
////            let percentChange = ((targetPrice - entryPrice) / entryPrice) * 100
////            let isLong = percentChange > 0
////            
////            infoCard {
////                VStack(spacing: 16) {
////                    HStack {
////                        Image(systemName: isLong ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
////                            .font(.title2)
////                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
////                        
////                        Text(isLong ? "Long Position" : "Short Position")
////                            .font(.headline)
////                            .fontWeight(.semibold)
////                            .foregroundColor(AppColors.whiteText)
////                        
////                        Spacer()
////                        
////                        Text(String(format: "%+.2f%%", percentChange))
////                            .font(.headline)
////                            .fontWeight(.bold)
////                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
////                    }
////                    
////                    Divider().background(AppColors.whiteText.opacity(0.1))
////                    
////                    HStack(spacing: 20) {
////                        VStack(alignment: .leading, spacing: 4) {
////                            Text("Entry").font(.caption).foregroundColor(AppColors.greyText)
////                            Text(String(format: "%.5f", entryPrice))
////                                .font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                        }
////                        Image(systemName: "arrow.right").font(.caption).foregroundColor(AppColors.greyText)
////                        VStack(alignment: .leading, spacing: 4) {
////                            Text("Target").font(.caption).foregroundColor(AppColors.greyText)
////                            Text(String(format: "%.5f", targetPrice))
////                                .font(.subheadline).fontWeight(.semibold)
////                                .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
////                        }
////                        Spacer()
////                    }
////                }
////            }
////        }
////    }
////    
////    @ViewBuilder private var alertSection: some View {
////        if let severity = marker.alertSeverity {
////            infoCard {
////                HStack {
////                    Circle().fill(severity.color).frame(width: 12, height: 12)
////                    Text("Severity: \(severity.rawValue)")
////                        .font(.subheadline).fontWeight(.medium).foregroundColor(AppColors.whiteText)
////                    Spacer()
////                }
////            }
////        }
////    }
////    
////    @ViewBuilder private var levelSection: some View {
////        infoCard {
////            HStack {
////                Image(systemName: marker.type == .support ? "arrow.down.to.line" : "arrow.up.to.line")
////                    .font(.title3).foregroundColor(marker.type.color)
////                VStack(alignment: .leading, spacing: 2) {
////                    Text(marker.type == .support ? "Support Level" : "Resistance Level")
////                        .font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                    Text("Price may \(marker.type == .support ? "bounce up" : "reverse down") at this level")
////                        .font(.caption).foregroundColor(AppColors.greyText)
////                }
////                Spacer()
////            }
////        }
////    }
////    
////    @ViewBuilder private var trendlineSection: some View {
////        if let direction = marker.trendlineDirection {
////            let color: Color = direction == .up ? AppColors.bullCandleGreen : direction == .down ? AppColors.bearCandleRed : AppColors.greyText
////            infoCard {
////                HStack {
////                    Image(systemName: direction == .up ? "arrow.up.right" : direction == .down ? "arrow.down.right" : "arrow.right")
////                        .font(.title3).foregroundColor(color)
////                    Text(direction.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                    Spacer()
////                }
////            }
////        }
////    }
////    
////    @ViewBuilder private var patternSection: some View {
////        if let pattern = marker.chartPattern {
////            infoCard {
////                HStack {
////                    Image(systemName: "chart.bar.doc.horizontal").font(.title3).foregroundColor(marker.type.color)
////                    Text(pattern.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                    Spacer()
////                }
////            }
////        }
////    }
////    
////    @ViewBuilder private var indicatorSection: some View {
////        if let indicator = marker.selectedIndicator {
////            infoCard {
////                HStack {
////                    Image(systemName: "waveform.path.ecg").font(.title3).foregroundColor(marker.type.color)
////                    VStack(alignment: .leading, spacing: 2) {
////                        Text("Indicator Signal").font(.caption).foregroundColor(AppColors.greyText)
////                        Text(indicator).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                    }
////                    Spacer()
////                }
////            }
////        }
////    }
////    
////    @ViewBuilder private var emojiSection: some View {
////        if let emoji = marker.selectedEmoji {
////            infoCard { HStack { Text(emoji).font(.system(size: 44)); Spacer() } }
////        }
////    }
////    
////    @ViewBuilder private var pollSection: some View {
////        if let question = marker.pollQuestion, let options = marker.pollOptions {
////            infoCard {
////                VStack(alignment: .leading, spacing: 12) {
////                    Text(question).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                    ForEach(options) { option in
////                        PollOptionRow(option: option, totalVotes: options.reduce(0) { $0 + $1.voteCount }, hasVoted: marker.userPollVote == option.id)
////                    }
////                }
////            }
////        }
////    }
////    
////    @ViewBuilder private var tradeSection: some View {
////        let isEntry = marker.type == .entry || marker.type == .takeProfit
////        infoCard {
////            HStack {
////                Image(systemName: isEntry ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
////                    .font(.title3).foregroundColor(isEntry ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
////                VStack(alignment: .leading, spacing: 2) {
////                    Text(marker.type.rawValue).font(.subheadline).fontWeight(.semibold).foregroundColor(AppColors.whiteText)
////                    if let linePrice = marker.horizontalLinePrice {
////                        Text(String(format: "%.5f", linePrice)).font(.caption).foregroundColor(AppColors.greyText)
////                    }
////                }
////                Spacer()
////            }
////        }
////    }
////    
////    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
////        content()
////            .padding(16)
////            .frame(maxWidth: .infinity, alignment: .leading)
////            .background(AppColors.whiteText.opacity(0.05))
////            .cornerRadius(16)
////            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1))
////    }
////    
////    private func infoRow(icon: String, label: String, value: String, valueColor: Color = AppColors.whiteText) -> some View {
////        HStack {
////            Image(systemName: icon).font(.subheadline).foregroundColor(AppColors.greyText).frame(width: 20)
////            Text(label).font(.subheadline).foregroundColor(AppColors.greyText)
////            Spacer()
////            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(valueColor)
////        }
////    }
////}
////
////// MARK: - Poll Option Row
////
////struct PollOptionRow: View {
////    let option: PollOption
////    let totalVotes: Int
////    let hasVoted: Bool
////    
////    private var percentage: Double {
////        guard totalVotes > 0 else { return 0 }
////        return Double(option.voteCount) / Double(totalVotes)
////    }
////    
////    var body: some View {
////        VStack(alignment: .leading, spacing: 6) {
////            HStack {
////                Text(option.text).font(.subheadline).fontWeight(hasVoted ? .semibold : .regular)
////                    .foregroundColor(hasVoted ? AppColors.accentColor : AppColors.whiteText)
////                Spacer()
////                Text("\(Int(percentage * 100))%").font(.caption).fontWeight(.semibold).foregroundColor(AppColors.greyText)
////            }
////            GeometryReader { geometry in
////                ZStack(alignment: .leading) {
////                    RoundedRectangle(cornerRadius: 4).fill(AppColors.whiteText.opacity(0.1)).frame(height: 6)
////                    RoundedRectangle(cornerRadius: 4).fill(hasVoted ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
////                        .frame(width: geometry.size.width * percentage, height: 6)
////                }
////            }.frame(height: 6)
////        }.padding(.vertical, 6)
////    }
////}
////
////// MARK: - Date Extension
////
////extension Date {
////    func timeAgoDisplay() -> String {
////        let formatter = RelativeDateTimeFormatter()
////        formatter.unitsStyle = .abbreviated
////        return formatter.localizedString(for: self, relativeTo: Date())
////    }
////}
