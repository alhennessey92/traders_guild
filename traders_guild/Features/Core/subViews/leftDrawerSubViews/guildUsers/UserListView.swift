//
//  UserListView.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//

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
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagingManager: MessagingManager
    
    var body: some View {
        VStack(spacing: 10) {
            // ✅ Loading state
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.members.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Guild Members...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            else if leftDrawerViewModel.members.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No members yet")
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
                ForEach(leftDrawerViewModel.members) { membership in
                    GuildUserListRowView(
                        user: membership,
                        onTap: {
                            bottomSheetContent = .guildMember(membership)
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
    let user: GuildMembershipDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator
                Circle()
                    .fill(AppColors.accentColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(user.globalMember.username.prefix(2)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accentColor)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(user.isOnline ? AppColors.bullCandleGreen : AppColors.greyText)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.drawerBackground, lineWidth: 1)
                            )
                            .padding(.trailing, 2)
                            .padding(.bottom, 2)
                    }
                
                // User info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if user.isBlocked {
                            Image(systemName: "nosign")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        Text(user.globalMember.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if user.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                .padding(.leading, 3)
                        }
                    }
            
                    HStack(spacing: 2) {
                        Text(user.roleInGuild.rawValue)
                            .font(.caption)
                            .foregroundColor(user.roleInGuild.roleForegroundColor)
                            .fontWeight(user.roleInGuild.roleFontWeight)
                            .lineLimit(1)
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 4, height: 4)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Enhanced User Detail View (Simplified)
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
                
                // ✅ Reusable profile content component
                GuildUserProfileContent(user: user)
                
                Divider()
                
                // ✅ Reusable action buttons component
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

// MARK: - Reusable Profile Content Component
struct GuildUserProfileContent: View {
    let user: GuildMembershipDTO
    @State private var selectedTab: ProfileTab = .overview
    
    enum ProfileTab: String, CaseIterable {
        case overview = "Overview"
        case activity = "Activity"
        case achievements = "Achievements"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Headers
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? AppColors.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 12)
            .background(AppColors.sheetBackground)
            
            Divider()
            
            // Tab Content - Scrollable
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .activity:
                        activityContent
                    case .achievements:
                        achievementsContent
                    }
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 20)
            }
        }
    }
    
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("User stats, bio, and other overview information...")
                .foregroundColor(AppColors.greyText)
            
            ForEach(0..<5) { i in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Section \(i + 1)")
                        .font(.headline)
                    Text("Some content here that makes the view scrollable...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.greyText)
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
    
    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.title3)
                .fontWeight(.bold)
            
            ForEach(0..<8) { i in
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity \(i + 1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Description of the activity")
                            .font(.caption)
                            .foregroundColor(AppColors.greyText)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(AppColors.gradientBackgroundDark.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }
    
    private var achievementsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<10) { i in
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundColor(AppColors.accentColor)
                        Text("Achievement \(i + 1)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.gradientBackgroundDark.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Reusable Action Buttons Component
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
                foregroundColor: AppColors.whiteText,
                strokeColor: AppColors.bearCandleRed.opacity(0.8),
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
                imageName: user.isFriend ? "person.crop.circle.badge.minus" : "person.crop.circle.badge.plus",
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
            guard let guildId = appState.currentGuild?.id else { return }
            do {
                try await appState.blockUser(guildId: guildId, userId: user.globalMember.id)
                appState.showSuccess("User blocked successfully")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Block User")
            }
        }
    }
    
    private func unBlockUser() {
        Task {
            guard let guildId = appState.currentGuild?.id else { return }
            do {
                try await appState.unBlockUser(guildId: guildId, userId: user.globalMember.id)
                appState.showSuccess("Unblocked user")
                dismiss()
            } catch {
                appState.showError(error, title: "Failed to Unblock User")
            }
        }
    }
    
    private func addFriend() {
        Task {
            guard let guildId = appState.currentGuild?.id else { return }
            do {
                try await appState.sendFriendRequest(guildId: guildId, userId: user.globalMember.id)
                appState.showSuccess("Friend request sent!")
            } catch {
                appState.showError(error, title: "Failed to Send Friend Request")
            }
        }
    }
    
    private func removeFriend() {
        Task {
            guard let guildId = appState.currentGuild?.id else { return }
            do {
                try await appState.sendCancelFriendship(guildId: guildId, userId: user.globalMember.id)
                appState.showSuccess("Friendship removed")
            } catch {
                appState.showError(error, title: "Failed to end friendship")
            }
        }
    }
}

// MARK: - Guild Member Header View for Profile Sheet
struct GuildMemberProfileHeaderView: View {
    let user: GuildMembershipDTO
    
    var body: some View {
        // Top header section with gradient background
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

                Spacer(minLength: 60) // Leave space for dismiss button
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

                // User guild reputation
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
//import SwiftUI
//
//
//
//// MARK: - Announcements List View
//struct UserListView: View {
//    @Binding var bottomSheetContent: BottomSheetContent?
//    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//    
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var messagingManager: MessagingManager // Add messaging manager
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
//
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
//
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
//                                
//                        }
//                        Text(user.globalMember.username)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
//                        
//                        
//                        
//                        if user.isFriend {
//                            Image(systemName: "person.crop.circle")
//                                .font(.caption2)
//                                .fontWeight(.bold)
//                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
//                                
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
//                
//                // Friend indicator & chevron
//                HStack(spacing: 2) {
//                    // Removed user.newMessage indicator as User doesn't have that property
//                }
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
//        
//    }
//
// 
//    
//}
//
//
//
//// MARK: - Enhanced Announcement Detail View
//struct GuildUserDetailView: View {
//    let user: GuildMembershipDTO
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var messagingManager: MessagingManager // Add messaging manager
//    @EnvironmentObject var appState: AppState
//    
//    @State private var selectedTab: ProfileTab = .overview
//    @State private var showBlockUserConfirmation = false
//    @State private var showUnBlockUserConfirmation = false
//    @State private var showAddFriendConfirmation = false
//    @State private var showRemoveFriendConfirmation = false
//    
//    // Define your tabs
//    enum ProfileTab: String, CaseIterable {
//        case overview = "Overview"
//        case activity = "Activity"
//        case achievements = "Achievements"
//    }
//
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            // Main content
//            VStack(alignment: .leading, spacing: 0) {
//                // Top header section with gradient background
//                GuildMemberProfileHeaderView(user: user)
//                // Tab Headers - Fixed
//                tabHeader
//                
//                Divider()
//                
//                ScrollView(.vertical, showsIndicators: false) {
//                    tabContent
//                        .padding(.horizontal, 25)
//                        .padding(.vertical, 20)
//                }
//                .padding(.horizontal, 25)
//                .padding(.vertical, 20)
//                
//                
//                Divider()
//                    
//
//                HStack(spacing: 8) {
//                    DrawerActionButton(
//                        imageName: "nosign",
//                        backgroundColor: user.isBlocked ? AppColors.bearCandleRed.opacity(0.8) : AppColors.bearCandleRed.opacity(0.1),
//                        foregroundColor: AppColors.whiteText,
//                        strokeColor: AppColors.bearCandleRed.opacity(0.8),
//                        strokeWidth: 0.5,
//                        action: {
//                            if user.isBlocked {
//                            showUnBlockUserConfirmation = true
//                        } else {
//                            showBlockUserConfirmation = true
//                        }}
//                    )
//                    
//                    Spacer()
//                    
////                    DrawerActionButton(
////                        imageName: "person.fill.badge.plus",
////                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
////                        foregroundColor: AppColors.whiteText.opacity(0.8),
////                        strokeColor: AppColors.whiteText.opacity(0.3),
////                        strokeWidth: 0.5,
////                        action: {showAddFriendConfirmation = true }
////                    )
//                    DrawerActionButton(
//                        imageName: user.isFriend ? "person.crop.circle.badge.minus" : "person.crop.circle.badge.plus",
//                        backgroundColor: user.isFriend ? AppColors.friendAccent.opacity(0.6) : AppColors.gradientBackgroundDark.opacity(0.05),
//                        foregroundColor: AppColors.whiteText.opacity(0.8),
//                        strokeColor: user.isFriend ? AppColors.friendAccent : AppColors.whiteText.opacity(0.3),
//                        strokeWidth: 0.5,
//                        action: {
//                            if user.isFriend {
//                                showRemoveFriendConfirmation = true
//                            } else {
//                                showAddFriendConfirmation = true
//                            }
//                        }
//                    )
//
//                    DrawerActionButton(
//                        title: "Chat",
//                        imageName: "message.fill",
//                        backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
//                        foregroundColor: AppColors.whiteText.opacity(0.8),
//                        strokeColor: AppColors.whiteText.opacity(0.3),
//                        strokeWidth: 0.5,
//                        action: {
//                            dismiss() // If in a sheet
//                            Task {  // ✅ Add Task wrapper
//                                await messagingManager.openUserChat(with: user)
//                            }
//                        }
//                    )
//                }
//                .padding(.horizontal, 25)
//                .padding(.top, 20)
//                .background(AppColors.sheetBackground)
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//            .background(
//                ZStack {
//                    Color.clear
//                        .background(.ultraThinMaterial)
//                    AppColors.sheetBackground
//                    StaticPatternView()
//                    
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
//        // ✅ Block User Alert
//        .alert("Block User", isPresented: $showBlockUserConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Block", role: .destructive) {
//                blockUser()
//            }
//        } message: {
//            Text("Are you sure you want to block \(user.globalMember.username)? You won't see their messages or activity.")
//        }
//        
//        // ✅ Un Block User Alert
//        .alert("Block User", isPresented: $showUnBlockUserConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Un Block", role: .destructive) {
//                unBlockUser()
//            }
//        } message: {
//            Text("Are you sure you want to block \(user.globalMember.username)? You won't see their messages or activity.")
//        }
//        // ✅ Add Friend Alert
//        .alert("Add Friend", isPresented: $showAddFriendConfirmation) {
//            Button("Cancel", role: .cancel) { }
//            Button("Add Friend") {
//                addFriend()
//            }
//        } message: {
//            Text("Send a friend request to \(user.globalMember.username)?")
//        }
//        
//        // ✅ Remove Friend Alert
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
//    // ✅ Block user action
//    private func blockUser() {
//        Task {
//            guard let guildId = appState.currentGuild?.id else { return }
//            
//            do {
//                // TODO: Call API to block user
//                try await appState.blockUser(guildId: guildId, userId: user.globalMember.id)
//                appState.showSuccess("User blocked successfully")
//                dismiss()
//            } catch {
//                appState.showError(error, title: "Failed to Block User")
//            }
//        }
//    }
//    
//    // ✅ Un Block user action
//    private func unBlockUser() {
//        Task {
//            guard let guildId = appState.currentGuild?.id else { return }
//            
//            do {
//                // TODO: Call API to block user
//                try await appState.unBlockUser(guildId: guildId, userId: user.globalMember.id)
//                appState.showSuccess("Un Blocked user")
//                dismiss()
//            } catch {
//                appState.showError(error, title: "Failed to Un Block User")
//            }
//        }
//    }
//    
//    // ✅ Add friend action
//    private func addFriend() {
//        Task {
//            guard let guildId = appState.currentGuild?.id else { return }
//            do {
//                // TODO: Call API to add friend
//                try await appState.sendFriendRequest(guildId: guildId, userId: user.globalMember.id)
//                appState.showSuccess("Friend request sent!")
//            } catch {
//                appState.showError(error, title: "Failed to Send Friend Request")
//            }
//        }
//    }
//    
//    // ✅ Remove friend action
//    private func removeFriend() {
//        Task {
//            guard let guildId = appState.currentGuild?.id else { return }
//            do {
//                // TODO: Call API to add friend
//                try await appState.sendCancelFriendship(guildId: guildId, userId: user.globalMember.id)
//                appState.showSuccess("Friendship removed")
//            } catch {
//                appState.showError(error, title: "Failed to end friendship")
//            }
//        }
//    }
//    
//    // MARK: - Tab Header
//    private var tabHeader: some View {
//        HStack(spacing: 0) {
//            ForEach(ProfileTab.allCases, id: \.self) { tab in
//                Button(action: {
//                    withAnimation(.easeInOut(duration: 0.2)) {
//                        selectedTab = tab
//                    }
//                }) {
//                    VStack(spacing: 8) {
//                        Text(tab.rawValue)
//                            .font(.subheadline)
//                            .fontWeight(selectedTab == tab ? .semibold : .regular)
//                            .foregroundColor(selectedTab == tab ? AppColors.accentColor : AppColors.greyText)
//                        
//                        // Active indicator
//                        Rectangle()
//                            .fill(selectedTab == tab ? AppColors.accentColor : Color.clear)
//                            .frame(height: 2)
//                    }
//                }
//                .frame(maxWidth: .infinity)
//            }
//        }
//        .padding(.horizontal, 25)
//        .padding(.top, 12)
//        .background(AppColors.sheetBackground)
//    }
//    
//    // MARK: - Tab Content
//    @ViewBuilder
//    private var tabContent: some View {
//        switch selectedTab {
//        case .overview:
//            overviewContent
//        case .activity:
//            activityContent
//        case .achievements:
//            achievementsContent
//        }
//    }
//    
//    private var overviewContent: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Overview")
//                .font(.title3)
//                .fontWeight(.bold)
//            
//            // Add your overview content here
//            Text("User stats, bio, and other overview information...")
//                .foregroundColor(AppColors.greyText)
//            
//            // Example content to demonstrate scrolling
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
//    private var activityContent: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Recent Activity")
//                .font(.title3)
//                .fontWeight(.bold)
//            
//            // Add your activity content here
//            ForEach(0..<8) { i in
//                HStack(spacing: 12) {
//                    Image(systemName: "circle.fill")
//                        .font(.caption)
//                        .foregroundColor(AppColors.accentColor)
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Activity \(i + 1)")
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
//    private var achievementsContent: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Achievements")
//                .font(.title3)
//                .fontWeight(.bold)
//            
//            // Add your achievements content here
//            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
//                ForEach(0..<10) { i in
//                    VStack(spacing: 8) {
//                        Image(systemName: "star.fill")
//                            .font(.title)
//                            .foregroundColor(AppColors.accentColor)
//                        Text("Achievement \(i + 1)")
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
//    
//
//}
//
//
//// MARK: - Guild Member header view for profile sheet
//struct GuildMemberProfileHeaderView: View {
//    let user: GuildMembershipDTO
//    
//    
//    
//    var body: some View {
// 
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
//
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
//                    
//                    
//                    HStack (spacing: 2){
//                        if user.isBlocked {
//                            Image(systemName: "nosign")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundColor(AppColors.bearCandleRed)
//                                
//                        }
//                    
//                        Text(user.globalMember.username)
//                            .font(.title3)
//                            .fontWeight(.medium)
//                            .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.whiteText)
//                        
//                        
//                        if user.isFriend {
//                            Image(systemName: "person.crop.circle")
//                                .font(.body)
//                                .fontWeight(.bold)
//                                .foregroundColor(user.isBlocked ? AppColors.greyText : AppColors.friendAccent)
//                                
//                                .padding(.leading, 3)
//                        }
//
//                        
//                        
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
//                // member since
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
//
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
