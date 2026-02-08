//
//  UserRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import SwiftUI


//
//  RLUserDMRowView.swift
//  traders_guild
//
//  UPDATED: Uses RLDMThreadDTO from new messaging DTOs.
//


// MARK: - User Direct Message Row View
struct RLUserDMRowView: View {
    let thread: RLDMThreadDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var participant: RLGuildMemberDTO {
        thread.participant
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    // Avatar circle
                    if let avatarUrl = participant.avatarUrl, !avatarUrl.isEmpty {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            avatarPlaceholder
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }
                    
                    // Online indicator
                    Circle()
                        .fill(participant.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(AppColors.drawerBackground, lineWidth: 1)
                        )
                        .offset(x: 2, y: 2)
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 2) {
                        // Blocked indicator
                        if participant.isBlocked || thread.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        // Username
                        Text(participant.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(thread.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        // Friend indicator
                        if participant.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(thread.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                .padding(.leading, 3)
                        }
                    }
                    
                    // Role and reputation
                    HStack(spacing: 2) {
                        let role = participant.memberRole
                        
                        Text(role.displayName)
                            .font(.caption)
                            .foregroundColor(role.color.opacity(0.9))
                            .fontWeight(role.canModerate ? .bold : .regular)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.5))
                            .frame(width: 4, height: 4)
                            .padding(.top, 1)
                            .padding(.horizontal, 3)
                        
                        Image(systemName: "shield.pattern.checkered")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                        
                        Text("\(participant.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                    }
                    
                    // Last message preview
                    if let lastMessage = thread.lastMessage {
                        Text(lastMessage.content)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Right side indicators
                VStack(alignment: .trailing, spacing: 4) {
                    // Last activity time
                    Text(thread.lastActivityFormatted)
                        .font(.caption2)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    
                    // Unread indicator
                    if thread.hasUnread {
                        ZStack {
                            Circle()
                                .fill(AppColors.accentDarkColor)
                                .frame(width: 10, height: 10)
                            Circle()
                                .stroke(AppColors.accentColor, lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                    }
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
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.accentColor.opacity(0.3))
            .frame(width: 40, height: 40)
            .overlay(
                Text(participant.initials)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
            )
    }
}

// MARK: - Preview
#if DEBUG
struct RLUserDMRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            // Would need sample data for preview
        }
        .padding()
        .background(AppColors.drawerBackground)
    }
}
#endif