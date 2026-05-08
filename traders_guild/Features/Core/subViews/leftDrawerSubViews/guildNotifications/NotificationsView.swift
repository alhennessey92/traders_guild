//
//  NotificationsView.swift
//  traders_guild
//
//  Notifications View for Left Drawer
//  Displays user notifications with filtering tabs
//  Uses UnifiedComponents for consistent styling
//

import SwiftUI

// MARK: - ================================================================================================
// MARK: - NOTIFICATION TAB DEFINITION
// MARK: - ================================================================================================

/// Tab enum for notification filtering
enum NotificationTab: String, CaseIterable, UnifiedTabItem {
    case all = "All"
    case guild = "Guild"
    case personal = "Personal"
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "bell.fill"
        case .guild: return "person.3.fill"
        case .personal: return "person.fill"
        }
    }
}

// MARK: - ================================================================================================
// MARK: - NOTIFICATIONS LIST VIEW
// MARK: - ================================================================================================

struct NotificationsListView: View {
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var notificationNavigationManager: NotificationNavigationManager
    @EnvironmentObject var rlAppState: RLAppState
    
    // Tab state
    @State private var selectedTab: NotificationTab = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector - OUTSIDE ScrollView (fixed)
            UnifiedTabBar(
                selectedTab: $selectedTab,
                size: .compact,
                theme: .blue,
                countForTab: { tab in getCountForTab(tab) },
                titleForTab: { tab in tabTitle(for: tab) },
                spacing: 6
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 12)
            
            // Scrollable content with pull to refresh
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    switch selectedTab {
                    case .all:
                        allNotificationsContent
                    case .guild:
                        guildNotificationsContent
                    case .personal:
                        personalNotificationsContent
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
            .refreshable {
                await refreshNotifications()
            }
        }
        // Loading overlay for navigation
        .overlay {
            if notificationNavigationManager.isNavigating {
                NavigationLoadingOverlay()
            }
        }
        .task {
            await leftDrawerViewModel.refreshNotificationsIfNeeded(rlAppState: rlAppState)
            await leftDrawerViewModel.refreshFriendRequests(
                guildId: rlAppState.currentGuild?.id,
                rlAppState: rlAppState
            )
        }
    }
    
    // MARK: - Refresh
    private func refreshNotifications() async {
        await leftDrawerViewModel.refreshNotifications(rlAppState: rlAppState)
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: NotificationTab) -> Int {
        // The Guild tab is scoped to the currently-active guild; backend stats are
        // aggregated across every guild the user belongs to, so always derive the
        // Guild count from the locally-filtered list to match what is shown.
        if tab == .guild {
            return filteredNotifications(for: .guild).filter { !$0.isRead }.count
        }

        if let stats = leftDrawerViewModel.notificationStats {
            switch tab {
            case .all:
                return stats.unreadCount
            case .personal:
                return stats.personalCount
            case .guild:
                return 0 // unreachable, handled above
            }
        }

        switch tab {
        case .all:
            return leftDrawerViewModel.userNotifications.filter { !$0.isRead }.count
        case .personal:
            return filteredNotifications(for: .personal).filter { !$0.isRead }.count
        case .guild:
            return 0 // unreachable
        }
    }
    
    // MARK: - Tab Titles

    /// Resolve a tab's display title; the Guild tab shows the current guild's name
    /// so users know notifications under it are scoped to the active guild.
    private func tabTitle(for tab: NotificationTab) -> String {
        switch tab {
        case .all, .personal:
            return tab.title
        case .guild:
            if let name = rlAppState.currentGuild?.name, !name.isEmpty {
                return name.hasSuffix(" Guild") ? name : "\(name) Guild"
            }
            return tab.title
        }
    }

    // MARK: - Filtered Notifications

    /// Returns the guild_id associated with a notification, preferring the destination
    /// payload (most reliable) and falling back to the data payload.
    private func notificationGuildId(_ notification: RLNotificationDTO) -> UUID? {
        notification.destination?.guildId ?? notification.guildId
    }

    private func filteredNotifications(for tab: NotificationTab) -> [RLNotificationDTO] {
        switch tab {
        case .all:
            // All notifications across every guild the user belongs to
            return leftDrawerViewModel.userNotifications
        case .guild:
            // Guild tab: announcements, events, member events — scoped to the active guild only
            let activeGuildId = rlAppState.currentGuild?.id
            return leftDrawerViewModel.userNotifications.filter { notification in
                guard notification.type?.isGuild == true else { return false }
                guard let activeGuildId else { return true }
                guard let notificationGuildId = notificationGuildId(notification) else {
                    // No guild_id on the notification — show under the active guild as a safe default
                    return true
                }
                return notificationGuildId == activeGuildId
            }
        case .personal:
            // Personal tab: cross-guild user-personal events (DMs, mentions, friend events,
            // marker reactions, reputation changes). These are scoped to the user, not a guild.
            return leftDrawerViewModel.userNotifications.filter { $0.type?.isPersonal == true }
        }
    }
    
    // MARK: - All Notifications Content
    
    private var allNotificationsContent: some View {
        Group {
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.userNotifications.isEmpty {
                UnifiedLoadingState(message: "Loading notifications...")
                    .padding(.top, 40)
            } else if leftDrawerViewModel.userNotifications.isEmpty {
                UnifiedEmptyState(
                    icon: "bell.slash",
                    title: "No notifications",
                    subtitle: "You're all caught up!"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(leftDrawerViewModel.userNotifications) { notification in
                        NotificationCard(notification: notification)
                    }
                }
            }
        }
    }
    
    // MARK: - Guild Notifications Content
    
    private var guildNotificationsContent: some View {
        Group {
            let notifications = filteredNotifications(for: .guild)
            
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.userNotifications.isEmpty {
                UnifiedLoadingState(message: "Loading notifications...")
                    .padding(.top, 40)
            } else if notifications.isEmpty {
                UnifiedEmptyState(
                    icon: "person.3",
                    title: "No guild notifications",
                    subtitle: "Guild activity will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(notifications) { notification in
                        NotificationCard(notification: notification)
                    }
                }
            }
        }
    }
    
    // MARK: - Personal Notifications Content
    
    private var personalNotificationsContent: some View {
        Group {
            let notifications = filteredNotifications(for: .personal)
            
            if leftDrawerViewModel.isLoading && leftDrawerViewModel.userNotifications.isEmpty {
                UnifiedLoadingState(message: "Loading notifications...")
                    .padding(.top, 40)
            } else if notifications.isEmpty {
                UnifiedEmptyState(
                    icon: "person",
                    title: "No personal notifications",
                    subtitle: "Messages and mentions will appear here"
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(notifications) { notification in
                        NotificationCard(notification: notification)
                    }
                }
            }
        }
    }
}

// MARK: - ================================================================================================
// MARK: - NOTIFICATION CARD
// MARK: - ================================================================================================

struct NotificationCard: View {
    let notification: RLNotificationDTO       // <<< Changed type

    @State private var isPressed = false
    @State private var hasRecordedView = false
    @State private var showAsUnread: Bool
    @State private var inviteActionTaken = false
    @State private var isProcessingInvite = false
    @State private var friendRequestActionTaken = false
    @State private var isProcessingFriendRequest = false

    @EnvironmentObject var rlAppState: RLAppState     // <<< Add rlAppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var notificationNavigationManager: NotificationNavigationManager

    init(notification: RLNotificationDTO) {           // <<< Changed type
        self.notification = notification
        _showAsUnread = State(initialValue: !notification.isRead)
    }
    
    /// Icon and color now come from the DTO computed properties
    private var notificationIcon: String {
        notification.icon           // Uses the computed property on RLNotificationDTO
    }
    
    private var notificationColor: Color {
        notification.accentColor    // Uses the computed property on RLNotificationDTO
    }

    private var iconBadgeFillOpacity: Double {
        if ThemeManager.shared.currentTheme == .lightGrey {
            return showAsUnread ? 0.32 : 0.24
        }
        return showAsUnread ? 0.20 : 0.14
    }

    private var notificationIconForeground: Color {
        if ThemeManager.shared.currentTheme == .lightGrey {
            return showAsUnread ? AppColors.primaryForeground : AppColors.primaryForeground.opacity(0.78)
        }
        return showAsUnread ? notificationColor : notificationColor.opacity(0.72)
    }

    private var titleColor: Color {
        showAsUnread ? AppColors.whiteText : AppColors.whiteText.opacity(0.8)
    }

    private var bodyColor: Color {
        showAsUnread ? AppColors.whiteText.opacity(0.72) : AppColors.whiteText.opacity(0.5)
    }

    private var timeColor: Color {
        showAsUnread ? AppColors.whiteText.opacity(0.55) : AppColors.whiteText.opacity(0.32)
    }

    private var semanticBorderColor: Color {
        showAsUnread ? (notification.semanticBorderColor ?? .clear) : .clear
    }

    private var showsSemanticBorder: Bool {
        showAsUnread && notification.semanticBorderColor != nil
    }

    private var incomingFriendRequest: RLFriendRequestIncomingDTO? {
        leftDrawerViewModel.incomingFriendRequest(for: notification)
    }
    
    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .top, spacing: 10) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(notificationColor.opacity(iconBadgeFillOpacity))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: notificationIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(notificationIconForeground)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(notification.displayTitle)          // <<< .title -> .displayTitle
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(titleColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Text(notification.timeAgoFormatted)
                            .font(.system(size: 10))
                            .foregroundColor(timeColor)

                        if showAsUnread {
                            Circle()
                                .fill(AppColors.accentColor)
                                .frame(width: 8, height: 8)
                                .padding(.top, 4)
                        }
                    }

                    Text(notification.displayBody)               // <<< .content -> .displayBody
                        .font(.system(size: 12))
                        .foregroundColor(bodyColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Guild Invite Action Buttons
                    if notification.isGuildInvite {
                        if let guildId = notification.guildId,
                           rlAppState.userGuilds.contains(where: { $0.guild.id == guildId }) {
                            Text("Already a member")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.whiteText.opacity(0.4))
                                .padding(.top, 2)
                        } else if !inviteActionTaken {
                            HStack(spacing: 8) {
                                Button(action: acceptInvite) {
                                    HStack(spacing: 4) {
                                        if isProcessingInvite {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .tint(AppColors.onAccentForeground)
                                        }
                                        Text("Accept")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppColors.statusPositive80)
                                    .foregroundColor(AppColors.onAccentForeground)
                                    .cornerRadius(6)
                                }
                                .disabled(isProcessingInvite)

                                Button(action: declineInvite) {
                                    Text("Decline")
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.panelFillEmphasis)
                                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                                        .cornerRadius(6)
                                }
                                .disabled(isProcessingInvite)

                                Spacer()
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Responded")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.whiteText.opacity(0.4))
                                .padding(.top, 2)
                        }
                    }

                    // Friend Request Action Buttons
                    if notification.type == .friendRequest && !friendRequestActionTaken {
                        if let request = incomingFriendRequest {
                            HStack(spacing: 8) {
                                Button {
                                    Task { await acceptFriendRequest(request: request) }
                                } label: {
                                    HStack(spacing: 4) {
                                        if isProcessingFriendRequest {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .tint(AppColors.onAccentForeground)
                                        }
                                        Text("Accept")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppColors.friendAccent.opacity(0.8))
                                    .foregroundColor(AppColors.onAccentForeground)
                                    .cornerRadius(6)
                                }
                                .disabled(isProcessingFriendRequest)

                                Button {
                                    Task { await declineFriendRequest(request: request) }
                                } label: {
                                    Text("Decline")
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.panelFillEmphasis)
                                        .foregroundColor(AppColors.whiteText.opacity(0.7))
                                        .cornerRadius(6)
                                }
                                .disabled(isProcessingFriendRequest)

                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    } else if notification.type == .friendRequest && friendRequestActionTaken {
                        Text("Responded")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.whiteText.opacity(0.4))
                            .padding(.top, 2)
                    }
                }

                // Chevron for navigable notifications
                if notification.isActionable && !notification.isGuildInvite {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.contentCardFill(isUnread: showAsUnread, isPressed: isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                semanticBorderColor,
                                lineWidth: showsSemanticBorder ? 1 : 0
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                (showAsUnread && !showsSemanticBorder) ? AppColors.accentColor.opacity(0.4) : Color.clear,
                                lineWidth: (showAsUnread && !showsSemanticBorder) ? 1 : 0
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .disabled(notificationNavigationManager.isNavigating)
        .opacity(notificationNavigationManager.isNavigating ? 0.6 : 1.0)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            recordNotificationView()
        }
        .onChange(of: notification.isRead) { _, isRead in
            withAnimation(.easeInOut(duration: 0.2)) {
                showAsUnread = !isRead
            }
        }
        .onDisappear {
            markAsReadIfNeeded()
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        HapticFeedback.light.trigger()
        
        // Mark as read immediately on tap
        if showAsUnread {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAsUnread = false
            }
            leftDrawerViewModel.markNotificationAsRead(
                notificationId: notification.id,
                rlAppState: rlAppState                       // <<< Pass rlAppState
            )
        }
        
        if notification.isActionable {
            Task {
                await notificationNavigationManager.navigate(to: notification)
            }
        }
    }
    
    private func recordNotificationView() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await rlAppState.recordNotificationView(       // <<< Use rlAppState
                    notificationId: notification.id
                )
            } catch {
                print("⚠️ Failed to record notification view: \(error)")
            }
        }
    }
    
    private func markAsReadIfNeeded() {
        if showAsUnread {
            withAnimation {
                showAsUnread = false
            }
            leftDrawerViewModel.markNotificationAsRead(
                notificationId: notification.id,
                rlAppState: rlAppState
            )
        }
    }

    // MARK: - Guild Invite Actions

    private func acceptInvite() {
        guard let guildId = notification.guildId,
              let inviteId = notification.inviteId else { return }

        isProcessingInvite = true
        HapticFeedback.light.trigger()

        Task {
            do {
                _ = try await rlAppState.acceptGuildInvite(guildId: guildId, inviteId: inviteId)
                withAnimation {
                    inviteActionTaken = true
                    showAsUnread = false
                }
                leftDrawerViewModel.markNotificationAsRead(
                    notificationId: notification.id,
                    rlAppState: rlAppState
                )
                // Refresh guild list so the new guild appears
                try await rlAppState.fetchUserGuilds()
            } catch {
                // Error shown by appState
            }
            isProcessingInvite = false
        }
    }

    private func declineInvite() {
        guard let guildId = notification.guildId,
              let inviteId = notification.inviteId else { return }

        isProcessingInvite = true
        HapticFeedback.light.trigger()

        Task {
            do {
                try await rlAppState.declineGuildInvite(guildId: guildId, inviteId: inviteId)
                withAnimation {
                    inviteActionTaken = true
                    showAsUnread = false
                }
                leftDrawerViewModel.markNotificationAsRead(
                    notificationId: notification.id,
                    rlAppState: rlAppState
                )
            } catch {
                // Error shown by appState
            }
            isProcessingInvite = false
        }
    }

    // MARK: - Friend Request Actions

    private func acceptFriendRequest(request: RLFriendRequestIncomingDTO) async {
        isProcessingFriendRequest = true
        HapticFeedback.light.trigger()

        do {
            _ = try await rlAppState.acceptFriendRequest(requestId: request.id)
            withAnimation {
                friendRequestActionTaken = true
                showAsUnread = false
            }
            leftDrawerViewModel.updateGuildMember(membershipId: request.fromMembershipId) { member in
                member.updating(isFriend: true, friendshipStatus: "accepted")
            }
            leftDrawerViewModel.markNotificationAsRead(
                notificationId: notification.id,
                rlAppState: rlAppState
            )
            await leftDrawerViewModel.refreshFriendRelationshipCaches(
                guildId: rlAppState.currentGuild?.id,
                rlAppState: rlAppState
            )
        } catch {
            // Error shown by appState
        }
        isProcessingFriendRequest = false
    }

    private func declineFriendRequest(request: RLFriendRequestIncomingDTO) async {
        isProcessingFriendRequest = true
        HapticFeedback.light.trigger()

        do {
            _ = try await rlAppState.declineFriendRequest(requestId: request.id)
            withAnimation {
                friendRequestActionTaken = true
                showAsUnread = false
            }
            leftDrawerViewModel.updateGuildMember(membershipId: request.fromMembershipId) { member in
                member.updating(isFriend: false, friendshipStatus: nil)
            }
            leftDrawerViewModel.markNotificationAsRead(
                notificationId: notification.id,
                rlAppState: rlAppState
            )
            await leftDrawerViewModel.refreshFriendRelationshipCaches(
                guildId: rlAppState.currentGuild?.id,
                rlAppState: rlAppState
            )
        } catch {
            // Error shown by appState
        }
        isProcessingFriendRequest = false
    }
}
// struct NotificationCard: View {
//     let notification: RLNotificationDTO
    
//     @State private var isPressed = false
//     @State private var hasRecordedView = false
//     @State private var showAsUnread: Bool
    
//     @EnvironmentObject var appState: AppState
//     @EnvironmentObject var rlAppState: RLAppState 
//     @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
//     @EnvironmentObject var notificationNavigationManager: NotificationNavigationManager
    
//     init(notification: RLNotificationDTO) {
//         self.notification = notification
//         _showAsUnread = State(initialValue: !notification.isRead)
//     }
    
//     /// Icon and color based on notification type
//     private var notificationIcon: String {
//         switch notification.notificationType {
//         case .personal:
//             return "person.crop.circle.fill"
//         case .symbol:
//             return "chart.line.uptrend.xyaxis"
//         }
//     }
    
//     private var notificationColor: Color {
//         switch notification.notificationType {
//         case .personal:
//             return AppColors.friendAccent
//         case .symbol:
//             return AppColors.bullCandleGreen
//         }
//     }
    
//     var body: some View {
//         Button(action: handleTap) {
//             HStack(alignment: .top, spacing: 10) {
//                 // Icon badge
//                 ZStack {
//                     Circle()
//                         .fill(notificationColor.opacity(0.2))
//                         .frame(width: 36, height: 36)
                    
//                     Image(systemName: notificationIcon)
//                         .font(.system(size: 14, weight: .semibold))
//                         .foregroundColor(notificationColor)
//                 }
                
//                 // Content
//                 VStack(alignment: .leading, spacing: 4) {
//                     // Title row with time
//                     HStack(alignment: .top) {
//                         Text(notification.title)
//                             .font(.system(size: 13, weight: .semibold))
//                             .foregroundColor(AppColors.whiteText)
//                             .lineLimit(2)
//                             .multilineTextAlignment(.leading)
                        
//                         Spacer()
                        
//                         Text(notification.timeAgoFormatted)
//                             .font(.system(size: 10))
//                             .foregroundColor(AppColors.whiteText.opacity(0.4))
//                     }
                    
//                     // Content preview
//                     Text(notification.content)
//                         .font(.system(size: 12))
//                         .foregroundColor(AppColors.whiteText.opacity(0.6))
//                         .lineLimit(2)
//                         .multilineTextAlignment(.leading)
//                 }
                
//                 // Chevron for navigable notifications
//                 if notification.destination != nil {
//                     Image(systemName: "chevron.right")
//                         .font(.system(size: 10, weight: .semibold))
//                         .foregroundColor(AppColors.whiteText.opacity(0.3))
//                         .padding(.top, 4)
//                 }
//             }
//             .padding(.horizontal, 12)
//             .padding(.vertical, 10)
//             .background(
//                 RoundedRectangle(cornerRadius: 12)
//                     .fill(AppColors.systemWhite.opacity(isPressed ? 0.08 : 0.04))
//                     .overlay(
//                         RoundedRectangle(cornerRadius: 12)
//                             .strokeBorder(
//                                 showAsUnread ? AppColors.accentColor.opacity(0.4) : Color.clear,
//                                 lineWidth: 1
//                             )
//                     )
//             )
//         }
//         .buttonStyle(PlainButtonStyle())
//         .scaleEffect(isPressed ? 0.98 : 1.0)
//         .animation(.easeInOut(duration: 0.15), value: isPressed)
//         .disabled(notificationNavigationManager.isNavigating)
//         .opacity(notificationNavigationManager.isNavigating ? 0.6 : 1.0)
//         .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
//             withAnimation(.easeInOut(duration: 0.1)) {
//                 isPressed = pressing
//             }
//         }, perform: {})
//         .onAppear {
//             recordNotificationView()
//         }
//         .onDisappear {
//             markAsReadIfNeeded()
//         }
//     }
    
//     // MARK: - Actions
    
//     private func handleTap() {
//         HapticFeedback.light.trigger()
        
//         // Mark as read immediately on tap
//         if showAsUnread {
//             withAnimation(.easeInOut(duration: 0.2)) {
//                 showAsUnread = false
//             }
//             leftDrawerViewModel.markNotificationAsRead(notificationId: notification.id)
//         }
        
//         // Navigate to destination
//         Task {
//             await notificationNavigationManager.navigate(to: notification)
//         }
//     }
    
//     private func recordNotificationView() {
//         guard !hasRecordedView else { return }
//         hasRecordedView = true
        
//         Task {
//             do {
//                 try await appState.recordNotificationView(notificationId: notification.id)
//             } catch {
//                 print("⚠️ Failed to record notification view: \(error)")
//             }
//         }
//     }
    
//     private func markAsReadIfNeeded() {
//         if showAsUnread {
//             withAnimation {
//                 showAsUnread = false
//             }
//             leftDrawerViewModel.markNotificationAsRead(notificationId: notification.id)
//         }
//     }
// }

// MARK: - ================================================================================================
// MARK: - NAVIGATION LOADING OVERLAY
// MARK: - ================================================================================================

struct NavigationLoadingOverlay: View {
    var body: some View {
        ZStack {
            AppColors.surfaceBlack30
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.primaryForeground)
                Text("Opening...")
                    .font(.subheadline)
                    .foregroundColor(AppColors.primaryForeground)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surfaceBlack80)
            )
        }
    }
}
