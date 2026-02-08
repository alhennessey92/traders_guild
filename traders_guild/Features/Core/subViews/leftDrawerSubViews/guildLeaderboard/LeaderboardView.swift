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
    @EnvironmentObject var rlAppState: RLAppState
    
    // Tab state
    @State private var selectedTab: LeaderboardTab = .guild
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector - OUTSIDE ScrollView (truly fixed)
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
            
            // Scrollable content with pull to refresh
            ScrollView(.vertical, showsIndicators: false) {
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
            .refreshable {
                await refreshLeaderboard()
            }
        }
    }
    
    // MARK: - Refresh
    
    private func refreshLeaderboard() async {
        guard let guild = rlAppState.currentGuild else { return }
        await leftDrawerViewModel.refreshGuildMembers(guildId: guild.id, rlAppState: rlAppState)
        await leftDrawerViewModel.refreshFriends(guildId: guild.id, rlAppState: rlAppState)
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: LeaderboardTab) -> Int {
        switch tab {
        case .guild: return leftDrawerViewModel.guildMembers.count
        case .friends: return leftDrawerViewModel.friendsRL.count
        case .global: return leftDrawerViewModel.globalLeaderboard.count
        }
    }
    
    // MARK: - Sorted Members (by reputation)
    
    private var sortedGuildMembers: [RLGuildMemberDTO] {
        leftDrawerViewModel.guildMembers.sorted { $0.reputation > $1.reputation }
    }
    
    private var sortedFriends: [RLFriendDTO] {
        leftDrawerViewModel.friendsRL.sorted { $0.globalReputation > $1.globalReputation }
    }
    
    private var sortedGlobalMembers: [RLGuildMemberDTO] {
        leftDrawerViewModel.globalLeaderboard.sorted { $0.reputation > $1.reputation }
    }
    
    // MARK: - Guild Leaderboard Content
    
    private var guildLeaderboardContent: some View {
        Group {
            if leftDrawerViewModel.isLoadingGuildMembers && leftDrawerViewModel.guildMembers.isEmpty {
                UnifiedLoadingState(message: "Loading leaderboard...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.guildMembers.isEmpty {
                UnifiedEmptyState(
                    icon: "trophy",
                    title: "No members yet",
                    subtitle: "Guild leaderboard will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedGuildMembers.enumerated()), id: \.element.id) { index, member in
                        LeaderboardMemberRow(
                            displayName: member.displayName,
                            username: member.username,
                            avatarUrl: member.avatarUrl,
                            isOnline: rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline),
                            roleText: member.memberRole.displayName,
                            roleColor: member.memberRole.color,
                            isBlocked: member.isBlocked,
                            isFriend: member.isFriend,
                            reputation: member.reputation,
                            rank: index + 1,
                            onTap: {
                                if member.userId == rlAppState.currentUser?.id {
                                    bottomSheetContent = .profile
                                } else {
                                    bottomSheetContent = .guildMemberRL(member)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Friends Leaderboard Content
    
    private var friendsLeaderboardContent: some View {
        Group {
            if leftDrawerViewModel.isLoadingFriendsRL && leftDrawerViewModel.friendsRL.isEmpty {
                UnifiedLoadingState(message: "Loading friends...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.friendsRL.isEmpty {
                UnifiedEmptyState(
                    icon: "person.2",
                    title: "No friends yet",
                    subtitle: "Add friends to compare rankings"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedFriends.enumerated()), id: \.element.id) { index, friend in
                        LeaderboardMemberRow(
                            displayName: friend.displayName,
                            username: friend.username,
                            avatarUrl: friend.avatarUrl,
                            isOnline: rlAppState.effectiveOnlineStatus(userId: friend.userId, fallback: friend.isOnline),
                            roleText: roleForFriend(friend).text,
                            roleColor: roleForFriend(friend).color,
                            isBlocked: false,
                            isFriend: true,
                            reputation: friend.globalReputation,
                            rank: index + 1,
                            onTap: {
                                if let member = leftDrawerViewModel.guildMembers.first(where: { $0.userId == friend.userId }) {
                                    bottomSheetContent = .guildMemberRL(member)
                                } else {
                                    rlAppState.showInfo("Member data not loaded yet")
                                }
                            }
                        )
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
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedGlobalMembers.enumerated()), id: \.element.id) { index, member in
                        LeaderboardMemberRow(
                            displayName: member.displayName,
                            username: member.username,
                            avatarUrl: member.avatarUrl,
                            isOnline: rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline),
                            roleText: member.memberRole.displayName,
                            roleColor: member.memberRole.color,
                            isBlocked: member.isBlocked,
                            isFriend: member.isFriend,
                            reputation: member.reputation,
                            rank: index + 1,
                            onTap: {
                                bottomSheetContent = .guildMemberRL(member)
                            }
                        )
                    }
                }
            }
        }
    }
}

private extension LeaderboardListView {
    func roleForFriend(_ friend: RLFriendDTO) -> (text: String, color: Color) {
        if let member = leftDrawerViewModel.guildMembers.first(where: { $0.userId == friend.userId }) {
            return (member.memberRole.displayName, member.memberRole.color)
        }
        return ("Member", .gray)
    }
}

private struct LeaderboardMemberRow: View {
    let displayName: String
    let username: String
    let avatarUrl: String?
    let isOnline: Bool
    let roleText: String
    let roleColor: Color
    let isBlocked: Bool
    let isFriend: Bool
    let reputation: Int
    let rank: Int
    let onTap: () -> Void
    
    @State private var isPressed: Bool = false
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.8)
        default: return AppColors.whiteText.opacity(0.5)
        }
    }
    
    private var isTopRank: Bool { rank <= 3 }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
                    .frame(width: 24)
                
                UnifiedMemberAvatar(
                    username: displayName,
                    avatarURL: avatarUrl,
                    isOnline: isOnline,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(isBlocked ? AppColors.greyText : AppColors.friendAccent)
                        }
                    }
                    
                    Text(roleText)
                        .font(.caption)
                        .foregroundColor(roleColor)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text("\(reputation)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(AppColors.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.08 : (isTopRank ? 0.05 : 0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isTopRank ? rankColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
