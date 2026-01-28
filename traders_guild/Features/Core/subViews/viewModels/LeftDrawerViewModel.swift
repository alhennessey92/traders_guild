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
import Combine

@MainActor
class LeftDrawerViewModel: ObservableObject {
    
    
    @EnvironmentObject var rlAppState: RLAppState
    
    // ================================================================================================
    // MARK: - Published State
    // ================================================================================================
    
    // NEW: Using RLGuildAnnouncementWithAuthorDTO for announcements (combined response from backend)
    @Published var announcements: [RLGuildAnnouncementWithAuthorDTO] = []
    // NEW: Using RLGuildEventWithAuthorDTO for events (combined response from backend)
    @Published var upcomingEvents: [RLGuildEventWithAuthorDTO] = []
    
    
    // These still use old DTOs (to be migrated later)
    
    @Published var members: [GuildMembershipDTO] = []
    @Published var watchlist: GuildWatchlistDTO?
    @Published var userNotifications: [GuildNotificationDTO] = []
    @Published var statistics: RLGuildStatisticsResponse?
    
    // New: backend-driven guild members
    @Published var guildMembers: [RLGuildMemberDTO] = []
    @Published var guildMembersTotalCount: Int = 0
    @Published var guildMembersOnlineCount: Int = 0
    @Published var isLoadingGuildMembers: Bool = false
    
    // Friends list
    @Published var friends: [GuildMembershipDTO] = []
    
    // Pending friend requests (real API)
    @Published var pendingFriendRequestsIncoming: [RLFriendRequestIncomingDTO] = []
    @Published var pendingFriendRequestsOutgoing: [RLFriendRequestOutgoingDTO] = []
    @Published var isLoadingFriendRequests: Bool = false
    
    // Accepted friends (real API)
    @Published var friendsRL: [RLFriendDTO] = []
    @Published var friendsRLTotalCount: Int = 0
    @Published var friendsRLOnlineCount: Int = 0
    @Published var isLoadingFriendsRL: Bool = false

    // Global leaderboard
    @Published var globalLeaderboard: [GuildMembershipDTO] = []
    
    @Published var guildTradingWatchlist: [TradingSymbolDTO] = []
    @Published var personalTradingWatchlist: [TradingSymbolDTO] = []
    
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    
    private var currentGuildId: UUID?
    private var cancellables = Set<AnyCancellable>()
    private weak var rlAppStateRef: RLAppState?
    
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

    func configure(with rlAppState: RLAppState) {
        rlAppStateRef = rlAppState
        rlAppState.$presenceByUserId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presenceMap in
                self?.applyPresenceUpdates(presenceMap)
            }
            .store(in: &cancellables)
        applyPresenceUpdates(rlAppState.presenceByUserId)
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

    private func applyPresenceUpdates(_ presenceMap: [UUID: Bool]) {
        if presenceMap.isEmpty {
            guildMembers = guildMembers.map { $0.withOnlineStatus(false) }
            guildMembersOnlineCount = 0
            friendsRL = friendsRL.map { $0.withOnlineStatus(false) }
            friendsRLOnlineCount = 0
            return
        }
        
        var didChange = false
        guildMembers = guildMembers.map { member in
            guard let isOnline = presenceMap[member.userId], isOnline != member.isOnline else {
                return member
            }
            didChange = true
            return member.withOnlineStatus(isOnline)
        }
        
        if didChange {
            guildMembersOnlineCount = guildMembers.filter { $0.isOnline }.count
        }
        
        var friendsChanged = false
        friendsRL = friendsRL.map { friend in
            guard let isOnline = presenceMap[friend.userId], isOnline != friend.isOnline else {
                return friend
            }
            friendsChanged = true
            return friend.withOnlineStatus(isOnline)
        }
        
        if friendsChanged {
            friendsRLOnlineCount = friendsRL.filter { $0.isOnline }.count
        }
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
    
    /// Preload all drawer data in parallel - each fetch is independent (failures don't cascade)
    /// NOTE: Announcements now use rlAppState, everything else still uses old appState
    func preloadData(for guildId: UUID, appState: AppState, rlAppState: RLAppState) async {
        guard shouldRefresh(for: guildId) else {
            print("📋 preloadData: Skipping refresh (cache still valid)")
            return
        }
        
        print("📋 preloadData: Starting for guild \(guildId)")
        
        isLoading = true
        defer { isLoading = false }
        
        // Capture userId for personal watchlist
        let userId = appState.currentUser?.id
        
        // Run all fetches independently - failures don't cascade
        await withTaskGroup(of: Void.self) { group in
            // Announcements (from rlAppState)
            group.addTask {
                do {
                    let fetched = try await rlAppState.fetchGuildAnnouncements(guildId: guildId)
                    await MainActor.run { self.announcements = fetched }
                    print("📋 preloadData: Fetched \(fetched.count) announcements")
                } catch is CancellationError {
                    print("📋 preloadData: Announcements cancelled")
                } catch {
                    print("⚠️ Failed to fetch announcements: \(error)")
                }
            }
            
            // Events (from rlAppState - like announcements)
            group.addTask {
                do {
                    let fetched = try await rlAppState.fetchGuildEvents(guildId: guildId)
                    await MainActor.run { self.upcomingEvents = fetched }
                    print("📋 preloadData: Fetched \(fetched.count) events")
                } catch is CancellationError {
                    // Silent - expected during navigation
                } catch {
                    print("⚠️ Failed to fetch events: \(error)")
                }
            }
            
            // Members
            group.addTask {
                do {
                    let fetched = try await appState.fetchGuildMembers(guildId: guildId)
                    await MainActor.run { self.members = fetched }
                } catch is CancellationError {
                    // Silent
                } catch {
                    print("⚠️ Failed to fetch members: \(error)")
                }
            }
            
            // Watchlist
            group.addTask {
                do {
                    let fetched = try await appState.fetchGuildWatchlist(guildId: guildId)
                    await MainActor.run { self.watchlist = fetched }
                } catch is CancellationError {
                    // Silent
                } catch {
                    print("⚠️ Failed to fetch watchlist: \(error)")
                }
            }
            
            // Guild Trading Watchlist
            group.addTask {
                do {
                    let fetched = try await appState.fetchGuildTradingWatchlist(guildId: guildId)
                    await MainActor.run { self.guildTradingWatchlist = fetched }
                } catch is CancellationError {
                    // Silent
                } catch {
                    print("⚠️ Failed to fetch guild trading watchlist: \(error)")
                }
            }
            
            // Personal Trading Watchlist
            if let userId = userId {
                group.addTask {
                    do {
                        let fetched = try await appState.fetchPersonalTradingWatchlist(userId: userId)
                        await MainActor.run { self.personalTradingWatchlist = fetched }
                    } catch is CancellationError {
                        // Silent
                    } catch {
                        print("⚠️ Failed to fetch personal trading watchlist: \(error)")
                    }
                }
            }
            
            // Notifications
            group.addTask {
                do {
                    let fetched = try await appState.fetchGuildUserNotifications(guildId: guildId)
                    await MainActor.run { self.userNotifications = fetched }
                } catch is CancellationError {
                    // Silent
                } catch {
                    print("⚠️ Failed to fetch notifications: \(error)")
                }
            }
            
            // Statistics (from rlAppState - like announcements/events)
            group.addTask {
                do {
                    let fetched = try await rlAppState.fetchGuildStatistics(guildId: guildId)
                    await MainActor.run { self.statistics = fetched }
                    print("📋 preloadData: Fetched statistics")
                } catch is CancellationError {
                    // Silent - expected during navigation
                } catch {
                    print("⚠️ Failed to fetch statistics: \(error)")
                }
            }
        }
        
        self.lastRefresh = Date()
        self.currentGuildId = guildId
        print("📋 preloadData: Complete")
    }
    
    /// Legacy preload - for backwards compatibility during migration
    /// NOTE: Announcements and Events require rlAppState - they will be skipped in legacy mode
    /// TODO: Remove once all callers pass rlAppState
    func preloadData(for guildId: UUID, appState: AppState) async {
        // Skip announcements and events fetch in legacy mode (will be empty)
        guard shouldRefresh(for: guildId) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let userId = appState.currentUser?.id
        
        // OLD: These all use old appState (events removed - now requires rlAppState)
        async let membersTask = appState.fetchGuildMembers(guildId: guildId)
        async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
        async let tradingWatchlistTask = appState.fetchGuildTradingWatchlist(guildId: guildId)
        async let userNotificationsTask = appState.fetchGuildUserNotifications(guildId: guildId)
        //async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
        
        async let personalTradingWatchlistTask: [TradingSymbolDTO] = {
            guard let id = userId else { return [] }
            return (try? await appState.fetchPersonalTradingWatchlist(userId: id)) ?? []
        }()
        
        do {
            let (fetchedMembers, fetchedWatchlist, fetchedTradingWatchlist, fetchedPersonalTradingWatchlist, fetchedUserNotifications) = try await (
                membersTask,
                watchlistTask,
                tradingWatchlistTask,
                personalTradingWatchlistTask,
                userNotificationsTask,
                //statisticsTask
            )
            
            // Don't touch announcements or events in legacy mode - they require rlAppState
            self.members = fetchedMembers
            self.watchlist = fetchedWatchlist
            self.guildTradingWatchlist = fetchedTradingWatchlist
            self.personalTradingWatchlist = fetchedPersonalTradingWatchlist
            self.userNotifications = fetchedUserNotifications
            //self.statistics = fetchedStatistics
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
        } catch is CancellationError {
            return
        } catch {
            print("⚠️ Failed to preload drawer data: \(error)")
            appState.showError(error, title: "Failed to load data", style: .toast)
        }
    }
    
    /// Manual refresh - forces reload of ALL data
    /// NOTE: Requires rlAppState for announcements
    func refresh(for guildId: UUID, appState: AppState, rlAppState: RLAppState) async {
        lastRefresh = nil
        await preloadData(for: guildId, appState: appState, rlAppState: rlAppState)
    }
    
    /// Legacy refresh - for backwards compatibility (doesn't refresh announcements)
    func refresh(for guildId: UUID, appState: AppState) async {
        lastRefresh = nil
        await preloadData(for: guildId, appState: appState)
    }
    
    // ================================================================================================
    // MARK: - Component-Specific Refresh (Recommended for Production)
    // ================================================================================================
    
    /// Refresh only announcements - use this in AnnouncementsView
    func refreshAnnouncements(guildId: UUID, rlAppState: RLAppState) async {
        do {
            let fetched = try await rlAppState.fetchGuildAnnouncements(guildId: guildId)
            await MainActor.run {
                self.announcements = fetched
            }
        } catch is CancellationError {
            print("📋 refreshAnnouncements: Cancelled")
        } catch {
            print("⚠️ Failed to refresh announcements: \(error)")
        }
    }
    
    /// Refresh only events - use this in EventsView
    func refreshEvents(guildId: UUID, rlAppState: RLAppState) async {
        do {
            let fetched = try await rlAppState.fetchGuildEvents(guildId: guildId)
            await MainActor.run {
                self.upcomingEvents = fetched
            }
        } catch is CancellationError {
            print("📋 refreshEvents: Cancelled")
        } catch {
            print("⚠️ Failed to refresh events: \(error)")
        }
    }
    
    /// Refresh only members - use this in MembersView
    func refreshMembers(guildId: UUID, appState: AppState) async {
        do {
            let fetched = try await appState.fetchGuildMembers(guildId: guildId)
            await MainActor.run {
                self.members = fetched
            }
        } catch is CancellationError {
            print("📋 refreshMembers: Cancelled")
        } catch {
            print("⚠️ Failed to refresh members: \(error)")
        }
    }
    
    /// Refresh guild members from real API (new DTOs)
    func refreshGuildMembers(guildId: UUID, rlAppState: RLAppState, search: String? = nil) async {
        isLoadingGuildMembers = true
        defer { isLoadingGuildMembers = false }
        
        do {
            let response = try await rlAppState.fetchGuildMembers(guildId: guildId, search: search)
            await MainActor.run {
                self.guildMembers = response.members
                self.guildMembersTotalCount = response.totalCount
                self.guildMembersOnlineCount = response.onlineCount
            }
        } catch is CancellationError {
            print("📋 refreshGuildMembers: Cancelled")
        } catch let error as APIError {
            if case .networkError(let message) = error, message == "cancelled" {
                print("📋 refreshGuildMembers: Network cancelled")
                return
            }
            print("⚠️ Failed to refresh guild members: \(error)")
        } catch {
            print("⚠️ Failed to refresh guild members: \(error)")
        }
    }
    
    /// Refresh friend requests (incoming + outgoing) from real API
    func refreshFriendRequests(guildId: UUID? = nil, rlAppState: RLAppState) async {
        isLoadingFriendRequests = true
        defer { isLoadingFriendRequests = false }
        
        do {
            let response = try await rlAppState.fetchFriendRequests(guildId: guildId)
            await MainActor.run {
                self.pendingFriendRequestsIncoming = response.incoming
                self.pendingFriendRequestsOutgoing = response.outgoing
            }
        } catch is CancellationError {
            print("📋 refreshFriendRequests: Cancelled")
        } catch let error as APIError {
            if case .networkError(let message) = error, message == "cancelled" {
                print("📋 refreshFriendRequests: Network cancelled")
                return
            }
            print("⚠️ Failed to refresh friend requests: \(error)")
        } catch {
            print("⚠️ Failed to refresh friend requests: \(error)")
        }
    }
    
    /// Refresh accepted friends list from real API
    func refreshFriends(guildId: UUID? = nil, rlAppState: RLAppState) async {
        isLoadingFriendsRL = true
        defer { isLoadingFriendsRL = false }
        
        do {
            let response = try await rlAppState.fetchFriends(guildId: guildId)
            await MainActor.run {
                self.friendsRL = response.friends
                self.friendsRLTotalCount = response.totalCount
                self.friendsRLOnlineCount = response.onlineCount
            }
        } catch is CancellationError {
            print("📋 refreshFriends: Cancelled")
        } catch let error as APIError {
            if case .networkError(let message) = error, message == "cancelled" {
                print("📋 refreshFriends: Network cancelled")
                return
            }
            print("⚠️ Failed to refresh friends: \(error)")
        } catch {
            print("⚠️ Failed to refresh friends: \(error)")
        }
    }

    /// Update a guild member in cache and return the updated member
    @discardableResult
    func updateGuildMember(
        membershipId: UUID,
        transform: (RLGuildMemberDTO) -> RLGuildMemberDTO
    ) -> RLGuildMemberDTO? {
        guard let index = guildMembers.firstIndex(where: { $0.membershipId == membershipId }) else {
            return nil
        }
        let updated = transform(guildMembers[index])
        guildMembers[index] = updated
        return updated
    }
    
    /// Refresh only notifications - use this in NotificationsView
    func refreshNotifications(guildId: UUID, appState: AppState) async {
        do {
            let fetched = try await appState.fetchGuildUserNotifications(guildId: guildId)
            await MainActor.run {
                self.userNotifications = fetched
            }
        } catch is CancellationError {
            print("📋 refreshNotifications: Cancelled")
        } catch {
            print("⚠️ Failed to refresh notifications: \(error)")
        }
    }
    
    /// Refresh only statistics - use this in StatisticsView
    func refreshStatistics(guildId: UUID, rlAppState: RLAppState) async {
        do {
            let fetched = try await rlAppState.fetchGuildStatistics(guildId: guildId)
            await MainActor.run {
                self.statistics = fetched
            }
            print("📊 refreshStatistics: Refreshed successfully")
        } catch is CancellationError {
            print("📊 refreshStatistics: Cancelled")
        } catch {
            print("⚠️ Failed to refresh statistics: \(error)")
        }
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
        guildMembers = []
        guildMembersTotalCount = 0
        guildMembersOnlineCount = 0
        isLoadingGuildMembers = false
        pendingFriendRequestsIncoming = []
        pendingFriendRequestsOutgoing = []
        isLoadingFriendRequests = false
        friendsRL = []
        friendsRLTotalCount = 0
        friendsRLOnlineCount = 0
        isLoadingFriendsRL = false
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
    func loadCurrentUserProfile(appState: AppState, rlAppState: RLAppState) async -> (
        profile: RLUserProfileDTO?,
        statistics: RLUserGlobalStatisticsDTO?,
        userMarkers: [TopMarkerDTO],
        awards: [RLUserAwardDTO],
        awardsSummary: RLAwardsSummaryDTO?
    ) {
        guard let userId = rlAppState.currentUser?.id else {
            return (nil, nil, [], [], nil)
        }
        
        do {
            async let fullProfileTask = rlAppState.fetchCurrentUserFullProfile(guildId: rlAppState.currentGuild?.id)
            async let markersTask = appState.fetchUserMarkers(userId: userId)
            async let awardsTask = rlAppState.fetchCurrentUserAwards(guildId: rlAppState.currentGuild?.id)
            async let awardsSummaryTask = rlAppState.fetchCurrentUserAwardsSummary(guildId: rlAppState.currentGuild?.id)
            
            let (fullProfile, markers, awards, awardsSummary) = try await (
                fullProfileTask,
                markersTask,
                awardsTask,
                awardsSummaryTask
            )
            
            return (fullProfile.profile, fullProfile.statistics, markers, awards, awardsSummary)
            
        } catch {
            print("⚠️ Failed to load current user profile: \(error)")
            return (nil, nil, [], [], nil)
        }
    }
    
    /// Load profile data for a guild member (uses real API where available)
    func loadMemberProfile(
        member: RLGuildMemberDTO,
        appState: AppState,
        rlAppState: RLAppState,
        guildId: UUID
    ) async -> (
        profile: RLUserProfileDTO?,
        statistics: RLUserGlobalStatisticsDTO?,
        userMarkers: [TopMarkerDTO],
        awards: [RLUserAwardDTO],
        awardsSummary: RLAwardsSummaryDTO?
    ) {
        do {
            async let fullProfileTask = rlAppState.fetchUserFullProfile(userId: member.userId, guildId: guildId)
            async let markersTask = appState.fetchUserMarkers(userId: member.userId, limit: 10)
            
            let (fullProfile, markers) = try await (fullProfileTask, markersTask)
            
            let awards = SampleData.memberAwards.map { RLUserAwardDTO.fromLegacy($0, membershipId: member.membershipId, guildId: guildId) }
            let awardsSummary = RLAwardsSummaryDTO.fromLegacy(SampleData.awardsSummary)
            
            return (fullProfile.profile, fullProfile.statistics, markers, awards, awardsSummary)
            
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

// MARK: - Guild Member Updates

extension RLGuildMemberDTO {
    func updating(
        isFriend: Bool? = nil,
        friendshipStatus: String? = nil,
        isBlocked: Bool? = nil,
        isBlockedBy: Bool? = nil
    ) -> RLGuildMemberDTO {
        RLGuildMemberDTO(
            membershipId: membershipId,
            role: role,
            reputation: reputation,
            contributionScore: contributionScore,
            dateJoined: dateJoined,
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            isOnline: isOnline,
            globalReputation: globalReputation,
            isFriend: isFriend ?? self.isFriend,
            friendshipStatus: friendshipStatus ?? self.friendshipStatus,
            isBlocked: isBlocked ?? self.isBlocked,
            isBlockedBy: isBlockedBy ?? self.isBlockedBy
        )
    }
}









