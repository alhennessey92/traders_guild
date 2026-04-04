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
    private struct TopMarkersCacheEntry {
        let response: RLTopMarkersListDTO
        let refreshedAt: Date
    }

    private struct TopMarkersCacheContext {
        let guildId: UUID
        let timeWindowHours: Int
    }

    private static let topMarkersCacheTTL: TimeInterval = 300
    private static let notificationRealtimeInsertWindow: TimeInterval = 1.5
    
    
    private weak var rlAppState: RLAppState?
    
    // ================================================================================================
    // MARK: - Published State
    // ================================================================================================
    
    // NEW: Using RLGuildAnnouncementWithAuthorDTO for announcements (combined response from backend)
    @Published var announcements: [RLGuildAnnouncementWithAuthorDTO] = []
    // NEW: Using RLGuildEventWithAuthorDTO for events (combined response from backend)
    @Published var upcomingEvents: [RLGuildEventWithAuthorDTO] = []
    
    
    @Published var userNotifications: [RLNotificationDTO] = []
    @Published var notificationStats: RLNotificationStatsDTO?
    @Published var statistics: RLGuildStatisticsResponse?
    
    // New: backend-driven guild members
    @Published var guildMembers: [RLGuildMemberDTO] = []
    @Published var guildMembersTotalCount: Int = 0
    @Published var guildMembersOnlineCount: Int = 0
    @Published var isLoadingGuildMembers: Bool = false
    
    // Pending friend requests (real API)
    @Published var pendingFriendRequestsIncoming: [RLFriendRequestIncomingDTO] = []
    @Published var pendingFriendRequestsOutgoing: [RLFriendRequestOutgoingDTO] = []
    @Published var isLoadingFriendRequests: Bool = false
    
    // Accepted friends (real API)
    @Published var friendsRL: [RLFriendDTO] = []
    @Published var friendsRLTotalCount: Int = 0
    @Published var friendsRLOnlineCount: Int = 0
    @Published var isLoadingFriendsRL: Bool = false

    // Global leaderboard (not yet implemented)
    @Published var globalLeaderboard: [RLGuildMemberDTO] = []

    // Accuracy leaderboard
    @Published var accuracyLeaderboard: [RLAccuracyLeaderboardMemberDTO] = []
    @Published var isLoadingAccuracyLeaderboard: Bool = false

    @Published var guildTradingWatchlist: [RLTradingSymbolDTO] = []
    @Published var personalTradingWatchlist: [RLTradingSymbolDTO] = []
    @Published var globalTradingSymbols: [RLTradingSymbolDTO] = []
    
    @Published var isLoading: Bool = false
    @Published var lastRefresh: Date?
    
    private var currentGuildId: UUID?
    private var cancellables = Set<AnyCancellable>()
    private weak var rlAppStateRef: RLAppState?

    
    // ================================================================================================
    // MARK: - Top Markers State
    // ================================================================================================
    
    @Published var trendingMarkers: [RLTopMarkerDTO] = []
    @Published var symbolGroupedMarkers: [String: [RLTopMarkerDTO]] = [:]
    @Published var followingMarkers: [RLTopMarkerDTO] = []
    @Published var myMarkers: [RLTopMarkerDTO] = []
    @Published var topMarkersLastRefresh: Date?
    @Published var isLoadingTopMarkers: Bool = false
    @Published var topMarkersCurrentTimeWindowHours: Int?
    
    private var topMarkersCache: [String: TopMarkersCacheEntry] = [:]
    private var currentTopMarkersContext: TopMarkersCacheContext?
    private var notificationResyncTask: Task<Void, Never>?

    var notificationRefreshActionOverride: (() async -> Void)?
    var notificationResyncDebounceNanoseconds: UInt64 = 350_000_000
    private(set) var lastNotificationSyncAt: Date?
    private(set) var lastNotificationStatsUpdateAt: Date?
    private(set) var lastNotificationForegroundSyncAt: Date?
    private(set) var lastRealtimeNotificationInsertAt: Date?
    private(set) var pendingNotificationCatchUpRefresh = false


    // ================================================================================================
    // MARK: - INIT
    // ================================================================================================
    init() {
        setupNotificationListener()
    }


    // ================================================================================================
    // MARK: - Navigation State
    // ================================================================================================
    

    /// When set, parent views should navigate to this marker on the chart
    /// After handling navigation, parent should set this back to nil
    @Published var pendingMarkerNavigation: RLTopMarkerDTO? = nil
    
    /// Request navigation to a specific marker
    /// Parent views observe `pendingMarkerNavigation` and handle the actual navigation
    func requestNavigationToMarker(_ marker: RLTopMarkerDTO) {
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

        // Listen for member role changes to update guild members list in real-time
        NotificationCenter.default.publisher(for: .guildMemberRoleChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let userId = userInfo["userId"] as? UUID,
                      let newRole = userInfo["newRole"] as? String else { return }

                if let index = self.guildMembers.firstIndex(where: { $0.userId == userId }) {
                    self.guildMembers[index] = self.guildMembers[index].withRole(newRole)
                    print("🏰 [LeftDrawer] Updated member role: \(userId) → \(newRole)")
                }
            }
            .store(in: &cancellables)
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
            let status = RealTimeService.shared.connectionStatus
            let isTransient = status == .connected || status == .connecting
            if isTransient {
                return
            }
            guildMembers = guildMembers.map { $0.withOnlineStatus(false) }
            guildMembersOnlineCount = 0
            friendsRL = friendsRL.map { $0.withOnlineStatus(false) }
            friendsRLOnlineCount = 0
            return
        }

        guildMembers = guildMembers.map { member in
            let isOnline = presenceMap[member.userId] ?? false
            return member.isOnline == isOnline ? member : member.withOnlineStatus(isOnline)
        }
        guildMembersOnlineCount = guildMembers.filter { $0.isOnline }.count
        
        friendsRL = friendsRL.map { friend in
            let isOnline = presenceMap[friend.userId] ?? false
            return friend.isOnline == isOnline ? friend : friend.withOnlineStatus(isOnline)
        }
        friendsRLOnlineCount = friendsRL.filter { $0.isOnline }.count
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
    func markNotificationAsRead(notificationId: UUID, rlAppState: RLAppState? = nil) {
        guard let index = userNotifications.firstIndex(where: { $0.id == notificationId }) else {
            print("⚠️ Notification not found in cache: \(notificationId)")
            return
        }
        
        // Update local cache immediately (optimistic)
        var updated = userNotifications[index]
        updated.isRead = true
        userNotifications[index] = updated
        applyLocalNotificationRead(notification: updated)
        print("✅ Updated notification cache: \(notificationId) -> isRead: true")
        
        // Fire-and-forget API call
        Task {
            await rlAppState?.markNotificationsAsRead(ids: [notificationId])
        }
    }

    func applyNotificationStats(_ stats: RLNotificationStatsDTO, updatedAt: Date = Date()) {
        notificationStats = stats
        rlAppStateRef?.notificationStats = stats
        lastNotificationStatsUpdateAt = updatedAt
    }

    private func applyLocalNotificationRead(notification: RLNotificationDTO) {
        guard let currentStats = notificationStats else { return }
        let unreadCount = max(currentStats.unreadCount - 1, 0)
        let personalCount = notification.isPersonal
            ? max(currentStats.personalCount - 1, 0)
            : currentStats.personalCount
        let guildCount = notification.isPersonal
            ? currentStats.guildCount
            : max(currentStats.guildCount - 1, 0)
        applyNotificationStats(
            RLNotificationStatsDTO(
                totalCount: currentStats.totalCount,
                unreadCount: unreadCount,
                personalCount: personalCount,
                guildCount: guildCount
            )
        )
        markNotificationListSynced()
    }

    private func applyNotificationReadEvent(_ payload: RLNotificationReadEventDTO) {
        let ids = Set(payload.notificationIds)
        var newlyRead: [RLNotificationDTO] = []
        userNotifications = userNotifications.map { notification in
            guard ids.contains(notification.id), !notification.isRead else { return notification }
            var updated = notification
            updated.isRead = true
            newlyRead.append(updated)
            return updated
        }

        guard !newlyRead.isEmpty, let currentStats = notificationStats else { return }
        let personalReads = newlyRead.filter(\.isPersonal).count
        let guildReads = newlyRead.count - personalReads
        applyNotificationStats(
            RLNotificationStatsDTO(
                totalCount: currentStats.totalCount,
                unreadCount: max(currentStats.unreadCount - newlyRead.count, 0),
                personalCount: max(currentStats.personalCount - personalReads, 0),
                guildCount: max(currentStats.guildCount - guildReads, 0)
            )
        )
        markNotificationListSynced()
    }

    private func applyNotificationDeletedEvent(_ payload: RLNotificationDeletedEventDTO) {
        let ids = Set(payload.notificationIds)
        userNotifications.removeAll { ids.contains($0.id) }
        markNotificationListSynced()
    }

    var hasUnreadAnnouncements: Bool {
        announcements.contains { !$0.isRead }
    }

    var hasUnreadEvents: Bool {
        upcomingEvents.contains { !$0.isRead }
    }

    var hasUnreadNotifications: Bool {
        if let notificationStats {
            return notificationStats.unreadCount > 0
        }
        return userNotifications.contains { !$0.isRead }
    }
    
    // ================================================================================================
    // MARK: - Preload Data
    // ================================================================================================
    
    /// Preload all drawer data in parallel - each fetch is independent (failures don't cascade)
    func preloadData(for guildId: UUID, rlAppState: RLAppState) async {
        guard shouldRefresh(for: guildId) else {
            print("📋 preloadData: Skipping refresh (cache still valid)")
            return
        }
        
        print("📋 preloadData: Starting for guild \(guildId)")
        
        isLoading = true
        defer { isLoading = false }
        
        // Capture userId for personal watchlist
        let userId = rlAppState.currentUser?.id
        
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
            
            // Guild members (real API)
            group.addTask {
                do {
                    let response = try await rlAppState.fetchGuildMembers(guildId: guildId)
                    await MainActor.run {
                        self.guildMembers = response.members
                        self.guildMembersTotalCount = response.totalCount
                        self.guildMembersOnlineCount = response.onlineCount
                        self.applyPresenceUpdates(rlAppState.presenceByUserId)
                    }
                } catch is CancellationError {
                    // Silent
                } catch {
                    print("⚠️ Failed to fetch guild members: \(error)")
                }
            }
            
            // Guild Trading Watchlist
            group.addTask {
                do {
                    let fetched = try await rlAppState.realApi.getGuildWatchlist(guildId: guildId)
                    await MainActor.run {
                        self.guildTradingWatchlist = fetched.symbols.map { $0.symbol }
                    }
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
                        let fetched = try await rlAppState.realApi.getPersonalWatchlist()
                        await MainActor.run {
                            self.personalTradingWatchlist = fetched.symbols.map { $0.symbol }
                        }
                    } catch is CancellationError {
                        // Silent
                    } catch {
                        print("⚠️ Failed to fetch personal trading watchlist: \(error)")
                    }
                }
            }
            
            // Notifications
            group.addTask {
                await self.fetchNotifications(rlAppState: rlAppState)

                // do {
                //     let fetched = try await appState.fetchGuildUserNotifications(guildId: guildId)
                //     await MainActor.run { self.userNotifications = fetched }
                // } catch is CancellationError {
                //     // Silent
                // } catch {
                //     print("⚠️ Failed to fetch notifications: \(error)")
                // }
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
    // func preloadData(for guildId: UUID, appState: AppState) async {
    //     // Skip announcements and events fetch in legacy mode (will be empty)
    //     guard shouldRefresh(for: guildId) else { return }
        
    //     isLoading = true
    //     defer { isLoading = false }
        
    //     let userId = appState.currentUser?.id
        
    //     // OLD: These all use old appState (events removed - now requires rlAppState)
    //     async let membersTask = appState.fetchGuildMembers(guildId: guildId)
    //     async let watchlistTask = appState.fetchGuildWatchlist(guildId: guildId)
    //     async let tradingWatchlistTask = appState.fetchGuildTradingWatchlist(guildId: guildId)
    //     async let userNotificationsTask = rlAppState.fetchNotifications(page: 1, pageSize: 50)
    //     //async let statisticsTask = appState.fetchGuildStatistics(guildId: guildId)
        
    //     async let personalTradingWatchlistTask: [TradingSymbolDTO] = {
    //         guard let id = userId else { return [] }
    //         return (try? await appState.fetchPersonalTradingWatchlist(userId: id)) ?? []
    //     }()
        
    //     do {
    //         let (fetchedMembers, fetchedWatchlist, fetchedTradingWatchlist, fetchedPersonalTradingWatchlist, fetchedUserNotifications) = try await (
    //             membersTask,
    //             watchlistTask,
    //             tradingWatchlistTask,
    //             personalTradingWatchlistTask,
    //             userNotificationsTask,
    //             //statisticsTask
    //         )
            
    //         // Don't touch announcements or events in legacy mode - they require rlAppState
    //         self.members = fetchedMembers
    //         self.watchlist = fetchedWatchlist
    //         self.guildTradingWatchlist = fetchedTradingWatchlist
    //         self.personalTradingWatchlist = fetchedPersonalTradingWatchlist
    //         self.userNotifications = fetchedNotificationsResult.notifications
    //         //self.statistics = fetchedStatistics
    //         self.lastRefresh = Date()
    //         self.currentGuildId = guildId
            
    //     } catch is CancellationError {
    //         return
    //     } catch {
    //         print("⚠️ Failed to preload drawer data: \(error)")
    //         appState.showError(error, title: "Failed to load data", style: .toast)
    //     }
    // }
    
    /// Manual refresh - forces reload of ALL data
    /// NOTE: Requires rlAppState for announcements
    func refresh(for guildId: UUID, rlAppState: RLAppState) async {
        lastRefresh = nil
        await preloadData(for: guildId, rlAppState: rlAppState)
    }
    
    /// Legacy refresh - for backwards compatibility (doesn't refresh announcements)
    // func refresh(for guildId: UUID, appState: AppState) async {
    //     lastRefresh = nil
    //     await preloadData(for: guildId, appState: appState)
    // }
    

    
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
                self.applyPresenceUpdates(rlAppState.presenceByUserId)
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
                self.applyPresenceUpdates(rlAppState.presenceByUserId)
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

    /// Refresh the accuracy leaderboard for the current guild
    func refreshAccuracyLeaderboard(guildId: UUID, rlAppState: RLAppState) async {
        isLoadingAccuracyLeaderboard = true
        defer { isLoadingAccuracyLeaderboard = false }

        do {
            let response = try await rlAppState.realApi.getGuildAccuracyLeaderboard(guildId: guildId)
            await MainActor.run {
                self.accuracyLeaderboard = response.members
            }
        } catch is CancellationError {
            print("📋 refreshAccuracyLeaderboard: Cancelled")
        } catch {
            print("⚠️ Failed to refresh accuracy leaderboard: \(error)")
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
    func refreshNotifications(rlAppState: RLAppState) async {
       do {
           let result = try await rlAppState.fetchNotifications(page: 1, pageSize: 50)
           let stats = try await rlAppState.fetchNotificationStats()
           await MainActor.run {
               self.userNotifications = result.notifications
               self.applyNotificationStats(stats)
               self.markNotificationListSynced()
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
        guildTradingWatchlist = []
        personalTradingWatchlist = []
        userNotifications = []
        notificationStats = nil
        rlAppStateRef?.notificationStats = nil
        notificationResyncTask?.cancel()
        notificationResyncTask = nil
        lastNotificationSyncAt = nil
        lastNotificationStatsUpdateAt = nil
        lastNotificationForegroundSyncAt = nil
        lastRealtimeNotificationInsertAt = nil
        pendingNotificationCatchUpRefresh = false
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
        globalLeaderboard = []
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
    func loadTopMarkers(
        for guildId: UUID,
        rlAppState: RLAppState,
        timeWindowHours: Int = 48,
        updateCurrentState: Bool = true
    ) async {
        let cacheKey = topMarkersCacheKey(guildId: guildId, timeWindowHours: timeWindowHours)
        if let entry = topMarkersCache[cacheKey],
           Date().timeIntervalSince(entry.refreshedAt) < Self.topMarkersCacheTTL {
            if updateCurrentState {
                applyTopMarkersResponse(
                    entry.response,
                    refreshedAt: entry.refreshedAt,
                    guildId: guildId,
                    timeWindowHours: timeWindowHours
                )
            }
            return
        }

        if updateCurrentState {
            isLoadingTopMarkers = true
        }
        defer {
            if updateCurrentState {
                isLoadingTopMarkers = false
            }
        }

        do {
            let response = try await rlAppState.realApi.getTopMarkers(guildId: guildId, timeWindowHours: timeWindowHours)
            let refreshedAt = Date()
            topMarkersCache[cacheKey] = TopMarkersCacheEntry(response: response, refreshedAt: refreshedAt)
            if updateCurrentState {
                applyTopMarkersResponse(
                    response,
                    refreshedAt: refreshedAt,
                    guildId: guildId,
                    timeWindowHours: timeWindowHours
                )
            }

            print("✅ Loaded top markers - Trending: \(response.trending.count), Symbols: \(response.bySymbol.count), Following: \(response.following.count), Mine: \(response.mine.count)")

        } catch is CancellationError {
            return
        } catch {
            print("⚠️ Failed to load top markers: \(error)")
        }
    }

    /// Force refresh top markers (bypasses cache)
    func refreshTopMarkers(for guildId: UUID, rlAppState: RLAppState, timeWindowHours: Int = 48) async {
        topMarkersCache.removeValue(forKey: topMarkersCacheKey(guildId: guildId, timeWindowHours: timeWindowHours))
        if currentTopMarkersContext?.guildId == guildId,
           currentTopMarkersContext?.timeWindowHours == timeWindowHours {
            topMarkersLastRefresh = nil
        }
        await loadTopMarkers(for: guildId, rlAppState: rlAppState, timeWindowHours: timeWindowHours)
    }

    func prefetchTopMarkers(
        for guildId: UUID,
        rlAppState: RLAppState,
        timeWindowHoursList: [Int]
    ) async {
        var seen = Set<Int>()
        for hours in timeWindowHoursList where seen.insert(hours).inserted {
            await loadTopMarkers(
                for: guildId,
                rlAppState: rlAppState,
                timeWindowHours: hours,
                updateCurrentState: false
            )
        }
    }

    func topMarkersResponse(for guildId: UUID, timeWindowHours: Int) -> RLTopMarkersListDTO? {
        if currentTopMarkersContext?.guildId == guildId,
           currentTopMarkersContext?.timeWindowHours == timeWindowHours {
            return RLTopMarkersListDTO(
                trending: trendingMarkers,
                bySymbol: symbolGroupedMarkers,
                following: followingMarkers,
                mine: myMarkers,
                lastUpdated: topMarkersLastRefresh ?? Date()
            )
        }

        return topMarkersCache[topMarkersCacheKey(guildId: guildId, timeWindowHours: timeWindowHours)]?.response
    }
    
    /// Toggle like on a marker and update local cache
    func toggleMarkerLike(markerId: UUID, rlAppState: RLAppState) async {
        do {
            let result = try await rlAppState.realApi.toggleMarkerLike(guildId: rlAppState.currentGuild?.id ?? UUID(), markerId: markerId)
            
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
        topMarkersCache.removeAll()
        trendingMarkers = []
        symbolGroupedMarkers = [:]
        followingMarkers = []
        myMarkers = []
        topMarkersLastRefresh = nil
        topMarkersCurrentTimeWindowHours = nil
        currentTopMarkersContext = nil
    }
    

    

    // ================================================================================================
    // MARK: - Notification Listener
    // ================================================================================================

    func fetchNotifications(rlAppState: RLAppState) async {
        do {
            let result = try await rlAppState.fetchNotifications(page: 1, pageSize: 50)
            await MainActor.run {
                self.userNotifications = result.notifications
                self.markNotificationListSynced()
            }
            // Also fetch stats for badges
            let stats = try await rlAppState.fetchNotificationStats()
            await MainActor.run {
                self.applyNotificationStats(stats)
            }
        } catch is CancellationError {
            print("📋 fetchNotifications: Cancelled")
        } catch {
            print("⚠️ Failed to fetch notifications: \(error)")
        }
    }


    
    func setupNotificationListener() {
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketNotification(message)
            }
            .store(in: &cancellables)
    }

    private let notificationDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private func handleWebSocketNotification(_ message: WSIncomingMessage) {
        handleTopMarkersRealtimeUpdate(message)

        switch WSMessageType(rawValue: message.type) {
        case .notification:
            // New notification received in real-time
            // Use message.payload(as:) which uses the flexible custom date decoder
            // instead of JSONSerialization which crashes on AnyCodable payloads
            guard let notification = message.payload(as: RLNotificationDTO.self) else {
                print("⚠️ Failed to decode notification payload")
                return
            }

            handleRealtimeNotificationInsert(notification)
            if notification.type == .markerResult {
                NotificationCenter.default.post(
                    name: .markerActivityDidChange,
                    object: nil,
                    userInfo: ["guildId": rlAppStateRef?.currentGuild?.id as Any]
                )
            }

        case .notificationStatsUpdate:
            // Badge counts updated
            guard let stats = message.payload(as: RLNotificationStatsDTO.self) else { return }
            handleNotificationStatsUpdate(stats)

        case .notificationRead:
            guard let payload = message.payload(as: RLNotificationReadEventDTO.self) else {
                print("⚠️ Failed to decode notification_read payload")
                return
            }
            applyNotificationReadEvent(payload)

        case .notificationDeleted:
            guard let payload = message.payload(as: RLNotificationDeletedEventDTO.self) else {
                print("⚠️ Failed to decode notification_deleted payload")
                return
            }
            applyNotificationDeletedEvent(payload)

        case .reputationUpdate:
            // Real-time reputation change
            guard let update = message.payload(as: RLReputationUpdatePayload.self) else {
                print("⚠️ Failed to decode reputation update payload")
                return
            }
            handleReputationUpdate(update)

        case .accuracyUpdate:
            // Real-time trading accuracy change (prediction win/loss)
            guard let update = message.payload(as: RLAccuracyUpdatePayload.self) else {
                print("⚠️ Failed to decode accuracy update payload")
                return
            }
            handleAccuracyUpdate(update)

        case .memberPerformanceUpdated:
            guard let update = message.payload(as: RLGuildMemberPerformanceUpdatePayload.self) else {
                print("⚠️ Failed to decode member performance payload")
                return
            }
            handleMemberPerformanceUpdate(update)

        default:
            break
        }
    }

    func handleRealtimeNotificationInsert(_ notification: RLNotificationDTO) {
        if !userNotifications.contains(where: { $0.id == notification.id }) {
            userNotifications.insert(notification, at: 0)
            lastRealtimeNotificationInsertAt = Date()
            markNotificationListSynced(at: lastRealtimeNotificationInsertAt ?? Date())
            print("🔔 New real-time notification: \(notification.displayTitle)")
        }
    }

    func handleNotificationStatsUpdate(_ stats: RLNotificationStatsDTO) {
        let previousUnreadCount = notificationStats?.unreadCount ?? 0
        let receivedAt = Date()
        applyNotificationStats(stats, updatedAt: receivedAt)
        print("📊 Notification stats updated: \(stats.unreadCount) unread")

        guard stats.unreadCount > previousUnreadCount else { return }
        guard !didReceiveRealtimeNotificationRecently(reference: receivedAt) else { return }
        scheduleNotificationCatchUpRefresh(reason: "stats_increase_without_realtime_notification")
    }

    func handleAppDidBecomeActive(rlAppState: RLAppState) async {
        let previousUnreadCount = notificationStats?.unreadCount ?? rlAppState.notificationStats?.unreadCount ?? 0

        do {
            let stats = try await rlAppState.fetchNotificationStats()
            let syncAt = Date()
            await MainActor.run {
                self.applyNotificationStats(stats, updatedAt: syncAt)
                self.lastNotificationForegroundSyncAt = syncAt
            }

            if stats.unreadCount > previousUnreadCount
                || pendingNotificationCatchUpRefresh
                || isNotificationListOlder(than: syncAt) {
                await refreshNotifications(rlAppState: rlAppState)
            }
        } catch is CancellationError {
            print("📋 handleAppDidBecomeActive: Cancelled")
        } catch {
            print("⚠️ Failed to sync notification stats on foreground: \(error)")
        }
    }

    func refreshNotificationsIfNeeded(rlAppState: RLAppState, force: Bool = false) async {
        guard force || shouldRefreshNotificationsOnOpen else { return }
        if let notificationRefreshActionOverride {
            await notificationRefreshActionOverride()
            markNotificationListSynced()
            return
        }
        await refreshNotifications(rlAppState: rlAppState)
    }

    private var shouldRefreshNotificationsOnOpen: Bool {
        if pendingNotificationCatchUpRefresh || lastNotificationSyncAt == nil {
            return true
        }

        let newestMetadataUpdate = [lastNotificationStatsUpdateAt, lastNotificationForegroundSyncAt]
            .compactMap { $0 }
            .max()

        guard let newestMetadataUpdate else { return false }
        return isNotificationListOlder(than: newestMetadataUpdate)
    }

    private func markNotificationListSynced(at date: Date = Date()) {
        lastNotificationSyncAt = date
        pendingNotificationCatchUpRefresh = false
    }

    private func isNotificationListOlder(than date: Date) -> Bool {
        guard let lastNotificationSyncAt else { return true }
        return lastNotificationSyncAt < date
    }

    private func didReceiveRealtimeNotificationRecently(reference: Date) -> Bool {
        guard let lastRealtimeNotificationInsertAt else { return false }
        return reference.timeIntervalSince(lastRealtimeNotificationInsertAt) <= Self.notificationRealtimeInsertWindow
    }

    private func scheduleNotificationCatchUpRefresh(reason: String) {
        pendingNotificationCatchUpRefresh = true
        notificationResyncTask?.cancel()

        let refreshOverride = notificationRefreshActionOverride
        let appState = rlAppStateRef
        let debounceNanoseconds = notificationResyncDebounceNanoseconds

        print("📋 Scheduling notification catch-up refresh (\(reason))")

        notificationResyncTask = Task { [weak self] in
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }

            guard let self, !Task.isCancelled else { return }

            if let refreshOverride {
                await refreshOverride()
                await MainActor.run {
                    self.markNotificationListSynced()
                }
                return
            }

            guard let appState else { return }
            await self.refreshNotifications(rlAppState: appState)
        }
    }

    private func handleTopMarkersRealtimeUpdate(_ message: WSIncomingMessage) {
        guard
            let channel = message.channel,
            channel.hasPrefix("guild:"),
            channel.hasSuffix(":markers"),
            let context = currentTopMarkersContext,
            let rlAppStateRef,
            let currentGuildId = rlAppStateRef.currentGuild?.id
        else {
            return
        }

        let expectedChannel = "guild:\(context.guildId.uuidString.lowercased()):markers"
        guard
            channel == expectedChannel,
            currentGuildId == context.guildId
        else {
            return
        }

        switch message.type {
        case "marker_created", "marker_updated", "marker_deleted", "tracking_state_changed":
            NotificationCenter.default.post(
                name: .markerActivityDidChange,
                object: nil,
                userInfo: ["guildId": context.guildId]
            )
            invalidateTopMarkersCache(guildId: context.guildId)
            Task { [weak self] in
                guard let self else { return }
                await self.loadTopMarkers(
                    for: context.guildId,
                    rlAppState: rlAppStateRef,
                    timeWindowHours: context.timeWindowHours
                )
                await self.prefetchTopMarkers(
                    for: context.guildId,
                    rlAppState: rlAppStateRef,
                    timeWindowHoursList: [24, 168, 720]
                )
            }
        default:
            break
        }
    }

    private func applyTopMarkersResponse(
        _ response: RLTopMarkersListDTO,
        refreshedAt: Date,
        guildId: UUID,
        timeWindowHours: Int
    ) {
        trendingMarkers = response.trending
        symbolGroupedMarkers = response.bySymbol
        followingMarkers = response.following
        myMarkers = response.mine
        topMarkersLastRefresh = refreshedAt
        topMarkersCurrentTimeWindowHours = timeWindowHours
        currentTopMarkersContext = TopMarkersCacheContext(
            guildId: guildId,
            timeWindowHours: timeWindowHours
        )
    }

    private func topMarkersCacheKey(guildId: UUID, timeWindowHours: Int) -> String {
        "\(guildId.uuidString.lowercased())|\(timeWindowHours)"
    }

    private func invalidateTopMarkersCache(guildId: UUID) {
        topMarkersCache = topMarkersCache.filter { key, _ in
            !key.hasPrefix(guildId.uuidString.lowercased())
        }
        topMarkersLastRefresh = nil
    }

    private func handleReputationUpdate(_ update: RLReputationUpdatePayload) {
        print("⭐ Reputation update: \(update.eventType) \(update.pointsFormatted) pts → guild:\(update.newGuildReputation) global:\(update.newGlobalReputation)")

        // Update in-memory state so UI reflects immediately
        if let membership = rlAppState?.currentMembership,
           update.guildId == membership.guildId.uuidString {
            rlAppState?.currentMembership = membership.withReputation(update.newGuildReputation)
        }

        if let currentUser = rlAppState?.currentUser,
           update.userId == currentUser.id.uuidString {
            rlAppState?.currentUser = currentUser.withGlobalReputation(update.newGlobalReputation)
        }

        // Notify observers for any reputation-dependent views
        NotificationCenter.default.post(
            name: .reputationDidUpdate,
            object: nil,
            userInfo: [
                "guildId": update.guildId,
                "newGuildReputation": update.newGuildReputation,
                "newGlobalReputation": update.newGlobalReputation,
                "tierLevel": update.tierLevel,
                "tierChanged": update.tierChanged,
                "pointsAwarded": update.pointsAwarded,
            ]
        )
    }

    private func handleAccuracyUpdate(_ update: RLAccuracyUpdatePayload) {
        print("🎯 Accuracy update: \(update.eventType) \(update.resultDisplay) → accuracy:\(update.accuracyFormatted) streak:\(update.winStreak)")

        // Update current user's membership in app state so user bar (username · role · reputation · accuracy) updates without refetch
        if let membership = rlAppState?.currentMembership,
           update.guildId == membership.guildId.uuidString,
           update.userId == rlAppState?.currentUser?.id.uuidString {
            rlAppState?.currentMembership = membership.withReputation(membership.reputation, accuracyRate: update.newAccuracyRate)
        }
        rlAppState?.currentGlobalAccuracy = update.newGlobalAccuracy

        // Notify observers for any accuracy-dependent views
        NotificationCenter.default.post(
            name: .accuracyDidUpdate,
            object: nil,
            userInfo: [
                "guildId": update.guildId,
                "newAccuracyRate": update.newAccuracyRate,
                "newGlobalAccuracy": update.newGlobalAccuracy,
                "totalPredictions": update.totalPredictions,
                "successfulPredictions": update.successfulPredictions,
                "winStreak": update.winStreak,
                "isWin": update.isWin,
            ]
        )
    }

    private func handleMemberPerformanceUpdate(_ update: RLGuildMemberPerformanceUpdatePayload) {
        guard
            let guildId = UUID(uuidString: update.guildId),
            let userId = UUID(uuidString: update.userId),
            let membershipId = UUID(uuidString: update.membershipId)
        else {
            return
        }

        if let index = guildMembers.firstIndex(where: { $0.membershipId == membershipId || $0.userId == userId }) {
            guildMembers[index] = guildMembers[index].withPerformance(
                guildReputation: update.newGuildReputation,
                accuracyRate: update.newAccuracyRate,
                globalReputation: update.newGlobalReputation
            )
        }

        if let index = friendsRL.firstIndex(where: { $0.userId == userId }) {
            friendsRL[index] = friendsRL[index].withGlobalReputation(update.newGlobalReputation)
        }

        if let rlAppState = rlAppStateRef {
            if let currentUser = rlAppState.currentUser, currentUser.id == userId {
                rlAppState.currentUser = currentUser.withGlobalReputation(update.newGlobalReputation)
                rlAppState.currentGlobalAccuracy = update.newGlobalAccuracy
            }

            if let membership = rlAppState.currentMembership, membership.id == membershipId {
                rlAppState.currentMembership = membership.withReputation(
                    update.newGuildReputation,
                    accuracyRate: update.newAccuracyRate
                )
            }

            if let currentGuild = rlAppState.currentGuild, currentGuild.id == guildId {
                rlAppState.currentGuild = currentGuild.withReputation(update.guildReputation)
            }

            rlAppState.userGuilds = rlAppState.userGuilds.map { guildWithMembership in
                guard guildWithMembership.guild.id == guildId else { return guildWithMembership }
                let updatedGuild = guildWithMembership.guild.withReputation(update.guildReputation)
                let updatedMembership = guildWithMembership.membership.id == membershipId
                    ? guildWithMembership.membership.withReputation(update.newGuildReputation, accuracyRate: update.newAccuracyRate)
                    : guildWithMembership.membership
                return RLGuildWithMembership(guild: updatedGuild, membership: updatedMembership)
            }
        }

        if update.eventType == "prediction_win" || update.eventType == "prediction_loss",
           let rlAppState = rlAppStateRef,
           rlAppState.currentGuild?.id == guildId {
            Task { [weak self] in
                guard let self else { return }
                await self.refreshAccuracyLeaderboard(guildId: guildId, rlAppState: rlAppState)
            }
        }

        NotificationCenter.default.post(
            name: .guildMemberPerformanceDidUpdate,
            object: nil,
            userInfo: [
                "guildId": guildId,
                "userId": userId,
                "membershipId": membershipId,
                "eventType": update.eventType,
                "newGuildReputation": update.newGuildReputation,
                "newGlobalReputation": update.newGlobalReputation,
                "newAccuracyRate": update.newAccuracyRate,
                "newGlobalAccuracy": update.newGlobalAccuracy,
                "totalPredictions": update.totalPredictions,
                "successfulPredictions": update.successfulPredictions,
                "guildReputation": update.guildReputation,
                "guildTotalPredictions": update.guildTotalPredictions,
                "guildCorrectPredictions": update.guildCorrectPredictions,
                "guildAverageAccuracy": update.guildAverageAccuracy,
            ]
        )
    }

    // ================================================================================================
    // MARK: - Load User Profiles Methods
    // ================================================================================================
    
    
    /// Load profile data for the current user
    func loadCurrentUserProfile(rlAppState: RLAppState) async -> (
        profile: RLUserProfileDTO?,
        statistics: RLUserGlobalStatisticsDTO?,
        userMarkers: [RLTopMarkerDTO],
        awards: [RLUserAwardDTO],
        awardsSummary: RLAwardsSummaryDTO?
    ) {
        guard let userId = rlAppState.currentUser?.id else {
            return (nil, nil, [], [], nil)
        }
        
        do {
            async let fullProfileTask = rlAppState.fetchCurrentUserFullProfile(guildId: rlAppState.currentGuild?.id)
            async let awardsTask = rlAppState.fetchCurrentUserAwards(guildId: rlAppState.currentGuild?.id)
            async let awardsSummaryTask = rlAppState.fetchCurrentUserAwardsSummary(guildId: rlAppState.currentGuild?.id)

            // Fetch user's markers from user-specific markers endpoint (no time window filter)
            var markers: [RLTopMarkerDTO] = []
            if let guildId = rlAppState.currentGuild?.id,
               let userId = rlAppState.currentUser?.id {
                do {
                    let userMarkers = try await rlAppState.realApi.getUserMarkers(guildId: guildId, userId: userId)
                    markers = userMarkers.mine
                } catch {
                    print("⚠️ Failed to load user markers: \(error)")
                }
            }

            let (fullProfile, awards, awardsSummary) = try await (
                fullProfileTask,
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
        rlAppState: RLAppState,
        guildId: UUID
    ) async -> (
        profile: RLUserProfileDTO?,
        statistics: RLUserGlobalStatisticsDTO?,
        userMarkers: [RLTopMarkerDTO],
        awards: [RLUserAwardDTO],
        awardsSummary: RLAwardsSummaryDTO?
    ) {
        do {
            async let fullProfileTask = rlAppState.fetchUserFullProfile(userId: member.userId, guildId: guildId)

            // Fetch member's markers from user-specific markers endpoint
            var markers: [RLTopMarkerDTO] = []
            do {
                let topMarkers = try await rlAppState.realApi.getUserMarkers(guildId: guildId, userId: member.userId)
                markers = topMarkers.mine
            } catch {
                print("⚠️ Failed to load member markers: \(error)")
            }

            let fullProfile = try await fullProfileTask
            
            // Awards will be loaded from backend API when needed
            // For now, use empty arrays - these should be fetched from rlAppState
            let awards: [RLUserAwardDTO] = []
            let awardsSummary = RLAwardsSummaryDTO(
                totalAwards: 0,
                totalPoints: 0,
                rarityBreakdown: [:],
                recentAwards: []
            )
            
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
        if announcements.isEmpty && upcomingEvents.isEmpty && guildMembers.isEmpty && userNotifications.isEmpty && statistics == nil && guildTradingWatchlist.isEmpty && personalTradingWatchlist.isEmpty {
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
        guildMembersOnlineCount
    }
    
    /// Has watchlist been loaded
    var hasWatchlist: Bool {
        !guildTradingWatchlist.isEmpty || !personalTradingWatchlist.isEmpty
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
            accuracyRate: accuracyRate,
            mutedUntil: mutedUntil,
            suspendedUntil: suspendedUntil,
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
