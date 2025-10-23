//
//  AppState.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//


import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    
    // ================================================================================================
    // MARK: - State Properties
    // ================================================================================================
    
    // MARK: Authentication State
    /// Currently logged-in user (nil = not authenticated)
    /// When this changes, we save to Keychain and update API headers
    @Published var currentUser: CurrentUserDTO? {
        didSet {
            if let user = currentUser {
                saveUserToKeychain(user)
            } else {
                clearKeychain()
            }
        }
    }
    
    /// Simple boolean for checking auth status in views
    @Published var isAuthenticated: Bool = false
    
    /// JWT token for API authentication
    /// Automatically added to all API requests when set
    @Published var authToken: String? {
        didSet {
            if let token = authToken {
                // TODO: Update your API client headers
                saveTokenToKeychain(token)
            }
        }
    }
    
    // MARK: Guild Context
    /// Currently active/selected guild
    /// Changing this triggers loading of guild-specific content
    @Published var currentGuild: GuildDTO? {
        didSet {
            // When guild changes, reload guild content
            if currentGuild?.id != oldValue?.id {
                clearGuildData()
                if let guild = currentGuild {
                    Task {
                        await loadGuildContent(guild.id)
                    }
                }
            }
        }
    }
    
    /// User's membership details in current guild
    @Published var currentGuildMembership: GuildMembershipDTO?
    
    /// Quick access to user's role in current guild
    var currentGuildRole: MemberRole? {
        currentGuild?.currentMemberRole
    }
    
    
    
    // MARK: Cached Data
    // These store fetched data to avoid repeated API calls
    
    /// All public guilds (for discovery)
    @Published var allGuilds: [GuildDTO] = []
    
    /// User's joined guilds
    @Published var myGuilds: [GuildDTO] = []
    
    /// Current guild's announcements
    @Published var currentGuildAnnouncements: [GuildAnnouncementDTO] = []
    
    /// Current guild's upcoming events
    @Published var currentGuildEvents: [GuildEventDTO] = []
    
    /// Current guild's chat channels
    @Published var currentGuildChatrooms: [GuildChatroomDTO] = []
    
    /// Current guild's member list
    @Published var currentGuildMembers: [GuildMembershipDTO] = []
    
    /// Current guild's watchlists
    @Published var currentGuildWatchlists: [GuildWatchlistDTO] = []
    
    /// User's direct message conversations
    @Published var directMessages: [DirectMessageDTO] = []
    
    /// User's friends list
    @Published var friends: [GuildFriendDTO] = []
    
    /// Messages in current chat/DM
    @Published var currentMessages: [MessageDTO] = []
    
    // MARK: UI State
    /// Global loading indicator
    @Published var isLoading: Bool = false
    
    /// Global error message (shown in alert)
    @Published var errorMessage: String?
    
    /// Control login sheet presentation
    @Published var showLoginSheet: Bool = false
    
    /// Badge counts for tab bar
    @Published var unreadAnnouncements: Int = 0
    @Published var unreadMessages: Int = 0
    @Published var unreadEvents: Int = 0
    
    // MARK: Services
    /// API client (MockAPIService during development, real APIService in production)
    private let api = MockAPIService()  // TODO: Replace with real APIService
    
    /// Timer for periodic updates
    private var refreshTimer: Timer?
    
    
    // ================================================================================================
    // MARK: - Initialization
    // ================================================================================================
    
    init() {
        // Check for existing session on app launch
        Task {
            await restoreSession()
        }
        
        
        // Start background refresh timer
        startRefreshTimer()
    }
    
    // ================================================================================================
    // MARK: - Authentication Methods
    // ================================================================================================
    
    /// Login with credentials
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    /// - Throws: Authentication errors
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // TODO: Replace with real API call
            // let response = try await api.post("/auth/login", body: ["email": email, "password": password])
            // self.currentUser = response.user
            // self.authToken = response.token
            
            // Mock implementation
            try await Task.sleep(nanoseconds: 1_000_000_000)
            self.currentUser = SampleData.currentUser
            self.authToken = "mock-jwt-token"
            self.isAuthenticated = true
            
            // Load user's data after successful login
            await loadMyGuilds()
            
            // Dismiss login UI
            showLoginSheet = false
            
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Logout and clear all data
    func logout() {
        // Clear authentication
        currentUser = nil
        authToken = nil
        isAuthenticated = false
        
        // Clear guild context
        currentGuild = nil
        currentGuildMembership = nil
        
        // Clear all cached data
        allGuilds = []
        myGuilds = []
        clearGuildData()
        directMessages = []
        friends = []
        
        
        // Clear persisted data
        clearKeychain()
        
        // Show login UI
        showLoginSheet = true
    }
    
    /// Restore saved session from Keychain
    private func restoreSession() async {
        if let savedToken = getTokenFromKeychain(),
           let savedUser = getUserFromKeychain() {
            
            // Restore saved session
            self.authToken = savedToken
            self.currentUser = savedUser
            self.isAuthenticated = true
            
            // TODO: Validate token with backend
            // if tokenIsValid {
                await loadMyGuilds()
            // } else {
            //     logout()
            // }
        } else {
            // No saved session
            showLoginSheet = true
        }
    }
    
    // ================================================================================================
    // MARK: - Guild Management
    // ================================================================================================
    
    /// Switch to a different guild
    /// - Parameter guild: Guild to switch to
    func switchToGuild(_ guild: GuildDTO) {
        currentGuild = guild
        // Content loading triggered by didSet
    }
    
    /// Join a new guild
    /// - Parameter guild: Guild to join
    func joinGuild(_ guild: GuildDTO) async throws {
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            // TODO: Real API call
            // let response = try await api.post("/guilds/\(guild.id)/join")
            
            // Create updated guild with joined status
            let joinedGuild = GuildDTO(
                id: guild.id,
                name: guild.name,
                description: guild.description,
                reputation: guild.reputation,
                accuracy: guild.accuracy,
                memberCount: guild.memberCount + 1,
                owner: guild.owner,
                dateCreated: guild.dateCreated,
                imageURL: guild.imageURL,
                isJoined: true,
                currentMemberRole: .member
            )
            
            // Update in all guilds
            if let index = allGuilds.firstIndex(where: { $0.id == guild.id }) {
                allGuilds[index] = joinedGuild
            }
            
            // Add to my guilds
            myGuilds.append(joinedGuild)
            
            // Switch to newly joined guild
            switchToGuild(joinedGuild)
            
        } catch {
            errorMessage = "Failed to join guild"
            throw error
        }
    }
    
    /// Leave the current guild
    func leaveCurrentGuild() async throws {
        guard let guild = currentGuild else { return }
        
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            // TODO: Real API call
            // try await api.delete("/guilds/\(guild.id)/leave")
            
            // Remove from my guilds
            myGuilds.removeAll { $0.id == guild.id }
            
            // Clear current guild
            currentGuild = nil
            
            // Update in all guilds list
            if let index = allGuilds.firstIndex(where: { $0.id == guild.id }) {
                let leftGuild = GuildDTO(
                    id: allGuilds[index].id,
                    name: allGuilds[index].name,
                    description: allGuilds[index].description,
                    reputation: allGuilds[index].reputation,
                    accuracy: allGuilds[index].accuracy,
                    memberCount: allGuilds[index].memberCount - 1,
                    owner: allGuilds[index].owner,
                    dateCreated: allGuilds[index].dateCreated,
                    imageURL: allGuilds[index].imageURL,
                    isJoined: false,
                    currentMemberRole: nil
                )
                allGuilds[index] = leftGuild
            }
            
        } catch {
            errorMessage = "Failed to leave guild"
            throw error
        }
    }
    
    // ================================================================================================
    // MARK: - Data Loading
    // ================================================================================================
    
    /// Load all public guilds for discovery
    func loadAllGuilds() async {
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        // TODO: Real API call
        allGuilds = await api.fetchGuilds()
    }
    
    /// Load user's joined guilds
    func loadMyGuilds() async {
        // TODO: Real API call
        // myGuilds = await api.get("/me/guilds")
        
        // Mock: filter for joined guilds
        myGuilds = await api.fetchGuilds().filter { $0.isJoined }
        
        // Auto-select first guild
        if currentGuild == nil, let firstGuild = myGuilds.first {
            switchToGuild(firstGuild)
        }
    }
    
    /// Load all content for a guild
    private func loadGuildContent(_ guildId: UUID) async {
        // Load everything in parallel for performance
        async let announcements = api.fetchAnnouncements(guildId: guildId)
        async let events = api.fetchEvents(guildId: guildId)
        async let chatrooms = api.fetchChatrooms(guildId: guildId)
        async let watchlists = api.fetchWatchlists(guildId: guildId)
        
        // Await all results
        currentGuildAnnouncements = await announcements
        currentGuildEvents = await events
        currentGuildChatrooms = await chatrooms
        currentGuildWatchlists = await watchlists
        
        // Update badge counts
        updateUnreadCounts()
    }
    
    // ================================================================================================
    // MARK: - Helper Methods
    // ================================================================================================
    
    /// Clear guild-specific data
    private func clearGuildData() {
        currentGuildAnnouncements = []
        currentGuildEvents = []
        currentGuildChatrooms = []
        currentGuildMembers = []
        currentGuildWatchlists = []
        currentMessages = []
        activeChatroom = nil
    }
    
    /// Update unread counts for badges
    private func updateUnreadCounts() {
        unreadAnnouncements = currentGuildAnnouncements.filter { !$0.isRead }.count
        unreadMessages = directMessages.reduce(0) { $0 + $1.unreadCount }
        unreadEvents = currentGuildEvents.filter { $0.isImportant && !$0.isAttending }.count
    }
    

    
    /// Start background refresh
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { [weak self] in
                await self?.updateUnreadCounts()
            }
        }
    }
    
    // ================================================================================================
    // MARK: - Persistence (Simplified)
    // ================================================================================================
    // TODO: Replace with proper Keychain implementation
    
    private func saveTokenToKeychain(_ token: String) {
        UserDefaults.standard.set(token, forKey: "authToken")
    }
    
    private func getTokenFromKeychain() -> String? {
        UserDefaults.standard.string(forKey: "authToken")
    }
    
    private func saveUserToKeychain(_ user: CurrentUserDTO) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
    
    private func getUserFromKeychain() -> CurrentUserDTO? {
        guard let data = UserDefaults.standard.data(forKey: "currentUser") else { return nil }
        return try? JSONDecoder().decode(CurrentUserDTO.self, from: data)
    }
    
    private func clearKeychain() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
}
