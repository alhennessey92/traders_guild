//
//  ChatroomRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import SwiftUI



// MARK: - Chatroom Row View
struct ChatroomRowView: View {
    let chatroom: GuildChatroomDTO
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
                    Image(systemName: "number")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.4))
                }
                
                // Chatroom info
                VStack(alignment: .leading, spacing: 4) {
                    Text(chatroom.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)
                    
                    if let lastMessage = chatroom.lastMessage {
                        Text(lastMessage.content)
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(chatroom.isActive ? AppColors.bullCandleGreen : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                            Text("\(chatroom.memberCount) members")
                                .font(.caption)
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Active indicator
                HStack(spacing: 6) {
                    if chatroom.isActive {
                        Circle()
                            .fill(AppColors.bullCandleGreen)
                            .frame(width: 8, height: 8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.03))
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
                    Image(systemName: "number")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText.opacity(0.4))
                    
                    // Pinned indicator
                    if chatroom.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .offset(x: 14, y: -14)
                    }
                }
                
                // Chatroom info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(chatroom.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                        
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
                            Text(lastMessage.content)
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .lineLimit(1)
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(chatroom.isActive ? AppColors.bullCandleGreen : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)
                            Text("\(chatroom.memberCount) members")
                                .font(.caption)
                                .foregroundColor(AppColors.whiteText.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Right side indicators
                VStack(alignment: .trailing, spacing: 4) {
                    // Last activity time
                    if chatroom.lastMessage != nil {
                        Text(chatroom.lastActivityFormatted)
                            .font(.caption2)
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                    }
                    
                    HStack(spacing: 6) {
                        // Unread badge
                        if chatroom.hasUnread {
                            Text("\(chatroom.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accentColor)
                                .clipShape(Capsule())
                        }
                        
                        // Active indicator
                        if chatroom.isActive && !chatroom.hasUnread {
                            Circle()
                                .fill(AppColors.bullCandleGreen)
                                .frame(width: 8, height: 8)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.whiteText.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.03))
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