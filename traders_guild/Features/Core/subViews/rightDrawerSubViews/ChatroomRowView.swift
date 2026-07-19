//
//  ChatroomRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import SwiftUI




//
//  RLChatroomRowView.swift
//  traders_guild
//
//  UPDATED: Uses RLGuildChatroomDTO from new messaging DTOs.
//


// MARK: - Chatroom Row View
struct RLChatroomRowView: View {
    let chatroom: RLGuildChatroomDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Chatroom icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.gradientBackgroundDark.opacity(0.4))
                        .frame(width: 44, height: 44)
                    Text(chatroom.displayIcon)
                        .font(.title2.weight(.bold))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.listRowSecondaryForeground)
                    
                    // Pinned indicator
                    if chatroom.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.themeAwareYellow)
                            .offset(x: 14, y: -14)
                    }
                }
                
                // Chatroom info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(chatroom.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.listRowPrimaryForeground)
                        
                        if chatroom.isMuted {
                            Image(systemName: "speaker.slash.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.greyText)
                        }
                    }
                    
                    if let lastMessage = chatroom.lastMessage {
                        HStack(spacing: 4) {
                            Text(lastMessage.author.username)
                                .fontWeight(.medium)
                            Text("·")
                            Text(MarkerShareCodec.displayPreview(for: lastMessage.content))
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.listRowSecondaryForeground)
                        .lineLimit(1)
                    } else {
                        Text(
                            chatroom.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? (chatroom.description ?? "")
                            : "No description yet"
                        )
                        .font(.caption)
                        .foregroundColor(AppColors.listRowSecondaryForeground)
                        .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Right side indicators
                VStack(alignment: .trailing, spacing: 4) {
                    Text(chatroom.lastActivityFormatted)
                        .font(.caption2)
                        .foregroundColor(AppColors.listRowTertiaryForeground)
                    
                    HStack(spacing: 6) {
                        // Unread badge
                        if chatroom.hasUnread {
                            Text("\(chatroom.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.onAccentForeground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accentColor)
                                .clipShape(Capsule())
                        }
                        
                        // Active indicator
                        if chatroom.isActive && !chatroom.hasUnread {
                            Circle()
                                .fill(AppColors.onlineStatusGreen)
                                .frame(width: 8, height: 8)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.listRowChevronForeground)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isPressed ? AppColors.messagingListRowFillPressed : AppColors.messagingListRowFill)
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

// MARK: - Preview
#if DEBUG
struct RLChatroomRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            RLChatroomRowView(
                chatroom: .sample,
                onTap: {}
            )
        }
        .padding()
        .background(AppColors.drawerBackground)
    }
}
#endif
