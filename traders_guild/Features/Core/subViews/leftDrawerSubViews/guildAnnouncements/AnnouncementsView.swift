//
//  AnnouncementsView.swift
//  traders_guild
//
//  Guild Announcements View for Left Drawer
//  Uses UnifiedCardComponents for consistent styling
//
//  UPDATED: Now uses RLGuildAnnouncementWithAuthorDTO and RLAppState
//  DTOs match backend exactly, view models provide fallbacks
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - ANNOUNCEMENTS LIST VIEW
// MARK: - ================================================================================================

private enum AnnouncementFeedTab: String, CaseIterable, UnifiedTabItem {
    case all = "All"
    case guild = "Guild"
    case system = "System"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .all:
            return "tray.full.fill"
        case .guild:
            return "shield.lefthalf.filled"
        case .system:
            return "megaphone.fill"
        }
    }
}

struct AnnouncementsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @State private var selectedTab: AnnouncementFeedTab = .all

    /// Sort: important first, then by chronological order (already sorted by view model).
    /// Pinning important items to the top is the core UX benefit of the "Important" flag.
    private var sortedAnnouncements: [RLGuildAnnouncementWithAuthorDTO] {
        filteredAnnouncements.sorted { lhs, rhs in
            if lhs.isImportant != rhs.isImportant { return lhs.isImportant }
            return lhs.announcement.postedAt > rhs.announcement.postedAt
        }
    }

    private var importantCount: Int {
        filteredAnnouncements.filter(\.isImportant).count
    }

    private var filteredAnnouncements: [RLGuildAnnouncementWithAuthorDTO] {
        leftDrawerViewModel.announcements.filter { announcement in
            switch selectedTab {
            case .all:
                return true
            case .guild:
                return !isSystemAnnouncement(announcement)
            case .system:
                return isSystemAnnouncement(announcement)
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in count(for: tab) },
                spacing: 6
            )
            .padding(.top, 4)
            .padding(.bottom, 4)

            // Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.announcements.isEmpty {
                UnifiedLoadingState(message: "Loading announcements...")
                    .padding(.top, 40)
            }
            // Empty state
            else if filteredAnnouncements.isEmpty {
                UnifiedEmptyState(
                    icon: "megaphone",
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
                .padding(.top, 40)
            } else {
                if importantCount > 0 {
                    ImportantSectionHeader(
                        icon: "exclamationmark.circle.fill",
                        iconColor: AppColors.statusWarning80,
                        title: "Important",
                        count: importantCount
                    )
                }
                ForEach(Array(sortedAnnouncements.enumerated()), id: \.element.id) { index, announcement in
                    if index == importantCount, importantCount > 0, index < sortedAnnouncements.count {
                        ImportantSectionHeader(
                            icon: "megaphone.fill",
                            iconColor: AppColors.accentColor,
                            title: "All Announcements",
                            count: sortedAnnouncements.count - importantCount
                        )
                        .padding(.top, 6)
                    }
                    AnnouncementRowView(
                        announcement: announcement,
                        onTap: {
                            bottomSheetContent = .announcement(announcement)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyTitle: String {
        switch selectedTab {
        case .all:
            return "No announcements yet"
        case .guild:
            return "No guild announcements"
        case .system:
            return "No system announcements"
        }
    }

    private var emptySubtitle: String {
        switch selectedTab {
        case .all:
            return "Check back later for guild updates"
        case .guild:
            return "Guild posts will appear here"
        case .system:
            return "Platform broadcasts will appear here"
        }
    }

    private func count(for tab: AnnouncementFeedTab) -> Int {
        switch tab {
        case .all:
            return leftDrawerViewModel.announcements.count
        case .guild:
            return leftDrawerViewModel.announcements.filter { !isSystemAnnouncement($0) }.count
        case .system:
            return leftDrawerViewModel.announcements.filter(isSystemAnnouncement).count
        }
    }

    private func isSystemAnnouncement(_ announcement: RLGuildAnnouncementWithAuthorDTO) -> Bool {
        if isOnboardingWelcomeAnnouncement(announcement) {
            return false
        }

        let authorText = "\(announcement.authorUsername) \(announcement.authorDisplayName)".lowercased()
        return authorText.contains("traders guild system")
            || authorText.contains("traders guild admin")
            || authorText == "system"
            || authorText.hasPrefix("system ")
            || authorText.contains(" system ")
    }

    private func isOnboardingWelcomeAnnouncement(_ announcement: RLGuildAnnouncementWithAuthorDTO) -> Bool {
        let title = announcement.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let content = announcement.content.lowercased()

        return title.hasPrefix("welcome to ")
            && (
                content.contains("starting guild while you get set up")
                || content.contains("this is your starting guild")
                || title.contains("onboarding guild")
            )
    }
}

// MARK: - ================================================================================================
// MARK: - IMPORTANT SECTION HEADER
// MARK: - ================================================================================================

/// Compact section header used to separate "Important" pinned items from the rest.
struct ImportantSectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(iconColor)
            Text(title.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(0.6)
                .foregroundColor(AppColors.whiteText.opacity(0.7))
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundColor(AppColors.whiteText.opacity(0.55))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(AppColors.whiteText.opacity(0.08))
                )
            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

// MARK: - ================================================================================================
// MARK: - ANNOUNCEMENT ROW VIEW
// MARK: - ================================================================================================

struct AnnouncementRowView: View {
    let announcement: RLGuildAnnouncementWithAuthorDTO
    let onTap: () -> Void

    private var styling: NotificationStyling {
        NotificationStyling(isRead: announcement.isRead)
    }

    private var importantBorderColor: Color? {
        guard announcement.isImportant else { return nil }
        // Show the "important" accent even when read — just lower the opacity.
        return AppColors.statusWarning80.opacity(announcement.isRead ? 0.25 : 0.55)
    }

    var body: some View {
        UnifiedContentCard(
            onTap: onTap,
            isUnread: !announcement.isRead,
            semanticBorderColor: importantBorderColor,
            cornerRadius: 14
        ) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 12) {
                    // Icon — important announcements get a small red exclamation
                    // badge in the bottom-right corner of the icon.
                    GuildPostIconBadge(
                        iconKey: announcement.iconKey,
                        size: 36,
                        iconSize: 16,
                        isRead: announcement.isRead,
                        cornerBadge: announcement.isImportant ? .important : nil
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(announcement.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(styling.titleColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        // Preview text
                        Text(announcement.preview)
                            .font(.caption)
                            .foregroundColor(styling.bodyColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    rowAccessory
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // MARK: - Author Footer Bar
                UnifiedAuthorFooter(
                    username: announcement.authorUsername,
                    role: announcement.authorRole,
                    reputation: announcement.authorReputation,
                    accuracy: announcement.authorAccuracy,
                    timeText: announcement.timeAgoFormatted,
                    cornerRadius: 14
                )
            }
        }
    }

    @ViewBuilder
    private var rowAccessory: some View {
        if announcement.isRead {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.whiteText.opacity(0.3))
        } else {
            Circle()
                .fill(AppColors.accentColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - ANNOUNCEMENT DETAIL VIEW
// MARK: - ================================================================================================

struct AnnouncementDetailView: View {
    let announcement: RLGuildAnnouncementWithAuthorDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var hasRecordedView = false
    
    private let drawerBackgroundColor: Color = AppColors.drawerBackground

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon and title
                HStack(alignment: .top, spacing: 12) {
                    GuildPostIconBadge(
                        iconKey: announcement.iconKey,
                        size: 44,
                        iconSize: 20,
                        isRead: false,
                        cornerBadge: announcement.isImportant ? .important : nil
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(announcement.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text(announcement.timeAgoFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                
                // Author info (uses view model's fallback properties)
                HStack(spacing: 3) {
                    Text("Posted by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    UnifiedAuthorRow(
                        username: announcement.authorUsername,
                        role: announcement.authorRole,
                        reputation: announcement.authorReputation,
                        accuracy: announcement.authorAccuracy
                    )
                }
                
                Divider()
                
                // Content
                ScrollView {
                    Text(announcement.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 30)
            .padding(.horizontal)
            
            // Floating dismiss button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(drawerBackgroundColor.opacity(0.2))
        .onAppear {
            recordAnnouncementView()
        }
    }
    
    private func recordAnnouncementView() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await rlAppState.recordAnnouncementView(
                    guildId: announcement.guildId,
                    announcementId: announcement.id
                )
                leftDrawerViewModel.markAnnouncementAsRead(announcementId: announcement.id)
            } catch {
                print("Failed to record announcement view: \(error)")
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - AUTHOR COMPONENTS (use view model properties, not raw DTOs)
// MARK: - ================================================================================================

/// Author row - takes display values directly (from view model's fallback properties)
struct RLAuthorRow: View {
    let displayName: String
    let avatarUrl: String?
    let role: RLMemberRole
    
    var body: some View {
        HStack(spacing: 4) {
            // Avatar placeholder or image
            if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
            
            Text(displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(role.displayName)
                .font(.caption)
                .foregroundColor(role.color)
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(role.color.opacity(0.3))
            .frame(width: 16, height: 16)
            .overlay(
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(role.color)
            )
    }
}

/// Author footer bar - takes display values directly (from view model's fallback properties)
struct RLAuthorFooter: View {
    let displayName: String
    let avatarUrl: String?
    let role: RLMemberRole
    let timeText: String
    let cornerRadius: CGFloat
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
            
            // Name and role
            Text(displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(AppColors.whiteText.opacity(0.9))
            
            Text("•")
                .font(.caption2)
                .foregroundColor(AppColors.whiteText.opacity(0.4))
            
            Text(role.displayName)
                .font(.caption2)
                .foregroundColor(role.color)
            
            Spacer()
            
            // Time
            Text(timeText)
                .font(.caption2)
                .foregroundColor(AppColors.whiteText.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: 0
            )
            .fill(AppColors.whiteText.opacity(0.03))
        )
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(role.color.opacity(0.3))
            .frame(width: 20, height: 20)
            .overlay(
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(role.color)
            )
    }
}
