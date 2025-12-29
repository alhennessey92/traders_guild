//
//  AnnouncementsView.swift
//  traders_guild
//
//  Guild Announcements View for Left Drawer
//  Uses UnifiedCardComponents for consistent styling
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
    let announcement: GuildAnnouncementDTO
    let onTap: () -> Void
    
    var body: some View {
        UnifiedContentCard(
            onTap: onTap,
            showUnreadBorder: !announcement.isRead,
            cornerRadius: 14
        ) {
            VStack(spacing: 0) {
                // MARK: - Main Content Area
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    UnifiedIconBadge(
                        icon: announcement.isImportant ? "megaphone.fill" : "megaphone",
                        color: announcement.isImportant ? AppColors.whiteText : AppColors.whiteText.opacity(0.8),
                        size: 36,
                        iconSize: 16,
                        backgroundOpacity: 0.15
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Title
                        Text(announcement.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        // Importance badge
                        if announcement.isImportant {
                            UnifiedImportanceBadge(text: "IMPORTANT ANNOUNCEMENT")
                        }
                        
                        // Preview text
                        Text(announcement.preview)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12) // More padding before footer
                
                // MARK: - Author Footer Bar
                UnifiedAuthorFooterFromMembership(
                    author: announcement.author,
                    timeText: announcement.timeAgoFormatted,
                    cornerRadius: 14
                )
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - ANNOUNCEMENT DETAIL VIEW
// MARK: - ================================================================================================

struct AnnouncementDetailView: View {
    let announcement: GuildAnnouncementDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var hasRecordedView = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with icon and title
                HStack(alignment: .top, spacing: 12) {
                    UnifiedIconBadge(
                        icon: "megaphone.fill",
                        color: AppColors.accentColor,
                        size: 44,
                        iconSize: 20,
                        backgroundOpacity: 0.2
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(announcement.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if announcement.isImportant {
                            UnifiedImportanceBadge(text: "IMPORTANT ANNOUNCEMENT")
                        }
                        
                        Text(announcement.timeAgoFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Author info
                HStack(spacing: 3) {
                    Text("Posted by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    UnifiedAuthorRowFromMembership(author: announcement.author)
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
        .background(AppColors.drawerBackground.opacity(0.2))
        .onAppear {
            recordAnnouncementView()
        }
    }
    
    private func recordAnnouncementView() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await appState.recordAnnouncementView(announcementId: announcement.id)
                leftDrawerViewModel.markAnnouncementAsRead(announcementId: announcement.id)
            } catch {
                print("Failed to record announcement view: \(error)")
            }
        }
    }
}

