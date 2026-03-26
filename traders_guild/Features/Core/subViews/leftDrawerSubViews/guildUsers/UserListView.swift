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
    @EnvironmentObject var rlAppState: RLAppState
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
        .task {
            await loadGuildMembersIfNeeded()
            await loadFriendRequestsIfNeeded()
            await loadFriendsIfNeeded()
        }
    }
    
    // MARK: - Refresh
    
    private func refreshMembers() async {
        guard let guild = rlAppState.currentGuild else { return }
        await leftDrawerViewModel.refreshGuildMembers(guildId: guild.id, rlAppState: rlAppState)
        await leftDrawerViewModel.refreshFriends(guildId: guild.id, rlAppState: rlAppState)
        await leftDrawerViewModel.refreshFriendRequests(guildId: guild.id, rlAppState: rlAppState)
    }
    
    private func loadGuildMembersIfNeeded() async {
        guard let guild = rlAppState.currentGuild else { return }
        guard leftDrawerViewModel.guildMembers.isEmpty else { return }
        await leftDrawerViewModel.refreshGuildMembers(guildId: guild.id, rlAppState: rlAppState)
    }
    
    private func loadFriendRequestsIfNeeded() async {
        guard let guild = rlAppState.currentGuild else { return }
        guard leftDrawerViewModel.pendingFriendRequestsIncoming.isEmpty,
              leftDrawerViewModel.pendingFriendRequestsOutgoing.isEmpty else { return }
        await leftDrawerViewModel.refreshFriendRequests(guildId: guild.id, rlAppState: rlAppState)
    }
    
    private func loadFriendsIfNeeded() async {
        guard let guild = rlAppState.currentGuild else { return }
        guard leftDrawerViewModel.friendsRL.isEmpty else { return }
        await leftDrawerViewModel.refreshFriends(guildId: guild.id, rlAppState: rlAppState)
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: UserListTab) -> Int {
        switch tab {
        case .guild: return leftDrawerViewModel.guildMembers.count
        case .friends:
            return leftDrawerViewModel.friendsRL.count
                + leftDrawerViewModel.pendingFriendRequestsIncoming.count
                + leftDrawerViewModel.pendingFriendRequestsOutgoing.count
        }
    }
    
    // MARK: - Guild Members Content
    
    private var guildMembersContent: some View {
        Group {
            if leftDrawerViewModel.isLoadingGuildMembers && leftDrawerViewModel.guildMembers.isEmpty {
                UnifiedLoadingState(message: "Loading guild members...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.guildMembers.isEmpty {
                UnifiedEmptyState(
                    icon: "person.3",
                    title: "No members yet",
                    subtitle: "Guild members will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(leftDrawerViewModel.guildMembers) { member in
                        UnifiedGuildMemberRow(user: member) {
                            if member.userId == rlAppState.currentUser?.id {
                                bottomSheetContent = .profile
                            } else {
                                bottomSheetContent = .guildMemberRL(member)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Friends Content
    
    private var friendsContent: some View {
        Group {
            if leftDrawerViewModel.isLoadingFriendsRL && leftDrawerViewModel.friendsRL.isEmpty &&
                leftDrawerViewModel.pendingFriendRequestsIncoming.isEmpty &&
                leftDrawerViewModel.pendingFriendRequestsOutgoing.isEmpty {
                UnifiedLoadingState(message: "Loading friends...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.friendsRL.isEmpty &&
                        leftDrawerViewModel.pendingFriendRequestsIncoming.isEmpty &&
                        leftDrawerViewModel.pendingFriendRequestsOutgoing.isEmpty {
                UnifiedEmptyState(
                    icon: "person.2",
                    title: "No friends yet",
                    subtitle: "Add friends to see them here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    if !leftDrawerViewModel.pendingFriendRequestsIncoming.isEmpty {
                        PendingRequestsSection(
                            title: "Incoming Requests",
                            requests: leftDrawerViewModel.pendingFriendRequestsIncoming,
                            onAccept: { request in
                                await acceptFriendRequest(request)
                            },
                            onDecline: { request in
                                await declineFriendRequest(request)
                            }
                        )
                    }
                    
                    if !leftDrawerViewModel.pendingFriendRequestsOutgoing.isEmpty {
                        PendingOutgoingSection(
                            title: "Outgoing Requests",
                            requests: leftDrawerViewModel.pendingFriendRequestsOutgoing
                        )
                    }
                    
                    ForEach(leftDrawerViewModel.friendsRL) { friend in
                        FriendRow(friend: friend) {
                            if let member = leftDrawerViewModel.guildMembers.first(where: { $0.userId == friend.userId }) {
                                if member.userId == rlAppState.currentUser?.id {
                                    bottomSheetContent = .profile
                                } else {
                                    bottomSheetContent = .guildMemberRL(member)
                                }
                            } else {
                                rlAppState.showInfo("Member data not loaded yet")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func acceptFriendRequest(_ request: RLFriendRequestIncomingDTO) async {
        do {
            _ = try await rlAppState.acceptFriendRequest(requestId: request.id)
            leftDrawerViewModel.updateGuildMember(membershipId: request.fromMembershipId) { member in
                member.updating(isFriend: true, friendshipStatus: "accepted")
            }
            if let guildId = rlAppState.currentGuild?.id {
                await leftDrawerViewModel.refreshFriendRequests(guildId: guildId, rlAppState: rlAppState)
                await leftDrawerViewModel.refreshFriends(guildId: guildId, rlAppState: rlAppState)
            }
            rlAppState.showSuccess("Friend request accepted")
        } catch { }
    }
    
    private func declineFriendRequest(_ request: RLFriendRequestIncomingDTO) async {
        do {
            _ = try await rlAppState.declineFriendRequest(requestId: request.id)
            leftDrawerViewModel.updateGuildMember(membershipId: request.fromMembershipId) { member in
                member.updating(isFriend: false, friendshipStatus: nil)
            }
            if let guildId = rlAppState.currentGuild?.id {
                await leftDrawerViewModel.refreshFriendRequests(guildId: guildId, rlAppState: rlAppState)
                await leftDrawerViewModel.refreshFriends(guildId: guildId, rlAppState: rlAppState)
            }
            rlAppState.showInfo("Friend request declined")
        } catch { }
    }
}

// MARK: - ================================================================================================
// MARK: - PENDING FRIEND REQUESTS (REAL API)
// MARK: - ================================================================================================

struct PendingRequestsSection: View {
    let title: String
    let requests: [RLFriendRequestIncomingDTO]
    let onAccept: (RLFriendRequestIncomingDTO) async -> Void
    let onDecline: (RLFriendRequestIncomingDTO) async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.greyText)
            
            ForEach(requests) { request in
                PendingRequestRow(request: request, onAccept: onAccept, onDecline: onDecline)
            }
        }
    }
}

struct PendingOutgoingSection: View {
    let title: String
    let requests: [RLFriendRequestOutgoingDTO]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.greyText)
            
            ForEach(requests) { request in
                PendingOutgoingRow(request: request)
            }
        }
    }
}

struct PendingRequestRow: View {
    let request: RLFriendRequestIncomingDTO
    let onAccept: (RLFriendRequestIncomingDTO) async -> Void
    let onDecline: (RLFriendRequestIncomingDTO) async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            UnifiedMemberAvatar(
                username: request.fromDisplayName,
                avatarURL: request.fromAvatarUrl,
                isOnline: false
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                Text("@\(request.fromUsername)")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Accept") {
                    Task { await onAccept(request) }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Decline") {
                    Task { await onDecline(request) }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surfaceWhite03)
        )
    }
}

struct PendingOutgoingRow: View {
    let request: RLFriendRequestOutgoingDTO
    
    var body: some View {
        HStack(spacing: 12) {
            UnifiedMemberAvatar(
                username: request.toDisplayName,
                avatarURL: request.toAvatarUrl,
                isOnline: false
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.toDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.whiteText)
                Text("@\(request.toUsername)")
                    .font(.caption)
                    .foregroundColor(AppColors.greyText)
            }
            
            Spacer()
            
            Text("Pending")
                .font(.caption)
                .foregroundColor(AppColors.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(AppColors.accentColor.opacity(0.15))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surfaceWhite03)
        )
    }
}

// MARK: - Friend Row (Real API)

struct FriendRow: View {
    let friend: RLFriendDTO
    let onTap: () -> Void
    
    @EnvironmentObject var rlAppState: RLAppState
    
    private var isOnline: Bool {
        rlAppState.effectiveOnlineStatus(userId: friend.userId, fallback: friend.isOnline)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                UnifiedMemberAvatar(
                    username: friend.username,
                    avatarURL: friend.avatarUrl,
                    isOnline: isOnline
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.whiteText)
                    Text(friend.displayUsername)
                        .font(.caption)
                        .foregroundColor(AppColors.greyText)
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "shield.pattern.checkered")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text("\(friend.globalReputation)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(AppColors.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surfaceWhite03)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ================================================================================================
// MARK: - GUILD USER DETAIL VIEW (REAL API)
// MARK: - ================================================================================================

struct GuildUserDetailViewRL: View {
    @State private var member: RLGuildMemberDTO
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rlMessagingManager: RLMessagingManager
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    
    @State private var extendedProfile: RLUserProfileDTO? = nil
    @State private var statistics: RLUserGlobalStatisticsDTO? = nil
    @State private var userMarkers: [RLTopMarkerDTO] = []
    @State private var awards: [RLUserAwardDTO] = []
    @State private var awardsSummary: RLAwardsSummaryDTO? = nil
    @State private var isLoading = true
    
    init(member: RLGuildMemberDTO) {
        _member = State(initialValue: member)
    }

    private var isCurrentUser: Bool {
        member.userId == rlAppState.currentUser?.id
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                GuildMemberProfileHeaderViewRL(member: member)
                
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading profile...")
                            .font(.subheadline)
                            .foregroundColor(AppColors.greyText)
                            .padding(.top, 12)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProfileContentView(
                        extendedProfile: extendedProfile,
                        markersSummary: statistics,
                        userMarkers: userMarkers,
                        awards: awards,
                        awardsSummary: awardsSummary,
                        stats: buildStats(),
                        isCurrentUser: isCurrentUser,
                        username: member.username,
                        tabs: [.overview, .markers, .awards],
                        onMarkerTap: { marker in
                            leftDrawerViewModel.requestNavigationToMarker(marker)
                            dismiss()
                        }
                    )
                }
                
                Divider()
                
                GuildUserActionButtonsRL(member: member) { updatedMember in
                    member = updatedMember
                }
                    .environmentObject(rlMessagingManager)
                    .environmentObject(rlAppState)
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
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .task {
            await loadProfileData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .guildMemberPerformanceDidUpdate)) { notification in
            guard let userId = notification.userInfo?["userId"] as? UUID,
                  userId == member.userId else { return }

            if let newGuildReputation = notification.userInfo?["newGuildReputation"] as? Int,
               let newGlobalReputation = notification.userInfo?["newGlobalReputation"] as? Int,
               let newAccuracyRate = notification.userInfo?["newAccuracyRate"] as? Double {
                member = member.withPerformance(
                    guildReputation: newGuildReputation,
                    accuracyRate: newAccuracyRate,
                    globalReputation: newGlobalReputation
                )
            }
        }
    }
    
    private func loadProfileData() async {
        guard let guildId = rlAppState.currentGuild?.id else {
            isLoading = false
            return
        }
        
        let data = await leftDrawerViewModel.loadMemberProfile(
            member: member,
            rlAppState: rlAppState,
            guildId: guildId
        )
        
        await MainActor.run {
            extendedProfile = data.profile
            statistics = data.statistics
            userMarkers = data.userMarkers
            awards = data.awards
            awardsSummary = data.awardsSummary
            isLoading = false
        }
    }
    
    private func buildStats() -> [ProfileStatDTO] {
        [
            ProfileStatDTO(
                label: "Guild Reputation",
                value: "\(member.reputation)",
                icon: "shield.checkered",
                color: AppColors.accentColor,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Global Reputation",
                value: "\(member.globalReputation)",
                icon: "globe",
                color: .blue,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Days in Guild",
                value: "\(member.daysInGuild)",
                icon: "calendar",
                color: .green,
                trend: nil
            ),
            ProfileStatDTO(
                label: "Contribution",
                value: "\(member.contributionScore)%",
                icon: "chart.bar.fill",
                color: .orange,
                trend: nil
            )
        ]
    }
}

// MARK: - ================================================================================================
// MARK: - GUILD MEMBER PROFILE HEADER VIEW (REAL API)
// MARK: - ================================================================================================

struct GuildMemberProfileHeaderViewRL: View {
    let member: RLGuildMemberDTO
    @EnvironmentObject var rlAppState: RLAppState
    
    private var isOnline: Bool {
        rlAppState.effectiveOnlineStatus(userId: member.userId, fallback: member.isOnline)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 15) {
                UnifiedMemberAvatar(
                    username: member.username,
                    avatarURL: member.avatarUrl,
                    isOnline: isOnline,
                    size: 60
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 2) {
                        if member.isBlocked {
                            Image(systemName: "nosign")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.bearCandleRed)
                        }
                        
                        Text(member.username)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(member.isBlocked ? AppColors.greyText : AppColors.whiteText)
                        
                        if member.isFriend {
                            Image(systemName: "person.crop.circle")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(member.isBlocked ? AppColors.greyText : AppColors.friendAccent)
                                .padding(.leading, 3)
                        }
                    }
                    
                    UnifiedRoleBadge(
                        member: member,
                        showReputation: true,
                        fontSize: .caption,
                        iconSize: .caption2
                    )
                }
                
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 25)
            .padding(.top, 25)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.greyText)
                    Text("\(member.memberSince)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.greyText)
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
// MARK: - GUILD USER ACTION BUTTONS (REAL API)
// MARK: - ================================================================================================


//
//  UserListView+RL.swift
//  traders_guild
//
//  Updated Guild User Action Buttons that use RLMessagingManager for chat.
//  Replace the existing GuildUserActionButtonsRL in UserListView.swift with this version.
//


// MARK: - ================================================================================================
// MARK: - GUILD USER ACTION BUTTONS (REAL API) - UPDATED FOR RL MESSAGING
// MARK: - ================================================================================================

/// Updated action buttons that use RLMessagingManager for opening DM chats.
/// This version directly opens DM threads via the new backend system.
struct GuildUserActionButtonsRL: View {
    let member: RLGuildMemberDTO
    let onMemberUpdate: (RLGuildMemberDTO) -> Void
    
    @EnvironmentObject var rlAppState: RLAppState
    @EnvironmentObject var rlMessagingManager: RLMessagingManager   // NEW: For DM chats
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var rightDrawerViewModel: RLRightDrawerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showBlockUserConfirmation = false
    @State private var showUnBlockUserConfirmation = false
    @State private var showAddFriendConfirmation = false
    @State private var showRemoveFriendConfirmation = false
    @State private var isOpeningChat = false
    @State private var showReportReasonSheet = false
    
    private var isCurrentUser: Bool {
        member.userId == rlAppState.currentUser?.id
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Block/Unblock button
            DrawerActionButton(
                imageName: "nosign",
                backgroundColor: member.isBlocked ? AppColors.bearCandleRed.opacity(0.8) : AppColors.bearCandleRed.opacity(0.1),
                foregroundColor: member.isBlocked ? AppColors.whiteText : AppColors.bearCandleRed,
                strokeColor: AppColors.bearCandleRed.opacity(0.6),
                strokeWidth: 0.5,
                action: {
                    if member.isBlocked {
                        showUnBlockUserConfirmation = true
                    } else {
                        showBlockUserConfirmation = true
                    }
                }
            )
            
            Spacer()
            
            // Friend action button
            DrawerActionButton(
                imageName: friendActionIcon,
                backgroundColor: friendActionBackgroundColor,
                foregroundColor: friendActionForegroundColor,
                strokeColor: friendActionStrokeColor,
                strokeWidth: 0.5,
                action: {
                    if member.isFriend {
                        showRemoveFriendConfirmation = true
                    } else if member.hasPendingIncomingRequest || member.hasPendingOutgoingRequest {
                        rlAppState.showInfo(member.friendshipStatusDisplay)
                    } else if member.canSendFriendRequest {
                        showAddFriendConfirmation = true
                    } else {
                        rlAppState.showInfo(member.friendshipStatusDisplay)
                    }
                }
            )
            
            // Chat button - never shown for current user profile
            if !isCurrentUser {
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
                            await openDMChat()
                        }
                    }
                )
                .opacity(isOpeningChat ? 0.5 : 1.0)
                .disabled(isOpeningChat)
            }
            
            // Report user (not shown for current user)
            if !isCurrentUser {
                DrawerActionButton(
                    imageName: "flag",
                    backgroundColor: AppColors.gradientBackgroundDark.opacity(0.05),
                    foregroundColor: AppColors.whiteText.opacity(0.8),
                    strokeColor: AppColors.whiteText.opacity(0.3),
                    strokeWidth: 0.5,
                    action: { showReportReasonSheet = true }
                )
            }
        }
        .sheet(isPresented: $showReportReasonSheet) {
            ReportReasonSheet(
                title: "Why are you reporting this user?",
                includeScam: true,
                onReasonSelected: { reason in
                    reportUser(reason: reason)
                    showReportReasonSheet = false
                },
                onCancel: { showReportReasonSheet = false }
            )
        }
        .alert("Block User", isPresented: $showBlockUserConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Are you sure you want to block \(member.username)? You won't see their messages or activity.")
        }
        .alert("Unblock User", isPresented: $showUnBlockUserConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock") {
                unblockUser()
            }
        } message: {
            Text("Are you sure you want to unblock \(member.username)?")
        }
        .alert("Add Friend", isPresented: $showAddFriendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Add Friend") {
                addFriend()
            }
        } message: {
            Text("Send a friend request to \(member.username)?")
        }
        .alert("Remove Friend", isPresented: $showRemoveFriendConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Friendship") {
                removeFriend()
            }
        } message: {
            Text("Un-friend User: \(member.username)?")
        }
    }

    // MARK: - Friend Action Styling
    
    private var friendActionIcon: String {
        if member.isFriend {
            return "person.crop.circle.badge.checkmark"
        }
        if member.hasPendingIncomingRequest {
            return "person.crop.circle.badge.exclamationmark"
        }
        if member.hasPendingOutgoingRequest {
            return "person.crop.circle.badge.clock"
        }
        return "person.crop.circle.badge.plus"
    }

    private var friendActionBackgroundColor: Color {
        if member.isFriend {
            return AppColors.friendAccent.opacity(0.6)
        }
        if member.hasPendingIncomingRequest || member.hasPendingOutgoingRequest {
            return AppColors.accentColor.opacity(0.2)
        }
        return AppColors.gradientBackgroundDark.opacity(0.05)
    }
    
    private var friendActionForegroundColor: Color {
        if member.isFriend {
            return AppColors.whiteText.opacity(0.9)
        }
        if member.hasPendingIncomingRequest || member.hasPendingOutgoingRequest {
            return AppColors.accentColor
        }
        return AppColors.whiteText.opacity(0.8)
    }
    
    private var friendActionStrokeColor: Color {
        if member.isFriend {
            return AppColors.friendAccent
        }
        if member.hasPendingIncomingRequest || member.hasPendingOutgoingRequest {
            return AppColors.accentColor
        }
        return AppColors.whiteText.opacity(0.3)
    }
    
    // MARK: - Actions
    
    private func blockUser() {
        Task {
            do {
                _ = try await rlAppState.blockUser(membershipId: member.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await leftDrawerViewModel.refreshGuildMembers(
                        guildId: guildId,
                        rlAppState: rlAppState
                    )
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                applyMemberUpdate { current in
                    current.updating(isFriend: false, friendshipStatus: nil, isBlocked: true)
                }
                dismiss()
            } catch { }
        }
    }
    
    private func unblockUser() {
        Task {
            do {
                _ = try await rlAppState.unblockUser(membershipId: member.membershipId)
                if let guildId = rlAppState.currentGuild?.id {
                    await leftDrawerViewModel.refreshGuildMembers(
                        guildId: guildId,
                        rlAppState: rlAppState
                    )
                    await rightDrawerViewModel.refresh(for: guildId, appState: rlAppState)
                }
                applyMemberUpdate { current in
                    current.updating(isBlocked: false)
                }
                dismiss()
            } catch { }
        }
    }
    
    private func addFriend() {
        Task {
            do {
                _ = try await rlAppState.sendFriendRequest(toMembershipId: member.membershipId)
                applyMemberUpdate { current in
                    current.updating(isFriend: false, friendshipStatus: "pending_sent")
                }
                rlAppState.showSuccess("Friend request sent")
            } catch { }
        }
    }
    
    private func removeFriend() {
        Task {
            do {
                _ = try await rlAppState.removeFriend(membershipId: member.membershipId)
                applyMemberUpdate { current in
                    current.updating(isFriend: false, friendshipStatus: nil)
                }
            } catch { }
        }
    }
    
    private func reportUser(reason: String) {
        Task {
            do {
                guard let guildId = rlAppState.currentGuild?.id else { return }
                try await rlAppState.reportUser(
                    guildId: guildId,
                    userId: member.userId,
                    reason: reason
                )
            } catch {
                // Error shown by rlAppState
            }
        }
    }
    
    private func applyMemberUpdate(_ transform: (RLGuildMemberDTO) -> RLGuildMemberDTO) {
        if let updated = leftDrawerViewModel.updateGuildMember(
            membershipId: member.membershipId,
            transform: transform
        ) {
            onMemberUpdate(updated)
        }
    }
    
    // MARK: - NEW: Open DM Chat via RLMessagingManager
    
    /// Opens a DM chat with this member using the new RLMessagingManager.
    /// Creates a DM thread if one doesn't exist.
    private func openDMChat() async {
        guard !isCurrentUser else { return }
        isOpeningChat = true
        defer { isOpeningChat = false }
        
        // Use the new RLMessagingManager to open/create DM thread
        await rlMessagingManager.openDMChat(with: member)
    }
}

// MARK: - ================================================================================================
// MARK: - USER LIST VIEW ENVIRONMENT UPDATE HELPER
// MARK: - ================================================================================================

/// Extension to help UserListView inject the RLMessagingManager
extension View {
    /// Adds RLMessagingManager environment object for views that need chat functionality
    func withRLMessaging(_ manager: RLMessagingManager) -> some View {
        self.environmentObject(manager)
    }
}
