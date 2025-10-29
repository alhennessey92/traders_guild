



//
//  AppState.swift
//  traders_guild
//
//  Created by Al Hennessey on 23/10/2025.
//


import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    
    // ================================================================================================
    // MARK: - Core State
    // ================================================================================================
    
    /// Currently logged-in user
    @Published var currentUser: CurrentUserDTO? {
        didSet {
            isAuthenticated = currentUser != nil
            if let user = currentUser {
                saveUserToKeychain(user)
            } else {
                clearKeychain()
            }
        }
    }
    
    /// Authentication status
    @Published var isAuthenticated: Bool = false
    
    /// JWT authentication token
    @Published var authToken: String? {
        didSet {
            if let token = authToken {
                saveTokenToKeychain(token)
            }
        }
    }
    
    /// Currently selected/active guild the user is viewing
    /// This represents which guild's content is currently being displayed
    @Published var currentGuild: GuildDTO? {
        didSet {
            if let guild = currentGuild {
                saveCurrentGuildToKeychain(guild)
            } else {
                clearCurrentGuild()
            }
        }
    }
    
    // ================================================================================================
    // MARK: - UI State
    // ================================================================================================
    
    /// Loading indicator
    @Published var isLoading: Bool = false
    
    // In UI State section
    @Published var isCompletingSignup: Bool = false
    
    /// Error message for alerts
    @Published var errorMessage: String?
    
//    /// Show/hide login sheet
//    @Published var showLoginSheet: Bool = false
    
    /// Show transition/loading view on app launch
    @Published var showingTransition: Bool = true

    /// Track if initial load is complete
    @Published var hasCompletedInitialLoad: Bool = false
    
    /// Show guild selection sheet after login
    @Published var showGuildSelectionSheet: Bool = false

    /// Available guilds for selection
    @Published var availableGuildsForSelection: [GuildDTO] = []
    
    
    // ================================================================================================
    // MARK: - Services
    // ================================================================================================
    
    private let api = MockAPIService()  // TODO: Replace with real API service
    
    // ================================================================================================
    // MARK: - Initialization
    // ================================================================================================
    
    init() {
        Task {
            await restoreSession()
        }
    }
    
    // ================================================================================================
    // MARK: - Authentication
    // ================================================================================================
    
    /// Signup with email and password
    /// /// Signup with email and password
    func signUp(data: SignupData) async throws {
        isLoading = true
        errorMessage = nil
        isCompletingSignup = true  // ✅ Set flag
        
        defer {
            isLoading = false
            isCompletingSignup = false  // ✅ Clear flag
        }
        
        do {
            let response = try await api.signUp(data: data)
            self.currentUser = response.user
            self.authToken = response.token
            
            if let selectedGuildId = data.selectedGuildId {
                try await joinGuild(guildId: selectedGuildId)
                
                if let selectedGuild = availableGuildsForSelection.first(where: { $0.id == selectedGuildId }) {
                    self.currentGuild = selectedGuild
                } else {
                    if let joinedGuild = try await fetchGuildById(guildId: selectedGuildId) {
                        self.currentGuild = joinedGuild
                    }
                }
            }
            
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Signup failed: \(error.localizedDescription)"
            throw error
        }
    }
//    func signUp(data: SignupData) async throws {
//        isLoading = true
//        errorMessage = nil
//        
//        defer {
//            isLoading = false
//        }
//        
//        do {
//            let response = try await api.signUp(data: data)
//            self.currentUser = response.user
//            self.authToken = response.token
//            
//            // ✅ If user selected a guild during signup, set it as current guild
//            if let selectedGuildId = data.selectedGuildId {
//                // Join the guild
//                try await joinGuild(guildId: selectedGuildId)
//                
//                // ✅ Use the guild from availableGuilds (already fetched in SignupGuildView!)
//                // No need to fetch again
//                if let selectedGuild = availableGuildsForSelection.first(where: { $0.id == selectedGuildId }) {
//                    self.currentGuild = selectedGuild
//                } else {
//                    // Fallback: fetch if somehow not in list
//                    if let joinedGuild = try await fetchGuildById(guildId: selectedGuildId) {
//                        self.currentGuild = joinedGuild
//                    }
//                }
//            }
//            
//        } catch is CancellationError {
//            throw CancellationError()
//        } catch {
//            errorMessage = "Signup failed: \(error.localizedDescription)"
//            throw error
//        }
//    }
    /// Login with email and password
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let response = try await api.login(email: email, password: password)
            self.currentUser = response.user
            self.authToken = response.token
            
            // ✅ Fetch user's guilds
            let userGuilds = try await fetchUserGuilds()
            self.availableGuildsForSelection = userGuilds
            
            // ✅ Show guild selection sheet (currentGuild is still nil)
            showGuildSelectionSheet = true
            
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
            throw error
        }
    }
//    /// Login with email and password
//    func login(email: String, password: String) async throws {
//        isLoading = true
//        errorMessage = nil
//        
//        defer {
//            isLoading = false
//        }
//        
//        do {
//            let response = try await api.login(email: email, password: password)
//            self.currentUser = response.user
//            self.authToken = response.token
//            
//            // ✅ Fetch and set user's current guild after login
//            // In production, this would come from the user's last active guild
//            // For now, we'll use sample data
//            let userGuild = try await fetchUserGuilds()
//            self.currentGuild = userGuild.first
//            
//            showLoginSheet = false
//            
//        } catch {
//            errorMessage = "Login failed: \(error.localizedDescription)"
//            throw error
//        }
//    }
    
    /// Logout and clear session
    func logout() {
        currentUser = nil
        authToken = nil
        currentGuild = nil
        clearKeychain()
        //showLoginSheet = true
    }
    
    /// Restore saved session from storage
    private func restoreSession() async {
        if let savedToken = getTokenFromKeychain(),
           let savedUser = getUserFromKeychain() {
            
            self.authToken = savedToken
            self.currentUser = savedUser
            
            // Restore current guild if exists
            if let savedGuild = getCurrentGuildFromKeychain() {
                self.currentGuild = savedGuild
            }
            
            // TODO: Validate token with backend
            
        }
        // Mark initial load as complete
        hasCompletedInitialLoad = true
    }
    
    // ================================================================================================
    // MARK: - Transition Management
    // ================================================================================================

    /// Called when the transition/welcome animation completes
    func finishTransition() {
        showingTransition = false
    }
    
    // ================================================================================================
    // MARK: - Guild Management
    // ================================================================================================
    
    /// Switch to a different guild
    func selectGuild(_ guild: GuildDTO) {
        currentGuild = guild
    }
    
    /// Open guild selection sheet (for switching guilds)  // ✅ Add this
    func openGuildSelector() async {
        do {
            let guilds = try await fetchUserGuilds()
            self.availableGuildsForSelection = guilds
            showGuildSelectionSheet = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Failed to load guilds: \(error.localizedDescription)"
        }
    }
    
    /// Fetch all open/available guilds
    func fetchOpenGuilds() async throws -> [GuildDTO] {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let guilds = try await api.fetchOpenGuilds()
            return guilds
        } catch {
            errorMessage = "Failed to fetch guilds: \(error.localizedDescription)"
            throw error
        }
    }
    
    
    /// Fetch all guilds the user is a member of
    func fetchUserGuilds() async throws -> [GuildDTO] {
        errorMessage = nil
        
        do {
            let guilds = try await api.fetchUserGuilds()
            return guilds
        } catch {
            errorMessage = "Failed to fetch user guilds: \(error.localizedDescription)"
            throw error
        }
    }
    
    
    /// Fetch a specific guild by ID
    func fetchGuildById(guildId: UUID) async throws -> GuildDTO? {
        errorMessage = nil
        
        do {
            let guild = try await api.fetchGuildById(guildId: guildId)
            return guild
        } catch {
            errorMessage = "Failed to fetch guild: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Join a guild
    func joinGuild(guildId: UUID) async throws {
        errorMessage = nil
        
        do {
            try await api.joinGuild(guildId: guildId)
        } catch {
            errorMessage = "Failed to join guild: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Leave current guild
    func leaveCurrentGuild() async throws {
        guard let guild = currentGuild else {
            throw AppError.noGuildSelected
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await api.leaveGuild(guildId: guild.id)
            currentGuild = nil
        } catch {
            errorMessage = "Failed to leave guild: \(error.localizedDescription)"
            throw error
        }
    }
    
    
    /// Fetch announcements for a guild
    func fetchGuildAnnouncements(guildId: UUID) async throws -> [GuildAnnouncementDTO] {
        errorMessage = nil
        
        do {
            let announcements = try await api.fetchGuildAnnouncements(guildId: guildId)
            return announcements
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Failed to fetch announcements: \(error.localizedDescription)"
            throw error
        }
    }

    /// Fetch upcoming events for a guild
    func fetchGuildEvents(guildId: UUID) async throws -> [GuildEventDTO] {
        errorMessage = nil
        
        do {
            let events = try await api.fetchGuildEvents(guildId: guildId)
            return events
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Failed to fetch events: \(error.localizedDescription)"
            throw error
        }
    }

    /// Fetch members for a guild
    func fetchGuildMembers(guildId: UUID) async throws -> [GuildMembershipDTO] {
        errorMessage = nil
        
        do {
            let members = try await api.fetchGuildMembers(guildId: guildId)
            return members
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Failed to fetch members: \(error.localizedDescription)"
            throw error
        }
    }

    /// Fetch watchlists for a guild
    func fetchGuildWatchlists(guildId: UUID) async throws -> [GuildWatchlistDTO] {
        errorMessage = nil
        
        do {
            let watchlists = try await api.fetchGuildWatchlists(guildId: guildId)
            return watchlists
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Failed to fetch watchlists: \(error.localizedDescription)"
            throw error
        }
    }
    
    
    /// Fetch or Create UserDM for Guild
    func fetchOrCreateUserDM(userId: UUID) async throws -> DMDTO{
        errorMessage = nil
        do {
            let dmdto = try await api.fetchOrCreateUserDM(userId: userId)
            return dmdto
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Failed to fetch User DM: \(error.localizedDescription)"
            throw error
        }
    }
    
    ///  Fetch DM Messages by DMId
    func fetchDMMessages(dmId: UUID) async throws -> [DMMessageDTO]{
        errorMessage = nil
        do {
            let dmmessages = try await api.fetchDMMessagesByDmId(dmId: dmId)
            return dmmessages
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = "Failed to fetch User DM: \(error.localizedDescription)"
            throw error
        }
    }
    
    // ================================================================================================
    // MARK: - Persistence
    // ================================================================================================
    
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
    
    private func saveCurrentGuildToKeychain(_ guild: GuildDTO) {
        if let data = try? JSONEncoder().encode(guild) {
            UserDefaults.standard.set(data, forKey: "currentGuild")
        }
    }
    
    private func getCurrentGuildFromKeychain() -> GuildDTO? {
        guard let data = UserDefaults.standard.data(forKey: "currentGuild") else { return nil }
        return try? JSONDecoder().decode(GuildDTO.self, from: data)
    }
    
    private func clearCurrentGuild() {
        UserDefaults.standard.removeObject(forKey: "currentGuild")
    }
    
    private func clearKeychain() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentGuild")
    }
}

// ================================================================================================
// MARK: - App Errors
// ================================================================================================

enum AppError: LocalizedError {
    case noGuildSelected
    case networkError
    case unauthorized
    case invalidResponse
    case guildNotFound
    
    var errorDescription: String? {
        switch self {
        case .noGuildSelected:
            return "No guild selected. Please select a guild first."
        case .networkError:
            return "Network error occurred. Please try again."
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .invalidResponse:
            return "Invalid response from server."
        case .guildNotFound:
            return "Guild not found."
        }
    }
}



