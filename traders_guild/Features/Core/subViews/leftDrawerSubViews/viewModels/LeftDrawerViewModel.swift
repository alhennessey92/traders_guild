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
    @Published var watchlist: GuildWatchlistDTO?
    @Published var userNotifications: [GuildNotificationDTO] = []
    @Published var statistics: GuildStatisticsDTO?
    
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    
    private var currentGuildId: UUID?
    
    // ================================================================================================
    // MARK: - Cache Update Methods
    // ================================================================================================
    
    /// Mark announcement as read in cache
    func markAnnouncementAsRead(announcementId: UUID) {
        guard let index = announcements.firstIndex(where: { $0.id == announcementId }) else {
            print("⚠️ Announcement not found in cache: \(announcementId)")
            return
        }
        
        var updatedAnnouncement = announcements[index]
        updatedAnnouncement.isRead = true
        announcements[index] = updatedAnnouncement
        print("✅ Updated announcement cache: \(announcementId) -> isRead: true")
    }
    
    /// Mark event as read in cache
    func markEventAsRead(eventId: UUID) {
        guard let index = upcomingEvents.firstIndex(where: { $0.id == eventId }) else {
            print("⚠️ Event not found in cache: \(eventId)")
            return
        }
        
        var updatedEvent = upcomingEvents[index]
        updatedEvent.isRead = true
        upcomingEvents[index] = updatedEvent
        print("✅ Updated event cache: \(eventId) -> isRead: true")
    }
    
    /// Update event attendance status in cache
    func updateEventAttendance(eventId: UUID, isAttending: Bool, attendanceCount: Int? = nil) {
        guard let index = upcomingEvents.firstIndex(where: { $0.id == eventId }) else {
            print("⚠️ Event not found in cache: \(eventId)")
            return
        }
        
        var updatedEvent = upcomingEvents[index]
        updatedEvent.isAttending = isAttending
        if let attendanceCount = attendanceCount {
            updatedEvent.attendeeCount = attendanceCount
        }
        upcomingEvents[index] = updatedEvent
        print("✅ Updated event attendance cache: \(eventId) -> isAttending: \(isAttending)")
    }
    
    
    /// Mark notification as read in cache
    func markNotificationAsRead(notificationId: UUID) {
        guard let index = userNotifications.firstIndex(where: { $0.id == notificationId }) else {
            print("⚠️ Notification not found in cache: \(notificationId)")
            return
        }
        
        var updatedNotification = userNotifications[index]
        updatedNotification.isRead = true
        userNotifications[index] = updatedNotification
        print("✅ Updated notification cache: \(notificationId) -> isRead: true")
    }
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
        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
        async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
        
        do {
            let (fetchedAnnouncements, fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedUserNotifications, fetchedStatistics) = try await (
                announcementsTask,
                eventsTask,
                membersTask,
                watchlistTask,
                userNotificationsTask,
                statisticsTask
            )
            
            self.announcements = fetchedAnnouncements
            self.upcomingEvents = fetchedEvents
            self.members = fetchedMembers
            self.watchlist = fetchedWatchlist
            self.userNotifications = fetchedUserNotifications
            self.statistics = fetchedStatistics
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
        watchlist = nil
        userNotifications = []
        statistics = nil
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
        if announcements.isEmpty && upcomingEvents.isEmpty && members.isEmpty && watchlist == nil && userNotifications.isEmpty && statistics == nil  {
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
    
    /// Has statistics been loaded
    var hasStatistics: Bool {
        statistics != nil
    }
}

//@MainActor
//class LeftDrawerViewModel: ObservableObject {
//    
//    // ================================================================================================
//    // MARK: - Published State
//    // ================================================================================================
//    
//    @Published var announcements: [GuildAnnouncementDTO] = []
//    @Published var upcomingEvents: [GuildEventDTO] = []
//    @Published var members: [GuildMembershipDTO] = []
//    @Published var watchlist: GuildWatchlistDTO?  // ✅ Single object, not array
//    @Published var userNotifications: [GuildNotificationDTO] = []
//    @Published var statistics: GuildStatisticsDTO?  // ✅ Single object, not array
//    
//    @Published var isLoading: Bool = false
//    @Published var lastRefresh: Date?
//    
//    private var currentGuildId: UUID?
//    
//    // ================================================================================================
//    // MARK: - Preload Data
//    // ================================================================================================
//    
//    /// Preload all drawer data in parallel
//    func preloadData(for guildId: UUID, appState: AppState) async {
//        guard shouldRefresh(for: guildId) else { return }
//        
//        isLoading = true
//        defer { isLoading = false }
//        
//        async let announcementsTask = appState.fetchGuildAnnouncements(guildId: guildId)
//        async let eventsTask = appState.fetchGuildEvents(guildId: guildId)
//        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
//        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)  // Returns single object
//        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
//        async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)  // Returns single object
//        
//        do {
//            let (fetchedAnnouncements, fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedUserNotifications, fetchedStatistics) = try await (
//                announcementsTask,
//                eventsTask,
//                membersTask,
//                watchlistTask,
//                userNotificationsTask,
//                statisticsTask
//            )
//            
//            self.announcements = fetchedAnnouncements
//            self.upcomingEvents = fetchedEvents
//            self.members = fetchedMembers
//            self.watchlist = fetchedWatchlist  // ✅ Single assignment
//            self.userNotifications = fetchedUserNotifications
//            self.statistics = fetchedStatistics
//            self.lastRefresh = Date()
//            self.currentGuildId = guildId
//            
//        } catch is CancellationError {
//            return
//        } catch {
//            print("⚠️ Failed to preload drawer data: \(error)")
//            appState.showError(error, title: "Failed to load data", style: .toast)
//        }
//    }
//    
//    /// Manual refresh - forces reload
//    func refresh(for guildId: UUID, appState: AppState) async {
//        lastRefresh = nil
//        await preloadData(for: guildId, appState: appState)
//    }
//    
//    /// Clear all cached data
//    func clearCache() {
//        announcements = []
//        upcomingEvents = []
//        members = []
//        watchlist = nil  // ✅ Set to nil instead of empty array
//        userNotifications = []
//        statistics = nil  // ✅ Set to nil instead of empty array
//        lastRefresh = nil
//        currentGuildId = nil
//    }
//    
//    // ================================================================================================
//    // MARK: - Cache Logic
//    // ================================================================================================
//    
//    /// Check if data should be refreshed
//    private func shouldRefresh(for guildId: UUID) -> Bool {
//        // Always refresh if guild changed
//        if currentGuildId != guildId {
//            return true
//        }
//        
//        // Refresh if cache is empty
//        if announcements.isEmpty && upcomingEvents.isEmpty && members.isEmpty && watchlist == nil && userNotifications.isEmpty && statistics == nil  {
//            return true
//        }
//        
//        // Refresh if data is stale (5 minutes old)
//        guard let lastRefresh = lastRefresh else { return true }
//        return Date().timeIntervalSince(lastRefresh) > 300
//    }
//    
//    // ================================================================================================
//    // MARK: - Computed Properties
//    // ================================================================================================
//    
//    /// Recent announcements (last 7 days)
//    var recentAnnouncements: [GuildAnnouncementDTO] {
//        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
//        return announcements.filter { $0.postedAt >= sevenDaysAgo }
//    }
//    
//    /// Online members count
//    var onlineMembersCount: Int {
//        members.filter { $0.isOnline }.count
//    }
//    
//    /// Has watchlist been loaded
//    var hasWatchlist: Bool {
//        watchlist != nil
//    }
//    
//    /// Has statistics been loaded
//    var hasStatistics: Bool {
//        statistics != nil
//    }
//}
