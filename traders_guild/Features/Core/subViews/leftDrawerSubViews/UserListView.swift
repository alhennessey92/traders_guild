//
//  UserListView.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//
import SwiftUI



// MARK: - Announcements List View
struct UserListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    let memberships: [GuildMembership]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager // Add messaging manager
    
    var body: some View {
        VStack(spacing: 10) {
            if memberships.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No members yet")
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
                ForEach(memberships) { membership in
                    GuildUserListRowView(
                        user: membership,
                        onTap: {
                            bottomSheetContent = .profile(membership)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}



// MARK: - Announcement Row View
struct GuildUserListRowView: View {
    let user: GuildMembership
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(user.userName?.prefix(2) ?? "unKnown"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    if user.isUserOnline {
                        Circle()
                            .fill(AppColors.bullCandleGreen)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.drawerBackground, lineWidth: 2)
                            )
                    }
                }
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        Text(user.userName ?? "unKnown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                    }
            
                    HStack(spacing: 2) {
                        Text(user.roleInGuild.rawValue)
                            .font(.caption)
                            .foregroundColor(user.roleInGuild.foregroundColor)
                            .fontWeight(user.roleInGuild.fontWeight)
                            .lineLimit(1)
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 5, height: 5)
                            .padding(.top, 1)
                            .padding(.leading, 3)
                            .padding(.trailing, 3)
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(user.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }
                }
                
                Spacer()
                
                // Friend indicator & chevron
                HStack(spacing: 2) {
                    // Removed user.newMessage indicator as User doesn't have that property
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
struct GuildUserDetailView: View {
    let user: GuildMembership
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager // Add messaging manager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            VStack(alignment: .leading, spacing: 20) {
                // Top header section with gradient background
                VStack(alignment: .leading, spacing: 20) {
                    // User header
                    HStack(spacing: 15) {
                        // Avatar with online indicator
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(AppColors.accentColor.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(user.userName?.prefix(2) ?? "unKnown"))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accentColor)
                                )
                            
                            if user.isUserOnline {
                                Circle()
                                    .fill(AppColors.bullCandleGreen)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(AppColors.drawerBackground, lineWidth: 2)
                                    )
                            }
                        }
                        
                        // User info
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.userName ?? "Unknown")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.whiteText)
                            
                            Text(user.roleInGuild.rawValue)
                                .font(.caption)
                                .foregroundColor(user.roleInGuild.foregroundColor)
                                .fontWeight(user.roleInGuild.fontWeight)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 60) // Leave space for dismiss button
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 25)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // member since
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.greyText)
                            Text("Member Since")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.greyText)
                        }
                        
                        // User guild reputation
                        HStack(alignment: .center, spacing: 1) {
                            Image(systemName: "shield.pattern.checkered")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                            Text("\(user.reputation)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accentColor)
                            Text("Guild Reputation")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.greyText)
                                .padding(.leading, 6)
                        }
                    }
                    .padding(.horizontal, 25)
                    
                    Divider()
                        .padding(.horizontal)
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
                
                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 1) {
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        Text("\(user.reputation)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        Text("Guild Reputation")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.greyText)
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 25)
                
                Spacer(minLength: 0)
                
                Divider()
                    .padding(.horizontal)

                HStack(spacing: 8) {
                    DrawerActionButton(
                        imageName: "nosign",
                        backgroundColor: AppColors.bearCandleRed.opacity(0.2),
                        foregroundColor: AppColors.whiteText,
                        strokeColor: AppColors.bearCandleRed.opacity(0.6),
                        strokeWidth: 0.5,
                        action: { }
                    )
                    
                    Spacer()
                    
                    DrawerActionButton(
                        imageName: "person.fill.badge.plus",
                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: { }
                    )

                    DrawerActionButton(
                        title: "Chat",
                        imageName: "message.fill",
                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: {
                            dismiss() // If in a sheet
                            messagingManager.openUserChat(with: user)
                        }
                    )
                }
                .padding(.horizontal, 25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // Floating dismiss button overlaid on top
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
       // .background(AppColors.drawerBackground.opacity(0.2))
    }
    

}
