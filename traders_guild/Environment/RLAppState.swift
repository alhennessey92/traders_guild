//
//  RLAppState.swift
//  traders_guild
//
//  CLEAN REBUILD - Uses flat DTOs that match backend exactly.
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
                print("🔑 AccessToken SET: \(token.prefix(20))...")
                saveTokenToKeychain(token)
                realApi.setAccessToken(token)
            } else {
                print("🔑 AccessToken CLEARED")
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
    
    /// Flag to prevent race conditions during login/signup flow
    /// When true, external triggers (like onAppear) should NOT call openGuildSelector
    @Published var isHandlingAuthFlow: Bool = false
    
    /// Available guilds for selection (combined view model)
    @Published var userGuilds: [RLGuildWithMembership] = []
    
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
        isHandlingAuthFlow = true  // ← Prevent race conditions
        
        defer {
            isLoading = false
            isCompletingSignup = false
            isHandlingAuthFlow = false  // ← Clear flag when done
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
        isHandlingAuthFlow = true  // ← Prevent race conditions
        
        defer {
            isLoading = false
            // Note: Don't clear isHandlingAuthFlow here if showing sheet
        }
        
        do {
            // Call real API
            let response = try await realApi.login(email: email, password: password)
            
            // Store tokens
            self.accessToken = response.tokens.accessToken
            self.refreshToken = response.tokens.refreshToken
            
            // Set user (this triggers isAuthenticated = true)
            self.currentUser = response.user
            
            print("🔐 Login: User set, currentGuild before fetch: \(currentGuild?.name ?? "nil")")
            
            // Fetch user's guilds
            try await fetchUserGuilds()
            
            print("🔐 Login: Fetched \(userGuilds.count) guilds")
            for (i, g) in userGuilds.enumerated() {
                print("   [\(i)] \(g.guild.name)")
            }
            
            // Handle guild selection
            if userGuilds.isEmpty {
                print("🔐 Login: No guilds - showing sheet")
                showGuildSelectionSheet = true
                isHandlingAuthFlow = false
                showWarning("Please join a guild to continue")
            } else if userGuilds.count == 1 {
                print("🔐 Login: Single guild - auto-selecting")
                // Auto-select single guild
                selectGuild(at: 0)
                isHandlingAuthFlow = false
                showTransitionForChartLoad()
            } else {
                print("🔐 Login: Multiple guilds (\(userGuilds.count)) - showing selection sheet")
                print("🔐 Login: showGuildSelectionSheet = true")
                // Multiple guilds - show picker
                showGuildSelectionSheet = true
                isHandlingAuthFlow = false
            }
            
            print("🔐 Login: Final state - currentGuild: \(currentGuild?.name ?? "nil"), showSheet: \(showGuildSelectionSheet)")
            
            showSuccess("Welcome back, \(response.user.username)!")
            
        } catch {
            isHandlingAuthFlow = false  // ← Clear flag on error
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
        userGuilds = []
        showGuildSelectionSheet = false  // ← Make sure sheet is dismissed
        isHandlingAuthFlow = false
        
        clearAllKeychain()
        resetChartReadyState()
        
        showInfo("You've been logged out")
    }
    
    /// Restore session from keychain
    func restoreSession() async {
        print("🔄 restoreSession: Starting...")
        
        if let token = getTokenFromKeychain() {
            self.accessToken = token
            print("🔄 restoreSession: Found token")
        }
        
        if let user = getUserFromKeychain() {
            self.currentUser = user
            print("🔄 restoreSession: Found user: \(user.username)")
        }
        
        if let guild = getGuildFromKeychain() {
            self.currentGuild = guild
            print("🔄 restoreSession: Found guild: \(guild.name)")
        }
        
        if let membership = getMembershipFromKeychain() {
            self.currentMembership = membership
            print("🔄 restoreSession: Found membership")
        }
        
        print("🔄 restoreSession: Done - isAuthenticated: \(isAuthenticated), hasGuild: \(currentGuild != nil)")
        isSessionRestored = true
    }
    
    // ================================================================================================
    // MARK: - Guild Management (REAL API)
    // ================================================================================================
    
    /// Fetch user's guild memberships
    func fetchUserGuilds() async throws {
        let response = try await realApi.getUserGuilds()
        self.userGuilds = response.combined
    }
    
    /// Select a guild by index
    func selectGuild(at index: Int) {
        guard index < userGuilds.count else { return }
        
        let selected = userGuilds[index]
        selectGuild(selected, showTransition: true)  // Show transition for auto-select (login)
    }
    
    /// Select a guild by ID
    func selectGuild(id: UUID) {
        guard let selected = userGuilds.first(where: { $0.guild.id == id }) else { return }
        selectGuild(selected, showTransition: true)  // Show transition for lookup select
    }
    
    /// Select a guild directly (primary method)
    /// - Parameter showTransition: Whether to show loading transition (false for manual guild switching)
    func selectGuild(_ guildWithMembership: RLGuildWithMembership, showTransition: Bool = false) {
        if showTransition {
            showTransitionForChartLoad()
        }
        
        self.currentGuild = guildWithMembership.guild
        self.currentMembership = guildWithMembership.membership
        
        // Dismiss the sheet if it's open
        if showGuildSelectionSheet {
            showGuildSelectionSheet = false
        }
    }
    
    /// Open guild selection sheet (for switching guilds)
    /// NOTE: External callers should check `isHandlingAuthFlow` before calling
    func openGuildSelector() async {
        // Prevent if already handling auth flow
        guard !isHandlingAuthFlow else {
            print("⚠️ openGuildSelector skipped - auth flow in progress")
            return
        }
        
        // Prevent if sheet already showing
        guard !showGuildSelectionSheet else {
            print("⚠️ openGuildSelector skipped - sheet already showing")
            return
        }
        
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
    
    /// Join a guild - returns the combined guild with membership
    func joinGuild(guildId: UUID) async throws -> RLGuildWithMembership {
        do {
            let response = try await realApi.joinGuild(guildId: guildId)
            let guildWithMembership = response.combined
            
            // Add to local guild list
            userGuilds.append(guildWithMembership)
            
            // Select the newly joined guild (show transition)
            selectGuild(guildWithMembership, showTransition: true)
            
            showSuccess("Joined \(guildWithMembership.guild.name) successfully!")
            return guildWithMembership
        } catch {
            showError(error, title: "Failed to Join Guild", style: .toast)
            throw error
        }
    }
    
    /// Create a new guild - returns the combined guild with membership
    func createGuild(name: String, description: String?, isOpen: Bool) async throws -> RLGuildWithMembership {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await realApi.createGuild(
                name: name,
                description: description,
                isOpen: isOpen
            )
            let guildWithMembership = response.combined
            
            // Add to local guild list
            userGuilds.append(guildWithMembership)
            
            // Select the newly created guild (show transition)
            selectGuild(guildWithMembership, showTransition: true)
            
            showSuccess("Created \(guildWithMembership.guild.name) successfully!")
            return guildWithMembership
        } catch {
            showError(error, title: "Failed to Create Guild", style: .toast)
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
            
            if !userGuilds.isEmpty {
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
    // MARK: - Announcement Management (REAL API)
    // ================================================================================================
    
    /// Fetch guild announcements
    func fetchGuildAnnouncements(guildId: UUID) async throws -> [RLGuildAnnouncementWithAuthorDTO] {
        print("📢 fetchGuildAnnouncements: Starting for guild \(guildId)")
        do {
            let response = try await realApi.getGuildAnnouncements(guildId: guildId)
            print("📢 fetchGuildAnnouncements: Got \(response.announcements.count) announcements")
            return response.announcements
        } catch {
            print("📢 fetchGuildAnnouncements: Error - \(error)")
            showError(error, title: "Failed to Load Announcements", style: .toast)
            throw error
        }
    }
    
    /// Fetch announcements for current guild
    func fetchCurrentGuildAnnouncements() async throws -> [RLGuildAnnouncementWithAuthorDTO] {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchGuildAnnouncements(guildId: guild.id)
    }
    
    /// Record announcement view (marks as read)
    /// Uses the announcement's guildId
    func recordAnnouncementView(guildId: UUID, announcementId: UUID) async throws {
        do {
            try await realApi.recordAnnouncementView(guildId: guildId, announcementId: announcementId)
        } catch {
            // Don't show error for view recording - it's not critical
            print("⚠️ Failed to record announcement view: \(error)")
            throw error
        }
    }
    
    /// Create announcement (admin/mod only)
    func createAnnouncement(title: String, content: String, preview: String? = nil, isImportant: Bool = false) async throws -> RLGuildAnnouncementWithAuthorDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        
        do {
            let response = try await realApi.createAnnouncement(
                guildId: guild.id,
                title: title,
                content: content,
                preview: preview,
                isImportant: isImportant
            )
            
            showSuccess("Announcement posted!")
            return response
        } catch {
            showError(error, title: "Failed to Create Announcement", style: .toast)
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
























////
////  RLAppState.swift
////  traders_guild
////
////  CLEAN REBUILD - Uses flat DTOs that match backend exactly.
////
//
//import Foundation
//import SwiftUI
//
//@MainActor
//class RLAppState: ObservableObject {
//
//    // ================================================================================================
//    // MARK: - Core State (NEW FLAT DTOs)
//    // ================================================================================================
//
//    /// Currently logged-in user (FLAT - no nested guild)
//    @Published var currentUser: RLUserDTO? {
//        didSet {
//            isAuthenticated = currentUser != nil
//            if let user = currentUser {
//                saveUserToKeychain(user)
//            } else {
//                clearUserFromKeychain()
//            }
//        }
//    }
//
//    /// Authentication status
//    @Published var isAuthenticated: Bool = false
//
//    /// JWT authentication token
//    @Published var accessToken: String? {
//        didSet {
//            if let token = accessToken {
//                saveTokenToKeychain(token)
//                realApi.setAccessToken(token)
//            } else {
//                clearTokenFromKeychain()
//                realApi.setAccessToken(nil)
//            }
//        }
//    }
//
//    /// Refresh token (stored but not published)
//    private var refreshToken: String?
//
//    /// Currently selected guild (FLAT - just guild data)
//    @Published var currentGuild: RLGuildDTO? {
//        didSet {
//            if let guild = currentGuild {
//                saveGuildToKeychain(guild)
//            } else {
//                clearGuildFromKeychain()
//            }
//        }
//    }
//
//    /// User's membership in current guild (FLAT - just membership data)
//    @Published var currentMembership: RLGuildMembershipDTO? {
//        didSet {
//            if let membership = currentMembership {
//                saveMembershipToKeychain(membership)
//            } else {
//                clearMembershipFromKeychain()
//            }
//        }
//    }
//
//    // ================================================================================================
//    // MARK: - Computed Convenience Properties
//    // ================================================================================================
//
//    /// User's role in current guild
//    var currentRole: RLMemberRole? {
//        currentMembership?.memberRole
//    }
//
//    /// Can user moderate in current guild?
//    var canModerate: Bool {
//        currentMembership?.canModerate ?? false
//    }
//
//    /// Can user admin current guild?
//    var canAdmin: Bool {
//        currentMembership?.canAdmin ?? false
//    }
//
//    /// Is user the owner of current guild?
//    var isGuildOwner: Bool {
//        guard let user = currentUser, let guild = currentGuild else { return false }
//        return guild.ownerId == user.id
//    }
//
//    /// Check if user has selected a guild
//    var hasSelectedGuild: Bool {
//        currentGuild != nil && currentMembership != nil
//    }
//
//    // ================================================================================================
//    // MARK: - UI State
//    // ================================================================================================
//
//    @Published var isLoading: Bool = false
//    @Published var isCompletingSignup: Bool = false
//    @Published var errorMessage: String?
//    @Published var currentAlert: RLAppAlert?
//
//    @Published var showingTransition: Bool = true
//    @Published var hasCompletedInitialLoad: Bool = false
//    @Published var isChartReady: Bool = false
//    @Published var isSessionRestored: Bool = false
//
//    @Published var showGuildSelectionSheet: Bool = false
//
//    /// Flag to prevent race conditions during login/signup flow
//    /// When true, external triggers (like onAppear) should NOT call openGuildSelector
//    @Published var isHandlingAuthFlow: Bool = false
//
//    /// Available guilds for selection (combined view model)
//    @Published var userGuilds: [RLGuildWithMembership] = []
//
//    // ================================================================================================
//    // MARK: - Services
//    // ================================================================================================
//
//    let realApi = RealAPIService()
//
//    // ================================================================================================
//    // MARK: - Initialization
//    // ================================================================================================
//
//    init() {
//        Task {
//            await restoreSession()
//        }
//    }
//
//    // ================================================================================================
//    // MARK: - Transition Management
//    // ================================================================================================
//
//    func finishTransition() {
//        showingTransition = false
//        hasCompletedInitialLoad = true
//    }
//
//    func chartDidBecomeReady() {
//        isChartReady = true
//    }
//
//    func resetChartReadyState() {
//        isChartReady = false
//    }
//
//    func showTransitionForChartLoad() {
//        isChartReady = false
//        showingTransition = true
//    }
//
//    // ================================================================================================
//    // MARK: - Error Management
//    // ================================================================================================
//
//    func showError(_ error: Error, title: String = "Error", style: RLAlertDisplayStyle = .alert) {
//        let alert = RLAppAlert(
//            title: title,
//            message: error.localizedDescription,
//            severity: .error,
//            style: style
//        )
//        currentAlert = alert
//    }
//
//    func showError(title: String, message: String, severity: RLAlertSeverity = .error, style: RLAlertDisplayStyle = .alert) {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: severity,
//            style: style
//        )
//        currentAlert = alert
//    }
//
//    func showSuccess(_ message: String, title: String = "Success") {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: .success,
//            style: .toast
//        )
//        currentAlert = alert
//    }
//
//    func showInfo(_ message: String, title: String = "Info") {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: .info,
//            style: .toast
//        )
//        currentAlert = alert
//    }
//
//    func showWarning(_ message: String, title: String = "Warning") {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: .warning,
//            style: .alert
//        )
//        currentAlert = alert
//    }
//
//    func clearAlert() {
//        currentAlert = nil
//    }
//
//    // ================================================================================================
//    // MARK: - Authentication (REAL API)
//    // ================================================================================================
//
//    /// Sign up new user
//    func signUp(data: RLSignupData) async throws {
//        isLoading = true
//        errorMessage = nil
//        isCompletingSignup = true
//        isHandlingAuthFlow = true  // ← Prevent race conditions
//
//        defer {
//            isLoading = false
//            isCompletingSignup = false
//            isHandlingAuthFlow = false  // ← Clear flag when done
//        }
//
//        do {
//            // Call real API
//            let response = try await realApi.register(data: data)
//
//            // Store tokens
//            self.accessToken = response.tokens.accessToken
//            self.refreshToken = response.tokens.refreshToken
//
//            // Set state - flat, no conversion needed!
//            self.currentUser = response.user
//            self.currentGuild = response.defaultGuild
//            self.currentMembership = response.defaultGuildMembership
//
//            showSuccess("Welcome to Traders Guild, \(response.user.username)!")
//            showTransitionForChartLoad()
//
//        } catch {
//            showError(error, title: "Signup Failed", style: .alert)
//            throw error
//        }
//    }
//
//    /// Login with email and password
//    func login(email: String, password: String) async throws {
//        isLoading = true
//        errorMessage = nil
//        isHandlingAuthFlow = true  // ← Prevent race conditions
//
//        defer {
//            isLoading = false
//            // Note: Don't clear isHandlingAuthFlow here if showing sheet
//        }
//
//        do {
//            // Call real API
//            let response = try await realApi.login(email: email, password: password)
//
//            // Store tokens
//            self.accessToken = response.tokens.accessToken
//            self.refreshToken = response.tokens.refreshToken
//
//            // Set user (this triggers isAuthenticated = true)
//            self.currentUser = response.user
//
//            print("🔐 Login: User set, currentGuild before fetch: \(currentGuild?.name ?? "nil")")
//
//            // Fetch user's guilds
//            try await fetchUserGuilds()
//
//            print("🔐 Login: Fetched \(userGuilds.count) guilds")
//            for (i, g) in userGuilds.enumerated() {
//                print("   [\(i)] \(g.guild.name)")
//            }
//
//            // Handle guild selection
//            if userGuilds.isEmpty {
//                print("🔐 Login: No guilds - showing sheet")
//                showGuildSelectionSheet = true
//                isHandlingAuthFlow = false
//                showWarning("Please join a guild to continue")
//            } else if userGuilds.count == 1 {
//                print("🔐 Login: Single guild - auto-selecting")
//                // Auto-select single guild
//                selectGuild(at: 0)
//                isHandlingAuthFlow = false
//                showTransitionForChartLoad()
//            } else {
//                print("🔐 Login: Multiple guilds (\(userGuilds.count)) - showing selection sheet")
//                print("🔐 Login: showGuildSelectionSheet = true")
//                // Multiple guilds - show picker
//                showGuildSelectionSheet = true
//                isHandlingAuthFlow = false
//            }
//
//            print("🔐 Login: Final state - currentGuild: \(currentGuild?.name ?? "nil"), showSheet: \(showGuildSelectionSheet)")
//
//            showSuccess("Welcome back, \(response.user.username)!")
//
//        } catch {
//            isHandlingAuthFlow = false  // ← Clear flag on error
//            showError(error, title: "Login Failed", style: .alert)
//            throw error
//        }
//    }
//
//    /// Logout and clear session
//    func logout() {
//        Task {
//            await realApi.logout()
//        }
//
//        accessToken = nil
//        refreshToken = nil
//        currentUser = nil
//        currentGuild = nil
//        currentMembership = nil
//        userGuilds = []
//        showGuildSelectionSheet = false  // ← Make sure sheet is dismissed
//        isHandlingAuthFlow = false
//
//        clearAllKeychain()
//        resetChartReadyState()
//
//        showInfo("You've been logged out")
//    }
//
//    /// Restore session from keychain
//    func restoreSession() async {
//        print("🔄 restoreSession: Starting...")
//
//        if let token = getTokenFromKeychain() {
//            self.accessToken = token
//            print("🔄 restoreSession: Found token")
//        }
//
//        if let user = getUserFromKeychain() {
//            self.currentUser = user
//            print("🔄 restoreSession: Found user: \(user.username)")
//        }
//
//        if let guild = getGuildFromKeychain() {
//            self.currentGuild = guild
//            print("🔄 restoreSession: Found guild: \(guild.name)")
//        }
//
//        if let membership = getMembershipFromKeychain() {
//            self.currentMembership = membership
//            print("🔄 restoreSession: Found membership")
//        }
//
//        print("🔄 restoreSession: Done - isAuthenticated: \(isAuthenticated), hasGuild: \(currentGuild != nil)")
//        isSessionRestored = true
//    }
//
//    // ================================================================================================
//    // MARK: - Guild Management (REAL API)
//    // ================================================================================================
//
//    /// Fetch user's guild memberships
//    func fetchUserGuilds() async throws {
//        let response = try await realApi.getUserGuilds()
//        self.userGuilds = response.combined
//    }
//
//    /// Select a guild by index
//    func selectGuild(at index: Int) {
//        guard index < userGuilds.count else { return }
//
//        let selected = userGuilds[index]
//        selectGuild(selected)
//    }
//
//    /// Select a guild by ID
//    func selectGuild(id: UUID) {
//        guard let selected = userGuilds.first(where: { $0.guild.id == id }) else { return }
//        selectGuild(selected)
//    }
//
//    /// Select a guild directly (primary method)
//    func selectGuild(_ guildWithMembership: RLGuildWithMembership) {
//        showTransitionForChartLoad()
//        self.currentGuild = guildWithMembership.guild
//        self.currentMembership = guildWithMembership.membership
//
//        // Dismiss the sheet if it's open
//        if showGuildSelectionSheet {
//            showGuildSelectionSheet = false
//        }
//    }
//
//    /// Open guild selection sheet (for switching guilds)
//    /// NOTE: External callers should check `isHandlingAuthFlow` before calling
//    func openGuildSelector() async {
//        // Prevent if already handling auth flow
//        guard !isHandlingAuthFlow else {
//            print("⚠️ openGuildSelector skipped - auth flow in progress")
//            return
//        }
//
//        // Prevent if sheet already showing
//        guard !showGuildSelectionSheet else {
//            print("⚠️ openGuildSelector skipped - sheet already showing")
//            return
//        }
//
//        do {
//            try await fetchUserGuilds()
//            showGuildSelectionSheet = true
//        } catch {
//            showError(error, title: "Failed to load guilds", style: .toast)
//        }
//    }
//
//    /// Fetch open guilds for discovery
//    func fetchOpenGuilds() async throws -> [RLGuildDTO] {
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            let guilds = try await realApi.getOpenGuilds()
//            return guilds
//        } catch {
//            showError(error, title: "Failed to Fetch Guilds", style: .toast)
//            throw error
//        }
//    }
//
//    /// Join a guild - returns the combined guild with membership
//    func joinGuild(guildId: UUID) async throws -> RLGuildWithMembership {
//        do {
//            let response = try await realApi.joinGuild(guildId: guildId)
//            let guildWithMembership = response.combined
//
//            // Add to local guild list
//            userGuilds.append(guildWithMembership)
//
//            // Select the newly joined guild
//            selectGuild(guildWithMembership)
//
//            showSuccess("Joined \(guildWithMembership.guild.name) successfully!")
//            return guildWithMembership
//        } catch {
//            showError(error, title: "Failed to Join Guild", style: .toast)
//            throw error
//        }
//    }
//
//    /// Create a new guild - returns the combined guild with membership
//    func createGuild(name: String, description: String?, isOpen: Bool) async throws -> RLGuildWithMembership {
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            let response = try await realApi.createGuild(
//                name: name,
//                description: description,
//                isOpen: isOpen
//            )
//            let guildWithMembership = response.combined
//
//            // Add to local guild list
//            userGuilds.append(guildWithMembership)
//
//            // Select the newly created guild
//            selectGuild(guildWithMembership)
//
//            showSuccess("Created \(guildWithMembership.guild.name) successfully!")
//            return guildWithMembership
//        } catch {
//            showError(error, title: "Failed to Create Guild", style: .toast)
//            throw error
//        }
//    }
//
//    /// Leave current guild
//    func leaveCurrentGuild() async throws {
//        guard let guild = currentGuild else {
//            throw RLAppError.noGuildSelected
//        }
//
//        isLoading = true
//        defer { isLoading = false }
//
//        do {
//            try await realApi.leaveGuild(guildId: guild.id)
//            currentGuild = nil
//            currentMembership = nil
//
//            // Refresh guild list
//            try await fetchUserGuilds()
//
//            if !userGuilds.isEmpty {
//                selectGuild(at: 0)
//            } else {
//                showGuildSelectionSheet = true
//            }
//        } catch {
//            showError(error, title: "Failed to Leave Guild", style: .toast)
//            throw error
//        }
//    }
//
//    // ================================================================================================
//    // MARK: - Keychain Persistence
//    // ================================================================================================
//
//    private let keychainPrefix = "traders_guild_"
//
//    // Token
//    private func saveTokenToKeychain(_ token: String) {
//        UserDefaults.standard.set(token, forKey: "\(keychainPrefix)token")
//    }
//
//    private func getTokenFromKeychain() -> String? {
//        UserDefaults.standard.string(forKey: "\(keychainPrefix)token")
//    }
//
//    private func clearTokenFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)token")
//    }
//
//    // User
//    private func saveUserToKeychain(_ user: RLUserDTO) {
//        if let data = try? JSONEncoder().encode(user) {
//            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)user")
//        }
//    }
//
//    private func getUserFromKeychain() -> RLUserDTO? {
//        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)user") else { return nil }
//        return try? JSONDecoder().decode(RLUserDTO.self, from: data)
//    }
//
//    private func clearUserFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)user")
//    }
//
//    // Guild
//    private func saveGuildToKeychain(_ guild: RLGuildDTO) {
//        if let data = try? JSONEncoder().encode(guild) {
//            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)guild")
//        }
//    }
//
//    private func getGuildFromKeychain() -> RLGuildDTO? {
//        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)guild") else { return nil }
//        return try? JSONDecoder().decode(RLGuildDTO.self, from: data)
//    }
//
//    private func clearGuildFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)guild")
//    }
//
//    // Membership
//    private func saveMembershipToKeychain(_ membership: RLGuildMembershipDTO) {
//        if let data = try? JSONEncoder().encode(membership) {
//            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)membership")
//        }
//    }
//
//    private func getMembershipFromKeychain() -> RLGuildMembershipDTO? {
//        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)membership") else { return nil }
//        return try? JSONDecoder().decode(RLGuildMembershipDTO.self, from: data)
//    }
//
//    private func clearMembershipFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)membership")
//    }
//
//    // Clear all
//    private func clearAllKeychain() {
//        clearTokenFromKeychain()
//        clearUserFromKeychain()
//        clearGuildFromKeychain()
//        clearMembershipFromKeychain()
//    }
//}
//
//// ================================================================================================
//// MARK: - App Errors
//// ================================================================================================
//
//enum RLAppError: LocalizedError {
//    case noGuildSelected
//    case notAuthenticated
//    case networkError(String)
//    case unknown(String)
//
//    var errorDescription: String? {
//        switch self {
//        case .noGuildSelected:
//            return "No guild selected"
//        case .notAuthenticated:
//            return "Not authenticated"
//        case .networkError(let msg):
//            return "Network error: \(msg)"
//        case .unknown(let msg):
//            return msg
//        }
//    }
//}
//




////
////  RLAppState.swift
////  traders_guild
////
////  CLEAN REBUILD - Uses flat DTOs that match backend exactly.
////
//
//import Foundation
//import SwiftUI
//
//@MainActor
//class RLAppState: ObservableObject {
//    
//    // ================================================================================================
//    // MARK: - Core State (NEW FLAT DTOs)
//    // ================================================================================================
//    
//    /// Currently logged-in user (FLAT - no nested guild)
//    @Published var currentUser: RLUserDTO? {
//        didSet {
//            isAuthenticated = currentUser != nil
//            if let user = currentUser {
//                saveUserToKeychain(user)
//            } else {
//                clearUserFromKeychain()
//            }
//        }
//    }
//    
//    /// Authentication status
//    @Published var isAuthenticated: Bool = false
//    
//    /// JWT authentication token
//    @Published var accessToken: String? {
//        didSet {
//            if let token = accessToken {
//                print("🔑 AccessToken SET: \(token.prefix(20))...")
//                saveTokenToKeychain(token)
//                realApi.setAccessToken(token)
//            } else {
//                print("🔑 AccessToken CLEARED")
//                clearTokenFromKeychain()
//                realApi.setAccessToken(nil)
//            }
//        }
//    }
//    
//    /// Refresh token (stored but not published)
//    private var refreshToken: String?
//    
//    /// Currently selected guild (FLAT - just guild data)
//    @Published var currentGuild: RLGuildDTO? {
//        didSet {
//            if let guild = currentGuild {
//                saveGuildToKeychain(guild)
//            } else {
//                clearGuildFromKeychain()
//            }
//        }
//    }
//    
//    /// User's membership in current guild (FLAT - just membership data)
//    @Published var currentMembership: RLGuildMembershipDTO? {
//        didSet {
//            if let membership = currentMembership {
//                saveMembershipToKeychain(membership)
//            } else {
//                clearMembershipFromKeychain()
//            }
//        }
//    }
//    
//    // ================================================================================================
//    // MARK: - Computed Convenience Properties
//    // ================================================================================================
//    
//    /// User's role in current guild
//    var currentRole: RLMemberRole? {
//        currentMembership?.memberRole
//    }
//    
//    /// Can user moderate in current guild?
//    var canModerate: Bool {
//        currentMembership?.canModerate ?? false
//    }
//    
//    /// Can user admin current guild?
//    var canAdmin: Bool {
//        currentMembership?.canAdmin ?? false
//    }
//    
//    /// Is user the owner of current guild?
//    var isGuildOwner: Bool {
//        guard let user = currentUser, let guild = currentGuild else { return false }
//        return guild.ownerId == user.id
//    }
//    
//    /// Check if user has selected a guild
//    var hasSelectedGuild: Bool {
//        currentGuild != nil && currentMembership != nil
//    }
//    
//    // ================================================================================================
//    // MARK: - UI State
//    // ================================================================================================
//    
//    @Published var isLoading: Bool = false
//    @Published var isCompletingSignup: Bool = false
//    @Published var errorMessage: String?
//    @Published var currentAlert: RLAppAlert?
//    
//    @Published var showingTransition: Bool = true
//    @Published var hasCompletedInitialLoad: Bool = false
//    @Published var isChartReady: Bool = false
//    @Published var isSessionRestored: Bool = false
//    
//    @Published var showGuildSelectionSheet: Bool = false
//    
//    /// Flag to prevent race conditions during login/signup flow
//    /// When true, external triggers (like onAppear) should NOT call openGuildSelector
//    @Published var isHandlingAuthFlow: Bool = false
//    
//    /// Available guilds for selection (combined view model)
//    @Published var userGuilds: [RLGuildWithMembership] = []
//    
//    // ================================================================================================
//    // MARK: - Services
//    // ================================================================================================
//    
//    let realApi = RealAPIService()
//    
//    // ================================================================================================
//    // MARK: - Initialization
//    // ================================================================================================
//    
//    init() {
//        Task {
//            await restoreSession()
//        }
//    }
//    
//    // ================================================================================================
//    // MARK: - Transition Management
//    // ================================================================================================
//    
//    func finishTransition() {
//        showingTransition = false
//        hasCompletedInitialLoad = true
//    }
//    
//    func chartDidBecomeReady() {
//        isChartReady = true
//    }
//    
//    func resetChartReadyState() {
//        isChartReady = false
//    }
//    
//    func showTransitionForChartLoad() {
//        isChartReady = false
//        showingTransition = true
//    }
//    
//    // ================================================================================================
//    // MARK: - Error Management
//    // ================================================================================================
//    
//    func showError(_ error: Error, title: String = "Error", style: RLAlertDisplayStyle = .alert) {
//        let alert = RLAppAlert(
//            title: title,
//            message: error.localizedDescription,
//            severity: .error,
//            style: style
//        )
//        currentAlert = alert
//    }
//    
//    func showError(title: String, message: String, severity: RLAlertSeverity = .error, style: RLAlertDisplayStyle = .alert) {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: severity,
//            style: style
//        )
//        currentAlert = alert
//    }
//    
//    func showSuccess(_ message: String, title: String = "Success") {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: .success,
//            style: .toast
//        )
//        currentAlert = alert
//    }
//    
//    func showInfo(_ message: String, title: String = "Info") {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: .info,
//            style: .toast
//        )
//        currentAlert = alert
//    }
//    
//    func showWarning(_ message: String, title: String = "Warning") {
//        let alert = RLAppAlert(
//            title: title,
//            message: message,
//            severity: .warning,
//            style: .alert
//        )
//        currentAlert = alert
//    }
//    
//    func clearAlert() {
//        currentAlert = nil
//    }
//    
//    // ================================================================================================
//    // MARK: - Authentication (REAL API)
//    // ================================================================================================
//    
//    /// Sign up new user
//    func signUp(data: RLSignupData) async throws {
//        isLoading = true
//        errorMessage = nil
//        isCompletingSignup = true
//        isHandlingAuthFlow = true  // ← Prevent race conditions
//        
//        defer {
//            isLoading = false
//            isCompletingSignup = false
//            isHandlingAuthFlow = false  // ← Clear flag when done
//        }
//        
//        do {
//            // Call real API
//            let response = try await realApi.register(data: data)
//            
//            // Store tokens
//            self.accessToken = response.tokens.accessToken
//            self.refreshToken = response.tokens.refreshToken
//            
//            // Set state - flat, no conversion needed!
//            self.currentUser = response.user
//            self.currentGuild = response.defaultGuild
//            self.currentMembership = response.defaultGuildMembership
//            
//            showSuccess("Welcome to Traders Guild, \(response.user.username)!")
//            showTransitionForChartLoad()
//            
//        } catch {
//            showError(error, title: "Signup Failed", style: .alert)
//            throw error
//        }
//    }
//    
//    /// Login with email and password
//    func login(email: String, password: String) async throws {
//        isLoading = true
//        errorMessage = nil
//        isHandlingAuthFlow = true  // ← Prevent race conditions
//        
//        defer {
//            isLoading = false
//            // Note: Don't clear isHandlingAuthFlow here if showing sheet
//        }
//        
//        do {
//            // Call real API
//            let response = try await realApi.login(email: email, password: password)
//            
//            // Store tokens
//            self.accessToken = response.tokens.accessToken
//            self.refreshToken = response.tokens.refreshToken
//            
//            // Set user (this triggers isAuthenticated = true)
//            self.currentUser = response.user
//            
//            print("🔐 Login: User set, currentGuild before fetch: \(currentGuild?.name ?? "nil")")
//            
//            // Fetch user's guilds
//            try await fetchUserGuilds()
//            
//            print("🔐 Login: Fetched \(userGuilds.count) guilds")
//            for (i, g) in userGuilds.enumerated() {
//                print("   [\(i)] \(g.guild.name)")
//            }
//            
//            // Handle guild selection
//            if userGuilds.isEmpty {
//                print("🔐 Login: No guilds - showing sheet")
//                showGuildSelectionSheet = true
//                isHandlingAuthFlow = false
//                showWarning("Please join a guild to continue")
//            } else if userGuilds.count == 1 {
//                print("🔐 Login: Single guild - auto-selecting")
//                // Auto-select single guild
//                selectGuild(at: 0)
//                isHandlingAuthFlow = false
//                showTransitionForChartLoad()
//            } else {
//                print("🔐 Login: Multiple guilds (\(userGuilds.count)) - showing selection sheet")
//                print("🔐 Login: showGuildSelectionSheet = true")
//                // Multiple guilds - show picker
//                showGuildSelectionSheet = true
//                isHandlingAuthFlow = false
//            }
//            
//            print("🔐 Login: Final state - currentGuild: \(currentGuild?.name ?? "nil"), showSheet: \(showGuildSelectionSheet)")
//            
//            showSuccess("Welcome back, \(response.user.username)!")
//            
//        } catch {
//            isHandlingAuthFlow = false  // ← Clear flag on error
//            showError(error, title: "Login Failed", style: .alert)
//            throw error
//        }
//    }
//    
//    /// Logout and clear session
//    func logout() {
//        Task {
//            await realApi.logout()
//        }
//        
//        accessToken = nil
//        refreshToken = nil
//        currentUser = nil
//        currentGuild = nil
//        currentMembership = nil
//        userGuilds = []
//        showGuildSelectionSheet = false  // ← Make sure sheet is dismissed
//        isHandlingAuthFlow = false
//        
//        clearAllKeychain()
//        resetChartReadyState()
//        
//        showInfo("You've been logged out")
//    }
//    
//    /// Restore session from keychain
//    func restoreSession() async {
//        print("🔄 restoreSession: Starting...")
//        
//        if let token = getTokenFromKeychain() {
//            self.accessToken = token
//            print("🔄 restoreSession: Found token")
//        }
//        
//        if let user = getUserFromKeychain() {
//            self.currentUser = user
//            print("🔄 restoreSession: Found user: \(user.username)")
//        }
//        
//        if let guild = getGuildFromKeychain() {
//            self.currentGuild = guild
//            print("🔄 restoreSession: Found guild: \(guild.name)")
//        }
//        
//        if let membership = getMembershipFromKeychain() {
//            self.currentMembership = membership
//            print("🔄 restoreSession: Found membership")
//        }
//        
//        print("🔄 restoreSession: Done - isAuthenticated: \(isAuthenticated), hasGuild: \(currentGuild != nil)")
//        isSessionRestored = true
//    }
//    
//    // ================================================================================================
//    // MARK: - Guild Management (REAL API)
//    // ================================================================================================
//    
//    /// Fetch user's guild memberships
//    func fetchUserGuilds() async throws {
//        let response = try await realApi.getUserGuilds()
//        self.userGuilds = response.combined
//    }
//    
//    /// Select a guild by index
//    func selectGuild(at index: Int) {
//        guard index < userGuilds.count else { return }
//        
//        let selected = userGuilds[index]
//        selectGuild(selected, showTransition: true)  // Show transition for auto-select (login)
//    }
//    
//    /// Select a guild by ID
//    func selectGuild(id: UUID) {
//        guard let selected = userGuilds.first(where: { $0.guild.id == id }) else { return }
//        selectGuild(selected, showTransition: true)  // Show transition for lookup select
//    }
//    
//    /// Select a guild directly (primary method)
//    /// - Parameter showTransition: Whether to show loading transition (false for manual guild switching)
//    func selectGuild(_ guildWithMembership: RLGuildWithMembership, showTransition: Bool = false) {
//        if showTransition {
//            showTransitionForChartLoad()
//        }
//        
//        self.currentGuild = guildWithMembership.guild
//        self.currentMembership = guildWithMembership.membership
//        
//        // Dismiss the sheet if it's open
//        if showGuildSelectionSheet {
//            showGuildSelectionSheet = false
//        }
//    }
//    
//    /// Open guild selection sheet (for switching guilds)
//    /// NOTE: External callers should check `isHandlingAuthFlow` before calling
//    func openGuildSelector() async {
//        // Prevent if already handling auth flow
//        guard !isHandlingAuthFlow else {
//            print("⚠️ openGuildSelector skipped - auth flow in progress")
//            return
//        }
//        
//        // Prevent if sheet already showing
//        guard !showGuildSelectionSheet else {
//            print("⚠️ openGuildSelector skipped - sheet already showing")
//            return
//        }
//        
//        do {
//            try await fetchUserGuilds()
//            showGuildSelectionSheet = true
//        } catch {
//            showError(error, title: "Failed to load guilds", style: .toast)
//        }
//    }
//    
//    /// Fetch open guilds for discovery
//    func fetchOpenGuilds() async throws -> [RLGuildDTO] {
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            let guilds = try await realApi.getOpenGuilds()
//            return guilds
//        } catch {
//            showError(error, title: "Failed to Fetch Guilds", style: .toast)
//            throw error
//        }
//    }
//    
//    /// Join a guild - returns the combined guild with membership
//    func joinGuild(guildId: UUID) async throws -> RLGuildWithMembership {
//        do {
//            let response = try await realApi.joinGuild(guildId: guildId)
//            let guildWithMembership = response.combined
//            
//            // Add to local guild list
//            userGuilds.append(guildWithMembership)
//            
//            // Select the newly joined guild (show transition)
//            selectGuild(guildWithMembership, showTransition: true)
//            
//            showSuccess("Joined \(guildWithMembership.guild.name) successfully!")
//            return guildWithMembership
//        } catch {
//            showError(error, title: "Failed to Join Guild", style: .toast)
//            throw error
//        }
//    }
//    
//    /// Create a new guild - returns the combined guild with membership
//    func createGuild(name: String, description: String?, isOpen: Bool) async throws -> RLGuildWithMembership {
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            let response = try await realApi.createGuild(
//                name: name,
//                description: description,
//                isOpen: isOpen
//            )
//            let guildWithMembership = response.combined
//            
//            // Add to local guild list
//            userGuilds.append(guildWithMembership)
//            
//            // Select the newly created guild (show transition)
//            selectGuild(guildWithMembership, showTransition: true)
//            
//            showSuccess("Created \(guildWithMembership.guild.name) successfully!")
//            return guildWithMembership
//        } catch {
//            showError(error, title: "Failed to Create Guild", style: .toast)
//            throw error
//        }
//    }
//    
//    /// Leave current guild
//    func leaveCurrentGuild() async throws {
//        guard let guild = currentGuild else {
//            throw RLAppError.noGuildSelected
//        }
//        
//        isLoading = true
//        defer { isLoading = false }
//        
//        do {
//            try await realApi.leaveGuild(guildId: guild.id)
//            currentGuild = nil
//            currentMembership = nil
//            
//            // Refresh guild list
//            try await fetchUserGuilds()
//            
//            if !userGuilds.isEmpty {
//                selectGuild(at: 0)
//            } else {
//                showGuildSelectionSheet = true
//            }
//        } catch {
//            showError(error, title: "Failed to Leave Guild", style: .toast)
//            throw error
//        }
//    }
//    
//    // ================================================================================================
//    // MARK: - Announcement Management (REAL API)
//    // ================================================================================================
//    
//    /// Fetch guild announcements
//    func fetchGuildAnnouncements(guildId: UUID) async throws -> [RLAnnouncementViewModel] {
//        print("📢 fetchGuildAnnouncements: Starting for guild \(guildId)")
//        do {
//            let response = try await realApi.getGuildAnnouncements(guildId: guildId)
//            let viewModels = response.viewModels
//            print("📢 fetchGuildAnnouncements: Got \(viewModels.count) announcements")
//            return viewModels
//        } catch {
//            print("📢 fetchGuildAnnouncements: Error - \(error)")
//            showError(error, title: "Failed to Load Announcements", style: .toast)
//            throw error
//        }
//    }
//    
//    /// Fetch announcements for current guild
//    func fetchCurrentGuildAnnouncements() async throws -> [RLAnnouncementViewModel] {
//        guard let guild = currentGuild else {
//            throw RLAppError.noGuildSelected
//        }
//        return try await fetchGuildAnnouncements(guildId: guild.id)
//    }
//    
//    /// Record announcement view (marks as read)
//    /// Uses the announcement's guildId
//    func recordAnnouncementView(guildId: UUID, announcementId: UUID) async throws {
//        do {
//            try await realApi.recordAnnouncementView(guildId: guildId, announcementId: announcementId)
//        } catch {
//            // Don't show error for view recording - it's not critical
//            print("⚠️ Failed to record announcement view: \(error)")
//            throw error
//        }
//    }
//    
//    /// Create announcement (admin/mod only)
//    func createAnnouncement(title: String, content: String, preview: String? = nil, isImportant: Bool = false) async throws -> RLAnnouncementViewModel {
//        guard let guild = currentGuild else {
//            throw RLAppError.noGuildSelected
//        }
//        
//        do {
//            let response = try await realApi.createAnnouncement(
//                guildId: guild.id,
//                title: title,
//                content: content,
//                preview: preview,
//                isImportant: isImportant
//            )
//            
//            showSuccess("Announcement posted!")
//            return RLAnnouncementViewModel(from: response)
//        } catch {
//            showError(error, title: "Failed to Create Announcement", style: .toast)
//            throw error
//        }
//    }
//    
//    // ================================================================================================
//    // MARK: - Keychain Persistence
//    // ================================================================================================
//    
//    private let keychainPrefix = "traders_guild_"
//    
//    // Token
//    private func saveTokenToKeychain(_ token: String) {
//        UserDefaults.standard.set(token, forKey: "\(keychainPrefix)token")
//    }
//    
//    private func getTokenFromKeychain() -> String? {
//        UserDefaults.standard.string(forKey: "\(keychainPrefix)token")
//    }
//    
//    private func clearTokenFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)token")
//    }
//    
//    // User
//    private func saveUserToKeychain(_ user: RLUserDTO) {
//        if let data = try? JSONEncoder().encode(user) {
//            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)user")
//        }
//    }
//    
//    private func getUserFromKeychain() -> RLUserDTO? {
//        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)user") else { return nil }
//        return try? JSONDecoder().decode(RLUserDTO.self, from: data)
//    }
//    
//    private func clearUserFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)user")
//    }
//    
//    // Guild
//    private func saveGuildToKeychain(_ guild: RLGuildDTO) {
//        if let data = try? JSONEncoder().encode(guild) {
//            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)guild")
//        }
//    }
//    
//    private func getGuildFromKeychain() -> RLGuildDTO? {
//        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)guild") else { return nil }
//        return try? JSONDecoder().decode(RLGuildDTO.self, from: data)
//    }
//    
//    private func clearGuildFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)guild")
//    }
//    
//    // Membership
//    private func saveMembershipToKeychain(_ membership: RLGuildMembershipDTO) {
//        if let data = try? JSONEncoder().encode(membership) {
//            UserDefaults.standard.set(data, forKey: "\(keychainPrefix)membership")
//        }
//    }
//    
//    private func getMembershipFromKeychain() -> RLGuildMembershipDTO? {
//        guard let data = UserDefaults.standard.data(forKey: "\(keychainPrefix)membership") else { return nil }
//        return try? JSONDecoder().decode(RLGuildMembershipDTO.self, from: data)
//    }
//    
//    private func clearMembershipFromKeychain() {
//        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)membership")
//    }
//    
//    // Clear all
//    private func clearAllKeychain() {
//        clearTokenFromKeychain()
//        clearUserFromKeychain()
//        clearGuildFromKeychain()
//        clearMembershipFromKeychain()
//    }
//}
//
//// ================================================================================================
//// MARK: - App Errors
//// ================================================================================================
//
//enum RLAppError: LocalizedError {
//    case noGuildSelected
//    case notAuthenticated
//    case networkError(String)
//    case unknown(String)
//    
//    var errorDescription: String? {
//        switch self {
//        case .noGuildSelected:
//            return "No guild selected"
//        case .notAuthenticated:
//            return "Not authenticated"
//        case .networkError(let msg):
//            return "Network error: \(msg)"
//        case .unknown(let msg):
//            return msg
//        }
//    }
//}




