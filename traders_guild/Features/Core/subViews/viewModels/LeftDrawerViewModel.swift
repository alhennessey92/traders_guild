//
//  LeftDrawerViewModel.swift
//  traders_guild
//
//  Created by Al Hennessey on 27/10/2025.
//
//  UPDATED: Added Top Markers support
//

import Foundation
import SwiftUI

@MainActor
class LeftDrawerViewModel: ObservableObject {
    
    
    @EnvironmentObject var rlAppState: RLAppState
    
    // ================================================================================================
    // MARK: - Published State
    // ================================================================================================
    
    // NEW: Using RLGuildAnnouncementWithAuthorDTO for announcements (combined response from backend)
    @Published var announcements: [RLGuildAnnouncementWithAuthorDTO] = []
    
    // These still use old DTOs (to be migrated later)
    @Published var upcomingEvents: [GuildEventDTO] = []
    @Published var members: [GuildMembershipDTO] = []
    @Published var watchlist: GuildWatchlistDTO?
    @Published var userNotifications: [GuildNotificationDTO] = []
    @Published var statistics: GuildStatisticsDTO?
    
    // Friends list
    @Published var friends: [GuildMembershipDTO] = []

    // Global leaderboard
    @Published var globalLeaderboard: [GuildMembershipDTO] = []
    
    @Published var guildTradingWatchlist: [TradingSymbolDTO] = []
    @Published var personalTradingWatchlist: [TradingSymbolDTO] = []
    
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    
    private var currentGuildId: UUID?
    
    // ================================================================================================
    // MARK: - Top Markers State
    // ================================================================================================
    
    @Published var trendingMarkers: [TopMarkerDTO] = []
    @Published var symbolGroupedMarkers: [String: [TopMarkerDTO]] = [:]
    @Published var followingMarkers: [TopMarkerDTO] = []
    @Published var myMarkers: [TopMarkerDTO] = []
    @Published var topMarkersLastRefresh: Date?
    @Published var isLoadingTopMarkers: Bool = false
    
    // ================================================================================================
    // MARK: - Navigation State
    // ================================================================================================
    
    /// When set, parent views should navigate to this marker on the chart
    /// After handling navigation, parent should set this back to nil
    @Published var pendingMarkerNavigation: TopMarkerDTO? = nil
    
    /// Request navigation to a specific marker
    /// Parent views observe `pendingMarkerNavigation` and handle the actual navigation
    func requestNavigationToMarker(_ marker: TopMarkerDTO) {
        pendingMarkerNavigation = marker
    }
    
    /// Clear pending navigation (call after handling)
    func clearPendingNavigation() {
        pendingMarkerNavigation = nil
    }
    
    // Load sample data (for development)
    func loadSampleFriendsAndLeaderboard() {
        friends = SampleData.sampleFriends
        globalLeaderboard = SampleData.sampleGlobalLeaderboard
    }
    
    // ================================================================================================
    // MARK: - Cache Update Methods
    // ================================================================================================
    
    /// Mark announcement as read in cache
    func markAnnouncementAsRead(announcementId: UUID) {
        guard let index = announcements.firstIndex(where: { $0.id == announcementId }) else {
            print("⚠️ Announcement not found in cache: \(announcementId)")
            return
        }
        
        announcements[index].isRead = true
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
    /// NOTE: Announcements now use rlAppState, everything else still uses old appState
    func preloadData(for guildId: UUID, appState: AppState, rlAppState: RLAppState) async {
        guard shouldRefresh(for: guildId) else {
            print("📋 preloadData: Skipping refresh (cache still valid)")
            return
        }
        
        print("📋 preloadData: Starting for guild \(guildId)")
        
        isLoading = true
        defer { isLoading = false }
        
        // CRITICAL: Capture userId BEFORE async let block to avoid MainActor isolation error
        let userId = appState.currentUser?.id
        
        // NEW: Fetch announcements from rlAppState
        print("📋 preloadData: Fetching announcements...")
        async let announcementsTask = rlAppState.fetchGuildAnnouncements(guildId: guildId)
        
        // OLD: These still use old appState
        async let eventsTask = appState.fetchGuildEvents(guildId: guildId)
        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
        async let tradingWatchlistTask = appState.fetchGuildTradingWatchlist(guildId: guildId)
        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
        async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
        
        // Fetch personal watchlist separately using captured userId
        async let personalTradingWatchlistTask: [TradingSymbolDTO] = {
            guard let id = userId else { return [] }
            return (try? await appState.fetchPersonalTradingWatchlist(userId: id)) ?? []
        }()
        
        do {
            let (fetchedAnnouncements, fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedTradingWatchlist, fetchedPersonalTradingWatchlist, fetchedUserNotifications, fetchedStatistics) = try await (
                announcementsTask,
                eventsTask,
                membersTask,
                watchlistTask,
                tradingWatchlistTask,
                personalTradingWatchlistTask,
                userNotificationsTask,
                statisticsTask
            )
            
            print("📋 preloadData: Fetched \(fetchedAnnouncements.count) announcements")
            
            self.announcements = fetchedAnnouncements
            self.upcomingEvents = fetchedEvents
            self.members = fetchedMembers
            self.watchlist = fetchedWatchlist
            self.guildTradingWatchlist = fetchedTradingWatchlist
            self.personalTradingWatchlist = fetchedPersonalTradingWatchlist
            self.userNotifications = fetchedUserNotifications
            self.statistics = fetchedStatistics
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
            print("📋 preloadData: Complete. Announcements in VM: \(self.announcements.count)")
            
        } catch is CancellationError {
            print("📋 preloadData: Cancelled")
            return
        } catch {
            print("⚠️ Failed to preload drawer data: \(error)")
            appState.showError(error, title: "Failed to load data", style: .toast)
        }
    }
    
    /// Legacy preload - for backwards compatibility during migration
    /// TODO: Remove once all callers pass rlAppState
    func preloadData(for guildId: UUID, appState: AppState) async {
        // Skip announcements fetch in legacy mode (will be empty)
        guard shouldRefresh(for: guildId) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let userId = appState.currentUser?.id
        
        // OLD: These all use old appState
        async let eventsTask = appState.fetchGuildEvents(guildId: guildId)
        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
        async let tradingWatchlistTask = appState.fetchGuildTradingWatchlist(guildId: guildId)
        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
        async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
        
        async let personalTradingWatchlistTask: [TradingSymbolDTO] = {
            guard let id = userId else { return [] }
            return (try? await appState.fetchPersonalTradingWatchlist(userId: id)) ?? []
        }()
        
        do {
            let (fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedTradingWatchlist, fetchedPersonalTradingWatchlist, fetchedUserNotifications, fetchedStatistics) = try await (
                eventsTask,
                membersTask,
                watchlistTask,
                tradingWatchlistTask,
                personalTradingWatchlistTask,
                userNotificationsTask,
                statisticsTask
            )
            
            // Don't touch announcements in legacy mode - they stay empty or previous
            self.upcomingEvents = fetchedEvents
            self.members = fetchedMembers
            self.watchlist = fetchedWatchlist
            self.guildTradingWatchlist = fetchedTradingWatchlist
            self.personalTradingWatchlist = fetchedPersonalTradingWatchlist
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
        guildTradingWatchlist = []
        personalTradingWatchlist = []
        userNotifications = []
        statistics = nil
        lastRefresh = nil
        currentGuildId = nil
        
        // Clear top markers cache
        trendingMarkers = []
        symbolGroupedMarkers = [:]
        followingMarkers = []
        myMarkers = []
        topMarkersLastRefresh = nil
    }
    
    // ================================================================================================
    // MARK: - Top Markers Methods
    // ================================================================================================
    
    /// Load all top markers data from API
    func loadTopMarkers(for guildId: UUID, appState: AppState) async {
        // Check cache freshness (5 minute cache)
        if let lastRefresh = topMarkersLastRefresh,
           Date().timeIntervalSince(lastRefresh) < 300 {
            return
        }
        
        isLoadingTopMarkers = true
        defer { isLoadingTopMarkers = false }
        
        do {
            let response = try await appState.fetchTopMarkers(guildId: guildId)
            
            self.trendingMarkers = response.trending
            self.symbolGroupedMarkers = response.bySymbol
            self.followingMarkers = response.following
            self.myMarkers = response.mine
            self.topMarkersLastRefresh = Date()
            
            print("✅ Loaded top markers - Trending: \(response.trending.count), Symbols: \(response.bySymbol.count), Following: \(response.following.count), Mine: \(response.mine.count)")
            
        } catch is CancellationError {
            return
        } catch {
            print("⚠️ Failed to load top markers: \(error)")
        }
    }
    
    /// Force refresh top markers (bypasses cache)
    func refreshTopMarkers(for guildId: UUID, appState: AppState) async {
        topMarkersLastRefresh = nil
        await loadTopMarkers(for: guildId, appState: appState)
    }
    
    /// Toggle like on a marker and update local cache
    func toggleMarkerLike(markerId: UUID, appState: AppState) async {
        do {
            let result = try await appState.toggleTopMarkerLike(markerId: markerId)
            
            // Update in trending
            if let index = trendingMarkers.firstIndex(where: { $0.id == markerId }) {
                trendingMarkers[index].isLikedByCurrentUser = result.isLiked
                trendingMarkers[index].likeCount = result.likeCount
            }
            
            // Update in symbol grouped
            for (symbolTicker, markers) in symbolGroupedMarkers {
                if let index = markers.firstIndex(where: { $0.id == markerId }) {
                    symbolGroupedMarkers[symbolTicker]?[index].isLikedByCurrentUser = result.isLiked
                    symbolGroupedMarkers[symbolTicker]?[index].likeCount = result.likeCount
                }
            }
            
            // Update in following
            if let index = followingMarkers.firstIndex(where: { $0.id == markerId }) {
                followingMarkers[index].isLikedByCurrentUser = result.isLiked
                followingMarkers[index].likeCount = result.likeCount
            }
            
            // Update in my markers
            if let index = myMarkers.firstIndex(where: { $0.id == markerId }) {
                myMarkers[index].isLikedByCurrentUser = result.isLiked
                myMarkers[index].likeCount = result.likeCount
            }
            
            print("✅ Updated marker like: \(markerId) -> liked: \(result.isLiked), count: \(result.likeCount)")
            
        } catch {
            print("⚠️ Failed to toggle marker like: \(error)")
        }
    }
    
    /// Clear top markers cache only
    func clearTopMarkersCache() {
        trendingMarkers = []
        symbolGroupedMarkers = [:]
        followingMarkers = []
        myMarkers = []
        topMarkersLastRefresh = nil
    }
    

    
    // ================================================================================================
    // MARK: - Load User Profiles Methods
    // ================================================================================================
    
    
    /// Load profile data for the current user
    func loadCurrentUserProfile(appState: AppState) async -> (
        extendedProfile: UserProfileExtendedDTO?,
        markersSummary: UserMarkersSummaryDTO?,
        userMarkers: [TopMarkerDTO],
        awards: [UserAwardDTO],
        awardsSummary: AwardsSummaryDTO?
    ) {
        guard let userId = appState.currentUser?.id else {
            return (nil, nil, [], [], nil)
        }
        
        do {
            async let profileTask = appState.fetchUserExtendedProfile(userId: userId)
            async let summaryTask = appState.fetchUserMarkersSummary(userId: userId)
            async let markersTask = appState.fetchUserMarkers(userId: userId)
            async let awardsTask = appState.fetchUserAwards(userId: userId)
            async let awardsSummaryTask = appState.fetchUserAwardsSummary(userId: userId)
            
            let (profile, summary, markers, awards, awardsSummary) = try await (
                profileTask,
                summaryTask,
                markersTask,
                awardsTask,
                awardsSummaryTask
            )
            
            return (profile, summary, markers, awards, awardsSummary)
            
        } catch {
            print("⚠️ Failed to load current user profile: \(error)")
            return (nil, nil, [], [], nil)
        }
    }
    
    /// Load profile data for a guild member
    func loadMemberProfile(membership: GuildMembershipDTO, appState: AppState) async -> (
        extendedProfile: UserProfileExtendedDTO?,
        markersSummary: UserMarkersSummaryDTO?,
        userMarkers: [TopMarkerDTO],
        awards: [UserAwardDTO],
        awardsSummary: AwardsSummaryDTO?
    ) {
        do {
            async let profileTask = appState.fetchMemberExtendedProfile(membershipId: membership.id)
            async let summaryTask = appState.fetchUserMarkersSummary(userId: membership.globalMember.id)
            async let markersTask = appState.fetchUserMarkers(userId: membership.globalMember.id, limit: 10)
            async let awardsTask = appState.fetchMemberAwards(membershipId: membership.id)
            async let awardsSummaryTask = appState.fetchUserAwardsSummary(userId: membership.globalMember.id)
            
            let (profile, summary, markers, awards, awardsSummary) = try await (
                profileTask,
                summaryTask,
                markersTask,
                awardsTask,
                awardsSummaryTask
            )
            
            return (profile, summary, markers, awards, awardsSummary)
            
        } catch {
            print("⚠️ Failed to load member profile: \(error)")
            return (nil, nil, [], [], nil)
        }
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
        if announcements.isEmpty && upcomingEvents.isEmpty && members.isEmpty && watchlist == nil && userNotifications.isEmpty && statistics == nil && guildTradingWatchlist.isEmpty && personalTradingWatchlist.isEmpty {
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
    var recentAnnouncements: [RLGuildAnnouncementWithAuthorDTO] {
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
    
    // MARK: - Top Markers Computed Properties
    
    /// Total trending markers count
    var trendingMarkersCount: Int {
        trendingMarkers.count
    }
    
    /// Total markers across all symbols
    var totalSymbolMarkersCount: Int {
        symbolGroupedMarkers.reduce(0) { $0 + $1.value.count }
    }
    
    /// Number of symbols with markers
    var symbolsWithMarkersCount: Int {
        symbolGroupedMarkers.keys.count
    }
    
    /// Has any top markers data
    var hasTopMarkersData: Bool {
        !trendingMarkers.isEmpty || !symbolGroupedMarkers.isEmpty || !followingMarkers.isEmpty || !myMarkers.isEmpty
    }
}






////
////  LeftDrawerViewModel.swift
////  traders_guild
////
////  Created by Al Hennessey on 27/10/2025.
////
////  UPDATED: Added Top Markers support
////
//
//import Foundation
//import SwiftUI
//
//@MainActor
//class LeftDrawerViewModel: ObservableObject {
//    
//    
//    @EnvironmentObject var rlAppState: RLAppState
//    
//    // ================================================================================================
//    // MARK: - Published State
//    // ================================================================================================
//    
//    // NEW: Using RLAnnouncementViewModel for announcements
//    @Published var announcements: [RLAnnouncementViewModel] = []
//    
//    // These still use old DTOs (to be migrated later)
//    @Published var upcomingEvents: [GuildEventDTO] = []
//    @Published var members: [GuildMembershipDTO] = []
//    @Published var watchlist: GuildWatchlistDTO?
//    @Published var userNotifications: [GuildNotificationDTO] = []
//    @Published var statistics: GuildStatisticsDTO?
//    
//    // Friends list
//    @Published var friends: [GuildMembershipDTO] = []
//
//    // Global leaderboard
//    @Published var globalLeaderboard: [GuildMembershipDTO] = []
//    
//    @Published var guildTradingWatchlist: [TradingSymbolDTO] = []
//    @Published var personalTradingWatchlist: [TradingSymbolDTO] = []
//    
//    @Published var isLoading: Bool = false
//    @Published var lastRefresh: Date?
//    
//    private var currentGuildId: UUID?
//    
//    // ================================================================================================
//    // MARK: - Top Markers State
//    // ================================================================================================
//    
//    @Published var trendingMarkers: [TopMarkerDTO] = []
//    @Published var symbolGroupedMarkers: [String: [TopMarkerDTO]] = [:]
//    @Published var followingMarkers: [TopMarkerDTO] = []
//    @Published var myMarkers: [TopMarkerDTO] = []
//    @Published var topMarkersLastRefresh: Date?
//    @Published var isLoadingTopMarkers: Bool = false
//    
//    // ================================================================================================
//    // MARK: - Navigation State
//    // ================================================================================================
//    
//    /// When set, parent views should navigate to this marker on the chart
//    /// After handling navigation, parent should set this back to nil
//    @Published var pendingMarkerNavigation: TopMarkerDTO? = nil
//    
//    /// Request navigation to a specific marker
//    /// Parent views observe `pendingMarkerNavigation` and handle the actual navigation
//    func requestNavigationToMarker(_ marker: TopMarkerDTO) {
//        pendingMarkerNavigation = marker
//    }
//    
//    /// Clear pending navigation (call after handling)
//    func clearPendingNavigation() {
//        pendingMarkerNavigation = nil
//    }
//    
//    // Load sample data (for development)
//    func loadSampleFriendsAndLeaderboard() {
//        friends = SampleData.sampleFriends
//        globalLeaderboard = SampleData.sampleGlobalLeaderboard
//    }
//    
//    // ================================================================================================
//    // MARK: - Cache Update Methods
//    // ================================================================================================
//    
//    /// Mark announcement as read in cache
//    func markAnnouncementAsRead(announcementId: UUID) {
//        guard let index = announcements.firstIndex(where: { $0.id == announcementId }) else {
//            print("⚠️ Announcement not found in cache: \(announcementId)")
//            return
//        }
//        
//        announcements[index].isRead = true
//        print("✅ Updated announcement cache: \(announcementId) -> isRead: true")
//    }
//    
//    /// Mark event as read in cache
//    func markEventAsRead(eventId: UUID) {
//        guard let index = upcomingEvents.firstIndex(where: { $0.id == eventId }) else {
//            print("⚠️ Event not found in cache: \(eventId)")
//            return
//        }
//        
//        var updatedEvent = upcomingEvents[index]
//        updatedEvent.isRead = true
//        upcomingEvents[index] = updatedEvent
//        print("✅ Updated event cache: \(eventId) -> isRead: true")
//    }
//    
//    /// Update event attendance status in cache
//    func updateEventAttendance(eventId: UUID, isAttending: Bool, attendanceCount: Int? = nil) {
//        guard let index = upcomingEvents.firstIndex(where: { $0.id == eventId }) else {
//            print("⚠️ Event not found in cache: \(eventId)")
//            return
//        }
//        
//        var updatedEvent = upcomingEvents[index]
//        updatedEvent.isAttending = isAttending
//        if let attendanceCount = attendanceCount {
//            updatedEvent.attendeeCount = attendanceCount
//        }
//        upcomingEvents[index] = updatedEvent
//        print("✅ Updated event attendance cache: \(eventId) -> isAttending: \(isAttending)")
//    }
//    
//    
//    /// Mark notification as read in cache
//    func markNotificationAsRead(notificationId: UUID) {
//        guard let index = userNotifications.firstIndex(where: { $0.id == notificationId }) else {
//            print("⚠️ Notification not found in cache: \(notificationId)")
//            return
//        }
//        
//        var updatedNotification = userNotifications[index]
//        updatedNotification.isRead = true
//        userNotifications[index] = updatedNotification
//        print("✅ Updated notification cache: \(notificationId) -> isRead: true")
//    }
//    
//    // ================================================================================================
//    // MARK: - Preload Data
//    // ================================================================================================
//    
//    /// Preload all drawer data in parallel
//    /// NOTE: Announcements now use rlAppState, everything else still uses old appState
//    func preloadData(for guildId: UUID, appState: AppState, rlAppState: RLAppState) async {
//        guard shouldRefresh(for: guildId) else {
//            print("📋 preloadData: Skipping refresh (cache still valid)")
//            return
//        }
//        
//        print("📋 preloadData: Starting for guild \(guildId)")
//        
//        isLoading = true
//        defer { isLoading = false }
//        
//        // CRITICAL: Capture userId BEFORE async let block to avoid MainActor isolation error
//        let userId = appState.currentUser?.id
//        
//        // NEW: Fetch announcements from rlAppState
//        print("📋 preloadData: Fetching announcements...")
//        async let announcementsTask = rlAppState.fetchGuildAnnouncements(guildId: guildId)
//        
//        // OLD: These still use old appState
//        async let eventsTask = appState.fetchGuildEvents(guildId: guildId)
//        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
//        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
//        async let tradingWatchlistTask = appState.fetchGuildTradingWatchlist(guildId: guildId)
//        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
//        async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
//        
//        // Fetch personal watchlist separately using captured userId
//        async let personalTradingWatchlistTask: [TradingSymbolDTO] = {
//            guard let id = userId else { return [] }
//            return (try? await appState.fetchPersonalTradingWatchlist(userId: id)) ?? []
//        }()
//        
//        do {
//            let (fetchedAnnouncements, fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedTradingWatchlist, fetchedPersonalTradingWatchlist, fetchedUserNotifications, fetchedStatistics) = try await (
//                announcementsTask,
//                eventsTask,
//                membersTask,
//                watchlistTask,
//                tradingWatchlistTask,
//                personalTradingWatchlistTask,
//                userNotificationsTask,
//                statisticsTask
//            )
//            
//            print("📋 preloadData: Fetched \(fetchedAnnouncements.count) announcements")
//            
//            self.announcements = fetchedAnnouncements
//            self.upcomingEvents = fetchedEvents
//            self.members = fetchedMembers
//            self.watchlist = fetchedWatchlist
//            self.guildTradingWatchlist = fetchedTradingWatchlist
//            self.personalTradingWatchlist = fetchedPersonalTradingWatchlist
//            self.userNotifications = fetchedUserNotifications
//            self.statistics = fetchedStatistics
//            self.lastRefresh = Date()
//            self.currentGuildId = guildId
//            
//            print("📋 preloadData: Complete. Announcements in VM: \(self.announcements.count)")
//            
//        } catch is CancellationError {
//            print("📋 preloadData: Cancelled")
//            return
//        } catch {
//            print("⚠️ Failed to preload drawer data: \(error)")
//            appState.showError(error, title: "Failed to load data", style: .toast)
//        }
//    }
//    
//    /// Legacy preload - for backwards compatibility during migration
//    /// TODO: Remove once all callers pass rlAppState
//    func preloadData(for guildId: UUID, appState: AppState) async {
//        // Skip announcements fetch in legacy mode (will be empty)
//        guard shouldRefresh(for: guildId) else { return }
//        
//        isLoading = true
//        defer { isLoading = false }
//        
//        let userId = appState.currentUser?.id
//        
//        // OLD: These all use old appState
//        async let eventsTask = appState.fetchGuildEvents(guildId: guildId)
//        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
//        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
//        async let tradingWatchlistTask = appState.fetchGuildTradingWatchlist(guildId: guildId)
//        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
//        async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
//        
//        async let personalTradingWatchlistTask: [TradingSymbolDTO] = {
//            guard let id = userId else { return [] }
//            return (try? await appState.fetchPersonalTradingWatchlist(userId: id)) ?? []
//        }()
//        
//        do {
//            let (fetchedEvents, fetchedMembers, fetchedWatchlist, fetchedTradingWatchlist, fetchedPersonalTradingWatchlist, fetchedUserNotifications, fetchedStatistics) = try await (
//                eventsTask,
//                membersTask,
//                watchlistTask,
//                tradingWatchlistTask,
//                personalTradingWatchlistTask,
//                userNotificationsTask,
//                statisticsTask
//            )
//            
//            // Don't touch announcements in legacy mode - they stay empty or previous
//            self.upcomingEvents = fetchedEvents
//            self.members = fetchedMembers
//            self.watchlist = fetchedWatchlist
//            self.guildTradingWatchlist = fetchedTradingWatchlist
//            self.personalTradingWatchlist = fetchedPersonalTradingWatchlist
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
//        watchlist = nil
//        guildTradingWatchlist = []
//        personalTradingWatchlist = []
//        userNotifications = []
//        statistics = nil
//        lastRefresh = nil
//        currentGuildId = nil
//        
//        // Clear top markers cache
//        trendingMarkers = []
//        symbolGroupedMarkers = [:]
//        followingMarkers = []
//        myMarkers = []
//        topMarkersLastRefresh = nil
//    }
//    
//    // ================================================================================================
//    // MARK: - Top Markers Methods
//    // ================================================================================================
//    
//    /// Load all top markers data from API
//    func loadTopMarkers(for guildId: UUID, appState: AppState) async {
//        // Check cache freshness (5 minute cache)
//        if let lastRefresh = topMarkersLastRefresh,
//           Date().timeIntervalSince(lastRefresh) < 300 {
//            return
//        }
//        
//        isLoadingTopMarkers = true
//        defer { isLoadingTopMarkers = false }
//        
//        do {
//            let response = try await appState.fetchTopMarkers(guildId: guildId)
//            
//            self.trendingMarkers = response.trending
//            self.symbolGroupedMarkers = response.bySymbol
//            self.followingMarkers = response.following
//            self.myMarkers = response.mine
//            self.topMarkersLastRefresh = Date()
//            
//            print("✅ Loaded top markers - Trending: \(response.trending.count), Symbols: \(response.bySymbol.count), Following: \(response.following.count), Mine: \(response.mine.count)")
//            
//        } catch is CancellationError {
//            return
//        } catch {
//            print("⚠️ Failed to load top markers: \(error)")
//        }
//    }
//    
//    /// Force refresh top markers (bypasses cache)
//    func refreshTopMarkers(for guildId: UUID, appState: AppState) async {
//        topMarkersLastRefresh = nil
//        await loadTopMarkers(for: guildId, appState: appState)
//    }
//    
//    /// Toggle like on a marker and update local cache
//    func toggleMarkerLike(markerId: UUID, appState: AppState) async {
//        do {
//            let result = try await appState.toggleTopMarkerLike(markerId: markerId)
//            
//            // Update in trending
//            if let index = trendingMarkers.firstIndex(where: { $0.id == markerId }) {
//                trendingMarkers[index].isLikedByCurrentUser = result.isLiked
//                trendingMarkers[index].likeCount = result.likeCount
//            }
//            
//            // Update in symbol grouped
//            for (symbolTicker, markers) in symbolGroupedMarkers {
//                if let index = markers.firstIndex(where: { $0.id == markerId }) {
//                    symbolGroupedMarkers[symbolTicker]?[index].isLikedByCurrentUser = result.isLiked
//                    symbolGroupedMarkers[symbolTicker]?[index].likeCount = result.likeCount
//                }
//            }
//            
//            // Update in following
//            if let index = followingMarkers.firstIndex(where: { $0.id == markerId }) {
//                followingMarkers[index].isLikedByCurrentUser = result.isLiked
//                followingMarkers[index].likeCount = result.likeCount
//            }
//            
//            // Update in my markers
//            if let index = myMarkers.firstIndex(where: { $0.id == markerId }) {
//                myMarkers[index].isLikedByCurrentUser = result.isLiked
//                myMarkers[index].likeCount = result.likeCount
//            }
//            
//            print("✅ Updated marker like: \(markerId) -> liked: \(result.isLiked), count: \(result.likeCount)")
//            
//        } catch {
//            print("⚠️ Failed to toggle marker like: \(error)")
//        }
//    }
//    
//    /// Clear top markers cache only
//    func clearTopMarkersCache() {
//        trendingMarkers = []
//        symbolGroupedMarkers = [:]
//        followingMarkers = []
//        myMarkers = []
//        topMarkersLastRefresh = nil
//    }
//    
//
//    
//    // ================================================================================================
//    // MARK: - Load User Profiles Methods
//    // ================================================================================================
//    
//    
//    /// Load profile data for the current user
//    func loadCurrentUserProfile(appState: AppState) async -> (
//        extendedProfile: UserProfileExtendedDTO?,
//        markersSummary: UserMarkersSummaryDTO?,
//        userMarkers: [TopMarkerDTO],
//        awards: [UserAwardDTO],
//        awardsSummary: AwardsSummaryDTO?
//    ) {
//        guard let userId = appState.currentUser?.id else {
//            return (nil, nil, [], [], nil)
//        }
//        
//        do {
//            async let profileTask = appState.fetchUserExtendedProfile(userId: userId)
//            async let summaryTask = appState.fetchUserMarkersSummary(userId: userId)
//            async let markersTask = appState.fetchUserMarkers(userId: userId)
//            async let awardsTask = appState.fetchUserAwards(userId: userId)
//            async let awardsSummaryTask = appState.fetchUserAwardsSummary(userId: userId)
//            
//            let (profile, summary, markers, awards, awardsSummary) = try await (
//                profileTask,
//                summaryTask,
//                markersTask,
//                awardsTask,
//                awardsSummaryTask
//            )
//            
//            return (profile, summary, markers, awards, awardsSummary)
//            
//        } catch {
//            print("⚠️ Failed to load current user profile: \(error)")
//            return (nil, nil, [], [], nil)
//        }
//    }
//    
//    /// Load profile data for a guild member
//    func loadMemberProfile(membership: GuildMembershipDTO, appState: AppState) async -> (
//        extendedProfile: UserProfileExtendedDTO?,
//        markersSummary: UserMarkersSummaryDTO?,
//        userMarkers: [TopMarkerDTO],
//        awards: [UserAwardDTO],
//        awardsSummary: AwardsSummaryDTO?
//    ) {
//        do {
//            async let profileTask = appState.fetchMemberExtendedProfile(membershipId: membership.id)
//            async let summaryTask = appState.fetchUserMarkersSummary(userId: membership.globalMember.id)
//            async let markersTask = appState.fetchUserMarkers(userId: membership.globalMember.id, limit: 10)
//            async let awardsTask = appState.fetchMemberAwards(membershipId: membership.id)
//            async let awardsSummaryTask = appState.fetchUserAwardsSummary(userId: membership.globalMember.id)
//            
//            let (profile, summary, markers, awards, awardsSummary) = try await (
//                profileTask,
//                summaryTask,
//                markersTask,
//                awardsTask,
//                awardsSummaryTask
//            )
//            
//            return (profile, summary, markers, awards, awardsSummary)
//            
//        } catch {
//            print("⚠️ Failed to load member profile: \(error)")
//            return (nil, nil, [], [], nil)
//        }
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
//        if announcements.isEmpty && upcomingEvents.isEmpty && members.isEmpty && watchlist == nil && userNotifications.isEmpty && statistics == nil && guildTradingWatchlist.isEmpty && personalTradingWatchlist.isEmpty {
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
//    var recentAnnouncements: [RLAnnouncementViewModel] {
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
//    
//    // MARK: - Top Markers Computed Properties
//    
//    /// Total trending markers count
//    var trendingMarkersCount: Int {
//        trendingMarkers.count
//    }
//    
//    /// Total markers across all symbols
//    var totalSymbolMarkersCount: Int {
//        symbolGroupedMarkers.reduce(0) { $0 + $1.value.count }
//    }
//    
//    /// Number of symbols with markers
//    var symbolsWithMarkersCount: Int {
//        symbolGroupedMarkers.keys.count
//    }
//    
//    /// Has any top markers data
//    var hasTopMarkersData: Bool {
//        !trendingMarkers.isEmpty || !symbolGroupedMarkers.isEmpty || !followingMarkers.isEmpty || !myMarkers.isEmpty
//    }
//}





