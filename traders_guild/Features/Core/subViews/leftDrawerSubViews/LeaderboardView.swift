//
//  LeaderboardView.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//

import SwiftUI



// MARK: - Announcements List View
struct LeaderboardView: View {
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
                ForEach(Array(guildUsers.sorted(by: { $0.reputation > $1.reputation }).enumerated()), id: \.element.id) { index, user in
                    LeaderBoardRowView(
                        user: user,
                        rank: index + 1, // this is their place in the sorted list
                        onTap: {
                            // handle tap
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}



// MARK: - Announcement Row View
struct LeaderBoardRowView: View {
    let user: GuildUser
    let rank: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rank <= 3 ? AppColors.accentColor : AppColors.whiteText.opacity(0.6))
                    .frame(width: 30)
                
//                if rank <= 3 {
//                    Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
//                        .foregroundColor(rank == 1 ? .yellow : (rank == 2 ? .gray : Color.orange))
//                        .font(.title3)
//                }
                
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(user.name.prefix(2)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
                VStack (alignment: .leading, spacing: 3){
                    Text("\(user.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    
                    Text(user.role.rawValue)
                        .font(.caption)
                        .foregroundColor(user.role.foregroundColor)
                        .fontWeight(user.role.fontWeight)
                        .lineLimit(1)
                }
                
                
                Spacer()
                HStack(spacing:2) {
                    
                    Image(systemName: "shield.pattern.checkered")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(user.reputation)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                }
                
                
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        Color.white
                            .opacity(isPressed ? 0.1 : (rank <= 3 ? 0.04 : 0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                AppColors.accentColor.opacity(rank <= 3 ? 0.2 : 0),
                                lineWidth: 1
                            )
                    )
            )
            .cornerRadius(14)
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


