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
    private weak var appState: AppState?
    private weak var messagingManager: MessagingManager?
    private weak var rightDrawerViewModel: RightDrawerViewModel?  // ✅ NEW: Cache access
    
    // ============================================================================
    // Initialization
    // ============================================================================
    
    init(appState: AppState? = nil,
         messagingManager: MessagingManager? = nil,
         rightDrawerViewModel: RightDrawerViewModel? = nil) {
        self.appState = appState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
    }
    
    /// Configure manager with required dependencies
    func configure(appState: AppState,
                   messagingManager: MessagingManager,
                   rightDrawerViewModel: RightDrawerViewModel) {  // ✅ NEW: Add cache parameter
        self.appState = appState
        self.messagingManager = messagingManager
        self.rightDrawerViewModel = rightDrawerViewModel
    }
    
    // ============================================================================
    // Navigation Methods
    // ============================================================================
    
    /// Main entry point: Handle navigation for a notification
    func navigate(to notification: GuildNotificationDTO) async {
        guard let destination = notification.destination else {
            print("⚠️ Notification '\(notification.title)' has no valid destination")
            appState?.showInfo("This notification cannot be opened")
            return
        }
        
        await navigate(to: destination)
    }
    
    /// Navigate to a specific destination
    func navigate(to destination: NotificationDestination) async {
        guard let appState = appState,
              let messagingManager = messagingManager else {
            print("⚠️ NotificationNavigationManager not properly configured")
            return
        }
        
        isNavigating = true
        defer { isNavigating = false }
        
        do {
            switch destination {
            // ============================================================================
            // CASE 1: Navigate to User DM (Cache-Optimized)
            // ============================================================================
            case .userDM(let userId):
                // ✅ NEW: Check cache first
                if let cachedDM = findDMInCache(userId: userId) {
                    print("✅ Found DM in cache for user \(userId)")
                    messagingManager.openUserDM(cachedDM)
                    return
                }
                
                // Cache miss - fetch from API
                print("⚠️ DM not in cache, fetching from API for user \(userId)")
                let userDM = try await appState.fetchOrCreateUserDM(userId: userId)
                messagingManager.openUserDM(userDM)
                
            // ============================================================================
            // CASE 2: Navigate to Chatroom (Cache-Optimized)
            // ============================================================================
            case .chatroom(let chatroomId):
                // ✅ NEW: Check cache first
                if let cachedChatroom = findChatroomInCache(chatroomId: chatroomId) {
                    print("✅ Found chatroom in cache: \(chatroomId)")
                    messagingManager.openChatroom(cachedChatroom)
                    return
                }
                
                // Cache miss - try appState.currentGuild (fallback)
                print("⚠️ Chatroom not in cache, checking currentGuild for \(chatroomId)")
                let chatroom = try await appState.fetchChatroomById(chatroomId: chatroomId)
                
                messagingManager.openChatroom(chatroom)
                
            // ============================================================================
            // CASE 3: Navigate to Symbol Chart
            // ============================================================================
            case .symbolChart(let symbolId, let ticker):
                print("🔔 Navigate to chart for \(ticker) (Symbol ID: \(symbolId))")
                appState.showInfo("Chart navigation coming soon for \(ticker)")
                
                // TODO: When ready
                // chartNavigationManager.openChart(symbolId: symbolId, ticker: ticker)
                
            // ============================================================================
            // CASE 4: Navigate to User Profile
            // ============================================================================
            case .userProfile(let userId):
                print("🔔 Navigate to user profile (ID: \(userId))")
                appState.showInfo("Profile navigation coming soon")
                
            // ============================================================================
            // CASE 5: Navigate to Announcement
            // ============================================================================
            case .announcement(let announcementId):
                print("🔔 Navigate to announcement (ID: \(announcementId))")
                appState.showInfo("Announcement details coming soon")
            }
            
        } catch is CancellationError {
            return
        } catch {
            appState.showError(error, title: "Navigation Failed", style: .toast)
        }
    }
    
    // ============================================================================
    // Cache Lookup Methods
    // ============================================================================
    
    /// Find DM in cache by user ID
    /// Searches friends, online non-friends, and offline non-friends
    private func findDMInCache(userId: UUID) -> DMDTO? {
        guard let cache = rightDrawerViewModel else { return nil }
        
        // Check friends
        if let dm = cache.guildFriends.first(where: { $0.participant.id == userId }) {
            return dm
        }
        
        // Check online non-friends
        if let dm = cache.guildOnlineNonFriends.first(where: { $0.participant.id == userId }) {
            return dm
        }
        
        // Check offline non-friends
        if let dm = cache.guildOfflineNonFriends.first(where: { $0.participant.id == userId }) {
            return dm
        }
        
        return nil
    }
    
    /// Find chatroom in cache by chatroom ID
    private func findChatroomInCache(chatroomId: UUID) -> GuildChatroomDTO? {
        guard let cache = rightDrawerViewModel else { return nil }
        
        return cache.guildChatrooms.first(where: { $0.id == chatroomId })
    }
}




