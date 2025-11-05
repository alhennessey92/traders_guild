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
    @EnvironmentObject var notificationNavigationManager: NotificationNavigationManager  // ✅ ADD THIS
    
    var body: some View {
        VStack(spacing: 10) {
            // Loading state
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
            // Empty state
            else if leftDrawerViewModel.userNotifications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
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
                // Notifications list
                ForEach(leftDrawerViewModel.userNotifications) { notification in
                    NotificationRowView(
                        notification: notification,
                        onTap: {
                            // Optional: Additional action on tap
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        // ✅ ADD THIS: Loading overlay
        .overlay {
            if notificationNavigationManager.isNavigating {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Opening...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                    )
                }
            }
        }
    }
}




// MARK: - Notification Row View

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: GuildNotificationDTO
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var hasRecordedView = false
    @State private var showAsUnread: Bool
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var leftDrawerViewModel: LeftDrawerViewModel
    @EnvironmentObject var notificationNavigationManager: NotificationNavigationManager
    
    init(notification: GuildNotificationDTO, onTap: @escaping () -> Void) {
        self.notification = notification
        self.onTap = onTap
        _showAsUnread = State(initialValue: !notification.isRead)
    }
    
    var body: some View {
        Button(action: {
            Task {
                await notificationNavigationManager.navigate(to: notification)
            }
            HapticFeedback.light.trigger()
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    switch notification.notificationType {
                    case .personal:
                        // Profile picture or default icon
                        Image(systemName: "person.2.shield")
                            .font(.title3)
                            .foregroundColor(AppColors.friendAccent)
                            .frame(width: 24)
                    case .symbol:
                        Image(systemName: "chart.line.uptrend.xyaxis.circle")
                            .font(.title3)
                            .foregroundColor(AppColors.bullCandleGreen)
                            .frame(width: 24)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {  // ✅ CHANGED: Reduced spacing from 6 to 4
                    // Title with unread indicator and time
                    HStack(alignment: .top, spacing: 6) {
//                        if showAsUnread {
//                            Circle()
//                                .fill(AppColors.accentDarkColor)
//                                .stroke(AppColors.accentColor, lineWidth: 2)
//                                .frame(width: 6, height: 6)
//                                .padding(.top, 6)
//                        }
                        
                        Text(notification.title)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.whiteText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Text(notification.timeAgoFormatted)
                            .font(.caption2)
                            .foregroundColor(AppColors.whiteText.opacity(0.5))
                    }
                    
                    // Content text
                    Text(notification.content)
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                
                
            }
            .padding(.horizontal, 14)  // ✅ CHANGED: More specific horizontal padding
            .padding(.vertical, 10)     // ✅ CHANGED: Reduced from 16 to 10 for thinner height
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.1 : showAsUnread ? 0.05 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(showAsUnread ? AppColors.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            if showAsUnread {
                withAnimation {
                    showAsUnread = false
                }
                leftDrawerViewModel.markNotificationAsRead(notificationId: notification.id)
            }
        }
    }
    
    private func recordNotificationView() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        
        Task {
            do {
                try await appState.recordNotificationView(notificationId: notification.id)
            } catch {
                print("⚠️ Failed to record notification view: \(error)")
            }
        }
    }
}
