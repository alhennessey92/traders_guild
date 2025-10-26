//
//  UserRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

//
//  UserRowView.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import SwiftUI


// MARK: - User Row View button for left drawer
struct UserRowView: View {
    let user: CurrentUserDTO
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
                            Text(user.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    
                    Circle()
                        .fill(AppColors.bullCandleGreen)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(AppColors.drawerBackground, lineWidth: 2)
                        )
                    
                }
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    HStack (spacing: 2){

                        Text(user.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                        
                    }
                    
                    
                    HStack (spacing:2){
                        Text(user.guildMembership.roleInGuild.displayName)
                            .font(.caption)
                            .foregroundColor(user.guildMembership.roleInGuild.roleForegroundColor)
                            .fontWeight(user.guildMembership.roleInGuild.roleFontWeight)
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
                        Text("\(user.guildMembership.reputation)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentColor)
                        
                        
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accentColor)
                
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
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.accentColor.opacity(isPressed ? 0.3 : 0.1))
                    .stroke(AppColors.accentDarkColor.opacity(isPressed ? 0.8 : 0.5), lineWidth: 1)
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
