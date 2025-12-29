//
//  RightDrawerViewModel.swift
//  traders_guild
//
//  Created by Al Hennessey on 29/10/2025.
//

//
//  LeftDrawerViewModel.swift
//  traders_guild
//
//  Created by Al Hennessey on 27/10/2025.
//

//
//  DrawerViewModel.swift
//  traders_guild
//
//  Created by Al Hennessey on 27/10/2025.
//

import Foundation
import SwiftUI

@MainActor
class RightDrawerViewModel: ObservableObject {
    
    // ================================================================================================
    // MARK: - Published State
    // ================================================================================================
    
    @Published var guildChatrooms: [GuildChatroomDTO] = []
    @Published var guildFriends: [DMDTO] = []
    @Published var guildOnlineNonFriends: [DMDTO] = []
    @Published var guildOfflineNonFriends: [DMDTO] = []
    
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    
    private var currentGuildId: UUID?
    
    // ================================================================================================
    // MARK: - Cache Update Methods
    // ================================================================================================
    
    /// Update DM unread count in cache
    func updateDMUnreadCount(dmId: UUID, unreadCount: Int) {
        // Check friends array
        if let index = guildFriends.firstIndex(where: { $0.id == dmId }) {
            var updatedDM = guildFriends[index]
            updatedDM.unreadCount = unreadCount
            guildFriends[index] = updatedDM
            print("✅ Updated friend DM cache: \(dmId) -> unreadCount: \(unreadCount)")
            return
        }
        
        // Check online non-friends array
        if let index = guildOnlineNonFriends.firstIndex(where: { $0.id == dmId }) {
            var updatedDM = guildOnlineNonFriends[index]
            updatedDM.unreadCount = unreadCount
            guildOnlineNonFriends[index] = updatedDM
            print("✅ Updated online non-friend DM cache: \(dmId) -> unreadCount: \(unreadCount)")
            return
        }
        
        // Check offline non-friends array
        if let index = guildOfflineNonFriends.firstIndex(where: { $0.id == dmId }) {
            var updatedDM = guildOfflineNonFriends[index]
            updatedDM.unreadCount = unreadCount
            guildOfflineNonFriends[index] = updatedDM
            print("✅ Updated offline non-friend DM cache: \(dmId) -> unreadCount: \(unreadCount)")
            return
        }
        
        print("⚠️ DM not found in cache: \(dmId)")
    }
    
    /// Mark DM as read in cache (convenience method)
    func markDMAsRead(dmId: UUID) {
        updateDMUnreadCount(dmId: dmId, unreadCount: 0)
    }
    
    /// Update chatroom unread count in cache
    func updateChatroomUnreadCount(chatroomId: UUID, unreadCount: Int) {
        guard let index = guildChatrooms.firstIndex(where: { $0.id == chatroomId }) else {
            print("⚠️ Chatroom not found in cache: \(chatroomId)")
            return
        }
        
        var updatedChatroom = guildChatrooms[index]
        updatedChatroom.unreadCount = unreadCount
        guildChatrooms[index] = updatedChatroom
        print("✅ Updated chatroom cache: \(chatroomId) -> unreadCount: \(unreadCount)")
    }
    
    /// Mark chatroom as read in cache (convenience method)
    func markChatroomAsRead(chatroomId: UUID) {
        updateChatroomUnreadCount(chatroomId: chatroomId, unreadCount: 0)
    }
    
    // ================================================================================================
    // MARK: - Preload Data
    // ================================================================================================
    
    /// Preload all drawer data in parallel
    func preloadData(for guildId: UUID, appState: AppState) async {
        guard shouldRefresh(for: guildId) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        async let guildChatroomsTask = appState.fetchGuildChatrooms(guildId: guildId)
        async let guildFriendsTask = appState.fetchGuildFriendDM(guildId: guildId)
        async let guildOnlineNonFriendTask = appState.fetchGuildOnlineNonFriendDM(guildId: guildId)
        async let guildOfflineNonFriendTask = appState.fetchGuildOfflineNonFriendDM(guildId: guildId)
        
        do {
            let (fetchedGuildChatrooms, fetchedGuildFriendDM, fetchedGuildOnlineNonFriendDM, fetchedGuildOfflineNonFriendDM) = try await (
                guildChatroomsTask,
                guildFriendsTask,
                guildOnlineNonFriendTask,
                guildOfflineNonFriendTask
            )
            
            self.guildChatrooms = fetchedGuildChatrooms
            self.guildFriends = fetchedGuildFriendDM
            self.guildOnlineNonFriends = fetchedGuildOnlineNonFriendDM
            self.guildOfflineNonFriends = fetchedGuildOfflineNonFriendDM
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
        } catch is CancellationError {
            return
        } catch {
            print("⚠️ Failed to preload drawer data: \(error)")
            appState.showError(error, title: "Failed to load data", style: .toast)
        }
    }
    
    /// Manual refresh - forces reload
    func refresh(for guildId: UUID, appState: AppState) async {
        lastRefresh = nil
        await preloadData(for: guildId, appState: appState)
    }
    
    /// Clear all cached data
    func clearCache() {
        guildChatrooms = []
        guildFriends = []
        guildOnlineNonFriends = []
        guildOfflineNonFriends = []
        lastRefresh = nil
        currentGuildId = nil
    }
    
    // ================================================================================================
    // MARK: - Cache Logic
    // ================================================================================================
    
    /// Check if data should be refreshed
    private func shouldRefresh(for guildId: UUID) -> Bool {
        // Always refresh if guild changed
        if currentGuildId != guildId {
            return true
        }
        
        // Refresh if cache is empty
        if guildChatrooms.isEmpty && guildFriends.isEmpty && guildOnlineNonFriends.isEmpty && guildOfflineNonFriends.isEmpty {
            return true
        }
        
        // Refresh if data is stale (5 minutes old)
        guard let lastRefresh = lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300
    }
}
