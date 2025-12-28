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
    @Environment(\.dismiss) private var dismiss
    
    // Tab state
    @State private var selectedTab: UserListTab = .guild
    
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
                    guildMembersContent
                case .friends:
                    friendsContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
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
                ScrollView(.vertical, showsIndicators: false) {
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
                ScrollView(.vertical, showsIndicators: false) {
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
}

// MARK: - ================================================================================================
// MARK: - GUILD USER DETAIL VIEW
// MARK: - ================================================================================================

struct GuildUserDetailView: View {
    let user: GuildMembershipDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // Top header section with gradient background
                GuildMemberProfileHeaderView(user: user)
                
                // Profile content component
                GuildUserProfileContent(user: user)
                
                Divider()
                
                // Action buttons component
                GuildUserActionButtons(user: user)
                    .environmentObject(appState)
                    .environmentObject(messagingManager)
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .background(AppColors.sheetBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(UnifiedStaticBackground())
            
            // Floating dismiss button
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
                // Avatar
                UnifiedMemberAvatar(
                    username: user.globalMember.username,
                    avatarURL: user.globalMember.avatarURL,
                    isOnline: user.isOnline,
                    size: 60
                )

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
// MARK: - GUILD USER PROFILE CONTENT
// MARK: - ================================================================================================

struct GuildUserProfileContent: View {
    let user: GuildMembershipDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats row
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(user.daysInGuild)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text("Days")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                VStack(spacing: 4) {
                    Text("\(user.contributionScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                    Text("Contributions")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                VStack(spacing: 4) {
                    Text("\(user.reputation)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text("Reputation")
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 25)
    }
}

// MARK: - ================================================================================================
// MARK: - GUILD USER ACTION BUTTONS
// MARK: - ================================================================================================

struct GuildUserActionButtons: View {
    let user: GuildMembershipDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager
    @EnvironmentObject var appState: AppState
    
    @State private var showBlockUserConfirmation = false
    @State private var showUnBlockUserConfirmation = false
    @State private var showAddFriendConfirmation = false
    @State private var showRemoveFriendConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Block/Unblock button
            DrawerActionButton(
                imageName: user.isBlocked ? "nosign" : "hand.raised.fill",
                backgroundColor: user.isBlocked ? AppColors.bearCandleRed.opacity(0.2) : AppColors.gradientBackgroundDark.opacity(0.2),
                foregroundColor: user.isBlocked ? AppColors.bearCandleRed : AppColors.whiteText.opacity(0.8),
                strokeColor: user.isBlocked ? AppColors.bearCandleRed.opacity(0.5) : AppColors.whiteText.opacity(0.3),
                strokeWidth: 0.5,
                action: {
                    if user.isBlocked {
                        showUnBlockUserConfirmation = true
                    } else {
                        showBlockUserConfirmation = true
                    }
                }
            )
            
            // Friend button
            DrawerActionButton(
                imageName: user.isFriend ? "person.crop.circle.badge.checkmark" : "person.badge.plus",
                backgroundColor: user.isFriend ? AppColors.friendAccent.opacity(0.2) : AppColors.gradientBackgroundDark.opacity(0.2),
                foregroundColor: user.isFriend ? AppColors.friendAccent : AppColors.whiteText.opacity(0.8),
                strokeColor: user.isFriend ? AppColors.friendAccent.opacity(0.5) : AppColors.whiteText.opacity(0.3),
                strokeWidth: 0.5,
                action: {
                    if user.isFriend {
                        showRemoveFriendConfirmation = true
                    } else {
                        showAddFriendConfirmation = true
                    }
                }
            )
            
            Spacer()
            
            // Message button
            DrawerActionButton(
                title: "Message",
                imageName: "bubble.left.fill",
                backgroundColor: AppColors.accentColor,
                foregroundColor: .white,
                strokeColor: AppColors.accentColor,
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
            Button("Block", role: .destructive) { blockUser() }
        } message: {
            Text("Are you sure you want to block \(user.globalMember.username)?")
        }
        .alert("Unblock User", isPresented: $showUnBlockUserConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock") { unBlockUser() }
        } message: {
            Text("Are you sure you want to unblock \(user.globalMember.username)?")
        }
        .alert("Add Friend", isPresented: $showAddFriendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Add Friend") { addFriend() }
        } message: {
            Text("Send a friend request to \(user.globalMember.username)?")
        }
        .alert("Remove Friend", isPresented: $showRemoveFriendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Friendship", role: .destructive) { removeFriend() }
        } message: {
            Text("Remove \(user.globalMember.username) as a friend?")
        }
    }
    
    // MARK: - Actions
    
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

////
////  UserListView.swift
////  traders_guild
////
////  Created by Al Hennessey on 09/10/2025.
////
//
////
////  UserListView.swift
////  traders_guild
////
////  Created by Al Hennessey on 09/10/2025.
////
//import SwiftUI
//
//// MARK: - Announcements List View
//struct UserListView: View {
//    @Binding var bottomSheetContent: BottomSheetContent?
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var messagingManager: MessagingManager
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
//                    Image(systemName: "person.3")
//                        .font(.largeTitle)
//                        .foregroundColor(AppColors.whiteText.opacity(0.3))
//                    Text("No members yet")
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
//                ForEach(leftDrawerViewModel.members) { membership in
//                    GuildUserListRowView(
//                        user: membership,
//                        onTap: {
//                            bottomSheetContent = .guildMember(membership)
//                        }
//                    )
//                }
//            }
//        }
//        .padding(.horizontal, 16)
//    }
//}
//
//// MARK: - Announcement Row View
//struct GuildUserListRowView: View {
//    let user: GuildMembershipDTO
//    let onTap: () -> Void
//    
//    @State private var isPressed = false
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 12) {
//                // Avatar with online indicator
//                Circle()
//                    .fill(AppColors.accentColor.opacity(0.3))
//                    .frame(width: 40, height: 40)
//                    .overlay(
//                        Text(String(user.globalMember.username.prefix(2)))
//                            .font(.caption)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                    )
//                    .overlay(alignment: .bottomTrailing) {
//                        Circle()
//                            .fill(user.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
//                            .frame(width: 10, height: 10)
//                            .overlay(
//                                Circle()
//                                    .stroke(AppColors.drawerBackground, lineWidth: 1)
//                            )
//                            .padding(.trailing, 2)
//                            .padding(.bottom, 2)
//                    }
//                
//                // User info
//                VStack(alignment: .leading, spacing: 3) {
//                    HStack(spacing: 4) {
//                        if user.isBlocked {
//                            Image(systemName: "nosign")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.bearCandleRed)
//                        }
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
//                    HStack(spacing: 2) {
//                        Text(user.roleInGuild.rawValue)
//                            .font(.caption)
//                            .foregroundColor(user.roleInGuild.roleForegroundColor)
//                            .fontWeight(user.roleInGuild.roleFontWeight)
//                            .lineLimit(1)
//                        Circle()
//                            .fill(AppColors.whiteText.opacity(0.7))
//                            .frame(width: 4, height: 4)
//                            .padding(.top, 1)
//                            .padding(.leading, 3)
//                            .padding(.trailing, 3)
//                        Image(systemName: "shield.pattern.checkered")
//                            .font(.caption2)
//                            .fontWeight(.bold)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("\(user.reputation)")
//                            .font(.caption2)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.accentColor)
//                    }
//                }
//                
//                Spacer()
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 6)
//        }
//        .buttonStyle(PlainButtonStyle())
//        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = pressing
//            }
//        }, perform: {})
//    }
//}
//
//// MARK: - Enhanced User Detail View (Simplified)
//struct GuildUserDetailView: View {
//    let user: GuildMembershipDTO
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var messagingManager: MessagingManager
//    @EnvironmentObject var appState: AppState
//
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            // Main content
//            VStack(alignment: .leading, spacing: 0) {
//                // Top header section with gradient background
//                GuildMemberProfileHeaderView(user: user)
//                
//                // ✅ Reusable profile content component
//                GuildUserProfileContent(user: user)
//                
//                Divider()
//                
//                // ✅ Reusable action buttons component
//                GuildUserActionButtons(user: user)
//                    .environmentObject(appState)
//                    .environmentObject(messagingManager)
//                    .padding(.horizontal, 25)
//                    .padding(.top, 20)
//                    .background(AppColors.sheetBackground)
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//            .background(
//                ZStack {
//                    Color.clear
//                        .background(.ultraThinMaterial)
//                    AppColors.sheetBackground
//                    StaticPatternView()
//                }
//            )
//            
//            // Floating dismiss button overlaid on top
//            Button(action: { dismiss() }) {
//                Image(systemName: "xmark.circle.fill")
//                    .font(.title2)
//                    .foregroundColor(.secondary)
//            }
//            .padding(.top, 20)
//            .padding(.trailing, 20)
//        }
//    }
//}
//
//// MARK: - Reusable Profile Content Component
//struct GuildUserProfileContent: View {
//    let user: GuildMembershipDTO
//    @State private var selectedTab: ProfileTab = .overview
//    
//    enum ProfileTab: String, CaseIterable {
//        case overview = "Overview"
//        case markers = "Markers"
//        case awards = "Awards"
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Tab Headers
//            HStack(spacing: 0) {
//                ForEach(ProfileTab.allCases, id: \.self) { tab in
//                    Button(action: {
//                        withAnimation(.easeInOut(duration: 0.2)) {
//                            selectedTab = tab
//                        }
//                    }) {
//                        VStack(spacing: 8) {
//                            Text(tab.rawValue)
//                                .font(.subheadline)
//                                .fontWeight(selectedTab == tab ? .semibold : .regular)
//                                .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
//                            
//                            Rectangle()
//                                .fill(selectedTab == tab ? AppColors.accentColor : Color.clear)
//                                .frame(height: 2)
//                        }
//                    }
//                    .frame(maxWidth: .infinity)
//                }
//            }
//            .padding(.horizontal, 25)
//            .padding(.top, 12)
//            .background(AppColors.sheetBackground)
//            
//            Divider()
//            
//            // Tab Content - Scrollable
//            ScrollView(.vertical, showsIndicators: false) {
//                VStack(alignment: .leading, spacing: 16) {
//                    switch selectedTab {
//                    case .overview:
//                        overviewContent
//                    case .markers:
//                        markersContent
//                    case .awards:
//                        awardsContent
//                    }
//                }
//                .padding(.horizontal, 25)
//                .padding(.vertical, 20)
//            }
//        }
//    }
//    
//    private var overviewContent: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Overview")
//                .font(.title3)
//                .fontWeight(.bold)
//            
//            Text("User stats, bio, and other overview information...")
//                .foregroundColor(AppColors.greyText)
//            
//            ForEach(0..<5) { i in
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Section \(i + 1)")
//                        .font(.headline)
//                    Text("Some content here that makes the view scrollable...")
//                        .font(.subheadline)
//                        .foregroundColor(AppColors.greyText)
//                }
//                .padding()
//                .background(AppColors.gradientBackgroundDark.opacity(0.2))
//                .cornerRadius(12)
//            }
//        }
//    }
//    
//    private var markersContent: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Markers Placed")
//                .font(.title3)
//                .fontWeight(.bold)
//            
//            ForEach(0..<8) { i in
//                HStack(spacing: 12) {
//                    Image(systemName: "circle.fill")
//                        .font(.caption)
//                        .foregroundColor(AppColors.accentColor)
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Markers \(i + 1)")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        Text("Description of the activity")
//                            .font(.caption)
//                            .foregroundColor(AppColors.greyText)
//                    }
//                    
//                    Spacer()
//                }
//                .padding()
//                .background(AppColors.gradientBackgroundDark.opacity(0.1))
//                .cornerRadius(10)
//            }
//        }
//    }
//    
//    private var awardsContent: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Awards")
//                .font(.title3)
//                .fontWeight(.bold)
//            
//            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
//                ForEach(0..<10) { i in
//                    VStack(spacing: 8) {
//                        Image(systemName: "star.fill")
//                            .font(.title)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("Award \(i + 1)")
//                            .font(.caption)
//                            .fontWeight(.medium)
//                            .multilineTextAlignment(.center)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
//                    .cornerRadius(12)
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Reusable Action Buttons Component
//struct GuildUserActionButtons: View {
//    let user: GuildMembershipDTO
//    @EnvironmentObject var appState: AppState
//    @EnvironmentObject var messagingManager: MessagingManager
//    @Environment(\.dismiss) private var dismiss
//    
//    @State private var showBlockUserConfirmation = false
//    @State private var showUnBlockUserConfirmation = false
//    @State private var showAddFriendConfirmation = false
//    @State private var showRemoveFriendConfirmation = false
//    
//    var body: some View {
//        HStack(spacing: 8) {
//            DrawerActionButton(
//                imageName: "nosign",
//                backgroundColor: user.isBlocked ? AppColors.bearCandleRed.opacity(0.8) : AppColors.bearCandleRed.opacity(0.1),
//                foregroundColor: user.isBlocked ? AppColors.whiteText : AppColors.bearCandleRed,
//                strokeColor: AppColors.bearCandleRed.opacity(0.6),
//                strokeWidth: 0.5,
//                action: {
//                    if user.isBlocked {
//                        showUnBlockUserConfirmation = true
//                    } else {
//                        showBlockUserConfirmation = true
//                    }
//                }
//            )
//            
//            Spacer()
//            
//            DrawerActionButton(
//                imageName: user.isFriend ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus",
//                backgroundColor: user.isFriend ? AppColors.friendAccent.opacity(0.6) : AppColors.gradientBackgroundDark.opacity(0.05),
//                foregroundColor: AppColors.whiteText.opacity(0.8),
//                strokeColor: user.isFriend ? AppColors.friendAccent : AppColors.whiteText.opacity(0.3),
//                strokeWidth: 0.5,
//                action: {
//                    if user.isFriend {
//                        showRemoveFriendConfirmation = true
//                    } else {
//                        showAddFriendConfirmation = true
//                    }
//                }
//            )
//            
//            DrawerActionButton(
//                title: "Chat",
//                imageName: "message.fill",
//                backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
//                foregroundColor: AppColors.whiteText.opacity(0.8),
//                strokeColor: AppColors.whiteText.opacity(0.3),
//                strokeWidth: 0.5,
//                action: {
//                    dismiss()
//                    Task {
//                        await messagingManager.openUserChat(with: user)
//                    }
//                }
//            )
//        }
//        .alert("Block User", isPresented: $showBlockUserConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Block", role: .destructive) {
//                blockUser()
//            }
//            
//        } message: {
//            Text("Are you sure you want to block \(user.globalMember.username)? You won't see their messages or activity.")
//        }
//        
//        
//        .alert("Unblock User", isPresented: $showUnBlockUserConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Unblock") {
//                unBlockUser()
//            }
//        } message: {
//            Text("Are you sure you want to unblock \(user.globalMember.username)?")
//        }
//        .alert("Add Friend", isPresented: $showAddFriendConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Add Friend") {
//                addFriend()
//            }
//        } message: {
//            Text("Send a friend request to \(user.globalMember.username)?")
//        }
//        .alert("Remove Friend", isPresented: $showRemoveFriendConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("End Friendship") {
//                removeFriend()
//            }
//        } message: {
//            Text("Un-friend User: \(user.globalMember.username)?")
//        }
//    }
//    
//    // MARK: - Action Methods
//    private func blockUser() {
//        Task {
//           
//            do {
//                try await appState.blockUser(userId: user.globalMember.id)
//                appState.showSuccess("User blocked successfully")
//                dismiss()
//            } catch {
//                appState.showError(error, title: "Failed to Block User")
//            }
//        }
//    }
//    
//    private func unBlockUser() {
//        Task {
//            
//            do {
//                try await appState.unBlockUser(userId: user.globalMember.id)
//                appState.showSuccess("Unblocked user")
//                dismiss()
//            } catch {
//                appState.showError(error, title: "Failed to Unblock User")
//            }
//        }
//    }
//    
//    private func addFriend() {
//        Task {
//            do {
//                try await appState.sendFriendRequest(userId: user.globalMember.id)
//                appState.showSuccess("Friend request sent!")
//            } catch {
//                appState.showError(error, title: "Failed to Send Friend Request")
//            }
//        }
//    }
//    
//    private func removeFriend() {
//        Task {
//            do {
//                try await appState.sendCancelFriendship(userId: user.globalMember.id)
//                appState.showSuccess("Friendship removed")
//            } catch {
//                appState.showError(error, title: "Failed to end friendship")
//            }
//        }
//    }
//}
//
//// MARK: - Guild Member Header View for Profile Sheet
//struct GuildMemberProfileHeaderView: View {
//    let user: GuildMembershipDTO
//    
//    var body: some View {
//        // Top header section with gradient background
//        VStack(alignment: .leading, spacing: 20) {
//            // User header
//            HStack(spacing: 15) {
//                // Avatar with online indicator
//                ZStack(alignment: .bottomTrailing) {
//                    Circle()
//                        .fill(AppColors.accentColor.opacity(0.3))
//                        .frame(width: 60, height: 60)
//                        .overlay(
//                            Text(String(user.globalMember.username.prefix(2)))
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.accentColor)
//                        )
//                        .overlay(alignment: .bottomTrailing) {
//                            Circle()
//                                .fill(user.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
//                                .frame(width: 14, height: 14)
//                                .overlay(
//                                    Circle()
//                                        .stroke(AppColors.drawerBackground, lineWidth: 2)
//                                )
//                                .padding(.trailing, 2)
//                                .padding(.bottom, 2)
//                        }
//                }
//
//                // User info
//                VStack(alignment: .leading, spacing: 3) {
//                    HStack(spacing: 2) {
//                        if user.isBlocked {
//                            Image(systemName: "nosign")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.bearCandleRed)
//                        }
//                    
//                        Text(user.globalMember.username)
//                            .font(.title3)
//                            .fontWeight(.medium)
//                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
//                        
//                        if user.isFriend {
//                            Image(systemName: "person.crop.circle")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
//                                .padding(.leading, 3)
//                        }
//                    }
//
//                    Text(user.roleInGuild.rawValue)
//                        .font(.caption)
//                        .foregroundColor(user.roleInGuild.roleForegroundColor)
//                        .fontWeight(user.roleInGuild.roleFontWeight)
//                        .lineLimit(1)
//                }
//
//                Spacer(minLength: 60) // Leave space for dismiss button
//            }
//            .padding(.horizontal, 25)
//            .padding(.top, 25)
//
//            VStack(alignment: .leading, spacing: 6) {
//                // Member since
//                HStack(spacing: 6) {
//                    Image(systemName: "calendar")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.greyText)
//                    Text("\(user.memberSince)")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.greyText)
//                }
//
//                // User guild reputation
//                HStack(alignment: .center, spacing: 1) {
//                    Image(systemName: "shield.pattern.checkered")
//                        .font(.caption)
//                        .fontWeight(.bold)
//                        .foregroundColor(AppColors.accentColor)
//                    Text("\(user.reputation)")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.accentColor)
//                    Text("Guild Reputation")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.greyText)
//                        .padding(.leading, 6)
//                }
//            }
//            .padding(.horizontal, 25)
//
//            Divider()
//        }
//        .background(
//            LinearGradient(
//                colors: [
//                    AppColors.gradientBackgroundDark.opacity(0.3),
//                    AppColors.sheetBackground
//                ],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        )
//    }
//}
