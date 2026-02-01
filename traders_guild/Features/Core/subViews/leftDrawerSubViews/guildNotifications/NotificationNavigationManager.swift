//
//  NotificationNavigationManager.swift
//  traders_guild
//
//  Created by Al Hennessey on 03/11/2025.
//
import SwiftUI



@MainActor
class NotificationNavigationManager: ObservableObject {
    /// Loading state while navigating
    @Published var isNavigating: Bool = false
    
    // Dependencies
    private weak var rlAppState: RLAppState?
    private weak var messagingManager: RLMessagingManager?
    private weak var rightDrawerViewModel: RLRightDrawerViewModel?
    
    // ============================================================================
    // Initialization
    // ============================================================================
    
    init(rlAppState: RLAppState? = nil,
         messagingManager: RLMessagingManager? = nil,
         rightDrawerViewModel: RLRightDrawerViewModel? = nil) {
        self.rlAppState = rlAppState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
    }
    
    /// Configure manager with required dependencies
    func configure(
        rlAppState: RLAppState,
        messagingManager: RLMessagingManager,
        rightDrawerViewModel: RLRightDrawerViewModel
    ) {
        self.rlAppState = rlAppState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
    }
    
    // ============================================================================
    // Navigation Methods
    // ============================================================================
    
    /// Main entry point: Handle navigation for a notification
    func navigate(to notification: RLNotificationDTO) async {
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
                rlAppState.showInfo("Chart navigation coming soon for \(ticker)")
                
                // TODO: When ready
                // chartNavigationManager.openChart(symbolId: symbolId, ticker: ticker)
                
            // ============================================================================
            // CASE 4: Navigate to User Profile
            // ============================================================================
            case .userProfile(let userId):
                print("🔔 Navigate to user profile (ID: \(userId))")
                rlAppState.showInfo("Profile navigation coming soon")
                
            // ============================================================================
            // CASE 5: Navigate to Announcement
            // ============================================================================
            case .announcement(let announcementId):
                print("🔔 Navigate to announcement (ID: \(announcementId))")
                rlAppState.showInfo("Announcement details coming soon")
            }
            
        } catch is CancellationError {
            return
        } catch {
            rlAppState.showError(error, title: "Navigation Failed", style: .toast)
        }
    }
    
}




