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

struct AnnouncementsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.announcements.isEmpty {
                UnifiedLoadingState(message: "Loading announcements...")
                    .padding(.top, 40)
            }
            // Empty state
            else if leftDrawerViewModel.announcements.isEmpty {
                UnifiedEmptyState(
                    icon: "megaphone",
                    title: "No announcements yet",
                    subtitle: "Check back later for guild updates"
                )
                .padding(.top, 40)
            } else {
                ForEach(leftDrawerViewModel.announcements) { announcement in
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

    var body: some View {
        UnifiedContentCard(
            onTap: onTap,
            isUnread: !announcement.isRead,
            semanticBorderColor: announcement.isImportant && !announcement.isRead
                ? Color.orange.opacity(0.4) : nil,
            cornerRadius: 14
        ) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    GuildPostIconBadge(
                        iconKey: announcement.iconKey,
                        isFeatured: announcement.isImportant,
                        showsFeaturedMarker: false,
                        size: 36,
                        iconSize: 16,
                        isRead: announcement.isRead
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        // Title
                        Text(announcement.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(styling.titleColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        // Importance badge
                        if announcement.isImportant {
                            UnifiedImportanceBadge(text: "Important")
                        }

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
                        isFeatured: announcement.isImportant,
                        showsFeaturedMarker: false,
                        size: 44,
                        iconSize: 20,
                        isRead: false
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(announcement.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if announcement.isImportant {
                            UnifiedImportanceBadge(text: "Important")
                        }
                        
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
