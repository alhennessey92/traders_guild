//
//  RLRightDrawerViewModel.swift
//  traders_guild
//
//  UPDATED: Uses RLAppState and new RL messaging DTOs.
//  Replaces old RightDrawerViewModel that used AppState.
//

import Foundation
import SwiftUI
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    private weak var messagingManager: RLMessagingManager?
    private weak var appState: RLAppState?
    private var isRefreshingFromRealtime = false
    
    init() {
        setupRealTimeListeners()
    }

    func configure(with messagingManager: RLMessagingManager) {
        self.messagingManager = messagingManager
    }

    /// Connects to RLAppState to observe the centralized presence map
    func configurePresence(with rlAppState: RLAppState) {
        self.appState = rlAppState

        // Observe the Source of Truth (no debounce so right drawer stays in sync with left drawer and online count)
        rlAppState.$presenceByUserId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presenceMap in
                self?.applyPresenceUpdates(presenceMap)
            }
            .store(in: &cancellables)

        // Apply initial state
        applyPresenceUpdates(rlAppState.presenceByUserId)

        // Listen for member role changes to update member list in real-time
        NotificationCenter.default.publisher(for: .guildMemberRoleChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let guildId = userInfo["guildId"] as? UUID,
                      let userId = userInfo["userId"] as? UUID,
                      let newRole = userInfo["newRole"] as? String,
                      guildId == self.currentGuildId else { return }

                // Update the member's role in the local list
                if let index = self.guildMembers.firstIndex(where: { $0.userId == userId }) {
                    self.guildMembers[index] = self.guildMembers[index].withRole(newRole)
                    print("🏰 [RightDrawer] Updated member role: \(userId) → \(newRole)")
                    // Rebuild DM sections so participant data (roles) propagate to the displayed thread lists
                    self.rebuildDMSections()
                }
            }
            .store(in: &cancellables)
    }
    
    // ================================================================================================
    // MARK: - Computed Properties
    // ================================================================================================
    
    var totalUnreadCount: Int {
        let chatroomUnread = guildChatrooms.reduce(0) { $0 + $1.unreadCount }
        let friendsUnread = guildFriends.reduce(0) { $0 + $1.unreadCount }
        let onlineUnread = guildOnlineNonFriends.reduce(0) { $0 + $1.unreadCount }
        let offlineUnread = guildOfflineNonFriends.reduce(0) { $0 + $1.unreadCount }
        return chatroomUnread + friendsUnread + onlineUnread + offlineUnread
    }
    
    var hasChatroomUnread: Bool { guildChatrooms.contains { $0.hasUnread } }
    
    var hasDMUnread: Bool {
        guildFriends.contains { $0.hasUnread } ||
        guildOnlineNonFriends.contains { $0.hasUnread } ||
        guildOfflineNonFriends.contains { $0.hasUnread }
    }

    var hasAnyDMThreads: Bool {
        !guildFriends.isEmpty || !guildOnlineNonFriends.isEmpty || !guildOfflineNonFriends.isEmpty
    }

    var memberFriends: [RLGuildMemberDTO] { guildMembers.filter { $0.isFriend } }

    var memberOnlineNonFriends: [RLGuildMemberDTO] { guildMembers.filter { !$0.isFriend && $0.isOnline } }

    var memberOfflineNonFriends: [RLGuildMemberDTO] { guildMembers.filter { !$0.isFriend && !$0.isOnline } }
    
    // ================================================================================================
    // MARK: - Cache Update Methods
    // ================================================================================================
    
    func updateDMUnreadCount(threadId: UUID, unreadCount: Int) {
        if let index = guildFriends.firstIndex(where: { $0.id == threadId }) {
            guildFriends[index] = guildFriends[index].withUnreadCount(unreadCount)
            return
        }
        if let index = guildOnlineNonFriends.firstIndex(where: { $0.id == threadId }) {
            guildOnlineNonFriends[index] = guildOnlineNonFriends[index].withUnreadCount(unreadCount)
            return
        }
        if let index = guildOfflineNonFriends.firstIndex(where: { $0.id == threadId }) {
            guildOfflineNonFriends[index] = guildOfflineNonFriends[index].withUnreadCount(unreadCount)
            return
        }
    }
    
    func markDMAsRead(threadId: UUID) {
        updateDMUnreadCount(threadId: threadId, unreadCount: 0)
    }
    
    func updateChatroomUnreadCount(chatroomId: UUID, unreadCount: Int) {
        guard let index = guildChatrooms.firstIndex(where: { $0.id == chatroomId }) else { return }
        guildChatrooms[index] = guildChatrooms[index].withUnreadCount(unreadCount)
    }
    
    func markChatroomAsRead(chatroomId: UUID) {
        updateChatroomUnreadCount(chatroomId: chatroomId, unreadCount: 0)
    }
    
    // ================================================================================================
    // MARK: - Preload Data
    // ================================================================================================
    
    func preloadData(for guildId: UUID, appState: RLAppState) async {
        guard shouldRefresh(for: guildId) else {
            // Even if not refreshing API data, ensure we are subscribed to channels
            subscribeToAllChannels(guildId: guildId)
            return
        }
        self.appState = appState
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await appState.fetchGuildMessagingData(guildId: guildId)
            var visibleFriends = data.friendDms.filter { !isThreadBlocked($0) }
            var visibleOnline = data.onlineDms.filter { !isThreadBlocked($0) }
            var visibleOffline = data.offlineDms.filter { !isThreadBlocked($0) }
            if visibleFriends.isEmpty && visibleOnline.isEmpty && visibleOffline.isEmpty,
               !(data.friendDms.isEmpty && data.onlineDms.isEmpty && data.offlineDms.isEmpty) {
                // Fallback: avoid blank drawer if block flags are missing or stale.
                visibleFriends = data.friendDms
                visibleOnline = data.onlineDms
                visibleOffline = data.offlineDms
            }
            
            self.guildChatrooms = data.chatrooms
            self.guildFriends = visibleFriends
            self.guildOnlineNonFriends = visibleOnline
            self.guildOfflineNonFriends = visibleOffline
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
            if data.chatrooms.isEmpty && data.friendDms.isEmpty && data.onlineDms.isEmpty && data.offlineDms.isEmpty {
                await preloadDataSeparate(for: guildId, appState: appState)
            }

            if guildMembers.isEmpty {
                await preloadMembersFallback(for: guildId, appState: appState)
            }
            
            // Re-apply any known presence state immediately
            applyPresenceUpdates(appState.presenceByUserId)
            
            // Rebuild lists and subscribe
            rebuildDMSections()
            subscribeToAllChannels(guildId: guildId)
            
        } catch {
            print("⚠️ Failed to preload drawer data: \(error)")
            await preloadDataSeparate(for: guildId, appState: appState)
        }
    }
    
    func preloadDataSeparate(for guildId: UUID, appState: RLAppState) async {
        guard shouldRefresh(for: guildId) else { return }
        self.appState = appState
        
        isLoading = true
        defer { isLoading = false }
        
        async let chatroomsTask = appState.fetchGuildChatrooms(guildId: guildId)
        async let threadsTask = appState.fetchDMThreads(guildId: guildId)
        
        do {
            let (chatrooms, threads) = try await (chatroomsTask, threadsTask)
            
            var visibleThreads = threads.filter { !isThreadBlocked($0) }
            if visibleThreads.isEmpty && !threads.isEmpty {
                // Fallback: avoid blank drawer if block flags are missing or stale.
                visibleThreads = threads
            }
            self.guildChatrooms = chatrooms
            self.guildFriends = visibleThreads.filter { $0.participant.isFriend }
            self.guildOnlineNonFriends = visibleThreads.filter { !$0.participant.isFriend && $0.participant.isOnline }
            self.guildOfflineNonFriends = visibleThreads.filter { !$0.participant.isFriend && !$0.participant.isOnline }
            
            self.lastRefresh = Date()
            self.currentGuildId = guildId
            
            if guildMembers.isEmpty {
                await preloadMembersFallback(for: guildId, appState: appState)
            }
            
            applyPresenceUpdates(appState.presenceByUserId)
            rebuildDMSections()
            subscribeToAllChannels(guildId: guildId)
            
        } catch {
            print("⚠️ Failed to preload drawer data separate: \(error)")
        }
    }
    
    func refresh(for guildId: UUID, appState: RLAppState) async {
        self.appState = appState
        lastRefresh = nil
        guildMembers = []
        await preloadData(for: guildId, appState: appState)
    }
    
    func clearCache() {
        guildChatrooms = []
        guildFriends = []
        guildOnlineNonFriends = []
        guildOfflineNonFriends = []
        guildMembers = []
        lastRefresh = nil
        currentGuildId = nil
    }

    private func preloadMembersFallback(for guildId: UUID, appState: RLAppState) async {
        do {
            let response = try await appState.fetchGuildMembers(guildId: guildId, limit: 200)
            guildMembers = response.members.filter { $0.userId != appState.currentUser?.id }
            rebuildDMSections()
        } catch {
            print("⚠️ Failed to load member fallback list: \(error)")
        }
    }

    func findDMThread(for userId: UUID) -> RLDMThreadDTO? {
        if let thread = guildFriends.first(where: { $0.participant.userId == userId }) { return thread }
        if let thread = guildOnlineNonFriends.first(where: { $0.participant.userId == userId }) { return thread }
        if let thread = guildOfflineNonFriends.first(where: { $0.participant.userId == userId }) { return thread }
        return nil
    }
    
    func findDMThread(id: UUID) -> RLDMThreadDTO? {
        if let thread = guildFriends.first(where: { $0.id == id }) { return thread }
        if let thread = guildOnlineNonFriends.first(where: { $0.id == id }) { return thread }
        if let thread = guildOfflineNonFriends.first(where: { $0.id == id }) { return thread }
        return nil
    }
    
    func findChatroom(id: UUID) -> RLGuildChatroomDTO? {
        return guildChatrooms.first(where: { $0.id == id })
    }
    
    private func shouldRefresh(for guildId: UUID) -> Bool {
        if currentGuildId != guildId { return true }
        if guildChatrooms.isEmpty && guildFriends.isEmpty && guildOnlineNonFriends.isEmpty && guildOfflineNonFriends.isEmpty { return true }
        guard let lastRefresh = lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300
    }
    
    // MARK: - RealTime Handling
    
    func setupRealTimeListeners() {
        // Only listen for messaging events. Presence is handled by binding to RLAppState.
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleRealTimeEvent(message)
            }
            .store(in: &cancellables)
    }
    
    func subscribeToAllChannels(guildId: UUID? = nil) {
        let activeGuildId = guildId ?? currentGuildId
        var channelsToSubscribe: [String] = []
        
        // Chatrooms
        channelsToSubscribe.append(contentsOf: guildChatrooms.map { MessagingChannel.chatroom($0.id).name })
        
        // Guild Presence (Critical for Online/Offline updates)
        if let gId = activeGuildId {
             channelsToSubscribe.append(MessagingChannel.guildPresence(gId).name)
        }
        
        // DMs (Friends + Others)
        let allDMs = guildFriends + guildOnlineNonFriends + guildOfflineNonFriends
        channelsToSubscribe.append(contentsOf: allDMs.map { MessagingChannel.dm($0.id).name })
        
        print("📜 [RightDrawer] Subscribing to \(channelsToSubscribe.count) channels")
        RealTimeService.shared.subscribe(to: channelsToSubscribe, owner: "rightDrawer")
    }
    
    private func handleRealTimeEvent(_ wsMessage: WSIncomingMessage) {
        guard let type = WSMessageType(rawValue: wsMessage.type) else { return }
        
        if type == .newMessage {
            if let chatroomMsg = wsMessage.payload(as: RLChatroomMessageDTO.self) {
                updateChatroomList(with: chatroomMsg)
            } else if let dmMsg = wsMessage.payload(as: RLDMMessageDTO.self) {
                if let senderId = wsMessage.userId,
                   let currentUserId = appState?.currentUser?.id.uuidString,
                   senderId == currentUserId {
                    return
                }
                updateDMList(with: dmMsg)
            }
        }
        // Removed presence handling here. It is handled by applyPresenceUpdates binding.
    }
    
    private func updateChatroomList(with message: RLChatroomMessageDTO) {
        if let index = guildChatrooms.firstIndex(where: { $0.id == message.chatroomId }) {
            if isActiveChatroom(message.chatroomId) { return }
            var chatroom = guildChatrooms[index]
            let newCount = chatroom.unreadCount + 1
            chatroom = chatroom.withUnreadCount(newCount)
            guildChatrooms[index] = chatroom
        }
    }
    
    private func updateDMList(with message: RLDMMessageDTO) {
        func updateArray(_ array: inout [RLDMThreadDTO]) -> Bool {
            if let index = array.firstIndex(where: { $0.id == message.dmId }) {
                if isActiveDM(message.dmId) { return true }
                var thread = array[index]
                if isThreadBlocked(thread) { 
                    array.remove(at: index)
                    return true
                }
                thread = thread.withUnreadCount(thread.unreadCount + 1)
                array.remove(at: index)
                array.insert(thread, at: 0)
                return true
            }
            return false
        }
        
        if !updateArray(&guildFriends) {
            if !updateArray(&guildOnlineNonFriends) {
                if !updateArray(&guildOfflineNonFriends) {
                    refreshIfMissingThread()
                }
            }
        }
    }
    
    private func refreshIfMissingThread() {
        guard !isRefreshingFromRealtime,
              let guildId = currentGuildId,
              let appState = appState else { return }
        isRefreshingFromRealtime = true
        Task { @MainActor in
            defer { isRefreshingFromRealtime = false }
            await refresh(for: guildId, appState: appState)
        }
    }

    /// Update the view model lists based on the Source of Truth from AppState
    private func applyPresenceUpdates(_ presenceMap: [UUID: Bool]) {
        // 1. Update fallback list
        if presenceMap.isEmpty {
            // If map is cleared (disconnect), mark all offline
            guildMembers = guildMembers.map { $0.withOnlineStatus(false) }
        } else {
            guildMembers = guildMembers.map { member in
                let isOnline = presenceMap[member.userId] ?? false
                return member.isOnline == isOnline ? member : member.withOnlineStatus(isOnline)
            }
        }
        
        // 2. Rebuild the DM sections to move people between online/offline lists
        rebuildDMSections()
    }

    private func rebuildDMSections() {
        let allThreads = guildFriends + guildOnlineNonFriends + guildOfflineNonFriends
        guard !allThreads.isEmpty else { return }
        
        // Determine who is a friend
        let friendUserIds: Set<UUID>
        if !guildMembers.isEmpty {
            friendUserIds = Set(guildMembers.filter { $0.isFriend }.map { $0.userId })
        } else {
            friendUserIds = Set(allThreads.filter { $0.participant.isFriend }.map { $0.participant.userId })
        }
        
        var newFriends: [RLDMThreadDTO] = []
        var newOnline: [RLDMThreadDTO] = []
        var newOffline: [RLDMThreadDTO] = []
        
        var visibleThreads = allThreads.filter { !isThreadBlocked($0) }
        if visibleThreads.isEmpty && !allThreads.isEmpty {
            visibleThreads = allThreads
        }
        for thread in visibleThreads {
            // "Hydrate" thread participant with latest status from guildMembers if available
            let updatedThread = updateThreadParticipant(from: thread)
            
            if friendUserIds.contains(updatedThread.participant.userId) {
                newFriends.append(updatedThread)
            } else if updatedThread.participant.isOnline {
                newOnline.append(updatedThread)
            } else {
                newOffline.append(updatedThread)
            }
        }
        
        guildFriends = newFriends
        guildOnlineNonFriends = newOnline
        guildOfflineNonFriends = newOffline
    }

    private func isThreadBlocked(_ thread: RLDMThreadDTO) -> Bool {
        thread.isBlocked || thread.participant.isBlocked || thread.participant.isBlockedBy
    }
    
    private func updateThreadParticipant(from thread: RLDMThreadDTO) -> RLDMThreadDTO {
        // Look up member in the updated list
        guard let member = guildMembers.first(where: { $0.userId == thread.participant.userId }) else {
            return thread
        }
        
        // Use JSON serialization to copy the thread with the updated participant data
        guard var dict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(thread)) as? [String: Any],
              let memberDict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(member)) as? [String: Any] else {
            return thread
        }
        
        dict["participant"] = memberDict
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLDMThreadDTO.self, from: data) else {
            return thread
        }
        
        return updated
    }

    private func isActiveChatroom(_ chatroomId: UUID) -> Bool {
        guard let messagingManager = messagingManager else { return false }
        if case .chatroom(let chatroom) = messagingManager.activeMessage {
            return chatroom.id == chatroomId
        }
        return false
    }

    private func isActiveDM(_ threadId: UUID) -> Bool {
        guard let messagingManager = messagingManager else { return false }
        if case .dmThread(let thread) = messagingManager.activeMessage {
            return thread.id == threadId
        }
        return false
    }
}

// Extensions for immutable copy with updates
extension RLDMThreadDTO {
    func withUnreadCount(_ count: Int) -> RLDMThreadDTO {
        guard var dict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any] else { return self }
        dict["unreadCount"] = count
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLDMThreadDTO.self, from: data) else { return self }
        return updated
    }
}

extension RLGuildChatroomDTO {
    func withUnreadCount(_ count: Int) -> RLGuildChatroomDTO {
        guard var dict = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as? [String: Any] else { return self }
        dict["unreadCount"] = count
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(RLGuildChatroomDTO.self, from: data) else { return self }
        return updated
    }
}

//extension RLGuildMemberDTO {
//    func withOnlineStatus(_ isOnline: Bool) -> RLGuildMemberDTO {
//        return RLGuildMemberDTO(
//            membershipId: membershipId,
//            role: role,
//            reputation: reputation,
//            contributionScore: contributionScore,
//            dateJoined: dateJoined,
//            userId: userId,
//            username: username,
//            displayName: displayName,
//            avatarUrl: avatarUrl,
//            isOnline: isOnline,
//            globalReputation: globalReputation,
//            isFriend: isFriend,
//            friendshipStatus: friendshipStatus,
//            isBlocked: isBlocked,
//            isBlockedBy: isBlockedBy
//        )
//    }
//}












// //
// //  RLRightDrawerViewModel.swift
// //  traders_guild
// //
// //  UPDATED: Uses RLAppState and new RL messaging DTOs.
// //  Replaces old RightDrawerViewModel that used AppState.
// //

// import Foundation
// import SwiftUI
// import Combine

// @MainActor
// class RLRightDrawerViewModel: ObservableObject {
    
//     // ================================================================================================
//     // MARK: - Published State
//     // ================================================================================================
    
//     @Published var guildChatrooms: [RLGuildChatroomDTO] = []
//     @Published var guildFriends: [RLDMThreadDTO] = []
//     @Published var guildOnlineNonFriends: [RLDMThreadDTO] = []
//     @Published var guildOfflineNonFriends: [RLDMThreadDTO] = []
//     @Published var guildMembers: [RLGuildMemberDTO] = []
    
//     @Published var isLoading: Bool = false
//     @Published var lastRefresh: Date?
    
//     private var currentGuildId: UUID?
//     private var cancellables = Set<AnyCancellable>()
//     private weak var messagingManager: RLMessagingManager?
//     private weak var appState: RLAppState?
//     private weak var presenceAppState: RLAppState?
//     private var isRefreshingFromRealtime = false
    
//     init() {
//         setupRealTimeListeners()
//     }

//     func configure(with messagingManager: RLMessagingManager) {
//         self.messagingManager = messagingManager
//     }

//     func configurePresence(with rlAppState: RLAppState) {
//         presenceAppState = rlAppState
//         rlAppState.$presenceByUserId
//             .receive(on: DispatchQueue.main)
//             .sink { [weak self] presenceMap in
//                 self?.applyPresenceUpdates(presenceMap)
//             }
//             .store(in: &cancellables)
//         applyPresenceUpdates(rlAppState.presenceByUserId)
//     }
    
//     // ================================================================================================
//     // MARK: - Computed Properties
//     // ================================================================================================
    
//     /// Total unread count across all messaging
//     var totalUnreadCount: Int {
//         let chatroomUnread = guildChatrooms.reduce(0) { $0 + $1.unreadCount }
//         let friendsUnread = guildFriends.reduce(0) { $0 + $1.unreadCount }
//         let onlineUnread = guildOnlineNonFriends.reduce(0) { $0 + $1.unreadCount }
//         let offlineUnread = guildOfflineNonFriends.reduce(0) { $0 + $1.unreadCount }
//         return chatroomUnread + friendsUnread + onlineUnread + offlineUnread
//     }
    
//     /// Whether any chatrooms have unread messages
//     var hasChatroomUnread: Bool {
//         guildChatrooms.contains { $0.hasUnread }
//     }
    
//     /// Whether any DMs have unread messages
//     var hasDMUnread: Bool {
//         guildFriends.contains { $0.hasUnread } ||
//         guildOnlineNonFriends.contains { $0.hasUnread } ||
//         guildOfflineNonFriends.contains { $0.hasUnread }
//     }

//     /// Whether any DM threads exist (for fallback to member list)
//     var hasAnyDMThreads: Bool {
//         !guildFriends.isEmpty ||
//         !guildOnlineNonFriends.isEmpty ||
//         !guildOfflineNonFriends.isEmpty
//     }

//     /// Member-based friend list (fallback when no threads yet)
//     var memberFriends: [RLGuildMemberDTO] {
//         guildMembers.filter { $0.isFriend }
//     }

//     /// Member-based online list (fallback when no threads yet)
//     var memberOnlineNonFriends: [RLGuildMemberDTO] {
//         guildMembers.filter { !$0.isFriend && $0.isOnline }
//     }

//     /// Member-based offline list (fallback when no threads yet)
//     var memberOfflineNonFriends: [RLGuildMemberDTO] {
//         guildMembers.filter { !$0.isFriend && !$0.isOnline }
//     }
    
//     // ================================================================================================
//     // MARK: - Cache Update Methods
//     // ================================================================================================
    
//     /// Update DM unread count in cache
//     func updateDMUnreadCount(threadId: UUID, unreadCount: Int) {
//         // Check friends array
//         if let index = guildFriends.firstIndex(where: { $0.id == threadId }) {
//             guildFriends[index] = guildFriends[index].withUnreadCount(unreadCount)
//             print("✅ Updated friend DM cache: \(threadId) -> unreadCount: \(unreadCount)")
//             return
//         }
        
//         // Check online non-friends array
//         if let index = guildOnlineNonFriends.firstIndex(where: { $0.id == threadId }) {
//             guildOnlineNonFriends[index] = guildOnlineNonFriends[index].withUnreadCount(unreadCount)
//             print("✅ Updated online non-friend DM cache: \(threadId) -> unreadCount: \(unreadCount)")
//             return
//         }
        
//         // Check offline non-friends array
//         if let index = guildOfflineNonFriends.firstIndex(where: { $0.id == threadId }) {
//             guildOfflineNonFriends[index] = guildOfflineNonFriends[index].withUnreadCount(unreadCount)
//             print("✅ Updated offline non-friend DM cache: \(threadId) -> unreadCount: \(unreadCount)")
//             return
//         }
        
//         print("⚠️ DM thread not found in cache: \(threadId)")
//     }
    
//     /// Mark DM as read in cache (convenience method)
//     func markDMAsRead(threadId: UUID) {
//         updateDMUnreadCount(threadId: threadId, unreadCount: 0)
//     }
    
//     /// Update chatroom unread count in cache
//     func updateChatroomUnreadCount(chatroomId: UUID, unreadCount: Int) {
//         guard let index = guildChatrooms.firstIndex(where: { $0.id == chatroomId }) else {
//             print("⚠️ Chatroom not found in cache: \(chatroomId)")
//             return
//         }
        
//         guildChatrooms[index] = guildChatrooms[index].withUnreadCount(unreadCount)
//         print("✅ Updated chatroom cache: \(chatroomId) -> unreadCount: \(unreadCount)")
//     }
    
//     /// Mark chatroom as read in cache (convenience method)
//     func markChatroomAsRead(chatroomId: UUID) {
//         updateChatroomUnreadCount(chatroomId: chatroomId, unreadCount: 0)
//     }
    
//     // ================================================================================================
//     // MARK: - Preload Data
//     // ================================================================================================
    
//     /// Preload all drawer data using combined endpoint (single request)
//     func preloadData(for guildId: UUID, appState: RLAppState) async {
//         guard shouldRefresh(for: guildId) else { return }
//         self.appState = appState
        
//         isLoading = true
//         defer { isLoading = false }
        
//         do {
//             // Use combined endpoint for efficiency
//             let data = try await appState.fetchGuildMessagingData(guildId: guildId)
            
//             self.guildChatrooms = data.chatrooms
//             self.guildFriends = data.friendDms
//             self.guildOnlineNonFriends = data.onlineDms
//             self.guildOfflineNonFriends = data.offlineDms
//             self.lastRefresh = Date()
//             self.currentGuildId = guildId
            
//             print("✅ Loaded drawer data: \(data.chatrooms.count) chatrooms, \(data.friendDms.count) friends, \(data.onlineDms.count) online, \(data.offlineDms.count) offline")
//             // Fallback if combined endpoint returns empty
//             if data.chatrooms.isEmpty && data.friendDms.isEmpty &&
//                 data.onlineDms.isEmpty && data.offlineDms.isEmpty {
//                 print("⚠️ Combined messaging data empty - falling back to separate fetches")
//                 await preloadDataSeparate(for: guildId, appState: appState)
//             }

//             if guildMembers.isEmpty {
//                 await preloadMembersFallback(for: guildId, appState: appState)
//             }
            
//             rebuildDMSections()
//             subscribeToAllChannels()
//             if let presenceAppState = presenceAppState {
//                 applyPresenceUpdates(presenceAppState.presenceByUserId)
//             }
//         } catch is CancellationError {
//             return
//         } catch {
//             print("⚠️ Failed to preload drawer data: \(error)")
//             // Error already shown by RLAppState
//             await preloadDataSeparate(for: guildId, appState: appState)
//         }
//     }
    
//     /// Preload data using separate endpoints (fallback/legacy)
//     func preloadDataSeparate(for guildId: UUID, appState: RLAppState) async {
//         guard shouldRefresh(for: guildId) else { return }
//         self.appState = appState
        
//         isLoading = true
//         defer { isLoading = false }
        
//         async let chatroomsTask = appState.fetchGuildChatrooms(guildId: guildId)
//         async let threadsTask = appState.fetchDMThreads(guildId: guildId)
        
//         do {
//             let (chatrooms, threads) = try await (chatroomsTask, threadsTask)
            
//             self.guildChatrooms = chatrooms
            
//             // Categorize DM threads
//             self.guildFriends = threads.filter { $0.participant.isFriend }
//             self.guildOnlineNonFriends = threads.filter { !$0.participant.isFriend && $0.participant.isOnline }
//             self.guildOfflineNonFriends = threads.filter { !$0.participant.isFriend && !$0.participant.isOnline }
            
//             self.lastRefresh = Date()
//             self.currentGuildId = guildId
            
//             if guildMembers.isEmpty {
//                 await preloadMembersFallback(for: guildId, appState: appState)
//             }
            
//             rebuildDMSections()
//             subscribeToAllChannels()
//             if let presenceAppState = presenceAppState {
//                 applyPresenceUpdates(presenceAppState.presenceByUserId)
//             }
            
//         } catch is CancellationError {
//             return
//         } catch {
//             print("⚠️ Failed to preload drawer data: \(error)")
//         }
//     }
    
//     /// Manual refresh - forces reload
//     func refresh(for guildId: UUID, appState: RLAppState) async {
//         self.appState = appState
//         lastRefresh = nil
//         await preloadData(for: guildId, appState: appState)
//     }
    
//     /// Clear all cached data
//     func clearCache() {
//         guildChatrooms = []
//         guildFriends = []
//         guildOnlineNonFriends = []
//         guildOfflineNonFriends = []
//         guildMembers = []
//         lastRefresh = nil
//         currentGuildId = nil
//     }

//     /// Fallback: load member list for right drawer when no threads exist yet
//     private func preloadMembersFallback(for guildId: UUID, appState: RLAppState) async {
//         do {
//             let response = try await appState.fetchGuildMembers(guildId: guildId, limit: 200)
//             guildMembers = response.members.filter { $0.userId != appState.currentUser?.id }
//             rebuildDMSections()
//         } catch {
//             print("⚠️ Failed to load member fallback list: \(error)")
//         }
//     }

//     /// Find an existing DM thread for a member (if any)
//     func findDMThread(for userId: UUID) -> RLDMThreadDTO? {
//         if let thread = guildFriends.first(where: { $0.participant.userId == userId }) {
//             return thread
//         }
//         if let thread = guildOnlineNonFriends.first(where: { $0.participant.userId == userId }) {
//             return thread
//         }
//         if let thread = guildOfflineNonFriends.first(where: { $0.participant.userId == userId }) {
//             return thread
//         }
//         return nil
//     }
    
//     // ================================================================================================
//     // MARK: - Cache Logic
//     // ================================================================================================
    
//     /// Check if data should be refreshed
//     private func shouldRefresh(for guildId: UUID) -> Bool {
//         // Always refresh if guild changed
//         if currentGuildId != guildId {
//             return true
//         }
        
//         // Refresh if cache is empty
//         if guildChatrooms.isEmpty && guildFriends.isEmpty && guildOnlineNonFriends.isEmpty && guildOfflineNonFriends.isEmpty {
//             return true
//         }
        
//         // Refresh if data is stale (5 minutes old)
//         guard let lastRefresh = lastRefresh else { return true }
//         return Date().timeIntervalSince(lastRefresh) > 300
//     }
    
//     // ================================================================================================
//     // MARK: - Find Methods
//     // ================================================================================================
    
//     /// Find a DM thread by ID across all categories
//     func findDMThread(id: UUID) -> RLDMThreadDTO? {
//         if let thread = guildFriends.first(where: { $0.id == id }) { return thread }
//         if let thread = guildOnlineNonFriends.first(where: { $0.id == id }) { return thread }
//         if let thread = guildOfflineNonFriends.first(where: { $0.id == id }) { return thread }
//         return nil
//     }
    
//     /// Find a chatroom by ID
//     func findChatroom(id: UUID) -> RLGuildChatroomDTO? {
//         return guildChatrooms.first(where: { $0.id == id })
//     }
// }

// // ================================================================================================
// // MARK: - DTO Extensions for Cache Updates
// // ================================================================================================
// // These extensions provide methods to create copies with updated values
// // without conflicting with the auto-generated memberwise initializers.

// extension RLDMThreadDTO {
//     /// Create a copy with updated unread count
//     func withUnreadCount(_ count: Int) -> RLDMThreadDTO {
//         // Use JSONEncoder/Decoder to create a mutable copy
//         // This is a workaround for structs with all `let` properties
//         guard var dict = try? JSONSerialization.jsonObject(
//             with: JSONEncoder().encode(self)
//         ) as? [String: Any] else {
//             return self
//         }
//         dict["unreadCount"] = count
//         guard let data = try? JSONSerialization.data(withJSONObject: dict),
//               let updated = try? JSONDecoder().decode(RLDMThreadDTO.self, from: data) else {
//             return self
//         }
//         return updated
//     }
// }

// extension RLGuildChatroomDTO {
//     /// Create a copy with updated unread count
//     func withUnreadCount(_ count: Int) -> RLGuildChatroomDTO {
//         // Use JSONEncoder/Decoder to create a mutable copy
//         guard var dict = try? JSONSerialization.jsonObject(
//             with: JSONEncoder().encode(self)
//         ) as? [String: Any] else {
//             return self
//         }
//         dict["unreadCount"] = count
//         guard let data = try? JSONSerialization.data(withJSONObject: dict),
//               let updated = try? JSONDecoder().decode(RLGuildChatroomDTO.self, from: data) else {
//             return self
//         }
//         return updated
//     }
// }










// //
// //  RLRightDrawerViewModel+RealTime.swift
// //  traders_guild
// //
// //  Handles real-time updates for the chat list (unread counts, last messages).
// //


// extension RLRightDrawerViewModel {
    
//     // MARK: - Setup
    
//     func setupRealTimeListeners() {
//         RealTimeService.shared.messageSubject
//             .receive(on: DispatchQueue.main)
//             .sink { [weak self] message in
//                 self?.handleRealTimeEvent(message)
//             }
//             .store(in: &cancellables) // Ensure ViewModel has cancellables
//     }
    
//     // MARK: - Subscription (Optional Strategy)
    
//     /// Subscribe to all known channels to receive unread updates
//     /// Call this after preloadData() finishes
//     func subscribeToAllChannels() {
//         var channelsToSubscribe: [String] = []
        
//         // Chatrooms
//         channelsToSubscribe.append(contentsOf: guildChatrooms.map { MessagingChannel.chatroom($0.id).name })
//         if let guildId = currentGuildId {
//             channelsToSubscribe.append(MessagingChannel.guildPresence(guildId).name)
//         }
        
//         // DMs (Friends + Others)
//         let allDMs = guildFriends + guildOnlineNonFriends + guildOfflineNonFriends
//         channelsToSubscribe.append(contentsOf: allDMs.map { MessagingChannel.dm($0.id).name })
        
//         print("📜 [RightDrawer] Subscribing to \(channelsToSubscribe.count) channels for updates")
//         RealTimeService.shared.subscribe(to: channelsToSubscribe, owner: "rightDrawer")
//     }
    
//     // MARK: - Event Handling
    
//     private func handleRealTimeEvent(_ wsMessage: WSIncomingMessage) {
//         guard let type = WSMessageType(rawValue: wsMessage.type) else { return }
        
//         // Handle "New Message" to update unread counts and "Last Message" preview
//         if type == .newMessage {
//             // Check if it's a Chatroom message
//             if let chatroomMsg = wsMessage.payload(as: RLChatroomMessageDTO.self) {
//                 updateChatroomList(with: chatroomMsg)
//             } 
//             // Check if it's a DM message
//             else if let dmMsg = wsMessage.payload(as: RLDMMessageDTO.self) {
//                 updateDMList(with: dmMsg)
//             }
//         }
        
//         // Handle "Presence" (Online/Offline status)
//         if type == .presence, let userId = wsMessage.userId, let isOnline = wsMessage.payload(as: Bool.self) {
//              updateUserPresence(userId: UUID(uuidString: userId), isOnline: isOnline)
//         }
//     }
    
//     private func updateChatroomList(with message: RLChatroomMessageDTO) {
//         if let index = guildChatrooms.firstIndex(where: { $0.id == message.chatroomId }) {
//             if isActiveChatroom(message.chatroomId) {
// #if DEBUG
//                 print("🧪 [RightDrawer] Skip unread: active chatroom \(message.chatroomId)")
// #endif
//                 return
//             }
//             var chatroom = guildChatrooms[index]
            
//             // Update unread count (if not currently looking at it - logic usually handled by checking active state)
//             // Ideally, check if this chatroom is NOT the active one in MessagingManager
//             let newCount = chatroom.unreadCount + 1
//             chatroom = chatroom.withUnreadCount(newCount)
            
//             // TODO: Update 'lastMessage' property on DTO if added later
            
//             // Move to top or just update
//             guildChatrooms[index] = chatroom
//         }
//     }
    
//     private func updateDMList(with message: RLDMMessageDTO) {
//         // Helper to update specific array
//         func updateArray(_ array: inout [RLDMThreadDTO]) -> Bool {
//             if let index = array.firstIndex(where: { $0.id == message.dmId }) {
//                 if isActiveDM(message.dmId) {
// #if DEBUG
//                     print("🧪 [RightDrawer] Skip unread: active DM \(message.dmId)")
// #endif
//                     return true
//                 }
//                 var thread = array[index]
//                 thread = thread.withUnreadCount(thread.unreadCount + 1)
                
//                 // Move to top
//                 array.remove(at: index)
//                 array.insert(thread, at: 0)
//                 return true
//             }
//             return false
//         }
        
//         // Try finding thread in all categories
//         if !updateArray(&guildFriends) {
//             if !updateArray(&guildOnlineNonFriends) {
//                 if !updateArray(&guildOfflineNonFriends) {
//                     refreshIfMissingThread()
//                 }
//             }
//         }
//     }
    
//     private func updateUserPresence(userId: UUID?, isOnline: Bool) {
//         guard let userId = userId else { return }
        
//         // Move user between Online/Offline arrays if they are not friends
//         // (If they are friends, just update the status inside guildFriends)
        
//         // Logic omitted for brevity, but involves finding the user in one array,
//         // updating their `isOnline` status, and moving them to the correct section.
//         if let index = guildMembers.firstIndex(where: { $0.userId == userId }) {
//             guildMembers[index] = guildMembers[index].withOnlineStatus(isOnline)
//         }
        
//         rebuildDMSections()
//     }

//     private func refreshIfMissingThread() {
//         guard !isRefreshingFromRealtime,
//               let guildId = currentGuildId,
//               let appState = appState else { return }
//         isRefreshingFromRealtime = true
//         Task { @MainActor in
//             defer { isRefreshingFromRealtime = false }
//             await refresh(for: guildId, appState: appState)
//         }
//     }

//     private func applyPresenceUpdates(_ presenceMap: [UUID: Bool]) {
//         if presenceMap.isEmpty {
//             guildMembers = guildMembers.map { $0.withOnlineStatus(false) }
//             rebuildDMSections()
//             return
//         }
        
//         var didChange = false
//         guildMembers = guildMembers.map { member in
//             guard let isOnline = presenceMap[member.userId], isOnline != member.isOnline else {
//                 return member
//             }
//             didChange = true
//             return member.withOnlineStatus(isOnline)
//         }
        
//         if didChange {
//             rebuildDMSections()
//         }
//     }

//     private func rebuildDMSections() {
//         let allThreads = guildFriends + guildOnlineNonFriends + guildOfflineNonFriends
//         guard !allThreads.isEmpty else { return }
        
//         let friendUserIds: Set<UUID>
//         if !guildMembers.isEmpty {
//             friendUserIds = Set(guildMembers.filter { $0.isFriend }.map { $0.userId })
//         } else {
//             friendUserIds = Set(allThreads.filter { $0.participant.isFriend }.map { $0.participant.userId })
//         }
        
//         var newFriends: [RLDMThreadDTO] = []
//         var newOnline: [RLDMThreadDTO] = []
//         var newOffline: [RLDMThreadDTO] = []
        
//         for thread in allThreads {
//             let updatedThread = updateThreadParticipant(from: thread)
//             if friendUserIds.contains(updatedThread.participant.userId) {
//                 newFriends.append(updatedThread)
//             } else if updatedThread.participant.isOnline {
//                 newOnline.append(updatedThread)
//             } else {
//                 newOffline.append(updatedThread)
//             }
//         }
        
//         guildFriends = newFriends
//         guildOnlineNonFriends = newOnline
//         guildOfflineNonFriends = newOffline
//     }
    
//     private func updateThreadParticipant(from thread: RLDMThreadDTO) -> RLDMThreadDTO {
//         guard let member = guildMembers.first(where: { $0.userId == thread.participant.userId }) else {
//             return thread
//         }
        
//         guard var dict = try? JSONSerialization.jsonObject(
//             with: JSONEncoder().encode(thread)
//         ) as? [String: Any],
//         let memberDict = try? JSONSerialization.jsonObject(
//             with: JSONEncoder().encode(member)
//         ) as? [String: Any] else {
//             return thread
//         }
        
//         dict["participant"] = memberDict
//         guard let data = try? JSONSerialization.data(withJSONObject: dict),
//               let updated = try? JSONDecoder().decode(RLDMThreadDTO.self, from: data) else {
//             return thread
//         }
        
//         return updated
//     }

//     private func isActiveChatroom(_ chatroomId: UUID) -> Bool {
//         guard let messagingManager = messagingManager else { return false }
//         if case .chatroom(let chatroom) = messagingManager.activeMessage {
//             return chatroom.id == chatroomId
//         }
//         return false
//     }

//     private func isActiveDM(_ threadId: UUID) -> Bool {
//         guard let messagingManager = messagingManager else { return false }
//         if case .dmThread(let thread) = messagingManager.activeMessage {
//             return thread.id == threadId
//         }
//         return false
//     }
// }
