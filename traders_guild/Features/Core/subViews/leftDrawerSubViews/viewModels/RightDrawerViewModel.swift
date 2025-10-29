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
        }
    }
    
    /// Manual refresh - forces reload
    func refresh(for guildId: UUID, appState: AppState) async {
        lastRefresh = nil
        await preloadData(for: guildId, appState: appState)
    }
    
    /// Clear all cached data
    func clearCache() {
        
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
    
    // ================================================================================================
    // MARK: - Computed Properties
    // ================================================================================================
    
    
}
