//
//  UserRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import SwiftUI


// MARK: - User Row View
struct GuildUserRowView: View {
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
                    HStack (spacing: 2){
//                        if user.isFriend {
//                            Image(systemName: "star.fill")
//                                .font(.caption2)
//                                .foregroundColor(AppColors.accentColor)
//                            
//                        }
                        Text(user.userName ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                        
                    }
            
                    
                    HStack (spacing:2){
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
//                HStack(spacing: 2) {
//                    if user.newMessage {
//                        Circle()
//                            .fill(AppColors.accentDarkColor)
//                            .stroke(AppColors.accentColor, lineWidth: 2)
//                            .frame(width: 10, height: 10)
//                    }
//                    
//                    
//                        
//                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
//            .background(
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(Color.white.opacity(isPressed ? 0.15 : 0.05))
//            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
//    private func roleForegroundColor(for role: UserRole) -> Color {
//        switch role {
//        case .admin: return .orange
//        case .moderator: return .blue
//        case .member: return AppColors.whiteText.opacity(0.7)
//        }
//    }
//    
//    private func roleWeight(for role: UserRole) -> Font.Weight {
//        switch role {
//        case .admin: return .bold
//        case .moderator: return .bold
//        case .member: return .regular
//        }
//    }
}
