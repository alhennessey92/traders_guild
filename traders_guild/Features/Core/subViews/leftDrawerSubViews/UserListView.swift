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
    let guildUsers: [GuildUser]
    
    var body: some View {
        VStack(spacing: 10) {
            if guildUsers.isEmpty {
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
                ForEach(guildUsers) { user in
                    GuildUserListRowView(
                        user: user,
                        onTap: {
                            bottomSheetContent = .guildUserProfile(user)
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
    let user: GuildUser
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
                            Text(String(user.name.prefix(2)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    if user.isOnline {
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
                        Text(user.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.whiteText)
                        
                    }
            
                    
                    HStack (spacing:2){
                        Text(user.role.rawValue)
                            .font(.caption)
                            .foregroundColor(roleForegroundColor(for: user.role))
                            .fontWeight(roleWeight(for: user.role))
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
                    if user.newMessage {
                        Circle()
                            .fill(AppColors.accentDarkColor)
                            .stroke(AppColors.accentColor, lineWidth: 2)
                            .frame(width: 10, height: 10)
                    }
                    
                    
                        
                }
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
    
    private func roleForegroundColor(for role: UserRole) -> Color {
        switch role {
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return AppColors.whiteText.opacity(0.7)
        }
    }
    
    private func roleWeight(for role: UserRole) -> Font.Weight {
        switch role {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
 
    
}



// MARK: - Enhanced Announcement Detail View
struct GuildUserDetailView: View {
    let user: GuildUser

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 15){
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(user.name.prefix(2)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                    
                    if user.isOnline {
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
                    Text(user.name)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text(user.role.rawValue)
                        .font(.caption)
                        .foregroundColor(roleForegroundColor(for: user.role))
                        .fontWeight(roleWeight(for: user.role))
                        .lineLimit(1)
                }
                
            }//hstack
            
            VStack(alignment: .leading, spacing: 6){
                
                // member since
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.greyText)
                    Text("Member Since")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                    Text(user.dateJoined, format: Date.FormatStyle().day().month(.twoDigits).year())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }
                
                // User guild reputation
                
                HStack(alignment: .center, spacing: 1) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(user.reputation)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
                    Text("Guild Reputation")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.leading, 6)
                }
                
            }
            
            
            
            Divider()
            
            HStack(spacing: 8) {
                StandardActionButton(
                    title: "Block",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark,
                    action: { }
                )
                Spacer()
                

                StandardActionButton(
                    title: "Block",
                    backgroundColor: AppColors.whiteText,
                    foregroundColor: AppColors.gradientBackgroundDark,
                    action: { }
                )
                
                .padding(.trailing)

                
            }
            
            
        } //vstack
        .padding(.top, 8).padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }
    private func roleForegroundColor(for role: UserRole) -> Color {
        switch role {
        case .admin: return .orange
        case .moderator: return .blue
        case .member: return AppColors.whiteText.opacity(0.7)
        }
    }
    
    private func roleWeight(for role: UserRole) -> Font.Weight {
        switch role {
        case .admin: return .bold
        case .moderator: return .bold
        case .member: return .regular
        }
    }
}

