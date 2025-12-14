//
//  MarkerDetailView.swift
//  traders_guild
//
//  Comprehensive marker detail view with:
//  - Header: Gradient background, icon, user info, stats
//  - Tabs: Info (type-specific) and Comments
//  - Footer: Circular action buttons matching profile view design
//
//  NOTE: Requires KeyboardHandler.swift in your project (shared utility)

import SwiftUI
import Combine

// MARK: - Marker Detail View

struct MarkerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject var markerManager: MarkerManager
    
    let marker: ChartMarker
    @Binding var selectedDetent: PresentationDetent
    
    @State private var selectedTab: MarkerTab = .info
    @State private var commentText: String = ""
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var comments: [MarkerComment] = []
    @State private var isSendingComment: Bool = false
    @State private var showDeleteMarkerConfirmation: Bool = false
    @State private var showReportConfirmation: Bool = false
    @StateObject private var keyboardHandler = KeyboardHandler()
    @FocusState private var isCommentInputFocused: Bool
    
    enum MarkerTab: String, CaseIterable {
        case info = "Info"
        case comments = "Comments"
    }
    
    init(marker: ChartMarker, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
        self.marker = marker
        self.markerManager = markerManager
        self._selectedDetent = selectedDetent
        
        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
        _likeCount = State(initialValue: marker.likeCount)
        _comments = State(initialValue: marker.comments)
    }
    
    private let footerHeight: CGFloat = 70
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Header with gradient
                MarkerDetailHeaderView(
                    marker: marker,
                    isLiked: isLiked,
                    likeCount: likeCount,
                    commentCount: comments.count
                )
                
                // Tab Headers
                tabHeader
                
                Divider()
                
                // Content area
                if selectedTab == .info {
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
                        isOwner: marker.userId == markerManager.userId,
                        onLike: handleLike,
                        onShare: handleShare,
                        onReport: { showReportConfirmation = true },
                        onDelete: { showDeleteMarkerConfirmation = true }
                    )
                } else {
                    commentsTabContent
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
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .ignoresSafeArea(.keyboard)
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
    }
    
    // MARK: - Comments Tab Content
    
    private var commentsTabContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    if comments.isEmpty {
                        emptyCommentsView
                            .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
                                MessageStyleCommentRow(
                                    comment: comment,
                                    isCurrentUser: comment.userId == markerManager.userId,
                                    onDelete: comment.userId == markerManager.userId ? {
                                        handleDeleteComment(comment)
                                    } : nil
                                )
                                .id(comment.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isCommentInputFocused = false
                }
                .onChange(of: comments.count) { _ in
                    if let lastComment = comments.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastComment.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Comment input
            commentInputView
                .padding(.bottom, keyboardHandler.keyboardHeight > 0 ? keyboardHandler.keyboardHeight - footerHeight : 0)
                .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
            
            // Footer - hidden when keyboard is open
            if keyboardHandler.keyboardHeight == 0 {
                Divider()
                
                MarkerDetailFooterView(
                    marker: marker,
                    isLiked: $isLiked,
                    likeCount: $likeCount,
                    isOwner: marker.userId == markerManager.userId,
                    onLike: handleLike,
                    onShare: handleShare,
                    onReport: { showReportConfirmation = true },
                    onDelete: { showDeleteMarkerConfirmation = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHandler.keyboardHeight)
    }
    
    // MARK: - Tab Header
    
    private var tabHeader: some View {
        HStack(spacing: 0) {
            ForEach(MarkerTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                        isCommentInputFocused = false
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
                            
                            if tab == .comments && !comments.isEmpty {
                                Text("\(comments.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 12)
        .background(AppColors.sheetBackground)
    }
    
    // MARK: - Comment Input View
    
    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                // User avatar
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(appState.currentUser?.name.prefix(2) ?? "??"))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
                
                // Text input
                HStack(spacing: 8) {
                    TextField("Add a comment...", text: $commentText, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(1...4)
                        .submitLabel(.send)
                        .focused($isCommentInputFocused)
                        .disabled(isSendingComment)
                        .onSubmit {
                            handleAddComment()
                        }
                    
                    // Send button
                    if isSendingComment {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 28, height: 28)
                    } else {
                        Button(action: handleAddComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(
                                    commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AppColors.greyText.opacity(0.4)
                                    : AppColors.accentColor
                                )
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.whiteText.opacity(0.08))
                .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppColors.sheetBackground)
    }
    
    // MARK: - Empty Comments View
    
    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accentColor.opacity(0.6))
            }
            
            VStack(spacing: 6) {
                Text("No comments yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.whiteText)
                
                Text("Be the first to share your thoughts")
                    .font(.subheadline)
                    .foregroundColor(AppColors.greyText)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func handleLike() {
        HapticFeedback.light.trigger()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }
        
        Task {
            do {
                // TODO: Call API
                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
                    markerManager.markers[index].isLikedByCurrentUser = isLiked
                    markerManager.markers[index].likeCount = likeCount
                }
            } catch {
                withAnimation {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }
                appState.showError(error, title: "Failed to Like", style: .toast)
            }
        }
    }
    
    private func handleShare() {
        HapticFeedback.medium.trigger()
        // TODO: Implement share
        print("Share marker: \(marker.id)")
    }
    
    private func handleReport() {
        HapticFeedback.medium.trigger()
        Task {
            // TODO: Call API
            appState.showSuccess("Marker reported. Thank you for your feedback.")
        }
    }
    
    private func handleDelete() {
        HapticFeedback.warning.trigger()
        
        Task {
            do {
                markerManager.markers.removeAll { $0.id == marker.id }
                appState.showSuccess("Marker deleted")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Delete", style: .toast)
            }
        }
    }
    
    private func handleAddComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isSendingComment = true
        isCommentInputFocused = false
        
        let newComment = MarkerComment(
            userId: markerManager.userId,
            username: appState.currentUser?.name ?? "Unknown",
            text: trimmedText,
            createdAt: Date()
        )
        
        withAnimation(.easeOut(duration: 0.2)) {
            comments.append(newComment)
        }
        commentText = ""
        
        Task {
            do {
                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
                    markerManager.markers[index].comments.append(newComment)
                }
                HapticFeedback.light.trigger()
            } catch {
                comments.removeAll { $0.id == newComment.id }
                appState.showError(error, title: "Failed to Add Comment", style: .toast)
            }
            isSendingComment = false
        }
    }
    
    private func handleDeleteComment(_ comment: MarkerComment) {
        HapticFeedback.light.trigger()
        
        withAnimation(.easeOut(duration: 0.2)) {
            comments.removeAll { $0.id == comment.id }
        }
        
        Task {
            do {
                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
                    markerManager.markers[index].comments.removeAll { $0.id == comment.id }
                }
            } catch {
                comments.append(comment)
                appState.showError(error, title: "Failed to Delete Comment", style: .toast)
            }
        }
    }
}

// MARK: - Marker Detail Header

struct MarkerDetailHeaderView: View {
    let marker: ChartMarker
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
                    
                    // User info row
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.accentColor.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text(String(marker.username.prefix(1)))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.accentColor)
                            )
                        
                        Text(marker.username)
                            .font(.subheadline)
                            .foregroundColor(AppColors.whiteText.opacity(0.8))
                        
                        Circle()
                            .fill(AppColors.greyText.opacity(0.5))
                            .frame(width: 3, height: 3)
                        
                        Text(marker.createdAt.timeAgoDisplay())
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

// MARK: - Marker Detail Footer

struct MarkerDetailFooterView: View {
    let marker: ChartMarker
    @Binding var isLiked: Bool
    @Binding var likeCount: Int
    let isOwner: Bool
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
            
            Spacer()
            
            // Share button - circular
            DrawerActionButton(
                imageName: "square.and.arrow.up",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.3),
                foregroundColor: AppColors.whiteText.opacity(0.9),
                strokeColor: AppColors.whiteText.opacity(0.2),
                strokeWidth: 1,
                action: onShare
            )
            
            // Report or Delete button - circular
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
    }
}

// MARK: - Message-Style Comment Row

struct MessageStyleCommentRow: View {
    let comment: MarkerComment
    let isCurrentUser: Bool
    var onDelete: (() -> Void)? = nil
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Avatar
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(comment.username.prefix(2)))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(comment.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(isCurrentUser ? .white : AppColors.whiteText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser
                        ? AppColors.accentColor
                        : AppColors.whiteText.opacity(0.1)
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isCurrentUser ? 18 : 4,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: isCurrentUser ? 4 : 18
                        )
                    )
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = comment.text
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        if let onDelete = onDelete {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                
                Text(comment.createdAt.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText.opacity(0.7))
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .alert("Delete Comment", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
}

// MARK: - Marker Info Content

struct MarkerInfoContent: View {
    let marker: ChartMarker
    
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
    
    // MARK: - Type-Specific Section
    
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
    
    // MARK: - Prediction Section
    
    @ViewBuilder
    private var predictionSection: some View {
        if let targetPrice = marker.targetPrice {
            let entryPrice = marker.horizontalLinePrice ?? marker.price
            let percentChange = ((targetPrice - entryPrice) / entryPrice) * 100
            let isLong = percentChange > 0
            
            infoCard {
                VStack(spacing: 16) {
                    // Direction indicator
                    HStack {
                        Image(systemName: isLong ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                        
                        Text(isLong ? "Long Position" : "Short Position")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        
                        Spacer()
                        
                        Text(String(format: "%+.2f%%", percentChange))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                    }
                    
                    Divider()
                        .background(AppColors.whiteText.opacity(0.1))
                    
                    // Price levels
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(String(format: "%.5f", entryPrice))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.whiteText)
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.caption)
                                .foregroundColor(AppColors.greyText)
                            Text(String(format: "%.5f", targetPrice))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(isLong ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Alert Section
    
    @ViewBuilder
    private var alertSection: some View {
        if let severity = marker.alertSeverity {
            infoCard {
                HStack {
                    Circle()
                        .fill(severity.color)
                        .frame(width: 12, height: 12)
                    
                    Text("Severity: \(severity.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Level Section
    
    @ViewBuilder
    private var levelSection: some View {
        infoCard {
            HStack {
                Image(systemName: marker.type == .support ? "arrow.down.to.line" : "arrow.up.to.line")
                    .font(.title3)
                    .foregroundColor(marker.type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.type == .support ? "Support Level" : "Resistance Level")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text("Price may \(marker.type == .support ? "bounce up" : "reverse down") at this level")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Trendline Section
    
    @ViewBuilder
    private var trendlineSection: some View {
        if let direction = marker.trendlineDirection {
            let color: Color = {
                switch direction {
                case .up: return AppColors.bullCandleGreen
                case .down: return AppColors.bearCandleRed
                case .sideways: return AppColors.greyText
                }
            }()
            
            infoCard {
                HStack {
                    Image(systemName: direction == .up ? "arrow.up.right" : direction == .down ? "arrow.down.right" : "arrow.right")
                        .font(.title3)
                        .foregroundColor(color)
                    
                    Text(direction.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Pattern Section
    
    @ViewBuilder
    private var patternSection: some View {
        if let pattern = marker.chartPattern {
            infoCard {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title3)
                        .foregroundColor(marker.type.color)
                    
                    Text(pattern.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Indicator Section
    
    @ViewBuilder
    private var indicatorSection: some View {
        if let indicator = marker.selectedIndicator {
            infoCard {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3)
                        .foregroundColor(marker.type.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Indicator Signal")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        Text(indicator)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Emoji Section
    
    @ViewBuilder
    private var emojiSection: some View {
        if let emoji = marker.selectedEmoji {
            infoCard {
                HStack {
                    Text(emoji)
                        .font(.system(size: 44))
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Poll Section
    
    @ViewBuilder
    private var pollSection: some View {
        if let question = marker.pollQuestion, let options = marker.pollOptions {
            infoCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    ForEach(options) { option in
                        PollOptionRow(
                            option: option,
                            totalVotes: options.reduce(0) { $0 + $1.voteCount },
                            hasVoted: marker.userPollVote == option.id
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Trade Section
    
    @ViewBuilder
    private var tradeSection: some View {
        let isEntry = marker.type == .entry || marker.type == .takeProfit
        
        infoCard {
            HStack {
                Image(systemName: isEntry ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(isEntry ? AppColors.bullCandleGreen : AppColors.bearCandleRed)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    if let linePrice = marker.horizontalLinePrice {
                        Text(String(format: "%.5f", linePrice))
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.whiteText.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.whiteText.opacity(0.08), lineWidth: 1)
            )
    }
    
    private func infoRow(icon: String, label: String, value: String, valueColor: Color = AppColors.whiteText) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Poll Option Row

struct PollOptionRow: View {
    let option: PollOption
    let totalVotes: Int
    let hasVoted: Bool
    
    private var percentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(option.voteCount) / Double(totalVotes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.text)
                    .font(.subheadline)
                    .fontWeight(hasVoted ? .semibold : .regular)
                    .foregroundColor(hasVoted ? AppColors.accentColor : AppColors.whiteText)
                
                Spacer()
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.whiteText.opacity(0.1))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasVoted ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 6)
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


