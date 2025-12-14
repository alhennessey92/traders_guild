

//
//  MarkerDetailView.swift
//  traders_guild
//
//  Comprehensive marker detail view with:
//  - Header: Icon, name, user, timestamp
//  - Tabs: Info (type-specific) and Comments
//  - Footer: Action buttons (like, share, report)
//

import SwiftUI

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
    @State private var keyboardHeight: CGFloat = 0
    
    enum MarkerTab: String, CaseIterable {
        case info = "Info"
        case comments = "Comments"
    }
    
    init(marker: ChartMarker, markerManager: MarkerManager, selectedDetent: Binding<PresentationDetent>) {
        self.marker = marker
        self.markerManager = markerManager
        self._selectedDetent = selectedDetent
        
        // Initialize state from marker
        _isLiked = State(initialValue: marker.isLikedByCurrentUser)
        _likeCount = State(initialValue: marker.likeCount)
        _comments = State(initialValue: marker.comments)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            MarkerDetailHeaderView(marker: marker)
            
            // Tab Headers - Fixed
            tabHeader
            
            Divider()
            
            // Content area - grows/shrinks with keyboard
            ZStack(alignment: .bottom) {
                // Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    if selectedTab == .info {
                        MarkerInfoContent(marker: marker)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 20)
                    } else {
                        // Comments list
                        MarkerCommentsListContent(
                            comments: $comments,
                            currentUserId: markerManager.userId
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, selectedTab == .comments ? 70 : 20) // Space for input
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            hideKeyboard()
                        }
                )
                
                // Comment Input - Overlaid at bottom
                if selectedTab == .comments {
                    VStack(spacing: 0) {
                        Divider()
                        commentInputView
                    }
                    .background(AppColors.sheetBackground)
                }
            }
            .padding(.bottom, keyboardHeight)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            
            // Footer - Fixed at bottom, goes off screen with keyboard
            if keyboardHeight == 0 {
                Divider()
                MarkerDetailFooterView(
                    marker: marker,
                    isLiked: $isLiked,
                    likeCount: $likeCount,
                    onLike: handleLike,
                    onShare: handleShare,
                    onReport: handleReport,
                    onDelete: marker.userId == markerManager.userId ? handleDelete : nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .onAppear {
            subscribeToKeyboardEvents()
        }
    }
    
    // MARK: - Tab Header
    private var tabHeader: some View {
        HStack(spacing: 0) {
            ForEach(MarkerTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
                            
                            // Comment count badge
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
                        
                        // Active indicator
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
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField("Add a comment...", text: $commentText, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .padding(.leading, 5)
                    .onSubmit {
                        handleAddComment()
                    }
                
                Button(action: {
                    handleAddComment()
                }) {
                    Image(systemName: "chevron.forward.2")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppColors.gradientBackgroundDark.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .padding(.leading, 2)
                        .background(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.whiteText.opacity(0.3) : AppColors.whiteText)
                        .clipShape(Capsule())
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.leading, 10)
            .frame(minHeight: 44)
            .background(AppColors.whiteText.opacity(0.08))
            .cornerRadius(25)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Keyboard Handling
    
    private func subscribeToKeyboardEvents() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = keyboardFrame.height
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Actions
    
    private func handleLike() {
        HapticFeedback.light.trigger()
        
        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        Task {
            do {
                // TODO: Call API to like/unlike marker
                // try await appState.toggleMarkerLike(markerId: marker.id)
                
                // Update marker in manager
                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
                    markerManager.markers[index].isLikedByCurrentUser = isLiked
                    markerManager.markers[index].likeCount = likeCount
                }
            } catch {
                // Revert on error
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
                appState.showError(error, title: "Failed to Like", style: .toast)
            }
        }
    }
    
    private func handleShare() {
        HapticFeedback.medium.trigger()
        // TODO: Implement share functionality
        // - Deep link to marker
        // - Screenshot of marker on chart
        // - Share via iOS share sheet
        print("Share marker: \(marker.id)")
    }
    
    private func handleReport() {
        HapticFeedback.medium.trigger()
        // TODO: Implement report functionality
        // - Show report reasons
        // - Submit report to API
        print("Report marker: \(marker.id)")
    }
    
    private func handleDelete() {
        HapticFeedback.warning.trigger()
        
        Task {
            do {
                // TODO: Call API to delete marker
                // try await appState.deleteMarker(markerId: marker.id)
                
                // Remove from manager
                markerManager.markers.removeAll { $0.id == marker.id }
                
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Delete", style: .toast)
            }
        }
    }
    
    private func handleAddComment() {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        HapticFeedback.medium.trigger()
        
        let newComment = MarkerComment(
            userId: markerManager.userId,
            username: appState.currentUser?.name ?? "Unknown",
            text: commentText,
            createdAt: Date()
        )
        
        // Optimistic update
        comments.append(newComment)
        commentText = ""
        
        Task {
            do {
                // TODO: Call API to add comment
                // try await appState.addMarkerComment(markerId: marker.id, text: newComment.text)
                
                // Update marker in manager
                if let index = markerManager.markers.firstIndex(where: { $0.id == marker.id }) {
                    markerManager.markers[index].comments.append(newComment)
                }
            } catch {
                // Revert on error
                comments.removeLast()
                appState.showError(error, title: "Failed to Add Comment", style: .toast)
            }
        }
    }
}

// MARK: - Marker Detail Header

struct MarkerDetailHeaderView: View {
    let marker: ChartMarker
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top section with icon and marker info
            HStack(spacing: 15) {
                // Marker type icon
                ZStack {
                    Circle()
                        .fill(marker.type.color.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: marker.type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(marker.type.color)
                }
                
                // Marker info
                VStack(alignment: .leading, spacing: 4) {
                    Text(marker.type.rawValue)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    HStack(spacing: 6) {
                        Text("by \(marker.username)")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                        
                        Circle()
                            .fill(AppColors.greyText)
                            .frame(width: 3, height: 3)
                        
                        Text(marker.createdAt.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                }
                
                Spacer(minLength: 60) // Space for dismiss button
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)
            
            // Price and timestamp info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.greyText)
                    Text(marker.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text(String(format: "%.5f", marker.price))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    
                    // Show horizontal line price if different
                    if let linePrice = marker.horizontalLinePrice, linePrice != marker.price {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.greyText)
                        Text(String(format: "%.5f", linePrice))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.greyText)
                    }
                }
            }
            .padding(.horizontal, 25)
            
            Divider()
        }
        .background(
            LinearGradient(
                colors: [
                    AppColors.gradientBackgroundDark.opacity(0.3),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Marker Info Content

struct MarkerInfoContent: View {
    let marker: ChartMarker
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Basic info section (always shown)
            basicInfoSection
            
            // Type-specific sections
            typeSpecificSections
            
            // Note section (if present)
            if let note = marker.note, !note.isEmpty {
                noteSection(note)
            }
        }
    }
    
    // MARK: - Basic Info
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Basic Info", icon: "info.circle")
            
            VStack(spacing: 8) {
                infoRow(label: "Type", value: marker.type.rawValue, color: marker.type.color)
                infoRow(label: "Created", value: marker.createdAt.formatted(date: .long, time: .shortened))
                infoRow(label: "Price", value: String(format: "%.5f", marker.price))
                
                if marker.type.hasHorizontalLine, let linePrice = marker.horizontalLinePrice {
                    infoRow(label: "Line Price", value: String(format: "%.5f", linePrice))
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Type-Specific Sections
    
    @ViewBuilder
    private var typeSpecificSections: some View {
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
            
        case .entry, .exit:
            tradeSection
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Prediction Section
    
    @ViewBuilder
    private var predictionSection: some View {
        if let targetPrice = marker.targetPrice {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Prediction Details", icon: "staroflife.circle")
                
                VStack(spacing: 8) {
                    infoRow(label: "Entry Price", value: String(format: "%.5f", marker.horizontalLinePrice ?? marker.price))
                    infoRow(label: "Target Price", value: String(format: "%.5f", targetPrice))
                    
                    // Calculate profit/loss percentage
                    let entryPrice = marker.horizontalLinePrice ?? marker.price
                    let percentChange = ((targetPrice - entryPrice) / entryPrice) * 100
                    let direction = percentChange > 0 ? "Long" : "Short"
                    let color = percentChange > 0 ? AppColors.bullCandleGreen : AppColors.bearCandleRed
                    
                    infoRow(
                        label: "Direction",
                        value: direction,
                        color: color
                    )
                    
                    infoRow(
                        label: "Target Move",
                        value: String(format: "%+.2f%%", percentChange),
                        color: color
                    )
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Alert Section
    
    @ViewBuilder
    private var alertSection: some View {
        if let severity = marker.alertSeverity {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Alert Details", icon: "bell.circle")
                
                VStack(spacing: 8) {
                    infoRow(
                        label: "Severity",
                        value: severity.rawValue,
                        color: severity.color
                    )
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Level Section
    
    @ViewBuilder
    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(marker.type == .support ? "Support Level" : "Resistance Level", icon: "chart.line.uptrend.xyaxis")
            
            VStack(spacing: 8) {
                if let linePrice = marker.horizontalLinePrice {
                    infoRow(label: "Level Price", value: String(format: "%.5f", linePrice))
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Trendline Section
    
    @ViewBuilder
    private var trendlineSection: some View {
        if let direction = marker.trendlineDirection {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Trendline", icon: "chart.line.uptrend.xyaxis.circle")
                
                VStack(spacing: 8) {
                    let color: Color = {
                        switch direction {
                        case .up: return AppColors.bullCandleGreen
                        case .down: return AppColors.bearCandleRed
                        case .sideways: return AppColors.greyText
                        }
                    }()
                    
                    infoRow(label: "Direction", value: direction.rawValue, color: color)
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Pattern Section
    
    @ViewBuilder
    private var patternSection: some View {
        if let pattern = marker.chartPattern {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Chart Pattern", icon: "circle.hexagongrid.circle")
                
                VStack(spacing: 8) {
                    infoRow(label: "Pattern", value: pattern.rawValue)
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Indicator Section
    
    @ViewBuilder
    private var indicatorSection: some View {
        if let indicator = marker.selectedIndicator {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Indicator Signal", icon: "star.circle")
                
                VStack(spacing: 8) {
                    infoRow(label: "Indicator", value: indicator)
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Emoji Section
    
    @ViewBuilder
    private var emojiSection: some View {
        if let emoji = marker.selectedEmoji {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Reaction", icon: "face.smiling")
                
                HStack {
                    Text(emoji)
                        .font(.system(size: 40))
                    Spacer()
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Poll Section
    
    @ViewBuilder
    private var pollSection: some View {
        if let question = marker.pollQuestion, let options = marker.pollOptions {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Poll", icon: "newspaper.circle")
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    ForEach(options) { option in
                        PollOptionRow(
                            option: option,
                            totalVotes: options.reduce(0) { $0 + $1.voteCount },
                            hasVoted: marker.userPollVote == option.id
                        )
                    }
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Trade Section
    
    @ViewBuilder
    private var tradeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(marker.type == .entry ? "Entry Signal" : "Exit Signal", icon: marker.type.icon)
            
            VStack(spacing: 8) {
                if let linePrice = marker.horizontalLinePrice {
                    infoRow(label: marker.type == .entry ? "Entry Price" : "Exit Price", value: String(format: "%.5f", linePrice))
                }
            }
            .padding()
            .background(AppColors.gradientBackgroundDark.opacity(0.15))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Note Section
    
    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Note", icon: "text.bubble")
            
            Text(note)
                .font(.subheadline)
                .foregroundColor(AppColors.whiteText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.gradientBackgroundDark.opacity(0.15))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.accentColor)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.whiteText)
        }
        .padding(.top, 8)
    }
    
    private func infoRow(label: String, value: String, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color ?? AppColors.whiteText)
        }
        .padding(.vertical, 4)
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
                
                Text("\(option.voteCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.greyText)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.gradientBackgroundDark.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasVoted ? AppColors.accentColor : AppColors.greyText.opacity(0.5))
                        .frame(width: geometry.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Marker Comments List Content (Comments Only - No Input)

struct MarkerCommentsListContent: View {
    @Binding var comments: [MarkerComment]
    let currentUserId: String
    
    var body: some View {
        VStack(spacing: 12) {
            if comments.isEmpty {
                emptyCommentsView
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(comments.sorted(by: { $0.createdAt < $1.createdAt })) { comment in
                        MessageStyleCommentRow(
                            comment: comment,
                            isCurrentUser: comment.userId == currentUserId
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyCommentsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(AppColors.greyText.opacity(0.5))
            
            Text("No comments yet")
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
            
            Text("Be the first to comment on this marker")
                .font(.caption)
                .foregroundColor(AppColors.greyText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Message-Style Comment Row

struct MessageStyleCommentRow: View {
    let comment: MarkerComment
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isCurrentUser {
                Spacer()
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
            
            // Message bubble
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Username (if not current user)
                if !isCurrentUser {
                    Text(comment.username)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                // Comment text
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(isCurrentUser ? .white : AppColors.whiteText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isCurrentUser ?
                        AppColors.accentColor.opacity(0.8) :
                        AppColors.gradientBackgroundDark.opacity(0.3)
                    )
                    .clipShape(messageBubbleShape(isFromCurrentUser: isCurrentUser))
                
                // Timestamp
                Text(comment.createdAt.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundColor(AppColors.greyText)
            }
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
    
    private func messageBubbleShape(isFromCurrentUser: Bool) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: isFromCurrentUser ? 16 : 4,
            bottomTrailingRadius: isFromCurrentUser ? 4 : 16,
            topTrailingRadius: 16
        )
    }
}

// MARK: - Marker Detail Footer

struct MarkerDetailFooterView: View {
    let marker: ChartMarker
    @Binding var isLiked: Bool
    @Binding var likeCount: Int
    let onLike: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            // Like button
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isLiked ? .red : AppColors.whiteText.opacity(0.9))
                    
                    Text("\(likeCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isLiked
                    ? Color.red.opacity(0.2)
                    : AppColors.gradientBackgroundDark.opacity(0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isLiked
                            ? Color.red.opacity(0.3)
                            : AppColors.whiteText.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Share button
            DrawerActionButton(
                imageName: "square.and.arrow.up",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                foregroundColor: AppColors.whiteText.opacity(0.9),
                strokeColor: AppColors.whiteText.opacity(0.3),
                strokeWidth: 0.5,
                action: onShare
            )
            
            // Report/Delete button
            if let onDelete = onDelete {
                DrawerActionButton(
                    imageName: "trash",
                    backgroundColor: AppColors.bearCandleRed.opacity(0.2),
                    foregroundColor: AppColors.bearCandleRed,
                    strokeColor: AppColors.bearCandleRed.opacity(0.3),
                    strokeWidth: 0.5,
                    action: onDelete
                )
            } else {
                DrawerActionButton(
                    imageName: "exclamationmark.triangle",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.2),
                    foregroundColor: AppColors.whiteText.opacity(0.9),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: onReport
                )
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 20)
        .background(AppColors.sheetBackground)
    }
}

// MARK: - Date Extension for Time Ago Display

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    let markerManager = MarkerManager(userId: "user123", guildId: "guild1")
    
    let sampleMarker = ChartMarker(
        candleIndex: 0,
        timestamp: Date(),
        price: 1.08455,
        type: .predictionTarget,
        userId: "user123",
        username: "TraderPro",
        note: "Strong bullish setup forming. Expecting breakout above resistance with volume confirmation.",
        guildId: "guild1",
        targetPrice: 1.09200,
        comments: [
            MarkerComment(
                userId: "user456",
                username: "ChartMaster",
                text: "Great analysis! I agree with your target. Looking at the same setup.",
                createdAt: Date().addingTimeInterval(-3600)
            ),
            MarkerComment(
                userId: "user789",
                username: "SwingTrader",
                text: "What's your stop loss on this?",
                createdAt: Date().addingTimeInterval(-1800)
            )
        ]
    )
    
    MarkerDetailView(
        marker: sampleMarker,
        markerManager: markerManager,
        selectedDetent: .constant(.fraction(0.9))
    )
    .environmentObject(AppState())
}
