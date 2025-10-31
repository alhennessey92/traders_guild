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
class LeftDrawerViewModel: ObservableObject {
    
    // ================================================================================================
    // MARK: - Published State
    // ================================================================================================
    
    @Published var announcements: [GuildAnnouncementDTO] = []
    @Published var upcomingEvents: [GuildEventDTO] = []
    @Published var members: [GuildMembershipDTO] = []
    @Published var watchlist: GuildWatchlistDTO?  // ✅ Single object, not array
    @Published var userNotifications: [GuildNotificationDTO] = []
    
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
        
        async let announcementsTask = appState.fetchGuildAnnouncements(guildId: guildId)
        async let eventsTask = appState.fetchGuildEvents(guildId: guildId)
        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)  // Returns single object
        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
        
        do {
            let (fetchedAnnouncements, fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedUserNotifications) = try await (
                announcementsTask,
                eventsTask,
                membersTask,
                watchlistTask,
                userNotificationsTask
            )
            
            self.announcements = fetchedAnnouncements
            self.upcomingEvents = fetchedEvents
            self.members = fetchedMembers
            self.watchlist = fetchedWatchlist  // ✅ Single assignment
            self.userNotifications = fetchedUserNotifications
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
        announcements = []
        upcomingEvents = []
        members = []
        watchlist = nil  // ✅ Set to nil instead of empty array
        userNotifications = []
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
        if announcements.isEmpty && upcomingEvents.isEmpty && members.isEmpty && watchlist == nil && userNotifications.isEmpty {
            return true
        }
        
        // Refresh if data is stale (5 minutes old)
        guard let lastRefresh = lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300
    }
    
    // ================================================================================================
    // MARK: - Computed Properties
    // ================================================================================================
    
    /// Recent announcements (last 7 days)
    var recentAnnouncements: [GuildAnnouncementDTO] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return announcements.filter { $0.postedAt >= sevenDaysAgo }
    }
    
    /// Online members count
    var onlineMembersCount: Int {
        members.filter { $0.isOnline }.count
    }
    
    /// Has watchlist been loaded
    var hasWatchlist: Bool {
        watchlist != nil
    }
}
