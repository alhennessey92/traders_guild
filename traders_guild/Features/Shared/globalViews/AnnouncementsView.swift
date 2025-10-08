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
    let announcements: [GuildAnnouncement]
    
    var body: some View {
        VStack(spacing: 10) {
            if announcements.isEmpty {
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
                ForEach(announcements) { announcement in
                    AnnouncementRowView(
                        announcement: announcement,
                        onTap: {
                            bottomSheetContent = .announcement(
                                id: announcement.id.hashValue,
                                title: announcement.title
                            )
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
    let announcement: GuildAnnouncement
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
                    
                    if announcement.isImportant {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
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
                        
//                        if announcement.isImportant {
//                            Text("IMPORTANT")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 6)
//                                .padding(.vertical, 2)
//                                .background(Color.red)
//                                .cornerRadius(4)
//                        }
                        
                        Spacer()
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
                            Text(announcement.timeAgo)
                                .font(.caption2)
                                .foregroundColor(AppColors.whiteText.opacity(0.5))
                        }
                        HStack(spacing: 4) {
                            Text(announcement.author)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText)
                            Circle()
                                .fill(AppColors.whiteText.opacity(0.7))
                                .frame(width: 3, height: 3)
                                .padding(.top, 1)
                                .padding(.leading, 3)
                                .padding(.trailing, 3)
                            
                            Text(announcement.authorRole.rawValue)
                                .font(.caption)
                                .foregroundColor(announcement.authorRole.foregroundColor)
                                .fontWeight(announcement.authorRole.fontWeight)
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
                            Text("345")
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
                        announcement.isImportant ?
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColors.accentColor.opacity(0.3), lineWidth: 1) :
                        nil
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
    let announcement: GuildAnnouncement
    
    init(id: Int, title: String) {
        // This is a temporary solution - in a real app you'd fetch the announcement by ID
        // For now, we'll create a sample announcement
        // Use modulo to keep the time offset reasonable and prevent overflow
        let safeTimeOffset = abs(id % 168) // Limit to 0-167 hours (about a week)
        self.announcement = GuildAnnouncement(
            title: title,
            content: "This is the full announcement content. You can include rich text, images, links, and more here. This view has all the space it needs to display detailed information.\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.\n\nImportant trading updates and guild information will be posted here regularly.",
            author: "Guild Admin",
            authorRole: .admin,
            postedAt: Date().addingTimeInterval(TimeInterval(-safeTimeOffset * 3600)),
            isImportant: (id % 10) <= 3 // Use modulo to determine importance safely
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and title
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Image(systemName: announcement.isImportant ? "megaphone.fill" : "megaphone.fill")
                        .font(.title)
                        .foregroundColor(AppColors.accentColor)
                    
                    if announcement.isImportant {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .offset(x: 12, y: -12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(announcement.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if announcement.isImportant {
                        Text("IMPORTANT ANNOUNCEMENT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            
            // Author and timestamp info
            HStack(spacing: 8) {
                if announcement.authorRole != .member {
                    Text(announcement.authorRole.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            announcement.authorRole == .admin ? 
                            Color.red.opacity(0.8) : 
                            AppColors.accentColor.opacity(0.8)
                        )
                        .cornerRadius(4)
                }
                
                Text("Posted by \(announcement.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(announcement.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    }
}
