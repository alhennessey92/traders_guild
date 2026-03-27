//
//  NotificationNavigationManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 03/11/2025.
//
import SwiftUI

enum NotificationDrawerRoute: Equatable, Identifiable {
    case announcement(announcementId: UUID)
    case event(eventId: UUID)
    case currentUserProfile
    case guildMemberProfile(userId: UUID)
    case adminReports(guildId: UUID?, reportId: UUID?)

    var id: String {
        switch self {
        case .announcement(let announcementId):
            return "announcement-\(announcementId.uuidString)"
        case .event(let eventId):
            return "event-\(eventId.uuidString)"
        case .currentUserProfile:
            return "current-user-profile"
        case .guildMemberProfile(let userId):
            return "guild-member-\(userId.uuidString)"
        case .adminReports(let guildId, let reportId):
            return "admin-reports-\(guildId?.uuidString ?? "none")-\(reportId?.uuidString ?? "none")"
        }
    }
}


@MainActor
class NotificationNavigationManager: ObservableObject {
    /// Loading state while navigating
    @Published var isNavigating: Bool = false
    
    // Dependencies
    private weak var rlAppState: RLAppState?
    private weak var messagingManager: RLMessagingManager?
    private weak var rightDrawerViewModel: RLRightDrawerViewModel?
    private var dismissOverlays: (() -> Void)?
    private var presentLeftDrawerRoute: ((NotificationDrawerRoute) -> Void)?
    
    // ============================================================================
    // Initialization
    // ============================================================================
    
    init(rlAppState: RLAppState? = nil,
         messagingManager: RLMessagingManager? = nil,
         rightDrawerViewModel: RLRightDrawerViewModel? = nil,
         dismissOverlays: (() -> Void)? = nil,
         presentLeftDrawerRoute: ((NotificationDrawerRoute) -> Void)? = nil) {
        self.rlAppState = rlAppState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
        self.dismissOverlays = dismissOverlays
        self.presentLeftDrawerRoute = presentLeftDrawerRoute
    }
    
    /// Configure manager with required dependencies
    func configure(
        rlAppState: RLAppState,
        messagingManager: RLMessagingManager,
        rightDrawerViewModel: RLRightDrawerViewModel,
        dismissOverlays: @escaping () -> Void,
        presentLeftDrawerRoute: @escaping (NotificationDrawerRoute) -> Void
    ) {
        self.rlAppState = rlAppState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
        self.dismissOverlays = dismissOverlays
        self.presentLeftDrawerRoute = presentLeftDrawerRoute
    }
    
    // ============================================================================
    // Navigation Methods
    // ============================================================================
    
    /// Main entry point: Handle navigation for a notification
    func navigate(to notification: RLNotificationDTO) async {
        if notification.destination?.type == .symbolChart {
            if let payload = notification.markerNavigationPayload {
                dismissOverlays?()
                NotificationCenter.default.post(
                    name: .openSharedMarker,
                    object: nil,
                    userInfo: payload.notificationUserInfo
                )
                return
            }

            print("⚠️ Marker notification '\(notification.displayTitle)' is missing chart context")
            rlAppState?.showInfo("This chart notification is missing marker context")
            return
        }

        guard let destination = notification.navigationDestination else {
            print("⚠️ Notification '\(notification.displayTitle)' has no valid destination")
            rlAppState?.showInfo("This notification cannot be opened")
            return
        }
        await navigate(to: destination)
    }
    
    /// Navigate to a specific destination
    func navigate(to destination: NotificationDestination) async {
        guard let rlAppState = rlAppState,
              let messagingManager = messagingManager else {
            print("⚠️ NotificationNavigationManager not properly configured")
            return
        }
        
        isNavigating = true
        defer { isNavigating = false }
        
        do {
            switch destination {
            // ============================================================================
            // CASE 1: Navigate to User DM
            // ============================================================================
            case .userDM(let userId):
                dismissOverlays?()
                if let thread = rightDrawerViewModel?.findDMThread(for: userId) {
                    messagingManager.openDMThread(thread)
                    return
                }
                
                guard let guildId = rlAppState.currentGuild?.id else {
                    rlAppState.showInfo("Guild not ready")
                    return
                }
                
                let member = try await rlAppState.fetchGuildMember(guildId: guildId, userId: userId)
                await messagingManager.openDMChat(with: member)
                
            // ============================================================================
            // CASE 2: Navigate to Chatroom
            // ============================================================================
            case .chatroom(let chatroomId):
                dismissOverlays?()
                if let cached = rightDrawerViewModel?.findChatroom(id: chatroomId) {
                    messagingManager.openChatroom(cached)
                    return
                }
                
                let chatroom = try await rlAppState.fetchChatroom(chatroomId: chatroomId)
                messagingManager.openChatroom(chatroom)
                
            // ============================================================================
            // CASE 3: Navigate to Symbol Chart
            // ============================================================================
            case .symbolChart(let symbolId, let ticker):
                print("🔔 Navigate to chart for \(ticker) (Symbol ID: \(symbolId))")
                rlAppState.showInfo("This chart notification is missing marker context")
                
            // ============================================================================
            // CASE 4: Navigate to User Profile
            // ============================================================================
            case .userProfile(let userId):
                if userId == rlAppState.currentUser?.id {
                    presentLeftDrawerRoute?(.currentUserProfile)
                } else {
                    presentLeftDrawerRoute?(.guildMemberProfile(userId: userId))
                }
                
            // ============================================================================
            // CASE 5: Navigate to Announcement
            // ============================================================================
            case .announcement(let announcementId):
                presentLeftDrawerRoute?(.announcement(announcementId: announcementId))

            case .event(let eventId):
                presentLeftDrawerRoute?(.event(eventId: eventId))

            case .adminReports(let guildId, let reportId):
                presentLeftDrawerRoute?(.adminReports(guildId: guildId, reportId: reportId))
            }
            
        } catch is CancellationError {
            return
        } catch {
            rlAppState.showError(error, title: "Navigation Failed", style: .toast)
        }
    }
    
}

