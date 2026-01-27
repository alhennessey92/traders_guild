//
//  RLRightDrawerViewModel.swift
//  traders_guild
//
//  UPDATED: Uses RLAppState and new RL messaging DTOs.
//  Replaces old RightDrawerViewModel that used AppState.
//

import Foundation
import SwiftUI

@MainActor
class RLRightDrawerViewModel: ObservableObject {
    
    // ================================================================================================
    // MARK: - Published State
    // ================================================================================================
    
    @Published var guildChatrooms: [RLGuildChatroomDTO] = []
    @Published var guildFriends: [RLDMThreadDTO] = []
    @Published var guildOnlineNonFriends: [RLDMThreadDTO] = []
    @Published var guildOfflineNonFriends: [RLDMThreadDTO] = []
    @Published var guildMembers: [RLGuildMemberDTO] = []
    
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    
    private var currentGuildId: UUID?
    
    // ================================================================================================
    // MARK: - Computed Properties
    // ================================================================================================
    
    /// Total unread count across all messaging
    var totalUnreadCount: Int {
        let chatroomUnread = guildChatrooms.reduce(0) { $0 + $1.unreadCount }
        let friendsUnread = guildFriends.reduce(0) { $0 + $1.unreadCount }
        let onlineUnread = guildOnlineNonFriends.reduce(0) { $0 + $1.unreadCount }
        let offlineUnread = guildOfflineNonFriends.reduce(0) { $0 + $1.unreadCount }
        return chatroomUnread + friendsUnread + onlineUnread + offlineUnread
    }
    
    /// Whether any chatrooms have unread messages
    var hasChatroomUnread: Bool {
        guildChatrooms.contains { $0.hasUnread }
    }
    
    /// Whether any DMs have unread messages
    var hasDMUnread: Bool {
        guildFriends.contains { $0.hasUnread } ||
        guildOnlineNonFriends.contains { $0.hasUnread } ||
        guildOfflineNonFriends.contains { $0.hasUnread }
    }

    /// Whether any DM threads exist (for fallback to member list)
    var hasAnyDMThreads: Bool {
        !guildFriends.isEmpty ||
        !guildOnlineNonFriends.isEmpty ||
        !guildOfflineNonFriends.isEmpty
    }

    /// Member-based friend list (fallback when no threads yet)
    var memberFriends: [RLGuildMemberDTO] {
        guildMembers.filter { $0.isFriend }
    }

    /// Member-based online list (fallback when no threads yet)
    var memberOnlineNonFriends: [RLGuildMemberDTO] {
        guildMembers.filter { !$0.isFriend && $0.isOnline }
    }

    /// Member-based offline list (fallback when no threads yet)
    var memberOfflineNonFriends: [RLGuildMemberDTO] {
        guildMembers.filter { !$0.isFriend && !$0.isOnline }
    }
    
    // ================================================================================================
    // MARK: - Cache Update Methods
    // ================================================================================================
    
    /// Update DM unread count in cache
    func updateDMUnreadCount(threadId: UUID, unreadCount: Int) {
        // Check friends array
        if let index = guildFriends.firstIndex(where: { $0.id == threadId }) {
            guildFriends[index] = guildFriends[index].withUnreadCount(unreadCount)
            print("✅ Updated friend DM cache: \(threadId) -> unreadCount: \(unreadCount)")
            return
        }
        
        // Check online non-friends array
        if let index = guildOnlineNonFriends.firstIndex(where: { $0.id == threadId }) {
            guildOnlineNonFriends[index] = guildOnlineNonFriends[index].withUnreadCount(unreadCount)
            print("✅ Updated online non-friend DM cache: \(threadId) -> unreadCount: \(unreadCount)")
            return
        }
        
        // Check offline non-friends array
        if let index = guildOfflineNonFriends.firstIndex(where: { $0.id == threadId }) {
            guildOfflineNonFriends[index] = guildOfflineNonFriends[index].withUnreadCount(unreadCount)
            print("✅ Updated offline non-friend DM cache: \(threadId) -> unreadCount: \(unreadCount)")
            return
        }
        
        print("⚠️ DM thread not found in cache: \(threadId)")
    }
    
    /// Mark DM as read in cache (convenience method)
    func markDMAsRead(threadId: UUID) {
        updateDMUnreadCount(threadId: threadId, unreadCount: 0)
    }
    
    /// Update chatroom unread count in cache
    func updateChatroomUnreadCount(chatroomId: UUID, unreadCount: Int) {
        guard let index = guildChatrooms.firstIndex(where: { $0.id == chatroomId }) else {
            print("⚠️ Chatroom not found in cache: \(chatroomId)")
            return
        }
        
        guildChatrooms[index] = guildChatrooms[index].withUnreadCount(unreadCount)
        print("✅ Updated chatroom cache: \(chatroomId) -> unreadCount: \(unreadCount)")
    }
    
    /// Mark chatroom as read in cache (convenience method)
    func markChatroomAsRead(chatroomId: UUID) {
        updateChatroomUnreadCount(chatroomId: chatroomId, unreadCount: 0)
    }
    
    // ================================================================================================
    // MARK: - Preload Data
    // ================================================================================================
    
    /// Preload all drawer data using combined endpoint (single request)
    func preloadData(for guildId: UUID, appState: RLAppState) async {
        guard shouldRefresh(for: guildId) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Use combined endpoint for efficiency
            let data = try await appState.fetchGuildMessagingData(guildId: guildId)
            
            self.guildChatrooms = data.chatrooms
            self.guildFriends = data.friendDms
            self.guildOnlineNonFriends = data.onlineDms
            self.guildOfflineNonFriends = data.offlineDms
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
            print("✅ Loaded drawer data: \(data.chatrooms.count) chatrooms, \(data.friendDms.count) friends, \(data.onlineDms.count) online, \(data.offlineDms.count) offline")
            // Fallback if combined endpoint returns empty
            if data.chatrooms.isEmpty && data.friendDms.isEmpty &&
                data.onlineDms.isEmpty && data.offlineDms.isEmpty {
                print("⚠️ Combined messaging data empty - falling back to separate fetches")
                await preloadDataSeparate(for: guildId, appState: appState)
            }

            if guildMembers.isEmpty {
                await preloadMembersFallback(for: guildId, appState: appState)
            }
        } catch is CancellationError {
            return
        } catch {
            print("⚠️ Failed to preload drawer data: \(error)")
            // Error already shown by RLAppState
            await preloadDataSeparate(for: guildId, appState: appState)
        }
    }
    
    /// Preload data using separate endpoints (fallback/legacy)
    func preloadDataSeparate(for guildId: UUID, appState: RLAppState) async {
        guard shouldRefresh(for: guildId) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        async let chatroomsTask = appState.fetchGuildChatrooms(guildId: guildId)
        async let threadsTask = appState.fetchDMThreads(guildId: guildId)
        
        do {
            let (chatrooms, threads) = try await (chatroomsTask, threadsTask)
            
            self.guildChatrooms = chatrooms
            
            // Categorize DM threads
            self.guildFriends = threads.filter { $0.participant.isFriend }
            self.guildOnlineNonFriends = threads.filter { !$0.participant.isFriend && $0.participant.isOnline }
            self.guildOfflineNonFriends = threads.filter { !$0.participant.isFriend && !$0.participant.isOnline }
            
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
            if guildMembers.isEmpty {
                await preloadMembersFallback(for: guildId, appState: appState)
            }
            
        } catch is CancellationError {
            return
        } catch {
            print("⚠️ Failed to preload drawer data: \(error)")
        }
    }
    
    /// Manual refresh - forces reload
    func refresh(for guildId: UUID, appState: RLAppState) async {
        lastRefresh = nil
        await preloadData(for: guildId, appState: appState)
    }
    
    /// Clear all cached data
    func clearCache() {
        guildChatrooms = []
        guildFriends = []
        guildOnlineNonFriends = []
        guildOfflineNonFriends = []
        guildMembers = []
        lastRefresh = nil
        currentGuildId = nil
    }

    /// Fallback: load member list for right drawer when no threads exist yet
    private func preloadMembersFallback(for guildId: UUID, appState: RLAppState) async {
        do {
            let response = try await appState.fetchGuildMembers(guildId: guildId, limit: 200)
            guildMembers = response.members.filter { $0.userId != appState.currentUser?.id }
        } catch {
            print("⚠️ Failed to load member fallback list: \(error)")
        }
    }

    /// Find an existing DM thread for a member (if any)
    func findDMThread(for userId: UUID) -> RLDMThreadDTO? {
        if let thread = guildFriends.first(where: { $0.participant.userId == userId }) {
            return thread
        }
        if let thread = guildOnlineNonFriends.first(where: { $0.participant.userId == userId }) {
            return thread
        }
        if let thread = guildOfflineNonFriends.first(where: { $0.participant.userId == userId }) {
            return thread
        }
        return nil
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
    // MARK: - Find Methods
    // ================================================================================================
    
    /// Find a DM thread by ID across all categories
    func findDMThread(id: UUID) -> RLDMThreadDTO? {
        if let thread = guildFriends.first(where: { $0.id == id }) { return thread }
        if let thread = guildOnlineNonFriends.first(where: { $0.id == id }) { return thread }
        if let thread = guildOfflineNonFriends.first(where: { $0.id == id }) { return thread }
        return nil
    }
    
    /// Find a chatroom by ID
    func findChatroom(id: UUID) -> RLGuildChatroomDTO? {
        return guildChatrooms.first(where: { $0.id == id })
    }
}

// ================================================================================================
// MARK: - DTO Extensions for Cache Updates
// ================================================================================================
// These extensions provide methods to create copies with updated values
// without conflicting with the auto-generated memberwise initializers.

extension RLDMThreadDTO {
    /// Create a copy with updated unread count
    func withUnreadCount(_ count: Int) -> RLDMThreadDTO {
        // Use JSONEncoder/Decoder to create a mutable copy
        // This is a workaround for structs with all `let` properties
        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self)
        ) as? [String: Any] else {
            return self
        }
        dict["unreadCount"] = count
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLDMThreadDTO.self, from: data) else {
            return self
        }
        return updated
    }
}

extension RLGuildChatroomDTO {
    /// Create a copy with updated unread count
    func withUnreadCount(_ count: Int) -> RLGuildChatroomDTO {
        // Use JSONEncoder/Decoder to create a mutable copy
        guard var dict = try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self)
        ) as? [String: Any] else {
            return self
        }
        dict["unreadCount"] = count
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLGuildChatroomDTO.self, from: data) else {
            return self
        }
        return updated
    }
}
