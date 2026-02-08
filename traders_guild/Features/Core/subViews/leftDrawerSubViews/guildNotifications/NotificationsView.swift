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
    }
    
    // MARK: - Refresh
    private func refreshNotifications() async {
        await leftDrawerViewModel.refreshNotifications(rlAppState: rlAppState)
    }
    
    // MARK: - Tab Counts
    
    private func getCountForTab(_ tab: NotificationTab) -> Int {
        filteredNotifications(for: tab).count
    }
    
    // MARK: - Filtered Notifications
    
    private func filteredNotifications(for tab: NotificationTab) -> [RLNotificationDTO] {
        switch tab {
        case .all:
            return leftDrawerViewModel.userNotifications
        case .guild:
            // Guild tab: announcements, events, guild invites
            return leftDrawerViewModel.userNotifications.filter { $0.type?.isGuild == true }
        case .personal:
            // Personal tab: DMs, chatroom mentions, friend requests, mentions
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
    
    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .top, spacing: 10) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(notificationColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: notificationIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(notificationColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(notification.displayTitle)          // <<< .title -> .displayTitle
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.whiteText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Text(notification.timeAgoFormatted)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.whiteText.opacity(0.4))
                    }
                    
                    Text(notification.displayBody)               // <<< .content -> .displayBody
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Chevron for navigable notifications
                if notification.isActionable {                   // <<< .destination != nil -> .isActionable
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
                    .fill(Color.white.opacity(isPressed ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                showAsUnread ? AppColors.accentColor.opacity(0.4) : Color.clear,
                                lineWidth: 1
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
        
        // Navigate using the new destination
        if let destination = notification.navigationDestination {
            Task {
                await notificationNavigationManager.navigate(to: destination)
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
//                     .fill(Color.white.opacity(isPressed ? 0.08 : 0.04))
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text("Opening...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}



