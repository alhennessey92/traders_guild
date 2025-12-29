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
    @EnvironmentObject var appState: AppState
    
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
        guard let guild = appState.currentGuild else { return }
        await leftDrawerViewModel.refresh(for: guild.id, appState: appState)
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
