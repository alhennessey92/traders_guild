//
//  UserListView.swift
//  traders_guild
//
//  Guild Members and Friends List View for Left Drawer
//  Uses UnifiedComponents for consistent styling
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - USER LIST TAB DEFINITION
// MARK: - ================================================================================================

/// Tab enum for user list sections
enum UserListTab: String, CaseIterable, UnifiedTabItem {
    case guild = "Guild"
    case friends = "Friends"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .guild: return "person.3.fill"
        case .friends: return "person.2.fill"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - USER LIST VIEW
// MARK: - ================================================================================================

struct UserListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // Tab state
    @State private var selectedTab: UserListTab = .guild
    
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
                        guildMembersContent
                    case .friends:
                        friendsContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshMembers()
            }
        }
    }
    
    // MARK: - Refresh
    
    private func refreshMembers() async {
        guard let guild = appState.currentGuild else { return }
        await leftDrawerViewModel.refresh(for: guild.id, appState: appState)
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: UserListTab) -> Int {
        switch tab {
        case .guild: return leftDrawerViewModel.members.count
        case .friends: return leftDrawerViewModel.friends.count
        }
    }
    
    // MARK: - Guild Members Content
    
    private var guildMembersContent: some View {
        Group {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.members.isEmpty {
                UnifiedLoadingState(message: "Loading guild members...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.members.isEmpty {
                UnifiedEmptyState(
                    icon: "person.3",
                    title: "No members yet",
                    subtitle: "Guild members will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(leftDrawerViewModel.members) { member in
                        UnifiedMemberRow(
                            user: member,
                            onTap: {
                                bottomSheetContent = .guildMember(member)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Friends Content
    
    private var friendsContent: some View {
        Group {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.friends.isEmpty {
                UnifiedLoadingState(message: "Loading friends...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.friends.isEmpty {
                UnifiedEmptyState(
                    icon: "person.2",
                    title: "No friends yet",
                    subtitle: "Add friends to see them here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(leftDrawerViewModel.friends) { friend in
                        UnifiedMemberRow(
                            user: friend,
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

// MARK: - ================================================================================================
// MARK: - GUILD USER DETAIL VIEW
// MARK: - ================================================================================================

struct GuildUserDetailView: View {
    let user: GuildMembershipDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // Top header section with gradient background
                GuildMemberProfileHeaderView(user: user)
                
                // New unified profile content with tabs
                ProfileContentView(
                    extendedProfile: SampleData.memberExtendedProfile,
                    markersSummary: SampleData.memberMarkersSummary,
                    userMarkers: SampleData.userPlacedMarkers.prefix(5).map { $0 },
                    awards: SampleData.memberAwards,
                    awardsSummary: SampleData.awardsSummary,
                    stats: SampleData.profileStats,
                    isCurrentUser: false,
                    username: user.globalMember.username,
                    onMarkerTap: { marker in
                        // TODO: Navigate to marker on chart
                        leftDrawerViewModel.requestNavigationToMarker(marker)
                        dismiss()
                    }
                )
                
                Divider()
                
                // Reusable action buttons component
                GuildUserActionButtons(user: user)
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .background(AppColors.sheetBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                    AppColors.sheetBackground
                    StaticPatternView()
                }
            )
            
            // Floating dismiss button overlaid on top
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
    }
}

// MARK: - ================================================================================================
// MARK: - GUILD MEMBER PROFILE HEADER VIEW
// MARK: - ================================================================================================

struct GuildMemberProfileHeaderView: View {
    let user: GuildMembershipDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // User header
            HStack(spacing: 15) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.accentColor.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(user.globalMember.username.prefix(2)))
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.accentColor)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(user.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.drawerBackground, lineWidth: 2)
                                )
                                .padding(.trailing, 2)
                                .padding(.bottom, 2)
                        }
                }

                // User info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        if user.isBlocked {
                            Image(systemName: "nosign")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                    
                        Text(user.globalMember.username)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if user.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                .padding(.leading, 3)
                        }
                    }

                    Text(user.roleInGuild.rawValue)
                        .font(.caption)
                        .foregroundColor(user.roleInGuild.roleForegroundColor)
                        .fontWeight(user.roleInGuild.roleFontWeight)
                        .lineLimit(1)
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)

            VStack(alignment: .leading, spacing: 6) {
                // Member since
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.greyText)
                    Text("\(user.memberSince)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                }

                // Reputation
                HStack(alignment: .center, spacing: 1) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("\(user.reputation)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentColor)
                    Text("Guild Reputation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
                        .padding(.leading, 6)
                }
            }
            .padding(.horizontal, 25)

            Divider()
        }
        .background(
            LinearGradient(
                colors: [
                    AppColors.gradientBackgroundDark.opacity(0.3),
                    AppColors.sheetBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - ================================================================================================
// MARK: - GUILD USER PROFILE CONTENT (DEPRECATED - Using ProfileContentView)
// MARK: - ================================================================================================

// GuildUserProfileContent has been replaced by ProfileContentView from ProfileContentViews.swift
// The new component provides:
// - Unified tab bar matching other drawer sections
// - Overview with extended profile info, interests, experience
// - Markers list with summary stats
// - Awards grid with category filters and rarity indicators

// MARK: - ================================================================================================
// MARK: - GUILD USER ACTION BUTTONS
// MARK: - ================================================================================================

struct GuildUserActionButtons: View {
    let user: GuildMembershipDTO
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var messagingManager: MessagingManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showBlockUserConfirmation = false
    @State private var showUnBlockUserConfirmation = false
    @State private var showAddFriendConfirmation = false
    @State private var showRemoveFriendConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            DrawerActionButton(
                imageName: "nosign",
                backgroundColor: user.isBlocked ? AppColors.bearCandleRed.opacity(0.8) : AppColors.bearCandleRed.opacity(0.1),
                foregroundColor: user.isBlocked ? AppColors.whiteText : AppColors.bearCandleRed,
                strokeColor: AppColors.bearCandleRed.opacity(0.6),
                strokeWidth: 0.5,
                action: {
                    if user.isBlocked {
                        showUnBlockUserConfirmation = true
                    } else {
                        showBlockUserConfirmation = true
                    }
                }
            )
            
            Spacer()
            
            DrawerActionButton(
                imageName: user.isFriend ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus",
                backgroundColor: user.isFriend ? AppColors.friendAccent.opacity(0.6) : AppColors.gradientBackgroundDark.opacity(0.05),
                foregroundColor: AppColors.whiteText.opacity(0.8),
                strokeColor: user.isFriend ? AppColors.friendAccent : AppColors.whiteText.opacity(0.3),
                strokeWidth: 0.5,
                action: {
                    if user.isFriend {
                        showRemoveFriendConfirmation = true
                    } else {
                        showAddFriendConfirmation = true
                    }
                }
            )
            
            DrawerActionButton(
                title: "Chat",
                imageName: "message.fill",
                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                foregroundColor: AppColors.whiteText.opacity(0.8),
                strokeColor: AppColors.whiteText.opacity(0.3),
                strokeWidth: 0.5,
                action: {
                    dismiss()
                    Task {
                        await messagingManager.openUserChat(with: user)
                    }
                }
            )
        }
        .alert("Block User", isPresented: $showBlockUserConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(user.globalMember.username)? You won't see their messages or activity.")
        }
        .alert("Unblock User", isPresented: $showUnBlockUserConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock") {
                unBlockUser()
            }
        } message: {
            Text("Are you sure you want to unblock \(user.globalMember.username)?")
        }
        .alert("Add Friend", isPresented: $showAddFriendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Add Friend") {
                addFriend()
            }
        } message: {
            Text("Send a friend request to \(user.globalMember.username)?")
        }
        .alert("Remove Friend", isPresented: $showRemoveFriendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Friendship") {
                removeFriend()
            }
        } message: {
            Text("Un-friend User: \(user.globalMember.username)?")
        }
    }
    
    // MARK: - Action Methods
    
    private func blockUser() {
        Task {
            do {
                try await appState.blockUser(userId: user.globalMember.id)
                appState.showSuccess("User blocked successfully")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Block User")
            }
        }
    }
    
    private func unBlockUser() {
        Task {
            do {
                try await appState.unBlockUser(userId: user.globalMember.id)
                appState.showSuccess("Unblocked user")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Unblock User")
            }
        }
    }
    
    private func addFriend() {
        Task {
            do {
                try await appState.sendFriendRequest(userId: user.globalMember.id)
                appState.showSuccess("Friend request sent!")
            } catch {
                appState.showError(error, title: "Failed to Send Friend Request")
            }
        }
    }
    
    private func removeFriend() {
        Task {
            do {
                try await appState.sendCancelFriendship(userId: user.globalMember.id)
                appState.showSuccess("Friendship removed")
            } catch {
                appState.showError(error, title: "Failed to end friendship")
            }
        }
    }
}
