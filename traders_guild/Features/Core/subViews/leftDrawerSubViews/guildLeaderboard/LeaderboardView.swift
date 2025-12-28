//
//  LeaderboardView.swift
//  traders_guild
//
//  Leaderboard View for Left Drawer
//  Shows reputation rankings across Guild, Friends, and Global
//  Uses UnifiedComponents for consistent styling
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - LEADERBOARD TAB DEFINITION
// MARK: - ================================================================================================

/// Tab enum for leaderboard sections
enum LeaderboardTab: String, CaseIterable, UnifiedTabItem {
    case guild = "Guild"
    case friends = "Friends"
    case global = "Global"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .guild: return "person.3.fill"
        case .friends: return "person.2.fill"
        case .global: return "globe"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - LEADERBOARD LIST VIEW
// MARK: - ================================================================================================

struct LeaderboardListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    // Tab state
    @State private var selectedTab: LeaderboardTab = .guild
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in getCountForTab(tab) },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 12)
            
            // Content based on selected tab
            VStack(spacing: 10) {
                switch selectedTab {
                case .guild:
                    guildLeaderboardContent
                case .friends:
                    friendsLeaderboardContent
                case .global:
                    globalLeaderboardContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: LeaderboardTab) -> Int {
        switch tab {
        case .guild: return leftDrawerViewModel.members.count
        case .friends: return leftDrawerViewModel.friends.count
        case .global: return leftDrawerViewModel.globalLeaderboard.count
        }
    }
    
    // MARK: - Sorted Members (by reputation)
    
    private var sortedGuildMembers: [GuildMembershipDTO] {
        leftDrawerViewModel.members.sorted { $0.reputation > $1.reputation }
    }
    
    private var sortedFriends: [GuildMembershipDTO] {
        leftDrawerViewModel.friends.sorted { $0.reputation > $1.reputation }
    }
    
    private var sortedGlobalMembers: [GuildMembershipDTO] {
        leftDrawerViewModel.globalLeaderboard.sorted { $0.reputation > $1.reputation }
    }
    
    // MARK: - Guild Leaderboard Content
    
    private var guildLeaderboardContent: some View {
        Group {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.members.isEmpty {
                UnifiedLoadingState(message: "Loading leaderboard...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.members.isEmpty {
                UnifiedEmptyState(
                    icon: "trophy",
                    title: "No members yet",
                    subtitle: "Guild leaderboard will appear here"
                )
                .padding(.top, 40)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(sortedGuildMembers.enumerated()), id: \.element.id) { index, member in
                            UnifiedLeaderboardRow(
                                user: member,
                                rank: index + 1,
                                onTap: {
                                    bottomSheetContent = .guildMember(member)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Friends Leaderboard Content
    
    private var friendsLeaderboardContent: some View {
        Group {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.friends.isEmpty {
                UnifiedLoadingState(message: "Loading friends...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.friends.isEmpty {
                UnifiedEmptyState(
                    icon: "person.2",
                    title: "No friends yet",
                    subtitle: "Add friends to compare rankings"
                )
                .padding(.top, 40)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(sortedFriends.enumerated()), id: \.element.id) { index, friend in
                            UnifiedLeaderboardRow(
                                user: friend,
                                rank: index + 1,
                                onTap: {
                                    bottomSheetContent = .guildMember(friend)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Global Leaderboard Content
    
    private var globalLeaderboardContent: some View {
        Group {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.globalLeaderboard.isEmpty {
                UnifiedLoadingState(message: "Loading global rankings...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.globalLeaderboard.isEmpty {
                UnifiedEmptyState(
                    icon: "globe",
                    title: "No global data",
                    subtitle: "Global leaderboard coming soon"
                )
                .padding(.top, 40)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(sortedGlobalMembers.enumerated()), id: \.element.id) { index, member in
                            UnifiedLeaderboardRow(
                                user: member,
                                rank: index + 1,
                                onTap: {
                                    bottomSheetContent = .guildMember(member)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}



////
////  LeaderboardView.swift
////  traders_guild
////
////  Created by Al Hennessey on 09/10/2025.
////
//
//import SwiftUI
//
//
//
//// MARK: - Announcements List View
//struct LeaderboardListView: View {
//    // MARK: - Need to add a bottom sheet for user profile
//    
//    @Binding var bottomSheetContent: BottomSheetContent?
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    var body: some View {
//        VStack(spacing: 10) {
//            // ✅ Loading state
//            if leftDrawerViewModel.isLoading && leftDrawerViewModel.members.isEmpty {
//                VStack(spacing: 16) {
//                    ProgressView()
//                        .scaleEffect(1.2)
//                    Text("Loading Guild Members...")
//                        .font(.subheadline)
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.top, 40)
//            }
//            else if leftDrawerViewModel.members.isEmpty {
//                VStack(spacing: 12) {
//                    Image(systemName: "megaphone")
//                        .font(.largeTitle)
//                        .foregroundColor(AppColors.whiteText.opacity(0.3))
//                    Text("No members in the guild")
//                        .font(.subheadline)
//                        .foregroundColor(AppColors.whiteText.opacity(0.5))
//                    Text("Check back later for guild updates")
//                        .font(.caption)
//                        .foregroundColor(AppColors.whiteText.opacity(0.4))
//                        .multilineTextAlignment(.center)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.top, 40)
//            } else {
//                ForEach(Array(leftDrawerViewModel.members.sorted(by: { $0.reputation > $1.reputation }).enumerated()), id: \.element.id) { index, user in
//                    LeaderBoardRowView(
//                        user: user,
//                        rank: index + 1, // this is their place in the sorted list
//                        onTap: {
//                            // handle tap
//                            bottomSheetContent = .guildMember(user)
//                        }
//                    )
//                }
//            }
//        }
//        .padding(.horizontal, 16)
//    }
//}
//
//
//
//// MARK: - Announcement Row View
//struct LeaderBoardRowView: View {
//    let user: GuildMembershipDTO
//    let rank: Int
//    let onTap: () -> Void
//    
//    @State private var isPressed = false
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 10) {
//                Text("\(rank)")
//                    .font(.subheadline)
//                    .fontWeight(.bold)
//                    .foregroundColor(rank <= 3 ? AppColors.accentColor : AppColors.whiteText.opacity(0.6))
//                    //.frame(width: 30)
//        
//                
//                // Avatar with online indicator
//                ZStack(alignment: .bottomTrailing) {
//                    Circle()
//                        .fill(AppColors.accentColor.opacity(0.3))
//                        .frame(width: 40, height: 40)
//                        .overlay(
//                            Text(String(user.globalMember.username.prefix(2)))
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.accentColor)
//                        )
//                        .overlay(alignment: .bottomTrailing) {
//                            Circle()
//                                .fill(user.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
//                                .frame(width: 10, height: 10)
//                                .overlay(
//                                    Circle()
//                                        .stroke(AppColors.drawerBackground, lineWidth: 2)
//                                )
//                                .padding(.trailing, 2)
//                                .padding(.bottom, 2)
//                        }
//                }
//                
//                VStack (alignment: .leading, spacing: 3){
//                    
//                    HStack(spacing: 2) {
//                        if user.isBlocked {
//                            Image(systemName: "nosign")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.bearCandleRed)
//                        }
//                    
//                        Text(user.globalMember.username)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
//                        
//                        if user.isFriend {
//                            Image(systemName: "person.crop.circle")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
//                                .padding(.leading, 3)
//                        }
//                    }
//                   
//                    
//                    Text(user.roleInGuild.rawValue)
//                        .font(.caption)
//                        .foregroundColor(user.roleInGuild.roleForegroundColor)
//                        .fontWeight(user.roleInGuild.roleFontWeight)
//                        .lineLimit(1)
//                }
//                
//                
//                Spacer()
//                HStack(spacing:2) {
//                    
//                    Image(systemName: "shield.pattern.checkered")
//                        .font(.caption2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    Text("\(user.reputation)")
//                        .font(.caption2)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                }
//                
//                
//            }
//            .padding(.horizontal, 10)
//            .padding(.vertical, 10)
//            .background(
//                RoundedRectangle(cornerRadius: 14)
//                    .fill(
//                        Color.white
//                            .opacity(isPressed ? 0.1 : (rank <= 3 ? 0.05 : 0.03))
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 14)
//                            .strokeBorder(
//                                AppColors.accentColor.opacity(rank <= 3 ? 0.2 : 0),
//                                lineWidth: 1
//                            )
//                    )
//            )
//            .cornerRadius(14)
//        }
//        .buttonStyle(PlainButtonStyle())
//        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = pressing
//            }
//        }, perform: {})
//        
//    }
//    
//  
// 
//    
//}
//
//
