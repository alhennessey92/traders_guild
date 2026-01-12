
//
//  AppState.swift
//  traders_guild
//
//  CLEAN REBUILD - Uses flat DTOs that match backend exactly.
//
//  Core State Changes:
//  - currentUser: UserDTO (was CurrentUserDTO with nested guildMembership)
//  - currentGuild: GuildDTO (was GuildMembershipDTO with nested guild)
//  - currentMembership: GuildMembershipDTO (NEW - flat, no nesting)
//
//  Auth: Works with real API
//  Other features: TODO - add as you build backend endpoints
//

import Foundation
import SwiftUI

@MainActor
class RLAppState: ObservableObject {
    
    // ================================================================================================
    // MARK: - Core State (NEW FLAT DTOs)
    // ================================================================================================
    
    /// Currently logged-in user (FLAT - no nested guild)
    @Published var currentUser: RLUserDTO? {
        didSet {
            isAuthenticated = currentUser != nil
            if let user = currentUser {
                saveUserToKeychain(user)
            } else {
                clearUserFromKeychain()
            }
        }
    }
    
    /// Authentication status
    @Published var isAuthenticated: Bool = false
    
    /// JWT authentication token
    @Published var accessToken: String? {
        didSet {
            if let token = accessToken {
                saveTokenToKeychain(token)
                realApi.setAccessToken(token)
            } else {
                clearTokenFromKeychain()
                realApi.setAccessToken(nil)
            }
        }
    }
    
    /// Refresh token (stored but not published)
    private var refreshToken: String?
    
    /// Currently selected guild (FLAT - just guild data)
    @Published var currentGuild: RLGuildDTO? {
        didSet {
            if let guild = currentGuild {
                saveGuildToKeychain(guild)
            } else {
                clearGuildFromKeychain()
            }
        }
    }
    
    /// User's membership in current guild (FLAT - just membership data)
    @Published var currentMembership: RLGuildMembershipDTO? {
        didSet {
            if let membership = currentMembership {
                saveMembershipToKeychain(membership)
            } else {
                clearMembershipFromKeychain()
            }
        }
    }
    
    // ================================================================================================
    // MARK: - Computed Convenience Properties
    // ================================================================================================
    
    /// User's role in current guild
    var currentRole: RLMemberRole? {
        currentMembership?.memberRole
    }
    
    /// Can user moderate in current guild?
    var canModerate: Bool {
        currentMembership?.canModerate ?? false
    }
    
    /// Can user admin current guild?
    var canAdmin: Bool {
        currentMembership?.canAdmin ?? false
    }
    
    /// Is user the owner of current guild?
    var isGuildOwner: Bool {
        guard let user = currentUser, let guild = currentGuild else { return false }
        return guild.ownerId == user.id
    }
    
    /// Check if user has selected a guild
    var hasSelectedGuild: Bool {
        currentGuild != nil && currentMembership != nil
    }
    
    // ================================================================================================
    // MARK: - UI State
    // ================================================================================================
    
    @Published var isLoading: Bool = false
    @Published var isCompletingSignup: Bool = false
    @Published var errorMessage: String?
    @Published var currentAlert: RLAppAlert?
    
    @Published var showingTransition: Bool = true
    @Published var hasCompletedInitialLoad: Bool = false
    @Published var isChartReady: Bool = false
    @Published var isSessionRestored: Bool = false
    
    @Published var showGuildSelectionSheet: Bool = false
    
    /// Available guilds for selection (flat arrays)
    @Published var availableGuilds: [RLGuildDTO] = []
    @Published var userMemberships: [RLGuildMembershipDTO] = []
    
    // ================================================================================================
    // MARK: - Services
    // ================================================================================================
    
    let realApi = RealAPIService()
    
    // ================================================================================================
    // MARK: - Initialization
    // ================================================================================================
    
    init() {
        Task {
            await restoreSession()
        }
    }
    
    // ================================================================================================
    // MARK: - Transition Management
    // ================================================================================================
    
    func finishTransition() {
        showingTransition = false
        hasCompletedInitialLoad = true
    }
    
    func chartDidBecomeReady() {
        isChartReady = true
    }
    
    func resetChartReadyState() {
        isChartReady = false
    }
    
    func showTransitionForChartLoad() {
        isChartReady = false
        showingTransition = true
    }
    
    // ================================================================================================
    // MARK: - Error Management
    // ================================================================================================
    
    func showError(_ error: Error, title: String = "Error", style: RLAlertDisplayStyle = .alert) {
        let alert = RLAppAlert(
            title: title,
            message: error.localizedDescription,
            severity: .error,
            style: style
        )
        currentAlert = alert
    }
    
    func showError(title: String, message: String, severity: RLAlertSeverity = .error, style: RLAlertDisplayStyle = .alert) {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: severity,
            style: style
        )
        currentAlert = alert
    }
    
    func showSuccess(_ message: String, title: String = "Success") {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .success,
            style: .toast
        )
        currentAlert = alert
    }
    
    func showInfo(_ message: String, title: String = "Info") {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .info,
            style: .toast
        )
        currentAlert = alert
    }
    
    func showWarning(_ message: String, title: String = "Warning") {
        let alert = RLAppAlert(
            title: title,
            message: message,
            severity: .warning,
            style: .alert
        )
        currentAlert = alert
    }
    
    func clearAlert() {
        currentAlert = nil
    }
    
    // ================================================================================================
    // MARK: - Authentication (REAL API)
    // ================================================================================================
    
    /// Sign up new user
    func signUp(data: RLSignupData) async throws {
        isLoading = true
        errorMessage = nil
        isCompletingSignup = true
        
        defer {
            isLoading = false
            isCompletingSignup = false
        }
        
        do {
            // Call real API
            let response = try await realApi.register(data: data)
            
            // Store tokens
            self.accessToken = response.tokens.accessToken
            self.refreshToken = response.tokens.refreshToken
            
            // Set state - flat, no conversion needed!
            self.currentUser = response.user
            self.currentGuild = response.defaultGuild
            self.currentMembership = response.defaultGuildMembership
            
            showSuccess("Welcome to Traders Guild, \(response.user.username)!")
            showTransitionForChartLoad()
            
        } catch {
            showError(error, title: "Signup Failed", style: .alert)
            throw error
        }
    }
    
    /// Login with email and password
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Call real API
            let response = try await realApi.login(email: email, password: password)
            
            // Store tokens
            self.accessToken = response.tokens.accessToken
            self.refreshToken = response.tokens.refreshToken
            
            // Set user
            self.currentUser = response.user
            
            // Fetch user's guilds
            try await fetchUserGuilds()
            
            // Handle guild selection
            if userMemberships.isEmpty {
                showGuildSelectionSheet = true
                showWarning("Please join a guild to continue")
            } else if userMemberships.count == 1 {
                selectGuild(at: 0)
                showTransitionForChartLoad()
            } else {
                showGuildSelectionSheet = true
            }
            
            showSuccess("Welcome back, \(response.user.username)!")
            
        } catch {
            showError(error, title: "Login Failed", style: .alert)
            throw error
        }
    }
    
    /// Logout and clear session
    func logout() {
        Task {
            await realApi.logout()
        }
        
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        currentGuild = nil
        currentMembership = nil
        availableGuilds = []
        userMemberships = []
        
        clearAllKeychain()
        resetChartReadyState()
        
        showInfo("You've been logged out")
    }
    
    /// Restore session from keychain
    func restoreSession() async {
        if let token = getTokenFromKeychain() {
            self.accessToken = token
        }
        
        if let user = getUserFromKeychain() {
            self.currentUser = user
        }
        
        if let guild = getGuildFromKeychain() {
            self.currentGuild = guild
        }
        
        if let membership = getMembershipFromKeychain() {
            self.currentMembership = membership
        }
        
        isSessionRestored = true
    }
    
    // ================================================================================================
    // MARK: - Guild Management (REAL API)
    // ================================================================================================
    
    /// Fetch user's guild memberships
    func fetchUserGuilds() async throws {
        let response = try await realApi.getUserGuilds()
        self.availableGuilds = response.guilds
        self.userMemberships = response.guildMemberships
    }
    
    /// Select a guild by index
    func selectGuild(at index: Int) {
        guard index < availableGuilds.count,
              index < userMemberships.count else { return }
        
        showTransitionForChartLoad()
        self.currentGuild = availableGuilds[index]
        self.currentMembership = userMemberships[index]
    }
    
    /// Select a guild by ID
    func selectGuild(id: UUID) {
        guard let index = availableGuilds.firstIndex(where: { $0.id == id }) else { return }
        selectGuild(at: index)
    }
    
    /// Open guild selection sheet
    func openGuildSelector() async {
        do {
            try await fetchUserGuilds()
            showGuildSelectionSheet = true
        } catch {
            showError(error, title: "Failed to load guilds", style: .toast)
        }
    }
    
    /// Fetch open guilds for discovery
    func fetchOpenGuilds() async throws -> [RLGuildDTO] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let guilds = try await realApi.getOpenGuilds()
            return guilds
        } catch {
            showError(error, title: "Failed to Fetch Guilds", style: .toast)
            throw error
        }
    }
    
    /// Join a guild
    func joinGuild(guildId: UUID) async throws {
        do {
            let membership = try await realApi.joinGuild(guildId: guildId)
            
            // Refresh guild list
            try await fetchUserGuilds()
            
            // Select the newly joined guild
            selectGuild(id: guildId)
            
            showSuccess("Joined guild successfully!")
        } catch {
            showError(error, title: "Failed to Join Guild", style: .toast)
            throw error
        }
    }
    
    /// Leave current guild
    func leaveCurrentGuild() async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await realApi.leaveGuild(guildId: guild.id)
            currentGuild = nil
            currentMembership = nil
            
            // Refresh guild list
            try await fetchUserGuilds()
            
            if !userMemberships.isEmpty {
                selectGuild(at: 0)
            } else {
                showGuildSelectionSheet = true
            }
        } catch {
            showError(error, title: "Failed to Leave Guild", style: .toast)
            throw error
        }
    }
    
    // ================================================================================================
    // MARK: - Keychain Persistence
    // ================================================================================================
    
    private let keychainPrefix = "traders_guild_"
    
    // Token
    private func saveTokenToKeychain(_ token: String) {
        UserDefaults.standard.set(token, forKey: "\(keychainPrefix)token")
    }
    
    private func getTokenFromKeychain() -> String? {
        UserDefaults.standard.string(forKey: "\(keychainPrefix)token")
    }
    
    private func clearTokenFromKeychain() {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)token")
    }
    
    // User
    private func saveUserToKeychain(_ user: RLUserDTO) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)user")
        }
    }
    
    private func getUserFromKeychain() -> RLUserDTO? {
        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)user") else { return nil }
        return try? JSONDecoder().decode(RLUserDTO.self, from: data)
    }
    
    private func clearUserFromKeychain() {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)user")
    }
    
    // Guild
    private func saveGuildToKeychain(_ guild: RLGuildDTO) {
        if let data = try? JSONEncoder().encode(guild) {
            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)guild")
        }
    }
    
    private func getGuildFromKeychain() -> RLGuildDTO? {
        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)guild") else { return nil }
        return try? JSONDecoder().decode(RLGuildDTO.self, from: data)
    }
    
    private func clearGuildFromKeychain() {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)guild")
    }
    
    // Membership
    private func saveMembershipToKeychain(_ membership: RLGuildMembershipDTO) {
        if let data = try? JSONEncoder().encode(membership) {
            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)membership")
        }
    }
    
    private func getMembershipFromKeychain() -> RLGuildMembershipDTO? {
        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)membership") else { return nil }
        return try? JSONDecoder().decode(RLGuildMembershipDTO.self, from: data)
    }
    
    private func clearMembershipFromKeychain() {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)membership")
    }
    
    // Clear all
    private func clearAllKeychain() {
        clearTokenFromKeychain()
        clearUserFromKeychain()
        clearGuildFromKeychain()
        clearMembershipFromKeychain()
    }
}

// ================================================================================================
// MARK: - App Errors
// ================================================================================================

enum RLAppError: LocalizedError {
    case noGuildSelected
    case notAuthenticated
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noGuildSelected:
            return "No guild selected"
        case .notAuthenticated:
            return "Not authenticated"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .unknown(let msg):
            return msg
        }
    }
}
