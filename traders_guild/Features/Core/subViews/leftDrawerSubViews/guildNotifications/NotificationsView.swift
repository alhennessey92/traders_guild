//
//  Notifications.swift
//  traders_guild
//
//  Created by Al Hennessey on 12/10/2025.
//

//
//  LeaderboardView.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//

import SwiftUI


struct NotificationsListView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            // ✅ Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.userNotifications.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Notifications...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            // ✅ Empty state
            else if leftDrawerViewModel.userNotifications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No Notifications yet")
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
                ForEach(leftDrawerViewModel.userNotifications) { notification in
                    NotificationRowView(
                        notification: notification,
                        onTap: {
                            //bottomSheetContent = .announcement(announcement)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}



// MARK: - Announcement Row View
struct NotificationRowView: View {
    let notification: GuildNotificationDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("1")
                    .font(.headline)
                    .fontWeight(.bold)
                   // .foregroundColor(rank <= 3 ? AppColors.accentColor : AppColors.whiteText.opacity(0.6))
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
                        Text(String(notification.title))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
//                VStack (alignment: .leading, spacing: 3){
//                    Text("\(notification.title)")
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//                        .foregroundColor(AppColors.whiteText)
//                    
//                    Text("asdasd")
//                        .font(.caption)
//                        .foregroundColor(user.role.foregroundColor)
//                        .fontWeight(user.role.fontWeight)
//                        .lineLimit(1)
//                }
                
                
                Spacer()
                HStack(spacing:2) {
                    
                    Image(systemName: "shield.pattern.checkered")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("asdadasd")
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
                            .opacity(isPressed ? 0.1 : 0.02)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                AppColors.accentColor.opacity(0.3),
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


