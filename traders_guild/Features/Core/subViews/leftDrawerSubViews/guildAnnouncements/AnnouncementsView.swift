//
//  Announcements.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import Foundation
import SwiftUI



// MARK: - Announcements List View
struct AnnouncementsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // ✅ Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.announcements.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading announcements...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            // ✅ Empty state
            else if leftDrawerViewModel.announcements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No announcements yet")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    Text("Check back later for guild updates")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
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

// MARK: - Announcement Row View
struct AnnouncementRowView: View {
    let announcement: GuildAnnouncementDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon with importance indicator
                ZStack {
                    Image(systemName: announcement.isImportant ? "megaphone.fill" : "megaphone")
                        .font(.title3)
                        .foregroundColor(announcement.isImportant ? AppColors.whiteText : AppColors.whiteText.opacity(0.8))
                        .frame(width: 24)
                    
//                    if announcement.isImportant {
//                        Circle()
//                            .fill(Color.red.opacity(0.9))
//                            .frame(width: 8, height: 8)
//                            .offset(x: 8, y: -8)
//                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title with importance badge
                    HStack(alignment: .top, spacing: 6) {
                        Text(announcement.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        
                        Spacer()
                    }
                    if announcement.isImportant {
                        Text("IMPORTANT ANNOUNCEMENT")
                            .font(.system(size: 8, weight: .bold))  // ✅ Combine size and weight
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.bearCandleRed.opacity(0.8))
                            .cornerRadius(6)
                    }
                    
                    // Preview text
                    Text(announcement.preview)
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Author and time info
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Posted by ")
                                .font(.caption)
                                .fontWeight(.regular)
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
//                                .frame(maxWidth: .infinity, alignment: .init(horizontal: .leading, vertical: .center))
                            
                            Spacer()
                            Text(announcement.timeAgoFormatted)
                                .font(.caption2)
                                .foregroundColor(AppColors.whiteText.opacity(0.5))
                        }
                        HStack(spacing: 4) {
                            let role = announcement.author.roleInGuild
                            Text(announcement.author.globalMember.username)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText)
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.7))
                                .frame(width: 3, height: 3)
                                .padding(.top, 1)
                                .padding(.leading, 3)
                                .padding(.trailing, 3)
                            Text(role.rawValue)
                                .font(.caption)
                                .foregroundColor(role.roleForegroundColor)
                                .fontWeight(role.roleFontWeight)
                                .lineLimit(1)
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.7))
                                .frame(width: 3, height: 3)
                                .padding(.top, 1)
                                .padding(.leading, 3)
                                .padding(.trailing, 3)
                            Image(systemName: "shield.pattern.checkered")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                            
                            // MARK: - need to fetch this based on author id
                            Text("\(announcement.author.reputation)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accentColor)
                            Spacer()
                        }
                        

                
//                        Spacer()
//                        
//                        Text(announcement.timeAgo)
//                            .font(.caption2)
//                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                    }
                    .padding(.top, 2)
                }
                
//                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(announcement.isRead ? Color.clear : AppColors.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Enhanced Announcement Detail View
struct AnnouncementDetailView: View {
    let announcement: GuildAnnouncementDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState  // ✅ Add this if not already present
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var hasRecordedView = false  // ✅ Prevent duplicate calls

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                
                // START OF CONTENT
                
                // Header with icon and title
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Image(systemName: announcement.isImportant ? "megaphone.fill" : "megaphone.fill")
                            .font(.title)
                            .foregroundColor(AppColors.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(announcement.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if announcement.isImportant {
                            Text("IMPORTANT ANNOUNCEMENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.bearCandleRed.opacity(0.8))
                                .cornerRadius(6)
                        }
                        
                        Text(announcement.timeAgoFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                let author = announcement.author
                // Author and timestamp info
                HStack(spacing: 3) {
                    if author.isBlocked {
                        Image(systemName: "nosign")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.bearCandleRed)
                    }
                    
                    Text("Posted by \(author.globalMember.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if author.isFriend {
                        Image(systemName: "person.crop.circle")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(author.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                    }
                    
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 4, height: 4)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    
                    Text(author.roleInGuild.rawValue)
                        .font(.caption)
                        .foregroundColor(author.roleInGuild.roleForegroundColor)
                        .fontWeight(author.roleInGuild.roleFontWeight)
                        .lineLimit(1)
                    
                    Circle()
                        .fill(AppColors.whiteText.opacity(0.7))
                        .frame(width: 4, height: 4)
                        .padding(.top, 1)
                        .padding(.leading, 3)
                        .padding(.trailing, 3)
                    
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    
                    Text("\(author.reputation)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
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
                
                // END OF CONTENT
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 30)
            .padding(.horizontal)
            
            // Floating dismiss button overlaid on top
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(AppColors.drawerBackground.opacity(0.2))
        .onAppear {  // ✅ Record view when the view appears
            recordAnnouncementView()
        }
    }
    
    // ✅ Function to record the view
    private func recordAnnouncementView() {
        // Prevent duplicate calls if view appears multiple times
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await appState.recordAnnouncementView(announcementId: announcement.id)
                
                // 2. Update cache to mark as read
                leftDrawerViewModel.markAnnouncementAsRead(announcementId: announcement.id)
                // Optionally: silently succeed, no need to show success message
            } catch {
                // Silently fail - viewing tracking is not critical
                // Or optionally log the error for debugging
                print("Failed to record announcement view: \(error)")
            }
        }
    }
}

