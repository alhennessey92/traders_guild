//
//  RLAppState.swift
//  traders_guild
//
//  CLEAN REBUILD - Uses flat DTOs that match backend exactly.
//

import Foundation
import SwiftUI
import Combine

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
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                saveRefreshTokenToKeychain(token)
            } else {
                clearRefreshTokenFromKeychain()
            }
        }
    }
    
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
    private var cancellables = Set<AnyCancellable>()
    @Published var presenceByUserId: [UUID: Bool] = [:]
    private var currentPresenceChannel: String?
    
    // ================================================================================================
    // MARK: - Initialization
    // ================================================================================================
    
    init() {
        // Set up auth failure callback - called when token refresh fails
        realApi.onAuthenticationFailure = { [weak self] in
            self?.handleAuthenticationFailure()
        }
        
        // Set up token refresh callback - called when tokens are refreshed
        realApi.onTokensRefreshed = { [weak self] accessToken, refreshToken in
            self?.handleTokensRefreshed(accessToken: accessToken, refreshToken: refreshToken)
        }
        
        setupRealTimeObservers()
        setupPresenceListeners()
        
        Task {
            await restoreSession()
        }
    }
    
    /// Handle authentication failure (refresh token expired)
    /// Called automatically by RealAPIService when token refresh fails
    private func handleAuthenticationFailure() {
        print("🔐 Authentication failure - session expired, logging out...")
        
        // Clear local state without calling logout API (token is invalid anyway)
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        currentGuild = nil
        currentMembership = nil
        userGuilds = []
        showGuildSelectionSheet = false
        isHandlingAuthFlow = false
        
        clearAllKeychain()
        resetChartReadyState()
        
        showError(
            title: "Session Expired",
            message: "Please log in again",
            severity: .warning,
            style: .alert
        )
    }
    
    /// Handle tokens being refreshed - update keychain
    /// Called automatically by RealAPIService after successful token refresh
    private func handleTokensRefreshed(accessToken: String, refreshToken: String) {
        print("🔐 Tokens refreshed - updating keychain")
        self.accessToken = accessToken
        self.refreshToken = refreshToken
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
        presenceByUserId.removeAll()
        currentPresenceChannel = nil
        
        clearAllKeychain()
        resetChartReadyState()
        
        showInfo("You've been logged out")
    }
    
    /// Restore session from keychain
    func restoreSession() async {
        print("🔄 restoreSession: Starting...")
        
        // Restore tokens
        if let token = getTokenFromKeychain() {
            self.accessToken = token
            print("🔄 restoreSession: Found access token")
        }
        
        if let refreshToken = getRefreshTokenFromKeychain() {
            self.refreshToken = refreshToken
            print("🔄 restoreSession: Found refresh token")
        }
        
        // Set tokens on realApi if we have both
        if let access = accessToken, let refresh = refreshToken {
            realApi.setTokens(access: access, refresh: refresh)
            print("🔄 restoreSession: Tokens set on API service")
        } else if let access = accessToken {
            // Fallback - at least set access token
            realApi.setAccessToken(access)
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
        self.userGuilds = response.guilds  // Backend now returns already-combined data
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
    
    /// Fetch guilds user can join (not already a member of)
    func fetchJoinableGuilds() async throws -> [RLGuildDTO] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let guilds = try await realApi.getJoinableGuilds()
            print("🏰 fetchJoinableGuilds: Found \(guilds.count) joinable guilds")
            return guilds
        } catch {
            showError(error, title: "Failed to Fetch Guilds", style: .toast)
            throw error
        }
    }
    
    // Keep old method name for backwards compatibility (optional - can remove if preferred)
    func fetchOpenGuilds() async throws -> [RLGuildDTO] {
        return try await fetchJoinableGuilds()
    }
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
    
    /// Join a guild - returns the combined guild with membership
    func joinGuild(guildId: UUID) async throws -> RLGuildWithMembership {
        do {
            let response = try await realApi.joinGuild(guildId: guildId)
            let guildWithMembership = response.asGuildWithMembership
            
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
            let guildWithMembership = response.asGuildWithMembership
            
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
    // MARK: - Event Management (REAL API)
    // ================================================================================================
    
    /// Fetch events for a guild
    func fetchGuildEvents(guildId: UUID) async throws -> [RLGuildEventWithAuthorDTO] {
        print("📅 fetchGuildEvents: Starting for guild \(guildId)")
        do {
            let response = try await realApi.getGuildEvents(guildId: guildId)
            print("📅 fetchGuildEvents: Got \(response.events.count) events")
            return response.events
        } catch {
            print("📅 fetchGuildEvents: Error - \(error)")
            showError(error, title: "Failed to Load Events", style: .toast)
            throw error
        }
    }
    
    /// Fetch events for current guild
    func fetchCurrentGuildEvents() async throws -> [RLGuildEventWithAuthorDTO] {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchGuildEvents(guildId: guild.id)
    }
    
    /// Record event view (mark as read)
    func recordEventView(guildId: UUID, eventId: UUID) async throws {
        do {
            try await realApi.recordEventView(guildId: guildId, eventId: eventId)
        } catch {
            // Silently fail for view recording - not critical
            print("⚠️ Failed to record event view: \(error)")
        }
    }
    
    /// Attend an event (RSVP yes)
    func attendEvent(guildId: UUID, eventId: UUID) async throws -> RLGuildEventResponseDTO {
        do {
            let response = try await realApi.attendEvent(guildId: guildId, eventId: eventId)
            return response
        } catch {
            showError(error, title: "Failed to Attend Event", style: .toast)
            throw error
        }
    }
    
    /// Unattend an event (cancel RSVP)
    func unattendEvent(guildId: UUID, eventId: UUID) async throws {
        do {
            try await realApi.unattendEvent(guildId: guildId, eventId: eventId)
        } catch {
            showError(error, title: "Failed to Cancel Attendance", style: .toast)
            throw error
        }
    }
    
    
    /// Create event (admin/mod only)
    /// Constructs full RLGuildEventWithAuthorDTO locally since we know current user is the author
    func createEvent(title: String, content: String, preview: String, eventDate: Date, isImportant: Bool = false) async throws -> RLGuildEventWithAuthorDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        guard let user = currentUser else {
            throw RLAppError.notAuthenticated
        }
        guard let membership = currentMembership else {
            throw RLAppError.noGuildSelected
        }
        
        do {
            // Backend returns just the event response
            let eventResponse = try await realApi.createEvent(
                guildId: guild.id,
                title: title,
                content: content,
                preview: preview,
                eventDate: eventDate,
                isImportant: isImportant
            )
            
            // Construct the author membership info from current user
            let authorMembership = RLGuildSimpleMembershipResponse(
                userId: user.id,
                guildId: guild.id,
                role: membership.role,
                reputation: membership.reputation,
                userDisplayName: user.displayName,
                userUsername: user.username,
                userAvatarUrl: user.avatarUrl
            )
            
            // Combine into full response
            let fullResponse = RLGuildEventWithAuthorDTO(
                event: eventResponse,
                authorMembership: authorMembership
            )
            
            showSuccess("Event created!")
            return fullResponse
        } catch {
            showError(error, title: "Failed to Create Event", style: .toast)
            throw error
        }
    }
    
    
    
    
    // ================================================================================================
    // MARK: - Statistics Management (REAL API)
    // ================================================================================================
    
    /// Fetch guild statistics
    func fetchGuildStatistics(guildId: UUID) async throws -> RLGuildStatisticsResponse {
        print("📊 fetchGuildStatistics: Starting for guild \(guildId)")
        do {
            let response = try await realApi.getGuildStatistics(guildId: guildId)
            print("📊 fetchGuildStatistics: Got statistics")
            return response
        } catch {
            print("📊 fetchGuildStatistics: Error - \(error)")
            // Don't show error toast for statistics - it's not critical
            throw error
        }
    }
    
    /// Fetch statistics for current guild
    func fetchCurrentGuildStatistics() async throws -> RLGuildStatisticsResponse {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchGuildStatistics(guildId: guild.id)
    }
    
    
    
    
    // NEW User management apis
    
    
    // ================================================================================================
    // MARK: - Guild Member Management (REAL API)
    // ================================================================================================
    
    /// Fetch guild members with embedded user data
    func fetchGuildMembers(
        guildId: UUID,
        skip: Int = 0,
        limit: Int = 50,
        search: String? = nil
    ) async throws -> RLGuildMembersListDTO {
        do {
            return try await realApi.getGuildMembers(
                guildId: guildId,
                skip: skip,
                limit: limit,
                search: search
            )
        } catch {
            showError(error, title: "Failed to Load Members", style: .toast)
            throw error
        }
    }
    
    /// Fetch a specific guild member's info with relationship data
    func fetchGuildMember(guildId: UUID, userId: UUID) async throws -> RLGuildMemberDTO {
        do {
            return try await realApi.getGuildMember(guildId: guildId, userId: userId)
        } catch {
            showError(error, title: "Failed to Load Member", style: .toast)
            throw error
        }
    }
    
    
    
    // ================================================================================================
    // MARK: - User Profile Management (REAL API)
    // ================================================================================================
    
    /// Fetch current user's full profile (profile + stats + awards summary)
    func fetchCurrentUserFullProfile(guildId: UUID? = nil) async throws -> RLUserFullProfileDTO {
        do {
            return try await realApi.getCurrentUserFullProfile(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Profile", style: .toast)
            throw error
        }
    }
    
    /// Fetch another user's full profile
    func fetchUserFullProfile(userId: UUID, guildId: UUID? = nil) async throws -> RLUserFullProfileDTO {
        do {
            return try await realApi.getUserProfile(userId: userId, guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Profile", style: .toast)
            throw error
        }
    }
    
    /// Fetch current user's extended profile (bio, interests, etc.)
    func fetchCurrentUserExtendedProfile() async throws -> RLUserProfileDTO {
        do {
            return try await realApi.getCurrentUserExtendedProfile()
        } catch {
            showError(error, title: "Failed to Load Profile", style: .toast)
            throw error
        }
    }
    
    /// Update current user's extended profile
    func updateCurrentUserProfile(_ updateRequest: RLUserProfileUpdateRequest) async throws -> RLUserProfileDTO {
        do {
            let response = try await realApi.updateCurrentUserProfile(updateRequest)
            showSuccess("Profile updated")
            return response
        } catch {
            showError(error, title: "Failed to Update Profile", style: .toast)
            throw error
        }
    }
    
    /// Fetch current user's global statistics
    func fetchCurrentUserStatistics() async throws -> RLUserGlobalStatisticsDTO {
        do {
            return try await realApi.getCurrentUserStatistics()
        } catch {
            showError(error, title: "Failed to Load Statistics", style: .toast)
            throw error
        }
    }
    
    
    
    // ================================================================================================
    // MARK: - Awards Management (REAL API)
    // ================================================================================================
    
    /// Fetch all awards earned by current user
    func fetchCurrentUserAwards(guildId: UUID? = nil) async throws -> [RLUserAwardDTO] {
        do {
            let response = try await realApi.getCurrentUserAwards(guildId: guildId)
            return response.awards
        } catch {
            showError(error, title: "Failed to Load Awards", style: .toast)
            throw error
        }
    }
    
    /// Fetch awards summary for current user
    func fetchCurrentUserAwardsSummary(guildId: UUID? = nil) async throws -> RLAwardsSummaryDTO {
        do {
            return try await realApi.getCurrentUserAwardsSummary(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Awards Summary", style: .toast)
            throw error
        }
    }
    
    
    
    // ================================================================================================
    // MARK: - Friends Management (REAL API)
    // ================================================================================================
    
    /// Fetch accepted friends list
    func fetchFriends(guildId: UUID? = nil) async throws -> RLFriendsListDTO {
        do {
            return try await realApi.getFriends(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Friends", style: .toast)
            throw error
        }
    }
    
    /// Fetch pending friend requests (incoming + outgoing)
    func fetchFriendRequests(guildId: UUID? = nil) async throws -> RLFriendRequestsListDTO {
        do {
            return try await realApi.getFriendRequests(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Friend Requests", style: .toast)
            throw error
        }
    }
    
    /// Send a friend request to another member (guild-scoped)
    func sendFriendRequest(toMembershipId: UUID, message: String? = nil) async throws -> RLFriendshipResponseDTO {
        do {
            let response = try await realApi.sendFriendRequest(toMembershipId: toMembershipId, message: message)
            showSuccess("Friend request sent")
            return response
        } catch {
            showError(error, title: "Failed to Send Friend Request", style: .toast)
            throw error
        }
    }
    
    /// Accept a pending friend request
    func acceptFriendRequest(requestId: UUID) async throws -> RLFriendshipResponseDTO {
        do {
            let response = try await realApi.acceptFriendRequest(requestId: requestId)
            showSuccess("Friend request accepted")
            return response
        } catch {
            showError(error, title: "Failed to Accept Request", style: .toast)
            throw error
        }
    }
    
    /// Decline a pending friend request
    func declineFriendRequest(requestId: UUID) async throws -> RLDetailResponseDTO {
        do {
            let response = try await realApi.declineFriendRequest(requestId: requestId)
            showSuccess("Friend request declined")
            return response
        } catch {
            showError(error, title: "Failed to Decline Request", style: .toast)
            throw error
        }
    }
    
    /// Remove a friend or cancel a pending request
    func removeFriend(membershipId: UUID) async throws -> RLDetailResponseDTO {
        do {
            let response = try await realApi.removeFriend(membershipId: membershipId)
            showSuccess("Friend removed")
            return response
        } catch {
            showError(error, title: "Failed to Remove Friend", style: .toast)
            throw error
        }
    }
    
    
    
    // ================================================================================================
    // MARK: - Blocks Management (REAL API)
    // ================================================================================================
    
    /// Block a user
    func blockUser(membershipId: UUID) async throws -> RLDetailResponseDTO {
        do {
            let response = try await realApi.blockUser(membershipId: membershipId)
            showSuccess("User blocked")
            return response
        } catch {
            showError(error, title: "Failed to Block User", style: .toast)
            throw error
        }
    }
    
    /// Unblock a user
    func unblockUser(membershipId: UUID) async throws -> RLDetailResponseDTO {
        do {
            let response = try await realApi.unblockUser(membershipId: membershipId)
            showSuccess("User unblocked")
            return response
        } catch {
            showError(error, title: "Failed to Unblock User", style: .toast)
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
    
    // Refresh Token
    private func saveRefreshTokenToKeychain(_ token: String) {
        UserDefaults.standard.set(token, forKey: "\(keychainPrefix)refresh_token")
    }
    
    private func getRefreshTokenFromKeychain() -> String? {
        UserDefaults.standard.string(forKey: "\(keychainPrefix)refresh_token")
    }
    
    private func clearRefreshTokenFromKeychain() {
        UserDefaults.standard.removeObject(forKey: "\(keychainPrefix)refresh_token")
    }
    
    // Clear all
    private func clearAllKeychain() {
        clearTokenFromKeychain()
        clearRefreshTokenFromKeychain()
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





// New Appstate for Messaging

//
//  RLAppState+Messaging.swift
//  traders_guild
//
//  Messaging methods for RLAppState.
//  Add this to your existing RLAppState.swift file or keep as extension.
//


// MARK: - Messaging Extension
extension RLAppState {
    
    // =============================================================================================
    // MARK: - Combined Data (Drawer Preload)
    // =============================================================================================
    
    /// Fetch all messaging data for drawer preload
    /// Returns chatrooms + categorized DMs in one request
    func fetchGuildMessagingData(guildId: UUID) async throws -> RLGuildMessagingDataDTO {
        do {
            return try await realApi.getGuildMessagingData(guildId: guildId)
        } catch {
            showError(error, title: "Failed to Load Messages", style: .toast)
            throw error
        }
    }
    
    /// Fetch messaging data for current guild
    func fetchCurrentGuildMessagingData() async throws -> RLGuildMessagingDataDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchGuildMessagingData(guildId: guild.id)
    }
    
    /// Fetch unread counts
    func fetchUnreadCounts(guildId: UUID) async throws -> RLUnreadCountsDTO {
        do {
            return try await realApi.getUnreadCounts(guildId: guildId)
        } catch {
            // Don't show error for unread counts - not critical
            print("⚠️ Failed to fetch unread counts: \(error)")
            throw error
        }
    }
    
    // =============================================================================================
    // MARK: - Chatrooms
    // =============================================================================================
    
    /// Fetch all chatrooms for a guild
    func fetchGuildChatrooms(guildId: UUID) async throws -> [RLGuildChatroomDTO] {
        do {
            let response = try await realApi.getGuildChatrooms(guildId: guildId)
            return response.chatrooms
        } catch {
            showError(error, title: "Failed to Load Chatrooms", style: .toast)
            throw error
        }
    }
    
    /// Fetch chatrooms for current guild
    func fetchCurrentGuildChatrooms() async throws -> [RLGuildChatroomDTO] {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchGuildChatrooms(guildId: guild.id)
    }
    
    /// Fetch a single chatroom
    func fetchChatroom(chatroomId: UUID) async throws -> RLGuildChatroomDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.getChatroom(guildId: guild.id, chatroomId: chatroomId)
        } catch {
            showError(error, title: "Failed to Load Chatroom", style: .toast)
            throw error
        }
    }
    
    /// Fetch chatroom messages (paginated)
    func fetchChatroomMessages(
        chatroomId: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> RLChatroomMessagesListDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.getChatroomMessages(
                guildId: guild.id,
                chatroomId: chatroomId,
                limit: limit,
                cursor: cursor
            )
        } catch {
            showError(error, title: "Failed to Load Messages", style: .toast)
            throw error
        }
    }
    
    /// Send a chatroom message
    func sendChatroomMessage(chatroomId: UUID, content: String) async throws -> RLChatroomMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.sendChatroomMessage(
                guildId: guild.id,
                chatroomId: chatroomId,
                content: content
            )
        } catch {
            showError(error, title: "Failed to Send Message", style: .toast)
            throw error
        }
    }
    
    /// Edit a chatroom message
    func editChatroomMessage(
        chatroomId: UUID,
        messageId: UUID,
        content: String
    ) async throws -> RLChatroomMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            let message = try await realApi.editChatroomMessage(
                guildId: guild.id,
                chatroomId: chatroomId,
                messageId: messageId,
                content: content
            )
            showSuccess("Message updated")
            return message
        } catch {
            showError(error, title: "Failed to Edit Message", style: .toast)
            throw error
        }
    }
    
    /// Delete a chatroom message
    func deleteChatroomMessage(chatroomId: UUID, messageId: UUID) async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            _ = try await realApi.deleteChatroomMessage(
                guildId: guild.id,
                chatroomId: chatroomId,
                messageId: messageId
            )
            showSuccess("Message deleted")
        } catch {
            showError(error, title: "Failed to Delete Message", style: .toast)
            throw error
        }
    }
    
    /// Mark chatroom as read
    func markChatroomAsRead(chatroomId: UUID) async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            _ = try await realApi.markChatroomAsRead(guildId: guild.id, chatroomId: chatroomId)
        } catch {
            // Don't show error for mark as read - not critical
            print("⚠️ Failed to mark chatroom as read: \(error)")
            throw error
        }
    }
    
    /// Update chatroom settings (pin/mute)
    func updateChatroomSettings(
        chatroomId: UUID,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil
    ) async throws -> RLChatroomUserSettingsDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            let settings = try await realApi.updateChatroomSettings(
                guildId: guild.id,
                chatroomId: chatroomId,
                isPinned: isPinned,
                isMuted: isMuted
            )
            if isPinned == true {
                showSuccess("Chatroom pinned")
            } else if isPinned == false {
                showSuccess("Chatroom unpinned")
            }
            if isMuted == true {
                showSuccess("Chatroom muted")
            } else if isMuted == false {
                showSuccess("Chatroom unmuted")
            }
            return settings
        } catch {
            showError(error, title: "Failed to Update Settings", style: .toast)
            throw error
        }
    }
    
    /// Create a new chatroom (admin only)
    func createChatroom(name: String, description: String? = nil) async throws -> RLGuildChatroomDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            let chatroom = try await realApi.createChatroom(
                guildId: guild.id,
                name: name,
                description: description
            )
            showSuccess("Chatroom created")
            return chatroom
        } catch {
            showError(error, title: "Failed to Create Chatroom", style: .toast)
            throw error
        }
    }
    
    // =============================================================================================
    // MARK: - Direct Messages
    // =============================================================================================
    
    /// Fetch all DM threads for current guild
    func fetchDMThreads(guildId: UUID) async throws -> [RLDMThreadDTO] {
        do {
            let response = try await realApi.getDMThreads(guildId: guildId)
            return response.threads
        } catch {
            showError(error, title: "Failed to Load Messages", style: .toast)
            throw error
        }
    }
    
    /// Fetch DM threads for current guild
    func fetchCurrentGuildDMThreads() async throws -> [RLDMThreadDTO] {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchDMThreads(guildId: guild.id)
    }
    
    /// Fetch or create a DM thread with another user
    func fetchOrCreateDMThread(participantUserId: UUID) async throws -> RLDMThreadDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.getOrCreateDMThread(
                guildId: guild.id,
                participantUserId: participantUserId
            )
        } catch {
            showError(error, title: "Failed to Open Chat", style: .toast)
            throw error
        }
    }
    
    /// Fetch a single DM thread
    func fetchDMThread(threadId: UUID) async throws -> RLDMThreadDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.getDMThread(guildId: guild.id, threadId: threadId)
        } catch {
            showError(error, title: "Failed to Load Chat", style: .toast)
            throw error
        }
    }
    
    /// Fetch DM messages (paginated)
    func fetchDMMessages(
        threadId: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> RLDMMessagesListDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.getDMMessages(
                guildId: guild.id,
                threadId: threadId,
                limit: limit,
                cursor: cursor
            )
        } catch {
            showError(error, title: "Failed to Load Messages", style: .toast)
            throw error
        }
    }
    
    /// Send a DM message
    func sendDMMessage(threadId: UUID, content: String) async throws -> RLDMMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            return try await realApi.sendDMMessage(
                guildId: guild.id,
                threadId: threadId,
                content: content
            )
        } catch {
            showError(error, title: "Failed to Send Message", style: .toast)
            throw error
        }
    }
    
    /// Edit a DM message
    func editDMMessage(
        threadId: UUID,
        messageId: UUID,
        content: String
    ) async throws -> RLDMMessageDTO {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            let message = try await realApi.editDMMessage(
                guildId: guild.id,
                threadId: threadId,
                messageId: messageId,
                content: content
            )
            showSuccess("Message updated")
            return message
        } catch {
            showError(error, title: "Failed to Edit Message", style: .toast)
            throw error
        }
    }
    
    /// Delete a DM message
    func deleteDMMessage(threadId: UUID, messageId: UUID) async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            _ = try await realApi.deleteDMMessage(
                guildId: guild.id,
                threadId: threadId,
                messageId: messageId
            )
            showSuccess("Message deleted")
        } catch {
            showError(error, title: "Failed to Delete Message", style: .toast)
            throw error
        }
    }
    
    /// Mark DM as read
    func markDMAsRead(threadId: UUID) async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            _ = try await realApi.markDMAsRead(guildId: guild.id, threadId: threadId)
        } catch {
            // Don't show error for mark as read - not critical
            print("⚠️ Failed to mark DM as read: \(error)")
            throw error
        }
    }
    
    /// Delete entire DM conversation
    func deleteDMThread(threadId: UUID) async throws {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        do {
            _ = try await realApi.deleteDMThread(guildId: guild.id, threadId: threadId)
            showSuccess("Conversation deleted")
        } catch {
            showError(error, title: "Failed to Delete Conversation", style: .toast)
            throw error
        }
    }
}





//
//  RLAppState+RealTime.swift
//  traders_guild
//
//  Integrates WebSocket lifecycle with App State.
//

// extension RLAppState {
    
//     // MARK: - WebSocket Lifecycle Management
    
//     /// Called when authentication is successful (Login or Restore Session)
//     func connectRealTimeService() {
//         guard let token = self.accessToken else { return }
//         RealTimeService.shared.connect(token: token)
        
//         // Optional: Subscribe to user-specific notification channel if backend supports it
//         // let userId = currentUser?.id.uuidString.lowercased() ?? ""
//         // RealTimeService.shared.subscribe(to: ["user:\(userId):notifications"])
//     }
    
//     /// Called when logging out
//     func disconnectRealTimeService() {
//         RealTimeService.shared.disconnect()
//     }
    
//     // MARK: - Setup Observers
    
//     /// Call this in RLAppState.init() to react to token changes
//     func setupRealTimeObservers() {
//         // Observe token changes to manage connection
//         $accessToken
//             .removeDuplicates()
//             .sink { [weak self] token in
//                 if let token = token {
//                     print("🔐 [AppState] Token set, connecting WS...")
//                     RealTimeService.shared.connect(token: token)
//                 } else {
//                     print("🔐 [AppState] Token cleared, disconnecting WS...")
//                     RealTimeService.shared.disconnect()
//                     self?.presenceByUserId.removeAll()
//                 }
//             }
//             .store(in: &cancellables) // Ensure RLAppState has: private var cancellables = Set<AnyCancellable>()
//     }

//     func setupPresenceListeners() {
//         RealTimeService.shared.messageSubject
//             .receive(on: DispatchQueue.main)
//             .sink { [weak self] message in
//                 guard let self = self,
//                       let type = WSMessageType(rawValue: message.type),
//                       type == .presence,
//                       let userIdString = message.userId,
//                       let userId = UUID(uuidString: userIdString),
//                       let isOnline = message.payload(as: Bool.self) else { return }
//                 self.presenceByUserId[userId] = isOnline
//             }
//             .store(in: &cancellables)
        
//         $currentGuild
//             .map { $0?.id }
//             .removeDuplicates()
//             .sink { [weak self] guildId in
//                 guard let self = self else { return }
//                 if let existing = self.currentPresenceChannel {
//                     RealTimeService.shared.unsubscribe(from: [existing], owner: "presence")
//                     self.currentPresenceChannel = nil
//                 }
//                 self.presenceByUserId.removeAll()
//                 guard let guildId = guildId else { return }
//                 let channel = MessagingChannel.guildPresence(guildId).name
//                 self.currentPresenceChannel = channel
//                 RealTimeService.shared.subscribe(to: [channel], owner: "presence")
//             }
//             .store(in: &cancellables)
//     }
// }

// NOTE: You need to add `private var cancellables = Set<AnyCancellable>()` to RLAppState
// and call `setupRealTimeObservers()` in its init().



//
//  RLAppState+RealTime.swift
//  traders_guild
//
//  Integrates WebSocket lifecycle with App State.
//


extension RLAppState {
    
    // MARK: - WebSocket Lifecycle Management
    
    /// Called when authentication is successful (Login or Restore Session)
    func connectRealTimeService() {
        guard let token = self.accessToken else { return }
        RealTimeService.shared.connect(token: token)
        
        // Optional: Subscribe to user-specific notification channel
        // let userId = currentUser?.id.uuidString.lowercased() ?? ""
        // RealTimeService.shared.subscribe(to: ["user:\(userId):notifications"])
    }
    
    /// Called when logging out or entering background
    func disconnectRealTimeService() {
        RealTimeService.shared.disconnect()
        
        // Clear presence state on disconnect so UI updates to offline
        DispatchQueue.main.async {
            self.presenceByUserId.removeAll()
        }
    }
    
    // MARK: - Setup Observers
    
    /// Call this in RLAppState.init() to react to token changes
    func setupRealTimeObservers() {
        // Observe token changes to manage connection
        $accessToken
            .removeDuplicates()
            .sink { [weak self] token in
                if let token = token {
                    print("🔐 [AppState] Token set, connecting WS...")
                    RealTimeService.shared.connect(token: token)
                } else {
                    print("🔐 [AppState] Token cleared, disconnecting WS...")
                    self?.disconnectRealTimeService()
                }
            }
            .store(in: &cancellables) // Ensure RLAppState has: private var cancellables = Set<AnyCancellable>()
    }
    
    /// Sets up the Single Source of Truth for user presence
    func setupPresenceListeners() {
        // 1. Listen for raw presence messages from WebSocket
        RealTimeService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self = self,
                      let type = WSMessageType(rawValue: message.type),
                      type == .presence,
                      let userIdString = message.userId,
                      let userId = UUID(uuidString: userIdString),
                      let isOnline = message.payload(as: Bool.self) else { return }
                
                // Update the Source of Truth map
                self.presenceByUserId[userId] = isOnline
            }
            .store(in: &cancellables)
        
        // 2. Manage subscription to the Guild Presence channel based on selected guild
        $currentGuild
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] guildId in
                guard let self = self else { return }
                
                // Unsubscribe from old guild presence channel
                if let existing = self.currentPresenceChannel {
                    RealTimeService.shared.unsubscribe(from: [existing], owner: "presence")
                    self.currentPresenceChannel = nil
                }
                
                // Clear map on guild change
                self.presenceByUserId.removeAll()
                
                // Subscribe to new guild presence
                guard let guildId = guildId else { return }
                let channel = MessagingChannel.guildPresence(guildId).name
                self.currentPresenceChannel = channel
                
                print("👀 [AppState] Subscribing to presence: \(channel)")
                RealTimeService.shared.subscribe(to: [channel], owner: "presence")
            }
            .store(in: &cancellables)
    }
}